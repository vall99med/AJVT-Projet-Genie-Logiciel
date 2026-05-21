from django.urls import path
from .views import (
    RegisterView, MembersListView, PendingMembersView,
    MyProfileView, ValidateMemberView, MemberDetailView,
)

urlpatterns = [
    path("register/", RegisterView.as_view()),
    path("pending/", PendingMembersView.as_view()),
    path("me/", MyProfileView.as_view()),
    path("<int:pk>/validate/", ValidateMemberView.as_view()),
    path("<int:pk>/", MemberDetailView.as_view()),
    path("", MembersListView.as_view()),
]
