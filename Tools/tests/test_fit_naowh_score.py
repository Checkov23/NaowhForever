"""Tests for Tools/build/fit_naowh_score.py: the fit on a made-up item table whose answer is known,
the quality gates, the change gate, rounding and the Lua it writes. Offline. From the repo
root:

    python -m unittest discover -s Tools/tests
"""
import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import fit_naowh_score as fit  # noqa: E402

# The made-up game: each slot kind's share of the budget, and each quality's budget line.
KINDS = (1, 0.75, 0.55, 0.42, 0.31)
LINES = {"Good": (0.5, -4.0), "Superior": (0.62, -2.0), "Epic": (0.78, 0.0)}
QUALITY = {2: "Good", 3: "Superior", 4: "Epic"}
INVENTORY = {"head": 1, "neck": 2, "shoulder": 3, "chest": 5, "waist": 6, "legs": 7, "feet": 8, "wrist": 9,
             "hands": 10, "finger": 11, "trinket": 12, "back": 16, "one-hand": 13, "two-hand": 17,
             "off hand": 14, "ranged": 15}
CRIT_COST = 0.8
SCALE = 100   # the budget points are large, so rounding each stat to a whole number barely shows


def points_rows():
    """RandPropPoints: budget points by item level, quality and slot kind."""
    rows = []
    for level in range(1, 101):
        row = {"ID": str(level)}
        for name, (a, c) in LINES.items():
            for kind, share in enumerate(KINDS):
                row[f"{name}_{kind}"] = repr(SCALE * share * max(a * level + c, 0.5))
        rows.append(row)
    return rows


def damage_rows():
    """ItemDamageOneHand: a grey 0.6 of a green's DPS, a white 0.9."""
    return [{"ItemLevel": str(level), "Quality_0": repr(0.6 * level), "Quality_1": repr(0.9 * level),
             "Quality_2": repr(float(level))} for level in range(1, 101)]


def item(item_id, inventory, quality, level, stats, name="Thing"):
    row = {"ID": str(item_id), "Display_lang": name, "ItemLevel": str(level), "OverallQualityID": str(quality),
           "InventoryType": str(inventory)}
    for k in range(fit.STATS):
        stat, share = stats[k] if k < len(stats) else (-1, 0)
        row[f"StatModifier_bonusStat_{k}"] = str(stat)
        row[f"StatPercentEditor_{k}"] = str(share)
    return row


def sparse_rows():
    """Every group, quality and some levels: stamina alone, or stamina and crit sharing the
    budget (crit costing CRIT_COST), so the budget is the game's points either way."""
    rows, n = [], 0
    for group, inventory in INVENTORY.items():
        for quality in QUALITY:
            for level in range(12, 92, 8):
                n += 1
                if n % 3:
                    stats = [(7, 10000)]
                else:
                    # sta^1.5 + (cost x crit)^1.5 = budget^1.5, half the budget's power each.
                    half = 0.5 ** (1 / 1.5)
                    stats = [(7, round(10000 * half)), (32, round(10000 * half / CRIT_COST))]
                rows.append(item(n, inventory, quality, level, stats))
    rows.append(item(n + 1, 5, 4, 60, [(7, 10000)], name="Test Chest"))           # a test item
    rows.append(item(n + 2, 5, 4, 60, [(7, 5000), (85, 5000)]))                    # fire spell damage
    rows.append(item(n + 3, 5, 1, 60, [(7, 10000)]))                               # white: not fitted
    return rows


def run():
    return fit.run(sparse_rows(), points_rows(), damage_rows())


CURRENT = {"SLOTS": {1: 1, 2: 0.55, 3: 0.75, 5: 1, 6: 0.75, 7: 1, 8: 0.75, 9: 0.55, 10: 0.75, 11: 0.55, 12: 0.55,
                     13: 0.7, 14: 0.7, 15: 0.55, 16: 0.42, 17: 0.55, 18: 0.31},
           "SCALE": {0: 0.4, 1: 0.59, 2: 0.66, 3: 0.82, 4: 1, 5: 1, 6: 1, 7: 1},
           "SHIFT": {0: -3.2, 1: -4.7, 2: -5.3, 3: -2.9, 4: 0, 5: 0, 6: 0, 7: 0}}


def copy(constants):
    return {name: dict(table) for name, table in constants.items()}


