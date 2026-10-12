"""Build NaowhForever_Journeys/Data/QuestSpots.lua: where each quest is handed in and where its
objectives are, so a tracked quest has somewhere to go when the game names no point.

Each quest page on Wowhead Forever (/forever/quest=<id>) draws a map (its "new Mapper" data) with
the quest giver ("start"), who takes it back ("end") and the mobs and objects of its objectives
("requirement" for what you kill or use, "sourcerequirement" for what drops what you collect).
A drop source is listed whatever its chance, so an item a dozen mobs can drop says little: only
objectives with at most MAX_SOURCES sources are kept. An objective's spots are grouped into camps
(points within CAMP map percent of each other), and the CAMPS biggest kept.

The quests are the Quest List's (Tools/data/completo_quests.json). Each page's points are cached
in Tools/data/journeys_quest_spots.json, so a run stopped by Wowhead's rate limit resumes where it
stopped; delete an entry to fetch it again. --offline writes from the cache only.

Usage: python Tools/build/journeys_quests.py [--offline]
"""
import json
import re
import sys
import time
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wowhead  # noqa: E402
from journal import header, write  # noqa: E402
from quest_chains import ZONE_MAP  # noqa: E402

OUT = paths.ROOT / "NaowhForever_Journeys" / "Data" / "QuestSpots.lua"
QUESTS = paths.DATA / "completo_quests.json"
CACHE = paths.DATA / "journeys_quest_spots.json"
GAP = 4   # seconds between pages: completo_quests.py found 1.5 drew 403s from Wowhead after ~125
MAX_SOURCES = 3
CAMP = 4.0
CAMPS = 3
KEEP = ("end", "requirement", "sourcerequirement")


def load(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save(path, data):
    path.write_text(json.dumps(data, separators=(",", ":"), sort_keys=True), encoding="utf-8")


def fetch(quest_id):
    """The page's map points: [{ point, zone, id, name, coords }], kept to the kinds used here."""
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/quest={quest_id}")
    mapper = re.search(r"new Mapper\((\{.*?\})\);", page, re.S)
    points = []
    for zone, objective in ((json.loads(mapper.group(1)).get("objectives") or {}).items() if mapper else []):
        for level in objective.get("levels", []):
            for p in level:
                if p.get("point") in KEEP and p.get("coords"):
                    points.append({"point": p["point"], "zone": int(zone), "id": p.get("id"),
                                   "name": p.get("name"), "coords": p["coords"]})
    return points


def camps(coords):
    """Groups points within CAMP of each other; the biggest groups first, as (x, y, count)."""
    groups = []
    for x, y in coords:
        near = [g for g in groups if any(abs(x - gx) <= CAMP and abs(y - gy) <= CAMP for gx, gy in g)]
        merged = [(x, y)]
        for g in near:
            merged += g
            groups.remove(g)
        groups.append(merged)
    groups.sort(key=len, reverse=True)
    return [(sum(p[0] for p in g) / len(g), sum(p[1] for p in g) / len(g), len(g)) for g in groups[:CAMPS]]


def spot(zone, x, y):
    """A Wowhead position on its Forever map. Taken as it is: on Redridge, a map Forever redrew,
    the game's own marker for quest 65's turn-in (21.4, 45.4) matched Wowhead's (21.4, 45.2), so
    these points are already Forever's, unlike what completo_quests.py's forever_spot expects."""
    ui_map = ZONE_MAP.get(zone)
    if not ui_map:
        return None
    return ui_map, round(x, 1), round(y, 1)


def quest_spots(points):
    """(turn-in or None, [objective camps]) from a page's points."""
    end = next((p for p in points if p["point"] == "end"), None)
    turn_in = end and spot(end["zone"], *end["coords"][0])
    sources = [p for p in points if p["point"] == "sourcerequirement"]
    targets = [p for p in points if p["point"] == "requirement"]
    if len(sources) <= MAX_SOURCES:
        targets += sources
    objectives = []
    for p in targets:
        for x, y, count in camps(p["coords"]):
            s = spot(p["zone"], x, y)
            if s:
                objectives.append((*s, count))
    objectives.sort(key=lambda o: o[3], reverse=True)
    return turn_in, objectives[:CAMPS]


def main():
    offline = "--offline" in sys.argv
    quests = sorted(int(q) for q in load(QUESTS))
    cache = load(CACHE)
    todo = [q for q in quests if str(q) not in cache]
    print(f"{len(quests)} quests, {len(todo)} to fetch", flush=True)
    for n, quest in enumerate([] if offline else todo, 1):
        try:
            cache[str(quest)] = fetch(quest)
        except urllib.error.HTTPError as e:
            print(f"  quest {quest}: {e.code}, stopping; run again to go on", flush=True)
            break
        if n % 25 == 0:
            save(CACHE, cache)
            print(f"  {n}/{len(todo)}", flush=True)
        time.sleep(GAP)
    save(CACHE, cache)

    # [questID] = { turn-in { uiMapID, x, y } or false, { { uiMapID, x, y }, ... } objective camps }.
    lines = header(OUT.name, "where each quest is handed in and its objectives' camps, generated by "
                             "Tools/build/journeys_quests.py")
    lines.append("ns.JourneyQuestSpots = {")
    kept = 0
    for quest in quests:
        points = cache.get(str(quest))
        if not points:
            continue
        turn_in, objectives = quest_spots(points)
        if not turn_in and not objectives:
            continue
        kept += 1
        end = "{ %d, %g, %g }" % turn_in if turn_in else "false"
        camps_lua = ", ".join("{ %d, %g, %g }" % o[:3] for o in objectives)
        lines.append(f"    [{quest}] = {{ {end}, {{ {camps_lua} }} }},")
    lines.append("}")
    write(OUT, lines)
    print(f"{kept} quests with a turn-in or objectives -> {OUT.relative_to(paths.ROOT)}")


if __name__ == "__main__":
    main()
