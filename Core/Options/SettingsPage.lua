-- SettingsPage.lua: the options window's Settings page: modules, minimap icons, scale, fonts, colors, RestedXP.
local ns = _G.NaowhForever
local UI = ns.UI
local O = ns.Options

local MODULES, Loaded, NameList = O.MODULES, O.Loaded, O.NameList
local ModuleOn, SetModuleOn, MinimapButtonOn = O.ModuleOn, O.SetModuleOn, O.MinimapButtonOn

local DEFAULT_SCALE = 100
local SCALE_VALUES = { [200] = "200%", [190] = "190%", [180] = "180%", [170] = "170%",
    [160] = "160%", [150] = "150%", [140] = "140%", [130] = "130%",
    [120] = "120%", [110] = "110%", [100] = "100%  (default)", [90] = "90%",
    [80] = "80%", [70] = "70%", [60] = "60%", [50] = "50%" }
local SCALE_ORDER = { 200, 190, 180, 170, 160, 150, 140, 130, 120, 110, 100, 90, 80, 70, 60, 50 }
local CUSTOM = "custom"
local SKIN_FOREVER = "forever"
local DEFAULT_START = "default"
local AUTO = "auto"
local MINIMAP_NAME = "NaowhForever"
local SWATCHES = { { "bg", "Background", "panel", "Panels" }, { "line", ns.L("Borders & Lines"), "fg", "Text" },
    { "muted", ns.L("Secondary Text"), "accent", "Accent" } }
local TEXT_SWITCHES_WITH = ns.L("|n|nSwitches with %s.")
local TEXT_NAOWH_DEFAULT = ns.L("Naowh (default)")
local TEXT_BLIZZARD_DEFAULT = ns.L("Blizzard Default")
local TEXT_FONT_OFF = ns.L("Off (Blizzard Default)")
local TEXT_SAVED_RELOAD = ns.L(" Saved for this computer.|n|nTakes effect after a /reload.")
local TEXT_CUSTOM = ns.L("Custom")
local TEXT_CHOOSE = ns.L("Choose a theme...")
local TEXT_REPLACE = ns.L("Replace your custom colors with %s?")
local TEXT_COLORS_RELOAD = ns.L("Reload UI to apply your color changes.")
local TEXT_RXP_RELOAD = ns.L("Reload UI to apply your RestedXP changes.")
local TEXT_RXP_PICK_RELOAD = "Reload UI to pick a theme."
local TEXT_RXP_WINDOW_NEEDS = "Turn on RestedXP's Beta Features and V2 interface."
local TEXT_WINDOW_THEME_CURRENT = "Current Theme"
local TEXT_SKIN_RELOAD = ns.L("Reload UI to change the skin.")
local TEXT_SKIN_TIP = ns.L("Dresses the addon's windows as Naowh's own or WoW Forever's, after a reload.")
local TEXT_FOREVER = "Forever"
local SKINS = { [""] = TEXT_NAOWH_DEFAULT, [SKIN_FOREVER] = TEXT_FOREVER }
local SKIN_ORDER = { "", SKIN_FOREVER }
local TEXT_MINIMAP_TIP = ns.L("A minimap button that opens %s. /nf%s does the same, "
    .. "and the Top Bar can carry it too. Saved for this computer.")
local TEXT_FEATURE_TIP = ns.L("A minimap button that opens %s. Saved for this computer.")
local TEXT_TURNED_OFF = ns.L("%s is turned off, so its settings are hidden. Turn it on under Modules below.")
local NONE = {}
local TEXT_ON_ITS_OWN, TEXT_ITS_SETTINGS = ns.L("%s on its own"), ns.L("%s's settings")
local TEXT_GAME_LANGUAGE = ns.L("Game Language")
local TEXT_LANGUAGE_RELOAD = ns.L("Reload UI to switch the language.")

local colorsPending = false
local rxpPending = false

local function Empty() return { type = "label", text = "" } end

