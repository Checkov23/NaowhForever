-- Browse.lua: the Browse screen's rules: each listing's leader asked once for their card, what is known of them, and which listings show in what order (ns.GroupFinder.Browse).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card, Comms, Listings = GF.Card, GF.Comms, GF.Listings
local S = GF.Settings

local find, lower = string.find, string.lower

local ASK_AGAIN = 300
local KNOWN_MAX = 200
local NO_SCORE, NO_LEVEL = -1, math.huge

local Browse = { ASK_AGAIN = ASK_AGAIN }
GF.Browse = Browse

local asked, without, nAsked = {}, {}, 0

local function Remember(key, now)
    if not asked[key] then
        if nAsked >= KNOWN_MAX then
            wipe(asked)
            wipe(without)
            nAsked = 0
        end
        nAsked = nAsked + 1
    end
    asked[key] = now
end

function Browse.Ask()
    local now = GetTime()
    for i = 1, Listings.n do
        local entry = Listings.entries[i]
        local leader = entry.leader
        if leader and not entry.delisted and not Comms.IsMe(leader) and not Comms.CardOf(leader) then
            local key = Comms.Key(leader)
            local at = asked[key]
            if not at or now - at > ASK_AGAIN then
                if not Comms.Ping(leader, entry.dungeon) then return end
                without[key] = nil
                Remember(key, now)
            end
        end
    end
end

function Browse.Apply(leader, dungeonKey)
    local id = Comms.Apply(leader, dungeonKey, Card.SavedRoles(), "")
    GF.Fire("applied")
    return id
end

function Browse.CardOf(leader)
    local card = Comms.CardOf(leader)
    if card then return card, false end
    local key = Comms.Key(leader)
    return nil, asked[key] ~= nil and not without[key]
end

local function Has(text, needle)
    return text ~= nil and find(lower(text), needle, 1, true) ~= nil
end

function Browse.Matches(entry, needle)
    if needle == "" then return true end
    local activity = entry.activity and Listings.Activity(entry.activity)
    local card = entry.leader and Comms.CardOf(entry.leader)
    local group = card and card.group
    return Has(activity and activity.name, needle) or Has(activity and activity.short, needle)
        or Has(entry.leader, needle) or Has(group and group.note, needle)
end

local function Newest(a, b)
    if a.mine ~= b.mine then return a.mine end
    return a.age < b.age
end

local function BestScore(a, b)
    if a.mine ~= b.mine then return a.mine end
    if a.leaderScore ~= b.leaderScore then return a.leaderScore > b.leaderScore end
    return a.age < b.age
end

local function LowestLevel(a, b)
    if a.mine ~= b.mine then return a.mine end
    if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
    return a.age < b.age
end

local SORTS = { newest = Newest, score = BestScore, level = LowestLevel }

function Browse.Sort(order, how)
    for i = 1, #order do
        local entry = order[i]
        local card = entry.leader and Comms.CardOf(entry.leader)
        local activity = entry.activity and Listings.Activity(entry.activity)
        entry.leaderScore = card and card.score or NO_SCORE
        entry.minLevel = activity and activity.min or NO_LEVEL
    end
    table.sort(order, SORTS[how] or Newest)
end

local function NoCard(ping)
    local key = Comms.Key(ping.name)
    if asked[key] then without[key] = true end
end

GF.Listen("noreply", NoCard)
GF.Listen("offline", NoCard)

S.OnChange(function(key)
    if key == "enabled" and not GF.On() then
        wipe(asked)
        wipe(without)
        nAsked = 0
    end
end)
