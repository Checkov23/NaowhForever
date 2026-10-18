-- Highlight.lua: the effect and its line on the soft interact target's nameplate, kept in step with the game.
local ns = _G.NaowhForever

local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitIsUnit = UnitIsUnit

local G = ns.Glimmer
local S = G.Settings
local C, St = G.C, G.Style
local Target, Effects, CVars = G.Target, G.Effects, G.CVars
local Plain = G.Plain

local UNIT = C.UNIT

local EVENTS = {
    "PLAYER_SOFT_INTERACT_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
    "SKILL_LINES_CHANGED",
}

local events, watch, fx, line
local plate, shown, barOwner
local wantReady, wantSince
local read = {}
local queued, fullQueued, cvarsQueued = false, false, false
local FULL_KEYS = { enabled = true, questSparkle = true, giverHideBar = true, giverOffset = true }
local BAR_PARTS = { "HealthBarsContainer", "LevelFrame", "PlayerLevelDiffFrame" }
local CVAR_KEYS = { range = true, arc = true }

local function Paused()
    if InCombatLockdown() then return true end
    return S.Get("hideInstance") and IsInInstance() and true or false
end

local function ShowBar()
    if not barOwner then return end
    for _, name in ipairs(BAR_PARTS) do barOwner[name]:SetAlpha(1) end
    barOwner = nil
end

local function HideBar(to)
    local unitFrame = to.UnitFrame
    if not unitFrame then return end
    barOwner = unitFrame
    for _, name in ipairs(BAR_PARTS) do unitFrame[name]:SetAlpha(0) end
end

local function Release()
    if not plate then return end
    ShowBar()
    fx:Hide()
    fx:ClearAllPoints()
    fx:SetParent(nil)
    watch:Hide()
    plate, shown = nil, nil
end

local function Build()
    if fx then return end
    fx = Effects.New(UIParent)
    fx:Hide()
    line = ns.Font(fx, St.LINE_SIZE)
    ns.Shared.Parts.HudText(line)
    watch = CreateFrame("Frame")
    watch:Hide()
end

local function LineFor(info)
    if info.category == "quest" then return info.line, St.QUEST_LINE_RGB end
    if not info.tier then return end
    return Target.TierText(info.category, info.need, info.tier), St.TIER_RGB[info.tier]
end

local function ColorFor(info)
    if info.tier and S.Get("skillColors") then return St.TIER_RGB[info.tier] end
    return S.Get(info.category .. "Color")
end

local function Paint(info)
    Effects.Set(fx, G.StyleOf(info.category), ColorFor(info), S.Get("brightness"), S.Get("size"),
        info.ready, info.locked)
    local text, color = LineFor(info)
    if text and S.Get("showLine") then
        line:SetText(text)
        line:SetTextColor(color.r, color.g, color.b)
        line:Show()
    else
        line:Hide()
    end
end

local function Attach(to, info)
    fx:SetParent(to)
    local level = to:GetFrameLevel()
    if Plain(level) then fx:SetFrameLevel(math.max(level - 1, 0)) end
    fx:SetIgnoreParentAlpha(true)
    fx:ClearAllPoints()
    local giver = info.category == "giver"
    fx:SetPoint("CENTER", to, "CENTER", 0, giver and St.PLATE_Y + S.Get("giverOffset") or St.PLATE_Y)
    if giver and S.Get("giverHideBar") then HideBar(to) end
    line:ClearAllPoints()
    line:SetPoint("TOP", to, "BOTTOM", 0, St.LINE_Y)
    plate, shown = to, info
    wantReady, wantSince = info.ready, nil
    Paint(info)
    Effects.Start(fx)
    fx:Show()
    watch:Show()
end

local function Evaluate()
    if not G.On() then return Release() end
    if Paused() then
        CVars.SetPlate(false)
        return Release()
    end
    local info = Target.Read(UNIT, read)
    local wanted = info and Target.Wanted(info.category) and not (info.locked and S.Get("hideLocked"))
    if not wanted then
        CVars.SetPlate(not S.Get("onlyHighlighted"))
        return Release()
    end
    CVars.SetPlate(true)
    local to = GetNamePlateForUnit(UNIT)
    if not (to and Plain(to)) then return Release() end
    if to ~= plate then Release() end
    if plate then
        shown = info
        Paint(info)
    else
        Attach(to, info)
    end
end

local function Watch(_, elapsed)
    watch.since = (watch.since or 0) + elapsed
    if watch.since < C.STATE_CHECK then return end
    watch.since = 0
    local ready = Target.Reach(UNIT)
    if ready == shown.ready then
        wantSince = nil
        return
    end
    local now = GetTime()
    if ready ~= wantReady or not wantSince then
        wantReady, wantSince = ready, now
    elseif now - wantSince >= C.STATE_HOLD then
        shown.ready, wantSince = ready, nil
        Paint(shown)
    end
end

local function OnEvent(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        CVars.SetPlate(false)
        Release()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local soft = UnitIsUnit(unit, UNIT)
        if not plate and not (Plain(soft) and not soft) then Evaluate() end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if plate and GetNamePlateForUnit(unit) == plate then Release() end
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
        Release()
        Evaluate()
    elseif event == "QUEST_LOG_UPDATE" or event == "SKILL_LINES_CHANGED" then
        if plate then Evaluate() end
    else
        Evaluate()
    end
end

local function Apply()
    CVars.Apply()
    if not G.On() then
        if events then events:UnregisterAllEvents() end
        Release()
        return
    end
    Build()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
        watch:SetScript("OnUpdate", Watch)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Release()
    Evaluate()
    G.CheckOthers()
end

local function RunQueued()
    local full, cvars = fullQueued, cvarsQueued
    queued, fullQueued, cvarsQueued = false, false, false
    if full then return Apply() end
    if cvars then CVars.Apply() end
    if G.On() and events then Evaluate() end
end

local function OnSet(key)
    fullQueued = fullQueued or FULL_KEYS[key] or false
    cvarsQueued = cvarsQueued or CVAR_KEYS[key] or false
    if queued then return end
    queued = true
    C_Timer.After(0, RunQueued)
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
