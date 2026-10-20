-- MapPinsPanel.lua: the Town Pins button on the world map and its drawer of which town pins show.
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI
local St = ns.Shared.Style
local DIM_ALPHA = ns.Shared.Settings.Style.DIM_ALPHA
local S = ns.QoLSettings

local PAD, HEAD_H, ROW_H, ROW_MIN_H = 14, 40, 28, 20
local LABEL_SIZE, NAME_SIZE, SMALL_SIZE, FOOT_SIZE = 13, 14, 11, 9
local GROUP_DROP, LABEL_GAP = 7, 8
local RULE_ALPHA = 0.6
local PANEL_W = 330
local PANEL_LEVEL = 100
local CONTROL_LEVEL = 2
local BORDERS = 2
local GAP = -1
local BAR_MARGIN, BAR_MIN_W = 8, 200
local UNDER_BUTTON = 4
local CLOSE_SIZE, CLOSE_IN = 22, 9
local BUTTON_SIZE, BUTTON_GAP, BUTTON_RIGHT, BUTTON_TOP = 32, 2, 4, 2
local BUTTON_ALPHA = 0.9
local ICON_INSET = 4
local SCROLL_W, SCROLL_IN = 4, 2
local TRACK_W, BOX_W, BOX_H, BOX_ALPHA, SLIDER_GAP = 70, 30, 14, 1, 6

local TEXT_TITLE = ns.L("Town Pins")
local TEXT_TIP = ns.L("Click to choose which town pins show on the map.")
local TEXT_CLOSE = "x"
local TEXT_TOWN, TEXT_TOWN_PINS, TEXT_TOWN_TIP = ns.TownPinTexts.group, ns.TownPinTexts.switch, ns.TownPinTexts.tip
local TEXT_SIZE, TEXT_SIZE_TIP = ns.L("Town Pin Size"), ns.L("How big the town pins are on the world map and minimap.")

local ROWS = ns.TownPinRows

local button, buttonBorder, panel, content
local rows, strips = {}, {}

local function TownOn()
    return S.Get("townMap")
end

local function On()
    return S.Get("enabled") and not ns.GamepadStandDown()
end

local function PanelWidth()
    local log = WorldMapFrame.QuestLog or _G.QuestMapFrame
    local w = log and log:GetWidth() or 0
    return w > 0 and w or PANEL_W
end

local function Needed(row)
    local needs = row.needs
    if type(needs) == "function" then return needs() end
    if type(needs) == "string" then return row.store.Get(needs) end
    for _, key in ipairs(needs) do
        if not row.store.Get(key) then return false end
    end
    return true
end

local function RefreshRows()
    for _, row in ipairs(rows) do
        row.control._refreshValue()
        if row.needs then
            local on = Needed(row) and true or false
            local alpha = on and 1 or DIM_ALPHA
            row.label:SetAlpha(alpha)
            row.control:SetAlpha(alpha)
            row.control:EnableMouse(on)
            local box = row.control._valBox
            if box then
                box:SetAlpha(alpha)
                box:EnableMouse(on)
                if not on then box:ClearFocus() end
            end
        end
    end
end

local function Rule(frame, alpha)
    local rule = ns.Solid(frame, "ARTWORK", T.line, alpha or RULE_ALPHA)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    ns.Hairline(rule, "h")
end

local function Strip(parent, y, h, inset)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(h)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, y)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, y)
    return frame
end

local function Layout(rowH)
    local y = 0
    for _, frame in ipairs(strips) do
        frame:SetHeight(rowH)
        frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        y = y - rowH
    end
    content:SetHeight(-y)
    return HEAD_H + BORDERS - y
end

