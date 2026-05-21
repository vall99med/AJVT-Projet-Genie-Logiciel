"""
Routes principales de l'API AJVT.
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/auth/", include("apps.users.urls")),
    path("api/members/", include("apps.members.urls")),
    path("api/payments/", include("apps.payments.urls")),
    path("api/dashboard/", include("apps.dashboard.urls")),
    path("api/", include("apps.posts.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
