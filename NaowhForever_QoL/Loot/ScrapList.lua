-- ScrapList.lua: the Scrap List window (/nf scrap): every marked item and rule match in your bags.
local ns = _G.NaowhForever

local T = ns.THEME
local Shared = ns.Shared
local Parts, St, View, Items = Shared.Parts, Shared.Style, Shared.View, Shared.Items
local Scrap = ns.ScrapMarker

local GetItemInfo = C_Item.GetItemInfo
local GetItemCount = C_Item.GetItemCount
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemQualityByID = C_Item.GetItemQualityByID
local GetContainerItemID = C_Container.GetContainerItemID
local GetContainerNumSlots = C_Container.GetContainerNumSlots

local PAGE = "QoL/Loot & Items"
local WIDTH, HEIGHT = 500, 560
local HEADER, PAD, FOOTER, SCROLLBAR = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.SCROLLBAR
local SEARCH_H, BAR_GAP, INSET = St.SEARCH_H, St.BAR_GAP, St.CONTENT_INSET
local BOTTOM_H = 34
local CLEAR_W, CLEAR_H = 100, 24
local EXPORT_PREFIX = "NFSCRAP:1:"
local IMPORT_MAX = 500
local IMPORT_LETTERS = 4000
local SHOWN_NAMES = 3
local UNCOMMON, RARE = 2, 3
local HIGH_VALUE, HIGH_VALUE_TEXT = 10000, "1g"
local SELL_PRICE = ns.QoLConstants.SELL_PRICE
local MAX_ITEM_ID = 2147483648
local CARD_INSET = 6
local SEARCH_DROP = 4
local SCROLL_GAP = 4
local VIEW_SPARE = 8
local SUMMARY_SIZE = 12
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local EVENTS = { "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "EQUIPMENT_SETS_CHANGED" }
local EMPTY_NOTE = ns.L("Nothing marked. Alt-click an item in your bags to mark it.")
local NO_MATCH = ns.L("No scrap item matches your search.")
local TAGS = { account = ns.L("Account"), char = ns.L("Character") }
local TAG_TIPS = { account = ns.L("Marked on every character; click for this character only."),
    char = ns.L("Marked on this character only; click for every character.") }
local RULE_TAG, RULE_TIP = ns.L("Rule"), ns.L("Picked by a rule; the X keeps it.")
local IMPORT_PATTERN = "^%s*NFSCRAP:1:([%d,%s]*)$"

local TEXT_IN_BAGS = ns.L(" in your bags")
local TEXT_NOT_CARRIED = ns.L("Not in your bags")
local TEXT_ITEM, TEXT_ITEMS = ns.L("%d item"), ns.L("%d items")
local TEXT_KEEP, TEXT_UNMARK = ns.L("Keep it"), ns.L("Unmark")
local TEXT_CLEAR_ASK = ns.L("Unmark every item marked as scrap?")
local TEXT_NOTHING_MARKED = ns.L("Nothing marked to export.")
local TEXT_TITLE = ns.L("Scrap List")
local TEXT_SUBTITLE = ns.L("Sold at the next vendor. Drop an item here to mark it.")
local TEXT_ADD_ONE = ns.L("Add %d item to your scrap list: %s%s?")
local TEXT_ADD = ns.L("Add %d items to your scrap list: %s%s?")
local TEXT_MORE = ns.L(" and %d more")
local TEXT_RARE_ONE, TEXT_RARE = ns.L("%d of these is Rare or better"), ns.L("%d of these are Rare or better")
local TEXT_UNCOMMON_ONE, TEXT_UNCOMMON = ns.L("%d of these is Uncommon"), ns.L("%d of these are Uncommon")
local TEXT_WORTH_ONE, TEXT_WORTH = ns.L("%d sells for %s or more"), ns.L("%d sell for %s or more")
local TEXT_WORTH_ALONE_ONE = ns.L("%d of these sells for %s or more")
local TEXT_WORTH_ALONE = ns.L("%d of these sell for %s or more")
local TEXT_WARN_AND = ns.L("%s, and %s")
local TEXT_NOT_A_LIST = ns.L("That isn't a Scrap List string.")
local TEXT_NOTHING_NEW = ns.L("Nothing new to add from that list.")
local TEXT_PASTE = ns.L("Paste a Scrap List")
local TEXT_IMPORT, TEXT_IMPORT_TIP = ns.L("Import a list"), ns.L("Paste a shared list to add its items.")
local TEXT_EXPORT, TEXT_EXPORT_TIP = ns.L("Export this list"), ns.L("A string to share it with.")
local TEXT_SEARCH = ns.L("Search")
local TEXT_CLEAR = ns.L("Clear All")

local window, view, scroll, search, summary
local filter = ""
local ids, marked, have, price, rule, seen = {}, {}, {}, {}, {}, {}
local lowered = {}
local metaTexts = {}
local lastCount, lastTotal
local exportIDs = {}

local function MetaText(reason, count)
    local byReason = metaTexts[reason]
    if not byReason then
        byReason = {}
        metaTexts[reason] = byReason
    end
    local text = byReason[count]
    if not text then
        local carried = count > 0 and (count .. TEXT_IN_BAGS) or TEXT_NOT_CARRIED
        text = reason ~= "" and (reason .. "  " .. carried) or carried
        byReason[count] = text
    end
    return text
end

local function Lower(id)
    local text = lowered[id]
    if not text then
        local name = GetItemInfo(id)
        if not name then return nil end
        text = name:lower()
        lowered[id] = text
    end
    return text
end

local function Carried(a, b)
    local ha, hb = have[a] > 0, have[b] > 0
    if ha ~= hb then return ha end
    local na, nb = GetItemInfo(a), GetItemInfo(b)
    if na ~= nb then
        if not na then return false end
        if not nb then return true end
        return na < nb
    end
    return a < b
end

local function Note(id)
    if seen[id] then return end
    seen[id] = true
    ids[#ids + 1] = id
    have[id] = GetItemCount(id)
    price[id] = select(SELL_PRICE, GetItemInfo(id)) or 0
end

local function Collect()
    wipe(ids)
    wipe(seen)
    wipe(rule)
    Scrap.MarkedIDs(marked)
    for i = 1, #marked do Note(marked[i]) end
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local id = GetContainerItemID(bag, slot)
            if id and not seen[id] then
                local why = Scrap.RuleMatch(id)
                if why then
                    rule[id] = why
                    Note(id)
                end
            end
        end
    end
    table.sort(ids, Carried)
end

local function Unscrap(id)
    Scrap.Unscrap(id)
end

local function PaintSummary(count, total)
    if count == lastCount and total == lastTotal then return end
    lastCount, lastTotal = count, total
    local text = (count == 1 and TEXT_ITEM or TEXT_ITEMS):format(count)
    if total > 0 then text = text .. ", " .. Parts.Coins(total) .. TEXT_IN_BAGS end
    summary:SetText(text)
end

local function Matches(id)
    if filter == "" then return true end
    local name = Lower(id)
    return name and name:find(filter, 1, true)
end

local Draw = {}

function Draw:AddItem(id, value)
    local why = rule[id]
    local scope = not why and Scrap.Scope(id)
    self:Add("item", id, MetaText(why or "", have[id]), value > 0 and Parts.Coins(value) or "",
        Unscrap, why and TEXT_KEEP or TEXT_UNMARK, why and RULE_TAG or TAGS[scope],
        not why and Scrap.SwitchScope or nil, why and RULE_TIP or TAG_TIPS[scope])
end

function Draw:Redraw()
    self:Clear()
    Collect()
    local total, shown = 0, 0
    for i = 1, #ids do
        local id = ids[i]
        local value = have[id] * price[id]
        total = total + value
        if Matches(id) then
            shown = shown + 1
            self:AddItem(id, value)
        end
    end
    if #ids == 0 then
        self:Note(EMPTY_NOTE)
    elseif shown == 0 then
        self:Note(NO_MATCH)
    end
    self:Fit(EVENTS)
    PaintSummary(#ids, total)
end

local function Drop()
    local kind, id, link = GetCursorInfo()
    if kind ~= "item" or not id then return end
    ClearCursor()
    if Scrap.Scope(id) then return end
    Scrap.Mark(id, link)
end

local function ClearAll()
    ns.Confirm(TEXT_CLEAR_ASK, Scrap.Clear)
end

local function Export()
    Scrap.MarkedIDs(exportIDs)
    if #exportIDs == 0 then
        ns.Print(TEXT_NOTHING_MARKED)
        return
    end
    table.sort(exportIDs)
    ns.ShowCopyLine(TEXT_TITLE, EXPORT_PREFIX .. table.concat(exportIDs, ","), St.LOGO)
end

local function Parse(text)
    local body = text:match(IMPORT_PATTERN)
    if not body then return nil end
    local out, got = {}, {}
    for digits in body:gmatch("%d+") do
        local id = tonumber(digits)
        if id and id > 0 and id < MAX_ITEM_ID and not got[id] then
            got[id] = true
            out[#out + 1] = id
            if #out >= IMPORT_MAX then break end
        end
    end
    return out
end
Scrap.Parse = Parse

local function QualityFirst(a, b)
    local qa, qb = GetItemQualityByID(a) or 0, GetItemQualityByID(b) or 0
    if qa ~= qb then return qa > qb end
    return a < b
end

local function AddText(add)
    local names = {}
    for i = 1, math.min(#add, SHOWN_NAMES) do
        names[i] = Items.QualityHex(add[i]) .. Items.Name(add[i]) .. "|r"
    end
    local more = #add - #names
    return (#add == 1 and TEXT_ADD_ONE or TEXT_ADD):format(#add, table.concat(names, ", "),
        more > 0 and TEXT_MORE:format(more) or "")
end

local function Tally(add)
    local rare, uncommon, valuable = 0, 0, 0
    for _, id in ipairs(add) do
        local quality = GetItemQualityByID(id) or 0
        if quality >= RARE then
            rare = rare + 1
        elseif quality >= UNCOMMON then
            uncommon = uncommon + 1
        end
        local sell = select(SELL_PRICE, GetItemInfo(id)) or 0
        local auction = ns.AuctionPrice and ns.AuctionPrice(id) or 0
        if math.max(sell, auction) >= HIGH_VALUE then valuable = valuable + 1 end
    end
    return rare, uncommon, valuable
end

local function Warning(add)
    local rare, uncommon, valuable = Tally(add)
    local warn
    if rare > 0 then
        warn = (rare == 1 and TEXT_RARE_ONE or TEXT_RARE):format(rare)
    elseif uncommon > 0 then
        warn = (uncommon == 1 and TEXT_UNCOMMON_ONE or TEXT_UNCOMMON):format(uncommon)
    end
    if valuable == 0 then return warn end
    local one = valuable == 1
    if warn then return TEXT_WARN_AND:format(warn, (one and TEXT_WORTH_ONE or TEXT_WORTH):format(valuable, HIGH_VALUE_TEXT)) end
    return (one and TEXT_WORTH_ALONE_ONE or TEXT_WORTH_ALONE):format(valuable, HIGH_VALUE_TEXT)
end

local function ImportQuestion(add)
    table.sort(add, QualityFirst)
    local text = AddText(add)
    local warn = Warning(add)
    if not warn then return text end
    return text .. "|n" .. St.WARN_CODE .. warn .. ".|r"
end

local function Import(text)
    local parsed = Parse(text)
    if not parsed then
        ns.Print(TEXT_NOT_A_LIST)
        return
    end
    local add = {}
    for _, id in ipairs(parsed) do
        if GetItemInfoInstant(id) and not Scrap.Scope(id) and not Scrap.Refusal(id) then add[#add + 1] = id end
    end
    if #add == 0 then
        ns.Print(TEXT_NOTHING_NEW)
        return
    end
    ns.Confirm(ImportQuestion(add), function()
        Scrap.AddAll(add)
    end)
end

local function ImportPrompt()
    ns.PromptText(TEXT_PASTE, "", IMPORT_LETTERS, Import)
end

local function OnSearch(text)
    filter = (text or ""):lower()
    if view then view:Redraw() end
end

local function DropClick()
    if GetCursorInfo() then Drop() end
end

local function OnScrapChange()
    if window:IsShown() then view:QueueRedraw() end
end

local function BuildWindow()
    window = Parts.Window(WIDTH, HEIGHT, "scrapListWindow")
    window.backdrop:Card(CARD_INSET, HEADER + CARD_INSET, CARD_INSET, FOOTER + CARD_INSET)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE)
    local import = Parts.BarButton(window, St.IMPORT, TEXT_IMPORT, TEXT_IMPORT_TIP, ImportPrompt)
    import:SetPoint("RIGHT", close, "LEFT", -BAR_GAP * 2, 0)
    local export = Parts.BarButton(window, St.EXPORT, TEXT_EXPORT, TEXT_EXPORT_TIP, Export)
    export:SetPoint("RIGHT", import, "LEFT", -BAR_GAP, 0)
    Parts.FooterBrand(window, PAGE)
    window:SetScript("OnReceiveDrag", Drop)
    window:SetScript("OnMouseUp", DropClick)
end

local function BuildFooter()
    local clear = ns.Button(window, TEXT_CLEAR, CLEAR_W, CLEAR_H, ClearAll)
    clear:SetPoint("BOTTOMRIGHT", -INSET, FOOTER + PAD)
    summary = ns.Font(window, SUMMARY_SIZE, nil, T.muted)
    summary:SetPoint("LEFT", window, "BOTTOMLEFT", INSET, FOOTER + PAD + CLEAR_H / 2)
    summary:SetPoint("RIGHT", clear, "LEFT", -PAD, 0)
    summary:SetJustifyH("LEFT")
end

local function BuildList(top)
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -(top + SEARCH_H + PAD))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_GAP, FOOTER + PAD + BOTTOM_H)
    view = View.New(scroll, View.NewKinds(), Draw)
    view:SetWidth(WIDTH - INSET - SCROLLBAR - PAD - VIEW_SPARE)
    view.onDrop = Drop
    scroll:SetScrollChild(view)
end

local function Build()
    BuildWindow()
    local top = HEADER + PAD + SEARCH_DROP
    search = Parts.SearchBox(window, TEXT_SEARCH, OnSearch)
    search:SetPoint("TOPLEFT", INSET, -top)
    search:SetPoint("TOPRIGHT", -INSET, -top)
    search:SetHeight(SEARCH_H)
    BuildFooter()
    BuildList(top)
    Scrap.OnChange(OnScrapChange)
end

function ns.OpenScrapList()
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
    lastCount = nil
    view:Redraw()
end

function ns.ToggleScrapList()
    if window and window:IsShown() then window:Hide() else ns.OpenScrapList() end
end

local function OpenFromCard()
    ns.OpenScrapList()
end

Shared.Settings.Page(PAGE, ns.QoLSettings):Window({
    order = 26,
    text = "Open Scrap List",
    open = OpenFromCard,
    headline = "Scrap List",
    detail = "Every item marked as scrap, to search, unmark, share or add to.",
})
