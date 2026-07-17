from django.urls import path
from .views import ChatHistoryView, check_video_presence

urlpatterns = [
    path('<uuid:appointment_id>/history/', ChatHistoryView.as_view(), name='chat-history'),
    path('<uuid:appointment_id>/video-presence/', check_video_presence, name='video-presence'),
]
