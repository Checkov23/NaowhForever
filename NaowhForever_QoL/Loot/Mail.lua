-- Mail.lua: the mailbox additions: alts for the To box, quick attach, and the expiring mail warning.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local SEND_SLOTS = 12
local DAY = ns.QoLConstants.SECONDS_PER_DAY
local EXPIRY_DAYS = 3
local EXPIRY_WARN = EXPIRY_DAYS * DAY
local WARN_DELAY = 5
local COIN_SIZE = 12
local BUTTON_W, BUTTON_H = 64, 22
local BUTTON_X, BUTTON_Y, BUTTON_GAP = 4, -30, 4
local NO_SUBCLASS = -1
local TRADE_GOODS = Enum.ItemClass.Tradegoods
local GEAR = { [Enum.ItemClass.Weapon] = true, [Enum.ItemClass.Armor] = true }

local TEXT_GOLD = ns.L("Gold on this realm: ")
local TEXT_NO_ALTS = ns.L("Log in on your other characters once and they appear here.")
local TEXT_NO_SURNAME = ns.L("A name without its last name gets it the next time you log in on that character.")
local TEXT_ALT = "%s  |cff808080%d|r  %s"
local TEXT_FULL = ns.L("%s: %d %s didn't fit, all %d attachment slots are full. Send this one and attach again.")
local TEXT_STACK, TEXT_STACKS = ns.L("stack"), ns.L("stacks")
local TEXT_ALL_GOODS = ns.L("All trade goods")
local TEXT_OTHER_GOODS = ns.L("Other trade goods")
local TEXT_GEAR = ns.L("Unbound gear")
local TEXT_ATTACH_TITLE = ns.L("Attach from your bags")
local TEXT_NOTHING = ns.L("No trade goods or unbound gear in your bags.")
local TEXT_ATTACH_ROW = "%s (%d %s)"
local TEXT_EXPIRED = ns.L("may have expired")
local TEXT_UNDER_DAY = ns.L("less than a day")
local TEXT_DAYS = "d"
local TEXT_EXPIRING = ns.L(": mail expiring soon on ")
local TEXT_KEEP = ns.L(". Open the mailbox on those characters to keep it.")
local TEXT_ALTS = ns.L("Alts")
local TEXT_ALTS_TIP = ns.L("Your Characters")
local TEXT_ALTS_HELP = ns.L("Pick one of your characters on this realm and faction to fill the To box. Shows each "
    .. "one's level and gold.")
local TEXT_ATTACH = ns.L("Attach")
local TEXT_ATTACH_TIP = ns.L("Quick Attach")
local TEXT_ATTACH_HELP = ns.L("Attach every trade good, one type of trade good, or your unbound gear from your bags, "
    .. "up to the 12 attachment slots.")

local altsButton, attachButton
local qBag, qSlot, qItem = {}, {}, {}
local qHead, qCount = 1, 0
local pendingSlot, pendingItem, pendingBag, pendingBagSlot
local clicking = false
local counts, labels, order = {}, {}, {}
local events = CreateFrame("Frame")

local function Tag() return ns.Color("accent", "Naowh Mail") end

local function On(key)
    return S.Get("enabled") and S.Get(key)
end

local function Coins(copper)
    return C_CurrencyInfo.GetCoinTextureString(copper, COIN_SIZE)
end

local function Stacks(n)
    return n == 1 and TEXT_STACK or TEXT_STACKS
end

local function OpenAltsMenu(owner)
    local list = ns.AltList()
    local total = GetMoney()
    for _, alt in ipairs(list) do total = total + alt.money end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_GOLD .. Coins(total))
        if #list == 0 then
            root:CreateTitle(TEXT_NO_ALTS, WHITE_FONT_COLOR)
            return
        end
        local firstOnly = false
        for _, alt in ipairs(list) do
            local text = TEXT_ALT:format(ns.ClassColoredName(alt.name, alt.class), alt.level, Coins(alt.money))
            root:CreateButton(text, function()
                SendMailNameEditBox:SetText(alt.name)
                SendMailSubjectEditBox:SetFocus()
            end)
            if not alt.full then firstOnly = true end
        end
        if firstOnly then root:CreateTitle(TEXT_NO_SURNAME, GRAY_FONT_COLOR) end
    end)
end

local function FreeSlot()
    for i = 1, SEND_SLOTS do
        if not HasSendMailItem(i) then return i end
    end
end

