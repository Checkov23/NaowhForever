-- Backups.lua: this character's bars, keybinds and the macros on its bars, kept before each import, the last ten, and putting one back (ns.ActionBars.Backups).
local ns = _G.NaowhForever

local A = ns.ActionBars
local Capture = A.Capture
local Import = A.Import
local Pending = A.Pending

local MAX_BACKUPS = 10
local STORE = "barSetBackups"
local CHOICES = { skip = {}, macroOff = {}, macros = false, keys = true }
local RESTORE = { actions = true, macros = true, keys = true, exact = true }

local TEXT_BEFORE_RESTORE = ns.L("Before putting back a backup")

local function Data()
    local data = ns.Shared.CharacterData(STORE, true)
    data.list = data.list or {}
    return data
end

local function List()
    return Data().list
end

local function Take(why)
    local data = Data()
    local list = data.list
    data.taken = (data.taken or 0) + 1
    table.insert(list, 1, { id = data.taken, saved = time(), why = why, set = Capture.Snapshot(CHOICES), last = A.Last() })
    for i = #list, MAX_BACKUPS + 1, -1 do list[i] = nil end
end

local function Restore(index)
    local list = List()
    local backup = list[index]
    if not backup then return nil end
    Take(TEXT_BEFORE_RESTORE)
    local result = Import.Run(backup.set, false, RESTORE)
    Pending.Forget()
    A.Account("barSetLast")[A.CharKey()] = backup.last
    return result
end

A.Backups = { List = List, Take = Take, Restore = Restore }
