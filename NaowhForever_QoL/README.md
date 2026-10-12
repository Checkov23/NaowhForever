# Quality of Life

The QoL features, shipped as their own addon (`NaowhForever_QoL`): one file per feature, each
with its rules, its drawing and its settings card at the end. They share one settings store,
`ns.QoLSettings`, which stays in the core (`Core/Settings.lua`) because the core and other modules
read it too; its on/off switches come from `ns.FEATURES.qol` (`Core/Features.lua`). Turn the addon
off (Settings > Modules) and every QoL feature is gone, with the Top Bar, which needs it.

## Layout

```
NaowhForever_QoL/
  NaowhForever_QoL.toc             its metadata, and one file line: QoL.xml
  QoL.xml                          every file, in load order
  Constants.lua                    the numbers, colors and patterns several QoL features share (ns.QoLConstants)
  Interface/
    SpellEfficiencyData.lua  each mana spell rank's healing or damage (ns.SpellEfficiencyData), generated
    SpellEfficiency.lua Mana Efficiency on spell tooltips, its Preview Tooltip and the Tooltips card's preview
    GlobalCopy.lua      /copy, and tooltip IDs with their copy shortcut (the card is Shared/UI/CopyCard.lua)
    HideClutter.lua     UI Clutter
    UnitNames.lua       Names Over Heads: guild names, guild titles and player titles with player names
    ChatZones.lua       Chat Zones
    TownMailboxes.lua   mailboxes by map (ns.TownMailboxes), generated
    TownSpiritHealers.lua  spirit healers by map (ns.TownSpiritHealers), generated
    TownTravel.lua      boats and zeppelins by map (ns.TownTravel), generated
    ZoneExits.lua       each zone's exits (ns.ZoneExits), generated
    TownMap.xml         TownMap.lua, the town pin templates, then MapPinsPanel.lua
    TownMap.lua         the town pins on the world map and minimap, and the Map Options and Map Pins cards on the Map & Pins tab, /naowh townaudit (ns.TownAudit)
    MapPinsPanel.lua    the Town Pins button on the world map and its drawer of which town pins show
    MapSize.lua         Map Window: the windowed world map scaled by a corner grip, moved by its title bar
    MapOverlays.lua     each zone map's explorable areas (ns.MapOverlays), generated
    Unexplored.xml      the unexplored pin template, then Unexplored.lua
    Unexplored.lua      Unexplored Areas on the world map
    ZoneLevelsData.lua  each zone's level range (ns.ZoneLevels), generated
    ZoneLevels.lua      Zone Levels on the world map
    SkyborneData.lua    the Skyborne spots every player starts with (ns.SkyborneSpots), MIT notice inside
    SkyborneSpots.xml   the Skyborne pin template, then SkyborneSpots.lua
    SkyborneSpots.lua   Skyborne Spots on the world map
    Waypoints.lua       the Waypoint Pin (ns.WaypointPinOn)
  Cursor/
    CursorClip.lua      Combat Cursor Clip
    Crosshair.lua       the Crosshair (ns.MeleeRangeSpell)
    MouseRing.lua       the Mouse Ring
  Combat/
    CoTank.lua          the Co-Tank Frame and its debuffs
    HealerMana.lua      Healer Mana
    CombatAlert.lua     Combat Alert
    CombatTimer.lua     Combat Timer
    CursorCooldown.lua  Cooldown at Cursor
    GcdTracker.lua      GCD Tracker (ns.GCDSpell)
    FocusCastBar.lua    the Focus Cast Bar
    StealthReminder.lua the Stealth Reminder
    PetTracker.lua      the Pet Tracker
  Questing/
    BuffThanks.lua      Buff Thank You Message and its line editor
    Invites.lua         the people you keep an invite button for and their editor (ns.InvitePerson,
                        ns.InviteAll, ns.ShowInviteEditor)
    GroupButtons.lua    On-Screen Buttons (Invite, your invite buttons, Invite All, Disband)
    FreeForAll.lua      Always Free for All, the party loot method while you lead
    TalentPoints.lua    the unspent talent points reminder
    QuestAutomation.lua accept, hand in and share quests, saved reward picks
    PlayerHistory.lua   Player History (ns.PlayerHistory), read by the Naowh Inspect panel
    Disband.lua         removing everyone from your group (ns.DisbandGroup), for the Disband button
    Trainer.lua         the trainer popup and rank swaps (ns.TrainerRankCheck, ns.TrainerForgetKept),
                        and its card on the Training Planner's page
  XP/
    GroupXP.lua         Group XP
    XPTicker.lua        XP per Hour (ns.ResetXPTicker)
    XPBar.lua           the XP Bar (ns.XPBarColor, ns.ResetXPBarSession, ns.ResetXPBarLayout)
  Loot/
    DeleteConfirm.lua   Type DELETE For You, and the Looting card
    Durability.lua      the low durability warning
    LootConfirm.lua     the retired loot confirmation skip, inert
    EquipmentReminder.lua  Equipment Reminder (ns.ShowEquipmentReminder, ns.CaptureEnchants)
    AuctionPrices.lua   Auction Prices (ns.AuctionPrice, ns.AuctionAge, ns.AuctionScanSummary)
    FoodBar.lua         the Food & Drink Bar (its food and potion lists are Shared/Game/Consumables.lua)
    BagSpace.lua        Bag Space (ns.BagSpaceRescan; ns.BagSpace for its ignore list)
    BagSpaceIgnore.lua  Bag Space's Ignore List window (ns.ShowBagSpaceIgnoreList)
    Alts.lua            your characters per realm and faction (ns.AltRealm, ns.AltList, ns.OpenForgetAltMenu)
    LootFeed.lua        the Loot Feed, gold per hour and quick loot (ns.ResetLootFeedSession)
    Restock.lua         the Restock Reminder, Auto Repair and Auto Sell Junk
    ScrapMarker.lua     the Scrap Marker (ns.ScrapMarker), read by Bag Space and the Scrap List
    ScrapList.lua       the Scrap List window (ns.OpenScrapList, /nf scrap)
    Mail.lua            Alts and Attach buttons at the mailbox, the expiring mail warning
  Travel/
    FlightData.lua      each flight route's flown length (ns.FLIGHT_ROUTES), generated
    Flight.lua          the Flight Timer, Flight Games and flight times on the flight map
    AimTrainer.lua      the Aim Trainer (/nfaim, ns.AimRules, ns.AimPlay, ns.AimOffer)
    AimBoard.lua        the Aim Trainer's leaderboard (ns.AimBoard)
    QuizData.lua        the quiz questions (ns.QUIZ_QUESTIONS)
    Quiz.lua            the Quiz (ns.ToggleQuiz, ns.QuizOffer, ns.QuizDismiss)
  System/
    SlashCommands.lua   Custom Slash Commands and their editor (ns.SlashCommandList, ns.RefreshSlashCommands)
    Performance.lua     QoL > System > Performance: recommended game settings and their backups
  Media/
    crosshair_ring.tga  the Crosshair's ring
    MouseRing/          the Mouse Ring's rings, glows and trail
  README.md           this file
```


## Why

