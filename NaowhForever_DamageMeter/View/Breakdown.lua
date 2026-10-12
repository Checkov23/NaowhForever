-- Breakdown.lua: the spells behind a hovered row, in a small panel beside it, in the theme's colors.
local ns = _G.NaowhForever

local UI = ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts
local DM = ns.DamageMeter
local S = DM.Settings
local C, Look, Format = DM.C, DM.Look, DM.Format
local CROP = ns.Shared.Style.ICON_CROP

local ROW_H, GAP, PAD, HEADER_H, NOTE_H = 18, 2, 6, 24, 22
local SECTION_GAP, SECTION_H = 6, 16
local TEXT_SIZE, TITLE_SIZE, ICON_PAD, VALUE_W = 11, 12, 2, 140
local SIDE_GAP = 6
local GRADIENT_TEX = ns.MEDIA .. "NaowhGradient.tga"

local TEXT_COMBAT, TEXT_NONE = C.TEXT_SPELLS_COMBAT, C.TEXT_SPELLS_NONE
local TEXT_TARGETS = "Targets"
local VALUE_PERCENT = "%s  %s"
local VALUE_RATE = "%s  %s"
local VALUE_FULL = "%s  %s  %s"
local VALUE_TARGET = "%s | %s"
local TEXT_SESSION = "%s (%s)"

local Breakdown = {}
DM.Breakdown = Breakdown

local panel

local function NewRow(pool, i, withIcon)
    local row = CreateFrame("StatusBar", nil, panel)
    row:SetMinMaxValues(0, 1)
    row:SetSize(C.MAX_PANEL_WIDTH - 2 * PAD, ROW_H)
    row.value = ns.Font(row, TEXT_SIZE, "OUTLINE", T.fg)
    row.value:SetPoint("RIGHT", -PAD, 0); row.value:SetWidth(VALUE_W); row.value:SetJustifyH("RIGHT")
    row.name = ns.Font(row, TEXT_SIZE, "OUTLINE", T.fg)
    if withIcon then
        row.icon = row:CreateTexture(nil, "OVERLAY")
        row.icon:SetPoint("LEFT", ICON_PAD, 0); row.icon:SetSize(ROW_H - 2 * ICON_PAD, ROW_H - 2 * ICON_PAD)
        row.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_PAD + 2, 0)
    else
        row.name:SetPoint("LEFT", PAD, 0)
    end
    row.name:SetPoint("RIGHT", row.value, "LEFT", -PAD, 0)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    pool[i] = row
    return row
end

