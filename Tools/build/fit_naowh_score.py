"""Fits the Naowh Score's constants (NaowhForever_BiS/NaowhScore/Data/Formula.lua) to a WoW Forever build's own
item table, read through wago.tools. Run by .github/workflows/daily-watch.yml when the watch
moves to a new build (and on manual runs, as a report), so the score follows the game.

The items the build lacks entirely come from --carry-from's table (wago.CARRY_FROM: hotfixed
items wago.tools has not recorded for the build yet), as the faction data reads them. Without
them each new build moved the constants twice: to a fit on its table before wago.tools had its
hotfixes (1.60.1.70532: 4,313 items), then to one with them (7,240 items).

How the game gives an item its stats (the columns read, in COLUMNS):

- ItemSparse: ItemLevel, OverallQualityID, InventoryType, Display_lang (to skip test items),
  and ten stats: StatModifier_bonusStat_N (the stat's type: 3 agility, 4 strength, 5
  intellect, 6 spirit, 7 stamina, 31 hit, 32 crit, 45 spell power, ...) with
  StatPercentEditor_N (its share of the item's budget, in 1/10000ths).
- RandPropPoints: by item level, the budget for each quality (Good_K, Superior_K, Epic_K)
  and slot kind K (0 head, chest, legs, two-hander; 1 shoulders, waist, feet, hands,
  trinket; 2 neck, wrist, finger, back, shield, held in off hand; 3 one-hander; 4 ranged).
  A stat's amount is its share x that budget / 10000, rounded: what the tooltip shows.
- ItemDamageOneHand: a one-hander's DPS by item level and quality (Quality_0 to Quality_2):
  how much a grey and a white weapon are worth next to a green.

The method, the same as the first fit's (which read Wowhead's database; CI reads only the
game's tables):

1. An item's stat budget: (sum (cost x stat)^1.5)^(1/1.5), primary stats costing 1 and every
   other stat's cost fitted (dodge, parry, block and expertise share one; so do resistances).
2. The budget against slot multiplier x (a_q x item level + c_q), one line per quality
   (green, blue, epic, the epic one through 0), by robust least squares (soft L1) on its log.
   Items of item level 5 to 100 with stats; the ones with a stat the model does not price
   (school spell damage, weapon skill, profession bonuses, slaying) are left out.
3. SLOTS: the slot multipliers (chest = 1), rounded to 2 places. Trinkets keep 0.7, a
   judgement call: their power is mostly in effects no stat shows.
4. SCALE and SHIFT: each quality's line in epic item levels (a_q / a_epic, c_q / a_epic),
   SCALE rounded to 2 places and SHIFT to 1. Grey and white carry no stats: the green line
   times their weapon DPS share of a green's (the mean over item levels 5 to 60). Legendary,
   artifact and heirloom count as epic.

It is deterministic: the same tables give the same constants. The report's 95% intervals
come from a bootstrap with a fixed seed, and only the report shows them.

Quality gates (any failing: the constants stay as they are, and the report says why): a full
epic set of level L scores L; the fitted model explains at least 90% of the items' budgets
(R^2 on the log, trinkets aside); the slots rank sensibly (head, chest and legs at least
shoulders, hands, waist and feet, which are at least neck, wrists, rings and back; a
two-hander within 0.1 of a main and off hand); and at item level 20, 40 and 60 grey < white
< green < blue < epic.

Change gate: Formula.lua is rewritten only when a slot weight moves 0.02 or more, or a
quality's worth at item level 10, 20, 30 or 60 (level x SCALE + SHIFT) moves 0.5 or more: a
levelling player's gear moves with SHIFT more than an item level 60's does.

Usage: python Tools/build/fit_naowh_score.py [--build 1.60.1.12345] [--carry-from 1.60.1.12344] [--cache DIR]
                                       [--report score.md] [--write] [--bootstrap 50]
"""
import argparse
import csv
import io
import math
import random
import re
import sys
import urllib.error
import urllib.parse
from collections import Counter
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402

ROOT = paths.ROOT
FORMULA = ROOT / "NaowhForever_BiS" / "NaowhScore" / "Data" / "Formula.lua"

STATS = 10   # ItemSparse's stat columns, _0 to _9
COLUMNS = {
    "ItemSparse": ("ID", "Display_lang", "ItemLevel", "OverallQualityID", "InventoryType")
    + tuple(f"StatModifier_bonusStat_{k}" for k in range(STATS))
    + tuple(f"StatPercentEditor_{k}" for k in range(STATS)),
    "RandPropPoints": ("ID",) + tuple(f"{q}_{k}" for q in ("Good", "Superior", "Epic") for k in range(5)),
    "ItemDamageOneHand": ("ItemLevel", "Quality_0", "Quality_1", "Quality_2"),
}

