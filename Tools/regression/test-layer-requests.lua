-- Run with Lua 5.1 from the repository root: Layer Tracker's swaps.
-- Off nothing is made, joined or listened to. On, the layer channel is joined a little after login, never at it.
-- A click asks the channel once for another layer of your zone, refused without a layer, in a group, in chat
-- lockdown or too soon; a click again stops. No invite in a minute ends the ask; a group that does not start a
-- move within 15 seconds, or whose move is cancelled, is left (or only named, with Leave Failed Swaps off). Other
-- players' requests for your zone from another layer show one prompt at a time with an Invite button, never in
-- combat, an instance, a raid or a group you cannot invite to, and never twice in a minute for one player. Every
-- request's layer is noted; secret or malformed lines and other channels are never read. A click during the
-- delayed join waits for it; a zone change or loading screen ends an ask not yet answered; a group a friend or
-- guildmate invited you into is never left; turning requests off drops the prompt, and a queued one that shows
-- after that hides itself; the channel is left after a /reload when this character joined it.
local NOTHING = function() end
local SECRET = "inv layer <LS 1411 not 5250-99>"
local queued = false
local frames, timers, sent, printed, invited, joined, left = {}, {}, {}, {}, {}, {}, {}
local channelId = 0
local clock = 100
local state = { grouped = false, raid = false, leader = false, members = 0, combat = false, instance = false,
    locked = false, guild = false, friend = false, bnet = false, guildmates = {} }
local leaves = 0

