# Tools

Scripts we run on our machines (and a few in CI) to build the addon's data, check it, and
ship it. None of this goes in the addon zip. Run everything from the repo root with Python
3.12 or Lua 5.1.

Why so many? The game client doesn't ship most of what the addon shows: who drops what,
quest chains and BiS lists all live on servers or websites. So we read them once, offline,
and ship the result as plain Lua data. The scripts keep that repeatable.

## Layout

| Folder | What it holds |
| --- | --- |
| `build/` | Every data generator: each writes one part of the addon's data (`python Tools/build/journal.py`). |
| `sources/` | The readers the builders share: the game's tables (`wago.py`), Wowhead (`wowhead.py`), wowsrc.com (`wowsrc.py`) and a client's own item cache (`items_in_game.py`). |
| `data/` | Every JSON input and cache the tools read and write, wowsrc's pages (`data/wowsrc_pages/`, not committed) and the two preset profiles (`preset_*.lua`). |
| `media/` | The scripts that draw the addon's textures and record its voice clips. |
| `release/` | Release, the daily build watch and the daily badge sync, run by the workflows. |
| `hooks/` | The checks pre-commit and the workflows run. |
| `regression/` | Offline Lua tests against stubs. |
| `nav/` | The walking maps Journeys plans walks on, baked from the client's terrain (Node; see `nav/README.md`). |
| `tests/` | Python tests for the tools. |
| `paths.py` | Where the tools, their data and the addon are. |

Each Python script starts by putting `Tools/` on the path and importing `paths`, which puts
`build/`, `sources/` and `release/` there too: `import wago` or `from journal import header`
works from any folder, and the tests import any tool the same way. `paths.ROOT` is the repo,
`paths.DATA` is `Tools/data/`. A new script does the same; don't add other `sys.path` tweaks.

The caches in `data/` (`*_cache.json`, `*.json`) keep every answer a build used. Delete an
entry to fetch it again. Be gentle with the sites: the scripts wait between requests on
purpose.

## build/: Dungeon Journal

| Tool | What it does | Why |
| --- | --- | --- |
| `journal.py` | Builds every dungeon's bosses and loot into `NaowhForever_DungeonJournal/Data/`. `--offline` asks Wowhead nothing (its cache and the game's tables only); `--refresh-drops` reads every boss's drops again for today's chances (both daily in CI). | The heart of the Journal. How it decides what a boss drops is drawn in `NaowhForever_DungeonJournal/README.md`. |
| `factions.py` | Builds the Reputation and PvP tabs from `data/journal_factions.json` and the game's own item tables. | Rewards, standings and prices are in the client, so we read them from there, not a website. |
| `quest_chains.py` | Builds each dungeon quest's chain and what you need first, from Wowhead Forever. | So the Journal can say "do this first". |
| `abilities.py` | Builds `NaowhForever_DungeonJournal/Data/Abilities.lua` (each boss's spell IDs, each name once) and `BossInfo.lua` (its level, classification, creature type and title) from its Wowhead Forever NPC page. Cached in `data/abilities_cache.json`; `--offline` writes what the cache has. | A boss's page shows its abilities and header. The game gives each spell's name, icon and description. |
| `boss_quests.py` | Builds `NaowhForever_DungeonJournal/Data/BossQuests.lua`: the dungeon quests whose objective on Wowhead Forever names or links a boss. Cached in `data/quest_objectives_cache.json`. | A boss's page lists the quests that need it. |

## build/: BiS List

| Tool | What it does | Why |
| --- | --- | --- |
| `bis_data.py` | Builds `NaowhForever_BiS/BiS/Data/BiS.lua` from wowsrc.com's per-spec BiS pages. Item IDs are cached in `data/bis_item_ids.json`. `--check` says what changed on their pages, `--offline` builds without Wowhead, `--sources-only` fills a new pick's source from Wowhead (all daily in CI). | The BiS List's picks, with permission from wowsrc. |
| `bis_spots.py` | Builds `NaowhForever_BiS/BiS/Data/Spots.lua`: where the NPC that drops or sells a BiS item stands out in the world, from Wowhead's item and NPC pages. Cached in `data/bis_spots.json`. | The BiS List's Run Next puts a waypoint on them. |
| `enchants.py` | Builds `NaowhForever_BiS/BiS/Data/Enchants.lua`: every Enchanting recipe, what it gives and goes on, from the game's tables (wago.tools), and the skill it needs and who teaches it, from Wowhead (cached in `data/enchant_recipes.json`). | The BiS List's best enchant for what you wear. |
| `bis_quests.py` | Builds `NaowhForever_DungeonJournal/Data/BiSQuests.lua`: every quest that rewards a ranked BiS item, from Wowhead's item pages ("Reward from") and quest pages (where it starts, who can take it). Cached in `data/bis_quests.json` and `data/bis_quest_pages.json`. Run `quest_chains.py` after it. | The BiS List's Quests page. |

## build/: Naowh Score

| Tool | What it does | Why |
| --- | --- | --- |
| `fit_naowh_score.py` | Fits the Naowh Score's constants (`NaowhForever_BiS/NaowhScore/Data/Formula.lua`: slot weights, each quality's worth in epic item levels) to a Forever build's own item table through wago.tools: ItemSparse's stats (`StatModifier_bonusStat_N` and `StatPercentEditor_N`, with `ItemLevel`, `OverallQualityID`, `InventoryType`), RandPropPoints' budgets and ItemDamageOneHand's DPS. Prints a report (`--report`); `--write` rewrites `Formula.lua` only when the fit passes its quality gates and a slot moves 0.02 or a quality's worth at item level 60 moves 0.5. `--build`, `--cache DIR`, `--bootstrap N` (the report's intervals, seeded). The method is in its docstring and `NaowhForever_BiS/NaowhScore/README.md`. | So the score follows the game's own numbers, build after build, with nothing read from Wowhead. |

