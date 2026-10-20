-- Run with Lua 5.1 from the repository root: Export to Website. A set or the bars as they are become
-- a code the website reads; read back through the addon's own import it gives the same slots, macros
-- and keybinds, with no Highest flag gained or lost. What the website cannot show is left out and
-- named, never failing the export.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local SPELLS = { [6673] = "Battle Shout", [100] = "Charge", [772] = "Rend", [12294] = "Mortal Strike",
    [20572] = "Blood Fury", [2580] = "Find Minerals" }
local sets, live = {}, nil
local ns = {
    L = function(s) return s end,
    Shared = {},
    Print = function() end,
    Confirm = function() end,
    OpenActionBarsImport = function() end,
    TrainingData = { [1] = { { 1, 6673, 10 }, { 4, 100, 100 }, { 4, 772, 100 } } },
    TrainingBuilds = { [1] = { talents = { [105000] = { 12294, 1, 7, 1, 2 } } } },
    ActionBars = {
        C = { KEYBOARD_SLOTS = 180, SLOTS_PER_BAR = 12, QUESTION = 134400 },
        Capture = { Slots = function() return { 1, 2, 3 } end,
            MacroKey = function(name, body) return name .. "\n" .. body end,
            Snapshot = function() return live end },
        Class = function() return "WARRIOR" end,
        On = function() return true end,
        Sets = function() return sets end,
        Find = function(key) return sets[key] and key end,
        Refresh = function() end,
        Plural = function(n, one, many) return (n == 1 and one or many):format(n) end,
    },
}
local env = setmetatable({ _G = { NaowhForever = ns }, InCombatLockdown = function() return false end,
    time = function() return 123 end, UnitName = function() return "Alt" end,
    C_Spell = { GetSpellName = function(id) return SPELLS[id] end } }, { __index = _G })
for _, file in ipairs({ "Shared/Decode.lua", "Shared/Encode.lua", "NaowhForever_Utilities/ActionBars/Data/Bars.lua",
    "NaowhForever_Utilities/ActionBars/Sharing.lua" }) do
    local chunk = assert(loadfile(file)); setfenv(chunk, env); chunk()
end
local Sharing = ns.ActionBars.Sharing

local PULL = { kind = "macro", name = "Pull", body = "#showtooltip\r\n/cast Charge", icon = 132337, perCharacter = true }
local SHOUT = { name = "Shout", body = "/yell Charge!", icon = 132333, perCharacter = false }
sets.Raid = {
    saved = 1,
    slots = {
        [1] = { kind = "spell", id = 6673, name = "Battle Shout", top = true },
        [2] = { kind = "spell", id = 100, name = "Charge" },
        [3] = { kind = "spell", id = 20572, name = "Blood Fury" },
        [4] = { kind = "item", id = 6948 },
        [5] = PULL,
        [6] = { kind = "summonmount", id = 5 },
        [7] = { kind = "macro", name = "Pull", body = "/cast Rend", icon = 1, perCharacter = true },
        [8] = { kind = "spell", id = 12294, name = "Mortal Strike", top = true },
        [190] = { kind = "spell", id = 772, name = "Rend" },
    },
    macros = { PULL, SHOUT },
    bindings = { ["SHIFT-Q"] = "ACTIONBUTTON3", ["CTRL-1"] = "BONUSACTIONBUTTON1", X = "TOGGLEAUTORUN",
        ["shift-ctrl-e"] = "ACTIONBUTTON2", ["ALT-1"] = "ACTIONBUTTON1", ["ALT-2"] = "ACTIONBUTTON1",
        ["ALT-Q"] = "SHAPESHIFTBUTTON1" },
}

