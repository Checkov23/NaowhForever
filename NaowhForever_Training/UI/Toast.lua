-- Toast.lua: the Level-Up Toast: on a level-up with spells to train, how many, what they cost, and buttons.
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI

local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Rows = Training.Rows

local FRAME_NAME = "NaowhForeverTrainingToast"
local SPELL = Training.C.ENTRY_SPELL
local TOAST_W, TOAST_PAD = 440, 18
local TOAST_ICON, TOAST_ICONS = 30, 10
local ICON_GAP = 6
local LOGO = 26
local TITLE_GAP, LINE_GAP = 10, 12
local ICONS_GAP, BUTTONS_GAP = 12, 14
local BUTTON_H = 28
local OPEN_W, WAYPOINT_W, DISMISS_W = 140, 100, 90
local BUTTON_GAP = 8
local HOME_DROP = -140
local TOAST_SECONDS = 20
local LEARN_SETTLE = 1
local FONT_TITLE, FONT_LINE = 22, 14
local TEXT_LEVEL = ns.L("Level ")
local TEXT_ONE_SPELL, TEXT_SPELLS = ns.L("1 spell"), ns.L(" spells")
local TEXT_LINE = ns.L("%s to train, %s in all. %s")
local TEXT_AFFORD_ALL = ns.L("You can afford every one.")
local TEXT_AFFORD_SOME = ns.L("You can afford %d of them.")
local TEXT_OPEN, TEXT_WAYPOINT, TEXT_DISMISS = ns.L("Open Planner"), ns.L("Waypoint"), ns.L("Dismiss")

local toast, toastGen = nil, 0
local events = CreateFrame("Frame")

local function On()
    return Training.On() and S.Get("levelUpToast")
end

local function Place()
    local pos = S.Get("toastPos")
    toast:ClearAllPoints()
    if pos then
        toast:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        toast:SetPoint("TOP", UIParent, "TOP", 0, HOME_DROP)
    end
end

local function DragStart()
    toast.dragging = true
    toast:StartMoving()
end

local function DragStop()
    toast:StopMovingOrSizing()
    toast.dragging = false
    S.Set("toastPos", UI.CenterPosition(toast))
    if toast.expired then toast:Hide() end
end

local function OpenPlanner()
    toast:Hide()
    ns.OpenTrainingWindow()
end

local function Build()
    toast = CreateFrame("Frame", FRAME_NAME, UIParent)
    toast:SetWidth(TOAST_W)
    toast:SetFrameStrata("DIALOG")
    toast:SetClampedToScreen(true)
    toast:SetMovable(true)
    toast:EnableMouse(true)
    toast:RegisterForDrag("LeftButton")
    toast:SetScript("OnDragStart", DragStart)
    toast:SetScript("OnDragStop", DragStop)
    ns.Solid(toast, "BACKGROUND", T.bg, Style.BACKDROP_ALPHA):SetAllPoints()
    ns.Border(toast, T.accent)
    local logo = toast:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO_FILE, nil, nil, "TRILINEAR")
    logo:SetSize(LOGO, LOGO)
    logo:SetPoint("TOPLEFT", TOAST_PAD, -TOAST_PAD)
    toast.title = ns.Font(toast, FONT_TITLE, nil)
    toast.title:SetPoint("LEFT", logo, "RIGHT", TITLE_GAP, 0)
    toast.line = ns.Font(toast, FONT_LINE, nil)
    toast.line:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -LINE_GAP)
    toast.line:SetWidth(TOAST_W - 2 * TOAST_PAD)
    toast.line:SetJustifyH("LEFT")
    toast.line:SetWordWrap(true)
    toast.icons = {}
    for i = 1, TOAST_ICONS do
        local icon = Rows.Crop(toast:CreateTexture(nil, "ARTWORK"))
        icon:SetSize(TOAST_ICON, TOAST_ICON)
        toast.icons[i] = icon
    end
    toast.open = ns.AccentBorder(ns.Button(toast, TEXT_OPEN, OPEN_W, BUTTON_H, OpenPlanner))
    toast.waypoint = ns.Button(toast, TEXT_WAYPOINT, WAYPOINT_W, BUTTON_H, function() Training.WaypointToTrainer() end)
    toast.dismiss = ns.Button(toast, TEXT_DISMISS, DISMISS_W, BUTTON_H, function() toast:Hide() end)
    Place()
    toast:Hide()
end

local function Affordable(plan)
    local afford, budget = 0, GetMoney()
    for _, entry in ipairs(plan.now) do
        local price = Training.Price(entry)
        if price <= budget then
            afford = afford + 1
            budget = budget - price
        end
    end
    return afford
end

local function PlaceIcons(plan, y)
    for i, icon in ipairs(toast.icons) do
        local entry = plan.now[i]
        icon:SetShown(entry ~= nil)
        if entry then
            icon:SetTexture(C_Spell.GetSpellTexture(entry[SPELL]))
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", TOAST_PAD + (i - 1) * (TOAST_ICON + ICON_GAP), y)
        end
    end
end

local function PlaceButtons(y)
    toast.open:ClearAllPoints()
    toast.open:SetPoint("TOPLEFT", TOAST_PAD, y)
    toast.waypoint:ClearAllPoints()
    toast.waypoint:SetPoint("LEFT", toast.open, "RIGHT", BUTTON_GAP, 0)
    toast.dismiss:ClearAllPoints()
    toast.dismiss:SetPoint("LEFT", toast.waypoint, "RIGHT", BUTTON_GAP, 0)
end

local function Fill(level, plan)
    local cost = Training.Total(plan.now)
    local afford = Affordable(plan)
    toast.title:SetText(TEXT_LEVEL .. level)
    local count = #plan.now == 1 and TEXT_ONE_SPELL or (#plan.now .. TEXT_SPELLS)
    toast.line:SetText(TEXT_LINE:format(count, Training.Coins(cost),
        afford == #plan.now and TEXT_AFFORD_ALL or TEXT_AFFORD_SOME:format(afford)))
    local y = -(TOAST_PAD + LOGO + LINE_GAP + math.ceil(toast.line:GetStringHeight()) + ICONS_GAP)
    PlaceIcons(plan, y)
    y = y - TOAST_ICON - BUTTONS_GAP
    PlaceButtons(y)
    toast:SetHeight(-y + BUTTON_H + TOAST_PAD)
end

local function Show(level)
    local plan = Training.Plan(level)
    if #plan.now == 0 then return end
    if not toast then Build() end
    Fill(level, plan)
    toast:Show()
    toast.expired = false
    toastGen = toastGen + 1
    local gen = toastGen
    C_Timer.After(TOAST_SECONDS, function()
        if gen ~= toastGen then return end
        toast.expired = true
        if not toast.dragging then toast:Hide() end
    end)
end

local function OnLevelUp(_, _, level)
    C_Timer.After(LEARN_SETTLE, function() if On() then Show(level) end end)
end

local function Apply()
    events:UnregisterAllEvents()
    if toast and not On() then toast:Hide() end
    if On() then events:RegisterEvent("PLAYER_LEVEL_UP") end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "levelUpToast" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

events:SetScript("OnEvent", OnLevelUp)
S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
