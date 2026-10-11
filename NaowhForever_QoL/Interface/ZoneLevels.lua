-- ZoneLevels.lua: Zone Levels, the level range under a zone's name as you hover it on the world map.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local SECTION_ORDER = 12
local TEXT_SIZE = 16
local TEXT_GAP = 2
local BELOW_RANGE = 2
local TEXT_RANGE, TEXT_LEVEL = ns.L("Level %d-%d"), ns.L("Level %d")

local LEVELS = ns.ZoneLevels

local label, shownMapID
local added
local provider = CreateFromMixins(MapCanvasDataProviderMixin)

local function On()
    return S.Get("enabled") and S.Get("zoneLevels")
end

local function RangeColor(low, high)
    local level = UnitLevel("player")
    if level < low then return GetQuestDifficultyColor(low) end
    if level > high then return GetQuestDifficultyColor(high - BELOW_RANGE) end
    return QuestDifficultyColors.difficult
end

local function Show(mapID)
    shownMapID = mapID
    local range = mapID and LEVELS[mapID]
    if not range then
        label.text:SetText("")
        return
    end
    local low, high = range[1], range[2]
    local color = RangeColor(low, high)
    label.text:SetText(low == high and TEXT_LEVEL:format(high) or TEXT_RANGE:format(low, high))
    label.text:SetTextColor(color.r, color.g, color.b)
end

local function OnUpdate()
    local map = provider:GetMap()
    local mapID
    if map:IsCanvasMouseFocus() then
        local x, y = map:GetNormalizedCursorPosition()
        local info = C_Map.GetMapInfoAtPosition(map:GetMapID(), x, y)
        if info and info.mapID ~= map:GetMapID() then mapID = info.mapID end
    end
    if mapID ~= shownMapID then Show(mapID) end
end

local function AreaDescription(map)
    for other in pairs(map.dataProviders) do
        if other.Label and other.Label.Description then return other.Label.Description end
    end
end

function provider:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)
    label = CreateFrame("Frame", nil, map:GetCanvasContainer())
    label:SetSize(1, 1)
    label:SetFrameStrata("HIGH")
    label.text = ns.Font(label, TEXT_SIZE, "OUTLINE")
    label.text:SetPoint("TOP", AreaDescription(map), "BOTTOM", 0, -TEXT_GAP)
    label:SetScript("OnUpdate", OnUpdate)
end

local function Apply()
    if not added then
        if not On() then return end
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    Show(nil)
    label:SetShown(On())
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "zoneLevels" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

table.insert(ns.Shared.MapPins, {
    order = SECTION_ORDER, store = S, switch = "zoneLevels",
    rows = {
        { key = "zoneLevels", label = "Zone Levels", toggle = true, store = S,
          help = "Shows a zone's level range when you hover it on the world map." },
    },
})
