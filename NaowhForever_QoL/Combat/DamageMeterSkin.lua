-- DamageMeterSkin.lua: Damage Meter Skin, the game's damage meter in the theme's colors, texture and font.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Settings = ns.Shared.Settings
local Parts = ns.Shared.Parts

local ADDON = "Blizzard_DamageMeter"
local PRIMARY_WINDOW = "DamageMeterSessionWindow1"
local OTHER_METERS = { { addon = "Details", name = "Details" },
    { addon = "EllesmereUIDamageMeters", name = "EllesmereUI Damage Meters" }, { addon = "Skada", name = "Skada" },
    { addon = "Recount", name = "Recount" }, { addon = "TinyDPS", name = "TinyDPS" } }
local TEXT_OTHERS = ns.L("Turn off every other damage meter first.")
local TEXT_OTHERS_NAMED = ns.L("Turn off %s first.")
local CARD_ORDER = 110
local GRADIENT_TEX = ns.MEDIA .. "NaowhGradient.tga"
local TEXT_GRADIENT, TEXT_NEEDS_NOT_FREE = "Naowh Gradient", ns.L("Turn off Move and Resize")
local TEXT_NO_WINDOW = ns.L("The game's meter has no window to place.")
local TEXT_NO_PLACE = ns.L("Show the game's meter first, then switch this off and on.")
local BAR_CLASS, BAR_ACCENT, BAR_CUSTOM = "class", "accent", "custom"
local BARS = { { class = "Class Colors", accent = "Theme Accent", custom = "Custom Color" },
    { BAR_CLASS, BAR_ACCENT, BAR_CUSTOM } }
local OUTLINE_GAME, OUTLINE_SHADOW = "game", ""
local TEXT_GAME_DEFAULT, TEXT_NEEDS_CUSTOM = "Game Default", ns.L("Set Bar Color to Custom Color")
local ENTRY_REFRESH = { "UpdateStyle", "UpdateBackground", "UpdateStatusBarColor" }
local SCROLL_GAME, SCROLL_ACCENT, SCROLL_HIDDEN = "game", "accent", "hidden"
local SCROLLS = { { game = TEXT_GAME_DEFAULT, accent = "Theme Accent", hidden = "Hidden" },
    { SCROLL_GAME, SCROLL_ACCENT, SCROLL_HIDDEN } }
local FADE_ALWAYS, FADE_HOVER = "always", "hover"
local FADES = { { always = "Always Shown", hover = "Shown on Hover" }, { FADE_ALWAYS, FADE_HOVER } }
local TITLE_PARTS = { "Header", "MinimizeButton", "SettingsDropdown", "SessionDropdown",
    "DamageMeterTypeDropdown", "SessionTimer" }
local FADE_EVERY, FADE_STEP, SETTLE, WATCH_DEPTH, SCROLL_DEPTH, PERCENT = 0.1, 0.35, 1, 5, 3, 100
local PERCENT_RANGE = { 0, PERCENT, 5 }
local FONT_SIZE_RANGE, FONT_SIZE_DEFAULT = { 0, 24, 1 }, 12
local BUTTON_PARTS = { "MinimizeButton", "SettingsDropdown", "SessionDropdown", "DamageMeterTypeDropdown" }
local BUTTON_DEPTH = 2
local BUTTONS_GAME, BUTTONS_THEMED = "game", "themed"
local BUTTONS = { { game = TEXT_GAME_DEFAULT, themed = "Themed" }, { BUTTONS_GAME, BUTTONS_THEMED } }
local TEXT_NEEDS_THEMED = ns.L("Set Buttons to Themed")
local TEXT_NEEDS_BORDER, TEXT_NEEDS_FADE = ns.L("Turn on Window Border"), ns.L("Set Title Bar to Shown on Hover")
local SETTING_PREFIX, POSITION_KEY = "^damageMeter", "damageMeterPos"

