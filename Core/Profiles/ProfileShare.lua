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
local MAX_QUEST_REWARDS = 2000
local ZERO = "\0"
local DEFAULT_PROFILE = "Default"
local MACROS_ADDON = "NaowhForever_Macros"
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
    "groupInvites", "questRewards" } }
local PARTS = {
    { key = "settings", label = "Settings", help = "Every module's settings and positions",
      share = ns.L("Every module's settings and where its frames sit.") },
    { key = "macros", label = "Macros", help = "Your class macros and the Macros settings",
      share = ns.L("Your class macros and the Macros settings.") },
    { key = "builds", label = "Talent Builds", help = "Added next to your saved builds",
      share = ns.L("The talent builds you saved in the Training Planner.") },
    { key = "bisLists", label = "BiS Lists", help = "Added next to your own lists, never over them",
      share = ns.L("Your BiS lists, for every class.") },
    { key = "actionBars", label = "Action Bars", help = "Added next to your saved bar sets, never over them",
      share = ns.L("Your saved action bar sets, for every class.") },
    { key = "questRewards", label = "Saved Quest Items", help = "The rewards you saved for quests, in this profile",
      share = ns.L("The quest rewards you saved with Alt-click.") },
    { key = "look", label = "Look", help = "Skin, theme colors, font and window scale, for every profile",
      share = ns.L("Skin, theme colors, font and window scale.") },
}
local LEGACY_PARTS = {
    { key = "library", label = "Macro Library", help = "Added next to your Library, never over it",
      share = ns.L("The macros you saved to the Macros Library.") },
    { key = "consumables", label = "Consumables", help = "The consumables your reminders watch",
      share = "The consumables your reminders watch." },
}
local API_PARTS = { settings = true, macros = true, library = true, consumables = true, builds = true,
    bisLists = true, questRewards = true, look = true }
local BAR_KINDS_NEED_ID = { spell = true, item = true }
local BAR_FLAGS = { "keys", "macros", "website", "petOff" }
local BAR_BUTTONS = { ACTIONBUTTON = 12, MULTIACTIONBAR1BUTTON = 12, MULTIACTIONBAR2BUTTON = 12,
    MULTIACTIONBAR3BUTTON = 12, MULTIACTIONBAR4BUTTON = 12, MULTIACTIONBAR5BUTTON = 12,
    MULTIACTIONBAR6BUTTON = 12, MULTIACTIONBAR7BUTTON = 12, BONUSACTIONBUTTON = 10 }
local BAR_KEYS_PER_ACTION = 2
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
local TEXT_QUEST_REWARDS = ns.L("%d quest rewards")
local TEXT_BAR_SETS = ns.L("%d bar sets")
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

local function ValidQuestRewards(picks)
    if type(picks) ~= "table" then return false end
    local count = 0
    for key, value in pairs(picks) do
        if type(key) == "string" and key:match("^%u+$") and type(value) == "table" then
            for questID, itemID in pairs(value) do
                count = count + 1
                local item = type(itemID) == "number" and math.abs(itemID)
                if count > MAX_QUEST_REWARDS or not PositiveID(questID) or not PositiveID(item) then return false end
            end
        else
            count = count + 1
            if count > MAX_QUEST_REWARDS or not PositiveID(key) or not PositiveID(value) then return false end
        end
    end
    return true
end

local function CleanQuestRewards(picks)
    local out = {}
    for key, value in pairs(picks) do
        if type(value) == "table" then
            local class = {}
            for questID, itemID in pairs(value) do class[questID] = itemID end
            out[key] = next(class) and class or nil
        else
            out[key] = value
        end
    end
    return next(out) and out or nil
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

local MODULE_STATE_KEY = "__modules"

local function ProfileSwitch(root, m)
    if not m.store then return nil end
    local values, on = root[m.store.key], nil
    if type(values) == "table" then on = values[m.key] end
    if type(on) ~= "boolean" then on = m.store.Default(m.key) end
    return on == true
end

local function CollectModuleState(profile)
    if type(ns.ModuleAddons) ~= "function" then return nil end
    local out
    for _, m in ipairs(ns.ModuleAddons(UnitGUID("player"))) do
        local on = m.on == true
        if profile then on = ProfileSwitch(profile, m) end
        if type(m.addon) == "string" and on ~= nil then
            out = out or {}
            out[m.addon] = on
        end
    end
    return out
end

local function CollectMacros(root, utility, budget)
    local macros = {}
    if type(root.macros) == "table" then macros.module = Plain(root.macros, 1, budget) end
    if utility and type(utility.classMacros) == "table" then
        macros.classMacros = Plain(utility.classMacros, 1, budget)
    end
    return next(macros) and macros or nil
