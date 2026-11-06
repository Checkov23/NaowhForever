"""Build NaowhForever_DungeonJournal/Data/BiSQuests.lua: every quest that rewards an item a BiS ranking lists,
for the BiS List's Quests page, as the Dungeon Journal's quest records.

Which quests reward a ranked item, and whether it is one to choose, come from ForeverChanges' quest
list (foreverchanges_quests.json, from Tools/build/foreverchanges_quests.py), with each quest's name,
levels, side and class. Every ranked item is looked up, not only the ones whose source says Quest: a
source names one way to get an item, and a drop wins over a quest. A quest starts at its giver there,
on Forever's own maps, picked as Tools/build/completo_quests.py picks it; without one, where its
Wowhead Forever page maps its quest giver, or the item that starts it. That page also says whether
the quest can be shared; pages are cached in bis_quest_pages.json (delete an entry to fetch it
again), and --offline reads none. A quest's races are the ones Wowhead's item pages gave it, as
bis_quests.json kept them (those pages are no longer read), else quest_entity_catalog.json's.

Run Tools/build/foreverchanges_quests.py before it, and Tools/build/quest_chains.py after it: that
reads this file's quests too, for their chains, what to do first and the level they need.

Usage: python Tools/build/bis_quests.py [--offline]
"""
import json
import re
import sys
import time
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
from bis_data import WOWHEAD, current_specs, fetch, lua_string  # noqa: E402
from completo_quests import listed_spot  # noqa: E402
from quest_chains import REDRAWN, ZONE_MAP  # noqa: E402

ROOT = paths.ROOT
OUT = ROOT / "NaowhForever_DungeonJournal" / "Data" / "BiSQuests.lua"
LISTED = paths.DATA / "foreverchanges_quests.json"
ITEMS = paths.DATA / "bis_quests.json"
PAGES = paths.DATA / "bis_quest_pages.json"
CATALOG = paths.DATA / "quest_entity_catalog.json"
JOURNAL = paths.DATA / "journal_cache.json"   # its "zones": Wowhead's zone names

SIDES = {1: "A", 2: "H"}
CLASSES = {1: "WARRIOR", 2: "PALADIN", 4: "HUNTER", 8: "ROGUE", 16: "PRIEST", 64: "SHAMAN", 128: "MAGE",
           256: "WARLOCK", 1024: "DRUID"}
# The playable races' bits (the client's ChrRaces.PlayableRaceBit), Forever's Skyborne at 32 and 33.
RACES = {1: "Human", 2: "Orc", 4: "Dwarf", 8: "Night Elf", 16: "Undead", 32: "Tauren", 64: "Gnome", 128: "Troll",
         1 << 32: "Skyborne", 1 << 33: "Skyborne"}
SIDE_RACES = {1: 1 | 4 | 8 | 64 | 1 << 32, 2: 2 | 16 | 32 | 128 | 1 << 33}


def race_limit(mask, side):
    """The races a quest is limited to, or None when it takes every race of its side."""
    if not mask:
        return None
    sides = [SIDE_RACES[s] for s in (1, 2) if side in (s, 3)]
    if all(mask & races == races for races in sides):
        return None
    names = list(dict.fromkeys(bits(mask, RACES)))
    return ", ".join(names) + " only" if names else None


