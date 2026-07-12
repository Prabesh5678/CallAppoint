import requests
from django.conf import settings

# Use https://dev.khalti.com/api/v2/epayment/ for testing,
# https://khalti.com/api/v2/epayment/ for production — swap via env var.
KHALTI_BASE = getattr(settings, 'KHALTI_BASE_URL', 'https://dev.khalti.com/api/v2/epayment')

def initiate_payment(*, amount_paisa, purchase_order_id, purchase_order_name, customer):
    """
    amount_paisa: integer, amount * 100 (Khalti requires paisa, not rupees).
    customer: {"name": ..., "email": ..., "phone": ...}
    Returns dict with 'pidx' and 'payment_url' (payment_url only relevant if you
    ever add a web flow — Flutter SDK just needs the pidx).
    """
    resp = requests.post(
        f"{KHALTI_BASE}/initiate/",
        headers={
            "Authorization": f"key {settings.KHALTI_SECRET_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "return_url": settings.KHALTI_RETURN_URL,
            "website_url": settings.KHALTI_WEBSITE_URL,
            "amount": amount_paisa,
            "purchase_order_id": purchase_order_id,
            "purchase_order_name": purchase_order_name,
            "customer_info": customer,
        },
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()


def lookup_payment(pidx):
    """Server-to-server verification — the only source of truth for payment status."""
    resp = requests.post(
        f"{KHALTI_BASE}/lookup/",
        headers={"Authorization": f"key {settings.KHALTI_SECRET_KEY}"},
        json={"pidx": pidx},
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()