from django.urls import path
from .views import (
    AdminListPatientsView, AdminListDoctorsView, approve_doctor, reject_doctor, remove_user,
    AdminSpecialtyView, delete_specialty, admin_login,
)

urlpatterns = [
    path('login/', admin_login, name='admin-login'),
    path('patients/', AdminListPatientsView.as_view(), name='admin-patients'),
    path('doctors/', AdminListDoctorsView.as_view(), name='admin-doctors'),
    path('doctors/<uuid:doctor_id>/approve/', approve_doctor, name='admin-approve-doctor'),
    path('doctors/<uuid:doctor_id>/reject/', reject_doctor, name='admin-reject-doctor'),
    path('users/<uuid:user_id>/', remove_user, name='admin-remove-user'),
    path('specialties/', AdminSpecialtyView.as_view(), name='admin-specialties'),
    path('specialties/<uuid:specialty_id>/', delete_specialty, name='admin-delete-specialty'),
]
