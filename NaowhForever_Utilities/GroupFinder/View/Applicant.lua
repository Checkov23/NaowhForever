-- Applicant.lua: a player who applied to your group, as a row on the shared row engine: who they are, their card, and Invite or Decline (ns.GroupFinder.UI.ApplicantKinds).
local ns = _G.NaowhForever
local T = ns.THEME

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local Parts, View = ns.Shared.Parts, ns.Shared.View
local Card, Group = GF.Card, GF.Group

local St = UI.Style
local ROW_H, PAD, GAP, BAND_W = St.APPLICANT_H, St.ROW_PAD, St.TEXT_GAP, St.BAND_W
local LINE_1, LINE_2 = St.LINE_1, St.LINE_2
local ROLE_ICON, ROLE_GAP = St.ROLE_ICON, St.ROLE_GAP
local SCORE_RIGHT, KILLS_X, BIS_X, QUESTS_X = St.APPLICANT_SCORE_RIGHT, St.APPLICANT_KILLS_X, St.APPLICANT_BIS_X,
    St.APPLICANT_QUESTS_X
local BUTTON_W, BUTTON_H = St.APPLICANT_BUTTON_W, St.BUTTON_H
local SCORE_TENTHS = 10
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local ROLE_BIT = { TANK = Card.TANK, HEALER = Card.HEALER, DAMAGER = Card.DAMAGE }
local WAITING = UI.WAITING

local TEXT_KILL, TEXT_KILLS = ns.L("1 boss kill"), ns.L("%d boss kills")
local TEXT_FIRST = ns.L("First time")
local TEXT_BIS = ns.L("BiS %d/%d")
local TEXT_QUEST, TEXT_QUESTS = ns.L("1 quest"), ns.L("%d quests")
local TEXT_INVITE = "Invite"
local TEXT_DECLINE = "Decline"
local TEXT_INVITED = ns.L("Invited")

local function RowEnter(row)
    row.hover:Show()
    if row.note then Parts.TipLines(row, "ANCHOR_RIGHT", row.note) end
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip_Hide()
end

local function NewRow(view)
    local row = CreateFrame("Frame", nil, view)
    Parts.RowBands(row, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row.band = ns.Solid(row, "ARTWORK", T.fg, 1)
    row.band:SetPoint("TOPLEFT")
    row.band:SetPoint("BOTTOMLEFT")
    row.band:SetWidth(BAND_W)
    row.class = Parts.ItemIcon(row, St.CLASS_ICON)
    row.class.texture:SetTexture(St.CLASS_ICONS)
    row.class:SetPoint("TOPLEFT", PAD, -LINE_1)
    row.name = ns.Font(row, St.LINE_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.class, "RIGHT", GAP, 0)
    row.name:SetWidth(St.APPLICANT_NAME_W)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.roles = {}
    for i = 1, #ROLE_ORDER do
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ROLE_ICON, ROLE_ICON)
        icon:SetPoint("TOPLEFT", PAD + (i - 1) * (ROLE_ICON + ROLE_GAP), -LINE_2)
        row.roles[i] = icon
    end
    row.level = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.score = ns.Font(row, St.SCORE_SIZE, nil, T.fg)
    row.score:SetPoint("RIGHT", row, "LEFT", SCORE_RIGHT, 0)
    row.kills = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.kills:SetPoint("LEFT", KILLS_X, 0)
    row.bis = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.bis:SetPoint("LEFT", BIS_X, 0)
    row.quests = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.quests:SetPoint("LEFT", QUESTS_X, 0)
    row.decline = ns.Button(row, TEXT_DECLINE, BUTTON_W, BUTTON_H, function() Group.Decline(row.record) end)
    row.decline:SetPoint("RIGHT", -PAD, 0)
    row.invite = ns.Button(row, TEXT_INVITE, BUTTON_W, BUTTON_H, function() Group.Invite(row.record) end)
    row.invite:SetPoint("RIGHT", row.decline, "LEFT", -GAP, 0)
    ns.PrimaryButton(row.invite)
    row.invited = ns.Font(row, St.SUB_SIZE, nil, T.muted)
    row.invited:SetPoint("RIGHT", row.decline, "LEFT", -GAP, 0)
    return row
end

local function PaintRoles(row, roles)
    local n = 0
    for r = 1, #ROLE_ORDER do
        local role = ROLE_ORDER[r]
        local roleBit = ROLE_BIT[role]
        if roles % (roleBit * 2) >= roleBit then
            n = n + 1
            row.roles[n]:SetAtlas(St.ROLE_ATLAS[role], false)
            row.roles[n]:Show()
        end
    end
    for i = n + 1, #ROLE_ORDER do row.roles[i]:Hide() end
    row.level:ClearAllPoints()
    row.level:SetPoint("TOPLEFT", PAD + n * (ROLE_ICON + ROLE_GAP), -LINE_2)
end

local function Kills(card)
    local total = 0
    for i = 1, card.nKills do total = total + card.kills[i] end
    return total
end

local function SetRow(row, record, index)
    local card = record.card
    row.record, row.index = record, index
    row.stripe:SetShown(index % 2 == 0)
    local _, class = GetClassInfo(card.class)
    local color = class and RAID_CLASS_COLORS[class] or T.fg
    row.band:SetColorTexture(color.r, color.g, color.b, 1)
    UI.PaintClass(row.class, class)
    row.name:SetText(record.name)
    row.name:SetTextColor(color.r, color.g, color.b)
    PaintRoles(row, card.roles)
    row.level:SetText(tostring(card.level))
    row.score:SetText(card.score and ns.NaowhScore.Colored(card.score / SCORE_TENTHS, card.level) or WAITING)
    if card.hasKills then
        local total = Kills(card)
        row.kills:SetText(total == 0 and TEXT_FIRST or total == 1 and TEXT_KILL or TEXT_KILLS:format(total))
    else
        row.kills:SetText("")
    end
    row.bis:SetText(card.bisTotal and TEXT_BIS:format(card.bisHave, card.bisTotal) or "")
    local quests = card.hasQuests and card.nHave or 0
    row.quests:SetText(quests == 0 and "" or quests == 1 and TEXT_QUEST or TEXT_QUESTS:format(quests))
    row.note = record.note
    row.invite:SetShown(not record.invited)
    row.invited:SetText(record.invited and TEXT_INVITED or "")
    return ROW_H
end

local kinds = View.NewKinds()
kinds.applicant = { New = NewRow, Set = SetRow }
UI.ApplicantKinds = kinds
