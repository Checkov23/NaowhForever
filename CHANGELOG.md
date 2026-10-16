# Changelog

## Unreleased

## 1.1.23

### Added
- AuraBuffs: an optional Class Buff Tracker with clickable self-buffs, short labels, full spell
  tooltips and missing-buff glow outside combat.
- AuraBuffs: adjust Gold Glow thickness under Class Buff Tracker.
- Training Planner: a Spellbook Tab setting (Settings > Window) puts a Trainable tab under your
  spellbook, listing the spells you can train now and in the next two levels, with their cost and a
  waypoint to your trainer.

### Changed
- Training Planner: a build's Spells tab lists every rank of a spell, so a build can skip only some
  ranks (say Rank 3) and still train the others.
- Boat and Zeppelin Timers (QoL > Travel) now shows on the minimap: hover a dock's boat or zeppelin
  pin for its countdown, left-click when it arrives and right-click when it leaves. The timer window
  is gone.

### Fixed
- Skyborne Spots: the new ley lines and Elemental Convergences Forever added across Eastern Kingdoms
  and Kalimdor are on the world map (76 ley lines, 56 convergences).
- Training Planner: talent tooltips in the build editor show the text of the rank you have and the
  next rank, instead of always the full rank.
- Boat and Zeppelin Timers: each zeppelin at a shared Horde tower keeps its own timer, and the
  Orgrimmar-Undercity and Undercity-Grom'gol zeppelins use their published cycle times.
- Glimmer: with Find Herbs or Find Minerals on, minimap icons leave the game's tracking dot visible
  inside the ring, so you can see which nodes are up. Only My Professions now shows nothing on a
  character with neither Herbalism nor Mining.
- Zephras Isle: zeppelin docks, town pins, quest givers, rares and herb and ore spots show on the
  island whichever of its two map IDs the game puts you on.

## 1.1.22

### Changed
- Instance Tracker, Journeys, Macros, Group Inspect and Action Bars are now one line in the AddOns
  list, Naowh Forever: Utilities, and the Consumable Bar is part of Naowh Forever: Combat. Turn each
  one on or off under Settings > Modules, and it takes effect without a reload. Restart the game
  once after updating so the new Naowh Forever: Utilities entry is found.

## 1.1.21

### Added
- RestedXP: the Naowh window's list of steps scrolls with the mouse wheel through the whole guide,
  the steps done above and the ones to come below, and a click goes back to any of them.
- RestedXP: a Show Scroll Bar setting, off to start, for the thin bar beside the Naowh window's list
  of steps; the wheel scrolls the list without it.
- RestedXP: the Naowh window's step box and progress bars have a border with a size and a color of
  their own, themed and black in the Naowh theme, and the bars a Bar Color and a background color,
  in Window Look, in any Window Theme.
- Settings > Minimap Icons: a minimap button for the Professions Shopping List, which the Top Bar
  can show once it's on.
- Consumable Bar: Flip Row Direction, in Settings > Bar > Layout, starts new rows above the first
  (or to its left), so a bar under your unit frame can grow upward.
- Consumable Bar: Rectangular Icons, in Settings > Bar > Layout, gives the icons their own Icon
  Height, with the art cropped to fit instead of stretched.
- Import (Profiles): Keep My Positions, ticked to start, keeps your frames where you put them when
  you import someone's profile.
- Profiles > Setups: Keep My Positions leaves your frames where they are when you apply one of
  Naowh's setups.
- AuraBuffs: Personal Buff Reminders remind a hunter with no aspect of their own up (Buffs &
  Consumables card, Aspect).
- Discovery: Rares: Skull on Click, off by default: clicking the Rare Alert card also puts a skull
  on the rare.
- Boat and Zeppelin Timers in QoL > Travel estimate the next arrival or departure at a dock from one
  recorded sighting, kept for your realm until the weekly reset.
- Professions: optional Skill-up Thresholds bar beneath the selected recipe, showing its difficulty
  boundaries and your current skill.
- German: Gamble, the RestedXP Naowh window, the Simple macro form, crafting ROI and the other new
  parts up to 1.1.20 now show in German on German clients.
- Professions: optional recipe markers for your active auctions and a Not Selling filter.
- Professions: an optional standalone Crafting Queue for prerequisites, missing materials and
  click-confirmed batches.
- QoL > Combat > Default Damage Meter: a Theme row to paint the meter in the game's own look, your
  current theme or any theme, with every color, font and texture still yours to change.
- Default Damage Meter: every row of the card now also works with Reskin off, on the game's own
  look.
- Default Damage Meter: switches to show or hide each part of the title bar, Title and Timer X
  Offsets, and an optional right-click menu on the title bar.
- Default Damage Meter: a preview at the top of the card that shows every pick as it is made.
- A Naowh Reverse Gradient bar texture.
- Professions: Vendor Items on Shopping List (off by default) puts vendor materials in a Buy from
  Vendor section of the Shopping List, with Buy and Buy All beside matching merchants.

### Changed
- RestedXP: Upcoming Steps is now Listed Steps, the number of steps the Naowh window's list shows at
  once.
- RestedXP: the Naowh window's step box and bars have a black border in the Naowh theme, in place of
  the window's border color.
- RestedXP: the Naowh window's Window Theme starts with Current Theme, in place of Same as the
  Addon.
- Restock Reminder (QoL > Loot & Items): the ammo settings are grouped under Ammo: Rogue and Warrior
  and Ammo: Hunter.
- Scrap Marker and the Scrap List are now the Junk Marker and the Junk List (QoL > Loot & Items),
  and /nf junk opens the list (/nf scrap still works).
- Waypoint Pin: the card above the pin has no blue line on top, and its text is centred.
- Dungeon Journal: drop chances updated from Wowhead's latest kill counts.

### Fixed
- RestedXP window: RestedXP's Active Targets and Active Items titles no longer throw a font error.
- Town Pins: mailboxes and spirit healers on the minimap are as big as the game's own minimap icons,
  and Town Pin Size (QoL > Map & Pins, or the map's Town Pins button) now sizes them too.
- The Quest List and its map pins no longer show some Forever quests to the wrong faction (Hearts of
  the Lost, Strahnbrad Mystery and others).
- Waypoint Pin: when the spot is off screen or far to one side, the pin points the way from near the
  middle of the screen instead of sitting on the minimap, quest tracker or bars.
- Training: the trainer waypoint for a new Skyborne shaman goes to Windshaper Boro on Zephras Isle
  instead of Thunder Bluff.
- AuraBuffs: Low Health no longer shows when you carry no healthstone or healing potion; turn on
  Show When Out on its card to keep the old warning.
- Gamble: on a German client the Last call announcement no longer puts the German word for party
  into the English chat line.
- Professions: the Shopping List's subtitle and empty-list message are no longer cut off when the
  window is narrow or in a longer language; the Consumables button shows only its icon when the
  title bar has no room for its label.
- Default Damage Meter: Themed buttons no longer change the color of the title.

## 1.1.20

### Added
- Buffs & Consumables: a stat scroll in your bags now reminds you when its buff is missing, one stat
  at a time, and counts Arcane Intellect, Fortitude and Divine Spirit as the matching scroll buff.

### Changed
- Performance: the HDR options are opt-in. Turn on HDR Settings on QoL > System > Performance to
  change HDR or Peak Brightness from there.
- Naowh Forever no longer ships LibGetFrame, which it did not use.

### Fixed
- Flight Point Reminder: no longer asks you to learn retired flight points like "zzOLDPowderfuse
  Port".
- Journeys: replanning while you walk makes far less memory garbage, so Naowh Forever's memory no
  longer climbs so fast during a journey.

## 1.1.19

### Changed
- Consumable Bar, Food Bar, Gear Sets, Trinkets, Group Buttons and the Finder role buttons hover and
  press with the same flat look as the Blessings bar, without Blizzard's square border.

### Fixed
- Scrap Marker: the Razormane Backstabber, Charred Razormane Wand and Razormane War Shield, needed
  for Weapons of Choice, are never marked as scrap or sold.

## 1.1.18

### Added
- RestedXP: a RestedXP Naowh Window (V2) in Settings, with the guide's progress, the active step and
  the steps after it in one window in your theme, resizable from its corner, with a Window Theme of
  its own, the Forever look, and a bar under a row that counts. Added: RestedXP: Step Icons in the
  RestedXP Naowh Window (V2) settings, Naowh's own step icons in a line or a filled style, in place
  of RestedXP's, in its windows, tooltips and quest log, in the window's Accent Color. Added:
  RestedXP: Set Up New Characters in the RestedXP Naowh Window (V2) settings, off to start, that
  turns on RestedXP's new interface and the Naowh theme for a character the first time you play it
  and puts the waypoint arrow in the middle of the screen, and a button to do it for the one you are
  playing. Added: RestedXP: the Active Targets and Active Items windows take the look of the window,
  and the chat bubble and sword on a target button are our icons. Added: RestedXP: an Arrow Shows
  Objective switch, so the text under the arrow says the distance and the objective (Talk to Duokna)
  in place of the step number, wrapped under the arrow, and an Arrow Text Size. Changed: RestedXP:
  the theme (V1) and the Naowh window (V2) are separate folds with a switch on their title and
  cannot both be on, and the waypoint arrow's options are in both (and on their own while neither
  is).
- Gamble: This feature adds in two gambling modes (Classic and Deathroll) to play with friends in
  party or raid chat.
- Performance: HDR and Peak Brightness settings, under QoL > System, for HDR monitors.
- Waypoint Pin: an Arrival Distance slider for how close counts as arriving (QoL > Interface).
- AuraBuffs: Worn Gear Reminder (Buffs & Consumables, off by default) shows an icon while you wear
  Cloak of Hermitic Bliss in Wailing Caverns, with the cloak's effects in its tooltip.
- AuraBuffs window: drag an item from your bags onto a section to add it.
- Glimmer: Quest Givers is its own category under Objects, so you can keep quest objects lit without
  the nameplate bar on quest givers.
- Buffs & Reminders: click a reminder icon to use the food, flask, elixir, scroll, stone or oil it
  shows, without opening its item menu.
- Scrap Marker: choose Alt or Ctrl as the marking modifier in QoL > Loot & Items.
- Professions: Show Normal Cast Bar in Total Craft Timer settings keeps individual craft progress
  visible alongside the batch timer.
- Professions: optional recipe-row markers for Shopping List quantities and bag or bank stock.
- Professions: optional Scan, Pause and Resume controls with paging for Favorite Patterns at the
  auction house.
- Professions: optional crafting ROI display with configurable colour thresholds.
- Settings search: a word with a letter missing still finds the setting, after the exact matches,
  with the matching letters lit.
- Settings search: modules that are turned off are searched too. Their matches show under Turned Off
  at the bottom of the sidebar, with a switch to turn the module on.

### Changed
- Glimmer: the Sparkles effect has twice as many stars.
- Campfire: click anywhere on Camp Nearby, the bar or the alert, to sit.
- Campfire: Alert Size shows a number instead of a percent.
- Dungeon Journal: a waypoint to a dungeon's entrance clears once you are inside the dungeon.
- The Window Opacity option is gone from every module's window and title bar; the windows are always
  fully solid.
- Buffs & Reminders: the item menu you get by hovering a reminder icon now uses the row's Icon Size
  and opens centred under the icon you hovered, above it when there is no room below.
- Options: every section starts folded when you open a tab, except on Damage Meter, Glimmer and Top
  Bar, which still open their first section.
- Buffs & Reminders: pressing a reminder icon or an item in its menu makes it glow, so you can see
  the press went through.
- Buffs & Reminders: the reminder row no longer updates during combat: a consumable that runs low or
  expires mid-fight appears once combat ends, and one used in combat stays on the row until then.
- AuraBuffs: the Weapon Enhancement Reminder shows each stone, weightstone and oil with its classic
  icon, and a Rough Sharpening Stone when you carry none.
- The Top Bar is now part of Quality of Life and no longer has its own line in the AddOns list. Turn
  it on or off on its card under QoL > Interface.
- Options: Cursor & Crosshair and Damage Meter are now the last Quality of Life tabs, after System.
- Options: Consumable Bar moves to the top of Combat, and Group Inspect moves to Utilities.
- Gear & Trinkets, Blessings, AuraBuffs, Threat Meter, PvP and Swing Timer are now one line in the
  AddOns list, Naowh Forever: Combat. Turn each one on or off under Settings > Modules, and it takes
  effect without a reload.
- Forever skin: Settings, Profiles, Patch Notes and Credits are back at the bottom of the sidebar.
- Forever skin: the options sidebar lists modules as gold text under group bars, with the picked one
  between gold lines, as the game's Options window does.
- Forever skin: section headings are plain bold text over a brown line, and every options page has
  the same row lines.
- Forever skin: folding sections on the Settings page look like the other collapsible bars.
- Forever skin: the window's lines, the logo ring, the help tip and tab rows all use the border's
  bronze metal.
- Forever skin: dropdowns and sliders get a soft sheen under the mouse instead of a yellow edge, and
  the scroll bar no longer lights bright yellow.
- The Naowh Forever: Language addon is gone; the language you pick in Settings is saved with the
  rest of Naowh Forever's settings. If you had picked a language other than your game's, pick it
  again once.

### Fixed
- Glimmer: herbs, ore and other objects light up on every setup; on some, the game never showed the
  nameplate Glimmer's effect needs.
- Waypoint Pin: hides when you are at a tracked quest's area and comes back when you walk away.
- Waypoint Pin: the walking time is right on a mount, instead of about double.
- Flight Point Reminder now alerts once when entering a zone with an unlearned flight point and adds
  a learn hint to existing flight-master pin tooltips.
- Flight Point Reminder remembers opened flight maps across reloads, including existing saved flight
  points.
- Flight Point Reminder no longer repeats "the" in reminders for The Sepulcher and other towns whose
  names start with "The ".
- Buff Thanks thanks the player who buffed you with its emote and skips unknown casters.
- Settings search reveals the module switch when a disabled module matches its description.
- AuraBuffs window: an added consumable shows its icon and name instead of its item ID.
- Forever skin: Quality of Life's tabs fit inside the window instead of running off its right edge.
- Campfire: on the Round reminder, clicking the "Click to sit" words makes you sit, not just the
  icon.
- Buffs & Reminders: the reminder icons and their item menu now take the theme's Borders & Lines
  color for their edges.
- AuraBuffs: the Buffs & Consumables preview no longer shows Arcane Intellect (or any raid buff) you
  do not track.
- AuraBuffs: with Icon set to Last Used, the Weapon Enhancement Reminder shows and uses the stone or
  oil you used last when you carry it.
- Restock Reminder: counts equipped Rogue and Warrior thrown weapons as ammo, and groups ammo after
  Class Reagents under class-coloured headings.
- The Gear & Trinkets and Blessings bars no longer stay on screen after being switched off around
  Unlock Mode.
- Forever skin: every Quality of Life tab shows its full name.
- Map: mount vendors such as Veron Amberstill no longer show as innkeeper pins.
- Professions: the Disenchant window no longer blocks keyboard input while it is open.

## 1.1.17

### Added
- German: Glimmer, Naowh's Forge's Simple view, Mana Efficiency, the Shopping List's consumables,
  the XP bar's new effects and the other new parts of 1.1.12 to 1.1.15 now show in German on German
  clients.
- Professions: the Shopping List's Consumables picker has a search box, and a star on each item that
  pins it under Favorites at the top of the list (saved per profile).
- Ability to remind a player to learn a new flight point if unknown
- Damage Meter: a left click on a death in the Deaths list opens the game's Death Recap for it.
- QoL: Group Finder Roles, role buttons on the Group Finder that show only players of a role, or
  only groups that still need one.

### Changed
- Journeys: the minimap route draws flights, ships, the tram and portals in their own colours, as
  the world map does.
- Journeys: a flight is drawn through each flight point it stops at, on the world map and the
  minimap.
- Consumable Bar: Ask to Add asks at the bar even when it has no items yet.
- Lighter at login: about 3 MB less memory while the Quest List or Journeys is off; their quests,
  rares and quest spots load the first time those features need them, from Naowh Forever: Discovery
  Data and Naowh Forever: Journeys Data in your AddOns list, so keep both enabled.
- Lighter all the time: about 0.6 MB less memory for the English text, and a smaller download
  without an unused font and two unused icons.
- Lighter in combat and at idle: the Damage Meter, Threat Meter, Instance Tracker, Pet Tracker, Zone
  Levels, Bag Space and Restock do less work.
- Glimmer: the Behind My Character cut-out is removed.
- Glimmer: Quest Item Sparkle is a toggle in the Glimmer card, next to Show Skill and Quest Line.
- Scrap Marker: a mark now ends when the item leaves your bags, so copies you loot later are not
  scrap. Turn on Save Marks to keep marks for good.
- Macros: My Macros, Smart Macros and Library are now tabs of the Macros page instead of a separate
  window; /nfmacros opens them there.
- Macros: Simple mode is a short form (spell, who to aim at, what to do if no one is there) that
  says what one press does and shows the macro it writes.
- Macros: "the unit under your mouse" is now "mouseover" everywhere.
- PvP: the Focus Macro button opens Macros on its Smart Macros tab.
- Onboarding: the Minimalist setup is now Recommended, and both setups have clearer descriptions.
- Onboarding: a module you turn on moves to the end of the Enabled list.
- Settings: changing the Skin asks to reload right away.

### Fixed
- Journeys: a far-away quest you track now goes to the quest itself, flying when that is quicker,
  instead of walking to the next zone border.
- Journeys: learning a flight point at a flight master plans the journey you are on again, so it can
  take that flight.
- Journeys: walks start from the ground you stand on instead of the lowest ground nearby, and are no
  longer counted as longer the higher up you are.
- German: the Mana Efficiency line in spell tooltips says Heilung or Schaden instead of the English
  healing or damage.
- Damage Meter: a Lua error that repeated after you died in a fight, from the figure columns being
  sized from text the game keeps secret.
- Damage Meter: the Deaths list shows when each death was instead of 0, and its summary and a Deaths
  column on another list count the deaths.
- Journeys: walking routes cut straight across open ground instead of bending at every map tile
  edge.

## 1.1.16

### Added
- XP Bar: Keep Blizzard XP Bar setting, so Blizzard's experience bar can stay between your action
  bars alongside ours.

### Changed
- Glimmer: herbs and ore light up grey with the skill they need on a character without Herbalism or
  Mining, instead of staying unlit.

### Fixed
- Journeys: following a journey no longer builds up memory and lag while you fight and move around,
  as when farming.

## 1.1.15

### Fixed
- Training Planner: resetting your talents while following a build asks whether to learn it again,
  instead of spending the points straight away.

## 1.1.14

### Changed
- Glimmer: its map data is now part of Quality of Life, one addon fewer in your list; delete an old
  NaowhForever_GlimmerData folder if you install by hand.

### Fixed
- Journeys: routes use the Deeprun Tram again, so Dun Morogh and Ironforge journeys from Stormwind
  no longer walk the long way round.
- Journeys: the route on the world map follows every walk instead of a straight line, and rides are
  drawn in their own colour.
- Journeys: flight points learned at a flight master are picked up straight away, and a character
  with none learned is told to open a flight master's map.
- Journeys: focusing a quest again after closing its Journey card brings the card back.
- Journeys: dungeon quests like Save Techbot's Brain! start a journey to the dungeon's entrance.

## 1.1.13

### Added
- Quality of Life: Shift-click the on-screen Disband button to disband without the question.
- Restock Reminder: a live preview on its settings card.
- XP Bar: Show Texts On Mouseover hides the texts around the bar, or all of them, until you hover
  it, and its times are shorter, with Time to Level and XP/Hour hidden until you earn XP.
- XP Bar: Leveling Pace, Time to Level and XP/h in one text.
- XP Bar: effects, each with its own switch: Shine, Notches, Rested Stripes, Quest XP Pulse, Ready
  to Level, Level-Up Flash and Hover Breakdown.
- Glimmer: quest givers light up when they have a quest to pick up or hand in.

### Changed
- Blessings: Growth Direction is at the top of the Anchor card.
- Professions: Add to List opens the Shopping List.
- Restock Reminder: the Hunter Ammo settings show on every class, to set up a profile on any
  character.
- Buffs & Consumables: the weapon reminder's default icon is a classic sharpening stone.
- Glimmer is now a tab under Quality of Life instead of its own module; delete an old
  NaowhForever_Glimmer folder if you install by hand.
- Glimmer: Show the Cut-Out is a toggle; click again to hide it.
- Glimmer: the tab opens on the Glimmer card, with its on/off in the header.
- Glimmer: herbs and ore stay unlit on a character without Herbalism or Mining.
- XP Bar: a cleaner settings card; reset it by right-clicking the preview.
- Naowh Score: graded against the best for your level by default.

### Fixed
- Blessings: the bar's buttons no longer show Blizzard's square glow over their black edge when
  hovered or pressed.
- Glimmer: quest objects and quest turn-ins light up in the effect picked for quest objects.
- Journeys: frees its walking maps after a minute unused, so it holds much less memory between
  journeys.

## 1.1.12

### Added
- GCD Tracker: Show Icons and Show Activity Bar switches in QoL > Combat, so you can keep the
  scrolling icons and hide the blue bar under them (or the other way round).
- Campfire: a Sit button beside the Refresh Camp reminder and the Camp Nearby alert (Show Sit
  Button).
- Campfire: a glow on the reminder while you have no Camp Benefits (Glow When Refresh Needed).
- Key Bindings: Naowh Forever now has a key for Instance Tracker, Discovery, Gear Sets, Blessings,
  Macros, Action Bars, AuraBuffs, Threat Meter and PvP.
- Training Planner: talent builds can carry spells to skip, picked in the build editor; Learn All at
  the trainer follows the build you follow and trains the rest.
- German: the Damage Meter, Journeys, invite buttons and the other new parts now show in German on
  German clients.
- Buffs & Consumables: Weapon Enhancement Reminder (off by default) for a weapon with no sharpening
  stone, weightstone or oil.
- Training Planner: a Weapon Skills section on the Spells tab lists the weapon skills your class can
  learn and the weapon master that teaches each; click one for a waypoint to the nearest.
- Restock Reminder: Hunters can set an ammo warning amount and buy ammo independently at vendors.
- Professions: the Shopping List is a window of its own (Shopping List button on the profession
  window, or /nf shopping), so it stays open when you close the profession window.
- Professions: add any item to the Shopping List, not just recipe materials: shift-click it, drag it
  in, or type its name or ID.
- Mana Efficiency now covers Blizzard, Rain of Fire, Flamestrike, Consecration, Hurricane, Volley,
  Fire Nova and Holy Shock, with the area spells shown per target.
- Growth Direction (Right, Left, Up or Down) for the Food & Drink Bar, Gear Set Bar and Trinket Bar,
  on their settings cards.
- Training Planner: the build editor has a Talents tab and a Spells tab, and the Spells tab has
  Select All and Clear for the spells a build skips.
- Settings > Minimap Icons: minimap buttons for the Scrap List, the Quiz and the Aim Trainer, off by
  default.
- Consumable Bar: the Food & Drink buttons in Adding Items, your best food and drink (food only for
  warriors and rogues).
- QoL > Questing & Group: Open Saved Rewards shows every reward you saved for a quest, with a Remove
  button on each and Clear All.
- Bars: the Consumable, Food & Drink, Blessing, Gear Set and Trinket bars and On-Screen Buttons now
  glow under the mouse and look pressed while clicked or while their key is held, like the game's
  action buttons.
- Key Bindings: keys for Journeys, Professions, Consumable Bar, Swing Timer, Top Bar, Scrap List,
  Disenchant, Quiz and Aim Trainer.
- Mana Efficiency counts your talents: percent healing and damage talents, Illumination's mana back
  on crit heals and Elemental Focus's free casts, at your ranks. Turn it off with Include My Talents
  in Tooltips > Spell Efficiency.
- Buffs & Consumables: an Icon choice, Default or Last Used, to show the item you used last.
- Buffs & Consumables: an optional glow on each reminder icon.
- Profiles > Share: Saved Quest Items, so the quest rewards you saved can be left out of a shared
  profile or sent on their own.
- WagoUI Packs can export, import and switch your Naowh Forever profiles.
- Fishing Levels (QoL > Map & Pins > Map Options) shows the Fishing skill a zone needs under its
  name on the world map.
- A Forever skin (Settings > Colors > Skin) that dresses the windows like WoW Forever's own, by
  Dieman.
- Blessings: an Anchor card to anchor the Blessing Bar to another element or a unit frame, and Reset
  Position to put it back above Buff Reminders.
- Glimmer (Adventure): herbs, ore, chests, quest objects and your fishing bobber light up as you
  walk up to them, colored by your chance of a skill-up, with five effects to pick from. It can also
  keep the loot sparkle on quest items.
- Glimmer: Minimap Icons shows where herbs and ore grow near you, ringed in your skill-up color,
  both at once whatever you track.
- Glimmer: Gathered on the Map pins every herb and vein you gather on the world map; click one for a
  waypoint. Also under QoL > Map & Pins.
- Glimmer: Behind My Character cuts the effect out around you, so it passes behind you instead of
  over you, with a size, a height and a red outline to fit it.
- Quality of Life, Tooltips: a Mana Efficiency report of every rank in your spellbook (/nf
  efficiency).
- Professions: the Shopping List has a Consumables picker (title bar) with the food, flasks,
  elixirs, potions, scrolls, weapon stones and oils and bandages that suit your class and level, the
  best for your level marked; set an amount to add it to the list and buy it at the auction house
  with Buy All.
- Professions: the search box also finds recipes by their reagents, like Blizzard's.
- Journeys: Waypoint Only Where Steps End (on) puts the game's waypoint on the dock, flight master
  or goal, not on every bend.
- Training Planner and Discovery: a Key Binding card on their settings page to set the key that
  opens them.
- Macros: Naowh's Forge has My Macros again: your macros and an editor with a Simple view (each line
  as a sentence with menus, Fix it, recipes and Test it) and an Advanced view (colored text, Build,
  Reads as, Simulate).
- Macros: the Forge's spell boxes offer the spells you know as you type.

### Changed
- Dungeon Journal: its data is updated to WoW Forever build 1.60.1.70374.
- Dungeon Journal: drop chances updated from Wowhead's latest kill counts.
- Campfire: the Enchanted Lute bonus is labelled +MotW instead of +ARM.
- Quality of Life: Buff Thank You Message is on the Interface tab, and Durability is on the Combat
  tab.
- Settings: Modules and Minimap Icons are closed by default and open from their header.
- Mana Efficiency: area spells (Frost Nova, Arcane Explosion, Holy Nova, Prayer of Healing and the
  like) now say "per mana / target" (HPM and DPM in Short), the numbers being for one target.
- Quality of Life, Loot & Items: Looting, Vendors, Auction Prices and Mail & Alts are one card, and
  the Scrap List button is at the bottom of the tab.
- Buffs & Consumables: with Only If I Carry One off, flasks and elixirs are reminded about too,
  whether or not you listed any.
