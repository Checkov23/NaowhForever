# Generates the addon's Core/Media/ textures as uncompressed 32-bit TGAs.
# WoW mask textures read the alpha channel, so every shape here lives in alpha over white
# RGB, which lets the same file serve as a mask or be tinted and drawn directly.
# Run from the repo root: python Tools/media/make_media.py
import math
import os
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402

OUT = os.path.join(paths.ROOT, "Core", "Media")
RXP_OUT = os.path.join(paths.ROOT, "Core", "Integrations", "RestedXP", "Media")

NAOWH_BLUE = (0x00, 0x91, 0xED)


def write_tga(path, size, pixel_fn):
    # Uncompressed true-color TGA, 32bpp BGRA, bottom-left origin.
    header = struct.pack(
        "<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 8
    )
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            r, g, b, a = pixel_fn(x + 0.5, size - y - 0.5, size)
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    with open(path, "wb") as f:
        f.write(header + b"".join(rows))
    print("wrote", os.path.normpath(path))


def smooth(edge, dist):
    # 1 inside, 0 outside, ~1px anti-aliased edge.
    return max(0.0, min(1.0, edge - dist + 0.5))


def disc(x, y, size):
    c = size / 2.0
    d = math.hypot(x - c, y - c)
    a = smooth(c - 0.5, d)
    v = int(round(255 * a))
    return (255, 255, 255, v)


def half_disc(x, y, size):
    # Right half of a disc: the sweep piece. Two of these, each clipped to one half of
    # the ring and rotated, draw any arc without per-frame geometry.
    c = size / 2.0
    d = math.hypot(x - c, y - c)
    a = smooth(c - 0.5, d) if x >= c else 0.0
    return (255, 255, 255, int(round(255 * a)))


def hole(x, y, size):
    # Thickness mask: transparent inside the inscribed disc, opaque outside it. Drawn
    # smaller than the ring and wrapped CLAMPTOWHITE, so it punches the centre out and
    # leaves everything beyond its own rect visible.
    c = size / 2.0
    d = math.hypot(x - c, y - c)
    a = 1.0 - smooth(c - 0.5, d)
    return (255, 255, 255, int(round(255 * a)))


def gear(x, y, size):
    c = size / 2.0
    dx, dy = x - c, y - c
    d = math.hypot(dx, dy)
    ang = math.atan2(dy, dx)
    teeth = 8
    body = size * 0.30
    tooth = size * 0.42
    hole = size * 0.13
    wave = 0.5 + 0.5 * math.cos(ang * teeth)
    radius = body + (tooth - body) * (1.0 if wave > 0.5 else 0.0)
    a = smooth(radius, d) * (1.0 - smooth(hole, d))
    v = int(round(255 * a))
    return (0xC8, 0xC8, 0xC8, v)


def icon(x, y, size):
    # Dark grey rounded square, Naowh blue border, blue exclamation mark.
    c = size / 2.0
    half = size * 0.46
    corner = size * 0.12
    qx, qy = abs(x - c) - (half - corner), abs(y - c) - (half - corner)
    dist = math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - corner
    inside = smooth(0.0, dist + 0.5)
    edge = inside * (1.0 - smooth(0.0, dist + size * 0.05))
    r, g, b = 0x1A, 0x1C, 0x1F
    a = inside
    if edge > 0.01:
        br, bg, bb = NAOWH_BLUE
        r = int(r + (br - r) * edge)
        g = int(g + (bg - g) * edge)
        b = int(b + (bb - b) * edge)
    # exclamation mark: bar + dot, centered
    bar_w, bar_top, bar_bot = size * 0.09, size * 0.70, size * 0.36
    dot_y, dot_r = size * 0.26, size * 0.06
    mark = 0.0
    if abs(x - c) < bar_w and bar_bot < y < bar_top:
        mark = 1.0
    if math.hypot(x - c, y - dot_y) < dot_r:
        mark = 1.0
    if mark > 0:
        r, g, b = NAOWH_BLUE
    return (int(r), int(g), int(b), int(round(255 * a)))


def seg_dist(px, py, ax, ay, bx, by):
    # Distance from a point to the segment a-b.
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def chevron(x, y, size):
    # A thick right-pointing chevron with rounded ends: the feature rows' open/closed
    # arrow, rotated a quarter turn to point down when open.
    ax, ay = size * 0.36, size * 0.18
    tx, ty = size * 0.66, size * 0.50
    bx, by = size * 0.36, size * 0.82
    d = min(seg_dist(x, y, ax, ay, tx, ty), seg_dist(x, y, tx, ty, bx, by))
    a = smooth(size * 0.10, d)
    return (255, 255, 255, int(round(255 * a)))


def segment_dist(x, y, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - (ax + t * dx), y - (ay + t * dy))


def stroke(size, points, width):
    # White polyline with round caps, alpha only, for tinting with SetVertexColor.
    def pixel(x, y, _):
        d = min(segment_dist(x, y, *(p * size for p in points[i] + points[i + 1]))
                for i in range(len(points) - 1))
        return (255, 255, 255, int(round(255 * smooth(width * size / 2, d))))
    return pixel


def chain(x, y, size):
    # Two chain links on the diagonal, bottom-left to top-right, each a stroked capsule, the
    # second passing through the first: the Journal's Chain action. Where they cross, the
    # one underneath is cut back by a hair, over on one side of the diagonal and under on
    # the other, so they read as linked rather than as one shape.
    ux, uy = 0.7071, -0.7071
    c, half, radius, width, gap = size / 2.0, size * 0.10, size * 0.13, size * 0.085, size * 0.045
    rings = []
    for offset in (-0.19, 0.19):
        mx, my = c + ux * offset * size, c + uy * offset * size
        d = seg_dist(x, y, mx - ux * half, my - uy * half, mx + ux * half, my + uy * half)
        rings.append(abs(d - radius))
    a1, a2 = smooth(width / 2, rings[0]), smooth(width / 2, rings[1])
    if (x - c) * uy - (y - c) * ux > 0:
        a2 *= 1.0 - smooth(width / 2 + gap, rings[0])
    else:
        a1 *= 1.0 - smooth(width / 2 + gap, rings[1])
    return (255, 255, 255, int(round(255 * max(a1, a2))))


