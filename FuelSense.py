"""
╔══════════════════════════════════════════════════════════════╗
║           FuelSense — YOLO Vehicle Counter Demo              ║
║           Stage 1: Camera + YOLOv8 + Line Counting           ║
╚══════════════════════════════════════════════════════════════╝

HOW TO RUN:
-----------
1. Install requirements:
   pip install ultralytics opencv-python

2. For WEBCAM test (no camera needed):
   Just run: python fuelsense_demo.py
   (it will use your laptop webcam by default)

3. For IP CAMERA (CCTV):
   Change USE_WEBCAM = False and set your RTSP_URL below

CONTROLS:
----------
  Q = Quit
  R = Reset counts
  S = Save snapshot image
"""

from ultralytics import YOLO
import cv2
import sqlite3
import time
import datetime
import os

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

USE_WEBCAM   = True                        # True = laptop webcam, False = IP camera
RTSP_URL     = "rtsp://admin:password@192.168.1.64/stream"  # Change to your camera URL
WEBCAM_INDEX = 0                           # Usually 0 for built-in webcam

# Counting line position (as a fraction of frame height, 0.0 = top, 1.0 = bottom)
LINE_POSITION = 0.5                        # Line sits in the middle of the frame

# How often to save counts to database (in seconds)
SAVE_INTERVAL = 30

# Vehicle classes we care about from YOLO COCO dataset
# YOLO class IDs: 2=car, 3=motorcycle, 5=bus, 7=truck
VEHICLE_CLASSES = {
    2: "Car",
    3: "Bike",
    5: "Bus",
    7: "HMV"   # Heavy Motor Vehicle
}

# Colors for bounding boxes (BGR format)
CLASS_COLORS = {
    2: (0,  200, 255),   # Orange for Car
    3: (255, 200, 0),    # Blue for Bike
    5: (0,  255, 100),   # Green for Bus
    7: (100, 0, 255),    # Purple for HMV
}

# ─── DATABASE SETUP ───────────────────────────────────────────────────────────

def init_database():
    """Create local SQLite database to store vehicle counts."""
    conn = sqlite3.connect("fuelsense_counts.db")
    cursor = conn.cursor()

    # Table for periodic count snapshots
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS vehicle_counts (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp   TEXT NOT NULL,
            cars_in     INTEGER DEFAULT 0,
            bikes_in    INTEGER DEFAULT 0,
            hmv_in      INTEGER DEFAULT 0,
            cars_out    INTEGER DEFAULT 0,
            bikes_out   INTEGER DEFAULT 0,
            hmv_out     INTEGER DEFAULT 0,
            current_total INTEGER DEFAULT 0
        )
    """)

    # Table for individual crossing events
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS crossing_events (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp   TEXT NOT NULL,
            vehicle_type TEXT NOT NULL,
            direction   TEXT NOT NULL,
            confidence  REAL
        )
    """)

    conn.commit()
    conn.close()
    print("✅ Database initialized: fuelsense_counts.db")


def save_counts_to_db(counts_in, counts_out):
    """Save current counts snapshot to SQLite database."""
    conn = sqlite3.connect("fuelsense_counts.db")
    cursor = conn.cursor()

    current_total = sum(counts_in.values()) - sum(counts_out.values())
    current_total = max(0, current_total)  # Can't be negative

    cursor.execute("""
        INSERT INTO vehicle_counts
        (timestamp, cars_in, bikes_in, hmv_in, cars_out, bikes_out, hmv_out, current_total)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        datetime.datetime.now().isoformat(),
        counts_in.get("Car", 0),
        counts_in.get("Bike", 0),
        counts_in.get("HMV", 0) + counts_in.get("Bus", 0),
        counts_out.get("Car", 0),
        counts_out.get("Bike", 0),
        counts_out.get("HMV", 0) + counts_out.get("Bus", 0),
        current_total
    ))

    conn.commit()
    conn.close()


def save_crossing_event(vehicle_type, direction, confidence):
    """Log individual crossing event."""
    conn = sqlite3.connect("fuelsense_counts.db")
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO crossing_events (timestamp, vehicle_type, direction, confidence)
        VALUES (?, ?, ?, ?)
    """, (datetime.datetime.now().isoformat(), vehicle_type, direction, confidence))
    conn.commit()
    conn.close()


