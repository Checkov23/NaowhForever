-- Profile.lua: a class macro from the profile pack made on this character and picked up for a bar (ns.PickupProfileMacro).
local ns = _G.NaowhForever

local M = ns.Macros
local S = M.Settings
local C = M.C
local Smart = M.Smart
local Commands = M.Commands

local TEXT_BAD = ns.L("A profile macro needs a name (1-16 characters) and body (1-255 characters).")
local TEXT_TAKEN = ns.L("A different macro already uses that name; rename it before adding the profile macro.")
local TEXT_MAY_FAIL = ns.L("%s may not work: %s")
local TEXT_SCRIPT = ns.L("%s runs a script from a shared profile. Hover its icon to read it first. Create it?")

local function Fits(entry)
    return type(entry.name) == "string" and #entry.name >= 1 and #entry.name <= C.NAME_MAX
        and type(entry.body) == "string" and #entry.body >= 1 and #entry.body <= C.LIMIT
end

local function Place(entry)
    if InCombatLockdown() then return end
    Smart.Write({ name = entry.name, icon = ns.MacroEntryIcon(entry) }, entry.body, true)
    local placed = GetMacroIndexByName(entry.name)
    if placed > 0 then PickupMacro(placed) end
    local problems = Commands.Problems(entry.body)
    if #problems > 0 then ns.Print(TEXT_MAY_FAIL:format(entry.name, table.concat(problems, " "))) end
end

function ns.PickupProfileMacro(entry)
    if InCombatLockdown() or not Smart.Ready() or not S.Get("enabled") then return end
    if not Fits(entry) then
        ns.Print(TEXT_BAD)
        return
    end
    local index = GetMacroIndexByName(entry.name)
    if index > 0 and GetMacroBody(index) ~= entry.body then
        ns.Print(TEXT_TAKEN)
        return
    end
    if index == 0 and Commands.RunsScript(entry.body) then
        ns.Confirm(TEXT_SCRIPT:format(entry.name), function() Place(entry) end)
        return
    end
    Place(entry)
end
