import json
from django.apps import AppConfig
from django.conf import settings
from decouple import config

class NotificationsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'notifications'

    def ready(self):
        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:
            return

        firebase_json = config('FIREBASE_CREDENTIALS_JSON', default=None)
        if firebase_json:
            # production: credentials passed as a raw JSON string env var
            cred_dict = json.loads(firebase_json)
            cred = credentials.Certificate(cred_dict)
        else:
            # local dev: fall back to a file path
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)

        firebase_admin.initialize_app(cred)