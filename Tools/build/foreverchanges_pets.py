"""Build Tools/data/foreverchanges_pets.json: the beasts ForeverChanges lists as tameable, which
Tools/build/scout.py marks tameable.

Their hunter pets page (/hunter-pets) lists Classic's beasts and the ones Forever adds, each with its
NPC ID and name, in the data the page is drawn from. Forever's new beasts are in no Classic database,
and Wowhead's pages, Scout's other source for them, have refused our requests since October.

Usage: python Tools/build/foreverchanges_pets.py
"""
import json
import re
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wowhead  # noqa: E402

SITE = "https://foreverchanges.pro"
OUT = paths.DATA / "foreverchanges_pets.json"
# The page's data comes in chunks of a JavaScript string, each pushed onto self.__next_f.
PUSH = re.compile(r'self\.__next_f\.push\(\[1,"((?:[^"\\]|\\.)*)"\]\)')


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": wowhead.AGENT})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def beasts(page):
    """{NPC ID: name} of every beast the page lists."""
    data = "".join(json.loads('"' + chunk + '"') for chunk in PUSH.findall(page))
    at = data.find('"beasts":[')
    if at < 0:
        raise ValueError("no beasts in the hunter pets page")
    listed = json.JSONDecoder().raw_decode(data, at + len('"beasts":'))[0]
    return {beast["id"]: beast["name"] for beast in listed}


def main():
    found = beasts(fetch(SITE + "/hunter-pets"))
    OUT.write_text(json.dumps({str(npc): found[npc] for npc in sorted(found)}, indent=1) + "\n",
                   encoding="utf-8", newline="\n")
    print(f"Wrote {OUT.relative_to(paths.ROOT)}: {len(found)} beasts")


if __name__ == "__main__":
    main()
