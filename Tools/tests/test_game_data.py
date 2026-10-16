"""Tests for the tools that read the game's own tables: Tools/sources/wago.py,
Tools/build/factions.py (the rewards added by hand on top) and Tools/build/same_maps.py.
Offline: wago.tools is never asked; its answers are made up here. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import factions  # noqa: E402
import same_maps  # noqa: E402
import wago  # noqa: E402


def reward(item_id, standing, **more):
    item = {"id": item_id, "standing": standing, "class": 4, "subclass": 2, "level": 60, "reqlevel": 55,
            "quality": 3, "price": 10000, "slot": 5}
    item.update(more)
    return item


class HandAddedRewards(unittest.TestCase):
    def test_standing_by_name(self):
        self.assertEqual(factions.standing("Revered", "here"), 7)
        self.assertEqual(factions.standing(" exalted ", "here"), 8)
        with self.assertRaises(SystemExit):
            factions.standing("Liked", "here")

    def test_price_in_coins(self):
        self.assertEqual(factions.copper("9g 1s 14c", "here"), 90114)
        self.assertEqual(factions.copper("50s", "here"), 5000)
        self.assertEqual(factions.copper(1234, "here"), 1234)
        with self.assertRaises(SystemExit):
            factions.copper("nine gold", "here")
        with self.assertRaises(SystemExit):
            factions.copper("9g and 5s", "here")

    def test_adds_an_item_the_tables_lack(self):
        notes = []
        faction = {"key": "Darkspear", "add": [{"item": 900001, "standing": "Honored", "price": "2g"}]}
        items = factions.by_hand(faction, [reward(1, 5)], {}, notes)
        added = items[-1]
        self.assertEqual((added["id"], added["standing"], added["price"]), (900001, 6, 20000))
        self.assertTrue(added["hand"])
        self.assertEqual(added["quality"], 1, "white until the client knows better")
        self.assertEqual(notes, [])

    def test_uses_what_the_tables_know_of_it(self):
        known = reward(900002, 0, quality=4, level=63)
        items = factions.by_hand({"key": "K", "add": [{"item": 900002, "standing": "Revered"}]},
                                       [], {900002: known}, [])
        self.assertEqual((items[0]["quality"], items[0]["level"], items[0]["standing"]), (4, 63, 7))
        self.assertEqual(known["standing"], 0, "the table's own facts are copied, not changed")

    def test_the_tables_win_once_they_have_it(self):
        notes = []
        faction = {"key": "K", "add": [{"item": 5, "standing": "Exalted"}]}
        items = factions.by_hand(faction, [reward(5, 7)], {}, notes)
        self.assertEqual([(i["id"], i["standing"]) for i in items], [(5, 7)])
        self.assertEqual(len(notes), 1)
        self.assertIn("can go", notes[0])
        self.assertIn("the game says 7, not 8", notes[0])

    def test_removes(self):
        items = factions.by_hand({"key": "K", "remove": [2]}, [reward(1, 5), reward(2, 5)], {}, [])
        self.assertEqual([i["id"] for i in items], [1])

    def test_a_bad_entry_says_where(self):
        with self.assertRaises(SystemExit) as raised:
            factions.by_hand({"key": "K", "add": [{"item": "272063", "standing": "Honored"}]}, [], {}, [])
        self.assertIn("K", str(raised.exception))

    def test_cloaks_are_for_everyone(self):
        self.assertEqual(factions.facts(reward(1, 5, subclass=1, slot=16)), (4, 0))
        self.assertEqual(factions.facts(reward(1, 5, subclass=5, slot=3)), (4, 0), "a cosmetic item too")
        self.assertEqual(factions.facts(reward(1, 5, subclass=1, slot=5)), (4, 1))
        self.assertEqual(factions.facts(reward(1, 5, **{"class": 9, "subclass": 2})), (4, 0))

    def test_turnins(self):
        faction = {"key": "AD", "turnins": [
            {"name": "Minion's Scourgestones", "quests": [5402, 5408], "rep": 25, "takes": [[12840, 20]],
             "level": 55, "at": {"5402": ["A", "Argent Officer Pureheart", "Western Plaguelands", 43, 83.6],
                                 "5408": ["H", "Lokhtos", "Blackrock Depths", None, None]},
             "from": [["Western Plaguelands", 20, ["Blighted Zombie"]]]}]}
        found = factions.turnins(faction, {12840: {}}, {"Western Plaguelands": [1422]})
        self.assertEqual([q["where"] for q in found[0]["quests"]],
                         ["Western Plaguelands - Argent Officer Pureheart (43, 83.6)", "Blackrock Depths - Lokhtos"])
        self.assertEqual([q["map"] for q in found[0]["quests"]], [1422, None], "no waypoint inside a dungeon")
        lines = factions.faction_file({"key": "AD", "id": 529, "tab": "reputation"}, "Argent Dawn", [],
                                            "1.60.1.1", found)
        self.assertIn('        { name = "Minion\'s Scourgestones", rep = 25, level = 55, takes = { 12840, 20 },',
                      lines)
        self.assertIn('                { 5402, "A", "Western Plaguelands - Argent Officer Pureheart (43, 83.6)", '
                      '1422, 43, 83.6 },', lines)
        self.assertIn('                { 5408, "H", "Blackrock Depths - Lokhtos" },', lines)
        self.assertIn('                { "Western Plaguelands", 20, "Blighted Zombie" },', lines)
        for bad in ({"quests": [5402], "rep": 25, "takes": [[12840, 20]]},
                    {"name": "x", "quests": ["5402"], "rep": 25, "takes": [[12840, 20]]},
                    {"name": "x", "quests": [5402], "rep": 0, "takes": [[12840, 20]]},
                    {"name": "x", "quests": [5402], "rep": 25, "takes": [12840, 20]},
                    {"name": "x", "quests": [5402], "rep": 25, "takes": [[777, 20]]}):
            with self.assertRaises(SystemExit, msg=bad):
                factions.turnins({"key": "AD", "turnins": [bad]}, {12840: {}})
        with self.assertRaises(SystemExit):
            factions.turnins({"key": "AD", "turnins": [{"name": "x", "quests": [1], "rep": 1,
                                    "takes": [[12840, 1]], "at": {"1": ["Both", "N", "Z", 1, 2]}}]}, {12840: {}})

    def test_places(self):
        tables = {"UiMap": [{"ID": "1451", "Name_lang": "Silithus", "Type": "3"},
                            {"ID": "2521", "Name_lang": "Zephras Isle", "Type": "3"},
                            {"ID": "2665", "Name_lang": "Zephras Isle", "Type": "3"},
                            {"ID": "1458", "Name_lang": "Undercity", "Type": "4"}],
                  "Map": [{"ID": "529", "MapName_lang": "Arathi Basin", "InstanceType": "3"},
                          {"ID": "189", "MapName_lang": "Scarlet Monastery", "InstanceType": "1"}]}
        real = wago.table
        wago.table = lambda name, build=None, hotfixes=True: tables[name]
        try:
            zones, battlegrounds = factions.places("b")
        finally:
            wago.table = real
        self.assertEqual(zones, {"Silithus": [1451], "Zephras Isle": [2521, 2665]}, "zones only")
        self.assertEqual(battlegrounds, {"Arathi Basin": 529}, "battlegrounds only")
        lines = factions.faction_file({"key": "D", "id": 510, "tab": "pvp", "zone": "Arathi Highlands"},
                                            "Defilers", [], "b", (), [1417], 529)
        self.assertIn("    maps = { 1417 },", lines)
        self.assertIn("    instance = 529,", lines)

    def test_the_hand_list_reads(self):
        config = json.loads(factions.FACTIONS.read_text(encoding="utf-8"))
        for faction in config["factions"]:
            for entry in faction.get("add", []):
                where = f"{faction['key']}, item {entry.get('item')}"
                self.assertIsInstance(entry.get("item"), int, where)
                factions.standing(entry.get("standing"), where)
                factions.copper(entry.get("price"), where)


class CarriedOver(unittest.TestCase):
    """Items a new build's tables lack, taken from the build before (its hotfixes)."""

    def setUp(self):
        self.table = wago.table
        sparse = "ID,MinFactionID,MinReputation,BuyPrice,OverallQualityID,ItemLevel,RequiredLevel,InventoryType"
        data = {
            ("ItemSparse", "new"): [sparse, "1,529,5,100,3,60,55,5", "2,529,6,200,3,60,55,5"],
            ("ItemSparse", "old"): [sparse, "1,529,4,999,3,60,55,5", "3,2798,5,300,3,63,58,16"],
            ("Item", "new"): ["ID,ClassID,SubclassID", "1,4,2", "2,4,2"],
            ("Item", "old"): ["ID,ClassID,SubclassID", "1,4,2", "3,4,1"],
        }
        import csv
        import io

        def table(name, build, hotfixes=True):
            return list(csv.DictReader(io.StringIO("\n".join(data[(name, build)]))))
        wago.table = table

    def tearDown(self):
        wago.table = self.table

    def test_fills_in_only_what_the_new_build_lacks(self):
        every, rewards, carried = factions.game_items("new", "old")
        self.assertEqual(carried, {3})
        self.assertEqual(rewards[2798][0]["id"], 3)
        self.assertEqual(every[3]["subclass"], 1, "with its Item row from the old build")
        self.assertEqual(every[1]["price"], 100, "the new build's own row wins")
        self.assertEqual(rewards[529][0]["standing"], 6)

    def test_nothing_carried_without_a_build_before(self):
        _, rewards, carried = factions.game_items("new")
        self.assertEqual(carried, set())
        self.assertNotIn(2798, rewards)


