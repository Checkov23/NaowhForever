"""Tests for Tools/build/journal.py's choice of a boss's loot. Wowhead counts Classic Era's and
Forever's kills together, so an item new in Forever is kept whatever its chance looks like,
and the rest above MIN_CHANCE. Offline: the drop rows are made up here, in the shape
npc_drops caches. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import re
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import journal  # noqa: E402
import items_in_game  # noqa: E402
import wago  # noqa: E402


def drop(item_id, count, kills, new=False, quality=3):
    return {"id": item_id, "count": count, "kills": kills, "new": new, "slot": 13, "class": 2,
            "subclass": 1, "level": 26, "reqlevel": 21, "quality": quality}


# Oggleflint's numbers, as Wowhead had them: 4227 Normal kills, Classic Era and Forever's.
SWORD = drop(1, 400, 4227)
SCEPTER = drop(272996, 6, 4227, new=True)   # new in Forever: 0.14% of the shared kills
RARE = drop(2, 6, 4227)                     # an old item that rare: left out
STRAY = drop(252455, 1, 5001, new=True)     # a new item seen once: a stray world drop


class Drops(unittest.TestCase):
    def test_a_new_item_is_kept_whatever_its_chance(self):
        kept = journal.choose([SCEPTER, RARE])
        self.assertEqual([i["id"] for i in kept], [272996])
        self.assertIsNone(kept[0]["chance"], "its chance is counted against Classic Era's kills too")

    def test_a_new_item_seen_once_is_not_enough(self):
        self.assertEqual(journal.choose([STRAY]), [])
        once = journal.choose([drop(273025, 1, 1, new=True)])
        self.assertEqual([i["id"] for i in once], [273025], "a new boss's single kill: its one drop")

    def test_a_boss_new_in_forever_has_real_chances(self):
        kept = journal.choose([drop(271201, 10, 30, new=True)], npc_new=True)
        self.assertAlmostEqual(kept[0]["chance"], 100 * 10 / 30, msg="Witherfang: all its kills are Forever's")

    def test_too_few_kills_for_a_chance(self):
        kept = journal.choose([drop(6641, 1, 1)], npc_new=True)
        self.assertEqual([i["id"] for i in kept], [6641])
        self.assertIsNone(kept[0]["chance"], "one kill makes every drop 100%")

    def test_chances_and_order(self):
        kept = journal.choose([SCEPTER, SWORD])
        self.assertEqual([i["id"] for i in kept], [1, 272996], "most likely first, unknown last")
        self.assertAlmostEqual(kept[0]["chance"], 100 * 400 / 4227)

    def test_no_kills_counted_yet(self):
        kept = journal.choose([drop(5, 0, 0)])
        self.assertEqual(kept[0]["chance"], None, "a new boss's drop: kept, its chance unknown")


class Kept(unittest.TestCase):
    """keeps: the gear and the recipes the Journal lists."""

    def test_uncommon_gear_is_kept(self):
        self.assertTrue(journal.keeps(drop(1, 1, 1, quality=2)))
        self.assertFalse(journal.keeps(drop(1, 1, 1, quality=1)), "white gear is left out")

    def test_a_recipe_is_kept_from_common(self):
        blueprint = {"id": 273099, "slot": 0, "class": journal.RECIPE, "quality": 1}
        self.assertTrue(journal.keeps(blueprint), "Blueprint: Spinning Wheel, Unstable Sentinel's")
        self.assertFalse(journal.keeps(dict(blueprint, quality=0)), "a poor one is left out")

    def test_a_recipe_has_no_armor_type(self):
        self.assertEqual(journal.kind({"class": journal.RECIPE, "subclass": 6}), (4, 0),
                         "Alchemy's subclass 6 is not a shield: every class can use the recipe")
        self.assertEqual(journal.kind({"class": 4, "subclass": 6}), (4, 6), "a shield stays one")

    def test_other_slotless_items_are_left_out(self):
        self.assertFalse(journal.keeps({"id": 251961, "slot": 0, "class": 12, "quality": 1}), "a quest item")
        self.assertFalse(journal.keeps({"id": 5, "slot": 0, "class": 13, "quality": 2}), "a key")


class WowsrcMerge(unittest.TestCase):
    """merge_wowsrc: wowsrc's Forever list over Wowhead's loot."""

    def setUp(self):
        self.facts = journal.item_facts
        journal.item_facts = lambda item_id: None   # offline: neither cache nor tables have it

    def tearDown(self):
        journal.item_facts = self.facts

    def test_an_item_without_facts_keeps_the_old_loot(self):
        loot = [dict(drop(6341, 1468, 15624), chance=9.0)]
        listed = {"items": [{"id": 273643, "chance": None, "new": True}], "complete": True}
        kept = journal.merge_wowsrc(loot, listed)
        self.assertEqual([i["id"] for i in kept], [6341], "not dropped over an item it could not read")

    def test_a_whole_list_moves_old_items_off(self):
        journal.item_facts = self.facts
        loot = [dict(drop(6341, 1468, 15624), chance=9.0), dict(drop(3191, 5241, 15624), chance=33.0)]
        listed = {"items": [{"id": 3191, "chance": 35.7, "new": False}], "complete": True}
        kept = journal.merge_wowsrc(loot, listed)
        self.assertEqual([i["id"] for i in kept], [3191])
        self.assertEqual(kept[0]["chance"], 35.7, "wowsrc's chance wins")


class InGame(unittest.TestCase):
    def setUp(self):
        self.saved = journal.game_items, journal.era_items, journal.sent, wago.table
        journal.game_items = journal.era_items = None
        journal.sent = {"loads": {7717}, "refused": {7718, 10800}}
        forever = {"Item": [{"ID": "10800", "ClassID": "4", "SubclassID": "2"},
                            {"ID": "3191", "ClassID": "2", "SubclassID": "1"}],
                   "ItemSparse": [{"ID": "3191"}]}
        era = {"Item": [{"ID": "10800", "ClassID": "4", "SubclassID": "2", "IconFileDataID": "132607"},
                        {"ID": "7718", "ClassID": "4", "SubclassID": "3", "IconFileDataID": "135032"}],
               "ItemSparse": [{"ID": "10800", "Display_lang": "Darkwater Bracers", "ItemLevel": "52",
                               "RequiredLevel": "47", "OverallQualityID": "3", "InventoryType": "9"},
                              {"ID": "7718", "Display_lang": "Herod\u2019s Shoulder", "ItemLevel": "42",
                               "RequiredLevel": "37", "OverallQualityID": "3", "InventoryType": "3"}]}
        wago.table = lambda name, build=None, hotfixes=True: (era if build == journal.CLASSIC_ERA else forever)[name]

    def tearDown(self):
        journal.game_items, journal.era_items, journal.sent, wago.table = self.saved

    def test_the_game_names_only_items_with_a_sparse_row(self):
        self.assertEqual(set(journal.game_tables()), {"3191"})

    def test_the_list_of_items_the_game_sent_is_read(self):
        journal.sent = None
        found = journal.in_game_list()
        self.assertIn(7717, found["loads"], "Ravager: no ItemSparse row on wago, loads in game")
        self.assertIn(10800, found["refused"])

    def test_an_item_only_on_the_list_is_in_forever(self):
        self.assertTrue(journal.known(7717))
        self.assertTrue(journal.known(3191), "in the game's tables")

    def test_a_refused_item_is_not_yet(self):
        self.assertFalse(journal.known(10800))
        self.assertFalse(journal.known(7718))

    def test_an_item_not_yet_is_named_from_classic_era(self):
        facts, name, icon = journal.not_yet_facts(10800)
        self.assertEqual((facts["level"], facts["reqlevel"], facts["quality"], name, icon),
                         (52, 47, 3, "Darkwater Bracers", 132607))
        self.assertIsNone(journal.not_yet_facts(273046), "a Forever item Classic Era never had")

    def test_items_file_keeps_the_two_apart_in_ascii(self):
        lines = journal.items_file({3191: drop(3191, 1, 1)},
                                         {7718: journal.not_yet_facts(7718)})
        text = "\n".join(lines)
        self.assertNotIn("[3191]", text, "an item in Forever is the shared list's")
        self.assertIn("ns.Journal.Items = ns.Shared.ItemFacts", text)
        self.assertIn('[7718] = { 4, 3, 42, 37, 3, 135032, "Herod\\226\\128\\153s Shoulder" },', text)
        text.encode("ascii")
        shared = "\n".join(journal.item_facts_file({3191: drop(3191, 1, 1)}))
        self.assertIn("ns.Shared.ItemFacts = {", shared)
        self.assertIn("[3191] = { 2, 1, 26, 21, 3 },", shared)
        shared.encode("ascii")

    def test_a_boss_lists_its_loot_with_no_count_left_out(self):
        boss = {"npc": 3975, "name": "Herod", "rare": False, "encounters": [448],
                "loot": [dict(drop(7718, 4167, 12682), chance=33.0), dict(drop(7717, 1776, 12682), chance=14.0)]}
        self.assertIn("loot = { 7718, 7717 }", journal.lua_boss(boss))
        self.assertNotIn("notInGame", journal.lua_boss(boss))

    def test_a_quest_boss_is_marked(self):
        boss = {"npc": 260808, "name": "Highland Horror", "rare": False, "quest": True, "encounters": [3644],
                "loot": []}
        self.assertIn("quest = true", journal.lua_boss(boss))
        boss["quest"] = False
        self.assertNotIn("quest", journal.lua_boss(boss))

    def test_the_wing_names_its_quest_bosses(self):
        wing = next(w for d in json.loads(journal.BOSSES.read_text(encoding="utf-8"))["dungeons"]
                    if d["key"] == "ExcavationSite" for w in d["wings"])
        self.assertEqual(wing["quest"], ["Highland Horror"])
        self.assertIn("Highland Horror", wing["bosses"])


class ItemsInGame(unittest.TestCase):
    PROBE = """
