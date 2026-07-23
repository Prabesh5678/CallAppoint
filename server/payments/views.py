from django.db import transaction
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, PermissionDenied, NotFound
from accounts.permissions import IsPatient
from appointments.models import Appointment
from appointments.services import get_available_slots
from .models import Payment
from doctors.models import DoctorProfile
from .serializers import PaymentSerializer
from .gateways import khalti
from notifications.services import notify_user
from datetime import datetime

@api_view(['POST'])
@permission_classes([IsAuthenticated, IsPatient])
def initiate_khalti_payment(request):
    """
    POST /api/payments/khalti/initiate/
    body: {"doctor": "<uuid>", "scheduled_start": "...", "scheduled_end": "...", "reason_for_visit": "..."}
    No Appointment is created yet — only after payment is verified.
    """
    doctor_id = request.data.get('doctor')
    scheduled_start = request.data.get('scheduled_start')
    scheduled_end = request.data.get('scheduled_end')
    reason = request.data.get('reason_for_visit', '')

    if not all([doctor_id, scheduled_start, scheduled_end]):
        raise ValidationError("doctor, scheduled_start, scheduled_end are required")

    try:
        doctor = DoctorProfile.objects.get(id=doctor_id, verification_status='approved')
    except DoctorProfile.DoesNotExist:
        raise ValidationError("Invalid doctor")

    start_dt = datetime.fromisoformat(scheduled_start)
    end_dt = datetime.fromisoformat(scheduled_end)

    # confirm the slot is genuinely open before taking payment
    slots = get_available_slots(doctor.pk, start_dt.date())
    slot_matches = any(
        s['start'] == start_dt and s['end'] == end_dt and s['is_available']
        for s in slots
    )
    if not slot_matches:
        raise ValidationError("Selected slot is no longer available")

    fee = doctor.consultation_fee
    amount_paisa = int(fee * 100)

    khalti_resp = khalti.initiate_payment(
        amount_paisa=amount_paisa,
        purchase_order_id=f"booking-{request.user.id}-{start_dt.isoformat()}",
        purchase_order_name=f"Consultation with Dr. {doctor.id.full_name}",
        customer={
            "name": request.user.db_user.full_name,
            "email": request.user.email or "",
            "phone": request.user.db_user.phone or "9800000000",
        },
    )

    payment = Payment.objects.create(
        appointment=None,
        patient_id=request.user.id,
        amount=fee,
        gateway='khalti',
        gateway_txn_id=khalti_resp['pidx'],
        status='pending',
        doctor=doctor,
        scheduled_start=start_dt,
        scheduled_end=end_dt,
        reason_for_visit=reason,
    )

    return Response({
        'payment_id': str(payment.id),
        'pidx': khalti_resp['pidx'],
        'payment_url': khalti_resp.get('payment_url'),
    }, status=status.HTTP_201_CREATED)

@api_view(['POST'])
@permission_classes([IsAuthenticated, IsPatient])
@transaction.atomic
def verify_khalti_payment(request):
    """
    POST /api/payments/khalti/verify/  body: {"pidx": "..."}
    Creates the Appointment (status='confirmed') only if payment is verified successful.
    """
    pidx = request.data.get('pidx')
    if not pidx:
        raise ValidationError("pidx is required")

    try:
        payment = Payment.objects.select_for_update().get(gateway_txn_id=pidx, patient_id=request.user.id)
    except Payment.DoesNotExist:
        raise NotFound("Payment record not found")

    if payment.appointment_id:
        # already processed (e.g. retry call) — just return current state
        return Response(PaymentSerializer(payment).data)

    lookup = khalti.lookup_payment(pidx)

    if lookup['status'] == 'Completed' and int(lookup['total_amount']) == int(payment.amount * 100):
        # Lock the doctor profile to ensure slot availability check is consistent
        DoctorProfile.objects.select_for_update().get(id=payment.doctor_id)

        # re-check slot is still open right before creating the appointment (race guard)
        slots = get_available_slots(payment.doctor_id, payment.scheduled_start.date())
        slot_matches = any(
            s['start'] == payment.scheduled_start and s['end'] == payment.scheduled_end and s['is_available']
            for s in slots
        )
        if not slot_matches:
            payment.status = 'refunded'  # flag for manual refund — slot got taken during checkout
            payment.save()
            raise ValidationError("Slot was booked by someone else during payment. Contact support for a refund.")

        appt = Appointment.objects.create(
            patient_id=request.user.id,
            doctor_id=payment.doctor_id,
            scheduled_start=payment.scheduled_start,
            scheduled_end=payment.scheduled_end,
            reason_for_visit=payment.reason_for_visit,
            status='confirmed',
            video_room_id=None,  # set below, needs appt.id first
        )
        appt.video_room_id = f"callappoint-{appt.id}"
        appt.save()

        payment.status = 'success'
        payment.appointment = appt
        payment.save()

        notify_user(
            user_id=payment.doctor_id,
            type='appointment_confirmed',
            title='New paid appointment',
            body=f'A patient paid and confirmed a booking on {appt.scheduled_start.strftime("%b %d, %I:%M %p")}',
            data={'appointment_id': str(appt.id)},
        )
    elif lookup['status'] in ('User canceled', 'Expired', 'Failed'):
        payment.status = 'failed'
        payment.save()

    return Response(PaymentSerializer(payment).data)
    
class MyPaymentsView(generics.ListAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated, IsPatient]

    def get_queryset(self):
        return Payment.objects.filter(patient_id=self.request.user.id).order_by('-created_at')