-- Run with Lua 5.1 from the repository root: the Town Pins drawer on the world map, and the Map & Pins tab.
-- The panel holds the town pins only, drawn from TownMap's list; their switches are not on the tab.
-- QoL's Map & Pins tab has the rest: a Map Options card and a Map Pins card with Town Pin Size and
-- each module's rows (ns.Shared.MapPins, in order, under their titles). The button shows whenever
-- QoL is on.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local panelSrc = Read("NaowhForever_QoL/Interface/MapPinsPanel.lua")
local townSrc = Read("NaowhForever_QoL/Interface/TownMap.lua")
for _, key in ipairs({ "townCapitalsOnly", "townMinimap", "townMinimapSpirit", "townSpiritHealers", "townZoneLinks", "townTravel",
    "townClass", "townProfession", "townFlight", "townInn", "townBank", "townRepair", "townSupplies",
    "townStable", "townVendors", "townMail" }) do
    Check(townSrc:find('key = "' .. key .. '"', 1, true), "in the pin list: " .. key)
    Check(not panelSrc:find('key = "' .. key .. '"', 1, true), "not copied into the panel: " .. key)
end
Check(panelSrc:find("local ROWS = ns.TownPinRows", 1, true), "the panel reads the town map's list")
Check(townSrc:find('key = "townPinSize"', 1, true), "the card keeps Pin Size")
local pinRows = setfenv(assert(loadstring("return " .. townSrc:match("local PIN_ROWS = (%b{})"))),
    setmetatable({ ns = { L = dofile("Tools/regression/locale_stub.lua").L } }, { __index = _G }))()
Check(townSrc:find('key = "townStable", text = ns.L("Stable Masters"), tip = ns.L("Hunters only."), class = STABLE_CLASS', 1, true),
    "Stable Masters is a hunter's row")
for _, row in ipairs(pinRows) do
    if row.key == "townStable" then row.class = "HUNTER" end
end

local function RealShared()
    local holder = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
    local chunk = assert(loadstring(Read("Shared/Shared.lua")))
    setfenv(chunk, setmetatable({ _G = { NaowhForever = holder } }, { __index = _G }))
    chunk()
    return holder.Shared
end

local questStore = { values = { enabled = true, mapPins = false }, listeners = {} }
function questStore.Get(key) return questStore.values[key] end
function questStore.Set(key, v)
    questStore.values[key] = v
    for _, fn in ipairs(questStore.listeners) do fn(key, v) end