NaowhForeverDB = {
["observed"] = {
["v"] = 1,
},
["journalProbe"] = {
["refused"] = {
7718, -- [1]
10800, -- [2]
},
["build"] = 70300,
["loads"] = {
7717, -- [1]
9384, -- [2]
},
},
["dbVersion"] = 1,
}
"""

    def test_the_probe_is_read_from_saved_variables(self):
        build, answers = items_in_game.read_probe(self.PROBE)
        self.assertEqual(build, 70300)
        self.assertEqual(answers, {7718: False, 10800: False, 7717: True, 9384: True})

    def test_no_probe_no_answers(self):
        self.assertEqual(items_in_game.read_probe('NaowhForeverDB = {\n["dbVersion"] = 1,\n}\n'), (0, {}))

    def test_a_newer_answer_replaces_the_old(self):
        known = {"build": 70205, "loads": [7717, 10330], "refused": [9384, 10800]}
        build, answers = items_in_game.read_probe(self.PROBE)
        found = items_in_game.merge(known, build, answers)
        self.assertEqual(found, {"build": 70300, "loads": [7717, 9384, 10330], "refused": [7718, 10800]})

    def test_the_client_cache_last_answer_counts(self):
        def entry(record, status, size=0):
            return items_in_game.ENTRY.pack(b"XFTH", 70, -1, 0, items_in_game.ITEM_SPARSE, record, size, status) + b"x" * size
        data = struct.pack("<4sII", b"XFTH", 9, 70205) + b"\0" * 32
        data += entry(7717, 3) + entry(7717, 1, 4) + entry(7718, 3) + entry(273023, 1, 8)
        data += items_in_game.ENTRY.pack(b"XFTH", 70, 1, 0, 0x1234, 7718, 0, 1)
        build, answers = items_in_game.read_cache(data)
        self.assertEqual(build, 70205)
        self.assertEqual(answers, {7717: True, 7718: False, 273023: True},
                         "refused, then sent: loads; another table's record of 7718 does not count")

    def test_a_file_that_is_not_the_cache_is_refused(self):
        with self.assertRaises(ValueError):
            items_in_game.read_cache(b"WDB5" + b"\0" * 64)


class NewBosses(unittest.TestCase):
    def test_a_new_boss_read_from_few_kills_is_read_again(self):
        self.assertTrue(journal.stale({"new": True, "items": [drop(273023, 1, 2)]}),
                        "Saltspine at 2 kills: no chance to show")
        self.assertTrue(journal.stale({"new": True, "items": []}))
        self.assertFalse(journal.stale({"new": True, "items": [drop(273023, 62, 210)]}))
        self.assertFalse(journal.stale({"new": False, "items": [drop(7717, 1, 2)]}), "a classic boss")
        self.assertFalse(journal.stale([]))

    def test_a_world_drop_flag_on_its_own_item(self):
        drape = dict(drop(271097, 59, 157, new=True), world=True)    # Faldrim Anvilmar's, 38%
        stray = dict(drop(3047, 2, 68), world=True)                   # Highland Horror's, 3%
        kept = journal.choose([drape, stray], npc_new=True)
        self.assertEqual([i["id"] for i in kept], [271097])
        self.assertAlmostEqual(kept[0]["chance"], 100 * 59 / 157)


class SharedDrops(unittest.TestCase):
    def setUp(self):
        self.cache = journal.cache
        helm = drop(252455, 2, 5377, new=True)
        journal.cache = {f"drops6:{npc}": {"new": False, "items": [helm]} for npc in (4829, 4842, 4543)}
        journal.cache["drops6:3983"] = {"new": False, "items": [drop(274290, 22, 13863, new=True)]}

    def tearDown(self):
        journal.cache = self.cache

    def test_a_helm_from_many_bosses_is_left_out(self):
        helm = dict(drop(252455, 2, 5377, new=True), chance=None)
        buckler = dict(drop(274290, 22, 13863, new=True), chance=None)
        boss = {"loot": [helm, buckler]}
        shared = journal.shared_drops([({}, [{"bosses": [boss]}])])
        self.assertEqual(shared, {252455})
        self.assertEqual([i["id"] for i in boss["loot"]], [274290], "Painwalker Buckler: Vishas's alone")

    def test_wowsrc_or_a_hand_list_keeps_it(self):
        listed = dict(drop(252455, 2, 5377, new=True), chance=None, listed=True)
        by_hand = {"id": 252455, "chance": None, "quality": 3, "slot": 1}
        boss = {"loot": [listed, by_hand]}
        journal.shared_drops([({}, [{"bosses": [boss]}])])
        self.assertEqual(len(boss["loot"]), 2)


class OpenDungeons(unittest.TestCase):
    def setUp(self):
        self.game_items = journal.game_items
        journal.game_items = {str(i): None for i in (1, 2, 3)}

    def tearDown(self):
        journal.game_items = self.game_items

    @staticmethod
    def wing(*loot):
        return [{"bosses": [{"loot": [{"id": i} for i in ids]} for ids in loot]}]

    def test_wings_of_one_instance_count_together(self):
        built = [({"key": "Graveyard", "name": "SM - Graveyard"}, self.wing([1, 2, 3])),
                 ({"key": "Armory", "name": "SM - Armory"}, self.wing([7717, 7718])),
                 ({"key": "Uldaman", "name": "Uldaman"}, self.wing([1, 9384, 9387, 9388]))]
        maps = {"SM - Graveyard": "189", "SM - Armory": "189", "Uldaman": "70"}
        found = {d["key"]: is_open for d, _, is_open in journal.opened(built, maps.get)}
        self.assertEqual(found, {"Graveyard": True, "Armory": True, "Uldaman": False})

    def test_items_the_server_sends_do_not_open_a_dungeon(self):
        saved = journal.sent
        journal.sent = {"loads": {9384, 9387, 9388}, "refused": set()}
        try:
            built = [({"key": "Uldaman", "name": "Uldaman"}, self.wing([1, 9384, 9387, 9388]))]
            self.assertFalse(next(journal.opened(built, lambda name: None))[2])
        finally:
            journal.sent = saved

    def test_no_loot_known_is_not_open_and_the_list_can_say_so(self):
        built = [({"key": "DrownedCity", "name": "The Drowned City"}, self.wing([])),
                 ({"key": "Dalaran", "name": "City of Dalaran", "open": True}, self.wing([4]))]
        found = {d["key"]: is_open for d, _, is_open in journal.opened(built, lambda name: None)}
        self.assertEqual(found, {"DrownedCity": False, "Dalaran": True})


class DailyWatchLog(unittest.TestCase):
    """The loot job's filter on the build's output (.github/workflows/daily-watch.yml) hides the
    per-dungeon counts and keeps the build's report lines, which start with two spaces."""

    def setUp(self):
        workflow = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "daily-watch.yml"
        found = re.search(r'grep -Ev "([^"]+)" "\$RUNNER_TEMP/build.txt"', workflow.read_text(encoding="utf-8"))
        self.assertIsNotNone(found, "the loot job filters build.txt with grep -Ev")
        self.hidden = re.compile(found.group(1))

    def test_counts_are_hidden(self):
        self.assertTrue(self.hidden.search("   12  Ragefire Chasm"))
        self.assertTrue(self.hidden.search("  133  Dire Maul"))

    def test_report_lines_are_kept(self):
        for line in ("  not in the game's item tables, left out: 47 items (Sunken Temple): 10624",
                     "  no NPC found: Lord Roccor",
                     "  wowsrc item not mapped: Dreadmist Mask (Darkmaster Gandling, Scholomance)",
                     "  dropped by many bosses, left out: 252455, 252512",
                     "  not open yet: Razorfen Downs",
                     "  not in Forever yet, listed from Classic Era: 2 items (Shadowfang Keep): 23171, 23173",
                     "383 items, 35 dungeons"):
            self.assertFalse(self.hidden.search(line), line)


