"""
Vues de l'app membres — inscription, validation admin, profil, annuaire.
"""
import logging
from django.db.models import Q
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.pagination import PageNumberPagination
from rest_framework.exceptions import ValidationError

from apps.users.views import api_response
from .models import Profile
from .serializers import RegisterSerializer, ProfileSerializer, MemberListSerializer, ValidateSerializer
from .services import MemberService
from .permissions import IsAdmin, IsActiveMember

logger = logging.getLogger(__name__)


def _serializer_error(serializer):
    """Extrait le premier message d'erreur d'un serializer invalide."""
    for errors in serializer.errors.values():
        if errors:
            return str(errors[0])
    return "Données invalides."


def _service_error(exc):
    """Extrait le message d'une ValidationError levée par les services."""
    detail = exc.detail
    return str(detail[0]) if isinstance(detail, list) and detail else str(detail)


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        s = RegisterSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        try:
            profile = MemberService.register(s.validated_data["phone"], s.validated_data)
            data = ProfileSerializer(profile, context={"request": request}).data
            return api_response(True, data, "Inscription envoyée. En attente de validation par le bureau.", 201)
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class PendingMembersView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        qs = MemberService.get_pending_members()
        paginator = PageNumberPagination()
        page = paginator.paginate_queryset(qs, request)
        data = MemberListSerializer(page, many=True, context={"request": request}).data
        return paginator.get_paginated_response(data)


class ValidateMemberView(APIView):
    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        s = ValidateSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        d = s.validated_data
        try:
            user = MemberService.validate_member(pk, d["action"], d.get("rejection_reason", ""), request.user)
            msg = "Membre approuvé." if d["action"] == "approve" else "Membre rejeté."
            return api_response(True, message=msg)
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class MyProfileView(APIView):
    permission_classes = [IsActiveMember]

    def get(self, request):
        profile = MemberService.get_member_profile(request.user)
        return api_response(True, ProfileSerializer(profile, context={"request": request}).data)

    def patch(self, request):
        s = ProfileSerializer(data=request.data, partial=True)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        profile = MemberService.update_profile(request.user, s.validated_data)
        return api_response(True, ProfileSerializer(profile, context={"request": request}).data, "Profil mis à jour.")


class MembersListView(APIView):
    permission_classes = [IsActiveMember]

    def get(self, request):
        qs        = MemberService.get_active_members()
        search    = request.query_params.get('search', '').strip()
        situation = request.query_params.get('situation', '').strip()
        if search:
            qs = qs.filter(
                Q(full_name__icontains=search) | Q(specialty__icontains=search) |
                Q(job_title__icontains=search) | Q(neighborhood__icontains=search)
            )
        if situation:
            qs = qs.filter(situation=situation)
        paginator = PageNumberPagination()
        page      = paginator.paginate_queryset(qs, request)
        data      = MemberListSerializer(page, many=True, context={"request": request}).data
        return paginator.get_paginated_response(data)


class MemberDetailView(APIView):
    permission_classes = [IsActiveMember]

    def get(self, request, pk):
        try:
            profile = Profile.objects.select_related('user').get(user__pk=pk, user__status='active')
        except Profile.DoesNotExist:
            return api_response(False, message="Membre introuvable.", status_code=404)
        return api_response(True, MemberListSerializer(profile, context={'request': request}).data)