local function MakeGroup(parent, title)
    local frame = Strip(parent, 0, ROW_H, 0)
    strips[#strips + 1] = frame
    local text = ns.Font(frame, SMALL_SIZE, nil, T.accentSoft)
    text:SetPoint("BOTTOMLEFT", PAD, GROUP_DROP)
    text:SetText(title)
    Rule(frame)
end

local function SetRow(store, key, value)
    store.Set(key, value)
    if UI.RefreshPage then UI:RefreshPage(true) end
end

local function BuildToggle(frame, store, key)
    local control = UI.BuildToggleControl(frame, frame:GetFrameLevel() + CONTROL_LEVEL,
        function() return store.Get(key) end,
        function(value) SetRow(store, key, value) end)
    control:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    return control
end

local function BuildSlider(frame, store, key, range)
    local track, box = UI.BuildSliderCore(frame, TRACK_W, St.SLIDER_H, St.KNOB, BOX_W, BOX_H, FOOT_SIZE, BOX_ALPHA,
        range[1], range[2], range[3],
        function() return store.Get(key) end,
        function(value) SetRow(store, key, value) end)
    box:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    track:SetPoint("RIGHT", box, "LEFT", -SLIDER_GAP, 0)
    return track
end

local function MakeRow(parent, store, key, text, tip, needs, range)
    local frame = Strip(parent, 0, ROW_H, 0)
    strips[#strips + 1] = frame
    frame:EnableMouse(true)
    Rule(frame)
    local control = range and BuildSlider(frame, store, key, range) or BuildToggle(frame, store, key)
    local label = ns.Font(frame, range and FOOT_SIZE or LABEL_SIZE, nil, range and T.muted or T.fg)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetPoint("LEFT", PAD, 0)
    label:SetPoint("RIGHT", control, "LEFT", -LABEL_GAP, 0)
    label:SetText(ns.L(text))
    if tip then ns.Tooltip(frame, text, tip) end
    rows[#rows + 1] = { control = control, label = label, needs = needs, store = store }
end

local function PlaceMaximized(map)
    local canvas = map:GetCanvasContainer()
    local bar = (canvas:GetLeft() or 0) - (map:GetLeft() or 0) - BAR_MARGIN * 2
    local room = canvas:GetHeight()
    if bar >= BAR_MIN_W then
        panel:SetWidth(math.min(PanelWidth(), bar))
        panel:SetPoint("TOPRIGHT", canvas, "TOPLEFT", -BAR_MARGIN, 0)
    else
        panel:SetWidth(PanelWidth())
        panel:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -UNDER_BUTTON)
        room = room - button:GetHeight() - UNDER_BUTTON - BUTTON_TOP
    end
    panel:SetHeight(math.min(Layout(ROW_H), room))
end

local function PlaceWindowed(map)
    local w = PanelWidth()
    panel:SetWidth(w)
    if (map:GetLeft() or 0) >= w + GAP then
        panel:SetPoint("TOPRIGHT", map, "TOPLEFT", -GAP, 0)
    else
        panel:SetPoint("TOPLEFT", map, "TOPRIGHT", GAP, 0)
    end
    local fit = math.floor((map:GetHeight() - HEAD_H - BORDERS) / #strips)
    Layout(math.max(ROW_MIN_H, math.min(ROW_H, fit)))
    panel:SetHeight(map:GetHeight())
end

local function PlacePanel()
    if not panel then return end
    local map = WorldMapFrame
    panel:ClearAllPoints()
    if map.IsMaximized and map:IsMaximized() then
        PlaceMaximized(map)
    else
        PlaceWindowed(map)
    end
end

local function HidePanel()
    panel:Hide()
end

local function BuildPanel()
    panel = CreateFrame("Frame", nil, WorldMapFrame)
    panel:SetWidth(PanelWidth())
    panel:SetFrameLevel(WorldMapFrame:GetFrameLevel() + PANEL_LEVEL)
    panel:EnableMouse(true)
    panel:Hide()
    ns.Solid(panel, "BACKGROUND", T.bg, St.BACKDROP_ALPHA):SetAllPoints()
    ns.Border(panel, St.BORDER_RGB)
    local head = Strip(panel, -1, HEAD_H, 1)
    ns.Solid(head, "BACKGROUND", T.panel, 1):SetAllPoints()
    Rule(head, 1)
    local title = ns.Font(head, NAME_SIZE, nil, T.fg)
    title:SetPoint("LEFT", PAD, 0)
    title:SetText(TEXT_TITLE)
    local close = ns.Button(head, TEXT_CLOSE, CLOSE_SIZE, CLOSE_SIZE, HidePanel)
    close:SetPoint("RIGHT", -CLOSE_IN, 0)
    local scroll = UI.SlimScroll(panel, SCROLL_W, -SCROLL_W - SCROLL_IN)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1 - HEAD_H)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    scroll.bar:SetFrameLevel(content:GetFrameLevel() + CONTROL_LEVEL)
    scroll:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    MakeGroup(content, TEXT_TOWN:upper())
    MakeRow(content, S, "townMap", TEXT_TOWN_PINS, TEXT_TOWN_TIP)
    local _, class = UnitClass("player")
    for _, row in ipairs(ROWS) do
        if row.header then
            MakeGroup(content, row.header)
        elseif not row.class or row.class == class then
            MakeRow(content, S, row.key, row.text, row.tip, TownOn)
        end
    end
    MakeRow(content, S, "townPinSize", TEXT_SIZE, TEXT_SIZE_TIP, TownOn, ns.TownPinRange)
    panel:SetScript("OnShow", RefreshRows)
    if WorldMapFrame.Maximize then hooksecurefunc(WorldMapFrame, "Maximize", PlacePanel) end
    if WorldMapFrame.Minimize then hooksecurefunc(WorldMapFrame, "Minimize", PlacePanel) end
end

local function MapEdgeButton(canvas)
    local edge, edgeX
    for _, frame in ipairs(WorldMapFrame.overlayFrames or {}) do
        if frame:IsShown() and frame:GetNumPoints() > 0 then
            local point, relative, _, x = frame:GetPoint(1)
            if point == "TOPRIGHT" and relative == canvas and (not edgeX or x < edgeX) then
                edge, edgeX = frame, x
            end
        end
    end
    return edge
end

local function PlaceButton()
    local canvas = WorldMapFrame:GetCanvasContainer()
    local edge = MapEdgeButton(canvas)
    button:ClearAllPoints()
    if edge then
        local w, h = edge:GetSize()
        button:SetSize(w > 0 and w or BUTTON_SIZE, h > 0 and h or BUTTON_SIZE)
        button:SetPoint("TOPRIGHT", edge, "TOPLEFT", -BUTTON_GAP, 0)
    else
        button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -BUTTON_RIGHT, -BUTTON_TOP)
    end
end

local function OnButtonClick()
    if not panel then BuildPanel() end
    PlacePanel()
    panel:SetShown(not panel:IsShown())
end

local function OnButtonEnter()
    buttonBorder:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
end

local function OnButtonLeave()
    buttonBorder:SetColor(St.BORDER_RGB.r, St.BORDER_RGB.g, St.BORDER_RGB.b, 1)
end

local function OnMapShow()
    PlaceButton()
    PlacePanel()
end

local function BuildButton()
    button = CreateFrame("Button", nil, WorldMapFrame:GetCanvasContainer())
    button:SetFrameStrata("DIALOG")
    ns.Solid(button, "BACKGROUND", T.bg, BUTTON_ALPHA):SetAllPoints()
    buttonBorder = ns.Border(button, St.BORDER_RGB)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(St.LOGO_SMALL)
    icon:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
    icon:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
    button:SetScript("OnClick", OnButtonClick)
    button:SetScript("OnEnter", OnButtonEnter)
    button:SetScript("OnLeave", OnButtonLeave)
    ns.Tooltip(button, TEXT_TITLE, TEXT_TIP)
    PlaceButton()
    WorldMapFrame:HookScript("OnShow", OnMapShow)
end

local function Apply()
    if On() then
        if not button then BuildButton() end
        button:Show()
        if panel and panel:IsShown() then RefreshRows() end
    elseif button then
        button:Hide()
        if panel then panel:Hide() end
    end
end

local function OnSettingSet(key)
    if key == "enabled" or key:find("^town") then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSettingSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