class RefreshDrops(unittest.TestCase):
    """--refresh-drops: a boss's cached drops are read again, once a run, and today's count wins."""

    def setUp(self):
        self.saved = (journal.cache, journal.fetch, journal.REFRESH_DROPS, journal.OFFLINE, journal.refreshed)
        self.pages = []
        row = {"id": 9461, "name": "Charged Gear", "quality": 3, "slot": 11, "classs": 4, "subclass": 0,
               "level": 34, "reqlevel": 29, "count": 33, "outof": 100}

        def fetch(url):
            self.pages.append(url)
            return "template: 'item', id: 'drops', _totalCount: 100, data: " + json.dumps([row])

        journal.fetch = fetch
        journal.cache = {"drops6:7800": {"new": False, "items": [drop(9461, 18, 100)]}}
        journal.REFRESH_DROPS, journal.OFFLINE, journal.refreshed = True, False, set()

    def tearDown(self):
        journal.cache, journal.fetch, journal.REFRESH_DROPS, journal.OFFLINE, journal.refreshed = self.saved

    def test_a_cached_boss_is_read_again_once(self):
        first = journal.wowhead_drops("npc", 7800)
        again = journal.wowhead_drops("npc", 7800)
        self.assertEqual(len(self.pages), 1, "one page a boss, however often the build asks")
        self.assertAlmostEqual(first[0]["chance"], 33)
        self.assertEqual(first, again)

    def test_without_the_flag_the_cache_answers(self):
        journal.REFRESH_DROPS = False
        kept = journal.wowhead_drops("npc", 7800)
        self.assertEqual(self.pages, [])
        self.assertAlmostEqual(kept[0]["chance"], 18)

    def test_offline_a_gear_only_answer_stands_in(self):
        journal.REFRESH_DROPS, journal.OFFLINE = False, True
        journal.cache = {"drops5:7800": {"new": False, "items": [drop(9461, 18, 100)]}}
        kept = journal.wowhead_drops("npc", 7800)
        self.assertEqual(self.pages, [], "offline: Wowhead is never asked")
        self.assertEqual([i["id"] for i in kept], [9461], "the boss keeps its gear until it is read again")

    def test_a_new_answer_replaces_the_gear_only_one(self):
        journal.REFRESH_DROPS = False
        journal.cache = {"drops5:7800": {"new": False, "items": [drop(9461, 18, 100)]}}
        kept = journal.wowhead_drops("npc", 7800)
        self.assertEqual(len(self.pages), 1)
        self.assertAlmostEqual(kept[0]["chance"], 33)
        self.assertEqual(list(journal.cache), ["drops6:7800"], "the old answer is let go")

    def test_a_recipe_on_the_page_is_cached(self):
        journal.REFRESH_DROPS = False
        journal.cache = {}
        recipe = {"id": 273099, "name": "Blueprint: Spinning Wheel", "quality": 1, "slot": 0, "classs": 9,
                  "subclass": 2, "level": 30, "count": 40, "outof": 100}
        journal.fetch = lambda url: ("template: 'item', id: 'drops', _totalCount: 100, data: "
                                     + json.dumps([recipe]))
        kept = journal.wowhead_drops("npc", 246017)
        self.assertEqual([i["id"] for i in kept], [273099])


if __name__ == "__main__":
    unittest.main()
