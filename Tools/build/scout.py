"""Build Scout's data: what a creature casts, its armor, resistances and immunities, and which beasts a
hunter can tame, for the creatures of every open-world zone and Dungeon Journal instance.

The creatures come from the zone pages of Wowhead Forever (Tools/data/scout.json, "zones"): the ones
some faction can attack, other than critters, and the bosses the Journal names by NPC ID (an
instance Wowhead has no zone page for has only those), with the tameable beasts players have found that
the zone pages leave out or the database calls untameable (Tools/data/scout_beasts.json). A zone's page is
read once and kept; --refresh-zones reads every zone's page again, for the creatures Wowhead has added
since. Their stats come from the CMaNGOS classic database
(github.com/cmangos/classic-db, GPL-3.0), downloaded each run (or --dump FILE):
  - what a creature casts: the spells its EventAI scripts cast (action 11), leaving out the events
    that are not a fight (it spawns, is out of combat, evades, reaches home, a quest or an emote), and
    its spell list;
  - Armor, the six Resistance columns, MechanicImmuneMask and SchoolImmuneMask;
  - tameable: CreatureTypeFlags bit 1.
A creature the database lacks (Forever's new ones) or whose spells are in the server's code (most
instance bosses: ScriptName) takes what Wowhead's creature page says it casts, read by --fetch-gaps
into the cache, one page at a time. The beasts of scout_beasts.json have their page read too, and a
beast is tameable when either the database or its page says so (Forever made some classic beasts
tameable).

The spells are cleaned with the game's own SpellName table: a spell the client has no name for,
spells the scripts or Wowhead put on creatures that never cast them (NOISE), a creature's spell to
summon itself and all but the newest spell of a name are dropped.

Armor by level is the game's ExpectedStat (classic rows, ExpansionID -2), for a creature the
database lacks.

Writes NaowhForever_QoL/Combat/ScoutData.lua: abilities, tameable beasts and stats packed as
glimmer_nodes.pack does (CBOR deflated in Base64, decoded by the client when Scout first needs
them), and the armor by level as a plain list.

Usage: python Tools/build/scout.py [--dump FILE] [--fetch-gaps] [--refresh-zones]
"""
import argparse
import collections
import gzip
import json
import re
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
import wowhead  # noqa: E402
from glimmer_nodes import pack  # noqa: E402
from journal import ROOT, header, write  # noqa: E402
from quest_chains import ZONE_MAP  # noqa: E402

OUT = ROOT / "NaowhForever_QoL" / "Combat" / "ScoutData.lua"
CACHE = paths.DATA / "scout.json"
DUNGEONS = paths.DATA / "journal_bosses.json"
BEASTS = paths.DATA / "scout_beasts.json"
# Open-world zones ZONE_MAP has no uiMapID for: Mount Hyjal, Riverglades, Shen'dralas (AreaTable IDs,
# which are Wowhead's zone IDs).
MORE_ZONES = {616, 16591, 16651}
DUMP_URL = "https://raw.githubusercontent.com/cmangos/classic-db/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
DUMP = Path(tempfile.gettempdir()) / "cmangos_classic_db.sql.gz"
CLASSIC = "-2"
MAX_LEVEL = 63
FRIENDLY = 1
CRITTER = 8
CAST_SPELL = "11"
NOT_A_FIGHT = {"1", "7", "10", "11", "17", "19", "20", "21", "22", "25", "26"}
STRING = r"'(?:[^'\\]|\\.|'')*'"
TUPLE = re.compile(rf"\(((?:{STRING}|[^')])*)\)")
FIELD = re.compile(rf"{STRING}|[^,]+")
TAMEABLE_FLAG = 1
RESISTANCES = ("ResistanceHoly", "ResistanceFire", "ResistanceNature", "ResistanceFrost", "ResistanceShadow",
               "ResistanceArcane")
NOISE_SPELLS = {403233}
NOISE_NAMES = {"Dazed", "Camp Benefits", "Boosted Rest"}
TAMEABLE = re.compile(r"\[li\]Tameable \(")
ABILITY = re.compile(r'"id":(\d+),.*?"name":"((?:[^"\\]|\\.)*)"')
SAVE_EVERY = 50
PAUSE = 4     # seconds on top of wowhead.fetch's own: its CDN answers 403 to anything quicker, for hours
COOL_OFF = 900
COOL_OFFS = 12
BLOCKED = (403, 429, 503)


def load():
    return json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {"zones": {}, "npcs": {}}


def save(cache):
    CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True), encoding="utf-8", newline="\r\n")


def instances():
    dungeons = json.loads(DUNGEONS.read_text(encoding="utf-8"))["dungeons"]
    return {d["zone"] for d in dungeons if d.get("zone")}


