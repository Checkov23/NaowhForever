"""Tests for the daily badge sync (Tools/release/sync_badges.py): naowh.gg's patron list checked and
written as Lua. Offline, made-up data. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import sync_badges  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


class SyncBadges(unittest.TestCase):
    def test_an_empty_list_writes_the_file_in_the_repo(self):
        committed = (ROOT / sync_badges.OUT).read_bytes()
        if b"Player-" in committed:
            self.skipTest("the committed list has patrons")
        text = sync_badges.render(sync_badges.validated({"patrons": {}}))
        self.assertEqual(text.encode("ascii"), committed)

    def test_patrons_are_sorted_by_region_and_guid_with_their_month(self):
        text = sync_badges.render(sync_badges.validated({"patrons": {
            "90": {"Player-4618-0000AAAA": {}, "Player-4613-006EB819": {"since": "2026-09"}},
            "3": {"Player-1-0000BBBB": {"since": "2026-10"}},
        }}))
        body = text.split("ns.BADGE_PATRONS = {\r\n", 1)[1]
        self.assertEqual(body, (
            "    [3] = {\r\n"
            '        ["Player-1-0000BBBB"] = { since = "2026-10" },\r\n'
            "    },\r\n"
            "    [90] = {\r\n"
            '        ["Player-4613-006EB819"] = { since = "2026-09" },\r\n'
            '        ["Player-4618-0000AAAA"] = {},\r\n'
            "    },\r\n"
            "}\r\n"
        ))
        self.assertNotIn("\n", text.replace("\r\n", ""))

    def test_epic_and_basic_patrons_keep_the_tier_and_a_legendary_one_needs_none(self):
        text = sync_badges.render(sync_badges.validated({"patrons": {"90": {
            "Player-4613-006EB819": {"since": "2026-09", "tier": "epic"},
            "Player-4618-0000AAAA": {"tier": "epic"},
            "Player-4620-0000BBBB": {"since": "2026-10", "tier": "legendary"},
            "Player-4620-0000CCCC": {"since": "2026-10", "tier": "basic"},
        }}}))
        self.assertIn('["Player-4613-006EB819"] = { since = "2026-09", tier = "epic" },\r\n', text)
        self.assertIn('["Player-4618-0000AAAA"] = { tier = "epic" },\r\n', text)
        self.assertIn('["Player-4620-0000BBBB"] = { since = "2026-10" },\r\n', text)
        self.assertIn('["Player-4620-0000CCCC"] = { since = "2026-10", tier = "basic" },\r\n', text)

    def test_the_claim_hash_is_kept(self):
        text = sync_badges.render(sync_badges.validated({"patrons": {"90": {
            "Player-4613-006EB819": {"since": "2026-09", "tier": "epic", "claim": "8c39fddd"},
            "Player-4618-0000AAAA": {"tier": "legendary", "claim": "04bb847a"},
        }}}))
        self.assertIn('["Player-4613-006EB819"] = { since = "2026-09", tier = "epic", claim = "8c39fddd" },\r\n', text)
        self.assertIn('["Player-4618-0000AAAA"] = { claim = "04bb847a" },\r\n', text)

    def test_anything_unexpected_stops_the_sync(self):
        for bad in (
            [],
            {"patrons": []},
            {"patrons": {"0": {}}},
            {"patrons": {"x": {}}},
            {"patrons": {"90": {"player-1-0000AAAA": {}}}},
            {"patrons": {"90": {"Player-1-0000aaaa": {}}}},
            {"patrons": {"90": {"Player-1-0000AAAA": {"since": "2026-13"}}}},
            {"patrons": {"90": {"Player-1-0000AAAA": "2026-09"}}},
            {"patrons": {"90": {"Player-1-0000AAAA": {"tier": "rare"}}}},
            {"patrons": {"90": {"Player-1-0000AAAA": {"tier": None}}}},
            {"patrons": {"90": {"Player-1-0000AAAA": {"claim": "8C39FDDD"}}}},
            {"patrons": {"90": {"Player-1-0000AAAA": {"claim": "8c39fdd"}}}},
            {"patrons": {"90": {"Player-1-0000AAAA": {"claim": "K7P2-9XQM"}}}},
        ):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                sync_badges.validated(bad)


if __name__ == "__main__":
    unittest.main()
