import json
from channels.generic.websocket import AsyncWebsocketConsumer
from django.conf import settings
import jwt
from jwt import PyJWKClient
from channels.db import database_sync_to_async

_jwks_client = PyJWKClient(settings.SUPABASE_JWKS_URL)

class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        token = self._get_token_from_query()
        user = await self._verify_and_get_user(token)

        if not user:
            await self.close(code=4001)
            return

        self.user = user
        self.user_id = str(user['id'])
        self.room_group_name = f'user_notifications_{self.user_id}'

        # Join personal user group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    async def user_notification(self, event):
        # Send message to WebSocket
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
