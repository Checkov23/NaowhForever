-- CraftQueue.lua: the standalone crafting queue window and its click-driven controls.
local ns = _G.NaowhForever

local T = ns.THEME
local Shared = ns.Shared
local Parts, St = Shared.Parts, Shared.Style

local P = ns.Professions
local S = P.Settings
local Queue = P.CraftQueue
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets

local PAGE = "Professions/Settings"
local WIDTH, HEIGHT = 380, 320
local MIN_W, MIN_H = 320, 190
local HEADER, PAD, FOOTER, SCROLLBAR = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.SCROLLBAR
local INSET = St.CONTENT_INSET
local CARD_INSET = 6
local BOTTOM_H = 34
local SCROLL_GAP = 4
local ROW_H = 20
local ROW_SHRINK = 2
local ICON_SHRINK = Style.ROW_ICON_SHRINK
local NAME_GAP = Style.ICON_NAME_GAP
local HEAD_X, HEAD_STEP = 4, 18
local SECTION_GAP = 8
local ROW_X = 2
local SMALL_BUTTON = 16
local STEP_GAP, MINUS_GAP = 6, 2
local CLEAR_W, START_W, ADD_MISSING_W = 68, 94, 120
local WARNING_GAP = 2
local BUTTON_H = 24

local TEXT_TITLE = ns.L("Crafting Queue")
local TEXT_SUBTITLE = ns.L("Prerequisites first, then crafts.")
local TEXT_PREREQUISITES = ns.L("Prerequisite Crafts")
local TEXT_CRAFTS = ns.L("Crafts")
local TEXT_EMPTY = ns.L("Crafts you add appear here. Their missing auction-house materials go to the Shopping List.")
local TEXT_ROW = "%dx %s"
local TEXT_UNKNOWN = "?"
local TEXT_START = ns.L("Start Queue")
local TEXT_RUNNING = ns.L("Crafting...")
local TEXT_NEXT = ns.L("Craft Next")
local TEXT_OPEN = ns.L("Open First")
local TEXT_CLEAR = ns.L("Clear")
local TEXT_ADD_MISSING = ns.L("Add Missing to SL")
local TEXT_ADD_MISSING_SHORT = ns.L("Missing to SL")
local TEXT_MISSING = ns.L("Missing Materials")
local TEXT_HAVE = ns.L("%d / %d")
local TEXT_VENDOR_COST = ns.L("Vendor cost: %s")
local TEXT_VENDOR_UNKNOWN = ns.L("Vendor price unknown")
local TEXT_OFF = ns.L("Turn on Crafting Queue in the Professions settings first.")
local TIP_REMOVE, TIP_REMOVE_HELP = ns.L("Remove"), ns.L("Takes this craft and its materials off the queue.")
local TIP_MORE, TIP_MORE_HELP = ns.L("One More"), ns.L("Adds the materials for one more craft.")
local TIP_FEWER, TIP_FEWER_HELP = ns.L("One Fewer"), ns.L("Takes the materials for one craft off the queue.")
local TIP_START_HELP = ns.L("Prepares the next ready craft; each Craft Next click makes one batch.")
local TIP_CLEAR_HELP = ns.L("Empties the crafting queue and removes its materials from the Shopping List.")
local TIP_ADD_MISSING_HELP = ns.L("Refreshes the Shopping List with the queue's missing auction-house materials.")
local TIP_REORDER = ns.L("Drag to reorder within this section.")

local View = {}
P.CraftQueueView = View

local window, scroll, content, empty, start, clear, addMissing, events
local dragged
local heads = {}
local pools = { prerequisites = {}, crafts = {} }
local sectionEntries = { prerequisites = {}, crafts = {} }

local function On()
    return S.Get("enabled") and S.Get("shoppingList") and S.Get("craftQueue")
end

local function Reorderable()
    local active = Queue.Active()
    return not (active and active.started)
end

local function RowUnderCursor()
    local node = GetMouseFoci()[1]
    while node do
        if node.entry and node:GetParent() == content then return node end
        node = node:GetParent()
    end
end

