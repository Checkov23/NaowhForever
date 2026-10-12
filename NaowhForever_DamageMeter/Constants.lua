-- Constants.lua: the sizes and names the Damage Meter's files share.
local ns = _G.NaowhForever

local MODES = {
    { key = "damage", short = "Damage", label = "Damage Done", type = "DamageDone", rate = true, total = "Damage", perSecond = "DPS",
      targets = true },
    { key = "dps", short = "DPS", label = "DPS", type = "Dps", rate = true, rateFirst = true, total = "Damage", perSecond = "DPS",
      targets = true },
    { key = "healing", short = "Healing", label = "Healing Done", type = "HealingDone", rate = true, total = "Healing", perSecond = "HPS" },
    { key = "hps", short = "HPS", label = "HPS", type = "Hps", rate = true, rateFirst = true, total = "Healing", perSecond = "HPS" },
    { key = "taken", short = "Taken", label = "Damage Taken", type = "DamageTaken", rate = true, total = "Taken", perSecond = "DTPS" },
    { key = "avoidable", short = "Avoidable", label = "Avoidable Damage", type = "AvoidableDamageTaken", rate = true, total = "Avoidable",
      perSecond = "Per Sec" },
    { key = "absorbs", short = "Absorbs", label = "Absorbs", type = "Absorbs", rate = true, total = "Absorbed", perSecond = "Per Sec" },
    { key = "interrupts", short = "Interrupts", label = "Interrupts", type = "Interrupts", rate = false, total = "Interrupts" },
    { key = "dispels", short = "Dispels", label = "Dispels", type = "Dispels", rate = false, total = "Dispels" },
    { key = "deaths", short = "Deaths", label = "Deaths", type = "Deaths", rate = false, spells = false, percent = false,
      total = "Deaths" },
}

local byKey, labels, order = {}, {}, {}
for i, mode in ipairs(MODES) do
    byKey[mode.key] = mode
    labels[mode.key] = mode.label
    order[i] = mode.key
end

ns.DamageMeter.C = {
    PAGE = "Damage Meter/Settings",
    MIN_WIDTH = 170, MIN_HEIGHT = 70, MAX_WIDTH = 1000, MAX_HEIGHT = 1000, MIN_SCALE = 50, MAX_SCALE = 200,
    MIN_BAR = 12, MAX_BAR = 40, MAX_SPACING = 12, MIN_FONT = 8, MAX_FONT = 20,
    INSET = 6, HEADER = 26, TITLE_X = 8,
    ROUND = 0.5,
    DEFAULT_MODE = "damage",
    BREAKDOWN_MAX = 15, TARGET_MAX = 10, REPORT_MAX = 10, FIGHTS_MAX = 30,
    MIN_PANEL_WIDTH = 240, MAX_PANEL_WIDTH = 480, MIN_PANEL_SCALE = 50, MAX_PANEL_SCALE = 150,
    PANEL_SIDES = { auto = "By the Window's Side on the Screen", left = "Left of the Window",
        right = "Right of the Window" },
    PANEL_SIDES_ORDER = { "auto", "left", "right" },
    TEXT_SPELLS_COMBAT = "Spells show after combat.", TEXT_SPELLS_NONE = "No spell data.",
    TEXT_RESET_ASK = "Reset the damage meter data?",
    TEXT_RESET_SETTINGS_ASK = "Put every Damage Meter setting back to its default?",
    ENEMY_COLOR = { r = 0.78, g = 0.2, b = 0.2 },
    COLUMN_HEAD = 16, SUMMARY_H = 16, LOWER_STRIP = 20, LOWER_GAP = 4,
    MIN_TITLE = 8, MAX_TITLE = 20, MAX_NAME_LETTERS = 24, MAX_PERCENT_DECIMALS = 2, MAX_ICON = 40, MAX_PAD = 20,
    NUMBER_UNITS = { game = "Game Default", latin = "K, M, B", asian = "Ten-thousands", full = "Full Numbers" },
    NUMBER_UNITS_ORDER = { "game", "latin", "asian", "full" },
    NUMBER_DECIMALS_MAX = 2, MAX_HIDE_DELAY = 60, MIN_KEEP = 5, MAX_KEEP = 100, MIN_TILE = 16, MAX_TILE = 512,
    OWN_PICTURE = "@own",
    HIDDEN_BACKGROUNDS = { ["Solid"] = true, ["Blizzard Tooltip"] = true, ["Blizzard Out of Control"] = true,
        ["Blizzard Low Health"] = true, ["None"] = true },
    BAR_COLORS = { class = "Class Colors", accent = "Theme Accent", custom = "Custom Color" },
    BAR_COLORS_ORDER = { "class", "accent", "custom" },
    RESET_ON = { never = "Never", instance = "Entering an Instance", ask = "Ask When Entering an Instance" },
    RESET_ON_ORDER = { "never", "instance", "ask" },
    ICON_SIDES = { left = "Left", right = "Right", before = "Before the Bar" },
    ICON_SIDES_ORDER = { "left", "right", "before" },
    OWN_LOOK_ORDER = { "barHeight", "barSpacing", "barAlpha", "growUp", "fontSize", "showIcons", "showRanks",
        "backgroundAlpha", "headerAlpha", "showBorder", "barColor", "columns", "showDivider",
        "showColumnHeaders" },
    OWN_LOOK_COLUMNS = { columns = true, showDivider = true, showColumnHeaders = true },
    BAR_SCALES = { top = "Top Player", total = "List Total" },
    BAR_SCALES_ORDER = { "top", "total" },
    OWN_BAR_STYLES = { bar = "Same as Bar Color", class = "Class Color", custom = "Custom Color" },
    OWN_BAR_STYLES_ORDER = { "bar", "class", "custom" },
    EDGE_STYLES = { accent = "Theme Accent", class = "Class Color", custom = "Custom Color" },
    EDGE_STYLES_ORDER = { "accent", "class", "custom" },
    NAME_FORMATS = { full = "Full Name", first = "First Name", last = "Last Name", initials = "Initials",
        firstInitial = "First Name and Initial" },
    NAME_FORMATS_ORDER = { "full", "first", "last", "initials", "firstInitial" },
    TITLE_TEXTS = { list = "List Name", fight = "Fight Name", both = "List and Fight" },
    TITLE_TEXTS_ORDER = { "list", "fight", "both" },
    MAX_OFFSET_X = 300, MAX_OFFSET_Y = 20,
    ASIAN_GLYPHS = {
        zhCN = { "\229\141\131", "\228\184\135", "\228\186\191" },
        zhTW = { "\229\141\131", "\232\144\172", "\229\132\132" },
        koKR = { "\236\178\156", "\235\167\140", "\236\150\181" },
    },
    COLORS = {
        { key = "barCustomColor", label = "Custom Bar Color", group = "Bars", token = "accent" },
        { key = "ownBarColor", label = "Your Bar Color", group = "Bars", token = "accent" },
        { key = "edgeColor", label = "Edge Color", group = "Bars", token = "accent" },
        { key = "trackColor", label = "Track Color", group = "Bars", token = "panel" },
        { key = "nameColor", label = "Name Color", group = "Text", token = "fg" },
        { key = "valueColor", label = "Figure Color", group = "Text", token = "fg" },
        { key = "rankColor", label = "Rank Color", group = "Text", token = "muted" },
        { key = "columnColor", label = "Column Title Color", group = "Text", token = "muted" },
        { key = "titleColor", label = "Title Color", group = "Text", token = "fg" },
        { key = "timeColor", label = "Time Color", group = "Text", token = "muted" },
        { key = "summaryColor", label = "Summary Color", group = "Text", token = "muted" },
        { key = "windowColor", label = "Window Background", group = "Window", token = "bg" },
        { key = "headerColor", label = "Title Bar Color", group = "Window", token = "panel" },
        { key = "borderColor", label = "Border Color", group = "Window", token = "line" },
    },
    OWN_LOOK = {},
    MODES = MODES, MODE_BY_KEY = byKey, MODE_LABELS = labels, MODE_ORDER = order,
    SESSION_LABELS = { current = "Current", overall = "Overall" },
    SESSION_ORDER = { "current", "overall" },
    GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
    GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
}

