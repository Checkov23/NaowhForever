# AuraBuffs

Buff and consumable reminders, the Campfire and Low Health. Its settings page is
AuraBuffs/Settings; the consumables to watch are listed in the AuraBuffs window (`/nfbuffs`, its
minimap and Top Bar button). Its on/off switches and their defaults come from
`ns.FEATURES.auraBuffs`.

- **Buffs & Consumables:** a row of icons for missing food, flask and elixir buffs from the
  consumables you watch, class buffs missing in your group, and your own class buff (armor, Inner
  Fire, Battle Shout, poisons, a weapon imbue, a hunter's aspect) when it is missing. Click one to use the item it
  shows, or hover it to pick another carried item.
  Worn Gear Reminder and Fishing Pole Reminder (both off by default) add an icon while you wear
  gear with a drawback where it matters (`D.WORN`, each entry naming its switch): Cloak of Hermitic
  Bliss in Wailing Caverns, and a fishing pole (Everywhere, or Dungeons & Raids by Fishing Pole
  Shows In). Its tooltip is the item's own; Ctrl-click hides it until that item comes off.
- **Campfire:** in two looks on one mover. Round, a camp icon with a time ring and a countdown;
  Simple, a bar in the windows' backdrop with the campfire at its left, the camp's bonuses with
  their amounts, and the time left on the right over a line that runs down green, yellow, then
  red. Hovering it lists each bonus, the time left and when to refresh.
  With no Camp Benefits it glows (LibCustomGlow) and its fire is grey. With a campfire in range the
  fire lights up, the words say Click to sit, and a click on the fire or its words performs the
  /sit emote (Round: the icon and the label under it; Simple: the whole bar); it glows brighter
  under the mouse. Camp Nearby's fire does the same.
- **Camp Nearby:** the same bar drawn bare (no backdrop, edge or line), larger by its own scale,
  sized to what it says and stacked in the Alerts group (`ns.AlertStack`), with the camp's time
  left inline after a dot while it still runs.
- **Low Health:** the best healing item in your bags, with a LOW HEALTH warning, while your health
  is under the threshold. With no healing item it stays hidden, unless Show When Out is on.

## Layout

```
NaowhForever_Combat/AuraBuffs/
  AuraBuffs.xml                every file, in load order, included by Combat.xml
  AuraBuffs.lua                the settings (ns.AuraBuffSettings), the module table (ns.AuraBuffs, A),
                               consumable entries kept in the profile, ns.ParseConsumableEntry,
                               the consumables list string (ns.ConsumableListString,
                               ns.ParseConsumableList), ns.CampBuffMode
  Constants.lua                the numbers several of its files share (A.C)
  Data/
    BuffReminders.lua          the spells and items behind the buff reminders (ns.BuffReminderData)
    Campfire.lua               the camp auras and each camp feature's bonus, by spell ID (A.CampData)
  BuffReminders.lua            which consumables and class buffs are missing (A.Buffs)
  CampReader.lua               which camp bonuses you have, from their auras and Camp Benefits'
                               tooltip, and their labels (A.Camp)
  LowHealth.lua                the item to offer and the curve that shows it (A.LowHealth)
  View/
    Style.lua                  its look (A.Style), on top of Shared/Style.lua
    Glow.lua                   a reminder's glow, with optional proc style, from its glow settings (A.Glow)
    BuffCell.lua               a buff reminder icon (A.BuffCell)
    CampIcon.lua               the campfire art and the Round look (A.CampIcon)
    CampBar.lua                the Simple bar (A.CampBar)
    CampAlert.lua              the Camp Nearby alert's look and fades (A.CampAlert)
    LowHealthLook.lua          the Low Health icon and warning (A.LowHealthLook)
  UI/
    SettingsPage.lua           the page's banner (Open AuraBuffs) and its Window card
    GlowRows.lua               the glow type, color and pixel look rows a card adds (A.GlowRows)
    Campfire.lua               the Campfire reminder and the Camp Nearby alert on screen
    CampfireCards.lua          the Campfire and Camp Nearby cards, with their editable previews
    LowHealth.lua              the Low Health icon on screen
    LowHealthCard.lua          the Low Health card
    BuffMenu.lua               the carried items a buff reminder offers, as secure buttons
    BuffReminders.lua          the buff reminder row on screen
    ClassBuffs.lua             secure self-buff buttons for missing buffs, and managed active icons
    BuffsCard.lua              the Buffs & Consumables card
    WindowPages.lua            the window's page: consumables, with list import and export, and
                               items dragged onto a section
    Window.lua                 the AuraBuffs window
  Media/CampfireHD.tga         the campfire icon's art (View/CampIcon.lua)
  README.md                    this file
```

## Why

- In combat the client refuses addons the player's auras outright (`GetAuraDataByIndex` errors,
  `GetPlayerAuraBySpellID` returns nil with the buff up), and it withdraws them at boss pulls
  before `InCombatLockdown()` turns true. Every read is gated on
  `C_Secrets.ShouldAurasBeSecret()`, and the reminders keep what they last showed until combat
  ends, or they would read every buff as missing. `InCombatLockdown()` is still false while
  `PLAYER_REGEN_DISABLED` is handled, so that event is checked too.