local function OnRowEnter(self)
    if not self.spell then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if not pcall(GameTooltip.SetRecipeResultItem, GameTooltip, self.spell) then
        GameTooltip:SetSpellByID(self.spell)
    end
    if Reorderable() then GameTooltip:AddLine(TIP_REORDER, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:Show()
end

local function OnDragStart(self)
    if not (self.entry and Reorderable()) then return end
    dragged = self
    GameTooltip_Hide()
end

local function OnDragStop(self)
    if dragged ~= self then return end
    dragged = nil
    local target = RowUnderCursor()
    if not (target and target.entry.prerequisite == self.entry.prerequisite) then return end
    Queue.Move(self.entry.recipeID, self.entry.prerequisite, target.entry.recipeID)
end

local function OnMissingEnter(self)
    local entry = self.entry
    if not entry then return end
    local rows, _, vendorCost = Queue.Requirements(entry)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(TEXT_MISSING, T.fg.r, T.fg.g, T.fg.b)
    for _, material in ipairs(rows) do
        local color = material.missing > 0 and Style.RED_RGB or T.accent
        local name = material.name .. (material.vendor and ("  " .. Style.VENDOR_ICON) or "")
        GameTooltip:AddDoubleLine(name, TEXT_HAVE:format(material.have, material.need),
            color.r, color.g, color.b, color.r, color.g, color.b)
        if material.vendor and material.missing > 0 then
            local cost = material.vendorPrice and Text.Money(material.vendorPrice * material.missing)
                or TEXT_VENDOR_UNKNOWN
            GameTooltip:AddLine("  " .. (material.vendorPrice and TEXT_VENDOR_COST:format(cost) or cost),
                Style.VENDOR_RGB.r, Style.VENDOR_RGB.g, Style.VENDOR_RGB.b)
        end
    end
    if vendorCost > 0 then
        GameTooltip:AddLine(TEXT_VENDOR_COST:format(Text.Money(vendorCost)),
            Style.VENDOR_RGB.r, Style.VENDOR_RGB.g, Style.VENDOR_RGB.b)
    end
    GameTooltip:Show()
end

local function NewRow(pool, index)
    local row = pool[index]
    if row then return row end
    row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_H - ROW_SHRINK)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    row.warning = CreateFrame("Button", nil, row)
    row.warning:SetSize(SMALL_BUTTON, SMALL_BUTTON)
    row.warning:SetPoint("LEFT")
    row.warning.text = ns.Font(row.warning, Style.FONT_HEAD, nil, Style.RED_RGB)
    row.warning.text:SetPoint("CENTER")
    row.warning.text:SetText("!")
    row.warning:SetScript("OnEnter", OnMissingEnter)
    row.warning:SetScript("OnLeave", GameTooltip_Hide)
    row.icon = Widgets.Crop(row:CreateTexture(nil, "ARTWORK"))
    row.icon:SetSize(ROW_H - ICON_SHRINK, ROW_H - ICON_SHRINK)
    row.name = ns.Font(row, Style.FONT, nil)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.remove = ns.Button(row, "X", SMALL_BUTTON, SMALL_BUTTON, function()
        local entry = row.entry
        if entry then Queue.Remove(entry.recipeID, entry.prerequisite) end
    end)
    row.remove:SetPoint("RIGHT")
    ns.Tooltip(row.remove, TIP_REMOVE, TIP_REMOVE_HELP)
    row.plus = ns.Button(row, "+", SMALL_BUTTON, SMALL_BUTTON, function()
        local entry = row.entry
        if entry then Queue.Step(entry.recipeID, entry.prerequisite, 1) end
    end)
    row.plus:SetPoint("RIGHT", row.remove, "LEFT", -STEP_GAP, 0)
    ns.Tooltip(row.plus, TIP_MORE, TIP_MORE_HELP)
    row.minus = ns.Button(row, "-", SMALL_BUTTON, SMALL_BUTTON, function()
        local entry = row.entry
        if entry then Queue.Step(entry.recipeID, entry.prerequisite, -1) end
    end)
    row.minus:SetPoint("RIGHT", row.plus, "LEFT", -MINUS_GAP, 0)
    ns.Tooltip(row.minus, TIP_FEWER, TIP_FEWER_HELP)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnDragStart", OnDragStart)
    row:SetScript("OnDragStop", OnDragStop)
    pool[index] = row
    return row
end

