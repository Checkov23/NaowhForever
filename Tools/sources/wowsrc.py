"""Read WoW Forever's dungeon loot from wowsrc.com, an independent, non-commercial WoW Forever
fan site (its robots.txt: "Crawl it freely"). Each of its loot pages lists a dungeon's bosses,
and under each the items it drops, Forever's new ones marked, with the drop chance the game
reports; it says its item data is the game's own. That places what Wowhead has not tied to a
boss yet (Worgenbane Talisman under Commander Springvale).

The pages are fetched politely (one every couple of seconds, saying who we are) and kept in
Tools/data/wowsrc_pages/ (not committed: delete a file to fetch it again, or pass --fresh); what
they say is written to Tools/data/wowsrc_loot.json:
  { dungeon slug: { "name", "updated", "bosses": [ { "name", "items": [ { "name", "quality",
    "level", "slot", "type", "chance" (percent or null), "new" } ] } ] } }
The pages give no item IDs, so items are matched by name: Tools/data/item_names.json maps each name
to its ID, filled from what we already have (the dungeon loot list, the game's item tables)
and, for the rest, by --resolve, which asks Wowhead's Classic search (names and IDs are the
same in Forever for Classic items, whose names the game's exported tables leave out) and
keeps only an ID that is in Forever's own item table. The build reads only the map, never a
search: a name not in it is reported, never guessed.

--check is the daily check (.github/workflows/daily-watch.yml): it reads the pages fresh and
says what changed on them since wowsrc_loot.json, which the Journal was last built from:
items a boss gained or lost, bosses and dungeon pages added or gone. Drop chances are left
out (they move with every kill counted). Each item gained says its ID where we know it:
from item_names.json, else the game's own item table (wago.tools; Forever's new items are
all there by name), so only an old classic item waits for --resolve. It only reads wowsrc
and the game's tables; bringing a change in needs Wowhead (an item's details), so that stays
a run on our machines.

Usage: python Tools/sources/wowsrc.py [--fresh]     fetch and read the loot pages
       python Tools/sources/wowsrc.py --resolve     add the names not mapped yet to item_names.json
                                            (--offline: from our data and the game's tables only)
       python Tools/sources/wowsrc.py --check [--report report.md] [--github-output $GITHUB_OUTPUT]
"""
import html
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402

PAGES = paths.DATA / "wowsrc_pages"
OUT = paths.DATA / "wowsrc_loot.json"
SITE = "https://wowsrc.com"
AGENT = "NaowhForever-tools (+https://github.com/naowh-gaming/NaowhForever)"
PAUSE = 2.0   # seconds between two pages fetched, not between pages read from disk

last = 0.0


def fetch(url, fresh=False):
    """The page, from Tools/data/wowsrc_pages/ when kept there, else from the site (then kept)."""
    global last
    name = re.sub(r"[^a-z0-9]+", "_", url.split("://", 1)[1].lower()).strip("_") + ".html"
    path = PAGES / name
    if path.exists() and not fresh:
        return path.read_text(encoding="utf-8")
    wait = last + PAUSE - time.time()
    if wait > 0:
        time.sleep(wait)
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(req, timeout=30) as r:
        page = r.read().decode("utf-8")
    last = time.time()
    PAGES.mkdir(exist_ok=True)
    path.write_text(page, encoding="utf-8")
    return page


def loot_urls(fresh=False):
    """Every dungeon loot page in the site's sitemap (not the list of them)."""
    urls = []
    index = fetch(f"{SITE}/sitemap-index.xml", fresh)
    for sitemap in re.findall(r"<loc>([^<]+)</loc>", index):
        for url in re.findall(r"<loc>([^<]+)</loc>", fetch(sitemap, fresh)):
            if re.search(r"/loot/[^/]+/$", url):
                urls.append(url)
    return sorted(urls)


SECTION = re.compile(r'<section class="bc" id="([^"]+)"[^>]*>\s*<h2 class="bc__h"[^>]*>(.*?)</h2>(.*?)</section>', re.S)
TIP = re.compile(r'data-tip="([^"]+)"')


def chance(text):
    """"35.7%" -> 35.7; anything else (no chance shown) -> None."""
    m = re.fullmatch(r"\s*([\d.]+)\s*%\s*", text or "")
    return float(m.group(1)) if m else None