P = 1.5                    # the budget's norm
MIN_LEVEL, MAX_LEVEL = 5, 100
DPS_LEVELS = range(5, 61)  # item levels a grey or white weapon's DPS share is averaged over
MIN_ITEMS = 10             # a stat or slot needs this many items to be fitted
F_SCALE = 0.1              # soft L1's scale, on the log of the budget
SEED = 1                   # the report's bootstrap
TRINKET = 0.7              # not fitted
QUALITIES = (2, 3, 4)      # fitted: green, blue, epic
QUALITY_COLUMN = {2: "Good", 3: "Superior", 4: "Epic"}
NAMES = {0: "Grey", 1: "White", 2: "Green", 3: "Blue", 4: "Epic", 5: "Legendary", 6: "Artifact", 7: "Heirloom"}

PRIMARY = (3, 4, 5, 6, 7)   # agility, strength, intellect, spirit, stamina: cost 1
# The other stats the model prices, each type to its cost's name; the starting costs.
FREE_OF = {45: "spell power", 42: "spell damage", 41: "healing", 38: "attack power",
           39: "ranged attack power", 32: "crit", 31: "hit", 12: "defense", 13: "avoidance",
           14: "avoidance", 15: "avoidance", 37: "avoidance", 43: "mana per 5", 46: "health per 5",
           51: "resistance", 52: "resistance", 53: "resistance", 54: "resistance", 55: "resistance",
           56: "resistance", 47: "spell penetration", 50: "armor", 36: "haste"}
START = {"spell power": 0.6, "spell damage": 0.6, "healing": 0.4, "attack power": 0.4,
         "ranged attack power": 0.4, "crit": 1, "hit": 1, "defense": 1, "avoidance": 1,
         "mana per 5": 2, "health per 5": 2, "resistance": 0.8, "spell penetration": 1,
         "armor": 0.05, "haste": 1}
FREE = tuple(START)

# Item groups by inventory type: what the fit gives a multiplier.
GROUP_OF = {1: "head", 2: "neck", 3: "shoulder", 5: "chest", 20: "chest", 6: "waist", 7: "legs",
            8: "feet", 9: "wrist", 10: "hands", 11: "finger", 12: "trinket", 16: "back",
            13: "one-hand", 21: "one-hand", 22: "one-hand", 17: "two-hand", 14: "off hand",
            23: "off hand", 15: "ranged", 25: "ranged", 26: "ranged", 28: "ranged"}
GROUPS = ("head", "neck", "shoulder", "chest", "waist", "legs", "feet", "wrist", "hands", "finger",
          "trinket", "back", "one-hand", "two-hand", "off hand", "ranged")
CHEST = "chest"
# RandPropPoints' slot kind for each group.
KIND = {"head": 0, "chest": 0, "legs": 0, "two-hand": 0, "shoulder": 1, "waist": 1, "feet": 1,
        "hands": 1, "trinket": 1, "neck": 2, "wrist": 2, "finger": 2, "back": 2, "off hand": 2,
        "one-hand": 3, "ranged": 4}
# The score's gear slots (inventory slots) and the group whose multiplier each takes.
SLOT_GROUP = {1: "head", 2: "neck", 3: "shoulder", 5: "chest", 6: "waist", 7: "legs", 8: "feet",
              9: "wrist", 10: "hands", 11: "finger", 12: "finger", 15: "back", 16: "one-hand",
              17: "off hand", 18: "ranged"}
SLOT_ORDER = (1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18)
SLOT_NAMES = {1: "Head", 2: "Neck", 3: "Shoulders", 5: "Chest", 6: "Waist", 7: "Legs", 8: "Feet",
              9: "Wrists", 10: "Hands", 11: "Ring", 12: "Ring", 13: "Trinket", 14: "Trinket",
              15: "Back", 16: "Main hand", 17: "Off hand", 18: "Ranged"}
TEST_NAME = re.compile(r"^(Monster - |Test |OLD)|TEST|Deprecated|\[PH\]")

# The gates.
MIN_R2 = 0.90
TWO_HAND_GAP = 0.1
GATE_LEVELS = (20, 40, 60)
SLOT_MOVE = 0.02
WORTH_MOVE = 0.5
WORTH_LEVEL = 60
WORTH_LEVELS = (10, 20, 30, WORTH_LEVEL)   # the change gate's item levels
TOP = (1, 5, 7)            # head, chest, legs
MIDDLE = (3, 6, 8, 10)     # shoulders, waist, feet, hands
LOW = (2, 9, 11, 15)       # neck, wrists, rings, back
EPSILON = 1e-9


