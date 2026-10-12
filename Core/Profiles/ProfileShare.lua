-- ProfileShare.lua: a whole profile as one string: what it holds, its export, decoding and import.
local ns = _G.NaowhForever

local PREFIX = "NFPROFILE1:"
local OLD_PACK_PREFIX = "NSRPACK2:"
local FORMAT = 1
local MAX_DEPTH = 12
local MAX_VALUES = 200000
local LIMITS = { maxChars = 1000000, maxBytes = 4194304, maxDepth = 32, maxValues = 1000000 }
local TEXT_MAX = 64
local LIST_TEXT_MAX = 40
local MACRO_NAME_MAX, MACRO_BODY_MAX, MACRO_NOTE_MAX = 16, 255, 200
local MAX_CONSUMABLES, MAX_AURAS, MAX_CLASS_MACROS = 500, 100, 100
local MAX_ID = 2147483647
local ITEM_ID_LIMIT = 2147483648
local MAX_PICKS = 50
local ZERO = "\0"
local DEFAULT_PROFILE = "Default"
local IMPORTED_PROFILE = ns.L("Imported Profile")
local IMPORTED_BUILD, IMPORTED_SPEC = ns.L("Imported Build"), ns.L("Imported")
local SR_KEY, MACROS_KEY = "tankReminder", "macros"
local OLD_CONSUMABLES_KEYS = { "smartReminders", "reminders" }
local CONSUMABLE_CATEGORIES = { food = true, flask = true, scroll = true, battle = true, guardian = true }
local LOOK = { "themePreset", "themeColors", "uiFont", "windowScale", "skin" }
local LOOK_TYPES = { themePreset = "string", themeColors = "table", uiFont = "string", windowScale = "number",
    skin = "string" }
