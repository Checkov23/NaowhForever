# Damage Meter

Damage, healing and more for your group, one bar each, in your theme. It reads the game's own
`C_DamageMeter` data and draws its own windows, and turns the game's meter off while it is on. Up to
three windows, each with its own list, session and size. Hover a row for its spells, report to chat
from the window's menu, and reset from the menu or a key binding. Its settings page is Damage
Meter/Settings. Its on/off switch and default come from `ns.FEATURES.damageMeter`.

## Layout

```
NaowhForever_DamageMeter/
  NaowhForever_DamageMeter.toc   the addon; lists only DamageMeter.xml
  DamageMeter.xml                every file, in load order
  DamageMeter.lua                the settings (ns.DamageMeterSettings) and the module table (ns.DamageMeter, DM)
  Constants.lua                  the sizes, the lists and the sessions (DM.C)
  Data/
    Samples.lua                  the sample group the preview and Unlock Mode show (DM.SAMPLE)
  Source.lua                     reading the game's sessions, fights and spells (DM.Session, DM.Fights, DM.SourceSpells)
  Numbers.lua                    how a number is written, and the sums over plain numbers (DM.Format, DM.Clock, DM.Percent)
  Spells.lua                     a source's spells and the enemies it hurt, as rows of a session (DM.SpellSession)
  Looks.lua                      the look kept by name, applied, and written as text (DM.SaveLook, DM.EncodeLook)
  Names.lua                      a player's name as written: first, last, initials (DM.DisplayName, DM.ScanRoster)
  Report.lua                     the lines a report sends, and where it can go (DM.Report, DM.Channels)
  History.lua                    a summary of each fight, kept when it ends (DM.History)
  View/
    Meter.lua                    a window's look and layout (DM.Look)
    Breakdown.lua                the spells panel beside a hovered row (DM.Breakdown)
  UI/
    History.lua                  the kept fights in a window of their own (DM.HistoryWindow)
    Menus.lua                    a window's list, session and window menus (DM.Menus)
    Meter.lua                    the windows: drag, resize, scroll, hover, updates (ns.PreviewDamageMeter)
    ImageHelp.lua                a dialog that says how to add a picture of your own (DM.ShowImageHelp)
    SettingsPage.lua             its settings page: eleven cards, the detail behind cogs
  README.md                      this file
```

## Why

- Amounts and names are secret in combat. Nothing in `Source.lua` or `View/` compares or adds them
  without asking `DM.IsSecret`: they go straight to `StatusBar:SetValue`, `SetMinMaxValues` and
  `SetText`, through the client's own `AbbreviateLargeNumbers`, which takes a secret. The class, the
  spec icon and `isLocalPlayer` are never secret, so those are read.
- The game returns its sources and spells already sorted, so the window draws them in order and ranks
  by position.
- The API calls go through `pcall`: an error reads as no data and the window says so, not a Lua error.
- `C_DamageMeter.IsDamageMeterAvailable` (available, reason) says whether the game lets the meter run;
  when it does not, the window shows the game's reason instead of the empty line. A client without the
  call counts as available.
- Updates are coalesced, 0.25 seconds after the first event of a burst, since the game fires one per
  source per update. All open windows redraw together.
- While it is off nothing is built or listened to but the frame that waits for the login: the event frame
  is made when it is first turned on, and the fade's OnUpdate runs only while a window is fading or
  Full While Hovered has the mouse to watch.
- The game's meter is the `damageMeterEnabled` setting. It is turned off while this one is on and put
  back as it was after, kept on the account so it survives a reload. It is left alone in combat and
  done again when combat ends. If this addon is disabled or removed, the core puts it back at login.
- Every part of a window has its own color setting (`DM.C.COLORS`): the bars' custom color and your
  row's edge, the names, amounts, ranks, column titles, title, fight time and summary line, and the
  window, the title bar and the border. A row has no background of its own: the window's shows behind
  the bars. Each is `false` until a color is picked and then follows the theme's token
  it stands in for, so a theme switch restyles what was not picked. `Look.Color(key)` is the one place
  that resolves it.