## build/: Training Planner

| Tool | What it does | Why |
| --- | --- | --- |
| `training_weapons.py` | Builds `NaowhForever_Training/Data/TrainingWeapons.lua`: the weapon skills each class can learn and the weapon masters that teach them, from the masters' Wowhead Forever NPC pages (cached in `data/training_weapons_cache.json`), with the level a class may learn one at from the game's tables (via `wago.py`). | Wowhead's class lists leave the weapon skills out. |
| `training_builds.py` | Builds `NaowhForever_Training/Data/TrainingBuilds.lua`: each class's talent trees, every talent's first rank spell, ranks, row, tree, column and the talent it needs, from the game's own talent tables (TraitNode, TraitNodeEntry, TraitDefinition, TraitEdge, via `wago.py`). Talents the game parks outside the grid are left out. Run it again when a patch changes a tree. | The planner shows and checks every class's tree, and builds imported from naowh.gg carry these node IDs, so they must match the game. |
| `training.py` | Builds `NaowhForever_Training/Data/TrainingData.lua`: every spell each class learns from a trainer or a quest, with its level, base price, the rank before it, the talent it needs and its races. Spells, levels and prices from Wowhead Forever's class lists (cached in `data/training_cache.json`), talents from the game's tables (via `wago.py`). | The client has no list of what a trainer will teach you later, nor its prices. The addon updates a price from the trainer window once you open it. |

## build/: Completo

| Tool | What it does | Why |
| --- | --- | --- |
| `completo_quests.py` | Builds `NaowhForever_DiscoveryData/Quests.lua`: every quest of every zone, its chain and where its quest giver stands, from Wowhead Forever's zone and quest pages. Cached in `data/completo_zones.json`, `data/completo_quests.json`, `data/completo_requires.json` and `data/completo_items.json`; `--offline` writes from the caches only. | A zone's quests and what to do first. |
| `completo_rares.py` | Builds `NaowhForever_DiscoveryData/Rares.lua`: every rare of every zone, where it spawns and its special drops. Cached in `data/completo_rares.json`; `--offline` writes from the caches only. | The rares worth hunting, on the map. |

## build/: World and town map

