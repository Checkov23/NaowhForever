-- LootFeed.lua: the QoL loot feed, gold per hour, and quick loot with the loot window out of sight.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Parts = ns.Shared.Parts
local T = ns.THEME

local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local XP_ICON = "Interface\\Icons\\INV_Misc_Book_11"
local QUEST_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local REP_ICON = "Interface\\Icons\\INV_BannerPVP_02"
local XP_COLOR, REP_COLOR = "|cffb48ef9", "|cff4fc3f7"
local STYLES = {
    dark  = { bg = { 0.05, 0.05, 0.06, 0.8 }, edge = { 0, 0, 0, 1 } },
    light = { bg = { 0.32, 0.23, 0.14, 0.7 }, edge = { 0.12, 0.08, 0.04, 1 } },
}

local DARK_BG = { r = 0.05, g = 0.05, b = 0.06 }
local LIGHT_BG = { r = 0.32, g = 0.23, b = 0.14 }
local LIGHT_EDGE = { r = 0.12, g = 0.08, b = 0.04 }
local GLOW = { r = 1, g = 0.8, b = 0.3 }
local GPH_RGB = { r = 1, g = 0.82, b = 0 }
local ICON_CROP_LOW, ICON_CROP_HIGH = ns.QoLConstants.ICON_CROP, ns.QoLConstants.ICON_CROP_HIGH
local ICON_INSET = 1
local GLOW_ALPHA, GLOW_W = 0.7, 12
local BAGS_SIZE, COIN_SIZE, VALUE_SIZE, NAME_SIZE, GPH_SIZE = 11, 12, 12, 13, 13
local BAGS_INSET = 2
local NAME_GAP, NAME_VALUE_GAP = 10, 8
local MIN_BAGS_SIZE, BAGS_SHRINK = 8, 2
local ROUND = ns.QoLConstants.ROUND
local COPPER_PER_SILVER, COPPER_PER_GOLD = 100, 10000
local SEPARATE_FROM = 1000
local HOUR = ns.QoLConstants.SECONDS_PER_HOUR
local MIN_HOURS = 1 / 60
local APPEAR_TIME, FADE_TIME = 0.15, 0.4
local LOOT_STEP, LOOT_GRACE = 0.05, 1
local SHRUNK = 0.001
local DEFAULT_X, DEFAULT_Y = -469, -141
local DISPLAY_TIME_RANGE = { 0.5, 10, 0.5 }
local TSM_SOURCE = "dbminbuyout"
local EVENTS = { "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_COMBAT_XP_GAIN",
    "CHAT_MSG_COMBAT_FACTION_CHANGE", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED" }

local TEXT_COINS = ns.L("Coins")
local TEXT_PER_HOUR = ns.L("%dg %ds %dc/Hr")
local TEXT_ITEM = "|c%s%s|r |cff20ff20x%d|r"
local TEXT_QUEST = ns.L("Quest Complete")
local TEXT_QUEST_XP = ns.L(" XP|r")
local TEXT_REP = ns.L(" Rep|r")
local TEXT_MOVER = "Loot Feed"
local TEXT_FADES = ns.L("Each line fades out after %ss.")
local TEXT_SUMMARY = ns.L("%d lines, %s%s")
local TEXT_NO_BACKGROUND, TEXT_LIGHT, TEXT_DARK = ns.L("no background"), ns.L("light"), ns.L("dark")
local TEXT_GPH = ns.L(", gold per hour")
local TEXT_EDIT = ns.L("Edit the Feed")
local TEXT_LINES_SHOW = ns.L("Lines Show")
local TEXT_GLOW = ns.L("Glow")

local feed, gph, unlocked
local rows, pool = {}, {}
local coinRow
local sessionStart, sessionValue = nil, 0
local lootHidden, lootScale, lootHooked
local lootGen = 0
local events = CreateFrame("Frame")
local lootWatch = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("lootFeed")
end

local PATTERNS = {}
for _, fmt in ipairs({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_SELF,
                       LOOT_ITEM_PUSHED_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF }) do
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    PATTERNS[#PATTERNS + 1] = "^" .. p .. "$"
end

local GOLD = GOLD_AMOUNT:gsub("%%d", "(%%d+)")
local SILVER = SILVER_AMOUNT:gsub("%%d", "(%%d+)")
local COPPER = COPPER_AMOUNT:gsub("%%d", "(%%d+)")

local REP_PATTERN = "^" .. FACTION_STANDING_INCREASED:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    :gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
local UNNAMED_XP = COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED and "^" .. COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED
    :gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%d", "(%%d+)")

local COIN_TEXTURES = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon" }
local SAMPLE_PANTS, SAMPLE_CLOTH, SAMPLE_COINS, SAMPLE_PER_HOUR = 94, 39, 31250, 412550
local SAMPLE_PANTS_BAGS, SAMPLE_CLOTH_BAGS, SAMPLE_CLOTH_BANK = 1, 7, 27
local PANTS_ICON = "Interface\\Icons\\INV_Pants_04"
local CLOTH_ICON = "Interface\\Icons\\INV_Fabric_Linen_01"
local SAMPLE_PANTS_NAME = ns.L("|cff1eff00Journeyman's Pants|r |cff20ff20x1|r")
local SAMPLE_CLOTH_NAME = ns.L("|cffffffffLinen Cloth|r |cff20ff20x3|r")
local VALUE_INSET, COIN_GAP, PAIR_GAP = 8, 2, 5
local GPH_GAP = 10

local Look = {}

function Look.NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.border = ns.Border(row)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", ICON_INSET, 0)
    row.icon:SetTexCoord(ICON_CROP_LOW, ICON_CROP_HIGH, ICON_CROP_LOW, ICON_CROP_HIGH)

    row.glow = row:CreateTexture(nil, "ARTWORK")
    row.glow:SetColorTexture(1, 1, 1, 1)
    local glow = ns.ThemeTint("accent", GLOW)
    row.glow:SetGradient("HORIZONTAL", CreateColor(glow.r, glow.g, glow.b, GLOW_ALPHA), CreateColor(glow.r, glow.g, glow.b, 0))
    row.glow:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 0, 0)
    row.glow:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 0, 0)
    row.glow:SetWidth(GLOW_W)

    row.bags = ns.Font(row, BAGS_SIZE, "OUTLINE")
    row.bags:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMLEFT", BAGS_INSET, BAGS_INSET)

    row.coins = {}
    for i = 1, #COIN_TEXTURES do
        local pair = { icon = row:CreateTexture(nil, "ARTWORK"), amount = ns.Font(row, COIN_SIZE, "OUTLINE") }
        pair.icon:SetTexture(COIN_TEXTURES[i])
        pair.amount:SetPoint("RIGHT", pair.icon, "LEFT", -COIN_GAP, 0)
        row.coins[i] = pair
    end
    row.value = ns.Font(row, VALUE_SIZE, "OUTLINE")
    row.value:SetPoint("RIGHT", -VALUE_INSET, 0)
    row.name = ns.Font(row, NAME_SIZE, "OUTLINE")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -NAME_VALUE_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

