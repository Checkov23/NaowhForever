# Action Bars

Every action bar slot, macro and keybind saved under a name and imported later, out of combat.
Sets belong to a class and are shared by every character of that class on the account. The
window (`/nfbars`, `/nf bars`, Open Action Bars on its settings page) shows your class's saved
sets, the set builder (pick the bars, slots, keybinds and macros that go in) and the import
preview (your bars as an import would leave them). `/nf bars save|import|test|delete <name>`
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
    Bars.lua                    the bars as the game numbers them, with the binding each answers to (A.BARS)
  Capture.lua                   the bars, macros and keybinds as they are now, read into a set (A.Capture)
  Import.lua                    one pass over the bars putting a set back, or testing it (A.Import)
  Pending.lua                   spells an import could not place, put in their slots when learned (A.Pending)
  Sets.lua                      save, import, rename, delete, /nf bars, and the public API (ns.ActionBarSets)
  View/
    Style.lua                   the window's colors and sizes, on top of Shared/Style.lua (A.Style)
    Parts.lua                   labels, chips, tick boxes, slot tiles, a bar's row, the window's panes (A.Parts)
  UI/
    SetsPage.lua                the saved sets, a row each with Import and More (ns.BuildActionBarsPage)
    Builder.lua                 the set builder (A.Builder)
    Preview.lua                 the import preview (A.Preview)
    Window.lua                  the window and its three views (ns.OpenActionBarsWindow)
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

## Checking

- `luacheck NaowhForever_Utilities/ActionBars` from the repo root.
- `lua Tools/regression/test-action-bars.lua`: saving, importing, testing, Fill In and the
  commands against a small fake of the bars, spellbook, macros and cursor.
- `lua Tools/regression/test-action-bars-window.lua`: the window's three views built from the
  real files, the builder's clicks becoming the saved set's choices, and the preview's Import.

## Website imports

Import Website Code, and the Profiles page's Import, accept versioned !NFA1! layouts from the Forever website.
Sharing.lua validates the class, slots, action types, byte limits and decode limits before
saving anything. Confirmation creates a uniquely named set and opens the existing preview;
it never places actions. Applying remains the normal out-of-combat player action.
Unfilled website slots and keys not assigned by the website build are preserved.
Keybinds are restricted to known action-button commands and ordinary keyboard/mouse keys. Macro bodies are data only;
the preview lets players inspect them before import. No hooks, events or frames are added
until the player opens the existing window.
The layout's macro list (`macros`, at most `MAX_MACROS`) is made with the macros on its bars, whether
placed or not, each once by name and text. A macro is a character macro unless the layout marks it
account-wide, and keeps the icon it was given, except a `#showtooltip` macro (above).
