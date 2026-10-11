-- BossCards.lua: a boss card's header: its kill order, name, Naowh's tip, kill count and what its filters hide.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Kinds = J.View.Kinds
local Parts = J.View.Parts
local Tip, ForeverLine = Parts.Tip, Parts.ForeverLine
local St = J.Style
local TIP_RGB, INFO, BORDER_RGB = St.TIP_RGB, St.INFO, St.BORDER_RGB
local BADGE, CARD_HEADER_H, CARD_NAME_SIZE = St.BADGE, St.CARD_HEADER_H, St.CARD_NAME_SIZE
local TIP_ICON, SMALL_SIZE, TINY_SIZE, TIP_X = St.TIP_ICON, St.SMALL_SIZE, St.TINY_SIZE, St.CURSOR_TIP_X
local RULE_ALPHA, BADGE_ALPHA = St.RULE_ALPHA, St.BADGE_ALPHA

local NAME_TOP = 11
local BADGE_LIFT = 2
local BADGE_GAP = 8
local STATS_TOP = 13
local KILLS_DROP = 6
local KILLS_GAP = 12
local TAG_GAP = 8
local TIP_PAD = 4
local TIP_GAP = 4
local TIP_ROOM = 10
local NOTE_GAP = 12
local NOTE_MIN = 40

local TEXT_MENU_HINT = ns.L("Right-click: Wowhead Link")
local TEXT_FILTERED = ns.L("+%d filtered")
local TEXT_FILTERED_LINE = ns.L("%d of its items hidden by your filters (top right).")
local TEXT_SHOW_ALL = ns.L("Click to show all its loot again")
local TEXT_SHOW_BEST = ns.L("Click to show only its BiS and upgrades")
local TEXT_WOWHEAD = ns.L("Wowhead Link")
local TEXT_NOTHING_FOR_CLASS = ns.L("Nothing for your class")
local TEXT_NO_LOOT = ns.L("No boss loot known yet")

local function TipEnter(button)
    button.icon:SetVertexColor(T.fg.r, T.fg.g, T.fg.b)
    if not Tip(button, "ANCHOR_RIGHT") then return end
    Parts.AddTip(button.tip)
    GameTooltip:Show()
end

local function TipLeave(button)
    button.icon:SetVertexColor(TIP_RGB.r, TIP_RGB.g, TIP_RGB.b)
    GameTooltip:Hide()
end

local function WowheadPage(boss)
    if boss.npc then return "npc", boss.npc end
    if boss.chest then return "object", boss.chest end
end

local function BossEnter(row)
    row.hovered = true
    local view = row:GetParent()
    view:ApplyPin()
    if not Tip(row, "ANCHOR_CURSOR_RIGHT", TIP_X, 0) then return end
    if row.canPin then
        GameTooltip:SetText(view.pinned == row.boss and TEXT_SHOW_ALL or TEXT_SHOW_BEST, 1, 1, 1)
    else
        GameTooltip:SetText(row.boss.name, 1, 1, 1)
    end
    if row.forever then GameTooltip:AddLine(ForeverLine()) end
    if row.hidden > 0 then
        GameTooltip:AddLine(TEXT_FILTERED_LINE:format(row.hidden), T.muted.r, T.muted.g, T.muted.b, true)
    end
    if WowheadPage(row.boss) then GameTooltip:AddLine(TEXT_MENU_HINT, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:Show()
end

local function BossLeave(row)
    row.hovered = false
    row:GetParent():ApplyPin()
    GameTooltip:Hide()
end

local function OpenWowheadMenu(row, boss)
    local kind, id = WowheadPage(boss)
    if not kind then return end
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(boss.name)
        root:CreateButton(TEXT_WOWHEAD, function() Parts.CopyWowhead(kind, id, boss.name) end)
    end)
end

local function BossClicked(row, button)
    local boss = row.boss
    if button == "RightButton" then return OpenWowheadMenu(row, boss) end
    if not row.canPin then return end
    row:GetParent():Pin(boss)
    BossEnter(row)
end

local function NewBadge(row)
    row.badge = CreateFrame("Frame", nil, row)
    row.badge:SetSize(BADGE, BADGE)
    row.badge:SetPoint("TOPLEFT", 0, -(NAME_TOP - BADGE_LIFT))
    ns.Solid(row.badge, "BACKGROUND", T.bg, BADGE_ALPHA):SetAllPoints()
    ns.Border(row.badge, BORDER_RGB)
    row.number = ns.Font(row.badge, SMALL_SIZE, nil, T.fg)
    row.number:SetPoint("CENTER", 0, 0)
