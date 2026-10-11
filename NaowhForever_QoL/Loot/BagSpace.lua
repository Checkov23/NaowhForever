-- BagSpace.lua: Bag Space, the cheapest things in your bags on a card, to delete, sell or ignore.
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local UI = ns.UI
local T = ns.THEME
local S = ns.QoLSettings
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local Coins = Parts.Coins

local SCAN_DELAY = 0.2
local SAMPLE_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local SAMPLE_PRICE = 12
local SAMPLE_FREE, SAMPLE_SLOTS = 28, 96
local FULL_SHOW = 20
local OUTLEVEL = 10
local MERGE_STEPS = 60
local QUEST_CONFIRM = 5
local EDGE_COLORED = 2
local DIRECT_DELETE = 1

local BORDER_RGB = St.BORDER_RGB
local CARD_ALPHA = 0.85
local PAD = 6
local GAP = 6
local GAP_MIN = 2
local ICON_BASE = 36
local HEAD_H = 16
local HEAD_GAP = 5
local HEAD_SPACE = 12
local HEAD_SIZE = 12
local HEAD_ICON = 12
local ICON_DROP = Parts.CARD_DROP
local TEXT_GAP = 4
local STACK_PAD = 8
local PRICE_SIZE = 10
local PRICE_MIN = 8
local PRICE_H = 12
local PRICE_GAP = 3
local PRICE_W = 32
local LOW_SHARE = 0.1
local QUEST_RGB = St.CARRIED_RGB
local FREE_TEXT = ns.L("free")
local OLD_TIP = (ns.L("Outlevelled: %d or more levels below you")):format(OUTLEVEL)
local TIP_ICON, TIP_ICON_TINTED = "|A:%s:0:0:0:%d|a ", "|A:%s:0:0:0:%d:%d:%d:%d|a "
local STACK_TEXT = ns.L("Stack +%d")
local ROUND = ns.QoLConstants.ROUND
local COLOR_MAX = 255
local FULL_SLACK = 0.1
local DEFAULT_Y = 180
local PLAIN_BAG = ns.QoLConstants.PLAIN_BAG
local COUNT_RANGE, FREE_BELOW_RANGE, ICON_RANGE = { 1, 8, 1 }, { 0, 30, 1 }, { 16, 56, 1 }
local TEXT_RANGE = St.HUD_TEXT_RANGE
local MOVER_LABEL = "Bag Space"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Loot & Items", "QoL/Loot & Items:bagSpace"
local ITEM_CLASS = { CONSUMABLE = 0, REAGENT = 5, PROJECTILE = 6, QUIVER = 11, QUEST = 12, KEY = 13 }
local NEED_PATTERNS = { "^(.-):%s*%d+%s*/%s*%d+", "^%d+%s*/%s*%d+%s+(.+)$" }
local TEXT = {
    HOLDING = ns.L("put down what you are holding first."),
    MOVED = ns.L("that item moved in your bags; the row has been refreshed."),
    A_QUEST = "a quest",
    QUEST = "%s (%d/%d)",
    CAREFUL = ns.L("careful: %s is needed for %s."),
    ON_CURSOR = ns.L("%s (%s) is on your cursor: click the ground to delete it, or a bag slot to put it back."),
    QUEST_DELETE = ns.L("%s is needed for %s. Ctrl-click it again within %d seconds to delete it anyway."),
    DELETED = ns.L("deleted %s (%s)."),
    IGNORED = ns.L("%s is ignored and will not be offered again. Manage it under QoL > Loot > "
        .. "Bag Space > Ignore List."),
    COUNT = " x",
    STACK_STOPPED = ns.L("stacking stopped: put down what you are holding, and wait for combat to end."),
    STACKED_ONE = ns.L("stacked your bags: %d slot freed."),
    STACKED = ns.L("stacked your bags: %d slots freed."),
    VENDOR = ns.L("Vendor"),
    AUCTION = ns.L("Auction"),
    NEEDED_FOR = ns.L("Needed for "),
    STACK_TITLE = ns.L("Stack Your Bags"),
    STACK_TIP_ONE = ns.L("Combines part-filled stacks of the same item, freeing %d slot. Nothing is deleted."),
    STACK_TIP = ns.L("Combines part-filled stacks of the same item, freeing %d slots. Nothing is deleted."),
    BAG_SPACE = ns.L("Bag Space"),
    BAG = "Bag ",
    BAG_FREE = ns.L("%d/%d free"),
    SPECIAL_BAGS = ns.L("Quivers and profession bags are not counted."),
    SCRAP_FREE = ns.L("%d more free after the next vendor sells your scrap."),
    STACK = "Stack",
    SCRAP = "+",
    SUMMARY = ns.L("%d items, %s and below"),
    COMMON = "Common",
}

local PROTECTED_CLASS = {
    [ITEM_CLASS.REAGENT] = true,
    [ITEM_CLASS.PROJECTILE] = true,
    [ITEM_CLASS.QUIVER] = true,
    [ITEM_CLASS.QUEST] = true,
    [ITEM_CLASS.KEY] = true,
}

local frame, unlocked, atMerchant, inCombat, pendingScan, missingInfo, junkFirst, oldFirst
local pool, picks = {}, {}
local free, total, fullUntil = 0, 0, 0
local scrapSlots = 0
local setItems, setsDirty = {}, true
local partial, stackSaves = {}, 0
local merging, mergeSteps, mergeStartFree

