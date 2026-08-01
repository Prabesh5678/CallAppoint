from rest_framework import serializers
from .models import ChatMessage

class ChatMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatMessage
        fields = ['id', 'appointment', 'sender', 'message', 'file_url', 'file_name', 'message_type', 'sent_at', 'is_read']
