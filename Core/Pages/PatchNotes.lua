-- PatchNotes.lua: the Patch Notes page, each build's notes as a card, newest first.
local ns = _G.NaowhForever

local TITLE_MAX = 60
local UNRELEASED = "Unreleased"
local TEXT_CHANGES = ns.L("%d changes")
local TEXT_IN_TESTING = ns.L("In testing, ")
local TEXT_LATEST = ns.L("Latest, ")
local TEXT_NEXT_RELEASE = "Next Release"

local NOTES = {
    { title = "0.5.20-beta", lines = {
        "Action Bars (Utilities): save your bars, keybinds and macros as a set and Import it "
            .. "on an alt. A set builder leaves out the slots you pick, Import shows a preview "
            .. "first, and Fill In As You Learn places spells you have not learned yet.",
        "Aim Trainer (/nfaim, QoL Travel): a shooting game for flights in Hexakill, Gridshot "
            .. "and Reflex, with a Leaderboard shared with your group and guild. Flight Games picks "
            .. "what opens when a flight starts.",
        "Scrap Marker (QoL, Loot & Items): Alt-click an item to mark it as scrap and the next "
            .. "vendor sells it. The Scrap List (/nf scrap) shows everything you marked.",
        "Dungeon Journal: Scarlet Monastery as its four wings, maps for Ruins of Lordaeron, "
            .. "Hall of Thanes and the Excavation Site, and a boss's own page from the dungeon map. "
            .. "The Dungeon Quest Tracker can open by itself in a dungeon with quests for you.",
        "Discovery: the Cozy Sleeping Bag quest chain step by step, with a tracker and map "
            .. "pins, and the third library reward at 25 books.",
        "Training Planner: a waypoint to your nearest class trainer (/nf trainer).",
        "Naowh's Forge: To Library saves your own macros to the Library for every character "
            .. "of your class.",
        "Campfire: a Simple style, a slim bar with every camp bonus and a time line.",
        "New looks: XP per Hour and Bag Space on small cards, the Flight Timer with your "
            .. "flight mount riding its track, and a Classic theme (thanks to Lyssa).",
        "RestedXP Guides: add the Naowh themes to RestedXP and give its window and arrow "
            .. "Naowh's look.",
        "QoL has a Character tab for the Character Panel, Slot Marks"
            .. (ns.FEATURE_BADGES == ns.BADGES_LIVE and ", Naowh Score and badges. " or " and Naowh Score. ")
            .. "The Character Panel and Bag Marks are now on by default.",
        "Windows and trackers can be dragged up to 90% off the screen, and the profession "
            .. "window stays where you put it.",
        "Settings: click the dot beside a setting you changed to put it back to its default.",
        "A welcome window on your first login (/nf welcome).",
        "Fixed: no more secret value errors from item and player tooltips, the character "
            .. "panel's stats while the game hides them, Naowh Score past 300 players, coin loot in "
            .. "the Loot Feed, the Delete confirmation's Yes button, the macro editor's cursor, and "
            .. "more.",
        "Most new features are off until you turn them on.",
    } },
    { title = "0.5.19-beta", lines = {
        "Training Planner (/nftraining, Adventure): what your next trainer visit costs against "
            .. "your gold, a road to 60 with every level that brings spells, and the spells you "
            .. "can train now with how much stronger each rank is. A toast on level-up, Learn All "
            .. "I Can Afford beside your class trainer, search, Show Learned and a Mini bar.",
        "Talent Builds (Training Planner): a leveling build for every class, an editor to make "
            .. "your own, Export and Import to share them, and Follow This Build spends each new "
            .. "talent point for you.",
        "Naowh's Forge (/nfmacros): a macro window that colours a macro as you type, counts its "
            .. "255 bytes, flags typos and explains each line in plain words. Smart Macros and "
            .. "Naowh's Library live there too.",
        "Dungeon Journal (/nfjournal or /nfdj): every dungeon's bosses in kill order with what "
            .. "they drop, your BiS and upgrades marked, your quests with waypoints, dungeon maps "
            .. "with the bosses where they stand, kill counts with who was there and who won what, "
            .. "and Reputation and PvP tabs with every reward. Dungeon Quests is part of it now.",
        "BiS List (/nfbis): your character in your whole BiS, every pick per slot with where it "
            .. "drops and how much stronger it makes you, Run Next for where to farm first, a "
            .. "Quests page, enchant advice and a Drop Alert when one of your picks drops.",
        "Naowh Score (BiS List): one number for your gear on the item level scale, coloured by "
            .. "how close it is to the best, on player tooltips and shared with your group and "
            .. "guild. On by default.",
        "Stat Weights (BiS List): what each stat is worth to your spec, read from your talents. "
            .. "Edit them or import from WoWSims, and turn on upgrade lines on gear tooltips.",
        "Character Panel (BiS List): your character panel in the BiS List's look, with your "
            .. "Naowh Score and your spec's stats first. Slot Marks (on by default) puts item level "
            .. "and your BiS star on your gear slots, and Bag Marks does the same in your bags with "
            .. "an arrow on upgrades.",
        "Blessings: Auto-Assign spreads blessings across the group's paladins, presets save the "
            .. "plan, class buttons show who needs a blessing at a glance, and in combat each click "
            .. "blesses the next player who needs it.",
        "Professions: Buy at Vendor, favourite recipes, a Shopping List for the auction house, "
            .. "Train Favorites, Craft Orders with another crafter, a Total Craft Timer for batches "
            .. "and Bind on Equip / Bind on Pickup filters.",
        "Settings (/nf): rebuilt with one page per module under Adventure, Combat and Utilities. "
            .. "Each feature is a card with its switch and a live preview of what it shows on "
            .. "screen, lists and editors moved to each module's own window, and profile strings "
            .. "now carry every module's settings and positions.",
        "Action Bars (Utilities): save your bars as a named set and put them back later. Also "
            .. "/nf bars save, restore, test, delete or list.",
        "Threat Meter: With Threat under Show replaces Hide When Empty, the status line can sit "
            .. "at the top, and Apply Theme to Your Bar.",
        "Top Bar: saved instances on the clock (/nf lockouts), Show On Mouseover with Faded "
            .. "Opacity, and Friends and Guild can be switched off.",
        "XP Bar: its own QoL tab with a clickable preview, three more text spots, your own "
            .. "colours, and Ctrl + right-click resets the session.",
        "Themes: colour chips preview a theme, and the Loot Feed, XP Bar, Top Bar, Swing Timer "
            .. "and more follow your colours. Thanks to Lyssa.",
        "Campfire: stat tags for each camp benefit, Show Active Camp Buffs on mouseover, and "
            .. "Ctrl-click Camp Nearby to dismiss it.",
        "Food & Drink Bar (Macros, Consumables): two buttons for the best food and drink in your "
            .. "bags, conjured first.",
        "Swing Timer: Color by Seal for paladins, the melee bars take the colour of your seal, "
            .. "Seal of Martyrdom included.",
        "Mailboxes (QoL, Interface): every mailbox on the world map, in towns and out in the "
            .. "world.",
        "Also: Group Tools (Disband, Invite, and as buttons on screen), Auto-Replace Enchants "
            .. "(hold Shift to be asked), right-click anything in Unlock Mode for its options, "
            .. "Skip Modifier for quest automation, Shift-click a "
            .. "recipe to search the AH, Flight Timer hides Blizzard's Request Stop, sound "
            .. "dropdowns play your pick and list None once.",
        "Fixed: borders and lines no longer lose a side at some UI scales, Group XP sees "
            .. "everyone again, Blessings with Forever's surnames, the Naowh font stays on this "
            .. "addon's windows, a warning at login when libraries are missing, and more.",
        "New features are off until you turn them on.",
    } },
    { title = "0.5.17-beta", lines = {
        "Group XP (QoL, XP): a bar for each group member with their level and XP, for "
            .. "levelling together. Everyone who wants to show up needs Naowh Forever with Group "
            .. "XP on.",
        "Share Quests With Group (QoL, Questing): quests you pick up from an NPC are shared "
            .. "with your group. Hold Alt to keep one to yourself.",
        "Unspent Talent Points (QoL, Combat & Alerts): a reminder while you have talent points "
            .. "to spend.",
        "Accept Popup Macro (Macros, Focus & Cursor): presses the popup on screen for you. It "
            .. "presses whichever popup is on top.",
        "Bag Space (QoL, Loot & Items): your cheapest items as a row of icons. Ctrl-click "
            .. "deletes, click sells, middle-click ignores. It also combines part stacks and "
            .. "warns about items a quest still needs.",
        "Mail & Alts (QoL, Loot & Items): what your alts carry on item tooltips, Alts and "
            .. "Attach buttons on the mailbox, and a warning for mail about to expire.",
        "Search box at the top of the sidebar: finds a setting and takes you to it. Thanks to "
            .. "Lyssa.",
        { badges = true, "Supporter Badges (QoL, Interface) for Naowh's Legendary patrons, the developers "
            .. "and the moderators." },
        "Themes (Settings, Colors): eight colour presets or your own colours for this window. "
            .. "Thanks to Lyssa.",
        "Discovery: track the 40 library books around Azeroth, with a zone tracker, world map "
            .. "pins and an alert when one is nearby.",
        "Professions: crafting profit from your auction house scan, Buy Materials and Search AH "
            .. "buttons, a recipe filter, Track Recipe and a gathering reminder.",
        "XP Bar: pick the text for each of five spots around the bar.",
        "Flight Timer (QoL, Flight & Camp): a new look, bigger, with a Scale slider and a Land "
            .. "Early button.",
        "Campfire: sharper artwork, and an Alert Under slider for Camp Nearby.",
        "Settings: features fold into dropdowns that open when you switch them on, with single "
            .. "switches above them. Crosshair melee range moved inside Crosshair.",
        "BiS List: several lists per class, quality borders, a rank button per slot, Fill Empty "
            .. "Slots and adding items by ID. Dungeon Quests: click a chain step for a waypoint.",
        "Combat Alert: new Combat and Safe voice clips, and no more stutter on the pull with "
            .. "Text to Speech.",
        "Co-Tank Frame: Righteous Fury counts as tanking, and debuffs show in combat.",
        "Class macros are character macros now, with a right-click icon picker. Key bindings "
            .. "have their own Naowh Forever section.",
        "Fixed: Death Release Protection outside instances, Smart Reminders with BigWigs and "
            .. "DBM, the Unknown name on login, Auto Repair without the Restock Reminder, Swing "
            .. "Timer set to Always, the empty trinket slot error and the cursor staying clipped "
            .. "after a crash, among others.",
        "New features are off until you turn them on.",
    } },
    { title = "Naowh Forever preview", lines = {
        "Smart Reminders is now Naowh Forever, and Smart Reminders is one of its modules. "
            .. "The addon folder is NaowhForever now: settings saved before the rename come "
            .. "back if you copy WTF\\...\\SavedVariables\\NaowhSmartReminders.lua to "
            .. "NaowhForever.lua with the game closed.",
        "New layout: Unlock Mode, Settings, Patch Notes and Profiles along the top, and the "
            .. "modules in the sidebar: Smart Reminders, QoL, Dungeon Quests, Gear Sets, BiS "
            .. "List, Macros and AuraBuffs.",
        "/nf opens this window, alongside /naowh, /nao, /nsr and /smartreminders.",
        "Window scale and the minimap button moved to Settings.",
        "Debuff sounds moved to AuraBuffs, under Poison & Dispel.",
        "Loot feed: every loot, quest turn-in and reputation gain pops up with its icon, amount "
            .. "and value, with an "
            .. "optional gold per hour counter. Set it up in QoL, Loot & Items; move it in Unlock Mode.",
        "Loot feed appearance: width, line height, spacing (no gaps by default), font and "
            .. "font size.",
        "XP per Hour in QoL, General: experience per hour, time to level, session time and "
            .. "XP per session on screen. Move it in Unlock Mode.",
        "Flight timer in QoL, Flight & Camp: where you are flying and how long is left, with a "
            .. "reminder quote from a streamer. Move it in Unlock Mode.",
        "Campfire reminder in AuraBuffs, Campfire: a round camp icon with a countdown while "
            .. "Camp Benefits is up, and a greyed-out Refresh Camp reminder with an optional "
            .. "sound when it runs out. Open world only. Move it in Unlock Mode.",
        "Low Health reminder in AuraBuffs, Low Health: your best healthstone or healing "
            .. "potion with a LOW HEALTH warning while you are under the threshold, in combat "
            .. "too, plus an optional sound each time you drop below it. Move it in Unlock Mode.",
        "Naowh Quiz: WoW trivia that opens on a flight or at a campfire, or any time with "
            .. "/naowh quiz.",
        "Global Font in Settings: one font for the whole game UI and this addon. The Naowh "
            .. "font ships with the addon and is the default; pick any other font, or Blizzard "
            .. "Default to leave the game's fonts alone.",
        "QoL, Macros and AuraBuffs settings can be set now; each feature switches on as "
            .. "it is built.",
    } },
}

local page = ns.Shared.Settings.Page("Patch Notes")

local function Line(text)
    local head, rest = text:match("^([^:]+):%s+(.+)$")
    if not head or #head > TITLE_MAX then return { text = text } end
    local title, where = head:match("^(.-)%s*%((.+)%)$")
    return { title = title or head, where = where, text = rest }
end

local function Lines(entry)
    local lines = {}
    for _, text in ipairs(entry.lines) do
        if type(text) == "table" then text = ns.FEATURE_BADGES == ns.BADGES_LIVE and text[1] or nil end
        if text then lines[#lines + 1] = Line(text) end
    end
    return lines
end

local latest

local function AddNotes(i, entry)
    local lines = Lines(entry)
    local coming = entry.title == UNRELEASED
    local summary = TEXT_CHANGES:format(#lines)
    if coming then
        summary = TEXT_IN_TESTING .. summary
    elseif not latest then
        latest = entry
        summary = TEXT_LATEST .. summary
    end
    page:Info({ id = entry.title, name = coming and TEXT_NEXT_RELEASE or entry.title, open = i == 1, lines = lines,
        summary = summary })
end

for i, entry in ipairs(NOTES) do AddNotes(i, entry) end
