"""Tests for Tools/build/training.py: which of Wowhead's rows are kept, and what each kept rank needs.
Offline: the rows are made up here. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import training as tr  # noqa: E402

SKILL = [613]


def row(spell, name, rank, level, source=None, cost=None):
    out = {"id": spell, "name": name, "rank": rank, "level": level, "skill": SKILL}
    if source:
        out["source"] = source
    if cost:
        out["trainingcost"] = cost
    return out


class Entries(unittest.TestCase):
    def kept(self, rows, talents=None):
        return {e["spell"]: e for e in tr.entries(rows, talents or {})}

    def test_talent_rank_needs_only_the_talent(self):
        rows = [row(402284, "Penance", "Rank 1", 30), row(1240720, "Penance", "Rank 2", 40, [tr.TRAINER], 16000),
                row(1240721, "Penance", "Rank 3", 50, [tr.TRAINER], 30000)]
        kept = self.kept(rows, {"Penance": 402174})
        self.assertEqual(kept[1240720]["talent"], 402174)
        self.assertIsNone(kept[1240720]["needs"])
        self.assertEqual(kept[1240721]["needs"], 1240720)

    def test_rank_granted_at_level_one_is_still_needed(self):
        rows = [row(133, "Fireball", "Rank 1", 1), row(143, "Fireball", "Rank 2", 6, [tr.TRAINER], 100)]
        self.assertEqual(self.kept(rows)[143]["needs"], 133)

    def test_unsourced_lists(self):
        rows = [row(724, "Lightwell", "Rank 1", 40), row(355, "Taunt", "", 10), row(9999, "Other", "", 20)]
        kept = self.kept(rows)
        self.assertEqual((kept[724]["quest"], kept[724]["cost"]), (False, 0))
        self.assertTrue(kept[355]["quest"])
        self.assertNotIn(9999, kept)


if __name__ == "__main__":
    unittest.main()