| Tool | What it does | Why |
| --- | --- | --- |
| `map_overlays.py` | Builds `NaowhForever_QoL/Interface/MapOverlays.lua`: every explorable area of each zone map and its tiles, from the game's tables (wago.tools). Run it again when `wago.BUILD` moves on. | The game only tells addons the areas you have explored; Unexplored Areas draws the rest. |
| `mailboxes.py` | Builds `NaowhForever_QoL/Interface/TownMailboxes.lua` from Wowhead Forever's mailbox pages (cached in `data/mailbox_cache.json`). | The town map's mailbox pins. |
| `spirit_healers.py` | Builds `NaowhForever_QoL/Interface/TownSpiritHealers.lua` from the Spirit Healer's Wowhead page. | The game won't list graveyards while you are alive. |
| `travel.py` | Builds `NaowhForever_QoL/Interface/TownTravel.lua`: the boats' and zeppelins' docks, from the game's taxi paths (wago.tools). | The town map's boat and zeppelin pins. |
| `journeys.py` | Builds `NaowhForever_Utilities/Journeys/Data/Network.lua`: every flight point with who can use it, every direct flight's flown length, each boat's and zeppelin's docks with its stop and sailing distance, and the tram and the Darnassus portal, from the game's tables (wago.tools). Run it again when `wago.BUILD` moves on. Lifts are not in the client's tables: they go in `LIFTS` by hand, from what `/nf lifts` prints in game. | The Journeys planner's network. |
| `transport.lua` | Builds `NaowhForever_QoL/Travel/TransportData.lua` from Journeys' generated network and speed constants, with the published cycle times it lists: `lua5.1 Tools/build/transport.lua`. Rebuild after changing that network or its speeds. | Single-sighting boat and zeppelin estimates in QoL, without loading Journeys. |
| `journeys_quests.py` | Builds `NaowhForever_JourneysData/QuestSpots.lua`: where each Quest List quest is handed in, and the camps of its objectives, from the map on its Wowhead Forever page. Cached in `data/journeys_quest_spots.json`; `--offline` writes from the cache only. | A tracked quest the game marks nowhere still has somewhere to go. |
| `same_maps.py` | Builds `Shared/Data/SameMaps.lua`: the maps the game has under two IDs (the same name, continent and bounds), each to the one with a parent map, whose data it reads, from the game's tables (wago.tools). Run it again when `wago.BUILD` moves on. | Zephras Isle is 2521 and 2665; the addon's data is keyed by 2521. |
| `zone_exits.py` | Builds `NaowhForever_QoL/Interface/ZoneExits.lua`: where the roads cross from one zone into the next, from Wowhead's zone grid and the game's map tables. | Forever has no map link data. |

## build/: the rest

| Tool | What it does | Why |
| --- | --- | --- |
| `daily_word.py` | Builds `NaowhForever_QoL/Travel/DailyWordData.lua`: the Daily Word's answers, shuffled once with a fixed seed, and every word it accepts, from 12dicts and ENABLE (both public domain, downloaded each run). Rebuilding changes past days' words if the sources or its choices change. | One word a day for everyone without a server. |
| `forever_new.py` | Builds `Shared/Data/Forever.lua`: the items, quests and NPCs Wowhead marks as new in Forever, the ones our data mentions. Cached in `data/forever_new.json` (`--refresh` asks again). | The addon's Forever mark. |
| `spell_efficiency.py` | Builds `NaowhForever_QoL/Interface/SpellEfficiencyData.lua`: every class spell rank that costs mana and heals or deals damage, its amounts (base, per level, bonus coefficient, ticks), level and school, from the game's spell tables (wago.tools). Also each spell's talent mods (percent talents by rank, Illumination, Elemental Focus), read through the talent nodes in `NaowhForever_Training/Data/TrainingBuilds.lua`. Spells whose amount is elsewhere (weapon, proc, script) are left out; area triggers (Blizzard, Consecration) and Holy Shock are read from the spell their description names. Run it again when `wago.BUILD` moves on. | QoL's Mana Efficiency, without reading tooltip text. |
| `pvp_auras.py` | Builds `NaowhForever_Combat/PvP/Data/Spells.lua`: PvP Auras' crowd control and debuff spell IDs, from the game's spell tables (wago.tools). | Forever's classic spells carry no aura flags to filter by. |
| `skill_thresholds.py` | Writes each recipe's yellow and grey skill into `NaowhForever_Professions/Data/RecipeData.lua`, from the game's `SkillLineAbility` table (wago.tools); `--csv` reads a saved copy instead. Run it again when `wago.BUILD` moves on, or after adding recipes. | The Professions Skill-up Thresholds bar. |
| `presets.lua` | Writes `Core/Profiles/Presets.lua`, the setups a player can start from, one preset at a time: `lua5.1 Tools/build/presets.lua minimalist Tools/data/preset_minimalist.lua Naowh` (and `recommended`). | Naowh's two setups, kept in `data/` and rebuilt from there. |
| `search_index.lua` | Writes `NaowhForever_SearchIndex/SearchIndex.lua`, every module page's search entries, by running every addon file against stubs: `lua5.1 Tools/build/search_index.lua`. Git keeps an empty placeholder; the release and package workflows build the real one over it before packaging, and `test-search-index-build.lua` checks it builds. | A turned-off module never loads, so the search reads its settings from here. |