def info(x, y, size):
    # A thin ring with an "i" in it: the Journal's Naowh's tip button.
    c = size / 2.0
    ring = smooth(size * 0.045, abs(math.hypot(x - c, y - c) - size * 0.42))
    dot = smooth(size * 0.075, math.hypot(x - c, y - size * 0.30))
    stem = smooth(size * 0.065, seg_dist(x, y, c, size * 0.46, c, size * 0.72))
    return (255, 255, 255, int(round(255 * max(ring, dot, stem))))


def pin(x, y, size):
    # A map pin: a round head that narrows to a point, with a hole in the head. The head's
    # circle and a triangle down to the tip, each with a soft edge, joined; the hole cut out.
    cx, cy, r = size * 0.5, size * 0.38, size * 0.27
    head = smooth(r, math.hypot(x - cx, y - cy))
    # The cone's sides touch the head where a line from the tip meets the circle at a tangent.
    tip_y = size * 0.93
    k = r / (tip_y - cy)
    top_y, half = cy + r * k, r * math.sqrt(1.0 - k * k)
    # Distance inside the triangle (left side, right side, top), negative outside.
    def side(ax, ay, bx, by):
        dx, dy = bx - ax, by - ay
        return ((x - ax) * dy - (y - ay) * dx) / math.hypot(dx, dy)
    inside = min(side(cx - half, top_y, cx, tip_y), -side(cx + half, top_y, cx, tip_y), y - top_y)
    cone = max(0.0, min(1.0, inside + 0.5))
    hole = smooth(size * 0.105, math.hypot(x - cx, y - cy))
    a = max(head, cone) * (1.0 - hole)
    return (255, 255, 255, int(round(255 * a)))


def hanger(x, y, size):
    # A coat hanger, for looks (appearances): an open hook at the top, a short neck, and a
    # triangle for the shoulders and the bar.
    w = size * 0.075
    hx, hy, hr = size * 0.5, size * 0.23, size * 0.10
    ring = abs(math.hypot(x - hx, y - hy) - hr)
    # The hook is open at its lower left.
    hook = smooth(w / 2, ring) if not (x < hx and y > hy) else 0.0
    body = [(0.5, 0.33), (0.5, 0.40), (0.08, 0.74), (0.92, 0.74), (0.5, 0.40)]
    d = min(seg_dist(x, y, body[i][0] * size, body[i][1] * size, body[i + 1][0] * size, body[i + 1][1] * size)
            for i in range(len(body) - 1))
    a = max(hook, smooth(w / 2, d))
    return (255, 255, 255, int(round(255 * a)))


def rounded_rect_dist(x, y, cx, cy, hw, hh, r):
    # Signed distance to a rounded rectangle: negative inside.
    qx, qy = abs(x - cx) - (hw - r), abs(y - cy) - (hh - r)
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r


def sidebar(filled):
    # A window with a panel down its left: the Journal's show and hide the list button. The
    # panel is filled while the list shows, empty while it is hidden.
    def pixel(x, y, size):
        w = size * 0.075
        c = size / 2.0
        d = rounded_rect_dist(x, y, c, c, size * 0.42, size * 0.34, size * 0.08)
        frame = smooth(w / 2, abs(d))
        split = size * 0.40
        divider = smooth(w / 2, abs(x - split)) if d < 0 else 0.0
        panel = 0.0
        if filled and d < -w / 2 and x < split:
            panel = 0.55
        a = max(frame, divider, panel)
        return (255, 255, 255, int(round(255 * a)))
    return pixel


def funnel(x, y, size):
    # A funnel, outlined: the Journal's Filters button.
    w = size * 0.075
    points = [(0.14, 0.20), (0.86, 0.20), (0.57, 0.53), (0.57, 0.78), (0.43, 0.86), (0.43, 0.53),
              (0.14, 0.20)]
    d = min(seg_dist(x, y, points[i][0] * size, points[i][1] * size, points[i + 1][0] * size,
                     points[i + 1][1] * size) for i in range(len(points) - 1))
    return (255, 255, 255, int(round(255 * smooth(w / 2, d))))


def half_circle(x, y, size):
    # A ring with its left half filled: the Journal's Opacity.
    c = size / 2.0
    d = math.hypot(x - c, y - c)
    r, w = size * 0.36, size * 0.075
    ring = smooth(w / 2, abs(d - r))
    fill = smooth(r, d) if x < c else 0.0
    return (255, 255, 255, int(round(255 * max(ring, fill))))


def ellipse_dist(x, y, cx, cy, rx, ry):
    # Close to the signed distance to an ellipse (negative inside); exact enough for a ~1px
    # edge at icon sizes.
    k = math.hypot((x - cx) / rx, (y - cy) / ry)
    return (k - 1.0) * min(rx, ry)


def skull(x, y, size):
    # A skull: a round cranium over a squarer jaw, two eyes, a nose and the gaps between the
    # teeth cut out. The Journal's kill count.
    u, v = x / size, y / size
    head = min(ellipse_dist(u, v, 0.5, 0.42, 0.33, 0.31),
               rounded_rect_dist(u, v, 0.5, 0.72, 0.2, 0.13, 0.05))
    eyes = min(ellipse_dist(u, v, 0.36, 0.46, 0.095, 0.105),
               ellipse_dist(u, v, 0.64, 0.46, 0.095, 0.105))
    nose = ellipse_dist(u, v, 0.5, 0.61, 0.035, 0.055)
    teeth = min(rounded_rect_dist(u, v, 0.43, 0.82, 0.014, 0.06, 0.01),
                rounded_rect_dist(u, v, 0.57, 0.82, 0.014, 0.06, 0.01))
    cut = min(eyes, nose, teeth)
    d = max(head, -cut) * size   # in pixels: inside the head and outside every cut
    return (255, 255, 255, int(round(255 * smooth(0, d))))


def polygon_dist(x, y, points):
    """Signed distance to a closed polygon (negative inside), by its edges and an even-odd
    crossing test."""
    d, inside = float("inf"), False
    n = len(points)
    for i in range(n):
        ax, ay = points[i]
        bx, by = points[(i + 1) % n]
        d = min(d, seg_dist(x, y, ax, ay, bx, by))
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            inside = not inside
    return -d if inside else d


def waypoint_shape(sides, ring):
    # A regular polygon, point up: the Waypoint Pin's hex (6) or diamond (4), filled or as an
    # outline a tenth of its size thick.
    def pixel(x, y, size):
        c, r = size / 2.0, size * 0.46
        points = [(c + r * math.sin(2 * math.pi * i / sides), c - r * math.cos(2 * math.pi * i / sides))
                  for i in range(sides)]
        d = polygon_dist(x, y, points)
        a = smooth(0, d)
        if ring:
            a *= 1.0 - smooth(0, d + size * 0.1)
        return (255, 255, 255, int(round(255 * a)))
    return pixel


