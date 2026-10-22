-- TransportShare.lua: ride timings sent to your group and guild as you time a ship, and theirs kept.
local ns = _G.NaowhForever

local GetServerTime = GetServerTime
local S = ns.QoLSettings
local Times = ns.TransportTimes
local Routes = ns.TransportRoutes

local PREFIX = "NaowhShips"
local ASK = "Q"
local TIMING_FORMAT = "T %s %.3f %.3f %s"
local TIMING_PATTERN = "^T (Player%-%d+%-%x+) (%d+%.?%d*) (%d+%.?%d*) (.+)$"
local ANSWER_SPREAD = 30
local TENTHS = 10
local GUILD_ANSWER_GAP = 30
local GUILD = "GUILD"
local PLAYER = "player"
local CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true, GUILD = true }
local EVENTS = { "CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE" }

local events, own
local inGroup, guildAsked = false, false
local lastGuildAnswer
local pending, answers = {}, {}

local function On()
    return S.Get("enabled") == true and S.Get("transportTimers") == true and S.Get("transportShare") == true
end

local function GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Message(name)
    local at, period = Times.Latest(name)
    if at and own then return TIMING_FORMAT:format(own, at, period or 0, name) end
end

local function SendTo(name, channel)
    local message = Message(name)
    if message then C_ChatInfo.SendAddonMessage(PREFIX, message, channel) end
end

local function SendAll(name)
    local group = GroupChannel()
    if group then SendTo(name, group) end
    if IsInGuild() then SendTo(name, GUILD) end
end

local function Timed(name)
    if On() then SendAll(name) end
end

local function Answer(channel)
    local fn = answers[channel]
    if not fn then
        fn = function()
            local names = pending[channel]
            pending[channel] = nil
            if not names or not On() then return end
            for name in pairs(names) do SendTo(name, channel) end
        end
        answers[channel] = fn
    end
    return fn
end

local function AnswerSoon(channel)
    if pending[channel] then return end
    if channel == GUILD then
        if lastGuildAnswer and GetTime() - lastGuildAnswer < GUILD_ANSWER_GAP then return end
        lastGuildAnswer = GetTime()
    end
    local names
    for name in pairs(Routes) do
        if Times.Latest(name) then
            names = names or {}
            names[name] = true
        end
    end
    if not names then return end
    pending[channel] = names
    C_Timer.After(math.random(1, ANSWER_SPREAD) / TENTHS, Answer(channel))
end

local function Identify()
    own = own or UnitGUID(PLAYER)
end

local function Joined()
    local group = GroupChannel()
    if group and not inGroup then
        C_ChatInfo.SendAddonMessage(PREFIX, ASK, group)
        for name in pairs(Routes) do SendTo(name, group) end
    end
    inGroup = group ~= nil
    if not guildAsked and IsInGuild() then
        guildAsked = true
        C_ChatInfo.SendAddonMessage(PREFIX, ASK, GUILD)
    end
end

local function Heard(name, at)
    for _, names in pairs(pending) do
        local ours = Times.Latest(name)
        if names[name] and (not ours or ours <= at) then names[name] = nil end
    end
end

local function Received(message, channel, sender)
    if message == ASK then return AnswerSoon(channel) end
    local guid, at, period, name = message:match(TIMING_PATTERN)
    at, period = tonumber(at), tonumber(period)
    if not guid or not own or guid == own or not at or not Routes[name] then return end
    if not ns.SenderIs(sender, channel, guid) then return end
    Times.Shared(name, at, period ~= 0 and period or nil, GetServerTime())
    Heard(name, at)
end

local function OnMessage(prefix, message, channel, sender)
    if issecretvalue(prefix) or issecretvalue(message) or issecretvalue(channel) or issecretvalue(sender) then return end
    if prefix ~= PREFIX or not CHANNELS[channel] then return end
    Received(message, channel, sender)
end

local function OnEvent(_, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then return OnMessage(prefix, message, channel, sender) end
    Identify()
    Joined()
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
        Identify()
        Times.OnTimed = Timed
        if IsLoggedIn() then Joined() end
    else
        if events then events:UnregisterAllEvents() end
        Times.OnTimed = nil
        wipe(pending)
        inGroup, guildAsked = false, false
    end
end

local function OnSetting(key)
    if key == "enabled" or key == "transportTimers" or key == "transportShare" then Apply() end
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
Apply()
