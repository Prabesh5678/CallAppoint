from rest_framework import serializers
from .models import MedicalReport

class MedicalReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicalReport
        fields = ['id', 'appointment', 'title', 'file_url', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_at']


class MedicalReportCreateSerializer(serializers.ModelSerializer):
    """
    Called AFTER Flutter has already uploaded the file directly to Supabase
    Storage (patient's own RLS-protected folder). This just records the metadata.
    file_url should be the storage path, e.g. "<patient_id>/report123.pdf" —
    not a public URL, since the bucket is private.
    """
    class Meta:
        model = MedicalReport
        fields = ['appointment', 'title', 'file_url']