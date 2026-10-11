-- Tabs.lua: a switch of parts side by side, and a search box, in the house look (ns.Shared.Parts).
local ns = _G.NaowhForever
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local TipLines = Parts.TipLines

local BORDER_RGB = St.BORDER_RGB
local TAB_SIZE, TAB_H, TAB_LINE, TAB_FILL = St.TAB_SIZE, St.TAB_H, St.TAB_LINE, St.TAB_FILL
local FILL_SUBLEVEL = 1
local SEARCH_ICON_SIZE, SEARCH_ICON_LEFT, SEARCH_ICON_GAP = 13, 7, 6
local SEARCH_TEXT_LEFT = SEARCH_ICON_LEFT + SEARCH_ICON_SIZE + SEARCH_ICON_GAP
local SEARCH_TEXT_RIGHT = 22

local function TabClicked(button)
    local bar = button:GetParent()
    if button.key ~= bar.shown then bar.onPick(button.key) end
end

local function TabEnter(button)
    if button.key ~= button:GetParent().shown then button.text:SetTextColor(T.fg.r, T.fg.g, T.fg.b) end
    if button.tip then TipLines(button, "ANCHOR_BOTTOM", button.label, button.tip) end
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
    if ns.classicSkin then
        local top, bottom = St.CLASSIC_TAB_RGB[1], St.CLASSIC_TAB_RGB[2]
        button.fill:SetColorTexture(1, 1, 1, 1)
        button.fill:SetGradient("VERTICAL", CreateColor(bottom.r, bottom.g, bottom.b, 1), CreateColor(top.r, top.g, top.b, 1))
        button.line:SetColorTexture(St.CLASSIC_GOLD_RGB.r, St.CLASSIC_GOLD_RGB.g, St.CLASSIC_GOLD_RGB.b, 1)
        button.line:ClearAllPoints()
        button.line:SetPoint("TOPLEFT")
        button.line:SetPoint("TOPRIGHT")
    end
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
        button.want = math.ceil(button.text:GetStringWidth())
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
        local color = on and T.fg or (ns.classicSkin and T.accent or T.muted)
        button.text:SetTextColor(color.r, color.g, color.b)
        button.fill:SetShown(on)
        button.line:SetShown(on)
    end
end

function Parts.SetTabs(bar, items)
    local width = bar:GetWidth()
    local words = FillTabs(bar, items)
    if #items == 0 then return end
    local spare, x = (width - words) / #items, 0
    for i = 1, #items do
        local button = bar.buttons[i]
        local w = i == #items and width - x or math.floor(button.want + spare + 0.5)
        button:SetSize(w, TAB_H)
        button:SetPoint("LEFT", x, 0)
        if i > 1 then Split(bar, i, x) end
        x = x + w
    end
end

function Parts.FitTabs(bar, items, margin, maxW)
    Parts.SetTabs(bar, items)
    local words = 0
    for i = 1, #items do words = words + bar.buttons[i].want end
    bar:SetWidth(math.min(maxW or math.huge, words + margin * #items))
    Parts.SetTabs(bar, items)
end

function Parts.Tabs(parent, width, items, onPick)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, TAB_H)
    ns.Solid(bar, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(bar, BORDER_RGB)
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
    box:HookScript("OnEditFocusGained", SearchFocus)
    box:HookScript("OnEditFocusLost", SearchBlur)
    return box
end
