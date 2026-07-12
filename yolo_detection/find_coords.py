import pyautogui
import time

print("5 seconds mein mouse ko Video ke TOP-LEFT corner pe le jao...")
time.sleep(5)
pos1 = pyautogui.position()
print(f"Top-Left: {pos1}")

print("Ab 5 seconds mein mouse ko Video ke BOTTOM-RIGHT corner pe le jao...")
time.sleep(5)
pos2 = pyautogui.position()
print(f"Bottom-Right: {pos2}")

print(f"\nmonitor dict:")
print(f"top: {pos1.y}")
print(f"left: {pos1.x}")
print(f"width: {pos2.x - pos1.x}")
print(f"height: {pos2.y - pos1.y}")