local HUD_NAMES, HUD_ORDER = unpack(Parts.HUD_OUTLINES)
local OUTLINE_NAMES, OUTLINE_ORDER = { [OUTLINE_GAME] = TEXT_GAME_DEFAULT }, { OUTLINE_GAME }
for key, name in pairs(HUD_NAMES) do OUTLINE_NAMES[key] = name end
for _, key in ipairs(HUD_ORDER) do OUTLINE_ORDER[#OUTLINE_ORDER + 1] = key end
local OUTLINES = { OUTLINE_NAMES, OUTLINE_ORDER }

local function Weak()
    return setmetatable({}, { __mode = "k" })
end

local meter
local generation = 0
local looks, hooked, edges, entries = Weak(), Weak(), Weak(), Weak()
local arts, swapped, faced, faded = Weak(), Weak(), Weak(), Weak()
local scrolled, tints, glyphs, buttoned, alphas, watched = Weak(), Weak(), Weak(), Weak(), Weak(), Weak()
local gameSizes = {}
local placementNote
local fader
local sinceTick = 0
local hovering, lowAlpha, scrollHidden, busy, awake = false, 0, false, false, 0

local function On()
    return S.Get("enabled") and S.Get("damageMeterSkin")
end

local function Free()
    return S.Get("enabled") and S.Get("damageMeterFree")
end

local function Watched(key)
    if key == "enabled" then return true end
    return type(key) == "string" and key ~= POSITION_KEY and key:find(SETTING_PREFIX) ~= nil
end

local function ThemedButtons()
    return S.Get("damageMeterButtons") == BUTTONS_THEMED
end

local function FadingTitle()
    return S.Get("damageMeterTitleFade") == FADE_HOVER
end

local function ScrollHidden()
    return S.Get("damageMeterScrollBar") == SCROLL_HIDDEN
end

local function Needed()
    return On() and (FadingTitle() or ScrollHidden())
end

local function Wake()
    if fader and Needed() then
        awake = SETTLE
        fader:Show()
    end
end

local function Has(object, method)
    return type(object) == "table" and type(object[method]) == "function"
end

local function Dig(t, ...)
    for i = 1, select("#", ...) do
        if type(t) ~= "table" then return nil end
        t = t[select(i, ...)]
    end
    return t
end

local function Watch(frame, depth)
    if not (Has(frame, "HookScript") and (not Has(frame, "HasScript") or frame:HasScript("OnEnter"))) then return end
    if not watched[frame] then
        watched[frame] = true
        frame:HookScript("OnEnter", Wake)
    end
    if depth > 0 and Has(frame, "GetChildren") then
        for _, child in ipairs({ frame:GetChildren() }) do Watch(child, depth - 1) end
    end
end

local function Pick(key, token)
    local c = S.Get(key)
    if type(c) == "table" then return c end
    return T[token]
end

local function Fraction(key)
    local v = S.Get(key)
    if type(v) ~= "number" then return 1 end
    if v > PERCENT then v = PERCENT end
    if v < 0 then v = 0 end
    return v / PERCENT
end

local function WindowColor()
    return Pick("damageMeterWindowColor", "bg")
end

local function Chosen(key, fallback)
    local c = S.Get(key)
    if type(c) == "table" then return c end
    return fallback()
end

local function BarBackground()
    return Chosen("damageMeterBarBgColor", WindowColor)
end

local function PanelColor()
    return Chosen("damageMeterPanelColor", WindowColor)
end

local function BarColor()
    local choice = S.Get("damageMeterBars")
    if choice == BAR_ACCENT then return T.accent end
    if choice == BAR_CUSTOM then return Pick("damageMeterBarColor", "accent") end
end

local function FontPath()
    local name = S.Get("damageMeterFont")
    if name == "" then return ns.UIFontPath() end
    return ns.UI.FontPath(name)
end

local function Flat(texture, c)
    if not Has(texture, "SetColorTexture") then return end
    local atlas = Has(texture, "GetAtlas") and texture:GetAtlas() or nil
    if atlas or looks[texture] == nil then looks[texture] = atlas or false end
    texture:SetColorTexture(c.r, c.g, c.b, 1)
end

local function Remember(fontString)
    local path, size, flags = fontString:GetFont()
    local r, g, b = fontString:GetTextColor()
    local was = { path = path, size = size, flags = flags, r = r, g = g, b = b }
    if Has(fontString, "GetShadowOffset") and Has(fontString, "GetShadowColor") then
        was.shadowX, was.shadowY = fontString:GetShadowOffset()
        was.shadowR, was.shadowG, was.shadowB, was.shadowA = fontString:GetShadowColor()
    end
    looks[fontString] = was
    return was
end

local function Shadow(fontString, was)
    if not (was.shadowX and Has(fontString, "SetShadowOffset") and Has(fontString, "SetShadowColor")) then return end
    fontString:SetShadowOffset(was.shadowX, was.shadowY)
    fontString:SetShadowColor(was.shadowR, was.shadowG, was.shadowB, was.shadowA)
end

local function Size(game, key)
    local size = key and S.Get(key)
    if type(size) == "number" and size > 0 then return size end
    return game
end

local function Face(fontString, was, key)
    local outline = S.Get("damageMeterOutline")
    if outline == OUTLINE_GAME then
        fontString:SetFont(FontPath(), Size(was.size, key), was.flags)
        Shadow(fontString, was)
        return
    end
    fontString:SetFont(FontPath(), Size(was.size, key), Parts.HudFlags(outline))
    if outline == OUTLINE_SHADOW then Parts.HudText(fontString) else Parts.HudText(fontString, false) end
end

local function Text(fontString, c, sizeKey)
    if not Has(fontString, "SetTextColor") then return end
    local was = looks[fontString] or Remember(fontString)
    if sizeKey and was.size and gameSizes[sizeKey] == nil then gameSizes[sizeKey] = was.size end
    if was.size and faced[fontString] ~= generation then
        faced[fontString] = generation
        Face(fontString, was, sizeKey)
    end
    fontString:SetTextColor(c.r, c.g, c.b)
end

local function Edge(frame)
    if not Has(frame, "GetFrameLevel") then return end
    if S.Get("damageMeterIconEdge") == false then
        if edges[frame] then edges[frame]._frame:Hide() end
        return
    end
    edges[frame] = edges[frame] or ns.Border(frame, T.line)
    edges[frame]._frame:Show()
end

local function Tint(entry)
    if not Has(entry, "GetStatusBarTexture") then return end
    local texture = entry:GetStatusBarTexture()
    if not Has(texture, "SetVertexColor") then return end
    local color = On() and BarColor()
    if color then
        texture:SetVertexColor(color.r, color.g, color.b)
    elseif entry.statusBarColor then
        texture:SetVertexColor(entry.statusBarColor:GetRGB())
    end
end

local function BarTexture(entry)
    local bar = entry.StatusBar
    if not (Has(bar, "SetStatusBarTexture") and Has(entry, "GetStatusBarTexture")) then return end
    local art = entry:GetStatusBarTexture()
    local file = ns.UI.TexturePath(S.Get("damageMeterTexture"), GRADIENT_TEX)
    if file then
        if arts[entry] == nil then arts[entry] = Has(art, "GetAtlas") and art:GetAtlas() or false end
        if swapped[entry] ~= file then
            swapped[entry] = file
            bar:SetStatusBarTexture(file)
        end
    elseif swapped[entry] then
        swapped[entry] = nil
        if arts[entry] and Has(art, "SetAtlas") then art:SetAtlas(arts[entry]) end
    end
end

local function Fill(entry, alpha)
    if not Has(entry, "GetStatusBarTexture") then return end
    local texture = entry:GetStatusBarTexture()
    if Has(texture, "SetAlpha") then texture:SetAlpha(alpha) end
end

local function Restyle(entry)
    if not On() then return end
    if ScrollHidden() then Wake() end
    local bar = entry.StatusBar
    if type(bar) ~= "table" then return end
    Flat(bar.Background, BarBackground())
    if Has(bar.Background, "SetAlpha") then bar.Background:SetAlpha(Fraction("damageMeterBarBgAlpha")) end
    if Has(bar.BackgroundEdge, "SetAlpha") then bar.BackgroundEdge:SetAlpha(0) end
    Text(bar.Name, Pick("damageMeterNameColor", "fg"), "damageMeterNameSize")
    Text(bar.Value, Pick("damageMeterValueColor", "muted"), "damageMeterValueSize")
    Edge(entry.Icon)
    BarTexture(entry)
    Tint(entry)
    Fill(entry, Fraction("damageMeterBarAlpha"))
end

local function Skin(entry)
    if type(entry) ~= "table" then return end
    entries[entry] = true
    if not watched[entry] and Needed() then Watch(entry, WATCH_DEPTH) end
    if not hooked[entry] then
        hooked[entry] = true
        for _, method in ipairs(ENTRY_REFRESH) do
            if Has(entry, method) then hooksecurefunc(entry, method, Restyle) end
        end
    end
    Restyle(entry)
end

local function Entries(scrollBox)
    if not Has(scrollBox, "EnumerateFrames") then return end
    if not hooked[scrollBox] and ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
        hooked[scrollBox] = true
        ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, frame) Skin(frame) end)
    end
    for _, frame in scrollBox:EnumerateFrames() do Skin(frame) end