local GEAR_SLOT = { [1] = true, [2] = true, [3] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true,
    [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true, [18] = true }
local OWN = { qol = { "characterPanelAsked", "characterPanelTookOver", "inspectPanelAsked", "inspectPanelTookOver",
    "groupInvites" } }
local PARTS = {
    { key = "settings", label = "Settings", help = "Every module's settings and positions",
      share = ns.L("Every module's settings and where its frames sit.") },
    { key = "macros", label = "Macros", help = "Your class macros and the Macros settings",
      share = ns.L("Your class macros and the Macros settings.") },
    { key = "library", label = "Macro Library", help = "Added next to your Library, never over it",
      share = ns.L("The macros you saved to the Forge's Library.") },
    { key = "consumables", label = "Consumables", help = "The consumables your reminders watch",
      share = "The consumables your reminders watch." },
    { key = "builds", label = "Talent Builds", help = "Added next to your saved builds",
      share = ns.L("The talent builds you saved in the Training Planner.") },
    { key = "bisLists", label = "BiS Lists", help = "Added next to your own lists, never over them",
      share = ns.L("Your BiS lists, for every class.") },
    { key = "look", label = "Look", help = "Skin, theme colors, font and window scale, for every profile",
      share = ns.L("Skin, theme colors, font and window scale.") },
}
local API_PARTS = { settings = true, macros = true, library = true, consumables = true, builds = true,
    bisLists = true, look = true }
local LIST_NOUN = { bisLists = ns.L("lists"), library = ns.L("macros"), builds = ns.L("builds") }
local TEXT_NO_LIBRARIES = ns.L("The serializer libraries are missing from this build.")
local TEXT_TOO_BIG_PROFILE = ns.L("This profile is too big to share.")
local TEXT_TICK_PART = ns.L("Tick a part to share.")
local TEXT_NOTHING_TO_EXPORT = ns.L("There is nothing to export yet.")
local TEXT_NOT_PROFILE = ns.L("This is not a Naowh Forever profile string.")
local TEXT_NO_PACKS = ns.L("Reminder Packs are no longer supported.")
local TEXT_TOO_BIG = ns.L("This string is too big.")
local TEXT_DAMAGED = ns.L("The string is damaged: copy it again in full.")
local TEXT_NEWER = ns.L("This string is from a newer Naowh Forever: update first.")
local TEXT_MODULES = ns.L("%d modules")
local TEXT_CLASS_MACROS = ns.L("%d class macros")
local TEXT_NOTHING_TO_READ = ns.L("Nothing to read.")
local TEXT_IMPORT_FAILED = ns.L("Naowh Forever import failed: ")
local TEXT_SPEC_SWITCH_OFF = ns.L("Per-spec profile switching is off while every character shares '%s'; your spec "
    .. "choices are kept if you switch it back on.")

local Profiles = {}
ns.Profiles = Profiles
ns.PROFILE_OWN = OWN

local function DropOwn(key, values)
    local own = OWN[key]
    if own and type(values) == "table" then
        for i = 1, #own do values[own[i]] = nil end
    end
    return values
end

local function Codec()
    local LS = LibStub and LibStub("LibSerialize", true)
    local LD = LibStub and LibStub("LibDeflate", true)
    if LS and LD then return LS, LD end
end

local function PositiveID(id)
    return type(id) == "number" and id >= 1 and id <= MAX_ID and id == math.floor(id)
end

local function ArrayOf(list, max, Valid)
    if type(list) ~= "table" then return false end
    local count = 0
    for index, value in pairs(list) do
        count = count + 1
        if count > max or not PositiveID(index) or not Valid(value) then return false end
    end
    for i = 1, count do
        if list[i] == nil then return false end
    end
    return true
end

local function ValidAuras(auras)
    if auras == nil then return true end
    return type(auras) == "table" and auras[1] ~= nil and ArrayOf(auras, MAX_AURAS, PositiveID)
end

local function ValidConsumable(entry)
    return type(entry) == "table" and CONSUMABLE_CATEGORIES[entry.category] == true
        and PositiveID(entry.itemID) and ValidAuras(entry.auras)
end

local function ValidConsumables(list)
    return ArrayOf(list, MAX_CONSUMABLES, ValidConsumable)
end

local function Sized(text, min, max)
    return type(text) == "string" and #text >= min and #text <= max
end

local function ValidMacro(entry)
    return type(entry) == "table" and Sized(entry.name, 1, MACRO_NAME_MAX) and Sized(entry.body, 1, MACRO_BODY_MAX)
        and (entry.icon == nil or PositiveID(entry.icon))
        and (entry.note == nil or Sized(entry.note, 0, MACRO_NOTE_MAX))
end

local function ValidClassMacros(classMacros)
    if type(classMacros) ~= "table" then return false end
    for class, entries in pairs(classMacros) do
        if type(class) ~= "string" or not class:match("^%u+$")
            or not ArrayOf(entries, MAX_CLASS_MACROS, ValidMacro) then return false end
    end
    return true
end

local function CleanConsumables(list)
    local out = {}
    for i, entry in ipairs(list) do
        local auras
        if entry.auras then
            auras = {}
            for j, id in ipairs(entry.auras) do auras[j] = id end
        end
        out[i] = { category = entry.category, itemID = entry.itemID, auras = auras }
    end
    return out
end

local function CleanClassMacros(classMacros)
    local out = {}
    for class, entries in pairs(classMacros) do
        local list = {}
        for i, m in ipairs(entries) do
            list[i] = { name = m.name, body = m.body, icon = m.icon, note = m.note }
        end
        out[class] = list
    end
    return out
end

local function Plain(v, depth, budget)
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return v end
    if t ~= "table" or depth > MAX_DEPTH or budget.over then return nil end
    local out = {}
    for k, val in pairs(v) do
        budget.n = budget.n + 1
        if budget.n > MAX_VALUES then
            budget.over = true
            return nil
        end
        local kt = type(k)
        if kt == "string" or kt == "number" then out[k] = Plain(val, depth + 1, budget) end
    end
    return out
end

local function Swap(v, from, to)
    if v == from then return to end
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[Swap(k, from, to)] = Swap(val, from, to) end
    return out
end

local function Checked(values, defaults)
    local out = {}
    for k, v in pairs(values) do
        local d = defaults[k]
        if d == nil or type(v) == type(d) then out[k] = v end
    end
    return out
end

local function Utility(sr)
    local utility = type(sr) == "table" and sr.utilityReminders
    return type(utility) == "table" and utility or nil
end

local function CollectSettings(root, budget)
    local settings = {}
    for key, values in pairs(root) do
        if key ~= SR_KEY and key ~= MACROS_KEY and type(values) == "table" and ns.ModuleDefaults(key) then
            settings[key] = DropOwn(key, Plain(values, 1, budget))
        end
    end
    return next(settings) and settings or nil
end

local function CollectMacros(root, utility, budget)
    local macros = {}
    if type(root.macros) == "table" then macros.module = Plain(root.macros, 1, budget) end
    if utility and type(utility.classMacros) == "table" then
        macros.classMacros = Plain(utility.classMacros, 1, budget)
    end
    return next(macros) and macros or nil
end

local function CollectConsumables(utility, budget)
    local list = utility and utility.consumables
    if type(list) ~= "table" or not next(list) then return nil end
    return Plain(list, 1, budget)
end

local function CollectBisLists(account, budget)
    if type(account.bisLists) ~= "table" then return nil end
    local lists = {}
    for class, store in pairs(account.bisLists) do
        if type(store) == "table" and type(store.lists) == "table" and #store.lists > 0 then
            lists[class] = Plain(store.lists, 1, budget)
        end
    end
    return next(lists) and lists or nil
end

local function CollectLibrary(account, budget)
    if type(account.libraryMacros) ~= "table" then return nil end
    local library = {}
    for class, list in pairs(account.libraryMacros) do
        local own = {}
        for i, m in ipairs(list) do own[i] = Plain(m, 1, budget) end
        if #own > 0 then library[class] = own end
    end
    return next(library) and library or nil
end

local function CollectBuilds(account, budget)
    if type(account.trainingBuilds) ~= "table" then return nil end
    local builds = {}
    for classID, list in pairs(account.trainingBuilds) do
        local out = {}
        for i, b in ipairs(list) do
            out[i] = { name = b.name, spec = b.spec, points = Plain(b.points, 1, budget) }
        end
        if #out > 0 then builds[classID] = out end
    end
    return next(builds) and builds or nil
end

local function CollectLook(account, budget)
    local look = {}
    for _, key in ipairs(LOOK) do
        if account[key] ~= nil then look[key] = Plain(account[key], 1, budget) end
    end
    return next(look) and look or nil
end

local function Collect()
    local root, account = ns.SettingsRoot(), ns.AccountSettings()
    local budget = { n = 0 }
    local utility = Utility(root.tankReminder)
    local parts = {}
    parts.settings = CollectSettings(root, budget)
    parts.macros = CollectMacros(root, utility, budget)
    parts.consumables = CollectConsumables(utility, budget)
    parts.bisLists = CollectBisLists(account, budget)
    parts.library = CollectLibrary(account, budget)
    parts.builds = CollectBuilds(account, budget)
    parts.look = CollectLook(account, budget)
    return parts, budget.over
end

function ns.ExportProfile(wanted)
    local LS, LD = Codec()
    if not LS then return nil, TEXT_NO_LIBRARIES end
    local all, over = Collect()
    if over then return nil, TEXT_TOO_BIG_PROFILE end
    local parts = {}
    for key, data in pairs(all) do
        if not wanted or wanted[key] then parts[key] = data end
    end
    if not next(parts) then
        return nil, next(all) and TEXT_TICK_PART or TEXT_NOTHING_TO_EXPORT
    end
    local payload = {
        format = FORMAT, name = ns.ActiveProfileName(), author = UnitName("player"),
        made = date("%Y-%m-%d"), build = ns.CODE_BUILD, parts = parts,
    }
    return PREFIX .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(Swap(payload, 0, ZERO))))
