from rest_framework import serializers
from .models import Review

class ReviewSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.full_name', read_only=True)

    class Meta:
        model = Review
        fields = ['id', 'appointment', 'patient', 'patient_name', 'doctor', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'patient', 'doctor', 'created_at']


class ReviewCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = ['appointment', 'rating', 'comment']

    def validate_rating(self, value):
        if not (1 <= value <= 5):
            raise serializers.ValidationError("rating must be between 1 and 5")
        return value

    def validate_appointment(self, appointment):
        request = self.context['request']
        if str(appointment.patient_id) != str(request.user.id):
            raise serializers.ValidationError("Not your appointment")
        if appointment.status != 'completed':
            raise serializers.ValidationError("Can only review completed appointments")
        if hasattr(appointment, 'review'):
            raise serializers.ValidationError("Appointment already reviewed")
        return appointment