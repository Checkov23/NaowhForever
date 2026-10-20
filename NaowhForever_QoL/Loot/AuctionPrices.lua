-- AuctionPrices.lua: Auction Prices, the lowest buyout per item from a full scan, per realm and faction.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local SCAN_COOLDOWN = 900
local CHUNK = 1000
local TIMEOUT = 60
local AGE_TICK = 60
local SECONDS_PER_MINUTE, SECONDS_PER_HOUR = ns.QoLConstants.SECONDS_PER_MINUTE, ns.QoLConstants.SECONDS_PER_HOUR
local SECONDS_PER_DAY = ns.QoLConstants.SECONDS_PER_DAY
local PERCENT = ns.QoLConstants.PERCENT
local BUTTON_W, BUTTON_H = 120, 24
local BUTTON_GAP, BUTTON_DROP = 8, 4
local AGE_SIZE = 11
local COIN_SIZE = 12
local WHITE = ns.QoLConstants.WHITE_RGB
local REALM_JOIN = "-"
local function Tag() return ns.Color("accent", "Naowh AH") end
local TEXT_SCAN = ns.L("Scan Prices")
local TEXT_SCANNING = ns.L("Scanning...")
local TEXT_PROGRESS = ns.L("Scanning %d%%")
local TEXT_NO_SCAN = ns.L("No scan yet for this realm and faction")
local TEXT_NO_SCAN_SHORT = ns.L("No scan yet")
local TEXT_SCAN_LINE = ns.L("Last scan %s ago: %s items priced")
local TEXT_AGE = ns.L("Last scan %s ago%s")
local TEXT_NEXT = ns.L(", next in %dm")
local TEXT_EMPTY = ns.L("The auction house returned no listings. Try again in a moment.")
local TEXT_WAIT = ns.L("%s: Blizzard allows one full scan every 15 minutes. Next scan in %dm.")
local TEXT_TIMEOUT = ns.L("no answer from the auction house. A full scan can only run once every 15 minutes.")
local TEXT_CLOSED = ns.L("scan stopped: the auction house closed.")
local TEXT_TIP = ns.L("Reads every listing on the auction house and keeps the lowest buyout for "
    .. "each item, shown on item tooltips. Blizzard allows one full scan every 15 "
    .. "minutes.\n\n")
local TEXT_EACH = ns.L(" |cff808080each, %s ago|r")
local MINUTES, HOURS, DAYS = "m", "h", "d"

local button, scanning, scanGen = nil, nil, 0
local houseKey
local priced, pricedAt
local ageTicker

local function House(create)
    local account = ns.AccountSettings()
    account.ahPrices = account.ahPrices or {}
    houseKey = houseKey or GetRealmName() .. REALM_JOIN .. (UnitFactionGroup("player") or "")
    if create and not account.ahPrices[houseKey] then account.ahPrices[houseKey] = { prices = {} } end
    return account.ahPrices[houseKey]
end

function ns.AuctionPrice(itemID)
    local house = House()
    if house and itemID then return house.prices[itemID], house.time end
end

function ns.AuctionScanTime()
    local house = House()
    return house and house.time
end

function ns.AuctionPriceList()
    local house = House()
    return house and house.prices, house and house.time
end

local function Age(seconds)
    if seconds < SECONDS_PER_HOUR then return math.max(1, math.floor(seconds / SECONDS_PER_MINUTE)) .. MINUTES end
    if seconds < SECONDS_PER_DAY then return math.floor(seconds / SECONDS_PER_HOUR) .. HOURS end
    return math.floor(seconds / SECONDS_PER_DAY) .. DAYS
end
ns.AuctionAge = Age

local function Priced(house)
    if pricedAt ~= house.time then
        priced = 0
        for _ in pairs(house.prices) do priced = priced + 1 end
        pricedAt = house.time
    end
    return priced
end

local function ScanLine()
    local house = House()
    if not (house and house.time) then return TEXT_NO_SCAN end
    return TEXT_SCAN_LINE:format(Age(time() - house.time), BreakUpLargeNumbers(Priced(house)))
end

function ns.AuctionScanSummary()
    return ScanLine() .. "."
end

local function Label(text)
    if button then button.label:SetText(text) end
end

local function ShowAge()
    if not (button and button.age) then return end
    local house = House()
    if not (house and house.time) then return button.age:SetText(TEXT_NO_SCAN_SHORT) end
    local since = time() - house.time
    local wait = SCAN_COOLDOWN - since
    button.age:SetText(TEXT_AGE:format(Age(since),
        wait > 0 and TEXT_NEXT:format(math.ceil(wait / SECONDS_PER_MINUTE)) or ""))
end

local events = CreateFrame("Frame")

local function Stop(message)
    scanning = nil
    scanGen = scanGen + 1
    events:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    Label(TEXT_SCAN)
    if message then ns.Print(Tag() .. ": " .. message) end
end

