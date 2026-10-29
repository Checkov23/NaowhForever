"""Tests for Tools/release/release.py, each in a throwaway git repo. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import release  # noqa: E402

CHANGELOG = ("# Changelog\r\n\r\n## Unreleased\r\n\r\n### Fixed\r\n- A fix.\r\n\r\n"
             "## 0.5.16-beta\r\n\r\n- Old.\r\n")
TOC = ("## Interface: 16001\r\n## Title: Naowh Forever\r\n## Version: 0.5.16-beta\r\n"
       "Core\\Core.lua\r\n")
CORE = 'local ns = {}\r\nns.CODE_BUILD = "0.5.16-beta"\r\nreturn ns\r\n'
FILES = (release.CHANGELOG, release.TOC, release.CORE)


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.git("init", "-q")
        self.files({release.CHANGELOG: CHANGELOG, release.TOC: TOC, release.CORE: CORE})
        self.commit("chore(release): 0.5.16-beta")
        self.tag("0.5.16-beta")

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        subprocess.run(["git", "-c", "user.name=test", "-c", "user.email=test@example.com",
                        "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", *args],
                       cwd=self.root, check=True, capture_output=True)

    def files(self, contents):
        for name, text in contents.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(text)

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", message)

    def tag(self, name):
        self.git("tag", name)

    def read(self, name):
        with open(self.root / name, encoding="utf-8", newline="") as f:
            return f.read()

    def assertUnchanged(self):
        self.assertEqual(self.read(release.CHANGELOG), CHANGELOG)
        self.assertEqual(self.read(release.TOC), TOC)
        self.assertEqual(self.read(release.CORE), CORE)

    def test_next_patch_after_the_newest_tag(self):
        self.tag("0.5.9-beta")  # sorts by number, not text
        self.assertEqual(release.prepare(self.root), "0.5.17-beta")
        self.assertEqual(self.read(release.CHANGELOG),
                         CHANGELOG.replace("## Unreleased", "## 0.5.17-beta"))
        self.assertEqual(self.read(release.TOC),
                         TOC.replace("## Version: 0.5.16-beta", "## Version: 0.5.17-beta"))
        self.assertEqual(self.read(release.CORE), CORE.replace("0.5.16-beta", "0.5.17-beta"))

    def test_in_game_notes_take_the_version(self):
        notes = ('local NOTES = {\r\n    { title = "Unreleased", lines = { "New." } },\r\n'
                 '    { title = "0.5.16-beta", lines = { "Old." } },\r\n}\r\n')
        self.files({release.PATCH_NOTES: notes})
        self.assertEqual(release.prepare(self.root), "0.5.17-beta")
        self.assertEqual(self.read(release.PATCH_NOTES),
                         notes.replace('{ title = "Unreleased"', '{ title = "0.5.17-beta"'))

    def test_in_game_notes_without_unreleased_are_left_alone(self):
        notes = 'local NOTES = {\r\n    { title = "0.5.16-beta", lines = { "Old." } },\r\n}\r\n'
        self.files({release.PATCH_NOTES: notes})
        release.prepare(self.root)
        self.assertEqual(self.read(release.PATCH_NOTES), notes)

    def test_given_version(self):
        self.assertEqual(release.prepare(self.root, "0.6.0-beta"), "0.6.0-beta")
        self.assertIn("## 0.6.0-beta\r\n", self.read(release.CHANGELOG))
        self.assertIn('ns.CODE_BUILD = "0.6.0-beta"\r\n', self.read(release.CORE))

    def test_version_already_set_by_hand(self):
        bumped = {release.CHANGELOG: CHANGELOG.replace("## Unreleased", "## 0.5.17-beta"),
                  release.TOC: TOC.replace("0.5.16-beta", "0.5.17-beta"),
                  release.CORE: CORE.replace("0.5.16-beta", "0.5.17-beta")}
        self.files(bumped)
        self.assertEqual(release.prepare(self.root), "0.5.17-beta")
        for name, text in bumped.items():
            self.assertEqual(self.read(name), text)

    def test_refuses_and_changes_nothing(self):
        cases = {
            "empty Unreleased": (
                {release.CHANGELOG: "## Unreleased\r\n\r\n## 0.5.16-beta\r\n"}, None),
            "existing tag": ({}, "0.5.16-beta"),
            "bad version": ({}, "v1"),
            "no changelog section": ({release.CHANGELOG: "## 0.5.16-beta\r\n- Old.\r\n"}, None),
            "no CODE_BUILD": ({release.CORE: "local ns = {}\r\n"}, None),
            "old section of the same number": (
                {release.CHANGELOG: "## 0.5.16-beta\r\n- Old.\r\n\r\n## 1.0.0\r\n- Older.\r\n"},
                "1.0.0"),
        }
        for label, (contents, version) in cases.items():
            with self.subTest(label):
                self.files({release.CHANGELOG: CHANGELOG, release.TOC: TOC, release.CORE: CORE})
                self.files(contents)
                before = {name: self.read(name) for name in FILES}
                with self.assertRaises(release.ReleaseError):
                    release.prepare(self.root, version)
                for name, text in before.items():
                    self.assertEqual(self.read(name), text)

    def test_notes(self):
        for message in ("feat(bag-space): show the stack total", "fix: trinket bar error",
                        "perf: no garbage per scan", "docs: rewrite the README",
                        "Old style subject", "chore(release): 0.5.17-beta"):
            self.commit(message)
        release.prepare(self.root, "0.5.17-beta")
        self.tag("0.5.17-beta")
        text = release.notes(self.root, "0.5.17-beta")
        self.assertTrue(text.startswith(
            "## What's new\n\n### Fixed\n- A fix.\n\n## Commits since 0.5.16-beta\n"))
        self.assertIn("### Features\n\n- **bag-space:** show the stack total (", text)
        self.assertIn("### Fixes\n\n- trinket bar error (", text)
        self.assertIn("### Performance\n\n- no garbage per scan (", text)
        # Newest first, like git log.
        self.assertIn("### Other changes\n\n- Old style subject (", text)
        self.assertIn("- rewrite the README (", text)
        self.assertNotIn("chore(release)", text)
        self.assertLess(text.index("### Features"), text.index("### Other changes"))

    def test_main_reports_errors(self):
        self.assertEqual(release.main(["prepare", "--version", "v1"]), 1)

    def test_bumps(self):
        cases = [
            ("patch", None, "0.5.17-beta"),
            ("minor", None, "0.6.0-beta"),
            ("major", None, "1.0.0-beta"),
            ("major", False, "1.0.0"),
            ("patch", True, "0.5.17-beta"),
        ]
        for bump, beta, expected in cases:
            with self.subTest(bump=bump, beta=beta):
                self.assertEqual(release.next_version("0.5.16-beta", bump, beta), expected)
        self.assertEqual(release.next_version("1.0.0", "minor", None), "1.1.0")
        self.assertEqual(release.next_version("1.0.0", "patch", True), "1.0.1-beta")

    def test_newest_tag_prefers_the_final_release(self):
        self.tag("1.0.0-beta")
        self.tag("1.0.0")
        self.assertEqual(release.newest_tag(self.root), "1.0.0")

    def test_heading_with_trailing_spaces(self):
        self.files({release.CHANGELOG: CHANGELOG.replace("## Unreleased", "## Unreleased  ")})
        self.assertEqual(release.prepare(self.root, "0.5.17-beta"), "0.5.17-beta")
        self.assertIn("## 0.5.17-beta\r\n", self.read(release.CHANGELOG))

    def test_errors_name_what_is_missing(self):
        self.files({release.CORE: "local ns = {}\r\n"})
        with self.assertRaisesRegex(release.ReleaseError, "has no ns.CODE_BUILD line"):
            release.prepare(self.root, "0.5.17-beta")

    def test_start_next_after_a_release(self):
        release.prepare(self.root, "0.5.17-beta")
        self.assertTrue(release.start_next(self.root))
        self.assertEqual(self.read(release.CHANGELOG),
                         "# Changelog\r\n\r\n## Unreleased\r\n\r\n"
                         "## 0.5.17-beta\r\n\r\n### Fixed\r\n"
                         "- A fix.\r\n\r\n## 0.5.16-beta\r\n\r\n- Old.\r\n")
        self.assertFalse(release.start_next(self.root))  # already there: no change

    def test_start_next_keeps_lf(self):
        self.files({release.CHANGELOG: "# Changelog\n\n## 1.0.0\n- Done.\n"})
        release.start_next(self.root)
        self.assertEqual(self.read(release.CHANGELOG),
                         "# Changelog\n\n## Unreleased\n\n## 1.0.0\n- Done.\n")

    def test_before_one_is_always_a_pre_release(self):
        with self.assertRaises(release.ReleaseError):
            release.prepare(self.root, bump="minor", beta=False)
        self.assertUnchanged()
        self.assertEqual(release.prepare(self.root, "0.6.0-alpha"), "0.6.0-alpha")

    def fetch(self, bodies):
        def fetch_body(root, number):
            return bodies[number]
        return fetch_body

    def test_changelog_from_descriptions(self):
        self.commit("fix(loot-feed): coins add up (#1)")
        self.commit("feat(qol): scrap list (#2)")
        # Wrote its own line, so its description is not read.
        self.files({release.CHANGELOG: CHANGELOG.replace("- A fix.", "- A fix.\r\n- By hand.")})
        self.commit("fix: by hand (#3)")
        self.commit("docs: no section (#4)")
        self.commit("chore: not a pull request")
        bodies = {
            "1": "## What does this PR do?\r\n\r\nStuff.\r\n\r\n## Changelog\r\n\r\n"
                 "<!-- Added:, Changed: or Fixed: -->\r\nFixed: Loot Feed: coins add up.\r\n\r\n"
                 "## Checklist\r\n- [x] Fixed: not an entry\r\n",
            "2": "## Changelog\n- added: Scrap List: Alt-click\n  to mark items.\n"
                 "Changed: Vendors.\n",
            "4": "## What does this PR do?\nDocs.\n",
        }
        release.prepare(self.root, "0.5.17-beta", fetch_body=self.fetch(bodies))
        self.assertEqual(self.read(release.CHANGELOG),
                         "# Changelog\r\n\r\n## 0.5.17-beta\r\n\r\n"
                         "### Added\r\n- Scrap List: Alt-click to mark items.\r\n\r\n"
                         "### Changed\r\n- Vendors.\r\n\r\n"
                         "### Fixed\r\n- A fix.\r\n- By hand.\r\n- Loot Feed: coins add up.\r\n\r\n"
                         "## 0.5.16-beta\r\n\r\n- Old.\r\n")

    def test_descriptions_fill_an_empty_unreleased(self):
        self.files({release.CHANGELOG: "# Changelog\n\n## Unreleased\n\n## 0.5.16-beta\n- Old.\n"})
        self.commit("chore: start the next changelog")
        self.commit("fix: one (#5)")
        text = "Fixed: " + " ".join(["word"] * 30)
        release.prepare(self.root, "0.5.17-beta",
                        fetch_body=self.fetch({"5": f"## Changelog\n{text}\n"}))
        changelog = self.read(release.CHANGELOG)
        self.assertTrue(changelog.startswith(
            "# Changelog\n\n## 0.5.17-beta\n\n### Fixed\n- word word"))
        self.assertTrue(changelog.endswith("word\n\n## 0.5.16-beta\n- Old.\n"))
        entry = changelog.split("### Fixed\n")[1].split("\n\n")[0].split("\n")
        self.assertEqual(len(entry), 2)
        self.assertTrue(all(len(line) <= 100 for line in entry))
        self.assertTrue(entry[1].startswith("  word"))

    def test_bad_description_names_the_pull_request(self):
        self.commit("fix: one (#6)")
        with self.assertRaisesRegex(release.ReleaseError, "#6: changelog lines start with"):
            release.prepare(self.root, "0.5.17-beta",
                            fetch_body=self.fetch({"6": "## Changelog\nLoot Feed fixed.\n"}))
        self.assertUnchanged()

    def test_pending(self):
        self.commit("feat: two (#7)")
        bodies = {"7": "## Changelog\nAdded: Two.\n"}
        self.assertEqual(release.pending(self.root, self.fetch(bodies)),
                         "## Unreleased\n\n### Added\n- Two.\n\n### Fixed\n- A fix.")
        self.assertUnchanged()

    def test_add_unreleased(self):
        count = release.add_unreleased(self.root, "Changed: BiS List: new picks.\nFixed: Two.\n")
        self.assertEqual(count, 2)
        self.assertEqual(self.read(release.CHANGELOG),
                         "# Changelog\r\n\r\n## Unreleased\r\n\r\n### Changed\r\n"
                         "- BiS List: new picks.\r\n\r\n### Fixed\r\n- A fix.\r\n- Two.\r\n\r\n"
                         "## 0.5.16-beta\r\n\r\n- Old.\r\n")

    def test_add_unreleased_without_lines_changes_nothing(self):
        self.assertEqual(release.add_unreleased(self.root, ""), 0)
        self.assertUnchanged()

    def beta_off_main(self, version):
        self.git("checkout", "-q", "--detach")
        self.commit(f"chore(release): {version}")
        self.tag(version)
        self.git("checkout", "-q", "-")

    def test_beta_counts_up_from_the_release(self):
        self.tag("1.0.0")
        self.commit("fix: one (#1)")
        self.assertEqual(release.beta_version(self.root), "1.0.1-beta.1")
        self.beta_off_main("1.0.1-beta.1")
        self.assertIsNone(release.beta_version(self.root))
        self.commit("fix: two (#2)")
        self.assertEqual(release.beta_version(self.root), "1.0.1-beta.2")

    def test_no_beta_right_after_a_release(self):
        self.tag("1.0.0")
        self.commit("chore: start the next changelog")
        self.assertIsNone(release.beta_version(self.root))

    def test_release_after_betas_counts_from_the_release(self):
        self.tag("1.0.0")
        self.commit("fix: one")
        self.beta_off_main("1.0.1-beta.1")
        self.assertEqual(release.prepare(self.root, bump="patch", beta=False, fetch_body=self.fetch({})),
                         "1.0.1")

    def test_stamp(self):
        release.stamp(self.root, "1.0.1-beta.1")
        self.assertIn("## Version: 1.0.1-beta.1\r\n", self.read(release.TOC))
        self.assertIn('ns.CODE_BUILD = "1.0.1-beta.1"\r\n', self.read(release.CORE))
        self.assertEqual(self.read(release.CHANGELOG), CHANGELOG)

    def test_beta_notes_are_the_unreleased_lines(self):
        self.commit("chore(release): 1.0.0")
        self.tag("1.0.0")
        self.commit("feat: two (#2)")
        self.beta_off_main("1.0.1-beta.1")
        text = release.notes(self.root, "1.0.1-beta.1",
                             self.fetch({"2": "## Changelog\nAdded: Two.\n"}))
        self.assertIn("### Added\n- Two.", text)
        self.assertIn("### Fixed\n- A fix.", text)
        self.assertIn("## Commits since 1.0.0", text)

    def test_body_entries(self):
        self.assertIsNone(release.body_entries(None))
        self.assertIsNone(release.body_entries("## Checklist\n- [x] Fixed: x\n"))
        self.assertEqual(release.body_entries("## Changelog\n<!-- Fixed: example -->\n"), [])
        self.assertEqual(release.body_entries("## Changelog\nFixed:\n"), [])
        self.assertEqual(release.body_entries("## Changelog\n* CHANGED:  A\nb\n\nFixed: C"),
                         [("Changed", "A b"), ("Fixed", "C")])

    def test_changelog_body(self):
        dev = {"body": "## Changelog\nDev-only: the workflow.\n", "labels": [{"name": "no changelog"}]}
        self.assertEqual(release.changelog_body(dev), "")
        self.assertEqual(release.body_entries(release.changelog_body(dev)), None)
        player = {"body": "## Changelog\nFixed: Loot Feed.\n", "labels": [{"name": "bug"}]}
        self.assertEqual(release.body_entries(release.changelog_body(player)), [("Fixed", "Loot Feed.")])
        self.assertEqual(release.changelog_body({"body": None, "labels": None}), "")

    def test_discord_payloads(self):
        changelog = ("## Unreleased\r\n\r\n## 1.0.7\r\n\r\n### Added\r\n- Healer Mana: a cup by\r\n"
                     "  anyone drinking.\r\n- Chat Zones.\r\n\r\n### Fixed\r\n- Co-Tank.\r\n\r\n## 1.0.6\r\n- Old.\r\n")
        posts = release.discord_payloads(changelog, "1.0.7")
        self.assertEqual(len(posts), 1)
        embed = posts[0]["embeds"][0]
        self.assertEqual(embed["title"], "Naowh Forever 1.0.7")
        self.assertEqual(embed["description"],
                         "**Added**\n- Healer Mana: a cup by anyone drinking.\n- Chat Zones.\n\n**Fixed**\n- Co-Tank.")
        self.assertEqual(embed["color"], 10181046)
        self.assertEqual(posts, [{"embeds": [embed]}])

        # Past the limit: split at a heading, numbered, nothing lost or reordered.
        posts = release.discord_payloads(changelog, "1.0.7", limit=70)
        self.assertEqual([p["embeds"][0]["title"] for p in posts],
                         ["Naowh Forever 1.0.7 (1/2)", "Naowh Forever 1.0.7 (2/2)"])
        texts = [p["embeds"][0]["description"] for p in posts]
        self.assertTrue(all(len(text) <= 70 for text in texts))
        self.assertEqual(texts[1], "**Fixed**\n- Co-Tank.")
        self.assertEqual("\n\n".join(texts), embed["description"])
        self.assertFalse(any("content" in p or "allowed_mentions" in p for p in posts))

        # One heading's list too long for a post: split between its lines, under its heading again.
        posts = release.discord_payloads(changelog, "1.0.7", limit=55)
        texts = [p["embeds"][0]["description"] for p in posts]
        self.assertTrue(all(len(text) <= 55 for text in texts))
        self.assertEqual(texts, ["**Added**\n- Healer Mana: a cup by anyone drinking.",
                                 "**Added**\n- Chat Zones.\n\n**Fixed**\n- Co-Tank."])

        with self.assertRaises(release.ReleaseError):
            release.discord_payloads(changelog, "9.9.9")
        with self.assertRaises(release.ReleaseError):
            release.discord_payloads(changelog, "1.0.7", limit=20)

    def test_prepare_with_bump_and_no_beta(self):
        self.assertEqual(release.prepare(self.root, bump="major", beta=False), "1.0.0")
        self.assertIn("## Version: 1.0.0\r\n", self.read(release.TOC))
        self.assertIn('ns.CODE_BUILD = "1.0.0"\r\n', self.read(release.CORE))


if __name__ == "__main__":
    unittest.main()
