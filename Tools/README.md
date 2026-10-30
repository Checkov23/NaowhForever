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
| `sources/` | The readers the builders share: the game's tables (`wago.py`), Wowhead (`wowhead.py`), wowsrc.com (`wowsrc.py`), the recipes bosses drop (`recipe_drops.py`) and a client's own item cache (`items_in_game.py`). |
| `data/` | Every JSON input and cache the tools read and write, wowsrc's pages (`data/wowsrc_pages/`, not committed) and the two preset profiles (`preset_*.lua`). |
| `media/` | The scripts that draw the addon's textures and record its voice clips. |
| `release/` | Release, the daily build watch and the daily badge sync, run by the workflows. |
| `hooks/` | The checks pre-commit and the workflows run. |
| `regression/` | Offline Lua tests against stubs. |
| `dev/` | Development addons loaded into the game by hand, never shipped (`dev/QuestPositions/`, see its README). |
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

## Scout and quest data without Wowhead requests

`build/data_bundle.py` imports an approved JSON export into the existing caches. It never
makes HTTP requests. This supplies an alternate input route; it does not unlock Wowhead or
provide fresh data by itself. Ask the data owner for an export in the format below, or adapt
their supplied export to it. Do not substitute Classic coordinates for Forever coordinates.

From the repo root:

```sh
python Tools/build/data_bundle.py --report missing-data.json
python Tools/build/data_bundle.py --export-file cache-snapshot.json
python Tools/build/data_bundle.py --import-file approved-data.json
python Tools/build/data_bundle.py --import-file approved-data.json --apply --report missing-data.json
python Tools/build/completo_quests.py --offline
python Tools/build/journeys_quests.py --offline
python Tools/build/scout.py --offline --dump /path/to/classic.sql.gz
```

The import previews by default. It validates the entire bundle before writing and merges
by record ID. Existing records win; use `--replace` with `--apply` when intentionally
refreshing them. A zone is one record: replacing a zone replaces its whole NPC or quest
list. Omitted records and sections stay intact. Individual writes use temporary files and
rename; a later write failure rolls earlier writes back. This is not a transaction across
a power failure, so retain the source export and review the Git diff before committing.

`--offline` on Scout skips Wowhead only. It still needs the Classic database dump and the
SpellName and ExpectedStat tables from wago.tools. It cannot run entirely without network
access unless those other inputs are supplied separately. If a live zone request fails,
Scout uses remaining cached zones; if an NPC request fails, it saves successful records and
builds from the cache rather than waiting through repeated 15-minute cooldowns. The shared
fetcher's bounded retries still apply to live requests.

The report lists missing IDs for the current zone lists, cached quests and Journal bosses.
It separates uncollected quest-map pages from successfully collected pages with no points.
Missing Scout NPC pages do not mean missing abilities: the Classic database may supply them.
It cannot discover unknown content, verify freshness, or prove completeness. Item-started
quest and dungeon/elsewhere auxiliary caches retain their existing inputs.

A bundle is versioned, Forever-specific JSON with a source description:

```json
{
  "version": 1,
  "edition": "forever",
  "source": "Owner-provided export, build and date",
  "data": {
    "scout": {
      "npcs": {"2850": {"abilities": [[3009, "Claw"]], "tameable": true}},
      "zones": {"1": [{"id": 448, "name": "Hogger"}]}
    },
    "quest_zones": {
      "44": {"name": "Redridge Mountains", "quests": [
        {"id": 65, "name": "The Defias Brotherhood", "level": 18, "reqlevel": 14, "side": 1}
      ]}
    },
    "quests": {"65": {"chain": null, "start": null}},
    "prerequisites": {"65": {"quests": [132]}},
    "quest_spots": {"65": []}
  }
}
```

These are format examples, not a verified quest/NPC relationship or an authoritative export.
Every section is optional; include only supplied data. Sections use the corresponding cache
shape: `scout.json`, `completo_zones.json`, `completo_quests.json`, `completo_requires.json`
and `journeys_quest_spots.json`. `cache-snapshot.json` is a local format reference, not a
new upstream export. It converts the legacy missing-coordinate sentinel `[""]` to `null`
in the snapshot only.

