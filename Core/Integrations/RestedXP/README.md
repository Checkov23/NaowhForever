# RestedXP themes and guide window

Naowh's theme, the eight theme presets and the player's current theme in RestedXP Guides, and the
hooks that style its arrow, title bar, quest list and scroll bar. Off unless Settings > RestedXP Theme (V1)
turns it on (`ns.FEATURES.account.rxpThemes`), and only with RestedXP Guides installed. Loads
through `RestedXP.xml`, after `Core/Core.xml`.

The Naowh guide window (`ns.FEATURES.account.rxpWindow`, also off by default) draws RestedXP's guide
in one Naowh window: the guide and its progress, the active step and the steps after it.

## Layout

```
Core/Integrations/RestedXP/
  RestedXP.xml                what loads
  Themes.lua     the themes, the settings behind the RESTEDXP card, and the hooks
  WindowSettings.lua  what the window can be changed in: its options, colors and theme
  WindowModel.lua     what RestedXP shows, read as plain data for the window to draw
  Window.lua     the Naowh guide window: its frames, drawing, clicks and the look of the two small windows
  Icons.lua      Naowh's step icons, put in RestedXP's icon table as it loads
  Media/         the themes' arrow, frame and grip art (rxp_*.tga), drawn by Tools/media/make_media.py
  Media/Icons/   the step icons, line/ and filled/ (28 each), drawn by Tools/media/make_rxp_icons.py
```

## Why

- RestedXP imports the global theme list (`RXPGuides_Themes`) as it starts, so the themes go in
  while our addon loads. If RestedXP is up already they go in through its own `RegisterTheme`, and
  a saved theme of ours it fell back from is reloaded at login.
- The hooks need RestedXP's frames, so they wait for PLAYER_LOGIN. Each checks what it needs and
  does nothing without it.
- RestedXP's functions change with its releases, so every call into one of them (its theme reload and
  `RegisterTheme`, `ReplaceNpcIds`, `GetGuideProgress`, `SetStep`, its menus, an objective's `OnComplete`)
  runs under `pcall` (`Run`), and a failure goes to `geterrorhandler()` once per call site, so BugSack
  shows it without one a frame. Our own hooks and drawing are not wrapped: an error in them is ours and
  shows like any other. Rows are remembered only when a pass got to the end, so one that failed is tried
  again.
- RestedXP's UI v2 hides its legacy window (`DisableLegacyGuideWindow`) but leaves the cog showing,
  as the cog hangs from the window and not from the footer. The banners, cog, grip, scroll bar and
  rules are therefore painted only while their part is visible (`Visible`), and again when it is
  shown: an OnShow hook on the window and on each part (`HookShown`), so a window that was closed
  and opened keeps no stale look. The look is not adapted to UI v2 yet; its windows get the colors
  through RestedXP's own conversion of the themes (`RXP.v2.themes`, from the fields in `Theme`).
- RestedXP's theme reload scales its protected target frame, so in combat it waits for the end.
- Naowh (current) is read from `ns.THEME`, the colors the addon itself is drawn in, not from the
  theme picked: the Forever skin overrides that pick (`ThemeSource` in Core.lua). The fixed themes
  come from `ns.ThemePalette`, which never carries the player's own colors.
- The font and text color are part of the themes, which RestedXP reads as it starts: they take a
  reload. The font is `ns.AddonFontPath`, not `UIFontPath`, which remembers what it finds and this
  runs before every addon has loaded.
- `dividerColor` and `chromeColor` are ours, not RestedXP's fields. The bars need a white fill to
  show the theme's color.
- Naowh's arrow image is drawn at a percent of RestedXP's arrow frame. With a glow the kite fills
  only 76% of the image (`GLOW_FILL`, see Tools/media/make_media.py), so that image is drawn larger to
  keep the kite the same size. RestedXP's Arrow Size setting resizes the frame silently, so its
  OnSizeChanged is watched.
- The colored layer over RestedXP's arrow is lighter at the top, deeper at the bottom and not full
  strength, so the dark arrow still shades it. It follows the arrow's rotation through a post-hook
  on its SetRotation. A turned arrow reaches past its square frame, so the layer covers the square's
  diagonal and its mask cuts it to the arrow; at the frame's own size the tips lost their color.