local code, report = Sharing.Export("Raid")
Check("a set exports to a website code", type(code) == "string" and code:find("^!NFA1!"))
local name, set = Sharing.Decode(code)
Check("its name comes along", name == "Raid")
local slots = set.slots
Check("a Highest spell keeps its flag", slots[1].kind == "spell" and slots[1].id == 6673 and slots[1].top == true)
Check("an exact rank gains none", slots[2].id == 100 and slots[2].top == nil)
Check("a talent spell comes along", slots[8].id == 12294 and slots[8].top == true)
Check("items come along", slots[4].kind == "item" and slots[4].id == 6948)
Check("macros come along on their slot", slots[5].kind == "macro" and slots[5].name == "Pull"
    and slots[5].body == "#showtooltip\n/cast Charge" and slots[5].icon == 132337 and slots[5].perCharacter == true)
Check("a racial, a mount, a second macro of the same name and a gamepad slot are left out",
    slots[3] == nil and slots[6] == nil and slots[7] == nil and slots[190] == nil)
local count = 0
for _ in pairs(slots) do count = count + 1 end
Check("and nothing else", count == 5 and report.actions == 5)
Check("the left-out actions are named", #report.left == 4 and report.left[1] == "Blood Fury" and report.left[2] == "Mount"
    and report.left[3] == "Pull" and report.left[4] == "Rend")
local summary = Sharing.ExportSummary(report)
Check("the popup says what went in", summary:find("In the code: 5 actions, 6 keybinds and 2 macros.", 1, true))
Check("and names a few of what was left out", summary:find("Left out, as the website cannot show them: 4 actions: "
    .. "Blood Fury, Mount, Pull, Rend.", 1, true))
local macros = {}
for _, m in ipairs(set.macros) do macros[m.name] = m end
Check("the macro list comes along once each", #set.macros == 2 and macros.Shout.perCharacter == false
    and macros.Shout.icon == 132333 and macros.Pull.perCharacter == true)
local b = set.bindings
Check("allowed keys come along, normalized", b["SHIFT-Q"] == "ACTIONBUTTON3" and b["CTRL-1"] == "BONUSACTIONBUTTON1"
    and b["CTRL-SHIFT-E"] == "ACTIONBUTTON2" and b.X == nil)
Check("stance and form keys come along", b["ALT-Q"] == "SHAPESHIFTBUTTON1")
local onOne = 0
for _, command in pairs(b) do if command == "ACTIONBUTTON1" then onOne = onOne + 1 end end
Check("at most two keys per action", onOne == 2 and report.keys == 6)

local again = select(2, Sharing.Decode(Sharing.Export("Raid")))
local same = true
for slot, entry in pairs(slots) do
    local other = again.slots[slot]
    same = same and other and other.kind == entry.kind and other.id == entry.id and other.top == entry.top
end
Check("a second round trip gives the same slots", same)

live = { slots = { [1] = { kind = "spell", id = 772, name = "Rend", top = true }, [2] = { kind = "spell", id = 2580 } },
    macros = { SHOUT }, bindings = { ["1"] = "ACTIONBUTTON1" } }
name, set = Sharing.Decode((Sharing.Export()))
Check("the bars as they are export under the character's name", name == "Alt bars" and set.slots[1].top == true
    and set.slots[2] == nil and set.macros[1].name == "Shout" and set.bindings["1"] == "ACTIONBUTTON1")

local ACCOUNT_MACROS, CHARACTER_MACROS, EXTRA_ACCOUNT, EXTRA_CHARACTER = 120, 60, 5, 3
local MAX_BODY, MAX_CHARS, FIRST_PRINTABLE, PRINTABLE = 255, 200000, 32, 95
local SEED, MULTIPLIER, MODULUS, LOW_BITS = 12345, 16807, 2147483647, 65536
local seed = SEED
local function Body()
    local bytes = {}
    for i = 1, MAX_BODY do
        seed = seed * MULTIPLIER % MODULUS
        bytes[i] = string.char(FIRST_PRINTABLE + math.floor(seed / LOW_BITS) % PRINTABLE)
    end
    return table.concat(bytes)
