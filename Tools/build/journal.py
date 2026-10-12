"""Build the Dungeon Journal's data from Tools/data/journal_bosses.json, Wowhead and wowsrc.com.

The boss lists are kept by hand in journal_bosses.json (bosses, rares, optional bosses and
loot chests, per wing; "quest" names those of a wing's bosses there only for a quest, kept in
kill order with no number, as Highland Horror). For each boss this finds its NPC on Wowhead
Forever by name and reads the "drops" list on its page (a chest: its object page's
"contains"): every item with the number of kills it dropped from. Where Wowhead Forever keeps nothing (it has not loaded
every classic item yet), Wowhead Classic's page for the same NPC is read. Gear of uncommon
quality or better is kept when it drops from at least 1 in 100 kills and is not a world drop
(the random greens any mob of that level carries). Wowhead counts Classic Era's kills and
Forever's together, so an item new in Forever looks rarer than it is: it is kept once it
has dropped twice, with no chance shown. A boss new in Forever has only Forever's kills, so
its chances are real; under 10 kills none is shown.

Then wowsrc.com's Forever loot pages (Tools/sources/wowsrc.py, its own data file) say what each
boss drops in Forever: their items are added, their chances win, and an old item they no
longer list on that boss is dropped (moved, like Springvale's lantern, now trash's). Each
wing's trash comes from them too. Last, the items placed by hand ("add") and the BiS
sources in NaowhForever_BiS/BiS/Data/BiS.lua; those have no chance.

Every item is listed, the ones not in Forever yet too, so the Journal is whole the day they
come. An item is in the game (known) when the game's tables have it (wago.tools' ItemSparse,
hotfixes in) or the game sent it (Tools/data/items_in_game.json, read from a client by
Tools/sources/items_in_game.py); else it is not in Forever yet, and Data/Items.lua carries all the
Journal shows of it (its name, quality, levels, icon) from Classic Era's tables
(CLASSIC_ERA), so the client never asks the server for it. One Classic Era does not have
either is left out, and listed at the end.
A new Forever item Wowhead ties to SHARED_DROP or more bosses, and wowsrc to none of them, is a
shared random drop, not any one boss's: it is left out. On a boss new in Forever, an item
Wowhead flags as a world drop is the boss's own when it drops from WORLD_DROP_BOSS percent of
its kills or more (Spiritwraith Drape, Faldrim Anvilmar's).

A dungeon is open when the game's own tables (not items_in_game.json: an item the server
sends on request does not open its dungeon) have at least OPEN_SHARE of its instance's boss
loot (Scarlet Monastery's four wings are one instance), or "open" in journal_bosses.json says
so; one not open says so at the top of its page (closed). A boss new in Forever whose drops
were read from fewer than MIN_KILLS kills is read again on a run that asks Wowhead.

Each dungeon also gets the zone its entrance is in and that zone's territory (Alliance, Horde
or Contested) from Wowhead Forever's zone list, and the entrance itself where
journal_bosses.json has one.

Each boss gets its encounter IDs, what ENCOUNTER_END names it by (the Journal counts kills
with it): the game's DungeonEncounter table for the Forever build, from wago.tools' export,
joined on the dungeon's instance (its map in Data/Quests.lua, else the Map table by name) and
the boss's name, or its encounterNames entry in journal_bosses.json. Every row of the
5-player dungeon counts: difficulty 0 fires on any, and Forever has two "Normal"s, 1 and
201, with their own rows in some dungeons. The first ID listed is the one kills are saved
under. A rare, or a boss fought inside a shared encounter (the Ring of Law), has none.

Writes one file per dungeon, NaowhForever_DungeonJournal/Data/Dungeons/<Key>.lua, and
NaowhForever_DungeonJournal/Data/Items.lua with what the addon needs to know about each item before
the client has loaded it; a new dungeon's file also goes in NaowhForever_DungeonJournal/DungeonJournal.xml. Answers are cached in journal_cache.json; delete an
entry to fetch it again.

Raids are in the same list with "raid" (how many players) and "announced": only the
raids announced for Forever get a file, so a classic raid waits in journal_bosses.json until
Blizzard announces it. A dungeon's "note" is shown at the top of its page, "loot": false leaves its loot out (a
raid whose drops Wowhead has no Forever data for yet: its page only has world drops), and
"encounterIDs" pins a boss's encounter IDs where the game's table hides its row.
"countedWith" names, for a boss the game runs no fight for, the boss whose fight it falls in
(Sneed's Shredder, which Sneed climbs out of): it takes that fight's encounter IDs, so its
kills count with it, and says so ("with").

--offline (the daily watch, in CI) asks Wowhead nothing: what the cache does not have comes
from the game's own tables where they have it (a new item's facts, through Tools/sources/wago.py),
else is left out and listed at the end, for a run on our machines.

--refresh-drops reads every boss's and chest's drops from Wowhead again, so each chance is
counted from today's kills (the cache otherwise keeps the first answer). One page per boss, at
fetch's pace; a run stopped part way keeps the old answer for the bosses it did not reach.

Usage: python Tools/build/journal.py [--offline | --refresh-drops]
"""
import csv
import io
import json
import re
import sys
import urllib.error
import urllib.parse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
from wowhead import EQUIPPABLE, SEP, WOWHEAD, fetch, guide_loot, kind, listview, lua_string  # noqa: E402

