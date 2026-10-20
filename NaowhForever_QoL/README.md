# Quality of Life

The QoL features, shipped as their own addon (`NaowhForever_QoL`): one file per feature, each
with its rules, its drawing and its settings card at the end. They share one settings store,
`ns.QoLSettings`, which stays in the core (`Core/Settings.lua`) because the core and other modules
read it too; its on/off switches come from `ns.FEATURES.qol` (`Core/Features.lua`). Turn the addon
off (Settings > Modules) and every QoL feature is gone, the Top Bar with them.

## Layout

```
NaowhForever_QoL/
  NaowhForever_QoL.toc             its metadata, and one file line: QoL.xml
  QoL.xml                          every file, in load order
  Constants.lua                    the numbers, colors and patterns several QoL features share (ns.QoLConstants)
  Glimmer/                         Glimmer, its own tab: herbs, ore, chests and quest objects light up as you walk up
    Glimmer.xml                    its files, in load order, included by QoL.xml
    Glimmer.lua                    its settings (ns.GlimmerSettings), its table (ns.Glimmer, G), its categories
    Constants.lua                  the names, game settings, timings and limits its files share (G.C)
    Data/Nodes.lua                 every herb, vein and chest by object ID, with the skill it needs (G.NODES),
                                   from Tools/build/glimmer_nodes.py
    Data/Spots.lua                 where herbs and veins grow, packed into one string (ns.GlimmerSpotsPacked),
                                   from Tools/build/glimmer_nodes.py
    CVars.lua                      the game settings it changes, saved first and put back (G.CVars)
    Target.lua                     what the soft interact target is, its reach and its skill-up chance (G.Target)
    Spots.lua                      where herbs and veins grow, unpacked on first use, and the ones gathered (G.Spots)
    View/Style.lua                 its look: skill colors, effect sizes and timings (G.Style)
    View/Effects.lua               the five effects on a frame, over the world and on the previews (G.Effects)
    UI/Conflict.lua                the question when another addon changes the same game settings (G.CheckOthers)
    UI/Highlight.lua               the effect and its line on the target's nameplate, and its events
    UI/Minimap.lua                 where herbs and veins grow, as icons on the minimap
    UI/MapPins.xml                 the Gathered pin's template, and the file that fills it
    UI/MapPins.lua                 the herbs and veins you gathered on the world map, noted as you loot them
    UI/SettingsPage.lua            its tab, QoL > Glimmer, declared as cards, with its previews
  TopBar/                          the Top Bar, its card on QoL > Interface; its own README has its files
  Interface/
    SpellEfficiencyData.lua  each mana spell rank's healing or damage (ns.SpellEfficiencyData) and their talents (ns.SpellEfficiencyTalents), generated
    SpellEfficiency.lua Mana Efficiency on spell tooltips, its Preview Tooltip and the Tooltips card's preview; ns.SpellEfficiencyOf, the numbers both it and the report show
    SpellEfficiencyReport.lua  the Mana Efficiency window (ns.OpenSpellEfficiencyReport, /nf efficiency): every rank of your mana spells
    GlobalCopy.lua      /copy, and tooltip IDs with their copy shortcut (the card is Shared/UI/CopyCard.lua)
    HideClutter.lua     UI Clutter
    UnitNames.lua       Names Over Heads: guild names, guild titles and player titles with player names
    HDR.lua             HDR: the game's HDR and Peak Brightness
    ChatZones.lua       Chat Zones
    ScoutData.lua       Scout's creature abilities and tameable beasts (packed) and armor by level, generated
    Scout.lua           Scout: abilities, armor and pet family on a creature's tooltip
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
    FishingLevelsData.lua  each zone's Fishing skill range (ns.FishingLevels)
    ZoneLevels.lua      Zone Levels and Fishing Levels on the world map
    ZoneInfo/           Model.lua (zone details), View.lua (panels), Runtime.lua (map and HUD lifecycle),
                        SettingsPage.lua (Map & Pins card), loaded by ZoneInfo.xml
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
    DamageMeterLayout.lua the game's damage meter Bar Height, saved in the active Edit Mode layout
    DamageMeterPreview.lua the card's preview: a mock of the game's meter drawn with the card's picks
    DamageMeterSkin.lua the card Default Damage Meter: the game's meter in the theme, and its place
    StealthReminder.lua the Stealth Reminder
    PetTracker.lua      the Pet Tracker
    SpellQueue.lua      Spell Queue: the game's Spell Queue Window
  Questing/
    BuffThanks.lua      Buff Thank You Message and its line editor
    Invites.lua         the people you keep an invite button for and their editor (ns.InvitePerson,
                        ns.InviteAll, ns.ShowInviteEditor)
    GroupButtons.lua    On-Screen Buttons (Invite, your invite buttons, Invite All, Disband)
    FreeForAll.lua      Always Free for All, the party loot method while you lead
    LayerSwap.lua       Auto-Accept Layer Swap, confirming the game's layer swap prompt on joining a group
    FinderRoles.lua     Group Finder Roles, the role buttons on the Group Finder
    TalentPoints.lua    the unspent talent points reminder
    QuestAutomation.lua accept, hand in and share quests, saved reward picks (ns.QuestRewards)
    RewardList.lua      the Saved Quest Rewards window (ns.OpenQuestRewards)
    PlayerHistory.lua   Player History (ns.PlayerHistory), read by the Naowh Inspect panel
    Disband.lua         removing everyone from your group (ns.DisbandGroup), for the Disband button
    Trainer.lua         the trainer popup and rank swaps (ns.TrainerRankCheck, ns.TrainerForgetKept),
                        and its card on the Training Planner's page
  XP/
    GroupXP.lua         Group XP
    XPTicker.lua        XP per Hour (ns.ResetXPTicker)
    XPBarFX.lua         the XP Bar's effects and hover breakdown (ns.XPBarFX)
    XPBar.lua           the XP Bar (ns.XPBarColor, ns.ResetXPBarSession, ns.ResetXPBarLayout)
  Loot/
    LootCard.lua        the one card on Loot & Items that Looting, Vendors, Auction Prices and Mail & Alts join
    DeleteConfirm.lua   Type DELETE For You, and the Looting card
    Durability.lua      the low durability warning
    LootConfirm.lua     the retired loot confirmation skip, inert
    AuctionPrices.lua   Auction Prices (ns.AuctionPrice, ns.AuctionAge, ns.AuctionScanSummary)
    FoodBar.lua         the Food & Drink Bar (its food and potion lists are Shared/Game/Consumables.lua)
    BagSpace.lua        Bag Space (ns.BagSpaceRescan; ns.BagSpace for its ignore list)
    BagSpaceIgnore.lua  Bag Space's Ignore List window (ns.ShowBagSpaceIgnoreList)
    Alts.lua            your characters per realm and faction (ns.AltRealm, ns.AltList, ns.OpenForgetAltMenu)
    LootFeed.lua        the Loot Feed, gold per hour and quick loot (ns.ResetLootFeedSession)
    Restock.lua         the Restock Reminder, Auto Repair and Auto Sell Junk
    GearReminders.lua   Gear Reminders: an icon while you wear Cloak of Hermitic Bliss in Wailing Caverns or a fishing pole
    ScrapMarker.lua     the Junk Marker (ns.ScrapMarker), read by Bag Space and the Junk List
    ScrapList.lua       the Junk List window (ns.OpenScrapList, /nf junk)
    Mail.lua            Alts and Attach buttons at the mailbox, the expiring mail warning
  Travel/
    FlightData.lua      each flight route's flown length (ns.FLIGHT_ROUTES), generated
    Flight.lua          the Flight Timer, Flight Games and flight times on the flight map
    FlightPoint.lua     zone-entry and nearby-town flight point reminders
    TransportData.lua   each boat and zeppelin stop with its period and dwell, generated from Journeys data
    TransportRoutes.lua the ships NauticusClassic timed: cycle, docks and trigger points (ns.TransportRoutes), generated
    TransportTimes.lua  saved per-realm server-clock sightings and ride timings (ns.TransportTimes)
    TransportRide.lua   times a ship as the player rides past one of its trigger points (ns.TransportRide)
    Transport.lua       Boat and Zeppelin Timers: its minimap pins, their tooltips and Travel settings
    AimTrainer.lua      the Aim Trainer (/nfaim, ns.AimRules, ns.AimPlay, ns.AimOffer)
    AimBoard.lua        the Aim Trainer's leaderboard (ns.AimBoard)
    QuizData.lua        the quiz questions (ns.QUIZ_QUESTIONS)
    Quiz.lua            the Quiz (ns.ToggleQuiz, ns.QuizOffer, ns.QuizDismiss)
    DailyWordData.lua   the Daily Word's answers and accepted words, generated
    DailyWord.lua       the Daily Word (/nf word, ns.DailyWordPlay, ns.DailyWordOffer, ns.DailyWordDismiss)
  Media/
    crosshair_ring.tga  the Crosshair's ring
    MouseRing/          the Mouse Ring's rings, glows and trail
    Glimmer/            Glimmer's glow, flare, ring, beam and bracket, drawn by
                        Tools/media/make_media.py
    Flight/             the Flight Timer's Land Early and game button icons, drawn by
                        Tools/media/make_media.py
    TopBar/             the Top Bar's button icons and resting glyph
  README.md           this file
```


## Why

- Under Forever's Gamepad interface style (`ns.GamepadStandDown()`) the features that hook, move or
  add to the game's own windows stay off and their settings say why: Zone Info and the Town Pins
  button on the world map, the Map Window, Type DELETE For You, Auto-Accept Layer Swap, Saved Quest
  Rewards, Hide Blizzard Loot Window, the Alts and Quick Attach buttons on the mailbox, the Scan Prices
  button, Group Finder Roles, Zones in Group Finder, Land Early Button and Glow New Abilities. That
  style opens and navigates those windows, popups and action bars from secure code, and our work on
  them would taint it, blocking its gamepad bindings in combat. EllesmereUI's matching features
  stand down the same way.
- The Damage Meter Skin never hides or re-lays out the game's meter: it recolors its textures and
  fonts after the game sets them (hooksecurefunc on each entry, a scroll box callback for new
  ones), and remembers the art, the font with its flags and shadow, and the bar's atlas to give
  them back when the switch is off and nothing is picked. It reads no damage numbers, which are secret in combat.
  Bar Texture swaps the file on the bar's own texture, which the game only ever colors. Font and
  Outline are written once per change of a setting, since the game never sets them again; the
  colors are the theme's tokens until one is picked, as in the Damage Meter module.
  The title bar fade, the scroll bar and the opacities are `SetAlpha` and `SetVertexColor` calls on the
  game's own parts, never a Hide. A tick of ours (a frame made only while one of them is on) moves the
  title parts toward the mouse state and puts the scroll bar's alpha back, since the game's own
  emphasis animation sets it again. The tick sleeps: an `OnEnter` hook on the window and its
  children (the entries as they are acquired) wakes it, and it stops one second after the mouse has
  left and the fade is done, so an idle meter runs nothing. The window border is a frame of ours
  round the window. The title bar's buttons are greyed with `SetDesaturated` and tinted with
  `SetVertexColor`, their first look remembered to give back; sizes are one setting each for the
  names, the amounts and the title, 0 keeping the game's own, which Edit Mode's Text Size still
  scales.