- RestedXP only sets the distance text, never shows or hides it, so hiding it is ours to undo.
  Moving it needs the anchor RestedXP gave it; a text with none has nothing to move or to give
  back, so it is left alone.
- The title bar and footer banners are plain black in DarkMode, so they are faded with SetAlpha to
  let the fill show; RestedXP sets them again whenever it draws its theme, so SetTexture is
  watched.
- The cog, corner grip and scroll bar have no theme field: the cog and grip get Naowh's images and
  the scroll bar a thin thumb without arrows, in Secondary Text. RestedXP never sets the grip
  again, so its original is kept to put back.
- Quest rows are 3 apart and the rule sits at the far edge of that gap. Rows are made when a guide
  loads, which ends in SetStep, so that is watched; rules are redrawn only when the theme or the
  row count changes.
- The guide window only reads RestedXP's data and never writes it, and RestedXP's own two v2 windows
  (the guide window and the active steps) are kept alive and out of sight: their rows are what
  RestedXP's step handlers write to (`BindActiveStepElement` sets `element.frame`, and the handlers
  set its text, icon and checkbox), so a second set of rows would not be updated. They are made
  see-through with `SetAlpha(0)`, held there by a post-hook on `SetAlpha`, and they and every frame
  in them take no clicks (`EnableMouse(false)`), the alpha and mouse kept to give back when the
  window is turned off. They are not hidden, as RestedXP shows and lays them out itself.
- A row shows the text RestedXP has in its own row now (`element.frame.text`), so counters such as
  "5/5" follow it; a post-hook on that text asks for a redraw. A click on a row is a click on
  RestedXP's own checkbox, so what it does for a skipped step is RestedXP's.
- Everything that changes asks for a redraw, and the redraw is one per frame (`C_Timer.After(0)`):
  `SetStep`, `UpdateGuideWindow`, `UpdateActiveStepsFrame`, `UpdatePlayerActiveStepItem` and the
  rows' text. The first four are RestedXP building what it shows and the last is a counter ticking:
  only the first four make the redraw read RestedXP's steps and walk its windows again (`Rebuilt`).
  The window needs RestedXP's V2 interface (`v2:IsGuideWindowEnabled()`): the active step rows and
  the guide's rows are built for it.
- The list under the active step is the guide's steps as `v2:BuildGuideStepsSnapshot` has them, which
  is what RestedXP's own v2 guide window lists: a step it hides is not listed, and a step done is, a
  little dimmer, so that a step can be gone back to. It starts at the first step after the active one
  and the mouse wheel moves it, two lines a tick, over the steps before (the one the guide is on in
  the accent color) and after. The wheel scrolls it over its lines, and only while there are more
  steps than lines, so anywhere else it still zooms the camera. A bar that shows where it is (Show Scroll
  Bar, off to start: the list is as wide as the step box, and no tooltip says it scrolls) is there only
  when there are more steps than lines: it is at the right edge of the step box, as wide as the steps
  are and not at the window's (where it looked like it belonged to nothing), and the lines end before
  it. It goes back to the steps after the active one when the guide moves on (a
  new progress or guide), and not when RestedXP builds again, so a list being read is not taken from
  the reader. Listed Steps is how many lines it has, and a click on one goes to that step as it did
  (shift-click to start): `SetStep` is what RestedXP's own "Go to step" calls, back or forward. With
  RestedXP's Hide Completed Steps on, the snapshot has no done steps and so neither has the list.
  The snapshot walks the whole guide and joins every step's text, so it is read once and kept, by
  guide, until RestedXP builds again, and the text of a line is made when the line is drawn. A counter
  ticking redraws from what was kept, as RestedXP's own window is only rebuilt then too: with a guide
  of 700 steps a redraw went from reading it (2.6 ms of Lua, plus the same in RestedXP's own window at
  its layout) to none.
- RestedXP's two windows are walked (`Silence`) for frames made since the last time only when it built
  something, and when they are given back and taken again. A window that is not there yet is asked
  for at every redraw until both are.
