"""Tests for Tools/build/foreverchanges_pets.py: reading the beasts out of ForeverChanges' hunter pets
page, whose data comes in pushed string chunks. Offline, made-up page. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import foreverchanges_pets as fc  # noqa: E402

DATA = ('1:["$","$L16d",null,{"locale":"en","beasts":[{"key":"c3098","id":3098,"name":"Mottled Boar",'
        '"family":"boar","isNew":false},{"key":"f250868","id":250868,"name":"Vuldren","family":"fox",'
        '"isNew":true}]}]\n')


def push(text):
    return f"<script>self.__next_f.push([1,{json.dumps(text)}])</script>"


class Beasts(unittest.TestCase):
    def test_the_beasts_across_chunks(self):
        page = push(DATA[:40]) + push(DATA[40:])
        self.assertEqual(fc.beasts(page), {3098: "Mottled Boar", 250868: "Vuldren"})

    def test_a_page_without_beasts(self):
        with self.assertRaises(ValueError):
            fc.beasts(push('1:["$","div",null,{}]\n'))


if __name__ == "__main__":
    unittest.main()
