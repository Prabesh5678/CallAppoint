from django.urls import path
from .views import CreateReviewView, DoctorReviewsView

urlpatterns = [
    path('', CreateReviewView.as_view(), name='create-review'),
    path('doctor/<uuid:doctor_id>/', DoctorReviewsView.as_view(), name='doctor-reviews'),
]