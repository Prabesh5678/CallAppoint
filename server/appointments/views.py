import hmac, hashlib, base64, time, logging
from datetime import datetime
from django.db import transaction
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, PermissionDenied
from accounts.permissions import IsPatient, IsDoctor
from doctors.models import DoctorProfile
from .models import Appointment
from .serializers import AppointmentSerializer, AppointmentCreateSerializer
from .services import get_available_slots
from notifications.services import notify_user
from django.utils import timezone as dj_timezone
from django.conf import settings

logger = logging.getLogger(__name__)

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
        {'start': s['start'].isoformat(), 'end': s['end'].isoformat(), 'is_available': s['is_available']}
        for s in slots
    ])

class MyAppointmentsView(generics.ListAPIView):
    serializer_class = AppointmentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        # Use select_related to avoid N+1 queries when fetching names in serializer
        base_qs = Appointment.objects.select_related('doctor__id', 'patient').order_by('-scheduled_start')

        if user.role == 'patient':
            return base_qs.filter(patient_id=user.id)
        elif user.role == 'doctor':
            return base_qs.filter(doctor_id=user.id)
        return Appointment.objects.none()

class AppointmentDetailView(generics.RetrieveAPIView):
    serializer_class = AppointmentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'patient':
            return Appointment.objects.filter(patient_id=user.id)
        elif user.role == 'doctor':
            return Appointment.objects.filter(doctor_id=user.id)
        return Appointment.objects.none()

class BookAppointmentView(generics.CreateAPIView):
    serializer_class = AppointmentCreateSerializer
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def perform_create(self, serializer):
        data = serializer.validated_data
        doctor_id = data['doctor'].pk

        parent_appointment = data.get('parent_appointment')
        status_val = 'pending'
        if parent_appointment and self.request.user.role == 'doctor':
            patient_id = parent_appointment.patient_id
            status_val = 'confirmed'
        else:
            patient_id = self.request.user.id

        DoctorProfile.objects.select_for_update().get(id=doctor_id)

        requested_start = _ensure_aware(data['scheduled_start'])
        requested_end = _ensure_aware(data['scheduled_end'])

        if requested_start < dj_timezone.now():
            raise ValidationError("Cannot book an appointment in the past")

        slots = get_available_slots(doctor_id, requested_start.date())

        slot_matches = any(
            s['start'] == requested_start and s['end'] == requested_end and s['is_available']
            for s in slots
        )
        if not slot_matches:
            raise ValidationError("Selected slot is no longer available")

        serializer.save(patient_id=patient_id, status=status_val)

        if status_val == 'confirmed':
            serializer.instance.video_room_id = f"callappoint-{serializer.instance.id}"
            serializer.instance.save()

        notify_user(
            user_id=doctor_id if self.request.user.role == 'patient' else patient_id,
            type='appointment_booked',
            title='New appointment' if status_val == 'pending' else 'Follow-up scheduled',
            body='A new appointment session has been created.',
            data={'appointment_id': str(serializer.instance.id)},
        )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        output = AppointmentSerializer(serializer.instance)
        return Response(output.data, status=status.HTTP_201_CREATED)

@api_view(['POST'])
@permission_classes([IsAuthenticated, IsDoctor])
def respond_to_appointment(request, pk):
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

    peer_id = appt.doctor_id if str(user.id) == str(appt.patient_id) else appt.patient_id
    notify_user(
        user_id=peer_id,
        type='appointment_cancelled',
        title='Appointment cancelled',
        body=f'The appointment on {appt.scheduled_start.strftime("%b %d, %I:%M %p")} was cancelled.',
        data={'appointment_id': str(appt.id)},
    )
    return Response(AppointmentSerializer(appt).data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_video_room(request, pk):
    try:
        appt = Appointment.objects.get(id=pk)
    except Appointment.DoesNotExist:
        raise ValidationError("Appointment not found")

    user = request.user
    if str(appt.patient_id) != str(user.id) and str(appt.doctor_id) != str(user.id):
        raise PermissionDenied("Not your appointment")

    if appt.status != 'confirmed':
        raise ValidationError(f"Video call not available — appointment status is '{appt.status}'")

    return Response({
        'room_name': appt.video_room_id,
        'jitsi_domain': 'meet.jit.si',
        'display_name': user.full_name,
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_appointment_followups(request, pk):
    followups = Appointment.objects.filter(parent_appointment_id=pk).order_by('scheduled_start')
    serializer = AppointmentSerializer(followups, many=True)
    return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_ice_servers(request):
    if not settings.COTURN_SECRET:
        raise ValidationError("TURN configuration is missing on the server.")
    appointment_id = request.GET.get('appointment_id')
    call_attempt_id = request.GET.get('call_attempt_id')
    if not appointment_id or not call_attempt_id:
        raise ValidationError("Both appointment_id and call_attempt_id are required.")
    # Generate Time-Limited Credentials
    expiry_time = int(time.time()) + 86400  # 24 hours
    username = f"{expiry_time}:{appointment_id}:{call_attempt_id}"
    secret = settings.COTURN_SECRET.encode('utf-8')
    message = username.encode('utf-8')
    hashed = hmac.new(secret, message, hashlib.sha1)
    password = base64.b64encode(hashed.digest()).decode('utf-8')

    # Routing through the frp tunnel on Azure (using PUBLIC_IP from .env)
    # Only port 3478 (control) and the 49152-49202 relay range are tunneled right now.
    PUBLIC_IP = settings.PUBLIC_IP

    return Response({
    'iceServers': [
        # {'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302']},
        {'urls': [f"stun:{settings.COTURN_URL}:3478"]},
        {
            'urls': [f"turn:{settings.COTURN_URL}:3478"],
            'username': username,
            'credential': password,
        },
        {
            'urls': [f"turns:{settings.COTURN_URL}:5349?transport=tcp"],
            'username': username,
            'credential': password,
        },
        # --- PREVIOUSLY USED: frp-tunneled laptop-hosted coturn ---
        # (kept for quick switch-back if needed — laptop must be
        # running coturn+frpc, and Azure running frps, for this to work)
        # {'urls': [f"stun:{PUBLIC_IP}:3478"]},
        # {
        #     'urls': [f"turn:{PUBLIC_IP}:3478"],
        #     'username': username,
        #     'credential': password,
        # },
    ]
})