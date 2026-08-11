from django.urls import path
from .views import MyMedicalProfileView, PatientMedicalProfileDetailView

urlpatterns = [
    path('me/', MyMedicalProfileView.as_view(), name='my-medical-profile'),
    path('<uuid:id>/', PatientMedicalProfileDetailView.as_view(), name='patient-medical-profile-detail'),

    # Diagnosis Engine
    path('diagnoses/', ClinicalDiagnosisListCreateView.as_view(), name='diagnosis-list-create'),
    path('diagnoses/<uuid:pk>/', ClinicalDiagnosisDetailView.as_view(), name='diagnosis-detail'),
]
