-- Window.lua: RestedXP's guide in one Naowh window: its progress, the active step and the steps after it.
local ns = _G.NaowhForever
local Safe = ns.RXPSafe
local Has, Dig, Run = Safe.Has, Safe.Dig, Safe.Run

local WIDTH_MIN, WIDTH_MAX = ns.RXPWindowWidthRange()
local STEPS_MAX = select(2, ns.RXPWindowStepsRange())

local WINDOW_NAME = "NaowhRXPWindow"
local STRATA = "MEDIUM"
local PERCENT = 100
local PAD, BOX_PAD, FOLD_W, PROGRESS_W = 10, 7, 16, 120
local HEAD_PAD, LIST_PAD = 10, 6
local BOX_TITLE_TEXT, BOX_TITLE_HEIGHT, BOX_TITLE_ROOM = 9, 19, 10
local BAR_W, ICON_GAP, GRIP_SIZE = 2, 5, 16
local FIRST_GROW, FIRST_ICON_GROW, LOGO_SIZE, BAR_HEIGHT, INDENT, ICON_SIZE = 2, 2, 24, 5, 12, 18
local EDGE_SIDES = 2
local HOVER_ALPHA, ICON_DONE_ALPHA = 0.25, 0.5
local COUNT_MIN, COUNT_GAP = 2, 2
local BAG_EVENT = "BAG_UPDATE_DELAYED"
local SHADOW, SHADOW_ALPHA = 1, 0.9
local TEXT_FOLD, TEXT_UNFOLD, TEXT_DOT = "-", "+", " \194\183 "
local LOGO = "Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64"
local GRADIENT = ns.MEDIA .. "NaowhGradient.tga"
local GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
local GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
local GRIP_CORNER = "BOTTOMRIGHT"
local TEXT_SKIP = ns.L("Skip step")
local TEXT_SHIFT = ns.L("Shift-click")
local TEXT_MENU = ns.L("Right-click: menu")
local TEXT_GO = ns.L("Go to step %d")
local TEXT_PICK = ns.L("Pick a guide")
local TIP_DIM = 0.7
local WHEEL_LINES, DONE_ALPHA = 2, 0.5
local SCROLL_W, SCROLL_GAP, SCROLL_MIN = 2, 4, 12
local SCROLL_ROOM = SCROLL_W + SCROLL_GAP
local HOME = { "LEFT", "LEFT", 0, 35 }
local DRAG_BUTTON, TIP_ANCHOR = "LeftButton", "ANCHOR_TOP"
local ACCENT = "accent"
local TARGET_PLACEHOLDER, MOB_PLACEHOLDER = 2056011, 135274
local PLACEHOLDER_GLYPHS = { [TARGET_PLACEHOLDER] = "gossip", [MOB_PLACEHOLDER] = "combat" }
local OUTLINE_FLAGS = { outline = "OUTLINE", thick = "THICKOUTLINE", slug = "OUTLINE, SLUG" }

local window, active, started, pending, styled, wantsBags
local retake = true
local sizing, sizingModel
local scroll, anchorGuide, anchorAfter = 0
local pool, used = { box = {}, row = {}, line = {}, hit = {} }, { box = 0, row = 0, line = 0, hit = 0 }
local silenced = setmetatable({}, { __mode = "k" })
local dressed = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local placeholders = setmetatable({}, { __mode = "k" })
local targetingHooked
local faced = {}
local Draw

local function Settings()
    return ns.AccountSettings()
end

local function Refresh()
    if not active or pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        Draw()
    end)
end

ns.RXPWindowRefresh = Refresh

local function Wheel(_, delta)
    scroll = scroll - delta * WHEEL_LINES
    Refresh()
end

local function RefreshAccepts()
    if not active then return end
    local rxp = _G.RXP
    if not Has(rxp, "ActiveStepElementEventHandler") or type(rxp.questAccept) ~= "table" then return end
    local steps = Dig(rxp.RXPFrame, "activeSteps")
    if not steps then return end
    for _, step in ipairs(steps) do
        if step.active then
            for _, element in ipairs(step.elements or {}) do
                local frame = element.frame
                if element.tag == "accept" and element.questId and not rxp.questAccept[element.questId]
                        and frame and frame.element == element and frame.step == step and Has(frame, "callback") then
                    Run("WindowAccept", rxp.ActiveStepElementEventHandler, frame)
                end
            end
        end
    end
end

local function Rebuilt()
    retake = true
    ns.RXPWindowStale()
    Refresh()
end

local function StepChanged()
    RefreshAccepts()
    Rebuilt()
end

