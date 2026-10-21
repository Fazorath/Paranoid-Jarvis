"""Tests for the JSON Lines event log. Run: .venv/bin/python -m pytest tests"""
from datetime import datetime, timezone

from paranoid_jarvis import event_log


def test_appended_event_reads_back_with_all_fields(tmp_path):
    log = tmp_path / "events.jsonl"
    now = datetime(2026, 10, 20, 22, 30, 5, tzinfo=timezone.utc)

    event_log.append_event(
        log, "login", photo="startup_image_1.jpg", power="ac",
        classification=None, now=now, camera_index=0,
    )

    assert list(event_log.read_events(log)) == [{
        "ts": "2026-10-20T22:30:05+00:00",
        "event": "login",
        "photo": "startup_image_1.jpg",
        "power": "ac",
        "classification": None,
        "context": {"camera_index": 0},
    }]


def test_reading_a_missing_log_yields_no_events(tmp_path):
    assert list(event_log.read_events(tmp_path / "events.jsonl")) == []


def test_truncated_line_from_a_crash_is_skipped(tmp_path):
    log = tmp_path / "events.jsonl"
    event_log.append_event(log, "login")
    with open(log, "a") as f:
        f.write('{"ts": "2026-10-20T22:3')
    event_log.append_event(log, "heartbeat")

    assert [e["event"] for e in event_log.read_events(log)] == ["login", "heartbeat"]