- QoL is optional: the base and every other module read what they need from it behind a nil
  guard, never at load, and the data they share with it lives in the core (`Core/Settings.lua`,
  the Alerts group in `Core/AlertStack.lua`, Naowh's setups in `Core/Profiles/Setups.lua`) or in
  `Shared/` (the copy cards, the town NPCs, the food and potion lists).
  `Tools/regression/test-module-boundaries.lua` checks it.
- The Top Bar's card sits on QoL > Interface, so the Top Bar depends on QoL: switching QoL off takes
  it along; turning the Top Bar on in the onboarding turns QoL on.
- The Trainer Popup card is declared here, on QoL > XP with Talent Points, so it goes when QoL is
  off. The Bag Space and Food & Drink key binding names live in `Core/Commands.lua`, so the key
  bindings read right with QoL off, where the Bag Space key says so.
- QoL loads after the core now, not between the profile strings and the Badges: nothing in the core
  reads a QoL field at load.
- `Constants.lua` holds the numbers several features share: `PERCENT` (100), `ROUND` (0.5, added
  before `math.floor` to round to the nearest), the icon crops that cut the game's own border off
  an icon (`ICON_CROP` 0.08 to 0.92, or `ICON_CROP_TIGHT` 0.07 to 0.93 for a thinner cut), and
  `HINT_RGB`, the light blue of the map pins' hint lines, which a theme's lighter Accent replaces.
  It loads right after the QoL store, before every feature.
- `Constants.lua` also holds what more than one feature means the same way: the time units
  (`SECONDS_PER_MINUTE`, `SECONDS_PER_HOUR`, `SECONDS_PER_DAY`), `THOUSAND` and `MILLION` for
  short numbers, `PERMILLE` and `TENTHS` for a percent with one decimal, `PARTY_SIZE` (4 others)
  and `RAID_SIZE` (40), `PLAIN_BAG` (bag type 0, a bag of no profession), `SELL_PRICE` (11, the
  vendor price's place in `GetItemInfo`'s returns), `GUID_PATTERN` (a player's GUID), `EDGE_OUT`
  (-1, a pixel inset that puts an edge just outside its frame), `WHITE_RGB`, and the cursor
  cards' preview fit and offset (`CURSOR_PREVIEW_FIT`, `CURSOR_PREVIEW_Y`).
- A settings row's slider range is a named table at the top of its file (`WIDTH_RANGE`,
  `TEXT_RANGE` for a Look's text size, ...). The ranges two features share with the same meaning
  are in `Constants.lua`: `VOLUME_RANGE` and `SPEECH_RATE_RANGE` for Text to Speech (Combat Alert,
  Focus Cast Bar), `OPACITY_RANGE`, `DOT_RANGE` and `SOUND_REPEAT_RANGE` (Crosshair, Mouse Ring).
  Ranges every module shares (`HUD_TEXT_RANGE`, `ALPHA_RANGE`, `SCALE_RANGE`, `PIN_SIZE_RANGE`),
  the percent scale, the preview stage's note and margin, the icon crop, the black edge
  (`BORDER_RGB`) and the flat texture (`WHITE`) come from `Shared/Style.lua`.
- Combat Cursor Clip saves your own `ClipCursor` value in the account settings while it holds it
  at 1, so after a crash or a killed client mid-fight the next login puts it back, instead of
  taking the held 1 for your setting.
- Loot Confirmation Skip is retired: its file registers no events, even for profiles that had it
  on, and keeps the saved choice so it can be brought back.
- Type DELETE For You drops the second paragraph of `DELETE_GOOD_ITEM` (the "type DELETE"
  instruction), which no longer applies once the box is filled in.
- Filling the delete box from code left Yes greyed out on Forever, so the dialog's own
  `EditBoxOnTextChanged` check is run straight after, which enables Yes when the text matches.
- The delete dialog sizes itself to its text only on show, and the box sits under the text, so
  it is resized after the item link is added.
- The Alerts group (Camp Nearby, Talent Points, Durability, Restock, Pet Tracker) is in the core
  (`Core/AlertStack.lua`, see Core's README), since Aura Buffs' Camp Nearby uses it too.
- The Pet Tracker skips Pet Missing for a hunter with Lone Wolf. `LONE_WOLF` (415370) is the
  talent node spell in the talent data; `LONE_WOLF_TAUGHT` (409979) is the spell it teaches,
  the one seen known in the Forever client. Either counts.
- Durability is fully red at or below 15% (`FLOOR_PCT`). Its card is fitted to the text only with
  a background, so what is anchored to it keeps its spot; the Unlock Mode preview shows 20%.
- UI Clutter's Hide Red Error Text is the same switch as Blizzard's `/uierrorsoff`.
- Hide Bag Bar fades `BagsBar` with SetAlpha and turns its buttons' mouse off, never Hide: Edit Mode lays the bar out, and its Show and Hide are protected in combat.
- The event toast frame is not in every client. Its own hide button stays usable while shown,
  and toasts are closed 0.05s after they display.
- `showTutorials` is the Show Tutorials box in Blizzard's options. What you had before Turn Off
  Tutorials is kept in the account store and put back when it goes off, even in a later session.
- Names Over Heads writes the game's own `UnitNamePlayerGuild`, `UnitNameGuildTitle` and
  `UnitNamePlayerPVPTitle` and keeps nothing: the game saves them. Forever's options have no box for
  them (only your own, NPC and player names), and a row shows only where the client has its setting.
- In-game cinematics carry no ID, so one is known by the zone and subzone it plays in. Skipping
  one waits a frame so CinematicFrame has taken the start before it is cancelled.
- Finishing a movie shows UIParent again, which combat lockdown would block, so a movie is never
  skipped in combat.
- On-Screen Buttons: Invite is a secure button running the game's own `/invite`, which invites
  your target; run from it, the game's code reads the target's name, so it works in combat.
  Disband removes everyone through addon code (`ns.DisbandGroup`), which the game allows only out
  of combat.
- Because Invite is secure, the bar is built, shown, hidden and laid out only out of combat; a
  change in combat waits for `PLAYER_REGEN_ENABLED`.
- Combat Timer's Card background is the panel the old Show Background toggle drew (black, or
  the theme's Background); the old on and off are saved as Card and None.
- Combat Timer shows while fighting, while unlocked, and after a fight when Keep After the Fight
  keeps the last one up.
- Combat Alert's Game Default voice is saved as `""` and speaks in the voice the rest of the
  addon uses.
- Speech is made on the game's own thread and the client waits for it, so Combat Alert speaks a
  frame after the combat change instead of stacking on it while every other addon handles it.
- Cooldown at Cursor's time is a duration object the game counts down itself (swipe and text),
  so it works in combat, where Forever keeps cooldown numbers secret.
- The global cooldown alone brings no Cooldown at Cursor card: the game raises the same error for
  it, and its `isOnGCD` flag stays readable in combat. A press and a cooldown error within 0.3s
  (`MATCH_WINDOW`) are one.
- Buff Thank You Message: the game only names a caster who has a nameplate, is your target or
  mouseover, or is in your group; for anyone else it can send the built-in /thank instead. An
  addon's custom /emote, like /say, is blocked outside instances without a key press, but
  `C_ChatInfo.PerformEmote` is not (tested on Forever from a `C_Timer` callback).
- Its buff lists hold every rank and group version of each class buff another player can give
  you (Wowhead Forever). They are kept in the file, not read from Auras & Buffs, because that
  module can be turned off. The Blessing list is Might, Wisdom, then Kings, Salvation and Light,
  then Protection, Freedom and Sacrifice; `OTHERS` (always on the Whisper Lines) is Amplify Magic,
  Dampen Magic, Fear Ward, Power Infusion, Levitate, Innervate, Unending Breath, Detect
  Invisibility, Water Breathing and Water Walking.
- Other players decide when it speaks, so at most 3 thanks go out a minute (`SENT_MAX`,
  `SENT_WINDOW`): a crowd buffing you gets a few, not a flood.
- Thanks are kept per caster GUID, not name: Forever's first names are not unique, and two
  players called the same each get theirs. Who was thanked is kept until the feature goes off.
- The line editor's box fills the scroll area down to its buttons and grows past it with the
  lines. `Parts.ShowBeside` sets its height once, so its bottom is tied to the options window's
  too, to follow a resize.
- The Crosshair checks melee range with one ability per class, its lowest rank (Forever keeps
  every rank known). Druids depend on form: Claw in Cat Form (form 1), Maul in Bear and Dire Bear
  (5 and 8). Shamans without Stormstrike and casters have none; Melee Spell ID sets one of your
  own, and the Mouse Ring's melee check uses the same (`ns.MeleeRangeSpell`).
- The Crosshair's out-of-range sound plays on leaving range, not on picking a target already out
  of it. Range is read every 0.05s (`TICK`) only while there is an attackable target.
- The crosshair ring texture is 512 texels wide; its coordinates are inset half a texel so the
  edge does not bleed, and its position is rounded to whole pixels at the UI scale.
- `ns.BestFoodAndDrink` (the bar's buttons and the Macros module's NF Food) and `ns.HEALTHSTONES`
  and `ns.HEALING_POTIONS` (NF Health and Aura Buffs' low health reminder) are in
  `Shared/Game/Consumables.lua`, so each works with QoL off.
- The bar was on the Macros page until 0.5.24; a profile's settings for it move here once.
- The Food & Drink buttons are secure, so the bar is built, shown, hidden and pointed at items
  only out of combat. Its key bindings (Bindings.xml) work once the bar is switched on, as that is
  when the buttons exist.
- The Food & Drink Bar's card sits on the Consumable Bar's page while that module is on (its addon
  loaded, before QoL by `OptionalDeps`, and `consumableBar` set), and on Loot & Items otherwise. A
  card's page is chosen at load, so switching the Consumable Bar on or off moves it at the next
  reload. Its settings keep their `foodBar*` keys either way.
- Its count, key text and anchor are the Consumable Bar's own rows and placement
  (`Shared/UI/ItemBar.lua`, `Shared/UI/Anchor.lua`); Show Count starts on, as the bar always showed it.
  It follows the Consumable Bar, or any Naowh Forever element, through the HUD Editor's Anchor.
- Its icons are cropped like the rest of the addon's (`ItemBar.CropIcon`). Before, it showed the
  full item art with the game's rounded border; for that look on this bar alone, add
  `ItemBar.CropIcon(button.icon, 0)` after `ItemBar.SecureButton` in `Build()`.
- Alts are kept per realm and faction, because characters there can mail each other. Forever has
  been seen to return "Name-Realm" for the player, and the mail box wants the bare name, so the
  name is cut at the dash.
- Forget a character exists because deleted or transferred characters otherwise stay in the
  counts and the Alts list for good.
- The Forever bank is the character bank tabs; a tab not bought has no slots.
- The mail scan (attachments, letters waiting, the soonest expiry) waits a second for a burst of
  `MAIL_INBOX_UPDATE` to end, as Open All fires one per letter.
- Alt Item Counts are added to a tooltip only when some of the item is somewhere other than the
  bags you are looking at.
- Auction Prices keeps one price table per auction house (realm and faction), as prices differ;
  the key is worked out once because it is read on every item tooltip.
- The Scan Prices button sits after the last auction house tab added through LibAHTab
  (Auctionator's Shopping, Selling, Cancelling and Auctionator), read from the library's
  `internalState.Tabs`, which is not public API; without it the button sits next to Auctions.
  Those tabs can be made on the same AUCTION_HOUSE_SHOW, after us, so the button is placed again
  a frame later.
- Blizzard allows one full auction house scan every 15 minutes (`SCAN_COOLDOWN` 900s). The
  listings arrive all at once and are read 1000 a frame (`CHUNK`), so a large auction house does
  not stall; bid-only listings are skipped. The profession window's crafting profit reads these
  prices, so it is refreshed after a scan.
- The GCD Tracker reads only the player's own casts, and those are never secret.
- Forever has no dedicated global cooldown spell, so the GCD Tracker watches one baseline spell
  per class with no cooldown of its own (`GCD_SPELLS`): any cooldown it shows is the global
  cooldown (`ns.GCDSpell`).
- Its blue glow and border while a cast runs is the shipped `GCD_BLUE`; `ns.ThemeTint` swaps in
  the player's Accent.
- Casts within 0.3s of each other stack in lanes (`STACK_WINDOW`). Login and loading screens fire
  casts of their own, so nothing is recorded for 5s after them (`LOGIN_QUIET`). A channel's ticks
  come back as casts of the same name, so they are skipped.
- The activity bar adds a segment per second of casting or global cooldown; the tracker redraws
  every 0.025s only while something is on it, and stops its OnUpdate once it is empty.
- Global Copy: frame text can be secret, so every read of a region's visibility and text is
  checked with `canaccessvalue` and pcalled. /copy reads the frames under the cursor, or failing
  that every visible frame the cursor is over.
- Tooltip IDs are classified (`issecretvalue`, `canaccessvalue`, `issecrettable`) before any value
  is read, compared, formatted or parsed; an ID the game keeps hidden shows as Hidden or not at
  all. NPC IDs come only from Creature and Vehicle GUIDs, never players'.
- The copy card links Wowhead's Forever database, built from the game's own client, classic
  items and all; its Classic link is for the odd page Forever's has not got yet (the game cannot
  ask Wowhead which). The card is `Shared/UI/CopyCard.lua`: `ns.ShowCopyCard` is the same card for an
  ID tooltips do not cover (the Dungeon Journal's quests); `ns.ShowCopyLine` puts any line on it.
- The tooltip ID line is added once per build: it is still there unless the game rebuilt the
  tooltip (a rebuild clears the lines but keeps the same info). It never hooks
  `OnTooltipCleared` for this (see the Badges plate).
- The copy shortcut hint reads like the addon's other tooltip hints ("Ctrl-Shift-C: copy ID or
  Wowhead link") and is made once per key.
- While a copy card is open its edit box owns the keyboard, even if combat starts; the keyboard
  watch goes back on when it closes.
- Chat Zones: the game never sends a stranger's zone, so a name is tagged only once it shows up
  in the Group Finder results, the guild roster, the friends list, your group, a /who you ran, or
  an answer from another player running the addon (asked with an addon whisper the first time
  they speak). A message from someone not yet known goes through untagged.
- Names are keyed as the game's `Ambiguate(name, "none")` gives them (same-realm players without
  the realm, others as Name-Realm), so every source keys alike. The chat event carries the
  speaker's GUID, which gives their class even for a stranger.
- Forever has no character friends list, only Battle.net friends.
- A /who with one result comes back as a chat line, not `WHO_LIST_UPDATE`, so that is read too:
  the game's own format strings become patterns, `%d` the level and the last `%s` the zone.
- [Where?]: the game runs a /who only from a click or keypress, so a stranger's whisper gets a
  link to click. "addon:" links reach EventRegistry's SetItemRef inside the click itself.
- Asking: "Q <their GUID>", answered "A <own GUID> <level> <zone>". An answer is kept only for a
  question still open (30s, `ANSWER_WAIT`), from the player whose chat line carried that GUID.
  The same player is asked again after 10 minutes at most, one whisper a second, 20 queued;
  answers go out at most 10 per 10s and once a minute per player.
- Forever's addon message sender is "Name Surname" where the chat author is only "Name".
- The chat filter runs once per chat frame per message, so it only reads and queues.
- Group Finder: the leader's zone on each row, every member's zone in the tooltip.
  `Blizzard_GroupFinder_VanillaStyle` loads on demand, so its functions are hooked once it has.
  The row's role icons are shrunk to 0.75 to make room; a row's group data on the right is 160
  wide (155, 2 in). Forever's rows differ from Classic Era's, so the zone takes the activity
  line's font and stops short of the role icons, measured on screen (the icons are scaled).
  The game sends only the leader's zone; other members show one if it is known elsewhere.
- A guildmate's zone may have changed since the last roster, so guild chat from one not fresh
  asks for the roster again (the game throttles that).
- The Co-Tank Frame's debuffs go through Blizzard's aura container (`CustomAuraContainerTemplate`),
  the only thing that can draw secret aura data. Button calls are denied while auras are secret,
  so a restyle waits for them to clear; `InitButton` runs once per engine button, the only time
  parenting to the button is allowed, and fonts are set before the engine is handed a font string
  because it writes text into them straight away.
- Righteous Fury is an aura, so it is read only while auras are not secret; the last answer
  stands in until they are. "Tanking" is the Threat Meter's test: tank role, Bear or Dire Bear
  Form or Defensive Stance (forms 5, 8 and 18), plus Righteous Fury for paladins. The other tank
  is the tank role or the raid's Main Tank assignment.
- Debuffs a tank carries that are no danger are left off the row (`HIDDEN_DEBUFFS`): Weakened
  Soul, Recently Bandaged, Resurrection Sickness and Forbearance, by Forever's spell IDs.
- One aura group per filter, so the icon cap is the whole row. `isBossOrRoleAura` is the engine's
  own "boss aura or role aura" test, which needs one group; the default sort has no boss
  tiebreak, so a wide group would fill with older trash debuffs first.
- The debuff row's edge that meets the bar mirrors the bar corner (a row above puts its BOTTOM on
  the bar's TOP); Centred wraps away from the bar, not back through it; the flow starts on the
  far side of its travel (RIGHT begins at a LEFT corner). A vertical row is one column, with
  0.4 of slack so the engine's rounding does not drop the last icon.
- Debuff time is formatted by the game (a debuff's time can be secret): bare seconds up to 90,
  minutes up to 90, then hours, rounded up so it never reads less than is left. The dispel-type
  ring is four plain white strips the engine shows and tints, since which aura gets them is
  secret. The bar under the icons is click-to-target, so the icons take no clicks.
- The Unlock Mode preview draws plain textures, not engine buttons: the engine only draws auras
  the unit really has.
- Dragging the Co-Tank Frame places it on the screen again. Anchored to another frame by name, it
  sits centre on centre plus the X and Y offsets; a name that matches no frame falls back to the
  screen.
- Healer Mana is read from the units themselves, so nobody else needs the addon. A healer has the
  healer role, or no role and a healing class. Each healer has a watcher frame listening to that
  unit only, so the rest of the raid's power and aura events never reach it; drinking is read
  from each aura event's own changes; a burst of roster events or mana ticks is one redraw
  (0.25s). Unit names are made once, so a roster pass makes no strings.
- Drink is found by the name of spell 430 (in the client's language), which is the buff's. Auras
  go secret during boss pulls; the last answer stands until they clear.
- Unit data can come back secret in restricted content, and is never compared then. While a
  share is secret, each healer keeps its place from the last plain sort and anyone new goes last;
  the share is written by the client: `UnitPowerPercent` takes the unit, power type and a 0 to 100
  curve (none of them secret) and hands back the share, secret or not, for `SetFormattedText`.
  A druid in a form keeps the last share it showed.
- Mana under 60% shows in the running-low colour and under 30% in the nearly-out colour. The cup
  icon is cropped 0.07 inside the border and dropped 1px, as the Naowh font sits low in its line.
- Group XP is fed by addon messages from every member running Naowh Forever; the setting only
  shows the bars. "2 guid level xp max" is someone's numbers and "R" asks everyone for theirs.
  Numbers are kept only for a GUID in the group, and someone who leaves keeps nothing behind.
- Forever's addon message sender is the character's full name with surname, which no unit API
  returns, so Group XP members are matched by GUID.
- Addon messages are not sent in combat, so the latest numbers go out once it ends. XP arrives
  with every kill, so sends are held to one every 2 seconds.
- Group XP's row sizes are at the default font size (12); a bigger font makes the rows taller and
  the names wider. Unit identity can come back secret in restricted content; those members are
  skipped.
- Focus casts are secret, so the Focus Cast Bar hands them only to setters that accept secrets
  (`SetTimerDuration`, `SetAlphaFromBoolean`, `C_CurveUtil.EvaluateColorFromBoolean`), and
  `interruptedBy` is never tested for truth directly. Whether your interrupt is ready is a secret
  boolean in combat; no duration object at all means no cooldown running.
- Forever cannot tell which spec you play, so your interrupt is the first you know of Pummel,
  Shield Bash (warrior), Kick, Counterspell, Earth Shock, Silence and Feral Charge.
- The interrupt-ready tick is fixed at the cast's start: summed with the cast's elapsed time only
  when both numbers are readable, otherwise the kick's remaining time alone, which is right at
  the start.
- An interrupted cast is held where it stopped, in the interrupted colour, for the fade time.
  Apply Theme takes the theme's Accent for the ready colour and its Background behind the bar.
- `ns.FLIGHT_ROUTES` (FlightData) is each Forever flight route's flown length in yards, keyed
  `fromNodeID * 10000 + toNodeID`, generated from the TaxiPath data of WoW Forever build
  1.60.1.69913.
- Flight Games (`flightGame`) is the one choice of what opens by itself when a flight starts: the
  button only, the Quiz or the Aim Trainer (Off hides the button). It was migrated once from the
  old `quizFlight` and `aimAutoFlight`.
- Flight times come from the route data at 30.4 yards a second (`FLIGHT_SPEED`), fitted to
  measured Classic flight times. Frequent Flier, node 110300 of the Adventure Legacy tree (1188),
  makes flight path mounts 20% faster; Legacy perks are bought per character, and a character
  without the tree has no config for it.
- A route is its stops, start first, each with the seconds to reach it. Once a hop is missing
  from the route data, the time is unknown from there on and the time learned on that route
  stands in for the whole flight. A flight shorter than 10 seconds was cut short or never left,
  and one landed early did not fly the route, so neither is learned.
- The flight master's map shows the same time the timer starts from: the route data's, else the
  learned time, only for a destination you can fly to. It is hooked the first time the setting
  is on, never before. The classic flight map's buttons share one global OnEnter; the newer
  Flight Map's pins take theirs from a mixin that exists once `Blizzard_FlightMap` loads (pins
  made before the hook keep the old one until a reload).
- Below 50% Background Opacity (`SHADOW_BELOW`) the card's text gets a shadow and its muted labels
  go bright, so they read over the world. Background Opacity fades only the card's and its
  buttons' backgrounds and edges, never the route, the track or the text.
- The client has no landing event and boarding lags the purchase by a moment, so a 0.5s poll runs
  only between buying a flight and landing; the card itself redraws smoothly while shown. A
  reload mid-flight does not know the route, so it only counts up and is not learned.
- Landing early (ours or Blizzard's own leave button) comes down at the first stop still ahead,
  so the flight then ends there.
- Blizzard's Request Stop is its vehicle leave button. It sits in the action bar's protected
  layout, so it is faded (SetAlpha) rather than hidden, and only outside combat.
- The Flight Timer's mover reports offsets in the timer's own scaled units; they are saved in
  screen units so the Scale slider resizes it in place.
- The Aim Trainer's leaderboard sends your best in each mode to your group and guild while Share
  My Scores is on, once you have one (nothing is registered before your first best), and keeps
  the bests others send account-wide in `aimBoard[mode][GUID]` (Forever names are not unique) for
  the leaderboard view and the results card's rank.
- Leaderboard messages on "NaowhAim": "2 B guid mode score accuracy class day" is a best ("-"
  for no accuracy) and "2 R guid" asks for everyone's. They are sent after login (10s to settle),
  on joining a group, on a new best and in answer to a request (spread over up to 3s, at most
  every 10s a group channel and 30s the guild), never in combat. What arrives is checked, rate
  limited (12 a minute per sender, 400 senders) and capped (200 entries a mode, the weakest and
  oldest dropped first). A best is kept only from the player its GUID names, found in your group
  or guild (`ns.SenderIs`), and an entry saved under one name is not replaced from another.
- The Aim Trainer opens from /nfaim, the Flight Timer's Games button or a flight starting (Flight
  Games). A miss costs 50 points and pops a "-50" where it landed. Every round is the same for
  everyone (fixed 30s length, target size and play area), so bests compare on the leaderboard;
  `ns.AimRules.Ceiling` caps a believable score (20 clicks a second at most) so a forged one is
  dropped.
- The Aim Trainer file sits close to Lua 5.1's limit of 200 locals in one chunk, so its words
  are one `TEXT` table and its drawing helpers hang off `Look`.
- Bag Space shows the cheapest things in your bags as icons on a small card under your free
  slots, to delete, sell or ignore. Its Background is the card, a soft fade or none
  (`Parts.HudBackdrop`); the icons keep their own edges in each. Its Font Size is the header's
  (12 is the size its other measures are drawn for); the bag, the header line and the prices
  scale with it. The card is the house panel at the Flight Timer's fill (0.85) round a slim
  header (the bag, free slots out of your total, Scrap Marker's "+N", the Stack button) over a
  cell per item (its icon, its marks, its price under it).
- Bag Space's cells and gap shrink with the Icon Size below 36 (the size the rest is drawn for):
  the gap, the price column and the price font follow it, to a floor, so a small row stays
  compact. At 36 and above nothing changes. Reverse Order only swaps which end the cheapest
  cell takes: the cells fill the same spots, so the card and its anchor do not move.
- Bag Space's scan reads every bag slot, so its container and item APIs are aliased once and the
  settings a scan reads for every slot are read once at its start. Scan entries are pooled and
  reused; a scan runs after every loot and must not leave tables behind. The row's buttons point
  into those pooled entries, so a scan always redraws the row too.
- Never offered, whatever they are worth: reagents (class reagents such as Flash Powder and
  candles), projectiles, quivers, quest items and keys (item classes 5, 6, 11, 12 and 13), items
  in an equipment set and BiS items. You need them, or they free no bag space.
- An item's worth is its vendor price, or its auction price when higher (the last Scan Prices,
  else TradeSkillMaster), so an item worth listing sorts behind ones only a vendor wants.
  Anything an unfinished quest in your log still asks for goes last, matched by item name from
  the quest objectives ("Okra: 1/3", or "1/3 Okra" in clients that put the count first), rebuilt
  only when the quest log changes.
- Food, drink and potions 10 or more levels below you (`OUTLEVEL`) are flagged as outlevelled:
  classic junk that is not grey.
- Stacking only counts plain bags: a quiver, soul bag or profession bag holds its own kind of
  item, and emptying one frees nothing for the rest of your loot. Protected items count too,
  since stacking loses nothing. Stacking is one move per bag update: the server locks both slots
  until a move lands, so the next waits for `BAG_UPDATE_DELAYED`; smallest into the fullest one
  that still has room, at most 60 moves, the first off a fresh scan, and anything left on the
  cursor goes back where it came from.
- Deleting: the slot is read again right before acting, as bags shift under a row drawn a moment
  ago. `DeleteCursorItem` is protected on Forever: it works only straight from a click on the
  icon, and is blocked from a confirmation button or a key binding, which only pick the item up.
  It also skips the game's own delete confirmation, so only Poor and Common are deleted directly;
  Uncommon and better go on the cursor, where dropping them brings up the game's prompt (type
  DELETE for Rare and up). A quest item takes a second Ctrl-click within 5 seconds: a warning,
  not a popup, since the delete must come straight from the click.
- The ignore list keeps the time each item was ignored, so it shows the newest first (an entry
  without a time sorts last). An item dropped or clicked onto its drop zone is ignored and goes
  straight back to its bag; the zone lights up while an item is held over it. Its rows' X shows
  while the row is hovered, and moving onto the X still counts as the row. Names not cached yet
  fill in once the item data arrives. The list is sized off the panel, as the scroll frame reads
  0 wide until a layout pass has run.
- Linking an item uses `ChatFrameUtil`, not `ChatEdit_InsertLink`: that is a deprecated shim
  Forever does not load.
- Bag Space's tooltip lines can each be turned off; the quest warning always shows, since it is
  what stops a needed item going by mistake. A stack's total is what is lost, and the split says
  how it adds up.
- The free count turns orange under a tenth of your slots free and red when full. An "Inventory
  is full" error brings the row up for 20 seconds whatever the threshold says; the threshold's
  events are needed only while it can hide the row.
- Unlock Mode moves the first icon's place, so a place saved before the card existed keeps the
  icons where they were; the card is drawn round the icons from it and kept on screen whole. Unlock
  Mode shows your own items, with samples in the empty slots so the whole row can be placed, and
  clicks do nothing while unlocked.
- Item data arrives in the background on first sight; a rescan waits for it only while something
  is still missing.
- The settings preview draws the same card with the same code on plain frames, from the addon's
  own samples (an item of each quality from Poor to Rare, a stack, an outlevelled one and one a
  quest needs): no bags are read and no click acts. Hovering a sample shows its tooltip lines.
- Bag Space's Ignore List window is its own file, loaded right after Bag Space, which keeps both
  under Lua 5.1's limit of 200 locals in one chunk. It reads the list and asks for a rescan
  through `ns.BagSpace`. Its search box is `ns.NewSearchBox` and its list scrolls in
  `UI.SlimScroll`, like the options window.

### Trainer
- The new-ability glow is LibCustomGlow's on the action buttons, never Blizzard's own new-ability highlight: that marks table is read from secure code, and a write from an addon taints it.
- Blizzard's, EllesmereUI's and the controller bars' buttons all inherit ActionBarButtonTemplate, which lists them in ActionBarButtonEventsFrame.frames, so the glow finds every bar there.
- Paging and slot events arrive before the buttons pick up their new action, so the glow waits a frame, and a burst of events costs one pass.
- An uncached spell has no subtext yet; read as rank 0 it would pass for a downrank, so it is skipped.
- A lower rank beside the highest one on your bars stays, for downranking (a healer's Rank 1 heal next to the main one); only the highest copy is swapped. Kept spells are still listed, flagged.
- New abilities stay lit per character in the account store, so a reload does not drop the glow.
- The popup never opens in combat (rank swaps cannot happen there); it waits for combat to end and keeps the list it had.
- Away from a trainer (a tome, a quest reward) the popup opens `SHOW_DELAY` (2 s) after the last new ability, instead of waiting for TRAINER_CLOSED.
- Casts and bar changes are listened to only while a new ability is waiting to be used or still lit.
- `KEYBOARD_SLOTS` is 180, the keyboard action slots; the controller's slots follow them.

### Quest Automation
- Saved rewards live in the profile (quest ID to item ID), so a shared profile carries its picks.
- A reward's item ID comes with it before the item is cached; its link may not.
- Every layout of the rewards ends by clearing the choice (the reward panel's OnShow, then QUEST_ITEM_UPDATE as uncached items arrive), so the saved pick is selected after QuestInfo_ShowRewards.
- A quest a player shared with you is not shared again when you accept it: the group already has it.
- Sharing makes the same call as Blizzard's Share button (QuestLogPushQuest). It is blocked in combat, so a quest accepted mid-fight is not shared.
- An NPC with several quests: the first finished one is handed in, else the first on offer is opened. A choice of rewards waits for the player unless the profile has a pick for it.
- The quest Modifier key keeps its saved key `questSkipModifier`; `questModifierMode` says whether holding it skips the quest steps (the default) or is what triggers them.
- Auto Gossip picks a lone option only when its icon is one of `GOSSIP_ICON_PATHS` (vendor, trainer, banker, auctioneer, stable master), resolved with GetFileIDFromPath on first use. The binder (hearthstone), the generic gossip icon and the rest are never picked, so nothing that costs money or moves you. The taxi icon is left out too: some lone flight options fly you straight off. Without GetFileIDFromPath it does nothing.
- Auto Gossip leaves a flagged `selectOptionWhenOnlyOption` option to Blizzard's gossip frame, which selects it before GOSSIP_SHOW reaches the addon, and leaves any window the game forces open (`ForceGossip`). It never acts with a quest listed (that is the quest automation's), with more than one option, with an option that is not Available, or in combat, and selects once until GOSSIP_CLOSED.
- Auto Gossip has its own Modifier and Modifier Does, as the quests do. `SelectOptionByIndex` is not hardware-gated in the API documentation (its secret-argument rule only allows untainted callers), and Blizzard's gossip frame makes the same call on show.

### Pet Tracker
- Demonic Sacrifice leaves one of `SACRIFICE_BUFFS` on the warlock in place of the demon, so a warlock who sacrificed theirs is left alone.
- The pet's health is secret in combat, so a step curve (`UnitHealthPercent` with `curve`) turns it straight into the warning's alpha. `STEP_EDGE` puts the step just under the threshold.
- The low health warning stays shown at alpha 0, as a secret value cannot hide it, so it sits on top of the alert stack (`STACK_ORDER` 5), where it leaves no gap between the others.
- The sacrifice aura is read out of combat only: in combat the client hides the player's own auras from addons, so the last answer from before the fight stands.
- A pet can take a few seconds to come back after dismounting: `DISMOUNT_DELAY` (5 s) keeps the warning away meanwhile.
- The warning is fitted to its text only with a background, so elements anchored to it keep their spot.

### Performance
- The game keeps its settings per computer, so the values the recommended ones replaced live in the account store (`cvarBackups`), not the profile.
- `SAME_WITHIN` compares numeric CVars loosely, as the game writes some back with float noise.

### Stealth Reminder
- The form IDs are `GetShapeshiftFormID` values, the same ones the Threat Meter reads.
- A reminder is fitted to its text only with a background, so elements anchored to it keep their spot.

### Quiz
- `CAMPFIRE_SEATED` (1229739) is Forever's "Welcoming Campfire" aura, present only while seated at a campfire (probed 2026-09-24). "Campfire Nearby" (1283391) is an area aura from simply walking past one, so it is not used.
- Auras cannot be read in combat, so the camp check pauses there rather than reading a missing aura as having walked away.
- A dismiss with no reason is the close button; one with a reason closes only what that reason opened, so landing never shuts a quiz opened by hand.
- In `QuizData.lua` the first answer is the right one; the quiz shuffles them before showing.

### Mail
- Quick Attach puts in one stack at a time, from a scan made at the click: each is checked in its bag slot and on the cursor before it goes in, and the next goes only once the last has landed (MAIL_SEND_INFO_UPDATE).
- Its one `C_Container.PickupContainerItem` runs only from a click at the open mailbox, which is why the taint scan allows it.

### Scrap Marker and Scrap List
- Items are marked by ID, never by name: for the account (`scrapItems`) or for one character by its GUID (`scrapChars`).
- Scrap sells `BATCH` (6) items at a time, `STEP_DELAY` (0.25 s) apart, and each sale checks again that you are still at the vendor, out of combat, with the same item in that slot. That is why the taint scan allows its one `C_Container.UseContainerItem`; keep that check right before the call.
- A generation number drops a step left over from an earlier sale, so closing the vendor or entering combat ends a sale cleanly.
- The X on a rule match keeps it (`scrapKeep`), so the rule leaves it alone until you mark it yourself.
- Bag buttons, the game's, EllesmereUI's and Baganator's, are hooked once with HookScript, and only out of combat.
- Baganator gets the mark as a corner widget and the marks as a junk plugin, through `Baganator.API`. Neither can be taken back, so both are registered once, the first time the Scrap Marker is on, and answer nothing while it is off.
- Baganator pools its item buttons and moves them between slots, so an Alt-click reads the button's bag and slot when it lands, not at the last paint. Its buttons for other characters' bags have no bag, so they get no click and no mark.
- Baganator's junk plugin takes over its junk detection, so ours counts grey items with a sell price as junk too, as Baganator's own Poor quality does, and adds scrap on top.
- `MAX_ITEM_ID` caps an imported ID at the largest 32-bit signed number, so a pasted list cannot ask for an impossible item.

### Skyborne Spots
- The game marks neither ley lines nor Elemental Convergences, so the spots come from two places: the list every player starts with (`SkyborneData.lua`, from tr0tsky's Skyborne Ley Line & Convergence Marker, under its MIT licence, whose notice stays in that file) and the ones this account finds. Casting the racial on a spot gives its buff, and where it was cast is saved.
- `SAME_SPOT` is 40 yards: a find this close to a known spot is that spot. `MIN_BUFF` is 60 s: the spot's buff lasts minutes, not a moment.
- The game applies the buff a moment after the cast, so it is looked for `FIRST_LOOK` after and then up to `MAX_TRIES` times, `RETRY_DELAY` apart. `CAST_SLACK` lets a buff that started just before the cast's own time count.
- Auras are secret in combat: the buff is read only while readable, and through pcall all the same. A cast in combat waits for combat to end.
- `MAP_CONTINENT` is the `Enum.UIMapType` of a continent: on it or anything larger the pins are drawn smaller.
- The map calls `CheckMouseButtonPassthrough` on every acquired pin, and its SetPassThroughButtons is protected: from our refresh it is blocked in combat. These pins want their clicks, so the method is left empty, and a redraw asked for in combat waits for combat to end. A resize only changes sizes, so it is safe in combat.
- The world map may load after this file, so switching on waits for Blizzard_WorldMap. The pin mixin is a global so the XML template can name it, made the first time it is switched on.

### Custom Slash Commands
- The default commands are copied into the profile on first use, so `DEFAULTS` is never written into.
- Whenever chat text is parsed, the game moves SlashCmdList's entries into `hash_SlashCmdList` and a table behind SlashCmdList's metatable, so a command is looked for in all three.
- A command's handler is called directly. Sending it through the chat box ran the game's chat code from the addon, and the player's next chat message was blocked.
- /cast, /use, /target and the other secure commands run only from the chat box or a macro, so a custom command refuses them. The game blocks ReloadUI from addon code, so /reload is refused too.
- The chat box caches handlers in `hash_SlashCmdList` the first time any slash command is typed, so a refresh drops our own cached entries there; the taint scan allows that one write.
- A window command shows or hides the frame from addon code, so its OnShow / OnHide run tainted;
  while `ns.GamepadOwnsPanels()` their gamepad handling is forbidden, so the command refuses.
- Only the windows this client has are offered: `FRAMES` names each one's load-on-demand addon where it is not loaded up front.

### Town Map
- The service NPCs (`Shared/Game/Towns.lua`, which the Training Planner and Professions read too) come from Classic Era data: `[uiMapID] = { { x, y, category, name, title, class token (class trainers), factions ("A", "H" or "AH"), optional NPC ID } }`, x and y in map percent. NPCs Forever added sit last in each map's list. Forever redrew Stormwind, Mulgore, Redridge and the Eastern Plaguelands, so Classic positions there went through world coordinates.
- `ns.TownCapitals` lists the capitals' maps: the game reports them as zones, so this is the only way to tell.
- `/naowh townaudit` checks that data against Forever by standing at each NPC: opening their window records where you are next to where the data puts them, in the account store (`townAudit[mapID][name]`).
- The hint lines' light blue (`HINT`) goes through `SoftBlue`: the shade it always was, or the theme's lighter Accent once a theme changes the Accent.
- The map calls `CheckMouseButtonPassthrough` on every acquired pin, and its SetPassThroughButtons is protected: from our refresh it is blocked in combat. Town pins take no clicks, so clicks reach the map anyway; zone exits and docks are separate clickable pins, so the vendor and trainer pins stay click-through. A zeppelin tower's pin has a second destination on right click. Their click opens the map with `C_Map.OpenWorldMap`, never the map's `SetMapID`: written from addon code, the map's `mapID` stays tainted for the session, and the next map opened in combat blocks the quest pins' SetPassThroughButtons.
- Forever has no map links of its own (`GetMapLinksForMap` returns nothing), so the exits come from `ZoneExits.lua`. `EXIT_SHRINK` (0.6) makes an exit arrow 40% smaller than a pin, so it stands no bigger than the others, and `EXIT_LENGTH` is its length in its own widths.
- Vendors & Trainers Only in Cities (`townCapitalsOnly`) keeps vendors, trainers and the bank off questing maps. Flight masters, innkeepers and stable masters (`EVERYWHERE`) are what a traveller looks for in any town, so they show on every map with it on, except stable masters, which only a hunter (`STABLE_CLASS`) sees; so do mailboxes and spirit healers, which are what you look for out in the world.
- `townMinimap` is the minimap's mailboxes and `townMinimapSpirit` its spirit healers: `townMinimap` once held both, so existing profiles keep their mailboxes.
- Which town pins show is chosen on the map itself, from the Town Pins button (`MapPinsPanel.lua`), and only there: the long list of town pin types is what you pick while looking at the map. Everything else is on QoL's Map & Pins tab and only there: a Map Options card (id `mapOptions`) and a Map Pins card (id `townMap`: Town Pin Size, then each module's pins under its title). No setting is in both places but Town Pin Size. The Map Pins card's search words include every town pin's name, so the options search still leads there. The keys stay in the QoL store, so saved settings carry over. The button shows whenever QoL is on, since the drawer is also where a switch that is off is turned back on.
- Map & Pins is the home of every map pin and map option: the town pins, QoL's own Unexplored Areas, Zone Levels and Skyborne Spots, Discovery's quests, rares, library books and Sleeping Bag steps, and the Dungeon Journal's entrances. Each of the last adds a section to `ns.Shared.MapPins` (`{ title, order, store, switch, rows, map }`), and `ns.Shared.MapPinSections()` hands them back by `order` (10 to 12 the map options, then the sections with no `order`, which count as 50, in load order, and Skyborne last at 60). A section's `title` is its group; one with no title continues the group above. Sections marked `map` (Unexplored Areas, Zone Levels) are the Map Options card's rows, the rest follow Town Pin Size on Map Pins under their titles. Rows of another module's store are `lent`, so a card's Reset and changed count leave them to their module. A module that is not loaded adds nothing, and a section whose `hidden` says so is left off (Skyborne Spots for anyone not Skyborne). Drawer rows dim and lock while their `needs` fails: the town rows while Town Pins is off. A town row with a `class` shows only for that class (Stable Masters, hunters). The drawer has its own Town Pins switch, so the town pins can be turned back on from the map.
- The Town Pins button sits in the map's top right corner, left of the buttons the map keeps there and at their size, so they read as one row. Those are found by where they sit, not by name, so a map with more, fewer or none of them still gets a free spot.
- The drawer is the options window's look: a header strip in the panel color, small accent group titles and ruled rows with the switch on the right. It is the map's child, so it opens, closes and scales with the map, `PANEL_LEVEL` over the map's pins as the Dungeon Journal's drawer.
- The drawer sits against the map window's left side (the Dungeon Journal takes the right), `GAP` -1 putting its border on the map's so the two read as one window; with no room there, the right. It is the map's height, as wide as the quest log beside the map (`PANEL_W` where there is none), and its rows shrink to fit a small map, down to `ROW_MIN_H`; past that they scroll, so the drawer never runs off the map. The scroll bar sits inside the rows' right margin, raised over them so its grip takes the mouse.
- The maximized map letterboxes its picture on a wide screen, so there the drawer goes in the black bar left of the picture, as wide as the bar allows; with no bar `BAR_MIN_W` wide it hangs under the Map Pins button, which stays free to close it. Either way it is no taller than the picture and its rows scroll. The map's Maximize and Minimize place it again.
- On the minimap, the game says when you start and stop moving but not where you are, so the pins are placed every `MINI_INTERVAL` (0.05 s) while you move, or always with a rotating minimap, for turning. The zone's map is kept in world coordinates (its continent, top left corner and the steps for one whole map across and down): `UnitPosition` makes no table each tick, `GetPlayerMapPosition` does.
- Pins draw the game's own map art, not square spell icons with a border: `MAP_ART` lists each kind's art in order, the redesigned atlases of the minimap's object icon sheet (`Interface/Minimap/ObjectIconsAtlas`) first, then the older `Interface/Minimap/Tracking` and gossip files. A kind whose art the client lacks keeps its square icon. A missing file makes SetTexture return false, so a file is only kept where it loaded.
- Flight masters are the flight map's green spot (`Taxi_Frame_Green`): its yellow one is lost on the Barrens' yellow. Vendors and trade goods are the sheet's bags, which is its `Banker` art, so the bank shares it.
- Spirit healers are the sheet's blue spirit ghost. Where the client lacks it, the Spirit Healer's angel cut round (`ROUND_ART`, `ROUND_MASK`), as the Skyborne pins are, reads better than a tombstone. Pins are pooled across kinds, so the mask goes on and comes off again.
- `TRAVEL_ART` picks a dock's art by the first word of its label. Boats are the flight map's ferry (`FlightMasterFerry`). Forever has no zeppelin map art (no atlas names one), so zeppelin towers are the flight map's globe for travel to another continent, which is what a zeppelin does. An item icon there (`ICON_FOLDER`) is cut round. The cyan ball is left for a client with none of them.
- Checked in game: Forever lacks `Vehicle-AllianceShip` and `Vehicle-HordeShip`, `ShipMissionIcon-*-Map` are badges, not ships, and `Vehicle-Air-Horde` reads as a warship. Wowpedia's small icon numbers ("obj220") are cells of the object icon sheet, not `GetPOITextureCoords` indices; townlong-yak's AtlasInfo.lua names them.
- Pins scale with `ns.Shared.ScalePin`: 1.5 times their size on screen whatever the canvas scale, so they keep one size as the map zooms, in the window and full screen. Town pins take `TOWN_PIN_SCALE` (0.5625) of that, so Town Pin Size 20, the default every map pin shares (`PIN_SIZE_DEFAULT`, in `PIN_SIZE_RANGE`), is the size that reads best beside the other pins: one number sizes every kind of pin alike.
- The drawer ends on Town Pin Size, a copy of the card's slider in smaller text (`FOOT_SIZE`), so the pins can be sized while looking at them.
- `MapOverlays.lua`, `TownMailboxes.lua`, `TownSpiritHealers.lua`, `TownTravel.lua` and `ZoneExits.lua` are generated (`Tools/build/map_overlays.py`, `mailboxes.py`, `spirit_healers.py`, `travel.py`, `zone_exits.py`): change the builder and run it, never the file.

### Map Window
- Always on while QoL is: no switch and no Map Scale slider, the grip is the setting. A map you can size and move is how the addon's map works, not an option; `mapSizePercent` and `mapSizePos` keep what the grip and title bar set.
- Only the map frame's scale changes, so its pins, the Town Pins drawer and the quest log scale with it. An anchor's offsets are in the frame's own scale, so they are corrected to keep its top left corner where it was on screen.
- The grip is the options window's own (`UI-ChatIM-SizeGrabber`). Dragged away from the map's top left corner the map grows, towards it it shrinks, by how far the cursor is from that corner in screen pixels, so the distance does not change as the map's own scale does. It snaps to `STEP_PCT` between `MIN_PCT` and `MAX_PCT`; right click puts it back to 100%. A drag the map's hiding cuts short keeps the size it got to.
- The full screen map is drawn at the game's size: its Maximize sets the scale back to 1 and hides the grip, Minimize puts ours back.
- The title bar moves the map: an invisible handle over it, short of `TITLE_BUTTONS` on the right so the map's own buttons still work. It places the map by hand while the cursor moves, never with StartMoving, so the game does not save it as a user-placed frame. The spot (`mapSizePos`, the top left corner in UIParent units) is kept at least `KEEP_ON_SCREEN` on screen.
- The game puts its panels back in place when one opens or closes (`UpdateUIPanelPositions`), so after it does, a saved spot is put back. That hook also notes where the game put the windowed map (`home`), even with a saved spot and after a /reload, so right-click on the title bar, or turning QoL off, puts it back there. Opening the map places it before showing it, so the hook takes the map's spot while it is shown or is the panel being placed, never a hidden map's stale one. Addon code never calls `UpdateUIPanelPositions` itself: that would taint the secure `FramePositionDelegate`.
- With QoL off, the hooks return straight away and the map is left where the game, or another map mover, puts it. Turning QoL off puts the scale and the game's spot back once (`applied`). Turned on with the map open, the spot it is in is noted as `home` first.
- Works in combat: Forever's world map has no secure frames (nothing in Blizzard_WorldMap or Blizzard_MapCanvas inherits a secure template, and the game itself resizes it in combat), so a full screen map opened in a fight is drawn at the game's size straight away.

### Restock
- `FAMILIES` are the class spells that use a vendor reagent on Forever, from its SpellReagents data (build 1.60.1.69913). Each family lists its ranks from lowest; the highest rank you know sets the reagent, so a rank 2 Prayer of Fortitude asks for Sacred Candles, not Holy Candles.
- `TARGETS` is how many of each reagent to carry unless the player sets their own.
- Forever reports an empty ammo slot as item 0, not nil.
- Food and drink are Consumable: Food & Drink (`FOOD_CLASS`, `FOOD_SUBCLASS`). Drink is told apart by its spell: `DRINK_ITEM` (159, Refreshing Spring Water) carries the localized Drink spell, so its data is asked for up front.
- Quivers, ammo pouches and soul bags do not count as room: only plain bags (`PLAIN_BAG`) add free slots.
- The reminder pulses `FLASH_LOOPS` times when it appears, then stays solid until it is dealt with; refreshed as bags change, only a new appearance pulses.
- It shows on reaching a rested area, and again `SETTLE_DELAY` after a vendor closes if anything is still short: bags settle a moment after the last purchase or sale. Restocked from the bank, mail or a trade, the list follows while it is up.
- A purchase returns what it spent because GetMoney() does not drop until the server answers. A vendor that sells in bundles (arrows by 200) only takes whole bundles, so the amount rounds up to one.
- Auto Repair and Auto Sell Junk work at the vendor whether or not the reminder is on. Reagents are cached at switch-on so the reminder can name ones the client has not seen this session.

### Waypoint Pin
- It follows the game's navigation frame (`C_Navigation`), so quests, your corpse and map pins get it as well as `ns.PlaceWaypoint`'s spots, which it names. A user waypoint counts as ours when it lies within `SAME_SPOT` (map percent) of `ns.placedWaypoint`.
- A map pin's or corpse's navigation point is the spot on the ground: the ring at the line's foot goes there and the pin stands above it. A quest giver's is over their head, where the pin goes as it is, with no line down.
- The game clears a map pin on arrival, but a quest stays tracked at the quest giver, so the pin goes within `REACHED` (5 yards) of a quest's target and comes back past `LEAVE` (7), so a step back does not make it flicker. The navigator stays.
- Your speed reads secret at times, as in restricted content, so the last readable one is kept; standing still, the walking time uses `RUN_SPEED` (7 yards a second).
- The card and navigator are repainted only when the mode, side, whole yards or whole seconds change; the place and arrows move every frame, and nothing is built per frame.
- `BEHIND` is the angle either side of straight down that counts as behind you. `FAR` is the distance at which the pin is smallest (`FAR_SCALE`), and `FADE_FLOOR` its alpha at your feet with Fade Up Close on.
- The game places a waypoint you click on the map without tracking it (its map code calls `SetSuperTrackedUserWaypoint(false)` right after `SetUserWaypoint`), and the pin only follows what is tracked, so on `USER_WAYPOINT_UPDATED` it tracks the new waypoint itself: one frame later with the map closed (the game's own untracking has run by then), or as the map closes (`trackOnMapClose`), as `Core/Waypoint.lua` holds its own placements, since setting one with the map open taints it. Already tracked, it leaves it.
- A waypoint you set has no held arrival: reaching it plays the sound and the pin, cue and bar go at once. A quest, the corpse and a route's stop hold the arrival where the pin last stood for `ARRIVED_HOLD` (a route's names the next stop). The game clears a waypoint you set as you reach it, its navigation frame going too, before or after NAVIGATION_DESTINATION_REACHED; that event's `isWaypoint` is a stop on the way (a zone's exit), not the spot itself. A waypoint you set does not wait for it: on the waypoint's map or one inside it (a waypoint placed on a continent still counts in its zones; the game routes a waypoint on another map through stops on the way, such as a zone's exit, which are not the spot), within `REACHED` of its spot, once the pin has seen you more than `LEAVE` away since the waypoint was attached or placed (a new waypoint can report no distance at first, and one placed under you has nothing to reach; other tracking changes on the way do not reset it), the pin shows the arrival and clears the waypoint itself, so it goes even when the game sends no arrival, or sends it as a stop. The game's event, when it does come first, clears it before the pin does. It does this once per waypoint (`selfCleared`: with the world map open the clear is held, and the pin must not arrive again every hold), and never on a route's stop, which moves on by the game's arrival event: clearing it would end the route.
- Nothing tracked means cleared or reached. A clear can leave the navigation frame up with no NAVIGATION_FRAME_DESTROYED, which used to leave the navigator showing.
- The game's own marker keeps setting its frame's alpha, so Hide the Game's Marker fades its parts (`GAME_PARTS`) instead.
- With no waypoint, Unlock Mode still shows the navigator on a sample, to place it by.

### Player History
- `ns.PlayerHistory.Of(guid)` is nil or `{ name, classFile, firstSeen, lastSeen, groups, dungeons, raids, sessions = { { at, seconds, kind, place, instance } }, chats = { { at, mine, channel, text } } }`, lists newest first; `Note(guid)` is nil or `{ text, tag, at, name }`; also `On()`, `Forget(guid)`, `SetNote(guid, text, tag, name)` and `TAGS`. What they return is the saved data itself: read it, never change it. The Naowh Inspect panel reads it.
- Everything is keyed by GUID, in the account's saved data: first names are not unique on Forever.
- Group members, names, chat lines and instance info can be secret; each is checked with `issecretvalue` before it is read, and a secret one is skipped.
- A save written by a newer version (`VERSION`) is left frozen, never rewritten.
- A group shorter than `MIN_SESSION` (60 s) is not kept. A reload or relog within `RESUME` (5 min) carries the open groups on, from what was saved at logout.
- Text is capped at a UTF-8 character boundary, so a cut never leaves half a letter.

### Mouse Ring
- The sweep is two half rings, each masked by a half disc that rotates. `RING_TEXEL` and `TRAIL_TEXEL` inset each texture by half a texel so its edge never bleeds.
- The player's own casts are never secret; the global cooldown is read only while the client hands it over readable.
- On Forever the global cooldown starts with UNIT_SPELLCAST_SENT, and UNIT_SPELLCAST_START follows a round trip later. A hard cast's own global cooldown still runs, unseen, to time the ready ring, so the cast sweep is the only one showing.
- A pushback moves the end of a cast already showing; only a new cast waits for Sweep Delay again.
- The idle fade applies to the whole ring and trail, on top of its opacity.
- Out of melee range uses the crosshair's melee ability (`ns.MeleeRangeSpell`), checked every `MELEE_TICK` while a hostile target is up; a secret answer is skipped.
- The settings preview is drawn by the same `Look` functions as the ring itself.

### Loot Feed
- Forever never loads Blizzard_Deprecated*, so item and coin calls go through C_Item and C_CurrencyInfo.
- With a theme, the dark style's fill follows Background, the light style's fill and edge follow Panels and Borders & Lines at the same opacity, and the glow follows Accent; `ns.ThemeTint` returns the shipped literals while the theme leaves that color alone.
- The loot patterns are built once from the game's own LOOT_ITEM_* strings; the Pushed ones cover quest rewards and anything handed straight to the bags.
- TradeSkillMaster is optional, and its price call errors on a source it cannot resolve: that is the one reason it runs under pcall.
- CHAT_MSG_LOOT can arrive before the item is in the bags, which showed the count from before the loot, so item lines read their count again once the bags settle.
- Coin loot adds to the coin line still on screen and holds it another display time, rather than stacking a line per corpse; its fade-in is skipped so the update does not blink.
- CHAT_MSG_MONEY carries your own looted coins and a group share, and only those, so vendor sales and mail never reach the feed.
- A quest turn-in also sends its experience as a combat XP message with no source named. The quest line already shows it, so that one is skipped while quest lines are on. A kill's message names the kill, and its first number is the total gained, rested bonus included.
- Chat payloads can be secret; nothing in one is worth recovering, so a secret one is dropped.
- Hide Blizzard Loot Window takes every slot on LOOT_READY, one every `LOOT_STEP` (0.05 s). The window still opens and closes as normal, as hiding it would close the loot: it is shrunk to `SHRUNK` scale instead. Its open and close animations both drive alpha, so alpha cannot hide it, and it is clamped to the screen, so it cannot be moved off it. The taint scan allows its two `LootFrame:SetScale` calls.
- The window stays full size whenever something would be left for the player: a group roll, a locked item, or bags too full. Still open `LOOT_GRACE` (1 s) after the last slot, something could not be taken, so the window comes back. Only a full-bags error during a loot matters, so errors are listened to only while one is open.
- The window gets its size back after its close animation finishes, so it never flashes on the way out.
- A Spacing of -1 lets neighbouring lines share one border.

### XP Bar
- Its colors: Naowh's blue for the fill, his logo's gold for quest XP, a darker blue for rested. A color the player picked wins; an unset one follows the theme, and the shipped one while the theme leaves the accent alone. `FILL_DARK` is how dark the fill's left end is against its color, `RESTED_DARK` how dark rested is against a theme's changed accent. A theme turns quest XP to its lighter accent, which reads apart from the fill, and the black border to its line color. Incomplete quests, unpicked, are the completed quests color faded over the background (`OPEN_ALPHA`), as its swatch shows it.
- `MIN_WIDTH` (400): narrower, the texts around the bar no longer fit even at their smallest size. The Width slider starts there, and a width saved before it did is raised to it.
- XP is counted only while the bar is on, so the session clock starts with it. The session is kept per character in the account store, so a /reload carries it on unless Reset Session on Reload is ticked; a fresh login always starts a new one.
- `UnitXPMax` reports 0 for a moment after login or a reload, before the character's data has loaded, so the maximum is never taken below 1.
- `SLOTS` is in reading order, which is also the order that keeps a text shown twice: the first keeps it. Each text shows in one spot at most, inside the bar and around it alike, the level's three forms counting as one; picking one for a spot clears whichever spot had it.
- `OLD_TEXTS` are the switches the spots replaced, with their old defaults (Played and Leveling on, Session and Completed off). A profile that changed them gets the same texts in the spots, once; with both Completed Quests and Rested on there is one spot left, so Rested is dropped.
- Blizzard's experience bar is faded with SetAlpha, never hidden or unregistered: Edit Mode stacks the bottom action bars on these containers, and a Show/Hide from addon code taints that layout, so the next re-layout in combat (the pet or stance bar changing) is blocked. Retail-engine clients keep XP in the status tracking containers, older ones in MainMenuExpBar. Only the container showing XP fades: at max level the same container carries the watched reputation.
- The container swaps bars without hiding when XP comes back on at max level (the ApplyPendingBarToShow hook), and its own fade-in animation runs after those hooks and ends at full alpha, which is how the bar came back after a /reload. Animations do not go through SetAlpha, so an OnUpdate hook catches it, only while it is shown and only once its alpha has crept back up.
- The texts are measured and placed only when one of them, or the bar, changed. `TEXT_GAP` sits between two texts in a row and `SLOT_FONT_MIN` is the smallest they shrink to before they cut off; a text is measured with a pixel spare so rounding never cuts it. Side texts start at the bar's ends; the middle one is centred while it has room and slides away from a long side text when not; when a row does not fit even at its smallest, it is split evenly and long texts cut off. The rows above and below shrink only as far as their own texts need; the texts beside the bar keep the full size. The texts inside follow the bar's height (`INSIDE_SHARE`).
- Rested runs from the end of your XP, like Blizzard's, the full height of the bar and over the incomplete quests, so a bar full of quest XP cannot push it off the end; at least `RESTED_MIN_W` (3 px), so a sliver of rest still reads.
- In a battleground or an arena (`PVP_INSTANCES`, from IsInInstance) the bar hides, like Blizzard's stays faded: the instance type only changes behind a loading screen, so it is read on PLAYER_ENTERING_WORLD and when the bar turns on, never per update. The HUD Editor still shows it there, to place it.
- The bar takes the mouse only while Ctrl is down, for its reset click; otherwise a click or a camera drag that starts over it goes through to the world.
- The texts are picked on the preview, so their rows are not drawn on the page; they are still declared for the search, the changed count and the card's Reset. A preview spot answers HandlesGlobalMouseEvent so the menu manager does not close its menu before OnMouseDown toggles it.

### Unexplored Areas
- The overlays (`MapOverlays.lua`, generated by `Tools/build/map_overlays.py` from the game's tables) are `[uiMapID] = { { width, height, offsetX, offsetY, fileDataID, ... } }`: an area's size and place on the map art in its pixels, then its `TILE` (256 px) tiles row by row (`AREA_FIELDS` before them).
- A tile's drawn size and its texture file's size differ along one side: the last tile of a row or column holds what is left, in a file rounded up to a power of two (from `SMALLEST_FILE`).
- The pin is one for the whole map, holding every unexplored area's tiles. Its `CheckMouseButtonPassthrough` is left empty: the map calls it on every acquired pin, its SetPassThroughButtons is protected in combat, and this pin takes no clicks.

### Zone Levels
- Forever's client tables give no outdoor zone a level range (no ContentTuningID on UiMap or AreaTable), so `C_Map.GetMapLevels` has nothing and the game's own map label never shows one. The ranges come from Wowhead's Forever world map instead, written to `ZoneLevelsData.lua` by `Tools/build/zone_levels.py`; Moonglade, Mount Hyjal and Shen'dralas have none there.
- The range is our own text under the game's area label (its Description), so nothing is written into Blizzard's label. The colour follows the game's rule for a range: the low end's colour below it, the high end less `BELOW_RANGE` above it, yellow inside.
- No source gives the fishing skill a zone needs, so it is not shown.

### Mana Efficiency
- Its amounts come from `SpellEfficiencyData.lua`, generated by `Tools/build/spell_efficiency.py` from the game's own spell tables (wago.tools, the build in its header), keyed by spell ID. Nothing is read from tooltip text.
- An entry is `school, level, maxLevel`, then one part per kind of amount the spell has on its target: `kind, direct, directPerLevel, directCoefficient, tick, tickPerLevel, tickCoefficient, ticks, seconds`. A spell that heals and damages the same target has two parts and gets two lines (none does in this build).
- Each entry is one string of those numbers joined by commas, not a table, so the data stays small while the feature is off: 482 tables held about 120 KB after login, the strings hold about 42 KB (measured in Lua 5.1, 32-bit; the 64-bit client holds more of both).
- A spell's string is split into its table (string.find and tonumber, never loadstring) the first time its tooltip needs it, and kept in `decoded`: later hovers of that spell allocate nothing.
- An entry that does not split into whole parts of plain numbers, each part a heal or damage, counts as no data: no line, no error.
- The direct amount is the middle of the client's roll (`EffectBasePointsF`, rolled plus or minus half its `Variance`), plus `EffectRealPointsPerLevel` for each level you are above the spell's level, up to its max level.
- Spell power counts through each effect's own `EffectBonusCoefficient` from the tables, per tick for healing and damage over time.
- A spell learned below level 20 gets 3.75% less of its coefficient per level under 20 (`LOW_LEVEL_CAP`, `LOW_LEVEL_STEP`): the classic level 20 penalty, `1 - ((20 - sLvl) * 0.0375)`, from warcraft.wiki.gg/wiki/Downranking. It is the one rule not in the tables. Vanilla had no downranking penalty above level 20, so none is applied there.
- Mana is the game's own cost (`C_Spell.GetSpellPowerCost`), so talents and gear that change it count. A spell with no mana cost (rage, energy, Bear and Cat Form abilities) gets no line, with no class checks.
- Per second is over the cast time (`C_Spell.GetSpellInfo`), read only when its info is a readable, non-secret table. An instant or channeled spell counts the time its periodic part runs instead; an instant spell with nothing periodic shows no per second.
- Per second is a whole number; Decimals sets the per mana numbers only (Per Mana, Per Mana per Second).
- Your bonus healing, or spell damage of the spell's school, is read only with Include My Spell Power on. While `C_Secrets.ShouldUnitStatsBeSecret()` says stats are secret, or any value read is secret, the line is left off rather than guessed.
- Not counted: talents and buffs that add a percent, crits, hit, resists and target conditions. A chain or area spell counts its first target.
- Left out, with no line, because part of their amount is somewhere the client's tables do not say (better no line than a wrong number): weapon damage (Aimed Shot, Multi-Shot), a triggered spell or proc (seals, Judgement), an area trigger the server runs (Blizzard, Rain of Fire, Consecration, Flamestrike, Hurricane, Volley), a dummy or script effect (Swiftmend, and Immolate, whose ranks carry a script effect in this build), and a direct base of 1 with no bonus (a scripted amount's placeholder).
- A periodic trigger is counted (Arcane Missiles): the missile spell is named in the effect itself, not chosen by a seal or a proc.
- What a spell does is what it does to its target: a heal on the caster from a damage spell (Drain Life, Death Coil) is not counted.
- The separator is written `||`, which the game draws as one `|`.
- A macro on an action bar has its own tooltip type (`Enum.TooltipDataType.Macro`, 25), so it gets its own post-call. The macro's tooltip data is not documented, so the spell comes from the hovered button instead: the tooltip owner's `action` slot (or its `action` attribute, for bar addons' secure buttons) through `GetActionInfo`, which returns `"macro", spellID, "spell"` while the macro shows a spell (Blizzard's glow and assisted-combat code compare that id to a spell ID) and `"macro", macroID` otherwise, resolved by `GetMacroSpell`. A `#showtooltip` macro follows its conditionals because the game resolves the spell. With no readable action there is no line: `data.id` is not a reliable macro index. A macro with no spell, or whose spell has no entry, gets no line, and the line is added once per tooltip build as for spells.
- The spell post-call goes on the first time the switch is on, and stays inert after it goes off (TooltipDataProcessor has no removal). The line is added once per tooltip build, as the ID line is.
- Preview Tooltip opens Lesser Heal rank 3 (`PREVIEW_SPELL`) with the line, even with the switch off. The card's preview draws two sample spells from fixed numbers (`SAMPLES`, `SAMPLE_POWER`), never a real spell.
- The line's default color is the theme's soft accent as shipped. A saved color whose r, g or b is missing or not a number (a profile import checks only that it is a table) draws in the default from the QoL store (`S.Default`), on the tooltip and in the card's preview. Both of Naowh's setups set the switch off (`Tools/data/preset_*.lua`).

### XP per Hour
- Played time comes from `Shared.Played`. Level times are kept per character by GUID, with the played time each level was reached at (shown beside each past level), which Compare Characters reads for every character on the account to mark your pace and color past levels against the fastest. A character's first login after the GUID change takes over the old entry under its first name and realm, once, if no one else has and its level fits.
- Its Background is the card, a soft fade or none (`Parts.HudBackdrop`). The old on/off setting is read as Card for on and Soft for off, and saved that way on the next Apply, as is the old Outlined Text toggle as Outline or Shadow.
- A split row is named by the level it reached: "Level 14" is the time from the ding to 13 to the ding to 14, beside the played time 14 came at. The saved table keeps it under the level it was played in (`levels[13]`), and `FORMAT.REACHED` adds one for the label, so saved splits did not move. The level in progress is named by the level it is heading for, and is not shown at the level cap.
- The outline goes through `Parts.HudFlags`: the HUD's None is saved as "NONE", which the game's SetFont rejects as a flag (the window then failed to draw at all), so it becomes no flag and no shadow; Shadow is no flag with the shadow.
- The pace arrow sits a share of the text size lower (`DROP_SHARE`), level with the letters: the Naowh font leaves room above capitals.
- The file sits close to Lua 5.1's 200-local cap for one chunk, so new constants are grouped into tables (`FORMAT`, `DEFAULT_POS`); the XP Bar folds its texts into `TEXT` for the same reason.


### Always Free for All
- Raids are left alone: a raid usually sets its own loot rules.
- The method is set again whenever it changes, so a leader who wants another one turns the switch off.
- `C_PartyInfo.SetLootMethod` is marked HasRestrictions in the Forever API docs; it is called only out
  of combat, from an event handler, never from a secure path.

### Invite Buttons
- The list is in `ns.PROFILE_OWN`: a shared profile never carries your friends' BattleTags.
- A Battle.net friend is kept by BattleTag: the game account ID to invite changes every session, so it
  is looked up on each click, the first of their game accounts online on Forever.
- Battle.net friends are invited with `C_BattleNet.InviteFriend`, as the game's Friends list does: the
  legacy friend list is off on Forever, so a name invite only reaches characters the game can find.
- Invite All stops at a full party (`MAX_PARTY_MEMBERS`) and does not turn the party into a raid;
  people already in the group are skipped.
- The invite buttons are plain buttons: invites are not protected, so they work in combat. Adding or
  removing one moves the bar, which waits for the fight to end, as the bar's other changes do.

### QoL defaults (Core/Settings.lua)
- Every on/off switch default in the QoL store is read from `ns.FEATURES.qol`; the values are unchanged.
- The supporter badges are on by default so everyone sees them, except the group banner, which Naowh asked to start off.
- The Character Panel's slot marks are on by default, an exception to off by default: they are marks on the game's own panel, with no restyle.
