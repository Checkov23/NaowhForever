-- Items.lua: the Consumable Bar's item rules: what counts as a consumable, what a Smart Macro covers, the list on the bar and each item's settings.
local ns = _G.NaowhForever

local CB = ns.ConsumableBar
local S, C, D = CB.S, CB.C, CB.Data

local MAX_ITEM_ID = 2147483647
local TEXT_PROMPT = ns.L("Item IDs or names, separated by commas")
local TEXT_NOT_ONE = ns.L("%s is not a consumable. Only consumables go on the Consumable Bar.")
local TEXT_NOT_MANY = ns.L("%s are not consumables. Only consumables go on the Consumable Bar.")
local TEXT_NO_NAME = ns.L("No item called %s in your bags or loaded by the game. Try its ID, or shift-click it into the box.")
local TEXT_NONE_KNOWN = ns.L("No known item in that. Enter item IDs or names, such as 13446 or Major Healing Potion.")
local TEXT_ADDED_ONE = ns.L("Added %d consumable to the Consumable Bar.")
local TEXT_ADDED = ns.L("Added %d consumables to the Consumable Bar.")
local TEXT_NOTHING_NEW = ns.L("No consumables in your bags that are not on the bar already.")
local TEXT_CLEAR = ns.L("Remove every item from the Consumable Bar?")
local TEXT_ASK_AGAIN = ns.L("The Consumable Bar will ask about those items again.")
local LIST_JOIN = ", "
local LOOK_FLAGS = { textOn = true, text = true, textFont = true, textSize = true, textColor = true,
    textPoint = true, textOutside = true, textX = true, textY = true }

local TEXT_NO_MANA = ns.L("You don't use mana. Add %s anyway?")
local TEXT_MIXED = ns.L("A Smart Macro already covers some of these, or they need mana: %s. Add them anyway?")
local TEXT_NEEDS_MANA = ns.L("You don't use mana, so that button would do nothing.")

local function FoodOnly()
    local M = ns.MacroSettings
    return M ~= nil and M.Get("foodOnly") == true
end

local function NotADrinkForFoodOnly(itemID)
    return not (FoodOnly() and ns.IsDrink(itemID))
end

local COVERS = {
    ["macro:food"] = { ask = ns.L("NF Food already uses your best food and drink. Add %s too?"),
        category = "food", also = NotADrinkForFoodOnly },
    ["macro:drink"] = { ask = ns.L("NF Drink already uses your best drink. Add %s too?"), category = "food",
        also = ns.IsDrink },
    ["macro:health"] = { ask = ns.L("NF Health already uses your best healthstone or healing potion. Add %s too?"),
        category = "healthstone", list = "HEALING_POTIONS" },
    ["macro:healthstone"] = { ask = ns.L("NF Healthstone already uses your best healthstone. Add %s too?"),
        category = "healthstone" },
    ["macro:healthPotion"] = { ask = ns.L("NF Health Potion already uses your best healing potion. Add %s too?"),
        list = "HEALING_POTIONS" },
    ["macro:mana"] = { ask = ns.L("NF Mana already uses your best mana potion. Add %s too?"), list = "MANA_POTIONS" },
    ["macro:bandage"] = { ask = ns.L("NF Bandage already uses your best bandage. Add %s too?"), category = "bandage" },
}

function CB.Category(itemID)
    if D.WEAPON[itemID] then return "weapon" end
    if CB.Has(ns.HEALTHSTONES, itemID) then return "healthstone" end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if classID == C.TRADE_GOODS_CLASS then return D.TRADE_GOODS[subclassID] end
    if classID ~= C.CONSUMABLE_CLASS then return nil end
    if subclassID == C.SCROLL_SUBCLASS and not D.SCROLLS[itemID] then return nil end
    return D.BY_SUBCLASS[subclassID] or "other"
end

function CB.CoveredBy(itemID)
    local category
    for _, entry in ipairs(CB.Items()) do
        local cover = COVERS[entry]
        if cover and CB.MacroInfo(entry) then
            category = category or CB.Category(itemID)
            local kind = (cover.category and cover.category == category) or (cover.list and CB.Has(ns[cover.list], itemID))
            if kind and (not cover.also or cover.also(itemID)) then return entry end
        end
    end