ROOT = paths.ROOT
BOSSES = paths.DATA / "journal_bosses.json"
CACHE = paths.DATA / "journal_cache.json"
OUT = ROOT / "NaowhForever_DungeonJournal"
BIS_DATA = ROOT / "NaowhForever_BiS" / "BiS" / "Data" / "BiS.lua"
QUESTS = OUT / "Data" / "Quests.lua"

BUILD = "1.60.1.70094"   # the Forever client build the game's tables are read from
WAGO = "https://wago.tools/db2/{}/csv?build=" + BUILD
# A 5-player dungeon's difficulties, the one firing on every difficulty first. 198 and 215
# are the 10- and 20-player raid versions of some dungeons: never the Journal's.
DUNGEON_DIFFICULTIES = ("0", "1", "201")

MIN_CHANCE = 1.0   # percent of kills
MIN_QUALITY = 2    # uncommon
WORLD_DROP = 16384  # Wowhead's flags2 bit for an item any mob can drop
# Wowhead's drop counts: "1" is Normal, kills from Classic Era and Forever together (it does
# not split them); "201" is Season of Discovery, never Forever. On a boss Classic has too, an
# item new in Forever is counted against all those shared kills, so its chance looks tiny
# (Trogg Scepter, 6 of 4,227 Oggleflint kills): it is kept whatever its chance, with none
# shown, once it has dropped NEW_DROPS times (one drop can be a stray world drop: Aku'mai's
# lone Defender's Leather Helm, beside Forever's new world-drop recipes). A boss new in
# Forever (Witherfang) has only Forever's kills: its chances are real. Under MIN_KILLS kills
# no chance is shown (one kill makes every drop 100%).
NORMAL = "1"
NEW_DROPS = 2
MIN_KILLS = 10
SOD = 201
OPEN_SHARE = 0.5
SHARED_DROP = 3
WORLD_DROP_BOSS = 10
CLASSIC_ERA = "1.15.9.70003"
IN_GAME = paths.DATA / "items_in_game.json"

cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}


OFFLINE = "--offline" in sys.argv
REFRESH_DROPS = "--refresh-drops" in sys.argv and not OFFLINE
refreshed = set()
# What a Wowhead answer is cached under; offline, one not cached yet is not asked.
WOWHEAD_KEYS = ("npc:", "drops5:", "contains5:", "model:", "item:", "zones", "guide:")
offline_missed = []


def cached(key, get, fallback=None):
    if key not in cache:
        if OFFLINE and key.startswith(WOWHEAD_KEYS):
            offline_missed.append(key)
            return fallback
        cache[key] = get()
    return cache[key]


game_items = None


def game_tables():
    """Item ID (a string) -> (its Item row, its ItemSparse row), for every item the game's own
    tables name: wago.BUILD's with its hotfixes, over CARRY_FROM's."""
    global game_items
    if game_items is None:
        import wago
        game_items = {}
        # The build carried from first (wago.CARRY_FROM: hotfixed items wago has not recorded for
        # the new one yet), then the build itself over it, as the faction data reads them.
        for build in (wago.CARRY_FROM, wago.BUILD):
            if build:
                sparse = {r["ID"]: r for r in wago.table("ItemSparse", build)}
                game_items.update({r["ID"]: (r, sparse[r["ID"]]) for r in wago.table("Item", build)
                                   if r["ID"] in sparse})
    return game_items


sent = None


def in_game_list():
    global sent
    if sent is None:
        found = json.loads(IN_GAME.read_text(encoding="ascii")) if IN_GAME.exists() else {}
        sent = {"loads": set(found.get("loads", [])), "refused": set(found.get("refused", []))}
    return sent


def known(item_id):
    return str(item_id) in game_tables() or item_id in in_game_list()["loads"]


era_items = None


def era_tables():
    global era_items
    if era_items is None:
        import wago
        sparse = {r["ID"]: r for r in wago.table("ItemSparse", CLASSIC_ERA, hotfixes=False)}
        era_items = {r["ID"]: (r, sparse[r["ID"]]) for r in wago.table("Item", CLASSIC_ERA, hotfixes=False)
                     if r["ID"] in sparse}
    return era_items


def game_item(item_id):
    """An item's facts from the game's own tables (Item, ItemSparse: the --offline build), in
    the fields npc_drops keeps; None where they do not have it (an old classic item)."""
    found = game_tables().get(str(item_id)) or era_tables().get(str(item_id))
    if not found:
        offline_missed.append(f"item:{item_id}")
        return None
    item, sparse = found
    return {"id": item_id, "slot": int(sparse["InventoryType"]), "class": int(item["ClassID"]),
            "subclass": int(item["SubclassID"]), "level": int(sparse["ItemLevel"]),
            "reqlevel": int(sparse["RequiredLevel"] or 0), "quality": int(sparse["OverallQualityID"])}