local function Silence(frame, top)
    if not frame then return end
    if not silenced[frame] then
        local home = { mouse = frame:IsMouseEnabled() }
        silenced[frame] = home
        if top then
            home.alpha = frame:GetAlpha()
            frame:SetAlpha(0)
            if not watched[frame] then
                watched[frame] = true
                hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                    if silenced[self] and alpha ~= 0 then self:SetAlpha(0) end
                end)
            end
        end
        frame:EnableMouse(false)
    end
    for _, child in ipairs({ frame:GetChildren() }) do Silence(child, false) end
end

local function Take()
    local guide = Dig(_G.RXPV2GuideWindow, "frame")
    local steps = _G["RXPActiveStepsFrame" .. _G.RXP.player.name]
    steps = Dig(steps, "frame") or steps
    Silence(guide, true)
    Silence(steps, true)
    return guide ~= nil and steps ~= nil
end

local function Release()
    for frame, home in pairs(silenced) do
        silenced[frame] = nil
        if home.alpha then frame:SetAlpha(home.alpha) end
        frame:EnableMouse(home.mouse)
    end
    retake = true
end

local function Save(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then Settings().rxpWindowPos = { point, relativePoint, x, y } end
end

local function Place(frame)
    local saved = Settings().rxpWindowPos
    frame:ClearAllPoints()
    if saved then
        frame:SetPoint(saved[1], UIParent, saved[2] or saved[1], saved[3] or 0, saved[4] or 0)
        return
    end
    local home = Dig(_G.RXPV2GuideWindow, "frame")
    local point, relativePoint, x, y = HOME[1], HOME[2], HOME[3], HOME[4]
    if home then
        local first, _, relative, dx, dy = home:GetPoint(1)
        if first then point, relativePoint, x, y = first, relative, dx, dy end
    end
    frame:SetPoint(point, UIParent, relativePoint, x, y)
end

local function Menu()
    Run("WindowMenu", _G.RXP.RXPFrame.DropDownMenu)
end

local function PickGuide()
    local v2 = _G.RXP.v2
    if v2.ShowGuideSelectionMenu then
        Run("WindowPick", v2.ShowGuideSelectionMenu, v2)
    else
        Menu()
    end
end

local function FacePath()
    local name = ns.RXPWindowOption("rxpWindowFont")
    local custom = name ~= "" and ns.UI.FontPath(name)
    return custom or ns.AddonFontPath(ns.RXPWindowForeverTheme() or nil)
end

local function Faced(fs, size)
    local outline = ns.RXPWindowOption("rxpWindowOutline")
    local path, last = FacePath(), dressed[fs]
    if last and last.path == path and last.size == size and last.outline == outline then return end
    local made = fs:SetFont(path, size, OUTLINE_FLAGS[outline] or "")
    if last then
        last.path, last.size, last.outline = made ~= false and path or nil, size, outline
    end
    if outline == "shadow" then
        fs:SetShadowOffset(SHADOW, -SHADOW)
        fs:SetShadowColor(0, 0, 0, SHADOW_ALPHA)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local function Face(fs, sizeKey)
    Faced(fs, type(sizeKey) == "number" and sizeKey or ns.RXPWindowOption(sizeKey))
end

local function Text(parent, sizeKey, justify, drawn)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs.sizeKey = sizeKey
    dressed[fs] = {}
    if not drawn then faced[#faced + 1] = fs end
    Face(fs, sizeKey)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("TOP")
    return fs
end

local function Refaced()
    for _, fs in ipairs(faced) do Face(fs, fs.sizeKey) end
end

local function Coloured(fs, name)
    local r, g, b, a = ns.RXPWindowColor(name)
    fs:SetTextColor(r, g, b, a)
end

local function SkinBox(part)
    local back, border = part.rxpBackground, part.rxpBorder
    if back then
        local r, g, b = ns.RXPWindowColor("box")
        back.textures[1]:SetVertexColor(r, g, b, ns.RXPWindowOption("rxpWindowBoxOpacity") / PERCENT)
    end
    if not border then return end
    local r, g, b, a = ns.RXPWindowColor("boxBorder")
    for _, texture in ipairs(border.textures) do texture:SetColorTexture(r, g, b, a) end
    border:SetShown(ns.RXPWindowOption("rxpWindowBoxBorder") and (not back or back:IsShown()))
end

local function SkinTitle(title)
    SkinBox(title)
    local text = title.text
    Faced(text, BOX_TITLE_TEXT)
    Coloured(text, "title")
    title:SetSize(text:GetStringWidth() + BOX_TITLE_ROOM, BOX_TITLE_HEIGHT)
end

local function SkinPlaceholders(frame)
    for _, button in ipairs({ frame:GetChildren() }) do
        local texture = button.placeholder
        if texture then
            local id = texture:GetTexture()
            local glyph = PLACEHOLDER_GLYPHS[id]
            local path = glyph and ns.RXPIconTexture(glyph)
            if path then
                placeholders[texture] = id
                texture:SetTexture(path)
            end
        end
    end
end

local function RestorePlaceholders()
    for texture, id in pairs(placeholders) do
        placeholders[texture] = nil
        texture:SetTexture(id)
    end
end

local function SkinFrame(frame)
    SkinBox(frame)
    if frame.title then SkinTitle(frame.title) end
    SkinPlaceholders(frame)
end

local function SkinFrames()
    local rxp = _G.RXP
    local frames = {}
    local target, items = Dig(rxp, "targeting", "activeTargetFrame"), Dig(rxp, "activeItemFrame")
    if target then table.insert(frames, target) end
    if items then table.insert(frames, items) end
    return frames
end

local function SkinHooks(frames)
    for _, frame in ipairs(frames) do
        if not watched[frame] then
            watched[frame] = true
            hooksecurefunc(frame, "UpdateVisuals", function(self)
                if active then SkinFrame(self) end
            end)
        end
    end
    local targeting = Dig(_G.RXP, "targeting")
    if not targeting or targetingHooked then return end
    targetingHooked = true
    hooksecurefunc(targeting, "RenderTargetFrameBackground", function()
        if active and targeting.activeTargetFrame then SkinBox(targeting.activeTargetFrame) end
    end)
    hooksecurefunc(targeting, "UpdateTargetFrame", function()
        if active and targeting.activeTargetFrame then SkinPlaceholders(targeting.activeTargetFrame) end
    end)
end

local function SkinRestore(frame)
    Run("WindowSkin", frame.UpdateVisuals, frame)
    for _, part in ipairs({ frame, frame.title }) do
        local border, back = part.rxpBorder, part.rxpBackground
        if border then border:SetShown(not back or back:IsShown()) end
    end
end

local function Skin()
    local frames = SkinFrames()
    if active then
        styled = true
        SkinHooks(frames)
        for _, frame in ipairs(frames) do SkinFrame(frame) end
    elseif styled then
        styled = false
        RestorePlaceholders()
        for _, frame in ipairs(frames) do SkinRestore(frame) end
    end
end

local function Draggable(frame)
    frame:RegisterForDrag(DRAG_BUTTON)
    frame:SetScript("OnDragStart", function()
        if not ns.RXPWindowOption("rxpWindowLock") then window:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        Save(window)
    end)
end

local function GoTo(index)
    Run("WindowGo", _G.RXP.SetStep, index)
end

local function SkipObjectives(rxp, step)
    for _, element in ipairs(step.elements or {}) do
        if not element.optional and not element.skip then
            element.skip = true
            if element.OnComplete then Run("WindowComplete", element.OnComplete, element) end
        end
    end
    rxp.updateSteps = true
    Run("WindowMap", rxp.UpdateMap)
end

local function SkipStep(step)
    local rxp = _G.RXP
    local progress = Run("WindowProgress", rxp.GetGuideProgress)
    if not progress then return end
    if step and step.index ~= progress then
        SkipObjectives(rxp, step)
    else
        GoTo(progress + 1)
    end
end

local function MaySkip()
    local mode = ns.RXPWindowOption("rxpWindowSkip")
    return mode == "click" or (mode == "shift" and IsShiftKeyDown())
end

local function StepClick(self, button)
    if button == "RightButton" then return Menu() end
    if MaySkip() then SkipStep(self.step) end
end

local function Tip(owner, text, menu, plain)
    if not ns.RXPWindowOption("rxpWindowTips") or GameTooltip:IsForbidden() then return end
    local mode = ns.RXPWindowOption("rxpWindowSkip")
    GameTooltip:SetOwner(owner, TIP_ANCHOR)
    local r, g, b = ns.RXPWindowColor(ACCENT)
    if plain then
        GameTooltip:SetText(text, r, g, b)
    elseif mode == "off" then
        GameTooltip:SetText(TEXT_MENU, r, g, b)
    else
        GameTooltip:SetText(text, r, g, b)
        if mode == "shift" then GameTooltip:AddLine(TEXT_SHIFT, TIP_DIM, TIP_DIM, TIP_DIM) end
        if menu then GameTooltip:AddLine(TEXT_MENU, TIP_DIM, TIP_DIM, TIP_DIM) end
    end
    GameTooltip:Show()
end

local function StepsFor(height)
    return math.floor((height - window.chrome) / window.lineHeight)
end

local function LiveSize(width, height)
    if not (sizing and sizingModel and window) then return end
    sizing.width = math.min(WIDTH_MAX, math.max(WIDTH_MIN, width))
    sizing.steps = math.max(0, math.min(STEPS_MAX, StepsFor(height)))
    Draw()
end

local function Resized()
    if not window then return end
    ns.SetRXPWindowWidth(window:GetWidth())
    ns.SetRXPWindowSteps(StepsFor(window:GetHeight()))
    Save(window)
    Draw()
end

local function MakeGrip(parent)
    local grip = CreateFrame("Button", nil, parent)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint(GRIP_CORNER, parent, GRIP_CORNER, 0, 0)
    grip:SetNormalTexture(GRIP_UP)
    grip:SetPushedTexture(GRIP_DOWN)
    grip:SetHighlightTexture(GRIP_HIGHLIGHT)
    grip:SetScript("OnMouseDown", function()
        if ns.RXPWindowOption("rxpWindowLock") then return end
        sizingModel = ns.RXPWindowRead()
        sizing = { width = window:GetWidth(), steps = ns.RXPWindowSteps() }
        window:StartSizing(GRIP_CORNER)
    end)
    grip:SetScript("OnMouseUp", function()
        sizing, sizingModel = nil, nil
        window:StopMovingOrSizing()
        Resized()
    end)
    return grip
end

local function TexturePath()
    local name = ns.RXPWindowOption("rxpWindowBarTexture")
    local custom = name ~= "" and ns.UI.TexturePath(name, GRADIENT)
    return custom or GRADIENT
end

local function MakeBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints()
    return bar
end

local function ForeverParts()
    return ns.Shared.Parts, ns.Shared.Style
end

local function ForeverLook()
    return ns.RXPWindowInForever()
end

local function PaintInset(frame, on)
    if on then
        if not frame.inset then
            frame.inset = ForeverParts().ForeverInset(frame)
            frame.inset:SetAllPoints(frame)
            frame.inset:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        end
        frame.inset:Show()
    elseif frame.inset then
        frame.inset:Hide()
    end
end

local function PaintBar(bar, fraction)
    bar:SetStatusBarTexture(TexturePath())
    local r, g, b, a = ns.RXPWindowColor("barFill")
    bar:SetStatusBarColor(r, g, b, a)
    local parts, style = ForeverParts()
    local forever = ForeverLook()
    if forever and not bar.rim then bar.rim = parts.ForeverBox(bar) end
    if bar.rim then bar.rim._frame:SetShown(forever) end
    if forever then
        local field = style.FOREVER_FIELD_RGB
        bar.track:SetColorTexture(field.r, field.g, field.b, 1)
    else
        r, g, b, a = ns.RXPWindowColor("barBack")
        bar.track:SetColorTexture(r, g, b, a)
    end
    local size = ns.RXPWindowOption("rxpWindowBarBorderSize")
    local edged = size > 0 and not forever
    if edged and not bar.edge then bar.edge = ns.Border(bar) end
    if bar.edge then bar.edge._frame:SetShown(edged) end
    local height = BAR_HEIGHT
    if edged then
        bar.edge:SetColor(ns.RXPWindowColor("barBorder"))
        bar.edge:SetPixels(size)
        height = height + EDGE_SIDES * size * ns.OnePixel(bar)
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(fraction)
    bar:SetHeight(height)
    return height
end

local function Build()
    local T = ns.THEME
    local f = CreateFrame("Frame", WINDOW_NAME, UIParent)
    f:SetFrameStrata(STRATA)
    f:SetScale(ns.RXPWindowScale() / PERCENT)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    Draggable(f)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then Menu() end
    end)
    f:SetScript("OnEvent", function() Refresh() end)
    f.back = ns.Solid(f, "BACKGROUND", T.panel, 1)
    f.back:SetAllPoints()
    f.edge = ns.Border(f, T.line)
    f.fold = CreateFrame("Button", nil, f)
    f.fold.text = Text(f.fold, "rxpWindowTitleSize", "CENTER")
    f.fold.text:SetAllPoints()
    f.fold.sign = f.fold:CreateTexture(nil, "OVERLAY")
    f.fold.sign:SetPoint("CENTER")
    f.fold:SetScript("OnClick", function()
        local on = Settings().rxpWindowCollapsed ~= true
        Settings().rxpWindowCollapsed = on or nil
        Draw()
    end)
    f.title = Text(f, "rxpWindowTitleSize")
    f.title:SetWordWrap(false)
    f.progress = Text(f, "rxpWindowTextSize", "RIGHT")
    f.rule = ns.Solid(f, "ARTWORK", T.fg, 1)
    ns.Hairline(f.rule, "h")
    f.bar = MakeBar(f)
    f.track = ns.Solid(f, "ARTWORK", T.line, 1)
    f.thumb = ns.Solid(f, "OVERLAY", T.accent, 1)
    f.wheel = CreateFrame("Frame", nil, f)
    f.wheel:SetScript("OnMouseWheel", Wheel)
    f:SetScript("OnSizeChanged", function(_, width, height) LiveSize(width, height) end)
    f.grip = MakeGrip(f)
    Place(f)
    return f
end

local function MakeBox()
    local T = ns.THEME
    local box = CreateFrame("Button", nil, window)
    box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    box:SetScript("OnClick", StepClick)
    box:SetScript("OnEnter", function(self) Tip(self, TEXT_SKIP, true) end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Draggable(box)
    box.back = ns.Solid(box, "BACKGROUND", T.bg, 1)
    box.back:SetAllPoints()
    box.edge = ns.Border(box)
    box.label = Text(box, "rxpWindowTextSize")
    box.logo = box:CreateTexture(nil, "OVERLAY")
    box.logo:SetTexture(LOGO)
    return box
end

local function LinkEnter(row, link)
    if row:IsForbidden() or GameTooltip:IsForbidden() then return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(link)
end

local function LinkLeave(row)
    if row:IsForbidden() or GameTooltip:IsForbidden() then return end
    if GameTooltip:GetOwner() == row then GameTooltip:Hide() end
end

local function MakeRow()
    local row = CreateFrame("Button", nil, window)
    row:SetHyperlinksEnabled(true)
    row:SetScript("OnHyperlinkClick", function(_, link, text, button)
        SetItemRef(link, text, button)
    end)
    row:SetScript("OnHyperlinkEnter", LinkEnter)
    row:SetScript("OnHyperlinkLeave", LinkLeave)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", StepClick)
    row:SetScript("OnEnter", function(self) Tip(self.box or self, TEXT_SKIP, true) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.bar = ns.Solid(row, "ARTWORK", ns.THEME.accent, 1)
    row.icon = Text(row, ICON_SIZE, nil, true)
    row.glyph = row:CreateTexture(nil, "OVERLAY")
    row.meter = MakeBar(row)
    row.text = Text(row, "rxpWindowTextSize", nil, true)
    row.text:SetWordWrap(true)
    Draggable(row)
    return row
end

local function MakeLine()
    local line = Text(window, "rxpWindowListSize")
    line:SetWordWrap(false)
    return line
end

local function MakeHit()
    local hit = CreateFrame("Button", nil, window)
    hit:RegisterForClicks("LeftButtonUp")
    hit.shade = hit:CreateTexture(nil, "BACKGROUND")
    hit.shade:SetAllPoints()
    hit:SetScript("OnClick", function(self)
        if self.menu then return PickGuide() end
        if MaySkip() then GoTo(self.index) end
    end)
    hit:SetScript("OnEnter", function(self)
        if not self.menu and ns.RXPWindowOption("rxpWindowSkip") == "off" then return end
        local r, g, b = ns.RXPWindowColor(ACCENT)
        self.shade:SetColorTexture(r, g, b, HOVER_ALPHA)
        self.shade:Show()
        if self.menu then
            Tip(self, TEXT_PICK, false, true)
        else
            Tip(self, TEXT_GO:format(self.index or 0))
        end
    end)
    hit:SetScript("OnLeave", function(self)
        self.shade:Hide()
        GameTooltip:Hide()
    end)
    Draggable(hit)
    return hit
end

local MAKERS = { box = MakeBox, row = MakeRow, line = MakeLine, hit = MakeHit }

local function Acquire(kind)
    used[kind] = used[kind] + 1
    local item = pool[kind][used[kind]]
    if not item then
        item = MAKERS[kind]()
        pool[kind][used[kind]] = item
    end
    item:Show()
    return item
end

local function Reset()
    for kind, list in pairs(pool) do
        for i = 1, #list do
            list[i]:Hide()
        end
        used[kind] = 0
    end
end

local function Watch(source)
    if not source or watched[source] then return end
    watched[source] = true
    hooksecurefunc(source, "SetText", Refresh)
end

local function Spacing()
    return ns.RXPWindowOption("rxpWindowSpacing")
end

local function DrawIcon(item, row, size)
    local path, r, g, b = ns.RXPIconLook(row.icon)
    if not path then
        item.glyph:Hide()
        item.icon:SetText(row.icon)
        return
    end
    item.icon:SetText("")
    item.glyph:ClearAllPoints()
    item.glyph:SetPoint("TOPLEFT", item.icon, "TOPLEFT", 0, 0)
    item.glyph:SetSize(size, size)
    item.glyph:SetTexture(path)
    item.glyph:SetVertexColor(r, g, b)
    item.glyph:SetAlpha(row.done and ICON_DONE_ALPHA or 1)
    item.glyph:Show()
end

local function DrawMeter(item, row, x, y, width)
    local counted = math.min(1, math.max(0, (row.have or 0) / row.need))
    local fraction = row.bags and row.done and 1 or counted
    item.meter:ClearAllPoints()
    item.meter:SetPoint("TOPLEFT", item, "TOPLEFT", x, -y)
    item.meter:SetWidth(width)
    local barHeight = PaintBar(item.meter, fraction)
    item.meter:Show()
    if row.bags then wantsBags = true end
    return barHeight
end

local function DrawRow(box, row, x, y, width, first)
    local item = Acquire("row")
    item:SetParent(box)
    item.box = box
    item.step = row.step
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
    item:SetWidth(width)
    local gap = Spacing()
    local iconSize = ICON_SIZE
    local textSize = ns.RXPWindowOption("rxpWindowTextSize")
    if first then
        textSize = textSize + FIRST_GROW
        iconSize = iconSize + FIRST_GROW * FIRST_ICON_GROW
    end
    local iconW = iconSize + ICON_GAP
    local drop = math.max(0, math.floor((iconSize - textSize) / 2))
    local textWidth = width - BAR_W - gap - iconW
    item.bar:ClearAllPoints()
    item.bar:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.bar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.bar:SetWidth(BAR_W)
    item.bar:SetShown(not first and not row.nested and not row.note)
    item.bar:SetColorTexture(ns.RXPWindowColor(row.done and "muted" or ACCENT))
    item.icon:ClearAllPoints()
    item.icon:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + gap, 0)
    Faced(item.icon, iconSize)
    DrawIcon(item, row, iconSize)
    item.text:ClearAllPoints()
    item.text:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + gap + iconW, -drop)
    item.text:SetWidth(textWidth)
    Coloured(item.text, row.done and "muted" or "text")
    Faced(item.text, textSize)
    item.text:SetText(row.text)
    local height = math.max(drop + math.max(item.text:GetStringHeight(), textSize), iconSize)
    if row.need and row.need >= COUNT_MIN then
        height = height + COUNT_GAP + DrawMeter(item, row, BAR_W + gap + iconW, height + COUNT_GAP, textWidth)
    else
        item.meter:Hide()
    end
    item:SetHeight(height)
    Watch(row.source)
    return height
end

local function DrawBox(step, y, inner, current)
    local box = Acquire("box")
    box.step = step.source
    local gap = Spacing()
    local size = ns.RXPWindowOption("rxpWindowTextSize")
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
    box:SetWidth(inner)
    local boxR, boxG, boxB = ns.RXPWindowColor("box")
    local opacity = ns.RXPWindowOption("rxpWindowBoxOpacity") / PERCENT
    local bordered = ns.RXPWindowOption("rxpWindowBoxBorder")
    local inset = bordered and ForeverLook()
    PaintInset(box, inset)
    if inset then box.inset.fill:SetColorTexture(boxR, boxG, boxB, opacity) end
    box.back:SetColorTexture(boxR, boxG, boxB, opacity)
    box.back:SetShown(not inset)
    local r, g, b, a = ns.RXPWindowColor("boxBorder")
    box.edge:SetColor(r, g, b, a)
    box.edge:SetPixels(ns.RXPWindowOption("rxpWindowBoxBorderSize"))
    box.edge._frame:SetShown(bordered and not inset)
    box.label:ClearAllPoints()
    box.label:SetPoint("TOPLEFT", box, "TOPLEFT", BOX_PAD, -BOX_PAD)
    Coloured(box.label, ACCENT)
    box.label:SetText(step.label:upper())
    local head = size
    if current then
        box.logo:ClearAllPoints()
        box.logo:SetPoint("TOPRIGHT", box, "TOPRIGHT", -BOX_PAD, -BOX_PAD)
        box.logo:SetSize(LOGO_SIZE, LOGO_SIZE)
        box.logo:Show()
        head = math.max(size, LOGO_SIZE)
    else
        box.logo:Hide()
    end
    local by = -BOX_PAD - head - gap
    local column = ICON_SIZE + ICON_GAP
    for i, row in ipairs(step.rows) do
        local set = i > 1 and INDENT or 0
        if i > 1 and row.nested then set = set + column end
        by = by - DrawRow(box, row, BOX_PAD + set, by, inner - BOX_PAD * 2 - set, i == 1) - gap
    end
    box:SetHeight(-by + BOX_PAD - gap)
    return y + by - BOX_PAD
end

local function DrawFold(folded, headH)
    local fold = window.fold
    fold:SetSize(FOLD_W, headH)
    fold:ClearAllPoints()
    fold:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -PAD)
    fold.text:SetText(folded and TEXT_UNFOLD or TEXT_FOLD)
    local parts, style = ForeverParts()
    local name = ForeverLook() and (folded and style.FOREVER_PLUS_ATLAS or style.FOREVER_MINUS_ATLAS)
    local sign = name and parts.ForeverAtlas(fold.sign, name, true) or false
    fold.sign:SetShown(sign)
    fold.text:SetShown(not sign)
    Coloured(fold.text, "line")