class Unreadable(Exception):
    """wago.tools does not have the table, or not its layout, for the build yet."""


def read_table(name, build, cache=None):
    """The table's rows for the build, hotfixes applied, each a dict of its columns. With cache,
    kept as cache/build/name.csv and read from there next time."""
    path = Path(cache) / build / f"{name}.csv" if cache else None
    if path and path.exists():
        text = path.read_text(encoding="utf-8")
    else:
        query = urllib.parse.urlencode({"build": build, "useHotfixes": "1"})
        text = wago.fetch(f"{wago.SITE}/db2/{name}/csv?{query}")
        if path:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8", newline="")
    rows = list(csv.DictReader(io.StringIO(text)))
    missing = [c for c in COLUMNS[name] if not rows or c not in rows[0]]
    if missing:
        raise Unreadable(f"wago.tools cannot read {name} for {build} yet (no {', '.join(missing[:3])})")
    return rows


def item_rows(build, carry=None, cache=None):
    """ItemSparse's rows for the build, and carry's for the items the build lacks entirely."""
    rows = read_table("ItemSparse", build, cache)
    if carry:
        have = {row["ID"] for row in rows}
        rows = rows + [row for row in read_table("ItemSparse", carry, cache) if row["ID"] not in have]
    return rows


def items_from(sparse, points):
    """The items the fit reads, from ItemSparse rows and RandPropPoints rows: [{id, group,
    quality, level, prim, free}], prim the sum of sign(x)|x|^P over its primary stats, free
    {cost name: amount}. And Counter of what was left out, by reason."""
    budget = {int(row["ID"]): row for row in points}
    found, skipped = [], Counter()
    for row in sparse:
        quality, level = int(row["OverallQualityID"]), int(row["ItemLevel"])
        group = GROUP_OF.get(int(row["InventoryType"]))
        if quality not in QUALITIES or group is None or not MIN_LEVEL <= level <= MAX_LEVEL:
            continue
        stats = [(int(row[f"StatModifier_bonusStat_{k}"]), int(row[f"StatPercentEditor_{k}"])) for k in range(STATS)]
        stats = [(stat, share) for stat, share in stats if stat >= 0 and share != 0]
        if not stats:
            continue
        if TEST_NAME.search(row["Display_lang"] or ""):
            skipped["a test item"] += 1
            continue
        if any(stat not in PRIMARY and stat not in FREE_OF for stat, _ in stats):
            skipped["a stat the model does not price"] += 1
            continue
        if level not in budget:
            skipped["no budget for its item level"] += 1
            continue
        points_ = float(budget[level][f"{QUALITY_COLUMN[quality]}_{KIND[group]}"])
        prim, free = 0.0, {}
        for stat, share in stats:
            amount = math.floor(share * points_ / 10000 + 0.5)
            if stat in PRIMARY:
                prim += math.copysign(abs(amount) ** P, amount)
            else:
                free[FREE_OF[stat]] = free.get(FREE_OF[stat], 0) + amount
        free = {k: v for k, v in free.items() if v}
        if prim == 0 and not free:
            continue
        found.append({"id": int(row["ID"]), "group": group, "quality": quality, "level": level,
                      "prim": prim, "free": free})
    # Too few items to price a stat or size a slot: those items are left out.
    while True:
        stat_count = Counter(k for item in found for k in item["free"])
        group_count = Counter(item["group"] for item in found)
        keep = [item for item in found if group_count[item["group"]] >= MIN_ITEMS
                and all(stat_count[k] >= MIN_ITEMS for k in item["free"])]
        if len(keep) == len(found):
            return found, skipped
        skipped["a stat or slot with too few items"] += len(found) - len(keep)
        found = keep


