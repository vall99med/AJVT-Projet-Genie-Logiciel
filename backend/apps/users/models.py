"""
Modèle utilisateur personnalisé — identifiant principal : numéro de téléphone.
Le PIN 4 chiffres (bcrypt) remplace le mot de passe Django standard.
"""
import bcrypt
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin


class UserManager(BaseUserManager):
    """Manager personnalisé — utilise le téléphone au lieu du username."""

    def create_user(self, phone, pin=None, **extra_fields):
        if not phone:
            raise ValueError("Le numéro de téléphone est obligatoire.")
        user = self.model(phone=phone, **extra_fields)
        user.set_unusable_password()  # Désactive le champ password Django
        if pin:
            user.set_pin(pin)
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, pin=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", User.Role.ADMIN)
        extra_fields.setdefault("status", User.Status.ACTIVE)
        extra_fields.setdefault("is_verified", True)

        if not extra_fields.get("is_staff"):
            raise ValueError("Le superutilisateur doit avoir is_staff=True.")
        if not extra_fields.get("is_superuser"):
            raise ValueError("Le superutilisateur doit avoir is_superuser=True.")

        return self.create_user(phone, pin, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """
    Utilisateur AJVT.
    Authentification : OTP SMS pour vérification initiale, puis PIN 4 chiffres.
    """

    class Role(models.TextChoices):
        VISITOR = "visitor", "Visiteur"
        MEMBER = "member", "Membre"
        MODERATOR = "moderator", "Modérateur"
        ADMIN = "admin", "Administrateur"

    class Status(models.TextChoices):
        PENDING = "pending", "En attente"
        ACTIVE = "active", "Actif"
        REJECTED = "rejected", "Rejeté"

    phone = models.CharField("téléphone", max_length=20, unique=True)
    pin_hash = models.CharField("PIN hashé", max_length=255, blank=True)
    role = models.CharField(
        "rôle", max_length=20, choices=Role.choices, default=Role.VISITOR
    )
    status = models.CharField(
        "statut", max_length=20, choices=Status.choices, default=Status.PENDING
    )
    is_verified = models.BooleanField("OTP vérifié", default=False)
    is_active = models.BooleanField("actif", default=True)
    is_staff = models.BooleanField("staff", default=False)
    created_at = models.DateTimeField("créé le", auto_now_add=True)
    updated_at = models.DateTimeField("modifié le", auto_now=True)

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = []

    objects = UserManager()

    class Meta:
        verbose_name        = "utilisateur"
        verbose_name_plural = "utilisateurs"
        indexes             = [
            models.Index(fields=["status"], name="user_status_idx"),
            models.Index(fields=["role"],   name="user_role_idx"),
        ]

    def __str__(self):
        return self.phone

    def set_pin(self, raw_pin):
        """Hashe le PIN avec bcrypt avant stockage."""
        hashed = bcrypt.hashpw(raw_pin.encode("utf-8"), bcrypt.gensalt())
        self.pin_hash = hashed.decode("utf-8")

    def check_pin(self, raw_pin):
        """Vérifie le PIN fourni contre le hash stocké. Retourne False si aucun PIN défini."""
        if not self.pin_hash:
            return False
        return bcrypt.checkpw(raw_pin.encode("utf-8"), self.pin_hash.encode("utf-8"))
