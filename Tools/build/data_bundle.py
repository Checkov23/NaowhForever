"""Import approved Forever data exports and report missing Scout and quest records, without HTTP.

The versioned JSON bundle uses the existing cache shapes. Import validates the whole bundle
before writing, merges by ID, and keeps existing records unless --replace is supplied.
"""
import argparse
import copy
import json
import math
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
from quest_chains import ZONE_MAP  # noqa: E402

FILES = {
    "scout": "scout.json",
    "quest_zones": "completo_zones.json",
    "quests": "completo_quests.json",
    "prerequisites": "completo_requires.json",
    "quest_spots": "journeys_quest_spots.json",
    "quest_catalog": "quest_entity_catalog.json",
}
MAX_BYTES = 64 * 1024 * 1024


def check(ok, message):
    if not ok:
        raise ValueError(message)


def integer(value, minimum=1):
    return type(value) is int and value >= minimum


def identifier(value):
    return isinstance(value, str) and value.isascii() and value.isdecimal() and str(int(value)) == value and int(value) > 0


def mapping(value):
    check(isinstance(value, dict) and all(identifier(k) for k in value), "expected an object keyed by positive IDs")


def coords(value):
    check(isinstance(value, list) and len(value) == 2 and
          all(type(v) in (int, float) and math.isfinite(v) and 0 <= v <= 100 for v in value),
          "coordinates must be [x, y] percentages between 0 and 100")


def named(row):
    check(isinstance(row, dict) and integer(row.get("id")) and isinstance(row.get("name"), str),
          "expected an id and name")


def validate(section, data):
    mapping(data)
    for value in data.values():
        if section == "scout_zones":
            check(isinstance(value, list), "Scout zone must contain a list of NPCs")
            for row in value:
                named(row)
        elif section == "scout_npcs":
            check(isinstance(value, dict) and type(value.get("tameable")) is bool and
                  isinstance(value.get("abilities"), list), "NPC needs abilities and tameable")
            for ability in value["abilities"]:
                check(isinstance(ability, list) and len(ability) == 2 and integer(ability[0]) and
                      isinstance(ability[1], str), "ability must be [spell ID, name]")
        elif section == "quest_zones":
            check(isinstance(value, dict) and isinstance(value.get("name"), str) and
                  isinstance(value.get("quests"), list), "quest zone needs name and quests")
            for row in value["quests"]:
                named(row)
                for field in ("level", "reqlevel", "side", "reqrace", "reqclass", "category2"):
                    check(field not in row or integer(row[field], -2 if field == "category2" else -1 if field == "level" else 0),
                          f"invalid quest {field}")
        elif section == "quests":
            check(isinstance(value, dict) and "chain" in value and "start" in value,
                  "quest needs chain and start (null when known absent)")
            chain, start = value["chain"], value["start"]
            if chain is not None:
                check(isinstance(chain, dict) and isinstance(chain.get("chain"), list) and
                      isinstance(chain.get("names"), dict), "invalid quest chain")
                mapping(chain["names"])
                check(all(isinstance(n, str) for n in chain["names"].values()), "invalid chain names")
                for step in chain["chain"]:
                    check(isinstance(step, list) and bool(step) and all(integer(i) for i in step),
                          "chain step must contain quest IDs")
            if start is not None:
                check(isinstance(start, dict) and integer(start.get("zone")), "invalid quest start zone")
                if start.get("coord") is not None:
                    coords(start["coord"])
                check(start.get("npc") is None or isinstance(start["npc"], str), "invalid quest giver")
        elif section == "quest_catalog":
            check(isinstance(value, dict) and isinstance(value.get("name"), str) and
                  integer(value.get("zone"), 0) and value["zone"] in {0, *ZONE_MAP} and
                  isinstance(value.get("zone_name"), str), "invalid catalog quest or zone")
            for field in ("level", "reqlevel", "reqrace", "reqclass", "side", "category2"):
                check(integer(value.get(field), -2 if field == "category2" else -1 if field == "level" else 0),
                      f"invalid catalog {field}")
            check(type(value.get("repeatable")) is bool, "invalid repeatable flag")
            if value.get("start") is not None:
                validate("quests", {"1": {"chain": None, "start": value["start"]}})
        elif section == "prerequisites":
            check(value is None or isinstance(value, dict) and isinstance(value.get("quests"), list) and
                  all(integer(i) for i in value["quests"]), "invalid prerequisites")
            if value is not None and "groups" in value:
                groups = value["groups"]
                check(isinstance(groups, list), "prerequisite groups must be a list")
                flat = []
                for group in groups:
                    check(integer(group) or isinstance(group, list) and bool(group) and
                          all(integer(i) for i in group), "invalid prerequisite group")
                    flat.extend(group if isinstance(group, list) else [group])
                check(set(flat) == set(value["quests"]), "prerequisite groups disagree with quest IDs")
        elif section == "quest_spots":
            check(isinstance(value, list), "quest spots must be a list")
            for point in value:
                check(isinstance(point, dict) and point.get("point") in
                      ("end", "end_choice", "requirement", "sourcerequirement", "entrance") and integer(point.get("zone")) and
                      isinstance(point.get("coords"), list) and bool(point["coords"]), "invalid quest point")
                for pair in point["coords"]:
                    coords(pair)
                check(point.get("point") != "end_choice" or point.get("side") in ("A", "H", "AH") and
                      point.get("coordinate_space") == "forever",
                      "alternative turn-in requires an explicit faction")
                check("quest_item" not in point or point["point"] == "sourcerequirement" and
                      integer(point["quest_item"]) and point.get("coordinate_space") == "forever",
                      "quest item source must identify an item in Forever coordinates")


