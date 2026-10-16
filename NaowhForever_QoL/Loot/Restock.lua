-- Restock.lua: the QoL restock reminder, and buying, selling junk and repairing at a vendor.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local St = ns.Shared.Style
local Parts = ns.Shared.Parts
local Group = ns.Shared.Settings.Group

local FAMILIES = {
    { class = "DRUID", name = "Rebirth", { 20484, 17034 }, { 20739, 17035 }, { 20742, 17036 }, { 20747, 17037 },
      { 20748, 17038 } },
    { class = "DRUID", name = "Gift of the Wild", { 21849, 17021 }, { 21850, 17026 } },
    { class = "MAGE", name = "Arcane Brilliance", { 23028, 17020 } },
    { class = "MAGE", name = "Teleports", { 3561, 17031 }, { 3562, 17031 }, { 3563, 17031 }, { 3565, 17031 },
      { 3566, 17031 }, { 3567, 17031 }, { 1297659, 17031 } },
    { class = "MAGE", name = "Portals", { 10059, 17032 }, { 11416, 17032 }, { 11417, 17032 }, { 11418, 17032 },
      { 11419, 17032 }, { 11420, 17032 } },
    { class = "PALADIN", name = "Divine Intervention", { 19752, 17033 } },
    { class = "PALADIN", name = "Greater Blessings", { 25782, 21177 }, { 25916, 21177 }, { 25890, 21177 },
      { 25894, 21177 }, { 25918, 21177 }, { 25895, 21177 }, { 25898, 21177 } },
    { class = "PRIEST", name = "Prayer of Fortitude", { 21562, 17028 }, { 21564, 17029 } },
    { class = "PRIEST", name = "Prayer of Spirit", { 27681, 17029 } },
    { class = "PRIEST", name = "Prayer of Shadow Protection", { 27683, 17029 } },
    { class = "SHAMAN", name = "Reincarnation", { 20608, 17030 }, { 21169, 17030 }, { 27740, 17030 } },
    { class = "WARLOCK", name = "Ritual of Doom", { 18540, 16583 } },
    { class = "WARLOCK", name = "Inferno", { 1122, 5565 }, { 24670, 5565 } },
    { class = "ROGUE", name = "Vanish", { 1856, 5140 }, { 1857, 5140 }, { 27617, 5140 }, { 457437, 5140 },
      { 1285372, 5140 } },
}

local TARGETS = {
    [17034] = 5, [17035] = 5, [17036] = 5, [17037] = 5, [17038] = 5,
    [17021] = 20, [17026] = 20,
    [17020] = 20, [17031] = 10, [17032] = 10,
    [17033] = 5, [21177] = 100,
    [17028] = 20, [17029] = 20,
    [17030] = 5,
    [16583] = 5, [5565] = 5,
    [5140] = 20,
}

local AMMO_SLOT, RANGED_SLOT = 0, 18
local WEAPON_CLASS, THROWN_SUBCLASS = 2, 16
local THROWN_CLASSES = { ROGUE = true, WARRIOR = true }
local PLAYER_CLASS = select(2, UnitClass("player"))
local FOOD_CLASS, FOOD_SUBCLASS = 0, 5
local DRINK_ITEM = 159
local PLAIN_BAG = ns.QoLConstants.PLAIN_BAG
local MAX_LEVEL = 60
local NO_DRINK = { WARRIOR = true, ROGUE = true }
local TITLE_GROW = 6
local TITLE_SIZE, TEXT_SIZE = 22, 16
local TITLE_TOP, TEXT_GAP = 4, 4
local PAD_W, PAD_H = 16, 12
local FLASH_LOOPS, FLASH_ALPHA, FLASH_TIME = 6, 0.35, 0.6
local STACK_ORDER = 4
local PAGE = "QoL/Loot & Items"
local TEXT_ALERT = "Restock Reminder"
local SETTLE_DELAY = 0.5
local CARRY_MAX = 200
local AMMO_RANGE, FOOD_BELOW_RANGE, FOOD_LEVEL_RANGE = { 50, 4000, 50 }, { 1, 40, 1 }, { 0, MAX_LEVEL, 1 }
local BAGS_BELOW_RANGE, CARRY_RANGE = { 1, 20, 1 }, { 0, CARRY_MAX, 1 }
local TEXT_RANGE = { 10, 32, 1 }
local ITEM_PATTERN = "item:(%d+)"
local CHECKS = { { "restockReagents", "reagents" }, { "restockAmmo", "ammo" }, { "restockFood", ns.L("food & drink") },
    { "restockVendor", ns.L("junk & bags") } }