def parse(page):
    """A loot page as { name, updated, bosses: [ { name, items } ] }."""
    title = re.search(r'<h1 class="ph__h"[^>]*>(.*?)</h1>', page, re.S)
    updated = re.search(r"(?:Last updated|Updated)[^0-9A-Za-z]{0,40}([A-Z][a-z]+ \d{1,2}, \d{4})", page)
    bosses = []
    for _, name, body in SECTION.findall(page):
        items = []
        for tip in TIP.findall(body):
            t = json.loads(html.unescape(tip))
            items.append({"name": t.get("n"), "quality": t.get("r"), "level": t.get("l"), "slot": t.get("sl"),
                          "type": t.get("ty"), "chance": chance(t.get("d")), "new": bool(t.get("nw"))})
        bosses.append({"name": html.unescape(re.sub(r"<[^>]+>", "", name)).strip(), "items": items})
    return {"name": html.unescape(re.sub(r"<[^>]+>", "", title.group(1))).strip() if title else None,
            "updated": updated.group(1) if updated else None, "bosses": bosses}


NAMES = paths.DATA / "item_names.json"
JOURNAL_CACHE = paths.DATA / "journal_cache.json"
SOD_COPIES = (200000, 250000)
CLASSIC_SEARCH = "https://www.wowhead.com/classic/search/suggestions-template?q="


def name_key(name):
    """A name as the map keys it: lower case, plain apostrophes, single spaces."""
    return re.sub(r"\s+", " ", (name or "").lower().replace("’", "'")).strip()


def item_names():
    """name_key -> item ID, from the committed map; {} before it exists."""
    return json.loads(NAMES.read_text(encoding="utf-8")) if NAMES.exists() else {}