def load(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save(path, data):
    path.write_text(json.dumps(data, indent=1, sort_keys=True), encoding="utf-8")


def rewarding(listed, ranked):
    """questID -> (its row in the list, the ranked items it rewards, whether those are a choice among
    its rewards), for every quest the list has that rewards a ranked item."""
    out = {}
    for key, q in listed["quests"].items():
        given = sorted(ranked.intersection(q["rewards"] + q["choices"]))
        if given:
            out[int(key)] = (q, given, bool(ranked.intersection(q["choices"])))
    return out


def quest_page(quest_id):
    """Where the quest starts and whether it can be shared, from its page."""
    page = fetch(f"{WOWHEAD}/quest={quest_id}")
    time.sleep(1)
    start = None
    mapper = re.search(r"new Mapper\((\{.*?\})\);", page, re.S)
    objectives = (json.loads(mapper.group(1)).get("objectives") or {}) if mapper else {}
    for zone, objective in objectives.items():
        for level in objective.get("levels", []):
            for point in level:
                if not start and point.get("point") == "start" and len(point.get("coord") or ()) == 2:
                    start = {"zone": int(zone), "zoneName": objective.get("zone"), "coord": point["coord"],
                             "npc": point.get("name") or ""}
    item = re.search(r"Start: \[url=\\/forever\\/item=(\d+)[^\]]*\]([^\[]*)\[", page)
    shared = re.search(r"\[li\](Sharable|Not sharable)", page)
    return {"start": start, "item": item.group(2) if item else None,
            "shareable": None if not shared else shared.group(1) == "Sharable"}


def bits(mask, names):
    return [name for bit, name in names.items() if mask & bit]


def write(quests, starts, pages, races, zone_names):
    """quests as rewarding gives them; starts, the list's givers by questID; pages, the Wowhead
    pages; races, questID -> its race mask; zone_names, uiMapID -> its zone's name."""
    records, zones = [], {}
    for quest_id, (q, _, _) in quests.items():
        page = pages.get(f"quest={quest_id}") or {}
        start = page.get("start")
        classes = bits(q["reqclass"], CLASSES)
        limits = []
        if len(classes) > 1:
            limits.append(", ".join(c.capitalize() for c in classes) + " only")
        reqrace = races.get(quest_id, 0)
        limit = race_limit(reqrace, q["side"])
        if limit:
            limits.append(limit)
        category = q["category"]
        given = listed_spot(starts.get(str(quest_id)),
                            ZONE_MAP.get(category[1]) if category and category[0] == "zone" else None)
        spot = None
        if start and len(start["coord"]) != 2:
            start = None   # a page that maps its quest giver with half a spot
        if given:
            map_id, x, y, giver = given
            x, y = round(x, 1), round(y, 1)
            where = f"{zone_names[map_id]} - {giver} ({x:g}, {y:g})"
            spot = (map_id, x, y)
            zones[quest_id] = zone_names[map_id]
        elif start:
            x, y = start["coord"]
            where = f"{start['zoneName']} - {start['npc']} ({x:g}, {y:g})"
            map_id = ZONE_MAP.get(start["zone"])
            if map_id and map_id not in REDRAWN:
                spot = (map_id, x, y)
            zones[quest_id] = start["zoneName"]
        elif page.get("item"):
            where = f"Starts from an item: {page['item']}"
        else:
            where = "Where it starts is not known yet"
        if limits:
            where += " (" + "; ".join(limits) + ")"
        records.append((q["level"] or q["reqlevel"], quest_id, q, page.get("shareable"), where, spot,
                        classes[0] if len(classes) == 1 else None, reqrace if limit else None))
    records.sort(key=lambda r: (r[0], r[1]))

    # BiSQuestData.quests: Data/Quests.lua's records, { questID, name, level, side, shareable,
    # where it starts, uiMapID, x, y; class; races, a mask of the races that can take it, by
    # ChrRaces.PlayableRaceBit }; a quest the Journal lists already is swapped for its record
    # there. Its chain, what to do first and the level it needs are in Data/QuestChains.lua.
    # BiSQuestRewards: questID -> the ranked items it rewards. BiSQuestChoices: the quests where
    # those are a choice among its rewards. BiSQuestZones: questID -> the zone it starts in.
    lines = [
        "-- BiSQuests.lua: the quests that reward a BiS, generated by Tools/build/bis_quests.py.",
        "local J = _G.NaowhForever.Journal",
        "",
        "J.BiSQuestData = { quests = {",
    ]
    for level, quest_id, q, shareable, where, spot, cls, reqrace in records:
        fields = [str(quest_id), lua_string(q["name"]), str(level), f'"{SIDES.get(q["side"], "B")}"',
                  "false" if shareable is False else "true", lua_string(where)]
        if spot:
            fields += [str(spot[0]), f"{spot[1]:g}", f"{spot[2]:g}"]
        if cls:
            fields.append(f'class = "{cls}"')
        if reqrace:
            fields.append(f"races = {reqrace}")
        lines.append("    { " + ", ".join(fields) + " },")
    lines.append("} }")
    lines.append("")
    lines.append("J.BiSQuestRewards = {")
    for quest_id in sorted(quests):
        lines.append(f"    [{quest_id}] = {{ {', '.join(str(i) for i in quests[quest_id][1])} }},")
    lines.append("}")
    lines.append("")
    lines.append("J.BiSQuestChoices = {")
    for quest_id in sorted(q for q, (_, _, choice) in quests.items() if choice):
        lines.append(f"    [{quest_id}] = true,")
    lines.append("}")
    lines.append("")
    lines.append("J.BiSQuestZones = {")
    for quest_id in sorted(zones):
        lines.append(f"    [{quest_id}] = {lua_string(zones[quest_id])},")
    lines.append("}")
    text = "\r\n".join(lines) + "\r\n"
    text.encode("ascii")
    OUT.write_text(text, encoding="utf-8", newline="")
    return zones


def main():
    offline = "--offline" in sys.argv
    ranked = {i for slots in current_specs().values() for ids in slots.values() for i in ids}
    listed, pages = load(LISTED), load(PAGES)
    quests = rewarding(listed, ranked)
    failed = []
    for quest_id in [] if offline else sorted(quests):
        key = f"quest={quest_id}"
        if key in pages:
            continue
        try:
            pages[key] = quest_page(quest_id)
        except (urllib.error.HTTPError, ValueError) as e:
            failed.append(f"{key}: {e}")
            continue
        save(PAGES, pages)

    races = {int(k): q["reqrace"] for k, q in load(CATALOG).items()}
    races.update({row["id"]: row["reqrace"] for rows in load(ITEMS).values() for row in rows})
    zone_names = {ZONE_MAP[int(a)]: z[0] for a, z in load(JOURNAL)["zones"].items() if int(a) in ZONE_MAP}
    zones = write(quests, listed["starts"], pages, races, zone_names)
    print(f"{len(ranked)} ranked items, {len(quests)} quests reward {sum(len(q[1]) for q in quests.values())} of them,"
          f" {len(zones)} with a start -> {OUT.name}", file=sys.stderr)
    if failed:
        print(f"{len(failed)} could not be read; run again to retry:", file=sys.stderr)
        for line in failed:
            print(f"  {line}", file=sys.stderr)


if __name__ == "__main__":
    main()