def read(path, default=None):
    if not path.exists():
        return copy.deepcopy(default if default is not None else {})
    check(path.stat().st_size <= MAX_BYTES, f"file exceeds {MAX_BYTES} bytes: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def prepare(bundle, folder, replace=False):
    check(isinstance(bundle, dict) and type(bundle.get("version")) is int and bundle["version"] == 1,
          "expected bundle version 1")
    check(bundle.get("edition") == "forever", "bundle must target Forever")
    check(isinstance(bundle.get("source"), str) and bool(bundle["source"].strip()), "source is required")
    check(isinstance(bundle.get("data"), dict) and bool(bundle["data"]), "data is required")
    check(not (set(bundle["data"]) - FILES.keys()), "unknown data section")
    result = {}
    for section, incoming in bundle["data"].items():
        current = read(folder / FILES[section], {"zones": {}, "npcs": {}} if section == "scout" else {})
        if section == "scout":
            check(isinstance(incoming, dict) and not (incoming.keys() - {"zones", "npcs"}), "invalid Scout sections")
            for key, values in incoming.items():
                validate("scout_" + key, values)
                current.setdefault(key, {})
                current[key] = {**current[key], **values} if replace else {**values, **current[key]}
        else:
            validate(section, incoming)
            if section == "quest_zones":
                check(all(int(k) in ZONE_MAP for k in incoming), "quest zone has no supported Forever map")
            current = {**current, **incoming} if replace else {**incoming, **current}
        result[folder / FILES[section]] = current
    return result


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            name = Path(stream.name)
            stream.write(content)
        os.replace(name, path)
    finally:
        if name is not None:
            name.unlink(missing_ok=True)


def apply(changes):
    previous = {p: p.read_bytes() if p.exists() else None for p in changes}
    written = []
    try:
        for path, data in changes.items():
            content = (json.dumps(data, ensure_ascii=True, sort_keys=True, indent=1) + "\n").encode("utf-8")
            if previous[path] and b"\r\n" in previous[path]:
                content = content.replace(b"\n", b"\r\n")
            atomic_write(path, content)
            written.append(path)
    except OSError:
        for path in reversed(written):
            if previous[path] is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path, previous[path])
        raise


