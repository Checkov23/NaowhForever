-- Sharing.lua: one macro or many as a string to share, and a shared string read back as character macros (ns.Macros.Sharing).
local ns = _G.NaowhForever

local M = ns.Macros
local C = M.C
local Store = M.Store

local SHARE = "!NFM1!"
local SHARE_PATTERN = "^%s*" .. SHARE:gsub("!", "%%!") .. "(%S+)%s*$"
local VERSION = 1
local SHOWN_COMMANDS = 4
local DECODE_LIMITS = { maxChars = 100000, maxBytes = 1048576, maxDepth = 8, maxValues = 20000 }

local TEXT_NOT_A_STRING = ns.L("That is not a Naowh Forever macro string.")
local TEXT_ADD_ONE = ns.L("Add %d macro as character macros?%s")
local TEXT_ADD = ns.L("Add %d macros as character macros?%s")
local TEXT_IN_COMBAT = ns.L("Macros can be added once the fight is over.")
local TEXT_ADDED = ns.L("Added %d.")
local TEXT_ADDED_SOME = ns.L("Added %d of %d: %s.")
local TEXT_TAKEN_ONE, TEXT_TAKEN = ns.L("%d uses a name you already have"), ns.L("%d use a name you already have")
local TEXT_FULL = ns.L("character macros are full")
local TEXT_SCRIPT_ONE, TEXT_SCRIPT = ns.L("runs a script"), ns.L("run a script")
local TEXT_WARNING_ONE = ns.L(" One %s: read it in /macro before you use it.")
local TEXT_WARNING = ns.L(" Some %s: read them in /macro before you use them.")
local TEXT_AND = ns.L(" and ")
local TEXT_PROMPT = ns.L("Paste a Naowh Forever macro string")

local COMMAND_KINDS = {
    { kind = "own", one = ns.L("uses Naowh Forever's own commands (%s)"),
      many = ns.L("use Naowh Forever's own commands (%s)") },
    { kind = "addon", one = ns.L("uses other addons' commands (%s)"), many = ns.L("use other addons' commands (%s)") },
    { kind = "unknown", one = ns.L("uses commands the game does not know (%s)"),
      many = ns.L("use commands the game does not know (%s)") },
}

local foundCommands = { own = {}, addon = {}, unknown = {} }

local function Codec()
    return LibStub("LibSerialize"), LibStub("LibDeflate")
end

local function Export(macros)
    local LS, LD = Codec()
    local out = {}
    for i, m in ipairs(macros) do out[i] = { name = m.name, body = m.body } end
    return SHARE .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize({ v = VERSION, macros = out })))
end

local function ReadMacro(m)
    if type(m) ~= "table" or type(m.name) ~= "string" or type(m.body) ~= "string" then return end
    local name = m.name:gsub("[|\r\n]", "")
    if #name < 1 or #name > C.NAME_MAX or #m.body > C.LIMIT then return end
    return { name = name, body = m.body }
end

local function Decode(text)
    local body = type(text) == "string" and text:match(SHARE_PATTERN)
    local data = body and ns.Shared.Decode.String(body, DECODE_LIMITS)
    if not (type(data) == "table" and data.v == VERSION and type(data.macros) == "table") then return end
    local out = {}
    local maxAccount, maxCharacter = Store.Limits()
    for i, m in ipairs(data.macros) do
        if i > maxAccount + maxCharacter then return end
        out[i] = ReadMacro(m)
        if not out[i] then return end
    end
    return #out > 0 and out or nil
end

local function Note(command)
    local kind = ns.MacroCommandKind(command)
    if kind ~= "script" and kind then
        local list = foundCommands[kind]
        command = command:lower()
        if not list[command] and #list < SHOWN_COMMANDS then
            list[command] = true
            list[#list + 1] = command
        end
    end
    return kind
end

local function Flagged(m)
    local hit, script = false, false
    for line in m.body:gmatch("[^\n]+") do
        local command = line:match("^%s*(/[^%s%[]+)")
        local kind = command and Note(command)
        if kind == "script" then script = true end
        if kind then hit = true end
    end
    return hit, script
end

local function Joined(pieces)
    if #pieces == 1 then return pieces[1] end
    return table.concat(pieces, ", ", 1, #pieces - 1) .. TEXT_AND .. pieces[#pieces]
end

local function CommandWarning(macros)
    for _, list in pairs(foundCommands) do wipe(list) end
    local flagged, script = 0, false
    for _, m in ipairs(macros) do
        local hit, runs = Flagged(m)
        if runs then script = true end
        if hit then flagged = flagged + 1 end
    end
    if flagged == 0 then return "" end
    local one = flagged == 1
    local pieces = {}
    if script then pieces[1] = one and TEXT_SCRIPT_ONE or TEXT_SCRIPT end
    for _, k in ipairs(COMMAND_KINDS) do
        local list = foundCommands[k.kind]
        if #list > 0 then pieces[#pieces + 1] = (one and k.one or k.many):format(table.concat(list, ", ")) end
    end
    return (one and TEXT_WARNING_ONE or TEXT_WARNING):format(Joined(pieces))
end

local function AddAll(macros)
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT) return end
    local added, taken, full = 0, 0, 0
    for _, m in ipairs(macros) do
        if GetMacroIndexByName(m.name) > 0 then
            taken = taken + 1
        elseif Store.Room(false) then
            CreateMacro(m.name, C.QUESTION, m.body, true)
            added = added + 1
        else
            full = full + 1
        end
    end
    local why = {}
    if taken > 0 then why[#why + 1] = (taken == 1 and TEXT_TAKEN_ONE or TEXT_TAKEN):format(taken) end
    if full > 0 then why[#why + 1] = TEXT_FULL end
    ns.Print(added == #macros and TEXT_ADDED:format(added)
        or TEXT_ADDED_SOME:format(added, #macros, table.concat(why, ", ")))
    M.Redraw()
end

function ns.ImportMacroString(text)
    local macros = Decode(text)
    if not macros then ns.Print(TEXT_NOT_A_STRING) return end
    ns.Confirm((#macros == 1 and TEXT_ADD_ONE or TEXT_ADD):format(#macros, CommandWarning(macros)),
        function() AddAll(macros) end)
end

local function Prompt()
    ns.PromptText(TEXT_PROMPT, "", 0, ns.ImportMacroString)
end

M.Sharing = { Export = Export, Prompt = Prompt }
