"""Tests for Tools/build/training_builds.py: where it puts each talent and which talent it needs,
from the game's talent tables. Offline: wago.tools is never asked; the rows are made up here. From
the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import training_builds as tb  # noqa: E402
import wago  # noqa: E402

TREE = 1112


def node(nid, x, y):
    return {"ID": str(nid), "TraitTreeID": str(TREE), "PosX": str(x), "PosY": str(y)}


def at(tree, column, row):
    return tb.FIRST_X + (tree - 1) * tb.TREE_X + (column - 1) * tb.GRID, tb.FIRST_Y + (row - 1) * tb.GRID


def tables(nodes, edges):
    return {
        "TraitNode": [node(n, *(at(*where) if len(where) == 3 else where)) for n, where in nodes],
        "TraitNodeXTraitNodeEntry": [{"TraitNodeID": str(n), "TraitNodeEntryID": str(n + 1000), "_Index": "0"}
                                     for n, _ in nodes],
        "TraitNodeEntry": [{"ID": str(n + 1000), "TraitDefinitionID": str(n + 2000), "MaxRanks": "3"}
                           for n, _ in nodes],
        "TraitDefinition": [{"ID": str(n + 2000), "SpellID": str(n + 5000)} for n, _ in nodes],
        "TraitEdge": [{"LeftTraitNodeID": str(a), "RightTraitNodeID": str(b)} for a, b in edges],
    }


class Trees(unittest.TestCase):
    def read(self, nodes, edges):
        rows = tables(nodes, edges)
        saved_table, saved_trees = wago.table, tb.TREES
        wago.table = lambda name, build=None: rows[name]
        tb.TREES = {8: (TREE, ("Arcane", "Fire", "Frost"))}
        try:
            return tb.class_trees("test")
        finally:
            wago.table, tb.TREES = saved_table, saved_trees

    def test_places_each_talent_by_tree_column_and_row(self):
        trees, parked = self.read([(1, (1, 1, 1)), (2, (2, 3, 4)), (3, (3, 4, 7))], [])
        self.assertEqual(trees[8], {1: [5001, 3, 1, 1, 1], 2: [5002, 3, 4, 2, 3], 3: [5003, 3, 7, 3, 4]})
        self.assertEqual(parked, [])

    def test_leaves_out_talents_parked_outside_the_grid(self):
        trees, parked = self.read([(1, (1, 1, 1)), (2, (102800, 5740)), (3, (6820, 39300))], [])
        self.assertEqual(list(trees[8]), [1])
        self.assertEqual(parked, ["mage 2", "mage 3"])

    def test_the_lower_talent_needs_the_upper_whichever_end_the_edge_names(self):
        nodes = [(1, (1, 2, 1)), (2, (1, 2, 3)), (3, (1, 2, 5))]
        trees, _ = self.read(nodes, [(1, 2), (3, 2), (3, 2)])
        self.assertEqual(trees[8][2][5:], [1])
        self.assertEqual(trees[8][3][5:], [2])
        self.assertEqual(trees[8][1][5:], [])

    def test_on_one_row_the_right_end_needs_the_left(self):
        trees, _ = self.read([(1, (1, 2, 5)), (2, (1, 1, 5))], [(1, 2)])
        self.assertEqual(trees[8][2][5:], [1])
        self.assertEqual(trees[8][1][5:], [])

    def test_a_talent_needing_two_stops_the_build(self):
        with self.assertRaises(SystemExit):
            self.read([(1, (1, 1, 1)), (2, (1, 2, 1)), (3, (1, 1, 3))], [(1, 3), (2, 3)])


if __name__ == "__main__":
    unittest.main()
