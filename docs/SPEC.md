# Paranoid-Jarvis Upgrade Spec

Status: agreed (grilling session, 2026-10-20). Board: https://github.com/users/Fazorath/projects/5

## 1. Purpose & threat model

- **Audience:** personal tool, but installable by a stranger with one command and a README they can follow. No Homebrew/.app packaging.
- **Primary threat:** snooping — someone with physical access opens the Mac while the owner is away.
- **Stretch threat:** theft — covered by pushing the photo off-device at capture time (the alert sink *is* the offsite copy).
- **Out of scope:** capture at the pre-login login window (not possible from a LaunchAgent; no user TCC context).

## 2. Supported platforms

- macOS ≥ 14 (soft floor); tested on macOS 26.
- Python ≥ 3.11 (required for `tomllib`).

## 3. Phasing

| Phase | Goal |
|---|---|
| 1 | Make the existing login-capture tool work and be robust. Keep `.conf` and opencv. |
| 2 | Intrusion detection: resident agent, wake/lock/unlock triggers, alerts. |
| Backlog | Deferred ideas (see §8). |

## 4. Phase 1 — Working & robust

### 4.1 Install (`install.sh`)
- Creates `.venv` in the repo with `python3 -m venv` and installs `requirements.txt`.
- Renders the LaunchAgent plist from a committed template (`com.paranoidjarvis.startupcam.plist.template`) with the real repo path and venv interpreter. No hardcoded paths anywhere.
- Ends with an **interactive test capture** from the terminal so the macOS camera (TCC) prompt appears while the user is present; verifies a JPG was written; prints a clear remediation message (System Settings → Privacy & Security → Camera) on failure.

### 4.2 Enable / disable
- Enable **copies** the rendered plist into `~/Library/LaunchAgents/` and uses `launchctl bootstrap gui/$UID`. Disable uses `launchctl bootout` and removes the copy.
- Tracked repo files are never moved or modified; `git status` stays clean after enable/disable.

### 4.3 Toggle script
- Non-interactive subcommands: `toggle_startup_cam.sh enable|disable|status`. Interactive menu remains only when no argument is given.
- Reads output dir / log file from `paranoid_jarvis.conf` instead of hardcoding.
- `status` also re-runs the camera-permission check.

### 4.4 Capture & logging robustness
- Camera open failures, failed frame reads and TCC denials each produce a log entry plus a hint; non-zero exit.
- Replace ad-hoc `open()/write` with the `logging` module; no bare `except: pass`.
- launchd stdout/stderr go to the output directory, not `/tmp`.
- Camera warm-up is time-based (or waits for frame brightness to stabilise), not a fixed 5 frames.
- "Power Connected" event kept as-is. (Superseded in Phase 2 by the `power` event field, §5.6.)

### 4.5 Repo hygiene
- `requirements.txt`: drop `configparser` (stdlib), pin `opencv-python`.
- Add `.gitignore` (`.venv`, rendered plist, `__pycache__`) and an MIT `LICENSE`.
- README rewritten to match reality: venv-based install via `install.sh`, correct clone URL, toggle subcommands, manual smoke-test checklist.

## 5. Phase 2 — Intrusion detection

### 5.1 Capture backend spike (first)
Time-boxed spike: run `imagesnap` (subprocess) and pyobjc-AVFoundation (in-process) under a real LaunchAgent; record which binary the Camera TCC entry is attributed to, behaviour across a Homebrew Python upgrade, and frame quality. Pick one; drop opencv if possible. Leaning pyobjc since it is required for §5.2 anyway.

### 5.2 Resident agent & triggers
- Single resident LaunchAgent (`RunAtLoad` + `KeepAlive`) running a run loop via pyobjc.
- Events:
  - `login` — agent start.
  - `wake` — `NSWorkspaceDidWakeNotification` (lid open / system wake).
  - `screen_wake_locked` — display wakes while the session is locked.
  - `unlock` — `com.apple.screenIsUnlocked` distributed notification.
  - (`lock` tracked internally to know locked state.)