function Look.Size(row, w, h)
    row:SetSize(w, h)
    row.icon:SetSize(h - 2 * ICON_INSET, h - 2 * ICON_INSET)
end

function Look.StyleRow(row)
    local style = S.Get("lootFeedStyle")
    local bare = style == "none"
    row.bg:SetShown(not bare)
    row.border._frame:SetShown(not bare)
    local st = STYLES[style] or STYLES.dark
    if st == STYLES.dark then
        local c = ns.ThemeTint("bg", DARK_BG)
        row.bg:SetColorTexture(c.r, c.g, c.b, st.bg[4])
        row.border:SetColor(unpack(st.edge))
    else
        local c, e = ns.ThemeTint("panel", LIGHT_BG), ns.ThemeTint("line", LIGHT_EDGE)
        row.bg:SetColorTexture(c.r, c.g, c.b, st.bg[4])
        row.border:SetColor(e.r, e.g, e.b, st.edge[4])
    end
    row.glow:SetShown(S.Get("lootFeedGlow"))
    local size, font, outline = S.Get("lootFeedFontSize"), S.Get("lootFeedFont"), S.Get("lootFeedOutline")
    local shadow = bare and "none" or "card"
    Look.Size(row, S.Get("lootFeedWidth"), S.Get("lootFeedHeight"))
    Parts.HudFont(row.name, font, size, outline, shadow)
    Parts.HudFont(row.value, font, size - 1, outline, shadow)
    for _, pair in ipairs(row.coins) do
        Parts.HudFont(pair.amount, font, size - 1, outline, shadow)
        pair.icon:SetSize(size - 1, size - 1)
    end
    Parts.HudFont(row.bags, font, math.max(MIN_BAGS_SIZE, size - BAGS_SHRINK), outline, shadow)
end

local function CoinPair(pair, amount, anchor)
    if amount <= 0 then
        pair.icon:Hide()
        pair.amount:Hide()
        return anchor
    end
    pair.icon:ClearAllPoints()
    if anchor then
        pair.icon:SetPoint("RIGHT", anchor, "LEFT", -PAIR_GAP, 0)
    else
        pair.icon:SetPoint("RIGHT", pair.icon:GetParent(), "RIGHT", -VALUE_INSET, 0)
    end
    pair.amount:SetText(amount >= SEPARATE_FROM and BreakUpLargeNumbers(amount) or amount)
    pair.icon:Show()
    pair.amount:Show()
    return pair.amount
end

function Look.Coins(row, copper)
    copper = copper or 0
    local left = CoinPair(row.coins[3], copper % COPPER_PER_SILVER, nil)
    left = CoinPair(row.coins[2], math.floor(copper / COPPER_PER_SILVER) % COPPER_PER_SILVER, left)
    left = CoinPair(row.coins[1], math.floor(copper / COPPER_PER_GOLD), left)
    row.value:ClearAllPoints()
    if left then
        row.value:SetPoint("RIGHT", left, "LEFT", -PAIR_GAP, 0)
    else
        row.value:SetPoint("RIGHT", row, "RIGHT", -VALUE_INSET, 0)
    end
end

function Look.Fill(row, icon, name, value, bags, copper)
    row.icon:SetTexture(icon)
    row.name:SetText(name)
    row.value:SetText(value or "")
    row.bags:SetText(bags or "")
    Look.Coins(row, copper)
end

function Look.Gap(holder)
    local spacing = S.Get("lootFeedSpacing")
    if spacing < 0 then return spacing * ns.OnePixel(holder) end
    return spacing
end

function Look.Stack(list, holder, height)
    local step = (height or S.Get("lootFeedHeight")) + Look.Gap(holder)
    local down = S.Get("lootFeedGrowth") == "down"
    local point = down and "TOP" or "BOTTOM"
    if down then step = -step end
    for i, row in ipairs(list) do
        row:ClearAllPoints()
        row:SetPoint(point, holder, point, 0, (i - 1) * step)
    end
end

function Look.GPHFont(text)
    Parts.HudFont(text, S.Get("lootFeedFont"), S.Get("lootFeedFontSize"), S.Get("lootFeedOutline"), "none")
end

