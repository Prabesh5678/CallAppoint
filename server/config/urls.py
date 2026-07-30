from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse

from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def payment_callback(request):
    return HttpResponse("Payment processed. You can close this window.")

urlpatterns = [
    path('admin/', admin.site.urls),
    # Handle both with and without trailing slash to avoid 301 redirects
    path('payment-callback', payment_callback, name='payment-callback-no-slash'),
    path('payment-callback/', payment_callback, name='payment-callback'),
    path('api/accounts/', include('accounts.urls')),
    path('api/doctors/', include('doctors.urls')),
    path('api/appointments/', include('appointments.urls')),
    path('api/prescriptions/', include('prescriptions.urls')),
    path('api/medical-reports/', include('medical_reports.urls')),
    path('api/reviews/', include('reviews.urls')),
    path('api/notifications/', include('notifications.urls')),
    path('api/chat/', include('chat.urls')),
    path('api/payments/', include('payments.urls')),
    path('api/blogs/', include('blogs.urls')),
    path('api/admin-panel/', include('adminapi.urls')),
    path('api/artifacts/', include('artifacts.urls')),
]
