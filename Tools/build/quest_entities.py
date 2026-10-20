"""Convert a permitted Forever entity JSON export into missing quest-map and prerequisite candidates.

Never fetches, executes imported code, or updates active caches. The source export must
declare Forever map coordinates; already-converted positions must not be converted again.
"""
import argparse
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import data_bundle  # noqa: E402
from quest_chains import ZONE_MAP  # noqa: E402
from journeys_quests import quest_spots, entrance_spots, turn_in_choices, CAMP  # noqa: E402

MAX_DROP_SOURCES = 3
NEW_ZONES = {
    616: ("Mount Hyjal", 1), 16591: ("Riverglades", 0), 16593: ("Zephras Isle", -2),
    16606: ("Darkspear Islands", 1), 16651: ("Shen'dralas", 1),
}


def sequence(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    data_bundle.mapping(value)
    return [value[k] for k in sorted(value, key=int)]


def slot(value, index, default=None):
    if isinstance(value, list):
        return value[index - 1] if len(value) >= index else default
    if isinstance(value, dict):
        return value.get(str(index), default)
    return default


def ids(value):
    result = sequence(value)
    data_bundle.check(all(data_bundle.integer(v) for v in result), "expected positive entity IDs")
    return sorted(set(result))


def validate(document):
    data_bundle.check(isinstance(document, dict) and type(document.get("version")) is int and document["version"] == 1 and
                      document.get("edition") == "forever" and document.get("coordinate_space") == "forever",
                      "expected version 1 Forever entities in Forever map coordinates")
    data_bundle.check(isinstance(document.get("source"), str) and bool(document["source"].strip()), "source is required")
    data_bundle.check(isinstance(document.get("build"), str) and bool(document["build"].strip()), "build is required")
    entities = document.get("entities")
    data_bundle.check(isinstance(entities, dict) and set(entities) == {"quests", "npcs", "objects", "items"},
                      "entities must contain quests, npcs, objects and items")
    for records in entities.values():
        data_bundle.mapping(records)
        data_bundle.check(all(isinstance(r, dict) for r in records.values()), "entity records must be objects")
    return entities


def points(entities, kind, entity_id, point, notes):
    record = entities[kind].get(str(entity_id))
    if record is None:
        notes.add("missing_entity")
        return []
    result = []
    for area, positions in (record.get("spawns") or {}).items():
        if not data_bundle.identifier(area) or int(area) not in ZONE_MAP:
            notes.add("unsupported_map")
            continue
        coords = []
        for position in sequence(positions):
            pair = [slot(position, 1), slot(position, 2)]
            phase = slot(position, 3)
            if phase not in (None, 0):
                notes.add("conditional_spawn")
                continue
            if any(type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 100 for v in pair):
                notes.add("invalid_or_instance_coordinate")
                continue
            if pair not in coords:
                coords.append(pair)
        if coords:
            result.append({"point": point, "zone": int(area), "id": entity_id,
                           "name": record.get("name"), "coords": sorted(coords), "coordinate_space": "forever"})
    return result


def clustered_turn_in(positions):
    """Use a recorded location only when every alternative is in one compact camp."""
    if not positions or len({p["zone"] for p in positions}) != 1:
        return []
    coords = [c for p in positions for c in p["coords"]]
    if any(max(abs(a[0] - b[0]), abs(a[1] - b[1])) > CAMP for a in coords for b in coords):
        return []
    center = [sum(c[i] for c in coords) / len(coords) for i in (0, 1)]
    chosen = min(coords, key=lambda c: sum((c[i] - center[i]) ** 2 for i in (0, 1)))
    original = next(p for p in positions if chosen in p["coords"])
    return [{**original, "coords": [chosen]}]


def explicit_positions(spawns, name, notes):
    entities = {"objects": {"1": {"name": name, "spawns": spawns}}}
    result = points(entities, "objects", 1, "requirement", notes)
    for point in result:
        point.pop("id")
    return result


def dungeon_entrances(folder):
    """Reuse the Journal's reviewed outdoor entrances, never an interior coordinate."""
    result = {}
    areas = {ui: area for area, ui in ZONE_MAP.items()}
    for dungeon in data_bundle.read(folder / "journal_bosses.json").get("dungeons", []):
        area, door = dungeon.get("zone"), dungeon.get("entrance")
        if area and door and door["map"] in areas:
            candidate = {"point": "entrance", "zone": areas[door["map"]], "id": area,
                         "name": dungeon["name"], "coords": [[door["x"], door["y"]]],
                         "coordinate_space": "forever"}
            data_bundle.validate("quest_spots", {"1": [candidate]})
            data_bundle.check(area not in result or all(result[area][k] == candidate[k] for k in ("zone", "coords")),
                              "conflicting dungeon entrances")
            result[area] = candidate
    return result


def routable(positions):
    turn_in, objectives = quest_spots(positions)
    return bool(turn_in or objectives or entrance_spots(positions) or turn_in_choices(positions))


def map_points(quest, entities, notes, entrances=None):
    result = []
    finishers = quest.get("finishedBy") or {}
    ends = [(kind, entity_id) for index, kind in ((1, "npcs"), (2, "objects"))
            for entity_id in ids(slot(finishers, index))]
    end_notes = set()
    end_points = [p for kind, entity_id in ends for p in points(entities, kind, entity_id, "end", end_notes)]
    notes.update(end_notes)
    turn_in = clustered_turn_in(end_points)
    # A missing actor could be an alternative elsewhere; do not hide that uncertainty.
    if turn_in and not end_notes and all(entities[kind].get(str(i), {}).get("spawns") for kind, i in ends):
        result.extend(turn_in)
    elif ends:
        notes.add("ambiguous_turn_in")
    objectives = quest.get("objectives") or {}
    for index, kind in ((1, "npcs"), (2, "objects")):
        for objective in sequence(slot(objectives, index)):
            entity_id = slot(objective, 1)
            data_bundle.check(data_bundle.integer(entity_id), "invalid quest objective ID")
            result.extend(points(entities, kind, entity_id, "requirement", notes))
    for objective in sequence(slot(objectives, 3)):
        item_id = slot(objective, 1)
        data_bundle.check(data_bundle.integer(item_id), "invalid quest item objective ID")
        item = entities["items"].get(str(item_id))
        if item is None:
            notes.add("missing_item")
            continue
        drops = [(kind, entity_id) for field, kind in (("npcDrops", "npcs"), ("objectDrops", "objects"))
                 for entity_id in ids(item.get(field))]
        if len(drops) > MAX_DROP_SOURCES:
            # Quest items in the quest's explicit outdoor zone are useful even when several
            # NPC templates share the drop. Commodity/world drops still need manual review.
            area = quest.get("zoneOrSort")
            if item.get("class") == 12 and area in ZONE_MAP:
                local = [p for kind, i in drops for p in points(entities, kind, i, "sourcerequirement", set())
                         if p["zone"] == area]
                if local:
                    result.extend({**p, "quest_item": item_id} for p in local)
                    notes.add("quest_item_sources_in_quest_zone")
                    continue
            notes.add("too_many_item_sources")
            continue
        for kind, entity_id in drops:
            result.extend(points(entities, kind, entity_id, "sourcerequirement", notes))
    trigger = quest.get("triggerEnd")
    if trigger:
        result.extend(explicit_positions(slot(trigger, 2), slot(trigger, 1), notes))
    for objective in sequence(quest.get("extraObjectives")):
        if slot(objective, 1):
            result.extend(explicit_positions(slot(objective, 1), slot(objective, 3), notes))
        for reference in sequence(slot(objective, 5)):
            kind = {"monster": "npcs", "object": "objects"}.get(slot(reference, 1))
            if kind:
                entity_id = slot(reference, 2)
                data_bundle.check(data_bundle.integer(entity_id), "invalid additional objective ID")
                result.extend(points(entities, kind, entity_id, "requirement", notes))
    if any(slot(objectives, index) for index in (4, 5, 6)):
        notes.add("additional_objective_types_not_projected")
    if entrances:
        area = quest.get("zoneOrSort")
        if area in entrances:
            result.append(entrances[area])
            notes.add("dungeon_entrance_only")
    unique = {json.dumps(p, sort_keys=True): p for p in result}
    return [unique[k] for k in sorted(unique)]


def prerequisite(quest, quest_id=None):
    raw = sequence(quest.get("preQuestGroup")) + sequence(quest.get("preQuestSingle"))
    data_bundle.check(all(type(i) is int and i != 0 for i in raw), "invalid prerequisite IDs")
    if any(i < 0 for i in raw) or quest_id is not None and quest_id in raw:
        return None
    grouped, alternatives = ids(quest.get("preQuestGroup")), ids(quest.get("preQuestSingle"))
    groups = grouped + ([alternatives] if len(alternatives) > 1 else alternatives)
    return {"quests": sorted(set(grouped + alternatives)), "groups": groups} if groups else None


def catalog_records(entities, zones):
    """Keep every source record, with conservative zone placement and starter coordinates."""
    result = {}
    for key, quest in entities["quests"].items():
        data_bundle.check(isinstance(quest.get("name"), str), "catalog quest needs a name")
        starts = quest.get("startedBy") or {}
        actors = [(kind, entity_id) for index, kind in ((1, "npcs"), (2, "objects"))
                  for entity_id in ids(slot(starts, index))]
        positions = [p for kind, entity_id in actors for p in points(entities, kind, entity_id, "end", set())]
        areas = {p["zone"] for p in positions}
        category = quest.get("zoneOrSort", 0)
        area = category if category in ZONE_MAP else next(iter(areas)) if len(areas) == 1 else 0
        zone = zones.get(str(area), {})
        name, continent = NEW_ZONES.get(area, (zone.get("name", "Unsorted Quests"), None))
        if continent is None:
            continents = [q.get("category2", 0) for q in zone.get("quests", [])]
            continent = max(set(continents), key=continents.count) if continents else -2
        start = None
        if len(actors) == 1 and len(positions) == 1 and len(positions[0]["coords"]) == 1:
            p = positions[0]
            start = {"zone": p["zone"], "coord": p["coords"][0], "npc": p.get("name"),
                     "npcId": p["id"], "coordinate_space": "forever"}
        races = quest.get("requiredRaces", 0)
        data_bundle.check(type(races) is int and races >= 0, "invalid race mask")
        side = 3
        if races:
            alliance, horde = 4294967373, 8589934770
            if races & alliance and not races & horde:
                side = 1
            elif races & horde and not races & alliance:
                side = 2
        result[key] = {"name": quest["name"], "level": quest.get("questLevel", 0),
                       "reqlevel": quest.get("requiredLevel", 0), "reqrace": races,
                       "reqclass": quest.get("requiredClasses", 0), "side": side,
                       "zone": area, "zone_name": name, "category2": continent, "start": start,
                       "repeatable": bool(quest.get("specialFlags", 0) & 1), "source_fields": quest}
    data_bundle.validate("quest_catalog", result)
    return result


def convert(document, folder, full_catalog=False, fill_unroutable=False):
    entities = validate(document)
    quests = data_bundle.read(folder / "completo_quests.json")
    maps = data_bundle.read(folder / "journeys_quest_spots.json")
    entrances = dungeon_entrances(folder)
    requires = data_bundle.read(folder / "completo_requires.json")
    existing_zone_ids = {q["id"] for z in data_bundle.read(folder / "completo_zones.json").values() for q in z["quests"]}
    for name in ("completo_dungeon.json", "completo_elsewhere.json"):
        for key, quest in data_bundle.read(folder / name).get("quests", {}).items():
            if int(key) not in existing_zone_ids and quest.get("after") and not requires.get(key):
                requires[key] = {"quests": quest["after"]}
    wanted = set(quests)
    for zone in data_bundle.read(folder / "completo_zones.json").values():
        wanted.update(str(q["id"]) for q in zone["quests"])
    wanted.update(data_bundle.read(folder / "quest_entity_catalog.json"))
    catalog = catalog_records(entities, data_bundle.read(folder / "completo_zones.json")) if full_catalog else None
    if catalog is not None:
        wanted.update(catalog)
    report = {"source": document["source"], "build": document["build"], "wanted": len(wanted),
              "source_quests": len(entities["quests"]), "present": 0, "map_candidates": [],
              "prerequisite_candidates": [], "map_records_missing_from_source": [], "notes": {},
              "unroutable_records_replaced": [],
              "prerequisite_conflicts": [], "signed_prerequisites_withheld": [],
              "self_referential_prerequisites_withheld": [], "limitations": [
                  "Static source data is not proof of in-game availability or freshness.",
                  "Usable existing map records and all existing prerequisite records are preserved.",
                  "Phased spawns, separated turn-ins and unsupported maps are withheld.",
                  "Dungeon entrances are guidance only, never exact interior objective locations.",
                  "Missing prerequisites do not establish no prerequisites; chains are not inferred from text."]}
    map_candidates, requirement_candidates = {}, {}
    for key in sorted(wanted, key=int):
        quest = entities["quests"].get(key)
        if quest is None:
            if not maps.get(key):
                report["map_records_missing_from_source"].append(int(key))
            continue
        report["present"] += 1
        existing = maps.get(key)
        if not existing or fill_unroutable and not routable(existing):
            notes = set()
            candidate = map_points(quest, entities, notes, entrances)
            if candidate and routable(candidate):
                map_candidates[key] = candidate
                report["map_candidates"].append(int(key))
                if existing:
                    report["unroutable_records_replaced"].append(int(key))
            if notes:
                report["notes"][key] = sorted(notes)
        candidate = prerequisite(quest, int(key))
        if int(key) in sequence(quest.get("preQuestGroup")) + sequence(quest.get("preQuestSingle")):
            report["self_referential_prerequisites_withheld"].append(int(key))
        if any(i < 0 for i in sequence(quest.get("preQuestGroup")) + sequence(quest.get("preQuestSingle"))):
            report["signed_prerequisites_withheld"].append(int(key))
        if candidate:
            if key not in requires:
                requirement_candidates[key] = candidate
                report["prerequisite_candidates"].append(int(key))
            elif (requires[key] or {}).get("quests") != candidate["quests"]:
                report["prerequisite_conflicts"].append(int(key))
    bundle = {"version": 1, "edition": "forever", "source": f"{document['source']} (build {document['build']})",
              "data": {"quest_spots": map_candidates, "prerequisites": requirement_candidates}}
    if catalog is not None:
        bundle["data"]["quest_catalog"] = catalog
        report["catalog_records"] = len(catalog)
        report["unassigned_quest_ids"] = sorted(int(k) for k, v in catalog.items() if v["zone"] == 0)
    data_bundle.prepare(bundle, folder)
    return bundle, report


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--input", type=Path, required=True, help="permitted, named-field entity JSON export")
    parser.add_argument("--bundle", type=Path, required=True, help="candidate bundle; does not change active caches")
    parser.add_argument("--report", type=Path, required=True, help="coverage and withheld-data JSON")
    parser.add_argument("--full-catalog", action="store_true", help="include every source quest, preserving existing catalog entries")
    parser.add_argument("--fill-unroutable", action="store_true", help="replace unusable map records with routable candidates; apply with --replace")
    args = parser.parse_args()
    try:
        outputs = [args.bundle.resolve(), args.report.resolve()]
        data_bundle.check(len(set(outputs)) == 2 and args.input.resolve() not in outputs and
                          all(not p.is_relative_to(paths.DATA.resolve()) for p in outputs),
                          "outputs must be separate files outside the active data directory and input")
        bundle, report = convert(data_bundle.read(args.input), paths.DATA, args.full_catalog, args.fill_unroutable)
        for path, value in ((args.bundle, bundle), (args.report, report)):
            data_bundle.atomic_write(path, (json.dumps(value, indent=1, sort_keys=True) + "\n").encode())
        print(f"{report['present']}/{report['wanted']} quest IDs present in source; "
              f"{len(report['map_candidates'])} map candidates; "
              f"{len(report['prerequisite_candidates'])} prerequisite candidates")
    except (ValueError, OSError, TypeError, RecursionError) as error:
        parser.exit(1, f"Quest entities: {error}\n")


if __name__ == "__main__":
    main()