- Quality of Life: the Equipment Reminder is removed.
- Training Planner: no longer needs the Professions module, so enabling it no longer enables both.
- The Damage Meter module is no longer part of Naowh Forever. The Default Damage Meter settings
  under Quality of Life are unchanged.
- The ten language addons in the AddOn list are now one, Naowh Forever: Locales.
- The Top Bar is part of Quality of Life now: its settings are the Top Bar card on Quality of Life >
  Interface, and it is no longer listed as a module under Settings or in the setup.
- Blessing Bar: the Direction setting now also grows the bar Left or Up, and is called Growth
  Direction.
- On-Screen Buttons: Button Layout is now Growth Direction, with Right and Down as before plus Left
  and Up.
- Blessings: Auto-Assign now plans Blessing of Salvation for the paladins when the group has two or
  more paladins and none of them is a tank.
- Training Planner: the Train Now button at your class trainer is now called Learn Selected.
- QoL: the Default Damage Meter skin and layout settings have their own Damage Meter tab, after
  Combat.
- Journeys and Instance Tracker are now listed under Utilities in the settings sidebar.
- QoL, Loot & Items: Scrap Marker sits directly above the Scrap List, after Bag Space.
- Onboarding: the Minimalist setup's description says who it is for.
- Loot Feed: looting an item that already has a line adds to its count instead of adding another
  line.
- Food & Drink Bar: steps aside while its buttons are on the Consumable Bar (its settings greyed),
  and its key bindings work for them there too.
- Settings > Colors: Theme sits beside Skin, with a three-color preview on its left.
- Buffs & Consumables: the personal buff reminders of every class are listed, your own in its class
  color and the others in grey, and can be switched on or off for when you play that class.
- Buffs & Consumables: the reminder icons are bigger by default (48), and the Icon Size slider goes
  up to 96.
- Camp reminder: the Sit button is now a seated-figure icon with its label, the camp icon's size on
  the Round look and the bar's height on Simple and Camp Nearby.
- Swapping to a spec with its own profile now also turns modules on or off to match that profile,
  with a reload prompt when the AddOn list changes.
- The first login after this update turns off, in the AddOn list, every module that is already
  switched off in your profile (for example after Minimalist), and offers one reload.
- Campfire and Low Health: the glow can be a Pixel Glow or the Standard Glow, with its own color,
  lines, thickness and speed.
- Profiles > Share no longer has Macro Library or Consumables.
- The Forever skin replaces Classic+; if you used Classic+ you are moved to it.
- Onboarding: Minimalist is the recommended start, picked for you on a new account, and turns on
  only Quality of Life, the Dungeon Journal and the BiS List.
- Onboarding and Profiles > Setups: Recommended is now Everything Enabled, which turns on every
  module.
- Blessings: the Blessing Bar keeps its first button in place as classes join or leave, starts above
  Buff Reminders and moves with them; drag or re-anchor it in the HUD Editor.
- Onboarding: the modules step is bigger, with the modules you turned on at the top and a line
  before the ones that are off.
- Buff reminders: with Only If I Carry One on, a flask, elixir or buff food in your bags reminds you
  even if you have not listed it.
- Journeys: the route on the world map and minimap is drawn as dots.
- Onboarding: the Forever skin's preview is a small Forever window.
- Campfire: click the fire to sit when a campfire is in range, instead of a separate Sit button; the
  fire lights up to show it.
- Campfire: the Glow When Refresh Needed outline is off by default.

### Fixed
- the Weapon Imbue and Poisons reminders now clear when an imbue or poison is on the weapon,
  including Windfury.
- Dungeon Journal > Quest Tracker: Hide the Game's Quest Tracker keeps the game's tracker hidden
  after the UI comes back (Alt-Z, cinematics).
- Campfire: the Resting and Refresh Camp label no longer touches the Round icon's ring.
- Mana Efficiency: Hellfire counted its self damage on top of what each enemy takes.
- Training Planner: a build's skipped spells now come with it when you copy it, export it, share
  your profile, or follow it on a new character.
- RestedXP themes: Naowh (current) is drawn in the Classic+ colors when the Classic+ skin is on,
  instead of the theme picked last.
- Buffs & Consumables: with Only If I Carry One off, the food reminder shows even when you have not
  listed any food, and its icon follows the last food you ate.
- Trainer Popup: learning profession abilities no longer pops the New Abilities card.
- Questing & Group: Disband now removes everyone from your group instead of doing nothing.
- Professions: the Unlearn button beside each skill bar is easy to see again, and the profession
  tabs on the window's edge have an outline so they stand out.
- Quest List: a quest that needs several quests done first stays locked until all of them are, and a
  locked quest says which quests it is waiting on.
- Discovery: the scroll bar on the Library Books, Sleeping Bag, Quest List and Rares tabs always
  works, no matter which tabs you opened before.
- Settings: the Modules and Minimap Icons arrows are on the left, like the rest of the addon.
- Consumable Bar: Ask to Add asks again about a consumable that left your bags and is looted again.
- Modules you turned off stay off on new characters and in imported profiles, and turning a module
  on or off in Settings now also enables or disables it in the game's AddOn list for that character.
- Professions: the Total Craft Timer no longer counts down a batch the game refused (no reagents),
  and counts only the crafts your bags can pay for.
- Professions: the Disenchant window shows every item's real quality colour; the next item to
  disenchant gets an accent ring instead of a blue border.
- Onboarding: a module's description no longer runs out of its tile on the modules step.
- Journeys: a journey to a boat no longer turns into one straight walk at the dock or while you
  ride, and walks to and from boats go along the pier instead of swimming.
- Journeys: a route no longer flips between two near-equal ways as you move; it changes only for a
  clearly quicker one.
- Journeys: walks that used to show a straight line on the map are drawn along their path.
- Onboarding: a profile's description no longer runs out of its card.
- Opening the options window no longer throws a "Division by zero" error.
- Discovery: the scroll bar shows as soon as a tab opens, without scrolling with the mouse wheel
  first.
- Campfire settings: the Active preview no longer shows an empty box when Show Only When Low is on;
  it shows the reminder dimmed with a note.

## 1.1.11

### Added
- Settings: a Language setting, with French, Portuguese (Brazil), Spanish (Spain and Latin America),
  Italian, Korean and Chinese (Simplified and Traditional) joining German and Russian.
- Buff Thank You Message: Whisper Named Players, turn it off to answer every buff with the /thank
  emote instead of a whisper.
- Journeys: a pin you put on the map yourself plans the way to it (Journeys to Map Pins in the
  Journeys settings).
- QoL > Combat > Default Damage Meter: a Reskin switch that draws the game's own damage meter in
  your theme, with a bar texture, font, outline, colors, sizes, title bar fade, scroll bar, buttons,
  border and spell panel to set.
- Default Damage Meter: Move and Resize, to drag the game's damage meter and resize it by its corner
  without opening Edit Mode.
- Default Damage Meter: the game's own Edit Mode settings for its damage meter (Bar Style, Numbers,
  Window Width and Height, Bar Height, Bar Spacing, Window and Background Opacity, Text Size,
  Visibility, Spec Icon, Class Color) set from the card, with Restore Game Settings.

### Fixed
- Journeys: the journey carries on through the Deeprun Tram instead of ending with "No way found".
- Journeys: arriving at the last stop clears the pin.
- Journeys: the card, the world map route and the pin follow you as you move.
- Journeys: reaching a pin partway along a journey no longer ends the whole journey.
- Professions: the Total Craft Timer bar disappears when you stop crafting instead of running on.
- Town Pins: Alchemy, Blacksmithing, Tailoring, Engineering, Enchanting and Leatherworking trainers
  now show on the map in every capital and starting town, not just Herbalism, Mining and the other
  gathering trainers.
- opening the character panel with the BiS List's look no longer errors.
- Personal Buff Reminders: Weapon Imbue now shows the enchant you last cast (Windfury, Flametongue,
  Frostbrand or Rockbiter), not always the same one.
- sharing a profile now also carries which modules are on or off, so importing it on another
  character matches.
- Top Bar: the clock returns to its chosen colour after you move the mouse off it.
- Tooltip copy shortcut: using Shift or Alt as the modifier no longer types the key into the copy
  card.
- Unlock Mode: modules that are switched off no longer show up to be moved.
- Map Window: when EllesmereUI's Shifter is on, Shifter moves and scales the world map and Naowh
  Forever leaves it alone.

## 1.1.10

### Added
- QoL > Questing & Group: Always Free for All sets your party's loot to Free for All whenever you
  lead it.
- Journeys (Adventure > Journeys, off by default): every waypoint a module places can become a
  journey over walking, the flights you know, your faction's boats and zeppelins, the Deeprun Tram,
  the Darnassus portal, your Hearthstone and class teleports.
- Journeys: walking follows the real terrain, with a compact Journey card for the steps and the
  route drawn on the world map.
- Journeys: tracking a far-away quest starts a journey to it, including quests the game gives no
  marker for.
- QoL > Questing & Group > On-Screen Buttons: Invite Buttons, a button per Battle.net friend or
  character you keep, and an Invite All button.
- Discovery: left-click a Rare Alert to target its rare.
- Map Options and Pins drawer: Town Pin Size slider at the bottom.
- QoL: a Map & Pins tab with Map Options and Map Pins, the home of every map option and map pin
  setting.
- Damage Meter: your group's damage, healing, absorbs, damage taken, interrupts, dispels and deaths
  in your theme, in up to three windows, with fight history, a summary line and the fight time.
- Damage Meter: hover a row for its spells and enemies, click it to drill in, report to chat or
  reset from the menu or a key binding.
- Damage Meter: choose a row's columns, texts, fonts and colors, and save looks by name to copy to
  other windows or share as text.
- Journeys: the route is drawn on the minimap too (Route on the Minimap in the Journeys settings).
- Journeys: Learn Lifts as You Ride (off by default) notes the lifts you ride; /nf lifts lists them.
- German: the whole addon now shows in German on German clients: settings, windows, tooltips, the
  HUD Editor and the messages in your chat.
- Top Bar: Clock Color, under Colors.
- Journeys: walks take the Great Lift, the Freewind Post lift and the Thunder Bluff and Undercity
  lifts.
- Consumable Bar: Remove Empty in Edit Items takes off every item you have none of.

### Changed
- QoL > Questing & Group > On-Screen Buttons: the Invite Player row is replaced by Invite Buttons,
  and the target Invite button can be turned off.
- Professions: Disenchant Window: right-click keeps only that copy of an item; Shift-right-click
  keeps every copy.
- Map Pins: town pins are smaller on the world map.
- Map: the map button's drawer holds the town pins only; every other pin and map option is on QoL >
  Map & Pins.
- Map: the windowed world map can always be resized from its corner and moved by its title bar; Map
  Window is no longer a setting.
- Map Pins: every pin size defaults to 20, and the same number gives every kind of pin the same
  size; quest pins are smaller by default, about 56% of their old size.
- Map Pins: pins are larger on the full screen map.
- Map Pins: Skyborne Spots only shows for Skyborne characters, Stable Masters only for hunters.
- QoL: a setting EllesmereUI also has no longer shows "EllesmereUI has it on"; turning one on while
  it is on in both now asks you to turn one off.
- Credits: the line under Ellesmere's name now thanks him for allowing us to add some of EUI's
  styling and functionality.
- Consumable Bar: Hide When Out is on by default and takes an item you have run out of off the bar,
  so the bar closes up; it comes back in its place when you get more.
- Consumable Bar: Scan Bags and Ask to Add leave Other Consumables out unless you switch them on in
  the Scan Filters.
- Waypoints: a waypoint placed while the world map is open now shows on the map at once instead of
  after you close and reopen it.
- Discovery: Quest List and Rares are now tabs of the Discovery window, next to Library Books and
  Sleeping Bag; Shift-L and /nfquests open it on the Quest List tab.

### Fixed
- Consumable Bar: Ask to Add New Consumables and Scan Bags only offer scrolls that give a buff.
- Performance: clarify that the Auto Push Spells to Bars recommendation stops automatic spell
  pushes.
- Map Pins: library book and Sleeping Bag pins no longer grow huge on the full screen map.
- Always Free for All: no longer keeps asking for Free for All when the game turns it down.
- Invite buttons: a Battle.net friend's alt on the other faction is no longer picked when
  cross-faction parties are off.
- Invite buttons: a button changed in combat invites the person it shows, not whoever took its place
  in the list.
- Journeys: walks to Marshal's Refuge, Morgan's Vigil and the Stormwind Harbor dock follow the
  ground instead of a straight line.
- Journeys: quests whose turn-in is in Stormwind, Mulgore, Redridge or the Eastern Plaguelands lead
  to the right spot.
- Instance Tracker: no more "attempt to compare a secret string value" errors when nameplates
  appear.

## 1.1.9

### Changed
- Dungeon Journal: boss loot updated from the latest Forever loot lists.
- BiS List: picks updated from wowsrc.com's latest lists.

### Fixed
- BiS List: ten picks wowsrc lists were missing from the lists (wowsrc shows them blue, the game
  green).

## 1.1.8

### Added
- Dungeon Journal: City of Dalaran is open, with every boss's loot and drop chances.

### Changed
- Dungeon Journal: the old dungeons' group is called Low Level and sits at the top of the dungeon
  list, closed until you open it.
- Dungeon Journal: its data is updated to WoW Forever build 1.60.1.70338.
- Dungeon Journal: boss loot updated from the latest Forever loot lists.
- Dungeon Journal: drop chances updated from Wowhead's latest kill counts.
- BiS List: picks updated from wowsrc.com's latest lists.
- Dungeon Journal: City of Dalaran and Excavation Site read wowsrc.com's loot lists too.

### Fixed
- Dungeon Journal: an item placed on a boss twice is listed once (the Stockade's Defias Renegade
  Ring).

## 1.1.7

### Added
- AuraBuffs: personal buff reminders for every class (armor, Inner Fire, Battle Shout, poisons,
  weapon imbues, shields, Thorns, Trueshot Aura, Hunter's Mark on elites), with a switch for each on
  the Buffs & Consumables card. Warn With Minutes Left flags them before they run out.
- Town Map: boat pins for the new Stormwind Harbor to Auberdine boat and the Steamwheedle Port to
  Powderfuse Port (Riverglades) boat.
- Town Map: zeppelin pins for the Dalaran and Mulgore zeppelins to Zephras Isle, and the island's
  docks back.
- Key binding: Open Training Planner, under Key Bindings > Naowh Forever.
- QoL > Interface: Names Over Heads, switches for guild names, guild titles and player titles shown
  with player names.
- German: the options window, module names, tabs, buttons, search hints and gear slot names now show
  in German on German clients.
- Consumable Bar: Smart Buttons in Adding Items: NF Health, NF Mana, NF Bandage and NF Food from
  Macros, and the Food & Drink buttons, each always using your best item.
- Consumable Bar: Scan Bags and Ask to Add skip what a smart button already covers, and adding one
  yourself asks first.
- Settings: a card's on/off switch shows the Changed dot when it is off its default.
- Settings that EllesmereUI also has (auto repair, sell junk, quick loot, skip cinematics and more)
  now say whether EllesmereUI has them on, so you can keep only one running.

### Changed
- Macros: a Smart Macro the Consumable Bar uses stays on and shows Used by Consumable Bar.
- Food & Drink Bar: steps aside while its buttons are on the Consumable Bar (its settings greyed),
  and its key bindings work for them there too.
- Consumable Bar and Food & Drink Bar: the keybind font starts on the addon font, and the Food &
  Drink preview shows the keys you bound.
- Consumable Bar: warriors and rogues get no drink button or NF Mana, no drinks or mana potions from
  Scan Bags and Ask to Add, and adding one yourself asks first.
- The Moderator badge is red.
- The XP Bar hides in battlegrounds and arenas.

### Fixed
- Action Bars: importing a saved set no longer makes a second, outdated copy of each NF macro; your
  own NF macros go on the bars.
- Action Bars: Save on Logout no longer saves a set with no actions, which made importing it blank
  your bars; it also never saves an alt's bars over a set the alt only imported.
- Town Map: the Menethil Harbor and Auberdine boat now shows its Southshore stop, with a dock pin in
  Hillsbrad Foothills.
- Scrap Marker: works in Baganator's bags: marked items show the mark, Alt+click marks them, and
  Baganator's junk can follow your scrap list.
- On-Screen Buttons: Invite and Disband now start on the left edge of the screen instead of over the
  action bars.
- Auction Prices: the Scan Prices button is no longer hidden behind Auctionator's tabs; with
  Auctionator loaded it sits after them.
- The /nf badges help line no longer breaks into pieces in chat.
- Professions: the window stays where you drag it when EllesmereUI's window mover is on, instead of
  snapping back.

## 1.1.6

### Added
- Bag Space: Reverse Order puts the cheapest item at the far end of the row, so it can grow left
  with the cheapest on the left.
- Action Bars: `/nf ab <set>` imports a saved set, and `/nf ab` lists them.
- Action Bars: Import on New Character imports a saved set once when a character first logs in at
  level 1.
- Macros: NF Healthstone, NF Health Potion and NF Drink macros, and a Food-only option for NF Food.
- Macros: Extra Lines on each smart macro, such as a mouseover heal after your potion.
- Quests: Modifier Does lets the quest key trigger the quest steps instead of skipping them, so they
  can be off by default with a key to accept.
- Quests: NPC Gossip picks the only option of a vendor, flight master, trainer, banker, auctioneer
  or stable master, with its own modifier.
- Macros: Save a Macro on the Library tab keeps one of your game macros under your class.
- Professions: Disenchant Window. With Enchanting open, a Disenchant button lists every item in your
  bags you can disenchant; right-click one to keep it, and Disenchant All disenchants the rest one
  click at a time.
- Consumable Bar (Utilities > Consumable Bar): your consumables on a bar you click, with counts,
  cooldowns and keys, and an Edit Items window to add, move and set up each item.
- Food & Drink Bar: Show Count and Show Keybinds, with cogs for their font, size, colour and
  position.
- Food & Drink Bar and Consumable Bar: anchor to one of your unit frames, or to another Naowh
  Forever element through the HUD Editor.
- New module that tracks instance history, lockouts remaining, an optional timer that shows current
  run stats and how many lockouts used in the last hour, the ability to see what runs your alts have
  done, has the ability to communicate with Nova Instance Tracker to send/receive instance reset
  messages, and automates announcing instance resets in chat.
- Macros: New Macro on the Library tab writes a macro with a name and its text, kept in your Library
  or added to this character.

### Changed
- XP per Hour: level splits are named by the level you reached, so the time you hit 14 shows on the
  Level 14 row.
- Map Pins: quest, rare and dungeon and raid entrance pins are set from Map Pins (QoL > Interface,
  and the Map Pins button on the world map) instead of Completo and the Dungeon Journal.
- Map Pins: zone exit arrows are smaller, in line with the other pins.
- Completo is now part of Discovery: its quests are the Quest List tab and its rares the Rares tab,
  under one switch. `/nfquests` opens the Quest List.
- Map Pins: stable masters only show for hunters.
- Map Pins is now Map Options and Pins: Map Window, Unexplored Areas, Zone Levels and Skyborne Spots
  moved into it from QoL > Interface.
- QoL: the Cursor tab is now Cursor & Crosshair and opens with its cards folded.
- QoL: Talent Points and Trainer Popup moved from Questing & Group to XP.
- The BiS List's Item Level in Bags option is gone. Bag Marks always shows item levels on gear in
  your bags.
- Bag Space: the gap and the price text shrink with the icon size, and icons can go down to 16.
- Macros: a smart macro for something you carry none of is made with a placeholder, so it can go on
  your bars before you have the item.
- QoL: Death Release Protection, Auto Combat Logging and Summon Emote are removed.
- Macros: the My Macros tab and the macro editor are removed; Naowh's Forge is Smart Macros and
  Library.
- Food & Drink Bar: its settings move under Consumable Bar while that module is on.

### Fixed
- XP per Hour: picking None for the text outline no longer leaves the window and its settings blank.
- Completo: spotting a rare no longer triggers the game's "blocked from an action" popup. Mark Rare
  is removed, since Forever doesn't let addons set raid marks.
- Map Pins: quest, rare, entrance and town pins keep the same size as you zoom the map.
- Character Panel stat hover cards say what Strength, Agility, Intellect and Spirit give your class
  (a Warrior's Agility gives only ranged attack power, a Shaman's none).
- Waypoint Pin: a waypoint you place on the map is tracked, so the pin shows it, and it goes away as
  soon as you reach it.
- Waypoint Pin: a waypoint placed on a continent map goes away when you reach it, and one you have
  been away from still does after another quest is tracked.
- Mana Efficiency: the line now shows on the tooltip of a macro that casts a mana spell.
- Settings: on a narrow card the "settings changed" note no longer runs into the Reset link.
- Smart Macros: extra lines that run a script are left out, and a change to the extra lines or Food
  Only updates the macro straight away.
- Action Bars: Import on New Character is chosen per class, follows a renamed set, and leaves an
  existing level 1 character's bars alone.
- Action Bars: Import on New Character still runs after combat when a setting is changed mid-fight.
- Quests: Auto Gossip no longer picks a lone flight master option.
- Tooltips: Mana Efficiency shows on macros on other addons' action bars.

## 1.1.5

### Added
- Mana Efficiency (QoL > Interface > Tooltips): mana spells show their healing or damage per mana
  and per second on the tooltip, to compare ranks, with a live preview. Off by default.
- PvP Flag: a movable button that flags or unflags you for PvP, in PvP > Flag.
- Zone Levels: hover a zone on the world map to see its level range, in QoL > Interface.
- UI Clutter: Hide Bag Bar hides the bag buttons beside the menu.
- Map Window (QoL > Interface): make the windowed world map bigger or smaller with the grip in its
  corner, and move it by its title bar.
- Training Planner: rename a saved talent build from the Builds tab.

### Changed
- Settings say Color instead of Colour everywhere.
- Minimalist now keeps every module on except Completo, Discovery, Group Inspect, Gear & Trinkets
  and Swing Timer, which you can still turn on from the onboarding's modules step or the sidebar.
- Leveling up with the Training Mini Bar shown is a little smoother.
- Map Pins: the town pins use the game's own map icons instead of square spell icons, with a ferry
  for boats and a travel globe for zeppelins.
- Restock Reminder: Ammo to Carry can now go as low as 50.

### Fixed
- Map Pins: clicking a zone exit or dock on the world map no longer blocks the quest pins the next
  time the map is opened in combat.
- Blessings: a class button's menu shows when players in that class have their own blessing, with a
  button to give them the class blessing again.
- Guild and Friends list tooltips no longer throw a Lua error when a player's details are hidden in
  combat or instances.
- Loot Feed: it no longer jumps to the bottom of the screen at login when it was anchored to Alerts.
- With gamepad mode on, opening Options from the game menu no longer shows the "blocked from an
  action" popup. In gamepad mode the Naowh Forever game menu button is hidden (use /nf), and the Top
  Bar clock and custom window commands say they can't open windows instead of triggering it.
- Buff Thank You Message: Thank With an Emote now sends the game's /thank instead of a custom emote,
  which the game blocked with an error. The Emote Lines editor is gone.
- Profiles > Setups: applying a setup turns on the modules it includes, even ones turned off before.
- Top Bar Icon Color is disabled under Classic+, where icons are always full color.
  ![](https://media.giphy.com/media/2yqYbPakQKDFhNZbW9/giphy.gif)
- The Professions, Swing Timer and Threat Meter settings pages load again instead of erroring at
  login.
- Map Pins: the town pins, zone exits and docks are no longer tiny on the small world map.
- Death Release Protection: the death popup no longer stretches to fill the screen near an instance
  portal.
- Pet Tracker: hunters with the Lone Wolf talent no longer get the Pet Missing warning.

## 1.1.4

### Fixed
- Professions: the settings page no longer throws a Lua error on load.

## 1.1.3

### Added
- A Share My Score toggle on the Naowh Score card (BiS List > Character), so you can stop sending
  your score to your group and guild.
- Every Map Pins toggle is now on the Map Pins card in QoL > Interface, as well as on the world
  map's Map Pins button.
- Choose each class's blessing on the Blessing Bar card in Blessings settings.
- Searching settings finds each PvP crowd control and debuff spell by name, like Polymorph, Sap or
  Mortal Strike.
- Show or hide each campfire bonus from the Campfire card in AuraBuffs settings.
- A Talent Builds card in Training Planner settings shows the build you follow, with Stop Following
  and Open Builds.
- The Professions recipe window's logo opens its settings.
- Open Quest Tracker on the Dungeon Journal's Quest Tracker page, and a Key Binding card in BiS List
  settings.
- Stats Shown on the Character Panel card picks Your Spec or All Stats.
- Reset the Quiz and Trainer Popup positions from their cards.

### Changed
- The Trainer Popup settings are now in QoL > Questing & Group, so they show without the Training
  Planner.
- Keep Cursor In Window During Combat and Cooldown at Cursor are now on the QoL Cursor tab.
- The BiS List card with tooltip and bag marks is now called Marks on Items.
- On the Classic+ skin, buttons are the game's own red panel buttons, white with a glow under the
  mouse.
- On the Classic+ skin, the Threat Meter's icon is Rallying Cry and Group Inspect's is the Eye of
  Kilrogg.
- On the Classic+ skin, text is in Friz Quadrata like the game's own interface, with Arial Narrow
  for compact numbers.
- On the Classic+ skin, windows have the game's wood background in place of rock.

### Fixed
- The game no longer freezes for a moment when you level up or learn spells at a trainer.
- Loot Feed: it no longer drifts from where you placed it in the HUD Editor after alerts show or
  hide.
- Your Naowh Score is no longer sent to your group and guild while the Naowh Score is switched off.
- Group Inspect now works with the QoL module switched off.
- Spells you skip in the Training Planner start unticked at the trainer, so Learn All I Can Afford
  leaves them out.
- Settings > Modules now shows and sets the same on or off state as each module's own switch.
- The Sleeping Bag tracker's X now hides it until you enter another zone, like the Library Books
  tracker, instead of switching it off.
- In the HUD Editor, the Alerts group's Settings button asks which alert to open (Camp Nearby,
  Talent Points, Durability, Restock Reminder or Pet Tracker) instead of always opening Durability.
- RestedXP's arrow in Naowh's themes keeps its colour on its tips when it turns.
- On the Classic+ skin, a slider's gold gem sits over its groove instead of behind its lines.

## 1.1.2

### Added
- /nf help lists every Naowh Forever command.
- /nf move (or /nf hud) and a new key binding open and close the HUD Editor.
- Each module's settings page shows its own slash command under the title.
- The settings search finds hidden clicks and commands, such as Alt+Shift-click for BiS, the
  profession Filter menu and favourites, right-click to skip a spell in the Training Planner,
  Dungeon Journal keys and the /nf commands.
- The addon compartment entry shows a tooltip.

### Changed
- Adding a module's name to a search narrows it to that module, and searching for a module that is
  turned off points you to Settings to turn it on.
- The open-window button on a module's sidebar row is always visible, dimmed until you point at it,
  and every page says when nothing on it matches your search.
- /nfbars save, restore, test and delete work like /nf bars.
- The minimap button tooltips for Threat Meter and PvP say they open their settings.
- The onboarding is now four quick steps: a profile (Minimalist, Recommended or keep yours), a skin
  with a live preview, your modules, and a summary to apply.
- Minimalist now turns on only Quality of Life, the BiS List and the Dungeon Journal, from the
  onboarding and from Profiles > Setups.
- Profiles > Setups has an Onboarding row to start it again, and Before Onboarding to restore.

### Fixed
- The settings search now finds everything on the Settings page (modules, minimap buttons, fonts,
  window scale, skin, theme, RestedXP) and the Profiles page's actions (new, copy, reset, delete,
  share, import).
