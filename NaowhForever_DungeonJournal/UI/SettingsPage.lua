-- SettingsPage.lua: the Dungeon Journal's settings page, declared as cards, and its entrance pins' rows on Map Options and Pins.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Loot = J.Loot
local Quests = J.Quests
local Settings = ns.Shared and ns.Shared.Settings

local OPACITY_RANGE, SCALE_RANGE = J.Style.OPACITY_RANGE, J.Style.SCALE_RANGE
local ICON_MIN, ICON_MAX, ICON_STEP = 50, 200, 10
local TO_FRACTION = J.Style.PERCENT_SCALE
local PERCENT = J.C.PERCENT
local ROUND_HALF = J.C.ROUND_HALF
local ORDER_FIRST, ORDER_THIRD, ORDER_FOURTH, ORDER_LAST = 10, 20, 30, 90

local TEXT_JOURNAL_OFF = ns.L("Turn on the Dungeon Journal")
local TEXT_BIS_OFF = ns.L("Needs the BiS List")
local TEXT_ENTRANCES_OFF = ns.L("Turn on Dungeon and Raid Entrances")
local TEXT_EVERY_DUNGEON = ns.L("Every dungeon and raid: what drops, your quests, and more.")
local TEXT_YOU_ARE_IN = ns.L("You are in %s.")
local TEXT_FOR_YOUR_LEVEL = ns.L("%s is for your level (%s).")
local TEXT_TO_PICK_UP = ns.L("%d to pick up")
local TEXT_IN_LOG = ns.L("%d in your log")
local TEXT_YOUR_QUESTS = ns.L("Your quests there: %s.")
local TEXT_LIST = ", "
local TEXT_ONE_FILTER = ns.L(", 1 filter on")
local TEXT_FILTERS = ns.L(", %d filters on")
local TEXT_OPACITY = ns.L("%d%% opacity")
local TEXT_OFF = ns.L("Off")
local FACTION_VALUES = { both = "Both Factions", Alliance = "Alliance Ground", Horde = "Horde Ground" }
local FACTION_ORDER = { "both", "Alliance", "Horde" }
local MAP_SUMMARY = { both = ns.L("Dungeons and zones"), panel = ns.L("In dungeons"), factions = ns.L("In zones"), none = ns.L("Nothing beside the map") }
local SHARE_SUMMARY = { both = ns.L("Asks and accepts shared quests"), ask = ns.L("Asks for shared quests"),
    accept = ns.L("Accepts shared quests") }
local TRACKER_EVERYWHERE, TRACKER_INSIDE, TRACKER_OUTSIDE = ns.L("everywhere"), ns.L("in dungeons"), ns.L("outside dungeons")
local TEXT_TRACKER, TEXT_AND_TRACKER = ns.L("Tracker "), ns.L(", tracker ")

local function ForYou()
    local here = J.Current()
    if here then return here[1], true end
    local level = UnitLevel("player")
    for _, dungeon in ipairs(J.Dungeons()) do
        local levels = not dungeon.raid and J.Levels(dungeon)
        if levels and level >= levels[1] and level <= levels[2] then return dungeon, false end
    end
end

local function Headline()
    local dungeon, inside = ForYou()
    if not dungeon then return TEXT_EVERY_DUNGEON end
    local name = ns.Color("accentSoft", dungeon.name)
    if inside then return TEXT_YOU_ARE_IN:format(name) end
    return TEXT_FOR_YOUR_LEVEL:format(name, J.LevelRange(dungeon))
end

