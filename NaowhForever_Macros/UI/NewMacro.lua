-- NewMacro.lua: the New Macro dialog on the Library tab: a name and its text, kept in the Library under your class and, if you ask, added to this character.
local ns = _G.NaowhForever
local T = ns.THEME

local M = ns.Macros
local C = M.C
local St = M.Style
local F = M.Forge

local LIMIT, NAME_MAX = C.LIMIT, C.NAME_MAX
local PAD, GAP = St.PAD, 8
local SMALL_SIZE, TITLE_SIZE = St.SMALL_SIZE, 16
local PANEL_W, PANEL_H = 480, 380
local NAME_LABEL_Y, NAME_Y, NAME_H = 46, 64, 26
local BODY_LABEL_Y, BODY_Y, BODY_H = 100, 118, 160
local SCROLL_ROOM = 22
local METER_Y, HELP_Y = 284, 304
local BUTTON_W, BUTTON_H = 140, St.BUTTON_H

local TEXT_TITLE = ns.L("New Macro")
local TEXT_NAME = ns.L("Name")
local TEXT_BODY = ns.L("Text")
local TEXT_METER = ns.L("%d / %d bytes")
local TEXT_HELP = ns.L("Kept in your Library for every %s you play. Save and Add also makes it one of this "
    .. "character's macros.")
local TEXT_SAVE, TEXT_SAVE_ADD, TEXT_CANCEL = ns.L("Save to Library"), ns.L("Save and Add"), ns.L("Cancel")

local dialog

local function ClearFocus(self) self:ClearFocus() end

local function Label(panel, y, text)
    local label = ns.Font(panel, SMALL_SIZE, nil, T.muted)
    label:SetPoint("TOPLEFT", PAD, -y)
    label:SetText(text)
    return label
end

local function FollowCursor(self, _, y, _, h)
    local scroll = self:GetParent()
    local top, view, at = -y, scroll:GetHeight(), scroll:GetVerticalScroll()
    if top < at then
        scroll:SetVerticalScroll(top)
    elseif top + h > at + view then
        scroll:SetVerticalScroll(top + h - view)
    end
end

local function Meter()
    dialog.meter:SetText(TEXT_METER:format(#dialog.body:GetText(), LIMIT))
end

local function NewBody(panel)
    local scroll = ns.UI.SlimScroll(panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -BODY_Y)
    scroll:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(PAD + SCROLL_ROOM), -BODY_Y)
    scroll:SetHeight(BODY_H)
    ns.Solid(scroll, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(scroll)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetMaxBytes(LIMIT + 1)
    box:SetWidth(1)
    box:SetHeight(BODY_H)
    box:SetScript("OnEscapePressed", ClearFocus)
    box:SetScript("OnTextChanged", Meter)
    box:SetScript("OnCursorChanged", FollowCursor)
    scroll:SetScrollChild(box)
    scroll:SetScript("OnSizeChanged", function(_, w) box:SetWidth(w) end)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
    return box
end

local function Accept(andAdd)
    local macro = { name = strtrim(dialog.name:GetText()), body = strtrim(dialog.body:GetText()) }
    F.SaveToLibrary(macro, function()
        dialog.dimmer:Hide()
        if andAdd then F.Add({ name = macro.name, body = macro.body, own = true }) end
    end)
end

local function SaveOnly() Accept(false) end
local function SaveAndAdd() Accept(true) end
local function Cancel() dialog.dimmer:Hide() end

local function Build()
    local dimmer, panel = ns.MakeModal(PANEL_W, PANEL_H, "macroNew")
    local d = { dimmer = dimmer }
    local title = ns.Font(panel, TITLE_SIZE, "OUTLINE")
    title:SetPoint("TOP", 0, -PAD)
    title:SetText(TEXT_TITLE)
    Label(panel, NAME_LABEL_Y, TEXT_NAME)
    d.name = ns.NewEditBox(panel)
    d.name:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -NAME_Y)
    d.name:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -NAME_Y)
    d.name:SetHeight(NAME_H)
    d.name:SetMaxBytes(NAME_MAX + 1)
    d.name:SetScript("OnEscapePressed", ClearFocus)
    Label(panel, BODY_LABEL_Y, TEXT_BODY)
    d.body = NewBody(panel)
    d.meter = ns.Font(panel, SMALL_SIZE, nil, T.muted)
    d.meter:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -METER_Y)
    d.help = ns.Font(panel, SMALL_SIZE, nil, T.muted)
    d.help:SetPoint("TOPLEFT", PAD, -HELP_Y)
    d.help:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    d.help:SetJustifyH("LEFT")
    local save = ns.Button(panel, TEXT_SAVE, BUTTON_W, BUTTON_H, SaveOnly)
    save:SetPoint("BOTTOM", panel, "BOTTOM", -(BUTTON_W + GAP), PAD)
    local saveAdd = ns.Button(panel, TEXT_SAVE_ADD, BUTTON_W, BUTTON_H, SaveAndAdd)
    saveAdd:SetPoint("BOTTOM", panel, "BOTTOM", 0, PAD)
    local cancel = ns.Button(panel, TEXT_CANCEL, BUTTON_W, BUTTON_H, Cancel)
    cancel:SetPoint("BOTTOM", panel, "BOTTOM", BUTTON_W + GAP, PAD)
    return d
end

function F.NewMacro()
    dialog = dialog or Build()
    local _, class = UnitClass("player")
    dialog.name:SetText("")
    dialog.body:SetText("")
    dialog.help:SetText(TEXT_HELP:format(LOCALIZED_CLASS_NAMES_MALE[class] or class))
    Meter()
    dialog.dimmer:Show()
    dialog.name:SetFocus()
end
