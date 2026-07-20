from rest_framework import viewsets, permissions, filters, status
from rest_framework.response import Response
from rest_framework.decorators import action
from django.db.models import Q
from .models import Blog
from .serializers import BlogSerializer
from accounts.permissions import IsDoctor
from appointments.models import Appointment

class BlogViewSet(viewsets.ModelViewSet):
    queryset = Blog.objects.all()
    serializer_class = BlogSerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['title', 'content', 'doctor__id__full_name']
    ordering_fields = ['created_at', 'updated_at']

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAuthenticated(), IsDoctor()]
        return [permissions.IsAuthenticated()]

    def perform_create(self, serializer):
        # The user is a doctor (checked by IsDoctor permission)
        serializer.save(doctor_id=self.request.user.id)

    def get_queryset(self):
        queryset = super().get_queryset()

        # Filter by "My Doctors" for patients
        my_doctors_only = self.request.query_params.get('my_doctors', 'false').lower() == 'true'
        if my_doctors_only and hasattr(self.request.user, 'role') and self.request.user.role == 'patient':
            # Get IDs of doctors the patient has had appointments with
            doctor_ids = Appointment.objects.filter(patient_id=self.request.user.id).values_list('doctor_id', flat=True).distinct()
            queryset = queryset.filter(doctor_id__in=doctor_ids)

        # Filter by "My Own Blogs" for doctors
        my_blogs_only = self.request.query_params.get('my_blogs', 'false').lower() == 'true'
        if my_blogs_only and self.request.user.role == 'doctor':
            queryset = queryset.filter(doctor_id=self.request.user.id)

        return queryset

    def update(self, request, *args, **kwargs):
        # Ensure only the author can update
        blog = self.get_object()
        # Ensure string comparison as request.user.id is a string but blog.doctor_id is a UUID object
        if str(blog.doctor_id) != str(request.user.id):
            return Response({"detail": "You do not have permission to edit this blog."},
                            status=status.HTTP_403_FORBIDDEN)
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        # Ensure only the author can delete
        blog = self.get_object()
        if str(blog.doctor_id) != str(request.user.id):
            return Response({"detail": "You do not have permission to delete this blog."},
                            status=status.HTTP_403_FORBIDDEN)
        return super().destroy(request, *args, **kwargs)
