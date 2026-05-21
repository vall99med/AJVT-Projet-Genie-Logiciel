"""Logique métier du fil d'actualité et des événements."""
import logging

from django.db.models import Count
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.dashboard.models import AuditLog
from .models import Post, Event, EventParticipant

logger = logging.getLogger(__name__)


class PostService:

    @staticmethod
    def get_published_posts(user=None):
        """Retourne les articles publiés.
        Les membres actifs voient tout ; les visiteurs voient les 3 derniers."""
        qs = Post.objects.filter(
            status=Post.Status.PUBLISHED
        ).select_related("author", "author__profile").order_by("-published_at")

        is_active = (
            user is not None
            and user.is_authenticated
            and user.status == "active"
        )
        if not is_active:
            qs = qs[:3]
        return qs

    @staticmethod
    def create_post(validated_data, author):
        """Crée un article en état brouillon."""
        post = Post.objects.create(
            author = author,
            title  = validated_data["title"],
            body   = validated_data["body"],
            image  = validated_data.get("image"),
            status = Post.Status.DRAFT,
        )
        post.compress_image()
        AuditLog.log(
            "post_created",
            performed_by=author,
            target_user=author,
            details={"post_id": post.id, "title": post.title},
        )
        logger.info("Article %s créé par %s", post.id, author.phone)
        return post

    @staticmethod
    def publish_post(post_id, publisher):
        """Publie un article brouillon."""
        try:
            post = Post.objects.get(pk=post_id)
        except Post.DoesNotExist:
            raise ValidationError("Article introuvable.")
        if post.status == Post.Status.PUBLISHED:
            raise ValidationError("Cet article est déjà publié.")
        post.publish()
        AuditLog.log(
            "post_published",
            performed_by=publisher,
            target_user=publisher,
            details={"post_id": post.id},
        )
        logger.info("Article %s publié par %s", post.id, publisher.phone)
        return post

    @staticmethod
    def delete_post(post_id, deleted_by):
        """Supprime un article."""
        try:
            post = Post.objects.get(pk=post_id)
        except Post.DoesNotExist:
            raise ValidationError("Article introuvable.")
        AuditLog.log(
            "post_deleted",
            performed_by=deleted_by,
            target_user=deleted_by,
            details={"post_id": post_id, "title": post.title},
        )
        post.delete()
        logger.info("Article %s supprimé par %s", post_id, deleted_by.phone)


class EventService:

    @staticmethod
    def get_events():
        """Retourne tous les événements avec le nombre de participants."""
        return (
            Event.objects
            .select_related("created_by", "created_by__profile")
            .annotate(_participants_count=Count("participants"))
            .order_by("starts_at")
        )

    @staticmethod
    def get_event(event_id):
        """Retourne un événement ou lève une ValidationError."""
        try:
            return (
                Event.objects
                .select_related("created_by", "created_by__profile")
                .annotate(_participants_count=Count("participants"))
                .get(pk=event_id)
            )
        except Event.DoesNotExist:
            raise ValidationError("Événement introuvable.")

    @staticmethod
    def create_event(validated_data, author):
        """Crée un événement."""
        event = Event.objects.create(
            title            = validated_data["title"],
            description      = validated_data["description"],
            image            = validated_data.get("image"),
            location         = validated_data["location"],
            starts_at        = validated_data["starts_at"],
            ends_at          = validated_data["ends_at"],
            max_participants = validated_data.get("max_participants"),
            created_by       = author,
            status           = Event.Status.UPCOMING,
        )
        event.compress_image()
        AuditLog.log(
            "event_created",
            performed_by=author,
            target_user=author,
            details={"event_id": event.id, "title": event.title},
        )
        logger.info("Événement %s créé par %s", event.id, author.phone)
        return event

    @staticmethod
    def join_event(event_id, user):
        """Inscrit un membre à un événement."""
        try:
            event = Event.objects.get(pk=event_id)
        except Event.DoesNotExist:
            raise ValidationError("Événement introuvable.")

        if event.status == Event.Status.CANCELLED:
            raise ValidationError("Cet événement est annulé.")
        if event.status == Event.Status.PAST:
            raise ValidationError("Cet événement est terminé.")
        if EventParticipant.objects.filter(event=event, user=user).exists():
            raise ValidationError("Vous êtes déjà inscrit à cet événement.")
        if event.is_full:
            raise ValidationError("Le nombre maximum de participants est atteint.")

        EventParticipant.objects.create(event=event, user=user)
        logger.info("Membre %s inscrit à l'événement %s", user.phone, event_id)

    @staticmethod
    def leave_event(event_id, user):
        """Désinscrit un membre d'un événement."""
        deleted, _ = EventParticipant.objects.filter(
            event_id=event_id, user=user
        ).delete()
        if not deleted:
            raise ValidationError("Vous n'êtes pas inscrit à cet événement.")
        logger.info("Membre %s désinscrit de l'événement %s", user.phone, event_id)

    @staticmethod
    def mark_attendance(event_id, user_id, attended):
        """Marque la présence ou l'absence d'un participant."""
        try:
            participant = EventParticipant.objects.get(
                event_id=event_id, user_id=user_id
            )
        except EventParticipant.DoesNotExist:
            raise ValidationError("Participant introuvable pour cet événement.")
        participant.attended = attended
        participant.save()
        return participant

    @staticmethod
    def get_event_participants(event_id):
        """Retourne la liste des participants d'un événement."""
        return (
            EventParticipant.objects
            .filter(event_id=event_id)
            .select_related("user", "user__profile")
            .order_by("joined_at")
        )
