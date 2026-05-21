"""Routes du fil d'actualité et des événements."""
from django.urls import path
from .views import (
    PostListView, PostDetailView, CreatePostView, PublishPostView, DeletePostView,
    EventListView, EventDetailView, CreateEventView,
    JoinEventView, LeaveEventView, EventParticipantsView, MarkAttendanceView,
)

urlpatterns = [
    # Articles
    path("posts/",                    PostListView.as_view()),
    path("posts/create/",             CreatePostView.as_view()),
    path("posts/<int:pk>/",           PostDetailView.as_view()),
    path("posts/<int:pk>/publish/",   PublishPostView.as_view()),
    path("posts/<int:pk>/delete/",    DeletePostView.as_view()),

    # Événements
    path("events/",                          EventListView.as_view()),
    path("events/create/",                   CreateEventView.as_view()),
    path("events/<int:pk>/",                 EventDetailView.as_view()),
    path("events/<int:pk>/join/",            JoinEventView.as_view()),
    path("events/<int:pk>/leave/",           LeaveEventView.as_view()),
    path("events/<int:pk>/participants/",    EventParticipantsView.as_view()),
    path("events/<int:pk>/attendance/",      MarkAttendanceView.as_view()),
]