local function StopAttaching()
    qHead, qCount = 1, 0
    pendingSlot, pendingItem, pendingBag, pendingBagSlot = nil, nil, nil, nil
    clicking = false
    events:UnregisterEvent("MAIL_SEND_INFO_UPDATE")
    events:UnregisterEvent("MAIL_SEND_SUCCESS")
end

local function Mailable(bag, slot)
    local itemID = C_Container.GetContainerItemID(bag, slot)
    if not itemID then return end
    local _, _, subType, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= TRADE_GOODS and not GEAR[classID] then return end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or info.isBound or info.isLocked or info.itemID ~= itemID then return end
    if GEAR[classID] and (info.quality or 0) < Enum.ItemQuality.Uncommon then return end
    return itemID, classID, subClassID or NO_SUBCLASS, subType
end

local function Matches(key, classID, subClassID)
    if key == "gear" then return GEAR[classID] end
    return classID == TRADE_GOODS and (key == "all" or key == subClassID)
end

local function Landed()
    if not HasSendMailItem(pendingSlot) then return false end
    local _, itemID = GetSendMailItem(pendingSlot)
    return itemID == pendingItem
end

local function StillPending()
    if Landed() then
        pendingSlot = nil
        return false
    end
    local info = C_Container.GetContainerItemInfo(pendingBag, pendingBagSlot)
    if not GetCursorInfo() and not (info and info.isLocked) then StopAttaching() end
    return true
end

local function ReportFull()
    local left = qCount - qHead + 1
    ns.Print(TEXT_FULL:format(Tag(), left, Stacks(left), SEND_SLOTS))
    StopAttaching()
end

local function OnCursor(itemID)
    local kind, cursorID = GetCursorInfo()
    return kind == "item" and cursorID == itemID, kind
end

local function AttachOne(slot, bag, bagSlot, itemID)
    local info = C_Container.GetContainerItemInfo(bag, bagSlot)
    if not (info and info.itemID == itemID and not info.isLocked and not info.isBound) then return true end
    C_Container.PickupContainerItem(bag, bagSlot)
    local held, kind = OnCursor(itemID)
    if not held then
        if kind then ClearCursor() end
        StopAttaching()
        return false
    end
    pendingSlot, pendingItem, pendingBag, pendingBagSlot = slot, itemID, bag, bagSlot
    clicking = true
    ClickSendMailItemButton(slot)
    clicking = false
    if OnCursor(itemID) then
        ClearCursor()
        StopAttaching()
        return false
    end
    return true
end

local function AttachNext()
    if clicking then return end
    while true do
        if pendingSlot and StillPending() then return end
        if qHead > qCount or GetCursorInfo() then
            StopAttaching()
            return
        end
        local slot = FreeSlot()
        if not slot then
            ReportFull()
            return
        end
        local bag, bagSlot, itemID = qBag[qHead], qSlot[qHead], qItem[qHead]
        qHead = qHead + 1
        if not AttachOne(slot, bag, bagSlot, itemID) then return end
    end
end

local function Attach(key)
    StopAttaching()
    local n = 0
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID, classID, subClassID = Mailable(bag, slot)
            if itemID and Matches(key, classID, subClassID) then
                n = n + 1
                qBag[n], qSlot[n], qItem[n] = bag, slot, itemID
            end
        end
    end
    if n == 0 then return end
    qHead, qCount = 1, n
    events:RegisterEvent("MAIL_SEND_INFO_UPDATE")
    events:RegisterEvent("MAIL_SEND_SUCCESS")
    AttachNext()
end

local function Tally(key, label)
    if not counts[key] then
        counts[key] = 0
        labels[key] = label
        order[#order + 1] = key
    end
    counts[key] = counts[key] + 1
end

local function Count()
    wipe(counts)
    wipe(labels)
    wipe(order)
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID, classID, subClassID, subType = Mailable(bag, slot)
            if itemID then
                if classID == TRADE_GOODS then
                    Tally("all", TEXT_ALL_GOODS)
                    Tally(subClassID, subType or TEXT_OTHER_GOODS)
                else
                    Tally("gear", TEXT_GEAR)
                end
            end
        end
    end
end

local function OpenAttachMenu(owner)
    Count()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_ATTACH_TITLE)
        if #order == 0 then
            root:CreateTitle(TEXT_NOTHING, WHITE_FONT_COLOR)
            return
        end
        for _, key in ipairs(order) do
            local n = counts[key]
            root:CreateButton(TEXT_ATTACH_ROW:format(labels[key], n, Stacks(n)), function()
                Attach(key)
            end)
        end
    end)
