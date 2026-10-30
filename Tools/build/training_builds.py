"""Build the Training Planner's talent trees: every talent of each class, where it sits and what it needs.

From Wowhead Forever's talent calculator data, which carries the beta's hotfixes before the game's own
talent tables do (on 1.60.1.70685 the tables still had Mage's old Arcane Focus, Incineration and
Critical Mass): per tree, each talent's row, column, rank spells and the talent it needs. A talent
needs the other at full rank; one needing two, or a part rank, stops the build, as the file holds
one full-rank need.

The talent IDs are the game's TraitNode IDs, which C_Traits buys ranks in and which the Naowh site's
build strings carry (naowh.gg/talents/forever). Run it again when a patch or hotfix changes a tree.

Writes NaowhForever_Training/Data/TrainingBuilds.lua: per class, its trees' names and
[node] = { first rank's spell, ranks, row, tree, column[, the node it needs] }.

Usage: python Tools/build/training_builds.py
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
from journal import ROOT, header, write  # noqa: E402
from training import CLASSES  # noqa: E402
from wowhead import talent_calculator  # noqa: E402

OUT = ROOT / "NaowhForever_Training" / "Data" / "TrainingBuilds.lua"
# Each class's three trees left to right (Wowhead's tree IDs), and the names the addon shows for them:
# saved builds carry the name of the tree they spend most in, so these stay as players have seen them.
TREES = {
    1: ((161, 164, 163), ("Arms", "Fury", "Protection")),
    2: ((382, 383, 381), ("Holy", "Protection", "Retribution")),
    3: ((361, 363, 362), ("Beast Mastery", "Marksmanship", "Survival")),
    4: ((182, 181, 183), ("Assassination", "Combat", "Subtlety")),
    5: ((201, 202, 203), ("Discipline", "Holy", "Shadow Magic")),
    7: ((261, 263, 262), ("Elemental Combat", "Enhancement", "Restoration")),
    8: ((81, 41, 61), ("Arcane", "Fire", "Frost")),
    9: ((302, 303, 301), ("Affliction", "Demonology", "Destruction")),
    11: ((283, 281, 282), ("Balance", "Feral Combat", "Restoration")),
}


def class_trees(talents):
    """Class ID -> node ID -> [spell, ranks, row, tree, column(, needs)], rows and columns from 1."""
    out = {}
    for class_id, (tree_ids, _) in TREES.items():
        tree_talents = {}
        for tree_id in tree_ids:
            if str(tree_id) not in talents:
                raise SystemExit(f"{CLASSES[class_id]}: Wowhead has no tree {tree_id}")
            tree_talents.update(talents[str(tree_id)])
        nodes = {}
        for tree, tree_id in enumerate(tree_ids, 1):
            for talent in talents[str(tree_id)].values():
                node = [talent["ranks"][0], len(talent["ranks"]), talent["row"] + 1, tree, talent["col"] + 1]
                needs = talent["requires"]
                if len(needs) > 1:
                    raise SystemExit(f"{CLASSES[class_id]} {talent['id']}: needs {len(needs)} talents, the file holds one")
                for need in needs:
                    if need["qty"] != len(tree_talents[str(need["id"])]["ranks"]):
                        raise SystemExit(f"{CLASSES[class_id]} {talent['id']}: needs {need['qty']} points in "
                                         f"{need['id']}, the file holds a full-rank need")
                    node.append(need["id"])
                nodes[talent["id"]] = node
        out[class_id] = nodes
    return out


def build():
    trees = class_trees(talent_calculator()["talents"])
    out = header("TrainingBuilds.lua", "each class's talent tree, from Wowhead Forever's talent calculator")
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


def main():
    argparse.ArgumentParser(description=__doc__.split("\n")[0]).parse_args()
    build()


if __name__ == "__main__":
    main()
