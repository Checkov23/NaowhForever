-- Cutout.lua: the hole in the effect where your character stands, so the effect passes behind you (G.Cutout).
local ns = _G.NaowhForever

local G = ns.Glimmer
local S = G.Settings
local St = G.Style
local Effects = G.Effects
local Plain = G.Plain

local CUTOUT = St.MEDIA .. "cutout"
local EDGE = St.MEDIA .. "cutout_edge"
local WRAP = "CLAMP"
local TEXT_SHOW, TEXT_HIDE = "Show", "Hide"

local Cutout = {}
G.Cutout = Cutout

local edge
local edgeRun = 0

local function Geometry()
    local h = UIParent:GetHeight()
    return h * St.CUTOUT_SHARE * S.Get("cutoutSize"), h * (St.CUTOUT_Y + S.Get("cutoutHeight"))
end

function Cutout.Place(fx)
    if not S.Get("cutout") then return Effects.Mask(fx, nil) end
    local scale = fx:GetEffectiveScale()
    if not (Plain(scale) and scale > 0) then return Effects.Mask(fx, nil) end
    if not fx.cutout then
        fx.cutout = fx:CreateMaskTexture()
        fx.cutout:SetTexture(CUTOUT, WRAP, WRAP)
    end
    local k = UIParent:GetEffectiveScale() / scale
    local side, y = Geometry()
    fx.cutout:ClearAllPoints()
    fx.cutout:SetPoint("CENTER", UIParent, "CENTER", 0, y * k)
    fx.cutout:SetSize(side * k, side * k)
    Effects.Mask(fx, fx.cutout)
end

local function Refresh()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function HideEdge()
    edgeRun = edgeRun + 1
    edge:Hide()
end

function Cutout.EdgeShown()
    return edge ~= nil and edge:IsShown()
end

function Cutout.EdgeText()
    return Cutout.EdgeShown() and TEXT_HIDE or TEXT_SHOW
end

function Cutout.ToggleEdge()
    if Cutout.EdgeShown() then return HideEdge() end
    if not edge then
        edge = CreateFrame("Frame", nil, UIParent)
        edge:SetFrameStrata("HIGH")
        edge.line = edge:CreateTexture(nil, "OVERLAY")
        edge.line:SetAllPoints()
        edge.line:SetTexture(EDGE)
        local c = St.CUTOUT_EDGE_RGB
        edge.line:SetVertexColor(c.r, c.g, c.b)
    end
    local side, y = Geometry()
    edge:ClearAllPoints()
    edge:SetPoint("CENTER", UIParent, "CENTER", 0, y)
    edge:SetSize(side, side)
    edge:Show()
    edgeRun = edgeRun + 1
    local run = edgeRun
    C_Timer.After(St.CUTOUT_EDGE_TIME, function()
        if run ~= edgeRun then return end
        HideEdge()
        Refresh()
    end)
end
