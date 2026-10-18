-- ShoppingList.lua: the shopping list beside the auction house: Check Prices, then Buy All one confirmed material at a time.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local C = P.C
local Shopping = P.Shopping
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets

local ROW_H, TOP, MAX_ROWS = 24, 36, 10
local START_H = 120
local DRIFT = 1.10
local THROTTLE_WAIT = 0.5
local MAX_TRIES = 2
local SHOW_DELAY = 0.3
local SETTLE = 0.5
local EDGE = Style.PANEL_EDGE
local TITLE_DROP = 11
local ROW_SHRINK, ICON_SHRINK = 2, Style.ROW_ICON_SHRINK
local REMOVE = 18
local NOTE_GAP, NAME_GAP = Style.NOTE_GAP, Style.ICON_NAME_GAP
local PRIMARY_W, CANCEL_W, SKIP_W = 180, 90, 80
local SKIP_GAP = 6
local MORE_H = 16
local CRAFTS_GAP, CRAFTS_AFTER = 4, 10
local LINE_GAP = 4
local PANEL_GAP = 6
local AH_GAP = 8
local NO_PROFESSION = 0
local PRICE_SORT = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local EVENTS = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "ITEM_DATA_LOAD_RESULT",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_PRICE_UPDATED",
    "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE" }
local PROBLEMS = {
    noquote = ns.L("The auction house gave no final price."),
    unavailable = ns.L("The auction house has no price for it right now."),
    failed = ns.L("The purchase failed; the price may have changed."),
    unconfirmed = ns.L("No answer to the purchase yet; check your mail before trying again."),
}
local RETRY = { ready = true, noquote = true, unavailable = true, failed = true, unconfirmed = true }
local WHITE_CODE = "|cffffffff"
local TEXT_TITLE = ns.L("Shopping List")
local TEXT_CHECK = ns.L("Check Prices")
local TEXT_CLEAR, TEXT_CANCEL, TEXT_SKIP, TEXT_CLOSE = ns.L("Clear"), ns.L("Cancel"), ns.L("Skip"), ns.L("Close")
local TEXT_CONFIRM, TEXT_TRY_AGAIN = ns.L("Confirm"), ns.L("Try Again")
local TEXT_CHECKING_BUTTON = ns.L("Checking...")
local TEXT_GET_PRICE = ns.L("Get Price")
local TEXT_ROW = "%dx %s"
local TEXT_ITEM = ns.L("item ")
local TEXT_UNKNOWN = "?"
local TEXT_MORE = ns.L("+%d more")
local TEXT_FOR = ns.L("For ")
local TEXT_MAKE_FIRST = ns.L(". Make first: ")
local TEXT_NONE_LISTED = ns.L("none listed|r")
local TEXT_ONLY = ns.L("%s  %sonly %d|r")
local TEXT_NO_ANSWER = ns.L("no answer|r")
local TEXT_SINGLE = ns.L("single listings: buy by hand|r")
local TEXT_ABOUT = "~"
local TEXT_NO_PRICE = ns.L("no price|r")
local TEXT_WITHOUT_PRICE = ns.L("without a price")
local TEXT_CHECK_FIRST = ns.L("Check Prices looks each one up first; nothing is bought before you confirm it.|r")
local TEXT_CHECKING = ns.L("Checking prices... (%d/%d)")
local TEXT_ALL_NOW = ns.L("All of it now: %s%s|r")
local TEXT_NO_GOLD = ns.L("You do not have enough gold.|r")
local TEXT_MARKED = ns.L("%d marked red: well above your last scan, or not enough listed.")
local TEXT_EACH_FINAL = ns.L("Buy All asks each final price; you confirm each one.|r")
local TEXT_BUY_ALL = ns.L("Buy All (%s)")
local TEXT_NEXT = ns.L("Next: %dx %s, about %s")
local TEXT_SO_FAR = ns.L("Bought %d so far. The game starts each purchase only from a click.")
local TEXT_BUY_NEXT = ns.L("Buy Next (%s)")
local TEXT_QUOTING = ns.L("%dx %s: getting the final price...")
local TEXT_BUYING_LIST = ns.L("Buying the list: %d bought so far.")
local TEXT_QUOTED = ns.L("%dx %s: %s%s|r  %s(%s each)|r")
local TEXT_UP_FROM = ns.L("Careful: up from %s at the check.")
local TEXT_CHECKED_AT = ns.L("Checked at %s.")
local TEXT_BUYING = ns.L("Buying %dx %s...")
local TEXT_BOUGHT = ns.L("Bought %d %s.")
local TEXT_MATERIAL, TEXT_MATERIALS = ns.L("material"), ns.L("materials")
local TEXT_IN_MAIL = ns.L("They wait in your mailbox.|r")
local TEXT_PROBLEM_ITEM = "%dx %s"
local TIP_REMOVE, TIP_REMOVE_HELP = ns.L("Remove"), ns.L("Takes this material off the shopping list.")

