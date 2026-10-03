from django.urls import path
from . import views

urlpatterns = [
    # Detection
    path("update_queue/",                       views.update_queue),

    # Stations (Flutter reads these)
    path("traffic/status/",                     views.traffic_status),
    path("stations/nearby/",                    views.nearby_stations),
    path("stations/<int:station_id>/status/",   views.station_status),
    path("stations/<int:station_id>/history/",  views.station_history),
    path("stations/list/", views.stations_list_simple),
    # Auth
    path("auth/send-otp/",                      views.send_otp),
    path("auth/verify-otp/",                    views.verify_otp),
    path("auth/signup/",                        views.signup),
    path("auth/login/",                         views.login_view),
    path("auth/profile/",                       views.my_profile),
    path("auth/request-password-reset/",        views.request_password_reset),
    path("auth/reset-password/",                views.reset_password),

    # Owner Dashboard
    path("dashboard/<int:station_id>/overview/",        views.dashboard_overview),
    path("dashboard/<int:station_id>/transactions/",    views.dashboard_transactions),
    # Employees
    path("dashboard/<int:station_id>/employees/",                   views.employees_list),
    path("dashboard/<int:station_id>/employees/<int:employee_id>/",  views.employee_delete),
]