class Fit(unittest.TestCase):
    """The fit finds the made-up game's own numbers."""

    @classmethod
    def setUpClass(cls):
        cls.result = run()

    def test_slots(self):
        slots = self.result["constants"]["SLOTS"]
        self.assertEqual(slots, {1: 1, 2: 0.55, 3: 0.75, 5: 1, 6: 0.75, 7: 1, 8: 0.75, 9: 0.55, 10: 0.75,
                                 11: 0.55, 12: 0.55, 13: 0.7, 14: 0.7, 15: 0.55, 16: 0.42, 17: 0.55, 18: 0.31})
        self.assertAlmostEqual(self.result["raw"]["two-hand"], 1, places=2, msg="a two-hander is a chest's kind")

    def test_qualities(self):
        c = self.result["constants"]
        # Green 0.5 / 0.78 = 0.641, -4 / 0.78 = -5.13; blue 0.795, -2.56; grey and white the
        # green line times their DPS share.
        self.assertEqual((c["SCALE"][2], c["SHIFT"][2]), (0.64, -5.1))
        self.assertEqual((c["SCALE"][3], c["SHIFT"][3]), (0.79, -2.6))
        self.assertEqual((c["SCALE"][0], c["SHIFT"][0]), (0.38, -3.1))
        self.assertEqual((c["SCALE"][1], c["SHIFT"][1]), (0.58, -4.6))
        for q in (4, 5, 6, 7):
            self.assertEqual((c["SCALE"][q], c["SHIFT"][q]), (1, 0), "legendary and up count as epic")

    def test_costs_and_quality(self):
        self.assertAlmostEqual(self.result["costs"]["crit"], CRIT_COST, places=2)
        self.assertGreater(self.result["fit"]["r2"], 0.999)
        self.assertTrue(all(passed for _, passed, _ in self.result["gates"]), self.result["gates"])

    def test_left_out(self):
        skipped = self.result["skipped"]
        self.assertEqual(skipped["a test item"], 1)
        self.assertEqual(skipped["a stat the model does not price"], 1)
        self.assertEqual(self.result["fit"]["n"], len(INVENTORY) * 3 * 10, "whites are not fitted")

    def test_deterministic(self):
        again = run()
        self.assertEqual(again["constants"], self.result["constants"])
        self.assertEqual(again["raw"]["SLOTS"], self.result["raw"]["SLOTS"])

    def test_bootstrap_seeded(self):
        sparse, points = sparse_rows(), points_rows()
        a = fit.run(sparse, points, damage_rows(), samples=3)["intervals"]
        b = fit.run(sparse, points, damage_rows(), samples=3)["intervals"]
        self.assertEqual(a, b)
        low, high = a[("slot", 3)]
        self.assertLessEqual(low, high)


class Rounding(unittest.TestCase):
    def test_half_away_from_zero(self):
        self.assertEqual(fit.rounded(0.125, 2), 0.13)
        self.assertEqual(fit.rounded(0.665, 2), 0.67)
        self.assertEqual(fit.rounded(-5.25, 1), -5.3)
        self.assertEqual(fit.rounded(-0.04, 1), 0.0)

    def test_publish(self):
        raw = {"SLOTS": {1: 1.0049, 3: 0.7651}, "SCALE": {2: 0.6649, 3: 0.8251}, "SHIFT": {2: -5.249, 3: -2.951}}
        self.assertEqual(fit.publish(raw), {"SLOTS": {1: 1.0, 3: 0.77}, "SCALE": {2: 0.66, 3: 0.83},
                                            "SHIFT": {2: -5.2, 3: -3.0}})

    def test_number(self):
        self.assertEqual([fit.number(v) for v in (1.0, 0.55, 0.4, -3.2, 0.0, -0.0)], ["1", "0.55", "0.4", "-3.2", "0", "0"])


