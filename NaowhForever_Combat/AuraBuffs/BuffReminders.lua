-- BuffReminders.lua: the Buffs & Consumables rules: which food, flask, elixir and class buffs are missing.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local D = ns.BuffReminderData

local MAX_AURAS = 40
local SECONDS = A.C.SECONDS
local PARTY_UNITS = MAX_PARTY_MEMBERS or 4
local RAID_UNITS_MAX = MAX_RAID_MEMBERS or 40
local CATEGORY_ORDER = A.CATEGORY_ORDER
local WEAPON_SLOTS = { 16, 17 }
local CLASS_INDEX = 6
local REQUIRED_LEVEL = 5
local ITEM_ICON = 10
local ELITE = { elite = true, rareelite = true, worldboss = true }
local MAX_LEVEL = 60
local WHERE = {
    consumables = { none = "consumablesWorld", party = "consumablesDungeon", raid = "consumablesRaid",
        atMax = "consumablesMaxHide" },
    raidBuffs = { none = "raidBuffsWorld", party = "raidBuffsDungeon", raid = "raidBuffsRaid",
        atMax = "raidBuffsMaxHide" },
    personalBuffs = { none = "personalBuffsWorld", party = "personalBuffsDungeon", raid = "personalBuffsRaid",
        atMax = "personalBuffsMaxHide" },
}

local GROUP_UNIT = { player = true }
local RAID_UNITS, PARTY_UNITS_LIST = {}, {}
for i = 1, PARTY_UNITS do
    GROUP_UNIT["party" .. i] = true
    PARTY_UNITS_LIST[i] = "party" .. i
end
for i = 1, RAID_UNITS_MAX do
    GROUP_UNIT["raid" .. i] = true
    RAID_UNITS[i] = "raid" .. i
end

local BUILT_IN = {}
for category, group in pairs(D.DEFAULT_GROUPS) do
    for _, id in ipairs(group.items) do BUILT_IN[id] = category end
end

local CLASSIC_WEAPON_ICON = {}
for _, icon in pairs(D.WEAPON_ICONS) do CLASSIC_WEAPON_ICON[icon] = true end

local buffPool, members, memberCount, classes = {}, {}, 0, {}
local missingUnits = {}
local requested = {}
local carried
local wellFedName
local wakeAt
local lastImbue
local leveledTo
local hidden = {}

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function Buffs(unit)
    local buffs = buffPool[unit]
    if buffs then wipe(buffs) else buffs = {}; buffPool[unit] = buffs end
    for i = 1, MAX_AURAS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        if Secret(aura.spellId) then return nil end
        buffs[aura.spellId] = aura
    end
    return buffs
end

local function Find(buffs, ids, own)
    for _, id in ipairs(ids) do
        local aura = buffs[id]
        if aura and (not own or Secret(aura.sourceUnit) or aura.sourceUnit == "player") then return aura end
    end
end

local function WellFed(buffs)
    wellFedName = wellFedName or C_Spell.GetSpellName(D.WELL_FED[1])
    for _, aura in pairs(buffs) do
        if aura.name == wellFedName then return aura end
    end
end

