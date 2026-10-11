-- MapOverlay.lua: a dungeon's map over the world map's picture while you are inside it, with its floor switch.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Map = J.DungeonMap
local C = J.C
local St = J.Style
local TEXT_SIZE, BLACK = St.TEXT_SIZE, St.OVERLAY_RGB

local OVERLAY_LEVEL = 50
local BAR_LEVEL = 20
local HINT_PAD = 10
local BAR_H = 28
local BAR_ALPHA = 0.55
local MIN_SCALE = 0.1

local TEXT_UP = ns.L("Right-click: ")

local overlay, overlayView

local function UpToZone()
    overlay:Hide()
    local entrance = overlayView.dungeon.entrance
    if entrance and not InCombatLockdown() then C_Map.OpenWorldMap(entrance.map) end
end

local function OverlayClicked(_, button)
    if button == "RightButton" then UpToZone() end
end

local function SwallowWheel() end

local function OverlayHidden()
    Map.ViewHidden(overlayView)
end

local function Fit()
    local w, h = overlay:GetWidth(), overlay:GetHeight()
    local scale = math.max(MIN_SCALE, math.min(w / C.MAP_W, h / C.MAP_H))
    overlayView.scale = scale
    overlayView.canvas:SetScale(scale)
    overlayView.canvas:ClearAllPoints()
    overlayView.canvas:SetPoint("CENTER", overlay, "CENTER", 0, 0)
end

local function BuildBar()
    local bar = CreateFrame("Frame", nil, overlay)
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetHeight(BAR_H)
    ns.Solid(bar, "BACKGROUND", BLACK, BAR_ALPHA):SetAllPoints()
    return bar
end

local function BuildOverlay()
    local map = WorldMapFrame
    local picture = type(map.ScrollContainer) == "table" and map.ScrollContainer or map
    overlay = CreateFrame("Frame", nil, map)
    overlay:SetAllPoints(picture)
    overlay:SetFrameLevel(picture:GetFrameLevel() + OVERLAY_LEVEL)
    overlay:EnableMouse(true)
    overlay:EnableMouseWheel(true)
    overlay:SetScript("OnMouseUp", OverlayClicked)
    overlay:SetScript("OnMouseWheel", SwallowWheel)
    ns.Solid(overlay, "BACKGROUND", BLACK, 1):SetAllPoints()
    local bar = BuildBar()
    overlayView = Map.NewView(overlay, bar, false)
    bar:SetFrameLevel(overlayView.canvas:GetFrameLevel() + BAR_LEVEL)
    overlay:SetScript("OnHide", OverlayHidden)
    overlayView.onRightClick = UpToZone
    overlayView.onWorldMap = true
    overlayView.down:SetPoint("LEFT", HINT_PAD, 0)
    overlay.hint = ns.Font(bar, TEXT_SIZE, nil, T.fg)
    overlay.hint:SetPoint("RIGHT", -HINT_PAD, 0)
end

local function OnSettingChanged(key)
    if key == "enabled" and not S.Get("enabled") and overlay then overlay:Hide() end
end

function J.ShowMapOnWorldMap(dungeon)
    if not (dungeon and J.Maps[dungeon.key]) then
        if overlay then overlay:Hide() end
        return
    end
    if not overlay then BuildOverlay() end
    local same = overlay:IsShown() and overlayView.dungeon == dungeon
    local keep, floor = same and overlayView.picked or nil, same and overlayView.floor or nil
    overlayView:Open(dungeon)
    overlayView.picked = keep
    if floor and overlayView:FloorAt(floor) then overlayView.floor = floor end
    overlay.hint:SetText(dungeon.entrance and dungeon.zone and (TEXT_UP .. dungeon.zone) or "")
    overlay:Show()
    overlay.mapID = WorldMapFrame:GetMapID()
    Fit()
    overlayView:Draw()
end

function J.WorldMapChanged()
    if overlay and overlay:IsShown() and WorldMapFrame:GetMapID() ~= overlay.mapID then overlay:Hide() end
end

function J.DungeonMapAway()
    return overlay ~= nil and not overlay:IsShown() and WorldMapFrame:IsShown()
end

function J.RedrawDungeonMaps()
    J.DrawDungeonMap()
    if overlay and overlay:IsShown() then overlayView:Draw() end
end

function J.View.ForgetMapLoot()
    local from = Map.lootFrom
    if from and not from.onWorldMap then from:Pick(nil) end
    Map.lootFrom = nil
end

function J.UnpickOnWorldMap()
    if overlayView then overlayView:Pick(nil) end
end

function J.FitMapOnWorldMap()
    if overlayView and Map.lootFrom == overlayView and not WorldMapFrame:IsMaximized() then
        Map.lootFrom = nil
        J.View.CloseBossLoot()
    end
    if overlay and overlay:IsShown() then
        Fit()
        overlayView:Draw()
    end
end

S.OnChange(OnSettingChanged)
