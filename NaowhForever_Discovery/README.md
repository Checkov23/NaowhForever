# Discovery

The library books and the Cozy Sleeping Bag: where to find each one, on the map and nearby, and
every quest and rare by zone (the Quest List and Rares tabs, in `QuestList/`, see its README). Its
Library Books tab has every book for your faction by zone, where it lies, whether you carry it,
and your road to the Friend of the Library rewards; its Sleeping Bag tab the bag's hidden quest
chain, step by step. Each has a tracker and map pins, and the books a nearby alert. Off by
default, every feature too: players turn it on in its settings pages (Discovery/Library Books and
Discovery/Sleeping Bag).

## Layout

```
NaowhForever_Discovery/
  NaowhForever_Discovery.toc  its metadata, and one file line: Discovery.xml
  Discovery.xml               every file, in load order
  Discovery.lua               its settings (ns.DiscoverySettings) and the module table (ns.Discovery)
  Constants.lua               the numbers several files share
  Data/
    Books.lua                 the books, where each lies and who takes it, and the reward quests
    SleepingBag.lua           the Cozy Sleeping Bag's steps, for each faction
  Library.lua                 the book rules: yours, carried, handed in, rewards, waypoints (ns.Library)
  SleepingBag.lua             the chain's rules: your steps, the one to do now (ns.SleepingBagChain)
  Nearby.lua                  the nearby alert: a ping and a chat line near a book you need
  View/
    Style.lua                 Discovery's own look, on top of Shared/Style.lua
    View.lua                  the window's row kinds, and the row a book and a step share
    BooksHero.lua             the Library Books card: the road to each reward
    BookRow.lua               a book
    BagHero.lua               the Sleeping Bag card
    StepRow.lua               a step of the chain
  UI/
    Window.lua                the window (/nfdiscovery) and its two tabs
    BookTracker.lua           the Library Books tracker
    BagTracker.lua            the Sleeping Bag tracker
    BookPins.lua, .xml        the book pins on the world map, and their template
    BagPins.lua, .xml         the chain's step pins on the world map, and their template
    BooksSettings.lua         the Discovery/Library Books settings page, declared as cards
    BagSettings.lua           the Discovery/Sleeping Bag settings page, declared as cards
  QuestList/                  the Quest List and Rares (Completo until 2026-10-10): its own README
```

Each layer only uses the ones above it. Everything the module shares hangs off `ns.Discovery`;
`ns.Library`, `ns.SleepingBagChain`, `ns.LibraryBooks`, `ns.LibraryGoals`, `ns.LibraryTurnIns`,
`ns.SleepingBag`, `ns.DiscoverySettings`, `ns.OpenDiscoveryWindow` and `ns.ToggleDiscoveryWindow`
keep their names for the rest of the addon.

## The data

- `ns.LibraryBooks`: the 40 library books on WoW Forever. Positions from
  foreverchanges.pro/library-books (2026-09-24, build 1.60.1.70009), cross-checked with
  zockify.com and Wowhead Forever; the turn-in quest IDs from Wowhead Forever's quests. Each book:
  `quest` (its turn-in, flagged completed once handed in), `item` (the book), `tier` (its set's
  quest level), `side` ("A", "H" or "B" for both), `turnIn` ("librarian", or "trainer": the level
  60 set goes to a mage trainer), and `spots`, each `{ uiMapID, x, y, place, note }`; a book with
  two spots lies in either. `unplaced`: nobody has found it on Forever yet; `missing`: it cannot be
  had on Forever. Both have no spots and are left off the map, and a missing book off every count.
- The Stormwind and Eastern Plaguelands spots are on Forever's redrawn maps already. The Blackrock
  Mountain books are pinned on the mountain in Burning Steppes, since the mountain's own map is not
  the zone you stand in.
- `ns.LibraryGoals`: handing in 10, 20 and 25 books each earns a reward quest; the books count
  toward every one. `rewards` are the choice of items, `{ itemID, name }`, the name for before the
  client has the item; `level` the level the quest needs. `reported`: the book count is what
  players report (method.gg, 2026-10-04); Wowhead Forever has the quest (82208, its rewards, level 30) but not
  how many books it takes.
