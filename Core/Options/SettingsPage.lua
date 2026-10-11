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
local SKIN_CLASSIC = "classic"
local DEFAULT_START = "default"
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
local TEXT_SKIN_TIP = ns.L("Classic+ dresses the addon's windows like the game's own, in gold and bronze. "
    .. "It has its own colors and uses the game's fonts unless you pick an Addon Font. Saved "
    .. "for this computer.|n|nTakes effect after a /reload.")
local TEXT_CLASSIC_PLUS = "Classic+"
local SKINS = { [""] = TEXT_NAOWH_DEFAULT, [SKIN_CLASSIC] = TEXT_CLASSIC_PLUS }
local SKIN_ORDER = { "", SKIN_CLASSIC }
local TEXT_MINIMAP_TIP = ns.L("A minimap button that opens %s. /nf%s does the same, "
    .. "and the Top Bar can carry it too. Saved for this computer.")
local TEXT_TURNED_OFF = ns.L("%s is turned off, so its settings are hidden. Turn it on under Modules below.")
local NONE = {}
local TEXT_ON_ITS_OWN, TEXT_ITS_SETTINGS = ns.L("%s on its own"), ns.L("%s's settings")

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
            if not Loaded(mod) then return C_AddOns.GetAddOnEnableState(mod.addon) > 0 end
            return ModuleOn(mod)
        end,
        setValue = function(v) SetModuleOn(mod, v) end }
end

local function ModulesSection(W, parent, y)
    local _, h = W:SectionHeader(parent, "MODULES", y); y = y - h
    local rows = {}
    for _, mod in ipairs(MODULES) do
        if mod.addon then rows[#rows + 1] = ModuleRow(mod) end
    end
    return Rows(W, parent, y, rows)
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
    local _, h
    _, h = W:SectionHeader(parent, "MINIMAP ICONS", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Minimap Button",
          tooltip = "The Naowh Forever button on the minimap. The addon compartment entry "
          .. "and /naowh open this window either way.",
          getValue = MinimapShown,
          setValue = SetMinimapShown },
        { type = "toggle", text = "Game Menu Button",
          tooltip = "Naowh Forever in the game menu (Esc), by the other addons' buttons. "
          .. "Saved for this computer. Not shown with a gamepad; use /nf.",
          getValue = GameMenuButtonOn,
          setValue = function(v) ns.AccountSettings().gameMenuButton = v and true or false end }
    ); y = y - h
    local rows = {}
    for _, mod in ipairs(MODULES) do
        if mod.command and Loaded(mod) then rows[#rows + 1] = ModuleButtonRow(mod) end
    end
    return Rows(W, parent, y, rows)
end

local function WindowSection(W, parent, y)
    local _, h = W:SectionHeader(parent, "OPTIONS WINDOW", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Window Scale", values = SCALE_VALUES, order = SCALE_ORDER,
          tooltip = "Size of this options window and the editors it opens, as a percentage. "
          .. "This window never grows past your screen, so above that size a higher setting "
          .. "only enlarges the editors.|n|nSaved for this computer instead of in the profile, so switching "
          .. "profile leaves it alone.",
          getValue = function() return tonumber(ns.AccountSettings().windowScale) or DEFAULT_SCALE end,
          setValue = function(v) ns.SetWindowScale(v) end }
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

local function ClassicSkin()
    return ns.AccountSettings().skin == SKIN_CLASSIC
end

local function SkinRow()
    return { type = "dropdown", text = "Skin", values = SKINS, order = SKIN_ORDER, tooltip = TEXT_SKIN_TIP,
        getValue = function() return ns.AccountSettings().skin or "" end,
        setValue = function(v)
            ns.AccountSettings().skin = v ~= "" and v or nil
            ColorsChanged()
        end }
end

local function ColorsSection(W, parent, y)
    local _, h = W:SectionHeader(parent, "COLORS", y); y = y - h
    _, h = W:DualRow(parent, y, SkinRow(), Empty()); y = y - h
    local themes, themeOrder = ThemeChoices()
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Theme", values = themes, order = themeOrder,
          tooltip = "Theme presets for the addon's windows and HUD frames, plus a Custom "
          .. "option for your own colors. If text gets hard to read, pick Naowh (default). "
          .. "Saved for this computer.|n|nTakes effect after a /reload.",
          getValue = ns.ThemePresetKey,
          disabled = ClassicSkin,
          setValue = function(v)
              ns.SetThemePreset(v)
              ColorsChanged()
          end },
        { type = "palette", text = "", colors = function() return ns.ThemePalette(ns.ThemePresetKey()) end }
    ); y = y - h
    if ns.ThemePresetKey() == CUSTOM and not ClassicSkin() then y = CustomRows(W, parent, y) end
    if colorsPending then
        _, h = W:Note(parent, TEXT_COLORS_RELOAD, y); y = y - h
    end
    return y
end

local function RxpChanged()
    rxpPending = true
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

local function RxpThemeRows(W, parent, y)
    local image = ns.RXPArrowStyle() == "image"
    local _, h = W:DualRow(parent, y, ArrowStyleRow(image)); y = y - h
    if image then
        _, h = W:DualRow(parent, y, ArrowLookRow()); y = y - h
    end
    _, h = W:DualRow(parent, y, ArrowTextRow(image)); y = y - h
    _, h = W:DualRow(parent, y,
        RxpSwitch("Use Addon Font", "RestedXP's text uses your Addon Font.", ns.RXPFontEnabled, ns.SetRXPFont),
        RxpSwitch("Use Theme Text Color", "RestedXP's text uses the theme's Text color.",
            ns.RXPTextColorEnabled, ns.SetRXPTextColor)
    )
    return y - h
end

local function RestedXPSection(W, parent, y)
    if not (ns.RXPThemesAvailable and ns.RXPThemesAvailable()) then return y end
    local _, h = W:SectionHeader(parent, "RESTEDXP", y); y = y - h
    local themesSwitch = RxpSwitch("Add Themes to RestedXP", "Adds the Naowh themes to RestedXP's theme list.",
        ns.RXPThemesEnabled, ns.SetRXPThemes)
    _, h = W:DualRow(parent, y, themesSwitch, RxpThemeChoice()); y = y - h
    if ns.RXPThemesEnabled() then y = RxpThemeRows(W, parent, y) end
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