local function Detail()
    local dungeon = ForYou()
    if not (dungeon and dungeon.quests) then return end
    local toPickUp, inLog = Quests.Count(dungeon.quests)
    if toPickUp + inLog == 0 then return end
    local parts = {}
    if toPickUp > 0 then parts[#parts + 1] = TEXT_TO_PICK_UP:format(toPickUp) end
    if inLog > 0 then parts[#parts + 1] = TEXT_IN_LOG:format(inLog) end
    return TEXT_YOUR_QUESTS:format(table.concat(parts, TEXT_LIST))
end

local function JournalOn()
    return S.Get("enabled") == true
end

local function EntrancesOn()
    return JournalOn() and S.Get("mapEntrances") == true
end

local function BisOn()
    return Loot.BisOn()
end

local function FactionGet()
    local alliance, horde = S.Get("showAlliance"), S.Get("showHorde")
    if alliance and horde then return "both" end
    return alliance and "Alliance" or "Horde"
end

local function FactionSet(value)
    if value == "Horde" then
        S.Set("showHorde", true)
        S.Set("showAlliance", false)
        return
    end
    S.Set("showAlliance", true)
    S.Set("showHorde", value ~= "Alliance")
end

local function OptionRow(option)
    local row = { key = option.key, label = option.label, toggle = true, help = option.tooltip }
    if option.needsBis then
        row.needs, row.why, row.help = BisOn, TEXT_BIS_OFF, option.tooltip .. " " .. J.NEEDS_BIS
    end
    return row
end

local function ListRows()
    local rows = {}
    for _, option in ipairs(J.OPTION_GROUPS[1].options) do rows[#rows + 1] = OptionRow(option) end
    rows[#rows + 1] = { label = "Dungeons Listed", choice = { FACTION_VALUES, FACTION_ORDER },
        get = FactionGet, set = FactionSet,
        help = "The dungeons on whose ground the list shows. Contested ones and the raids are always listed. "
            .. "Also the switch beside the Journal's search." }
    return rows
end

local function ListSummary(store)
    local hiding = 0
    for _, option in ipairs(J.OPTION_GROUPS[1].options) do
        if option.hides ~= nil and store.Get(option.key) == option.hides then hiding = hiding + 1 end
    end
    return ns.L(FACTION_VALUES[FactionGet()]) .. (hiding == 1 and TEXT_ONE_FILTER or TEXT_FILTERS:format(hiding))
end

local function MapSummary(store)
    local panel, factions = store.Get("mapPanel"), store.Get("mapFactions")
    if panel and factions then return MAP_SUMMARY.both end
    if panel then return MAP_SUMMARY.panel end
    if factions then return MAP_SUMMARY.factions end
    return MAP_SUMMARY.none
end

local function ShareSummary(store)
    local ask, accept = store.Get("shareRequests"), store.Get("acceptShared")
    if ask and accept then return SHARE_SUMMARY.both end
    if ask then return SHARE_SUMMARY.ask end
    if accept then return SHARE_SUMMARY.accept end
    return TEXT_OFF
end

local function TrackerWhere(store)
    local outside = store.Get("trackerOutside")
    if store.Get("trackerAuto") then return outside and TRACKER_EVERYWHERE or TRACKER_INSIDE end
    return outside and TRACKER_OUTSIDE
end

local function QuestsSummary(store)
    local text = ShareSummary(store)
    local where = TrackerWhere(store)
    if not where then return text end
    return text == TEXT_OFF and TEXT_TRACKER .. where or text .. TEXT_AND_TRACKER .. where
end

local function OpacitySummary(key)
    return function(store)
        return TEXT_OPACITY:format(math.floor((store.Get(key) or 1) * PERCENT + ROUND_HALF))
    end
end

local function OpenJournal()
    ns.OpenJournalWindow()
end

local function OpenTracker()
    J.TurnOn()
    J.QuestTracker.Show(ForYou() or J.Dungeons()[1])
end

local function OnSettingChanged(key)
    if key == "enabled" then ns.UI:RefreshPage(true) end
end

local function OpacityRow(key, help)
    return { key = key, label = "Window Opacity", slider = OPACITY_RANGE, unit = "%",
        scale = TO_FRACTION, help = help }
end

local function Toggle(key, label, help, search)
    return { key = key, label = label, toggle = true, needs = JournalOn, why = TEXT_JOURNAL_OFF, help = help,
        search = search }
end

local function DeclareJournal()
    local page = Settings.Page("Dungeon Journal/Journal", S)
    page:Window({ text = "Open Dungeon Journal", open = OpenJournal, headline = Headline, detail = Detail })
    page:Card({
        id = "lists", name = "What It Lists", order = ORDER_FIRST,
        help = "What the Journal lists on a boss. The same switches as the Filters icon on its title bar.",
        summary = ListSummary,
        rows = ListRows(),
    })
    page:Card({
        id = "window", name = "Window", order = ORDER_LAST,
        help = "The Journal's own window.",
        search = "up down arrow keys ctrl+f ctrl f search recent reset kills loot",
        summary = OpacitySummary("windowAlpha"),
        rows = { OpacityRow("windowAlpha", "How solid the Journal's window and its side panels are.") },
    })
    page:Card({
        id = "keys", name = "Key Binding", order = ORDER_FOURTH,
        help = "The key that opens the Journal.",
        rows = {
            { label = "Open Dungeon Journal", binding = "NAOWHFOREVER_JOURNAL",
              help = "Press it to open or close the Dungeon Journal." },
        },
    })
end

local function DeclareTracker()
    local tracker = Settings.Page("Dungeon Journal/Quest Tracker", S)
    tracker:Window({ text = "Open Quest Tracker", open = OpenTracker, headline = Headline, detail = Detail })
    tracker:Card({
        id = "quests", name = "Quests", order = ORDER_FIRST,
        help = "The quest tracker, and sharing dungeon quests with your group.",
        summary = QuestsSummary,
        rows = {
            Toggle("trackerAuto", "Open Tracker in Dungeons",
                "Opens the quest tracker when you enter a dungeon with quests for you."),
            Toggle("trackerOutside", "Show Outside Dungeons",
                "Opens the quest tracker out in the world, on the dungeon your quests are for."),
            Toggle("hideGameTracker", "Hide the Game's Quest Tracker",
                "Fades out the game's quest tracker while this one is open in a dungeon."),
            Toggle("shareRequests", "Quest Share Requests",
                "Ask your group to share a dungeon quest you don't have, from its group icon."),
            Toggle("acceptShared", "Accept Shared Dungeon Quests",
                "Accepts dungeon quests your group shares with you straight away.",
                "hold skip modifier qol accept quests"),
        },
    })
    tracker:Card({
        id = "trackerwindow", name = "Window", order = ORDER_LAST,
        help = "The Dungeon Quest Tracker's window.",
        summary = OpacitySummary("trackerAlpha"),
        rows = {
            OpacityRow("trackerAlpha", "How solid the Dungeon Quest Tracker is."),
            { key = "trackerScale", label = "Window Scale", slider = SCALE_RANGE, unit = "%",
              scale = TO_FRACTION, help = "How big the Dungeon Quest Tracker is." },
        },
    })
end

local function DeclareMap()
    local map = Settings.Page("Dungeon Journal/Map", S)
    map:Card({
        id = "map", name = "Beside the World Map", order = ORDER_FIRST,
        help = "The Journal beside the world map: bosses and loot in dungeons, factions outside.",
        summary = MapSummary,
        rows = {
            Toggle("mapPanel", "Bosses and Loot in Dungeons",
                "Shows a dungeon's bosses and loot beside the world map while you are inside.",
                "dungeon map on the world map quest log fold"),
            Toggle("mapFactions", "Factions Beside the Map",
                "Shows the factions earned where you are beside the world map."),
        },
    })
    map:Card({
        id = "mapwindow", name = "Window", order = ORDER_LAST,
        help = "The map's window, the Journal beside the world map and Boss Loot at Cursor.",
        search = "dungeon page map link pin fold map and bosses only",
        summary = OpacitySummary("mapAlpha"),
        rows = { OpacityRow("mapAlpha",
            "How solid the map's window, the Journal beside the map and Boss Loot at Cursor are.") },
    })
    map:Card({
        id = "lootkey", name = "Boss Loot at Cursor", order = ORDER_THIRD,
        help = "A key that shows a boss's loot at your cursor.",
        rows = {
            { label = "Boss Loot at Cursor", binding = "NAOWHFOREVER_BOSSLOOT",
              help = "Press it over a boss, or with one targeted, to see what it drops." },
        },
    })
end

local function DeclareMapPins()
    local entrances = Toggle("mapEntrances", "Dungeon and Raid Entrances", "A door on each dungeon and raid "
        .. "entrance on the world map, for the sides the Journal lists. Hover it for the levels, click it for a "
        .. "waypoint.")
    entrances.store, entrances.always = S, true
    table.insert(ns.Shared.MapPins, {
        title = ns.L("Dungeons & Raids"), store = S, switch = "mapEntrances",
        rows = {
            entrances,
            { key = "mapEntranceScale", label = "Entrance Icon Size", slider = { ICON_MIN, ICON_MAX, ICON_STEP },
              unit = "%", scale = TO_FRACTION, store = S, always = true, needs = EntrancesOn,
              why = TEXT_ENTRANCES_OFF, help = "How big the entrance icons are. They are largest on a zone's map, "
                  .. "smaller on a continent's and the world's." },
        },
    })
end

S.OnChange(OnSettingChanged)
if Settings then
    DeclareJournal()
    DeclareTracker()
    DeclareMap()
    DeclareMapPins()
end
