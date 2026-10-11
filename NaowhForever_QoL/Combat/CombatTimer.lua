-- CombatTimer.lua: Combat Timer, how long the current fight has run, on screen and in chat.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI
local Parts = ns.Shared.Parts

local CARD_COLOR, CARD_ALPHA = { r = 0, g = 0, b = 0 }, 0.8
local OLD_BACKGROUNDS = { [true] = "card", [false] = "none" }
local TICK = 1
local FONT_SIZE = 32
local WIDTH_PER_SIZE, ROOM = 7, 16
local DEFAULT_Y = -200
local SECONDS_PER_MINUTE, SECONDS_PER_HOUR = ns.QoLConstants.SECONDS_PER_MINUTE, ns.QoLConstants.SECONDS_PER_HOUR
local TEXT_RANGE = { 10, 72, 1 }
local MOVER_LABEL = "Combat Timer"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Combat", "QoL/Combat:combatTimer"
local CLOCK = "%d:%02d"
local PREFIX = ns.L("COMBAT: ")
local REPORT = ns.L("You were in combat for: |cffffa300%s|r")
local HOURS, MINUTES = ns.L("%d:%02d:%02d hours"), ns.L("%d:%02d minutes")
local SECOND, SECONDS = ns.L("%d second"), ns.L("%d seconds")
local WHERE_INSTANCES, WHERE_EVERYWHERE = ns.L("In instances"), ns.L("Everywhere")
local SUMMARY_CHAT, SUMMARY_STICKY = ns.L(", reported to chat"), ns.L(", kept after the fight")

local frame, clock, unlocked
local started, last = nil, 0

local function On()
    return S.Get("enabled") and S.Get("combatTimer")
end

local function InstanceOk()
    if not S.Get("combatTimerInstanceOnly") then return true end
    local inInstance, kind = IsInInstance()
    return inInstance and kind ~= "none"
end

local function Format(seconds)
    local text = CLOCK:format(math.floor(seconds / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE))
    if S.Get("combatTimerHidePrefix") then return text end
    return PREFIX .. text
end

local function Update()
    local elapsed
    if started then
        elapsed = GetTime() - started
    elseif unlocked or (S.Get("combatTimerSticky") and last > 0 and InstanceOk()) then
        elapsed = last
    end
    if not elapsed then
        frame:Hide()
        return
    end
    frame.text:SetText(Format(elapsed))
    frame:Show()
end

local function Duration(seconds)
    local h = math.floor(seconds / SECONDS_PER_HOUR)
    local m = math.floor(seconds % SECONDS_PER_HOUR / SECONDS_PER_MINUTE)
    local s = math.floor(seconds % SECONDS_PER_MINUTE)
    if h > 0 then return HOURS:format(h, m, s) end
    if m > 0 then return MINUTES:format(m, s) end
    return (s == 1 and SECOND or SECONDS):format(s)
end

local function Report(duration)
    ns.Print(REPORT:format(Duration(duration)))
end

local function StopClock()
    if clock then clock:Cancel(); clock = nil end
end

local function OnCombatStart()
    if not InstanceOk() then return false end
    started = GetTime()
    if not clock then clock = C_Timer.NewTicker(TICK, Update) end
    return true
end

local function OnCombatEnd()
    last = GetTime() - started
    started = nil
    StopClock()
    if S.Get("combatTimerChat") then Report(last) end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if not OnCombatStart() then return end
    elseif event == "PLAYER_REGEN_ENABLED" and started then
        OnCombatEnd()
    end
    Update()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)

local function SavePosition(pos)
    S.Set("combatTimerPos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverCombatTimer", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.backdrop = Parts.HudBackdrop(frame, { color = ns.ThemeTint("bg", CARD_COLOR), alpha = CARD_ALPHA,
        mode = "none" })
    frame.text = ns.Font(frame, FONT_SIZE, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.mover = UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
    frame:Hide()
end

local function Place()
    local pos = S.Get("combatTimerPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function MigrateBackground()
    local db = S.DB()
    local mode = OLD_BACKGROUNDS[db.combatTimerBackground]
    if mode then db.combatTimerBackground = mode end
end

local function Restyle()
    local size = S.Get("combatTimerFontSize")
    local mode = frame.backdrop:SetMode(S.Get("combatTimerBackground"))
    Parts.HudFont(frame.text, S.Get("combatTimerFont"), size, S.Get("combatTimerOutline"), mode)
    local c = S.Get("combatTimerClassColor") and RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        or S.Get("combatTimerColor")
    frame.text:SetTextColor(c.r, c.g, c.b, 1)
    frame:SetSize(size * WIDTH_PER_SIZE, size + ROOM)
end

local function Apply()
    MigrateBackground()
    events:UnregisterAllEvents()
    if not On() then
        started = nil
        StopClock()
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Restyle()
    Place()
    frame.mover:SetShown(unlocked == true)
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    Update()
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^combatTimer") and key ~= "combatTimerPos") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = S.Get("enabled") == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared.Settings
local Group = Settings.Group

local function OwnColour() return not S.Get("combatTimerClassColor") end

local function Summary(store)
    local parts = store.Get("combatTimerInstanceOnly") and WHERE_INSTANCES or WHERE_EVERYWHERE
    if store.Get("combatTimerChat") then parts = parts .. SUMMARY_CHAT end
    if store.Get("combatTimerSticky") then parts = parts .. SUMMARY_STICKY end
    return parts
end

Settings.Page("QoL/Combat", S):Card({
    id = "combatTimer", name = "Combat Timer", order = 90, switch = "combatTimer",
    help = "How long the current fight has run, on screen while you fight. Move it in the HUD Editor.",
    summary = Summary,
    rows = {
        Group("When"),
        { key = "combatTimerInstanceOnly", label = "Only In Instances", toggle = true },
        { key = "combatTimerChat", label = "Report to Chat", toggle = true,
          help = "How long the fight lasted, in chat when it ends." },
        { key = "combatTimerSticky", label = "Keep After the Fight", toggle = true,
          help = "The last fight's time stays on screen until the next one starts." },
        Settings.Look("combatTimer", { text = true, size = TEXT_RANGE }),
        { key = "combatTimerHidePrefix", label = "Hide the COMBAT Label", toggle = true },
        Settings.Look("combatTimer", { background = "card" }),
        Group("Colors"),
        { key = "combatTimerClassColor", label = "Class Color", toggle = true },
        { key = "combatTimerColor", label = "Timer Color", colour = true, needs = OwnColour,
          why = "Class color is on" },
    },
})
