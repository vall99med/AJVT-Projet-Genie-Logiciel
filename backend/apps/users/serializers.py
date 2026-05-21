from rest_framework import serializers
from .models import User
from .utils import validate_international_phone


class OTPRequestSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)

    def validate_phone(self, value):
        return validate_international_phone(value)


class OTPVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    code = serializers.CharField(min_length=6, max_length=6)

    def validate_phone(self, value):
        return validate_international_phone(value)


class SetPinSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    pin = serializers.CharField(min_length=4, max_length=4)
    pin_confirm = serializers.CharField(min_length=4, max_length=4)

    def validate_phone(self, value):
        return validate_international_phone(value)

    def validate_pin(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("Le PIN doit contenir uniquement des chiffres.")
        return value

    def validate(self, attrs):
        if attrs["pin"] != attrs["pin_confirm"]:
            raise serializers.ValidationError({"pin_confirm": "Les PIN ne correspondent pas."})
        return attrs


class LoginSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    pin = serializers.CharField(min_length=4, max_length=4)

    def validate_phone(self, value):
        return validate_international_phone(value)

    def validate_pin(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("Le PIN doit contenir uniquement des chiffres.")
        return value


class ResetPinConfirmSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    code = serializers.CharField(min_length=6, max_length=6)
    pin = serializers.CharField(min_length=4, max_length=4)
    pin_confirm = serializers.CharField(min_length=4, max_length=4)

    def validate_phone(self, value):
        return validate_international_phone(value)

    def validate_pin(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("Le PIN doit contenir uniquement des chiffres.")
        return value

    def validate(self, attrs):
        if attrs["pin"] != attrs["pin_confirm"]:
            raise serializers.ValidationError({"pin_confirm": "Les PIN ne correspondent pas."})
        return attrs


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = read_only_fields = ("id", "phone", "role", "status", "is_verified", "created_at")