end

local function Opacity(region, alpha)
    if not Has(region, "SetAlpha") then return end
    if alphas[region] == nil then alphas[region] = Has(region, "GetAlpha") and region:GetAlpha() or 1 end
    region:SetAlpha(alpha)
end

local function WindowBorder(window)
    local border = edges[window]
    if S.Get("damageMeterBorder") ~= true or not Has(window, "GetFrameLevel") then
        if border then border._frame:Hide() end
        return
    end
    local c = Pick("damageMeterBorderColor", "line")
    if not border then
        border = ns.Border(window, c)
        edges[window] = border
    end
    border:SetColor(c.r, c.g, c.b, 1)
    border._frame:Show()
end

local function Textures(frame, depth, out)
    if Has(frame, "GetRegions") then
        for _, region in ipairs({ frame:GetRegions() }) do
            if Has(region, "SetVertexColor") then out[#out + 1] = region end
        end
    end
    if depth > 0 and Has(frame, "GetChildren") then
        for _, child in ipairs({ frame:GetChildren() }) do Textures(child, depth - 1, out) end
    end
    return out
end

local function Vertex(texture)
    local r, g, b, a = texture:GetVertexColor()
    return { r = r, g = g, b = b, a = a }
end

local function ScrollBar(window, mode)
    local bar = Dig(window, "MinimizeContainer", "ScrollBar")
    if type(bar) ~= "table" then return end
    if mode == SCROLL_GAME and not scrolled[window] then return end
    scrolled[window] = true
    if Has(bar, "SetAlpha") then bar:SetAlpha(mode == SCROLL_HIDDEN and 0 or 1) end
    for _, texture in ipairs(Textures(bar, SCROLL_DEPTH, {})) do
        if tints[texture] == nil and Has(texture, "GetVertexColor") then tints[texture] = Vertex(texture) end
        local was = tints[texture]
        if mode == SCROLL_ACCENT then
            texture:SetVertexColor(T.accent.r, T.accent.g, T.accent.b)
        elseif was then
            texture:SetVertexColor(was.r, was.g, was.b, was.a)
        end
    end
end

local function Buttons(window, themed)
    if not themed and not buttoned[window] then return end
    buttoned[window] = true
    local c = Pick("damageMeterButtonColor", "accent")
    for _, key in ipairs(BUTTON_PARTS) do
        for _, texture in ipairs(Textures(window[key], BUTTON_DEPTH, {})) do
            if glyphs[texture] == nil and Has(texture, "GetVertexColor") then
                local first = Vertex(texture)
                first.desaturated = Has(texture, "IsDesaturated") and texture:IsDesaturated() or false
                glyphs[texture] = first
            end
            local was = glyphs[texture]
            if themed then
                if Has(texture, "SetDesaturated") then texture:SetDesaturated(true) end
                texture:SetVertexColor(c.r, c.g, c.b)
            elseif was then
                if Has(texture, "SetDesaturated") then texture:SetDesaturated(was.desaturated) end
                texture:SetVertexColor(was.r, was.g, was.b, was.a)
            end
        end
    end
end

local function TitleAlpha(window, alpha)
    for _, key in ipairs(TITLE_PARTS) do
        local part = window[key]
        if Has(part, "SetAlpha") then part:SetAlpha(alpha) end
    end
end

local function Label(fontString)
    if not Has(fontString, "SetTextColor") then return end
    local was = looks[fontString] or Remember(fontString)
    local c = { r = was.r, g = was.g, b = was.b }
    if ThemedButtons() then c = Pick("damageMeterButtonColor", "accent") end
    Text(fontString, c, nil)
end

local function SkinWindow(window)
    local titles, values = Pick("damageMeterTitleColor", "fg"), Pick("damageMeterValueColor", "muted")
    Flat(window.Header, Pick("damageMeterHeaderColor", "panel"))
    Text(window.SessionTimer, values, "damageMeterValueSize")
    Label(Dig(window, "SessionDropdown", "SessionName"))
    Text(Dig(window, "DamageMeterTypeDropdown", "TypeName"), titles, "damageMeterTitleSize")
    WindowBorder(window)
    Buttons(window, ThemedButtons())
    if Needed() then Watch(window, WATCH_DEPTH) end
    local container = window.MinimizeContainer
    if type(container) ~= "table" then return end
    Flat(container.Background, WindowColor())
    ScrollBar(window, S.Get("damageMeterScrollBar"))
    Skin(container.LocalPlayerEntry)
    Entries(container.ScrollBox)
    local source = container.SourceWindow
    if type(source) == "table" then
        Flat(source.Background, PanelColor())
        Opacity(source.Background, Fraction("damageMeterPanelAlpha"))
        WindowBorder(source)
        Entries(source.ScrollBox)
    end
end

local function RestoreWindow(window)
    if faded[window] then
        faded[window] = nil
        TitleAlpha(window, 1)
    end
    if scrolled[window] then ScrollBar(window, SCROLL_GAME) end
    if buttoned[window] then Buttons(window, false) end
    local panel = Dig(window, "MinimizeContainer", "SourceWindow", "Background")
    if panel and alphas[panel] ~= nil then Opacity(panel, alphas[panel]) end
end

local function GiveBack()
    for region, was in pairs(looks) do
        if type(was) == "string" and Has(region, "SetAtlas") then
            region:SetAtlas(was)
        elseif type(was) == "table" and was.path then
            region:SetFont(was.path, was.size, was.flags)
            region:SetTextColor(was.r, was.g, was.b)
            Shadow(region, was)
        end
    end
    for _, border in pairs(edges) do border._frame:Hide() end
    for entry in pairs(entries) do
        local bar = entry.StatusBar
        if type(bar) == "table" then
            if Has(bar.BackgroundEdge, "SetAlpha") then bar.BackgroundEdge:SetAlpha(1) end
            if Has(bar.Background, "SetAlpha") then bar.Background:SetAlpha(1) end
        end
        Fill(entry, 1)
        if swapped[entry] then
            swapped[entry] = nil
            local art = Has(entry, "GetStatusBarTexture") and entry:GetStatusBarTexture() or nil
            if arts[entry] and Has(art, "SetAtlas") then art:SetAtlas(arts[entry]) end
        end
        Tint(entry)
    end
    if Has(meter, "ForEachSessionWindow") then meter:ForEachSessionWindow(RestoreWindow) end
end

local placed = false

local function Note(text)
    if placementNote == text then return end
    placementNote = text
    if ns.UI and ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function Primary()
    local window = Has(meter, "GetPrimarySessionWindow") and meter:GetPrimarySessionWindow() or nil
    if type(window) ~= "table" then window = _G[PRIMARY_WINDOW] end
    return window
end

local function Locked(window)
    return Has(window, "IsLocked") and window:IsLocked() == true
end

local function Save(window)
    local left, top = window:GetLeft(), window:GetTop()
    if not (left and top) then return end
    S.Set(POSITION_KEY, { left = left, top = top, width = window:GetWidth(), height = window:GetHeight() })
end

local function Handles(window)
    if hooked[window] or not Has(window, "HookScript") then return end
    hooked[window] = true
    window:HookScript("OnDragStart", function(self)
        if Free() and not Locked(self) then self:StartMoving() end
    end)
    window:HookScript("OnDragStop", function(self)
        if not Free() then return end
        self:StopMovingOrSizing()
        Save(self)
    end)
    local grip = Dig(window, "MinimizeContainer", "ResizeButton")
    if not Has(grip, "HookScript") then return end
    grip:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and Free() and not Locked(window) then window:StartSizing("BOTTOMRIGHT") end
    end)
    grip:HookScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not Free() then return end
        window:StopMovingOrSizing()
        Save(window)
    end)
    grip:HookScript("OnEnter", function(self)
        if Free() and not Locked(window) then self:SetAlpha(1) end
    end)
    grip:HookScript("OnLeave", function(self)
        if Free() then self:SetAlpha(0) end
    end)
