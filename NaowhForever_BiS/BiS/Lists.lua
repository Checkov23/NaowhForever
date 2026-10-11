-- Lists.lua: your BiS lists, their old formats, and the ns calls that change them (B.Lists).
local ns = _G.NaowhForever

local B = ns.BiS
local C = B.C
local R = B.Rankings
local Items = ns.Shared.Items
local SLOT_NAME = Items.SLOT_NAME
local Picks, Store = B.Picks, B.Store

local NAME_MAX = C.NAME_MAX
local TEXT_DEFAULT_NAME = "My BiS"
local TEXT_NOT_FITTED = ns.L("Your BiS list now keeps a ranked list per slot. These did not fit: ")
local TEXT_NAME_EMPTY = ns.L("the name is empty")
local TEXT_NAME_TAKEN = ns.L("that name is taken")
local TEXT_NOT_GEAR = ns.L("That is not an item you can equip.")
local TEXT_ADDED = ns.L("Added %s to your BiS %s.")
local TEXT_ADDED_AS = ns.L("Added %s to your BiS %s as #%d.")
local FREE_NAME = "%s %d"
local NONE = {}

local lookup

local function ClassLists()
    local account = ns.AccountSettings()
    local _, class = UnitClass("player")
    account.bisLists = account.bisLists or {}
    local store = account.bisLists[class] or { lists = {}, nextID = 1 }
    account.bisLists[class] = store
    account.bisActive = account.bisActive or {}
    return store, account
end

