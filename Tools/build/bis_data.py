"""Build NaowhForever_BiS/BiS/Data/BiS.lua from wowsrc.com's per-spec best-in-slot lists.

wowsrc.com gave permission to use what is on its site. Each spec page
(/specs/<spec>/) has one <details> per gear slot; its <summary> is the #1 pick
and the <li> rows under it are #2 onwards, each carrying a data-tip JSON blob
(name, quality, item level, slot, source) and an icon. The site publishes no
item IDs, so each item is looked up by name in Wowhead's Forever database and
accepted only when name, quality, icon and item level all agree. Answers are
cached in bis_item_ids.json; an entry there can be edited by hand to settle an
item the lookup could not, and a value of null leaves the item out.

wowsrc gives no source for some items. Those get one from their Wowhead Forever
item page: the NPC and zone that drop it, the quest that rewards it, the profession
that crafts it, the vendor that sells it or the container it comes in, in that order,
or World drop when many NPCs drop it. Answers are cached in bis_sources.json, where
an entry can be edited by hand the same way.

--check is the daily check (.github/workflows/daily-watch.yml): it reads the spec pages again
and says, slot by slot, where they differ from NaowhForever_BiS/BiS/Data/BiS.lua: a new #1, items
added to a slot or taken off it, a new spec page. The rest of the order is left out. It
only reads wowsrc: an item it has not looked up yet is named, and building it in needs
Wowhead, so that stays a run on our machines.

--offline (the daily watch, in CI) asks Wowhead nothing: a new item is found by name, quality
and item level in the game's own item table (Tools/sources/wago.py), and one it cannot settle there,
or a source it would ask Wowhead for, is left for a run on our machines (and listed).

Usage: python Tools/build/bis_data.py [--sources-only] [--offline]
       python Tools/build/bis_data.py --check [--report report.md] [--github-output $GITHUB_OUTPUT]
  --sources-only keeps the specs in NaowhForever_BiS/BiS/Data/BiS.lua as they are and only
  fills in the sources missing for items already in it.
"""
import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402

ROOT = paths.ROOT
OUT = ROOT / "NaowhForever_BiS" / "BiS" / "Data" / "BiS.lua"
CACHE = paths.DATA / "bis_item_ids.json"
SOURCES = paths.DATA / "bis_sources.json"
WOWHEAD = "https://www.wowhead.com/forever"
SEP = " \u00b7 "

WOWSRC_AGENT = "NaowhForever-tools (+https://github.com/naowh-gaming/NaowhForever)"   # as wowsrc.py's

CLASSES = ["druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior"]

# wowsrc slot id -> inventory slot number, in character pane order.
SLOTS = [
    ("head", 1), ("neck", 2), ("shoulder", 3), ("back", 15), ("chest", 5), ("wrist", 9),
    ("hands", 10), ("waist", 6), ("legs", 7), ("feet", 8), ("finger-1", 11), ("finger-2", 12),
    ("trinket-1", 13), ("trinket-2", 14), ("main-hand", 16), ("off-hand", 17), ("ranged", 18),
]

QUALITY = {"poor": 0, "common": 1, "uncommon": 2, "rare": 3, "epic": 4, "legendary": 5}

# Wowhead quest side -> wowsrc's wording; 3 is both.
SIDE = {1: " (Alliance)", 2: " (Horde)"}
PROFESSIONS = {164: "Blacksmithing", 165: "Leatherworking", 171: "Alchemy", 197: "Tailoring",
               202: "Engineering", 333: "Enchanting"}


def fetch(url):
    # wowsrc.com is told who we are, as Tools/sources/wowsrc.py tells it: it answers a bare browser
    # name from GitHub's runners with 403 (the daily BiS check, 2 Oct 2026).
    agent = WOWSRC_AGENT if urllib.parse.urlsplit(url).netloc.endswith("wowsrc.com") else "Mozilla/5.0"
    req = urllib.request.Request(url, headers={"User-Agent": agent})
    # Wowhead's CDN answers 403 once requests come too fast; it lifts after a pause.
    for wait in (30, 60, 120, 240, None):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            if e.code not in (403, 429, 503) or wait is None:
                raise
            print(f"  {e.code} from {urllib.parse.urlsplit(url).netloc}, retrying in {wait}s", file=sys.stderr)
            time.sleep(wait)


