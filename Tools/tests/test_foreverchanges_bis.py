"""Tests for ForeverChanges' BiS picks: Tools/build/foreverchanges_bis.py's reading of a list page
(slots, a ring for both ring slots, enchants left out) and of where each pick comes from, and
Tools/build/bis_data.py adding the picks after wowsrc's, keeping them in its daily check and
taking their source when Wowhead has none. Offline, made-up data. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import bis_data  # noqa: E402
import foreverchanges_bis as fc  # noqa: E402


def row(item, first):
    return (f'<li class="bis-row"><div class="bis-name-cell"><a class="bis-name q2" href="/item/{item}/x">X</a></div>'
            f'<div class="bis-from"><p>{first}<span>more</span></p></div></li>')


def section(heading, *rows):
    return f'<section class="bis-slot"><h3>{heading}</h3><ol>{"".join(rows)}</ol></section>'


PAGE = (section("Head", row(7413, "<b>World drop, sold at the auction house</b>"),
                row(9428, "<b>Trash mobs, Uldaman</b>"))
        + section("Finger", row(274746, "<b>Sold by Gezzy Gunkgear in Booty Bay</b>"))
        + section("Enchants", row(1, "<b>Enchanting</b>")))


class Parse(unittest.TestCase):
    def test_slots_in_rank_order_a_ring_in_both(self):
        slots, sources = fc.parse(PAGE)
        self.assertEqual(slots, {1: [7413, 9428], 11: [274746], 12: [274746]})
        self.assertEqual(sources, {"7413": "World drop", "9428": "Trash drop \u00b7 Uldaman",
                                   "274746": "Gezzy Gunkgear \u00b7 Booty Bay"})

    def test_a_slot_not_known_stops_it(self):
        with self.assertRaises(ValueError):
            fc.parse(section("Shirt", row(1, "<b>x</b>")))


class Source(unittest.TestCase):
    def check(self, first, expected):
        self.assertEqual(fc.source(row(1, first)), expected)

    def test_each_kind(self):
        self.check('<a href="/quest/5561/kodo-roundup">Quest: Kodo Roundup</a>', "Kodo Roundup \u00b7 Quest")
        self.check('<a href="/professions/blacksmithing#r-1">Blacksmithing (95)</a>', "Blacksmithing \u00b7 Crafted")
        self.check("<b>Overlord Ramtusk, Razorfen Kraul</b>", "Overlord Ramtusk \u00b7 Razorfen Kraul")
        self.check("<b>Heartrazor, the rare wyvern of Thousand Needles</b>", "Heartrazor \u00b7 Thousand Needles")
        self.check("<b>Brontus, a rare kodo of the Barrens</b>", "Brontus \u00b7 the Barrens")
        self.check("<b>Shaman quest The Tempest's Weapons, from level 30</b>", "The Tempest's Weapons \u00b7 Quest")

    def test_none_where_it_names_none(self):
        self.check("<b></b>", None)
        self.check("<b>Paladin quest chain</b>", None)
        self.check("<b>The Blade of Silverlaine, imbued with the Scroll of the Saber</b>", None)
        self.check("<b>A quest of the Excavation Site, in the Wetlands</b>", None)


class WithListed(unittest.TestCase):
    def test_after_wowsrc_each_item_once(self):
        slots = bis_data.with_listed({1: [10, 20], 2: [30]}, {"1": [20, 40], "15": [50]})
        self.assertEqual((slots[1], slots[2], slots[15], slots[3]), ([10, 20, 40], [30], [50], []))

    def test_a_listed_pick_is_not_taken_off_by_wowsrc(self):
        cache = {bis_data.item_key({"name": "Mantle", "quality": 3, "ilvl": 21, "icon": "x"}): 10}
        theirs = {"arcane-mage": ("Arcane Mage", {3: [{"name": "Mantle", "quality": 3, "ilvl": 21, "icon": "x"}]})}
        ours = {"arcane-mage": {3: [10, 40]}}
        self.assertIn("taken off 40", "\n".join(bis_data.bis_changes(ours, theirs, cache)))
        self.assertEqual(bis_data.bis_changes(ours, theirs, cache, picks={"arcane-mage": {"3": [40]}}), [])


class FillSources(unittest.TestCase):
    def test_theirs_when_wowhead_has_none(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            (folder / "bis_sources.json").write_text(json.dumps({"item=1": "Boss \u00b7 Place", "item=2": None}))
            (folder / "listed.json").write_text(json.dumps({"specs": {}, "sources": {"1": "theirs", "2": "theirs 2",
                                                                                     "3": "theirs 3"}}))
            sources = {}
            with mock.patch.object(bis_data, "SOURCES", folder / "bis_sources.json"), \
                    mock.patch.object(bis_data, "LISTED", folder / "listed.json"), \
                    mock.patch.object(bis_data, "OFFLINE", True):
                missing = bis_data.fill_sources(sources, {1, 2, 3, 4})
        self.assertEqual(sources, {1: "Boss \u00b7 Place", 2: "theirs 2", 3: "theirs 3"})
        self.assertEqual(missing, [4])


if __name__ == "__main__":
    unittest.main()
