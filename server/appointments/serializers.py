from rest_framework import serializers
from .models import Appointment

class AppointmentSerializer(serializers.ModelSerializer):
    doctor_name = serializers.CharField(source='doctor.id.full_name', read_only=True)
    patient_name = serializers.CharField(source='patient.full_name', read_only=True)

    class Meta:
        model = Appointment
        fields = [
            'id', 'patient', 'doctor', 'doctor_name', 'patient_name',
            'scheduled_start', 'scheduled_end', 'status', 'reason_for_visit',
            'video_room_id', 'cancellation_reason', 'created_at',
        ]
        read_only_fields = ['id', 'patient', 'status', 'video_room_id', 'created_at']


class AppointmentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Appointment
        fields = ['doctor', 'scheduled_start', 'scheduled_end', 'reason_for_visit']

    def validate(self, data):
        if data['scheduled_end'] <= data['scheduled_start']:
            raise serializers.ValidationError("scheduled_end must be after scheduled_start")
        return data