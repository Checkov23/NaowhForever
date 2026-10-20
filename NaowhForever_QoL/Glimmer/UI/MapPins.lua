-- MapPins.lua: the herbs and veins you have gathered, on the world map, and noting each one as you gather it.
local ns = _G.NaowhForever

local T = ns.THEME
local G = ns.Glimmer
local S = G.Settings
local C, St = G.C, G.Style
local Spots, Target = G.Spots, G.Target

local TEMPLATE = "NaowhForeverGatheredPinTemplate"
local PIN_SCALE = 0.5
local PERCENT = 100
local OWN_KEYS = { enabled = true, gatheredPins = true, gatheredPinSize = true, ore = true, herb = true,
    myProfessions = true, skillColors = true, oreColor = true, herbColor = true }
local TEXT_LINE = "%s (%d)"
local TEXT_COUNT = ns.L("Gathered %d times, last %s.")
local TEXT_WAYPOINT = ns.L("Click for a waypoint (again to remove it).")

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local added, events, lastGUID
local read = {}

NaowhForeverGatheredPinMixin = CreateFromMixins(MapCanvasPinMixin)

function NaowhForeverGatheredPinMixin:ApplyCurrentScale()
    ns.Shared.ScalePin(self, PIN_SCALE)
end

local function On()
    return G.On() and S.Get("gatheredPins")
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

function NaowhForeverGatheredPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self.Icon:SetTexCoord(St.ICON_CROP, St.ICON_CROP_HIGH, St.ICON_CROP, St.ICON_CROP_HIGH)
end

function NaowhForeverGatheredPinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverGatheredPinMixin:OnAcquired(entry)
    ns.Shared.PinClicks(self)
    local node = G.NODES[entry.id]
    self.entry, self.node = entry, node
    local size = S.Get("gatheredPinSize")
    self:SetSize(size, size)
    self.Icon:SetTexture(C_Spell.GetSpellTexture(C.ICON_SPELL[node[1]]))
    local tier = S.Get("skillColors") and Spots.Tier(entry.id)
    local c = tier and St.TIER_RGB[tier] or S.Get(node[1] .. "Color")
    self.Ring:SetVertexColor(c.r, c.g, c.b)
    self:SetPosition(entry.x / C.SPOT_SCALE, entry.y / C.SPOT_SCALE)
    self:ApplyCurrentScale()
end

function NaowhForeverGatheredPinMixin:OnMouseEnter()
    local entry, node = self.entry, self.node
    local m, soft = T.muted, T.accentSoft
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TEXT_LINE:format(ns.L(node[3]), node[2]), 1, 1, 1)
    local tier = Spots.Tier(entry.id)
    if tier then
        local c = St.TIER_RGB[tier]
        GameTooltip:AddLine(Target.TierText(node[1], node[2], tier), c.r, c.g, c.b)
    end
    GameTooltip:AddLine(TEXT_COUNT:format(entry.count, ns.Shared.Ago(entry.last)), m.r, m.g, m.b)
    GameTooltip:AddLine(TEXT_WAYPOINT, soft.r, soft.g, soft.b)
    GameTooltip:Show()
end

function NaowhForeverGatheredPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function NaowhForeverGatheredPinMixin:OnClick(button)
    if button ~= "LeftButton" then return end
    local entry = self.entry
    ns.ToggleWaypoint(ns.L(self.node[3]), self:GetMap():GetMapID(), entry.x * PERCENT / C.SPOT_SCALE,
        entry.y * PERCENT / C.SPOT_SCALE)
end

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    for _, entry in pairs(Spots.Gathered(map:GetMapID()) or {}) do
        local node = G.NODES[entry.id]
        if node and S.Get(node[1]) then map:AcquirePin(TEMPLATE, entry) end
    end
end

local function FromNode(guid)
    for slot = 1, GetNumLootItems() do
        local source = GetLootSourceInfo(slot)
        if source and G.Plain(source) and source == guid then return true end
    end
    return false
end

local function OnLoot()
    local info = Target.Read(C.UNIT, read)
    if not (info and info.ready and info.id and (info.category == "ore" or info.category == "herb")) then return end
    local guid = UnitGUID(C.UNIT)
    if not (guid and G.Plain(guid)) or guid == lastGUID or not FromNode(guid) then return end
    lastGUID = guid
    if Spots.Record(info.id) then Redraw() end
end

local function Apply()
    if On() then
        if not added then
            WorldMapFrame:AddDataProvider(provider)
            added = true
        end
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnLoot)
        end
        events:RegisterEvent("LOOT_OPENED")
    elseif events then
        events:UnregisterAllEvents()
    end
    Redraw()
end

local function OnSet(key)
    if OWN_KEYS[key] then C_Timer.After(0, Apply) end
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
