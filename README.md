# Paranoid-Jarvis: MacBook Startup Camera Logger

Paranoid-Jarvis is a privacy/security tool for macOS that automatically takes a photo with your MacBook's front-facing camera and logs the startup time every time you log in or open your laptop. Easily enable or disable this feature with a simple terminal toggle script.

## Features
- Captures a photo with the front-facing camera at each login/startup
- Logs the date and time of each startup
- Toggle the feature on/off with a single command
- Clean, user-friendly terminal interface
- All logs and images are stored locally for your review

## Quick Start for Most Users
This project uses the system Python (`/usr/bin/python3`) for maximum compatibility. You must install the required Python packages globally or with `--user`.

## Requirements
- macOS
- Python 3.7+ (system Python is fine)
- Python packages: `opencv-python`, `configparser`

## Setup
1. Clone this repository:
   ```sh
   git clone https://github.com/yourusername/Paranoid-Jarvis.git
   cd Paranoid-Jarvis
   ```
2. Install dependencies globally or with --user:
   ```sh
   pip3 install --user -r requirements.txt
   ```
3. Make the toggle script executable:
   ```sh
   chmod +x toggle_startup_cam.sh
   ```
4. Use the toggle script to enable or disable the startup camera logger:
   ```sh
   ./toggle_startup_cam.sh
   ```

## How It Works
- When enabled, a Launch Agent runs the Python script at login/startup using the system Python.
- The script takes a photo and logs the time to `~/ParanoidJarvisLogs/`.
- Use the toggle script to move the Launch Agent plist in/out of the system folder, turning the feature on or off.

## Security & Privacy
- All photos and logs are stored locally and never leave your device.
- You control when the feature is enabled or disabled.
- No virtual environment is required for basic use.

## Uninstall
1. Use the toggle script to disable the feature.
2. Delete the project folder and logs as desired.

---

# GitHub Description

A macOS tool that takes a photo with your MacBook's camera and logs the time every time you log in. Easily toggle the feature on or off with a single command. All data stays local for your privacy.
