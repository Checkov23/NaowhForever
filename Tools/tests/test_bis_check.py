"""Tests for the daily checks' reports: Tools/build/bis_data.py's BiS changes, and the short
list a pull request shows (Tools/sources/wowsrc.py). Offline, made-up data. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import os
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import bis_data  # noqa: E402
import wowsrc  # noqa: E402


def item(name, quality=3, ilvl=21, icon="inv_x"):
    return {"name": name, "quality": quality, "ilvl": ilvl, "icon": icon, "source": ""}


MANTLE, NEW = item("Magician's Mantle"), item("Fairywing Mantle")
CACHE = {bis_data.item_key(MANTLE): 4000}
OURS = {"arcane-mage": {3: [4000]}}


class BisChanges(unittest.TestCase):
    def test_a_new_top_pick(self):
        theirs = {"arcane-mage": ("Arcane Mage", {3: [NEW, MANTLE]})}
        lines = bis_data.bis_changes(OURS, theirs, CACHE, lambda i: CACHE.get(bis_data.item_key(i)) or 5000)
        text = "\n".join(lines)
        self.assertIn("top pick is now Fairywing Mantle (was Magician's Mantle)", text)
        self.assertIn("added Fairywing Mantle.", text, "found in the game's tables: no mark")
        self.assertIsNone(re.search(r"#\d", text), "GitHub would link #1 to pull request 1")

    def test_one_the_tables_do_not_have(self):
        theirs = {"arcane-mage": ("Arcane Mage", {3: [MANTLE, NEW]})}
        text = "\n".join(bis_data.bis_changes(OURS, theirs, CACHE))
        self.assertIn("added Fairywing Mantle (not in the game's tables yet)", text)


class Updated(unittest.TestCase):
    def test_the_page_date_as_the_addon_shows_it(self):
        page = '<p class="updated">\nLast updated <time datetime="2026-09-30">30 September 2026</time>'
        self.assertEqual(bis_data.updated_on(page), "30 Sep 2026")
        self.assertIsNone(bis_data.updated_on("<p>no date</p>"))

    def test_the_data_still_reads_with_dates(self):
        text = bis_data.OUT.read_text(encoding="utf-8")
        self.assertIn("updated = ", text, "the data carries each spec page's date")
        self.assertGreater(len(bis_data.current_specs()), 20)


class ShortList(unittest.TestCase):
    RUN = {"GITHUB_SERVER_URL": "https://github.com", "GITHUB_REPOSITORY": "o/r", "GITHUB_RUN_ID": "7"}

    def setUp(self):
        self.saved = {k: os.environ.get(k) for k in self.RUN}

    def tearDown(self):
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def test_in_ci_a_long_list_links_the_run(self):
        os.environ.update(self.RUN)
        found = [f"- change {i}" for i in range(40)]
        short = wowsrc.shortened(found)
        self.assertEqual(short[:wowsrc.SHORT], found[:wowsrc.SHORT])
        self.assertIn("... and 15 more: [the whole list](https://github.com/o/r/actions/runs/7)", short[-1])

    def test_short_or_outside_ci_it_stays_whole(self):
        for k in self.RUN:
            os.environ.pop(k, None)
        found = [f"- change {i}" for i in range(40)]
        self.assertEqual(wowsrc.shortened(found), found, "no run to link: all of it")
        os.environ.update(self.RUN)
        self.assertEqual(wowsrc.shortened(found[:5]), found[:5])


class Lookup(unittest.TestCase):
    """An item's ID from its name: of its quality first; wowsrc shows some greens as blue, and
    then the one item of another quality with that name, icon and item level is it."""

    def setUp(self):
        self.saved = (bis_data.game_rows, bis_data.fetch, bis_data.time.sleep, bis_data.OFFLINE)
        bis_data.time.sleep = lambda _: None

    def tearDown(self):
        bis_data.game_rows, bis_data.fetch, bis_data.time.sleep, bis_data.OFFLINE = self.saved

    @staticmethod
    def rows(*found):
        return {"energized stone circle": [{"ID": str(i), "OverallQualityID": str(q), "ItemLevel": str(lvl)}
                                           for i, q, lvl in found]}

    def test_offline_the_game_table_settles_a_green_shown_as_blue(self):
        bis_data.game_rows = self.rows((9522, 2, 38))
        self.assertEqual(bis_data.game_lookup(item("Energized Stone Circle", quality=3, ilvl=38)), [9522])

    def test_offline_its_own_quality_wins(self):
        bis_data.game_rows = self.rows((9522, 2, 38), (99999, 3, 38))
        self.assertEqual(bis_data.game_lookup(item("Energized Stone Circle", quality=3, ilvl=38)), [99999])

    def test_offline_two_of_another_quality_stay_unsettled(self):
        bis_data.game_rows = self.rows((9522, 2, 38), (99998, 4, 38))
        self.assertEqual(bis_data.game_lookup(item("Energized Stone Circle", quality=3, ilvl=38)), [])

    def test_offline_another_item_level_is_not_it(self):
        bis_data.game_rows = self.rows((9522, 2, 36))
        self.assertEqual(bis_data.game_lookup(item("Energized Stone Circle", quality=3, ilvl=38)), [])

    def test_wowhead_settles_a_green_shown_as_blue(self):
        bis_data.OFFLINE = False
        found = {"results": [{"type": 3, "id": 9522, "name": "Energized Stone Circle", "quality": 2,
                              "icon": "inv_shield_10", "pinDescription": "This green shield of item level 38 goes"}]}
        bis_data.fetch = lambda url: json.dumps(found)
        wanted = item("Energized Stone Circle", quality=3, ilvl=38, icon="inv_shield_10")
        self.assertEqual(bis_data.lookup(wanted), [9522])
        self.assertEqual(bis_data.lookup(dict(wanted, icon="inv_shield_11")), [], "another icon is another item")


if __name__ == "__main__":
    unittest.main()
