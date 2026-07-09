from rest_framework.decorators import api_view
from rest_framework.response import Response

@api_view(['GET'])
def me(request):
    user = request.user  # SupabaseUser instance from SupabaseJWTAuthentication
    db_user = user.db_user
    return Response({
        'id': str(db_user.id),
        'email': user.email,
        'role': db_user.role,
        'full_name': db_user.full_name,
        'phone': db_user.phone,
        'is_active': db_user.is_active,
    })