class SameMaps(unittest.TestCase):
    """Zone maps the game has under two IDs, as Zephras Isle's 2521 and 2665."""

    @staticmethod
    def ui_map(map_id, name, parent):
        return {"ID": str(map_id), "Name_lang": name, "Type": "3", "ParentUiMapID": str(parent)}

    @staticmethod
    def placed(map_id, continent, left, top=-1331.25, order="0"):
        return {"UiMapID": str(map_id), "MapID": str(continent), "OrderIndex": order, "Region_0": str(left),
                "Region_1": str(top), "Region_3": "4956.25", "Region_4": "4231.25"}

    def test_the_one_without_a_parent_reads_the_other(self):
        ui_maps = [self.ui_map(2521, "Zephras Isle", 947), self.ui_map(2665, "Zephras Isle", 0),
                   self.ui_map(1411, "Durotar", 1414)]
        assignments = [self.placed(2521, 2991, 1247.9169921875), self.placed(2665, 2991, 1247.9200439453),
                       self.placed(1411, 1, 1247.9169921875)]
        self.assertEqual(same_maps.same_maps(ui_maps, assignments), {2665: 2521})

    def test_not_the_same_place(self):
        ui_maps = [self.ui_map(1, "Isle", 947), self.ui_map(2, "Isle", 0), self.ui_map(3, "Other", 0)]
        self.assertEqual(same_maps.same_maps(ui_maps, [self.placed(1, 9, 0), self.placed(2, 9, 0, top=-2000)]),
                         {}, "other bounds")
        self.assertEqual(same_maps.same_maps(ui_maps, [self.placed(1, 9, 0), self.placed(2, 8, 0)]), {},
                         "another continent")
        self.assertEqual(same_maps.same_maps(ui_maps, [self.placed(1, 9, 0), self.placed(3, 9, 0)]), {},
                         "another name")
        self.assertEqual(same_maps.same_maps(ui_maps, [self.placed(1, 9, 0), self.placed(2, 9, 0, order="1")]),
                         {}, "only a map's first assignment places it")

    def test_which_one_reads_the_other_must_be_clear(self):
        ui_maps = [self.ui_map(1, "Isle", 0), self.ui_map(2, "Isle", 0)]
        with self.assertRaises(SystemExit):
            same_maps.same_maps(ui_maps, [self.placed(1, 9, 0), self.placed(2, 9, 0)])


