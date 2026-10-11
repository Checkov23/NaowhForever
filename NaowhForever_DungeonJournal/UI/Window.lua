-- Window.lua: the Dungeon Journal's window: its tabs, its lists, the page it shows and its search.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local List = J.DungeonList
local Factions = J.FactionList
local Filters = J.FiltersMenu
local Switch = J.FactionSwitch
local Parts = J.View.Parts
local St = J.Style
local WIDTH, HEIGHT, HEADER, PAD = St.WINDOW_W, St.WINDOW_H, St.WINDOW_HEADER, St.WINDOW_PAD
local FOOTER = St.WINDOW_FOOTER
local LIST_W, SEARCH_H, SCROLLBAR, CONTENT_INSET = St.LIST_W, St.SEARCH_H, St.SCROLLBAR, St.CONTENT_INSET
local PLACE_DOT, LIST_SHOWN, LIST_HIDDEN = St.PLACE_DOT, St.LIST_SHOWN, St.LIST_HIDDEN
local FACTION_W, FACTION_GAP = St.FACTION_W, St.FACTION_GAP
local TAB_H, TAB_GAP = St.TAB_H, St.TAB_GAP

local PAGE = "Dungeon Journal"
local SEARCH_DELAY = 0.15
local NEXT_FRAME = 0
local MIN_QUERY = 2
local PERCENT = J.C.PERCENT
local ROUND_HALF = J.C.ROUND_HALF
local SEARCH_ROOM = 8
local SEARCH_W = LIST_W - SEARCH_ROOM - FACTION_W * 2 - FACTION_GAP
local SEARCH_FULL_W = LIST_W - SEARCH_ROOM
local CARD_EDGE, CARD_RIGHT, CARD_LIST_GAP = 6, 4, 14
local LIST_TOP = 4
local SCROLL_TOP, SCROLL_RIGHT, VIEW_ROOM = 4, 4, 8
local FILTERS_GAP, BAR_GAP = 18, 12
local BACK_GAP, BACK_DROP = 16, 1
local DUNGEONS = "dungeons"
local TABS = {
    { key = DUNGEONS, label = "Dungeons & Raids" },
    { key = "reputation", label = "Reputation" },
    { key = "pvp", label = "PvP" },
}

local TEXT_SUBTITLE = ns.L("Dungeons and raids, reputation and PvP: what drops, your quests, and more.")
local TEXT_SEARCH = ns.L("Search items, bosses or factions")
local TEXT_SHOW_LIST = ns.L("Show the dungeon list")
local TEXT_HIDE_LIST = ns.L("Hide the dungeon list")
local TEXT_DATA = ns.L("Game data: WoW Forever ")
local TEXT_DATA_DATE = ns.L("That build came out on %s.")
local TEXT_DATA_HELP = ns.L("Faction rewards, their standings and prices, and the boss fights the kill counts follow, "
    .. "are read from it. A daily check moves them on to each new build.")
local TEXT_DATA_NOTE = ns.L("Game data: build ")
local TEXT_BACK = ns.L("Back")

local window, view, scroll, search, listFrame, factionFrame
local listCard, contentCard
local selected
local awayForMap = false
local onClose
local shownTab
local picked = {}
local shownQuery = ""
local searchQueued = false
local clearing = false

local function DataDate(text)
    local day, month, year = tostring(text or ""):match("^(%d+) (%a+) (%d+)$")
    if not day then return text end
    return ns.L("%d %s %d"):format(tonumber(day), ns.L(month), tonumber(year))
end

local function TabOf(page)
    return page.tab or DUNGEONS
end

local function SavedTab()
    local tab = ns.AccountSettings().journalTab
    return (tab == "reputation" or tab == "pvp") and tab or DUNGEONS
end

local function ShowLists()
    if not shownTab then return end
    local hidden = S.Get("listHidden")
    local dungeons = shownTab == DUNGEONS
    local sides = shownTab ~= "reputation"
    listFrame:SetShown(dungeons and not hidden)
    factionFrame:SetShown(not dungeons and not hidden)
    window.factionSwitch:SetShown(sides and not hidden)
    search:SetWidth(sides and SEARCH_W or SEARCH_FULL_W)
    if not dungeons then Factions.Layout(shownTab) end
end

local function ShowTab(tab)
    shownTab = tab
    ns.AccountSettings().journalTab = tab
    view.watchFactions = tab ~= DUNGEONS
    ShowLists()
    Parts.PaintTabs(window.tabBar, tab)
end

local function FirstPage(tab)
    if tab == DUNGEONS then return J.Suggested() end
    if tab == "pvp" then return J.RANK end
    return Factions.First(tab) or J.Suggested()
end

local function ClearSearch()
    if search:GetText() ~= "" then
        clearing = true
        search:SetText("")
        clearing = false
    end
    shownQuery = ""
end

local function DrawPage(page)
    if page.rank then
        view:DrawRank()
    elseif page.tab then
        view:DrawFaction(page)
    else
        view:Draw(page)
    end
end

local function Select(page)
    local tab = TabOf(page)
    if tab ~= shownTab then ShowTab(tab) end
    selected = page
    picked[tab] = page
    ClearSearch()
    DrawPage(page)
    scroll:SetVerticalScroll(0)
