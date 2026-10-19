"""Tests for Tools/build/elsewhere_quests.py's reading of the QuestPositions addon's answers and
its placing of a giver from them: one spot per zone map while its spawns stand together, each
when they stand apart, none for a spawn the client put on no zone or on a map that is no zone's.
Offline. From the repo root:

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


if __name__ == "__main__":
    unittest.main()