- A font string of the window's own is set once: `Faced` leaves it when its path, size and outline
  are the ones it has, and the two font strings of a row, which their row sets at every draw, are not
  in the loop that follows an option. A redraw that changes no size sets no font (22 calls before, in
  a window of three rows and six lines). RestedXP's own title text, which it may set again itself,
  is always set, at RestedXP's own size (`BOX_TITLE_TEXT`, 9) and never at the size `GetFont` answers:
  a title whose font did not load (a cold login, before the font is there) answers a size that is
  garbage, and `SetFont` refuses a height of 0 or less with an error the client reports even when it
  is caught. RestedXP sets every one of these titles at 9 itself.
- The window has no panel of its own, as RestedXP's coming layout has none: a header with a rule under
  it, the active step in a box (the only thing with a background), and the steps after it as plain
  shadowed lines over the world, so every text carries a shadow (`SHADOW`) to be read on any ground.
  The lines after the active step are plain text (`Plain`: no icons, colors or links), as the active
  step's rows are what carries them. RestedXP's menu is a right click, on the window and on a row and the
  box of the current step too (they take the mouse, so each is given the right button), and not on a
  line of the list: those are for going to a step. A button for it was taken out as it was the same menu,
  and the tooltip of the first line says where it is. A locked window has no grip.
- The window's size is one scale (`SetScale`) for the whole of it, text included, and the width is the
  room the text has inside it. Changing the scale keeps the window in the same place on the screen:
  its anchor is kept in the scaled units, so it is multiplied by the old scale over the new one, in the
  saved place too when the window is off.
- The arrow's text is RestedXP's step title and its distance, set again every time the distance
  changes. With Arrow Shows Objective the text is put again after RestedXP's own (a post-hook on its
  `SetText`, which `composing` keeps from calling itself): the distance, then the words of the
  objective the waypoint belongs to, as RestedXP shows them in its own row when it has one, as plain
  words (`Plain`: no texture or atlas, which RestedXP puts in a row of its own and in the text of
  some lines). A guide often writes the place first and what to do there after it, so the waypoint has no
  `element.parent` (the line above it, `addon.lastObjective`): its own words come next, then the
  lines of its step after it, then the ones before it, leaving out one that is done or has no tooltip. A waypoint with no words says only the distance, and RestedXP's "~" on the
  wrong continent is left. It does not wait for one of the Naowh themes to be picked in RestedXP, as the
  words are not part of how the arrow is drawn. Turning it off makes RestedXP say its own text again by clearing
  `arrow.distance`, which RestedXP compares before it sets the text.
- The arrow's font is set by RestedXP's `SetupArrow` and by its Arrow Text Size setting, from
  the font of the theme picked, which is ours only when one of ours is picked. While the arrow is ours to
  style (below), a post-hook on its `SetFont` puts it in the Addon Font (Arrow Addon Font), with the outline
  RestedXP gave it, whatever RestedXP sets next. Its size is RestedXP's own (its Arrow Text Size, 9 to
  start) until Arrow Text Size is picked here: only then is ours held, so RestedXP's slider keeps working
  for a player who never picked one, and ours shows RestedXP's until it is picked. A path the client
  hands back spelled differently would make the font chase itself, so a flag (`keeping`) holds the
  hook while it sets one. With Arrow Shows Objective its text is also given a width (`TEXT_WIDTH`) so a long
  objective wraps under the arrow and does not run across the screen; it is its own width again without it.
  With the switch off RestedXP's own font (`RXP.font`) is given back. The
  window uses `ns.AddonFontPath`, which is read live, and not `ns.UIFontPath`, which keeps the first
  path it found.
- The window is three files in load order, each one job: `WindowSettings.lua` (what can be changed, read
  live by the others; it tells the window to draw again through `ns.RXPWindowRefresh`, which the window
  defines), `WindowModel.lua` (reads RestedXP and returns tables; draws nothing) and `Window.lua` (frames).
  What each reads of the others is a function on `ns`, never a file-level local. `Run`, which returns
  what a call into RestedXP returned and reports what raised, is shared through `ns.RXPSafe` with `Has`
  and `Dig`.
