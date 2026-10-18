"""Build Tools/data/completo_dungeon.json: the dungeon and raid quests for the Quest List's map pins.

Wowhead files a dungeon's quests under the dungeon, not under the zone their quest giver stands in,
so Tools/build/completo_quests.py, which reads the zones, has none of them. This puts them back from
what we already have and two sources that allow it:

- Which quests, and where their giver stands: the Dungeon Journal's own list
  (NaowhForever_DungeonJournal/Data/Quests.lua, from Wowhead's Forever dungeon quest guide). Only
  the quests with a giver outside the dungeon get a spot there, and only those are kept.
- What each one asks of you: CMaNGOS's Classic world database (github.com/cmangos/classic-db, at
  COMMIT): the quest's level, the races and classes it is for, the quests before it and its giver's
  name. Its full dump is from early 2024; the updates since then are applied to the fields read here,
  and an update to them in a form not read here stops the build. Only these facts of the game are
  taken (the database's COPYRIGHT.md: the game's content is Blizzard's, not part of its GPL).
- A quest new in Forever is not in CMaNGOS: its level comes from wowsrc.com's Forever dungeon quest
  page (Tools/sources/wowsrc.py), matched by name, else the Journal's required level, and it is for
  the Journal's side, every race and class of it. wowsrc's level agrees with CMaNGOS's on every
  quest both have.

The dump and the updates are kept in Tools/data/cmangos/ (not committed). The JSON is committed;
completo_quests.py reads it, so `completo_quests.py --offline` writes the addon's data from it.

Usage: python Tools/build/dungeon_quests.py
"""
import gzip
import html
import json
import re
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wowsrc  # noqa: E402

ROOT = paths.ROOT
OUT = paths.DATA / "completo_dungeon.json"
CACHE = paths.DATA / "cmangos"
JOURNAL = ROOT / "NaowhForever_DungeonJournal" / "Data" / "Quests.lua"
COMMIT = "ec4f596146be6467ea93c57397858e329e2db852"
REPO = "cmangos/classic-db"
DUMP = "Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
AGENT = wowsrc.AGENT
QUESTS_PAGE = f"{wowsrc.SITE}/quests/"

TABLES = {
    "quest_template": ("entry", "MinLevel", "QuestLevel", "RequiredClasses", "RequiredRaces",
                       "PrevQuestId", "NextQuestId", "Title"),
    "creature_questrelation": ("id", "quest"),
    "gameobject_questrelation": ("id", "quest"),
    "creature_template": ("Entry", "Name"),
    "gameobject_template": ("entry", "name"),
}
# The quest fields read here, which an update must be understood to change.
READ = {"MinLevel", "QuestLevel", "RequiredClasses", "RequiredRaces", "PrevQuestId", "NextQuestId"}
ALLIANCE, HORDE = 1 | 4 | 8 | 64, 2 | 16 | 32 | 128   # race bits: 1 << (raceID - 1)
ALL_RACES = 255
SIDES = {"A": 1, "H": 2, "B": 3}


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def cached(name, url):
    path = CACHE / name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(fetch(url))
    return path


def raw(path):
    return f"https://raw.githubusercontent.com/{REPO}/{COMMIT}/{path}"


def update_files():
    """The update scripts at COMMIT, in the order the database applies them (by name)."""
    listing = CACHE / "updates.json"
    if not listing.exists():
        tree = json.loads(fetch(f"https://api.github.com/repos/{REPO}/git/trees/{COMMIT}?recursive=1"))
        names = sorted(e["path"] for e in tree["tree"] if e["path"].startswith("Updates/") and e["path"].endswith(".sql"))
        CACHE.mkdir(parents=True, exist_ok=True)
        listing.write_text(json.dumps(names, indent=1), encoding="utf-8")
    names = json.loads(listing.read_text(encoding="utf-8"))
    return [cached(name.replace("/", "_"), raw(name)) for name in names]


def values(s):
    """The rows of an INSERT's VALUES list, each a list of strings (None for NULL)."""
    rows, row, i, n = [], None, 0, len(s)
    while i < n:
        c = s[i]
        if row is None:
            if c == "(":
                row = []
            i += 1
        elif c == "'":
            j, buf = i + 1, []
            while s[j] != "'":
                if s[j] == "\\":
                    buf.append(s[j + 1])
                    j += 2
                else:
                    buf.append(s[j])
                    j += 1
            row.append("".join(buf))
            i = j + 1
        elif c == ")":
            rows.append(row)
            row = None
            i += 1
        elif c in ", \t\r\n":
            i += 1
        else:
            j = i
            while s[j] not in ",)":
                j += 1
            token = s[i:j].strip()
            row.append(None if token == "NULL" else token)
            i = j
    return rows


