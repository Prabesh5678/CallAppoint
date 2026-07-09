from django.urls import path
from .views import initiate_khalti_payment, verify_khalti_payment, MyPaymentsView

urlpatterns = [
    path('khalti/initiate/<uuid:appointment_id>/', initiate_khalti_payment, name='khalti-initiate'),
    path('khalti/verify/', verify_khalti_payment, name='khalti-verify'),
    path('mine/', MyPaymentsView.as_view(), name='my-payments'),
]