function Look.GPH(text, newest, per)
    text:SetText(TEXT_PER_HOUR:format(math.floor(per / COPPER_PER_GOLD), math.floor(per / COPPER_PER_SILVER) % COPPER_PER_SILVER,
        per % COPPER_PER_SILVER))
    text:ClearAllPoints()
    text:SetPoint("LEFT", newest, "RIGHT", GPH_GAP, 0)
end

local function PerHour()
    local hours = (GetTime() - sessionStart) / HOUR
    return math.floor(sessionValue / math.max(hours, MIN_HOURS))
end

local function AddSessionValue(copper)
    if not sessionStart then sessionStart = GetTime() end
    sessionValue = sessionValue + copper
end

function ns.ResetLootFeedSession()
    sessionStart, sessionValue = nil, 0
    if gph then gph:Hide() end
end

local function UnitPrice(link, vendor)
    if S.Get("lootFeedPrice") == "ahscan" then
        local price = ns.AuctionPrice(C_Item.GetItemInfoInstant(link))
        if price then return price end
    end
    if S.Get("lootFeedPrice") == "tsm" and TSM_API and TSM_API.GetCustomPriceValue then
        local ok, value = pcall(TSM_API.GetCustomPriceValue, TSM_SOURCE, TSM_API.ToItemString(link))
        if ok and value then return value end
    end
    return vendor or 0
end

local function Layout()
    Look.Stack(rows, feed)
    local newest = rows[1]
    if gph and newest and S.Get("lootFeedGPH") and sessionStart then
        Look.GPH(gph, newest, PerHour())
        gph:Show()
    elseif gph then
        gph:Hide()
    end
end

local function Release(row)
    row.anim:Stop()
    row:Hide()
    row.link = nil
    if row == coinRow then coinRow = nil end
    for i = #rows, 1, -1 do
        if rows[i] == row then table.remove(rows, i) end
    end
    pool[#pool + 1] = row
    Layout()
end

local function OnRowEnter(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
end

local function OnRowLeave()
    GameTooltip:Hide()
end

local function NewRow()
    local row = Look.NewRow(feed)

    row.anim = row:CreateAnimationGroup()
    row.appear = row.anim:CreateAnimation("Alpha")
    row.appear:SetToAlpha(1)
    row.appear:SetDuration(APPEAR_TIME)
    row.fade = row.anim:CreateAnimation("Alpha")
    row.fade:SetFromAlpha(1)
    row.fade:SetToAlpha(0)
    row.fade:SetDuration(FADE_TIME)
    row.fade:SetOrder(2)
    row.anim:SetScript("OnFinished", function() Release(row) end)

    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", OnRowLeave)
    return row
end

local function Push(icon, name, value, bags, link, copper)
    local row = table.remove(pool) or NewRow()
    Look.StyleRow(row)
    Look.Fill(row, icon, name, value, bags, copper)
    row.link = link
    row:EnableMouse(link ~= nil)
    row:SetAlpha(1)
    row:Show()
    table.insert(rows, 1, row)
    while #rows > S.Get("lootFeedCount") do Release(rows[#rows]) end
    row.appear:SetFromAlpha(0)
    row.fade:SetStartDelay(S.Get("lootFeedFade"))
    row.anim:Restart()
    Layout()
    return row
end

local function OnItem(link, count)
    local item = Item:CreateFromItemLink(link)
    if item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function()
        local _, _, quality, _, _, _, _, _, _, texture, sellPrice = C_Item.GetItemInfo(link)
        if not quality or quality < S.Get("lootFeedQuality") then return end
        local worth = UnitPrice(link, sellPrice) * count
        AddSessionValue(worth)
        local bags = C_Item.GetItemCount(link, S.Get("lootFeedBank"))
        bags = bags > 0 and bags or nil
        local _, _, _, hex = C_Item.GetItemQualityColor(quality)
        local function Named(total)
            local name = TEXT_ITEM:format(hex, item:GetItemName(), total)
            local pick = ns.IsBisItem and ns.IsBisItem(item:GetItemID())
            if pick then name = name .. "  " .. ns.Color("accent", "BiS" .. (pick > 1 and " #" .. pick or "")) end
            return name
        end
        for _, row in ipairs(rows) do
            if row.link == link then
                row.count, row.worth = row.count + count, row.worth + worth
                Look.Fill(row, texture, Named(row.count), nil, bags,
                    S.Get("lootFeedValue") and row.worth or nil)
                row.appear:SetFromAlpha(1)
                row.fade:SetStartDelay(S.Get("lootFeedFade"))
                row.anim:Restart()
                Layout()
                return
            end
        end
        local row = Push(texture, Named(count), nil, bags, link,
            S.Get("lootFeedValue") and worth or nil)
        row.count, row.worth = count, worth
    end)
end

local function RefreshBags()
    for _, row in ipairs(rows) do
        if row.link then
            local bags = C_Item.GetItemCount(row.link, S.Get("lootFeedBank"))
            row.bags:SetText(bags > 0 and bags or "")
        end
    end
end

local function OnMoney(copper)
    AddSessionValue(copper)
    if not S.Get("lootFeedMoney") then return end
    if coinRow then
        coinRow.copper = coinRow.copper + copper
        Look.Coins(coinRow, coinRow.copper)
        coinRow.appear:SetFromAlpha(1)
        coinRow.fade:SetStartDelay(S.Get("lootFeedFade"))
        coinRow.anim:Restart()
        Layout()
        return
    end
    coinRow = Push(COIN_ICON, TEXT_COINS, nil, nil, nil, copper)
    coinRow.copper = copper
end

local function MoneyMessage(text)
    local copper = (tonumber(text:match(GOLD)) or 0) * COPPER_PER_GOLD
        + (tonumber(text:match(SILVER)) or 0) * COPPER_PER_SILVER
        + (tonumber(text:match(COPPER)) or 0)
    if copper > 0 then OnMoney(copper) end
end

local function KillXP(text)
    if UNNAMED_XP and S.Get("lootFeedQuest") and text:match(UNNAMED_XP) then return end
    local gained = tonumber(text:match("(%d+)"))
    if gained and gained > 0 then
        Push(XP_ICON, XP_COLOR .. "Experience|r", XP_COLOR .. "+" .. BreakUpLargeNumbers(gained) .. "|r")
    end
end

local function QuestTurnedIn(questID, xp, money)
    if money > 0 then AddSessionValue(money) end
    if xp <= 0 and money <= 0 then return end
    local xpText = xp > 0 and (XP_COLOR .. "+" .. BreakUpLargeNumbers(xp) .. TEXT_QUEST_XP) or nil
    local title = C_QuestLog.GetTitleForQuestID(questID) or TEXT_QUEST
    Push(QUEST_ICON, "|cffffd100" .. title .. "|r", xpText, nil, nil, money)
end

local function Reputation(text)
    local faction, amount = text:match(REP_PATTERN)
    if faction then
        Push(REP_ICON, REP_COLOR .. faction .. "|r", REP_COLOR .. "+" .. amount .. TEXT_REP)
    end
end

local function LootMessage(text)
    for _, pattern in ipairs(PATTERNS) do
        local link, count = text:match(pattern)
        if link then
            OnItem(link, tonumber(count) or 1)
            return
        end
    end
end

local function OnEvent(_, event, text, ...)
    if event == "BAG_UPDATE_DELAYED" then
        RefreshBags()
        return
    end
    if event == "QUEST_TURNED_IN" then
        if S.Get("lootFeedQuest") then QuestTurnedIn(text, ...) end
        return
    end
    if issecretvalue and issecretvalue(text) then return end
    if event == "CHAT_MSG_LOOT" then
        LootMessage(text)
    elseif event == "CHAT_MSG_MONEY" then
        MoneyMessage(text)
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        if S.Get("lootFeedXP") then KillXP(text) end
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        if S.Get("lootFeedRep") then Reputation(text) end
    end
end

local function HideWindowOn()
    return S.Get("hideLootWindow") and not ns.GamepadStandDown()
end

local function AllTakeable()
    local threshold = IsInGroup() and GetLootThreshold()
    local items = 0
    for i = 1, GetNumLootItems() do
        local _, _, _, currencyID, quality, locked, _, _, _, isCoin = GetLootSlotInfo(i)
        if locked then return false end
        if not (isCoin or currencyID) then
            items = items + 1
            if threshold and quality and quality >= threshold then return false end
        end
    end
    local free = 0
    for bag = 0, NUM_BAG_SLOTS do free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0) end
    return items <= free
