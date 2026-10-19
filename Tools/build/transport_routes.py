"""Builds NaowhForever_QoL/Travel/TransportRoutes.lua: the boats and zeppelins NauticusClassic timed.

Run from the repo root with NauticusClassic's data.lua (MIT, github.com/psynct/NauticusClassic, commit
504bc4c248e13696756e920b359f6a95b8e9eda4):

    python Tools/build/transport_routes.py path/to/NauticusClassic/data.lua

Each route keeps its measured round trip, both docks' arrival and departure in its cycle, and the two
trigger segments a rider passes. NauticusClassic stores places on the whole-world map; they are turned
into world yards by a fit per continent on the docks it shares with TransportData.lua.
"""

import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402

# NauticusClassic's transport id, its ship's name, then the TransportData stop at its first and second dock.
# The Bravery (5) is left out: on Forever it calls at Southshore on the way, so its path no longer fits.
ROUTES = [
    (1, "The Thundercaller", "1411:Zeppelin to Undercity", "Orgrimmar", "1420:Zeppelin to Orgrimmar", "Undercity"),
    (2, "The Iron Eagle", "1411:Zeppelin to Grom'gol", "Orgrimmar", "1434:Zeppelin to Orgrimmar", "Grom'gol"),
    (3, "The Purple Princess", "1420:Zeppelin to Grom'gol", "Undercity", "1434:Zeppelin to Undercity", "Grom'gol"),
    (4, "The Maiden's Fancy", "1413:Boat to Booty Bay", "Ratchet", "1434:Boat to Ratchet", "Booty Bay"),
    (6, "The Lady Mehley", "1437:Boat to Theramore", "Menethil Harbor", "1445:Boat to Menethil Harbor", "Theramore"),
    (7, "The Moonspray", "1438:Boat to Auberdine", "Rut'theran Village", "1439:Boat to Rut'theran Village",
     "Auberdine"),
    (8, "Feathermoon Ferry", "1444:Boat to the Feralas coast", "Feathermoon Stronghold",
     "1444:Boat to Feathermoon Stronghold", "The Forgotten Coast"),
]
# NauticusClassic's whole-world map holds Kalimdor left of the middle and the Eastern Kingdoms right of it.
KALIMDOR, EASTERN_KINGDOMS, MIDDLE = 1, 0, 0.5
MAX_DOCK_MISS = 20

OUTPUT = paths.ROOT / "NaowhForever_QoL" / "Travel" / "TransportRoutes.lua"
STOPS = paths.ROOT / "NaowhForever_QoL" / "Travel" / "TransportData.lua"


def read_routes(text):
    rtts = [float(v) for v in re.findall(r"^\s*([0-9.]+), -- \[\d+\]",
                                         text[text.index("NauticusClassic.rtts"):text.index("NauticusClassic.transitZones")],
                                         re.M)]
    body = text[text.index("NauticusClassic.packedData"):]
    blocks = re.split(r"^\[(\d+)\] = \{", body, flags=re.M)[1:]
    routes = {}
    for i in range(0, len(blocks), 2):
        rows, x, y, offset = [], 0.0, 0.0, 0.0
        for packed in re.findall(r'"([^"]+)"', blocks[i + 1]):
            fields = packed.split(":")
            x, y = x + float(fields[0]), y + float(fields[1])
            offset += float(fields[2])
            rows.append({"x": x, "y": y, "dt": float(fields[2]), "offset": offset,
                         "tag": fields[5] if len(fields) > 5 else ""})
        routes[int(blocks[i])] = {"period": rtts[int(blocks[i]) - 1], "rows": rows}
    return routes


def read_stops(text):
    stops = {}
    for key, cont, x, y in re.findall(r'\["([^"]+)"\] = \{ map = \d+, continent = (\d+), x = ([-0-9.]+), y = ([-0-9.]+)',
                                      text):
        stops[key] = (int(cont), float(x), float(y))
    return stops


def side(u):
    return KALIMDOR if u < MIDDLE else EASTERN_KINGDOMS


