"""Offline checks for Scout's data generator: which creatures it keeps, how it cleans a creature's spells,
how it reads the CMaNGOS database dump and a creature's Wowhead page."""
import gzip
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import scout  # noqa: E402

PAGE = (
    "<script>... [ul][li]Level: 37[\\/li][li]Type: Beast[\\/li][li]Tameable ([url=\\/forever\\/pet=2\\/cat]Cat"
    "[\\/url])[\\/li][\\/ul] ...</script>"
    "id: 'abilities', hideCount: 1, data: [{\"cat\":0,\"id\":3009,\"level\":1,\"name\":\"Claw\",\"schools\":1},"
    "{\"cat\":0,\"id\":17257,\"name\":\"Bite\",\"schools\":1},{\"cat\":0,\"id\":403233,\"name\":\"Meathook\"}]});"
)

NAMES = {3009: "Claw", 3010: "Claw", 16828: "Claw", 17257: "Bite", 17258: "Bite", 6016: "Pierce Armor",
         19774: "Summon Ragnaros", 20565: "Magma Blast", 403233: "Meathook", 1604: "Dazed",
         1229741: "Camp Benefits", 1229451: "Boosted Rest"}

TEMPLATE = (
    "CREATE TABLE `creature_template` (\n  `Entry` int(10),\n  `Name` varchar(100),\n  `Armor` int(10),\n"
    "  `ResistanceHoly` int(10),\n  `ResistanceFire` int(10),\n  `ResistanceNature` int(10),\n"
    "  `ResistanceFrost` int(10),\n  `ResistanceShadow` int(10),\n  `ResistanceArcane` int(10),\n"
    "  `MechanicImmuneMask` int(10),\n  `SchoolImmuneMask` int(10),\n  `CreatureTypeFlags` int(10),\n"
    "  `SpellList` int(10),\n  `ScriptName` varchar(100),\n  PRIMARY KEY (`Entry`)\n) ENGINE=InnoDB;\n"
    "INSERT INTO `creature_template` VALUES (448,'Hogger',538,0,0,0,0,0,0,0,0,0,0,''),"
    "(2850,'Broken, Tooth',1593,0,0,0,0,0,0,0,0,1,0,''),"
    "(11502,'Ragnaros',4691,0,0,0,-40,0,0,116097015,4,108,0,'boss_ragnaros'),"
    "(1001,'Spell\\'s List',100,0,60,0,20,0,0,0,0,0,7,''),"
    "(1003,'It''s',50,0,0,0,0,0,0,0,0,0,0,'');\n"
)
AI = (
    "CREATE TABLE `creature_ai_scripts` (\n  `creature_id` int(10),\n  `event_type` int(10),\n"
    "  `action1_type` int(10),\n  `action1_param1` int(10),\n  `action2_type` int(10),\n"
    "  `action2_param1` int(10),\n  `action3_type` int(10),\n  `action3_param1` int(10)\n) ENGINE=InnoDB;\n"
    "INSERT INTO `creature_ai_scripts` VALUES (448,4,11,6016,0,0,0,0),(448,0,1,5,11,6730,0,0),"
    "(448,0,11,6268,0,0,0,0),(448,11,11,19774,0,0,0,0),(448,1,11,403233,0,0,0,0);\n"
)
LISTS = (
    "CREATE TABLE `creature_spell_list` (\n  `Id` int(10),\n  `Position` int(10),\n  `SpellId` int(10)\n) ENGINE=InnoDB;\n"
    "INSERT INTO `creature_spell_list` VALUES (7,0,20565),(7,1,17257),(8,0,3009);\n"
)
DUMP = TEMPLATE + AI + LISTS