A quest's `chain` is `null` or `{"chain": [[10], [110]], "names": {"10": "First", "110": "Next"}}`.
Its `start` is `null` or `{"zone": 44, "coord": [20, 40], "npc": "Giver", "npcId": 123}`.
Prerequisites are `null` when known absent, otherwise `{"quests": [123]}`. Quest spots are
a list of `{"point": "end", "zone": 44, "id": 123, "name": "Giver", "coords": [[20, 40]]}`;
the other point kinds are `requirement`, `sourcerequirement`, `entrance` and `end_choice`. Zones here are AreaTable
IDs, not uiMapIDs. Positions are percentages on the source map expected by the existing
builder: Journey objective/turn-in points use Forever maps, while quest-start coordinates
retain the existing builder's Classic-to-Forever conversion on redrawn maps. Confirm the
coordinate convention with the provider before importing. Empty lists and nulls mean known
absence; omit an ID when it has not been collected.

### Permitted entity exports

`build/quest_entities.py` converts a permitted, named-field entity JSON export into a bundle
of missing quest-map and prerequisite records. It makes no requests and writes candidates
outside `Tools/data`; the bundle importer applies them after review:

```sh
python Tools/build/quest_entities.py --input entities.json --bundle quest-candidates.json --report quest-coverage.json
python Tools/build/data_bundle.py --import-file quest-candidates.json --replace --apply
python Tools/build/completo_quests.py --offline
python Tools/build/journeys_quests.py --offline
```

The input has `version: 1`, `edition: "forever"`, `coordinate_space: "forever"`, `source`
and `build` descriptions, and an `entities` object with `quests`, `npcs`, `objects` and
`items`. Each entity collection is keyed by numeric ID strings and holds named fields.
An array may instead be an object with numeric position strings, preserving sparse groups.
Obtain the export and reuse permission from its owner; no provider code is required here.

