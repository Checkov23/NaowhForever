-- Widgets.lua: the widget kit behind every options row (ns.UI).
local ns = _G.NaowhForever
local T = ns.THEME

local MEDIA = ns.MEDIA
local CHEVRON = MEDIA .. "chevron.tga"
local COGS_ICON = MEDIA .. "cog.tga"
local TRACK_TEX = MEDIA .. "toggle_track.tga"
local KNOB_TEX = MEDIA .. "toggle_knob.tga"
local CHECK_TEX = MEDIA .. "check.tga"
local SPEAKER_TEX = MEDIA .. "speaker.tga"
local VOICE_PATH = MEDIA .. "Voice\\"
local BLACK = { r = 0, g = 0, b = 0 }
local CURSOR_TIP = { anchor = "cursor", justify = "LEFT" }
local CONTENT_PAD = 20
local ROUND = 0.5
local CHEVRON_DOWN = -math.pi / 2
local PICK_TOLERANCE = 1 / 255
local DROPDOWN_W, DROPDOWN_H, DROPDOWN_TEXT_SIZE = 160, 24, 12
local DROPDOWN_TEXT_X, DROPDOWN_ARROW_ROOM, DROPDOWN_ARROW, DROPDOWN_ARROW_X = 8, 18, 10, 7
local MENU_HEIGHT, MENU_DROP = 420, 2
local SLIDER_TEXT_SIZE, SLIDER_BOX_INSET, SLIDER_MIN_FILL = 12, 4, 0.001
local SLIDER_PRECISION = "%.4f"
local ROW_H, HEADER_H = 50, 40
local ROW_INSET, LABEL_GAP, LABEL_SIZE = 20, 8, 14
local CONTROL_RAISE = 2
local BUTTONS_W, BUTTONS_H, BUTTONS_GAP = 84, 24, 6
local ICON_BUTTON, DEFAULT_ICON = 32, 134400
local ROW_BUTTON_W, ROW_BUTTON_H = 90, 24
local PLAY_SIZE, PLAY_GAP, PLAY_ICON = 24, 4, 14
local SLIDER_TRACK_W, SLIDER_TRACK_H, SLIDER_THUMB = 120, 4, 12
local SLIDER_BOX_W, SLIDER_BOX_H, SLIDER_MAX = 40, 22, 100
local PALETTE_SIZE, PALETTE_GAP, PALETTE_EDGE_ALPHA = 22, 4, 0.6
local DIM_ALPHA = 0.3
local HIT_PAD = 4
local RULE_ALPHA = 0.6
local FALLBACK_ROW_W = 910
local DIVIDER_INSET = 8
local HEADER_TEXT_Y = 8
local WIDE_BUTTON_W, WIDE_BUTTON_H = 200, 26
local KEY_FIELD_W, KEY_FIELD_H, COMBAT_DIM = 150, 26, 0.4
local SWATCH_W, SWATCH_H = 40, 20
local SCROLL_STEP = 60
local GLIDE_RATE = 14
local GLIDE_DONE = 0.5
local TIP = { w = 240, pad = 8, size = 10, spacing = 3, gap = 4, cursorX = 16, cursorY = -12, alpha = 0.98 }
local TOGGLE = { w = 40, h = 20, knobShare = 0.8, insetShare = 0.1, minInset = 2, markShare = 0.4, hit = 4 }
local FOLD = { arrow = 14, inset = 22, switchGap = 12, barTextX = 12 }
local NOTE = { size = 12, inset = 20, top = 12, room = 24, fallbackW = 960 }
local SCROLL = { slimW = 6, slimGap = 6, trackAlpha = 0.6, thumbAlpha = 0.8, minThumb = 24, sync = 0.5 }
local SHARE_DEPTH = 4
local NO_SOUND = "none"
local SHARED_MEDIA_PREFIX = "sm:"
local SHARED_MEDIA_NONE = "None"
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
local RACIAL_VOICES = {
    ["voice:stoneform-ready"] = "stoneform-ready.ogg",
    ["voice:stoneform-preview"] = "stoneform-preview.ogg",
    ["voice:shadowmeld-ready"] = "shadowmeld-ready.ogg",
    ["voice:shadowmeld-preview"] = "shadowmeld-preview.ogg",
}
local TEXT_EDIT = ns.L("Edit")
local TEXT_PLAY, TEXT_PLAY_HELP = ns.L("Play it"), ns.L("Plays the sound picked here.")
local TEXT_PRESS_KEY, TEXT_NOT_BOUND = ns.L("Press a key..."), ns.L("|cff808080Not bound|r")
local TEXT_REBOUND = ns.L("%s is now bound to %s instead of %s.")
local TEXT_KEY_BINDING = ns.L("Key Binding")
local TEXT_KEY_HELP = ns.L("Click, then press a key to bind it. Escape cancels; right-click clears. "
    .. "The same binding as in Key Bindings > Naowh Forever.")
local TEXT_RELOAD = ns.L("Reload UI")
local TEXT_ADDON_FONT = ns.L("Addon Font")
local TEXT_UNAVAILABLE = ns.L(" (unavailable)")
local TEXT_NONE = ns.L("None")
local TEXT_VOICE = ns.L("Voice: %s (English)")

local UI = {}
ns.UI = UI

UI.CHEVRON = CHEVRON
UI.CONTENT_PAD = CONTENT_PAD
UI.COGS_ICON = COGS_ICON

function UI.L(text) return ns.L(text) end

local card

local function Card()
    if card then return card end
    card = CreateFrame("Frame", nil, UIParent)
    card:SetFrameStrata("TOOLTIP")
    card:SetClampedToScreen(true)
    if ns.foreverSkin then
        ns.Shared.Parts.ForeverTip(card)
    else
        ns.Solid(card, "BACKGROUND", T.panel, TIP.alpha):SetAllPoints()
        ns.Border(card, BLACK)
    end
    card.text = ns.Font(card, TIP.size, nil, card.arrow and ns.Shared.Style.FOREVER_VALUE_RGB)
    card.text:SetPoint("TOPLEFT", TIP.pad, -TIP.pad)
    card.text:SetSpacing(TIP.spacing)
    card:Hide()
    return card
end

local function Usable(v) return not (issecretvalue and issecretvalue(v)) end

local function PlaceCard(t, owner, opts)
    t:ClearAllPoints()
    local cursor = opts and opts.anchor == "cursor"
    if t.arrow then t.arrow:SetShown(not cursor) end
    if cursor then
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        t:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + TIP.cursorX, y / scale + TIP.cursorY)
    else
        t:SetPoint("BOTTOM", owner, "TOP", 0, TIP.gap + (t.arrow and t.arrow:GetHeight() or 0))
    end
end

function UI.ShowWidgetTooltip(owner, text, opts)
    if type(text) == "function" then text = text() end
    text = ns.L(text)
    if not text or text == "" then return end
    local t = Card()
    local fs = t.text
    fs:SetJustifyH(opts and opts.justify or "CENTER")
    fs:SetWidth(TIP.w - 2 * TIP.pad)
    fs:SetText(text)
    PlaceCard(t, owner, opts)
    t:Show()
    local w, h = fs:GetStringWidth(), fs:GetStringHeight()
    if Usable(w) and w < TIP.w - 2 * TIP.pad then fs:SetWidth(math.ceil(w)) end
    if not Usable(h) then h = TIP.size end
    t:SetSize(fs:GetWidth() + 2 * TIP.pad, h + 2 * TIP.pad)
end

function UI.HideWidgetTooltip()
    if card then card:Hide() end
end

local function Smooth(tex)
    tex:SetTexelSnappingBias(0)
    tex:SetSnapToPixelGrid(false)
end

local function Truthy(v) return v and true or false end

