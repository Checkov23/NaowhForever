-- ScrapMarker.lua: the QoL Scrap Marker (ns.ScrapMarker): scrap marks and rules, sold at the next vendor.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Shared = ns.Shared
local Bags, Parts, St, View = Shared.Bags, Shared.Parts, Shared.Style, Shared.View

local GetContainerItemID = C_Container.GetContainerItemID
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerItemLink = C_Container.GetContainerItemLink
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local OVERLAY = "NaowhForeverScrap"
local MARK_SHARE, MARK_MIN = 0.5, 14
local MARK_IN = Parts.MARK_IN
local MARK_LEVEL = 5
local RULE_ALPHA = 0.55
local BATCH = 6
local STEP_DELAY = 0.25
local WEAPON, ARMOR, QUEST_CLASS, KEY_CLASS = 2, 4, 12, 13
local MARKED, RULED = 1, 2
local SELL_PRICE = ns.QoLConstants.SELL_PRICE
local POOR, COMMON = 0, 1
local ROUND = ns.QoLConstants.ROUND
local LEVELS_RANGE = { 5, 30, 1 }
local EMPTY = {}
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local BAGANATOR_CORNER = { corner = "top_right", priority = 1 }

local FOR_ALL = {
    [WEAPON] = { [14] = true, [20] = true },
    [ARMOR] = { [0] = true, [1] = true, [5] = true, [10] = true, [11] = true },
}
local CAN_WEAR = {
    WARRIOR = { [WEAPON] = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true,
        [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [16] = true, [18] = true },
        [ARMOR] = { [2] = true, [3] = true, [4] = true, [6] = true } },
    PALADIN = { [WEAPON] = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
        [ARMOR] = { [2] = true, [3] = true, [4] = true, [6] = true, [7] = true } },
    HUNTER = { [WEAPON] = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true,
        [10] = true, [13] = true, [15] = true, [16] = true, [18] = true },
        [ARMOR] = { [2] = true, [3] = true } },
    ROGUE = { [WEAPON] = { [2] = true, [3] = true, [4] = true, [7] = true, [13] = true, [15] = true, [16] = true,
        [18] = true },
        [ARMOR] = { [2] = true } },
    PRIEST = { [WEAPON] = { [4] = true, [10] = true, [15] = true, [19] = true }, [ARMOR] = {} },
    SHAMAN = { [WEAPON] = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
        [ARMOR] = { [2] = true, [3] = true, [6] = true, [9] = true } },
    MAGE = { [WEAPON] = { [7] = true, [10] = true, [15] = true, [19] = true }, [ARMOR] = {} },
    WARLOCK = { [WEAPON] = { [7] = true, [10] = true, [15] = true, [19] = true }, [ARMOR] = {} },
    DRUID = { [WEAPON] = { [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
        [ARMOR] = { [2] = true, [8] = true } },
}
local NEVER_RULED = { [""] = true, INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true,
    INVTYPE_QUIVER = true, INVTYPE_NON_EQUIP_IGNORE = true }

local RULE_WEAR, RULE_OLD = ns.L("Can't wear"), ns.L("Outlevelled")
local TIPS = {
    sell = { ns.L("Scrap: sold at the next vendor"), ns.L("Scrap by rule: sold at the next vendor") },
    ask = { ns.L("Scrap: offered at the next vendor"), ns.L("Scrap by rule: offered at the next vendor") },
    none = { ns.L("Scrap"), ns.L("Scrap by rule") },
}
local NOT_SCRAP = {
    quest = ns.L(" is a quest item, so it can't be scrap."),
    key = " is a key, so it can't be scrap.",
    value = ns.L(" has no sell price, so it can't be scrap."),
    bis = ns.L(" is on your BiS list, so it can't be scrap."),
    set = ns.L(" is in a gear set, so it can't be scrap."),
}
local VENDOR = { { sell = "Sell", ask = "Ask First", none = "Nothing" }, { "sell", "ask", "none" } }
local SCOPE = { { account = "Account", char = "This Character" }, { "account", "char" } }

local TEXT_ITEM = ns.L("item ")
local TEXT_MARKED = ns.L(" marked as scrap.")
local TEXT_UNMARKED = ns.L(" is no longer scrap.")
local TEXT_SOLD_ONE, TEXT_SOLD = ns.L("Sold %d scrap item for %s."), ns.L("Sold %d scrap items for %s.")
local TEXT_KEPT = ns.L(" Kept %d protected.")
local TEXT_KEPT_ALL_ONE = ns.L("Kept %d protected scrap item from the vendor.")
local TEXT_KEPT_ALL = ns.L("Kept %d protected scrap items from the vendor.")
local TEXT_COUNT = "x"
local TEXT_SELL, TEXT_NOT_NOW = "Sell", "Not Now"
local TEXT_ASK = ns.L("Sell your scrap for %s?")
local TEXT_SUMMARY_ONE, TEXT_SUMMARY = ns.L("%d item marked"), ns.L("%d items marked")
local TEXT_IN_BAGS = ns.L(" in your bags")
local TEXT_BAGANATOR = "Naowh Forever Scrap"

local marks, hooked, bagOf, slotOf = {}, {}, {}, {}
local installed, registered, events = false, false, nil
local baganator
local owners = {}
local atMerchant, offerPending = false, false
local selling, generation, scheduledFor, pending = false, 0, 0, false
local nextBag, nextSlot, sold, earned, spared = 0, 1, 0, 0, 0
local showMark = true
local setItems, setsDirty, watchingSets = {}, true, false
local guid, class
local listeners = {}
local askIDs, askCount, askValue = {}, {}, {}
local countTexts = {}
local AskPanel, Toggle, Step

local Scrap = {}
ns.ScrapMarker = Scrap

local function On()
    return S.Get("enabled") and S.Get("scrapMarker") == true
end
Scrap.On = On

local function SellPrice(id)
    return select(SELL_PRICE, GetItemInfo(id))
end

local function Me()
    guid = guid or UnitGUID("player")
    return guid
end

local function AccountMarks()
    return ns.AccountSettings().scrapItems or EMPTY
end

local function CharMarks()
    local chars, me = ns.AccountSettings().scrapChars, Me()
    return chars and me and chars[me] or EMPTY
end

local function Kept()
    return ns.AccountSettings().scrapKeep or EMPTY
end

local function Writable(key)
    local account = ns.AccountSettings()
    account[key] = account[key] or {}
    return account[key]
end

local function WritableChar()
    local chars, me = Writable("scrapChars"), Me()
    chars[me] = chars[me] or {}
    return chars[me]
end

local function RebuildSets()
    setsDirty = watchingSets == false
    wipe(setItems)
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local ids = C_EquipmentSet.GetItemIDs(setID)
        if ids then
            for _, itemID in pairs(ids) do
                if type(itemID) == "number" and itemID > 0 then setItems[itemID] = true end
            end
        end
    end
end

local function Protection(id)
    if not S.Get("scrapMarkerProtect") then return nil end
    if setsDirty then RebuildSets() end
    if setItems[id] then return "set" end
    if ns.IsBisItem and ns.IsBisItem(id) then return "bis" end
end

local function CanWear(classID, sub)
    if FOR_ALL[classID][sub] then return true end
    class = class or select(2, UnitClass("player"))
    local own = CAN_WEAR[class]
    return own == nil or own[classID][sub] == true
end

local function RuleMatch(id)
    local wear, old = S.Get("scrapRuleWear"), S.Get("scrapRuleOld")
    if not (wear or old) or Kept()[id] then return nil end
    local _, _, _, equipLoc, _, classID, sub = GetItemInfoInstant(id)
    if (classID ~= WEAPON and classID ~= ARMOR) or NEVER_RULED[equipLoc or ""] then return nil end
    local name, _, quality, itemLevel, minLevel, _, _, _, _, _, price = GetItemInfo(id)
    if not name or not price or price == 0 or Protection(id) then return nil end
    if wear and not CanWear(classID, sub) then return RULE_WEAR end
    if old and quality and quality <= COMMON then
        local needs = (minLevel and minLevel > 0) and minLevel or itemLevel or 0
        if UnitLevel("player") - needs > S.Get("scrapRuleLevels") then return RULE_OLD end
    end
end
Scrap.RuleMatch = RuleMatch

local function State(id)
    if AccountMarks()[id] or CharMarks()[id] then return MARKED end
    if RuleMatch(id) then return RULED end
end

function Scrap.IsScrap(id)
    return On() and State(id) ~= nil
end

function Scrap.Scope(id)
    if AccountMarks()[id] then return "account" end
    if CharMarks()[id] then return "char" end
end

function Scrap.MarkedIDs(out)
    wipe(out)
    for id in pairs(AccountMarks()) do out[#out + 1] = id end
    for id in pairs(CharMarks()) do
        if not AccountMarks()[id] then out[#out + 1] = id end
    end
    return out
end

local function Refusal(id, bag, slot)
    local _, _, _, _, _, classID = GetItemInfoInstant(id)
    if classID == QUEST_CLASS then return NOT_SCRAP.quest end
    if classID == KEY_CLASS then return NOT_SCRAP.key end
    local info = bag and GetContainerItemInfo(bag, slot)
    if (info and info.hasNoValue) or SellPrice(id) == 0 then return NOT_SCRAP.value end
    local guard = Protection(id)
    if guard then return NOT_SCRAP[guard] end
end
Scrap.Refusal = Refusal

local function NewMark(button, over)
    local size = math.max(MARK_MIN, math.floor(button:GetHeight() * MARK_SHARE))
    local mark = CreateFrame("Frame", nil, over)
    mark:SetSize(size, math.floor(size * St.SCRAP_RATIO + ROUND))
    mark:SetPoint("TOPRIGHT", -MARK_IN, -MARK_IN)
    mark:SetFrameLevel(over:GetFrameLevel() + MARK_LEVEL)
    local icon = Parts.Smooth(mark:CreateTexture(nil, "OVERLAY"))
    icon:SetAtlas(St.SCRAP_ATLAS)
    icon:SetAllPoints()
    marks[button] = mark
    return mark
end

local function Paint(button, over, id)
    local mark = marks[button]
    local state = id and showMark and State(id)
    if not state then
        if mark then mark:Hide() end
        return
    end
    mark = mark or NewMark(button, over)
    mark:SetAlpha(state == RULED and RULE_ALPHA or 1)
    mark:Show()
end

local function OnClick(button, mouse)
    if mouse ~= "LeftButton" or not IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown() then return end
    if not On() or GetCursorInfo() then return end
    local bag, slot = bagOf[button], slotOf[button]
    local id = bag and GetContainerItemID(bag, slot)
    if id then Toggle(id, bag, slot) end
end

local function HookClick(button, onClick)
    if not hooked[button] and not InCombatLockdown() then
        hooked[button] = true
        button:HookScript("OnClick", onClick)
    end
end

local function Slot(button, over, bag, slot, id)
    bagOf[button], slotOf[button] = bag, slot
    HookClick(button, OnClick)
    Paint(button, over, id)
end

local function GameBag(frame)
    if not On() then return end
    showMark = S.Get("scrapMarkerShow")
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button:GetBagID(), button:GetID()
        Slot(button, button, bag, slot, GetContainerItemID(bag, slot))
    end
end

local function EllesmereSlot(button, data)
    local info = data.info
    local id = info and info.itemID
    if not id then
        Paint(button, button, nil)
        return
    end
    showMark = S.Get("scrapMarkerShow")
    Slot(button, button._textOverlay or button, data.bag, data.slot, id)
end

local function BaganatorClick(button, mouse)
    bagOf[button], slotOf[button] = button:GetBagID(), button:GetID()
    OnClick(button, mouse)
end

local function BaganatorInit(button)
    local mark = NewMark(button, button)
    owners[mark] = button
    return mark
end

local function BaganatorPaint(mark, details)
    local button = owners[mark]
    if not On() or not (button.GetBagID and button:GetBagID()) then return false end
    HookClick(button, BaganatorClick)
    showMark = S.Get("scrapMarkerShow")
    local state = showMark and State(details.itemID)
    if not state then return false end
    mark:SetAlpha(state == RULED and RULE_ALPHA or 1)
    return true
end

local function BaganatorJunk(_, _, id)
    local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(id)
    return (quality == POOR and price ~= nil and price > 0) or Scrap.IsScrap(id)
end

local function Repaint()
    if not installed then return end
    Bags.RepaintGame(GameBag)
    if registered then Bags.RefreshEllesmere() end
    if baganator then baganator.RequestItemButtonsRefresh() end
end

local function Changed()
    Repaint()
    for i = 1, #listeners do listeners[i]() end
    if ns.BagSpaceRescan then ns.BagSpaceRescan() end
    if ns.UI and ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

function Scrap.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function Scrap.Mark(id, link, bag, slot)
    local why = Refusal(id, bag, slot)
    if why then
        ns.Print((link or (TEXT_ITEM .. id)) .. why)
        return false
    end
    local keep = ns.AccountSettings().scrapKeep
    if keep then keep[id] = nil end
    if S.Get("scrapMarkerScope") == "char" and Me() then
        WritableChar()[id] = true
    else
        Writable("scrapItems")[id] = true
    end
    if link then ns.Print(link .. TEXT_MARKED) end
    Changed()
    return true
end

function Scrap.Unscrap(id, link)
    Writable("scrapItems")[id] = nil
    if Me() then WritableChar()[id] = nil end
    if RuleMatch(id) then Writable("scrapKeep")[id] = true end
    if link then ns.Print(link .. TEXT_UNMARKED) end
    Changed()
end

function Scrap.SwitchScope(id)
    local scope = Scrap.Scope(id)
    if not scope or not Me() then return end
    if scope == "account" then
        Writable("scrapItems")[id] = nil
        WritableChar()[id] = true
    else
        WritableChar()[id] = nil
        Writable("scrapItems")[id] = true
    end
    Changed()
end

function Scrap.AddAll(ids)
    local list = (S.Get("scrapMarkerScope") == "char" and Me()) and WritableChar() or Writable("scrapItems")
    for i = 1, #ids do list[ids[i]] = true end
    Changed()
end

function Scrap.Clear()
    local account = ns.AccountSettings()
    account.scrapItems = nil
    if account.scrapChars and Me() then account.scrapChars[Me()] = nil end
    Changed()
end

function Toggle(id, bag, slot)
    local link = GetContainerItemLink(bag, slot) or (TEXT_ITEM .. id)
    if State(id) then Scrap.Unscrap(id, link) else Scrap.Mark(id, link, bag, slot) end
end

local function Sellable(info)
    local id = info and info.itemID
    return id and not info.isLocked and not info.hasNoValue and State(id) ~= nil and id
end

function Scrap.BagValue()
    local total = 0
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            local id = Sellable(info)
            if id and not Protection(id) then
                total = total + (SellPrice(id) or 0) * (info.stackCount or 1)
            end
        end
    end
    return total
end

local function AtMerchant()
    return atMerchant and MerchantFrame ~= nil and MerchantFrame:IsShown() and not InCombatLockdown()
end

local function CanSell()
    return selling and On() and S.Get("scrapMarkerVendor") ~= "none" and AtMerchant()
end

local function Finish()
    if sold > 0 then
        local line = (sold == 1 and TEXT_SOLD_ONE or TEXT_SOLD):format(sold, Parts.Coins(earned))
        if spared > 0 then line = line .. TEXT_KEPT:format(spared) end
        ns.Print(line)
    elseif spared > 0 then
        ns.Print((spared == 1 and TEXT_KEPT_ALL_ONE or TEXT_KEPT_ALL):format(spared))
    end
    selling, sold, earned, spared = false, 0, 0, 0
    generation = generation + 1
end

local function Schedule()
    scheduledFor = generation
    if pending then return end
    pending = true
    C_Timer.After(STEP_DELAY, Step)
end

local function Sell()
    if AskPanel then AskPanel:Hide() end
    if not AtMerchant() then return end
    generation = generation + 1
    selling, sold, earned, spared = true, 0, 0, 0
    nextBag, nextSlot = BACKPACK_CONTAINER, 1
    scheduledFor = generation
    Step()
end

local function SellSlot(bag, slot)
    local info = GetContainerItemInfo(bag, slot)
    local id = Sellable(info)
    if not id then return false end
    if Protection(id) then
        spared = spared + 1
        return false
    end
    if not CanSell() or GetContainerItemID(bag, slot) ~= id then return nil end
    local price = SellPrice(id)
    C_Container.UseContainerItem(bag, slot)
    sold = sold + 1
    earned = earned + (price or 0) * (info.stackCount or 1)
    return true
end

function Step()
    pending = false
    if scheduledFor ~= generation or not selling then return end
    local sales = 0
    while nextBag <= LAST_BAG do
        local slots = GetContainerNumSlots(nextBag)
        while nextSlot <= slots do
            local bag, slot = nextBag, nextSlot
            nextSlot = slot + 1
            local sale = SellSlot(bag, slot)
            if sale == nil then return Finish() end
            if sale then
                sales = sales + 1
                if sales >= BATCH then return Schedule() end
            end
        end
        nextBag, nextSlot = nextBag + 1, 1
    end
    Finish()
end

local function CountText(n)
    local text = countTexts[n]
    if not text then
        text = TEXT_COUNT .. n
        countTexts[n] = text
    end
    return text
end

local function CollectSale()
    wipe(askIDs)
    wipe(askCount)
    wipe(askValue)
    local total = 0
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            local id = Sellable(info)
            if id and not Protection(id) then
                local count, value = info.stackCount or 1, (SellPrice(id) or 0) * (info.stackCount or 1)
                if not askCount[id] then
                    askIDs[#askIDs + 1] = id
                    askCount[id], askValue[id] = 0, 0
                end
                askCount[id], askValue[id] = askCount[id] + count, askValue[id] + value
                total = total + value
            end
        end
    end
    return total
end

local AskDraw = {}

function AskDraw:Redraw()
    self:Clear()
    for i = 1, #askIDs do
        local id = askIDs[i]
        self:Add("item", id, CountText(askCount[id]), Parts.Coins(askValue[id]))
    end
    self:Fit(EMPTY)
end

local function NewAskView(scroll)
    return View.New(scroll, View.NewKinds(), AskDraw)
end

local function One()
    return 1
end

local function HideAsk()
    AskPanel:Hide()
end

local function ShowAsk()
    local total = CollectSale()
    if #askIDs == 0 then return end
    if not AskPanel then
        AskPanel = Parts.SidePanel({ { TEXT_SELL, Sell }, { TEXT_NOT_NOW, HideAsk } }, NewAskView, One)
    end
    AskPanel.title:SetText(TEXT_ASK:format(Parts.Coins(total)))
    Parts.ShowBeside(AskPanel, MerchantFrame)
    AskPanel.view:Redraw()
end
Scrap.ShowAsk = ShowAsk

local function Offer()
    offerPending = false
    if not AtMerchant() or not On() then return end
    local mode = S.Get("scrapMarkerVendor")
    if mode == "sell" then
        Sell()
    elseif mode == "ask" then
        ShowAsk()
    end
end

local function OnEvent(_, event)
    if event == "MERCHANT_SHOW" then
        atMerchant = true
        if not offerPending then
            offerPending = true
            C_Timer.After(STEP_DELAY, Offer)
        end
    elseif event == "MERCHANT_CLOSED" or event == "PLAYER_REGEN_DISABLED" then
        if event == "MERCHANT_CLOSED" then atMerchant = false end
        if AskPanel then AskPanel:Hide() end
        if selling then Finish() end
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        setsDirty = true
        Changed()
    elseif event == "PLAYER_LEVEL_UP" then
        Repaint()
    end
end

local function OnItem(tooltip, data)
    if not On() then return end
    local id = data and data.id
    if not id or (issecretvalue and issecretvalue(id)) then return end
    local state = State(id)
    if not state then return end
    local c = T.accent
    tooltip:AddLine((TIPS[S.Get("scrapMarkerVendor")] or TIPS.sell)[state], c.r, c.g, c.b)
end

local function Install()
    installed = true
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
    Bags.OnGameUpdate(GameBag)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
end

local function Apply()
    local on = On()
    if on and not installed then Install() end
    if not installed then return end
    events:UnregisterAllEvents()
    watchingSets, setsDirty = false, true
    local bags = Bags.Ellesmere()
    if bags and on ~= registered then
        registered = on
        if on then
            bags.RegisterItemOverlayIcon(OVERLAY, EllesmereSlot)
        else
            bags.UnregisterItemOverlayIcon(OVERLAY)
        end
    end
    local api = on and not baganator and Bags.Baganator()
    if api then
        baganator = api
        api.RegisterCornerWidget(TEXT_BAGANATOR, OVERLAY, BaganatorPaint, BaganatorInit, BAGANATOR_CORNER, true)
        api.RegisterJunkPlugin(TEXT_BAGANATOR, OVERLAY, BaganatorJunk)
    end
    if selling and not (on and S.Get("scrapMarkerVendor") ~= "none") then Finish() end
    if AskPanel and not (on and S.Get("scrapMarkerVendor") == "ask") then AskPanel:Hide() end
    if not on then
        for _, mark in pairs(marks) do mark:Hide() end
        Changed()
        return
    end
    events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    watchingSets = true
    if S.Get("scrapRuleOld") then events:RegisterEvent("PLAYER_LEVEL_UP") end
    if S.Get("scrapMarkerVendor") ~= "none" then
        atMerchant = MerchantFrame ~= nil and MerchantFrame:IsShown()
        events:RegisterEvent("MERCHANT_SHOW")
        events:RegisterEvent("MERCHANT_CLOSED")
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
    Changed()
end

S.OnChange(function(key)
    if key == "enabled" or key:find("^scrap") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local Group = Shared.Settings.Group

local function Summary()
    local n = 0
    for _ in pairs(AccountMarks()) do n = n + 1 end
    for id in pairs(CharMarks()) do
        if not AccountMarks()[id] then n = n + 1 end
    end
    local text = (n == 1 and TEXT_SUMMARY_ONE or TEXT_SUMMARY):format(n)
    local value = Scrap.BagValue()
    if value > 0 then text = text .. ", " .. Parts.Coins(value) .. TEXT_IN_BAGS end
    return text
end

Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "scrapMarker", name = "Scrap Marker", order = 25, switch = "scrapMarker",
    help = "Alt-click an item in your bags to mark it as scrap, and sell it at the next vendor.",
    search = "/nf scrap nf scrap list",
    summary = Summary,
    rows = {
        { key = "scrapMarkerVendor", label = "At the Vendor", choice = VENDOR,
          help = "Sell your scrap when you open a vendor, ask you first, or do nothing." },
        { key = "scrapMarkerScope", label = "New Marks", choice = SCOPE,
          help = "Whether a new mark counts on every character or only this one." },
        { key = "scrapMarkerShow", label = "Show Mark", toggle = true,
          help = "A scrap icon on the bag slot of each item marked as scrap." },
        { key = "scrapMarkerProtect", label = "Protect BiS and Gear Sets", toggle = true,
          help = "Items on your BiS list or in a gear set are never scrap." },
        Group("Rules"),
        { key = "scrapRuleWear", label = "Gear You Can't Wear", toggle = true,
          help = "Armour and weapons your class can never use count as scrap." },
        { key = "scrapRuleOld", label = "Old Common Gear", toggle = true,
          help = "Grey and white gear far below your level counts as scrap." },
        { key = "scrapRuleLevels", label = "Levels Below You", slider = LEVELS_RANGE, needs = "scrapRuleOld",
          help = "How far below your level gear has to be for Old Common Gear." },
    },
})
