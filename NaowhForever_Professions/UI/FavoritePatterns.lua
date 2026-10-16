-- FavoritePatterns.lua: Search Favorites AH: your favourites' patterns beside the auction house, each bought on Accept.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local C = P.C
local Patterns = P.Patterns
local Popup = P.Popup
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets

local MAX_ROWS = Style.SIDE_PANEL_ROWS
local LOOKUP_TIMEOUT = 3
local QUEUE_DELAY = C.QUEUE_DELAY
local PURCHASE_SETTLE = 1
local PANEL_GAP = Style.SIDE_PANEL_GAP
local CONFIRM_H = 78
local CONFIRM_GAP = 6
local LINE_DROP, LINE_GAP = 10, 4
local LINE_ROOM = 20
local BUTTON_W, BUTTON_H = 120, 22
local BUTTON_GAP, BUTTON_BOTTOM = 4, 8
local PAGE_BUTTON_W, PAGE_BUTTON_H = 28, 20
local PAGE_BUTTON_GAP, PAGE_EDGE = 4, 8
local SCAN_BUTTON_W, PAGER_W = 92, 118
local PRICE_SORT = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local EVENTS = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_MONEY", "ITEM_DATA_LOAD_RESULT",
    "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
    "AUCTION_HOUSE_SHOW_ERROR" }
local OPEN_EVENTS = { "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED" }
local ALONE = { none = true, bought = true, unconfirmed = true }
local WHITE_CODE = "|cffffffff"
local TEXT_TITLE = ns.L("Favorite Patterns")
local TEXT_BUY = "Buy"
local TEXT_UNKNOWN = "?"
local TEXT_NONE_LISTED = ns.L("none listed")
local TEXT_SCAN = ns.L("scan ")
local TEXT_NOT_LISTED = ns.L("not listed")
local TEXT_NO_SCAN = ns.L("no scan yet")
local TEXT_MORE = ns.L("+%d more")
local TEXT_START_SCAN, TEXT_PAUSE_SCAN = ns.L("Scan"), ns.L("Pause")
local TEXT_RESUME_SCAN = ns.L("Resume Scan")
local TEXT_AVAILABLE_SCANNING = ns.L("%d available, scanning %d")
local TEXT_AVAILABLE_REMAINING = ns.L("%d available, %d remaining")
local TEXT_PATTERNS_READY = ns.L("%d patterns ready")
local TEXT_AVAILABLE = ns.L("%d available")
local TEXT_PAGE = "%d / %d"
local TEXT_PATTERN = ns.L("the pattern")
local TEXT_ACCEPT, TEXT_CANCEL, TEXT_CLOSE = ns.L("Accept"), ns.L("Cancel"), ns.L("Close")
local TEXT_TRY_AGAIN, TEXT_SEARCH = ns.L("Try Again"), ns.L("Search")
local TEXT_LOOKING = ns.L("Looking for the cheapest")
local TEXT_BUYOUT = ns.L("Buyout auction for:")
local TEXT_PRICE = "%s  %s%s|r"
local TEXT_NO_GOLD = ns.L("You do not have enough gold.|r")
local TEXT_NONE_NOW = ns.L("None with a buyout listed right now.")
local TEXT_NO_ANSWER = ns.L("No answer from the auction house.")
local TEXT_THROTTLED = ns.L("Searches are limited to a few a second.|r")
local TEXT_BY_AMOUNT = ns.L("Sold by amount, not as single listings.")
local TEXT_BY_AMOUNT_HELP = ns.L("Search shows it on the Buy tab.|r")
local TEXT_BUYING = ns.L("Buying")
local TEXT_FAILED = ns.L("The purchase failed.")
local TEXT_FAILED_HELP = ns.L("Someone may have bought it first.|r")
local TEXT_UNCONFIRMED = ns.L("No answer to the purchase yet.")
local TEXT_CHECK_MAIL = ns.L("Check your mailbox before buying it again.|r")
local TEXT_BOUGHT = ns.L("Bought ")
local TEXT_IN_MAIL = ns.L("It is on its way to your mailbox.|r")

local market
local buy
local bids = {}
local live = {}
local waiting = {}
local lookup, lookups, looked = nil, {}, {}
local lookupWait, lookupGen = nil, 0
local pending = false
local page = 1
local scanState = "idle"
local display = {}
local events = CreateFrame("Frame")
local Render, RenderConfirm, ToggleScan

local function On()
    return S.Get("enabled") and S.Get("searchFavoritesAH")