class Model:
    """budget = m_group x (a_q x level + c_q), with the stats' costs: theta is the log of each
    group's multiplier but the chest's, a_q for green, blue and epic, c_q for green and blue (the
    epic line goes through 0), and the log of each cost."""

    def __init__(self, items):
        self.items = items
        self.groups = [g for g in GROUPS if any(i["group"] == g for i in items)]
        if CHEST not in self.groups:
            raise ValueError("no chest items to measure the slots against")
        self.free = [k for k in FREE if any(k in i["free"] for i in items)]
        self.qualities = [q for q in QUALITIES if any(i["quality"] == q for i in items)]
        if 4 not in self.qualities:
            raise ValueError("no epic items to measure the qualities against")
        index = 0
        self.m_at = {}
        for g in self.groups:
            if g != CHEST:
                self.m_at[g] = index
                index += 1
        self.a_at = {q: index + n for n, q in enumerate(self.qualities)}
        index += len(self.qualities)
        self.c_at = {}
        for q in self.qualities:
            if q != 4:
                self.c_at[q] = index
                index += 1
        self.cost_at = {k: index + n for n, k in enumerate(self.free)}
        self.size = index + len(self.free)
        # Per item, what the residual needs, by index.
        self.rows = [(self.m_at.get(i["group"]), self.a_at[i["quality"]], self.c_at.get(i["quality"]),
                      float(i["level"]), i["prim"], [(self.cost_at[k], float(v)) for k, v in sorted(i["free"].items())])
                     for i in items]

    def start(self):
        theta = [0.0] * self.size
        for q, at in self.a_at.items():
            theta[at] = 0.5
        for k, at in self.cost_at.items():
            theta[at] = math.log(START[k])
        return theta

    def evaluate(self, theta, jacobian=True):
        """The log residuals (log budget - log prediction) and, with jacobian, each one's
        derivatives as [(index, value)]."""
        residuals, rows = [], []
        for m_at, a_at, c_at, level, prim, free in self.rows:
            s = prim
            terms = []
            for at, amount in free:
                x = math.exp(theta[at]) * amount
                term = math.copysign(abs(x) ** P, x)
                s += term
                terms.append((at, term))
            b = math.copysign(abs(s) ** (1 / P), s)
            line = theta[a_at] * level + (theta[c_at] if c_at is not None else 0.0)
            m = math.exp(theta[m_at]) if m_at is not None else 1.0
            pred = m * line
            residuals.append(math.log(max(b, 0.5)) - math.log(max(pred, 0.5)))
            if jacobian:
                row = []
                if b > 0.5:
                    row += [(at, term / s) for at, term in terms]
                if pred > 0.5:
                    if m_at is not None:
                        row.append((m_at, -1.0))
                    row.append((a_at, -level / line))
                    if c_at is not None:
                        row.append((c_at, -1.0 / line))
                rows.append(row)
        return residuals, rows


def robust(residuals, weights):
    """Soft L1 loss, as least squares with loss="soft_l1" sums it."""
    return sum(w * 2 * F_SCALE * F_SCALE * (math.sqrt(1 + (r / F_SCALE) ** 2) - 1)
               for r, w in zip(residuals, weights))


def solve(matrix, vector):
    """matrix x = vector, by Gaussian elimination with partial pivoting."""
    n = len(vector)
    a = [row[:] + [vector[i]] for i, row in enumerate(matrix)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(a[r][col]))
        if abs(a[pivot][col]) < 1e-300:
            raise ArithmeticError("singular system")
        a[col], a[pivot] = a[pivot], a[col]
        lead = a[col]
        for r in range(col + 1, n):
            factor = a[r][col] / lead[col]
            if factor:
                row = a[r]
                for c in range(col, n + 1):
                    row[c] -= factor * lead[c]
    x = [0.0] * n
    for r in range(n - 1, -1, -1):
        x[r] = (a[r][n] - sum(a[r][c] * x[c] for c in range(r + 1, n))) / a[r][r]
    return x


def least_squares(model, theta=None, weights=None, iterations=300):
    """Levenberg-Marquardt on the robust loss (reweighted each step). Returns theta."""
    theta = list(theta or model.start())
    weights = weights or [1.0] * len(model.rows)
    n = model.size
    residuals, rows = model.evaluate(theta)
    loss = robust(residuals, weights)
    damping = 1e-3
    for _ in range(iterations):
        matrix = [[0.0] * n for _ in range(n)]
        gradient = [0.0] * n
        for r, row, w in zip(residuals, rows, weights):
            if not w:
                continue
            w = w / math.sqrt(1 + (r / F_SCALE) ** 2)
            for j, v in row:
                gradient[j] -= w * v * r
                line = matrix[j]
                for k, u in row:
                    line[k] += w * v * u
        while True:
            damped = [line[:] for line in matrix]
            for j in range(n):
                damped[j][j] = matrix[j][j] * (1 + damping) + 1e-12
            step = solve(damped, gradient)
            trial = [t + s for t, s in zip(theta, step)]
            trial_residuals, _ = model.evaluate(trial, jacobian=False)
            trial_loss = robust(trial_residuals, weights)
            if trial_loss < loss:
                break
            damping *= 10
            if damping > 1e12:
                return theta
        done = loss - trial_loss <= 1e-12 * loss
        theta, loss = trial, trial_loss
        damping = max(damping / 3, 1e-12)
        residuals, rows = model.evaluate(theta)
        if done:
            break
    return theta


