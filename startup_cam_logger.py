
import cv2
import datetime
import os
import configparser
import glob

# Load config
config = configparser.ConfigParser()
config.read(os.path.join(os.path.dirname(__file__), 'paranoid_jarvis.conf'))

output_dir = os.path.expanduser(config.get('general', 'output_dir', fallback='~/ParanoidJarvisLogs'))
os.makedirs(output_dir, exist_ok=True)
max_images = config.getint('general', 'max_images', fallback=5)
camera_index = config.getint('general', 'camera_index', fallback=0)
log_file = config.get('general', 'log_file', fallback='startup_log.txt')
image_prefix = config.get('general', 'image_prefix', fallback='startup_image_')
log_path = os.path.join(output_dir, log_file)

def take_picture():
    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    img_filename = f"{image_prefix}{timestamp}.jpg"
    img_path = os.path.join(output_dir, img_filename)
    cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        raise Exception('Could not open camera')
    ret, frame = cap.read()
    if ret:
        cv2.imwrite(img_path, frame)
    cap.release()
    cleanup_old_images()

def cleanup_old_images():
    images = sorted(glob.glob(os.path.join(output_dir, f"{image_prefix}*.jpg")))
    if len(images) > max_images:
        for img in images[:-max_images]:
            try:
                os.remove(img)
            except Exception:
                pass

def log_startup_time():
    with open(log_path, 'a') as f:
        f.write(f"Startup: {datetime.datetime.now().isoformat()}\n")

def main():
    log_startup_time()
    take_picture()

if __name__ == '__main__':
    main()
