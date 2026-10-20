-- Alts.lua: your characters per realm and faction, kept for the mail features and Alt Item Counts.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local MAIL_ATTACHMENTS = 16
local MAX_TOOLTIP_ROWS = 8
local SECONDS_PER_DAY = ns.QoLConstants.SECONDS_PER_DAY
local MAIL_SCAN_DELAY = 1
local REALM_JOIN = "-"
local GREY_CODE = "|cff808080"
local WHITE = ns.QoLConstants.WHITE_RGB
local PLACE_RGB = { r = 0.8, g = 0.8, b = 0.8 }
local LIST_JOIN, INDENT = ", ", "  "
local TEXT_BAGS, TEXT_BANK, TEXT_MAIL = ns.L(" bags"), ns.L(" bank"), ns.L(" mail")
local TEXT_OWNED = ns.L("Total owned")
local TEXT_FORGET_TITLE = ns.L("Forget a character")
local TEXT_NONE = ns.L("No characters recorded yet.")
local TEXT_FORGET = ns.L("Forget %s on %s? It comes back the next time you log in on it with a Mail & Alts option on.")
local APPLY_KEYS = { enabled = true, altCounts = true, mailAlts = true, mailExpiry = true }

local realmKey, me, bankOpen, mailPending

local function CountsOn()
    return S.Get("enabled") and S.Get("altCounts")
end

local function RosterOn()
    return S.Get("enabled") and (S.Get("altCounts") or S.Get("mailAlts") or S.Get("mailExpiry"))
end

function ns.AltRealm()
    local account = ns.AccountSettings()
    account.alts = account.alts or {}
    realmKey = realmKey or GetRealmName() .. REALM_JOIN .. (UnitFactionGroup("player") or "")
    account.alts[realmKey] = account.alts[realmKey] or {}
    return account.alts[realmKey]
end

function ns.AltName()
    me = me or (GetUnitName("player", true)):match("^[^-]+")
    return me
end

local function Me()
    local realm = ns.AltRealm()
    local name = ns.AltName()
    local first = UnitName("player")
    local old = first ~= name and realm[first]
    if not realm[name] and old and old.class == select(2, UnitClass("player")) then
        realm[name], realm[first] = old, nil
    end
    realm[name] = realm[name] or {}
    realm[name].full = true
    return realm[name]
end

function ns.ClassColoredName(name, class)
    local color = class and C_ClassColor.GetClassColor(class)
    return color and color:WrapTextInColorCode(name) or name
end

local function AskForget(all, realm, chars, name)
    ns.Confirm(TEXT_FORGET:format(name, realm), function()
        chars[name] = nil
        if not next(chars) then all[realm] = nil end
    end)
end

local function FillForgetMenu(root, all)
    root:CreateTitle(TEXT_FORGET_TITLE)
    local any = false
    for realm, chars in pairs(all) do
        for name, c in pairs(chars) do
            any = true
            root:CreateButton(ns.ClassColoredName(name, c.class) .. INDENT .. GREY_CODE .. realm .. "|r", function()
                AskForget(all, realm, chars, name)
            end)
        end
    end
    if not any then root:CreateTitle(TEXT_NONE, WHITE_FONT_COLOR) end
end

function ns.OpenForgetAltMenu(owner)
    local all = ns.AccountSettings().alts or {}
    MenuUtil.CreateContextMenu(owner, function(_, root) FillForgetMenu(root, all) end)
end

local function UpdateRoster()
    local c = Me()
    c.class = select(2, UnitClass("player"))
    c.level = UnitLevel("player")
    c.money = GetMoney()
end

