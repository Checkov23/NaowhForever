# Consumable Bar

Your consumables on a bar you can click: potions, elixirs, flasks, scrolls, food, bandages,
weapon stones and oils, healthstones, explosives and engineering devices. Each icon shows how many
you carry, leaves the bar when you run out (or greys out with NONE in red, with Hide When Out
off), and has its cooldown and its key. Edit Items, the bar's own window, adds items (+, by ID or
name, or dragged from the bags), puts them in order, and opens each one's settings beside it. Off by
default (`consumableBar` in `Core/Features.lua`): while it is off nothing is built or listened to.

A module addon of its own, built on the item bar in `Shared/` (`Shared/UI/ItemBar.lua`, with
`Shared/UI/Anchor.lua` and `Shared/Game/ActionKeys.lua`) that QoL's Food & Drink Bar uses too. Its
settings live in the QoL store (`Core/Settings.lua`, `consumableBar*`). While this addon is
loaded and the bar is on, the Food & Drink Bar's card sits on this page.

## Layout

```
NaowhForever_ConsumableBar/
  NaowhForever_ConsumableBar.toc  its metadata, and one file line: ConsumableBar.xml
  ConsumableBar.xml   every file, in load order
  ConsumableBar.lua   the module table (ns.ConsumableBar, CB): entries, their settings, change listeners
  Constants.lua       the numbers several files share (CB.C)
  Data/
    Categories.lua    the kinds of consumable: by the game's subclass, Trade Goods, weapon items and stat scrolls by ID (CB.Data)
  Items.lua           the item rules: what is a consumable, the list, typed items, Scan Bags, Clear
  Keys.lua            the key that uses each entry: its own button's binding, or an action button holding it
  Used.lua            Hide After Use: the item's cooldown, buff or weapon enchant, and when to look again
  View/
    Cell.lua          one icon as the bar, Edit Items and the settings preview draw it
  UI/
    Ask.lua           Ask to Add New Consumables: the popup and what it asks about
    Bar.lua           the bar on screen: secure buttons, layout, place, visibility, events
    Editor.lua        Edit Items, and an item's settings beside it (the page Consumable Bar/Item)
    SettingsPage.lua  its settings page: Edit Items, the bar, adding items, its anchor, the window
  README.md           this file
```

## Why

- The bar is its own switch (`consumableBar`), as Gear & Trinkets and Blessings are, though its
  settings live in QoL's store: QoL's own `enabled` is QoL's. While it is off at load no event frame
  is made; switching it on makes one.
- The icons are secure item buttons: their layout, place, items, mouse input and visibility only
  change out of combat. A change made in a fight sets `pending` and applies when it ends.
- Each item has its own named button, `NaowhForeverConsumableBarItem<id>`, made the first time it is
  on the bar and kept: WoW never frees a frame, and a key bound to it follows the item wherever it
  sits. Taken off the bar, its button is pointed at nothing, so that key does nothing.
- Hide in Combat and Hide After Use work through state drivers set before a fight: a fight shows
  an item hidden after use again, so it is there when it is needed. A driver is registered only
  when its rule changes, since registering one evaluates it and visibility is checked on every
  global cooldown.
- Hide After Use reads auras and weapon enchants out of combat only, and never a secret value: a
  value handed back secret keeps what was shown. Food's use spell is the eating; what it leaves is
  Well Fed, read from Shared's lists (`ns.FOOD_SPELLS`, `ns.WELL_FED`), so it works with Aura Buffs
  off.
- A cooldown counts only when it started with the item's own cast, seen as `UNIT_SPELLCAST_SUCCEEDED`
  (within `CAST_SLOP`, 1 s): potions share one cooldown, and drinking a healing potion must not hide
  a mana potion. A cooldown from before a reload is not seen, so the item shows until its next use.
- Only the six stat scrolls count as scrolls (`SCROLLS`): the game files other items as Scrolls too,
  and only a scroll that gives a buff belongs on the bar.
- A cooldown of `GCD` (1.5 s) or less is the global cooldown, not the item's own.
- A setting is applied as far as it reaches: the bar's look (fonts, offsets, background, an item's
  own text) restyles the icons, what the bar does not show (filters, declined items, tooltips)
  applies nothing, and the rest lays the bar out again. A drag writes the anchor only
  when it changes, since every write reaches the listeners.
- Ask to Add learns what the bags hold on the first bag update, not at login, when they may not
  be filled yet. What waits to be asked about is checked again when it is shown: declined, filtered
  out, no longer in the bags or on the bar already, it is skipped.
  Only what the bags hold now counts as known, so an item that left the bags and is looted again
  is new again.
- Ask to Add asks at the bar, even an empty one or one whose items are all hidden: the bar frame is
  placed either way, so the question shows where the item will go. Only before the bar is built
  does it fall back to the top of the screen.
- After Hide After Use hides an item, the bar looks again when its cooldown or effect should end,
  `WAKE_LEAD` (0.1 s) after. Only the soonest look is scheduled; a later one just looks again.
- Hide When Out (on by default) lays the bar out with only what you carry, in the saved order, so
  the bar closes up when you run out and an item comes back to its place when you get more. A
  Smart Macro counts as out while it names no item you carry. Laying out secure buttons waits for
  the end of a fight: one that runs out in a fight fades at once and leaves when the fight ends,
  and one gained in a fight joins after it. Unlock Mode shows every item.