end
function questStore.OnChange(fn) questStore.listeners[#questStore.listeners + 1] = fn end
local function QuestsOn() return questStore.values.enabled end
local function QuestPinsOn() return questStore.values.enabled and questStore.values.mapPins end
local questSection = { title = "Quests", store = questStore, switch = "mapPins", rows = {
    { key = "mapPins", label = "Quest Givers", toggle = true, store = questStore, always = true, needs = QuestsOn },
    { key = "mapGrey", label = "Low Level Quests", toggle = true, store = questStore, always = true,
      needs = QuestPinsOn },
    { key = "mapChainsOnly", label = "Chains Only", toggle = true, store = questStore, needs = "mapPins" },
    { key = "mapRepeat", label = "Repeatable", toggle = true, store = questStore, needs = { "enabled", "mapPins" } },
    { key = "mapPinSize", label = "Quest Pin Size", slider = { 12, 32, 1 }, store = questStore, always = true },
} }

local pinTexts
do
    local cards = {}
    local function Group(title) return { group = title } end
    local own = {}
    local ownSection = { map = true, title = "Map", order = 11, store = own, switch = "mapUnexplored", rows = {
        { key = "mapUnexplored", label = "Unexplored Areas", toggle = true, store = own },
        { key = "mapUnexploredDark", label = "Unexplored Darkness", slider = { 0, 100, 5 }, store = own,
          needs = "mapUnexplored" },
    } }
    local shared = RealShared()
    local hiddenSection = { title = "Skyborne", store = own, switch = "mapSkyborne", hidden = function() return true end,
        rows = { { key = "mapSkyborne", label = "Skyborne Spots", toggle = true, store = own } } }
    shared.MapPins = { questSection, ownSection, hiddenSection }
    shared.Style = dofile("Tools/regression/shared_style.lua")
    shared.Settings = { Group = Group, Page = function(key)
        return { Card = function(_, c) c.pageKey = key; cards[c.id] = c end }
    end }
    local cardNs = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLConstants = dofile("Tools/regression/qol_constants.lua"), QoLSettings = own,
        Apply = function() end, ThemeTint = function() end, TownCapitals = {}, TownNPCs = {}, Shared = shared }
    local cardEnv = setmetatable({ _G = { NaowhForever = cardNs },
        CreateFromMixins = function() return {} end, MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
        hooksecurefunc = function() end,
        CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end,
    }, { __index = _G })
    local chunk = assert(loadstring(townSrc))
    setfenv(chunk, cardEnv)
    chunk()
    local card, mapCard = cards.townMap, cards.mapOptions
    Check(card and mapCard and card.pageKey == "QoL/Map & Pins" and mapCard.pageKey == "QoL/Map & Pins",
        "two cards on QoL's Map & Pins tab: Map Options and Map Pins")
    Check(mapCard.order < card.order and not card.switch and not mapCard.switch,
        "map options first, and neither has a switch of its own")
    local rows = card.rows()
    for _, row in ipairs(rows) do
        Check(not (row.key and row.key:find("^town") and row.toggle),
            "no town switch on the card, they are on the map: " .. tostring(row.key))
    end
    Check(rows[1].group == "Town" and rows[2].key == "townPinSize" and rows[2].needs == "townMap" and rows[2].why,
        "Town Pin Size under Town, waiting for Town Pins with its reason")
    Check(rows[3].group == "Quests" and rows[4] == questSection.rows[1] and rows[8] == questSection.rows[5]
        and #rows == 8, "a module's rows under its title, its switches with them, and a hidden one left out")
    Check(rows[4].lent and not rows[2].lent, "lent to the card: its Reset and changed count leave them alone")
    local mapRows = mapCard.rows()
    Check(#mapRows == 2 and mapRows[1] == ownSection.rows[1] and mapRows[2] == ownSection.rows[2],
        "Map Options: the map sections' rows, switch and all, without their title")
    Check(not mapRows[1].lent, "QoL's own rows are the card's own store's: Reset takes them")
    pinTexts = cardNs.TownPinTexts
    Check(pinTexts.group and pinTexts.switch and pinTexts.tip, "the drawer's town texts are named, not positional")
    Check(cardNs.TownPinRows ~= nil, "the list is shared with the panel")
    local Search = dofile("Tools/regression/settings_search.lua")({ ["QoL/Map & Pins"] = { card, mapCard } })
    local hit = Search("flight master")[1]
    Check(hit and hit.card == "QoL/Map & Pins:townMap", "the options search still leads a pin's name to the card")
    hit = Search("graveyard")[1]
    Check(hit and hit.card == "QoL/Map & Pins:townMap", "and its search words")
    hit = Search("quest pin size")[1]
    Check(hit and hit.label == "Quest Pin Size" and hit.card == "QoL/Map & Pins:townMap", "a module's size on it")
    hit = Search("unexplored darkness")[1]
    Check(hit and hit.label == "Unexplored Darkness" and hit.card == "QoL/Map & Pins:mapOptions",
        "and a map option on the other card")
end
-- A card's Reset and changed count skip rows lent to it from another module's store.
do
    local function Store(values)
        local defaults = {}
        for k, v in pairs(values) do defaults[k] = v end
        local s = {}
        function s.Get(k) return values[k] end
        function s.Set(k, v) values[k] = v end
        function s.Raw(k) return values[k] end
        function s.Default(k) return defaults[k] end
        return s, values
    end
    local own, ownValues = Store({ townFlight = true })
    local other, otherValues = Store({ mapPins = false })
    local sns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, THEME = {}, Shared = { Style = dofile("Tools/regression/shared_style.lua") }, UI = {} }
    local senv = setmetatable({ _G = { NaowhForever = sns } }, { __index = _G })
    local chunk = assert(loadfile("Shared/Settings/Settings.lua"))
    setfenv(chunk, senv)
    chunk()
    local Settings = sns.Shared.Settings
    local card = Settings.Page("Test/Reset", own):Card({ id = "pins", name = "Map Pins", rows = {
        { key = "townFlight", label = "Flight Masters", toggle = true },
        { key = "mapPins", label = "Quest Givers", toggle = true, store = other, lent = true },
    } })
    ownValues.townFlight, otherValues.mapPins = false, true
    Check(Settings.ChangedCount(card) == 1, "the changed count leaves a lent row out")
    Settings.Reset(card)
    Check(ownValues.townFlight == true and otherValues.mapPins == true, "Reset puts back the card's own rows only")