## sources/

| Tool | What it does | Why |
| --- | --- | --- |
| `wago.py` | Reads the game's own tables (DB2) for a Forever build from wago.tools, hotfixes included. `BUILD` is the build our data comes from. | The one source that is the game itself. |
| `wowhead.py` | Not a build: reading Wowhead's Forever pages (a polite `fetch`, listviews, a dungeon guide's loot) and writing Lua strings, for the tools that do. | Shared by the builders, `release/watch_build.py` and `wowsrc.py`. |
| `wowsrc.py` | Reads wowsrc.com's Forever loot pages into `data/wowsrc_loot.json`. `--resolve` maps their item names to IDs in `data/item_names.json` (`--offline`: without Wowhead). `--check` says what changed on their pages since (daily in CI). | Wowhead hasn't tied Forever's new items to bosses yet; wowsrc has. They gave us permission. |
| `items_in_game.py` | Writes `data/items_in_game.json`: the items a Forever client was sent, and refused, from its hotfix cache (`--cache`) and the Journal's `/nf itemprobe` (`--probe`, its SavedVariables). With neither, both are read from a Windows install. | wago.tools lacks some items the server sends; the build lists those as in the game. Run on a machine with the client, then commit the JSON. |

## data/

| File | What it is |
| --- | --- |
| `journal_bosses.json` | The bosses per dungeon, in kill order, with rares, optional bosses, chests and hand fixes. Kept by hand: no source has the right list for Forever. |
| `journal_factions.json` | The Journal's factions, with rewards added or removed by hand on top of the game's. |
| `journal_cache.json`, `wowsrc_loot.json`, `item_names.json` | Every Wowhead answer the Journal's build used; wowsrc's pages as last read; their item names to IDs. Committed, so a rebuild (and CI) gives the same data without asking again. |
| `preset_minimalist.lua`, `preset_recommended.lua` | Naowh's two setups, the input of `build/presets.lua`. |
| Every other `*.json` | The cache of the builder that names it above. |

## media/

| Tool | What it does |
| --- | --- |
| `make_media.py` | Draws our icons into `Core/Media/*.tga`, and the RestedXP themes' art into `Core/Integrations/RestedXP/Media/`. Change an icon in its function, then run it. |
| `make_navigation.py` | Draws the navigation glyphs into `Core/Media/Navigation/`. |
| `make_rxp_icons.py` | Draws RestedXP's step icons, in a line and a filled style, into `Core/Integrations/RestedXP/Media/Icons/`. Change a glyph in its table, then run it. |
| `generate-voice-clips.ps1` | Rebuilds the English voice clips in `Core/Media/Voice/` on Windows. |

## release/, hooks/ and the tests

