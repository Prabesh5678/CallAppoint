from rest_framework import generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from django.db.models import Q
from django.core.cache import cache
from appointments.models import Appointment
from .models import ChatMessage
from .serializers import ChatMessageSerializer


class ChatHistoryView(generics.ListAPIView):
    """GET /api/chat/<uuid:appointment_id>/history/"""
    serializer_class = ChatMessageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        appointment_id = self.kwargs['appointment_id']
        user = self.request.user
        appt = Appointment.objects.filter(
            Q(id=appointment_id) & (Q(patient_id=user.id) | Q(doctor_id=user.id))
        ).first()
        if not appt:
            raise PermissionDenied("Not your appointment")
        return ChatMessage.objects.filter(appointment_id=appointment_id).order_by('sent_at')


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_video_presence(request, appointment_id):
    """
    Checks if the other party is currently in the video room.
    """
    user = request.user
    # 1. Security check: user must be part of the appointment
    appt = Appointment.objects.filter(
        Q(id=appointment_id) & (Q(patient_id=user.id) | Q(doctor_id=user.id))
    ).first()
    if not appt:
        return Response({"error": "Unauthorized"}, status=403)

    # 2. Determine other role
    other_role = 'doctor' if user.role == 'patient' else 'patient'

    # 3. Check cache
    is_present = cache.get(f"video_presence_{appointment_id}_{other_role}", False)

    return Response({
        "appointment_id": appointment_id,
        "other_role": other_role,
        "is_present": is_present
    })