- What the window can be changed in is two lists in `WindowSettings.lua` (`OPTIONS` and `COLORS`), each with its
  kind, default, range and tip, and the settings page draws its rows from them (`WindowOptionCell`,
  `WindowColorCell`), so a new option is one entry. A value is kept only when it is not the default, and
  a color whole (r, g, b, a) or not at all, so the theme's stays the default and follows it. Every text
  is made with `Text` and set again with `Face` each time the window is drawn, which is what lets the face,
  the outline and the three sizes change at once.
- The progress bar is a `StatusBar`: the guide's under the title (the step over the number of steps, so
  36 of 66) and one in the active step (the rows done over its rows). Its texture is a SharedMedia
  statusbar picked in the page and flat to start, its track is the Bar Background Color (the Line color
  to start) and its fill the Bar Color (the Accent color to start, `barFill` follows `accent`, so it is
  the theme's). The fill's height is fixed (`BAR_HEIGHT`).
- The step box and the bars have a border of their own, one pixel to start and black in the Naowh theme,
  as Naowh's house style has it and as Naowh asked for them: Step Box Border Size and Color, Bar Border
  Size and Color, and the bar's background. The color is themed (`edge` in `COLORS`, `ThemedEdge`): black
  for the addon's own theme, the preset's line color for a preset (the window's or the addon's), and the
  Forever skin's bronze for the skin, so a theme keeps its look and only the Naowh theme is black. The
  size is in whole screen pixels: both are the shared `ns.Border`, whose `SetPixels` sets how many, and
  which refits them like every other border when the UI scale changes. The bar is that much
  taller, `EDGE_SIDES` times the size, so its fill is as thick as it was: the border is inside the bar's
  frame and over it. The three colors are the player's in every theme (`always` is set on them): a
  theme's edge is not what a player has to take, so Custom is not needed to change it. The window's own
  border keeps the Border Color, and the two windows of RestedXP that take the step's look (Active
  Targets and Items) take the step box's, as they are drawn as the step box is. The Forever skin draws
  its own rim and inset, so its look has neither the border nor its size.
- The window is resized from its corner (`StartSizing`). Its height is what it draws, so the height does
  not set a height: it sets how many steps are listed. Draw keeps the height the window has without the
  list (`chrome`) and the height of a line, and letting go of the grip turns the width and
  `(height - chrome) / line` into the width and steps settings and draws again at the size that fits.
  Its bounds are the smallest (no steps) and the tallest (all of them). Lock Window stops moving and
  sizing, and a folded window has nothing to size. The width has no slider and the grip no switch:
  the corner is the way to size the window, so a setting for either was one more row to say the same
  (only the lines keep one, Listed Steps, as a number is exact where a drag is not). A grip that an
  older version had switched off is shown.
- The window follows the drag as it happens (`OnSizeChanged` while the grip is held): what the list can
  show is read once when the grip is pressed, with every step it could list, and each size drawn from
  that, so nothing is read again per frame; the window does not set its own width or height while it is
  dragged, as the drag does, and what is kept is set when the grip is let go. The width is kept to the
  pixel.
- The guide's progress under the title is the only bar of the window besides the ones of a row that
  counts: a bar of the objectives done under the active step was tried and taken out, as it read as one
  thing counted twice beside the guide's. The box's own opacity is a setting (`rxpWindowBoxOpacity`) and
  not a part of its color. The bars are in the Naowh Gradient to start (`GRADIENT`, which is `ns.MEDIA`'s,
  so a texture of SharedMedia is only needed when another is wanted).
- RestedXP's logo (`Textures/rxp_logo-64`, the one its own window and quest log use) is drawn from
  RestedXP's files in the top right corner of the current step's box (the first, when there are more),
  untinted, at a fixed size (`LOGO_SIZE`). It is a texture of the
  box, so it is above the box's background, and the rows start below it, or below the label when it is
  smaller. The window hides RestedXP's own and so would otherwise show nothing of it anywhere.
- The rows after the first of a step are set in (`INDENT`, fixed), and narrower by as much, so a
  Buy under a Talk to reads as a part of it.
