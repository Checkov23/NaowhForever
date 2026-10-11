-- BagSettings.lua: Discovery's Sleeping Bag settings page (Discovery/Sleeping Bag), declared as cards.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local S = Discovery.Settings
local Library = Discovery.Library
local Bag = Discovery.Bag
local Settings = ns.Shared.Settings

local St = ns.Shared.Style

local SCALE = St.SCALE_RANGE
local PIN_SIZE = St.PIN_SIZE_RANGE
local OPACITY_RANGE = St.OPACITY_RANGE
local PERCENT_SCALE = St.PERCENT_SCALE
local ORDER_TRACKER, ORDER_MAP_PINS = 10, 20
local TEXT_OFF = ns.L("Turn on Discovery")
local TEXT_HAVE_BAG = ns.L("You have the Cozy Sleeping Bag")
local TEXT_STEP_OF = ns.L("Step %d of %d")
local TEXT_HEADLINE = ns.L("Sleeping Bag: step %d of %d")
local TEXT_REST = ns.L("Rest in it for a bonus to experience.")
local TEXT_STARTS = ns.L("It starts at level %d.")
local TEXT_NEXT = ns.L("Next: %s, %s.")

local function On() return S.Get("enabled") == true end

local function BagSummary()
    local _, at = Bag.Current()
    if not at then return TEXT_HAVE_BAG end
    return TEXT_STEP_OF:format(at, #Bag.Steps())
end

local function BagHeadline()
    local _, at = Bag.Current()
    if not at then return TEXT_HAVE_BAG end
    return TEXT_HEADLINE:format(at, #Bag.Steps())
end

local function BagDetail()
    local step = Bag.Current()
    if not step then return TEXT_REST end
    if not Bag.Level() then return TEXT_STARTS:format(ns.SleepingBag.level) end
    return TEXT_NEXT:format(step.object, Library.ZoneName(step.map))
end

local function OpenBag()
    ns.OpenDiscoveryWindow("bag")
end

local bags = Settings.Page("Discovery/Sleeping Bag", S)

bags:Window({
    text = "Open Sleeping Bag",
    open = OpenBag,
    headline = BagHeadline,
    detail = BagDetail,
})

bags:Card({
    id = "bagtracker", name = "Tracker", order = ORDER_TRACKER, switch = "bagTracker",
    help = "Shows each Sleeping Bag step, with how to reach the next one and a waypoint.",
    search = "x close turn off",
    summary = BagSummary,
    rows = {
        { key = "bagTrackerScale", label = "Scale", slider = SCALE, unit = "%", scale = PERCENT_SCALE, needs = On,
          why = TEXT_OFF, help = "How big the tracker is." },
        { key = "bagTrackerAlpha", label = "Opacity", slider = OPACITY_RANGE, unit = "%",
          scale = PERCENT_SCALE, needs = On, why = TEXT_OFF, help = "How solid the tracker is, in percent." },
    },
})

bags:Card({
    id = "bagmappins", name = "Map Pins", order = ORDER_MAP_PINS, switch = "bagMapPins",
    help = "Shows the Sleeping Bag steps still to do on your map; click one for a waypoint.",
    rows = {
        { key = "bagMapPinSize", label = "Pin Size", slider = PIN_SIZE, needs = On, why = TEXT_OFF,
          help = "How big the pins are on the map." },
    },
})
