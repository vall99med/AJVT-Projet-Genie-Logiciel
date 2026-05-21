from rest_framework import serializers
from apps.users.utils import validate_international_phone
from .models import Profile


class RegisterSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    full_name = serializers.CharField(max_length=200)
    situation = serializers.ChoiceField(choices=Profile.Situation.choices)
    specialty = serializers.CharField(required=False, allow_blank=True, default="")
    study_level = serializers.CharField(required=False, allow_blank=True, default="")
    job_title = serializers.CharField(required=False, allow_blank=True, default="")
    neighborhood = serializers.CharField(required=False, allow_blank=True, default="")

    def validate_phone(self, value):
        return validate_international_phone(value)


class ProfileSerializer(serializers.ModelSerializer):
    """Serializer de lecture/écriture pour le profil personnel."""
    photo = serializers.SerializerMethodField()

    class Meta:
        model = Profile
        fields = (
            "id", "full_name", "situation", "specialty", "study_level",
            "job_title", "neighborhood", "photo", "created_at",
        )
        read_only_fields = ("id", "created_at")

    def get_photo(self, obj):
        if not obj.photo:
            return None
        request = self.context.get("request")
        return request.build_absolute_uri(obj.photo.url) if request else obj.photo.url


class MemberListSerializer(serializers.ModelSerializer):
    """Serializer pour les listes (annuaire et liste admin). Source : Profile."""
    id = serializers.IntegerField(source="user.id", read_only=True)  # ID utilisateur pour /validate/
    phone = serializers.CharField(source="user.phone", read_only=True)
    status = serializers.CharField(source="user.status", read_only=True)
    role = serializers.CharField(source="user.role", read_only=True)
    photo = serializers.SerializerMethodField()
    cotisation_status = serializers.SerializerMethodField()
    member_since = serializers.SerializerMethodField()

    class Meta:
        model = Profile
        fields = (
            "id", "full_name", "situation", "specialty", "job_title",
            "neighborhood", "photo", "phone", "status", "role",
            "cotisation_status", "member_since",
        )

    def get_photo(self, obj):
        if not obj.photo:
            return None
        request = self.context.get("request")
        return request.build_absolute_uri(obj.photo.url) if request else obj.photo.url

    def get_cotisation_status(self, obj):
        """Vérifie si le membre a payé sa cotisation pour l'année en cours."""
        from apps.payments.models import Payment
        from django.utils import timezone
        paid = Payment.objects.filter(
            user=obj.user, year=timezone.now().year, status=Payment.Status.PAID
        ).exists()
        return Payment.Status.PAID if paid else Payment.Status.PENDING

    def get_member_since(self, obj):
        """Année d'inscription du membre."""
        return obj.user.created_at.year


class ValidateSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=["approve", "reject"])
    rejection_reason = serializers.CharField(required=False, allow_blank=True, default="")
