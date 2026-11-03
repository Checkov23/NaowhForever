"""Build Tools/data/foreverchanges_bis.json: ForeverChanges' best-in-slot picks per spec, which
Tools/build/bis_data.py adds after wowsrc's, and where each comes from.

Each list page (/bis/<class>[/<list>]) has a section per gear slot, its items in rank order, each
with where it comes from under it. Only the PvE, tank and healer lists are read, each for the
specs of ours it is for (a class's one PvE list for all its damage specs); the PvP lists are left
out, as are the enchants and consumables.

Usage: python Tools/build/foreverchanges_bis.py
"""
import html
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wowhead  # noqa: E402

SITE = "https://foreverchanges.pro"
OUT = paths.DATA / "foreverchanges_bis.json"
GAP = 1
LISTS = {
    "/bis/warrior": ["arms-warrior", "fury-warrior"],
    "/bis/warrior/tank": ["protection-warrior"],
    "/bis/hunter": ["beast-mastery-hunter", "marksmanship-hunter", "survival-hunter"],
    "/bis/mage": ["frost-mage"],
    "/bis/mage/fire": ["fire-mage"],
    "/bis/mage/arcane": ["arcane-mage"],
    "/bis/rogue": ["combat-rogue"],
    "/bis/rogue/assassination": ["assassination-rogue"],
    "/bis/priest": ["shadow-priest"],
    "/bis/priest/holy": ["holy-priest"],
    "/bis/warlock": ["affliction-warlock", "demonology-warlock", "destruction-warlock"],
    "/bis/paladin": ["retribution-paladin"],
    "/bis/paladin/holy": ["holy-paladin"],
    "/bis/paladin/tank": ["protection-paladin"],
    "/bis/druid": ["feral-dps-druid"],
    "/bis/druid/tank": ["feral-tank-druid"],
    "/bis/druid/balance": ["balance-druid"],
    "/bis/druid/restoration": ["restoration-druid"],
    "/bis/shaman": ["elemental-shaman"],
    "/bis/shaman/enhancement": ["enhancement-shaman"],
    "/bis/shaman/restoration": ["restoration-shaman"],
}
# Their slot headings -> inventory slots; a ring or trinket goes in both.
SLOTS = {
    "Head": [1], "Neck": [2], "Shoulder": [3], "Back": [15], "Chest": [5], "Wrist": [9], "Hands": [10],
    "Waist": [6], "Legs": [7], "Feet": [8], "Finger": [11, 12], "Trinket": [13, 14],
    "Main hand": [16], "Two-hand weapon": [16], "Off hand": [17], "Off hand: held item": [17],
    "Off hand: shield": [17], "Ranged": [18], "Relic": [18],
}
SKIPPED = {"Enchants", "Consumables"}
SEP = " \u00b7 "


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": wowhead.AGENT})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def source(row):
    """A row's source as bis_data.py writes them: a quest's name, a profession, a boss or a vendor,
    then SEP and Quest, Crafted or the place; or World drop. From the first line under it; None
    where it names none."""
    first = re.search(r'<div class="bis-from"><p>(?:<a href="([^"]*)"[^>]*>(.*?)</a>|<b>(.*?)</b>)', row, re.S)
    if not first:
        return None
    href, text = first.group(1) or "", html.unescape(re.sub(r"<[^>]+>", "", first.group(2) or first.group(3))).strip()
    if href.startswith("/quest/"):
        return text.removeprefix("Quest: ") + SEP + "Quest"
    if href.startswith("/professions/"):
        return re.sub(r" \(\d+\)$", "", text) + SEP + "Crafted"
    if text.startswith("World drop"):
        return "World drop"
    sold = re.match(r"Sold by (.+) in (.+)", text)
    if sold:
        return sold.group(1) + SEP + sold.group(2)
    who, comma, where = text.partition(", ")
    quest = re.match(r"[A-Z][a-z]+ quest (?!of |chain$)(.+)", who)
    if quest:
        return quest.group(1) + SEP + "Quest"
    # "the rare wyvern of Thousand Needles", "a rare elite of the Barrens": the place is what follows.
    where = re.sub(r"^(?:the|a) rare (?:[a-z]+ )*?of ", "", where)
    if not comma or not (where[:1].isupper() or where.startswith("the ")):
        return None
    return ("Trash drop" if who == "Trash mobs" else who) + SEP + where


def parse(page):
    """({inventory slot: [item IDs]}, {item ID: source}): a list page's items per slot, in rank
    order, and their sources."""
    slots, sources = {}, {}
    for section in re.findall(r'<section class="bis-slot"(.*?)</section>', page, re.S):
        heading = re.sub(r"<[^>]+>", "", re.search(r"<h[234][^>]*>(.*?)</h[234]>", section, re.S).group(1)).strip()
        if heading in SKIPPED:
            continue
        if heading not in SLOTS:
            raise ValueError(f"a slot heading not known: {heading!r}")
        items = []
        for row in re.findall(r'<li class="bis-row">(.*?)</li>', section, re.S):
            item = re.search(r'href="/item/(\d+)/', row)
            if not item:
                continue
            items.append(int(item.group(1)))
            if source(row):
                sources[item.group(1)] = source(row)
        for inv in SLOTS[heading]:
            slot = slots.setdefault(inv, [])
            slot += [i for i in items if i not in slot]
    return slots, sources


def main():
    specs, sources = {}, {}
    for path, slugs in LISTS.items():
        slots, found = parse(fetch(SITE + path))
        sources.update(found)
        print(f"{path}: {sum(len(v) for v in slots.values())} items", file=sys.stderr)
        for slug in slugs:
            specs[slug] = {str(inv): items for inv, items in sorted(slots.items())}
        time.sleep(GAP)
    OUT.write_text(json.dumps({"specs": specs, "sources": sources}, indent=1, sort_keys=True),
                   encoding="utf-8", newline="\r\n")


if __name__ == "__main__":
    main()
