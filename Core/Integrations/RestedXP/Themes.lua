-- Themes.lua: the Naowh themes in RestedXP Guides, and the hooks that style it.
local ns = _G.NaowhForever
local F = ns.FEATURES.account

local RXP_ADDON = "RXPGuides"
local NAME_PREFIX = "NaowhForever:"
local AUTHOR = "Naowh Forever"
local DEFAULT_KEY, DEFAULT_NAME = "default", "Naowh"
local CURRENT_KEY, CURRENT_NAME = "current", ns.L("Naowh (current)")
local RXP_DEFAULT = "Default"
local TEXT_RXP_DEFAULT = ns.L("RestedXP (default)")
local TEXT_CURRENT = ns.L("Current Theme")

local RXP_TEXTURES = "Interface/AddOns/RXPGuides/Textures/"
local TEXTURES = RXP_TEXTURES .. "DarkMode/"
local WHITE = "Interface/BUTTONS/WHITE8X8"

local HIGHLIGHT_ALPHA = 0.5
local RULE_ALPHA = 0.6
local CHROME_ALPHA = 0.7
local RULE_DROP = 3
local RULE_H = 1

local MEDIA = ns.MEDIA
local RXP_ART = "Interface\\AddOns\\NaowhForever\\Core\\Integrations\\RestedXP\\Media\\"
local FRAME = RXP_ART .. "rxp_frame.tga"
local ARROW_IMAGES = {
    kite = { [false] = RXP_ART .. "rxp_arrow.tga", [true] = RXP_ART .. "rxp_arrow_glow.tga" },
    wide = { [false] = RXP_ART .. "rxp_arrow_wide.tga", [true] = RXP_ART .. "rxp_arrow_wide_glow.tga" },
}
local DEFAULT_SHAPE = "kite"
local ARROW_STYLES = { layer = true, image = true, off = true }
local DEFAULT_ARROW = "layer"
local SIZE_MIN, SIZE_MAX, SIZE_STEP, DEFAULT_SIZE = 60, 200, 5, 90
local GLOW_FILL = 0.76
local GAP_MIN, GAP_MAX, DEFAULT_GAP = 0, 20, 4
local GAP_STEP = 1
local PERCENT = 100
local CHANNEL_MAX = 255
local ROUND = 0.5
local TOP_TOWARD_WHITE = 0.22
local BOTTOM_SHARE = 0.72
local LAYER_STRENGTH = 0.9
local DIAGONAL = math.sqrt(2)   -- a square's diagonal, over its side

local BARS = { "GuideName", "Footer" }
local COG = MEDIA .. "cog.tga"
local GRIP = RXP_ART .. "rxp_grip.tga"
local ARROWS = { "ScrollUpButton", "ScrollDownButton" }
local ARROW_PARTS = { "Normal", "Highlight", "Pushed", "Disabled" }
local THUMB_W, THUMB_H = 8, 40

local PaintArrow
local boot

function ns.RXPThemesAvailable()
    return C_AddOns.DoesAddOnExist(RXP_ADDON) == true
end

function ns.RXPThemesEnabled()
    local on = ns.AccountSettings().rxpThemes
    if on == nil then return F.rxpThemes end
    return on == true
end

function ns.SetRXPThemes(on)
    ns.AccountSettings().rxpThemes = on and true or nil
end

