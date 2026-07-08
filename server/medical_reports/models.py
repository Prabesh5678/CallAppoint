import uuid
from django.db import models
from accounts.models import User
from appointments.models import Appointment

class MedicalReport(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(User, on_delete=models.CASCADE,
                                 db_column='patient_id', related_name='medical_reports')
    appointment = models.ForeignKey(Appointment, null=True, blank=True, on_delete=models.SET_NULL,
                                     db_column='appointment_id', related_name='medical_reports')
    title = models.CharField(max_length=255)
    file_url = models.TextField()
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'medical_reports'