def spec_slugs():
    slugs = []
    for cls in CLASSES:
        page = fetch(f"https://wowsrc.com/classes/{cls}/")
        for slug in sorted(set(re.findall(r'href="/specs/([a-z-]+)/"', page))):
            slugs.append((cls.upper(), slug))
    return slugs


MONTHS = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()


def updated_on(page):
    """When wowsrc last updated a spec page, as the addon shows dates ("30 Sep 2026"); None
    when the page does not say."""
    found = re.search(r'Last updated <time datetime="(\d{4})-(\d\d)-(\d\d)"', page)
    if not found:
        return None
    year, month, day = (int(x) for x in found.groups())
    return f"{day} {MONTHS[month - 1]} {year}"


def parse_spec(slug):
    """A spec page: its title, its items per slot in rank order, and when it was updated."""
    page = fetch(f"https://wowsrc.com/specs/{slug}/")
    title = re.search(r"<title>WoW Forever ([^:<]+):", page).group(1)
    slots = {}
    for key, inv in SLOTS:
        start = page.find(f'id="slot-{key}"')
        if start < 0:
            continue
        block = page[start:page.index("</details>", start)]
        items = []
        # Each item is a data-tip followed by its icon; rows are already in rank order.
        for tip, icon in re.findall(r'data-tip="([^"]*)".*?/icons/item/([a-z0-9_]+)\.webp', block, re.S):
            t = json.loads(html.unescape(tip))
            items.append({
                "name": t["n"], "quality": QUALITY.get(t.get("r")), "ilvl": t.get("l"),
                "icon": icon, "source": (t.get("src") or "").replace("�", "-"),
            })
        slots[inv] = items
    return title, slots, updated_on(page)


OFFLINE = "--offline" in sys.argv
game_rows = None


def same_else_one(exact, other_quality):
    """The matches of the item's quality; with none, the one match of another quality. wowsrc
    shows some greens as blue (Energized Stone Circle, Doomsayer's Robe: green in the game's
    table and on Wowhead, at the item level wowsrc gives), and a name, icon and item level that
    fit one item are that item. Two of another quality stay unsettled."""
    return exact or (other_quality if len(other_quality) == 1 else [])


def game_lookup(item):
    """The Forever items with the item's name, quality and item level, from the game's own item
    table (the --offline build); same_else_one when the quality is wowsrc's slip."""
    global game_rows
    if game_rows is None:
        import wago
        game_rows, seen = {}, set()
        # The build itself first, then the carried one's (hotfixed items wago has not recorded
        # for the new build yet), each item once.
        for build in (wago.BUILD, wago.CARRY_FROM):
            if not build:
                continue
            forever = {r["ID"] for r in wago.table("Item", build)}
            for r in wago.table("ItemSparse", build):
                if r["ID"] in forever and r["ID"] not in seen:
                    seen.add(r["ID"])
                    game_rows.setdefault(r.get("Display_lang", "").lower(), []).append(r)
    rows = [r for r in game_rows.get(item["name"].lower(), [])
            if not item["ilvl"] or int(r["ItemLevel"]) == item["ilvl"]]
    return same_else_one([int(r["ID"]) for r in rows if int(r["OverallQualityID"]) == item["quality"]],
                         [int(r["ID"]) for r in rows if int(r["OverallQualityID"]) != item["quality"]])


def lookup(item):
    if OFFLINE:
        return game_lookup(item)
    url = ("https://www.wowhead.com/forever/search/suggestions-template?q="
           + urllib.parse.quote(item["name"]))
    results = json.loads(fetch(url)).get("results", [])
    exact, other_quality = [], []
    for r in results:
        if r.get("type") != 3 or r.get("name", "").lower() != item["name"].lower():
            continue
        if r.get("icon") != item["icon"]:
            continue
        ilvl = re.search(r"item level (\d+)", r.get("pinDescription", ""))
        if item["ilvl"] and ilvl and int(ilvl.group(1)) != item["ilvl"]:
            continue
        (exact if r.get("quality") == item["quality"] else other_quality).append(r["id"])
    time.sleep(1)
    return same_else_one(exact, other_quality)