def rounded(value, places):
    """Half away from zero, as a person rounds (Python's round() rounds half to even)."""
    step = Decimal(1).scaleb(-places)
    return float(Decimal(repr(value)).quantize(step, rounding=ROUND_HALF_UP))


def dps_shares(damage):
    """A grey's and a white one-hander's DPS as a share of a green's, the mean over DPS_LEVELS."""
    by_level = {int(row["ItemLevel"]): row for row in damage}
    shares = {}
    for q in (0, 1):
        ratios = [float(by_level[level][f"Quality_{q}"]) / float(by_level[level]["Quality_2"])
                  for level in DPS_LEVELS if level in by_level and float(by_level[level]["Quality_2"]) > 0]
        if not ratios:
            raise ValueError("ItemDamageOneHand has no green DPS for item levels 5 to 60")
        shares[q] = sum(ratios) / len(ratios)
    return shares


def raw_constants(model, theta, shares):
    """The unrounded constants: {SLOTS, SCALE, SHIFT}, by slot and quality."""
    mult = {g: (math.exp(theta[model.m_at[g]]) if g != CHEST else 1.0) for g in model.groups}
    slots = {}
    for slot in SLOT_ORDER:
        if slot in (13, 14):
            slots[slot] = TRINKET
        else:
            group = SLOT_GROUP[slot]
            if group not in mult:
                raise ValueError(f"no {group} items to size the {SLOT_NAMES[slot].lower()} slot")
            slots[slot] = mult[group]
    a_epic = theta[model.a_at[4]]
    scale, shift = {4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0}, {4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0}
    for q in (2, 3):
        if q not in model.a_at:
            raise ValueError(f"no {NAMES[q].lower()} items to fit")
        scale[q] = theta[model.a_at[q]] / a_epic
        shift[q] = theta[model.c_at[q]] / a_epic
    for q in (0, 1):
        scale[q] = shares[q] * scale[2]
        shift[q] = shares[q] * shift[2]
    return {"SLOTS": slots, "SCALE": scale, "SHIFT": shift, "two-hand": mult.get("two-hand"), "mult": mult}


def publish(raw):
    """The constants as Formula.lua holds them: slots and SCALE to 2 places, SHIFT to 1."""
    return {"SLOTS": {s: rounded(v, 2) for s, v in raw["SLOTS"].items()},
            "SCALE": {q: rounded(v, 2) for q, v in raw["SCALE"].items()},
            "SHIFT": {q: rounded(v, 1) for q, v in raw["SHIFT"].items()}}


def worth(constants, quality, level):
    """What an item of the quality and level counts as: the item level of an epic."""
    return level * constants["SCALE"][quality] + constants["SHIFT"][quality]


def score(constants, gear):
    """The Naowh Score of gear {slot: (level, quality, two-handed)}, as Score.Of works it out."""
    slots = constants["SLOTS"]
    total = sum(slots[s] for s in SLOT_ORDER)
    result, two = 0.0, False
    for slot in SLOT_ORDER:
        if slot == 17 and two:
            continue
        weight = slots[slot]
        item = gear.get(slot)
        if slot == 16 and item and item[2]:
            two = True
            weight += slots[17]
        if item:
            result += weight * max(0.0, worth(constants, item[1], item[0]))
    return result / total


def r_squared(model, theta):
    """Share of the items' log budget spread the fitted model explains, trinkets aside; and the
    median error (the median of |log residual|, as a ratio less 1)."""
    residuals, _ = model.evaluate(theta, jacobian=False)
    picked = [n for n, item in enumerate(model.items) if item["group"] != "trinket"]
    logs = []
    for n in picked:
        _, _, _, _, prim, free = model.rows[n]
        s = prim + sum(math.copysign(abs(math.exp(theta[at]) * v) ** P, v) for at, v in free)
        logs.append(math.log(max(math.copysign(abs(s) ** (1 / P), s), 0.5)))
    res = [residuals[n] for n in picked]
    mean_log, mean_res = sum(logs) / len(logs), sum(res) / len(res)
    spread = sum((x - mean_log) ** 2 for x in logs)
    r2 = 1 - sum((x - mean_res) ** 2 for x in res) / spread if spread else 0.0
    errors = sorted(abs(x) for x in res)
    middle = len(errors) // 2
    median = errors[middle] if len(errors) % 2 else (errors[middle - 1] + errors[middle]) / 2
    return r2, math.exp(median) - 1


