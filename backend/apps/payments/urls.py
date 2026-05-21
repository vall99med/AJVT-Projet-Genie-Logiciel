from django.urls import path
from .views import (
    MemberCardView,
    MyPaymentsView,
    CreatePaymentView,
    AllPaymentsView,
    SubmitPaymentView,
    ReviewPaymentView,
    SubmittedPaymentsView,
)

urlpatterns = [
    path("card/",            MemberCardView.as_view()),
    path("me/",              MyPaymentsView.as_view()),
    path("submit/",          SubmitPaymentView.as_view()),
    path("submitted/",       SubmittedPaymentsView.as_view()),
    path("all/",             AllPaymentsView.as_view()),
    path("<int:pk>/review/", ReviewPaymentView.as_view()),
    path("",                 CreatePaymentView.as_view()),
]
