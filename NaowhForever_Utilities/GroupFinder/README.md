# Group Finder

A Looking For Group layer for Naowh Forever players, on top of WoW Forever's own group finder
(`Blizzard_GroupFinder_VanillaStyle`, a listing board with no applications). Forever does the listing,
searching and inviting; Naowh Forever players see each other's cards and can apply to a group, by
addon whispers between the two players. A module of `NaowhForever_Utilities` (Utilities > Group Finder
in the options window), needing `NaowhForever_BiS` for the Naowh Score and the BiS list; the Dungeon
Journal is optional and read for kills, quests and dungeon keys when it is loaded.

Off by default (`groupFinder.enabled`; its switch under Settings > Modules). Its window (`/nflfg`, its
Top Bar launcher, or Open Group Finder on its settings page) has three tabs: Browse, Your Group and
Create. Opening it turns the module on.

## Browse

```
+--------------------------------------------------------------------+
| [logo] Looking For Group                     [Search]          [x] |
|        4 groups                                                    |
|--------------------------------------------------------------------|
| [For your level] [All] [RFC 13-18] [WC 17-24] [DM 17-26]           |  a chip is a search; dungeons
| [SFK 22-30] [BFD 24-32] [Stocks 24-32] ...                         |  outside your level muted
| [Filter by dungeon, leader or note        ]         Sort: Newest v |
|--------------------------------------------------------------------|
| Shadowfang Keep 22-30                                  12.0+  23.9 |  their minimum, the leader's
| [class] Korvath 25                                         [Apply] |  Naowh Score in its grade's color
| [T][D][D][ ][ ]   3 boss kills   2 quests                   10m ago |
|--------------------------------------------------------------------|
| The Deadmines 17-26                                            ... |  waiting for their card
| [class] Nessa 19                                                   |
| [H][D]                                                   just now |  a solo player's roles
+--------------------------------------------------------------------+
```

- The chips pick what is searched: the dungeons for your level (to start), every dungeon, or one. A
  chip clicked while a search runs does nothing; Search searches the picked chip again.
- The filter box keeps the listings whose dungeon, leader or note has what you type; the count says
  how many of them show.
- Your own listing first, then by the sort: newest first (to start), the leader's Naowh Score best first,
  or the dungeon's level lowest first, newest first within each. The sort is kept. A delisted listing
  stays, faded.
- A group's spots are its tanks, healers and damage, then empty spots up to the activity's size; a solo
  player shows the roles they signed up as; a raid shows its count.
- The kills and quests are the leader's for that dungeon: their boss kills there, or First time, and
  the dungeon's quests in their log.
- A note says when nothing has been searched yet, while searching, when a search failed, when there is
  nothing to search at your level, and during an encounter.
- A leader who listed through Create shows their minimum score, and their note and the roles they need
  on hover. Apply sends your card with your saved roles; the row then says Applied, Received (their game
  has it) or Declined.

## Your Group

```
| Shadowfang Keep 22-30                                     [Delist] |
| Competitive   Minimum score 12.5   Listed 10m ago   2 applied      |
| Die Man 20   Pal 20                                                |  your party, in class colors
|--------------------------------------------------------------------|
| [class] Magus            23.9  7 boss kills  BiS 9/14  1 quest   [Invite] [Decline] |
| [H][D] 25                                                          |  the roles they apply as
```

- The applicants, best Naowh Score first, their note on hover. Invite invites them by name, and the
  row then says Invited; Decline tells them, and they leave the list.
- Without a listing it says so, and points to Create. Only your group's leader sees Delist.

## Create

- **Dungeon:** a tile for each activity in the category the search uses, by level: its short name, its
  levels in the color of their difficulty for you, and its bosses from the Journal.
- **Roles needed:** how many tanks, healers and damage you still want, 0 to 9 each.
- **Minimum score:** 0 to 30, in halves.
- **Style:** the game's own four playstyles, under the game's names.
- **Note:** 60 characters.
- **List Group**, or **Update Group** while listed: lists the dungeon and playstyle in Forever's finder
  and shows Your Group. It says why when it cannot: nothing picked yet, or you are not the leader.
  **Reset** clears the form.

## Layout

