-- WindowSettings.lua: what the RestedXP window can be changed in: its options, its colors and its theme.
local ns = _G.NaowhForever
local F = ns.FEATURES.account
local Dig = ns.RXPSafe.Dig

local WIDTH_MIN, WIDTH_MAX, WIDTH_STEP, DEFAULT_WIDTH = 260, 640, 1, 380
local SCALE_MIN, SCALE_MAX, SCALE_STEP, DEFAULT_SCALE = 60, 200, 5, 100
local STEPS_MIN, STEPS_MAX, DEFAULT_STEPS = 0, 12, 6
local PERCENT, ROUND, CHANNEL_MAX = 100, 0.5, 255
local PANEL_ALPHA, EDGE_ALPHA, RULE_ALPHA, MUTED_ALPHA = 0.92, 0.8, 0.5, 0.9
local BOX_OPACITY = 55
local TEXT_GRADIENT = "Naowh Gradient"
local COLORS_KEY, THEME_KEY = "rxpWindowColors", "rxpWindowTheme"
local CUSTOM, FOLLOW, FOREVER = "custom", "", "forever"
local BLACK = { r = 0, g = 0, b = 0 }

local OUTLINES = { shadow = "Shadow", outline = "Outline", thick = "Thick Outline", slug = "Slug Outline", none = "None" }
local SKIPS = { shift = "Shift-click", click = "Click", off = "Off" }
local LINES = { bar = "Progress Bar", rule = "Line", none = "Nothing" }
local OPTIONS = {
    { key = "rxpWindowFont", group = "Text", kind = "font", label = "Window Font",
      tip = "The face of every text in the window." },
    { key = "rxpWindowOutline", group = "Text", kind = "choice", label = "Text Outline", default = "shadow",
      values = OUTLINES, order = { "shadow", "outline", "thick", "slug", "none" },
      tip = "How the text is kept readable over the world." },
    { key = "rxpWindowTitleSize", group = "Text", kind = "number", label = "Title Size", default = 16, min = 10,
      max = 28, tip = "The guide's name and its progress." },
    { key = "rxpWindowTextSize", group = "Text", kind = "number", label = "Step Text Size", default = 13, min = 8,
      max = 24, tip = "The active step." },
    { key = "rxpWindowListSize", group = "Text", kind = "number", label = "List Text Size", default = 12, min = 8,
      max = 24, tip = "The steps after the active one." },
    { key = "rxpWindowLine", group = "Look", kind = "choice", label = "Under the Title", default = "bar",
      values = LINES, order = { "bar", "rule", "none" }, tip = "A progress bar of the guide, a line, or nothing." },
    { key = "rxpWindowSkip", group = "Look", kind = "choice", label = "Skipping Steps", default = "shift",
      values = SKIPS, order = { "shift", "click", "off" },
      tip = "What it takes to click the active step to skip it, or a step of the list to go to it." },
    { key = "rxpWindowTips", group = "Look", kind = "toggle", label = "Show Tooltips", default = true,
      tip = "What a click on a step does, said when the mouse is over it." },
    { key = "rxpWindowScrollBar", group = "Look", kind = "toggle", label = "Show Scroll Bar", default = false,
      tip = "A thin bar at the edge of the list that shows how far it is scrolled." },
    { key = "rxpWindowLock", group = "Look", kind = "toggle", label = "Lock Window", default = false,
      tip = "The window cannot be moved or resized." },
    { key = "rxpWindowPanel", group = "Look", kind = "toggle", label = "Window Background", default = false,
      tip = "A panel behind the whole window." },
    { key = "rxpWindowBorder", group = "Look", kind = "toggle", label = "Window Border", default = false,
      tip = "A border round the whole window." },
    { key = "rxpWindowBoxBorder", group = "Look", kind = "toggle", label = "Step Box Border", default = true,
      tip = "A border round the active step." },
    { key = "rxpWindowBoxBorderSize", group = "Look", kind = "number", label = "Step Box Border Size", default = 1,
      min = 1, max = 4, tip = "How thick the border round the active step is." },
    { key = "rxpWindowBoxOpacity", group = "Look", kind = "number", label = "Step Box Opacity",
      default = BOX_OPACITY, min = 0, max = PERCENT, tip = "How solid the background of the active step is." },
    { key = "rxpWindowSpacing", group = "Look", kind = "number", label = "Spacing", default = 5, min = 0, max = 12,
      tip = "The room between the rows." },
    { key = "rxpWindowBarTexture", group = "Progress", kind = "texture", label = "Bar Texture",
      defaultLabel = TEXT_GRADIENT, tip = "The texture of the progress bars, the Naowh Gradient to start." },
    { key = "rxpWindowBarBorderSize", group = "Progress", kind = "number", label = "Bar Border Size", default = 1,
      min = 0, max = 4, tip = "How thick the border round the progress bars is, or none." },
}