def resolve():
    """Adds to item_names.json every wowsrc item name it does not map yet: from the Journal's
    bosses' drops and the game's item tables first, else Wowhead's Classic search, keeping only an
    ID Forever's item table has. Ambiguous or unknown names are listed, not mapped."""
    import urllib.parse
    import wago
    from wowhead import fetch as wowhead   # waits and retries when Wowhead says slow down
    loot = json.loads(OUT.read_text(encoding="utf-8"))
    mapped = item_names()
    wanted = sorted({name_key(i["name"]) for d in loot.values() for b in d["bosses"] for i in b["items"]} - set(mapped))
    forever = {int(r["ID"]) for build in (wago.BUILD, wago.CARRY_FROM) if build for r in wago.table("Item", build)}
    local = {}
    # The bosses' drops build/journal.py read from Wowhead, names kept.
    for key, found in json.loads(JOURNAL_CACHE.read_text(encoding="utf-8")).items():
        if key.startswith("drops5:") and isinstance(found, dict):
            for r in found["items"]:
                if r.get("name"):
                    local.setdefault(name_key(r["name"]), set()).add(r["id"])
    for build in (wago.BUILD, wago.CARRY_FROM):
        if build:
            for r in wago.table("ItemSparse", build):
                local.setdefault(name_key(r["Display_lang"]), set()).add(int(r["ID"]))
    left = []
    for i, key in enumerate(wanted):
        ids = {x for x in local.get(key, ()) if x in forever}
        if not ids and "--offline" not in sys.argv:
            global last
            wait = last + PAUSE - time.time()
            if wait > 0:
                time.sleep(wait)
            found = json.loads(wowhead(CLASSIC_SEARCH + urllib.parse.quote(key)))
            last = time.time()
            ids = {x["id"] for x in found.get("results", [])
                   if x.get("type") == 3 and name_key(x["name"]) == key and x["id"] in forever}
        # Season of Discovery's copies of classic items (217000 to 249999) are in Forever's
        # item table too: the classic one is meant.
        if len(ids) > 1:
            ids = {x for x in ids if not SOD_COPIES[0] <= x < SOD_COPIES[1]} or ids
        if len(ids) == 1:
            mapped[key] = ids.pop()
        else:
            left.append(f"{key}: {'not found' if not ids else 'several: ' + str(sorted(ids))}")
        if i % 50 == 0:
            NAMES.write_text(json.dumps(mapped, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
            print(f"{i}/{len(wanted)}", file=sys.stderr)
    NAMES.write_text(json.dumps(mapped, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(wanted) - len(left)} of {len(wanted)} names mapped; left:", file=sys.stderr)
    for line in left:
        print("  " + line, file=sys.stderr)


def read_all(fresh=False):
    """Every loot page, read: { slug: parse(page) }."""
    loot = {}
    for url in loot_urls(fresh):
        slug = url.rstrip("/").rsplit("/", 1)[1]
        loot[slug] = parse(fetch(url, fresh))
        d = loot[slug]
        count = sum(len(b["items"]) for b in d["bosses"])
        new = sum(i["new"] for b in d["bosses"] for i in b["items"])
        # "new" is wowsrc's mark for an item new in WoW Forever, not new since the last read.
        print(f"{slug:32} {len(d['bosses']):3} bosses {count:4} items {new:3} new in Forever  "
              f"{d['updated'] or ''}", file=sys.stderr)
    return loot


def game_ids(keys):
    """name_key -> item ID for the names given, from the game's own item table (ItemSparse, for
    the builds the data is read from), where one Forever item has the name; {} when wago.tools
    cannot be read (the report then just says the name is not mapped)."""
    try:
        import wago
        forever = {r["ID"] for build in (wago.BUILD, wago.CARRY_FROM) if build for r in wago.table("Item", build)}
        found = {}
        for build in (wago.BUILD, wago.CARRY_FROM):
            if build:
                for r in wago.table("ItemSparse", build):
                    key = name_key(r.get("Display_lang"))
                    if key in keys and r["ID"] in forever:
                        found.setdefault(key, set()).add(int(r["ID"]))
        return {key: ids.pop() for key, ids in found.items() if len(ids) == 1}
    except Exception as e:   # a check that cannot reach the tables still reports the rest
        print(f"the game's item table could not be read: {e}", file=sys.stderr)
        return {}


def changes(old, new, game=None):
    """What new (pages read now) says that old (wowsrc_loot.json) does not, as Markdown lines
    under headings; [] when nothing. Items by name, bosses by name, chances left out. game:
    name_key -> ID from the game's tables, for names item_names.json does not have."""
    mapped = dict(game or {}, **item_names())
    added_pages = [new[s]["name"] or s for s in sorted(set(new) - set(old))]
    gone_pages = [old[s]["name"] or s for s in sorted(set(old) - set(new))]
    added_bosses, gone_bosses, gained, lost = [], [], [], []
    for slug in sorted(set(old) & set(new)):
        page = new[slug]["name"] or slug
        before = {b["name"]: b["items"] for b in old[slug]["bosses"]}
        after = {b["name"]: b["items"] for b in new[slug]["bosses"]}
        for boss in after:
            if boss not in before:
                if after[boss]:
                    added_bosses.append(f"- {page} / {boss}: {', '.join(i['name'] for i in after[boss])}")
                continue
            had = {name_key(i["name"]) for i in before[boss]}
            for item in after[boss]:
                if name_key(item["name"]) not in had:
                    item_id = mapped.get(name_key(item["name"]))
                    marks = [m for m, on in ((f"ID {item_id}", item_id), ("new in Forever", item["new"]),
                                             ("name not mapped yet", not item_id)) if on]
                    gained.append(f"- {page} / {boss}: {item['name']}" + (f" ({', '.join(marks)})" if marks else ""))
            has = {name_key(i["name"]) for i in after[boss]}
            for item in before[boss]:
                if name_key(item["name"]) not in has:
                    lost.append(f"- {page} / {boss}: {item['name']}")
        gone_bosses += [f"- {page} / {boss}" for boss in before if boss not in after and before[boss]]
    lines = []
    for title, rows in (("New loot pages", [f"- {p}" for p in added_pages]),
                        ("New bosses", added_bosses),
                        ("Items a boss gained", gained),
                        ("Items a boss lost (moved, or gone)", lost),
                        ("Bosses gone", gone_bosses),
                        ("Loot pages gone", [f"- {p}" for p in gone_pages])):
        if rows:
            lines += ["", f"### {title}", ""] + rows
    return lines


REPORT_MAX = 60000
SHORT = 25   # changes a pull request lists; the rest are on its run's summary page


def run_link():
    """This GitHub Actions run's page (its summary), or None outside CI."""
    server, repo, run = (os.environ.get(k) for k in ("GITHUB_SERVER_URL", "GITHUB_REPOSITORY", "GITHUB_RUN_ID"))
    return f"{server}/{repo}/actions/runs/{run}" if server and repo and run else None


def shortened(found):
    """The changes as a pull request shows them: in CI, a long list cut to SHORT lines with a
    link to the run's summary page, which has them all (to_summary)."""
    link = run_link()
    if len(found) <= SHORT or not link:
        return found
    return found[:SHORT] + ["", f"... and {len(found) - SHORT} more: [the whole list]({link}) is on the run's "
                            "summary page."]


def to_summary(text):
    """The whole report on the run's summary page, in CI."""
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(text)


def counts(found):
    """How many rows each heading of a report has: {"Items a boss gained": 3, ...}."""
    seen, heading = {}, None
    for line in found:
        if line.startswith("### "):
            heading = line[4:]
        elif line.startswith("- ") and heading:
            seen[heading] = seen.get(heading, 0) + 1
    return seen


def loot_body(found):
    """The pull request's description: what changed, where each part of the Journal comes
    from, and what is left for a run on our machines."""
    import wago
    n = counts(found)
    said = [f"**{n.get(h, 0)}** {w}" for h, w in (("Items a boss gained", "items gained"),
                                                    ("Items a boss lost (moved, or gone)", "lost"),
                                                    ("New bosses", "new bosses"), ("New loot pages", "new pages"))]
    return [
        "## Boss loot from wowsrc.com's latest pages", "",
        "wowsrc.com's WoW Forever loot pages changed since the Journal was last built from them. "
        "This rebuilds the Journal's boss loot from them, without asking Wowhead anything.", "",
        " &middot; ".join(said), "",
        "### Where each part comes from", "",
        "| What | From | How |",
        "| --- | --- | --- |",
        "| Which items each boss, chest and trash drops | [wowsrc.com](https://wowsrc.com) loot pages, read today "
        "(they allow crawling and gave us permission) | `Tools/sources/wowsrc.py` &rarr; `Tools/data/wowsrc_loot.json` |",
        "| An item's name to its ID | `Tools/data/item_names.json`, else the game's own item table (ItemSparse) "
        "| `wowsrc.py --resolve --offline` |",
        f"| A new item's level, slot, type and quality | the game's own tables (Item, ItemSparse), build "
        f"{wago.BUILD}, through [wago.tools](https://wago.tools) | `build/journal.py --offline` |",
        "| Drop chances | wowsrc's where it gives one; else Wowhead's, from our last run "
        "(`Tools/data/journal_cache.json`) | Wowhead is never asked in CI |",
        "| Bosses, kill order, rares, optional bosses, chests | `Tools/data/journal_bosses.json`, by hand "
        "| not touched |",
        "", "### What changed on their pages"] + found + [
        "", "### Before merging", "",
        "- Anything the build lists below as not in the cache nor the game's tables (an old classic "
        "item, a boss never fetched) is left out: run `python Tools/sources/wowsrc.py --resolve` and "
        "`python Tools/build/journal.py` on your machine for it.",
        "- A boss wowsrc lists that we do not (\"wowsrc boss not listed\") gets in through "
        "`Tools/data/journal_bosses.json`."]


def check(report_path=None, github_output=None):
    """The daily check: wowsrc's pages now against wowsrc_loot.json."""
    old = json.loads(OUT.read_text(encoding="utf-8"))
    new = read_all(fresh=True)
    found = changes(old, new)
    if found:
        # Names not mapped yet: the game's tables have Forever's new items by name.
        known = item_names()
        wanted = {name_key(i["name"]) for d in new.values() for b in d["bosses"] for i in b["items"]} - set(known)
        game = game_ids(wanted) if wanted else {}
        if game:
            found = changes(old, new, game)
    if not found:
        text = "## Boss loot from wowsrc.com\n\nTheir loot pages match `Tools/data/wowsrc_loot.json`: nothing new.\n"
    else:
        to_summary("\n".join(loot_body(found)) + "\n")
        # The pull request: a long list cut, with the run's summary page for the rest; and
        # whatever happens under GitHub's 65536 characters.
        short = shortened(found)
        while len("\n".join(loot_body(short))) > REPORT_MAX and len(short) > 1:
            short = short[:-2] + ["- ... and more: run `python Tools/sources/wowsrc.py --check` to see them all."]
        text = "\n".join(loot_body(short)) + "\n"
    if not found:
        to_summary(text)
    if report_path:
        Path(report_path).write_text(text, encoding="utf-8")
    else:
        print(text)
    if github_output:
        with open(github_output, "a", encoding="utf-8") as f:
            f.write(f"changes={'true' if found else 'false'}\n")


def main():
    if "--resolve" in sys.argv:
        return resolve()
    if "--check" in sys.argv:
        args = sys.argv[1:]

        def value(flag):
            return args[args.index(flag) + 1] if flag in args else None
        return check(value("--report"), value("--github-output"))
    loot = read_all("--fresh" in sys.argv)
    OUT.write_text(json.dumps(loot, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(loot)} loot pages -> {OUT.name}", file=sys.stderr)


if __name__ == "__main__":
    main()