def gates(constants, fit):
    """The quality gates: [(name, passed, detail)]."""
    found = []
    worst = 0.0
    for level in (10, 26, 60, 78):
        full = {slot: (level, 4, False) for slot in SLOT_ORDER}
        two = dict(full)
        two[16] = (level, 4, True)
        two.pop(17)
        worst = max(worst, abs(score(constants, full) - level), abs(score(constants, two) - level))
    found.append(("A full epic set of level L scores L", worst < 1e-9,
                  f"at levels 10, 26, 60 and 78, a main and off hand or a two-hander: off by at most {worst:.1e}"))
    found.append((f"The fit explains at least {MIN_R2:.0%} of the items' budgets", fit["r2"] >= MIN_R2,
                  f"R^2 (log) {fit['r2']:.3f} over {fit['n'] - fit['trinkets']} items, trinkets aside"))
    slots = constants["SLOTS"]
    top, middle, low = (min(slots[s] for s in TOP), max(slots[s] for s in MIDDLE),
                        min(slots[s] for s in MIDDLE))
    lowest_high = max(slots[s] for s in LOW)
    ordered = top >= middle and low >= lowest_high
    found.append(("Slots rank sensibly", ordered,
                  f"head, chest, legs at least {top:g}; shoulders, waist, feet, hands {low:g} to {middle:g}; "
                  f"neck, wrists, rings, back at most {lowest_high:g}"))
    hands = slots[16] + slots[17]
    gap = abs(fit["two-hand"] - hands) if fit.get("two-hand") is not None else float("inf")
    found.append(("A two-hander is worth a main and off hand", gap <= TWO_HAND_GAP + EPSILON,
                  f"two-hander {fit['two-hand']:.3f}, main + off hand {hands:g}: {gap:.3f} apart (at most "
                  f"{TWO_HAND_GAP:g})" if fit.get("two-hand") is not None else "no two-handers to fit"))
    steps = []
    for level in GATE_LEVELS:
        values = [worth(constants, q, level) for q in (0, 1, 2, 3, 4)]
        if not all(a < b for a, b in zip(values, values[1:])):
            steps.append(f"{level}: " + " / ".join(f"{v:.1f}" for v in values))
    found.append(("Grey < white < green < blue < epic", not steps,
                  "at item level 20, 40 and 60" if not steps else "not at " + "; ".join(steps)))
    return found


def moves(old, new):
    """What moves enough to rewrite Formula.lua: [(what, before, after, decimal places)]; [] when
    nothing does."""
    found = []
    for slot in SLOT_ORDER:
        before, after = old["SLOTS"].get(slot), new["SLOTS"][slot]
        if before is None or abs(after - before) >= SLOT_MOVE - EPSILON:
            found.append((f"{SLOT_NAMES[slot]} (slot {slot}) weight", before, after, 2))
    for q in sorted(new["SCALE"]):
        if q not in old["SCALE"] or q not in old["SHIFT"]:
            found.append((f"{NAMES[q]} worth at item level {WORTH_LEVEL}", None, worth(new, q, WORTH_LEVEL), 1))
            continue
        # The item level it moves most at.
        level = max(WORTH_LEVELS, key=lambda lv: abs(worth(new, q, lv) - worth(old, q, lv)))
        before, after = worth(old, q, level), worth(new, q, level)
        if abs(after - before) >= WORTH_MOVE - EPSILON:
            found.append((f"{NAMES[q]} worth at item level {level}", before, after, 1))
    return found


TABLE = re.compile(r"Score\.(SLOTS|SCALE|SHIFT) = \{(.*?)\}", re.S)
ENTRY = re.compile(r"\[(\d+)\]\s*=\s*(-?\d+(?:\.\d+)?)")


def read_formula(text):
    """The constants a Formula.lua holds: {SLOTS, SCALE, SHIFT}; None when it has not all three."""
    found = {name: {int(k): float(v) for k, v in ENTRY.findall(body)} for name, body in TABLE.findall(text)}
    return found if all(found.get(name) for name in ("SLOTS", "SCALE", "SHIFT")) else None


def number(value):
    """0.55, 1, -3.2: no trailing zeros."""
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def entries(table, keys):
    return [f"[{k}] = {number(table[k])}" for k in keys]


def wrap(items, indent="    ", width=96):
    """Comma-separated items on lines of at most width characters."""
    lines, line = [], ""
    for item in items:
        piece = item + ","
        if line and len(indent) + len(line) + 1 + len(piece) > width:
            lines.append(indent + line)
            line = piece
        else:
            line = f"{line} {piece}" if line else piece
    if line:
        lines.append(indent + line)
    return lines


