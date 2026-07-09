from django.urls import path
from .views import MyNotificationsView, mark_notification_read, register_device_token

urlpatterns = [
    path('', MyNotificationsView.as_view(), name='my-notifications'),
    path('<uuid:pk>/read/', mark_notification_read, name='mark-notification-read'),
    path('register-device/', register_device_token, name='register-device-token'),
]