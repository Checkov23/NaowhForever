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
local PRICE_SORT = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local EVENTS = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_MONEY", "ITEM_DATA_LOAD_RESULT",
    "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
    "AUCTION_HOUSE_SHOW_ERROR" }
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
local lookupWait
local pending = false
local events = CreateFrame("Frame")
local Render, RenderConfirm

local function On()
    return S.Get("enabled") and S.Get("searchFavoritesAH")
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
    if lookup or lookupWait or (buy and (buy.state == "searching" or buy.state == "placing")) then return end
    local item = table.remove(lookups, 1)
    if not item then return end
    local key = C_AuctionHouse.MakeItemKey(item)
    local gen = (looked.gen or 0) + 1
    looked.gen = gen
    lookup = { item = item, key = key }
    C_AuctionHouse.SendSearchQuery(key, PRICE_SORT, false)
    C_Timer.After(LOOKUP_TIMEOUT, function()
        if lookup and looked.gen == gen then
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
        if not looked[e.item] then
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
    PriceNote(row, e, scanned)
    row.button:SetEnabled(name ~= nil)
    row.button:SetAlpha(name and 1 or Style.DIMMED)
    row:Show()
end

Render = function()
    local ah = _G.AuctionHouseFrame
    if not (On() and ah and ah:IsShown()) then return market and market:Hide() end
    local list = Patterns.List()
    if #list == 0 then return market and market:Hide() end
    if not market then market = Popup.New(TEXT_TITLE) end
    if market.dismissed then return end
    local scanned = ns.AuctionScanTime and ns.AuctionScanTime()
    for i = 1, math.min(#list, MAX_ROWS) do FillRow(i, list[i], scanned) end
    Popup.Fit(market, math.min(#list, MAX_ROWS), #list > MAX_ROWS)
    market.note:SetText(#list > MAX_ROWS and TEXT_MORE:format(#list - MAX_ROWS) or "")
    market:ClearAllPoints()
    market:SetPoint("TOPLEFT", ah, "TOPRIGHT", PANEL_GAP, 0)
    market:Show()
    NextLookup()
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

local function Closed()
    buy, lookup = nil, nil
    wipe(live)
    wipe(lookups)
    wipe(looked)
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
end

local function OnSettingChanged(key)
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