def read_dump(path):
    """{ table: [row dicts of its TABLES columns] } from the full dump."""
    columns, data, table = {}, {t: [] for t in TABLES}, None
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            create = re.match(r"CREATE TABLE `(\w+)`", line)
            if create:
                table = create.group(1) if create.group(1) in TABLES else None
                if table:
                    columns[table] = []
                continue
            if table and line.startswith("  `"):
                columns[table].append(re.match(r"\s+`(\w+)`", line).group(1).lower())
                continue
            if line.startswith(")"):
                table = None
            insert = re.match(r"INSERT INTO `(\w+)`(?: \([^)]*\))? VALUES ", line)
            if insert and insert.group(1) in TABLES:
                t = insert.group(1)
                at = {c: columns[t].index(c.lower()) for c in TABLES[t]}
                for row in values(line[insert.end():]):
                    data[t].append({c: row[k] for c, k in at.items()})
    return data


def statements(path):
    """The file's statements, split at the semicolons outside strings, with comments left out."""
    text = path.read_text(encoding="utf-8", errors="replace")
    buf, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "'":
            j = i + 1
            while j < n and text[j] != "'":
                j += 2 if text[j] == "\\" else 1
            buf.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("--", i) or c == "#":
            end = text.find("\n", i)
            i = n if end < 0 else end
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
        elif c == ";":
            s = " ".join("".join(buf).split())
            if s:
                yield s
            buf, i = [], i + 1
        else:
            buf.append(c)
            i += 1
    s = " ".join("".join(buf).split())
    if s:
        yield s


def unquote(token):
    return token.strip().strip("`").strip("'")


def where(clause):
    """A WHERE clause as (column, set of values), for `col = v` and `col IN (...)`; joined by AND."""
    if re.search(r"\b(OR|NOT|BETWEEN|LIKE)\b|[<>!]", re.sub(r"'(?:[^'\\]|\\.)*'", "''", clause), re.I):
        raise ValueError(f"unread WHERE: {clause}")
    tests = []
    for part in re.split(r"\s+AND\s+", clause, flags=re.I):
        m = re.fullmatch(r"`?(\w+)`?\s*(=|IN)\s*(.+)", part.strip(), re.I)
        if not m:
            raise ValueError(f"unread WHERE: {clause}")
        vals = m.group(3).strip()
        vals = vals[1:-1].split(",") if m.group(2).upper() == "IN" else [vals]
        tests.append((m.group(1).lower(), {unquote(v) for v in vals}))
    return tests


def matches(row, tests):
    lower = {k.lower(): v for k, v in row.items()}
    return all(lower.get(col) in vals for col, vals in tests)


def apply(data, s):
    """Applies one update statement to the tables read here; anything else is ignored."""
    quest = re.match(r"UPDATE `?quest_template`? SET (.+?) WHERE (.+)$", s, re.I)
    if quest:
        sets = {}
        for part in re.findall(r"`?(\w+)`?\s*=\s*('(?:[^'\\]|\\.)*'|[^,]+)", quest.group(1)):
            sets[part[0]] = unquote(part[1])
        read = {c for c in sets if c in READ}
        if not read:
            return
        tests = where(quest.group(2))
        for row in data["quest_template"]:
            if matches(row, tests):
                for c in read:
                    row[c] = sets[c]
        return
    if re.search(r"\bquest_template\b", s, re.I) and re.match(r"(INSERT|DELETE|REPLACE)\b", s, re.I):
        raise ValueError(f"unread update: {s[:160]}")
    rel = re.search(r"\b(creature|gameobject)_questrelation\b", s, re.I)
    if not rel:
        return
    table = f"{rel.group(1).lower()}_questrelation"
    if re.match(r"INSERT", s, re.I):
        listed = re.search(r"questrelation`?\s*\(([^)]*)\)\s*VALUES", s, re.I)
        cols = [unquote(c).lower() for c in listed.group(1).split(",")] if listed else ["id", "quest"]
        for row in values(s[s.upper().index("VALUES") + len("VALUES"):]):
            data[table].append({"id": row[cols.index("id")], "quest": row[cols.index("quest")]})
    elif re.match(r"DELETE", s, re.I):
        tests = where(re.search(r"WHERE (.+)$", s, re.I).group(1))
        data[table] = [r for r in data[table] if not matches(r, tests)]
    elif re.match(r"UPDATE", s, re.I):
        m = re.match(r"UPDATE `?\w+`? SET `?id`?\s*=\s*(\d+) WHERE (.+)$", s, re.I)
        if not m:
            raise ValueError(f"unread update: {s[:160]}")
        for r in data[table]:
            if matches(r, where(m.group(2))):
                r["id"] = m.group(1)
    else:
        raise ValueError(f"unread update: {s[:160]}")


LUA_STR = r'"((?:[^"\\]|\\.)*)"'
JOURNAL_ROW = re.compile(r"\{ (\d+), " + LUA_STR + r', (\d+), "(\w)", (?:true|false|"pre"), ' + LUA_STR
                         + r", (\d+), ([\d.]+), ([\d.]+)")
JOURNAL_CLASS = re.compile(r'class = "(\w+)"')
CLASS_IDS = {"WARRIOR": 1, "PALADIN": 2, "HUNTER": 3, "ROGUE": 4, "PRIEST": 5, "SHAMAN": 7, "MAGE": 8,
             "WARLOCK": 9, "DRUID": 11}
