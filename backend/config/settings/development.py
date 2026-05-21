"""
Configuration pour l'environnement de développement local.
"""
from .base import *  # noqa: F401, F403

DEBUG = True

# CORS : autoriser toutes les origines en développement (localhost Flutter Web)
CORS_ALLOW_ALL_ORIGINS = True

# SQLite en dev si PostgreSQL n'est pas disponible
# Décommenter pour utiliser SQLite :
# DATABASES = {
#     "default": {
#         "ENGINE": "django.db.backends.sqlite3",
#         "NAME": BASE_DIR / "db.sqlite3",
#     }
# }

# Barre de débogage Django (optionnel, nécessite django-debug-toolbar)
# INSTALLED_APPS += ["debug_toolbar"]
# MIDDLEWARE = ["debug_toolbar.middleware.DebugToolbarMiddleware"] + MIDDLEWARE
# INTERNAL_IPS = ["127.0.0.1"]

# Emails affichés dans la console en dev
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Logs détaillés
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "[{asctime}] {levelname} {name}: {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "DEBUG",
    },
    "loggers": {
        "django.db.backends": {
            "handlers": ["console"],
            "level": "INFO",  # Passer à DEBUG pour voir les requêtes SQL
            "propagate": False,
        },
    },
}