local function ForeverCheck(t)
    local tick, border, rest = ns.Shared.Parts.ForeverCheck(t)
    local function Paint(state) tick:SetShown(Truthy(state)) end
    if border then
        t:SetScript("OnEnter", function() border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1) end)
        t:SetScript("OnLeave", function() border:SetColor(rest.r, rest.g, rest.b, 1) end)
    end
    local function Snap() Paint(t._get()) end
    t:SetScript("OnClick", function()
        t._set(not Truthy(t._get()))
        Snap()
    end)
    Snap()
    t._refreshValue = Snap
    return t, Paint, Snap
end

function UI.BuildToggleControl(parent, frameLevel, get, set, w, h, knobSize, onColor)
    local W, H = w or TOGGLE.w, h or TOGGLE.h
    local KNOB = knobSize or math.floor(H * TOGGLE.knobShare + ROUND)
    local INSET = math.max(TOGGLE.minInset, math.floor(H * TOGGLE.insetShare + ROUND))
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(W, H)
    if frameLevel then t:SetFrameLevel(frameLevel) end
    t._get, t._set = get, set
    if ns.foreverSkin then return ForeverCheck(t) end
    t:SetHitRectInsets(-TOGGLE.hit, -TOGGLE.hit, -TOGGLE.hit, -TOGGLE.hit)

    local track = t:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(TRACK_TEX)
    track:SetAllPoints()
    Smooth(track)

    local knob = t:CreateTexture(nil, "ARTWORK")
    knob:SetTexture(KNOB_TEX)
    knob:SetSize(KNOB, KNOB)
    Smooth(knob)

    local mark = t:CreateTexture(nil, "ARTWORK")
    mark:SetTexture(CHECK_TEX)
    mark:SetSize(H * TOGGLE.markShare, H * TOGGLE.markShare)
    mark:SetPoint("CENTER", t, "LEFT", H / 2, 0)
    Smooth(mark)
    local minus = ns.Solid(t, "ARTWORK", T.muted, 1)
    minus:SetSize(H * TOGGLE.markShare, 1)
    minus:SetPoint("CENTER", t, "RIGHT", -H / 2, 0)
    ns.Hairline(minus, "h")

    local on = false
    local function PaintTrack(c, a)
        track:SetVertexColor(c.r, c.g, c.b, a)
    end

    local function Paint(state)
        on = Truthy(state)
        mark:SetShown(on)
        minus:SetShown(not on)
        knob:ClearAllPoints()
        if on then
            PaintTrack(onColor or T.accent, 1)
            knob:SetVertexColor(1, 1, 1, 1)
            knob:SetPoint("RIGHT", t, "RIGHT", -INSET, 0)
        else
            PaintTrack(T.line, 1)
            knob:SetVertexColor(T.fg.r, T.fg.g, T.fg.b, 1)
            knob:SetPoint("LEFT", t, "LEFT", INSET, 0)
        end
    end

    t:SetScript("OnEnter", function()
        PaintTrack(on and (onColor or T.accentSoft) or T.grey, 1)
    end)
    t:SetScript("OnLeave", function()
        PaintTrack(on and (onColor or T.accent) or T.line, 1)
    end)

    local function Snap() Paint(Truthy(t._get())) end
    t:SetScript("OnClick", function()
        t._set(not Truthy(t._get()))
        Snap()
    end)
    Snap()
    t._refreshValue = Snap
    return t, Paint, Snap
end

local function ByText(a, b) return tostring(a) < tostring(b) end

local function DropdownKeys(btn)
    if btn._order then return btn._order end
    local out = {}
    for k in pairs(btn._values) do out[#out + 1] = k end
    table.sort(out, ByText)
    return out
end

local function DropdownHandlesMouse(_, buttonName, event)
    return event == "GLOBAL_MOUSE_DOWN" and buttonName == "LeftButton"
end

local function MenuApi()
    return MenuUtil and MenuUtil.CreateRootMenuDescription and MenuVariants
        and Menu and Menu.GetManager and AnchorUtil
end

local function OpenDropdownMenu(btn)
    if not MenuApi() then return end
    local desc = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultMenuMixin())
    if not desc then return end
    local menuHeight = btn._menuHeight
    if type(menuHeight) == "function" then menuHeight = menuHeight() end
    if desc.SetScrollMode then desc:SetScrollMode(menuHeight or MENU_HEIGHT) end
    if btn._menuFill then
        btn._menuFill(desc)
    else
        for _, k in ipairs(DropdownKeys(btn)) do
            local key = k
            desc:CreateRadio(ns.L(btn._values[key] or tostring(key)),
                function() return btn._get() == key end,
                function()
                    btn._set(key)
                    btn._refreshLabel()
                end)
        end
    end
    btn._menu = Menu.GetManager():OpenMenu(btn, desc,
        AnchorUtil.CreateAnchor("TOPLEFT", btn, "BOTTOMLEFT", 0, -MENU_DROP))
end

local function CloseDropdownMenu(btn)
    btn._menu:Close()
    btn._menu = nil
end

local function OnDropdownMouseDown(btn)
    if btn._menu and btn._menu.IsShown and btn._menu:IsShown() then
        return CloseDropdownMenu(btn)
    end
    OpenDropdownMenu(btn)
end

local function OnDropdownHide(btn)
    if btn._menu then CloseDropdownMenu(btn) end
end

local function DropdownArrow(btn)
    local arrow = btn:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture(CHEVRON)
    arrow:SetSize(DROPDOWN_ARROW, DROPDOWN_ARROW)
    if arrow.SetRotation then arrow:SetRotation(CHEVRON_DOWN) end
    arrow:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
    arrow:SetPoint("RIGHT", -DROPDOWN_ARROW_X, 0)
    return arrow
end

