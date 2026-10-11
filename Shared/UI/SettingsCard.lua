-- SettingsCard.lua: a module's card at the top of its settings page: the logo, a line or two on where you stand, and the button that opens its window (ns.Shared.Parts).
local ns = _G.NaowhForever
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local BORDER_RGB = St.BORDER_RGB
local CARD_H, CARD_PAD, CARD_ICON = 76, 16, 52
local CARD_BUTTON_W, CARD_BUTTON_H, CARD_LINE_GAP = 190, 30, 6
local HEADLINE_SIZE, DETAIL_SIZE = 15, St.TEXT_SIZE

local function Line(card, size, color, heading)
    local line = ns.Font(card, size, nil, color, heading)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(false)
    return line
end

local function OpenButton(card)
    return ns.AccentBorder(ns.Button(card, "", CARD_BUTTON_W, CARD_BUTTON_H, function()
        ns.OpenFromOptions(card.onOpen)
    end))
end

function Parts.SettingsCardFrame(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetHeight(CARD_H)
    ns.Solid(card, "BACKGROUND", T.fg, St.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(card, BORDER_RGB)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(CARD_ICON, CARD_ICON)
    card.icon:SetPoint("LEFT", CARD_PAD, 0)
    card.icon:SetTexture(St.LOGO, nil, nil, "TRILINEAR")
    card.open = OpenButton(card)
    card.open:SetPoint("RIGHT", -CARD_PAD, 0)
    card.headline = Line(card, HEADLINE_SIZE, ns.classicSkin and T.accent or T.fg, true)
    if ns.classicSkin then Parts.ClassicBox(card) end
    card.detail = Line(card, DETAIL_SIZE, T.muted)
    return card
end

function Parts.PaintSettingsCard(card, buttonText, onOpen, headline, detail)
    card.onOpen = onOpen
    card.open:SetShown(onOpen ~= nil)
    if onOpen then ns.SetButtonText(card.open, buttonText) end
    card.headline:SetText(ns.L(headline))
    card.detail:SetText(ns.L(detail) or "")
    card.detail:SetShown(detail ~= nil)
    local height = detail and HEADLINE_SIZE + CARD_LINE_GAP + DETAIL_SIZE or HEADLINE_SIZE
    local right, rightPoint = card.open, "LEFT"
    if not onOpen then right, rightPoint = card, "RIGHT" end
    card.headline:ClearAllPoints()
    card.headline:SetPoint("TOPLEFT", card.icon, "RIGHT", CARD_PAD, height / 2)
    card.headline:SetPoint("RIGHT", right, rightPoint, -CARD_PAD, 0)
    card.detail:ClearAllPoints()
    card.detail:SetPoint("TOPLEFT", card.headline, "BOTTOMLEFT", 0, -CARD_LINE_GAP)
    card.detail:SetPoint("RIGHT", right, rightPoint, -CARD_PAD, 0)
    return CARD_H
end

function Parts.SettingsCard(parent, y, key, buttonText, onOpen, headline, detail)
    local UI = ns.UI
    local card = UI.Keep(parent, key, Parts.SettingsCardFrame)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.CONTENT_PAD, y - CARD_PAD)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -UI.CONTENT_PAD, y - CARD_PAD)
    Parts.PaintSettingsCard(card, buttonText, onOpen, headline, detail)
    return y - CARD_H - CARD_PAD
end