local function On()
    return S.Get("enabled") and S.Get("bagSpace")
end

local function Ignored()
    local db = S.DB()
    db.bagSpaceIgnore = db.bagSpaceIgnore or {}
    return db.bagSpaceIgnore
end

local function RebuildSets()
    setsDirty = false
    wipe(setItems)
    if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs) then return end
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local ids = C_EquipmentSet.GetItemIDs(setID)
        if ids then
            for _, itemID in pairs(ids) do
                if type(itemID) == "number" and itemID > 0 then setItems[itemID] = true end
            end
        end
    end
end

local scanIgnored, scanProtect, scanAuction, scanMaxQuality, scanScrap

local function Protected(itemID, classID)
    if scanIgnored[itemID] then return true end
    if not scanProtect then return false end
    if PROTECTED_CLASS[classID] or setItems[itemID] then return true end
    return ns.IsBisItem and ns.IsBisItem(itemID) and true or false
end

local function AuctionEach(itemID, link)
    local ah = ns.AuctionPrice and ns.AuctionPrice(itemID)
    if not ah and TSM_API and TSM_API.GetCustomPriceValue then
        local ok, value = pcall(TSM_API.GetCustomPriceValue, "dbminbuyout", TSM_API.ToItemString(link))
        if ok then ah = value end
    end
    return ah
end

local function StackValue(itemID, link, vendor, count)
    local each = vendor
    if scanAuction then
        local ah = AuctionEach(itemID, link)
        if ah and ah > each then each = ah end
    end
    return each * count
end

local questNeeds, questDirty = {}, true
local needPool, needsUsed = {}, 0

local function NoteNeed(name, title, have, need)
    needsUsed = needsUsed + 1
    local n = needPool[needsUsed] or {}
    needPool[needsUsed] = n
    n.title, n.have, n.need = title, have, need
    questNeeds[name] = n
end

local function NoteObjectives(info)
    local objectives = C_QuestLog.GetQuestObjectives(info.questID)
    if not objectives then return end
    for _, o in ipairs(objectives) do
        if o.type == "item" and not o.finished and o.text then
            local name = o.text:match(NEED_PATTERNS[1]) or o.text:match(NEED_PATTERNS[2])
            if name then NoteNeed(name, info.title, o.numFulfilled or 0, o.numRequired or 0) end
        end
    end
end

local function RebuildQuestNeeds()
    questDirty = false
    wipe(questNeeds)
    needsUsed = 0
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetQuestObjectives) then return end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then NoteObjectives(info) end
    end
end

local function Cheaper(a, b)
    if (a.quest ~= nil) ~= (b.quest ~= nil) then return b.quest ~= nil end
    if junkFirst and (a.quality == 0) ~= (b.quality == 0) then return a.quality == 0 end
    if oldFirst and a.old ~= b.old then return a.old end
    if a.value ~= b.value then return a.value < b.value end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

local listPool, listsUsed = {}, 0
local slotPool, slotsUsed = {}, 0