local function Rows(W, parent, y, rows)
    local _, h
    for i = 1, #rows, 2 do
        _, h = W:DualRow(parent, y, rows[i], rows[i + 1] or Empty()); y = y - h
    end
    return y
end

local function NeedsTip(mod)
    local needs = {}
    for i, addon in ipairs(mod.needs) do
        for _, other in ipairs(MODULES) do
            if other.addon == addon then needs[i] = other end
        end
    end
    return ns.L(mod.subtitle) .. TEXT_SWITCHES_WITH:format(NameList(needs))
end

local function ModuleRow(mod)
    return { type = "toggle", text = O.DisplayName(mod), module = mod,
        tooltip = mod.needs and NeedsTip(mod) or mod.subtitle,
        getValue = function()
            if not Loaded(mod) then return ns.ModuleListed(mod.addon) end
            return ModuleOn(mod)
        end,
        setValue = function(v) SetModuleOn(mod, v) end }
end

local function SearchHit(title, rows)
    local filter = UI.filter
    if not filter then return false end
    local Mark = UI.Search.Mark
    local shown = ns.L(title)
    if Mark(filter, shown) ~= shown then return true end
    for _, row in ipairs(rows) do
        if Mark(filter, row.text) ~= row.text then return true end
        for _, mod in ipairs(filter.off or NONE) do
            if row.module == mod then return true end
        end
    end
    return false
end

local function FoldedRows(W, parent, y, title, rows)
    local _, h = W:FoldHeader(parent, title, y, SearchHit(title, rows)); y = y - h
    return Rows(W, parent, y, rows)
end