function UI.BuildDropdownControl(parent, ddW, fLevel, values, order, get, set)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(ddW or DROPDOWN_W, DROPDOWN_H)
    if fLevel then btn:SetFrameLevel(fLevel) end
    local bg = ns.Solid(btn, "BACKGROUND", T.panel, 1)
    bg:SetAllPoints()
    local border = ns.Border(btn, BLACK)
    local lbl = ns.Font(btn, DROPDOWN_TEXT_SIZE, nil)
    lbl:SetPoint("LEFT", DROPDOWN_TEXT_X, 0)
    lbl:SetPoint("RIGHT", -DROPDOWN_ARROW_ROOM, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetWordWrap(false)
    local arrow = DropdownArrow(btn)
    if ns.foreverSkin then ns.Shared.Parts.ForeverDropdown(btn, bg, lbl, arrow) end
    btn._values, btn._order, btn._get, btn._set = values, order, get, set
    btn._refreshLabel = function()
        local v = btn._get()
        lbl:SetText(ns.L(btn._values[v] or tostring(v or "")))
    end
    btn.HandlesGlobalMouseEvent = DropdownHandlesMouse
    btn:SetScript("OnMouseDown", OnDropdownMouseDown)
    if not ns.foreverSkin then
        btn:SetScript("OnEnter", function()
            border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
        end)
        btn:SetScript("OnLeave", function()
            border:SetColor(BLACK.r, BLACK.g, BLACK.b, 1)
        end)
    end
    btn._refreshLabel()
    btn._refreshValue = btn._refreshLabel
    btn:SetScript("OnHide", OnDropdownHide)
    return btn, lbl
end

local function SliderClamp(track, v)
    v = tonumber(v)
    if not v then return nil end
    local lo, hi, st = track._minV, track._maxV, track._step
    v = math.floor((v - lo) / st + ROUND) * st + lo
    v = tonumber((SLIDER_PRECISION):format(v))
    if v < lo then v = lo elseif v > hi then v = hi end
    return v
end

local function SliderValueBox(parent, inputW, inputH, inputFontSz, inputAlpha)
    local valBox = CreateFrame("EditBox", nil, parent)
    valBox:SetSize(inputW, inputH)
    valBox:SetAutoFocus(false)
    valBox:SetFont(ns.DataFontPath(), inputFontSz or SLIDER_TEXT_SIZE, "")
    valBox:SetTextColor(T.fg.r, T.fg.g, T.fg.b, 1)
    valBox:SetTextInsets(SLIDER_BOX_INSET, SLIDER_BOX_INSET, 0, 0)
    valBox:SetJustifyH("CENTER")
    valBox:SetAlpha(inputAlpha or 1)
    local boxBg = ns.Solid(valBox, "BACKGROUND", T.bg, 1)
    boxBg:SetAllPoints()
    local boxBorder = ns.Border(valBox, BLACK)
    if not ns.foreverSkin then
        valBox:SetScript("OnEnter", function() boxBorder:SetColor(T.accent.r, T.accent.g, T.accent.b, 1) end)
        valBox:SetScript("OnLeave", function() boxBorder:SetColor(BLACK.r, BLACK.g, BLACK.b, 1) end)
    end
    return valBox, boxBg, boxBorder
end

function UI.BuildSliderCore(parent, trackW, trackH, thumbSz, inputW, inputH, inputFontSz,
                            inputAlpha, minV, maxV, step, get, set)
    local track = CreateFrame("Frame", nil, parent)
    track._minV, track._maxV, track._step = minV, maxV, step or 1
    local function Clamp(v) return SliderClamp(track, v) end

    track:SetSize(trackW, math.max(trackH, thumbSz))
    track:EnableMouse(true)
    track._get, track._set = get, set
    local rail = ns.Solid(track, "BACKGROUND", T.line, 1)
    rail:SetPoint("LEFT", 0, 0)
    rail:SetPoint("RIGHT", 0, 0)
    rail:SetHeight(trackH)
    local fill = ns.Solid(track, "BORDER", T.accent, 1)
    fill:SetPoint("LEFT", 0, 0)
    fill:SetHeight(trackH)
    local thumb = track:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(KNOB_TEX)
    thumb:SetVertexColor(T.fg.r, T.fg.g, T.fg.b, 1)
    thumb:SetSize(thumbSz, thumbSz)

    local valBox, boxBg, boxBorder = SliderValueBox(parent, inputW, inputH, inputFontSz, inputAlpha)
    if ns.foreverSkin then ns.Shared.Parts.ForeverSlider(track, rail, fill, thumb, valBox, thumbSz) end

    local function Paint()
        local lo, hi = track._minV, track._maxV
        local v = Clamp(track._get()) or lo
        local frac = (hi > lo) and (v - lo) / (hi - lo) or 0
        fill:SetWidth(math.max(SLIDER_MIN_FILL, frac * trackW))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", track, "LEFT", frac * trackW, 0)
        valBox:SetText(track._format and track._format(v) or tostring(v))
        valBox:SetCursorPosition(0)
    end

    local function FromCursor()
        local scale = track:GetEffectiveScale()
        local cx = GetCursorPosition() / scale
        local left = track:GetLeft()
        if not left then return end
        local frac = (cx - left) / trackW
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        local v = Clamp(track._minV + frac * (track._maxV - track._minV))
        if v ~= nil and v ~= track._get() then
            track._set(v)
        end
        Paint()
    end

    local function EndDrag()
        track:SetScript("OnUpdate", nil)
        if UI.sliderDrag == track then UI.sliderDrag = nil end
    end
    local function OnDragUpdate()
        if not IsMouseButtonDown("LeftButton") then
            EndDrag()
            Paint()
            return
        end
        FromCursor()
    end
    track:SetScript("OnMouseDown", function()
        UI.sliderDrag = track
        FromCursor()
        track:SetScript("OnUpdate", OnDragUpdate)
    end)
    track:SetScript("OnMouseUp", function()
        EndDrag()
        Paint()
    end)
    track:SetScript("OnHide", EndDrag)

    local function Commit()
        if UI.rebindingRows then return end
        local v = Clamp((valBox:GetText():gsub("[^%d%.%-]", "")))
        if v ~= nil then track._set(v) end
        Paint()
        valBox:ClearFocus()
    end
    valBox:SetScript("OnEnterPressed", Commit)
    valBox:SetScript("OnEditFocusLost", function() Commit() end)
    valBox:SetScript("OnEscapePressed", function()
        Paint()
        valBox:ClearFocus()
    end)

    Paint()
    track._refreshValue = Paint
    track._valBox = valBox
    track.rail, track.fill, track.thumb = rail, fill, thumb
    track.valueBox, track.valueFill, track.valueBorder = valBox, boxBg, boxBorder
    return track, valBox, Paint
end

function UI.SetSliderRange(track, minV, maxV, step)
    track._minV, track._maxV, track._step = minV, maxV, step or 1
end

local W = {}
UI.Widgets = W

local function Collapsed(parent, frame, h)
    if parent._nsuiCollapsed then
        frame:Hide()
        return frame, 0
    end
    return frame, h
end

function UI.BeginReusableRows(parent)
    parent._rowCache = parent._rowCache or {}
    parent._rowUses = {}
    UI.rebindingRows = true
    for _, rows in pairs(parent._rowCache) do
        for _, row in ipairs(rows) do row:Hide() end
    end
    UI.rebindingRows = nil
end

local function NextUse(parent, key)
    local index = (parent._rowUses[key] or 0) + 1
    parent._rowUses[key] = index
    local list = parent._rowCache[key]
    if not list then list = {}; parent._rowCache[key] = list end
    return list, index
end

local function CachedRow(parent, key)
    if not parent._rowCache then return nil end
    local rows, index = NextUse(parent, key)
    local row = rows[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        rows[index] = row
    end
    row:ClearAllPoints()
    row:Show()
    return row
end

function UI.Keep(parent, key, create)
    if not parent._rowCache then return create(parent), true end
    local list, index = NextUse(parent, key)
    local el, new = list[index], false
    if not el then
        el, new = create(parent), true
        list[index] = el
    end
    el:ClearAllPoints()
    el:Show()
    if el.CreateTexture then UI.BeginReusableRows(el) end
    return el, new
end

function UI.KeepFont(parent, key, size, flags, color)
    local fs = UI.Keep(parent, key, function(p) return ns.Font(p, size, flags, color) end)
    local c = color or T.fg
    fs:SetTextColor(c.r, c.g, c.b, 1)
    return fs
end

function UI.KeepToggle(parent, key, get, set, w, h, knobSize)
    local t = UI.Keep(parent, key, function(p)
        return UI.BuildToggleControl(p, nil, get, set, w, h, knobSize)
    end)
    t._get, t._set = get, set
    t:SetFrameLevel(parent:GetFrameLevel() + CONTROL_RAISE)
    t._refreshValue()
    return t
end

function UI.KeepDropdown(parent, key, width, values, order, get, set)
    local dd = UI.Keep(parent, key, function(p)
        return UI.BuildDropdownControl(p, width, nil, values, order, get, set)
    end)
    dd._values, dd._order, dd._get, dd._set = values, order, get, set
    dd:SetFrameLevel(parent:GetFrameLevel() + CONTROL_RAISE)
    dd._refreshLabel()
    return dd
end

function UI.KeepButton(parent, key, text, w, h, onClick)
    local btn = UI.Keep(parent, key, function(p) return ns.Button(p, text, w, h) end)
    btn:SetSize(w, h)
    ns.SetButtonText(btn, text)
    btn._onClick = onClick
    return btn
end

local CONFIG_LISTS = { "values", "order" }

local function UpdateConfig(dst, src)
    if dst == src then return end
    local values, order = dst.values, dst.order
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(src) do dst[k] = v end
    for _, key in ipairs(CONFIG_LISTS) do
        local prior = key == "values" and values or order
        if type(prior) == "table" and type(src[key]) == "table" then
            if prior ~= src[key] then
                for k in pairs(prior) do prior[k] = nil end
                for k, v in pairs(src[key]) do prior[k] = v end
            end
            dst[key] = prior
        end
    end
end

local function AtRowEnd(control, rgn)
    control:SetPoint("RIGHT", rgn, "RIGHT", -ROW_INSET, 0)
    return control
end

local function IconButtonControl(rgn, cfg)
    local button = CreateFrame("Button", nil, rgn)
    button:SetSize(ICON_BUTTON, ICON_BUTTON)
    AtRowEnd(button, rgn)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    ns.Border(button, BLACK)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            if cfg.onRightClick then cfg.onRightClick() end
        else
            cfg.onClick()
        end
    end)
    button:SetScript("OnDragStart", function() cfg.onClick() end)
    button:SetScript("OnEnter", function(self)
        if cfg.tooltip then UI.ShowWidgetTooltip(self, cfg.tooltip, CURSOR_TIP) end
    end)
    button:SetScript("OnLeave", function() UI.HideWidgetTooltip() end)
    button._refreshValue = function()
        icon:SetTexture(cfg.icon or DEFAULT_ICON)
        icon:SetDesaturated(cfg.active ~= nil and not cfg.active())
    end
    button._refreshValue()
    return button
end

local function Dropped(cfg)
    return cfg.onDrop and GetCursorInfo() and cfg.onDrop()
end

local function ButtonControl(rgn, cfg)
    local button = ns.Button(rgn, cfg.buttonText or TEXT_EDIT, ROW_BUTTON_W, ROW_BUTTON_H, function()
        if not Dropped(cfg) then cfg.onClick() end
    end)
    return AtRowEnd(button, rgn)
end

local function ButtonsControl(rgn, cfg)
    local holder = CreateFrame("Frame", nil, rgn)
    holder:SetHeight(BUTTONS_H)
    AtRowEnd(holder, rgn)
    holder._buttons = {}
    local x = 0
    for i = #cfg.buttons, 1, -1 do
        local w = cfg.buttons[i].width or BUTTONS_W
        local button = ns.Button(holder, "", w, BUTTONS_H, function() cfg.buttons[i].onClick() end)
        button:SetPoint("RIGHT", holder, "RIGHT", -x, 0)
        holder._buttons[i] = button
        x = x + w + BUTTONS_GAP
    end
    holder:SetWidth(math.max(1, x - BUTTONS_GAP))
    holder._refreshValue = function()
        for i, button in ipairs(holder._buttons) do
            local b = cfg.buttons[i]
            ns.SetButtonText(button, b.text)
            if b.tooltip then ns.Tooltip(button, b.text, b.tooltip) end
        end
    end
    holder._refreshValue()
    return holder
end

local function ToggleControl(rgn, _, Get, Set)
    return AtRowEnd(UI.BuildToggleControl(rgn, rgn:GetFrameLevel() + CONTROL_RAISE, Get, Set), rgn)
end

local function PlayButton(dd, cfg, Get)
    local play = CreateFrame("Button", nil, dd)
    play:SetSize(PLAY_SIZE, PLAY_SIZE)
    play:SetPoint("RIGHT", dd, "LEFT", -PLAY_GAP, 0)
    ns.Solid(play, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(play, BLACK)
    play.icon = play:CreateTexture(nil, "ARTWORK")
    play.icon:SetTexture(SPEAKER_TEX)
    play.icon:SetSize(PLAY_ICON, PLAY_ICON)
    play.icon:SetPoint("CENTER")
    play.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    play:SetScript("OnClick", function() cfg.preview(Get()) end)
    ns.Tooltip(play, TEXT_PLAY, TEXT_PLAY_HELP)
    play:HookScript("OnEnter", function(self) self.icon:SetVertexColor(T.fg.r, T.fg.g, T.fg.b) end)
    play:HookScript("OnLeave", function(self) self.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b) end)
    return play
end

local function PaletteChip(chips, i)
    local chip = CreateFrame("Frame", nil, chips)
    chip:SetSize(PALETTE_SIZE, PALETTE_SIZE)
    chip:SetPoint("LEFT", chips, "LEFT", (i - 1) * (PALETTE_SIZE + PALETTE_GAP), 0)
    chip.fill = ns.Solid(chip, "BACKGROUND", T.bg, 1)
    chip.fill:SetAllPoints()
    ns.Border(chip, T.muted, PALETTE_EDGE_ALPHA)
    return chip
end

local function PaletteControl(rgn, cfg, beside)
    local chips = CreateFrame("Frame", nil, rgn)
    chips:SetHeight(PALETTE_SIZE)
    if beside then chips:SetPoint("RIGHT", beside, "LEFT", -LABEL_GAP, 0) else AtRowEnd(chips, rgn) end
    local made = {}
    local function Paint()
        local colors = cfg.colors()
        local n = #colors
        chips:SetWidth(math.max(1, n * (PALETTE_SIZE + PALETTE_GAP) - PALETTE_GAP))
        for i = 1, n do
            made[i] = made[i] or PaletteChip(chips, i)
            local c = colors[i]
            made[i].fill:SetColorTexture(c.r, c.g, c.b, 1)
            made[i]:Show()
        end
        for i = n + 1, #made do made[i]:Hide() end
    end
    chips._refreshValue = Paint
    Paint()
    return chips
end

local function DropdownControl(rgn, cfg, Get, Set)
    local dd = UI.BuildDropdownControl(rgn, cfg.width or DROPDOWN_W, rgn:GetFrameLevel() + CONTROL_RAISE,
        cfg.values, cfg.order, Get, Set)
    AtRowEnd(dd, rgn)
    if cfg.preview then dd._buttons = { PlayButton(dd, cfg, Get) } end
    if cfg.palette then
        local chips = PaletteControl(rgn, { colors = cfg.palette }, dd)
        local refreshLabel = dd._refreshValue
        dd._labelEdge = chips
        dd._refreshValue = function() refreshLabel(); chips._refreshValue() end
    end
    return dd
end

local function SliderControl(rgn, cfg, Get, Set)
    local track, valBox = UI.BuildSliderCore(rgn, cfg.trackWidth or SLIDER_TRACK_W, SLIDER_TRACK_H, SLIDER_THUMB,
        cfg.boxWidth or SLIDER_BOX_W, SLIDER_BOX_H, SLIDER_TEXT_SIZE, 1, cfg.min or 0, cfg.max or SLIDER_MAX,
        cfg.step or 1, Get, Set)
    track._format = function(v) return cfg.format and cfg.format(v) or tostring(v) end
    track._refreshValue()
    AtRowEnd(valBox, rgn)
    track:SetPoint("RIGHT", valBox, "LEFT", -LABEL_GAP, 0)
    return track
end

local function ColorPickerControl(rgn, cfg, Get, Set)
    return AtRowEnd(UI.BuildColorSwatchControl(rgn, Get, Set, cfg.hasAlpha), rgn)
end

local CONTROLS = {
    iconbutton = IconButtonControl,
    button = ButtonControl,
    buttons = ButtonsControl,
    toggle = ToggleControl,
    dropdown = DropdownControl,
    slider = SliderControl,
    palette = PaletteControl,
    colorpicker = ColorPickerControl,
}

local function BuildRegionControl(rgn, cfg)
    local build = CONTROLS[cfg.type]
    if not build then return nil end
    local function Get() return cfg.getValue() end
    local function Set(...) return cfg.setValue(...) end
    return build(rgn, cfg, Get, Set)
end

local function Dim(cfg, lbl, control, off)
    local alpha = off and DIM_ALPHA or 1
    lbl:SetAlpha(alpha)
    if not control then return end
    control:SetAlpha(alpha)
    if cfg.type ~= "palette" and cfg.type ~= "buttons" then control:EnableMouse(not off) end
    local box = control._valBox
    if box then
        box:SetAlpha(alpha)
        box:EnableMouse(not off)
        if off then box:ClearFocus() end
    end
    if control._buttons then
        for _, button in ipairs(control._buttons) do button:EnableMouse(not off) end
    end
    if off and control._menu then
        control._menu:Close()
        control._menu = nil
    end
end

local function Disabled(cfg)
    return type(cfg.disabled) == "function" and cfg.disabled()
end

local function RegionLabel(rgn, control, cfg)
    local lbl = ns.Font(rgn, LABEL_SIZE, nil)
    lbl:SetPoint("LEFT", rgn, "LEFT", ROW_INSET, 0)
    if control then
        lbl:SetPoint("RIGHT", control._labelEdge or control, "LEFT", -LABEL_GAP, 0)
    else
        lbl:SetPoint("RIGHT", rgn, "RIGHT", -ROW_INSET, 0)
    end
    lbl:SetJustifyH("LEFT")
    lbl:SetWordWrap(false)
    lbl:SetText(ns.L(cfg.text) or "")
    return lbl
end

local function RegionTooltip(rgn, lbl, cfg)
    local hit = CreateFrame("Button", nil, rgn)
    hit:SetPoint("TOPLEFT", lbl, "TOPLEFT", -HIT_PAD, HIT_PAD)
    hit:SetPoint("BOTTOMRIGHT", lbl, "BOTTOMRIGHT", HIT_PAD, -HIT_PAD)
    hit:SetScript("OnEnter", function(self)
        UI.ShowWidgetTooltip(self, Disabled(cfg) and cfg.disabledTooltip or cfg.tooltip, CURSOR_TIP)
    end)
    hit:SetScript("OnLeave", function() UI.HideWidgetTooltip() end)
end

local function DropTarget(rgn, control, cfg)
    local function Drop() Dropped(cfg) end
    rgn:EnableMouse(true)
    rgn:SetScript("OnReceiveDrag", Drop)
    rgn:SetScript("OnMouseUp", Drop)
    if control then control:SetScript("OnReceiveDrag", Drop) end
end

local function BuildRegion(row, cfg, left, width)
    local rgn = CreateFrame("Frame", nil, row)
    rgn:SetPoint("TOPLEFT", row, "TOPLEFT", left, 0)
    rgn:SetSize(width, ROW_H)

    local control = BuildRegionControl(rgn, cfg)
    rgn._control = control
    local disabled = Disabled(cfg)

    local lbl = RegionLabel(rgn, control, cfg)
    rgn._label = lbl
    Dim(cfg, lbl, control, disabled)

    rgn._cfg = cfg
    rgn._refresh = function(newCfg)
        UpdateConfig(cfg, newCfg)
        lbl:SetText(ns.L(cfg.text) or "")
        Dim(cfg, lbl, control, Disabled(cfg))
        if control and control._refreshValue then control._refreshValue() end
    end

    local tip = disabled and cfg.disabledTooltip or cfg.tooltip
    if tip then RegionTooltip(rgn, lbl, cfg) end
    if cfg.onDrop then DropTarget(rgn, control, cfg) end
    return rgn
end

local function RegionKey(cfg)
    local key = cfg.type .. ":" .. (cfg.text or "")
    if cfg.type == "slider" then
        key = key .. ":" .. tostring(cfg.min) .. ":" .. tostring(cfg.max) .. ":" .. tostring(cfg.trackWidth)
        if cfg.boxWidth then key = key .. ":" .. cfg.boxWidth end
    elseif cfg.type == "buttons" then
        key = key .. ":" .. #cfg.buttons
    elseif cfg.preview then
        key = key .. ":preview"
    end
    if cfg.onDrop then key = key .. ":drop" end
    return key
end

local function PlaceRow(row, parent, yOffset, h)
    row:SetHeight(h)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_PAD, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -CONTENT_PAD, yOffset)