| Tool | What it does |
| --- | --- |
| `release/release.py` | Release helper for `.github/workflows/release.yml`: version bump, notes, changelog (from the merged PRs' descriptions). |
| `release/watch_build.py` | Compares a new Forever build with ours: faction rewards, kill-count encounters, new dungeons, new dungeon floor maps, new gear the Journal doesn't list yet. `--update` moves us to it. Runs daily in CI (`.github/workflows/daily-watch.yml`), so a new build never sneaks past us. |
| `release/sync_badges.py` | Writes `Core/Badges/Patrons.lua` from naowh.gg's list of Legendary and Epic patrons, daily in `.github/workflows/badges.yml`. |
| `regression/` | Offline Lua tests against stubs. `bash Tools/regression/run-all.sh` runs them all (set `LUA=` to your lua.exe). `load_files.lua` loads a module's real files into a test, `shared_places.lua` gives a stubbed test the real `Places` and its map aliases, `measure.lua` times a draw and fails on garbage, `toc_files.lua` lists what the TOCs load. |
| `tests/` | Python tests for the tools: `python -m unittest discover -s Tools/tests`. |
| `hooks/check-pr.sh` | PR rules: a changelog line in the PR description for addon changes, TOC version untouched. |
| `hooks/check_toc.py`, `hooks/toc_files.py` | Every file the TOCs load (the core's and each module addon's, following their XML files) exists, with the right letter case. |
| `hooks/check-package.sh` | The built zip has `NaowhForever/` and each module addon's folder (`.pkgmeta`'s `move-folders`) at the top, everything they load, and no tooling. |
| `hooks/daily-pull-request.sh` | The daily watch's one pull request: `add` commits what a check changed, `open` squashes them into one commit (a title saying what is in it, a short list) and opens the PR or brings the open one up to date, with the checks' changelog lines under `## Changelog` in its description (labelled `no changelog` when there are none), or an issue with a link where workflows may not open PRs. |

## What CI runs

- **Every PR** (`checks.yml`, and `pr-title.yml` for the PR rules and title): luacheck and
  pre-commit, the Lua regression tests, the Python tests, PR rules, the title, and a package check.
- **Daily** (`daily-watch.yml`), four checks, one after another on one branch, each on what
  the one before changed. Whatever they change goes in **one** pull request, as one commit (we
  squash merge): its title says what is in it (`chore(data): WoW Forever build 1.60.1.70205,
  boss loot and BiS lists`), its description lists the changes, their lines for players under
  `## Changelog` (labelled `no changelog` when there are none; CHANGELOG.md is left to the
  release), and each check's report folded away (`hooks/daily-pull-request.sh`, which keeps it
  up to date). A check that fails leaves out only its own change, and the run says so. A new
  BiS pick neither wowsrc nor Wowhead has a source for keeps the pull request a draft that
  says what to do. A change CI cannot make at all (wowsrc lists
  items the game's tables don't have yet) goes in one issue, "Daily data: changes that need a
  run on our machines", with what to run; the first run with nothing stuck closes it. Where
  workflows may not open a pull request, an issue with a one-click link:
  - `watch`: `release/watch_build.py`. Only reads the game's tables through wago.tools. If
    there's a new build, the change moves our faction data to it, with a report of what
    changed (new gear the Journal doesn't list yet, new dungeon floor maps in the game's map
    table). The same change refits the Naowh Score (`build/fit_naowh_score.py --write`):
    `Formula.lua` changes when the constants move enough, with a changelog line (every
    player's score moves), and the report gets a "Naowh Score" section (old against new, the
    fit's quality, its gates). A manual run reports it too; a failed fit only says so.
  - `loot`: `sources/wowsrc.py --check`. If wowsrc's loot pages changed (a boss gained or lost
    items, a new boss or page), it rebuilds the Journal with `build/journal.py --offline`.
  - `drops`: `build/journal.py --refresh-drops`. Every boss's and chest's drops read again from
    Wowhead Forever, so the chances follow today's kill counts. A change only when a chance
    moved a whole percent, or an item came or went.
  - `bis`: `build/bis_data.py --check`, the same for wowsrc's BiS lists, then
    `build/bis_data.py --sources-only` for a new pick's source from Wowhead.

  `--offline` asks Wowhead nothing: a new item's facts come from the game's own tables, and
  what they can't settle (an old classic item) is listed in the PR for a run on our machines.
- **Daily** (`badges.yml`): `release/sync_badges.py`.
- **Wowhead in CI:** only the daily `drops` check and the BiS sources, one page at a time at
  `wowhead.fetch`'s pace (a second apart, backing off on a 403). GitHub's runners can read it
  (checked on 11 Oct 2026). Everything else that reads Wowhead stays off CI and runs on our
  machines, by hand: `build/quest_chains.py`,
  `build/bis_spots.py`, `build/enchants.py`, `build/bis_quests.py`, `build/abilities.py`,
  `build/boss_quests.py`, the Completo and town map builders that read Wowhead, and
  `build/forever_new.py`.
