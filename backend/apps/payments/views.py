"""
Vues des cotisations, de la carte membre et du tableau de bord.
"""
import logging
from datetime import datetime
from django.http import HttpResponse
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from apps.users.views import api_response
from apps.members.permissions import IsAdmin, IsActiveMember
from .serializers import (
    PaymentSerializer,
    CreatePaymentSerializer,
    SubmitPaymentSerializer,
    ReviewPaymentSerializer,
)
from .services import PaymentService

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


class MemberCardView(APIView):
    permission_classes = [IsActiveMember]

    def get(self, request):
        data = PaymentService.get_member_card(request.user)
        return api_response(True, data)


class SubmitPaymentView(APIView):
    """Le membre soumet son reçu de paiement mobile (multipart/form-data)."""
    permission_classes = [IsActiveMember]
    parser_classes     = [MultiPartParser, FormParser]

    def post(self, request):
        s = SubmitPaymentSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        try:
            PaymentService.submit_payment(request.user, s.validated_data)
            return api_response(True, message="Reçu soumis. En attente de vérification.", status_code=201)
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class ReviewPaymentView(APIView):
    """L'admin approuve ou rejette un reçu soumis."""
    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        s = ReviewPaymentSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        try:
            PaymentService.review_payment(
                pk,
                s.validated_data["action"],
                s.validated_data.get("rejection_reason", ""),
                request.user,
            )
            msg = "Paiement approuvé." if s.validated_data["action"] == "approve" else "Paiement rejeté."
            return api_response(True, message=msg)
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class SubmittedPaymentsView(APIView):
    """Liste tous les reçus soumis en attente de vérification (admin)."""
    permission_classes = [IsAdmin]

    def get(self, request):
        qs       = PaymentService.get_submitted_payments()
        paginator = PageNumberPagination()
        page     = paginator.paginate_queryset(qs, request)
        serializer = PaymentSerializer(page, many=True, context={"request": request})
        return paginator.get_paginated_response(serializer.data)


class CreatePaymentView(APIView):
    """Enregistrement direct d'une cotisation cash par l'admin."""
    permission_classes = [IsAdmin]
    parser_classes     = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        s = CreatePaymentSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        try:
            payment = PaymentService.create_payment(
                s.validated_data["user_id"], s.validated_data, request.user
            )
            return api_response(True, PaymentSerializer(payment).data, "Cotisation enregistrée.", 201)
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class MyPaymentsView(APIView):
    permission_classes = [IsActiveMember]

    def get(self, request):
        qs        = PaymentService.get_member_payments(request.user)
        paginator = PageNumberPagination()
        page      = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response(PaymentSerializer(page, many=True).data)


class AllPaymentsView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        filters = {
            "year":   request.query_params.get("year"),
            "status": request.query_params.get("status"),
        }
        qs        = PaymentService.get_all_payments(filters)
        paginator = PageNumberPagination()
        page      = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response(PaymentSerializer(page, many=True).data)


class DashboardStatsView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        return api_response(True, PaymentService.get_dashboard_stats())


class ExportMembersView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        today   = datetime.now().strftime("%Y-%m-%d")
        content = PaymentService.export_members_excel()
        response = HttpResponse(
            content,
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        response["Content-Disposition"] = f'attachment; filename="membres_ajvt_{today}.xlsx"'
        return response