local function PlaceRow(row, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
end

local function Build()
    panel = CreateFrame("Frame", "NaowhForeverDamageMeterBreakdown", UIParent)
    panel:SetFrameStrata("TOOLTIP"); panel:SetClampedToScreen(true)
    panel.rows, panel.targetRows = {}, {}
    panel.background = ns.Solid(panel, "BACKGROUND", T.bg, 1)
    panel.background:SetAllPoints()
    panel.border = ns.Border(panel)
    panel.subtitle = ns.Font(panel, TEXT_SIZE, "OUTLINE", T.muted)
    panel.subtitle:SetPoint("TOPRIGHT", -PAD, -PAD)
    panel.subtitle:SetJustifyH("RIGHT"); panel.subtitle:SetWordWrap(false)
    panel.title = ns.Font(panel, TITLE_SIZE, "OUTLINE", T.fg)
    panel.title:SetPoint("TOPLEFT", PAD, -PAD); panel.title:SetPoint("RIGHT", panel.subtitle, "LEFT", -PAD, 0)
    panel.title:SetJustifyH("LEFT"); panel.title:SetWordWrap(false)
    panel.note = ns.Font(panel, TEXT_SIZE, "OUTLINE", T.muted)
    panel.note:SetPoint("TOPLEFT", PAD, -HEADER_H)
    panel.targetsTitle = ns.Font(panel, TEXT_SIZE, "OUTLINE", T.muted)
    panel.targetsTitle:SetText(TEXT_TARGETS)
    for i = 1, C.BREAKDOWN_MAX do NewRow(panel.rows, i, true) end
    for i = 1, C.TARGET_MAX do NewRow(panel.targetRows, i, false) end
    panel:Hide()
end

local function PaintIcon(icon, spell)
    local texture = DM.SpellIcon(spell)
    if texture ~= nil then icon:SetTexture(texture) end
    icon:SetShown(texture ~= nil)
end

local function PaintRow(row, spell, data, color, alpha, seconds)
    row:SetStatusBarTexture(UI.TexturePath(S.Get("texture"), GRADIENT_TEX))
    row:SetStatusBarColor(color.r, color.g, color.b, alpha)
    row:SetMinMaxValues(0, data.maxAmount)
    row:SetValue(spell.totalAmount)
    PaintIcon(row.icon, spell)
    row.name:SetText(DM.SpellName(spell))
    local amount = Format(spell.totalAmount)
    local percent = DM.Percent(spell.totalAmount, data.totalAmount)
    local rate = seconds and DM.PerSecond(spell.totalAmount, seconds)
    if rate and percent then
        row.value:SetFormattedText(VALUE_FULL, amount, Format(rate) .. DM.RateSuffix(), DM.PercentText(percent))
    elseif rate then
        row.value:SetFormattedText(VALUE_RATE, amount, Format(rate) .. DM.RateSuffix())
    elseif percent then
        row.value:SetFormattedText(VALUE_PERCENT, amount, DM.PercentText(percent))
    else
        row.value:SetText(amount)
    end
    row:Show()
end

local function Style()
    local font, outline = S.Get("font"), S.Get("outline")
    local name, value, rank = Look.Color("nameColor"), Look.Color("valueColor"), Look.Color("rankColor")
    local title = Look.Color("titleColor")
    local window, border = Look.Color("windowColor"), Look.Color("borderColor")
    panel.background:SetColorTexture(window.r, window.g, window.b, 1)
    panel.border:SetColor(border.r, border.g, border.b, 1)
    panel.border._frame:SetShown(S.Get("showBorder"))
    Parts.HudFont(panel.title, font, TITLE_SIZE, outline)
    panel.title:SetTextColor(title.r, title.g, title.b)
    Parts.HudFont(panel.note, font, TEXT_SIZE, outline)
    panel.note:SetTextColor(rank.r, rank.g, rank.b)
    Parts.HudFont(panel.subtitle, font, TEXT_SIZE, outline)
    panel.subtitle:SetTextColor(rank.r, rank.g, rank.b)
    Parts.HudFont(panel.targetsTitle, font, TEXT_SIZE, outline)
    panel.targetsTitle:SetTextColor(rank.r, rank.g, rank.b)
    for _, pool in ipairs({ panel.rows, panel.targetRows }) do
        for _, row in ipairs(pool) do
            Parts.HudFont(row.name, font, TEXT_SIZE, outline)
            Parts.HudFont(row.value, font, TEXT_SIZE, outline)
            row.name:SetTextColor(name.r, name.g, name.b)
            row.value:SetTextColor(value.r, value.g, value.b)
        end
    end
end

local function PaintTarget(row, target, largest, seconds, alpha)
    local c = C.ENEMY_COLOR
    row:SetStatusBarTexture(UI.TexturePath(S.Get("texture"), GRADIENT_TEX))
    row:SetStatusBarColor(c.r, c.g, c.b, alpha)
    row:SetMinMaxValues(0, largest)
    row:SetValue(target.total)
    row.name:SetText(target.name)
    local perSecond = DM.PerSecond(target.total, seconds)
    if perSecond then
        row.value:SetFormattedText(VALUE_TARGET, Format(target.total), Format(perSecond))
    else
        row.value:SetText(Format(target.total))
    end
    row:Show()
end

local function Place(owner, toRight)
    local side = S.Get("panelSide")
    if side == "left" then toRight = false elseif side == "right" then toRight = true end
    panel:ClearAllPoints()
    if toRight then
        panel:SetPoint("TOPLEFT", owner, "TOPRIGHT", SIDE_GAP, 0)
    else
        panel:SetPoint("TOPRIGHT", owner, "TOPLEFT", -SIDE_GAP, 0)
    end
end

function Breakdown.Show(row, source, data, view)
    if not panel then Build() end
    Style()
    local width, maxLines, maxTargets = S.Get("panelWidth"), S.Get("panelLines"), S.Get("targetLines")
    panel:SetScale(S.Get("panelScale"))
    panel.background:SetAlpha(S.Get("panelAlpha"))
    panel.border._frame:SetAlpha(S.Get("panelAlpha"))
    panel.subtitle:SetText(view.seconds and TEXT_SESSION:format(view.label, DM.Clock(view.seconds)) or view.label)
    panel.title:SetText(DM.DisplayName(source))
    local lines = data and math.min(maxLines, #data.combatSpells) or 0
    local color, alpha = Look.BarColor(source, view.index), DM.Setting(view.index, "barAlpha")
    local seconds = view.rate and view.seconds or nil
    for i = 1, C.BREAKDOWN_MAX do
        local spellRow = panel.rows[i]
        if i <= lines then
            spellRow:SetWidth(width - 2 * PAD)
            PlaceRow(spellRow, HEADER_H + (i - 1) * (ROW_H + GAP))
            PaintRow(spellRow, data.combatSpells[i], data, color, alpha, seconds)
        else
            spellRow:Hide()
        end
    end
    panel.note:SetText(view.inCombat and TEXT_COMBAT or TEXT_NONE)
    panel.note:SetShown(lines == 0)
    local bottom = HEADER_H + (lines > 0 and lines * (ROW_H + GAP) - GAP or NOTE_H)
    local targets = view.targets
    local count = targets and math.min(maxTargets, #targets) or 0
    panel.targetsTitle:SetShown(count > 0)
    if count > 0 then
        local top = bottom + SECTION_GAP
        panel.targetsTitle:ClearAllPoints()
        panel.targetsTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -top)
        local y = top + SECTION_H
        for i = 1, C.TARGET_MAX do
            local targetRow = panel.targetRows[i]
            if i <= count then
                targetRow:SetWidth(width - 2 * PAD)
                PlaceRow(targetRow, y + (i - 1) * (ROW_H + GAP))
                PaintTarget(targetRow, targets[i], targets[1].total, view.seconds, alpha)
            else
                targetRow:Hide()
            end
        end
        bottom = y + count * (ROW_H + GAP) - GAP
    else
        for _, targetRow in ipairs(panel.targetRows) do targetRow:Hide() end
    end
    panel:SetSize(width, bottom + PAD)
    Place(row, view.toRight)
    panel:Show()
end

function Breakdown.Hide()
    if panel then panel:Hide() end
end
