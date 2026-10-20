"""Build Tools/data/completo_elsewhere.json: the quests no zone page lists and the Dungeon Journal
does not have, for the Quest List's map pins.

Wowhead files class quests under the class, and dungeon, raid and battleground quests under the
instance, so Tools/build/completo_quests.py, which reads the zones, has none of them, and
Tools/build/dungeon_quests.py only the Journal's. This adds the rest from what allows it:

- Which quests: CMaNGOS's Classic world database (read as dungeon_quests.py reads it), each
  quest with a giver, kept only if Forever's client has it (wago.tools' QuestV2).
- Where: the start on the quest's own Wowhead Forever page, else the giver's spot from another
  quest it gives. Both are kept in Tools/data/completo_quests.json, the same cache
  completo_quests.py fills; a quest whose giver has no spot there has its own page fetched, one
  every GAP seconds. The first page that fails stops the fetching, so a run Wowhead turns
  away ends there and the next one goes on.
- Else where the game client puts the giver's spawn (CMaNGOS's full dump, on the two
  continents). Spawn positions alone cannot tell which zone's map a giver near a border is on,
  but the client can: --positions writes the ones not resolved yet to
  Tools/dev/QuestPositions/Positions.lua, for the QuestPositions addon there to resolve in game
  (its README), and --resolved reads its SavedVariables file into
  Tools/data/completo_positions.json. The client misses too along zone borders, so its answer is
  taken only where the zone rectangles (UiMapAssignment) pick the same map: the smallest one the
  spawn is at least EDGE map percent inside, else the smallest, and only on the map. A giver is
  placed this way only when every spawn of it is, and not when they land on more than one map or
  stand apart on one. Each run says how often that agrees with Wowhead on the givers both place.
- Holiday and event quests (seasonal, Darkmoon Faire, the Ahn'Qiraj War) are left out, as are
  profession quests: nothing tells the addon your professions, so each would pin for everyone.

The JSON is committed; completo_quests.py reads it, so `completo_quests.py --offline` writes the
addon's data from it.

Usage: python Tools/build/elsewhere_quests.py [--offline] [--positions] [--resolved <SavedVariables/QuestPositions.lua>]
"""
import argparse
import json
import math
import re
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
POSITIONS = paths.DATA / "completo_positions.json"
RESOLVER = paths.TOOLS / "dev" / "QuestPositions" / "Positions.lua"
# Twice completo_quests.py's gap, for the runs on GitHub's runners.
GAP = 8
# The quest sorts (QuestSort) kept: the classes, and the few that are neither holiday, event nor
# profession.
KEPT_SORTS = {"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid",
              "Reputation", "Epic", "Legendary"}
# The battleground areas (AreaTable) CMaNGOS sorts quests under: Alterac Valley, the Alterac Valley
# area in the Alterac Mountains outside it, Warsong Gulch and Arathi Basin. Their quests are
# instance quests, but not dungeon or raid ones.
BATTLEGROUNDS = {2597, 2839, 3277, 3358}
CONTINENTS = {"0", "1"}   # Eastern Kingdoms and Kalimdor, as CMaNGOS and C_Map number them
ZONE_MAPS = set(ZONE_MAP.values())
# A giver Wowhead places that has more spawns than this is left out of the agreement check.
CHECK_SPAWNS = 3
CLOSE = 1.5   # map percent within which the client's spot and Wowhead's agree
SAME_SPOT = 3   # map percent within which a giver's spawns on one map count as one spot
EDGE = 5   # map percent a spawn must be inside a zone's rectangle to count as well inside it
RESULT = re.compile(r'"([^"=]+)=(?:(\d+),(-?[\d.]+),(-?[\d.]+))?"')


def spot_of(start):
    """(uiMapID, x, y, giver) from a quest page's start, or None."""
    if not (start and start.get("coord") and start["zone"] in ZONE_MAP):
        return None
    m = ZONE_MAP[start["zone"]]
    x, y = forever_spot(m, *start["coord"])
    return m, round(x, 1), round(y, 1), start["npc"]


def spawn_key(row):
    return f"{row['map']},{float(row['position_x']):.1f},{float(row['position_y']):.1f}"


