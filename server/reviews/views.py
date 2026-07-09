from django.db import transaction
from django.db.models import Avg, Count
from rest_framework import generics
from rest_framework.permissions import AllowAny ,IsAuthenticated
from accounts.permissions import IsPatient
from doctors.models import DoctorProfile
from .models import Review
from .serializers import ReviewSerializer, ReviewCreateSerializer


class CreateReviewView(generics.CreateAPIView):
    """POST /api/reviews/ — patients only, one review per completed appointment."""
    serializer_class = ReviewCreateSerializer
    permission_classes = [IsAuthenticated, IsPatient]

    @transaction.atomic
    def perform_create(self, serializer):
        appointment = serializer.validated_data['appointment']
        review = serializer.save(
            patient_id=self.request.user.id,
            doctor_id=appointment.doctor_id,
        )
        self._recompute_doctor_rating(appointment.doctor_id)
        return review

    def _recompute_doctor_rating(self, doctor_id):
        stats = Review.objects.filter(doctor_id=doctor_id).aggregate(
            avg=Avg('rating'), count=Count('id')
        )
        DoctorProfile.objects.filter(id=doctor_id).update(
            average_rating=round(stats['avg'] or 0, 2),
            total_reviews=stats['count'],
        )


class DoctorReviewsView(generics.ListAPIView):
    """GET /api/reviews/doctor/<uuid>/ — public list of a doctor's reviews."""
    serializer_class = ReviewSerializer
    permission_classes = [AllowAny]  # public

    def get_queryset(self):
        return Review.objects.filter(
            doctor_id=self.kwargs['doctor_id']
        ).select_related('patient').order_by('-created_at')