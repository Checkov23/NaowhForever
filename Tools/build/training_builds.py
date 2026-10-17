"""Build the Training Planner's talent trees: every talent of each class, where it sits and what it needs.

From the game's own talent tables (Tools/sources/wago.py), the same ones the talent frame reads:
TraitNode places each talent (one tree per class, its three talent trees side by side),
TraitNodeEntry and TraitDefinition give its first rank's spell and its ranks, and TraitEdge the
arrows between talents. A talent needs, at full rank, the one an arrow joins it to on the row
above: across rows the table's two ends say nothing of which needs which, so the rows do; on one
row (Divine Precision, Improved Mind Flay) the talent at the arrow's right end needs the left one.
The game parks talents it no longer uses outside the grid (Hunter's Lightning Reflexes); those
are left out.

The node IDs are the game's TraitNode IDs, which C_Traits buys ranks in and which the Naowh site's
build strings carry (naowh.gg/talents/forever). Run it again when a patch changes a tree.

Writes NaowhForever_Training/Data/TrainingBuilds.lua: per class, its trees' names and
[node] = { first rank's spell, ranks, row, tree, column[, the node it needs] }.

Usage: python Tools/build/training_builds.py [--build 1.60.1.70425]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import wago  # noqa: E402
from journal import ROOT, header, write  # noqa: E402
from training import CLASSES  # noqa: E402

OUT = ROOT / "NaowhForever_Training" / "Data" / "TrainingBuilds.lua"
# Each class's talent tree (TraitTree), and the names the addon shows for its three trees: saved
# builds carry the name of the tree they spend most in, so these stay as players have seen them.
TREES = {
    1: (1117, ("Arms", "Fury", "Protection")),
    2: (1100, ("Holy", "Protection", "Retribution")),
    3: (1091, ("Beast Mastery", "Marksmanship", "Survival")),
    4: (1111, ("Assassination", "Combat", "Subtlety")),
    5: (1114, ("Discipline", "Holy", "Shadow Magic")),
    7: (1082, ("Elemental Combat", "Enhancement", "Restoration")),
    8: (1112, ("Arcane", "Fire", "Frost")),
    9: (1116, ("Affliction", "Demonology", "Destruction")),
    11: (1089, ("Balance", "Feral Combat", "Restoration")),
}
# Where the talent frame puts things, in TraitNode units: talents a grid step apart, the first
# tree's first column and the first row at these, each next tree this far to the right.
GRID = 600
FIRST_X, FIRST_Y = 1020, 2130
TREE_X = 4000
ROWS, COLUMNS = 7, 4


def place(node):
    """(row, tree, column), each from 1, or None for a talent parked outside the grid."""
    x, y = int(node["PosX"]), int(node["PosY"])
    tree = round((x - FIRST_X) / TREE_X) + 1
    column = round((x - FIRST_X - (tree - 1) * TREE_X) / GRID) + 1
    row = round((y - FIRST_Y) / GRID) + 1
    if 1 <= tree <= 3 and 1 <= column <= COLUMNS and 1 <= row <= ROWS:
        return row, tree, column
    return None


def class_trees(build_id):
    """Class ID -> node ID -> [spell, ranks, row, tree, column(, needs)], and the parked talents."""
    entries = {}
    for row in wago.table("TraitNodeXTraitNodeEntry", build_id):
        entries.setdefault(row["TraitNodeID"], []).append((int(row["_Index"]), row["TraitNodeEntryID"]))
    entry = {row["ID"]: row for row in wago.table("TraitNodeEntry", build_id)}
    spell = {row["ID"]: int(row["SpellID"]) for row in wago.table("TraitDefinition", build_id)}
    by_tree = {}
    for row in wago.table("TraitNode", build_id):
        by_tree.setdefault(int(row["TraitTreeID"]), {})[row["ID"]] = row
    edges = [(int(row["LeftTraitNodeID"]), int(row["RightTraitNodeID"]))
             for row in wago.table("TraitEdge", build_id)]

    out, parked = {}, []
    for class_id, (tree_id, _) in TREES.items():
        nodes = by_tree.get(tree_id)
        if not nodes:
            raise SystemExit(f"{CLASSES[class_id]}: no talents in tree {tree_id} in build {build_id}")
        talents = {}
        for node_id, node in nodes.items():
            at = place(node)
            if not at:
                parked.append(f"{CLASSES[class_id]} {node_id}")
                continue
            first = min(entries.get(node_id, []), default=None)
            if not first:
                raise SystemExit(f"{CLASSES[class_id]} {node_id}: a talent without an entry")
            e = entry[first[1]]
            talents[int(node_id)] = [spell[e["TraitDefinitionID"]], int(e["MaxRanks"]), *at]
        needs = {}
        for left, right in edges:
            if left in talents and right in talents:
                need, of = (right, left) if talents[right][2] < talents[left][2] else (left, right)
                needs.setdefault(of, set()).add(need)
        for node_id, talent in talents.items():
            above = sorted(needs.get(node_id, ()))
            if len(above) > 1:
                raise SystemExit(f"{CLASSES[class_id]} {node_id}: needs {above}, the file holds one")
            talent.extend(above)
        out[class_id] = talents
    return out, parked


def build(build_id):
    trees, parked = class_trees(build_id)
    out = header("TrainingBuilds.lua", f"each class's talent tree, built from game build {build_id}")
    out.append("ns.TrainingBuilds = {")
    counts = []
    for class_id, talents in trees.items():
        names = ", ".join(f'"{n}"' for n in TREES[class_id][1])
        out += [f"    [{class_id}] = {{", f"        specs = {{ {names} }},", "        talents = {"]
        for node_id in sorted(talents):
            out.append(f"            [{node_id}] = {{ {', '.join(str(v) for v in talents[node_id])} }},")
        out += ["        },", "    },"]
        counts.append(f"{CLASSES[class_id]} {len(talents)}")
    out.append("}")
    write(OUT, out)
    print(f"Wrote {OUT.relative_to(ROOT)}: " + ", ".join(counts))
    if parked:
        print("Left out, parked outside the grid: " + ", ".join(parked))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--build", default=wago.BUILD, help="the Forever build to read (default: wago.BUILD)")
    build(parser.parse_args().build)


if __name__ == "__main__":
    main()
