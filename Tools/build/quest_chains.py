"""Build NaowhForever_DungeonJournal/Data/QuestChains.lua from Wowhead's Forever quest pages.

Each quest page (/forever/quest=<id>) with a chain has a "Series" box in its infobox: a
<table class="series"> with one row per step in order, each step a link to its quest, or
<b> for the page's own quest. A row can hold more than one quest (the faction or class
versions of that step). Every quest ID in NaowhForever_DungeonJournal/Data/Quests.lua is looked up,
including its alt, steps and lead IDs, and every one in Data/BiSQuests.lua (the BiS List's
quests, from Tools/build/bis_quests.py, which runs first). Answers are cached in quest_chains.json (null for
a quest with no chain); delete an entry to fetch it again.

It also works out what must be done before each dungeon quest can be picked up. Wowhead's
quest pages have no field for that: their Series box is only a fragment of a long chain
(The Defias Brotherhood, 166, shows 155 and 166 of the six steps before it). The Forever
dungeon quest guide does link it: its note on a quest names the quest its prerequisites
start with ("Complete 6 quests, starting with [quest=65]") or the quest whose
prerequisites it shares. So a quest's prerequisites are those starting quests with the rest
of their Series, walked back through any dungeon quest among them, then the steps before
the quest in its own Series. The guide's notes are cached in quest_guide.json; each quest
page's name and required level ("Requires level N" in its Quick Facts) in quest_info.json.

Usage: python Tools/build/quest_chains.py
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
import wowhead  # noqa: E402

ROOT = paths.ROOT
DATA = ROOT / "NaowhForever_DungeonJournal" / "Data" / "Quests.lua"
BIS_DATA = ROOT / "NaowhForever_DungeonJournal" / "Data" / "BiSQuests.lua"
OUT = ROOT / "NaowhForever_DungeonJournal" / "Data" / "QuestChains.lua"
CACHE = paths.DATA / "quest_chains.json"
# Where each chain step starts, from the quest page's map: { zone, coord, npc, npcId }, or
# null for a quest with no start on a map. Delete an entry to fetch it again.
STARTS = paths.DATA / "quest_starts.json"
# The guide's note on each quest: { note, quests, seps }, the note's text, the quests it
# links in order, and the text between each two of them. Delete the file to fetch it again.
GUIDE = paths.DATA / "quest_guide.json"
GUIDE_URL = "https://www.wowhead.com/forever/guide/dungeons/every-dungeon-quest-location"
# Each quest page's { name, reqlevel }. Delete an entry to fetch it again.
INFO = paths.DATA / "quest_info.json"

# A note that lists quests to complete first, and one whose linked quests come after it
# instead ("Prerequisite to pick up X", "Starts X", a breadcrumb, "Must pick up X first",
# which only needs X in the log).
PRE = re.compile(r"complet|\brequires\b|opens after|prerequisite quests", re.I)
NOT_PRE = re.compile(r"^prerequisite (?:to|for)\b|complete (?:to be eligible|quest to pick up)"
                     r"|\bstarts\b|breadcrumb|leads to|must pick up", re.I)
SAME = re.compile(r"^same prerequisites as", re.I)
COUNT = re.compile(r"complete (\d+) quests|(\d+) prerequisite quests", re.I)

# Wowhead's zone (area) IDs to the client's uiMapIDs.
ZONE_MAP = {
    1: 1426, 3: 1418, 4: 1419, 8: 1435, 10: 1431, 11: 1437, 12: 1429, 14: 1411, 15: 1445,
    16: 1447, 17: 1413, 28: 1422, 33: 1434, 36: 1416, 38: 1432, 40: 1436, 41: 1430,
    44: 1433, 45: 1417, 46: 1428, 47: 1425, 51: 1427, 85: 1420, 130: 1421, 139: 1423,
    141: 1438, 148: 1439, 215: 1412, 267: 1424, 331: 1440, 357: 1444, 361: 1448,
    400: 1441, 405: 1443, 406: 1442, 440: 1446, 490: 1449, 493: 1450, 618: 1452,
    1377: 1451, 1497: 1458, 1519: 1453, 1537: 1455, 1637: 1454, 1638: 1456, 1657: 1457,
    16593: 2521,   # Zephras Isle, Forever's
}
# Forever redrew these, and Wowhead still gives their classic coordinates. Stormwind has
# enough known quest givers to fit the conversion; on the others a step only gets a spot
# when its quest giver also gives a quest in Data/Quests.lua.
REDRAWN = {1453, 1412, 1433, 1423}
FIT_MAP = 1453


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": wowhead.AGENT})
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


def data_text():
    """Data/Quests.lua, then Data/BiSQuests.lua once it is built: the Journal's quests first."""
    return "\n".join(p.read_text(encoding="utf-8") for p in (DATA, BIS_DATA) if p.exists())


