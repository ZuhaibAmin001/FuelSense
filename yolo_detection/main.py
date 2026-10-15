import cv2
import numpy as np
import mss
from ultralytics import YOLO
import time
import requests

model = YOLO("yolov8n.pt")

# ── Station settings ──────────────────────────────────────────────────────
# Attock k liye: STATION_ID = 1
# Total Petrol k liye: STATION_ID = 2
STATION_ID = 2  # ← yahan sirf number change karo

# ── Coordinates ───────────────────────────────────────────────────────────
# Attock coordinates
MONITORS = {
    1: {"top": 374, "left": 504, "width": 1316, "height": 538},
    # Total Petrol coordinates — find_coords.py se nikaal ke yahan daalo
    2: {"top": 88, "left": 351, "width": 463, "height": 939},
}

monitor = MONITORS[STATION_ID]

BACKEND_URL = "http://127.0.0.1:8000/api/update_queue/"
VEHICLE_CLASSES = [2, 3, 5, 7]  # car, motorcycle, bus, truck

def send_to_backend(count):
    try:
        requests.post(BACKEND_URL, json={
            "station_id": STATION_ID,
            "vehicle_count": count,
            "api_key": "fuelsense2024"
        }, timeout=2)
        print(f"Station {STATION_ID} → Bheja: {count} vehicles")
    except:
        print("Backend unavailable")

print(f"FuelSense — Station {STATION_ID} chal raha hai...")
print("Band karne k liye Q dabao\n")

frame_count = 0

with mss.mss() as sct:
    while True:
        frame_count += 1
        if frame_count % 5 != 0:
            time.sleep(0.05)
            continue

        frame = np.array(sct.grab(monitor))
        frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
        frame = cv2.resize(frame, (640, 640))

        results = model(frame, conf=0.35, verbose=False)

        vehicle_count = 0
        for box in results[0].boxes:
            if int(box.cls[0]) in VEHICLE_CLASSES:
                vehicle_count += 1

        send_to_backend(vehicle_count)

        annotated = results[0].plot()
        color = (0,255,0) if vehicle_count <= 10 else (0,165,255) if vehicle_count <= 25 else (0,0,255)
        cv2.rectangle(annotated, (0,0), (300,60), (0,0,0), -1)
        cv2.putText(annotated, f"Station {STATION_ID}: {vehicle_count} vehicles", (10,35), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)

        cv2.imshow(f"FuelSense — Station {STATION_ID}", annotated)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

cv2.destroyAllWindows()