def listview(page, lv_id):
    start = page.find(f"id: '{lv_id}'")
    if start < 0:
        return []
    data = re.compile(r"data:\s*").search(page, start)
    return json.JSONDecoder().raw_decode(page[data.end():])[0]


def zone_name(zone, cache):
    key = f"zone={zone}"
    if key not in cache:
        cache[key] = re.search(r"<title>(.+?) - Zone - ", fetch(f"{WOWHEAD}/zone={zone}")).group(1)
        time.sleep(1)
    return cache[key]


def wowhead_source(item_id, cache):
    key = f"item={item_id}"
    if key in cache:
        return cache[key]
    page = fetch(f"{WOWHEAD}/item={item_id}")
    time.sleep(1)

    def top(rows):
        return max(rows, key=lambda r: r.get("popularity", 0))

    npcs = sorted(listview(page, "dropped-by"), key=lambda n: -n.get("count", 0))
    # Some NPCs are placed only on a continent (negative), which says nothing about where.
    zones = {z for n in npcs for z in n.get("location", []) if z > 0}
    quests = listview(page, "reward-from-q")
    crafts = listview(page, "created-by-spell")
    vendors = listview(page, "sold-by")
    containers = listview(page, "contained-in-item") + listview(page, "contained-in-object")
    source = None
    if npcs and len(npcs) <= 3 and len(zones) == 1:
        source = npcs[0]["name"] + SEP + zone_name(zones.pop(), cache)
    elif quests:
        name = top(quests)["name"]
        sides = {q.get("side") for q in quests if q["name"] == name}
        source = name + SEP + "Quest" + (SIDE.get(sides.pop(), "") if len(sides) == 1 else "")
    elif crafts:
        source = PROFESSIONS[crafts[0]["skill"][0]] + SEP + "Crafted"
    elif vendors:
        vendor = top(vendors)
        zone = next((z for z in vendor.get("location", []) if z > 0), None)
        source = vendor["name"] + SEP + (zone_name(zone, cache) if zone else "Vendor")
    elif containers:
        source = containers[0]["name"] + SEP + "Container"
    elif len(npcs) > 3:
        source = "World drop"
    cache[key] = source
    return source


def fill_sources(sources, ranked):
    """Adds a Wowhead source for every ranked item wowsrc gave none; returns the ones still without."""
    cache = json.loads(SOURCES.read_text(encoding="utf-8")) if SOURCES.exists() else {}
    missing = []
    for item_id in sorted(ranked - sources.keys()):
        if OFFLINE and f"item={item_id}" not in cache:
            missing.append(item_id)
            continue
        source = wowhead_source(item_id, cache)
        SOURCES.write_text(json.dumps(cache, indent=1, sort_keys=True), encoding="utf-8", newline="\r\n")
        if source:
            sources[item_id] = source
        else:
            missing.append(item_id)
    return missing


def source_lines(sources):
    lines = ["    sources = {"]
    for item_id in sorted(sources):
        lines.append(f"        [{item_id}] = {lua_string(sources[item_id])},")
    return lines + ["    },", "}"]


def refill_sources():
    data = OUT.read_bytes()
    head = data[:data.index(b"    sources = {")]
    text = data[len(head):].decode("utf-8")
    sources = {int(i): re.sub(r"\\(.)", r"\1", s)
               for i, s in re.findall(r'\[(\d+)\] = "((?:[^"\\]|\\.)*)",', text)}
    ranked = {int(i) for i in re.findall(rb"\d+", b" ".join(re.findall(rb"\] = \{([\d, ]*)\}", head)))}
    before = len(sources)
    missing = fill_sources(sources, ranked)
    # newline="" writes our CRLF as is; without it Windows turns each \n into \r\n again (CR CR LF).
    OUT.write_bytes(head)
    with OUT.open("a", encoding="utf-8", newline="") as f:
        f.write("\r\n".join(source_lines(sources)) + "\r\n")
    print(f"{len(ranked)} ranked items, {before} sourced, {len(sources) - before} added from Wowhead", file=sys.stderr)
    return missing