end
Check(Read("NaowhForever_QoL/Interface/TownMap.xml"):find('<Script file="MapPinsPanel.lua"/>', 1, true),
    "the panel loads")

local settings = { enabled = true, townMap = false }
local canvasHeight = 600
local S = { Get = function(key) return settings[key] end, Set = function(key, v) settings[key] = v end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = S, TownPinRows = pinRows, Apply = function() end, THEME = { bg = {}, line = {}, accent = {}, accentSoft = {}, panel = {}, fg = {}, muted = {} }, UI = {} }
local made, boot, button, panel = 0, nil, nil, nil
local mapLeft, maximized, mapHeight = 500, false, 700
local canvasLeft = 350
local canvas = { GetLeft = function() return canvasLeft end, GetHeight = function() return canvasHeight end }
-- One of the map's own buttons in its top right corner, x from the corner.
local function MapButton(x)
    return { IsShown = function() return true end, GetNumPoints = function() return 1 end,
        GetPoint = function() return "TOPRIGHT", canvas, "TOPRIGHT", x end, GetSize = function() return 30, 30 end }
end
local function NewFrame()
    local f = { events = {}, scripts = {}, shown = true }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetFrameStrata() end
    function f:CreateTexture() return { SetTexture = function() end, SetPoint = function() end } end
    function f:ClearAllPoints() end
    function f:SetSize() end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:SetFrameLevel() end
    function f:GetFrameLevel() return 1 end
    function f:GetHeight() return 30 end
    function f:EnableMouse() end
    function f:IsShown() return self.shown end
    function f:SetShown(on) self.shown = on end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    return f
end
ns.Solid = function() return { SetAllPoints = function() end, SetPoint = function() end } end
ns.Hairline = function() end
ns.Shared = RealShared()
ns.Shared.MapPins = { questSection }
ns.Shared.Settings = { Style = { DIM_ALPHA = 0.35 } }
ns.Shared.Style = { BACKDROP_ALPHA = 0.97, BORDER_RGB = {}, LOGO_SMALL = "LogoSmall" }
ns.TownPinTexts = pinTexts
ns.Border = function() return { SetColor = function() end } end
ns.Tooltip = function() end
local function Text() return { SetPoint = function() end, SetText = function() end, SetJustifyH = function() end,
    SetWordWrap = function() end, SetAlpha = function(self, a) self.alpha = a end } end
