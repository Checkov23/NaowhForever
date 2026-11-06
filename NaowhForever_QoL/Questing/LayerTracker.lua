-- LayerTracker.lua: Layer Tracker, the layer you are on, read from the NPCs around you, and the layers seen in your zone (ns.Layers).
local ns = _G.NaowhForever

local UnitGUID = UnitGUID
local issecretvalue = issecretvalue

local S = ns.QoLSettings
local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local Settings = ns.Shared.Settings
local LayerOf = ns.Shared.LayerOf
local Ago = ns.Shared.Ago

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "NAME_PLATE_UNIT_ADDED", "SHARD_TRANSFER_IMMINENT", "SHARD_TRANSFER_CANCELLED", "SHARD_TRANSFER",
}
local ZONE_TYPE = Enum.UIMapType.Zone
local TICK = 1
local SEEN_MAX = 12
local PAD_W, ROOM = 16, 8
local DEFAULT_POS = { point = "TOP", relPoint = "TOP", x = -274, y = -77 }
local TEXT_RANGE = { 10, 40, 1 }
local SECONDS_PER_MINUTE = ns.QoLConstants.SECONDS_PER_MINUTE
local MOVER_LABEL = "Layer Tracker"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Questing & Group", "QoL/Questing & Group:layerTracker"
local CLOCK = "%d:%02d"
local TEXT_UNKNOWN = "?"
local TEXT_LAYER = ns.L("Layer %s")
local TEXT_CHANGES = ns.L("%s - changes in %s")
local TEXT_CHANGING = ns.L("%s - changing")
local TEXT_ASKING = ns.L("%s - asking")
local TEXT_MOVED = ns.L("You moved to layer %s (it was %s).")
local TEXT_TITLE = ns.L("Layers in %s")
local TEXT_HERE = ns.L("You are here")
local TEXT_ASKED = ns.L("From a swap request, %s")
local TEXT_NONE = ns.L("Target or mouse over an NPC to read your layer.")
local TEXT_WHY_SWAPS = "Swap Layers With Others is off"
local NONE = {}

local events, frame, ticker
local layer, shown, map, inside, unlocked, refreshAt, wasKey, wasZone, pendingKey, pendingGuid
local seen = {}
local order = {}

local Layers = {}
ns.Layers = Layers

local function On()
    return S.Get("enabled") and S.Get("layerTracker")
end

local function ZoneMap()
    local id = C_Map.GetBestMapForUnit("player")
    local info = id and C_Map.GetMapInfo(id)
    while info and info.mapType > ZONE_TYPE and info.parentMapID ~= 0 do
        id = info.parentMapID
        info = C_Map.GetMapInfo(id)
    end
    return id
end

local function Oldest(list)
    local oldest
    for key, entry in pairs(list) do
        if not oldest or entry.at < list[oldest].at then oldest = key end
    end
    return oldest
end

local function Note(where, key, zone, asked)
    if not where then return end
    local list = seen[where]
    if not list then
        list = { n = 0, entries = {} }
        seen[where] = list
    end
    local entry = list.entries[key]
    if not entry then
        if list.n >= SEEN_MAX then
            list.entries[Oldest(list.entries)] = nil
            list.n = list.n - 1
        end
        entry = { key = key, zone = zone, asked = asked }
        list.entries[key] = entry
        list.n = list.n + 1
    end
    if not asked then entry.asked = false end
    entry.at = time()
end

local function Label(key, zone)
    local list = map and seen[map]
    if not list then return zone end
    for other, entry in pairs(list.entries) do
        if other ~= key and entry.zone == zone then return key end
    end
    return zone
end

local function Text()
    local text = TEXT_LAYER:format(layer and Label(layer, shown) or TEXT_UNKNOWN)
    if refreshAt and S.Get("layerTrackerCountdown") then
        local left = refreshAt - GetTime()
        if left <= 0 then return TEXT_CHANGING:format(text) end
        local clock = CLOCK:format(math.floor(left / SECONDS_PER_MINUTE), math.floor(left % SECONDS_PER_MINUTE))
        return TEXT_CHANGES:format(text, clock)
    end
    if Layers.Asking() then return TEXT_ASKING:format(text) end
    return text
end

local function Update()
    if inside and not unlocked then
        frame:Hide()
        return
    end
    frame.text:SetText(Text())
    frame:SetWidth(frame.text:GetStringWidth() + PAD_W)
    frame:Show()
end

local function Clock()
    local want = refreshAt and S.Get("layerTrackerCountdown")
    if want and not ticker then
        ticker = C_Timer.NewTicker(TICK, Update)
    elseif not want and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function Seen(key, zone, guid)
    if key == layer then
        pendingKey, pendingGuid = nil, nil
        return
    end
    if key ~= pendingKey or guid == pendingGuid then
        pendingKey, pendingGuid = key, guid
        return
    end
    pendingKey, pendingGuid = nil, nil
    layer, shown = key, zone
    Note(map, key, zone, false)
    if wasKey and wasKey ~= key and S.Get("layerTrackerChat") then
        ns.Print(TEXT_MOVED:format(Label(key, zone), Label(wasKey, wasZone)))
    end
    wasKey, wasZone = nil, nil
    Update()
end

local function Read(unit, replace)
    if inside or (layer and not replace) then return end
    local guid = UnitGUID(unit)
    local key, zone = LayerOf(guid)
    if key then Seen(key, zone, guid) end
