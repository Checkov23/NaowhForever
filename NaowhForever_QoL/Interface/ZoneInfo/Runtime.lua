-- Runtime.lua: Zone Info's lazy map provider, pinned selection, current-zone events and HUD mover.
local ns = _G.NaowhForever
local Z = ns.ZoneInfo
local S = ns.QoLSettings
local INTERVAL, BUTTON_W, BUTTON_H, MAP_INSET, BUTTON_BOTTOM = 0.08, 100, 24, 12, 42
local SAMPLE_MAP = 1436
local PAGE, CARD = "QoL/Map & Pins", "QoL/Map & Pins:zoneInfo"
local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }
local TEXT_ZONE_INFO = ns.L("Zone Info")
local TEXT_PIN = ns.L("Pin a hovered zone, or your current zone, for more details.")
local events, provider, tick, mapButton, hud
local elapsedTotal, lastX, lastY, lastMap, hovered = 0, nil, nil, nil, nil
local added, unlockHooks, unlocked, journalWatch = false, false, false, false

function Z.Enabled()
    return S.Get("enabled") and S.Get("zoneInfo") == true
end

local function MapText()
    if not S.Get("zoneInfoOnMap") then Z.HideMapText(); return end
    if added and WorldMapFrame:IsShown() then
        local mapID = hovered or Z.ZoneMap(provider:GetMap():GetMapID()) or Z.current
        Z.MapText(mapID)
    else Z.HideMapText() end
end

local function ResetHover()
    lastX, lastY, lastMap, hovered = nil, nil, nil, nil
    Z.Hover(nil)
end

local function RefreshHover()
    local current = provider and provider:GetMap() and provider:GetMap():GetMapID()
    if hovered and Z.Plain(current) and lastMap == current and not InCombatLockdown() then
        lastX, lastY = nil, nil
        Z.Hover(hovered)
    else ResetHover() end
end

function Z.Pin(mapID, detached)
    if not Z.Enabled() or InCombatLockdown() then return end
    mapID = Z.ZoneMap(mapID)
    if not mapID then return end
    Z.detached = detached == true
    S.Set("zoneInfoPinned", mapID)
    Z.ShowDetails(detached)
end

local function MapButtonClicked()
    Z.Pin(hovered or Z.ZoneMap(provider:GetMap():GetMapID()) or Z.current, false)
end

local function OnUpdate(_, elapsed)
    if not Z.Enabled() or InCombatLockdown() then ResetHover(); tick:SetScript("OnUpdate", nil); return end
    if Z.HoverFocused() then return end
    local map = provider:GetMap()
    if not map or not map:IsCanvasMouseFocus() then return end
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < INTERVAL then return end
    elapsedTotal = 0
    local x, y = map:GetNormalizedCursorPosition()
    local current = map:GetMapID()
    if not (Z.Plain(x) and Z.Plain(y) and Z.Plain(current)) then return end
    if not x or not y or x < 0 or y < 0 or x > 1 or y > 1 then return end
    if x == lastX and y == lastY and current == lastMap then return end
    lastX, lastY, lastMap = x, y, current
    local info = C_Map.GetMapInfoAtPosition(current, x, y)
    local id = info and Z.Plain(info) and Z.Plain(info.mapID) and info.mapID
    id = Z.ZoneMap(id or current)
    if id and id ~= hovered then hovered = id; Z.Hover(id); MapText() end
end

local function AddMap()
    if added or not (WorldMapFrame and MapCanvasDataProviderMixin) then return end
    if not provider then
        provider = CreateFromMixins(MapCanvasDataProviderMixin)
        function provider:OnAdded(map)
            MapCanvasDataProviderMixin.OnAdded(self, map)
            if not tick then
                tick = CreateFrame("Frame", nil, map:GetCanvasContainer())
                tick:SetSize(1, 1)
                tick:SetPoint("TOPLEFT")
                tick:Hide()
                mapButton = ns.Button(map:GetCanvasContainer(), TEXT_ZONE_INFO, BUTTON_W, BUTTON_H, MapButtonClicked)
                mapButton:SetPoint("BOTTOMLEFT", MAP_INSET, BUTTON_BOTTOM)
                ns.Tooltip(mapButton, TEXT_ZONE_INFO, TEXT_PIN)
            end
        end
        function provider:OnShow()
            ResetHover()
            tick:SetScript("OnUpdate", not InCombatLockdown() and OnUpdate or nil)
            tick:Show()
            mapButton:SetShown(not S.Get("zoneInfoOnMap"))
            mapButton:SetEnabled(not InCombatLockdown())
            Z.ShowDetails(false)
            MapText()
        end
        function provider:OnHide()
            tick:SetScript("OnUpdate", nil)
            tick:Hide()
            mapButton:Hide()
            ResetHover()
            Z.HideMap()
        end
        function provider:RemoveAllData() self:OnHide() end
        function provider:RefreshAllData()
            RefreshHover()
            if Z.Enabled() and self:GetMap():IsShown() then Z.ShowDetails(false); MapText() end
        end
    end
    WorldMapFrame:AddDataProvider(provider)
    added = true
    if WorldMapFrame:IsShown() then provider:OnShow() else provider:OnHide() end
