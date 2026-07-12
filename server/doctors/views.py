from rest_framework import viewsets, generics, filters
from rest_framework.exceptions import ValidationError
from django.db import transaction
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.decorators import action, api_view, permission_classes
from accounts.permissions import IsVerifiedDoctor
from .models import DoctorProfile, Specialty, DoctorSpecialty, DoctorAvailability

from .serializers import (
    DoctorListSerializer, DoctorDetailSerializer,
    DoctorProfileUpdateSerializer, SpecialtySerializer,DoctorApplicationSerializer,
    DoctorApplicationStatusSerializer, DoctorAvailabilityCreateSerializer
)


class SpecialtyViewSet(viewsets.ReadOnlyModelViewSet):
    """GET /api/doctors/specialties/ — list of specialties for filter dropdowns etc."""
    queryset = Specialty.objects.all().order_by('name')
    serializer_class = SpecialtySerializer
    permission_classes = [AllowAny]


class DoctorListView(generics.ListAPIView):
    """
    GET /api/doctors/?search=<name>&specialty=<uuid>&min_fee=&max_fee=&ordering=
    Only shows approved doctors — pending/rejected are not patient-visible.
    """
    serializer_class = DoctorListSerializer
    permission_classes = [AllowAny]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['id__full_name']  # traverses to users.full_name via the OneToOne 'id' field
    ordering_fields = ['consultation_fee', 'average_rating', 'years_experience']
    ordering = ['-average_rating']

    def get_queryset(self):
        qs = DoctorProfile.objects.filter(
            verification_status='approved'
        ).select_related('id').prefetch_related('doctor_specialties__specialty', 'availability')

        specialty_id = self.request.query_params.get('specialty')
        if specialty_id:
            qs = qs.filter(doctor_specialties__specialty_id=specialty_id)

        min_fee = self.request.query_params.get('min_fee')
        max_fee = self.request.query_params.get('max_fee')
        if min_fee:
            qs = qs.filter(consultation_fee__gte=min_fee)
        if max_fee:
            qs = qs.filter(consultation_fee__lte=max_fee)

        return qs.distinct()


class DoctorDetailView(generics.RetrieveAPIView):
    """GET /api/doctors/<uuid:pk>/ — full profile for booking screen."""
    queryset = DoctorProfile.objects.filter(verification_status='approved')
    serializer_class = DoctorDetailSerializer
    permission_classes = [AllowAny]
    lookup_field = 'pk'


class MyDoctorProfileView(generics.RetrieveUpdateAPIView):
    """
    GET/PATCH /api/doctors/me/ — the logged-in doctor manages their own profile.
    Verification fields (status, verified_by, etc.) are intentionally not editable here.
    """
    serializer_class = DoctorProfileUpdateSerializer
    permission_classes = [IsAuthenticated, IsVerifiedDoctor]

    def get_object(self):
        return DoctorProfile.objects.get(id=self.request.user.id)

class ApplyForDoctorView(generics.CreateAPIView):
    serializer_class = DoctorApplicationSerializer
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def perform_create(self, serializer):
        user = self.request.user
        existing = DoctorProfile.objects.filter(id=user.id).first()

        if existing and existing.verification_status != 'rejected':
            raise ValidationError("You've already applied")

        specialty_ids = serializer.validated_data.pop('specialty_ids', [])

        if existing:
            existing.license_number = serializer.validated_data['license_number']
            existing.bio = serializer.validated_data.get('bio', '')
            existing.years_experience = serializer.validated_data.get('years_experience', 0)
            existing.consultation_fee = serializer.validated_data.get('consultation_fee', 0)
            existing.verification_status = 'pending'
            existing.rejection_reason = None
            existing.save()
            profile = existing
            DoctorSpecialty.objects.filter(doctor=profile).delete()
        else:
            profile = DoctorProfile.objects.create(
                id_id=user.id,
                license_number=serializer.validated_data['license_number'],
                bio=serializer.validated_data.get('bio', ''),
                years_experience=serializer.validated_data.get('years_experience', 0),
                consultation_fee=serializer.validated_data.get('consultation_fee', 0),
                verification_status='pending',
            )

        for spec_id in specialty_ids:
            DoctorSpecialty.objects.create(doctor=profile, specialty_id=spec_id)
        self.instance = profile

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response({'detail': 'Application submitted. Awaiting admin review.'}, status=201)         

class MyAvailabilityView(generics.ListCreateAPIView):
    """
    GET  /api/doctors/me/availability/  — list current doctor's weekly schedule
    POST /api/doctors/me/availability/  — add a new weekly slot
    """
    serializer_class = DoctorAvailabilityCreateSerializer
    permission_classes = [IsAuthenticated, IsVerifiedDoctor]

    def get_queryset(self):
        return DoctorAvailability.objects.filter(doctor_id=self.request.user.id).order_by('day_of_week', 'start_time')

    def perform_create(self, serializer):
        serializer.save(doctor_id=self.request.user.id)


class DeleteAvailabilityView(generics.DestroyAPIView):
    """DELETE /api/doctors/me/availability/<uuid:pk>/"""
    permission_classes = [IsAuthenticated, IsVerifiedDoctor]
    queryset = DoctorAvailability.objects.all()

    def get_queryset(self):
        return DoctorAvailability.objects.filter(doctor_id=self.request.user.id)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def application_status(request):
    """GET /api/doctors/application-status/ — null if never applied."""
    profile = DoctorProfile.objects.filter(id=request.user.id).first()
    if not profile:
        return Response(None)
    return Response(DoctorApplicationStatusSerializer(profile).data) 


