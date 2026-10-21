"""JSON Lines event log: one JSON object per line, one line per event."""
import glob
import json
import os
import subprocess
import time
from datetime import datetime

# Classification for a photo taken on a locked-screen wake with no unlock in time.
# Its photo is never removed by retention.
SUSPECTED_INTRUSION = "suspected_intrusion"

DEFAULT_RETENTION_DAYS = 30


def append_event(log_path, event, *, photo=None, power=None, classification=None,
                 now=None, **context):
    """Append one event. Extra keyword arguments are stored under "context"."""
    record = {
        "ts": (now or datetime.now().astimezone()).isoformat(timespec="seconds"),
        "event": event,
        "photo": photo,
        "power": power,
        "classification": classification,
        "context": context,
    }
    with open(log_path, "a+b") as f:
        # Start a fresh line if a crash left the last write unterminated.
        if f.tell() > 0:
            f.seek(-1, os.SEEK_END)
            if f.read(1) != b"\n":
                f.write(b"\n")
        f.write((json.dumps(record) + "\n").encode())


def read_events(log_path):
    """Yield events in order, skipping lines that aren't JSON objects. A missing log is empty."""
    try:
        f = open(log_path)
    except FileNotFoundError:
        return
    with f:
        for line in f:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(record, dict):
                yield record


def format_event(record):
    """Render an event as '[YYYY-MM-DD HH:MM:SS] EVENT: login - File: x.jpg (power: ac)'."""
    ts = datetime.fromisoformat(record["ts"]).strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] EVENT: {record['event']}"
    if record.get("photo"):
        line += f" - File: {record['photo']}"
    details = [f"{key}: {record[key]}" for key in ("power", "classification") if record.get(key)]
    details += [f"{key}: {value}" for key, value in (record.get("context") or {}).items()]
    if details:
        line += f" ({', '.join(details)})"
    return line


def power_source(run=subprocess.check_output):
    """Return "ac" or "battery" from `pmset -g batt`, or None if it can't be read."""
    try:
        output = run(["pmset", "-g", "batt"], text=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    if "'AC Power'" in output:
        return "ac"
    if "'Battery Power'" in output:
        return "battery"
    return None


def apply_retention(output_dir, log_path, image_prefix, max_age_days=DEFAULT_RETENTION_DAYS,
                    now=None):
    """Delete photos older than max_age_days, except those logged as suspected intrusions.

    Returns the paths deleted. A photo that can't be removed is skipped, so retention
    never masks a capture error.
    """
    protected = {
        e["photo"] for e in read_events(log_path)
        if e.get("classification") == SUSPECTED_INTRUSION and e.get("photo")
    }
    cutoff = (now or time.time()) - max_age_days * 86400
    deleted = []
    for path in glob.glob(os.path.join(glob.escape(output_dir), f"{glob.escape(image_prefix)}*.jpg")):
        if os.path.basename(path) in protected or os.path.getmtime(path) >= cutoff:
            continue
        try:
            os.remove(path)
        except OSError:
            continue
        deleted.append(path)
    return deleted
