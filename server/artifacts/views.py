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
        if user.role == 'patient':
            return Artifact.objects.filter(patient_id=user.id).order_by('-created_at')
        elif user.role == 'doctor':
            return Artifact.objects.filter(doctor_id=user.id).order_by('-created_at')
        return Artifact.objects.none()

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
