from rest_framework import generics
from .serializers import UserSerializer

class UserMeView(generics.RetrieveUpdateAPIView):
    """
    GET/PATCH /api/accounts/me/ — the logged-in user manages their own basic profile.
    """
    serializer_class = UserSerializer

    def get_object(self):
        # request.user is a SupabaseUser instance from SupabaseJWTAuthentication
        # request.user.db_user is the Django User model instance
        return self.request.user.db_user