Quest fields used are `finishedBy` (NPC IDs in group 1, object IDs in group 2), `objectives`
(NPC/object/item tuples in groups 1/2/3, each tuple's first value its entity ID),
`preQuestGroup` (all required) and `preQuestSingle` (any one required). NPCs and objects
use `name` and `spawns: {"44": [[20, 40]]}`. Items use `npcDrops` and `objectDrops` ID lists.
Areas are AreaTable IDs. Spawns are already Forever map percentages; conditional spawn
tuples with a third, nonzero phase value are withheld. Unsupported map IDs and instance
sentinels never become exact objective coordinates. Alternative turn-ins are accepted only
when every actor has locations and all locations fit one camp, at most four map percentage
points apart; the chosen point is an actual recorded spawn. Separated and conditional
alternatives, including seasonal moves, remain withheld.

More than three drop sources are withheld unless the item is explicitly a quest item
(class 12) and sources are located in the quest's explicit, supported outdoor zone. These
filtered points carry `quest_item: <itemID>` and bypass the broad world-drop guard; ordinary
commodities retain the guard. `triggerEnd`'s coordinate map (slot 2), and `extraObjectives`'
coordinate maps (slot 1) and explicit monster/object references (slot 5), can supply objective
points. Reputation or other unprojected objective types never become invented coordinates.

For a quest explicitly categorized in a dungeon, `journal_bosses.json` supplies its reviewed
outdoor entrance. This is a separate `entrance` point, not a turn-in or interior objective.
The generated row has optional slot 3 containing entrance positions; Journeys uses it only
while the quest is incomplete and no exact destination was found. Entrance guidance works
without the Dungeon Journal addon loaded. The report distinguishes this evidence.

Reviewed alternative turn-ins use `end_choice` with `coordinate_space: "forever"` and an
explicit `side` of `A`, `H` or `AH`. Generated slot 4 holds `{ uiMapID, x, y, side }` choices;
slot 3 is present even when empty. Journeys chooses the nearest candidate for the player's
faction when the quest is complete or has no objective camps. Ordinary objective camps
take priority while the quest is unfinished. This format is only for valid alternatives;
seasonal moves, class-specific variants and unresolved conditional NPC states must be
withheld or resolved before import. A pickup coordinate is never promoted to a turn-in.

By default only known quest IDs with empty or absent map records receive candidates.
`--fill-unroutable` also proposes replacements for populated records that produce neither
an exact destination nor entrance guidance. Apply that bundle with `--replace`; the report
lists every replaced ID. Existing usable records stay intact, and a replacement must itself
produce usable output. Prerequisites are supplied only where the cache has no record;
disagreements with existing records are reported for review. Negative prerequisite IDs
have special active-quest semantics and are withheld. Missing fields never establish that
a quest has no prerequisites. Text, breadcrumbs and quest titles are not used to infer them.

Explicit prerequisite records carry both `quests` (the flat dependency IDs for the chain
graph) and `groups` (all elements required, with a nested list meaning any one). For
example, `{"quests": [10, 11, 12], "groups": [10, [11, 12]]}` requires 10 and either 11 or
12. These groups bypass the old same-name heuristic; unrelated existing chain requirements
are preserved. Imported map points carry `coordinate_space: "forever"` so the legacy
mixed-map heuristic cannot move them again.

To import the complete source catalog, add `--full-catalog`:

```sh
python Tools/build/quest_entities.py --input entities.json --full-catalog --bundle catalog-bundle.json --report catalog-coverage.json
python Tools/build/data_bundle.py --import-file catalog-bundle.json --replace --apply
python Tools/build/completo_quests.py --offline
python Tools/build/journeys_quests.py --offline
```

`data/quest_entity_catalog.json` retains every source quest, including its original named
fields. The Quest List builder supplements its reviewed zone/dungeon/class records from
this catalog without replacing existing quest names, levels or race/class restrictions.
It first uses a supported source zone category, then a single supported starter zone.
Records without a supported zone stay searchable in Unsorted Quests, a list group with map
ID 0; no waypoint is assigned to that group. A single unphased, unambiguous starter can
supply a quest-giver position. Repeatable flags are retained. Existing source page caches
stay separate; a missing fetched page does not mean missing catalog metadata.

The generated quest list continues to exclude explicitly unused/unimplemented titles;
these records remain in the import cache for inventory accounting. The Journey builder
also considers the full catalog when generating destinations. Entries without usable
location evidence remain cataloged without a generated destination. Static catalog
membership does not establish in-game availability, and the source's profession,
reputation, exclusivity and other special conditions are retained in `source_fields` for
later validation rather than fully implemented as new availability rules here.

The current mapping additions for Mount Hyjal, Riverglades, Darkspear Islands and
Shen'dralas were checked against build 1.60.1.70450's UiMapAssignment and UiMap tables.
A supported map with no source quests, such as Mount Hyjal in this snapshot, is not evidence
that the zone has no quests. Self-referential prerequisite records are withheld and named
in the conversion report. Reviewed auxiliary quest prerequisites remain authoritative.

The coverage report distinguishes absent page caches from `quest_metadata_missing` and
counts `entity_catalog_records`. Keep import receipts and permission records outside the repository.

### Scout's scripted Classic baseline

`data/scout_script_spells.json` lists reviewed combat casts for twelve Molten Core script
names, from the pinned CMaNGOS source linked in the file. Only spell IDs are recorded;
no server code is embedded. The database's exact `ScriptName` joins them to creatures.
Boss spells and add spells remain separate. Commented-out spells, submerge/emerge visuals
and summon visuals are excluded. Ordinary database spell lists keep their current priority.
A cached creature page, including a known-empty ability list, takes priority over this
fallback. A future source update can therefore replace a Classic assumption.

This is Classic encounter evidence, not an in-game verification of Forever bosses. Every
spell still passes the Forever client's SpellName check and the existing cleanup. The
baseline adds no new creature stats, immunity claims or tameability flags.

```sh
python Tools/build/scout.py --offline --report scout-missing.json
```

The report identifies creatures supplied by that fallback, uncollected ability records,
cached records without usable spells and script spells the client lacks. It records the
client-table build and baseline source so future collection can target the remaining gaps.

`data/scout_ability_supplement.json` adds a lower-priority Classic ability baseline for
338 creatures whose lists were empty. Existing usable abilities and explicit cached
pages, including empty pages, remain authoritative. Pet-family overlaps, quest effects
and internal helper spells were withheld. These numeric spell records add no stats,
tameability or quest guidance and are not verified Forever encounter behavior. Client
spell validation and rank cleanup also apply to this fallback. The generated report's
`supplemental_ability_creatures` identifies the records actually used.

### Scout's instance coverage

The generator includes each resolved boss, rare and optional NPC in the Journal's
cached name lookups, in addition to its explicit NPC IDs and cached zone rosters.
This prevents a missing zone listing from dropping an already identified boss.

`data/abilities_cache.json`, the Journal's existing NPC-page cache, fills ability
lists that remain empty after Scout's current sources. Explicit Scout pages,
including empty pages, and previously usable lists retain their priority.
`data/scout_instance_records.json` supplies reviewed extra instance identities and
numeric cast records. It includes Forever beta casts linked in the published
Dalaran guide and additional Classic combat records from a second database.
The source URLs and Classic scope are recorded in that file. Internal targeting
helpers, spell casts by substituted sources and unsupported client spell IDs are
excluded. The original database still supplies stats for newly included Classic
NPCs; ability records do not supply armor, immunity or tameability claims.

The build report separates `journal_ability_creatures` from
`reviewed_instance_ability_creatures` and lists selected instance NPCs still
without abilities or stats. These counts are not a complete Forever spawn census:
new-instance trash rosters are incomplete, and some creatures have no spells.
Speculative raid spell associations based on names or neighbouring client rows
are not included. Classic baseline values remain unverified for Forever.

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
| `training_builds.py` | Builds `NaowhForever_Training/Data/TrainingBuilds.lua`: each class's talent trees, every talent's first rank spell, ranks, row, tree, column and the talent it needs, from Wowhead Forever's talent calculator data (`nether.wowhead.com/forever/data/talents-classic`), which has the beta's hotfixes before the game's own talent tables do. Run it again when a patch or hotfix changes a tree. | The planner shows and checks every class's tree, and builds imported from naowh.gg carry these node IDs, so they must match the game. |
| `training.py` | Builds `NaowhForever_Training/Data/TrainingData.lua`: every spell each class learns from a trainer or a quest, with its level, base price, the rank before it, the talent it needs and its races. Spells, levels and prices from Wowhead Forever's class lists (cached in `data/training_cache.json`), talents from Wowhead Forever's talent calculator. | The client has no list of what a trainer will teach you later, nor its prices. The addon updates a price from the trainer window once you open it. |

## build/: Completo

| Tool | What it does | Why |
| --- | --- | --- |
| `completo_quests.py` | Builds `NaowhForever_DiscoveryData/Quests.lua`: every quest of every zone, its chain and where its quest giver stands, from Wowhead Forever's zone and quest pages. Cached in `data/completo_zones.json`, `data/completo_quests.json`, `data/completo_requires.json` and `data/completo_items.json`; `--offline` writes from the caches only. | A zone's quests and what to do first. |
| `elsewhere_quests.py` | Builds `data/completo_elsewhere.json`, which `completo_quests.py` reads: the class, dungeon and battleground quests no zone page lists, from CMaNGOS's quests that Forever's client has, placed from Wowhead's quest pages or, failing those, where the game client puts the giver's spawn (`dev/QuestPositions/`, kept in `data/completo_positions.json`). `--offline` fetches nothing; `--positions` writes the spawns for the dev addon to resolve; `--resolved <file>` reads its answers. | The quests Wowhead files under a class or an instance, on the map too. |
| `completo_rares.py` | Builds `NaowhForever_DiscoveryData/Rares.lua`: every rare of every zone, where it spawns and its special drops. Cached in `data/completo_rares.json`; `--offline` writes from the caches only. | The rares worth hunting, on the map. |

## build/: World and town map

| Tool | What it does | Why |
| --- | --- | --- |
| `map_overlays.py` | Builds `NaowhForever_QoL/Interface/MapOverlays.lua`: every explorable area of each zone map and its tiles, from the game's tables (wago.tools). Run it again when `wago.BUILD` moves on. | The game only tells addons the areas you have explored; Unexplored Areas draws the rest. |
| `mailboxes.py` | Builds `NaowhForever_QoL/Interface/TownMailboxes.lua` from Wowhead Forever's mailbox pages (cached in `data/mailbox_cache.json`). | The town map's mailbox pins. |
| `spirit_healers.py` | Builds `NaowhForever_QoL/Interface/TownSpiritHealers.lua` from the Spirit Healer's Wowhead page. | The game won't list graveyards while you are alive. |
| `travel.py` | Builds `NaowhForever_QoL/Interface/TownTravel.lua`: the boats' and zeppelins' docks, from the game's taxi paths (wago.tools). | The town map's boat and zeppelin pins. |
| `journeys.py` | Builds `NaowhForever_Utilities/Journeys/Data/Network.lua`: every flight point with who can use it, every direct flight's flown length, each boat's and zeppelin's docks with its stop and sailing distance, and the tram and the Darnassus portal, from the game's tables (wago.tools). Run it again when `wago.BUILD` moves on. Lifts are not in the client's tables: they go in `LIFTS` by hand, from what `/nf lifts` prints in game. | The Journeys planner's network. |
| `transport_routes.py` | Builds `NaowhForever_QoL/Travel/TransportRoutes.lua` from NauticusClassic's `data.lua` (MIT, github.com/psynct/NauticusClassic at 504bc4c): `python Tools/build/transport_routes.py path/to/data.lua`. It fits their whole-world map to world yards on the docks shared with `TransportData.lua` and stops if a dock is 20 yards out. | The seven ships timed from a ride in QoL, with their measured round trips. |
| `transport.lua` | Builds `NaowhForever_QoL/Travel/TransportData.lua` from Journeys' generated network and speed constants, with the published cycle times it lists: `lua5.1 Tools/build/transport.lua`. Rebuild after changing that network or its speeds. | Single-sighting boat and zeppelin estimates in QoL, without loading Journeys. |
| `journeys_quests.py` | Builds `NaowhForever_JourneysData/QuestSpots.lua`: where each Quest List quest is handed in, and the camps of its objectives, from the map on its Wowhead Forever page. Cached in `data/journeys_quest_spots.json`; `--offline` writes from the cache only. | A tracked quest the game marks nowhere still has somewhere to go. |
| `same_maps.py` | Builds `Shared/Data/SameMaps.lua`: the maps the game has under two IDs (the same name, continent and bounds), each to the one with a parent map, whose data it reads, from the game's tables (wago.tools). Run it again when `wago.BUILD` moves on. | Zephras Isle is 2521 and 2665; the addon's data is keyed by 2521. |
| `zone_exits.py` | Builds `NaowhForever_QoL/Interface/ZoneExits.lua`: where the roads cross from one zone into the next, from Wowhead's zone grid and the game's map tables. | Forever has no map link data. |

## build/: the rest

| Tool | What it does | Why |
| --- | --- | --- |
| `scout.py` | Builds `NaowhForever_QoL/Interface/ScoutData.lua`: each attackable creature's abilities, armor, immunities, resistances and tameable beasts, for every open-world zone's and Dungeon Journal instance's creatures (Wowhead Forever's zone pages, cached in `data/scout.json` until `--refresh-zones`), and the tameable beasts those pages leave out or the database calls untameable (`data/scout_beasts.json`, whose pages are always read), from the CMaNGOS classic database (downloaded each run, or `--dump FILE`), the game's SpellName and ExpectedStat (wago.tools); `--fetch-gaps` reads Wowhead's creature pages for the creatures the database has no spells for, slowly, into the same cache. | Scout's tooltips: the game lists no creature's spells or stats. |
| `daily_word.py` | Builds `NaowhForever_QoL/Travel/DailyWordData.lua`: the Daily Word's answers, shuffled once with a fixed seed, and every word it accepts, from 12dicts and ENABLE (both public domain, downloaded each run). Rebuilding changes past days' words if the sources or its choices change. | One word a day for everyone without a server. |
| `forever_new.py` | Builds `Shared/Data/Forever.lua`: the items, quests and NPCs Wowhead marks as new in Forever, the ones our data mentions. Cached in `data/forever_new.json` (`--refresh` asks again). | The addon's Forever mark. |
| `spell_efficiency.py` | Builds `NaowhForever_QoL/Interface/SpellEfficiencyData.lua`: every class spell rank that costs mana and heals or deals damage, its amounts (base, per level, bonus coefficient, ticks), level and school, from the game's spell tables (wago.tools). Also each spell's talent mods (percent talents by rank, Illumination, Elemental Focus), read through the talent nodes in `NaowhForever_Training/Data/TrainingBuilds.lua`. Spells whose amount is elsewhere (weapon, proc, script) are left out; area triggers (Blizzard, Consecration) and Holy Shock are read from the spell their description names. Run it again when `wago.BUILD` moves on. | QoL's Mana Efficiency, without reading tooltip text. |
| `pvp_auras.py` | Builds `NaowhForever_Combat/PvP/Data/Spells.lua`: PvP Auras' crowd control and debuff spell IDs, from the game's spell tables (wago.tools). | Forever's classic spells carry no aura flags to filter by. |
| `skill_thresholds.py` | Writes each recipe's yellow and grey skill into `NaowhForever_Professions/Data/RecipeData.lua`, from the game's `SkillLineAbility` table (wago.tools); `--csv` reads a saved copy instead. Run it again when `wago.BUILD` moves on, or after adding recipes. | The Professions Skill-up Thresholds bar. |
| `vendor_spots.py` | Builds `NaowhForever_Professions/Data/VendorSellers.lua`: the unlimited-stock sellers on Wowhead Classic for each vendor reagent, limited to NPC names already in the addon's Forever-adjusted town data. Cached in `data/vendor_sellers.json`; `--offline` rebuilds without Wowhead. | Shopping List vendor pins work before visiting a merchant and need no other addon at runtime. |
| `vendor_prices.py` | Builds `NaowhForever_Professions/Data/VendorPrices.lua`: each vendor reagent's merchant price per item, in copper, from the game's ItemSparse table (BuyPrice over VendorStackCount, wago.tools). Cached in `data/vendor_prices.json`; `--offline` rebuilds from it. Run it again when `wago.BUILD` moves on, or after adding a vendor reagent. | Profit, ROI, the craft queue and the Shopping List use the vendor price before visiting a merchant, instead of a dearer auction price. |
| `presets.lua` | Writes `Core/Profiles/Presets.lua`, the setups a player can start from, one preset at a time: `lua5.1 Tools/build/presets.lua minimalist Tools/data/preset_minimalist.lua Naowh` (and `recommended`). | Naowh's two setups, kept in `data/` and rebuilt from there. |
| `search_index.lua` | Writes `NaowhForever_SearchIndex/SearchIndex.lua`, every module page's search entries, by running every addon file against stubs: `lua5.1 Tools/build/search_index.lua`. Git keeps an empty placeholder; the release and package workflows build the real one over it before packaging, and `test-search-index-build.lua` checks it builds. | A turned-off module never loads, so the search reads its settings from here. |