end

local function Forget()
    layer, shown, pendingKey, pendingGuid = nil, nil, nil, nil
    Update()
end

local function OnEvent(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if not (layer or issecretvalue(unit)) then Read(unit) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        Read("target", true)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Read("mouseover", true)
    elseif event == "SHARD_TRANSFER_IMMINENT" then
        refreshAt = GetTime() + GetEvictionTimeRemaining()
        Clock()
        Update()
    elseif event == "SHARD_TRANSFER_CANCELLED" then
        refreshAt = nil
        Clock()
        Update()
    elseif event == "SHARD_TRANSFER" then
        refreshAt = nil
        Clock()
        wasKey, wasZone = layer, shown
        Forget()
    else
        wasKey, wasZone = nil, nil
        inside = IsInInstance()
        map = ZoneMap()
        Forget()
        if event == "PLAYER_ENTERING_WORLD" then Read("target", true) end
    end
end

local function ByRecent(a, b)
    return a.at > b.at
end

local function ShowTip(self)
    if not Parts.Tip(self, "ANCHOR_BOTTOM") then return end
    local info = map and C_Map.GetMapInfo(map)
    GameTooltip:SetText(TEXT_TITLE:format(info and info.name or TEXT_UNKNOWN), 1, 1, 1)
    wipe(order)
    for _, entry in pairs(map and seen[map] and seen[map].entries or NONE) do order[#order + 1] = entry end
    table.sort(order, ByRecent)
    local m, a = T.muted, T.accentSoft
    if #order == 0 then GameTooltip:AddLine(TEXT_NONE, m.r, m.g, m.b, true) end
    for _, entry in ipairs(order) do
        local label = Label(entry.key, entry.zone)
        if entry.key == layer then
            GameTooltip:AddDoubleLine(label, TEXT_HERE, 1, 1, 1, a.r, a.g, a.b)
        else
            local when = Ago(entry.at)
            GameTooltip:AddDoubleLine(label, entry.asked and TEXT_ASKED:format(when) or when, 1, 1, 1, m.r, m.g, m.b)
        end
    end
    Layers.AddTip(GameTooltip)
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local function OnClick()
    Layers.Click()
end

local function SavePosition(pos)
    S.Set("layerTrackerPos", pos)
end

local function Build()
    frame = CreateFrame("Button", "NaowhForeverLayerTracker", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", OnClick)
    frame:SetScript("OnEnter", ShowTip)
    frame:SetScript("OnLeave", HideTip)
    frame.backdrop = Parts.HudBackdrop(frame)
    frame.text = ns.Font(frame, S.Get("layerTrackerFontSize"), "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.mover = UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
    frame:Hide()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

local function Place()
    local pos = S.Get("layerTrackerPos") or DEFAULT_POS
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function Restyle()
    local size = S.Get("layerTrackerFontSize")
    local mode = frame.backdrop:SetMode(S.Get("layerTrackerBackground"))
    Parts.HudFont(frame.text, S.Get("layerTrackerFont"), size, S.Get("layerTrackerOutline"), mode)
    frame:SetHeight(size + ROOM)
end

local function Apply()
    if not On() then
        layer, shown, wasKey, wasZone, refreshAt, pendingKey, pendingGuid = nil, nil, nil, nil, nil, nil, nil
        if frame then
            Clock()
            events:UnregisterAllEvents()
            frame:Hide()
        end
        return
    end
    if not frame then Build() end
    Restyle()
    Place()
    frame.mover:SetShown(unlocked == true)
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    inside = IsInInstance()
    map = ZoneMap()
    Read("target", true)
    Clock()
    Update()
end

function Layers.Current()
    return layer, shown
end

function Layers.Map()
    return map
end

function Layers.Note(where, key, zone)
    Note(where, key, zone, true)
end

function Layers.Refresh()
    if frame and On() then Update() end
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^layerTracker") and key ~= "layerTrackerPos") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = Settings.Group

local function Swapping()
    return S.Get("layerRequests")
end

Settings.Page(SETTINGS_PAGE, S):Card({
    id = "layerTracker", name = "Layer Tracker", order = 27, switch = "layerTracker",
    help = "Shows which layer you are on, read from the NPCs around you.",
    rows = {
        Group("Show"),
        { key = "layerTrackerCountdown", label = "Countdown to a Layer Change", toggle = true,
          help = "Counts down on the line when the game is about to move you to another layer." },
        { key = "layerTrackerChat", label = "Say When You Move", toggle = true,
          help = "A line in chat with your new layer after the game moves you." },
        Group("Swaps"),
        { key = "layerRequests", label = "Swap Layers With Others", toggle = true,
          help = "Click the line to ask players on other layers of your zone for an invite." },
        { key = "layerRequestsHost", label = "Show Requests From Others", toggle = true, needs = Swapping,
          why = TEXT_WHY_SWAPS, help = "Asks whether to invite a player in your zone who wants your layer." },
        { key = "layerRequestsLeave", label = "Leave Failed Swaps", toggle = true, needs = Swapping,
          why = TEXT_WHY_SWAPS, help = "Leaves the group again when joining it did not move you." },
        Settings.Look("layerTracker", { text = true, size = TEXT_RANGE, background = "card" }),
    },
})
