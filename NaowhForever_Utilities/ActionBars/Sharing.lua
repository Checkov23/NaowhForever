-- Sharing.lua: a website bar layout decoded into a new saved set, then reviewed in the existing import preview.
local ns = _G.NaowhForever

local A = ns.ActionBars
local MAX_NAME, MAX_MACRO_NAME, MAX_BODY, MAX_ID = 40, 16, 255, 10000000
local VERSION, MAX_SUFFIX, MAX_MACROS = 1, 1000, 30
local NAMES_SHOWN = 4
local MAX_KEY, MAX_KEYS_PER_ACTION = 40, 2
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
local BUTTONS = {}
for _, bar in ipairs(A.BARS) do BUTTONS[bar.button] = A.C.SLOTS_PER_BAR end
BUTTONS[A.PET_BAR.button] = A.PET_BAR.buttons
local MAX_BINDINGS = 0
for _, count in pairs(BUTTONS) do MAX_BINDINGS = MAX_BINDINGS + count * MAX_KEYS_PER_ACTION end
local TEXT_INVALID = ns.L("That is not a valid website bar layout for your class.")
local TEXT_PROMPT = ns.L("Paste a code from naowh.gg")
local TEXT_PROMPT_LINE = ns.L("Copy it with Copy import code on the website's Action Bars, then paste it here.")
local TEXT_IMPORT = ns.L("Import")
local TEXT_EXPORT = ns.L("Export to Website")
local TEXT_EXPORT_LINE = ns.L("Paste it on naowh.gg/forever Action Bars with Paste a code.")
local TEXT_CLOSE = ns.L("Close")
local TEXT_ACTION, TEXT_ACTIONS = ns.L("%d action"), ns.L("%d actions")
local TEXT_KEYBIND, TEXT_KEYBINDS = ns.L("%d keybind"), ns.L("%d keybinds")
local TEXT_MACRO, TEXT_MACROS = ns.L("%d macro"), ns.L("%d macros")
local TEXT_WENT_IN = ns.L("In the code: %s, %s and %s.")
local TEXT_LEFT_OUT = ns.L("Left out, as the website cannot show them: %s.")
local TEXT_MORE_NAMES = ns.L("%s and %d more")
local TEXT_MACROS_LEFT = ns.L("Left out: %s, past the website's limit or sharing a name.")
local TEXT_NO_SPELLS = ns.L("Spells need the Training Planner addon turned on, so they were left out.")
local TEXT_NO_CODE = ns.L("The website code could not be made.")
local TEXT_COMBAT = ns.L("Bar sets can be imported out of combat.")
local TEXT_OFF = ns.L("Action Bars is switched off.")
local TEXT_CONFIRM = ns.L("Save %s as a new bar set and review it? Your bars stay unchanged until you apply the preview.")
local TEXT_FULL = ns.L("There are too many saved bar sets with that name.")
local TEXT_BARS = ns.L("%s bars")
local KINDS = { summonmount = ns.L("Mount"), summonpet = ns.L("Pet"), companion = ns.L("Companion"),
    flyout = ns.L("Flyout"), equipmentset = ns.L("Equipment set") }
local CLASS_IDS = {}
for id, class in pairs(CLASSES) do CLASS_IDS[class] = id end
local catalog, catalogClass

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
        if row.top ~= nil and (type(row.top) ~= "boolean" or (row.top and row.kind ~= "spell")) then return end
        return { kind = row.kind, id = row.id, name = row.name, top = row.top or nil }
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
        local buttons = prefix and BUTTONS[prefix]
        local n = tonumber(number)
        if not (buttons and Integer(n, buttons) and tostring(n) == number) then return end
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

local function Catalog(classID)
    local spells = ns.TrainingData and ns.TrainingData[classID]
    if not spells then return nil end
    if catalogClass == classID then return catalog end
    local tree = ns.TrainingBuilds and ns.TrainingBuilds[classID]
    catalog, catalogClass = {}, classID
    for _, row in ipairs(spells) do catalog[row[2]] = true end
    for _, talent in pairs(tree and tree.talents or {}) do catalog[talent[1]] = true end
    return catalog
end

local function LeftName(entry)
    if entry.kind == "spell" then return C_Spell.GetSpellName(entry.id) or entry.name or tostring(entry.id) end
    if entry.kind == "macro" then return entry.name end
    return KINDS[entry.kind] or entry.kind
end

local function ExportMacro(row)
    if type(row) ~= "table" then return end
    local body = type(row.body) == "string" and row.body:gsub("\r", "") or ""
    if not body:find("%S") then return end
    return Macro({ name = row.name, body = body, icon = row.icon, perCharacter = row.perCharacter })
end

