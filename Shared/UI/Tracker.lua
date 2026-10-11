-- Tracker.lua: a tracker's small window (ns.Shared.Parts.TrackerPanel), and a list row's bands (Parts.RowBands).
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Parts = Shared.Parts
local St = Shared.Style

local TRACKER_W, PANEL_PAD, PANEL_HEADER, ACTION = St.TRACKER_W, St.PANEL_PAD, St.PANEL_HEADER, St.ACTION
local PANEL_INSET = St.PANEL_INSET
local SLOT_H, SLOT_GAP, SCROLL_GAP, CLOSE_ROOM = St.TRACKER_SLOT, St.TRACKER_GAP, St.TRACKER_SCROLL, St.CLOSE_ROOM
local ROW_LEFT, WAYPOINT_SLOT, ROW_RIGHT, TICK = St.ROW_LEFT, St.WAYPOINT_SLOT, St.ROW_RIGHT, St.ROW_TICK
local ROW_TOP, ROW_LINE_GAP, ROW_BOTTOM = St.ROW_TOP, St.ROW_LINE_GAP, St.ROW_BOTTOM
local HEAD_GAP = 4
local FOOTER = ACTION + 6
local TEXT_LEFT = ROW_LEFT + WAYPOINT_SLOT + 6
local PIN_X = ROW_LEFT + WAYPOINT_SLOT / 2
local TEXT_SIZE, SUB_SIZE, BAR_TEXT_SIZE = 13, St.SMALL_SIZE, St.TEXT_SIZE
local TITLE_HIT = 4
local PICKER_LEVEL = 3
local CENTER = { "CENTER", "CENTER", 0, 0 }
local TEXT_PIN = "Waypoint"
local TEXT_PIN_HINT = "Click to mark it on your map."

local Tracker = {}

local function RowEnter(row)
    row.hover:Show()
    local tip = row.entry and row.entry.tip
    if not (tip and Parts.Tip(row, "ANCHOR_LEFT")) then return end
    tip(row)
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function RowClick(row, button)
    local click = row.entry and row.entry.click
    if click then click(row, button) end
end

local function PinClick(pin)
    local entry = pin:GetParent().entry
    if entry and entry.waypoint then entry.waypoint(entry) end
end

local function RowText(row, size, color)
    local text = ns.Font(row, size, nil, color)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    return text
end

local function PinAt(region, row, line)
    region:ClearAllPoints()
    region:SetPoint("CENTER", row, "TOPLEFT", PIN_X, line)
end

local function FillRow(row, entry, width)
    local color = entry.color or T.fg
    row.text:SetTextColor(color.r, color.g, color.b)
    row.text:SetWidth(width)
    row.text:SetText(entry.text)
    local textH = math.ceil(row.text:GetStringHeight())
    local h = ROW_TOP + textH + ROW_BOTTOM
    row.sub:SetWidth(width)
    row.sub:SetText(entry.sub or "")
    row.sub:SetShown(entry.sub ~= nil)
    if entry.sub then h = h + ROW_LINE_GAP + math.ceil(row.sub:GetStringHeight()) end
    local line = -(ROW_TOP + textH / 2)
    PinAt(row.pin, row, line)
    row.pin:SetShown(entry.waypoint ~= nil and not entry.done)
    PinAt(row.tick, row, line)
    row.tick:SetShown(entry.done == true)
    return h
end

local function DragStart(frame)
    frame:StartMoving()
end

local function SaveWhere(panel)
    local save = panel.opts.save
    if not save then return end
    local point, _, relativePoint, x, y = panel:GetPoint(1)
    save(point, relativePoint, x, y)
end

local function DragStop(frame)
    frame:StopMovingOrSizing()
    SaveWhere(frame)
end

local function TitleDragStart(button)
    button:GetParent():StartMoving()
end

local function TitleDragStop(button)
    DragStop(button:GetParent())
end

local function TitleClick(button)
    local onTitle = button:GetParent().opts.onTitle
    if onTitle then onTitle() end
end

