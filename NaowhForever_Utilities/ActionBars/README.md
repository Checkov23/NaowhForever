# Action Bars

Every action bar slot, macro and keybind saved under a name and imported later, out of combat.
Sets belong to a class and are shared by every character of that class on the account. The
Action Bars page's Bar Sets tab (`/nfbars`, `/nf bars`) shows your class's saved sets, the set
builder (pick the bars, slots, keybinds and macros that go in) and the import
preview (your bars as an import would leave them), laid out like the Forever website's Action Bars.
Export to Website gives your bars, or a saved set, as a code the website's Import a code loads.
`/nf bars save|import|test|delete <name>`
and `/nf bars list` do the same from chat. `/nf ab <name>` imports a set and `/nf ab` lists them.
Import on New Character imports a chosen set once, the first time a new character of that class
logs in (level 1, no experience yet). Load on Its Own loads a set on entering a dungeon or raid, on
joining a battleground (putting the bars from before back on leaving) and on the level-up that reaches a
chosen level.
Every import first backs up the bars, keybinds and the macros on the bars; the home offers Undo after
an import, lists the last ten backups, and checks the bars for spells below their best rank and class
spells on no bar. `/nf bars undo` undoes the last import. Right-clicking the Action Bars launcher (minimap
or Top Bar) opens a menu of the sets, Undo and Save Bars into the last set.

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
  Backups.lua                   this character's bars before each import, the last ten, and putting one back (A.Backups)
  Sets.lua                      save, import, undo, rename, delete, /nf bars, and the public API (ns.ActionBarSets)
  AutoLoad.lua                  sets loaded on their own: dungeons and raids, battlegrounds, a level (A.AutoLoad)
  Check.lua                     spells below their best rank, and class spells on no bar (A.Check)
  View/
    Style.lua                   the Bar Sets tab's colors and sizes, on top of Shared/Style.lua (A.Style)
    Parts.lua                   labels, chips, tick boxes, slot tiles, glass panels, the bar strip at any size (the
                                scene's, and a set row's small one), the scene with its pet row, form or stance
                                bar and bar picker, the tab's panes (A.Parts)
  UI/
    SetsPage.lua                the home: Paste Code, Get Code and Save Current Bars over it with the class pill, Undo,
                                the bar check, a filter and a card per saved set (icon, tags, a small strip of its bars,
                                Import and More), a card to save a new one, and the backups (ns.BuildActionBarsPage,
                                A.BuildSetsHeader,
                                ns.ActionBarsMenu for the launcher's quick menu)
    Builder.lua                 the set builder: a name, icon and tags, your bars on the scene, what goes in, the macros or
                                keybinds, and a summary to save (A.Builder)
    Preview.lua                 the import preview: what changes counted, the same scene now or after the import with each
                                change marked, then what comes across, what fills in later and the keys that change (A.Preview)
    Keys.lua                    the keybind map: a set's keys on a keyboard and mouse (A.Keys)
    Window.lua                  the Bar Sets tab, its views and its back link (ns.BuildActionBarsTab,
                                ns.OpenActionBarsWindow)
    SettingsPage.lua            its settings page (Action Bars/Settings), declared as cards
  README.md                     this file
```

Each layer uses only the ones above it. The tab hands the builder and the preview its own
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
- The tab's redraws are gathered into one on the next frame (`C_Timer.After(0, ...)`).
- The builder's switches read the draft when they are made, so a draft exists before the tab
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
- The builder and the preview draw the website's strip: Action Bar 3 (6 by 2) on the left, Action Bar 2
  over Action Bar 1 in the middle, Action Bar 4 (6 by 2) on the right, 24 buttons of 38 (`TILE`) across,
  the site's size; 918 wide, it fits the narrowest the options window gets. The views take the tab's
  width and height, so the builder's two heads and the preview's three panels share whatever width the
  tab has. The scene is as tall as what it holds: 190, or 249 with the pet bar's row (`P.SCENE_H`,
  `P.PET_SCENE_H`), and the panels under it hang from its bottom.
- The bar picker sits under Action Bar 3, as the site's switcher does, so it never pushes the strip down.
- One strip drawing (`P.PlaceStrip`) lays out the scene's buttons and a saved set's small strip on the home,
  12 (`MINI_TILE`) with 1 between, so three cards fit across the narrowest tab; the small one is textures only, drawn from the saved slots, never the bars.
  Its tags name what it cannot show: the form pages ("+ Stealth", "+ 3 forms"), other bars and the pet bar's keys.
- The builder has no step strip: its three steps were one screen, so the tabs did nothing.
- The builder's What Goes In panel holds the switches for keybinds, macros, Highest Rank (the import setting
  itself) and, for Hunters and Warlocks, the pet bar's keys; Keybinds counts the keys on your bars and those
  for other commands. Its list shows the macros (Select None keeps the ones on the bars) or, on its
  Keybinds tab, each key with what it presses now.
- A class with form pages (`A.FORMS`: a Rogue's Stealth, a Druid's forms and Prowl, a Warrior's stances)
  gets the website's bar over the strip, FORMS for a Druid and STANCE BAR otherwise (`A.FORM_BAR`): MAIN as a
  word, each form as its spell's icon with the key its stance bar button is bound to, and Prowl, which has no
  button of its own, as a word. A chip picks which page Action Bar 1's row shows (its label then reads, say,
  ACTION BAR 1 - STEALTH), dims when that page is left out, and its tooltip counts the page's actions. The
  forms are matched to the stance bar by spell ID (`spells`, every rank), so it works in any language, and a
  form not learned yet still shows its icon, with no key. The preview shows the key the set binds there, as
  the rest of its strip does. The bar's height stays reserved while a single bar is picked from the list, so
  the panels under the scene never move. Its title sits beside its box, so it costs one row of height. The
  builder's What Goes In and the preview's three panels scroll their rows when the tab is too short for them,
  so a Druid, Rogue or Warrior on a small window loses no row to the taller scene. A Druid's are in stance bar order (Bear, Cat, Prowl,
  Moonkin). A Warrior is always in a stance, so MAIN shows only when page 1 holds something (`A.NO_MAIN`) and
  Battle Stance opens first, as on the site. The other bars (Action Bar 5 to 8, Page 2, the stance and extra
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
- The main buttons (Save Set, Import, the home's Save Current Bars, a row's Import) are the site's solid blue
  with white text (`ns.PrimaryButton`); the others keep the house outline. The home's buttons say what they do
  (Paste Code, Get Code), and their tooltips carry the old cards' titles and lines.
- A wrapping line is held by its top corners (`TOPLEFT`, `TOPRIGHT`), never a `RIGHT` point: a side point
  also fixes its middle, which cut the home cards' lines short.
- The views are one frame built into the Bar Sets tab, as the Macros page hosts Naowh's Forge: `/nfbars`,
  a saved set's Import and a website code's preview open the options window on the tab. The builder and the
  preview link back to the saved sets from the tab's top right.
- Stop Auto Push Spells to Bars (the New Spells card) is the game's `AutoPushSpellToActionBar` setting itself,
  read and written as it is, with no saved key: the game keeps it, so it stays as the player left it on the
  old QoL > System page, and it works whether Action Bars is on or not.
- A backup keeps the bars, every keybind and only the macros on the bars: an import never deletes a macro,
  so only one a backed-up slot needs can be missing. Putting one back is exact: each spell goes back at the
  rank it had, whatever Highest Rank or a slot's Highest says, keys the backup did not have are unbound,
  the fill-in list is dropped and the character's last set is what it was. Putting a
  backup back is itself backed up first, so it can be undone too. Backups are per character (by GUID).
  Save as Set asks before it replaces a set of the same name, as the builder does.
- The preview compares each slot with the bars as they are: added (green edge) where the button is empty
  now, swapped (accent edge) where something else is there, cleared (red edge and cross) where the set
  keeps it empty or its spell is not learned yet, and dimmed where nothing changes. A spell on the bars at
  another rank counts as the same. Your Bars Now shows the bars as they are with what the import clears or
  swaps edged. Its Bring Across boxes (actions, macros, keybinds) apply to this import only, starting from
  the Settings tab's Import Macros and Import Keybinds; Fill In As You Learn there is the setting itself.
- The bar check reads the keyboard slots only. A lower rank kept for downranking is left alone once the
  player picks Leave as Is (`barSetRankKeep`, by spell ID); Hide These does the same for spells on no bar
  (`barSetSpellsHidden`, by name, so a new rank of a hidden spell stays hidden). A spell named in a macro
  on the bars counts as on the bars. Class spells come from the Training Planner's data, so without it
  loaded the check lists ranks only.
- Load on Its Own keeps its rules per class (`autoLoad`) and makes and registers its events only while a rule names
  a set that exists. The instance it is in, the set it loaded and that set's backup are kept per character
  (`barSetAutoLoad`), so a reload inside changes nothing and logging in outside puts the bars back. In
  combat it waits for `PLAYER_REGEN_ENABLED`. Switching it off, or clearing its rules, forgets the instance, so
  turning it back on later never puts back an old backup.
- The rules are shared by every character of the class, so the level rule fires only on the `PLAYER_LEVEL_UP`
  whose level is the one picked (`FIRST_LOAD_LEVEL`, 2, until the slider is moved), never on entering the
  world: an alt already past it keeps its bars. The level comes from the event, since `UnitLevel` can still
  give the old one then.
- Releasing after a wipe loads the graveyard outside: while `UnitIsDeadOrGhost` it stays inside, so a wipe
  never swaps the bars out and back in, and never spends two of the ten backups. Taking a spirit healer's
  resurrection outside keeps the instance's set until the next loading screen.
- Each backup has its own number (`id`, from `taken`), and the backup to put back on leaving is found by it:
  two taken in the same second share `saved`.
- A set's icon and tags (at most three) are kept when it is saved again, by hand, from chat or on logout.
  A set with no icon shows its first spell on the strip's bars.
- The keybind map reads a set's own keys, or the bars and keys as they are when the set keeps none. Each
  key's colour is the bar its command presses; a ring marks a key that presses something else now.

## Checking

- `luacheck NaowhForever_Utilities/ActionBars` from the repo root.
- `lua Tools/regression/test-action-bars.lua`: saving, importing, testing, Fill In and the
  commands against a small fake of the bars, spellbook, macros and cursor.
- `lua Tools/regression/test-action-bars-new-spells.lua`: the New Spells card's toggle against a fake of the
  game's setting.
- `lua Tools/regression/test-action-bars-window.lua`: the Bar Sets tab's views built from the real files
  into a stand-in for the options page: Undo, the backups, the bar check, tags and the icon, the
  preview's changes and its per-import switches, the keybind map, the quick menu, the home's cards and
  set rows, the paste and export popups, the strip for each class (a Rogue's Stealth chips, a Druid's
  forms, a Hunter's pet row, a Mage with neither), a bar left out by its label, a slot skipped, the bar
  picker, the summary, saving, and the preview's strip and Import.
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
until the player opens the Bar Sets tab.
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