end

local function Manual()
    return S.Get("manualPatternScan") == true
end

local function Cheapest(key)
    local best
    for i = 1, C_AuctionHouse.GetNumItemSearchResults(key) or 0 do
        local r = C_AuctionHouse.GetItemSearchResultInfo(key, i)
        if r and (r.buyoutAmount or 0) > 0 and not r.containsOwnerItem and not r.containsAccountItem
            and (not best or r.buyoutAmount < best.buyoutAmount) then
            best = r
        end
    end
    live[key.itemID] = best and best.buyoutAmount or false
    return best
end

local function StartBuy(item, name)
    local gen = (buy and buy.gen or 0) + 1
    local key = C_AuctionHouse.MakeItemKey(item)
    buy = { item = item, name = name, key = key, state = "searching", gen = gen }
    C_AuctionHouse.SendSearchQuery(key, PRICE_SORT, false)
    C_Timer.After(C.SEARCH_TIMEOUT, function()
        if buy and buy.gen == gen and buy.state == "searching" then
            buy.state = "noanswer"
            RenderConfirm()
        end
    end)
    RenderConfirm()
end

local function ReadResults()
    local best = Cheapest(buy.key)
    if best then
        buy.state, buy.auctionID, buy.price = "ready", best.auctionID, best.buyoutAmount
    else
        buy.state = "none"
    end
    RenderConfirm()
end

local function BuyClick(row)
    StartBuy(row.item, row.searchName)
end

local function NextLookup()
    if Manual() and scanState ~= "scanning" then return end
    if lookup or lookupWait or (buy and (buy.state == "searching" or buy.state == "placing")) then return end
    local item = table.remove(lookups, 1)
    if not item then
        if Manual() then
            scanState = "done"
            for _, e in ipairs(Patterns.List()) do
                if live[e.item] == nil then scanState = "paused" break end
            end
            if Render then Render() end
        end
        return
    end
    local key = C_AuctionHouse.MakeItemKey(item)
    lookupGen = lookupGen + 1
    local gen = lookupGen
    lookup = { item = item, key = key }
    C_AuctionHouse.SendSearchQuery(key, PRICE_SORT, false)
    C_Timer.After(LOOKUP_TIMEOUT, function()
        if lookup and lookupGen == gen then
            if Manual() then looked[item] = nil end
            lookup = nil
            NextLookup()
        end
    end)
end

local function LookupGapOver()
    lookupWait = nil
    NextLookup()
end

local function LookupDone()
    Cheapest(lookup.key)
    lookup, lookupWait = nil, true
    Render()
    C_Timer.After(C.SEARCH_GAP, LookupGapOver)
end

local function Accept()
    if not buy then return end
    if buy.state == "noanswer" or buy.state == "failed" then return StartBuy(buy.item, buy.name) end
    if buy.state == "byamount" then return P.AH.Search(buy.name) end
    if buy.state ~= "ready" or GetMoney() < buy.price then return end
    C_AuctionHouse.PlaceBid(buy.auctionID, buy.price)
    bids[buy.auctionID] = buy.item
    buy.state = "placing"
    local placed = buy
    C_Timer.After(C.BUY_TIMEOUT, function()
        if buy == placed and buy.state == "placing" then
            buy.state = "unconfirmed"
            RenderConfirm()
        end
    end)
    RenderConfirm()
end

local function RenderLater()
    if Render then Render() end
end

local function Purchased(auctionID)
    local item = bids[auctionID]
    bids[auctionID] = nil
    Patterns.Bought()[item] = time()
    live[item], looked[item] = nil, nil
    if buy and buy.auctionID == auctionID then
        buy.state = "bought"
        RenderConfirm()
    end
    C_Timer.After(PURCHASE_SETTLE, RenderLater)
end

local function PlaceShopping()
    if ns.ShoppingListPlace then ns.ShoppingListPlace() end
end

local function CancelBuy()
    buy = nil
    market.confirm:Hide()
end

local function ConfirmLine(c, anchor, gap)
    local fs = ns.Font(c, Style.FONT, nil)
    if anchor then
        fs:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
    else
        fs:SetPoint("TOP", 0, -gap)
    end
    fs:SetWidth(Style.POPUP_W - LINE_ROOM)
    return fs
end