end

local function ShrinkLootWindow()
    if not lootScale then
        lootScale = LootFrame:GetScale()
        LootFrame:SetScale(SHRUNK)
    end
end

local function RestoreLootWindow()
    if lootScale then
        LootFrame:SetScale(lootScale)
        lootScale = nil
    end
end

local function ShowLootWindow()
    lootHidden = false
    RestoreLootWindow()
end

local function OnLootReady()
    if IsShiftKeyDown() then return end
    lootWatch:RegisterEvent("UI_ERROR_MESSAGE")
    lootHidden = HideWindowOn() and AllTakeable()
    lootGen = lootGen + 1
    local gen = lootGen
    local count = GetNumLootItems()
    for i = 1, count do
        C_Timer.After(LOOT_STEP * i, function()
            if gen == lootGen then LootSlot(i) end
        end)
    end
    C_Timer.After(LOOT_STEP * count + LOOT_GRACE, function()
        if gen == lootGen then ShowLootWindow() end
    end)
end

local function OnLootWindowOpen()
    if lootHidden then ShrinkLootWindow() else RestoreLootWindow() end
end

lootWatch:SetScript("OnEvent", function(_, event, _, arg2)
    if event == "LOOT_READY" then
        OnLootReady()
    elseif event == "LOOT_CLOSED" then
        lootGen = lootGen + 1
        lootHidden = false
        lootWatch:UnregisterEvent("UI_ERROR_MESSAGE")
    elseif event == "UI_ERROR_MESSAGE" and arg2 == ERR_INV_FULL then
        ShowLootWindow()
    end
end)

local function ApplyLootWindow()
    if not HideWindowOn() then ShowLootWindow() end
    if S.Get("enabled") and (HideWindowOn() or S.Get("fastLoot")) then
        if not lootHooked and not ns.GamepadStandDown() then
            lootHooked = true
            hooksecurefunc(LootFrame, "Open", OnLootWindowOpen)
            LootFrame.HideAnim:HookScript("OnFinished", RestoreLootWindow)
        end
        lootWatch:RegisterEvent("LOOT_READY")
        lootWatch:RegisterEvent("LOOT_CLOSED")
    else
        lootWatch:UnregisterAllEvents()
        lootGen = lootGen + 1
        ShowLootWindow()
    end
end

local function PlaceFeed()
    local pos = S.Get("lootFeedPos")
    feed:ClearAllPoints()
    if pos then
        feed:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        feed:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
    end
end

local function CreateFeed()
    feed = CreateFrame("Frame", "NaowhForeverLootFeed", UIParent)
    feed:SetMovable(true)
    feed:SetClampedToScreen(true)
    gph = ns.Font(feed, GPH_SIZE, "OUTLINE", GPH_RGB)
    gph:Hide()
    feed.mover = ns.UI.AttachMover(feed, TEXT_MOVER, function(pos) S.Set("lootFeedPos", pos) end, "QoL/Loot & Items", "QoL/Loot & Items:lootFeed")
    PlaceFeed()
