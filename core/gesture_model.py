"""Geometry-based classifier for the static signs supported by this project.

This deliberately is not presented as a trained ASL model. It recognises a
small, documented set of static hand poses from MediaPipe landmarks; movement
signs such as ``Please`` and ``Thank You`` remain available as reference cards.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Iterable, Sequence


DICT_PATH = Path(__file__).resolve().parent.parent / "data" / "sign_dictionary.json"

DEFAULT = {
    "A": "Closed fist, thumb on side",
    "B": "Four fingers up, thumb folded",
    "C": "Curved fingers like letter C",
    "D": "Index up, others form circle",
    "E": "Fingers bent down, thumb tucked",
    "Hello": "Open hand, wave outward",
    "Thank You": "Fingers touch chin, move forward",
    "Yes": "Fist nods up and down",
    "No": "Index and middle fingers close to thumb",
    "Please": "Flat hand circles on chest",
    "Sorry": "Fist circles over chest",
    "I Love You": "Thumb, index, pinky extended",
}

# Only these poses can be judged from one still hand-landmark frame. Keeping
# this separate from the reference dictionary prevents impossible tutor rounds.
STATIC_SIGNS = ("A", "B", "C", "D", "E", "Hello", "I Love You")


def load_dictionary() -> dict[str, str]:
    """Return the local sign reference dictionary, with a safe built-in fallback."""
    try:
        with DICT_PATH.open("r", encoding="utf-8") as file:
            loaded = json.load(file)
        return loaded if isinstance(loaded, dict) else DEFAULT.copy()
    except (OSError, json.JSONDecodeError):
        return DEFAULT.copy()


def _point(landmark: object) -> tuple[float, float, float]:
    """Accept MediaPipe landmark objects as well as simple 2/3-value sequences."""
    if hasattr(landmark, "x") and hasattr(landmark, "y"):
        return (
            float(landmark.x),
            float(landmark.y),
            float(getattr(landmark, "z", 0.0)),
        )
    values = tuple(landmark)  # type: ignore[arg-type]
    return float(values[0]), float(values[1]), float(values[2] if len(values) > 2 else 0.0)


def normalise_landmarks(landmarks: Sequence[object]) -> list[tuple[float, float, float]]:
    """Centre landmarks at the wrist and scale them by palm length.

    The resulting coordinates are stable when the hand moves nearer to or
    farther from the camera, which makes the classifier's distance thresholds
    independent of the frame size.
    """
    points = [_point(landmark) for landmark in landmarks]
    if len(points) < 21:
        return []

    wrist = points[0]
    palm_length = math.dist(points[0], points[9])
    if palm_length < 1e-6:
        return []
    return [
        ((x - wrist[0]) / palm_length, (y - wrist[1]) / palm_length, (z - wrist[2]) / palm_length)
        for x, y, z in points
    ]


def _distance(points: Sequence[tuple[float, float, float]], first: int, second: int) -> float:
    return math.dist(points[first], points[second])


def _angle(points: Sequence[tuple[float, float, float]], first: int, vertex: int, third: int) -> float:
    """Return the angle at ``vertex`` in degrees (0-180)."""
    a = tuple(points[first][axis] - points[vertex][axis] for axis in range(3))
    b = tuple(points[third][axis] - points[vertex][axis] for axis in range(3))
    a_size = math.sqrt(sum(value * value for value in a))
    b_size = math.sqrt(sum(value * value for value in b))
    if a_size < 1e-6 or b_size < 1e-6:
        return 0.0
    cosine = max(-1.0, min(1.0, sum(x * y for x, y in zip(a, b)) / (a_size * b_size)))
    return math.degrees(math.acos(cosine))


def _finger_extension(points: Sequence[tuple[float, float, float]], mcp: int, pip: int, dip: int, tip: int) -> tuple[bool, float]:
    """Classify a finger from its joint angles and return an extension margin."""
    straightness = min(_angle(points, mcp, pip, dip), _angle(points, pip, dip, tip))
    reach = _distance(points, 0, tip) - _distance(points, 0, pip)
    margin = min((straightness - 145.0) / 35.0, reach / 0.35)
    return straightness >= 145.0 and reach > 0.03, margin


class GestureModel:
    """Recognise a limited set of static signs with a transparent score."""

    supported_signs = STATIC_SIGNS

    def __init__(self) -> None:
        self.dictionary = load_dictionary()

    def predict(self, landmarks: Sequence[object] | Iterable[object]) -> tuple[str, int]:
        """Return ``(sign, confidence)`` for 21 MediaPipe landmarks.

        Confidence is a geometry fit score for the rule, not a probability and
        should be treated as a visual cue rather than a clinical-quality result.
        """
        points = normalise_landmarks(list(landmarks))
        if len(points) < 21:
            return "---", 0

        thumb_angle = min(_angle(points, 1, 2, 3), _angle(points, 2, 3, 4))
        thumb_reach = _distance(points, 0, 4) - _distance(points, 0, 2)
        thumb_open = thumb_angle >= 135.0 and thumb_reach > 0.02
        thumb_margin = min((thumb_angle - 135.0) / 45.0, thumb_reach / 0.35)

        index_open, index_margin = _finger_extension(points, 5, 6, 7, 8)
        middle_open, middle_margin = _finger_extension(points, 9, 10, 11, 12)
        ring_open, ring_margin = _finger_extension(points, 13, 14, 15, 16)
        pinky_open, pinky_margin = _finger_extension(points, 17, 18, 19, 20)
        fingers = (thumb_open, index_open, middle_open, ring_open, pinky_open)
        margins = (thumb_margin, index_margin, middle_margin, ring_margin, pinky_margin)

        # E must be checked before the generic closed-fist A rule. Its folded
        # fingertips sit unusually close to their MCP joints.
        fingertip_fold = sum(
            _distance(points, tip, mcp)
            for tip, mcp in ((8, 5), (12, 9), (16, 13), (20, 17))
        ) / 4
        if not any(fingers[1:]) and fingertip_fold < 0.8 and not thumb_open:
            return "E", max(60, min(84, round(84 - fingertip_fold * 20)))

        thumb_to_index = _distance(points, 4, 8)
        other_fingers_curled = not middle_open and not ring_open and not pinky_open
        if thumb_open and index_open and other_fingers_curled and 0.65 <= thumb_to_index <= 1.75:
            closeness = 1.0 - abs(thumb_to_index - 1.15) / 0.6
            return "C", max(60, min(88, round(74 + closeness * 14)))

        def rule_confidence(target: tuple[bool, bool, bool, bool, bool], base: int) -> int:
            # A larger positive margin helps an open target; a negative margin
            # helps a closed target. The score stays modest near a boundary.
            fit = [margin if expected else -margin for expected, margin in zip(target, margins)]
            average_fit = sum(max(-1.0, min(1.0, value)) for value in fit) / len(fit)
            return max(55, min(99, round(base + average_fit * 12)))

        rules = (
            ((True, True, False, False, True), "I Love You", 88),
            ((False, True, True, True, True), "B", 84),
            ((False, True, False, False, False), "D", 82),
            ((True, True, False, False, False), "D", 79),
            ((True, True, True, True, True), "Hello", 86),
            ((False, False, False, False, False), "A", 78),
            ((True, False, False, False, False), "A", 76),
        )
        for pattern, sign, base in rules:
            if fingers == pattern:
                return sign, rule_confidence(pattern, base)

        return "---", 0