def star(x, y, size):
    # A five-pointed star, point up: the Journal's mark for your BiS.
    c, outer = size / 2.0, size * 0.47
    inner = outer * 0.42
    points = []
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        a = math.pi / 2 + i * math.pi / 5
        points.append((c + r * math.cos(a), c + size * 0.03 - r * math.sin(a)))
    return (255, 255, 255, int(round(255 * smooth(0, polygon_dist(x, y, points)))))


def crossed_swords(x, y, size):
    # Two swords crossed, points up: contested ground, beside the factions' crests.
    def sword(flip):
        def at(u, v):
            return (1 - u if flip else u, v)
        blade = stroke(size, [at(0.24, 0.80), at(0.80, 0.20)], 0.09)
        guard = stroke(size, [at(0.20, 0.62), at(0.38, 0.80)], 0.08)
        grip = stroke(size, [at(0.24, 0.80), at(0.14, 0.90)], 0.08)
        return max(blade(x, y, size)[3], guard(x, y, size)[3], grip(x, y, size)[3])
    return (255, 255, 255, max(sword(False), sword(True)))


def people(x, y, size):
    # Two people, one in front of the other: group members on the same quest. Each is a
    # round head over rounded shoulders; the one behind is cut back around the one in front.
    u, v = x / size, y / size

    def person(cx, top, scale):
        head = ellipse_dist(u, v, cx, top + 0.15 * scale, 0.14 * scale, 0.14 * scale)
        body = ellipse_dist(u, v, cx, top + 0.62 * scale, 0.27 * scale, 0.26 * scale)
        body = max(body, v - (top + 0.66 * scale))   # shoulders: the top of the body only
        return min(head, body)
    front = person(0.40, 0.18, 1.0)
    back = max(person(0.68, 0.12, 0.82), -(front - 0.06))   # a gap round the front one
    d = min(front, back) * size
    return (255, 255, 255, int(round(255 * smooth(0, d))))


def bag(x, y, size):
    # A tied loot bag: a round body, a band where it is tied, and the cloth fanning out
    # above it in two points. The Journal's loot from a boss.
    u, v = x / size, y / size
    body = min(ellipse_dist(u, v, 0.5, 0.67, 0.35, 0.28),
               rounded_rect_dist(u, v, 0.5, 0.42, 0.11, 0.05, 0.02))
    tie = rounded_rect_dist(u, v, 0.5, 0.33, 0.16, 0.035, 0.03)
    cloth = polygon_dist(u, v, [(0.41, 0.27), (0.59, 0.27), (0.74, 0.08), (0.5, 0.15), (0.26, 0.08)])
    d = min(body, tie, cloth) * size
    return (255, 255, 255, int(round(255 * smooth(0, d))))


# The waypoint arrow's facets (left outer, left inner, right inner, right outer) as how much of the tint
# each keeps, and its dark edge.
ARROW_SHADES = (158, 204, 255, 230)
ARROW_EDGE = 24


# RestedXP's frame image: eight 32x32 cells (left, right, top, bottom, the corners), each showing 28 texels over
# 8 units, the top and bottom turned. One unit of black sits against RestedXP's fill, which starts 4, 2, 2 and
# 4 units in, and runs on into the margin so filtering shows no seam.
FRAME_INSET = {"left": 4, "right": 2, "top": 2, "bottom": 4}
FRAME_SIDES = ("left", "right", "top", "bottom")
FRAME_CORNERS = (("left", "top"), ("right", "top"), ("left", "bottom"), ("right", "bottom"))


