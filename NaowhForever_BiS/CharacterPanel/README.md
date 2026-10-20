# Character Panel

The game's character panel (C) in the BiS List's look. Blizzard keeps the panel and everything
it does: its slots' clicks, drags and tooltips, its tabs and its stats. Naowh fades its art
(`SetAlpha`, never `Hide`) and lays its own frames over it, from post-hooks only.

Off by default (BiS List > Character Panel), and nothing is hooked until it is first turned on.

EllesmereUI styles the same panel, and the two are never on at once. Turning Naowh's on turns
EllesmereUI's Character Sheet off (`EllesmereUIDB.themedCharacterSheet = false`, what its own
switch sets), and turning Naowh's off turns it back on if Naowh's was what turned it off; either
way a reload is offered, as EllesmereUI swaps its look at login. Should EllesmereUI's come back on
by other means (read through `EllesmereUI.GetBlizzWindowStyle("charsheet")`), Naowh's stands down.

## Layout

```
CharacterPanel/
  CharacterPanel.xml   what loads, in order
  CharacterPanel.lua   the namespace (ns.CharacterPanel), its switch, EllesmereUI's rule (CP.Rival)
  Constants.lua        the pane's width and edge, and the sizes, colours and counts the panel's files
                       and the Inspect Panel share (CP.C)
  Data/Slots.lua       the game's equipment slots by slot ID, named as its slot buttons are (CP.SLOTS)
  Data/Stats.lua       the stats your spec's list can show, in order, their short names and
                       yardsticks, and what each one does for your class (CP.Stats)
  Totals.lua           your total now for each stat, plain or while the game keeps it secret (CP.Totals)
  Worth.lua            what a stat is worth to your spec, in words: its yardstick, the list's title and
                       the hover card's line (CP.Worth)
  Restyler.lua         fades, tints and restyles the game's art and text, and puts it all back
                       (CP.Restyler); the character panel's own (CP.PanelArt)
  Frame.lua            the frame both panels wear: our backdrop, title rule, logo and close cross,
                       the model's panel and the split (CP.Chrome, CP.ModelPanel, CP.Split)
  Slots.lua            a slot's look over one of the game's slot buttons (CP.SlotOver)
  Score.lua            the Naowh Score card: the score big, a bar to its share of the best
                       (CP.ScoreCard)
  Badge.lua            the supporter badge plate and its hover card (CP.BadgePlate)
  StatRows.lua         the stats' heading and rows: each with a bar for its worth against the
                       spec's yardstick ("VS AGI"), your total, and a hover card for what it is
                       worth and what it does (CP.StatRows)
  StatsLook.lua        the game's stats rows restyled as its list makes them (CP.StatsLook)
  YourSlots.lua        your slots: edge in the quality's colour, item level, Forever's mark,
                       your BiS's star, the enchant dot
  YourScore.lua        your Naowh Score card under your level; hover for the score with your
                       BiS, click for the BiS List
  YourBadge.lua        your supporter badge in the left pane's top corner
  SpecStats.lua        the stats: your spec's first (the stats it weighs, in a fixed order), or
                       the game's All Stats; the switch at the bottom
  Chrome.lua           the panel dressed: the game's art faded or tinted under our frame, the
                       BiS List link, your level on the badge's row
  UI/SettingsPage.lua  its cards on BiS List > Character
```

The Inspect Panel (`InspectPanel/`) dresses the inspect window with the same parts: the rule
for EllesmereUI (`CP.Rival`), the frame (`CP.Restyler`, `CP.Chrome`), the slots (`CP.SlotOver`),
the score card (`CP.ScoreCard`) and the badge plate (`CP.BadgePlate`).

## How the slots work

Ours is a frame over each of the game's slot buttons (`Character<Name>Slot`), kept in a side
table: nothing of ours is stored on the game's frames. A post-hook of
`PaperDollItemSlotButton_Update` paints it each time the game updates the slot. Turned off,
the game's art comes back and ours hides.

## Why

- With both on, a player new to Naowh Forever (the onboarding not seen yet) gets Naowh's panel from the
  next reload, told in chat; anyone else is asked once. A player whose onboarding Apply left the panel on, with the
  BiS List, has answered already and gets it the same way, even over an earlier answer. At most
  one question a login, the character panel's first: a second confirm would close the first. The
  question waits `ASK_DELAY` seconds after entering the world, and never comes in combat.
- The onboarding's pick is a plain QoL key, `characterPanelPicked` (`inspectPanelPicked` for the
  Inspect Panel), which the core sets on Apply and the rule reads and clears at the next login, so the
  core knows nothing of this module and works without it. A pick waits out combat; with nothing to take
  over (EllesmereUI or its saved settings gone, its sheet off, or ours off) it is just cleared.
- A "took over" that EllesmereUI's own switch does not bear out (copied in with a profile, or
  EllesmereUI's turned back on since) is forgotten at login with its question, so the player is asked
  as on a first run.
