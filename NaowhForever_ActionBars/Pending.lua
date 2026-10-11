-- Pending.lua: the spells an import could not place yet, put into their saved slots as they are learned (ns.ActionBars.Pending).
local ns = _G.NaowhForever

local A = ns.ActionBars
local S = A.Settings
local Capture = A.Capture
local Import = A.Import

local TEXT_PLACED = ns.L("%s is on your bars where %s keeps it.")

local events = CreateFrame("Frame")

local function Store()
    return A.Account("barSetPending")
end

local function Pending()
    local pending = Store()[A.CharKey()]
    if pending and pending.class == A.Class() then return pending end
end

local function Watch()
    if S.Get("enabled") and S.Get("fillLater") and Pending() then
        events:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
        return
    end
    events:UnregisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
    events:UnregisterEvent("SPELLS_CHANGED")
    if not A.autoWaiting then events:UnregisterEvent("PLAYER_REGEN_ENABLED") end
end

local function Remember(key, result)
    local pending
    if S.Get("fillLater") and #result.later > 0 then
        pending = { class = A.Class(), set = key, slots = {} }
        for _, later in ipairs(result.later) do pending.slots[later.slot] = later.entry end
    end
    Store()[A.CharKey()] = pending
    Watch()
    return pending
end

local function ClearCopies(set, skip, pending, spell)
    for _, slot in ipairs(Capture.Slots()) do
        if slot ~= spell.slot and not set.slots[slot] and not skip[slot] and not pending.slots[slot] then
            local kind, id = GetActionInfo(slot)
            if kind == "spell" and id == spell.id then
                PickupAction(slot)
                ClearCursor()
            end
        end
    end
end

local function PlaceLearned(pending)
    local best, placed = Import.HighestRanks(), {}
    for slot, entry in pairs(pending.slots) do
        if GetActionInfo(slot) then
            pending.slots[slot] = nil
        elseif Import.PickUp(entry, best) then
            PlaceAction(slot)
            pending.slots[slot] = nil
            local _, id = GetActionInfo(slot)
            placed[#placed + 1] = { slot = slot, id = id, name = Import.Describe(entry) }
        end
        ClearCursor()
    end
    return placed
end

local function FillPending()
    local pending = Pending()
    if not pending then return end
    local set = A.Sets()[pending.set]
    local skip = set and set.choices and set.choices.skip or {}
    for _, spell in ipairs(PlaceLearned(pending)) do
        if set then ClearCopies(set, skip, pending, spell) end
        ns.Print(TEXT_PLACED:format(spell.name, pending.set))
    end
    if next(pending.slots) == nil then Store()[A.CharKey()] = nil end
    Watch()
end

local function SpellsReady(event)
    events:UnregisterEvent(event)
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        FillPending()
    end
end

A.Pending = { events = events, Watch = Watch, Remember = Remember, SpellsReady = SpellsReady }
