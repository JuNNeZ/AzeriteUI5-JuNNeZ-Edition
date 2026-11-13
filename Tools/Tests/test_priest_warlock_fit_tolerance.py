"""The scoped tolerance measures distance, not failed-pixel counts."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PriestWarlockFitTolerance import edge_distance, component_span


class FitTolerance(unittest.TestCase):
    def setUp(self):
        self.reference = np.zeros((50, 50), dtype=bool)
        self.reference[20, 20] = True

    def query(self, y, x):
        query = np.zeros_like(self.reference)
        query[y, x] = True
        return query

    def test_exactly_ten_pixels_is_accepted(self):
        self.assertEqual(edge_distance(self.reference, self.query(20, 30)), 10)

    def test_one_pixel_outside_limit_is_rejected(self):
        with self.assertRaises(AssertionError):
            edge_distance(self.reference, self.query(20, 31))

    def test_diagonal_uses_euclidean_distance(self):
        with self.assertRaisesRegex(AssertionError, "exceeds 10px"):
            edge_distance(self.reference, self.query(28, 28))

    def test_many_nearby_pixels_do_not_become_a_count_limit(self):
        query = np.zeros_like(self.reference)
        query[19:22, 19:22] = True
        self.assertAlmostEqual(edge_distance(self.reference, query), 2**.5)

    def test_isolated_alpha_rounding_components_are_measured_separately(self):
        query = self.query(4, 4)
        query[30:32, 30] = True
        self.assertEqual(component_span(query), 2)


if __name__ == "__main__":
    unittest.main()