class Cleaning(unittest.TestCase):
    def test_keeps_the_newest_spell_of_each_name(self):
        self.assertEqual(scout.cleaned("Cat", [3009, 3010, 16828, 17257, 17258], NAMES), [16828, 17258])

    def test_drops_the_spells_that_are_on_creatures_that_never_cast_them(self):
        spells = [403233, 1604, 1229741, 1229451, 6016]
        self.assertEqual(scout.cleaned("Hogger", spells, NAMES), [6016])

    def test_drops_a_creatures_spell_to_summon_itself(self):
        self.assertEqual(scout.cleaned("Ragnaros", [19774, 20565], NAMES), [20565])
        self.assertEqual(scout.cleaned("Hogger", [19774, 20565], NAMES), [19774, 20565])

    def test_drops_a_spell_the_client_has_no_name_for(self):
        self.assertEqual(scout.cleaned("Hogger", [6016, 99999999], NAMES), [6016])

    def test_a_creature_with_nothing_left_has_no_list(self):
        self.assertEqual(scout.cleaned("Rat", [403233], NAMES), [])


class Creatures(unittest.TestCase):
    def test_reviewed_instance_npcs_fill_roster_gaps_without_replacing_cached_names(self):
        cache = {"zones": {"1": [{"id": 448, "name": "Hogger"}]}, "npcs": {}}
        extra = {"448": {"name": "Old name"}, "12129": {"name": "Onyxian Warder"}}
        with mock.patch.object(scout, "zones", return_value=[1]), \
                mock.patch.object(scout, "instances", return_value=set()), \
                mock.patch.object(scout, "instance_npcs", return_value={}):
            names, first = scout.creatures(cache, offline=True, extra=extra)
        self.assertEqual(names, {448: "Hogger", 12129: "Onyxian Warder"})
        self.assertEqual(first, {448, 12129})

    def test_instance_bosses_include_resolved_names_and_preserve_pinned_identity(self):
        dungeons = [{"npcs": {"Boss": 448}, "wings": [{"bosses": ["Boss", "Unresolved"],
                     "rare": ["Rare"], "optional": ["Optional"], "quest": ["Quest Target"]}]}]
        lookup = {"npc:Boss": 999, "npc:Unresolved": None, "npc:Rare": 1001, "npc:Optional": 1002,
                  "npc:Quest Target": 1003}
        self.assertEqual(scout.instance_npcs(dungeons, lookup), {448: "Boss", 1001: "Rare", 1002: "Optional"})

    def test_offline_keeps_cached_zones_and_instance_bosses_without_http(self):
        cache = {"zones": {"1": [{"id": 448, "name": "Hogger"}]}, "npcs": {}}
        with mock.patch.object(scout, "zones", return_value=[1, 2]), \
                mock.patch.object(scout, "instances", return_value={2}), \
                mock.patch.object(scout, "instance_npcs", return_value={11502: "Ragnaros"}), \
                mock.patch.object(scout, "fetch_zone", side_effect=AssertionError("unexpected HTTP")):
            names, first = scout.creatures(cache, offline=True)
        self.assertEqual(names, {448: "Hogger", 11502: "Ragnaros"})
        self.assertEqual(first, {11502})
        self.assertNotIn("2", cache["zones"])

    def test_blocked_zone_keeps_later_cached_zones_and_stops_fetching(self):
        cache = {"zones": {"3": [{"id": 448, "name": "Hogger"}]}, "npcs": {}}
        blocked = urllib.error.HTTPError("https://example.test", 403, "Forbidden", {}, None)
        self.addCleanup(blocked.close)
        with mock.patch.object(scout, "zones", return_value=[1, 2, 3]), \
                mock.patch.object(scout, "instances", return_value=set()), \
                mock.patch.object(scout, "instance_npcs", return_value={}), \
                mock.patch.object(scout, "save"), \
                mock.patch.object(scout, "fetch_zone", side_effect=blocked) as fetch:
            names, _ = scout.creatures(cache)
        self.assertEqual(names, {448: "Hogger"})
        fetch.assert_called_once_with(1)
        self.assertEqual(set(cache["zones"]), {"3"})

    def test_keeps_what_someone_can_attack_but_critters(self):
        self.assertTrue(scout.attackable({"react": [-1, -1], "type": 7}))
        self.assertTrue(scout.attackable({"react": [1, -1], "type": 1}))
        self.assertTrue(scout.attackable({"react": [-1, None], "type": 1}))

    def test_leaves_out_critters_and_friendly_creatures(self):
        self.assertFalse(scout.attackable({"react": [-1, -1], "type": scout.CRITTER}))
        self.assertFalse(scout.attackable({"react": [1, 1], "type": 7}))
        self.assertFalse(scout.attackable({"react": [None, None], "type": 7}))
        self.assertFalse(scout.attackable({"type": 7}))


