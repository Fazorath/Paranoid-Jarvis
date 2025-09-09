import cv2
import datetime
import os

# Set up paths
output_dir = os.path.expanduser('~/ParanoidJarvisLogs')
os.makedirs(output_dir, exist_ok=True)
img_path = os.path.join(output_dir, 'startup_image.jpg')
log_path = os.path.join(output_dir, 'startup_log.txt')

def take_picture():
    # 0 is usually the front camera on MacBooks
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        raise Exception('Could not open camera')
    ret, frame = cap.read()
    if ret:
        cv2.imwrite(img_path, frame)
    cap.release()

def log_startup_time():
    with open(log_path, 'a') as f:
        f.write(f"Startup: {datetime.datetime.now().isoformat()}\n")

def main():
    log_startup_time()
    take_picture()

if __name__ == '__main__':
    main()
