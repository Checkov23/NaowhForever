-- BagTracker.lua: the Sleeping Bag tracker: each step of the chain with a waypoint, the one to do now in full.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local Bag = Discovery.Bag
local L = Discovery.Library
local Style = Discovery.Style
local Parts = ns.Shared.Parts

local SETTINGS_PAGE = "Discovery/Sleeping Bag"
local PLACE = { "RIGHT", "RIGHT", -260, 120 }
local EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }
local TEXT_TITLE = ns.L("SLEEPING BAG")
local TEXT_NAME = "Sleeping Bag"
local TEXT_STEPS = ns.L("%d / %d  steps")
local TEXT_STEP = "%d. %s"

local panel, events, refreshQueued, dismissedZone
local entries = {}

local function On()
    return S.Get("enabled") and S.Get("bagTracker")
end

local function Opacity()
    return S.Get("bagTrackerAlpha") or 1
end

local function LoadPosition()
    local pos = S.Get("bagTrackerPos")
    if type(pos) == "table" then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("bagTrackerPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Mover(frame, onMoved)
    return ns.UI.AttachMover(frame, TEXT_NAME, onMoved, SETTINGS_PAGE, SETTINGS_PAGE .. ":bagtracker")
end

local function Close()
    dismissedZone = L.PlayerZone()
    panel:Hide()
end

local function OpenSteps()
    ns.OpenDiscoveryWindow("bag")
end

local function StepWaypoint(entry)
    Bag.Waypoint(entry.step)
end

local function StepTip(row)
    local step, m = row.entry.step, T.muted
    GameTooltip:SetText(Bag.Name(step), 1, 1, 1)
    GameTooltip:AddLine(Bag.Where(step), m.r, m.g, m.b, true)
    if step.tip then GameTooltip:AddLine(step.tip, 1, 1, 1, true) end
end

local function BuildPanel()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        onTitle = OpenSteps, titleTip = TEXT_NAME,
        titleHint = ns.L("Click to see every step in the Discovery window."),
        onClose = Close,
        bar = true,
        settings = { page = SETTINGS_PAGE, card = "bagtracker", tip = ns.L("Sleeping Bag settings"),
            hint = ns.L("Opens the Sleeping Bag tracker's settings.") },
        opacity = Opacity,
        load = LoadPosition, save = SavePosition, place = PLACE,
        mover = Mover,
    })
    panel:SetScale(S.Get("bagTrackerScale"))
    panel:Place()
    panel:Paint()
    panel:Hide()
end

local function RenderBar(done, n)
    local bar = panel.bar
    bar:SetMinMaxValues(0, n)
    bar:SetValue(done)
    bar:SetStatusBarColor(T.accent.r, T.accent.g, T.accent.b, Style.BAR_ALPHA)
    bar.text:SetText(TEXT_STEPS:format(done, n))
end

local function Fill(i, step, done, at)
    local entry = entries[i] or {}
    entries[i] = entry
    local isDone, isNow = i <= done, i == at
    entry.step, entry.done = step, isDone
    entry.text = TEXT_STEP:format(i, Bag.Name(step))
    entry.color = not isNow and T.muted or nil
    entry.sub = not isDone and Bag.Sub(step, isNow) or nil
    entry.waypoint, entry.tip = StepWaypoint, StepTip
end

local function Render()
    local steps = Bag.Steps()
    local _, at = Bag.Current()
    local n = #steps
    local done = (at or n + 1) - 1
    RenderBar(done, n)
    for i, step in ipairs(steps) do Fill(i, step, done, at) end
    for i = n + 1, #entries do entries[i] = nil end
    panel:Fit(panel:SetRows(entries))
end

local function Refresh()
    local zone = L.PlayerZone()
    if zone and zone ~= dismissedZone then dismissedZone = nil end
    local show = On() and not dismissedZone and Bag.Level() and Bag.Current() ~= nil
    if not show then
        if panel then panel:Hide() end
        return
    end
    if not panel then BuildPanel() end
    Render()
    panel:Show()
end

local function QueuedRefresh()
    refreshQueued = false
    Refresh()
end

local function OnEvent()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(C.REFRESH_DELAY, QueuedRefresh)
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    elseif events then
        events:UnregisterAllEvents()
    end
    Refresh()
end

local function OnSet(key, value)
    if key == "bagTrackerScale" and panel then panel:SetScale(value) end
    if key == "bagTrackerAlpha" and panel then panel:Paint() end
    if key == "bagTracker" then dismissedZone = nil end
    if key == "enabled" or key == "bagTracker" then Apply() end
end

local function ShowMover()
    if not On() then return end
    if not panel then BuildPanel() end
    Render()
    panel.mover:Show()
    panel:Show()
end

local function HideMover()
    if not panel then return end
    panel.mover:Hide()
    Refresh()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", ShowMover)
hooksecurefunc(ns, "HideUnlockMode", HideMover)