class Builds(unittest.TestCase):
    def setUp(self):
        self.fetch = wago.fetch
        self.tables = dict(wago.tables)
        wago.tables.clear()

    def tearDown(self):
        wago.fetch = self.fetch
        wago.tables.clear()
        wago.tables.update(self.tables)

    def test_versions(self):
        self.assertTrue(wago.is_forever("1.60.1.70124"))
        self.assertTrue(wago.is_forever("1.61.0.1"))
        self.assertFalse(wago.is_forever("1.15.9.70003"))
        self.assertFalse(wago.is_forever("12.1.0.69933"))
        self.assertGreater(wago.version_key("1.60.1.70200"), wago.version_key("1.60.1.70124"))
        self.assertGreater(wago.version_key("1.60.10.1"), wago.version_key("1.60.9.99999"))

    def test_forever_builds_newest_first_once_each(self):
        wago.fetch = lambda url: json.dumps({
            "wow_classic_beta": [{"version": "1.60.1.70124", "created_at": "2026-09-30 01:57:04"},
                                 {"version": "1.60.1.70009", "created_at": "2026-09-20"}],
            "wow_cn_beta": [{"version": "1.60.1.70124", "created_at": "2026-09-29 00:00:00"}],
            "wow_classic_era": [{"version": "1.15.9.70003", "created_at": "2026-09-29"}],
        })
        builds = wago.forever_builds()
        self.assertEqual([b["version"] for b in builds], ["1.60.1.70124", "1.60.1.70009"])
        self.assertEqual(sorted(builds[0]["products"]), ["wow_classic_beta", "wow_cn_beta"])
        self.assertEqual(builds[0]["created_at"], "2026-09-29 00:00:00", "when wago first saw it")

    def test_a_table_wago_cannot_read_yet(self):
        def fetch(url):
            if "/Map/" in url:
                return "ID,Field_1_60_1_99999_000\n1,2\n"
            return "ID,Name_lang,MapID,ClassID,SubclassID,MapName_lang,InstanceType,MaxPlayers," \
                   "MinFactionID,MinReputation,BuyPrice,OverallQualityID,ItemLevel,RequiredLevel,InventoryType\n" \
                   + "1," * 14 + "1\n"
        wago.fetch = fetch
        self.assertEqual(wago.unreadable("1.60.1.99999"), ["Map"])


if __name__ == "__main__":
    unittest.main()
