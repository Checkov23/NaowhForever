-- DisenchantDeals.lua: cached disenchant deals beside the auction house, with click-confirmed purchases.
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI

local P = ns.Professions
local S = P.Settings
local C = P.C
local Deals = P.DisenchantDeals
local Values = P.DisenchantValues
local Popup = P.Popup
local Style = P.Style
local Text = P.Text
local Widgets = P.Widgets

local MAX_ROWS = Style.SIDE_PANEL_ROWS
local ROW_TOP = 62
local FILTER_TOP = -36
local FILTER_H = 18
local FILTER_W = 190
local SKILL_FILTER_W = 180
local TOGGLE_W, TOGGLE_H = 38, 18
local FILTER_TOGGLE_W, FILTER_TOGGLE_H = 30, 14
local TOGGLE_LABEL_GAP = 7
local MODE_W, MODE_H = 150, 22
local MODE_X, MODE_DROP = 24, 6
local NOTE_W = 188
local FOOTER_NOTE_W = 150
local COIN_SIZE = 12
local MATERIAL_ICON_SIZE = 14
local CONFIRM_ICON_SIZE = 18
local PAGE_BUTTON_W, PAGE_BUTTON_H = 28, 20
local PAGE_BUTTON_GAP, PAGE_EDGE = 4, 8
local ACTION_W, ACTION_H = 92, 20
local CONFIRM_H, CONFIRM_GAP = 132, 6
local CONFIRM_EDGE, CONFIRM_LINE_GAP = 10, 4
local CONFIRM_BUTTON_W, CONFIRM_BUTTON_GAP = 120, 6
local CONFIRM_BUTTON_BOTTOM = 8
local PURCHASE_SETTLE = 0.8
local PRICE_WARNING_RATIO = 1.10
local PRICE_SORT = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local GUARANTEED_ICON = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14:0:0|t"
local OPEN_EVENTS = { "ITEM_DATA_LOAD_RESULT", "ITEM_SEARCH_RESULTS_UPDATED",
    "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_SHOW_ERROR" }

local TEXT_TITLE = ns.L("Disenchant Deals")
local TEXT_BUY = ns.L("Buy")
local TEXT_FIND, TEXT_RESUME = ns.L("Find Deals"), ns.L("Resume")
local TEXT_CURRENT, TEXT_WORKING = ns.L("Up to Date"), ns.L("Calculating...")
local TEXT_LEVEL, TEXT_PROFIT = ns.L("Level Up"), ns.L("Profit")
local TEXT_GUARANTEED = ns.L("Guaranteed profit only")
local TEXT_CURRENT_SKILL = ns.L("For my Enchant Lvl")
local TEXT_CLOSE, TEXT_BUY_NEXT = ns.L("Close"), ns.L("Buy Next")
local TEXT_TRY_AGAIN = ns.L("Try Again")
local TEXT_PAGE = "%d / %d"
local TEXT_RUN_SCAN = ns.L("Run Scan Prices first.")
local TEXT_PRESS_FIND = ns.L("Press Find Deals.")
local TEXT_SKILL_STOP = ns.L("Disenchant skill-ups stop at 60.")
local TEXT_SKILL_UNKNOWN = ns.L("Enchanting skill unavailable.")
local TEXT_LOADING = ns.L("%d deals (%d loading)")
local TEXT_PROFITABLE = ns.L("%d profitable items")
local TEXT_NO_GUARANTEED = ns.L("No guaranteed-profit deals.")
local TEXT_NO_ELIGIBLE = ns.L("No eligible items.")
local TEXT_NO_DEALS = ns.L("0 deals; best %s")
local TEXT_TOP_PROFIT = ns.L("Top %d; buy %s, profit %s")
local TEXT_TOP_COST = ns.L("Top %d; buy %s, cost %s")
local TEXT_POSSIBLE = ns.L("Possible materials")
local TEXT_EXPECTED_VALUE = ns.L("Expected disenchant value")
local TEXT_AFTER_CUT = ns.L("After 5% AH cut")
local TEXT_SCAN_PRICE = ns.L("Last-scan item price")
local TEXT_EXPECTED_PROFIT = ns.L("Expected profit")
local TEXT_EXPECTED_COST = ns.L("Expected cost")
local TEXT_REQUIRES_ENCHANTING = ns.L("Requires Enchanting")
local TEXT_GUARANTEED_SCAN = ns.L("Guaranteed profit at last-scan prices")
local TEXT_SKILL_UP = ns.L("Skill-up")
local TEXT_GUARANTEED_BAND, TEXT_LIKELY_BAND = ns.L("Guaranteed"), ns.L("Likely")
local TEXT_UNLIKELY_BAND, TEXT_NONE_BAND = ns.L("Unlikely"), ns.L("None")
local TEXT_EACH = ns.L("%s each")
local TEXT_CHECKING = ns.L("Checking current listings...")
local TEXT_NO_ANSWER = ns.L("No answer from the auction house.")
local TEXT_NO_LISTINGS = ns.L("No current listings remain.")
local TEXT_NO_PROFIT = ns.L("No profitable listings remain.")
local TEXT_BREAK_EVEN = ns.L("Break-even: %s each")
local TEXT_BUYING = ns.L("Buying the cheapest listing...")
local TEXT_REFRESHING = ns.L("Refreshing current listings...")
local TEXT_UNCONFIRMED = ns.L("Purchase not confirmed.")
local TEXT_CHECK_MAIL = ns.L("Check your mailbox before retrying.")
local TEXT_FAILED = ns.L("The purchase failed.")
local TEXT_LEVEL_AVAILABLE = ns.L("%dx available at the cheapest price")
local TEXT_LEVEL_NEXT = ns.L("Next: %dx for %s  Recover about %s")
local TEXT_LEVEL_PROFIT = ns.L("Expected profit %s")
local TEXT_LEVEL_COST = ns.L("Expected leveling cost %s")
local TEXT_PROFIT_AVAILABLE = ns.L("%s%dx profitable up to %s each")
local TEXT_AT_LEAST = ns.L("At least ")
local TEXT_INVEST = ns.L("Invest %s  Expected profit %s")
local TEXT_PROFIT_NEXT = ns.L("Next: %dx for %s  (%s)")
local TEXT_MODE_TIP = ns.L("Profit finds expected gains; Level Up finds cheap items you can disenchant now.")
local TEXT_GUARANTEED_TIP = ns.L("Keeps deals whose least valuable possible result is still profitable.")
local TEXT_CURRENT_SKILL_TIP = ns.L("Only shows profitable items your current Enchanting skill can disenchant.")

