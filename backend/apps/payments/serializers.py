from datetime import datetime
from rest_framework import serializers
from .models import Payment

_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
_MAX_RECEIPT_BYTES   = 5 * 1024 * 1024  # 5 Mo


def _current_year():
    return datetime.now().year


class PaymentSerializer(serializers.ModelSerializer):
    member_name       = serializers.SerializerMethodField()
    is_current_year   = serializers.SerializerMethodField()
    receipt_image_url = serializers.SerializerMethodField()

    class Meta:
        model  = Payment
        fields = (
            "id", "year", "amount", "status", "payment_mode",
            "transaction_ref", "receipt_image_url",
            "submitted_at", "reviewed_at", "rejection_reason",
            "paid_at", "notes", "created_at", "member_name", "is_current_year",
        )
        read_only_fields = ("id", "paid_at", "created_at")

    def get_member_name(self, obj):
        try:
            return obj.user.profile.full_name or obj.user.phone
        except Exception:
            return obj.user.phone

    def get_is_current_year(self, obj):
        return obj.year == datetime.now().year

    def get_receipt_image_url(self, obj):
        if not obj.receipt_image:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.receipt_image.url)
        return obj.receipt_image.url


class SubmitPaymentSerializer(serializers.Serializer):
    """Utilisé par le membre pour soumettre son reçu de paiement mobile."""
    year            = serializers.IntegerField(default=_current_year)
    amount          = serializers.DecimalField(max_digits=10, decimal_places=2)
    payment_mode    = serializers.ChoiceField(choices=Payment.PaymentMode.choices)
    transaction_ref = serializers.CharField(required=False, allow_blank=True, default="")
    receipt_image   = serializers.ImageField()

    def validate_year(self, value):
        current = datetime.now().year
        if value < 2020 or value > current + 1:
            raise serializers.ValidationError(
                f"L'année doit être comprise entre 2020 et {current + 1}."
            )
        return value

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Le montant doit être supérieur à 0.")
        return value

    def validate_receipt_image(self, value):
        if value.content_type not in _ALLOWED_IMAGE_TYPES:
            raise serializers.ValidationError("Format non supporté. Utilisez JPG ou PNG.")
        if value.size > _MAX_RECEIPT_BYTES:
            raise serializers.ValidationError("L'image ne doit pas dépasser 5 Mo.")
        return value


class ReviewPaymentSerializer(serializers.Serializer):
    """Utilisé par l'admin pour approuver ou rejeter un reçu soumis."""
    action           = serializers.ChoiceField(choices=["approve", "reject"])
    rejection_reason = serializers.CharField(required=False, allow_blank=True, default="")

    def validate(self, data):
        if data["action"] == "reject" and not data.get("rejection_reason", "").strip():
            raise serializers.ValidationError(
                {"rejection_reason": "Le motif de rejet est obligatoire."}
            )
        return data


class CreatePaymentSerializer(serializers.Serializer):
    """Utilisé par l'admin pour enregistrer une cotisation cash directement."""
    user_id      = serializers.IntegerField()
    year         = serializers.IntegerField(default=_current_year)
    amount       = serializers.DecimalField(max_digits=10, decimal_places=2)
    payment_mode = serializers.ChoiceField(choices=Payment.PaymentMode.choices)
    notes        = serializers.CharField(required=False, allow_blank=True, default="")

    def validate_year(self, value):
        current = datetime.now().year
        if value < 2020 or value > current + 1:
            raise serializers.ValidationError(
                f"L'année doit être comprise entre 2020 et {current + 1}."
            )
        return value

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Le montant doit être supérieur à 0.")
        return value


class MemberCardSerializer(serializers.Serializer):
    """Représente les données de la carte membre digitale."""
    full_name         = serializers.CharField()
    phone             = serializers.CharField()
    neighborhood      = serializers.CharField()
    situation         = serializers.CharField()
    cotisation_status = serializers.CharField()
    cotisation_year   = serializers.IntegerField()
    member_since      = serializers.IntegerField()
    rejection_reason  = serializers.CharField()
