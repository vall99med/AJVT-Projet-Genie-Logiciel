"""Profil détaillé des membres de l'association."""
import io
import os
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.conf import settings
from PIL import Image


class Profile(models.Model):
    """Informations personnelles et professionnelles d'un membre."""

    class Situation(models.TextChoices):
        STUDENT = "student", "Étudiant"
        EMPLOYED = "employed", "Employé"
        UNEMPLOYED = "unemployed", "Sans emploi"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile",
        verbose_name="utilisateur",
    )
    full_name = models.CharField("nom complet", max_length=200, blank=True)
    situation = models.CharField(
        "situation", max_length=20, choices=Situation.choices, blank=True
    )
    # Champs conditionnels selon la situation
    specialty = models.CharField("spécialité", max_length=200, blank=True)
    study_level = models.CharField("niveau d'études", max_length=100, blank=True)
    job_title = models.CharField("poste", max_length=200, blank=True)
    neighborhood = models.CharField("région", max_length=200, blank=True)
    photo = models.ImageField("photo", upload_to="profiles/", blank=True, null=True)
    rejection_reason = models.TextField("motif de rejet", blank=True)
    validated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="validated_members",
        verbose_name="validé par",
    )
    validated_at = models.DateTimeField("validé le", null=True, blank=True)
    created_at = models.DateTimeField("créé le", auto_now_add=True)
    updated_at = models.DateTimeField("modifié le", auto_now=True)

    class Meta:
        verbose_name = "profil"
        verbose_name_plural = "profils"

    def __str__(self):
        return self.full_name or str(self.user)

    def compress_photo(self):
        """Redimensionne la photo si elle dépasse MAX_IMAGE_SIZE_KB (défaut : 200 Ko)."""
        if not self.photo:
            return

        max_size_bytes = getattr(settings, "MAX_IMAGE_SIZE_KB", 200) * 1024

        try:
            photo_path = self.photo.path
        except (ValueError, NotImplementedError):
            return

        if not os.path.exists(photo_path):
            return

        if self.photo.size <= max_size_bytes:
            return

        img = Image.open(photo_path)
        if img.mode not in ("RGB", "RGBA"):
            img = img.convert("RGB")
        elif img.mode == "RGBA":
            # Fond blanc pour les images avec transparence
            background = Image.new("RGB", img.size, (255, 255, 255))
            background.paste(img, mask=img.split()[3])
            img = background

        output = io.BytesIO()
        quality = 85
        while quality >= 40:
            output.seek(0)
            output.truncate(0)
            img.save(output, format="JPEG", quality=quality, optimize=True)
            if output.tell() <= max_size_bytes:
                break
            quality -= 10

        # Réécriture directe sur disque sans déclencher un nouveau save()
        with open(photo_path, "wb") as f:
            f.write(output.getvalue())

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self.compress_photo()


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
    """Crée automatiquement un profil vide à la création d'un utilisateur."""
    if created:
        Profile.objects.get_or_create(user=instance)