- Your own bar (found by `isLocalPlayer`, never secret) and the strip beside it each have a style:
  the same as the others, your class's color, or a color of their own (`ownBarStyle`, `edgeStyle`),
  over whichever Bar Color is chosen. The window menu switches Bar Color between Class Colors, Theme
  Accent and Custom Color without opening the settings. The sample's "You" row takes your own class
  (`DM.Sample`), so the preview and Unlock Mode show your bar and edge as they will be.
- Class Colors can be changed class by class (`classColors`, class to color), kept apart from the
  theme tokens since the game gives every class its own. A background image is a name from the shared
  media's `background` list, or the path typed in Custom Image when Image is Your Own Picture
  (`DM.C.OWN_PICTURE`, a choice of the same list); Custom Image is greyed until that is picked. It is
  drawn above the window's color and below the rows, stretched or tiled. Tiling is worked out in
  `LayImage` from the window's size and a Tile Size setting, with a repeating wrap, since a picture's own
  size is not known to the add-on and the engine's own tile flags need the picture to be a power of two.
  The game's plain backgrounds (Solid, Blizzard Tooltip, Out of Control, Low Health) are left out of the
  list and read as none. A dialog, opened by a button in the Window card's Picture cog, says how to add a
  picture: a .png, .tga or .blp in a folder of the player's own under
  `AddOns`, and its path with the extension. A .png loads on this client as it does for other add-ons
  here; a .jpg is not known to. The tooltip is a fixed-width card, so a help text must not hold a long
  word with no spaces, such as a path: it is cut short, which is why the example lives in the dialog.
- The media's own list has a None of its own, which is left out with the plain backgrounds since the
  page's Image already has one.
- The fights kept are on the account under the character (`damageMeterFights`, by `UnitGUID("player")`),
  not in the profile, so a profile that is switched, reset or imported does not take them and they are
  not in the strings a profile is shared by. Fights Kept, which is a setting, trims it.
- The Fight History window sits in the FULLSCREEN strata, over the settings window (DIALOG), and opens
  beside it when there is room, so the two do not cover each other. A window the player has moved stays
  where it was put.
- The summary line is made of up to four pieces (the session's name, its total, the raid's per-second
  figure, your rank), each a setting, joined by `SetFormattedText`; Summary Size is its font size. Short
  List Names (`DM.ModeLabel`) swaps a list's label for its short one in the title, the second list's
  strip and the spell panel, and leaves the menus and the reports with the full names.
- The settings page is eleven cards: Lists, Window, Bars, Row, Figures, Title Bar, Spells and Reports,
  Fights and Data, Looks, and a Second and a Third Window. A card shows what is used most, in two columns,
  and keeps the rest behind the cog of the row it belongs to (`cog` on the row, `under = <its label>` on the
  rows behind it, which the framework leaves off the page, searches and resets with the card): the icon's
  size, style, side, crop and gap behind Icons; a text's size, size switch, font, outline and color behind the
  row of the text (Name Settings, with the name's format and length too, Figure Settings, Title Settings, Rank
  Numbers, Show Fight Time, Column Titles, Summary Line); the picture's path and tiling behind Image; the classes' colors behind Bar Color; the spell
  panel behind Spell Breakdown; a window's own look and columns behind Own Look and Column 1. A row that
  means something for one choice only (`hidden` as a function) is left off while another is picked: Hide
  After, Custom Bar Color, Track Color and Decimals. A row's label is the only one of its name on its card,
  because a cog is found by the label of the row that owns it. A text's size (`SizeRow`) shows the size the
  text has, and setting it sets the size and turns the text's Own Size switch on, which the cog turns off
  again; it is in the cog of its text, with the text's font and color. The rows of Name Settings, Figure
  Settings and Title Settings are color pickers called what their cog holds (still found by the color's
  name); the others are the text's toggle. A card folded with its cog open takes the cog's panel
  with it (`Draw:Card` in the shared page). The window's own font and outline are on the Window card; Clean
  Look is on the Looks card.
