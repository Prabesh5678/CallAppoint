from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.conf import settings

class AdminPseudoUser:
    is_authenticated = True
    role = 'admin'

class StaticAdminAuthentication(BaseAuthentication):
    """
    Separate auth path for the standalone Flutter admin app, which has no
    Supabase session at all. Not real user-level auth — a shared secret,
    fast to build but should be swapped for something stronger before
    this admin surface handles real production data.
    """
    def authenticate(self, request):
        token = request.headers.get('X-Admin-Token')
        if not token:
            return None
        if token != settings.ADMIN_API_TOKEN:
            raise AuthenticationFailed('Invalid admin token')
        return (AdminPseudoUser(), None)
