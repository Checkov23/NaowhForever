-- EntrancePins.lua: the dungeon and raid entrances as pins on the world map.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local PERCENT = J.C.PERCENT
local St = J.Style
local KIND_RGB, NAME_RGB, HINT_RGB = St.ENTRANCE_KIND_RGB, St.GOLD_NAME_RGB, St.ENTRANCE_HINT_RGB

local TEMPLATE = "NaowhForeverEntrancePinTemplate"
local PIN_SIZE = 18
local MAP_COSMIC, MAP_WORLD, MAP_CONTINENT = 0, 1, 2
local ZONE_SIZE, CONTINENT_SIZE, WORLD_SIZE = 1, 0.75, 0.6
local WORLD_POS_RETURN = 2
local ICON = "dungeon"
local RAID_ICON = "raid"
local FRAME_LEVEL = "PIN_FRAME_LEVEL_AREA_POI"
local SPOT_KEY = "%s:%s:%s"

local TEXT_ENTRANCE_NAME = ns.L("Entrance")
local TEXT_RAID = ns.L("Raid, %d players")
local TEXT_DUNGEON = ns.L("Dungeon")
local TEXT_KIND_LEVELS = "%s, %s"
local TEXT_CLICK = ns.L("Click for a waypoint.")
local TEXT_ENTRANCE = ns.L(" (entrance)")

local provider, added, events
local spots = {}
local waitingForMap = false

local function On()
    return S.Get("enabled") and S.Get("mapEntrances")
end

local function PinSize(map)
    local info = C_Map.GetMapInfo(map:GetMapID())
    local kind = info and info.mapType
    local step = (kind == MAP_COSMIC or kind == MAP_WORLD) and WORLD_SIZE
        or kind == MAP_CONTINENT and CONTINENT_SIZE or ZONE_SIZE
    return PIN_SIZE * step * (S.Get("mapEntranceScale") or 1)
end

local function OnMap(px, py)
    return px >= 0 and px <= 1 and py >= 0 and py <= 1
end

local function FindSpot(mapID, entrance)
    local x, y = entrance.x / PERCENT, entrance.y / PERCENT
    if entrance.map == mapID then return { x, y } end
    local continent, world = C_Map.GetWorldPosFromMapPos(entrance.map, CreateVector2D(x, y))
    local pos = continent and world and select(WORLD_POS_RETURN, C_Map.GetMapPosFromWorldPos(continent, world, mapID))
    if not pos then return false end
    local px, py = pos:GetXY()
    if OnMap(px, py) then return { px, py } end
    return false
end

local function SpotOn(mapID, entrance)
    local known = spots[mapID]
    if not known then
        known = {}
        spots[mapID] = known
    end
    local spot = known[entrance]
    if spot == nil then
        spot = FindSpot(mapID, entrance)
        known[entrance] = spot
    end
    return spot or nil
end

local function AllRaids(dungeons)
    for _, dungeon in ipairs(dungeons) do
        if not dungeon.raid then return false end
    end
    return true
end

local function KindText(dungeon)
    local levels = J.ColoredLevelRange(dungeon)
    local kind = dungeon.raid and TEXT_RAID:format(dungeon.raid) or TEXT_DUNGEON
    return levels and TEXT_KIND_LEVELS:format(kind, levels) or kind
end

local function GroupName(dungeons, fallback)
    return #dungeons == 1 and dungeons[1].name or dungeons[1].zone or fallback
end

local function MakePinMixin()
    NaowhForeverEntrancePinMixin = CreateFromMixins(MapCanvasPinMixin)
    local Pin = NaowhForeverEntrancePinMixin
    Pin.ApplyCurrentScale = ns.Shared.ScalePin

    function Pin:OnLoad()
        self:UseFrameLevelType(FRAME_LEVEL)
    end

    function Pin:CheckMouseButtonPassthrough() end

    function Pin:OnAcquired(group)
        self.group = group
        local size = PinSize(self:GetMap())
        self:SetSize(size, size)
        if not (AllRaids(group.dungeons) and self.Icon:SetAtlas(RAID_ICON)) then self.Icon:SetAtlas(ICON) end
        self:SetPosition(group.x, group.y)
        self:ApplyCurrentScale()
    end

    function Pin:OnMouseEnter()
        local dungeons = self.group.dungeons
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(GroupName(dungeons, TEXT_ENTRANCE_NAME), 1, 1, 1)
        for _, dungeon in ipairs(dungeons) do
            local right = KindText(dungeon)
            if #dungeons == 1 then
                GameTooltip:AddLine(right, KIND_RGB.r, KIND_RGB.g, KIND_RGB.b)
            else
                GameTooltip:AddDoubleLine(dungeon.name, right, NAME_RGB.r, NAME_RGB.g, NAME_RGB.b,
                    KIND_RGB.r, KIND_RGB.g, KIND_RGB.b)
            end
        end
        local c = ns.ThemeTint("accentSoft", nil) or HINT_RGB
        GameTooltip:AddLine(TEXT_CLICK, c.r, c.g, c.b)
        GameTooltip:Show()
    end

    function Pin:OnMouseLeave()
        GameTooltip:Hide()
    end

    function Pin:OnClick(button)
        if button ~= "LeftButton" then return end
        local dungeons = self.group.dungeons
        local entrance = dungeons[1].entrance
        ns.PlaceWaypoint(GroupName(dungeons, dungeons[1].name), entrance.map, entrance.x, entrance.y, TEXT_ENTRANCE)
    end
end

local function GroupBySpot(mapID, groups, bySpot, dungeon)
    local entrance = dungeon.entrance
    local spot = entrance and J.FactionShown(dungeon) and SpotOn(mapID, entrance)
    if not spot then return end
    local key = SPOT_KEY:format(entrance.map, entrance.x, entrance.y)
    local group = bySpot[key]
    if not group then
        group = { x = spot[1], y = spot[2], dungeons = {} }
        bySpot[key] = group
        groups[#groups + 1] = group
    end
    group.dungeons[#group.dungeons + 1] = dungeon
end

local function MakeProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end

    function provider:RefreshAllData()
        self:RemoveAllData()
        if not On() then return end
        local map = self:GetMap()
        local mapID = map:GetMapID()
        if not mapID then return end
        local groups, bySpot = {}, {}
        for _, dungeon in ipairs(J.Dungeons()) do GroupBySpot(mapID, groups, bySpot, dungeon) end
        for _, group in ipairs(groups) do map:AcquirePin(TEMPLATE, group) end
    end
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function Event(_, event)
    if event == "PLAYER_REGEN_ENABLED" then events:UnregisterEvent(event) end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    Redraw()
end

local function Resize()
    if not (added and WorldMapFrame:IsShown()) then return end
    for pin in WorldMapFrame:EnumeratePinsByTemplate(TEMPLATE) do
        local size = PinSize(WorldMapFrame)
        pin:SetSize(size, size)
    end
end

local function Setup()
    MakePinMixin()
    MakeProvider()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", Event)
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        Redraw()
        return
    end
    if not WorldMapFrame then
        if not waitingForMap then
            waitingForMap = true
            EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Apply)
        end
        return
    end
    if not provider then Setup() end
    if not added then
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        Redraw()
    end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "mapEntrances" or key == "showAlliance" or key == "showHorde" then
        Apply()
    elseif key == "mapEntranceScale" then
        Resize()
    end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
