"""Serializers pour les articles et les événements."""
from rest_framework import serializers
from .models import Post, Event, EventParticipant


class PostSerializer(serializers.ModelSerializer):
    """Lecture d'un article publié."""
    author_name = serializers.SerializerMethodField()
    image_url   = serializers.SerializerMethodField()

    class Meta:
        model  = Post
        fields = [
            "id", "author_name", "title", "body",
            "image_url", "status", "published_at", "created_at",
        ]

    def get_author_name(self, obj):
        profile = getattr(obj.author, "profile", None)
        return profile.full_name if profile and profile.full_name else obj.author.phone

    def get_image_url(self, obj):
        if not obj.image:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.image.url)
        return obj.image.url


class CreatePostSerializer(serializers.Serializer):
    """Création d'un article."""
    title = serializers.CharField(max_length=200)
    body  = serializers.CharField()
    image = serializers.ImageField(required=False)


class EventSerializer(serializers.ModelSerializer):
    """Lecture d'un événement avec compteur et statut participation."""
    image_url          = serializers.SerializerMethodField()
    created_by_name    = serializers.SerializerMethodField()
    participants_count = serializers.SerializerMethodField()
    is_participating   = serializers.SerializerMethodField()

    class Meta:
        model  = Event
        fields = [
            "id", "title", "description", "image_url", "location",
            "starts_at", "ends_at", "max_participants", "status",
            "participants_count", "is_participating", "created_by_name", "created_at",
        ]

    def get_image_url(self, obj):
        if not obj.image:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.image.url)
        return obj.image.url

    def get_created_by_name(self, obj):
        profile = getattr(obj.created_by, "profile", None)
        return profile.full_name if profile and profile.full_name else obj.created_by.phone

    def get_participants_count(self, obj):
        # Utilise l'annotation si disponible, sinon compte direct
        if hasattr(obj, "_participants_count"):
            return obj._participants_count
        return obj.participants.count()

    def get_is_participating(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return obj.participants.filter(user=request.user).exists()


class CreateEventSerializer(serializers.Serializer):
    """Création d'un événement."""
    title            = serializers.CharField(max_length=200)
    description      = serializers.CharField()
    image            = serializers.ImageField(required=False)
    location         = serializers.CharField(max_length=200)
    starts_at        = serializers.DateTimeField()
    ends_at          = serializers.DateTimeField()
    max_participants = serializers.IntegerField(required=False, min_value=1)

    def validate_starts_at(self, value):
        from django.utils import timezone
        if value <= timezone.now():
            raise serializers.ValidationError("La date de début doit être dans le futur.")
        return value

    def validate(self, attrs):
        if attrs.get("ends_at") and attrs.get("starts_at"):
            if attrs["ends_at"] <= attrs["starts_at"]:
                raise serializers.ValidationError("La date de fin doit être après la date de début.")
        return attrs


class ParticipantSerializer(serializers.ModelSerializer):
    """Lecture d'un participant à un événement."""
    full_name = serializers.SerializerMethodField()
    phone     = serializers.SerializerMethodField()
    user_id   = serializers.IntegerField(source="user.id", read_only=True)

    class Meta:
        model  = EventParticipant
        fields = ["id", "user_id", "full_name", "phone", "joined_at", "attended"]

    def get_full_name(self, obj):
        profile = getattr(obj.user, "profile", None)
        return profile.full_name if profile and profile.full_name else ""

    def get_phone(self, obj):
        return obj.user.phone


class MarkAttendanceSerializer(serializers.Serializer):
    """Marquage de présence d'un participant."""
    user_id  = serializers.IntegerField()
    attended = serializers.BooleanField()
