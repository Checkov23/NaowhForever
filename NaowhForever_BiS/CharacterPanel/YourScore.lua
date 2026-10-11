-- YourScore.lua: your Naowh Score card under your level on the character panel: hover for the score with your BiS, click for the BiS List.
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local CP = ns.CharacterPanel
local C = CP.C
local B = ns.BiS

local GAP = 10
local PANE_DROP = 68
local BADGE_LIFT = 20
local GOAL_RGB, TITLE_RGB = C.GOLD_RGB, C.TITLE_RGB
local TIP_TITLE = "Naowh Score"
local TIP_NOW, TIP_WITH_BIS = ns.L("Now"), ns.L("With your BiS")
local TIP_GOAL = ns.L("Level %d goal")
local TIP_BEST = ns.L("Best in the game")
local TIP_CLICK = ns.L("Click to open the BiS List.")

local badge, installed
local gains = { stats = {} }

local function ScoreOn()
    return CP.On() and S.Get("characterPanelScore") == true
end

local function Paint()
    CP.PaintScoreCard(badge, ns.NaowhScore.Unit("player"), UnitLevel("player"))
end

local function Enter(frame)
    local Score = ns.NaowhScore
    if not ns.Shared.Parts.Tip(frame, "ANCHOR_BOTTOM") then return end
    local m, w, level = T.muted, TITLE_RGB, UnitLevel("player")
    GameTooltip:SetText(TIP_TITLE, w.r, w.g, w.b)
    GameTooltip:AddDoubleLine(TIP_NOW, Score.Colored((Score.Unit("player")), level), m.r, m.g, m.b)
    local read = B.Gains.Read(B.Lists.List(), gains)
    if read.bis and read.bis > 0 then
        GameTooltip:AddDoubleLine(TIP_WITH_BIS, Score.Colored(read.bis, level), m.r, m.g, m.b)
    end
    local goal, best = Score.Best(level), Score.Best()
    if goal and best and goal < best then
        GameTooltip:AddDoubleLine(TIP_GOAL:format(level), Score.Text(goal), GOAL_RGB.r, GOAL_RGB.g, GOAL_RGB.b,
            w.r, w.g, w.b)
    end
    if best then GameTooltip:AddDoubleLine(TIP_BEST, Score.Text(best), m.r, m.g, m.b, w.r, w.g, w.b) end
    GameTooltip:AddLine(TIP_CLICK, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function OnEvent()
    if badge:IsVisible() then Paint() end
end

local function Shown()
    badge:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    Paint()
end

local function Hidden()
    badge:UnregisterAllEvents()
end

local function Clicked()
    ns.OpenBisWindow()
end

local function Build()
    local stats = CharacterStatsPaneScrollBox
    badge = CP.ScoreCard(stats)
    badge:SetIgnoreParentAlpha(true)
    if PaperDollFrame and PaperDollFrame.TopBackgroundStripHost then
        badge:SetPoint("TOP", PaperDollSidebarTabs, "TOP", 0, -PANE_DROP)
    else
        badge:SetPoint("TOP", CharacterLevelText, "BOTTOM", 0, -GAP)
    end
    badge:SetFrameLevel(stats:GetFrameLevel() + BADGE_LIFT)
    badge:SetScript("OnEnter", Enter)
    badge:SetScript("OnLeave", GameTooltip_Hide)
    badge:SetScript("OnClick", Clicked)
    badge:SetScript("OnEvent", OnEvent)
    badge:SetScript("OnShow", Shown)
    badge:SetScript("OnHide", Hidden)
    CP.badge = badge
end

local function Apply()
    local on = ScoreOn()
    if on and not installed and CharacterStatsPaneScrollBox then
        installed = true
        Build()
    end
    if not installed then return end
    badge:SetShown(on)
    if on and badge:IsVisible() then Paint() end
end

local function OnSetting(key)
    if key == "enabled" or key:find("^characterPanel") or key == "naowhScoreCompare" then Apply() end
end

CP.BADGE_GAP = GAP
CP.ApplyScore = Apply

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