end

local function Reattach(window)
    placed = false
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT")
    window:SetPoint("BOTTOMRIGHT")
    if Has(window, "SetMovable") then window:SetMovable(false) end
    if Has(window, "SetResizable") then window:SetResizable(false) end
end

local function Place()
    local window = Primary()
    if not (Has(window, "SetPoint") and Has(window, "ClearAllPoints") and Has(window, "SetSize")) then
        if Free() then Note(TEXT_NO_WINDOW) end
        return
    end
    if not Free() then
        if placed then Reattach(window) end
        return
    end
    local pos = S.Get(POSITION_KEY)
    if type(pos) ~= "table" then
        Save(window)
        pos = S.Get(POSITION_KEY)
        if type(pos) ~= "table" then
            Note(TEXT_NO_PLACE)
            return
        end
    end
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.left, pos.top)
    window:SetSize(pos.width, pos.height)
    if Has(window, "SetMovable") then window:SetMovable(true) end
    if Has(window, "SetResizable") then window:SetResizable(true) end
    placed = true
    Note(nil)
    Handles(window)
end

local function ResetPosition()
    local window = Primary()
    if placed and Has(window, "ClearAllPoints") then Reattach(window) end
    S.Set(POSITION_KEY, false)
    Place()
end

local function Toward(now, want)
    if now < want then
        now = now + FADE_STEP
        if now > want then now = want end
    else
        now = now - FADE_STEP
        if now < want then now = want end
    end
    return now
