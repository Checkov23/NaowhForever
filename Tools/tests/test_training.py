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
    def kept(self, rows, talents=None, learnable=None):
        learnable = {r["id"] for r in rows} if learnable is None else learnable
        return {e["spell"]: e for e in tr.entries(rows, talents or {}, learnable)}

    def test_a_spell_out_of_the_skill_lines_is_left_out(self):
        rows = [row(1326053, "Frost Blast", "Rank 1", 24, [tr.TRAINER], 4526),
                row(120, "Cone of Cold", "Rank 1", 26, [tr.TRAINER], 4700)]
        self.assertEqual(list(self.kept(rows, learnable={120})), [120])

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

    def test_a_talent_taken_out_of_the_tree_leaves_its_ranks_untrainable(self):
        rows = [row(1240770, "Binding Heal", "Rank 2", 32, [tr.TRAINER], 11000)]
        self.assertEqual(self.kept(rows), {})

    def test_unsourced_lists(self):
        rows = [row(724, "Lightwell", "Rank 1", 40), row(355, "Taunt", "", 10), row(9999, "Other", "", 20)]
        kept = self.kept(rows)
        self.assertEqual((kept[724]["quest"], kept[724]["cost"]), (False, 0))
        self.assertTrue(kept[355]["quest"])
        self.assertNotIn(9999, kept)


class CaughtUp(unittest.TestCase):
    # Lacerate after the 30 October 2026 hotfix: a talent first rank, a new second, and Wowhead's
    # "Rank 1" now the third.
    GAME = {
        1328617: {"name": "Lacerate", "rank": "Rank 1", "level": 25, "replaces": 0},
        1328616: {"name": "Lacerate", "rank": "Rank 2", "level": 34, "replaces": 1328617},
        414644: {"name": "Lacerate", "rank": "Rank 3", "level": 42, "replaces": 1328616},
        20927: {"name": "Holy Shield", "rank": "Rank 2", "level": 40, "replaces": 0},
        1239570: {"name": "Holy Shield", "rank": "Rank 4", "level": 0, "replaces": 20927},
    }
    TALENTS = {"Lacerate": 1328617}

    def kept(self, rows):
        rows = tr.caught_up(rows, self.TALENTS, self.GAME)
        return {e["spell"]: e for e in tr.entries(rows, self.TALENTS, {r["id"] for r in rows})}

    def test_rank_and_level_are_the_games(self):
        kept = self.kept([row(414644, "Lacerate", "Rank 1", 42, [tr.TRAINER], 12000),
                          row(20927, "Holy Shield", "Rank 2", 50, [tr.TRAINER], 1400)])
        self.assertEqual((kept[414644]["rank"], kept[414644]["cost"]), ("Rank 3", 12000))
        self.assertEqual((kept[20927]["level"], kept[20927]["cost"]), (40, 1400))

    def test_a_rank_wowhead_lacks_is_added_without_a_price(self):
        kept = self.kept([row(414644, "Lacerate", "Rank 1", 42, [tr.TRAINER], 12000)])
        self.assertEqual(sorted(kept), [414644, 1328616])
        added = kept[1328616]
        self.assertEqual((added["level"], added["cost"], added["talent"], added["needs"]), (34, 0, 1328617, None))
        self.assertEqual(kept[414644]["needs"], 1328616)

    def test_a_rank_the_game_gives_no_level_is_not_added(self):
        game = dict(self.GAME)
        game[20928] = {"name": "Holy Shield", "rank": "Rank 3", "level": 50, "replaces": 1239570}
        rows = tr.caught_up([row(20928, "Holy Shield", "Rank 3", 60, [tr.TRAINER], 2300)], {}, game)
        self.assertEqual([r["id"] for r in rows], [20928])


if __name__ == "__main__":
    unittest.main()
