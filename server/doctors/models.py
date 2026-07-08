import uuid
from django.db import models
from accounts.models import User

class DoctorProfile(models.Model):
    STATUS_CHOICES = [('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')]

    id = models.OneToOneField(User, primary_key=True, db_column='id',
                               on_delete=models.CASCADE, related_name='doctor_profile')
    license_number = models.CharField(max_length=255, unique=True)
    bio = models.TextField(null=True, blank=True)
    years_experience = models.IntegerField(default=0)
    consultation_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    verification_status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL,
                                     db_column='verified_by', related_name='verified_doctors')
    average_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)
    total_reviews = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'doctor_profiles'

    def __str__(self):
        return f"Dr. {self.id.full_name}"


class VerificationDocument(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    doctor = models.ForeignKey(DoctorProfile, on_delete=models.CASCADE,
                                db_column='doctor_id', related_name='verification_documents')
    document_type = models.CharField(max_length=100)
    file_url = models.TextField()
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'verification_documents'


class Specialty(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255, unique=True)
    description = models.TextField(null=True, blank=True)
    icon_url = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'specialties'

    def __str__(self):
        return self.name


class DoctorSpecialty(models.Model):
    doctor = models.ForeignKey(DoctorProfile, on_delete=models.CASCADE, db_column='doctor_id')
    specialty = models.ForeignKey(Specialty, on_delete=models.CASCADE, db_column='specialty_id')

    class Meta:
        managed = False
        db_table = 'doctor_specialties'
        unique_together = ('doctor', 'specialty')


class DoctorAvailability(models.Model):
    DAY_CHOICES = [(0, 'Sun'), (1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'), (5, 'Fri'), (6, 'Sat')]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    doctor = models.ForeignKey(DoctorProfile, on_delete=models.CASCADE,
                                db_column='doctor_id', related_name='availability')
    day_of_week = models.SmallIntegerField(choices=DAY_CHOICES)
    start_time = models.TimeField()
    end_time = models.TimeField()
    slot_duration_minutes = models.IntegerField(default=15)
    is_active = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = 'doctor_availability'


class DoctorAvailabilityException(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    doctor = models.ForeignKey(DoctorProfile, on_delete=models.CASCADE,
                                db_column='doctor_id', related_name='availability_exceptions')
    date = models.DateField()
    is_unavailable = models.BooleanField(default=True)
    start_time = models.TimeField(null=True, blank=True)
    end_time = models.TimeField(null=True, blank=True)
    reason = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'doctor_availability_exceptions'