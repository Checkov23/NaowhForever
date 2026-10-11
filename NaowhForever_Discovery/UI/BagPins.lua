-- BagPins.lua: the Cozy Sleeping Bag's steps still to do on the world map, numbered; the one to do now in full.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local Bag = Discovery.Bag
local Style = Discovery.Style

local GOLD = Style.GOLD_RGB
local TEMPLATE = "NaowhForeverSleepingBagPinTemplate"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Bag_07"
local CROP_LOW, CROP_HIGH = Style.ICON_CROP, Style.ICON_CROP_HIGH
local LATER_ALPHA = 0.6
local BADGE = 12
local BADGE_INSET = 2
local BADGE_LEVEL = 2
local BADGE_SIZE = 9
local BADGE_ALPHA = 0.9
local OWN_KEYS = { enabled = true, bagMapPins = true, bagMapPinSize = true }
local TEXT_STEP = ns.L("Sleeping Bag, step %d")
local TEXT_LATER = ns.L("A later step.")
local TEXT_WAYPOINT = ns.L("Click for a waypoint.")

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local added, events

NaowhForeverSleepingBagPinMixin = CreateFromMixins(MapCanvasPinMixin)

local function On()
    return S.Get("enabled") and S.Get("bagMapPins")
end

local function SameSpot(a, b)
    return a and b and a.map == b.map and a.x == b.x and a.y == b.y
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function OnEvent(frame, event)
    if event ~= "QUEST_LOG_UPDATE" then
        frame:RegisterEvent("QUEST_LOG_UPDATE")
        return
    end
    frame:UnregisterEvent("QUEST_LOG_UPDATE")
    Redraw()
end

function NaowhForeverSleepingBagPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    local badge = CreateFrame("Frame", nil, self)
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("CENTER", self, "BOTTOMRIGHT", -BADGE_INSET, BADGE_INSET)
    badge:SetFrameLevel(self:GetFrameLevel() + BADGE_LEVEL)
    badge.disc = badge:CreateTexture(nil, "ARTWORK")
    badge.disc:SetAllPoints()
    badge.disc:SetTexture(Style.ROUND, "CLAMP", "CLAMP", "TRILINEAR")
    badge.disc:SetVertexColor(0, 0, 0, BADGE_ALPHA)
    badge.text = ns.Font(badge, BADGE_SIZE, nil, T.fg)
    badge.text:SetPoint("CENTER", 0, 0)
    self.badge = badge
end

function NaowhForeverSleepingBagPinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverSleepingBagPinMixin:OnAcquired(entry)
    self.entry = entry
    local size = S.Get("bagMapPinSize")
    self:SetSize(size, size)
    self.Icon:SetTexture(C_Item.GetItemIconByID(ns.SleepingBag.item) or FALLBACK_ICON)
    self.Icon:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    self.badge.text:SetText(entry.number)
    self:SetAlpha(entry.now and 1 or LATER_ALPHA)
    self:SetPosition(entry.step.x / C.PERCENT, entry.step.y / C.PERCENT)
end

function NaowhForeverSleepingBagPinMixin:OnMouseEnter()
    local entry, step = self.entry, self.entry.step
    local m, soft = T.muted, T.accentSoft
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TEXT_STEP:format(entry.number), 1, 1, 1)
    GameTooltip:AddLine(Bag.Name(step), GOLD.r, GOLD.g, GOLD.b)
    GameTooltip:AddLine(Bag.Where(step), m.r, m.g, m.b, true)
    if step.tip then GameTooltip:AddLine(step.tip, 1, 1, 1, true) end
    if not entry.now then GameTooltip:AddLine(TEXT_LATER, m.r, m.g, m.b) end
    GameTooltip:AddLine(TEXT_WAYPOINT, soft.r, soft.g, soft.b)
    GameTooltip:Show()
end

function NaowhForeverSleepingBagPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function NaowhForeverSleepingBagPinMixin:OnClick(button)
    if button == "LeftButton" then Bag.Waypoint(self.entry.step) end
end

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local _, at = Bag.Current()
    if not at then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local steps = Bag.Steps()
    for i = at, #steps do
        local step = steps[i]
        if step.map == mapID and not (i > at and SameSpot(step, steps[i - 1])) then
            map:AcquirePin(TEMPLATE, { step = step, number = i, now = i == at })
        end
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
            events:SetScript("OnEvent", OnEvent)
        end
        events:RegisterEvent("QUEST_ACCEPTED")
        events:RegisterEvent("QUEST_TURNED_IN")
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
