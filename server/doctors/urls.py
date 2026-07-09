from django.urls import path
from rest_framework.routers import DefaultRouter
from .views import SpecialtyViewSet, DoctorListView, DoctorDetailView, MyDoctorProfileView

router = DefaultRouter()
router.register('specialties', SpecialtyViewSet, basename='specialty')

urlpatterns = [
    path('me/', MyDoctorProfileView.as_view(), name='doctor-me'),
    path('<uuid:pk>/', DoctorDetailView.as_view(), name='doctor-detail'),
    path('', DoctorListView.as_view(), name='doctor-list'),
] + router.urls