def rxp_frame(x, y, width, height):
    cell = int(x // 32)
    if cell > 7:
        return (0, 0, 0, 0)
    a, b = (x - 32 * cell - 2) / 3.5, (y - 2) / 3.5
    dist = {"left": a, "right": 8 - a, "top": b, "bottom": 8 - b}

    def line(side, d):
        return FRAME_INSET[side] - 1 <= d < FRAME_INSET[side]

    if cell < 4:
        side = FRAME_SIDES[cell]
        on = line(side, a if side in ("left", "top") else 8 - a)
    else:
        v, h = FRAME_CORNERS[cell - 4]
        on = (line(v, dist[v]) and dist[h] >= FRAME_INSET[h] - 1) or (line(h, dist[h]) and dist[v] >= FRAME_INSET[v] - 1)
    return (0, 0, 0, 255 if on else 0)


def grip(x, y, size):
    lines = [stroke(size, [(a, 0.94), (0.94, a)], 0.09) for a in (0.2, 0.46, 0.72)]
    return max((line(x, y, size) for line in lines), key=lambda p: p[3])


def nav_arrow(wide, glow):
    # The waypoint arrow, point up: a kite in four facets with a dark edge and a thin line inside, grey over
    # white so a vertex color tints it. wide: base 14% wider. glow: a soft halo, with the kite drawn
    # smaller to leave it room (GLOW_FILL in Core/Integrations/RestedXP/Themes.lua). Units are a 97-tall kite.
    half = 49.0 if wide else 43.0              # wing tips from the middle
    shrink = 0.76 if glow else 1.0             # how much of the image the kite fills
    glow_reach, glow_peak = 22.0, 0.9          # halo reach, and its strength at the edge
    unit = 0.88 / 97.0                         # one unit as a share of the canvas
    outer_left, inner_left, inner_right, outer_right = ARROW_SHADES

    def canvas(px, py):
        u, v = 0.5 + px * unit, 0.05 + (py + 50) * unit
        return 0.5 + (u - 0.5) * shrink, 0.5 + (v - 0.5) * shrink

    outer = [canvas(*p) for p in ((0, -50), (half, 47), (0, 23), (-half, 47))]
    inner = [canvas(*p) for p in ((0, -33), (0.78 * half, 38), (0, 21), (-0.78 * half, 38))]

    def pixel(x, y, size):
        u, v = x / size, y / size
        d = polygon_dist(u, v, outer) * size
        unit_px = unit * shrink * size
        # the crease runs from the tip to a third of the way along the lower edge
        px = ((0.5 + (u - 0.5) / shrink) - 0.5) / unit
        py = ((0.5 + (v - 0.5) / shrink) - 0.05) / unit - 50
        folded = (half / 3.0) * (py + 50) - 81.0 * abs(px) >= 0
        if px < 0:
            shade = inner_left if folded else outer_left
        else:
            shade = inner_right if folded else outer_right
        fill = smooth(0, d)
        edge = smooth(size * 0.028, d)
        line = smooth(1.1, abs(polygon_dist(u, v, inner)) * size) * fill
        halo = 0.0
        if glow:
            away = max(0.0, d) / (glow_reach * unit_px)   # 0 at the edge, 1 where the halo ends
            if away < 1.0:
                halo = glow_peak * (1.0 - away) ** 1.6
        rgb, alpha = (255.0 if glow else float(ARROW_EDGE)), 0.0
        for color, cover in ((255.0, halo), (float(ARROW_EDGE), edge), (float(shade), fill), (255.0, line)):
            if cover <= 0:
                continue
            total = cover + alpha * (1 - cover)
            rgb = (color * cover + rgb * alpha * (1 - cover)) / total
            alpha = total
        c = int(round(rgb))
        return (c, c, c, int(round(255 * alpha)))

    return pixel


def tray_arrow(up):
    # An open tray with an arrow down into it (Import) or up out of it (Export).
    shaft = [(0.5, 0.60), (0.5, 0.12)] if up else [(0.5, 0.12), (0.5, 0.60)]
    head = [(0.32, 0.30), (0.5, 0.12), (0.68, 0.30)] if up else [(0.32, 0.42), (0.5, 0.60), (0.68, 0.42)]
    parts = [stroke(64, [(0.16, 0.60), (0.16, 0.86), (0.84, 0.86), (0.84, 0.60)], 0.09),
             stroke(64, shaft, 0.09), stroke(64, head, 0.09)]

    def pixel(x, y, size):
        return (255, 255, 255, max(part(x, y, size)[3] for part in parts))
    return pixel


def wand(x, y, size):
    # A wand with a four-pointed sparkle at its tip: fill in for you.
    stick = stroke(size, [(0.14, 0.86), (0.56, 0.44)], 0.10)(x, y, size)[3]
    cx, cy = size * 0.70, size * 0.30
    points = []
    for i in range(8):
        r = size * (0.24 if i % 2 == 0 else 0.06)
        a = i * math.pi / 4
        points.append((cx + r * math.cos(a), cy - r * math.sin(a)))
    spark = int(round(255 * smooth(0, polygon_dist(x, y, points))))
    return (255, 255, 255, max(stick, spark))


def scales(x, y, size):
    # A balance: a post on a foot, a beam across its top, and a pan hung from each end:
    # Stat Weights, what each stat weighs.
    lines = [[(0.5, 0.20), (0.5, 0.84)], [(0.32, 0.84), (0.68, 0.84)], [(0.14, 0.24), (0.86, 0.24)],
             [(0.14, 0.24), (0.04, 0.54)], [(0.14, 0.24), (0.24, 0.54)],
             [(0.86, 0.24), (0.76, 0.54)], [(0.86, 0.24), (0.96, 0.54)],
             [(0.02, 0.54), (0.08, 0.64), (0.20, 0.64), (0.26, 0.54)],
             [(0.74, 0.54), (0.80, 0.64), (0.92, 0.64), (0.98, 0.54)]]
    return (255, 255, 255, max(stroke(size, line, 0.07)(x, y, size)[3] for line in lines))



def speaker(x, y, size):
    # A speaker, its cone opening right, and two sound waves: play a sound.
    body = [(0.10, 0.38), (0.26, 0.38), (0.48, 0.18), (0.48, 0.82), (0.26, 0.62), (0.10, 0.62)]
    shape = smooth(0, polygon_dist(x, y, [(px * size, py * size) for px, py in body]))
    waves = 0.0
    for r in (0.16, 0.30):
        arc = [(0.50 + r * math.cos(a), 0.5 - r * math.sin(a))
               for a in [(-0.85 + 1.7 * i / 16) for i in range(17)]]
        waves = max(waves, stroke(size, arc, 0.08)(x, y, size)[3] / 255)
    return (255, 255, 255, int(round(255 * max(shape, waves))))


def play(x, y, size):
    corner = size * 0.05
    points = [(0.34 * size, 0.24 * size), (0.74 * size, 0.50 * size), (0.34 * size, 0.76 * size)]
    return (255, 255, 255, int(round(255 * smooth(0, polygon_dist(x, y, points) - corner))))


def pause(x, y, size):
    d = min(rounded_rect_dist(x, y, size * 0.36, size * 0.5, size * 0.085, size * 0.27, size * 0.04),
            rounded_rect_dist(x, y, size * 0.64, size * 0.5, size * 0.085, size * 0.27, size * 0.04))
    return (255, 255, 255, int(round(255 * smooth(0, d))))


def reset(x, y, size):
    cx, cy, r = 0.5, 0.5, 0.28
    start, sweep = math.radians(60), math.radians(285)
    arc = [(cx + r * math.cos(start + sweep * i / 32), cy - r * math.sin(start + sweep * i / 32))
           for i in range(33)]
    ring = stroke(size, arc, 0.10)(x, y, size)[3]
    px, py = cx + r * math.cos(start), cy - r * math.sin(start)
    dx, dy = math.sin(start), math.cos(start)
    nx, ny = math.cos(start), -math.sin(start)
    head = [((px + dx * 0.20) * size, (py + dy * 0.20) * size),
            ((px - dx * 0.02 + nx * 0.14) * size, (py - dy * 0.02 + ny * 0.14) * size),
            ((px - dx * 0.02 - nx * 0.14) * size, (py - dy * 0.02 - ny * 0.14) * size)]
    tip = int(round(255 * smooth(0, polygon_dist(x, y, head))))
    return (255, 255, 255, max(ring, tip))


def soft_shade(x, y, size):
    # Soft's fade behind HUD text (Parts.HudBackdrop): opaque in the middle, clear at the edge, a
    # smoothstep with no slope at either end. Sliced nine ways and stretched, it shows no edge: the
    # middle row and column are the sides' fades, the quarters the rounded corners.
    c = size / 2.0
    t = max(0.0, min(1.0, 1.0 - math.hypot(x - c, y - c) / c))
    return (255, 255, 255, int(round(255 * t * t * (3 - 2 * t))))


def write_wide_tga(path, width, height, pixel_fn, samples=4):
    # As write_tga, for a texture wider than tall, each pixel the average of samples x samples
    # points across it: a small mark drawn near its own size stays smooth, as text icons are
    # drawn without mipmaps and a big texture shrunk in them shimmers.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    rows = []
    for y in range(height):
        row = bytearray()
        for x in range(width):
            total = [0.0, 0.0, 0.0, 0.0]
            for sy in range(samples):
                for sx in range(samples):
                    px = pixel_fn(x + (sx + 0.5) / samples, height - y - (sy + 0.5) / samples, width, height)
                    for k in range(4):
                        total[k] += px[k]
            r, g, b, a = (int(round(v / (samples * samples))) for v in total)
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    with open(path, "wb") as f:
        f.write(header + b"".join(rows))
    print("wrote", os.path.normpath(path))


def infinity_shape(x, y, width, height, grow):
    # The sign's distance field: how far (x, y) is inside its stroke, grown by grow pixels.
    best = -1e9
    for i in range(160):
        t0, t1 = i * 2 * math.pi / 160, (i + 1) * 2 * math.pi / 160
        k0, k1 = 1 + math.sin(t0) ** 2, 1 + math.sin(t1) ** 2
        a = (width * (0.5 + 0.40 * math.cos(t0) / k0), height * (0.5 + 0.80 * math.sin(t0) * math.cos(t0) / k0))
        b = (width * (0.5 + 0.40 * math.cos(t1) / k1), height * (0.5 + 0.80 * math.sin(t1) * math.cos(t1) / k1))
        w = height * (0.07 + 0.07 * (abs(math.cos(t0)) ** 2 + abs(math.cos(t1)) ** 2) / 2) + grow
        best = max(best, w - seg_dist(x, y, *a, *b))
    return best


def infinity_outlined(x, y, width, height):
    # The sign with a dark outline round it, for a badge on an item's icon: no box, the outline
    # alone keeps it readable on any icon's art. White inside (it takes the Forever gold),
    # black in the outline.
    inside = 1.0 if infinity_shape(x, y, width, height, 0) >= 0 else 0.0
    edge = 1.0 if infinity_shape(x, y, width, height, 1.4) >= 0 else 0.0
    v = int(round(255 * inside))
    return (v, v, v, int(round(255 * edge)))


def infinity(x, y, width, height):
    # An infinity sign, thick at its loops and thin where they cross: WoW Forever's mark, as
    # wide as twice its height. White, to take the Forever gold; no rim, as it sits on the
    # addon's dark panels at text size.
    points, widths = [], []
    for i in range(161):
        t = i * 2 * math.pi / 160
        k = 1 + math.sin(t) ** 2
        points.append((width * (0.5 + 0.43 * math.cos(t) / k),
                       height * (0.5 + 0.86 * math.sin(t) * math.cos(t) / k)))
        widths.append(height * (0.07 + 0.07 * abs(math.cos(t)) ** 2))
    inner = 0.0
    for i in range(160):
        d = seg_dist(x, y, *points[i], *points[i + 1])
        w = (widths[i] + widths[i + 1]) / 2
        inner = max(inner, 1.0 if d <= w else 0.0)
    return (255, 255, 255, int(round(255 * inner)))


def infinity_track(width, height, scale=2):
    W, H = width * scale, height * scale
    alpha = [0.0] * (W * H)

    def point(t):
        k = 1 + math.sin(t) ** 2
        return (W * (0.5 + 0.44 * math.cos(t) / k), H * (0.5 - 0.84 * math.sin(t) * math.cos(t) / k))

    radius = 0.8 * scale
    steps = 1800
    for i in range(steps):
        cx, cy = point(i * 2 * math.pi / steps)
        for py in range(int(cy - radius - 2), int(cy + radius + 2) + 1):
            for px in range(int(cx - radius - 2), int(cx + radius + 2) + 1):
                if 0 <= px < W and 0 <= py < H:
                    d = math.hypot(px + 0.5 - cx, py + 0.5 - cy)
                    alpha[py * W + px] = max(alpha[py * W + px], max(0.0, min(1.0, radius - d + 0.5)))

    def pixel(x, y, w, h):
        px = min(W - 1, max(0, int(x * scale)))
        py = min(H - 1, max(0, int(y * scale)))
        return (255, 255, 255, 255 * alpha[py * W + px])
    return pixel


def glow_dot(x, y, size):
    d = math.hypot(x - size / 2.0, y - size / 2.0) / (size / 2.0)
    core = smooth(size * 0.11, d * size / 2.0)
    halo = 0.55 * math.exp(-4.5 * d * d)
    return (255, 255, 255, int(round(255 * min(1.0, max(core, halo)))))



def elbow(x, y, width, height):
    # The rounded corner of a tree line, 1px wide: down the left edge, then a quarter circle
    # into the bottom edge, heading right. Drawn at its own size (8 by 8), so it stays a clean
    # pixel line where it meets the 1px lines either side of it.
    r = width - 1.5
    cx, cy = 0.5 + r, height - 0.5 - r
    if y <= cy:
        d = abs(x - 0.5)
    elif x >= cx:
        d = abs(y - (height - 0.5))
    else:
        d = abs(math.hypot(x - cx, y - cy) - r)
    return (255, 255, 255, int(round(255 * max(0.0, min(1.0, 1.0 - d)))))


os.makedirs(OUT, exist_ok=True)
os.makedirs(RXP_OUT, exist_ok=True)
# y runs down the image.

def eye(slashed):
    # An eye, outlined, with its pupil: the HUD Editor's show and hide an element. Hidden, a
    # stroke crosses it on the diagonal, the eye cut back either side of the stroke.
    def pixel(x, y, size):
        c, w = size / 2.0, size * 0.05
        lid = abs(ellipse_dist(x / size, y / size, 0.5, 0.5, 0.40, 0.22)) * size
        a = max(smooth(w / 2, lid), smooth(size * 0.11, math.hypot(x - c, y - c)))
        if slashed:
            d = seg_dist(x, y, size * 0.18, size * 0.18, size * 0.82, size * 0.82)
            a = max(a * (1.0 - smooth(w / 2 + size * 0.06, d)), smooth(w / 2, d))
        return (255, 255, 255, int(round(255 * a)))
    return pixel


def padlock(x, y, size):
    # A padlock, its body filled and its shackle an arch over it: the HUD Editor's lock an
    # element in place.
    c, w = size / 2.0, size * 0.085
    body = smooth(0.0, rounded_rect_dist(x, y, c, size * 0.66, size * 0.27, size * 0.20, size * 0.05))
    arch = 0.0
    if y <= size * 0.47:
        arch = smooth(w / 2, abs(math.hypot(x - c, y - size * 0.40) - size * 0.17))
    return (255, 255, 255, int(round(255 * max(body, arch))))

def align(edge):
    # The HUD Editor's align buttons: two bars of different lengths and the line they line up
    # on. edge: "left", "hcenter", "right" (the line upright), "top", "vcenter", "bottom" (level),
    # or "across" and "down" for spacing evenly: two lines either side of one bar.
    def pixel(x, y, size):
        u, v = x / size, y / size
        if edge in ("top", "vcenter", "bottom", "down"):
            u, v = v, u
        w = 0.08
        if edge in ("across", "down"):
            line = min(abs(u - 0.14), abs(u - 0.86))
            a = smooth(w * size / 2, line * size) if 0.12 <= v <= 0.88 else 0.0
            box = rounded_rect_dist(u, v, 0.5, 0.5, 0.14, 0.24, 0.03)
            return (255, 255, 255, int(round(255 * max(a, smooth(0.0, box * size)))))
        at = {"left": 0.14, "top": 0.14, "hcenter": 0.5, "vcenter": 0.5, "right": 0.86, "bottom": 0.86}[edge]
        a = smooth(w * size / 2, abs(u - at) * size) if 0.1 <= v <= 0.9 else 0.0
        bars = ((0.33, 0.30), (0.67, 0.18))
        for cy, half in bars:
            if at == 0.14:
                cx = 0.22 + half
            elif at == 0.86:
                cx = 0.78 - half
            else:
                cx = 0.5
            d = rounded_rect_dist(u, v, cx, cy, half, 0.09, 0.03)
            a = max(a, smooth(0.0, d * size))
        return (255, 255, 255, int(round(255 * a)))
    return pixel


write_tga(os.path.join(OUT, "chevron_up.tga"), 64, stroke(64, [(0.22, 0.64), (0.5, 0.36), (0.78, 0.64)], 0.12))
write_tga(os.path.join(OUT, "cross.tga"), 64, lambda x, y, s: max(
    stroke(64, [(0.26, 0.26), (0.74, 0.74)], 0.11)(x, y, s),
    stroke(64, [(0.26, 0.74), (0.74, 0.26)], 0.11)(x, y, s), key=lambda p: p[3]))
write_tga(os.path.join(OUT, "check.tga"), 64, stroke(64, [(0.18, 0.5), (0.4, 0.72), (0.82, 0.28)], 0.13))
write_tga(os.path.join(OUT, "circle_mask.tga"), 128, disc)
write_tga(os.path.join(OUT, "circle_half.tga"), 256, half_disc)
write_tga(os.path.join(OUT, "circle_hole.tga"), 256, hole)
write_tga(os.path.join(OUT, "cog.tga"), 64, gear)
write_tga(os.path.join(OUT, "icon.tga"), 64, icon)
write_tga(os.path.join(OUT, "chevron.tga"), 64, chevron)
write_tga(os.path.join(OUT, "chain.tga"), 64, chain)
write_tga(os.path.join(OUT, "info.tga"), 64, info)
write_tga(os.path.join(OUT, "pin.tga"), 64, pin)
write_tga(os.path.join(OUT, "hanger.tga"), 64, hanger)
write_tga(os.path.join(OUT, "sidebar_shown.tga"), 64, sidebar(True))
write_tga(os.path.join(OUT, "sidebar_hidden.tga"), 64, sidebar(False))
write_tga(os.path.join(OUT, "funnel.tga"), 64, funnel)
write_tga(os.path.join(OUT, "opacity.tga"), 64, half_circle)
write_tga(os.path.join(OUT, "skull.tga"), 64, skull)
write_tga(os.path.join(OUT, "star.tga"), 64, star)
write_tga(os.path.join(OUT, "swords.tga"), 64, crossed_swords)
write_tga(os.path.join(OUT, "people.tga"), 64, people)
write_tga(os.path.join(OUT, "bag.tga"), 64, bag)
write_tga(os.path.join(RXP_OUT, "rxp_arrow.tga"), 128, nav_arrow(False, False))
write_tga(os.path.join(RXP_OUT, "rxp_arrow_glow.tga"), 128, nav_arrow(False, True))
write_tga(os.path.join(RXP_OUT, "rxp_arrow_wide.tga"), 128, nav_arrow(True, False))
write_tga(os.path.join(RXP_OUT, "rxp_arrow_wide_glow.tga"), 128, nav_arrow(True, True))
write_wide_tga(os.path.join(RXP_OUT, "rxp_frame.tga"), 256, 32, rxp_frame)
write_tga(os.path.join(RXP_OUT, "rxp_grip.tga"), 64, grip)
write_tga(os.path.join(OUT, "plus.tga"), 64, lambda x, y, s: max(
    stroke(64, [(0.5, 0.2), (0.5, 0.8)], 0.11)(x, y, s),
    stroke(64, [(0.2, 0.5), (0.8, 0.5)], 0.11)(x, y, s), key=lambda p: p[3]))
write_tga(os.path.join(OUT, "import.tga"), 64, tray_arrow(False))
write_tga(os.path.join(OUT, "export.tga"), 64, tray_arrow(True))
write_tga(os.path.join(OUT, "wand.tga"), 64, wand)
write_tga(os.path.join(OUT, "scales.tga"), 64, scales)
write_wide_tga(os.path.join(OUT, "infinity.tga"), 32, 16, infinity)
write_wide_tga(os.path.join(OUT, "infinity_outlined.tga"), 32, 16, infinity_outlined)
write_wide_tga(os.path.join(OUT, "Welcome", "infinity_track.tga"), 256, 128, infinity_track(256, 128), samples=2)
write_tga(os.path.join(OUT, "Welcome", "glow_dot.tga"), 64, glow_dot)
write_wide_tga(os.path.join(OUT, "elbow.tga"), 8, 8, elbow)
write_tga(os.path.join(OUT, "speaker.tga"), 64, speaker)
write_tga(os.path.join(OUT, "play.tga"), 64, play)
write_tga(os.path.join(OUT, "pause.tga"), 64, pause)
write_tga(os.path.join(OUT, "reset.tga"), 64, reset)
write_tga(os.path.join(OUT, "soft_shade.tga"), 64, soft_shade)
write_tga(os.path.join(OUT, "eye.tga"), 64, eye(False))
write_tga(os.path.join(OUT, "eye_off.tga"), 64, eye(True))
write_tga(os.path.join(OUT, "lock.tga"), 64, padlock)
write_tga(os.path.join(OUT, "align_left.tga"), 64, align("left"))
write_tga(os.path.join(OUT, "align_hcenter.tga"), 64, align("hcenter"))
write_tga(os.path.join(OUT, "align_right.tga"), 64, align("right"))
write_tga(os.path.join(OUT, "align_top.tga"), 64, align("top"))
write_tga(os.path.join(OUT, "align_vcenter.tga"), 64, align("vcenter"))
write_tga(os.path.join(OUT, "align_bottom.tga"), 64, align("bottom"))
write_tga(os.path.join(OUT, "align_across.tga"), 64, align("across"))
write_tga(os.path.join(OUT, "align_down.tga"), 64, align("down"))
write_tga(os.path.join(OUT, "waypoint_hex.tga"), 128, waypoint_shape(6, False))
write_tga(os.path.join(OUT, "waypoint_hex_ring.tga"), 128, waypoint_shape(6, True))
write_tga(os.path.join(OUT, "waypoint_diamond.tga"), 128, waypoint_shape(4, False))
write_tga(os.path.join(OUT, "waypoint_diamond_ring.tga"), 128, waypoint_shape(4, True))


LINE_W = 0.075


def bezier(p0, p1, p2, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1])
            for t in (i / n for i in range(n + 1))]


