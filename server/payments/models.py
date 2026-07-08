import uuid
from django.db import models
from accounts.models import User
from appointments.models import Appointment

class Payment(models.Model):
    STATUS_CHOICES = [('pending', 'Pending'), ('success', 'Success'), ('failed', 'Failed'), ('refunded', 'Refunded')]
    GATEWAY_CHOICES = [('khalti', 'Khalti'), ('esewa', 'eSewa')]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.ForeignKey(Appointment, on_delete=models.CASCADE,
                                     db_column='appointment_id', related_name='payments')
    patient = models.ForeignKey(User, on_delete=models.CASCADE, db_column='patient_id')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    gateway = models.CharField(max_length=20, choices=GATEWAY_CHOICES)
    gateway_txn_id = models.CharField(max_length=255, null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'payments'