- Searching for a window such as "scrap list" or "forge" now finds its Open button, and searching
  for "quality" finds Quality of Life.

## 1.1.1

### Added
- On the Classic+ skin, the sidebar and Top Bar use the game's full-colour icons.

### Fixed
- The NF Health macro and the low health icon now use Forever's Discolored healing potions and the
  Combat Healing Potion.
- NF Health uses your healthstone and then your potions in the same fight, and moves on to your next
  potion when one kind runs out mid-fight.
- On the Classic+ skin, the "Naowh Forever" title plate fits its title and is in the Naowh font.

## 1.1.0

### Added
- PvP > Battlegrounds: move the battleground scores and the start countdown in the HUD Editor's PvP
  section.
- Completo: an Overview tab, where the window opens: how far along you are in Quests and Rares,
  everywhere and in the zone you are in; click one to open it.
- Completo: a General settings tab with Open Completo, Key Binding and Window.
- row cogs on hidden rows, row icons and card watch
- AuraBuffs > Consumables: Import and Export buttons copy a consumables list between profiles;
  Import also takes the consumables from a profile string.
- A Classic+ skin in Settings > Colors, which dresses the addon's windows in gold and bronze, like
  the game's own.
- On the Classic+ skin, buttons are red with a gold rim, like the game's own.
- On the Classic+ skin, switches are check boxes with the game's gold tick, and sliders, dropdowns
  and text boxes look like the game's own.
- On the Classic+ skin, tabs, the sidebar, section headers and settings cards look like the game's
  own.
- On the Classic+ skin, text is in the game's Arial Narrow and headings in its Friz Quadrata, and
  help cards look like the game's tooltips.
- On the Classic+ skin, windows have the game's rock background and headings stand out more.
- Tailor my setup: seven quick questions pick what Naowh Forever turns on, and you review every
  change before it applies (on your first login, from the Profiles page, or /nf setup).
- A new character asks whether to use the same settings as your main or set itself up on its own,
  with its own modules.

### Changed
- Completo: right-clicking a rare's star on the world map keeps its spots and route shown without
  opening a panel; hover it for its tooltip.
- AuraBuffs > Consumables: an item ID is enough to add a consumable; food counts any Well Fed buff
  and other items their own buff.
- Map Pins: choose which pins show from the Map Pins button in the world map's top right corner,
  which opens a drawer beside the map. The options card keeps the on/off switch and Pin Size.
- Map Pins: Mailboxes on Minimap and Spirit Healers on Minimap are separate switches.
- Everyone sees the new onboarding once, even with Naowh Forever already installed.
- The BiS List and the Dungeon Journal can be turned on and off separately; where one needs the
  other, it says so and offers to turn it on.
- Quality of Life and the Top Bar are their own modules you can switch off in Settings > Modules.
- Naowh's setups and Tailor Setup are on the Profiles page, and settings search finds them.
- Picking the Character Panel or Inspect Panel in the onboarding takes over from EllesmereUI's
  without asking again.
- The Bag Space Ignore List's search has a clear button, Escape clears it, and the list uses the
  slim scroll bar.
- The sidebar and the copy box use the slim scroll bar.
- The Reminders part of a profile string is now Consumables and shares only your consumables list;
  older strings still bring their consumables.
- Every Library macro is now included when you share your Macro Library.
- Smart Reminders, Reminder Packs, the Buffs module's Debuff Sounds tab and the /nsr command are
  gone.

### Fixed
- Top Bar: battleground scores and the other displays at the top centre of the screen sit below the
  bar instead of under it.
- Swing Timer: with Seal Colours on, the melee bars keep the seal's colour after a Judgement instead
  of going back to the default.
- Macros: no more Lua error refreshing the NF Health macro while the AuraBuffs module is turned off.
- Credits: the cards line up, with names and descriptions in the same place on every card.
- Dungeon Journal: Wailing Caverns' map is the old classic map again, with its bosses placed where
  they stand on it.
- Completo: the quest pins on the full screen world map are no longer oversized.
- Completo: right-clicking a focused rare's star again shows every rare's star again straight away.
- The waypoint pin for a quest sits where the game's quest marker does instead of floating above it,
  and goes away once you reach the quest giver.
- Completo: the search box no longer overlaps the tabs.
- Map Pins: flight masters, innkeepers and stable masters show on every map again; the capitals
  switch, now Vendors & Trainers Only in Cities, only hides vendors and trainers outside the cities.
- Applying a setup no longer wipes your saved quest rewards, lists and notes.
- Character panel: the level line, Naowh Score and supporter badge fit the latest Forever update,
  and the badge and BiS List link show only on the Character tab.
- Supporter badges show again after the latest Forever update.
- Macros: Open in Editor from the Library switches to My Macros instead of erroring.

## 1.0.6

### Added
- Dungeon Journal: Naowh's tips for the four Excavation Site bosses.
- Dungeon Journal: dungeon and raid entrances on the world map, on zone, continent and world maps
  (Settings > Dungeon Journal > Map > Dungeon and Raid Entrances). Hover for the levels, click for a
  waypoint; Icon Size sets how big they are.
- QoL > Interface > Skyborne Spots: Skyborne characters see the ley lines (Alliance) or Elemental
  Convergences (Horde) on the world map, and each new one they cast their racial on is saved.
- Completo, a new module (Settings > Modules): every quest of every zone for your character, your
  progress per zone, and every quest chain with the step you are on. Open it with /nfcompleto or
  Shift-L.
- Completo: search every zone's quests by name or quest giver.
- Completo: Map Pins (off by default) mark quest givers with a quest you can pick up, blue for
  repeatable ones, grey for low level ones with Low Level Quests, and the mobs whose drop begins a
  quest. Chains Only leaves just quest chains.
- Completo learns from the quest givers you speak to which quests they really offer you.
- Completo's window can be sized by dragging its corner, and has its own scale and opacity.
- QoL > Interface > Chat Zones: the zone and level of whoever talks in chat channels, guild chat and
  whispers, in front of their message, plus a [Where?] link on whispers from unknown players.
- Chat Zones: the leader's zone on each Group Finder listing, and members' zones in its tooltip
  where known.
- Shopping List: - and + beside each craft change how many crafts it is for.
- Shopping List: materials you can make for less from their parts (a bar from ore, say) have their
  parts bought instead, with what is made first and what it saves under Make First.
- Shopping List: the estimate says how long ago your last auction house scan was.
- Auction Prices: the last scan's age, and when the next scan may run, beside the Scan Prices
  button.
- Completo: a Rares tab with every rare of every zone and which ones you have killed. Click a rare
  for its special drops (rare and epic items, recipes, new Forever loot), ticked once it dropped
  them for you.
- Completo: Rare Alerts (off by default): a card with the rare's portrait, a sound, and a raid mark
  of your choice on it when a rare is near you. Drag the card where you want it.
- Completo: rare Map Pins (off by default): a star per rare on the world map; hover for its other
  spawn spots and patrol route, click for a panel of its drops, right-click for a waypoint.
- PvP: a new module. PvP Auras shows your target's short buffs, the crowd control on them and the
  debuffs you pick, with the time left and their shields, and a focus panel to keep a Sap or
  Polymorph timer on a second enemy. Pick each crowd control and debuff in its icon grid.
- Cooldown at Cursor (QoL > Combat): press something still on cooldown and its icon, name and time
  left show by your mouse.
- Healer Mana (QoL > Combat): your group's healers and their mana, lowest first, with a cup by
  anyone drinking. Off by default.
- Buff Thank You Message (QoL > Questing & Group, off by default): whispers thanks when a player
  gives you a class buff in the open world, with optional lines per buff and an /emote when the game
  can't name them.
- Dungeon Journal: the Dungeon Quest Tracker has its own Window Scale, under Quest Tracker > Window.
- Blessings > Blessing Bar: a Direction setting (Horizontal or Vertical) to stack the bar in a
  column, with class labels beside the buttons.
- Blessings: Class Label Style under Blessing Bar > Buttons shows each class's icon under its button
  instead of its name.

### Changed
- Settings tooltips show down and right of the cursor, sized to their text.
- Short timers read in seconds up to 90, then minutes up to 90, then hours (co-tank debuffs, and
  timed lines such as the campfire's).
- Layout Mode: the grid's lines are 40 apart, with every fifth one stronger.
- Threat Meter: the pull line is called the Aggro Line (the bar and its settings), and with Tank
  Threat percent it also shows when someone outside your group holds the mob.
- Threat Meter: new default colours (your bar red, tank green, aggro line orange); colours you
  picked are kept.
- Flight Timer: Land Early's tooltip and the Layout Mode sample flight have new wording and stops.
- Swing Timer: new default bar colours (main hand cyan, off hand silver, ranged green, Cleave red)
  and a softer red for out-of-range text. Colours you picked are kept.
- Naowh Score: the player you hover is read first, so their score shows sooner.
- Completo: Rare Alerts now look like the other alerts, with font, size, background and glow
  options, a Stays For slider, a live preview in the settings, and move in the HUD Editor.
- Completo: click a rare's star on the map for a waypoint, right-click it to keep its route shown
  with a panel of its drops, a waypoint button and a button to open it in Completo.
- PvP Auras: the shield number has a small shield icon on both the target and the focus panel.
- PvP Auras: the focus panel fades while your focus is also your target, so the two no longer show
  the same.
- Options window: a soft shadow round it.

### Fixed
- Dungeon Journal: on the Excavation Site's map, the bosses and the entrance sit in the right places
  again.
- Blessings: class names under the Blessing Bar no longer overlap when the buttons are small or
  close together; they shrink, then shorten to three letters, when the full name does not fit.
- Closing or switching the Professions window in combat no longer causes a blocked action error
  after the window has been moved.
- Co-Tank: debuffs that are no danger to a tank (Weakened Soul, Recently Bandaged, Resurrection
  Sickness, Forbearance) are left off its debuff row.
- A moved Professions window now closes properly in combat instead of staying behind invisibly.
- Themes: the Combat Timer's background follows your theme's Background instead of staying black.
  Looks the same with the default theme.

## 1.0.5

### Fixed
- Naowh Score: no more error when your target's target changes gear.
- Character Panel: no more error opening it while your stats are hidden; Defense shows as hidden.
- CurseForge: updates show up in the CurseForge app again.

## 1.0.4

### Added
- Credits: Ellesmere, creator of EllesmereUI, is thanked with his own badge.
- Flight Timer: Flight Time on Map shows the flight time to each destination when you hover it on
  the flight master's map (QoL > Travel > Flight Timer).

### Changed
- Credits: a shorter line for Santiago Reyes's maps.

### Fixed
- CurseForge lists Naowh Forever under WoW Forever only, not Retail.

## 1.0.3

### Fixed
- Welcome window: on some screens its buttons no longer cover the Recommended setup.

## 1.0.2

### Changed
- Top Bar: Training Planner and Discovery have their own icons, in the bar's style.
- Minimalist setup starts with the Threat Meter off.
- QoL > System > Defaults: hovering a setup also lists the modules it turns on or off.

### Fixed
- Welcome window: it comes back after a reload when another addon's setup reloads before you pick a
  setup.

## 1.0.1

### Added
- Two setups by Naowh, Minimalist (almost everything off) and Recommended (the modules he uses on):
  pick one in the welcome window, or switch any time from the Setup dropdown in QoL > System >
  Defaults, whose tooltip lists what it turns on and off. Your BiS lists and notes stay.

### Changed
- A fresh install starts with the team's settings and HUD layout: Swing Timer, Threat Meter,
  Training Planner, Dungeon Journal, Smart Macros and the quest, loot and repair helpers start on,
  and every element starts in its place.
- Town Map Pins is now Map Pins, and Waypoint Pin sits under it on QoL > Interface.
- Export Profile and Reminder Pack exports copy as one unbroken line, so they paste cleanly into
  other tools.
- Smart Reminders is taken out for now while it is reworked for Forever.
- A new install starts with Naowh's setup: his module settings and positions.
- The durability warning starts off; turn it on under Quality of Life, Loot & Items.
- On a new install the XP bar starts 20px lower.
- The Top Bar's clock is off by default; turn it on with Show Clock in the Top Bar settings.
- The Top Bar starts with the Dungeon Journal and Discovery on the left and the BiS List and
  Training Planner on the right.
- New installs start from Minimalist, with almost everything off to turn on as you like.
- Item levels in your bags show in the item's quality color, so they no longer look like stack
  counts.

### Fixed
- Waypoint Pin: no more Lua errors when the game hides your movement speed; the walking time keeps
  using your last known speed.
- Waypoint Pin: the pin stands above the spot with its ring on the ground, instead of its line
  sinking into the ground.
- The sidebar keeps Combat above Utilities when Gear & Trinkets or Blessings is switched off.
- Clearing a waypoint with the navigator's X closes the navigator.
- With the clock hidden, the Top Bar's buttons sit in one row with no gap where the clock was.
- Imported profiles no longer bring someone else's answers about EllesmereUI's character and inspect
  windows, and turning Naowh's panel off no longer turns EllesmereUI's sheet back on when you had it
  off.
- Applying an enchant or armor kit over an existing enchant is no longer blocked; Auto-Replace
  Enchants is removed, as only you can confirm that popup.
- Your Naowh Score on the character panel no longer covers your gear sets or titles, so their rows
  can be clicked again.
- Shift-clicking the game's waypoint pin on the world map to share it in chat works again after
  placing a waypoint from Naowh Forever; a waypoint set while the map is open is placed when you
  close it.

## 0.5.25-beta

### Added
- Hovering a guildmate in the Guild & Communities list, or a friend in the Friends list, shows their
  Naowh Forever badge and Naowh Score, and for offline guildmates the last score seen with how long
  ago
- An Item Level in Bags toggle under the BiS List's Bag Marks, to hide item levels in your bags
- Swing Timer: a Font and an Outline setting for the bar text, under Text on its Bars card.
- Threat Meter: an Outline setting for the row text.
- QoL > Combat Alert, Combat Timer, Stealth Reminder and Pet Tracker: an Outline option and a
  Background (Card, Soft or None).
- Talent Points, Durability and Restock Reminder: Font Size, Outline and Background; Talent Points
  and Durability can also use the theme's colour.
- AuraBuffs > Camp Nearby: Font, Outline and Background.
- Focus Cast Bar: Outline, Bar Texture and Apply Theme to Bar Colours settings.
- Co-Tank Frame: Outline and Bar Texture settings.
- GCD Tracker: a Bar Texture setting for the activity bar.
- Group XP: Font, Font Size, Outline, Bar Texture and Background Opacity settings.
- XP Bar: Font, Font Size, Outline, Bar Texture and Background Opacity settings.
- Flight Timer: Font, Outline, Bar Texture and Background Opacity settings.
- Total Craft Timer: Font, Font Size, Outline, Bar Texture and Background Opacity settings, on its
  card under Professions.
- Bag Space: Font, Font Size and Outline, with the header and prices scaling to the size (QoL > Loot
  & Items > Bag Space).
- Loot Feed: an Outline choice, and a None style for lines without a background (QoL > Loot & Items
  > Loot Feed).
- Top Bar: Font and Outline for the FPS / MS readout and the button counts, and a Clock Outline (QoL
  > Interface > Top Bar).
- Buff Reminders, Low Health and the Tracking reminder: Font, Font Size and Outline for their text.
- Campfire: Font and Outline for both the Round and Simple looks.
- Blessing Bar: Font and Outline for its timers and labels, and Apply Theme to Status Colours.
- Group Buttons: Button Width, Button Height, Font, Font Size, Outline and Background.
- BiS List > Drop Alert: Font, Font Size and Outline for the on-screen alert.
- Gear Set Bar: Spacing, and Show Always, In Combat or Out of Combat.
- Smart Reminders: an Outline setting for the reminder displays and for the defensive alert, under
  Text on their cards.
- Smart Reminders: Bar Texture and Bar Background Opacity for the Bar display, and Circle Background
  Opacity for the Circle display.
- Smart Reminders: Apply Theme to Text for the reminder displays and Apply Theme to the Callout for
  the defensive alert, which use your theme's text colour in place of white.
- Threat Meter: Background Colour under Window, next to Background Opacity.
- Food & Drink Bar: key bindings for the food and drink buttons, on its card and under Key Bindings
  > Naowh Forever.
- AuraBuffs > Settings > Buffs & Consumables: a switch per raid buff, to choose which ones remind
  you.
- HUD Editor: a dragged element lines up with the others and the screen centre on guides, which show
  the gap to each element in pixels. Hold Alt to drag freely, or turn Guides off on the toolbar.
- HUD Editor: an anchored element's tag picks the side it sits off (Top, Left, Right or Bottom) and
  its gap in pixels, and the anchor is drawn on screen.
- HUD Editor: an Elements panel lists every element by module, with a search. Click one to select
  it, hide one to get it out of the way while you edit, or lock one in place.
- HUD Editor: Undo (Ctrl + Z), Redo (Ctrl + Y) and Revert on the toolbar put back changes you made.
- HUD Editor: Shift-click to select several elements, then drag or nudge them together, line them
  up, space them evenly or by a gap you type, or lock them all.
- HUD Editor: Layouts save where everything is under a name, to load again later with one click.
  Undo takes a load back, and locked elements stay put.
- HUD Editor: dragging lines an element up on even gaps with the others (between two, past a pair,
  or mirrored about the screen centre) and shows the equal gaps.
- HUD Editor: an anchored element's target shows a tab on each side; click one to anchor to that
  side.
- Naowh Inspect Panel: the inspect window in the BiS List's look, with their Naowh Score next to
  yours, talents, a gear check (unenchanted and empty slots, item level, upgrades for you), guild,
  your note and tag, and your history with them (QoL > Character > Inspect Panel).
- Inspected players' slots show item level, Forever's mark, an upgrade arrow for you and a dot on
  unenchanted gear; their BiS stars show when they run Naowh Forever.
- Share Your BiS (on by default) lets players who inspect you with Naowh Forever see your BiS stars.
- Player History (QoL > Questing & Group, off by default) remembers the players you group and chat
  with: sessions, dungeon and raid runs, and your last whispers and group chat, stored only on your
  computer.
- Write a note and a tag (Great Tank, Great Healer, Great DPS, Friendly, Avoid) on a player, shown
  on their tooltip.
- Waypoint Pin (QoL > Travel, off by default): marks the spot you are heading to with its name,
  distance and walking time, points the way from the screen's edge when it is off screen, and shows
  a navigator bar you can move in Layout Mode.
- Training Planner: the trainer waypoint takes you to your class trainer, then your professions'
  trainers in the same town, one after the other.
- Waypoint Pin: on a route, the navigator shows which stop you are on and the arrival names the next
  one.
- Group Inspect (Combat > Group Inspect, off by default): everyone in your party or raid with their
  Naowh Score, item level, gear, talents and stats in one window. Open it with /nf group, the Top
  Bar, the minimap button, a key binding or a party/raid member's right-click menu.
- Group Inspect marks Naowh Forever users, and turns the mark orange when their version is older
  than yours.

### Changed
- Lighter in combat and at idle: Buff Reminders, Threat Meter, Blessings, Swing Timer, GCD Tracker,
  Focus Cast Bar and the Top Bar do less work
- Naowh Forever's chat lines start with its logo, so they can't be faked
- Importing a profile lists the settings that act for you (auto emotes, auto sell, auto quests) and
  leaves them off unless you tick Also Import
- Importing a scrap list names its items and warns about valuable ones; importing macros warns about
  other addons' commands
- `/nf bars delete` asks before removing a bar set
- Options window: Search is a box at the top of the sidebar. What you type filters the window to the
  matching settings, and modules and tabs show how many matches they hold.
- New players with EllesmereUI get Naowh's character panel by default; others are asked once, with
  Naowh's recommended
- Threat Meter: Bar Texture lists every SharedMedia bar texture. Naowh Gradient and Flat stay as you
  set them.
- Swing Timer: its Bar Texture list includes Naowh Gradient.
- Combat Timer's Show Background is now a Background choice; existing "on" keeps its black panel as
  Card.
- Move Elements: the Alerts group's Settings button opens the Durability card.
- Focus Cast Bar, Co-Tank Frame and GCD Tracker: settings regrouped into Size, Text, Bar and
  Colours, like the other HUD elements.
- XP per Hour: Outlined Text is now an Outline choice with Shadow, Outline and Thick Outline; your
  current pick is kept.
- Bag Space, Loot Feed, XP per Hour and Top Bar settings are grouped the same way: Size, Text,
  Background and Visibility.
- Move Elements > Settings on the Library Books and Sleeping Bag trackers opens their own settings
  card.
- Smart Reminders: the Bar display always draws the Naowh Gradient by default, also without
  NaowhUI_Media installed.
- Smart Reminders: the font is also on the Reminder Displays card, and changing it updates the
  displays straight away.
- RestedXP: the Naowh Forever theme is now called Naowh instead of NaowhUI.
- Move Elements is now called HUD Editor.
- HUD Editor: elements have a black edge, so they are easier to line up.
- HUD Editor: Smart Reminders' displays are no longer in it for now, and the Customize Anchors
  button is gone.
- Threat Meter: the window can be made narrower (160) and shorter (50).
- Food & Drink Bar: moved from Macros to Quality of Life, Loot & Items, and works without the Macros
  module. Your settings come along.
- Food & Drink Bar: warriors and rogues get the food button only.
- Raid buff reminders leave out Paladin Blessings by default, since the Blessings module covers
  them. Switch them back on under Raid Buffs.
- Waypoint Pin: the card and navigator show what a spot is (an entrance, a quest giver, a trainer's
  title) and its icon from the module that placed it: your class for the trainer, the item for BiS,
  the book for Discovery. With the pin on, waypoints use the game's own even when TomTom is loaded.
- The Discord link at the bottom left of the settings window opens the Naowh Forever Discord.

### Fixed
- Professions no longer climbs in memory while you browse the Auction House, and redraws about 3x
  faster
- "AddOn blocked" when closing the profession window, disbanding or changing Buff Reminders in
  combat
- an error when a page redrew while you hovered a nameplate aura in combat
- Pasted profiles, packs and lists can't freeze or crash the game, and names in them show as plain
  text
- Shared Naowh Scores, the Aim Trainer board and Group XP only accept a player's own data
- Unexplored areas on the world map show their roads, towns and labels again, darkened, and the
  slider now sets how dark they are
- The Naowh Score card on the character panel no longer covers the Equipment Manager or Titles list
- Quick Attach on the Send Mail tab now attaches every stack of the type you pick (it stopped after
  two), and its menu counts stacks.
- Threat Meter: the window border no longer shows when Background Opacity is 0%.
- World map: right-clicking a zeppelin tower opens its second destination (QoL > Town Map Pins >
  Boats & Zeppelins).

## 0.5.24-beta

### Added
- Move Elements: Anchor on the selected element's tag. Click it, then click another element, and it
  follows that element from then on. Unanchor lets go.

### Changed
- Options window: the sidebar's Adventure, Combat and Utilities groups are back.

## 0.5.23-beta

### Added
- Move Elements: the selected element shows its X and Y on a small tag just outside it. Type a
  number and press Enter to move it there.
- World map: a zone exit arrow on the new road between Stonetalon Mountains and Skywatcher Plateau,
  above Thunder Bluff.

### Changed
- Unlock Mode is now called Move Elements.
- Move Elements has its own look: dark movers with a blue strip, a quieter grid, and a toolbar in
  the Naowh window style.
- Move Elements: elements can no longer be anchored to each other or to a screen edge. Anchored
  elements stay where they are.
- Profiles: a new layout in cards. The profile in use sits on top with Reset, Copy and Delete
  buttons and your other profiles under it with Use, the parts to share are a grid of switches
  showing what each holds, and Import is a paste box with an Import button.
- World map: zone exit arrows are longer and easier to see, and right-click no longer places a
  waypoint (QoL > Town Map Pins).
- World map: Unexplored Areas are darkened instead of greyed out, at 50% opacity by default (QoL >
  Interface).
- Quality of Life: six options have new names. Type DELETE For You (was Auto-Fill Delete
  Confirmation), Hide Red Error Text, Turn Off Tutorials, Hide Screen Captured Text, Accept Quests
  and Hand In Quests. Your settings are kept.
- Options window: the search box is now Search (Ctrl+F), a bar under the header that steps through
  every matching setting.
- Options window: the Reload UI / Close bar at the bottom is gone. Reload UI is in the header, close
  with the X or Escape. The sidebar is one list without the Adventure, Combat and Utilities titles.
- Move Elements: the tag under the selected element also has Center and Settings. Snapping, the cog
  menu and the hover animation are gone. Shift + arrow keys move 10 pixels.
- Move Elements: Restock, Pet Tracker, Durability, Talent Points and Camp Nearby move together as
  one Alerts group, and alerts showing at the same time stack upward instead of overlapping.
- QoL > Combat: Emote Detection is gone, and Auto Emotes is now Summon Emote, an /emote of your own
  when you start casting a summon.
- AddOns list: Naowh Forever is its own entry, with its modules under it, instead of sitting under
  NaowhUI.
- Smart Reminders is now its own addon that you switch on and off under Settings > Modules, like the
  other modules. Restart the game once after updating (a /reload is not enough) so it finds the new
  addon.

### Fixed
- Scrollbars in the settings window and the module windows follow the cursor when dragged, instead
  of jumping and moving the wrong way.
- Minimap: mailboxes show with Mailboxes & Spirit Healers on Minimap on, even when the world map's
  Mailboxes toggle is off.

## 0.5.22-beta

### Added
- Profiles: profile strings now carry your Forge macro Library and your saved talent builds, added
  next to yours on import.
- Unlock Mode: anchor an element to another one. Hover it, click Anchor under its name, click the
  element it goes beside and pick a side; it follows that element from then on. Click Anchored to
  let it go.
- Unlock Mode: Relative to Screen in an element's cog menu holds it to a screen edge, or two for a
  corner, so one profile fits every resolution.
- Unlock Mode: an element's cog menu types an anchored element's Offset X and Y, picks its Snap
  Target and centres it on the screen; dragged elements snap to the nearest one (Snap Elements in
  the toolbar turns it off).
- Dungeon Journal: the Excavation Site: Wetlands map shows where its bosses are.
- Dungeon Journal: Excavation Site: Wetlands lists its quests, and Highland Horror is on its map
  with the quest that needs him.
- Dungeon Journal: Shift-click a boss's ability to link it in chat.
- World map: Unexplored Areas shows the parts of a zone you haven't explored yet, greyed out (QoL >
  Interface).
