from django.urls import path
from .views import ArtifactListCreateView

urlpatterns = [
    path('', ArtifactListCreateView.as_view(), name='artifact-list-create'),
]