local function ItemIcon(itemID)
    if D.WEAPON_ICONS[itemID] then return D.WEAPON_ICONS[itemID] end
    local icon = select(ITEM_ICON, C_Item.GetItemInfo(itemID))
    if icon then return icon end
    if not requested[itemID] then
        requested[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return C_Item.GetItemIconByID(itemID)
end

local function FirstCarried(items)
    for _, id in ipairs(items) do
        if C_Item.GetItemCount(id) > 0 then return id end
    end
end

local function Left(aura)
    local expiry = aura.expirationTime
    if Secret(expiry) or not expiry or expiry == 0 then return nil end
    return expiry - GetTime()
end

local function ShowsHere(kind, zone)
    local keys = WHERE[kind]
    local level = math.max(UnitLevel("player"), leveledTo or 0)
    if zone == "none" and S.Get(keys.atMax) and level >= MAX_LEVEL then return false end
    return S.Get(keys[zone] or keys.none)
end

local function Wake(seconds)
    if not wakeAt or seconds < wakeAt then wakeAt = seconds end
end

local function FoodItemIcon(spellID)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id then
                local _, spell = C_Item.GetItemSpell(id)
                if spell == spellID then return C_Item.GetItemIconByID(id) end
            end
        end
    end
end

local function LastUsed()
    return S.Get("buffIconMode") == "last"
end

local function ClassicWeaponIcon(icon)
    for _, id in ipairs(D.WEAPON_ITEMS) do
        if C_Item.GetItemIconByID(id) == icon then return D.WEAPON_ICONS[id] end
    end
end

local function LastIcon(category)
    if not LastUsed() then return nil end
    if category == "food" then return ns.AccountSettings().lastFoodIcon end
    local icons = ns.AccountSettings().lastIcons
    local icon = icons and icons[category]
    if category == "weapon" and icon and not CLASSIC_WEAPON_ICON[icon] then
        icon = ClassicWeaponIcon(icon)
        icons.weapon = icon
    end
    return icon
end

local function Shown(items, last, item)
    if last then
        for _, id in ipairs(items) do
            if C_Item.GetItemCount(id) > 0 and (D.WEAPON_ICONS[id] or C_Item.GetItemIconByID(id)) == last then
                return last, id
            end
        end
        if not item then return last end
    end
    return item and ItemIcon(item), item
end

local function Carried(category)
    local on = S.Get("carriedPicks")[category]
    if on == nil then return S.Get("onlyIfCarried") end
    return on
end

local function Consumable(list, buffs, group, item, icon, last, onlyCarried)
    local aura = Find(buffs, group.auras) or group.wellFed and WellFed(buffs)
    local left = aura and Left(aura)
    local warn = S.Get("consumablesMinutes") * SECONDS
    if aura and not (left and left <= warn) then
        if left then Wake(left - warn) end
        return
    end
    if not item and onlyCarried then return end
    local shown, used = Shown(group.items, last, item)
    list[#list + 1] = { icon = shown or icon, aura = aura, item = used }
end

local function ScanBags()
    carried = {}
    local best, level = {}, UnitLevel("player")
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            local category = id and BUILT_IN[id]
            if id and not category then
                local _, spell = C_Item.GetItemSpell(id)
                category = spell and D.FOOD_SPELLS[spell] and "food"
            end
            local need = category and select(REQUIRED_LEVEL, C_Item.GetItemInfo(id)) or 0
            if category and need <= level then
                local items = carried[category]
                if not items then items = {}; carried[category] = items end
                if not best[category] or need > best[category] then
                    table.insert(items, 1, id)
                    best[category] = need
                else
                    items[#items + 1] = id
                end
            end
        end
    end
    return carried
end

local function CarriedBuiltIn(category, builtIn)
    local items = (carried or ScanBags())[category]
    if not items then return end
    return { items = items, auras = builtIn.auras, wellFed = builtIn.wellFed }, items[1]
end

local function ScrollGroup(items, buffs)
    local auras = D.SCROLL_AURAS[items[1]]
    for _, id in ipairs(items) do
        if not Find(buffs, D.SCROLL_AURAS[id]) then
            auras = D.SCROLL_AURAS[id]
            break
        end
    end
    local same, best, bestNeed = {}, 1, -1
    for _, id in ipairs(items) do
        if D.SCROLL_AURAS[id] == auras then
            same[#same + 1] = id
            local need = select(REQUIRED_LEVEL, C_Item.GetItemInfo(id)) or 0
            if need > bestNeed then best, bestNeed = #same, need end
        end
    end
    same[1], same[best] = same[best], same[1]
    return { items = same, auras = auras }, same[1]
end

local function Consumables(list, buffs)
    for _, category in ipairs(CATEGORY_ORDER) do
        local onlyCarried = Carried(category)
        local builtIn = D.DEFAULT_GROUPS[category]
        local group, item
        if onlyCarried or builtIn.carried then
            group, item = CarriedBuiltIn(category, builtIn)
            if item and category == "scroll" then group, item = ScrollGroup(group.items, buffs) end
        else
            group, item = builtIn, FirstCarried(builtIn.items)
        end
        if group then
            local before = #list
            local icon = group.items[1] and ItemIcon(group.items[1])
            if category == "food" then
                icon = ns.AccountSettings().lastFoodIcon or icon or C_Spell.GetSpellTexture(D.WELL_FED[1])
            end
            Consumable(list, buffs, group, item, icon, LastIcon(category), onlyCarried)
            if #list > before then list[#list].items, list[#list].key = group.items, category end
        end
    end
end

local function Picked(family)
    local on = S.Get("raidBuffPicks")[family.key]
    if on == nil then return family.class ~= "PALADIN" end
    return on
end

local function HideBlessings()
    return S.Get("hideBlessingsOnPaladin") and select(2, UnitClass("player")) == "PALADIN"
        and GetNumGroupMembers() > 0
end

local function Knows(spells)
    for _, id in ipairs(spells) do
        if C_SpellBook.IsSpellKnown(id) then return id end
    end
end

local function AddMember(unit, playerBuffs)
    local _, class = UnitClass(unit)
    if not class or Secret(class) then return end
    classes[class] = true
    if not (UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit)) then return end
    local buffs = UnitIsUnit(unit, "player") and playerBuffs or Buffs(unit)
    if not buffs then return end
    memberCount = memberCount + 1
    local member = members[memberCount]
    if not member then member = {}; members[memberCount] = member end
    member.class, member.buffs, member.unit = class, buffs, unit
end

local function AddGroup(playerBuffs)
    memberCount = 0
    wipe(classes)
    local n = GetNumGroupMembers()
    if IsInRaid() then
        for i = 1, n do AddMember(RAID_UNITS[i] or ("raid" .. i), playerBuffs) end
    else
        AddMember("player", playerBuffs)
        for i = 1, n - 1 do AddMember(PARTY_UNITS_LIST[i] or ("party" .. i), playerBuffs) end
    end
end

local function IsTank(unit)
    local role = UnitGroupRolesAssigned(unit)
    if not Secret(role) and role == "TANK" then return true end
    return GetPartyAssignment("MAINTANK", unit) and true or false
end

local function Missing(family, units)
    local missing, first = 0, nil
    if units then wipe(units) end
    for m = 1, memberCount do
        local member = members[m]
        if not (family.skip and family.skip[member.class]) and not (family.skipTanks and IsTank(member.unit))
            and not Find(member.buffs, family.spells) then
            missing = missing + 1
            first = first or member.unit
            if units then units[missing] = member.unit end
        end
    end
    return missing, first
end

local function RaidBuffs(list, playerBuffs)
    AddGroup(playerBuffs)
    local own = S.Get("raidBuffsOwn")
    local hideBlessings = HideBlessings()
    for _, family in ipairs(D.RAID) do
        local picked = Picked(family) and not (hideBlessings and family.class == "PALADIN")
        local spell = picked and Knows(family.spells)
        if picked and (spell or not (own or family.talent) and classes[family.class]) then
            local units
            if S.Get("raidBuffRange") then
                units = missingUnits[family.key]
                if not units then units = {}; missingUnits[family.key] = units end
            end
            local missing, first = Missing(family, units)
            if missing > 0 then
                list[#list + 1] = { icon = C_Spell.GetSpellTexture(family.spells[1]), key = family,
                    spell = spell or nil, unit = spell and first or nil, count = memberCount > 1 and missing,
                    rangeUnits = units, rangeSpell = units and spell }
            end
        end
    end
    for m = 1, memberCount do members[m].buffs = nil end
end

local function PersonalPicked(family)
    return S.Get("personalBuffPicks")[family.key] ~= false
end

local function Lasts(left, warn, duration)
    if not left or left <= 0 then return true end
    if duration and duration <= warn then warn = 0 end
    if left <= warn then return false end
    Wake(left - warn)
    return true
end

local function SlotEnchanted(weaponSlot, warn)
    for _, enchant in pairs(C_Item.GetWeaponEnchantInfo(weaponSlot)) do
        if enchant.hasEnchant and Lasts(enchant.timeLeft / 1000, warn) then return true end
    end
    return false
end

local function MissingSlot(slots, warn)
    for _, slot in ipairs(slots) do
        if GetInventoryItemID("player", slot) and not SlotEnchanted(slot == 16 and 0 or 1, warn) then
            return slot
        end
    end
end

local function WeaponSlots()
    local slots = {}
    for _, slot in ipairs(WEAPON_SLOTS) do
        local id = GetInventoryItemID("player", slot)
        if id and select(CLASS_INDEX, C_Item.GetItemInfoInstant(id)) == Enum.ItemClass.Weapon then
            slots[#slots + 1] = slot
        end
    end
    return slots
end

local function OwnWeaponBuff(zone)
    if not (S.Get("personalBuffs") and ShowsHere("personalBuffs", zone)) then return false end
    local _, class = UnitClass("player")
    for _, family in ipairs(D.PERSONAL) do
        if family.weapons and family.class == class and PersonalPicked(family) and Knows(family.spells) then
            return true
        end
    end
    return false
end

local function WeaponEnhancement(list, zone)
    if OwnWeaponBuff(zone) then return end
    local slots = WeaponSlots()
    local slot = #slots > 0 and MissingSlot(slots, S.Get("consumablesMinutes") * SECONDS)
    if not slot then return end
    local item = FirstCarried(D.WEAPON_ITEMS)
    if not item and Carried("weapon") then return end
    local shown, used = Shown(D.WEAPON_ITEMS, LastIcon("weapon"), item)
    list[#list + 1] = { icon = shown or D.WEAPON_ICONS[D.WEAPON_ICON_ITEM], items = D.WEAPON_ITEMS,
        item = used, slot = slot, key = "weapon" }
end

local function TargetHas(spells)
    for i = 1, MAX_AURAS do
        local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL")
        if not aura or Secret(aura.spellId) then return aura ~= nil end
        for _, id in ipairs(spells) do
            if aura.spellId == id then return true end
        end
    end
end

local function EliteTarget()
    if not UnitExists("target") or UnitIsDeadOrGhost("target") or not UnitCanAttack("player", "target") then
        return false
    end
    local kind = UnitClassification("target")
    return not Secret(kind) and ELITE[kind] or false
end

local function Has(family, buffs, warn)
    if family.weapons then return MissingSlot(family.weapons, warn) == nil end
    if family.target then return not EliteTarget() or TargetHas(family.spells) end
    local aura = Find(buffs, family.spells, family.own)
    local duration = aura and not Secret(aura.duration) and aura.duration or nil
    return aura and Lasts(Left(aura), warn, duration), aura
end

local function PersonalBuffs(list, buffs)
    if UnitIsDeadOrGhost("player") or S.Get("hideResting") and IsResting() then return end
    local _, class = UnitClass("player")
    local warn = S.Get("consumablesMinutes") * SECONDS
    for _, family in ipairs(D.PERSONAL) do
        local spell = family.class == class and PersonalPicked(family) and Knows(family.spells)
        if spell then
            if family.key == "imbue" and lastImbue and C_SpellBook.IsSpellKnown(lastImbue) then
                spell = lastImbue
            end
            local has, aura = Has(family, buffs, warn)
            if not has then
                local entry = { icon = C_Spell.GetSpellTexture(spell), aura = aura, key = family }
                if family.items then
                    entry.items, entry.item = family.items, FirstCarried(family.items)
                    entry.slot = MissingSlot(family.weapons, warn)
                else
                    entry.spell, entry.unit = spell, family.target and "target" or nil
                end
                list[#list + 1] = entry
            end
        end
    end
end

local Reminders = {}
A.Buffs = Reminders

Reminders.GROUP_UNIT = GROUP_UNIT
Reminders.Carried = Carried
Reminders.Left = Left
Reminders.Picked = Picked
Reminders.PersonalPicked = PersonalPicked
Reminders.Secret = Secret
Reminders.ShowsHere = ShowsHere

function Reminders.WatchesLevel()
    return (S.Get("consumablesMaxHide") or S.Get("raidBuffsMaxHide") or S.Get("personalBuffsMaxHide"))
        and UnitLevel("player") < MAX_LEVEL
end

function Reminders.NoteLevel(level)
    leveledTo = level
end

function Reminders.InRange(entry)
    local count = 0
    if not entry.rangeSpell or InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then return count end
    for _, unit in ipairs(entry.rangeUnits) do
        if UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit) then
            if UnitIsUnit(unit, "player") then
                count = count + 1
            else
                local inRange = C_Spell.IsSpellInRange(entry.rangeSpell, unit)
                if not Secret(inRange) and inRange == true then count = count + 1 end
            end
        end
    end
    return count
end

function Reminders.On()
    return S.Get("enabled")
end

function Reminders.ForgetBags()
    carried = nil
end

function Reminders.WatchesTarget()
    if not S.Get("personalBuffs") then return false end
    local _, class = UnitClass("player")
    for _, family in ipairs(D.PERSONAL) do
        if family.target and family.class == class and PersonalPicked(family) then return true end
    end
    return false
end

function Reminders.WatchesImbue()
    if not S.Get("personalBuffs") then return false end
    local _, class = UnitClass("player")
    for _, family in ipairs(D.PERSONAL) do
        if family.key == "imbue" and family.class == class and PersonalPicked(family) then
            return Knows(family.spells) ~= nil
        end
    end
    return false
end

function Reminders.NoteImbueCast(spellID)
    for _, family in ipairs(D.PERSONAL) do
        if family.key == "imbue" then
            for _, id in ipairs(family.spells) do
                if id == spellID then
                    lastImbue = spellID
                    return true
                end
            end
            return false
        end
    end
    return false
end

function Reminders.NoteFoodCast(spellID)
    if not D.FOOD_SPELLS[spellID] then return false end
    local icon = FoodItemIcon(spellID) or C_Spell.GetSpellTexture(spellID)
    local account = ns.AccountSettings()
    if not icon or account.lastFoodIcon == icon then return false end
    account.lastFoodIcon = icon
    return true
end

local function UsedIcon(items, spellID)
    for _, id in ipairs(items) do
        local _, spell = C_Item.GetItemSpell(id)
        if spell == spellID then return D.WEAPON_ICONS[id] or C_Item.GetItemIconByID(id) end
    end
end

function Reminders.NoteUseCast(spellID)
    if not LastUsed() or InCombatLockdown() then return false end
    local category, icon = "weapon", UsedIcon(D.WEAPON_ITEMS, spellID)
    if not icon then
        for _, name in ipairs(CATEGORY_ORDER) do
            local group = D.DEFAULT_GROUPS[name]
            icon = not group.wellFed and UsedIcon(group.items, spellID)
            if icon then
                category = name
                break
            end
        end
    end
    local account = ns.AccountSettings()
    local icons = account.lastIcons or {}
    if not icon or icons[category] == icon then return false end
    icons[category] = icon
    account.lastIcons = icons
    return true
end

Reminders.ItemIcon = ItemIcon

function Reminders.RaidSample()
    if not S.Get("raidBuffs") then return nil end
    local own = S.Get("raidBuffsOwn")
    local hideBlessings = HideBlessings()
    for _, family in ipairs(D.RAID) do
        if Picked(family) and not (hideBlessings and family.class == "PALADIN")
            and (Knows(family.spells) or not (own or family.talent)) then return family.spells[1] end
    end
end

function Reminders.Requested(itemID)
    return requested[itemID] == true
end

function Reminders.WakeAt()
    return wakeAt
end

function Reminders.Hide(key)
    hidden[key] = true
end

function Reminders.Collect()
    if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then return nil end
    local buffs = Buffs("player")
    if not buffs then return nil end
    local list = {}
    wakeAt = nil
    local _, zone = IsInInstance()
    if ShowsHere("consumables", zone) and not (S.Get("hideResting") and IsResting()) then
        Consumables(list, buffs)
        if S.Get("weaponEnhancements") then WeaponEnhancement(list, zone) end
    end
    if S.Get("personalBuffs") and ShowsHere("personalBuffs", zone) then PersonalBuffs(list, buffs) end
    if S.Get("raidBuffs") and ShowsHere("raidBuffs", zone) then RaidBuffs(list, buffs) end
    for i = #list, 1, -1 do
        if hidden[list[i].key] then table.remove(list, i) end
    end
    return list
end
