from rest_framework import generics, permissions, status
from rest_framework.response import Response
from .models import PatientMedicalProfile, ClinicalDiagnosis, PatientBiomarker, GeneticVariant
from .serializers import (
    PatientMedicalProfileSerializer,
    ClinicalDiagnosisSerializer,
    PatientBiomarkerSerializer,
    GeneticVariantSerializer
)
from accounts.permissions import IsPatient, IsDoctor

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
