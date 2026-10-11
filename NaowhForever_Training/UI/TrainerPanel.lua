-- TrainerPanel.lua: Panel at the Trainer: beside your class trainer, what you can learn now, ticked, and Learn All.
local ns = _G.NaowhForever

local T = ns.THEME

local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Rows = Training.Rows

local PANEL_W, PANEL_PAD = 380, 10
local PANEL_HEADER = 40
local OFFER_H, OFFER_ICON, MAX_OFFERS = 34, 26, 10
local OFFER_GAP = 2
local LIST_GAP = 4
local CHECK = 16
local CHECK_X, TICK_INSET = 4, 4
local ICON_GAP, NAME_GAP = 10, 8
local PRICE_RIGHT = 4
local FOOTER_H = 92
local BARS_H = 32
local EMPTY_H = 44
local LIST_END = 8
local LOGO = 20
local TITLE_GAP, COUNT_GAP = 8, 10
local CLOSE = 20
local TOTAL_DROP = 12
local LEARN_H, BARS_BUTTON_H = 30, 26
local BARS_GAP = 6
local DONE_DROP = 14
local PANEL_GAP = 8
local SERVICE_LEVEL = 4
local FONT_SMALL, FONT, FONT_ROW, FONT_TITLE = Style.FONT_SMALL, Style.FONT, Style.FONT_ROW, 15
local TRAINER_ADDON = "Blizzard_TrainerUI"
local PANEL_EVENTS = { "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "PLAYER_MONEY", "ADDON_LOADED" }
local TEXT_TITLE = ns.L("Train Now")
local TEXT_CLOSE = "x"
local TEXT_LEARN_ALL = ns.L("Learn All")
local TEXT_BARS = ns.L("Put the New Ranks on My Bars")
local TEXT_LEVEL = ns.L("Level ")
local TEXT_LEAVE_OUT = ns.L("Click to leave it out of Learn All.")
local TEXT_PICKED = ns.L("%d of %d picked")
local TEXT_PICKED_COST = ns.L("Picked  ")
local TEXT_LEAVES = ns.L("Leaves ")
local TEXT_SHORT = ns.L(" short")
local TEXT_LEARN_AFFORD = ns.L("Learn All I Can Afford (%d)  %s")
local TEXT_NOTHING_AFFORD = ns.L("Nothing You Can Afford")
local TEXT_LEARNED_ONE = ns.L("Learned %d spell. Nothing else to train here for now.")
local TEXT_LEARNED = ns.L("Learned %d spells. Nothing else to train here for now.")
local TEXT_NOTHING = ns.L("Nothing to train here for now.")

local panel
local unpicked = {}
local learned = 0
local panelQueued = false
local hookedTrainer
local events = CreateFrame("Frame")
local Render

local function On()
    return Training.On() and S.Get("trainerPanel")
end

local function Key(offer)
    return offer.name .. "|" .. offer.level
end

local function Picked(offer)
    local left = unpicked[Key(offer)]
    if left == nil then return not (offer.spell and Training.Ignored()[offer.spell]) end
    return not left
end

local function Offers()
    local byKey = Training.SpellsByService()
    local out, myLevel = {}, UnitLevel("player")
    for i = 1, GetNumTrainerServices() do
        local name, kind, icon = ns.TrainerServiceInfo(i)
        local level = select(SERVICE_LEVEL, GetTrainerServiceInfo(i)) or 0
        local spell = Training.ServiceSpell(byKey, i)
        local open = kind == "available"
            or kind == nil and level <= myLevel and not (spell and C_SpellBook.IsSpellKnown(spell))
        if name and level > 0 and open then
            out[#out + 1] = { index = i, name = name, level = level, icon = icon, spell = spell,
                cost = GetTrainerServiceCost(i) or 0 }
        end
    end
    return out
end

local function Affordable(offers)
    local out, budget = {}, GetMoney()
    for _, offer in ipairs(offers) do
        if Picked(offer) and offer.cost <= budget then
            out[#out + 1] = offer
            budget = budget - offer.cost
        end
    end
    return out
end

local function ClassServices()
    local count = GetNumTrainerServices()
    if count == 0 then return true end
    local byKey = Training.SpellsByService()
    for i = 1, count do
        if Training.ServiceSpell(byKey, i) then return true end
    end
    return false
end

local function LastFirst(a, b)
    return a.index > b.index
end

local function LearnAll()
    local buy = Affordable(panel.offers)
    table.sort(buy, LastFirst)
    for _, offer in ipairs(buy) do
        if ns.TrainerServiceInfo(offer.index) == offer.name then
            BuyTrainerService(offer.index)
            learned = learned + 1
        end
    end
    Render()
end

local function CheckPaint(row)
    local on = Picked(row.offer)
    row.tick:SetShown(on)
    local c = on and T.accent or T.line
    row.box:SetColor(c.r, c.g, c.b, 1)
    row:SetAlpha(on and 1 or Style.UNPICKED_ALPHA)
end

local function OnOfferClick(self)
    unpicked[Key(self.offer)] = Picked(self.offer)
    Render()
end

local function OnOfferEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetTrainerService(self.offer.index)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TEXT_LEAVE_OUT, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function NewOffer(i)
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(PANEL_W - 2 * PANEL_PAD, OFFER_H - OFFER_GAP)
    row:SetPoint("TOPLEFT", PANEL_PAD, -(PANEL_HEADER + LIST_GAP + (i - 1) * OFFER_H))
    local check = CreateFrame("Frame", nil, row)
    check:SetSize(CHECK, CHECK)
    check:SetPoint("LEFT", CHECK_X, 0)
    ns.Solid(check, "BACKGROUND", T.panel, 1):SetAllPoints()
    row.box = ns.Border(check, T.line)
    row.tick = ns.Solid(check, "ARTWORK", T.accent, 1)
    row.tick:SetPoint("TOPLEFT", TICK_INSET, -TICK_INSET)
    row.tick:SetPoint("BOTTOMRIGHT", -TICK_INSET, TICK_INSET)
    row.icon = Rows.Crop(row:CreateTexture(nil, "ARTWORK"))
    row.icon:SetSize(OFFER_ICON, OFFER_ICON)
    row.icon:SetPoint("LEFT", check, "RIGHT", ICON_GAP, 0)
    row.price = ns.Font(row, FONT_ROW, nil)
    row.price:SetPoint("RIGHT", -PRICE_RIGHT, 0)
    row.name = ns.Font(row, FONT_ROW, nil)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", NAME_GAP, 0)
    row.name:SetPoint("RIGHT", row.price, "LEFT", -NAME_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.rank = ns.Font(row, FONT_SMALL, nil, T.muted)
    row.rank:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", NAME_GAP, 0)
    row:SetScript("OnClick", OnOfferClick)
    row:SetScript("OnEnter", OnOfferEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    panel.rows[i] = row
    return row
end

local function Dismiss()
    panel.dismissed = true
    panel:Hide()
end

local function BuildHeader()
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO_FILE, nil, nil, "TRILINEAR")
    logo:SetSize(LOGO, LOGO)
    logo:SetPoint("LEFT", panel, "TOPLEFT", PANEL_PAD, -PANEL_HEADER / 2)
    local title = ns.Font(panel, FONT_TITLE, nil)
    title:SetPoint("LEFT", logo, "RIGHT", TITLE_GAP, 0)
    title:SetText(TEXT_TITLE)
    panel.close = ns.Button(panel, TEXT_CLOSE, CLOSE, CLOSE, Dismiss)
    panel.close:SetPoint("RIGHT", panel, "TOPRIGHT", -PANEL_PAD, -PANEL_HEADER / 2)
    panel.count = ns.Font(panel, FONT, nil, T.muted)
    panel.count:SetPoint("RIGHT", panel.close, "LEFT", -COUNT_GAP, 0)
    local rule = ns.Solid(panel, "ARTWORK", T.line, 1)
    rule:SetPoint("TOPLEFT", 0, -PANEL_HEADER)
    rule:SetPoint("TOPRIGHT", 0, -PANEL_HEADER)
    ns.Hairline(rule, "h")
end

local function RankCheck()
    if ns.TrainerRankCheck then ns.TrainerRankCheck() end
end

local function BuildFooter()
    panel.footer = CreateFrame("Frame", nil, panel)
    panel.footer:SetPoint("BOTTOMLEFT")
    panel.footer:SetPoint("BOTTOMRIGHT")
    panel.footer:SetHeight(FOOTER_H)
    local footRule = ns.Solid(panel.footer, "ARTWORK", T.line, 1)
    footRule:SetPoint("TOPLEFT")
    footRule:SetPoint("TOPRIGHT")
    ns.Hairline(footRule, "h")
    panel.total = ns.Font(panel.footer, FONT_ROW, nil)
    panel.total:SetPoint("TOPLEFT", PANEL_PAD, -TOTAL_DROP)
    panel.note = ns.Font(panel.footer, FONT, nil, T.muted)
    panel.note:SetPoint("TOPRIGHT", -PANEL_PAD, -TOTAL_DROP)
    panel.learn = ns.AccentBorder(ns.Button(panel.footer, TEXT_LEARN_ALL, PANEL_W - 2 * PANEL_PAD, LEARN_H, LearnAll))
    panel.learn:SetPoint("BOTTOMLEFT", PANEL_PAD, PANEL_PAD)
    panel.bars = ns.Button(panel.footer, TEXT_BARS, PANEL_W - 2 * PANEL_PAD, BARS_BUTTON_H, RankCheck)
end

local function Build()
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetWidth(PANEL_W)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    ns.Solid(panel, "BACKGROUND", T.bg, Style.BACKDROP_ALPHA):SetAllPoints()
    ns.Border(panel, Style.BORDER_RGB)
    BuildHeader()
    panel.rows = {}
    BuildFooter()
    panel.done = ns.Font(panel, FONT_ROW, nil, T.muted)
    panel.done:SetPoint("TOPLEFT", PANEL_PAD, -(PANEL_HEADER + DONE_DROP))
    panel.done:SetWidth(PANEL_W - 2 * PANEL_PAD)
    panel.done:SetJustifyH("LEFT")
    panel:Hide()
end

local function FillRows(offers)
    local shown = math.min(#offers, MAX_OFFERS)
    for i = 1, shown do
        local row = panel.rows[i] or NewOffer(i)
        local offer = offers[i]
        row.offer = offer
        row.icon:SetTexture(offer.icon or offer.spell and C_Spell.GetSpellTexture(offer.spell))
        row.name:SetText(offer.name)
        row.rank:SetText(offer.spell and C_Spell.GetSpellSubtext(offer.spell) or (TEXT_LEVEL .. offer.level))
        row.price:SetText(Training.Coins(offer.cost))
        CheckPaint(row)
        row:Show()
    end
    for i = shown + 1, #panel.rows do panel.rows[i]:Hide() end
    return shown
end

local function FillTotals(offers)
    local picked, pickedCost = 0, 0
    for _, offer in ipairs(offers) do
        if Picked(offer) then
            picked = picked + 1
            pickedCost = pickedCost + offer.cost
        end
    end
    local buy = Affordable(offers)
    local buyCost = 0
    for _, offer in ipairs(buy) do buyCost = buyCost + offer.cost end
    panel.count:SetText(#offers > 0 and TEXT_PICKED:format(picked, #offers) or "")
    panel.total:SetText(TEXT_PICKED_COST .. Training.Coins(pickedCost))
    local gold = GetMoney()
    panel.note:SetText(gold >= pickedCost and (TEXT_LEAVES .. Training.Coins(gold - pickedCost))
        or (Training.Coins(pickedCost - gold) .. TEXT_SHORT))
    local c = gold >= pickedCost and T.muted or Style.WARN_RGB
    panel.note:SetTextColor(c.r, c.g, c.b, 1)
    ns.SetButtonText(panel.learn, #buy > 0
        and TEXT_LEARN_AFFORD:format(#buy, Training.Coins(buyCost)) or TEXT_NOTHING_AFFORD)
    panel.learn:SetEnabled(#buy > 0)
    panel.learn:SetAlpha(#buy > 0 and 1 or Style.DISABLED_ALPHA)
end

local function FillFooter(any, shown)
    local hasBars = learned > 0 and ns.TrainerRankCheck ~= nil
    panel.done:SetShown(not any)
    panel.done:SetText(learned > 0 and (learned == 1 and TEXT_LEARNED_ONE or TEXT_LEARNED):format(learned) or TEXT_NOTHING)
    panel.total:SetShown(any)
    panel.note:SetShown(any)
    panel.learn:SetShown(any)
    panel.bars:SetShown(hasBars)
    panel.bars:ClearAllPoints()
    if any then
        panel.bars:SetPoint("BOTTOMLEFT", panel.learn, "TOPLEFT", 0, BARS_GAP)
    else
        panel.bars:SetPoint("BOTTOMLEFT", PANEL_PAD, PANEL_PAD)
    end
    local footer = (any and FOOTER_H or PANEL_PAD) + (hasBars and BARS_H or 0)
    panel.footer:SetHeight(footer)
    panel:SetHeight(PANEL_HEADER + (any and (shown * OFFER_H + LIST_END) or EMPTY_H) + footer)
end

Render = function()
    local frame = _G.ClassTrainerFrame
    if not (On() and frame and frame:IsShown()) or IsTradeskillTrainer() or not ClassServices() then
        return panel and panel:Hide()
    end
    if not panel then Build() end
    if panel.dismissed then return end
    local offers = Offers()
    panel.offers = offers
    local shown = FillRows(offers)
    FillTotals(offers)
    FillFooter(#offers > 0, shown)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", PANEL_GAP, 0)
    panel:Show()
end

local function RunQueued()
    panelQueued = false
    Render()
end

local function Queue()
    if panelQueued then return end
    panelQueued = true
    C_Timer.After(0, RunQueued)
end

local function OnFrameShow()
    if On() then Queue() end
end

local function OnFrameHide()
    if panel then panel:Hide() end
end

local function HookTrainerFrame()
    local frame = _G.ClassTrainerFrame
    if hookedTrainer or not frame then return end
    hookedTrainer = true
    frame:HookScript("OnShow", OnFrameShow)
    frame:HookScript("OnHide", OnFrameHide)
end

local function OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == TRAINER_ADDON then HookTrainerFrame() end
    elseif event == "TRAINER_SHOW" then
        wipe(unpicked)
        learned = 0
        if panel then panel.dismissed = nil end
        HookTrainerFrame()
        Queue()
    elseif event == "TRAINER_CLOSED" then
        if panel then panel:Hide() end
    else
        Queue()
    end
end

local function Apply()
    events:UnregisterAllEvents()
    if panel and not On() then panel:Hide() end
    if not On() then return end
    for _, event in ipairs(PANEL_EVENTS) do events:RegisterEvent(event) end
    HookTrainerFrame()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "trainerPanel" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

events:SetScript("OnEvent", OnEvent)
S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
