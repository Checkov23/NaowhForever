-- AbilityRows.lua: one of a boss's abilities: its icon, name and what the game says it does.
local ns = _G.NaowhForever

local GetSpellName = C_Spell.GetSpellName
local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellDescription = C_Spell.GetSpellDescription
local IsSpellDataCached = C_Spell.IsSpellDataCached
local GetSpellLink = C_Spell.GetSpellLink

local T = ns.THEME
local J = ns.Journal
local Kinds, Parts = J.View.Kinds, J.View.Parts
local St = J.Style
local ICON, QUESTION_ICON, HOVER = St.ICON, St.QUESTION_ICON, St.ITEM_HOVER
local DENSE_H, DENSE_TALL_H, DENSE_ICON = St.DENSE_H, St.DENSE_TALL_H, St.DENSE_ICON
local TEXT_SIZE, SMALL_SIZE = St.TEXT_SIZE, St.SMALL_SIZE

local TEXT_GAP = 8
local NAME_DESC_GAP = 2
local ROW_PAD = 5
local DENSE_TALL_TOP = 4
local DENSE_NAME_TOP = 1
local TALL_LINES = 2
local LINE_BREAKS = "%s*[\r\n]+%s*"

local TEXT_LINK_HINT = ns.L("Shift-click: link")
local TEXT_SPELL = ns.L("Spell ")

local oneLine = {}

local function AbilityEnter(row)
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(row.spell)
    GameTooltip:AddLine(TEXT_LINK_HINT, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function AbilityClick(row)
    if not IsModifiedClick("CHATLINK") then return end
    local link = GetSpellLink(row.spell)
    if link then ChatFrameUtil.InsertLink(link) end
end

local function AbilityLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function OneLine(spell, desc)
    local line = oneLine[spell]
    if not line then
        line = desc:gsub(LINE_BREAKS, " ")
        oneLine[spell] = line
    end
    return line
end

local function Loaded(view)
    return function()
        if view:IsVisible() then view:QueueRedraw() end
    end
end

local function Description(row, spell)
    local desc = GetSpellDescription and GetSpellDescription(spell) or ""
    if desc == "" and IsSpellDataCached and not IsSpellDataCached(spell) and Spell then
        Spell:CreateFromSpellID(spell):ContinueOnSpellLoad(row.loaded)
    end
    return desc
end

local function SetDense(row, spell, desc, tall)
    local frame = row.iconFrame
    frame:SetSize(DENSE_ICON, DENSE_ICON)
    row.desc:SetWidth(row:GetWidth() - DENSE_ICON - TEXT_GAP)
    row.desc:SetText(desc ~= "" and OneLine(spell, desc) or "")
    row.desc:SetShown(desc ~= "")
    if tall then
        frame:SetPoint("TOPLEFT", 0, -DENSE_TALL_TOP)
        row.name:SetPoint("TOPLEFT", frame, "TOPRIGHT", TEXT_GAP, -DENSE_NAME_TOP)
        row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -NAME_DESC_GAP)
        return DENSE_TALL_H
    end
    frame:SetPoint("LEFT", 0, 0)
    row.name:SetPoint("TOPLEFT", frame, "TOPRIGHT", TEXT_GAP, -DENSE_NAME_TOP)
    row.desc:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", TEXT_GAP, DENSE_NAME_TOP)
    return DENSE_H
end

local function SetFull(row, desc)
    local frame = row.iconFrame
    frame:SetSize(ICON, ICON)
    frame:SetPoint("TOPLEFT", 0, -ROW_PAD)
    row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -NAME_DESC_GAP)
    row.desc:SetWidth(row:GetWidth() - ICON - TEXT_GAP)
    row.desc:SetText(desc)
    row.desc:SetShown(desc ~= "")
    local text = row.name:GetStringHeight()
    if desc ~= "" then text = text + NAME_DESC_GAP + row.desc:GetStringHeight() end
    row.name:SetPoint("TOPLEFT", frame, "TOPRIGHT", TEXT_GAP, -math.max(0, (ICON - text) / 2))
    return math.ceil(math.max(ICON, text)) + ROW_PAD * 2
end

Kinds.ability = {
    New = function(view)
        local row = CreateFrame("Button", nil, view)
        row.hover = Parts.CardBand(row, HOVER)
        row.hover:Hide()
        local frame = Parts.ItemIcon(row, ICON)
        row.icon, row.iconFrame = frame.texture, frame
        row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
        row.name:SetPoint("TOPLEFT", frame, "TOPRIGHT", TEXT_GAP, 0)
        row.name:SetPoint("RIGHT")
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.desc = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.desc:SetJustifyH("LEFT")
        row:SetScript("OnEnter", AbilityEnter)
        row:SetScript("OnLeave", AbilityLeave)
        row:SetScript("OnClick", AbilityClick)
        row.loaded = Loaded(view)
        return row
    end,
    Set = function(row, spell)
        row.spell = spell
        row.icon:SetTexture(GetSpellTexture(spell) or QUESTION_ICON)
        row.name:SetText(GetSpellName(spell) or (TEXT_SPELL .. spell))
        local desc = Description(row, spell)
        local view = row:GetParent()
        local dense = view.dense
        local tall = dense and view.abilityLines == TALL_LINES
        row.iconFrame:ClearAllPoints()
        row.desc:ClearAllPoints()
        row.desc:SetWordWrap(not dense or tall)
        row.desc:SetMaxLines(tall and TALL_LINES or 0)
        if dense then return SetDense(row, spell, desc, tall) end
        return SetFull(row, desc)
    end,
}
