"""Build Tools/data/completo_elsewhere.json: the quests no zone page lists and the Dungeon Journal
does not have, for the Quest List's map pins.

Wowhead files class quests under the class, and dungeon, raid and battleground quests under the
instance, so Tools/build/completo_quests.py, which reads the zones, has none of them, and
Tools/build/dungeon_quests.py only the Journal's. This adds the rest from what allows it:

- Which quests: CMaNGOS's Classic world database (read as dungeon_quests.py reads it), each
  quest with a creature giver, kept only if Forever's client has it (wago.tools' QuestV2).
- Where: the giver's own spot on Wowhead's Forever pages, from another quest it gives
  (Tools/data/completo_quests.json). A quest whose giver gives no quest we have a spot for is left
  out: CMaNGOS's spawn positions cannot tell which zone's map a giver near a border is on.
- Holiday and event quests (seasonal, Darkmoon Faire, the Ahn'Qiraj War) are left out, as are
  profession quests: nothing tells the addon your professions, so each would pin for everyone.

The JSON is committed; completo_quests.py reads it, so `completo_quests.py --offline` writes the
addon's data from it.

Usage: python Tools/build/elsewhere_quests.py
"""
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
import dungeon_quests  # noqa: E402
from completo_quests import PLACEHOLDER, forever_spot  # noqa: E402
from quest_chains import ZONE_MAP  # noqa: E402

OUT = paths.DATA / "completo_elsewhere.json"
QUESTS = paths.DATA / "completo_quests.json"
ZONES = paths.DATA / "completo_zones.json"
DUNGEON = paths.DATA / "completo_dungeon.json"
# The quest sorts (QuestSort) kept: the classes, and the few that are neither holiday, event nor
# profession.
KEPT_SORTS = {"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid",
              "Reputation", "Epic", "Legendary"}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    data, quests, _, after = dungeon_quests.cmangos()
    in_forever = {int(r["ID"]) for r in wago.table("QuestV2")}
    sorts = {-int(r["ID"]): r["SortName_lang"] for r in wago.table("QuestSort")}
    have = {q["id"] for z in load(ZONES).values() for q in z["quests"]} | {int(k) for k in load(DUNGEON)["quests"]}

    spots = {}
    for entry in load(QUESTS).values():
        start = entry and entry.get("start")
        if start and start.get("npcId") and start.get("coord") and start["zone"] in ZONE_MAP:
            m = ZONE_MAP[start["zone"]]
            x, y = forever_spot(m, *start["coord"])
            spots.setdefault(start["npcId"], set()).add((m, round(x, 1), round(y, 1), start["npc"]))
    npcs = {}
    for r in data["creature_questrelation"]:
        npcs.setdefault(int(r["quest"]), []).append(int(r["id"]))

    out, skipped = {}, Counter()
    for qid, npc_ids in sorted(npcs.items()):
        q = quests.get(qid)
        if not q or qid in have or qid not in in_forever or PLACEHOLDER.search(q["Title"]):
            continue
        sort = int(q["ZoneOrSort"])
        if sort < 0 and sorts.get(sort) not in KEPT_SORTS:
            skipped[sorts.get(sort, sort)] += 1
            continue
        found = set().union(*(spots.get(n, set()) for n in npc_ids))
        if len(found) != 1:
            skipped["no giver spot" if not found else "giver in more than one spot"] += 1
            continue
        m, x, y, giver = found.pop()
        side, races = dungeon_quests.side_of(int(q["RequiredRaces"]))
        out[str(qid)] = {"name": q["Title"], "level": int(q["QuestLevel"]), "reqlevel": int(q["MinLevel"]),
                         "side": side, "reqrace": races, "reqclass": int(q["RequiredClasses"]),
                         "after": sorted(after.get(qid, ())), "map": m, "x": x, "y": y, "giver": giver,
                         "dungeon": sort > 0 and sort not in ZONE_MAP}

    OUT.write_text(json.dumps({"cmangos": dungeon_quests.COMMIT, "build": wago.BUILD, "quests": out},
                              indent=1, sort_keys=True) + "\n", encoding="utf-8")
    kinds = Counter("dungeon" if d["dungeon"] else "other" for d in out.values())
    print(f"wrote {OUT.relative_to(paths.ROOT)}: {len(out)} quests ({kinds['dungeon']} dungeon, {kinds['other']} other)")
    for reason, n in skipped.most_common():
        print(f"  left out {n}: {reason}")


if __name__ == "__main__":
    main()