def arc(cx, cy, r, a0, a1, n=40):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def path(points, closed=False, alpha=1.0):
    pts = []
    for q in (points + [points[0]] if closed else points):
        if not pts or math.hypot(q[0] - pts[-1][0], q[1] - pts[-1][1]) > 1e-9:
            pts.append(q)

    def dist(u, v):
        return min(seg_dist(u, v, *pts[i], *pts[i + 1]) for i in range(len(pts) - 1))
    return ("line", dist, alpha)


def ring(cx, cy, r, alpha=1.0):
    return ("line", lambda u, v: abs(math.hypot(u - cx, v - cy) - r), alpha)


def box(cx, cy, hw, hh, r, alpha=1.0):
    return ("line", lambda u, v: abs(rounded_rect_dist(u, v, cx, cy, hw, hh, r)), alpha)


def dot(cx, cy, r, alpha=1.0):
    return ("fill", lambda u, v: math.hypot(u - cx, v - cy) - r, alpha)


def solid_box(cx, cy, hw, hh, r, alpha=1.0):
    return ("fill", lambda u, v: rounded_rect_dist(u, v, cx, cy, hw, hh, r), alpha)


def solid(points, alpha=1.0):
    return ("fill", lambda u, v: polygon_dist(u, v, points), alpha)


