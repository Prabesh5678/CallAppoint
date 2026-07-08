import jwt
from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from .models import User

class SupabaseUser:
    """Wraps the verified JWT + DB profile so request.user behaves consistently."""
    def __init__(self, payload, db_user):
        self.id = payload['sub']
        self.email = payload.get('email')
        self.role = db_user.role
        self.db_user = db_user
        self.is_authenticated = True

class SupabaseJWTAuthentication(BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return None

        token = auth_header.split(' ')[1]
        try:
            payload = jwt.decode(
                token,
                settings.SUPABASE_JWT_SECRET,
                algorithms=['HS256'],
                audience='authenticated',
            )
        except jwt.ExpiredSignatureError:
            raise AuthenticationFailed('Token expired')
        except jwt.InvalidTokenError:
            raise AuthenticationFailed('Invalid token')

        try:
            db_user = User.objects.get(id=payload['sub'])
        except User.DoesNotExist:
            raise AuthenticationFailed('User profile not found — trigger may not have run')

        return (SupabaseUser(payload, db_user), None)