- `ns.SleepingBag`: a hidden quest chain across Azeroth, each step a thing in the world to click,
  ending in the Cozy Sleeping Bag. From Wowhead Forever's quests (objects and spots) and its guide
  (the climbs and jumps), 2026-10-04. `steps[side]` in order: `object` to click, `map`, `x`, `y`,
  `place`, `tip` (how to get there where it is not plain), and `done`, the quest clicking it hands
  in; the first has `started`, the quest it starts, instead. The Alliance goes from Westfall to The
  Barrens and the Horde the other way ("... and that note you found"); from Stonetalon on both share
  the same steps. `level` is 14, what the chain needs; `optional` a side step not needed for the bag.

## Why

- Book and Sleeping Bag pins scale with `ns.Shared.ScalePin` at `BOOK_PIN_SCALE` / `BAG_PIN_SCALE` (0.5),
  like the quest pins: drawn in map units they grew with the canvas and filled the full screen map. Pin
  Size 20 is the default every map pin shares.
- Every file registers nothing but a login check until its feature is switched on.
- The windows' opacity was one setting (`windowAlpha`) before each had its own: a player who set
  it keeps it on the trackers until they set theirs, once.
- The bank count is the client's copy from the last time the bank was open.
- Caves and buildings have maps of their own under the zone, and the books are placed on the
  zone's, so the zone you stand in walks up to it.
- The reward quests count the books handed to the librarian, so progress counts those only.
- A step is done once the quest it hands in is; the first once the quest it starts is in your log
  or handed in. Two steps of one name (the Burned-Out Remains) are told apart by their zone.
- The hint lines keep the light blue they always had, unless the theme changed the Accent; then
  they take the theme's lighter Accent (`SoftBlue`).
- Map pins override `CheckMouseButtonPassthrough` with nothing: the map calls it on every pin, and
  its `SetPassThroughButtons` is protected, so calling it from our refresh is blocked in combat.
  Our pins want their clicks. The pin mixins are globals so the XML templates can name them.
- A pin's icon is cropped 0.08 to 0.92 to cut off the icon's own border.
- The Library Books tracker pops up on entering a zone with books you still need and stays while
  you are in that zone, even once they are looted. Its X closes it until you enter another zone,
  and switches Always Show off. With Always Show it is up in every zone with a dropdown; entering a
  zone with books selects it, and a zone picked after that sticks until you enter another. The
  picked zone stays in the list at 0 once its last book is looted, so the pick does not jump.
- Looting and handing in fire several events at once; the trackers redraw once, 0.2 seconds later,
  when the quest log has the change too.
- Unlock Mode shows the tracker on your zone, or the first zone with books for your faction (The
  Barrens for the Horde, Westfall for the Alliance).
- The Sleeping Bag tracker shows from level 14 until you have the bag; its X closes it until you
  enter another zone, as the Library Books tracker's does.
- Two steps at one spot (the Messenger Bag and the satchel under it) share a pin: the first not
  done. Its pins redraw once, on the quest log update after a step is taken or handed in.
- The game says when you start and stop moving but not where you are, so the nearby alert checks
  your distance once a second while you move, and once more as you stop; standing still nothing
  runs, and nothing at all in a zone with no book left. `REARM` is 1.5: past one and a half times
  the range the alert rearms, so standing at its edge does not repeat it.
- On the road a stripe stands for each book, in the accent for those handed in, with YOU over the
  end of the last one. A reward's dot is filled grey once handed in, in the accent once ready (or
  waiting on your level), a ring while ahead; once handed in, the reward you have keeps its colour
  and the others grey.
- A waypoint from the window or the tracker also opens the map with Open the Map (out of combat
  only); a pin's waypoint does not.

## Checking

- `luacheck NaowhForever_Discovery` from the repo root.
- `lua Tools/regression/test-library-tracker.lua`: the Library Books tracker's zones and cost.
- `lua Tools/regression/test-sleeping-bag.lua`: the chain's data and rules, its tracker, its pins
  and its settings' help.
- `lua Tools/regression/test-theme-hud.lua`: the hint lines' blue.
