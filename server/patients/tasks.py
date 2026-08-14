from celery import shared_task
from .models import PatientBiomarker, ClinicalDiagnosis, PatientMedicalProfile
from django.core.cache import cache

@shared_task
def precompute_patient_dashboard_data(patient_id):
    """
    Background task to precompute and cache dashboard data for a patient.
    This prevents the mobile app from slowing down during heavy clinical queries.
    """
    from .serializers import PatientMedicalProfileSerializer, ClinicalDiagnosisSerializer
    from accounts.models import User

    # 1. Get Latest Diagnosis
    latest_diag = ClinicalDiagnosis.objects.filter(patient_id=patient_id).order_by('-date_of_diagnosis').first()
    diag_serializer = ClinicalDiagnosisSerializer(latest_diag) if latest_diag else None

    # 2. Get Medical Profile
    profile = PatientMedicalProfile.objects.filter(id=patient_id).first()
    profile_serializer = PatientMedicalProfileSerializer(profile) if profile else None

    # 3. Get Biomarker Trends (Last 5 readings per biomarker)
    biomarkers = PatientBiomarker.objects.filter(patient_id=patient_id).order_by('name', '-recorded_at')
    trends = {}
    for b in biomarkers:
        if b.name not in trends:
            trends[b.name] = []
        if len(trends[b.name]) < 5:
            trends[b.name].append({
                "id": str(b.id),
                "value": float(b.value),
                "unit": b.unit,
                "date": b.recorded_at.isoformat()
            })

    dashboard_cache = {
        "medical_profile": profile_serializer.data if profile_serializer else None,
        "latest_diagnosis": diag_serializer.data if diag_serializer else None,
        "biomarker_summaries": trends,
        "precomputed_at": True
    }

    # Cache for 1 hour
    cache_key = f"patient_dashboard_{patient_id}"
    cache.set(cache_key, dashboard_cache, 3600)

    return f"Dashboard precomputed for patient {patient_id}"
