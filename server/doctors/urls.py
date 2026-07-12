from django.urls import path
from rest_framework.routers import DefaultRouter
from .views import (SpecialtyViewSet, DoctorListView, DoctorDetailView,
 MyDoctorProfileView,ApplyForDoctorView, application_status, MyAvailabilityView, DeleteAvailabilityView)

router = DefaultRouter()
router.register('specialties', SpecialtyViewSet, basename='specialty')

urlpatterns = [
    path('me/', MyDoctorProfileView.as_view(), name='doctor-me'),
    path('<uuid:pk>/', DoctorDetailView.as_view(), name='doctor-detail'),
    path('', DoctorListView.as_view(), name='doctor-list'),
    path('apply/', ApplyForDoctorView.as_view(), name='apply_doctor'),
    path('application-status/', application_status, name='doctor-application-status'),
    path('me/availability/', MyAvailabilityView.as_view(), name='my-availability'),
    path('me/availability/<uuid:pk>/', DeleteAvailabilityView.as_view(), name='delete-availability'),
] + router.urls