## sources/

| Tool | What it does | Why |
| --- | --- | --- |
| `wago.py` | Reads the game's own tables (DB2) for a Forever build from wago.tools, hotfixes included. `BUILD` is the build our data comes from. | The one source that is the game itself. |
| `wowhead.py` | Not a build: reading Wowhead's Forever pages (a polite `fetch`, listviews, a dungeon guide's loot) and writing Lua strings, for the tools that do. | Shared by the builders, `release/watch_build.py` and `wowsrc.py`. |
| `wowsrc.py` | Reads wowsrc.com's Forever loot pages into `data/wowsrc_loot.json`. `--resolve` maps their item names to IDs in `data/item_names.json` (`--offline`: without Wowhead). `--check` says what changed on their pages since (daily in CI). | Wowhead hasn't tied Forever's new items to bosses yet; wowsrc has. They gave us permission. |
| `recipe_drops.py` | Writes `data/journal_recipes.json`: the recipes each Journal boss drops, by each recipe's Wowhead item XML (its `sourcemore`), one item at a time; answers kept in `data/recipe_drops_cache.json`, `--refresh` asks again. | Wowhead's CDN refuses boss pages to scripts at times while the item XML still answers; the Journal build places these like an "add" list. |
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
  `build/forever_new.py`, `build/vendor_spots.py`.
