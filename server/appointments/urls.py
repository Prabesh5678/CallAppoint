from django.urls import path
from .views import (
    available_slots, MyAppointmentsView, BookAppointmentView,
    respond_to_appointment, cancel_appointment,
)

urlpatterns = [
    path('mine/', MyAppointmentsView.as_view(), name='my-appointments'),
    path('book/', BookAppointmentView.as_view(), name='book-appointment'),
    path('doctor/<uuid:doctor_id>/slots/', available_slots, name='available-slots'),
    path('<uuid:pk>/respond/', respond_to_appointment, name='respond-appointment'),
    path('<uuid:pk>/cancel/', cancel_appointment, name='cancel-appointment'),
]