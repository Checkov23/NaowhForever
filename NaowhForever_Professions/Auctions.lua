-- Auctions.lua: active auction-house quantities for the current character's crafted items.
local ns = _G.NaowhForever

local GetNumOwnedAuctions = C_AuctionHouse.GetNumOwnedAuctions
local GetOwnedAuctionInfo = C_AuctionHouse.GetOwnedAuctionInfo
local IsThrottledMessageSystemReady = C_AuctionHouse.IsThrottledMessageSystemReady
local QueryOwnedAuctions = C_AuctionHouse.QueryOwnedAuctions

local P = ns.Professions
local S = P.Settings
local C = P.C

local ACTIVE = Enum.AuctionStatus.Active
local OWNED_SORT = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local EVENTS = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED",
    "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }
local SETTING_KEYS = { enabled = true, ownedAuctions = true }

local events
local open, wanted = false, false

local Auctions = {}
P.Auctions = Auctions

local function On()
    return P.On() and S.Get("ownedAuctions")
end

local function Saved(create)
    local saved = P.CharacterData("profOwnedAuctions", create)
    if not saved then return end
    if type(saved.counts) ~= "table" then saved.counts = {} end
    return saved
end

local function Refresh()
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

local function Read()
    local saved = Saved(true)
    if not saved then return end
    wipe(saved.counts)
    for i = 1, GetNumOwnedAuctions() or 0 do
        local info = GetOwnedAuctionInfo(i)
        local itemID = info and info.status == ACTIVE and info.itemKey and info.itemKey.itemID
        if itemID then saved.counts[itemID] = (saved.counts[itemID] or 0) + (info.quantity or 1) end
    end
    saved.updated = time()
    wanted = false
    Refresh()
end

local function Request()
    if not (On() and open and wanted) then return end
    if not IsThrottledMessageSystemReady() then return end
    wanted = false
    QueryOwnedAuctions(OWNED_SORT)
end

local function QueueRequest()
    if not open or wanted then return end
    wanted = true
    C_Timer.After(C.QUEUE_DELAY, Request)
end

local function OnEvent(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        open = true
        QueueRequest()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        open, wanted = false, false
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        Read()
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        Request()
    else
        QueueRequest()
    end
end

function Auctions.On()
    return On() and true or false
end

function Auctions.Ready()
    local saved = On() and Saved(false)
    return type(saved) == "table" and saved.updated ~= nil
end

function Auctions.Count(itemID)
    local saved = itemID and On() and Saved(false)
    return saved and saved.counts[itemID] or 0
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        open, wanted = false, false
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    open = P.AH and P.AH.Open() and true or false
    if open then QueueRequest() end
end

local function OnSettingChanged(key)
    if SETTING_KEYS[key] then Apply() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
Apply()