def report(folder):
    scout = read(folder / FILES["scout"], {"zones": {}, "npcs": {}})
    zones = read(folder / FILES["quest_zones"])
    quests = read(folder / FILES["quests"])
    catalog = read(folder / FILES["quest_catalog"])
    requires = read(folder / FILES["prerequisites"])
    spots = read(folder / FILES["quest_spots"])
    dungeons = read(folder / "journal_bosses.json").get("dungeons", [])
    areas = set(ZONE_MAP) | {d["zone"] for d in dungeons if d.get("zone")}
    npcs = {r["id"] for rows in scout["zones"].values() for r in rows}
    npcs |= {int(n) for d in dungeons for n in (d.get("npcs") or {}).values()}
    wanted = {q["id"] for z in zones.values() for q in z["quests"]}
    wanted |= {int(q) for q in quests}
    wanted |= {int(q) for q in catalog}
    catalog_zones = {r["zone"] for r in catalog.values() if r["zone"]}
    return {
        "scope": "Cache coverage only. Page-cache gaps may be covered by the entity catalog. Missing NPC pages may have Classic spells. No freshness or completeness guarantee.",
        "entity_catalog_records": len(catalog),
        "scout_zones_missing": sorted(a for a in areas if str(a) not in scout["zones"]),
        "scout_npc_pages_missing": sorted(n for n in npcs if str(n) not in scout["npcs"]),
        "quest_zones_missing": sorted(a for a in ZONE_MAP if str(a) not in zones and a not in catalog_zones),
        "quest_zone_pages_missing": sorted(a for a in ZONE_MAP if str(a) not in zones),
        "quest_pages_missing": sorted(q for q in wanted if str(q) not in quests),
        "quest_metadata_missing": sorted(q for q in wanted if str(q) not in quests and str(q) not in catalog),
        "classic_prerequisite_pages_missing": sorted(q for q in wanted if q < 10000 and str(q) not in requires),
        "quest_map_pages_missing": sorted(q for q in wanted if str(q) not in spots),
        "quest_maps_known_empty": sorted(q for q in wanted if str(q) in spots and not spots[str(q)]),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--import-file", type=Path, help="approved version 1 JSON bundle")
    parser.add_argument("--replace", action="store_true", help="allow incoming records to replace existing IDs")
    parser.add_argument("--apply", action="store_true", help="write imported records; otherwise preview only")
    parser.add_argument("--export-file", type=Path, help="write current caches as a bundle (local snapshot, not fresh data)")
    parser.add_argument("--report", type=Path, help="write missing-record IDs as JSON")
    args = parser.parse_args()
    try:
        targets = {p.resolve() for p in (args.report, args.export_file) if p is not None}
        protected = {paths.DATA.resolve() / name for name in FILES.values()}
        if args.import_file:
            protected.add(args.import_file.resolve())
        check(not (targets & protected), "report/export must not overwrite an input or cache file")
        check(not (args.report and args.export_file and args.report.resolve() == args.export_file.resolve()),
              "report and export need different paths")
        if args.import_file:
            changes = prepare(read(args.import_file), paths.DATA, args.replace)
            for path, data in changes.items():
                print(f"{path.name}: {len(data)} top-level entries after merge")
            if args.apply:
                apply(changes)
            else:
                print("Preview only. Add --apply to write caches.")
        elif args.apply or args.replace:
            parser.error("--apply and --replace need --import-file")
        if args.export_file:
            data = {k: read(paths.DATA / v) for k, v in FILES.items()}
            for quest in data["quests"].values():
                start = quest and quest.get("start")
                if start and start.get("coord") == [""]:
                    start["coord"] = None
            bundle = {"version": 1, "edition": "forever", "source": "local cache snapshot", "data": data}
            atomic_write(args.export_file, (json.dumps(bundle, ensure_ascii=True, indent=1) + "\n").encode())
        coverage = report(paths.DATA)
        if args.report:
            atomic_write(args.report, (json.dumps(coverage, indent=1) + "\n").encode())
        for key, value in coverage.items():
            print(f"{key}: {len(value) if isinstance(value, list) else value}")
    except (ValueError, OSError, RecursionError) as error:
        parser.exit(1, f"Data bundle: {error}\n")


if __name__ == "__main__":
    main()
