-- UnitNames.lua: the Names Over Heads card, the guild and title lines shown with player names, kept in the game's own settings.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Settings = ns.Shared.Settings

local ON, OFF = "1", "0"
local SUMMARY = ns.L("%d of %d shown")
local NAMES = {
    { cvar = "UnitNamePlayerPVPTitle", label = "Player Titles", help = "Titles like Private or Scout with player names." },
    { cvar = "UnitNamePlayerGuild", label = "Guild Names", help = "The guild name under a player's name." },
    { cvar = "UnitNameGuildTitle", label = "Guild Titles", help = "The player's guild rank beside their guild name." },
}

local rows = {}

local function Exists(name)
    return C_CVar.GetCVar(name.cvar) ~= nil
end

local function Row(name)
    return { label = name.label, toggle = true, help = name.help,
        get = function() return C_CVar.GetCVarBool(name.cvar) end,
        set = function(on) C_CVar.SetCVar(name.cvar, on and ON or OFF) end }
end

local function Rows()
    wipe(rows)
    for _, name in ipairs(NAMES) do
        if Exists(name) then
            name.row = name.row or Row(name)
            rows[#rows + 1] = name.row
        end
    end
    return rows
end

local function Summary()
    local shown, total = 0, 0
    for _, name in ipairs(NAMES) do
        if Exists(name) then
            total = total + 1
            if C_CVar.GetCVarBool(name.cvar) then shown = shown + 1 end
        end
    end
    return SUMMARY:format(shown, total)
end

Settings.Page("QoL/Interface", S):Card({
    id = "unitNames", name = "Names Over Heads", order = 25,
    help = "Which guild and title lines show with players' names, saved by the game itself.",
    summary = Summary,
    rows = Rows,
})
