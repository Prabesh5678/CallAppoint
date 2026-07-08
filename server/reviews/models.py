import uuid
from django.db import models
from accounts.models import User
from doctors.models import DoctorProfile
from appointments.models import Appointment

class Review(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.OneToOneField(Appointment, on_delete=models.CASCADE,
                                        db_column='appointment_id', related_name='review')
    patient = models.ForeignKey(User, on_delete=models.CASCADE, db_column='patient_id')
    doctor = models.ForeignKey(DoctorProfile, on_delete=models.CASCADE,
                                db_column='doctor_id', related_name='reviews')
    rating = models.SmallIntegerField()
    comment = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'reviews'