local SAMPLE = { "Arcane Powder  3 / 20", "Rough Arrow  150 / 1000", ns.L("Junk to sell  6") }
local STAGE_H, STAGE_MARGIN = 200, St.STAGE_MARGIN
local NOTE_Y, NOTE_SIZE, NOTE_LINE = St.STAGE_NOTE_Y, St.STAGE_NOTE_SIZE, 15
local TEXT_ROOM = NOTE_Y + NOTE_LINE
local SAMPLE_REAGENT, SAMPLE_AMMO = 17020, 2512
local SAMPLE_SHARE, SAMPLE_DRINK_SHARE = 0.25, 0.5
local SAMPLE_JUNK = 6

local TEXT_ITEM = ns.L("item ")
local TEXT_TITLE = ns.L("Restock")
local TEXT_SHORT = "%s  %d / %d"
local TEXT_FOOD = ns.L("Food  %d left")
local TEXT_DRINK = ns.L("Drink  %d left")
local TEXT_JUNK = ns.L("Junk to sell  %d")
local TEXT_BAGS = ns.L("Bags nearly full  %d free")
local TEXT_NO_GOLD = ns.L("Not enough gold to repair (")
local TEXT_REPAIRED = ns.L("Repaired for ")
local TEXT_RESTOCKED = ns.L("Restocked ")
local TEXT_FOR = ns.L(" for ")
local TEXT_BOUGHT = "x "
local CARRY_HELP = ns.L("How many to carry. 0 stops reminding you about it.")
local TEXT_NOTHING = ns.L("Nothing to check")
local TEXT_BUYS = ns.L("; buys at vendors")
local TEXT_STOCKED = "Nothing shows while you carry what you need."
local TEXT_HUNTER_OFF = "Turn on Hunter Ammo Reminder below to get it."

local alert, flash
local wasResting
local pendingItems = {}
local restockRows, reagentRows, seenReagents = {}, {}, {}
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("restock")
end

local function HunterAmmoOn()
    return PLAYER_CLASS == "HUNTER" and S.Get("restockHunterAmmo")
end

local function ItemName(itemID)
    return C_Item.GetItemNameByID(itemID) or (TEXT_ITEM .. itemID)
end

local function Target(itemID)
    return S.Get("restockTarget" .. itemID) or TARGETS[itemID]
end

local function KnownReagent(family)
    local item
    for _, rank in ipairs(family) do
        if C_SpellBook.IsSpellKnown(rank[1]) then item = rank[2] end
    end
    return item
end

local function RequestItem(itemID)
    if pendingItems[itemID] then return end
    pendingItems[itemID] = true
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    C_Item.RequestLoadItemDataByID(itemID)
end

local function CarriedAmmo()
    if THROWN_CLASSES[PLAYER_CLASS] then
        local item = GetInventoryItemID("player", RANGED_SLOT)
        if item then
            local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item)
            if classID == WEAPON_CLASS and subclassID == THROWN_SUBCLASS then
                local _, _, _, _, _, _, _, stackSize = C_Item.GetItemInfo(item)
                if not stackSize then RequestItem(item); return end
                if stackSize > 1 then return item end
                return
            end
        end
    end
    return GetInventoryItemID("player", AMMO_SLOT)
end