def line_icon(*parts, width=None):
    w = width or LINE_W

    def pixel(x, y, size):
        u, v = x / size, y / size
        a = 0.0
        for kind, dist, alpha in parts:
            d = dist(u, v) * size
            cover = smooth(w * size / 2, d) if kind == "line" else smooth(0, d)
            a = max(a, cover * alpha)
        return (255, 255, 255, int(round(255 * a)))
    return pixel


def bars(lit):
    parts = []
    for i, (x, h) in enumerate(((0.26, 0.26), (0.5, 0.44), (0.74, 0.62))):
        parts.append(solid_box(x, 0.84 - h / 2, 0.075, h / 2, 0.04, 1.0 if i < lit else 0.28))
    return line_icon(*parts)


def arrow_head(tip, toward, size=0.13, spread=32):
    ang = math.atan2(toward[1] - tip[1], toward[0] - tip[0])
    left = (tip[0] + size * math.cos(ang + math.radians(spread)), tip[1] + size * math.sin(ang + math.radians(spread)))
    right = (tip[0] + size * math.cos(ang - math.radians(spread)), tip[1] + size * math.sin(ang - math.radians(spread)))
    return path([left, tip, right])


UNDO = arc(0.5, 0.54, 0.27, 200, 470)
STAR4 = []
for i in range(8):
    r = 0.36 if i % 2 == 0 else 0.1
    a = math.radians(-90 + i * 45)
    STAR4.append((0.46 + r * math.cos(a), 0.54 + r * math.sin(a)))
