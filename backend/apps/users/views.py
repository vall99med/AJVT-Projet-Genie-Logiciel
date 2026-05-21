"""
Vues d'authentification — chaque vue délègue toute la logique à services.py.
Format de réponse unifié : {"success": bool, "data": {}, "message": ""}
"""
import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.exceptions import ValidationError

from .serializers import (
    OTPRequestSerializer, OTPVerifySerializer, SetPinSerializer,
    LoginSerializer, ResetPinConfirmSerializer, UserSerializer,
)
from .services import OTPService, AuthService
from .throttles import OTPThrottle

logger = logging.getLogger(__name__)


def api_response(success, data=None, message="", status_code=200):
    """Format de réponse unifié pour toute l'API AJVT."""
    return Response({"success": success, "data": data or {}, "message": message}, status=status_code)


def _serializer_error(serializer):
    """Extrait le premier message d'erreur d'un serializer invalide."""
    for errors in serializer.errors.values():
        if errors:
            return str(errors[0])
    return "Données invalides."


def _service_error(exc):
    """Extrait le message d'une ValidationError levée par les services."""
    detail = exc.detail
    if isinstance(detail, list) and detail:
        return str(detail[0])
    return str(detail)


class OTPRequestView(APIView):
    permission_classes  = [AllowAny]
    throttle_classes    = [OTPThrottle]

    def post(self, request):
        s = OTPRequestSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        phone = s.validated_data["phone"]
        try:
            code = OTPService.generate_otp(phone)
            OTPService.send_sms(phone, code)
            return api_response(True, {"phone": phone}, "Code OTP envoyé.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class OTPVerifyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        s = OTPVerifySerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        phone, code = s.validated_data["phone"], s.validated_data["code"]
        try:
            OTPService.verify_otp(phone, code)
            AuthService.mark_phone_verified(phone)
            return api_response(True, {"phone": phone, "next_step": "set_pin"}, "Numéro vérifié.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class SetPinView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        s = SetPinSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        phone, pin = s.validated_data["phone"], s.validated_data["pin"]
        try:
            user = AuthService.set_user_pin(phone, pin)
            tokens = AuthService.generate_tokens(user)
            return api_response(True, {"tokens": tokens, "user": UserSerializer(user).data}, "PIN créé. Bienvenue !", 201)
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        s = LoginSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        phone, pin = s.validated_data["phone"], s.validated_data["pin"]
        try:
            user = AuthService.authenticate(phone, pin)
            tokens = AuthService.generate_tokens(user)
            return api_response(True, {"tokens": tokens, "user": UserSerializer(user).data}, "Connexion réussie.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class ResetPinRequestView(APIView):
    permission_classes  = [AllowAny]
    throttle_classes    = [OTPThrottle]

    def post(self, request):
        s = OTPRequestSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        phone = s.validated_data["phone"]
        try:
            code = OTPService.generate_otp(phone)
            AuthService.create_reset_request(phone)
            OTPService.send_sms(phone, code)
            return api_response(True, {"phone": phone}, "Code de réinitialisation envoyé.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class ResetPinConfirmView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        s = ResetPinConfirmSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        d = s.validated_data
        try:
            AuthService.validate_reset_request(d["phone"])
            OTPService.verify_otp(d["phone"], d["code"])
            AuthService.set_user_pin(d["phone"], d["pin"])
            AuthService.delete_reset_request(d["phone"])
            return api_response(True, message="PIN réinitialisé avec succès.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)
