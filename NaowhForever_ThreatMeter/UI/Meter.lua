-- Meter.lua: the Threat Meter window: drag, resize, scroll, and its updates while the threat moves.
local ns = _G.NaowhForever

local UI = ns.UI
local TM = ns.ThreatMeter
local S = TM.Settings
local C, Look = TM.C, TM.Look
local list, Readable = TM.list, TM.Readable

local UPDATE_DELAY = 0.2
local FOLLOW_INTERVAL = 0.5
local PREVIEW_SECONDS = 10
local INSET, FOOTER = C.INSET, C.FOOTER
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = C.MIN_WIDTH, C.MIN_HEIGHT, C.MAX_WIDTH, C.MAX_HEIGHT
local MIN_BAR, MAX_BAR, MAX_SPACING, MIN_FONT, MAX_FONT = C.MIN_BAR, C.MAX_BAR, C.MAX_SPACING, C.MIN_FONT, C.MAX_FONT
local SOURCE_W, SMALL_W, BUTTON_H = 58, 22, 18
local SOURCE_X, SOURCE_Y, LOCK_X, SETTINGS_X, BUTTON_Y = -8, -5, -34, -8, 5
local GRIP_SIZE, GRIP_INSET, GRIP_LEVEL, GRIP_LOCKED_ALPHA = 20, 2, 20, 0.4
local HOME_X, HOME_Y = 400, -100
local ROUND = C.ROUND
local GRIP_UP, GRIP_HIGHLIGHT, GRIP_DOWN = C.GRIP_UP, C.GRIP_HIGHLIGHT, C.GRIP_DOWN
local CARD = C.PAGE .. ":meter"
local THREAT_EVENTS = { "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }
local SWITCHED = { PLAYER_TARGET_CHANGED = "target", PLAYER_FOCUS_CHANGED = "focus" }

local TEXT_TARGET, TEXT_FOCUS = ns.L("Target"), ns.L("Focus")
local TEXT_LOCKED, TEXT_UNLOCKED = "L", "U"
local TEXT_PREVIEW = ns.L("PREVIEW")
local TEXT_NO_TARGET = ns.L("No target")
local TEXT_MOVER = "Threat Meter"
local TEXT_OFF = ns.L("Enable Threat Meter first.")
local TEXT_IN_COMBAT = ns.L("Preview is available outside combat.")

local frame, pendingUpdate, followTicker, unlocked
local renderedTitle, renderedPlayer
local offset, currentMob, mobGUID, preview = 0, nil, nil, false
local updateGeneration = 0
local previewGeneration = 0
local listening = false
local events = CreateFrame("Frame")
local Update

local function ResizeMetrics()
    local start = frame.resizeStart
    if not start then return S.Get("barHeight"), S.Get("barSpacing"), S.Get("fontSize") end
    local chrome = Look.HeaderHeight() + FOOTER + 2 * INSET
    local ratio = math.max(1, frame:GetHeight() - chrome) / start.contentHeight
    local textRatio = math.min(ratio, frame:GetWidth() / start.width)
    return math.max(MIN_BAR, math.min(MAX_BAR, start.barHeight * ratio)),
        math.max(0, math.min(MAX_SPACING, start.spacing * ratio)),
        math.max(MIN_FONT, math.min(MAX_FONT, start.fontSize * textRatio))
end

local function Layout()
    local bh, gap, fontSize = S.Get("barHeight"), S.Get("barSpacing"), S.Get("fontSize")
    if frame.sizing then bh, gap, fontSize = ResizeMetrics() end
    frame:SetResizeBounds(MIN_WIDTH, math.max(MIN_HEIGHT, Look.HeaderHeight() + FOOTER + 2 * INSET + bh), MAX_WIDTH, MAX_HEIGHT)
    local shown
    shown, offset = Look.Layout(frame, math.min(#list, S.Get("maxBars")), offset, bh, gap, fontSize)
    frame.source.label:SetText(TM.Watched() == "focus" and TEXT_FOCUS or TEXT_TARGET)
    frame.source:SetShown(S.Get("focusEnabled"))
    frame.lock.label:SetText(S.Get("locked") and TEXT_LOCKED or TEXT_UNLOCKED)
    local statusTop = S.Get("statusPos") == "top"
    frame.grip:SetShown(not unlocked and not (statusTop and S.Get("locked")))
    frame.grip:SetAlpha(S.Get("locked") and GRIP_LOCKED_ALPHA or 1)
    return shown
end

local function Render(title, me)
    renderedTitle, renderedPlayer = title, me
    local shown = Layout()
    Look.Paint(frame, list, offset, shown, title, (preview or unlocked) and TEXT_PREVIEW or Look.State(me))
end

local function RenderSample()
    local sample = TM.SAMPLES.pulling
    TM.FillSample(sample, list, TM.entries)
    Render(sample.title)
end

local function Place()
    local pos = S.Get("threatPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", HOME_X, HOME_Y)
    end
end

local function SavePosition()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = frame:GetLeft() * scale, frame:GetTop() * scale - UIParent:GetHeight()
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    S.Set("threatPos", { point = "TOPLEFT", relPoint = "TOPLEFT", x = x, y = y })
end

local function SwitchSource()
    S.Set("source", TM.Watched() == "focus" and "target" or "focus")
end

local function ToggleLock()
    S.Set("locked", not S.Get("locked"))
end

local function OpenSettings()
    ns.OpenOptionsWindow(TEXT_MOVER)
end

local function OnDragStart()
    if not S.Get("locked") and not unlocked and not InCombatLockdown() then frame.moving = true; frame:StartMoving() end
end

local function OnDragStop()
    if frame.moving then frame:StopMovingOrSizing(); frame.moving = false; SavePosition() end
end

local function OnGripDown(_, button)
    if button ~= "LeftButton" or S.Get("locked") or unlocked or InCombatLockdown() then return end
    SavePosition()
    frame.resizeStart = { contentHeight = math.max(1, frame:GetHeight() - Look.HeaderHeight() - FOOTER - 2 * INSET),
        width = frame:GetWidth(), barHeight = S.Get("barHeight"), spacing = S.Get("barSpacing"), fontSize = S.Get("fontSize") }
    frame.sizing = true; frame:StartSizing("BOTTOMRIGHT")
end

local function OnGripUp()
    if not frame.sizing then return end
    local bh, gap, fontSize = ResizeMetrics()
    local width, height = frame:GetWidth(), frame:GetHeight()
    frame:StopMovingOrSizing(); frame.sizing = false; frame.resizeStart = nil
    S.Set("barHeight", bh); S.Set("barSpacing", gap); S.Set("fontSize", fontSize)
    S.Set("width", math.floor(width + ROUND)); S.Set("height", math.floor(height + ROUND))
    SavePosition(); Update()
end

local function OnSizeChanged()
    if frame.sizing then Render(renderedTitle, renderedPlayer) end
end

local function OnHide()
    if frame.moving or frame.sizing then
        frame:StopMovingOrSizing(); frame.moving, frame.sizing = false, false
    end
end

local function OnWheel(_, delta)
    offset = math.max(0, offset - delta)
    Update()
end

local function SaveMoved(pos)
    S.Set("threatPos", pos)
end

local function NewButtons()
    frame.source = ns.Button(frame.header, TEXT_TARGET, SOURCE_W, BUTTON_H, SwitchSource)
    frame.source:SetPoint("TOPRIGHT", SOURCE_X, SOURCE_Y)
    ns.Tooltip(frame.source, ns.L("Threat Source"), ns.L("Click to switch between your target and focus."))
    frame.lock = ns.Button(frame.header, TEXT_LOCKED, SMALL_W, BUTTON_H, ToggleLock)
    frame.lock:SetPoint("BOTTOMRIGHT", LOCK_X, BUTTON_Y)
    ns.Tooltip(frame.lock, ns.L("Window Lock"), ns.L("Unlock to drag the header and resize with the bottom-right grip."))
    local settings = ns.Button(frame.header, "...", SMALL_W, BUTTON_H, OpenSettings)
    settings:SetPoint("BOTTOMRIGHT", SETTINGS_X, BUTTON_Y)
    ns.Tooltip(settings, ns.L("Threat Meter Settings"))
end

local function NewGrip()
    frame.grip = CreateFrame("Button", nil, frame)
    frame.grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    frame.grip:SetPoint("BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
    frame.grip:SetFrameLevel(frame:GetFrameLevel() + GRIP_LEVEL)
    frame.grip:SetNormalTexture(GRIP_UP)
    frame.grip:SetHighlightTexture(GRIP_HIGHLIGHT)
    frame.grip:SetPushedTexture(GRIP_DOWN)
    ns.Tooltip(frame.grip, ns.L("Resize Threat Meter"), ns.L("Drag to resize. Turn off Lock Window first; resizing is available outside combat."))
    frame.grip:SetScript("OnMouseDown", OnGripDown)
    frame.grip:SetScript("OnMouseUp", OnGripUp)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverThreatMeter", UIParent)
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    Look.New(frame)
    NewButtons()
    frame.header:EnableMouse(true); frame.header:RegisterForDrag("LeftButton")
    frame.header:SetScript("OnDragStart", OnDragStart)
    frame.header:SetScript("OnDragStop", OnDragStop)
    NewGrip()
    frame:SetScript("OnSizeChanged", OnSizeChanged)
    ns.AllowOffscreen(frame)
    frame:SetScript("OnHide", OnHide)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", OnWheel)
    frame.mover = UI.AttachMover(frame, TEXT_MOVER, SaveMoved, C.PAGE, CARD)
    frame:Hide(); Place()
end

local function SetFollow(on)
    if on and not followTicker then
        followTicker = C_Timer.NewTicker(FOLLOW_INTERVAL, function() Update() end)
    elseif not on and followTicker then
        followTicker:Cancel()
        followTicker = nil
    end
end

local function ListenForThreat(on)
    if on == listening then return end
    listening = on
    for _, event in ipairs(THREAT_EVENTS) do
        if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
end

local function Hide()
    SetFollow(false)
    frame:Hide()
end

function Update()
    pendingUpdate = false
    if not frame then return end
    if not TM.On() then return Hide() end
    local sample = unlocked or preview
    local mob = not sample and TM.ThreatMob() or nil
    currentMob = mob
    ListenForThreat(mob ~= nil)
    if sample then SetFollow(false); RenderSample(); frame:Show(); return end
    local guid = mob and UnitGUID(mob)
    if Readable(guid) and guid ~= mobGUID then mobGUID, offset = guid, 0; TM.Rearm() end
    local fighting = mob and UnitAffectingCombat(mob)
    local combat = InCombatLockdown() or Readable(fighting) and fighting
    local mode = S.Get("visibility")
    if mode == "combat" and not combat or mode == "group" and not IsInGroup() then return Hide() end
    SetFollow(mob ~= nil and mob ~= TM.Watched() and combat)
    local me
    if mob then me = TM.Collect(mob) else TM.Clear() end
    if #list > 0 then
        TM.Warn(me)
    else
        TM.Rearm()
        if mode == "threat" then frame:Hide(); return end
    end
    Render(mob and UnitName(mob) or TEXT_NO_TARGET, me)
    frame:Show()
end

local function RequestUpdate()
    if pendingUpdate or not TM.On() then return end
    pendingUpdate = true
    local generation = updateGeneration
    C_Timer.After(UPDATE_DELAY, function() if generation == updateGeneration then Update() end end)
end

local function StopSizing()
    if frame and (frame.sizing or frame.moving) then frame:StopMovingOrSizing(); frame.sizing, frame.moving = false, false end
end

local function OnEvent(_, event, unit)
    if SWITCHED[event] then
        if SWITCHED[event] ~= TM.Watched() then return end
        mobGUID, offset = nil, 0
        TM.Rearm()
    elseif event == "PLAYER_REGEN_DISABLED" then
        preview = false
        StopSizing()
    elseif event == "UNIT_THREAT_LIST_UPDATE" then
        if not (currentMob and Readable(unit)) then return end
        local same = UnitIsUnit(unit, currentMob)
        if Readable(same) and not same then return end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_PET" then
        if not (Readable(unit) and TM.IN_GROUP[unit]) then return end
    end
    RequestUpdate()
end

local function Listen()
    events:RegisterEvent("PLAYER_FOCUS_CHANGED")
    events:RegisterEvent("UNIT_PET")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterUnitEvent("UNIT_FLAGS", "target", "focus", "pet")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function Apply()
    TM.Migrate()
    TM.Rewatch()
    events:UnregisterAllEvents()
    listening = false
    updateGeneration = updateGeneration + 1; pendingUpdate = false
    if not (TM.On() or unlocked) then
        SetFollow(false)
        TM.Rearm()
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Place()
    frame.mover:SetShown(unlocked == true)
    if TM.On() then Listen() end
    Update()
end

local function EndPreview(generation)
    if generation ~= previewGeneration then return end
    preview = false
    Update()
end

function ns.PreviewThreatMeter()
    if not TM.On() then ns.Print(TEXT_OFF) return end
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT) return end
    previewGeneration = previewGeneration + 1
    local generation = previewGeneration
    preview = true
    Update()
    C_Timer.After(PREVIEW_SECONDS, function() EndPreview(generation) end)
end

local function OnSet(key)
    if key == "threatPos" then return end
    if key == "source" or key == "focusEnabled" then
        TM.Rewatch()
        offset, mobGUID = 0, nil
        TM.Rearm()
    end
    if key == "enabled" then
        previewGeneration = previewGeneration + 1
        preview = false
        Apply()
    else
        RequestUpdate()
    end
end

local function OnUnlock()
    unlocked = TM.On() == true
    Apply()
end

local function OnLock()
    unlocked = false
    if frame then Apply() end
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
