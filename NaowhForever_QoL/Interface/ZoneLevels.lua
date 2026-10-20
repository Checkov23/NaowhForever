-- ZoneLevels.lua: Zone Levels and Fishing Levels, a zone's level range and Fishing skill under its name as you hover it on the world map.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local SECTION_ORDER = 12
local FISHING_ORDER = 13
local TEXT_SIZE = 16
local TEXT_GAP = 2
local BELOW_RANGE = 2
local FISHING_SLOT = 4
local TEXT_RANGE, TEXT_LEVEL = ns.L("Level %d-%d"), ns.L("Level %d")
local TEXT_FISHING = ns.L("Fishing %d-%d")

local LEVELS = ns.ZoneLevels
local FISHING = ns.FishingLevels

local label, shownMapID
local lastX, lastY, lastMapID
local added
local provider = CreateFromMixins(MapCanvasDataProviderMixin)

local function ZoneInfoOn()
    return S.Get("zoneInfo") and not ns.GamepadStandDown()
end

local function LevelsOn()
    return S.Get("enabled") and S.Get("zoneLevels") and not ZoneInfoOn()
end

local function FishingOn()
    return S.Get("enabled") and S.Get("mapFishing") and not ZoneInfoOn()
end

local function On()
    return LevelsOn() or FishingOn()
end

local function RangeColor(low, high)
    local level = UnitLevel("player")
    if level < low then return GetQuestDifficultyColor(low) end
    if level > high then return GetQuestDifficultyColor(high - BELOW_RANGE) end
    return QuestDifficultyColors.difficult
end

local function MySkill()
    local fishing = select(FISHING_SLOT, GetProfessions())
    if not fishing then return nil end
    local _, _, rank, _, _, _, _, modifier = GetProfessionInfo(fishing)
    return (rank or 0) + (modifier or 0)
end

local function SkillColor(low, high)
    local skill = MySkill()
    if not skill then return QuestDifficultyColors.trivial end
    if skill < low then return QuestDifficultyColors.impossible end
    if skill < high then return QuestDifficultyColors.difficult end
    return QuestDifficultyColors.standard
end

local function ShowLevels(mapID)
    local range = mapID and LevelsOn() and LEVELS[mapID]
    if not range then
        label.text:SetText("")
        return false
    end
    local low, high = range[1], range[2]
    local color = RangeColor(low, high)
    label.text:SetText(low == high and TEXT_LEVEL:format(high) or TEXT_RANGE:format(low, high))
    label.text:SetTextColor(color.r, color.g, color.b)
    return true
end

local function ShowFishing(mapID, below)
    label.fishing:ClearAllPoints()
    label.fishing:SetPoint("TOP", below, "BOTTOM", 0, -TEXT_GAP)
    local range = mapID and FishingOn() and FISHING[mapID]
    if not range then
        label.fishing:SetText("")
        return
    end
    local low, high = range[1], range[2]
    local color = SkillColor(low, high)
    label.fishing:SetText(TEXT_FISHING:format(low, high))
    label.fishing:SetTextColor(color.r, color.g, color.b)
end

local function Show(mapID)
    shownMapID = mapID
    local levels = ShowLevels(mapID)
    ShowFishing(mapID, levels and label.text or label.description)
end

local function OnUpdate()
    local map = provider:GetMap()
    local mapID
    if map:IsCanvasMouseFocus() then
        local x, y = map:GetNormalizedCursorPosition()
        local current = map:GetMapID()
        if x == lastX and y == lastY and current == lastMapID then return end
        lastX, lastY, lastMapID = x, y, current
        local info = C_Map.GetMapInfoAtPosition(current, x, y)
        if info and info.mapID ~= current then mapID = info.mapID end
    else
        lastX = nil
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
    label.description = AreaDescription(map)
    label.text = ns.Font(label, TEXT_SIZE, "OUTLINE")
    label.text:SetPoint("TOP", label.description, "BOTTOM", 0, -TEXT_GAP)
    label.fishing = ns.Font(label, TEXT_SIZE, "OUTLINE")
    label:SetScript("OnUpdate", OnUpdate)
end

local function Apply()
    if not added then
        if not On() then return end
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    Show(nil)
    lastX = nil
    label:SetShown(On())
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "zoneLevels" or key == "mapFishing" or key == "zoneInfo" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

table.insert(ns.Shared.MapPins, {
    map = true,
    order = SECTION_ORDER, store = S, switch = "zoneLevels",
    rows = {
        { key = "zoneLevels", label = "Zone Levels", toggle = true, store = S,
          help = "Shows a zone's level range when you hover it on the world map." },
    },
})

table.insert(ns.Shared.MapPins, {
    map = true,
    order = FISHING_ORDER, store = S, switch = "mapFishing",
    rows = {
        { key = "mapFishing", label = "Fishing Levels", toggle = true, store = S,
          help = "Shows the Fishing skill a zone needs when you hover it on the world map." },
    },
})
