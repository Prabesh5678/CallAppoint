from django.urls import path
from .views import CreatePrescriptionView, MyPrescriptionsView, PrescriptionDetailView

urlpatterns = [
    path('', CreatePrescriptionView.as_view(), name='create-prescription'),
    path('mine/', MyPrescriptionsView.as_view(), name='my-prescriptions'),
    path('<uuid:pk>/', PrescriptionDetailView.as_view(), name='prescription-detail'),
]