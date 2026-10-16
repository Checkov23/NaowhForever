-- SettingsPage.lua: Zone Info's Map & Pins card and current-zone preview.
local ns = _G.NaowhForever
local Z = ns.ZoneInfo
local S = ns.QoLSettings
local Settings = ns.Shared.Settings
local PAGE, ORDER, PREVIEW_H, SAMPLE_MAP = "QoL/Map & Pins", 14, 150, 1436
local STATES = { { key = "current", label = "Current Zone" } }
local SCALE_RANGE = { 0.6, 1.6, 0.05 }
local TEXT_OFF, TEXT_ON = ns.L("Off"), ns.L("Map summary and pinned zone details")
local RECOMMENDED = { "zoneInfoDungeons", "zoneInfoFishing", "zoneInfoTravel", "zoneInfoOnlyProfessions", "zoneInfoHideCombat" }

local function Recommended()
    for _, key in ipairs(RECOMMENDED) do S.Set(key, true) end
    S.Set("zoneInfoOnMap", false)
    S.Set("zoneInfo", true)
end

local function MapOnly()
    for _, key in ipairs(RECOMMENDED) do S.Set(key, true) end
    S.Set("zoneInfoCurrent", false)
    S.Set("zoneInfoGathering", true)
    S.Set("zoneInfoOnlyProfessions", false)
    S.Set("zoneInfoPinned", 0)
    S.Set("zoneInfoOnMap", true)
    S.Set("zoneInfo", true)
end

local function Preview(stage)
    local frame = Z.NewHUD(stage, true)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata(stage:GetFrameStrata())
    return frame
end

local function PaintPreview(frame)
    Z.PaintHUD(frame, SAMPLE_MAP, true)
end

local function CurrentDetails()
    if Z.current then Z.Pin(Z.current, not WorldMapFrame or not WorldMapFrame:IsShown()) end
end

local function Summary(store)
    return store.Get("zoneInfo") and TEXT_ON or TEXT_OFF
end

Settings.Page(PAGE, S):Card({
    id = "zoneInfo", name = "Zone Info", order = ORDER, switch = "zoneInfo", summary = Summary,
    help = "Shows zone summaries, pinned details and an optional current-zone panel.",
    studio = { height = PREVIEW_H, states = STATES, new = Preview, paint = PaintPreview },
    rows = {
        { label = "Recommended Details", buttonText = "Apply", button = Recommended, always = true,
          help = "Shows dungeon, fishing and travel details with your profession filters." },
        { label = "Map Text Only", buttonText = "Apply", button = MapOnly, always = true,
          help = "Shows the zone summary on the map and turns off the panels." },
        Settings.Group("Display"),
        { key = "zoneInfoOnMap", label = "On-map Summary", toggle = true,
          help = "Draws zone information on the map instead of showing side panels." },
        { key = "zoneInfoCurrent", label = "Current-Zone Panel", toggle = true,
          help = "Shows a compact panel for the zone you are in." },
        { key = "zoneInfoHideCombat", label = "Hide Panel in Combat", toggle = true, needs = "zoneInfoCurrent",
          help = "Hides the current-zone panel during combat." },
        { label = "Current Zone Details", buttonText = "Open Details", button = CurrentDetails,
          help = "Opens the details for your current zone." },
        Settings.Group("Content"),
        { key = "zoneInfoDungeons", label = "Dungeons & Raids", toggle = true,
          help = "Lists dungeon entrances with Journal and waypoint shortcuts." },
        { key = "zoneInfoFishing", label = "Fishing Details", toggle = true,
          help = "Shows the zone's fishing requirements and your skill." },
        { key = "zoneInfoTravel", label = "Travel Connections", toggle = true,
          help = "Lists flight masters, transport stops and roads to neighboring zones." },
        { key = "zoneInfoGathering", label = "Herbs & Mining", toggle = true,
          help = "Adds a gathering tab with requirements and known locations." },
        { key = "zoneInfoOnlyProfessions", label = "Only My Professions", toggle = true, needs = "zoneInfoGathering",
          help = "Lists only nodes for gathering professions you have learned." },
        Settings.Group("Appearance"),
        { key = "zoneInfoScale", label = "Panel Scale", slider = SCALE_RANGE, unit = "x", needs = "zoneInfoCurrent" },
    },
})