end

local function TickWindow(window)
    local over = Has(window, "IsMouseOver") and window:IsMouseOver()
    if over then busy = true end
    if hovering then
        local want = over and 1 or lowAlpha
        local now = faded[window] or 1
        if now ~= want then
            busy = true
            now = Toward(now, want)
            faded[window] = now
            TitleAlpha(window, now)
        end
    elseif faded[window] then
        faded[window] = nil
        TitleAlpha(window, 1)
    end
    if scrollHidden then
        local bar = Dig(window, "MinimizeContainer", "ScrollBar")
        if Has(bar, "SetAlpha") then bar:SetAlpha(0) end
    end
end

local function Tick()
    busy = false
    if not (meter and On() and Has(meter, "ForEachSessionWindow")) then return end
    hovering = FadingTitle()
    lowAlpha = Fraction("damageMeterTitleFadeAlpha")
    scrollHidden = ScrollHidden()
    meter:ForEachSessionWindow(TickWindow)
end

local function OnFade(self, elapsed)
    sinceTick = sinceTick + elapsed
    if sinceTick < FADE_EVERY then return end
    awake = awake - sinceTick
    sinceTick = 0
    Tick()
    if busy then awake = SETTLE end
    if awake <= 0 then self:Hide() end
end

local function Pace()
    if not Needed() then
        if fader then fader:Hide() end
        return
    end
    if not fader then
        fader = CreateFrame("Frame")
        fader:Hide()
        fader:SetScript("OnUpdate", OnFade)
    end
    Wake()
