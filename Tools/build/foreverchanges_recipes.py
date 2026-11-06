"""Give the Professions recipes whose source is unknown the one ForeverChanges lists: builds
Tools/data/foreverchanges_recipes.json, then writes those sources into
NaowhForever_Professions/Data/RecipeData.lua.

Their profession pages (/professions/<trade>) list each recipe by its spell, with its recipe item
and where that comes from: who sells it (zone, side, price in copper), the mobs it drops from,
or the quest it rewards. Their dungeon pages (/dungeons/<id>) list each boss's drops, recipes
among them, for a recipe the profession pages give no source. Only a recipe RecipeData has as
"unknown" is written; every other source in it stays as it is.

- A seller RecipeData already has an NPC row for keeps that row's ID and spot. The others are
  written as sellers, { name, faction, areaID [, price] }: the pages name only their zone, and
  the game has no map of a dungeon's inside to put a spot on.
- A drop from more mobs than the page names is a world drop; otherwise the mobs it names, or
  the dungeon bosses that drop it, are its bosses.
- Zones are the game's AreaTable IDs (through wago.py), kept in the JSON with the pages' answers;
  0 where the table has no area of that name, as RecipeData has for an unknown area.
- Names that are not ASCII are left out: their pages carry some sellers twice, the second
  time in another language.

--offline reads nothing and writes from the JSON.

Usage: python Tools/build/foreverchanges_recipes.py [--offline]
"""
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
import wowhead  # noqa: E402

SITE = "https://foreverchanges.pro"
OUT = paths.DATA / "foreverchanges_recipes.json"
RECIPES = paths.ROOT / "NaowhForever_Professions" / "Data" / "RecipeData.lua"
GAP = 1
TRADES = ("alchemy", "blacksmithing", "camping", "cooking", "enchanting", "engineering", "first-aid",
          "fishing", "herbalism", "leatherworking", "mining", "skinning", "tailoring")
RECIPE_CLASS = 9   # a dungeon page item's class ("c") for a recipe
SIDES = {"a": "A", "h": "H", "": "AH"}
# The page's data comes as React Server Component chunks, JSON strings pushed in order.
PUSH = re.compile(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)')
ROW = re.compile(r'\{"spell":\d+,"id":')
NPC = re.compile(r'\{ (\d+), ("(?:[^"\\]|\\.)*"), "[AH-]+", (\d+, [\d.]+, [\d.]+)')
UNKNOWN = re.compile(r'^( *)(\{ spell = (\d+),.*?), source = "unknown" \},', re.M)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": wowhead.AGENT})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def page_data(page):
    return "".join(json.loads(m.group(1)) for m in PUSH.finditer(page))


def listed(data, key):
    """The first list under key in a page's data; None where it has none."""
    at = data.find(f'"{key}":[')
    if at < 0:
        return None
    return json.JSONDecoder().raw_decode(data, at + len(key) + 3)[0]


def trade_recipes(data):
    """[(spell, recipe item, its source)] for each recipe a profession page lists with an item.
    Enchanting's rods, oils and blueprints name their item as taught_by, with no source."""
    decoder = json.JSONDecoder()
    found = []
    for m in ROW.finditer(data):
        row = decoder.raw_decode(data, m.start())[0]
        item = row["formula"]["id"] if row.get("formula") else row.get("taught_by")
        if item:
            found.append((row["spell"], item, row.get("source") or {}))
    return found


def boss_recipes(data, dungeon):
    """{recipe item: [[boss, dungeon], ...]} for the recipes a dungeon page's bosses drop; none
    on a page for a dungeon not out yet, which lists no bosses."""
    out = {}
    for boss in listed(data, "bosses") or []:
        for item in boss["items"]:
            if item.get("c") == RECIPE_CLASS:
                out.setdefault(item["i"], []).append([boss["name"], dungeon])
    return out


def source(found, dropped):
    """A recipe's source as the JSON keeps it, from its profession page's source and the dungeon
    bosses that drop it; None where neither names one."""
    vendors = [[v["npc"], v["zone"], v["side"], v.get("price")] for v in found.get("vendors") or []
               if v["npc"].isascii()]
    if vendors:
        return {"vendors": vendors}
    drops = found.get("drops") or []
    if sum(place["n"] for place in found.get("places") or []) > len(drops):
        return {"world": True}
    bosses = [[d["npc"], d["zone"]] for d in drops if d["npc"].isascii()]
    if bosses:
        return {"bosses": bosses}
    quests = [[q["name"], q["side"], q["level"], q.get("id")] for q in found.get("quests") or []]
    if quests:
        return {"quests": quests}
    if dropped:
        return {"bosses": dropped}
    return None


