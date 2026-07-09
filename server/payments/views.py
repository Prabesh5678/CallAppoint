from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, PermissionDenied, NotFound
from accounts.permissions import IsPatient
from appointments.models import Appointment
from .models import Payment
from .serializers import PaymentSerializer
from .gateways import khalti


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsPatient])
def initiate_khalti_payment(request, appointment_id):
    """POST /api/payments/khalti/initiate/<uuid:appointment_id>/"""
    try:
        appointment = Appointment.objects.select_related('doctor').get(
            pk=appointment_id, patient_id=request.user.id
        )
    except Appointment.DoesNotExist:
        raise NotFound("Appointment not found")

    if Payment.objects.filter(appointment=appointment, status='success').exists():
        raise ValidationError("Appointment already paid")

    fee = appointment.doctor.consultation_fee
    amount_paisa = int(fee * 100)

    khalti_resp = khalti.initiate_payment(
        amount_paisa=amount_paisa,
        purchase_order_id=str(appointment.id),
        purchase_order_name=f"Consultation with Dr. {appointment.doctor.id.full_name}",
        customer={
            "name": request.user.db_user.full_name,
            "email": request.user.email or "",
            "phone": request.user.db_user.phone or "9800000000",
        },
    )

    payment = Payment.objects.create(
        appointment=appointment,
        patient_id=request.user.id,
        amount=fee,
        gateway='khalti',
        gateway_txn_id=khalti_resp['pidx'],
        status='pending',
    )

    return Response({
        'payment_id': str(payment.id),
        'pidx': khalti_resp['pidx'],
        'payment_url': khalti_resp.get('payment_url'),  # unused by Flutter SDK, harmless to include
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsPatient])
def verify_khalti_payment(request):
    """
    POST /api/payments/khalti/verify/  body: {"pidx": "..."}
    Called by Flutter right after the Khalti SDK reports completion.
    Never trust the SDK result alone — always re-check server-to-server.
    """
    pidx = request.data.get('pidx')
    if not pidx:
        raise ValidationError("pidx is required")

    try:
        payment = Payment.objects.get(gateway_txn_id=pidx, patient_id=request.user.id)
    except Payment.DoesNotExist:
        raise NotFound("Payment record not found")

    lookup = khalti.lookup_payment(pidx)

    if lookup['status'] == 'Completed' and int(lookup['total_amount']) == int(payment.amount * 100):
        payment.status = 'success'
        payment.save()
    elif lookup['status'] in ('User canceled', 'Expired', 'Failed'):
        payment.status = 'failed'
        payment.save()
    # else: still Pending/Refunded/etc — leave as-is, caller can poll again

    return Response(PaymentSerializer(payment).data)


class MyPaymentsView(generics.ListAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated, IsPatient]

    def get_queryset(self):
        return Payment.objects.filter(patient_id=self.request.user.id).order_by('-created_at')