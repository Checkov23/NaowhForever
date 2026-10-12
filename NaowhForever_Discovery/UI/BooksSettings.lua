-- BooksSettings.lua: Discovery's Library Books settings page (Discovery/Library Books), declared as cards.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local S = Discovery.Settings
local Library = Discovery.Library
local Settings = ns.Shared.Settings

local St = ns.Shared.Style

local PAGE = "Discovery/Library Books"
local SCALE = St.SCALE_RANGE
local PIN_SIZE = St.PIN_SIZE_RANGE
local RANGE = { 10, 100, 5 }
local OPACITY_RANGE = St.OPACITY_RANGE
local PERCENT_SCALE = St.PERCENT_SCALE
local ORDER_TRACKER, ORDER_NEARBY, ORDER_WAYPOINTS, ORDER_WINDOW = 10, 30, 35, 90
local TEXT_SECTION = ns.L("Library Books")
local TEXT_OFF = ns.L("Turn on Discovery")
local TEXT_PINS_OFF = ns.L("Turn on Library Books pins")
local TEXT_HANDED_IN = ns.L("%d of %d books handed in")
local TEXT_ALL_EARNED = ns.L("Every reward earned. %s thanks you.")
local TEXT_NEXT = ns.L("Next: %s at %d. Hand them to %s.")
local TEXT_EVERY_ZONE = ns.L("In every zone")
local TEXT_BOOK_ZONES = ns.L("In zones with books to find")
local TEXT_WITHIN = ns.L("Within %d yards")
local TEXT_OPENS_MAP = ns.L("Pins it and opens the map")
local TEXT_PIN_ONLY = ns.L("Pins it only")

local page = Settings.Page(PAGE, S)

local function On() return S.Get("enabled") == true end
local function PinsOn() return On() and S.Get("mapPins") == true end

local function Headline()
    return TEXT_HANDED_IN:format(Library.Progress())
end

local function Detail()
    local goal = Library.NextGoal()
    local librarian = Library.Librarian()
    if not goal then return TEXT_ALL_EARNED:format(librarian.name) end
    return TEXT_NEXT:format(goal.name, goal.books, librarian.name)
end

local function OpenBooks()
    ns.OpenDiscoveryWindow("books")
end

local function TrackerSummary(store)
    return store.Get("trackerAlways") and TEXT_EVERY_ZONE or TEXT_BOOK_ZONES
end

local function NearbySummary(store)
    return TEXT_WITHIN:format(store.Get("nearbyRange"))
end

local function WaypointSummary(store)
    return store.Get("openMap") and TEXT_OPENS_MAP or TEXT_PIN_ONLY
end

page:Window({
    text = "Open Library Books",
    open = OpenBooks,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "tracker", name = "Tracker", order = ORDER_TRACKER, switch = "tracker",
    help = "Pops up when you enter a zone with books you still need, with a waypoint for each and your "
        .. "progress toward the next reward, and stays while you are in that zone. The X closes it until "
        .. "you enter another. Move it in the HUD Editor.",
    summary = TrackerSummary,
    rows = {
        { key = "trackerAlways", label = "Always Show", toggle = true, needs = On, why = TEXT_OFF,
          help = "Keep the tracker up in every zone, with a dropdown of the zones where you still have books "
              .. "to find. Entering one selects it. The X on the tracker switches this off." },
        { key = "trackerScale", label = "Scale", slider = SCALE, unit = "%", scale = PERCENT_SCALE, needs = On,
          why = TEXT_OFF, help = "How big the tracker is." },
        { key = "trackerAlpha", label = "Opacity", slider = OPACITY_RANGE, unit = "%",
          scale = PERCENT_SCALE, needs = On, why = TEXT_OFF, help = "How solid the tracker is, in percent." },
    },
})

table.insert(ns.Shared.MapPins, {
    title = TEXT_SECTION, store = S, switch = "mapPins",
    rows = {
        { key = "mapPins", label = TEXT_SECTION, toggle = true, store = S, needs = On, why = TEXT_OFF,
          help = "Pins every book you still need on its zone's map, and your librarian while you carry books. "
              .. "Hover a pin for the exact spot; click it for a waypoint." },
        { key = "mapTurnIn", label = "Hand-In Pin", toggle = true, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF,
          help = "While you carry books, a pin on who takes them: your librarian, or the mage trainer." },
        { key = "mapPinSize", label = "Book Pin Size", slider = PIN_SIZE, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF, help = "How big the pins are on the map." },
    },
})

page:Card({
    id = "nearby", name = "Nearby Alert", order = ORDER_NEARBY, switch = "nearbySound",
    help = "Plays the map ping and names the book in chat when you come within range of one you still need. "
        .. "Once per book, until you walk away and come back.",
    summary = NearbySummary,
    rows = {
        { key = "nearbyRange", label = "Range", slider = RANGE, unit = " yd", needs = On,
          why = TEXT_OFF, help = "How close a book has to be before it pings." },
        { key = "nearbyPing", label = "Ping Sound", toggle = true, needs = On, why = TEXT_OFF,
          help = "Plays the map ping when a book is near." },
        { key = "nearbyChat", label = "Chat Line", toggle = true, needs = On, why = TEXT_OFF,
          help = "Names the book in chat, with how far it is and where." },
    },
})

page:Card({
    id = "waypoints", name = "Waypoints", order = ORDER_WAYPOINTS,
    help = "What a waypoint from the Discovery window or the tracker does.",
    search = "sleeping bag steps",
    summary = WaypointSummary,
    rows = {
        { key = "openMap", label = "Open the Map", toggle = true,
          help = "Also opens the world map on the waypoint, so you see where it is. Out of combat only." },
    },
})

page:Card({
    id = "window", name = "Window", order = ORDER_WINDOW,
    help = "Discovery's own window, with every book and where to find it.",
    rows = {
        { key = "windowAlpha", label = "Window Opacity", slider = OPACITY_RANGE,
          unit = "%", scale = PERCENT_SCALE, help = "How solid the window is, in percent. Also on its title bar." },
    },
})
