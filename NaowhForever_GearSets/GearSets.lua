-- GearSets.lua: the gear sets' rules and API (ns.GearSets): your sets, equipping them, automatic swaps.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local TEXT_AFTER_COMBAT = ns.L("Gear set equips when combat ends.")
local SWAP_KEYS = { "gearMounted", "gearResting" }

local pending
local autoSet

local function ByName(a, b) return a.name < b.name end

local function Sets()
    local sets = {}
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local name, icon, setID, isEquipped, numItems, _, _, numLost = C_EquipmentSet.GetEquipmentSetInfo(id)
        if name then
            sets[#sets + 1] = { id = setID, name = name, icon = icon, equipped = isEquipped,
                items = numItems, lost = numLost }
        end
    end
    table.sort(sets, ByName)
    return sets
end

local function EquippedSet()
    for _, set in ipairs(Sets()) do
        if set.equipped then return set.id end
    end
end

local function SetByName(name)
    if not name or name == "" then return end
    return C_EquipmentSet.GetEquipmentSetID(name)
end

local function Equip(setID)
    if not setID then return end
    if InCombatLockdown() then
        pending = setID
        ns.Print(TEXT_AFTER_COMBAT)
        return
    end
    pending = nil
    C_EquipmentSet.UseEquipmentSet(setID)
end

local function Saved()
    local account = ns.AccountSettings()
    account.gearReturn = account.gearReturn or {}
    return account.gearReturn, UnitName("player") .. "-" .. GetRealmName()
end

local function WantedAuto()
    if IsMounted() then
        local id = SetByName(S.Get("gearMounted"))
        if id then return id end
    end
    if IsResting() then return SetByName(S.Get("gearResting")) end
end

local G = { SWAP_KEYS = SWAP_KEYS }
ns.GearSets = G

G.Sets = Sets

function G.On()
    return S.Get("gearSets")
end

function G.EquipByHand(setID)
    local saved, key = Saved()
    saved[key] = nil
    Equip(setID)
end

function G.EquipPending()
    if pending then Equip(pending) end
end

function G.AutoSwap()
    local want = WantedAuto()
    if want == autoSet then return end
    local saved, key = Saved()
    if want then
        if not autoSet and EquippedSet() ~= want then saved[key] = EquippedSet() end
        autoSet = want
        Equip(want)
    else
        autoSet = nil
        Equip(saved[key])
        saved[key] = nil
    end
end
