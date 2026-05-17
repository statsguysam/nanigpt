"""In-memory caregiver log store.

The production deployment swaps this implementation for SQLCipher AES-256
with the master key held in Android Keystore (hardware-backed where
available). The public surface of the module is identical, so production
and notebook code share the same calling conventions.
"""

from datetime import datetime, timezone
from typing import Any

# In-memory store. Each entry is appended with a timestamp.
_LOG: list[dict[str, Any]] = []


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def append(entry: dict[str, Any]) -> dict[str, Any]:
    """Append a log entry with auto-timestamp. Returns the stored entry."""
    record = {"ts": _now_iso(), **entry}
    _LOG.append(record)
    return record


def all_entries() -> list[dict[str, Any]]:
    return list(_LOG)


def filter_entries(category: str | None = None, since_iso: str | None = None) -> list[dict[str, Any]]:
    out = _LOG
    if category:
        out = [e for e in out if e.get("category") == category]
    if since_iso:
        out = [e for e in out if e["ts"] >= since_iso]
    return out


def reset() -> None:
    """For tests."""
    _LOG.clear()
