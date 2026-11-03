-- Window.lua: the Group Finder's window (/nflfg): Browse, Your Group and Create, under one title bar.
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local S = GF.Settings
local Comms, Listings, Search, Browse = GF.Comms, GF.Listings, GF.Search, GF.Browse
local Parts, View = ns.Shared.Parts, ns.Shared.View

local St = UI.Style
local HEADER, INSET, CARD_EDGE = St.WINDOW_HEADER, St.CONTENT_INSET, 6
local SCROLL_GAP, BAR_GAP = St.SCROLL_GAP, St.BAR_GAP
local WINDOW_KEY = "groupFinderWindow"
local NO_EVENTS = {}
local BROWSE, YOUR_GROUP, CREATE = "browse", "group", "create"
local REDRAWN_BY = { "listings", "listing", "search", "card", "noreply", "offline", "applied", "received", "declined",
    "expired", "group", "applicant", "withdrawn", "applicantExpired" }

local TEXT_TITLE = ns.L("Looking For Group")
local TEXT_GROUPS = ns.L("%d groups")
local TEXT_SEARCH = ns.L("Search")
local TEXT_SEARCH_TIP = ns.L("Search Forever's group finder again for the chip picked below.")
local TEXT_BROWSE, TEXT_CREATE = "Browse", "Create"
local TEXT_YOUR_GROUP = ns.L("Your Group")
local TEXT_YOUR_GROUP_COUNT = ns.L("Your Group (%d)")
local TEXT_FIRST = ns.L("Search to see the groups listed in Forever's group finder.")
local TEXT_SEARCHING = ns.L("Searching...")
local TEXT_FAILED = ns.L("The search failed. Wait a moment and search again.")
local TEXT_UNAVAILABLE = ns.L("Forever's group finder has nothing to search for your level yet.")
local TEXT_LOCKED = ns.L("Listings cannot be read during an encounter.")
local TEXT_NONE = ns.L("No groups found.")
local TEXT_NO_MATCH = ns.L("No groups match your filter.")
local TEXT_SOME = ns.L("%d of %d groups")
local TURNED_ON = ns.L("Group Finder turned on. Turn it off on its settings page.")

local TABS = { { key = BROWSE, label = TEXT_BROWSE }, { key = YOUR_GROUP, label = TEXT_YOUR_GROUP },
    { key = CREATE, label = TEXT_CREATE } }

local window, view
local pages = {}
local listening = false
local shown = BROWSE

local function Status()
    local state = Search.state
    if Listings.state == "locked" then return TEXT_LOCKED end
    if state == "searching" then return TEXT_SEARCHING end
    if state == "failed" then return TEXT_FAILED end
    if state == "unavailable" then return TEXT_UNAVAILABLE end
    if not Listings.searched then return TEXT_FIRST end
end

local function DrawRows(v)
    local n = Listings.Read()
    Browse.Ask()
    local order, needle, matched = v.order, window.bar.needle, 0
    for i = 1, n do
        local entry = Listings.entries[i]
        if Browse.Matches(entry, needle) then
            matched = matched + 1
            order[matched] = entry
        end
    end
    for i = #order, matched + 1, -1 do order[i] = nil end
    Browse.Sort(order, S.Get("sort"))
    v:Clear()
    local status = Status()
    if status then v:Note(status) end
    if Search.state ~= "failed" then
        for i = 1, matched do v:Add("listing", order[i], i) end
        if matched == 0 and not status then v:Note(n > 0 and TEXT_NO_MATCH or TEXT_NONE) end
    end
    v:Fit(NO_EVENTS)
    local count = matched < n and TEXT_SOME:format(matched, n) or TEXT_GROUPS:format(n)
    window.subtitle:SetText(Listings.searched and count or "")
end

local function PaintTabs()
    local count = #Comms.applicants
    TABS[2].label = count > 0 and TEXT_YOUR_GROUP_COUNT:format(count) or TEXT_YOUR_GROUP
    Parts.SetTabs(window.tabs, TABS)
    Parts.PaintTabs(window.tabs, shown)