- World map: boats and zeppelins, each with where it goes; click one to open that zone (QoL > Town
  Map Pins > Boats & Zeppelins).
- Minimap: mailboxes and spirit healers near you show on the minimap too (QoL > Town Map Pins).
- Flight Games: new Off choice under QoL > Travel hides the Flight Timer's Games button; "Nothing"
  is now called "Button only".
- XP Bar: pick the Incomplete Quests and Border colours under Colours.
- Dungeon map: bosses are placed on the maps of 16 more dungeons, Blackrock Depths to Uldaman.
- Dungeon map: City of Dalaran has a map of the Underbelly and the city, from Santiago Reyes's Atlas
  de Azeroth: Forever.
- Dungeon map: Upper Blackrock Spire has its Hall of Binding and Rookery and its Dragonspire Hall,
  the levels the game has no map of yet.
- Dungeon Journal: City of Dalaran lists all its bosses in kill order, its eight quests and tips for
  five of its bosses.

### Changed
- Profiles: the page is redone as cards, with Import and New Profile on top and Export on the page,
  part by part, so you can share only what you want.
- Profiles: Reset and Delete now act on the profile in use.
- Profiles: Import Profile also takes Forge macro, talent build and BiS list strings and hands each
  one to its own import.
- Training Planner: the test leveling builds are gone; the Builds tab lists the builds you save or
  import.
- The Level-Up Toast and the Aim Trainer are no longer in Unlock Mode: drag them where they are, and
  they stay there.
- Dungeon Journal: the trash has its own section under the bosses, in two columns.
- Dungeon Journal: the Excavation Site: Wetlands map is the updated one, with the entrance where it
  is now.
- The Naowh Forever logo in the options window sits tight in its corner, a little bigger, with the
  wordmark lined up to the emblem.
- Each module is now its own addon. Switching a module off disables it for every character after a
  reload, and it leaves the sidebar until you turn it back on under Settings > Modules.
- Dungeon Journal and BiS List switch on and off together, and Training Planner goes off with
  Professions.
- The mouse wheel now scrolls smoothly in the settings window, its sidebar and the module windows
  (Dungeon Journal, BiS List and the rest); the settings scrollbar is slim and hides when the page
  fits.
- The Dungeon Journal's dungeon map shows its bosses as a grid of portraits under the map and the
  picked boss's loot and abilities side by side, with Naowh's tip and its quests, so it fits without
  scrolling; quest bosses like Highland Horror are tagged QUEST and no longer numbered.
- The dungeon map's bosses are a list beside the map, with the same portraits as its pins and
  grouped by wing, and the boss page gets the full width under both.
- XP Bar: its border is black, like the rest of the UI.
- Dungeon map: with a map open from the Journal, picking another dungeon shows that dungeon's map.

### Fixed
- Profiles: Export Profile no longer does nothing when your profile has a setting at 0.
- Training Planner: the Train Now panel no longer shows at the hunter pet trainer, where Learn All
  gave a Lua error and taught the pet nothing.
- Dungeon Journal: every dungeon lists its full loot again, with items not in Forever yet tagged
  "Not in Forever yet", dungeons not open yet say so at the top, and Excavation Site, Hall of Thanes
  and Ruins of Lordaeron show drop chances.
- Dungeon Journal: clicking a boss on a dungeon map's second floor, on the world map, no longer
  jumps back to the first floor.
- Raid Reminders: the anchor config toolbar no longer gets covered by other unlock-mode elements
  (e.g. the Level Up toast) after login or /reload, so Exit Config is always reachable.
- Dungeon Journal: the Excavation Site waypoint leads to the meeting stone, where the road up to the
  entrance starts.
- Dungeon Journal: General Drakkisath lists General Drakkisath's Command, which starts in Lower
  Blackrock Spire.
- Escape closes the settings window again while the Top Bar preview is on screen.
- World map: Clickable Zone Exits shows green arrows on the roads out of each zone; click one to
  open the next zone, right-click for a waypoint to the road (QoL > Town Map Pins).
- World map: Spirit Healers pins show every graveyard's spirit healer (QoL > Town Map Pins).
- BiS List: clicking an item's name or icon selects it, not just the empty part of the row.
- Settings: Escape closes the window after a Top Bar preview drag that ended in combat.
- Minimap pins: they no longer keep updating after being switched off and back on while standing
  still, and cost less while you move.
- Pressing Escape on a confirmation now cancels it, so a Settings > Modules switch goes back to how
  it was.
- XP Bar: turning on Incomplete Quests no longer changes the colour of your rested XP.
- Professions: pressing K after viewing another player's profession link opens your own professions
  again, not theirs.
- Spelling and grammar across the addon: Dungeon Journal quest giver places (Darnassus,
  Stranglethorn Vale, Steamwheedle Port and more) and boss tips, "1 second" and "1 spell" instead of
  "1 seconds" and "1 spells", "an Ability Reminder", and Show Text Callout. A debuff sound's tooltip
  now says "stack increased" instead of a raw game value, and asking for crafts in an instance says
  instance chat, not party chat.
- Dungeon map: Shadowfang Keep's floors are numbered in the order you reach them, and Lower and
  Upper Blackrock Spire each show only their own floors.

## 0.5.21-beta

### Added
- Profiles: Export Profile and Import Profile share your whole setup as one string: every
  module's settings and positions, your macros, Smart Reminders, your BiS lists and the look
  (theme, font, window scale). Import shows what a string holds, lets you untick parts, and
  lands it as a new profile; your own profiles and BiS lists are never overwritten. They replace
  the Smart Reminders-only Share and Import buttons, and a Smart Reminders pack string pasted
  into Import still opens in the pack import.
- XP per Hour shows your total played time on the character, and each past level shows your played
  time when you reached it (Show Played at Ding).
- Compare Characters (off by default) on XP per Hour marks whether you're ahead of or behind your
  other characters at the same point, colors past levels green or red against them, and lists them
  in the tooltip.

### Changed
- Profiles: Match My Spec and Merge a Profile In are gone. Forever gives each class one spec, so
  picking a profile already is what Match My Spec did, and Merge was for Smart Reminders packs,
  which come back with that module.
- Naowh Score grades against Both by default: the best in the game and, in gold, the best for your
  level, now also on the character panel's score bar.
- XP per Hour and the XP Bar share one muted /played request.
- XP per Hour's tooltip only lists your characters (with Compare Characters on); the card already
  shows the rest.
- Character panel: the Naowh Score bar shows your level's goal as a gold tick only; hover it for the
  number.
- Stat Weights: every spec now has its own default weights for level 60, built for Forever's
  talents. Weights you changed yourself are kept.

### Fixed
- Bag Space: items marked as scrap no longer jump to the front; it shows the cheapest first, as
  before.
- Naowh's Forge: the macro editor shows one cursor, not two.
- Stat Weights now read hit, crit, haste, dodge and block on gear as the percent they give, and
  casters now value the hit and crit on their gear.
- Dungeon Journal: bosses no longer list Classic items that are not in Forever yet, which showed as
  "Item 10800" with a tooltip stuck on Retrieving item information; their cards say the loot arrives
  when Forever opens the dungeon.

## 0.5.20-beta

### Added
- Settings: click the dot beside a setting you changed to put it back to its default; hover it to
  see what the default is.
- Aim Trainer (QoL > Travel, on by default): a shooting game for flight paths. Click the other
  faction's races as they pop up, in Hexakill (six targets at once, the default), Gridshot (three)
  or Reflex (one at a time, shrinking away), for a score, accuracy, combo and reaction time, with
  your best kept for every character. A miss costs 50, so spam-clicking doesn't pay. Every round
  is 30 seconds with the same targets for everyone, so scores compare fairly on its Leaderboard:
  once you have a best and with Share My Scores on, your bests are swapped with the players you
  group with and your guild's, and the results card shows your rank. Open it with /nfaim or the
  Flight Timer's Games button, or pick it under Flight Games to open by itself when a flight
  starts; it closes when you land or enter combat. Move it in Unlock Mode.
- Flight Games (QoL > Travel, under the Flight Timer): one choice of what opens by itself when a
  flight starts, Nothing, the Quiz or the Aim Trainer (the default).
- Scrap Marker (QoL > Loot & Items, off by default): Alt-click an item in your bags, the game's
  or EllesmereUI's, to mark it as scrap, and again to unmark it. Marks count on every character,
  or on this one only (New Marks), and the next vendor sells your scrap, even items the game
  doesn't count as junk. At the Vendor can instead ask first, on a panel beside the vendor, or do
  nothing. Scrap shows an icon on its bag slot and a line on its tooltip. Your BiS and gear sets
  are protected, and quest items, keys and items with no sell price can't be marked.
  - Rules, each off by default, count gear your class can't wear and old grey and white gear as
    scrap too; the X on a rule's item keeps it.
  - The Scrap List (Open Scrap List on its settings page, or /nf scrap): every scrap item with
    what you carry and what it sells for, a search, an X to unmark, Account or Character on each
    mark, drop an item on it to mark it, Clear All, and Export and Import to share a list.
  - Bag Space puts your scrap first and shows the slots it will free, like +3.
- Training Planner: a waypoint to your nearest class trainer, from Waypoint to nearest trainer at
  the top of the planner, the Waypoint button on the level-up toast, or /nf trainer. With TomTom
  loaded, it uses TomTom's arrow.
- Naowh's Forge: To Library in the editor saves the macro to the Library under your class, for every
  character of that class. Your Library macros show as YOURS, with Add, Open in Editor and Remove;
  saving one again under the same name replaces it.
- Dungeon Journal: Scarlet Monastery's Library, Armory and Cathedral maps show where their bosses
  stand.
- Dungeon Journal: the quest tracker is now the Dungeon Quest Tracker. Click its title for its
  settings. A dropdown under it shows any dungeon with quests, each level range in the quest log's
  colours for your level. It widens to show quest names in full, grows to 70% of the screen before
  it scrolls, has Share All, and a cog for its settings.
- Dungeon Journal: Open Tracker in Dungeons (on by default, Dungeon Journal > Quest Tracker) opens
  the quest tracker when you enter a dungeon with quests for you. Close it and it stays closed until
  you leave that dungeon.
- Dungeon Journal: Show Outside Dungeons (off by default, Dungeon Journal > Quest Tracker) opens the
  quest tracker out in the world after a loading screen, on the dungeon your quests are for.
- Dungeon Journal: Hide the Game's Quest Tracker (off by default, Dungeon Journal > Quest Tracker)
  fades out the game's quest tracker while yours is open in a dungeon.
- Discovery: the Cozy Sleeping Bag, its hidden quest chain step by step (from level 14). A Sleeping
  Bag tab in the Discovery window lists every step: what to click, where, how to get there (the
  jumps and climbs), and a waypoint; the optional campfire too. Two steps with the same name show
  their zone.
- Discovery: a Sleeping Bag tracker (off by default, Discovery > Sleeping Bag) shows the steps, the
  next one with its way there, until you have the bag; its X switches it off.
- Discovery: Sleeping Bag map pins (off by default): the bag's icon with the step's number on every
  step still to do, the next one in full; click one for a waypoint.
- Discovery: the third library reward, Greater Friend of the Library at 25 books (level 30):
  Truthseeker's Bow, Crest of Elucidation or Researcher's Night Light. The book count is what
  players report so far.
- Discovery: the progress at the top of its window is a road, like the Training Planner's: a stripe
  per book (blue once handed in), YOU where you are, and a dot at 10, 20 and 25 books with the
  rewards under each (hover one for the item).
- Dungeon map: Ruins of Lordaeron, Hall of Thanes and the Excavation Site have a map, from Santiago
  Reyes's Atlas de Azeroth: Forever (credited on the map and in Credits), until the game has art of
  its own for them. Ruins of Lordaeron's and Hall of Thanes's bosses stand on theirs; the Excavation
  Site's are still to be placed.
- Settings > RESTEDXP (shown when RestedXP Guides is installed, off by default): Add Themes to
  RestedXP puts NaowhUI, the Naowh themes and Naowh (current), which follows your own theme, in
  RestedXP's theme list. Pick one with RestedXP Theme or in RestedXP's own settings.
- With a Naowh theme on, RestedXP's window takes Naowh's look: Panels-colored surfaces with a 1px
  black frame, thin rules between quest rows, and the theme's color in the title bar and footer.
- RestedXP Arrow colors RestedXP's waypoint arrow with your Accent, or swaps it for Naowh's own
  arrow with its shape, glow, size and text gap. Show Arrow Text hides the text under it.
- Use Addon Font and Use Theme Text Color can be turned off to keep RestedXP's own font and text
  color.
- Dungeon Journal: click a boss on the dungeon map for its own page beside the world map: its level
  and type, Naowh's tip with a button to share it, the quests that need it, its abilities and its
  loot.
- Professions: drag the profession window to move it; it opens there from then on.
- Campfire has a Simple style (AuraBuffs > Settings > Campfire > Style): a slim bar in the house
  panel look listing every camp bonus with its amount and a time line, the same size in every state,
  with a fuller tooltip and a mouse-editable preview. It reads Camp Benefits in any client language.
- XP per Hour shows the level you're on as it runs, under Level History.
- Bag Space has a Background choice (Card, Soft or None) and a live preview on its settings card
  with Bags, Low and Full views.
- A welcome window on your first login with how to get started and a link to our Discord; see it
  again with /nf welcome or QoL > System > Welcome.
- Settings > COLORS: a Classic theme in the Theme dropdown, with dark brown panels, parchment text
  and an antique gold accent.
- Action Bars Save Current Bars opens a set builder: leave out slots or whole bars, choose whether
  keybinds come along and which macros, then name the set.
- Action Bars Import shows a preview first (new macros marked NEW, spells you haven't learned yet
  with their level), and Fill In As You Learn (off by default) places those spells once you learn
  them.

### Changed
- Dungeon Journal: Scarlet Monastery is its four wings, each a dungeon of its own: Scarlet
  Monastery - Graveyard (26-36), Library (29-39), Armory (32-42) and Cathedral (35-45), with its
  bosses, loot, quests and floor of the map. Inside, the subzone you stand in says which wing
  you are in; where it cannot tell, the Graveyard comes first.
- QoL has a Character tab: Character Panel, Slot Marks and Naowh Score moved there from the BiS
  List's settings, and Supporter Badges from Interface. The BiS List's page keeps what is about
  your BiS.
- The Naowh Character Panel and Bag Marks are now on by default. With EllesmereUI's character
  panel in use, you're asked once at login which one you want.
- Loot Feed: Spacing goes down to -1, now the default, so neighbouring lines share one border
  instead of two. Its coins line up on every line, and it is the first card on QoL > Loot &
  Items. Edit it right in its preview: drag its right edge for width and a line's bottom for
  height, the wheel for text size (Shift: spacing, Ctrl: lines), click a line's value or bag
  count to show or hide it, and right-click a line for what it shows.
- QoL's Leveling & Travel tab is two again: XP (XP Bar, XP per Hour, Group XP) and Travel
  (Flight Timer, Flight Games, Quiz, Aim Trainer).
- Quiz: Quiz While Flying is gone, replaced by Flight Games, where the Aim Trainer now opens on
  flights by default. If you had turned it off, Flight Games is set to Nothing; the Quiz keeps
  its campfire toggle.
- XP Bar: click a text on the preview, or an empty spot around the bar, to pick what it shows,
  as before the settings rebuild. The eleven text dropdowns under it are gone; search still
  finds each spot and opens the card.
- Flight Timer: a new look. A card with where you left and where you land, the time left in
  blue, and a slim track you ride along on your faction's flight mount, with each stop marked on
  it (filled once passed) and the next stop and its time under it. Land Early is now a Land
  button beside Games.
- Character Panel: the grey Legendary badge for players without a badge is gone; only your own
  badge shows.
- Naowh's Forge: the Smart Macros tab no longer has the Food & Drink Bar panel (it stays under
  Macros settings); that side now explains how Smart Macros keep themselves up to date.
- Naowh's Forge: a class with nothing in the Library shows just its name, without the import message
  and button.
- Dungeon Journal: the Forever mark shows on the dungeon only; its bosses and items no longer carry
  it (their tooltips still say they're new in Forever).
- Dungeon Journal: its settings are three tabs: Journal (what it lists, its window, the Open Dungeon
  Journal key), Quest Tracker (the tracker and sharing quests) and Map (beside the world map, and
  Boss Loot at Cursor's key).
- Dungeon Journal: the Journal, the Dungeon Quest Tracker and the map each have their own Window
  Opacity. They start at the opacity you had set for them all.
- Dungeon Journal: a quest row starts with its waypoint pin and its quest mark (! or ?) in place of
  its level. The ! is yellow when you can take the quest, grey when other quests come first and red
  when it is too high for you; hover the mark for what it means.
- Dungeon Journal: a quest that needs another one first says Requires: (the quest) under its name
  and Prerequisite as its state, in place of Do first. A quest on its own shows no chain icon.
- Dungeon Journal: a quest's card shows only when you hover its name, on the tracker, the dungeon's
  page and beside the map.
- Dungeon Journal: the group count on quest rows shows only while you are in a group.
- Dungeon Journal: Link in Chat on a quest's menu sends to party chat in a group, or into your chat
  box while it is open. Out of a group with the chat box closed, it is greyed out.
- Discovery: its window has two tabs, Library Books (every book for your faction, a tick on those
  handed in, in place of To Find and All Books) and Sleeping Bag.
- Discovery: its settings are two tabs, Library Books and Sleeping Bag, and each tracker has its own
  opacity apart from the Discovery window's (they start at the one you had set).
- Discovery: the Library Books tracker has the Dungeon Quest Tracker's look: the progress bar and
  zone dropdown under its title, a waypoint pin in front of each book (a tick once handed in), a
  book's level in its tooltip, and a cog for its settings. Drag it by its title or body (Unlock Mode
  still moves it too).
- BiS List: three picks that were missing are back (Guerrilla's Jagged Mace, Rotmender's Garb,
  Precision Bow).
- Quality of Life > Loot & Items > Auto-Fill Delete Confirmation: the confirmation box stays visible
  with DELETE already typed in, instead of being hidden.
- Dungeon Journal: the boss you pick on a dungeon map gets a glowing gold ring, in your theme's
  Accent if you picked one.
- Dungeon Journal: the Journal beside the world map uses its full width while everything fits.
- Dungeon Journal: a boss's loot at the mouse opens only on the maximised world map.
- Naowh Forever's windows, trackers and panels can be dragged up to 90% off the left, right and
  bottom of the screen; the title bar always stays reachable.
- The Camp Nearby alert is a compact bar in the same look: the fire, "Camp Nearby Â· sit to refresh"
  and the time left inline, fading in and out (Fade and Alert Size in AuraBuffs > Campfire).
  Right-click hides it until you leave the campfire.
- Campfire settings only show the rows for the style you picked (Round or Simple), with shorter
  help.
- XP per Hour sits on a small card: the rate and "xp/hr" on one line, Ding and session time on a
  footer line, and a thin level progress line with your rested XP just ahead of it. The rate glows
  blue while you earn, with a green or red arrow as it climbs or falls, Ding turns blue in the last
  10 minutes, and it greys out while paused. Pause and Reset show as small icons on hover, it says
  "no XP yet" until you earn some, and its tooltip has your level, rested XP and the session
  numbers.
- XP per Hour's Background is a choice of Card, Soft (a soft dark fade with no edge) or None; if you
  had it off you now get Soft, and Outlined Text works with every background (QoL > XP).
- Bag Space sits on a clean card in the house colors: free slots and a Stack button in a slim
  header, a small clock on outlevelled food, the game's quest "!" on quest items, and small muted
  prices with coin icons, each in its largest coin (QoL > Loot & Items > Bag Space).
- Unlock Mode no longer shows a position box over the display you select, so nothing covers it while
  you place it.
- Action Bars sets now save your keybinds and every macro with your bars, and Restore is now Import:
  import a set on an alt to get its bars, keybinds and missing macros, never copying a macro twice.

### Fixed
- Naowh Score: no more Lua error after seeing more than 300 players, like in a busy city.
- Hovering items and players no longer fills BugSack with "secret value" errors on Forever: the
  upgrade line and bag arrows wait while the game keeps your stats hidden, Naowh Score copes with
  a player it can no longer read, and the supporter plate and ID lines stop hooking the game's
  tooltip, which was reported breaking its own player-name colours.
- Naowh's Forge: no more Lua error when a macro line is just a "/" with no command yet.
- Character panel: while the game keeps your stats hidden (combat, encounters), your spec's stats
  still show where the game allows it (primary stats, armor, healing, each school's spell damage,
  crit, dodge, block), a dash for the rest, instead of a Lua error.
- Stat Weights: upgrade lines and bag arrows keep working while your stats are hidden, worked out
  against your stats from just before, until your gear or level changes.
- Loot Feed: looting coins again while the Coins line is still up adds to it instead of throwing
  a Lua error, and the loot after that line fades shows up again.
- Auto-Fill Delete Confirmation: Yes can be clicked again once DELETE is filled in for you;
  it stayed greyed out on Forever.
- Settings: a module's window opened from /nf (Open Dungeon Journal, or the small window button
  beside a module) brings /nf back when you close it the first time too, not only from the
  second time on.
- Blessings: a class button clears as soon as your blessing lands, instead of staying red for about
  a second.
- Macros: the macro editor shows a blinking cursor again while you type.
- Quality of Life > Cursor > Mouse Ring: with Cast Sweep on, a hard cast no longer shows its GCD
  sweep first and then restarts as the cast sweep, or sweeps the rest of the GCD again after the
  cast.
- XP per Hour's level history is kept per character, so characters with the same first name no
  longer share it.
- Bag Space gives Poor items the same black edge as Common ones; only Uncommon and better show their
  color.

## 0.5.19-beta

### Added
- Naowh's Forge (/nfmacros, the Macros page, or its minimap and top bar button): a window for
  your macros. My Macros lists your account and character macros and your pack's; the editor
  colours a macro as you type it, in a code font (JetBrains Mono), shows how many of the
  game's 255 bytes it uses, numbers its lines, marks the ones that
  will not work with what was meant (/castsequnce: did you mean /castsequence?), and beside it
  Explain says what each line does in plain words. Build conditions with Conditions, insert
  commands from Commands, pick an icon (star your favourites), Shorten a macro, and drag its
  icon to a bar. Smart Macros shows the macros the module keeps up to date with what each will
  use right now; the Library holds Naowh's macros once you import them. Export and Import share
  macros as a string.
- /nf settings, rebuilt on the Dungeon Journal's look. Every feature is a card with its
  switch and a line saying how it is set; open, its settings sit in groups, two to a line. A
  setting that is off says what it needs, a dot marks what you changed, and each card can reset
  itself. Search finds a setting by its name and opens its card.
- Every module has one Settings page, with a card on top saying where you stand. What is not a
  setting moved to the module's own window: Discovery's books (/nfdiscovery), Macros
  (/nfmacros), Action Bars (/nfbars), AuraBuffs' consumables and debuff sounds (/nfbuffs), Smart
  Reminders' presets and boss pages (/nfreminders), Gear Sets, Stat Weights, and the Dungeon
  Journal's recent kills and loot (the skull on its title bar). Opening a window from /nf closes
  /nf, and Back to Settings in its title brings you back.
- Live previews on the settings cards of everything you see on screen: the Top Bar, Crosshair,
  Mouse Ring, Focus Cast Bar, Loot Feed, XP Bar, XP per Hour, Group XP, Flight Timer, the BiS
  drop alert, the threat meter, swing timer bars, buff and camp reminders, low health, the
  gear and trinket bars, the craft timer, tracking and food bars, and Smart Reminders' displays,
  each in the moments you see it, following every setting as you change it. A moment that only
  exists with a setting on (faded, in combat, idle...) only has its tab while that is on.
- Top Bar: arrange its buttons right in the preview: drag to move, x to remove, + to add.
- Blessings: edit the bar right in its preview: right-click a class for its blessing, click the
  aura for yours, x hides the aura or Righteous Fury button and + brings it back, the wheel
  sizes the buttons (Shift: spacing) and the gap after the aura drags wider or narrower.
- Threat Meter: edit it right in its preview: drag the corner to resize, click the name or the
  status line to change them, the wheel sets row height (Shift: spacing, Ctrl: text size) and
  right-click a row for what it shows.
- Naowh Forever in the game menu (Esc), by the other addons' buttons. Game Menu Button on the
  Settings page turns it off.
- Profile strings now carry every module's settings and Unlock Mode positions, not only Smart
  Reminders'.
- The sidebar dims the modules you have off and lists them last in their group; a module with a
  window of its own opens it from the icon on its row.
- Discovery: a waypoint also opens the world map on it (Open the Map), a waypoint to your
  librarian, and new settings: tracker scale, map pin size and hand-in pin, and the nearby
  alert's ping and chat line each on their own.
- Auto Combat Logging: log raids and dungeons each Ask Once, Always or Never, keep logging when
  you leave, a chat line when it starts or stops, and the Advanced Logging prompt as a choice.
- Blessings: one Settings page with a live preview of the bar, in a group and out of range. The
  assignments grid, Auto-Assign and the preset moved to Blessings' own window: /nfbless, Open
  Blessings on its settings page, or Assignments on a class button's right-click menu.
- Quality of Life in 7 tabs instead of 13: Interface, Cursor, Combat, Questing & Group, Loot &
  Items, Leveling & Travel and System. Mouse Ring is one card, the two copy shortcuts are one,
  the auction price line sits with Auction Prices, Trainer moved to Training Planner and Naowh
  Score to BiS List.
- Credits page with the team, the people we thank, and the data and libraries Naowh Forever is
  built on; Discord, Website and GitHub links in the sidebar.
- Patch Notes as cards, the newest open, each change with where it lives.
- A smaller search box by Unlock Mode, the Dungeon Journal's boxed tabs, and no more
  UNTESTED / READY tags or "Preview build" notes. Minimap Icons moved to Settings.
- QoL > Interface, Town Map Pins: Mailboxes, every mailbox on the world map, in towns and out in
  the world, even with Town Pins Only in Capitals on (off until you turn it on). Positions come
  from Wowhead's WoW Forever database.
- QoL > Questing: On-Screen Buttons (off by default) puts Invite and Disband on your screen,
  stacked or side by side, to move in Unlock Mode. Invite invites your target, in combat
  too; Disband removes everyone (group leader, out of combat).
- QoL > Loot & Items: Auto-Replace Enchants (off by default) says yes for you when an enchant
  would replace the one already on an item. Hold Shift to be asked.
- Unlock Mode: right-click anything on screen for Element Options, which leaves Unlock Mode and
  opens that element's settings in /nf, its section already open.
- Swing Timer: Color by Seal for paladins (Swing Timer > Bars, under Seals). The melee bars take
  the color of the seal you have up, one color per seal, Seal of Martyrdom included. In combat
  that is the last seal you cast until a Judgement uses it up or it runs out; out of combat it
  is read from your buffs. Off by default.
