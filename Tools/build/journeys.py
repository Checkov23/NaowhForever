"""Build the Journeys planner's travel network from the game's own tables (Tools/sources/wago.py).

Flight points come from TaxiNodes: where the flight master stands, its continent and who can
use it (Flags bit 1 Alliance, bit 2 Horde; a node with neither is a quest flight). Each direct
flight is a TaxiPath between two of them, flown along its TaxiPathNode points, so its length is
the sum of the legs between them. Boats and zeppelins are the taxi paths Tools/build/travel.py
lists by hand (ROUTES): each dock is a node of the path with a delay.

Positions stay in world yards (x north, y west, as the game gives them); the addon turns them
into map positions with C_Map when it needs to.

Writes NaowhForever_Journeys/Data/Network.lua.

Usage: python Tools/build/journeys.py [--build 1.60.1.70338]
"""
import argparse
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
from journal import ROOT, header, write  # noqa: E402
from travel import ROUTES, stops  # noqa: E402
from wowhead import lua_string  # noqa: E402

OUT = ROOT / "NaowhForever_Journeys" / "Data" / "Network.lua"
TOWNS = ROOT / "Shared" / "Game" / "Towns.lua"
NPC_REACH = 200   # yards: a flight master this close to a flight point, on its side, is the one you talk to
CONTINENTS = (0, 1, 2991)
ALLIANCE, HORDE = 1, 2
DEAD = ("zzOLD", "Quest Path", "[DNT]", "DEPRECATED")
# Fixed links between two spots, both ways: (kind, factions, place, AreaTrigger, place,
# AreaTrigger, seconds through it). A portal's other end is where the portal back stands; the
# tram's seconds are the ride with its wait, timed in game.
LINKS = [
    ("Portal", "AH", "Rut'theran Village", 542, "Darnassus", 527, 5),
    ("Tram", "AH", "Ironforge", 2175, "Stormwind", 2173, 150),
]
TELEPORT = 1   # TaxiPathNode flag: the next step is a jump, not sailed
SAME_DOCK = 10   # yards: a path that starts and ends at one dock lists it twice, this far apart


def factions(flags):
    flags = int(flags)
    return ("A" if flags & ALLIANCE else "") + ("H" if flags & HORDE else "")


def flight_points(build):
    points = {}
    for row in wago.table("TaxiNodes", build):
        side = factions(row["Flags"])
        name = row["Name_lang"]
        if not side or int(row["ContinentID"]) not in CONTINENTS or any(d in name for d in DEAD):
            continue
        points[int(row["ID"])] = {
            "name": name, "continent": int(row["ContinentID"]), "side": side,
            "x": float(row["Pos_0"]), "y": float(row["Pos_1"]), "z": float(row["Pos_2"]),
        }
    return points


def map_bounds(build):
    """Each world map's continent and bounds in world yards (min x, min y, max x, max y)."""
    bounds = {}
    for row in wago.table("UiMapAssignment", build):
        if row["OrderIndex"] == "0":
            bounds[int(row["UiMapID"])] = (int(row["MapID"]), tuple(float(row[f"Region_{i}"]) for i in (0, 1, 3, 4)))
    return bounds


def flight_masters(build):
    """The flight masters of Shared/Game/Towns.lua in world yards: [(continent, x, y, factions)]."""
    bounds = map_bounds(build)
    masters, ui_map = [], None
    for line in TOWNS.read_text(encoding="ascii").splitlines():
        head = re.match(r"\s*\[(\d+)\] = \{", line)
        if head:
            ui_map = int(head.group(1))
        npc = re.match(r'\s*\{ ([\d.]+), ([\d.]+), "flight", .*"(A|H|AH)"', line)
        if npc and ui_map in bounds:
            continent, (min_x, min_y, max_x, max_y) = bounds[ui_map]
            left, top = float(npc.group(1)), float(npc.group(2))
            masters.append((continent, max_x - top / 100 * (max_x - min_x), max_y - left / 100 * (max_y - min_y), npc.group(3)))
    return masters


def stand_at_masters(points, masters):
    """Moves each flight point onto its flight master, where there is one: the table's position is where
    the flight starts, a few yards off. The table's height is kept: it is the master's floor, on a
    tower or on the ground, and tells the two apart."""
    moved = 0
    for p in points.values():
        near = [(math.dist((p["x"], p["y"]), (x, y)), x, y) for c, x, y, side in masters
                if c == p["continent"] and set(p["side"]) & set(side)]
        near = [n for n in near if n[0] <= NPC_REACH]
        if near:
            _, p["x"], p["y"] = min(near)
            moved += 1
    return moved


def path_lengths(nodes):
    by_path = {}
    for node in nodes:
        by_path.setdefault(int(node["PathID"]), []).append(node)
    lengths = {}
    for path, points in by_path.items():
        points.sort(key=lambda n: int(n["NodeIndex"]))
        total = 0.0
        for a, b in zip(points, points[1:]):
            if a["ContinentID"] != b["ContinentID"]:
                total = None
                break
            total += math.dist([float(a[f"Loc_{i}"]) for i in range(3)], [float(b[f"Loc_{i}"]) for i in range(3)])
        if total:
            lengths[path] = total
    return lengths