def render(constants, build, fit, carry=None):
    """Formula.lua's text, CRLF."""
    qualities = sorted(constants["SCALE"])
    source = f"{build}'s item table and {carry}'s hotfixes" if carry else f"{build}'s own item table"
    lines = [
        f"-- Formula.lua: Naowh Score constants from build {source} ({fit['n']:,} items).",
        "local ns = _G.NaowhForever",
        "",
        "local Score = {}",
        "ns.NaowhScore = Score",
        "",
        "Score.SLOTS = {",
    ]
    lines += wrap(entries(constants["SLOTS"], SLOT_ORDER))
    lines += [
        "}",
        "Score.SCALE = { " + ", ".join(entries(constants["SCALE"], qualities)) + " }",
        "Score.SHIFT = { " + ", ".join(entries(constants["SHIFT"], qualities)) + " }",
        "",
    ]
    return "\r\n".join(lines)


def bootstrap(model, theta, shares, samples):
    """95% intervals of each slot's weight and each quality's worth at WORTH_LEVEL, from samples
    refits on items drawn with replacement (seeded). {} when samples is 0."""
    if samples <= 0:
        return {}
    rng = random.Random(SEED)
    n = len(model.rows)
    draws = {}
    for _ in range(samples):
        weights = [0.0] * n
        for _ in range(n):
            weights[rng.randrange(n)] += 1.0
        fitted = least_squares(model, theta, weights, iterations=60)
        raw = raw_constants(model, fitted, shares)
        for slot in SLOT_ORDER:
            draws.setdefault(("slot", slot), []).append(raw["SLOTS"][slot])
        for q in range(4):
            draws.setdefault(("worth", q), []).append(worth(raw, q, WORTH_LEVEL))
    found = {}
    for key, values in draws.items():
        values.sort()
        found[key] = (values[int(0.025 * (len(values) - 1))], values[int(math.ceil(0.975 * (len(values) - 1)))])
    return found


def run(sparse, points, damage, samples=0):
    """The fit on the tables' rows: {raw, constants, fit, gates, intervals, skipped, costs}."""
    items, skipped = items_from(sparse, points)
    model = Model(items)
    theta = least_squares(model)
    shares = dps_shares(damage)
    raw = raw_constants(model, theta, shares)
    constants = publish(raw)
    r2, median = r_squared(model, theta)
    fit = {"n": len(items), "r2": r2, "median": median, "two-hand": raw["two-hand"],
           "trinkets": sum(1 for i in items if i["group"] == "trinket"),
           "by_quality": Counter(i["quality"] for i in items), "by_group": Counter(i["group"] for i in items),
           "shares": shares, "a_epic": theta[model.a_at[4]]}
    costs = {k: math.exp(theta[model.cost_at[k]]) for k in model.free}
    return {"raw": raw, "constants": constants, "fit": fit, "gates": gates(constants, fit),
            "intervals": bootstrap(model, theta, shares, samples), "skipped": skipped, "costs": costs}


def show(value, places=2):
    return "none" if value is None else f"{value:.{places}f}"


def quality_line(constants, quality):
    """"0.66 x - 5.3": what an item of the quality counts as, x its item level."""
    shift = constants["SHIFT"][quality]
    return f"{number(constants['SCALE'][quality])} x {'-' if shift < 0 else '+'} {number(abs(shift))}"


