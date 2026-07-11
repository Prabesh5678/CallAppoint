from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from django.db.models import Q
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