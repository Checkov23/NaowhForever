-- Import.lua: one pass over the bars putting a saved set back, or testing it, slot by slot (ns.ActionBars.Import).
local ns = _G.NaowhForever

local A = ns.ActionBars
local S = A.Settings
local C = A.C
local Capture = A.Capture

local MacroKey, Body, Lookup = Capture.MacroKey, Capture.Body, Capture.Lookup
local QUESTION = C.QUESTION
local SHOWTOOLTIP = "^#showtooltip"

local RESTORABLE = { spell = true, macro = true, item = true, equipmentset = true }

local function Describe(entry)
    if entry.kind == "spell" then return entry.name or (ns.L("spell ") .. entry.id) end
    if entry.kind == "macro" then return ns.L("macro ") .. entry.name end
    if entry.kind == "item" then return C_Item.GetItemNameByID(entry.id) or (ns.L("item ") .. entry.id) end
    return ("%s %s"):format(entry.kind, tostring(entry.id))
end

local function MacroRoom(perCharacter, plan)
    local account, character = GetNumMacros()
    account, character = account + plan.account, character + plan.character
    local max = Constants.MacroConsts
    if perCharacter then return character < max.MAX_CHARACTER_MACROS end
    return account < max.MAX_ACCOUNT_MACROS
end

local function SetMacros(set)
    if set.macros then return set.macros end
    local list, seen = {}, {}
    for _, entry in pairs(set.slots) do
        if entry.kind == "macro" and not seen[MacroKey(entry.name, entry.body)] then
            seen[MacroKey(entry.name, entry.body)] = true
            list[#list + 1] = entry
        end
    end
    return list
end

local function ImportMacros(set, test)
    local index, plan, fresh, fates = Capture.MacroIndex(), { account = 0, character = 0 }, {}, {}
    local made = false
    for _, macro in ipairs(SetMacros(set)) do
        local fate = Lookup(index, macro) and "have"
        if not fate and not index.managed[macro.name] then
            fate = "full"
            if MacroRoom(macro.perCharacter, plan) then
                if test then
                    local kind = macro.perCharacter and "character" or "account"
                    plan[kind] = plan[kind] + 1
                else
                    local icon = Body(macro.body):find(SHOWTOOLTIP) and QUESTION or macro.icon
                    CreateMacro(macro.name, icon or QUESTION, macro.body or "", macro.perCharacter)
                end
                index.text[MacroKey(macro.name, macro.body)] = true
                fresh[MacroKey(macro.name, macro.body)] = true
                fate, made = "new", true
            end
        end
        if fate then fates[#fates + 1] = { name = macro.name, fate = fate, perCharacter = macro.perCharacter } end
    end
    if made and not test then index = Capture.MacroIndex() end
    return index, fresh, fates
end

local function Unbind(...)
    for i = 1, select("#", ...) do SetBinding((select(i, ...))) end
end

local function ImportBindings(set, test)
    local count, cleared = 0, {}
    if not test and set.choices and set.choices.website then
        for _, command in pairs(set.bindings) do
            if not cleared[command] then
                cleared[command] = true
                Unbind(GetBindingKey(command))
            end
        end
    end
    for key, command in pairs(set.bindings) do
        if test or SetBinding(key, command, C_KeyBindings.GetBindingContextForAction(command)) then
            count = count + 1
        end
    end
    if not test then SaveBindings(GetCurrentBindingSet()) end
    return count
end

local function PickUpSpell(entry, ranks)
    if entry.top or S.Get("highestRank") then
        local top = Capture.Highest(entry, ranks)
        if top then C_Spell.PickupSpell(top) end
    end
    if not GetCursorInfo() then C_Spell.PickupSpell(entry.id) end
    if GetCursorInfo() or Capture.Variant(entry.id, ranks) then return end
    local name = Capture.SpellName(entry)
    local known = name and ranks.best[name]
    if known then C_Spell.PickupSpell(known) end
end

local function PickUp(entry, ranks, index, test)
    ClearCursor()
    if entry.kind == "spell" then
        PickUpSpell(entry, ranks)
    elseif entry.kind == "macro" then
        local found = Lookup(index, entry)
        if test then return found ~= nil end
        if found then PickupMacro(found) end
    elseif entry.kind == "item" then
        C_Item.PickupItem(entry.id)
    elseif entry.kind == "equipmentset" then
        local setID = type(entry.id) == "number" and entry.id or C_EquipmentSet.GetEquipmentSetID(entry.id)
        if setID then C_EquipmentSet.PickupEquipmentSet(setID) end
    end
    return GetCursorInfo() ~= nil
end

local function Missed(result, slot, entry, test)
    local row = { entry = entry, state = entry.kind == "spell" and "later" or "gone" }
    if entry.kind == "spell" then
        row.level = C_Spell.GetSpellLevelLearned(entry.id)
        result.later[#result.later + 1] = { slot = slot, entry = entry }
    end
    if not test and GetActionInfo(slot) then PickupAction(slot) end
    return row
end

local function Restore(result, slot, entry, test, ranks, index, fresh)
    result.actions = result.actions + 1
    if not PickUp(entry, ranks, index, test) then return Missed(result, slot, entry, test) end
    result.placed = result.placed + 1
    local new = entry.kind == "macro" and fresh[MacroKey(entry.name, entry.body)]
    if not test then PlaceAction(slot) end
    return { entry = entry, state = new and "new" or "ok" }
end

local function Run(set, test)
    local skip = set.choices and set.choices.skip or {}
    local result = { slots = {}, actions = 0, placed = 0, later = {}, macros = {} }
    local index, fresh = Capture.MacroIndex(), {}
    if S.Get("importMacros") then index, fresh, result.macros = ImportMacros(set, test) end
    local ranks = Capture.Ranks()
    for _, slot in ipairs(Capture.Slots()) do
        local entry = set.slots[slot]
        local row
        if skip[slot] or (entry and not RESTORABLE[entry.kind]) then
            row = { entry = entry, state = "skip" }
        elseif not entry then
            row = { state = "clear" }
            if not test and GetActionInfo(slot) then PickupAction(slot) end
        else
            row = Restore(result, slot, entry, test, ranks, index, fresh)
        end
        ClearCursor()
        result.slots[slot] = row
    end
    if set.bindings and S.Get("importBindings") then result.bound = ImportBindings(set, test) end
    return result
end

A.Import = { Describe = Describe, HighestRanks = Capture.Ranks, PickUp = PickUp, Run = Run }
