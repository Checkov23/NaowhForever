"""Build the Training Planner's talent trees: every talent of each class, where it sits and what it needs.

From the game's own talent tables with the build's hotfixes (Tools/sources/wago.py), the same ones the
talent frame reads: TraitNode places each talent (one tree per class, its three talent trees side by
side), TraitNodeEntry and TraitDefinition give its first rank's spell and its ranks, and TraitEdge the
arrows between talents. A talent needs, at full rank, the one an arrow joins it to on the row above:
across rows the table's two ends say nothing of which needs which, so the rows do; on one row (Divine
Precision, Improved Mind Flay) the talent at the arrow's right end needs the left one. The game parks
talents it no longer uses outside the grid (Hunter's Lightning Reflexes); those are left out.

Forever's trees change by hotfix, so read the build whose hotfixes wago.tools has. From 1.60.1.70685
to 70707 this read Wowhead's talent calculator instead, while wago.tools lagged; on the 3 November
2026 Rogue and Fury rework the calculator was the one behind.

The talent IDs are the game's TraitNode IDs, which C_Traits buys ranks in and which the Naowh site's
build strings carry (naowh.gg/talents/forever). Run it again when a patch or hotfix changes a tree.

Writes NaowhForever_Training/Data/TrainingBuilds.lua: per class, its trees' names, its revision,
replaced and [node] = { first rank's spell, ranks, row, tree, column[, the node it needs] }. The
revision goes up by one each time the class's tree changes; replaced lists each node that came in or
took another talent then, with the revision it did. Saved builds carry the revision they were made
on, and the addon drops their points in nodes replaced since (Blizzard reuses a node for a new talent).

Usage: python Tools/build/training_builds.py [--build 1.60.1.70707]
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import wago  # noqa: E402
from journal import ROOT, header, write  # noqa: E402

OUT = ROOT / "NaowhForever_Training" / "Data" / "TrainingBuilds.lua"
# The game's class IDs and Wowhead's names for them.
CLASSES = {1: "warrior", 2: "paladin", 3: "hunter", 4: "rogue", 5: "priest", 7: "shaman", 8: "mage",
           9: "warlock", 11: "druid"}
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


def previous(text):
    """What the last TrainingBuilds.lua held: class ID -> (revision, replaced, node -> its fields)."""
    out, class_id = {}, None
    for line in text.splitlines():
        if m := re.match(r"    \[(\d+)\] = \{$", line):
            class_id = int(m.group(1))
            out[class_id] = (0, {}, {})
        elif m := re.match(r"        rev = (\d+),$", line):
            out[class_id] = (int(m.group(1)), out[class_id][1], out[class_id][2])
        elif m := re.match(r"        replaced = \{(.*)\},$", line):
            out[class_id][1].update({int(n): int(r) for n, r in re.findall(r"\[(\d+)\] = (\d+)", m.group(1))})
        elif m := re.match(r"            \[(\d+)\] = \{ ([\d, ]+) \},$", line):
            out[class_id][2][int(m.group(1))] = [int(v) for v in m.group(2).split(", ")]
    return out


def revisions(old, trees):
    """Class ID -> (revision, replaced): the same as before while a class's tree is unchanged, else one
    up, with each node that is new or holds another talent replaced at it."""
    out = {}
    for class_id, talents in trees.items():
        rev, replaced, before = old.get(class_id, (0, {}, {}))
        if rev and talents == before:
            out[class_id] = (rev, replaced)
            continue
        rev += 1
        replaced = {node: r for node, r in replaced.items() if node in talents}
        for node, talent in talents.items():
            if node not in before or before[node][0] != talent[0]:
                replaced[node] = rev
        out[class_id] = (rev, replaced)
    return out


def build(build_id):
    trees, parked = class_trees(build_id)
    revs = revisions(previous(OUT.read_text(encoding="ascii")) if OUT.exists() else {}, trees)
    out = header("TrainingBuilds.lua", f"each class's talent tree, built from game build {build_id}")
    out.append("ns.TrainingBuilds = {")
    counts = []
    for class_id, talents in trees.items():
        names = ", ".join(f'"{n}"' for n in TREES[class_id][1])
        rev, replaced = revs[class_id]
        moved = ", ".join(f"[{node}] = {r}" for node, r in sorted(replaced.items()))
        out += [f"    [{class_id}] = {{", f"        specs = {{ {names} }},", f"        rev = {rev},",
                f"        replaced = {{ {moved} }}," if moved else "        replaced = {},", "        talents = {"]
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
