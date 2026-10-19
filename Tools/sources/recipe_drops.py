"""Which recipes the Journal's bosses drop, from each recipe's Wowhead Forever item XML:
Tools/data/journal_recipes.json.

A boss's own page lists its drops, but Wowhead's CDN refuses those pages to scripts at times
(403 for hours on 2026-10-18) while the item XML still answers. So this asks the other way
round: for every recipe the Professions data says drops or does not know the source of, its
item XML's "sourcemore" names the NPCs it drops from (beside "source" 2: one beside 5 sells it), and a Journal boss among them gets the
recipe. One dropped by SHARED_DROP or more Journal bosses is a shared random drop, not any one
boss's: left out, as Tools/build/journal.py leaves out such gear.

Each answer is kept in Tools/data/recipe_drops_cache.json, so a run stopped part way resumes;
--refresh asks again for every recipe. Tools/build/journal.py places what this writes on its
bosses like journal_bosses.json's "add" lists (no chance shown: the XML gives no counts).

Usage: python Tools/sources/recipe_drops.py [--refresh]
"""
import json
import re
import sys
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wowhead  # noqa: E402

RECIPES = paths.ROOT / "NaowhForever_Professions" / "Data" / "RecipeData.lua"
DUNGEONS = paths.ROOT / "NaowhForever_DungeonJournal" / "Data" / "Dungeons"
CACHE = paths.DATA / "recipe_drops_cache.json"
OUT = paths.DATA / "journal_recipes.json"
SOURCES = ("drop", "unknown")   # a vendor's, trainer's or quest's recipe drops from no boss
NPC = 1                         # a "sourcemore" entry's type ("t") for an NPC
DROP = 2                        # its "source" beside it: dropped (5 is sold, by a vendor)
SHARED_DROP = 3
RECIPE = re.compile(r'recipe = (\d+), source = "(\w+)"')
BOSS = re.compile(r'\{ npc = (\d+), name = "((?:[^"\\]|\\.)*)"')
JSON = re.compile(r"<json><!\[CDATA\[(.*?)\]\]></json>", re.S)


def recipe_ids():
    """The recipes the Professions data says drop, or does not know the source of."""
    text = RECIPES.read_text(encoding="utf-8")
    return sorted({int(item) for item, source in RECIPE.findall(text) if source in SOURCES})


def journal_bosses():
    """NPC ID -> (dungeon name, boss name) for every Journal boss with an NPC ID."""
    bosses = {}
    for path in sorted(DUNGEONS.glob("*.lua")):
        text = path.read_text(encoding="utf-8")
        dungeon = re.search(r'name = "([^"]+)"', text).group(1)
        for npc, name in BOSS.findall(text):
            bosses[int(npc)] = (dungeon, name)
    return bosses


def dropped_by(xml):
    """The NPC IDs an item's XML names as dropping it; [] where it names none. "source" and
    "sourcemore" run side by side: an NPC can sell the item instead (Plugger Spazzring)."""
    found = JSON.search(xml)
    if not found:
        return []
    item = json.loads("{" + found.group(1) + "}")
    pairs = zip(item.get("source") or [], item.get("sourcemore") or [])
    return sorted({s["ti"] for how, s in pairs if how == DROP and s.get("t") == NPC and s.get("ti")})


def placed(answers, bosses):
    """{dungeon: {boss: [recipe IDs]}} for the recipes one or two Journal bosses drop."""
    out = {}
    for item, npcs in sorted(answers.items(), key=lambda a: int(a[0])):
        ours = [bosses[n] for n in npcs if n in bosses]
        if not ours or len(ours) >= SHARED_DROP:
            continue
        for dungeon, boss in ours:
            out.setdefault(dungeon, {}).setdefault(boss, []).append(int(item))
    return out


def main():
    cache = {}
    if CACHE.exists() and "--refresh" not in sys.argv:
        cache = json.loads(CACHE.read_text(encoding="utf-8"))
    wanted = [i for i in recipe_ids() if str(i) not in cache]
    print(f"{len(wanted)} recipes to ask Wowhead about", file=sys.stderr)
    for n, item in enumerate(wanted, 1):
        try:
            cache[str(item)] = dropped_by(wowhead.fetch(f"{wowhead.WOWHEAD}/item={item}&xml"))
        except urllib.error.HTTPError as e:
            if e.code != 404:
                raise
            cache[str(item)] = []
        if n % 25 == 0 or n == len(wanted):
            CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
            print(f"  {n} of {len(wanted)}", file=sys.stderr)
    out = placed(cache, journal_bosses())
    OUT.write_text(json.dumps(out, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    count = sum(len(ids) for bosses in out.values() for ids in bosses.values())
    print(f"{count} recipes on {sum(len(b) for b in out.values())} bosses to {OUT.relative_to(paths.ROOT)}",
          file=sys.stderr)


if __name__ == "__main__":
    main()