- Other Consumables are off in the scan filters by default: the game files quest items, holiday
  items and the like there, and Scan Bags would fill the bar with them.
- Remove Empty takes off the items you have none of in your bags; Smart Macros stay, since they
  pick whatever you carry.
- Counts, keys, the grey icon, NONE and cooldowns are plain text and textures, and update in combat.
- NONE follows the icon's size, not the count's font: as large as fits between the edges, and no
  taller than a rectangular icon's shorter side.
- Rectangular Icons (off by default) gives the icons their own height, with Icon Size as their
  width, so they can match a unit frame's or a cooldown manager's icons. The art is cropped to the
  icon's shape (`ItemBar.Shape`), never stretched.
- Flip Row Direction (off by default) starts each new row on the other side of the first: above it
  when the icons grow left or right, to the left when they grow up or down. A bar under a unit frame
  then grows upward toward it.
- Each icon carries its own piece of the background, reaching halfway into the spacing toward each
  neighbour and `BG_PAD` (3 px) past an outer edge, so a hidden icon takes its piece with it.
- Keys are read a frame after a bar changes (`C_Timer.After(0)`): Blizzard redraws its own key text
  on the same events, and a burst of them is read once.
- Edit Items keeps the bar at its real size: it scrolls sideways when the bar is wider than the
  window, and an item out of stock while Hide When Out is on stays in it as a `GHOST` (35 %).
- An item's settings are a settings page of their own (`Consumable Bar/Item`) whose store reads and
  writes that item's entry in `consumableBarItemFlags`, so its rows, dots and Reset work as any
  page's do. Saved tables are copied before every change, so the shared defaults are never written.
- An item given its own text before the Custom Text switch existed keeps showing it.
- The bar starts at `HOME_Y` (-260), under the Food & Drink Bar's spot (-210), so the two never sit
  on top of each other.
- An entry is an item ID, a Smart Macro (`macro:health`, `macro:healthstone`, `macro:healthPotion`,
  `macro:mana`, `macro:food`, `macro:drink`, `macro:bandage`, while the Macros module is loaded: it
  loads first, `OptionalDeps`), or a Food & Drink button (`smart:food`, `smart:drink`). A macro's
  button runs it by name, so Macros' rewrite needs nothing protected here. The bar never flips your
  Macros switches: Macros keeps a macro the bar uses (`ns.ConsumableBarUsesMacro`), and the bar only
  asks it to update (`ns.UpdateManagedMacros`) when the macros it uses change, so a bar that is off
  costs nothing. A rewrite in combat only redraws the icon, since resizing a secure button waits for
  the fight to end.
- A Food & Drink button is a secure item button pointed at your best food or drink
  (`ns.BestFoodAndDrink`), out of combat only: a bag change in a fight points it when the fight
  ends. Its key is the Food & Drink Bar's own (`ns.FoodBarBindings`), which clicks that bar's hidden
  buttons, so one key works on either bar. With QoL not loaded there are no such buttons, so the
  bar's own take their names (`ns.FOOD_BUTTONS`) and the same key clicks them; buttons are built at
  login, when that is known.
- The Food & Drink buttons do NF Food's and NF Drink's job, so the bar takes the buttons or those
  macros, not both; the one held back says which is in the way. While the buttons are on the bar,
  the Food & Drink Bar steps aside.
- NF Health's priority and NF Food's Food Only sit behind cogs on their rows. They are the Macros
  module's own settings (`ns.MacroSettings`), shown in both places, so there is never a second copy.
- A smart button covers a kind of item: the food button food and the drink button drinks, each on
  its own, NF Health healthstones and healing potions, NF Healthstone and NF Health Potion one of
  those each, NF Mana mana potions, NF Food food and drink (food alone with Macros' Food Only on),
  NF Drink drinks, NF Bandage bandages. Scan Bags and Ask to Add skip what is covered; adding one
  by hand asks first.
- Either Food & Drink button on the bar counts as the buttons being there (`CB.HasFoodButtons`), so
  one left alone still keeps the Food & Drink Bar aside and its keys working. The drink button
  counts only for a class with mana: a warrior on a caster's profile does not see it, so it does not
  take their Food & Drink Bar away.
- For a class with no mana (warriors and rogues, `ns.UsesMana`) NF Mana, NF Drink and the drink
  button are not shown, even from another character's profile, but stay saved and kept by Macros
  (`ns.ConsumableBarUsesMacro` reads the saved list): the NF macros are account-wide, so letting one
  go would delete a caster's macro from their action bars. Edits on that character keep them for the
  next; their switches wait, saying why, and Scan Bags and Ask to Add skip drinks and mana potions;
  adding one by hand asks first.
- Anchoring is the shared one (`Shared/UI/Anchor.lua`): unit frames there, and the HUD Editor's own
  Anchor for another Naowh Forever element (Anchor to an Element). Another addon's frame could move
  in combat, and the bar's secure buttons on it would block that.

## Checking

`lua Tools/regression/test-consumable-bar.lua` loads the feature switches, the shared item bar,
anchor and action keys, then these files in the XML's order, against stubs.
