import cv2
import numpy as np
import mss
from ultralytics import YOLO
import time
import requests
from tkinter import messagebox
import tkinter as tk

model = YOLO("yolov8n.pt")

monitor = {
    "top": 374,
    "left": 504,
    "width": 1316,
    "height": 538
}

BACKEND_URL = "http://127.0.0.1:8000/api/update_queue/"
def send_to_backend(count):
    try:
        requests.post(BACKEND_URL, json={
            "station_id": 1,
            "vehicle_count": count,
            "api_key": "fuelsense2024"
        }, timeout=2)
        print(f"Bheja: {count} vehicles")
    except:
        print("Backend unavailable")


time.sleep(8)

count = 0
start_time = time.time()

with mss.mss() as sct:
    while True:
        elapsed = time.time() - start_time
        if elapsed >= 120:
            break

        count += 1
        if count % 5 != 0:
            continue

        frame = np.array(sct.grab(monitor))
        frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
        frame = cv2.resize(frame, (416, 416))

        results = model(frame, conf=0.3)
        vehicle_count = len(results[0].boxes)
        annotated = results[0].plot()

        cv2.putText(annotated, f"Vehicles: {vehicle_count}",
                    (10, 30), cv2.FONT_HERSHEY_SIMPLEX,
                    1, (0, 255, 0), 2)

        send_to_backend(vehicle_count)

        cv2.imshow("FuelSense Detection", annotated)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

cv2.destroyAllWindows()

root = tk.Tk()
root.withdraw()
messagebox.showinfo("FuelSense", "2 minute capture complete!\nDetection band ho gaya.")
root.destroy()