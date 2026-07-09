from rest_framework import serializers
from .models import Prescription, PrescriptionItem

class PrescriptionItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrescriptionItem
        fields = ['id', 'medicine_name', 'dosage', 'frequency', 'duration', 'instructions']


class PrescriptionSerializer(serializers.ModelSerializer):
    items = PrescriptionItemSerializer(many=True, read_only=True)
    doctor_name = serializers.CharField(source='doctor.id.full_name', read_only=True)
    patient_name = serializers.CharField(source='patient.full_name', read_only=True)

    class Meta:
        model = Prescription
        fields = [
            'id', 'appointment', 'doctor', 'doctor_name', 'patient', 'patient_name',
            'diagnosis', 'notes', 'items', 'created_at',
        ]
        read_only_fields = ['id', 'doctor', 'patient', 'created_at']


class PrescriptionItemCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrescriptionItem
        fields = ['medicine_name', 'dosage', 'frequency', 'duration', 'instructions']


class PrescriptionCreateSerializer(serializers.ModelSerializer):
    items = PrescriptionItemCreateSerializer(many=True)

    class Meta:
        model = Prescription
        fields = ['appointment', 'diagnosis', 'notes', 'items']

    def validate_appointment(self, appointment):
        request = self.context['request']
        if str(appointment.doctor_id) != str(request.user.id):
            raise serializers.ValidationError("Not your appointment")
        if appointment.status != 'completed':
            # allow writing during a confirmed/in-progress call too, not just after
            if appointment.status != 'confirmed':
                raise serializers.ValidationError(
                    "Can only prescribe for confirmed or completed appointments"
                )
        return appointment