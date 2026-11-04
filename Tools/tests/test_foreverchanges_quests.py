"""Tests for Tools/build/foreverchanges_quests.py's reading of a quest page's givers, and for what
completo_quests.py does with the list: a quest it does not list is left out, one only it lists is
added to its zone, or to Unsorted Quests without a giver, one filed under no category is not, a
quest goes in the zone it is filed under, and
its giver's spot, the one on the quest's zone map first, comes before Wowhead's, on Ironforge's map
too for one ForeverChanges puts on Dun Morogh's inside the city, and never on a map Forever redrew.
Offline. From the
repo root:

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
import completo_quests  # noqa: E402
import foreverchanges_quests  # noqa: E402


def page(zones):
    chunk = '80:["$","aside",null,{"children":[["$","$L84",null,{"zones":' + json.dumps(zones) + '}]]}]'
    return f'<script>self.__next_f.push([1,{json.dumps("0:[]")}])</script>' \
           f'<script>self.__next_f.push([1,{json.dumps(chunk)}])</script>'


class ParseStarts(unittest.TestCase):
    def test_start_pins_of_every_zone(self):
        zones = [{"id": 1436, "pins": [{"x": 56, "y": 31.2, "name": "Farmer Saldean", "start": True},
                                       {"x": 56.3, "y": 47.5, "name": "Gryan Stoutmantle", "end": True}]},
                 {"id": 1429, "pins": [{"x": 42.1, "y": 65.9, "name": "Marshal Dughan", "start": True, "end": True}]}]
        self.assertEqual(foreverchanges_quests.parse_starts(page(zones)),
                         [[1436, 56, 31.2, "Farmer Saldean"], [1429, 42.1, 65.9, "Marshal Dughan"]])

    def test_item_quest_and_page_without_map(self):
        zones = [{"id": 1440, "pins": [{"x": 73.8, "y": 61.5, "name": "Senani Thunderheart", "end": True}]}]
        self.assertEqual(foreverchanges_quests.parse_starts(page(zones)), [])
        self.assertEqual(foreverchanges_quests.parse_starts("<html></html>"), [])

    def test_list_row(self):
        row = {"i": 98601, "n": "A Difficult Path", "l": 1, "m": 1, "s": "h", "c": ["sort", 141], "cl": 2}
        self.assertEqual(foreverchanges_quests.quest_row(row), {
            "name": "A Difficult Path", "level": 1, "reqlevel": 1, "side": 2, "reqclass": 2,
            "category": ["sort", 141]})


class ListedMaps(unittest.TestCase):
    def test_dun_morogh_spot_inside_ironforge_is_on_its_map_first(self):
        # Prospector Stormpike: 63.1, 23 on Dun Morogh's map, 74.4, 12.0 on Ironforge's per Wowhead.
        (city, x, y), outside = completo_quests.listed_maps(1426, 63.1, 23)
        self.assertEqual((city, round(x, 1), round(y, 1)), (1455, 74.9, 11.9))
        self.assertEqual(outside, (1426, 63.1, 23))

    def test_other_spots_stay(self):
        self.assertEqual(completo_quests.listed_maps(1426, 30, 50), [(1426, 30, 50)])
        self.assertEqual(completo_quests.listed_maps(1429, 63.1, 23), [(1429, 63.1, 23)])

    def test_the_quests_zone_picks_the_map(self):
        # Jordan Stilwell stands at Ironforge's gates, in Dun Morogh.
        starts = [[1426, 52.5, 36.9, "Jordan Stilwell"]]
        self.assertEqual(completo_quests.listed_spot(starts, 1426), (1426, 52.5, 36.9, "Jordan Stilwell"))
        self.assertEqual(completo_quests.listed_spot(starts, 1432)[0], 1455)

    def test_no_giver_from_a_redrawn_map(self):
        # High Sorcerer Andromath at Classic's 37.6, 81.6 on Forever's redrawn Stormwind.
        andromath = [1453, 37.6, 81.6, "High Sorcerer Andromath"]
        self.assertIsNone(completo_quests.listed_spot([andromath], 1453))
        self.assertEqual(completo_quests.listed_spot([andromath, [1429, 42.1, 65.9, "Marshal Dughan"]], 1453)[0], 1429)


class Write(unittest.TestCase):
    def write(self, zones, quests, listed):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out):
                completo_quests.write(zones, quests, {}, {}, {}, {}, {}, listed)
            return out.read_text()

    def test_list_decides_the_quests_and_their_spots(self):
        zones = {"12": {"name": "Elwynn Forest", "quests": [
            {"id": 7, "name": "Kobold Camp Cleanup", "level": 2, "reqlevel": 1, "side": 1},
            {"id": 8, "name": "Not Listed", "level": 2, "reqlevel": 1, "side": 1},
            {"id": 9, "name": "Wowhead Only Spot", "level": 2, "reqlevel": 1, "side": 1}]},
                 "1519": {"name": "Stormwind City", "quests": []},
                 "267": {"name": "Hillsbrad Foothills", "quests": [
                     {"id": 540, "name": "Preserving Knowledge", "level": 30, "reqlevel": 25, "side": 1}]}}
        quests = {"7": {"chain": None, "start": {"zone": 12, "coord": [48.8, 41.6], "npc": "Marshal McBride"}},
                  "9": {"chain": None, "start": {"zone": 12, "coord": [40, 50], "npc": "Somebody"}}}
        row = {"level": 5, "reqlevel": 1, "side": 3, "reqclass": 0}
        listed = {"quests": {"7": dict(row, name="Kobold Camp Cleanup", category=["zone", 12]),
                             "9": dict(row, name="Wowhead Only Spot", category=["zone", 12]),
                             "94901": dict(row, name="Hopping Helpers", category=["zone", 12]),
                             "999": dict(row, name="When Dreams Turn to Nightmares", category=["dungeon", 718]),
                             "8021": dict(row, name="Redeem iCoke Prize Voucher", category=None),
                             "540": dict(row, name="Preserving Knowledge", category=["zone", 1519])},
                  "starts": {"7": [[1436, 10, 10, "Elsewhere"], [1429, 48.9, 41.6, "Marshal McBride"]],
                             "9": [], "94901": [[1429, 30, 20, "Hopper"]], "999": [], "8021": [], "540": []}}
        text = self.write(zones, quests, listed)
        self.assertIn('[7] = { "Kobold Camp Cleanup", 2, 1, 1, 0, 0, 1429, 48.9, 41.6, "Marshal McBride" }', text)
        self.assertIn('[9] = { "Wowhead Only Spot", 2, 1, 1, 0, 0, 1429, 40.0, 50.0, "Somebody" }', text)
        self.assertNotIn("[8]", text)
        self.assertIn('[94901] = { "Hopping Helpers", 5, 1, 3, 0, 0, 1429, 30.0, 20.0, "Hopper" }', text)
        self.assertIn('map = 1429, name = "Elwynn Forest", continent = 0, quests = { 7, 9, 94901 }', text)
        self.assertIn('map = 0, name = "Unsorted Quests", continent = 0, quests = { 999 }', text)
        self.assertNotIn("[8021]", text)
        self.assertIn('map = 1453, name = "Stormwind City", continent = 0, quests = { 540 }', text)
        self.assertNotIn('name = "Hillsbrad Foothills"', text)

    def test_without_the_list_nothing_changes(self):
        zones = {"12": {"name": "Elwynn Forest", "quests": [{"id": 8, "name": "Kept", "level": 2, "reqlevel": 1, "side": 1}]}}
        self.assertIn('[8] = { "Kept", 2, 1, 1, 0, 0, nil, nil, nil, nil }', self.write(zones, {}, None))


class Report(unittest.TestCase):
    def quest(self, name, level):
        return {"name": name, "level": level, "reqlevel": 1, "side": 3, "reqclass": 0, "category": ["zone", 12]}

    def test_new_gone_and_changed_quests(self):
        before = {"1": self.quest("Kept", 5), "2": self.quest("Dropped", 8), "3": self.quest("Moved", 10)}
        after = {"1": self.quest("Kept", 5), "3": self.quest("Moved", 12), "4": self.quest("Arrived", 20)}
        self.assertEqual(foreverchanges_quests.report(before, after).splitlines(), [
            "### Quests", "",
            "https://foreverchanges.pro/quests lists 3 quests: 1 new, 1 gone, 1 changed.",
            "", "**New:**", "", "- Arrived (4), level 20",
            "", "**Gone:**", "", "- Dropped (2), level 8",
            "", "**Changed:**", "", "- Moved (3), level 12"])

    def test_long_lists_are_counted(self):
        after = {str(i): self.quest(f"Quest {i}", 1) for i in range(foreverchanges_quests.REPORT_ROWS + 3)}
        lines = foreverchanges_quests.report({}, after).splitlines()
        self.assertEqual(lines[-1], "- and 3 more")
        self.assertEqual(sum(line.startswith("- Quest") for line in lines), foreverchanges_quests.REPORT_ROWS)


if __name__ == "__main__":
    unittest.main()
