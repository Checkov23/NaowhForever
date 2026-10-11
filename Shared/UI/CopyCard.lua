-- CopyCard.lua: the copy cards, an ID with its Wowhead links (ns.ShowCopyCard) or one line (ns.ShowCopyLine).
local ns = _G.NaowhForever

local T = ns.THEME

local CARD_W = 500
local ACCENT_H = 2
local PAD = 18
local ICON_SIZE, ICON_Y = 40, -20
local ICON_CROP = ns.Shared.Style.ICON_CROP
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local TEXT_X = 70
local KICKER_SIZE, KICKER_Y = 10, -20
local NAME_SIZE, NAME_Y, NAME_RIGHT = 16, -38, -44
local CLOSE_SIZE, CLOSE_INSET = 24, 10
local BOX_W, BOX_H, BOX_INSET = 464, 36, 10
local HINT_SIZE, HINT_BELOW = 12, 49
local ID_CARD_H, ID_BOX_Y = 230, -112
local NOTE_SIZE, NOTE_Y = 10, -187
local LINE_CARD_H, LINE_BOX_Y = 150, -76
local BUTTONS_Y, BUTTON_H, BUTTON_GAP = -76, 26, 8
local ID_BUTTON_W, LINK_BUTTON_W, CLASSIC_BUTTON_W = 170, 140, 90
local WOWHEAD = "https://www.wowhead.com/"
local WOWHEAD_FOREVER, WOWHEAD_CLASSIC = "forever/", "classic/"
local TEXT_IN_COMBAT = ns.L("Copy cards are available outside combat.")
local TEXT_HINT = ns.L("Text selected. Press Ctrl+C to copy.")
local TEXT_NOTE = ns.L("Open the link in your browser. No page on Forever's Wowhead yet? Try Classic.")
local TEXT_ID_KICKER = "NAOWH  /  TOOLTIP COPY"
local TEXT_LINE_KICKER = "NAOWH  /  COPY"
local TEXT_LINK, TEXT_CLASSIC = ns.L("Wowhead Link"), ns.L("Classic")

local function Accessible(value)
    if issecretvalue and issecretvalue(value) then return false end
    return not canaccessvalue or canaccessvalue(value)
end

local function URL(kind, id, classic)
    return WOWHEAD .. (classic and WOWHEAD_CLASSIC or WOWHEAD_FOREVER) .. kind .. "=" .. tostring(id)
end

local function NewAccent(p)
    return ns.Solid(p, "OVERLAY", T.accent, 1)
end

local function NewIcon(p)
    return p:CreateTexture(nil, "ARTWORK")
end

local function NewBox(p)
    local edit = ns.NewEditBox(p, { inset = BOX_INSET, border = T.line, hover = false, sunken = false })
    edit:SetMultiLine(false)
    return edit
end

local function CardHead(panel, texture, kickerText, title)
    local UI = ns.UI
    local accent = UI.Keep(panel, "accent", NewAccent)
    accent:SetPoint("TOPLEFT"); accent:SetPoint("TOPRIGHT"); accent:SetHeight(ACCENT_H)
    local icon = UI.Keep(panel, "icon", NewIcon)
    icon:SetSize(ICON_SIZE, ICON_SIZE); icon:SetPoint("TOPLEFT", PAD, ICON_Y)
    icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    icon:SetTexture(texture or DEFAULT_ICON)
    local kicker = UI.KeepFont(panel, "kicker", KICKER_SIZE, "OUTLINE", T.accent)
    kicker:SetPoint("TOPLEFT", TEXT_X, KICKER_Y); kicker:SetText(ns.L(kickerText))
    local name = UI.KeepFont(panel, "name", NAME_SIZE, "OUTLINE")
    name:SetPoint("TOPLEFT", TEXT_X, NAME_Y); name:SetPoint("RIGHT", NAME_RIGHT, 0)
    name:SetJustifyH("LEFT"); name:SetWordWrap(false); name:SetText(title)
end

local function Card(key, height, texture, kickerText, title, boxY)
    local UI = ns.UI
    local dimmer, panel = ns.MakeModal(CARD_W, height, key)
    CardHead(panel, texture, kickerText, title)
    UI.KeepButton(panel, "close", "X", CLOSE_SIZE, CLOSE_SIZE, function() dimmer:Hide() end)
        :SetPoint("TOPRIGHT", -CLOSE_INSET, -CLOSE_INSET)
    local box = UI.Keep(panel, "value", NewBox)
    box:SetPoint("TOPLEFT", PAD, boxY); box:SetSize(BOX_W, BOX_H)
    box:SetScript("OnEscapePressed", function() box:ClearFocus(); dimmer:Hide() end)
    local hint = UI.KeepFont(panel, "hint", HINT_SIZE, nil, T.muted)
    hint:SetPoint("TOPLEFT", PAD, boxY - HINT_BELOW); hint:SetText(TEXT_HINT)
    return dimmer, panel, box
end

local function CardTexture(kind, id)
    local texture
    if kind == "spell" then texture = C_Spell.GetSpellTexture(id)
    elseif kind == "item" then texture = C_Item.GetItemIconByID(id) end
    if not Accessible(texture) then texture = nil end
    return texture
end

function ns.ShowCopyCard(kind, label, id, title, mode, onClose)
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT); return end
    local UI = ns.UI
    local dimmer, panel, box = Card("tooltipCopy", ID_CARD_H, CardTexture(kind, id), TEXT_ID_KICKER,
        title or label, ID_BOX_Y)
    local note = UI.KeepFont(panel, "note", NOTE_SIZE, nil, T.muted)
    note:SetPoint("TOPLEFT", PAD, NOTE_Y); note:SetWidth(BOX_W); note:SetJustifyH("LEFT")
    note:SetText(TEXT_NOTE)
    local buttons
    local function Select(pick)
        box:SetText(pick == "id" and tostring(id) or URL(kind, id, pick == "classic"))
        for key, button in pairs(buttons) do
            local color = key == pick and T.accent or T.muted
            button.label:SetTextColor(color.r, color.g, color.b)
        end
        box:SetFocus(); box:HighlightText()
    end
    buttons = {
        id = UI.KeepButton(panel, "id", label .. ": " .. id, ID_BUTTON_W, BUTTON_H, function() Select("id") end),
        url = UI.KeepButton(panel, "link", TEXT_LINK, LINK_BUTTON_W, BUTTON_H, function() Select("url") end),
        classic = UI.KeepButton(panel, "classic", TEXT_CLASSIC, CLASSIC_BUTTON_W, BUTTON_H,
            function() Select("classic") end),
    }
    buttons.id:SetPoint("TOPLEFT", PAD, BUTTONS_Y)
    buttons.url:SetPoint("LEFT", buttons.id, "RIGHT", BUTTON_GAP, 0)
    buttons.classic:SetPoint("LEFT", buttons.url, "RIGHT", BUTTON_GAP, 0)
    dimmer.onClose = function()
        box:ClearFocus()
        if onClose then onClose() end
    end
    dimmer:Show(); Select(mode or ns.QoLSettings.Get("tooltipCopyFormat"))
end

function ns.ShowCopyLine(title, text, texture)
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT); return end
    local dimmer, _, box = Card("copyLine", LINE_CARD_H, texture, TEXT_LINE_KICKER, title, LINE_BOX_Y)
    box:SetText(text)
    dimmer.onClose = function() box:ClearFocus() end
    dimmer:Show()
    box:SetFocus(); box:HighlightText()
end
