"""Offline checks for the profession threshold data generator."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import skill_thresholds as st  # noqa: E402


def row(spell=10, first=1, yellow=95, grey=130, line=197, category=1):
    return {"Spell": str(spell), "SkillLine": str(line), "MinSkillLineRank": str(first),
            "TrivialSkillLineRankLow": str(yellow), "TrivialSkillLineRankHigh": str(grey),
            "TradeSkillCategoryID": str(category)}


RECIPES = (
    'recipes = {\r\n'
    '    { spell = 10, item = 1, skill = 75, source = "trainer", cost = 100 },\r\n'
    '    { spell = 11, item = 2, skill = 45, yellow = 1, grey = 2, source = "drop", drops = {\r\n'
    '    { spell = 12, skill = 20, yellow = 30, grey = 40, source = "trainer" },\r\n'
    '    { cap = 150, skill = 50, spell = 10, name = "Journeyman" },\r\n'
    '}\r\n')


class ThresholdTests(unittest.TestCase):
    def test_bounds_are_read_from_the_client_fields(self):
        self.assertEqual(st.collect([row()]), {10: (95, 130)})

    def test_invalid_noncrafting_and_nonrecipe_rows_are_omitted(self):
        self.assertEqual(st.collect([row(first=100), row(grey=95), row(line=356), row(category=0)]), {})

    def test_conflicting_spell_rows_are_omitted_in_any_order(self):
        rows = [row(), row(grey=135), row()]
        self.assertEqual(st.collect(rows), {})
        self.assertEqual(st.collect(list(reversed(rows))), {})

    def test_identical_duplicates_are_kept_once(self):
        self.assertEqual(st.collect([row(), row()]), {10: (95, 130)})

    def test_unknown_table_layout_fails(self):
        with self.assertRaises(ValueError):
            st.collect([{"Spell": "10"}])

    def test_ranges_follow_the_learn_skill_and_old_ones_are_replaced_or_dropped(self):
        output = st.apply(RECIPES, {10: (95, 130), 11: (30, 65)})
        self.assertEqual(output, (
            'recipes = {\r\n'
            '    { spell = 10, item = 1, skill = 75, yellow = 95, grey = 130, source = "trainer", cost = 100 },\r\n'
            '    { spell = 11, item = 2, skill = 45, yellow = 30, grey = 65, source = "drop", drops = {\r\n'
            '    { spell = 12, skill = 20, source = "trainer" },\r\n'
            '    { cap = 150, skill = 50, spell = 10, name = "Journeyman" },\r\n'
            '}\r\n'))

    def test_rewriting_is_repeatable(self):
        values = {10: (95, 130), 11: (30, 65)}
        once = st.apply(RECIPES, values)
        self.assertEqual(st.apply(once, values), once)


if __name__ == "__main__":
    unittest.main()
