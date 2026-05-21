from django.urls import path
from .views import (
    OTPRequestView, OTPVerifyView, SetPinView,
    LoginView, ResetPinRequestView, ResetPinConfirmView,
)

urlpatterns = [
    path("request-otp/", OTPRequestView.as_view()),
    path("verify-otp/", OTPVerifyView.as_view()),
    path("set-pin/", SetPinView.as_view()),
    path("login/", LoginView.as_view()),
    path("reset-pin/request/", ResetPinRequestView.as_view()),
    path("reset-pin/confirm/", ResetPinConfirmView.as_view()),
]
