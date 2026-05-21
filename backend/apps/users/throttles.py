"""Throttle custom pour les endpoints OTP — limite par numéro de téléphone."""
from rest_framework.throttling import AnonRateThrottle


class OTPThrottle(AnonRateThrottle):
    """5 requêtes par heure par numéro de téléphone (ou par IP si absent)."""
    scope = "otp"

    def get_cache_key(self, request, view):
        phone = request.data.get("phone", "").strip()
        if phone:
            return f"throttle_otp_{phone}"
        return super().get_cache_key(request, view)