# What the Journal writes after a giver's name, about the quest rather than the giver.
GIVER_END = re.compile(r";|,| Prerequisite| Complete| Same| Starts| Breadcrumb")


def journal_giver(text):
    """The giver's name from the Journal's "where": after the place ("Ironforge, Old Ironforge -
    Thom Filch (32.6, 44.6)", "Undercity, Tabitha Heartweaver (34, 21)"), before any note."""
    where = text.split(" (")[0]
    name = where.rsplit(" - ", 1)[1] if " - " in where else where.rsplit(", ", 1)[-1]
    name = GIVER_END.split(name)[0].strip()
    return name if name and name != where else None


def journal_quests():
    """{ questID: { name, reqlevel, side, map, x, y, text, reqclass } } for the Journal's quests given
    outside the dungeon."""
    out = {}
    for line in JOURNAL.read_text(encoding="utf-8").splitlines():
        m = JOURNAL_ROW.search(line)
        if not m:
            continue
        cls = JOURNAL_CLASS.search(line[m.end():])
        out.setdefault(int(m.group(1)), {"name": m.group(2), "reqlevel": int(m.group(3)), "side": m.group(4),
                                         "text": m.group(5), "map": int(m.group(6)),
                                         "x": float(m.group(7)), "y": float(m.group(8)),
                                         "reqclass": 1 << (CLASS_IDS[cls.group(1)] - 1) if cls else 0})
    return out


def fold(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def wowsrc_levels():
    """{ folded name: level } of wowsrc's Forever dungeon and raid quests."""
    page = wowsrc.fetch(QUESTS_PAGE)
    out = {}
    for section in re.finditer(r'<section class="q__g" id="[^"]+" data-kind="(\w+)"(.*?)</section>', page, re.S):
        if section.group(1) not in ("dungeon", "raid"):
            continue
        for q in re.finditer(r"<summary[^>]*>\s*<b[^>]*>(.*?)</b>.*?q__lv[^>]*>(\d+)", section.group(2), re.S):
            out[fold(html.unescape(q.group(1)))] = int(q.group(2))
    return out


def side_of(races):
    """CMaNGOS's races mask as (side, race mask): a whole faction is its side alone."""
    races = 0 if races == ALL_RACES else races
    if races and races & ~ALLIANCE == 0:
        return 1, 0 if races == ALLIANCE else races
    if races and races & ~HORDE == 0:
        return 2, 0 if races == HORDE else races
    return 3, races


def main():
    data = read_dump(cached("dump.sql.gz", raw(DUMP)))
    for path in update_files():
        for s in statements(path):
            apply(data, s)
    quests = {int(q["entry"]): q for q in data["quest_template"]}
    names = {r["Entry"]: r["Name"] for r in data["creature_template"]}
    objects = {r["entry"]: r["name"] for r in data["gameobject_template"]}
    givers = {}
    for r in data["creature_questrelation"]:
        givers.setdefault(int(r["quest"]), []).append(names.get(r["id"]))
    for r in data["gameobject_questrelation"]:
        givers.setdefault(int(r["quest"]), []).append(objects.get(r["id"]))
    after = {}
    for qid, q in quests.items():
        if int(q["PrevQuestId"]) > 0:
            after.setdefault(qid, set()).add(int(q["PrevQuestId"]))
        if int(q["NextQuestId"]) > 0:
            after.setdefault(int(q["NextQuestId"]), set()).add(qid)
    levels = wowsrc_levels()

    out, forever, sides = {}, [], []
    for qid, j in sorted(journal_quests().items()):
        row = {"name": j["name"], "reqlevel": j["reqlevel"], "map": j["map"], "x": j["x"], "y": j["y"]}
        # The spot is the Journal's, so the giver is the one it names when CMaNGOS has several.
        named = [g for g in givers.get(qid, []) if g]
        giver = next((g for g in named if g in j["text"]), None) or next(iter(named), None) or journal_giver(j["text"])
        q = quests.get(qid)
        if q:
            side, races = side_of(int(q["RequiredRaces"]))
            if side != 3 and side != SIDES[j["side"]]:
                sides.append(f"{qid} {row['name']}: CMaNGOS side {side}, Journal {j['side']}")
            row.update(level=int(q["QuestLevel"]), side=side, reqrace=races,
                       reqclass=int(q["RequiredClasses"]) or j["reqclass"], after=sorted(after.get(qid, ())))
        else:
            forever.append(qid)
            row.update(level=levels.get(fold(row["name"]), j["reqlevel"]), side=SIDES[j["side"]], reqrace=0,
                       reqclass=j["reqclass"], after=[])
        row["giver"] = giver
        out[str(qid)] = row

    known = {fold(r["name"]) for r in out.values()}
    unplaced = sorted(n for n in levels if n not in known)
    OUT.write_text(json.dumps({"cmangos": COMMIT, "quests": out}, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(out)} quests, {len(forever)} new in Forever (not in CMaNGOS)")
    for line in sides:
        print("SIDE", line)
    print(f"{len(unplaced)} of wowsrc's dungeon quests are not in the Journal's list, so have no spot:")
    for n in unplaced:
        print("  ", n)


if __name__ == "__main__":
    main()
