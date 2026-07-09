import jwt
from jwt import PyJWKClient
from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from .models import User

# Module-level so the JWKS client (and its internal key cache) persists
# across requests instead of re-fetching on every call.
_jwks_client = PyJWKClient(settings.SUPABASE_JWKS_URL)

class SupabaseUser:
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
            signing_key = _jwks_client.get_signing_key_from_jwt(token)
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=['ES256', 'RS256'],  # Supabase uses ES256 by default; RS256 if you chose that
                audience='authenticated',
            )
        except jwt.ExpiredSignatureError:
            raise AuthenticationFailed('Token expired')
        except jwt.PyJWKClientError:
            raise AuthenticationFailed('Unable to fetch signing key')
        except jwt.InvalidTokenError:
            raise AuthenticationFailed('Invalid token')

        try:
            db_user = User.objects.get(id=payload['sub'])
        except User.DoesNotExist:
            raise AuthenticationFailed('User profile not found — trigger may not have run')

        return (SupabaseUser(payload, db_user), None)