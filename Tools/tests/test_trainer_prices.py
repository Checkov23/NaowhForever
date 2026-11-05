"""Tests for Tools/build/trainer_prices.py: reading the trainer window's prices from SavedVariables.
Offline: the files are made up here. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import trainer_prices as tp  # noqa: E402

SAVED = """
NaowhForeverDB = {
["journalWindow"] = {
"CENTER",
},
["trainingCharPrices"] = {
["Player-6796-006CA983"] = {
[1126] = 10,
[1062] = 1500,
},
["Player-6796-00000001"] = {
[6673] = 10,
},
},
}
"""
DATA = """ns.TrainingData = {
    [1] = {
        { 1, 6673, 10 },
    },
    [11] = {
        { 1, 1126, 10 },
        { 18, 1062, 1900, needs = 339 },
    },
}
"""


class ReadSaved(unittest.TestCase):
    def test_each_characters_prices(self):
        self.assertEqual(tp.read_saved(SAVED), {"Player-6796-006CA983": {1126: 10, 1062: 1500},
                                                "Player-6796-00000001": {6673: 10}})

    def test_none_read_yet(self):
        self.assertEqual(tp.read_saved('NaowhForeverDB = {\n["lastFoodIcon"] = 1,\n}\n'), {})


class ReadClassList(unittest.TestCase):
    def test_spells_by_level(self):
        text = ("local swipe = {779, 780}\nclass.spellsByLevel = {\n\t[1] = {{id = 1126, cost = 10}},\n"
                "\t[6] = {{id = 5177, cost = 100, requiredIds = {5176}}, {id = 467, cost = 100}},\n}\n")
        self.assertEqual(tp.read_class_list(text), {1126: 10, 5177: 100, 467: 100})


class ByClass(unittest.TestCase):
    SPELLS = tp.class_spells(DATA)

    def test_each_character_goes_to_its_class(self):
        found = tp.by_class(tp.read_saved(SAVED), self.SPELLS)
        self.assertEqual(found, {"druid": {1126: 10, 1062: 1500}, "warrior": {6673: 10}})

    def test_prices_of_no_one_class_are_skipped(self):
        self.assertEqual(tp.by_class({"Player-1": {6673: 10, 1126: 10}}, self.SPELLS), {})

    def test_two_characters_asked_different_prices_stop_the_read(self):
        with self.assertRaises(SystemExit):
            tp.by_class({"Player-1": {1062: 1500}, "Player-2": {1062: 1350}}, self.SPELLS)


if __name__ == "__main__":
    unittest.main()
