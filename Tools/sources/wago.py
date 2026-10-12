"""The game client's own tables for WoW Forever, from wago.tools.

wago.tools publishes every table (DB2) of each game build as CSV, and can apply the hotfixes
Blizzard has pushed for that build: items added after the build was cut (Forever's Darkspear
Raiders and Theramore rewards, most of the Brood of Nozdormu's) are only in the hotfixes.
Its builds API lists every build it has, by product; Forever's builds come under more than
one product name (wow_classic_beta, wow_cn_beta), so a Forever build is told apart by its
version instead: 1.60 and up, where the classic game is 1.15.

BUILD is the build the Journal's data is read from: Tools/release/watch_build.py (daily, in
.github/workflows/daily-watch.yml) moves it on when a newer one is out. Used by
Tools/build/factions.py and Tools/release/watch_build.py.
"""
import csv
import io
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BUILD = "1.60.1.70338"   # the Forever client build the Journal's data is read from
# The build before it, whose hotfixed tables fill in the items BUILD's lack entirely. Hotfixes
# are recorded per build, and wago.tools records a new build's some time after it appears;
# a hotfix stays in the game from build to build until Blizzard takes it back, so the last
# build's are carried over meanwhile. Set by Tools/release/watch_build.py when it moves BUILD on.
CARRY_FROM = None
SITE = "https://wago.tools"
# Who is asking, so wago can tell these requests apart and reach us.
AGENT = "NaowhForever-tools (+https://github.com/naowh-gaming/NaowhForever)"
FOREVER_MINOR = 60   # Forever's versions are 1.60 and up
# How much of the items earlier builds got by hotfix a build must have, with its own hotfixes,
# for wago.tools to count as having recorded them (hotfix_coverage). Below it, they are still
# coming; above it, an item it lacks was removed by Blizzard. A build whose hotfixes are not in
# yet has next to none of them (1.60.1.70170 at first: 0 of 4388).
CAUGHT_UP = 0.98


def fetch(url):
    """The page's text. A busy answer (429, 502 to 504) or a slow one (no answer in time) is
    retried after a pause: wago.tools has days like that."""
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    for wait in (10, 30, 60, None):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            if e.code not in (429, 502, 503, 504) or wait is None:
                raise
            print(f"  {e.code} from wago.tools, retrying in {wait}s", file=sys.stderr)
        except (TimeoutError, urllib.error.URLError) as e:
            if wait is None:
                raise
            print(f"  no answer from wago.tools ({e}), retrying in {wait}s", file=sys.stderr)
        time.sleep(wait)


# The columns the Journal's tools read from each table. For a build wago has only just
# added, it may not know a table's layout yet and names the columns Field_1_60_1_..._000:
# such a table cannot be read until it does (usually within a day or two).
COLUMNS = {
    "DungeonEncounter": ("ID", "Name_lang", "MapID"),
    "Map": ("ID", "MapName_lang", "InstanceType", "MaxPlayers"),
    "Faction": ("ID", "Name_lang"),
    "Item": ("ID", "ClassID", "SubclassID"),
    "ItemSparse": ("ID", "MinFactionID", "MinReputation", "BuyPrice", "OverallQualityID", "ItemLevel",
                   "RequiredLevel", "InventoryType"),
}

tables = {}   # (table, build, hotfixes) -> its rows, read once per run


def table(name, build=BUILD, hotfixes=True):
    """The table's rows for the build, each a dict of its columns (all strings), with the
    build's hotfixes applied unless hotfixes is False."""
    key = (name, build, hotfixes)
    if key not in tables:
        query = {"build": build}
        if hotfixes:
            query["useHotfixes"] = "1"
        text = fetch(f"{SITE}/db2/{name}/csv?{urllib.parse.urlencode(query)}")
        tables[key] = list(csv.DictReader(io.StringIO(text)))
    return tables[key]


def unreadable(build, hotfixes=True):
    """The tables in COLUMNS whose layout wago does not know yet for the build (empty when all
    can be read)."""
    missing = []
    for name, columns in COLUMNS.items():
        rows = table(name, build, hotfixes)
        if not rows or any(column not in rows[0] for column in columns):
            missing.append(name)
    return missing


def hotfixed_items(build):
    """The IDs of the items the build gets by hotfix: in its item table with its hotfixes
    applied, not in the table without."""
    plain = {row["ID"] for row in table("ItemSparse", build, hotfixes=False)}
    return {row["ID"] for row in table("ItemSparse", build)} - plain


def hotfix_coverage(build, sources):
    """How far wago.tools has recorded the build's own hotfixes: the share of the items the
    source builds got by hotfix that the build has, with its hotfixes (1.0 when they got none).
    The sources are the builds the Journal's data came from: wago.BUILD and CARRY_FROM."""
    wanted = set()
    for source in sources:
        wanted |= hotfixed_items(source)
    if not wanted:
        return 1.0
    have = {row["ID"] for row in table("ItemSparse", build)}
    return len(wanted & have) / len(wanted)


def version_key(version):
    """"1.60.1.70124" -> (1, 60, 1, 70124), so versions sort as numbers."""
    return tuple(int(part) for part in version.split("."))


def is_forever(version):
    major, minor = version_key(version)[:2]
    return major == 1 and minor >= FOREVER_MINOR


def forever_builds():
    """Every Forever build wago knows, newest first: [{version, products, created_at}], a build
    listed under several products once, with all of them."""
    found = {}
    for product, builds in json.loads(fetch(f"{SITE}/api/builds")).items():
        for build in builds:
            version = build.get("version", "")
            if not version or not is_forever(version):
                continue
            entry = found.setdefault(version, {"version": version, "products": [], "created_at": ""})
            entry["products"].append(product)
            # When wago first saw it, under any product.
            when = build.get("created_at") or ""
            if when and (not entry["created_at"] or when < entry["created_at"]):
                entry["created_at"] = when
    return sorted(found.values(), key=lambda b: version_key(b["version"]), reverse=True)
