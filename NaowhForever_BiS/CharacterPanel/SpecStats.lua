-- SpecStats.lua: the character panel's stats for your spec, and the switch to the game's.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local CP = ns.CharacterPanel
local C = CP.C
local D = CP.Stats
local SW = ns.StatWeights
local Parts = ns.Shared.Parts
local Worth = CP.Worth
local StatRows = CP.StatRows

local SWITCH_W = CP.PANE_W - 2 * CP.EDGE
local SWITCH_H = 26
local GAP = 6
local ROOM = 20
local ROWS = C.STAT_ROWS
local VIEW_LIFT = 10
local SPEC_PICK = "spec"
local EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "COMBAT_RATING_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED" }
local UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE",
    "UNIT_ATTACK_SPEED", "UNIT_RESISTANCES" }
local TEXT_YOUR_STATS = ns.L("YOUR STATS")
local TEXT_WORTH = ns.L("WORTH")
local LABELS = { { key = "spec", label = "Your Spec" }, { key = "all", label = "All Stats" } }

local switch, view, installed
local keys = {}

local function SpecShown()
    return CP.On() and S.Get("characterPanelStats") == SPEC_PICK
end

local function Shown(weights)
    wipe(keys)
    local top = 0
    for _, stat in ipairs(D.ORDER) do
        local weight = weights and weights[stat] or 0
        if D.ALWAYS[stat] or weight > 0 then
            keys[#keys + 1] = stat
            if weight > top then top = weight end
        end
    end
    return top
end

local function Paint()
    local key = SW.ActiveSpec()
    local spec = key and SW.Spec(key)
    local weights = key and SW.For(key)
    local short = Worth.ShortName(spec)
    local yard = Worth.Yardstick(weights)
    view.title:SetText(spec and Worth.Title(short) or TEXT_YOUR_STATS)
    view.head:SetText(D.HEADING[yard] or TEXT_WORTH)
    view.specName, view.yard = short, yard
    view.yardWeight = yard and weights[yard] or Worth.YARD
    local top = Shown(weights)
    StatRows.Lay(view, math.min(#keys, ROWS))
    local hidden = C_Secrets.ShouldUnitStatsBeSecret()
    for i, row in ipairs(view.rows) do
        local stat = keys[i]
        row:SetShown(stat ~= nil)
        if stat then StatRows.Paint(row, stat, weights, top, hidden) end
    end
end

local function OnEvent()
    if view:IsVisible() then Paint() end
end

local function Resized()
    if view:IsVisible() then StatRows.Lay(view, math.min(#keys, ROWS)) end
end

local function WeightsChanged()
    if view:IsVisible() then Paint() end
end

local function PlaceList(drop, lift)
    local stats = CharacterStatsPaneScrollBox
    stats:ClearAllPoints()
    stats:SetPoint("TOPLEFT", CharacterFrameRightPaneHostStoneBg, "BOTTOMLEFT", 0, -drop)
    stats:SetPoint("BOTTOMRIGHT", CharacterFrame.RightPaneHost, "BOTTOMRIGHT", 0, lift)
end

local function Under(badge)
    local cardBottom = badge:GetBottom()
    local stoneBottom = CharacterFrameRightPaneHostStoneBg:GetBottom()
    if not (cardBottom and stoneBottom) then return CP.BADGE_GAP + CP.BADGE_H - ROOM end
    return stoneBottom - cardBottom + CP.BADGE_GAP
end

local function Layout()
    local badge = CP.badge
    local drop = badge ~= nil and badge:IsShown() and Under(badge) or 0
    PlaceList(math.max(0, drop), SWITCH_H + 2 * GAP)
end

local function Listen(spec)
    view:UnregisterAllEvents()
    if not spec then return end
    for _, event in ipairs(EVENTS) do view:RegisterEvent(event) end
    for _, event in ipairs(UNIT_EVENTS) do view:RegisterUnitEvent(event, "player") end
    Paint()
end

local function Show()
    local stats = CharacterStatsPaneScrollBox
    local on = CP.On() and stats:IsShown()
    switch:SetShown(on)
    if CP.On() then Layout() end
    LABELS[1].label = Worth.ShortName(SW.Spec(SW.ActiveSpec() or ""))
    Parts.SetTabs(switch, LABELS)
    Parts.PaintTabs(switch, S.Get("characterPanelStats"))
    local spec = on and SpecShown()
    view:SetShown(spec)
    stats:SetAlpha(spec and 0 or 1)
    Listen(spec)
end

local function Picked(key)
    S.Set("characterPanelStats", key)
end

local function Build()
    local panel, stats = CharacterFrame, CharacterStatsPaneScrollBox
    switch = Parts.Tabs(panel, SWITCH_W, LABELS, Picked)
    switch:SetPoint("BOTTOM", CharacterFrame.RightPaneHost, "BOTTOM", 0, GAP)
    switch:SetFrameLevel(stats:GetFrameLevel() + VIEW_LIFT)
    view = CreateFrame("Frame", nil, panel)
    view:SetAllPoints(stats)
    view:SetFrameLevel(stats:GetFrameLevel() + VIEW_LIFT)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetScript("OnEvent", OnEvent)
    view:SetScript("OnSizeChanged", Resized)
    StatRows.Build(view)
    stats:HookScript("OnShow", Show)
    stats:HookScript("OnHide", Show)
    SW.OnChange(WeightsChanged)
end

local function Apply()
    if CP.On() and not installed and CharacterFrame and CharacterStatsPaneScrollBox then
        installed = true
        Build()
    end
    if not installed then return end
    if CP.On() then return Show() end
    switch:Hide()
    view:Hide()
    view:UnregisterAllEvents()
    CharacterStatsPaneScrollBox:SetAlpha(1)
    PlaceList(0, 0)
end

local function OnSetting(key)
    if key == "enabled" or key:find("^characterPanel") then Apply() end
end

CP.ShowSpecStats = Show

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
