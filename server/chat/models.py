import uuid
from django.db import models
from accounts.models import User
from appointments.models import Appointment

class ChatMessage(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.ForeignKey(Appointment, on_delete=models.CASCADE,
                                     db_column='appointment_id', related_name='chat_messages')
    sender = models.ForeignKey(User, on_delete=models.CASCADE, db_column='sender_id')
    message = models.TextField(null=True, blank=True)
    attachment_url = models.TextField(null=True, blank=True)
    sent_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    class Meta:
        managed = False
        db_table = 'chat_messages'
        indexes = [models.Index(fields=['appointment', 'sent_at'])]