- An icon and a font are not changed on screen until the game is reloaded, so once one of their settings has
  been changed since the game loaded (`S.OnChange`, kept in `pending`), its row says "Needs a /reload", and so
  do the row that owns its cog and its card (`note`), until the reload. The keys are the icon's (`showIcons`
  and the icon rows) and each text's font, own-font switch and outline, and the window's font and outline;
  a size is applied at once and says nothing.
- Reset All Settings (Fights and Data card, asks first) clears every key of the module's settings but
  `enabled` and the windows' places (`meterPos*`), so each setting reads its default again. The looks kept
  by name and the fights kept are on the account, not in the settings, and stay.
- The spell panel's pool is as many rows as the settings can ask for (`BREAKDOWN_MAX`, `TARGET_MAX`) and
  it shows as many as Spells Shown and Enemies Shown say, at Panel Width, Scale and Opacity, on the side
  Panel Side says or else the one the window leaves room on. Enemies Shown also sets how many enemies a
  player's breakdown in the window lists. Past Fights Offered trims the fights the Session menu lists.
- The columns of a row, left to right, are one setting (`columns`, per window with its own look): six slots,
  each the name, the total, the per-second figure, the share, the total of another list for the same player
  (`damage`, `healing`, `taken`, `avoidable`, `absorbs`, `interrupts`, `dispels` or `deaths`) or none, as the
  six Column rows on the Figures card. A kind is once and the name is always there; a kind picked that is in
  another slot trades places with it (`DM.SetColumnSlot`). "auto" is the name, the total and the per-second
  figure, with the per-second figure first in the DPS and HPS lists, as the game's meter has it; the first
  change makes it a list. `DM.ColumnSlots` reads it.
  A row is its cells, `Columns` giving each its id: A the first figure, B the second (or the only one, or
  both with the divider, at the place of the first), P the share and X1 to X5 the totals of other lists.
  The cells before the name are anchored from the left end, each to the right of the one before it, and the
  cells after it from the right end, each to the left of the one after it; the name, with its rank and icon,
  fills what they leave. The column titles are put by number at the right end of their columns, take the
  width of their words and do not wrap, which is what keeps a long one (a wide font, a big text size) from
  being cut short and lowered a line, as a title with a width of its own and wrapping on was.
- A column of another list's total (`Look.Extras`, read as asked for through `DM.Session`) is found for a row
  by your own row, or by a guid the addon can read: in combat the guid is secret and the cell is empty, as the
  share is, and fills in after the fight. A player's breakdown does not draw them.
