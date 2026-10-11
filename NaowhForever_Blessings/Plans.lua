-- Plans.lua: plans shared with the group's other paladins running Naowh Forever, over addon messages.
local ns = _G.NaowhForever

local B = ns.Blessings
local CLASSES, BLESSINGS, AURAS = B.CLASSES, B.BLESSINGS, B.AURAS
local BY_KEY, BY_CODE = B.BY_KEY, B.BY_CODE
local others = B.others
local Learned, Store, Roster, InGroup, CanAssign = B.Learned, B.Store, B.Roster, B.InGroup, B.CanAssign
local MyName, IsPaladin = B.MyName, B.IsPaladin

local PREFIX = "NaowhBless"
local NONE = "-"
local PLAYER_BATCH = 200
local MAX_PLAYER_CHOICES = 40
local BATCH_DELAY = 1
local TEXT_UPDATED = ns.L(" updated your blessings.")

local pending = {}
local sentPlayers, broadcastAfterCombat, broadcastQueued, syncQueued

local function RefreshPage()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function EncodePlan(classes, aura)
    local out = {}
    for i, class in ipairs(CLASSES) do
        out[i] = classes[class] and BY_KEY[classes[class]].code or NONE
    end
    out[#out + 1] = aura and BY_KEY[aura].code or NONE
    return table.concat(out)
end

local function DecodePlan(text)
    if #text ~= #CLASSES + 1 then return end
    local classes = {}
    for i, class in ipairs(CLASSES) do
        local c = text:sub(i, i)
        if c ~= NONE then
            local entry = BY_CODE[c]
            if not (entry and entry.blessing) then return end
            classes[class] = entry.key
        end
    end
    local c = text:sub(-1)
    if c == NONE then return classes end
    local entry = BY_CODE[c]
    if entry and not entry.blessing then return classes, entry.key end
end

local function KnownCodes()
    local codes = {}
    for _, entry in ipairs(BLESSINGS) do if Learned(entry) then codes[#codes + 1] = entry.code end end
    for _, entry in ipairs(AURAS) do if Learned(entry) then codes[#codes + 1] = entry.code end end
    return table.concat(codes)
end

local function Channel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Send(msg, key)
    if InCombatLockdown() then
        pending[key or msg] = msg
        return
    end
    local channel = Channel()
    if channel then C_ChatInfo.SendAddonMessage(PREFIX, msg, channel) end
end

local function SendPlayers()
    local players = Store().players
    local parts, n, chunk = {}, 1, ""
    for _, member in ipairs(Roster()) do
        local key = players[member.guid]
        if key then
            local part = member.guid .. "=" .. BY_KEY[key].code
            if #chunk + #part > PLAYER_BATCH then
                parts[#parts + 1] = chunk
                chunk = ""
            end
            chunk = chunk == "" and part or chunk .. "," .. part
        end
    end
    parts[#parts + 1] = chunk
    if chunk == "" and #parts == 1 and not sentPlayers then return end
    sentPlayers = chunk ~= "" or #parts > 1
    for _, body in ipairs(parts) do
        Send("P|" .. n .. "|" .. body, "P|" .. n)
        n = n + 1
    end
end

local function Broadcast()
    if not IsPaladin() then return end
    if InCombatLockdown() then
        broadcastAfterCombat = true
        return
    end
    local store = Store()
    Send("F|" .. EncodePlan(store.classes, store.aura) .. "|" .. KnownCodes())
    SendPlayers()
end

local function BroadcastNow()
    broadcastQueued = false
    Broadcast()
end

local function BroadcastSoon()
    if broadcastQueued then return end
    broadcastQueued = true
    C_Timer.After(BATCH_DELAY, BroadcastNow)
end

local function OnAssigned(who, target, plan)
    local from = InGroup(who)
    local classes, aura = DecodePlan(plan)
    if not (IsPaladin() and classes and from and CanAssign(from.unit)
            and target == MyName() .. "-" .. GetNormalizedRealmName()) then
        return
    end
    local store = Store()
    store.classes = {}
    for class, key in pairs(classes) do
        if Learned(BY_KEY[key]) then store.classes[class] = key end
    end
    store.aura = aura and Learned(BY_KEY[aura]) and aura or nil
    ns.Print(who .. TEXT_UPDATED)
    BroadcastSoon()
    B.Changed()
end

local function OnPlayers(who, part, list)
    local from = others[who]
    if not from then return end
    if part == "1" then from.players, from.choices = {}, 0 end
    for guid, code in list:gmatch("(Player%-[%w%-]+)=(%a)") do
        local entry = BY_CODE[code]
        local choices = from.choices or 0
        if entry and entry.blessing and (from.players[guid] or choices < MAX_PLAYER_CHOICES) then
            if not from.players[guid] then from.choices = choices + 1 end
            from.players[guid] = entry.key
        end
    end
    RefreshPage()
end

local function OnPlan(who, body, known)
    local member = body and InGroup(who)
    if not (member and member.class == "PALADIN") then return end
    local classes, aura = DecodePlan(body)
    if not classes then return end
    local set = {}
    for code in known:gmatch(".") do
        if BY_CODE[code] then set[BY_CODE[code].key] = true end
    end
    local was = others[who]
    others[who] = { classes = classes, aura = aura, known = set, players = was and was.players or {},
        choices = was and was.choices or 0 }
    RefreshPage()
end

local function SyncNow()
    syncQueued = false
    for who in pairs(others) do
        if not InGroup(who) then others[who] = nil end
    end
    if IsPaladin() or CanAssign("player") then Send("R") end
    BroadcastSoon()
    RefreshPage()
end

B.PREFIX = PREFIX
B.EncodePlan = EncodePlan
B.Send = Send
B.BroadcastSoon = BroadcastSoon

function B.OnMessage(msg, sender)
    local who = Ambiguate(sender, "none")
    if who == MyName() then return end
    if msg == "R" then return BroadcastSoon() end
    local target, plan = msg:match("^S|([^|]+)|(%S+)$")
    if target then return OnAssigned(who, target, plan) end
    local part, list = msg:match("^P|(%d+)|(.*)$")
    if part then return OnPlayers(who, part, list) end
    local body, known = msg:match("^F|(%S+)|(%a*)$")
    OnPlan(who, body, known)
end

function B.SendPlan(who, classes, aura)
    others[who].classes, others[who].aura = classes, aura
    local full = who:find("-") and who or who .. "-" .. GetNormalizedRealmName()
    Send("S|" .. full .. "|" .. EncodePlan(classes, aura), "S|" .. full)
end

function B.SyncSoon()
    if syncQueued then return end
    syncQueued = true
    C_Timer.After(BATCH_DELAY, SyncNow)
end

function B.AfterCombat()
    if broadcastAfterCombat then
        broadcastAfterCombat = false
        BroadcastSoon()
    end
    for key, msg in pairs(pending) do
        pending[key] = nil
        Send(msg)
    end
end
