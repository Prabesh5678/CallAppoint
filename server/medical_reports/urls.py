from django.urls import path
from .views import CreateMedicalReportView, MyMedicalReportsView, get_signed_url

urlpatterns = [
    path('', CreateMedicalReportView.as_view(), name='create-medical-report'),
    path('mine/', MyMedicalReportsView.as_view(), name='my-medical-reports'),
    path('<uuid:pk>/signed-url/', get_signed_url, name='medical-report-signed-url'),
]