- Periodic `heartbeat` log entry.

### 5.3 Intrusion logic
- On `screen_wake_locked`: capture **immediately**, then wait **N seconds** (default 30, configurable).
  - `unlock` within N → photo classified as owner; normal retention.
  - No unlock within N → **suspected intrusion**: send alert with photo; photo marked never-delete.
- Rate limits: max 1 capture / 15 s; max 1 alert / 5 min. Suppressed attempts are counted and the next alert reads "+K more attempts" with the latest photo.
- Only suspected intrusions alert. All other events are log-only.

### 5.4 Alert sinks
- Pluggable sink interface (`send(event, photo_path, context)`).
- Sink 1: **ntfy** (HTTP POST with photo attachment). Sink 2: **Telegram** bot.
- Alert context includes Wi-Fi SSID and public IP (public IP fetched at alert time, failure tolerated).
- `pj test-alert` sends a test message through every configured sink.

### 5.5 Config & secrets
- TOML config at `~/.config/paranoid-jarvis/config.toml`; committed `config.example.toml`; installer creates the real config from the example. Nested sections (`[sinks.ntfy]`, `[intrusion]`, …).
- Secrets (ntfy topic, Telegram token) stored in macOS Keychain via the `security` CLI; config references the Keychain item name only. Installer prompts for them.
- Old `.conf` may be migrated or ignored (single existing user).

### 5.6 Event log & retention
- Stored log is JSON Lines, one object per event: `ts`, `event`, `photo`, `power` (`ac|battery`), `classification`, plus context fields.
- `pj logs` renders the human-readable `[YYYY-MM-DD HH:MM:SS] EVENT: …` format.
- Retention is age-based (default 30 days); photos tied to suspected intrusions are never auto-deleted.

### 5.7 CLI (`pj`)
- Python package `paranoid_jarvis/` exposing `pj` with subcommands: `enable | disable | status | test-capture | test-alert | logs | uninstall [--purge]`. Replaces `toggle_startup_cam.sh`; no interactive menu.
- `uninstall` boots out and removes the LaunchAgent and Keychain items; keeps photos/logs unless `--purge`.

### 5.8 Testing
- pytest unit tests with camera, sinks, `pmset`, notifications and clock mocked (intrusion state machine and rate limiting are the priority).
- Manual smoke-test checklist in README for launchd/TCC behaviour.

## 6. Constraints & known risks

- Camera TCC permission attaches to the resolved interpreter binary (Homebrew Python here), not to "Paranoid-Jarvis"; shared with other tools using that Python and may need re-grant after interpreter changes. §5.1 spike resolves the mitigation.
- The green camera LED always lights during capture (hardware-enforced).
- Failed-password details in the unified log are `<private>`-redacted for non-root processes, so failed attempts are inferred from §5.3 rather than read directly.

## 7. Decisions log (abridged)

Personal-but-installable · snooping primary / theft stretch · two phases · ntfy then Telegram via sink interface · alert = offsite copy · install.sh + repo venv · 30-day age retention, intrusion photos kept · TOML in `~/.config` · Keychain secrets · pytest with mocks, no CI · triggers login/wake/screen-wake-locked/unlock · capture backend by spike · interactive first-run capture · resident KeepAlive agent · alert only on intrusion (N=30 s) · capture at wake · 15 s / 5 min limits · power as event field · `pj` CLI · JSON Lines log · uninstall keeps evidence unless `--purge` · macOS ≥ 14, Python ≥ 3.11 · MIT.

## 8. Backlog

- Dedicated cloud backup of photos (S3 / iCloud folder).
- Precise location via CoreLocation.
- Failed-password detection via unified log (needs root or logging profile).
- Suppress alerts on trusted Wi-Fi.
- GitHub Actions CI running pytest.
- Encryption of photos at rest (#13, closed).
