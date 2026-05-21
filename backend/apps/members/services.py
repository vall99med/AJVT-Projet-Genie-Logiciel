"""
Logique métier de l'app membres — validation, profils, annuaire.
"""
import logging
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.users.models import User
from apps.dashboard.models import AuditLog
from .models import Profile

logger = logging.getLogger(__name__)


class MemberService:

    @staticmethod
    def register(phone, validated_data):
        """Complète le profil d'un utilisateur vérifié pour une demande d'adhésion."""
        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            raise ValidationError("Téléphone non vérifié. Inscrivez-vous d'abord.")

        if not user.is_verified:
            raise ValidationError("Téléphone non vérifié. Validez votre OTP d'abord.")

        if user.status != User.Status.PENDING:
            raise ValidationError("Compte déjà traité.")

        profile = user.profile
        if profile.full_name:
            raise ValidationError("Inscription déjà soumise. En attente de validation par le bureau.")
        for field in ("full_name", "situation", "specialty", "study_level", "job_title", "neighborhood"):
            if field in validated_data:
                setattr(profile, field, validated_data[field])
        profile.save()

        AuditLog.log("member_registered", performed_by=user)
        logger.info("Inscription membre : %s", phone)
        return profile

    @staticmethod
    def get_pending_members():
        """Retourne les profils des utilisateurs dont la demande est en attente."""
        return (
            Profile.objects.filter(user__status=User.Status.PENDING)
            .select_related("user")
            .order_by("user__created_at")
        )

    @staticmethod
    def get_active_members():
        """Retourne les profils des membres actifs visibles dans l'annuaire."""
        return (
            Profile.objects.filter(
                user__status=User.Status.ACTIVE,
                user__role__in=[User.Role.MEMBER, User.Role.MODERATOR, User.Role.ADMIN],
            )
            .select_related("user")
            .order_by("full_name")
        )

    @staticmethod
    def validate_member(member_id, action, rejection_reason, validated_by):
        """Approuve ou rejette une demande d'adhésion. Met à jour statut et profil."""
        try:
            user = User.objects.select_related("profile").get(pk=member_id)
        except User.DoesNotExist:
            raise ValidationError("Membre introuvable.")

        if user.status != User.Status.PENDING:
            raise ValidationError("Ce membre a déjà été traité.")

        profile = user.profile

        with transaction.atomic():
            if action == "approve":
                user.status = User.Status.ACTIVE
                user.role = User.Role.MEMBER
                profile.validated_by = validated_by
                profile.validated_at = timezone.now()
                user.save()
                profile.save()
                AuditLog.log("member_approved", performed_by=validated_by, target_user=user)
                logger.info("Membre approuvé : %s par %s", user.phone, validated_by.phone)
            else:
                user.status = User.Status.REJECTED
                profile.rejection_reason = rejection_reason or ""
                user.save()
                profile.save()
                AuditLog.log("member_rejected", performed_by=validated_by, target_user=user)
                logger.info("Membre rejeté : %s par %s", user.phone, validated_by.phone)

        return user

    @staticmethod
    def get_member_profile(user):
        """Retourne le profil complet de l'utilisateur connecté."""
        return Profile.objects.select_related("user").get(user=user)

    @staticmethod
    def update_profile(user, validated_data):
        """Met à jour les champs fournis du profil (partial update)."""
        profile = Profile.objects.get(user=user)
        for field, value in validated_data.items():
            setattr(profile, field, value)
        profile.save()  # compress_photo() est appelé automatiquement dans Profile.save()
        return profile
