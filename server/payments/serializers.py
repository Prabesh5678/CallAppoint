from rest_framework import serializers
from .models import Payment

class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ['id', 'appointment', 'patient', 'amount', 'gateway', 'gateway_txn_id', 'status', 'created_at']
        read_only_fields = fields