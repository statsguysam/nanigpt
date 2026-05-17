"""NaniGPT tool functions exposed to Gemma 4 via native function calling.

These are plain Python functions with type hints and docstrings. Gemma 4's
chat template (and HF transformers' `tools=` argument) auto-converts them
into JSON Schema for the model.

Design rules:
    - Each tool returns a dict so the model can confirm what it did.
    - Each tool is idempotent-friendly: re-calling logs an additional entry
      rather than mutating the prior one.
    - Severity and urgency vocabularies are constrained (Literal types) so the
      model cannot invent fields.
"""

from typing import Literal
from datetime import datetime, timezone

from . import storage


# ---------- Pill organizer ----------

def log_pill_change(
    day: Literal["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"],
    ampm: Literal["AM", "PM"],
    change: Literal["taken", "refilled", "missed"],
    note: str = "",
) -> dict:
    """Log a pill organizer state change detected by the morning photo diff.

    Args:
        day: Day-of-week the slot belongs to (e.g. 'TUE').
        ampm: 'AM' or 'PM' compartment.
        change: 'taken' (slot went from full to empty as expected),
                'refilled' (empty to full, caregiver topped up),
                'missed' (slot still full when it should have been taken).
        note: Optional free-text from the caregiver.

    Returns:
        The stored log entry including timestamp.
    """
    return storage.append({
        "category": "medication",
        "day": day,
        "ampm": ampm,
        "change": change,
        "note": note,
    })


# ---------- Incidents (falls, bruises, behavior, appetite, sleep) ----------

def log_incident(
    category: Literal["fall", "bruise", "behavior", "appetite", "sleep", "wandering", "other"],
    detail: str,
    severity: Literal["low", "medium", "high"],
    photo_attached: bool = False,
) -> dict:
    """Log an observation about the parent.

    Use 'low' for trend-tracking entries, 'medium' for things to mention at
    next doctor visit, 'high' for things that warrant a same-day clinician
    call. NaniGPT never decides medical severity for the caregiver. It
    records what the caregiver tells it.

    Args:
        category: Type of observation.
        detail: Plain-language description (1-3 sentences).
        severity: 'low', 'medium', or 'high' as the caregiver judges.
        photo_attached: Whether a photo was logged with this incident.
    """
    return storage.append({
        "category": "incident",
        "incident_type": category,
        "detail": detail,
        "severity": severity,
        "photo_attached": photo_attached,
    })


# ---------- Doctor visit prep ----------

def add_to_doctor_visit(
    item: str,
    priority: Literal["fyi", "important", "urgent"] = "fyi",
) -> dict:
    """Add an item to the agenda for the next doctor visit.

    Used both reactively (caregiver mentions a question) and proactively
    (NaniGPT notices a logged pattern, e.g. 3 missed PM doses in a row,
    and queues it).

    Args:
        item: The question or observation to bring up.
        priority: 'fyi' (mention if time), 'important' (definitely raise),
                  'urgent' (consider phoning before the appointment).
    """
    return storage.append({
        "category": "doctor_agenda",
        "item": item,
        "priority": priority,
    })


# ---------- Family circle ----------

def notify_sibling(
    message: str,
    urgency: Literal["info", "soon", "now"] = "info",
) -> dict:
    """Send a notification to other caregivers in the family circle.

    'info': batched into the daily digest (quiet)
    'soon': SMS or push within the hour
    'now':  immediate alert (bypass quiet hours)

    The tool records the notification intent. The transport (SMS, push,
    email) is dispatched by a separate platform-specific sender.
    """
    return storage.append({
        "category": "sibling_notify",
        "message": message,
        "urgency": urgency,
    })


# ---------- Reports ----------

def generate_doctor_pdf(
    patient_name: str,
    days: int = 30,
) -> dict:
    """Compile the last N days of caregiver log entries into a printable
    report the caregiver can hand the neurologist.

    The tool surfaces the report-generation intent so the model can call
    it from natural language ('print the report for tomorrow's
    appointment'). The rendering layer (reportlab on the laptop build,
    UIKit print on iOS) consumes the returned metadata to produce the
    output file.

    Returns:
        {'patient': str, 'days': int, 'entries_count': int, 'path': str}
    """
    cutoff = datetime.now(timezone.utc).timestamp() - days * 86400
    cutoff_iso = datetime.fromtimestamp(cutoff, tz=timezone.utc).isoformat(timespec="seconds")
    entries = storage.filter_entries(since_iso=cutoff_iso)

    return {
        "patient": patient_name,
        "days": days,
        "entries_count": len(entries),
        "path": f"/data/exports/{patient_name.replace(' ', '_')}_{days}d.pdf",
    }


# Registry the notebook / app passes to Gemma 4 as `tools=[...]`.
ALL_TOOLS = [
    log_pill_change,
    log_incident,
    add_to_doctor_visit,
    notify_sibling,
    generate_doctor_pdf,
]