local run
local panel
local pending = false
local learnAt, learned = 0, nil
local craftNames, madeNames = {}, {}
local events = CreateFrame("Frame")
local Render

local function On()
    return S.Get("enabled") and S.Get("shoppingList")
end

local function AuctionHouseOpen()
    local ah = _G.AuctionHouseFrame
    return ah and ah:IsShown()
end

local function Current()
    return run and run.items[run.index]
end

local CheckNext

local function ScheduleCheck()
    run.gen = run.gen + 1
    local gen = run.gen
    C_Timer.After(C.SEARCH_GAP, function()
        if run and run.gen == gen and run.state == "checking" then CheckNext() end
    end)
end

local function WaitForThrottle()
    run.index = run.index - 1
    run.checkWaiting = true
    C_Timer.After(THROTTLE_WAIT, function()
        if run and run.checkWaiting and run.state == "checking" then
            run.checkWaiting = nil
            CheckNext()
        end
    end)
end

function CheckNext()
    run.index = run.index + 1
    local e = Current()
    if not e then
        run.state, run.index = "checked", 0
        return Render()
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        return WaitForThrottle()
    end
    run.checkWaiting = nil
    run.gen = run.gen + 1
    local gen = run.gen
    C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(e.item), PRICE_SORT, true)
    C_Timer.After(C.SEARCH_TIMEOUT, function()
        if run and run.gen == gen and run.state == "checking" then
            e.noanswer = (e.noanswer or 0) + 1
            if e.noanswer < MAX_TRIES then run.index = run.index - 1 end
            ScheduleCheck()
        end
    end)
    Render()
end