local function Frame()
    local f = { scripts = {}, events = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = f
    return f
end

local function Timer(seconds, fn)
    local t = { seconds = seconds, fn = fn }
    function t:Cancel() self.cancelled = true end
    timers[#timers + 1] = t
    return t
end

local function Live(seconds)
    for i = #timers, 1, -1 do
        local t = timers[i]
        if t.seconds == seconds and not t.cancelled and not t.fired then return t end
    end
end

local function Run(seconds)
    local t = assert(Live(seconds), "no live timer of " .. seconds .. "s")
    t.fired = true
    t.fn()
end

local settings = { enabled = true, layerTracker = true, layerRequests = false, layerRequestsHost = true,
    layerRequestsLeave = true }
local setHooks = {}
local S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end }
local toast, toastSpec, refreshed = nil, nil, 0
local own = {}
local noted = {}
local current, currentZone, map = nil, nil, 1411
local Layers = {
    Current = function() return current, currentZone end,
    Map = function() return map end,
    Note = function(where, key, zone) noted[#noted + 1] = { where = where, key = key, zone = zone } end,
    Refresh = function() refreshed = refreshed + 1 end,
}

local function Toast(spec)
    toastSpec = spec
    toast = { shown = false, hooks = { OnShow = {}, OnHide = {} } }
    function toast:Hide()
        if not self.shown then return end
        self.shown = false
        for _, fn in ipairs(self.hooks.OnHide) do fn(self) end
    end
    function toast:Show()
        if self.shown then return end
        self.shown = true
        for _, fn in ipairs(self.hooks.OnShow) do fn(self) end
    end
    function toast:HookScript(script, fn) table.insert(self.hooks[script], fn) end
    return toast
end

local ns = {
    QoLSettings = S,
    Layers = Layers,
    THEME = { accentSoft = { r = 0, g = 0.6, b = 1 } },
    Apply = NOTHING,
    Print = function(text) printed[#printed + 1] = text end,
    L = dofile("Tools/regression/locale_stub.lua").L,
    Shared = {
        CharacterData = function(key)
            assert(key == "layerRequestsChannel")
            return own
        end,
        Parts = {
            Toast = Toast,
            FillToast = function(t, title, line) t.title, t.line = title, line end,
            ShowToast = function(t, seconds)
                if queued then
                    t.waiting = seconds
                    return
                end
                if t.on and not t.on() then return end
                t.seconds = seconds
                t:Show()
            end,
        },
    },
}

local function Secret(v) return v == SECRET end

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    MAX_PARTY_MEMBERS = 4,
    issecretvalue = Secret,
    GetTime = function() return clock end,
    GetChannelName = function(name)
        assert(name == "layer")
        return channelId
    end,
    JoinTemporaryChannel = function(name) joined[#joined + 1] = name; channelId = 6 end,
    LeaveChannelByName = function(name) left[#left + 1] = name; channelId = 0 end,
    IsInGroup = function() return state.grouped end,
    IsInRaid = function() return state.raid end,
    UnitIsGroupLeader = function() return state.leader end,
    GetNumGroupMembers = function() return state.members end,
    InCombatLockdown = function() return state.combat end,
    IsInInstance = function() return state.instance end,
    IsInGuild = function() return state.guild end,
    UnitGUID = function(unit)
        assert(unit == "player")
        return "Player-5250-00000001"
    end,
    C_Timer = { NewTimer = Timer },
    C_ChatInfo = {
        InChatMessagingLockdown = function() return state.locked end,
        SendChatMessage = function(text, kind, language, target)
            sent[#sent + 1] = { text = text, kind = kind, language = language, target = target }
        end,
    },
    C_PartyInfo = {
        InviteUnit = function(name) invited[#invited + 1] = name end,
        LeaveParty = function() leaves = leaves + 1 end,
    },
    C_FriendList = { IsFriend = function() return state.friend end },
    C_BattleNet = { GetGameAccountInfoByGUID = function() return state.bnet and {} or nil end },
    C_GuildInfo = { MemberExistsByName = function(name) return state.guildmates[name] == true end },
    hooksecurefunc = function(t, name, fn)
        if t == S and name == "Set" then setHooks[#setHooks + 1] = fn end
    end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/LayerRequests.lua"))
setfenv(chunk, env)
chunk()
local boot = frames[1]
local events

local function Set(k, v)
    settings[k] = v
    for _, fn in ipairs(setHooks) do fn(k) end
end

local function Fire(event, ...)
    events.scripts.OnEvent(events, event, ...)
end

local function Say(text, name, guid, base)
    Fire("CHAT_MSG_CHANNEL", text, name, "", "6. layer", "", "", 0, 6, base or "layer", 0, 1, guid or "Player-5250-00000099")
end

local function Last() return printed[#printed] end

local function Release()
    local seconds = toast.waiting
    toast.waiting = nil
    if seconds and not (toast.on and not toast.on()) then
        toast.seconds = seconds
        toast:Show()
    end
end

local count = 0
local function Case(name, fn)
    printed, sent, invited, noted = {}, {}, {}, {}
    fn()
    count = count + 1
    print("PASS " .. name)
end

Case("off: nothing is made, joined or listened to, and a click does nothing", function()
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    assert(#frames == 1 and #timers == 0)
    Layers.Click()
    assert(#printed == 0 and #sent == 0)
end)

Case("switched on: its events, and the channel joined only after a delay", function()
    Set("layerRequests", true)
    events = frames[2]
    assert(events.events.CHAT_MSG_CHANNEL and events.events.GROUP_JOINED and events.events.SHARD_TRANSFER_CANCELLED)
    assert(#joined == 0, "never joined at once")
    Fire("PLAYER_ENTERING_WORLD", true, false)
    assert(#timers == 1, "one join, however many times it is asked for")
    Run(10)
    assert(#joined == 1 and joined[1] == "layer" and own.joined == true, "joined, and kept for this character")
end)

Case("a click with your layer unread asks nothing", function()
    Layers.Click()
    assert(#sent == 0 and Last() == "Your layer is not read yet: target or mouse over an NPC first.", Last())
end)

Case("in a group, or with chat locked, nothing is asked", function()
    current, currentZone = "5250-18853", 18853
    state.grouped = true
    Layers.Click()
    assert(#sent == 0 and Last():find("^Leave your group first"), Last())
    state.grouped, state.locked = false, true
    Layers.Click()
    assert(#sent == 0 and Last() == "Chat is locked right now, so nothing was asked.", Last())
    state.locked = false
end)

Case("out of the channel: the click joins it and asks nothing yet", function()
    channelId = 0
    Layers.Click()
    assert(#sent == 0 and #joined == 2 and Last() == "Joining the layer channel. Click again in a moment.", Last())
end)

Case("a click asks the layer channel once, with your zone and your layer to leave", function()
    Layers.Click()
    assert(#sent == 1, #sent)
    local m = sent[1]
    assert(m.text == "inv layer <LS 1411 not 5250-18853>" and m.kind == "CHANNEL" and m.target == 6, m.text)
    assert(Layers.Asking() and Last() == "Asked the layer channel for an invite to another layer.")
    local tip = { lines = {} }
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    Layers.AddTip(tip)
    assert(tip.lines[2] == "Asking for another layer. Click: stop asking", tip.lines[2])
end)

Case("a click again stops asking", function()
    Layers.Click()
    assert(not Layers.Asking() and Last() == "Stopped asking for another layer." and #sent == 0)
    assert(Live(60) == nil, "the ask's timer is cancelled")
    local tip = { lines = {} }
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    Layers.AddTip(tip)
    assert(tip.lines[2] == "Click: ask for another layer", tip.lines[2])
end)

Case("asking again too soon is refused", function()
    clock = clock + 10
    Layers.Click()
    assert(#sent == 0 and Last():find("^You asked a moment ago"), Last())
end)

Case("no invite in a minute: the ask ends and says so", function()
    clock = clock + 30
    Layers.Click()
    assert(#sent == 1)
    Run(60)
    assert(not Layers.Asking() and Last() == "No one invited you to another layer. Click the layer line to ask again.")
end)

Case("a group that does not start a move in 15 seconds is left", function()
    clock = clock + 31
    Layers.Click()
    state.grouped = true
    Fire("GROUP_JOINED", 1, "Party-1")
    assert(Live(60) == nil, "the ask's minute stops once grouped")
    Run(15)
    assert(leaves == 1 and Last() == "Joining that group did not move you, so you left it.", Last())
    assert(not Layers.Asking())
    state.grouped = false
end)

Case("a move that starts and finishes keeps the group, and says why", function()
    clock = clock + 31
    Layers.Click()
    state.grouped = true
    Fire("GROUP_JOINED", 1, "Party-1")
    Fire("SHARD_TRANSFER_IMMINENT")
    assert(Live(15) == nil, "a coming move stops the check")
    Fire("SHARD_TRANSFER")
    assert(leaves == 1 and not Layers.Asking())
    assert(Last() == "You keep this layer while you stay in the group.", Last())
    state.grouped = false
end)

Case("a cancelled move leaves the group", function()
    clock = clock + 31
    Layers.Click()
    state.grouped = true
    Fire("GROUP_JOINED", 1, "Party-1")
    Fire("SHARD_TRANSFER_IMMINENT")
    Fire("SHARD_TRANSFER_CANCELLED")
    assert(leaves == 2 and Last():find("so you left it"), Last())
    state.grouped = false
end)

Case("Leave Failed Swaps off: a failed swap is only named", function()
    Set("layerRequestsLeave", false)
    clock = clock + 31
    Layers.Click()
    state.grouped = true
    Fire("GROUP_JOINED", 1, "Party-1")
    Run(15)
    assert(leaves == 2 and Last() == "Joining that group did not move you to another layer.", Last())
    Set("layerRequestsLeave", true)
    state.grouped = false
end)

Case("leaving the group while asking ends the ask", function()
    clock = clock + 31
    Layers.Click()
    Fire("GROUP_JOINED", 1, "Party-1")
    Fire("GROUP_LEFT", 1, "Party-1")
    assert(not Layers.Asking() and Live(15) == nil)
end)

Case("a joined group while not asking is left alone", function()
    Fire("GROUP_JOINED", 1, "Party-1")
    assert(Live(15) == nil)
end)

Case("a request from another layer of your zone asks you, and Invite invites them", function()
    Say("inv layer <LS 1411 not 5250-16>", "Thrall Doomhammer")
    assert(#noted == 1 and noted[1].where == 1411 and noted[1].key == "5250-16" and noted[1].zone == 16)
    assert(toast.shown and toast.line == "Thrall Doomhammer wants to join your layer.", toast.line)
    assert(toast.title == "Layer Swap" and toast.seconds == 30)
    toastSpec.buttons[1].click(toast)
    assert(#invited == 1 and invited[1] == "Thrall Doomhammer" and not toast.shown)
end)

Case("Not Now invites no one", function()
    Say("inv layer <LS 1411 not 5250-17>", "Jaina Proudmoore")
    assert(toast.shown)
    toastSpec.buttons[2].click(toast)
    assert(#invited == 0 and not toast.shown)
end)

Case("one prompt at a time, and one player is not asked about twice in a minute", function()
    Say("inv layer <LS 1411 not 5250-17>", "Jaina Proudmoore")
    assert(not toast.shown, "asked about a moment ago")
    Say("inv layer <LS 1411 not 5250-18>", "Rexxar Earthfury")
    assert(toast.shown and toast.line:find("^Rexxar"))
    Say("inv layer <LS 1411 not 5250-19>", "Vol'jin Shadowhunter")
    assert(toast.line:find("^Rexxar"), "the shown prompt stays")
    toast:Hide()
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-17>", "Jaina Proudmoore")
    assert(toast.shown and toast.line:find("^Jaina"))
    toast:Hide()
end)

Case("friends and guildmates are named as such", function()
    clock = clock + 61
    state.friend = true
    Say("inv layer <LS 1411 not 5250-20>", "Baine Bloodhoof")
    assert(toast.line == "Your friend Baine Bloodhoof wants to join your layer.", toast.line)
    toast:Hide()
    state.friend, state.guild, state.guildmates["Cairne Bloodhoof"] = false, true, true
    Say("inv layer <LS 1411 not 5250-21>", "Cairne Bloodhoof")
    assert(toast.line == "Cairne Bloodhoof from your guild wants to join your layer.", toast.line)
    toast:Hide()
    state.guild = false
end)

Case("requests you cannot host are noted but not asked about", function()
    local function Nothing(why, text, name, guid, base)
        clock = clock + 61
        Say(text, name, guid, base)
        assert(not toast.shown, why)
    end
    Nothing("your own request", "inv layer <LS 1411 not 5250-18853>", "Me Myself", "Player-5250-00000001")
    Nothing("another zone", "inv layer <LS 1412 not 5250-16>", "A One")
    Nothing("your own layer", "inv layer <LS 1411 not 5250-18853>", "A Two")
    state.combat = true
    Nothing("in combat", "inv layer <LS 1411 not 5250-16>", "A Three")
    state.combat, state.instance = false, true
    Nothing("in an instance", "inv layer <LS 1411 not 5250-16>", "A Four")
    state.instance, state.raid, state.grouped = false, true, true
    Nothing("in a raid", "inv layer <LS 1411 not 5250-16>", "A Five")
    state.raid = false
    Nothing("in a group you do not lead", "inv layer <LS 1411 not 5250-16>", "A Six")
    state.leader, state.members = true, 5
    Nothing("in a full party", "inv layer <LS 1411 not 5250-16>", "A Seven")
    state.members = 3
    Say("inv layer <LS 1411 not 5250-16>", "A Eight")
    assert(toast.shown, "leading a party with room hosts")
    toast:Hide()
    state.grouped, state.leader, state.members = false, false, 0
    assert(#noted == 9, #noted)
end)

Case("while you ask, no one else's request asks you", function()
    clock = clock + 61
    Layers.Click()
    Say("inv layer <LS 1411 not 5250-16>", "B One")
    assert(not toast.shown)
    Layers.Click()
end)

Case("other channels, other lines and secret payloads are never read", function()
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "C One", nil, "Trade")
    Say("inv layer pls", "C Two")
    Say("anyone selling inv layer <LS 1411 not 5250-16>", "C Three")
    Say(SECRET, "C Four")
    Say("inv layer <LS 1411 not 5250-16>", SECRET)
    Say("inv layer <LS 1411 not 5250-16>", "C Five", SECRET)
    Say("inv layer <LS 1411 not 5250-16>", "C Six", nil, SECRET)
    assert(not toast.shown and #noted == 0, #noted)
end)

Case("a Layer channel spelled with a capital is the same channel", function()
    Say("inv layer <LS 1411 not 5250-16>", "D One", nil, "Layer")
    assert(toast.shown)
    toast:Hide()
end)

Case("Show Requests From Others off: requests are noted, nobody is asked about", function()
    Set("layerRequestsHost", false)
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "E One")
    assert(not toast.shown and #noted == 1)
    Set("layerRequestsHost", true)
end)

Case("a prompt waiting its turn is dropped when swaps go off", function()
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "F One")
    assert(toast.shown)
    Set("layerRequests", false)
    assert(not toast.shown and next(events.events) == nil)
    assert(#left == 1 and left[1] == "layer", "the channel it joined is left")
    Set("layerRequests", true)
    Run(10)
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "F Two")
    assert(toast.shown, "a new prompt can show")
    toast:Hide()
end)

Case("a prompt still queued behind another toast is forgotten when swaps go off", function()
    queued = true
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "G One")
    assert(not toast.shown)
    Set("layerRequests", false)
    queued = false
    Set("layerRequests", true)
    Run(10)
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "G Two")
    assert(toast.shown and toast.line:find("^G Two"), "the queued one does not block new prompts")
    toast:Hide()
end)

Case("a channel you were already in is not left", function()
    Set("layerRequests", false)
    local before = #left
    channelId = 7
    Set("layerRequests", true)
    assert(Live(10) == nil, "already in it: nothing to join")
    Set("layerRequests", false)
    assert(#left == before, "a channel it did not join stays")
end)

Case("a click while the channel is still being joined waits for the join", function()
    Set("layerRequests", false)
    channelId = 0
    Set("layerRequests", true)
    local before = #joined
    clock = clock + 61
    Layers.Click()
    assert(#joined == before and #sent == 0 and Last() == "Joining the layer channel. Click again in a moment.", Last())
    Run(10)
    assert(#joined == before + 1, "the delayed join still happens")
    Layers.Click()
    assert(#sent == 1 and Layers.Asking())
    Layers.Click()
end)

Case("a zone change or loading screen ends an ask not yet answered", function()
    clock = clock + 31
    Layers.Click()
    Fire("ZONE_CHANGED_NEW_AREA")
    assert(not Layers.Asking() and Last() == "Stopped asking for another layer.", Last())
    clock = clock + 31
    Layers.Click()
    Fire("PLAYER_ENTERING_WORLD", false, false)
    assert(not Layers.Asking())
end)

Case("once grouped, a zone change or loading screen does not end the swap", function()
    clock = clock + 31
    Layers.Click()
    state.grouped = true
    Fire("GROUP_JOINED", 1, "Party-1")
    Fire("ZONE_CHANGED_NEW_AREA")
    Fire("PLAYER_ENTERING_WORLD", false, false)
    assert(Layers.Asking() and Live(15), "still waiting for the move")
    Fire("SHARD_TRANSFER")
    assert(Last() == "You keep this layer while you stay in the group.", Last())
    state.grouped = false
end)

Case("a group a friend or guildmate invited you into is never left", function()
    local before = leaves
    clock = clock + 31
    Layers.Click()
    state.friend = true
    Fire("PARTY_INVITE_REQUEST", "Baine Bloodhoof", false, false, false, true, false, "Player-5250-00000042", false)
    state.friend = false
    state.grouped = true
    Fire("GROUP_JOINED", 1, "Party-1")
    Run(15)
    assert(leaves == before and Last() == "Joining that group did not move you to another layer.", Last())
    state.grouped = false
    clock = clock + 31
    Layers.Click()
    state.guild, state.guildmates["Cairne Bloodhoof"] = true, true
    Fire("PARTY_INVITE_REQUEST", "Cairne Bloodhoof", false, false, false, true, false, "Player-5250-00000043", false)
    state.guild = false
    state.grouped = true
    Fire("GROUP_JOINED", 1, "Party-1")
    Run(15)
    assert(leaves == before, "a guildmate's group stays too")
    state.grouped = false
end)

Case("a stranger's invite, or a secret one, is still left when it does not move you", function()
    local before = leaves
    clock = clock + 31
    Layers.Click()
    state.friend = true
    Fire("PARTY_INVITE_REQUEST", SECRET, false, false, false, true, false, "Player-5250-00000044", false)
    state.friend = false
    Fire("PARTY_INVITE_REQUEST", "Garrosh Hellscream", false, false, false, true, false, "Player-5250-00000045", false)
    state.grouped = true
    Fire("GROUP_JOINED", 1, "Party-1")
    Run(15)
    assert(leaves == before + 1, "left")
    state.grouped = false
end)

Case("turning Show Requests From Others off takes a shown prompt away, Invite and all", function()
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "H One")
    assert(toast.shown)
    Set("layerRequestsHost", false)
    assert(not toast.shown, "the prompt goes")
    toastSpec.buttons[1].click(toast)
    assert(#invited == 0, "and inviting from it does nothing")
    Set("layerRequestsHost", true)
end)

Case("a queued prompt that shows after its request was dropped hides itself", function()
    queued = true
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "I One")
    assert(not toast.shown and toast.waiting)
    Set("layerRequestsHost", false)
    Set("layerRequestsHost", true)
    queued = false
    Release()
    assert(not toast.shown, "nothing to invite: it hides at once")
    clock = clock + 61
    Say("inv layer <LS 1411 not 5250-16>", "I Two")
    assert(toast.shown and toast.line:find("^I Two"), "and a new request can show")
    toast:Hide()
end)

Case("after a /reload, the channel this character joined is still left when swaps go off", function()
    Set("layerRequests", false)
    channelId, own.joined = 6, true
    Set("layerRequests", true)
    assert(Live(10) == nil, "already in it: nothing to join")
    local before = #left
    Set("layerRequests", false)
    assert(#left == before + 1 and own.joined == nil, "left, as the saved flag says this character joined it")
    Set("layerRequests", true)
    Run(10)
end)

Case("Layer Tracker off takes its swaps with it", function()
    channelId = 0
    settings.layerRequests = true
    Set("layerTracker", false)
    assert(next(events.events) == nil)
    Layers.Click()
    assert(#sent == 0 and #printed == 0)
end)

print(("passed %d cases"):format(count))