end
local function Macros(accountCount, characterCount)
    local list = {}
    for i = 1, accountCount do
        list[#list + 1] = { kind = "macro", name = "A" .. i, body = Body(), icon = 132333, perCharacter = false }
    end
    for i = 1, characterCount do
        list[#list + 1] = { kind = "macro", name = "C" .. i, body = Body(), icon = 132337, perCharacter = true }
    end
    return list
end
local function Kinds(list)
    local account, character = 0, 0
    for _, m in ipairs(list) do
        if m.perCharacter then character = character + 1 else account = account + 1 end
    end
    return account, character
end
sets.Macros = { saved = 1, slots = { [4] = { kind = "item", id = 6948 } },
    macros = Macros(ACCOUNT_MACROS + EXTRA_ACCOUNT, CHARACTER_MACROS + EXTRA_CHARACTER) }
code, report = Sharing.Export("Macros")
set = select(2, Sharing.Decode(code))
local account, character = Kinds(set and set.macros or {})
Check("120 account and 60 character macros round-trip", account == ACCOUNT_MACROS and character == CHARACTER_MACROS
    and set.macros[1].body == sets.Macros.macros[1].body and set.macros[1].perCharacter == false)
Check("the first of each kind are kept", set.macros[ACCOUNT_MACROS].name == "A" .. ACCOUNT_MACROS
    and set.macros[ACCOUNT_MACROS + 1].name == "C1")
Check("the rest are left out", report.macrosLeft == EXTRA_ACCOUNT + EXTRA_CHARACTER)
summary = Sharing.ExportSummary(report)
Check("and the popup names them", summary:find("1 action, 0 keybinds and 180 macros.", 1, true)
    and summary:find("Left out: 8 macros, past the website's limit or sharing a name.", 1, true))
local full = Macros(ACCOUNT_MACROS, CHARACTER_MACROS)
local placed = {}
for i, m in ipairs(full) do placed[i] = m end
local KEYS_PER_ACTION, FUNCTION_KEYS, SLOTS_PER_BAR = 2, 24, 12
local MODIFIERS = { "", "ALT-", "CTRL-", "SHIFT-", "ALT-CTRL-", "ALT-SHIFT-", "CTRL-SHIFT-", "ALT-CTRL-SHIFT-", "META-", "ALT-META-" }
local bindings, bound, commands = {}, 0, {}
local function Bind(command)
    for _ = 1, KEYS_PER_ACTION do
        bindings[MODIFIERS[math.floor(bound / FUNCTION_KEYS) + 1] .. "F" .. (bound % FUNCTION_KEYS + 1)] = command
        bound = bound + 1
    end
end
for _, bar in ipairs(ns.ActionBars.BARS) do
    if not commands[bar.button] then
        commands[bar.button] = true
        for button = 1, SLOTS_PER_BAR do Bind(bar.button .. button) end
    end
end
for button = 1, ns.ActionBars.PET_BAR.buttons do Bind(ns.ActionBars.PET_BAR.button .. button) end
for button = 1, ns.ActionBars.STANCE_BAR.buttons do Bind(ns.ActionBars.STANCE_BAR.button .. button) end
sets.Full = { saved = 1, slots = placed, macros = full, bindings = bindings }
code, report = Sharing.Export("Full")
set = select(2, Sharing.Decode(code))
Check("180 placed macros of 255 bytes and every keybind stay within the code's size limit", #code <= MAX_CHARS
    and set and #set.macros == ACCOUNT_MACROS + CHARACTER_MACROS and report.macrosLeft == 0
    and report.actions == #full and report.keys == bound)

ns.TrainingData = nil
sets.Solo = { saved = 1, slots = { [1] = { kind = "spell", id = 100 }, [2] = { kind = "item", id = 6948 } } }
code, report = Sharing.Export("Solo")
set = select(2, Sharing.Decode(code))
Check("without the Training Planner's data spells are left out, items kept", set.slots[1] == nil
    and set.slots[2].id == 6948 and report.spells == false and report.left[1] == "Charge")
sets.Empty = { saved = 1, slots = { [1] = { kind = "summonmount", id = 5 } } }
code, report = Sharing.Export("Empty")
Check("a set the website can show nothing of still exports", type(code) == "string" and report.actions == 0)
Check("an unknown set exports nothing", Sharing.Export("Nope") == nil)

print("action bar export: " .. checks .. " checks passed")
