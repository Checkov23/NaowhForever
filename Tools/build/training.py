"""Build the Training Planner's spell list from Wowhead Forever's class ability lists.

Each class's list (wowhead.com/forever/spells/abilities/<class>) gives every spell with its
level, rank, where it comes from (source 6 is a trainer, 4 a quest) and the trainer's base
price in copper. Kept: the spells a trainer sells, and the ones a quest teaches above level 1, with
the few a class quest teaches beside its reward, which Wowhead lists with no source (QUEST_TAUGHT),
and the few new class abilities it lists with no source or price (TRAINER_TAUGHT).
Left out: talents (no trainer), runes and engravings, the level 60 book ranks, and the hunter's
pet training (rows with no skill line: the pet learns those, not the hunter).

Rogue poisons are not in the rogue's list: they are the game's Poisons skill line
(SkillLineAbility), each with its level from its own Wowhead page, kept when that page lists
a trainer teaching it (the first Instant Poison, which the skill grants, and the book and
rune poisons are not). Their price comes from the trainer window. Pick Lock, Parry, Dual
Wield and the armor skills are left out: Wowhead gives them level 1 for every class, which
the trainers do not.

From Wowhead's talent calculator: each later rank's talent, when its first rank is a talent (the
talent's first rank, by class and spell name), so the addon can list those ranks once the talent is
known; such a rank needs nothing else. On Forever some talents are sold by the trainer too (Aimed
Shot, Holy Shock); then nothing waits on the talent.

Wowhead's answers are kept in Tools/data/training_cache.json; delete a class's entry to ask again.

Writes NaowhForever_Training/Data/TrainingData.lua.

Usage: python Tools/build/training.py [--build 1.60.1.70170]
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
from wowhead import WOWHEAD, fetch, talent_calculator  # noqa: E402
from journal import ROOT, write  # noqa: E402

OUT = ROOT / "NaowhForever_Training" / "Data" / "TrainingData.lua"
CACHE = paths.DATA / "training_cache.json"
# The game's class IDs and Wowhead's names for them.
CLASSES = {1: "warrior", 2: "paladin", 3: "hunter", 4: "rogue", 5: "priest", 7: "shaman", 8: "mage",
           9: "warlock", 11: "druid"}
TRAINER, QUEST = 6, 4    # Wowhead's sources
# What a class quest teaches beside its reward, which Wowhead lists with no source: Taunt and Sunder
# Armor (Defensive Stance), Intercept (Berserker Stance), Growl and Maul (Bear Form), and Call,
# Dismiss, Feed and Revive Pet (Tame Beast).
QUEST_TAUGHT = {355, 7386, 20252, 6795, 6807, 883, 2641, 6991, 982}
# Class abilities in Wowhead's talent calculator that its class lists have no source or price for:
# Teleport: Moonglade, Teleport: Dalaran, Revoke, the hunter's Lacerate, and Lightwell's first rank,
# which Forever took out of the talent tree. Kept as trainer spells; the trainer window gives their price.
TRAINER_TAUGHT = {18960, 1297659, 1325499, 24118, 24119, 24120, 1299332, 724}
KEEP = ("id", "name", "rank", "level", "source", "trainingcost", "reqrace", "skill")
ROGUE = 4
POISONS = 40              # the game's Poisons skill line
POISON_CLASS = 8          # ClassMask bit for rogues


def class_spells(slug):
    """Wowhead's ability list for the class: its rows, trimmed to the fields kept."""
    page = fetch(f"{WOWHEAD}/spells/abilities/{slug}")
    start = page.index("listviewspells = ") + len("listviewspells = ")
    # A JavaScript literal: a few keys are not quoted.
    text = re.sub(r"([{,])([A-Za-z_]\w*):", r'\1"\2":', page[start:page.index("];", start) + 1])
    return [{k: row[k] for k in KEEP if k in row} for row in json.loads(text)]


def poison_spells(build_id, cache):
    """The rogue's poisons a trainer teaches, as rows like Wowhead's list: each one's level from
    its Wowhead page (cached under "poison:<id>", 0 when no trainer teaches it), price unknown."""
    names = {r["ID"]: r["Name_lang"] for r in wago.table("SpellName", build_id)}
    ranks = {r["ID"]: r["NameSubtext_lang"] for r in wago.table("Spell", build_id)}
    rows = []
    for row in wago.table("SkillLineAbility", build_id):
        spell = row["Spell"]
        if row["SkillLine"] != str(POISONS) or not int(row["ClassMask"] or 0) & POISON_CLASS:
            continue
        if not names.get(spell):
            continue
        key = f"poison:{spell}"
        if key not in cache:
            page = fetch(f"{WOWHEAD}/spell={spell}")
            found = re.search(r"Requires level (\d+)", page)
            cache[key] = int(found.group(1)) if found and "id: 'taught-by-npc'" in page else 0
        if cache[key]:
            rows.append({"id": int(spell), "name": names[spell], "rank": ranks.get(spell) or "",
                         "level": cache[key], "source": [TRAINER], "skill": [POISONS]})
    return rows


