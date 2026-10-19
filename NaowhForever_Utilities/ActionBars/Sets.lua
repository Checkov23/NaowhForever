-- Sets.lua: saving, importing, renaming and deleting a bar set, /nf bars, and the module's public API (ns.ActionBarSets).
local ns = _G.NaowhForever

local A = ns.ActionBars
local S = A.Settings
local Capture = A.Capture
local Import = A.Import
local Pending = A.Pending

local Plural = A.Plural

local TEXT_OFF = ns.L("Action Bars is switched off.")
local TEXT_SAVE_IN_COMBAT = ns.L("Bar sets can be saved out of combat.")
local TEXT_IMPORT_IN_COMBAT = ns.L("Bar sets can be imported out of combat.")
local TEXT_NEW_MACRO, TEXT_NEW_MACROS = ns.L("%d new macro"), ns.L("%d new macros")
local TEXT_KEYBIND, TEXT_KEYBINDS = ns.L("%d keybind"), ns.L("%d keybinds")
local TEXT_MACRO, TEXT_MACROS = ns.L("%d macro"), ns.L("%d macros")
local TEXT_SAVED = ns.L("Saved your bars, macros and keybinds as %s.")
local TEXT_NO_SET = ns.L("No bar set called %s for your class.")
local TEXT_IMPORTED = "%s %s: %s."
local TEXT_IMPORTED_VERB, TEXT_TESTED_VERB = ns.L("Imported"), ns.L("Test import of")
local TEXT_ACTIONS = ns.L("%d of %d actions")
local TEXT_NO_ROOM = ns.L("   No room for %s: %s")
local TEXT_SLOT = ns.L("Slot %d: %s")
local TEXT_WOULD_BE_EMPTY = ns.L("   These slots would be left empty:")
local TEXT_WERE_EMPTY = ns.L("   These slots were left empty:")
local TEXT_SLOT_LINE = "      "
local TEXT_LATER = ns.L("   Spells you learn later go into their slots then.")
local TEXT_LATER_LIST = ns.L("   These go on your bars when you learn them: %s.")
local TEXT_AT_LEVEL = ns.L("%s (level %d)")
local TEXT_DELETED = ns.L("Deleted the bar set %s.")
local TEXT_TAKEN = ns.L("There is already a bar set called %s.")
local TEXT_SETS = ns.L("Bar sets: ")
local TEXT_NO_SETS = ns.L("No bar sets saved for your class.")
local TEXT_DELETE = ns.L("Delete the bar set %s?")
local TEXT_HEADLINE_NONE = ns.L("No bar sets saved for your %s yet")
local TEXT_HEADLINE_ONE = ns.L("%d bar set saved for your %s")
local TEXT_HEADLINE = ns.L("%d bar sets saved for your %s")
local TEXT_DETAIL_OFF = ns.L("Turn on Action Bars to save and import your bars.")
local TEXT_DETAIL_LAST = ns.L("This character last used %s. Import any set from the window, out of combat.")
local TEXT_DETAIL = ns.L("Save your bars from the window, or with /nf bars save and a name.")

local AUTO_IMPORT_LEVEL, AUTO_IMPORT_XP = 1, 0
local AUTO_STORE = "barSetAuto"
local LOGOUT_COPY_DELAY = 1
local LOGOUT_EVENTS = { ACTIONBAR_SLOT_CHANGED = true, UPDATE_MACROS = true, UPDATE_BINDINGS = true }

local COMMANDS = { save = true, import = true, restore = true, test = true, delete = true }

local logoutCopy, copyQueued

local function Ready(inCombat)
    if not S.Get("enabled") then ns.Print(TEXT_OFF) return false end
    if InCombatLockdown() then ns.Print(inCombat) return false end
    return true
end

local function Save(name, choices)
    if not Ready(TEXT_SAVE_IN_COMBAT) then return end
    local key = A.Find(name) or name
    local sets = A.Sets()
    sets[key] = Capture.Snapshot(choices or (sets[key] and sets[key].choices))
    A.SetLast(key, true)
    logoutCopy = nil
    ns.Print(TEXT_SAVED:format(key))
    A.Refresh()
    return key
end

local function Count(fates, fate)
    local n = 0
    for _, m in ipairs(fates) do if m.fate == fate then n = n + 1 end end
    return n
end

