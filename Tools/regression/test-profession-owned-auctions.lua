-- Run with Lua 5.1 from the repository root: owned auctions stay opt-in, cached per character and filter recipes.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end
local function Noop() end

local values, listeners, account = {}, {}, {}
local applyHooks = {}
local frames, registry, timers = {}, {}, {}
local owned, queries, refreshes = {}, 0, 0
local player = "Alpha"
local playerGUID = "Player-Alpha"

local function CharacterData(store, create)
    account[store] = account[store] or {}
    local mine = account[store][playerGUID]
    if mine or not create then return mine end
    mine = {}
    account[store][playerGUID] = mine
    return mine
end

local frameMethods = {}
function frameMethods:RegisterEvent(event)
    registry[event] = registry[event] or {}
    registry[event][self] = true
end
function frameMethods:UnregisterAllEvents()
    for _, set in pairs(registry) do set[self] = nil end
end
function frameMethods:SetScript(name, fn) self.scripts[name] = fn end

local function Listening()
    local n = 0
    for _, set in pairs(registry) do for _ in pairs(set) do n = n + 1 end end
    return n
end

local function Fire(event)
    local copy = {}
    for frame in pairs(registry[event] or {}) do copy[#copy + 1] = frame end
    for _, frame in ipairs(copy) do frame.scripts.OnEvent(frame, event) end
end

local function RunTimers()
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
end

local ns = {
    L = function(text) return text end,
    UI = {
        ModuleSettings = function(_, defaults)
            local S = {}
            function S.Get(key)
                if values[key] == nil then return defaults[key] end
                return values[key]
            end
            function S.Set(key, value)
                values[key] = value
                for _, fn in ipairs(listeners) do fn(key, value) end
            end
            function S.OnChange(fn) listeners[#listeners + 1] = fn end
            return S
        end,
    },
    Shared = { CharacterData = CharacterData },
    AccountSettings = function() return account end,
    Apply = Noop,
}

local env = setmetatable({
    NaowhForever = ns,
    Enum = { AuctionStatus = { Active = 0 }, AuctionHouseSortOrder = { Price = 0 } },
    UnitName = function() return player end,
    UnitGUID = function() return playerGUID end,
    GetRealmName = function() return "Realm" end,
    CreateFrame = function()
        local frame = setmetatable({ scripts = {} }, { __index = frameMethods })
        frames[#frames + 1] = frame
        return frame
    end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_AuctionHouse = {
        IsThrottledMessageSystemReady = function() return true end,
        QueryOwnedAuctions = function() queries = queries + 1 end,
        GetNumOwnedAuctions = function() return #owned end,
        GetOwnedAuctionInfo = function(index) return owned[index] end,
    },
    C_Item = { GetItemInfo = Noop },
    hooksecurefunc = function(target, name, fn)
        if target == ns and name == "Apply" then applyHooks[#applyHooks + 1] = fn end
    end,
    time = function() return 12345 end,
    wipe = function(t) for key in pairs(t) do t[key] = nil end return t end,
}, { __index = _G })
env._G = env

Load({ "Core/Features.lua", "NaowhForever_Professions/Professions.lua" }, env)
local P, S = ns.Professions, ns.ProfessionSettings
P.C = { QUEUE_DELAY = 0.2 }
P.AH = { Open = function() return false end }
ns.ProfWindowRefresh = function() refreshes = refreshes + 1 end
Load({ "NaowhForever_Professions/Auctions.lua" }, env)

Check("the feature is off by default", not P.Auctions.On())
Check("off creates no frame and registers no events", #frames == 0 and Listening() == 0)

S.Set("ownedAuctions", true)
Check("turning it on creates one event frame", #frames == 1 and Listening() == 5)
Check("the filter is not ready before an owner list", not P.Auctions.Ready())

Fire("AUCTION_HOUSE_SHOW")
Check("opening the auction house coalesces the query", queries == 0 and #timers == 1)
Fire("AUCTION_HOUSE_AUCTION_CREATED")
Check("a post does not add a duplicate timer", #timers == 1)
RunTimers()
Check("the queued owner-list query is sent once", queries == 1)

owned = {
    { status = 0, itemKey = { itemID = 100 }, quantity = 2 },
    { status = 0, itemKey = { itemID = 100 }, quantity = 3 },
    { status = 1, itemKey = { itemID = 200 }, quantity = 9 },
}
Fire("OWNED_AUCTIONS_UPDATED")
Check("active quantities are combined and inactive auctions ignored",
    P.Auctions.Count(100) == 5 and P.Auctions.Count(200) == 0)
Check("a complete list marks the cache ready and refreshes the window", P.Auctions.Ready() and refreshes == 1)
Check("counts are saved under the character's GUID", account.profOwnedAuctions["Player-Alpha"].counts[100] == 5)

Fire("AUCTION_CANCELED")
Check("a cancel sends no query of its own", queries == 1 and #timers == 0)
owned[2] = nil
Fire("OWNED_AUCTIONS_UPDATED")
Check("the owner list the auction house reloads after a cancel is read", P.Auctions.Count(100) == 2)

P.Recipes = {
    OutputItem = function(recipeID) return recipeID == 1 and 100 or 300 end,
    Craftable = function() return 1 end,
    Request = Noop,
}
P.Prices = {
    ProfitShown = function() return true end,
    RecipeProfit = function(recipeID) return recipeID == 2 and -1 or 10 end,
}
P.Favorites = { Is = function() return false end }
Load({ "NaowhForever_Professions/Filters.lua" }, env)
S.Set("filterNotSelling", true)
Check("Not Selling is available after the first owner list", P.Filters.Available(P.Filters.LIST.filterNotSelling))
Check("Not Selling excludes a learned recipe with active auctions",
    not P.Filters.Passes({ recipeID = 1, relativeDifficulty = 1 }, {}))
Check("Not Selling keeps a learned recipe with no active auctions",
    P.Filters.Passes({ recipeID = 3, relativeDifficulty = 1 }, {}))
Check("Not Selling excludes recipes the character has not learned", not P.Filters.Passes(nil, { spell = 3 }))

S.Set("filterProfit", true)
Check("Not Selling combines with Profitable", P.Filters.Passes({ recipeID = 3, relativeDifficulty = 1 }, {})
    and not P.Filters.Passes({ recipeID = 2, relativeDifficulty = 1 }, {}))

player, playerGUID = "Beta", "Player-Beta"
Check("auction counts do not leak to another character", P.Auctions.Count(100) == 0 and not P.Auctions.Ready())
player, playerGUID = "Alpha", "Player-Alpha"
Check("returning to the character restores its cache", P.Auctions.Count(100) == 2 and P.Auctions.Ready())

S.Set("ownedAuctions", false)
Check("turning it off unregisters every event", Listening() == 0)
Check("off exposes no cached auction counts", P.Auctions.Count(100) == 0 and not P.Auctions.Ready())

values.ownedAuctions = true
for _, fn in ipairs(applyHooks) do fn() end
Check("applying a profile turns the feature back on", P.Auctions.On() and Listening() == 5)

print(("test-profession-owned-auctions: %d checks passed"):format(checks))