end

local function ContentWidth(parent, fallback)
    local w = (parent:GetWidth() or 0) - CONTENT_PAD * 2
    if w <= 0 then w = fallback end
    return w
end

local function NewRowRegions(row, parent, leftCfg, rightCfg)
    local w = row:GetWidth()
    if w <= 0 then w = ContentWidth(parent, FALLBACK_ROW_W) end
    if not rightCfg then
        row._leftRegion = BuildRegion(row, leftCfg, 0, w)
        return
    end
    local half = w / 2
    row._leftRegion = BuildRegion(row, leftCfg, 0, half)
    row._rightRegion = BuildRegion(row, rightCfg, half, half)
    local divider = ns.Solid(row, "ARTWORK", T.line, RULE_ALPHA)
    divider:SetPoint("TOP", row, "TOP", 0, -DIVIDER_INSET)
    divider:SetPoint("BOTTOM", row, "BOTTOM", 0, DIVIDER_INSET)
    ns.Hairline(divider, "v")
    divider:SetShown(ns.foreverSkin == true)
end

local function FitRegions(row, parent, rightCfg)
    local width = math.max(1, parent:GetWidth() - CONTENT_PAD * 2)
    local half = rightCfg and width / 2 or width
    row._leftRegion:SetWidth(half)
    if row._rightRegion then
        row._rightRegion:SetWidth(half)
        row._rightRegion:SetPoint("TOPLEFT", row, "TOPLEFT", half, 0)
    end
