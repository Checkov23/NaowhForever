-- Run with Lua 5.1 from the repository root: Announce Quest Progress.
-- Off it listens to nothing; on, the game's own quest objective messages are said in party chat, or
-- instance chat in an instance group, word for word. Other info messages, "Objective Complete.", a
-- raid, no group and locked chat say nothing.
local NOTHING = function() end
local frames = {}
local grouped, raid, instance, locked = false, false, false, false
local sent = {}

local TYPES = {
    "ERR_QUEST_ADD_KILL_SII", "ERR_QUEST_ADD_ITEM_SII", "ERR_QUEST_ADD_FOUND_SII",
    "ERR_QUEST_ADD_PLAYER_KILL_SII", "ERR_QUEST_OBJECTIVE_COMPLETE_S", "ERR_QUEST_UNKNOWN_COMPLETE",
    "ERR_ZONE_EXPLORED",
}
local KILL, ITEM, FOUND, PLAYERS, DONE, UNKNOWN, EXPLORED = 1, 2, 3, 4, 5, 6, 7

local function Frame()
    local f = { scripts = {}, events = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = f
    return f
end

local settings = { enabled = true }
local setHooks, applyHooks = {}, {}
local S = { Get = function(k) return settings[k] end }
local card
local ns = {
    QoLSettings = S,
    Apply = NOTHING,
    L = dofile("Tools/regression/locale_stub.lua").L,
    Shared = {
        Parts = {},
        Settings = { Page = function() return { Card = function(_, c) card = c end } end },
    },
}
local INSTANCE = 2
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    LE_PARTY_CATEGORY_INSTANCE = INSTANCE,
    IsInGroup = function(category)
        if category == INSTANCE then return instance end
        return grouped
    end,
    IsInRaid = function() return raid end,
    GetGameMessageInfo = function(i) return TYPES[i] end,
    C_ChatInfo = {
        InChatMessagingLockdown = function() return locked end,
        SendChatMessage = function(text, channel) sent[#sent + 1] = { text = text, channel = channel } end,
    },
    hooksecurefunc = function(t, name, fn)
        if t == S then setHooks[#setHooks + 1] = fn elseif name == "Apply" then applyHooks[#applyHooks + 1] = fn end
    end,
}, { __index = _G })
env._G = env
for _, path in ipairs({ "Shared/UI/Share.lua", "NaowhForever_QoL/Questing/QuestProgress.lua" }) do
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end
local events, boot = frames[1], frames[2]

local function Set(k, v)
    settings[k] = v
    for _, fn in ipairs(setHooks) do fn(k) end
end

local function Say(messageType, message)
    events.scripts.OnEvent(events, "UI_INFO_MESSAGE", messageType, message)
end

local count = 0
local function Case(name, fn) sent = {}; fn(); count = count + 1; print("PASS " .. name) end

Case("the card is on Questing & Group, behind its own switch", function()
    assert(card and card.switch == "questProgress")
end)

Case("off by default: no events", function()
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    assert(next(events.events) == nil)
end)

Case("switched on: listens for info messages", function()
    Set("questProgress", true)
    assert(events.events.UI_INFO_MESSAGE)
end)

Case("not in a group: nothing said", function()
    Say(KILL, "Mottled Boar slain: 10/10")
    assert(#sent == 0)
end)

Case("in a party: the game's line, word for word, in party chat", function()
    grouped = true
    Say(KILL, "Mottled Boar slain: 10/10")
    assert(#sent == 1 and sent[1].text == "Mottled Boar slain: 10/10" and sent[1].channel == "PARTY")
end)

Case("items, finds, player kills and finished objectives are said too", function()
    local lines = {
        { ITEM, "Scorpid Worker Tail: 3/10" }, { FOUND, "Tainted Note: 1/1" },
        { PLAYERS, "Players slain: 2/5" }, { DONE, "Scout the Gold Mine (Complete)" },
    }
    for _, line in ipairs(lines) do Say(line[1], line[2]) end
    assert(#sent == #lines)
    for i, line in ipairs(lines) do
        assert(sent[i].text == line[2] and sent[i].channel == "PARTY", line[2])
    end
end)

Case("other info messages and an unnamed Objective Complete: nothing said", function()
    Say(UNKNOWN, "Objective Complete.")
    Say(EXPLORED, "Discovered: Valley of Trials")
    assert(#sent == 0)
end)

Case("an instance group: instance chat", function()
    instance = true
    Say(KILL, "Kolkar Drudge slain: 4/12")
    assert(#sent == 1 and sent[1].channel == "INSTANCE_CHAT")
    instance = false
end)

Case("a raid: nothing said", function()
    raid = true
    Say(KILL, "Mottled Boar slain: 10/10")
    assert(#sent == 0)
    raid = false
end)

Case("chat locked: nothing said", function()
    locked = true
    Say(KILL, "Mottled Boar slain: 10/10")
    assert(#sent == 0)
    locked = false
end)

Case("switched off: events dropped", function()
    Set("questProgress", false)
    assert(next(events.events) == nil)
    for _, fn in ipairs(applyHooks) do fn() end
    assert(next(events.events) == nil)
end)

Case("the whole QoL off: events dropped", function()
    Set("questProgress", true)
    Set("enabled", false)
    assert(next(events.events) == nil)
end)

print(count .. " quest-progress checks passed")
