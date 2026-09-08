"""Fast, camera-free tests for gesture geometry helpers."""
import unittest

from core.gesture_model import GestureModel, normalise_landmarks


class GestureModelTests(unittest.TestCase):
    def test_normalisation_ignores_translation_and_scale(self):
        points = [(index * 0.01, index * 0.02, 0.0) for index in range(21)]
        points[0] = (0.0, 0.0, 0.0)
        points[9] = (0.0, 1.0, 0.0)
        scaled_and_shifted = [(x * 3 + 7, y * 3 - 2, z * 3 + 4) for x, y, z in points]
        original = normalise_landmarks(points)
        transformed = normalise_landmarks(scaled_and_shifted)
        for expected, actual in zip(original, transformed):
            for expected_value, actual_value in zip(expected, actual):
                self.assertAlmostEqual(expected_value, actual_value)

    def test_rejects_incomplete_hand_data(self):
        self.assertEqual(GestureModel().predict([(0.0, 0.0)] * 20), ("---", 0))

    def test_tutor_signs_are_static_signs(self):
        self.assertEqual(GestureModel.supported_signs, ("A", "B", "C", "D", "E", "Hello", "I Love You"))


if __name__ == "__main__":
    unittest.main()
