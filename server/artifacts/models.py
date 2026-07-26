import uuid
from django.db import models
from accounts.models import User
from doctors.models import DoctorProfile
from appointments.models import Appointment

class Artifact(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.ForeignKey(Appointment, on_delete=models.CASCADE,
                                     db_column='appointment_id', related_name='artifacts')
    doctor = models.ForeignKey(DoctorProfile, on_delete=models.CASCADE, db_column='doctor_id')
    patient = models.ForeignKey(User, on_delete=models.CASCADE, db_column='patient_id')
    report_type = models.CharField(max_length=100) # e.g., 'Clinical Note', 'Referral', 'Diagnosis'
    title = models.CharField(max_length=255)
    content = models.TextField(null=True, blank=True)
    file_url = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'artifacts'
