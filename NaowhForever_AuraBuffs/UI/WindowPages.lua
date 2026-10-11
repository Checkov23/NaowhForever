-- WindowPages.lua: the AuraBuffs window's page: the consumables to watch.
local ns = _G.NaowhForever

local UI = ns.UI
local A = ns.AuraBuffs
local S = A.Settings
local CATEGORY_NAMES, CATEGORY_ORDER, MAX_ENTRIES = A.CATEGORY_NAMES, A.CATEGORY_ORDER, A.MAX_ENTRIES

local PROMPT_WIDTH = 240
local PASTE_LIMIT = 0

local TEXT_PROMPT = ns.L("Item ID, then buff spell ID(s) if not the item's own")
local TEXT_INVALID = ns.L("Enter an item ID, then any buff spell IDs, separated by commas.")
local TEXT_CONSUMABLES = ns.L("Add an item ID, or import a list. Food counts any Well Fed "
    .. "buff and other items their own buff; add buff spell IDs only for an item that gives another. "
    .. "Nothing is added automatically. Hover a reminder to choose a configured item from your bags. "
    .. "Reminders pause in combat; item menus work outside combat. When and where they show is on "
    .. "AuraBuffs > Settings.")
local TEXT_IDS = "Item ID, buff spell IDs optional"
local TEXT_IMPORT = "Import a list or a profile's consumables"
local TEXT_IMPORT_PROMPT = ns.L("Paste a consumables list or a profile string")
local TEXT_NO_LIST = ns.L("That string holds no consumables list.")
local TEXT_ADDED = ns.L("Added %d consumables; %d were already listed or past the %d limit.")
local TEXT_EXPORT = "Copy this profile's list"
local TEXT_EXPORT_TITLE = ns.L("Consumables list")
local TEXT_NOTHING_TO_EXPORT = ns.L("There are no consumables to export yet.")
local TEXT_BUFFS = "Buffs: "
local TEXT_WELL_FED = ns.L("Buff: any Well Fed")
local TEXT_OWN_BUFF = ns.L("Buff: the item's own")

local function Entries()
    return S.Get("consumableEntries") or {}
end

local function SaveEntry(category, index, text)
    local entry = ns.ParseConsumableEntry(category, text)
    if not entry then ns.Print(TEXT_INVALID) return end
    local copy = {}
    for i, value in ipairs(Entries()) do copy[i] = value end
    copy[index or #copy + 1] = entry
    S.Set("consumableEntries", copy)
    UI:RefreshPage(true)
end

local function EntryText(entry)
    if not entry.auras then return tostring(entry.itemID) end
    return entry.itemID .. ", " .. table.concat(entry.auras, ", ")
end

local function EditEntry(category, index)
    local existing = index and Entries()[index]
    local initial = existing and EntryText(existing) or ""
    ns.PromptText(TEXT_PROMPT, initial, PROMPT_WIDTH, function(text) SaveEntry(category, index, text) end)
end

local function RemoveEntry(index)
    local copy = {}
    for i, value in ipairs(Entries()) do
        if i ~= index then copy[#copy + 1] = value end
    end
    S.Set("consumableEntries", copy)
    UI:RefreshPage(true)
end

local function MergeList(text)
    local incoming = ns.ParseConsumableList(text)
    if not incoming then ns.Print(TEXT_NO_LIST) return end
    local entries, have = {}, {}
    for i, entry in ipairs(Entries()) do
        entries[i] = entry
        have[entry.category .. ":" .. entry.itemID] = true
    end
    local added = 0
    for _, entry in ipairs(incoming) do
        local key = entry.category .. ":" .. entry.itemID
        if not have[key] and #entries < MAX_ENTRIES then
            have[key] = true
            entries[#entries + 1] = entry
            added = added + 1
        end
    end
    S.Set("consumableEntries", entries)
    ns.Print(TEXT_ADDED:format(added, #incoming - added, MAX_ENTRIES))
    UI:RefreshPage(true)
end

local function ImportList()
    ns.PromptText(TEXT_IMPORT_PROMPT, "", PASTE_LIMIT, MergeList)
end

local function ExportList()
    local entries = Entries()
    if #entries == 0 then ns.Print(TEXT_NOTHING_TO_EXPORT) return end
    ns.ShowCopyBox(TEXT_EXPORT_TITLE, ns.ConsumableListString(entries))
end

local function BuffsText(category, entry)
    if entry.auras then return TEXT_BUFFS .. table.concat(entry.auras, ", ") end
    return category == "food" and TEXT_WELL_FED or TEXT_OWN_BUFF
end

local function EntryRow(parent, y, category, index, entry)
    local W = UI.Widgets
    local name = C_Item.GetItemNameByID(entry.itemID) or ("Item " .. entry.itemID)
    local _, h = W:DualRow(parent, y,
        { type = "button", text = name, buttonText = "Edit",
            onClick = function() EditEntry(category, index) end },
        { type = "button", text = BuffsText(category, entry), buttonText = "Remove",
            onClick = function() RemoveEntry(index) end })
    return y - h
end

local function Category(parent, y, category)
    local W = UI.Widgets
    local _, h = W:SectionHeader(parent, ns.Upper(CATEGORY_NAMES[category]), y)
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = ns.L("Add %s"):format(CATEGORY_NAMES[category]), buttonText = "Add",
            onClick = function() EditEntry(category) end },
        { type = "label", text = TEXT_IDS })
    y = y - h
    for index, entry in ipairs(Entries()) do
        if entry.category == category then y = EntryRow(parent, y, category, index, entry) end
    end
    return y
end

function ns.BuildAuraBuffConsumables(parent, y)
    local W = UI.Widgets
    local _, h = W:Note(parent, TEXT_CONSUMABLES, y)
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = TEXT_IMPORT, buttonText = "Import", onClick = ImportList },
        { type = "button", text = TEXT_EXPORT, buttonText = "Export", onClick = ExportList })
    y = y - h
    for _, category in ipairs(CATEGORY_ORDER) do y = Category(parent, y, category) end
    return y
end
