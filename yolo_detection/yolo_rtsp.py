from ultralytics import YOLO
import cv2
import time

# Load model
model = YOLO("yolov8n.pt")

# RTSP link (replace this)
rtsp_url = "rtsp://username:password@ip:554/stream"

cap = cv2.VideoCapture(rtsp_url)

def get_traffic(count):
    if count < 5:
        return "Low"
    elif count < 15:
        return "Medium"
    else:
        return "High"

while True:
    ret, frame = cap.read()
    if not ret:
        print("Failed to connect to camera")
        break

    results = model(frame)

    vehicle_count = 0

    for r in results:
        for box in r.boxes:
            cls = int(box.cls[0])

            # car=2, bus=5, truck=7
            if cls in [2, 5, 7]:
                vehicle_count += 1

    traffic = get_traffic(vehicle_count)

    print(f"Vehicles: {vehicle_count} | Traffic: {traffic}")

    annotated = results[0].plot()
    cv2.imshow("FuelSense YOLO", annotated)

    time.sleep(2)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()