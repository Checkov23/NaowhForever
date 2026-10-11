-- Recent.lua: Recent on the window's title bar: this character's latest kills and loot (J.Recent).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Kills = J.Kills
local Looted = J.Looted
local Parts = J.View.Parts
local FightLength = Parts.FightLength
local Ago = ns.Shared.Ago
local St = J.Style
local BORDER_RGB, SKULL, KILL_DATE, HOVER = St.BORDER_RGB, St.SKULL, St.KILL_DATE, St.ITEM_HOVER
local TEXT_SIZE, HEADING_SIZE = St.TEXT_SIZE, St.HEADING_SIZE

local RECENT_ROWS = 5
local RECENT_ROW = 26
local RECENT_HEAD = 30
local RECENT_FOOT = 8
local RECENT_INSET = 20
local RECENT_ICON = 16
local RECENT_GAP = 8
local WHERE_W, AGO_W, COLUMN_GAP = 150, 76, 12
local RESET_W, RESET_H = 64, 20
local RESET_TOP = 6
local PANEL_W, PANEL_PAD, PANEL_DROP = 820, 8, 6
local DIVIDER_ALPHA = 0.6
local LINK_BRACKETS, LINK_NAME = "|h%[(.-)%]|h", "|h%1|h"

local TEXT_OPEN_HINT = ns.L("Click to show the dungeon.")
local TEXT_TOOK = ns.L("took ")
local TEXT_FROM = ns.L("From ")
local TEXT_LOOTED = ns.L("Looted")
local TEXT_RESET = ns.L("Reset")
local TEXT_FORGET_KILLS = ns.L("Forget this character's kills? Every boss's kill count starts again from 0.")
local TEXT_FORGET_LOOT = ns.L("Forget what this character has looted? This list and the item on each boss start again.")
local TEXT_KILLS = ns.L("Kills")
local TEXT_NO_KILLS = ns.L("No kills counted yet. They count while the Journal is on.")
local TEXT_LOOT = ns.L("Loot")
local TEXT_NO_LOOT = ns.L("Nothing looted yet. Loot counts in its dungeons and raids.")
local TEXT_RECENT = ns.L("Recent")
local TEXT_RECENT_TIP = ns.L("This character's latest kills and loot.")
local TEXT_BLANK = " "

local latestKills, latestLoot = {}, {}
local panel, button, show
local Fill

local function KillLines(kill, muted)
    GameTooltip:SetText(kill.boss.name, 1, 1, 1)
    GameTooltip:AddDoubleLine(date(KILL_DATE, kill.at), kill.took and TEXT_TOOK .. FightLength(kill.took) or "",
        1, 1, 1, muted.r, muted.g, muted.b)
end

local function ItemLines(item, muted)
    GameTooltip:SetHyperlink(item.link)
    GameTooltip:AddLine(TEXT_BLANK)
    GameTooltip:AddDoubleLine(item.boss and TEXT_FROM .. item.boss or TEXT_LOOTED, date(KILL_DATE, item.at),
        1, 1, 1, muted.r, muted.g, muted.b)
end