def sailings(nodes, path):
    """Each dock of a ship's path in order, with the seconds it waits there and the yards it
    sails to the next dock (back to the first after the last). A path that crosses to another
    continent, or skips ahead on its own (a zeppelin out of sight), jumps: the step after a
    node flagged TELEPORT, one that changes continent, and the step from the path's last node
    back to its first add nothing."""
    points = sorted((n for n in nodes if n["PathID"] == str(path)), key=lambda n: int(n["NodeIndex"]))
    docks = [i for i, n in enumerate(points) if int(n["Delay"]) > 0]
    first, last = points[docks[0]], points[docks[-1]]
    if len(docks) > 1 and first["ContinentID"] == last["ContinentID"] and math.dist(
            (float(first["Loc_0"]), float(first["Loc_1"])), (float(last["Loc_0"]), float(last["Loc_1"]))) < SAME_DOCK:
        docks.pop()
    stretches = []
    for k, start in enumerate(docks):
        end = docks[(k + 1) % len(docks)]
        span = points[start:end + 1] if end > start else points[start:] + points[:end + 1]
        yards = 0.0
        for a, b in zip(span, span[1:]):
            if b is points[0] and a is points[-1]:
                continue
            if a["ContinentID"] == b["ContinentID"] and not int(a["Flags"]) & TELEPORT:
                yards += math.dist([float(a[f"Loc_{i}"]) for i in range(3)], [float(b[f"Loc_{i}"]) for i in range(3)])
        stretches.append((int(points[start]["Delay"]), round(yards)))
    return stretches


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", default=wago.BUILD)
    build = parser.parse_args().build

    points = flight_points(build)
    moved = stand_at_masters(points, flight_masters(build))
    nodes = wago.table("TaxiPathNode", build)
    lengths = path_lengths(nodes)
    hops = []
    for row in wago.table("TaxiPath", build):
        a, b, path = int(row["FromTaxiNode"]), int(row["ToTaxiNode"]), int(row["ID"])
        if a in points and b in points and path in lengths and points[a]["continent"] == points[b]["continent"]:
            hops.append((a, b, round(lengths[path])))
    used = {n for hop in hops for n in hop[:2]}

    # flights[nodeID] = { name, continent, x, y, z, factions }: a flight master the network uses, where it
    # stands when Towns.lua has it, else where the flight starts.
    # hops = { { from, to, yards flown }, ... }: every direct flight.
    # ships = { { kind, factions, { continent, x, y, uiMapID, place, seconds it waits, yards to
    # the next dock }, ... }, ... }: a boat or zeppelin and its docks in the order it sails
    # them, back to the first after the last.
    lines = header(OUT.name, "the Journeys planner's flights, boats and zeppelins, generated by Tools/build/journeys.py")
    lines.append("ns.JourneyNetwork = {")
    lines.append("    flights = {")
    for node in sorted(used):
        p = points[node]
        lines.append(f"        [{node}] = {{ {lua_string(p['name'])}, {p['continent']}, {p['x']:.1f}, {p['y']:.1f}, "
                     f"{p['z']:.1f}, \"{p['side']}\" }},")
    lines.append("    },")
    lines.append("    hops = {")
    for a, b, yards in sorted(hops):
        lines.append(f"        {{ {a}, {b}, {yards} }},")
    lines.append("    },")
    lines.append("    ships = {")
    for path, kind, side, *listed in ROUTES:
        docks, legs = stops(nodes, path), sailings(nodes, path)
        if not len(docks) == len(legs) == len(listed):
            sys.exit(f"taxi path {path} has {len(docks)} docks and {len(legs)} sailings, not {len(listed)}")
        fields = [f'"{kind}"', f'"{side}"']
        for (continent, x, y), (place, _, map_id), (wait, yards) in zip(docks, listed, legs):
            fields.append(f"{{ {continent}, {x:.1f}, {y:.1f}, {map_id}, {lua_string(place)}, {wait}, {yards} }}")
        lines.append("        { " + ", ".join(fields) + " },")
    lines.append("    },")
    triggers = {int(row["ID"]): row for row in wago.table("AreaTrigger", build)}
    # links = { { kind, factions, seconds, { continent, x, y, place }, { continent, x, y, place } }, ... }
    lines.append("    links = {")
    for kind, side, here, here_id, there, there_id, seconds in LINKS:
        ends = []
        for place, trigger in ((here, here_id), (there, there_id)):
            row = triggers[trigger]
            ends.append(f"{{ {row['ContinentID']}, {float(row['Pos_0']):.1f}, {float(row['Pos_1']):.1f}, {lua_string(place)} }}")
        lines.append(f'        {{ "{kind}", "{side}", {seconds}, {ends[0]}, {ends[1]} }},')
    lines.append("    },")
    lines.append("}")
    write(OUT, lines)
    print(f"{len(used)} flight points ({moved} at their flight master), {len(hops)} flights, {len(ROUTES)} ships, {len(LINKS)} links -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