local function Count(into, first, last)
    for bag = first, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                into[info.itemID] = (into[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return into
end

local function Emptied(c, key)
    local t = c[key]
    if type(t) ~= "table" then
        t = {}
        c[key] = t
    end
    wipe(t)
    return t
end

local function ScanBags()
    Count(Emptied(Me(), "bags"), BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS)
end

local function ScanBank()
    Count(Emptied(Me(), "bank"), Enum.BagIndex.CharacterBankTab_1, Enum.BagIndex.CharacterBankTab_9)
end

local function CountAttachments(items, letter)
    for a = 1, MAIL_ATTACHMENTS do
        local _, itemID, _, count = GetInboxItem(letter, a)
        if itemID then items[itemID] = (items[itemID] or 0) + (count or 1) end
    end
end

local function ScanMail()
    mailPending = nil
    if not RosterOn() then return end
    local shown, total = GetInboxNumItems()
    local items, soonest, now = {}, nil, time()
    for i = 1, shown do
        local _, _, _, _, _, _, daysLeft, itemCount = GetInboxHeaderInfo(i)
        if daysLeft then
            local expires = now + math.floor(daysLeft * SECONDS_PER_DAY)
            if not soonest or expires < soonest then soonest = expires end
        end
        if itemCount and itemCount > 0 then CountAttachments(items, i) end
    end
    local c = Me()
    c.mail, c.mailCount, c.mailExpires = items, total or shown, soonest
end

local function OnEvent(_, event, arg)
    if event == "BAG_UPDATE_DELAYED" then
        ScanBags()
        if bankOpen then ScanBank() end
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        ScanBank()
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = nil
    elseif event == "MAIL_INBOX_UPDATE" then
        if not mailPending then
            mailPending = true
            C_Timer.After(MAIL_SCAN_DELAY, ScanMail)
        end
    elseif event == "PLAYER_LEVEL_UP" then
        Me().level = arg
    else
        UpdateRoster()
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)

local function Apply()
    events:UnregisterAllEvents()
    if not RosterOn() then return end
    UpdateRoster()
    events:RegisterEvent("PLAYER_MONEY")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("MAIL_INBOX_UPDATE")
    if CountsOn() then
        ScanBags()
        events:RegisterEvent("BAG_UPDATE_DELAYED")
        events:RegisterEvent("BANKFRAME_OPENED")
        events:RegisterEvent("BANKFRAME_CLOSED")
    end
end

local function OnSettingChanged(key)
    if APPLY_KEYS[key] then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local function ByLevelThenName(a, b)
    if a.level ~= b.level then return a.level > b.level end
    return a.name < b.name
end

function ns.AltList()
    local list, mine = {}, ns.AltName()
    for name, c in pairs(ns.AltRealm()) do
        if name ~= mine then
            list[#list + 1] = { name = name, class = c.class, level = c.level or 0, money = c.money or 0,
                full = c.full == true }
        end
    end
    table.sort(list, ByLevelThenName)
    return list
end

local rows, rowPool = {}, {}

local function Where(c, id)
    local bags, bank, mail = c.bags and c.bags[id] or 0, c.bank and c.bank[id] or 0, c.mail and c.mail[id] or 0
    local text
    if bags > 0 then text = bags .. TEXT_BAGS end
    if bank > 0 then text = (text and text .. LIST_JOIN or "") .. bank .. TEXT_BANK end
    if mail > 0 then text = (text and text .. LIST_JOIN or "") .. mail .. TEXT_MAIL end
    return bags + bank + mail, text or "", bank > 0 or mail > 0
end

local function MostFirst(a, b)
    return a.count > b.count
end

local function Row(n)
    local r = rowPool[n]
    if not r then
        r = {}
        rowPool[n] = r
    end
    rows[n] = r
    return r
end

local function Gather(id)
    local mine, total, elsewhere, n = ns.AltName(), 0, false, 0
    wipe(rows)
    for name, c in pairs(ns.AltRealm()) do
        local count, text, away = Where(c, id)
        if count > 0 then
            total = total + count
            if name ~= mine or away then elsewhere = true end
            n = n + 1
            local r = Row(n)
            r.name, r.class, r.count, r.text = name, c.class, count, text
        end
    end
    return total, elsewhere
end

local function OnItemTooltip(tooltip, data)
    if not CountsOn() then return end
    local id = data and data.id
    if not id or (issecretvalue and issecretvalue(id)) then return end
    local total, elsewhere = Gather(id)
    if not elsewhere then return end
    table.sort(rows, MostFirst)
    tooltip:AddDoubleLine(TEXT_OWNED, total, WHITE.r, WHITE.g, WHITE.b, WHITE.r, WHITE.g, WHITE.b)
    for i = 1, math.min(#rows, MAX_TOOLTIP_ROWS) do
        local r = rows[i]
        tooltip:AddDoubleLine(INDENT .. ns.ClassColoredName(r.name, r.class), r.text, WHITE.r, WHITE.g, WHITE.b,
            PLACE_RGB.r, PLACE_RGB.g, PLACE_RGB.b)
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