```
NaowhForever_Utilities/GroupFinder/
  GroupFinder.xml      what loads, in order, included by Utilities.xml
  GroupFinder.lua      its settings (ns.GroupFinderSettings), the module table (ns.GroupFinder, GF), on or
                       off, and the listeners its files tell each other through (GF.Listen, GF.Fire)
  Card.lua             your card for one dungeon, and every message written and read (GF.Card)
  Comms.lua            the whispers: send queue, card requests, applications, expiry, guards (GF.Comms)
  Listings.lua         Forever's search results in pooled entries, activities to Journal keys (GF.Listings)
  Search.lua           a search from the Browse screen, for the activities at your level, all of them or
                       one, and the category's activities by level (GF.Search)
  Group.lua            your group: listing, updating and delisting it, inviting or declining applicants,
                       and what Naowh Forever players are told about it (GF.Group)
  Browse.lua           each listing's leader asked once for their card, applying to them, and the
                       filter and sorts (GF.Browse)
  Probe.lua            /nf groupfinder probe and /nf groupfinder ping <name>
  View/
    Style.lua          its look, its window's sizes and shared words and parts (GF.UI, GF.UI.Style)
    Row.lua            a listing's row on the shared row engine (GF.UI.Kinds)
    Applicant.lua      an applicant's row on the shared row engine (GF.UI.ApplicantKinds)
  UI/
    YourGroup.lua      the Your Group page (GF.UI.YourGroup)
    Create.lua         the Create page (GF.UI.Create)
    BrowseBar.lua      Browse's chips, filter box and sort (GF.UI.BrowseBar)
    Window.lua         the window, its tabs and the Browse list (ns.OpenGroupFinder, ns.ToggleGroupFinder)
    SettingsPage.lua   its settings page (Group Finder/Settings): Open Group Finder, what your card shares
  README.md            this file
```

## How it talks

Addon whispers by name, prefix `NaowhLFG`. Every message is one plain line, version first, at most
255 bytes:

| Message | Sent | Answer |
| --- | --- | --- |
| `1 Q <nonce> <dungeon or ->` | asks a listed player for their card | `C` or `L` with the same nonce |
| `1 C <nonce> <card>` | your card | |
| `1 L <nonce> <card> <minimum or -> <needs> [note]` | your card and the group you listed through Create | |
| `1 A <id> <card> [note]` | applies: your card with the roles you apply as, and a note | `K` |
| `1 K <id>` | the leader's game received it | |
| `1 X <id>` | you withdraw it | |
| `1 D <id>` | the leader declined: no message, the row says Declined until the application expires | |

The card is nine fields, `-` for one not shared or not known:

```
<class ID> <level> <roles> <spec> <score> <BiS> <dungeon> <kills> <quests>
1          20      TD      fury-warrior 189 8/14 Deadmines 3,2,0,0,99,1,0,0 168,2040/166,214
```