end

local function Apply()
    ApplyLootWindow()
    if not On() then
        events:UnregisterAllEvents()
        if feed then
            for i = #rows, 1, -1 do Release(rows[i]) end
            feed.mover:Hide()
        end
        return
    end
    if not feed then CreateFeed() end
    feed:SetSize(S.Get("lootFeedWidth"), S.Get("lootFeedHeight"))
    Look.GPHFont(gph)
    PlaceFeed()
    for _, e in ipairs(EVENTS) do events:RegisterEvent(e) end
    for _, row in ipairs(rows) do Look.StyleRow(row) end
    feed.mover:SetShown(unlocked == true)
    Layout()
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "hideLootWindow" or key == "fastLoot"
        or (key:find("^lootFeed") and key ~= "lootFeedPos") then
        Apply()
    end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = true
    if On() then
        Apply()
        Push(COIN_ICON, TEXT_COINS, nil, nil, nil, SAMPLE_COINS)
        Push(PANTS_ICON, SAMPLE_PANTS_NAME, nil, SAMPLE_PANTS_BAGS, nil, SAMPLE_PANTS)
    end
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if feed then feed.mover:Hide() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group
local QUALITY = { { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }, { 0, 1, 2, 3, 4 } }
local STYLE = { { dark = "Dark", light = "Light", none = "None" }, { "dark", "light", "none" } }
local PRICE = { { vendor = "Vendor Price", ahscan = "Auction (Naowh Scan)", tsm = "Auction (TSM)" },
    { "vendor", "ahscan", "tsm" } }
local GROWTH = { { up = "Up", down = "Down" }, { "up", "down" } }

local FADING = { 1, 0.6, 0.25 }
local ITEM_ROWS = 2
local STAGE_H, STAGE_MARGIN, TEXT_ROOM = 220, 14, 58
local NOTE_Y, NOTE_SIZE, NOTE_GAP = 8, ns.Shared.Style.STAGE_NOTE_SIZE, 4
local EDIT_LEVEL, TOP_LEVEL = 10, 12
local EDGE_HIT, EDGE_LINE = 6, 2
local VALUE_PAD, VALUE_ROOM = 6, 48
local HOVER_ALPHA = 0.12
local WIDTH_RANGE, HEIGHT_RANGE, SPACING_RANGE = { 200, 600, 5 }, { 20, 64, 1 }, { -1, 20, 1 }
local SIZE_RANGE, COUNT_RANGE = ns.Shared.Style.HUD_TEXT_RANGE, { 3, 12, 1 }
local HINT = ns.L("Drag the right edge for width, a line's bottom for height. Wheel: text size (Shift: spacing, "
    .. "Ctrl: lines). Right-click a line for what it shows.")
local OFF_HINT = ns.L("Turn on the Loot Feed to edit it here.")
local QOL_OFF_HINT = ns.L("Turn on QoL to edit the Loot Feed here.")
local TIP_VALUE = "%s (%d)"
local STATES = {
    { key = "looting", label = "Looting", tip = "Lines as they come in, newest at the anchor." },
    { key = "fading", label = "Fading", tip = "Older lines fading out after the display time." },
}
local TIPS = {
    { "width", ns.L("Drag the right edge"), ns.L("Width"), "lootFeedWidth" },
    { "height", ns.L("Drag a line's bottom edge"), ns.L("Line Height"), "lootFeedHeight" },
    { "lines", ns.L("Wheel"), ns.L("Font Size"), "lootFeedFontSize" },
    { "lines", ns.L("Shift + wheel"), ns.L("Spacing"), "lootFeedSpacing" },
    { "lines", ns.L("Ctrl + wheel"), ns.L("Lines Shown"), "lootFeedCount" },
    { "value", ns.L("Click the value"), ns.L("Show Item Value") },
    { "bags", ns.L("Click the bag count"), ns.L("Count Bank Items") },
    { "lines", ns.L("Right-click a line"), ns.L("What Lines Show") },
}
local LINE_TOGGLES = {
    { "lootFeedMoney", ns.L("Show Money") },
    { "lootFeedQuest", ns.L("Show Quest Rewards") },
    { "lootFeedRep", ns.L("Show Reputation") },
    { "lootFeedXP", ns.L("Show Kill Experience") },
}

local function Choices(title, key, choice)
    local list = { title = title }
    for i, value in ipairs(choice[2]) do list[i] = { key = key, value = value, label = choice[1][value] } end
    return list
end

local RADIOS = { Choices("Style", "lootFeedStyle", STYLE), Choices("Outline", "lootFeedOutline", Parts.HUD_OUTLINES),
    Choices("Growth Direction", "lootFeedGrowth", GROWTH) }

local function Snap(v, range)
    local low, high, step = range[1], range[2], range[3]
    v = low + math.floor((v - low) / step + ROUND) * step
    return math.max(low, math.min(high, v))
end

local function HideTip(preview)
    if GameTooltip:GetOwner() == preview.feed then GameTooltip:Hide() end
end

local function ShowTip(preview)
    local part, fg = preview.part, T.fg
    GameTooltip:SetOwner(preview.feed, "ANCHOR_RIGHT")
    GameTooltip:AddLine(TEXT_EDIT, fg.r, fg.g, fg.b)
    for i = 1, #TIPS do
        local tip = TIPS[i]
        local c = tip[1] == part and T.accent or T.muted
        local right = tip[4] and TIP_VALUE:format(tip[3], S.Get(tip[4])) or tip[3]
        GameTooltip:AddDoubleLine(tip[2], right, c.r, c.g, c.b, c.r, c.g, c.b)
    end
    GameTooltip:Show()
