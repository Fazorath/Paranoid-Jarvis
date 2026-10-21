#!/usr/bin/env python3

import cv2
import datetime
import os
import configparser

from paranoid_jarvis import event_log

# Load config
config = configparser.ConfigParser()
config.read(os.path.join(os.path.dirname(__file__), 'paranoid_jarvis.conf'))

output_dir = os.path.expanduser(config.get('general', 'output_dir', fallback='~/ParanoidJarvisLogs'))
os.makedirs(output_dir, exist_ok=True)
retention_days = config.getint('general', 'retention_days', fallback=event_log.DEFAULT_RETENTION_DAYS)
heartbeat_minutes = config.getint('general', 'heartbeat_minutes', fallback=15)
camera_index = config.getint('general', 'camera_index', fallback=0)
log_file = config.get('general', 'log_file', fallback='events.jsonl')
image_prefix = config.get('general', 'image_prefix', fallback='startup_image_')
log_path = os.path.join(output_dir, log_file)

def take_picture():
    """Capture one photo and return its file name, or None if no frame was read."""
    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    img_filename = f"{image_prefix}{timestamp}.jpg"
    img_path = os.path.join(output_dir, img_filename)
    cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        raise Exception('Could not open camera')
    try:
        # Warm up the camera by grabbing and discarding a few frames
        for _ in range(5):
            cap.read()
        ret, frame = cap.read()
        if ret and cv2.imwrite(img_path, frame):
            return img_filename
        return None
    finally:
        cap.release()

def main():
    photo = None
    try:
        photo = take_picture()
    finally:
        # Log the login even if capture failed, so the attempt is on record.
        event_log.append_event(log_path, 'login', photo=photo,
                               power=event_log.power_source())
        event_log.apply_retention(output_dir, log_path, image_prefix, retention_days)

if __name__ == '__main__':
    main()