local function BuildConfirm()
    local c = CreateFrame("Frame", nil, market)
    c:SetSize(Style.POPUP_W, CONFIRM_H)
    c:SetPoint("TOPLEFT", market, "BOTTOMLEFT", 0, -CONFIRM_GAP)
    c:EnableMouse(true)
    ns.Solid(c, "BACKGROUND", T.bg, Style.WINDOW_ALPHA):SetAllPoints()
    ns.Border(c, Style.BORDER_RGB)
    c.line1 = ConfirmLine(c, nil, LINE_DROP)
    c.line2 = ConfirmLine(c, c.line1, LINE_GAP)
    c.accept = ns.Button(c, TEXT_ACCEPT, BUTTON_W, BUTTON_H, Accept)
    c.accept:SetPoint("BOTTOMRIGHT", c, "BOTTOM", -BUTTON_GAP, BUTTON_BOTTOM)
    c.cancel = ns.Button(c, TEXT_CANCEL, BUTTON_W, BUTTON_H, CancelBuy)
    c.cancel:SetPoint("BOTTOMLEFT", c, "BOTTOM", BUTTON_GAP, BUTTON_BOTTOM)
    market.confirm = c
    c:HookScript("OnShow", PlaceShopping)
    c:HookScript("OnHide", PlaceShopping)
end

function ns.FavoritePatternsFrames()
    return market, market and market.confirm
end

local function ConfirmText(name, muted)
    local state = buy.state
    if state == "searching" then return TEXT_LOOKING, name, TEXT_ACCEPT, false, TEXT_CANCEL end
    if state == "ready" then
        local short = GetMoney() < buy.price
        local line2 = TEXT_PRICE:format(name, short and Style.ALERT_CODE or WHITE_CODE, Text.Short(buy.price))
        if short then return Style.ALERT_CODE .. TEXT_NO_GOLD, line2, TEXT_ACCEPT, false, TEXT_CANCEL end
        return TEXT_BUYOUT, line2, TEXT_ACCEPT, true, TEXT_CANCEL
    end
    if state == "none" then return TEXT_NONE_NOW, muted .. name .. "|r", TEXT_ACCEPT, false, TEXT_CLOSE end
    if state == "noanswer" then return TEXT_NO_ANSWER, muted .. TEXT_THROTTLED, TEXT_TRY_AGAIN, true, TEXT_CANCEL end
    if state == "byamount" then return TEXT_BY_AMOUNT, muted .. TEXT_BY_AMOUNT_HELP, TEXT_SEARCH, true, TEXT_CANCEL end
    if state == "placing" then return TEXT_BUYING, name, TEXT_ACCEPT, false, TEXT_CANCEL end
    if state == "failed" then return TEXT_FAILED, muted .. TEXT_FAILED_HELP, TEXT_TRY_AGAIN, true, TEXT_CANCEL end
    if state == "unconfirmed" then return TEXT_UNCONFIRMED, muted .. TEXT_CHECK_MAIL, TEXT_ACCEPT, false, TEXT_CLOSE end
    if state == "bought" then return TEXT_BOUGHT .. name .. ".", muted .. TEXT_IN_MAIL, TEXT_ACCEPT, false, TEXT_CLOSE end
    return "", "", TEXT_ACCEPT, false, TEXT_CANCEL
end

RenderConfirm = function()
    if not market then return end
    if not market.confirm then BuildConfirm() end
    local c = market.confirm
    if not buy then return c:Hide() end
    local line1, line2, accept, enabled, cancel = ConfirmText(buy.name or TEXT_PATTERN, Text.Hex(T.muted))
    c.line1:SetText(line1)
    c.line2:SetText(line2)
    ns.SetButtonText(c.accept, accept)
    local alone = ALONE[buy.state] == true
    c.accept:SetShown(not alone)
    c.cancel:ClearAllPoints()
    if alone then
        c.cancel:SetPoint("BOTTOM", c, "BOTTOM", 0, BUTTON_BOTTOM)
    else
        c.cancel:SetPoint("BOTTOMLEFT", c, "BOTTOM", BUTTON_GAP, BUTTON_BOTTOM)
    end
    c.accept:SetEnabled(enabled)
    c.accept:SetAlpha(enabled and 1 or Style.DIMMED)
    ns.SetButtonText(c.cancel, cancel)
    c:Show()
end