def quest_ids():
    """Every quest ID in Data/Quests.lua and Data/BiSQuests.lua, its own first, in file order."""
    ids = []
    src = data_text()
    for line in re.findall(r'^\s+\{ \d+, ".*$|^\s+steps = .*$', src, re.M):
        own = re.match(r'\s+\{ (\d+), "', line)
        found = [own.group(1)] if own else []
        for field in re.findall(r'(?:alt|steps|lead) = (\{(?:[^{}]|\{[^{}]*\})*\})', line):
            found += re.findall(r"\d+", field)
        for i in found:
            if int(i) not in ids:
                ids.append(int(i))
    return ids


def parse(quest_id, page):
    """{ "chain": [[ids of step 1], ...], "names": { id: name } }, or None without a chain."""
    table = re.search(r'<table class="series">(.*?)</table>', page, re.S)
    if not table:
        return None
    chain, names = [], {}
    for row in re.findall(r"<tr>(.*?)</tr>", table.group(1), re.S):
        step = []
        for qid, name in re.findall(r'href="/forever/quest=(\d+)[^"]*">([^<]*)</a>', row):
            step.append(int(qid))
            names[qid] = html.unescape(name)
        own = re.search(r"<b>([^<]*)</b>", row)
        if own:
            step.insert(0, quest_id)
            names[str(quest_id)] = html.unescape(own.group(1))
        if not step:
            raise ValueError(f"quest {quest_id}: series row without a quest: {row!r}")
        chain.append(step)
    return {"chain": chain, "names": names}


def parse_start(page):
    """The quest giver on the quest page's map, or None when the page has no start."""
    mapper = re.search(r"new Mapper\((\{.*?\})\);", page, re.S)
    if not mapper:
        return None
    for zone, objective in (json.loads(mapper.group(1)).get("objectives") or {}).items():
        for level in objective.get("levels", []):
            for point in level:
                if point.get("point") == "start" and point.get("coord"):
                    return {"zone": int(zone), "coord": point["coord"], "npc": point.get("name"),
                            "npcId": point.get("id")}
    return None


def parse_info(page):
    """The quest page's name, and its required level from the Quick Facts (None without)."""
    info = re.search(r"g_pageInfo = (\{.*?\});", page)
    level = re.search(r"\[li\]Requires level (\d+)\[\\/li\]", page)
    return {"name": json.loads(info.group(1))["name"] if info else None,
            "reqlevel": int(level.group(1)) if level else None}


def plain(markup):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", markup))).strip()


def parse_guide(page):
    """questID -> the guide's note on it: its text, the quests it links, and what is between."""
    rows = {}
    for qid, rest in re.findall(r'<tr><td><a href="/forever/quest=(\d+)[^"]*">[^<]*</a></td>(.*?)</tr>',
                                page, re.S):
        cells = re.findall(r"<td>(.*?)</td>", rest, re.S)
        cell = cells[-1] if cells else ""
        # The note follows a line break; a few run on after the /way coordinates instead.
        note = re.search(r"<br\s*/?>(.*)$", cell, re.S) or re.search(r"/way [\d.]+ [\d.]+\.?(.*)$", cell, re.S)
        note = note.group(1) if note else ""
        link = r'<a href="/forever/quest=\d+[^"]*">[^<]*</a>'
        if qid not in rows or not rows[qid]["note"]:
            rows[qid] = {"note": plain(note),
                         "quests": [int(i) for i in re.findall(r'href="/forever/quest=(\d+)', note)],
                         "seps": [plain(s) for s in re.split(link, note)[1:-1]]}
    return rows


