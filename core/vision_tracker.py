"""
vision_tracker.py
Webcam capture via OpenCV + hand landmark detection via MediaPipe Tasks API.
Works with mediapipe >= 0.10.x (new Tasks API only — no mp.solutions).
"""
import os
import cv2
import numpy as np
from PIL import Image
import customtkinter as ctk

# MediaPipe Tasks API (works in mediapipe 0.10.x and 1.x)
import mediapipe as mp
from mediapipe.tasks.python import BaseOptions
from mediapipe.tasks.python.vision import (
    HandLandmarker,
    HandLandmarkerOptions,
    RunningMode,
)

from core.gesture_model import GestureModel

# Path to the downloaded .task model file
_MODEL_PATH = os.path.join(os.path.dirname(__file__), "hand_landmarker.task")

# MediaPipe Hand connections (21 landmarks, standard indices)
_HAND_CONNECTIONS = [
    (0,1),(1,2),(2,3),(3,4),          # thumb
    (0,5),(5,6),(6,7),(7,8),          # index
    (0,9),(9,10),(10,11),(11,12),     # middle
    (0,13),(13,14),(14,15),(15,16),   # ring
    (0,17),(17,18),(18,19),(19,20),   # pinky
    (5,9),(9,13),(13,17),             # palm
]


class VisionTracker:
    """Live camera tracking via OpenCV + MediaPipe Tasks HandLandmarker."""

    def __init__(self):
        self.cap = None
        self.running = False
        self.landmarker = None
        self.camera_available = False
        self.last_error = ""
        self.gesture_model = GestureModel()
        self._last_landmarks = None   # cache last result (Tasks API is async-friendly)

        self._init_landmarker()
        self.start()

    # ── Setup ─────────────────────────────────────────────────────────────────
    def _init_landmarker(self):
        if not os.path.exists(_MODEL_PATH):
            print("[VisionTracker] Model file missing:", _MODEL_PATH)
            return
        try:
            opts = HandLandmarkerOptions(
                base_options=BaseOptions(model_asset_path=_MODEL_PATH),
                running_mode=RunningMode.IMAGE,   # simple per-frame mode
                num_hands=1,
                min_hand_detection_confidence=0.6,
                min_hand_presence_confidence=0.6,
                min_tracking_confidence=0.5,
            )
            self.landmarker = HandLandmarker.create_from_options(opts)
            print("[VisionTracker] HandLandmarker ready.")
        except Exception as e:
            self.last_error = f"Hand model error: {e}"
            print(f"[VisionTracker] Failed to init landmarker: {e}")

    def start(self):
        if not self.running:
            self.cap = cv2.VideoCapture(0)
            if not self.cap or not self.cap.isOpened():
                self.last_error = "Camera 0 could not be opened."
                if self.cap:
                    self.cap.release()
                self.cap = None
                self.camera_available = False
                return False
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.running = True
            self.camera_available = True
        return True

    def stop(self):
        self.running = False
        self.camera_available = False
        if self.cap:
            self.cap.release()
            self.cap = None

    # ── Main Frame Getter ─────────────────────────────────────────────────────
    def get_frame(self):
        """Returns (CTkImage | None, gesture_str, confidence_int 0-100)."""
        if not self.running or not self.cap or not self.cap.isOpened():
            return None, "---", 0

        ok, bgr = self.cap.read()
        if not ok:
            self.last_error = "Camera frame could not be read."
            return None, "---", 0

        # Mirror so it feels like looking in a mirror
        bgr = cv2.flip(bgr, 1)
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)

        gesture = "---"
        confidence = 0

        # ── Run MediaPipe Tasks landmarker ─────────────────────────────────
        if self.landmarker:
            try:
                mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
                result = self.landmarker.detect(mp_image)

                if result.hand_landmarks:
                    lm_list = result.hand_landmarks[0]   # first hand
                    gesture, confidence = self.gesture_model.predict(lm_list)

                    # Draw skeleton on the numpy array
                    self._draw_skeleton(rgb, lm_list)
            except Exception as e:
                self.last_error = f"Hand detection error: {e}"
                print(f"[VisionTracker] Detection error: {e}")

        # ── Convert to CTkImage for the UI ─────────────────────────────────
        pil_img = Image.fromarray(rgb)
        ctk_img = ctk.CTkImage(light_image=pil_img, dark_image=pil_img, size=(440, 310))

        return ctk_img, gesture, confidence

    # ── Skeleton Drawing ──────────────────────────────────────────────────────
    def _draw_skeleton(self, rgb_array: np.ndarray, landmarks):
        """Draw coloured dots and bone lines directly on the numpy array."""
        h, w, _ = rgb_array.shape

        # Pixel coordinates
        pts = [(int(lm.x * w), int(lm.y * h)) for lm in landmarks]

        # Connections
        for a, b in _HAND_CONNECTIONS:
            cv2.line(rgb_array, pts[a], pts[b], (170, 212, 0), 2)

        # Landmark dots
        for i, (px, py) in enumerate(pts):
            color = (255, 99, 108) if i in (4, 8, 12, 16, 20) else (255, 220, 80)
            cv2.circle(rgb_array, (px, py), 5, color, -1)

    # ── Cleanup ───────────────────────────────────────────────────────────────
    def release(self):
        self.stop()
        if self.landmarker:
            self.landmarker.close()
            self.landmarker = None

    @property
    def model_available(self):
        return self.landmarker is not None
