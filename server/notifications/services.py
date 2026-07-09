from firebase_admin import messaging
from .models import Notification, DeviceToken

def notify_user(*, user_id, type, title, body, data=None):
    """
    Creates the in-app Notification row AND sends an FCM push to every
    registered device for that user. Call this from other apps whenever
    something notification-worthy happens (appointment confirmed, etc).
    """
    Notification.objects.create(
        user_id=user_id, type=type, title=title, body=body, data=data or {},
    )

    tokens = list(DeviceToken.objects.filter(user_id=user_id).values_list('fcm_token', flat=True))
    if not tokens:
        return

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in (data or {}).items()},
        tokens=tokens,
    )
    response = messaging.send_each_for_multicast(message)

    # clean up dead tokens (uninstalled app, expired token, etc.)
    if response.failure_count:
        for idx, result in enumerate(response.responses):
            if not result.success and 'not-registered' in str(result.exception).lower():
                DeviceToken.objects.filter(fcm_token=tokens[idx]).delete()