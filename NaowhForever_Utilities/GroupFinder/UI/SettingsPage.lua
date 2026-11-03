-- SettingsPage.lua: the Group Finder's settings page (Group Finder/Settings): what your card shares.
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local S = GF.Settings
local Settings = ns.Shared.Settings

local OFF = ns.L("Turn on the Group Finder")
local TEXT_BASICS = ns.L("Class, level and roles only")
local TEXT_SHARES = ns.L("Shares %d of %d")
local SHARED = { "shareScore", "shareKills", "shareQuests", "shareBis" }

local function On()
    return GF.On()
end

local function Summary(store)
    local count = 0
    for _, key in ipairs(SHARED) do
        if store.Get(key) then count = count + 1 end
    end
    if count == 0 then return TEXT_BASICS end
    return TEXT_SHARES:format(count, #SHARED)
end

local page = Settings.Page(GF.PAGE, S)

page:Window({
    text = "Open Group Finder",
    open = function() ns.OpenGroupFinder() end,
    headline = "Forever's groups, with their leaders' cards",
    detail = "Search, and see the Naowh Score of every leader who runs Naowh Forever.",
})

page:Card({
    id = "card", name = "Your Card", order = 10,
    help = "What Naowh Forever players see about you when you list or apply.",
    summary = Summary,
    rows = {
        { key = "shareScore", label = "Naowh Score", toggle = true, needs = On, why = OFF,
          help = "Shows your Naowh Score on your card." },
        { key = "shareKills", label = "Boss Kills", toggle = true, needs = On, why = OFF,
          help = "Shows how often you have killed each boss of the dungeon." },
        { key = "shareQuests", label = "Dungeon Quests", toggle = true, needs = On, why = OFF,
          help = "Shows the dungeon's quests you have or still need." },
        { key = "shareBis", label = "BiS Progress", toggle = true, needs = On, why = OFF,
          help = "Shows how many of your BiS items you already have." },
    },
})
