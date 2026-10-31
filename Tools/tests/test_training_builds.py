"""Tests for Tools/build/training_builds.py: where it puts each talent and which talent it needs,
from Wowhead Forever's talent calculator data. Offline: Wowhead is never asked; the talents are made
up here. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import training_builds as tb  # noqa: E402

TREES = (81, 41, 61)


def talent(tid, row, col, ranks=3, needs=()):
    return {"id": tid, "row": row, "col": col, "ranks": [tid + 5000] * ranks,
            "requires": [{"id": n, "qty": q} for n, q in needs]}


class Trees(unittest.TestCase):
    def read(self, *trees):
        saved = tb.TREES
        tb.TREES = {8: (TREES, ("Arcane", "Fire", "Frost"))}
        try:
            return tb.class_trees({str(tree_id): {str(t["id"]): t for t in talents}
                                   for tree_id, talents in zip(TREES, trees)})
        finally:
            tb.TREES = saved

    def test_places_each_talent_by_tree_row_and_column(self):
        trees = self.read([talent(1, 0, 0)], [talent(2, 3, 2, ranks=5)], [talent(3, 6, 3, ranks=1)])
        self.assertEqual(trees[8], {1: [5001, 3, 1, 1, 1], 2: [5002, 5, 4, 2, 3], 3: [5003, 1, 7, 3, 4]})

    def test_a_talent_lists_the_one_it_needs_at_full_rank(self):
        trees = self.read([talent(1, 0, 1, ranks=5), talent(2, 2, 1, needs=[(1, 5)])], [], [])
        self.assertEqual(trees[8][2][5:], [1])
        self.assertEqual(trees[8][1][5:], [])

    def test_a_talent_needing_two_stops_the_build(self):
        with self.assertRaises(SystemExit):
            self.read([talent(1, 0, 0), talent(2, 0, 1), talent(3, 2, 0, needs=[(1, 3), (2, 3)])], [], [])

    def test_a_talent_needing_part_of_another_stops_the_build(self):
        with self.assertRaises(SystemExit):
            self.read([talent(1, 0, 0, ranks=5), talent(2, 2, 0, needs=[(1, 3)])], [], [])

    def test_a_tree_wowhead_lacks_stops_the_build(self):
        saved = tb.TREES
        tb.TREES = {8: (TREES, ("Arcane", "Fire", "Frost"))}
        try:
            with self.assertRaises(SystemExit):
                tb.class_trees({"81": {}, "41": {}})
        finally:
            tb.TREES = saved


if __name__ == "__main__":
    unittest.main()