# ─── VEHICLE TRACKER ─────────────────────────────────────────────────────────

class VehicleTracker:
    """
    Simple centroid-based tracker.
    Tracks each detected vehicle across frames using its center point.
    Detects when a vehicle crosses the counting line.
    """

    def __init__(self, line_y, frame_height):
        self.line_y       = line_y        # Y coordinate of counting line in pixels
        self.frame_height = frame_height
        self.tracked      = {}            # {track_id: {"prev_y": float, "class": int, "counted": bool}}
        self.next_id      = 0

        # Counts
        self.counts_in  = {"Car": 0, "Bike": 0, "Bus": 0, "HMV": 0}
        self.counts_out = {"Car": 0, "Bike": 0, "Bus": 0, "HMV": 0}

    def get_center(self, box):
        """Get center point of a bounding box."""
        x1, y1, x2, y2 = box
        return int((x1 + x2) / 2), int((y1 + y2) / 2)

    def match_to_existing(self, center, class_id, threshold=80):
        """Try to match a detected vehicle to an existing tracked vehicle."""
        cx, cy = center
        best_id   = None
        best_dist = threshold

        for track_id, track in self.tracked.items():
            if track["class"] != class_id:
                continue
            px, py = track["center"]
            dist = ((cx - px) ** 2 + (cy - py) ** 2) ** 0.5
            if dist < best_dist:
                best_dist = dist
                best_id = track_id

        return best_id

    def update(self, detections):
        """
        Update tracker with new detections.
        detections = list of (box, class_id, confidence)
        Returns list of crossing events this frame.
        """
        events = []
        matched_ids = set()

        for box, class_id, conf in detections:
            if class_id not in VEHICLE_CLASSES:
                continue

            center = self.get_center(box)
            cx, cy = center

            # Try to match to existing track
            track_id = self.match_to_existing(center, class_id)

            if track_id is None:
                # New vehicle — create track
                track_id = self.next_id
                self.next_id += 1
                self.tracked[track_id] = {
                    "center":  center,
                    "prev_y":  cy,
                    "class":   class_id,
                    "counted": False,
                    "conf":    conf
                }
            else:
                matched_ids.add(track_id)
                track    = self.tracked[track_id]
                prev_y   = track["prev_y"]
                vtype    = VEHICLE_CLASSES[class_id]

                # Check if vehicle crossed the line this frame
                if not track["counted"]:
                    # Moving downward (entering) — prev above line, now below
                    if prev_y < self.line_y <= cy:
                        self.counts_in[vtype] += 1
                        track["counted"] = True
                        events.append(("IN", vtype, conf))
                        save_crossing_event(vtype, "IN", conf)

                    # Moving upward (exiting) — prev below line, now above
                    elif prev_y > self.line_y >= cy:
                        self.counts_out[vtype] += 1
                        track["counted"] = True
                        events.append(("OUT", vtype, conf))
                        save_crossing_event(vtype, "OUT", conf)

                # Update position
                track["prev_y"] = cy
                track["center"] = center
                track["counted"] = track["counted"]

        # Remove old tracks that didn't appear this frame
        stale = [tid for tid in self.tracked if tid not in matched_ids and
                 self.tracked[tid]["counted"]]
        for tid in stale[:10]:  # Clean up max 10 per frame
            del self.tracked[tid]

        return events

    @property
    def current_at_station(self):
        """How many vehicles are currently at the station."""
        total = 0
        for vtype in ["Car", "Bike", "Bus", "HMV"]:
            total += max(0, self.counts_in[vtype] - self.counts_out[vtype])
        return total

    @property
    def congestion_level(self):
        """Return congestion level based on current vehicle count."""
        n = self.current_at_station
        if n <= 5:
            return "LOW",    (0, 200, 80)    # Green
        elif n <= 10:
            return "MEDIUM", (0, 200, 255)   # Yellow/Orange
        else:
            return "HIGH",   (0, 50, 220)    # Red


# ─── DISPLAY HELPERS ─────────────────────────────────────────────────────────

