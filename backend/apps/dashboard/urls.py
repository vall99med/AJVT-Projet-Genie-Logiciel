from django.urls import path
from apps.payments.views import DashboardStatsView, ExportMembersView

urlpatterns = [
    path("stats/", DashboardStatsView.as_view()),
    path("export/", ExportMembersView.as_view()),
]
