-- BagSpaceIgnore.lua: Bag Space's Ignore List window: search, drag to add, X to remove.
local ns = _G.NaowhForever

local UI = ns.UI
local T = ns.THEME
local BagSpace = ns.BagSpace

local LIST = { W = 440, H = 500, ROW = 30, HOVER_ALPHA = 0.12, ICON = 24, INSET = 2,
    ICON_CROP = ns.QoLConstants.ICON_CROP,
    REMOVE = 22, WHEN_RIGHT = 32, COUNT_GAP = 12, TEXT_GAP = 8, SMALL = 11, TEXT = 12, HEAD = 14,
    NOTE_Y = 6, CONTENT_ROOM = 62, HEAD_Y = 16, SIDE = 20, SCROLL_TOP = 80, SCROLL_RIGHT = 40,
    SCROLL_BOTTOM = 100, SEARCH_Y = 44, SEARCH_H = 24, DROP_H = 34, DROP_Y = 54,
    BUTTON_W = 100, BUTTON_H = 26, BUTTON_X = 56, BUTTON_Y = 16, DATE = "%d %b" }
local TEXT = {
    LIST_HEAD = ns.L("Bag Space: Ignored Items (%d)"),
    WHITE_CODE = "|cffffffff",
    ITEM = ns.L("Item "),
    CARRIED = "x",
    NOTHING_IGNORED = ns.L("Nothing ignored yet. Middle-click an icon on the Bag Space row, or drop "
        .. "an item below."),
    NO_MATCH = ns.L("No ignored item matches your search."),
    SEARCH = "Search",
    DROP = ns.L("Drop an item here to ignore it"),
    CLEAR_ALL = "Clear All",
    CLEAR_ASK = "Offer every item you ignored again?",
    DONE = "Done",
}

local Ignored = BagSpace.Ignored
local RequestScan = BagSpace.RequestScan

local listDimmer, listPanel
local FillList

local function NewestFirst(a, b)
    if a.when ~= b.when then return a.when > b.when end
    return a.id < b.id
end

local function IgnoredByDate()
    local out = {}
    for itemID, when in pairs(Ignored()) do
        out[#out + 1] = { id = itemID, when = type(when) == "number" and when or 0 }
    end
    table.sort(out, NewestFirst)
    return out
end

local function Refill()
    if listDimmer and listDimmer:IsShown() then FillList() end
end

local function Unignore(id)
    Ignored()[id] = nil
    Refill()
    RequestScan()
end

local function IgnoreFromCursor()
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return end
    ClearCursor()
    Ignored()[id] = time()
    Refill()
    RequestScan()
end

local function RowLeave(row)
    if row:IsMouseOver() then return end
    row.hover:Hide()
    row.remove:Hide()
    GameTooltip:Hide()
end

local function RowEnter(self)
    self.hover:Show()
    self.remove:Show()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.id)
    GameTooltip:Show()
end