end

local function DrawHeader(model, folded, width, headH)
    DrawFold(folded, headH)
    window.title:ClearAllPoints()
    window.title:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + FOLD_W + Spacing(), -PAD)
    window.title:SetWidth(width - PAD * 2 - FOLD_W - Spacing() - PROGRESS_W)
    Coloured(window.title, "title")
    window.title:SetText(model.heading)
    window.progress:ClearAllPoints()
    window.progress:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -PAD)
    if model.step then
        window.progress:SetText(ns.RXPWindowTint(ACCENT, ("%d/%d"):format(model.step, model.total)) .. TEXT_DOT
            .. ns.RXPWindowTint("title", ("%d%%"):format(model.percent)))
    else
        window.progress:SetText("")
    end
    window.progress:SetTextColor(1, 1, 1, 1)
end

local function DrawLine(model, y)
    local line = ns.RXPWindowOption("rxpWindowLine")
    local gap = Spacing()
    window.rule:Hide()
    window.bar:Hide()
    if line == "bar" then
        window.bar:ClearAllPoints()
        window.bar:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
        window.bar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, y)
        local barHeight = PaintBar(window.bar, model.fraction or 0)
        window.bar:Show()
        return y - barHeight - gap
    elseif line == "rule" then
        window.rule:ClearAllPoints()
        window.rule:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
        window.rule:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, y)
        window.rule:SetColorTexture(ns.RXPWindowColor("line"))
        window.rule:Show()
        return y - gap
    end
    return y
