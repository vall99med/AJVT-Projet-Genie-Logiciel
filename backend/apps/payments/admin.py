from django.contrib import admin
from .models import Payment


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ("__str__", "year", "amount", "status", "payment_mode", "paid_at")
    list_filter = ("status", "payment_mode", "year")
    search_fields = ("user__phone", "user__profile__full_name")
    readonly_fields = ("created_at",)
    raw_id_fields = ("user", "validated_by")
    fieldsets = (
        ("Cotisation", {"fields": ("user", "year", "amount", "status", "payment_mode")}),
        ("Validation", {"fields": ("paid_at", "validated_by", "notes")}),
        ("Dates", {"fields": ("created_at",)}),
    )
