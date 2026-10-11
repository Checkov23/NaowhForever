-- Raid.lua: Group Inspect's raid, a row each on the shared row engine under its column header (GI.UI.RaidList).
local ns = _G.NaowhForever
local S = ns.QoLSettings
local GI = ns.GroupInspect
local UI = GI.UI
local Parts, View = ns.Shared.Parts, ns.Shared.View
local Order = UI.RaidOrder

local St = UI.Style
local COLUMNS_H, TITLE_RGB = St.COLUMNS_H, St.TIP_TITLE_RGB
local NAME_X, VIEW_X, TREE_W = St.RAID_NAME_X, St.RAID_VIEW_X, St.RAID_TREE_W
local SCORE_RIGHT, ILVL_RIGHT, STATE_RIGHT = St.RAID_SCORE_RIGHT, St.RAID_ILVL_RIGHT, St.RAID_STATE_RIGHT
local NO_EVENTS = {}

local VIEW_TITLES = { gear = "GEAR", talents = "TALENTS", stats = "STATS" }
local STATS_TIP = ns.L("White: exact, from their Naowh Forever. Grey: added up from their gear.")
local NO_MATCH = ns.L("No one in the raid matches your filters.")

local kinds = UI.RaidKinds
local Passes, SortValue, SORTS, ByScore = UI.Passes, Order.SortValue, Order.SORTS, Order.ByScore
local SetRow = kinds.member.Set

local windowList

local function DrawRows(view)
    local mode = S.Get("groupInspectView")
    if not VIEW_TITLES[mode] then mode = "gear" end
    view.mode, view.sort = mode, S.Get("groupInspectSort")
    local order, members, n = view.order, GI.Members(), 0
    for i = 1, #members do
        local rec = members[i]
        if view.unfiltered or Passes(rec) then
            n = n + 1
            order[n] = rec
        end
    end
    for i = #order, n + 1, -1 do order[i] = nil end
    table.sort(order, SORTS[view.sort] or ByScore)
    view:Clear()
    for i = 1, n do view:Add("member", order[i], i) end
    if n == 0 and #members > 0 then view:Note(NO_MATCH) end
    view:Fit(NO_EVENTS)
    for i = 1, n do order[i] = nil end
    local header = view.header
    header.title:SetText(VIEW_TITLES[mode])
    header.tip:SetShown(mode == "stats")
    if not view.unfiltered then UI.PaintRaidBar() end
end

local function IsGuid(row, guid)
    return row.guid == guid
end

local function Draw(list)
    list.view:Redraw()
end

local function PaintGuid(list, guid)
    local view = list.view
    local rec = GI.Member(guid)
    local row = view:Find("member", IsGuid, guid)
    if not rec then
        if row then view:QueueRedraw() end
        return
    end
    local shows = view.unfiltered or Passes(rec)
    if not row then
        if shows then view:QueueRedraw() end
        return
    end
    if not shows or SortValue(rec, view.sort) ~= row.sortValue then view:QueueRedraw() end
    SetRow(row, rec, row.index)
end

local function TipEnter(frame)
    if GameTooltip:IsForbidden() or not Parts.Tip(frame, "ANCHOR_TOP") then return end
    GameTooltip:SetText(STATS_TIP, TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b, 1, true)
    GameTooltip:Show()
end

local function Header(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(UI.LIST_W, COLUMNS_H)
    UI.Kicker(header, "NAME"):SetPoint("LEFT", NAME_X, 0)
    UI.Kicker(header, "SCORE"):SetPoint("RIGHT", header, "LEFT", SCORE_RIGHT, 0)
    UI.Kicker(header, "ILVL"):SetPoint("RIGHT", header, "LEFT", ILVL_RIGHT, 0)
    UI.Kicker(header, "STATUS"):SetPoint("RIGHT", -STATE_RIGHT, 0)
    header.title = UI.Kicker(header, "")
    header.title:SetPoint("LEFT", VIEW_X, 0)
    header.tip = CreateFrame("Frame", nil, header)
    header.tip:SetPoint("LEFT", VIEW_X, 0)
    header.tip:SetSize(TREE_W, COLUMNS_H)
    header.tip:EnableMouse(true)
    header.tip:SetScript("OnEnter", TipEnter)
    header.tip:SetScript("OnLeave", GameTooltip_Hide)
    header.tip:Hide()
    return header
end

function UI.RaidList(parent, scroll)
    local list = { Draw = Draw, PaintGuid = PaintGuid }
    list.header = Header(parent)
    local view = View.New(scroll or parent, kinds, { Redraw = DrawRows })
    view:SetWidth(UI.LIST_W)
    view.order, view.header = {}, list.header
    list.view = view
    if scroll then windowList = list end
    return list
end

local function Redraw()
    if windowList then windowList:Draw() end
end

Order.OnFiltered(Redraw)