local function PriceNote(row, e, scanned)
    local now = live[e.item]
    if now ~= nil then
        row.note:SetText(now and Text.Short(now) or TEXT_NONE_LISTED)
    else
        row.note:SetText(e.price and (TEXT_SCAN .. Text.Short(e.price)) or scanned and TEXT_NOT_LISTED or TEXT_NO_SCAN)
        if not Manual() and not looked[e.item] then
            looked[e.item] = true
            lookups[#lookups + 1] = e.item
        end
    end
    local c = now and T.fg or T.muted
    row.note:SetTextColor(c.r, c.g, c.b)
end

local function FillRow(i, e, scanned)
    local row = Popup.Row(market, i, TEXT_BUY, BuyClick)
    local name = C_Item.GetItemNameByID(e.item)
    if not name then
        waiting[e.item] = true
        C_Item.RequestLoadItemDataByID(e.item)
    end
    row.item, row.spell, row.searchName = e.item, nil, name
    row.icon:SetTexture(C_Item.GetItemIconByID(e.item))
    row.name:SetText(name or C_Spell.GetSpellName(e.r.spell) or TEXT_UNKNOWN)
    local color = Patterns.Learnable(e.item) and Style.READY_RGB or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    PriceNote(row, e, scanned)
    row.button:SetEnabled(name ~= nil)
    row.button:SetAlpha(name and 1 or Style.DIMMED)
    row:Show()
end

local function ChangePage(delta)
    if not (market and Manual()) then return end
    local pages = market.pageCount or 1
    local nextPage = math.max(1, math.min(pages, page + delta))
    if nextPage == page then return end
    page = nextPage
    Render()
end

local function BuildPager()
    if market.pager then return end
    local pager = CreateFrame("Frame", nil, market)
    pager:SetPoint("BOTTOMRIGHT", -PAGE_EDGE, PAGE_EDGE)
    pager:SetSize(PAGER_W, PAGE_BUTTON_H)
    pager.next = ns.Button(pager, ">", PAGE_BUTTON_W, PAGE_BUTTON_H, function() ChangePage(1) end)
    pager.next:SetPoint("RIGHT")
    pager.previous = ns.Button(pager, "<", PAGE_BUTTON_W, PAGE_BUTTON_H, function() ChangePage(-1) end)
    pager.previous:SetPoint("RIGHT", pager.next, "LEFT", -PAGE_BUTTON_GAP, 0)
    pager.label = ns.Font(pager, Style.FONT_SMALL, nil, T.muted)
    pager.label:SetPoint("RIGHT", pager.previous, "LEFT", -PAGE_BUTTON_GAP, 0)
    pager.label:SetJustifyH("RIGHT")
    market.pager = pager
    market.scan = ns.Button(market, TEXT_START_SCAN, SCAN_BUTTON_W, PAGE_BUTTON_H, ToggleScan)
    market.scan:SetPoint("BOTTOMRIGHT", market, "BOTTOMRIGHT", -(PAGE_EDGE + PAGER_W + PAGE_BUTTON_GAP), PAGE_EDGE)
    market:EnableMouseWheel(true)
    market:HookScript("OnMouseWheel", function(_, delta)
        if Manual() then ChangePage(delta > 0 and -1 or 1) end
    end)
end

local function UpdateScanButton()
    local text = scanState == "scanning" and TEXT_PAUSE_SCAN
        or scanState == "paused" and TEXT_RESUME_SCAN or TEXT_START_SCAN
    ns.SetButtonText(market.scan, text)
end

local function UpdatePager(pages)
    BuildPager()
    market.pageCount = pages
    market.pager.label:SetText(TEXT_PAGE:format(page, pages))
    Widgets.EnableButton(market.pager.previous, page > 1)
    Widgets.EnableButton(market.pager.next, page < pages)
    market.pager:SetShown(pages > 1)
    market.scan:Show()
end

local function QueueAllLookups(list)
    local remaining = 0
    for _, e in ipairs(list) do
        if live[e.item] == nil then
            remaining = remaining + 1
            if not looked[e.item] then
                looked[e.item] = true
                lookups[#lookups + 1] = e.item
            end
        end
    end
    return remaining
end

ToggleScan = function()
    if scanState == "scanning" then
        scanState = "paused"
        return Render()
    end
    local list = Patterns.List()
    if scanState ~= "paused" then
        lookup, lookupWait = nil, nil
        wipe(live)
        wipe(lookups)
        wipe(looked)
    end
    scanState = "scanning"
    QueueAllLookups(list)
    Render()
    NextLookup()
end

local function RenderAutomatic(list, scanned)
    for i = 1, math.min(#list, MAX_ROWS) do FillRow(i, list[i], scanned) end
    Popup.Fit(market, math.min(#list, MAX_ROWS), #list > MAX_ROWS)
    market.note:SetText(#list > MAX_ROWS and TEXT_MORE:format(#list - MAX_ROWS) or "")
    if market.pager then market.pager:Hide() end
    if market.scan then market.scan:Hide() end
end

local function RenderManual(list, scanned)
    if scanState == "scanning" then QueueAllLookups(list) end
    wipe(display)
    local found, remaining = 0, 0
    for _, e in ipairs(list) do
        if live[e.item] ~= false then display[#display + 1] = e end
        if live[e.item] then found = found + 1 end
        if live[e.item] == nil then remaining = remaining + 1 end
    end
    local pages = math.max(1, math.ceil(#display / MAX_ROWS))
    page = math.max(1, math.min(page, pages))
    local first = (page - 1) * MAX_ROWS + 1
    local shown = math.min(MAX_ROWS, math.max(0, #display - first + 1))
    for row = 1, shown do FillRow(row, display[first + row - 1], scanned) end
    Popup.Fit(market, shown, true)
    if scanState == "scanning" then
        market.note:SetText(TEXT_AVAILABLE_SCANNING:format(found, remaining))
    elseif scanState == "paused" then
        market.note:SetText(TEXT_AVAILABLE_REMAINING:format(found, remaining))
    elseif scanState == "idle" then
        market.note:SetText(TEXT_PATTERNS_READY:format(#list))
    else
        market.note:SetText(TEXT_AVAILABLE:format(found))
    end
    UpdatePager(pages)
    UpdateScanButton()
end

Render = function()
    local ah = _G.AuctionHouseFrame
    if not (On() and ah and ah:IsShown()) then return market and market:Hide() end
    local list = Patterns.List()
    if #list == 0 then return market and market:Hide() end
    if not market then market = Popup.New(TEXT_TITLE) end
    if market.dismissed then return end
    local scanned = ns.AuctionScanTime and ns.AuctionScanTime()
    if Manual() then RenderManual(list, scanned) else RenderAutomatic(list, scanned) end
    market:ClearAllPoints()
    market:SetPoint("TOPLEFT", ah, "TOPRIGHT", PANEL_GAP, 0)
    market:Show()
    if not Manual() or scanState == "scanning" then NextLookup() end
end

local function Flush()
    pending = false
    Render()
end

local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(QUEUE_DELAY, Flush)
end

local function ResetScan()
    lookup, lookupWait = nil, nil
    page, scanState = 1, "idle"
    wipe(live)
    wipe(lookups)
    wipe(looked)
    wipe(display)
end

local function WatchOpen(on)
    for _, event in ipairs(OPEN_EVENTS) do
        if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
end

local function Closed()
    WatchOpen(false)
    buy = nil
    ResetScan()
    wipe(waiting)
    if market then market:Hide() end
end

local function ItemResults(info)
    local item = type(info) == "table" and info.itemID
    if buy and buy.state == "searching" and item == buy.item then
        ReadResults()
        Render()
    end
    if lookup and item == lookup.item then LookupDone() end
end

local function CommodityResults(item)
    if buy and buy.state == "searching" and item == buy.item then
        buy.state = "byamount"
        RenderConfirm()
    end
    if lookup and item == lookup.item then
        lookup = nil
        C_Timer.After(C.SEARCH_GAP, NextLookup)
    end
end

local function ShowError()
    if buy and buy.state == "placing" then
        buy.state = "failed"
        RenderConfirm()
    end
end

local function OnEvent(_, event, name, loaded)
    if event == "AUCTION_HOUSE_SHOW" then
        WatchOpen(true)
        if market then market.dismissed = nil end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        return Closed()
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        return ItemResults(name)
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        return CommodityResults(name)
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        if bids[name] then Purchased(name) end
        return
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        return ShowError()
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if not waiting[name] then return end
        waiting[name] = nil
        if not (loaded and market and market:IsShown()) then return end
    end
    Queue()
end

local function Apply()
    events:UnregisterAllEvents()
    if market and not On() then market:Hide() end
    if not On() then return end
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    local ah = _G.AuctionHouseFrame
    if ah and ah:IsShown() then WatchOpen(true) end
end

local function OnSettingChanged(key)
    if key == "manualPatternScan" then
        ResetScan()
        return Queue()
    end
    if key ~= "enabled" and key ~= "searchFavoritesAH" then return end
    Apply()
    Queue()
end

local function OnStarred()
    if On() then Queue() end
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
if ns.ProfFavorites then hooksecurefunc(ns.ProfFavorites, "Toggle", OnStarred) end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
