# Paranoid-Jarvis: MacBook Startup Camera Logger

Paranoid-Jarvis is a privacy/security tool for macOS that automatically takes a photo with your MacBook's front-facing camera and logs the startup time every time you log in or open your laptop. Easily enable or disable this feature with a simple terminal toggle script.

## Features
- Captures a photo with the front-facing camera at each login/startup
- Logs the date and time of each startup
- Toggle the feature on/off with a single command
- Clean, user-friendly terminal interface
- All logs and images are stored locally for your review

## Requirements
- macOS
- Python 3.7+
- OpenCV (`opencv-python`)

## Setup
1. Clone this repository:
   ```sh
   git clone https://github.com/yourusername/Paranoid-Jarvis.git
   cd Paranoid-Jarvis
   ```
2. Set up a Python virtual environment and install dependencies:
   ```sh
   python3 -m venv .venv
   source .venv/bin/activate
   pip install opencv-python
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
- When enabled, a Launch Agent runs the Python script at login/startup.
- The script takes a photo and logs the time to `~/ParanoidJarvisLogs/`.
- Use the toggle script to move the Launch Agent plist in/out of the system folder, turning the feature on or off.

## Security & Privacy
- All photos and logs are stored locally and never leave your device.
- You control when the feature is enabled or disabled.

## Uninstall
1. Use the toggle script to disable the feature.
2. Delete the project folder and logs as desired.

---

# GitHub Description

A macOS tool that takes a photo with your MacBook's camera and logs the time every time you log in. Easily toggle the feature on or off with a single command. All data stays local for your privacy.