local function Summary(result)
    local parts = { TEXT_ACTIONS:format(result.placed, result.actions) }
    local made = Count(result.macros, "new")
    if made > 0 then parts[#parts + 1] = Plural(made, TEXT_NEW_MACRO, TEXT_NEW_MACROS) end
    if result.bound then parts[#parts + 1] = Plural(result.bound, TEXT_KEYBIND, TEXT_KEYBINDS) end
    return table.concat(parts, ", ")
end

local function PrintFull(result)
    local full = {}
    for _, m in ipairs(result.macros) do
        if m.fate == "full" then full[#full + 1] = m.name end
    end
    if #full > 0 then print(TEXT_NO_ROOM:format(Plural(#full, TEXT_MACRO, TEXT_MACROS), table.concat(full, ", "))) end
end

local function PrintEmpty(result, test, waiting)
    local failed = {}
    for _, slot in ipairs(Capture.Slots()) do
        local row = result.slots[slot]
        if (row.state == "later" and not waiting) or row.state == "gone" then
            failed[#failed + 1] = TEXT_SLOT:format(slot, Import.Describe(row.entry))
        end
    end
    if #failed == 0 then return end
    print(test and TEXT_WOULD_BE_EMPTY or TEXT_WERE_EMPTY)
    for _, line in ipairs(failed) do print(TEXT_SLOT_LINE .. line) end
end

local function PrintLater(result)
    local names = {}
    for _, later in ipairs(result.later) do
        local level = result.slots[later.slot].level
        local name = Import.Describe(later.entry)
        names[#names + 1] = level and level > 0 and TEXT_AT_LEVEL:format(name, level) or name
    end
    print(TEXT_LATER_LIST:format(table.concat(names, ", ")))
end

local function ImportSet(name, test)
    if not Ready(TEXT_IMPORT_IN_COMBAT) then return end
    local key = A.Find(name)
    if not key then ns.Print(TEXT_NO_SET:format(name)) return end
    local set = A.Sets()[key]
    local website = set.choices and set.choices.website
    local result = Import.Run(set, test)
    local pending = not test and Pending.Remember(key, result, website)
    if not test then A.SetLast(key, false) end
    ns.Print(TEXT_IMPORTED:format(test and TEXT_TESTED_VERB or TEXT_IMPORTED_VERB, key, Summary(result)))
    PrintFull(result)
    PrintEmpty(result, test, pending and pending.always)
    if pending and pending.always then PrintLater(result) elseif pending then print(TEXT_LATER) end
    A.Refresh()
    return result
end

function A.AutoImportName()
    local chosen = S.Get("autoImportSets")
    return chosen and chosen[A.Class()] or ""
end

function A.SetAutoImport(name)
    local chosen = {}
    for class, set in pairs(S.Get("autoImportSets") or {}) do chosen[class] = set end
    chosen[A.Class()] = name ~= "" and name or nil
    S.Set("autoImportSets", chosen)
end

local function Delete(key)
    A.Sets()[key] = nil
    if A.AutoImportName() == key then A.SetAutoImport("") end
    ns.Print(TEXT_DELETED:format(key))
    A.Refresh()
end

local function Rename(key, new)
    if new == key then return end
    if A.Find(new) and A.Find(new) ~= key then ns.Print(TEXT_TAKEN:format(new)) return end
    local sets = A.Sets()
    local set = sets[key]
    sets[key] = nil
    sets[new] = set
    for _, last in pairs(A.Account("barSetLast")) do
        if last.class == A.Class() and last.name == key then last.name = new end
    end
    if logoutCopy and logoutCopy.key == key then logoutCopy.key = new end
    if A.AutoImportName() == key then A.SetAutoImport(new) end
    A.Refresh()
end

local function ConfirmDelete(key)
    ns.Confirm(TEXT_DELETE:format(key), function() Delete(key) end)
end

local function SetCount()
    local n = 0
    for _ in pairs(A.Sets()) do n = n + 1 end
    return n
end

local function Headline()
    local n = SetCount()
    local class = UnitClass("player")
    if n == 0 then return TEXT_HEADLINE_NONE:format(class) end
    return (n == 1 and TEXT_HEADLINE_ONE or TEXT_HEADLINE):format(n, class)
end

local function Detail()
    if not A.On() then return TEXT_DETAIL_OFF end
    local last = A.Last()
    if last and last.class == A.Class() and A.Sets()[last.name] then return TEXT_DETAIL_LAST:format(last.name) end
    return TEXT_DETAIL
end

local function List()
    local names = A.SortedNames()
    ns.Print(#names > 0 and (TEXT_SETS .. table.concat(names, ", ")) or TEXT_NO_SETS)
end

local function DeleteNamed(name)
    local key = A.Find(name)
    if key then ConfirmDelete(key) else ns.Print(TEXT_NO_SET:format(name)) end
end

local function LogoutKey()
    if not (S.Get("enabled") and S.Get("saveOnLogout")) then return nil end
    local last = A.Last()
    local key = last and last.class == A.Class() and last.saved ~= false and last.name
    return key and A.Sets()[key] and key or nil
end

local function CopyBars()
    copyQueued = false
    local key = LogoutKey()
    logoutCopy = key and { key = key, slots = Capture.Capture() } or nil
end

local function QueueCopy()
    if copyQueued then return end
    copyQueued = true
    C_Timer.After(LOGOUT_COPY_DELAY, CopyBars)
end

local function WatchLogout()
    local on = S.Get("enabled") and S.Get("saveOnLogout")
    for event in pairs(LOGOUT_EVENTS) do
        if on then Pending.events:RegisterEvent(event) else Pending.events:UnregisterEvent(event) end
    end
    if on then QueueCopy() else logoutCopy = nil end
end

local function SaveOnLogout()
    local key = LogoutKey()
    if key and logoutCopy and logoutCopy.key == key then
        A.Sets()[key] = Capture.Snapshot(A.Sets()[key].choices, logoutCopy.slots)
    end
end

local function AutoImportDue()
    local name = A.AutoImportName()
    if name == "" or not S.Get("enabled") or UnitLevel("player") ~= AUTO_IMPORT_LEVEL
        or UnitXP("player") ~= AUTO_IMPORT_XP then
        return false
    end
    local done = ns.Shared.CharacterData(AUTO_STORE, true)
    return not done.imported and A.Find(name) ~= nil
end

local function AutoImport()
    if not A.autoWaiting then return end
    if InCombatLockdown() then
        Pending.events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    A.autoWaiting = false
    ns.Shared.CharacterData(AUTO_STORE, true).imported = true
    ImportSet(A.AutoImportName())
end

local function OnEvent(_, event)
    if event == "PLAYER_LOGIN" then
        Pending.Watch()
        WatchLogout()
        if AutoImportDue() then
            A.autoWaiting = true
            Pending.events:RegisterEvent("PLAYER_ENTERING_WORLD")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Pending.events:UnregisterEvent(event)
        AutoImport()
    elseif event == "LEARNED_SPELL_IN_SKILL_LINE" then
        Pending.events:RegisterEvent("SPELLS_CHANGED")
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_ENABLED" then AutoImport() end
        Pending.SpellsReady(event)
    elseif event == "PLAYER_LOGOUT" then
        SaveOnLogout()
    elseif LOGOUT_EVENTS[event] then
        QueueCopy()
    end
end

A.Rename, A.Delete, A.ConfirmDelete = Rename, Delete, ConfirmDelete

function ns.ActionBarsCommand(text)
    local cmd, name = strtrim(text or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "list" then
        List()
    elseif name == "" or not COMMANDS[cmd] then
        ns.OpenActionBarsWindow()
    elseif cmd == "save" then
        Save(name)
    elseif cmd == "import" or cmd == "restore" then
        ImportSet(name)
    elseif cmd == "test" then
        ImportSet(name, true)
    else
        DeleteNamed(name)
    end
end

function ns.ActionBarsImportCommand(text)
    local name = strtrim(text or "")
    if name == "" then List() else ImportSet(name) end
end

ns.ActionBarSets = {
    Headline = Headline, Detail = Detail, BARS = A.BARS, Find = A.Find,
    Get = function(key) return A.Sets()[key] end,
    SlotList = Capture.Slots, Capture = Capture.Capture, CaptureMacros = Capture.CaptureMacros,
    CaptureBindings = Capture.CaptureBindings, MacroKey = Capture.MacroKey, Describe = Import.Describe,
    Save = Save, Import = ImportSet,
    Preview = function(key) return Import.Run(A.Sets()[key], true) end,
}

Pending.events:RegisterEvent("PLAYER_LOGIN")
Pending.events:RegisterEvent("PLAYER_LOGOUT")
Pending.events:SetScript("OnEvent", OnEvent)

S.OnChange(function(key)
    if key == "enabled" or key == "fillLater" then Pending.Watch() end
    if key == "enabled" or key == "saveOnLogout" then WatchLogout() end
end)
