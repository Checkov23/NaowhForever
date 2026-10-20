"""Quest fallback imports preserve map coordinates, prerequisite logic and existing records."""
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import data_bundle  # noqa: E402
import quest_entities as source  # noqa: E402
import completo_quests  # noqa: E402
import journeys_quests  # noqa: E402


class EntityQuests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        (self.folder / "completo_quests.json").write_text(json.dumps({"65": {"chain": None, "start": None}}))
        self.document = {"version": 1, "edition": "forever", "coordinate_space": "forever",
                         "source": "permitted fixture", "build": "fixture build",
                         "entities": {"quests": {"65": {"finishedBy": {"1": [123]}, "preQuestGroup": [10, 11]}},
                                      "npcs": {"123": {"name": "Giver", "spawns": {"44": [[20, 40]]}}},
                                      "objects": {}, "items": {}}}

    def convert(self):
        with mock.patch("urllib.request.urlopen", side_effect=AssertionError("unexpected HTTP")):
            return source.convert(self.document, self.folder)

    def test_generates_importable_candidates_without_modifying_caches(self):
        before = {p.name: p.read_bytes() for p in self.folder.iterdir()}
        bundle, report = self.convert()
        self.assertEqual(report["map_candidates"], [65])
        point = bundle["data"]["quest_spots"]["65"][0]
        self.assertEqual((point["zone"], point["coords"], point["coordinate_space"]), (44, [[20, 40]], "forever"))
        data_bundle.prepare(bundle, self.folder)
        self.assertEqual({p.name: p.read_bytes() for p in self.folder.iterdir()}, before)

    def test_keeps_existing_nonempty_map_and_known_prerequisite_records(self):
        (self.folder / "journeys_quest_spots.json").write_text(json.dumps({"65": [{"existing": True}]}))
        (self.folder / "completo_requires.json").write_text(json.dumps({"65": None}))
        bundle, report = self.convert()
        self.assertEqual(bundle["data"], {"quest_spots": {}, "prerequisites": {}})
        self.assertEqual(report["prerequisite_conflicts"], [65])

    def test_can_fill_empty_map_without_marking_unknown_maps_as_known_empty(self):
        (self.folder / "journeys_quest_spots.json").write_text('{"65": []}')
        self.document["entities"]["quests"]["66"] = {}
        bundle, _ = self.convert()
        self.assertIn("65", bundle["data"]["quest_spots"])
        self.assertNotIn("66", bundle["data"]["quest_spots"])

    def test_withholds_phased_unsupported_and_instance_coordinates(self):
        self.document["entities"]["npcs"]["123"]["spawns"] = {
            "44": [[20, 40, 194], [-1, -1]], "99999": [[20, 40]]}
        bundle, report = self.convert()
        self.assertEqual(bundle["data"]["quest_spots"], {})
        self.assertEqual(set(report["notes"]["65"]),
                         {"conditional_spawn", "unsupported_map", "invalid_or_instance_coordinate", "ambiguous_turn_in"})

    def test_clustered_turn_ins_use_an_actual_spawn_and_reject_separate_locations(self):
        entities = self.document["entities"]
        entities["quests"]["65"]["finishedBy"] = [[123, 124]]
        entities["npcs"]["124"] = {"name": "Other giver", "spawns": {"44": [[21, 41], [22, 42]]}}
        bundle, _ = self.convert()
        self.assertEqual(bundle["data"]["quest_spots"]["65"][0]["coords"], [[21, 41]])
        entities["npcs"]["124"]["spawns"]["44"].append([60, 60])
        bundle, _ = self.convert()
        self.assertEqual(bundle["data"]["quest_spots"], {})

    def test_known_turn_in_does_not_hide_an_unsupported_or_conditional_alternative(self):
        spawns = self.document["entities"]["npcs"]["123"]["spawns"]
        for area, coords in (("99999", [[21, 41]]), ("44", [[20, 40], [21, 41, 9]])):
            spawns[area] = coords
            bundle, _ = self.convert()
            self.assertEqual(bundle["data"]["quest_spots"], {})
            spawns.pop(area)

    def test_explicit_event_coordinates_and_extra_objective_actor_links(self):
        quest = self.document["entities"]["quests"]["65"]
        quest.pop("finishedBy")
        quest["triggerEnd"] = ["Explore", {"44": [[33, 55]]}]
        quest["extraObjectives"] = [[None, 4, "Use object", 0, [["object", 55]]]]
        self.document["entities"]["objects"]["55"] = {"name": "Object", "spawns": {"44": [[40, 50]]}}
        bundle, _ = self.convert()
        points = bundle["data"]["quest_spots"]["65"]
        self.assertEqual({tuple(p["coords"][0]) for p in points}, {(33, 55), (40, 50)})
        self.assertTrue(all(p["point"] == "requirement" for p in points))

    def test_many_quest_item_sources_require_explicit_matching_zone_and_keep_commodity_guard(self):
        quest = self.document["entities"]["quests"]["65"]
        quest.pop("finishedBy")
        quest.update(objectives={"3": [[77]]}, zoneOrSort=44)
        entities = self.document["entities"]
        entities["items"]["77"] = {"class": 12, "npcDrops": [123, 124, 125, 126]}
        for i in (124, 125, 126):
            entities["npcs"][str(i)] = {"name": str(i), "spawns": {"44": [[21, 41]]}}
        bundle, _ = self.convert()
        points = bundle["data"]["quest_spots"]["65"]
        self.assertEqual(len(points), 4)
        self.assertTrue(journeys_quests.quest_spots(points)[1])
        entities["items"]["77"]["class"] = 7
        self.assertFalse(self.convert()[0]["data"]["quest_spots"])
        entities["items"]["77"]["class"] = 12
        quest["zoneOrSort"] = 33
        self.assertFalse(self.convert()[0]["data"]["quest_spots"])

    def test_dungeon_guidance_is_separate_from_exact_targets(self):
        (self.folder / "journal_bosses.json").write_text(json.dumps({"dungeons": [
            {"name": "Fixture dungeon", "zone": 209, "entrance": {"map": 1433, "x": 30, "y": 40}}]}))
        quest = self.document["entities"]["quests"]["65"]
        quest["zoneOrSort"] = 209
        self.document["entities"]["npcs"]["123"]["spawns"] = {"209": [[-1, -1]]}
        bundle, report = self.convert()
        points = bundle["data"]["quest_spots"]["65"]
        self.assertEqual(journeys_quests.quest_spots(points), (None, []))
        self.assertEqual(journeys_quests.entrance_spots(points), [(1433, 30, 40)])
        self.assertIn("dungeon_entrance_only", report["notes"]["65"])

    def test_fill_unroutable_requires_opt_in_and_preserves_usable_records(self):
        path = self.folder / "journeys_quest_spots.json"
        current = {"65": [{"point": "requirement", "zone": 99999, "coords": [[20, 40]]}]}
        path.write_text(json.dumps(current))
        self.assertFalse(self.convert()[0]["data"]["quest_spots"])
        bundle, report = source.convert(self.document, self.folder, fill_unroutable=True)
        self.assertIn("65", bundle["data"]["quest_spots"])
        self.assertEqual(report["unroutable_records_replaced"], [65])
        self.assertEqual(json.loads(path.read_text()), current)
        current["65"][0]["zone"] = 44
        path.write_text(json.dumps(current))
        bundle, _ = source.convert(self.document, self.folder, fill_unroutable=True)
        self.assertFalse(bundle["data"]["quest_spots"])

    def test_does_not_choose_between_multiple_turn_in_npcs(self):
        self.document["entities"]["quests"]["65"]["finishedBy"] = [[123, 124]]
        bundle, report = self.convert()
        self.assertEqual(bundle["data"]["quest_spots"], {})
        self.assertIn("ambiguous_turn_in", report["notes"]["65"])

    def test_item_objective_uses_drop_source_and_limits_world_drops(self):
        quest = self.document["entities"]["quests"]["65"]
        quest.pop("finishedBy")
        quest["objectives"] = {"3": [[77]]}
        self.document["entities"]["items"]["77"] = {"npcDrops": [123]}
        bundle, _ = self.convert()
        self.assertEqual(bundle["data"]["quest_spots"]["65"][0]["point"], "sourcerequirement")
        self.document["entities"]["items"]["77"]["npcDrops"] = [123, 124, 125, 126]
        bundle, report = self.convert()
        self.assertEqual(bundle["data"]["quest_spots"], {})
        self.assertIn("too_many_item_sources", report["notes"]["65"])

    def test_preserves_all_and_any_prerequisites(self):
        quest = {"preQuestGroup": [10, 11], "preQuestSingle": [12, 13]}
        requirements = source.prerequisite(quest)
        self.assertEqual(requirements, {"quests": [10, 11, 12, 13], "groups": [10, 11, [12, 13]]})
        self.assertIsNone(source.prerequisite({"preQuestGroup": [-10]}))
        self.assertIsNone(source.prerequisite({}))
        self.assertIsNone(source.prerequisite({"preQuestSingle": [10, 11]}, quest_id=10))

    def test_explicit_groups_keep_unrelated_existing_chain_requirements(self):
        before = {65: [10, 11, 12, 13, 14]}
        known = {i: (44, {"name": "Same" if i in (10, 11) else str(i)}) for i in before[65]}
        explicit = {"65": {"quests": [10, 11, 12, 13], "groups": [10, 11, [12, 13]]}}
        result = completo_quests.requirements(before, known, explicit)
        self.assertEqual(result[65], [10, 11, [12, 13], 14])
        self.assertEqual(before[65], [10, 11, 12, 13, 14])

    def test_forever_points_bypass_legacy_coordinate_heuristic(self):
        point = {"point": "end", "zone": 44, "coords": [[20, 40]], "coordinate_space": "forever"}
        with mock.patch.object(journeys_quests, "forever_points", side_effect=AssertionError("double conversion")):
            self.assertEqual(journeys_quests.quest_spots([point]), ((1433, 20, 40), []))

    def test_alternative_turn_ins_keep_factions_and_are_usable_without_objective_camps(self):
        points = [{"point": "end_choice", "zone": 44, "coords": [[20, 40]],
                   "coordinate_space": "forever", "side": "A"},
                  {"point": "end_choice", "zone": 14, "coords": [[30, 50]],
                   "coordinate_space": "forever", "side": "H"}]
        data_bundle.validate("quest_spots", {"65": points})
        self.assertEqual(journeys_quests.quest_spots(points), (None, []))
        self.assertEqual(journeys_quests.turn_in_choices(points), [(1411, 30, 50, "H"), (1433, 20, 40, "A")])
        self.assertTrue(source.routable(points))
        for field, value in (("side", "unknown"), ("coordinate_space", "classic")):
            bad = copy.deepcopy(points)
            bad[0][field] = value
            with self.assertRaises(ValueError):
                data_bundle.validate("quest_spots", {"65": bad})

    def test_rejects_classic_coordinate_declaration_and_inconsistent_groups(self):
        wrong = copy.deepcopy(self.document)
        wrong["coordinate_space"] = "classic"
        with self.assertRaises(ValueError):
            source.convert(wrong, self.folder)
        with self.assertRaises(ValueError):
            data_bundle.validate("prerequisites", {"65": {"quests": [10], "groups": [[10, 11]]}})

    def test_full_catalog_retains_every_record_and_unknown_zone_has_no_fake_start(self):
        quests = self.document["entities"]["quests"]
        quests["66"] = {"name": "Island quest", "zoneOrSort": 16606, "questLevel": 10,
                        "requiredRaces": 8589934770, "specialFlags": 1}
        quests["67"] = {"name": "No known zone", "zoneOrSort": -666}
        quests["68"] = {"name": "<UNUSED> old quest"}
        quests["65"]["name"] = "Existing quest"
        bundle, report = source.convert(self.document, self.folder, full_catalog=True)
        catalog = bundle["data"]["quest_catalog"]
        self.assertEqual(set(catalog), {"65", "66", "67", "68"})
        self.assertEqual((catalog["66"]["zone"], catalog["66"]["zone_name"], catalog["66"]["side"]),
                         (16606, "Darkspear Islands", 2))
        self.assertTrue(catalog["66"]["repeatable"])
        self.assertEqual(catalog["67"]["zone"], 0)
        self.assertIsNone(catalog["67"]["start"])
        self.assertIn(67, report["unassigned_quest_ids"])

    def test_catalog_uses_supported_starter_zone_without_reconverting_forever_coords(self):
        quest = self.document["entities"]["quests"]["65"]
        quest.update(name="Starter quest", startedBy=[[123]], zoneOrSort=-81)
        rows = source.catalog_records(self.document["entities"], {})
        self.assertEqual(rows["65"]["zone"], 44)
        self.assertEqual(rows["65"]["start"]["coord"], [20, 40])
        self.assertEqual(rows["65"]["start"]["coordinate_space"], "forever")

    def test_generated_catalog_preserves_existing_rows_adds_unassigned_and_hides_unused(self):
        source_quests = self.document["entities"]["quests"]
        source_quests["65"].update(name="Source name must not replace reviewed name", zoneOrSort=44)
        source_quests["66"] = {"name": "Island quest", "zoneOrSort": 16606}
        source_quests["67"] = {"name": "Unassigned quest", "zoneOrSort": -666}
        source_quests["68"] = {"name": "<UNUSED> old quest"}
        catalog = source.catalog_records(self.document["entities"], {})
        zones = {"44": {"name": "Redridge Mountains", "quests": [
            {"id": 65, "name": "Reviewed name", "level": 18, "reqlevel": 14, "side": 1, "category2": 0}]}}
        original = copy.deepcopy(zones)
        out = self.folder / "Quests.lua"
        with mock.patch.object(completo_quests, "ROOT", self.folder), mock.patch.object(completo_quests, "OUT", out):
            completo_quests.write(zones, {}, {}, {}, {}, {}, catalog)
            first = out.read_bytes()
            completo_quests.write(zones, {}, {}, {}, {}, {}, catalog)
        text = first.decode()
        self.assertIn('[65] = { "Reviewed name"', text)
        self.assertNotIn("Source name must not replace", text)
        self.assertIn('map = 2524, name = "Darkspear Islands"', text)
        self.assertIn('map = 0, name = "Unsorted Quests"', text)
        self.assertIn('[67] = { "Unassigned quest"', text)
        self.assertNotIn("[68]", text)
        self.assertEqual(first, out.read_bytes())
        self.assertEqual(zones, original)

    def test_full_catalog_preserves_existing_auxiliary_prerequisites(self):
        (self.folder / "completo_quests.json").write_text("{}")
        (self.folder / "completo_elsewhere.json").write_text(json.dumps({"quests": {"65": {"after": [9]}}}))
        self.document["entities"]["quests"]["65"]["name"] = "Auxiliary quest"
        bundle, report = source.convert(self.document, self.folder, full_catalog=True)
        self.assertNotIn("65", bundle["data"]["prerequisites"])
        self.assertIn(65, report["prerequisite_conflicts"])


if __name__ == "__main__":
    unittest.main()
