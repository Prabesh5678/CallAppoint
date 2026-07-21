from rest_framework import serializers
from .models import DoctorProfile, Specialty, DoctorAvailability

class SpecialtySerializer(serializers.ModelSerializer):
    class Meta:
        model = Specialty
        fields = ['id', 'name', 'description', 'icon_url']


class DoctorAvailabilitySerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorAvailability
        fields = ['id', 'day_of_week', 'start_time', 'end_time', 'slot_duration_minutes', 'is_active']


class DoctorListSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='id.full_name', read_only=True)
    avatar_url = serializers.CharField(source='id.avatar_url', read_only=True)
    specialties = serializers.SerializerMethodField()

    class Meta:
        model = DoctorProfile
        fields = [
            'id', 'full_name', 'avatar_url', 'consultation_fee',
            'years_experience', 'average_rating', 'total_reviews', 'specialties',
        ]

    def get_specialties(self, obj):
        return SpecialtySerializer(
            [ds.specialty for ds in obj.doctor_specialties.all()], many=True
        ).data


class DoctorDetailSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='id.full_name', read_only=True)
    avatar_url = serializers.CharField(source='id.avatar_url', read_only=True)
    gender = serializers.CharField(source='id.gender', read_only=True)
    specialties = serializers.SerializerMethodField()
    availability = DoctorAvailabilitySerializer(many=True, read_only=True)

    class Meta:
        model = DoctorProfile
        fields = [
            'id', 'full_name', 'avatar_url', 'gender', 'bio', 'license_number',
            'years_experience', 'consultation_fee', 'verification_status',
            'average_rating', 'total_reviews', 'specialties', 'availability',
        ]

    def get_specialties(self, obj):
        return SpecialtySerializer(
            [ds.specialty for ds in obj.doctor_specialties.all()], many=True
        ).data


class DoctorProfileUpdateSerializer(serializers.ModelSerializer):
    """What a doctor can edit on their own profile."""
    specialty_ids = serializers.ListField(
        child=serializers.UUIDField(),
        write_only=True,
        required=False
    )
    current_specialty_ids = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = DoctorProfile
        fields = ['bio', 'years_experience', 'consultation_fee', 'specialty_ids', 'current_specialty_ids', 'license_number', 'verification_status']
        read_only_fields = ['verification_status']

    def get_current_specialty_ids(self, obj):
        return [ds.specialty_id for ds in obj.doctor_specialties.all()]


class DoctorApplicationSerializer(serializers.ModelSerializer):
    specialty_ids = serializers.ListField(child=serializers.UUIDField(), write_only=True, required=False)

    class Meta:
        model = DoctorProfile
        fields = ['license_number', 'bio', 'years_experience', 'consultation_fee', 'specialty_ids']
        
class DoctorApplicationStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorProfile
        fields = ['verification_status', 'rejection_reason']   

class DoctorAvailabilityCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorAvailability
        fields = ['id', 'day_of_week', 'start_time', 'end_time', 'slot_duration_minutes', 'is_active']
        read_only_fields = ['id']             