class Zones(unittest.TestCase):
    def read(self, refresh):
        cache = {"zones": {"12": [{"id": 1, "name": "Old"}]}, "npcs": {}}
        with mock.patch.object(scout, "zones", return_value=[12]), \
                mock.patch.object(scout, "instances", return_value=set()), \
                mock.patch.object(scout, "instance_npcs", return_value={}), \
                mock.patch.object(scout, "save"), \
                mock.patch.object(scout, "fetch_zone", return_value=[{"id": 2, "name": "New"}]):
            return scout.creatures(cache, refresh)[0]

    def test_keeps_a_zone_page_already_read(self):
        self.assertEqual(self.read(False), {1: "Old"})

    def test_reads_every_zone_page_again_when_refreshing(self):
        self.assertEqual(self.read(True), {2: "New"})

    def test_failed_refresh_keeps_the_current_and_later_cached_zones(self):
        cache = {"zones": {"1": [{"id": 448, "name": "Hogger"}],
                           "2": [{"id": 2850, "name": "Broken Tooth"}]}, "npcs": {}}
        with mock.patch.object(scout, "zones", return_value=[1, 2]), \
                mock.patch.object(scout, "instances", return_value=set()), \
                mock.patch.object(scout, "instance_npcs", return_value={}), \
                mock.patch.object(scout, "save"), \
                mock.patch.object(scout, "fetch_zone", side_effect=TimeoutError("unavailable")) as fetch:
            names, _ = scout.creatures(cache, refresh=True)
        self.assertEqual(names, {448: "Hogger", 2850: "Broken Tooth"})
        fetch.assert_called_once_with(1)


class Database(unittest.TestCase):
    def setUp(self):
        self.stats, self.casts, self.scripted = scout.database(DUMP)

    def test_reads_values_with_commas_and_quotes_in_a_name(self):
        rows = list(scout.rows(DUMP, "creature_template"))
        self.assertEqual([r["Name"] for r in rows],
                         ["Hogger", "Broken, Tooth", "Ragnaros", "Spell\\'s List", "It''s"])
        self.assertEqual(rows[1]["Armor"], "1593")

    def test_reads_a_creatures_armor_immunities_and_resistances(self):
        ragnaros = self.stats[11502]
        self.assertEqual(ragnaros["armor"], 4691)
        self.assertEqual((ragnaros["school"], ragnaros["mechanic"]), (4, 116097015))
        self.assertEqual(self.stats[1001]["resist"], [0, 60, 0, 20, 0, 0])

    def test_a_negative_resistance_counts_as_none(self):
        self.assertEqual(self.stats[11502]["resist"], [0, 0, 0, 0, 0, 0])

    def test_tameable_is_bit_one_of_the_type_flags(self):
        self.assertTrue(self.stats[2850]["tameable"])
        self.assertFalse(self.stats[448]["tameable"])
        self.assertFalse(self.stats[11502]["tameable"])

    def test_a_creature_casts_what_its_scripts_and_its_spell_list_say(self):
        self.assertEqual(self.casts[448], {6016, 6730, 6268})
        self.assertEqual(self.casts[1001], {20565, 17257})
        self.assertFalse(self.casts.get(2850))

    def test_a_script_action_that_is_not_a_cast_is_ignored(self):
        self.assertNotIn(5, self.casts[448])

    def test_a_cast_when_it_spawns_or_is_out_of_combat_is_not_an_ability(self):
        self.assertNotIn(19774, self.casts[448])
        self.assertNotIn(403233, self.casts[448])

    def test_a_row_with_the_wrong_number_of_fields_is_an_error(self):
        short = DUMP.replace("(1003,'It''s',50,0,0,0,0,0,0,0,0,0,0,'')", "(1003,'It''s',50,0)")
        with self.assertRaises(ValueError):
            list(scout.rows(short, "creature_template"))

    def test_knows_which_creatures_are_scripted_in_code(self):
        self.assertEqual(self.scripted, {11502})

    def test_a_row_of_stats_is_left_out_when_all_of_it_is_nothing(self):
        self.assertIsNone(scout.stat_row({"armor": 0, "school": 0, "mechanic": 0, "resist": [0] * 6}))
        self.assertEqual(scout.stat_row(self.stats[11502]), [4691, 4, 116097015, 0, 0, 0, 0, 0, 0])