end

function CB.ManaOnly(itemID)
    return not ns.UsesMana() and (CB.Has(ns.MANA_POTIONS, itemID) or ns.IsDrink(itemID))
end

function CB.Wanted(itemID)
    local category = CB.Category(itemID)
    local skip = S.Get("consumableBarSkip") or {}
    return category ~= nil and not skip[category] and not CB.CoveredBy(itemID) and not CB.ManaOnly(itemID)
end

function CB.Blocked(entry)
    if CB.NeedsMana(entry) and not ns.UsesMana() then return TEXT_NEEDS_MANA end
end

function CB.SetFlag(entry, key, value)
    local copy = {}
    for id, flags in pairs(S.Get("consumableBarItemFlags") or {}) do
        local f = {}
        for k, v in pairs(flags) do f[k] = v end
        copy[id] = f
    end
    copy[entry] = copy[entry] or {}
    if value == "" or (value == false and key ~= "textOn") then value = nil end
    copy[entry][key] = value
    if not next(copy[entry]) then copy[entry] = nil end
    CB.lookOnly = LOOK_FLAGS[key] == true
    S.Set("consumableBarItemFlags", copy)
    CB.lookOnly = nil
end

function CB.AddItems(ids)
    local items, have, added = {}, {}, 0
    for i, id in ipairs(CB.SavedItems()) do
        items[i] = id
        have[id] = true
    end
    for _, id in ipairs(ids) do
        if not have[id] then
            items[#items + 1] = id
            have[id] = true
            added = added + 1
        end
    end
    if added > 0 then S.Set("consumableBarItems", items) end
    return added
end

local function IndexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
end

local function Without(entry)
    local items = {}
    for _, id in ipairs(CB.SavedItems()) do
        if id ~= entry then items[#items + 1] = id end
    end
    return items
end

function CB.PlaceItem(entry, before)
    if entry == before then return end
    local items = Without(entry)
    table.insert(items, IndexOf(items, before) or #items + 1, entry)
    S.Set("consumableBarItems", items)
end

function CB.MoveItem(entry, onto)
    if entry == onto then return end
    local saved = CB.SavedItems()
    local later = onto == nil or (IndexOf(saved, entry) or 0) < (IndexOf(saved, onto) or 0)
    local items = Without(entry)
    local at = IndexOf(items, onto)
    table.insert(items, at and (later and at + 1 or at) or #items + 1, entry)
    S.Set("consumableBarItems", items)
end

local function AddAt(ids, before)
    if before then CB.PlaceItem(ids[1], before) else CB.AddItems(ids) end
end

local function Question(by, manaOnly, names)
    local list = table.concat(names, LIST_JOIN)
    if by and manaOnly then return TEXT_MIXED:format(list) end
    if manaOnly then return TEXT_NO_MANA:format(list) end
    local cover = COVERS[by]
    return cover.ask:format(list)
end

function CB.AddAsked(ids, at)
    local plain, asked, names, by, manaOnly = {}, {}, {}, nil, false
    local items = CB.Items()
    for _, id in ipairs(ids) do
        local fresh = not CB.Has(items, id)
        local entry = fresh and CB.CoveredBy(id)
        local mana = fresh and not entry and CB.ManaOnly(id)
        if entry or mana then
            asked[#asked + 1] = id
            names[#names + 1] = CB.ItemName(id)
            by = by or entry or nil
            manaOnly = manaOnly or mana
        else
            plain[#plain + 1] = id
        end
    end
    if #plain > 0 then AddAt(plain, at) end
    if #asked == 0 then return end
    ns.Confirm(Question(by, manaOnly, names), function() AddAt(asked, at) end)
end

function CB.RemoveEntries(entries)
    local items = {}
    for _, id in ipairs(CB.SavedItems()) do
        if not CB.Has(entries, id) then items[#items + 1] = id end
    end
    local flags = {}
    for id, f in pairs(S.Get("consumableBarItemFlags") or {}) do
        if not CB.Has(entries, id) then flags[id] = f end
    end
    S.Set("consumableBarItemFlags", flags)
    S.Set("consumableBarItems", items)
end

function CB.SetMacro(key, on)
    local entry = CB.MacroEntry(key)
    if not on then
        if CB.HasMacro(key) then CB.RemoveEntries({ entry }) end
        return
    end
    local why = CB.Blocked(entry)
    if why then
        ns.Print(why)
        return
    end
    CB.AddItems({ entry })
end

function CB.RemoveItem(entry)
    CB.RemoveEntries({ entry })
end

local function ItemByName(name)
    local want, partial = name:lower(), nil
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            local itemName = id and C_Item.GetItemNameByID(id)
            if itemName then
                local lower = itemName:lower()
                if lower == want then return id end
                if not partial and lower:find(want, 1, true) then partial = id end
            end
        end
    end
    if partial then return partial end
    return (C_Item.GetItemInfoInstant(name))
end

function CB.ParseItems(text)
    if type(text) ~= "string" then return end
    local ids, seen, missing = {}, {}, {}
    local function Add(id)
        id = tonumber(id)
        if id and id >= 1 and id <= MAX_ITEM_ID and not seen[id] and C_Item.GetItemInfoInstant(id) then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]*:", ""):gsub("|r", "")
    text = text:gsub("|H(item:[^|]*)|h.-|h", "%1")
    text = text:gsub("item:(%d+)[%d:%-]*", ",#%1,")
    for piece in text:gmatch("[^,]+") do
        piece = strtrim(piece)
        if piece:match("^#%d+$") then
            Add(piece:sub(2))
        elseif piece:match("^[%d%s]+$") then
            for id in piece:gmatch("%d+") do Add(id) end
        elseif piece ~= "" then
            local id = ItemByName(piece)
            if id then Add(id) else missing[#missing + 1] = piece end
        end
    end
    return #ids > 0 and ids or nil, missing
end

local function OnlyConsumables(ids)
    local kept, refused = {}, {}
    for _, id in ipairs(ids or {}) do
        if CB.Category(id) then kept[#kept + 1] = id else refused[#refused + 1] = CB.ItemName(id) end
    end
    return kept, refused
end

function CB.SayNotConsumable(names)
    ns.Print((#names == 1 and TEXT_NOT_ONE or TEXT_NOT_MANY):format(table.concat(names, LIST_JOIN)))
end

local function Typed(text)
    local found, missing = CB.ParseItems(text)
    local ids, refused = OnlyConsumables(found)
    if #ids > 0 then CB.AddAsked(ids) end
    if #refused > 0 then CB.SayNotConsumable(refused) end
    if missing and #missing > 0 then
        ns.Print(TEXT_NO_NAME:format(table.concat(missing, LIST_JOIN)))
    elseif not found then
        ns.Print(TEXT_NONE_KNOWN)
    end
end

function CB.PromptAdd()
    ns.PromptText(TEXT_PROMPT, "", 0, Typed)
end

function CB.BagConsumables(found, seen)
    found, seen = found or {}, seen or {}
    wipe(found)
    wipe(seen)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] and CB.Category(id) then
                seen[id] = true
                found[#found + 1] = id
            end
        end
    end
    return found
end

function CB.ScanBags()
    local wanted = {}
    for _, id in ipairs(CB.BagConsumables()) do
        if CB.Wanted(id) then wanted[#wanted + 1] = id end
    end
    local added = CB.AddItems(wanted)
    if added > 0 then
        ns.Print((added == 1 and TEXT_ADDED_ONE or TEXT_ADDED):format(added))
    else
        ns.Print(TEXT_NOTHING_NEW)
    end
end

local function ClearAll()
    S.Set("consumableBarItemFlags", {})
    S.Set("consumableBarItems", {})
end

function CB.Clear()
    ns.Confirm(TEXT_CLEAR, ClearAll)
end

function CB.ForgetDeclined()
    S.Set("consumableBarDeclined", {})
    ns.Print(TEXT_ASK_AGAIN)
end
