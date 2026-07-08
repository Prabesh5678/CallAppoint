import uuid
from django.db import models
from accounts.models import User

class Notification(models.Model):
    TYPE_CHOICES = [
        ('appointment_booked', 'Appointment Booked'),
        ('appointment_confirmed', 'Appointment Confirmed'),
        ('appointment_cancelled', 'Appointment Cancelled'),
        ('appointment_reminder', 'Appointment Reminder'),
        ('prescription_ready', 'Prescription Ready'),
        ('doctor_verified', 'Doctor Verified'),
        ('general', 'General'),
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, db_column='user_id', related_name='notifications')
    type = models.CharField(max_length=50, choices=TYPE_CHOICES)
    title = models.CharField(max_length=255)
    body = models.TextField(null=True, blank=True)
    data = models.JSONField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'notifications'
        indexes = [models.Index(fields=['user', 'is_read'])]


class DeviceToken(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, db_column='user_id', related_name='device_tokens')
    fcm_token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=20, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'device_tokens'