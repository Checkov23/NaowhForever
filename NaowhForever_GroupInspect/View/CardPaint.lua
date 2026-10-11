-- CardPaint.lua: a Group Inspect party card painted from a member's record (GI.UI.PaintPartyCard).
local ns = _G.NaowhForever
local T = ns.THEME
local GI = ns.GroupInspect
local UI = GI.UI
local CP = ns.CharacterPanel
local Items = ns.Shared.Items

local St = UI.Style
local PAD, LINE_H, CLASS_ICON = St.PARTY_PAD, St.LINE_H, St.CLASS_ICON
local NAME_GAP, ICON_GAP = St.PARTY_NAME_GAP, St.PARTY_ICON_GAP
local ROUND = GI.C.ROUND
local GEAR_SLOTS = Items.GEAR_SLOTS
local STATS = UI.STATS
local WAITING = UI.WAITING

local NO_TALENTS = ns.L("Not known yet")

local shown = {}

local function Color(text, color)
    text:SetTextColor(color.r, color.g, color.b)
end

local function PaintHeader(card, rec, color)
    local nf = rec.hasNF == true
    card.nf:SetShown(nf)
    UI.PaintNFPill(card.nf, rec)
    local badged = UI.PaintBadge(card.badge, rec.guid)
    local room = card.layout.inner - CLASS_ICON - NAME_GAP - (nf and card.nf:GetWidth() + ICON_GAP or 0)
        - (badged and St.BADGE + St.BADGE_GAP or 0)
    local width = UI.FitName(card.name, rec.name or WAITING, room, St.NAME_SIZE, St.NAME_MIN)
    Color(card.name, color)
    card.badge:ClearAllPoints()
    card.badge:SetPoint("LEFT", card.name, "LEFT", width + St.BADGE_GAP, 0)
    card.sub:SetText(UI.LevelText(rec.level, rec.classFile))
    UI.PaintRole(card.role, rec.role)
end

local function PaintGear(card, rec)
    local gear = rec.gear
    for i = 1, #GEAR_SLOTS do
        UI.PaintGear(card.slots[i], gear and gear[GEAR_SLOTS[i][1]])
    end
    card.enchants:SetText(UI.EnchantText(rec))
end

local function PaintTalents(card, rec)
    local talents = rec.talents
    if not talents then
        card.tree:SetText(NO_TALENTS)
        Color(card.tree, T.muted)
        card.points:SetText("")
        card.trole:SetText(UI.ROLE_WORDS[rec.role] or "")
        return
    end
    card.tree:SetText(talents.tree or "")
    Color(card.tree, T.fg)
    card.points:SetText(UI.TalentText(talents.spent))
    card.trole:SetText(talents.role or UI.ROLE_WORDS[rec.role] or "")
end

local function PaintStats(card, rec)
    local l, values, stats, n = card.layout, rec.stats, card.stats, 0
    if values then
        for i = 1, #STATS do
            local stat = STATS[i]
            local value = values[stat.key]
            if type(value) == "number" and value ~= 0 and n < #stats then
                n = n + 1
                shown[n] = stat
            end
        end
    end
    local split = math.ceil(n / 2)
    for i = 1, #stats do
        local cell, stat = stats[i], shown[i]
        cell.label:ClearAllPoints()
        if stat then
            local col = i <= split and 0 or 1
            local row = col == 0 and i - 1 or i - split - 1
            local x, y = PAD + col * (l.cellW + l.cellGap), l.cellsY + row * LINE_H
            cell.label:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
            cell.label:SetText(l.long and stat.name or stat.card or stat.name)
            cell.value[1]:ClearAllPoints()
            cell.value[1]:SetPoint("TOPRIGHT", card, "TOPLEFT", x + l.cellW, -y)
            cell.value:SetText(UI.StatValue(stat, values[stat.key]))
        else
            cell.label:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -l.cellsY)
            cell.label:SetText(i == 1 and not values and WAITING or "")
            cell.value:SetText("")
        end
    end
    for i = 1, n do shown[i] = nil end
    local from, color = UI.StatsFrom(rec)
    card.from:SetText(from)
    Color(card.from, color)
end

function UI.PaintPartyCard(card, rec)
    card.guid = rec.guid
    local color = UI.ClassColor(rec.classFile)
    card.band:SetColorTexture(color.r, color.g, color.b, 1)
    UI.PaintClass(card.class, rec.classFile)
    PaintHeader(card, rec, color)
    if rec.score then CP.PaintScoreCard(card.score, rec.score, rec.level) else CP.ScoreCardWaiting(card.score) end
    card.ilvl:SetText(rec.ilvl and tostring(math.floor(rec.ilvl + ROUND)) or WAITING)
    PaintGear(card, rec)
    PaintTalents(card, rec)
    PaintStats(card, rec)
    card.state:SetText(UI.StateText(rec.state))
    card:SetAlpha(UI.Away(rec) and St.AWAY_ALPHA or 1)
end