end

local function NewTipButton(row)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(TIP_ICON + TIP_PAD, TIP_ICON + TIP_PAD)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(INFO)
    button.icon:SetSize(TIP_ICON, TIP_ICON)
    button.icon:SetPoint("CENTER")
    button.icon:SetVertexColor(TIP_RGB.r, TIP_RGB.g, TIP_RGB.b)
    button:SetScript("OnEnter", TipEnter)
    button:SetScript("OnLeave", TipLeave)
    button:SetScript("OnClick", Parts.OpenTipMenu)
    return button
end

local function NewRule(row)
    local rule = ns.Solid(row, "ARTWORK", T.line, RULE_ALPHA)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    ns.Hairline(rule, "h")
    return rule
end

local function SetKills(row, boss, view)
    local kills = row.kills
    local showKills = view.showKills and not boss.trash and not boss.chest
    kills:SetShown(showKills)
    row.stats:ClearAllPoints()
    if not showKills then
        row.stats:SetPoint("TOPRIGHT", 0, -STATS_TOP)
        return 0
    end
    Parts.SetKillCount(kills, boss)
    row.stats:SetPoint("RIGHT", kills, "LEFT", -KILLS_GAP, 0)
    return kills:GetWidth() + KILLS_GAP
end

local function SetTipButton(row, boss, view, tag)
    local tip = view.showTips and J.Tip(boss) or nil
    local button = row.tipButton
    button.boss, button.tip = boss, tip
    button:SetShown(tip ~= nil)
    button:ClearAllPoints()
    button:SetPoint("LEFT", tag and row.rare or row.name, "RIGHT", TIP_GAP, 0)
    return tip
end

local function FitName(row, left, after, right)
    local room = row:GetWidth() - left - after - right - NOTE_GAP
    local nameW = math.min(math.ceil(row.name:GetStringWidth()) + 1, room)
    row.name:SetWidth(nameW)
    local noteW = math.min(math.ceil(row.stats:GetStringWidth()), room - nameW)
    row.stats:SetShown(noteW >= NOTE_MIN)
    row.stats:SetWidth(math.max(noteW, 1))
end

function Parts.BossEmptyText(shown, boss)
    if shown > 0 then return "" end
    return boss.loot and TEXT_NOTHING_FOR_CLASS or TEXT_NO_LOOT
end

Kinds.boss = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        NewBadge(row)
        row.name = ns.Font(row, CARD_NAME_SIZE, nil, T.fg)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.rare = ns.Font(row, TINY_SIZE, nil, T.muted)
        row.rare:SetPoint("LEFT", row.name, "RIGHT", TAG_GAP, 0)
        row.tipButton = NewTipButton(row)
        row.stats = ns.Font(row, SMALL_SIZE)
        row.stats:SetJustifyH("RIGHT")
        row.stats:SetWordWrap(false)
        row.kills = Parts.KillCount(row)
        row.kills:SetPoint("RIGHT", row, "TOPRIGHT", 0, -(STATS_TOP + KILLS_DROP))
        row.rule = NewRule(row)
        row:SetScript("OnEnter", BossEnter)
        row:SetScript("OnLeave", BossLeave)
        row:SetScript("OnMouseUp", BossClicked)
        return row
    end,
    Set = function(row, boss, number, shown, hidden)
        local view = row:GetParent()
        row.boss, row.hovered, row.hidden = boss, false, hidden or 0
        row:EnableMouse(false)
        row.badge:SetShown(number ~= nil)
        row.number:SetText(number or "")
        local left = number and BADGE + BADGE_GAP or 0
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", left, -NAME_TOP)
        row.name:SetWidth(0)
        row.forever = J.IsForeverBoss(boss)
        row.name:SetText(boss.name)
        local tag = J.BossTag(boss)
        row.rare:SetText(tag or "")
        row.rare:SetShown(tag ~= nil)
        row.stats:SetWidth(0)
        row.stats:SetText(row.hidden > 0 and ns.Color("muted", TEXT_FILTERED:format(row.hidden)) or "")
        local right = SetKills(row, boss, view)
        local tip = SetTipButton(row, boss, view, tag)
        local after = (tag and TAG_GAP + math.ceil(row.rare:GetStringWidth()) or 0) + (tip and TIP_ICON + TIP_ROOM or 0)
        FitName(row, left, after, right)
        row.rule:SetShown(shown > 0)
        return CARD_HEADER_H
    end,
}
