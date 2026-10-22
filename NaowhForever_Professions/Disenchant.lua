-- Disenchant.lua: the bag items Disenchant can take, the ones you keep, and which one is next (P.Disenchant).
local ns = _G.NaowhForever

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemQualityByID = C_Item.GetItemQualityByID
local GetItemGUID = C_Item.GetItemGUID

local P = ns.Professions
local Values = P.DisenchantValues

local SPELL = 13262
local ENCHANTING = 333
local SLOT_KEY_SCALE = 1000
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local KEEP_KEY, COPY_KEY = "profDisenchantKeep", "profDisenchantKeepCopy"

local records, failed, misses = {}, {}, {}
local count = 0

local D = { SPELL = SPELL, ENCHANTING = ENCHANTING }
P.Disenchant = D

local function Saved(key)
    local account = ns.AccountSettings()
    account[key] = account[key] or {}
    return account[key]
end

local function CopyGUID(bag, slot)
    if not (GetItemGUID and ItemLocation) then return nil end
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    return location and location:IsValid() and GetItemGUID(location) or nil
end

local function Takes(itemID, quality)
    local _, _, _, equip, _, class = GetItemInfoInstant(itemID)
    return Values.ItemTakes(itemID, class, quality or GetItemQualityByID(itemID), equip)
end

local function Note(bag, slot, info)
    count = count + 1
    local r = records[count] or {}
    records[count] = r
    r.bag, r.slot, r.itemID = bag, slot, info.itemID
    r.link, r.icon = info.hyperlink, info.iconFileID
    r.quality = info.quality or GetItemQualityByID(info.itemID)
    r.locked = info.isLocked == true
    r.guid = CopyGUID(bag, slot)
    r.failureKey = r.guid or bag * SLOT_KEY_SCALE + slot
end

function D.Known()
    return C_SpellBook.IsSpellKnown(SPELL) == true
end

function D.Collect()
    count = 0
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local info = GetContainerItemInfo(bag, slot)
            if info and info.itemID and Takes(info.itemID, info.quality) then Note(bag, slot, info) end
        end
    end
    return records, count
end

function D.KeptAll(r)
    return Saved(KEEP_KEY)[r.itemID] == true
end

function D.KeptCopy(r)
    return r.guid ~= nil and Saved(COPY_KEY)[r.guid] == true
end

function D.Kept(r)
    return D.KeptAll(r) or D.KeptCopy(r)
end

function D.ToggleKeep(r, every)
    local all, copies = Saved(KEEP_KEY), Saved(COPY_KEY)
    local copy = D.KeptCopy(r)
    if r.guid then copies[r.guid] = nil end
    if every or not r.guid or all[r.itemID] then
        all[r.itemID] = not all[r.itemID] or nil
    elseif not copy then
        copies[r.guid] = true
    end
end

function D.Failed(r)
    return r and failed[r.failureKey] == true or false
end

function D.MarkFailed(r)
    if r then failed[r.failureKey] = true end
end

function D.Miss(r)
    if r then misses[r.failureKey] = (misses[r.failureKey] or 0) + 1 end
end

function D.Misses(r)
    return misses[r.failureKey] or 0
end

function D.Ready(r)
    return not (r.locked or D.Kept(r) or D.Failed(r))
end

function D.Next()
    local best
    for i = 1, count do
        local r = records[i]
        if D.Ready(r) and (not best or D.Misses(r) < D.Misses(best)) then best = r end
    end
    return best
end

function D.Counts()
    local ready, kept = 0, 0
    for i = 1, count do
        local r = records[i]
        if D.Kept(r) then
            kept = kept + 1
        elseif D.Ready(r) then
            ready = ready + 1
        end
    end
    return ready, kept
end