local function TitleEnter(button)
    local panel = button:GetParent()
    local opts = panel.opts
    panel.title:SetTextColor(T.accent.r, T.accent.g, T.accent.b)
    if not opts.titleTip then return end
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(ns.L(opts.titleTip))
    if opts.titleHint then GameTooltip:AddLine(ns.L(opts.titleHint), T.accentSoft.r, T.accentSoft.g, T.accentSoft.b) end
    GameTooltip:Show()
end

local function TitleLeave(button)
    button:GetParent().title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Hide()
end

local function CogClick(button)
    local settings = button:GetParent().opts.settings
    ns.OpenOptionsWindow(settings.page)
    if settings.card then ns.UI.GoToSetting(settings.page, nil, settings.page .. ":" .. settings.card) end
end

local function TitleButton(panel)
    local button = CreateFrame("Button", nil, panel)
    button:SetPoint("TOPLEFT", panel.title, "TOPLEFT", -TITLE_HIT, TITLE_HIT)
    button:SetPoint("BOTTOMRIGHT", panel.title, "BOTTOMRIGHT", 0, -TITLE_HIT)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", TitleClick)
    button:SetScript("OnDragStart", TitleDragStart)
    button:SetScript("OnDragStop", TitleDragStop)
    button:SetScript("OnEnter", TitleEnter)
    button:SetScript("OnLeave", TitleLeave)
    return button
end

local function ProgressBar(panel, width, under)
    local bar = CreateFrame("StatusBar", nil, panel)
    bar:SetSize(width - PANEL_PAD * 2, SLOT_H)
    bar:SetPoint("TOPLEFT", PANEL_PAD, under)
    bar:SetStatusBarTexture(St.WHITE)
    bar.bg = ns.Solid(bar, "BACKGROUND", ns.ThemeTint("panel", St.TRACKER_BAR_RGB), 1)
    bar.bg:SetAllPoints()
    ns.Border(bar, St.BORDER_RGB)
    bar.text = ns.Font(bar, BAR_TEXT_SIZE, "OUTLINE")
    bar.text:SetPoint("CENTER", 0, 0)
    return bar
end

local function Picker(panel, picker, width, under)
    local control = ns.UI.BuildDropdownControl(panel, width - PANEL_PAD * 2, panel:GetFrameLevel() + PICKER_LEVEL,
        picker.values, picker.order, picker.get, picker.set)
    if panel.bar then
        control:SetPoint("TOPLEFT", panel.bar, "BOTTOMLEFT", 0, -SLOT_GAP)
    else
        control:SetPoint("TOPLEFT", PANEL_PAD, under)
    end
    control._menuHeight = picker.menuHeight
    return control
end

local function Cog(panel, settings)
    local cog = Parts.IconButton(panel, CogClick, ns.UI.COGS_ICON, 0, settings.tip)
    cog:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    cog.hint = settings.hint
    return cog
end

local function Movable(panel, opts)
    panel:SetFrameStrata("MEDIUM")
    panel:SetMovable(true)
    ns.AllowOffscreen(panel)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", DragStart)
    panel:SetScript("OnDragStop", DragStop)
    if opts.onClose then panel.close:SetScript("OnClick", opts.onClose) end
end

local function Mover(panel, opts)
    return opts.mover(panel, function(pos)
        if opts.save then opts.save(pos.point, pos.relPoint, pos.x, pos.y) end
    end)
end

function Tracker:Paint()
    local opacity = self.opts.opacity
    self.backdrop:Paint(opacity and opacity() or 1)
end

function Tracker:Place()
    local opts = self.opts
    self:ClearAllPoints()
    local point, relativePoint, x, y
    if opts.load then point, relativePoint, x, y = opts.load() end
    if type(point) ~= "string" then
        local place = opts.place or CENTER
        point, relativePoint, x, y = place[1], place[2], place[3], place[4]
    end
    self:SetPoint(point, UIParent, relativePoint, x, y)
end

function Tracker:ScrollGap()
    return self.scrolling and SCROLL_GAP or 0
end

function Tracker:Top()
    local top = PANEL_HEADER + HEAD_GAP
    if self.bar and self.bar:IsShown() then top = top + SLOT_H + SLOT_GAP end
    if self.picker and self.picker:IsShown() then top = top + SLOT_H + SLOT_GAP end
    return top
end

