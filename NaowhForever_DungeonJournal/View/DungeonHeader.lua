-- DungeonHeader.lua: the top of a dungeon's page: its name, entrance pin, zone and stats.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Loot = J.Loot
local Quests = J.Quests
local Kinds = J.View.Kinds
local Tip = ns.Shared.Parts.Tip
local St = J.Style
local BIS_CODE, LOOK_CODE, LOOK_RGB, TERRITORY_CODE = St.BIS_CODE, St.LOOK_CODE, St.LOOK_RGB, St.TERRITORY_CODE
local BANG, HANGER, PLACE_DOT = St.BANG, St.HANGER, St.PLACE_DOT
local STAR, BIS_RGB, DONE_MARK = St.STAR, St.BIS_RGB, St.DONE_MARK
local STAT_ICON, STAT_GAP, STAT_SPACE, STAT_LINE_H = St.STAT_ICON, St.STAT_GAP, St.STAT_SPACE, St.STAT_LINE_H
local TITLE_SIZE, TITLE_H, TITLE_GAP = St.TITLE_SIZE, St.TITLE_H, St.TITLE_GAP
local WHERE_H, HEADER_PAD, TEXT_SIZE = St.WHERE_H, St.HEADER_PAD, St.TEXT_SIZE

local PIN_BOX, PIN_ICON = 20, 18
local PIN_ATLAS = { dungeon = "dungeon", raid = "raid" }
local PIN_REST = 0.85
local PIN_DROP = 0
local PIN_GAP, PIN_GAP_AFTER_MARK = 6, 2
local TITLE_ROOM = 10
local STAT_H = 16
local STAT_ICON_GAP = 2
local BANG_DROP = -1
local COMPACT_STAT_TOP, COMPACT_PAD = 6, 12
local FOREVER_H, FOREVER_GAP = 12, 8
local FOREVER_W = FOREVER_H * 2
local STATS = { "quests", "bis", "looks" }
local CONTESTED = "Contested"

local TEXT_CLICK_BIS = ns.L("Click to see your BiS.")
local TEXT_SHOW_ENTRANCE = ns.L("Show the entrance on your map")
local TEXT_SHARE_ENTRANCE = ns.L("Right-click to share it in chat, or copy it.")
local TEXT_SHARE_TITLE = ns.L("Share the entrance")
local TEXT_ENTRANCE = " entrance"
local TEXT_PLAYERS = ns.L(" players")
local TEXT_LEVEL = ns.L("Level ")
local TEXT_COUNT = "%s/%s"
local TEXT_CODE_END = "|r"
local TERRITORY_TIP = {
    Alliance = ns.L("Alliance territory"), Horde = ns.L("Horde territory"),
    Contested = ns.L("Contested territory: both factions"),
}

