from django.urls import path
from .views import (
    available_slots, MyAppointmentsView, BookAppointmentView,
    respond_to_appointment, cancel_appointment,get_video_room, get_ice_servers,
    get_appointment_followups
)

urlpatterns = [
    path('mine/', MyAppointmentsView.as_view(), name='my-appointments'),
    path('book/', BookAppointmentView.as_view(), name='book-appointment'),
    path('doctor/<uuid:doctor_id>/slots/', available_slots, name='available-slots'),
    path('<uuid:pk>/respond/', respond_to_appointment, name='respond-appointment'),
    path('<uuid:pk>/cancel/', cancel_appointment, name='cancel-appointment'),
    path('<uuid:pk>/video-room/', get_video_room, name='video-room'),
    path('<uuid:pk>/followups/', get_appointment_followups, name='appointment-followups'),
    path('ice-servers/', get_ice_servers, name='ice-servers'),
]