for _, key in ipairs(ns.DamageMeter.C.OWN_LOOK_ORDER) do ns.DamageMeter.C.OWN_LOOK[key] = true end

do
    local C = ns.DamageMeter.C
    C.LOOK_KEYS = { "barHeight", "barSpacing", "growUp", "reverseFill", "barScale", "columns", "showDivider",
        "showIcons", "showRanks", "highlightPlayer", "pinSelf", "barColor", "barAlpha",
        "backgroundAlpha", "fontSize", "font", "outline", "texture", "showBorder", "iconStyle", "showColumnHeaders",
        "numberUnits", "numberDecimals", "nameFormat", "showSummary", "summaryName", "summaryTotal", "summaryRate",
        "summaryRank", "summarySize", "shortNames", "titleSize", "timeSize", "showTime",
        "titleText", "titleX", "titleY", "timeX", "timeY", "showButtons", "headerAlpha", "timeBrackets",
        "timeByTitle", "iconSize", "iconGap", "iconSide", "iconZoom", "textPad", "colGap", "edgeWidth", "barTrack",
        "nameClassColor", "valueClassColor", "valueFontSize", "rankSize", "youLabel", "nameMaxLetters",
        "percentDecimals", "rateSuffix", "ownBarStyle", "edgeStyle", "backgroundImage", "backgroundPath",
        "nameOwnFont", "nameFont", "nameOutline", "valueOwnSize", "valueOwnFont", "valueFont", "valueOutline", "rankOwnSize", "rankOwnFont", "rankFont", "rankOutline", "titleOwnSize", "titleOwnFont", "titleFont", "titleOutline", "timeOwnSize", "timeOwnFont", "timeFont", "timeOutline", "summaryOwnSize", "summaryOwnFont", "summaryFont", "summaryOutline", "headOwnSize", "headOwnFont", "headFont", "headOutline", "headSize",
        "imageAlpha", "imageTile", "imageTileSize", "classColors" }
    for _, entry in ipairs(C.COLORS) do C.LOOK_KEYS[#C.LOOK_KEYS + 1] = entry.key end
    C.MAX_LOOKS, C.LOOK_NAME_MAX, C.LOOK_TEXT_MAX = 12, 24, 20000

    C.COLUMN_SLOTS = 6
    C.COLUMN_EXTRAS = {}
    C.COLUMN_KINDS = { name = "Name", total = "Total", rate = "Per Second", percent = "Share", none = "None" }
    C.COLUMN_KINDS_ORDER = { "name", "total", "rate", "percent" }
    for _, key in ipairs({ "damage", "healing", "taken", "avoidable", "absorbs", "interrupts", "dispels",
        "deaths" }) do
        C.COLUMN_EXTRAS[key] = true
        C.COLUMN_KINDS[key] = C.MODE_LABELS[key]
        C.COLUMN_KINDS_ORDER[#C.COLUMN_KINDS_ORDER + 1] = key
    end
    C.COLUMN_KINDS_ORDER[#C.COLUMN_KINDS_ORDER + 1] = "none"
end