def instance_npcs():
    """{ npcID: name } of the bosses the Journal names by ID, so an instance with no zone page on
    Wowhead (Forever's new ones, the raids) still has its bosses looked up."""
    dungeons = json.loads(DUNGEONS.read_text(encoding="utf-8"))["dungeons"]
    return {npc: name for d in dungeons for name, npc in (d.get("npcs") or {}).items()}


def zones():
    return sorted(set(ZONE_MAP) | MORE_ZONES | instances())


def beasts():
    """{ npcID: name } of the beasts read from Wowhead whatever the zone pages and the database say."""
    return {int(npc): name for npc, name in json.loads(BEASTS.read_text(encoding="utf-8")).items()}


def attackable(row):
    react = [r for r in row.get("react") or [] if r is not None]
    return row.get("type") != CRITTER and any(r != FRIENDLY for r in react)


def fetch_zone(area):
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/zone={area}")
    return [{"id": row["id"], "name": row["name"]} for row in wowhead.listview(page, "npcs") if attackable(row)]


def fetch_npc(npc):
    """{ "abilities": [[spell ID, name], ...], "tameable": bool } from the creature's Wowhead page."""
    page = wowhead.fetch(f"{wowhead.WOWHEAD}/npc={npc}")
    time.sleep(PAUSE)
    abilities = []
    start = page.find("id: 'abilities'")
    if start >= 0:
        data = page.find("data:", start)
        chunk = page[data:page.find("});", data)]
        for row in re.split(r"\},\{", chunk):
            m = ABILITY.search(row)
            if m:
                abilities.append([int(m.group(1)), json.loads('"' + m.group(2) + '"')])
    return {"abilities": abilities, "tameable": TAMEABLE.search(page) is not None}


def patient(read, key, cache):
    """read(key), waiting out Wowhead's block (saving first) when it refuses even wowhead.fetch's retries."""
    for attempt in range(COOL_OFFS + 1):
        try:
            return read(key)
        except urllib.error.HTTPError as error:
            if error.code not in BLOCKED or attempt == COOL_OFFS:
                raise
            save(cache)
            print(f"  blocked ({error.code}); waiting {COOL_OFF // 60} minutes", file=sys.stderr)
            time.sleep(COOL_OFF)


def download(path):
    print(f"downloading {DUMP_URL}", file=sys.stderr)
    with urllib.request.urlopen(DUMP_URL, timeout=120) as r:
        path.write_bytes(r.read())


def dump_text(path, fetch=download):
    """The dump's text, downloading it first when it is missing or a download was cut short."""
    for attempt in (1, 2):
        if not path.exists():
            fetch(path)
        try:
            with gzip.open(path, "rb") as dump:
                return dump.read().decode("latin-1")
        except (EOFError, gzip.BadGzipFile, OSError):
            if attempt == 2:
                raise
            path.unlink()


def columns(sql, table):
    m = re.search(rf"CREATE TABLE `{table}` \((.*?)\) ENGINE", sql, re.S)
    return re.findall(r"^\s+`(\w+)`", m.group(1), re.M)


def values(line):
    """The tuples of an INSERT ... VALUES (...),(...); line, each as a list of its raw fields."""
    return [FIELD.findall(m.group(1)) for m in TUPLE.finditer(line[line.index("VALUES") + 6:])]


def rows(sql, table):
    names = columns(sql, table)
    prefix = f"INSERT INTO `{table}`"
    for line in sql.split("\n"):
        if line.startswith(prefix):
            for fields in values(line):
                if len(fields) != len(names):
                    raise ValueError(f"{table}: a row of {len(fields)} fields for {len(names)} columns")
                yield dict(zip(names, (f.strip("'") for f in fields)))


def database(sql):
    """({ creature ID: its stats }, { creature ID: set of spell IDs it casts }, scripted creature IDs)."""
    stats, scripted = {}, set()
    lists = collections.defaultdict(set)
    for row in rows(sql, "creature_spell_list"):
        lists[row["Id"]].add(int(row["SpellId"]))
    casts = collections.defaultdict(set)
    for row in rows(sql, "creature_ai_scripts"):
        for n in (1, 2, 3):
            if row.get(f"action{n}_type") == CAST_SPELL and row["event_type"] not in NOT_A_FIGHT:
                casts[int(row["creature_id"])].add(int(row[f"action{n}_param1"]))
    for row in rows(sql, "creature_template"):
        npc = int(row["Entry"])
        stats[npc] = {
            "armor": int(row["Armor"]), "school": int(row["SchoolImmuneMask"]),
            "mechanic": int(row["MechanicImmuneMask"]),
            "resist": [max(0, int(row[name])) for name in RESISTANCES],
            "tameable": int(row["CreatureTypeFlags"]) & TAMEABLE_FLAG != 0,
        }
        if row["SpellList"] != "0":
            casts[npc] |= lists.get(row["SpellList"], set())
        if row["ScriptName"]:
            scripted.add(npc)
    return stats, casts, scripted


