"""Offline export imports must preserve caches and reject malformed data before writing."""
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import data_bundle as bundle  # noqa: E402


class DataBundle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.npc = {"abilities": [[3009, "Claw"]], "tameable": True}
        self.data = {"version": 1, "edition": "forever", "source": "approved fixture",
                     "data": {"scout": {"npcs": {"2850": self.npc}}}}

    def write(self, name, value):
        path = self.folder / name
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_merges_npcs_without_erasing_other_zones_or_records(self):
        old = {"zones": {"1": [{"id": 448, "name": "Hogger"}]}, "npcs": {"448": self.npc}}
        path = self.write("scout.json", old)
        bundle.apply(bundle.prepare(self.data, self.folder))
        got = bundle.read(path)
        self.assertEqual(got["zones"], old["zones"])
        self.assertEqual(set(got["npcs"]), {"448", "2850"})

    def test_existing_record_wins_unless_replace_requested(self):
        old = {"zones": {}, "npcs": {"2850": {"abilities": [], "tameable": False}}}
        path = self.write("scout.json", old)
        self.assertEqual(bundle.prepare(self.data, self.folder)[path], old)
        self.assertEqual(bundle.prepare(self.data, self.folder, replace=True)[path]["npcs"]["2850"], self.npc)

    def test_rejects_entire_bundle_before_any_cache_is_written(self):
        path = self.write("scout.json", {"zones": {}, "npcs": {}})
        before = path.read_bytes()
        self.data["data"]["quest_spots"] = {"65": [{"point": "end", "zone": 44, "coords": [[101, 20]]}]}
        with self.assertRaises(ValueError):
            bundle.prepare(self.data, self.folder)
        self.assertEqual(path.read_bytes(), before)
        self.assertFalse((self.folder / "journeys_quest_spots.json").exists())

    def test_rejects_wrong_edition_paths_boolean_ids_and_nonfinite_coords(self):
        for change in (
            {"edition": "classic"}, {"version": True},
            {"data": {"../../other": {}}},
            {"data": {"scout": {"zones": {"1": [{"id": True, "name": "bad"}]}}}},
            {"data": {"quest_spots": {"65": [{"point": "end", "zone": 44, "coords": [[float("nan"), 20]]}]}}},
        ):
            with self.subTest(change=change), self.assertRaises(ValueError):
                bundle.prepare({**self.data, **change}, self.folder)

    def test_rolls_back_previous_file_when_later_write_fails(self):
        first = self.write("scout.json", {"zones": {}, "npcs": {}})
        before = first.read_bytes()
        second = self.folder / "completo_quests.json"
        real_write = bundle.atomic_write

        def write(path, data):
            if path == second:
                raise OSError("disk full")
            real_write(path, data)

        with mock.patch.object(bundle, "atomic_write", side_effect=write), self.assertRaises(OSError):
            bundle.apply({first: {"updated": True}, second: {"1": {}}})
        self.assertEqual(first.read_bytes(), before)
        self.assertFalse(second.exists())

    def test_report_distinguishes_missing_and_known_empty_map_pages(self):
        self.write("completo_quests.json", {"1": {"chain": None, "start": None},
                                           "2": {"chain": None, "start": None}})
        self.write("journeys_quest_spots.json", {"1": []})
        result = bundle.report(self.folder)
        self.assertEqual(result["quest_map_pages_missing"], [2])
        self.assertEqual(result["quest_maps_known_empty"], [1])

    def test_preview_does_not_write_caches_or_make_http_requests(self):
        source = self.write("approved.json", self.data)
        with mock.patch.object(bundle.paths, "DATA", self.folder), \
                mock.patch.object(sys, "argv", ["data_bundle.py", "--import-file", str(source)]), \
                mock.patch("urllib.request.urlopen", side_effect=AssertionError("unexpected HTTP")), \
                mock.patch("builtins.print"):
            bundle.main()
        self.assertFalse((self.folder / "scout.json").exists())

    def test_report_cannot_overwrite_an_input_cache(self):
        source = self.write("scout.json", {"zones": {}, "npcs": {}})
        before = source.read_bytes()
        with mock.patch.object(bundle.paths, "DATA", self.folder), \
                mock.patch.object(sys, "argv", ["data_bundle.py", "--report", str(source)]), \
                self.assertRaises(SystemExit) as error:
            bundle.main()
        self.assertEqual(error.exception.code, 1)
        self.assertEqual(source.read_bytes(), before)

    def test_real_cache_snapshot_can_be_validated_without_mutating_it(self):
        data = {k: bundle.read(paths.DATA / v) for k, v in bundle.FILES.items()}
        original = copy.deepcopy(data)
        for quest in data["quests"].values():
            start = quest and quest.get("start")
            if start and start.get("coord") == [""]:
                start["coord"] = None
        export = {"version": 1, "edition": "forever", "source": "snapshot", "data": data}
        bundle.prepare(export, self.folder)
        self.assertEqual(bundle.read(paths.DATA / "completo_quests.json"), original["quests"])


if __name__ == "__main__":
    unittest.main()
