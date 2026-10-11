-- Buyer.lua: Buy on AH's box: each missing material searched, priced, and bought only on Confirm.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local C = P.C
local R = P.Recipes
local V = P.Vendors
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets
local EnableButton = Widgets.EnableButton

local ROUND = C.ROUND
local BOX_W, BOX_H = 320, 170
local BOX_LIFT = 20
local BOX_LEVEL = 60
local BOX_ALPHA = 0.98
local EDGE = 14
local TITLE_DROP = 10
local ICON, ICON_DROP = 36, 34
local NAME_GAP = 10
local LINE_GAP, LINE2_GAP = 10, 4
local BUTTON_EDGE = 10
local BUTTON_GAP = 6
local CANCEL_W, PRIMARY_W = 80, 110
local PERCENT = C.PERCENT
local EVENTS = { "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_PRICE_UPDATED",
    "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
    "AUCTION_HOUSE_CLOSED" }
local PRICE_SORT = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local TRY_AGAIN = { noanswer = true, noquote = true, failed = true, unavailable = true, short = true,
    unconfirmed = true }
local TEXT_ONE_CRAFT, TEXT_CRAFTS = ns.L("1 craft"), ns.L(" crafts")
local TEXT_CANCEL, TEXT_SKIP, TEXT_CONFIRM = ns.L("Cancel"), ns.L("Skip"), ns.L("Confirm")
local TEXT_BUY, TEXT_TRY_AGAIN, TEXT_SEARCH, TEXT_CLOSE = ns.L("Buy"), ns.L("Try Again"), ns.L("Search AH"), ns.L("Close")
local TEXT_TITLE_DONE = ns.L("Buy on AH for ")
local TEXT_TITLE = ns.L("Buy on AH for %s  (%d/%d)")
local TEXT_NOTHING = ns.L("Nothing to buy: every material is unchecked or sold by vendors.")
local TEXT_BOUGHT = ns.L("Bought %d of %d materials.")
local TEXT_ITEM = ns.L("Item ")
local TEXT_AMOUNT = "%d x %s"
local TEXT_NO_GOLD = ns.L("You do not have enough gold.|r")
local TEXT_CAREFUL = ns.L("%sCareful: %d%% above your last scan (%s each).|r")
local TEXT_LAST_SCAN = ns.L("Last scan: %s each.")
local TEXT_SEARCHING = ns.L("Searching the auction house...")
local TEXT_CHEAPEST = ns.L("Cheapest %d add up to %s.")
local TEXT_FINAL_PRICE = ns.L("Buy asks for the final price.|r")
local TEXT_QUOTING = ns.L("Cheapest %d add up to %s. Getting the final price...")
local TEXT_NO_QUOTE = ns.L("The auction house gave no final price.")
local TEXT_SEARCH_AGAIN = ns.L("Try Again searches it once more.|r")
local TEXT_COSTS = ns.L("Costs %s  %s(%s each)|r")
local TEXT_BUYING = ns.L("Buying...")
local TEXT_UNCONFIRMED = ns.L("No answer to the purchase yet.")
local TEXT_CHECK_BAGS = ns.L("It may still have gone through: check your bags before trying again.|r")
local TEXT_ONLY = ns.L("Only %d listed right now.")
local TEXT_SKIP_IT = ns.L("Skip it, or lower the number of crafts.|r")
local TEXT_NO_PRICE_NOW = ns.L("The auction house has no price for it right now.")
local TEXT_NO_ANSWER = ns.L("No answer from the auction house.")
local TEXT_THROTTLED = ns.L("Searches are limited to a few a second; try again in a moment.|r")
local TEXT_FAILED = ns.L("The purchase failed; the price may have changed.|r")
local TEXT_SINGLE = ns.L("Sold as single listings, not by amount.")
local TEXT_SINGLE_HELP = ns.L("Search AH shows them to buy yourself; Skip moves on.|r")

local EMPTY = {}
local buyer, buyEvents
local searchGen = 0

local Buyer = {}
P.Buyer = Buyer