end

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint()
    S.Set("zoneInfoPos", { point = point, relPoint = relativePoint, x = x, y = y })
end

local function ApplyHUD()
    if not S.Get("zoneInfoCurrent") then
        if hud then hud:Hide(); hud.mover:Hide() end
        return
    end
    if not hud then
        hud = Z.HUD()
        hud:SetMovable(true)
        hud:SetClampedToScreen(true)
        hud.mover = ns.UI.AttachMover(hud, TEXT_ZONE_INFO, SavePosition, PAGE, CARD)
    end
    local pos = S.Get("zoneInfoPos")
    hud:ClearAllPoints()
    hud:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    hud:SetScale(ns.UIScale() * S.Get("zoneInfoScale"))
    local shown = unlocked or Z.current ~= nil and not (S.Get("zoneInfoHideCombat") and InCombatLockdown())
    hud:SetShown(shown and true or false)
    hud.mover:SetShown(unlocked and true or false)
    if shown then Z.PaintHUD(hud, Z.current or SAMPLE_MAP) end
end

local function RefreshCharacter()
    if not InCombatLockdown() then
        Z.Character()
        local id = C_Map.GetBestMapForUnit("player")
        Z.current = Z.Plain(id) and Z.ZoneMap(id) or nil
    end
    ApplyHUD()
    Z.RefreshPanels()
    RefreshHover()
    MapText()
end

local function JournalChanged()
    if Z.Enabled() then Z.RefreshPanels(); MapText() end
end

local function WatchJournal()
    local J = ns.Journal
    if journalWatch or not (J and J.Settings and J.Settings.OnChange) then return end
    J.Settings.OnChange(JournalChanged)
    journalWatch = true
end

local function OnEvent(_, event, addon)
    if event == "ADDON_LOADED" then
        if addon ~= "Blizzard_WorldMap" and addon ~= "NaowhForever_DungeonJournal" then return end
        AddMap()
        WatchJournal()
    end
    RefreshCharacter()
    if event == "PLAYER_LEVEL_UP" and Z.Plain(addon) and type(addon) == "number" then
        Z.level = addon
        Z.RefreshPanels()
        MapText()
    end
    if added and WorldMapFrame:IsShown() then
        tick:SetScript("OnUpdate", not InCombatLockdown() and OnUpdate or nil)
        mapButton:SetEnabled(not InCombatLockdown())
    end
end

local function UnlockShown()
    if not Z.Enabled() then return end
    unlocked = S.Get("zoneInfoCurrent") == true
    ApplyHUD()
end

local function UnlockHidden()
    unlocked = false
    if Z.Enabled() then ApplyHUD() end
end

function Z.Apply()
    if not Z.Enabled() then
        if events then events:UnregisterAllEvents() end
        if added then WorldMapFrame:RemoveDataProvider(provider); added = false end
        Z.HideAll()
        unlocked = false
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if not unlockHooks then
        hooksecurefunc(ns, "ShowUnlockMode", UnlockShown)
        hooksecurefunc(ns, "HideUnlockMode", UnlockHidden)
        unlockHooks = true
    end
    AddMap()
    WatchJournal()
    RefreshCharacter()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        Z.ShowDetails(false)
        mapButton:SetShown(not S.Get("zoneInfoOnMap"))
        MapText()
    end
end

local function OnSetting(key)
    if key == "zoneInfoPos" then return end
    if key == "enabled" or key:find("^zoneInfo") then Z.Apply() end
end
S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Z.Apply)
Z.Apply()