ns.Font = Text
ns.Button = function() return { SetPoint = function() end } end
local toggles = {}
ns.UI.BuildToggleControl = function(_, _, get, set)
    local control = { get = get, set = set, SetPoint = function() end, _refreshValue = function() end,
        SetAlpha = function(self, a) self.alpha = a end, EnableMouse = function(self, on) self.mouse = on end }
    toggles[#toggles + 1] = control
    return control
end
local scroll = { SetPoint = function() end, SetScript = function() end, bar = { SetFrameLevel = function() end },
    SetScrollChild = function(self, child) self.child = child end }
ns.UI.SlimScroll = function() return scroll end
local slider
ns.UI.BuildSliderCore = function()
    local box = { SetPoint = function() end, SetAlpha = function(self, a) self.alpha = a end,
        EnableMouse = function(self, on) self.mouse = on end, ClearFocus = function(self) self.cleared = true end }
    slider = { SetPoint = function() end, _refreshValue = function() end, _valBox = box,
        SetAlpha = function(self, a) self.alpha = a end, EnableMouse = function(self, on) self.mouse = on end }
    return slider, box
end
ns.TownPinRange = { 10, 28, 1 }
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFrame = function(kind)
        local f = NewFrame()
        if kind == "Button" then made, button = made + 1, f
        elseif boot then panel = panel or f
        else boot = f end
        return f
    end,
    UnitClass = function() return "Mage", "MAGE" end,
    hooksecurefunc = function(t, name, fn)
        local old = t[name]
        t[name] = function(...) old(...); fn(...) end
    end,
    WorldMapFrame = { GetCanvasContainer = function() return canvas end, HookScript = function() end,
        GetFrameLevel = function() return 1 end, GetLeft = function() return mapLeft end,
        GetHeight = function() return mapHeight end, IsMaximized = function() return maximized end,
        Maximize = function() end, Minimize = function() end,
        overlayFrames = { MapButton(-4), MapButton(-36), { IsShown = function() return true end,
            GetNumPoints = function() return 1 end, GetPoint = function() return "BOTTOMLEFT", canvas, "BOTTOMLEFT", 0 end } } },
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/MapPinsPanel.lua")))
setfenv(chunk, env)
chunk()
boot.scripts.OnEvent(boot)
Check(made == 1 and button.shown, "the button is made with QoL on, whatever is switched on")
S.Set("enabled", false)
Check(not button.shown, "QoL off takes it away")
S.Set("enabled", true)
Check(button.shown, "and on brings it back")
S.Set("townMap", true)
Check(button.point[1] == "TOPRIGHT" and button.point[3] == "TOPLEFT" and button.point[2].GetPoint
    and select(4, button.point[2].GetPoint()) == -36, "top right, left of the map's own buttons there")
S.Set("townFlight", true)
Check(made == 1, "and is made once")

-- The drawer beside the map window.
local map = env.WorldMapFrame
button.scripts.OnClick()
Check(panel and panel.shown, "the button opens the drawer")
local towns = 0
for _, row in ipairs(pinRows) do if row.key and not row.class then towns = towns + 1 end end
Check(#toggles == 1 + towns, "a Town Pins switch and every town row, nothing from other modules; a mage has no Stable Masters")
local flight = toggles[2]
toggles[1].set(false)
Check(panel.shown and flight.mouse == false and toggles[1].mouse == nil,
    "Town Pins off: the town rows are dimmed, its own switch stays")
Check(slider.alpha == 0.35 and slider.mouse == false and slider._valBox.alpha == 0.35
    and slider._valBox.mouse == false and slider._valBox.cleared, "Town Pin Size too, its number box with it")
toggles[1].set(true)
Check(flight.mouse == true and slider._valBox.alpha == 1 and slider._valBox.mouse == true, "and back")
toggles[1].set(false)
Check(button.shown and panel.shown, "everything off: the button and drawer stay, to turn it back on")
toggles[1].set(true)
button.scripts.OnClick()
button.scripts.OnClick()
Check(panel.point[1] == "TOPRIGHT" and panel.point[2] == map and panel.point[3] == "TOPLEFT",
    "against the map window's left side")
Check(panel.height == 700 and scroll.child ~= nil, "the map's height, the rows in a scroll below the header")
button.scripts.OnClick()
Check(not panel.shown, "and closes it")
mapHeight = 500
button.scripts.OnClick()
Check(panel.height == 500, "a small map: the rows shrink so the drawer keeps the map's height")
button.scripts.OnClick()
mapHeight = 300
button.scripts.OnClick()
Check(panel.height == 300 and scroll.child.height > 300, "too small for every row: still the map's height, "
    .. "and the rows scroll")
button.scripts.OnClick()
mapHeight = 700
mapLeft = 100
button.scripts.OnClick()
Check(panel.point[2] == map and panel.point[3] == "TOPRIGHT", "no room on the left: the right side")
maximized = true
map.Maximize()
Check(panel.point[1] == "TOPRIGHT" and panel.point[2] == canvas and panel.point[3] == "TOPLEFT"
    and panel.width == 234, "the maximized map: in the black bar left of the picture, as wide as it")
Check(panel.height == 600, "no taller than the picture; the rest scrolls")
canvasLeft = 250
map.Maximize()
Check(panel.point[1] == "TOPRIGHT" and panel.point[2] == button and panel.point[3] == "BOTTOMRIGHT",
    "no bar wide enough: under the button in the top right")
Check(panel.height == 600 - 30 - 4 - 2, "and stops at the picture's foot")

print(("test-map-pins-panel: %d checks passed"):format(checks))
