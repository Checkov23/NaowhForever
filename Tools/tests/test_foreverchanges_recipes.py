"""Tests for Tools/build/foreverchanges_recipes.py: reading recipes and their sources out of
ForeverChanges' profession and dungeon pages, whose data comes in pushed string chunks, and
writing them into RecipeData's unknown recipes. Offline, made-up pages. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import foreverchanges_recipes as fc  # noqa: E402

TRADE = ('1:["$","$L5",null,{"rows":[{"spell":3188,"id":3391,"formula":{"id":6211,"q":1},"source":'
         '{"vendors":[{"npc":"Kor\'geld","zone":"Orgrimmar","side":"h","price":13000}]}},'
         '{"spell":7183,"id":5997,"formula":null,"source":null}],"crafted":[{"spell":1263056,'
         '"id":279985,"taught_by":273103},{"spell":7421,"id":6218,"taught_by":null}]}]\n')
DUNGEON = ('2:["$","$L9",null,{"bosses":[{"name":"Obsidian Sentinel","kind":"boss","items":['
           '{"i":251400,"n":"Plans: Warder\'s Boots","c":9},{"i":9375,"n":"Expert First Aid","c":4}]},'
           '{"name":"Trash mobs","kind":"trash","items":[]}]}]\n')
RECIPES = (
    '    [171] = {\r\n'
    '        recipes = {\r\n'
    '            { spell = 1, item = 11, skill = 5, recipe = 101, source = "vendor", vendors = {\r\n'
    '                { 5594, "Alchemist Pestlezugg", "A", 1446, 50.8, 27 },\r\n'
    '            } },\r\n'
    '            { spell = 2, item = 12, skill = 10, yellow = 15, grey = 20, source = "unknown" },\r\n'
    '            { spell = 3, item = 13, skill = 15, recipe = 103, source = "unknown" },\r\n'
    '            { spell = 4, skill = 20, source = "unknown" },\r\n'
    '            { spell = 5, item = 15, skill = 25, recipe = 105, source = "unknown" },\r\n'
    '            { spell = 6, item = 16, skill = 30, source = "unknown" },\r\n'
    '        },\r\n'
    '    },\r\n')
SOURCES = {
    "1": {"recipe": 101, "world": True},
    "2": {"recipe": 102, "vendors": [["Alchemist Pestlezugg", "Tanaris", "", None],
                                     ["Happy Camper", "Dun Morogh", "", 1500]]},
    "3": {"recipe": 103, "bosses": [["Fel Steed", "Shadowfang Keep"], ["Gilnid", "The Deadmines"],
                                    ["Fel Steed", "Shadowfang Keep"]]},
    "4": {"recipe": 104, "world": True},
    "6": {"recipe": 106, "quests": [["Cluster Launcher", "", 60, None]]},
}
ZONES = {"Dun Morogh": 1, "Shadowfang Keep": 209, "Tanaris": 440, "The Deadmines": 1581}
CHINESE_NAME = chr(0x5766) + chr(0x65AF)


def push(text):
    return f"<script>self.__next_f.push([1,{json.dumps(text)}])</script>"


class Pages(unittest.TestCase):
    def test_the_recipes_with_an_item_across_chunks(self):
        page = fc.page_data(push(TRADE[:60]) + push(TRADE[60:]))
        self.assertEqual(fc.trade_recipes(page), [
            (3188, 6211, {"vendors": [{"npc": "Kor'geld", "zone": "Orgrimmar", "side": "h", "price": 13000}]}),
            (1263056, 273103, {}),
        ])

    def test_the_recipes_a_dungeons_bosses_drop(self):
        page = fc.page_data(push(DUNGEON))
        self.assertEqual(fc.boss_recipes(page, "Uldaman"), {251400: [["Obsidian Sentinel", "Uldaman"]]})

    def test_a_dungeon_not_out_yet_lists_no_bosses(self):
        self.assertEqual(fc.boss_recipes(fc.page_data(push('3:["$","div",null,{"bosses":null}]\n')), "Alcaz"), {})


class Source(unittest.TestCase):
    def test_sellers_come_first_and_a_name_in_another_language_is_left_out(self):
        found = {"vendors": [{"npc": "Tansy Puddlefizz", "zone": "Dun Morogh", "side": "a", "price": 2200},
                             {"npc": CHINESE_NAME, "zone": "Ironforge", "side": "a"}],
                 "drops": [{"npc": "Ro'Bark", "zone": "Hillsbrad Foothills"}]}
        self.assertEqual(fc.source(found, None), {"vendors": [["Tansy Puddlefizz", "Dun Morogh", "a", 2200]]})

    def test_a_drop_from_more_mobs_than_it_names_is_a_world_drop(self):
        found = {"drops": [{"npc": "Ro'Bark", "zone": "Hillsbrad Foothills"}],
                 "places": [{"zone": "Ashenvale", "n": 38}], "more_places": 23}
        self.assertEqual(fc.source(found, None), {"world": True})

    def test_the_mobs_it_names_are_its_bosses(self):
        found = {"drops": [{"npc": "Weapon Technician", "zone": "Blackrock Depths"}],
                 "places": [{"zone": "Blackrock Depths", "n": 1}]}
        self.assertEqual(fc.source(found, None), {"bosses": [["Weapon Technician", "Blackrock Depths"]]})

    def test_a_quest(self):
        found = {"quests": [{"name": "Cluster Launcher", "level": 60, "side": ""}]}
        self.assertEqual(fc.source(found, None), {"quests": [["Cluster Launcher", "", 60, None]]})

    def test_a_dungeon_boss_only_where_the_page_names_nothing(self):
        bosses = [["Obsidian Sentinel", "Uldaman"]]
        self.assertEqual(fc.source({}, bosses), {"bosses": bosses})
        self.assertEqual(fc.source({"quests": [{"name": "Q", "level": 1, "side": "a"}]}, bosses)["quests"],
                         [["Q", "a", 1, None]])
        self.assertIsNone(fc.source({"places": [{"zone": "Wailing Caverns", "n": 0}]}, None))


class Areas(unittest.TestCase):
    def test_the_zone_or_dungeon_before_a_subzone_and_the_lower_id(self):
        rows = [{"ID": "133", "AreaName_lang": "Gnomeregan", "ParentAreaID": "1"},
                {"ID": "721", "AreaName_lang": "Gnomeregan", "ParentAreaID": "0"},
                {"ID": "16116", "AreaName_lang": "Swamp of Sorrows", "ParentAreaID": "0"},
                {"ID": "8", "AreaName_lang": "Swamp of Sorrows", "ParentAreaID": "0"},
                {"ID": "1216", "AreaName_lang": "Blackmaw Hold", "ParentAreaID": "16"}]
        self.assertEqual(fc.areas(rows, {"Gnomeregan", "Swamp of Sorrows", "Blackmaw Hold", "Dire Maul North"}),
                         {"Blackmaw Hold": 1216, "Dire Maul North": 0, "Gnomeregan": 721, "Swamp of Sorrows": 8})


class Fill(unittest.TestCase):
    def test_only_unknown_recipes_are_given_their_source(self):
        lines = fc.fill(RECIPES, SOURCES, ZONES).split("\r\n")
        self.assertEqual(lines[2:], [
            '            { spell = 1, item = 11, skill = 5, recipe = 101, source = "vendor", vendors = {',
            '                { 5594, "Alchemist Pestlezugg", "A", 1446, 50.8, 27 },',
            '            } },',
            '            { spell = 2, item = 12, skill = 10, yellow = 15, grey = 20, recipe = 102, '
            'source = "vendor", vendors = {',
            '                { 5594, "Alchemist Pestlezugg", "AH", 1446, 50.8, 27 },',
            '            }, sellers = {',
            '                { "Happy Camper", "AH", 1, 1500 },',
            '            } },',
            '            { spell = 3, item = 13, skill = 15, recipe = 103, source = "drop", bosses = {',
            '                { "Fel Steed", 209 },',
            '                { "Gilnid", 1581 },',
            '            } },',
            '            { spell = 4, skill = 20, recipe = 104, source = "drop", world = 1 },',
            '            { spell = 5, item = 15, skill = 25, recipe = 105, source = "unknown" },',
            '            { spell = 6, item = 16, skill = 30, recipe = 106, source = "quest", quests = {',
            '                { name = "Cluster Launcher", side = "AH", level = 60 },',
            '            } },',
            '        },',
            '    },',
            '',
        ])

    def test_filling_again_changes_nothing(self):
        once = fc.fill(RECIPES, SOURCES, ZONES)
        self.assertEqual(fc.fill(once, SOURCES, ZONES), once)

    def test_the_checked_in_recipes_are_what_the_json_writes(self):
        data = json.loads(fc.OUT.read_text(encoding="utf-8"))
        text = fc.RECIPES.read_bytes().decode("ascii")
        self.assertEqual(fc.fill(text, data["recipes"], data["areas"]), text)


if __name__ == "__main__":
    unittest.main()
