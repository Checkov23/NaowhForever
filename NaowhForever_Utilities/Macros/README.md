# Macros

Naowh's Forge is three tabs of the Macros page in the options window (`/nfmacros`): My Macros, Smart
Macros and the Library, beside the Settings tab. My Macros lists your account and character macros
beside an editor with two views. Simple, the default, is a short form: the spell, what to aim at
(Mouseover, Target, Focus or Myself), friends or enemies, what to do if there is no one there, a key
to cast on yourself, and three switches; under it, one or two sentences say what a press does, above
the text it writes. Advanced is the colored text editor with a line gutter, and a side panel with
Build (each line as a sentence edited with menus, problems with a Fix it, lines and recipes to add),
Reads as and Simulate. Export and Import on the tabs' top bar share your macros as a string. The Smart Macros (NF Health, NF Healthstone, NF Health Potion, NF Mana, NF Food, NF Drink, NF
Bandage, NF Trinket 1 and 2, NF Focus, NF Accept) are written by the module and kept on the best
item or spell you carry, out of combat.
The Library keeps, by class, the macros you saved to it and those your profile pack brings. Save a Macro on its
tab lists your game macros and keeps the one you pick under your class, so it can be added to any character of that class,
and New Macro opens a small dialog to write one: a name and its text, with a byte counter against the game's 255.

## Layout

```
NaowhForever_Utilities/Macros/
  Macros.xml                every file, in load order, included by Utilities.xml
  Macros.lua                its settings, the pack's class macros, the macro icons and the module table (ns.Macros)
  Constants.lua             the limits, icons and command sets several files share (M.C)
  Data/
    Items.lua               the mana potions and bandages the Smart Macros use, best first (M.Items)
  Text.lua                  a macro's text read and written: problems and fixes, each line in words, one press
                            simulated, clauses built back into a line, the editor's colors, Shorten (M.Text)
  Commands.lua              the commands the game knows, whose they are, and which run a script (M.Commands)
  Store.lua                 the game's macros, the pack's and the Library's, and the icon each shows (M.Store)
  Smart.lua                 the Smart Macros: their text, writing them out of combat, their events (M.Smart)
  Sharing.lua               macros as a string to share, and a shared string read back (M.Sharing)
  View/
    Style.lua               the Forge's colors, fonts and sizes, on top of Shared/Style.lua (M.Style)
    Parts.lua               the Forge's small parts: text, pools, icons, section titles, list rows (M.Parts)
  UI/
    SmartPage.lua           the Smart Macros tab (M.Forge, the window's shared state)
    Library.lua             the Library tab, and its Save a Macro picker (F.SavePicker)
    NewMacro.lua            the New Macro dialog on the Library tab (F.NewMacro)
    Editor.lua              My Macros' editor: the draft, its name, icon, byte meter, code box, Save, Undo, Delete
    List.lua                My Macros' list: your macros, searchable, with a dot for one with problems
    SpellSuggest.lua        the spells you know, offered under a spell box as you type
    Builder.lua             Advanced's Build view and Simulate's questions
    Inspector.lua           Advanced's side panel (Build, Reads as, Simulate) and the icon picker
    Simple.lua              the Simple view: the form, what a press does, the text it writes
    Window.lua              the tabs' frame on the Macros page, its top bar (ns.BuildForgePage, ns.OpenMacroWindow)
    SettingsPage.lua        its settings page (Macros/Settings), declared as cards
  README.md                 this file
```

Each layer uses only the ones above it. `M.Forge` holds the tabs' shared state (the frame they share,
`F.window`, and the open tab) and the functions its UI files call on each other.

## Why

- NF Healthstone and NF Health Potion are NF Health split by item kind; NF Health itself is
  unchanged. NF Drink is the drink half of NF Food, and the Food Only setting (off) drops the
  drink from NF Food, so macros players already have do not change.
- A bag macro (health, healthstone, health potion, mana, food, drink, bandage) is made with a bare
  `#showtooltip` when nothing in the bags matches, so it can be placed on a bar before the item
  arrives. It is filled when the item shows up, and a macro that already holds an item is left
  alone when the last one is used.
- Extra Lines is one single-line text row per bag macro (`<key>Extra`), because the settings
  engine has no multi-line box. A typed `\n` starts a new line; `;` cannot, as it already
  separates clauses inside a macro line. The lines go after the generated ones; if the macro
  would pass `LIMIT`, or they run a script (`Commands.RunsScript`), they are left out and the player
  gets a message once per text. A change to them, or to Food Only, rewrites the macro at once, even
  when it holds a placeholder or an item it would otherwise keep. The Smart Macros page lists what
  the generated lines use (`Smart.Body`), so an item named in the extras is not shown as the macro's.
- After `CreateMacro`, `Write` looks the name up again. On the China Forever beta that lookup missed
  new macros, so every `UPDATE_MACROS` made another copy until General was full; a macro the lookup
  cannot find is now made once, the player is told, and it is left alone until a reload.
- NF Health picks from the core's healing lists (`ns.HEALTHSTONES`, `ns.HEALING_POTIONS`, in
  `Shared/Game/Consumables.lua`), never Aura Buffs', so it works with Aura Buffs off. NF Mana's list
  (`ns.MANA_POTIONS`) is there too, so the Consumable Bar can tell mana potions apart without Macros.