def solve(points, pick):
    """Least squares for world = a * u + b * v + c over (u, v) -> world points."""
    rows = [(u, v, 1.0) for (u, v), _ in points]
    targets = [pick(world) for _, world in points]
    m = [[sum(r[i] * r[j] for r in rows) for j in range(3)] for i in range(3)]
    b = [sum(r[i] * t for r, t in zip(rows, targets)) for i in range(3)]
    for c in range(3):
        pivot = max(range(c, 3), key=lambda r: abs(m[r][c]))
        m[c], m[pivot], b[c], b[pivot] = m[pivot], m[c], b[pivot], b[c]
        for r in range(3):
            if r != c:
                f = m[r][c] / m[c][c]
                m[r] = [m[r][k] - f * m[c][k] for k in range(3)]
                b[r] -= f * b[c]
    return [b[i] / m[i][i] for i in range(3)]


def dock_rows(route):
    found = {}
    for index, row in enumerate(route["rows"]):
        if row["tag"].startswith("plat"):
            found[int(row["tag"][4:])] = index
    return found[1], found[2]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    routes = read_routes(open(sys.argv[1], encoding="utf-8-sig").read())
    stops = read_stops(STOPS.read_text(encoding="utf-8"))

    pairs = {KALIMDOR: [], EASTERN_KINGDOMS: []}
    for tid, _, first, _, second, _ in ROUTES:
        rows = routes[tid]["rows"]
        for row_index, key in zip(dock_rows(routes[tid]), (first, second)):
            row = rows[row_index]
            cont, x, y = stops[key]
            assert side(row["x"]) == cont, f"{key} is on the other continent in NauticusClassic"
            pairs[cont].append(((row["x"], row["y"]), (x, y)))
    fits = {cont: (solve(p, lambda w: w[0]), solve(p, lambda w: w[1])) for cont, p in pairs.items()}

    def world(row):
        cont = side(row["x"])
        fx, fy = fits[cont]
        u, v = row["x"], row["y"]
        return cont, fx[0] * u + fx[1] * v + fx[2], fy[0] * u + fy[1] * v + fy[2]

    lines = [
        "-- TransportRoutes.lua: the ships NauticusClassic timed (MIT, psynct), generated by Tools/build/transport_routes.py.",
        "local ns = _G.NaowhForever",
        "",
        "ns.TransportRoutes = {",
    ]
    for tid, name, first, first_place, second, second_place in ROUTES:
        route = routes[tid]
        rows = route["rows"]
        one, two = dock_rows(route)
        for row_index, key in ((one, first), (two, second)):
            _, x, y = world(rows[row_index])
            miss = math.hypot(x - stops[key][1], y - stops[key][2])
            assert miss < MAX_DOCK_MISS, f"{name} docks {miss:.1f} yd from {key}"
        docks = [
            (first, first_place, 0.0, rows[one]["offset"]),
            (second, second_place, rows[two - 1]["offset"], rows[two]["offset"]),
        ]
        triggers = []
        for index, row in enumerate(rows):
            if row["tag"].startswith("trig"):
                cont, bx, by = world(row)
                cont_a, ax, ay = world(rows[index - 1])
                assert cont == cont_a, f"{name}'s trigger at row {index + 1} crosses continents"
                triggers.append((cont, ax, ay, bx, by, rows[index - 1]["offset"], row["dt"]))
        assert len(triggers) == 2, f"{name} has {len(triggers)} triggers"
        lines.append(f'    ["{name}"] = {{ period = {route["period"]:.6f}, docks = {{')
        for key, place, arrive, leave in docks:
            lines.append(f'        {{ stop = "{key}", place = "{place}", arrive = {arrive:.3f}, leave = {leave:.3f} }},')
        lines.append("    }, triggers = {")
        for cont, ax, ay, bx, by, at, span in triggers:
            lines.append(f"        {{ continent = {cont}, ax = {ax:.1f}, ay = {ay:.1f}, bx = {bx:.1f}, by = {by:.1f},"
                         f" at = {at:.3f}, span = {span:.3f} }},")
        lines.append("    } },")
    lines.append("}")
    OUTPUT.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))
    print(f"Transport routes -> {OUTPUT}")


if __name__ == "__main__":
    main()