end

local function Unhover(preview)
    preview.part = nil
    local hits = preview.hits
    for i = 1, #hits do
        local hit = hits[i]
        if hit.wash then hit.wash:Hide() end
        if hit.line then hit.line:Hide() end
    end
    HideTip(preview)
end

local function PartEnter(hit)
    local preview = hit.preview
    if preview.drag then return end
    preview.part = hit.part
    if hit.wash then hit.wash:Show() end
    if hit.line then hit.line:Show() end
    preview.widthHit.line:Show()
    ShowTip(preview)
end

local function PartLeave(hit)
    local preview = hit.preview
    if hit.wash then hit.wash:Hide() end
    if preview.drag then return end
    if hit.line and hit ~= preview.widthHit then hit.line:Hide() end
    if not preview.feed:IsMouseOver() then Unhover(preview) end
end

local function Restack(preview, w, h)
    local shown, box = preview.list, preview.feed
    Look.Stack(shown, box, h)
    box:SetSize(w, #shown * h + (#shown - 1) * Look.Gap(box))
end

local function Resize(preview, w, h)
    local shown = preview.list
    for i = 1, #shown do Look.Size(shown[i], w, h) end
    Restack(preview, w, h)
end

local function Fit(preview)
    local box, area, rate = preview.feed, preview.area, preview.gph
    local extra = rate:IsShown() and GPH_GAP + rate:GetStringWidth() or 0
    local w, h = box:GetWidth() + extra, box:GetHeight()
    local roomW, roomH = area:GetWidth(), area:GetHeight()
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h > 0 and h * scale > roomH then scale = roomH / h end
    preview.fitX = -extra / 2
    box:SetScale(scale)
    box:ClearAllPoints()
    box:SetPoint("CENTER", area, "CENTER", preview.fitX, 0)
    return scale
end

local function EndDrag(preview)
    local hit = preview.drag
    if not hit then return nil end
    hit:SetScript("OnUpdate", nil)
    preview.drag = nil
    return hit
end

local function DragUpdate(hit)
    local preview = hit.preview
    local scale = preview.feed:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local w, h = preview.dragW, preview.dragH
    if hit.part == "width" then
        w = Snap(preview.fromW + x / scale - preview.fromX, WIDTH_RANGE)
    else
        h = Snap(preview.fromH + (preview.fromY - y / scale) / (hit.above + 1), HEIGHT_RANGE)
    end
    if w == preview.dragW and h == preview.dragH then return end
    preview.dragW, preview.dragH = w, h
    Resize(preview, w, h)
end

local function DragStart(hit)
    local preview = hit.preview
    if preview.drag or not preview.editable then return end
    local box = preview.feed
    local scale = box:GetEffectiveScale()
    local x, y = GetCursorPosition()
    preview.fromX, preview.fromY = x / scale, y / scale
    preview.fromW, preview.fromH = S.Get("lootFeedWidth"), S.Get("lootFeedHeight")
    preview.dragW, preview.dragH = preview.fromW, preview.fromH
    preview.drag = hit
    local w, h = box:GetWidth(), box:GetHeight()
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", preview.area, "CENTER", preview.fitX - w / 2, h / 2)
    HideTip(preview)
    hit:SetScript("OnUpdate", DragUpdate)
end

local function DragStop(hit)
    local preview = hit.preview
    EndDrag(preview)
    Fit(preview)
    local w, h = preview.dragW, preview.dragH
    if w ~= S.Get("lootFeedWidth") then S.Set("lootFeedWidth", w) end
    if h ~= S.Get("lootFeedHeight") then S.Set("lootFeedHeight", h) end
    if hit:IsMouseOver() then
        preview.part = hit.part
        ShowTip(preview)
        return
    end
    if hit ~= preview.widthHit then hit.line:Hide() end
    if not preview.feed:IsMouseOver() then Unhover(preview) end
end

local function Toggled(key)
    return S.Get(key) == true
end

local function Toggle(key)
    S.Set(key, not S.Get(key))
end

local function Picked(choice)
    return S.Get(choice.key) == choice.value
end

local function Pick(choice)
    S.Set(choice.key, choice.value)
end

local function LineMenu(_, root)
    root:CreateTitle(TEXT_LINES_SHOW)
    for i = 1, #LINE_TOGGLES do
        local t = LINE_TOGGLES[i]
        root:CreateCheckbox(t[2], Toggled, Toggle, t[1])
    end
    root:CreateDivider()
    root:CreateCheckbox(TEXT_GLOW, Toggled, Toggle, "lootFeedGlow")
    for i = 1, #RADIOS do
        local radio = RADIOS[i]
        root:CreateDivider()
        root:CreateTitle(radio.title)
        for j = 1, #radio do root:CreateRadio(radio[j].label, Picked, Pick, radio[j]) end
    end
end

local function Wheel(hit, delta)
    local preview = hit.preview
    if not preview.editable or preview.drag then return end
    local key, range = "lootFeedFontSize", SIZE_RANGE
    if IsControlKeyDown() then
        key, range = "lootFeedCount", COUNT_RANGE
    elseif IsShiftKeyDown() then
        key, range = "lootFeedSpacing", SPACING_RANGE
    end
    local v = Snap(S.Get(key) + delta * range[3], range)
    if v ~= S.Get(key) then S.Set(key, v) end
end

local function HitDown(hit, button)
    if button == "LeftButton" and hit.drag then DragStart(hit) end
end

local function HitUp(hit, button)
    local preview = hit.preview
    if preview.drag == hit then
        if button == "LeftButton" then DragStop(hit) end
        return
    end
    if not preview.editable or preview.drag then return end
    if button == "RightButton" then
        HideTip(preview)
        MenuUtil.CreateContextMenu(hit, LineMenu)
    elseif button == "LeftButton" and hit.toggle and hit:IsMouseOver() then
        Toggle(hit.toggle)
    end
end

local function Hit(frame, preview, part)
    frame.preview, frame.part = preview, part
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnEnter", PartEnter)
    frame:SetScript("OnLeave", PartLeave)
    frame:SetScript("OnMouseDown", HitDown)
    frame:SetScript("OnMouseUp", HitUp)
    frame:SetScript("OnMouseWheel", Wheel)
end

local function NewHit(preview, part, toggle)
    local hit = CreateFrame("Frame", nil, preview.edit)
    Hit(hit, preview, part)
    hit.toggle = toggle
    if toggle then
        hit.wash = ns.Solid(hit, "OVERLAY", T.accent, HOVER_ALPHA)
        hit.wash:SetAllPoints()
        hit.wash:Hide()
    end
    preview.hits[#preview.hits + 1] = hit
    return hit
end

local function NewEdge(preview, part, from, to)
    local hit = NewHit(preview, part)
    hit.drag, hit.above = true, 0
    hit.line = ns.Solid(hit, "OVERLAY", T.accent, 1)
    hit.line:SetPoint(from)
    hit.line:SetPoint(to)
    hit.line:Hide()
    return hit
end

local function PreviewHidden(preview)
    if EndDrag(preview) then
        Resize(preview, S.Get("lootFeedWidth"), S.Get("lootFeedHeight"))
        Fit(preview)
    end
    Unhover(preview)
end

local function ValueWidth(row)
    local w, any = VALUE_INSET + VALUE_PAD, false
    for i = 1, #row.coins do
        local pair = row.coins[i]
        if pair.amount:IsShown() then
            w = w + (any and PAIR_GAP or 0) + pair.icon:GetWidth() + COIN_GAP + pair.amount:GetStringWidth()
            any = true
        end
    end
    return any and w or VALUE_ROOM
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.area = CreateFrame("Frame", nil, preview)
    preview.area:SetPoint("TOPLEFT", STAGE_MARGIN, -STAGE_MARGIN)
    preview.area:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, TEXT_ROOM)
    local box = CreateFrame("Frame", nil, preview)
    preview.feed = box
    preview.list, preview.hits = {}, {}
    Hit(box, preview, "lines")
    preview.rows = { Look.NewRow(box), Look.NewRow(box), Look.NewRow(box) }
    preview.gph = ns.Font(box, GPH_SIZE, "OUTLINE", GPH_RGB)
    preview.edit = CreateFrame("Frame", nil, box)
    preview.edit:SetAllPoints()
    local widthHit = NewEdge(preview, "width", "TOP", "BOTTOM")
    widthHit:SetPoint("TOP", box, "TOPRIGHT")
    widthHit:SetPoint("BOTTOM", box, "BOTTOMRIGHT")
    preview.widthHit = widthHit
    for i, row in ipairs(preview.rows) do
        local edge = NewEdge(preview, "height", "LEFT", "RIGHT")
        edge:SetPoint("LEFT", row, "BOTTOMLEFT")
        edge:SetPoint("RIGHT", row, "BOTTOMRIGHT")
        row.edgeHit = edge
        if i <= ITEM_ROWS then
            row.valueHit = NewHit(preview, "value", "lootFeedValue")
            row.valueHit:SetPoint("TOPRIGHT", row, "TOPRIGHT")
            row.valueHit:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
            row.bagsHit = NewHit(preview, "bags", "lootFeedBank")
            row.bagsHit:SetAllPoints(row.icon)
        end
    end
    preview.hint = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.hint:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_Y)
    preview.hint:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_Y)
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", preview.hint, "TOP", 0, NOTE_GAP)
    preview:SetScript("OnHide", PreviewHidden)
    return preview
