"""Build the Training Planner's spell list from Wowhead Forever's class ability lists.

Each class's list (wowhead.com/forever/spells/abilities/<class>) gives every spell with its
level, rank, where it comes from (source 6 is a trainer, 4 a quest) and the trainer's base
price in copper. Kept: the spells a trainer sells, and the ones a quest teaches above level 1, with
the few a class quest teaches beside its reward, which Wowhead lists with no source or as the
trainer's (QUEST_TAUGHT), and the few new class abilities it lists with no source or price
(TRAINER_TAUGHT).
Left out: talents (no trainer), runes and engravings, the level 60 book ranks, the hunter's
pet training (rows with no skill line: the pet learns those, not the hunter), any spell the
build's skill lines (SkillLineAbility) no longer have, which Wowhead can still list after a hotfix
takes it away (Frost Blast, 30 October 2026), or have as never learned (AcquireMethod 3: Tiger's
Fury), and what a hotfix took away that the build's tables still have (UNTRAINABLE).

Wowhead's prices are older than Forever's launch, which changed them. A class's prices read from its
trainer (Tools/data/trainer_prices.json: the trainer window's, or What's Training's lists, by
Tools/build/trainer_prices.py) replace them. A trainer lists every spell it sells, so for such a class a
trainer spell the prices lack stops the build, until the spell is put in QUEST_TAUGHT or UNTRAINABLE.

Wowhead's lists can lag a hotfix, so each spell's rank and level are the build's own (Spell,
SpellLevels: BaseLevel, else SpellLevel, the only level Forever's new spells have), and a rank before
a listed one (SkillLineAbility's SupercedesSpell) that Wowhead lacks is added at the game's level,
unless it is the talent. So are the few new spells no listed rank leads to (UNLISTED), and the ranks
after a talent or an UNLISTED spell, which the lists can lack entirely (Death Mark's, Shank's). Only
those are followed forward: after any other spell, a later rank Wowhead lacks could be a level 60
book's, which no trainer sells. An added rank has no price: the trainer window gives it.

A kept rank that a rank Wowhead lists but no trainer sells replaces (the level 60 book ranks) names
it as replacedBy, so the addon counts the kept rank as learned once the book is read; not when a
hotfix took that rank away (UNTRAINABLE).

Rogue poisons are not in the rogue's list: they are the game's Poisons skill line
(SkillLineAbility), each with its level from its own Wowhead page, kept when that page lists
a trainer teaching it (the first Instant Poison, which the skill grants, and the book and
rune poisons are not). Their price comes from the trainer window. Pick Lock, Parry, Dual
Wield and the armor skills are left out: Wowhead gives them level 1 for every class, which
the trainers do not.

From the build's talent trees (training_builds.py): each later rank's talent, when its first rank
is a talent (the talent's first rank, by class and spell name), so the addon can list those ranks
once the talent is known; such a rank needs nothing else. On Forever some talents are sold by the
trainer too (Aimed Shot, Holy Shock); then nothing waits on the talent.

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
from wowhead import WOWHEAD, fetch  # noqa: E402
from journal import ROOT, write  # noqa: E402
from training_builds import CLASSES, class_trees  # noqa: E402

OUT = ROOT / "NaowhForever_Training" / "Data" / "TrainingData.lua"
CACHE = paths.DATA / "training_cache.json"
PRICES = paths.DATA / "trainer_prices.json"
TRAINER, QUEST = 6, 4    # Wowhead's sources
NEVER_LEARNED = "3"      # SkillLineAbility's AcquireMethod for a spell no one learns
# What a class quest teaches beside its reward, which Wowhead lists with no source: Taunt and Sunder
# Armor (Defensive Stance), Intercept (Berserker Stance), Growl and Maul (Bear Form), and Call,
# Dismiss, Feed and Revive Pet (Tame Beast). Forever's Cat Form quest teaches Cat Form, Prowl, Claw and
# Rip (spell 1309050), which Wowhead lists as the trainer's, and the trainer window has neither them nor
# Teleport: Moonglade. Poisons comes from the rogue's level 20 quest (Klaven's Tower, Hinott's Assistance).
QUEST_TAUGHT = {355, 7386, 20252, 6795, 6807, 883, 2641, 6991, 982, 768, 5215, 1082, 1079, 18960, 2842}
# Class abilities in Wowhead's talent calculator that its class lists have no source or price for:
# Teleport: Dalaran, the hunter's Lacerate, and Lightwell, which Forever took out of the talent tree
# (Wowhead prices its later ranks as a talent's). Kept as trainer spells without a price, though What's
# Training's trainer lists lack them too: where they come from wants a look in game.
TRAINER_TAUGHT = {1297659, 24118, 24119, 24120, 1299332, 724, 27870, 27871}
# What no trainer teaches any more though Wowhead and the build's tables on wago.tools still have it:
# wago applies a hotfix's new and changed rows, not the ones it removes. The 30 October 2026 hotfix
# removed Blessing of Light, Greater Blessing of Light, Salvation, Mass Salvation and Revoke (their Spell
# rows) and Primal Bite's fourth rank (its SkillLineAbility row), and replaced the talent that was Binding
# Heal's first rank with Holy Binding, which leaves its later ranks out of reach. The 3 November 2026
# hotfix made the Mutilate talent the rank the trainer sold at 40, which it now gives.
UNTRAINABLE = {19977, 19978, 19979, 25890, 1038, 25895, 1325499, 1238073,
               1240770, 1240771, 1240772, 1240773, 1240774, 399956}
# New class spells Wowhead's class lists lack, which no listed rank or talent leads to: Shank and Poised
# (rogue), Poised (druid), and Holy Shield's fourth rank, whose ranks the game does not chain by
# SupercedesSpell. Read from the build's tables as trainer spells without a price; Shank's second rank
# follows its first.
UNLISTED = {"rogue": (1329283, 1328825), "druid": (1328829,), "paladin": (1239570,)}
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
    """Class ID -> spell name -> the spell ID of that talent's first rank, from the build's talent
    trees. The game's Talent rows lag behind: they lack Forever's new talents (Lava Burst, Penance,
    Mutilate) and still have Lightwell, which is no longer a talent."""
    names = {r["ID"]: r["Name_lang"] for r in wago.table("SpellName", build_id)}
    trees, _ = class_trees(build_id)
    out = {}
    for class_id, talents in trees.items():
        for spell, *_ in talents.values():
            if names.get(str(spell)):
                out.setdefault(class_id, {})[names[str(spell)]] = spell
    return out


def game_spells(build_id):
    """Spell ID -> {name, rank, level, replaces, after, skill} from the build's tables: level its
    BaseLevel, else its SpellLevel, 0 when the game gives neither, replaces the rank before it
    (SkillLineAbility's SupercedesSpell), 0 for none, after the ranks that replace it, and skill its
    skill line, 0 for none."""
    levels = {r["SpellID"]: int(r["BaseLevel"] or 0) or int(r["SpellLevel"] or 0)
              for r in wago.table("SpellLevels", build_id)}
    abilities = wago.table("SkillLineAbility", build_id)
    replaces = {r["Spell"]: int(r["SupercedesSpell"]) for r in abilities if int(r["SupercedesSpell"] or 0)}
    after = {}
    for spell, before in replaces.items():
        after.setdefault(before, []).append(int(spell))
    skills = {r["Spell"]: int(r["SkillLine"]) for r in abilities}
    ranks = {r["ID"]: r["NameSubtext_lang"] for r in wago.table("Spell", build_id)}
    return {int(r["ID"]): {"name": r["Name_lang"], "rank": ranks.get(r["ID"], ""), "level": levels.get(r["ID"], 0),
                           "replaces": replaces.get(r["ID"], 0), "after": sorted(after.get(int(r["ID"]), [])),
                           "skill": skills.get(r["ID"], 0)} for r in wago.table("SpellName", build_id)}


def game_row(spell, game):
    """A spell Wowhead does not list, as a row like its list's, from the build's tables."""
    return {"id": spell, "name": game[spell]["name"], "rank": game[spell]["rank"], "level": game[spell]["level"],
            "source": [TRAINER], "skill": [game[spell]["skill"]], "added": True}


def caught_up(rows, talents, game):
    """Wowhead's rows as the build has them: each spell's rank and level from the game, and the rank
    before a listed one that Wowhead lacks, unless that rank is the talent or has no level."""
    listed = {row["id"] for row in rows}
    out = []
    for row in rows:
        spell = game.get(row["id"])
        out.append(dict(row, rank=spell["rank"], level=spell["level"] or row.get("level")) if spell else row)
    # out grows as ranks are added, so an added rank's own rank before is looked at too.
    for row in out:
        before = game.get(row["id"], {}).get("replaces")
        spell = game.get(before)
        if not spell or before in listed or not spell["level"] or talents.get(spell["name"]) == before:
            continue
        listed.add(before)
        added = dict(row, id=before, name=spell["name"], rank=spell["rank"], level=spell["level"],
                     source=[TRAINER], added=True)
        added.pop("trainingcost", None)
        out.append(added)
    return out


def later_ranks(rows, starts, game):
    """The ranks after the start spells (the class's talents and UNLISTED spells), followed on through
    SupercedesSpell, that rows lack and the game gives a level, added like caught_up's ranks. Each carries
    the rank it replaces as before, which entries takes as what it needs when there is no rank text to
    match (Shank's)."""
    by_id = {row["id"]: row for row in rows}
    out, todo = [], sorted(starts)
    while todo:
        before = todo.pop(0)
        for spell in game.get(before, {}).get("after", []):
            if spell in by_id or not game.get(spell, {}).get("level"):
                continue
            base = by_id.get(before) or game_row(spell, game)
            added = dict(base, id=spell, name=game[spell]["name"], rank=game[spell]["rank"],
                         level=game[spell]["level"], source=[TRAINER], added=True, before=before)
            added.pop("trainingcost", None)
            by_id[spell] = added
            out.append(added)
            todo.append(spell)
    return out


def replaced_by(spells, rows, game):
    """Kept spell -> the rank the class's list has that replaces it but no trainer sells, when no kept
    rank replaces it: the level 60 book ranks (Battle Shout 25289 replaces 11551). A rank a hotfix took
    away (UNTRAINABLE) is not one. Swipe's fourth rank is also replaced by Swipe (Cat), another spell,
    but the trainer's fifth rank follows it."""
    kept = {e["spell"] for e in spells}
    listed = {row["id"] for row in rows}
    out = {}
    for spell in kept:
        later = game.get(spell, {}).get("after", [])
        books = [s for s in later if s in listed and s not in UNTRAINABLE]
        if books and not kept.intersection(later):
            out[spell] = books[0]
    return out


def races(mask):
    """The race IDs in Wowhead's race mask (bit n-1 for race n)."""
    return [n + 1 for n in range(64) if int(mask) >> n & 1]


def entries(rows, talents, learnable, prices=None):
    """The class's kept spells in level order, each {spell, level, name, rank, cost, quest,
    talent, races, needs}: needs is the rank before it, which the trainer asks for first. Only the
    spells in learnable (the build's skill lines) are kept. prices, when the class's trainer prices
    were read, replace Wowhead's; a trainer spell they lack, other than TRAINER_TAUGHT's,
    raises ValueError."""
    kept, unsold = [], []
    for row in rows:
        source = row.get("source") or []
        level = row.get("level") or 0
        if not row.get("skill") or row["id"] not in learnable or row["id"] in UNTRAINABLE:
            continue
        trainer = row["id"] not in QUEST_TAUGHT and (
            TRAINER in source and (row.get("trainingcost") or row["skill"] == [POISONS] or row.get("added"))
            or row["id"] in TRAINER_TAUGHT)
        if trainer and (prices is None or row["id"] in prices or row["id"] in TRAINER_TAUGHT):
            cost = (row.get("trainingcost") or 0) if prices is None else prices.get(row["id"], 0)
            kept.append({"quest": False, "cost": cost})
        elif (QUEST in source and level > 1) or row["id"] in QUEST_TAUGHT:
            kept.append({"quest": True, "cost": 0})
        else:
            if trainer:
                unsold.append(f"{row['name']} ({row['id']})")
            continue
        kept[-1].update(spell=row["id"], level=level, name=row["name"], rank=row.get("rank") or "",
                        races=races(row["reqrace"]) if row.get("reqrace") else [],
                        talent=talents.get(row["name"]), before=row.get("before"))
    if unsold:
        raise ValueError("no trainer price for " + ", ".join(unsold)
                         + ": put each in QUEST_TAUGHT or UNTRAINABLE")
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
        e["needs"] = number and ranks.get((e["name"], tuple(e["races"]), number - 1)) or e["before"]
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
    learnable = {int(r["Spell"]) for r in wago.table("SkillLineAbility", build_id)
                 if r["AcquireMethod"] != NEVER_LEARNED}
    game = game_spells(build_id)
    captured = json.loads(PRICES.read_text(encoding="ascii")) if PRICES.exists() else {}
    credit = (" and What's Training's prices (MIT, Sveng)"
              if any(c["source"].startswith("What's Training") for c in captured.values()) else "")

    out = [f"-- TrainingData.lua: every spell each class learns as it levels, built from game build {build_id}{credit}.",
           "local ns = _G.NaowhForever",
           "",
           "ns.TrainingData = {"]
    counts = []
    for class_id, slug in CLASSES.items():
        mine = talents.get(class_id, {})
        listed = cache[slug] + [game_row(spell, game) for spell in UNLISTED.get(slug, ())]
        rows = caught_up(listed, mine, game) + (poisons if class_id == ROGUE else [])
        rows += later_ranks(rows, set(mine.values()) | set(UNLISTED.get(slug, ())), game)
        prices = captured.get(slug)
        spells = entries(rows, mine, learnable, prices and {int(s): c for s, c in prices["prices"].items()})
        books = replaced_by(spells, rows, game)
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
            if e["spell"] in books:
                flags.append(f"replacedBy = {books[e['spell']]}")
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