- roles: `T`, `H`, `D` in that order (the game's saved LFG roles, or the ones you apply as).
- spec: the BiS list's spec key. score: the Naowh Score in tenths. BiS: have/total.
- kills: each boss the game counts, in the Journal's order, capped at 99. A screen showing them per
  boss checks the count against its own list of the dungeon's bosses first; the total is always good.
- quests: the quests in your log, a slash, then those you still need, by quest ID (the reader names
  them in its own language).
- the note: printable ASCII, no `|` escapes, 60 bytes at most, always last.
- `L`'s minimum: the Naowh Score in tenths. needs: three digits, the tanks, healers and damage you want.

Sizes: Q 15 bytes, C 86, L with a note 129, A with a note 106; the biggest real application (Dire
Maul's 19 bosses, a full note) 248. When a card would not fit, its quest lists are cut first, then its
kills.

## The data the screens use

- **A listing** (`GF.Listings.entries[1..n]`, after `GF.Listings.Read()`): `id`, `leader` (nil until
  the game names them), `activity`, `dungeon` (Journal key), `numMembers`, `members[1..nMembers]`
  (`name`, `level`, `class`, `roles` as card role bits, `leader`, up to 5), `tanks`, `healers`,
  `damage`, `age` in seconds, `delisted`, `mine` (your own), `party` (its party GUID).
  `GF.Listings.state` is `ready`, `locked`, `failed` or `none`. An activity
  (`GF.Listings.Activity(id)`, read once): `name`, `short`, `min` and `max` levels, `size`.
- **A search** (`GF.Search.Run(pick)`, from a click): `GF.Search.state` is `idle`, `searching`, `done`,
  `failed` or `unavailable`; `GF.Search.pick` is `Search.LEVEL`, `Search.ALL` or an activity ID, kept
  for the next search. The category's activities by level: `GF.Search.Activities(list)`, and whether
  one suits your level: `GF.Search.Suits(id)`. A leader's card (`GF.Browse.CardOf(name)`): the card, and
  whether one is still awaited. Browse's rules: `GF.Browse.Matches(entry, needle)` and
  `GF.Browse.Sort(order, how)`.
- **A card** (`GF.Card.New()`): `class`, `level`, `roles` (bits: `Card.TANK`, `HEALER`, `DAMAGE`),
  `spec`, `score`, `bisHave`, `bisTotal`, `dungeon`, `hasKills`, `kills[1..nKills]`, `hasQuests`,
  `have[1..nHave]`, `need[1..nNeed]`. Received ones by name: `GF.Comms.CardOf(name)`, with `group`
  (`min`, `tanks`, `healers`, `damage`, `note`) when they answered with `L`.
- **An applicant** (`GF.Comms.applicants`): `id`, `name`, `card`, `note`, `at`, `deadline`, `invited`.
- **Your application** (`GF.Comms.sent`, one by leader: `GF.Comms.SentTo(name)`): `id`, `name`,
  `dungeon`, `deadline`, `acked`, `declined`.
- **Your group** (`GF.Group`): the form's `activity`, `style`, `min` (tenths), `tanks`, `healers`,
  `damage` and `note`; `ours` while its listing is the one Create made, from `listedAt`.
- Events (`GF.Listen(what, fn)`): `listings` (true when the search failed), `listing`, `search`, `card`,
  `noreply`, `offline`, `applicant`, `received`, `declined`, `withdrawn`, `expired`, `applicantExpired`.

## Why

- Custom chat channels are split per realm on Forever, so there is no channel network: a player's
  own search in Forever's finder is the discovery, and only the players they look at or apply to are
  whispered.
- Its own prefix: the BiS List's inspect whisper and the Naowh Score's share answer a unit you
  inspect or your group, while a card goes to a stranger from a listing and carries dungeon kills and
  quests they do not.
- Listings are read here rather than through Chat Zones or Group Finder Roles: those are Quality of
  Life features that may be off, and each reads only the one field it needs.
- Messages carry no GUID: the game names the sender, and a GUID in the text would only be the
  sender's own claim.
- Names are compared after `Ambiguate(name, "none")`: your own realm's suffix goes and other realms
  keep theirs, so Bob-A and Bob-B are two players, and your name on another realm is someone else.
  A reply to a ping or an application also matches when one of the two names has no realm, since
  Forever's listings name the leader without one.
- A card request or an application is answered only while you are listed
  (`C_LFGList.HasActiveEntryInfo`): browsing players ask listed players, and nobody else needs your
  card.
- Card requests are answered at most `ANSWERS_MAX` per `ANSWERS_WINDOW` seconds (half the send rate)
  and once per player per `ANSWER_GAP`, so players browsing your listing cannot fill the queue your
  own applications and acknowledgements go through.
- The send queue keeps to `BURST` at once then `RATE` a second, holds during chat lockdown, and waits
  again when the game answers with its own throttle.
- Listings are not read in chat-messaging lockdown, when the search results are secret. A listing or
  member with a secret field is skipped. Members' roles are the ones they signed up as (`lfgRoles`),
  as Group Finder Roles reads them.
- `GetFilteredSearchResults` leaves out listings the player reported, as the game's own finder does.
  `LFG_LIST_SEARCH_FAILED` marks the listings `failed`, so a screen can say so instead of waiting.
- The game's "No player named" line is hidden only for a name whispered in the last
  `NOT_FOUND_WINDOW` seconds, and ends that name's ping as offline.
- One sweep timer with a generation number expires pings, applications and applicants; turning the
  module off makes a pending sweep stale.
- Activities are matched to Journal dungeons by name, then by instance map when only one dungeon has
  it, never guessing between Scarlet Monastery's wings or the Blackrock Spires. Activity names come in
  the client's language, so outside English only the map match works for now.
- Every table that grows with other players is bounded: the queue, pings, applications, applicants,
  kept cards, senders, askers, names whispered and leaders asked.
- A search runs only from a click, the Search button's or a chip's, as the game's own finder runs it, so
  there is no timed refresh. It takes the first category with an activity that suits your level and
  searches those activities, plus your own listing's, the way the game's finder filters by suggested
  levels (`Blizzard_LFGVanilla_ParentFrame.lua`); All searches every activity in it, and a dungeon's
  chip that one alone. A search that gets no answer in `SEARCH_WAIT` seconds has failed: not every
  failure sends an event.
- The chips are searches rather than a filter on the last results, so a dungeon outside your level is
  found too, and the list always matches the chip picked. The filter box only narrows what is shown.
- `C_LFGList.GetAvailableCategories`, `GetAvailableActivities` and `GetSearchResultMemberCounts` are not
  in the generated API docs, but the game's own Forever finder calls them
  (`Blizzard_LFGVanilla_Browse.lua`, `Blizzard_LFGVanilla_ParentFrame.lua`), and Group Finder Roles reads
  the member counts too.
- A group's spots follow the game's own finder: tanks, healers, then damage, from the member counts, and
  `groupfinder-icon-emptyslot` for the rest.
- Browse asks each leader for their card once, at most every `ASK_AGAIN` seconds, through the pings
  the whispers keep (`MAX_PINGS`), never your own listing or a delisted one. A listed leader answers;
  one who does not run Naowh Forever is not waited on again.
- The kills on a row are the leader's own boss kills in that dungeon, not how far the group has got:
  a card carries no run progress yet.
- `C_LFGList.CreateListing`, `UpdateListing` and `RemoveListing` need a hardware event, so List Group,
  Update Group and Delist run only from their clicks. They list as the game's own Listing tab does
  (`Blizzard_LFGVanilla_Listing.lua`): the activity and a playstyle, which Forever requires and shows
  every player, so Style offers the game's four (`GROUP_FINDER_GENERAL_PLAYSTYLE1` to `4`). Only a group's
  leader, or a player on their own, can list or delist, as there.
- The game's listing comment is a text field addon code cannot fill, so the note, the minimum score
  and the roles needed reach Naowh Forever players only, in the leader's answer.
- A listed leader answers with one `L`, the card and the group together, not two whispers: answers are
  capped to keep the send rate free, and an answer cut there looks like a leader without Naowh Forever.
- What Create listed is told only while that listing stands (`ours`): a listing made in the game's own
  finder, or one gone (`LFG_LIST_ACTIVE_ENTRY_UPDATE` with no active entry), has no group to tell.
- Invite is `C_PartyInfo.InviteUnit` by the applicant's name; the game asks for confirmation itself when
  inviting would turn the party into a raid.

## Settings

| Key | Default | What it is |
| --- | --- | --- |
| `enabled` | `false` | the module |
| `shareScore` | `true` | your Naowh Score on your card |
| `shareKills` | `true` | your boss kills for the dungeon |
| `shareQuests` | `true` | the dungeon's quests you have or need |
| `shareBis` | `true` | how many of your BiS items you have |
| `sort` | `"newest"` | Browse's order: `newest`, `score` or `level` |

## Checking

- `lua Tools/regression/test-group-finder.lua`: loads its rules against stubs and checks it is free
  while off, the card and its messages, the whispers' guards and expiry, answering only while listed,
  names across realms, the listings, the search for your level, every dungeon or one, Browse's filter
  and sorts, asking leaders for cards, a listed leader's `L`, listing,
  updating and delisting a group, invites and declines, applying, the probe, and the budgets: a card
  built and written under 0.1 ms, read under 0.05 ms, fifty listings read under 0.5 ms, none of them
  making garbage.
- `lua Tools/regression/test-group-finder-ui.lua`: the window, its tabs and its pages on the real shared
  parts, against stubbed rules: nothing built until opened; Browse's notes, order, rows, a leader's group
  and Apply; the chips, the filter box and the sort; Create's tiles, roles, slider, styles, note, List Group and Reset, and why it cannot list;
  Your Group's header, party, applicants best first, Invite, Decline and Delist; and turning it off.
- In game: `/nf groupfinder probe`, and `/nf groupfinder ping <name>` between two players with the
  Group Finder on; the one pinged needs a listing up in the game's Group Finder.
