-- Tabs.lua: a switch of parts side by side, and a search box, in the house look (ns.Shared.Parts).
local ns = _G.NaowhForever
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local TipLines = Parts.TipLines

local BORDER_RGB = St.BORDER_RGB
local TAB_SIZE, TAB_H, TAB_LINE, TAB_FILL = St.TAB_SIZE, St.TAB_H, St.TAB_LINE, St.TAB_FILL
local FILL_SUBLEVEL = 1
local TEXT_TAB_INSET = 8
local SEARCH_ICON_SIZE, SEARCH_ICON_LEFT, SEARCH_ICON_GAP = 13, 7, 6
local SEARCH_TEXT_LEFT = SEARCH_ICON_LEFT + SEARCH_ICON_SIZE + SEARCH_ICON_GAP
local SEARCH_TEXT_RIGHT = 22
local FOREVER_OVERHANG = math.max(St.FOREVER_TAB_RIGHT_X, St.FOREVER_ACTIVE_RIGHT_X)

local fitOrder = {}

local function TabClicked(button)
    local bar = button:GetParent()
    if button.key ~= bar.shown then bar.onPick(button.key) end
end

local function TabEnter(button)
    if button.key ~= button:GetParent().shown then button.text:SetTextColor(T.fg.r, T.fg.g, T.fg.b) end
    if button.tip or button.cut then TipLines(button, "ANCHOR_BOTTOM", button.label, button.tip) end
end

local function TabLeave(button)
    local bar = button:GetParent()
    Parts.PaintTabs(bar, bar.shown)
    GameTooltip:Hide()
end

local function NewTab(bar)
    local button = CreateFrame("Button", nil, bar)
    button.text = ns.Font(button, TAB_SIZE, nil, T.muted, true)
    button.text:SetPoint("CENTER", 0, 0)
    button.fill = button:CreateTexture(nil, "BACKGROUND", nil, FILL_SUBLEVEL)
    button.fill:SetAllPoints()
    button.fill:SetColorTexture(T.accent.r, T.accent.g, T.accent.b, TAB_FILL)
    button.line = ns.Solid(button, "ARTWORK", T.accent, 1)
    button.line:SetPoint("BOTTOMLEFT")
    button.line:SetPoint("BOTTOMRIGHT")
    button.line:SetHeight(TAB_LINE)
    if bar.plain then
        button.line:ClearAllPoints()
        button.line:SetPoint("BOTTOMLEFT", TEXT_TAB_INSET, 0)
        button.line:SetPoint("BOTTOMRIGHT", -TEXT_TAB_INSET, 0)
        button.text:SetWordWrap(false)
    end
    if ns.foreverSkin then Parts.ForeverTab(button) end
    button:SetScript("OnClick", TabClicked)
    button:SetScript("OnEnter", TabEnter)
    button:SetScript("OnLeave", TabLeave)
    return button
end

local function FillTabs(bar, items)
    local words = 0
    for i, item in ipairs(items) do
        local button = bar.buttons[i] or NewTab(bar)
        bar.buttons[i] = button
        button.key, button.label, button.tip = item.key, item.label, item.tip
        button.text:SetText(ns.L(item.label))
        button.want = math.ceil(button.text:GetStringWidth()) + (button.capRoom or 0)
        words = words + button.want
        button:Show()
    end
    for i = #items + 1, #bar.buttons do bar.buttons[i]:Hide() end
    for i = 1, #bar.splits do bar.splits[i]:Hide() end
    return words
end

local function Split(bar, i, x)
    local split = bar.splits[i - 1]
    if not split then
        split = ns.Solid(bar, "BORDER", BORDER_RGB, 1)
        ns.Hairline(split, "v")
        bar.splits[i - 1] = split
    end
    split:SetPoint("TOPLEFT", x, 0)
    split:SetPoint("BOTTOMLEFT", x, 0)
    split:Show()
end

local function Edge(box, color)
    box.border:SetColor(color.r, color.g, color.b, 1)
end

local function SearchFocus(box) Edge(box, T.accent) end

local function SearchBlur(box) Edge(box, BORDER_RGB) end

function Parts.PaintTabs(bar, shown)
    bar.shown = shown
    for _, button in ipairs(bar.buttons) do
        local on = button.key == shown
        local color = on and T.fg or T.muted
        button.text:SetTextColor(color.r, color.g, color.b)
        button.fill:SetShown(on and not bar.plain)
        button.line:SetShown(on)
        if ns.foreverSkin then Parts.PaintForeverTab(button, on) end
    end
end

local function Widest(a, b) return a.fit > b.fit end

local function CutWidest(count, room, total)
    for i = 1, count do
        total = total - fitOrder[i].fit
        local level = math.floor((room - total) / i)
        if i == count or level >= fitOrder[i + 1].fit then
            for j = 1, i do
                local button = fitOrder[j]
                button.fit = math.max(level, button.pad)
                button.cut = true
                button.text:SetWordWrap(false)
                button.text:SetWidth(math.max(1, button.fit - button.pad))
            end
            return
        end
    end
