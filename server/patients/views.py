from django.db.models import Count
from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
import json
import os
from django.conf import settings
from .models import PatientMedicalProfile, ClinicalDiagnosis, PatientBiomarker, GeneticVariant
from .serializers import (
    PatientMedicalProfileSerializer,
    ClinicalDiagnosisSerializer,
    PatientBiomarkerSerializer,
    GeneticVariantSerializer
)
from accounts.permissions import IsPatient, IsDoctor, IsAdmin

class ICD10SearchView(APIView):
    """
    Search for ICD-10 codes for oncology.
    Returns a list of matching codes and names.
    """
    permission_classes = [permissions.IsAuthenticated, IsDoctor]

    def get(self, request):
        query = request.query_params.get('q', '').lower()
        file_path = os.path.join(settings.BASE_DIR, 'patients', 'data', 'icd10_cancer.json')

        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
        except Exception:
            return Response({"error": "ICD data not found"}, status=500)

        if not query:
            return Response(data[:10]) # Return first 10 by default

        results = [
            item for item in data
            if query in item['code'].lower() or query in item['name'].lower()
        ]
        return Response(results[:20])

class MyMedicalProfileView(generics.RetrieveUpdateAPIView):
# ... (existing view)
    serializer_class = PatientMedicalProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        # request.user is a SupabaseUser, request.user.db_user is the Django User model instance
        profile, created = PatientMedicalProfile.objects.get_or_create(id=self.request.user.db_user)
        return profile

class PatientMedicalProfileDetailView(generics.RetrieveAPIView):
    """View for Doctors to see a specific patient's profile"""
    queryset = PatientMedicalProfile.objects.all()
    serializer_class = PatientMedicalProfileSerializer
    permission_classes = [permissions.IsAuthenticated, IsDoctor]
    lookup_field = 'id'

class ClinicalDiagnosisListCreateView(generics.ListCreateAPIView):
    serializer_class = ClinicalDiagnosisSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user.db_user
        if user.role == 'patient':
            return ClinicalDiagnosis.objects.filter(patient=user)
        return ClinicalDiagnosis.objects.all()

    def perform_create(self, serializer):
        # Automatically set the doctor as the one creating the diagnosis
        serializer.save(doctor=self.request.user.db_user)

class ClinicalDiagnosisDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ClinicalDiagnosisSerializer
    permission_classes = [permissions.IsAuthenticated, IsDoctor]
    queryset = ClinicalDiagnosis.objects.all()

class BiomarkerListCreateView(generics.ListCreateAPIView):
    serializer_class = PatientBiomarkerSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user.db_user
        queryset = PatientBiomarker.objects.all()

        # Patients only see their own biomarkers
        if user.role == 'patient':
            queryset = queryset.filter(patient=user)

        # Support filtering by biomarker name (e.g., ?name=PSA) for charts
        name = self.request.query_params.get('name')
        if name:
            queryset = queryset.filter(name__iexact=name)

        return queryset

    def perform_create(self, serializer):
        user = self.request.user.db_user
        if user.role == 'patient':
            # Security Fix: Patients can only record biomarkers for themselves
            serializer.save(patient=user)
        else:
            # Doctors/Admins can record biomarkers for any patient (specified in request body)
            serializer.save()

class GeneticVariantListCreateView(generics.ListCreateAPIView):
    serializer_class = GeneticVariantSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user.db_user
        if user.role == 'patient':
            return GeneticVariant.objects.filter(patient=user)

        # Security Enhancement: Doctors only see variants for patients
        # they have a professional relationship with (via appointments)
        from appointments.models import Appointment
        patient_ids = Appointment.objects.filter(doctor_id=user.id).values_list('patient_id', flat=True)
        queryset = GeneticVariant.objects.filter(patient_id__in=patient_ids)

        # Research Filtering
        gene = self.request.query_params.get('gene')
        significance = self.request.query_params.get('significance')
        if gene:
            queryset = queryset.filter(gene_name__iexact=gene)
        if significance:
            queryset = queryset.filter(clinical_significance=significance)

        return queryset

    def perform_create(self, serializer):
        user = self.request.user.db_user
        if user.role == 'patient':
            raise permissions.PermissionDenied("Genetic data must be entered by a medical professional.")
        serializer.save()

class GeneticVariantDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = GeneticVariantSerializer
    permission_classes = [permissions.IsAuthenticated, IsDoctor]

    def get_queryset(self):
        user = self.request.user.db_user
        from appointments.models import Appointment
        patient_ids = Appointment.objects.filter(doctor_id=user.id).values_list('patient_id', flat=True)
        return GeneticVariant.objects.filter(patient_id__in=patient_ids)

from django.core.cache import cache
from .tasks import precompute_patient_dashboard_data

class PatientDashboardView(APIView):
    """
    Consolidated dashboard for the mobile app.
    Uses cached precomputed data from background jobs to keep the app fast.
    """
    permission_classes = [permissions.IsAuthenticated, IsPatient]

    def get(self, request):
        patient_id = request.user.id
        cache_key = f"patient_dashboard_{patient_id}"
        dashboard_data = cache.get(cache_key)

        if not dashboard_data:
            # If cache is empty, trigger a background job to compute it for next time
            # and return live data once for this request.
            precompute_patient_dashboard_data.delay(patient_id)

            # (Fall back to live computation if cache miss)
            latest_diag = ClinicalDiagnosis.objects.filter(patient_id=patient_id).order_by('-date_of_diagnosis').first()
            diag_serializer = ClinicalDiagnosisSerializer(latest_diag) if latest_diag else None

            profile = PatientMedicalProfile.objects.filter(id=patient_id).first()
            profile_serializer = PatientMedicalProfileSerializer(profile) if profile else None

            dashboard_data = {
                "medical_profile": profile_serializer.data if profile_serializer else None,
                "latest_diagnosis": diag_serializer.data if diag_serializer else None,
                "is_live": True # Flag for UI to show data is being refreshed in background
            }

        return Response(dashboard_data)

class PatientTrendView(APIView):
    """Returns time-series data for a specific biomarker for a specific patient."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, patient_id):
        user = request.user.db_user

        # Security Enhancement:
        if user.role == 'patient':
            if str(user.id) != str(patient_id):
                return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)
        elif user.role == 'doctor':
            # Doctors only see trends for patients they have a professional relationship with
            from appointments.models import Appointment
            exists = Appointment.objects.filter(doctor_id=user.id, patient_id=patient_id).exists()
            if not exists:
                return Response({"error": "Access Denied: No professional relationship with this patient."},
                                status=status.HTTP_403_FORBIDDEN)

        biomarker_name = request.query_params.get('name')
        if not biomarker_name:
            return Response({"error": "Biomarker 'name' parameter required"}, status=status.HTTP_400_BAD_REQUEST)

        data = PatientBiomarker.objects.filter(
            patient_id=patient_id,
            name__iexact=biomarker_name
        ).order_by('recorded_at')

        first_entry = data.first()
        return Response({
            "biomarker": biomarker_name,
            "unit": first_entry.unit if first_entry else None,
            "trends": [
                {"date": d.recorded_at.date(), "value": d.value} for d in data
            ]
        })

class ClinicalResearchAnalyticsView(APIView):
    """Aggregated stats for medical research (Restricted to Admin/Verified Doctors)"""
    permission_classes = [permissions.IsAuthenticated, IsAdmin | IsDoctor]

    def get(self, request):
        # 1. Distribution of Cancer Stages
        stage_dist = ClinicalDiagnosis.objects.values('overall_stage').annotate(count=Count('id')).order_by('overall_stage')

        # 2. Smoking Status in Population
        smoking_stats = PatientMedicalProfile.objects.values('smoking_status').annotate(count=Count('id'))

        # 3. Most Common Genetic Variants
        top_genes = GeneticVariant.objects.values('gene_name').annotate(count=Count('id')).order_by('-count')[:10]

        return Response({
            "stage_distribution": stage_dist,
            "lifestyle_smoking": smoking_stats,
            "common_genetic_variants": top_genes,
            "total_patients": PatientMedicalProfile.objects.count()
        })
