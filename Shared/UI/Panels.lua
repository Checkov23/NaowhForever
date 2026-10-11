-- Panels.lua: a window's backdrop and its cards, the panel a view sits in, and the side panel that opens beside a window (ns.Shared.Parts).
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Parts = Shared.Parts
local St = Shared.Style

local PANEL_W, PANEL_PAD, PANEL_INSET = St.PANEL_W, St.PANEL_PAD, St.PANEL_INSET
local PANEL_HEADER, PANEL_BUTTONS, BORDER_RGB = St.PANEL_HEADER, St.PANEL_BUTTONS, St.BORDER_RGB
local CARD_FILL, CARD_EDGE = St.WINDOW_CARD_FILL, St.WINDOW_CARD_EDGE
local GRADIENT_SUBLEVEL, PATTERN_SUBLEVEL, CARD_SUBLEVEL = -8, -7, -6
local PANEL_ALPHA = 0.96
local SCROLL_GAP = 20
local SIDE_MIN_H = 320
local BUTTON_GAP, BUTTON_H = 4, 24
local BESIDE_GAP, BESIDE_ROOM = 4, 8
local EDGES = {
    { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
    { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true },
}

local sidePanels = {}

local Backdrop = {}
Backdrop.__index = Backdrop

function Backdrop:Keep(texture, color, alpha)
    texture.color, texture.alpha = color, alpha
    self.flat[#self.flat + 1] = texture
    return texture
end

function Backdrop:Card(left, top, right, bottom)
    local frame = self.frame
    local fill = self:Keep(frame:CreateTexture(nil, "BACKGROUND", nil, CARD_SUBLEVEL), T.fg, CARD_FILL)
    fill:SetPoint("TOPLEFT", left, -top)
    fill:SetPoint("BOTTOMRIGHT", -right, bottom)
    local parts = { fill }
    for _, edge in ipairs(EDGES) do
        local line = self:Keep(frame:CreateTexture(nil, "BORDER"), BORDER_RGB, CARD_EDGE)
        line:SetPoint(edge[1], fill)
        line:SetPoint(edge[2], fill)
        ns.Hairline(line, edge[3] and "v" or "h")
        parts[#parts + 1] = line
    end
    return parts
end

function Backdrop:Paint(alpha)
    local top, bg = T.panel, T.bg
    self.bottom:SetRGBA((top.r + bg.r) / 2, (top.g + bg.g) / 2, (top.b + bg.b) / 2, alpha)
    self.top:SetRGBA(top.r, top.g, top.b, alpha)
    self.gradient:SetGradient("VERTICAL", self.bottom, self.top)
    local pattern = self.pattern
    if pattern then
        local shade = St.CLASSIC_PATTERN_SHADE
        pattern:SetVertexColor(shade, shade, shade, St.CLASSIC_PATTERN_ALPHA * alpha)
    end
    local flat = self.flat
    for i = 1, #flat do
        local texture = flat[i]
        local c = texture.color
        texture:SetColorTexture(c.r, c.g, c.b, texture.alpha * alpha)
    end
end

local function Owner(frame)
    while frame:GetParent() and frame:GetParent() ~= UIParent do frame = frame:GetParent() end
    return frame
end

local function SideButtons(panel, actions)
    local count = math.max(1, #actions)
    local width = (PANEL_W - PANEL_PAD * 2 - BUTTON_GAP * (count - 1)) / count
    local previous
    for _, action in ipairs(actions) do
        local button = ns.Button(panel, action[1], width, BUTTON_H, action[2])
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", BUTTON_GAP, 0)
        else
            button:SetPoint("BOTTOMLEFT", PANEL_PAD, PANEL_PAD)
        end
        panel.buttons[action[1]] = button
        previous = button
    end
end

local function HideOthers(panel)
    for _, other in ipairs(sidePanels) do
        if other ~= panel then other:Hide() end
    end
end

local function CloseWith(panel, owner)
    if panel.owners[owner] then return end
    panel.owners[owner] = true
    owner:HookScript("OnHide", function() panel:Hide() end)
end

local function PlaceBeside(panel, owner)
    panel:ClearAllPoints()
    local right = (owner:GetRight() or 0) * owner:GetEffectiveScale()
    local room = UIParent:GetRight() * UIParent:GetEffectiveScale() - right
    if room >= (PANEL_W + BESIDE_ROOM) * owner:GetEffectiveScale() then
        panel:SetPoint("TOPLEFT", owner, "TOPRIGHT", BESIDE_GAP, 0)
    else
        panel:SetPoint("TOPRIGHT", owner, "TOPLEFT", -BESIDE_GAP, 0)
    end
end

function Parts.Backdrop(frame)
    local backdrop = setmetatable({ frame = frame, flat = {} }, Backdrop)
    backdrop.gradient = frame:CreateTexture(nil, "BACKGROUND", nil, GRADIENT_SUBLEVEL)
    backdrop.gradient:SetAllPoints()
    backdrop.gradient:SetColorTexture(1, 1, 1, 1)
    backdrop.bottom, backdrop.top = CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 1)
    if ns.classicSkin then
        local pattern = frame:CreateTexture(nil, "BACKGROUND", nil, PATTERN_SUBLEVEL)
        pattern:SetAllPoints()
        pattern:SetTexture(St.CLASSIC_PATTERN, "REPEAT", "REPEAT")
        pattern:SetHorizTile(true)
        pattern:SetVertTile(true)
        backdrop.pattern = pattern
    end
    return backdrop
end

function Parts.Panel(title, windowLook)
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetWidth(PANEL_W)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    if windowLook then
        panel.backdrop = Parts.Backdrop(panel)
    else
        ns.Solid(panel, "BACKGROUND", T.bg, PANEL_ALPHA):SetAllPoints()
    end
    ns.Border(panel, BORDER_RGB)
    panel.title = ns.Font(panel, St.TEXT_SIZE, nil, T.accent)
    panel.title:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_PAD)
    panel.title:SetPoint("RIGHT", -St.CLOSE_ROOM, 0)
    panel.title:SetJustifyH("LEFT")
    panel.title:SetWordWrap(false)
    panel.title:SetText(ns.L(title))
    panel.close = ns.Button(panel, "x", St.CLOSE_SIZE, St.CLOSE_SIZE, function() panel:Hide() end)
    panel.close:SetPoint("TOPRIGHT", -St.CLOSE_IN, -St.CLOSE_IN)
    return panel
end

function Parts.SidePanel(actions, newView, opacity)
    local bottom = #actions > 0 and PANEL_BUTTONS or 0
    local panel = Parts.Panel("", true)
    panel:SetFrameStrata("HIGH")
    panel.opacity = opacity
    panel.backdrop:Card(PANEL_INSET, PANEL_HEADER, PANEL_INSET, bottom + PANEL_INSET)
    panel.backdrop:Paint(opacity())
    local scroll = ns.UI.SlimScroll(panel)
    scroll:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_HEADER - PANEL_INSET)
    scroll:SetPoint("BOTTOMRIGHT", -PANEL_PAD - SCROLL_GAP, bottom + PANEL_PAD)
    local view = newView(scroll)
    view:SetWidth(PANEL_W - PANEL_PAD * 2 - SCROLL_GAP)
    scroll:SetScrollChild(view)
    panel.scroll, panel.view, panel.owners, panel.buttons = scroll, view, {}, {}
    SideButtons(panel, actions)
    sidePanels[#sidePanels + 1] = panel
    return panel
end

function Parts.RepaintSidePanels()
    for _, panel in ipairs(sidePanels) do panel.backdrop:Paint(panel.opacity()) end
end

function Parts.ShowBeside(panel, from)
    HideOthers(panel)
    local owner = Owner(from)
    CloseWith(panel, owner)
    panel:SetScale(owner:GetScale())
    panel:SetHeight(math.max(SIDE_MIN_H, owner:GetHeight()))
    PlaceBeside(panel, owner)
    panel.scroll:SetVerticalScroll(0)
    panel:Show()
end