def read_resolved(text):
    """{ position: [uiMapID, x, y], or None where the client placed it on no zone } from the
    QuestPositions addon's SavedVariables file."""
    return {m.group(1): [int(m.group(2)), float(m.group(3)), float(m.group(4))] if m.group(2) else None
            for m in RESULT.finditer(text)}


def client_spots(npc_ids, spawns, positions, names):
    """{ (uiMapID, x, y, giver) } where the client puts the givers' spawns: one spot per zone map
    while they stand together there, else each, as more than one spot."""
    by_map = {}
    for n in npc_ids:
        for key in spawns.get(n, ()):
            spot = positions.get(key)
            if spot and spot[0] in ZONE_MAPS:
                by_map.setdefault(spot[0], []).append((spot[0], round(spot[1], 1), round(spot[2], 1), names.get(n)))
    found = set()
    for spots in by_map.values():
        first = spots[0]
        together = all(math.hypot(s[1] - first[1], s[2] - first[2]) <= SAME_SPOT for s in spots)
        found.update([first] if together else spots)
    return found


def zone_rects():
    """[(uiMapID, continent, minX, minY, maxX, maxY, uiMin, uiMax)]: each zone map's place in the world."""
    rects = []
    for r in wago.table("UiMapAssignment"):
        if int(r["UiMapID"]) in ZONE_MAPS:
            rects.append((int(r["UiMapID"]), r["MapID"], float(r["Region_0"]), float(r["Region_1"]),
                          float(r["Region_3"]), float(r["Region_4"]),
                          (float(r["UiMin_0"]), float(r["UiMin_1"])), (float(r["UiMax_0"]), float(r["UiMax_1"]))))
    return rects


def geometry_map(key, rects):
    """The zone map the rectangles pick for a spawn: the smallest it is at least EDGE map percent
    inside, else the smallest that holds it; None when none does."""
    c, wx, wy = key.split(",")
    wx, wy = float(wx), float(wy)
    best = None
    for ui, continent, x0, y0, x1, y1, (u0, v0), (u1, v1) in rects:
        if continent != c or not (x0 <= wx <= x1 and y0 <= wy <= y1):
            continue
        # A map's x runs along the world's Y axis from its max down, its y along X from its max down.
        px = (u0 + (y1 - wy) / (y1 - y0) * (u1 - u0)) * 100
        py = (v0 + (x1 - wx) / (x1 - x0) * (v1 - v0)) * 100
        rank = (min(px, 100 - px, py, 100 - py) < EDGE, (x1 - x0) * (y1 - y0))
        if best is None or rank < best[0]:
            best = (rank, ui)
    return best and best[1]


def write_resolver(keys):
    lines = ["-- Positions.lua: the giver spawns QuestPositions resolves, generated by Tools/build/elsewhere_quests.py.",
             "local _, T = ...", "", "T.positions = {"]
    lines += [f'    "{key}",' for key in sorted(keys)]
    lines.append("}")
    RESOLVER.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))


