-- MapSize.lua: the QoL map window: the windowed world map scaled by a corner grip and moved by its title bar.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local PERCENT = ns.QoLConstants.PERCENT
local ROUND = ns.QoLConstants.ROUND
local MIN_PCT, MAX_PCT, STEP_PCT = 50, 150, 5
local SAME_SCALE = 0.001
local GRIP_SIZE = 16
local GRIP_INSET = 3
local GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
local GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
local TITLE_HEIGHT = 22
local TITLE_BUTTONS = 80
local HANDLE_LEVEL = 80
local KEEP_ON_SCREEN = 60

local TEXT_TITLE = "Map Window"
local TEXT_TIP = ns.L("Drag to make the map bigger or smaller.\nRight-click: back to 100%.")

local grip, handle
local hooked, applied
local startDist, startPct
local moveX, moveY, cursorX, cursorY
local home

local function On()
    local eui = _G.EllesmereUIDB
    return S.Get("enabled") and not (eui and eui.shifterEnabled)
end

local function Wanted()
    return On() and (S.Get("mapSizePercent") or PERCENT) / PERCENT or 1
end

local function Saved()
    local pos = On() and S.Get("mapSizePos")
    if type(pos) == "table" and pos.x and pos.y then return pos end
    return nil
end

local function Full()
    local map = WorldMapFrame
    return map.IsMaximized and map:IsMaximized()
end

local function PlaceAt(x, y, scale)
    local map = WorldMapFrame
    map:ClearAllPoints()
    map:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function SetMapScale(scale)
    local map = WorldMapFrame
    local old = map:GetScale()
    if math.abs(old - scale) < SAME_SCALE then return end
    local point, relative, relPoint, x, y = map:GetPoint(1)
    map:SetScale(scale)
    if point == "TOPLEFT" and map:GetNumPoints() == 1 then
        map:ClearAllPoints()
        map:SetPoint(point, relative, relPoint, (x or 0) * old / scale, (y or 0) * old / scale)
    end
end

local function GoHome()
    local map = WorldMapFrame
    if not home then return end
    local scale = map:GetScale()
    map:ClearAllPoints()
    map:SetPoint(home[1], home[2], home[3], home[4] * home[6] / scale, home[5] * home[6] / scale)
end

local function NoteHome()
    local map = WorldMapFrame
    if Full() or map:GetNumPoints() ~= 1 then return end
    local point, relative, relPoint, x, y = map:GetPoint(1)
    home = { point, relative, relPoint, x or 0, y or 0, map:GetScale() }
end

local function Apply()
    local map = WorldMapFrame
    if not map then return end
    if ns.GamepadOwnsPanels() then
        if grip then grip:Hide() end
        if handle then handle:Hide() end
        return
    end
    local on = On()
    if not (on or applied) then return end
    if on and not applied and map:IsShown() then NoteHome() end
    applied = on
    local full = Full()
    local scale = full and 1 or Wanted()
    SetMapScale(scale)
    local pos = not full and Saved()
    if pos then
        PlaceAt(pos.x, pos.y, scale)
    elseif not full then
        GoHome()
    end
    if grip then grip:SetShown(On() and not full) end
    if handle then handle:SetShown(On() and not full) end
end

local function CursorDistance(map)
    local x, y = GetCursorPosition()
    local s = map:GetEffectiveScale()
    local left, top = map:GetLeft(), map:GetTop()
    if not (left and top) then return nil end
    local dx, dy = x - left * s, top * s - y
    return math.sqrt(dx * dx + dy * dy)
end

local function Snap(pct)
    pct = math.floor(pct / STEP_PCT + ROUND) * STEP_PCT
    return math.max(MIN_PCT, math.min(MAX_PCT, pct))
end

local function Drag()
    local dist = CursorDistance(WorldMapFrame)
    if not dist or not startDist or startDist <= 0 then return end
    SetMapScale(Snap(startPct * dist / startDist) / PERCENT)
end

local function OnGripDown(_, button)
    if button ~= "LeftButton" then return end
    startDist, startPct = CursorDistance(WorldMapFrame), S.Get("mapSizePercent") or PERCENT
    grip:SetScript("OnUpdate", Drag)
end