- A column is as wide as its widest text once every figure shown is known (`FitColumns`, measured on a
  hidden FontString of the figures' font, since a FontString given a width reports no more than it), so the
  name has all the room the figures leave. A figure the game keeps back in combat cannot be measured, and
  the columns keep the width of the longest figure the settings would write (`pane.fit` is nil); the share
  is always known, and fits once it is there. The title has the room to the bar's end less its margin when
  the buttons are hidden, and to the buttons when they are shown, from where its offset puts it.
- A look is the visual settings (`DM.C.LOOK_KEYS`: not places, lists, rules or behaviour). Looks are kept
  on the account by name (`damageMeterLooks`, twelve at most), applied key by key with `DM.ApplyLook`, and
  written as one line, `NFDM1|key=value|...`, each value with its kind in front (`n` number, `b` boolean,
  `s` string, `c` color, `m` colors by class), with `|`, `=`, `;`, `:`, `,`, `%` and bytes above 127
  escaped. A text is read key by key: a key that is not a look's, or a value that is not of its kind
  (a color outside 0 to 1, a number out of range, a string for a number), is left out and the rest is
  taken. Copy to Other Windows turns the second and third windows' own looks on, from the first.
- A second or third window may have a look of its own (`ownLook2`, `ownLook3`): seventeen of the look
  settings (`DM.C.OWN_LOOK_ORDER`: row height and spacing, bar opacity and color, grow direction, text
  size, icons, ranks, window and title bar opacity, border, and the columns: total, per second,
  share, divider, order and their titles; behind two cogs of the window's card) have a copy under the
  window's number (`barHeight2`). `DM.Setting(index, key)` reads a look setting for a window, which is the
  copy when the window has its own look and the shared one otherwise, and `DM.LookKey` is the key to
  write, which the window menu's Bar Color uses. Turning a window's look on copies the shared values into
  its keys, so it starts as it was, and turning it off keeps them. The rest of the look (fonts, colors,
  name and number formats) is shared by every window.
- The room in a row is settings now (Icons, and the Row card): the icon's size (zero fits the row; a size of its
  own is used as it is, up to `MAX_ICON`, and the bars are at least as tall: `Look.BarHeight`), side, crop and
  gap, the padding at the ends, the gap between columns and the edge's width.
  An icon on the right takes room from the figures (`rightInset`, which the titles over them follow),
  and the name's right end is the figures' left less that. An icon before the bar (`iconSide = "before"`)
  stands outside it, at the bar's height and touching it, whatever Icon Gap says: the row starts after it
  (`g.iconOutside`), and the icon is anchored to the row's left end. Bar Track is a texture under the status bar,
  in the Bar Track color at a fixed opacity.
- Class Colored Names and Figures use the row's `classFilename` (never secret) through the same
  `ClassColor` the bars use, so a class picked for its bar is the class's text color too; spell and enemy
  rows (they have a `label`) keep the theme's. Call Me You and Name Length are done in the view, not in
  `DM.DisplayName`, so reports keep real names; a name is cut by letters (UTF-8 aware) and only when it
  is a plain text. A share is written by `DM.PercentText` (decimals from the settings) and a per-second
  figure takes `DM.RateSuffix()`, through `SetFormattedText` so a secret amount still goes in as it is.
- Each text (name, figures, rank, title, time, summary, column titles) has a font, an outline and a size of
  its own, each behind its own switch (`<text>OwnFont`, `<text>OwnSize`); with the switch off it follows
  the window's font and outline and its usual size, with it on it takes `<text>Font`, `<text>Outline` and
  its size key. `Look.TextStyle` answers for one text and `Look.Layout` collects them all into the geometry,
  so the figures' columns and the time's room are sized by their own text. Every setting change throws the
  layout's memory away (`Look.Invalidate`), so it is laid out again at once; the game does not always show
  a new font or icon until a reload, which the page says.
- Always Show My Row: when your row (found by `isLocalPlayer`, never secret) is outside the rows shown
  (above them after scrolling, or below), the last row shown is yours, with your rank, so the list
  still scrolls through the others. It is the same source table, so hovering and clicking it work.
- When it shows: Where gains In a Raid, and Hide in Battlegrounds hides it in a `pvp` or `arena` instance
  whatever Where says. Pet battles, cinematics and hiding the UI take the windows with `UIParent`, so
  they need no rule. Data and Reset: entering a new instance (a different instance id, not a login or a
  reload) clears the game's data or asks first, leaving a group clears it, and nothing is cleared in
  combat. Show Overall Out of Combat sets each shown window's session setting to Overall when combat ends
  and back to Current when it begins, so the menu and the settings page say what is shown.
- Fading is the window's alpha, stepped toward its target from a small `OnUpdate` (every tenth of a
  second, and only while it is still moving or, out of combat, Full While Hovered has a faded window
  to watch; a change of state starts it again): full in combat, while the mouse is over the
  window (`IsMouseOver`, since a row on top of the window would take an `OnEnter` of the frame itself),
  while it is being placed and in the preview, else the Out of Combat Opacity. The spell panel is not
  the window's child, so it is not faded. Mouse Passes Through, with the window locked, turns the mouse
  off on the title bar, the rows, the corner and the window itself, so hover and clicks do not work.
