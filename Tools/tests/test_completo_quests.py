"""Tests for Tools/build/completo_quests.py's hand-kept corrections (Tools/data/completo_fixes.json):
a quest's add joins the quests before it, its drop leaves them and its explicit groups, a fix naming
a quest the data lacks is skipped with a warning, an add or drop that changes nothing is warned of,
and a key starting with _ is a note; how it mends the race masks: a quest for both sides that names
only the High Order Skyborne is both Skyborne's, and other masks stay as given; where ForeverChanges
and the catalog agree: a class, level or side both give is taken, one alone is not, nor what both
write for a value they lack (side 3, level 0), and the build takes them for the quests ForeverChanges
lists, in the zone it files them under, before it writes their rows, reporting the ones Quests.lua did
not have yet; a quest ForeverChanges does not list kept when the fixes name it, warned of once it lists
it; and the gating it writes: the camping quests of one name and the hand-kept groups are
exclusive, a quest in one group at most, and the breadcrumbs, professions and camp recipes come from
the fixes, an entry naming a quest the data lacks skipped with a warning. Offline. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import completo_quests  # noqa: E402


class Corrected(unittest.TestCase):
    def setUp(self):
        self.known = {i: (40, {"name": str(i)})
                      for i in (19, 20, 98386, 98387, 92744, 92742, 94013, 94979, 94978, 94007)}

    def corrected(self, before, requires, fixes):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            out = completo_quests.corrected(before, requires, fixes, self.known)
        return out, err.getvalue()

    def test_add_and_drop(self):
        before = {19: [20, 98386, 98387]}
        fixes = {"19": {"drop": [98386]}, "92744": {"add": [92742]}}
        (after, _), warnings = self.corrected(before, {}, fixes)
        self.assertEqual(after, {19: [20, 98387], 92744: [92742]})
        self.assertEqual(before, {19: [20, 98386, 98387]})
        self.assertEqual(warnings, "")

    def test_drop_leaves_explicit_groups(self):
        before = {94013: [94007, 94978, 94979]}
        requires = {"94013": {"quests": [94979, 94007, 94978], "groups": [94979, [94007, 94978]]}}
        (after, fixed), warnings = self.corrected(before, requires, {"94013": {"drop": [94979, 94978]}})
        self.assertEqual(after, {94013: [94007]})
        self.assertEqual(fixed["94013"]["groups"], [94007])
        self.assertEqual(requires["94013"]["groups"], [94979, [94007, 94978]])
        self.assertEqual(completo_quests.requirements(after, self.known, fixed)[94013], [94007])
        self.assertEqual(warnings, "")

    def test_a_quest_left_with_nothing_has_no_requirement(self):
        (after, _), _ = self.corrected({19: [98386]}, {}, {"19": {"drop": [98386]}})
        self.assertEqual(after, {})

    def test_unknown_quest_warns_and_skips(self):
        fixes = {"1": {"add": [20]}, "19": {"add": [98387, 2]}, "92744": {"drop": [3]}}
        (after, _), warnings = self.corrected({19: [20]}, {}, fixes)
        self.assertEqual(after, {19: [20]})
        lines = warnings.splitlines()
        self.assertEqual(len(lines), 3)
        self.assertIn("requires 1 names quest 1,", lines[0])
        self.assertIn("requires 19 names quest 2,", lines[1])
        self.assertIn("requires 92744 names quest 3,", lines[2])
        self.assertTrue(all(line.endswith("skipped") for line in lines))

    def test_add_present_or_drop_absent_warns(self):
        (after, _), warnings = self.corrected({19: [20, 98386]}, {}, {"19": {"add": [20, 98387], "drop": [92742]}})
        self.assertEqual(after, {19: [20, 98386, 98387]})
        self.assertIn("requires 19 adds 20, which it needs already", warnings)
        self.assertIn("requires 19 drops 92742, which it does not need", warnings)

    def test_notes_are_ignored(self):
        (after, _), warnings = self.corrected({19: [20, 98386]}, {}, {"_note": "x", "19": {"drop": [98386]}})
        self.assertEqual(after, {19: [20]})
        self.assertEqual(warnings, "")


class Races(unittest.TestCase):
    ALLIANCE_BUT_HUMAN, TAUREN = 4294967372, 1 << 5

    def test_both_skyborne(self):
        both = completo_quests.HIGH_ORDER | completo_quests.WINDSHAPER
        self.assertEqual(completo_quests.races(completo_quests.HIGH_ORDER, 3), both)
        self.assertEqual(completo_quests.races(completo_quests.HIGH_ORDER, 1), completo_quests.HIGH_ORDER)

    def test_other_masks_stay_as_the_sources_give_them(self):
        self.assertEqual(completo_quests.races(self.ALLIANCE_BUT_HUMAN, 1), self.ALLIANCE_BUT_HUMAN)
        self.assertEqual(completo_quests.races(self.TAUREN, 2), self.TAUREN)
        self.assertEqual(completo_quests.races(0, 1), 0)


class Agreed(unittest.TestCase):
    # Armaments of War, Warrior's: the zone page gives it no class.
    OURS = {"id": 8316, "name": "Armaments of War", "level": 60, "reqlevel": 58, "side": 3, "reqclass": 0}

    def test_what_both_say_is_taken(self):
        listed = {"quests": {"8316": {"level": 60, "reqlevel": 58, "side": 3, "reqclass": 1}}}
        catalog = {"8316": {"level": 60, "reqlevel": 58, "side": 3, "reqclass": 1}}
        self.assertEqual(completo_quests.agreed(self.OURS, listed, catalog), dict(self.OURS, reqclass=1))

    def test_one_source_alone_is_not(self):
        listed = {"quests": {"8316": {"level": 59, "reqlevel": 50, "side": 3, "reqclass": 1}}}
        catalog = {"8316": {"level": 60, "reqlevel": 55, "side": 3, "reqclass": 0}}
        self.assertEqual(completo_quests.agreed(self.OURS, listed, catalog), self.OURS)
        self.assertEqual(completo_quests.agreed(self.OURS, listed, {}), self.OURS)

    def test_what_both_write_for_a_missing_value_is_not(self):
        # Crocs of the Sky: the Alliance's giver, no race mask, so both sources say both sides.
        ours = {"id": 98072, "name": "Crocs of the Sky", "level": 27, "reqlevel": 19, "side": 1, "reqclass": 4}
        missing = {"level": 0, "reqlevel": 0, "side": 3, "reqclass": 0}
        self.assertEqual(completo_quests.agreed(ours, {"quests": {"98072": missing}}, {"98072": missing}), ours)


class AgreedWritten(unittest.TestCase):
    def write(self):
        quests = {
            98072: {"name": "Crocs of the Sky", "level": 27, "reqlevel": 19, "side": 1, "reqclass": 0},
            8316: {"name": "Armaments of War", "level": 60, "reqlevel": 58, "side": 3, "reqclass": 0},
            1: {"name": "Not Listed", "level": 10, "reqlevel": 5, "side": 1, "reqclass": 0},
        }
        zones = {"11": {"name": "Wetlands", "quests": [dict(q, id=i) for i, q in quests.items()]},
                 "40": {"name": "Westfall", "quests": []}}
        listed = {"quests": {"98072": dict(quests[98072], side=3, category=["zone", 11]),
                             "8316": dict(quests[8316], side=2, reqclass=1, category=["zone", 40])},
                  "starts": {}}
        catalog = {"98072": dict(quests[98072], side=3, zone=11, zone_name="Wetlands", start=None, repeatable=False),
                   "8316": dict(quests[8316], side=2, reqclass=1, zone=11, zone_name="Wetlands", start=None,
                                repeatable=False)}
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stdout(io.StringIO()):
                taken = completo_quests.write(zones, {}, {}, {}, {}, {}, catalog, listed, {})
            return taken, out.read_text(), completo_quests.shipped(out)

    def test_taken_after_the_move_and_before_the_rows(self):
        taken, text, rows = self.write()
        self.assertIn('name = "Westfall", continent = 0, quests = { 8316 }', text)
        self.assertIn('    [8316] = { "Armaments of War", 60, 58, 2, 0, 1,', text)
        self.assertIn('    [98072] = { "Crocs of the Sky", 27, 19, 1, 0, 0,', text)
        self.assertNotIn("Not Listed", text)
        self.assertEqual(taken, [(8316, "Armaments of War", "reqclass", 0, 1), (8316, "Armaments of War", "side", 3, 2)])
        self.assertEqual(rows[8316], {"level": 60, "reqlevel": 58, "side": 2, "reqclass": 1})

    def test_report_names_what_is_new(self):
        taken, _, rows = self.write()
        self.assertIn("2 values are theirs instead of ours, 0 of them new.", completo_quests.taken_report(taken, rows))
        before = {8316: dict(rows[8316], side=3)}
        report = completo_quests.taken_report(taken, before)
        self.assertIn("2 values are theirs instead of ours, 1 of them new.", report)
        self.assertIn("- Armaments of War (8316): side 3 to 2", report)


class Unlisted(unittest.TestCase):
    def test_kept_though_the_list_leaves_it_out(self):
        zones = {"16591": {"name": "Riverglades", "quests": [
            {"id": 94532, "name": "Gnoll Infestation", "level": 38, "reqlevel": 36, "side": 2},
            {"id": 95161, "name": "Remember That I Love You", "level": 22, "reqlevel": 15, "side": 1},
            {"id": 8, "name": "Not Listed", "level": 2, "reqlevel": 1, "side": 1}]}}
        listed = {"quests": {"95161": {"name": "Remember That I Love You", "level": 22, "reqlevel": 15, "side": 1,
                                       "reqclass": 0, "category": ["zone", 16591]}}, "starts": {}}
        fixes = {"unlisted": [{"quests": [94532, 95161]}, {"quests": [1]}]}
        err = io.StringIO()
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
                completo_quests.write(zones, {}, {}, {}, {}, {}, {}, listed, fixes)
            text = out.read_text()
        self.assertIn('map = 2548, name = "Riverglades", continent = 0, quests = { 94532, 95161 }', text)
        self.assertIn('    [94532] = { "Gnoll Infestation", 38, 36, 2, 0, 0, nil, nil, nil, nil },', text)
        self.assertNotIn("Not Listed", text)
        self.assertIn("unlisted [1] names quest 1, which the data does not have; skipped", err.getvalue())
        self.assertIn("unlisted names quest 95161, which ForeverChanges lists already", err.getvalue())


class Gating(unittest.TestCase):
    CAMP = {"category": ["sort", 666]}

    def rows(self):
        names = {95998: "The Great Outdoors", 96608: "The Great Outdoors", 96627: "The Adventurer",
                 97915: "Camping 101: Alchemy", 96045: "Camping 101: Alchemy", 324: "The Lost Ingots",
                 526: "Lightforge Ingots", 19: "Tharil'zun"}
        return {q: (12, {"id": q, "name": n, "level": 6, "reqlevel": 4, "side": 1}) for q, n in names.items()}

    def listed(self):
        return {"quests": {str(q): dict(self.CAMP) for q in (95998, 96608, 96627, 97915, 96045)}}

    def test_camping_quests_of_one_name_and_the_fixes(self):
        groups = completo_quests.exclusive_groups(self.rows(), self.listed(), [{"quests": [526, 324]}])
        self.assertEqual(groups, [[324, 526], [95998, 96608], [96045, 97915]])

    def test_only_the_camping_sort(self):
        listed = {"quests": {"95998": {"category": ["zone", 12]}, "96608": dict(self.CAMP)}}
        self.assertEqual(completo_quests.exclusive_groups(self.rows(), listed, []), [])

    def exclusive_groups(self, fixes):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            groups = completo_quests.exclusive_groups(self.rows(), self.listed(), fixes)
        return groups, err.getvalue()

    def test_unknown_quest_warns_and_skips(self):
        groups, warnings = self.exclusive_groups([{"quests": [1, 324]}, {"quests": [526, 324]}])
        self.assertEqual(groups, [[324, 526], [95998, 96608], [96045, 97915]])
        self.assertIn("exclusive [1, 324] names quest 1, which the data does not have; skipped", warnings)

    def test_a_quest_in_two_groups_warns_and_skips(self):
        groups, warnings = self.exclusive_groups([{"quests": [324, 526]}, {"quests": [526, 19]}, {"quests": [19, 95998]}])
        self.assertEqual(groups, [[324, 526], [95998, 96608], [96045, 97915]])
        self.assertIn("exclusive [19, 526] names quest 526, which is in a group already; skipped", warnings)
        self.assertIn("exclusive [19, 95998] names quest 95998, which is in a group already; skipped", warnings)

    def test_written(self):
        zones = {"12": {"name": "Elwynn Forest", "quests": [q for _, q in self.rows().values()]}}
        fixes = {"breadcrumbs": {"_note": "x", "96627": {"to": 95998}, "96628": {"to": 1}},
                 "professions": [{"skill": 171, "recipe": 1230564, "quests": [97915, 96045]},
                                 {"skill": 393, "quests": [19]}, {"skill": 164, "quests": [19, 2]}]}
        err = io.StringIO()
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stderr(err):
                completo_quests.write(zones, {}, {}, {}, {}, {}, {}, None, fixes)
            text = out.read_text()
        self.assertIn("D.Breadcrumb = {\n    [96627] = 95998,\n}", text)
        self.assertIn("    [97915] = 171,\n", text)
        self.assertIn("    [19] = 393,\n", text)
        self.assertIn("D.Recipe = {\n    [96045] = 1230564,\n    [97915] = 1230564,\n}", text)
        self.assertIn("breadcrumbs 96628 names quest 96628, 1, which the data does not have; skipped", err.getvalue())
        self.assertIn("professions 164 names quest 2, which the data does not have; skipped", err.getvalue())


class FixesFile(unittest.TestCase):
    def test_every_fix_says_why(self):
        fixes = json.loads((paths.DATA / "completo_fixes.json").read_text(encoding="utf-8"))
        for qid, fix in fixes["requires"].items():
            if qid.startswith("_"):
                continue
            self.assertTrue(fix.get("why"), qid)
            self.assertTrue(fix.get("add") or fix.get("drop"), qid)
        breadcrumbs = [b for k, b in fixes["breadcrumbs"].items() if not k.startswith("_")]
        for entry in fixes["exclusive"] + breadcrumbs + fixes["professions"] + fixes["unlisted"]:
            self.assertTrue(entry.get("why"), entry)


if __name__ == "__main__":
    unittest.main()
