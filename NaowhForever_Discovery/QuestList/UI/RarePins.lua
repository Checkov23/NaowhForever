-- RarePins.lua: a star on the world map for each rare you have not killed; hover or focus one for its spots and way.
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local S = Completo.Settings
local Style = Completo.Style
local R = Completo.Rares

local TEMPLATE = "NaowhForeverRarePinTemplate"
local STAR_ATLAS = Style.STAR_ATLAS
local SKULL_FILE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local FRAME_LEVEL = "PIN_FRAME_LEVEL_AREA_POI"
local KILLED_ALPHA = 0.7
local KINDS = { spot = { 0.7, 0.9 }, dot = { 0.45, 0.8 } }
local SIZE, ALPHA = 1, 2
local LIT_SCALE = 1.3
local FADED_ALPHA = 0.2
local PERCENT = Completo.C.PERCENT
local STAR_LEVEL, MORE_LEVEL = 1, 0
local OWN_KEYS = { enabled = true, rarePins = true, rarePinsKilled = true, rarePinSize = true }
local RARE_PIN_SCALE = 0.75
local TEXT_RARE = ns.L("Rare")
local TEXT_ELITE = ns.L("Rare elite")
local TEXT_KIND_LEVEL = ns.L("%s, level %s")
local TEXT_NOT_KILLED = ns.L("Not killed yet")
local TEXT_PATROLS = ns.L("Patrols: the small stars are its way")
local TEXT_SPAWNS = ns.L("Spawns at %d more spots, shown smaller")
local TEXT_HINT = ns.L("Click for a waypoint (again to remove it), right-click to keep its spots shown.")
local TEXT_HINT_FOCUSED = ns.L("Click for a waypoint (again to remove it), right-click to let go.")

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local added
local focused
local shown = {}
local spot = {}

local function ScaleRarePin(pin)
    ns.Shared.ScalePin(pin, RARE_PIN_SCALE)
end

NaowhForeverRarePinMixin = CreateFromMixins(MapCanvasPinMixin)
NaowhForeverRarePinMixin.ApplyCurrentScale = ScaleRarePin

local function On()
    return S.Get("enabled") and S.Get("rarePins")
end

local function Map()
    return provider.GetMap and provider:GetMap()
end

local function Look(pin, lit, faded)
    local kind = KINDS[pin.kind]
    local size = S.Get("rarePinSize") * (kind and kind[SIZE] or 1)
    if lit and not kind then size = size * LIT_SCALE end
    pin:SetSize(size, size)
    local alpha = kind and kind[ALPHA] or 1
    if pin.killed then alpha = alpha * KILLED_ALPHA end
    if lit and not kind then alpha = 1 elseif faded then alpha = FADED_ALPHA end
    pin.Icon:SetAlpha(alpha)
end

local function Place(map, npc, points, first, kind, into)
    for i = first * 2 - 1, points and #points or 0, 2 do
        spot.npc, spot.x, spot.y, spot.kind = npc, points[i], points[i + 1], kind
        local pin = map:AcquirePin(TEMPLATE, spot)
        if into then into[#into + 1] = pin end
    end
end

local function ShowMore(npc)
    local map = Map()
    if not map then return end
    for i = #shown, 1, -1 do
        map:RemovePin(shown[i])
        shown[i] = nil
    end
    if not npc then return end
    Place(map, npc, R.Trail(npc), 1, "dot", shown)
    Place(map, npc, R.Spots(npc), 2, "spot", shown)
end

local function Highlight(npc)
    local map = Map()
    if not map then return end
    for pin in map:EnumeratePinsByTemplate(TEMPLATE) do
        Look(pin, npc ~= nil and pin.npc == npc, npc ~= nil and pin.npc ~= npc)
    end
end

local function AddRecord(npc)
    local record = R.Record(npc)
    if not record then return GameTooltip:AddLine(TEXT_NOT_KILLED, 1, 1, 1) end
    local have = Style.HAVE_RGB
    GameTooltip:AddLine(R.KilledText(record), have.r, have.g, have.b)
end

local function ShowTip(pin)
    local npc, m, gold = pin.npc, T.muted, Style.GOLD_RGB
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(R.Name(npc), 1, 1, 1)
    local kind = R.Elite(npc) and TEXT_ELITE or TEXT_RARE
    GameTooltip:AddLine(TEXT_KIND_LEVEL:format(kind, R.LevelText(npc)), gold.r, gold.g, gold.b)
    AddRecord(npc)
    local others = R.SpotCount(npc) - 1
    if R.Trail(npc) then GameTooltip:AddLine(TEXT_PATROLS, m.r, m.g, m.b) end
    if others > 0 then GameTooltip:AddLine(TEXT_SPAWNS:format(others), m.r, m.g, m.b) end
    R.AddLoot(GameTooltip, npc)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(npc == focused and TEXT_HINT_FOCUSED or TEXT_HINT, Style.Hint())
    GameTooltip:Show()
end

local function Rest()
    ShowMore(focused)
    Highlight(focused)
end

function NaowhForeverRarePinMixin:OnLoad()
    self:UseFrameLevelType(FRAME_LEVEL)
end

function NaowhForeverRarePinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverRarePinMixin:OnAcquired(data)
    self.npc, self.spotX, self.spotY, self.kind = data.npc, data.x, data.y, data.kind
    self.killed = R.Killed(data.npc)
    self:UseFrameLevelType(FRAME_LEVEL, data.kind and MORE_LEVEL or STAR_LEVEL)
    self:EnableMouse(not data.kind)
    ns.Shared.PinClicks(self, not data.kind)
    local icon = self.Icon
    if not icon:SetAtlas(STAR_ATLAS) then icon:SetTexture(SKULL_FILE) end
    icon:SetDesaturated(self.killed)
    Look(self)
    self:SetPosition(data.x / PERCENT, data.y / PERCENT)
    if self.ApplyCurrentScale then self:ApplyCurrentScale() end
end

function NaowhForeverRarePinMixin:OnMouseEnter()
    ShowTip(self)
    ShowMore(self.npc)
    Highlight(self.npc)
end

function NaowhForeverRarePinMixin:OnMouseLeave()
    GameTooltip:Hide()
    Rest()
end

function NaowhForeverRarePinMixin:OnClick(button)
    if button == "LeftButton" then
        ns.ToggleWaypoint(R.Name(self.npc), R.Map(self.npc), self.spotX, self.spotY)
    elseif button == "RightButton" then
        focused = focused ~= self.npc and self.npc or nil
        if focused then return self:OnMouseEnter() end
        Rest()
        ShowTip(self)
    end
end

function provider:RemoveAllData()
    wipe(shown)
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    local killedToo = S.Get("rarePinsKilled")
    local still = false
    for _, npc in ipairs(R.OnMap(map:GetMapID())) do
        if killedToo or not R.Killed(npc) then
            local spots = R.Spots(npc)
            spot.npc, spot.x, spot.y, spot.kind = npc, spots[1], spots[2], nil
            map:AcquirePin(TEMPLATE, spot)
            if npc == focused then still = true end
        end
    end
    if not still then focused = nil end
    Rest()
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function Apply()
    if On() and not added then
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    Redraw()
end

local function OnRareChanged()
    if On() then Redraw() end
end

local function OnSet(key)
    if OWN_KEYS[key] then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

R.OnChange(OnRareChanged)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
