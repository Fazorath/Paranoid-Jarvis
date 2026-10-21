"""Tests for the resident agent's trigger logic. Run: .venv/bin/python -m pytest tests"""
from paranoid_jarvis.agent import Triggers


def make_triggers(locked=False):
    events = []
    return Triggers(events.append, locked=locked), events


def test_display_wake_while_locked_is_screen_wake_locked():
    triggers, events = make_triggers()

    triggers.screen_locked()
    triggers.screens_woke()

    assert events == ["screen_wake_locked"]


def test_unlock_is_emitted_and_clears_locked_state():
    triggers, events = make_triggers()

    triggers.screen_locked()
    triggers.screen_unlocked()
    triggers.screens_woke()

    assert events == ["unlock"]


def test_system_wake_while_restarted_locked_reports_wake_then_locked_display():
    # KeepAlive can restart the agent while the screen is locked.
    triggers, events = make_triggers(locked=True)

    triggers.system_woke()
    triggers.screens_woke()

    assert events == ["wake", "screen_wake_locked"]