def save_cache():
    """Written whole to a temporary file first, so a stopped run never leaves half a cache.
    Windows refuses the swap while another program holds the cache open (an editor, a virus
    scan); then it is written in place."""
    text = json.dumps(cache, indent=1, sort_keys=True)
    tmp = CACHE.with_suffix(".tmp")
    tmp.write_text(text, encoding="utf-8", newline="\n")
    try:
        tmp.replace(CACHE)
    except PermissionError:
        CACHE.write_text(text, encoding="utf-8", newline="\n")
        tmp.unlink()


def npc_model(npc):
    """The NPC's creature display ID, from its Wowhead Forever page (g_npcs' "model"), for its
    portrait on the dungeon map; None where the page has none."""
    def get():
        try:
            page = fetch(f"{WOWHEAD}/npc={npc}")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            raise
        found = re.search(r'"%d":\{"name_enus":"[^"]*","model":(\d+)' % npc, page)
        return int(found.group(1)) if found else None
    return cached(f"model:{npc}", get)


def find_npc(name):
    """The ID of the Wowhead Forever NPC with exactly this name (any case), or None."""
    def get():
        query = urllib.parse.urlencode({"q": name})
        found = json.loads(fetch(f"{WOWHEAD}/search/suggestions-template?{query}"))
        exact = [r["id"] for r in found["results"] if r["type"] == 1 and r["name"].lower() == name.lower()]
        return exact[0] if exact else None
    return cached(f"npc:{name}", get)


def npc_drops(npc):
    """[{id, chance, facts}] for the gear the NPC drops, most likely first."""
    return wowhead_drops("npc", npc)


def chest_drops(chest):
    """The same for a chest (a Wowhead object): what it contains."""
    return wowhead_drops("object", chest)


def wowhead_drops(kind, thing):
    """An NPC's drops ("npc") or a chest's contents ("object"), from its Wowhead Forever page;
    where that keeps nothing (Wowhead Forever has not loaded its classic items yet: Blackrock
    Depths' Secret Safe), from Classic's page for the same NPC or object."""
    listed = "drops" if kind == "npc" else "contains"

    def page_of(base):
        try:
            page = fetch(f"{base}/{kind}={thing}")
        except urllib.error.HTTPError as e:
            if e.code == 404:   # a boss Wowhead has no page for yet (a raid not open)
                return None, -1
            raise
        return page, page.find(f"template: 'item', id: '{listed}'")

    def get():
        found = read(*page_of(WOWHEAD))
        if not (found and found["items"]):
            found = read(*page_of(CLASSIC_WOWHEAD)) or found
        return found or []

    def read(page, start):
        if start < 0:
            return None
        total = int(page[start:].split("_totalCount:", 1)[1].split(",", 1)[0])

        def counted(i):
            """The item's drops and the kills they are out of: Normal's, else every
            difficulty's ("0"), else its own count, else the page's total."""
            modes = i.get("modes") or {}
            for mode in (NORMAL, "0"):
                if (modes.get(mode) or {}).get("outof"):
                    return modes[mode].get("count", 0), modes[mode]["outof"]
            return i.get("count", 0), i.get("outof") or total

        def sod_only(i):
            seen = (i.get("modes") or {}).get("mode") or []
            return bool(seen) and all(m == SOD for m in seen)

        # The boss is new in Forever: Wowhead's own entry for it says so.
        npc_new = kind == "npc" and re.search(r'"id":%d,[^;]*?"envChange":\{"status":"new"' % thing,
                                              page[:start]) is not None
        # Only what could be kept is cached: uncommon or better gear that is not a world drop
        # nor only Season of Discovery's. A chest's own items carry the world-drop flag too
        # (the Secret Safe's): there only Wowhead's common-drop mark counts.
        return {"new": npc_new, "items": [{"id": i["id"], "name": i.get("name"), "count": counted(i)[0], "kills": counted(i)[1],
                 "new": (i.get("envChange") or {}).get("status") == "new",
                 "slot": i.get("slot"), "class": i.get("classs"), "subclass": i.get("subclass"), "level": i.get("level"),
                 "reqlevel": i.get("reqlevel") or 0, "quality": i.get("quality", 0),
                 **({"world": True} if kind == "npc" and i.get("flags2", 0) & WORLD_DROP else {})}
                for i in listview(page[start:], listed)
                if i.get("quality", 0) >= MIN_QUALITY and i.get("slot") in EQUIPPABLE
                and not (i.get("commondrop") or (kind == "npc" and i.get("flags2", 0) & WORLD_DROP and not npc_new))
                and not sod_only(i)]}
    key = f"drops5:{thing}" if kind == "npc" else f"contains5:{thing}"
    if not OFFLINE and (stale(cache.get(key)) or (REFRESH_DROPS and key not in refreshed)):
        cache.pop(key, None)
    refreshed.add(key)
    found = cached(key, get)
    if not found or isinstance(found, list):   # a page with no drops (or, offline, not read yet)
        return []
    return choose(found["items"], found["new"])


def stale(found):
    if not isinstance(found, dict) or not found.get("new"):
        return False
    return max((item["kills"] for item in found["items"]), default=0) < MIN_KILLS


