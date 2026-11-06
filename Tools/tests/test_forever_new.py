"""Tests for Tools/build/forever_new.py's rule: an item or quest is new in Forever when Forever's
own table has it and Classic Era's does not. Offline: the tables are made up here. From the repo
root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import forever_new  # noqa: E402
import wago  # noqa: E402


def ids(*numbers):
    return [{"ID": str(n)} for n in numbers]


class NewInTable(unittest.TestCase):
    def setUp(self):
        self.saved = wago.table, wago.CARRY_FROM
        wago.CARRY_FROM = None
        self.tables = {
            wago.BUILD: {"ItemSparse": ids(5813, 7066, 273023), "QuestV2": ids(1012, 7668, 78150, 96800)},
            forever_new.CLASSIC_ERA: {"ItemSparse": ids(5813, 19019), "QuestV2": ids(1012, 7668, 78150)},
        }
        wago.table = lambda name, build, hotfixes=True: self.tables[build][name]

    def tearDown(self):
        wago.table, wago.CARRY_FROM = self.saved

    def test_an_item_classic_era_lacks_is_new(self):
        self.assertEqual(forever_new.new_in_table("ItemSparse"), [7066, 273023],
                         "Exotic Silk Dress is new on an ID Classic Era never used")

    def test_a_quest_classic_era_has_is_not_new(self):
        self.assertEqual(forever_new.new_in_table("QuestV2"), [96800],
                         "Friend of the Library (78150) and The Darkreaver Menace (7668) are Classic Era's")

    def test_the_build_carried_from_counts_as_forever(self):
        wago.CARRY_FROM = "1.60.1.70755"
        self.tables[wago.CARRY_FROM] = {"ItemSparse": ids(273053, 5813)}
        self.assertEqual(forever_new.new_in_table("ItemSparse"), [7066, 273023, 273053])


if __name__ == "__main__":
    unittest.main()
