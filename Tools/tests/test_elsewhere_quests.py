"""Tests for Tools/build/elsewhere_quests.py's reading of the QuestPositions addon's answers and
its placing of a giver from them: one spot per zone map while its spawns stand together, each
when they stand apart, none for a spawn the client put on no zone or on a map that is no zone's;
and the zone map the rectangles pick for a spawn. Offline. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import elsewhere_quests  # noqa: E402

SAVED = '''
QuestPositionsResults = {
"0,-8913.2,554.6=1453,48.51,49.98", -- [1]
"1,-981.2,-3686.5=1413,51.82,30.24", -- [2]
"0,100.0,-200.0=", -- [3]
"1,1.0,2.0=1413,-0.35,40.12", -- [4]
}
'''


class ReadResolved(unittest.TestCase):
    def test_spots_and_unplaced(self):
        self.assertEqual(elsewhere_quests.read_resolved(SAVED), {
            "0,-8913.2,554.6": [1453, 48.51, 49.98],
            "1,-981.2,-3686.5": [1413, 51.82, 30.24],
            "0,100.0,-200.0": None,
            "1,1.0,2.0": [1413, -0.35, 40.12],
        })


class ClientSpots(unittest.TestCase):
    positions = {"a": [1453, 48.51, 49.98], "b": [1453, 49.5, 50.5], "f": [1453, 60.0, 70.0],
                 "c": [1413, 51.82, 30.24], "d": None, "e": [1414, 40.0, 50.0]}
    names = {1: "Grimand Elmore", 2: "Gazrog"}

    def spots(self, spawns):
        return elsewhere_quests.client_spots([1, 2], spawns, self.positions, self.names)

    def test_one_spot_per_map(self):
        self.assertEqual(self.spots({1: ["a", "b"]}), {(1453, 48.5, 50.0, "Grimand Elmore")})

    def test_apart_on_one_map_each(self):
        self.assertEqual(len(self.spots({1: ["a", "f"]})), 2)

    def test_two_maps_two_spots(self):
        self.assertEqual(len(self.spots({1: ["a"], 2: ["c"]})), 2)

    def test_unplaced_and_continent_left_out(self):
        self.assertEqual(self.spots({1: ["d", "e", "missing"]}), set())


class GeometryMap(unittest.TestCase):
    # A zone 1000 yards square, a city 100 yards square well inside it, and a neighbour that
    # overlaps the zone's southern 100 yards. Map x runs down the world's Y, map y down its X.
    rects = [(1429, "0", 0.0, 0.0, 1000.0, 1000.0, (0.0, 0.0), (1.0, 1.0)),
             (1453, "0", 400.0, 400.0, 500.0, 500.0, (0.0, 0.0), (1.0, 1.0)),
             (1431, "0", -1000.0, 0.0, 100.0, 1000.0, (0.0, 0.0), (1.0, 1.0))]

    def test_city_inside_its_zone(self):
        self.assertEqual(elsewhere_quests.geometry_map("0,450.0,450.0", self.rects), 1453)

    def test_overlap_goes_to_the_map_it_is_well_inside(self):
        self.assertEqual(elsewhere_quests.geometry_map("0,20.0,500.0", self.rects), 1431)

    def test_near_every_edge_takes_the_smallest(self):
        rects = [self.rects[0], (1431, "0", -1000.0, 0.0, 10.0, 1000.0, (0.0, 0.0), (1.0, 1.0))]
        self.assertEqual(elsewhere_quests.geometry_map("0,5.0,500.0", rects), 1429)

    def test_part_of_a_map_projects_onto_its_part(self):
        # The zone's rectangle is the right half of its map image, so the spawn on its western
        # edge is in the middle of the map, not on an edge, and beats the bigger map.
        rects = [(1429, "0", 0.0, 0.0, 1000.0, 1000.0, (0.5, 0.0), (1.0, 1.0)),
                 (1431, "0", -1000.0, -1000.0, 2000.0, 3000.0, (0.0, 0.0), (1.0, 1.0))]
        self.assertEqual(elsewhere_quests.geometry_map("0,500.0,1000.0", rects), 1429)

    def test_other_continent_and_outside(self):
        self.assertIsNone(elsewhere_quests.geometry_map("1,450.0,450.0", self.rects))
        self.assertIsNone(elsewhere_quests.geometry_map("0,5000.0,450.0", self.rects))


if __name__ == "__main__":
    unittest.main()