end

local function Apply()
    if not meter then return end
    generation = generation + 1
    if not On() then
        GiveBack()
    elseif Has(meter, "ForEachSessionWindow") then
        meter:ForEachSessionWindow(SkinWindow)
        for entry in pairs(entries) do
            BarTexture(entry)
            Tint(entry)
            Fill(entry, Fraction("damageMeterBarAlpha"))
        end
    end
    Place()
    Tick()
    Pace()
end

local function Hook()
    meter = _G.DamageMeter
    if Has(meter, "SetupSessionWindow") then hooksecurefunc(meter, "SetupSessionWindow", Apply) end
    Apply()
end

local function Start()
    if meter or not (On() or Free()) then return end
    if C_AddOns.IsAddOnLoaded(ADDON) then
        Hook()
    else
        EventUtil.ContinueOnAddOnLoaded(ADDON, Hook)
    end
end

hooksecurefunc(S, "Set", function(key)
    if not Watched(key) then return end
    Start()
    Apply()
end)
hooksecurefunc(ns, "Apply", function()
    Start()
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Start)

local function CustomBars()
    return S.Get("damageMeterBars") == BAR_CUSTOM
end

local function Bordered()
    return S.Get("damageMeterBorder") == true
end

local function SkinOn()
    return S.Get("damageMeterSkin") == true