def choose(items, npc_new=False):
    """The gear kept for a boss, with each item's chance, most likely first. On a boss Classic
    has too, an item new in Forever is kept once it has dropped NEW_DROPS times, whatever its
    chance, and shows none (it is counted against Classic Era's kills too). No chance either
    under MIN_KILLS kills."""
    drops = []
    for item in items:
        chance = 100 * item["count"] / item["kills"] if item["kills"] else None
        if item.get("world") and (chance or 0) < WORLD_DROP_BOSS:
            continue
        shared = item["new"] and not npc_new
        if chance is None:
            drops.append(dict(item, chance=None))
        elif shared and (item["count"] >= NEW_DROPS or chance >= MIN_CHANCE):
            drops.append(dict(item, chance=None))
        elif not shared and chance >= MIN_CHANCE:
            drops.append(dict(item, chance=chance if item["kills"] >= MIN_KILLS else None))
    drops.sort(key=lambda i: (-(i["chance"] or 0), -i["quality"], i["id"]))
    return drops


CLASSIC_WOWHEAD = "https://www.wowhead.com/classic"


def item_facts(item_id):
    """What the item's XML says about it, in the fields npc_drops keeps: Wowhead Forever's, else
    Classic's (Wowhead Forever has not loaded every classic item yet: Hand of Justice; the IDs
    are the same)."""
    def get():
        xml = fetch(f"{WOWHEAD}/item={item_id}&xml")
        if "<json>" not in xml:
            xml = fetch(f"{CLASSIC_WOWHEAD}/item={item_id}&xml")
        item = json.loads("{" + re.search(r"<json><!\[CDATA\[(.*?)\]\]></json>", xml, re.S).group(1) + "}")
        return {"id": item_id, "slot": item.get("slot"), "class": item.get("classs"),
                "subclass": item.get("subclass"), "level": item.get("level"),
                "reqlevel": item.get("reqlevel") or 0, "quality": item.get("quality", 0)}
    if OFFLINE and f"item:{item_id}" not in cache:
        return game_item(item_id)
    return cached(f"item:{item_id}", get)


WOWSRC = paths.DATA / "wowsrc_loot.json"
ITEM_NAMES = paths.DATA / "item_names.json"
WING_SUFFIX = re.compile(r"^(.*) \((\w+)\)$")   # Dire Maul's "Hydrospawn (East)"
wowsrc_pages = json.loads(WOWSRC.read_text(encoding="utf-8")) if WOWSRC.exists() else {}
item_names = json.loads(ITEM_NAMES.read_text(encoding="utf-8")) if ITEM_NAMES.exists() else {}


def name_key(name):
    """An item name as Tools/data/item_names.json keys it (wowsrc.py's name_key)."""
    return re.sub(r"\s+", " ", (name or "").lower().replace("\u2019", "'")).strip()


def wowsrc_loot(dungeon, report):
    """(wing name or None, boss name lower case) -> {"items": [{id, chance, new}], "complete"}
    from wowsrc.com's Forever loot pages for the dungeon (its "wowsrc": a page's slug, or
    {wing: slug}); "trash" names a wing's trash. complete: every item name on the page is
    mapped to an ID. A boss of theirs we do not list, and a name not mapped, are reported."""
    slugs = dungeon.get("wowsrc")
    if not slugs:
        return {}
    if isinstance(slugs, str):
        slugs = {None: slugs}
    ours = {(w.get("name"), b.lower()) for w in dungeon["wings"]
            for b in w["bosses"] + w.get("rare", []) + w.get("optional", []) + list(w.get("chests", {}))}
    # One page for a dungeon with wings (Blackrock Depths): each boss in its own wing, the
    # trash in the last.
    wing_of = {b: w for w, b in ours}
    last_wing = dungeon["wings"][-1].get("name")
    renamed = {k.lower(): v.lower() for k, v in dungeon.get("wowsrcNames", {}).items()}
    found = {}
    for wing, slug in slugs.items():
        for boss in wowsrc_pages[slug]["bosses"]:
            if not boss["items"]:
                continue   # nothing listed: not known there, not "drops nothing"
            name, where = boss["name"], wing
            suffix = WING_SUFFIX.match(name)
            if suffix and where is None:
                name, where = suffix.group(1), suffix.group(2)
            name = renamed.get(name.lower(), name.lower())
            if where is None and len(slugs) == 1:
                where = last_wing if name == "trash" else wing_of.get(name)
            key = (where, name)
            if name != "trash" and key not in ours:
                report.append(f"wowsrc boss not listed: {boss['name']} ({dungeon['name']})")
                continue
            items, complete = [], True
            for item in boss["items"]:
                item_id = item_names.get(name_key(item["name"]))
                if item_id is None:
                    complete = False
                    report.append(f"wowsrc item not mapped: {item['name']} ({boss['name']}, {dungeon['name']})")
                else:
                    chance = item["chance"]
                    if chance is not None and not 0 < chance <= 100:   # Balzaphon's Chains of the Lich: 127.8%
                        report.append(f"wowsrc chance not a percent: {item['name']} {chance} ({boss['name']})")
                        chance = None
                    items.append({"id": item_id, "chance": chance, "new": item["new"]})
            if key in found:   # two of theirs are one of ours: Doom'rel's and Anger'rel's, the Seven's chest
                found[key]["items"] += items
                found[key]["complete"] = found[key]["complete"] and complete
            else:
                found[key] = {"items": items, "complete": complete}
    return found