def draw_ui(frame, tracker, line_y, fps, last_save_time):
    """Draw all UI elements on the frame."""
    h, w = frame.shape[:2]

    # ── Counting Line ──────────────────────────────────────────────────────
    level, level_color = tracker.congestion_level
    cv2.line(frame, (0, line_y), (w, line_y), level_color, 3)
    cv2.putText(frame, "COUNTING LINE", (10, line_y - 8),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, level_color, 2)

    # ── Top Stats Bar ──────────────────────────────────────────────────────
    cv2.rectangle(frame, (0, 0), (w, 90), (20, 30, 45), -1)
    cv2.putText(frame, "FuelSense - Live Vehicle Counter",
                (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.75, (255, 160, 50), 2)

    # FPS
    cv2.putText(frame, f"FPS: {fps:.1f}", (w - 130, 25),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (150, 150, 150), 1)

    # Counts row
    in_total  = sum(tracker.counts_in.values())
    out_total = sum(tracker.counts_out.values())
    at_station = tracker.current_at_station

    cv2.putText(frame, f"IN: {in_total}",
                (10, 65), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (100, 255, 100), 2)
    cv2.putText(frame, f"OUT: {out_total}",
                (120, 65), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (100, 150, 255), 2)
    cv2.putText(frame, f"AT STATION: {at_station}",
                (250, 65), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)

    # ── Congestion Badge ───────────────────────────────────────────────────
    badge_x = w - 200
    cv2.rectangle(frame, (badge_x, 35), (w - 10, 80), level_color, -1)
    cv2.putText(frame, level, (badge_x + 10, 67),
                cv2.FONT_HERSHEY_SIMPLEX, 0.85, (255, 255, 255), 2)

    # ── Side Panel ────────────────────────────────────────────────────────
    panel_x = w - 210
    cv2.rectangle(frame, (panel_x, 95), (w, h), (15, 25, 40), -1)

    # Vehicle breakdown
    y_pos = 120
    cv2.putText(frame, "VEHICLE BREAKDOWN", (panel_x + 10, y_pos),
                cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 160, 50), 1)
    y_pos += 30

    for vtype in ["Car", "Bike", "Bus", "HMV"]:
        inside = max(0, tracker.counts_in.get(vtype, 0) - tracker.counts_out.get(vtype, 0))
        color  = (200, 200, 200) if inside == 0 else (100, 255, 150)
        cv2.putText(frame, f"{vtype:<6}  IN:{tracker.counts_in.get(vtype,0)}  NOW:{inside}",
                    (panel_x + 10, y_pos),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.42, color, 1)
        y_pos += 25

    # DB save timer
    elapsed  = time.time() - last_save_time
    remaining = max(0, SAVE_INTERVAL - elapsed)
    cv2.putText(frame, f"DB save in: {remaining:.0f}s",
                (panel_x + 10, y_pos + 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.40, (100, 100, 150), 1)

    # Timestamp
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    cv2.putText(frame, ts, (panel_x + 50, h - 15),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (150, 150, 150), 1)

    # ── Controls hint ─────────────────────────────────────────────────────
    cv2.putText(frame, "Q=Quit  R=Reset  S=Snapshot",
                (10, h - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (100, 100, 100), 1)

    return frame


# ─── MAIN FUNCTION ────────────────────────────────────────────────────────────

def main():
    print("\n🚀 FuelSense Vehicle Counter Starting...\n")

    # Initialize database
    init_database()

    # Load YOLO model
    print("⏳ Loading YOLOv8 model...")
    model = YOLO("yolov8n.pt")  # 'n' = nano (fastest). Use 'yolov8s.pt' for better accuracy
    print("✅ YOLO model loaded!\n")

    # Open video source
    if USE_WEBCAM:
        print(f"📷 Opening webcam (index {WEBCAM_INDEX})...")
        cap = cv2.VideoCapture(WEBCAM_INDEX)
    else:
        print(f"📷 Connecting to IP camera: {RTSP_URL}")
        cap = cv2.VideoCapture(RTSP_URL)

    if not cap.isOpened():
        print("❌ ERROR: Could not open camera. Check your camera connection or RTSP URL.")
        return

    # Get frame dimensions
    ret, frame = cap.read()
    if not ret:
        print("❌ ERROR: Could not read first frame.")
        return

    h, w = frame.shape[:2]
    line_y = int(h * LINE_POSITION)

    print(f"✅ Camera opened! Frame size: {w}x{h}")
    print(f"📏 Counting line at y={line_y} (middle of frame)")
    print("\n🔴 Live feed starting... Press Q to quit\n")

    # Initialize tracker
    tracker = VehicleTracker(line_y=line_y, frame_height=h)

    # FPS tracking
    fps         = 0
    fps_counter = 0
    fps_start   = time.time()

    # DB save timer
    last_save_time = time.time()

    # Snapshot counter
    snapshot_count = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            print("⚠️  Frame read failed. Retrying...")
            time.sleep(0.5)
            continue

        # ── Run YOLO detection ───────────────────────────────────────────
        results = model(frame, verbose=False, classes=list(VEHICLE_CLASSES.keys()))

        # Collect detections
        detections = []
        for result in results:
            for box in result.boxes:
                class_id = int(box.cls[0])
                conf     = float(box.conf[0])
                if conf < 0.4:   # Skip low-confidence detections
                    continue
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                detections.append(((x1, y1, x2, y2), class_id, conf))

        # ── Update tracker and check for crossings ───────────────────────
        events = tracker.update(detections)

        # Print crossing events to console
        for direction, vtype, conf in events:
            arrow = "⬇ ENTERED" if direction == "IN" else "⬆ EXITED "
            print(f"  {arrow}  {vtype:<5}  (conf: {conf:.2f})  |  At station: {tracker.current_at_station}")

        # ── Draw bounding boxes ──────────────────────────────────────────
        for (x1, y1, x2, y2), class_id, conf in detections:
            color = CLASS_COLORS.get(class_id, (200, 200, 200))
            vtype = VEHICLE_CLASSES.get(class_id, "Unknown")
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            label = f"{vtype} {conf:.0%}"
            cv2.rectangle(frame, (x1, y1 - 22), (x1 + len(label) * 10, y1), color, -1)
            cv2.putText(frame, label, (x1 + 2, y1 - 5),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

        # ── Draw UI ──────────────────────────────────────────────────────
        draw_ui(frame, tracker, line_y, fps, last_save_time)

        # ── Show frame ───────────────────────────────────────────────────
        cv2.imshow("FuelSense - Vehicle Counter", frame)

        # ── FPS calculation ───────────────────────────────────────────────
        fps_counter += 1
        if time.time() - fps_start >= 1.0:
            fps       = fps_counter
            fps_counter = 0
            fps_start = time.time()

        # ── Save to DB every SAVE_INTERVAL seconds ────────────────────────
        if time.time() - last_save_time >= SAVE_INTERVAL:
            save_counts_to_db(tracker.counts_in, tracker.counts_out)
            print(f"\n💾 Saved to DB at {datetime.datetime.now().strftime('%H:%M:%S')} — At station: {tracker.current_at_station}\n")
            last_save_time = time.time()

        # ── Key controls ─────────────────────────────────────────────────
        key = cv2.waitKey(1) & 0xFF

        if key == ord('q'):
            print("\n👋 Quitting...")
            break

        elif key == ord('r'):
            print("\n🔄 Counts reset!")
            tracker.counts_in  = {"Car": 0, "Bike": 0, "Bus": 0, "HMV": 0}
            tracker.counts_out = {"Car": 0, "Bike": 0, "Bus": 0, "HMV": 0}

        elif key == ord('s'):
            snapshot_count += 1
            fname = f"snapshot_{snapshot_count:03d}.jpg"
            cv2.imwrite(fname, frame)
            print(f"📸 Snapshot saved: {fname}")

    # ── Cleanup ───────────────────────────────────────────────────────────
    save_counts_to_db(tracker.counts_in, tracker.counts_out)
    cap.release()
    cv2.destroyAllWindows()

    print("\n" + "="*50)
    print("📊 FINAL SESSION SUMMARY")
    print("="*50)
    print(f"  Cars entered  : {tracker.counts_in['Car']}")
    print(f"  Bikes entered : {tracker.counts_in['Bike']}")
    print(f"  HMV entered   : {tracker.counts_in['HMV'] + tracker.counts_in['Bus']}")
    print(f"  Total IN      : {sum(tracker.counts_in.values())}")
    print(f"  Total OUT     : {sum(tracker.counts_out.values())}")
    print(f"  Still at station: {tracker.current_at_station}")
    print(f"  Data saved to : fuelsense_counts.db")
    print("="*50)


if __name__ == "__main__":
    main()