local function ModulesSection(W, parent, y)
    local rows = {}
    for _, mod in ipairs(MODULES) do
        if mod.addon then rows[#rows + 1] = ModuleRow(mod) end
    end
    return FoldedRows(W, parent, y, "MODULES", rows)
end

local function ShowIcon(name, shown)
    local icon = LibStub("LibDBIcon-1.0")
    if shown then icon:Show(name) else icon:Hide(name) end
end

local function SetModuleButton(mod, v)
    local account = ns.AccountSettings()
    account.microMenu = account.microMenu or { buttons = {} }
    account.microMenu.buttons[mod.name] = v
    account.moduleButtons[mod.name].hide = not v
    ShowIcon(MINIMAP_NAME .. mod.short, v)
end

local function ModuleButtonRow(mod)
    return { type = "toggle", text = mod.name,
        tooltip = TEXT_MINIMAP_TIP:format((mod.open and TEXT_ON_ITS_OWN or TEXT_ITS_SETTINGS):format(O.DisplayName(mod)),
            mod.command),
        getValue = function() return MinimapButtonOn(mod) end,
        setValue = function(v) SetModuleButton(mod, v) end }
end

local function FeatureButtonRow(feature)
    return { type = "toggle", text = feature.name,
        tooltip = TEXT_FEATURE_TIP:format(ns.L(feature.name)),
        getValue = function() return ns.MinimapFeatureOn(feature) end,
        setValue = function(v) ns.SetMinimapFeature(feature, v) end }
end

local function MinimapShown()
    local mm = ns.AccountSettings().minimap
    return not (type(mm) == "table" and mm.hide)
end

local function SetMinimapShown(v)
    ns.AccountSettings().minimap.hide = not v
    ShowIcon(MINIMAP_NAME, v)
end

local function GameMenuButtonOn()
    local on = ns.AccountSettings().gameMenuButton
    if on == nil then return ns.FEATURES.account.gameMenuButton end
    return on ~= false
end

local function MinimapSection(W, parent, y)
    local rows = {
        { type = "toggle", text = "Minimap Button",
          tooltip = "The Naowh Forever button on the minimap. The addon compartment entry "
          .. "and /naowh open this window either way.",
          getValue = MinimapShown,
          setValue = SetMinimapShown },
        { type = "toggle", text = "Game Menu Button",
          tooltip = "Naowh Forever in the game menu (Esc), by the other addons' buttons. "
          .. "Saved for this computer. Not shown with a gamepad; use /nf.",
          getValue = GameMenuButtonOn,
          setValue = function(v) ns.AccountSettings().gameMenuButton = v and true or false end },
    }
    for _, mod in ipairs(MODULES) do
        if mod.command and Loaded(mod) then rows[#rows + 1] = ModuleButtonRow(mod) end
    end
    for _, feature in ipairs(ns.MinimapFeatures) do rows[#rows + 1] = FeatureButtonRow(feature) end
    return FoldedRows(W, parent, y, "MINIMAP ICONS", rows)
end

local LANGUAGE_VALUES, LANGUAGE_ORDER = (function()
    local values, order = { [AUTO] = TEXT_GAME_LANGUAGE }, { AUTO }
    for _, code in ipairs(ns.LANGUAGES) do
        values[code] = ns.L(ns.LANGUAGE_NAMES[code])
        order[#order + 1] = code
    end
    return UI.KeepMissing(values, order, ns.LANGUAGE_PICK)
end)()

local function WindowSection(W, parent, y)
    local _, h = W:SectionHeader(parent, "OPTIONS WINDOW", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Window Scale", values = SCALE_VALUES, order = SCALE_ORDER,
          tooltip = "Size of this options window and the editors it opens, as a percentage. "
          .. "This window never grows past your screen, so above that size a higher setting "
          .. "only enlarges the editors.|n|nSaved for this computer instead of in the profile, so switching "
          .. "profile leaves it alone.",
          getValue = function() return tonumber(ns.AccountSettings().windowScale) or DEFAULT_SCALE end,
          setValue = function(v) ns.SetWindowScale(v) end },
        { type = "dropdown", text = "Language", values = LANGUAGE_VALUES, order = LANGUAGE_ORDER,
          tooltip = "The language of this addon. Game Language follows your game client. Saved for this "
          .. "computer.|n|nTakes effect after a /reload.",
          getValue = function() return ns.AccountSettings().language or AUTO end,
          setValue = function(v)
              ns.AccountSettings().language = v ~= AUTO and v or nil
              ns.ConfirmReload(TEXT_LANGUAGE_RELOAD)
          end }
    )
    return y - h
end

local function GameFontDropdown(text, key, tooltip)
    local saved = ns.AccountSettings()[key]
    if saved == ns.BLIZZARD_FONT then saved = nil end
    local fonts, order = UI.FontChoices(saved)
    fonts[""] = TEXT_FONT_OFF
    return { type = "dropdown", text = text, values = fonts, order = order,
        tooltip = tooltip .. TEXT_SAVED_RELOAD,
        getValue = function()
            local v = ns.AccountSettings()[key]
            return (v == nil or v == ns.BLIZZARD_FONT) and "" or v
        end,
        setValue = function(v)
            ns.AccountSettings()[key] = v ~= "" and v or nil
        end }
end

local function AddonFontChoices()
    local uiFonts, uiFontOrder = UI.FontChoices(ns.AccountSettings().uiFont)
    uiFonts[""] = TEXT_NAOWH_DEFAULT
    uiFonts[ns.BLIZZARD_FONT] = TEXT_BLIZZARD_DEFAULT
    table.insert(uiFontOrder, 2, ns.BLIZZARD_FONT)
    return uiFonts, uiFontOrder
end

local function FontSection(W, parent, y)
    local _, h = W:SectionHeader(parent, "FONT", y); y = y - h
    local uiFonts, uiFontOrder = AddonFontChoices()
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Addon Font", values = uiFonts, order = uiFontOrder,
          tooltip = "The font for this addon's windows and HUD. Font settings on a feature "
          .. "use it unless they pick their own. Saved for this computer.|n|nTakes effect "
          .. "after a /reload.",
          getValue = function() return ns.AccountSettings().uiFont or "" end,
          setValue = function(v)
              ns.AccountSettings().uiFont = v ~= "" and v or nil
          end },
        GameFontDropdown("Game Font", "gameFont", ns.L("The font for the rest of the game: menus, "
            .. "chat, tooltips and names. Off leaves the game's own fonts alone."))
    ); y = y - h
    _, h = W:DualRow(parent, y,
        GameFontDropdown("Combat Text Font", "combatFont", ns.L("The font for damage and healing "
            .. "numbers, over enemies and over your character. Off leaves the game's own "
            .. "font alone.")),
        Empty()
    )
    return y - h
end

local function ThemeChoices()
    local themes, themeOrder = { [""] = TEXT_NAOWH_DEFAULT }, { "" }
    for _, key in ipairs(ns.THEME_PRESET_ORDER) do
        themes[key] = ns.THEME_PRESETS[key].name
        themeOrder[#themeOrder + 1] = key
    end
    themes.custom = TEXT_CUSTOM
    themeOrder[#themeOrder + 1] = CUSTOM
    return themes, themeOrder
end

local function StartChoices()
    local starts, startOrder = { [""] = TEXT_CHOOSE, default = TEXT_NAOWH_DEFAULT }, { "", DEFAULT_START }
    for _, key in ipairs(ns.THEME_PRESET_ORDER) do
        starts[key] = ns.THEME_PRESETS[key].name
        startOrder[#startOrder + 1] = key
    end
    return starts, startOrder
end

local function ColorsChanged()
    colorsPending = true
    ns.MarkReloadRequired(TEXT_COLORS_RELOAD)
    UI:RefreshPage(true)
end

local function MarkColorsPending()
    if colorsPending then return end
    ColorsChanged()
end

local function Swatch(key, text)
    return { type = "colorpicker", text = text, hasAlpha = false,
        getValue = function() return ns.ThemeSwatchColor(key) end,
        setValue = function(r, g, b)
            local account = ns.AccountSettings()
            if type(account.themeColors) ~= "table" then account.themeColors = {} end
            account.themeColors[key] = { r = r, g = g, b = b }
            MarkColorsPending()
        end }
end

local function StartFrom(starts, v)
    if v == "" then return end
    ns.Confirm(TEXT_REPLACE:format(starts[v]), function()
        ns.CopyThemeToCustom(v ~= DEFAULT_START and v or "")
        ColorsChanged()
    end)
end

local function CustomRows(W, parent, y)
    local starts, startOrder = StartChoices()
    local _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Start From", values = starts, order = startOrder,
          tooltip = "Replace your custom colors with the colors of a theme, then adjust "
          .. "them below. Picking Naowh (default) is a reset.",
          getValue = function() return "" end,
          setValue = function(v) StartFrom(starts, v) end },
        Empty()
    ); y = y - h
    for _, pair in ipairs(SWATCHES) do
        _, h = W:DualRow(parent, y, Swatch(pair[1], pair[2]), Swatch(pair[3], pair[4])); y = y - h
    end
    return y
end

local function SkinColors()
    return ns.AccountSettings().skin == SKIN_FOREVER
end

local function SkinRow()
    return { type = "dropdown", text = "Skin", values = SKINS, order = SKIN_ORDER, tooltip = TEXT_SKIN_TIP,
        getValue = function() return ns.AccountSettings().skin or "" end,
        setValue = function(v)
            ns.AccountSettings().skin = v ~= "" and v or nil
            ColorsChanged()
            ns.ConfirmReload(TEXT_SKIN_RELOAD)
        end }
end

local function ThemeRow(themes, themeOrder)
    return { type = "dropdown", text = "Theme", values = themes, order = themeOrder,
        tooltip = "Theme presets for the addon's windows and HUD frames, plus a Custom "
        .. "option for your own colors. If text gets hard to read, pick Naowh (default). "
        .. "Saved for this computer.|n|nTakes effect after a /reload.",
        getValue = ns.ThemePresetKey,
        disabled = SkinColors,
        palette = function()
            local colors = ns.ThemePalette(ns.ThemePresetKey())
            return { colors[1], colors[math.floor(#colors / 2) + 1], colors[#colors] }
        end,
        setValue = function(v)
            ns.SetThemePreset(v)
            ColorsChanged()
        end }
end

local function ColorsSection(W, parent, y)
    local _, h = W:SectionHeader(parent, "COLORS", y); y = y - h
    _, h = W:DualRow(parent, y, SkinRow(), ThemeRow(ThemeChoices())); y = y - h
    if ns.ThemePresetKey() == CUSTOM and not SkinColors() then y = CustomRows(W, parent, y) end
    if colorsPending then
        _, h = W:Note(parent, TEXT_COLORS_RELOAD, y); y = y - h
    end
    return y
end

local function RxpChanged()
    rxpPending = true
    ns.MarkReloadRequired(TEXT_RXP_RELOAD)
    UI:RefreshPage(true)
end

local function RxpSwitch(text, tooltip, get, set)
    return { type = "toggle", text = text, tooltip = tooltip,
        getValue = get,
        setValue = function(v)
            set(v)
            RxpChanged()
        end }
end

local function RxpThemeChoice()
    if not ns.RXPThemesEnabled() then return Empty() end
    local choices, choiceOrder = ns.RXPThemeChoices()
    if not ns.RXPThemesReady() then return { type = "label", text = TEXT_RXP_PICK_RELOAD } end
    return { type = "dropdown", text = "RestedXP Theme", values = choices,
        order = choiceOrder, tooltip = "The theme RestedXP uses: its own, or one of the Naowh themes.",
        getValue = ns.RXPThemeChoice,
        setValue = function(v)
            if ns.SetRXPThemeChoice(v) == "reload" then RxpChanged() end
        end }
end

local function ArrowStyleRow(image)
    return { type = "dropdown", text = "RestedXP Arrow",
          values = { layer = "Colored layer", image = "Naowh arrow", off = "RestedXP's own" },
          order = { "layer", "image", "off" },
          tooltip = "How RestedXP's waypoint arrow is drawn with a Naowh theme.",
          getValue = ns.RXPArrowStyle,
          setValue = function(v)
              ns.SetRXPArrowStyle(v)
              UI:RefreshPage(true)
          end },
        image and { type = "dropdown", text = "Naowh Arrow Shape",
          values = { kite = "Kite", wide = "Wide kite" },
          order = { "kite", "wide" },
          tooltip = "The shape of Naowh's arrow.",
          getValue = ns.RXPArrowShape,
          setValue = function(v) ns.SetRXPArrowShape(v) end } or Empty()
end

local function ArrowLookRow()
    local sizeMin, sizeMax, sizeStep = ns.RXPArrowSizeRange()
    return { type = "toggle", text = "Naowh Arrow Glow",
          tooltip = "A soft glow around Naowh's arrow.",
          getValue = ns.RXPArrowGlow,
          setValue = function(v) ns.SetRXPArrowGlow(v) end },
        { type = "slider", text = "Naowh Arrow Size", min = sizeMin, max = sizeMax, step = sizeStep,
          tooltip = "How big Naowh's arrow is.",
          getValue = ns.RXPArrowSize,
          setValue = function(v) ns.SetRXPArrowSize(v) end }
end

local function ArrowTextRow(image)
    local gapMin, gapMax = ns.RXPArrowGapRange()
    return { type = "toggle", text = "Show Arrow Text",
          tooltip = "The step and distance text under RestedXP's waypoint arrow.",
          getValue = ns.RXPArrowTextEnabled,
          setValue = function(v) ns.SetRXPArrowText(v) end },
        image and { type = "slider", text = "Naowh Arrow Text Gap", min = gapMin, max = gapMax, step = 1,
          tooltip = "The space between Naowh's arrow and the text under it.",
          getValue = ns.RXPArrowGap,
          setValue = function(v) ns.SetRXPArrowGap(v) end } or Empty()
end

local function ArrowObjectiveRow()
    local sizeMin, sizeMax, sizeStep = ns.RXPArrowTextSizeRange()
    return { type = "toggle", text = "Arrow Shows Objective",
          tooltip = "The objective under RestedXP's arrow, as in Talk to Duokna, in place of the step number.",
          getValue = ns.RXPArrowObjective,
          setValue = function(v) ns.SetRXPArrowObjective(v) end },
        { type = "slider", text = "Arrow Text Size", min = sizeMin, max = sizeMax, step = sizeStep,
          tooltip = "How big the text under RestedXP's arrow is.",
          getValue = ns.RXPArrowTextSize,
          setValue = function(v) ns.SetRXPArrowTextSize(v) end }
end

local function RxpThemeRows(W, parent, y)
    local _, h = W:DualRow(parent, y,
        RxpSwitch("Use Addon Font", "RestedXP's text uses your Addon Font.", ns.RXPFontEnabled, ns.SetRXPFont),
        RxpSwitch("Use Theme Text Color", "RestedXP's text uses the theme's Text color.",
            ns.RXPTextColorEnabled, ns.SetRXPTextColor)
    )
    return y - h
end

local function RxpArrowRows(W, parent, y)
    local on = ns.RXPArrowEnabled()
    local _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Style RestedXP's Arrow",
          tooltip = "The waypoint arrow in a look of its own, whatever theme or window is used.",
          getValue = ns.RXPArrowEnabled,
          setValue = function(v)
              ns.SetRXPArrow(v)
              UI:RefreshPage(true)
          end },
        Empty()
    ); y = y - h
    if not on then return y end
    local image = ns.RXPArrowStyle() == "image"
    _, h = W:DualRow(parent, y, ArrowStyleRow(image)); y = y - h
    if image then
        _, h = W:DualRow(parent, y, ArrowLookRow()); y = y - h
    end
    _, h = W:DualRow(parent, y, ArrowTextRow(image)); y = y - h
    _, h = W:DualRow(parent, y, ArrowObjectiveRow()); y = y - h
    _, h = W:DualRow(parent, y,
        RxpSwitch("Arrow Addon Font", "The text under the arrow uses your Addon Font.", ns.RXPArrowFontEnabled,
            ns.SetRXPArrowFont),
        Empty()
    )
    return y - h
end

local function WindowOptionCell(option)
    local key = option.key
    local function Get() return ns.RXPWindowOption(key) end
    local function Set(v) ns.SetRXPWindowOption(key, v) end
    if option.kind == "toggle" then
        return { type = "toggle", text = option.label, tooltip = option.tip, getValue = Get, setValue = Set }
    elseif option.kind == "number" then
        return { type = "slider", text = option.label, min = option.min, max = option.max, step = 1,
          tooltip = option.tip, getValue = Get, setValue = Set }
    elseif option.kind == "choice" then
        return { type = "dropdown", text = option.label, values = option.values, order = option.order,
          tooltip = option.tip, getValue = Get, setValue = Set }
    elseif option.kind == "font" then
        local values, order = UI.FontChoices(Get())
        return { type = "dropdown", text = option.label, values = values, order = order, tooltip = option.tip,
          getValue = Get, setValue = Set }
    end
    local values, order = UI.TextureChoices(Get(), option.defaultLabel)
    return { type = "dropdown", text = option.label, values = values, order = order, tooltip = option.tip,
      getValue = Get, setValue = Set }
end

local function WindowColorCell(color)
    local name = color.name
    return { type = "colorpicker", text = color.label, hasAlpha = not color.opaque, tooltip = color.tip,
      getValue = function() return ns.RXPWindowColor(name) end,
      setValue = function(r, g, b, a) ns.SetRXPWindowColor(name, r, g, b, a) end }
end

local function IconStyleRow()
    return { type = "dropdown", text = "Step Icons",
        values = { [""] = "RestedXP's own", line = "Line", filled = "Filled" },
        order = { "", "line", "filled" },
        tooltip = "Naowh's own step icons in the accent color in place of RestedXP's, after a /reload.",
        getValue = ns.RXPIconStyle,
        setValue = function(v)
            ns.SetRXPIconStyle(v)
            RxpChanged()
        end }
end

local function WindowThemeRow()
    local values, order = { [""] = TEXT_WINDOW_THEME_CURRENT }, { "" }
    for _, key in ipairs(ns.THEME_PRESET_ORDER) do
        values[key] = ns.THEME_PRESETS[key].name
        order[#order + 1] = key
    end
    values.forever = TEXT_FOREVER
    order[#order + 1] = "forever"
    values[CUSTOM] = TEXT_CUSTOM
    order[#order + 1] = CUSTOM
    return { type = "dropdown", text = "Window Theme", values = values, order = order,
        tooltip = "The window's own theme, or the addon's current one; Custom lets you pick the colors.",
        getValue = ns.RXPWindowThemeKey,
        setValue = function(v)
            ns.SetRXPWindowTheme(v)
            UI:RefreshPage(true)
        end }
end

local function RxpWindowStyleRows(W, parent, y)
    local _, h = W:GroupHeader(parent, "WINDOW LOOK", y); y = y - h
    _, h = W:DualRow(parent, y, WindowThemeRow(), Empty()); y = y - h
    local cells = {}
    for _, group in ipairs({ "Text", "Look", "Progress" }) do
        for _, option in ipairs(ns.RXPWindowOptions()) do
            if option.group == group then cells[#cells + 1] = WindowOptionCell(option) end
        end
    end
    local own = ns.RXPWindowOwnColors()
    for _, color in ipairs(ns.RXPWindowColors()) do
        if own or color.always then cells[#cells + 1] = WindowColorCell(color) end
    end
    for i = 1, #cells, 2 do
        _, h = W:DualRow(parent, y, cells[i], cells[i + 1] or Empty()); y = y - h
    end
    _, h = W:DualRow(parent, y,
        { type = "button", text = "Window Look", buttonText = "Reset",
          tooltip = "Puts the window's text, colors and bars back as they were.",
          onClick = function()
              ns.ResetRXPWindowStyle()
              UI:RefreshPage(true)
          end },
        Empty()
    )
    return y - h
end

local function SetUpRows(W, parent, y)
    local _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Set Up New Characters",
          tooltip = "Turns on RestedXP's new interface and the Naowh theme for a character that has not been set up.",
          getValue = ns.RXPSetUpEnabled,
          setValue = function(v) ns.SetRXPSetUp(v) end },
        { type = "button", text = "This Character", buttonText = "Set Up",
          tooltip = "Turns them on for the character you are playing now.",
          onClick = function()
              if ns.RXPSetUpCharacter() == "reload" then RxpChanged() else UI:RefreshPage(true) end
          end }
    )
    return y - h
end

local function RxpWindowRows(W, parent, y)
    local on = ns.RXPWindowEnabled()
    local _, h = W:SwitchFold(parent, "RestedXP Naowh Window (V2)", y, {
        get = ns.RXPWindowEnabled,
        set = function(v)
            ns.SetRXPWindow(v)
            UI:RefreshPage(true)
        end,
        tooltip = "RestedXP's guide and active steps in one Naowh window, in place of its own and of the theme.",
        rows = on, open = UI.filter ~= nil }); y = y - h
    if not on then return y end
    y = SetUpRows(W, parent, y)
    if not ns.RXPWindowReady() then
        _, h = W:DualRow(parent, y, { type = "label", text = TEXT_RXP_WINDOW_NEEDS }, Empty()); y = y - h
    end
    local stepsMin, stepsMax, stepsStep = ns.RXPWindowStepsRange()
    local scaleMin, scaleMax, scaleStep = ns.RXPWindowScaleRange()
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "Listed Steps", min = stepsMin, max = stepsMax, step = stepsStep,
          tooltip = "How many steps the list shows at once, the rest by scrolling it.",
          getValue = ns.RXPWindowSteps,
          setValue = function(v) ns.SetRXPWindowSteps(v) end },
        { type = "slider", text = "Naowh Window Scale", min = scaleMin, max = scaleMax, step = scaleStep,
          tooltip = "How big the whole window is, its text with it.",
          getValue = ns.RXPWindowScale,
          setValue = function(v) ns.SetRXPWindowScale(v) end }
    ); y = y - h
    _, h = W:DualRow(parent, y, IconStyleRow(), Empty()); y = y - h
    y = RxpArrowRows(W, parent, y)
    y = RxpWindowStyleRows(W, parent, y)
    W:EndFold(parent)
    return y
end

local function RestedXPSection(W, parent, y)
    if not (ns.RXPThemesAvailable and ns.RXPThemesAvailable()) then return y end
    local themesOn = ns.RXPThemesEnabled()
    local themesSwitch = RxpSwitch("RestedXP Theme (V1)",
        "Adds the Naowh themes to RestedXP's theme list, in place of the Naowh window.",
        ns.RXPThemesEnabled, ns.SetRXPThemes)
    local _, h = W:SwitchFold(parent, "RestedXP Theme (V1)", y, {
        get = themesSwitch.getValue, set = themesSwitch.setValue, tooltip = themesSwitch.tooltip, rows = themesOn,
        open = UI.filter ~= nil })
    y = y - h
    if themesOn then
        _, h = W:DualRow(parent, y, RxpThemeChoice(), Empty()); y = y - h
        y = RxpThemeRows(W, parent, y)
        y = RxpArrowRows(W, parent, y)
    end
    W:EndFold(parent)
    y = RxpWindowRows(W, parent, y)
    if not (ns.RXPThemesEnabled() or ns.RXPWindowEnabled()) then
        _, h = W:SectionHeader(parent, "RESTEDXP ARROW", y); y = y - h
        y = RxpArrowRows(W, parent, y)
    end
    if rxpPending then
        _, h = W:Note(parent, TEXT_RXP_RELOAD, y); y = y - h
    end
    return y
end

local function Sections(W, parent, y)
    y = ModulesSection(W, parent, y)
    y = MinimapSection(W, parent, y)
    y = WindowSection(W, parent, y)
    y = FontSection(W, parent, y)
    y = ColorsSection(W, parent, y)
    return RestedXPSection(W, parent, y)
end

local function OffNotes(W, parent, y)
    for _, mod in ipairs(UI.filter and UI.filter.off or NONE) do
        local _, h = W:Note(parent, TEXT_TURNED_OFF:format(O.DisplayName(mod)), y); y = y - h
    end
    return y
end

function ns.BuildSettingsPage(parent, y)
    local W = UI.Widgets
    y = OffNotes(W, parent, y)
    y = Sections(W, parent, y)
    local _, h = W:ReloadButton(parent, y)
    return y - h
end

local Terms = {}
Terms.__index = Terms

function Terms:SectionHeader(_, text)
    self.section = text
    return nil, 0
end

Terms.FoldHeader = Terms.SectionHeader
Terms.GroupHeader = Terms.SectionHeader

function Terms:SwitchFold(_, text, _, cfg)
    self.section = text
    self:Take({ text = text, tooltip = cfg.tooltip })
    return nil, 0
end

function Terms:EndFold() end

function Terms:Take(row)
    if row.text == "" or row.type == "label" then return end
    local off = row.module and not Loaded(row.module) and row.module or nil
    self.add(row.text, row.tooltip, self.section, off)
end

function Terms:DualRow(_, _, left, right)
    self:Take(left)
    if right then self:Take(right) end
    return nil, 0
end

function Terms:Note()
    return nil, 0
end

function ns.SettingsSearchTerms(add)
    Sections(setmetatable({ add = add }, Terms), nil, 0)
end