local function ReadListing(prices, i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID =
        C_AuctionHouse.GetReplicateItemInfo(i)
    if not (itemID and buyout and buyout > 0 and count and count > 0) then return end
    local each = math.floor(buyout / count)
    if not prices[itemID] or each < prices[itemID] then prices[itemID] = each end
end

local function Finish(prices)
    local house = House(true)
    house.prices, house.time = prices, time()
    Stop()
    ShowAge()
    ns.Print(Tag() .. ": " .. ns.AuctionScanSummary())
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

local function Read()
    events:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    local total = C_AuctionHouse.GetNumReplicateItems()
    if total == 0 then return Stop(TEXT_EMPTY) end
    local prices, index, gen = {}, 0, scanGen
    local function Step()
        if gen ~= scanGen then return end
        local last = math.min(index + CHUNK, total) - 1
        for i = index, last do ReadListing(prices, i) end
        index = last + 1
        if index < total then
            Label(TEXT_PROGRESS:format(math.floor(index * PERCENT / total)))
            C_Timer.After(0, Step)
            return
        end
        Finish(prices)
    end
    Step()
end

local function Wait()
    local house = House()
    return house and house.time and SCAN_COOLDOWN - (time() - house.time)
end

local function OnTimeout(gen)
    if gen == scanGen and scanning then Stop(TEXT_TIMEOUT) end
end

local function Scan()
    if scanning then return end
    local wait = Wait()
    if wait and wait > 0 then
        ns.Print(TEXT_WAIT:format(Tag(), math.ceil(wait / SECONDS_PER_MINUTE)))
        return
    end
    scanning = true
    scanGen = scanGen + 1
    local gen = scanGen
    Label(TEXT_SCANNING)
    events:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    C_AuctionHouse.ReplicateItems()
    C_Timer.After(TIMEOUT, function() OnTimeout(gen) end)
end

local function ButtonTip()
    return TEXT_TIP .. ns.AuctionScanSummary()
end

local function LastTab(frame)
    local lib = LibStub and LibStub("LibAHTab-1-0", true)
    local tabs = lib and lib.internalState and lib.internalState.Tabs
    if tabs and #tabs > 0 then return tabs[#tabs] end
    return frame.AuctionsTab
end

local function Anchor()
    local frame = _G.AuctionHouseFrame
    if not (button and frame) then return end
    button:ClearAllPoints()
    local tab = LastTab(frame)
    if tab then
        button:SetPoint("LEFT", tab, "RIGHT", BUTTON_GAP, 0)
    else
        button:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -BUTTON_GAP, -BUTTON_DROP)
    end
end

local function BuildButton(frame)
    button = ns.Button(frame, TEXT_SCAN, BUTTON_W, BUTTON_H, Scan)
    ns.Tooltip(button, TEXT_SCAN, ButtonTip)
    button.age = ns.Font(button, AGE_SIZE, nil, ns.THEME.muted)
    button.age:SetPoint("LEFT", button, "RIGHT", BUTTON_GAP, 0)
end

local function ShowButton()
    local frame = _G.AuctionHouseFrame
    if not frame or ns.GamepadStandDown() then return end
    if not button then BuildButton(frame) end
    Anchor()
    C_Timer.After(0, Anchor)
    button:SetShown(S.Get("ahPrices"))
    ShowAge()
    if S.Get("ahPrices") and not ageTicker then ageTicker = C_Timer.NewTicker(AGE_TICK, ShowAge) end
end

local function OnClosed()
    if scanning then Stop(TEXT_CLOSED) end
    if ageTicker then
        ageTicker:Cancel()
        ageTicker = nil
    end
end

local function OnEvent(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        ShowButton()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        OnClosed()
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        Read()
    end
end

local function OnSettingChanged(key)
    if key == "ahPrices" and button then button:SetShown(S.Get("ahPrices")) end
end

local function OnItemTooltip(tooltip, data)
    if not S.Get("ahTooltip") then return end
    local id = data and data.id
    if not id or (issecretvalue and issecretvalue(id)) then return end
    local price, when = ns.AuctionPrice(id)
    if not price then return end
    tooltip:AddDoubleLine(Tag(), C_CurrencyInfo.GetCoinTextureString(price, COIN_SIZE)
        .. TEXT_EACH:format(Age(time() - when)), WHITE.r, WHITE.g, WHITE.b, WHITE.r, WHITE.g, WHITE.b)
end

events:SetScript("OnEvent", OnEvent)
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
hooksecurefunc(S, "Set", OnSettingChanged)
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "auctionPrices", name = "Auction Prices", order = 30, into = "lootTrade",
    rows = {
        { key = "ahPrices", label = "Scan Prices Button", toggle = true, note = ScanLine,
          needs = ns.GamepadFree, why = ns.GamepadWhy,
          help = "A Scan Prices button on the auction house. It reads every listing and keeps the "
              .. "lowest buyout for each item, for this realm and faction. Blizzard allows one full "
              .. "scan every 15 minutes." },
        { key = "ahTooltip", label = "Auction House Price", toggle = true,
          help = "Item tooltips show the item's price at your last auction house scan, for one of it, "
              .. "and how long ago that was. Scan with the Scan Prices button on the auction house." },
    },
})