- A click skips or goes to a step and never ticks an objective: a sub task completes itself as RestedXP
  sees it done, and skipping one by hand is not offered. On the whole of an active step (its rows and the
  box round them, which each know their step: `step` on a row, on the box) a click goes to the step after
  the guide's progress, unless the step is not the guide's progress (a trainer to see, which stays active
  beside it, `sticky`): then its objectives are skipped as RestedXP's checkbox does (`element.skip`,
  `OnComplete` once, `updateSteps`) and RestedXP lets it go, as going to the next step would leave it
  where it is. On a line of the list it goes to that line's step. Both need Shift by default (Skipping
  Steps), as a plain click is also where a window is grabbed to be moved and a step skipped by it is not
  given back; Click and Off are the other two. The tooltip is the box's wherever the mouse is in the step,
  and Show Tooltips turns it off. A right click is RestedXP's menu on the window and on a step, and not on
  a line of the list, those being for going to a step. The list's lines are a transparent button each
  (pooled as `hit`) over the text, so they are also where the window is dragged from, and with Off they
  are not lit.
- A row that counts has a bar under its text: a buy by the items in the bags against `qty` (RestedXP shows
  no counter for it, so `C_Item.GetItemCount(id)` is read, and the window listens to `BAG_UPDATE_DELAYED` only
  while such a row is drawn), and any other row by the `3/8` in its text, which RestedXP rewrites as the
  count changes and so redraws the window. A count of one is a tick box and not a bar, and a count past
  its total is full. A buy that is done is full whatever the bags hold now (what was bought is used or
  sold), but a line with its own count is drawn by that count, done or not: RestedXP marks some of them done
  that still say 0/8 (an objective it skips, like a loot it says not to go out of the way for), and a
  full bar under 0/8 would say the opposite of the number. Only `buy` tags are counted from the bags, as
  another tag's `id` or `qty` can mean something else.
