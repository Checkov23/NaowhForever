-- TalentPoints.lua: the QoL unspent talent points reminder.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts, St = ns.Shared.Parts, ns.Shared.Style

local GOLD = { r = 1, g = 0.82, b = 0 }
local WIDTH, ROOM = 300, 10
local FONT_SIZE = 22
local STACK_ORDER = 2
local PAGE = "QoL/XP"
local TEXT_ALERT = "Talent Points"
local SAMPLE_POINTS = 2
local TEXT_RANGE = { 10, 48, 1 }

local TEXT_ONE = ns.L("1 Unspent Talent Point")
local TEXT_MANY = ns.L("%d Unspent Talent Points")

local EVENTS = { "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

local frame, unlocked, inCombat
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("talentPoints")
end

local function Show(points)
    frame.text:SetText(points == 1 and TEXT_ONE or TEXT_MANY:format(points))
    frame:SetWidth(frame.mode == "none" and WIDTH or frame.text:GetStringWidth() + 2 * St.CARD_PAD)
    frame:Show()
end

local function Update()
    if unlocked then
        Show(SAMPLE_POINTS)
        return
    end
    local unspent, classPoints, specPoints = C_ClassTalents.HasUnspentTalentPoints()
    if unspent and not inCombat then
        Show(classPoints + specPoints)
    else
        frame:Hide()
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end
    Update()
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverTalentPoints", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.text = ns.Font(frame, FONT_SIZE, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.backdrop = Parts.HudBackdrop(frame, { mode = "none" })
    ns.AlertStack(frame, STACK_ORDER, TEXT_ALERT, PAGE, PAGE .. ":talentPoints")
end

local function Restyle()
    local size = S.Get("talentPointsFontSize")
    frame.mode = frame.backdrop:SetMode(S.Get("talentPointsBackground"))
    Parts.HudFont(frame.text, S.Get("talentPointsFont"), size, S.Get("talentPointsOutline"), frame.mode)
    local c = S.Get("talentPointsTheme") and T.accent or GOLD
    frame.text:SetTextColor(c.r, c.g, c.b, 1)
    frame:SetSize(WIDTH, size + ROOM)
end

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Restyle()
    inCombat = UnitAffectingCombat("player")
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Update()
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key:find("^talentPoints") then Apply() end
end)
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

Settings.Page(PAGE, S):Card({
    id = "talentPoints", name = "Talent Points", order = 40, switch = "talentPoints",
    help = "Text on screen while you have talent points to spend. Hidden in combat. Move it in the "
        .. "HUD Editor.",
    rows = {
        Settings.Look("talentPoints", { text = true, size = TEXT_RANGE, background = "card" }),
        Settings.Group("Colors"),
        { key = "talentPointsTheme", label = "Apply Theme to Text Color", toggle = true,
          help = "The text in the theme's accent color instead of gold." },
    },
})
