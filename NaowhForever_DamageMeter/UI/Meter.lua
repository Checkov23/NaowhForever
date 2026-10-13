-- Meter.lua: the Damage Meter windows: drag, resize, scroll, their buttons and their updates.
local ns = _G.NaowhForever

local UI = ns.UI
local DM = ns.DamageMeter
local S = DM.Settings
local C, Look, Key, Menus, Breakdown = DM.C, DM.Look, DM.Key, DM.Menus, DM.Breakdown

local UPDATE_DELAY = 0.25
local PREVIEW_SECONDS = 10
local INSET, HEADER, ROUND = C.INSET, C.HEADER, C.ROUND
local MIN_WIDTH, MAX_WIDTH, MAX_HEIGHT = C.MIN_WIDTH, C.MAX_WIDTH, C.MAX_HEIGHT
local BUTTON_H, MORE_W, SESSION_W, BUTTON_GAP, BUTTON_RIGHT = 18, 22, 62, 4, -6
local TITLE_X = C.TITLE_X
local TITLE_JOIN = " - "
local TIME_BRACKETS = "(%s)"
local BAR_BUTTONS = BUTTON_GAP + SESSION_W + BUTTON_GAP + MORE_W - BUTTON_RIGHT
local GRIP_SIZE, GRIP_INSET, GRIP_LEVEL, GRIP_LOCKED_ALPHA = 20, 2, 20, 0.4
local HOME_X, HOME_Y = -24, 210
local FRAME_NAME = "NaowhForeverDamageMeter"
local CARD, CARD_SECOND, CARD_THIRD = C.PAGE .. ":window", C.PAGE .. ":window2", C.PAGE .. ":window3"
local GAME_CVAR, GAME_CVAR_OFF = "damageMeterEnabled", "0"
local GAME_CVAR_SAVED = "damageMeterGameWas"
local DATA_EVENTS = { "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    "DAMAGE_METER_RESET" }
local STATE_EVENTS = { "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE" }
local FADE_EVERY, FADE_STEP, FADE_SNAP = 0.1, 0.35, 0.02

local TEXT_OFF = ns.L("Enable the Damage Meter first.")
local TEXT_UNAVAILABLE = ns.L("The damage meter is not available")
local TEXT_IN_COMBAT = ns.L("Preview is available outside combat.")
local TEXT_RESET_DONE = ns.L("Damage meter data reset.")
local TEXT_RESET_INSTANCE_ASK = ns.L("You entered a new instance. Reset the damage meter data?")
local TEXT_FIGHT = ns.L("Fight")
local TEXT_SESSION_TIP = ns.L("The current fight, everything since the last reset, or a past fight.")
local TEXT_MORE_TIP = ns.L("The list and the session, report, reset, add or close a window, and settings.")

local windows = {}
local pendingUpdate, unlocked, hovered, tipRow
local lastCombatEnd, override
local lastInstance, wasGrouped
local preview = false
local updateGeneration, previewGeneration = 0, 0
local events, fader
local fadeElapsed = 0
local Update

local function Get(w, base)
    return S.Get(Key(base, w.index))
end

local function Window(index)
    local w = windows[index]
    if not w then
        w = { index = index, offset = 0, offset2 = 0 }
        windows[index] = w
    end
    return w
end

local function Layout(w, session, modeKey)
    local frame = w.frame
    local index = w.index
    local bh, gap, fontSize = Look.BarHeight(index), DM.Setting(index, "barSpacing"), DM.Setting(index, "fontSize")
    frame:SetResizeBounds(MIN_WIDTH, math.max(C.MIN_HEIGHT, HEADER + 2 * INSET + bh), MAX_WIDTH, MAX_HEIGHT)
    local mode = DM.Mode(modeKey or Get(w, "mode"))
    local shown
    shown, w.offset = Look.Layout(frame, #session.combatSources, w.offset, bh, gap, fontSize, mode)
    frame.grip:SetShown(not unlocked)
    frame.grip:SetAlpha(S.Get("locked") and GRIP_LOCKED_ALPHA or 1)
    return shown, mode
end

local function OwnOnly(session)
    local rank = DM.Rank(session)
    local sources = {}
    if rank then sources[1] = session.combatSources[rank] end
    return { combatSources = sources, maxAmount = session.maxAmount, totalAmount = session.totalAmount, rank = rank }
end

local function TitleText(mode, fightName)
    local says = S.Get("titleText")
    local label = DM.ModeLabel(mode)
    if says == "list" or not fightName then return label end
    if says == "fight" then return fightName end
    return label .. TITLE_JOIN .. fightName
end

local function PaintTitleBar(frame, mode, seconds, fightName, text)
    local title, header = frame.title, frame.header
    local clock = frame.time
    local buttons = S.Get("showButtons") ~= false
    frame.session:SetShown(buttons)
    frame.more:SetShown(buttons)
    title:SetWidth(0)
    title:SetText(text or TitleText(mode, fightName))
    local textWidth, timeWidth = math.ceil(title:GetStringWidth()), Look.TimeWidth()
    local x = TITLE_X + S.Get("titleX")
    local reach = frame:GetWidth() - x
    local room = reach - (buttons and BAR_BUTTONS or TITLE_X)
    local timeRoom = S.Get("timeByTitle") == true and room or reach - BAR_BUTTONS
    local shown = seconds ~= nil and S.Get("showTime") == true and textWidth + BUTTON_GAP + timeWidth <= timeRoom
    local drawn = math.max(0, math.min(textWidth, room))
    title:ClearAllPoints()
    title:SetPoint("LEFT", header, "LEFT", x, S.Get("titleY"))
    title:SetWidth(drawn)
    clock:ClearAllPoints()
    if S.Get("timeByTitle") == true then
        clock:SetPoint("LEFT", title, "RIGHT", BUTTON_GAP + S.Get("timeX"), S.Get("timeY"))
        clock:SetJustifyH("LEFT")
    else
        clock:SetPoint("RIGHT", frame.session, "LEFT", -BUTTON_GAP + S.Get("timeX"), S.Get("timeY"))
        clock:SetJustifyH("RIGHT")
    end
    local words = shown and DM.Clock(seconds) or ""
    if shown and S.Get("timeBrackets") == true then words = TIME_BRACKETS:format(words) end
    clock:SetText(words)
    clock:SetShown(shown)
end

local function PassesMouse()
    return S.Get("clickThrough") == true and S.Get("locked") == true and not unlocked
end

local function SourceNow(list, detail)
    for _, source in ipairs(list.combatSources) do
        if detail.me then
            if source.isLocalPlayer == true then return source end
        elseif detail.guid and DM.Plain(source.sourceGUID, "string") and source.sourceGUID == detail.guid then
            return source
        end
    end
end

local function DetailView(w, session, lowerSession, seconds)
    local detail = w.detail
    local list = detail.pane == 2 and lowerSession or session
    local source = list and SourceNow(list, detail) or detail.source
    detail.source = source
    local mode = DM.Mode(detail.modeKey)
    local sessionKey, fight = Get(w, "session"), w.fight
    local inCombat = InCombatLockdown()
    local targets
    if not inCombat and mode.targets then targets = DM.Targets(sessionKey, fight, source.name) end
    local data = DM.SourceSpells(mode.key, sessionKey, fight, source)
    local view = DM.SpellSession(data, source, { rate = mode.rate, seconds = seconds, targets = targets,
        inCombat = inCombat })
    local name = DM.DisplayName(source)
    local label = DM.ModeLabel(mode)
    local title = DM.Plain(name, "string") and name .. TITLE_JOIN .. label or label
    return view, mode.key, title, list or session
end

local function Render(w, session, unavailable, seconds, lowerSession, fightName)
    local frame = w.frame
    local raid = S.Get("raidMode")
    local detail = w.detail ~= nil and not w.sample and S.Get("breakdown") == true
    frame.detail = detail
    frame:EnableMouse(detail and not PassesMouse())
    local view, modeKey, title, listSession = raid and OwnOnly(session) or session, nil, nil, session
    if detail then view, modeKey, title, listSession = DetailView(w, session, lowerSession, seconds) end
    local lowerKey = detail and "" or Get(w, "lower")
    frame.lowerOn = lowerKey ~= ""
    local shown, mode = Layout(w, view, modeKey)
    local extras = Look.Extras(Get(w, "session"), w.fight)
    Look.Paint(frame, view, w.offset, shown, mode, unavailable, extras)
    if frame.lowerOn then
        local lowerMode = DM.Mode(lowerKey)
        local lowerView = raid and OwnOnly(lowerSession) or lowerSession
        local lowerShown
        lowerShown, w.offset2 = Look.LayoutLower(frame, #lowerView.combatSources, w.offset2, lowerMode)
        Look.PaintLower(frame, lowerView, w.offset2, lowerShown, lowerMode, unavailable, extras)
    else
        Look.HideLower(frame)
    end
    local summary = S.Get("showSummary") == true
    frame.summary:SetShown(summary)
    if summary then
        Look.PaintSummary(frame, listSession, mode, DM.SessionName(Get(w, "session"), w.fight, true), seconds)
    end
    PaintTitleBar(frame, mode, seconds, fightName, title)
    ns.SetButtonText(frame.session, w.fight and TEXT_FIGHT or C.SESSION_LABELS[Get(w, "session")]
        or C.SESSION_LABELS.current)
end

local function Place(w)
    local pos = Get(w, "meterPos")
    local frame = w.frame
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", HOME_X, HOME_Y)
    end
end

local function SavePosition(w)
    local frame = w.frame
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = frame:GetLeft(), frame:GetTop() - UIParent:GetHeight() / ratio
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    S.Set(Key("meterPos", w.index), { point = "TOPLEFT", relPoint = "TOPLEFT", x = x, y = y })
end

local function OnDragStart(w)
    if S.Get("locked") or unlocked then return end
    w.frame.moving = true; w.frame:StartMoving()
end

local function OnDragStop(w)
    local frame = w.frame
    if frame.moving then frame:StopMovingOrSizing(); frame.moving = false; SavePosition(w) end
end

local function OnGripDown(w, button)
    if button ~= "LeftButton" or S.Get("locked") or unlocked then return end
    SavePosition(w)
    w.frame.sizing = true; w.frame:StartSizing("BOTTOMRIGHT")
end

local function OnGripUp(w)
    local frame = w.frame
    if not frame.sizing then return end
    local width, height = frame:GetWidth(), frame:GetHeight()
    frame:StopMovingOrSizing(); frame.sizing = false
    S.Set(Key("width", w.index), math.floor(width + ROUND)); S.Set(Key("height", w.index), math.floor(height + ROUND))
    SavePosition(w); Update()
end

local function OnHide(w)
    local frame = w.frame
    if frame.moving or frame.sizing then
        frame:StopMovingOrSizing(); frame.moving, frame.sizing = false, false
    end
end

local function OnWheel(w, delta, row)
    if row and row.pane == 2 then
        w.offset2 = math.max(0, w.offset2 - delta)
    else
        w.offset = math.max(0, w.offset - delta)
    end
    Update()
end

local function HideSpellTip()
    if tipRow and GameTooltip:GetOwner() == tipRow then GameTooltip:Hide() end
    tipRow = nil
end

local function ShowSpellTip(w, row)
    local id = row.source.spellID
    if type(id) ~= "number" or DM.IsSecret(id) then return end
    local getName = C_Spell and C_Spell.GetSpellName
    if getName and not getName(id) then return end
    if tipRow == row and row.tipID == id then return end
    HideSpellTip()
    local x = w.frame:GetCenter()
    GameTooltip:SetOwner(row, x ~= nil and x < UIParent:GetWidth() / 2 and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
    GameTooltip:SetSpellByID(id)
    GameTooltip:Show()
    tipRow, row.tipID = row, id
end

local function ShowBreakdown(w, row)
    local source = row.source
    if source ~= nil and (source.isSpell or source.isTarget or source.isHeader) then
        Breakdown.Hide()
        if source.isSpell then ShowSpellTip(w, row) else HideSpellTip() end
        return
    end
    HideSpellTip()
    local mode = DM.Mode(row.modeKey or Get(w, "mode"))
    if not S.Get("breakdown") or w.sample or source == nil or mode.spells == false then
        Breakdown.Hide()
        return
    end
    local session, fight = Get(w, "session"), w.fight
    local data = DM.SourceSpells(mode.key, session, fight, source)
    local inCombat = InCombatLockdown()
    local targets, seconds
    if not inCombat then
        seconds = DM.Duration(session, fight)
        if mode.targets then targets = DM.Targets(session, fight, source.name) end
    end
    local x = w.frame:GetCenter()
    Breakdown.Show(row, source, data, { toRight = x ~= nil and x < UIParent:GetWidth() / 2, inCombat = inCombat,
        targets = targets, seconds = seconds, rate = mode.rate, label = DM.ModeLabel(mode), index = w.index })
end

local function OnRowEnter(w, row)
    hovered = { w = w, row = row }
    ShowBreakdown(w, row)
end

local function OnRowLeave()
    hovered = nil
    Breakdown.Hide()
    HideSpellTip()
end

local function CloseDetail(w)
    if not w.detail then return end
    w.detail, w.offset = nil, 0
    OnRowLeave()
    Update()
end

local function OnRowClick(w, row, button)
    if button ~= "LeftButton" then return end
    if w.detail then
        CloseDetail(w)
        return
    end
    local source = row.source
    local mode = DM.Mode(row.modeKey or Get(w, "mode"))
    if not S.Get("breakdown") or w.sample or source == nil or mode.spells == false then return end
    w.detail = { pane = row.pane or 1, modeKey = mode.key, source = source, me = source.isLocalPlayer == true,
        guid = DM.Plain(source.sourceGUID, "string") and source.sourceGUID or nil }
    w.offset = 0
    OnRowLeave()
    Update()
end

local function NewButtons(w)
    local frame = w.frame
    local header = frame.header
    frame.more = ns.Button(header, "...", MORE_W, BUTTON_H, function() Menus.Window(w, frame.more) end)
    frame.more:SetPoint("RIGHT", BUTTON_RIGHT, 0)
    ns.Tooltip(frame.more, "Menu", TEXT_MORE_TIP)
    frame.session = ns.Button(header, "", SESSION_W, BUTTON_H, function() Menus.Session(w, frame.session) end)
    frame.session:SetPoint("RIGHT", frame.more, "LEFT", -BUTTON_GAP, 0)
    ns.Tooltip(frame.session, "Session", TEXT_SESSION_TIP)
end

local function NewGrip(w)
    local frame = w.frame
    frame.grip = CreateFrame("Button", nil, frame)
    frame.grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    frame.grip:SetPoint("BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
    frame.grip:SetFrameLevel(frame:GetFrameLevel() + GRIP_LEVEL)
    frame.grip:SetNormalTexture(C.GRIP_UP)
    frame.grip:SetHighlightTexture(C.GRIP_HIGHLIGHT)
    frame.grip:SetPushedTexture(C.GRIP_DOWN)
    ns.Tooltip(frame.grip, "Resize Damage Meter", "Drag to resize. Turn off Lock Window first.")
    frame.grip:SetScript("OnMouseDown", function(_, button) OnGripDown(w, button) end)
    frame.grip:SetScript("OnMouseUp", function() OnGripUp(w) end)
end

local function AttachMover(frame, index, onSave)
    local name = DM.WindowName(index)
    if index == 1 then return UI.AttachMover(frame, name, onSave, C.PAGE, CARD) end
    if index == 2 then return UI.AttachMover(frame, name, onSave, C.PAGE, CARD_SECOND) end
    return UI.AttachMover(frame, name, onSave, C.PAGE, CARD_THIRD)
end

local function Build(w)
    local index = w.index
    local frame = CreateFrame("Frame", index == 1 and FRAME_NAME or FRAME_NAME .. index, UIParent)
    w.frame = frame
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, C.MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    Look.New(frame, index)
    NewButtons(w)
    frame.header:EnableMouse(true); frame.header:RegisterForDrag("LeftButton")
    frame.header:SetScript("OnDragStart", function() OnDragStart(w) end)
    frame.header:SetScript("OnDragStop", function() OnDragStop(w) end)
    frame.header:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then Menus.Window(w, frame.header) end
    end)
    NewGrip(w)
    frame:SetScript("OnSizeChanged", function() if frame.sizing then Update() end end)
    ns.AllowOffscreen(frame)
    frame:SetScript("OnHide", function() OnHide(w) end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) OnWheel(w, delta) end)
    frame:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then CloseDetail(w) end end)
    frame.onWheel = function(delta, row) OnWheel(w, delta, row) end
    frame.onRowEnter = function(row) OnRowEnter(w, row) end
    frame.onRowClick = function(row, button) OnRowClick(w, row, button) end
    frame.onRowLeave = OnRowLeave
    frame.mover = AttachMover(frame, index, function(pos) S.Set(Key("meterPos", index), pos) end)
    frame:SetScale(Get(w, "scale"))
    frame:Hide(); Place(w)
end

local function ShownNow()
    if override ~= nil then return override end
    if S.Get("hideInPvP") then
        local inside, kind = IsInInstance()
        if inside and (kind == "pvp" or kind == "arena") then return false end
    end
    local where = S.Get("visibility")
    if where == "group" then return IsInGroup() end
    if where == "raid" then return IsInRaid() end
    if where == "instance" then return (IsInInstance()) end
    if where == "combat" then
        if InCombatLockdown() then return true end
        return lastCombatEnd ~= nil and GetTime() - lastCombatEnd < S.Get("hideDelay")
    end
    return true
end

local function GameMeter(takeOver)
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local account = ns.AccountSettings()
    if takeOver then
        if account[GAME_CVAR_SAVED] == nil and not InCombatLockdown() then
            local was = C_CVar.GetCVar(GAME_CVAR)
            if was and was ~= GAME_CVAR_OFF then
                account[GAME_CVAR_SAVED] = was
                C_CVar.SetCVar(GAME_CVAR, GAME_CVAR_OFF)
            end
        end
    elseif account[GAME_CVAR_SAVED] ~= nil and not InCombatLockdown() then
        C_CVar.SetCVar(GAME_CVAR, account[GAME_CVAR_SAVED])
        account[GAME_CVAR_SAVED] = nil
    end
end

local function HideAll()
    for _, w in pairs(windows) do
        if w.frame then w.frame:Hide() end
    end
    OnRowLeave()
end

local function TargetAlpha(w)
    local idle = S.Get("idleAlpha")
    if idle >= 1 or unlocked or preview or InCombatLockdown() then return 1 end
    if S.Get("hoverFull") and w.frame:IsMouseOver() then return 1 end
    return idle
end

local function WatchesMouse()
    return S.Get("idleAlpha") < 1 and S.Get("hoverFull") and not (unlocked or preview or InCombatLockdown())
end

local function StepFade()
    local moving, shown = false, false
    for index = 1, DM.MAX_WINDOWS do
        local w = windows[index]
        if w and w.frame and w.frame:IsShown() then
            shown = true
            local target, now = TargetAlpha(w), w.frame:GetAlpha()
            if now ~= target then
                local nextAlpha = now + (target - now) * FADE_STEP
                if math.abs(target - nextAlpha) < FADE_SNAP then nextAlpha = target end
                w.frame:SetAlpha(nextAlpha)
                moving = true
            end
        end
    end
    return moving, shown
end

local function OnFadeTick(_, elapsed)
    fadeElapsed = fadeElapsed + elapsed
    if fadeElapsed < FADE_EVERY then return end
    fadeElapsed = 0
    local moving, shown = StepFade()
    if not moving and not (shown and WatchesMouse()) then fader:SetScript("OnUpdate", nil) end
end

local function StartFade()
    fader = fader or CreateFrame("Frame")
    fader:SetScript("OnUpdate", OnFadeTick)
end

local function ApplyMouse(w)
    local frame, through = w.frame, PassesMouse()
    frame.header:EnableMouse(not through)
    frame.grip:SetShown(not unlocked and not through)
    for _, pane in ipairs(frame.panes) do
        for _, row in ipairs(pane.rows) do row:EnableMouse(not through) end
    end
    frame.passes = through
end

local function ApplyScale(w)
    local frame, scale = w.frame, Get(w, "scale")
    local old = frame:GetScale()
    if old == scale then return end
    frame:SetScale(scale)
    local pos = Get(w, "meterPos")
    if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
        S.Set(Key("meterPos", w.index), { point = pos.point, relPoint = pos.relPoint, x = pos.x * old / scale,
            y = pos.y * old / scale })
        Place(w)
    end
end

local function Draw(w, asSample)
    ApplyScale(w)
    w.sample = asSample
    local lowerKey = Get(w, "lower")
    if asSample then
        local sample = DM.Sample()
        Render(w, sample, nil, sample.durationSeconds, lowerKey ~= "" and sample or nil, sample.fightName)
    else
        local session, fight = Get(w, "session"), w.fight
        local lower = lowerKey ~= "" and DM.Session(lowerKey, session, fight) or nil
        local name = S.Get("titleText") ~= "list" and DM.FightName(session, fight) or nil
        local available, why = DM.Available()
        local unavailable = not available and (why ~= nil and why ~= "" and why or TEXT_UNAVAILABLE) or nil
        Render(w, DM.Session(Get(w, "mode"), session, fight), unavailable, DM.Duration(session, fight), lower, name)
    end
    w.frame:Show()
    ApplyMouse(w)
    StartFade()
end

function Update()
    pendingUpdate = false
    if not DM.On() and not unlocked then HideAll() return end
    local sample = unlocked or preview
    local visible = sample or ShownNow()
    for index = 1, DM.MAX_WINDOWS do
        local w = windows[index]
        if w and w.frame then
            if visible and DM.WindowOn(index) then Draw(w, sample) else w.frame:Hide() end
        end
    end
    if hovered and hovered.w.frame:IsShown() then ShowBreakdown(hovered.w, hovered.row) else OnRowLeave() end
end

local function RequestUpdate()
    if pendingUpdate or not DM.On() then return end
    pendingUpdate = true
    local generation = updateGeneration
    C_Timer.After(UPDATE_DELAY, function() if generation == updateGeneration then Update() end end)
end

DM.Refresh = RequestUpdate

local function ResetNow()
    if InCombatLockdown() then return end
    DM.Reset()
    ns.Print(TEXT_RESET_DONE)
end

local function InstanceID()
    if not IsInInstance() then return nil end
    return select(8, GetInstanceInfo())
end

local function OnEnterWorld(isLogin, isReload)
    local now = InstanceID()
    local entered = now ~= nil and now ~= lastInstance
    lastInstance = now
    if isLogin or isReload or not entered or InCombatLockdown() then return end
    local mode = S.Get("resetOn")
    if mode == "instance" then
        ResetNow()
    elseif mode == "ask" then
        ns.Confirm(TEXT_RESET_INSTANCE_ASK, ResetNow)
    end
end

local function OnGroupChanged()
    local grouped = IsInGroup()
    local left = wasGrouped == true and not grouped
    wasGrouped = grouped
    if left and S.Get("resetOnLeave") then ResetNow() end
end

local function ShowOverall(on)
    for index = 1, DM.MAX_WINDOWS do
        if DM.WindowOn(index) then
            local key, want = Key("session", index), on and "overall" or "current"
            if S.Get(key) ~= want then
                S.Set(key, want)
                local w = windows[index]
                if w then w.fight, w.offset = nil, 0 end
            end
        end
    end
end

local function ForgetFights()
    for _, w in pairs(windows) do w.fight, w.detail, w.offset, w.offset2 = nil, nil, 0, 0 end
end

local function OnEvent(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" or event:find("^DAMAGE_METER") then DM.ClearTargets() end
    if event == "PLAYER_REGEN_DISABLED" then
        preview, override = false, nil
        if S.Get("overallOutOfCombat") then ShowOverall(false) end
        DM.History.OnCombatStart()
    elseif event == "ENCOUNTER_END" then
        DM.History.OnEncounterEnd((select(2, ...)))
    elseif event == "PLAYER_REGEN_ENABLED" then
        if S.Get("overallOutOfCombat") then ShowOverall(true) end
        DM.History.Arm()
        GameMeter(DM.On() and S.Get("hideGameMeter"))
        DM.ScanRoster()
        lastCombatEnd = GetTime()
        if S.Get("visibility") == "combat" then
            C_Timer.After(S.Get("hideDelay") + UPDATE_DELAY, RequestUpdate)
        end
    elseif event == "DAMAGE_METER_RESET" then
        ForgetFights()
    elseif event == "PLAYER_ENTERING_WORLD" then
        DM.ScanRoster()
        OnEnterWorld(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        DM.ScanRoster()
        OnGroupChanged()
    end
    RequestUpdate()
end

local function Listen()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(DATA_EVENTS) do events:RegisterEvent(event) end
    for _, event in ipairs(STATE_EVENTS) do events:RegisterEvent(event) end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(events.RegisterEvent, events, "ENCOUNTER_END")
end

local function Apply()
    if events then events:UnregisterAllEvents() end
    updateGeneration = updateGeneration + 1; pendingUpdate = false
    GameMeter(DM.On() and S.Get("hideGameMeter"))
    if not (DM.On() or unlocked) then HideAll() return end
    for index = 1, DM.MAX_WINDOWS do
        if DM.WindowOn(index) then
            local w = Window(index)
            if not w.frame then Build(w) end
            Place(w)
            w.frame.mover:SetShown(unlocked == true)
        end
    end
    if DM.On() then Listen(); DM.ScanRoster() end
    Update()
end

local function EndPreview(generation)
    if generation ~= previewGeneration then return end
    preview = false
    Update()
end

function ns.PreviewDamageMeter()
    if not DM.On() then ns.Print(TEXT_OFF) return end
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT) return end
    previewGeneration = previewGeneration + 1
    local generation = previewGeneration
    preview = true
    Update()
    C_Timer.After(PREVIEW_SECONDS, function() EndPreview(generation) end)
end

function NaowhForever_ToggleDamageMeter()
    if not DM.On() then ns.Print(TEXT_OFF) return end
    local first = windows[1]
    override = not (first and first.frame and first.frame:IsShown())
    Update()
end

function NaowhForever_ResetDamageMeter()
    if not DM.On() then ns.Print(TEXT_OFF) return end
    DM.Reset()
    ns.Print(TEXT_RESET_DONE)
end

local function OnSet(key)
    if key:find("^meterPos") then return end
    for _, w in pairs(windows) do
        if w.frame then Look.Invalidate(w.frame) end
    end
    local own = key:match("^ownLook(%d)$")
    if own and S.Get(key) == true then DM.CopyLook(tonumber(own)) end
    if key == "overallOutOfCombat" and S.Get("overallOutOfCombat") then ShowOverall(not InCombatLockdown()) end
    if key == "enabled" or key == "hideGameMeter" or key:find("^window%d$") then
        previewGeneration = previewGeneration + 1
        preview = false
        Apply()
    else
        RequestUpdate()
    end
end

local function OnUnlock()
    unlocked = DM.On() == true
    Apply()
end

local function OnLock()
    unlocked = false
    if windows[1] and windows[1].frame then Apply() end
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() Apply() end)