end

function W:DualRow(parent, yOffset, leftCfg, rightCfg)
    local key = "row:" .. RegionKey(leftCfg) .. ":" .. (rightCfg and RegionKey(rightCfg) or "")
    local row = CachedRow(parent, key) or CreateFrame("Frame", nil, parent)
    PlaceRow(row, parent, yOffset, ROW_H)

    if not row._rule then
        row._rule = ns.Solid(row, "ARTWORK", T.line, RULE_ALPHA)
        row._rule:SetPoint("BOTTOMLEFT"); row._rule:SetPoint("BOTTOMRIGHT"); ns.Hairline(row._rule, "h")
    end
    row._rule:SetShown(ns.foreverSkin == true)
    if row._leftRegion then
        row._leftRegion._refresh(leftCfg)
        if rightCfg then row._rightRegion._refresh(rightCfg) end
        FitRegions(row, parent, rightCfg)
        return Collapsed(parent, row, ROW_H)
    end
    NewRowRegions(row, parent, leftCfg, rightCfg)
    return Collapsed(parent, row, ROW_H)
end

local function ForeverHeader(f, text, fold)
    local Parts = ns.Shared.Parts
    if not fold then
        local heading = Parts.ForeverHeading(f, LABEL_SIZE, CONTENT_PAD)
        heading:SetAllPoints()
        heading.text:SetText(ns.L(text))
        return
    end
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("LEFT"); bar:SetPoint("RIGHT")
    bar:SetHeight(ns.Shared.Style.FOREVER_CARD_BAR_H)
    Parts.ForeverBar(bar)
    bar.sign:SetPoint("CENTER", bar, "RIGHT", -ns.Shared.Style.FOREVER_SIGN_RIGHT, 0)
    bar.name = ns.Font(bar, LABEL_SIZE, nil, T.accent, true)
    bar.name:SetPoint("LEFT", FOLD.barTextX, 0)
    bar.name:SetText(ns.L(text))
    f.bar = bar
end

function W:SectionHeader(parent, text, yOffset, inset, fold)
    parent._nsuiCollapsed = nil
    local f = CachedRow(parent, "header:" .. text) or CreateFrame("Frame", nil, parent)
    PlaceRow(f, parent, yOffset, HEADER_H)
    if f._headerBuilt then return f, HEADER_H end
    f._headerBuilt = true
    local lbl = ns.Font(f, LABEL_SIZE, nil, T.fg, true)
    inset = inset or 0
    lbl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, HEADER_TEXT_Y)
    lbl:SetText(ns.L(text))
    f._label = lbl
    local sep = ns.Solid(f, "ARTWORK", T.line, 1)
    sep:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    sep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    ns.Hairline(sep, "h")
    sep:Hide()
    if ns.foreverSkin then
        ForeverHeader(f, text, fold)
        lbl:Hide()
        sep:Hide()
    end
    return f, HEADER_H