end

local function DrawPanel()
    local panelOn, borderOn = ns.RXPWindowOption("rxpWindowPanel"), ns.RXPWindowOption("rxpWindowBorder")
    local inset = borderOn and ForeverLook()
    PaintInset(window, inset)
    if inset then
        local r, g, b, a = ns.RXPWindowColor("panel")
        window.inset.fill:SetColorTexture(r, g, b, panelOn and a or 0)
    end
    window.back:SetColorTexture(ns.RXPWindowColor("panel"))
    window.back:SetShown(panelOn and not inset)
    window.edge:SetColor(ns.RXPWindowColor("border"))
    window.edge._frame:SetShown(borderOn and not inset)
end

local function ListLine(y, inner, listH, text, index, menu, look, barred)
    local item = Acquire("line")
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
    item:SetWidth(barred and inner - SCROLL_ROOM or inner)
    Coloured(item, look == "current" and ACCENT or "muted")
    item:SetAlpha(look == "done" and DONE_ALPHA or 1)
    item:SetText(text)
    local hit = Acquire("hit")
    hit:ClearAllPoints()
    hit:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
    hit:SetSize(inner, listH)
    hit.index, hit.menu = index, menu
    hit.shade:Hide()
    return y - listH
end

local function DrawScrollBar(from, height, top, count, total)
    local grip = math.max(SCROLL_MIN, height * count / total)
    local share = math.min(1, (top - 1) / (total - count))
    window.track:ClearAllPoints()
    window.track:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, from)
    window.track:SetSize(SCROLL_W, height)
    window.track:SetColorTexture(ns.RXPWindowColor("line"))
    window.thumb:ClearAllPoints()
    window.thumb:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, from - share * (height - grip))
    window.thumb:SetSize(SCROLL_W, grip)
    window.thumb:SetColorTexture(ns.RXPWindowColor(ACCENT))