- The Consumable Bar can carry every bag macro: NF Health, NF Healthstone, NF Health Potion, NF Mana,
  NF Food, NF Drink and NF Bandage (`ns.ConsumableMacros`).
  Its buttons run them by name, so this module's rewrite is all that keeps them current: a macro the
  bar uses (`ns.ConsumableBarUsesMacro`) is written and kept current whatever its own switch while
  this module is on, cannot be removed from here, and shows locked on in Kept Current. One written only for
  the bar goes when the bar stops using it; one switched on here stays. Which ones only the bar
  wanted is saved (`barOnly`), so that still holds after a `/reload`.
- `LIMIT` is 255: the game keeps only the first 255 bytes of a macro's text, counted in bytes.
- `NAME_MAX` is 16, the bytes a macro's name holds.
- `QUESTION` (134400) is the question mark icon. A macro made with it shows what `#showtooltip`
  names, so the Smart Macros and the macros the Library and Import add follow their spell or item
  unless the pack names an icon.
- `ACCEPT_ICON` (136814) is the ready check mark, NF Accept's icon; `FOCUS_ICON` (132212) stands
  for NF Focus on its Smart Macros card.
- The class macros (`classMacros`) live in the profile's `utilityReminders`, not in the module's
  own settings, so they travel with shared profile packs.
- Icons once picked for a pack macro are still kept by macro name in the account settings, outside
  the profile, so a pack export never carries them; the Library and the pack hand-off use them over
  the pack's own.
- My Macros edits the game's macros directly; there is no copy of them. The text is the only model:
  Build, Reads as, Simulate and Test it all read it through `M.Text`, and every Build control edits one
  line by parsing it, changing its clauses and writing it back with `Text.Build`, so a line keeps what
  it does and Undo covers every change. A line Build cannot show (a script, a chat line, a bracket with
  an unknown condition, more than one bracket per clause after `Text.Expand`) stays exactly as typed
  and says to edit it in Advanced. #355 had taken the editor out in favour of `/macro`; this one
  brings it back for players who do not know the syntax.
- Naowh's Forge used to be its own window with sentence cards as Simple. Testers found it looked unlike
  the other pages and Simple still too hard, so it moved into the Macros page and Simple became a form.
- The three tabs share one frame (`F.window`), built on the first tab's page and moved to the page of
  the tab shown: each page's `OnShow` takes it back, since the options window builds a page only once.
  The options window scrolls each page, but the tabs scroll their own lists, so the frame reaches down
  to the bottom of that scroll frame and the page itself stays one line tall.
- Simple writes the text from the form (`Write`) and reads a macro back by writing every form it could
  be and keeping the one that writes exactly its text. Anything else (another spell line, a
  `#showtooltip` naming a spell, a clause it would not write) says to edit it in Advanced, so Simple
  never rewrites a macro it did not make. Aiming at your target with nothing else writes a plain
  `/cast`, so friends or enemies is asked only when a check is written.
- The spell boxes (the recipe's, a `/cast` line's, Button shows) offer the spells in your spellbook:
  active spells only, one per name whatever its ranks, read again after `SPELLS_CHANGED`. `/use`
  boxes take items, so they offer nothing.
- The code box shows the text with color codes; `Text.Strip` gives the plain text back and
  `Text.PlainPos`/`CodedPos` keep the cursor in place when the colors are rewritten as you type.
- Save, Delete and a picked icon refuse in combat, like every other macro write. An icon picked for a
  saved macro is written at once, without saving the unsaved text.
- Library cards, Import and the profile hand-off add character macros, and say so in `/macro`.
  New Macro on the Library tab writes a macro into the Library, not the game: a name and its text
  (a name holds 16 bytes and the text 255, both capped by the boxes), saved under your class like
  Save a Macro does, and added to this character too with Save and Add.
- The known commands come from the client's `SLASH_` and `EMOTE_CMD` strings. Commands of addons
  that are not loaded are missing from that list, so an unknown command is a warning, not an error.
- The Smart Macros' item lists are classic-era item IDs, best first.

- Smart item macros skip items above the player level and items whose minimum level is unknown. Player `UNIT_LEVEL` and successful carried-item `GET_ITEM_INFO_RECEIVED` events refresh them, with writes deferred until combat ends. A stale unusable macro becomes a placeholder when no eligible item remains; eligible spent items keep their existing tooltip behavior.

- Chat commands take no conditionals, so NF Focus's announce channel is chosen when the macro is
  written, and the macro is written again on roster changes.
- Only switching a Smart Macro or the module off deletes its macro. A profile or spec switch that
  turns one off leaves it, since deleting a macro also empties its action bar slots.
- Nothing is written before the first `PLAYER_ENTERING_WORLD`, when the character's macros are
  loaded: `GetMacroIndexByName` misses them earlier and every macro would be made twice.
- `UPDATE_MACROS` fires when a macro is deleted, so a Smart Macro that did not fit is made once
  there is room.
- Macros cannot change in combat: a Smart Macro's write waits for `PLAYER_REGEN_ENABLED`, and
  every create, edit, delete and pickup refuses in combat.
- Profile macros and shared strings come from other players, so one that runs a script (`/run`,
  `/script`, `/dump`) is made only after the player says yes.
- A shared macro string is read as data, never run: names and texts within the game's limits, no
  more macros than the game holds, and the decoder's size, depth and value caps.

## Checking

- `luacheck NaowhForever_Utilities/Macros` from the repo root.
- `lua Tools/regression/test-macros.lua`: the Smart Macros against stubbed macro, bag and item
  APIs, with the Food & Drink Bar.
- `lua Tools/regression/test-macro-text.lua`: Check, Fix, Explain, Simulate, Build, Shorten and the colors.
- `lua Tools/regression/test-macro-window.lua`: the tabs built from the real files into stand-in pages,
  every tab drawn and its controls used, Simple's form included.
