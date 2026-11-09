from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, render
from django.utils import timezone

from .models import Event, EventCategory, EventRegistration


def health(request):
    """Liveness check for deploys and monitoring"""
    return JsonResponse({"status": "ok"})


def event_list(request):
    """Display list of upcoming events"""
    events = Event.objects.filter(
        status="published", start_datetime__gte=timezone.now()
    ).select_related("category", "organizer")

    categories = EventCategory.objects.all()

    # Filter by category if provided
    category_id = request.GET.get("category")
    if category_id:
        events = events.filter(category_id=category_id)

    context = {
        "events": events,
        "categories": categories,
    }
    return render(request, "events/event_list.html", context)


def event_detail(request, event_id):
    """Display details of a specific event"""
    event = get_object_or_404(
        Event.objects.select_related("category", "organizer"), id=event_id
    )

    is_registered = False
    if request.user.is_authenticated:
        is_registered = EventRegistration.objects.filter(
            event=event, user=request.user
        ).exists()

    context = {
        "event": event,
        "is_registered": is_registered,
    }
    return render(request, "events/event_detail.html", context)


@login_required
def register_for_event(request, event_id):
    """Register user for an event"""
    if request.method == "POST":
        event = get_object_or_404(Event, id=event_id, status="published")

        # Check if registration is required
        if not event.registration_required:
            return JsonResponse(
                {
                    "success": False,
                    "message": "Registration is not required for this event.",
                }
            )

        # Check if already registered
        if EventRegistration.objects.filter(event=event, user=request.user).exists():
            return JsonResponse(
                {
                    "success": False,
                    "message": "You are already registered for this event.",
                }
            )

        # Check if event is full
        if event.max_participants:
            current_registrations = EventRegistration.objects.filter(
                event=event
            ).count()
            if current_registrations >= event.max_participants:
                return JsonResponse(
                    {"success": False, "message": "This event is full."}
                )

        # Create registration
        EventRegistration.objects.create(event=event, user=request.user)

        return JsonResponse(
            {"success": True, "message": "Successfully registered for the event."}
        )

    return JsonResponse({"success": False, "message": "Invalid request method."})


@login_required
def my_events(request):
    """Display user's registered events"""
    registrations = (
        EventRegistration.objects.filter(user=request.user)
        .select_related("event", "event__category")
        .order_by("-registered_at")
    )

    context = {
        "registrations": registrations,
    }
    return render(request, "events/my_events.html", context)
