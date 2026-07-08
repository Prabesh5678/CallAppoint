import uuid
from django.db import models
from accounts.models import User
from doctors.models import DoctorProfile

class Appointment(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'), ('confirmed', 'Confirmed'), ('rejected', 'Rejected'),
        ('cancelled', 'Cancelled'), ('completed', 'Completed'), ('no_show', 'No Show'),
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(User, on_delete=models.CASCADE,
                                 db_column='patient_id', related_name='patient_appointments')
    doctor = models.ForeignKey(DoctorProfile, on_delete=models.CASCADE,
                                db_column='doctor_id', related_name='doctor_appointments')
    scheduled_start = models.DateTimeField()
    scheduled_end = models.DateTimeField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    reason_for_visit = models.TextField(null=True, blank=True)
    video_room_id = models.CharField(max_length=255, null=True, blank=True)
    cancelled_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL,
                                      db_column='cancelled_by', related_name='cancelled_appointments')
    cancellation_reason = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'appointments'
        indexes = [
            models.Index(fields=['doctor', 'scheduled_start']),
            models.Index(fields=['patient']),
        ]

    def __str__(self):
        return f"{self.patient_id} w/ {self.doctor_id} @ {self.scheduled_start}"