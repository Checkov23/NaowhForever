"""Build Tools/data/foreverchanges_quests.json: every quest ForeverChanges lists for Forever, and
where its quest givers stand, for Tools/build/completo_quests.py.

ForeverChanges lists the quests Forever gives (Classic's, and the ones new to Forever as its
addon's players meet them), each giver on Forever's own maps. completo_quests.py keeps only the
quests listed here, adds the ones Wowhead's zone pages lack, and places a quest at its giver from
here before anything else.

- The list (/quests/list.json): each quest's name, level, required level, side, class mask (the
  game's, as Wowhead's) and the zone or category it is filed under. Read every run, so a quest
  new to it comes in.
- Each quest's page (/quest/<id>): its map's zones, each a uiMapID with pins in map percent; the
  pins marked start are its givers. A quest an item begins has none. A page read is cached and
  not read again: delete its entry, or the file, to read it again.

--report FILE writes what the list gained, lost and changed since the last run, in Markdown, for
the daily watch (.github/workflows/daily-watch.yml).

Usage: python Tools/build/foreverchanges_quests.py [--offline] [--report FILE]
"""
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wowhead  # noqa: E402
from completo_quests import load, save  # noqa: E402

SITE = "https://foreverchanges.pro"
OUT = paths.DATA / "foreverchanges_quests.json"
GAP = 1
SIDES = {"a": 1, "h": 2}
# The page's data comes as React Server Component chunks, JSON strings pushed in order.
PUSH = re.compile(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)')
ZONES = '"zones":['
REPORT_ROWS = 50   # quests named per list in the report; the rest are counted


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": wowhead.AGENT})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def quest_row(row):
    """A list row as completo_quests.py's zone rows have it, and the category it is filed under."""
    return {"name": row["n"], "level": row["l"], "reqlevel": row["m"], "side": SIDES.get(row["s"], 3),
            "reqclass": row.get("cl") or 0, "category": row["c"]}


def parse_starts(page):
    """[[uiMapID, x, y, giver], ...]: the quest page's start pins, in its order."""
    data = "".join(json.loads(m.group(1)) for m in PUSH.finditer(page))
    at = data.find(ZONES)
    if at < 0:
        return []
    zones = json.JSONDecoder().raw_decode(data, at + len(ZONES) - 1)[0]
    return [[z["id"], pin["x"], pin["y"], pin["name"]] for z in zones for pin in z["pins"] if pin.get("start")]


def report(before, after):
    """The quests the list gained, lost and changed (level, side, class or category), in Markdown."""
    sections = (("New", [q for q in after if q not in before], after),
                ("Gone", [q for q in before if q not in after], before),
                ("Changed", [q for q in after if q in before and before[q] != after[q]], after))
    counts = ", ".join(f"{len(ids)} {title.lower()}" for title, ids, _ in sections)
    lines = ["### Quests", "", f"{SITE}/quests lists {len(after)} quests: {counts}."]
    for title, ids, quests in sections:
        if not ids:
            continue
        lines += ["", f"**{title}:**", ""]
        lines += [f"- {quests[q]['name']} ({q}), level {quests[q]['level']}" for q in ids[:REPORT_ROWS]]
        if len(ids) > REPORT_ROWS:
            lines.append(f"- and {len(ids) - REPORT_ROWS} more")
    return "\n".join(lines) + "\n"


def main():
    offline = "--offline" in sys.argv
    report_to = sys.argv[sys.argv.index("--report") + 1] if "--report" in sys.argv else None
    data = load(OUT) or {"quests": {}, "starts": {}}
    before = data["quests"]
    if not offline:
        rows = json.loads(fetch(f"{SITE}/quests/list.json"))
        data["quests"] = {str(row["i"]): quest_row(row) for row in rows}
        save(OUT, data)
    todo = [q for q in data["quests"] if q not in data["starts"]]
    print(f"{len(data['quests'])} quests, {len(todo)} quest pages to read")
    failed = []
    for n, qid in enumerate([] if offline else todo, 1):
        try:
            data["starts"][qid] = parse_starts(fetch(f"{SITE}/quest/{qid}"))
        except (urllib.error.URLError, ValueError) as e:
            failed.append(f"quest {qid}: {e}")
            continue
        if n % 50 == 0:
            save(OUT, data)
            print(f"  {n}/{len(todo)}")
        time.sleep(GAP)
    save(OUT, data)
    if report_to:
        Path(report_to).write_text(report(before, data["quests"]), encoding="utf-8")
    for line in failed:
        print("FAILED", line, file=sys.stderr)


if __name__ == "__main__":
    main()
