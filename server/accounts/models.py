from django.db import models

class User(models.Model):
    ROLE_CHOICES = [
        ('patient', 'Patient'),
        ('doctor', 'Doctor'),
        ('admin', 'Admin'),
    ]
    id = models.UUIDField(primary_key=True, editable=False)  # = auth.users.id, row created by Supabase trigger
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='patient')
    full_name = models.CharField(max_length=255)
    phone = models.CharField(max_length=32, unique=True, null=True, blank=True)
    avatar_url = models.TextField(null=True, blank=True)
    gender = models.CharField(max_length=32, null=True, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'users'

    def __str__(self):
        return f"{self.full_name} ({self.role})"