local COLORS = {
    { name = "title", label = "Title Color", token = "fg", tip = "The guide's name and its percent." },
    { name = "accent", label = "Accent Color", token = "accent",
      tip = "The level range, the step count, STEP and its number, and the icons." },
    { name = "text", label = "Step Text Color", token = "fg", tip = "The rows of the active step." },
    { name = "muted", label = "Muted Text Color", token = "muted", alpha = MUTED_ALPHA,
      tip = "A row that is done and the steps after the active one." },
    { name = "line", label = "Line Color", token = "fg", alpha = RULE_ALPHA, tip = "The line and the bars' track." },
    { name = "box", label = "Step Box Color", token = "bg", opaque = true,
      tip = "Behind the active step; its opacity is its own setting." },
    { name = "border", label = "Border Color", token = "line", alpha = EDGE_ALPHA, tip = "Round the whole window." },
    { name = "boxBorder", label = "Step Box Border Color", edge = true, always = true,
      tip = "Round the active step and the two windows that follow its look, black in the Naowh theme." },
    { name = "barFill", label = "Bar Color", follows = "accent", always = true,
      tip = "The filled part of the progress bars, the Accent Color to start." },
    { name = "barBack", label = "Bar Background Color", follows = "line", always = true,
      tip = "Behind the filled part of the progress bars, the Line Color to start." },
    { name = "barBorder", label = "Bar Border Color", edge = true, always = true,
      tip = "Round the progress bars, black in the Naowh theme." },
    { name = "panel", label = "Window Color", token = "panel", alpha = PANEL_ALPHA, tip = "Behind the whole window." },
    { name = "arrow", label = "Arrow Color", token = "accent", tip = "RestedXP's waypoint arrow." },
}

local OPTION_BY_KEY, COLOR_BY_NAME = {}, {}
for _, option in ipairs(OPTIONS) do OPTION_BY_KEY[option.key] = option end
for _, color in ipairs(COLORS) do COLOR_BY_NAME[color.name] = color end

local function Settings()
    return ns.AccountSettings()
end

local function Snap(value, lo, hi, step)
    return math.min(hi, math.max(lo, math.floor(value / step + ROUND) * step))
end

local function Changed()
    ns.RXPWindowRefresh()
end

local function IsPreset(key)
    return ns.THEME_PRESETS[key] ~= nil
end

local function IsTheme(key)
    return key == CUSTOM or key == FOREVER or IsPreset(key)
end

local function Hex(r, g, b)
    return ("%02x%02x%02x"):format(math.floor(r * CHANNEL_MAX + ROUND), math.floor(g * CHANNEL_MAX + ROUND),
        math.floor(b * CHANNEL_MAX + ROUND))
end

function ns.RXPWindowEnabled()
    local on = ns.AccountSettings().rxpWindow
    if on == nil then return F.rxpWindow end
    return on == true
end

function ns.RXPWindowWidthRange() return WIDTH_MIN, WIDTH_MAX, WIDTH_STEP end

function ns.RXPWindowStepsRange() return STEPS_MIN, STEPS_MAX, 1 end

function ns.RXPWindowScaleRange() return SCALE_MIN, SCALE_MAX, SCALE_STEP end

function ns.RXPWindowScale()
    local scale = tonumber(Settings().rxpWindowScale)
    return scale and Snap(scale, SCALE_MIN, SCALE_MAX, SCALE_STEP) or DEFAULT_SCALE
end

function ns.RXPWindowWidth()
    local width = tonumber(Settings().rxpWindowWidth)
    return width and Snap(width, WIDTH_MIN, WIDTH_MAX, WIDTH_STEP) or DEFAULT_WIDTH
end

function ns.RXPWindowSteps()
    local steps = tonumber(Settings().rxpWindowSteps)
    return steps and Snap(steps, STEPS_MIN, STEPS_MAX, 1) or DEFAULT_STEPS
end

function ns.RXPWindowOptions() return OPTIONS end

function ns.RXPWindowColors() return COLORS end

function ns.RXPWindowOption(key)
    local option = OPTION_BY_KEY[key]
    if not option then return nil end
    local value = Settings()[key]
    if option.kind == "number" then
        local number = tonumber(value)
        return number and Snap(number, option.min, option.max, 1) or option.default
    elseif option.kind == "toggle" then
        if value == nil then return option.default end
        return value == true
    elseif option.kind == "choice" then
        return option.values[value] and value or option.default
    end
    return type(value) == "string" and value or ""
