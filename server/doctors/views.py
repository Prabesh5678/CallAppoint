from rest_framework import viewsets, generics, filters
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.decorators import action
from accounts.permissions import IsVerifiedDoctor
from .models import DoctorProfile, Specialty
from .serializers import (
    DoctorListSerializer, DoctorDetailSerializer,
    DoctorProfileUpdateSerializer, SpecialtySerializer,
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