end

local function OldConsumables(parts)
    for _, key in ipairs(OLD_CONSUMABLES_KEYS) do
        local utility = Utility(parts[key])
        parts[key] = nil
        if parts.consumables == nil and utility then parts.consumables = utility.consumables end
    end
end

local function CleanParts(payload)
    local Text, parts = ns.Shared.Decode.Text, payload.parts
    payload.name, payload.author = Text(payload.name, TEXT_MAX), Text(payload.author, TEXT_MAX)
    payload.made = Text(payload.made, TEXT_MAX)
    OldConsumables(parts)
    parts.consumables = ValidConsumables(parts.consumables) and CleanConsumables(parts.consumables) or nil
    local macros = parts.macros
    if type(macros) == "table" and macros.classMacros ~= nil then
        macros.classMacros = ValidClassMacros(macros.classMacros) and CleanClassMacros(macros.classMacros) or nil
    end
end

function ns.DecodeProfile(text)
    text = (text or ""):gsub("%s", "")
    if text == "" then return nil end
    if text:sub(1, #OLD_PACK_PREFIX) == OLD_PACK_PREFIX then return nil, TEXT_NO_PACKS end
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, TEXT_NOT_PROFILE end
    local payload, why = ns.Shared.Decode.String(text:sub(#PREFIX + 1), LIMITS)
    if why == "missing" then return nil, TEXT_NO_LIBRARIES end
    if why == "big" then return nil, TEXT_TOO_BIG end
    if type(payload) ~= "table" or type(payload.parts) ~= "table" then return nil, TEXT_DAMAGED end
    if payload.format ~= FORMAT then return nil, TEXT_NEWER end
    local budget = { n = 0 }
    payload.parts = Plain(Swap(payload.parts, ZERO, 0), 1, budget)
    if budget.over then return nil, TEXT_TOO_BIG end
    CleanParts(payload)
    return payload
end

local function Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function ClassMacroCount(data)
    local n = 0
    for _, list in pairs(type(data.classMacros) == "table" and data.classMacros or {}) do
        if type(list) == "table" then n = n + Count(list) end
    end
    return n
end

local function ListCount(data)
    local n = 0
    for _, list in pairs(data) do
        if type(list) == "table" then n = n + #list end
    end
    return n
end

local function PartDetail(key, data)
    if key == "settings" then return TEXT_MODULES:format(Count(data)) end
    if key == "macros" then return TEXT_CLASS_MACROS:format(ClassMacroCount(data)) end
    if LIST_NOUN[key] then return ("%d %s"):format(ListCount(data), LIST_NOUN[key]) end
end

function ns.ProfileStringParts(payload)
    local out, parts = {}, payload.parts
    for _, part in ipairs(PARTS) do
        local data = parts[part.key]
        if type(data) == "table" and next(data) then
            out[#out + 1] = { key = part.key, label = part.label, help = part.help,
                detail = PartDetail(part.key, data) }
        end
    end
    return out
end

local function SellsScrap(values)
    return (values.scrapMarkerVendor or "sell") == "sell"
end

local ACTING = {
    { module = "qol", key = "questAccept", label = "Accept Quests" },
    { module = "qol", key = "questTurnIn", label = "Hand In Quests" },
    { module = "qol", key = "questShare", label = "Share Quests With Group" },
    { module = "qol", key = "autoRepair", label = "Auto Repair" },
    { module = "qol", key = "sellJunk", label = "Auto Sell Junk" },
    { module = "qol", key = "restockBuy", label = "Buy at Vendors" },
    { module = "qol", key = "lootConfirm", label = "Skip Loot Confirmations" },
    { module = "qol", key = "scrapMarker", label = "Scrap Marker, which sells what it marks", when = SellsScrap },
    { module = "journal", key = "acceptShared", label = "Accept Shared Dungeon Quests" },
}

local function ActingOn(settings, item)
    local values = type(settings) == "table" and settings[item.module]
    if type(values) ~= "table" or values[item.key] ~= true then return false end
    local defaults = ns.ModuleDefaults(item.module)
    if defaults and defaults[item.key] == true then return false end
    return not item.when or item.when(values)
end

function ns.ProfileActing(payload)
    local out, settings = {}, type(payload.parts) == "table" and payload.parts.settings
    for _, item in ipairs(ACTING) do
        if ActingOn(settings, item) then
            out[#out + 1] = item.label
        end
    end
    return out
end

local function Trim(text)
    return text:match("^%s*(.-)%s*$")
end

local function FreeProfileName(base)
    base = type(base) == "string" and Trim(base) or ""
    if base == "" then base = IMPORTED_PROFILE end
    if not ns.ProfileExists(base) then return base end
    local n = 2
    while ns.ProfileExists(base .. " " .. n) do n = n + 1 end
    return base .. " " .. n
end

local function SameList(a, b)
    if a.name ~= b.name or type(a.slots) ~= type(b.slots) then return false end
    if type(a.slots) ~= "table" then return true end
    for slot, id in pairs(a.slots) do if b.slots[slot] ~= id then return false end end
    for slot in pairs(b.slots) do if a.slots[slot] == nil then return false end end
    return true
end

local function ItemID(id)
    return type(id) == "number" and id >= 1 and id < ITEM_ID_LIMIT and id % 1 == 0
end

local function CleanExtra(ids)
    local keep = {}
    for _, id in ipairs(ids) do
        if ItemID(id) and #keep < MAX_PICKS then keep[#keep + 1] = id end
    end
    return keep[1] and keep or nil
end

local function CleanBisList(list)
    if type(list) ~= "table" or type(list.slots) ~= "table" then return nil end
    local name = ns.Shared.Decode.Text(list.name, LIST_TEXT_MAX)
    if not name or name == "" then return nil end
    local out = { name = name, spec = ns.Shared.Decode.Text(list.spec, LIST_TEXT_MAX), slots = {}, extra = {} }
    for slot, id in pairs(list.slots) do
        if GEAR_SLOT[slot] and ItemID(id) then out.slots[slot] = id end
    end
    for slot, ids in pairs(type(list.extra) == "table" and list.extra or {}) do
        if GEAR_SLOT[slot] and type(ids) == "table" then out.extra[slot] = CleanExtra(ids) end
    end
    return out
end

local function ListNameTaken(store, try)
    for _, mine in ipairs(store.lists) do
        if type(mine.name) == "string" and mine.name:lower() == try:lower() then return true end
    end
end

local function HasList(store, list)
    for _, mine in ipairs(store.lists) do
        if type(list) == "table" and SameList(mine, list) then return true end
    end
    return false
end

local function ClassStore(account, class)
    local store = account.bisLists[class]
    if type(store) ~= "table" or type(store.lists) ~= "table" then
        store = { lists = {}, nextID = 1 }
        account.bisLists[class] = store
    end
    store.nextID = tonumber(store.nextID) or #store.lists + 1
    return store
end

local function AddBisList(store, raw)
    local list = CleanBisList(raw)
    if not (type(list) == "table" and type(list.name) == "string") or HasList(store, list) then return 0 end
    local base = list.name
    local name, n = base, 1
    while ListNameTaken(store, name) do
        n = n + 1
        name = ("%s %d"):format(base, n)
    end
    list.name, list.id = name, store.nextID
    store.nextID = store.nextID + 1
    store.lists[#store.lists + 1] = list
    return 1
end

local function AddBisLists(incoming)
    local account = ns.AccountSettings()
    account.bisLists = type(account.bisLists) == "table" and account.bisLists or {}
    local added = 0
    for class, lists in pairs(incoming) do
        if type(class) == "string" and type(lists) == "table" then
            local store = ClassStore(account, class)
            for _, raw in ipairs(lists) do added = added + AddBisList(store, raw) end
        end
    end
    return added
end

local function LibraryEntry(m, mine)
    local name = type(m) == "table" and type(m.name) == "string" and m.name:gsub("[|\r\n]", "")
    local body = name and m.body
    local taken = false
    for _, e in ipairs(mine) do taken = taken or e.name == name end
    if not (name and #name >= 1 and #name <= MACRO_NAME_MAX and type(body) == "string" and #body >= 1
        and #body <= ns.Macros.C.LIMIT and not taken) then return nil end
    local icon = (type(m.icon) == "number" or type(m.icon) == "string") and m.icon or nil
    return { name = name, body = body, icon = icon }
end

local function AddLibrary(incoming)
    local account = ns.AccountSettings()
    account.libraryMacros = type(account.libraryMacros) == "table" and account.libraryMacros or {}
    local added = 0
    for class, list in pairs(incoming) do
        if type(class) == "string" and type(list) == "table" then
            local mine = account.libraryMacros[class] or {}
            for _, m in ipairs(list) do
                local entry = LibraryEntry(m, mine)
                if entry then
                    mine[#mine + 1] = entry
                    account.libraryMacros[class] = mine
                    added = added + 1
                end
            end
        end
    end
    return added
end

local function SameBuild(a, b)
    if a.name ~= b.name or #a.points ~= #b.points then return false end
    for i, node in ipairs(a.points) do if b.points[i] ~= node then return false end end
    return true
end

local function BuildPoints(b)
    local points = {}
    for i, node in ipairs(type(b) == "table" and type(b.points) == "table" and b.points or {}) do
        points[i] = node
    end
    return points
end

local function NewBuild(tree, b)
    local Training = ns.Training
    local points = BuildPoints(b)
    if #points == 0 or Training.CheckBuild(tree, points) then return nil end
    return { name = Training.BuildName(b.name, IMPORTED_BUILD),
        spec = Training.BuildName(b.spec, IMPORTED_SPEC), points = points, saved = true }
end

local function HasBuild(saved, build)
    local have = false
    for _, mine in ipairs(saved) do have = have or SameBuild(mine, build) end
    return have
end

local function AddBuilds(incoming)
    local account = ns.AccountSettings()
    account.trainingBuilds = type(account.trainingBuilds) == "table" and account.trainingBuilds or {}
    local added = 0
    for classID, list in pairs(incoming) do
        local tree = ns.TrainingBuilds[classID]
        if tree and type(list) == "table" then
            local saved = account.trainingBuilds[classID] or {}
            for _, b in ipairs(list) do
                local build = NewBuild(tree, b)
                if build and not HasBuild(saved, build) then
                    saved[#saved + 1] = build
                    account.trainingBuilds[classID] = saved
                    added = added + 1
                end
            end
        end
    end
    if added > 0 then ns.Training.Changed() end
    return added
end

local function ImportSettings(root, settings, wanted)
    for key, values in pairs(settings) do
        local defaults = ns.ModuleDefaults(key)
        if defaults and key ~= MACROS_KEY and key ~= SR_KEY and type(values) == "table" then
            root[key] = DropOwn(key, Checked(values, defaults))
        end
    end
    if wanted.acting then return end
    for _, item in ipairs(ACTING) do
        local values = root[item.module]
        if type(values) == "table" and ActingOn(settings, item) then
            values[item.key] = nil
        end
    end
end

local function OwnUtility(root)
    if type(root.tankReminder) ~= "table" then root.tankReminder = {} end
    local sr = root.tankReminder
    if type(sr.utilityReminders) ~= "table" then sr.utilityReminders = {} end
    return sr.utilityReminders
end

local function ImportMacros(root, macros)
    if type(macros.module) == "table" then root.macros = Checked(macros.module, ns.ModuleDefaults("macros") or {}) end
    if ValidClassMacros(macros.classMacros) then
        OwnUtility(root).classMacros = CleanClassMacros(macros.classMacros)
    end
end

local function ImportLook(look)
    local account = ns.AccountSettings()
    for _, key in ipairs(LOOK) do
        if type(look[key]) == LOOK_TYPES[key] then account[key] = look[key] end
    end
end

local function ImportTarget(payload, name, overwrite)
    local trimmed = type(name) == "string" and Trim(name)
    local replace = overwrite and trimmed ~= DEFAULT_PROFILE and ns.ProfileExists(trimmed)
    name = replace and trimmed or FreeProfileName(name or payload.name)
    local root = ns.ProfileRoot(name)
    if replace then
        for key in pairs(root) do root[key] = nil end
        root.tankReminder = {}
    end
    return name, root
end

function ns.ImportProfile(payload, wanted, name, overwrite)
    local parts = payload.parts
    local root
    name, root = ImportTarget(payload, name, overwrite)
    if wanted.settings and type(parts.settings) == "table" then ImportSettings(root, parts.settings, wanted) end
    if wanted.consumables and ValidConsumables(parts.consumables) then
        OwnUtility(root).consumables = CleanConsumables(parts.consumables)
    end
    if wanted.macros and type(parts.macros) == "table" then ImportMacros(root, parts.macros) end
    local added = { bisLists = 0, library = 0, builds = 0 }
    if wanted.bisLists and type(parts.bisLists) == "table" then added.bisLists = AddBisLists(parts.bisLists) end
    if wanted.library and ns.Macros and type(parts.library) == "table" then added.library = AddLibrary(parts.library) end
    if wanted.builds and ns.Training and type(parts.builds) == "table" then added.builds = AddBuilds(parts.builds) end
    if wanted.look and type(parts.look) == "table" then ImportLook(parts.look) end

    ns.SwitchProfile(name)
    if ns.RefreshRuntime then ns.RefreshRuntime() end
    return name, added
end

local function CurrentSpecEntry()
    local spec = ns.CurrentSpec and ns.CurrentSpec()
    if not spec or spec <= 0 then return nil end
    return tostring(spec), ns.SpecProfileMap()[tostring(spec)]
end

local API = {}
_G.NaowhForever_API = API

function API:ImportProfile(str, profileName)
    local specKey, specWas = CurrentSpecEntry()
    local payload, why = ns.DecodeProfile(str)
    if not payload then
        why = why or TEXT_NOTHING_TO_READ
        ns.Print(TEXT_IMPORT_FAILED .. tostring(why))
        return false, why
    end
    local landed = ns.ImportProfile(payload, API_PARTS, profileName, true)
    local set, autoOff = ns.SetAccountProfile(landed)
    if set and specKey then ns.SpecProfileMap()[specKey] = specWas end
    if set and autoOff then ns.Print(TEXT_SPEC_SWITCH_OFF:format(landed)) end
    return true, landed
end

Profiles.PARTS = PARTS
Profiles.Collect = Collect
Profiles.FreeName = FreeProfileName
