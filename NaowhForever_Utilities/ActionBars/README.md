# Action Bars

Every action bar slot, macro and keybind saved under a name and imported later, out of combat.
Sets belong to a class and are shared by every character of that class on the account. The
window (`/nfbars`, `/nf bars`, Open Action Bars on its settings page) shows your class's saved
sets, the set builder (pick the bars, slots, keybinds and macros that go in) and the import
preview (your bars as an import would leave them), laid out like the Forever website's Action Bars.
Export to Website gives your bars, or a saved set, as a code the website's Import a code loads.
`/nf bars save|import|test|delete <name>`
and `/nf bars list` do the same from chat. `/nf ab <name>` imports a set and `/nf ab` lists them.
Import on New Character imports a chosen set once, the first time a new character of that class
logs in (level 1, no experience yet).

## Layout

```
NaowhForever_Utilities/ActionBars/
  ActionBars.xml                every file, in load order, included by Utilities.xml
  ActionBars.lua                its settings, this class's saved sets and the module table (ns.ActionBars)
  Constants.lua                 the slot counts and icon several files share (A.C)
  Data/
    Bars.lua                    the bars as the game numbers them, with the binding each answers to (A.BARS), the
                                pet bar's keys (A.PET_BAR) and the pages each class's forms swap in (A.FORMS)
  Capture.lua                   the bars, macros and keybinds as they are now, read into a set, and the highest
                                rank of each spell known (A.Capture)
  Import.lua                    one pass over the bars putting a set back, or testing it (A.Import)
  Pending.lua                   spells an import could not place, put in their slots when learned (A.Pending)
  Sets.lua                      save, import, rename, delete, /nf bars, and the public API (ns.ActionBarSets)
  View/
    Style.lua                   the window's colors and sizes, on top of Shared/Style.lua (A.Style)
    Parts.lua                   labels, chips, tick boxes, slot tiles, glass panels, the bar strip at any size (the
                                scene's, and a set row's small one), the scene with its pet row, form chips and bar
                                picker, the window's panes (A.Parts)
  UI/
    SetsPage.lua                the home: Save Current Bars, Import Website Code and Export to Website cards, then a
                                row per saved set with a small strip of its bars, Import and More (ns.BuildActionBarsPage)
    Builder.lua                 the set builder: your bars on the scene, keybinds and macros, a name (A.Builder)
    Preview.lua                 the import preview: the same scene, then what comes across (A.Preview)
    Window.lua                  the window, its three views and its back link (ns.OpenActionBarsWindow)
    SettingsPage.lua            its settings page (Action Bars/Settings), declared as cards
  README.md                     this file
```

Each layer uses only the ones above it. The window hands the builder and the preview its own
table (the frame, `Show` and `Redraw`) when it builds them.

## Why

- `KEYBOARD_SLOTS` is 180: the keyboard's slots, 15 pages of `SLOTS_PER_BAR` (12). The gamepad's
  slots come after them, read for as long as the client says the next one is valid.
- In `Data/Bars.lua` the main bar's second page and the stance bars answer to the main bar's keys
  (`ACTIONBUTTON`), as the game binds them.
- The last set this character saved or imported (`barSetLast`) is kept with its class, since a
  set's name means something only within its class. Save on Logout writes back to it unless the
  character only imported it (`saved = false`), so an alt never writes its own, half-filled bars
  over a set; entries from before that flag count as saved, as they always did.
- The game no longer reports the action bars at `PLAYER_LOGOUT` (macros and keybinds still read):
  saving then wrote a set with no actions (Itsmarco and POK, 2026-10-11). Save on Logout keeps a
  copy of the slots instead, taken `LOGOUT_COPY_DELAY` after the bars, macros or keybinds change
  and when it is switched on, and saves that with the macros and keybinds read at logout. A hand
  save drops the copy, so logging out right after it changes nothing; so does switching it off. A
  slot changed in the last `LOGOUT_COPY_DELAY` before logging out is not in it.
- Set names match without case, so `/nf bars` finds them however they are typed.
- A macro slot's action ID is the spell or item it shows, not the macro, so the macro is found
  by the name the slot carries.
