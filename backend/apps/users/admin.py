from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ("phone", "role", "status", "is_verified", "is_active", "created_at")
    list_filter = ("role", "status", "is_verified", "is_active")
    search_fields = ("phone",)
    ordering = ("-created_at",)
    readonly_fields = ("created_at", "updated_at")

    # Remplacement des fieldsets par défaut (pas de username/email)
    fieldsets = (
        (None, {"fields": ("phone", "pin_hash")}),
        ("Rôle & statut", {"fields": ("role", "status", "is_verified")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Dates", {"fields": ("created_at", "updated_at", "last_login")}),
    )
    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("phone", "role", "is_staff", "is_superuser"),
        }),
    )
    filter_horizontal = ("groups", "user_permissions")
