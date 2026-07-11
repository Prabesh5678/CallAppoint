from datetime import datetime
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, PermissionDenied
from accounts.permissions import IsPatient, IsDoctor
from .models import Appointment
from .serializers import AppointmentSerializer, AppointmentCreateSerializer
from .services import get_available_slots
from notifications.services import notify_user
from django.utils import timezone as dj_timezone


def _ensure_aware(dt):
    if dj_timezone.is_naive(dt):
        return dj_timezone.make_aware(dt)
    return dt

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def available_slots(request, doctor_id):
    date_str = request.query_params.get('date')
    if not date_str:
        raise ValidationError("date query param required (YYYY-MM-DD)")
    date = datetime.strptime(date_str, '%Y-%m-%d').date()
    slots = get_available_slots(doctor_id, date)
    return Response([
        {'start': s.isoformat(), 'end': e.isoformat()} for s, e in slots
    ])


class MyAppointmentsView(generics.ListAPIView):
    """GET /api/appointments/mine/ — role-aware: patient sees their bookings, doctor sees theirs."""
    serializer_class = AppointmentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'patient':
            return Appointment.objects.filter(patient_id=user.id).order_by('-scheduled_start')
        elif user.role == 'doctor':
            return Appointment.objects.filter(doctor_id=user.id).order_by('-scheduled_start')
        return Appointment.objects.none()

class BookAppointmentView(generics.CreateAPIView):
    """POST /api/appointments/book/ — patients only."""
    serializer_class = AppointmentCreateSerializer
    permission_classes = [IsAuthenticated, IsPatient]

    def perform_create(self, serializer):
        data = serializer.validated_data
        slots = get_available_slots(data['doctor'].pk, data['scheduled_start'].date())

        requested_start = _ensure_aware(data['scheduled_start'])
        requested_end = _ensure_aware(data['scheduled_end'])

        slot_matches = any(s == requested_start and e == requested_end for s, e in slots)
        if not slot_matches:
            raise ValidationError("Selected slot is no longer available")

        serializer.save(patient_id=self.request.user.id, status='pending')

        notify_user(
            user_id=data['doctor'].id_id,  # ← .id_id, not .id — see previous fix
            type='appointment_booked',
            title='New appointment request',
            body=f'A patient requested a booking on {data["scheduled_start"].strftime("%b %d, %I:%M %p")}',
            data={'appointment_id': str(serializer.instance.id)},
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsDoctor])
def respond_to_appointment(request, pk):
    """POST /api/appointments/<uuid>/respond/  body: {"action": "confirm" | "reject"}"""
    action = request.data.get('action')
    if action not in ('confirm', 'reject'):
        raise ValidationError('action must be "confirm" or "reject"')

    try:
        appt = Appointment.objects.get(pk=pk, doctor_id=request.user.id)
    except Appointment.DoesNotExist:
        raise PermissionDenied("Not your appointment")

    if appt.status != 'pending':
        raise ValidationError(f"Cannot {action} an appointment with status '{appt.status}'")

    appt.status = 'confirmed' if action == 'confirm' else 'rejected'
    if action == 'confirm':
        appt.video_room_id = f"callappoint-{appt.id}"
    appt.save()
    notify_user(
        user_id=appt.patient_id,
        type='appointment_confirmed' if action == 'confirm' else 'appointment_cancelled',
        title='Appointment confirmed' if action == 'confirm' else 'Appointment rejected',
        body=f'Your appointment on {appt.scheduled_start.strftime("%b %d, %I:%M %p")} was {appt.status}',
        data={'appointment_id': str(appt.id)},
    )
    return Response(AppointmentSerializer(appt).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancel_appointment(request, pk):
    """POST /api/appointments/<uuid>/cancel/ — either party can cancel."""
    user = request.user
    try:
        appt = Appointment.objects.get(pk=pk)
    except Appointment.DoesNotExist:
        raise ValidationError("Appointment not found")

    if str(appt.patient_id) != str(user.id) and str(appt.doctor_id) != str(user.id):
        raise PermissionDenied("Not your appointment")

    if appt.status in ('cancelled', 'completed', 'rejected'):
        raise ValidationError(f"Cannot cancel an appointment with status '{appt.status}'")

    appt.status = 'cancelled'
    appt.cancelled_by_id = user.id
    appt.cancellation_reason = request.data.get('reason', '')
    appt.save()
    return Response(AppointmentSerializer(appt).data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_video_room(request, pk):
    """GET /api/appointments/<uuid>/video-room/"""
    try:
        appt = Appointment.objects.get(pk=pk)
    except Appointment.DoesNotExist:
        raise ValidationError("Appointment not found")

    user = request.user
    if str(appt.patient_id) != str(user.id) and str(appt.doctor_id) != str(user.id):
        raise PermissionDenied("Not your appointment")

    if appt.status != 'confirmed':
        raise ValidationError(f"Video call not available — appointment status is '{appt.status}'")

    if not appt.video_room_id:
        raise ValidationError("No video room generated for this appointment")

    return Response({
        'room_name': appt.video_room_id,
        'jitsi_domain': 'meet.jit.si',
        'display_name': user.db_user.full_name,
    })