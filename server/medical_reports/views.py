from rest_framework import generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied, NotFound
from accounts.permissions import IsPatient
from appointments.models import Appointment
from .models import MedicalReport
from .serializers import MedicalReportSerializer, MedicalReportCreateSerializer
from .storage import create_signed_url


class CreateMedicalReportView(generics.CreateAPIView):
    """POST /api/medical-reports/ — patient records metadata after direct Storage upload."""
    serializer_class = MedicalReportCreateSerializer
    permission_classes = [IsAuthenticated, IsPatient]

    def perform_create(self, serializer):
        serializer.save(patient_id=self.request.user.id)


class MyMedicalReportsView(generics.ListAPIView):
    """GET /api/medical-reports/mine/ — patient's own report list (metadata only, no file access yet)."""
    serializer_class = MedicalReportSerializer
    permission_classes = [IsAuthenticated, IsPatient]

    def get_queryset(self):
        return MedicalReport.objects.filter(patient_id=self.request.user.id).order_by('-uploaded_at')


def _doctor_shares_appointment_with_patient(doctor_id, patient_id):
    return Appointment.objects.filter(
        doctor_id=doctor_id, patient_id=patient_id,
    ).exclude(status__in=['cancelled', 'rejected']).exists()


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_signed_url(request, pk):
    """
    GET /api/medical-reports/<uuid>/signed-url/
    Owning patient: always allowed.
    Doctor: allowed only if they share a non-cancelled/rejected appointment with the patient.
    Admin: always allowed.
    """
    try:
        report = MedicalReport.objects.get(pk=pk)
    except MedicalReport.DoesNotExist:
        raise NotFound("Report not found")

    user = request.user
    allowed = (
        str(report.patient_id) == str(user.id)
        or user.role == 'admin'
        or (user.role == 'doctor' and _doctor_shares_appointment_with_patient(user.id, report.patient_id))
    )
    if not allowed:
        raise PermissionDenied("You don't have access to this report")

    signed_url = create_signed_url(report.file_url)
    return Response({'signed_url': signed_url, 'expires_in': 3600})