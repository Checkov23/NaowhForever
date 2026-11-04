"""Tests for Tools/build/completo_quests.py's hand-kept corrections (Tools/data/completo_fixes.json):
a quest's add joins the quests before it, its drop leaves them and its explicit groups, a fix naming
a quest the data lacks is skipped with a warning, an add or drop that changes nothing is warned of,
and a key starting with _ is a note. Offline. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import contextlib
import io
import json
import sys
import unittest
from pathlib import Path

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


class FixesFile(unittest.TestCase):
    def test_every_fix_says_why(self):
        fixes = json.loads((paths.DATA / "completo_fixes.json").read_text(encoding="utf-8"))
        for qid, fix in fixes["requires"].items():
            if qid.startswith("_"):
                continue
            self.assertTrue(fix.get("why"), qid)
            self.assertTrue(fix.get("add") or fix.get("drop"), qid)


if __name__ == "__main__":
    unittest.main()