def guide_prereqs(row):
    """("same", questID), ("pre", [steps]) or None. A step is a list of IDs: two links with
    only a slash between them are one step's faction versions."""
    if not row or not row["quests"]:
        return None
    if SAME.search(row["note"]):
        return "same", row["quests"][0]
    if not PRE.search(row["note"]) or NOT_PRE.search(row["note"]):
        return None
    steps = []
    for i, qid in enumerate(row["quests"]):
        if i > 0 and row["seps"][i - 1] == "/":
            steps[-1].append(qid)
        else:
            steps.append([qid])
    return "pre", steps


def without_note(where, note):
    """The data file's where text with the guide's note taken out, or None when the note is
    not in it. Spaces are ignored in the match: the guide runs a link on without one."""
    chars = [(c, i) for i, c in enumerate(where) if not c.isspace()]
    hay = "".join(c for c, _ in chars)
    needle = re.sub(r"\s+", "", note)
    k = hay.find(needle) if needle else -1
    if k < 0:
        return None
    a, b = chars[k][1], chars[k + len(needle) - 1][1] + 1
    out = re.sub(r"\s+", " ", where[:a] + " " + where[b:]).strip()
    return re.sub(r"\s+([,.;)])", r"\1", out)


def solve3(m, v):
    """Solves the 3x3 system m * x = v by elimination."""
    a = [row[:] + [v[i]] for i, row in enumerate(m)]
    for c in range(3):
        p = max(range(c, 3), key=lambda r: abs(a[r][c]))
        a[c], a[p] = a[p], a[c]
        for r in range(3):
            if r != c:
                f = a[r][c] / a[c][c]
                a[r] = [x - f * y for x, y in zip(a[r], a[c])]
    return [a[i][3] / a[i][i] for i in range(3)]


def fit(pairs):
    """Least-squares affine map from classic (x, y) to Forever (x, y), and its worst error."""
    rows = [(x, y, 1.0) for (x, y), _ in pairs]
    m = [[sum(r[i] * r[j] for r in rows) for j in range(3)] for i in range(3)]
    cx = solve3(m, [sum(r[i] * t[0] for r, (_, t) in zip(rows, pairs)) for i in range(3)])
    cy = solve3(m, [sum(r[i] * t[1] for r, (_, t) in zip(rows, pairs)) for i in range(3)])

    def to(x, y):
        return (cx[0] * x + cx[1] * y + cx[2], cy[0] * x + cy[1] * y + cy[2])

    worst = max(abs(a - b) for (s, t) in pairs for a, b in zip(to(*s), t))
    return to, worst


