from django.urls import re_path
from .consumers import ChatConsumer, VideoSignalConsumer

websocket_urlpatterns = [
    re_path(r'ws/chat/(?P<appointment_id>[0-9a-f-]+)/$', ChatConsumer.as_asgi()),
    re_path(r'ws/video/(?P<appointment_id>[0-9a-f-]+)/$', VideoSignalConsumer.as_asgi()),
]