class Dump(unittest.TestCase):
    def test_downloads_a_missing_dump(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "dump.sql.gz"
            fetched = []

            def fetch(target):
                fetched.append(target)
                target.write_bytes(gzip.compress(b"INSERT INTO `t` VALUES (1);"))
            self.assertEqual(scout.dump_text(path, fetch), "INSERT INTO `t` VALUES (1);")
            self.assertEqual(len(fetched), 1)

    def test_downloads_again_when_a_download_was_cut_short(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "dump.sql.gz"
            path.write_bytes(gzip.compress(b"x" * 1000)[:20])
            fetch = mock.Mock(side_effect=lambda target: target.write_bytes(gzip.compress(b"whole")))
            self.assertEqual(scout.dump_text(path, fetch), "whole")
            fetch.assert_called_once()

    def test_a_good_dump_is_not_downloaded_again(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "dump.sql.gz"
            path.write_bytes(gzip.compress(b"kept"))
            fetch = mock.Mock()
            self.assertEqual(scout.dump_text(path, fetch), "kept")
            fetch.assert_not_called()


class Pages(unittest.TestCase):
    def read(self, page):
        with mock.patch.object(scout.wowhead, "fetch", return_value=page), \
                mock.patch.object(scout.time, "sleep"):
            return scout.fetch_npc(2850)

    def test_reads_the_abilities_and_whether_a_hunter_can_tame_it(self):
        npc = self.read(PAGE)
        self.assertEqual(npc["abilities"], [[3009, "Claw"], [17257, "Bite"], [403233, "Meathook"]])
        self.assertTrue(npc["tameable"])

    def test_a_creature_that_cannot_be_tamed(self):
        npc = self.read(PAGE.replace("Tameable (", "Worth ("))
        self.assertFalse(npc["tameable"])

    def test_a_page_with_no_abilities(self):
        self.assertEqual(self.read("<script>nothing here</script>"), {"abilities": [], "tameable": False})


class Armor(unittest.TestCase):
    def test_is_the_expected_armor_of_each_classic_level(self):
        rows = [{"ExpansionID": "-2", "Lvl": str(level), "CreatureArmor": str(level * 10 + 0.4)}
                for level in range(1, 64)]
        rows.append({"ExpansionID": "0", "Lvl": "1", "CreatureArmor": "99999"})
        with mock.patch.object(scout.wago, "table", return_value=rows):
            armor = scout.armor()
        self.assertEqual(len(armor), 63)
        self.assertEqual(armor[0], 10)
        self.assertEqual(armor[62], 630)


class ScriptedBaseline(unittest.TestCase):
    def test_joins_by_exact_script_not_a_similar_creature_name(self):
        result = scout.script_casts(DUMP, {"boss_ragnaros": [20565], "boss_ragnaros_extra": [3009]})
        self.assertEqual(result, {11502: {20565}})

    def test_cached_spell_and_known_empty_records_win_over_classic_script(self):
        baseline = {11502: {20565}}
        self.assertEqual(scout.creature_spells(11502, {}, {}, baseline), {20565})
        self.assertEqual(scout.creature_spells(11502, {}, {"11502": {"abilities": [[3009, "Claw"]]}}, baseline), {3009})
        self.assertEqual(scout.creature_spells(11502, {}, {"11502": {"abilities": []}}, baseline), set())
        self.assertEqual(scout.creature_spells(11502, {11502: {17257}}, {}, baseline), {17257})

    def test_rejects_non_spell_values(self):
        for spells in ([True], [0], [-1], ["20565"], []):
            with self.subTest(spells=spells), self.assertRaises(ValueError):
                scout.script_casts(DUMP, {"boss_ragnaros": spells})


class SupplementalAbilities(unittest.TestCase):
    def test_reuses_journal_abilities_only_for_a_gap(self):
        journal = {"11502": {"abilities": [[20565, "Magma Blast"], [99999999, "Unknown"]]}}
        self.assertEqual(scout.creature_abilities(11502, "Ragnaros", {}, {}, {}, {}, NAMES, journal), [20565])
        self.assertEqual(scout.creature_abilities(11502, "Ragnaros", {11502: {6016}}, {}, {}, {}, NAMES,
                                                journal), [6016])
        self.assertEqual(scout.creature_abilities(11502, "Ragnaros", {}, {"11502": {"abilities": []}}, {}, {},
                                                NAMES, journal), [])

    def test_preserves_existing_fallback_and_uses_reviewed_casts_last(self):
        journal = {"11502": {"abilities": [[20565, "Magma Blast"]]}}
        self.assertEqual(scout.creature_abilities(11502, "Ragnaros", {}, {}, {}, {11502: [6016]}, NAMES,
                                                journal, {11502: [17257]}), [6016])
        self.assertEqual(scout.creature_abilities(11502, "Ragnaros", {}, {}, {}, {}, NAMES,
                                                journal, {11502: [17257]}), [20565])
        self.assertEqual(scout.creature_abilities(11502, "Ragnaros", {}, {}, {}, {}, NAMES,
                                                {"11502": {"abilities": []}}, {11502: [17257, 99999999]}), [17257])

    def abilities(self, casts=None, pages=None, baseline=None, supplement=None):
        return scout.creature_abilities(11502, "Ragnaros", casts or {}, pages or {}, baseline or {},
                                        supplement or {11502: {17257, 19774, 99999999}}, NAMES)

    def test_fills_only_the_gap_and_filters_unknown_and_self_summoning_spells(self):
        self.assertEqual(self.abilities(), [17257])
        self.assertEqual(self.abilities(casts={11502: {99999999}}), [17257])

    def test_preserves_database_page_and_reviewed_script_abilities(self):
        self.assertEqual(self.abilities(casts={11502: {6016}}), [6016])
        self.assertEqual(self.abilities(pages={"11502": {"abilities": [[6016, "Pierce Armor"]]}}), [6016])
        self.assertEqual(self.abilities(baseline={11502: {20565}}), [20565])

    def test_preserves_an_explicit_empty_cached_page(self):
        self.assertEqual(self.abilities(pages={"11502": {"abilities": []}}), [])

    def test_supplement_uses_the_same_rank_cleanup(self):
        self.assertEqual(self.abilities(supplement={11502: [3009, 3010, 16828]}), [16828])

    def test_rejects_invalid_ids_in_supplement(self):
        self.assertEqual(scout.supplemental_casts({"448": [6016, 6016]}), {448: {6016}})
        for records in ([], {"0448": [6016]}, {"0": [6016]}, {"448": []}, {"448": [True]},
                        {"448": [0]}, {"448": [-1]}, {"448": ["6016"]}, {448: [6016]}):
            with self.subTest(records=records), self.assertRaises(ValueError):
                scout.supplemental_casts(records)


if __name__ == "__main__":
    unittest.main()
