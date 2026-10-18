-- Popup.lua: the small window beside the trainer or the auction house: a title, rows with a button, a note.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local Style = P.Style
local Widgets = P.Widgets

local START_H = 80
local TITLE_X, TITLE_DROP = 10, 11
local CLOSE, CLOSE_EDGE = 20, 7
local NOTE_X, NOTE_BOTTOM = 10, 12
local ROW_H, TOP = 26, 36
local ROW_X = 10
local ROW_SHRINK = 2
local ICON_SHRINK = Style.ROW_ICON_SHRINK
local BUTTON_W, BUTTON_H = 64, 20
local NOTE_GAP = Style.NOTE_GAP
local NAME_GAP = Style.ICON_NAME_GAP
local FOOTER_H, BARE_FOOTER = 36, 14

local Popup = {}
P.Popup = Popup

local function PlaceShopping()
    if ns.ShoppingListPlace then ns.ShoppingListPlace() end
end

local function OnRowEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.item then
        GameTooltip:SetItemByID(self.item)
    elseif self.spell then
        GameTooltip:SetSpellByID(self.spell)
    end
    if self.onTooltip then self.onTooltip(self) end
    GameTooltip:Show()
end

function Popup.New(title)
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(Style.POPUP_W, START_H)
    p:SetFrameStrata("DIALOG")
    p:EnableMouse(true)
    p:SetClampedToScreen(true)
    ns.Solid(p, "BACKGROUND", T.bg, Style.WINDOW_ALPHA):SetAllPoints()
    ns.Border(p, Style.BORDER_RGB)
    p.title = ns.Font(p, Style.FONT_LARGE, nil, T.accent)
    p.title:SetPoint("TOPLEFT", TITLE_X, -TITLE_DROP)
    p.title:SetText(title)
    p.close = ns.Button(p, "X", CLOSE, CLOSE, function() p.dismissed = true; p:Hide() end)
    p.close:SetPoint("TOPRIGHT", -CLOSE_EDGE, -CLOSE_EDGE)
    p.note = ns.Font(p, Style.FONT_SMALL, nil, T.muted)
    p.note:SetPoint("BOTTOMLEFT", NOTE_X, NOTE_BOTTOM)
    p.note:SetJustifyH("LEFT")
    p.rows = {}
    p:HookScript("OnShow", PlaceShopping)
    p:HookScript("OnHide", PlaceShopping)
    p:Hide()
    return p
end

function Popup.Row(p, i, label, onClick, top)
    local row = p.rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, p)
    row:SetSize(Style.POPUP_W - 2 * ROW_X, ROW_H - ROW_SHRINK)
    row:SetPoint("TOPLEFT", ROW_X, -(top or TOP) - (i - 1) * ROW_H)
    row:EnableMouse(true)
    row.icon = Widgets.Crop(row:CreateTexture(nil, "ARTWORK"))
    row.icon:SetSize(ROW_H - ICON_SHRINK, ROW_H - ICON_SHRINK)
    row.icon:SetPoint("LEFT")
    row.button = ns.Button(row, label, BUTTON_W, BUTTON_H, function() onClick(row) end)
    row.button:SetPoint("RIGHT")
    row.note = ns.Font(row, Style.FONT, nil, T.muted)
    row.note:SetPoint("RIGHT", row.button, "LEFT", -NOTE_GAP, 0)
    row.note:SetJustifyH("RIGHT")
    row.name = ns.Font(row, Style.FONT, nil)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
    row.name:SetPoint("RIGHT", row.note, "LEFT", -NAME_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    p.rows[i] = row
    return row
end

function Popup.Fit(p, shown, footer, top)
    for i = shown + 1, #p.rows do p.rows[i]:Hide() end
    p:SetHeight((top or TOP) + shown * ROW_H + (footer and FOOTER_H or BARE_FOOTER))
end