def item_key(item):
    return f'{item["name"]}|{item["icon"]}|{item["quality"]}|{item["ilvl"]}'


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if "--check" in sys.argv:
        args = sys.argv[1:]

        def value(flag):
            return args[args.index(flag) + 1] if flag in args else None
        return check(value("--report"), value("--github-output"))
    if "--sources-only" in sys.argv:
        report_missing(refill_sources())
        return
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    specs, sources, candidates, left_out = [], {}, {}, set()

    for cls, slug in spec_slugs():
        title, slots, updated = parse_spec(slug)
        print(f"{title}: {sum(len(v) for v in slots.values())} items", file=sys.stderr)
        resolved = {}
        for inv, items in slots.items():
            ids = []
            for item in items:
                key = item_key(item)
                if key not in cache:
                    matches = lookup(item)
                    candidates[key] = matches
                    # Offline, an item it cannot settle is left for Wowhead, not set to null.
                    if len(matches) == 1 or not OFFLINE:
                        cache[key] = matches[0] if len(matches) == 1 else None
                item_id = cache.get(key)
                if not item_id:
                    left_out.add(key)
                if item_id and item_id not in ids:
                    ids.append(item_id)
                    if item["source"]:
                        sources[item_id] = item["source"]
            resolved[inv] = ids
        specs.append((cls, slug, title, updated, resolved))
        CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True), encoding="utf-8", newline="\r\n")

    lines = [
        "-- BiS.lua: ranked best-in-slot candidates per spec and item sources, from wowsrc.com (Tools/build/bis_data.py).",
        "local ns = _G.NaowhForever",
        "",
        "ns.BiSData = {",
        "    specs = {",
    ]
    for cls, slug, title, updated, slots in specs:
        stamp = f" updated = {lua_string(updated)}," if updated else ""
        lines.append(f"        {{ class = {lua_string(cls)}, key = {lua_string(slug)}, name = {lua_string(title)},{stamp} slots = {{")
        for _, inv in SLOTS:
            ids = slots.get(inv, [])
            lines.append(f"            [{inv}] = {{ {', '.join(str(i) for i in ids)} }},")
        lines.append("        } },")
    lines.append("    },")
    missing = fill_sources(sources, {i for *_, slots in specs for ids in slots.values() for i in ids})
    lines += source_lines(sources)
    OUT.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8", newline="")

    print(f"{len(specs)} specs, {len(sources)} sourced items -> {OUT.name}", file=sys.stderr)
    # Every run lists them, whether the lookup failed now, earlier, or was set to null by hand.
    if left_out:
        print(f"{len(left_out)} items left out; settle them in {CACHE.name}:", file=sys.stderr)
        for key in sorted(left_out):
            found = f"  candidates={candidates[key]}" if key in candidates else ""
            print(f"  {key}{found}", file=sys.stderr)
    report_missing(missing)


REPORT_MAX = 60000


def current_specs():
    """spec slug -> {inventory slot: [item IDs]}, as NaowhForever_BiS/BiS/Data/BiS.lua has them."""
    text = OUT.read_text(encoding="utf-8")
    specs = {}
    for slug, body in re.findall(r'key = "([^"]+)", name = "[^"]*",(?: updated = "[^"]*",)? slots = \{(.*?)\} \},',
                                 text, re.S):
        specs[slug] = {int(inv): [int(i) for i in re.findall(r"\d+", ids)]
                       for inv, ids in re.findall(r"\[(\d+)\] = \{([^}]*)\}", body)}
    return specs


def settler(cache):
    """An item's ID as the build would settle it offline: the cache's, else the game's item table
    (one Forever item with its name, quality and item level), else None. The tables are read
    once; unreachable, the cache alone answers."""
    tables = {"ok": True}

    def find(item):
        item_id = cache.get(item_key(item))
        if item_id or not tables["ok"]:
            return item_id
        try:
            matches = game_lookup(item)
        except Exception as e:
            print(f"the game's item table could not be read: {e}", file=sys.stderr)
            tables["ok"] = False
            return None
        return matches[0] if len(matches) == 1 else None
    return find


