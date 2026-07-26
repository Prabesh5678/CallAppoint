from rest_framework import serializers
from .models import Artifact

class ArtifactSerializer(serializers.ModelSerializer):
    doctor_name = serializers.CharField(source='doctor.id.full_name', read_only=True)
    patient_name = serializers.CharField(source='patient.full_name', read_only=True)

    class Meta:
        model = Artifact
        fields = [
            'id', 'appointment', 'doctor', 'doctor_name', 'patient', 'patient_name',
            'report_type', 'title', 'content', 'file_url', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'doctor', 'patient', 'created_at', 'updated_at']

class ArtifactCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Artifact
        fields = ['appointment', 'report_type', 'title', 'content', 'file_url']

    def validate_appointment(self, appointment):
        request = self.context['request']
        print(f"Validating appointment: {appointment.id} for user: {request.user.id}")
        if str(appointment.doctor_id) != str(request.user.id):
            print(f"Validation failed: {appointment.doctor_id} != {request.user.id}")
            raise serializers.ValidationError("This appointment is not assigned to you.")
        return appointment
