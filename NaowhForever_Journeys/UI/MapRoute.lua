-- MapRoute.lua: the journey drawn on the world map: the walk you are on along its path, then each leg after it.
local ns = _G.NaowhForever

local T = ns.THEME
local Jy = ns.Journeys
local S = Jy.Settings
local Guide = Jy.Guide

local TEMPLATE = "NaowhForeverJourneyRoutePinTemplate"
local WALK_WIDTH, LEG_WIDTH = 4, 2
local WALK_ALPHA, LEG_ALPHA = 0.9, 0.55
local CENTER = 0.5

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

local function Add(c, x, y, walk)
    points[#points + 1] = { c = c, x = x, y = y, walk = walk }
end

local function Collect(journey)
    wipe(points)
    local legs = journey.plan and journey.plan.legs
    if not legs then return end
    local corners, at = journey.corners, journey.corner or 1
    local here = Jy.World.Player()
    if here then Add(here.c, here.x, here.y, true) end
    local first = 1
    if corners then
        for i = at * 2 - 1, #corners, 2 do Add(legs[1].c, corners[i], corners[i + 1], true) end
        first = 2
    end
    for i = first, #legs do
        local leg = legs[i]
        Add(leg.c, leg.x, leg.y, leg.mode == "walk")
    end
end

function NaowhForeverJourneyRoutePinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetIgnoreGlobalPinScale(true)
    self.lines = {}
end

function NaowhForeverJourneyRoutePinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverJourneyRoutePinMixin:Line(i)
    local line = self.lines[i]
    if not line then
        line = self:CreateLine(nil, "OVERLAY")
        self.lines[i] = line
    end
    return line
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
    local n, last = 0, nil
    for _, p in ipairs(points) do
        local u, v
        if p.c == continent then
            local _, pos = C_Map.GetMapPosFromWorldPos(p.c, CreateVector2D(p.x, p.y), mapID)
            if pos then u, v = pos.x, pos.y end
        end
        if u and last then
            n = n + 1
            local line = self:Line(n)
            line:SetStartPoint("TOPLEFT", self, last[1] * w, -last[2] * h)
            line:SetEndPoint("TOPLEFT", self, u * w, -v * h)
            line:SetThickness((p.walk and WALK_WIDTH or LEG_WIDTH) * scale)
            line:SetColorTexture(T.accent.r, T.accent.g, T.accent.b, p.walk and WALK_ALPHA or LEG_ALPHA)
            line:Show()
        end
        last = u and { u, v } or nil
    end
    for i = n + 1, #self.lines do self.lines[i]:Hide() end
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
    Collect(journey)
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