def merge_wowsrc(loot, listed):
    """A boss's loot with wowsrc's Forever list for it: its chances where it gives one (the
    game's own), its items added, and an old item it does not list left out (moved in Forever:
    Springvale's Eerie Stable Lantern is trash's now) when the list is complete. An item new
    in Forever that Wowhead ties to the boss stays either way."""
    if not listed:
        return loot
    on_list = {i["id"]: i for i in listed["items"]}
    kept = []
    for item in loot:
        theirs = on_list.pop(item["id"], None)
        if theirs:
            kept.append(dict(item, listed=True, chance=item["chance"] if theirs["chance"] is None else theirs["chance"]))
        elif item.get("new") or not listed["complete"]:
            kept.append(item)
    for theirs in on_list.values():
        facts = item_facts(theirs["id"])
        if facts and facts["quality"] >= MIN_QUALITY and facts["slot"] in EQUIPPABLE:
            kept.append(dict(facts, chance=theirs["chance"], new=theirs["new"], listed=True))
        elif not facts:
            # Not known here (offline, an item neither cache nor tables have): the list is not
            # whole, so what the boss had stays rather than lose loot over it.
            have = {item["id"] for item in kept}
            kept += [item for item in loot if item["id"] not in have]
    kept.sort(key=lambda i: (i["chance"] is None, -(i["chance"] or 0), -i["quality"], i["id"]))
    return kept


def plain(dungeon):
    """Lower case, without a leading "The": the BiS data leaves it off."""
    return re.sub(r"^the ", "", dungeon.lower())


def bis_sources():
    """(dungeon, boss), as plain() and lower case -> item IDs, from the BiS data's sources."""
    text = BIS_DATA.read_text(encoding="utf-8")
    by_boss = {}
    pattern = r'\[(\d+)\] = "(.*?)' + SEP + r'(.*?)"'
    for item_id, boss, where in re.findall(pattern, text[text.index("sources = {"):]):
        by_boss.setdefault((plain(where), boss.lower()), []).append(int(item_id))
    return by_boss


TERRITORY = {0: "Alliance", 1: "Horde"}   # anything else is open to both
# One zone in the list: its ID, name and territory, in that order in the JSON.
ZONE_ROW = re.compile(r'\{"category":[^{}]*?"id":(\d+),[^{}]*?"name":"([^"]*)"[^{}]*?"territory":(\d+)')


def zones():
    """Wowhead zone ID -> (name, territory), from Wowhead Forever's zone list."""
    def get():
        page = fetch(f"{WOWHEAD}/zones")
        found = {}
        for m in ZONE_ROW.finditer(page):
            found.setdefault(m.group(1), [m.group(2), int(m.group(3))])
        return found
    return cached("zones", get)


def guide_drops(slug):
    """Boss name (lower case) -> its items, from the guide's Loot tabs."""
    by_boss = {}
    for item in cached(f"guide:{slug}", lambda: guide_loot(slug)):
        by_boss.setdefault(item["boss"].lower(), []).append(dict(item, chance=None))
    return by_boss


def boss_entry(name, rare, pinned, extra, items, report, listed=None, kind=None, chest=None):
    """A boss's entry; kind "optional" for one a run can skip (an event, a summon), "quest" for
    one there only for a quest, "chest" for a chest (its Wowhead object ID in chest)."""
    if kind == "chest":
        loot = merge_wowsrc(chest_drops(chest), listed)
        for item in loot:
            items[item["id"]] = item
        if not loot:
            report.append(f"no loot: {name} (object {chest})")
        return {"npc": None, "name": name, "rare": False, "chest": chest, "loot": loot}
    npc = pinned.get(name) or find_npc(name)
    loot = merge_wowsrc(npc_drops(npc) if npc else [], listed)
    have = {i["id"] for i in loot}
    for item in extra.get(name.lower(), []):
        if item["id"] not in have and item["quality"] >= MIN_QUALITY and item["slot"] in EQUIPPABLE:
            loot.append(dict(item, chance=None))
            have.add(item["id"])
    if not npc:
        report.append(f"no NPC found: {name}")
    elif not loot:
        report.append(f"no loot: {name} ({npc})")
    for item in loot:
        items[item["id"]] = item
    return {"npc": npc, "name": name, "rare": rare, "optional": kind == "optional", "quest": kind == "quest",
            "loot": loot, "model": npc_model(npc) if npc else None}


tables = {}


def db2_rows(table, fields):
    """The game's table for BUILD, each row as a list of the fields asked for. Read once per
    run and not cached: what is taken from it is, so the cache keeps only the Journal's rows."""
    if table not in tables:
        rows = csv.DictReader(io.StringIO(fetch(WAGO.format(table))))
        tables[table] = [[row[f] for f in fields] for row in rows]
    return tables[table]


