"""
Services d'authentification — toute la logique métier est ici, jamais dans les vues.
"""
import math
import random
import logging

from django.conf import settings
from django.core.cache import cache
from rest_framework.exceptions import ValidationError
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User

logger = logging.getLogger(__name__)

# Clés Redis — centralisées pour éviter les fautes de frappe
_OTP_KEY = "otp:{phone}"
_OTP_ATTEMPTS_KEY = "otp_attempts:{phone}"
_OTP_BLOCKED_KEY = "otp_blocked:{phone}"
_RESET_PIN_KEY = "reset_pin:{phone}"


class OTPService:

    @staticmethod
    def generate_otp(phone):
        """Génère un OTP à 6 chiffres et le stocke dans Redis. Bloque si le numéro est en quarantaine."""
        blocked_ttl = cache.ttl(_OTP_BLOCKED_KEY.format(phone=phone))
        if blocked_ttl > 0:
            minutes = math.ceil(blocked_ttl / 60)
            raise ValidationError(f"Trop de tentatives. Réessayez dans {minutes} minute(s).")

        code = str(random.randint(100000, 999999))
        cache.set(_OTP_KEY.format(phone=phone), code, timeout=settings.OTP_TTL_SECONDS)
        cache.delete(_OTP_ATTEMPTS_KEY.format(phone=phone))
        return code

    @staticmethod
    def verify_otp(phone, code):
        """
        Vérifie le code OTP. Incrémente le compteur de tentatives et bloque après OTP_MAX_ATTEMPTS échecs.
        Retourne True si le code est correct.
        """
        blocked_ttl = cache.ttl(_OTP_BLOCKED_KEY.format(phone=phone))
        if blocked_ttl > 0:
            minutes = math.ceil(blocked_ttl / 60)
            raise ValidationError(f"Trop de tentatives. Réessayez dans {minutes} minute(s).")

        stored_code = cache.get(_OTP_KEY.format(phone=phone))
        if stored_code is None:
            raise ValidationError("Code expiré ou invalide. Demandez un nouveau code.")

        if str(code) != str(stored_code):
            attempts = (cache.get(_OTP_ATTEMPTS_KEY.format(phone=phone)) or 0) + 1
            cache.set(_OTP_ATTEMPTS_KEY.format(phone=phone), attempts, timeout=settings.OTP_BLOCK_DURATION_SECONDS)

            if attempts >= settings.OTP_MAX_ATTEMPTS:
                cache.set(_OTP_BLOCKED_KEY.format(phone=phone), "1", timeout=settings.OTP_BLOCK_DURATION_SECONDS)
                cache.delete(_OTP_KEY.format(phone=phone))
                cache.delete(_OTP_ATTEMPTS_KEY.format(phone=phone))
                raise ValidationError("Trop de tentatives. Numéro bloqué 15 minutes.")

            remaining = settings.OTP_MAX_ATTEMPTS - attempts
            raise ValidationError(f"Code incorrect. {remaining} tentative(s) restante(s).")

        cache.delete(_OTP_KEY.format(phone=phone))
        cache.delete(_OTP_ATTEMPTS_KEY.format(phone=phone))
        return True

    @staticmethod
    def send_sms(phone, code):
        """Envoie le code par SMS. En mode DEBUG, affiche uniquement dans la console."""
        if settings.DEBUG:
            print(f"[DEV] OTP pour {phone} : {code}")
            logger.info("[DEV] OTP pour %s : %s", phone, code)
            return

        from twilio.rest import Client
        from twilio.base.exceptions import TwilioRestException

        try:
            client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
            message = client.messages.create(
                body=f"Votre code AJVT : {code}. Valable 5 minutes.",
                from_=settings.TWILIO_PHONE_NUMBER,
                to=phone,
            )
            logger.info("SMS OTP envoyé à %s — SID : %s", phone, message.sid)
        except TwilioRestException as e:
            logger.error("Échec envoi SMS à %s : %s", phone, str(e))
            raise ValidationError("Échec envoi SMS. Réessayez.")


class AuthService:

    @staticmethod
    def mark_phone_verified(phone):
        """Marque le numéro comme vérifié (OTP validé). Crée le compte si inexistant."""
        user, _ = User.objects.get_or_create(phone=phone)
        if not user.is_verified:
            user.is_verified = True
            user.save()
        return user

    @staticmethod
    def set_user_pin(phone, raw_pin):
        """Définit ou réinitialise le PIN d'un utilisateur ayant vérifié son numéro."""
        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            raise ValidationError("Aucun compte avec ce numéro.")

        if not user.is_verified:
            raise ValidationError("Téléphone non vérifié. Validez votre OTP d'abord.")

        user.set_pin(raw_pin)
        user.save()
        return user

    @staticmethod
    def authenticate(phone, raw_pin):
        """Authentifie un utilisateur par numéro + PIN. Retourne le User si valide."""
        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            raise ValidationError("Aucun compte avec ce numéro.")

        if not user.check_pin(raw_pin):
            raise ValidationError("PIN incorrect.")

        return user

    @staticmethod
    def generate_tokens(user):
        """Génère une paire de jetons JWT (access + refresh) pour l'utilisateur."""
        refresh = RefreshToken.for_user(user)
        return {"access": str(refresh.access_token), "refresh": str(refresh)}

    @staticmethod
    def create_reset_request(phone):
        """Enregistre une demande de réinitialisation de PIN dans Redis (TTL 10 minutes)."""
        cache.set(_RESET_PIN_KEY.format(phone=phone), "1", timeout=600)

    @staticmethod
    def validate_reset_request(phone):
        """Vérifie qu'une demande de réinitialisation active existe pour ce numéro."""
        if not cache.get(_RESET_PIN_KEY.format(phone=phone)):
            raise ValidationError("Demande de réinitialisation non trouvée ou expirée.")

    @staticmethod
    def delete_reset_request(phone):
        """Supprime la demande de réinitialisation après usage."""
        cache.delete(_RESET_PIN_KEY.format(phone=phone))
