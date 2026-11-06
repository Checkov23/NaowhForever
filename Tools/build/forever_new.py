"""What is new in WoW Forever: the items, quests and NPCs not in the original game, for the
addon's Forever mark (Shared/Data/Forever.lua).

An item or quest is new when Forever's own table has it (ItemSparse, QuestV2: wago.BUILD's
with its hotfixes, and CARRY_FROM's, through wago.py) and Classic Era's (CLASSIC_ERA) does
not. A quest Forever reworked keeps its classic ID, so it is not new (Friend of the Library,
78150). A new quest Forever's table lacks goes unmarked (Applejack Still, 91736).

The game has no table of its NPCs, so those are the ones Wowhead's Forever database marks as
new. Wowhead lists a thousand rows a page at most, so they are read by ID range, a range
split in two whenever it comes back full, and only "new" rows are kept (not "updated" or
"unchanged").

Only the IDs the addon's own data mentions are written, so the file stays small. Answers are
cached in Tools/data/forever_new.json; pass --refresh to read the game's tables again (when
wago.BUILD moves on). Wowhead is asked only when the cache has no NPCs.

Run from the repo root: python Tools/build/forever_new.py [--refresh]
"""
import glob
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
from wowhead import WOWHEAD, fetch  # noqa: E402

ROOT = paths.ROOT
CACHE = paths.DATA / "forever_new.json"
OUT = os.path.join(ROOT, "Shared", "Data", "Forever.lua")
CLASSIC_ERA = "1.15.9.70576"   # the Classic Era build Forever's tables are compared with
# Wowhead shows a thousand rows at most, a few of them without a status: a page this full may
# have more past it, so its range is split.
FULL = 900

# Each kind: the game's table it is read from, or Wowhead's list page with the listview's
# filter on ID and the highest ID to read; and the addon's files that mention it.
KINDS = {
    "items": {"table": "ItemSparse", "files": [
        "NaowhForever_DungeonJournal/Data/Items.lua", "NaowhForever_DungeonJournal/Data/Dungeons/*.lua",
        "Shared/Data/ItemFacts.lua", "Shared/Data/FactionItems.lua", "NaowhForever_DungeonJournal/Data/Factions/*.lua",
        "NaowhForever_DungeonJournal/Data/BiSQuests.lua", "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_BiS/BiS/Data/*.lua"]},
    "quests": {"table": "QuestV2", "files": [
        "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_DungeonJournal/Data/QuestChains.lua",
        "NaowhForever_DungeonJournal/Data/BiSQuests.lua"]},
    "npcs": {"page": "npcs", "filter": 37, "top": 400000, "files": ["NaowhForever_DungeonJournal/Data/Dungeons/*.lua"]},
}

# A row of a listview, items' (JavaScript) or the others' (JSON): its ID, then its status,
# with no other row's ID in between.
ROW = re.compile(r'"id":(\d+),(?:(?!"id":\d).)*?"envChange":\{"status":"(\w+)"', re.S)


def rows(page, name):
    start = max(page.find(f"id: '{name}'"), page.find(f'"id":"{name}"'))
    data = page.rfind("var listview" + name, 0, start) if start >= 0 else -1
    if data < 0:   # the data inline, after the listview's id
        data = start
    end = page.find("</script>", data)
    return [(int(i), status) for i, status in ROW.findall(page[data:end])] if data >= 0 else []


def read(kind, low, high, found):
    spec = KINDS[kind]
    f = spec["filter"]
    page = fetch(f"{WOWHEAD}/{spec['page']}?filter={f}:{f};2:4;{low}:{high}")
    # Only the rows in the range: past the IDs Wowhead's filter takes (a quest's stops at
    # 100000), it ignores the filter and lists its usual first page instead.
    got = [(i, status) for i, status in rows(page, spec["page"]) if low <= i <= high]
    if len(got) >= FULL and high > low:
        mid = (low + high) // 2
        read(kind, low, mid, found)
        read(kind, mid + 1, high, found)
        return
    print(f"  {kind} {low}-{high}: {len(got)}, {sum(1 for _, s in got if s == 'new')} new", file=sys.stderr)
    found.extend(i for i, status in got if status == "new")


def new_in_table(name):
    """The IDs in Forever's table (CARRY_FROM's too, while wago.BUILD's hotfixes come in) that
    Classic Era's lacks, sorted."""
    forever = set()
    for build in (wago.CARRY_FROM, wago.BUILD):
        if build:
            forever.update(row["ID"] for row in wago.table(name, build))
    classic = {row["ID"] for row in wago.table(name, CLASSIC_ERA)}
    return sorted(int(i) for i in forever - classic)


def mentioned(patterns):
    ids = set()
    for pattern in patterns:
        for path in glob.glob(os.path.join(ROOT, pattern)):
            with open(path, encoding="utf-8") as fh:
                ids.update(int(n) for n in re.findall(r"\b\d{2,6}\b", fh.read()))
    return ids


def lua_set(ids):
    lines, line = [], "       "
    for i in sorted(ids):
        part = f" [{i}] = true,"
        if len(line) + len(part) > 100:
            lines.append(line)
            line = "       "
        line += part
    if line.strip():
        lines.append(line)
    return "\n".join(lines)


def main():
    cache = {}
    if os.path.exists(CACHE):
        with open(CACHE, encoding="utf-8") as fh:
            cache = json.load(fh)
    for kind, spec in KINDS.items():
        if kind in cache and not ("table" in spec and "--refresh" in sys.argv):
            continue
        if "table" in spec:
            cache[kind] = new_in_table(spec["table"])
        else:
            found = []
            read(kind, 1, spec["top"], found)
            cache[kind] = sorted(set(found))
        with open(CACHE, "w", encoding="utf-8") as fh:
            json.dump(cache, fh, indent=1)
    out = ["-- Forever.lua: what is new in WoW Forever, by ID, generated by Tools/build/forever_new.py.",
           "local ns = _G.NaowhForever", "", "ns.Shared.ForeverNew = {"]
    for kind, spec in KINDS.items():
        keep = set(cache[kind]) & mentioned(spec["files"])
        print(f"{kind}: {len(cache[kind])} new in Forever, {len(keep)} of them in the addon's data")
        out += [f"    {kind} = {{", lua_set(keep), "    },"]
    out.append("}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="ascii", newline="\r\n") as fh:
        fh.write("\n".join(out) + "\n")
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