def cleaned(name, spells, names):
    """The spell IDs worth listing for a creature called name: the newest of each spell name, with a name
    in the game's own table, leaving out the noise and the creature's own summoning."""
    newest = {}
    for spell in spells:
        spell_name = names.get(spell)
        if not spell_name or spell in NOISE_SPELLS or spell_name in NOISE_NAMES or spell_name == f"Summon {name}":
            continue
        if spell > newest.get(spell_name, 0):
            newest[spell_name] = spell
    return sorted(newest.values())


def armor():
    rows_ = {int(r["Lvl"]): r for r in wago.table("ExpectedStat") if r["ExpansionID"] == CLASSIC}
    return [int(round(float(rows_[level]["CreatureArmor"]))) for level in range(1, MAX_LEVEL + 1)]


def creatures(cache, refresh=False):
    names, first = {}, set()
    for area in zones():
        key = str(area)
        if refresh or key not in cache["zones"]:
            cache["zones"][key] = patient(fetch_zone, area, cache)
            save(cache)
        for row in cache["zones"][key]:
            names[row["id"]] = row["name"]
            if area in instances():
                first.add(row["id"])
    for npc, name in instance_npcs().items():
        names.setdefault(npc, name)
        first.add(npc)
    return names, first


def stat_row(s):
    if s["armor"] or s["school"] or s["mechanic"] or any(s["resist"]):
        return [s["armor"], s["school"], s["mechanic"], *s["resist"]]
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dump", type=Path, default=DUMP, help="the CMaNGOS classic-db dump (downloaded if missing)")
    parser.add_argument("--fetch-gaps", action="store_true",
                        help="read Wowhead's page of each creature the database leaves without spells")
    parser.add_argument("--refresh-zones", action="store_true",
                        help="read every zone's page again instead of keeping the cached one")
    args = parser.parse_args()
    cache = load()
    names, first = creatures(cache, args.refresh_zones)
    found = beasts()
    for npc, name in found.items():
        names.setdefault(npc, name)
    stats, casts, scripted = database(dump_text(args.dump))
    spell_names = {int(r["ID"]): r["Name_lang"] for r in wago.table("SpellName")}

    gaps = sorted((npc for npc in names
                   if npc in found or not casts.get(npc) and (npc not in stats or npc in scripted)),
                  key=lambda npc: (npc not in found, npc not in first, npc))
    todo = [npc for npc in gaps if str(npc) not in cache["npcs"]]
    print(f"{len(names)} creatures; {len(gaps)} with no spells in the database ({len(todo)} not read from "
          f"Wowhead yet)", file=sys.stderr)
    if args.fetch_gaps:
        for i, npc in enumerate(todo, 1):
            cache["npcs"][str(npc)] = patient(fetch_npc, npc, cache)
            if i % SAVE_EVERY == 0:
                save(cache)
                print(f"  {i}/{len(todo)}", file=sys.stderr)
        save(cache)

    abilities, tameable, creature_stats, common = {}, set(), {}, collections.Counter()
    for npc, name in names.items():
        spells = set(casts.get(npc, ()))
        page = cache["npcs"].get(str(npc))
        if not spells and page:
            spells = {spell for spell, _ in page["abilities"]}
        listed = cleaned(name, spells, spell_names)
        if listed:
            abilities[npc] = listed
            common.update(listed)
        if stats.get(npc, {}).get("tameable") or (page and page["tameable"]):
            tameable.add(npc)
        if npc in stats and stat_row(stats[npc]):
            creature_stats[npc] = stat_row(stats[npc])
    lines = header("ScoutData.lua", "Scout's creature abilities, tameable beasts and stats (armor, immunities, "
                   "resistances), packed, from the CMaNGOS classic database and Wowhead Forever, and creature "
                   "armor by level (the game's ExpectedStat), generated by Tools/build/scout.py")
    lines += [f'ns.ScoutAbilitiesPacked = "{pack(abilities)}"',
              f'ns.ScoutTameablePacked = "{pack({0: sorted(tameable)})}"',
              f'ns.ScoutStatsPacked = "{pack(creature_stats)}"',
              "ns.ScoutArmor = { " + ", ".join(str(a) for a in armor()) + " }"]
    write(OUT, lines)
    left = [npc for npc in gaps if npc not in abilities]
    print(f"{len(abilities)} creatures with abilities, {len(creature_stats)} with stats, {len(tameable)} tameable;"
          f" {len(left)} gaps still without abilities", file=sys.stderr)
    print("most shared spells:", [(s, spell_names.get(s), n) for s, n in common.most_common(12)], file=sys.stderr)


if __name__ == "__main__":
    main()