end

local function TimeLeft(left)
    if left <= 0 then return TEXT_EXPIRED end
    if left < DAY then return TEXT_UNDER_DAY end
    return math.floor(left / DAY) .. TEXT_DAYS
end

local function WarnExpiring()
    local now, soon = time(), {}
    for _, realm in pairs(ns.AccountSettings().alts or {}) do
        for name, c in pairs(realm) do
            if c.mailExpires and (c.mailCount or 0) > 0 and c.mailExpires - now < EXPIRY_WARN then
                soon[#soon + 1] = ns.ClassColoredName(name, c.class) .. " (" .. TimeLeft(c.mailExpires - now) .. ")"
            end
        end
    end
    if #soon > 0 then
        ns.Print(Tag() .. TEXT_EXPIRING .. table.concat(soon, ", ") .. TEXT_KEEP)
    end
end

local function OnAltsClick()
    OpenAltsMenu(altsButton)
end

local function OnAttachClick()
    OpenAttachMenu(attachButton)
end

local function Build()
    if altsButton or not (SendMailFrame and MailFrame) then return end
    altsButton = ns.Button(SendMailFrame, TEXT_ALTS, BUTTON_W, BUTTON_H, OnAltsClick)
    altsButton:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", BUTTON_X, BUTTON_Y)
    ns.Tooltip(altsButton, TEXT_ALTS_TIP, TEXT_ALTS_HELP)
    attachButton = ns.Button(SendMailFrame, TEXT_ATTACH, BUTTON_W, BUTTON_H, OnAttachClick)
    ns.Tooltip(attachButton, TEXT_ATTACH_TIP, TEXT_ATTACH_HELP)
end

local function Place()
    if not altsButton then return end
    altsButton:SetShown(On("mailAlts"))
    attachButton:ClearAllPoints()
    if altsButton:IsShown() then
        attachButton:SetPoint("TOPLEFT", altsButton, "BOTTOMLEFT", 0, -BUTTON_GAP)
    else
        attachButton:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", BUTTON_X, BUTTON_Y)
    end
    attachButton:SetShown(On("mailQuickAttach"))
end

local function OnEvent(_, event, isLogin)
    if event == "MAIL_SEND_INFO_UPDATE" then
        AttachNext()
    elseif event == "MAIL_SHOW" then
        Build()
        Place()
    elseif event == "MAIL_CLOSED" or event == "MAIL_SEND_SUCCESS" then
        StopAttaching()
    elseif event == "PLAYER_ENTERING_WORLD" then
        events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if isLogin then C_Timer.After(WARN_DELAY, WarnExpiring) end
    end
end

local function Apply()
    if On("mailAlts") or On("mailQuickAttach") then
        Build()
        events:RegisterEvent("MAIL_SHOW")
        events:RegisterEvent("MAIL_CLOSED")
    else
        StopAttaching()
        events:UnregisterEvent("MAIL_SHOW")
        events:UnregisterEvent("MAIL_CLOSED")
    end
    Place()
end

local function OnLogin()
    Apply()
    if On("mailExpiry") then events:RegisterEvent("PLAYER_ENTERING_WORLD") end
end

local function ForgetCharacter()
    ns.OpenForgetAltMenu(UIParent)
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "mailAlts" or key == "mailQuickAttach" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "mailAlts", name = "Mail & Alts", order = 40, into = "lootTrade",
    rows = {
        { key = "altCounts", label = "Alt Item Counts", toggle = true,
          help = "Item tooltips show how many your characters on this realm and faction hold in "
              .. "their bags, bank and mailbox. Each character is counted once you log in on it, "
              .. "and its bank once you open it." },
        { key = "mailAlts", label = "Alts Button on Mail", toggle = true,
          help = "An Alts button beside the mailbox's Send tab lists your characters on this realm "
              .. "and faction with their level and gold. Pick one to fill the To box." },
        { key = "mailQuickAttach", label = "Quick Attach", toggle = true,
          help = "An Attach button beside the mailbox's Send tab: attach every trade good, one type "
              .. "of trade good, or your unbound gear in one click." },
        { key = "mailExpiry", label = "Mail Expiry Warning", toggle = true,
          help = "At login, names any of your characters with mail that expires within three days. "
              .. "It knows each character's mail from the last time it opened a mailbox." },
        { label = "Forget a Character", button = ForgetCharacter, buttonText = "Forget",
          help = "Removes a deleted or transferred character from the counts and the Alts list." },
    },
})