def own_spots():
    """questID -> (uiMapID, x, y) for every quest in Data/Quests.lua with a quest giver spot."""
    spots = {}
    for line in DATA.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s+\{ (\d+), ".*?", \d+, "[ABH]", .*?"(?:, (\d+), ([\d.]+), ([\d.]+))?(?:,|\s*\})', line)
        if m and m.group(2):
            spots.setdefault(int(m.group(1)), (int(m.group(2)), float(m.group(3)), float(m.group(4))))
    return spots


def own_wheres():
    """questID -> the data file's where text (the quest's sixth field)."""
    wheres = {}
    for m in re.finditer(r'^\s+\{ (\d+), "(?:[^"\\]|\\.)*", \d+, "[ABH]", (?:true|false|"pre"), '
                         r'"((?:[^"\\]|\\.)*)"', DATA.read_text(encoding="utf-8"), re.M):
        wheres.setdefault(int(m.group(1)), m.group(2).replace('\\"', '"').replace("\\\\", "\\"))
    return wheres


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# One page per quest per run, however many of the caches below still need it.
pages = {}


def quest_page(quest_id):
    if quest_id not in pages:
        pages[quest_id] = fetch(f"https://www.wowhead.com/forever/quest={quest_id}")
        time.sleep(1)
    return pages[quest_id]


def load(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save(path, data):
    path.write_text(json.dumps(data, indent=1, sort_keys=True), encoding="utf-8")


def fill(cache, path, wanted, parser, failed, what):
    """Reads each wanted quest's page into cache, saving as it goes."""
    for quest_id in wanted:
        key = str(quest_id)
        if key in cache:
            continue
        try:
            cache[key] = parser(quest_id, quest_page(quest_id))
        except (urllib.error.HTTPError, ValueError) as e:
            failed.append(f"{quest_id} ({what}): {e}")
            continue
        save(path, cache)


def main():
    cache = load(CACHE)
    ids = quest_ids()
    failed = []
    fill(cache, CACHE, ids, parse, failed, "chain")

    journal = set(int(i) for i in re.findall(r'^\s+\{ (\d+), "', DATA.read_text(encoding="utf-8"), re.M))
    own = set(int(i) for i in re.findall(r'^\s+\{ (\d+), "', data_text(), re.M))
    chains, names = {}, {}
    for quest_id in ids:
        entry = cache.get(str(quest_id))
        if not entry or len(entry["chain"]) < 2:
            continue
        chains[quest_id] = entry["chain"]
        for step in entry["chain"]:
            for i in step:
                if i not in journal:
                    names[i] = entry["names"][str(i)]

    # What each dungeon quest needs done first (see the top of this file).
    guide = load(GUIDE)
    if not guide:
        guide = parse_guide(fetch(GUIDE_URL))
        save(GUIDE, guide)
    firsts = {}
    for key, row in guide.items():
        found = guide_prereqs(row)
        if found and found[0] == "pre":
            firsts[int(key)] = found[1]
    # The Series of every quest a prerequisite list starts with.
    fill(cache, CACHE, sorted({i for steps in firsts.values() for step in steps for i in step}),
         parse, failed, "chain")

    def series(quest_id):
        entry = cache.get(str(quest_id))
        return entry["chain"] if entry else None

    def fragment(step, stop):
        """The step and the rest of its Series from it on, up to the quest it is for. A step
        with faction versions merges their Series row by row when they line up."""
        runs = []
        for i in step:
            chain = series(i) or [[i]]
            pos = next(k for k, row in enumerate(chain) if i in row) if any(i in r for r in chain) else 0
            run = []
            for row in chain[pos:]:
                if stop in row:
                    break
                run.append(list(row))
            runs.append(run or [[i]])
        if all(len(r) == len(runs[0]) for r in runs):
            return [sorted({i for r in runs for i in r[k]}, key=lambda i: (i not in step, i))
                    for k in range(len(runs[0]))]
        return [sorted(set(step))] + runs[0][1:]

    memo = {}

    def prereqs(quest_id, walking):
        if quest_id in memo:
            return memo[quest_id]
        if quest_id in walking:
            raise ValueError(f"quest {quest_id}: its prerequisites lead back to it")
        walking = walking | {quest_id}
        tail = []
        for row in series(quest_id) or []:
            if quest_id in row:
                break
            tail.append(list(row))
        out, seen = [], set()

        def add(steps):
            for step in steps:
                if quest_id in step or seen & set(step):
                    continue
                out.append(step)
                seen.update(step)

        found = guide_prereqs(guide.get(str(quest_id)))
        if found and found[0] == "same":
            add(prereqs(found[1], walking))
        elif found:
            for step in found[1]:
                at = next((k for k, row in enumerate(tail) if set(step) & set(row)), None)
                if at is not None:
                    # It starts within the quest's own Series: that covers it.
                    tail = tail[at:]
                    continue
                for i in step:
                    if i in own and i != quest_id:
                        add(prereqs(i, walking))
                add(fragment(step, quest_id))
        # A Series that begins with another dungeon quest carries that quest's own.
        for i in tail[0] if tail else []:
            if i in own:
                add(prereqs(i, walking))
        add(tail)
        memo[quest_id] = out
        return out

    info = load(INFO)
    fill(info, INFO, sorted(own), lambda _, page: parse_info(page), failed, "level")
    wheres = own_wheres()
    # "Same prerequisites as X" goes both ways, and the note's side can see more of them:
    # Red Silk Bandanas (214) walks to 142, while The Defias Brotherhood (166), which shares
    # its prerequisites, has 155 in its own Series. The other quest's list is taken when it
    # matches the count this quest's own note gives and this quest's list does not.
    sharers = {}
    for key, row in guide.items():
        found = guide_prereqs(row)
        if found and found[0] == "same":
            sharers.setdefault(found[1], []).append(int(key))

    def guide_count(quest_id):
        row = guide.get(str(quest_id))
        count = COUNT.search(row["note"]) if row else None
        return count and int(count.group(1) or count.group(2))

    prereq_lists, min_levels, short_wheres, counts = {}, {}, {}, []
    for quest_id in sorted(own):
        steps = prereqs(quest_id, frozenset())
        want = guide_count(quest_id)
        for other in sharers.get(quest_id, []):
            theirs = prereqs(other, frozenset())
            if want and len(steps) != want and len(theirs) == want and not any(quest_id in s for s in theirs):
                steps = theirs
        level = (info.get(str(quest_id)) or {}).get("reqlevel")
        if level and level > 1:
            min_levels[quest_id] = level
        if not steps:
            continue
        prereq_lists[quest_id] = steps
        row = guide.get(str(quest_id))
        if row and row["note"] and quest_id in wheres:
            short = without_note(wheres[quest_id], row["note"])
            if short:
                short_wheres[quest_id] = short
        if want and want != len(steps):
            counts.append(f"{quest_id}: the guide says {want}, found {len(steps)}")
    # Each quest's list is built from its own steps' lists, so a loop would show up as a
    # quest among its own prerequisites; checked here again after the walk.
    for quest_id, steps in prereq_lists.items():
        for step in steps:
            for i in step:
                if quest_id in {j for s in prereq_lists.get(i, []) for j in s}:
                    raise ValueError(f"quests {quest_id} and {i} each need the other first")

    # Names for the prerequisite steps that are neither in Data/Quests.lua nor in a chain.
    for entry in cache.values():
        for i, name in (entry or {}).get("names", {}).items():
            if int(i) not in journal:
                names.setdefault(int(i), name)
    wanted = sorted({i for steps in prereq_lists.values() for step in steps for i in step
                     if i not in journal and i not in names})
    fill(info, INFO, wanted, lambda _, page: parse_info(page), failed, "name")
    for steps in prereq_lists.values():
        for step in steps:
            for i in step:
                if i not in journal:
                    name = names.get(i) or (info.get(str(i)) or {}).get("name")
                    if name:
                        names[i] = name
                    else:
                        failed.append(f"{i}: no name")

    # Where each step starts. The data file's own quests keep its spots; the rest come from
    # their quest pages, and the data file's quests on the redrawn maps are fetched too, to
    # match quest givers and fit the conversion.
    spots = own_spots()
    steps = sorted({i for chain in chains.values() for step in chain for i in step}
                   | {i for lst in prereq_lists.values() for step in lst for i in step})
    wanted = [i for i in steps if i not in spots] + sorted(q for q, s in spots.items() if s[0] in REDRAWN)
    starts = load(STARTS)
    fill(starts, STARTS, wanted, lambda _, page: parse_start(page), failed, "start")

    known, pairs = {}, []
    for quest_id, (map_id, x, y) in spots.items():
        start = starts.get(str(quest_id))
        if map_id in REDRAWN and start and ZONE_MAP.get(start["zone"]) == map_id:
            known[start["npcId"]] = (map_id, x, y)
            if map_id == FIT_MAP:
                pairs.append((tuple(start["coord"]), (x, y)))
    # Some quest givers walk about (Nikova Raskol does), so their spot on the page and in the
    # data file differ; one that throws the fit off is left out.
    to_forever, worst = fit(pairs)
    if worst > 1.5:
        tries = [(fit(pairs[:i] + pairs[i + 1:]), i) for i in range(len(pairs))]
        (to_forever, worst), dropped = min(tries, key=lambda t: t[0][1])
        print(f"Stormwind fit leaves out the quest giver at {pairs[dropped][0]}", file=sys.stderr)
        pairs = pairs[:dropped] + pairs[dropped + 1:]
    print(f"Stormwind fit from {len(pairs)} quest givers, worst error {worst:.2f}", file=sys.stderr)
    if worst > 1.5:
        to_forever = None

    chain_starts = {}
    for quest_id in steps:
        start = quest_id not in spots and starts.get(str(quest_id))
        map_id = start and ZONE_MAP.get(start["zone"])
        if not map_id:
            continue
        x, y = start["coord"]
        if start["npcId"] in known:
            map_id, x, y = known[start["npcId"]]
        elif map_id in REDRAWN:
            if map_id != FIT_MAP or not to_forever:
                continue
            x, y = to_forever(x, y)
        chain_starts[quest_id] = (map_id, round(x, 1), round(y, 1), start["npc"] or "")

    def step_lua(step):
        return str(step[0]) if len(step) == 1 else "{ " + ", ".join(str(i) for i in step) + " }"

    # QuestChains: questID -> every step of its chain in order, itself included. A step is a quest
    # ID, or a table of IDs (one per faction or class), any of which counts. QuestPrereqs: questID
    # -> the steps to complete before it can be picked up, in order, steps as above: the quests
    # Wowhead's Forever dungeon quest guide says its prerequisites start with and their Series,
    # then the steps before it in its own Series. QuestMinLevel: questID -> the level it can be
    # picked up at (Requires level). QuestWhere: questID -> its where text without the guide's
    # prerequisite note, for the quests with a prerequisite list; the full text stays in
    # Data/Quests.lua. QuestChainNames: the names of the steps that are not quests in
    # Data/Quests.lua. QuestChainStarts: where those steps start, { uiMapID, x, y, quest giver },
    # from the quest page's map; missing where the page has none or the map is not known.
    lines = [
        "-- QuestChains.lua: each dungeon quest's chain, prerequisites and level, generated by "
        "Tools/build/quest_chains.py.",
        "local J = _G.NaowhForever.Journal",
        "",
        "J.QuestChains = {",
    ]
    for quest_id in sorted(chains):
        lines.append(f"    [{quest_id}] = {{ {', '.join(step_lua(s) for s in chains[quest_id])} }},")
    lines.append("}")
    lines.append("")
    lines.append("J.QuestPrereqs = {")
    for quest_id in sorted(prereq_lists):
        lines.append(f"    [{quest_id}] = {{ {', '.join(step_lua(s) for s in prereq_lists[quest_id])} }},")
    lines.append("}")
    lines.append("")
    lines.append("J.QuestMinLevel = {")
    for quest_id in sorted(min_levels):
        lines.append(f"    [{quest_id}] = {min_levels[quest_id]},")
    lines.append("}")
    lines.append("")
    lines.append("J.QuestWhere = {")
    for quest_id in sorted(short_wheres):
        lines.append(f"    [{quest_id}] = {lua_string(short_wheres[quest_id])},")
    lines.append("}")
    lines.append("")
    lines.append("J.QuestChainNames = {")
    for quest_id in sorted(names):
        if any(quest_id in step for chain in list(chains.values()) + list(prereq_lists.values())
               for step in chain):
            lines.append(f"    [{quest_id}] = {lua_string(names[quest_id])},")
    lines.append("}")
    lines.append("")
    lines.append("J.QuestChainStarts = {")
    for quest_id in sorted(chain_starts):
        map_id, x, y, npc = chain_starts[quest_id]
        lines.append(f"    [{quest_id}] = {{ {map_id}, {x:g}, {y:g}, {lua_string(npc)} }},")
    lines.append("}")
    text = "\r\n".join(lines) + "\r\n"
    text.encode("ascii")
    OUT.write_text(text, encoding="utf-8", newline="")

    print(f"{len(ids)} quests, {len(chains)} in a chain, {len(prereq_lists)} with prerequisites, "
          f"{len(min_levels)} required levels, {len(names)} step names, {len(chain_starts)} step "
          f"starts -> {OUT.name}", file=sys.stderr)
    if counts:
        print(f"{len(counts)} prerequisite lists differ from the guide's count:", file=sys.stderr)
        for line in counts:
            print(f"  {line}", file=sys.stderr)
    if failed:
        print(f"{len(failed)} could not be read; run again to retry:", file=sys.stderr)
        for line in failed:
            print(f"  {line}", file=sys.stderr)


if __name__ == "__main__":
    main()
