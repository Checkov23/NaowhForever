-- QuestsSettings.lua: the Quest List's quest cards (Discovery/Quest List), and its quest pins' rows on QoL > Map & Pins.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Settings = ns.Shared.Settings

local PAGE = "Discovery/Quest List"
local PIN_SIZE = ns.Shared.Style.PIN_SIZE_RANGE
local ORDER_QUESTS = 10
local TEXT_OFF = ns.L("Turn on Discovery")
local TEXT_PINS_OFF = ns.L("Turn on Quest Givers")
local TEXT_PROGRESS = ns.L("%d of %d zone quests done")
local TEXT_ZONE = ns.L("%s: %d of %d.")
local TEXT_EVERY_QUEST = ns.L("Every quest of every zone, and where you are in each chain.")

local page = Settings.Page(PAGE, S)

local function On() return S.Get("enabled") == true end
local function PinsOn() return On() and S.Get("mapPins") == true end

local function Headline()
    Q.Refresh()
    return TEXT_PROGRESS:format(Q.Progress())
end

local function Detail()
    local zone = Q.CurrentZone()
    if not zone then return TEXT_EVERY_QUEST end
    local n, total = Q.ZoneProgress(zone)
    return TEXT_ZONE:format(zone.name, n, total)
end

local function OpenQuests()
    ns.OpenCompletoWindow("quests")
end

page:Window({
    text = "Open Quest List",
    open = OpenQuests,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "quests", name = "Quests", order = ORDER_QUESTS,
    help = "What a zone's page in the Quest List window lists.",
    rows = {
        { key = "hideDone", label = "Hide Done", toggle = true,
          help = "Leave out the quests and chains you have finished." },
    },
})

table.insert(ns.Shared.MapPins, {
    title = ns.L("Quests"), store = S, switch = "mapPins",
    rows = {
        { key = "mapPins", label = "Quest Givers", toggle = true, store = S, always = true, needs = On, why = TEXT_OFF,
          help = "A yellow ! on the world map at every quest giver with a quest you can pick up that still gives "
              .. "experience. Hover it for the quests; click it for a waypoint." },
        { key = "mapGrey", label = "Low Level Quests", toggle = true, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF,
          help = "Also a grey ! for quests you can still pick up that no longer give experience." },
        { key = "mapChainsOnly", label = "Chains Only", toggle = true, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF,
          help = "Only quest chains: the first quest of each one, and the next step of those you are on." },
        { key = "mapPinSize", label = "Quest Pin Size", slider = PIN_SIZE, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF, help = "How big the quest pins are on the map." },
    },
})
