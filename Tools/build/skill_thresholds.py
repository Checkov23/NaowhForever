"""Write each recipe's yellow and grey skill into the Professions RecipeData from the Forever
client's SkillLineAbility table.

Uses the project's wago reader, with the selected build's hotfixes. The low trivial rank
is yellow, the high trivial rank is grey. The display starts orange at the recipe's learn skill
and derives green from the yellow and grey midpoint. Conflicting duplicate spell rows and
contradictory ranges are omitted rather than guessed; a recipe without a range loses its old one.
Run: python Tools/build/skill_thresholds.py [--build VERSION] [--csv FILE] [--recipes FILE]
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402

CRAFTING_LINES = {129, 164, 165, 171, 185, 186, 197, 202, 333}
RECIPES = paths.ROOT / "NaowhForever_Professions" / "Data" / "RecipeData.lua"
FIELDS = {"Spell", "SkillLine", "MinSkillLineRank", "TrivialSkillLineRankLow",
          "TrivialSkillLineRankHigh", "TradeSkillCategoryID"}
# A recipe entry's line: its spell, then its learn skill, then the range this tool wrote last time.
RECIPE = re.compile(r"^(\s*\{ spell = (\d+),.*?\bskill = \d+)(?:, yellow = \d+, grey = \d+)?", re.M)


def collect(rows):
    values, conflicts = {}, set()
    for row in rows:
        if not FIELDS.issubset(row):
            raise ValueError("SkillLineAbility is missing required columns")
        if int(row["SkillLine"]) not in CRAFTING_LINES or int(row["TradeSkillCategoryID"]) <= 0:
            continue
        spell = int(row["Spell"])
        first, yellow, grey = (int(row[field]) for field in (
            "MinSkillLineRank", "TrivialSkillLineRankLow", "TrivialSkillLineRankHigh"))
        if spell <= 0 or not 0 <= first <= yellow < grey:
            continue
        bounds = (yellow, grey)
        if spell in values and values[spell] != bounds:
            conflicts.add(spell)
        values[spell] = bounds
    return {spell: bounds for spell, bounds in values.items() if spell not in conflicts}


def apply(source, values):
    """RecipeData's text with each recipe's range after its learn skill, or none without one."""
    def fill(match):
        bounds = values.get(int(match[2]))
        return match[1] + (", yellow = %d, grey = %d" % bounds if bounds else "")
    return RECIPE.sub(fill, source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", default=wago.BUILD)
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--recipes", type=Path, default=RECIPES)
    args = parser.parse_args()
    if args.csv:
        with args.csv.open(encoding="utf-8-sig", newline="") as source:
            values = collect(csv.DictReader(source))
    else:
        values = collect(wago.table("SkillLineAbility", args.build))
    if not values:
        raise ValueError("No valid crafting ranges; existing data left intact")
    text = apply(args.recipes.read_bytes().decode("ascii"), values)
    args.recipes.write_bytes(text.encode("ascii"))
    print(f"Wrote {text.count(', yellow = ')} recipe ranges for {args.build}: {args.recipes}")


if __name__ == "__main__":
    main()
