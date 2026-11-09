from django.urls import path

from . import views

app_name = "events"

urlpatterns = [
    path("health/", views.health, name="health"),
    path("", views.event_list, name="event_list"),
    path("<int:event_id>/", views.event_detail, name="event_detail"),
    path("<int:event_id>/register/", views.register_for_event, name="register"),
    path("my-events/", views.my_events, name="my_events"),
]