local market, events, buy
local bids = {}
local page, buyGen = 1, 0
local hooked = false
local watched = setmetatable({}, { __mode = "k" })
local Render, RenderConfirm, Place, SetMode, WatchOpen

local function Coin(copper)
    return C_CurrencyInfo.GetCoinTextureString(math.max(0, math.floor((copper or 0) + 0.5)), COIN_SIZE)
end

local function SignedCoin(copper)
    return (copper >= 0 and "+" or "-") .. Coin(math.abs(copper))
end

local function ItemLabel(entry)
    local texture = entry.icon and ("|T%d:%d:%d:0:0|t "):format(
        entry.icon, CONFIRM_ICON_SIZE, CONFIRM_ICON_SIZE) or ""
    return texture .. entry.name
end

local function SetEnabled(button, enabled)
    Widgets.EnableButton(button, enabled)
end

local function AuctionHouseOpen()
    local frame = _G.AuctionHouseFrame
    return frame and frame:IsShown()
end

local function MaterialLabel(result)
    local icon = C_Item.GetItemIconByID(result.itemID)
    local texture = icon and ("|T%d:%d:%d:0:0|t "):format(icon, MATERIAL_ICON_SIZE, MATERIAL_ICON_SIZE) or ""
    local name = C_Item.GetItemNameByID(result.itemID) or ("#" .. result.itemID)
    local quantity = result.minimum == result.maximum and tostring(result.minimum)
        or ("%d-%d"):format(result.minimum, result.maximum)
    return ("%s%s  %sx @ %.1f%%"):format(texture, name, quantity, result.chance)
end