local function NotePartial(bag, slot, itemID, count, maxStack)
    if not maxStack or maxStack <= 1 or count >= maxStack then return end
    local list = partial[itemID]
    if not list then
        listsUsed = listsUsed + 1
        list = listPool[listsUsed] or {}
        listPool[listsUsed] = list
        wipe(list)
        list.total, list.max = 0, maxStack
        partial[itemID] = list
    end
    slotsUsed = slotsUsed + 1
    local rec = slotPool[slotsUsed] or {}
    slotPool[slotsUsed] = rec
    rec.bag, rec.slot, rec.count = bag, slot, count
    list[#list + 1] = rec
    list.total = list.total + count
end

local function CountStackSaves()
    stackSaves = 0
    for _, list in pairs(partial) do
        if #list > 1 then
            stackSaves = stackSaves + #list - math.ceil(list.total / list.max)
        end
    end
end

local anyLocked, scanLevel

local function Offer(n, bag, slot, info, quality, classID, name, minLevel, vendor)
    n = n + 1
    local e = pool[n] or {}
    pool[n] = e
    e.bag, e.slot, e.itemID, e.link = bag, slot, info.itemID, info.hyperlink
    e.icon, e.count, e.quality = info.iconFileID, info.stackCount or 1, quality
    e.vendor = vendor
    e.value = StackValue(info.itemID, info.hyperlink, vendor, e.count)
    e.old = classID == ITEM_CLASS.CONSUMABLE and (minLevel or 0) > 0 and scanLevel - minLevel >= OUTLEVEL
    e.quest = questNeeds[name]
    picks[n] = e
    return n
end

local function ScanSlot(n, bag, slot)
    local info = GetContainerItemInfo(bag, slot)
    if info and info.isLocked then anyLocked = true end
    if not (info and info.itemID and not info.isLocked) then return n end
    local _, _, _, _, _, classID = GetItemInfoInstant(info.itemID)
    local quality = info.quality or 1
    local name, _, _, _, minLevel, _, _, maxStack, _, _, vendor = GetItemInfo(info.itemID)
    if vendor == nil then
        missingInfo = true
        return n
    end
    NotePartial(bag, slot, info.itemID, info.stackCount or 1, maxStack)
    local scrap = scanScrap ~= nil and vendor > 0 and scanScrap(info.itemID)
    if scrap then scrapSlots = scrapSlots + 1 end
    if vendor > 0 and quality <= scanMaxQuality and not Protected(info.itemID, classID) then
        n = Offer(n, bag, slot, info, quality, classID, name, minLevel, vendor)
    end
    return n
end

local function StartScan()
    for i = #picks, 1, -1 do picks[i] = nil end
    wipe(partial)
    listsUsed, slotsUsed = 0, 0
    free, total, missingInfo, anyLocked, scrapSlots = 0, 0, false, false, 0
    if setsDirty then RebuildSets() end
    if questDirty then RebuildQuestNeeds() end
    scanIgnored, scanProtect = Ignored(), S.Get("bagSpaceProtect")
    scanAuction, scanMaxQuality = S.Get("bagSpaceAuction"), S.Get("bagSpaceMaxQuality")
    local scrapper = ns.ScrapMarker
    scanScrap = scrapper and scrapper.On() and scrapper.IsScrap or nil
    scanLevel = UnitLevel("player")
end

local function Scan()
    StartScan()
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    local n = 0
    for bag = BACKPACK_CONTAINER, lastBag do
        local freeSlots, family = GetContainerNumFreeSlots(bag)
        if family == PLAIN_BAG then
            local slots = GetContainerNumSlots(bag)
            free, total = free + (freeSlots or 0), total + slots
            for slot = 1, slots do n = ScanSlot(n, bag, slot) end
        end
    end
    CountStackSaves()
    junkFirst, oldFirst = S.Get("bagSpaceJunkFirst"), S.Get("bagSpaceOldFirst")
    table.sort(picks, Cheaper)
end

local RequestScan, Update

local function StillThere(p)
    local info = C_Container.GetContainerItemInfo(p.bag, p.slot)
    return info and info.itemID == p.itemID and (info.stackCount or 1) == p.count and not info.isLocked
end

local function Snapshot(e)
    return { bag = e.bag, slot = e.slot, itemID = e.itemID, link = e.link, count = e.count, value = e.value,
        quest = e.quest, quality = e.quality }
end

local function Label(p)
    return p.link .. (p.count > 1 and (TEXT.COUNT .. p.count) or "")
end

local function PickUp(p)
    if GetCursorInfo() then
        ns.Print(TEXT.HOLDING)
        return
    end
    if not StillThere(p) then
        ns.Print(TEXT.MOVED)
        RequestScan()
        return
    end
    C_Container.PickupContainerItem(p.bag, p.slot)
    local kind, id = GetCursorInfo()
    if kind ~= "item" or id ~= p.itemID then
        ClearCursor()
        return
    end
    return true
end

local function QuestText(q)
    return TEXT.QUEST:format(q.title or TEXT.A_QUEST, q.have, q.need)
end

local function GroundHint(p)
    if p.quest then ns.Print(TEXT.CAREFUL:format(p.link, QuestText(p.quest))) end
    ns.Print(TEXT.ON_CURSOR:format(Label(p), Coins(p.value)))
end

local armedItem, armedUntil = nil, 0

local function ConfirmQuestDelete(p)
    if not p.quest or (armedItem == p.itemID and GetTime() < armedUntil) then
        armedItem = nil
        return true
    end
    armedItem, armedUntil = p.itemID, GetTime() + QUEST_CONFIRM
    ns.Print(TEXT.QUEST_DELETE:format(p.link, QuestText(p.quest), QUEST_CONFIRM))
    return false
end

local function Delete(p)
    if not PickUp(p) then return end
    if p.quality > DIRECT_DELETE then
        GroundHint(p)
        return
    end
    DeleteCursorItem()
    if GetCursorInfo() then
        GroundHint(p)
        return
    end
    ns.Print(TEXT.DELETED:format(Label(p), Coins(p.value)))
end

local function Sell(p)
    if InCombatLockdown() or not StillThere(p) then return end
    C_Container.UseContainerItem(p.bag, p.slot)
end

local function Ignore(p)
    Ignored()[p.itemID] = time()
    ns.Print(TEXT.IGNORED:format(p.link))
    RequestScan()
end

local function StopMerge(message)
    merging = false
    if message then ns.Print(message) end
    RequestScan()
end

local function Smaller(a, b)
    return a.count < b.count
end

local function NextMove()
    for _, list in pairs(partial) do
        if #list > 1 then
            table.sort(list, Smaller)
            local src = list[1]
            for i = #list, 2, -1 do
                local dst = list[i]
                local room = list.max - dst.count
                if room > 0 then return src, dst, math.min(room, src.count) end
            end
        end
    end
end

local function MergeStep()
    if not merging then return end
    if InCombatLockdown() or GetCursorInfo() then
        return StopMerge(TEXT.STACK_STOPPED)
    end
    mergeSteps = mergeSteps + 1
    if mergeSteps == 1 then mergeStartFree = free end
    local src, dst, amount = NextMove()
    if not src and anyLocked and mergeSteps <= MERGE_STEPS then return end
    if not src or mergeSteps > MERGE_STEPS then
        local freed = free - mergeStartFree
        if freed <= 0 then return StopMerge() end
        return StopMerge((freed == 1 and TEXT.STACKED_ONE or TEXT.STACKED):format(freed))
    end
    if amount < src.count then
        C_Container.SplitContainerItem(src.bag, src.slot, amount)
    else
        C_Container.PickupContainerItem(src.bag, src.slot)
    end
    C_Container.PickupContainerItem(dst.bag, dst.slot)
    if GetCursorInfo() then C_Container.PickupContainerItem(src.bag, src.slot) end
end

local function StartMerge()
    if merging or InCombatLockdown() then return end
    if GetCursorInfo() then
        ns.Print(TEXT.HOLDING)
        return
    end
    merging, mergeSteps = true, 0
    Update()
end

function NaowhForever_BagSpacePickUp()
    if not On() then return end
    Update()
    if not picks[1] then return end
    local p = Snapshot(picks[1])
    if PickUp(p) then GroundHint(p) end
end

local function OnClick(self, button)
    local e = self.pick
    if not e or unlocked then return end
    local p = Snapshot(e)
    if IsModifiedClick("CHATLINK") then
        ChatFrameUtil.InsertLink(p.link)
    elseif button == "MiddleButton" then
        Ignore(p)
    elseif IsControlKeyDown() then
        if ConfirmQuestDelete(p) then Delete(p) end
    elseif atMerchant then
        Sell(p)
    end
end

local function Worth(each, count)
    if count <= 1 then return Coins(each) end
    return Coins(each * count) .. ("  " .. ns.Color("muted", ns.L("(%s each x%d)"))):format(Coins(each), count)
end

local oldLine, questMark

local function TipMarks()
    local c = St.WARN_RGB
    oldLine = TIP_ICON_TINTED:format(St.CLOCK_ATLAS, -Parts.TOOLTIP_DROP, c.r * COLOR_MAX, c.g * COLOR_MAX,
        c.b * COLOR_MAX) .. OLD_TIP
    questMark = TIP_ICON:format(St.QUEST_ATLAS, -Parts.TOOLTIP_DROP)
end

local function AddHints(e, deleteHint, ignoreHint)
    if deleteHint then
        if e.quest then
            GameTooltip:AddLine(ns.Color("accent", ns.L("Ctrl-click")) .. ns.L("  twice to delete"), 1, 1, 1)
        elseif e.quality > DIRECT_DELETE then
            GameTooltip:AddLine(ns.Color("accent", ns.L("Ctrl-click")) .. ns.L("  pick up to delete"), 1, 1, 1)
        else
            GameTooltip:AddLine(ns.Color("accent", "Ctrl-click") .. ns.L("  delete now"), 1, 1, 1)
        end
        if atMerchant then GameTooltip:AddLine(ns.Color("accent", ns.L("Click")) .. ns.L("  sell"), 1, 1, 1) end
    end
    if ignoreHint then GameTooltip:AddLine(ns.Color("accent", ns.L("Middle-click")) .. ns.L("  ignore this item"), 1, 1, 1) end
end

local function AddTipLines(e, ah)
    if not oldLine then TipMarks() end
    local vendor, auction = S.Get("bagSpaceTipVendor"), S.Get("bagSpaceTipAuction")
    local deleteHint, ignoreHint = S.Get("bagSpaceTipDelete"), S.Get("bagSpaceTipIgnore")
    if vendor or auction or deleteHint or ignoreHint or e.quest or e.old then GameTooltip:AddLine(" ") end
    if vendor then GameTooltip:AddDoubleLine(TEXT.VENDOR, Worth(e.vendor, e.count), 1, 1, 1, 1, 1, 1) end
    if auction then
        GameTooltip:AddDoubleLine(TEXT.AUCTION, ah and Worth(ah, e.count) or ns.Color("muted", ns.L("unknown")), 1, 1, 1, 1, 1, 1)
    end
    if e.old then GameTooltip:AddLine(oldLine, St.WARN_RGB.r, St.WARN_RGB.g, St.WARN_RGB.b) end
    if e.quest then
        GameTooltip:AddLine(questMark .. TEXT.NEEDED_FOR .. QuestText(e.quest), QUEST_RGB.r, QUEST_RGB.g, QUEST_RGB.b)
    end
    AddHints(e, deleteHint, ignoreHint)
end

local function OnEnter(self)
    local e = self.pick
    if not e or unlocked then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetBagItem(e.bag, e.slot)
    AddTipLines(e, S.Get("bagSpaceTipAuction") and AuctionEach(e.itemID, e.link) or nil)
    GameTooltip:Show()
end

local function StackTip(self)
    local saves = self.saves or 0
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(TEXT.STACK_TITLE)
    GameTooltip:AddLine((saves == 1 and TEXT.STACK_TIP_ONE or TEXT.STACK_TIP):format(saves), 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(ns.Color("accent", ns.L("Click")) .. ns.L("  stack now"), 1, 1, 1)
    GameTooltip:Show()
end

local function StackClicked()
    if not unlocked then StartMerge() end
end

local function AddBagLine(bag, slots)
    local freeSlots, family = GetContainerNumFreeSlots(bag)
    if family ~= PLAIN_BAG then return true end
    local name = C_Container.GetBagName and C_Container.GetBagName(bag) or (TEXT.BAG .. bag)
    GameTooltip:AddDoubleLine(name, TEXT.BAG_FREE:format(freeSlots or 0, slots), 1, 1, 1, 1, 1, 1)
    return false
end

local function FreeTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(TEXT.BAG_SPACE)
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    local special = false
    for bag = BACKPACK_CONTAINER, lastBag do
        local slots = GetContainerNumSlots(bag)
        if slots > 0 and AddBagLine(bag, slots) then special = true end
    end
    if special then
        GameTooltip:AddLine(TEXT.SPECIAL_BAGS, T.muted.r, T.muted.g, T.muted.b, true)
    end
    if scrapSlots > 0 then
        GameTooltip:AddLine(TEXT.SCRAP_FREE:format(scrapSlots), T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, true)
    end
    GameTooltip:Show()
end

local function NewFreeCounter(parent, live)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(HEAD_H)
    f.icon = Parts.Smooth(f:CreateTexture(nil, "ARTWORK"), St.BAG)
    f.icon:SetSize(HEAD_ICON, HEAD_ICON)
    f.icon:SetPoint("LEFT", 0, -ICON_DROP)
    f.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    f.text = Parts.HudText(ns.Font(f, HEAD_SIZE))
    f.text:SetPoint("LEFT", HEAD_ICON + TEXT_GAP, 0)
    f.word = Parts.HudText(ns.Font(f, HEAD_SIZE, nil, T.muted))
    f.word:SetPoint("LEFT", f.text, "RIGHT", TEXT_GAP, 0)
    f.word:SetText(FREE_TEXT)
    f.scrap = Parts.HudText(ns.Font(f, HEAD_SIZE, nil, T.accentSoft))
    f.scrap:SetPoint("LEFT", f.word, "RIGHT", TEXT_GAP, 0)
    if live then
        f:EnableMouse(true)
        f:SetScript("OnEnter", FreeTooltip)
        f:SetScript("OnLeave", GameTooltip_Hide)
    end
    return f
end

local function NewView(view, onClick, onEnter, onStack, live)
    local card = CreateFrame("Frame", nil, view)
    view.backdrop = Parts.HudBackdrop(card, { alpha = CARD_ALPHA })
    view.card = card
    view.free = NewFreeCounter(card, live)
    view.free:SetPoint("TOPLEFT", PAD, -PAD)
    view.stack = ns.AccentBorder(ns.Button(card, TEXT.STACK, HEAD_H, HEAD_H, onStack))
    view.stack:SetPoint("TOPRIGHT", -PAD, -PAD)
    view.stack:HookScript("OnEnter", StackTip)
    view.stack:HookScript("OnLeave", GameTooltip_Hide)
    view.stack:Hide()
    view.cells, view.onClick, view.onEnter = {}, onClick, onEnter
    return view
end

local function NewCell(view, i, size)
    local b = CreateFrame("Button", nil, view.card)
    local icon = Parts.ItemIcon(b, size)
    icon:SetAllPoints()
    b.icon, b.edge = icon.texture, icon.edge
    b.marks = Parts.ItemMarks(icon, size)
    b.old = Parts.ItemBadge(b.marks, "TOPLEFT", St.CLOCK_ATLAS, St.WARN_RGB)
    b.quest = Parts.ItemBadge(b.marks, "TOPRIGHT", St.QUEST_ATLAS)
    b.price = Parts.HudFont(ns.Font(b, PRICE_SIZE, nil, T.muted), view.font, view.priceSize, view.outline, view.shadow)
    b.price:SetPoint("TOP", b, "BOTTOM", 0, -PRICE_GAP)
    b.price:SetWordWrap(false)
    if view.onClick then
        b:RegisterForClicks("LeftButtonUp", "MiddleButtonUp")
        b:SetScript("OnClick", view.onClick)
    end
    b:SetScript("OnEnter", view.onEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    view.cells[i] = b
    return b
end

local function ShowFree(view, count, slots, scrap)
    local f = view.free
    if not S.Get("bagSpaceShowFree") then
        f:Hide()
        return 0
    end
    local c = count == 0 and St.RED_RGB or count < slots * LOW_SHARE and St.WARN_RGB or T.fg
    f.text:SetTextColor(c.r, c.g, c.b, 1)
    f.text:SetText(Parts.Fraction(count, slots))
    local w = view.headIcon + TEXT_GAP + f.text:GetStringWidth() + TEXT_GAP + f.word:GetStringWidth()
    if scrap > 0 then
        f.scrap:SetText(TEXT.SCRAP .. scrap)
        w = w + TEXT_GAP + f.scrap:GetStringWidth()
    end
    f.scrap:SetShown(scrap > 0)
    w = math.ceil(w)
    f:SetWidth(w)
    f:Show()
    return w
end

local function ShowStack(view, saves)
    local b = view.stack
    if saves <= 0 then
        b:Hide()
        return 0
    end
    ns.SetButtonText(b, STACK_TEXT:format(saves))
    local w = math.ceil(b.label:GetStringWidth()) + STACK_PAD * 2
    b:SetWidth(w)
    b.saves = saves
    b:Show()
    return w
end

local function Scaled(v, scale)
    return math.floor(v * scale + ROUND)
end

local function Style(view)
    local mode = view.backdrop:SetMode(S.Get("bagSpaceBackground"))
    local font, size, outline = S.Get("bagSpaceFont"), S.Get("bagSpaceFontSize"), S.Get("bagSpaceOutline")
    local iconSize = S.Get("bagSpaceSize")
    if view.shadow == mode and view.font == font and view.size == size and view.outline == outline
        and view.iconSize == iconSize then return end
    view.shadow, view.font, view.size, view.outline, view.iconSize = mode, font, size, outline, iconSize
    local scale = size / HEAD_SIZE
    local fit = math.min(1, iconSize / ICON_BASE)
    local price = math.max(PRICE_MIN, Scaled(PRICE_SIZE, scale * fit))
    view.priceSize, view.priceH, view.priceW = price, Scaled(PRICE_H, scale * fit), Scaled(PRICE_W, scale * fit)
    view.headH, view.headIcon = Scaled(HEAD_H, scale), Scaled(HEAD_ICON, scale)
    local f, cells = view.free, view.cells
    f:SetHeight(view.headH)
    f.icon:SetSize(view.headIcon, view.headIcon)
    f.text:SetPoint("LEFT", view.headIcon + TEXT_GAP, 0)
    view.stack:SetHeight(view.headH)
    Parts.HudFont(f.text, font, size, outline, mode)
    Parts.HudFont(f.word, font, size, outline, mode)
    Parts.HudFont(f.scrap, font, size, outline, mode)
    for i = 1, #cells do Parts.HudFont(cells[i].price, font, price, outline, mode) end
end

local STEP = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

local function PlaceCells(view, shown, size, stepX, stepY, prices)
    local cells, reverse = view.cells, S.Get("bagSpaceReverse")
    for i = 1, shown do
        local at = reverse and shown - i or i - 1
        local b = cells[i] or NewCell(view, i, size)
        b:SetSize(size, size)
        Parts.SizeItemMarks(b.marks, size)
        b:ClearAllPoints()
        b:SetPoint("CENTER", view, "CENTER", at * stepX, at * stepY)
        b.price:SetShown(prices)
        b:Show()
    end
    for i = shown + 1, #cells do cells[i]:Hide() end
end

local function Layout(view, shown, headW)
    local size = S.Get("bagSpaceSize")
    local prices = S.Get("bagSpacePrices")
    local dir = STEP[S.Get("bagSpaceGrow")] or STEP.RIGHT
    local half = size / 2
    local cellW = prices and math.max(size, view.priceW) or size
    local cellH = prices and size + PRICE_GAP + view.priceH or size
    local gap = math.max(GAP_MIN, Scaled(GAP, math.min(1, size / ICON_BASE)))
    local stepX, stepY = (cellW + gap) * dir[1], (cellH + gap) * dir[2]
    view:SetSize(size, size)
    PlaceCells(view, shown, size, stepX, stepY, prices)
    local spanX, spanY = (shown - 1) * stepX, (shown - 1) * stepY
    local left, right = math.min(0, spanX) - cellW / 2, math.max(0, spanX) + cellW / 2
    local top, bottom = math.max(0, spanY) + half, math.min(0, spanY) + half - cellH
    local head = headW > 0 and view.headH + HEAD_GAP or 0
    if shown == 0 then
        left, right, top, bottom, head = -half, -half, half, half, view.headH
    end
    if headW > right - left then
        if dir[1] < 0 then left = right - headW else right = left + headW end
    end
    local x, y = left - PAD, top + head + PAD
    local w, h = right - left + PAD * 2, top - bottom + head + PAD * 2
    local card = view.card
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", view, "CENTER", x, y)
    card:SetSize(w, h)
    view.cardX, view.cardY, view.cardW, view.cardH = x + w / 2, y - h / 2, w, h
    view:SetClampRectInsets(x + half, x + w - half, y - half, y - h + half)
end

local function Fill(b, e, icon, price, count, quality, old, quest)
    b.pick = e
    b.icon:SetTexture(icon)
    b.price:SetText(price)
    Parts.PaintItemMarks(b.marks, count, nil, false, false)
    b.old:SetShown(old == true)
    b.quest:SetShown(quest ~= nil)
    local c = quality and quality >= EDGE_COLORED and ITEM_QUALITY_COLORS[quality] or BORDER_RGB
    b.edge:SetColor(c.r, c.g, c.b, 1)
end

local function Draw(view, list, shown, count, slots, scrap, saves)
    Style(view)
    local freeW, stackW = ShowFree(view, count, slots, scrap), ShowStack(view, saves)
    Layout(view, shown, freeW + stackW + (freeW > 0 and stackW > 0 and HEAD_SPACE or 0))
    local cells = view.cells
    for i = 1, shown do
        local e = list[i]
        Fill(cells[i], e, e.icon, Coins(e.value, true), e.count, e.quality, e.old, e.quest)
    end
end

local function RenderUnlocked()
    local n = S.Get("bagSpaceCount")
    Style(frame)
    local freeW
    if total > 0 then
        freeW = ShowFree(frame, free, total, scrapSlots)
    else
        freeW = ShowFree(frame, SAMPLE_FREE, SAMPLE_SLOTS, 0)
    end
    ShowStack(frame, 0)
    Layout(frame, n, freeW)
    local cells = frame.cells
    for i = 1, n do
        local e = picks[i]
        if e then
            Fill(cells[i], nil, e.icon, Coins(e.value, true), e.count, e.quality, e.old, e.quest)
        else
            Fill(cells[i], nil, SAMPLE_ICON, Coins(SAMPLE_PRICE * i, true), nil, 1, i == 1)
        end
    end
    frame:Show()
end

local function Render()
    if unlocked then return RenderUnlocked() end
    local below = S.Get("bagSpaceFreeBelow")
    local enoughRoom = below > 0 and free >= below and GetTime() >= fullUntil
    local offerStack = S.Get("bagSpaceStack") and stackSaves > 0 and not merging
    local shown = math.min(#picks, S.Get("bagSpaceCount"))
    if (shown == 0 and not offerStack) or (inCombat and S.Get("bagSpaceHideCombat")) or enoughRoom then
        frame:Hide()
        return
    end
    Draw(frame, picks, shown, free, total, scrapSlots, offerStack and stackSaves or 0)
    frame:Show()
end

local events = CreateFrame("Frame")

function Update()
    pendingScan = false
    if not (frame and On()) then return end
    Scan()
    if missingInfo then
        events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    else
        events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
    if merging then
        events:RegisterEvent("ITEM_LOCK_CHANGED")
        MergeStep()
    else
        events:UnregisterEvent("ITEM_LOCK_CHANGED")
    end
    Render()
end

function RequestScan()
    if pendingScan then return end
    pendingScan = true
    C_Timer.After(SCAN_DELAY, Update)
end

function ns.BagSpaceRescan()
    if frame and On() then RequestScan() end
end

local function OnEvent(_, event, _, message)
    if event == "UI_ERROR_MESSAGE" then
        if message ~= ERR_INV_FULL and message ~= ERR_BAG_FULL then return end
        fullUntil = GetTime() + FULL_SHOW
        C_Timer.After(FULL_SHOW + FULL_SLACK, RequestScan)
    elseif event == "MERCHANT_SHOW" then
        atMerchant = true
    elseif event == "MERCHANT_CLOSED" then
        atMerchant = false
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        setsDirty = true
    elseif event == "QUEST_LOG_UPDATE" then
        questDirty = true
    end
    RequestScan()
end

events:SetScript("OnEvent", OnEvent)

local function Place()
    local pos = S.Get("bagSpacePos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function SavePosition(pos)
    S.Set("bagSpacePos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverBagSpace", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    NewView(frame, OnClick, OnEnter, StackClicked, true)
    frame.mover = UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
    frame.mover:ClearAllPoints()
    frame.mover:SetAllPoints(frame.card)
end

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Place()
    frame.mover:SetShown(unlocked == true)
    inCombat = UnitAffectingCombat("player")
    atMerchant = MerchantFrame and MerchantFrame:IsShown()
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("MERCHANT_SHOW")
    events:RegisterEvent("MERCHANT_CLOSED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    events:RegisterEvent("QUEST_LOG_UPDATE")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    if S.Get("bagSpaceOnFull") and S.Get("bagSpaceFreeBelow") > 0 then
        events:RegisterEvent("UI_ERROR_MESSAGE")
    end
    setsDirty, questDirty = true, true
    Update()
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^bagSpace") and key ~= "bagSpacePos") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.BagSpace = { Ignored = Ignored, RequestScan = RequestScan }

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group
local QUALITY = { { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }, { 0, 1, 2, 3, 4 } }
local DIRECTION = { { RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" }, { "RIGHT", "LEFT", "UP", "DOWN" } }

local function ShowIgnoreList()
    if ns.ShowBagSpaceIgnoreList then ns.ShowBagSpaceIgnoreList() end
end

local function BagSpaceSummary(store)
    return TEXT.SUMMARY:format(store.Get("bagSpaceCount"),
        QUALITY[1][store.Get("bagSpaceMaxQuality")] or TEXT.COMMON)
end

local STAGE_H, STAGE_MARGIN = 150, 14
local PREVIEW_SLOTS, PREVIEW_SCRAP, PREVIEW_STACK = 52, 2, 1
local PREVIEW_FREE = { bags = 28, low = 4, full = 0 }
local STATES = {
    { key = "bags", label = "Bags", tip = "Room to spare: 28 of 52 slots free." },
    { key = "low", label = "Low", tip = "Under a tenth of your slots free.", needs = "bagSpaceShowFree" },
    { key = "full", label = "Full", tip = "Not a slot free.", needs = "bagSpaceShowFree" },
}

local function Samples()
    local quest = { title = ns.L("Linen for Lakeshire"), have = 2, need = 6 }
    local list = {
        { name = ns.L("Worn Leather Pants"), icon = "Interface\\Icons\\INV_Pants_04", quality = 2, count = 1, vendor = 150 },
        { name = ns.L("Ruined Pelt"), icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", quality = 0, count = 4, vendor = 59 },
        { name = ns.L("Tough Jerky"), icon = "Interface\\Icons\\INV_Misc_Food_14", quality = 1, count = 20, vendor = 15,
          old = true },
        { name = ns.L("Linen Cloth"), icon = "Interface\\Icons\\INV_Fabric_Linen_01", quality = 1, count = 7, vendor = 13,
          quest = quest },
        { name = ns.L("Jade Ring"), icon = "Interface\\Icons\\INV_Jewelry_Ring_03", quality = 3, count = 1, vendor = 920 },
    }
    for i, e in ipairs(list) do
        e.bag, e.slot, e.value = 0, i, e.vendor * e.count
    end
    return list
end

local function PreviewEnter(self)
    local e = self.pick
    if not e then return end
    local c = ITEM_QUALITY_COLORS[e.quality] or ITEM_QUALITY_COLORS[1]
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(e.name, c.r, c.g, c.b)
    AddTipLines(e, nil)
    GameTooltip:Show()
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.view = NewView(CreateFrame("Frame", nil, preview), nil, PreviewEnter, nil, false)
    preview.samples, preview.list, preview.n = Samples(), {}, 0
    return preview
end

local function OfferedSamples(preview)
    local list, samples, maxQuality = preview.list, preview.samples, S.Get("bagSpaceMaxQuality")
    local n = 0
    for i = 1, #samples do
        local e = samples[i]
        if e.quality <= maxQuality then
            n = n + 1
            list[n] = e
        end
    end
    for i = n + 1, preview.n do list[i] = nil end
    preview.n = n
    junkFirst, oldFirst = S.Get("bagSpaceJunkFirst"), S.Get("bagSpaceOldFirst")
    table.sort(list, Cheaper)
    return list, n
end

local function PaintPreview(preview, state)
    local list, n = OfferedSamples(preview)
    local view = preview.view
    Draw(view, list, math.min(n, S.Get("bagSpaceCount")), PREVIEW_FREE[state] or PREVIEW_FREE.bags,
        PREVIEW_SLOTS, PREVIEW_SCRAP, S.Get("bagSpaceStack") and PREVIEW_STACK or 0)
    local scale = 1
    local roomW = preview:GetWidth() - STAGE_MARGIN * 2
    local roomH = preview:GetHeight() - STAGE_MARGIN * 2
    if roomW > 0 and view.cardW > roomW then scale = roomW / view.cardW end
    if roomH > 0 and view.cardH * scale > roomH then scale = roomH / view.cardH end
    view:SetScale(scale)
    view:ClearAllPoints()
    view:SetPoint("CENTER", preview, "CENTER", -view.cardX, -view.cardY)
end

Settings.Page("QoL/Loot & Items", S):Card({
    id = "bagSpace", name = "Bag Space", order = 60, switch = "bagSpace",
    help = "The cheapest items in your bags as a row of icons, cheapest first. Ctrl-click an icon "
        .. "to delete it, or click it to sell it while a vendor is open. Middle-click to ignore "
        .. "an item. "
        .. "Move it in the HUD Editor.",
    summary = BagSpaceSummary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Offered"),
        { key = "bagSpaceCount", label = "Items Shown", slider = COUNT_RANGE },
        { key = "bagSpaceMaxQuality", label = "Highest Quality Offered", choice = QUALITY,
          help = "Items above this quality are never offered." },
        { key = "bagSpaceJunkFirst", label = "Grey Items First", toggle = true,
          help = "Grey items come before everything else, whatever they sell for." },
        { key = "bagSpaceOldFirst", label = "Outlevelled Food & Potions First", toggle = true,
          help = "Puts food, drink and potions 10 or more levels below you, marked with a clock, first." },
        { key = "bagSpaceAuction", label = "Count Auction Prices", toggle = true,
          help = "An item worth more at the auction house than at a vendor is valued at its auction "
              .. "price, from your last Scan Prices or TradeSkillMaster." },
        { key = "bagSpaceProtect", label = "Protect Needed Items", toggle = true,
          help = "Never offers reagents, ammo, quest items, keys, items in an equipment set or items "
              .. "on your BiS list." },
        { label = "Ignore List", button = ShowIgnoreList, buttonText = "Ignore List", always = true,
          help = "Items Bag Space never offers. Search for one, drag one in, or middle-click an icon "
              .. "on the row." },
        Group("Showing"),
        { key = "bagSpaceFreeBelow", label = "Only With Free Slots Below", slider = FREE_BELOW_RANGE,
          help = "Shows the row only once your bags are this full. 0 shows it all the time." },
        { key = "bagSpaceOnFull", label = "Show When Bags Are Full", toggle = true,
          help = "An \"Inventory is full\" error brings the row up for 20 seconds, even with more free "
              .. "slots than the threshold above." },
        { key = "bagSpaceShowFree", label = "Show Free Slots", toggle = true,
          help = "Free bag slots out of your total, above the row. Hover it for each bag." },
        { key = "bagSpaceStack", label = "Offer to Stack", toggle = true,
          help = "A Stack button on the card when part-filled stacks of an item can be combined." },
        { key = "bagSpacePrices", label = "Show Prices", toggle = true,
          help = "What each stack is worth, in its largest coin, under its icon." },
        { label = "Pick Up Cheapest Item", binding = "NAOWHFOREVER_BAGSPACE_PICKUP",
          help = "Puts the cheapest item on your cursor, to drop or sell." },
        Group("Tooltips"),
        { key = "bagSpaceTipVendor", label = "Tooltip: Vendor Price", toggle = true,
          help = "What the whole stack sells for at a vendor, and each item's price." },
        { key = "bagSpaceTipAuction", label = "Tooltip: Auction Price", toggle = true,
          help = "What the stack fetches at the auction house, from your last Scan Prices or "
              .. "TradeSkillMaster." },
        { key = "bagSpaceTipDelete", label = "Tooltip: Delete Hint", toggle = true,
          help = "The Ctrl-click line, and Click to sell while a vendor is open." },
        { key = "bagSpaceTipIgnore", label = "Tooltip: Ignore Hint", toggle = true, help = "The Middle-click line." },
        Group("Size"),
        { key = "bagSpaceSize", label = "Icon Size", slider = ICON_RANGE },
        { key = "bagSpaceGrow", label = "Direction", choice = DIRECTION },
        { key = "bagSpaceReverse", label = "Reverse Order", toggle = true,
          help = "Puts the cheapest item at the far end of the row instead of next to its anchor." },
        Settings.Look("bagSpace", { text = true, size = TEXT_RANGE, background = "card" }),
        Group("Visibility"),
        { key = "bagSpaceHideCombat", label = "Hide in Combat", toggle = true },
    },
})
