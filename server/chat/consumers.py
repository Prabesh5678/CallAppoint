import json
import asyncio
import jwt
import logging
from django.db import models
from django.conf import settings
from jwt import PyJWKClient
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.core.cache import cache
from accounts.models import User

logger = logging.getLogger(__name__)
from accounts.authentication import _jwks_client

class BaseConsumer(AsyncWebsocketConsumer):
    async def _verify_and_get_user(self, token):
        if not token:
            return None
        try:
            loop = asyncio.get_event_loop()
            signing_key = await loop.run_in_executor(None, _jwks_client.get_signing_key_from_jwt, token)

            payload = jwt.decode(token, signing_key.key, algorithms=['ES256', 'RS256'], audience='authenticated')

            return await self._get_db_user(payload['sub'])
        except Exception as e:
            logger.error(f"Auth error in WebSocket: {e}")
            return None

    @database_sync_to_async
    def _get_db_user(self, user_id):
        try:
            db_user = User.objects.get(id=user_id)
            return {'id': db_user.id, 'role': db_user.role, 'full_name': db_user.full_name}
        except User.DoesNotExist:
            return None

    def _get_token_from_query(self):
        try:
            qs = self.scope['query_string'].decode()
            params = dict(p.split('=', 1) for p in qs.split('&') if '=' in p)
            return params.get('token')
        except Exception:
            return None

    @database_sync_to_async
    def _user_in_appointment(self, user_id, appointment_id):
        from appointments.models import Appointment
        return Appointment.objects.filter(id=appointment_id).filter(
            models.Q(patient_id=user_id) | models.Q(doctor_id=user_id)
        ).exists()

class ChatConsumer(BaseConsumer):
    async def connect(self):
        self.appointment_id = str(self.scope['url_route']['kwargs']['appointment_id'])
        self.room_group_name = f'chat_{self.appointment_id}'

        token = self._get_token_from_query()
        user = await self._verify_and_get_user(token)
        if not user:
            await self.close(code=4001)
            return
        self.user = user

        allowed = await self._user_in_appointment(user['id'], self.appointment_id)

        if not allowed:
            await self.close(code=4003)
            return

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            message_text = data.get('message', '')
            if not message_text:
                return

            msg = await self._save_message(self.appointment_id, self.user['id'], message_text)

            peer_id = await self._get_peer_id()
            if peer_id:
                await self.channel_layer.group_send(
                    f'user_notifications_{peer_id}',
                    {
                        'type': 'user_notification',
                        'payload': {
                            'type': 'new_chat_message',
                            'appointment_id': self.appointment_id,
                            'sender_name': self.user['full_name'],
                            'message': message_text,
                        }
                    }
                )

            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'chat_message',
                    'id': msg['id'],
                    'message': message_text,
                    'sender_id': str(self.user['id']),
                    'sent_at': msg['sent_at'],
                }
            )
        except Exception as e:
            logger.error(f"Error in ChatConsumer receive: {e}")

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'id': event['id'],
            'message': event['message'],
            'sender_id': event['sender_id'],
            'sent_at': event['sent_at'],
        }))

    @database_sync_to_async
    def _save_message(self, appointment_id, sender_id, message_text):
        from .models import ChatMessage
        msg = ChatMessage.objects.create(
            appointment_id=appointment_id, sender_id=sender_id, message=message_text
        )
        return {'id': str(msg.id), 'sent_at': msg.sent_at.isoformat()}

    @database_sync_to_async
    def _get_peer_id(self):
        from appointments.models import Appointment
        try:
            appt = Appointment.objects.get(id=self.appointment_id)
            return str(appt.patient_id) if self.user['role'] == 'doctor' else str(appt.doctor_id)
        except Exception:
            return None

class VideoSignalConsumer(BaseConsumer):
    async def connect(self):
        self.appointment_id = str(self.scope['url_route']['kwargs']['appointment_id'])
        self.room_group_name = f'video_{self.appointment_id}'

        token = self._get_token_from_query()
        user = await self._verify_and_get_user(token)
        if not user:
            await self.close(code=4001)
            return
        self.user = user

        allowed = await self._user_in_appointment(user['id'], self.appointment_id)
        if not allowed:
            await self.close(code=4003)
            return

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

        cache_key = f"video_presence_{self.appointment_id}_{self.user['role']}"
        cache.set(cache_key, True, timeout=300)

        await self._notify_peer_presence(is_joining=True)

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            cache_key = f"video_presence_{self.appointment_id}_{self.user['role']}"
            cache.delete(cache_key)

            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'signal_message',
                    'sender_id': str(self.user['id']),
                    'payload': {'type': 'peer_disconnected'},
                }
            )
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            if data.get('type') == 'hangup':
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'signal_message',
                        'sender_id': str(self.user['id']),
                        'payload': {'type': 'bye'},
                    }
                )
            else:
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'signal_message',
                        'sender_id': str(self.user['id']),
                        'payload': data,
                    }
                )
        except Exception as e:
            logger.error(f"Error in VideoConsumer receive: {e}")

    async def signal_message(self, event):
        try:
            if event['sender_id'] != str(self.user['id']):
                await self.send(text_data=json.dumps(event['payload']))
        except Exception:
            pass

    async def _notify_peer_presence(self, is_joining):
        peer_id = await self._get_peer_id()
        if not peer_id: return

        await self.channel_layer.group_send(
            f'user_notifications_{peer_id}',
            {
                'type': 'user_notification',
                'payload': {
                    'type': 'video_presence',
                    'appointment_id': self.appointment_id,
                    'role': self.user['role'],
                    'is_present': is_joining
                }
            }
        )

    @database_sync_to_async
    def _get_peer_id(self):
        from appointments.models import Appointment
        try:
            appt = Appointment.objects.get(id=self.appointment_id)
            return str(appt.patient_id) if self.user['role'] == 'doctor' else str(appt.doctor_id)
        except Exception:
            return None