- Theme (`damageMeterTheme`) is only where a color that was not picked comes from (`Resolve`): the game's own
  (Blizzard), the addon's current theme (`ns.THEME`, the default), or the palette of one of the themes, read
  from `ns.ThemePalette` and kept until the next apply (`Token`, `palettes`). A color that is picked applies
  whichever it is, so every row works in all of them, and choosing a theme repaints at once with no reload,
  since the meter reads the palette as it paints. Everything that follows the theme reads it the same way
  (`Color`): Accent bars, the Accent scroll bar and the icon borders are the chosen theme's, not the current
  one's. With Blizzard a flat texture that has no color goes back to
  its atlas (`Unflat`), a text keeps the color it had, the bar's shadow and edge stay, and the spell panel's
  opacity waits for a color of its own or the Window Color (the row says so). That look has its own Font, Bar
  Color, Bar Texture and Icon Border (`damageMeterGameFont`, `damageMeterGameBars`, `damageMeterGameTexture`,
  `damageMeterGameIconEdge`), which start as the game's own, so it does not leave the text in the addon's font,
  the bars in the theme's accent or its gradient, nor the icons bordered (`FontPath` answers nothing for the game's
  face, and `Face` then writes the face the text had). Each is a row of its own that the other look hides, so the
  card's Reset and its count of changes see every one.
- The Reskin switch is the theme's colors, not the switch of the whole card. The skin runs when it is on or when a
  row of the card has been picked (`Customized`: each of `PICKS` that is not its default, read through `Raw` and
  `Default`, once and kept until a setting changes or a profile is applied, since the hooks ask at every refresh of
  every bar), so a player who wants the game's own look with a font, a hidden timer or a bar opacity does not have
  to reskin. With it off, `Blizzard()` is true and `Token` answers nothing: every color that is not picked is the
  game's own, exactly as with the Blizzard (Default) theme, and the rows are that look's. Nothing picked and the
  switch off runs nothing, as before: no hook, no tick, and the first pick starts it. Theme is the only row that
  waits for the switch. The picks of the theme look's own (`damageMeterBars`, `damageMeterTexture`,
  `damageMeterIconEdge`, `damageMeterFont`) are not in `PICKS` for that reason: they do nothing with it off.
- Picks only apply with the Reskin switch off once `damageMeterPicksLive` is true, which the first change of a
  row in `PICKS` sets. Before that release the picks only applied with the switch on, so a player who picked
  colors, turned Reskin off and kept the game's look would otherwise have them painted on it after updating.
  Their saved picks are not touched: they apply with Reskin on, as before, and with it off from the first pick
  the player makes, all together.
- The title bar's timer, session button, settings button and minimize button are each switched off with
  `SetAlpha(0)`, never a Hide, and a post-hook on each one's `SetAlpha` puts a part the game raises back to 0
  (`Title.KeepAlpha`); the title fade keeps them at 0 (`TitleAlpha`) and nothing picked, with the reskin off, gives
  them back. The
  list's button is two switches, since it is a text and an arrow: the text is `TypeName`'s own opacity, and the
  arrow is every texture of the dropdown but its texts (`Title.Inner`: a text answers to `SetVertexColor` as a
  texture does, so the object type is asked, and each is given back its own opacity, since a highlight
  starts at 0). A hidden part is also made one pixel wide (`Title.Fit`, its width kept to give back, and a
  post-hook on `SetWidth` for the game's own), so what the game anchors to its edge closes the gap instead of
  leaving the room it had; the list's button closes only when both of its switches are off. A hidden button
  still takes a click where it was, as an opacity of 0 does not turn the mouse off.
  The game hangs the list's button from the timer's right edge, so the timer is in front and the title after it,
  and `Title.Layout` leaves that order: the timer is one anchor of its own and a width of 0, so it is as wide as
  its text and the title is at the far left when there is no time, and a post-hook on the timer's `SetPoint` and
  `SetWidth`, on the dropdown's `SetPoint` and on the title's `SetText` lays it out again when the game or the
  list changes. The two X offsets move one part each: the timer's moves the timer, and the button, which hangs
  from it, is given the same offset the other way so the title stays; the title's moves the text only. Only the
  game's own anchors are added to (`Title.homes`, read once and given back when the skin goes off, and not read at
  all when an offset is secret: the part then stays where the game has it), and nothing is measured: where a
  text starts and how wide it is are numbers the game keeps secret in some states, and adding them raised
  "arithmetic on a secret number value" and cut the rest of the skin short. A timer hung after the title was
  tried and dropped: the title's frame can be as wide as the window, so the end of it is not the end of the text,
  which could not be measured. The timer's offset puts it there when it is wanted.
  The game anchors the title's text flush to the arrow (an x of 0), so while the arrow shows the text's left
  anchor, and only that one, is given `TITLE_GAP` (4) pixels more, and a hidden arrow has no gap. The gap waits
  for a pick (`Title.Spaced`: `damageMeterPicksLive`, or a title bar option that is not its default), so a
  player with Reskin on who picks nothing keeps the title where it was before. Themed buttons
  tint the art of the buttons only (`Title.Glyphs`): the list's text and the session's letter are texts with colors
  of their own, and tinting them changed the title. The parts are anchored in an
  order where no anchor depends on what depends on it (the game raises "Cannot anchor to a region dependent on
  it" otherwise). `Title.placing` keeps the layout's own `SetPoint` and `SetWidth` from laying it out again
  through the hooks; `Apply` clears it, so a layout that raised an error does not stop the next one.
- The skin's title bar parts are fields of one `Title` table, not locals: the file is close to the 200 locals
  a Lua 5.1 chunk can have.
  The right-click menu is a hook on the window's
  `OnMouseUp`, made only when Right-Click Menu is on, that opens `MenuUtil.CreateContextMenu` with a checkbox for
  each switch, so a part that was switched off can be switched on from the window.
- The card's preview (`DamageMeterPreview.lua`) is a mock of the meter on the card's stage (`studio`), not the
  game's own window: the game shows sample bars only inside Edit Mode (`SetIsEditing`), and calling that from an
  addon taints the meter's own refresh, which reads data that is secret in combat. The mock is drawn from
  `ns.DamageMeterLook.Describe` (what each pick makes of each part, from the same functions the skin paints with,
  so the two cannot say different things) and from the game's own settings in `DamageMeterLayout` (width, bar
  height, spacing, icons, class color, style, opacities and text size), so it follows every row at once, with no
  reload and no fight. Its art is the game's own atlases, with the buttons sized and anchored as the game's templates
  have them (the mode button `common-dropdown-a-button-shadowless`, the cog `...-settings-shadowless`, the session's
  box `common-dropdown-c-button` reaching 7 pixels past its frame). Nothing in it is read from the game's window.
  The page is drawn again for a change of the card's own settings, but not for the game's (they are saved through
  Edit Mode and `DamageMeterLayout` keeps the value on its way), and not while a slider is held, so the preview
  repaints itself: a frame after any QoL setting changes (after the skin has taken it, so it reads what the skin
  will paint) and whenever `DamageMeterLayout` changes a value (`Refresh`). It does nothing while it is not shown.
  Its stage has one height, so the page does not move under a slider: a window taller than the stage is scaled.
- The card is in sections (Game Settings, Look, Window, Bars, Text, Title Bar, Spell Panel, Reset). The game's own
  settings are first, in a section of their own, since they are written through Edit Mode and the game may only
  take them at a reload (the row says so); the skin's rows are below, and work with the Reskin switch off too.
- The game's own settings in it (`DamageMeterLayout.lua`) are the game's list for its damage
  meter, written through `C_EditMode`: it copies the manager's layout info (never writes into it),
  changes the values in the copy and saves that, so the game applies it with its own code and
  nothing of its is tainted. Each value is stored as Edit Mode stores it: the setting less the
  slider's minimum (Bar Height, Window Width and Height), less the minimum over the step (Bar
  Spacing, Text Size, Window and Background Opacity), or the enum itself (Bar Style, Numbers,
  Visibility).
  Before the first change since login it keeps every value and a backup string of the layout,
  which Restore Game Settings puts back. It refuses in combat, with Edit Mode open and on the game's
  built-in layouts, says why in a note under the row, shows the value on its way until the save
  is done, and waits half a second after a slider stops, since every save re-lays out the game's
  systems. Window Width and Height wait for Move and Resize to be off, since that anchors the
  window on its own.
- Move and Resize re-anchors the primary session window to the screen and sizes it, since the game
  leaves that window to Edit Mode (`CanMoveOrResizeSessionWindow` is false for it). Only the session
  window moves: the Edit Mode frame it hangs from is never touched, and the game's own window setup is
  followed by ours (hooksecurefunc on `SetupSessionWindow`). The drag and the grip are `HookScript`s
  beside the game's own, which return early for this window, and the game's per-window lock is
  respected. Switching it off anchors the window to its parent again exactly as the game did. Windows
  2 and 3 are the game's own to move.