local function AddList(store, list)
    list.id = store.nextID
    store.nextID = store.nextID + 1
    store.lists[#store.lists + 1] = list
    return list
end

local function Taken(store, name, except)
    for _, l in ipairs(store.lists) do
        if l ~= except and l.name:lower() == name:lower() then return true end
    end
    return false
end

local function FreeName(store, name)
    local try, n = name, 1
    while Taken(store, try) do
        n = n + 1
        try = FREE_NAME:format(name, n)
    end
    return try
end

local function CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function Use(list)
    local _, account = ClassLists()
    account.bisActive[CharKey()] = list.id
end

local function FreeSlot(slots, itemID)
    for _, s in ipairs(Items.SlotsFor(itemID) or NONE) do
        if not slots[s] then return s end
    end
end

local function SlotItems(list)
    local dropped = {}
    list.slots = {}
    for _, id in ipairs(list.items or NONE) do
        local slot = FreeSlot(list.slots, id)
        if slot then list.slots[slot] = id else dropped[#dropped + 1] = Items.Name(id) end
    end
    list.items = nil
    if #dropped > 0 then ns.Print(TEXT_NOT_FITTED .. table.concat(dropped, ", ")) end
end

local function MoveOwnList(store, account, key)
    local old = account.bis and account.bis[key]
    if not old then return end
    old.name = FreeName(store, (not old.name or old.name == TEXT_DEFAULT_NAME) and UnitName("player") or old.name)
    account.bisActive[key] = AddList(store, old).id
    account.bis[key] = nil
end

local function RankOldPicks(list)
    for slot, set in pairs(list.extra) do
        if not set[1] then
            list.extra[slot] = R.Ranked(set, R.Ranking(list.spec, slot))
            Store(list, slot, Picks(list, slot))
        end
    end
end

local function List()
    local store, account = ClassLists()
    local key = CharKey()
    MoveOwnList(store, account, key)
    local list
    for _, l in ipairs(store.lists) do
        if l.id == account.bisActive[key] then list = l end
    end
    list = list or store.lists[1] or AddList(store, { name = ns.L(TEXT_DEFAULT_NAME) })
    account.bisActive[key] = list.id
    list.extra = list.extra or {}
    if not list.slots then SlotItems(list) end
    RankOldPicks(list)
    return list
end

local function SwitchSpec(key)
    local list = List()
    local first = R.ClassSpecs()[1]
    local previous = list.spec or (first and first.key)
    if not key or key == previous then
        list.spec = previous
        return list
    end
    list.bySpec = list.bySpec or {}
    if previous then list.bySpec[previous] = { slots = list.slots, extra = list.extra } end
    local picks = list.bySpec[key] or { slots = {}, extra = {} }
    list.slots, list.extra, list.spec = picks.slots, picks.extra, key
    return list
end

local function Rebuild()
    lookup = {}
    local list = List()
    for slot in pairs(SLOT_NAME) do
        for rank, id in ipairs(Picks(list, slot)) do
            if not lookup[id] or rank < lookup[id] then lookup[id] = rank end
        end
    end
end

local function Changed()
    Rebuild()
    B.ListChanged()
end

local function CleanName(name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil end
    return (name:sub(1, NAME_MAX):gsub("|", "||"))
end

local function Edit(list, slot, change, ...)
    local picks = Picks(list, slot)
    change(picks, ...)
    Store(list, slot, picks)
end

local function IndexOf(picks, itemID)
    for i = 1, #picks do
        if picks[i] == itemID then return i end
    end
end

local function Append(picks, itemID)
    if not IndexOf(picks, itemID) then picks[#picks + 1] = itemID end
end

local function Drop(picks, itemID)
    local i = IndexOf(picks, itemID)
    if i then table.remove(picks, i) end
end

local function Step(picks, itemID, step)
    local i = IndexOf(picks, itemID)
    local j = i and i + step
    if j and picks[j] then picks[i], picks[j] = picks[j], itemID end
end

local function Top(picks, itemID)
    local i = IndexOf(picks, itemID)
    if i and i > 1 then
        table.remove(picks, i)
        table.insert(picks, 1, itemID)
    end
end

local L = {}
B.Lists = L
L.FreeSlot = FreeSlot
L.List = List

function L.CurrentSpec()
    local specs = R.ClassSpecs()
    local key = List().spec
    for _, spec in ipairs(specs) do
        if spec.key == key then return spec end
    end
    return specs[1]
end

function L.AddList(name, spec, slots, extra)
    local store = ClassLists()
    local list = AddList(store, { name = FreeName(store, name), spec = spec, slots = slots, extra = extra })
    Use(list)
    Changed()
    return list
end

function L.SlotOf(itemID)
    local list, best, bestRank = List(), nil, nil
    for slot in pairs(SLOT_NAME) do
        local picks = Picks(list, slot)
        for rank = 1, #picks do
            if picks[rank] == itemID and (not bestRank or rank < bestRank) then best, bestRank = slot, rank end
        end
    end
    return best
end

function ns.IsBisItem(itemID)
    if not (B.On() and itemID) then return nil end
    if not lookup then Rebuild() end
    return lookup[itemID]
end

function ns.BisListIsEmpty()
    return next(List().slots) == nil
end

function ns.SetBisSpec(key)
    for _, spec in ipairs(R.ClassSpecs()) do
        if spec.key == key then
            SwitchSpec(key)
            return Changed()
        end
    end
end

function ns.BisListChoices()
    local id = List().id
    local values, order = {}, {}
    for _, l in ipairs((ClassLists()).lists) do
        values[l.id], order[#order + 1] = l.name, l.id
    end
    return values, order, id
end

function ns.SelectBisList(id)
    for _, l in ipairs((ClassLists()).lists) do
        if l.id == id then
            Use(l)
            return Changed()
        end
    end
end

function ns.NewBisList(name)
    name = CleanName(name)
    if not name then return false, TEXT_NAME_EMPTY end
    if Taken((ClassLists()), name) then return false, TEXT_NAME_TAKEN end
    local current = L.CurrentSpec()
    L.AddList(name, current and current.key, {}, {})
    return true
end

function ns.RenameBisList(name)
    name = CleanName(name)
    if not name then return false, TEXT_NAME_EMPTY end
    local list = List()
    if Taken((ClassLists()), name, list) then return false, TEXT_NAME_TAKEN end
    list.name = name
    Changed()
    return true
end

function ns.DeleteBisList()
    local list = List()
    local lists = (ClassLists()).lists
    for i, l in ipairs(lists) do
        if l == list then
            table.remove(lists, i)
            break
        end
    end
    Changed()
end

function ns.AddBisPick(slot, itemID)
    Edit(List(), slot, Append, itemID)
    Changed()
end

function ns.RemoveBisPick(slot, itemID)
    Edit(List(), slot, Drop, itemID)
    Changed()
end

function ns.MoveBisPick(slot, itemID, step)
    Edit(List(), slot, Step, itemID, step)
    Changed()
end

function ns.TopBisPick(slot, itemID)
    Edit(List(), slot, Top, itemID)
    Changed()
end

function ns.AddBisItem(value)
    local id = Items.IDFrom(value)
    local fits = id and Items.SlotsFor(id)
    if not fits then
        ns.Print(TEXT_NOT_GEAR)
        return
    end
    if not lookup then Rebuild() end
    if lookup[id] then return end
    local list = List()
    local slot = FreeSlot(list.slots, id)
    ns.AddBisPick(slot or fits[1], id)
    if slot then
        ns.Print(TEXT_ADDED:format(Items.Name(id), Items.SlotName(slot)))
    else
        ns.Print(TEXT_ADDED_AS:format(Items.Name(id), Items.SlotName(fits[1]), #Picks(list, fits[1])))
    end
end

function ns.PromoteBisItem(itemID)
    local list = List()
    for slot in pairs(SLOT_NAME) do Edit(list, slot, Top, itemID) end
    Changed()
end

function ns.RemoveBisItem(itemID)
    local list = List()
    for slot in pairs(SLOT_NAME) do Edit(list, slot, Drop, itemID) end
    Changed()
end