function ns.RXPThemeChoices()
    local values = { [""] = TEXT_RXP_DEFAULT, [CURRENT_KEY] = TEXT_CURRENT, [DEFAULT_KEY] = DEFAULT_NAME }
    local order = { "", CURRENT_KEY, DEFAULT_KEY }
    for _, key in ipairs(ns.THEME_PRESET_ORDER) do
        values[key] = ns.THEME_PRESETS[key].name
        order[#order + 1] = key
    end
    return values, order
end

local function ThemeId(key)
    return key == CURRENT_KEY or key == DEFAULT_KEY or (type(key) == "string" and ns.THEME_PRESETS[key] ~= nil)
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

local function Ours(name)
    return type(name) == "string" and name:find(NAME_PREFIX, 1, true) == 1
end

local function Reload()
    local rxp = _G.RXP
    if not Has(rxp, "ReloadTheme") then return end
    if InCombatLockdown() then
        boot:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    rxp:ReloadTheme()
end

function ns.RXPThemesReady()
    local rxp = _G.RXP
    return type(Dig(rxp, "settings", "profile")) == "table" and Has(rxp, "ReloadTheme")
        and type(Dig(rxp, "themes", NAME_PREFIX .. DEFAULT_KEY)) == "table"
end

function ns.RXPThemeChoice()
    local name = Dig(_G.RXP, "settings", "profile", "activeTheme")
    local key = Ours(name) and name:sub(#NAME_PREFIX + 1)
    return ThemeId(key) and Dig(_G.RXP, "themes", name) and key or ""
end

function ns.SetRXPThemeChoice(key)
    local rxp = _G.RXP
    local profile = Dig(rxp, "settings", "profile")
    if type(profile) ~= "table" or not Has(rxp, "ReloadTheme") then return end
    local name
    if key == "" then
        name = Ours(profile.activeTheme) and RXP_DEFAULT
    elseif ThemeId(key) and Dig(rxp, "themes", NAME_PREFIX .. key) then
        name = NAME_PREFIX .. key
    end
    if not name or profile.activeTheme == name then return end
    profile.activeTheme = name
    if not profile.enableThemeLiveReload then return "reload" end
    Reload()
end

local function Wanted(key)
    return ns.AccountSettings()[key] ~= false
end

local function Want(key, on)
    if on then ns.AccountSettings()[key] = nil else ns.AccountSettings()[key] = false end
end

function ns.RXPFontEnabled() return Wanted("rxpFont") end

function ns.SetRXPFont(on) Want("rxpFont", on) end

function ns.RXPTextColorEnabled() return Wanted("rxpTextColor") end

function ns.SetRXPTextColor(on) Want("rxpTextColor", on) end

function ns.RXPArrowStyle()
    local style = ns.AccountSettings().rxpArrow
    return ARROW_STYLES[style] and style or DEFAULT_ARROW
end

function ns.SetRXPArrowStyle(style)
    ns.AccountSettings().rxpArrow = (ARROW_STYLES[style] and style ~= DEFAULT_ARROW) and style or nil
    PaintArrow()
end

function ns.RXPArrowShape()
    local shape = ns.AccountSettings().rxpArrowShape
    return ARROW_IMAGES[shape] and shape or DEFAULT_SHAPE
end

function ns.SetRXPArrowShape(shape)
    ns.AccountSettings().rxpArrowShape = (ARROW_IMAGES[shape] and shape ~= DEFAULT_SHAPE) and shape or nil
    PaintArrow()
end

function ns.RXPArrowSizeRange() return SIZE_MIN, SIZE_MAX, SIZE_STEP end

local function Snap(value, lo, hi, step)
    return math.min(hi, math.max(lo, math.floor(value / step + ROUND) * step))
end

function ns.RXPArrowSize()
    local size = tonumber(ns.AccountSettings().rxpArrowSize)
    return size and Snap(size, SIZE_MIN, SIZE_MAX, SIZE_STEP) or DEFAULT_SIZE
end

function ns.SetRXPArrowSize(size)
    size = tonumber(size)
    size = size and Snap(size, SIZE_MIN, SIZE_MAX, SIZE_STEP)
    ns.AccountSettings().rxpArrowSize = size ~= DEFAULT_SIZE and size or nil
    PaintArrow()
end

function ns.RXPArrowGapRange() return GAP_MIN, GAP_MAX end

function ns.RXPArrowGap()
    local gap = tonumber(ns.AccountSettings().rxpArrowGap)
    return gap and Snap(gap, GAP_MIN, GAP_MAX, GAP_STEP) or DEFAULT_GAP
end

function ns.SetRXPArrowGap(gap)
    gap = tonumber(gap)
    gap = gap and Snap(gap, GAP_MIN, GAP_MAX, GAP_STEP)
    ns.AccountSettings().rxpArrowGap = gap ~= DEFAULT_GAP and gap or nil
    PaintArrow()
end

function ns.RXPArrowTextEnabled() return Wanted("rxpArrowText") end

function ns.SetRXPArrowText(on)
    Want("rxpArrowText", on)
    PaintArrow()
end

function ns.RXPArrowGlow()
    return ns.AccountSettings().rxpArrowGlow == true
end

function ns.SetRXPArrowGlow(on)
    ns.AccountSettings().rxpArrowGlow = on and true or nil
    PaintArrow()
end

local function Rgba(c, alpha)
    return { c.r, c.g, c.b, alpha }
end

local function Hex(c)
    return ("%02x%02x%02x"):format(math.floor(c.r * CHANNEL_MAX + ROUND),
        math.floor(c.g * CHANNEL_MAX + ROUND), math.floor(c.b * CHANNEL_MAX + ROUND))
end

local function Theme(id, displayName, source)
    local palette = ns.ThemePalette(source)
    local c = {}
    for i, token in ipairs(ns.THEME_EDITABLE) do c[token] = palette[i] end
    return {
        name = NAME_PREFIX .. id,
        displayName = displayName,
        author = AUTHOR,
        background = Rgba(c.panel, 1),
        bottomFrameBG = Rgba(c.panel, 1),
        bottomFrameHighlight = Rgba(c.accent, HIGHLIGHT_ALPHA),
        dividerColor = Rgba(c.line, RULE_ALPHA),
        chromeColor = Rgba(c.muted, CHROME_ALPHA),
        mapPins = Rgba(c.accent, 1),
        tooltip = "|cff" .. Hex(c.accent),
        textColor = ns.RXPTextColorEnabled() and { c.fg.r, c.fg.g, c.fg.b } or nil,
        font = ns.RXPFontEnabled() and ns.AddonFontPath() or nil,
        texturePath = TEXTURES,
        bgTextures = { edge = WHITE, bottom = WHITE, guideName = WHITE },
        edges = { edge = FRAME, guideName = FRAME },
    }
end

local late

local function Add(themes, id, displayName, source)
    local theme = Theme(id, displayName, source)
    themes[theme.name] = theme
end

local function Register()
    local themes = {}
    Add(themes, DEFAULT_KEY, DEFAULT_NAME, "")
    for _, key in ipairs(ns.THEME_PRESET_ORDER) do Add(themes, key, ns.THEME_PRESETS[key].name, key) end
    Add(themes, CURRENT_KEY, CURRENT_NAME, ns.ThemePresetKey())
    local rxp = _G.RXP
    if Has(rxp, "RegisterTheme") and type(rxp.activeTheme) == "table" then
        late = true
        for _, theme in pairs(themes) do rxp:RegisterTheme(theme) end
        return
    end
    local list = _G.RXPGuides_Themes
    if type(list) ~= "table" then
        list = {}
        _G.RXPGuides_Themes = list
    end
    for name, theme in pairs(themes) do list[name] = theme end
end

local function Resume()
    local rxp = _G.RXP
    local saved = Dig(rxp, "themes", Dig(rxp, "settings", "profile", "activeTheme"))
    if type(saved) == "table" and Ours(saved.name) and saved ~= rxp.activeTheme then Reload() end
end

local function ActiveTheme()
    local rxp = _G.RXP
    local theme = rxp and rxp.activeTheme
    if type(theme) == "table" and type(theme.name) == "string" and type(theme.mapPins) == "table"
            and theme.name:find(NAME_PREFIX, 1, true) == 1 then
        return theme
    end
end

local layer
local swapped
local fitted
local rxpImage
local textHome
local textHidden
local hookedArrow

local function BuildLayer(arrow)
    local texture = arrow.texture
    if not Has(texture, "SetRotation") then return nil end
    local f = CreateFrame("Frame", nil, arrow)
    f:SetAllPoints()
    f:SetFrameLevel(arrow:GetFrameLevel() + 1)
    f.color = f:CreateTexture(nil, "OVERLAY")
    f.color:SetPoint("CENTER")
    f.color:SetBlendMode("ADD")
    f.mask = f:CreateMaskTexture()
    f.mask:SetAllPoints()
    f.color:AddMaskTexture(f.mask)
    hooksecurefunc(texture, "SetRotation", function(_, radians) f.mask:SetRotation(radians) end)
    -- A turned arrow reaches past its square frame, so the colour covers the square's diagonal and the
    -- mask cuts it to the arrow; at the frame's own size its tips lost their colour.
    local function Cover(self, w, h)
        local side = math.max(w, h) * DIAGONAL
        self.color:SetSize(side, side)
    end
    f:SetScript("OnSizeChanged", Cover)
    Cover(f, arrow:GetSize())
    return f
end

local function ShowLayer(arrow, c)
    layer = layer or BuildLayer(arrow)
    if not layer then return end
    layer.color:SetColorTexture(1, 1, 1, 1)
    layer.color:SetGradient("VERTICAL",
        CreateColor(c[1] * BOTTOM_SHARE, c[2] * BOTTOM_SHARE, c[3] * BOTTOM_SHARE, LAYER_STRENGTH),
        CreateColor(c[1] + (1 - c[1]) * TOP_TOWARD_WHITE, c[2] + (1 - c[2]) * TOP_TOWARD_WHITE,
            c[3] + (1 - c[3]) * TOP_TOWARD_WHITE, LAYER_STRENGTH))
    layer.mask:SetTexture(arrow.texture:GetTexture(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    layer.mask:SetRotation(arrow.orientation or 0)
    layer:Show()
end

local function MoveText(arrow, down)
    local text = arrow.text
    if not Has(text, "GetPoint") then return end
    textHome = textHome or { text:GetPoint() }
    local point, relativeTo, relativePoint, x, y = unpack(textHome)
    text:SetPoint(point, relativeTo, relativePoint, x, y - down)
end

local function Fit(arrow, texture, scale)
    if not (Has(texture, "ClearAllPoints") and Has(arrow, "GetSize")) then return end
    local w, h = arrow:GetSize()
    local dx, dy = w * (scale - 1) / 2, h * (scale - 1) / 2
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", arrow, "TOPLEFT", -dx, dy)
    texture:SetPoint("BOTTOMRIGHT", arrow, "BOTTOMRIGHT", dx, -dy)
    MoveText(arrow, math.max(0, dy) + ns.RXPArrowGap())
end

local function ShowImage(arrow, texture, c)
    texture:SetTexture(ARROW_IMAGES[ns.RXPArrowShape()][ns.RXPArrowGlow()])
    texture:SetVertexColor(c[1], c[2], c[3], 1)
    fitted = ns.RXPArrowSize() / PERCENT / (ns.RXPArrowGlow() and GLOW_FILL or 1)
    Fit(arrow, texture, fitted)
    swapped = true
end

local function HandBack(arrow, texture)
    if fitted then
        fitted = nil
        if Has(texture, "SetAllPoints") then
            texture:ClearAllPoints()
            texture:SetAllPoints()
        end
        if textHome then arrow.text:SetPoint(unpack(textHome)) end
        texture:SetVertexColor(1, 1, 1, 1)
    end
    if swapped then
        if rxpImage then texture:SetTexture(rxpImage) end
        swapped = false
    end
end

local function PaintText(arrow, theme)
    local text = arrow.text
    if not Has(text, "Hide") then return end
    local hide = theme ~= nil and not ns.RXPArrowTextEnabled()
    if hide and not textHidden then
        text:Hide()
    elseif textHidden and not hide then
        text:Show()
    end
    textHidden = hide
end

function PaintArrow()
    local arrow = _G.RXPG_ARROW
    local texture = arrow and arrow.texture
    if not texture then return end
    local theme = ActiveTheme()
    local style = theme and ns.RXPArrowStyle() or "off"
    if style == "layer" then
        ShowLayer(arrow, theme.mapPins)
    elseif layer then
        layer:Hide()
    end
    if style == "image" then
        ShowImage(arrow, texture, theme.mapPins)
    else
        HandBack(arrow, texture)
    end
    PaintText(arrow, theme)
end

local function OnRxpUpdate()
    local arrow = _G.RXPG_ARROW
    swapped = false
    rxpImage = arrow and arrow.texture and arrow.texture:GetTexture()
    PaintArrow()
end

local function OnArrowSize()
    if fitted then Fit(hookedArrow, hookedArrow.texture, fitted) end
end

local function HookArrow()
    local arrow = _G.RXPG_ARROW
    if not (arrow and arrow.texture and Has(arrow, "UpdateVisuals")) then return end
    hooksecurefunc(arrow, "UpdateVisuals", OnRxpUpdate)
    if Has(arrow, "HookScript") then
        hookedArrow = arrow
        arrow:HookScript("OnSizeChanged", OnArrowSize)
    end
    OnRxpUpdate()
end

local barsHidden

local function Banner(name)
    local banner = Dig(_G.RXPFrame, name, "bg")
    return type(banner) == "table" and banner or nil
end

local function PaintBars()
    local hide = ActiveTheme() ~= nil
    if not hide and not barsHidden then return end
    for _, name in ipairs(BARS) do
        local banner = Banner(name)
        if Has(banner, "SetAlpha") then banner:SetAlpha(hide and 0 or 1) end
    end
    barsHidden = hide
end

local function HookBars()
    for _, name in ipairs(BARS) do
        local banner = Banner(name)
        if Has(banner, "SetTexture") then hooksecurefunc(banner, "SetTexture", PaintBars) end
    end
    PaintBars()
end

local chromeTinted, gripOriginal, thumbSize

local function Skin(texture, path, color)
    if not Has(texture, "SetVertexColor") then return end
    if path and Has(texture, "SetTexture") then texture:SetTexture(path) end
    local r, g, b, a = 1, 1, 1, 1
    if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end
    texture:SetVertexColor(r, g, b, a)
end

local function Normal(button)
    return Has(button, "GetNormalTexture") and button:GetNormalTexture() or nil
end

local function PaintThumb(thumb, color)
    if not (Has(thumb, "SetSize") and Has(thumb, "GetSize")) then return end
    thumbSize = thumbSize or { thumb:GetSize() }
    if color and Has(thumb, "SetColorTexture") then
        thumb:SetColorTexture(color[1], color[2], color[3], color[4])
        thumb:SetSize(THUMB_W, THUMB_H)
    else
        thumb:SetSize(thumbSize[1], thumbSize[2])
    end
end

local function PaintChrome()
    local theme = ActiveTheme()
    local color = theme and type(theme.chromeColor) == "table" and theme.chromeColor or nil
    if not color and not chromeTinted then return end
    chromeTinted = color ~= nil
    local frame = _G.RXPFrame
    local grip = Normal(Dig(frame, "Footer", "icon"))
    if Has(grip, "GetTexture") then gripOriginal = gripOriginal or grip:GetTexture() end
    Skin(Normal(Dig(frame, "Footer", "cog")), color and COG, color)
    Skin(grip, color and GRIP or gripOriginal, color)
    local bar = Dig(frame, "ScrollFrame", "ScrollBar")
    PaintThumb(Has(bar, "GetThumbTexture") and bar:GetThumbTexture() or nil, color)
    for _, name in ipairs(ARROWS) do
        for _, part in ipairs(ARROW_PARTS) do
            local texture = Dig(bar, name, part)
            if Has(texture, "SetAlpha") then texture:SetAlpha(color and 0 or 1) end
        end
    end
end

local function HookChrome()
    local frame = _G.RXPFrame
    if Has(frame, "UpdateScrollBar") then hooksecurefunc(frame, "UpdateScrollBar", PaintChrome) end
    PaintChrome()
end

local rules = setmetatable({}, { __mode = "k" })
local ruleTheme, ruleRows

local function PaintRules()
    local list = Dig(_G.RXPFrame, "ScrollChild", "framePool")
    if type(list) ~= "table" then return end
    local theme = ActiveTheme()
    if theme == ruleTheme and #list == ruleRows then return end
    ruleTheme, ruleRows = theme, #list
    local color = theme and theme.dividerColor
    if type(color) ~= "table" then color = nil end
    for _, row in ipairs(list) do
        local rule = rules[row]
        if color and not rule and Has(row, "CreateTexture") then
            rule = row:CreateTexture(nil, "ARTWORK")
            rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -RULE_DROP)
            rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -RULE_DROP)
            rule:SetHeight(RULE_H)
            rules[row] = rule
        end
        if rule and color then
            rule:SetColorTexture(color[1], color[2], color[3], color[4])
            rule:Show()
        elseif rule then
            rule:Hide()
        end
    end
end

local function HookRules()
    local rxp = _G.RXP
    if Has(rxp, "SetStep") then hooksecurefunc(rxp, "SetStep", PaintRules) end
    PaintRules()
end

local function OnBootEvent(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ns.MODULE_KEY then return end
        self:UnregisterEvent("ADDON_LOADED")
        if ns.RXPThemesEnabled() and ns.RXPThemesAvailable() then
            Register()
            self:RegisterEvent("PLAYER_LOGIN")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        Reload()
    else
        self:UnregisterAllEvents()
        if late then Resume() end
        HookArrow()
        HookBars()
        HookChrome()
        HookRules()
    end
end

boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", OnBootEvent)
