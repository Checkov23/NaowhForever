"""Tests for Tools/sources/wowsrc.py's daily check: what wowsrc's pages say now that wowsrc_loot.json
(what the Journal was built from) does not. Offline, made-up pages. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import wowsrc  # noqa: E402


def item(name, new=False, chance=None):
    return {"name": name, "new": new, "chance": chance, "quality": "rare", "level": 21, "slot": "trinket", "type": None}


OLD = {"shadowfang-keep": {"name": "Shadowfang Keep", "updated": None, "bosses": [
    {"name": "Commander Springvale", "items": [item("Arced War Axe", chance=35.7), item("Eerie Stable Lantern")]},
    {"name": "Trash", "items": [item("Shadowfang")]},
]}}


class Check(unittest.TestCase):
    def setUp(self):
        self.names = wowsrc.item_names
        wowsrc.item_names = lambda: {"arced war axe": 3191, "worgenbane talisman": 273643}

    def tearDown(self):
        wowsrc.item_names = self.names

    def test_nothing_new(self):
        self.assertEqual(wowsrc.changes(OLD, copy.deepcopy(OLD)), [])

    def test_a_chance_moving_is_not_a_change(self):
        new = copy.deepcopy(OLD)
        new["shadowfang-keep"]["bosses"][0]["items"][0]["chance"] = 36.1
        self.assertEqual(wowsrc.changes(OLD, new), [])

    def test_an_item_moved_and_one_added(self):
        new = copy.deepcopy(OLD)
        springvale = new["shadowfang-keep"]["bosses"][0]["items"]
        springvale.remove(springvale[1])
        springvale.append(item("Worgenbane Talisman", new=True))
        text = "\n".join(wowsrc.changes(OLD, new))
        self.assertIn("Shadowfang Keep / Commander Springvale: Worgenbane Talisman (ID 273643, new in Forever)", text)
        self.assertIn("Items a boss lost", text)
        self.assertIn("Commander Springvale: Eerie Stable Lantern", text)

    def test_an_unmapped_name_says_so(self):
        new = copy.deepcopy(OLD)
        new["shadowfang-keep"]["bosses"][1]["items"].append(item("Gloomshroud Armor"))
        self.assertIn("Trash: Gloomshroud Armor (name not mapped yet)", "\n".join(wowsrc.changes(OLD, new)))

    def test_the_game_names_an_id(self):
        new = copy.deepcopy(OLD)
        new["shadowfang-keep"]["bosses"][1]["items"].append(item("Gloomshroud Armor"))
        text = "\n".join(wowsrc.changes(OLD, new, {"gloomshroud armor": 1489}))
        self.assertIn("Trash: Gloomshroud Armor (ID 1489)", text)

    def test_new_boss_and_page(self):
        new = copy.deepcopy(OLD)
        new["shadowfang-keep"]["bosses"].append({"name": "Sever", "items": [item("The Axe of Severing")]})
        new["ruins"] = {"name": "Ruins of Lordaeron", "updated": None, "bosses": []}
        text = "\n".join(wowsrc.changes(OLD, new))
        self.assertIn("Shadowfang Keep / Sever: The Axe of Severing", text)
        self.assertIn("- Ruins of Lordaeron", text)


class Links(unittest.TestCase):
    """Every wowsrc loot page we read is one a dungeon in journal_bosses.json names ("wowsrc"):
    an unlinked page is read every day and built into nothing (City of Dalaran's, Excavation
    Site's, until 11 Oct 2026)."""

    def test_every_page_is_linked_to_a_dungeon(self):
        pages = json.loads((paths.DATA / "wowsrc_loot.json").read_text(encoding="utf-8"))
        dungeons = json.loads((paths.DATA / "journal_bosses.json").read_text(encoding="utf-8"))["dungeons"]
        linked = set()
        for dungeon in dungeons:
            slugs = dungeon.get("wowsrc") or {}
            linked.update([slugs] if isinstance(slugs, str) else slugs.values())
        self.assertEqual(sorted(set(pages) - linked), [],
                         'add "wowsrc": "<slug>" to the dungeon in Tools/data/journal_bosses.json')
        self.assertEqual(sorted(linked - set(pages)), [], "a linked page wowsrc_loot.json does not have")


if __name__ == "__main__":
    unittest.main()
