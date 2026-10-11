-- Panel.lua: the HUD Editor's Elements panel: every element, to find, hide while editing and lock.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI
local H = ns.HudEditor

local placement = H.placement
local Marks, IsHidden, IsLocked = H.Marks, H.IsHidden, H.IsLocked
local Refresh, PaintMarks = H.Refresh, H.PaintMarks

local C = H.C
local PANEL_W, PANEL_PAD, PANEL_HEAD = 248, 12, 40
local PANEL_LIST_H = 420
local PANEL_X, PANEL_Y, PANEL_LEVEL = 16, -140, 505
local ROW_H, GROUP_H = 24, 22
local ROW_ICON, ROW_ICON_GAP = 14, 8
local ROW_HIDDEN_ALPHA = 0.45
local ROW_FILL = 0.16
local TITLE_SIZE, GROUP_SIZE, ROW_TEXT_SIZE = 14, 10, 12
local GROUP_TITLE_DROP = 6
local PANEL_NAME = "NaowhForeverHudElements"
local OTHER_GROUP = "Other"
local TEXT_TITLE = ns.L("Elements")
local TEXT_FIND = ns.L("Find an element")
local TEXT_HIDDEN = ns.L(" hidden")
local TEXT_LOCK, TEXT_UNLOCK = ns.L("Lock in place"), ns.L("Unlock")
local TEXT_HIDE, TEXT_SHOW = ns.L("Hide while editing"), ns.L("Show while editing")

local panel, panelQueued
local RefreshPanel

local function GroupOf(item)
    return item.page and item.page:match("^[^/]+") or OTHER_GROUP
end

local function ByName(a, b) return ns.L(a.name) < ns.L(b.name) end
local function ByLabel(a, b) return ns.L(a.label) < ns.L(b.label) end

local function Matches(item, filter)
    return filter == "" or ns.Lower(ns.L(item.label)):find(filter, 1, true) or item.label:lower():find(filter, 1, true)
end