def talents_by_name(build_id):
    """Class ID -> spell name -> the spell ID of that talent's first rank, from Wowhead's talent
    calculator, as the trees are. The game's Talent rows lag behind: they lack Forever's new talents
    (Lava Burst, Penance, Mutilate) and still have Lightwell, which is no longer a talent."""
    names = {r["ID"]: r["Name_lang"] for r in wago.table("SpellName", build_id)}
    out = {}
    calculator = talent_calculator()
    for tree_id, talents in calculator["talents"].items():
        tree = calculator["trees"][tree_id]["description"].lower()
        class_id = next(c for c, slug in CLASSES.items() if tree.startswith(slug))
        for talent in talents.values():
            spell = str(talent["ranks"][0])
            if names.get(spell):
                out.setdefault(class_id, {})[names[spell]] = int(spell)
    return out


def races(mask):
    """The race IDs in Wowhead's race mask (bit n-1 for race n)."""
    return [n + 1 for n in range(64) if int(mask) >> n & 1]


def entries(rows, talents):
    """The class's kept spells in level order, each {spell, level, name, rank, cost, quest,
    talent, races, needs}: needs is the rank before it, which the trainer asks for first."""
    kept = []
    for row in rows:
        source = row.get("source") or []
        level = row.get("level") or 0
        if not row.get("skill"):
            continue
        if TRAINER in source and (row.get("trainingcost") or row["skill"] == [POISONS]) or row["id"] in TRAINER_TAUGHT:
            kept.append({"quest": False, "cost": row.get("trainingcost") or 0})
        elif (QUEST in source and level > 1) or row["id"] in QUEST_TAUGHT:
            kept.append({"quest": True, "cost": 0})
        else:
            continue
        kept[-1].update(spell=row["id"], level=level, name=row["name"], rank=row.get("rank") or "",
                        races=races(row["reqrace"]) if row.get("reqrace") else [],
                        talent=talents.get(row["name"]))
    sold = {e["spell"] for e in kept}
    for e in kept:
        if e["talent"] in sold:
            e["talent"] = None
    kept.sort(key=lambda e: (e["level"], e["name"], e["spell"]))
    # The rank before, from every rank in the list, kept or not: a first rank the game grants at
    # level 1 (Heroic Strike, Fireball) has no trainer, but the second still follows it.
    ranks = {}
    for row in rows:
        number = rank_number(row.get("rank"))
        if row.get("skill") and number:
            key = (row["name"], tuple(races(row["reqrace"]) if row.get("reqrace") else []), number)
            ranks.setdefault(key, row["id"])
    for e in kept:
        number = rank_number(e["rank"])
        e["needs"] = number and ranks.get((e["name"], tuple(e["races"]), number - 1))
        # The talent is the first rank: Wowhead's "Rank 1" of Penance and Mutilate is a hidden half of
        # the spell, which the game never reports as known.
        if e["talent"] and e["needs"] not in sold:
            e["needs"] = None
    return kept


def rank_number(rank):
    """"Rank 3" -> 3; None for a spell without ranks."""
    match = re.fullmatch(r"Rank (\d+)", rank or "")
    return int(match.group(1)) if match else None


def build(build_id):
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    for slug in CLASSES.values():
        if slug not in cache:
            print(f"Wowhead: {slug}")
            cache[slug] = class_spells(slug)
    poisons = poison_spells(build_id, cache)
    CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    talents = talents_by_name(build_id)

    out = [f"-- TrainingData.lua: every spell each class learns as it levels, built from game build {build_id}.",
           "local ns = _G.NaowhForever",
           "",
           "ns.TrainingData = {"]
    counts = []
    for class_id, slug in CLASSES.items():
        rows = cache[slug] + (poisons if class_id == ROGUE else [])
        spells = entries(rows, talents.get(class_id, {}))
        counts.append(f"{slug} {len(spells)}")
        out.append(f"    [{class_id}] = {{")
        for e in spells:
            flags = []
            if e["quest"]:
                flags.append("quest = true")
            if e["needs"]:
                flags.append(f"needs = {e['needs']}")
            if e["talent"]:
                flags.append(f"talent = {e['talent']}")
            if e["races"]:
                flags.append("races = { " + ", ".join(map(str, e["races"])) + " }")
            extra = (", " + ", ".join(flags)) if flags else ""
            out.append(f"        {{ {e['level']}, {e['spell']}, {e['cost']}{extra} }},")
        out.append("    },")
    out.append("}")
    write(OUT, [line.encode("ascii", "replace").decode("ascii") for line in out])
    print(f"Wrote {OUT.relative_to(ROOT)}: " + ", ".join(counts))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--build", default=wago.BUILD, help="the Forever build to read (default: wago.BUILD)")
    build(parser.parse_args().build)


if __name__ == "__main__":
    main()
