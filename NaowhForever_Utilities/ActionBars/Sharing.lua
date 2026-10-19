-- Sharing.lua: a website bar layout decoded into a new saved set, then reviewed in the existing import preview.
local ns = _G.NaowhForever

local A = ns.ActionBars
local MAX_NAME, MAX_MACRO_NAME, MAX_BODY, MAX_ID = 40, 16, 255, 10000000
local VERSION, MAX_SUFFIX, MAX_MACROS = 1, 1000, 30
local MAX_BINDINGS, MAX_KEY, MAX_KEYS_PER_ACTION = 192, 40, 2
local MAX_BASE_KEY = 31
local FIRST_MOUSE_BUTTON, LAST_MOUSE_BUTTON, LAST_FUNCTION_KEY = 3, 31, 24
local MODIFIER_ORDER = { "LALT", "RALT", "LCTRL", "RCTRL", "LSHIFT", "RSHIFT", "LMETA", "RMETA",
    "ALT", "CTRL", "SHIFT", "META" }
local MODIFIERS = {}
for _, key in ipairs(MODIFIER_ORDER) do MODIFIERS[key] = true end
local KEY_ALIASES = { MINUS = "-", EQUALS = "=" }
local IGNORED_KEYS = { UNKNOWN = true, BUTTON1 = true, BUTTON2 = true }
local PREFIX = "!NFA1!"
local LIMITS = { maxChars = 100000, maxBytes = 262144, maxDepth = 8, maxValues = 10000 }
local CLASSES = { [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
    [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID" }
local TEXT_INVALID = ns.L("That is not a valid website bar layout for your class.")
local TEXT_PROMPT = ns.L("Paste an Action Bars & Macros import code from naowh.gg")
local TEXT_COMBAT = ns.L("Bar sets can be imported out of combat.")
local TEXT_OFF = ns.L("Action Bars is switched off.")
local TEXT_CONFIRM = ns.L("Save %s as a new bar set and review it? Your bars stay unchanged until you apply the preview.")
local TEXT_FULL = ns.L("There are too many saved bar sets with that name.")

local function Integer(value, maximum)
    return type(value) == "number" and value >= 1 and value <= maximum and value % 1 == 0
end

local function Text(value, maximum)
    return type(value) == "string" and #value > 0 and #value <= maximum and not value:find("[|%c]")
end

local function Macro(row)
    if type(row) ~= "table" or not Text(row.name, MAX_MACRO_NAME) then return end
    if type(row.body) ~= "string" or #row.body < 1 or #row.body > MAX_BODY
        or row.body:find("[%z\1-\8\11-\31]") then return end
    return { kind = "macro", name = row.name, body = row.body,
        icon = Integer(row.icon, MAX_ID) and row.icon or A.C.QUESTION, perCharacter = row.perCharacter ~= false }
end

local function Entry(row)
    if type(row) ~= "table" then return end
    if row.kind == "spell" or row.kind == "item" then
        if not Integer(row.id, MAX_ID) then return end
        if row.name ~= nil and not Text(row.name, MAX_BODY) then return end
        return { kind = row.kind, id = row.id, name = row.name }
    end
    if row.kind == "macro" then return Macro(row) end
end

local function AddMacro(macros, seen, entry)
    local key = A.Capture.MacroKey(entry.name, entry.body)
    if seen[key] then return end
    seen[key] = true
    macros[#macros + 1] = entry
end

local function ListMacros(input, macros, seen)
    if input == nil then return true end
    if type(input) ~= "table" then return end
    for i in pairs(input) do
        if not Integer(i, MAX_MACROS) then return end
    end
    for i = 1, MAX_MACROS do
        if input[i] ~= nil then
            local entry = Macro(input[i])
            if not entry then return end
            AddMacro(macros, seen, entry)
        end
    end
    return true
end

local function Key(value)
    if not Text(value, MAX_KEY) or value:find("%s") then return end
    local rest, modifiers = value:upper(), {}
    while true do
        local modifier, tail = rest:match("^([A-Z]+)%-(.+)$")
        if not modifier then break end
        if not MODIFIERS[modifier] or modifiers[modifier] then return end
        modifiers[modifier] = true
        rest = tail
    end
    rest = KEY_ALIASES[rest] or rest
    if MODIFIERS[rest] or IGNORED_KEYS[rest] then return end
    local international = rest:match("^[\194-\244][\128-\191]+$")
    if not rest:match("^[!-~]$") and not rest:match("^[A-Z][A-Z0-9_]+$") and not international then return end
    if #rest > MAX_BASE_KEY then return end
    local f = tonumber(rest:match("^F(%d+)$"))
    local mouse = tonumber(rest:match("^BUTTON(%d+)$"))
    if rest:match("^F%d") and (not f or f < 1 or f > LAST_FUNCTION_KEY or rest ~= "F" .. f) then return end
    if rest:match("^BUTTON") and (not mouse or mouse < FIRST_MOUSE_BUTTON or mouse > LAST_MOUSE_BUTTON
        or rest ~= "BUTTON" .. mouse) then return end
    local parts = {}
    for _, modifier in ipairs(MODIFIER_ORDER) do
        if modifiers[modifier] then parts[#parts + 1] = modifier end
    end
    parts[#parts + 1] = rest
    return table.concat(parts, "-")
end

local function Bindings(input)
    if input == nil then return {} end
    if type(input) ~= "table" then return end
    local bindings, counts, count = {}, {}, 0
    for key, command in pairs(input) do
        local normalized = Key(key)
        if not normalized or bindings[normalized] or type(command) ~= "string" then return end
        local prefix, number = command:match("^(.-)(%d+)$")
        local valid = false
        if Integer(tonumber(number), A.C.SLOTS_PER_BAR) then
            for _, bar in ipairs(A.BARS) do
                if bar.button == prefix then valid = true break end
            end
        end
        if not valid then return end
        counts[command] = (counts[command] or 0) + 1
        if counts[command] > MAX_KEYS_PER_ACTION then return end
        count = count + 1
        if count > MAX_BINDINGS then return end
        bindings[normalized] = command
    end
    return bindings
end

local function Decode(text)
    if type(text) ~= "string" or #text > LIMITS.maxChars then return end
    local body = text:match("^%s*" .. PREFIX .. "(%S+)%s*$")
    local data = body and ns.Shared.Decode.String(body, LIMITS)
    if type(data) ~= "table" or data.v ~= VERSION or CLASSES[data.class] ~= A.Class()
        or not Text(data.name, MAX_NAME) or type(data.slots) ~= "table" then return end
    local slots, macros, seen, skip, count = {}, {}, {}, {}, 0
    if not ListMacros(data.macros, macros, seen) then return end
    for slot, row in pairs(data.slots) do
        if not Integer(slot, A.C.KEYBOARD_SLOTS) then return end
        local entry = Entry(row)
        if not entry then return end
        slots[slot], count = entry, count + 1
        if entry.kind == "macro" then AddMacro(macros, seen, entry) end
    end
    if count == 0 and #macros == 0 then return end
    local bindings = Bindings(data.bindings)
    if not bindings then return end
    for _, slot in ipairs(A.Capture.Slots()) do
        if not slots[slot] and (count == 0 or slot > A.C.KEYBOARD_SLOTS) then skip[slot] = true end
    end
    return data.name, { slots = slots, macros = macros, bindings = bindings,
        choices = { skip = skip, keys = next(bindings) ~= nil, website = true, macros = true, macroOff = {} } }
end

local function Ready()
    if not A.On() then ns.Print(TEXT_OFF) return false end
    if InCombatLockdown() then ns.Print(TEXT_COMBAT) return false end
    return true
end

local function Save(name, set)
    if not Ready() then return end
    local key = name
    for i = 1, MAX_SUFFIX do
        if not A.Find(key) then
            set.saved = time()
            A.Sets()[key] = set
            A.Refresh()
            ns.OpenActionBarsImport(key)
            return
        end
        local suffix = " (" .. i .. ")"
        key = name:sub(1, MAX_NAME - #suffix) .. suffix
    end
    ns.Print(TEXT_FULL)
end

local function Import(text)
    if not Ready() then return end
    local name, set = Decode(text)
    if not name then ns.Print(TEXT_INVALID) return end
    ns.Confirm(TEXT_CONFIRM:format(name), function() Save(name, set) end)
end

local function Prompt()
    if Ready() then ns.PromptText(TEXT_PROMPT, "", LIMITS.maxChars, Import) end
end

A.Sharing = { Decode = Decode, Import = Import, Prompt = Prompt }
ns.ImportActionBarString = Import
