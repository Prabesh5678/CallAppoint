from rest_framework.permissions import BasePermission

class IsPatient(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.role == 'patient')

class IsDoctor(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.role == 'doctor')

class IsAdmin(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.role == 'admin')

class IsVerifiedDoctor(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user and user.role == 'doctor'
            and hasattr(user.db_user, 'doctor_profile')
            and user.db_user.doctor_profile.verification_status == 'approved'
        )