local function StatEnter(stat)
    if not Tip(stat, "ANCHOR_BOTTOM") then return end
    local tip = stat.done and stat.doneTip or stat.total == 0 and stat.noneTip
        or stat.tipFormat:format(stat.have, stat.total)
    GameTooltip:SetText(tip, 1, 1, 1)
    if stat.onClick and stat.canClick() then
        GameTooltip:AddLine(stat.hint, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    end
    GameTooltip:Show()
end

local function StatClicked(stat, button)
    if button == "LeftButton" and stat.onClick and stat.canClick() then stat.onClick() end
end

local function StatIcon(stat, icon, tint, dy)
    stat.icon = stat:CreateTexture(nil, "ARTWORK")
    stat.icon:SetTexture(icon, nil, nil, "TRILINEAR")
    stat.icon:SetSize(STAT_ICON, STAT_ICON)
    stat.icon:SetPoint("LEFT", 0, dy)
    if tint then
        stat.icon:SetDesaturated(true)
        stat.icon:SetVertexColor(tint.r, tint.g, tint.b)
    end
    stat.text:SetPoint("LEFT", stat.icon, "RIGHT", stat.gap, -dy)
end

local function Stat(parent, label, tipFormat, doneTip, icon, tint, gap, dy)
    local stat = CreateFrame("Frame", nil, parent)
    stat:SetHeight(STAT_H)
    stat:EnableMouse(true)
    stat.tipFormat, stat.doneTip = tipFormat, doneTip
    stat.label = ns.Color("muted", " " .. label)
    stat.text = ns.Font(stat, TEXT_SIZE, nil, T.fg)
    stat.gap = icon and (gap or STAT_SPACE) or 0
    if icon then
        StatIcon(stat, icon, tint, dy or 0)
    else
        stat.text:SetPoint("LEFT")
    end
    stat:SetScript("OnEnter", StatEnter)
    stat:SetScript("OnLeave", GameTooltip_Hide)
    stat:SetScript("OnMouseUp", StatClicked)
    return stat
end

local function OpenBisList()
    ns.OpenBisWindow()
end

local function OpensBisList(stat)
    stat.onClick, stat.canClick, stat.hint = OpenBisList, Loot.BisOn, TEXT_CLICK_BIS
end

local function SetStat(stat, have, total, code, always)
    stat.have, stat.total, stat.done = have, total, total > 0 and have == total
    stat:SetShown(total > 0 or always == true)
    if not stat:IsShown() then return end
    local count = TEXT_COUNT:format(have, total)
    if code then count = code .. count .. TEXT_CODE_END end
    stat.text:SetText((stat.done and DONE_MARK or count) .. stat.label)
    stat:SetWidth((stat.icon and STAT_ICON + stat.gap or 0) + math.ceil(stat.text:GetStringWidth()))
end

local function PinClicked(pin, mouse)
    local dungeon = pin:GetParent().dungeon
    if mouse ~= "RightButton" then
        J.ShowEntrance(dungeon)
        return
    end
    local entrance = dungeon.entrance
    J.View.Parts.SharePlace(pin, TEXT_SHARE_TITLE, dungeon.name, entrance.map, entrance.x, entrance.y, TEXT_ENTRANCE)
end

local function PinEnter(pin)
    pin.icon:SetAlpha(1)
    if not Tip(pin, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(TEXT_SHOW_ENTRANCE, 1, 1, 1)
    GameTooltip:AddLine(TEXT_SHARE_ENTRANCE, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function PinLeave(pin)
    pin.icon:SetAlpha(PIN_REST)
    GameTooltip:Hide()
end

local function ForeverEnter(mark)
    if not Tip(mark, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(ns.Shared.Parts.ForeverLine())
    GameTooltip:Show()
end

local function ZoneEnter(zone)
    if not Tip(zone, "ANCHOR_BOTTOM") then return end
    GameTooltip:SetText(zone.name, 1, 1, 1)
    GameTooltip:AddLine(TERRITORY_CODE[zone.territory] .. TERRITORY_TIP[zone.territory] .. TEXT_CODE_END)
    GameTooltip:Show()
end

local function PlaceStat(row, stat, anchor, compact)
    if anchor then
        stat:SetPoint(compact and "LEFT" or "RIGHT", anchor, compact and "RIGHT" or "LEFT",
            compact and STAT_GAP or -STAT_GAP, 0)
    elseif compact then
        stat:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(TITLE_H + TITLE_GAP + WHERE_H + COMPACT_STAT_TOP))
    else
        stat:SetPoint("RIGHT", row, "TOPRIGHT", 0, -(TITLE_H + TITLE_GAP + WHERE_H / 2))
    end
end

local function PlaceStats(row, compact)
    local anchor, used = nil, 0
    for i = 1, #STATS do row.stats[STATS[i]]:ClearAllPoints() end
    local first, last, step = #STATS, 1, -1
    if compact then first, last, step = 1, #STATS, 1 end
    for i = first, last, step do
        local stat = row.stats[STATS[i]]
        if stat:IsShown() then
            PlaceStat(row, stat, anchor, compact)
            used = used + stat:GetWidth() + STAT_GAP
            anchor = stat
        end
    end
    return used, anchor ~= nil
end

local function NewForever(row)
    local mark = CreateFrame("Frame", nil, row)
    mark:SetSize(FOREVER_W, FOREVER_H)
    mark:SetPoint("LEFT", row.title, "RIGHT", FOREVER_GAP, 0)
    mark:EnableMouse(true)
    ns.Shared.Parts.ForeverMark(mark, FOREVER_H):SetAllPoints()
    mark:SetScript("OnEnter", ForeverEnter)
    mark:SetScript("OnLeave", GameTooltip_Hide)
    return mark
end

local function NewPin(row)
    local pin = CreateFrame("Button", nil, row)
    pin:SetSize(PIN_BOX, PIN_BOX)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetSize(PIN_ICON, PIN_ICON)
    pin.icon:SetPoint("CENTER")
    pin.icon:SetAlpha(PIN_REST)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetScript("OnClick", PinClicked)
    pin:SetScript("OnEnter", PinEnter)
    pin:SetScript("OnLeave", PinLeave)
    return pin
end

local function NewZone(row)
    local zone = CreateFrame("Frame", nil, row)
    zone:SetHeight(WHERE_H)
    zone:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -TITLE_GAP)
    zone:EnableMouse(true)
    zone.text = ns.Font(zone, TEXT_SIZE)
    zone.text:SetPoint("LEFT")
    zone:SetScript("OnEnter", ZoneEnter)
    zone:SetScript("OnLeave", GameTooltip_Hide)
    return zone
end

local function NewStats(row)
    local stats = {
        quests = Stat(row, "Quests", ns.L("You have handed in %d of your %d quests here"),
            ns.L("Every quest here is done"), BANG, nil, 0, BANG_DROP),
        bis = Stat(row, "BiS", ns.L("You have %d of the %d BiS from your list that drop here"),
            ns.L("You have every BiS that drops here"), STAR, BIS_RGB, STAT_ICON_GAP),
        looks = Stat(row, "Transmog", ns.L("You have %d of the %d looks here"), ns.L("You have every look here"),
            HANGER, LOOK_RGB, STAT_ICON_GAP, BANG_DROP),
    }
    stats.bis.noneTip = ns.L("None of your BiS drops here")
    OpensBisList(stats.bis)
    stats.looks.noneTip = ns.L("Nothing listed here has a look to collect")
    return stats
end

local function SetTitle(row, dungeon, view)
    local new = dungeon.new == true
    row.pin:SetShown(dungeon.entrance ~= nil and not view.compact)
    row.pin.icon:SetAtlas(dungeon.raid and PIN_ATLAS.raid or PIN_ATLAS.dungeon)
    row.forever:SetShown(new)
    row.pin:ClearAllPoints()
    row.pin:SetPoint("LEFT", new and row.forever or row.title, "RIGHT", new and PIN_GAP_AFTER_MARK or PIN_GAP, -PIN_DROP)
    row.title:SetWidth(0)
    row.title:SetText(dungeon.name)
    row.title:SetWidth(math.min(math.ceil(row.title:GetStringWidth()) + 1,
        row:GetWidth() - PIN_BOX - TITLE_ROOM - (new and FOREVER_W + FOREVER_GAP or 0)))
end

local function WhereText(dungeon)
    local dot = dungeon.zone and PLACE_DOT or ""
    if dungeon.raid then return dot .. ns.Color("fg", dungeon.raid) .. TEXT_PLAYERS end
    local range = J.LevelRange(dungeon)
    return range and (dot .. TEXT_LEVEL .. ns.Color("fg", range)) or ""
end

local function SetWhere(row, dungeon)
    local zone = row.zone
    local territory = dungeon.territory or CONTESTED
    zone:SetShown(dungeon.zone ~= nil)
    row.where:ClearAllPoints()
    if dungeon.zone then
        zone.name, zone.territory = dungeon.zone, territory
        zone.text:SetText(TERRITORY_CODE[territory] .. dungeon.zone .. TEXT_CODE_END)
        zone:SetWidth(math.ceil(zone.text:GetStringWidth()))
        row.where:SetPoint("LEFT", zone, "RIGHT", 0, 0)
    else
        row.where:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -TITLE_GAP)
    end
    row.where:SetText(WhereText(dungeon))
end

local function SetStats(row, dungeon, filters)
    local bis, haveBis = Loot.DungeonBis(dungeon, filters)
    local newLooks, looks = 0, 0
    if filters.showAppearance then newLooks, looks = Loot.DungeonNewLooks(dungeon, filters) end
    local stats = row.stats
    SetStat(stats.quests, Quests.Progress(dungeon.quests))
    SetStat(stats.bis, haveBis, bis, BIS_CODE, Loot.BisOn())
    SetStat(stats.looks, looks - newLooks, looks, LOOK_CODE, filters.showAppearance)
end

J.View.Parts.Stat, J.View.Parts.SetStat, J.View.Parts.OpensBisList = Stat, SetStat, OpensBisList

Kinds.header = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.title = ns.Font(row, TITLE_SIZE, nil, T.fg)
        row.title:SetPoint("TOPLEFT")
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(false)
        row.forever = NewForever(row)
        row.pin = NewPin(row)
        row.zone = NewZone(row)
        row.where = ns.Font(row, TEXT_SIZE, nil, T.muted)
        row.where:SetJustifyH("LEFT")
        row.where:SetWordWrap(false)
        row.stats = NewStats(row)
        return row
    end,
    Set = function(row, dungeon)
        local view = row:GetParent()
        row.dungeon = dungeon
        SetTitle(row, dungeon, view)
        SetWhere(row, dungeon)
        SetStats(row, dungeon, view.filters)
        local used, any = PlaceStats(row, view.compact)
        local zoneW = dungeon.zone and row.zone:GetWidth() or 0
        local lines = TITLE_H + TITLE_GAP + WHERE_H
        if view.compact then
            row.where:SetWidth(row:GetWidth() - zoneW)
            return lines + (any and STAT_LINE_H or 0) + COMPACT_PAD
        end
        row.where:SetWidth(row:GetWidth() - used - zoneW)
        return lines + HEADER_PAD
    end,
}