end

local function TabPicked(tab)
    Select(picked[tab] or FirstPage(tab))
end

local function RunSearch()
    searchQueued = false
    if not window:IsShown() then return end
    local query = strtrim(search:GetText()):lower()
    if #query < MIN_QUERY then query = "" end
    if query == shownQuery then return end
    shownQuery = query
    if query == "" then DrawPage(selected) else view:DrawSearch(query, Select) end
    scroll:SetVerticalScroll(0)
end

local function OnSearch()
    if clearing or searchQueued then return end
    searchQueued = true
    C_Timer.After(SEARCH_DELAY, RunSearch)
end

local function PassKeysOn()
    if not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
end

local function Step(key)
    local by = key == "UP" and -1 or 1
    Select(shownTab == DUNGEONS and List.Next(selected, by) or Factions.Next(selected, by))
end

local function FocusSearch()
    search:SetFocus()
end

local function KeyAction(self, key)
    if InCombatLockdown() or not self:IsMouseOver() or search:HasFocus() then return nil end
    if key == "UP" or key == "DOWN" then return Step end
    if key == "F" and IsControlKeyDown() then return FocusSearch end
end

local function OnKeyDown(self, key)
    local action = KeyAction(self, key)
    if not action then return ns.UI.CloseOnEscape(self, key) end
    self:SetPropagateKeyboardInput(false)
    action(key)
    C_Timer.After(NEXT_FRAME, PassKeysOn)
end

local function Opacity()
    return math.floor((S.Get("windowAlpha") or 1) * PERCENT + ROUND_HALF)
end

local function SetOpacity(value)
    S.Set("windowAlpha", value / PERCENT)
end

local function PaintOpacity()
    window.backdrop:Paint(Opacity() / PERCENT)
    window.opacity._refreshValue()
end

local function ToggleEnter(button)
    Parts.LightBarIcon(button, true)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(S.Get("listHidden") and TEXT_SHOW_LIST or TEXT_HIDE_LIST, 1, 1, 1)
    GameTooltip:Show()
end

local function ToggleClicked(button)
    S.Set("listHidden", not S.Get("listHidden"))
    ToggleEnter(button)
end

local function PlaceContent(hidden)
    local cardLeft = hidden and CARD_EDGE or LIST_W + PAD + CARD_LIST_GAP
    local fill = contentCard[1]
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", cardLeft, -(HEADER + CARD_EDGE))
    fill:SetPoint("BOTTOMRIGHT", -CARD_RIGHT, FOOTER + CARD_EDGE)
    local left = cardLeft + CONTENT_INSET
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", left, -(HEADER + PAD + SCROLL_TOP))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_RIGHT, FOOTER + PAD)
    view:SetWidth(WIDTH - left - SCROLLBAR - PAD - VIEW_ROOM)
end

local function Arrange()
    local hidden = S.Get("listHidden")
    if hidden then ClearSearch() end
    search:SetShown(not hidden)
    window.factionSwitch:SetShown(not hidden)
    window.tabBar:SetShown(not hidden)
    ShowLists()
    for _, part in ipairs(listCard) do part:SetShown(not hidden) end
    PlaceContent(hidden)
    window.listToggle.icon:SetTexture(hidden and LIST_HIDDEN or LIST_SHOWN)
end