local function PanelList()
    local filter = ns.Lower(panel.search:GetText())
    local groups, byName = {}, {}
    for _, item in ipairs(placement.items) do
        if item.handle:IsShown() and Matches(item, filter) then
            local name = GroupOf(item)
            local group = byName[name]
            if not group then
                group = { name = name }
                byName[name] = group
                groups[#groups + 1] = group
            end
            group[#group + 1] = item
        end
    end
    table.sort(groups, ByName)
    for _, group in ipairs(groups) do table.sort(group, ByLabel) end
    return groups
end

local function ToggleMark(key, item)
    local marks = Marks(key)
    marks[item.label] = not marks[item.label] or nil
    PaintMarks(item)
    Refresh(item)
    RefreshPanel()
end

local function RowEnter(row)
    local item = row.item
    if item and not IsHidden(item) then
        item.hovered = true
        Refresh(item)
    end
end

local function RowLeave(row)
    local item = row.item
    if item then
        item.hovered = false
        Refresh(item)
    end
end

local function RowClicked(row)
    if row.item then UI.SelectMover(row.item.handle, IsShiftKeyDown()) end
end

local function RowIcon(row, texture, tip, onClick)
    local icon = ns.Shared.Parts.IconButton(row, onClick, texture, nil, tip)
    icon:SetSize(ROW_ICON, ROW_ICON)
    icon.icon:SetSize(ROW_ICON, ROW_ICON)
    return icon
end

local function NewRow(child)
    local St = ns.Shared.Style
    local row = CreateFrame("Button", nil, child)
    row:SetHeight(ROW_H)
    row.fill = ns.Solid(row, "BACKGROUND", T.accent, ROW_FILL)
    row.fill:SetAllPoints()
    row.mark = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.mark:SetPoint("TOPLEFT")
    row.mark:SetPoint("BOTTOMLEFT")
    row.mark:SetWidth(C.MOVER_STRIP)
    row.lock = RowIcon(row, St.LOCK, TEXT_LOCK, function() ToggleMark("locked", row.item) end)
    row.lock:SetPoint("RIGHT", -PANEL_PAD, 0)
    row.eye = RowIcon(row, St.EYE, TEXT_HIDE, function() ToggleMark("hidden", row.item) end)
    row.eye:SetPoint("RIGHT", row.lock, "LEFT", -ROW_ICON_GAP, 0)
    row.label = ns.Font(row, ROW_TEXT_SIZE)
    row.label:SetPoint("LEFT", PANEL_PAD, 0)
    row.label:SetPoint("RIGHT", row.eye, "LEFT", -ROW_ICON_GAP, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function PaintRow(row, item)
    local St = ns.Shared.Style
    local hidden, locked, picked = IsHidden(item), IsLocked(item), item.selected == true
    row.item = item
    row.label:SetText(ns.L(item.label))
    row.label:SetTextColor(T.fg.r, T.fg.g, T.fg.b, hidden and ROW_HIDDEN_ALPHA or 1)
    row.fill:SetShown(picked)
    row.mark:SetShown(picked)
    row.eye.icon:SetTexture(hidden and St.EYE_OFF or St.EYE, nil, nil, "TRILINEAR")
    row.eye.tip = hidden and TEXT_SHOW or TEXT_HIDE
    local eye = hidden and T.fg or T.muted
    row.eye.icon:SetVertexColor(eye.r, eye.g, eye.b, 1)
    row.lock.tip = locked and TEXT_UNLOCK or TEXT_LOCK
    local lock = locked and T.accent or T.muted
    row.lock.icon:SetVertexColor(lock.r, lock.g, lock.b, locked and 1 or ROW_HIDDEN_ALPHA)
end

local function GroupTitle(g, name, y)
    local title = panel.titles[g]
    if not title then
        title = ns.Font(panel.child, GROUP_SIZE, nil, T.muted)
        panel.titles[g] = title
    end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", PANEL_PAD, -(y + GROUP_H - GROUP_TITLE_DROP))
    title:SetText(ns.Upper(ns.L(name)))
    title:Show()
end

local function PanelRow(r, item, y)
    local rows = panel.rows
    local row = rows[r] or NewRow(panel.child)
    rows[r] = row
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", 0, -y)
    PaintRow(row, item)
    row:Show()
end

local function HideUnused(r, g)
    local rows, titles = panel.rows, panel.titles
    for i = r + 1, #rows do
        rows[i].item = nil
        rows[i]:Hide()
    end
    for i = g + 1, #titles do titles[i]:Hide() end
end

local function DrawPanel()
    panelQueued = false
    if not (panel and panel:IsShown()) then return end
    local y, r, g, shown, hidden = 0, 0, 0, 0, 0
    for _, group in ipairs(PanelList()) do
        g = g + 1
        GroupTitle(g, group.name, y)
        y = y + GROUP_H
        for _, item in ipairs(group) do
            r = r + 1
            PanelRow(r, item, y)
            y = y + ROW_H
            shown = shown + 1
            if IsHidden(item) then hidden = hidden + 1 end
        end
    end
    HideUnused(r, g)
    panel.child:SetHeight(math.max(1, y))
    panel.count:SetText(hidden > 0 and (shown .. ns.Shared.Style.PLACE_DOT .. hidden .. TEXT_HIDDEN) or tostring(shown))
end

function RefreshPanel()
    if panelQueued or not (panel and panel:IsShown()) then return end
    panelQueued = true
    C_Timer.After(0, DrawPanel)
end

local function StartMoving(self) self:StartMoving() end
local function StopMoving(self) self:StopMovingOrSizing() end

local function PanelFrame()
    local St = ns.Shared.Style
    local f = CreateFrame("Frame", PANEL_NAME, UIParent)
    f:SetSize(PANEL_W, PANEL_HEAD + St.SEARCH_H + PANEL_PAD + PANEL_LIST_H + PANEL_PAD)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", PANEL_X, PANEL_Y)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(PANEL_LEVEL)
    f:SetClampedToScreen(true)
    ns.AllowOffscreen(f)
    ns.Shared.Parts.Backdrop(f):Paint(St.BACKDROP_ALPHA)
    ns.Border(f, St.BORDER_RGB)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", StartMoving)
    f:SetScript("OnDragStop", StopMoving)
    return f
end

local function PanelHead(f)
    local St = ns.Shared.Style
    local title = ns.Font(f, TITLE_SIZE)
    title:SetPoint("LEFT", f, "TOPLEFT", PANEL_PAD, -PANEL_HEAD / 2)
    title:SetText(TEXT_TITLE)
    f.count = ns.Font(f, C.LABEL_SIZE, nil, T.muted)
    f.count:SetPoint("RIGHT", f, "TOPRIGHT", -PANEL_PAD, -PANEL_HEAD / 2)
    f.search = ns.Shared.Parts.SearchBox(f, TEXT_FIND, function() RefreshPanel() end)
    f.search:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_HEAD)
    f.search:SetPoint("TOPRIGHT", -PANEL_PAD, -PANEL_HEAD)
    f.search:SetHeight(St.SEARCH_H)
end

local function PanelScroll(f)
    local St = ns.Shared.Style
    local scroll = UI.SlimScroll(f)
    scroll:SetPoint("TOPLEFT", 0, -(PANEL_HEAD + St.SEARCH_H + PANEL_PAD))
    scroll:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(PANEL_W - PANEL_PAD, 1)
    scroll:SetScrollChild(child)
    f.child, f.rows, f.titles = child, {}, {}
end

local function BuildPanel()
    if panel then return panel end
    local f = PanelFrame()
    PanelHead(f)
    PanelScroll(f)
    f:SetScript("OnShow", function() RefreshPanel() end)
    f:Hide()
    panel = f
    return f
end

local function ShowPanel(shown)
    if shown then BuildPanel():Show() elseif panel then panel:Hide() end
end

H.RefreshPanel, H.ShowPanel = RefreshPanel, ShowPanel