- Grow Upward puts row i in the slot `capacity - i` of its pane's room (the first row at the bottom of
  it), so each pane of a window with a second list fills from its own bottom. Fill From the Right is the
  status bar's `SetReverseFill`. Bars Compare To is the second argument of `SetMinMaxValues`: the list's
  biggest amount (the game's `maxAmount`) or its total, either of which may be secret.
- A window has a scale of its own (`scale`, `scale2`, `scale3`), the frame's `SetScale`. Its saved place is
  in its own units, which are the screen's divided by the scale, so a change converts the saved place and
  puts the window back with its corner where it was, and a drag saves the place the same way. The size
  limits are generous (up to 1000 by 1000) since the scale can be used for the rest.
- The windows are plain frames, so they move and resize in combat; only Lock Window stops that. The
  sizing flag lives on the frame (`frame.sizing`), which is what the layout reads while the client
  resizes it.
- A row has two value columns, the total and the per-second figure, each its own text with a title
  above it. The DPS and HPS lists are the game's own, sorted by the per-second figure, so they lead
  with it and the bars still show the total, as the game's meter does.
- Number formats go through the client's `AbbreviateNumbers` with a config of breakpoints (`DM.Format`),
  which takes a secret and returns a string made from it, so K / M / B, a chosen number of decimals,
  ten-thousands (by the client's locale) and full numbers all work in combat. A client without it
  falls back to `AbbreviateLargeNumbers`.
- A name is written by cutting its words at spaces and the client's surname separator, and its realm is
  dropped. In combat a source's name is secret and cannot be cut, but its class is not: the group is
  read from unit tokens, which stay plain, and a row is matched to the one member of its class. Your
  own row always comes from your unit. A class two members share, or one not in the group, shows the
  name whole, as the game gives it.
- Interrupts, Dispels and Deaths have no per-second figure, so a Per Second column skips them. Deaths has
  no spells either.
- Windows 2 and 3 use the first window's keys with their number added (`mode2`, `width3`,
  `meterPos2`), so the window code takes an index and reads `DM.Key(base, index)`.
- A past fight is a field of the window (`fight`), not a setting: the game's fight ids do not outlive
  a reset or a reload, so the saved session stays Current or Overall and a reset puts every window
  back on it.
- A spell panel asks the game for a source by guid, and in combat the game takes a plain guid only:
  your own row's (`UnitGUID("player")`) or one whose guid is not secret. Any other row says its spells
  show after combat. The share and the per-second figure are shown only when the amounts are plain
  numbers.
- A click on a row opens its source's breakdown in the window itself, in place of the list, and a click
  on it (or anywhere in the window, which takes the mouse while it is open) closes it. It is a session
  built from the source's spells (`DM.SpellSession`), then a Targets line and the enemies it hurt, so the
  same rows, bars and columns draw it: a spell row has `label`, `icon` and `isSpell`, an enemy `color` and
  its own `maxAmount`, and the heading `isHeader`. It is a field of the window (`detail`), found again in
  each update by your own row or its guid, so it follows the player when the order changes. A hovered
  spell shows the game's own tooltip (`SetSpellByID`) on the side away from the window, not for an id the
  game keeps back in combat. The hover panel is as before, with the per-second figure added.
- The share is a column of its own, made from the row's amount and the list's total once both are plain
  numbers, so it is empty in combat. Deaths has none.
- Column Divider writes the total and the per-second figure as one right-aligned text, `"%s | %s"` through
  `SetFormattedText` so a secret amount goes in as it is, in one column (`pane.merged`) as wide as both
  and the bar. The title over it is "Damage | DPS". It does nothing when only one figure is shown, and a
  spell whose per-second figure is not known yet shows its amount alone.
- Clean Look is one button for what makes the window as plain as the game's own bars: no column titles,
  buttons, rank numbers, backgrounds or border (the title bar and the window at zero opacity: `headerAlpha`
  and `backgroundAlpha` draw nothing, the line under the bar included), the column divider, and the time in
  brackets after the title (`timeBrackets`, `timeByTitle`). It sets plain settings, each of which has a control of its
  own, and asks first.
- The title bar's menu: the list and the session are in the window's ... menu, which a right click on the
  bar opens too. The session and ... buttons can be hidden (Show Buttons); the room they take is kept, so
  nothing else moves.
- Targets (the enemies a player hurt) come from the game's Enemy Damage Taken list: each enemy's data is
  by attacker and spell, so a player's share is the sum of that player's spells over the enemies. That
  is arithmetic over many amounts and a comparison of names, so it is done after combat only, from
  plain numbers, and only for Damage Done and DPS. It asks the game once per enemy, so the result is kept
  until the game's data changes.
- A spell's icon and name come from `C_Spell` through `pcall` and are tested with `type()`, never by
  truthiness, since a secret id gives a secret answer. They go to the texture and the text as they are.
- A report is made of plain numbers, so it is sent outside combat only, and a source whose name or
  amount is still secret is left out. It goes to chat with `SendChatMessage` from a menu click, which
  is a hardware event, so Say works too.
- The summary line under the title bar is made with one `SetFormattedText`: the session's name, its
  total (a secret string in combat), the raid's per-second figure and your rank. The raid figure is
  the total over the session's length, so it only appears once both are plain numbers, after the
  fight; your rank is your row's position in the game's order, which is never secret.
- The fight time in the title bar is the shown session's own length from the game
  (`GetSessionDurationSeconds`, or a past fight's from `GetAvailableCombatSessions`), read through
  `DM.Duration` and shown only as a plain number and only when the bar has room beside the title.
- The title bar's right end is the buttons. The title starts at the left and the time sits beside the
  buttons, and each has an X and a Y offset to move it from there (`PaintTitleBar`, from the window's
  width and the title's measured width, so a resize or a longer title is allowed for). The time goes when
  the title and it do not fit side by side, and a title too long for the room is cut. What the title says
  is the list's name, the fight's, or both: the fight's name is the game's own for a past fight, the
  newest one's for Current, and Overall for Overall (`DM.FightName`). In combat the newest fight listed
  is not the one running, so the title falls back to the list's name then, as it does for a fight the
  game has not named. The second list's title takes the title's offsets.
- Avoidable Damage is the game's own list of damage taken from avoidable abilities.
- There is no combat timer or cast history here: the QoL module already has a Combat Timer and a GCD
  Tracker.
- The reset key is `NaowhForever_ResetDamageMeter`, declared in `Bindings.xml`. Core defines a stub
  that says the module is off; this module replaces it.

- A fight is kept when combat ends (`History.Arm`), read again until its amounts are plain: they are secret
  in combat and for a moment after it. Only plain numbers are kept, a fight too short to be worth keeping
  is dropped, and the fights are on the account under the character.
- Take Screenshot waits a moment (`SHOT_DELAY`) so that the menu that was clicked has closed and is not
  in the picture.
- A source's spells are asked for by its guid, which is secret in combat except your own: `UnitGUID("player")`
  stands in for your row, and any other row says its spells show after combat.

## Checking

- `lua Tools/regression/test-damage-meter.lua`: the API reads, the windows, the menus, the report,
  the spell panel, where it shows, the game's meter, updates and the settings page, with amounts that
  fail on any arithmetic.
- `lua Tools/regression/test-nf-commands.lua`: the reset binding and its stub.