local function Entries(prerequisite, ordered)
    local key = prerequisite and "prerequisites" or "crafts"
    local list = sectionEntries[key]
    wipe(list)
    for _, entry in ipairs(ordered) do
        if entry.prerequisite == prerequisite then list[#list + 1] = entry end
    end
    return key, list
end

local function PlaceSection(prerequisite, y, ordered)
    local key, entries = Entries(prerequisite, ordered)
    local head, pool = heads[key], pools[key]
    head:SetShown(#entries > 0)
    if #entries > 0 then
        if y < 0 then y = y - SECTION_GAP end
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", HEAD_X, y)
        y = y - HEAD_STEP
    end
    for index = 1, math.max(#entries, #pool) do
        local entry = entries[index]
        local row = (entry or pool[index]) and NewRow(pool, index)
        if entry then
            local missing = Queue.Missing(entry)
            row.entry, row.spell = entry, entry.recipeID
            row.icon:SetTexture(entry.icon or C_Spell.GetSpellTexture(entry.recipeID))
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", missing and row.warning or row,
                missing and "RIGHT" or "LEFT", missing and WARNING_GAP or 0, 0)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
            row.name:SetPoint("RIGHT", row.minus, "LEFT", -STEP_GAP, 0)
            row.name:SetText(TEXT_ROW:format(entry.count, entry.name or TEXT_UNKNOWN))
            row.warning:SetShown(missing)
            row.warning.entry = entry
            local active = Queue.Active()
            local editing = not (active and active.started)
            Widgets.EnableButton(row.remove, editing)
            Widgets.EnableButton(row.plus, editing)
            Widgets.EnableButton(row.minus, editing and entry.count > 1)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", ROW_X, y)
            row:SetPoint("TOPRIGHT", -ROW_X, y)
            row:Show()
            y = y - ROW_H
        elseif row then
            row:Hide()
        end
    end
    return y, #entries
end

function View.Render()
    if not (window and window:IsShown()) then return end
    local ordered = Queue.Ordered()
    local y, prerequisites = PlaceSection(true, -2, ordered)
    local crafts
    y, crafts = PlaceSection(false, y, ordered)
    local count = prerequisites + crafts
    local contentHeight = count > 0 and (-y + SECTION_GAP) or 1
    content:SetHeight(math.max(1, contentHeight))
    empty:SetShown(count == 0)
    local active = Queue.Active()
    local running = Queue.Running()
    local crafting = running and active and active.started
    local startText = TEXT_START
    if running then
        startText = crafting and TEXT_RUNNING or (Queue.Ready() and TEXT_NEXT or TEXT_OPEN)
    end
    ns.SetButtonText(start, startText)
    start._tipTitle = startText
    Widgets.EnableButton(start, count > 0 and (not running or (active and not active.started)))
    Widgets.EnableButton(clear, count > 0 and not crafting)
    Widgets.EnableButton(addMissing, count > 0 and not crafting)
end

local function BuildHead(key, text)
    local head = ns.Font(content, Style.FONT, nil, Style.GOLD_RGB)
    head:SetText(text)
    heads[key] = head
end

local function BuildBody()
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -(HEADER + PAD))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_GAP, FOOTER + PAD + BOTTOM_H)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - INSET - SCROLLBAR - SCROLL_GAP, 1)
    scroll:SetScrollChild(content)
    BuildHead("prerequisites", TEXT_PREREQUISITES)
    BuildHead("crafts", TEXT_CRAFTS)
    empty = ns.Font(window, Style.FONT, nil, T.muted)
    empty:SetPoint("LEFT", scroll, "LEFT")
    empty:SetPoint("RIGHT", scroll, "RIGHT")
    empty:SetJustifyH("CENTER")
    empty:SetWordWrap(true)
    empty:SetText(TEXT_EMPTY)
end

local function BuildFooter()
    clear = ns.Button(window, TEXT_CLEAR, CLEAR_W, BUTTON_H, Queue.Clear)
    clear:SetPoint("BOTTOMLEFT", INSET, FOOTER + PAD)
    ns.Tooltip(clear, TEXT_CLEAR, TIP_CLEAR_HELP)
    start = ns.Button(window, TEXT_START, START_W, BUTTON_H, Queue.Click)
    start:SetPoint("BOTTOMRIGHT", -INSET, FOOTER + PAD)
    ns.AccentBorder(start)
    ns.Tooltip(start, TEXT_START, TIP_START_HELP)
    addMissing = ns.Button(window, TEXT_ADD_MISSING, ADD_MISSING_W, BUTTON_H, Queue.AddMissingToShopping)
    addMissing:SetPoint("LEFT", clear, "RIGHT", PAD, 0)
    addMissing:SetPoint("RIGHT", start, "LEFT", -PAD, 0)
    ns.Tooltip(addMissing, TEXT_ADD_MISSING, TIP_ADD_MISSING_HELP)
end

local function OnSized(_, width)
    content:SetWidth(width - INSET - SCROLLBAR - SCROLL_GAP)
    ns.SetButtonText(addMissing, width < WIDTH and TEXT_ADD_MISSING_SHORT or TEXT_ADD_MISSING)
end

local function OnShow()
    Queue.EnableRuntime()
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("TRADE_SKILL_SHOW")
    events:RegisterEvent("TRADE_SKILL_CLOSE")
    View.Render()
end

local function OnHide()
    events:UnregisterAllEvents()
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "craftQueueWindow")
    window.backdrop:Card(CARD_INSET, HEADER + CARD_INSET, CARD_INSET, FOOTER + CARD_INSET)
    Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE)
    Parts.FooterBrand(window, PAGE)
    BuildBody()
    BuildFooter()
    Parts.Resizable(window, "craftQueue", MIN_W, MIN_H, OnSized)
    OnSized(window, window:GetWidth())
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", View.Render)
    window:HookScript("OnShow", OnShow)
    window:HookScript("OnHide", OnHide)
end

function ns.OpenCraftQueue()
    if not On() then return ns.Print(TEXT_OFF) end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
end

function ns.ToggleCraftQueue()
    if window and window:IsShown() then window:Hide() else ns.OpenCraftQueue() end
end

function View.Hide()
    if window then window:Hide() end
end

Queue.Render = View.Render
