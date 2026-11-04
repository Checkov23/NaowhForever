"""Tests for Tools/build/training.py: which of Wowhead's rows are kept, and what each kept rank needs.
Offline: the rows are made up here. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import training as tr  # noqa: E402
import wago  # noqa: E402

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


class GameSpells(unittest.TestCase):
    # Shank as the game's tables have it: no BaseLevel, its level in SpellLevel, no rank text.
    TABLES = {
        "SpellLevels": [{"SpellID": "1329283", "BaseLevel": "0", "SpellLevel": "24"},
                        {"SpellID": "1329549", "BaseLevel": "0", "SpellLevel": "44"},
                        {"SpellID": "11551", "BaseLevel": "52", "SpellLevel": "50"}],
        "SkillLineAbility": [{"Spell": "1329283", "SupercedesSpell": "0", "SkillLine": "38"},
                             {"Spell": "1329549", "SupercedesSpell": "1329283", "SkillLine": "38"},
                             {"Spell": "11551", "SupercedesSpell": "0", "SkillLine": "256"}],
        "Spell": [{"ID": "1329283", "NameSubtext_lang": ""}, {"ID": "1329549", "NameSubtext_lang": ""},
                  {"ID": "11551", "NameSubtext_lang": "Rank 6"}],
        "SpellName": [{"ID": "1329283", "Name_lang": "Shank"}, {"ID": "1329549", "Name_lang": "Shank"},
                      {"ID": "11551", "Name_lang": "Battle Shout"}],
    }

    def test_a_spell_without_a_base_level_has_its_spell_level(self):
        saved = wago.table
        wago.table = lambda name, build=None: self.TABLES[name]
        try:
            game = tr.game_spells("test")
        finally:
            wago.table = saved
        self.assertEqual((game[1329283]["level"], game[1329549]["level"], game[11551]["level"]), (24, 44, 52))
        self.assertEqual((game[1329283]["after"], game[1329549]["replaces"]), ([1329549], 1329283))
        self.assertEqual(game[1329283]["skill"], 38)


class LaterRanks(unittest.TestCase):
    # Death Mark: a talent whose later ranks Wowhead's list lacks. Shank: a new spell with no rank text.
    # Battle Shout's seventh rank and Swipe (Cat): ranks Wowhead lists that no trainer sells.
    GAME = {
        1316709: {"name": "Death Mark", "rank": "Rank 1", "level": 40, "after": [1325756], "skill": 39},
        1325756: {"name": "Death Mark", "rank": "Rank 2", "level": 48, "after": [1325757, 1325759], "skill": 39},
        1325757: {"name": "Death Mark", "rank": "Rank 3", "level": 56, "after": [], "skill": 39},
        1325759: {"name": "Death Mark", "rank": "Rank 3", "level": 0, "after": [], "skill": 39},
        1329283: {"name": "Shank", "rank": "", "level": 24, "after": [1329549], "skill": 38},
        1329549: {"name": "Shank", "rank": "", "level": 44, "after": [], "skill": 38},
        11551: {"name": "Battle Shout", "rank": "Rank 6", "level": 52, "after": [25289], "skill": 256},
        25289: {"name": "Battle Shout", "rank": "Rank 7", "level": 60, "after": [], "skill": 256},
        9754: {"name": "Swipe", "rank": "Rank 4", "level": 44, "after": [9908, 411128], "skill": 134},
        9908: {"name": "Swipe", "rank": "Rank 5", "level": 54, "after": [], "skill": 134},
        411128: {"name": "Swipe", "rank": "Cat", "level": 1, "after": [], "skill": 134},
    }
    TALENTS = {"Death Mark": 1316709}

    def kept(self, rows):
        return {e["spell"]: e for e in tr.entries(rows, self.TALENTS, set(self.GAME))}

    def test_a_talents_later_ranks_are_added_and_need_only_the_talent(self):
        rows = tr.later_ranks([], {1316709}, self.GAME)
        self.assertEqual([r["id"] for r in rows], [1325756, 1325757])
        kept = self.kept(rows)
        self.assertEqual((kept[1325756]["level"], kept[1325756]["cost"], kept[1325756]["talent"],
                          kept[1325756]["needs"]), (48, 0, 1316709, None))
        self.assertEqual(kept[1325757]["needs"], 1325756)

    def test_a_rank_without_rank_text_needs_the_rank_it_replaces(self):
        rows = [tr.game_row(1329283, self.GAME)]
        rows += tr.later_ranks(rows, set(self.kept(rows)), self.GAME)
        kept = self.kept(rows)
        self.assertEqual((kept[1329283]["level"], kept[1329283]["cost"], kept[1329283]["needs"]), (24, 0, None))
        self.assertEqual((kept[1329549]["level"], kept[1329549]["needs"]), (44, 1329283))

    def test_a_book_rank_is_not_added_but_names_the_rank_it_replaces(self):
        rows = [row(11551, "Battle Shout", "Rank 6", 52, [tr.TRAINER], 54000),
                row(25289, "Battle Shout", "Rank 7", 60, [2])]
        self.assertEqual(tr.later_ranks(rows, {11551}, self.GAME), [])
        spells = tr.entries(rows, {}, {11551, 25289})
        self.assertEqual([e["spell"] for e in spells], [11551])
        self.assertEqual(tr.replaced_by(spells, rows, self.GAME), {11551: 25289})

    def test_no_book_link_to_a_rank_a_hotfix_took_away(self):
        rows = [row(11551, "Battle Shout", "Rank 6", 52, [tr.TRAINER], 54000),
                row(25289, "Battle Shout", "Rank 7", 60, [2])]
        spells = tr.entries(rows, {}, {11551, 25289})
        with mock.patch.object(tr, "UNTRAINABLE", tr.UNTRAINABLE | {25289}):
            self.assertEqual(tr.replaced_by(spells, rows, self.GAME), {})

    def test_no_book_link_when_a_trainer_rank_follows(self):
        rows = [row(9754, "Swipe", "Rank 4", 44, [tr.TRAINER], 18000),
                row(9908, "Swipe", "Rank 5", 54, [tr.TRAINER], 28000), row(411128, "Swipe", "Cat", 1)]
        spells = tr.entries(rows, {}, {9754, 9908, 411128})
        self.assertEqual(tr.replaced_by(spells, rows, self.GAME), {})


if __name__ == "__main__":
    unittest.main()
