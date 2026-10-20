# Top Bar

`[buttons] [clock] [buttons]` across the top of the screen, with the FPS / MS readout under it.
One saved layout orders the buttons on each side: Friends, Guild and Hearthstone (secure
buttons) and any addon's LibDataBroker launcher. Its card on the QoL Interface page has a live
preview that edits the layout: drag a button to move it, its x removes it, a side's + adds one.
The bar moves in the HUD Editor. `/nf lockouts` prints your saved instances. It is part of
NaowhForever_QoL, where its card is: switching QoL off takes the Top Bar with it.

## Layout

```
NaowhForever_QoL/TopBar/
  TopBar.xml            every file, in load order, included last by QoL.xml
  TopBar.lua            its settings and the module table (ns.TopBar)
  Constants.lua         the gaps, sizes, rounding, Hearthstone and broker prefix several files share (TB.C)
  Layout.lua            the saved layout, its migration from the old button keys, editing it (TB.Layout)
  Info.lua              friends and guild online, the Hearthstone's cooldown, saved instances (TB.Info)
  View/
    Style.lua           its glyphs, the pills, the badges, the readout's bands, the tooltips' colors (TB.Style)
    Look.lua            how the bar and its preview draw: pills, clock, rows of buttons, the readout (TB.Look)
  UI/
    Tooltips.lua        its tooltips at Tooltip Size (TB.Tooltips)
    Buttons.lua         the secure Friends, Guild and Hearthstone buttons and one per broker (TB.Buttons)
    Widgets.lua         the game's top-centre display moved below the bar, and back (TB.Widgets)
    Bar.lua             the bar on screen: built on first use, kept current, its events
    Preview.lua         the card's live preview, which edits the layout (TB.Preview)
    SettingsPage.lua    its card on the QoL Interface page, declared once
  README.md             this file
```

Its art is in `NaowhForever_QoL/Media/TopBar/`:

```
NaowhForever_QoL/Media/TopBar/
  icon-*.png            its button icons
  resting.blp           the resting glyph
```

Each layer uses only the ones above it. The bar hands its buttons the function that fades it
(`UpdateHover`) when it makes them.

## Why

- The clock's font is EllesmereUI's ("Gotham Narrow Ultra"), found through SharedMedia; without
  it the clock falls back to the Addon Font.
- Our own windows (Shopping List, Junk List, Aim Trainer and the rest) are offered by their broker
  launchers, which the core makes at login whether or not their minimap icon is on, so a saved one
  is on the bar after a reload.
- Our own launchers have glyphs of their own (`GLYPH`); any other launcher's icon is desaturated
  and tinted to match. On Forever the icons keep their full color and nothing tints them; the
  game's highlight shows the hover.
- Friends and Guild are secure buttons that click Blizzard's own button, the first of
  `CLICK_THROUGH` that exists, so the click opens its panel even in combat. They are made out of
  combat only.
- The pills take the player's Background color through `ns.ThemeTint`; the clock's and the
  tooltips' whites and greys (`WHITE`, `LABEL_GREY`, `EMPTY_GREY`, `MORE_GREY`) stay the shade they
  always were unless the theme changed Text or Secondary Text. The AFK and DND tags keep their grey
  (`AWAY_GREY`) unless the theme changed Secondary Text.
- Show On Mouseover fades the bar instead of hiding it, as it holds secure buttons. Every enter
  and leave on the bar or its buttons fades it again, since a leave into a gap fires nothing else.
- The bar takes mouse motion only, so the gaps between its buttons still click through.
- The clock opens the calendar with `ShowUIPanel` from our click, which is forbidden while
  `ns.GamepadOwnsPanels()`, so then it only says so.
- `SYS_DROP` (2) is how far the FPS / MS readout sits under the bar, on screen and in the preview
  alike, so it lives in `Constants.lua` with `ROUND` (0.5, added before `math.floor`).
- Each slider range on the card is a named table at the top of `UI/SettingsPage.lua`; Bar Opacity
  and Faded Opacity share `ALPHA_RANGE`, the house 0 to 100 opacity range from `Shared/Style.lua`.
- The FPS / MS readout is a sibling on `UIParent`, not a child of the bar, so Hide In Combat leaves
  it up: it sits under the bar while the bar shows, and where the bar was once it is hidden.
- Hide In Combat uses a state driver: hiding a frame that holds secure buttons is protected in
  combat. Everything `Apply` does moves or shows secure buttons, so in combat it waits for
  `PLAYER_REGEN_ENABLED`, and so does fitting the bar's width.
- `PLAYER_ENTERING_WORLD` comes after every addon's login, so late launchers exist by then: the
  bar is applied again there. Like the bar's other events it is registered only while the bar is on:
  the Top Bar ships inside QoL, so a Top Bar switched off must cost nothing, not even the saved
  instances request it makes on every loading screen.
- `GetSavedInstanceInfo`'s reset counts down from the last `UPDATE_INSTANCE_INFO`, not from now.
- `ROSTER_CAP` (40) keeps a big guild's tooltip on the screen.
- Roster names and zones can come back secret in combat, so the friends and guild lists wait for
  combat to end.
- `GuildRoster()` answers later and is rate limited, so the guild list may be a request behind: the
  tooltip asks at most every 10 seconds, the badges every 15.
- The tooltips are shown at Tooltip Size; `GameTooltip`'s own scale comes back when it hides. That
  hook is made with the bar's first tooltip, not at load.
- The addon memory scan is a frame spike, so it runs at most every 30 seconds; a click on the
  readout runs it again.
- The resting "zzz" is an 8-frame flipbook, 16 columns across the top half of its texture.
- The game's top-centre display (battleground scores, capture bars) hangs from the top of the
  screen (`WIDGETS_Y`, -15), under a Top Bar left there. It goes below the bar and its FPS / MS,
  `WIDGETS_GAP` (4) under, and back once the bar is off or moved away; `WIDGETS_ROOM` (60) is how
  far down the bar may reach and still be in its way. One another addon has placed is left where
  it is.
- The preview's edit layer sets an `OnKeyDown` script, which turns keyboard input on; it is turned
  off again until a drag starts. With no drag, Escape still reaches the options window. A drag
  that ends in combat cannot turn the keyboard off.
- The old button keys (`showFriends`, `showGuild`, `showHearth`, `brokers`, `brokerSide`) become
  the saved layout once, and Dungeon Quests (`NaowhForeverDQ`) became the Dungeon Journal.

## Checking

- `luacheck NaowhForever_QoL/TopBar` from the repo root.
- `lua Tools/regression/test-topbar-layout.lua`: the layout, its migration, the drawing order and
  the preview's remove, move and add.
- `lua Tools/regression/test-topbar-look.lua`, `test-topbar-readout.lua`,
  `test-topbar-mouseover.lua`, `test-topbar-widgets.lua` and `test-lockouts.lua`: the look, the
  readout, the fade, the top-centre display and the saved instances, on stubs.
