"""Hand overlays (common.py): a rebuild keeps NPCs, finds, signs and warps added to the JSON.
Run: python3 -m unittest tools/art/world/test_hand.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import apply_hand, diff_hand  # noqa: E402

GEN = {"name": "Town", "rows": ["..", ".."],
       "npcs": [{"id": "a", "x": 0, "y": 0}, {"id": "b", "x": 1, "y": 0}],
       "secrets": [{"x": 1, "y": 1, "item": "remedy", "flag": "f1"}]}


class HandTest(unittest.TestCase):
    def test_added_entries_survive_a_rebuild(self):
        com = dict(GEN, npcs=GEN["npcs"] + [{"id": "side", "x": 0, "y": 1}],
                   secrets=GEN["secrets"] + [{"x": 0, "y": 1, "item": "tonic", "flag": "f2"}])
        ov = diff_hand(GEN, com)
        self.assertEqual(ov["add"]["npcs"], [{"id": "side", "x": 0, "y": 1}])
        self.assertNotIn("set", ov)
        self.assertEqual(apply_hand(GEN, ov), com)

    def test_changed_and_removed_entries(self):
        com = dict(GEN, npcs=[{"id": "a", "x": 1, "y": 1}], rows=["._", ".."])
        ov = diff_hand(GEN, com)
        self.assertEqual(ov["replace"]["npcs"], [{"id": "a", "x": 1, "y": 1}])
        self.assertEqual(ov["drop"]["npcs"], ["id:b"])
        self.assertEqual(ov["set"]["rows"], ["._", ".."])
        self.assertEqual(apply_hand(GEN, ov), com)

    def test_generator_changes_still_come_through(self):
        ov = {"add": {"npcs": [{"id": "side", "x": 0, "y": 1}]}}
        gen = dict(GEN, npcs=[{"id": "a", "x": 1, "y": 1}])
        out = apply_hand(gen, ov)
        self.assertEqual(out["npcs"], [{"id": "a", "x": 1, "y": 1}, {"id": "side", "x": 0, "y": 1}])

    def test_no_difference_no_overlay(self):
        self.assertEqual(diff_hand(GEN, GEN), {})


if __name__ == "__main__":
    unittest.main()