end

local openFolds = {}

local function OnFoldClick(hit)
    openFolds[hit._id] = not openFolds[hit._id] or nil
    UI:RefreshPage(true)
end

function W:FoldHeader(parent, text, yOffset, forceOpen)
    local f, h = W:SectionHeader(parent, text, yOffset, FOLD.inset, true)
    if not f.hit then
        f.arrow = f:CreateTexture(nil, "ARTWORK")
        f.arrow:SetTexture(CHEVRON)
        f.arrow:SetSize(FOLD.arrow, FOLD.arrow)
        f.arrow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, HEADER_TEXT_Y)
        f.arrow:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
        f.hit = CreateFrame("Button", nil, f)
        f.hit:SetAllPoints()
        f.hit:SetScript("OnClick", OnFoldClick)
        f.hit:SetScript("OnEnter", function() f.arrow:SetVertexColor(T.fg.r, T.fg.g, T.fg.b, 1) end)
        f.hit:SetScript("OnLeave", function() f.arrow:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1) end)
    end
    f.hit._id = text
    local open = forceOpen or openFolds[text]
    f.arrow:SetRotation(open and CHEVRON_DOWN or 0)
    f._open = open
    if f.bar then
        f.arrow:Hide()
        ns.Shared.Parts.PaintForeverBar(f.bar, open, true)
    end
    parent._nsuiCollapsed = not open or nil
    return f, h
end

function W:SwitchFold(parent, text, yOffset, cfg)
    local f, h = W:FoldHeader(parent, text, yOffset, cfg.open)
    f._get, f._set = cfg.get, cfg.set
    if not f.switch then
        f.switch = UI.BuildToggleControl(f, f.hit:GetFrameLevel() + CONTROL_RAISE, function() return f._get() end,
            function(v)
                if v then openFolds[text] = true end
                f._set(v)
            end)
        if f.bar then
            f.switch:SetPoint("LEFT", f.bar, "LEFT", FOLD.barTextX, 0)
            f.bar.name:ClearAllPoints()
            f.bar.name:SetPoint("LEFT", f.switch, "RIGHT", FOLD.switchGap, 0)
        else
            f.switch:SetPoint("LEFT", f._label, "RIGHT", FOLD.switchGap, 0)
        end
    end
    f.switch._refreshValue()
    if cfg.tooltip then ns.Tooltip(f.switch, ns.L(text), ns.L(cfg.tooltip)) end
    f.arrow:SetShown(cfg.rows == true and not f.bar)
    f.hit:SetShown(cfg.rows == true)
    if f.bar then ns.Shared.Parts.PaintForeverBar(f.bar, f._open, cfg.rows == true) end
    if not cfg.rows then parent._nsuiCollapsed = nil end
    return f, h
end

function W:GroupHeader(parent, text, yOffset)
    local shut = parent._nsuiCollapsed
    local f, h = W:SectionHeader(parent, text, yOffset)
    parent._nsuiCollapsed = shut
    if shut then
        f:Hide()
        return f, 0
    end
    return f, h
end

function W:EndFold(parent)
    parent._nsuiCollapsed = nil
end

function W:Button(parent, text, yOffset, onClick)
    local row = CachedRow(parent, "button:" .. text) or CreateFrame("Frame", nil, parent)
    PlaceRow(row, parent, yOffset, ROW_H)
    row._onClick = onClick
    if not row._btn then
        row._btn = ns.Button(row, text, WIDE_BUTTON_W, WIDE_BUTTON_H, function() row._onClick() end)
        row._btn:SetPoint("LEFT", row, "LEFT", ROW_INSET, 0)
    end
    return Collapsed(parent, row, ROW_H)
end

local function KeyCombo(key)
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

local function SaveKeyBindings()
    SaveBindings(GetCurrentBindingSet())
end

local function ClearBinding(action)
    if InCombatLockdown() then return end
    for _, key in ipairs({ GetBindingKey(action) }) do SetBinding(key) end
end

local function Resolve(value)
    if type(value) == "function" then return value() end
    return value
end

local function Bind(combo, action, label)
    if InCombatLockdown() then return end
    local previous = GetBindingAction(combo)
    ClearBinding(action)
    SetBinding(combo, action)
    SaveKeyBindings()
    if previous ~= "" and previous ~= action then
        ns.Print(TEXT_REBOUND:format(GetBindingText(combo), label, GetBindingName(previous)))
    end
end

function UI.KeyField(rgn, action, label, tooltip)
    if rgn._keyField then return rgn._keyField end
    local btn = ns.Button(rgn, "", KEY_FIELD_W, KEY_FIELD_H)
    rgn._keyField = btn
    btn:SetPoint("RIGHT", rgn, "RIGHT", -ROW_INSET, 0)
    if rgn._label then rgn._label:SetPoint("RIGHT", btn, "LEFT", -LABEL_GAP, 0) end
    btn:RegisterForClicks("AnyUp")
    local capturing
    local function Show()
        local key = GetBindingKey(Resolve(action))
        btn.label:SetText(capturing and ns.L(TEXT_PRESS_KEY) or key and GetBindingText(key) or ns.L(TEXT_NOT_BOUND))
        btn:SetAlpha(InCombatLockdown() and COMBAT_DIM or 1)
    end
    local function Stop()
        capturing = false
        btn:EnableKeyboard(false)
        Show()
    end
    btn:SetScript("OnClick", function(_, button)
        if InCombatLockdown() then return end
        if MOUSE_KEYS[button] then
            if capturing then
                Bind(KeyCombo(MOUSE_KEYS[button]), Resolve(action), Resolve(label))
                Stop()
            end
            return
        end
        if button == "RightButton" then
            ClearBinding(Resolve(action))
            SaveKeyBindings()
            Stop()
            return
        end
        capturing = true
        btn:EnableKeyboard(true)
        btn:SetPropagateKeyboardInput(false)
        Show()
    end)
    btn:SetScript("OnKeyDown", function(_, key)
        if MODIFIER_KEYS[key] then return end
        if key ~= "ESCAPE" and not InCombatLockdown() then Bind(KeyCombo(key), Resolve(action), Resolve(label)) end
        Stop()
    end)
    btn:EnableKeyboard(false)
    btn:SetScript("OnShow", Show)
    btn:SetScript("OnHide", function() if capturing then Stop() end end)
    ns.Tooltip(btn, type(label) == "string" and label or TEXT_KEY_BINDING, tooltip or TEXT_KEY_HELP)
    btn._refreshValue = function()
        if capturing then Stop() else Show() end
    end
    Show()
    return btn
end

function W:ReloadButton(parent, yOffset)
    local row, h = self:Button(parent, TEXT_RELOAD, yOffset)
    if row and row._btn then ns.MakeReloadButton(row._btn) end
    return row, h
end

local function Near(a, b) return math.abs(a - b) <= PICK_TOLERANCE end

local function OpenColorPicker(swatchBtn, PaintSwatch)
    local read, write, withAlpha = swatchBtn._get, swatchBtn._set, swatchBtn._hasAlpha
    local r, g, b, a = read()
    r, g, b, a = r or 1, g or 1, b or 1, a or 1
    local changed = false
    local function Apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = withAlpha and ColorPickerFrame:GetColorAlpha() or 1
        if not changed and Near(nr, r) and Near(ng, g) and Near(nb, b) and Near(na, a) then return end
        changed = true
        write(nr, ng, nb, na)
        PaintSwatch()
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b,
        opacity = a,
        hasOpacity = withAlpha and true or false,
        swatchFunc = Apply,
        opacityFunc = Apply,
        cancelFunc = function()
            if not changed then return end
            write(r, g, b, a)
            PaintSwatch()
        end,
    })
