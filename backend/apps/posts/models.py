"""Modèles du fil d'actualité (Post) et des événements (Event)."""
import io
import os
from django.db import models
from django.conf import settings
from PIL import Image


def _compress_image(image_field, max_bytes):
    """Redimensionne l'image si sa taille dépasse max_bytes."""
    if not image_field:
        return
    try:
        path = image_field.path
    except (ValueError, NotImplementedError):
        return
    if not os.path.exists(path):
        return
    if image_field.size <= max_bytes:
        return

    img = Image.open(path)
    if img.mode != "RGB":
        img = img.convert("RGB")

    output = io.BytesIO()
    quality = 85
    while quality >= 40:
        output.seek(0)
        output.truncate(0)
        img.save(output, format="JPEG", quality=quality, optimize=True)
        if output.tell() <= max_bytes:
            break
        quality -= 10

    with open(path, "wb") as f:
        f.write(output.getvalue())


class Post(models.Model):
    """Article du fil d'actualité, rédigé par un admin ou modérateur."""

    class Status(models.TextChoices):
        DRAFT     = "draft",     "Brouillon"
        PUBLISHED = "published", "Publié"

    author       = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="posts",
        verbose_name="auteur",
    )
    title        = models.CharField("titre", max_length=200)
    body         = models.TextField("contenu")
    image        = models.ImageField("image", upload_to="posts/", null=True, blank=True)
    status       = models.CharField(
        "statut", max_length=20, choices=Status.choices, default=Status.DRAFT
    )
    published_at = models.DateTimeField("publié le", null=True, blank=True)
    created_at   = models.DateTimeField("créé le", auto_now_add=True)
    updated_at   = models.DateTimeField("modifié le", auto_now=True)

    class Meta:
        verbose_name        = "article"
        verbose_name_plural = "articles"
        ordering            = ["-published_at", "-created_at"]
        indexes             = [
            models.Index(fields=["status", "-published_at"], name="post_status_date_idx"),
        ]

    def __str__(self):
        return self.title

    def publish(self, publisher=None):
        """Publie l'article et enregistre la date."""
        from django.utils import timezone
        self.status       = self.Status.PUBLISHED
        self.published_at = timezone.now()
        self.save()

    def compress_image(self):
        """Compresse l'image si elle dépasse 300 Ko."""
        _compress_image(self.image, 300 * 1024)


class Event(models.Model):
    """Événement associatif avec gestion des participants."""

    class Status(models.TextChoices):
        UPCOMING  = "upcoming",  "À venir"
        ONGOING   = "ongoing",   "En cours"
        PAST      = "past",      "Passé"
        CANCELLED = "cancelled", "Annulé"

    title            = models.CharField("titre", max_length=200)
    description      = models.TextField("description")
    image            = models.ImageField("image", upload_to="events/", null=True, blank=True)
    location         = models.CharField("lieu", max_length=200)
    starts_at        = models.DateTimeField("début")
    ends_at          = models.DateTimeField("fin")
    max_participants = models.PositiveIntegerField("participants max", null=True, blank=True)
    status           = models.CharField(
        "statut", max_length=20, choices=Status.choices, default=Status.UPCOMING
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="created_events",
        verbose_name="créé par",
    )
    created_at = models.DateTimeField("créé le", auto_now_add=True)
    updated_at = models.DateTimeField("modifié le", auto_now=True)

    class Meta:
        verbose_name        = "événement"
        verbose_name_plural = "événements"
        ordering            = ["starts_at"]
        indexes             = [
            models.Index(fields=["status", "starts_at"], name="event_status_date_idx"),
        ]

    def __str__(self):
        return self.title

    @property
    def is_full(self):
        """Retourne True si le nombre max de participants est atteint."""
        if not self.max_participants:
            return False
        return self.participants.count() >= self.max_participants

    def compress_image(self):
        """Compresse l'image si elle dépasse 300 Ko."""
        _compress_image(self.image, 300 * 1024)


class EventParticipant(models.Model):
    """Participation d'un membre à un événement."""

    event     = models.ForeignKey(
        Event, on_delete=models.CASCADE, related_name="participants", verbose_name="événement"
    )
    user      = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="event_participations",
        verbose_name="membre",
    )
    joined_at = models.DateTimeField("inscrit le", auto_now_add=True)
    attended  = models.BooleanField("présent", default=False)

    class Meta:
        unique_together     = ("event", "user")
        verbose_name        = "participant"
        verbose_name_plural = "participants"

    def __str__(self):
        return f"{self.user.phone} → {self.event.title}"
