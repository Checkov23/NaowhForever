-- SettingsPage.lua: the Journeys settings page, declared as cards.
local ns = _G.NaowhForever

local Jy = ns.Journeys
local S = Jy.Settings
local Settings = ns.Shared.Settings
local Style = ns.Shared.Style

local MINUTE = 60
local ORDER_ROUTES, ORDER_CARD = 10, 20
local SAVING_RANGE = { 0, 10, 1 }
local SCALE_RANGE = { 0.5, 2, 0.05 }
local OPACITY_RANGE, PERCENT_SCALE = Style.ALPHA_RANGE, Style.PERCENT_SCALE
local TEXT_OFF = ns.L("Turn on Journeys")
local TEXT_MINUTES = " min"
local TEXT_HEADLINE = ns.L("Following: %s")
local TEXT_IDLE = ns.L("No journey yet")
local TEXT_DETAIL = ns.L("Every waypoint button in Naowh Forever plans a journey: walking, flights, boats, "
    .. "zeppelins, the tram, portals and your Hearthstone.")
local TEXT_ROUTES = ns.L("Hearthstone %s, teleports %s")
local TEXT_ON, TEXT_OFF_WORD = ns.L("on"), ns.L("off")
local TEXT_CARD = ns.L("%d%% opacity")
local TEXT_CARD_OFF = ns.L("Hidden")

local function Headline()
    local journey = Jy.Guide.Current()
    return journey and TEXT_HEADLINE:format(journey.title) or TEXT_IDLE
end

local function Detail()
    return TEXT_DETAIL
end

local function Word(on)
    return on and TEXT_ON or TEXT_OFF_WORD
end

local function RoutesSummary(store)
    return TEXT_ROUTES:format(Word(store.Get("hearth")), Word(store.Get("teleports")))
end

local function CardSummary(store)
    if not store.Get("card") then return TEXT_CARD_OFF end
    return TEXT_CARD:format(store.Get("cardAlpha") / PERCENT_SCALE)
end

local function Needs(key)
    return function() return Jy.On() and S.Get(key) and true or false end
end

local page = Settings.Page("Journeys/Settings", S)

page:Window({
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "routes", name = "Routes", order = ORDER_ROUTES,
    help = "What a journey may use besides walking, flights and ships.",
    search = "hearthstone teleport mage druid moonglade portal tram boat zeppelin",
    summary = RoutesSummary,
    rows = {
        { key = "hearth", label = "Use the Hearthstone", toggle = true, needs = Jy.On, why = TEXT_OFF,
          help = "Start with your Hearthstone when it is ready and gets you there sooner." },
        { key = "hearthSaving", label = "Hearthstone Must Save", slider = SAVING_RANGE, unit = TEXT_MINUTES,
          scale = MINUTE, needs = Needs("hearth"), why = "Needs Use the Hearthstone",
          help = "Keep your Hearthstone unless it saves at least this long." },
        { key = "teleports", label = "Use Class Teleports", toggle = true, needs = Jy.On, why = TEXT_OFF,
          help = "Start with a mage or druid teleport you know." },
        { key = "quests", label = "Journeys to Tracked Quests", toggle = true, needs = Jy.On, why = TEXT_OFF,
          help = "Track a quest that is far away and Journeys plans the way there." },
        { key = "mapPins", label = "Journeys to Map Pins", toggle = true, needs = Jy.On, why = TEXT_OFF,
          help = "Put a pin on the map yourself and Journeys plans the way there." },
        { key = "learnLifts", label = "Learn Lifts as You Ride", toggle = true, needs = Jy.On, why = TEXT_OFF,
          help = "Notes the lifts you ride so they can be added to Journeys; /nf lifts lists them." },
        { key = "minimapRoute", label = "Route on the Minimap", toggle = true, needs = Jy.On, why = TEXT_OFF,
          help = "Draw the journey on the minimap: the walk you are on, then the legs after it." },
        { key = "mapRoute", label = "Route on the World Map", toggle = true, needs = Jy.On, why = TEXT_OFF,
          help = "Draw the journey on the world map: the walk you are on, then each leg after it." },
    },
})

page:Card({
    id = "card", name = "Journey Card", order = ORDER_CARD, switch = "card",
    help = "Every step of the journey you are on, with the time each takes.",
    summary = CardSummary,
    rows = {
        { key = "cardScale", label = "Scale", slider = SCALE_RANGE, needs = Needs("card"), why = "Needs Journey Card" },
        { key = "cardAlpha", label = "Opacity", slider = OPACITY_RANGE, unit = "%", scale = PERCENT_SCALE,
          needs = Needs("card"), why = "Needs Journey Card" },
    },
})