class Gates(unittest.TestCase):
    FIT = {"r2": 0.95, "n": 100, "trinkets": 5, "two-hand": 0.97}

    def failed(self, constants, **fit_values):
        values = dict(self.FIT, **fit_values)
        return [name for name, passed, _ in fit.gates(constants, values) if not passed]

    def test_current_constants_pass(self):
        self.assertEqual(self.failed(CURRENT), [])

    def test_r2(self):
        self.assertEqual(self.failed(CURRENT, r2=0.89), ["The fit explains at least 90% of the items' budgets"])

    def test_slot_order(self):
        c = copy(CURRENT)
        c["SLOTS"][3] = 1.05   # shoulders over the head
        self.assertEqual(self.failed(c), ["Slots rank sensibly"])
        c = copy(CURRENT)
        c["SLOTS"][15] = 0.8   # the back over the waist
        self.assertEqual(self.failed(c), ["Slots rank sensibly"])

    def test_two_hand(self):
        self.assertEqual(self.failed(CURRENT, **{"two-hand": 0.88}), [])   # main + off hand 0.97
        self.assertEqual(self.failed(CURRENT, **{"two-hand": 0.8}), ["A two-hander is worth a main and off hand"])

    def test_monotonic(self):
        c = copy(CURRENT)
        c["SCALE"][1], c["SHIFT"][1] = 0.66, -5.3   # white as green
        self.assertEqual(self.failed(c), ["Grey < white < green < blue < epic"])

    def test_full_epic_set(self):
        # Epics are their own level by construction: off only when the epic line is.
        c = copy(CURRENT)
        c["SHIFT"][4] = 0.5
        self.assertIn("A full epic set of level L scores L", self.failed(c))


class ChangeGate(unittest.TestCase):
    def test_small_moves_change_nothing(self):
        new = copy(CURRENT)
        new["SLOTS"][3] = 0.76
        new["SCALE"][3], new["SHIFT"][3] = 0.81, -2.4   # 46.2 at 60, was 46.3
        self.assertEqual(fit.moves(CURRENT, new), [])

    def test_a_slot_moving(self):
        new = copy(CURRENT)
        new["SLOTS"][3] = 0.77
        self.assertEqual(fit.moves(CURRENT, new), [("Shoulders (slot 3) weight", 0.75, 0.77, 2)])

    def test_a_quality_moving(self):
        new = copy(CURRENT)
        new["SCALE"][2], new["SHIFT"][2] = 0.67, -5.4   # 34.8 at 60, was 34.3
        moved = fit.moves(CURRENT, new)
        self.assertEqual([what for what, _, _, _ in moved], ["Green worth at item level 60"])
        self.assertAlmostEqual(moved[0][2] - moved[0][1], 0.5)

    def test_a_shift_moving_low_levels(self):
        new = copy(CURRENT)
        new["SCALE"][3], new["SHIFT"][3] = 0.84, -4.0   # 46.4 at 60, was 46.3; 4.4 at 10, was 5.3
        moved = fit.moves(CURRENT, new)
        self.assertEqual([what for what, _, _, _ in moved], ["Blue worth at item level 10"])
        self.assertAlmostEqual(moved[0][2] - moved[0][1], -0.9)


class Lua(unittest.TestCase):
    INFO = {"n": 4304, "r2": 0.961, "median": 0.035}

    def test_format(self):
        text = fit.render(CURRENT, "1.60.1.70178", self.INFO)
        raw = text.encode("ascii")   # ASCII only
        self.assertNotIn(b"\n", raw.replace(b"\r\n", b""), "CRLF line endings only")
        self.assertTrue(text.endswith("\r\n"))
        self.assertIn("build 1.60.1.70178's own item table", text)
        self.assertIn("4,304 items", text)
        self.assertIn("local Score = {}\r\nns.NaowhScore = Score\r\n", text)
        self.assertIn("Score.SCALE = { [0] = 0.4, [1] = 0.59, [2] = 0.66, [3] = 0.82, [4] = 1,", text)
        self.assertIn("Score.SHIFT = { [0] = -3.2, [1] = -4.7, [2] = -5.3, [3] = -2.9, [4] = 0,", text)
        self.assertTrue(all(len(line) <= 100 for line in text.split("\r\n")))
        self.assertEqual(fit.read_formula(text), {k: {kk: float(v) for kk, v in t.items()} for k, t in CURRENT.items()})

    def test_format_carried(self):
        text = fit.render(CURRENT, "1.60.1.70790", self.INFO, "1.60.1.70532")
        self.assertIn("from build 1.60.1.70790's item table and 1.60.1.70532's hotfixes (4,304 items).", text)

    def test_read_formula_incomplete(self):
        self.assertIsNone(fit.read_formula("Score.SLOTS = { [1] = 1 }"))