local function AddExportMacro(out, entry)
    local listed = out.byName[entry.name]
    if listed then return listed.body == entry.body end
    if #out.macros >= MAX_MACROS then return false end
    out.byName[entry.name] = entry
    out.macros[#out.macros + 1] = entry
    return true
end

local function ExportSpell(entry, known)
    if not (known and known[entry.id] and Integer(entry.id, MAX_ID)) then return end
    return { kind = "spell", id = entry.id, name = Text(entry.name, MAX_BODY) and entry.name or nil,
        top = entry.top and true or nil }
end

local function ExportSlot(out, slot, entry, known)
    local row
    if slot <= A.C.KEYBOARD_SLOTS then
        if entry.kind == "spell" then row = ExportSpell(entry, known) end
        if entry.kind == "item" and Integer(entry.id, MAX_ID) then row = { kind = "item", id = entry.id } end
        if entry.kind == "macro" then
            row = ExportMacro(entry)
            if row and not AddExportMacro(out, row) then row = nil end
        end
    end
    if row then
        out.slots[slot], out.actions = row, out.actions + 1
    else
        out.left[#out.left + 1] = LeftName(entry)
    end
end

local function ExportBindings(out, bindings)
    local counts = {}
    for key, command in pairs(bindings or {}) do
        local normalized = Key(key)
        local prefix, number
        if type(command) == "string" then prefix, number = command:match("^(.-)(%d+)$") end
        local n = tonumber(number)
        local buttons = prefix and BUTTONS[prefix]
        if normalized and buttons and Integer(n, buttons) and tostring(n) == number and not out.bindings[normalized]
            and (counts[command] or 0) < MAX_KEYS_PER_ACTION then
            counts[command] = (counts[command] or 0) + 1
            out.bindings[normalized], out.keys = command, out.keys + 1
        end
    end
end

local function SlotOrder(slots)
    local order = {}
    for slot in pairs(slots) do order[#order + 1] = slot end
    table.sort(order)
    return order
end

local function ExportSet(key)
    local set = key and A.Sets()[key]
    if key and not set then return end
    return set or A.Capture.Snapshot(), key or TEXT_BARS:format(UnitName("player"))
end

local function Export(key)
    local set, name = ExportSet(key)
    if not set then return end
    local classID = CLASS_IDS[A.Class()]
    local known = Catalog(classID)
    local out = { slots = {}, macros = {}, byName = {}, bindings = {}, left = {}, actions = 0, keys = 0,
        macrosLeft = 0, spells = known ~= nil }
    for _, slot in ipairs(SlotOrder(set.slots or {})) do ExportSlot(out, slot, set.slots[slot], known) end
    for _, row in ipairs(set.macros or {}) do
        local entry = ExportMacro(row)
        if not (entry and AddExportMacro(out, entry)) then out.macrosLeft = out.macrosLeft + 1 end
    end
    ExportBindings(out, set.bindings)
    local code = ns.Shared.Encode.String(PREFIX, { v = VERSION, class = classID, name = name, slots = out.slots,
        macros = #out.macros > 0 and out.macros or nil, bindings = next(out.bindings) and out.bindings or nil })
    out.byName = nil
    return code, out
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
    if not Ready() then return end
    ns.Shared.Parts.CodeModal({ title = TEXT_PROMPT, line = TEXT_PROMPT_LINE, acceptText = TEXT_IMPORT,
        onAccept = Import, maxLetters = LIMITS.maxChars })
end

local function LeftNames(left)
    local seen, names = {}, {}
    for _, name in ipairs(left) do
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    local text = table.concat(names, ", ", 1, math.min(#names, NAMES_SHOWN))
    if #names > NAMES_SHOWN then text = TEXT_MORE_NAMES:format(text, #names - NAMES_SHOWN) end
    return A.Plural(#left, TEXT_ACTION, TEXT_ACTIONS) .. ": " .. text
end

local function ExportSummary(out)
    local lines = { TEXT_WENT_IN:format(A.Plural(out.actions, TEXT_ACTION, TEXT_ACTIONS),
        A.Plural(out.keys, TEXT_KEYBIND, TEXT_KEYBINDS), A.Plural(#out.macros, TEXT_MACRO, TEXT_MACROS)) }
    if #out.left > 0 then lines[#lines + 1] = TEXT_LEFT_OUT:format(LeftNames(out.left)) end
    if out.macrosLeft > 0 then
        lines[#lines + 1] = TEXT_MACROS_LEFT:format(A.Plural(out.macrosLeft, TEXT_MACRO, TEXT_MACROS))
    end
    if not out.spells then lines[#lines + 1] = TEXT_NO_SPELLS end
    return table.concat(lines, "\n")
end

local function ShowExport(key)
    local code, out = Export(key)
    if not code then ns.Print(TEXT_NO_CODE) return end
    ns.Shared.Parts.CodeModal({ title = TEXT_EXPORT, line = TEXT_EXPORT_LINE, code = code, copy = true,
        summary = ExportSummary(out), closeText = TEXT_CLOSE })
end

A.Sharing = { Decode = Decode, Import = Import, Prompt = Prompt, Export = Export, ShowExport = ShowExport,
    ExportSummary = ExportSummary }
ns.ImportActionBarString = Import