end

local function FitForeverTabs(bar, count, width)
    local room = width - St.FOREVER_TAB_GAP * (count - 1) - FOREVER_OVERHANG
    local total = 0
    for i = 1, count do
        local button = bar.buttons[i]
        button.fit, button.pad, button.cut = button.want, button.capRoom or 0, nil
        button.text:SetWidth(0)
        total = total + button.want
    end
    if total <= room then return end
    local trim = math.ceil((total - room) / count)
    total = 0
    for i = 1, count do
        local button = bar.buttons[i]
        local cut = math.min(trim, math.max(0, button.pad - 2 * St.FOREVER_TAB_TIGHT))
        button.fit, button.pad = button.fit - cut, button.pad - cut
        total = total + button.fit
        fitOrder[i] = button
    end
    for i = count + 1, #fitOrder do fitOrder[i] = nil end
    if total <= room then return end
    table.sort(fitOrder, Widest)
    CutWidest(count, room, total)
end

local function PlaceRail(bar, rowW)
    local rail = bar.rail
    if not rail then return end
    rail:SetShown(rowW > 0)
    rail:ClearAllPoints()
    rail:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -St.FOREVER_TAB_RAIL_OUT, 0)
    rail:SetWidth(rowW + 2 * St.FOREVER_TAB_RAIL_OUT)
end

function Parts.SetTabs(bar, items)
    local width = bar:GetWidth()
    local words = FillTabs(bar, items)
    if #items == 0 then return PlaceRail(bar, 0) end
    if ns.foreverSkin then FitForeverTabs(bar, #items, width) end
    local spare, x = (width - words) / #items, 0
    for i = 1, #items do
        local button = bar.buttons[i]
        local w = i == #items and width - x or math.floor(button.want + spare + 0.5)
        if ns.foreverSkin then w = button.fit end
        button:SetSize(w, TAB_H)
        button:SetPoint("LEFT", x, 0)
        if bar.plain then
            button.text:SetWidth(math.max(1, w - TEXT_TAB_INSET * 2))
            button.cut = button.want > w - TEXT_TAB_INSET * 2
        end
        if i > 1 and not ns.foreverSkin and not bar.plain then Split(bar, i, x) end
        x = x + w + (ns.foreverSkin and St.FOREVER_TAB_GAP or 0)
    end
    PlaceRail(bar, x - St.FOREVER_TAB_GAP)
end

function Parts.FitTabs(bar, items, margin, maxW)
    Parts.SetTabs(bar, items)
    local words = 0
    for i = 1, #items do words = words + bar.buttons[i].want end
    bar:SetWidth(math.min(maxW or math.huge, words + margin * #items))
    Parts.SetTabs(bar, items)
end

function Parts.Tabs(parent, width, items, onPick, noRail, plain)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, TAB_H)
    bar.plain = plain and not ns.foreverSkin
    if not ns.foreverSkin and not bar.plain then
        ns.Solid(bar, "BACKGROUND", T.panel, 1):SetAllPoints()
        ns.Border(bar, BORDER_RGB)
    elseif ns.foreverSkin and not noRail then
        bar.rail = Parts.ForeverRail(bar)
    end
    bar.buttons, bar.splits, bar.onPick = {}, {}, onPick
    Parts.SetTabs(bar, items)
    return bar
end

function Parts.SearchBox(parent, hint, onSearch, columns)
    local box = ns.NewSearchBox(parent, hint, onSearch)
    local iconLeft = columns and math.floor(columns.icon - SEARCH_ICON_SIZE / 2 + 0.5) or SEARCH_ICON_LEFT
    local textLeft = columns and columns.text or SEARCH_TEXT_LEFT
    local fill = box:CreateTexture(nil, "BACKGROUND", nil, FILL_SUBLEVEL)
    fill:SetColorTexture(T.panel.r, T.panel.g, T.panel.b, 1)
    fill:SetAllPoints()
    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(St.SEARCH)
    icon:SetSize(SEARCH_ICON_SIZE, SEARCH_ICON_SIZE)
    icon:SetPoint("LEFT", iconLeft, 0)
    icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
    box:SetTextInsets(textLeft, SEARCH_TEXT_RIGHT, 0, 0)
    box.hint:ClearAllPoints()
    box.hint:SetPoint("LEFT", textLeft, 0)
    Edge(box, BORDER_RGB)
    if not ns.foreverSkin then
        box:HookScript("OnEditFocusGained", SearchFocus)
        box:HookScript("OnEditFocusLost", SearchBlur)
    end
    if ns.foreverSkin then Parts.ForeverSearch(box, fill, icon) end
    return box
end