def match_name(name):
    """A name as the encounter join compares it: no case, punctuation or leading "The"."""
    name = re.sub(r"^the ", "", name.lower().replace("\u2019", "'"))
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", "", name)).strip()


def map_encounters(map_id):
    """The 5-player encounters in an instance, [ID, name, difficulty]."""
    def get():
        rows = db2_rows("DungeonEncounter", ("ID", "Name_lang", "MapID", "DifficultyID"))
        return [[int(e), name, d] for e, name, m, d in rows if m == map_id and d in DUNGEON_DIFFICULTIES]
    return cached(f"encounters:{BUILD}:{map_id}", get) if map_id else []


def instance_maps():
    """Dungeon name -> its instance map ID: Data/Quests.lua's, else the Map table's by name."""
    text = QUESTS.read_text(encoding="ascii")
    maps = {m.group(1): m.group(2) for m in re.finditer(r'\{ name = "((?:[^"\\]|\\.)*)", map = (\d+),', text)}

    def by_name(dungeon):
        def get():
            want = match_name(dungeon)
            return next((m for m, name in db2_rows("Map", ("ID", "MapName_lang")) if match_name(name) == want), None)
        return cached(f"map:{BUILD}:{dungeon}", get)
    return lambda dungeon: maps.get(dungeon) or by_name(dungeon)


def boss_encounters(name, renamed, encounters):
    """The boss's encounter IDs, the one firing on any difficulty first, then by ID."""
    want = match_name(renamed.get(name, name))
    rows = [e for e in encounters if match_name(e[1]) == want]
    rows.sort(key=lambda e: (DUNGEON_DIFFICULTIES.index(e[2]), e[0]))
    return [e[0] for e in rows]


def chance(item):
    """Whole percent, at least 1; 0 when the chance is not known."""
    return "0" if item["chance"] is None else str(max(1, round(item["chance"])))


def lua_boss(boss):
    fields = [f"npc = {boss['npc'] or 'nil'}", f"name = {lua_string(boss['name'])}"]
    if boss.get("model"):
        fields.append(f"model = {boss['model']}")
    if boss["rare"]:
        fields.append("rare = true")
    if boss.get("optional"):
        fields.append("optional = true")
    if boss.get("quest"):
        fields.append("quest = true")
    if boss.get("chest"):
        fields.append(f"chest = {boss['chest']}")
    if boss.get("trash"):
        fields.append("trash = true")
    if boss["encounters"]:
        fields.append("encounters = { " + ", ".join(str(e) for e in boss["encounters"]) + " }")
    if boss.get("with"):
        fields.append(f"with = {lua_string(boss['with'])}")
    if boss["loot"]:
        fields.append("loot = { " + ", ".join(str(i["id"]) for i in boss["loot"]) + " }")
        if any(i["chance"] is not None for i in boss["loot"]):
            fields.append("chance = { " + ", ".join(chance(i) for i in boss["loot"]) + " }")
    return "{ " + ", ".join(fields) + " }"


def write(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))


def header(name, what):
    """A generated Lua file's start: its one-line header comment (the house style allows no
    other comment), then the addon's namespace."""
    return [f"-- {name}: {what}.", "local ns = _G.NaowhForever", ""]


def dungeon_file(dungeon, wings, zone_names):
    lines = header(f"{dungeon['key']}.lua",
                   f"{dungeon['name']} in the Dungeon Journal, generated by Tools/build/journal.py")
    lines += [f"ns.Journal.AddDungeon({lua_string(dungeon['key'])}, {{",
              f"    name = {lua_string(dungeon['name'])},"]
    if dungeon.get("new"):
        lines.append("    new = true,")
    if dungeon.get("raid"):
        lines.append(f"    raid = {dungeon['raid']},")
    if dungeon.get("note"):
        lines.append(f"    note = {lua_string(dungeon['note'])},")
    if dungeon.get("closed"):
        lines.append("    closed = true,")
    zone = zone_names.get(str(dungeon["entranceZone"]))
    if zone:
        territory = TERRITORY.get(zone[1], "Contested")
        lines.append(f"    zone = {lua_string(zone[0])}, territory = {lua_string(territory)},")
    entrance = dungeon.get("entrance")
    if entrance:
        lines.append(f"    entrance = {{ map = {entrance['map']}, x = {entrance['x']}, y = {entrance['y']} }},")
    lines.append("    wings = {")
    for wing in wings:
        name = f"name = {lua_string(wing['name'])}, " if wing.get("name") else ""
        lines.append(f"        {{ {name}bosses = {{")
        lines += [f"            {lua_boss(boss)}," for boss in wing["bosses"]]
        lines.append("        } },")
    lines += ["    },", "})"]
    return lines


def ascii_string(s):
    return "".join(c if ord(c) < 128 else "".join(f"\\{b}" for b in c.encode("utf-8")) for c in lua_string(s))


def not_yet_facts(item_id):
    found = era_tables().get(str(item_id))
    if not found:
        return None
    item, sparse = found
    facts = {"id": item_id, "class": int(item["ClassID"]), "subclass": int(item["SubclassID"]),
             "level": int(sparse["ItemLevel"]), "reqlevel": int(sparse["RequiredLevel"] or 0),
             "quality": int(sparse["OverallQualityID"])}
    return facts, sparse["Display_lang"], int(item["IconFileDataID"] or 0)


