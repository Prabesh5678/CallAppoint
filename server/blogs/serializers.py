from rest_framework import serializers
from .models import Blog
from doctors.models import DoctorProfile

class BlogSerializer(serializers.ModelSerializer):
    doctor_name = serializers.ReadOnlyField(source='doctor.id.full_name')
    doctor_avatar_url = serializers.SerializerMethodField()
    doctor_id = serializers.ReadOnlyField(source='doctor.id.id')

    class Meta:
        model = Blog
        fields = [
            'id', 'doctor_id', 'doctor_name', 'doctor_avatar_url',
            'title', 'content', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'doctor_id', 'created_at', 'updated_at']

    def get_doctor_avatar_url(self, obj):
        # Assuming there's an avatar_url field in the User model linked to DoctorProfile
        return obj.doctor.id.avatar_url if hasattr(obj.doctor.id, 'avatar_url') else None

    def validate_title(self, value):
        if len(value) > 200:
            raise serializers.ValidationError("Title cannot exceed 200 characters.")
        if len(value) < 5:
            raise serializers.ValidationError("Title must be at least 5 characters long.")
        return value

    def validate_content(self, value):
        if len(value) > 10000:
            raise serializers.ValidationError("Content cannot exceed 10000 characters.")
        if len(value) < 20:
            raise serializers.ValidationError("Content must be at least 20 characters long.")
        return value
