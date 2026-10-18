"""Build NaowhForever_DiscoveryData/Quests.lua: every quest of every zone, with its chain.

A zone page (/forever/zone=<areaID>) lists the quests tied to the zone in its "quests"
listview; the ones whose category is the zone itself are the zone's own quests (the rest are
class, profession and holiday quests that merely start there). Each quest page
(/forever/quest=<id>) then gives its chain, the "Series" box parsed the same way as
Tools/build/quest_chains.py does, and where its quest giver stands.

The dungeon and raid quests, which Wowhead files under the dungeon and so no zone lists, come
from completo_dungeon.json (Tools/build/dungeon_quests.py): each goes in the zone its quest giver
stands in, marked in D.Dungeon. The class quests and the instance quests the Journal lacks come
from completo_elsewhere.json (Tools/build/elsewhere_quests.py), marked in D.Elsewhere or D.Dungeon.

Answers are cached, so a run that dies on Wowhead's rate limit resumes where it stopped:
completo_zones.json (each zone's quest rows) and completo_quests.json (each quest's
{ chain, start }). Delete an entry to fetch it again. --offline writes from the caches only.

Usage: python Tools/build/completo_quests.py [--offline]
"""
import html
import json
import re
import sys
import time
import unicodedata
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wowhead  # noqa: E402
from quest_chains import ZONE_MAP, parse, parse_start  # noqa: E402

ROOT = paths.ROOT
OUT = ROOT / "NaowhForever_DiscoveryData" / "Quests.lua"
ZONES = paths.DATA / "completo_zones.json"
QUESTS = paths.DATA / "completo_quests.json"
REQUIRES = paths.DATA / "completo_requires.json"
DUNGEON = paths.DATA / "completo_dungeon.json"
ELSEWHERE = paths.DATA / "completo_elsewhere.json"
# Wowhead answers 403 after ~125 pages at 1.5s apart; 5s ran clean.
GAP = 4


