from django.contrib import admin
from .models import Profile


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ("full_name", "user", "situation", "neighborhood", "validated_at")
    list_filter = ("situation", "validated_at")
    search_fields = ("full_name", "user__phone", "neighborhood")
    readonly_fields = ("created_at", "updated_at", "validated_at", "validated_by")
    raw_id_fields = ("user",)
    fieldsets = (
        ("Identité", {"fields": ("user", "full_name", "photo")}),
        ("Situation", {"fields": ("situation", "specialty", "study_level", "job_title", "neighborhood")}),
        ("Validation", {"fields": ("validated_by", "validated_at", "rejection_reason")}),
        ("Dates", {"fields": ("created_at", "updated_at")}),
    )