def items_file(items, not_yet):
    # Items: the ones in Forever, the shared list (Shared/Data/ItemFacts.lua). NotYet: the items not
    # in Forever yet, which the client cannot load: { class, subclass, item level, required level,
    # quality }, then their icon and name, from Classic Era's tables.
    lines = header("Items.lua", "the Journal's items not in Forever yet, generated by Tools/build/journal.py")
    lines.append("ns.Journal.Items = ns.Shared.ItemFacts")
    lines.append("ns.Journal.NotYet = {")
    for item_id in sorted(not_yet):
        item, name, icon = not_yet[item_id]
        cls, sub = kind(item)
        lines.append(f"    [{item_id}] = {{ {cls}, {sub}, {item['level']}, {item['reqlevel']}, {item['quality']}, "
                     f"{icon}, {ascii_string(name)} }},")
    lines.append("}")
    return lines


def item_facts_file(items):
    # [itemID] = { class, subclass, item level, required level, quality }, with class and subclass
    # the game's (2 weapon, 4 armor; 0 no armor type): the Dungeon Journal's loot, its BiS List
    # levels and the Naowh Score's best read the same list.
    lines = header("ItemFacts.lua",
                   "each dungeon item's facts before the client loads it, generated by Tools/build/journal.py")
    lines.append("ns.Shared.ItemFacts = {")
    for item_id in sorted(items):
        item = items[item_id]
        cls, sub = kind(item)
        lines.append(f"    [{item_id}] = {{ {cls}, {sub}, {item['level']}, {item['reqlevel']}, {item['quality']} }},")
    lines.append("}")
    return lines


def extra_loot(dungeon, bis):
    """Boss name (lower case) -> the items the guide, the BiS sources and the dungeon's own
    "add" list (by hand: items seen dropping that Wowhead has not tied to the boss yet) place
    on it."""
    extra = guide_drops(dungeon["guide"]) if dungeon.get("guide") else {}
    for boss, ids in dungeon.get("add", {}).items():
        for item_id in ids:
            if not isinstance(item_id, int):
                sys.exit(f"journal_bosses.json, {dungeon['name']}, {boss}: \"add\" takes item IDs, not {item_id!r}")
            facts = item_facts(item_id)
            if facts:
                extra.setdefault(boss.lower(), []).append(dict(facts, chance=None))
    here = plain(dungeon["name"])
    for (where, boss), ids in bis.items():
        # The BiS data names both of Blackrock Spire's halves after the whole spire.
        if where == here or (where == "blackrock spire" and here.endswith("blackrock spire")):
            extra.setdefault(boss, []).extend(item_facts(i) for i in ids)
    return extra


def shared_drops(built):
    npcs = {}
    for key, found in cache.items():
        if key.startswith("drops5:") and isinstance(found, dict):
            for item in found["items"]:
                if item["new"]:
                    npcs.setdefault(item["id"], set()).add(key)
    shared = {i for i, found in npcs.items() if len(found) >= SHARED_DROP}
    for _, wings in built:
        for boss in (b for w in wings for b in w["bosses"]):
            boss["loot"] = [item for item in boss["loot"]
                            if item["id"] not in shared or item.get("listed") or "count" not in item]
    return shared


def opened(built, map_of):
    have, total = {}, {}
    tables = game_tables()
    for dungeon, wings in built:
        where = map_of(dungeon["name"]) or dungeon["key"]
        for boss in (b for w in wings for b in w["bosses"] if not b.get("trash")):
            have[where] = have.get(where, 0) + sum(1 for i in boss["loot"] if str(i["id"]) in tables)
            total[where] = total.get(where, 0) + len(boss["loot"])
    for dungeon, wings in built:
        where = map_of(dungeon["name"]) or dungeon["key"]
        share = have.get(where, 0) / total[where] if total.get(where) else 0
        yield dungeon, wings, dungeon.get("open", share >= OPEN_SHARE)