def read():
    """{spell: {"recipe": item, and its source}} for every recipe ForeverChanges gives a source."""
    recipes = {}
    for trade in TRADES:
        for spell, item, found in trade_recipes(page_data(fetch(f"{SITE}/professions/{trade}"))):
            recipes[spell] = (item, found)
        time.sleep(GAP)
    if not recipes:
        raise ValueError("no recipes on ForeverChanges' profession pages")
    dungeons = listed(page_data(fetch(f"{SITE}/dungeons")), "dungeons")
    if not dungeons:
        raise ValueError("no dungeons on ForeverChanges' dungeons page")
    dropped = {}
    for dungeon in dungeons:
        time.sleep(GAP)
        page = page_data(fetch(f"{SITE}/dungeons/{dungeon['id']}"))
        for item, bosses in boss_recipes(page, dungeon["name"]).items():
            dropped.setdefault(item, []).extend(bosses)
    out = {}
    for spell, (item, found) in recipes.items():
        known = source(found, dropped.get(item))
        if known:
            out[str(spell)] = {"recipe": item, **known}
    return out


def areas(rows, names):
    """Zone name -> its AreaTable ID: the zone or dungeon of that name before a subzone, the
    lower ID of two; 0 for a name the table lacks."""
    ids = {}
    for row in sorted(rows, key=lambda r: (r["ParentAreaID"] != "0", int(r["ID"]))):
        ids.setdefault(row["AreaName_lang"], int(row["ID"]))
    return {name: ids.get(name, 0) for name in sorted(names)}


def block(field, rows, indent):
    return f"{field} = {{\r\n" + "".join(f"{indent}    {row},\r\n" for row in rows) + f"{indent}}}"


def lua_source(entry, npcs, zones, indent):
    """The RecipeData fields for a recipe's source, from source = on."""
    if entry.get("world"):
        return 'source = "drop", world = 1'
    if "bosses" in entry:
        rows = [f"{{ {wowhead.lua_string(name)}, {zones[zone]} }}" for name, zone in entry["bosses"]]
        return 'source = "drop", ' + block("bosses", list(dict.fromkeys(rows)), indent)
    if "quests" in entry:
        rows = []
        for name, side, level, quest in entry["quests"]:
            given = "" if quest is None else f"id = {quest}, "
            rows.append(f'{{ {given}name = {wowhead.lua_string(name)}, side = "{SIDES[side]}", level = {level} }}')
        return 'source = "quest", ' + block("quests", rows, indent)
    spotted, sellers = [], []
    for name, zone, side, price in entry["vendors"]:
        name, cost = wowhead.lua_string(name), "" if price is None else f", {price}"
        if name in npcs:
            npc, spot = npcs[name]
            spotted.append(f'{{ {npc}, {name}, "{SIDES[side]}", {spot}{cost} }}')
        else:
            sellers.append(f'{{ {name}, "{SIDES[side]}", {zones[zone]}{cost} }}')
    lists = [block("vendors", spotted, indent)] if spotted else []
    lists += [block("sellers", sellers, indent)] if sellers else []
    return 'source = "vendor", ' + ", ".join(lists)


def fill(text, recipes, zones):
    """RecipeData's text with each unknown recipe ForeverChanges knows given its source, and its
    recipe item where the row has none."""
    npcs = {}
    for npc, name, spot in NPC.findall(text):
        npcs.setdefault(name, (npc, spot))

    def one(m):
        entry = recipes.get(m[3])
        if not entry:
            return m[0]
        head = m[2] if "recipe = " in m[2] else f"{m[2]}, recipe = {entry['recipe']}"
        return f"{m[1]}{head}, {lua_source(entry, npcs, zones, m[1])} }},"
    return UNKNOWN.sub(one, text)


def main():
    if "--offline" in sys.argv:
        data = json.loads(OUT.read_text(encoding="utf-8"))
    else:
        recipes = read()
        rows = [row for entry in recipes.values() for row in entry.get("vendors", []) + entry.get("bosses", [])]
        data = {"recipes": recipes, "areas": areas(wago.table("AreaTable"), {row[1] for row in rows})}
        OUT.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    text = RECIPES.read_bytes().decode("ascii")
    filled = fill(text, data["recipes"], data["areas"])
    RECIPES.write_bytes(filled.encode("ascii"))
    before, after = (len(UNKNOWN.findall(t)) for t in (text, filled))
    print(f"{len(data['recipes'])} recipes with a source on ForeverChanges; {before - after} of {before} "
          f"unknown recipes given one, {after} left: {RECIPES.relative_to(paths.ROOT)}")


if __name__ == "__main__":
    main()
