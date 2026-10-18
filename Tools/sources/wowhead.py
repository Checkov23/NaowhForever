"""Reading Wowhead's Forever pages, shared by the tools that do: fetching a page politely, a
listview's rows, a dungeon guide's loot, and writing what they read as Lua.

Used by Tools/build/journal.py, build/factions.py, release/watch_build.py and sources/wowsrc.py.
"""
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

WOWHEAD = "https://www.wowhead.com/forever"
# Named, as wago.py and wowsrc.py name us, so Wowhead can tell the tools apart and allow them.
AGENT = "NaowhForever-tools (+https://github.com/naowh-gaming/NaowhForever)"
# Wowhead inventory types that go in a gear slot: no shirt (4), bag (18), tabard (19),
# ammo (24) or quiver (27).
EQUIPPABLE = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 22, 23, 25, 26, 28}
SEP = " \u00b7 "


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    # Wowhead's CDN answers 403 once requests come too fast; it lifts after a pause.
    for wait in (30, 60, 120, 240, None):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                page = r.read().decode("utf-8")
            time.sleep(1)
            return page
        except urllib.error.HTTPError as e:
            if e.code not in (403, 429, 503) or wait is None:
                raise
            print(f"  {e.code} from {urllib.parse.urlsplit(url).netloc}, retrying in {wait}s", file=sys.stderr)
            time.sleep(wait)


def listview(page, lv_id):
    start = page.find(f"id: '{lv_id}'")
    if start < 0:
        return []
    data = re.compile(r"data:\s*").search(page, start)
    return json.JSONDecoder().raw_decode(page[data.end():])[0]


def keep(item):
    return item.get("quality", 0) >= 2 and item.get("slot") in EQUIPPABLE


def fields(item, boss):
    return {
        "name": item["name"], "slot": item["slot"], "class": item["classs"],
        "subclass": item["subclass"], "level": item["level"], "reqlevel": item.get("reqlevel") or 0,
        "quality": item["quality"], "boss": boss,
    }


def guide_loot(slug):
    """The gear a Wowhead dungeon guide's Loot tabs list, by boss."""
    page = fetch(f"{WOWHEAD}/guide/{slug}")
    markup = json.loads(re.search(r'WH\.markup\.printHtml\(("(?:[^"\\]|\\.)*")', page).group(1))
    loot = markup[markup.index('[tabs name="Loot"'):]
    loot = loot[:loot.index("[/tabs]")]
    items = []
    for boss, body in re.findall(r'\[tab name="([^"]+)"\](.*?)\[/tab\]', loot, re.S):
        for item_id in re.findall(r"\[item=(\d+)\]", body):
            xml = fetch(f"{WOWHEAD}/item={item_id}&xml")
            item = json.loads("{" + re.search(r"<json><!\[CDATA\[(.*?)\]\]></json>", xml, re.S).group(1) + "}")
            if keep(item):
                items.append(dict(fields(item, boss.strip()), id=int(item_id)))
    return items


def lua_string(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + s.replace("\u00b7", "\\194\\183") + '"'


def kind(item):
    """(item class, subclass): 2 weapon or 4 armor; anything with no armor type is 0."""
    if item["class"] == 2:
        return 2, item["subclass"]
    return 4, max(item["subclass"], 0)
