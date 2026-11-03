-- YourGroup.lua: the Your Group page: your listing, your party, and the Naowh Forever players who applied, best score first (ns.GroupFinder.UI.YourGroup).
local ns = _G.NaowhForever
local T = ns.THEME

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local Comms, Listings, Group = GF.Comms, GF.Listings, GF.Group
local View = ns.Shared.View

local St = UI.Style
local GAP = St.TEXT_GAP
local HEAD_H, PARTY_Y, PARTY_W = St.GROUP_HEAD_H, St.GROUP_PARTY_Y, St.GROUP_PARTY_W
local SECONDS_PER_MINUTE, SCORE_TENTHS = 60, 10
local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local SEPARATOR = "   "
local NO_EVENTS = {}

local TEXT_RANGE = "%d-%d"
local TEXT_MEMBER = "%s %d"
local TEXT_MIN = ns.L("Minimum score %.1f")
local TEXT_LISTED = ns.L("Listed %dm ago")
local TEXT_APPLIED = ns.L("%d applied")
local TEXT_NOT_LISTED = ns.L("You have no listing. Make one on Create.")
local TEXT_NONE = ns.L("No one has applied yet. Naowh Forever players who apply show here.")
local TEXT_LEADER_ONLY = ns.L("Only your group's leader can change its listing.")
local TEXT_DELIST = "Delist"

local parts = {}
local page

local function Secret(v)
    return v ~= nil and issecretvalue(v)
end

local function ByScore(a, b)
    local sa, sb = a.card.score or -1, b.card.score or -1
    if sa ~= sb then return sa > sb end
    return a.at < b.at
end

local function DrawApplicants(view)
    view:Clear()
    if not Group.Listed() then
        view:Note(TEXT_NOT_LISTED)
        view:Fit(NO_EVENTS)
        return
    end
    local order, list = view.order, Comms.applicants
    local n = #list
    for i = 1, n do order[i] = list[i] end
    for i = #order, n + 1, -1 do order[i] = nil end
    table.sort(order, ByScore)
    for i = 1, n do view:Add("applicant", order[i], i) end
    if n == 0 then view:Note(TEXT_NONE) end
    view:Fit(NO_EVENTS)
end

local function PaintParty()
    for i, unit in ipairs(PARTY_UNITS) do
        local member = page.party[i]
        local name = UnitName(unit)
        if name and not Secret(name) then
            local _, class = UnitClass(unit)
            local color = class and RAID_CLASS_COLORS[class] or T.fg
            member:SetText(TEXT_MEMBER:format(name, UnitLevel(unit)))
            member:SetTextColor(color.r, color.g, color.b)
        else
            member:SetText("")
        end
    end
end

local function PaintHead()
    local entry = C_LFGList.GetActiveEntryInfo()
    local activity = entry and Listings.Activity(entry.activityIDs[1])
    page.title:SetText(activity and activity.name or "")
    page.range:SetText(activity and activity.max > 0 and TEXT_RANGE:format(activity.min, activity.max) or "")
    local n = 0
    local style = entry and entry.generalPlaystyle
    if style and not Secret(style) and UI.STYLES[style] then
        n = n + 1
        parts[n] = UI.STYLES[style]
    end
    if Group.Info() and Group.min > 0 then
        n = n + 1
        parts[n] = TEXT_MIN:format(Group.min / SCORE_TENTHS)
    end
    if entry and Group.listedAt then
        n = n + 1
        parts[n] = TEXT_LISTED:format(math.floor((GetTime() - Group.listedAt) / SECONDS_PER_MINUTE))
    end
    if entry then
        n = n + 1
        parts[n] = TEXT_APPLIED:format(#Comms.applicants)
    end
    page.info:SetText(table.concat(parts, SEPARATOR, 1, n))
    local leader = Group.CanEdit()
    page.delist:SetShown(entry ~= nil and leader)
    page.leaderOnly:SetText(entry and not leader and TEXT_LEADER_ONLY or "")
    PaintParty()
end

local function Paint(queued)
    PaintHead()
    if queued then page.view:QueueRedraw() else page.view:Redraw() end
end

function UI.YourGroup(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", St.CONTENT_INSET, -UI.CONTENT_TOP)
    page:SetPoint("BOTTOMRIGHT", -St.CONTENT_INSET, UI.FOOTER_ROOM)
    page.title = ns.Font(page, St.HEAD_SIZE, nil, T.fg)
    page.title:SetPoint("TOPLEFT")
    page.range = ns.Font(page, St.SUB_SIZE, nil, T.muted)
    page.range:SetPoint("LEFT", page.title, "RIGHT", GAP, 0)
    page.info = ns.Font(page, St.SUB_SIZE, nil, T.muted)
    page.info:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -GAP)
    page.party = {}
    for i = 1, #PARTY_UNITS do
        local member = ns.Font(page, St.LINE_SIZE, nil, T.fg)
        member:SetPoint("TOPLEFT", (i - 1) * PARTY_W, -PARTY_Y)
        member:SetWidth(PARTY_W - GAP)
        member:SetJustifyH("LEFT")
        member:SetWordWrap(false)
        page.party[i] = member
    end
    page.delist = ns.Button(page, TEXT_DELIST, St.APPLICANT_BUTTON_W, St.BUTTON_H, Group.Delist)
    page.delist:SetPoint("TOPRIGHT")
    page.leaderOnly = ns.Font(page, St.SUB_SIZE, nil, T.muted)
    page.leaderOnly:SetPoint("TOPRIGHT")

    local scroll = ns.UI.SlimScroll(page)
    scroll:SetPoint("TOPLEFT", 0, -HEAD_H)
    scroll:SetPoint("BOTTOMRIGHT", -St.SCROLLBAR - St.SCROLL_GAP, 0)
    local view = View.New(scroll, UI.ApplicantKinds, { Redraw = DrawApplicants })
    view:SetWidth(UI.LIST_W)
    view.order = {}
    scroll:SetScrollChild(view)
    page.view, page.Paint = view, Paint
    page:Hide()
    return page
end
