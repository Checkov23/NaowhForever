-- ConsumableBar.lua: the Consumable Bar's module table (ns.ConsumableBar), its entries, their settings and its change listeners.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local ITEM_FALLBACK = ns.L("Item %d")
local BUTTON_ITEM = "NaowhForeverConsumableBarItem%s"
local BUTTON_NAMED = "NaowhForeverConsumableBar%s"
local BIND_CLICK = "CLICK %s:LeftButton"
local MACRO_PREFIX = "macro:"
local MACRO_PATTERN = "^macro:(%a+)$"
local MACRO_NAME = "%s (%s)"
local ITEM_IN_BODY = "item:(%d+)"
local MANA_MACRO, DRINK_MACRO = "macro:mana", "macro:drink"

local NEEDS_MANA = { [MANA_MACRO] = true, [DRINK_MACRO] = true }

local NO_FLAGS = {}
local NO_ITEMS = {}
local listeners = {}
local shownFor, shown

local CB = {}
ns.ConsumableBar = CB
CB.S = S
CB.PREFIX = "consumableBar"
CB.PAGE = "Consumable Bar/Settings"
CB.CARD = "Consumable Bar/Settings:bar"

function CB.On()
    return S.Get("consumableBar") == true
end

function CB.Has(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

function CB.Secret(v)
    return issecretvalue and issecretvalue(v)
end

function CB.SavedItems()
    local items = S.Get("consumableBarItems")
    return type(items) == "table" and items or NO_ITEMS
end

function CB.NeedsMana(entry)
    return NEEDS_MANA[entry] == true
end

local function Hidden(entry)
    if NEEDS_MANA[entry] and not ns.UsesMana() then return true end
    return type(entry) == "string" and entry:find(MACRO_PATTERN) ~= nil and not CB.MacroInfo(entry)
end

local function AnyHidden(items)
    for _, entry in ipairs(items) do
        if Hidden(entry) then return true end
    end
    return false
end

function CB.Items()
    local items = CB.SavedItems()
    if shownFor == items then return shown end
    if not AnyHidden(items) then return items end
    shownFor, shown = items, {}
    for _, entry in ipairs(items) do
        if not Hidden(entry) then shown[#shown + 1] = entry end
    end
    return shown
end

function CB.Flags(entry)
    local all = S.Get("consumableBarItemFlags")
    return type(all) == "table" and all[entry] or NO_FLAGS
end

function CB.ItemName(itemID)
    return C_Item.GetItemNameByID(itemID) or ITEM_FALLBACK:format(itemID)
end

function CB.ItemSpell(itemID)
    local _, spellID = C_Item.GetItemSpell(itemID)
    if not spellID then C_Item.RequestLoadItemDataByID(itemID) end
    return spellID
end

function CB.MacroKey(entry)
    local key = type(entry) == "string" and entry:match(MACRO_PATTERN)
    return key and ns.ConsumableMacros and ns.ConsumableMacros[key] and key
end

function CB.MacroInfo(entry)
    local key = CB.MacroKey(entry)
    local macros = ns.ConsumableMacros
    return key and macros and macros[key]
end

function CB.MacroEntry(key)
    return MACRO_PREFIX .. key
end

function CB.Resolve(entry)
    if type(entry) == "number" then return entry end
    local info = CB.MacroInfo(entry)
    local body = info and GetMacroBody(info.name)
    return body and tonumber(body:match(ITEM_IN_BODY))
end

function CB.EntryName(entry)
    local info = CB.MacroInfo(entry)
    if info then return MACRO_NAME:format(info.label, info.name) end
    if type(entry) ~= "number" then return entry end
    return CB.ItemName(entry)
end

function CB.EntryIcon(entry)
    local item = CB.Resolve(entry)
    if item then return C_Item.GetItemIconByID(item) or CB.C.EMPTY_ICON end
    local info = CB.MacroInfo(entry)
    return info and info.icon or CB.C.EMPTY_ICON
end

function CB.EmptyTip(entry)
    local info = CB.MacroInfo(entry)
    return info and CB.EntryName(entry)
end

function CB.ButtonName(entry)
    local key = CB.MacroKey(entry)
    if key then return BUTTON_NAMED:format((key:gsub("^%l", string.upper))) end
    return BUTTON_ITEM:format(tostring(entry))
end

function CB.BindAction(entry)
    return BIND_CLICK:format(CB.ButtonName(entry))
end

function CB.HasMacro(key)
    return CB.Has(CB.SavedItems(), MACRO_PREFIX .. key)
end

function ns.ConsumableBarUsesMacro(key)
    return CB.On() and CB.HasMacro(key) or false
end

function CB.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function CB.Changed()
    for _, fn in ipairs(listeners) do fn() end
end
