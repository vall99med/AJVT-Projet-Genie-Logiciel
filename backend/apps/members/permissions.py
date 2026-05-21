from rest_framework.permissions import BasePermission


class IsAdmin(BasePermission):
    """Accès réservé aux administrateurs."""
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            request.user.role == "admin"
        )


class IsAdminOrModerator(BasePermission):
    """Accès aux admins et modérateurs."""
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            request.user.role in ["admin", "moderator"]
        )


class IsActiveMember(BasePermission):
    """Accès aux membres actifs uniquement."""
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            request.user.status == "active"
        )