local function MaterialsToBuy(recipeID, crafts)
    local out, owned = {}, R.Owned()
    local ok, reagents = pcall(R.Reagents, recipeID)
    for _, r in ipairs(ok and reagents or EMPTY) do
        if not owned[r.itemID] and not V.IsVendorItem(r.itemID) then
            out[#out + 1] = { itemID = r.itemID, quantity = r.need * crafts }
        end
    end
    return out
end

local function HasMaterials(recipeID)
    local owned = R.Owned()
    local ok, reagents = pcall(R.Reagents, recipeID)
    for _, r in ipairs(ok and reagents or EMPTY) do
        if not owned[r.itemID] and not V.IsVendorItem(r.itemID) then return true end
    end
    return false
end

local function CraftsText(n)
    return n == 1 and TEXT_ONE_CRAFT or (n .. TEXT_CRAFTS)
end

local function CancelQuote()
    if buyer.state == "quoting" or buyer.state == "quoted" then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end
end

local function Close()
    if not buyer then return end
    CancelQuote()
    searchGen = searchGen + 1
    buyEvents:UnregisterAllEvents()
    buyer:Hide()
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

local function PriceWarning(each, total, scanEach)
    if GetMoney() < total then return Text.Hex(Style.RED_RGB) .. TEXT_NO_GOLD, true end
    if scanEach and each > scanEach * C.OVERPRICED then
        return TEXT_CAREFUL:format(Text.Hex(Style.RED_RGB), math.floor((each / scanEach - 1) * PERCENT + ROUND),
            Text.Money(scanEach))
    end
    if scanEach then return Text.Hex(T.muted) .. TEXT_LAST_SCAN:format(Text.Money(scanEach)) .. "|r" end
    return ""
end

local function RenderDone()
    local b = buyer
    b.title:SetText(TEXT_TITLE_DONE .. CraftsText(b.crafts))
    b.icon:Hide()
    b.name:SetText(#b.list == 0 and TEXT_NOTHING or TEXT_BOUGHT:format(b.bought, #b.list))
    b.line1:SetText("")
    b.line2:SetText("")
    ns.SetButtonText(b.primary, TEXT_CLOSE)
    EnableButton(b.primary, true)
end

local function StateText(item, scanEach)
    local b = buyer
    local muted = Text.Hex(T.muted)
    local state = b.state
    if state == "searching" then return TEXT_CONFIRM, false, TEXT_SEARCHING, "" end
    if state == "listed" then
        local warn, blocked = PriceWarning(b.estimate / item.quantity, b.estimate, scanEach)
        return TEXT_BUY, not blocked, TEXT_CHEAPEST:format(item.quantity, Text.Money(b.estimate)),
            warn ~= "" and warn or (muted .. TEXT_FINAL_PRICE)
    end
    if state == "quoting" then
        return TEXT_CONFIRM, false, TEXT_QUOTING:format(item.quantity, Text.Money(b.estimate)), ""
    end
    if state == "noquote" then return TEXT_TRY_AGAIN, true, TEXT_NO_QUOTE, muted .. TEXT_SEARCH_AGAIN end
    if state == "quoted" then
        local warn, blocked = PriceWarning(b.unit, b.total, scanEach)
        return TEXT_CONFIRM, not blocked, TEXT_COSTS:format(Text.Money(b.total), muted, Text.Money(b.unit)), warn
    end
    if state == "buying" then return TEXT_CONFIRM, false, TEXT_BUYING, "" end
    if state == "unconfirmed" then return TEXT_TRY_AGAIN, true, TEXT_UNCONFIRMED, muted .. TEXT_CHECK_BAGS end
    if state == "short" then return TEXT_TRY_AGAIN, true, TEXT_ONLY:format(b.found), muted .. TEXT_SKIP_IT end
    if state == "unavailable" then return TEXT_TRY_AGAIN, true, TEXT_NO_PRICE_NOW, "" end
    if state == "noanswer" then return TEXT_TRY_AGAIN, true, TEXT_NO_ANSWER, muted .. TEXT_THROTTLED end
    if state == "failed" then return TEXT_TRY_AGAIN, true, Text.Hex(Style.RED_RGB) .. TEXT_FAILED, "" end
    if state == "single" then return TEXT_SEARCH, true, TEXT_SINGLE, muted .. TEXT_SINGLE_HELP end
    return TEXT_CONFIRM, false, "", ""
end

local function Render()
    local b = buyer
    local done = b.state == "done"
    b.skip:SetShown(not done)
    b.cancel:SetShown(not done)
    EnableButton(b.skip, b.state ~= "buying")
    EnableButton(b.cancel, b.state ~= "buying")
    if done then return RenderDone() end
    local item = b.list[b.index]
    local name = C_Item.GetItemNameByID(item.itemID) or (TEXT_ITEM .. item.itemID)
    local scanEach = ns.AuctionPrice and ns.AuctionPrice(item.itemID)
    b.title:SetText(TEXT_TITLE:format(CraftsText(b.crafts), b.index, #b.list))
    b.icon:SetTexture(C_Item.GetItemIconByID(item.itemID))
    b.icon:Show()
    b.name:SetText(TEXT_AMOUNT:format(item.quantity, name))
    local label, enabled, line1, line2 = StateText(item, scanEach)
    b.line1:SetText(line1)
    b.line2:SetText(line2)
    ns.SetButtonText(b.primary, label)
    EnableButton(b.primary, enabled)
end

local function Watch(seconds, state, onLate)
    searchGen = searchGen + 1
    local gen = searchGen
    C_Timer.After(seconds, function()
        if gen == searchGen and buyer.state == state then onLate() end
    end)
end

local function NoAnswer()
    buyer.state = "noanswer"
    Render()
end

local function Search()
    local item = buyer.list[buyer.index]
    local key = C_AuctionHouse.MakeItemKey(item.itemID)
    buyer.state = "searching"
    Watch(C.SEARCH_TIMEOUT, "searching", NoAnswer)
    C_AuctionHouse.SendSearchQuery(key, PRICE_SORT, true)
end

local function NextMaterial()
    buyer.index = buyer.index + 1
    if buyer.index > #buyer.list then
        buyer.state = "done"
    else
        Search()
    end
    Render()
end

local function ReadListings(item)
    local want, have, total = item.quantity, 0, 0
    for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(item.itemID) or 0 do
        local r = C_AuctionHouse.GetCommoditySearchResultInfo(item.itemID, i)
        if r then
            local n = math.min((r.quantity or 0) - (r.numOwnerItems or 0), want - have)
            if n > 0 then have, total = have + n, total + n * r.unitPrice end
            if have >= want then break end
        end
    end
    if have < want and not C_AuctionHouse.HasFullCommoditySearchResults(item.itemID) then
        C_AuctionHouse.RequestMoreCommoditySearchResults(item.itemID)
        return
    end
    buyer.found, buyer.estimate = have, total
    buyer.state = have < want and "short" or "listed"
    Render()
end

local function NoQuote()
    pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    buyer.state = "noquote"
    Render()
end

local function Quote(item)
    buyer.state = "quoting"
    Watch(C.SEARCH_TIMEOUT, "quoting", NoQuote)
    C_AuctionHouse.StartCommoditiesPurchase(item.itemID, item.quantity)
end

local function Unconfirmed()
    buyer.state = "unconfirmed"
    Render()
end

local function Confirm(item)
    buyer.state = "buying"
    Watch(C.BUY_TIMEOUT, "buying", Unconfirmed)
    C_AuctionHouse.ConfirmCommoditiesPurchase(item.itemID, item.quantity)
end

local function Primary()
    local item = buyer.list[buyer.index]
    local state = buyer.state
    if state == "done" then return Close() end
    if state == "single" then return P.AH.Search(C_Item.GetItemNameByID(item.itemID)) end
    if state == "listed" then
        Quote(item)
    elseif state == "quoted" then
        Confirm(item)
    elseif TRY_AGAIN[state] then
        Search()
    end
    Render()
end

local function SkipMaterial()
    CancelQuote()
    NextMaterial()
end

local function OnEvent(_, event, a, b)
    if event == "AUCTION_HOUSE_CLOSED" then return Close() end
    local item = buyer.list[buyer.index]
    if not item then return end
    local state = buyer.state
    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" and state == "searching" and a == item.itemID then
        return ReadListings(item)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" and state == "searching"
        and type(a) == "table" and a.itemID == item.itemID then
        buyer.state = "single"
    elseif event == "COMMODITY_PRICE_UPDATED" and state == "quoting" then
        buyer.state, buyer.unit, buyer.total = "quoted", a, b
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" and state == "quoting" then
        buyer.state = "unavailable"
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" and (state == "buying" or state == "unconfirmed") then
        buyer.bought = buyer.bought + 1
        return NextMaterial()
    elseif event == "COMMODITY_PURCHASE_FAILED" and state == "buying" then
        buyer.state = "failed"
    else
        return
    end
    Render()
end

local function TextLine(anchor, gap)
    local fs = ns.Font(buyer, Style.FONT, nil)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    fs:SetPoint("RIGHT", -EDGE, 0)
    fs:SetJustifyH("LEFT")
    return fs
end

local function Build(win)
    buyer = CreateFrame("Frame", nil, win)
    buyer:SetSize(BOX_W, BOX_H)
    buyer:SetPoint("CENTER", win.mid, "CENTER", 0, BOX_LIFT)
    buyer:SetFrameLevel(win:GetFrameLevel() + BOX_LEVEL)
    buyer:EnableMouse(true)
    ns.Solid(buyer, "BACKGROUND", T.bg, BOX_ALPHA):SetAllPoints()
    ns.Border(buyer, Style.BORDER_RGB)
    buyer.title = ns.Font(buyer, Style.FONT_HEAD, nil, T.accent)
    buyer.title:SetPoint("TOP", 0, -TITLE_DROP)
    buyer.icon = Widgets.Crop(buyer:CreateTexture(nil, "ARTWORK"))
    buyer.icon:SetSize(ICON, ICON)
    buyer.icon:SetPoint("TOPLEFT", EDGE, -ICON_DROP)
    buyer.name = ns.Font(buyer, Style.FONT_LARGE, nil)
    buyer.name:SetPoint("LEFT", buyer.icon, "RIGHT", NAME_GAP, 0)
    buyer.name:SetPoint("RIGHT", -EDGE, 0)
    buyer.name:SetJustifyH("LEFT")
    buyer.line1 = TextLine(buyer.icon, LINE_GAP)
    buyer.line2 = TextLine(buyer.line1, LINE2_GAP)
    buyer.line2:SetWordWrap(true)
    buyer.cancel = ns.Button(buyer, TEXT_CANCEL, CANCEL_W, Style.BUTTON_H, Close)
    buyer.cancel:SetPoint("BOTTOMRIGHT", -BUTTON_EDGE, BUTTON_EDGE)
    buyer.skip = ns.Button(buyer, TEXT_SKIP, CANCEL_W, Style.BUTTON_H, SkipMaterial)
    buyer.skip:SetPoint("RIGHT", buyer.cancel, "LEFT", -BUTTON_GAP, 0)
    buyer.primary = ns.Button(buyer, TEXT_CONFIRM, PRIMARY_W, Style.BUTTON_H, Primary)
    buyer.primary:SetPoint("BOTTOMLEFT", BUTTON_EDGE, BUTTON_EDGE)
    buyEvents = CreateFrame("Frame")
    buyEvents:SetScript("OnEvent", OnEvent)
    buyer:Hide()
end

function Buyer.Open(win, recipeID, crafts)
    if not buyer then Build(win) end
    buyer.list = MaterialsToBuy(recipeID, crafts)
    buyer.index, buyer.bought, buyer.crafts = 1, 0, crafts
    for _, event in ipairs(EVENTS) do pcall(buyEvents.RegisterEvent, buyEvents, event) end
    if #buyer.list == 0 then
        buyer.state = "done"
    else
        Search()
    end
    buyer:Show()
    Render()
end

function Buyer.CloseIfShown()
    if buyer and buyer:IsShown() then Close() end
end

Buyer.HasMaterials = HasMaterials