function Tracker:SetTrackerWidth(w)
    local inner = w - PANEL_PAD * 2
    self:SetWidth(w)
    if self.bar then self.bar:SetWidth(inner) end
    if self.picker then self.picker:SetWidth(inner) end
    self.scroll:SetPoint("BOTTOMRIGHT", -PANEL_PAD - self:ScrollGap(), PANEL_PAD + self.footer)
    self.body:SetWidth(inner - self:ScrollGap())
end

function Tracker:Fit(height)
    local top = self:Top()
    self.scroll:SetPoint("TOPLEFT", PANEL_PAD, -top)
    local full = top + height + self.footer + PANEL_PAD
    local maxHeight = self.opts.maxHeight and self.opts.maxHeight()
    self:SetHeight(maxHeight and math.min(maxHeight, full) or full)
    local scrolls = maxHeight ~= nil and full > maxHeight
    if scrolls == self.scrolling then return false end
    self.scrolling = scrolls
    return true
end

function Tracker:Row(i)
    local row = self.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, self.body)
    Parts.RowBands(row, ROW_LEFT)
    row.pin = Parts.IconButton(row, PinClick, St.PIN, 0, TEXT_PIN)
    row.pin.hint = TEXT_PIN_HINT
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.tick:SetTexture(St.CHECK)
    row.tick:SetSize(TICK, TICK)
    row.text = RowText(row, TEXT_SIZE, T.fg)
    row.text:SetPoint("TOPLEFT", TEXT_LEFT, -ROW_TOP)
    row.sub = RowText(row, SUB_SIZE, T.muted)
    row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -ROW_LINE_GAP)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)
    self.rows[i] = row
    return row
end

function Tracker:SetRows(entries)
    local body = self.body
    local width = body:GetWidth() - TEXT_LEFT - ROW_RIGHT
    local y, count = 0, #entries
    for i = 1, count do
        local row = self:Row(i)
        row.entry = entries[i]
        row:SetWidth(body:GetWidth())
        row.stripe:SetShown(i % 2 == 0)
        row.hover:Hide()
        local h = FillRow(row, entries[i], width)
        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        row.divider:SetShown(i < count)
        row:Show()
        y = y + h
    end
    for i = count + 1, #self.rows do self.rows[i]:Hide() end
    body:SetHeight(math.max(y, 1))
    return y
end

function Parts.RowBands(row, dividerLeft)
    row.stripe = ns.Solid(row, "BACKGROUND", T.fg, St.STRIPE)
    row.stripe:SetAllPoints()
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.ROW_HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.divider = ns.Solid(row, "BORDER", T.line, St.ROW_DIVIDER)
    row.divider:SetPoint("BOTTOMLEFT", dividerLeft, 0)
    row.divider:SetPoint("BOTTOMRIGHT")
    ns.Hairline(row.divider, "h")
end

function Parts.TrackerPanel(title, opts)
    local panel = Parts.Panel(title, true)
    Mixin(panel, Tracker)
    panel.opts, panel.rows, panel.scrolling = opts, {}, false
    panel.backdrop:Card(PANEL_INSET, PANEL_HEADER, PANEL_INSET, PANEL_INSET)
    panel.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    panel.title:SetPoint("RIGHT", -CLOSE_ROOM - (opts.titleRoom or 0), 0)
    Movable(panel, opts)
    panel.titleButton = TitleButton(panel)
    local width = opts.width or TRACKER_W
    local under = -PANEL_HEADER - HEAD_GAP
    if opts.bar then panel.bar = ProgressBar(panel, width, under) end
    if opts.picker then panel.picker = Picker(panel, opts.picker, width, under) end
    panel.footer = opts.settings and FOOTER or 0
    if opts.settings then panel.settings = Cog(panel, opts.settings) end
    panel.scroll = ns.UI.SlimScroll(panel)
    panel.scroll:SetPoint("TOPLEFT", PANEL_PAD, -panel:Top())
    panel.body = opts.newBody and opts.newBody(panel.scroll) or CreateFrame("Frame", nil, panel.scroll)
    panel:SetTrackerWidth(width)
    panel.scroll:SetScrollChild(panel.body)
    if opts.mover then panel.mover = Mover(panel, opts) end
    return panel
end
