import logging
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import ValidationError
from accounts.permissions import IsDoctor
from .models import Artifact
from .serializers import ArtifactSerializer, ArtifactCreateSerializer

logger = logging.getLogger(__name__)

class ArtifactListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ArtifactCreateSerializer
        return ArtifactSerializer

    def get_queryset(self):
        user = self.request.user
        queryset = Artifact.objects.none()
        if user.role == 'patient':
            queryset = Artifact.objects.filter(patient_id=user.id)
        elif user.role == 'doctor':
            queryset = Artifact.objects.filter(doctor_id=user.id)

        appointment_id = self.request.query_params.get('appointment')
        if appointment_id:
            queryset = queryset.filter(appointment_id=appointment_id)

        patient_id = self.request.query_params.get('patient')
        if patient_id:
            queryset = queryset.filter(patient_id=patient_id)

        doctor_id = self.request.query_params.get('doctor')
        if doctor_id:
            queryset = queryset.filter(doctor_id=doctor_id)

        return queryset.order_by('-created_at')

    def perform_create(self, serializer):
        try:
            appointment = serializer.validated_data['appointment']

            # Since DoctorProfile PK is the User ID, we can use request.user.id directly
            # to avoid potential lookup issues if DoctorProfile is not yet cached or similar.
            # But Artifact model expects a doctor (DoctorProfile instance).

            serializer.save(
                doctor_id=self.request.user.id,
                patient=appointment.patient
            )
            logger.info(f"Artifact successfully created for appointment {appointment.id} by doctor {self.request.user.id}")
        except Exception as e:
            logger.error(f"Error in Artifact perform_create: {str(e)}")
            raise ValidationError(detail=str(e))