class Main(unittest.TestCase):
    """The command line: writes Formula.lua only when the constants move, and reports."""

    def setUp(self):
        self.saved = (fit.FORMULA, fit.read_table)
        self.tmp = tempfile.TemporaryDirectory()
        fit.FORMULA = Path(self.tmp.name) / "Data" / "Formula.lua"
        self.report = Path(self.tmp.name) / "score.md"
        tables = {"ItemSparse": sparse_rows(), "RandPropPoints": points_rows(), "ItemDamageOneHand": damage_rows()}
        fit.read_table = lambda name, build, cache=None: tables[name]

    def tearDown(self):
        fit.FORMULA, fit.read_table = self.saved
        self.tmp.cleanup()

    def main(self, *args):
        saved = sys.argv
        sys.argv = ["fit_naowh_score.py", "--build", "1.60.1.99999", "--bootstrap", "0",
                    "--report", str(self.report), *args]
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                fit.main()
        finally:
            sys.argv = saved
        return self.report.read_text(encoding="utf-8")

    def test_writes_then_leaves_alone(self):
        fit.FORMULA.parent.mkdir(parents=True)
        fit.FORMULA.write_bytes(fit.render(CURRENT, "1.60.1.1", {"n": 1, "r2": 1, "median": 0}).encode("ascii"))
        text = self.main("--write")
        self.assertIn("> **Check before merging:** the refit on 1.60.1.99999 updates Formula.lua", text)
        self.assertIn("Blue worth at item level 60", text)
        written = fit.FORMULA.read_bytes()
        self.assertIn(b"build 1.60.1.99999's", written)
        text = self.main("--write")
        self.assertIn("> **No change:**", text)
        self.assertEqual(fit.FORMULA.read_bytes(), written, "untouched when nothing moves")

    def test_report_only_without_write(self):
        fit.FORMULA.parent.mkdir(parents=True)
        before = fit.render(CURRENT, "1.60.1.1", {"n": 1, "r2": 1, "median": 0}).encode("ascii")
        fit.FORMULA.write_bytes(before)
        self.assertIn("would update Formula.lua", self.main())
        self.assertEqual(fit.FORMULA.read_bytes(), before)

    def test_failed_gate_keeps_constants(self):
        fit.FORMULA.parent.mkdir(parents=True)
        before = fit.render(CURRENT, "1.60.1.1", {"n": 1, "r2": 1, "median": 0}).encode("ascii")
        fit.FORMULA.write_bytes(before)
        saved = fit.MIN_R2
        fit.MIN_R2 = 1.5
        try:
            text = self.main("--write")
        finally:
            fit.MIN_R2 = saved
        self.assertIn("> **Constants kept:**", text)
        self.assertEqual(fit.FORMULA.read_bytes(), before)

    def test_unreadable(self):
        def unreadable(name, build, cache=None):
            raise fit.Unreadable(f"wago.tools cannot read {name} for {build} yet (no ItemLevel)")
        fit.read_table = unreadable
        text = self.main("--write")
        self.assertIn("> **Not refitted:** wago.tools cannot read ItemSparse for 1.60.1.99999 yet", text)
        self.assertFalse(fit.FORMULA.exists())


class ItemRows(unittest.TestCase):
    """The build's items, and the carried build's for the ones it lacks entirely."""

    def setUp(self):
        self.saved = fit.read_table
        tables = {"new": [{"ID": "1", "ItemLevel": "42"}],
                  "old": [{"ID": "1", "ItemLevel": "40"}, {"ID": "2", "ItemLevel": "30"}]}
        fit.read_table = lambda name, build, cache=None: tables[build]

    def tearDown(self):
        fit.read_table = self.saved

    def test_carried_fills_in_the_build_wins(self):
        rows = fit.item_rows("new", "old")
        self.assertEqual([(r["ID"], r["ItemLevel"]) for r in rows], [("1", "42"), ("2", "30")])

    def test_nothing_carried(self):
        self.assertEqual(fit.item_rows("new"), [{"ID": "1", "ItemLevel": "42"}])


class ReadTable(unittest.TestCase):
    def test_cache_and_columns(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "1.2.3.4" / "ItemDamageOneHand.csv"
            path.parent.mkdir()
            path.write_text("ItemLevel,Quality_0,Quality_1,Quality_2\r\n1,1,2,3\r\n", encoding="utf-8")
            self.assertEqual(fit.read_table("ItemDamageOneHand", "1.2.3.4", tmp)[0]["Quality_2"], "3")
            path.write_text("ItemLevel,Field_1_60_1\r\n1,1\r\n", encoding="utf-8")
            with self.assertRaises(fit.Unreadable):
                fit.read_table("ItemDamageOneHand", "1.2.3.4", tmp)


if __name__ == "__main__":
    unittest.main()