def bis_changes(ours, theirs, cache, find=None):
    """What theirs ({slug: (title, {inv: [items]})}, read now) says that ours (current_specs)
    does not, as Markdown lines; [] when nothing. find(item) -> its ID (settler's), else the
    cache alone. No "#1": GitHub links "#" and a number to that pull request."""
    find = find or (lambda item: cache.get(item_key(item)))
    names = {item_id: key.split("|", 1)[0] for key, item_id in cache.items() if item_id}
    slot_names = {inv: key.replace("-", " ") for key, inv in SLOTS}
    lines = []
    for slug, (title, slots) in sorted(theirs.items()):
        if slug not in ours:
            lines.append(f"- **{title}**: a new spec page.")
            continue
        for _, inv in SLOTS:
            items = slots.get(inv, [])
            now = [find(i) for i in items]
            before = ours[slug].get(inv, [])
            said = []
            if now and before and now[0] != before[0]:
                said.append(f"top pick is now {items[0]['name']} (was {names.get(before[0], before[0])})")
            added = [i["name"] + ("" if item_id else " (not in the game's tables yet)")
                     for i, item_id in zip(items, now) if item_id not in before]
            gone = [names.get(i, str(i)) for i in before if i not in now]
            if added:
                said.append("added " + ", ".join(added))
            if gone:
                said.append("taken off " + ", ".join(gone))
            if said:
                lines.append(f"- **{title}**, {slot_names[inv]}: {'; '.join(said)}.")
    return lines


def check(report_path=None, github_output=None):
    """The daily check: wowsrc's spec pages now against NaowhForever_BiS/BiS/Data/BiS.lua."""
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    theirs = {}
    for _, slug in spec_slugs():
        theirs[slug] = parse_spec(slug)[:2]
        time.sleep(1)   # one page at a time, gently
    found = bis_changes(current_specs(), theirs, cache, settler(cache))
    if not found:
        head = ["## BiS lists from wowsrc.com", "",
                "Their spec pages match `NaowhForever_BiS/BiS/Data/BiS.lua`: nothing new."]
    else:
        import wago
        specs = len({line.split("**")[1] for line in found if line.startswith("- **")})
        head = [
            "## BiS lists from wowsrc.com's latest pages", "",
            "wowsrc.com's spec pages changed since the BiS List's data was built from them. This "
            "rebuilds it from them, without asking Wowhead anything.", "",
            f"**{len(found)}** slot changes across **{specs}** specs", "",
            "### Where each part comes from", "",
            "| What | From | How |",
            "| --- | --- | --- |",
            "| Each spec's picks per slot, best first | [wowsrc.com](https://wowsrc.com) spec pages, read "
            "today (with their permission) | `Tools/build/bis_data.py --offline` |",
            "| An item's name to its ID | `Tools/data/bis_item_ids.json`, else the game's own item table "
            f"(ItemSparse, build {wago.BUILD}) by name, quality and item level | `--offline` |",
            "| Where an item comes from (its source line) | wowsrc's own; else `Tools/data/bis_sources.json` "
            "| Wowhead is never asked in CI |",
            "", "### What changed (top picks, items added or taken off)", ""]
    from wowsrc import shortened, to_summary
    whole = found
    # The pull request: a long list cut, with the run's summary page (which has it all) for the
    # rest; and whatever happens under GitHub's 65536 characters.
    found = shortened(found)
    while len("\n".join(head + found)) > REPORT_MAX and len(found) > 1:
        found = found[:-2] + ["- ... and more: run the build to see them all."]
    tail = ["", "### Before merging", "",
            "- An item marked \"not in the game's tables yet\", or listed below as left out, could not be "
            "settled offline: "
            "run `python Tools/build/bis_data.py` on your machine (it asks Wowhead).",
            "- Items with no source line: `python Tools/build/bis_data.py --sources-only`."] if found else []
    text = "\n".join(head + found + tail) + "\n"
    to_summary("\n".join(head + whole + tail) + "\n")
    if report_path:
        Path(report_path).write_text(text, encoding="utf-8")
    else:
        print(text)
    if github_output:
        with open(github_output, "a", encoding="utf-8") as f:
            f.write(f"changes={'true' if found else 'false'}\n")


def report_missing(missing):
    if missing:
        print(f"{len(missing)} items have no source; settle them in {SOURCES.name}: "
              + ", ".join(map(str, missing)), file=sys.stderr)


if __name__ == "__main__":
    main()
