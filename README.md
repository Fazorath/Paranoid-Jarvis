# Paranoid-Jarvis

Paranoid-Jarvis takes a photo with your Mac's front camera every time you log in and records the time in a local log. If someone opens your Mac while you're away, you'll know, and you'll see their face.

It is a personal tool, not a packaged app: you clone the repo, run one installer, and enable a macOS Launch Agent. The design and roadmap are in [docs/SPEC.md](docs/SPEC.md).

## Supported platforms

- **macOS 14 (Sonoma) or later.** Tested on macOS 26.
- **Python 3.11 or later.** Homebrew Python works (`brew install python`). Dependencies go into a `.venv` inside the repo; nothing is installed system-wide or with `pip --user`.

## Install

```sh
git clone https://github.com/Fazorath/Paranoid-Jarvis.git
cd Paranoid-Jarvis
./install.sh
```

`install.sh`:

1. Checks that `python3` is 3.11 or later. To use a different interpreter, run `PYTHON=/path/to/python3 ./install.sh`.
2. Creates `.venv/` in the repo and installs `requirements.txt` into it.
3. Renders `com.paranoidjarvis.startupcam.plist` from `com.paranoidjarvis.startupcam.plist.template`, filling in this checkout's path and the venv's Python. The rendered file is git-ignored.
4. Takes a test photo from the terminal so macOS asks for camera access while you're there (see [Camera permission](#camera-permission)). If no new photo appears in the output directory, the installer exits non-zero and tells you how to fix it.

You can run `./install.sh` again, for example after moving the repo or upgrading Python. Then choose Enable again (`./toggle_startup_cam.sh` → `1`): it notices that the copy in `~/Library/LaunchAgents/` is out of date, boots out the running agent and installs the new copy.

## Enable, disable, status

```sh
./toggle_startup_cam.sh
```

This opens a menu:

| Option | What it does |
|---|---|
| `1` Enable | Copies the rendered plist into `~/Library/LaunchAgents/` and runs `launchctl bootstrap gui/$UID`. A capture runs right away, then at every login. Repo files are never moved, so `git status` stays clean. |
| `2` Disable | Runs `launchctl bootout` and removes the copy from `~/Library/LaunchAgents/`. If bootout fails, the copy is kept and the script exits non-zero. |
| `3` Status | Says whether a copy is in `~/Library/LaunchAgents/` (enabled) or only the rendered plist in the repo (disabled), and shows the last line of `~/ParanoidJarvisLogs/events.jsonl`. It doesn't ask `launchctl`, and it ignores `output_dir`/`log_file` changes in the config. |
| `h` / `q` | Help / quit. |

`./toggle_startup_cam.sh --help` prints the same options.

> **Coming soon:** non-interactive `enable`, `disable` and `status` subcommands ([#9](https://github.com/Fazorath/Paranoid-Jarvis/issues/9)). This section will change when they land.

## Camera permission

macOS asks before any app uses the camera. Things to know:

- **The permission belongs to whatever launched the capture, not to Paranoid-Jarvis.** At login, launchd runs the venv's `python`, a symlink to the interpreter you installed with, so the Camera entry is "Python". The installer's test capture runs from your terminal, and macOS may charge it to the terminal app instead. So a passing install doesn't prove the login capture will work. The first login after enabling is the real test (see the [smoke test](#manual-smoke-test)). Any other script run by that same Python shares the permission.
- **Upgrading or reinstalling Python can reset it.** If captures stop after a Homebrew upgrade, re-run `./install.sh` and allow access again.
- **If you clicked "Don't Allow"** or the installer's test capture failed: open **System Settings → Privacy & Security → Camera**, turn on the entry for Python (and/or your terminal), then re-run `./install.sh`.
- **The green camera light always turns on during a capture.** The hardware controls that light and software can't turn it off. Expect a brief flash at login.

## Where things go

Everything stays on your Mac. Settings live in `paranoid_jarvis.conf`:

| Setting | Default | Meaning |
|---|---|---|
| `output_dir` | `~/ParanoidJarvisLogs` | Where photos and the log are written |
| `retention_days` | `30` | Photos older than this are deleted; suspected-intrusion photos are always kept |
| `camera_index` | `0` | Which camera to use (0 = built-in) |
| `log_file` | `events.jsonl` | Event log file name inside `output_dir` |
| `image_prefix` | `startup_image_` | Photo file name prefix |

The log is JSON Lines, one object per event:

```
{"ts": "2026-10-20T10:15:02-04:00", "event": "login", "photo": "startup_image_20261020_101502.jpg", "power": "ac", "classification": null, "context": {}}
```

`photo` is `null` if the capture failed, and `power` (`ac` or `battery`) is `null` only if `pmset` can't be read.

When the script runs under launchd, its stdout and stderr go to `/tmp/startupcam.log` and `/tmp/startupcam.err`. Look there if the log above stops growing.

## Manual smoke test

Automated tests can't cover launchd and camera permission, so after installing or changing anything, check these by hand:

- [ ] `./install.sh` finishes with `Test capture OK: …` and prints the path of a new JPG.
- [ ] The photo opens and shows your face, not a black frame.
- [ ] `./toggle_startup_cam.sh` → `1` (Enable) prints `Startup camera logger ENABLED.`, and a new photo and `EVENT: Startup` line appear in your `output_dir` within a few seconds.
- [ ] `launchctl list | grep paranoidjarvis` shows `com.paranoidjarvis.startupcam`.
- [ ] Log out and back in (or restart). A new photo and log entry appear, and the green light flashed at login. If not, check `/tmp/startupcam.err` for a camera error and allow Python under Privacy & Security → Camera.
- [ ] `./toggle_startup_cam.sh` → `3` (Status) reports `ENABLED` and shows the latest log line.
- [ ] `./toggle_startup_cam.sh` → `2` (Disable) prints `DISABLED`. `launchctl list | grep paranoidjarvis` prints nothing, and logging in again takes no photo.
- [ ] `git status` shows no changes to tracked files.
- [ ] `/tmp/startupcam.err` has no errors.

## Uninstall

1. Disable the agent: `./toggle_startup_cam.sh` → `2`.
2. Delete the repo folder.
3. If you want, delete your `output_dir` (default `~/ParanoidJarvisLogs/`) and remove Python from System Settings → Privacy & Security → Camera.

## Tests

```sh
bash tests/test_install.sh
zsh tests/test_toggle.zsh
```