def load(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save(path, data):
    path.write_text(json.dumps(data, indent=1, sort_keys=True), encoding="utf-8")


def zone_name(page):
    info = re.search(r"g_pageInfo = (\{.*?\});", page)
    if info:
        name = json.loads(info.group(1)).get("name")
        if name:
            return name
    title = re.search(r"<title>([^<]*?) - Zone", page)
    return html.unescape(title.group(1)) if title else None


def fetch_zone(area):
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/zone={area}")
    rows = []
    for q in wowhead.listview(page, "quests"):
        if q.get("category") != area:
            continue
        rows.append({k: q[k] for k in ("id", "name", "level", "reqlevel", "side", "reqrace",
                                         "reqclass", "category2") if k in q})
    return {"name": zone_name(page), "quests": rows}


# A Series row Wowhead fills with "<UNUSED>" (quests 810, 3515) is a step that no longer
# exists: left out of the page before it is read.
UNUSED = re.compile(r"<tr><th>\d+\.</th><td><div><b>&lt;UNUSED&gt;</b></div></td></tr>|"
                    r"<tr><th>\d+\.</th><td><div><b><UNUSED></b></div></td></tr>")


def fetch_quest(quest_id):
    page = UNUSED.sub("", wowhead.fetch(f"{wowhead.WOWHEAD}/quest={quest_id}"))
    return {"chain": parse(quest_id, page), "start": parse_start(page)}


# Wowhead Classic's quest pages have a "Requires" box, the quests to hand in before this one
# is offered, which its Forever pages lack. Quest IDs are the same; Forever's own quests
# (CLASSIC_MAX and up) are not on Classic.
CLASSIC = "https://www.wowhead.com/classic"
CLASSIC_MAX = 10000
REQUIRES_BOX = re.compile(r"<th>Requires</th>.*?WH\.markup\.printHtml\(\"(.*?)\", \"infobox-contents", re.S)


def fetch_requires(quest_id):
    """{ "quests": [ids the Requires box names], "text": its markup }, or None without a box."""
    page = wowhead.fetch(f"{CLASSIC}/quest={quest_id}")
    box = REQUIRES_BOX.search(page)
    if not box:
        return None
    markup = box.group(1)
    return {"quests": [int(i) for i in re.findall(r"\[quest=(\d+)", markup)], "text": markup}


# Quests that start from an item a mob drops (Ursangous's Paw) have no quest giver on the map.
# The zone page lists the items that start quests there ("starts-quest"); each item's page
# names its quest ("This Item Begins a Quest") and the mobs that drop it ("dropped-by"); each
# mob's page has where it spawns (g_mapperData). Cached in completo_items.json:
# { "zones": { area: { items } }, "items": { item: { quest, drops } }, "npcs": { npc: spots },
# "repeatable": [questIDs] }.
ITEMS = paths.DATA / "completo_items.json"
BEGINS = re.compile(r"/forever/quest=(\d+)[^\"<]*\"[^>]*>This Item Begins a Quest")
# A mob that drops it this rarely is not where to go for it (a world drop).
MIN_DROP = 0.02


def fetch_zone_items(area):
    """{ "items": the zone's quest-starting items }."""
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/zone={area}")
    return {"items": [row["id"] for row in wowhead.listview(page, "starts-quest")]}


def fetch_repeatable():
    """Every quest Wowhead calls repeatable, from its quest search's Repeatable: Yes filter
    (one page: 318 quests, under a list's 1000). Its listview's wflags do not say it: bit 16
    is set on The Ashenvale Hunt and the library books too."""
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/quests?filter=29;1;0")
    return sorted(q["id"] for q in wowhead.listview(page, "quests"))


def fetch_item(item):
    """{ "quest": the quest it begins, or None; "drops": [{ npc, name, chance, rare }] }."""
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/item={item}").replace("\\/", "/").replace('\\"', '"')
    begins = BEGINS.search(page)
    drops = []
    for row in wowhead.listview(page, "dropped-by"):
        outof = row.get("outof") or 0
        drops.append({"npc": row["id"], "name": row["name"], "rare": row.get("classification", 0) > 0,
                      "chance": (row.get("count") or 0) / outof if outof else 0})
    return {"quest": int(begins.group(1)) if begins else None, "drops": drops}


def fetch_npc(npc):
    """{ uiMapID: [[x, y], ...] } where the mob spawns, from its page's map."""
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/npc={npc}")
    mapper = re.search(r"g_mapperData\s*=\s*(\{.*?\});", page, re.S)
    spots = {}
    for floors in (json.loads(mapper.group(1)).values() if mapper else []):
        for floor in floors:
            if floor.get("uiMapId") and floor.get("coords"):
                spots.setdefault(str(floor["uiMapId"]), []).extend(floor["coords"])
    return spots


def drop_spot(items, quest_id):
    """Where to go for a quest an item begins: (uiMapID, x, y, mob, item), the spawn point
    nearest the middle of where its likeliest dropper spawns on the map it spawns most, or None."""
    for item, info in items["items"].items():
        if not info or info.get("quest") != quest_id:
            continue
        drops = sorted((d for d in info["drops"] if d["chance"] >= MIN_DROP),
                       key=lambda d: (-d["chance"], not d["rare"]))
        for drop in drops:
            spots = items["npcs"].get(str(drop["npc"])) or {}
            maps = [(len(c), int(m), c) for m, c in spots.items() if int(m) in ZONE_MAP.values()]
            if not maps:
                continue
            _, map_id, coords = max(maps)
            cx = sum(c[0] for c in coords) / len(coords)
            cy = sum(c[1] for c in coords) / len(coords)
            x, y = min(coords, key=lambda c: (c[0] - cx) ** 2 + (c[1] - cy) ** 2)
            return map_id, x, y, drop["name"], int(item)
    return None


# The maps Forever redrew, and Wowhead still gives classic positions on: each map's world
# bounds (minX, minY, maxX, maxY, from the game's UiMapAssignment on wago.tools) in Classic
# Era 1.15.9.70003 and in Forever 1.60.1.70205. The world did not move, only the maps, so a
# classic position goes to the world and back onto Forever's map.
REDRAWN_BOUNDS = {
    1453: ((-9175.205, 36.701, -8278.851, 1380.971), (-9154.170, -14.584, -7995.830, 1722.920)),
    1412: ((-3697.917, -3089.583, -272.917, 2047.917), (-3835.416, -3675.0, 266.666, 2479.167)),
    1433: ((-10022.916, -3741.667, -8575.0, -1570.833), (-10022.916, -3852.084, -8575.0, -1681.25)),
    1423: ((1218.75, -6056.25, 3800.0, -2185.417), (825.0, -6558.334, 3691.667, -2256.25)),
}


def forever_spot(map_id, x, y):
    """A Wowhead position (percent) on Forever's map: the same on maps Forever left alone."""
    if map_id not in REDRAWN_BOUNDS:
        return x, y
    (cx0, cy0, cx1, cy1), (fx0, fy0, fx1, fy1) = REDRAWN_BOUNDS[map_id]
    # A map's x runs along the world's Y axis from its max down, its y along X from its max down.
    world_y = cy1 - x / 100 * (cy1 - cy0)
    world_x = cx1 - y / 100 * (cx1 - cx0)
    return (fy1 - world_y) / (fy1 - fy0) * 100, (fx1 - world_x) / (fx1 - fx0) * 100


def lua_string(s):
    # ASCII only, as the addon files must be: an accented letter keeps its base letter.
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + "".join(c if " " <= c <= "~" else f"\\{ord(c):03d}" for c in s) + '"'


def prerequisites(quests, requires, known):
    """questID -> the quests before it: the step before it in its Forever Series (the faction
    or class versions of one step), and Wowhead Classic's Requires box."""
    before = {}
    for entry in quests.values():
        chain = entry and entry.get("chain")
        if not chain:
            continue
        for prev, step in zip(chain["chain"], chain["chain"][1:]):
            for i in step:
                if i in known:
                    before.setdefault(i, set()).update(prev)
    for qid, box in requires.items():
        if box and int(qid) in known:
            before.setdefault(int(qid), set()).update(box["quests"])
    for qid in before:
        before[qid].discard(qid)
    return {q: sorted(p) for q, p in before.items() if p}


def requirements(before, known):
    """questID -> what must be done before it: each element a quest, or a list of alternatives,
    one of which will do. Quests of one name are alternatives (a Requires box lists each class's
    version of a quest), as are the ones the zones lack, which cannot be told apart. The
    versions that are not the player's own are left out by the addon."""
    out = {}
    for qid, prev in before.items():
        groups = {}
        for p in prev:
            groups.setdefault(known[p][1]["name"] if p in known else None, []).append(p)
        out[qid] = sorted((g if len(g) > 1 else g[0] for g in groups.values()),
                          key=lambda e: e[0] if isinstance(e, list) else e)
    return out


def chains_of(quests, before, known):
    """The data's quests linked by their prerequisites, each group one chain, its quests in
    steps: a quest one step after the furthest of those before it. A step with more than one
    quest has parallel quests, or a Series step's versions (any=True: one of them is done)."""
    edges = {}
    for qid, prev in before.items():
        for p in prev:
            if p in known:
                edges.setdefault(p, set()).add(qid)
    # The groups: quests linked either way.
    group = {}

    def find(q):
        while group.get(q, q) != q:
            group[q] = group.get(group[q], group[q])
            q = group[q]
        return q
    for p, nexts in edges.items():
        for n in nexts:
            a, b = find(p), find(n)
            if a != b:
                group[a] = b
    members = {}
    for q in set(edges) | {n for ns in edges.values() for n in ns}:
        members.setdefault(find(q), set()).add(q)
    # A Series step's versions, to tell them apart from parallel quests.
    versions = []
    for entry in quests.values():
        chain = entry and entry.get("chain")
        for step in (chain["chain"] if chain else []):
            kept = frozenset(i for i in step if i in known)
            if len(kept) > 1:
                versions.append(kept)
    out = []
    for quests_in in members.values():
        # Each quest's step: one after the furthest of those before it in the group. A loop
        # in the data (it has none so far) leaves its quests at the step they reached.
        depth = {q: 0 for q in quests_in}
        for _ in range(len(quests_in)):
            moved = False
            for q in quests_in:
                for n in edges.get(q, ()):
                    if n in depth and depth[n] < depth[q] + 1 <= len(quests_in):
                        depth[n] = depth[q] + 1
                        moved = True
            if not moved:
                break
        steps = {}
        for q, d in depth.items():
            steps.setdefault(d, []).append(q)
        ordered = []
        for d in sorted(steps):
            ids = sorted(steps[d], key=lambda q: (known[q][1].get("level") or 0, q))
            any_of = len(ids) > 1 and any(frozenset(ids) <= v for v in versions)
            ordered.append((ids, any_of))
        out.append(ordered)
    out.sort(key=lambda steps: steps[0][0][0])
    return out


def main():
    offline = "--offline" in sys.argv
    zones, quests, failed = load(ZONES), load(QUESTS), []

    for area in ZONE_MAP:
        if str(area) in zones or offline:
            continue
        try:
            zones[str(area)] = fetch_zone(area)
        except urllib.error.HTTPError as e:
            failed.append(f"zone {area}: {e}")
            continue
        save(ZONES, zones)
        print(f"zone {area} {zones[str(area)]['name']}: {len(zones[str(area)]['quests'])} quests")
        time.sleep(GAP)

    wanted = [q["id"] for z in zones.values() for q in z["quests"]]
    todo = [i for i in wanted if str(i) not in quests]
    print(f"{len(wanted)} quests, {len(todo)} quest pages to fetch")
    if not offline:
        for n, quest_id in enumerate(todo, 1):
            try:
                quests[str(quest_id)] = fetch_quest(quest_id)
            except (urllib.error.HTTPError, ValueError) as e:
                failed.append(f"quest {quest_id}: {e}")
                continue
            save(QUESTS, quests)
            if n % 50 == 0:
                print(f"  {n}/{len(todo)}")
            time.sleep(GAP)

    requires = load(REQUIRES)
    todo = [i for i in wanted if i < CLASSIC_MAX and str(i) not in requires]
    print(f"{len(todo)} Wowhead Classic pages to fetch for prerequisites")
    if not offline:
        for n, quest_id in enumerate(todo, 1):
            try:
                requires[str(quest_id)] = fetch_requires(quest_id)
            except urllib.error.HTTPError as e:
                failed.append(f"classic quest {quest_id}: {e}")
                continue
            save(REQUIRES, requires)
            if n % 50 == 0:
                print(f"  {n}/{len(todo)}")
            time.sleep(GAP)

    items = load(ITEMS) or {}
    for key in ("zones", "items", "npcs"):
        items.setdefault(key, {})
    if not offline and "repeatable" not in items:
        items["repeatable"] = fetch_repeatable()
        save(ITEMS, items)
        time.sleep(GAP)
    if not offline:
        for area in ZONE_MAP:
            if str(area) not in items["zones"]:
                try:
                    items["zones"][str(area)] = fetch_zone_items(area)
                except urllib.error.HTTPError as e:
                    failed.append(f"zone items {area}: {e}")
                    continue
                save(ITEMS, items)
                time.sleep(GAP)
        todo = sorted({i for z in items["zones"].values() for i in z["items"] if str(i) not in items["items"]})
        print(f"{len(todo)} quest item pages to fetch")
        for item in todo:
            try:
                items["items"][str(item)] = fetch_item(item)
            except urllib.error.HTTPError as e:
                failed.append(f"item {item}: {e}")
                continue
            save(ITEMS, items)
            time.sleep(GAP)
        npcs = {d["npc"] for info in items["items"].values() if info
                for d in info["drops"] if d["chance"] >= MIN_DROP}
        todo = [n for n in npcs if str(n) not in items["npcs"]]
        print(f"{len(todo)} mob pages to fetch")
        for npc in todo:
            try:
                items["npcs"][str(npc)] = fetch_npc(npc)
            except urllib.error.HTTPError as e:
                failed.append(f"npc {npc}: {e}")
                continue
            save(ITEMS, items)
            time.sleep(GAP)

    write(zones, quests, requires, items, load(DUNGEON).get("quests", {}), load(ELSEWHERE).get("quests", {}))
    for line in failed:
        print("FAILED", line, file=sys.stderr)


# Quests the game has records for but never gives: "<UNUSED>", "(UNUSED) The Rusty Gadget",
# "<NYI> <TXT> Course of Action" (not yet implemented). Left out everywhere.
PLACEHOLDER = re.compile(r"^\s*[<(]|unused|\bnyi\b", re.I)


def write(zones, quests, requires, items, dungeon, elsewhere):
    for z in zones.values():
        z["quests"] = [q for q in z["quests"] if not PLACEHOLDER.search(q["name"])]
    # A dungeon or elsewhere quest's spot is Forever's already, and its giver's zone is the one it
    # goes in.
    area_of = {m: a for a, m in ZONE_MAP.items()}
    own = {q["id"] for z in zones.values() for q in z["quests"]}
    spots, requires = {}, dict(requires)
    for key, d in {**{k: dict(d, dungeon=True) for k, d in dungeon.items()}, **elsewhere}.items():
        zone = zones.get(str(area_of.get(d["map"])))
        if int(key) in own or not zone:
            continue
        zone["quests"].append({"id": int(key), "name": d["name"], "level": d["level"], "reqlevel": d["reqlevel"],
                               "side": d["side"], "reqrace": d["reqrace"], "reqclass": d["reqclass"]})
        spots[int(key)] = d
        if d["after"] and not requires.get(key):
            requires[key] = {"quests": d["after"]}
    rows = {q["id"]: (int(area), q) for area, z in zones.items() for q in z["quests"]}
    before = prerequisites(quests, requires, rows)
    chains = chains_of(quests, before, rows)
    lines = [
        "-- Quests.lua: every quest of every zone and its chain, generated by Tools/build/completo_quests.py.",
        "local D = _G.NaowhForever.CompletoQuestData",
        "",
        "D.Zones = {",
    ]
    order = sorted(zones.items(), key=lambda kv: (kv[1]["name"] or ""))
    for area, z in order:
        ids = sorted(q["id"] for q in z["quests"])
        if not ids:
            continue
        conts = [q.get("category2", 0) for q in z["quests"] if q["id"] not in spots]
        cont = max(set(conts), key=conts.count)
        lines.append(f"    {{ map = {ZONE_MAP[int(area)]}, name = {lua_string(z['name'])}, "
                     f"continent = {cont}, quests = {{ {', '.join(map(str, ids))} }} }},")
    lines += [
        "}",
        "",
        "D.Quests = {",
    ]
    for qid in sorted(rows):
        area, q = rows[qid]
        start = (quests.get(str(qid)) or {}).get("start")
        spot = "nil, nil, nil, nil"
        if qid in spots:
            d = spots[qid]
            giver = lua_string(d["giver"]) if d["giver"] else "nil"
            spot = f"{d['map']}, {d['x']:.1f}, {d['y']:.1f}, {giver}"
        elif start and start.get("coord") and start["zone"] in ZONE_MAP:
            m = ZONE_MAP[start["zone"]]
            x, y = forever_spot(m, *start["coord"])
            giver = lua_string(start["npc"]) if start.get("npc") else "nil"
            spot = f"{m}, {x:.1f}, {y:.1f}, {giver}"
        else:
            drop = drop_spot(items, qid) if items else None
            if drop:
                m, x, y, mob, item = drop
                x, y = forever_spot(m, x, y)
                spot = f"{m}, {x:.1f}, {y:.1f}, {lua_string(mob)}, {item}"
        lines.append(f"    [{qid}] = {{ {lua_string(q['name'])}, {q.get('level') or 0}, "
                     f"{q.get('reqlevel') or 0}, {q.get('side') or 3}, {q.get('reqrace') or 0}, "
                     f"{q.get('reqclass') or 0}, {spot} }},")
    repeatable = sorted(set((items or {}).get("repeatable", [])) & set(rows))
    lines += [
        "}",
        "",
        "D.Repeatable = {",
    ]
    for qid in repeatable:
        lines.append(f"    [{qid}] = true,")
    lines += [
        "}",
        "",
        "D.Dungeon = {",
    ]
    for qid in sorted(q for q, d in spots.items() if d["dungeon"]):
        lines.append(f"    [{qid}] = true,")
    lines += [
        "}",
        "",
        "D.Elsewhere = {",
    ]
    for qid in sorted(q for q, d in spots.items() if not d["dungeon"]):
        lines.append(f"    [{qid}] = true,")
    lines += [
        "}",
        "",
        "D.Requires = {",
    ]
    required = requirements(before, rows)
    for qid in sorted(required):
        parts = ["{ " + ", ".join(map(str, e)) + " }" if isinstance(e, list) else str(e) for e in required[qid]]
        lines.append(f"    [{qid}] = {{ {', '.join(parts)} }},")
    lines += [
        "}",
        "",
        "D.Chains = {",
    ]
    for steps in chains:
        parts = []
        for ids, any_of in steps:
            parts.append("{ " + ", ".join(map(str, ids)) + (", any = true" if any_of else "") + " }")
        lines.append("    { " + ", ".join(parts) + " },")
    lines.append("}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii", "replace"))
    print(f"wrote {OUT.relative_to(ROOT)}: {len(rows)} quests, {len(chains)} chains")


if __name__ == "__main__":
    main()