end

local function DrawSteps(model, y, inner, listH)
    local list = model.list
    local count = sizing and sizing.steps or ns.RXPWindowSteps()
    local top = math.max(1, math.min(model.first + scroll, math.max(model.first, #list - count + 1)))
    scroll = top - model.first
    local scrollable = count > 0 and #list > count
    local barred = scrollable and ns.RXPWindowOption("rxpWindowScrollBar")
    local from = y
    for i = top, math.min(#list, top + count - 1) do
        local entry = list[i]
        local look = model.current[entry.index] and "current" or entry.done and "done" or nil
        y = ListLine(y, inner, listH, ("%d  %s"):format(entry.index, ns.RXPWindowLineText(entry)), entry.index, false,
            look, barred)
    end
    window.track:SetShown(barred)
    window.thumb:SetShown(barred)
    window.wheel:ClearAllPoints()
    window.wheel:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, from)
    window.wheel:SetSize(inner, math.max(count, 1) * listH)
    window.wheel:EnableMouseWheel(scrollable)
    window.wheel:SetShown(scrollable)
    if barred then DrawScrollBar(from, from - y, top, count, #list) end
    return y
end

local function DrawList(model, y, inner, listH)
    if model.empty then y = ListLine(y, inner, listH, TEXT_PICK, nil, true) end
    for i, step in ipairs(model.steps) do y = DrawBox(step, y, inner, i == 1) end
    return DrawSteps(model, y, inner, listH)
end

local function DrawChrome(y, listH, folded)
    if not sizing then window:SetHeight(-y + PAD) end
    if wantsBags then window:RegisterEvent(BAG_EVENT) else window:UnregisterEvent(BAG_EVENT) end
    window.lineHeight = listH
    window.chrome = -y + PAD - used.line * listH
    local locked = ns.RXPWindowOption("rxpWindowLock")
    window:SetResizable(not locked and not folded)
    window:SetResizeBounds(WIDTH_MIN, window.chrome, WIDTH_MAX, window.chrome + STEPS_MAX * listH)
    window.grip:SetShown(not folded and not locked)
end

function Draw()
    if not active then return end
    wantsBags = false
    if not sizing then Skin() end
    window = window or Build()
    local model = sizing and sizingModel or ns.RXPWindowRead() or ns.RXPWindowNoGuide()
    if not sizing and retake then retake = not Take() end
    if not sizing and (model.guide ~= anchorGuide or model.after ~= anchorAfter) then
        anchorGuide, anchorAfter, scroll = model.guide, model.after, 0
    end
    Reset()
    Refaced()
    local width = sizing and sizing.width or ns.RXPWindowWidth()
    local folded = Settings().rxpWindowCollapsed == true
    local headH = ns.RXPWindowOption("rxpWindowTitleSize") + HEAD_PAD
    local listH = ns.RXPWindowOption("rxpWindowListSize") + LIST_PAD
    if not sizing then window:SetWidth(width) end
    DrawPanel()
    DrawHeader(model, folded, width, headH)
    local y = DrawLine(model, -PAD - headH)
    window.track:Hide()
    window.thumb:Hide()
    window.wheel:Hide()
    if not folded then y = DrawList(model, y, width - PAD * 2, listH) end
    DrawChrome(y, listH, folded)
    window:Show()
end

local function Apply()
    local want = ns.RXPWindowEnabled() and ns.RXPThemesAvailable() and ns.RXPWindowReady()
    if want == active then
        if active then Refresh() end
        return
    end
    active = want
    if want then
        RefreshAccepts()
        Draw()
    else
        Release()
        if window then
            window:Hide()
            window:UnregisterEvent(BAG_EVENT)
        end
        Skin()
    end
end

local function Hook(owner, name)
    if Has(owner, name) then hooksecurefunc(owner, name, Rebuilt) end
end

function ns.RXPWindowReady()
    local v2 = Dig(_G.RXP, "v2")
    return Has(v2, "IsGuideWindowEnabled") and v2:IsGuideWindowEnabled() and true or false
end

function ns.RXPWindowStart()
    if not started then
        started = true
        local rxp = _G.RXP
        if Has(rxp, "SetStep") then hooksecurefunc(rxp, "SetStep", StepChanged) end
        local v2 = Dig(rxp, "v2")
        Hook(v2, "UpdateGuideWindow")
        Hook(v2, "UpdateActiveStepsFrame")
        Hook(v2, "UpdatePlayerActiveStepItem")
    end
    Apply()
end

function ns.SetRXPWindow(on)
    Settings().rxpWindow = on and true or nil
    if on then
        ns.RXPArrowKept()
        Settings().rxpThemes = nil
    end
    ns.RXPWindowStart()
end

function ns.SetRXPWindowScale(scale)
    local was = window and window:GetScale() or ns.RXPWindowScale() / PERCENT
    ns.RXPWindowStoreScale(scale)
    local now = ns.RXPWindowScale() / PERCENT
    local saved = Settings().rxpWindowPos
    if window then
        local point, _, relativePoint, x, y = window:GetPoint(1)
        window:SetScale(now)
        if point then
            window:ClearAllPoints()
            window:SetPoint(point, UIParent, relativePoint, x * was / now, y * was / now)
            Save(window)
        end
    elseif saved then
        saved[3], saved[4] = saved[3] * was / now, saved[4] * was / now
    end
end