local function Wanted()
    local want = {}
    if S.Get("restockReagents") then
        for _, family in ipairs(FAMILIES) do
            local item = KnownReagent(family)
            if item and Target(item) > 0 then want[item] = Target(item) end
        end
    end
    local ammo = S.Get("restockAmmo") and CarriedAmmo()
    if ammo and ammo > 0 then want[ammo] = S.Get("restockAmmoTarget") end
    return want
end

local function FoodLevel(itemID)
    local _, _, _, _, level = C_Item.GetItemInfo(itemID)
    if level then return level end
    RequestItem(itemID)
end

local function InLevelRange(level)
    return level >= (S.Get("restockFoodMinLevel") or 0) and level <= (S.Get("restockFoodMaxLevel") or MAX_LEVEL)
end

local function IsFood(itemID)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return classID == FOOD_CLASS and subclassID == FOOD_SUBCLASS
end

local function ScanBags()
    local food, drink, junk, free = 0, 0, 0, 0
    local drinkSpell = C_Item.GetItemSpell(DRINK_ITEM)
    for bag = 0, NUM_BAG_SLOTS do
        local slots, bagType = C_Container.GetContainerNumFreeSlots(bag)
        if bagType == PLAIN_BAG then free = free + slots end
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                if info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                    junk = junk + 1
                end
                local level = IsFood(info.itemID) and FoodLevel(info.itemID)
                if level and InLevelRange(level) then
                    if drinkSpell and C_Item.GetItemSpell(info.itemID) == drinkSpell then
                        drink = drink + info.stackCount
                    else
                        food = food + info.stackCount
                    end
                end
            end
        end
    end
    return food, junk, free, drink
end