- The Active Targets and Active Items windows (`RXPTargetFrame`, `RXPItemFrame`) take the look of the
  active step's box: the colors of their v2 background and border textures are set in place after
  `UpdateVisuals` (and after the targets' `RenderTargetFrameBackground`, which settings call alone), and
  their title's text takes the window's face and color, kept at RestedXP's size so nothing is laid out
  again. Each is hooked once (`watched`); a frame RestedXP makes later is taken at the next draw. The
  border follows the background, so a background RestedXP hides keeps its border hidden. Turned off
  (the window), RestedXP's own `UpdateVisuals` paints them again, and the
  border is shown where the background is, as the title's is not set by it. The title is in the window's Title
  Color, as the guide's name is, and not in the accent. The buttons of the targets that have no portrait yet
  show a placeholder (the chat bubble for a friendly one, the sword for an enemy: file IDs 2056011 and 135274
  that RestedXP sets again at each `UpdateTargetFrame`), and with a step icon style picked those are the
  gossip and combat glyphs (`RXPIconTexture`), put right after each update and given back when the window
  goes off; a portrait is never touched.
- The icon at the start of a row has a fixed size of its own (`ICON_SIZE`, 18, over the text's 13): the
  icon's font string is faced at it, so RestedXP's own icons (`|T...:0|t`, as tall as the text they are in)
  grow with it, and the column and the row are as big. The text is dropped to the middle of an icon that
  is taller than it, and not when it is smaller.
- The first line of a step is bigger than its sub tasks (`FIRST_GROW`, 2 over the text size).
  `Refaced` sets every row's text to the text size at the start of a draw, and `DrawRow` sets the first
  row's again with the bonus, so a pooled row that was the first and is not is back at the text size at
  the next draw. The title has no bar at its side (the sub tasks keep theirs, which say open or done), and
  its icon is bigger by the bonus twice, as its text is bigger by it once; the column, the drop of the text
  and the row follow the icon's size of that row.
- RestedXP keeps its settings by profile, which is a character's own unless the player shares one, so a
  character it has not met has its defaults: the V2 interface off, which the window needs, and its own
  theme. Set Up New Characters (off to start, the first thing in the window's (V2) fold) sets, the
  first login of a character, `enableBetaFeatures`, `enableV2Interface` and the Naowh current theme in its
  profile for what is wished for, and asks for a reload as the interface is read when RestedXP loads; what
  the player changes after is theirs, as the characters done are kept (`rxpSetUp`, by GUID). The button
  does it for the character played, seen or not. The Naowh themes are registered in RestedXP while the
  window is on as well as with the theme (V1), so Set Up has the Naowh current theme to pick; one turned on
  since the last load is registered by Set Up itself. A theme picked with RestedXP's live reload off waits
  for a reload, so the button asks for one. RestedXP puts its waypoint arrow at the top of the screen
  (`framePositions.arrowFrame`, by profile), and a character that is set up has an arrow that is still
  there in the middle: in the profile, which is read at load, and on the frame, so that the position
  RestedXP saves when the game closes is not the old one. One the player moved is left where it is.
- In the Forever skin (the addon is in it and the window's theme is the addon's, or the window's theme is Forever) the
  window is drawn in the skin's art where the client has it (`SkinParts`, `Skinned`): the bronze inset
  (`ForeverInset`) behind the step box with its border on and behind the window with its border on, in place
  of the flat back and line, the skin's rim and field on the bars, and its plus and minus for the fold. The
  box's opacity and the window's panel are the fill of the inset; with no border the flat back is what is drawn.
- The window has a theme of its own (`rxpWindowTheme`: the addon's current one to start, a preset, or Custom),
  picked in its fold, where the addon's own is called Current Theme, as RestedXP's theme list does, and
  shown at once. It is the window's colors alone: the addon's theme (COLORS) is not read for
  a preset and not set by it, and the icons and the arrow follow the window's. The colors are the preset's
  and the player's own only while it is Custom (`RXPWindowOwnColors`): a theme is a look as a whole, so the
  nine colors are shown only for Custom, and what was picked is kept for when it is Custom again (the four of
  the step box's border and the bars, `always`, are shown and kept in any theme). Forever is
  the addon's Forever skin for the window alone: its gold and bronze (`ns.FOREVER_SKIN`) and its face, with the
  addon left as it is (the skin itself, under COLORS, is read at load and takes the window with it when the
  window's theme is the addon's). The
  waypoint arrow's color is one of them, used by the arrow (`OwnArrowColor`) only with the window on and
  Custom, and the arrow is painted again when it, the theme or the reset changes it. A step of the list lit
  by the mouse and the title of the tooltips are in the accent, a little see-through for the first, and not
  the text's color or the game's gold.
- The theme (RestedXP Theme (V1)), the arrow (Style RestedXP's Arrow) and the window (RestedXP Naowh
  Window (V2)) are each a switch, and the theme and the window each a fold with its switch on its title
  (`W:SwitchFold`, a `W:FoldHeader` with a switch: shut to start and kept as it is left like the other
  folds, opened when its switch is turned on and while searching, no chevron while there is nothing under
  it, ended by `W:EndFold` so the rows after it are not held back; `W:GroupHeader` is a title inside a
  fold that goes with it), and none
  reads another's rows. The arrow's options are in the fold of whichever of the two is on (once), and in a
  section of their own, RESTEDXP ARROW, while neither is. The theme and the window are
  never both on: turning one on turns the other off (`SetRXPThemes`, `SetRXPWindow`), and a saved pair is
  read as the window's (`RXPThemesEnabled` is false while the window is wished for). The arrow is its own
  module (`RXPArrowEnabled`): it is hooked at login when it is on, with the theme or the window or neither,
  and with a font of its own (Arrow Addon Font, `rxpArrowFont`). With the theme (V1) on it is styled only
  while one of ours is RestedXP's active theme, as it was before the window, and given back as RestedXP
  draws it under one of RestedXP's own (`ArrowStyled`); with the window on, or neither, there is no theme
  of ours to pick, so it is styled in the window's color or the live Naowh accent. An account from before follows the theme it had on until the arrow is
  set once, and the theme or the window being switched sets it as it was, so that taking the theme away
  does not take the arrow with it.
- RestedXP's two v2 windows are taken (made see-through and click-free) whenever the window is on, with a
  guide or without one: its welcome window ("Select a guide:") would say what ours says. They are given
  back when the window goes off. The hook that keeps them dark follows what is silenced and not whether
  the window is on, as giving them back sets their alpha through it.
- With RestedXP there and no guide (a new character, in RestedXP's V2 interface, shows nothing of its own
  until one is picked), the window is shown as that: "No guide selected" and a line, Pick a guide, which
  opens RestedXP's list of guides (`v2:ShowGuideSelectionMenu`, the one its welcome window opens on a right
  click, or its menu when it has none) with a plain click: there is nothing to skip, so it takes no shift.
- The step icons are a style (`rxpIconStyle`: RestedXP's own, line or filled) and not a switch, kept only
  when picked. RestedXP builds its rows, tooltips and quest log lines from `RXP.icons` as a guide loads
  (`element.icon`, `tooltipText = icon .. text`) and its v2 window takes an icon off the front of a line by
  comparing text with the table's current value. The table is therefore replaced when RestedXP's
  `ADDON_LOADED` arrives, before any guide parses, and a change of style waits for a /reload: an icon
  baked under the old style would no longer match and would show twice. Every key RestedXP files (and the
  aliases it makes from them at load, such as `explore` and `groundgoto`) is replaced by its own name, and
  only when its value is text, so a key it drops or renames is left alone. Without a style nothing is
  listened for.
- The icons are white over alpha at 64 texels, drawn from one geometry per glyph: the body is outlined in
  the line style and solid in the filled one, the detail is stroked and cut out. The escape that draws
  them carries the theme's accent as its vertex color (`|T...:r:g:b|t`), read as RestedXP loads, so it
  follows a theme change after a /reload. Their size is `0`, the height of the text, as RestedXP's own.
- The icons have no colors of their own: they are in the window's Accent Color (`RXPWindowColor("accent")`,
  the theme's accent to start, the theme's alone when the window is not there), so that no icon reads as
  unthemed and one color covers the level range, the step count, the bars and the icons. The escape bakes
  the color in, so RestedXP's own windows take a change at the next /reload; the Naowh window does not use
  the escape: it reads the path out of the row's text (`RXPIconLook`) and draws a texture, so a color
  picked, or a theme token, is live there, and a done row is dimmed.
- The style is the window's own setting (Step Icons, in the window's (V2) fold, beside its scale) and is
  only in force while the window is wished for (`RXPIconStyle` is RestedXP's own otherwise, the choice
  kept), so the table is left alone for a player who does not use the window.
- The two placeholders RestedXP shows on its target buttons until a unit has a portrait are not in
  `RXP.icons` either (file IDs, not escapes): the Naowh window takes them (see the Active Targets bullet) and
  `RXPIconTexture(glyph)` gives it a glyph's file in the style picked, or nothing without one.
- Two icons are not in `RXP.icons` but inside the guides' text, in most of its lines: the grey speech bubble
  (`chatbubble_64grey`, on every Talk to) and the interact cursor. They are baked into the text RestedXP
  parses, so the table cannot reach them and rewriting 27 thousand lines of guide text would not be ours to
  do; the Naowh window swaps them as it reads a row (`RXPIconText`, by path, whatever its case and
  slashes), in the row's group color. RestedXP's own windows keep theirs.
- A line that begins with an icon of its own (the speech bubble of a Talk to) has it lifted into the icon
  column when the row has none, at the height of the text, so every row has its icon and its text at the
  same place; a row that has an icon keeps the one in its line, and one in the middle of a line stays.
- An item's icon at the start of a line (a file ID, or `Interface/Icons/...`) is lifted into the icon
  column like a marker is, and the line is set in as far as the column on top of the sub task indent, so
  the items listed under a "Buy the following:" sit under its text and not at its marker. A marker (the
  speech bubble, the interact cursor, ours) is set in as a sub task is, and the first line never is.
- The line of an item listed that way has no bar at its side: that bar says open or done, and
  RestedXP's tracking of such a line marked items done that were not in the bags. The counts under it
  (a line with a `5/5`, a buy) keep their bars.
- A line of words that is not a task (`textOnly`, with no marker of its own: "Don't go out of your way to
  loot all of them yet") has no bar and no icon: it has nothing to be open or done. RestedXP hides the icon of
  such a line but its frame keeps the text of the element it showed last, so an icon is only read from a
  frame that is shown (`IsShown() == false` is none); that is what put a question mark on it.