end

function UI.BuildColorSwatchControl(parent, get, set, hasAlpha)
    local swatchBtn = CreateFrame("Button", nil, parent)
    swatchBtn:SetSize(SWATCH_W, SWATCH_H)
    ns.Border(swatchBtn, BLACK)
    local swatch = ns.Solid(swatchBtn, "BACKGROUND", T.fg, 1)
    swatch:SetAllPoints()
    if ns.foreverSkin then ns.Shared.Parts.ForeverSwatch(swatchBtn) end
    swatchBtn._get, swatchBtn._set, swatchBtn._hasAlpha = get, set, hasAlpha
    local function PaintSwatch()
        local r, g, b = swatchBtn._get()
        swatch:SetColorTexture(r or 1, g or 1, b or 1, 1)
    end
    PaintSwatch()
    swatchBtn._refreshValue = PaintSwatch
    swatchBtn:SetScript("OnClick", function() OpenColorPicker(swatchBtn, PaintSwatch) end)
    return swatchBtn
end

function W:Note(parent, text, yOffset)
    local row = CachedRow(parent, "note")
    if row then
        row:SetPoint("TOPLEFT")
        row:SetSize(1, 1)
    end
    local fs = row and row._fs
    if not fs then
        fs = ns.Font(row or parent, NOTE.size, nil, T.muted)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        if row then row._fs = fs end
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_PAD + NOTE.inset, yOffset - NOTE.top)
    local w = parent:GetWidth() or 0
    if w <= 0 then w = NOTE.fallbackW end
    fs:SetWidth(w - (CONTENT_PAD + NOTE.inset) * 2)
    fs:SetText(ns.L(text))
    fs:Show()
    local h = math.ceil(fs:GetStringHeight()) + NOTE.room
    return Collapsed(parent, fs, h)
end

local function OnPixel(scroll, value, target)
    local px = ns.OnePixel(scroll)
    local snapped = target > value and math.ceil(value / px) * px or math.floor(value / px) * px
    if target > value then return math.min(snapped, target) end
    return math.max(snapped, target)
end

local function StopGlide(scroll)
    scroll._gliding = nil
    scroll:SetScript("OnUpdate", nil)
end

local function Glide(self, elapsed)
    local at = self:GetVerticalScroll()
    if math.abs(at - self._glideAt) > GLIDE_DONE then return StopGlide(self) end
    local target = math.max(0, math.min(self:GetVerticalScrollRange(), self._glideTo))
    local nextAt
    if math.abs(target - at) <= GLIDE_DONE then
        nextAt = target
        StopGlide(self)
    else
        nextAt = OnPixel(self, at + (target - at) * (1 - math.exp(-GLIDE_RATE * elapsed)), target)
    end
    self._glideAt = nextAt
    self:SetVerticalScroll(nextAt)
end

function UI.SmoothWheel(scroll, step)
    step = step or SCROLL_STEP
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        if range <= 0 then return end
        local at = self:GetVerticalScroll()
        local continuing = self._gliding and math.abs(at - self._glideAt) <= GLIDE_DONE
        local from = continuing and self._glideTo or at
        local px = ns.OnePixel(self)
        local target = math.max(0, math.min(range, from - delta * step))
        self._glideTo = math.min(range, math.floor(target / px + ROUND) * px)
        self._glideAt = at
        if not self._gliding then
            self._gliding = true
            self:SetScript("OnUpdate", Glide)
        end
    end)
end

local function StopDrag(self) self:SetScript("OnUpdate", nil) end

local function ScrollBar(parent, scroll, width, gap)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(width)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", gap, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", gap, 0)
    bar:SetObeyStepOnDrag(false)
    local track = ns.Solid(bar, "BACKGROUND", T.line, SCROLL.trackAlpha)
    track:SetAllPoints()
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(T.muted.r, T.muted.g, T.muted.b, SCROLL.thumbAlpha)
    thumb:SetWidth(width)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:Hide()
    bar:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)
    return bar, thumb
end

local function ScrollGrip(bar, thumb, scroll)
    bar:EnableMouse(false)
    local grip = CreateFrame("Frame", nil, bar)
    grip:SetAllPoints()
    grip:EnableMouse(true)
    local lit = ns.foreverSkin and ns.Shared.Style.FOREVER_RAIL_RGB[1] or T.accent
    grip:SetScript("OnEnter", function() thumb:SetColorTexture(lit.r, lit.g, lit.b, 1) end)
    grip:SetScript("OnLeave", function()
        thumb:SetColorTexture(T.muted.r, T.muted.g, T.muted.b, SCROLL.thumbAlpha)
    end)
    local grabY, grabValue
    local function CursorY()
        local _, y = GetCursorPosition()
        return y / bar:GetEffectiveScale()
    end
    local function Drag(self)
        if not IsMouseButtonDown("LeftButton") then return self:SetScript("OnUpdate", nil) end
        local _, range = bar:GetMinMaxValues()
        local travel = bar:GetHeight() - thumb:GetHeight()
        if travel <= 0 then return end
        bar:SetValue(math.max(0, math.min(range, grabValue + (grabY - CursorY()) / travel * range)))
    end
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        StopGlide(scroll)
        grabY, grabValue = CursorY(), bar:GetValue()
        local _, middle = thumb:GetCenter()
        if math.abs(grabY - middle) > thumb:GetHeight() / 2 then grabY = middle end
        self:SetScript("OnUpdate", Drag)
        Drag(self)
    end)
    grip:SetScript("OnMouseUp", StopDrag)
    grip:SetScript("OnHide", StopDrag)
    return grip
end

function UI.SlimScroll(parent, width, gap)
    width, gap = width or SCROLL.slimW, gap or SCROLL.slimGap
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local bar, thumb = ScrollBar(parent, scroll, width, gap)
    if ns.foreverSkin then ns.Shared.Parts.ForeverScrollArrows(bar, scroll, gap) end
    local grip = ScrollGrip(bar, thumb, scroll)
    local function Sync(self, _, range)
        range = range or self:GetVerticalScrollRange()
        local shown = self:GetHeight()
        local _, old = bar:GetMinMaxValues()
        bar:SetMinMaxValues(0, range)
        bar:SetShown(range > 0)
        if range > 0 then
            thumb:SetHeight(math.max(SCROLL.minThumb, bar:GetHeight() * shown / (shown + range)))
        end
        local value = bar:GetValue()
        if old == 0 and range > 0 then
            -- A slider hides its thumb at an empty range and only places it again when its value moves.
            bar:SetValue(range)
            bar:SetValue(value)
        elseif value > range then
            bar:SetValue(range)
        end
    end
    local function Refresh()
        scroll:UpdateScrollChildRect()
        Sync(scroll)
    end
    scroll:SetScript("OnScrollRangeChanged", Sync)
    scroll:HookScript("OnShow", Refresh)
    local setChild = scroll.SetScrollChild
    function scroll:SetScrollChild(child)
        setChild(self, child)
        child:HookScript("OnSizeChanged", Refresh)
    end
    scroll:HookScript("OnHide", function() bar:Hide() end)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        if math.abs(bar:GetValue() - offset) > SCROLL.sync then bar:SetValue(offset) end
    end)
    UI.SmoothWheel(scroll)
    grip:EnableMouseWheel(true)
    grip:SetScript("OnMouseWheel", function(_, delta) scroll:GetScript("OnMouseWheel")(scroll, delta) end)
    scroll.bar = bar
    return scroll
end

