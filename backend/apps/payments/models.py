"""Modèle de cotisation annuelle des membres."""
import io
import os
from datetime import datetime
from django.db import models
from django.conf import settings
from PIL import Image


class Payment(models.Model):
    """Cotisation annuelle d'un membre."""

    class Status(models.TextChoices):
        PENDING   = "pending",   "En attente"
        SUBMITTED = "submitted", "Reçu soumis"
        PAID      = "paid",      "Payé"
        REJECTED  = "rejected",  "Rejeté"

    class PaymentMode(models.TextChoices):
        CASH     = "cash",     "Espèces"
        BANKILY  = "bankily",  "Bankily"
        MASRIVI  = "masrivi",  "Masrivi"
        SEDAD    = "sedad",    "Sedad"
        BIMBANK  = "bimbank",  "BimBank"
        CLIQUE   = "clique",   "Clique"
        AMANTY   = "amanty",   "Amanty"
        TRANSFER = "transfer", "Virement bancaire"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="payments",
        verbose_name="membre",
    )
    year = models.IntegerField("année")
    amount = models.DecimalField("montant", max_digits=10, decimal_places=2)
    status = models.CharField(
        "statut", max_length=20, choices=Status.choices, default=Status.PENDING
    )
    payment_mode = models.CharField(
        "mode de paiement",
        max_length=20,
        choices=PaymentMode.choices,
        default=PaymentMode.CASH,
    )
    receipt_image    = models.ImageField("reçu", upload_to="receipts/", null=True, blank=True)
    transaction_ref  = models.CharField("référence transaction", max_length=100, blank=True)
    submitted_at     = models.DateTimeField("soumis le", null=True, blank=True)
    reviewed_by      = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_payments",
        verbose_name="vérifié par",
    )
    reviewed_at      = models.DateTimeField("vérifié le", null=True, blank=True)
    rejection_reason = models.TextField("motif de rejet", blank=True)
    paid_at          = models.DateTimeField("payé le", null=True, blank=True)
    validated_by     = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="validated_payments",
        verbose_name="validé par",
    )
    notes      = models.TextField("notes", blank=True)
    created_at = models.DateTimeField("créé le", auto_now_add=True)

    class Meta:
        verbose_name        = "cotisation"
        verbose_name_plural = "cotisations"
        ordering            = ["-year", "-created_at"]
        indexes             = [
            models.Index(fields=["year", "status"],  name="payment_year_status_idx"),
            models.Index(fields=["user", "year"],    name="payment_user_year_idx"),
            models.Index(fields=["status"],          name="payment_status_idx"),
        ]

    def __str__(self):
        full_name = getattr(getattr(self.user, "profile", None), "full_name", None)
        label = full_name or self.user.phone
        return f"{label} — {self.year} — {self.get_status_display()}"

    @property
    def is_current_year(self):
        """Retourne True si la cotisation concerne l'année en cours."""
        return self.year == datetime.now().year

    def compress_receipt(self):
        """Redimensionne le reçu si sa taille dépasse 500 Ko."""
        if not self.receipt_image:
            return

        max_size_bytes = 500 * 1024

        try:
            image_path = self.receipt_image.path
        except (ValueError, NotImplementedError):
            return

        if not os.path.exists(image_path):
            return

        if self.receipt_image.size <= max_size_bytes:
            return

        img = Image.open(image_path)
        if img.mode != "RGB":
            img = img.convert("RGB")

        output = io.BytesIO()
        quality = 85
        while quality >= 40:
            output.seek(0)
            output.truncate(0)
            img.save(output, format="JPEG", quality=quality, optimize=True)
            if output.tell() <= max_size_bytes:
                break
            quality -= 10

        with open(image_path, "wb") as f:
            f.write(output.getvalue())