- This character's macros are found by name and text, and by text alone, so a set's macro is
  found again under another name and never made twice, and a macro the player has is never changed.
- A Smart Macro (`ns.MacroSmart.list`, NF Bandage and the rest) is found by name alone, before any
  text match, and never made: the Macros module rewrites its text on every character for what that
  character carries, so an alt's copy never matches the saved text, and making the saved one gave
  a second, stale macro of that name. The first by name is the one the Macros module keeps
  current, so an older stale copy is passed over. One switched off stays gone.
- Sets saved before macros were kept whole carry only the macros on their bars, in their slots.
- `GetMacroInfo` gives a `#showtooltip` macro the icon it was showing. Made with that icon, the
  macro would stop following its spell, so it is made with the question mark (`QUESTION`, 134400).
- The game keeps macros sorted by name, so making one moves the others: the index is read again
  after an import makes any.
- A test import makes nothing, so it counts the macros it would make to know when the tabs fill.
- A spell falls back to the highest rank known when the saved rank is not, so a set made at a
  higher level still imports. Highest Rank picks the highest first.
- A slot marked Highest (`top`, from the website's Highest or saved from your bars) places the best rank
  this character knows; one without it places its own rank, so a Rank 1 Frostbolt kept for downranking
  stays Rank 1. Highest Rank still makes every slot Highest. Saving from your bars marks a spell Highest
  when it is the highest rank you know.
- The highest rank is the highest numbered rank (the spellbook's subtext) of the same spell name, the
  name the client gives the slot's spell ID, so a website code's English names work in any language. A spell
  with no number there, such as Polymorph: Pig, is a spell of its own: it is never swapped for another
  spell's top rank, nor placed in its stead when it is not known. One the spellbook does not hold is read
  with `C_Spell.GetSpellSubtext`. Rage and energy abilities that Forever keeps up to date are unchanged.
- Every slot ends as it was saved: a slot the set keeps empty is cleared, and so is one whose
  action cannot come back. A slot left out of the set, or holding something no set can import (a
  mount, a pet, a flyout), is left as it is. Keys the set leaves free keep what they do.
- Fill In As You Learn: the spellbook takes a new spell on the `SPELLS_CHANGED` after
  `LEARNED_SPELL_IN_SKILL_LINE`, and in combat the placing waits for `PLAYER_REGEN_ENABLED`. A slot
  the player filled meanwhile is theirs. The game may put a spell on the bars when it is learned;
  a copy in a slot the set keeps empty is taken off.
- Picking up, placing, binding and making macros are protected: they run only from `Ready()`,
  which refuses in combat, or after combat ends.
- The window's redraws are gathered into one on the next frame (`C_Timer.After(0, ...)`).
- The builder's switches read the draft when they are made, so a draft exists before the window
  is built.
- `/nf ab` is its own command, not the module alias `/nfab`: an alias shares `/nfbars`'s handler, which
  cannot tell the two apart and would read the set name as a `/nf bars` subcommand.
- Import on New Character waits for `PLAYER_ENTERING_WORLD`, when the spellbook is loaded, and for
  the end of combat. The character is recorded by GUID (`barSetAuto`) when the import runs, so it
  never repeats; the spells a level 1 character has not learned are placed by Fill In As You Learn.
  The choice is kept per class (`autoImportSets`, class token to set name), follows a rename and is
  cleared when its set is deleted. `UnitXP` must be 0 too, so an existing level 1 alt is left alone.
- `/nf bars restore` still imports, as it did before `import` was its name.
- The pet bar (`BONUSACTIONBUTTON1` to `10`) comes along as keys only: a set never places a pet action,
  since the pet's bar is the game's own. Saving keeps its keys with the rest; clicking the builder's PET BAR
  label leaves them out (`choices.petOff`). Hunters and Warlocks see its row of keys above the strip, in the
  builder and the preview.
- The builder and the preview draw the website's strip: Action Bar 3 (6 by 2) on the left, Action Bar 2 over
  Action Bar 1 in the middle, Action Bar 4 (6 by 2) on the right, 24 buttons of 38 (`TILE`) across, the site's
  size; 918 wide, it fills the 968 the window leaves inside its edges. The window is 680 tall (`HEIGHT`), on
  screen at 1080p. The scene is as tall as what it holds: 190, or 249 with the pet bar's row
  (`P.SCENE_H`, `P.PET_SCENE_H`), and the panels under it hang from its bottom.
- The bar picker sits under Action Bar 3, beside the form chips, as the site's switcher does, so it never
  pushes the strip down.
- One strip drawing (`P.PlaceStrip`) lays out the scene's buttons and a saved set's small strip on the home,
  15 (`MINI_TILE`) with 1 between; the small one is textures only, drawn from the saved slots, never the bars.
  Its tags name what it cannot show: the form pages ("+ Stealth", "+ 3 forms"), other bars and the pet bar's keys.
- The builder has no step strip: its three steps were one screen, so the tabs did nothing.
- The builder's Keybinds and Macros heads sit side by side over the macro list, which takes the full width;
  Keybinds counts the keys on your bars and those for other commands.
- A class with form pages (`A.FORMS`: a Rogue's Stealth, a Druid's forms and Prowl, a Warrior's stances)
  gets a chip per page under the strip; the chip picks which page Action Bar 1's row shows, with its
  count, and dims when that page is left out. The other bars (Action Bar 5 to 8, Page 2, the stance and extra
  pages a class has no form for) are picked from the scene's list, as on the site, and shown on their own.
- Show empty bars is gone: the strip always shows every button, empty ones empty, and the list picks the
  other bars, so nothing is hidden for it to show.
- A bar's label leaves the whole bar out or puts it back; a left-out bar dims to `DIM_ALPHA` (45%) and its
  label reads LEFT OUT. A button skips just its slot (`OUT_ALPHA`, greyed, with a cross). Hovering a bar or
  its label draws the website's gold outline round it (`GOLD_SOFT_RGB`, #e9cf9a). The step strip marks the
  part last used.
- The colors are the website's: its gold (#d1ad74, #e9cf9a), the green of a switch that is on (#4fd36b),
  the scene's night blue and its glass panels. Labels are the site's uppercase mono, in JetBrains Mono
  (`MONO_FONT`). Glass panels keep the site's faint white hairline (`GLASS_EDGE_ALPHA`) in place of the house
  black edge, so they read as the site's; buttons and tiles keep their black edge. The kit has no rounded
  corners, so the panels are square.
- The main buttons (Save Set, Import, the home's Save, a row's Import) are the site's solid blue with white
  text (`ns.PrimaryButton`); the others keep the house outline. A home card's button is a verb (Save, Paste
  code, Get code) under its title, so the two never repeat.
- A wrapping line is held by its top corners (`TOPLEFT`, `TOPRIGHT`), never a `RIGHT` point: a side point
  also fixes its middle, which cut the home cards' lines short.
- The window's back link sits by the close button. Opened from Settings, it reads Settings and closing
  goes back there, as the options window asks; otherwise it goes back to the saved sets.
- Stop Auto Push Spells to Bars (the New Spells card) is the game's `AutoPushSpellToActionBar` setting itself,
  read and written as it is, with no saved key: the game keeps it, so it stays as the player left it on the
  old QoL > System page, and it works whether Action Bars is on or not.

## Checking

- `luacheck NaowhForever_Utilities/ActionBars` from the repo root.
- `lua Tools/regression/test-action-bars.lua`: saving, importing, testing, Fill In and the
  commands against a small fake of the bars, spellbook, macros and cursor.
- `lua Tools/regression/test-action-bars-new-spells.lua`: the New Spells card's toggle against a fake of the
  game's setting.
- `lua Tools/regression/test-action-bars-window.lua`: the window's three views built from the
  real files: the home's cards and set rows, the paste and export popups, the strip for each class
  (a Rogue's Stealth chips, a Druid's forms, a Hunter's pet row, a Mage with neither), a bar left out by
  its label, a slot skipped, the bar picker, the summary, saving, and the preview's strip and Import.
- `lua Tools/regression/test-action-bars-export.lua`: Export to Website read back through the addon's own
  import gives the same slots, macros and keybinds, with no Highest flag gained or lost, and leaves out what
  the website cannot show.

## Website imports

Import Website Code, and the Profiles page's Import, accept versioned !NFA1! layouts from the Forever website.
Sharing.lua validates the class, slots, action types, byte limits and decode limits before
saving anything. Confirmation creates a uniquely named set and opens the existing preview;
it never places actions. Applying remains the normal out-of-combat player action.
Keyboard slots the layout leaves empty are cleared, so the bars end as they were built on the
website. Gamepad slots, and every slot when the layout carries only macros, are left as they are.
Keys not assigned by the website build keep what they do, but an action the layout binds keeps
only the layout's keys: its other keys come off first. A button shows its first
key, so one bound on top of the old key kept showing, and answering to, the old one. A saved set
still only adds its keys, so importing it never takes away a key the player added.
A website layout (`choices.website`) also fills in its spells as they are learned whether Fill In
As You Learn is on or not (`pending.always`): the player built the bars for the levels to come, and
would not know to switch it on. The preview says so in place of the switch, and the import lists
those spells with the level each is learned at.
Keybinds are restricted to known action-button commands and the pet bar's 10, with at most two per
action (212 total). A command outside them, or a button past a bar's end, rejects the whole code.
Binding syntax supports punctuation, international characters, named keys, mouse buttons 3-31,
F1-F24 and general or sided modifiers, including Meta. Modifier order is normalized; legacy
MINUS/EQUALS names become the native -/= keys. Unknown device-specific names are left to the
client's SetBinding validation when applied; malformed names, bare modifiers and mouse buttons
1-2 are rejected. This adds no automatic binding calls or lifecycle work. Macro bodies are data only;
the preview lets players inspect them before import. No hooks, events or frames are added
until the player opens the existing window.
The layout's macro list (`macros`, at most `MAX_MACROS`) is made with the macros on its bars, whether
placed or not, each once by name and text. A macro is a character macro unless the layout marks it
account-wide (`perCharacter = false`), and keeps the icon it was given, except a `#showtooltip` macro
(above). A layout with more account or character macros than the website holds (`MACRO_CAPS`, 120 and
60) is turned down. These are the website's limits, not the game's (`Constants.MacroConsts` says 30
character macros), so the import itself makes only what fits in the game's free slots of each kind.
A code of 180 macros of 255 bytes, each also on a slot, with every keybind, is about 108,000 characters,
so `LIMITS.maxChars` is 200,000; `maxBytes` (262,144) and `maxValues` (10,000) stay well above it.

## Website exports

Export to Website (the home's card for the bars as they are, a set's More menu for that set) writes the
same `!NFA1!` code the website's own export does, so its Import a code loads it: `v` 1, the class's number,
the name (the set's, or "<character> bars"), the slots, the macro list and the keybinds.
- The website reads only its own writer's form of LibSerialize, without the short forms LibSerialize itself
  writes, so the code is written by `Shared/Encode.lua` and only deflated by LibDeflate. The addon's import
  reads it with LibSerialize as before.
- The website turns down a whole code for one spell it does not list, and lists exactly the class spells
  and talents in the Training Planner's data (`ns.TrainingData`, `ns.TrainingBuilds`). The export keeps only
  those spells, so racials, profession and general spells, mounts, companions, flyouts, pet actions and
  gamepad slots are left out and named in the popup, never failing the export. Without the Training
  Planner loaded every spell is left out, and the popup says so. Items and macros stay.
- A spell keeps Highest (`top`) as saved, or, for the bars as they are, by the rule saving uses.
- The website holds at most 120 account and 60 character macros (`MACRO_CAPS`), each name once: the
  macros on the bars go first, then the set's list (or every macro you have).
  A macro past its kind's limit, or a second macro of a name already in, is left out and counted in the popup.
- Keybinds keep only the commands the website takes (the bars' buttons and the pet bar's 10), at most two
  per action, normalized like an import's.
- The popup's code box is read-only and selected, ready for Ctrl+C. Nothing is made until it opens.