- Macros > Consumables: Food & Drink Bar (off by default), two buttons for the best food and the
  best drink in your bags, conjured first. Click to eat or drink; move it in Unlock Mode.
- Training Planner (/nftraining, or its minimap and top bar button): a window with what your
  next trainer visit costs against your gold, a road to 60 with a dot for every level that
  brings spells (click one to see them), what is left to pay up to 60, the spells you can
  train now as cards, and what waits on a rank, a talent or a later level. Each new rank says
  how much stronger it is than the one before (+100%, and on its tooltip Fire damage 16-24 to
  33-47). Search any spell of your class, and Show Learned lists what you know. Mini swaps
  the window for a small bar with your next visit and your gold, to leave up while you level.
  Right-click a spell to skip it or all its ranks, shift-click to link it. A toast on
  level-up says how many spells wait and what they cost, and beside your class trainer a
  panel ticks what you can learn with Learn All I Can Afford, then puts the new ranks on your
  bars. Opening the trainer updates prices to what it asks, reputation discounts included.
  Off by default.
- Training Planner: a Builds tab with a leveling talent build for every class, levels 10 to 30,
  from Mobalytics' WoW Forever guides (Warrior has Arms/Fury to 15, then Protection). Pick a
  class and a build to see it level by level, which points you have already taken and which
  one comes next.
  New Build opens your class's talent tree: click talents in the order you take them and the
  build fills in level by level, keeping to the tree's rules (Undo, Clear, right-click to give
  a point back). Copy makes an editable copy of a built-in build. Export gives any build as text
  to share, Import a Build adds one someone shared with you, and Save My Talents keeps the
  talents you have now as a build of your own.
- Training Planner: Learn Next Points on your class's build spends your free talent points on it,
  in its order, and Follow This Build does it for you each time you get a new point (out of
  combat; after a fight if you level in one). Off until you pick a build to follow.
- Training Planner: its window now matches the Dungeon Journal: the Naowh title bar with an
  opacity slider (also in its settings), Spells and Builds as a switch under it, the search and
  each tab's buttons beside it, and its strips and lists on cards. Its settings page opens with
  a card on what you can train now, and has the Mini Bar switch.
- Naowh Score (QoL > Naowh Score, on by default): one number for a character's gear, on the
  item level scale (26.4 means gear worth a set of level 26 epics), fitted to Forever's own
  items: each item counts as the level of an epic with the same stats, weighted by how many
  stats its slot carries. It is coloured by how close it is to the best, on a smooth ramp from
  grey through greens, blues and purples to orange; Grade Against picks the best in the game,
  the best for the player's level, or Both (the score against the game's best, then in gold
  "44% of level 20"). Under the BiS List's paperdoll, a score card shows yours with your BiS or
  as you are now and the gain, over a bar filled to what you wear and dimmer on to your BiS,
  with your level's goal in gold under Both. Your score is shared with your group and guild
  as it changes, so other Naowh Forever players see it at once, at any distance. Player
  tooltips show anyone's: a Naowh Forever player's as they share it, anyone else's read from
  their gear as the game's Inspect does (within inspect range, out of combat). In the
  background, Scan Your Group and Scan Players Nearby (your target, focus and mouseover, and
  everyone whose nameplate shows) read theirs, so the scores are ready before you hover.
