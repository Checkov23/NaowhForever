-- Source.lua: reads the game's damage meter data.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local C = DM.C

local EMPTY = { combatSources = {}, maxAmount = 0, totalAmount = 0 }

function DM.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

function DM.Plain(value, kind)
    return type(value) == kind and not DM.IsSecret(value)
end

local IsSecret, Plain = DM.IsSecret, DM.Plain

function DM.Mode(key)
    return C.MODE_BY_KEY[key] or C.MODE_BY_KEY[C.DEFAULT_MODE]
end

function DM.ModeLabel(mode)
    if mode.short and DM.Settings.Get("shortNames") == true then return mode.short end
    return mode.label
end

function DM.Available()
    if not (C_DamageMeter ~= nil and Enum.DamageMeterType ~= nil and Enum.DamageMeterSessionType ~= nil) then
        return false
    end
    if not C_DamageMeter.IsDamageMeterAvailable then return true end
    return C_DamageMeter.IsDamageMeterAvailable()
end

local function SessionType(key)
    return key == "overall" and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
end

local function ListType(modeKey)
    return Enum.DamageMeterType[DM.Mode(modeKey).type]
end

local function FetchSession(kind, sessionKey, fightID)
    local ok, session
    if fightID ~= nil then
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, fightID, kind)
    else
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, SessionType(sessionKey), kind)
    end
    if ok and type(session) == "table" and type(session.combatSources) == "table" then return session end
end

local function FetchSource(kind, sessionKey, fightID, guid, creatureID)
    local ok, data
    if fightID ~= nil then
        ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromID, fightID, kind, guid, creatureID)
    else
        ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromType, SessionType(sessionKey), kind, guid, creatureID)
    end
    if ok and type(data) == "table" and type(data.combatSpells) == "table" then return data end
end

function DM.Session(modeKey, sessionKey, fightID)
    if not DM.Available() then return EMPTY end
    return FetchSession(ListType(modeKey), sessionKey, fightID) or EMPTY
end

local function Newest(a, b)
    return a.id > b.id
end

function DM.Fights()
    local fights = {}
    if not (DM.Available() and C_DamageMeter.GetAvailableCombatSessions) then return fights end
    local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not (ok and type(sessions) == "table") then return fights end
    for _, entry in ipairs(sessions) do
        if type(entry) == "table" and Plain(entry.sessionID, "number") then
            local name, seconds = entry.name, entry.durationSeconds
            fights[#fights + 1] = { id = entry.sessionID,
                name = Plain(name, "string") and name ~= "" and name or nil,
                seconds = Plain(seconds, "number") and seconds or nil }
        end
    end
    table.sort(fights, Newest)
    for i = #fights, DM.Settings.Get("fightsShown") + 1, -1 do fights[i] = nil end
    return fights
end

function DM.FightLabel(fight)
    local label = fight.name or ("Fight " .. fight.id)
    if fight.seconds then
        label = ("%s (%d:%02d)"):format(label, math.floor(fight.seconds / 60), math.floor(fight.seconds % 60))
    end
    return label
end

function DM.SessionName(sessionKey, fightID)
    if fightID == nil then return C.SESSION_LABELS[sessionKey] or C.SESSION_LABELS.current end
    for _, fight in ipairs(DM.Fights()) do
        if fight.id == fightID then return DM.FightLabel(fight) end
    end
    return "Fight " .. fightID
end

function DM.Duration(sessionKey, fightID)
    if not DM.Available() then return nil end
    if fightID ~= nil then
        for _, fight in ipairs(DM.Fights()) do
            if fight.id == fightID then return fight.seconds end
        end
        return nil
    end
    local ok, seconds = pcall(C_DamageMeter.GetSessionDurationSeconds, SessionType(sessionKey))
    if ok and Plain(seconds, "number") then return seconds end
    return nil
end

function DM.FightName(sessionKey, fightID)
    if fightID == nil and sessionKey == "overall" then return C.SESSION_LABELS.overall end
    if fightID == nil and InCombatLockdown() then return nil end
    for _, fight in ipairs(DM.Fights()) do
        if fightID == nil or fight.id == fightID then return fight.name end
    end
    return nil
end

function DM.Rank(session)
    local sources = session.combatSources
    for i = 1, #sources do
        if sources[i].isLocalPlayer == true then return i, #sources end
    end
    return nil, #sources
end

function DM.SourceSpells(modeKey, sessionKey, fightID, source)
    if not DM.Available() or DM.Mode(modeKey).spells == false then return nil end
    local guid
    if source.isLocalPlayer == true then guid = UnitGUID("player") else guid = source.sourceGUID end
    if IsSecret(guid) or guid == nil then return nil end
    local data = FetchSource(ListType(modeKey), sessionKey, fightID, guid)
    if data and #data.combatSpells > 0 then return data end
    return nil
end

local targetsCache = {}

function DM.ClearTargets()
    for key in pairs(targetsCache) do targetsCache[key] = nil end
end

local function Share(kind, sessionKey, fightID, enemy, name)
    local guid = enemy.sourceGUID
    if IsSecret(guid) then return 0 end
    local data = FetchSource(kind, sessionKey, fightID, guid, enemy.sourceCreatureID)
    if not data then return 0 end
    local total = 0
    for _, spell in ipairs(data.combatSpells) do
        local details = spell.combatSpellDetails
        local who = type(details) == "table" and details.unitName
        if Plain(who, "string") and who == name and Plain(spell.totalAmount, "number") then
            total = total + spell.totalAmount
        end
    end
    return total
end

local function Biggest(a, b)
    return a.total > b.total
end

function DM.Targets(sessionKey, fightID, name)
    if not DM.Available() or not Plain(name, "string") or name == "" then return nil end
    local kind = Enum.DamageMeterType.EnemyDamageTaken
    if kind == nil then return nil end
    local key = tostring(fightID or sessionKey) .. "|" .. name
    local cached = targetsCache[key]
    if cached ~= nil then return cached or nil end
    local list = {}
    local session = FetchSession(kind, sessionKey, fightID)
    for _, enemy in ipairs(session and session.combatSources or {}) do
        local total = Share(kind, sessionKey, fightID, enemy, name)
        if total > 0 then list[#list + 1] = { name = enemy.name, total = total } end
    end
    table.sort(list, Biggest)
    if #list == 0 then list = nil end
    targetsCache[key] = list or false
    return list
end

function DM.Reset()
    if DM.Available() then C_DamageMeter.ResetAllCombatSessions() end
end
