import json
from django.db import models
from django.conf import settings
import jwt
from jwt import PyJWKClient
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.core.cache import cache

_jwks_client = PyJWKClient(settings.SUPABASE_JWKS_URL)


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.appointment_id = self.scope['url_route']['kwargs']['appointment_id']
        self.room_group_name = f'chat_{self.appointment_id}'

        token = self._get_token_from_query()
        user = await self._verify_and_get_user(token)
        if not user:
            await self.close(code=4001)  # invalid/missing token
            return
        self.user = user

        allowed = await self._user_in_appointment(user['id'], self.appointment_id)
        if not allowed:
            await self.close(code=4003)  # not your appointment
            return

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

        # Track presence in cache IMMEDIATELY upon connection
        cache_key = f"video_presence_{self.appointment_id}_{self.user['role']}"
        cache.set(cache_key, True, timeout=3600)
        print(f"DEBUG: Tracking {self.user['role']} for {self.appointment_id}")

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            # Clear presence in cache
            cache_key = f"video_presence_{self.appointment_id}_{self.user['role']}"
            cache.delete(cache_key)
            print(f"DEBUG: Cleared {self.user['role']} for {self.appointment_id}")
            # Notify the other party that we are leaving
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'signal_message',
                    'sender_id': str(self.user['id']),
                    'payload': {'type': 'bye'},
                }
            )
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        message_text = data.get('message', '')
        if not message_text:
            return

        msg = await self._save_message(self.appointment_id, self.user['id'], message_text)

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

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'id': event['id'],
            'message': event['message'],
            'sender_id': event['sender_id'],
            'sent_at': event['sent_at'],
        }))

    def _get_token_from_query(self):
        qs = self.scope['query_string'].decode()
        params = dict(p.split('=', 1) for p in qs.split('&') if '=' in p)
        return params.get('token')

    @database_sync_to_async
    def _verify_and_get_user(self, token):
        if not token:
            return None
        try:
            signing_key = _jwks_client.get_signing_key_from_jwt(token)
            payload = jwt.decode(token, signing_key.key, algorithms=['ES256', 'RS256'], audience='authenticated')
            from accounts.models import User
            db_user = User.objects.get(id=payload['sub'])
            return {'id': db_user.id, 'role': db_user.role}
        except Exception:
            return None

    @database_sync_to_async
    def _user_in_appointment(self, user_id, appointment_id):
        from appointments.models import Appointment
        return Appointment.objects.filter(id=appointment_id).filter(
            models.Q(patient_id=user_id) | models.Q(doctor_id=user_id)
        ).exists()

    @database_sync_to_async
    def _save_message(self, appointment_id, sender_id, message_text):
        from .models import ChatMessage
        msg = ChatMessage.objects.create(
            appointment_id=appointment_id, sender_id=sender_id, message=message_text
        )
        return {'id': str(msg.id), 'sent_at': msg.sent_at.isoformat()}

class VideoSignalConsumer(AsyncWebsocketConsumer):
    """
    Relays WebRTC signaling messages (offer/answer/ICE candidates) between
    the two participants of an appointment. Does not touch the DB at all —
    pure message relay, same auth/authorization checks as chat.
    """
    async def connect(self):
        self.appointment_id = self.scope['url_route']['kwargs']['appointment_id']
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

        # Track presence in cache IMMEDIATELY upon connection
        cache_key = f"video_presence_{self.appointment_id}_{self.user['role']}"
        cache.set(cache_key, True, timeout=3600)
        print(f"DEBUG: Tracking {self.user['role']} for {self.appointment_id}")

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            # Clear presence in cache
            cache_key = f"video_presence_{self.appointment_id}_{self.user['role']}"
            cache.delete(cache_key)
            print(f"DEBUG: Cleared {self.user['role']} for {self.appointment_id}")
            # Notify the other party that we are leaving
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'signal_message',
                    'sender_id': str(self.user['id']),
                    'payload': {'type': 'bye'},
                }
            )
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        # just relay to everyone else in the room — sender excluded on the client side
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'signal_message',
                'sender_id': str(self.user['id']),
                'payload': data,
            }
        )

    async def signal_message(self, event):
        # don't echo back to the sender
        if event['sender_id'] != str(self.user['id']):
            await self.send(text_data=json.dumps(event['payload']))

    def _get_token_from_query(self):
        qs = self.scope['query_string'].decode()
        params = dict(p.split('=', 1) for p in qs.split('&') if '=' in p)
        return params.get('token')

    @database_sync_to_async
    def _verify_and_get_user(self, token):
        if not token:
            return None
        try:
            signing_key = _jwks_client.get_signing_key_from_jwt(token)
            payload = jwt.decode(token, signing_key.key, algorithms=['ES256', 'RS256'], audience='authenticated')
            from accounts.models import User
            db_user = User.objects.get(id=payload['sub'])
            return {'id': db_user.id, 'role': db_user.role}
        except Exception:
            return None

    @database_sync_to_async
    def _user_in_appointment(self, user_id, appointment_id):
        from appointments.models import Appointment
        return Appointment.objects.filter(id=appointment_id).filter(
            models.Q(patient_id=user_id) | models.Q(doctor_id=user_id)
        ).exists()