local function RecentEnter(row)
    local muted = T.muted
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if row.kill then KillLines(row.kill, muted) else ItemLines(row.item, muted) end
    GameTooltip:AddLine(row.dungeon.name, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:AddLine(TEXT_OPEN_HINT, muted.r, muted.g, muted.b)
    GameTooltip:Show()
end

local function RecentLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function RecentClick(row)
    panel:Hide()
    show(row.dungeon)
end

local function NewIcons(row)
    row.skull = row:CreateTexture(nil, "ARTWORK")
    row.skull:SetTexture(SKULL)
    row.skull:SetSize(RECENT_ICON, RECENT_ICON)
    row.skull:SetPoint("LEFT")
    row.skull:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    row.itemIcon = CreateFrame("Frame", nil, row)
    row.itemIcon:SetSize(RECENT_ICON, RECENT_ICON)
    row.itemIcon:SetPoint("LEFT")
    row.itemIcon.texture = row.itemIcon:CreateTexture(nil, "ARTWORK")
    row.itemIcon.texture:SetAllPoints()
    ns.Border(row.itemIcon, BORDER_RGB)
end

local function NewText(row)
    row.ago = ns.Font(row, TEXT_SIZE, nil, T.muted)
    row.ago:SetPoint("RIGHT")
    row.ago:SetWidth(AGO_W)
    row.ago:SetJustifyH("RIGHT")
    row.where = ns.Font(row, TEXT_SIZE, nil, T.muted)
    row.where:SetPoint("RIGHT", row.ago, "LEFT", -COLUMN_GAP, 0)
    row.where:SetWidth(WHERE_W)
    row.where:SetJustifyH("LEFT")
    row.where:SetWordWrap(false)
    row.name = ns.Font(row, HEADING_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", RECENT_ICON + RECENT_GAP, 0)
    row.name:SetPoint("RIGHT", row.where, "LEFT", -COLUMN_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
end

local function RecentRow(column, index)
    local row = CreateFrame("Button", nil, column)
    row:SetHeight(RECENT_ROW)
    row:SetPoint("TOPLEFT", RECENT_INSET, -(RECENT_HEAD + (index - 1) * RECENT_ROW))
    row:SetPoint("RIGHT", -RECENT_INSET, 0)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, HOVER)
    row.hover:SetPoint("TOPLEFT", -RECENT_INSET / 2, 0)
    row.hover:SetPoint("BOTTOMRIGHT", RECENT_INSET / 2, 0)
    row.hover:Hide()
    NewIcons(row)
    NewText(row)
    row:SetScript("OnEnter", RecentEnter)
    row:SetScript("OnLeave", RecentLeave)
    row:SetScript("OnClick", RecentClick)
    return row
end

local function Forget(question, forget)
    ns.Confirm(question, function()
        forget()
        if panel and panel:IsShown() then Fill() end
        ns.RedrawJournalWindow()
    end)
end

local function ForgetKills()
    Forget(TEXT_FORGET_KILLS, Kills.Forget)
end

local function ForgetLoot()
    Forget(TEXT_FORGET_LOOT, Looted.Forget)
end

local function RecentColumn(block, title, empty, reset)
    local column = CreateFrame("Frame", nil, block)
    column.reset = ns.Button(column, TEXT_RESET, RESET_W, RESET_H, reset)
    column.reset:SetPoint("TOPRIGHT", -RECENT_INSET, -RESET_TOP)
    column.title = ns.Font(column, TEXT_SIZE, nil, T.muted)
    column.title:SetPoint("LEFT", RECENT_INSET, 0)
    column.title:SetPoint("TOP", column.reset, "TOP")
    column.title:SetPoint("BOTTOM", column.reset, "BOTTOM")
    column.title:SetText(title)
    column.rows = {}
    for i = 1, RECENT_ROWS do column.rows[i] = RecentRow(column, i) end
    column.empty = ns.Font(column, TEXT_SIZE, nil, T.muted)
    column.empty:SetPoint("LEFT", column.rows[1], "LEFT")
    column.empty:SetPoint("RIGHT", column.rows[1], "RIGHT")
    column.empty:SetJustifyH("LEFT")
    column.empty:SetText(empty)
    return column
end

local function MakeRecent(parent)
    local block = CreateFrame("Frame", nil, parent)
    block.kills = RecentColumn(block, TEXT_KILLS, TEXT_NO_KILLS, ForgetKills)
    block.kills:SetPoint("TOPLEFT")
    block.kills:SetPoint("BOTTOMRIGHT", block, "BOTTOM")
    block.loot = RecentColumn(block, TEXT_LOOT, TEXT_NO_LOOT, ForgetLoot)
    block.loot:SetPoint("TOPLEFT", block, "TOP")
    block.loot:SetPoint("BOTTOMRIGHT")
    local divider = ns.Solid(block, "ARTWORK", T.line, DIVIDER_ALPHA)
    divider:SetPoint("TOP", 0, -RECENT_INSET / 2)
    divider:SetPoint("BOTTOM", 0, RECENT_FOOT)
    ns.Hairline(divider, "v")
    return block
end

local function ShowKill(row, kill)
    row.kill, row.item, row.dungeon = kill, nil, kill.dungeon
    row.skull:Show()
    row.itemIcon:Hide()
    row.name:SetText(kill.boss.name)
    row.where:SetText(kill.dungeon.name)
    row.ago:SetText(Ago(kill.at))
    row:Show()
end

local function ShowItem(row, item)
    local dungeon = J.Get(item.dungeon)
    row.kill, row.item, row.dungeon = nil, item, dungeon
    row.skull:Hide()
    row.itemIcon:Show()
    row.itemIcon.texture:SetTexture(C_Item.GetItemIconByID(item.id))
    row.name:SetText((item.link:gsub(LINK_BRACKETS, LINK_NAME)))
    row.where:SetText(dungeon.name)
    row.ago:SetText(Ago(item.at))
    row:Show()
end

local function FillColumn(column, list, ShowEntry)
    local rows = column.rows
    for i = 1, RECENT_ROWS do
        if list[i] then ShowEntry(rows[i], list[i]) else rows[i]:Hide() end
    end
    column.empty:SetShown(#list == 0)
    column.reset:SetShown(#list > 0)
end

function Fill()
    local block = panel.block
    local kills = Kills.Latest(RECENT_ROWS, latestKills)
    FillColumn(block.kills, kills, ShowKill)
    local items = Looted.Latest(RECENT_ROWS, latestLoot)
    FillColumn(block.loot, items, ShowItem)
    local shown = math.max(#kills, #items, 1)
    panel:SetHeight(RECENT_HEAD + shown * RECENT_ROW + RECENT_FOOT + PANEL_PAD * 2)
end

local function MouseDown()
    if not (panel:IsMouseOver() or button:IsMouseOver()) then panel:Hide() end
end

local function PanelShown(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
end

local function PanelHidden(self)
    self:UnregisterAllEvents()
    self:Hide()
end

local function Build(window)
    panel = CreateFrame("Frame", nil, window)
    panel:SetWidth(PANEL_W)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -PANEL_DROP)
    ns.Solid(panel, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(panel, BORDER_RGB)
    panel.block = MakeRecent(panel)
    panel.block:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_PAD)
    panel.block:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    panel:SetScript("OnShow", PanelShown)
    panel:SetScript("OnHide", PanelHidden)
    panel:SetScript("OnEvent", MouseDown)
    panel:Hide()
end

local function Clicked(self)
    if not panel then Build(self:GetParent()) end
    if panel:IsShown() then
        panel:Hide()
        return
    end
    GameTooltip:Hide()
    panel:Show()
    Fill()
end

local function Enter(self)
    Parts.LightBarIcon(self, true)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(TEXT_RECENT, 1, 1, 1)
    GameTooltip:AddLine(TEXT_RECENT_TIP, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local Recent = {}
J.Recent = Recent

function Recent.Button(window, onPick)
    show = onPick
    button = Parts.BarIcon(window, SKULL, true)
    button:SetScript("OnClick", Clicked)
    button:SetScript("OnEnter", Enter)
    return button
end
