from rest_framework import serializers
from .models import ChatMessage

class ChatMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatMessage
        fields = ['id', 'appointment', 'sender', 'message', 'attachment_url', 'sent_at', 'is_read']