local function StartCheck()
    local items = {}
    for _, m in ipairs(Shopping.Materials()) do items[#items + 1] = { item = m.item, qty = m.qty } end
    if #items == 0 then return end
    run = { state = "checking", items = items, index = 0, gen = 0, bought = 0 }
    CheckNext()
end

local function ReadListings(e)
    local have, total = 0, 0
    for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(e.item) or 0 do
        local r = C_AuctionHouse.GetCommoditySearchResultInfo(e.item, i)
        if r then
            local n = math.min((r.quantity or 0) - (r.numOwnerItems or 0), e.qty - have)
            if n > 0 then have, total = have + n, total + n * r.unitPrice end
            if have >= e.qty then break end
        end
    end
    if have < e.qty and not C_AuctionHouse.HasFullCommoditySearchResults(e.item) then
        C_AuctionHouse.RequestMoreCommoditySearchResults(e.item)
        return
    end
    e.found, e.cost = have, total
    local scan = ns.AuctionPrice and ns.AuctionPrice(e.item)
    e.warn = have > 0 and scan and (total / have) > scan * C.OVERPRICED or false
    e.short = have < e.qty
    e.buy = have
    ScheduleCheck()
end

local function CheckedTotal()
    local total, count = 0, 0
    for _, e in ipairs(run.items) do
        if (e.buy or 0) > 0 then total, count = total + e.cost, count + 1 end
    end
    return total, count
end

local function NextBuy()
    repeat
        run.index = run.index + 1
    until not Current() or (Current().buy or 0) > 0
    run.state = Current() and "ready" or "done"
    Render()
end

local function Quote()
    local e = Current()
    if not e then return end
    run.state = "quoting"
    run.gen = run.gen + 1
    local gen = run.gen
    C_AuctionHouse.StartCommoditiesPurchase(e.item, e.buy)
    C_Timer.After(C.SEARCH_TIMEOUT, function()
        if run and run.gen == gen and run.state == "quoting" then
            pcall(C_AuctionHouse.CancelCommoditiesPurchase)
            run.state = "noquote"
            Render()
        end
    end)
    Render()
end

local function Confirm()
    local e = Current()
    if not (e and run.state == "quoted") or GetMoney() < run.total then return end
    run.state = "buying"
    run.gen = run.gen + 1
    local gen = run.gen
    C_AuctionHouse.ConfirmCommoditiesPurchase(e.item, e.buy)
    C_Timer.After(C.BUY_TIMEOUT, function()
        if run and run.gen == gen and run.state == "buying" then
            run.state = "unconfirmed"
            Render()
        end
    end)
    Render()
end

local function CancelQuote()
    if run and (run.state == "quoting" or run.state == "quoted") then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end
end

local function CancelRun()
    CancelQuote()
    run = nil
    Render()
end

local function Skip()
    CancelQuote()
    NextBuy()
end

local function BuyAll()
    run.agreed = true
    run.index = 0
    NextBuy()
    if run.state == "ready" then Quote() end
end

local function Primary()
    local state = run and run.state
    if not run then return StartCheck() end
    if state == "checked" then return BuyAll() end
    if RETRY[state] then return Quote() end
    if state == "quoted" then return Confirm() end
    if state == "done" then
        run = nil
        return Render()
    end
end

local function OnRemove(row)
    if row.item and not run then
        Shopping.Drop(row.item, row.qty)
        Render()
    end
end

local function OnClear()
    if run then return CancelRun() end
    Shopping.Clear()
end

local function OnRowEnter(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.item)
    GameTooltip:Show()
end

local function NewRow(i)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(Style.POPUP_W - 2 * EDGE, ROW_H - ROW_SHRINK)
    row:SetPoint("TOPLEFT", EDGE, -TOP - (i - 1) * ROW_H)
    row:EnableMouse(true)
    row.icon = Widgets.Crop(row:CreateTexture(nil, "ARTWORK"))
    row.icon:SetSize(ROW_H - ICON_SHRINK, ROW_H - ICON_SHRINK)
    row.icon:SetPoint("LEFT")
    row.remove = ns.Button(row, "X", REMOVE, REMOVE, function() OnRemove(row) end)
    row.remove:SetPoint("RIGHT")
    ns.Tooltip(row.remove, TIP_REMOVE, TIP_REMOVE_HELP)
    row.note = ns.Font(row, Style.FONT, nil, T.muted)
    row.note:SetPoint("RIGHT", row.remove, "LEFT", -NOTE_GAP, 0)
    row.note:SetJustifyH("RIGHT")
    row.name = ns.Font(row, Style.FONT, nil)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
    row.name:SetPoint("RIGHT", row.note, "LEFT", -NAME_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:Hide()
    return row
end

local function TextLine(size, wrap)
    local fs = ns.Font(panel, size, nil, size == Style.FONT_SMALL and T.muted or nil)
    fs:SetWidth(Style.POPUP_W - 2 * EDGE)
    fs:SetJustifyH("LEFT")
    if wrap then fs:SetWordWrap(true) end
    return fs
end

local function Build()
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(Style.POPUP_W, START_H)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    ns.Solid(panel, "BACKGROUND", T.bg, Style.WINDOW_ALPHA):SetAllPoints()
    ns.Border(panel, Style.BORDER_RGB)
    panel.title = ns.Font(panel, Style.FONT_LARGE, nil, T.accent)
    panel.title:SetPoint("TOPLEFT", EDGE, -TITLE_DROP)
    panel.title:SetText(TEXT_TITLE)
    panel.rows = {}
    for i = 1, MAX_ROWS do panel.rows[i] = NewRow(i) end
    panel.more = ns.Font(panel, Style.FONT_SMALL, nil, T.muted)
    panel.more:SetJustifyH("LEFT")
    panel.crafts = TextLine(Style.FONT_SMALL, true)
    panel.line1 = TextLine(Style.FONT, false)
    panel.line2 = TextLine(Style.FONT, true)
    panel.primary = ns.Button(panel, TEXT_CHECK, PRIMARY_W, Style.BUTTON_H, Primary)
    panel.primary:SetPoint("BOTTOMLEFT", EDGE, EDGE)
    panel.cancel = ns.Button(panel, TEXT_CLEAR, CANCEL_W, Style.BUTTON_H, OnClear)
    panel.cancel:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    panel.skip = ns.Button(panel, TEXT_SKIP, SKIP_W, Style.BUTTON_H, Skip)
    panel.skip:SetPoint("RIGHT", panel.cancel, "LEFT", -SKIP_GAP, 0)
    panel:Hide()
end

function ns.ShoppingListPlace()
    if not panel then return end
    local ah = _G.AuctionHouseFrame
    local market, confirm, deals, dealConfirm
    if ns.FavoritePatternsFrames then market, confirm = ns.FavoritePatternsFrames() end
    if P.DisenchantDeals and P.DisenchantDeals.Frames then deals, dealConfirm = P.DisenchantDeals.Frames() end
    panel:ClearAllPoints()
    if dealConfirm and dealConfirm:IsVisible() then
        panel:SetPoint("TOPLEFT", dealConfirm, "BOTTOMLEFT", 0, -PANEL_GAP)
    elseif deals and deals:IsVisible() then
        panel:SetPoint("TOPLEFT", deals, "BOTTOMLEFT", 0, -PANEL_GAP)
    elseif confirm and confirm:IsVisible() then
        panel:SetPoint("TOPLEFT", confirm, "BOTTOMLEFT", 0, -PANEL_GAP)
    elseif market and market:IsVisible() then
        panel:SetPoint("TOPLEFT", market, "BOTTOMLEFT", 0, -PANEL_GAP)
    elseif ah then
        panel:SetPoint("TOPLEFT", ah, "TOPRIGHT", AH_GAP, 0)
    end
end

local function RunEntry(item)
    local found
    for _, x in ipairs(run and run.items or {}) do
        if x.item == item then found = x end
    end
    return found
end

local function RowNote(m)
    local e = RunEntry(m.item)
    if e and e.cost then
        if e.found == 0 then return Style.ALERT_CODE .. TEXT_NONE_LISTED end
        local text = Text.Short(e.cost)
        if e.short then text = TEXT_ONLY:format(text, Style.ALERT_CODE, e.found) end
        if e.warn then text = Style.ALERT_CODE .. text .. "|r" end
        return text
    end
    if e and e.noanswer and not e.cost then return Style.ALERT_CODE .. TEXT_NO_ANSWER end
    local muted = Text.Hex(T.muted)
    if e and e.single then return muted .. TEXT_SINGLE end
    local price = Shopping.BuyPrice(m.item)
    return price and (muted .. TEXT_ABOUT .. Text.Short(price * m.qty) .. "|r") or (muted .. TEXT_NO_PRICE)
end

local function CheckedText(muted)
    local total, count = CheckedTotal()
    local warned = 0
    for _, x in ipairs(run.items) do if x.warn or x.short then warned = warned + 1 end end
    local short = GetMoney() < total
    local line2 = short and (Style.ALERT_CODE .. TEXT_NO_GOLD)
        or warned > 0 and (Style.ALERT_CODE .. TEXT_MARKED:format(warned) .. "|r")
        or (muted .. TEXT_EACH_FINAL)
    return TEXT_ALL_NOW:format(short and Style.ALERT_CODE or WHITE_CODE, Text.Short(total)), line2,
        TEXT_BUY_ALL:format(Text.Short(total)), count > 0 and not short, TEXT_CANCEL, false
end

local function QuotedText(e, name, muted)
    local moved = run.total > e.cost * DRIFT
    local short = GetMoney() < run.total
    local line2 = short and (Style.ALERT_CODE .. TEXT_NO_GOLD)
        or moved and (Style.ALERT_CODE .. TEXT_UP_FROM:format(Text.Short(e.cost)) .. "|r")
        or (muted .. TEXT_CHECKED_AT:format(Text.Short(e.cost)) .. "|r")
    return TEXT_QUOTED:format(e.buy, name, (moved or short) and Style.ALERT_CODE or WHITE_CODE,
        Text.Short(run.total), muted, Text.Short(run.unit)), line2, TEXT_CONFIRM, not short, TEXT_CANCEL, true
end

local function RunText(materials)
    local muted = Text.Hex(T.muted)
    local state = run and run.state
    local e = Current()
    local name = e and (Shopping.ItemName(e.item) or (TEXT_ITEM .. e.item))
    if not run then
        return Shopping.Estimate(materials, TEXT_WITHOUT_PRICE) .. ".", muted .. TEXT_CHECK_FIRST,
            TEXT_CHECK, true, TEXT_CLEAR, false
    elseif state == "checking" then
        return TEXT_CHECKING:format(run.index, #run.items), muted .. (name or "") .. "|r",
            TEXT_CHECKING_BUTTON, false, TEXT_CANCEL, false
    elseif state == "checked" then
        return CheckedText(muted)
    elseif state == "ready" then
        return TEXT_NEXT:format(e.buy, name, Text.Short(e.cost)), muted .. TEXT_SO_FAR:format(run.bought) .. "|r",
            run.agreed and TEXT_BUY_NEXT:format(Text.Short(e.cost)) or TEXT_GET_PRICE, true, TEXT_CANCEL, true
    elseif state == "quoting" then
        return TEXT_QUOTING:format(e.buy, name),
            run.agreed and (muted .. TEXT_BUYING_LIST:format(run.bought) .. "|r") or "",
            TEXT_CONFIRM, false, TEXT_CANCEL, true
    elseif state == "quoted" then
        return QuotedText(e, name, muted)
    elseif state == "buying" then
        return TEXT_BUYING:format(e.buy, name), "", TEXT_CONFIRM, false, TEXT_CANCEL, false
    elseif state == "done" then
        return TEXT_BOUGHT:format(run.bought, run.bought == 1 and TEXT_MATERIAL or TEXT_MATERIALS),
            muted .. TEXT_IN_MAIL, TEXT_CLOSE, true, TEXT_CLOSE, false
    end
    return Style.ALERT_CODE .. (PROBLEMS[state] or "") .. "|r",
        muted .. TEXT_PROBLEM_ITEM:format(e and e.buy or 0, name or "") .. "|r", TEXT_TRY_AGAIN, true, TEXT_CANCEL, true
end

local function FillRows(materials)
    for i, row in ipairs(panel.rows) do
        local m = materials[i]
        row.item, row.qty = m and m.item, m and m.qty
        if m then
            row.icon:SetTexture(C_Item.GetItemIconByID(m.item))
            row.name:SetText(TEXT_ROW:format(m.qty, Shopping.ItemName(m.item) or (TEXT_ITEM .. m.item)))
            row.note:SetText(RowNote(m))
            row.remove:SetShown(not run)
            row:Show()
        else
            row:Hide()
        end
    end
end

local function ForWhat(made)
    wipe(craftNames)
    for _, craft in pairs(Shopping.List()) do
        craftNames[#craftNames + 1] = TEXT_ROW:format(craft.count, craft.name or TEXT_UNKNOWN)
    end
    table.sort(craftNames)
    wipe(madeNames)
    for item, qty in pairs(made) do
        madeNames[#madeNames + 1] = TEXT_ROW:format(qty, Shopping.ItemName(item) or (TEXT_ITEM .. item))
    end
    table.sort(madeNames)
    return (#craftNames > 0 and (TEXT_FOR .. table.concat(craftNames, ", ")) or "")
        .. (#madeNames > 0 and (TEXT_MAKE_FIRST .. table.concat(madeNames, ", ")) or "")
end

Render = function()
    Shopping.RenderWindow()
    if not (On() and AuctionHouseOpen()) then return panel and panel:Hide() end
    local materials, made = Shopping.Materials()
    if #materials == 0 and not run then return panel and panel:Hide() end
    if not panel then Build() end
    FillRows(materials)
    local y = -TOP - math.min(#materials, MAX_ROWS) * ROW_H
    panel.more:ClearAllPoints()
    panel.more:SetPoint("TOPLEFT", EDGE, y)
    panel.more:SetText(#materials > MAX_ROWS and TEXT_MORE:format(#materials - MAX_ROWS) or "")
    if #materials > MAX_ROWS then y = y - MORE_H end
    panel.crafts:ClearAllPoints()
    panel.crafts:SetPoint("TOPLEFT", EDGE, y - CRAFTS_GAP)
    panel.crafts:SetText(ForWhat(made))
    y = y - CRAFTS_GAP - (#craftNames > 0 and panel.crafts:GetStringHeight() or 0) - CRAFTS_AFTER
    local line1, line2, primary, enabled, cancel, skip = RunText(materials)
    panel.line1:ClearAllPoints()
    panel.line1:SetPoint("TOPLEFT", EDGE, y)
    panel.line1:SetText(line1)
    panel.line2:ClearAllPoints()
    panel.line2:SetPoint("TOPLEFT", panel.line1, "BOTTOMLEFT", 0, -LINE_GAP)
    panel.line2:SetText(line2)
    y = y - panel.line1:GetStringHeight() - LINE_GAP - panel.line2:GetStringHeight()
    ns.SetButtonText(panel.primary, primary)
    Widgets.EnableButton(panel.primary, enabled)
    panel.primary:SetShown(not (run and run.state == "done"))
    ns.SetButtonText(panel.cancel, cancel)
    panel.skip:SetShown(skip)
    panel:SetHeight(-y + EDGE + Style.BUTTON_H + EDGE)
    ns.ShoppingListPlace()
    panel:Show()
end
Shopping.Render = Render

local function Flush()
    pending = false
    Render()
end

local function LearnSettled(at)
    if learnAt ~= at or not On() then return end
    local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    local ids = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
    local key = (base and base.professionID or NO_PROFESSION) .. ":" .. (ids and #ids or 0)
    if key ~= learned then
        learned = key
        Shopping.Learn()
    end
    if Render then Render() end
end

local function OnTradeSkill(event)
    if event == "TRADE_SKILL_SHOW" then learned = nil end
    learnAt = GetTime()
    local at = learnAt
    C_Timer.After(SETTLE, function() LearnSettled(at) end)
end

local function OnItemLoaded(item, ok)
    if not Shopping.waiting[item] then return end
    Shopping.waiting[item] = nil
    if ok and not pending then
        pending = true
        C_Timer.After(0, Flush)
    end
end

local function OnPurchased(e)
    run.bought = run.bought + 1
    Shopping.Bought(e.item, e.buy)
    NextBuy()
end

local function OnRunEvent(event, a, b)
    local e = Current()
    if run and event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" and run.checkWaiting then
        run.checkWaiting = nil
        return CheckNext()
    end
    if not (run and e) then return end
    local state = run.state
    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" and state == "checking" and a == e.item then
        ReadListings(e)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" and state == "checking" and type(a) == "table"
        and a.itemID == e.item then
        e.single, e.buy = true, 0
        ScheduleCheck()
    elseif event == "COMMODITY_PRICE_UPDATED" and state == "quoting" then
        run.state, run.unit, run.total = "quoted", a, b
        Render()
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" and state == "quoting" then
        run.state = "unavailable"
        Render()
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" and (state == "buying" or state == "unconfirmed") then
        OnPurchased(e)
    elseif event == "COMMODITY_PURCHASE_FAILED" and state == "buying" then
        run.state = "failed"
        Render()
    end
end

local function OnEvent(_, event, a, b)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then return OnTradeSkill(event) end
    if event == "AUCTION_HOUSE_SHOW" then return C_Timer.After(SHOW_DELAY, Render) end
    if event == "AUCTION_HOUSE_CLOSED" then
        if run then CancelRun() end
        if panel then panel:Hide() end
        return
    end
    if event == "ITEM_DATA_LOAD_RESULT" then return OnItemLoaded(a, b) end
    OnRunEvent(event, a, b)
end

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        if run then CancelRun() end
        if panel then panel:Hide() end
        Shopping.HideAdd()
        return
    end
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
end

local function OnSettingChanged(key)
    if key ~= "enabled" and key ~= "shoppingList" then return end
    Apply()
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