- A `UNIT_AURA` unit arrives secret while auras are restricted; `PLAYER_REGEN_ENABLED` catches up.
- Consumable entries are profile data, never code: an item ID, then buff spell IDs only when the
  buff is not the item's own, checked as plain numbers. They travel in a profile string's
  Consumables part (`utilityReminders.consumables` in the profile); presentation settings stay in
  the module's store.
- An entry with no buff IDs: food counts any Well Fed (every cooked food's buff is named Well Fed,
  whatever it raises, so it is matched by the name of `D.WELL_FED[1]`), other items their use spell
  (`C_Item.GetItemSpell`), which needs the item cached. An uncached item is asked for once, and only
  its own `ITEM_DATA_LOAD_RESULT` refreshes: an ID with no use spell would otherwise load, refresh
  and ask again forever.
- An added item's icon, in the row, its menu and the window, is the cached item's own
  (`GetItemInfo`, `R.ItemIcon`); uncached, it is the one the game has for the ID, the item is asked
  for once like a use spell, and its `ITEM_DATA_LOAD_RESULT` draws the row again.
- The window's rows show each item's icon and name. A name needs the item cached, and an item added
  by ID usually is not, so the row read "Item <id>" until something else loaded it. An uncached
  row asks for its item once (`ContinueOnItemLoad`, never for an ID the game does not have) and
  draws the page again when it lands. The icon is cropped by `ICON_CROP` of `ICON_SIDE`, as the
  reminders crop theirs, and dropped `ICON_DROP` to the letters of the Naowh font.
- An item dragged onto a section's rows, or clicked onto them, is added there with its own buff:
  the cursor is cleared, and one already in that section, one with no use effect (once cached) or a
  full list is said in chat instead. The rows are plain frames, not secure ones, so a drop in combat
  is no different from typing an ID in combat.
- The consumables list string is one line, since the paste box is one line:
  `NFCONSUMABLES1:food=13931,2680;battle=13454/17539`. Import also takes a profile string and keeps
  only its consumables, through the same checks as the profile import; it adds what is not listed
  yet, up to `MAX_ENTRIES` (500, the same limit the profile import enforces).
- Group auras change in bursts, so a buff refresh waits `QUEUE_DELAY` and covers the lot. Nothing
  fires as a buff runs down, so the earliest one to cross the warning time is timed.
- Show Buff Range starts off. When enabled, raid buff reminders show confirmed recipients in
  casting range over the eligible members missing that buff. The check uses a learned rank of
  that family's spell. A missing buff on yourself is in range; an unknown, secret or unavailable
  result is unconfirmed, contributes zero, and never adds an unknown label. With none confirmed,
  the icon dims to `BUFF_RANGE_DIM` and its glow stops. Other reminder icons keep their usual look.
- `SPELL_RANGE_CHECK_UPDATE` / `C_Spell.EnableSpellRangeCheck` only track the current target.
  Group movement across a buff's casting range therefore uses a narrow exception to event-only
  updates: a `RANGE_INTERVAL` (0.5 seconds) ticker checking only cached missing recipients, without
  rescanning auras or bags or rebuilding the row. It exists only while range tracking is enabled
  and a visible reminder has a learned spell and another missing group member. It stops on combat,
  disable, Unlock Mode or no remaining reminders; restriction transitions freeze reads. Self-only
  and uncastable buffs need no ticker. Aura and roster events still rebuild the missing lists.