SMALL4 = []
for i in range(8):
    r = 0.13 if i % 2 == 0 else 0.04
    a = math.radians(-90 + i * 45)
    SMALL4.append((0.78 + r * math.cos(a), 0.22 + r * math.sin(a)))


SETUP_ICONS = {
    "purist": line_icon(path([(0.3, 0.24), (0.7, 0.24), (0.86, 0.43), (0.5, 0.85), (0.14, 0.43)], True),
                        path([(0.14, 0.43), (0.86, 0.43)]), path([(0.42, 0.24), (0.36, 0.43), (0.5, 0.85)]),
                        path([(0.58, 0.24), (0.64, 0.43), (0.5, 0.85)])),
    "essentials": bars(1),
    "everything": bars(3),
    "none": line_icon(ring(0.5, 0.5, 0.34), path([(0.26, 0.74), (0.74, 0.26)])),
    "questions": line_icon(box(0.5, 0.44, 0.34, 0.25, 0.1), path([(0.34, 0.69), (0.28, 0.84), (0.48, 0.69)]),
                           dot(0.36, 0.44, 0.045), dot(0.5, 0.44, 0.045), dot(0.64, 0.44, 0.045)),
    "review": line_icon(path([(0.16, 0.34), (0.23, 0.41), (0.35, 0.27)]), path([(0.45, 0.34), (0.84, 0.34)]),
                        path([(0.16, 0.66), (0.23, 0.73), (0.35, 0.59)]), path([(0.45, 0.66), (0.84, 0.66)])),
    "undo": line_icon(path(UNDO), arrow_head(UNDO[0], UNDO[4])),
    "interface": line_icon(box(0.5, 0.5, 0.36, 0.3, 0.07), path([(0.14, 0.34), (0.86, 0.34)]),
                           path([(0.36, 0.34), (0.36, 0.8)])),
    "changes": line_icon(solid(STAR4), solid(SMALL4)),
    "next": line_icon(path([(0.18, 0.5), (0.8, 0.5)]), arrow_head((0.8, 0.5), (0.18, 0.5), 0.3, 42), width=0.13),
    "back": line_icon(path([(0.82, 0.5), (0.2, 0.5)]), arrow_head((0.2, 0.5), (0.82, 0.5), 0.3, 42), width=0.13),
}

