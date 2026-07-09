from django.urls import path
from .views import ChatHistoryView

urlpatterns = [
    path('<uuid:appointment_id>/history/', ChatHistoryView.as_view(), name='chat-history'),
]