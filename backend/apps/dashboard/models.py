"""Journal d'audit pour tracer les actions administratives."""
from django.db import models
from django.conf import settings


class AuditLog(models.Model):
    """Entrée du journal d'audit — une action administrative tracée."""

    action = models.CharField("action", max_length=100)
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="audit_logs",
        verbose_name="effectué par",
    )
    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_targets",
        verbose_name="utilisateur cible",
    )
    details = models.JSONField("détails", default=dict)
    ip_address = models.GenericIPAddressField("adresse IP", null=True, blank=True)
    created_at = models.DateTimeField("créé le", auto_now_add=True)

    class Meta:
        verbose_name = "entrée d'audit"
        verbose_name_plural = "journal d'audit"
        ordering = ["-created_at"]

    def __str__(self):
        actor = self.performed_by.phone if self.performed_by else "système"
        return f"[{self.created_at:%Y-%m-%d %H:%M}] {self.action} par {actor}"

    @classmethod
    def log(cls, action, performed_by, target_user=None, details=None, ip=None):
        """Crée une entrée d'audit depuis n'importe quelle vue.

        Exemple :
            AuditLog.log("member_approved", request.user, target_user=membre, ip=request.META.get("REMOTE_ADDR"))
        """
        return cls.objects.create(
            action=action,
            performed_by=performed_by,
            target_user=target_user,
            details=details or {},
            ip_address=ip,
        )