def main():
    parser = argparse.ArgumentParser(description="The quests no zone page lists, for the Quest List.")
    parser.add_argument("--offline", action="store_true", help="fetch no Wowhead pages")
    parser.add_argument("--positions", action="store_true",
                        help="write the spawns not resolved yet for the QuestPositions addon")
    parser.add_argument("--resolved", metavar="FILE", help="the QuestPositions addon's SavedVariables file")
    args = parser.parse_args()
    data, quests, _, after = dungeon_quests.cmangos()
    in_forever = {int(r["ID"]) for r in wago.table("QuestV2")}
    sorts = {-int(r["ID"]): r["SortName_lang"] for r in wago.table("QuestSort")}
    have = {q["id"] for z in completo_quests.load(ZONES).values() for q in z["quests"]} | {int(k) for k in completo_quests.load(DUNGEON)["quests"]}
    pages = completo_quests.load(QUESTS)
    positions = completo_quests.load(POSITIONS)
    if args.resolved:
        positions.update(read_resolved(Path(args.resolved).read_text(encoding="utf-8")))
        completo_quests.save(POSITIONS, positions)
    rects = zone_rects()
    confident = {k: v for k, v in positions.items()
                 if v and 0 <= v[1] <= 100 and 0 <= v[2] <= 100 and geometry_map(k, rects) == v[0]}
    names = {int(r["Entry"]): r["Name"] for r in data["creature_template"]}
    spawns = {}
    for r in data["creature"]:
        if r["map"] in CONTINENTS:
            spawns.setdefault(int(r["id"]), []).append(spawn_key(r))

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
    if not args.offline:
        for n, qid in enumerate(todo, 1):
            try:
                pages[str(qid)] = completo_quests.fetch_quest(qid)
            except (urllib.error.HTTPError, ValueError) as e:
                print(f"quest {qid}: {e}; stopping, run again later to go on", file=sys.stderr)
                break
            completo_quests.save(QUESTS, pages)
            if n % 50 == 0:
                print(f"  {n}/{len(todo)}")
            time.sleep(GAP)
        spots = giver_spots()

    # The givers Wowhead places that the client resolves too, to see how often the answers taken agree.
    check = {n: next(iter(s)) for n, s in spots.items() if len(s) == 1 and 0 < len(spawns.get(n, ())) <= CHECK_SPAWNS}
    needed = {key for n in check for key in spawns[n]}

    out, by_client = {}, 0
    for qid in wanted:
        q = quests[qid]
        own = spot_of((pages.get(str(qid)) or {}).get("start"))
        found = {own} if own else set().union(*(spots.get(n, set()) for n in npcs[qid]))
        if not found:
            keys = [key for n in npcs[qid] for key in spawns.get(n, ())]
            needed.update(keys)
            if any(key not in positions for key in keys):
                skipped["giver not resolved in game yet"] += 1
                continue
            if not all(key in confident for key in keys):
                skipped["giver near a zone border or on no zone"] += 1
                continue
            found = client_spots(npcs[qid], spawns, confident, names)
            by_client += len(found) == 1
        if len(found) != 1:
            skipped["no giver spot" if not found else "giver in more than one spot"] += 1
            continue
        m, x, y, giver = found.pop()
        sort = int(q["ZoneOrSort"])
        side, races = dungeon_quests.side_of(int(q["RequiredRaces"]))
        out[str(qid)] = {"name": q["Title"], "level": int(q["QuestLevel"]), "reqlevel": int(q["MinLevel"]),
                         "side": side, "reqrace": races, "reqclass": int(q["RequiredClasses"]),
                         "after": sorted(after.get(qid, ())), "map": m, "x": x, "y": y, "giver": giver,
                         "dungeon": sort > 0 and sort not in ZONE_MAP, "battleground": sort in BATTLEGROUNDS}

    OUT.write_text(json.dumps({"cmangos": dungeon_quests.COMMIT, "build": wago.BUILD, "quests": out},
                              indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\r\n")
    kinds = Counter("dungeon" if d["dungeon"] else "other" for d in out.values())
    print(f"wrote {OUT.relative_to(paths.ROOT)}: {len(out)} quests ({kinds['dungeon']} dungeon, "
          f"{kinds['other']} other), {by_client} placed by the client")
    for reason, n in skipped.most_common():
        print(f"  left out {n}: {reason}")

    if args.positions:
        unresolved = {key for key in needed if key not in positions}
        write_resolver(unresolved)
        print(f"wrote {RESOLVER.relative_to(paths.ROOT)}: {len(unresolved)} positions to resolve in game")
    total = on_map = agree = 0
    for n, (m, x, y, _) in check.items():
        if not all(k in confident for k in spawns[n]):
            continue
        total += 1
        same = [confident[k] for k in spawns[n] if confident[k][0] == m]
        on_map += bool(same)
        agree += any(math.hypot(s[1] - x, s[2] - y) <= CLOSE for s in same)
    if total:
        print(f"of the {total} givers Wowhead places that the answers taken place too, {on_map} "
              f"({on_map / total:.1%}) are on Wowhead's map, {agree} ({agree / total:.1%}) within {CLOSE} of its spot")


if __name__ == "__main__":
    main()