end

local function PaintPreview(preview, state)
    EndDrag(preview)
    local shown, samples = preview.list, preview.rows
    wipe(shown)
    local values, money = S.Get("lootFeedValue"), S.Get("lootFeedMoney")
    if money then
        Look.Fill(samples[3], COIN_ICON, TEXT_COINS, nil, nil, SAMPLE_COINS)
        shown[#shown + 1] = samples[3]
    else
        samples[3]:Hide()
    end
    local cloth = S.Get("lootFeedBank") and SAMPLE_CLOTH_BANK or SAMPLE_CLOTH_BAGS
    Look.Fill(samples[2], CLOTH_ICON, SAMPLE_CLOTH_NAME, nil, cloth, values and SAMPLE_CLOTH or nil)
    shown[#shown + 1] = samples[2]
    Look.Fill(samples[1], PANTS_ICON, SAMPLE_PANTS_NAME, nil, SAMPLE_PANTS_BAGS, values and SAMPLE_PANTS or nil)
    shown[#shown + 1] = samples[1]
    for i, row in ipairs(shown) do
        Look.StyleRow(row)
        row:SetAlpha(state == "fading" and FADING[i] or 1)
        row:Show()
    end
    local w, h = S.Get("lootFeedWidth"), S.Get("lootFeedHeight")
    Restack(preview, w, h)
    local rate = preview.gph
    if state == "looting" and S.Get("lootFeedGPH") then
        Look.GPHFont(rate)
        Look.GPH(rate, shown[1], SAMPLE_PER_HOUR)
        rate:Show()
    else
        rate:Hide()
    end
    local scale = Fit(preview)
    Restack(preview, w, h)
    preview.note:SetText(state == "fading" and TEXT_FADES:format(S.Get("lootFeedFade")) or "")
    local editable = On() and true or false
    local box = preview.feed
    preview.editable = editable
    box:EnableMouse(editable)
    box:EnableMouseWheel(editable)
    preview.edit:SetShown(editable)
    preview.hint:SetText(editable and HINT or S.Get("enabled") and OFF_HINT or QOL_OFF_HINT)
    if not editable then
        Unhover(preview)
        return
    end
    local level = box:GetFrameLevel()
    local edge, line = EDGE_HIT / scale, EDGE_LINE / scale
    preview.edit:SetFrameLevel(level + EDIT_LEVEL)
    local widthHit = preview.widthHit
    widthHit:SetFrameLevel(level + TOP_LEVEL)
    widthHit:SetWidth(edge)
    widthHit.line:SetWidth(line)
    samples[3].edgeHit:SetShown(money)
    local down = S.Get("lootFeedGrowth") == "down"
    for i, row in ipairs(shown) do
        local hit = row.edgeHit
        hit.above = down and i - 1 or #shown - i
        hit:SetFrameLevel(level + TOP_LEVEL)
        hit:SetHeight(edge)
        hit.line:SetHeight(line)
        hit:Show()
    end
    for i = 1, ITEM_ROWS do samples[i].valueHit:SetWidth(ValueWidth(samples[i])) end
    if preview.part then ShowTip(preview) end
end

local function ResetGPH()
    ns.ResetLootFeedSession()
end

local function LootFeedSummary(store)
    local style = store.Get("lootFeedStyle")
    style = style == "none" and TEXT_NO_BACKGROUND or style == "light" and TEXT_LIGHT or TEXT_DARK
    return TEXT_SUMMARY:format(store.Get("lootFeedCount"), style, store.Get("lootFeedGPH") and TEXT_GPH or "")
end

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "lootFeed", name = "Loot Feed", order = 5, switch = "lootFeed",
    help = "Everything you loot pops up on screen with its icon, amount and value, stacking "
        .. "in your chosen direction and fading out. Hover a line for the item's tooltip. Move it in the HUD Editor.",
    summary = LootFeedSummary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Lines"),
        { key = "lootFeedMoney", label = "Show Money", toggle = true },
        { key = "lootFeedQuest", label = "Show Quest Rewards", toggle = true,
          help = "A line for each quest you turn in, with the experience and money it gave. "
              .. "Reward items show as their own lines." },
        { key = "lootFeedRep", label = "Show Reputation", toggle = true,
          help = "A line for every reputation gain, from quests and kills alike." },
        { key = "lootFeedXP", label = "Show Kill Experience", toggle = true,
          help = "A line for the experience from each kill. Quest experience is on the quest's "
              .. "own line." },
        { key = "lootFeedQuality", label = "Lowest Quality Shown", choice = QUALITY },
        { key = "lootFeedCount", label = "Lines Shown", slider = COUNT_RANGE },
        { key = "lootFeedFade", label = "Display Time", slider = DISPLAY_TIME_RANGE, unit = "s",
          help = "How long each line stays before it fades." },
        { key = "lootFeedGrowth", label = "Growth Direction", choice = GROWTH,
          help = "The newest line stays at the anchor; older lines stack in this direction." },
        Group("Value"),
        { key = "lootFeedValue", label = "Show Item Value", toggle = true,
          help = "What each line is worth, in gold, silver and copper." },
        { key = "lootFeedPrice", label = "Price Source", choice = PRICE,
          help = "Auction (Naowh Scan) uses your last Scan Prices at the auction house; Auction (TSM) "
              .. "needs TradeSkillMaster. An item without an auction price counts at its vendor price." },
        { key = "lootFeedBank", label = "Count Bank Items", toggle = true,
          help = "The number on each icon counts your bank as well as your bags." },
        { key = "lootFeedGPH", label = "Gold per Hour", toggle = true,
          help = "A running gold per hour beside the newest line, counting money and item value "
              .. "since your first loot this session." },
        { label = "Reset Gold per Hour", button = ResetGPH, buttonText = "Reset", always = true,
          help = "Starts the gold per hour count again from your next loot." },
        Group("Loot Window"),
        { key = "hideLootWindow", label = "Hide Blizzard Loot Window", toggle = true, always = true,
          needs = ns.GamepadFree, why = ns.GamepadWhy,
          help = "Takes everything the moment you loot, with Blizzard's loot window kept out of "
              .. "sight, so the feed is all you see. Works with or without the game's auto loot. "
              .. "Hold Shift while looting to get the window back. It also appears whenever "
              .. "something cannot be taken: a group roll, a locked item, or bags too full." },
        Group("Size"),
        { key = "lootFeedWidth", label = "Width", slider = WIDTH_RANGE },
        { key = "lootFeedHeight", label = "Line Height", slider = HEIGHT_RANGE,
          help = "The icon grows and shrinks with it." },
        { key = "lootFeedSpacing", label = "Spacing", slider = SPACING_RANGE,
          help = "Space between lines. -1 lets neighbouring lines share one border instead of two side by side." },
        ns.Shared.Settings.Look("lootFeed", { text = true, size = SIZE_RANGE }),
        Group("Background"),
        { key = "lootFeedStyle", label = "Style", choice = STYLE,
          help = "A dark or light fill and edge behind each line, or none." },
        { key = "lootFeedGlow", label = "Glow", toggle = true, help = "A soft glow beside each icon." },
    },
})
