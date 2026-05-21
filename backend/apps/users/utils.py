import re
from rest_framework import serializers


def validate_international_phone(value):
    """
    Valide et normalise un numéro de téléphone au format E.164 international.
    Accepte tous les pays — pas uniquement la Mauritanie.
    Exemples : +22212345678, +33612345678, +12125551234
    """
    phone = value.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")

    if not phone.startswith("+"):
        raise serializers.ValidationError(
            "Le numéro doit commencer par + suivi de l'indicatif pays. "
            "Exemple : +22212345678 pour la Mauritanie, +33612345678 pour la France."
        )

    if not re.match(r"^\+\d{7,15}$", phone):
        raise serializers.ValidationError(
            "Format invalide. Le numéro doit contenir entre 7 et 15 chiffres après le +."
        )

    return phone
