from rest_framework import generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import Notification, DeviceToken
from .serializers import NotificationSerializer, DeviceTokenSerializer


class MyNotificationsView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user_id=self.request.user.id).order_by('-created_at')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_notification_read(request, pk):
    updated = Notification.objects.filter(pk=pk, user_id=request.user.id).update(is_read=True)
    if not updated:
        return Response({'detail': 'Not found'}, status=404)
    return Response({'detail': 'marked read'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_device_token(request):
    """POST /api/notifications/register-device/  body: {"fcm_token": "...", "platform": "android"}"""
    serializer = DeviceTokenSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    # one user can have multiple devices; one token shouldn't belong to two users
    DeviceToken.objects.filter(fcm_token=serializer.validated_data['fcm_token']).delete()
    DeviceToken.objects.create(user_id=request.user.id, **serializer.validated_data)

    return Response({'detail': 'registered'}, status=201)