def main():
    config = json.loads(BOSSES.read_text(encoding="utf-8"))
    bis = bis_sources()
    zone_names = zones()
    map_of = instance_maps()
    items, report, files, built = {}, [], [], []
    for dungeon in config["dungeons"]:
        if dungeon.get("announced") is False:
            continue   # a raid not announced for Forever: kept in the list, not built
        extra = extra_loot(dungeon, bis)
        pinned = dungeon.get("npcs", {})
        renamed = dungeon.get("encounterNames", {})
        pinned_encounters = dungeon.get("encounterIDs", {})
        counted_with = dungeon.get("countedWith", {})
        encounters = map_encounters(map_of(dungeon["name"]))
        listed = wowsrc_loot(dungeon, report)
        wings = []
        for wing in dungeon["wings"]:
            # No loot for one whose drops are not known: its items go to a list nobody reads.
            kept = items if dungeon.get("loot", True) else {}
            here = wing.get("name")
            quest = wing.get("quest", [])
            bosses = [boss_entry(n, False, pinned, extra, kept, report, listed.get((here, n.lower())),
                                 "quest" if n in quest else None)
                      for n in wing["bosses"]]
            bosses += [boss_entry(n, True, pinned, extra, kept, report, listed.get((here, n.lower())))
                       for n in wing.get("rare", [])]
            bosses += [boss_entry(n, False, pinned, extra, kept, report, listed.get((here, n.lower())), "optional")
                       for n in wing.get("optional", [])]
            bosses += [boss_entry(n, False, pinned, extra, kept, report, listed.get((here, n.lower())), "chest", o)
                       for n, o in wing.get("chests", {}).items()]
            # The wing's trash, last: what its other mobs drop, by wowsrc's list.
            trash = merge_wowsrc([], (listed.get((here, "trash")) or {"items": [], "complete": True}))
            if here == dungeon["wings"][-1].get("name"):   # placed by hand ("add": { "Trash": [...] })
                # An item can be placed twice (by hand and as a BiS source, the Stockade's
                # Defias Renegade Ring): listed once.
                have = {i["id"] for i in trash}
                for i in extra.get("trash", []):
                    if i["id"] not in have and i["quality"] >= MIN_QUALITY and i["slot"] in EQUIPPABLE:
                        have.add(i["id"])
                        trash.append(dict(i, chance=None))
            trash = {"npc": None, "name": "Trash", "rare": False, "trash": True, "loot": trash}
            if trash["loot"]:
                for item in trash["loot"]:
                    kept[item["id"]] = item
                bosses.append(trash)
            if not dungeon.get("loot", True):
                for boss in bosses:
                    boss["loot"] = []
            for boss in bosses:
                boss["encounters"] = [] if boss.get("trash") or boss.get("chest") else (
                    boss_encounters(boss["name"], renamed, encounters) or pinned_encounters.get(boss["name"], []))
            # A boss killed on the way into another's fight counts with that fight.
            for boss in bosses:
                other = counted_with.get(boss["name"])
                if other:
                    fight = next(b for b in bosses if b["name"] == other)
                    boss["encounters"], boss["with"] = fight["encounters"], other
                if not boss["encounters"] and not (boss["rare"] or boss.get("optional") or boss.get("trash")
                                                   or boss.get("chest")):
                    report.append(f"no encounter: {boss['name']} ({dungeon['name']})")
            wings.append({"name": wing.get("name"), "bosses": bosses})
        built.append((dungeon, wings))
        save_cache()
    shared = shared_drops(built)
    if shared:
        report.append("dropped by many bosses, left out: " + ", ".join(str(i) for i in sorted(shared)))
    not_yet, nameless = {}, set()
    for dungeon, wings in built:
        for wing in wings:
            for boss in wing["bosses"]:
                for item in boss["loot"]:
                    if not known(item["id"]) and item["id"] not in not_yet:
                        found = not_yet_facts(item["id"])
                        if found:
                            not_yet[item["id"]] = found
                        else:
                            nameless.add(item["id"])
                boss["loot"] = [item for item in boss["loot"] if item["id"] not in nameless]
            wing["bosses"] = [b for b in wing["bosses"] if b["loot"] or not b.get("trash")]
        here = {item["id"] for wing in wings for b in wing["bosses"] for item in b["loot"]}
        later = sorted(here & set(not_yet))
        if later:
            report.append(f"not in Forever yet, listed from Classic Era: {len(later)} items ({dungeon['name']}): "
                          + ", ".join(str(i) for i in later))
    if nameless:
        report.append("not in Forever nor Classic Era's tables, left out: " + ", ".join(str(i) for i in sorted(nameless)))
    for dungeon, wings, is_open in opened(built, map_of):
        dungeon["closed"] = not is_open and dungeon.get("loot", True)
        if dungeon["closed"]:
            report.append(f"not open yet: {dungeon['name']}")
        name = f"{dungeon['key']}.lua"
        write(OUT / "Data" / "Dungeons" / name, dungeon_file(dungeon, wings, zone_names))
        files.append(name)
        count = sum(len(b["loot"]) for w in wings for b in w["bosses"])
        print(f"{count:5d}  {dungeon['name']}", file=sys.stderr)
    used = {item["id"] for _, wings in built for w in wings for b in w["bosses"] for item in b["loot"]}
    items = {i: item for i, item in items.items() if known(i) and i in used}
    not_yet = {i: found for i, found in not_yet.items() if i in used}
    write(OUT / "Data" / "Items.lua", items_file(items, not_yet))
    write(ROOT / "Shared" / "Data" / "ItemFacts.lua", item_facts_file(items))
    print(f"{len(items)} items in Forever, {len(not_yet)} not yet, {len(files)} dungeons", file=sys.stderr)
    for line in report:
        print(f"  {line}", file=sys.stderr)
    if offline_missed:
        print(f"Offline, {len(offline_missed)} answers were not in the cache nor the game's tables "
              "(run it on your machine for them): " + ", ".join(sorted(set(offline_missed))), file=sys.stderr)
    print("DungeonJournal.xml lines:\n" + "\n".join(f'    <Script file="Data\\Dungeons\\{f}"/>' for f in files))


if __name__ == "__main__":
    main()
