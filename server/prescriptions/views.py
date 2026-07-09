from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from django.db import transaction
from accounts.permissions import IsDoctor
from .models import Prescription, PrescriptionItem
from .serializers import PrescriptionSerializer, PrescriptionCreateSerializer


class CreatePrescriptionView(generics.CreateAPIView):
    """POST /api/prescriptions/ — doctors only, tied to one of their appointments."""
    serializer_class = PrescriptionCreateSerializer
    permission_classes = [IsAuthenticated, IsDoctor]

    @transaction.atomic
    def perform_create(self, serializer):
        items_data = serializer.validated_data.pop('items')
        appointment = serializer.validated_data['appointment']
        prescription = Prescription.objects.create(
            appointment=appointment,
            doctor_id=self.request.user.id,
            patient_id=appointment.patient_id,
            diagnosis=serializer.validated_data.get('diagnosis', ''),
            notes=serializer.validated_data.get('notes', ''),
        )
        PrescriptionItem.objects.bulk_create([
            PrescriptionItem(prescription=prescription, **item) for item in items_data
        ])
        self.instance = prescription

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        output = PrescriptionSerializer(self.instance)
        return Response(output.data, status=201)


class MyPrescriptionsView(generics.ListAPIView):
    """GET /api/prescriptions/mine/ — patient sees their own, doctor sees ones they wrote."""
    serializer_class = PrescriptionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = Prescription.objects.prefetch_related('items').select_related('doctor__id', 'patient')
        if user.role == 'patient':
            return qs.filter(patient_id=user.id).order_by('-created_at')
        elif user.role == 'doctor':
            return qs.filter(doctor_id=user.id).order_by('-created_at')
        return Prescription.objects.none()


class PrescriptionDetailView(generics.RetrieveAPIView):
    """GET /api/prescriptions/<uuid>/ — only the patient it belongs to or the prescribing doctor."""
    serializer_class = PrescriptionSerializer
    permission_classes = [IsAuthenticated]
    queryset = Prescription.objects.prefetch_related('items')

    def get_object(self):
        obj = super().get_object()
        user = self.request.user
        if str(obj.patient_id) != str(user.id) and str(obj.doctor_id) != str(user.id):
            raise PermissionDenied("Not your prescription")
        return obj