- EllesmereUI styles a window when its public `GetBlizzWindowStyle` says anything but `"off"`; it is
  nil when its window skins are not loaded.
- Under Forever's Gamepad interface style (`ns.GamepadStandDown()`) the Character Panel, the Inspect
  Panel and Slot Marks stay off, and their cards say why. That style opens, closes and navigates
  these windows from secure code, so our hooks and restyling on them taint it, and its gamepad
  bindings are then blocked in combat. EllesmereUI's window skins stand down the same way, and the
  question about taking over from them is not asked.
- The parts both panels use (`Frame.lua`, `Restyler.lua`, `Slots.lua`, `Score.lua`, `Badge.lua`) make
  nothing at load; the `Your*` files, `SpecStats.lua` and `Chrome.lua` put them on your panel. These
  load in that order so their setting listeners and `ns.Apply` hooks run in it: the slots, your score,
  your badge, then the stats (placed under your score's card) and the frame.
- `HALF` is added before `math.floor` to round to the nearest whole; `RING_OUT` is the house's black
  ring one pixel outside an edge.
- `CP.PANE_W` is the game's right pane (`RightPaneHost` in its CharacterFrame.xml); `CP.EDGE` is the
  one edge in from its sides that your score, the stats and the switch all keep.
- Our backdrop sits at the panel's own frame level, under the game's frames, so the game's slots,
  model and stats draw over it. Each faded or tinted piece of the game's art is remembered so turning
  it off brings it all back.
- A model's buttons are faded texture by texture: the game sets their frame's alpha itself on hover,
  never their art's. A frame covers their strip so they take no clicks; dragging the model turns it
  and the wheel zooms it.
- The stats' rows are styled as the game's list makes them (its scroll box's initialized-frame
  callback), the same on every reuse.
- `FitLabel` keeps only a stat label's anchor points: FontString has no `GetWordWrap` to read back
  (only `SetWordWrap` and `CanWordWrap` exist), and the game never calls `SetWordWrap` on these
  labels, so `Unfit` always restores wrap to `true`.
- The BiS List's link sits in the left pane's top-right corner on your badge's middle, clear of the
  game's toggle for the stats there (`TOGGLE_W` 28px, `TOGGLE_EDGE` 6px in).
- An empty slot is nil, and an empty ammo slot 0.
- The game's slot update sets the icon again, so it is cropped again in our look on each update.
- A black ring outside the quality's edge (the house's border) makes the edge stand off the dark
  panel round it.
- The score card is a child of the game's stats list (its fade ignored), so the game hides it with
  the list whenever its gear sets, titles or pet take that room, and it never sits over their rows.
- `ROOM` is what the game leaves between your level and its list's top (the list's first title sits
  low in its own row): only what the score needs beyond it moves the list down.
- The stats can go secret under the game's addon restrictions (combat, an encounter, some maps):
  `ADDON_RESTRICTION_STATE_CHANGED` paints them again when one lifts. While secret, the totals the
  game can still show are set straight on the row's text by the calls that take a secret (a font
  string's `SetText` and `SetFormattedText`, and `C_StringUtil`'s rounding); a total we would have to
  add up or compare ourselves shows "-". The hover card writes it the same way.
- A spec's yardstick is the stat its weights are measured in (the defaults weigh it 1: Agility or
  Strength for fighters, Stamina for tanks, Spell Damage or Healing for casters), else the heaviest
  of `YARDSTICKS`.
- A row's bar is its weight's share of the heaviest by the square root, so a small one still shows.
- What a primary stat does is what the game's own character sheet says for your class. Its
  `PaperDollFrame_SetStatTooltip2` (`Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrameStats.lua`,
  Gethe/wow-ui-source `forever` branch) picks `<CLASS>_<STAT>_TOOLTIP`, else `DEFAULT_<STAT>_TOOLTIP`;
  Forever's strings are in Ketho/BlizzardInterfaceResources `forever`, `Resources/GlobalStrings/enUS.lua`.
  `DOES_BY_CLASS` holds the class ones, `DOES` the default.
- By those strings, Agility gives Warriors ranged attack power only, Rogues and Hunters attack power and
  ranged attack power, Druids attack power in Cat Form, and every other class none. Only Warriors,
  Paladins and Shamans get block value from Strength. Warriors and Rogues get no mana from Intellect
  or Spirit.
- The game's numbers stay out of the description: they go secret under the game's addon restrictions,
  and the hover card already shows your total.
- The badge art is 128px: drawn at a third of that it needs the mipmapped (`TRILINEAR`) filter to
  stay sharp. Its plate sits over the model, which is at frame level 50.
- While `ns.FEATURE_BADGES` is 0 only the team's badges exist, and the badge setting's default holds;
  the Supporter Badge row is on the page only while it is 1.

## Checking

`lua Tools/regression/test-character-panel.lua`: off and hooking nothing by default, the art
faded and each part painted when on, standing down for EllesmereUI, the art back when off, and
no garbage from a slot's update.