- Character Panel (BiS List > Character Panel, off by default): your character panel in the BiS
  List's look: our dark frame and title, the model on the dark panel, the stats as plain rows
  under accent titles, the tabs and buttons in our colours, and your Naowh Score big under your
  level with a bar of how close it is to the best (hover it for your score with your BiS, click
  it for the BiS List). Its stats show your spec's first: the stats your spec weighs, in a fixed
  order (Agility, Strength, Attack Power, Crit, Hit, Haste, then Stamina and Armor), each with
  a bar for what it is worth against your spec's yardstick (VS AGI) and your total now; hover a
  row for what the stat is worth and what it does, or click the scales by its title to change
  the weights. A switch at the bottom gives the game's All Stats. A BiS List
  button replaces the model's zoom buttons (drag the model to turn it, scroll to zoom). Your
  supporter badge sits big in its top corner; without one, the Legendary badge in grey: click
  it for what it is and where it shows, with more on Naowh's Discord.
  Its slots: each item's level in
  its corner, its edge in its quality's colour,
  Forever's mark on what is new in Forever, your BiS's star, and a dot where a better enchant
  waits. With EllesmereUI, turning it on swaps EllesmereUI's character panel for
  this one, and turning it off swaps them back (after a reload). Rather keep the game's own
  panel (or EllesmereUI's)? Slot Marks, on the same page and on by default, puts just the
  marks on its slots.
- Bag Marks (BiS List > Settings, off by default): the BiS List's slot marks on the items in
  your bags: each piece of gear's item level, your BiS's star, Forever's mark on what is new in
  Forever, and the green upgrade arrow on gear better than what you wear by your spec's stat
  weights (BiS or not). Works in the game's bags and in EllesmereUI's bags, reagent bag and bank, where
  ours replace its item level and leave room for its BoE text and Pawn's upgrade arrow.
- Stat Weights (BiS List > Stat Weights, and the scales in the BiS List's title bar): what each
  stat is worth to your spec, which it reads from your talents, only the stats it uses, each a
  bar and a number you can type over, with your BiS list's best upgrades by them right under
  them. Reset, Export to copy your weights, and Import for someone's or a WoWSims EP export.
  Upgrades on Tooltips (off by default): gear that is an upgrade for your spec says by how much
  ("+9% upgrade"). The BiS List's upgrades and enchants
  use your weights.
- Top Bar: Faded Opacity (with Show On Mouseover) sets how visible the bar and the FPS / MS
  readout stay while the mouse is away. 0% by default, invisible as before.
- Blessings: in combat each click on a class button blesses the next member of that class who
  needed it when the fight began, then round again, instead of the same player every time. It
  follows them by name, so the raid being rearranged mid-fight does not send it to someone
  else, skips anyone who has left, and a Greater Blessing is cast once for the class.
- Blessings: class buttons show what is needed at a glance: red when someone in range is
  missing the class blessing, yellow when it is only running out, blue when only players with
  their own blessing need theirs.
- Blessings: Auto-Assign on the Assignments page spreads blessings and auras across every
  paladin in the group running Naowh Forever, the most useful blessing for each class first,
  with Salvation first for casters and rogues in a raid and never for warriors, druids or
  paladins. The
  group leader or an assistant can run it for everyone; a paladin on their own for themselves.
- Blessings: a preset on the Assignments page saves the whole group's plan and loads it again
  later for the paladins who are there.
- Blessings: a paladin's own blessings for single players are shared with the group, and show
  in the tooltip of that class on the Assignments page.
- Group Tools on QoL > Questing: a Disband Group button for leaders and an Invite Player button where you type the name.
- Dungeon Journal: every dungeon's bosses in the order you meet them, what each one drops
  and how often (Forever's new items included; a boss whose loot is not known yet says so),
  its optional bosses and loot chests, then what its trash drops (a card says how many items
  your filters hide), with your BiS marked and how many of them each boss has. Upgrade
  marks what beats your gear (a higher pick on your BiS list, or a higher item level you can
  wear), and right-click puts an item on your BiS list or gives its Wowhead link (a boss's
  too). Your quests for the
  dungeon are listed too, with a waypoint each, and right-click one to share it with your
  party. The group icon counts who else is on each quest; click it on one you don't have
  and a member running Naowh Forever shares it with you (Quest Share Requests, in the
  Journal's settings). Tracker opens a dungeon's quests in a small window to keep on
  screen while you run it, and Map opens its map: the bosses where they stand, with their
  portraits and kill order, and the entrance. Under it, the bosses in kill order with this
  run's progress (killed ones ticked and dimmed), the ones your quests need, your BiS there,
  and the loot of the boss you click; fold that away for the map alone, and pin the map to
  keep it open. Opening the world map (M) puts the Journal away, and M again brings it back. Inside a dungeon its map fills the world map (M), right-click for its zone,
  and the game's quest log beside it folds away so the Journal sits against the map (back as
  you had it once you leave). Each dungeon says whose ground its entrance is on, and the pin
  by its name points you there. Open the world map inside a dungeon and it sits beside the map; browse any
  dungeon in its own window with /nfjournal (or /nfdj) or its own key (Open Dungeon Journal, in
  its settings or Key Bindings), or bind Boss Loot at Cursor to see
  what the boss you hover drops. Search every dungeon for an item or boss, or list only
  the BiS you are still missing, or only your upgrades. The switch beside the search
  lists the dungeons on Alliance or Horde ground, or both. Loot your class can't use is hidden, and nearly every
  boss has a tip from Naowh, to read on hover and share in chat. A skull on each boss
  counts how many times this character has killed it; click it for each kill, who was in
  your group (tanks, healers, then damage, in class colours), everything that dropped, who
  won it and everyone's rolls. The Dungeon Journal page lists your latest kills and loot,
  and where. The three raids
  announced for Forever are listed too (Onyxia's Lair, The Barrow Deeps and Hyjal Summit),
  with their bosses and entrances; their loot fills in once it is known. Off by default:
  turn it on in the Dungeon Journal page.
- Dungeon Journal: Reputation and PvP tabs beside Dungeons & Raids. Reputation lists each
  faction with your standing, and its page shows every reward by the standing it needs,
  with its price, your BiS marked and how far you are from the next standing. Dungeons
  link to the factions earned in them, and back. PvP shows your rank this season, how far
  to the next one, this week's cap and what every rank gives, then the battleground
  factions and their rewards. Search finds faction rewards too. Your side's cities are
  listed with their Runecloth hand-ins, and so are the Azeroth Commerce Authority and
  Durotar Supply and Logistics, new in WoW Forever. Dungeons & Raids,
  Reputation and PvP are tabs over the list. Recipes are listed only for your professions
  (My Professions Only, in Filters), the ones you know are marked, and they fold under each
  standing's gear; Show Cosmetic Items, in Filters, hides cosmetics. A pin on a faction's page
  sets a waypoint to its quartermaster. Each faction's page shows what your
  unlocked rewards would cost and the quests that raise it: yours
  in your log, and its repeatable hand-ins (Scourgestones, Timbermaw feathers, Thorium
  Brotherhood's cores and more), listed like dungeon quests: who takes each and where, with a
  waypoint, how many your bags hold and where to get the items. A locked reward says how much
  reputation it still needs. Dungeon pages show
  your standing with the factions earned there, and the PvP rank has a track with this
  week's cap. Click a page's BiS count to open your BiS list. The Journal's footer shows the
  game build its data is from. Turn on Factions Beside the Map (in the Journal's settings) and
  the world map (M) shows, in a zone or a battleground, the factions earned there beside it. Once
  you have opened your side's PvP rank vendor, a pin on the rank's page shows where it is.
- Top Bar: hover the clock to see your saved instances, boss progress and when each resets;
  `/nf lockouts` lists them in chat.
- Campfire: Ctrl-click the Camp Nearby alert to dismiss it until you leave that campfire.
- Action Bars (new, under Utilities): save every action bar slot as a named set and restore it later,
  out of combat. Sets are shared by your class on the account; Test Restore lists what would not
  come back. Options to restore the highest rank, recreate deleted macros and save on logout
  (all off by default). Also `/nf bars save|restore|test|delete <name>` and `/nf bars list`.
- Top Bar: Friends and Guild can each be switched off in Top Bar > Buttons (both on by default).
- Top Bar: Show On Mouseover keeps the bar and its FPS / MS readout invisible until you hover
  them (Top Bar > Bar, off by default).
- QoL > Questing: Skip Modifier picks the key you hold to skip quest automation (Alt, Ctrl or
  Shift; Alt by default).
- XP Bar: Ctrl + right-click the bar to reset the session time and XP/Hour. Without Ctrl,
  clicks and camera drags go through the bar.
- Professions: Shift-Click Searches AH (off by default). While the auction house is open,
  Shift-click a recipe or a reagent and the search for the item runs straight away; while
  you type in chat, it still links it.
- Settings: six color chips beside the Theme dropdown preview the selected theme's colors before you reload.
- Professions: Buy at Vendor (Buying and Selling, off by default). At a merchant, "- [1] +
  Buy" under the chosen recipe's reagents buys every checked reagent the merchant sells for
  that many crafts in one click, such as Coarse Thread or Weak Flux. The total shows beside
  it, red when you cannot pay; hover Buy for each reagent. Buy All (x) beside it buys only
  what your bags lack for x crafts, x being the orange count next to the recipe, so Create
  All can then make them all. Buy Materials is now called Buy on AH.
- Professions: Create All stops at what your bags have room for, with "Bags: room for 14 of
  20" in red under the recipe when that is fewer than your reagents allow. Items that stack,
  such as bandages or potions, need far fewer slots than swords or armour, and stacks you
  already carry count; profession bags and the reagent bag count for what they take. Slots
  freed as the batch uses up reagent stacks count too, craft by craft.
- Professions: favourite recipes. Click the star before a recipe's name, or right-click it
  in the list; favourites get a small star in the list, and Favorites at the top of the
  Filter menu shows only them. Favourites set in Blizzard's window count too. Recipes you
  have not learned can be favourites as well.
- Professions: Shopping List (Buying and Selling, off by default). "- [1] + Add to List"
  under a recipe's reagents puts the materials Buy on AH would buy for that many crafts on
  a list, from anywhere. At the auction house the list shows beside it, with what it is
  for: Check Prices looks each material up and marks in red any well above your last scan
  or short on supply. Buy All then goes through the list: each material shows its final
  price and is bought when you click Confirm. Bought materials leave the list.
- Professions: Train Favorites (Recipe Window, off by default). A trainer who teaches a
  favourite you can learn now lists them beside their window, with the cost, to Learn one
  or Learn All.
- Professions: Search Favorites AH (Buying and Selling, off by default). At the auction
  house, the patterns, plans and manuals of your favourites are listed beside it with their
  price at your last Scan Prices, cheapest first. Buy finds the cheapest listing and asks
  "Buyout auction for:" with the live price, as the auction house does; only Accept buys it.
- Professions: the Filter menu has Bind on Equip and Bind on Pickup, showing only recipes
  whose item binds that way (either way with both ticked), unlearned recipes included.
  Items that do not bind at all, as much crafted gear on the beta, count as Bind on Equip.
- Professions: Total Craft Timer (Recipe Window, off by default). Crafting several at once
  (Create All, or Create with a count) shows one bar for the whole batch, drawn like the
  Flight Timer: the recipe and its icon, how many are done and the time left on all of them.
  The cast bar that fills for every single craft is hidden meanwhile. It sits where the
  Flight Timer is; move it in Unlock Mode as the Flight Timer. It ends when the batch is
  done, interrupted or stopped.
- Professions: Craft Orders (Recipe Window, off by default). Another player's profession
  link opens in Naowh's profession window, to order crafts from them. Choose a recipe, set
  how many crafts, tick the materials you bring (or type how many of each), and click Add to
  Order. The order on the right lists every craft with a tip you can change; Ask sends the
  crafter one message per craft with the amount, your materials and the tip: in party chat,
  starting with their name, when they are in your party, else as a whisper. Invite, at the
  top of the order, asks them into your group first. Under the reagents: the crafter's
  materials and the suggested tip, which pays back their materials plus a share of the
  items' value (10% by default, set with Suggested Tip), rounded, at least 1s; prices need
  an auction house scan.
- Dungeon Journal: Share on the quest tracker shares your quests for its dungeon with your
  group. Quests that cannot be shared are skipped. They go out one at a time, each once your
  group has answered the last, so nobody is too busy for the next; one someone was busy for
  is shared again at the end. Click the tracker's title to open the Journal's settings.
- Dungeon Journal: Accept Shared Dungeon Quests (off by default, in the Journal's settings)
  accepts a dungeon quest a group member shares with you as soon as it opens. Hold the Skip
  Modifier to look at one first.
- Threat Meter: Status Line (Layout) moves the line with your distance to pulling aggro and
  the entry count from under the bars to the top, between the title bar and the bars.
  Bottom by default.
- Threat Meter: Apply Theme to Your Bar (Colours, off by default) colors your bar in a darker shade of your theme's Accent instead of the color picked there. The tank and pull aggro colors are unchanged.
- Swing Timer: Apply Theme to Bar Colours (Colours, off by default) colors the main hand bar with your theme's Accent, the off hand bar with its lighter Accent and the ranged bar with a deeper shade of it, instead of the colors picked there.
- BiS List: its own window, in the Dungeon Journal's look. On the left your spec, your list
  and your character wearing your whole BiS, or what you wear now with each slot's BiS tried
  on as you hover it: drag to turn it, scroll to zoom. The slots are laid out as the game's
  character frame, each BiS in its quality's edge with a check once it is yours, and under
  them what your BiS gets you over what you wear: average item level and the stats it adds. On the right how many of
  your BiS are yours, then where to run next (which slots each place is for; a click opens
  the dungeon in the Journal, or out in the world puts a waypoint on who drops or sells your
  BiS there and shows it on your map, and the BiS List comes back when you
  close them), then a row per slot: its BiS, where it
  drops (a weapon says what it is), the level it needs while above yours, and its backups,
  opened under it. A wand on a slot shows the best enchant for your spec on what you wear
  there, for that item's level (no endgame enchants on a level 19 sword), and what is on it
  now; a click asks for it in Trade chat, or copies the message. A Quests page lists the
  quests that reward a pick you do not have yet, by the zone they start in, as the Dungeon
  Journal lists its own: what to do first, the level it needs, its chain, a waypoint, and the
  picks it gives under it. All, To get, In bag or To enchant filters the list. Click a slot to change its picks
  beside the window, where the ranking shows its own order. Import and Export are on the
  title bar, and the footer says when your spec's rankings were last updated.
  Open it with `/nfbis`, its own key, or the BiS stat in the Journal.

### Changed
- Training Planner: the Builds tab is laid out as the Dungeon Journal is, the class's builds in a
  list down the left and the one you pick beside it, with its buttons (Learn Next Points, Follow
  This Build, Edit or Copy, Export, Delete) over it. Its lists (a build level by level, the spells
  waiting on a rank, talent or later level, and the later levels) are one continuous list, every
  other row faintly banded, instead of a box round each row. In the talent tree each talent's
  ranks sit under it instead of over its corner.
- Top Bar settings moved from their own sidebar page to the top of QoL > General, with a Top Bar switch in place of the page's Enable switch. /nf still opens on them.
- Supporter badges: on a player's tooltip the badge is a plate of its own over the top, the
  badge and title in the tier's colour, instead of a line in the tooltip.
- BiS List and Dungeon Journal: an item new in WoW Forever has Forever's badge on its icon's
  corner, and what you wear a green bar at the row's edge. The paperdoll's slots show their
  item level in the corner and a green line under what you wear.
- BiS List: tidier rows. A slot's backups hang from it on a line; names get more room; a quest
  for your own side says just "Quest"; and an item with no known source says "World drop".
  Run Next's star counts, gains and links line up in columns. Each gain has a bar as long as
  its share of your biggest, brighter the bigger it is. A better enchant for what you wear
  shows as a small dot on that slot's icon in the paperdoll: hover for the advice, click to ask
  in Trade. Text, titles and columns share one grid.
- BiS List: right-click an item for its copy card (its ID and Wowhead link), the same card
  as the tooltips' Ctrl-Shift-C. Move and remove stay on a backup pick's icons and in the
  picker.
- Tooltip Display: the line saying which keys copy an ID is off by default; Show Shortcut Hint
  brings it back. The shortcut works either way.
- Copy cards link to Wowhead's Forever database; a Classic button beside it is there for a
  page Forever's has not got yet. The Wowhead Database setting is gone.
- BiS List: Run Next ranks quests, crafts and faction rewards with the dungeons and zones by
  how much stronger they make you, so a quest reward worth +18% comes first. Click one for
  the quest, the recipe or the faction.
- BiS List: "Your BiS over what you wear" shows the stats that matter most to your spec, by
  its stat weights, and leaves out what it does not weigh. No more "+14 more" and its
  tooltip.
- BiS List: the picker's items use the whole row for their name and where they come from,
  and the level shows only when it is above yours. A source still cut short shows in full
  when you hover it.
- Small icons are smoother: the check on gear you have, the button icons and the Forever
  mark, and item icons at any UI scale.
- BiS List: where an item comes from is a link. A dungeon drop opens the Dungeon Journal on
  that item, a reputation or PvP reward its faction there, a quest's reward the quest on the
  Quests page, an NPC's item a waypoint on them, a crafted item its recipe (if you have the
  profession), a zone its map; anything else copies its Wowhead link. Hover it to see where
  it goes.
- BiS List: a slot's backup picks open as rows like the slot's own: the rank (2nd, 3rd)
  where the slot's name is, the item, how much stronger it makes you and where it comes
  from in the same columns, move and remove on hover.
- Every sound setting (Combat Alert, Crosshair, Mouse Ring, Emotes, Focus Cast Bar, Campfire,
  Low Health, Threat Meter, Drop Alert) has a play button beside it, and plays the sound as you
  pick it.
- Dungeon Journal: the dungeon and faction lists count only the BiS you still miss there, and
  show nothing once they are all yours, instead of a second check.
- What is new in WoW Forever wears its infinity sign instead of NEW: dungeons and factions in
  the Dungeon Journal's lists and its dungeon page, and the bosses, quests and items new in
  Forever, in the Journal and the BiS List. Hover it, or the row, and the tooltip says
  "New in WoW Forever".
- Item tooltips are shorter: one line each for your BiS rank, how much of an upgrade it is and
  whether it is new in Forever, written the same way in the BiS List, the Dungeon Journal and
  on every tooltip, with nothing said twice.
- BiS List: each BiS you do not wear yet says how much stronger it makes you (+9%), by the
  stats your spec values, and Run Next puts the place that makes you strongest first, with its
  total, so you know what to farm first.
- BiS List: what drops in a dungeon is the Dungeon Journal's, so both list the same items under
  the same bosses and dungeon names, and a slot's picker offers every dungeon drop for your
  class (about three times as many as before).
- BiS List: Fill Empty Slots is gone. Pick each slot's BiS from its picker, or import a list.
- The options window's sidebar header shows the NaowhUI Forever logo, and the search box beside it is narrower.
- Flight Timer: with Land Early Button on, Blizzard's own Request Stop button is hidden
  during the flight, so there is only one. It comes back when you land.
- QoL has a new XP tab, right after Questing: XP Bar, XP per Hour and Group XP moved there from
  Questing. Your settings stay as they were.
- XP Bar settings show a preview of the bar: click a text on it, or a spot around it, to pick
  what it shows. A text shows in one spot at a time; picking it for another spot moves it
  there. If your bar already shows a text in two spots, it keeps the first one (top to
  bottom, left to right) and the other spot is emptied.
- XP Bar: three more spots for texts, Top (above the middle of the bar), Left and Right (beside
  the bar).
- XP Bar: the level inside the bar can be written shorter, as Lvl 20 or just 20.
- XP Bar: pick your own fill, completed quests, rested and background colours under XP Bar,
  Colours; Reset Colours puts them back. Reset Size & Texts does the same for the bar's width,
  height and the text in each spot.
- XP Bar: Completed Quests (XP) shows the XP of your finished quests as a number; the percent
  one is now called Completed Quests (%).
- The Naowh logo now has the closed infinity loop at the bottom, on the addon list, the main window and the small popups.
- The Minimap Button switch and the per-module minimap buttons moved from Settings to the Top Bar page, so /nf shows them straight away.
- Loot Feed Appearance options sit inside the Loot Feed dropdown instead of a second one.
- /nf opens on the Top Bar page the first time in a session; after that it reopens where you left it.
- Dungeon Quests is now part of the Dungeon Journal. Each dungeon's page lists your quests
  there: what to do first for one you can't pick up yet (and the waypoint points there),
  the level it needs, Too high for one five levels or more above you, and the whole chain
  leading up to it. The separate Dungeon Quests page is gone, and its tracker is the
  Journal's Tracker now; /nf dungeon and the Top Bar button open the Journal instead.
- Patch Notes: what's new in 0.5.18-beta on the in-game page.
- Campfire: each camp benefit shows as a short stat tag (+Spirit, +ATK, +ARM, +STR, +STA, +INT,
  +MP5, +Stats, +Crit, +Rested) instead of the camp feature's name.
- Supporter badges: the badge sits after the name in chat, at the size of the text, so every
  name starts in the same place and lines are no taller. It shows in the Guild & Communities
  member list too, after the name, and the lines on the badge's hover card line up.
- Options window: redesigned. The left menu groups the modules under Adventure, Combat and
  Utilities, a module's categories are tabs on one row under its title, the search at the top covers every
  setting, and each module's on/off switch is at the top right of its page. The window also fits
  on a 1080p screen.
- Buttons, dropdowns and input boxes have a black border that lights up blue under the mouse.
- Options window: a little taller, so the left menu fits every module without scrolling.
- Unlock Mode: the position readout sits on the display you select instead of at the bottom of
  the screen.
- QoL > General: Co-Tank Debuffs now sits inside Co-Tank Frame, and Stealth Reminder's colours
  and texts fold away under Appearance & text. Turning a feature off folds its settings away
  again.
- QoL: the auction house price on item tooltips is now switched in QoL > Tooltip Display
  (Auction House Price), with the other tooltip settings. Your setting is kept.
- Dungeon Journal: its data is updated to WoW Forever build 1.60.1.70170: 4 faction rewards changed (item levels, required levels).
- Campfire: Show Active Camp Buffs is a dropdown: Off, Always or On Mouseover, which shows
  the buffs only while the mouse is over the camp icon. Your current setting is kept.
- Dungeon Journal: its data is updated to WoW Forever build 1.60.1.70178.
- Sound dropdowns play the sound when you pick it, as Smart Reminders' already did.
- Threat Meter: Hide When Empty is now With Threat, a choice under Show, so Always really
  means always. Your setting carries over; with In Combat it becomes With Threat. In a Group
  can no longer hide the empty window, so choose With Threat for that.
- Dungeon Journal: its data is updated to WoW Forever build 1.60.1.70205.
- BiS List: picks updated from wowsrc.com's latest lists, for every spec.
- BiS List: Drop Alert says each drop once: a roll for one of your picks, then its boss's
  loot window opened as often as you like, is one line in chat with its star, the item and
  the slot it is for ("up for a roll: your BiS for Shoulder"), and another when it is yours.
  Its roll frame shows a badge with the star and "Your BiS" in place of the blue glow. Test
  in its settings plays it all for your first BiS.
- BiS List: Drop Alert is yours to set up. An alert on screen (on by default, moved in Unlock
  Mode) shows the item with your star, the line under its name and its border as you pick
  them: click them in the preview on its settings page to change them, and set its size, how
  long it stays, its background and glow. Choose which picks alert (your BiS, your top two, or
  all), a sound for a drop and one for when it is yours, and turn the chat line and the roll
  frame badge on or off.
- BiS List settings: a shorter page. Drop Alert's on-screen alert has a panel of its own: see
  it up for a roll, dropped or yours, click its star, line or border (or the chips under it)
  to change them, set its size, how long it stays, background and glow beside it, and Play
  test. Sounds play as you pick them, the list buttons sit on one row, and the star on the
  alert shows over the item's icon. On every settings page, greyed-out options can no longer
  be changed.
- BiS ranks look the same everywhere: an orange star for your BiS, a silver star for your
  second pick and a number for the rest, in the BiS List, the Dungeon Journal and on
  tooltips. What you wear is marked in green.

### Fixed
- Unlock Mode: Exit Config shows again (it was under the Level-Up Toast), Smart Reminders'
  samples move by dragging the whole display like everything else, and Bag Space's plate covers
  its whole row.
- Character panel: your Naowh Score no longer stays out beside the panel when you fold the stats
  side away.
- Blessings: the options window opens again while the bar shows your blessing buffs. Opening
  it, or changing the UI scale, raised a Lua error and left the window broken.
- Borders and divider lines no longer lose a side at some UI scales (the trainer popup's X
  missing its left edge, a panel without its top line), and icons keep their black edge all
  round. Every border, line and icon edge is now exactly one screen pixel, refitted when the
  UI scale or window scale changes.
- Opening a color swatch and closing it without picking no longer saves that color. A Custom
  theme color left at the default (including when Custom is first picked) no longer counts as
  changed, so the loot feed glow, XP bar quest and rested colors and the other HUD colors keep
  their own shades until you actually change one.
- Themes: the hint lines in the Library Books tracker and its map pins, and in the town map pins, follow your lighter Accent instead of staying light blue. Looks the same with the default theme.
- Group XP: every group member running Naowh Forever now shares their XP, even with Group XP
  switched off, so the bars no longer say "no addon" for players who never turned it on.
- Group XP: bars show everyone's XP again. Forever sends a character's full name with surname
  with each update, which never matched the party list, so every member read "no addon". Older
  versions can't be read: everyone needs this version to see each other.
- Themes: the Top Bar's clock, its FPS / MS labels and its tooltips follow your Text and Secondary Text colors instead of staying white and grey, and the tooltips of the Naowh buttons (minimap, top bar) use your Accent for the title and Text for the lines. Looks the same with the default theme.
- Themes: the Loot Feed follows your theme: the Dark style uses your Background, the Light style uses your Panels and Borders & Lines, and the glow uses your Accent. Looks the same with the default theme.
- Themes: the XP Bar's quest and rested segments and text follow your theme's Accent instead of staying gold and blue. Looks the same with the default theme.
- A copy downloaded with GitHub's green Code button has none of the addon's libraries, and
  parts of it then failed with Lua errors (Low Health's glow on a level up, among others). It
  now says at login which libraries are missing and where to download the full addon.
- Loot Feed: turning in a quest no longer shows its experience twice, once on the quest's line
  and again as Experience. With quest lines turned off it still shows as Experience.
- Blessings: the class buttons and the player list cast on the right player again in a party.
  Forever names carry a surname, and the buttons were looking players up by the whole name
  while the game knows party members by their first name.
- Blessings: a group leader's or assistant's changes to another paladin's blessings now reach
  them; they were dropped because of the surname. Changes made during combat are sent once
  it ends instead of being lost.
- Blessings: a class button no longer glows red when the only members missing their blessing
  are out of range. It lights up only for someone you can bless from where you stand.
- Recipe Finder and rank alerts: Stormwind and Eastern Plaguelands trainers and vendors
  (Lucan Cordell, the Stormwind enchanting trainer, among them) were placed at their Classic
  positions, so their waypoints pointed at the wrong spot on Forever's redrawn maps.
- Share Quests With Group no longer tries to share a quest accepted in combat, where the
  game blocks sharing.
- Discovery tracker: the zone picked in its dropdown stays picked once its last book is
  looted, showing "No more books in this area", instead of jumping to another zone.
- XP Bar: the texts above and below the bar take the room they need, so a long one is no longer
  cut off with "..." while there is space beside it. On a narrow bar they get smaller to fit,
  and the bar is at least 400 wide.
- The Naowh font is only on this addon's own windows and HUD again; the rest of the game keeps
  its own fonts. Settings > Font has Addon Font (Naowh), plus Game Font and Combat Text Font,
  both off unless you pick a font.
- The Naowh logo on the New Abilities, Quiz and Buy Materials windows is sharper and a little
  bigger.
- Blessings: every icon has the same thin black border, also while its buff is up and on
  your own blessing button.
- Bag Space: Unlock Mode shows your own items instead of question marks, where you have them.
- Buff Reminders: no more error when the mouse leaves a missing buff's item menu.
- Global Copy: /copy finds the frame under the mouse again when the game names none.
- Reload UI buttons and prompts work again, like the one after Apply All Recommended on
  QoL > Performance: they run the game's own /reload instead of causing an error. In
  combat they say to type /reload.
- QoL > Tools: a custom slash command that runs another slash command no longer makes your
  next chat message fail. Emotes like /dance work too. Macro commands like /cast, /use and
  /target, and /reload, can't be run this way; the command says so in chat.
- Sound dropdowns list None once; the second was a silent placeholder from SharedMedia.
  The QoL sound dropdowns (Combat Alert, Emote, Crosshair, Mouse Ring, Focus Cast Bar)
  now offer None as well, so a sound can be turned back to silent.

## 0.5.17-beta

### Added
- Unspent Talent Points (off by default, QoL > Combat & Alerts): text on screen while you
  have talent points to spend. Hidden in combat; move it in Unlock Mode.
- Share Quests With Group (off by default, QoL > Questing): while you are in a group, each
  quest you accept from an NPC is shared with the others, when the quest can be shared. A
  quest someone shared with you is not shared again. Hold Alt to keep one to yourself.
- Accept Popup Macro (Macros > Focus & Cursor): a macro that presses the first button of the
  popup on screen, like accepting a summons or a group invite. It presses whichever popup is
  on top, so it confirms the others too.
- Group XP (off by default, QoL > Questing): a bar for each group member with their level
  and how far through it they are, for levelling together. Everyone who wants to be seen
  needs Naowh Forever with Group XP on; anyone else shows their level only. Move it in
  Unlock Mode.
- Options window: a search box at the top of the sidebar finds a setting on the Settings
  page and on the QoL, Gear & Trinkets, Macros, AuraBuffs, Threat Meter, Swing Timer and
  Professions pages, jumps to it and lights it up, opening the dropdown it sits in. While
  you type, matching settings on the page you are on are highlighted and their dropdowns
  open. The editor pages (Smart Reminders, Profiles, BiS List, Blessings, Dungeon Quests,
  Top Bar, QoL Tools and Poison & Dispel) are found by name. Thanks to Lyssa.
- Supporter Badges: Legendary patrons on Naowh's Patreon now get the Naowh Forever N next
  to their name in chat, seen by everyone with the addon. Hover their name for their card,
  with how long they've been supporting, and their player tooltip shows it too. Type
  /nf badges id to get the code that links your characters. Naowh, the developers and the
  moderators have their own badges. Turn each part off in QoL > Interface > Supporter
  Badges, where you can also turn on a banner for when one of them joins your group.
- Discovery: a new module (off by default) for the 40 library books hidden around Azeroth.
  The Books page lists every book your faction can take, by zone, with its level set, where
  it lies, who takes it and a Waypoint button; Finished, In bags, In bank or Missing on the
  right. Books handed to the librarian count toward Friend of the Library (10) and Greater
  Friend of the Library (20); the level 60 set goes to a mage trainer instead.
- Discovery: Show Tracker (off by default). Entering a zone with books you still need pops
  up a small window listing them with a waypoint pin each, under a bar counting your
  hand-ins toward the next reward; hover the bar for both rewards and their items, click the
  title for the Books page. Books in your bags or bank get a line with where to hand them
  in. It stays while you are in that zone; the X closes it until you enter another.
- Discovery: Always Show (off by default) keeps the tracker up in every zone, with a
  dropdown of the zones where you still have books to find. Entering one selects it; the X
  switches Always Show off.
- Discovery: Show on World Map (off by default) pins every book you still need on its
  zone's map, and your librarian while you carry books. Hover for the exact spot; click for
  a waypoint.
- Discovery: Sound When Nearby (off by default) plays the map ping and names the book in
  chat when you come within range of one you still need (10 to 100 yards, default 40).
- Settings: a new COLORS section with theme presets (Midnight, Slate, Obsidian, Aubergine,
  Forest, Crimson, Rose Noir and Cotton Candy) for the addon's windows and HUD frames, plus
  a Custom option to pick your own Background, Panels, Borders & Lines, Text, Secondary Text
  and Accent colors. Choose a theme, then press Reload UI (a reminder shows under the
  section until you do). Custom can start from any theme. Off by default (Naowh
  (default)); saved for this computer.

### Changed
- Campfire: an Alert Under slider next to Camp Nearby Alert sets how many minutes of Camp
  Benefits count as needing a refresh, instead of always 2 (AuraBuffs > Campfire).
- Patch Notes: the page in the options window lists what is new in this version.
- Settings: switches that stand on their own now sit above the dropdowns on every page. On
  the QoL Questing, Loot & Items, Combat & Alerts and Performance tabs, AuraBuffs, Blessings
  and Swing Timer's aids they had been further down.
- Crosshair: Recolour Out of Melee Range and its options are inside the Crosshair dropdown
  instead of a section of their own.
- XP Bar: the text around the bar now has five spots, Top Left, Top Right, Bottom Left,
  Bottom and Bottom Right, and each shows the one you pick: Played Time, Session Time,
  Completed Quests, Rested Experience, Time to Level or XP per Hour. They replace the four
  text switches, and the texts you had on move into the spots (QoL > Questing > XP Bar).
- Flight Timer: bigger, with a Scale slider in its dropdown (QoL > Flight & Camp). The ends
  of the route are round dots, and the Land Early button uses the game's own leave-flight
  arrow.
- Settings dropdowns: switching a feature on opens its options, and the arrow is a bigger,
  bolder chevron.
- Flight Timer: a new look in Naowh's colours. The route is a line between its two ends,
  the stops on the way slide past you, and the time left sits beside it. A Land Early
  button (off by default, QoL > Flight & Camp) lands you at the next flight point.
- BiS List: lists are shared by every character of a class, and a class can keep several.
  Pick, make, rename and delete them on the List and Settings tabs; each character keeps
  using its own pick. Your current list moves over, named after your character. Importing
  a list adds it as a new one instead of replacing yours.
- BiS List: Fill Empty Slots puts the ranking's best item in every slot you have not picked,
  skipping items already picked elsewhere, so a second ring or trinket gets the next one down.
- BiS List picker: two-line rows with each item's source, item level and required level (in
  orange while it is above yours), small arrow and remove buttons, and only your own picks
  are numbered.
- BiS List: Where to Go Next lists only places you can go, not crafted, quest, reputation or
  world-drop items.
- BiS List: add any item to a slot by item ID, item link or Wowhead URL from the bottom of
  the picker.
- BiS List: a slot's BiS item is framed in a thin border of its quality colour, and the
  check mark is gone.
- BiS List: a button beside each slot steps its icon through your picks (BiS, 2nd, 3rd and so
  on) and turns green on the one you are wearing; the slot's line in Where Your Items Drop
  follows it. The slot's picker tags the item you wear Worn.
- Dungeon Quests and BiS List open straight to the dungeons and to your character panel;
  their options moved to a new Settings tab in each.
- Settings pages are shorter: a feature with several options, such as Restock or the Co-Tank
  Frame, is one row with its on/off switch, and its options open under it with a click.
  Features with a single switch stay as they are. Groups of options with no switch of their
  own, such as a module's layout or colours, open the same way.
- Dungeon Quests: click a step in a quest's Chain list for a waypoint to where it starts,
  or for a step in your log, to where the game sends you for it.
- Co-Tank Frame: Righteous Fury counts as tanking for paladins.
- Co-Tank Debuffs now show in combat, drawn by the game the way NaowhUI's co-tank does it,
  with its filter, icon, position and text settings. On by default with the frame.
- Combat Alert: two new voice clips, "Combat" and "Safe", are its default sounds for entering and
  leaving combat. Set Audio to Sound to hear a spoken alert without the stutter Text to Speech
  can cause. They are in every sound list as Voice: Combat and Voice: Safe.
- Professions: every Professions setting is off by default (Unlearned Recipes, Next Rank
  Alert, Reagents in Bags and Reagents in Bank were on). Settings a profile has already saved
  keep their value.
- Professions: the settings page is grouped into Recipe Window, Buying and Selling, and
  Gathering, two settings to a row.
- Professions: the recipe list is wider. Craft counts and required skills sit in a column at
  the left of each row, so the icons and names line up, and the profit at the right.
- Professions: Create and Create All grey out while one of the recipe's requirements is not
  met, such as being away from an anvil.
- Professions: the window follows the NaowhUI look: 1px black borders, the skill bars filled
  with Naowh's blue gradient like the XP bar, and flat checkboxes.
- Professions: amounts read as text, from the largest coin down to copper ("12g 07s 09c",
  "6s 00c").

### Fixed
- Death Release Protection no longer carries over to a death outside a dungeon or raid.
- Smart Reminders now follows an installed BigWigs or DBM on Forever, and pull triggers and
  boss-mod reminders work without Blizzard's encounter timeline. Callouts still wait for
  boss data, so nothing fires in Forever dungeons until BigWigs or DBM ship timers for them.
- Loading in while the game still calls you "Unknown" no longer files your character under
  that name or pins the wrong profile for the session.
- Pasting an oversized string into Reminder Pack import is refused instead of freezing the game.
- Auction Prices: a scan that comes back empty no longer wipes the saved prices or starts the
  15 minute wait.
- Gain/Lose a Buff or Debuff is no longer offered as a reminder trigger where the combat log is
  unavailable.
- Town Map: pins show by default in Zephras Isle.
- Flight Timer: the tooltip no longer says the first flight counts up.
- Professions: Crafting Profit (Buying and Selling, off by default). Once you have scanned
  the auction house (Scan Prices), the chosen recipe shows Buy for, Sell for and Profit: what
  its reagents cost to buy, what the item sells for, and the profit after the 5% auction cut,
  green or red. Each reagent is priced at its cheapest: a vendor's price once you have seen a
  vendor sell it, else the lowest buyout at your last scan. Hover the lines for the cost of
  each reagent. Works for unlearned recipes too.
- Professions: Profit in Recipe List (off by default) shows each recipe's profit at the right
  of its row in the list.
- Professions: with Crafting Profit or Buy Materials on, each reagent has a checkbox. Uncheck
  one you already have to leave it out of the cost and out of what Buy Materials buys, for
  every recipe that uses it.
- Professions: Search AH Button (off by default). At the auction house, a Search AH button
  next to the chosen recipe searches for the item it makes; unlearned recipes also get Search
  Recipe, for the pattern, plans or manual that teaches it.
- Professions: Buy Materials (off by default). At the auction house, "- [1] + Buy" under the
  chosen recipe's reagents buys the materials for that many crafts: every checked reagent
  vendors do not sell. Each material is searched and priced first, warns in red when it is
  more than 25% above your last scan or you cannot afford it, and is only bought when you
  click Confirm. Materials sold as single listings get Search AH instead.
- Professions: a Filter button beside the recipe search: Have Materials, Has Skill-Up,
  Profitable (once scanned) and Unlearned Recipes, with Reset Filters. It shows how many
  filters are on.
- Professions: Track Recipe on the chosen recipe's Reagents line, as in Blizzard's window:
  the recipe's reagents in your objective tracker.
- Professions: Tracking Reminder (Gathering, off by default). An icon on screen while you
  know Find Herbs, Find Minerals or Find Fish but track none of them; click it to start
  tracking (left, right and middle-click for the first, second and third). Hidden in combat,
  on flight paths, while dead, and in dungeons and raids unless Show in Dungeons and Raids is
  on. Include Find Fish can leave fish out. Move it in Unlock Mode.
- Mouse Ring: a cast pushed back by damage keeps its sweep to the new end instead of stopping at
  the old one and leaving the ring blank until the cast finishes.
- Mouse Ring: changing the Melee Spell ID takes effect at once instead of on the next target.
- Crosshair and Mouse Ring: switching Play a Sound off stops an out-of-melee sound already
  repeating.
- Cursor Clip: a crash or a closed client in the middle of a fight no longer leaves the cursor
  locked to the window; your own setting comes back at the next login.
- Mouse Ring: Recolour Ready Ring greys out while GCD Sweep is off, as the ready ring needs it.
- Combat Alert with Text to Speech no longer stutters the game on every pull. The addon re-read
  your installed Windows voices each time combat started; it now does that when you close
  the game's Settings or its Text to Speech options. The spoken line also goes out a frame
  after the combat change instead of on it.
- Auto Repair and Auto Sell Junk work with the Restock Reminder switched off. They did nothing
  at a vendor unless the reminder was on, and said nothing about it.
- Auto Repair says so when you do not have the gold to repair, instead of skipping it quietly.
- Buy at Vendors greys out while the Restock Reminder is off, as it only buys with it on.
- Professions: clicking another player's profession link with the profession window closed
  opened your own profession; it now opens theirs the first time.
- Professions: the unlearned recipe view no longer runs its requirement line under the
  Search Recipe button, or its waypoint hint into the profit lines.

## 0.5.16-beta

### Added
- Bag Space (QoL > Loot, off by default): the cheapest items in your bags as a row of
  icons, cheapest first (or grey items first), with what each stack sells for and a border
  in its quality colour, black for common items.
  Ctrl-click an icon to delete it, or click it to sell it at a vendor, and middle-click an
  item to ignore it. Uncommon and better items are only picked up by a Ctrl-click, so the
  game's own delete confirmation still applies to them. Hover an icon for what the stack
  fetches at a vendor and at the auction house; an item worth more at the auction house is
  valued at its auction price, so it comes later in the row. Reagents, ammo, quest items,
  keys, equipment set items and BiS items are never offered. It can show only when your
  bags are nearly full, hides in combat, and has a key binding that picks up the cheapest
  item, which you can set on the same page. Move it in Unlock Mode.
- Bag Space: Ignore List, on the same page, shows every item you ignored, newest first, with
  the day you ignored it and how many you carry. Search it by name, hover a row and click
  the X to stop ignoring that item, or drop an item from your bags onto it to ignore it
  before it is ever offered. Clear All starts over.
- Bag Space: each tooltip line it adds (vendor price, auction price, delete and ignore hints)
  can be turned off on its page. The quest warning always shows.
- Bag Space: a Stack button at the start of the row when part-filled stacks of the same item
  can be combined, with how many slots it frees; nothing is deleted. Free slots out of your
  total show above the row with a bag icon (orange when nearly full, red when full; hover it
  for each bag), food, drink and potions 10 or more levels below you are marked
  OLD (and can go first), and an "Inventory is full" error brings the row up for 20 seconds
  even when your free-slot threshold would hide it.
- Bag Space: an item an unfinished quest in your log still needs (Okra for Westfall Stew,
  say) gets a yellow ! and goes to the end of the row, and its tooltip names the quest and
  how many you have. Deleting it takes a second Ctrl-click within 5 seconds.
- Mail & Alts (QoL > Loot & Items, each off by default): item tooltips show what your
  characters on this realm and faction hold in bags, bank and mail. On the mailbox's Send tab,
  Alts fills the To box with one of your characters (with their level and gold) and Attach
  adds all trade goods, one type of them, or your unbound gear in one click. A login warning
  names characters whose mail expires within three days. Characters are recorded once you
  log in on them; Forget a Character removes one.
- Class macros: right-click an icon to pick another (yours only, never exported; Profile Icon
  restores it). A macro with an unknown command, a line that is not a command, or unbalanced
  brackets is marked, and hovering its icon says what is wrong. Profiles can add a note.

### Changed
- Class macros are now made as character macros, so they no longer fill General macro slots
  or show on your other characters. Class macros you already made stay where they are.
- Key bindings: Naowh Forever's bindings have their own Naowh Forever section in the game's
  Key Bindings, instead of sitting under AddOns. When a key field takes a key that was
  already in use, the message now says the key "is now bound to" the new action.
- Campfire: clearer high-resolution artwork, a larger default icon, and short buff labels such as Rested XP and Crit Strike 2%.

### Fixed
- Swing Timer: Show set to Always now keeps the bars up out of combat even with Hide When Idle on. Hide When Idle is greyed out while Show is Always, since it only applies to In Combat.
- Trinket bar: clicking an empty trinket slot no longer throws a Lua error, and hovering a slot shows the equipped trinket's tooltip instead of usage instructions (those stay on the Trinkets settings page).

## 0.5.15-beta

### Added
- Professions: Next Rank Alert (on by default). Once a profession's skill is high enough
  for its next rank (Journeyman, Expert, Artisan), a banner under the skill bar in the
  profession window, and on that profession's card in the overview, says what it takes
  (train it, buy and read the book, or do the quest) and who to see, nearest first. Click
  Waypoint (or the card's banner) to mark them on your map, with TomTom's arrow when TomTom
  is installed. It also says so once in chat; /naowh profrank repeats that. Covers every
  profession, Herbalism and Skinning included.
- Professions: an X in the recipe search box clears it.
- Professions: Crafts with Vendor Buys (off by default) adds a second, orange number next
  to each recipe: how many you could make after buying the reagents vendors sell, such
  as Weak Flux or Coarse Thread ("3 | 6", or just the orange "6" when you can make none
  yet). The chosen recipe's vendor reagents then say how many more to buy. Trade goods a
  merchant sells for gold without a stock limit are remembered when you visit them.
- Professions: Reagents in Bags and Reagents in Bank (both on by default) add Bags and Bank
  columns to the chosen recipe's reagents.
- Gear & Trinkets: a Trinket bar with two movable slots. Left-click uses the trinket,
  right-click (out of combat) picks another one from your bags.
- Macros: a Class Macros tab for macros supplied by your profile. Click or drag an icon to
  put it on your action bar. A macro that runs a script asks before it is created.
- Campfire: Buff Text Size, Buff Text Position (below, above, left or right) and Show
  Refresh Reminder settings.
- Blessings: Button Spacing, Aura / Class Gap, Timer Text Size and Class Labels settings;
  buttons go up to 70.
- XP Bar: choose the left, center and right text (level, XP, percent or rested).

### Changed
- Professions: your learned recipes sit under a Learned heading that folds away, and the
  unlearned ones are split into Learnable now, Needs more skill and Needs next rank (the
  last two folded by default). The recipe list has a scrollbar.
- Professions: Naowh's profession window is the only way the module shows recipes. The
  separate Naowh Profession Window switch and the unlearned-recipes drawer beside
  Blizzard's window are gone; the module's sidebar switch turns it all on and off.
- Buffs & Consumables: food, flask, scroll and elixir reminders come from the entries you
  add (an item ID and its buff spell IDs) or from an imported profile, instead of a built-in
  list. Hover a reminder to pick a configured item from your bags.
- Macros: the macro toggles are icons you click or drag onto your bars, created as General
  macros instead of character macros. Right-click an icon to remove its macro.
- Campfire: a new high-resolution icon. The timer ring is edged in black with no dark
  swipe over the icon, the seated label reads Resting, and each buff line shows the effect
  from the Camp Benefits tooltip.
- BiS: each spec keeps its own list; switching spec or importing no longer overwrites
  another spec's picks.
- XP Ticker: Level Splits is replaced by Level History, your most recent completed levels.
- Module names: Gear Sets is Gear & Trinkets, Alerts is Combat & Alerts.
- FPS and latency moved to the Top Bar; the On-Screen Extras options are gone.

### Fixed
- QoL's tab row no longer runs past the window edge and over the scrollbar; tabs tighten
  their spacing to fit.
- Threat Meter no longer throws a Lua error every update while it has a mob to show, which
  kept it from listing any threat.
- XP Bar: Blizzard's experience bar no longer comes back after a /reload. Its container's
  own fade-in animation was undoing the fade.

### Removed
- Streamer quotes on flights.
- Automatic loot confirmations (saved preferences are kept).

## 0.5.14-beta

### Added
- Tooltip Display (QoL > Tooltip Display): spell, item and NPC IDs under tooltips, and
  a copy card (Ctrl+Shift+C) with the ID or its Wowhead link, outside combat.
- Town Map: added 35 audited service NPC locations on Zephras Isle, including class and
  profession services, innkeeper, bank, auctioneer, vendors and repairs.
- The rest of NaowhQOL that works on Forever, each off by default:
  - Pet Tracker (QoL > Alerts): a warning while a hunter or warlock has no pet out or has
    it on passive, and optionally while the pet is low on health. A warlock who sacrificed
    their demon is left alone. Move it in Unlock Mode.
  - Equipment Reminder (QoL > Alerts): your trinkets, weapons and ranged slot in a small
    window when you enter a dungeon or raid or on a ready check, with an optional enchant
    check against the enchants you capture.
  - Emote Detection (QoL > Alerts): an alert and a sound when an emote in a dungeon or raid
    contains one of your words, plus auto emotes for spells you list, such as a summoning
    ritual.
  - Mouse Ring (QoL > Interface): a ring around your cursor with your global cooldown and
    casts swept around it, an optional trail, centre dot and border, idle fade, and a red
    recolour while your target is out of melee range.
  - GCD Tracker (QoL > Casting): your recent casts scrolling across the screen with a bar
    showing when you were busy, and an optional downtime summary after each fight. Move it
    in Unlock Mode.
  - Focus Cast Bar (QoL > Casting): your focus target's casts, coloured by whether your
    interrupt is ready, with a tick where it comes off cooldown, a shield on casts you
    cannot interrupt, and an optional sound or spoken line. Move it in Unlock Mode.
  - Performance (QoL > Performance): NaowhQOL's recommended graphics, frame rate and
    network settings, applied all at once or one at a time, with your own values kept so
    you can put them back, and the spell queue window.
- Swing Timer module: a bar for each weapon that can swing (Main Hand, Off Hand, Ranged),
  timed by the game's own swing event, so parry haste, swing resets and haste are always
  right. Range dimming, queued Heroic Strike / Cleave / Maul / Raptor Strike colors, class
  colors, textures and Unlock Mode placement. Its Timing Aids tab adds a window at the end of
  the melee swing (with optional latency), a hunter's Auto Shot cast window that turns red
  while moving, a mark where your cast ends against the next swing, and an estimated Target
  swing bar. Everything starts off.
- Professions module: Naowh's profession window over Blizzard's, with your recipes by
  category, reagents and Create / Create All in the middle, and Blizzard's profession tabs
  on its edge. The overview tab shows every profession as a card. Off shows Blizzard's
  window as before.
- Unlearned Recipes: the recipes you have not learned yet, listed under your own, with the
  skill each needs, what it costs and where it comes from (nearest trainers, the vendor
  selling it, or what drops it). Click a trainer or vendor to set a waypoint. Covers every
  crafting profession plus Cooking, Fishing and First Aid; with the Naowh window off it is
  a drawer beside Blizzard's. /nf recipes prints what the profession API reports.

### Changed
- Threat Meter: focus tracking, class icons and rank numbers, and with Lock Window off
  it can be dragged and resized.
- Dungeon Quests: each quest's state sits in its own column on the right, quests are listed
  in the order you work through them (to pick up, in log, complete, finished), and a
  finished quest is greyed with a check in place of its level. The tracker draws each quest
  as its own bar on a darker panel. The tracker's on/off is now only the module switch.
- XP Bar: the bar runs the full width, with the percentage inside it on the right.

### Fixed
- XP Bar: Time to Level and the quest and rested percentages no longer break for a moment
  after login or a reload, when the game still reports 0 XP to level.

## 0.5.13-beta

### Added
- Top Bar module: friends and guild on the left, the clock in the middle, addon buttons
  on either side, FPS and latency underneath. Dungeon Quests and BiS List are on it by
  default, and any addon's broker button can be added from its Buttons section, on the
  left or the right, along with an optional Hearthstone button. Move it in Unlock Mode.
  It replaces NaowhUI's top bar on Forever.
- Every module with its own window (Dungeon Quests, Gear Sets, Blessings, BiS List, Threat
  Meter) now has a broker button, which the Top Bar and any broker display can carry, and an
  optional minimap button next to the Naowh Forever logo. Settings > Minimap Buttons turns
  those on; they start off.

### Removed
- The micro menu bar. The Top Bar carries Dungeon Quests and BiS List, and any other
  module can be added to it.

### Fixed
- XP Bar: Blizzard's experience bar is faded out instead of hidden. Hiding it from the
  addon tainted Edit Mode's action bar layout, so a pet or stance bar change in combat
  was blocked (ADDON_ACTION_BLOCKED on MultiBarBottomRight). The space it took is kept.
- Crosshair: Melee Spell ID 0 now works for paladins (Holy Strike), and the class check
  no longer calls a function Forever only keeps as a deprecated shim.
- Text prompts wrap a long title inside the box instead of running past its edges.
- Smart Reminders: the alert preview no longer shows while the module is switched off. It
  put an empty square on screen whenever the Naowh Forever window was open, on any page.
- BiS List: item names no longer show as "item 12345" the first time you open a gear
  slot. An item the server could not load held back every other name in that slot until
  you clicked something.
- Dungeon Quests: clicking a quest you have, or Track in quest log in a chain list, now
  tracks it and selects it in your quest log instead of opening the log. Opening it from
  the addon left the world map's quest pins blocked the next time you opened the map in
  combat (ADDON_ACTION_BLOCKED on SetPassThroughButtons).
- Blessings: the Next Blessing and Next Greater Blessing key fields no longer take keys
  you press before clicking them. Walking with the Blessings page open bound W, A, S or D
  to a blessing.

## 0.5.12-beta

### Added
- Resize any Naowh Forever window by dragging its bottom-right corner, the main window
  and each module's own window alike. Each keeps its size, and pages spread out to the
  new width when you let go.
- XP Bar (QoL > General): level, experience and percentage on one bar, with completed
  quest XP and rested experience drawn past the fill, and optional played, session and
  levelling text underneath. Replaces Blizzard's experience bar while it is on. Off by
  default; move it in Unlock Mode.
- Dungeon Quest Tracker: Show Outside Dungeons (off by default) keeps it up in the world,
  listing each dungeon with one of your quests in the log or one you still need near your
  level. /nf dungeon and the X on the tracker switch it on and off.
- Dungeon Quest Tracker: Show Single Dungeon (off by default) adds a dropdown to the
  tracker to list a single dungeon. Entering a dungeon selects it.
- Dungeon Quest Tracker: a pin in front of each quest. On a quest you still need it marks
  the quest giver on your map; on one in your log it marks where you hand it in (the
  quest giver, or the turn-in NPC where that is someone else). Clicking a quest you have
  opens it in your quest log. Hover a line or pin for where the quest starts.
- Dungeon Quests: with TomTom installed, waypoints from the tracker and the Dungeon
  Quests page use TomTom's waypoint and arrow instead of the game's.
- Dungeon Quests: the seven new Forever dungeons that had no quests listed (Excavation
  Site: Wetlands, City of Dalaran, The Drowned City, Krol'dok, Alcaz Prison, Blackmaw Hold,
  Shaper's Terrace) are on the page and in the dropdown now, and all nine new dungeons show
  their level range.
- Dungeon Quests: a quest in your log has a green border on the tracker and the Dungeon
  Quests page, and once its objectives are done it reads Complete in green instead of In
  log, so you know it is ready to hand in.
- Dungeon Quests: every dungeon shows its level range now, not only the new ones. Within 5
  levels of it the range turns green, with IN RANGE on the Dungeon Quests page; the tracker
  shows it next to each dungeon outside and in the Show Single Dungeon dropdown.
- BiS List, Dungeon Quests, Gear Sets, Blessings and Threat Meter open in a window of their
  own, without the rest of the options: /nfbis, /nfdq, /nfgear, /nfbless and /nfthreat open
  or close each one.
- A micro menu bar at the top of the screen has a button for each. It shows BiS and Dungeon
  Quests to start with; choose its buttons or hide it under Settings > Micro Menu, and move
  it in Unlock Mode.
- Gear Sets: rename a set with Ctrl-click on its bar button or the Rename button on the
  Gear Sets page. Wear While Mounted and Wear While Resting follow the new name.
- Buffs & Consumables (AuraBuffs) now works: a row of icons for missing food, flask and
  elixir buffs in dungeons and raids, or wherever you choose under Show In. It can warn a
  few minutes before a buff runs out, and skips anything you do not carry.
- Scrolls in your bags show until you read them.
- Raid Buff Reminders shows how many in your group are missing Arcane Intellect,
  Fortitude, Divine Spirit, Mark of the Wild or a Blessing.
- Move the icons in Unlock Mode. Reminders pause in combat, since Forever hides auras from
  addons then, and pick up again after.
- Saved quest rewards (QoL > General > Questing): Alt-click a reward you can choose, in the
  quest log or at the quest giver, to save it for that quest in your profile. It is selected
  when you hand the quest in, and Auto Turn In takes it for you. Picks travel with the
  profile, so a shared profile comes with its rewards chosen. Suggested by Gingi.
- UI Clutter (QoL > Interface): Hide Error Messages, Hide Tutorial Pop-ups, Hide Screenshot
  Status and Skip Cinematics now work. Hide Error Messages also silences the voice line with
  the red text. Turning Hide Tutorial Pop-ups off puts back the tutorial settings you had.
  Skip Cinematics skips only cinematics already seen on this account.
- FPS counter (QoL > Interface), with optional local and world latency. Move it in Unlock
  Mode.
- Dungeon Quests: quest chains. Click a quest on the tracker, or its Chain button on the
  Dungeon Quests page, to list every quest in its chain in order, the ones before it and
  the ones after, each marked Completed, In log or Not done. A chain quest you have opens
  in your quest log from that list. Chains come from Wowhead's Forever quest database.
- BiS list: the slot picker lists every dungeon drop for that slot that your class can
  use under Other Dungeon Drops, below the ranking for your spec, with its item level,
  required level and the boss that drops it. It shows drops within 10 levels of yours;
  Show All lists every level. Click one to add it as your next pick. Dungeons Wowhead has
  no Forever loot for yet (Dire Maul and most of the new dungeons) are not in it.
- BiS list: the page looks like the character pane, your character in the middle with
  your gear slots around it. Slots start empty; click one to open a picker in the middle
  of the screen and choose its items in order from the ranking for your spec, your BiS
  first, then your 2nd, 3rd and so on. A slot shows its BiS with a green border and a
  check mark, and +N for the rest.
- BiS list: a Where Your Items Drop panel to the right of your character has a line per
  slot with its BiS, where it drops and +N for your other picks. Click the + on a line to
  list every pick for that slot with its boss and place. Run Next at
  the top names the places holding the most BiS picks you do not have yet.

Brought over from NaowhQOL:
- Questing (QoL > General): accept quests, hand in finished ones, and pick quests from
  an NPC's options for you. Hold Alt to skip it.
- Skip Loot Confirmations (QoL > Loot & Items): Need, Greed, disenchant and
  bind-on-pickup confirmations answered for you.
- Combat Timer (QoL > Alerts): how long the fight has run, with the time in chat when it
  ends.
- UI clutter (QoL > Interface): hide alert pop-ups, event toasts and zone text, and keep
  the cursor in the game window during combat.
- Crosshair (QoL > Interface), with a colour change and sound while your target is out
  of melee range.
- A new Tools tab under QoL:
  - Auto Combat Logging in raids, asking once per raid and difficulty.
  - Global Copy: /copy for the text under the cursor, and a hotkey that copies a
    tooltip's spell, item or NPC ID.
  - Custom Slash Commands that open a game window or run another command.

### Fixed
- Dungeon Quests: Afadra Dunwall (The Restless Dead) is marked at her real spot in Old
  Ironforge.
- Dungeon Quests: the level in brackets is the quest level the game reports, the same
  number as the quest log, instead of the guide's, which was often off (Leaders of the
  Fang read 15; it is 22).
- Dungeon Quests: quests with more than one step or a version per faction now read In log
  or Completed correctly, where before they could show Missing. Covers Searching for the Lost
  Satchel (Ragefire Chasm), Unending Torment and Crest of Lordaeron (Ruins of Lordaeron),
  and Allegiance to the Old Gods and The Essence of Aku'Mai (Blackfathom Deeps). A chain
  that is part done shows Next step. Crest of Lordaeron was missing and is listed now,
  and Searching for the Lost Satchel shows its real quest giver, Rahauro in Thunder Bluff.
- Blessings and Restock look up which spells you know through the current spellbook call.
  The old call only exists on Forever while deprecated APIs are loaded, so without them
  the Blessings bar could not find your blessing ranks and class reagent restocking found
  no spells.
- Macros: the macros on the Macros page are now actually made. Switching one on adds it to
  your character macros (NF Health, NF Mana, NF Food, NF Bandage, NF Trinket 1 and 2,
  NF Focus); put it on a bar once and it follows your bags, changing after combat if your
  bags change during a fight. Switching it off, or turning the module off, deletes it; a
  profile or spec switch that has it off leaves it on your bars. Announce Focus uses raid
  chat in a raid and party chat in a party. Before this the settings saved but no macro
  was ever written.
- XP per Hour: Reset now also resets the XP Bar's Time to Level, XP/Hour and Session.
  They kept their own count, so resetting seemed to do nothing when reading the bar.

These QoL settings were saved before, but nothing acted on them. They now work:
- Stealth Reminder (QoL > General): RESTEALTH on screen while a rogue or druid is out
  of stealth and out of combat, and STEALTH while stealthed. Druids choose Cat Form only
  or any form.
- Stance / Form Reminder (QoL > General): a warning while a warrior has no stance, a
  paladin has no aura, or a druid or shadow priest is out of the form picked on the page,
  with an optional repeating sound.
- Co-Tank Frame (QoL > General): the other tank's health while you are tanking, with
  their debuffs beside it out of combat. Click it to target them. It can also anchor to
  another frame by name.
- Auto-Fill Delete Confirmation (QoL > Loot & Items) types DELETE for you and shows the
  item as a link in the dialog.
- Low Durability Warning (QoL > Alerts).
- Combat Alert (QoL > Alerts): text as you enter and leave combat, each with an optional
  sound or spoken line.

Each on-screen reminder can be moved in Unlock Mode, and its text, colours and font set on
its page.

### Changed
- Loot Feed: Show Reputation and Glow are off by default. Anyone who switched them on
  keeps them on.
- XP per Hour: the level splits read "Level 23  1/4" and so on, instead of "Split 1", so
  each line says which level it belongs to.
- BiS list: each slot holds a ranked list of picks instead of one item. The picker lists
  your picks in order, with Up, Down and Remove, above the ranking you add from, each item
  with its rank and where it comes from: the quest, vendor or NPC from Wowhead's Forever
  database when the ranking gives no source. Tooltips, the loot feed and drop alerts say
  BiS for your first pick and BiS #2, #3 and so on for the rest. Your current list carries
  over as your BiS picks.
- BiS list: Alt+Shift-click adds an item as the next pick for its slot, or as its BiS when
  the slot has none, and never pushes out an item you already picked.
- BiS list: a two-hander as your Main Hand BiS greys out the Off Hand but keeps its picks.
  They count again once your Main Hand BiS is a one-hander.
- BiS list: picking is from the ranking and the dungeon drops now; the Add Item by ID
  button and the item ID entry are gone. Shared lists keep the order of your picks, and
  older strings still import. Worn marks a BiS pick you are wearing.
- Dungeon Quests: quests grey to you are no longer listed on the tracker (in dungeons and
  with Show Single Dungeon too) or on the Dungeon Quests page. Quests in your log and chains
  you are partway through still show, and Show Completed still lists the ones you did.
- The options window no longer builds a fresh copy of a page every time a setting on it
  changes, which used memory for the rest of the session. Every page now reuses its own.
- Popups and editors (reminder editors, pickers, confirmations, copy boxes, the gear set
  icon picker) are built once and reused instead of adding a new window each time they
  open.
- Campfire: standing near a campfire no longer stacks up a new hidden timer every time
  your buffs change.
- Lighter in combat: the Blessings bar, threat meter, trainer glow, loot feed, gear set bar
  and Smart Reminders' boss mod handling do less work per event, and XP per Hour stops its
  clock at max level.

## 0.5.11-beta

### Added
- Campfire: Show Only When Low keeps the camp icon hidden until Camp Benefits has less
  time left than you choose (10 to 59 minutes, 10 by default). Off by default.
- Campfire: while you sit at a campfire, the icon counts down the minute until Camp
  Benefits lands, then switches to the camp's own timer.

### Fixed
- Campfire: "Spell ID" no longer shows in the list of active camp buffs.
- Death Release Protection (QoL > General) now works: in a dungeon or raid, Release Spirit
  has to be held down for the Hold Time before it releases, and a plain click does nothing.
  The setting was saved before, but nothing acted on it.

## 0.5.10-beta

### Added
- Auction prices: a Scan Prices button on the auction house reads every listing and keeps
  the lowest buyout for each item (Blizzard allows one full scan every 15 minutes). Item
  tooltips show that price, and the loot feed can use it as its Price Source, no
  TradeSkillMaster needed. Settings under QoL > Loot & Items > Auction Prices.

## 0.5.9-beta

### Added
- Blessings: Next Blessing and Next Greater Blessing keybinds. Bind
  them on the Blessings page or in Key Bindings > AddOns > Naowh Forever. Each press
  blesses the next player who needs it; the Greater key only covers classes that share one
  blessing, while you carry Symbols of Kings. In combat a key steps through the players who
  needed it when the fight began.

## 0.5.8-beta

### Fixed
- Loot feed: the bag count on a looted item is your new total, not the count from before
  the loot.

## 0.5.7-beta

### Changed
- BiS list: every gear slot laid out like the character pane. Pick it opens that slot's
  ranking for your spec, with each item's icon, source and tooltip; the chosen item shows
  in its slot with a mark when you are wearing it. Rankings For switches between your
  class's specs. The last choice in every slot takes an item ID of your own.
- The list keeps one item per slot (two rings, two trinkets). Alt+Shift-click puts an item
  in its slot. An older list moves into slots on first use; anything that no longer fits
  is named in chat.
- Export now shares the slots and the spec, so a list you import comes in slot for slot.
  Older strings still import.

## 0.5.6-beta

### Fixed
- Threat meter: no more "attempt to perform boolean test on a secret boolean value"
  errors while your target is targeting someone.

## 0.5.5-beta

### Fixed
- Blessings: no more "table index is nil" error when someone joins your group while
  their character is still loading. They show up on the bar a moment later.

## 0.5.4-beta

### Changed
- The options window opens on Settings instead of Smart Reminders.
- Window Scale goes up to 200%, for large or high-resolution monitors.

## 0.5.3-beta

### Fixed
- Blessings: no more "Auras cannot be accessed" errors on boss pulls. While the game
  keeps auras hidden the bar holds what it showed before the pull, and its buttons still
  cast; the marks and timers catch up once auras are readable again.
- The campfire icon no longer reports the Camp Benefits buff gone, or plays its sound,
  at the start of a world boss pull.

## 0.5.2-beta

### Fixed
- Blessings: the bar waits for combat to end before it is built (a reload mid-fight), the
  bar cannot be dragged in combat, and a plan changed in combat is shared once it ends. A
  Greater Blessing is only used while you carry Symbols of Kings. The Blessings switch in
  the sidebar turns the module on and off by itself.
- The flight timer works on characters without the Adventure Legacy perk tree.
- The trainer popup's Update Bars no longer mistakes a spell whose rank has not loaded yet
  for a lower rank.
- The restock reminder follows your bags while it is up, so restocking from the bank or
  mail updates it; it only pulses when it first appears.
- The threat meter only redraws for your target's threat, not every mob nearby.
- The gear set icon picker no longer errors after the UI is hidden and shown again.
- Maginor Dumas's town map pin sits with the other Stormwind mage trainers.

### Upgrading
- The addon's folder is now NaowhForever. Delete the old NaowhSmartReminders folder, or both
  load and every reminder fires twice.

## 0.5.1-beta

### Added
- Threat Meter: threat on your target for everyone in the group, one bar each, with an
  optional pull aggro bar and a warning sound. Off until you turn it on.
- Gear sets: a new set asks for an icon from the same list the equipment manager offers.

### Fixed
- The flight timer counts down from your first flight on a route instead of counting up.
  The time comes from the length of every leg of the trip, 20% shorter with Frequent
  Flier. A flight picked up after a reload mid-air still counts up.
- Town map pins and dungeon quest waypoints in Stormwind, Mulgore, Redridge and the Eastern
  Plaguelands sit where the NPCs stand. Forever redrew those maps over a wider area, so the
  auction house showed in Cathedral Square and the mage trainers south of the park.
- Restock no longer asks for 1000 of "item 0" when your ammo slot is empty.
- The trainer popup closes after Update Bars once every slot is swapped.

### Changed
- The trainer popup's Update Bars only swaps each spell's highest rank on your bars. A lower
  rank sitting beside it, such as a healer's Rank 1 heal, stays for downranking, and if your
  top rank is already on your bars nothing of that spell changes.

## 0.5.0-beta

### Added
- Trainer popup: after a trainer visit, a window lists the abilities you just learned, and
  they glow on your bars until you use them. One button swaps every lower rank on your bars,
  keyboard and controller, for the highest rank you know. Right-click a spell in the window
  to keep its lower ranks for downranking. /naowh ranks checks your bars any time.
- Blessings: each class button casts on the next member of that class who needs a blessing
  (missing first, then running out), skipping anyone dead, offline or out of range. Greater
  Blessings only when the whole class shares one, otherwise the highest single rank. Each
  class opens a player list with per-player choices, aura and Righteous Fury buttons sit at
  the front, and an assignments grid shows every paladin's plan, editable by the leader and
  assistants.
- /naowh townaudit: open an NPC's window while standing next to them to see how far the
  town map pin is from where they really stand, or that the map is missing them.

### Changed
- The addon is Naowh Forever throughout: folder, files, saved settings, chat prefix and the
  addon table other addons read (`_G.NaowhForever`). Smart Reminders is one of its modules.
  Settings saved before the rename load once `SavedVariables\NaowhSmartReminders.lua` is
  copied over as `NaowhForever.lua`. `/nf` joins the existing slash commands.
- The town map has 38 NPCs Forever added that Classic never had: Horde paladin and
  Alliance shaman trainers among other new class trainers, Dalaran's innkeeper, bankers and
  vendors in Alterac Mountains, reagent and ammo vendors and an auctioneer.
- Unlock Mode, Settings, Patch Notes and Profiles moved from the sidebar to the top of the
  window, beside the close button. The sidebar now starts with the module list.
- The logo is redrawn with smooth edges, so it stays sharp at the size the window shows it.
- Dungeon Quests, Gear Sets and BiS List are modules of their own instead of QoL tabs, each
  with its own switch in the sidebar. Turning QoL off no longer turns them off. Their
  settings stay where they were, so nothing needs setting up again.
- The restock reminder stays up while you are in town and short on something, instead of
  hiding after a set time. It goes away once a vendor has you covered, when you leave or
  when combat starts, and pulses only when it first appears. The Display Time slider is gone.

### Removed
- The Trash tab and its ExBoss trash cooldown alerts. ExBoss does not run on Forever, so
  nothing on the tab could fire. Debuff alerts are unaffected. Trash rules already saved in
  a profile or a shared pack still load, they just no longer do anything.

## 1.4.25

### Fixed
- The Trash tab now says outright that trash cooldown alerts need ExBoss. Without it the
  tab showed an empty dungeon list and "No enabled trash rules for this instance and
  spec", which reads as nothing being set up rather than the timer engine being absent.
  Both the ability list and the timings behind every alert come from ExBoss, so nothing
  on the tab can fire without it.
- The ability list on the Trash tab now says why it is empty when it has nothing to show.
  The line written for that case could not be reached, so the list sat blank instead.

## 1.4.24

### Changed
- When a personalized profile is refused because it belongs to another account, the message
  now names both BattleTags: the one the pack is signed to and the one you are logged in to
  Battle.net as. Reading them side by side shows you whether the tag saved on naowh.gg has a
  typo in it, which the old wording gave you no way to tell.

## 1.4.23

### Fixed
- A personalized profile from naowh.gg no longer refuses to import when your BattleTag is
  saved on the site with different capitals than Battle.net holds. `Silkytouch#1976` and
  `SilkyTouch#1976` are the same account, and the check now treats them that way. It was
  reporting "this pack is licensed to a different Battle.net account", which pointed at the
  wrong problem entirely, and the 30 day change lock meant you could not correct it yourself.

## 1.4.22

### Added
- A pack shared with `/nutank share` is now named **Naowh** by default, and
  `/nutank share <name>` names it whatever you type. That name is what the profile ends up
  called when someone imports it.
- Importing a pack whose name you already have offers to **replace** that profile instead of
  landing another copy beside it. Off by default, and only offered when the name is actually
  taken, so nothing is replaced without choosing it. Replacing clears the profile first, so
  none of the old contents survive underneath. "Default" is never replaced.

### Changed
- A personalized profile from naowh.gg can no longer be exported or shared onward, including
  through `/nutank share`, and merging one marks the profile it was merged into. Packs that
  did not come with a licence are unaffected, so handing work back to a curator still works
  exactly as before.
- The refusal you get when exporting a profile built on someone else's pack no longer names
  the command that bypasses it.

## 1.4.21

Housekeeping only. No gameplay or behaviour changes from 1.4.20.

### Added
- LICENSE.md, covering this addon and the libraries it embeds.

## 1.4.20

Built on 1.4.18. The 1.4.19 alpha is not included: that work is still being fixed.

### Added
- naowh.gg can hand out a personalized, signed copy of a curator's Reminder Pack, bound
  to the recipient's own BattleTag so it cannot be freely redistributed. The signature is
  checked with a real RSA-2048 verification on import. Ordinary friend-to-friend and
  self-export packs are completely unaffected.
- Russian and German locale foundations, with the English strings split into
  Locales/enUS.lua. Anything untranslated falls back to English.

### Note
- Personalized packs from naowh.gg need this version or newer. Earlier builds do not know
  about the licence appended to the string and report it as damaged on import.
- **If you ran the 1.4.19 alpha**, it rewrote your saved trash alerts one way and this
  build does not carry the code that reads them back. Those alerts will stop firing, with
  no icon and no sound. Restore the NaowhUI_SmartRemindersDB.lua backup you took, or set
  a defensive preset on the affected alerts again.

## 1.4.19

**Never released. Superseded by 1.4.20, which is built on 1.4.18.**

**Alpha. Please test this before relying on it in a key.**

This build converts your saved trash alerts when it loads: any alert still carrying the
old generic "Use a defensive" line is rewritten to a blank one. Nothing is deleted, but
the conversion is one way. If you install this and then go back to 1.4.18 or earlier,
every converted alert stops firing, with no icon, no sound and no error to tell you. Back
up NaowhUI_SmartRemindersDB.lua before you load it if you want a way back.

### Changed
- A trash alert with no defensive preset chosen now calls out whichever preset the spec
  has active, instead of saying a generic "Use a defensive". That phrase was never typed
  by anyone: the page has had no text box since these moved from free text to presets, so
  every alert switched on from the dungeon list carried it.
- An alert whose preset belongs to another spec now falls back to the active preset as
  well. It used to go silent. Copy From Spec and shared packs both produce this.
- The Defensive preset dropdown reads "This spec's active preset" where it read "None".
## 1.4.18

### Fixed
- A trash alert or boss reminder bound to a defensive preset now stays quiet when nothing
  on that preset is ready. It was still playing its sound and speaking its line -- "Use a
  defensive", on a rule that had never been given one of its own -- over icons that had
  already gone dark for the same reason. A reminder carrying only custom text is
  unchanged and still fires every time.

## 1.4.17

### Fixed
- Picking a dungeon by name while the Instance ID field was showing saved the id last
  typed in that field instead of the dungeon chosen, then snapped back to it.
- Choosing a dungeon no longer redraws the page. On an alert too incomplete to have saved
  yet, that redraw threw away the spell id, name and switches already typed into it.
- The Instance ID field no longer pushes the Unit dropdown past the bottom of its panel.

## 1.4.16

### Changed
- A debuff alert names the instance it belongs to. "Every dungeon or raid" is gone from
  the list, and a new alert starts on the first dungeon instead of everywhere. An alert
  already saved for everywhere keeps firing everywhere and shows as "Instance 0" until you
  rescope it; "Another instance (by ID)" still accepts 0 if that is what you want.

## 1.4.15

### Fixed
- A debuff alert can be scoped to an instance the dungeon list does not carry again. That
  list comes from ExBoss and holds only dungeons it has trash data for, so without ExBoss
  it is empty and nothing could be scoped at all, and a raid was never in it. The list
  gains "Another instance (by ID)", which brings the id field back.
- A second boss callout arriving while the first is still on screen no longer keeps the
  earlier cast's target name under it.
- The target name no longer overlaps the callout at small Text Size settings. It is drawn
  at a fixed size while the row spacing follows Text Size, so the two could collide.

## 1.4.14

### Fixed
- The target name on a boss cast sat a full row clear of the callout, with an empty row
  between them, because the row it used belongs to a reminder's own text and that text is
  not shown for a boss-mod callout. It could be drawn and still be impossible to find. It
  now takes the row directly beside the callout, and moves out one only when a reminder is
  actually using that row.

## 1.4.13

### Removed
- Show What Is Incoming. Its spoken half went in 1.4.11 as a second voice over BigWigs, and
  the line on its own did not earn a row on the alert. The label no longer travels from the
  boss mod to the display at all, and the rows that moved to make space have moved back.

## 1.4.12

### Removed
- Show Target on Trash Casts, and everything behind it. A trash cast was matched to the
  rule that predicted it by spell id, and the client keeps that id secret for every unit
  that is not you or your pet, so the match never succeeded and the repeat never once fired
  in a dungeon. The per-rule Show target on cast and Sound on cast switches go with it.
  Rules and packs already carrying those fields keep them untouched.

### Changed
- The diagnostic trace says when a boss cast names somebody even with no alert on screen to
  put the name on. One traced dungeon now answers which abilities carry a target name at
  all, which previously took a pull per guess.

## 1.4.11

### Changed
- Debuff Alerts pick the instance they apply to by name, from the same dungeon list the
  Trash tab uses, instead of a typed Instance ID. An id the list does not carry keeps an
  entry of its own, so an alert set for a raid is not quietly moved to everywhere.

### Removed
- Say What Is Incoming, one release after it arrived. BigWigs already announces its own
  warnings, so this was a second voice saying the same thing a beat earlier.

## 1.4.10

### Added
- Say What Is Incoming, on Setup. Speaks the boss mod's own name for the ability just
  before the callout: "Frontal", then "Vampiric Blood". Said on its own rather than folded
  into the callout, so it still works when your callout is a sound file instead of speech.
  The bar's count is left off what is spoken -- "Frontal", not "Frontal one".

### Fixed
- The diagnostic trace said "no name, asked if it is on you" for a cast carrying no target
  name, describing a marker that was removed in 1.4.7. It reads "cast names nobody" again.

## 1.4.9

### Fixed
- Show What Is Incoming showed nothing on DBM. DBM identifies a timer by a numeric id
  rather than by its text, and the line was using that id; the message DBM sends alongside
  it is the label now. BigWigs was unaffected, since its identity is the bar text.
- The alert no longer leaves an empty row between the callout and the target name when the
  incoming line is switched off.
- Show Target on Boss Casts takes effect the moment you tick it, instead of waiting for the
  next pull. Its trash counterpart already did.

## 1.4.8

### Added
- Show What Is Incoming, on Setup. The alert gains a line naming the ability the boss mod is
  timing -- "Frontal", "Debuffs", "Boss Buff" -- so it says what is coming as well as what
  to press. The name is the boss mod's own bar text, which arrives as ordinary text beside
  the timer, so nothing is guessed and nothing restricted is read. Only for reminders driven
  by a BigWigs or DBM timer, since that is where the name comes from. Off until you ask.

## 1.4.7

### Removed
- Mark Me When I Am Targeted. It could never have worked. The game answers "is this cast on
  you" as a protected value, and the only way to put that on screen is a call the game
  refuses from addons, so it failed silently from the day it shipped in 1.4.1. Nothing is
  really lost: when a cast does carry a target name, that name is yours when it is on you.

### Changed
- The diagnostic trace now says why a boss cast did or did not put a name up: the switch is
  off, nothing was on screen to write on, or the cast names nobody.

## 1.4.6

### Fixed
- The rule editor no longer reads Enabled for a trash ability nothing is saved for. It was
  showing a would-be rule's defaults while that ability's own switch in the list correctly
  read off, and the missing Remove button was the only sign nothing was there. Editing a
  field on an ability you have not switched on now creates it disabled, which is what the
  editor in front of you says it will do.

## 1.4.5

### Added
- A boss cast puts the target's name on the reminder that is already on screen. The client
  will not say what a boss is casting, so a reminder could never be matched to the cast it
  warned about; whether a cast names somebody is the one thing it does answer plainly, so
  the warning already showing picks the name up when the ability goes out. Needs Show
  Target on Boss Casts, on the Dungeon Bosses or Raid Bosses tab. Boss units only: the name
  belongs to whatever is casting at that moment, which on a boss is the mechanic you were
  warned about and in a trash pack would be a guess.

### Changed
- The Trash dungeon list only offers Every dungeon when there is a saved rule no dungeon in
  the catalogue accounts for, instead of always carrying an entry that opens an empty list.

## 1.4.4

### Changed
- Show Who Is Targeted is now two switches, each on the page that owns the reminders it
  affects. Show Target on Boss Casts sits on the Dungeon Bosses and Raid Bosses tabs,
  Show Target on Trash Casts on the Trash tab, and both start off. Mark Me When I Am
  Targeted stays on Setup, since it applies wherever a name shows. The old setting is not
  carried over, so if you had it on, tick the one you want.
- Debuff Alerts are grouped by the instance each one is set for, under headers that fold
  shut. Alerts set for every dungeon or raid get their own group at the bottom. Folding a
  group leaves whatever is selected inside it open in the editor.

### Fixed
- A trash callout bound to a preset names every cooldown in the set, not just the one that
  won the pick. With Call Together ticked on Anti-Magic Shell and Death's Advance it said
  "AMS"; it now says "AMS and Death's Advance", the same line the boss callout has always
  spoken for a set.
- The Trash and Debuff Alerts lists stay where you left them. Picking a rule rebuilds the
  page, which sent the list back to the top, so anything below the fold scrolled away the
  moment you clicked it.

## 1.4.3

### Changed
- The spec list in Merge a Profile In now matches the one in Import: rows grouped by
  class and coloured by it, read as "Protection (Tank)" rather than "Protection
  Warrior", with Select All and Deselect All beside the heading.

## 1.4.2

### Changed
- Show Who Is Targeted and Mark Me When I Am Targeted now start off rather than on. Both
  are in Setup, and the trash callout repeat is behind them too, so no part of the cast
  target display shows up until one of them is ticked.

### Fixed
- The Merge a Profile In window sizes itself to the string you paste. A profile covering
  a lot of specs pushed the last rows and both "Also take their..." switches out past the
  bottom of the window, with Merge and Cancel sitting over the middle of the spec list.

## 1.4.1

### Added
- Boss casts that name a player now show that player's name on the alert in class colour,
  with YOU beside it when the cast is on you. Two switches in Setup to turn either off.
  Display only; the game does not let an addon read who was named, so the voice cannot
  follow it.
- Trash callouts get the same treatment. A trash rule warns ahead of the cast, so there is
  nobody to name yet when it fires; it now comes back at the cast itself carrying the
  name. Only for abilities that name a target, and silent unless you ask for it. Show
  target on cast and Sound on cast, per rule, on the Trash tab.
- Copy From Spec on the Debuff Alerts tab, for moving debuff alerts between specs.
- `/nutank share` exports your profile even when it came from someone else's pack, for
  handing changes back to whoever maintains it. The pack is marked so they can see it is
  theirs coming back.

### Changed
- Trash Alerts and Debuff Alerts, renamed from Trash & Debuff Alerts and Debuff Sounds.
- Each Copy From Spec now moves only its own kind. The trash one used to drag debuff
  alerts across with it.
- No more 32 rules per spec limit on trash and debuff rules.
- Trash and debuff rules save as you change them. The Save button is gone.
- The rule editor is one page in two columns instead of three tabs.
- Dropped the custom text field. A preset writes the callout line.
- The Trash list no longer repeats the dungeon name under the dropdown that names it.
- BIGWIGS/DBM MESSAGES is now BOSS REMINDERS, with an Add Reminder button. Cast triggers
  live in that editor too, so naming it after messages hid half of what it does.

### Fixed
- Remove no longer overlaps Test in the rule editor.

## 1.4.0

### Added
- Merge a Profile In, on the Profiles tab. Paste a string somebody else maintains, tick
  the specs you are accepting, pick which of your profiles it goes into, and it merges
  rather than landing beside them. A ticked spec is taken whole, lists, bindings and
  trash rules together. Nothing outside the ticked specs can move, which matters because
  a contributor usually works in a copy of the whole profile they were given. Per-boss
  reminders come across only for the specs they record. Raid reminders, callout lines and
  their display and sound settings record no spec and are left behind unless asked for.
- Shadowmeld joins Stoneform as a cooldown-gated debuff voice. Pick it as the sound on
  a debuff rule and it stays silent while Shadowmeld is on cooldown, unknown, unusable
  or you are dead. The two gate independently, so one being down does not quiet the
  other.
- New voice clips for both racials, supplied by Naowh, listed as "Stoneform - Naowh" and
  "Shadowmeld - Naowh" to match his other sound files.

### Fixed
- A spoken callout uses the name you gave the spell. Renaming Vampiric Blood to Vamp
  renamed the label beside the icon but not what was said, so the two channels
  disagreed about the same spell.

### Changed
- The options window is two levels: Smart Reminders, Custom Notes and Profiles across the
  top, with Setup, Cooldown Presets, Dungeon Bosses, Raid Bosses, Trash and Debuffs under
  Smart Reminders. Custom Notes is dimmed and says what it will do.
- The Trash page shows one dungeon at a time as a collapsible section, with the spell icon
  and a switch on every ability. Rows are half their old height, so a dungeon's abilities
  fit without scrolling the list.
- Debuff sounds have their own tab beside Trash. They answer to an aura rather than a
  dungeon, and were previously reachable only through a bucket at the foot of the trash
  list. Each page keeps its own selection.
- Copy From Spec sits beside the page heading, since it acts on the whole spec rather
  than on the selected dungeon.
- Trash and debuff callouts draw on the defensive alert itself, replacing what is in it,
  instead of putting a second icon and line on screen beside it. A rule with a preset
  rebuilds the alert's slots from that preset; a rule with only custom text takes the
  alert's own text row and puts the slots away, so a defensive left there by the spec's
  preset no longer shows beside the line. Each rule keeps its own sound and Speak
  Callout setting.
- The separate Ability Reminder display is gone. Every reminder now draws on the
  defensive alert, so there is one placeable display instead of two showing the same
  kind of callout in two different styles. Its Reset Ability Reminder Position button
  and its own text colour setting go with it; the alert's Defensive Text Color now
  covers both the slot labels and the authored line.
- Every trash ability row carries a switch, reading off until a reminder exists behind
  it. Turning one on writes the rule the editor would have written and opens it.
- Reminder icons carry the 1px black edge the priority slots already had.
- Callout text is now Custom text, and it greys out while a preset is supplying the line.
  What is typed there is kept and returns when the preset is cleared.
- Text in the trash editor's input boxes is inset rather than sitting on the border.
- The Trash and Debuffs pages fit the options window, so the page itself no longer
  scrolls. The editor's Cast, Text & Test and Voice settings sit behind tabs instead of
  stacked panels, Save and Remove moved onto that row, and the page reports the height
  it actually draws rather than a fixed guess. The ability list keeps its own scrollbar.
  Switching tab shows a different panel and nothing else, so a preset chosen or text
  typed and not yet saved survives the switch. Save, Test and Remove sit above the tabs,
  since they act on the whole rule rather than on one group of its settings.

### Validation and limits
- All 18 offline regression suites pass; runtime Lua syntax checked.
- This is a large UI rework and none of it has been verified in the client. The window
  layout, the split Trash and Debuffs pages, the single reminder display and both new
  dialogs are offline-tested only.
- The two racial voice clips are installed and wired but have not been heard, and their
  encoding is unverified.
- Showing who a boss cast is aimed at is not in this build. It is display only and
  cannot be meaningfully tested outside an instanced pull, so it ships on alpha first.

## 1.3.9

### Added
- Importing a single-profile pack can point every character on the account at it, including
  characters logged into later, instead of leaving each alt to be switched by hand. The
  toggle names how many characters it will move and is on by default.
- Copy From Spec on the Trash & Debuff page brings another spec's trash and debuff rules
  across, leaving anything already saved here alone and saying what did not fit the
  32-rule limit.

### Fixed
- Setting an account-wide profile now turns per-spec profile switching off, instead of
  every alt being moved back to the previous profile on its next login. Spec choices are
  kept and come back if switching is turned on again.

### Validation and limits
- All 17 offline regression suites pass; runtime Lua syntax checked.
- User confirmed the account-wide import in game, which is how the per-spec switching
  conflict was found. That fix and the trash rule copy are not yet client verified.
- Copied trash rules name the spells the source spec casts. Copying across classes is
  allowed and warned about rather than blocked.

## 1.3.8

### Added
- Bar callouts and BigWigs/DBM message reminders run side by side on the same ability:
  bars keep the ability's own preset and warning time, messages fire the message
  reminder's preset.
- Copy From Spec brings BigWigs/DBM message reminders across with the abilities, remaps
  their preset to one this spec owns, and counts them in the spec picker.

### Fixed
- The ability Test button tests the bar callout instead of refusing when the ability also
  has a message reminder, and points at that reminder's own Test.
- A message reminder is no longer muted by the repeat window when the bar callout for the
  same ability just named the same defensive.
- A reminder saved under DBM's own spell id is matched against the BigWigs key it is
  normalised to, instead of both callouts firing for one message.
- The Setup page counts message reminders when deciding whether this spec has anything
  set up, so a spec whose whole setup is reminders no longer reads as empty.

### Validation and limits
- All 16 offline regression suites pass; runtime Lua syntax checked.
- User confirmed in game. Both callouts share one reminder frame, so when a bar callout
  and a message land close together the later one replaces the display.

## 1.3.7

### Added
- Trash & Debuffs setup with profile/spec rules, EXBoss readiness predictions, preset selection, and pack sharing.
- Native player/party aura sounds and bundled English voices, including Stoneform calls gated by racial readiness.
- Test buttons for individual BigWigs/DBM message reminders.

### Fixed
- Reused and recurring trash timers can notify on later cooldown cycles without replaying same-cycle corrections.
- Invalid debuff spell and instance IDs are rejected instead of silently retaining previous values.
- Message-only abilities direct tests to their message rows instead of reporting missing talents.
- Improved ability-picker spacing, moved external-call help above its toggle, and colored the Healer label green.
- Reminder TTS uses the addon voice volume and reports preview failures.

### Validation and limits
- All 15 offline regression suites pass; runtime Lua syntax checked with Lua 5.1.
- User confirmed Stoneform voice in combat and a dungeon. New repeat-cycle fixes, message tests, and UI layout still need client verification; after screenshots are unavailable.
- EXBoss integration predicts readiness, not confirmed casts or targets, and depends on inspected internal scheduler methods.
- Native aura registration changes defer during combat/encounter restrictions. No specific-bleed icon or personal-target Shadowmeld voice is implemented.

## 1.3.6

### Added
- Account-wide Enable Healer Reminders switch in Setup, enabled by default.
- Healer Reminder tagging for ability preset callouts and authored reminders.
  Tags travel with shared packs; each player's opt-out stays personal.
- Turning healer reminders off cancels their pending alerts and hides their
  active displays. Existing reminders remain untagged until a curator marks them.

### Fixed
- BigWigs messages containing protected target text can trigger reminders using
  their readable spell key, including Thunder and Lightning on Adderis and Aspix.
  Protected text is discarded; this does not add player-target detection.

### Validation
- All 13 offline regression suites pass; runtime syntax checked with Lua 5.1.
- Boss-message audit passed 1,980 synthetic dispatch checks across 990 numeric
  module/key pairs. New message regression cases cover cancellation and counters.
- Live encounter validation and screenshots for these changes are outstanding.

## 1.3.5

### Fixed
- Restore the settings preview after switching profiles, including switching back
  from profiles with the icon or master switch disabled.
- Cancel stale raid reminders after deletion, replacement, disable, profile changes,
  or encounter changes. Two reminders sharing a boss bar can both fire.
- Handle early boss-mod broadcasts, exact bar cancellation, and delayed callouts
  when a bar identity is reused.
- Recover sound lookup when SharedMedia loads late, invalidate cached sounds on
  registration, and clear timeline sounds when their settings change.
- Validate nested imported settings before modifying profiles, preserve supported
  legacy shapes, and correct account-default fallback when deleting profiles.
- Keep the alert frame from overwriting the addon's global namespace.

### Performance
- Cache sound lookups, coalesce settings and spell refreshes, reuse dialog controls,
  and prune observations outside encounters.
- Reuse the main Setup page's controls and rebind their profile callbacks. Dynamic
  boss/profile editor frame growth is not fully addressed by this change.

### Validation
- All 12 offline regression suites pass under Lua 5.1, including 38 recovery cases,
  profile-preview restoration, real serializer round trips, and Setup control reuse.
- The tester reported all requested in-game checks passed after loading recovery.2.
  No exact client build, screenshots, profiler capture, or taint log was supplied.
- Combat CPU improvement and universal taint-free behavior are not claimed.

## 1.3.4

### Fixed
- Preserve charge counters across temporary API changes and avoid crediting a
  completed recharge twice, preventing false ready calls for charge abilities.
- Restore Feint charges when recharge data is unavailable and disregard its old
  inferred recharge estimate that could leave reminders silent for minutes.
- Keep delayed message reminders through unrelated settings refreshes and cancel
  them when their reminder is disabled, deleted, or replaced.
- Handle boss messages emitted at encounter start before setup finishes.

### Added
- Opt-in BigWigs/DBM message triggers with a delay and defensive preset selection.
  Existing timer-bar bindings remain for abilities without an enabled message reminder.
- BigWigs ability selection and a single-page reminder editor. Time-in-combat
  trigger creation is removed.
- Bounded charge-model diagnostics included in exports even when trace is off.

### Validation
- 106 automated regression checks pass under Lua 5.1.
- User verified Death's Advance behavior, boss-message triggers, and Feint recovery
  with icons and sound in game. Fiery Brand has automated coverage only.
- A newly reported Windwalker issue is under investigation and is not claimed fixed.

## 1.3.3

### Fixed
- Track charge spells across configured presets, including casts before a boss pull,
  and share readiness between base and replacement spell IDs.
- Restore only completed charge recharges instead of prematurely filling the stack.
- Retry an empty early warning until its boss timer expires, allowing a cooldown
  that becomes ready during that window to be called once.
- Exclude BigWigs cast bars from timer reminders, including Chillstorm uptime.
- Exclude the verified Demonic Rage uptime bar and message on Xathuux.

### Validation
- The reporter confirmed in-game testing of the fixes.
- Fiery Brand has automated coverage; no separate live Fiery Brand result was supplied.
- Unknown ordinary uptime bars retain the existing filtering behavior.

## 1.3.2

### Fixed
- Removed a charge-tracking fallback that could mark an empty defensive as ready
  before its recharge finished, causing callouts for unavailable abilities such
  as Death's Advance.

## 1.3.1

### Fixed
- Exclude developer tools and regression scripts from release packages.

## 1.3.0

### Added
- Dedicated Profiles tab for profile management and import/export.
- Minimap launcher with the NaowhUI logo and a saved, draggable position.
- Reminder Font selector shared by defensive, ability, and raid reminder text.
- Hide After Casting toggle, off by default. Dismissal uses the displayed icon
  independently of speech; protected visibility falls back to the display timer.

### Changed
- Icon Display Duration defaults to 3 seconds, adjustable from 1 to 15 seconds.
  Existing profiles retain their saved duration.
- Removed Where It Runs and its global dungeon/raid gates. The main enable
  switch and per-boss choices remain in control.
- Bundled the NaowhUI logo for the addon-list icon and colored Naowh blue in the title.

### Fixed
- Charge tracking could spend a charge twice, invent one after a failed read,
  or credit the same recharge twice. Death's Advance recovery and callouts were
  verified in Ruby Life Pools on the test build.
- Skipped warnings and warnings with empty or unusable presets no longer erase
  the previous icon before its display timer expires.

## 1.2.0

### Changed
- Importing a pack names each row by its spec rather than its class. A Warrior's
  three rows all read "Warrior (DPS)" and "Warrior (Tank)" before, with no way
  to tell Arms from Fury; they now read "Protection (Tank)", "Arms (DPS)",
  "Fury (DPS)". Class colouring is unchanged, and it is what tells apart the
  four spec names that belong to two classes each.

### Added
- Select All and Deselect All on the pack import, beside the name field. A pack
  can carry all forty specs, so bringing in one or two of them meant thirty
  eight clicks of turning the rest off.

## 1.1.2

### Fixed
- A defensive with charges could be called while you had none of them. At zero
  charges the spell's cooldown is not running, and the charge tracker read that
  idle cooldown as proof a charge was in hand, so it handed itself one. Death's
  Advance was named at 0 of 2 on Rav'i because of it. The tracker now believes
  the client when it says a charge is still recharging.
- Where the game will state your real charge count, which is everywhere outside
  a dungeon or raid, that count is now used instead of the tracked estimate. The
  estimate could only drift, and had nothing to correct itself against for the
  rest of the session once it had.

## 1.1.1

### Fixed
- A flood of "table index is nil" errors while BigWigs' options or Edit Mode
  were open. The preview bars BigWigs raises there are not real boss timers and
  carry no ability, and filing one under the ability it does not have was the
  error. Those bars are now ignored, which is what should have happened anyway:
  there is nothing to remind anyone about.

## 1.1.0

### Added
- Window Scale, on the setup page under Options Window. Sets the size of the
  options window and every editor it opens, from 50% to 100%, for people whose
  screen the config UI did not fit on. Saved for the computer rather than in
  the profile, so switching profile leaves it alone and an exported pack never
  carries it to someone on a different monitor.

## 1.0.1

### Fixed
- Reminder Packs could not be imported or exported on the CurseForge and Wago
  builds, which reported "The serializer libraries are missing from this
  build." Those builds pulled an unrelated library that shares the LibSerialize
  name, so nothing registered the serializer the pack code reads. Local
  installs were never affected.

### Changed
- The version moves on every release now, so the number in the TOC and beside
  the build stamp identifies which files a report came from. Three separate
  1.0.0 files were published while this was not the case.

## 1.0.0

First release.

### Added
- Boss ability reminders driven by BigWigs or DBM. Pick the boss addon under
  Hook Into; every reminder rides its bars and messages rather than a timeline
  of our own.
- Dungeon Bosses and Raid Bosses tabs: this season's pool read from your own
  Dungeon Journal, with an ability picker per boss. Boss pages start blank and
  abilities are added deliberately.
- Cooldown Presets: named lists of defensives, stored per spec. A preset binds
  to an ability, with its own warning time.
- Callout display: icon and text with independent anchors, sizes and colours,
  placed from the Customize Anchors toolbar.
- Ability Reminders, assignable to a role, class, spec, name or subgroup with
  AND/OR combinations. Text, icon, bar, ring, timer, chat line, text-to-speech,
  nameplate glow and raid-frame glow displays.
- Triggers: a boss mod bar or message, a cast starting or finishing, a phase
  starting, time after pull, time in combat, and an aura applied at a stack
  threshold.
- Skip When Already Covered, which drops a call when a big defensive or
  external is already up, for as long as you set Your Own Cast Covers You For.
  On a tank spec, boss callouts fire only for the tank the boss is actually on;
  DPS and healer specs are never gated.
- Call Together: tick two or more cooldowns on a preset and they are called as
  one -- "Vampiric Blood and Icebound Fortitude" -- showing as a single row
  named for the call. One on cooldown is left out rather than holding the
  callout back.
- Equipped on-use trinkets sit in the cooldown preset picker beside the spec's
  own defensives, and the list follows a gear swap without a reload.
- Announce in Chat, including calling for an external by name.
- Observed timings: what the boss actually did on your own pulls, recorded per
  difficulty, with a reminder built from one click.
- Reminder Packs: a whole profile as one string, with preview before apply.
- Standalone options window at `/smartreminders`, `/nsr` or `/naowh`. Own
  theme, widget kit, profiles and SavedVariables, with no EllesmereUI
  dependency.
- Diagnostics under `/nutank`: `status`, `cds`, `keys`, and a trace recorder
  with a copyable export. Pretend Tank lets a DPS reproduce a tank-buster
  report.
- Every option ships off by default.
- Callouts on any spec, not only ones with a tank role. A raid-wide hit a DPS
  answers with a personal is the same question a tank buster asks, put to
  somebody else. Adding an ability for a spec is the opt-in, and abilities are
  stored per spec, so a spec nobody has set up still calls nothing.
- Call for an External is decided per ability as well as per spec, from that
  ability's own cog, for hits the raid was never going to answer.
- Warning Time takes a negative number, calling a defensive that many seconds
  AFTER a mechanic lands rather than before it, for a hit whose useful moment
  is once it is over.
- Copy All Dungeons / All Raids From a Spec, at the top of the boss lists:
  another spec's whole setup in one press, instead of repeating the per-boss
  copy on every boss. Raids and dungeons stay on their own side, and anything
  the target spec already has is kept.
- Saving a profile under a name already taken offers to overwrite it, naming
  the profile and what replacing it costs, rather than refusing.
- A boss page with nothing on this spec says whether the profile has work under
  other specs, since an empty page otherwise reads as lost data.
- `/nutank tanksheet` cross-checks the curated tank-ability list against the
  Dungeon Journal, separating entries the journal contradicts from ones it
  simply has no role flag for.

### Changed

- Ability Reminders is marked coming soon: the tab is dimmed and opens a note.
  The same reminders are authored per boss in the meantime, which is where that
  page reads them from.
- Importing a pack never overwrites anything. It lands as a new profile under a
  name you choose, so going back to your own profile finds it as you left it,
  and a pack that does not mention a spec no longer drops the one you had.
- A whole profile exports in one string, every spec it holds, with the display,
  sound and behaviour settings alongside it for the importer to take or leave.

### Fixed before release

Found by testers on live keys and raid nights between the release branch being
cut and 1.0.0 going out.

- Tank callouts fired for both tanks on abilities the addon could not attribute
  to a boss unit. Every ability in the pool was checked against its BigWigs or
  LittleWigs module and given the slot that casts it, so a call now goes to the
  tank holding that boss. Abilities whose module never settles a slot keep the
  old behaviour rather than risk silencing a real one.
- A tank holding an add that occupied a boss frame was called for the boss's
  own ability, most visibly on Ula'tek.
- Threat momentarily reading low -- mid-cast, across a stage change, while a
  boss was untargetable -- refused callouts for the tank who had the boss the
  whole time.
- Charge defensives could read ready while on cooldown: a spell's cooldown was
  being stored as its recharge, and for Guardian of Ancient Kings those differ
  by nearly three minutes.
- A repeating ability called on some casts and not others. A boss mod's bar for
  the next cast replaced the callout already due for the current one, and a
  second announcement of the same cast could cancel the next one outright at
  short warning times.
- A debuff bar sharing an ability's spell id could take that ability's callout
  with it when it expired.
- A defensive was named over one still running.
- Rav'i's Triple Shot was treated as a tank hit. Blizzard's own Journal calls it
  a healer mechanic and it is not threat-driven, so it no longer carries the
  tank-hit sound or the tank tag in the ability picker.
- Two boss abilities landing within a second of each other, as Entombed
  Sentinels' do, announced the same defensive twice. A repeat of the same pick
  is now muted for three seconds across different abilities, while a genuine
  repeat of the same ability seconds later still gets its own line.
- Raid-frame glow did nothing for anyone using EllesmereUI raid frames, with no
  error. The library it asks first returns nothing for those frames, so the
  buttons are now looked up directly when it comes up empty.
- The options window opened with every tab blank. One file had passed Lua's
  200-local ceiling and stopped compiling, taking every page builder with it.
- A dropdown could open behind the row below it, a colour swatch could go
  unreachable, and the ability editor's layout could overlap at some sizes.
