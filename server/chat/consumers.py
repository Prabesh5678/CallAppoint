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

        # Notify the other party via their personal notification channel
        await self._notify_peer_presence(is_joining=True)

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            # Clear presence in cache
            cache_key = f"video_presence_{self.appointment_id}_{self.user['role']}"
            cache.delete(cache_key)

            # Notify the other party via their personal notification channel
            await self._notify_peer_presence(is_joining=False)

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

    async def _notify_peer_presence(self, is_joining):
        peer_id = await self._get_peer_id()
        if not peer_id:
            return

        # 1. Real-time Webhook-style notification (WebSocket)
        group_name = f'user_notifications_{peer_id}'
        await self.channel_layer.group_send(
            group_name,
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

        # 2. Push Notification (FCM) if joining
        if is_joining:
            await self._send_push_notification(peer_id)

    async def _send_push_notification(self, peer_id):
        from notifications.services import notify_user

        # We run this in a thread to not block the consumer
        def trigger_push():
            role_name = "Doctor" if self.user['role'] == 'doctor' else "Patient"
            notify_user(
                user_id=peer_id,
                type='call_waiting',
                title='Call is ready!',
                body=f'Your {role_name} has joined the video room and is waiting for you.',
                data={
                    'appointment_id': self.appointment_id,
                    'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                }
            )

        import threading
        threading.Thread(target=trigger_push).start()

    @database_sync_to_async
    def _get_peer_id(self):
        from appointments.models import Appointment
        try:
            appt = Appointment.objects.get(id=self.appointment_id)
            if self.user['role'] == 'doctor':
                return str(appt.patient_id)
            else:
                # In appointment model, doctor is a ForeignKey to DoctorProfile.
                # We need the user_id of the doctor.
                return str(appt.doctor.user_id)
        except Exception:
            return None

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

        # Notify the other party via their personal notification channel
        await self._notify_peer_presence(is_joining=True)

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            # Clear presence in cache
            cache_key = f"video_presence_{self.appointment_id}_{self.user['role']}"
            cache.delete(cache_key)

            # Notify the other party via their personal notification channel
            await self._notify_peer_presence(is_joining=False)

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

    async def _notify_peer_presence(self, is_joining):
        peer_id = await self._get_peer_id()
        if not peer_id:
            return

        # 1. Real-time Webhook-style notification (WebSocket)
        group_name = f'user_notifications_{peer_id}'
        await self.channel_layer.group_send(
            group_name,
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

        # 2. Push Notification (FCM) if joining
        if is_joining:
            await self._send_push_notification(peer_id)

    async def _send_push_notification(self, peer_id):
        from notifications.services import notify_user

        # We run this in a thread to not block the consumer
        def trigger_push():
            role_name = "Doctor" if self.user['role'] == 'doctor' else "Patient"
            notify_user(
                user_id=peer_id,
                type='call_waiting',
                title='Call is ready!',
                body=f'Your {role_name} has joined the video room and is waiting for you.',
                data={
                    'appointment_id': self.appointment_id,
                    'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                }
            )

        import threading
        threading.Thread(target=trigger_push).start()

    @database_sync_to_async
    def _get_peer_id(self):
        from appointments.models import Appointment
        try:
            appt = Appointment.objects.get(id=self.appointment_id)
            if self.user['role'] == 'doctor':
                return str(appt.patient_id)
            else:
                # In appointment model, doctor is a ForeignKey to DoctorProfile.
                # We need the user_id of the doctor.
                return str(appt.doctor.user_id)
        except Exception:
            return None

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