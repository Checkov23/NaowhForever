-- MiniBar.lua: the planner's mini bar: your next trainer visit and your gold, to leave up while you level.
local ns = _G.NaowhForever

local T = ns.THEME

local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Rows = Training.Rows
local Place = Training.Place
local Parts = ns.Shared.Parts

local MINI_W, MINI_H, MINI_PAD, MINI_LOGO = 340, 74, 10, 16
local POSITION_KEY = "trainingMini"
local HOME = { "TOP", UIParent, "TOP", 0, -60 }
local LABEL_GAP = 6
local CLOSE, CLOSE_EDGE = 18, 6
local OPEN_W, OPEN_GAP = 56, 4
local COST_DROP = 8
local GOLD_DROP = 9
local BAR_H = 4
local FONT_LABEL, FONT_GOLD, FONT_COST = 11, 13, 15
local TEXT_VISIT_AT, TEXT_TRAIN_NOW, TEXT_VISIT = ns.L("NEXT VISIT, LEVEL "), ns.L("TRAIN NOW"), ns.L("NEXT VISIT")
local TEXT_ONE_SPELL, TEXT_SPELLS = ns.L(" spell"), ns.L(" spells")
local TEXT_NOTHING_LEFT = ns.L("Nothing left to learn")
local TEXT_CLOSE, TEXT_OPEN = "x", ns.L("Open")

local mini
local miniCost = 0

local function PaintGold()
    local cost, gold = miniCost, GetMoney()
    mini.gold:SetText(Training.Coins(gold))
    local fill = cost > 0 and math.min(1, gold / cost) or 0
    mini.fill:SetShown(fill > 0)
    mini.fill:SetWidth(math.max(1, (MINI_W - 2 * MINI_PAD) * fill))
    local c = gold >= cost and T.accent or Style.WARN_RGB
    mini.fill:SetColorTexture(c.r, c.g, c.b, 1)
end

local function Render()
    if not (mini and mini:IsShown()) then return end
    local plan = Training.Plan()
    local list, atLevel = Training.Spells.NextVisit(plan)
    local cost = Training.Total(list)
    miniCost = cost
    mini.label:SetText(atLevel and (TEXT_VISIT_AT .. atLevel) or (#list > 0 and TEXT_TRAIN_NOW or TEXT_VISIT))
    mini.cost:SetText(#list > 0 and (Training.Coins(cost) .. "  "
        .. ns.Color("muted", #list .. (#list == 1 and TEXT_ONE_SPELL or TEXT_SPELLS))) or TEXT_NOTHING_LEFT)
    mini.track:SetShown(cost > 0)
    PaintGold()
end

local function OnDragStop(self)
    self:StopMovingOrSizing()
    Place.Save(self, MINI_W, MINI_H, POSITION_KEY)
end

local function OnShow(self)
    self:RegisterEvent("PLAYER_MONEY")
    Render()
end

local function OnHide(self)
    self:UnregisterEvent("PLAYER_MONEY")
end

local function BuildTop()
    local logo = mini:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO, nil, nil, "TRILINEAR")
    logo:SetSize(MINI_LOGO, MINI_LOGO)
    logo:SetPoint("TOPLEFT", MINI_PAD, -MINI_PAD)
    mini.label = Rows.Text(mini, FONT_LABEL, nil, T.muted)
    mini.label:SetPoint("LEFT", logo, "RIGHT", LABEL_GAP, 0)
    local close = ns.Button(mini, TEXT_CLOSE, CLOSE, CLOSE, function() S.Set("miniShown", false) end)
    close:SetPoint("TOPRIGHT", -CLOSE_EDGE, -CLOSE_EDGE)
    local open = ns.Button(mini, TEXT_OPEN, OPEN_W, CLOSE, function() ns.OpenTrainingWindow() end)
    open:SetPoint("RIGHT", close, "LEFT", -OPEN_GAP, 0)
    mini.cost = Rows.Text(mini, FONT_COST, nil)
    mini.cost:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -COST_DROP)
    mini.gold = Rows.Text(mini, FONT_GOLD, nil)
    mini.gold:SetPoint("TOPRIGHT", -MINI_PAD, -(MINI_PAD + MINI_LOGO + GOLD_DROP))
end

local function Build()
    mini = CreateFrame("Frame", nil, UIParent)
    mini:SetSize(MINI_W, MINI_H)
    mini:SetFrameStrata("MEDIUM")
    mini:SetClampedToScreen(true)
    ns.AllowOffscreen(mini)
    mini:SetMovable(true)
    mini:EnableMouse(true)
    mini:RegisterForDrag("LeftButton")
    mini:SetScript("OnDragStart", mini.StartMoving)
    mini:SetScript("OnDragStop", OnDragStop)
    Place.Restore(mini, POSITION_KEY, HOME)
    Parts.Backdrop(mini):Paint(1)
    ns.Border(mini, Style.BORDER_RGB)
    BuildTop()
    mini.track = ns.Solid(mini, "ARTWORK", T.line, 1)
    mini.track:SetPoint("BOTTOMLEFT", MINI_PAD, MINI_PAD)
    mini.track:SetPoint("BOTTOMRIGHT", -MINI_PAD, MINI_PAD)
    mini.track:SetHeight(BAR_H)
    mini.fill = mini:CreateTexture(nil, "OVERLAY")
    mini.fill:SetPoint("TOPLEFT", mini.track)
    mini.fill:SetHeight(BAR_H)
    mini:SetScript("OnShow", OnShow)
    mini:SetScript("OnHide", OnHide)
    mini:SetScript("OnEvent", PaintGold)
    mini:Hide()
end

local function Apply()
    local want = S.Get("enabled") and S.Get("miniShown")
    if want and not mini then Build() end
    if not mini then return end
    if want then
        mini:SetScale(ns.UIScale())
        Place.Snap(mini, MINI_W, MINI_H)
        mini:Show()
    else
        mini:Hide()
    end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "miniShown" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

Training.OnChange(Render)
S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