local function OnGripUp(_, button)
    if button ~= "LeftButton" or not startDist then return end
    grip:SetScript("OnUpdate", nil)
    startDist = nil
    S.Set("mapSizePercent", Snap(WorldMapFrame:GetScale() * PERCENT))
end

local function OnGripHide()
    if startDist then OnGripUp(grip, "LeftButton") end
end

local function OnGripClick()
    S.Set("mapSizePercent", PERCENT)
end

local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

local function Clamp(x, y)
    local map = WorldMapFrame
    local scale = map:GetScale()
    local w = map:GetWidth() * scale
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    x = math.max(KEEP_ON_SCREEN - w, math.min(screenW - KEEP_ON_SCREEN, x))
    y = math.max(KEEP_ON_SCREEN, math.min(screenH, y))
    return x, y
end

local function Move()
    if not moveX then return end
    local x, y = Cursor()
    local nx, ny = Clamp(moveX + x - cursorX, moveY + y - cursorY)
    PlaceAt(nx, ny, WorldMapFrame:GetScale())
end

local function OnHandleDown(_, button)
    if button ~= "LeftButton" then return end
    local map = WorldMapFrame
    local scale = map:GetScale()
    local left, top = map:GetLeft(), map:GetTop()
    if not (left and top) then return end
    moveX, moveY = left * scale, top * scale
    cursorX, cursorY = Cursor()
    handle:SetScript("OnUpdate", Move)
end

local function OnHandleUp(_, button)
    if button == "RightButton" then
        S.Set("mapSizePos", false)
        GoHome()
        return
    end
    if not moveX then return end
    handle:SetScript("OnUpdate", nil)
    moveX = nil
    local map = WorldMapFrame
    local scale = map:GetScale()
    S.Set("mapSizePos", { x = map:GetLeft() * scale, y = map:GetTop() * scale })
end

local function OnHandleHide()
    if moveX then OnHandleUp(handle, "LeftButton") end
end

local function BuildGrip()
    grip = CreateFrame("Button", nil, WorldMapFrame)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
    grip:SetFrameStrata("DIALOG")
    grip:SetNormalTexture(GRIP_UP)
    grip:SetHighlightTexture(GRIP_HIGHLIGHT)
    grip:SetPushedTexture(GRIP_DOWN)
    grip:RegisterForClicks("RightButtonUp")
    grip:SetScript("OnClick", OnGripClick)
    grip:SetScript("OnMouseDown", OnGripDown)
    grip:SetScript("OnMouseUp", OnGripUp)
    grip:SetScript("OnHide", OnGripHide)
    ns.Tooltip(grip, TEXT_TITLE, TEXT_TIP)
end

local function BuildHandle()
    local map = WorldMapFrame
    handle = CreateFrame("Frame", nil, map)
    handle:SetPoint("TOPLEFT")
    handle:SetPoint("TOPRIGHT", -TITLE_BUTTONS, 0)
    handle:SetHeight(TITLE_HEIGHT)
    handle:SetFrameLevel(map:GetFrameLevel() + HANDLE_LEVEL)
    handle:EnableMouse(true)
    handle:SetScript("OnMouseDown", OnHandleDown)
    handle:SetScript("OnMouseUp", OnHandleUp)
    handle:SetScript("OnHide", OnHandleHide)
end

local function OnPanelsPlaced(frame)
    if not On() then return end
    local map = WorldMapFrame
    if map:IsShown() or frame == map then NoteHome() end
    if map:IsShown() and Saved() then Apply() end
end

local function Setup()
    local map = WorldMapFrame
    if not map then return end
    if On() and not grip then
        BuildGrip()
        BuildHandle()
    end
    if not hooked then
        hooked = true
        if map.Maximize then hooksecurefunc(map, "Maximize", Apply) end
        if map.Minimize then hooksecurefunc(map, "Minimize", Apply) end
        map:HookScript("OnShow", Apply)
        if UpdateUIPanelPositions then hooksecurefunc("UpdateUIPanelPositions", OnPanelsPlaced) end
    end
    Apply()
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Setup()
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "mapSizePercent" or key == "mapSizePos" then Setup() end
end)
hooksecurefunc(ns, "Apply", Setup)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
