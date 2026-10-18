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
    if C_Secrets.ShouldAurasBeSecret() then return nil end
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

local function ByUrgency(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.left < b.left
end

local function Survey(members, fixed)
    local s = { missing = 0, reachable = false, missingNear = 0, expiringNear = 0, classDue = 0,
        classMissing = 0, queue = {} }
    local rank, left
    local queue = s.queue
    local players = Store().players
    local spells = {}
    for _, member in ipairs(members) do
        local key = fixed and fixed.key or Assigned(member)
        if key and spells[key] == nil then spells[key] = fixed and fixed.spell or CastSpell(key, members) or false end
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
                    if fixed or not players[member.guid] then
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
    for i = #queue, math.max(due, 1) + 1, -1 do queue[i] = nil end
    s.rank, s.left = rank, left
    return s
end

local function SalvationGroup(roster)
    local members, tankClass = {}, {}
    for _, member in ipairs(roster) do
        local role = UnitGroupRolesAssigned(member.unit)
        if not Secret(role) and role == "TANK" then
            tankClass[member.class] = true
        else
            members[#members + 1] = member
        end
    end
    return members, tankClass
end

local function SalvationSurvey(members, tankClass)
    local entry = B.SALVATION
    local single = HighestKnown(entry.ranks)
    local symbols = C_Item.GetItemCount(SYMBOL_OF_KINGS) > 0
    local byClass = {}
    for _, member in ipairs(members) do
        byClass[member.class] = byClass[member.class] or {}
        table.insert(byClass[member.class], member)
    end
    local all = { missing = 0, reachable = false, missingNear = 0, expiringNear = 0, classDue = 0,
        classMissing = 0, queue = {} }
    for _, class in ipairs(B.CLASSES) do
        local list = byClass[class]
        if list then
            local greater = not tankClass[class] and #list > 1 and symbols and HighestKnown(entry.greater)
            local s = Survey(list, { key = entry.key, spell = greater or single })
            if greater and s.missingNear + s.expiringNear < 2 then
                s = Survey(list, { key = entry.key, spell = single })
            end
            all.missing = all.missing + s.missing
            all.reachable = all.reachable or s.reachable
            all.missingNear = all.missingNear + s.missingNear
            all.expiringNear = all.expiringNear + s.expiringNear
            all.classDue = all.classDue + s.classDue
            all.classMissing = all.classMissing + s.classMissing
            if s.shortest and (not all.shortest or s.shortest < all.shortest) then all.shortest = s.shortest end
            for _, queued in ipairs(s.queue) do table.insert(all.queue, queued) end
            if s.target and (not all.target or s.rank < all.rank or (s.rank == all.rank and s.left < all.left)) then
                all.target, all.spell, all.rank, all.left = s.target, s.spell, s.rank, s.left
            end
        end
    end
    table.sort(all.queue, ByUrgency)
    local due = 0
    for _, queued in ipairs(all.queue) do if queued.rank < 2 then due = due + 1 end end
    for i = #all.queue, math.max(due, 1) + 1, -1 do all.queue[i] = nil end
    return all
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
B.SalvationGroup = SalvationGroup
B.SalvationSurvey = SalvationSurvey
B.Due = Due