end

local function NotFree()
    return S.Get("damageMeterFree") ~= true
end

local function ColorRow(key, label, token, help, needs, why, current)
    return { key = key, label = label, colour = true, help = help, needs = needs, why = why,
        get = function()
            local c = current and current() or Pick(key, token)
            return c.r, c.g, c.b, 1
        end,
        set = function(r, g, b) S.Set(key, { r = r, g = g, b = b }) end }
end

local function SizeRow(key, label, help)
    return { key = key, label = label, slider = FONT_SIZE_RANGE, unit = "px", help = help,
        get = function()
            local picked = S.Get(key)
            if type(picked) == "number" and picked > 0 then return picked end
            local game = gameSizes[key] or FONT_SIZE_DEFAULT
            return game - game % 1
        end,
        set = function(v) S.Set(key, v) end }
end

local skin = {
    barColor = { key = "damageMeterBars", label = "Bar Color", choice = BARS },
    customBarColor = ColorRow("damageMeterBarColor", "Custom Bar Color", "accent",
        "The bars' color when Bar Color is Custom Color.", CustomBars, TEXT_NEEDS_CUSTOM),
    texture = { key = "damageMeterTexture", label = "Bar Texture", texture = TEXT_GRADIENT },
    iconEdge = { key = "damageMeterIconEdge", label = "Icon Border", toggle = true,
      help = "A thin border round each bar's icon." },
    barAlpha = { key = "damageMeterBarAlpha", label = "Bar Opacity", slider = PERCENT_RANGE, unit = "%",
      help = "How solid the bars are." },
    barBgColor = ColorRow("damageMeterBarBgColor", "Bar Background Color", "bg",
        "The color behind each bar, the Window Color until you pick one.", nil, nil, BarBackground),
    barBgAlpha = { key = "damageMeterBarBgAlpha", label = "Bar Background Opacity", slider = PERCENT_RANGE, unit = "%",
      help = "How solid the color behind each bar is." },
    scrollBar = { key = "damageMeterScrollBar", label = "Scroll Bar", choice = SCROLLS,
      help = "The game's own, in your Accent, or hidden; the mouse wheel still scrolls." },
    font = { key = "damageMeterFont", label = "Font", font = true },
    outline = { key = "damageMeterOutline", label = "Outline", choice = OUTLINES,
      help = "The game's own, none, the soft shadow, a thin outline or a thick one." },
    nameColor = ColorRow("damageMeterNameColor", "Name Color", "fg", "The names on the bars."),
    nameSize = SizeRow("damageMeterNameSize", "Name Size",
        "The names on the bars, 0 being the game's own size."),
    valueColor = ColorRow("damageMeterValueColor", "Amount Color", "muted", "The amounts, and the fight time."),
    valueSize = SizeRow("damageMeterValueSize", "Amount Size", "The amounts and the fight time, 0 being the game's own size."),
    titleColor = ColorRow("damageMeterTitleColor", "Title Color", "fg", "The list and session names in the title bar."),
    titleSize = SizeRow("damageMeterTitleSize", "Title Size", "The list name in the title bar, 0 being the game's own size."),
    headerColor = ColorRow("damageMeterHeaderColor", "Title Bar Color", "panel", "The title bar."),
    panelColor = ColorRow("damageMeterPanelColor", "Spell Panel Color", "bg",
        "The panel a left click opens, the Window Color until you pick one.", nil, nil, PanelColor),
    panelAlpha = { key = "damageMeterPanelAlpha", label = "Spell Panel Opacity", slider = PERCENT_RANGE, unit = "%",
      help = "How solid the panel a left click opens is." },
    windowColor = ColorRow("damageMeterWindowColor", "Window Color", "bg", "The window and the shadow behind each bar."),
    border = { key = "damageMeterBorder", label = "Window Border", toggle = true,
      help = "A thin border round the window and the spell panel." },
    borderColor = ColorRow("damageMeterBorderColor", "Border Color", "line", "The border round the window.",
        Bordered, TEXT_NEEDS_BORDER),
    buttons = { key = "damageMeterButtons", label = "Buttons", choice = BUTTONS,
      help = "The title bar's buttons: the game's own, or in your theme." },
    buttonColor = ColorRow("damageMeterButtonColor", "Button Color", "accent", "The buttons, when they are Themed.",
        ThemedButtons, TEXT_NEEDS_THEMED),
    titleFade = { key = "damageMeterTitleFade", label = "Title Bar", choice = FADES,
      help = "Always shown, or faded until the mouse is over the window." },
    titleFadeAlpha = { key = "damageMeterTitleFadeAlpha", label = "Faded Title Opacity", slider = PERCENT_RANGE,
      unit = "%", needs = FadingTitle, why = TEXT_NEEDS_FADE,
      help = "How much of the title bar stays while the mouse is away." },
}