SETUP_OUT = os.path.join(OUT, "Setup")
os.makedirs(SETUP_OUT, exist_ok=True)
for name, pixel in SETUP_ICONS.items():
    write_tga(os.path.join(SETUP_OUT, name + ".tga"), 64, pixel)


JOURNEYS_OUT = os.path.join(paths.ROOT, "NaowhForever_Journeys", "Media")
JOURNEY_ICONS = {
    "walk": line_icon(dot(0.5, 0.2, 0.085), path([(0.5, 0.34), (0.5, 0.58)]), path([(0.5, 0.58), (0.36, 0.86)]),
                      path([(0.5, 0.58), (0.64, 0.86)]), path([(0.32, 0.46), (0.68, 0.46)]), width=0.095),
    "ship": line_icon(path([(0.12, 0.64), (0.88, 0.64), (0.74, 0.86), (0.26, 0.86)], True),
                      path([(0.5, 0.12), (0.5, 0.64)]), path([(0.5, 0.18), (0.82, 0.54), (0.5, 0.54)], True),
                      width=0.07),
    "fly": line_icon(path([(0.1, 0.5), (0.9, 0.14), (0.62, 0.86), (0.46, 0.58)], True), path([(0.46, 0.58), (0.9, 0.14)]),
                     width=0.075),
    "tram": line_icon(path([(0.2, 0.22), (0.8, 0.22), (0.8, 0.72), (0.2, 0.72)], True), path([(0.2, 0.46), (0.8, 0.46)]),
                      path([(0.5, 0.22), (0.5, 0.08)]), dot(0.34, 0.86, 0.07), dot(0.66, 0.86, 0.07), width=0.075),
    "portal": line_icon(path(arc(0.5, 0.5, 0.36, 0, 360, 60) , True), path(arc(0.5, 0.5, 0.17, 0, 360, 40), True),
                        width=0.085),
    "hearth": line_icon(path([(0.1, 0.5), (0.5, 0.14), (0.9, 0.5)]), path([(0.22, 0.42), (0.22, 0.86), (0.78, 0.86), (0.78, 0.42)]),
                        path([(0.43, 0.86), (0.43, 0.62), (0.57, 0.62), (0.57, 0.86)]), width=0.075),
    "teleport": line_icon(solid(STAR4), solid(SMALL4)),
    "lift": line_icon(path([(0.5, 0.2), (0.5, 0.66)]), arrow_head((0.5, 0.12), (0.5, 0.5), 0.2, 40),
                      arrow_head((0.5, 0.74), (0.5, 0.36), 0.2, 40), path([(0.2, 0.9), (0.8, 0.9)]), width=0.085),
    "goal": line_icon(path([(0.26, 0.9), (0.26, 0.1)]), path([(0.26, 0.14), (0.82, 0.14), (0.66, 0.38), (0.82, 0.62), (0.26, 0.62)]),
                      width=0.085),
}
os.makedirs(JOURNEYS_OUT, exist_ok=True)
for name, pixel in JOURNEY_ICONS.items():
    write_tga(os.path.join(JOURNEYS_OUT, name + ".tga"), 64, pixel)


GLIMMER_OUT = os.path.join(paths.ROOT, "NaowhForever_QoL", "Media", "Glimmer")


def glimmer_glow(x, y, size):
    d = math.hypot(x - size / 2.0, y - size / 2.0) / (size / 2.0)
    a = max(0.0, 1.0 - d) ** 2
    return (255, 255, 255, int(round(255 * a)))


def glimmer_flare(x, y, size):
    u, v = (x - size / 2.0) / (size / 2.0), (y - size / 2.0) / (size / 2.0)
    arms = max(math.exp(-(v / 0.06) ** 2) * max(0.0, 1.0 - abs(u)) ** 1.5,
               math.exp(-(u / 0.06) ** 2) * max(0.0, 1.0 - abs(v)) ** 1.5)
    core = max(0.0, 1.0 - math.hypot(u, v) / 0.35) ** 2
    return (255, 255, 255, int(round(255 * min(1.0, arms + core))))


def glimmer_ring(x, y, size):
    d = math.hypot(x - size / 2.0, y - size / 2.0) / (size / 2.0)
    line = math.exp(-((d - 0.86) / 0.035) ** 2)
    halo = 0.35 * math.exp(-((d - 0.86) / 0.12) ** 2)
    return (255, 255, 255, int(round(255 * min(1.0, line + halo))))


def glimmer_beam(x, y, size):
    u = (x - size / 2.0) / (size / 2.0)
    rise = y / size
    a = math.exp(-(u / 0.32) ** 2) * rise ** 1.6
    return (255, 255, 255, int(round(255 * a)))


def glimmer_bracket(x, y, size):
    w, length = size * 0.09, size * 0.62
    top = smooth(w, y) if x < length else 0.0
    left = smooth(w, x) if y < length else 0.0
    return (255, 255, 255, int(round(255 * max(top, left))))


def glimmer_capsule_dist(x, y, size):
    # Distance outside an upright capsule, the shape a character stands in; negative inside.
    c, half_w, half_h = size / 2.0, size * 0.2, size * 0.45
    dy = max(abs(y - c) - (half_h - half_w), 0.0)
    return math.hypot(x - c, dy) - half_w


def glimmer_cutout(x, y, size):
    a = max(0.0, min(1.0, glimmer_capsule_dist(x, y, size) / (size * 0.04) + 0.5))
    return (255, 255, 255, int(round(255 * a)))


def glimmer_cutout_edge(x, y, size):
    return (255, 255, 255, int(round(255 * smooth(size * 0.012, abs(glimmer_capsule_dist(x, y, size))))))


GLIMMER_TEXTURES = {
    "glow": glimmer_glow, "flare": glimmer_flare, "ring": glimmer_ring,
    "beam": glimmer_beam, "bracket": glimmer_bracket,
    "cutout": glimmer_cutout, "cutout_edge": glimmer_cutout_edge,
}
os.makedirs(GLIMMER_OUT, exist_ok=True)
for name, pixel in GLIMMER_TEXTURES.items():
    write_tga(os.path.join(GLIMMER_OUT, name + ".tga"), 128, pixel)
