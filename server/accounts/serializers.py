from rest_framework import serializers
from .models import User

class UserSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(read_only=True)
    role = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'role', 'full_name', 'phone',
            'avatar_url', 'gender', 'date_of_birth', 'is_active'
        ]
        read_only_fields = ['id', 'is_active']

    def validate_phone(self, value):
        if value == "" or value is None:
            return None
        # Check if it is exactly 10 digits
        if not (value.isdigit() and len(value) == 10):
            raise serializers.ValidationError("Phone number must be exactly 10 digits.")
        return value

    def validate_avatar_url(self, value):
        if value == "":
            return None
        return value
