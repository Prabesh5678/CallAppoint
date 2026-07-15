from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from django.utils import timezone
from django.db import connection
from accounts.admin_auth import StaticAdminAuthentication
from accounts.models import User
from doctors.models import DoctorProfile, Specialty


class AdminListPatientsView(APIView):
    authentication_classes = [StaticAdminAuthentication]
    permission_classes = []

    def get(self, request):
        patients = User.objects.filter(role='patient').values(
            'id', 'full_name', 'email', 'phone', 'is_active', 'created_at'
        ).order_by('-created_at')
        return Response(list(patients))


class AdminListDoctorsView(APIView):
    authentication_classes = [StaticAdminAuthentication]
    permission_classes = []

    def get(self, request):
        status_filter = request.query_params.get('status')  # pending/approved/rejected
        qs = DoctorProfile.objects.select_related('id')
        if status_filter:
            qs = qs.filter(verification_status=status_filter)
        data = [{
            'id': str(d.id_id),
            'full_name': d.id.full_name,
            'email': d.id.email,
            'license_number': d.license_number,
            'verification_status': d.verification_status,
            'consultation_fee': str(d.consultation_fee),
            'created_at': d.created_at,
        } for d in qs]
        return Response(data)


@api_view(['POST'])
@authentication_classes([StaticAdminAuthentication])
@permission_classes([])
def approve_doctor(request, doctor_id):
    try:
        profile = DoctorProfile.objects.get(id=doctor_id)
    except DoctorProfile.DoesNotExist:
        return Response({'detail': 'Not found'}, status=404)

    profile.verification_status = 'approved'
    profile.verified_at = timezone.now()
    profile.rejection_reason = None
    profile.save()

    with connection.cursor() as cursor:
        cursor.execute("UPDATE users SET role = 'doctor' WHERE id = %s", [str(doctor_id)])

    return Response({'detail': 'Doctor approved'})


@api_view(['DELETE'])
@authentication_classes([StaticAdminAuthentication])
@permission_classes([])
def remove_user(request, user_id):
    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({'detail': 'Not found'}, status=404)
    user.delete()
    return Response({'detail': 'User removed'})


class AdminSpecialtyView(APIView):
    authentication_classes = [StaticAdminAuthentication]
    permission_classes = []

    def get(self, request):
        specialties = Specialty.objects.all().values('id', 'name', 'description')
        return Response(list(specialties))

    def post(self, request):
        name = request.data.get('name')
        description = request.data.get('description', '')
        if not name:
            return Response({'detail': 'name is required'}, status=400)
        specialty = Specialty.objects.create(name=name, description=description)
        return Response({'id': str(specialty.id), 'name': specialty.name}, status=201)


@api_view(['DELETE'])
@authentication_classes([StaticAdminAuthentication])
@permission_classes([])
def delete_specialty(request, specialty_id):
    Specialty.objects.filter(id=specialty_id).delete()
    return Response({'detail': 'Deleted'})
