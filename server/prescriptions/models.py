import uuid
from django.db import models
from accounts.models import User
from doctors.models import DoctorProfile
from appointments.models import Appointment

class Prescription(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.ForeignKey(Appointment, on_delete=models.CASCADE,
                                     db_column='appointment_id', related_name='prescriptions')
    doctor = models.ForeignKey(DoctorProfile, on_delete=models.CASCADE, db_column='doctor_id')
    patient = models.ForeignKey(User, on_delete=models.CASCADE, db_column='patient_id')
    diagnosis = models.TextField(null=True, blank=True)
    notes = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'prescriptions'


class PrescriptionItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    prescription = models.ForeignKey(Prescription, on_delete=models.CASCADE,
                                      db_column='prescription_id', related_name='items')
    medicine_name = models.CharField(max_length=255)
    dosage = models.CharField(max_length=100, null=True, blank=True)
    frequency = models.CharField(max_length=100, null=True, blank=True)
    duration = models.CharField(max_length=100, null=True, blank=True)
    instructions = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'prescription_items'