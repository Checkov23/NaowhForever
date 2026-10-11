-- Layout.lua: the Top Bar's saved layout of buttons on each side, its migration from the old button keys, and editing it (ns.TopBar.Layout).
local ns = _G.NaowhForever

local TB = ns.TopBar
local S = TB.Settings
local C = TB.C

local LDB_PREFIX, SIDES = C.LDB_PREFIX, C.SIDES
local OLD_BUTTONS = { showFriends = true, showGuild = true, showHearth = false }
local OLD_BROKERS = { "NaowhForeverJournal", "NaowhForeverBiS" }
local OLD_DQ, JOURNAL = "NaowhForeverDQ", "NaowhForeverJournal"

local BUILTIN = { friends = ns.L("Friends"), guild = ns.L("Guild"), hearth = "Hearthstone" }
local BUILTIN_ORDER = { "friends", "guild", "hearth" }

local function IndexOf(list, key)
    for i = 1, #list do
        if list[i] == key then return i end
    end
end

local function InLayoutOf(layout, key)
    return IndexOf(layout.left, key) ~= nil or IndexOf(layout.right, key) ~= nil
end

local function MigrateBrokers(db)
    local saved = db.brokers
    if not (saved and IndexOf(saved, OLD_DQ)) then return end
    local keep = IndexOf(saved, JOURNAL) ~= nil
    for i = #saved, 1, -1 do
        if saved[i] == OLD_DQ then
            if keep then table.remove(saved, i) else saved[i], keep = JOURNAL, true end
        end
    end
    local sides = db.brokerSide
    if sides and sides[OLD_DQ] then
        sides[JOURNAL] = sides[JOURNAL] or sides[OLD_DQ]
        sides[OLD_DQ] = nil
    end
end

local function OldButton(db, key)
    local v = db[key]
    if v == nil then return OLD_BUTTONS[key] end
    return v
end

local function HasOldKeys(db)
    return db.showFriends ~= nil or db.showGuild ~= nil or db.showHearth ~= nil or db.brokers ~= nil
        or db.brokerSide ~= nil
end

local function MigrateLayout(db)
    db.layoutMigrated = true
    if db.layout ~= nil then return end
    if not HasOldKeys(db) then return end
    MigrateBrokers(db)
    local left, right = {}, {}
    if OldButton(db, "showHearth") then right[1] = "hearth" end
    local sides = type(db.brokerSide) == "table" and db.brokerSide or {}
    for _, name in ipairs(type(db.brokers) == "table" and db.brokers or OLD_BROKERS) do
        local list = sides[name] == "left" and left or right
        list[#list + 1] = LDB_PREFIX .. name
    end
    if OldButton(db, "showFriends") then left[#left + 1] = "friends" end
    if OldButton(db, "showGuild") then left[#left + 1] = "guild" end
    db.layout = { left = left, right = right }
end

local function SavedLayout()
    local db = S.DB()
    if not db.layoutMigrated then MigrateLayout(db) end
    local layout = S.Get("layout")
    if type(layout) ~= "table" or type(layout.left) ~= "table" or type(layout.right) ~= "table" then
        return S.Default("layout")
    end
    return layout
end

local function CopyList(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    return out
end

local function EditableLayout(key)
    local layout = SavedLayout()
    local out = { left = CopyList(layout.left), right = CopyList(layout.right) }
    for s = 1, #SIDES do
        local list = out[SIDES[s]]
        for i = #list, 1, -1 do
            if list[i] == key then table.remove(list, i) end
        end
    end
    return out
end

local function RemoveKey(key)
    S.Set("layout", EditableLayout(key))
end

local function MoveKey(key, side, before)
    local layout = EditableLayout(key)
    local list = layout[side]
    table.insert(list, before and IndexOf(list, before) or #list + 1, key)
    S.Set("layout", layout)
end

local function AddKey(side, key)
    local layout = EditableLayout(key)
    local list = layout[side]
    table.insert(list, side == "left" and 1 or #list + 1, key)
    S.Set("layout", layout)
end

local function ResetLayout()
    S.Set("layout", nil)
end

local function BrokerName(key)
    return key:sub(#LDB_PREFIX + 1)
end

local function ButtonName(key)
    if BUILTIN[key] then return BUILTIN[key] end
    local name = BrokerName(key)
    local ldb = TB.LDB()
    local obj = ldb and ldb:GetDataObjectByName(name)
    return obj and obj.label or name
end

TB.Layout = { BUILTIN = BUILTIN, BUILTIN_ORDER = BUILTIN_ORDER, Saved = SavedLayout, InLayoutOf = InLayoutOf,
    IndexOf = IndexOf, Remove = RemoveKey, Move = MoveKey, Add = AddKey, Reset = ResetLayout,
    BrokerName = BrokerName, Name = ButtonName }
