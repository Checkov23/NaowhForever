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
local INSTANCE_ID = 8
local ELITE = { elite = true, rareelite = true, worldboss = true }

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
local itemBuffs, requested = {}, {}
local carried
local wellFedName
local wakeAt
local lastImbue

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

local function ItemBuff(itemID)
    if not itemBuffs[itemID] then
        local _, spell = C_Item.GetItemSpell(itemID)
        if spell then
            itemBuffs[itemID] = spell
        elseif not requested[itemID] then
            requested[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
    return itemBuffs[itemID]
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

local function ConsumablesHere()
    if S.Get("hideResting") and IsResting() then return false end
    local where = S.Get("consumablesWhere")
    if where == "always" then return true end
    local _, kind = IsInInstance()
    return kind == "raid" or (where == "instance" and kind == "party")
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

local function Groups()
    local groups = {}
    for _, entry in ipairs(S.Get("consumableEntries") or {}) do
        if type(entry) == "table" and type(entry.itemID) == "number" then
            local group = groups[entry.category]
            if not group then group = { items = {}, auras = {} }; groups[entry.category] = group end
            group.items[#group.items + 1] = entry.itemID
            if type(entry.auras) == "table" then
                for _, id in ipairs(entry.auras) do group.auras[#group.auras + 1] = id end
            elseif entry.category == "food" then
                group.wellFed = true
            else
                group.auras[#group.auras + 1] = ItemBuff(entry.itemID)
            end
        end
    end
    return groups
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

local function CarriedBuiltIn(category, group, builtIn)
    local items = (carried or ScanBags())[category]
    if not items then return group end
    local auras = builtIn.auras
    if group then
        auras = {}
        for _, id in ipairs(group.auras) do auras[#auras + 1] = id end
        for _, id in ipairs(builtIn.auras) do auras[#auras + 1] = id end
    end
    return { items = items, auras = auras, wellFed = builtIn.wellFed or group and group.wellFed }, items[1]
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
    local groups = Groups()
    for _, category in ipairs(CATEGORY_ORDER) do
        local onlyCarried = Carried(category)
        local group = groups[category]
        local builtIn = not (category == "battle" and groups.guardian) and D.DEFAULT_GROUPS[category]
        if group and builtIn and builtIn.carried then builtIn = nil end
        local carriedOnly = onlyCarried or builtIn and builtIn.carried
        if not (group or carriedOnly) then group = builtIn end
        local item = group and FirstCarried(group.items)
        if not item and carriedOnly and builtIn then
            group, item = CarriedBuiltIn(category, group, builtIn)
            if item and category == "scroll" then group, item = ScrollGroup(group.items, buffs) end
        end
        if group then
            local before = #list
            local icon = group.items[1] and ItemIcon(group.items[1])
            if category == "food" then
                icon = ns.AccountSettings().lastFoodIcon or icon or C_Spell.GetSpellTexture(D.WELL_FED[1])
            end
            Consumable(list, buffs, group, item, icon, LastIcon(category), onlyCarried)
            if #list > before then list[#list].items = group.items end
        end
    end
end

local function Picked(family)
    local on = S.Get("raidBuffPicks")[family.key]
    if on == nil then return family.class ~= "PALADIN" end
    return on
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
    member.class, member.buffs = class, buffs
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

local function Missing(family)
    local missing = 0
    for m = 1, memberCount do
        local member = members[m]
        if not (family.skip and family.skip[member.class]) and not Find(member.buffs, family.spells) then
            missing = missing + 1
        end
    end
    return missing
end

local function RaidBuffs(list, playerBuffs)
    AddGroup(playerBuffs)
    local own = S.Get("raidBuffsOwn")
    for _, family in ipairs(D.RAID) do
        if Picked(family) and (Knows(family.spells) or not (own or family.talent) and classes[family.class]) then
            local missing = Missing(family)
            if missing > 0 then
                list[#list + 1] = { icon = C_Spell.GetSpellTexture(family.spells[1]),
                    count = memberCount > 1 and missing }
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

local function Enchanted(slots, warn)
    for _, slot in ipairs(slots) do
        if GetInventoryItemID("player", slot) and not SlotEnchanted(slot == 16 and 0 or 1, warn) then
            return false
        end
    end
    return true
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

local function OwnWeaponBuff()
    if not S.Get("personalBuffs") then return false end
    local _, class = UnitClass("player")
    for _, family in ipairs(D.PERSONAL) do
        if family.weapons and family.class == class and PersonalPicked(family) and Knows(family.spells) then
            return true
        end
    end
    return false
end

local function WeaponEnhancement(list)
    if OwnWeaponBuff() then return end
    local slots = WeaponSlots()
    if #slots == 0 or Enchanted(slots, S.Get("consumablesMinutes") * SECONDS) then return end
    local item = FirstCarried(D.WEAPON_ITEMS)
    if not item and Carried("weapon") then return end
    local shown, used = Shown(D.WEAPON_ITEMS, LastIcon("weapon"), item)
    list[#list + 1] = { icon = shown or D.WEAPON_ICONS[D.WEAPON_ICON_ITEM], items = D.WEAPON_ITEMS,
        item = used }
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
    if family.weapons then return Enchanted(family.weapons, warn) end
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
            if not has then list[#list + 1] = { icon = C_Spell.GetSpellTexture(spell), aura = aura } end
        end
    end
end

local function Worn(list)
    local here = select(INSTANCE_ID, GetInstanceInfo())
    for _, worn in ipairs(D.WORN) do
        if worn.instance == here and GetInventoryItemID("player", worn.slot) == worn.item then
            list[#list + 1] = { icon = C_Item.GetItemIconByID(worn.item), slot = worn.slot }
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
        local groups = Groups()
        for _, name in ipairs(CATEGORY_ORDER) do
            local group = groups[name] or not (name == "battle" and groups.guardian) and D.DEFAULT_GROUPS[name]
            icon = group and not group.wellFed and UsedIcon(group.items, spellID)
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
    for _, family in ipairs(D.RAID) do
        if Picked(family) and (Knows(family.spells) or not (own or family.talent)) then return family.spells[1] end
    end
end

function Reminders.Requested(itemID)
    return requested[itemID] == true
end

function Reminders.WakeAt()
    return wakeAt
end

function Reminders.Collect()
    if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then return nil end
    local buffs = Buffs("player")
    if not buffs then return nil end
    local list = {}
    wakeAt = nil
    if ConsumablesHere() then
        Consumables(list, buffs)
        if S.Get("weaponEnhancements") then WeaponEnhancement(list) end
    end
    if S.Get("personalBuffs") then PersonalBuffs(list, buffs) end
    if S.Get("raidBuffs") then RaidBuffs(list, buffs) end
    if S.Get("wornReminders") then Worn(list) end
    return list
end