for _, row in pairs(skin) do
    local own = row.needs
    if type(own) == "function" then
        row.needs = function() return SkinOn() and own() end
    elseif own == nil then
        row.needs = "damageMeterSkin"
    end
end

local layout = ns.DamageMeterLayout
local game = layout and layout.byName or {}
for _, name in ipairs({ "FrameWidth", "FrameHeight" }) do
    if game[name] then game[name].needs, game[name].why = NotFree, TEXT_NEEDS_NOT_FREE end
end

local card = {}
local function Add(...)
    for index = 1, select("#", ...) do
        local row = select(index, ...)
        if row then card[#card + 1] = row end
    end
end

Add({ key = "damageMeterSkin", label = "Reskin", toggle = true,
    help = "Draws the game's damage meter in your theme; the rows that need it wait for this." })
Add(Settings.Group("Window"))
Add(game.Visibility, game.FrameWidth, game.FrameHeight)
Add({ key = "damageMeterFree", label = "Move and Resize", toggle = true,
    note = function() return placementNote end,
    help = "Drag the window and its corner here, without Edit Mode." })
Add(game.Transparency, game.BackgroundTransparency, skin.windowColor, skin.border, skin.borderColor)
Add(Settings.Group("Bars"))
Add(game.Style, game.BarHeight, game.Padding, skin.texture, skin.barColor, skin.customBarColor, skin.barAlpha,
    skin.barBgColor, skin.barBgAlpha, game.ShowSpecIcon, game.ShowClassColor, skin.iconEdge, skin.scrollBar)
Add(Settings.Group("Text"))
Add(skin.font, skin.outline, game.TextSize, game.Numbers, skin.nameColor, skin.nameSize, skin.valueColor,
    skin.valueSize)
Add(Settings.Group("Title Bar"))
Add(skin.titleColor, skin.titleSize, skin.headerColor, skin.buttons, skin.buttonColor, skin.titleFade,
    skin.titleFadeAlpha)
Add(Settings.Group("Spell Panel"))
Add(skin.panelColor, skin.panelAlpha)
Add(Settings.Group("Reset"))
Add({ label = "Window Position", buttonText = "Reset", button = ResetPosition,
    needs = "damageMeterFree", help = "Puts the window back where Edit Mode has it." })
Add(layout and layout.restore)

local function OtherMeters()
    local names
    for _, other in ipairs(OTHER_METERS) do
        if C_AddOns.IsAddOnLoaded(other.addon) then names = names and (names .. ", " .. other.name) or other.name end
    end
    if not names then return TEXT_OTHERS end
    return TEXT_OTHERS_NAMED:format(names)
end

Settings.Page("QoL/Combat", S):Card({
    id = "damageMeterSkin", name = "Default Damage Meter", order = CARD_ORDER, note = OtherMeters,
    help = "The game's own damage meter: in your theme, sized and set here instead of in Edit Mode.",
    search = "damage meter skin reskin blizzard default bar height move resize edit mode style numbers padding",
    rows = card,
})
