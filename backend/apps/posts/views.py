"""Vues du fil d'actualité et des événements."""
import logging
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import AllowAny, IsAuthenticatedOrReadOnly
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.exceptions import ValidationError

from apps.users.views import api_response
from apps.members.permissions import IsAdmin, IsAdminOrModerator, IsActiveMember
from .serializers import (
    PostSerializer, CreatePostSerializer,
    EventSerializer, CreateEventSerializer,
    ParticipantSerializer, MarkAttendanceSerializer,
)
from .services import PostService, EventService

logger = logging.getLogger(__name__)


def _serializer_error(serializer):
    for errors in serializer.errors.values():
        if errors:
            return str(errors[0])
    return "Données invalides."


def _service_error(exc):
    detail = exc.detail
    return str(detail[0]) if isinstance(detail, list) and detail else str(detail)


# ── Articles ──────────────────────────────────────────────────────────────────

class PostListView(APIView):
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get(self, request):
        qs        = PostService.get_published_posts(request.user)
        paginator = PageNumberPagination()
        page      = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response(
            PostSerializer(page, many=True, context={"request": request}).data
        )


class PostDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pk):
        try:
            from .models import Post
            post = Post.objects.select_related(
                "author", "author__profile"
            ).get(pk=pk, status=Post.Status.PUBLISHED)
        except Exception:
            return api_response(False, message="Article introuvable.", status_code=404)
        return api_response(True, PostSerializer(post, context={"request": request}).data)


class CreatePostView(APIView):
    permission_classes = [IsAdminOrModerator]
    parser_classes     = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        s = CreatePostSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        post = PostService.create_post(s.validated_data, request.user)
        return api_response(True, PostSerializer(post, context={"request": request}).data,
                            "Article créé.", 201)


class PublishPostView(APIView):
    permission_classes = [IsAdminOrModerator]

    def patch(self, request, pk):
        try:
            post = PostService.publish_post(pk, request.user)
            return api_response(True, PostSerializer(post, context={"request": request}).data,
                                "Article publié.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class DeletePostView(APIView):
    permission_classes = [IsAdminOrModerator]

    def delete(self, request, pk):
        try:
            PostService.delete_post(pk, request.user)
            return api_response(True, message="Article supprimé.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


# ── Événements ────────────────────────────────────────────────────────────────

class EventListView(APIView):
    permission_classes = [IsActiveMember]

    def get(self, request):
        qs        = EventService.get_events()
        paginator = PageNumberPagination()
        page      = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response(
            EventSerializer(page, many=True, context={"request": request}).data
        )


class EventDetailView(APIView):
    permission_classes = [IsActiveMember]

    def get(self, request, pk):
        try:
            event = EventService.get_event(pk)
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=404)
        return api_response(True, EventSerializer(event, context={"request": request}).data)


class CreateEventView(APIView):
    permission_classes = [IsAdminOrModerator]
    parser_classes     = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        s = CreateEventSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        try:
            event = EventService.create_event(s.validated_data, request.user)
            return api_response(True, EventSerializer(event, context={"request": request}).data,
                                "Événement créé.", 201)
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class JoinEventView(APIView):
    permission_classes = [IsActiveMember]

    def post(self, request, pk):
        try:
            EventService.join_event(pk, request.user)
            return api_response(True, message="Inscription confirmée.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class LeaveEventView(APIView):
    permission_classes = [IsActiveMember]

    def delete(self, request, pk):
        try:
            EventService.leave_event(pk, request.user)
            return api_response(True, message="Désinscription effectuée.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)


class EventParticipantsView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request, pk):
        qs = EventService.get_event_participants(pk)
        return api_response(True, ParticipantSerializer(qs, many=True).data)


class MarkAttendanceView(APIView):
    permission_classes = [IsAdminOrModerator]

    def patch(self, request, pk):
        s = MarkAttendanceSerializer(data=request.data)
        if not s.is_valid():
            return api_response(False, message=_serializer_error(s), status_code=400)
        try:
            EventService.mark_attendance(pk, s.validated_data["user_id"], s.validated_data["attended"])
            return api_response(True, message="Présence mise à jour.")
        except ValidationError as e:
            return api_response(False, message=_service_error(e), status_code=400)
