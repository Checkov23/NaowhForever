-- Run with Lua 5.1 from the repository root: the town map's mailboxes. Every one is a pin the
-- town map can draw (its row shape, the "mail" category, both factions, a spot on the map),
-- the capitals have theirs, and the setting starts off.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/TownMailboxes.lua")))
setfenv(chunk, { _G = { NaowhForever = ns } })
chunk()

local total = 0
for map, list in pairs(ns.TownMailboxes) do
    Check(type(map) == "number" and #list > 0, "a map with mailboxes: " .. tostring(map))
    for _, box in ipairs(list) do
        Check(box[1] >= 0 and box[1] <= 100 and box[2] >= 0 and box[2] <= 100, "on the map: " .. map)
        Check(box[3] == "mail" and box[4] == "Mailbox" and box[7] == "AH", "a mailbox pin row: " .. map)
        total = total + 1
    end
end
Check(total >= 90, "every mailbox found (" .. total .. ")")
for _, capital in ipairs({ 1453, 1454, 1455, 1456, 1457, 1458 }) do
    Check(ns.TownMailboxes[capital] ~= nil, "the capital has mailboxes: " .. capital)
end

local map = Read("NaowhForever_QoL/Interface/TownMap.lua")
Check(map:find('mail       = { "townMail",', 1, true), "the town map knows the mail category")
Check(map:find("ns.TownMailboxes[mapID]", 1, true), "and draws the mailboxes")
Check(map:find('if S.Get("townMail") then', 1, true), "everywhere: Town Pins Only in Capitals is for vendors and trainers")
Check(Read("Core/Settings.lua"):find("townMail = true", 1, true), "Mailboxes start on")

print(("test-town-mailboxes: %d checks passed"):format(checks))
