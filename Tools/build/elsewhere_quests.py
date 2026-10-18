"""Build Tools/data/completo_elsewhere.json: the quests no zone page lists and the Dungeon Journal
does not have, for the Quest List's map pins.

Wowhead files class quests under the class, and dungeon, raid and battleground quests under the
instance, so Tools/build/completo_quests.py, which reads the zones, has none of them, and
Tools/build/dungeon_quests.py only the Journal's. This adds the rest from what allows it:

- Which quests: CMaNGOS's Classic world database (read as dungeon_quests.py reads it), each
  quest with a giver, kept only if Forever's client has it (wago.tools' QuestV2).
- Where: the start on the quest's own Wowhead Forever page, else the giver's spot from another
  quest it gives. Both are kept in Tools/data/completo_quests.json, the same cache
  completo_quests.py fills; a quest whose giver has no spot there has its own page fetched, at
  completo_quests.py's pace. The first page that fails stops the fetching, so a run Wowhead turns
  away ends there and the next one goes on. A quest with no spot either way is left out:
  CMaNGOS's spawn positions cannot tell which zone's map a giver near a border is on.
- Holiday and event quests (seasonal, Darkmoon Faire, the Ahn'Qiraj War) are left out, as are
  profession quests: nothing tells the addon your professions, so each would pin for everyone.

The JSON is committed; completo_quests.py reads it, so `completo_quests.py --offline` writes the
addon's data from it.

Usage: python Tools/build/elsewhere_quests.py [--offline]
"""
import json
import sys
import time
import urllib.error
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
import completo_quests  # noqa: E402
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


def spot_of(start):
    """(uiMapID, x, y, giver) from a quest page's start, or None."""
    if not (start and start.get("coord") and start["zone"] in ZONE_MAP):
        return None
    m = ZONE_MAP[start["zone"]]
    x, y = forever_spot(m, *start["coord"])
    return m, round(x, 1), round(y, 1), start["npc"]


def main():
    offline = "--offline" in sys.argv
    data, quests, _, after = dungeon_quests.cmangos()
    in_forever = {int(r["ID"]) for r in wago.table("QuestV2")}
    sorts = {-int(r["ID"]): r["SortName_lang"] for r in wago.table("QuestSort")}
    have = {q["id"] for z in completo_quests.load(ZONES).values() for q in z["quests"]} | {int(k) for k in completo_quests.load(DUNGEON)["quests"]}
    pages = completo_quests.load(QUESTS)

    npcs = {}
    for r in data["creature_questrelation"]:
        npcs.setdefault(int(r["quest"]), []).append(int(r["id"]))
    for r in data["gameobject_questrelation"]:
        npcs.setdefault(int(r["quest"]), [])

    wanted, skipped = [], Counter()
    for qid in sorted(npcs):
        q = quests.get(qid)
        if not q or qid in have or qid not in in_forever or PLACEHOLDER.search(q["Title"]):
            continue
        sort = int(q["ZoneOrSort"])
        if sort < 0 and sorts.get(sort) not in KEPT_SORTS:
            skipped[sorts.get(sort, sort)] += 1
            continue
        wanted.append(qid)

    def giver_spots():
        spots = {}
        for entry in pages.values():
            spot = spot_of(entry and entry.get("start"))
            if spot and entry["start"].get("npcId"):
                spots.setdefault(entry["start"].get("npcId"), set()).add(spot)
        return spots

    # A quest whose giver has no spot yet has its own page fetched, which says where it starts.
    spots = giver_spots()
    todo = [i for i in wanted if str(i) not in pages and not any(spots.get(n) for n in npcs[i])]
    print(f"{len(wanted)} quests, {len(todo)} quest pages to fetch")
    if not offline:
        for n, qid in enumerate(todo, 1):
            try:
                pages[str(qid)] = completo_quests.fetch_quest(qid)
            except (urllib.error.HTTPError, ValueError) as e:
                print(f"quest {qid}: {e}; stopping, run again later to go on", file=sys.stderr)
                break
            completo_quests.save(QUESTS, pages)
            if n % 50 == 0:
                print(f"  {n}/{len(todo)}")
            time.sleep(completo_quests.GAP)
        spots = giver_spots()

    out = {}
    for qid in wanted:
        q = quests[qid]
        own = spot_of((pages.get(str(qid)) or {}).get("start"))
        found = {own} if own else set().union(*(spots.get(n, set()) for n in npcs[qid]))
        if len(found) != 1:
            skipped["no giver spot" if not found else "giver in more than one spot"] += 1
            continue
        m, x, y, giver = found.pop()
        sort = int(q["ZoneOrSort"])
        side, races = dungeon_quests.side_of(int(q["RequiredRaces"]))
        out[str(qid)] = {"name": q["Title"], "level": int(q["QuestLevel"]), "reqlevel": int(q["MinLevel"]),
                         "side": side, "reqrace": races, "reqclass": int(q["RequiredClasses"]),
                         "after": sorted(after.get(qid, ())), "map": m, "x": x, "y": y, "giver": giver,
                         "dungeon": sort > 0 and sort not in ZONE_MAP}

    OUT.write_text(json.dumps({"cmangos": dungeon_quests.COMMIT, "build": wago.BUILD, "quests": out},
                              indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\r\n")
    kinds = Counter("dungeon" if d["dungeon"] else "other" for d in out.values())
    print(f"wrote {OUT.relative_to(paths.ROOT)}: {len(out)} quests ({kinds['dungeon']} dungeon, {kinds['other']} other)")
    for reason, n in skipped.most_common():
        print(f"  left out {n}: {reason}")


if __name__ == "__main__":
    main()
