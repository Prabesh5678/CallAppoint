from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from accounts.permissions import IsDoctor
from .models import Artifact
from .serializers import ArtifactSerializer, ArtifactCreateSerializer

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

        return queryset.order_by('-created_at')

    def perform_create(self, serializer):
        try:
            appointment = serializer.validated_data['appointment']
            from doctors.models import DoctorProfile
            doctor_profile = DoctorProfile.objects.get(id=self.request.user.id)

            serializer.save(
                doctor=doctor_profile,
                patient=appointment.patient
            )
            print("Artifact successfully saved to database")
        except Exception as e:
            print(f"Error in perform_create: {str(e)}")
            raise e