def report(build, result, old, changed, wrote, note=None):
    """The "Naowh Score" section of the watch's report, as Markdown lines."""
    lines = ["### Naowh Score", ""]
    if result is None:
        return lines + [f"> **Not refitted:** {note}. The constants stay as they are.", ""]
    new, raw, fit, intervals = result["constants"], result["raw"], result["fit"], result["intervals"]
    failed = [name for name, passed, _ in result["gates"] if not passed]
    if failed:
        verdict = (f"> **Constants kept:** the refit on {build} fails {len(failed)} quality "
                   f"gate{'s' if len(failed) > 1 else ''} ({'; '.join(failed)}), so Formula.lua stays as it is.")
    elif old is None:
        verdict = f"> **New:** there is no Formula.lua yet; the refit on {build} {'writes' if wrote else 'would write'} it."
    elif changed:
        did = "updates" if wrote else "would update"
        verdict = (f"> **Check before merging:** the refit on {build} {did} Formula.lua: "
                   + "; ".join(f"{what} {show(a, n)} &rarr; {show(b, n)}" for what, a, b, n in changed) + ".")
    else:
        verdict = (f"> **No change:** the refit on {build} agrees with the constants in use (no slot moves "
                   f"{SLOT_MOVE:g}, no quality's worth at item level {', '.join(map(str, WORTH_LEVELS[:-1]))} "
                   f"or {WORTH_LEVELS[-1]} moves {WORTH_MOVE:g}).")
    by_q = fit["by_quality"]
    lines += [verdict, "",
              "| | |", "|---|---|",
              f"| **Items** | {fit['n']:,} with stats, item levels {MIN_LEVEL} to {MAX_LEVEL}: {by_q[2]:,} green, "
              f"{by_q[3]:,} blue, {by_q[4]:,} epic |",
              f"| **Fit** | R^2 (log) {fit['r2']:.3f}, median error {fit['median']:.1%} (trinkets aside) |",
              f"| **Grey and white** | {fit['shares'][0]:.3f} and {fit['shares'][1]:.3f} of a green's weapon DPS |", ""]
    if result["skipped"]:
        lines += ["Left out: " + ", ".join(f"{n} with {why}" for why, n in sorted(result["skipped"].items())) + ".", ""]

    lines += ["| Slot | In use | Fit | 95% interval |", "|---|---|---|---|"]
    for slot in SLOT_ORDER:
        if slot == 12 or slot == 14:
            continue
        span = intervals.get(("slot", slot))
        cell = "fixed" if slot == 13 else (f"{span[0]:.3f} to {span[1]:.3f}" if span else "")
        lines.append(f"| {SLOT_NAMES[slot]}{'s' if slot in (11, 13) else ''} | {show(old['SLOTS'].get(slot)) if old else 'none'} "
                     f"| {show(new['SLOTS'][slot])} ({raw['SLOTS'][slot]:.3f}) | {cell} |")
    lines += ["", f"| Quality | In use | Fit | Worth at {WORTH_LEVEL}: in use | Fit | 95% interval |",
              "|---|---|---|---|---|---|"]
    for q in range(5):
        span = intervals.get(("worth", q))
        was = old and q in old["SCALE"] and q in old["SHIFT"]
        lines.append(f"| {NAMES[q]} | {quality_line(old, q) if was else 'none'} | {quality_line(new, q)} "
                     f"| {f'{worth(old, q, WORTH_LEVEL):.1f}' if was else 'none'} "
                     f"| {worth(new, q, WORTH_LEVEL):.1f} ({worth(raw, q, WORTH_LEVEL):.2f}) "
                     f"| {f'{span[0]:.1f} to {span[1]:.1f}' if span else ''} |")
    lines += ["", "Fit: the rounded constants, the unrounded ones in brackets; the intervals are the "
              "unrounded ones'. Legendary, artifact and heirloom count as epic.", "", "**Gates**", ""]
    for name, passed, detail in result["gates"]:
        lines.append(f"- {'Passed' if passed else '**Failed**'}: {name} ({detail}).")
    lines += ["", "<details><summary>What each stat costs, in primary stat points</summary>", "",
              "| Stat | Cost |", "|---|---|"]
    lines += [f"| {k} | {v:.3f} |" for k, v in result["costs"].items()]
    lines += ["", "</details>", ""]
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--build", default=wago.BUILD, help="the Forever build to fit (default: wago.BUILD)")
    parser.add_argument("--carry-from", default=wago.CARRY_FROM,
                        help="a build whose items fill in the ones --build lacks (default: wago.CARRY_FROM)")
    parser.add_argument("--cache", help="keep the tables here, and read them from here next time")
    parser.add_argument("--report", help="write the report here instead of to stdout")
    parser.add_argument("--write", action="store_true",
                        help="rewrite NaowhForever_BiS/NaowhScore/Data/Formula.lua when the constants move enough and the gates pass")
    parser.add_argument("--bootstrap", type=int, default=50, help="refits for the report's intervals (0: none)")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+\.\d+", args.build):
        sys.exit(f"A build reads like 1.60.1.12345, not {args.build!r}")

    text = FORMULA.read_bytes().decode("utf-8") if FORMULA.exists() else ""
    old = read_formula(text)
    result, changed, wrote, note = None, [], False, None
    try:
        tables = [item_rows(args.build, args.carry_from, args.cache)]
        tables += [read_table(name, args.build, args.cache) for name in ("RandPropPoints", "ItemDamageOneHand")]
        result = run(*tables, samples=args.bootstrap)
    except Unreadable as e:
        note = str(e)
    except (urllib.error.URLError, TimeoutError) as e:
        note = f"wago.tools did not answer ({e})"
    if result:
        passed = all(passed for _, passed, _ in result["gates"])
        changed = moves(old, result["constants"]) if old else [("Formula.lua", None, None, 0)]
        if args.write and passed and changed:
            FORMULA.parent.mkdir(parents=True, exist_ok=True)
            FORMULA.write_bytes(render(result["constants"], args.build, result["fit"], args.carry_from).encode("ascii"))
            wrote = True
    lines = report(args.build, result, old, changed, wrote, note)
    out = "\n".join(lines) + "\n"
    if args.report:
        Path(args.report).write_text(out, encoding="utf-8")
    else:
        print(out)


if __name__ == "__main__":
    main()
