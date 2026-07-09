import requests
from django.conf import settings

BUCKET = 'medical-reports'

def create_signed_url(file_path, expires_in=3600):
    """
    Uses the service_role key to bypass RLS and generate a short-lived signed
    URL for a private object. This is the Django-side gate for doctor access —
    RLS on the bucket itself only allows the owning patient + admins.
    """
    url = f"{settings.SUPABASE_URL}/storage/v1/object/sign/{BUCKET}/{file_path}"
    headers = {
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }
    resp = requests.post(url, headers=headers, json={"expiresIn": expires_in}, timeout=10)
    resp.raise_for_status()
    data = resp.json()
    # response is a relative path like "/object/sign/medical-reports/...&token=..."
    return f"{settings.SUPABASE_URL}/storage/v1{data['signedURL']}"