end

local function PaintPage(queued)
    if shown == BROWSE then
        if queued then view:QueueRedraw() else view:Redraw() end
    elseif shown == YOUR_GROUP then
        pages[YOUR_GROUP].Paint(queued)
    else
        pages[CREATE].Paint()
    end
end

local function ShowPage(key)
    shown = key
    window.scroll:SetShown(key == BROWSE)
    window.search:SetShown(key == BROWSE)
    window.bar:SetShown(key == BROWSE)
    if key == BROWSE then window.bar.Paint() end
    pages[YOUR_GROUP]:SetShown(key == YOUR_GROUP)
    pages[CREATE]:SetShown(key == CREATE)
    if key ~= BROWSE then window.subtitle:SetText("") end
    PaintTabs()
    PaintPage(false)
end

local function Refresh()
    if not (window and window:IsShown()) then return end
    PaintTabs()
    PaintPage(true)
end

local function OnSearch()
    Search.Run()
    Refresh()
end

local function Listen()
    if listening then return end
    listening = true
    for _, what in ipairs(REDRAWN_BY) do GF.Listen(what, Refresh) end
end

local function Build()
    window = Parts.Window(St.WINDOW_W, St.WINDOW_H, WINDOW_KEY)
    window.backdrop:Card(CARD_EDGE, HEADER + CARD_EDGE, CARD_EDGE, St.WINDOW_FOOTER + CARD_EDGE)
    local close = Parts.TitleBar(window, TEXT_TITLE, "", GF.PAGE)
    local search = Parts.BarButton(window, St.SEARCH, TEXT_SEARCH, TEXT_SEARCH_TIP, OnSearch, TEXT_SEARCH)
    search:SetPoint("RIGHT", close, "LEFT", -BAR_GAP, 0)
    window.subtitle:SetPoint("RIGHT", search, "LEFT", -BAR_GAP, 0)
    window.search = search
    Parts.FooterBrand(window, GF.PAGE)

    window.tabs = Parts.Tabs(window, UI.CONTENT_W, TABS, ShowPage)
    window.tabs:SetPoint("TOPLEFT", INSET, -UI.TABS_TOP)
    Parts.FitTabs(window.tabs, TABS, St.TAB_PAD, UI.CONTENT_W)

    window.bar = UI.BrowseBar(window, function() view:QueueRedraw() end)
    window.bar:SetPoint("TOPLEFT", INSET, -UI.CONTENT_TOP)

    local scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", window.bar, "BOTTOMLEFT", 0, -St.TAB_GAP)
    scroll:SetPoint("BOTTOMRIGHT", -INSET - St.SCROLLBAR - SCROLL_GAP, UI.FOOTER_ROOM)
    view = View.New(scroll, UI.Kinds, { Redraw = DrawRows })
    view:SetWidth(UI.LIST_W)
    view.order = {}
    scroll:SetScrollChild(view)
    window.scroll, window.view = scroll, view

    pages[YOUR_GROUP] = UI.YourGroup(window)
    pages[CREATE] = UI.Create(window, function() ShowPage(YOUR_GROUP) end)
    window.pages = pages
    Listen()
end

function ns.OpenGroupFinder()
    if not GF.On() then
        S.Set("enabled", true)
        ns.Print(TURNED_ON)
    end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
    ShowPage(shown)
end

function ns.ToggleGroupFinder()
    if window and window:IsShown() then window:Hide() else ns.OpenGroupFinder() end
end

function UI.Window()
    return window
end

S.OnChange(function(key)
    if key == "enabled" and window and not GF.On() then window:Hide() end
end)
hooksecurefunc(ns, "Apply", function()
    if window and window:IsShown() then
        window.backdrop:Paint(1)
        PaintPage(false)
    end
end)
