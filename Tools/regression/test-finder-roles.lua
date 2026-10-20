-- Run with Lua 5.1 from the repository root: Group Finder Roles.
-- Off it builds and hooks nothing. On, rows that do not match the picks fade out with their mouse off,
-- while the Group Finder's results, totals and refresh are never touched. Every row fading shows a
-- hint, and in chat messaging lockdown nothing is read or filtered.
local NOTHING = function() end
local frames = {}
local lockdown = false
local infoReads = 0

local function Region()
    local r = { shown = true }
    function r:SetPoint() end
    function r:SetSize() end
    function r:SetWidth() end
    function r:SetHeight() end
    function r:SetText(t) self.text = t end
    function r:GetStringWidth() return 40 end
    function r:SetAllPoints() end
    function r:SetAtlas(a) self.atlas = a end
    function r:SetDesaturated(d) self.desaturated = d end
    function r:SetAlpha(a) self.alpha = a end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(s) self.shown = s and true or false end
    function r:IsShown() return self.shown end
    return r
end

local function Frame()
    local f = Region()
    f.scripts, f.events = {}, {}
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:RegisterForClicks() end
    function f:SetFrameLevel() end
    function f:GetFrameLevel() return 1 end
    function f:CreateTexture() return Region() end
    frames[#frames + 1] = f
    return f
end

local function Entry(resultID)
    local e = Region()
    e.resultID = resultID
    e.alphaSets = 0
    function e:SetAlpha(a) self.alpha = a; self.alphaSets = self.alphaSets + 1 end
    function e:EnableMouse(on) self.mouse = on end
    return e
end

local results = { 1, 2, 3, 4, 5 }
local listings = {
    [1] = { hasSelf = true, numMembers = 1 },
    [2] = { numMembers = 1, roles = { healer = true } },
    [3] = { numMembers = 1, roles = { dps = true } },
    [4] = { numMembers = 3, counts = { TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 0 } },
    [5] = { numMembers = 4, counts = { TANK_REMAINING = 1, HEALER_REMAINING = 0, DAMAGER_REMAINING = 0 } },
}
local entries = { Entry(1), Entry(2), Entry(3), Entry(4), Entry(5), Region() }
local blizzardRefreshes = 0
local finder = Frame()
finder.results, finder.totalResults, finder.searching, finder.searchFailed = results, #results, false, false
finder.CategoryDropdown, finder.NoResultsFound = Frame(), Region()
finder.ScrollBox = { EnumerateFrames = function() return ipairs(entries) end }
finder.UpdateResultList = function() blizzardRefreshes = blizzardRefreshes + 1 end
finder.UpdateResults = function() blizzardRefreshes = blizzardRefreshes + 1 end

local settings = { enabled = true }
local setHooks, applyHooks, rowHooks, resultHooks = {}, {}, {}, {}
local S = { Get = function(k) return settings[k] end }
function S.Set(k, v)
    settings[k] = v
    for _, fn in ipairs(setHooks) do fn(k, v) end
end
local card
local tips = {}
local ns = { GamepadStandDown = function() return false end,
    QoLSettings = S,
    Apply = NOTHING,
    THEME = { muted = {} },
    L = function(key, ...) if select("#", ...) > 0 then return key:format(...) end return key end,
    Font = function() return Region() end,
    Tooltip = function(frame, title, body) tips[#tips + 1] = { frame = frame, title = title, body = body } end,
    Shared = {
        Parts = { Press = NOTHING },
        Style = { SMALL_SIZE = 11, TEXT_SIZE = 12 },
        Settings = { Page = function() return { Card = function(_, c) card = c end } end },
    },
}
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    C_ChatInfo = { InChatMessagingLockdown = function() return lockdown end },
    C_LFGList = {
        GetSearchResultInfo = function(id)
            infoReads = infoReads + 1
            return listings[id]
        end,
        GetSearchResultPlayerInfo = function(id) return { lfgRoles = listings[id].roles } end,
        GetSearchResultMemberCounts = function(id) return listings[id].counts end,
    },
    hooksecurefunc = function(t, name, fn)
        if t == S then setHooks[#setHooks + 1] = fn
        elseif t == ns then applyHooks[#applyHooks + 1] = fn
        elseif t == "LFGBrowseSearchEntry_Update" then rowHooks[#rowHooks + 1] = name
        elseif t == finder and name == "UpdateResults" then resultHooks[#resultHooks + 1] = fn
        else error("unexpected hook " .. tostring(name)) end
    end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/FinderRoles.lua"))
local first = #frames
setfenv(chunk, env)
chunk()
local events, boot = frames[first + 1], frames[first + 2]

local function Snapshot()
    local copy = {}
    for i, v in ipairs(results) do copy[i] = v end
    return copy
end
local before = Snapshot()

local function UntouchedList()
    assert(finder.results == results and #results == #before, "the result table is Blizzard's")
    for i, v in ipairs(before) do assert(results[i] == v, "result " .. i .. " rewritten") end
    assert(finder.totalResults == #before, "totals are Blizzard's")
    assert(blizzardRefreshes == 0, "Blizzard's refresh is never called")
end

local function RowUpdate(entry)
    for _, fn in ipairs(rowHooks) do fn(entry) end
end

local function Results()
    for _, fn in ipairs(resultHooks) do fn(finder) end
end

local function Faded(i) return entries[i].alpha == 0 and entries[i].mouse == false end
local function Kept(i) return entries[i].alpha ~= 0 and entries[i].mouse ~= false end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("the card is on Questing & Group, one short sentence", function()
    assert(card and card.switch == "finderRoles")
    assert(#card.help < 100 and not card.help:find("%. "), "help is one sentence under 100 characters")
end)

Case("off by default: nothing built, hooked or listened to", function()
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    assert(next(events.events) == nil)
    assert(#rowHooks == 0 and #resultHooks == 0)
end)

Case("on before the Group Finder loads: waits for it", function()
    S.Set("finderRoles", true)
    assert(events.events.ADDON_LOADED and #rowHooks == 0)
end)

Case("the Group Finder loads: hooks its rows and results, buttons get the house tooltip", function()
    env.LFGBrowseFrame = finder
    events.scripts.OnEvent(events, "ADDON_LOADED")
    assert(not events.events.ADDON_LOADED)
    assert(#rowHooks == 1 and #resultHooks == 1)
    assert(#tips == 6 and tips[1].title == "Tank" and tips[1].body == "Show players who signed up as Tank.")
    UntouchedList()
end)

Case("nothing picked: rows are left as the game drew them", function()
    infoReads = 0
    for _, e in ipairs(entries) do if e.resultID then RowUpdate(e) end end
    for i = 1, 5 do assert(entries[i].alphaSets == 0) end
    assert(infoReads == 0, "no search result read while nothing is picked")
end)

Case("Players: Healer fades the rest, keeps your own listing, never touches the list", function()
    S.Set("finderRolesHealer", true)
    assert(Kept(1) and Kept(2), "own listing and the healer stay")
    assert(Faded(3) and Faded(4) and Faded(5), "damage and groups fade")
    UntouchedList()
end)

Case("a faded row the list reuses for a match comes back", function()
    entries[3].resultID = 2
    RowUpdate(entries[3])
    assert(Kept(3))
    entries[3].resultID = 3
    RowUpdate(entries[3])
    assert(Faded(3))
end)

Case("Groups need: Healer keeps the group with a healer spot", function()
    S.Set("finderNeedHealer", true)
    assert(Kept(4) and Faded(5))
    UntouchedList()
end)

local hint
Case("every listing faded: the hint says the picks did it", function()
    S.Set("finderRolesHealer", false)
    S.Set("finderNeedHealer", false)
    listings[1].hasSelf = false
    listings[1].roles = { dps = true }
    S.Set("finderRolesTank", true)
    for i = 1, 5 do assert(Faded(i)) end
    for _, f in ipairs(frames) do
        if f.buttons then hint = f.hint end
    end
    assert(hint and hint.shown and hint.text == "Your Group Finder Roles picks hide every listing.")
end)

Case("a new search hides the hint until results come", function()
    finder.searching = true
    Results()
    assert(not hint.shown)
    finder.searching = false
    Results()
    assert(hint.shown)
end)

Case("chat messaging lockdown: nothing read, rows shown, no hint", function()
    lockdown, infoReads = true, 0
    for i = 1, 5 do RowUpdate(entries[i]) end
    Results()
    for i = 1, 5 do assert(Kept(i)) end
    assert(infoReads == 0, "secret search results are never read")
    assert(not hint.shown)
    lockdown = false
    for i = 1, 5 do RowUpdate(entries[i]) end
    assert(Faded(2), "filters again once lockdown ends")
end)

Case("switched off: every faded row is restored, events dropped", function()
    S.Set("finderRoles", false)
    for i = 1, 5 do assert(Kept(i)) end
    assert(next(events.events) == nil)
    for _, fn in ipairs(applyHooks) do fn() end
    UntouchedList()
end)

print(count .. " finder-roles checks passed")
