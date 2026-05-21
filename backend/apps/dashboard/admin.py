from django.contrib import admin
from .models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ("action", "performed_by", "target_user", "ip_address", "created_at")
    list_filter = ("action",)
    search_fields = ("action", "performed_by__phone", "target_user__phone", "ip_address")
    readonly_fields = ("action", "performed_by", "target_user", "details", "ip_address", "created_at")

    def has_add_permission(self, request):
        """Les entrées d'audit ne se créent qu'en code, pas via l'admin."""
        return False

    def has_change_permission(self, request, obj=None):
        return False