local function ReagentLines(lines)
    for itemID, target in pairs(Wanted()) do
        local have = C_Item.GetItemCount(itemID)
        local hunterAmmo = HunterAmmoOn() and itemID == GetInventoryItemID("player", AMMO_SLOT)
        if not hunterAmmo and have < target then
            lines[#lines + 1] = TEXT_SHORT:format(ItemName(itemID), have, target)
        end
    end
    table.sort(lines)
end

local function HunterAmmoLines(lines)
    if not HunterAmmoOn() then return end
    local ammo = GetInventoryItemID("player", AMMO_SLOT)
    if not ammo or ammo <= 0 then return end
    local have = C_Item.GetItemCount(ammo)
    local below = S.Get("restockHunterAmmoBelow")
    if have <= below then
        lines[#lines + 1] = TEXT_SHORT:format(ItemName(ammo), have, below)
    end
end

local function BagLines(lines)
    local food, junk, free, drink = ScanBags()
    local below = S.Get("restockFoodBelow")
    if S.Get("restockFood") and food < below then
        lines[#lines + 1] = TEXT_FOOD:format(food)
    end
    local class = select(2, UnitClass("player"))
    if S.Get("restockFood") and not NO_DRINK[class] and drink < below then
        lines[#lines + 1] = TEXT_DRINK:format(drink)
    end
    if not S.Get("restockVendor") then return end
    if junk > 0 then lines[#lines + 1] = TEXT_JUNK:format(junk) end
    if free < S.Get("restockBagsBelow") then
        lines[#lines + 1] = TEXT_BAGS:format(free)
    end
end

local function Lines()
    local lines = {}
    ReagentLines(lines)
    HunterAmmoLines(lines)
    BagLines(lines)
    return lines
end

local function OnFlashLoop(self)
    self.loops = self.loops + 1
    if self.loops >= FLASH_LOOPS then self:Stop() end
end

local function NewView(view)
    view.title = ns.Font(view, TITLE_SIZE, "OUTLINE", T.accent)
    view.title:SetPoint("TOP", 0, -TITLE_TOP)
    view.title:SetText(TEXT_TITLE)
    view.text = ns.Font(view, TEXT_SIZE, "OUTLINE")
    view.text:SetPoint("TOP", view.title, "BOTTOM", 0, -TEXT_GAP)
    view.text:SetJustifyH("CENTER")
    view.backdrop = Parts.HudBackdrop(view, { mode = "none" })
    return view
end

local function Restyle(view)
    local font, size, outline = S.Get("restockFont"), S.Get("restockFontSize"), S.Get("restockOutline")
    local mode = view.backdrop:SetMode(S.Get("restockBackground"))
    Parts.HudFont(view.title, font, size + TITLE_GROW, outline, mode)
    Parts.HudFont(view.text, font, size, outline, mode)
end

local function Fill(view, lines)
    Restyle(view)
    view.text:SetText(table.concat(lines, "\n"))
    view:SetSize(math.max(view.title:GetStringWidth(), view.text:GetStringWidth()) + PAD_W,
        view.title:GetStringHeight() + view.text:GetStringHeight() + PAD_H)
end

local function BuildAlert()
    alert = NewView(CreateFrame("Frame", "NaowhForeverRestock", UIParent))
    alert:SetMovable(true)
    alert:SetClampedToScreen(true)

    flash = alert:CreateAnimationGroup()
    flash:SetLooping("BOUNCE")
    flash:SetScript("OnLoop", OnFlashLoop)
    local pulse = flash:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(FLASH_ALPHA)
    pulse:SetDuration(FLASH_TIME)

    alert:Hide()
    ns.AlertStack(alert, STACK_ORDER, TEXT_ALERT, PAGE, PAGE .. ":restock")
end

local function HideAlert()
    if alert then
        flash:Stop()
        alert:Hide()
    end
end

local function ShowAlert(lines)
    if not alert then BuildAlert() end
    Fill(alert, lines)
    if not alert:IsShown() then
        alert:Show()
        flash.loops = 0
        flash:Play()
    end
end

local function Check()
    if not On() or not IsResting() or InCombatLockdown() or IsInInstance()
        or (MerchantFrame and MerchantFrame:IsShown()) then
        HideAlert()
        return
    end
    local lines = Lines()
    if #lines > 0 then ShowAlert(lines) else HideAlert() end
end

local function Repair()
    if not (S.Get("autoRepair") and CanMerchantRepair()) then return 0 end
    local cost, canRepair = GetRepairAllCost()
    if not (canRepair and cost > 0) then return 0 end
    if GetMoney() < cost then
        ns.Print(TEXT_NO_GOLD .. C_CurrencyInfo.GetCoinTextureString(cost) .. ").")
        return 0
    end
    RepairAllItems()
    ns.Print(TEXT_REPAIRED .. C_CurrencyInfo.GetCoinTextureString(cost))
    return cost
end

local function SellJunk()
    if S.Get("sellJunk") and C_MerchantFrame.IsSellAllJunkEnabled()
        and C_MerchantFrame.GetNumJunkItems() > 0 then
        C_MerchantFrame.SellAllJunkItems()
    end
end

local function Bundles(index, itemID, target, info, money)
    local bundle = math.max(info.stackCount, 1)
    local bundles = math.ceil((target - C_Item.GetItemCount(itemID)) / bundle)
    if info.numAvailable and info.numAvailable >= 0 then
        bundles = math.min(bundles, info.numAvailable)
    end
    if info.price > 0 then bundles = math.min(bundles, math.floor(money / info.price)) end
    return bundles, bundle, math.max(math.floor(GetMerchantItemMaxStack(index) / bundle), 1)
end

local function BuyBundles(index, bundles, bundle, perBuy)
    local left = bundles
    while left > 0 do
        local take = math.min(left, perBuy)
        BuyMerchantItem(index, take * bundle)
        left = left - take
    end
end

local function Buy(alreadySpent)
    if not S.Get("restockBuy") then return end
    local want = Wanted()
    local money = GetMoney() - alreadySpent
    local spent, bought = 0, {}
    for index = 1, GetMerchantNumItems() do
        local itemID = tonumber((GetMerchantItemLink(index) or ""):match(ITEM_PATTERN))
        local target = itemID and want[itemID]
        local info = target and C_MerchantFrame.GetItemInfo(index)
        if info and info.isPurchasable and not info.hasExtendedCost then
            local bundles, bundle, perBuy = Bundles(index, itemID, target, info, money)
            if bundles > 0 then
                BuyBundles(index, bundles, bundle, perBuy)
                money = money - bundles * info.price
                spent = spent + bundles * info.price
                bought[#bought + 1] = bundles * bundle .. TEXT_BOUGHT .. ItemName(itemID)
            end
        end
    end
    if #bought > 0 then
        ns.Print(TEXT_RESTOCKED .. table.concat(bought, ", ") .. TEXT_FOR
            .. C_CurrencyInfo.GetCoinTextureString(math.floor(spent)))
    end
end

local function OnMerchantShow()
    HideAlert()
    SellJunk()
    local spent = Repair()
    if On() then Buy(spent) end
end

local function OnRestingChanged()
    local resting = IsResting()
    if resting and not wasResting then Check() end
    if not resting then HideAlert() end
    wasResting = resting
end

local function OnEvent(_, event, itemID)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not pendingItems[itemID] then return end
        pendingItems[itemID] = nil
        if not next(pendingItems) then events:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end
    end
    if event == "MERCHANT_SHOW" then
        OnMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
        C_Timer.After(SETTLE_DELAY, Check)
    elseif event == "PLAYER_REGEN_DISABLED" then
        HideAlert()
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_REGEN_ENABLED"
        or event == "GET_ITEM_INFO_RECEIVED" or event == "UNIT_INVENTORY_CHANGED" then
        Check()
    else
        OnRestingChanged()
    end
end

local function Apply()
    events:UnregisterAllEvents()
    if S.Get("enabled") and (S.Get("restock") or S.Get("autoRepair") or S.Get("sellJunk")) then
        events:RegisterEvent("MERCHANT_SHOW")
    end
    if not On() then
        HideAlert()
        return
    end
    for itemID in pairs(TARGETS) do C_Item.RequestLoadItemDataByID(itemID) end
    events:RegisterEvent("PLAYER_UPDATE_RESTING")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("MERCHANT_CLOSED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    if S.Get("restockAmmo") or HunterAmmoOn() then
        events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    end
    pendingItems[DRINK_ITEM] = true
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    C_Item.RequestLoadItemDataByID(DRINK_ITEM)
    wasResting = IsResting()
    Check()
end

local function ShowSample()
    if not On() then return end
    ShowAlert(SAMPLE)
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "sellJunk" or key == "autoRepair"
        or key:find("^restock") then
        Apply()
    end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", ShowSample)
hooksecurefunc(ns, "HideUnlockMode", HideAlert)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local loot = ns.Shared.Settings.Page(PAGE, S)

loot:Card({
    id = "vendors", name = "Vendors", order = 20, into = "lootTrade",
    rows = {
        { key = "autoRepair", label = "Auto Repair", toggle = true,
          help = "Repairs all gear when you open a vendor who can." },
        { key = "sellJunk", label = "Auto Sell Junk", toggle = true,
          help = "Sells grey items when you open a vendor." },
    },
})

local FIXED = {
    Group("Class Reagents"),
    { key = "restockReagents", label = "Class Reagents", toggle = true,
      help = "The reagents your known spells use, such as Arcane Powder, candles, seeds, Symbols "
          .. "of Kings and Flash Powder, matched to the highest rank you know." },
    { key = "restockBuy", label = "Buy at Vendors", toggle = true,
      help = "At a vendor who sells them, tops your class reagents and ammo up to what you carry, "
          .. "and prints what it spent. Off by default: it spends gold for you." },
}
local AMMO = {
    { key = "restockAmmo", label = "Ammo", toggle = true,
      help = "Restocks equipped thrown weapons, or the arrows or shot in your ammo slot." },
    { key = "restockAmmoTarget", label = "Ammo to Carry", slider = AMMO_RANGE, needs = "restockAmmo" },
}
local OTHER = {
    Group("Food & Drink"),
    { key = "restockFood", label = "Food & Drink", toggle = true,
      help = "Counts food and drink separately across all stacks. Warriors and rogues do not need drink." },
    { key = "restockFoodBelow", label = "Food & Drink Below", slider = FOOD_BELOW_RANGE, needs = "restockFood" },
    { key = "restockFoodMinLevel", label = "Food Minimum Required Level", slider = FOOD_LEVEL_RANGE, needs = "restockFood",
      help = "Only count food and drink whose required level is within this range." },
    { key = "restockFoodMaxLevel", label = "Food Maximum Required Level", slider = FOOD_LEVEL_RANGE, needs = "restockFood",
      help = "The same required-level filter applies to every stack, not each item separately." },
    Group("Bags"),
    { key = "restockVendor", label = "Junk & Full Bags", toggle = true,
      help = "Reminds you to vendor junk, and when your bags are nearly full." },
    { key = "restockBagsBelow", label = "Free Slots Below", slider = BAGS_BELOW_RANGE, needs = "restockVendor" },
}
local HUNTER = {
    { key = "restockHunterAmmo", label = "Hunter Ammo Reminder", toggle = true,
      help = "Reminds you about your equipped ammo at its own amount, not the carry target." },
    { key = "restockHunterAmmoBelow", label = "Remind Me When Ammo Falls To", slider = AMMO_RANGE,
      needs = "restockHunterAmmo",
      help = "Reminds at or below this many equipped arrows or shot across all bag stacks." },
}
local CARRY_GROUP = Group("Reagents to Carry")
local LOOK = ns.Shared.Settings.Look("restock", { text = true, size = TEXT_RANGE, background = "card" })

local function ReagentRow(item)
    local row = reagentRows[item]
    if not row then
        local key = "restockTarget" .. item
        row = { key = key, slider = CARRY_RANGE, help = CARRY_HELP, needs = "restockReagents",
            get = function() return Target(item) end,
            set = function(v) S.Set(key, v) end }
        reagentRows[item] = row
    end
    row.label = ItemName(item)
    return row
end

local function AddReagentRows(family, grouped)
    for _, rank in ipairs(family) do
        local item = rank[2]
        if not seenReagents[item] then
            seenReagents[item] = true
            if not grouped then
                restockRows[#restockRows + 1] = CARRY_GROUP
                grouped = true
            end
            restockRows[#restockRows + 1] = ReagentRow(item)
        end
    end
    return grouped
end

local function ClassName(class)
    return C_ClassColor.GetClassColor(class):WrapTextInColorCode(LOCALIZED_CLASS_NAMES_MALE[class])
end

local function RestockRows()
    wipe(restockRows)
    wipe(seenReagents)
    for i = 1, #FIXED do restockRows[i] = FIXED[i] end
    local class = select(2, UnitClass("player"))
    local grouped = false
    for _, family in ipairs(FAMILIES) do
        if family.class == class then grouped = AddReagentRows(family, grouped) end
    end
    restockRows[#restockRows + 1] = Group(ns.L("Ammo: %s and %s", ClassName("ROGUE"), ClassName("WARRIOR")))
    for _, row in ipairs(AMMO) do restockRows[#restockRows + 1] = row end
    restockRows[#restockRows + 1] = Group(ns.L("Ammo: %s", ClassName("HUNTER")))
    for _, row in ipairs(HUNTER) do restockRows[#restockRows + 1] = row end
    for _, row in ipairs(OTHER) do restockRows[#restockRows + 1] = row end
    restockRows[#restockRows + 1] = LOOK
    return restockRows
end

local function RestockSummary(store)
    local text
    for _, pair in ipairs(CHECKS) do
        if store.Get(pair[1]) then text = text and (text .. ", " .. pair[2]) or pair[2] end
    end
    if HunterAmmoOn() then
        local hunter = ns.L("Hunter Ammo")
        text = text and (text .. ", " .. hunter) or hunter
    end
    if not text then return TEXT_NOTHING end
    text = text:sub(1, 1):upper() .. text:sub(2)
    return store.Get("restockBuy") and (text .. TEXT_BUYS) or text
end

local STATES = {
    { key = "low", label = "Running Low", tip = "What you are short on when you reach a city or inn." },
    { key = "hunter", label = "Hunter Ammo", tip = "Only your equipped ammo, at or below its own amount." },
    { key = "stocked", label = "All Stocked", tip = TEXT_STOCKED },
}

local function SampleReagent()
    local own
    for _, family in ipairs(FAMILIES) do
        if family.class == PLAYER_CLASS then
            own = true
            local item = family[1][2]
            if Target(item) > 0 then return item end
        end
    end
    if not own then return SAMPLE_REAGENT end
end

local function AddShort(lines, item, target)
    lines[#lines + 1] = TEXT_SHORT:format(ItemName(item), math.floor(target * SAMPLE_SHARE), target)
end

local function SampleCarried(lines)
    local reagent = S.Get("restockReagents") and SampleReagent()
    if reagent then AddShort(lines, reagent, Target(reagent)) end
    if S.Get("restockAmmo") and not HunterAmmoOn() then
        AddShort(lines, SAMPLE_AMMO, S.Get("restockAmmoTarget"))
    end
    table.sort(lines)
end

local function SampleBags(lines)
    if S.Get("restockFood") then
        local below = S.Get("restockFoodBelow")
        lines[#lines + 1] = TEXT_FOOD:format(math.floor(below * SAMPLE_SHARE))
        if not NO_DRINK[PLAYER_CLASS] then
            lines[#lines + 1] = TEXT_DRINK:format(math.floor(below * SAMPLE_DRINK_SHARE))
        end
    end
    if not S.Get("restockVendor") then return end
    lines[#lines + 1] = TEXT_JUNK:format(SAMPLE_JUNK)
    lines[#lines + 1] = TEXT_BAGS:format(S.Get("restockBagsBelow") - 1)
end

local function SampleLines(lines, state)
    wipe(lines)
    if state == "stocked" then return lines end
    if state == "low" then SampleCarried(lines) end
    if state == "hunter" or (state == "low" and HunterAmmoOn()) then
        AddShort(lines, SAMPLE_AMMO, S.Get("restockHunterAmmoBelow"))
    end
    if state == "low" then SampleBags(lines) end
    return lines
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.view = NewView(CreateFrame("Frame", nil, preview))
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y)
    preview.lines = {}
    C_Item.RequestLoadItemDataByID(SAMPLE_AMMO)
    for itemID in pairs(TARGETS) do C_Item.RequestLoadItemDataByID(itemID) end
    return preview
end

local function Fit(preview)
    local view = preview.view
    local w, h = view:GetWidth(), view:GetHeight()
    local roomW = preview:GetWidth() - STAGE_MARGIN * 2
    local roomH = preview:GetHeight() - STAGE_MARGIN * 2 - TEXT_ROOM
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h * scale > roomH then scale = roomH / h end
    view:SetScale(scale)
    view:ClearAllPoints()
    view:SetPoint("CENTER", preview, "CENTER", 0, TEXT_ROOM / 2 / scale)
end

local function PaintPreview(preview, state)
    local lines = SampleLines(preview.lines, state)
    local shown = #lines > 0
    preview.view:SetShown(shown)
    local hunterOff = state == "hunter" and not S.Get("restockHunterAmmo")
    preview.note:SetText(state == "stocked" and ns.L(TEXT_STOCKED) or hunterOff and ns.L(TEXT_HUNTER_OFF)
        or not shown and TEXT_NOTHING or "")
    if not shown then return end
    Fill(preview.view, lines)
    Fit(preview)
end

loot:Card({
    id = "restock", name = "Restock Reminder", order = 50, switch = "restock",
    help = "When you reach a city or inn, a flashing list in the middle of the screen of what "
        .. "you are short on. It stays up until you have what you need or leave. Move it "
        .. "in the HUD Editor.",
    summary = RestockSummary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = RestockRows,
})