local function AddTooltip(row)
    local entry = row.entry
    if not (entry and S.Get("disenchantDealsTooltip")) then return end
    local prices = Deals.Prices()
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TEXT_POSSIBLE, T.accent.r, T.accent.g, T.accent.b)
    for _, result in ipairs(entry.outcomes) do
        local price = prices and prices[result.itemID]
        GameTooltip:AddDoubleLine(MaterialLabel(result), price and TEXT_EACH:format(Coin(price)) or "?",
            1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(TEXT_EXPECTED_VALUE, Coin(entry.gross), T.accent.r, T.accent.g, T.accent.b, 1, 1, 1)
    GameTooltip:AddDoubleLine(TEXT_AFTER_CUT, Coin(entry.value), Style.GOLD_RGB.r, Style.GOLD_RGB.g,
        Style.GOLD_RGB.b, 1, 1, 1)
    GameTooltip:AddDoubleLine(TEXT_SCAN_PRICE, Coin(entry.scanPrice), Style.GOLD_RGB.r, Style.GOLD_RGB.g,
        Style.GOLD_RGB.b, 1, 1, 1)
    local label = entry.profit >= 0 and TEXT_EXPECTED_PROFIT or TEXT_EXPECTED_COST
    local color = entry.profit >= 0 and Style.PROFIT_RGB or Style.RED_RGB
    GameTooltip:AddDoubleLine(label, Coin(math.abs(entry.profit)), color.r, color.g, color.b,
        color.r, color.g, color.b)
    GameTooltip:AddDoubleLine(TEXT_REQUIRES_ENCHANTING, tostring(entry.required), Style.GOLD_RGB.r,
        Style.GOLD_RGB.g, Style.GOLD_RGB.b, 1, 1, 1)
    if entry.guaranteed then
        GameTooltip:AddLine(TEXT_GUARANTEED_SCAN, Style.PROFIT_RGB.r, Style.PROFIT_RGB.g, Style.PROFIT_RGB.b)
    end
    if entry.mode == Deals.MODE_LEVEL then
        local bands = { guaranteed = TEXT_GUARANTEED_BAND, likely = TEXT_LIKELY_BAND,
            unlikely = TEXT_UNLIKELY_BAND }
        GameTooltip:AddDoubleLine(TEXT_SKILL_UP, bands[Values.SkillupBand(Deals.Skill())] or TEXT_NONE_BAND,
            Style.GOLD_RGB.r, Style.GOLD_RGB.g, Style.GOLD_RGB.b, 1, 1, 1)
    end
end

local function DealText(entry)
    local color = entry.profit >= 0 and Style.PROFIT_RGB or Style.RED_RGB
    local profit = Text.Hex(color) .. SignedCoin(entry.profit) .. "|r"
    local guaranteed = entry.guaranteed and (" " .. GUARANTEED_ICON) or ""
    if entry.mode == Deals.MODE_PROFIT then
        return ("%s / %s / %.0f%% ROI%s"):format(Coin(entry.price), profit, entry.roi, guaranteed)
    end
    return ("%s / %s%s"):format(Coin(entry.price), profit, guaranteed)
end

local function Search(entry, state, excluded)
    buyGen = buyGen + 1
    buy = { entry = entry, key = C_AuctionHouse.MakeItemKey(entry.item), state = state or "searching",
        gen = buyGen, excluded = excluded }
    C_AuctionHouse.SendSearchQuery(buy.key, PRICE_SORT, false)
    local gen = buy.gen
    C_Timer.After(C.SEARCH_TIMEOUT, function()
        if buy and buy.gen == gen and (buy.state == "searching" or buy.state == "checking") then
            buy.state = "noanswer"
            RenderConfirm()
        end
    end)
    RenderConfirm()
end

local function BuyRow(row)
    Search(row.entry)
end

local function FillRow(index, entry)
    local row = Popup.Row(market, index, TEXT_BUY, BuyRow, ROW_TOP)
    row.entry, row.item, row.spell, row.onTooltip = entry, entry.item, nil, AddTooltip
    row.icon:SetTexture(entry.icon)
    row.name:SetText(entry.name)
    local color = ITEM_QUALITY_COLORS[entry.quality] or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    row.note:SetWidth(NOTE_W)
    row.note:SetText(DealText(entry))
    row.note:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    row:Show()
end

local function ChangePage(delta)
    local job = Deals.Job()
    local pages = math.max(1, math.ceil(#(job and job.visible or {}) / MAX_ROWS))
    local nextPage = math.max(1, math.min(pages, page + delta))
    if nextPage ~= page then page = nextPage; Render() end
end

local function StartDeals()
    Deals.Start()
end

local function BuildFooter()
    if market.footer then return end
    local footer = CreateFrame("Frame", nil, market)
    footer:SetPoint("BOTTOMLEFT", PAGE_EDGE, PAGE_EDGE)
    footer:SetPoint("BOTTOMRIGHT", -PAGE_EDGE, PAGE_EDGE)
    footer:SetHeight(PAGE_BUTTON_H)
    footer.action = ns.Button(footer, TEXT_FIND, ACTION_W, ACTION_H, StartDeals)
    footer.action:SetPoint("CENTER")
    footer.next = ns.Button(footer, ">", PAGE_BUTTON_W, PAGE_BUTTON_H, function() ChangePage(1) end)
    footer.next:SetPoint("RIGHT")
    footer.previous = ns.Button(footer, "<", PAGE_BUTTON_W, PAGE_BUTTON_H, function() ChangePage(-1) end)
    footer.previous:SetPoint("RIGHT", footer.next, "LEFT", -PAGE_BUTTON_GAP, 0)
    footer.page = ns.Font(footer, Style.FONT_SMALL, nil, T.muted)
    footer.page:SetPoint("RIGHT", footer.previous, "LEFT", -PAGE_BUTTON_GAP, 0)
    market.footer = footer
    market.note:SetWidth(FOOTER_NOTE_W)
    market:EnableMouseWheel(true)
    market:HookScript("OnMouseWheel", function(_, delta) ChangePage(delta > 0 and -1 or 1) end)
end

local function PaintMode()
    if not (market and market.modeControl) then return end
    local profit = Deals.Mode() == Deals.MODE_PROFIT
    local levelColor, profitColor = profit and T.muted or T.accent, profit and T.accent or T.muted
    market.modeControl.level:SetTextColor(levelColor.r, levelColor.g, levelColor.b)
    market.modeControl.profit:SetTextColor(profitColor.r, profitColor.g, profitColor.b)
    market.modeControl.toggle._refreshValue()
    if market.guaranteeControl then market.guaranteeControl:SetShown(profit) end
    if market.skillControl then market.skillControl:SetShown(profit) end
end

local function BuildSkillFilter()
    if market.skillControl then return end
    local control = CreateFrame("Frame", nil, market)
    control:SetSize(SKILL_FILTER_W, FILTER_H)
    control:SetPoint("TOPRIGHT", -CONFIRM_EDGE, FILTER_TOP)
    control.toggle = UI.BuildToggleControl(control, nil, Deals.CurrentSkillOnly,
        function(value)
            page = 1
            Deals.SetCurrentSkillOnly(value)
            WatchOpen(true)
        end, FILTER_TOGGLE_W, FILTER_TOGGLE_H)
    control.toggle:SetPoint("LEFT")
    control.label = ns.Font(control, Style.FONT_SMALL, nil, T.muted)
    control.label:SetPoint("LEFT", control.toggle, "RIGHT", TOGGLE_LABEL_GAP, 0)
    control.label:SetText(TEXT_CURRENT_SKILL)
    ns.Tooltip(control.toggle, TEXT_CURRENT_SKILL, TEXT_CURRENT_SKILL_TIP)
    market.skillControl = control
    control:SetShown(Deals.Mode() == Deals.MODE_PROFIT)
end

local function BuildMode()
    if market.modeControl then return end
    local control = CreateFrame("Frame", nil, market)
    control:SetSize(MODE_W, MODE_H)
    control:SetPoint("TOP", MODE_X, -MODE_DROP)
    control.toggle = UI.BuildToggleControl(control, nil,
        function() return Deals.Mode() == Deals.MODE_PROFIT end,
        function(profit) SetMode(profit and Deals.MODE_PROFIT or Deals.MODE_LEVEL) end,
        TOGGLE_W, TOGGLE_H)
    control.toggle:SetPoint("CENTER")
    control.level = ns.Font(control, Style.FONT_SMALL, nil, T.muted)
    control.level:SetPoint("RIGHT", control.toggle, "LEFT", -TOGGLE_LABEL_GAP, 0)
    control.level:SetText(TEXT_LEVEL)
    control.profit = ns.Font(control, Style.FONT_SMALL, nil, T.muted)
    control.profit:SetPoint("LEFT", control.toggle, "RIGHT", TOGGLE_LABEL_GAP, 0)
    control.profit:SetText(TEXT_PROFIT)
    ns.Tooltip(control.toggle, TEXT_TITLE, TEXT_MODE_TIP)
    market.modeControl = control
    PaintMode()
end

local function BuildGuarantee()
    if market.guaranteeControl then return end
    local control = CreateFrame("Frame", nil, market)
    control:SetSize(FILTER_W, FILTER_H)
    control:SetPoint("TOPLEFT", CONFIRM_EDGE, FILTER_TOP)
    control.toggle = UI.BuildToggleControl(control, nil, Deals.GuaranteedOnly,
        function(value) page = 1; Deals.SetGuaranteedOnly(value) end, FILTER_TOGGLE_W, FILTER_TOGGLE_H)
    control.toggle:SetPoint("LEFT")
    control.label = ns.Font(control, Style.FONT_SMALL, nil, T.muted)
    control.label:SetPoint("LEFT", control.toggle, "RIGHT", TOGGLE_LABEL_GAP, 0)
    control.label:SetText(TEXT_GUARANTEED)
    ns.Tooltip(control.toggle, TEXT_GUARANTEED, TEXT_GUARANTEED_TIP)
    market.guaranteeControl = control
    control:SetShown(Deals.Mode() == Deals.MODE_PROFIT)
end

local function Status(job)
    local scanned = ns.AuctionScanTime and ns.AuctionScanTime()
    if not scanned then return TEXT_RUN_SCAN end
    if not job then return TEXT_PRESS_FIND end
    if job.mode == Deals.MODE_LEVEL and not job.skill then return TEXT_SKILL_UNKNOWN end
    if job.mode == Deals.MODE_LEVEL and not Values.SkillupBand(job.skill) then return TEXT_SKILL_STOP end
    if not job.done then return TEXT_LOADING:format(#job.visible, job.pendingCount) end
    if job.mode == Deals.MODE_LEVEL then
        if #job.visible == 0 then return TEXT_NO_ELIGIBLE end
        local first = job.visible[1]
        if first.profit >= 0 then return TEXT_TOP_PROFIT:format(#job.visible, Coin(first.price), Coin(first.profit)) end
        return TEXT_TOP_COST:format(#job.visible, Coin(first.price), Coin(-first.profit))
    end
    if Deals.GuaranteedOnly() and #job.visible == 0 then return TEXT_NO_GUARANTEED end
    if #job.candidates == 0 and job.best then return TEXT_NO_DEALS:format(SignedCoin(job.best.profit)) end
    return TEXT_PROFITABLE:format(#job.visible)
end

local function UpdateFooter(job)
    BuildFooter()
    local pages = math.max(1, math.ceil(#(job and job.visible or {}) / MAX_ROWS))
    market.footer.page:SetText(TEXT_PAGE:format(page, pages))
    SetEnabled(market.footer.previous, page > 1)
    SetEnabled(market.footer.next, page < pages)
    local label, enabled = TEXT_FIND, true
    if job then
        if job.done then label, enabled = TEXT_CURRENT, false
        elseif Deals.Active() then label, enabled = TEXT_WORKING, false
        else label = TEXT_RESUME end
    end
    ns.SetButtonText(market.footer.action, label)
    SetEnabled(market.footer.action, enabled)
end

local function Reflow()
    Place()
    if ns.ShoppingListPlace then ns.ShoppingListPlace() end
end

local function QueuePlace()
    C_Timer.After(0, Reflow)
end

local function Watch(frame)
    if not frame or watched[frame] then return end
    watched[frame] = true
    frame:HookScript("OnShow", QueuePlace)
    frame:HookScript("OnHide", QueuePlace)
end

Place = function()
    local ah = _G.AuctionHouseFrame
    if not (market and market:IsShown() and ah and ah:IsShown()) then return end
    local favorite, confirm
    if ns.FavoritePatternsFrames then favorite, confirm = ns.FavoritePatternsFrames() end
    Watch(favorite)
    Watch(confirm)
    market:ClearAllPoints()
    if confirm and confirm:IsVisible() then
        market:SetPoint("TOPLEFT", confirm, "BOTTOMLEFT", 0, -Style.SIDE_PANEL_GAP)
    elseif favorite and favorite:IsVisible() then
        market:SetPoint("TOPLEFT", favorite, "BOTTOMLEFT", 0, -Style.SIDE_PANEL_GAP)
    else
        market:SetPoint("TOPLEFT", ah, "TOPRIGHT", Style.SIDE_PANEL_GAP, 0)
    end
end

local function MarketHidden(self)
    if not self.dismissed then return end
    buy = nil
    Deals.Pause()
    if self.confirm then self.confirm:Hide() end
end

Render = function()
    if not (Deals.On() and AuctionHouseOpen()) then return market and market:Hide() end
    if not market then
        market = Popup.New(TEXT_TITLE)
        market:HookScript("OnHide", MarketHidden)
    end
    if market.dismissed then return end
    BuildMode()
    BuildGuarantee()
    BuildSkillFilter()
    local job = Deals.Job()
    local list = job and job.visible or {}
    local pages = math.max(1, math.ceil(#list / MAX_ROWS))
    page = math.max(1, math.min(page, pages))
    local first = (page - 1) * MAX_ROWS + 1
    local shown = math.min(MAX_ROWS, math.max(0, #list - first + 1))
    for row = 1, shown do FillRow(row, list[first + row - 1]) end
    Popup.Fit(market, shown, true, ROW_TOP)
    market.note:SetText(Status(job))
    UpdateFooter(job)
    market:Show()
    Place()
end

SetMode = function(nextMode)
    if nextMode == Deals.Mode() then return end
    Deals.SetMode(nextMode)
    page, buy = 1, nil
    if market and market.confirm then market.confirm:Hide() end
    PaintMode()
    WatchOpen(true)
    Deals.Start()
end

local function ReadDepth()
    local entry = buy.entry
    local cheapestResult, cheapestUnit, count, investment, profit, ceiling
    local results = C_AuctionHouse.GetNumItemSearchResults(buy.key) or 0
    count, investment, profit, ceiling = 0, 0, 0, 0
    for i = 1, results do
        local result = C_AuctionHouse.GetItemSearchResultInfo(buy.key, i)
        local quantity = result and math.max(1, result.quantity or 1)
        local price = result and result.buyoutAmount
        if price and price > 0 and result.auctionID ~= buy.excluded
            and not result.containsOwnerItem and not result.containsAccountItem then
            local unit = price / quantity
            if not cheapestUnit or unit < cheapestUnit then cheapestResult, cheapestUnit = result, unit end
            if buy.entry.mode == Deals.MODE_PROFIT and unit < entry.value then
                count, investment = count + quantity, investment + price
                profit, ceiling = profit + entry.value * quantity - price, math.max(ceiling, unit)
            end
        end
    end
    if entry.mode == Deals.MODE_LEVEL and cheapestUnit then
        for i = 1, results do
            local result = C_AuctionHouse.GetItemSearchResultInfo(buy.key, i)
            local quantity = result and math.max(1, result.quantity or 1)
            local price = result and result.buyoutAmount
            if price and price > 0 and result.auctionID ~= buy.excluded
                and not result.containsOwnerItem and not result.containsAccountItem
                and price / quantity == cheapestUnit then
                count, investment = count + quantity, investment + price
                profit = profit + entry.value * quantity - price
            end
        end
        ceiling = cheapestUnit
    end
    buy.cheapest, buy.cheapestUnit, buy.count, buy.investment = cheapestResult, cheapestUnit, count, investment
    buy.profit, buy.ceiling = profit, ceiling
    buy.full = not C_AuctionHouse.HasFullItemSearchResults or C_AuctionHouse.HasFullItemSearchResults(buy.key)
    local usable = cheapestResult and (entry.mode == Deals.MODE_LEVEL or cheapestUnit < entry.value)
    buy.state = usable and "ready" or "done"
    Deals.UpdateLive(entry, cheapestUnit)
    RenderConfirm()
end

local function ConfirmLine(parent, anchor)
    local line = ns.Font(parent, Style.FONT, nil)
    line:SetWidth(Style.POPUP_W - 2 * CONFIRM_EDGE)
    line:SetJustifyH("LEFT")
    if anchor then
        line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -CONFIRM_LINE_GAP)
    else
        line:SetPoint("TOPLEFT", CONFIRM_EDGE, -CONFIRM_EDGE)
    end
    return line
end

local function CancelBuy()
    buy = nil
    if market and market.confirm then market.confirm:Hide() end
end

local function BuyNext()
    if not (buy and buy.state == "ready" and buy.cheapest) then return end
    local result = buy.cheapest
    if GetMoney() < result.buyoutAmount then return end
    buy.state, buy.auctionID = "buying", result.auctionID
    bids[result.auctionID] = true
    C_AuctionHouse.PlaceBid(result.auctionID, result.buyoutAmount)
    local current, gen = buy, buy.gen
    C_Timer.After(C.BUY_TIMEOUT, function()
        if buy == current and buy.gen == gen and buy.state == "buying" then
            buy.state = "unconfirmed"
            RenderConfirm()
        end
    end)
    RenderConfirm()
end

local function Primary()
    if not buy then return end
    if buy.state == "ready" then return BuyNext() end
    if buy.state == "noanswer" or buy.state == "failed" then return Search(buy.entry) end
end

local function BuildConfirm()
    local confirm = CreateFrame("Frame", nil, market)
    confirm:SetSize(Style.POPUP_W, CONFIRM_H)
    confirm:SetPoint("TOPLEFT", market, "BOTTOMLEFT", 0, -CONFIRM_GAP)
    confirm:EnableMouse(true)
    ns.Solid(confirm, "BACKGROUND", T.bg, Style.WINDOW_ALPHA):SetAllPoints()
    ns.Border(confirm, Style.BORDER_RGB)
    confirm.item = ns.Font(confirm, Style.FONT, nil)
    confirm.item:SetPoint("TOPLEFT", CONFIRM_EDGE, -CONFIRM_EDGE)
    confirm.item:SetPoint("RIGHT", -CONFIRM_EDGE, 0)
    confirm.item:SetJustifyH("LEFT")
    confirm.item:SetWordWrap(false)
    confirm.line1 = ConfirmLine(confirm, confirm.item)
    confirm.line2 = ConfirmLine(confirm, confirm.line1)
    confirm.line3 = ConfirmLine(confirm, confirm.line2)
    confirm.buy = ns.Button(confirm, TEXT_BUY_NEXT, CONFIRM_BUTTON_W, Style.BUTTON_H, Primary)
    confirm.buy:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -CONFIRM_BUTTON_GAP, CONFIRM_BUTTON_BOTTOM)
    confirm.close = ns.Button(confirm, TEXT_CLOSE, CONFIRM_BUTTON_W, Style.BUTTON_H, CancelBuy)
    confirm.close:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", CONFIRM_BUTTON_GAP, CONFIRM_BUTTON_BOTTOM)
    confirm:Hide()
    confirm:HookScript("OnShow", QueuePlace)
    confirm:HookScript("OnHide", QueuePlace)
    market.confirm = confirm
end

local function ConfirmText()
    local state, entry = buy.state, buy.entry
    if state == "searching" then return TEXT_CHECKING, entry.name, "", false, false end
    if state == "checking" then return TEXT_REFRESHING, entry.name, "", false, false end
    if state == "noanswer" then return TEXT_NO_ANSWER, entry.name, "", true, true end
    if state == "done" then
        if entry.mode == Deals.MODE_LEVEL then return TEXT_NO_LISTINGS, entry.name, "", false, false end
        return TEXT_NO_PROFIT, entry.name, TEXT_BREAK_EVEN:format(Coin(entry.value)), false, false
    end
    if state == "buying" then return TEXT_BUYING, entry.name, "", false, false end
    if state == "unconfirmed" then return TEXT_UNCONFIRMED, entry.name, TEXT_CHECK_MAIL, false, false end
    if state == "failed" then return TEXT_FAILED, entry.name, "", true, true end
    if state == "ready" then
        local result = buy.cheapest
        local quantity = math.max(1, result.quantity or 1)
        local nextProfit = entry.value * quantity - result.buyoutAmount
        local enabled = GetMoney() >= result.buyoutAmount
        if entry.mode == Deals.MODE_LEVEL then
            local line3 = nextProfit >= 0 and TEXT_LEVEL_PROFIT:format(SignedCoin(nextProfit))
                or TEXT_LEVEL_COST:format(Coin(-nextProfit))
            return TEXT_LEVEL_AVAILABLE:format(buy.count),
                TEXT_LEVEL_NEXT:format(quantity, Coin(result.buyoutAmount), Coin(entry.value * quantity)),
                line3, enabled, false
        end
        return TEXT_PROFIT_AVAILABLE:format(buy.full and "" or TEXT_AT_LEAST, buy.count, Coin(buy.ceiling)),
            TEXT_INVEST:format(Coin(buy.investment), SignedCoin(buy.profit)),
            TEXT_PROFIT_NEXT:format(quantity, Coin(result.buyoutAmount), SignedCoin(nextProfit)), enabled, false
    end
    return "", "", "", false, false
end

local function LivePriceColor()
    if not (buy and buy.state == "ready" and buy.cheapest) then return T.fg end
    local current, baseline = buy.cheapestUnit, buy.entry.scanPrice
    if current <= baseline then return T.fg end
    if current <= baseline * PRICE_WARNING_RATIO then return Style.GOLD_RGB end
    return Style.RED_RGB
end

RenderConfirm = function()
    if not market then return end
    if not market.confirm then BuildConfirm() end
    local confirm = market.confirm
    if not buy then return confirm:Hide() end
    local line1, line2, line3, enabled, retry = ConfirmText()
    local entry = buy.entry
    confirm.item:SetText(ItemLabel(entry))
    local itemColor = ITEM_QUALITY_COLORS[entry.quality] or T.fg
    confirm.item:SetTextColor(itemColor.r, itemColor.g, itemColor.b)
    confirm.line1:SetText(line1)
    confirm.line2:SetText(line2)
    confirm.line3:SetText(line3)
    local color = LivePriceColor()
    confirm.line2:SetTextColor(color.r, color.g, color.b)
    ns.SetButtonText(confirm.buy, retry and TEXT_TRY_AGAIN or TEXT_BUY_NEXT)
    confirm.buy:SetShown(enabled or retry)
    SetEnabled(confirm.buy, enabled or retry)
    confirm.close:ClearAllPoints()
    if confirm.buy:IsShown() then
        confirm.close:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", CONFIRM_BUTTON_GAP, CONFIRM_BUTTON_BOTTOM)
    else
        confirm.close:SetPoint("BOTTOM", 0, CONFIRM_BUTTON_BOTTOM)
    end
    confirm:Show()
end

local function Purchased(auctionID)
    if not bids[auctionID] then return end
    bids[auctionID] = nil
    if not (buy and buy.auctionID == auctionID) then return end
    local entry, excluded = buy.entry, buy.auctionID
    buy.state = "checking"
    RenderConfirm()
    C_Timer.After(PURCHASE_SETTLE, function()
        if buy and buy.entry == entry and buy.state == "checking" then Search(entry, "checking", excluded) end
    end)
end

local function ItemResults(key)
    local itemID = type(key) == "table" and key.itemID or key
    if buy and (buy.state == "searching" or buy.state == "checking") and itemID == buy.entry.item then ReadDepth() end
end

WatchOpen = function(on)
    for _, event in ipairs(OPEN_EVENTS) do
        if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
    if on and (Deals.Mode() == Deals.MODE_LEVEL or Deals.CurrentSkillOnly()) then
        events:RegisterEvent("SKILL_LINES_CHANGED")
    else
        events:UnregisterEvent("SKILL_LINES_CHANGED")
    end
end

local function Closed()
    WatchOpen(false)
    buy = nil
    wipe(bids)
    Deals.Pause()
    if market then market:Hide() end
end

local function OnEvent(_, event, arg, loaded)
    if event == "AUCTION_HOUSE_SHOW" then
        WatchOpen(true)
        if market then market.dismissed = nil end
        local job = Deals.Job()
        if job and not job.done then Deals.Start() end
        return Render()
    end
    if event == "AUCTION_HOUSE_CLOSED" then return Closed() end
    if event == "ITEM_DATA_LOAD_RESULT" then return Deals.ItemLoaded(arg, loaded) end
    if event == "ITEM_SEARCH_RESULTS_UPDATED" then return ItemResults(arg) end
    if event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then return Purchased(arg) end
    if event == "SKILL_LINES_CHANGED" then return Deals.SkillChanged() end
    if event == "AUCTION_HOUSE_SHOW_ERROR" and buy and buy.state == "buying" then
        bids[buy.auctionID] = nil
        buy.state = "failed"
        return RenderConfirm()
    end
end

local function PricesChanged()
    if not Deals.On() then return end
    Deals.ScanChanged()
    Render()
end

local function Apply()
    if events then events:UnregisterAllEvents() end
    if not Deals.On() then
        Deals.Pause()
        if market then market:Hide() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:RegisterEvent("AUCTION_HOUSE_SHOW")
    events:RegisterEvent("AUCTION_HOUSE_CLOSED")
    if not hooked and ns.ProfWindowRefresh then
        hooksecurefunc(ns, "ProfWindowRefresh", PricesChanged)
        hooked = true
    end
    if AuctionHouseOpen() then WatchOpen(true); Render() end
end

function Deals.Place()
    Place()
end

function Deals.Frames()
    return market, market and market.confirm
end

Deals.SetListener(Render)
S.OnChange(function(key)
    if key == "enabled" or key == "disenchantDeals" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
Apply()
