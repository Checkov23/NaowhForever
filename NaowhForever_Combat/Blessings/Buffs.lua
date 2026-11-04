-- Buffs.lua: who has which blessing and for how long, who is in range, and who a class button blesses next.
local ns = _G.NaowhForever

local B = ns.Blessings
local Secret, Store, Assigned, HighestKnown = B.Secret, B.Store, B.Assigned, B.HighestKnown
local BY_KEY, FAMILY, GREATER = B.BY_KEY, B.FAMILY, B.GREATER
local SYMBOL_OF_KINGS = B.SYMBOL_OF_KINGS

local EXPIRING = 300
local MAX_AURAS = 40

local function CastSpell(key, members)
    local entry = BY_KEY[key]
    local greater = C_Item.GetItemCount(SYMBOL_OF_KINGS) > 0 and HighestKnown(entry.greater)
    if greater then
        for _, member in ipairs(members) do
            if Assigned(member) ~= key then greater = nil break end
        end
    end
    return greater or HighestKnown(entry.ranks)
end

local memoAt
local memo, scratch = {}, {}

local function BeginAuraMemo()
    memoAt = GetTime()
    for _, seen in pairs(memo) do seen.stale = true end
end

local function EndAuraMemo()
    memoAt = nil
end

local function Found(v)
    if v == true then return true end
    return true, v - GetTime()
end

local function BuffState(unit, key)
    if C_Secrets.ShouldAurasBeSecret() then
        if B.HiddenAuras() then return B.Remembered(unit, key) end
        return nil
    end
    local seen
    if memoAt and memoAt == GetTime() then
        seen = memo[unit]
        if not seen then seen = {}; memo[unit] = seen end
        if seen.stale then wipe(seen) end
    else
        wipe(scratch)
        seen = scratch
    end
    local v = seen[key]
    if v then return Found(v) end
    if seen.ended == "none" then return false end
    if seen.ended then return nil end
    for i = seen.next or 1, MAX_AURAS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then seen.ended = "none" return false end
        local id = aura.spellId
        if Secret(id) then seen.ended = "secret" return nil end
        local family = FAMILY[id]
        if family and seen[family] == nil then
            local expires = aura.expirationTime
            seen[family] = (Secret(expires) or not expires or expires == 0) and true or expires
        end
        if family and family == key then
            seen.next = i + 1
            return Found(seen[family])
        end
    end
    seen.ended = "none"
    return false
end

local function InRange(member, spell)
    if member.guid == UnitGUID("player") then return true end
    local inRange = C_Spell.IsSpellInRange(spell, member.unit)
    if Secret(inRange) then return nil end
    return inRange
end

local function WaitedFor(members, spell)
    if not B.Settings.Get("blessWait") then return true end
    for _, member in ipairs(members) do
        if UnitIsConnected(member.unit) and not UnitIsDeadOrGhost(member.unit) and InRange(member, spell) == false then
            return false
        end
    end
    return true
end

local function ByUrgency(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.left < b.left
end

local function Survey(members)
    local s = { missing = 0, reachable = false, missingNear = 0, expiringNear = 0, classDue = 0,
        classMissing = 0, queue = {} }
    local rank, left
    local queue = s.queue
    local players = Store().players
    local spells = {}
    for _, member in ipairs(members) do
        local key = Assigned(member)
        if key and spells[key] == nil then
            local cast = CastSpell(key, members)
            if cast and GREATER[cast] and not WaitedFor(members, cast) then cast = HighestKnown(BY_KEY[key].ranks) end
            spells[key] = cast or false
        end
        local spell = key and spells[key]
        if spell and UnitIsConnected(member.unit) and not UnitIsDeadOrGhost(member.unit) then
            local has, remaining = BuffState(member.unit, key)
            if has == false then
                s.missing = s.missing + 1
                s.shortest = 0
            elseif remaining and (not s.shortest or remaining < s.shortest) then
                s.shortest = remaining
            end
            local range = UnitIsVisible(member.unit) and InRange(member, spell)
            if has ~= nil and range ~= false then
                s.reachable = true
                local r = not has and 0 or (remaining and remaining < EXPIRING and 1 or 2)
                if range == true and r < 2 and member.targetable then
                    if r == 0 then s.missingNear = s.missingNear + 1 else s.expiringNear = s.expiringNear + 1 end
                    if not players[member.guid] then
                        s.classDue = s.classDue + 1
                        if r == 0 then s.classMissing = s.classMissing + 1 end
                    end
                end
                local l = remaining or math.huge
                if member.targetable then
                    queue[#queue + 1] = { names = member.names, spell = spell, rank = r, left = l }
                    if not s.target or r < rank or (r == rank and l < left) then
                        s.target, s.spell, rank, left = member, spell, r, l
                    end
                end
            end
        end
    end
    table.sort(queue, ByUrgency)
    local due = 0
    for _, entry in ipairs(queue) do if entry.rank < 2 then due = due + 1 end end
    if GREATER[queue[1] and queue[1].spell] then due = math.min(due, 1) end
    local keep = B.Settings.Get("blessRespect") and 0 or 1
    for i = #queue, math.max(due, keep) + 1, -1 do queue[i] = nil end
    if due == 0 and keep == 0 then s.target = nil end
    s.rank, s.left = rank, left
    return s
end

local function Due(member, key, spell)
    if not (spell and UnitIsConnected(member.unit) and not UnitIsDeadOrGhost(member.unit)
        and UnitIsVisible(member.unit) and InRange(member, spell) ~= false) then return end
    local has, remaining = BuffState(member.unit, key)
    if has == false then return 0, 0 end
    if has and remaining and remaining < EXPIRING then return 1, remaining end
end

B.CastSpell = CastSpell
B.BeginAuraMemo, B.EndAuraMemo = BeginAuraMemo, EndAuraMemo
B.BuffState = BuffState
B.ByUrgency = ByUrgency
B.Survey = Survey
B.WaitedFor = WaitedFor
B.Due = Due
