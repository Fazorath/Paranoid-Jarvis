# Paranoid-Jarvis: MacBook Startup Camera Logger

Paranoid-Jarvis is a privacy/security tool for macOS that automatically takes a photo with your MacBook's front-facing camera and logs the startup time every time you log in or open your laptop. Easily enable or disable this feature with a simple terminal toggle script.

## Features
- Captures a photo with the front-facing camera at each login/startup
- Logs the date and time of each startup in a clear, human-readable format
- Toggle the feature on/off with a single command
- Clean, user-friendly terminal interface
- All logs and images are stored locally for your review

## Requirements
- macOS
- Python 3.11+ (dependencies are installed into a repo-local `.venv` by `install.sh`)

## Setup
1. Clone this repository:
   ```sh
   git clone https://github.com/Fazorath/Paranoid-Jarvis.git
   cd Paranoid-Jarvis
   ```
2. Run the installer (Python 3.11+ required; set `PYTHON=/path/to/python3` to choose one):
   ```sh
   ./install.sh
   ```
   It creates `.venv`, installs `requirements.txt`, renders the Launch Agent plist for this checkout from `com.paranoidjarvis.startupcam.plist.template`, and takes a test photo. Click **Allow** if macOS asks for camera access; if the test fails, enable Python under System Settings → Privacy & Security → Camera and re-run.
3. Use the toggle script to enable or disable the startup camera logger:
   ```sh
   ./toggle_startup_cam.sh
   ```

## How It Works
- When enabled, a Launch Agent runs the Python script at login/startup using the repo's `.venv` Python.
- The script takes a photo and logs the time to `~/ParanoidJarvisLogs/`.
- Log entries are now more readable, for example:

   ```
   [2025-09-09 10:15:00] EVENT: Startup
   [2025-09-09 10:15:01] EVENT: Power Connected
   [2025-09-09 10:15:02] EVENT: Photo Taken - File: startup_image_20250909_101502.jpg
   ```
- Enabling copies the rendered plist into `~/Library/LaunchAgents/` and runs `launchctl bootstrap`; disabling runs `launchctl bootout` and removes the copy. Repo files are never moved, so `git status` stays clean.

## Security & Privacy
- All photos and logs are stored locally and never leave your device.
- You control when the feature is enabled or disabled.

## Uninstall
1. Use the toggle script to disable the feature.
2. Delete the project folder and logs as desired.

---

# GitHub Description

A macOS tool that takes a photo with your MacBook's camera and logs the time every time you log in. Easily toggle the feature on or off with a single command. All data stays local for your privacy.
