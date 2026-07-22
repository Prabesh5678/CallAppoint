import hmac, hashlib, base64, time
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
from django.conf import settings


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
    serializer_class = AppointmentCreateSerializer
    permission_classes = [IsAuthenticated, IsPatient]

    def perform_create(self, serializer):
        data = serializer.validated_data
        slots = get_available_slots(data['doctor'].pk, data['scheduled_start'].date())

        requested_start = _ensure_aware(data['scheduled_start'])
        requested_end = _ensure_aware(data['scheduled_end'])

        slot_matches = any(
            s['start'] == requested_start and s['end'] == requested_end and s['is_available']
            for s in slots
        )
        if not slot_matches:
            raise ValidationError("Selected slot is no longer available")

        serializer.save(patient_id=self.request.user.id, status='pending')
    
        notify_user(
            user_id=data['doctor'].id_id,
            type='appointment_booked',
            title='New appointment request',
            body=f'A patient requested a booking on {data["scheduled_start"].strftime("%b %d, %I:%M %p")}',
            data={'appointment_id': str(serializer.instance.id)},
        )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        # return the full appointment (including id) using the READ serializer, not the create one
        output = AppointmentSerializer(serializer.instance)
        return Response(output.data, status=status.HTTP_201_CREATED)


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


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_ice_servers(request):
    """
    Generates dynamic, time-limited CoTurn credentials using HMAC-SHA1.
    Valid for 24 hours.
    """
    if not settings.COTURN_SECRET:
        # Fallback to public STUN if secret is missing (for safety)
        return Response({
            'iceServers': [{'urls': ['stun:turn.20-2-129-98.sslip.io:3478']}]
        })

    # CoTurn uses UTC unix timestamp for time-limited credentials
    expiry_time = int(time.time()) + 86400  # 24 hours
    username = f"{expiry_time}:{request.user.id}" # Standard format: timestamp:username

    # Generate HMAC-SHA1 signature as the password
    secret = settings.COTURN_SECRET.encode('utf-8')
    message = username.encode('utf-8')

    hashed = hmac.new(secret, message, hashlib.sha1)
    password = base64.b64encode(hashed.digest()).decode('utf-8')

    return Response({
        'iceServers': [
            {'urls': ['stun:turn.20-2-129-98.sslip.io:3478']},
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
        ]
    })
    # LOCAL_COTURN_IP = "192.168.1.75"
    # LOCAL_COTURN_SECRET = "9fbd4867d6ac8a6bcfef49b00d53e71d6822c16696821c7f689146b5a7d331fa"  # from /etc/turnserver.conf

    # ttl_seconds = 86400  # 24 hours
    # username = str(int(time.time()) + ttl_seconds)
    # credential = base64.b64encode(
    #     hmac.new(LOCAL_COTURN_SECRET.encode(), username.encode(), hashlib.sha1).digest()
    # ).decode()

    # return Response({
    #     'iceServers': [
    #         {'urls': [f'stun:{LOCAL_COTURN_IP}:3478']},
    #         {
    #             'urls': [f'turn:{LOCAL_COTURN_IP}:3478?transport=udp'],
    #             'username': username,
    #             'credential': credential,
    #         },
    #     ]
    # })