- Hide Out of Range starts off and needs Show Buff Range. A raid buff with a learned spell and
  none confirmed in range is left out of the row instead of dimmed, so a party member far off
  while questing shows nothing. An uncastable buff cannot be confirmed, so it stays dimmed rather
  than hidden for good. When a tick sees a buff cross between hidden and shown it queues a normal
  refresh, the only time the ticker rebuilds the row.
- `ELIXIR_ICON` (13454, Greater Arcane Elixir) stands for "no elixir at all" in the preview.
- The preview's raid buff (Unlock Mode and the card) is the first picked one the reminders would track for you
  (`A.Buffs.RaidSample`): one you know, or with Only Buffs I Can Cast off any non-talent one. With Raid Buff
  Reminders off, or none that applies, it shows none, so a warrior no longer sees Arcane Intellect.
- Two classic elixirs for the same stat do not stack, so one of each group counts; Forever's
  stacking is unconfirmed. Forever keeps the classic IDs for flasks, elixirs, scrolls and class
  buffs; cooked food moved to Forever-only "Nutritious Food" spells with one shared Well Fed aura
  per stat (Wowhead's Forever data, build 1.60.1). Flask of Petrification is left out: it is a
  minute of stone form, not a buff to keep up.
- Hide Blessings on Paladins (`hideBlessingsOnPaladin`, off by default) suppresses both paladin
  raid reminder families and Class Buff Tracker slots while the player is a grouped paladin, since
  the Blessings tab already covers them. It keeps the saved picks and does not hide the Blessing bar.
  Leaving the group, turning the option off, or playing another class restores the selected reminders.
- Paladin blessings start off in the raid buff picks: the Blessings module covers them. Salvation is a raid
  buff of its own, since it stacks with the other blessings: a member with only Salvation still lacks a blessing,
  and one with only a blessing still lacks Salvation. It skips members whose assigned role is Tank (a secret
  role counts as not a tank), and is off until picked like the rest. A talent
  buff (Divine Spirit) only counts when you can cast it, since another player's talents cannot be
  seen. A camp buff standing in for a class buff is not seen, so it still counts as missing.
- Personal buffs (`D.PERSONAL`) fire only for the player's class and once a spell of the family is
  known, so a talent buff (Shadowform, Trueshot Aura, Water Shield) waits for the talent. Any spell
  of a family counts as up: Frost, Ice or Mage Armor all satisfy the mage. The icon is the first
  known spell, so families list the best first. Forever adds its own IDs: Trueshot Aura 1299346 and
  1299348, Water Shield 408510 (the TBC IDs do not exist), Fel Armor 403619 (Wowhead dataEnv=16,
  2026-10-11; not yet checked in the client).
- Poisons and imbues are temporary weapon enchants (`C_Item.GetWeaponEnchantInfo`, which lists
  several per weapon with the empty ones first: Windfury is its second entry, where the old
  `GetWeaponEnchantInfo` global reads only the first), so any one counts,
  a sharpening stone too. Nothing reliable fires when one runs out (Blizzard's own display polls),
  so its expiry is timed. Poisons check every equipped weapon, imbues the main hand. An enchant
  reported with no time left counts as up and times nothing.
- Weapon Imbue's family lists four different enchants (Windfury, Flametongue, Frostbrand,
  Rockbiter), not ranks of one, so "the first known spell" picked the wrong icon once a shaman
  trained more than one. `UNIT_SPELLCAST_SUCCEEDED` remembers the last one actually cast
  (`lastImbue`) and the icon follows that instead, falling back to the first known spell until a
  cast is seen.
- The glow of a reminder (the buff icons, the Campfire's refresh reminder, Low Health) is Pixel Glow or
  Standard Glow, both LibCustomGlow's. Standard is its ButtonGlow, the action button spell alert: Blizzard's
  own `ActionButtonSpellAlertManager` only drives action buttons. Each feature has its own switch
  (`buffGlow` off by default, `campGlow` and `lowHealthGlow` on as before), type, color, and for Pixel Glow lines,
  thickness and speed. Speed is 1 to 8 as in EllesmereUI, the march taking `9 - speed` seconds, so 5 is the
  four seconds the Campfire and Low Health glows always had; the default type, red color, eight lines and
  thickness 2 are what they drew before. `Glow.Set` restarts a glow only when its settings or the icon's
  width changed.
- With Only If I Carry One off, food, flasks and elixirs with no entries still get a reminder: any Well Fed, flask or elixir of the
  classic lists in `D.DEFAULT_GROUPS` (no battle/guardian split on Forever, so one elixir reminder, skipped when
  guardian entries exist). Food's icon is the carried item's, else the last buff
  food eaten (`lastFoodIcon` in the account settings, taken on `UNIT_SPELLCAST_SUCCEEDED` from the bag item
  with that use spell, else the spell's own texture), else Well Fed's. Weapon Enhancement Reminder (off by default) asks for a stone or
  oil (`D.WEAPON_ITEMS`) on each equipped weapon, an off hand only when it is a weapon, and defers to a class's
  own poison or imbue reminder. Its icon is the carried item's, else a Rough Sharpening Stone (`D.WEAPON_ICON_ITEM`),
  and each stone, weightstone and oil shows its classic icon (`D.WEAPON_ICONS`, a texture path per item ID, here and in
  the hover menu) rather than the client's item icon: Naowh asked for classic-looking icons, and the first oil in the
  list has a modern one. The IDs and icon names are Wowhead Forever's (2026-10-14), which match Classic's.
  A weapon item saved as Last Used before that (the client's item icon) is turned into its classic icon the
  first time it is shown, or forgotten when no stone or oil has it. `ItemIcon` returns the classic icon for these
  items, and Last Used finds the carried item by it, so the row, the item a click uses and the menu agree.
- With Only If I Carry One on (the default), Robin asked for reminders only while you have the item, but a profile
  with nothing listed should still remind you about the flask or buff food in your bags. So a kind shows when a
  listed item is carried, else when an item of the same `D.DEFAULT_GROUPS` list is (buff food is any bag item whose
  use spell is in `D.FOOD_SPELLS`), with that list's auras also counting as up. The listed item wins; else the
  highest required level you can use, the rest following in the hover menu. The bags are read once after
  `BAG_UPDATE_DELAYED` or `PLAYER_ENTERING_WORLD`, not on every refresh. This replaced "an empty profile never
  invents reminders from bag items", so the row is on whenever the module is. Weapon Enhancement Reminder
  already worked this way on `D.WEAPON_ITEMS`.
- A scroll you have not listed reminds only while you carry one, with Only If I Carry One on or off (`carried` on their
  `D.DEFAULT_GROUPS` entry): Robin expected a carried scroll to remind like food, but a reminder for scrolls you
  do not have would nag everyone. Each stat is its own buff, so `ScrollGroup` offers the first carried
  scroll whose stat is missing, not any scroll. A scroll does not stack with the class buff of its
  stat (`raid` on `D.SCROLLS`: Arcane Intellect, Power Word: Fortitude, Divine Spirit), so
  `D.SCROLL_AURAS` counts that buff as the scroll's. Listing a scroll keeps the old rules for that kind: the
  listed entries alone decide, and the built-in scroll group is not used.
- Only If I Carry One is set per kind (`carriedPicks`: food, flask, scroll, battle, guardian, weapon): Drjay
  wanted buff food to remind him with none in his bags, without flasks and elixirs showing all the time too. A kind
  with no pick follows the old single switch (`onlyIfCarried`), so profiles from before keep what they did.
- Icon (Default or Last Used): Last Used shows the icon of the flask, elixir, scroll or weapon item
  used last (`lastIcons` in the account settings, food's is `lastFoodIcon`), taken from the item whose
  use spell `UNIT_SPELLCAST_SUCCEEDED` reports; a spell no listed or default item uses is ignored, and
  nothing is read in combat. The cast event is listened for only while Last Used is chosen or food
  needs it (Only If I Carry One off for food). Icon Size defaults to 48 and goes to 96; a profile that saved a
  size keeps it. The row is sized to its icons and anchored by its centre, so reminders spread left
  and right of the saved spot, and one sits on it.
- Warn With Minutes Left covers personal buffs too, except a buff no longer than the warning
  (Battle Shout's 2 minutes), which would otherwise show the moment it is cast. Poisons last 30
  minutes and Forever's imbues 60, past the slider's 10.
- The card lists every class's personal buffs, the player's own class first: its label in the class
  color, the others grey with the class named in its color beside the switch. Picks are stored under
  the buff's own key (`personalBuffPicks.demonArmor`), so a Warlock buff switched off on a Priest is
  ready for the Warlock; every personal rule checks `family.class` against the player's class, so
  none fires for another class. Raid buff picks are not greyed: another class's raid buff fires when a
  group member of that class can cast it. A class with no personal buff (paladin) still gets the
  group for the others.
- Worn Gear Reminder: Cloak of Hermitic Bliss (273084, a Kresh drop, new in Forever) slows you 25%
  and speeds swimming 33%, so it gets worn for Wailing Caverns' water and forgotten. Wailing Caverns
  is instance ID 43 (`GetInstanceInfo`'s eighth value). Item and effects from Wowhead's Forever
  tooltip, 2026-10-14; not yet checked in the client. It is read on `PLAYER_EQUIPMENT_CHANGED`,
  `ZONE_CHANGED_NEW_AREA` and `PLAYER_ENTERING_WORLD`, registered only while the switch is on.
- Fishing Pole Reminder has its own switch so its name says what it does. A fishing pole in the
  main hand reminds anywhere by default (Robin asked for it), or only in dungeons and raids
  (`fishingPoleWhere`). It is matched by its weapon subclass, `Enum.ItemWeaponSubclass.Fishingpole`,
  not by item ID or name, so every pole counts in
  every locale; `GetItemInfoInstant` needs no cached item. Its icon stays up while you fish, so
  Ctrl-click hides it for that item (`dismissed`, per slot, not saved): a different item there, or
  `PLAYER_EQUIPMENT_CHANGED` taking it off, shows it again. The click is a `PostClick` on the secure
  icon, which has no item set for worn gear, so it uses nothing.
- Hunter's Mark is asked for only with a hostile elite, rare elite or boss targeted, read from the
  target's debuffs; like every reminder it holds what it showed once combat starts.
- Aspect: any aspect counts, so Cheetah or Pack while travelling does not remind. Another hunter's
  Pack or Wild lands on you too, so the family is `own`: only an aura whose `sourceUnit` is the
  player counts. The IDs are every rank Forever has, from the Training data (game build
  1.60.1.70178), names checked on Wowhead's Forever spells: Forever adds Aspect of the Beast ranks
  2 to 4 (1299445 to 1299447), and 25296 is Hawk rank 7, from a book. The best Hawk comes first,
  so the icon is Monkey below level 10. Mounted or not makes no difference, as for every reminder.
- The buff menu holds secure buttons, so it can only be hidden outside combat. It uses
  `IsMouseOver` on the frame: the old `MouseIsOver` global is gone from the game.
- The buff menu's icons are the row's Icon Size, centred under the icon you hover and spreading both
  ways, each line of them centred too. With no room under the icon it opens above it; the screen
  clamp keeps it in at the sides. The icon size and every gap, in the row and the menu, are rounded
  to whole pixels (`Cell.Snap`): at a UI scale where a unit is not a whole pixel, a menu icon a
  fraction of a pixel off the row was resampled and looked rougher than the icon above it.
- The row's icons are secure item buttons (`type1 = "item"`), each using the carried item it shows
  (under Last Used, the carried one with that icon; when no carried item has it, the row shows and
  uses the first carried item instead); a class or raid buff icon uses nothing. Secure buttons make the row
  protected, so in combat nothing touches it: a refresh waits, and a setting change or Unlock Mode
  is applied once combat ends (`PLAYER_REGEN_ENABLED`), registered only while the row is on or
  showing.
- A press glows the icon (`Glow.Press`): a short Pixel Glow in the Glow color, lines and thickness,
  under its own LibCustomGlow key so a reminder's own glow keeps running. It is not the game's button
  highlight or pushed look (`Parts.Press`). The menu waits for the glow before it closes.
- The row's and the menu's icon edges take the theme's Borders & Lines color (`ns.ThemeTint`), and
  stay black with the default theme.
- Camp Benefits (1229741, probed 2026-09-19), Campfire Nearby (1283391, the area aura in range of
  a campfire, 2026-09-24) and Welcoming Campfire (1229739 and the crafting 1289723, the 60 second
  aura while sitting, before Camp Benefits lands, 2026-09-25) were probed on the client.
- Camp Benefits is earned in the open world, so dungeons, raids and battlegrounds never nag about
  it.
- The bonuses come from the hidden aura each camp feature puts on you, by spell ID, and for the
  rest from Camp Benefits' tooltip (wago.tools build 1.60.1.70205), in `FEATURES` order with no
  feature twice. One tooltip line per feature, matched by the feature's name as the client spells
  it, its numbers read in the description's order (the Lute's armor, stats, resistances; the Mana
  Well's mana, then its 5 seconds). The tooltip is kept once per Camp Benefits as soon as a read
  finds anything; an empty read is tried again at most every `LINE.RETRY` seconds.
- The Round countdown and ring use `SetCooldownFromExpirationTime` with the aura's deadline and
  full duration. A buff that was already running before login can have a negative reconstructed
  start, so it is not handed to the cooldown's start-time setter. Missing, zero or expired
  deadlines leave the countdown hidden until an aura update supplies a valid one. Simple keeps
  its duration-backed timer line.
- The time ring's color by time left: green above 30 minutes, yellow above 5, red below. Nothing
  fires as the buff runs down, so each color change is timed, and a generation number throws away
  a timer armed for an older state.
- Show Active Camp Buffs (Off, Always, On Mouseover): a profile that never picked one follows the
  old on/off switch (`campBuffs`), so nobody's setting changes. On Mouseover the buff lines stay
  written but invisible until the icon is hovered, and the icon only takes the mouse then, so
  clicks and camera drags otherwise go through.
- Sitting is a click on the fire, not a second icon: a button beside the reminder doubled its size
  for one emote. The click only takes the fire's own square, so Camp Nearby still lets every other
  click through, and only while a campfire is in range, the only time /sit can refresh the camp.
  A lit fire with no Camp Benefits is the hint: grey says no camp, lit says a fire is here to sit at.
- The Round icon's plate follows the theme's Panels color (`ns.ThemeTint`), and a black circle one
  pixel wider behind it is its 1px round border. The black disk extends past the time ring on both
  sides, edging it.
- The Simple bar: nothing draws outside it, so it can sit anywhere. Every state keeps the fire, the
  words and the bar's size the same; the down states leave the time's place empty. It is never
  narrower than four wide bonuses need at its text size (`CAMP_MIN_LABELS`), and its text never
  under 11. `FONT_LIFT` raises its words: the Naowh font sits low. Its fire has no plate or ring:
  the art (transparent round its fire) sits on the bar's own backdrop, `CAMP_ART_CROP` trimming its
  empty margin so the fire fills the square. `Parts.LabelRow` sets the Addon Font on the labels it
  makes, so the bar's font goes on after.
- Both looks keep the fire on one screen spot: Round's centre is the Simple fire's centre. The saved
  spot is LEFT for Simple and CENTER for Round (an older corner point is the Round icon's),
  converted to the current style once, when placed, from the settings alone. A setting change
  refilters the last bonuses read (`FilterBar`), so the bar repaints in every state, resting too.
- Camp Nearby shows when a campfire is in range and the camp needs a refresh: no Camp Benefits, or
  less than Alert Under left. With Simple it shows only while Camp Benefits is still up and low:
  once it is gone, the bar's own Camp Nearby pill says it. It fades in, breathes and fades out
  through animation groups, never OnUpdate. With no background its words keep the card's shadow.
  `UNIT_AURA` fires often, so its timer is only set again for a new expiry, and a new Alert Under
  disarms the old one.
- Right-click (or Ctrl-click) hides Camp Nearby until you leave the campfire's range. Only right
  clicks are taken (`SetPassThroughButtons`, set out of combat), and it takes the mouse only while
  Ctrl is down, so left clicks and camera drags still reach the world.
- Low Health offers healthstones then potions, best first, from the core's lists
  (`ns.HEALTHSTONES`, `ns.HEALING_POTIONS`, in `Shared/Game/Consumables.lua`), which the Macros
  module's NF Health reads too, so either works with the other off.
- Low Health never compares the health: a step curve turns the health percent into 1 below the
  threshold and 0 above it, and the engine applies that as the frame's alpha itself, so it works in
  combat even where health is secret to addons. The curve is flat on both sides of the threshold,
  so it gives the same answer whether it snaps to the point before or the nearest point.
- The Low Health sound and glow need the health itself. Where the client hands it over readable the
  sound plays once per dip below the threshold and the glow runs only while low; a secret read skips
  the sound and leaves the glow running under the alpha. The Font Size is the warning's; the count
  keeps its size and follows the font and outline.

## Checking

- `lua Tools/regression/test-buff-reminders.lua`: which reminders show, the item menu, the card.
- `lua Tools/regression/test-campfire-simple.lua`: both Campfire looks, the reader, Camp Nearby and
  the cards' previews.
- `lua Tools/regression/test-icon-look.lua`: Low Health's text.
- `lua Tools/regression/test-robin-final.lua`: consumable entries and the Round campfire.
- `lua Tools/regression/test-combat-perf.lua`: the buff reminders' cost in a raid.

## Class Buff Tracker

- Off by default, under AuraBuffs / Class Buff Tracker, with its own HUD Editor mover.
  It shows known personal and raid buff families of your class, following the existing
  personal and raid buff picks independently of the reminder switches.
- Secure spell buttons target `player`; their configured spell and layout change only
  outside combat. Enabling, disabling or changing picks in combat waits for
  `PLAYER_REGEN_ENABLED`. Alternative-buff families cast their first known spell;
  the full native spell tooltip describes that cast.
- Blizzard's `CustomAuraContainerTemplate` overlays active icons during combat using
  helpful spell-ID filters, and an own-caster filter for aspects. No code reads the
  managed icon, its visibility or hidden aura data. Weapon enchants and target debuffs
  are excluded. The existing consumable and group reminders are unchanged.
- Missing-buff glow is off by default and updates only when aura data is readable.
  It shares one bounded scan across all icons, reusing scratch tables. A secret ID,
  unknown required caster or incomplete scan suppresses the warning. Combat entry
  clears glows immediately, before lockdown may become true; combat end refreshes them.
- Glow uses the shared Pixel/Standard wrapper plus an optional Gold style using the
  embedded library's proc outline, without an opening flash. Other callers keep their
  existing choices. Gold is the tracker's default style, with glow itself still off.
- `HOME_Y` puts the tracker below the default reminder position. `ACTIVE_LEVEL` puts
  the managed icon above its grey placeholder. The shared icon crop, one-pixel inset
  and outlined short labels match the suite's bars. Labels fit the icon spacing.
- No frames or events are created before first enable. Disabling unregisters events,
  disables managed containers and stops glows. Construction failures hide the tracker,
  print an unavailable message and retain the original error through the error handler.
- Out of combat, a buff you have is left off the row and the rest close up, so the row is
  only what is missing; one that drops comes back. The buttons are secure, so the row can
  only be laid out out of combat: in combat it holds as it was, Blizzard's container still
  showing the active icons on it, and combat end lays it out again. Aura data that cannot
  be read keeps every button. Unlock Mode shows every button so the row can be placed.
- An aura change reads the auras once; only one that changes which buffs are active lays
  the row out again (a second read, by the layout).
- Opening or closing settings updates only the mover overlay and missing-buff glow,
  without hiding unchanged buttons. Tooltip ownership is cleared when its button hides.
- User confirmed self-casting, labels, tooltips and settings/glow behavior in the Forever
  client. Restricted-instance coverage and before/after in-game screenshots are missing.
- Offline checks: `lua Tools/regression/test-class-buffs.lua` covers lifecycle, native
  tooltip wiring, secure self-cast attributes, one shared scan, buff removal, unknown
  data, combat deferral, feature disable and mover open/close.

- Gold Glow's Thickness control widens the outline with up to six copies of its native
  artwork, each half a UI unit farther out. The icon keeps its size. The shared glow
  wrapper owns and stops every keyed layer; changing thickness replaces the old layers.
  Pixel Glow retains its direct stroke-width control, and Standard Glow is unchanged.