end

local function CollectQuestRewards(root, budget)
    local picks = type(root.qol) == "table" and root.qol.questRewards
    if type(picks) ~= "table" then return nil end
    picks = CleanQuestRewards(picks)
    return picks and Plain(picks, 1, budget)
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

local function CollectBarSets(account, budget)
    if type(account.barSets) ~= "table" then return nil end
    local sets = {}
    for class, store in pairs(account.barSets) do
        if type(store) == "table" and next(store) then sets[class] = Plain(store, 1, budget) end
    end
    return next(sets) and sets or nil
end

local function CollectBuilds(account, budget)
    if type(account.trainingBuilds) ~= "table" then return nil end
    local builds = {}
    for classID, list in pairs(account.trainingBuilds) do
        local out = {}
        for i, b in ipairs(list) do
            local skip = {}
            for spell in pairs(type(b.skip) == "table" and b.skip or {}) do skip[#skip + 1] = spell end
            table.sort(skip)
            out[i] = { name = b.name, spec = b.spec, points = Plain(b.points, 1, budget),
                skip = #skip > 0 and Plain(skip, 1, budget) or nil }
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

local function Collect(root)
    local active = ns.SettingsRoot()
    root = root or active
    local account = ns.AccountSettings()
    local budget = { n = 0 }
    local utility = Utility(root.tankReminder)
    local parts = {}
    parts.settings = CollectSettings(root, budget)
    local moduleState = CollectModuleState(root ~= active and root)
    if moduleState then
        parts.settings = parts.settings or {}
        parts.settings[MODULE_STATE_KEY] = moduleState
    end
    parts.macros = CollectMacros(root, utility, budget)
    parts.bisLists = CollectBisLists(account, budget)
    parts.actionBars = CollectBarSets(account, budget)
    parts.builds = CollectBuilds(account, budget)
    parts.questRewards = CollectQuestRewards(root, budget)
    parts.look = CollectLook(account, budget)
    return parts, budget.over
end

function ns.ExportProfile(wanted, profileName)
    local LS, LD = Codec()
    if not LS then return nil, TEXT_NO_LIBRARIES end
    local all, over = Collect(profileName and ns.ProfileTable(profileName))
    if over then return nil, TEXT_TOO_BIG_PROFILE end
    local parts = {}
    for key, data in pairs(all) do
        if not wanted or wanted[key] then parts[key] = data end
    end
    if not next(parts) then
        return nil, next(all) and TEXT_TICK_PART or TEXT_NOTHING_TO_EXPORT
    end
    local payload = {
        format = FORMAT, name = profileName or ns.ActiveProfileName(), author = UnitName("player"),
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

local function ValidModuleState(state)
    if type(state) ~= "table" then return false end
    for addon, on in pairs(state) do
        if type(addon) ~= "string" or type(on) ~= "boolean" then return false end
    end
    return true
end

local function CleanParts(payload)
    local Text, parts = ns.Shared.Decode.Text, payload.parts
    payload.name, payload.author = Text(payload.name, TEXT_MAX), Text(payload.author, TEXT_MAX)
    payload.made = Text(payload.made, TEXT_MAX)
    if type(parts.settings) == "table" then
        local state = parts.settings[MODULE_STATE_KEY]
        parts.settings[MODULE_STATE_KEY] = ValidModuleState(state) and state or nil
    end
    local qol = type(parts.settings) == "table" and parts.settings.qol
    if type(qol) == "table" then
        if parts.questRewards == nil then parts.questRewards = qol.questRewards end
        qol.questRewards = nil
    end
    parts.questRewards = ValidQuestRewards(parts.questRewards) and CleanQuestRewards(parts.questRewards) or nil
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

local function QuestRewardCount(data)
    local n = 0
    for _, value in pairs(data) do n = n + (type(value) == "table" and Count(value) or 1) end
    return n
end

local function PartDetail(key, data)
    if key == "settings" then
        local n = Count(data)
        if data[MODULE_STATE_KEY] then n = n - 1 end
        return TEXT_MODULES:format(n)
    end
    if key == "actionBars" then
        local n = 0
        for _, sets in pairs(data) do
            if type(sets) == "table" then n = n + Count(sets) end
        end
        return TEXT_BAR_SETS:format(n)
    end
    if key == "macros" then return TEXT_CLASS_MACROS:format(ClassMacroCount(data)) end
    if key == "questRewards" then return TEXT_QUEST_REWARDS:format(QuestRewardCount(data)) end
    if LIST_NOUN[key] then return ("%d %s"):format(ListCount(data), LIST_NOUN[key]) end
end

function ns.ProfileStringParts(payload)
    local out, parts = {}, payload.parts
    for _, list in ipairs({ PARTS, LEGACY_PARTS }) do
        for _, part in ipairs(list) do
            local data = parts[part.key]
            if type(data) == "table" and next(data) then
                out[#out + 1] = { key = part.key, label = part.label, help = part.help,
                    detail = PartDetail(part.key, data) }
            end
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
    { module = "qol", key = "scrapMarker", label = "Junk Marker, which sells what it marks", when = SellsScrap },
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
    local out = { name = name, spec = ns.Shared.Decode.Text(list.spec, LIST_TEXT_MAX), slots = {}, extra = {},
        specOnly = list.specOnly == true or nil }
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

local function BarName(text, max)
    return Sized(text, 1, max or TEXT_MAX) and not text:find("[|%c]")
end

local function BarBody(text)
    return Sized(text, 1, MACRO_BODY_MAX) and not text:find("[%z\1-\8\11-\31]")
end

local function CleanBarAction(entry, kind)
    if type(entry) ~= "table" then return nil end
    local out = { kind = kind }
    if PositiveID(entry.id) or BarName(entry.id) then out.id = entry.id end
    if BarName(entry.name) then out.name = entry.name end
    if BarBody(entry.body) then out.body = entry.body end
    if PositiveID(entry.icon) or BarBody(entry.icon) then out.icon = entry.icon end
    if type(entry.perCharacter) == "boolean" then out.perCharacter = entry.perCharacter end
    if kind == "spell" and entry.top == true then out.top = true end
    if BAR_KINDS_NEED_ID[kind] and type(out.id) ~= "number" then return nil end
    if (kind == nil or kind == "macro") and not (out.name and out.body) then return nil end
    return out
end

local function BarButton(command)
    if type(command) ~= "string" then return false end
    local prefix, n = command:match("^(.-)(%d+)$")
    n = tonumber(n)
    return BAR_BUTTONS[prefix] and n >= 1 and n <= BAR_BUTTONS[prefix]
end

local function CleanBarChoices(raw)
    local choices = { skip = {}, macroOff = {} }
    for slot, on in pairs(type(raw.skip) == "table" and raw.skip or {}) do
        if PositiveID(slot) and on == true then choices.skip[slot] = true end
    end
    for key, on in pairs(type(raw.macroOff) == "table" and raw.macroOff or {}) do
        if Sized(key, 1, TEXT_MAX + MACRO_BODY_MAX) and on == true then choices.macroOff[key] = true end
    end
    for _, flag in ipairs(BAR_FLAGS) do
        if type(raw[flag]) == "boolean" then choices[flag] = raw[flag] end
    end
    return choices
end

local function CleanBarSet(raw)
    if type(raw) ~= "table" or type(raw.slots) ~= "table" then return nil end
    local set = { saved = PositiveID(raw.saved) and raw.saved or nil, by = BarName(raw.by) and raw.by or nil,
        slots = {}, macros = {} }
    for slot, entry in pairs(raw.slots) do
        local kind = type(entry) == "table" and entry.kind
        if PositiveID(slot) and BarName(kind) and kind:match("^%l+$") then set.slots[slot] = CleanBarAction(entry, kind) end
    end
    for _, m in ipairs(type(raw.macros) == "table" and raw.macros or {}) do
        set.macros[#set.macros + 1] = CleanBarAction(m)
    end
    if type(raw.bindings) == "table" then
        set.bindings = {}
        local keys = {}
        for key, command in pairs(raw.bindings) do
            local n = BarName(key) and BarButton(command) and (keys[command] or 0) + 1
            if n and n <= BAR_KEYS_PER_ACTION then set.bindings[key], keys[command] = command, n end
        end
    end
    if type(raw.choices) == "table" then set.choices = CleanBarChoices(raw.choices) end
    return set
end

local function BarSetTaken(sets, name)
    local lower = name:lower()
    for key in pairs(sets) do
        if key:lower() == lower then return true end
    end
    return false
end

local function FindBarSet(sets, set)
    if not set.saved then return nil end
    for key, mine in pairs(sets) do
        if type(mine) == "table" and mine.saved == set.saved and mine.by == set.by then return key end
    end
    return nil
end

local function AddBarSets(incoming, root)
    local account = ns.AccountSettings()
    account.barSets = type(account.barSets) == "table" and account.barSets or {}
    local chosen = type(root.actionBars) == "table" and root.actionBars.autoImportSets
    chosen = type(chosen) == "table" and chosen or {}
    local added = 0
    for class, sets in pairs(incoming) do
        if type(class) == "string" and class:match("^%u+$") and type(sets) == "table" then
            local mine = type(account.barSets[class]) == "table" and account.barSets[class] or {}
            local auto = chosen[class]
            for name, raw in pairs(sets) do
                local set = BarName(name) and CleanBarSet(raw)
                local key = set and FindBarSet(mine, set)
                if set and not key then
                    local n = 1
                    key = name
                    while BarSetTaken(mine, key) do
                        n = n + 1
                        key = ("%s %d"):format(name, n)
                    end
                    mine[key] = set
                    added = added + 1
                end
                if key and auto == name then chosen[class] = key end
            end
            if next(mine) then account.barSets[class] = mine end
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

local function NewBuild(classID, tree, b)
    local Training = ns.Training
    local points = BuildPoints(b)
    if #points == 0 or Training.CheckBuild(tree, points) then return nil end
    return { name = Training.BuildName(b.name, IMPORTED_BUILD),
        spec = Training.BuildName(b.spec, IMPORTED_SPEC), points = points, saved = true,
        skip = Training.CleanSkips(classID, b.skip) }
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
                local build = NewBuild(classID, tree, b)
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

local function ApplyModuleState(root, state)
    if type(state) ~= "table" then return end
    for _, item in pairs(ns.Setup.ITEMS) do
        local want = state[item.addon]
        if type(want) == "boolean" then
            if type(root[item.db]) ~= "table" then root[item.db] = {} end
            root[item.db][item.key] = want
        end
    end
end

local function ImportSettings(root, settings, wanted)
    for key, values in pairs(settings) do
        local defaults = ns.ModuleDefaults(key)
        if defaults and key ~= MACROS_KEY and key ~= SR_KEY and type(values) == "table" then
            root[key] = DropOwn(key, Checked(values, defaults))
        end
    end
    ApplyModuleState(root, settings[MODULE_STATE_KEY])
    if wanted.acting then return end
    for _, item in ipairs(ACTING) do
        local values = root[item.module]
        if type(values) == "table" and ActingOn(settings, item) then
            values[item.key] = nil
        end
    end
end

local function ImportQuestRewards(root, picks)
    if type(root.qol) ~= "table" then root.qol = {} end
    root.qol.questRewards = CleanQuestRewards(picks)
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
    local kept = wanted.keepPositions and ns.KeepPositions(ns.SettingsRoot())
    local root
    name, root = ImportTarget(payload, name, overwrite)
    if wanted.settings and type(parts.settings) == "table" then ImportSettings(root, parts.settings, wanted) end
    if wanted.consumables and ValidConsumables(parts.consumables) then
        OwnUtility(root).consumables = CleanConsumables(parts.consumables)
    end
    if wanted.macros and type(parts.macros) == "table" then ImportMacros(root, parts.macros) end
    if wanted.questRewards and ValidQuestRewards(parts.questRewards) then
        ImportQuestRewards(root, parts.questRewards)
    end
    local added = { bisLists = 0, library = 0, builds = 0, actionBars = 0 }
    if wanted.bisLists and type(parts.bisLists) == "table" then added.bisLists = AddBisLists(parts.bisLists) end
    if wanted.actionBars and type(parts.actionBars) == "table" then added.actionBars = AddBarSets(parts.actionBars, root) end
    if wanted.library and ns.ModuleOn(MACROS_ADDON) and type(parts.library) == "table" then
        added.library = AddLibrary(parts.library)
    end
    if wanted.builds and ns.Training and type(parts.builds) == "table" then added.builds = AddBuilds(parts.builds) end
    if wanted.look and type(parts.look) == "table" then ImportLook(parts.look) end
    if kept then ns.PutPositionsBack(root, kept) end

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

function API:ExportProfile(profileKey)
    if type(profileKey) ~= "string" or not self:GetProfileKeys()[profileKey] then return nil end
    return (ns.ExportProfile(API_PARTS, profileKey))
end

function API:DecodeProfileString(str)
    local payload = ns.DecodeProfile(str)
    return payload and payload.parts
end

function API:SetProfile(profileKey)
    if type(profileKey) ~= "string" or not self:GetProfileKeys()[profileKey] then return false end
    return (ns.SwitchProfile(profileKey))
end

function API:GetProfileKeys()
    local keys = {}
    for _, name in ipairs(ns.ListProfiles()) do keys[name] = true end
    return keys
end

function API:GetProfileAssignments()
    local out = {}
    for _, known in ipairs(ns.KnownCharacters()) do out[known.char] = known.profile end
    return out
end

function API:GetCurrentProfileKey()
    return ns.ActiveProfileName()
end

function API:OpenConfig()
    ns.OpenOptionsWindow("Profiles")
end

function API:CloseConfig()
    ns.StashOptionsWindow()
end

Profiles.PARTS = PARTS
Profiles.Collect = Collect
Profiles.FreeName = FreeProfileName