end

function ns.SetRXPWindowOption(key, value)
    local option = OPTION_BY_KEY[key]
    if not option then return end
    local store
    if option.kind == "number" then
        local number = tonumber(value)
        number = number and Snap(number, option.min, option.max, 1)
        store = number ~= option.default and number or nil
    elseif option.kind == "toggle" then
        local on = value and true or false
        if on ~= option.default then store = on end
    elseif option.kind == "choice" then
        store = option.values[value] and value ~= option.default and value or nil
    else
        store = type(value) == "string" and value ~= "" and value or nil
    end
    Settings()[key] = store
    Changed()
end

function ns.SetRXPWindowWidth(width)
    width = tonumber(width)
    width = width and Snap(width, WIDTH_MIN, WIDTH_MAX, WIDTH_STEP)
    Settings().rxpWindowWidth = width ~= DEFAULT_WIDTH and width or nil
    Changed()
end

function ns.RXPWindowStoreScale(scale)
    scale = tonumber(scale)
    scale = scale and Snap(scale, SCALE_MIN, SCALE_MAX, SCALE_STEP)
    Settings().rxpWindowScale = scale ~= DEFAULT_SCALE and scale or nil
end

function ns.SetRXPWindowSteps(steps)
    steps = tonumber(steps)
    steps = steps and Snap(steps, STEPS_MIN, STEPS_MAX, 1)
    Settings().rxpWindowSteps = steps ~= DEFAULT_STEPS and steps or nil
    Changed()
end

function ns.RXPWindowThemeKey()
    local key = Settings()[THEME_KEY]
    if IsTheme(key) then return key end
    return FOLLOW
end

function ns.SetRXPWindowTheme(key)
    Settings()[THEME_KEY] = IsTheme(key) and key or nil
    Changed()
    ns.RXPPaintArrow()
end

function ns.RXPWindowOwnColors()
    return ns.RXPWindowThemeKey() == CUSTOM
end

function ns.RXPWindowForeverTheme()
    return ns.RXPWindowThemeKey() == FOREVER
end

function ns.RXPWindowInForever()
    local key = ns.RXPWindowThemeKey()
    return key == FOREVER or (key == FOLLOW and ns.foreverSkin == true)
end

local function ThemedEdge()
    local key = ns.RXPWindowThemeKey()
    local source = (key == FOREVER and ns.FOREVER_SKIN) or (IsPreset(key) and ns.THEME_PRESETS[key]) or nil
    if source then return source.line end
    if ns.foreverSkin or ns.ThemePresetKey() ~= "" then return ns.THEME.line end
    return BLACK
end

function ns.RXPWindowColor(name)
    local color = COLOR_BY_NAME[name]
    if not color then return 1, 1, 1, 1 end
    local saved = (color.always or ns.RXPWindowOwnColors()) and Dig(Settings(), COLORS_KEY, name)
    if saved then return saved.r, saved.g, saved.b, saved.a end
    if color.follows then return ns.RXPWindowColor(color.follows) end
    if color.edge then
        local line = ThemedEdge()
        return line.r, line.g, line.b, color.alpha or 1
    end
    local key = ns.RXPWindowThemeKey()
    local source = (key == FOREVER and ns.FOREVER_SKIN) or (IsPreset(key) and ns.THEME_PRESETS[key]) or nil
    local base = source and source[color.token] or ns.THEME[color.token]
    return base.r, base.g, base.b, color.alpha or 1
end

function ns.SetRXPWindowColor(name, r, g, b, a)
    if not COLOR_BY_NAME[name] then return end
    local all = Settings()[COLORS_KEY]
    if type(all) ~= "table" then
        all = {}
        Settings()[COLORS_KEY] = all
    end
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        local solid = COLOR_BY_NAME[name].opaque or type(a) ~= "number"
        all[name] = { r = r, g = g, b = b, a = solid and 1 or a }
    else
        all[name] = nil
    end
    if next(all) == nil then Settings()[COLORS_KEY] = nil end
    Changed()
    ns.RXPPaintArrow()
end

function ns.RXPWindowTint(name, text)
    local r, g, b = ns.RXPWindowColor(name)
    return "|cff" .. Hex(r, g, b) .. text .. "|r"
end

function ns.ResetRXPWindowStyle()
    for _, option in ipairs(OPTIONS) do Settings()[option.key] = nil end
    Settings()[COLORS_KEY] = nil
    Settings()[THEME_KEY] = nil
    Changed()
    ns.RXPPaintArrow()
end
