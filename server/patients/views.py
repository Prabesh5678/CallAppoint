from rest_framework import generics, permissions, status
from rest_framework.response import Response
from .models import PatientMedicalProfile, ClinicalDiagnosis, PatientBiomarker
from .serializers import (
    PatientMedicalProfileSerializer,
    ClinicalDiagnosisSerializer,
    PatientBiomarkerSerializer
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