- QoL is optional: the base and every other module read what they need from it behind a nil
  guard, never at load, and the data they share with it lives in the core (`Core/Settings.lua`,
  the Alerts group in `Core/AlertStack.lua`, Naowh's setups in `Core/Profiles/Setups.lua`) or in
  `Shared/` (the copy cards, the town NPCs, the food and potion lists).
  `Tools/regression/test-module-boundaries.lua` checks it.
- The Top Bar lives in `TopBar/`, loaded last, after the QoL features it sits beside. Its on/off is
  its card's switch on QoL > Interface, and it keeps its own store, `ns.TopBarSettings` (the
  profile's `topBar` table): it was a module addon of its own (NaowhForever_TopBar) before it moved
  into QoL, and the same table means every setting carried over. An old NaowhForever_TopBar folder
  is switched off at login (`RETIRED_ADDONS` in `Core/Core.lua`), with a reload offered when it
  loaded. In that one session the old addon, which loads after QoL, has the bar: `TB.On` is false
  while it is loaded, and the QoL copy declares no card while it is enabled, since the old copy
  stops on a second `topBar` card. The enable state is asked for all characters, as the player
  may not be known yet while QoL loads; a folder enabled only on other characters costs the card
  for one session.
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
  Disband can't remove anyone from addon code: `UninviteUnit` is protected for addons, even out
  of combat. So the Disband dialog's Yes is covered, while the mouse is over it, by a secure
  button that runs `/uninvite <name>` for each member, the same way the Reload UI dialog runs
  `/reload`. The macro is built from the group as it is when the mouse reaches Yes. Names go in
  whole from `GetUnitName(unit, true)`: Forever names have two parts ("Lilith Gremory"), and
  `/uninvite` needs both. The dialog closes on the release, after the macro ran on the press or
  the release, and a click on Yes that the cover missed says to try again.
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
  mouseover, or is in your group; unknown casters are skipped. With whispers off, the built-in
  /thank receives the caster's unit token, without changing your current target. An addon's
  custom /emote, like /say, is blocked outside instances without a key press, but
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
- The Food & Drink Bar's card sits on the Consumable Bar's page while that module is on
  (`NaowhForever_Combat` loaded, before QoL by `OptionalDeps`, and `consumableBar` set), and on Loot &
  Items otherwise. A
  card's page is chosen at load, so switching the Consumable Bar on or off moves it at the next
  reload. Its settings keep their `foodBar*` keys either way.
- Its count, key text and anchor are the Consumable Bar's own rows and placement
  (`Shared/UI/ItemBar.lua`, `Shared/UI/Anchor.lua`); Show Count starts on, as the bar always showed it.
  It follows the Consumable Bar, or any Naowh Forever element, through the HUD Editor's Anchor.
- Its icons are cropped like the rest of the addon's (`ItemBar.CropIcon`). Before, it showed the
  full item art with the game's rounded border; for that look on this bar alone, add
  `ItemBar.CropIcon(button.icon, 0)` after `ItemBar.SecureButton` in `Build()`.
- While its Food & Drink buttons, or either one, are on the Consumable Bar
  (`ns.ConsumableBarUsesFood`), the bar steps aside and its card is held with why, its settings
  greyed (the Consumable Bar's apply). The `foodBar` setting itself is kept, so the bar comes back
  as it was once they leave the Consumable Bar.
- Those buttons on the Consumable Bar use this bar's key bindings (`ns.FoodBarBindings`), so one key
  works on either bar and shows in both places. Meanwhile this bar is still built and kept on your
  best food and drink, hidden: its buttons are what those keys click. It does not search the bags
  then: the Consumable Bar hands it what it found (`ns.FoodBarPoint`), so a bag change is one
  search.
- Alts are kept per realm and faction, because characters there can mail each other. Forever has
  been seen to return "Name-Realm" for the player, and the mail box wants the bare name, so the
  name is cut at the dash.
- An alt is kept by its whole name, surname included (`GetUnitName("player", true)`): `UnitName`
  gives only the first name on Forever, and the To box needs the whole name. A
  character saved under its first name before is moved to its whole name the next time it logs in, only
  when the class matches: with surnames two characters can share a first name. A record saved by its
  whole name is marked `full`; until every listed alt is, the Alts menu says so under the list, since
  another character's surname cannot be read.
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
- Group Finder Roles never writes the Group Finder's results or calls its refresh: its list, totals,
  selection and right-click menu stay Blizzard's own, untainted. It hooks
  `LFGBrowseSearchEntry_Update` (after `Blizzard_GroupFinder_VanillaStyle` loads) and fades a row
  that does not match to alpha 0 with its mouse off, so a hidden row keeps its place and the list
  can show gaps; Blizzard's sort puts solo players by tank, healer, then damage and groups with
  room for your own roles first, so matches mostly sit together at the top. A pick change repaints
  the rows on screen. A solo lister's roles are the `lfgRoles` they signed up with; a group has
  only each member's assigned role, which says nothing about who you can invite, so the player
  buttons match solo listers only. The Groups need buttons read `GetSearchResultMemberCounts`'
  `*_REMAINING` counts, the open spots Blizzard's own sort uses, and match groups only. Your own
  listing always stays. When every listing is faded, a line where the game's "No results" sits
  says the picks did it. The search results are secret in chat messaging lockdown
  (`SecretInChatMessagingLockdown`), so while `C_ChatInfo.InChatMessagingLockdown()` is true
  nothing is filtered.
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
- Healer Mana's Growth Direction holds the top or bottom edge of the four-healer sample box placed in
  the HUD Editor, so the list starts at that edge whatever the group size. In the HUD Editor it is
  placed by its centre, as every mover saves it.
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
  buttons only, the Quiz, the Aim Trainer or the Daily Word (Off hides the game buttons). It was
  migrated once from the old `quizFlight` and `aimAutoFlight`.
- Daily Word First (`flightWordFirst`) opens the Daily Word ahead of the Quiz or Aim Trainer while
  today's word is not done. Only its close button hands over to the chosen game (`ns.FlightWordClosed`):
  a game button or landing also hides it, and that must not open a second game.
- The Flight Timer has one icon button per game (the Quiz, each Aim Trainer mode and the Daily
  Word), so a game opens in one click. A game whose feature is off keeps its button, greyed out,
  with a tooltip saying where to turn it on, as the old Games menu did for the Aim Trainer.
- A game a flight opened by itself shows an eye beside its close button
  (`ns.FlightGameHideButton`, `ns.FlightGameOffered`), so a player can stop that from the game
  instead of the settings. It sets Flight Games to Buttons only, so the games stay one click away.
  The Aim Trainer hides it with its other header buttons while a round runs.
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
- Flight Point reads `C_TaxiMap.GetTaxiNodesForMap` for the zone, and the parent maps up through
  the continent when that list is empty. That list keeps nodes the game has retired ("zzOLDPowderfuse
  Port"), so a name with one of the markers `Tools/build/journeys.py` drops (`RETIRED`) is never a
  reminder, nor the nearest node to a flight master's pin. `isUndiscovered` is not set for a classic
  flight path you have not spoken to. Until this character opens a flight master's map on that continent
  (`GetAllTaxiNodes` only lists the open map's continent), a friendly point in range
  asks you to open one to save the points you know, and only a node the map marks undiscovered is
  named. Talking to a flight master (a gossip option with the taxi icon) records that town's node
  as known, so the reminder hides without opening the flight map, and does not mark the snapshot
  complete. The snapshot is this character's GUID in `flightPoints` (`TAXIMAP_OPENED`), and opening
  the map still replaces every node from `GetAllTaxiNodes`. A name cannot tell two characters apart.
- Opening a flight map saves both its taxi map ID and the player's real continent in
  `seenMaps`. Classic and Forever use separate taxi maps: 1463 for Eastern Kingdoms (1415)
  and 1464 for Kalimdor (1414). `TAXI_MAPS` lets both the screen reminder and pin hint recognize
  older saves containing only those taxi map IDs after a reload, without another visit.
- A zone under no continent counts as its own: Zephras Isle (2521) sits straight under Azeroth and
  its second map (2665) has no parent, so with only continents counted, opening a flight map there
  never marked it seen and the reminder kept asking for one.
- The learn sentence drops a leading `The ` from the place name so The Sepulcher reads
  "Learn the Sepulcher flight point". The original name still matches the town's subzone.
- A node is reminded only when it is unlearned and its faction is neutral or the player's.
  An Alliance character in Undercity sees nothing, because that flight point is Horde.
- A capital (`ns.TownCapitals`) reminds you only of that city's own flight point, and only while
  it is still unlearned, anywhere in the city. The place name is the city's when the two are equal,
  or one contains the other as a whole word: Stormwind matches Stormwind City, and Darkshire does
  not. Once that point is known, another town does not take its place. Anywhere else the player has to
  be within 400 yards, or standing in the subzone of that flight point, which is how the Auberdine
  inn counts. The Crossroads and Ratchet are about 1,200 yards apart, so one town does not
  light the next. An empty subzone matches nothing.
- Entering a zone also shows one reminder through `ns.AlertStack`, anywhere in that zone.
  `ZONE_HOLD` is ten seconds so the entry alert clears while you keep questing. Stops, subzone
  changes and restyling do not restart it. Combat and flying defer the alert until they end.
  Leaving the zone or disabling the reminder cancels its timer. Returning to the zone allows
  another entry alert. Nearby-town reminders still stay up until the node is learned or you leave.
- Node world positions are projected into the current zone with `C_Map.GetMapPosFromWorldPos`.
  Only coordinates inside that zone's map count for the entry alert, including when the taxi API
  falls back to the continent. A flight point in another zone cannot trigger that alert.
- Existing `TownMap.lua` flight-master pins add the learn reminder to their tooltip when the
  closest friendly taxi node within `TOWN_RANGE` is unlearned. Known nodes get no reminder,
  even if another unlearned node is nearby. The Town Pins and Flight Masters switches still
  control those pins; Flight Point Reminder controls the extra tooltip line. No pin system or
  setting is added. Gossip still uses the nearby-town scan, so a distant entry alert cannot
  record that node as learned.
- It checks on a zone change, when you stop, when you talk to a flight master, when the flight map
  opens or closes, when a flight takes or returns control, and when combat starts or ends. While the
  switch is off, none of those events are registered and the frame is not built.
- A stop reuses the zone's flight points until the zone changes or the flight map opens or closes.
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
- The Aim Trainer opens from /nfaim, the Flight Timer's mode buttons or a flight starting (Flight
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
  header (the bag, free slots out of your total, Junk Marker's "+N", the Stack button) over a
  cell per item (its icon, its marks, its price under it).
- Bag Space's cells and gap shrink with the Icon Size below 36 (the size the rest is drawn for):
  the gap, the price column and the price font follow it, to a floor, so a small row stays
  compact. At 36 and above nothing changes. Reverse Order only swaps which end the cheapest
  cell takes: the cells fill the same spots, so the card and its anchor do not move.
- Bag Space's Larger Cheapest Icon draws the cheapest cell about `BIG_SCALE` (1.25) times the Icon
  Size, the step up Drjay asked for to spot it at a glance. The growth is rounded to an even number,
  so the centred cell and the card keep whole-pixel edges. Its near edge stays where a plain cell's would be,
  the cells after it move over by the difference, and the card grows by it across the row. Count
  Filled Slots shows used out of total, its colour still from the free slots left, and Junk Marker's
  count as "-N" since selling lowers it. Slot Count on the Right swaps the count and the Stack button.
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
- Closing a non-profession trainer checks the current spellbook for lower ranks even without a learned-ability notification. The trainer type is captured while its window is open. A fresh visit drops the previous popup list; kept-only rank offers stay silent automatically but remain available through Check Bars. Combat deferral is unchanged.
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
- Saved rewards live in the profile, kept per class (`questRewards[CLASS]`, quest ID to item ID), so a shared profile carries its picks and characters of different classes on one profile never take each other's reward. The Saved Quest Rewards window shows and clears only the current class's list, and redraws on a profile switch.
- Picks from before they were kept per class sit at the top of `questRewards` with no class. The first class to read the picks takes them all, once; nothing is deleted, and a class's own pick wins over an old one for the same quest.
- An old pick may be another class's, so it is taken as the negative item ID: not confirmed. It shows in the Saved Quest Rewards window as Not confirmed and is never selected or handed in for you; Alt-clicking that reward again confirms it.
- The Saved Quest Rewards window is `WIDTH` 620 wide so its English subtitle, with the Alt-click hint, fits on
  its one line before the close button; it ran out of the window at 460. A longer translation is cut short.
- A reward's item ID comes with it before the item is cached; its link may not.
- Every layout of the rewards ends by clearing the choice (the reward panel's OnShow, then QUEST_ITEM_UPDATE as uncached items arrive), so the saved pick is selected after QuestInfo_ShowRewards.
- A quest a player shared with you is not shared again when you accept it: the group already has it.
- Sharing makes the same call as Blizzard's Share button (QuestLogPushQuest). It is blocked in combat, so a quest accepted mid-fight is not shared.
- An NPC with several quests: the first finished one is handed in, else the first on offer is opened. A choice of rewards waits for the player unless this class has a pick for it.
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

### Scout
- The game gives addons no list of what a creature casts or how it is built, so Scout's data is
  built by Tools/build/scout.py from the CMaNGOS classic database (GPL-3.0, credited on the Credits
  page): what a creature's scripts and spell list cast (not the casts when it spawns, is out of combat,
  evades, reaches home, or for a quest or an emote), its Armor, its six Resistance columns, its
  immunity masks and whether it can be tamed. Wowhead Forever's creature pages fill in the creatures
  the database has no spells for: most raid bosses, whose abilities are in the server's code, and
  Forever's new creatures.
- Spells are cleaned with the game's own SpellName table: one the client has no name for, a
  creature's spell to summon itself, spells the scripts put on creatures that never cast them
  (Meathook, Dazed, the campfire's Camp Benefits and Boosted Rest) are dropped, and of each spell
  name only the newest is kept (older ranks are another creature's version). Names, icons, range,
  cast time and descriptions are read from the game for each spell, so they are the client's own
  text; there is no cooldown to read for a creature's spell.
- Armor is the creature's own where the database has it (Ragnaros has 4691, more than a level 63's
  3731); the game's ExpectedStat for its level, shown with a `~`, where it does not. The cut of your
  physical damage is classic's: armor / (armor + 400 + 85 x your level), at most 75%
  (ExpectedStat's ArmorConstant is that 400 + 85 x level). A `??` creature counts as level 63 if it
  is a world boss, else as ten levels above you, the furthest a level shows.
- Immunities are the creature's two masks: the schools (bit 1 physical, 2 holy, 4 fire, 8 nature,
  16 frost, 32 shadow, 64 arcane) and the mechanics (bit n - 1 for MECHANIC n: stun 12, fear 5,
  root 7, snare 11, silence 9, sleep 10, charm 1, polymorph 17, banish 18, disorient 2, interrupt
  26, bleed 15, shackle 20, disarm 3). Only those a player can cast are listed. A negative
  resistance is left out.
- The database is classic 1.12, so a creature Forever has changed may differ from it.
- Hunters can tame a beast of their level or lower, so a tameable one above it reads
  "Untameable until level N" in red, and one whose level shows as `??` "Untameable at your level".
  The family is the game's (UnitCreatureFamily); whether it can be tamed at all is the database's.
- The data is packed like Glimmer's spots and unpacked when Scout is first on, out of combat;
  turned on in combat it waits for combat to end. A creature whose ID is hidden gets nothing
  added; one whose level is hidden gets its abilities but no armor or pet family. A spell the
  client has no data for is left out.
- The details are Scout's own tooltips (GameTooltip copies), shown while the details key is held
  (MODIFIER_STATE_CHANGED, that key only) and hidden with the creature's tooltip: under it for In
  the Tooltip, or the game's own spell tooltips beside it, on the side with more screen. The
  creature's tooltip is never redrawn: refreshing Blizzard's tooltip from addon code would re-run
  its unit code under taint, where combat's secret values break it.
- A spell whose description is empty is asked of the client once (Spell:ContinueOnSpellLoad); some
  creature spells have none, so asking again would never end.

### HDR
- HDR and Peak Brightness set the game's own `HDRFactor` and `HDRPeakBrightness`, which have no place in the game's options. Peak Brightness also turns on `useHDRPeakBrightness`, without which the game ignores it. The card shows only where the client has `HDRFactor`. HDR Settings (`hdr`, off by default) is the opt-in: until it is on, the card leaves both alone.

### Stealth Reminder
- The form IDs are `GetShapeshiftFormID` values, the same ones the Threat Meter reads.
- A reminder is fitted to its text only with a background, so elements anchored to it keep their spot.

### Quiz
- The Quiz and Flight Timer use HIGH strata, like the Aim Trainer, so reminder text stays behind their controls.
- `CAMPFIRE_SEATED` (1229739) is Forever's "Welcoming Campfire" aura, present only while seated at a campfire (probed 2026-09-24). "Campfire Nearby" (1283391) is an area aura from simply walking past one, so it is not used.
- Auras cannot be read in combat, so the camp check pauses there rather than reading a missing aura as having walked away.
- A dismiss with no reason is the close button; one with a reason closes only what that reason opened, so landing never shuts a quiz opened by hand.
- In `QuizData.lua` the first answer is the right one; the quiz shuffles them before showing.

### Daily Word
- Everyone gets the same word on the same day without any server: the day is the one the next
  daily reset falls on, less one (`GetServerTime` plus `C_DateAndTime.GetSecondsUntilDailyReset`,
  in days), so the word changes at the daily reset, and `FIRST_DAY` (20741, 15 October 2026 UTC)
  is #1. Day N's answer is the Nth in `ns.DailyWordAnswers`, starting over after the last.
- `Tools/build/daily_word.py` shuffles the answers with a fixed seed, so a run gives the same
  order. Rebuilding with other sources, words left out or seed changes the words of days already
  played, and players comparing a day's result would have had different words.
- The words are public domain: the answers are the five-letter words of 12dicts' 2of12 also in its
  3esl learners' list, less plurals and past tenses and a hand-picked list of slurs and crude
  words; every answer and every five-letter word of ENABLE is accepted as a guess. 12dicts asks
  for acknowledgment, which is on the Credits page.
- The words are two strings of five-letter words, not tables: the accepted ones are sorted, so a
  guess is a binary search, and nothing is built when the file loads.
- The letters are typed into an invisible edit box over the grid, which keeps the keyboard while
  it has focus: Play and the game buttons focus it, a flight opening it by itself does not, and
  Escape, a finished game and closing it all let go.
- A result is saved for the account, so every character shares the day's game, streak and best.
  A streak counts consecutive days won; a day skipped breaks it.
- Shared results mark each letter with raid target icons, `{rt4}` (green triangle) in place,
  `{rt1}` (yellow star) elsewhere in the word and `{rt5}` (moon) not in it: chat cannot color text
  or show the colored squares other word games share.

### Boat and Zeppelin Timers
- The game draws nothing for a boat or zeppelin on the minimap: no tracking type, area POI or
  vignette covers them, and the minimap's own mouseover tooltip comes from the engine
  (`GameTooltip:SetMinimapMouseover`) with nothing an addon can read or extend. So each stop gets
  its own minimap pin, placed by `Parts.MinimapLayer` (Shared/UI/MinimapPins.lua) like Glimmer's.
- A pin sits where the ship waits at its stop (Journeys' stop point, the taxi path node with a
  delay), not at the town map's dock pin: the Horde towers each hold two zeppelins about 50 to 60
  yards apart, so one pin per tower could not tell which ship a click recorded. `PIN_SIZE` (16)
  keeps the two pins of a tower apart at the default zoom; `MAX_PINS` (3) is the most stops one
  map has (Auberdine's).
- A left click on a pin records an arrival and a right click a departure, against `GetServerTime`.
  Click at the actual arrival or departure, rather than partway through its stop. Another click
  corrects the phase.
- The tooltip's countdown is redrawn every `UPDATE_EVERY` (1 s) only while the pointer is on a
  pin. The pins are placed only on a zone or loading event; the layer moves them while you move.
- `TransportData.lua` is generated by `lua5.1 Tools/build/transport.lua` from Journeys' ships, one
  entry per ship stop. A ship with a published cycle time uses it: warcraft.wiki.gg's "Travel
  guide to zeppelins and boats" gives Undercity-Orgrimmar every 3:59 and Undercity-Grom'gol every
  5:15, with every ship docked 60 seconds (the Feathermoon Ferry 30). Journeys' path-length
  estimate (each dock's wait plus each leg's yards over its flat speed) had those two at 6:44 and
  6:08, outside the refine band, so a second sighting could never correct them.
- Every other ship keeps Journeys' estimate until it is timed in game: the flat speed ignores
  acceleration, so it can be well off. Rebuild after Journeys' network or speeds change.
- A second sighting of the same kind (arrival after arrival, departure after departure) at the
  same stop measures the period: the time between them divided by the whole cycles in it. It is
  kept only when exactly one cycle count puts it within `REFINE_BAND` (15%) of the data's
  period; otherwise the sighting just re-anchors the phase. The measured period is saved with it.
- An estimate more than `STALE_CYCLES` (6) cycles past its last sighting shows as out of date
  instead of a countdown: by then a small period error has added up to a large phase error.
- The three-stop Southshore boat is one pin at each of its docks, naming both places it sails
  on to.
- Sightings are saved in the account settings per realm (`transportSightings`), keyed by stop, not
  the profile: a realm's transports run on the server's clock whichever character watches them.
  Turning the feature or QoL off keeps them.
- Each login and enable drops sightings older than the last weekly reset (from
  `C_DateAndTime.GetSecondsUntilWeeklyReset`), since the weekly restart restarts the
  transports, and sightings of stops no longer in the data. An unscheduled restart is not
  detectable; only a new sighting fixes that phase. Enabling prunes only once `IsLoggedIn`; at
  login, PLAYER_ENTERING_WORLD prunes.
- A backwards server clock suspends an estimate until a fresh sighting.
- Seven ships are timed from a ride instead: The Thundercaller, The Iron Eagle, The Purple Princess,
  The Maiden's Fancy, The Lady Mehley, The Moonspray and the Feathermoon Ferry. `TransportRoutes.lua`
  holds each one's round trip, when in it the ship reaches and leaves each dock, and two trigger
  segments on the way, from NauticusClassic's measurements (MIT, psynct; the notice is in LICENSE.md).
  It is generated by `python Tools/build/transport_routes.py` from NauticusClassic's `data.lua`.
- NauticusClassic keeps places on the whole-world map, so the generator fits world yards per continent
  on the docks both share and stops if one is 20 yards or more from ours; all fourteen are within 13.
  The Bravery is left out: on Forever it calls at Southshore between Menethil Harbor and Auberdine,
  so its path no longer fits.
- Their round trips replace Journeys' estimate for those ships, and the wiki's 3:59 for Undercity-
  Orgrimmar: a player's tooltip from the game had the Thundercaller about 2:10 in the air, as a
  356 second cycle gives and a 239 second one cannot.
- No event says where the player is, so while the feature is on in a zone one of those ships docks
  in, or out at sea, `TransportRide.lua` reads `UnitPosition` every `POLL` (0.8 s) and stops in any
  other zone. A ride counts when the player is within `TRIGGER_RADIUS` (20 yards) of a trigger
  point, moved within `SPEED_BAND` (35%) of the ship's speed on that segment and heading its way
  (`HEADING_MATCH`), and is not on a flight path or swimming: walking, flying or swimming past the
  point times nothing. Where along the segment the player is gives the moment in the ship's cycle.
  A ship is timed at most once every `LOCKOUT` (30 s).
- Rides are kept per realm in the account settings (`transportRides`), as one cycle start. A ride
  within `RIDE_MISS` (3 s) of a whole number of cycles from the first one keeps it and measures the
  cycle from all of them, when that lands within `RIDE_BAND` (2%) of the data's; one that does not fit
  starts over. A click at either dock times the whole ship the same way.
- Rides are not dropped at the weekly reset: NauticusClassic found the ships keep the realm's clock
  through maintenance. If Forever's restart does move them, the next ride starts over.
- A timed ship's tooltip is its name, then each dock with its departure (yellow, red under
  `LEAVING_SOON`, 30 s) or arrival (green), the colors at the top of `Transport.lua`.
- Each stop's map position is worked out once, with `C_Map.GetMapPosFromWorldPos`, the first time
  its map is shown. Disable unregisters the events and hides the pins; nothing is built until the
  feature is first on in a zone with a stop.

### Mail
- Quick Attach puts in one stack at a time, from a scan made at the click: each is checked in its bag slot and on the cursor before it goes in, and the next goes only once the last has landed (MAIL_SEND_INFO_UPDATE).
- Its one `C_Container.PickupContainerItem` runs only from a click at the open mailbox, which is why the taint scan allows it.

### Junk Marker and Junk List
- Players see Junk Marker and Junk List; the code, setting keys (`scrap*`), saved marks, the `NFSCRAP:1:` share
  string and Baganator's plugin id (`NaowhForeverScrap`) keep the old Scrap name, so saved settings, marks and
  shared lists carry over. `/nf scrap` still opens the list.
- Items are marked by ID, never by name: for the account (`scrapItems`) or for one character by its GUID (`scrapChars`).
- With Save Marks off (the default) a mark lasts only while you hold the item: on `BAG_UPDATE_DELAYED`, a marked ID
  this character has had in its bags this session and no longer has loses its mark. Only IDs seen in the bags this
  session are dropped, so a login before the bags are read, another character's account mark, or a mark added from
  the Junk List for an item you do not carry are all kept.
- The Junk Marker sells `BATCH` (6) items at a time, `STEP_DELAY` (0.25 s) apart, and each sale checks again that you are still at the vendor, out of combat, with the same item in that slot. That is why the taint scan allows its one `C_Container.UseContainerItem`; keep that check right before the call.
- A generation number drops a step left over from an earlier sale, so closing the vendor or entering combat ends a sale cleanly.
- The X on a rule match keeps it (`scrapKeep`), so the rule leaves it alone until you mark it yourself.
- `QUEST_GEAR` is gear a quest takes but the game files as a weapon or armour, not a quest item, so a rule
  would sell it: the Razormane wand, dagger and shield (5092-5094) for Weapons of Choice in the Barrens.
  It is never junk, even with an old mark, and can't be marked.
- Bag buttons, the game's, EllesmereUI's and Baganator's, are hooked once with HookScript, and only out of combat.
- Marking Modifier is Alt or Ctrl. The game's own modified click still runs after the hook, so with Ctrl a click on gear also opens the dressing room (DRESSUP is Ctrl by default); the setting's help says so instead of blocking the game's handler.
- Baganator gets the mark as a corner widget and the marks as a junk plugin, through `Baganator.API`. Neither can be taken back, so both are registered once, the first time the Junk Marker is on, and answer nothing while it is off.
- Baganator pools its item buttons and moves them between slots, so a marking click reads the button's bag and slot when it lands, not at the last paint. Its buttons for other characters' bags have no bag, so they get no click and no mark.
- Baganator's junk plugin takes over its junk detection, so ours counts grey items with a sell price as junk too, as Baganator's own Poor quality does, and adds marked junk on top.
- `MAX_ITEM_ID` caps an imported ID at the largest 32-bit signed number, so a pasted list cannot ask for an impossible item.

### Skyborne Spots
- The game marks neither ley lines nor Elemental Convergences, so the spots come from two places: the list every player starts with (`SkyborneData.lua`, from tr0tsky's Skyborne Ley Line & Convergence Marker, under its MIT licence, whose notice stays in that file) and the ones this account finds. Casting the racial on a spot gives its buff, and where it was cast is saved.
- The shipped list is tr0tsky's v0.4.0 data, 76 ley lines and 56 convergences, after Forever added spawn spots in most Eastern Kingdoms and Kalimdor zones. A spot this account found before it shipped is dropped from the found list on the first map draw of a session (`PruneFound`), so it is not pinned twice.
- `SAME_SPOT` is 40 yards: a find this close to a known spot is that spot. `MIN_BUFF` is 60 s: the spot's buff lasts minutes, not a moment.
- The game applies the buff a moment after the cast, so it is looked for `FIRST_LOOK` after and then up to `MAX_TRIES` times, `RETRY_DELAY` apart. `CAST_SLACK` lets a buff that started just before the cast's own time count.
- Auras are secret in combat: the buff is read only while readable, and through pcall all the same. A cast in combat waits for combat to end.
- `MAP_CONTINENT` is the `Enum.UIMapType` of a continent: on it or anything larger the pins are drawn smaller.
- The map calls `CheckMouseButtonPassthrough` on every acquired pin, and its SetPassThroughButtons is protected: from our refresh it is blocked in combat. These pins want their clicks, so the method is left empty, and a redraw asked for in combat waits for combat to end. A resize only changes sizes, so it is safe in combat.
- The world map may load after this file, so switching on waits for Blizzard_WorldMap. The pin mixin is a global so the XML template can name it, made the first time it is switched on.

### Town Map
- The service NPCs (`Shared/Game/Towns.lua`, which the Training Planner and Professions read too) come from Classic Era data: `[uiMapID] = { { x, y, category, name, title, class token (class trainers), factions ("A", "H" or "AH"), optional NPC ID } }`, x and y in map percent. NPCs Forever added sit last in each map's list. Forever redrew Stormwind, Mulgore, Redridge and the Eastern Plaguelands, so Classic positions there went through world coordinates.
- `ns.TownCapitals` lists the capitals' maps: the game reports them as zones, so this is the only way to tell.
- The town pins, the Boat and Zeppelin Timers, the Flight Point Reminder, Glimmer's spots and the Waypoint Pin read a map's data through `Places.SameMap`, so Zephras Isle's second map (2665) shows 2521's (Shared/README.md, Why).
- `/naowh townaudit` checks that data against Forever by standing at each NPC: opening their window records where you are next to where the data puts them, in the account store (`townAudit[mapID][name]`).
- The hint lines' light blue (`HINT`) goes through `SoftBlue`: the shade it always was, or the theme's lighter Accent once a theme changes the Accent.
- The map calls `CheckMouseButtonPassthrough` on every acquired pin, and its SetPassThroughButtons is protected: from our refresh it is blocked in combat. Town pins take no clicks, so clicks reach the map anyway; zone exits and docks are separate clickable pins, so the vendor and trainer pins stay click-through. A zeppelin tower's pin has a second destination on right click. Their click opens the map with `C_Map.OpenWorldMap`, never the map's `SetMapID`: written from addon code, the map's `mapID` stays tainted for the session, and the next map opened in combat blocks the quest pins' SetPassThroughButtons.
- Forever has no map links of its own (`GetMapLinksForMap` returns nothing), so the exits come from `ZoneExits.lua`. `EXIT_SHRINK` (0.6) makes an exit arrow 40% smaller than a pin, so it stands no bigger than the others, and `EXIT_LENGTH` is its length in its own widths.
- Vendors & Trainers Only in Cities (`townCapitalsOnly`) keeps vendors, trainers and the bank off questing maps. Flight masters, innkeepers and stable masters (`EVERYWHERE`) are what a traveller looks for in any town, so they show on every map with it on, except stable masters, which only a hunter (`STABLE_CLASS`) sees; so do mailboxes and spirit healers, which are what you look for out in the world.
- `townMinimap` is the minimap's mailboxes and `townMinimapSpirit` its spirit healers: `townMinimap` once held both, so existing profiles keep their mailboxes.
- Which town pins show is chosen on the map itself, from the Town Pins button (`MapPinsPanel.lua`), and only there: the long list of town pin types is what you pick while looking at the map. Everything else is on QoL's Map & Pins tab and only there: a Map Options card (id `mapOptions`) and a Map Pins card (id `townMap`: Town Pin Size, then each module's pins under its title). No setting is in both places but Town Pin Size. The Map Pins card's search words include every town pin's name, so the options search still leads there. The keys stay in the QoL store, so saved settings carry over. The button shows whenever QoL is on, since the drawer is also where a switch that is off is turned back on.
- Map & Pins is the home of every map pin and map option: the town pins, QoL's own Unexplored Areas, Zone Levels, Fishing Levels and Skyborne Spots, Discovery's quests, rares, library books and Sleeping Bag steps, and the Dungeon Journal's entrances. Each of the last adds a section to `ns.Shared.MapPins` (`{ title, order, store, switch, rows, map }`), and `ns.Shared.MapPinSections()` hands them back by `order` (10 to 13 the map options, then the sections with no `order`, which count as 50, in load order, and Skyborne last at 60). A section's `title` is its group; one with no title continues the group above. Sections marked `map` (Unexplored Areas, Zone Levels, Fishing Levels) are the Map Options card's rows, the rest follow Town Pin Size on Map Pins under their titles. Rows of another module's store are `lent`, so a card's Reset and changed count leave them to their module. A module that is not loaded adds nothing, and a section whose `hidden` says so is left off (Skyborne Spots for anyone not Skyborne). Drawer rows dim and lock while their `needs` fails: the town rows while Town Pins is off. A town row with a `class` shows only for that class (Stable Masters, hunters). The drawer has its own Town Pins switch, so the town pins can be turned back on from the map.
- The Town Pins button sits in the map's top right corner, left of the buttons the map keeps there and at their size, so they read as one row. Those are found by where they sit, not by name, so a map with more, fewer or none of them still gets a free spot.
- The drawer is the options window's look: a header strip in the panel color, small accent group titles and ruled rows with the switch on the right. It is the map's child, so it opens, closes and scales with the map, `PANEL_LEVEL` over the map's pins as the Dungeon Journal's drawer.
- The drawer sits against the map window's left side (the Dungeon Journal takes the right), `GAP` -1 putting its border on the map's so the two read as one window; with no room there, the right. It is the map's height, as wide as the quest log beside the map (`PANEL_W` where there is none), and its rows shrink to fit a small map, down to `ROW_MIN_H`; past that they scroll, so the drawer never runs off the map. The scroll bar sits inside the rows' right margin, raised over them so its grip takes the mouse.
- The maximized map letterboxes its picture on a wide screen, so there the drawer goes in the black bar left of the picture, as wide as the bar allows; with no bar `BAR_MIN_W` wide it hangs under the Map Pins button, which stays free to close it. Either way it is no taller than the picture and its rows scroll. The map's Maximize and Minimize place it again.
- On the minimap, the game says when you start and stop moving but not where you are, so the pins are placed every `MINI_INTERVAL` (0.05 s) while you move, or always with a rotating minimap, for turning. The zone's map is kept in world coordinates (its continent, top left corner and the steps for one whole map across and down): `UnitPosition` makes no table each tick, `GetPlayerMapPosition` does.
- Minimap pins follow Town Pin Size too, at `MINI_SCALE` (0.9) of it: Town Pin Size 20 makes them 18, the size of the game's own tracking icons beside them.
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
- Stands down while `ns.GamepadOwnsPanels()`: the map is left where the game puts it and the grip and handle are hidden. The gamepad UI focuses the map inside `ShowUIPanel`, after its OnShow, and builds its footer bindings from there; our scale and anchor in that OnShow tainted that path, which tainted Blizzard's binding-group counter (`nextBindingGroupId`) for the rest of the session, so every gamepad binding change was blocked in combat.

### Restock
- `FAMILIES` are the class spells that use a vendor reagent on Forever, from its SpellReagents data (build 1.60.1.69913). Each family lists its ranks from lowest; the highest rank you know sets the reagent, so a rank 2 Prayer of Fortitude asks for Sacred Candles, not Holy Candles.
- `TARGETS` is how many of each reagent to carry unless the player sets their own.
- Forever reports an empty ammo slot as item 0, not nil.
- Equipped thrown weapons are restocked only when their maximum stack size exceeds one;
  permanent single weapons are not ammunition. Uncached item data is requested once and the
  existing GET_ITEM_INFO_RECEIVED path checks again, without guessing a restock target.
- Food and drink are Consumable: Food & Drink (`FOOD_CLASS`, `FOOD_SUBCLASS`). Drink is told apart by its spell: `DRINK_ITEM` (159, Refreshing Spring Water) carries the localized Drink spell, so its data is asked for up front.
- Quivers, ammo pouches and soul bags do not count as room: only plain bags (`PLAIN_BAG`) add free slots.
- The reminder pulses `FLASH_LOOPS` times when it appears, then stays solid until it is dealt with; refreshed as bags change, only a new appearance pulses.
- It shows on reaching a rested area, and again `SETTLE_DELAY` after a vendor closes if anything is still short: bags settle a moment after the last purchase or sale. Restocked from the bank, mail or a trade, the list follows while it is up.
- A purchase returns what it spent because GetMoney() does not drop until the server answers. A vendor that sells in bundles (arrows by 200) only takes whole bundles, so the amount rounds up to one.
- Auto Repair and Auto Sell Junk work at the vendor whether or not the reminder is on. Reagents are cached at switch-on so the reminder can name ones the client has not seen this session.

### Gear Reminders
- Worn Gear Reminder and Fishing Pole Reminder were part of AuraBuffs' Buffs & Consumables row until they
  moved here, with their own icons and mover, so they work with AuraBuffs off. The setting keys are the same
  (`wornReminders`, `fishingPoleReminder`, `fishingPoleWhere`): a profile's values in the `auraBuffs` table move
  to the QoL store on `Apply` (which also runs on a profile switch or import) and leave `auraBuffs`. A value
  already in the QoL store is never replaced, and a false moves as false.
- Cloak of Hermitic Bliss (273084, a Kresh drop, new in Forever) slows you 25% and speeds swimming 33%, so it
  gets worn for Wailing Caverns' water and forgotten. Wailing Caverns is instance ID 43 (`GetInstanceInfo`'s
  eighth value). Item and effects from Wowhead's Forever tooltip, 2026-10-14; not yet checked in the client.
- A fishing pole in the main hand reminds anywhere by default (Robin asked for it), or only in dungeons and
  raids (`fishingPoleWhere`). It is matched by its weapon subclass, `Enum.ItemWeaponSubclass.Fishingpole`, not
  by item ID or name, so every pole counts in every locale; `GetItemInfoInstant` needs no cached item.
- An icon stays up while you fish, so Ctrl-click hides it for that item (`dismissed`, per slot, not saved): a
  different item there, or `PLAYER_EQUIPMENT_CHANGED` taking it off, shows it again. The icons are plain
  frames, not secure buttons, so they also update in combat.
- It reads on `PLAYER_EQUIPMENT_CHANGED`, `ZONE_CHANGED_NEW_AREA` and `PLAYER_ENTERING_WORLD`, registered only
  while a switch is on. Unlock Mode shows a sample of each reminder that is on (the cloak, and a Fishing Pole,
  6256).

### Waypoint Pin
- Quest Objectives and Downward Arrows are independent switches, initially off. Objectives come from the tracked quest or guide context and refresh on quest-log changes; unfinished objectives keep the quest pin visible inside its area. The three chevrons use the existing shared arrow art and disappear in off-screen and arrival modes.
- Follow RestedXP is initially off and uses the shared guide waypoint feed. Guide destinations skip our manual-pin auto-clear; if native navigation ends at arrival, the pin waits for the next guide destination. RestedXP's own arrow stays shown throughout. A manual pin temporarily takes priority until the next guide destination.
- It follows the game's navigation frame (`C_Navigation`), so quests, your corpse and map pins get it as well as `ns.PlaceWaypoint`'s spots, which it names. A user waypoint counts as ours when it lies within `SAME_SPOT` (map percent) of `ns.placedWaypoint`.
- A map pin's or corpse's navigation point is the spot on the ground: the ring at the line's foot goes there and the pin stands above it. A quest giver's is over their head, where the pin goes as it is, with no line down.
- The game clears a map pin on arrival, but it keeps tracking a quest, and Forever reports a quest reached only right on its point. So for a tracked quest the pin and cue go within `QUEST_NEAR` (40 yards) of its point, the quest's area or the quest giver, and come back past `QUEST_LEAVE` (55), so walking about the area does not make them flicker. The game has no call that says you are inside a quest's area (Forever's QuestLog and Navigation docs: only map points, `IsOnMap` and a display state), so the distance stands in for it. Other targets use Arrival Distance (`waypointArrive`, 5 yards by default) and come back `LEAVE_MARGIN` (2) yards past it. The navigator stays.
- The walking time comes from how fast the distance shrinks, sampled every `SAMPLE_EVERY` second and smoothed by `SMOOTH`. Your speed reads secret at times (on a mount too), and the last readable one was often the run on foot, so a mounted time came out about double. A sample under `MIN_CLOSING` (stopped, turned away) or over `MAX_CLOSING` (the spot moved) drops the pace, and so does a new target; without one, the time uses your last readable speed, or `RUN_SPEED` (7 yards a second) standing still.
- The card and navigator are repainted only when the mode, side, whole yards or whole seconds change; the place and arrows move every frame, and nothing is built per frame.
- The pin stands on its spot only inside an oval around the middle of the screen, `EDGE_RING` (0.3) of its width and height out from the centre. Past it, on screen or off, it rides the oval with its arrow: the minimap, quest tracker, buffs and bars sit at the edges and corners, and a pin and card clamped there landed on top of them. One boundary for both cases means no jump when the game starts clamping the spot, which it does right at the screen's edge. With Edge Arrow Off Screen off, a spot on screen keeps its pin wherever it is. Once past the oval it holds there until the spot is back inside `EDGE_BACK` (0.9) of it, so a spot sitting on the line does not flicker between the two looks. Within `EDGE_NEAR` (40 yards) a spot on screen keeps its pin, beam and fade wherever it is: walking up to it, it is often low on screen.
- Behind you is the game's clamped spot within `BEHIND` of straight down, not the oval's: a spot low on screen past the oval is in front of you.
- `BEHIND` is the angle either side of straight down that counts as behind you. `FAR` is the distance at which the pin is smallest (`FAR_SCALE`), and `FADE_FLOOR` its alpha at your feet with Fade Up Close on.
- The game places a waypoint you click on the map without tracking it (its map code calls `SetSuperTrackedUserWaypoint(false)` right after `SetUserWaypoint`), and the pin only follows what is tracked, so on `USER_WAYPOINT_UPDATED` it tracks the new waypoint itself: one frame later with the map closed (the game's own untracking has run by then), or as the map closes (`trackOnMapClose`), as `Core/Waypoint.lua` holds its own placements, since setting one with the map open taints it. Already tracked, it leaves it.
- A waypoint you set has no held arrival: reaching it plays the sound and the pin, cue and bar go at once. A quest, the corpse and a route's stop hold the arrival where the pin last stood for `ARRIVED_HOLD` (a route's names the next stop). The game clears a waypoint you set as you reach it, its navigation frame going too, before or after NAVIGATION_DESTINATION_REACHED; that event's `isWaypoint` is a stop on the way (a zone's exit), not the spot itself. A waypoint you set does not wait for it: on the waypoint's map or one inside it (a waypoint placed on a continent still counts in its zones; the game routes a waypoint on another map through stops on the way, such as a zone's exit, which are not the spot), within Arrival Distance of its spot once the pin has seen you more than `LEAVE_MARGIN` past it, or within `REACHED` (5 yards) once it has seen you more than `LEAVE_MARGIN` past that, since the waypoint was attached or placed (a new waypoint can report no distance at first, and one placed under you has nothing to reach; other tracking changes on the way do not reset it), the pin shows the arrival and clears the waypoint itself, so it goes even when the game sends no arrival, or sends it as a stop. The game's event, when it does come first, clears it before the pin does. It does this once per waypoint (`selfCleared`: with the world map open the clear is held, and the pin must not arrive again every hold), and never on a route's stop, which moves on by the game's arrival event: clearing it would end the route. The `REACHED` fallback keeps a waypoint placed inside a long Arrival Distance from clearing at once.
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
- Looting an item that already has a line on screen adds to that line's count and value and holds it another display time, the same as coins. Items match by link, so two variants of one item stay apart.
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
- The bar takes clicks only while Ctrl is down, for its reset click; otherwise a click or a camera drag that starts over it goes through to the world. It follows the mouse without taking clicks (SetMouseMotionEnabled) while Show Texts On Mouseover or Hover Breakdown is on; its hover area then reaches the texts around it (SetHitRectInsets), so moving onto a text keeps them up.
- Leveling Pace is Time to Level and XP/h in one text. Time to Level, XP/h and Leveling Pace stay blank until XP comes in this session, never `--` or `0`.
- The effects (`XPBarFX.lua`, its own file because XPBar.lua sits near the 200-local cap) each have a switch: Shine and Notches are on, as the bar's look; Rested Stripes, Quest XP Pulse, Ready to Level, Level-Up Flash and Hover Breakdown start off. They use the game's own animations (AnimationGroup), so nothing runs per frame: the quest pulse plays once per hand-in, the Ready to Level glow loops only while completed quests cover the rest of the level, and the level-up flash plays once on PLAYER_LEVEL_UP. The quest pulse comes from QUEST_TURNED_IN's XP reward, so kills never pulse. That event and PLAYER_XP_UPDATE come in either order, so the pulse waits for the fill to move, or `PULSE.WAIT` at most (a redraw follows `FX.SETTLE` after the hand-in), and the slice is the reward's width back from where the fill ends: right in either order, and cut at the bar's start when the reward levels you. Hand-ins between two draws add up into one pulse.
- Hover Breakdown's kills are of your own level, `5 x level + 45` XP each (Classic's formula for a normal mob of your level), counted double while rested XP lasts, so it says "About".
- The texts are picked on the preview, so their rows are not drawn on the page; they are still declared for the search, the changed count and the card's Reset. A preview spot answers HandlesGlobalMouseEvent so the menu manager does not close its menu before OnMouseDown toggles it.
- The card's preview draws the bar at its real size, never enlarged, and shrinks it only when it does not fit. Its Quest Hand-In, Ready and Level Up states play the effects, each while its switch is on. An empty spot is a small + that shows only while the mouse is over the stage, placed after the texts so it never covers one. The two Resets live in the preview's right-click menu, as on the Campfire card, which keeps the rows to the settings themselves.

### Unexplored Areas
- The overlays (`MapOverlays.lua`, generated by `Tools/build/map_overlays.py` from the game's tables) are `[uiMapID] = { { width, height, offsetX, offsetY, fileDataID, ... } }`: an area's size and place on the map art in its pixels, then its `TILE` (256 px) tiles row by row (`AREA_FIELDS` before them).
- A tile's drawn size and its texture file's size differ along one side: the last tile of a row or column holds what is left, in a file rounded up to a power of two (from `SMALLEST_FILE`).
- The pin is one for the whole map, holding every unexplored area's tiles. Its `CheckMouseButtonPassthrough` is left empty: the map calls it on every acquired pin, its SetPassThroughButtons is protected in combat, and this pin takes no clicks.

### Zone Levels and Fishing Levels
- Forever's client tables give no outdoor zone a level range (no ContentTuningID on UiMap or AreaTable), so `C_Map.GetMapLevels` has nothing and the game's own map label never shows one. The ranges come from Wowhead's Forever world map instead, written to `ZoneLevelsData.lua` by `Tools/build/zone_levels.py`; Moonglade, Mount Hyjal and Shen'dralas have none there.
- The range is our own text under the game's area label (its Description), so nothing is written into Blizzard's label. The colour follows the game's rule for a range: the low end's colour below it, the high end less `BELOW_RANGE` above it, yellow inside.
- Fishing Levels is a second line of our own under the range (under the game's Description when the range is off or the zone has none), on its own switch, from the same hovered zone. A zone's pair in `FishingLevelsData.lua` is the lowest skill that fishes there and the skill no fish gets away from, 95 apart, the low end never under 1. Neither the client tables nor Wowhead's Forever pages carry it, so the numbers are entered by hand from Classic and cross-checked against warcraft.wiki.gg and Classic fishing guides; zones with no water to fish and Forever's own zones are left out.
- The colour is against your Fishing skill with gear and lures: red under the low end, yellow until the high end, green from it, grey without Fishing. Your skill is `GetProfessions()`'s fourth slot (`FISHING_SLOT`), read when the hovered zone changes.

### Mana Efficiency
- Its amounts come from `SpellEfficiencyData.lua`, generated by `Tools/build/spell_efficiency.py` from the game's own spell tables (wago.tools, the build in its header), keyed by spell ID. Nothing is read from tooltip text.
- An entry is `school, level, maxLevel, area`, then one part per kind of amount the spell has on its target: `kind, direct, directPerLevel, directCoefficient, tick, tickPerLevel, tickCoefficient, ticks, seconds`. A spell that heals and damages the same target has two parts and gets two lines (none does in this build). `area` is 1 for a spell whose first amount reaches everyone in an area or cone, or on an aura on everyone near (Frost Nova, Arcane Explosion, Prayer of Healing, Tranquility, Hellfire): its numbers are for one target and every number on its line ends with `/ target`.
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
- Include My Talents (on by default) counts the talents that change what a spell does or costs, at your rank in each (`C_ClassTalents.GetActiveConfigID` with `C_Traits.GetNodeInfo`, the same read the Training builds use). `SpellEfficiencyData.lua` also holds `ns.SpellEfficiencyTalents`, spell ID to a string of mods joined by `;`, each `node, op, value at rank 1, 2, ...`, where op 0 is the direct part, 1 the ticks, 2 a crit refund and 3 a free cast. The builder writes a mod for every passive class talent whose percent aura (spell mod 0, damage and healing, or 22, over time) has the spell in its class mask; a talent's value at each rank is a curve in the tables (`TraitDefinitionEffectPoints`, `CurvePoint`), since Forever has no spell per rank. An effect with no curve of its own grows like the talent's effect that has one (Piercing Ice's periodic percent), and a talent whose direct percent names a spell with ticks, with no periodic percent for it, counts on the ticks too (Gift of Nature on Tranquility, Arcane Instability on Frostfire Bolt). Percents of one kind add together and multiply the whole amount, spell power included: Healing Light, Spiritual Healing, Improved Renew, Fire Power.
- Two talents that spare mana have no numbers in the tables and are written from the game's description: Illumination (op 2: a crit heal gives back half its base cost, at the chance the tables give the rank; your cost is cut by that times your spell crit chance, `GetSpellCritChance` for the spell's school, left uncounted while stats are secret) and Elemental Focus (op 3: a 10% chance the next damage spell is free, for shaman fire, frost and nature spells). The cost they cut is the game's own shown cost, so talents that already lower the cost (Convection, Improved Healing) are counted by the game, not twice.
- Not counted: buffs, crits' extra damage, hit, resists and target conditions, and talents with a dummy or script effect, an on-use talent (Arcane Power, Presence of Mind, Divine Favor), Arcane Concentration and the ones that change the cast time or duration (the cast time is the game's own). A chain spell (Chain Heal, Chain Lightning) counts its first target; an area spell counts one target of the area, with the same ticks per target. Nothing in this build splits one amount between the targets.
- Left out, with no line, because part of their amount is somewhere the client's tables do not say (better no line than a wrong number): weapon damage (Aimed Shot, Multi-Shot), a triggered spell or proc (seals, Judgement), a dummy or script effect (Swiftmend, and Immolate, whose ranks carry a script effect in this build), and a direct base of 1 with no bonus (a scripted amount's placeholder).
- A spell whose amount is in a spell its own description names is read from that spell, the same pointer the game's tooltip follows (`Spell.Description_lang`, like `$1279976s1`). An area trigger (Blizzard, Rain of Fire, Flamestrike's burn, Consecration, Hurricane, Volley) is the named spell's amount once a period (the periodic dummy aura 226) for the aura's duration, as the ticks of one target; a count in the description ("*8") has to equal the ticks, or the spell is left out. Consecration's second amount, for the first enemies in the area, is added: one target is always among them. A dummy spell naming a damage spell and a heal spell that are not over time (Holy Shock, Fire Nova) gets a part for each, and is an area spell when the named spell's targets are. Healing Rain (its amount is a percent of healing power in the description), Penance (several hits) and Light's Vigil (a buff) are still left out.
- A periodic trigger is counted (Arcane Missiles): the missile spell is named in the effect itself, not chosen by a seal or a proc.
- What a spell does is what it does to its target: a heal on the caster from a damage spell (Drain Life, Death Coil) is not counted.
- The separator is written `||`, which the game draws as one `|`.
- A macro on an action bar has its own tooltip type (`Enum.TooltipDataType.Macro`, 25), so it gets its own post-call. The macro's tooltip data is not documented, so the spell comes from the hovered button instead: the tooltip owner's `action` slot (or its `action` attribute, for bar addons' secure buttons) through `GetActionInfo`, which returns `"macro", spellID, "spell"` while the macro shows a spell (Blizzard's glow and assisted-combat code compare that id to a spell ID) and `"macro", macroID` otherwise, resolved by `GetMacroSpell`. A `#showtooltip` macro follows its conditionals because the game resolves the spell. With no readable action there is no line: `data.id` is not a reliable macro index. A macro with no spell, or whose spell has no entry, gets no line, and the line is added once per tooltip build as for spells.
- The spell post-call goes on the first time the switch is on, and stays inert after it goes off (TooltipDataProcessor has no removal). The line is added once per tooltip build, as the ID line is.
- Preview Tooltip opens Lesser Heal rank 3 (`PREVIEW_SPELL`) with the line, even with the switch off. The card's preview draws two sample spells from fixed numbers (`SAMPLES`, `SAMPLE_POWER`), never a real spell.
- `ns.SpellEfficiencyOf(spellID, out)` is the one place a rank's numbers are worked out: its mana (after talents), cast time, level, area flag and, for each kind it shows, the amount, per mana, per second and per mana per second. The tooltip line and the Mana Efficiency window both read it, so they cannot disagree. The tooltip passes one table it keeps, so a hover allocates nothing.
- The Mana Efficiency window lists the spells in the data you know (`C_SpellBook.IsSpellKnown` on each rank's ID; Forever keeps every rank known), grouped by name, one group per kind for a spell that both heals and deals damage. Ranks are separate spell IDs, matched by name (`C_Spell.GetSpellName`); no two classes share a name in the data. The ranks above your highest known one are listed greyed, one per rank text (`C_Spell.GetSpellSubtext`), so a rank the data holds under two IDs (Renew, Drain Life and Fire Blast have a second set at the same levels) shows once when both carry the same text, and an ID with no rank text is left out; a rank whose text is not loaded yet is asked for (`C_Spell.RequestLoadSpellData`) and shows on the redraw.
- The star marks the known rank with the most per mana in its group. A column header sorts the ranks inside each spell (numbers start highest first, Rank lowest first); the spells stay in name order. The window follows the Tooltips card's Per Mana, Per Second, Per Mana per Second, Style, Decimals, Show On, Include My Spell Power and Include My Talents, and works with the tooltip line off. It is built on first open, and redraws on SPELLS_CHANGED, PLAYER_LEVEL_UP, TRAIT_CONFIG_UPDATED and SPELL_DATA_LOAD_RESULT only while shown.
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

### Glimmer
- Herbs, ore, quest objects, chests and your fishing bobber light up as you walk up to them, in one of
  five effects: dim while out of reach, a flash and full brightness once you can use them. Its tab is
  QoL > Glimmer, its on/off the Glimmer card's switch there. It keeps its own settings store,
  `ns.GlimmerSettings` (the profile's `glimmer` table, defaults from `ns.FEATURES.glimmer`), not
  `ns.QoLSettings`: it was a module addon of its own (NaowhForever_Glimmer) before it moved into QoL,
  and the same table means every setting carried over with no migration.
- Herbs and ore take the color of your chance of a skill-up and get a line under their name saying so; a
  node your skill is too low for shows red with the skill it needs; a character without Herbalism or
  Mining at all sees no herbs or ore lit, since they are not theirs to gather. Quest objects are
  found three ways: the game marking them quest related, a quest objective in their tooltip, or the
  quest pick-up or turn-in cursor the game shows on them; that cursor is also what lights an NPC with a
  quest to pick up or hand in, the only NPCs Glimmer lights. Quest objects get the line of the
  quest objective they count for. Quest Item Sparkle keeps the game's loot sparkle on quest items
  through graphics presets. Minimap Icons shows every spot herbs and ore grow near you, ringed in their
  skill-up color, and Gathered on the Map every herb and vein you gather.
- Quest Givers were part of Quest Objects until they got their own category, and turning Quest Objects
  off was the only way to keep the nameplate off quest NPCs. A profile with no `giver` setting yet
  takes `quest`, `questStyle` and `questColor` for it on `ns.Apply`, which also runs on a profile
  switch; once `giver` is set it never runs again for that profile.
- Its spots (25,177 on 44 maps) used to be the load-on-demand NaowhForever_GlimmerData; they are now one string in
  QoL, CBOR deflated in Base64 (about 130 KB), which Spots.Load unpacks with the client's own C_EncodingUtil
  the first time Minimap Icons or Gathered on the Map needs them (about 1.2 MB as a table, measured in Lua 5.1),
  then lets the string go. A player who never turns those on holds only the string, and there is one addon
  fewer in the list. It never unpacks in combat. An old NaowhForever_GlimmerData folder is switched off at
  login with a note to delete it.
- The game always picks one object to interact with, the `softinteract` unit, and gives it a
  nameplate when `SoftTargetNameplateInteract` is on. Glimmer hangs its effect on that nameplate,
  so only that one object lights up and the effect follows it on screen with no work of ours.
- `SoftTargetInteract` 3 keeps the soft target on, and `SoftTargetInteractOnlyInRange` 0 lets it pick
  objects beyond reach, so they can light up dim before you get there. The range is capped at 15
  yards on the page because the client drops the soft target near there whatever is asked.
- `SoftTargetIconGameObject` 1 is needed too: with it at 0 the game picks the object as the soft
  target but never makes its nameplate, so nothing lights up. A setting Glimmer adds later is saved
  into the old values the first time it is written, so turning Glimmer off puts it back as well.
- The nameplate is only opened for an object Glimmer lights (`onlyHighlighted`), so NPCs, mailboxes
  and doors do not grow a nameplate. Whether to open it does not need the nameplate: the object is
  read from the unit token, then the nameplate arrives with `NAME_PLATE_UNIT_ADDED`.
- In combat the game will not change these settings, and an open soft target nameplate would sit
  on every lootable corpse with 0% health. The nameplate is closed on `PLAYER_REGEN_DISABLED`, just
  before the lockdown, and Glimmer rests until combat ends; a setting changed in combat is applied
  after it.
- What an object is comes from the object ID in its GUID, looked up in `G.NODES`; the bobber is
  object 35591. IDs work in every language. A herb or vein the data does not know is still found by
  the cursor the game would show on it (`SetUnitCursorTexture`): Mine or GatherHerbs, with an Unable
  variant when the game would refuse it.
- The game gives an NPC's quest cursor only as a low priority one: `SetUnitCursorTexture` answers false for a
  quest giver unless its fourth argument, `includeLowPriority`, is true, so the giver check passes it and the
  object check does not. The texture comes back as a name (`Cursor Crosshair_QuestTurnIn_64`), matched by its
  words like the other cursors.
- Quest objects come from `C_QuestLog.UnitIsRelatedToActiveQuest`, and their line is the quest
  objective line of the object's own tooltip, as the game words it.
- Gathering gives a point every time up to 25 skill over the node's (orange), usually up to 50
  (yellow), rarely up to 100 (green), and never past that (grey): `SKILL_ORANGE`, `SKILL_YELLOW`,
  `SKILL_GREEN`. The node's skill comes from the data, so a node your skill is too low for is red
  from as far as it is picked, not only once in reach.
- `UnitIsInInteractRange` is not in the 12.1 API docs but answers on Forever; without it every
  object counts as in reach. Its answer is read every `STATE_CHECK` while an object is lit, and a
  change must hold for `STATE_HOLD` before it shows, so the edge of reach does not flicker. That
  check runs only while something is lit; nothing runs while no object is.
- A quest giver's nameplate is the game's friendly one, with its health bar and level. Hide Health Bar and Level
  (`giverHideBar`, off by default) sets the alpha of the plate's `HealthBarsContainer`, `LevelFrame` and `PlayerLevelDiffFrame` to 0 while
  Glimmer lights a giver, leaving the name. Forever's plate shows the level in `PlayerLevelDiffFrame`, the boxed
  number beside the bar; `LevelFrame` is the retail one it keeps hidden. The plate's unit frame is pooled by the game, so all three are set back to 1
  when the effect is released. Effect Height (`giverOffset`, pixels, 0 by default) moves a giver's effect from the
  same anchor an object's uses, since a plate over a creature's head sits at a different height than one over an
  object. Both apply on the next frame, like the other settings.
- The effect is parented to the nameplate, one frame level under it so the game's name stays on
  top, and ignores the nameplate's alpha so it does not fade with it.
- The game settings Glimmer changes are saved in the account settings before the first change and
  written back when Glimmer or the Quest Item Sparkle is turned off, or by Restore. A graphics
  preset turns the quest sparkle settings back; `CVAR_UPDATE` on a preset or one of those settings
  puts them back `SPARKLE_AGAIN` seconds later, after the preset has finished writing.
- Taking the quest sparkle off only shows after a full restart of the game, so the card says so.
- There used to be a Behind My Character cut-out, a mask at a guessed spot near the middle of the
  screen, since the game does not tell an addon where your character is. It took three settings to fit
  and testers did not understand it, so it was removed.
- Other addons that change the same soft target settings (`OTHER_ADDONS`) undo Glimmer's and it
  undoes theirs; with one on as well, Glimmer asks once per session to disable it.
- A slider drag sets its key on every step, so settings apply once on the next frame.
- The game does not tell an addon where its tracking dots are, and it cannot switch tracking for you:
  Find Herbs and Find Minerals are casts, which only a click may start. So the minimap icons come from
  where Wowhead Forever has each herb and vein growing (`ns.GlimmerSpots`, unpacked from
  Data/Spots.lua on first use), and herbs and ore show together whatever you track. The icons draw over
  the game's tracking dot, so while Find Herbs or Find Minerals tracks (`MINIMAP_UPDATE_TRACKING`),
  that kind's icon moves onto its ring and the dot shows inside the ring when the node is up.
- The minimap shows at most `MINIMAP_MAX` icons, the spots inside its view. Placing them is
  `Parts.MinimapLayer` (Shared/UI/MinimapPins.lua): it moves them only while you move or the minimap
  turns.
- The spot data loads the first time Minimap Icons is on, out of combat: loading an addon in combat is
  not something to rely on, so it waits for the fight to end, and only then does `PLAYER_REGEN_ENABLED`
  redraw the icons. A skill-up repaints their rings, and redraws them only when it changes whether
  herbs or ore show. Gathered on the Map alone never loads the data.
- Only My Professions shows herbs to an herbalist and ore to a miner, and nothing to a character with
  neither (the spot data is not even unpacked); players read a character with no gathering showing both
  as the setting not working. It is a Minimap Icons setting: Gathered on the Map shows the account's
  gathers on any character.
- A gather is noted when the loot window opens while the soft target is a herb or vein in reach and
  the loot came from it (`GetLootSourceInfo`), so it needs no spell IDs and a corpse looted beside a
  node does not count. One node counts once per loot window, even if it is opened again. Where it is
  noted is a pin already there for that node within `SNAP` (tenths of a map percent) of where you
  stand, else the data's own spot for it when the data is loaded, else where you stand, so gathering
  a node again when it grows back counts on the same pin. Each
  map keeps at most `MAX_GATHERED` nodes, dropping the one gathered longest ago. They are kept in the
  account settings, so every character's gathering shows.
- Check it offline: `lua Tools/regression/test-glimmer.lua`: reading the target, skill-up colors, the game settings
  saved and put back, combat, the nameplate it opens, the minimap icons and the gathered pins, against
  stubs of the game's API.

### QoL defaults (Core/Settings.lua)
- Every on/off switch default in the QoL store is read from `ns.FEATURES.qol`; the values are unchanged.
- The supporter badges are on by default so everyone sees them, except the group banner, which Naowh asked to start off.
- The Character Panel's slot marks are on by default, an exception to off by default: they are marks on the game's own panel, with no restyle.


### Zone Info

- QoL > Map & Pins > Zone Info adds a compact map hover and a pinned details panel.
  Apply beside Recommended Details enables the master switch and dungeon, fishing and travel content; the HUD and
  gathering tab stay optional. Every new feature switch is off by default in Core/Features.lua.
- The existing zone-level and fishing labels stand aside while Zone Info is enabled, without
  changing their saved switches, and return when it is disabled.
- Map hover queries run only while the map is visible and the cursor moves, at most once per
  0.08 seconds. Closing the map clears the ticker; disabling removes the provider and unregisters
  every feature event. No event frame, provider or HUD is constructed while the feature is off.
- Pin details holds one zone through unrelated hovers and map changes. The saved map ID belongs
  to the current profile. The map button pins the hovered zone, the displayed zone, or the player's
  zone. Current Zone Details opens our own panel when the map is closed, without opening Blizzard UI.
- The current-zone HUD belongs to the shared HUD Editor, with position and scale in QoL settings.
  Zone, skill and level events refresh it, not a per-frame ticker. Combat hides it when requested;
  otherwise it keeps its last checked character information until combat ends.
- Profession skill includes GetProfessionInfo's eighth return (rankModifier). Levels, skills and
  map fields are checked before use; unavailable skills are not treated as missing or ready.
  Difficulty colors use the checked cached level and static house colors, not a helper which
  reads UnitEffectiveLevel again. PLAYER_LEVEL_UP's level payload refreshes the cached level.
- Dungeon entries reuse the enabled Journal's registry, entrances and level ranges. No Journal
  means an explanation, not an assumed dependency. Journal settings repaint a visible zone panel.
  Opening a dungeon is an explicit click on our own Journal UI. Waypoint actions use PlaceWaypoint
  and are unavailable during combat; they never open or modify Blizzard's own frames.
- Travel reuses TownNPCs flight masters, TownTravel stops and ZoneExits roads, filtering faction
  stops against the checked character faction. SameMap resolves equivalent map IDs as it does
  for existing map pins. Missing data is labeled rather than guessed.
- Gathering reuses Glimmer's node definitions and compressed location data. It decodes only
  when the gathering tab is requested outside combat and indexes unique node names per map.
  Glimmer itself need not be enabled and none of its switches change. A waypoint is a known
  historical location, not a claim that the object is currently spawned or the nearest node.
- Fishing distinguishes the minimum skill from the reliable threshold and displays the player's
  checked skill. Territory text is shown only for the current zone, from the client's PvP API;
  territory for a different hovered zone is omitted because the existing registries do not supply it.
- Details use shared panels, tabs, buttons, fonts and pooled row drawing. The preview uses the
  same HUD drawing with sample Westfall data; it does not activate the feature or register a mover.

- Map panels use an opaque theme fill, with their layer set above the canvas after parenting,
  so the map cannot cover their background, title or metadata. Parts.Panel accepts an optional
  flat-fill opacity; other callers retain their existing opacity.
- Pinned map details dock outside the whole Map and Quest Log window on its right, with
  width fitted to the available screen space. If only the left side has room, they dock there.
- The compact hover card uses the same external dock; visible pinned details stack below it.
  The map button sits above the two coordinate lines rather than covering their text.
- On-map Summary is an off-by-default alternative to docked cards: centered outlined text
  shows the selected zone, or the hovered/current zone on continent maps. Map Text Only > Apply
  enables all content, disables the HUD, clears the pinned selection and selects this layout.
  Recommended Details > Apply returns to the docked layout. Content switches still apply.
- Map text is pooled, mouse-transparent and refreshed by the existing map provider and zone,
  profession and level events. It has no additional ticker. Gathering remains known static
  data; a short list ends with a count when there are more entries. Missing data is omitted.
- The built-in area-label frame is faded while our map summary is visible, then restored to
  its original alpha when the map closes or this layout is disabled; no Blizzard script,
  label content or layout is replaced. This avoids duplicate zone names at the top of the map.
- A hover selection stays available across empty map space, the canvas boundary, same-map
  redraws and character refreshes so its Pin Details action remains reachable. Another valid
  zone replaces it; closing or changing the map, disabling the feature or combat clears it.
