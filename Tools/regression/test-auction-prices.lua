-- Run with Lua 5.1 from the repository root: shared replication results and settings lifecycle.
local Load = dofile("Tools/regression/load_files.lua")
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end
local function Noop() end

local function Setup(buttonOn, captureOn, withFrame)
    local values = { ahPrices = buttonOn, ahCapture = captureOn }
    local account, registered, timers, messages = {}, {}, {}, {}
    local now, requests, refreshes, total = 10000, 0, 0, 1001
    local allInfo = true
    local replicateHooks, reloads = 0, 0
    local card, button
    local frame = {}
    function frame:RegisterEvent(event) registered[event] = true end
    function frame:UnregisterEvent(event) registered[event] = nil end
    function frame:SetScript(_, fn) self.handler = fn end
    local S = { Get = function(key) return values[key] end,
        Set = function(key, value) values[key] = value end }
    local ns = {
        QoLSettings = S,
        QoLConstants = { SECONDS_PER_MINUTE = 60, SECONDS_PER_HOUR = 3600,
            SECONDS_PER_DAY = 86400, PERCENT = 100, WHITE_RGB = {} },
        L = function(text) return text end,
        Color = function(_, text) return text end,
        AccountSettings = function() return account end,
        ConfirmReload = function() reloads = reloads + 1 end,
        GamepadStandDown = function() return false end,
        Print = function(text) messages[#messages + 1] = text end,
        ProfWindowRefresh = function() refreshes = refreshes + 1 end,
        THEME = {},
        Tooltip = Noop,
        Font = function() return { SetPoint = Noop, SetText = Noop } end,
        Button = function(_, _, _, _, click)
            button = { click = click, label = { SetText = Noop },
                ClearAllPoints = Noop, SetPoint = Noop,
                SetShown = function(self, on) self.shown = on end }
            return button
        end,
        Shared = { Settings = { Page = function()
            return { Card = function(_, spec) card = spec end }
        end } },
    }
    local env = setmetatable({
        NaowhForever = ns,
        AuctionHouseFrame = withFrame and {} or nil,
        CreateFrame = function() return frame end,
        GetRealmName = function() return "Realm" end,
        UnitFactionGroup = function() return "Alliance" end,
        time = function() return now end,
        BreakUpLargeNumbers = tostring,
        C_Timer = {
            After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end,
            NewTicker = function() return { Cancel = Noop } end,
        },
        C_AuctionHouse = {
            ReplicateItems = function() requests = requests + 1 end,
            GetNumReplicateItems = function() return total end,
            GetReplicateItemInfo = function(i)
                local count, buyout, id = 2, 101, 10
                if i == 1 then buyout = 99 end
                if i == 2 then count = 0 end
                if i == 3 then buyout = 0 end
                if i == 1000 then id, buyout = 20, 200 end
                return nil, nil, count, nil, nil, nil, nil, nil, nil, buyout,
                    nil, nil, nil, nil, nil, nil, id, allInfo
            end,
        },
        hooksecurefunc = function(target, key, hook)
            if key == "ReplicateItems" then replicateHooks = replicateHooks + 1 end
            local original = target[key]
            target[key] = function(...)
                original(...)
                hook(...)
            end
        end,
        TooltipDataProcessor = { AddTooltipPostCall = Noop },
        Enum = { TooltipDataType = { Item = 0 } },
    }, { __index = _G })
    env._G = env
    Load({ "NaowhForever_QoL/Loot/AuctionPrices.lua" }, env)
    local t = { ns = ns, settings = S, messages = messages, card = card }
    function t.Fire(event)
        if registered[event] then frame.handler(frame, event) end
    end
    function t.ExternalScan() env.C_AuctionHouse.ReplicateItems() end
    function t.Listening() return registered.REPLICATE_ITEM_LIST_UPDATE end
    function t.Requests() return requests end
    function t.Refreshes() return refreshes end
    function t.Button() return button end
    function t.Reloads() return reloads end
    function t.ReplicateHooks() return replicateHooks end
    function t.Flush() for _ = 1, 20 do t.Run(0) end end
    function t.AllInfo(value) allInfo = value end
    function t.Total(value) total = value end
    function t.Advance(seconds) now = now + seconds end
    function t.Run(delay)
        local pending = timers
        timers = {}
        for _, timer in ipairs(pending) do
            if timer.delay == delay then timer.fn() else timers[#timers + 1] = timer end
        end
    end
    return t
end

local t = Setup(true, true, true)
t.Fire("AUCTION_HOUSE_SHOW")
Check("enabled capture hooks once but opening does not listen or request", not t.Listening()
    and t.Requests() == 0 and t.ReplicateHooks() == 1)
t.AllInfo(false)
t.ExternalScan()
Check("external request arms results", t.Listening())
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
Check("reading unsubscribes immediately", not t.Listening())
t.Button().click()
Check("click during read does not request", t.Requests() == 1)
t.Flush()
Check("capture finishes without waiting on unused item data", t.Refreshes() == 1 and #t.messages == 1 and not t.Listening())
local prices, when = t.ns.AuctionPriceList()
Check("minimum unit prices preserved", prices[10] == 49 and prices[20] == 100 and when == 10000)
for _ = 1, 100 do t.Fire("REPLICATE_ITEM_LIST_UPDATE"); t.Flush() end
Check("late Auctionator cache events do not repeat completion", t.Refreshes() == 1 and #t.messages == 1 and t.ns.AuctionScanTime() == when)
t.Button().click()
Check("capture retains cooldown", t.Requests() == 1 and #t.messages == 2)
t.Advance(901)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("next external request captures in same visit", t.Refreshes() == 2 and not t.Listening())
t.Advance(901)
t.Button().click()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
t.Run(60)
Check("manual request completes once and stale timeout is ignored", t.Refreshes() == 3 and not t.Listening())
t.Advance(901)
local printed = #t.messages
t.ExternalScan()
t.Run(60)
Check("external unanswered request times out silently", #t.messages == printed and not t.Listening())
t.Total(0)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
Check("empty capture preserves prices silently", t.ns.AuctionPrice(10) == 49 and #t.messages == printed and not t.Listening())
t.Total(1001)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Fire("AUCTION_HOUSE_CLOSED")
t.Flush()
Check("closing cancels unfinished batches silently", t.Refreshes() == 3 and #t.messages == printed and not t.Listening())
t.ExternalScan()
Check("closed house does not arm capture", not t.Listening())

t = Setup(true, false, true)
t.Fire("AUCTION_HOUSE_SHOW")
Check("capture defaults install no hook", t.ReplicateHooks() == 0)
t.ExternalScan()
Check("button alone ignores external scans", not t.Listening())
t.Button().click()
Check("manual scan requests and listens", t.Requests() == 2 and t.Listening())
t.Run(60)
Check("manual unanswered request reports timeout", t.messages[#t.messages]:find("no answer", 1, true) and not t.Listening())

t = Setup(false, false, true)
t.Fire("AUCTION_HOUSE_SHOW")
Check("disabled defaults install no hook", t.ReplicateHooks() == 0 and not t.Listening())
local capture = t.card.rows[3]
Check("capture row always shown", capture.key == "ahCapture" and capture.label == "Capture Other Addons' Scans" and capture.hidden == nil)
t.settings.Set("ahCapture", true)
Check("first enable installs hook without arming results", t.ReplicateHooks() == 1 and not t.Listening() and not t.Button().shown)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.settings.Set("ahCapture", false)
t.Flush()
Check("disable during read lets it finish", t.Refreshes() == 1 and not t.Listening())
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("installed hook ignores requests after disabling", t.Refreshes() == 1 and not t.Listening())
t.settings.Set("ahCapture", true)
Check("reenabling does not install duplicate hooks", t.ReplicateHooks() == 1)
t.Advance(901)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("capture works with the button hidden", t.Refreshes() == 2 and not t.Button().shown)
t.settings.Set("ahPrices", true)
t.settings.Set("ahPrices", false)
t.settings.Set("ahCapture", false)
Check("toggling never asks for a reload", t.Reloads() == 0)

t = Setup(true, true, false)
t.Fire("AUCTION_HOUSE_SHOW")
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("capture works without visual AH frame", t.Refreshes() == 1)
print("auction prices: " .. checks .. " checks passed")
