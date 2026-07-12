from django.contrib import admin
from django.utils import timezone
from django.db import connection
from .models import DoctorProfile, VerificationDocument, Specialty, DoctorSpecialty


@admin.action(description="Approve selected doctor applications")
def approve_doctors(modeladmin, request, queryset):
    for profile in queryset:
        profile.verification_status = 'approved'
        profile.verified_at = timezone.now()
        profile.rejection_reason = None
        profile.save()
        with connection.cursor() as cursor:
            cursor.execute("UPDATE users SET role = 'doctor' WHERE id = %s", [str(profile.id_id)])


@admin.register(DoctorProfile)
class DoctorProfileAdmin(admin.ModelAdmin):
    list_display = ['id', 'license_number', 'verification_status', 'consultation_fee', 'created_at']
    list_filter = ['verification_status']
    fields = ['license_number', 'bio', 'years_experience', 'consultation_fee', 'verification_status', 'rejection_reason']
    actions = [approve_doctors]
    # To reject: open the application, set verification_status to "rejected",
    # type a reason in rejection_reason, then Save.


@admin.register(Specialty)
class SpecialtyAdmin(admin.ModelAdmin):
    list_display = ['name']


@admin.register(VerificationDocument)
class VerificationDocumentAdmin(admin.ModelAdmin):
    list_display = ['doctor', 'document_type', 'uploaded_at']