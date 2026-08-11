from django.urls import path
from .views import MyMedicalProfileView, PatientMedicalProfileDetailView

urlpatterns = [
    path('me/', MyMedicalProfileView.as_view(), name='my-medical-profile'),
    path('<uuid:id>/', PatientMedicalProfileDetailView.as_view(), name='patient-medical-profile-detail'),

    # Diagnosis Engine
    path('diagnoses/', ClinicalDiagnosisListCreateView.as_view(), name='diagnosis-list-create'),
    path('diagnoses/<uuid:pk>/', ClinicalDiagnosisDetailView.as_view(), name='diagnosis-detail'),

    # Biomarker Tracker
    path('biomarkers/', BiomarkerListCreateView.as_view(), name='biomarker-list-create'),

    # Precision/Genomic Layer
    path('genetics/', GeneticVariantListCreateView.as_view(), name='genetic-variant-list-create'),
    path('genetics/<uuid:pk>/', GeneticVariantDetailView.as_view(), name='genetic-variant-detail'),
]
