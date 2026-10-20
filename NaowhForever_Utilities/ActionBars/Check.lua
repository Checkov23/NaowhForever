-- Check.lua: what the bars could do better: spells below the best rank this character knows, and class spells it knows that are on no bar (ns.ActionBars.Check).
local ns = _G.NaowhForever

local A = ns.ActionBars
local C = A.C
local Capture = A.Capture

local KEEP_STORE, HIDE_STORE = "barSetRankKeep", "barSetSpellsHidden"

local TEXT_IN_COMBAT = ns.L("Your bars can be changed out of combat.")
local TEXT_UPGRADED = ns.L("Upgraded %d spells on your bars to your best rank.")
local TEXT_UPGRADED_ONE = ns.L("Upgraded 1 spell on your bars to your best rank.")

local function Upgrades()
    local ranks, kept, list = Capture.Ranks(), ns.Shared.CharacterData(KEEP_STORE, true), {}
    for slot = 1, C.KEYBOARD_SLOTS do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and not kept[id] then
            local best = Capture.Highest({ id = id }, ranks)
            if best and best ~= id then list[#list + 1] = { slot = slot, id = id, best = best } end
        end
    end
    return list
end

local function Upgrade(list)
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT) return end
    local done = 0
    for _, row in ipairs(list) do
        ClearCursor()
        C_Spell.PickupSpell(row.best)
        if GetCursorInfo() then
            PlaceAction(row.slot)
            done = done + 1
        end
        ClearCursor()
    end
    ns.Print(done == 1 and TEXT_UPGRADED_ONE or TEXT_UPGRADED:format(done))
    A.Refresh()
end

local function Keep(list)
    local kept = ns.Shared.CharacterData(KEEP_STORE, true)
    for _, row in ipairs(list) do kept[row.id] = true end
    A.Refresh()
end

local function OnBars()
    local names, bodies = {}, {}
    for slot = 1, C.KEYBOARD_SLOTS do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" then
            names[C_Spell.GetSpellName(id) or ""] = true
        elseif kind == "macro" then
            local _, _, body = GetMacroInfo(GetMacroIndexByName(C_ActionBar.GetActionText(slot) or ""))
            if body then bodies[#bodies + 1] = body end
        end
    end
    return names, table.concat(bodies, "\n")
end

local function ByName(a, b) return a.name < b.name end

local function Missing()
    local catalog = A.Sharing.Catalog()
    if not catalog then return nil end
    local names, macros = OnBars()
    local hidden, list = ns.Shared.CharacterData(HIDE_STORE, true), {}
    for name, id in pairs(Capture.Ranks().best) do
        if catalog[id] and not names[name] and not hidden[name] and not macros:find(name, 1, true) then
            list[#list + 1] = { id = id, name = name }
        end
    end
    table.sort(list, ByName)
    return list
end

local function Hide(list)
    local hidden = ns.Shared.CharacterData(HIDE_STORE, true)
    for _, row in ipairs(list) do hidden[row.name] = true end
    A.Refresh()
end

A.Check = { Upgrades = Upgrades, Upgrade = Upgrade, Keep = Keep, Missing = Missing, Hide = Hide }
