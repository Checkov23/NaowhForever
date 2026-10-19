"""Tests for Tools/sources/recipe_drops.py: which Journal boss a recipe's item XML ties it to.
Offline: the XML is made up here, in the shape Wowhead Forever sends. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import recipe_drops  # noqa: E402


def xml(sources, how=None):
    body = json.dumps({"classs": 9, "id": 273099, "source": how or [2] * len(sources), "sourcemore": sources})[1:-1]
    return f"<wowhead><item><json><![CDATA[{body}]]></json></item></wowhead>"


BOSSES = {246017: ("City of Dalaran", "Unstable Sentinel"), 7800: ("Gnomeregan", "Mekgineer Thermaplugg"),
          4421: ("Razorfen Downs", "Charlga Razorflank")}


class DroppedBy(unittest.TestCase):
    def test_the_npcs_it_drops_from(self):
        page = xml([{"dd": -1, "n": "Unstable Sentinel", "t": 1, "ti": 246017, "z": 36},
                    {"n": "Happy Camper", "t": 1, "ti": 277945}, {"n": "A quest", "t": 5, "ti": 1}])
        self.assertEqual(recipe_drops.dropped_by(page), [246017, 277945], "NPCs only, not the quest")

    def test_a_vendor_is_not_a_drop(self):
        page = xml([{"dd": -1, "n": "Unstable Sentinel", "t": 1, "ti": 246017},
                    {"n": "Happy Camper", "t": 1, "ti": 277945}], how=[2, 5])
        self.assertEqual(recipe_drops.dropped_by(page), [246017])
        self.assertEqual(recipe_drops.dropped_by(xml([{"n": "Plugger Spazzring", "t": 1, "ti": 9499}], how=[5])), [],
                         "Plugger sells the Black Dragonscale Breastplate pattern")

    def test_no_sources(self):
        self.assertEqual(recipe_drops.dropped_by(xml([])), [])
        self.assertEqual(recipe_drops.dropped_by("<wowhead><error>Item not found!</error></wowhead>"), [])


class Placed(unittest.TestCase):
    def test_a_recipe_goes_on_its_journal_boss(self):
        out = recipe_drops.placed({"273099": [246017, 277945]}, BOSSES)
        self.assertEqual(out, {"City of Dalaran": {"Unstable Sentinel": [273099]}}, "the vendor is no boss")

    def test_a_recipe_no_boss_drops_is_left_out(self):
        self.assertEqual(recipe_drops.placed({"273103": [277945]}, BOSSES), {})

    def test_a_shared_drop_is_left_out(self):
        out = recipe_drops.placed({"1": [246017, 7800, 4421], "2": [7800, 4421]}, BOSSES)
        self.assertEqual(out, {"Gnomeregan": {"Mekgineer Thermaplugg": [2]}, "Razorfen Downs": {"Charlga Razorflank": [2]}},
                         "three bosses: a random drop; two: each boss's")


if __name__ == "__main__":
    unittest.main()
