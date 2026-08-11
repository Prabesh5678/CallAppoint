from rest_framework import serializers
from .models import PatientMedicalProfile

class PatientMedicalProfileSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='id.full_name', read_only=True)

    class Meta:
        model = PatientMedicalProfile
        fields = [
            'id', 'full_name', 'blood_group', 'smoking_status',
            'alcohol_consumption', 'exercise_frequency', 'allergies',
            'chronic_conditions', 'family_cancer_history',
            'family_history_details', 'updated_at'
        ]
        read_only_fields = ['id', 'updated_at']

class ClinicalDiagnosisSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.full_name', read_only=True)
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True)

    class Meta:
        model = ClinicalDiagnosis
        fields = [
            'id', 'patient', 'patient_name', 'doctor', 'doctor_name',
            'icd_code', 'condition_name', 'date_of_diagnosis',
            'tumor_stage', 'nodes_stage', 'metastasis_stage', 'overall_stage',
            'histology', 'is_active', 'notes', 'created_at'
        ]
        read_only_fields = ['id', 'doctor', 'created_at']

class PatientBiomarkerSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientBiomarker
        fields = [
            'id', 'patient', 'name', 'value', 'unit',
            'reference_range', 'recorded_at', 'notes', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']
