-- The Names Over Heads card (NaowhForever_QoL/Interface/UnitNames.lua) against a fake of the game's settings.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end
local source = Read("NaowhForever_QoL/Interface/UnitNames.lua")

local function Load(cvars)
    local card
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = {}, Shared = { Settings = {
        Page = function() return { Card = function(_, c) card = c end } end,
    } } }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_CVar = {
            GetCVar = function(name) return cvars[name] end,
            GetCVarBool = function(name) return cvars[name] == "1" end,
            SetCVar = function(name, value) cvars[name] = value end,
        },
    }, { __index = _G })
    local chunk = assert(loadstring(source, "UnitNames"))
    setfenv(chunk, env)
    chunk()
    return card
end

local count = 0
local function Case(name, fn) fn(); count = count + 1 end

Case("a setting the client lacks gets no row", function()
    local card = Load({ UnitNamePlayerGuild = "1", UnitNamePlayerPVPTitle = "0" })
    local rows = card.rows()
    assert(#rows == 2 and rows[1].label == "Player Titles" and rows[2].label == "Guild Names", #rows)
    assert(card.summary() == "1 of 2 shown", card.summary())
end)
Case("a row reads and writes the game's setting", function()
    local cvars = { UnitNamePlayerGuild = "1", UnitNameGuildTitle = "1", UnitNamePlayerPVPTitle = "1" }
    local card = Load(cvars)
    local guild = card.rows()[2]
    assert(guild.get() == true)
    guild.set(false)
    assert(cvars.UnitNamePlayerGuild == "0" and guild.get() == false)
    guild.set(true)
    assert(cvars.UnitNamePlayerGuild == "1")
    assert(card.rows()[2] == guild, "the same row each time the page draws")
end)

print("test-unit-names: " .. count .. " cases passed")
