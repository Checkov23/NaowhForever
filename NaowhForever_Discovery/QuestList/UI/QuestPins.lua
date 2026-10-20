-- QuestPins.lua: a ! on the world map at each quest giver with a quest you can pick up.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local Style = Completo.Style

local TEMPLATE = "NaowhForeverQuestGiverPinTemplate"
local BANG_ATLAS, GREY_ATLAS, REPEAT_ATLAS = "QuestNormal", "TrivialQuests", "QuestDaily"
local BANG_FILE = "Interface\\GossipFrame\\AvailableQuestIcon"
local PERCENT = Completo.C.PERCENT
local QUEST_PIN_SCALE = 0.5
local EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP" }
local OWN_KEYS = { enabled = true, mapPins = true, mapGrey = true, mapChainsOnly = true, mapPinSize = true }
local TEXT_GIVER = ns.L("Quest giver")
local TEXT_DROPS = ns.L("Drops %s, which begins:")
local TEXT_LEVEL = ns.L("Level %d")
local TEXT_REPEATABLE = ns.L("Repeatable, ")
local TEXT_DUNGEON = ns.L("Dungeon, ")
local TEXT_WAYPOINT = ns.L("Click for a waypoint.")

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local added, events

local function ScaleQuestPin(pin)
    ns.Shared.ScalePin(pin, QUEST_PIN_SCALE)
end

NaowhForeverQuestGiverPinMixin = CreateFromMixins(MapCanvasPinMixin)
NaowhForeverQuestGiverPinMixin.ApplyCurrentScale = ScaleQuestPin

local function On()
    return S.Get("enabled") and S.Get("mapPins")
end

local function SetMark(icon, giver)
    icon:SetVertexColor(1, 1, 1)
    icon:SetDesaturated(false)
    local tint
    if giver.repeatable and not giver.dungeon then
        if icon:SetAtlas(REPEAT_ATLAS) then return end
        tint = Style.REPEAT_RGB
    elseif giver.grey then
        if icon:SetAtlas(GREY_ATLAS) then return end
        tint = Style.GREY_RGB
    elseif giver.dungeon then
        tint = Style.DUNGEON_RGB
    end
    if not icon:SetAtlas(BANG_ATLAS) then icon:SetTexture(BANG_FILE) end
    if not tint then return end
    icon:SetDesaturated(true)
    icon:SetVertexColor(tint.r, tint.g, tint.b)
end

local function AddQuestLine(id)
    local c = Q.Trivial(id) and Style.GREY_RGB or GetQuestDifficultyColor(Q.Level(id))
    local level = TEXT_LEVEL:format(Q.Level(id))
    if Q.Repeatable(id) then level = TEXT_REPEATABLE .. level end
    if Q.Dungeon(id) then level = TEXT_DUNGEON .. level end
    GameTooltip:AddDoubleLine(Q.Name(id), level, c.r, c.g, c.b, c.r, c.g, c.b)
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

function NaowhForeverQuestGiverPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function NaowhForeverQuestGiverPinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverQuestGiverPinMixin:OnAcquired(giver)
    self.quests = self.quests or {}
    wipe(self.quests)
    for i, id in ipairs(giver.quests) do self.quests[i] = id end
    self.grey = giver.grey
    local size = S.Get("mapPinSize")
    self:SetSize(size, size)
    SetMark(self.Icon, giver)
    self:SetPosition(giver.x / PERCENT, giver.y / PERCENT)
    self:ApplyCurrentScale()
end

function NaowhForeverQuestGiverPinMixin:OnMouseEnter()
    local first = self.quests[1]
    local gold = Style.GOLD_RGB
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(Q.Giver(first) or TEXT_GIVER, 1, 1, 1)
    local item = Q.Item(first)
    if item then
        local name = C_Item.GetItemNameByID(item) or Q.Name(first)
        GameTooltip:AddLine(TEXT_DROPS:format(name), gold.r, gold.g, gold.b)
    end
    for _, id in ipairs(self.quests) do AddQuestLine(id) end
    GameTooltip:AddLine(TEXT_WAYPOINT, Style.Hint())
    GameTooltip:Show()
end

function NaowhForeverQuestGiverPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function NaowhForeverQuestGiverPinMixin:OnClick(button)
    if button ~= "LeftButton" then return end
    local first = self.quests[1]
    local map, x, y = Q.Spot(first)
    if map then ns.PlaceWaypoint(Q.Giver(first) or Q.Name(first), map, x, y) end
end

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    Q.Refresh()
    for _, giver in ipairs(Q.Givers(map:GetMapID(), S.Get("mapGrey"), S.Get("mapChainsOnly"))) do
        map:AcquirePin(TEMPLATE, giver)
    end
end

local function Apply()
    if On() then
        if not added then
            WorldMapFrame:AddDataProvider(provider)
            added = true
        end
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", Redraw)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    elseif events then
        events:UnregisterAllEvents()
    end
    Redraw()
end

local function OnSet(key)
    if OWN_KEYS[key] then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