local function NewListRowText(row)
    row.when = ns.Font(row, LIST.SMALL, nil, T.muted)
    row.when:SetPoint("RIGHT", row, "RIGHT", -LIST.WHEN_RIGHT, 0)
    row.count = ns.Font(row, LIST.SMALL, nil, T.muted)
    row.count:SetPoint("RIGHT", row.when, "LEFT", -LIST.COUNT_GAP, 0)
    row.text = ns.Font(row, LIST.TEXT, nil)
    row.text:SetPoint("LEFT", row.icon, "RIGHT", LIST.TEXT_GAP, 0)
    row.text:SetPoint("RIGHT", row.count, "LEFT", -LIST.TEXT_GAP, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
end

local function NewListRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(LIST.ROW)
    row:EnableMouse(true)
    row.hover = ns.Solid(row, "BACKGROUND", T.accent, LIST.HOVER_ALPHA)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(LIST.ICON, LIST.ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", LIST.INSET, 0)
    row.icon:SetTexCoord(LIST.ICON_CROP, 1 - LIST.ICON_CROP, LIST.ICON_CROP, 1 - LIST.ICON_CROP)
    row.remove = ns.Button(row, "X", LIST.REMOVE, LIST.REMOVE, function() Unignore(row.id) end)
    row.remove:SetPoint("RIGHT", row, "RIGHT", -LIST.INSET, 0)
    row.remove:HookScript("OnLeave", function() RowLeave(row) end)
    row.remove:Hide()
    NewListRowText(row)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function Note(content, text)
    local note = UI.KeepFont(content, "note", LIST.TEXT, nil, T.muted)
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -LIST.NOTE_Y)
    note:SetWidth(LIST.W - LIST.CONTENT_ROOM)
    note:SetJustifyH("LEFT")
    note:SetText(text)
end

local function FillListRow(row, entry, name, quality)
    local id = entry.id
    row.id = id
    row.hover:Hide()
    row.remove:Hide()
    row.icon:SetTexture(C_Item.GetItemIconByID(id))
    if name then
        local c = ITEM_QUALITY_COLORS[quality]
        row.text:SetText((c and c.hex or TEXT.WHITE_CODE) .. name .. "|r")
    else
        row.text:SetText(TEXT.ITEM .. id)
        Item:CreateFromItemID(id):ContinueOnItemLoad(Refill)
    end
    local carried = C_Item.GetItemCount(id)
    row.count:SetText(carried > 0 and (TEXT.CARRIED .. carried) or "")
    row.when:SetText(entry.when > 0 and date(LIST.DATE, entry.when) or "")
end

function FillList()
    local content = listPanel.scroll.content
    UI.BeginReusableRows(content)
    local items = IgnoredByDate()
    local filter = strtrim(listPanel.search:GetText()):lower()
    listPanel.head:SetText(TEXT.LIST_HEAD:format(#items))
    local y, shown = 0, 0
    for _, entry in ipairs(items) do
        local name, _, quality = C_Item.GetItemInfo(entry.id)
        if filter == "" or (name and name:lower():find(filter, 1, true)) then
            local row = UI.Keep(content, "ignoreRow", NewListRow)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            FillListRow(row, entry, name, quality)
            y = y - LIST.ROW
            shown = shown + 1
        end
    end
    if #items == 0 then
        Note(content, TEXT.NOTHING_IGNORED)
        y = y - LIST.ROW
    elseif shown == 0 then
        Note(content, TEXT.NO_MATCH)
        y = y - LIST.ROW
    end
    content:SetHeight(-y)
end

local function SearchChanged()
    if listPanel then FillList() end
end

local function NewSearchBox(parent)
    return ns.NewSearchBox(parent, TEXT.SEARCH, SearchChanged)
end

local function DropEnter(self)
    if GetCursorInfo() == "item" then self.border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1) end
end

local function DropLeave(self)
    self.border:SetColor(T.line.r, T.line.g, T.line.b, 1)
end

local function NewDropZone(parent)
    local zone = CreateFrame("Button", nil, parent)
    zone:SetHeight(LIST.DROP_H)
    ns.Solid(zone, "BACKGROUND", T.bg, 1):SetAllPoints()
    zone.border = ns.Border(zone)
    zone.text = ns.Font(zone, LIST.TEXT, nil, T.muted)
    zone.text:SetPoint("CENTER")
    zone.text:SetText(TEXT.DROP)
    zone:SetScript("OnReceiveDrag", IgnoreFromCursor)
    zone:SetScript("OnClick", IgnoreFromCursor)
    zone:SetScript("OnEnter", DropEnter)
    zone:SetScript("OnLeave", DropLeave)
    return zone
end

local function NewListScroll(p)
    local sf = UI.SlimScroll(p)
    sf.content = CreateFrame("Frame", nil, sf)
    sf.content:SetSize(LIST.W - LIST.CONTENT_ROOM, 1)
    sf:SetScrollChild(sf.content)
    return sf
end

local function ClearIgnored()
    wipe(Ignored())
    Refill()
    RequestScan()
end

local function AskClearAll()
    ns.Confirm(TEXT.CLEAR_ASK, ClearIgnored)
end

local function PlaceListParts(panel)
    panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST.SIDE, -LIST.SCROLL_TOP)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -LIST.SCROLL_RIGHT, LIST.SCROLL_BOTTOM)
    panel.scroll:SetVerticalScroll(0)
    panel.search:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST.SIDE, -LIST.SEARCH_Y)
    panel.search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -LIST.SIDE, -LIST.SEARCH_Y)
    panel.search:SetHeight(LIST.SEARCH_H)
    panel.search:SetText("")
    panel.drop:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", LIST.SIDE, LIST.DROP_Y)
    panel.drop:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -LIST.SIDE, LIST.DROP_Y)
end

function ns.ShowBagSpaceIgnoreList()
    local dimmer, panel = ns.MakeModal(LIST.W, LIST.H, "bagSpaceIgnore")
    listDimmer, listPanel = dimmer, panel
    panel.head = UI.KeepFont(panel, "head", LIST.HEAD, "OUTLINE")
    panel.head:SetPoint("TOP", 0, -LIST.HEAD_Y)
    panel.scroll = UI.Keep(panel, "scroll", NewListScroll)
    panel.search = UI.Keep(panel, "search", NewSearchBox)
    panel.drop = UI.Keep(panel, "drop", NewDropZone)
    PlaceListParts(panel)
    UI.KeepButton(panel, "clear", TEXT.CLEAR_ALL, LIST.BUTTON_W, LIST.BUTTON_H, AskClearAll)
        :SetPoint("BOTTOM", panel, "BOTTOM", -LIST.BUTTON_X, LIST.BUTTON_Y)
    UI.KeepButton(panel, "done", TEXT.DONE, LIST.BUTTON_W, LIST.BUTTON_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOM", panel, "BOTTOM", LIST.BUTTON_X, LIST.BUTTON_Y)
    FillList()
    dimmer:Show()
end
