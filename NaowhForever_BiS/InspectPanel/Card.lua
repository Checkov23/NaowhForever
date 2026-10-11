-- Card.lua: their Naowh Score card and supporter badge plate on the inspect panel.
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local IP = ns.InspectPanel
local CP = ns.CharacterPanel

local YOU = ns.L("You ")
local PLATE_LEVEL = 10
local BADGES_LIVE = ns.BADGES_LIVE
local TITLE_RGB = CP.C.TITLE_RGB
local TIP_TITLE = "Naowh Score"
local TIP_THEM, TIP_YOU = ns.L("Them"), ns.L("You")
local TIP_GOAL = ns.L("Level %d goal")
local TIP_BEST = ns.L("Best in the game")

local card, plate
local last = {}

local function ScoreOn()
    return IP.On() and S.Get("inspectPanelScore") == true
end

local function BadgeOn()
    local wanted = S.Get("inspectPanelBadge")
    if ns.FEATURE_BADGES ~= BADGES_LIVE then wanted = S.Default("inspectPanelBadge") end
    return IP.On() and wanted == true
end

local function LevelOf(unit)
    local level = UnitLevel(unit)
    return level and level > 0 and level or nil
end

local function TheirScore(unit, guid)
    local Score = ns.NaowhScore
    if IP.Ready(guid) and IP.HasGear(unit, guid) then
        local score, complete = Score.Unit(unit)
        if complete then
            last.guid, last.score, last.level = guid, score, LevelOf(unit)
            Score.Remember(guid, score, true, false, last.level)
            return score, last.level
        end
        IP.Wait()
    end
    if last.guid == guid then return last.score, last.level end
    local known = Score.Known(guid)
    if known then return known.score, known.level or LevelOf(unit) end
end

local function Paint(unit, guid)
    local Score = ns.NaowhScore
    local score, level
    if guid then score, level = TheirScore(unit, guid) end
    card.score, card.level = score, level
    if score then CP.PaintScoreCard(card, score, level) else CP.ScoreCardWaiting(card) end
    card.you:SetText(YOU .. Score.Colored((Score.Unit("player")), LevelOf("player")))
end

local function PaintPlate(guid)
    local shown = BadgeOn() and guid ~= nil and ns.BadgeOf(guid) ~= nil
    plate:SetShown(shown)
    if shown then CP.PaintBadgePlate(plate, guid) end
end

local function Enter(self)
    local Score = ns.NaowhScore
    if not ns.Shared.Parts.Tip(self, "ANCHOR_BOTTOM") then return end
    local m, w = T.muted, TITLE_RGB
    local unit = IP.unit
    GameTooltip:SetText(TIP_TITLE, w.r, w.g, w.b)
    local name = unit and UnitName(unit)
    GameTooltip:AddDoubleLine(IP.Readable(name) and name or TIP_THEM,
        card.score and Score.Colored(card.score, card.level) or CP.WAITING, m.r, m.g, m.b)
    GameTooltip:AddDoubleLine(TIP_YOU, Score.Colored((Score.Unit("player")), LevelOf("player")), m.r, m.g, m.b)
    local goal, best = card.level and Score.Best(card.level), Score.Best()
    if goal and best and goal < best then
        local gold = CP.GOAL_RGB
        GameTooltip:AddDoubleLine(TIP_GOAL:format(card.level), Score.Text(goal), gold.r, gold.g, gold.b, w.r, w.g, w.b)
    end
    if best then GameTooltip:AddDoubleLine(TIP_BEST, Score.Text(best), m.r, m.g, m.b, w.r, w.g, w.b) end
    GameTooltip:Show()
end

local function Build()
    card = CP.ScoreCard(IP.pane)
    card:SetPoint("TOPLEFT", IP.EDGE, -IP.CARD_GAP)
    card.you = ns.Font(card, CP.LEGEND_SIZE, nil, T.muted)
    card.you:SetPoint("TOPLEFT", card.bar, "BOTTOMLEFT", 0, -CP.LEGEND_GAP)
    card:SetScript("OnEnter", Enter)
    card:SetScript("OnLeave", GameTooltip_Hide)
    IP.card = card
    local parent = InspectPaperDollFrame or InspectFrame
    plate = CP.BadgePlate(parent)
    local model = InspectModelFrame or parent
    plate:SetPoint("TOPLEFT", model, "TOPLEFT", CP.BADGE_INSET, -CP.BADGE_INSET)
    plate:SetFrameLevel(model:GetFrameLevel() + PLATE_LEVEL)
    plate:Hide()
    IP.plate = plate
end

IP.OnApply(function(on)
    if on and not card then Build() end
    if not card then return end
    card:SetShown(ScoreOn())
    if not BadgeOn() then plate:Hide() end
end)

IP.OnRefresh(function(unit, guid)
    if ScoreOn() then Paint(unit, guid) end
    PaintPlate(guid)
end)