local function SharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function UI.KeepMissing(values, order, selected)
    if type(selected) == "string" and selected ~= "" and not values[selected] then
        values[selected] = selected .. TEXT_UNAVAILABLE
        order[#order + 1] = selected
    end
    return values, order
end

function UI.FontChoices(selected, label)
    local values, order = { [""] = label or TEXT_ADDON_FONT }, { "" }
    local LSM = SharedMedia()
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            values[name] = name
            order[#order + 1] = name
        end
    end
    return UI.KeepMissing(values, order, selected)
end

function UI.FontPath(name)
    local LSM = SharedMedia()
    local path = LSM and name and name ~= "" and LSM:Fetch("font", name, true)
    return path and ns.LocaleFont(name, path) or ns.HeadingFontPath()
end

local function Squashed(name)
    return (name:gsub("%s", ""):lower())
end

function UI.TextureChoices(selected, label)
    local values, order = { [""] = label }, { "" }
    local seen = { [Squashed(label)] = true }
    local LSM = SharedMedia()
    if LSM then
        for _, name in ipairs(LSM:List("statusbar")) do
            local same = Squashed(name)
            if name == selected or not seen[same] then
                seen[same] = true
                values[name] = name
                order[#order + 1] = name
            end
        end
    end
    return UI.KeepMissing(values, order, selected)
end

function UI.TexturePath(name, fallback)
    local LSM = SharedMedia()
    local path = LSM and name and name ~= "" and LSM:Fetch("statusbar", name, true)
    return path or fallback
end

local moduleDefaults = {}

local function Plain(v, depth)
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return true end
    if t ~= "table" or depth > SHARE_DEPTH then return false end
    for k, val in pairs(v) do
        local kt = type(k)
        if (kt ~= "string" and kt ~= "number") or not Plain(val, depth + 1) then return false end
    end
    return true
end

local function CopyPlain(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = CopyPlain(val) end
    return out
end

local function SavedDefaults()
    local account = ns.AccountSettings()
    if type(account.moduleDefaults) ~= "table" then account.moduleDefaults = {} end
    return account.moduleDefaults
end

function ns.SaveModuleDefaults()
    local saved = SavedDefaults()
    for key, defaults in pairs(moduleDefaults) do
        local copy = {}
        for k, v in pairs(defaults) do
            if type(k) == "string" and Plain(v, 1) then copy[k] = CopyPlain(v) end
        end
        saved[key] = copy
    end
end

function ns.ModuleDefaults(key)
    return moduleDefaults[key] or SavedDefaults()[key]
end

local function RegisterDefaults(key, defaults)
    local known = moduleDefaults[key]
    if not known then
        moduleDefaults[key] = defaults
        return
    end
    for k, v in pairs(defaults) do
        if known[k] == nil then known[k] = v end
    end
end

local function DependsOn(S, on)
    if type(on) == "table" then
        return function()
            for i = 1, #on do
                if not S.Get(on[i]) then return true end
            end
            return false
        end
    end
    return function() return not S.Get(on) end
end

function UI.ModuleSettings(key, defaults)
    local S = { key = key }
    local listeners = {}
    RegisterDefaults(key, defaults)
    function S.DB()
        local root = ns.SettingsRoot()
        if type(root[key]) ~= "table" then root[key] = {} end
        return root[key]
    end
    function S.Get(k)
        local v = S.DB()[k]
        if v == nil then return defaults[k] end
        return v
    end
    function S.Raw(k) return S.DB()[k] end
    function S.Default(k) return defaults[k] end
    function S.Set(k, v)
        S.DB()[k] = v
        for i = 1, #listeners do listeners[i](k, v) end
    end
    function S.OnChange(fn) listeners[#listeners + 1] = fn end

    local function Row(cfg, k, on)
        cfg.getValue = function() return S.Get(k) end
        cfg.setValue = cfg.setValue or function(v) S.Set(k, v) end
        if on then cfg.disabled = DependsOn(S, on) end
        return cfg
    end
    function S.Toggle(k, text, tooltip, on)
        return Row({ type = "toggle", text = text, tooltip = tooltip,
            setValue = function(v) S.Set(k, v); UI:RefreshPage(true) end }, k, on)
    end
    function S.Slider(k, text, min, max, step, tooltip, on)
        return Row({ type = "slider", text = text, tooltip = tooltip,
            min = min, max = max, step = step }, k, on)
    end
    return S
end

ns.UnlockModeSettings = UI.ModuleSettings("unlockMode", { guides = true, hidden = {}, locked = {},
    elementsPanel = true, anchoredTo = {} })

local bundledVoices = {
    { key = "voice:dispel-me", text = ns.L("Dispel me"), file = "dispel-me.ogg" },
    { key = "voice:move-out", text = ns.L("Move out"), file = "move-out.ogg" },
    { key = "voice:use-a-defensive", text = ns.L("Use a defensive"), file = "use-a-defensive.ogg" },
    { key = "voice:combat", text = "Combat", file = "combat.ogg" },
    { key = "voice:safe", text = ns.L("Safe"), file = "safe.ogg" },
}

function UI.BuildAlertSoundTables()
    local paths, names, order = {}, { [NO_SOUND] = TEXT_NONE }, { NO_SOUND }
    for _, voice in ipairs(bundledVoices) do
        paths[voice.key] = VOICE_PATH .. voice.file
        names[voice.key] = TEXT_VOICE:format(voice.text)
        order[#order + 1] = voice.key
    end
    return paths, names, order
end

local function ByLower(a, b) return a:lower() < b:lower() end

function UI.AppendSharedMediaSounds(paths, names, order)
    local LSM = SharedMedia()
    if not LSM then return end
    local list = LSM:HashTable("sound")
    if not list then return end
    local sorted = {}
    for name in pairs(list) do sorted[#sorted + 1] = name end
    table.sort(sorted, ByLower)
    for _, name in ipairs(sorted) do
        local key = SHARED_MEDIA_PREFIX .. name
        if name == SHARED_MEDIA_NONE then
            names[key] = names[key] or TEXT_NONE
        elseif not names[key] then
            paths[key] = list[name]
            names[key] = name
            order[#order + 1] = key
        end
    end
end

function UI.PlaySoundKey(key)
    UI._PlayLSMSound(UI.SoundPathFor(key))
end

function UI._PlayLSMSound(v)
    if v == nil or v == 1 then return end
    if type(v) == "string" then
        PlaySoundFile(v, "Master")
    elseif type(v) == "number" then
        PlaySound(v, "Master")
    end
end

local soundPaths
local soundProvider
local function SoundRegistered(_, mediatype)
    if mediatype == "sound" then
        soundPaths = nil
    end
end

local function BundledVoicePath(key)
    local racial = RACIAL_VOICES[key]
    if racial then return VOICE_PATH .. racial end
    for _, voice in ipairs(bundledVoices) do
        if key == voice.key then return VOICE_PATH .. voice.file end
    end
end

local function WatchProvider(provider)
    if provider == soundProvider then return end
    if soundProvider then
        soundProvider.UnregisterCallback(UI, "LibSharedMedia_Registered")
    end
    provider.RegisterCallback(UI, "LibSharedMedia_Registered", SoundRegistered)
    soundProvider = provider
    soundPaths = nil
end

function UI.SoundPathFor(key)
    if not key or key == NO_SOUND then return nil end
    local bundled = BundledVoicePath(key)
    if bundled then return bundled end
    local provider = SharedMedia()
    if not provider then return nil end
    WatchProvider(provider)
    if not soundPaths then
        local paths, names, order = UI.BuildAlertSoundTables()
        UI.AppendSharedMediaSounds(paths, names, order)
        soundPaths = paths
    end
    return soundPaths[key]
end

function ns.SoundChoices()
    local paths, names, order = UI.BuildAlertSoundTables()
    UI.AppendSharedMediaSounds(paths, names, order)
    names[NO_SOUND] = nil
    for i = #order, 1, -1 do
        if order[i] == NO_SOUND then table.remove(order, i) end
    end
    return paths, names, order
end
