-- MapRoute.lua: the journey drawn on the world map as dots: the walk you are on along its path, then each leg after it.
local ns = _G.NaowhForever

local sqrt, fmod = math.sqrt, math.fmod

local T = ns.THEME
local Jy = ns.Journeys
local S = Jy.Settings
local Guide = Jy.Guide

local TEMPLATE = "NaowhForeverJourneyRoutePinTemplate"
local DOT = ns.Shared.Style.ROUND
local FILTER = "TRILINEAR"
local WALK_SIZE, LEG_SIZE = 7, 5
local WALK_GAP, LEG_GAP = 13, 11
local WALK_ALPHA, LEG_ALPHA = 0.9, 0.55
local CENTER = 0.5
local TINT = {
    fly = { 0.2, 1, 0.35 },
    ship = { 0, 0.75, 1 },
    tram = { 1, 0.6, 0.2 },
    lift = { 1, 0.6, 0.2 },
    portal = { 0.85, 0.35, 1 },
    hearth = { 0.85, 0.35, 1 },
    teleport = { 0.85, 0.35, 1 },
}

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local added
local points = {}

NaowhForeverJourneyRoutePinMixin = CreateFromMixins(MapCanvasPinMixin)

local function On()
    return Jy.On() and S.Get("mapRoute")
end

local function Continent(mapID)
    local c = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(CENTER, CENTER))
    return c
end

local function Collect()
    wipe(points)
    local ahead = Guide.Points()
    if not ahead then return end
    local here = Jy.World.Player()
    if here then points[1] = { c = here.c, x = here.x, y = here.y, walk = true } end
    for _, p in ipairs(ahead) do points[#points + 1] = p end
end

function Jy.RouteDots(ax, ay, bx, by, gap, carry, place)
    local dx, dy = bx - ax, by - ay
    local length = sqrt(dx * dx + dy * dy)
    local at = carry or fmod(length, gap)
    while at <= length do
        local t = length > 0 and at / length or 0
        place(ax + dx * t, ay + dy * t)
        at = at + gap
    end
    return at - length
end

function NaowhForeverJourneyRoutePinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetIgnoreGlobalPinScale(true)
    self.dots = {}
    self.place = function(x, y) self:Place(x, y) end
end

function NaowhForeverJourneyRoutePinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverJourneyRoutePinMixin:Place(x, y)
    self.count = self.count + 1
    local dot = self.dots[self.count]
    if not dot then
        dot = self:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(DOT, nil, nil, FILTER)
        self.dots[self.count] = dot
    end
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", self, "TOPLEFT", x, -y)
    dot:SetSize(self.size, self.size)
    local tint = self.tint
    if tint then
        dot:SetVertexColor(tint[1], tint[2], tint[3], self.alpha)
    else
        dot:SetVertexColor(T.accent.r, T.accent.g, T.accent.b, self.alpha)
    end
    dot:Show()
end

function NaowhForeverJourneyRoutePinMixin:Draw()
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local canvas = map:GetCanvas()
    local w, h = canvas:GetSize()
    self:SetSize(w, h)
    self:SetPosition(CENTER, CENTER)
    local continent = Continent(mapID)
    local scale = 1 / map:GetCanvasScale()
    local last, carry = nil, nil
    self.count = 0
    for _, p in ipairs(points) do
        local u, v
        if p.c == continent then
            local _, pos = C_Map.GetMapPosFromWorldPos(p.c, CreateVector2D(p.x, p.y), mapID)
            if pos then u, v = pos.x, pos.y end
        end
        if u and last then
            self.size = (p.walk and WALK_SIZE or LEG_SIZE) * scale
            self.alpha = p.walk and WALK_ALPHA or LEG_ALPHA
            self.tint = not p.walk and TINT[p.mode] or nil
            carry = Jy.RouteDots(last[1] * w, last[2] * h, u * w, v * h, (p.walk and WALK_GAP or LEG_GAP) * scale, carry,
                self.place)
        else
            carry = nil
        end
        last = u and { u, v } or nil
    end
    for i = self.count + 1, #self.dots do self.dots[i]:Hide() end
end

function NaowhForeverJourneyRoutePinMixin:OnAcquired()
    self:Draw()
end

function NaowhForeverJourneyRoutePinMixin:OnCanvasScaleChanged()
    self:Draw()
end

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    local journey = Guide.Current()
    if not (On() and journey) then return end
    Collect()
    if #points > 1 then self:GetMap():AcquirePin(TEMPLATE) end
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

Guide.OnChange(Redraw)
S.OnChange(Apply)
hooksecurefunc(ns, "Apply", Apply)
Apply()