local function DataEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:SetText(TEXT_DATA .. J.DATA_BUILD, 1, 1, 1)
    if J.DATA_DATE ~= "" then
        GameTooltip:AddLine(TEXT_DATA_DATE:format(DataDate(J.DATA_DATE)), T.muted.r, T.muted.g, T.muted.b)
    end
    GameTooltip:AddLine(TEXT_DATA_HELP, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function Hidden()
    if awayForMap then return end
    local back = onClose
    onClose = nil
    window.back:Hide()
    if back then back() end
end

local function BackClicked()
    window:Hide()
end

local function Drawn()
    if shownTab == DUNGEONS then List.Paint(selected) else Factions.Paint(selected) end
end

local function BuildTitleBar()
    local close = Parts.TitleBar(window, PAGE, TEXT_SUBTITLE, PAGE)
    local opacityIcon
    opacityIcon, window.opacity = Parts.Opacity(window, close, Opacity, SetOpacity)
    window.filters = Filters.Button(window)
    window.filters:SetPoint("RIGHT", opacityIcon, "LEFT", -FILTERS_GAP, 0)
    window.listToggle = Parts.BarIcon(window, LIST_SHOWN, true)
    window.listToggle:SetScript("OnClick", ToggleClicked)
    window.listToggle:SetScript("OnEnter", ToggleEnter)
    window.listToggle:SetPoint("RIGHT", window.filters, "LEFT", -BAR_GAP, 0)
    J.Recent.Button(window, Select):SetPoint("RIGHT", window.listToggle, "LEFT", -BAR_GAP, 0)
    window.back = Parts.Link(window, BackClicked, true)
    window.back:SetPoint("LEFT", window.title, "RIGHT", BACK_GAP, -BACK_DROP)
    window.back:Hide()
end

local function BuildFooter()
    Parts.FooterBrand(window, PAGE)
    if not J.DATA_BUILD then return end
    Parts.FooterNote(window, TEXT_DATA_NOTE .. J.DATA_BUILD .. (J.DATA_DATE ~= "" and PLACE_DOT .. DataDate(J.DATA_DATE) or ""),
        DataEnter)
end

local function BuildLists()
    window.tabBar = Parts.Tabs(window, SEARCH_FULL_W, TABS, TabPicked)
    window.tabBar:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
    local below = HEADER + PAD + TAB_H + TAB_GAP
    search = Parts.SearchBox(window, TEXT_SEARCH, OnSearch)
    search:SetSize(SEARCH_W, SEARCH_H)
    search:SetPoint("TOPLEFT", PAD, -below)
    window.factionSwitch, window.factions = Switch.New(window)
    window.factionSwitch:SetPoint("LEFT", search, "RIGHT", FACTION_GAP, 0)
    listFrame = CreateFrame("Frame", nil, window)
    listFrame:SetPoint("TOPLEFT", PAD, -(below + SEARCH_H + LIST_TOP))
    listFrame:SetPoint("BOTTOMLEFT", PAD, FOOTER + PAD)
    listFrame:SetWidth(LIST_W)
    List.Build(listFrame, Select)
    factionFrame = CreateFrame("Frame", nil, window)
    factionFrame:SetPoint("TOPLEFT", listFrame)
    factionFrame:SetPoint("BOTTOMLEFT", listFrame)
    factionFrame:SetWidth(LIST_W)
    factionFrame:Hide()
    Factions.Build(factionFrame, Select)
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "journalWindow")
    local backdrop = window.backdrop
    listCard = backdrop:Card(CARD_EDGE, HEADER + CARD_EDGE, WIDTH - LIST_W - PAD - CARD_EDGE, FOOTER + CARD_EDGE)
    contentCard = backdrop:Card(LIST_W + PAD + CARD_LIST_GAP, HEADER + CARD_EDGE, CARD_RIGHT, FOOTER + CARD_EDGE)
    window:SetScript("OnKeyDown", OnKeyDown)
    BuildTitleBar()
    window:HookScript("OnHide", Hidden)
    BuildFooter()
    BuildLists()
    scroll = ns.UI.SlimScroll(window)
    view = J.View.New(scroll)
    scroll:SetScrollChild(view)
    view.onResize = Drawn
    view.navigate = Select
end

local function ApplyProfile()
    PaintOpacity()
    Switch.Paint(window.factions)
    Arrange()
    Filters.Paint()
    List.Layout()
end

local function RedrawFactions()
    if shownTab == DUNGEONS then return end
    Factions.Layout(shownTab)
    Factions.Paint(selected)
end

local function SettingChanged(key)
    if not (window and window:IsShown()) then return end
    if key == "enabled" then
        if not S.Get("enabled") then window:Hide() end
    elseif key == "windowAlpha" then
        PaintOpacity()
    elseif key:find("^closedGroup") then
        List.Layout()
    elseif key == "openUnreleased" then
        RedrawFactions()
    elseif key == "showAlliance" or key == "showHorde" then
        Switch.Paint(window.factions)
        List.Layout()
        RedrawFactions()
        if shownQuery ~= "" then view:Redraw() end
    else
        if key == "listHidden" then Arrange() end
        Filters.Paint()
        Filters.Repaint()
        view:Redraw()
    end
end

local function ProfileApplied()
    if not (window and window:IsShown()) then return end
    ApplyProfile()
    view:Redraw()
end

local function IsItem(row, itemID)
    return row.itemID == itemID
end

local function GoToItem(itemID)
    local row = itemID and view:Find("item", IsItem, itemID)
    if not row then return end
    view:ScrollToRow(scroll, row)
    if row.boss and view.pinned ~= row.boss then view:Pin(row.boss) end
end

function ns.RedrawJournalWindow()
    if window and window:IsShown() then view:Redraw() end
    J.View.BossPanel.Refresh()
end

function ns.OpenJournalWindow(dungeon, back, backText, itemID)
    awayForMap = false
    J.TurnOn()
    if not window then Build() end
    onClose = back
    window.back:SetShown(back ~= nil)
    if back then Parts.SetLink(window.back, backText or TEXT_BACK) end
    window:SetScale(ns.UIScale())
    window:Show()
    ApplyProfile()
    local here = J.Current()
    Select(dungeon or here and here[1] or selected or FirstPage(SavedTab()))
    GoToItem(itemID)
end

function ns.ToggleJournalWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenJournalWindow() end
end

function J.WindowAwayForMap(mapShown)
    if mapShown then
        if not (window and window:IsShown()) then return end
        awayForMap = true
        window.stepAside = true
        window:Hide()
        window.stepAside = nil
    elseif awayForMap then
        awayForMap = false
        if window and S.Get("enabled") then window:Show() end
    end
end

function NaowhForever_ToggleJournal()
    ns.ToggleJournalWindow()
end

S.OnChange(SettingChanged)
hooksecurefunc(ns, "Apply", ProfileApplied)
