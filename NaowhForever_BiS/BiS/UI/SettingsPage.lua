-- SettingsPage.lua: the BiS List's settings page (BiS List/Settings), declared as cards.
local ns = _G.NaowhForever

local B = ns.BiS
local S = B.Settings
local L, R, A = B.Lists, B.Rankings, B.Actions
local St = B.Style

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local PLACE_DOT = St.PLACE_DOT
local PERCENT, ROUND = B.C.PERCENT, B.C.ROUND
local ORDER_MARKS, ORDER_DROP_ALERT, ORDER_LISTS, ORDER_KEYS, ORDER_WINDOW = 10, 20, 30, 50, 80
local SCALE_RANGE = { 60, 160, 5 }
local TIME_RANGE = { 2, 15, 1 }
local ALPHA_RANGE = St.ALPHA_RANGE
local FONT_RANGE = { 10, 20, 1 }
local OPACITY_RANGE = St.OPACITY_RANGE
local TO_FRACTION = St.PERCENT_SCALE
local BIS_OFF = ns.L("Turn on the BiS List")
local NEEDS_LOOKS = { "bis", "bisToast" }
local TEXT_HEADLINE = ns.L("Your list: %s%s")
local TEXT_NOTHING_PICKED = ns.L("Nothing picked yet: open it and pick each slot's BiS, or import a list.")
local TEXT_HAVE = ns.L("You have %d of your %d BiS.%s")
local TEXT_RUN_NEXT = ns.L(" Run next: %s, for %d.")
local TEXT_MARKS_BOTH, TEXT_MARKS_TIPS = ns.L("On tooltips and in your bags"), ns.L("On tooltips")
local TEXT_MARKS_BAGS, TEXT_MARKS_NONE = ns.L("In your bags"), ns.L("Only in its window")
local TEXT_ON_SCREEN, TEXT_IN_CHAT = ns.L(", on screen"), ns.L(", in chat")
local TEXT_OPACITY = ns.L("%d%% opacity")

local function Headline()
    local list, spec = L.List(), L.CurrentSpec()
    return TEXT_HEADLINE:format(ns.Color("accentSoft", (list.name:gsub("||", "|"))),
        spec and ns.Color("muted", PLACE_DOT .. spec.name) or "")
end

local function Detail()
    local list = L.List()
    local have, total = R.Had(list)
    if total == 0 then return TEXT_NOTHING_PICKED end
    local place = R.RunNext(list)[1]
    return TEXT_HAVE:format(have, total, place and TEXT_RUN_NEXT:format(place.name, place.bis) or "")
end

local ALERT_FOR = { { bis = "Your BiS only", top2 = "Your top two", all = "Every pick" }, { "bis", "top2", "all" } }
local STARS = { { icon = "On the icon, left", iconRight = "On the icon, right", name = ns.L("Before the name"),
    none = "Hidden" }, { "icon", "iconRight", "name", "none" } }
local BORDERS = { { none = "None", black = "Black", quality = "The item's quality",
    rank = "Your rank's color (BiS orange)" }, { "none", "black", "quality", "rank" } }

local function Sounds()
    local _, names, order = ns.SoundChoices()
    local values, keys = {}, {}
    for key, name in pairs(B.Alerts.GAME_SOUND_NAMES) do values[key] = name end
    for i, key in ipairs(B.Alerts.GAME_SOUND_ORDER) do keys[i] = key end
    for _, key in ipairs(order) do
        values[key] = names[key]
        keys[#keys + 1] = key
    end
    return values, keys
end

local function SoundRow(key, label, help)
    return { key = key, label = label, choice = Sounds, needs = "bis", why = BIS_OFF, help = help,
        get = function() return S.Get(key) end,
        set = function(v)
            S.Set(key, v)
            B.Alerts.Play(v)
        end }
end

local function ListGet()
    local _, _, id = ns.BisListChoices()
    return id
end

local function SpecChoices()
    local values, order = {}, {}
    for _, spec in ipairs(R.ClassSpecs()) do
        values[spec.key] = spec.name
        order[#order + 1] = spec.key
    end
    return values, order
end

local function SpecGet()
    local spec = L.CurrentSpec()
    return spec and spec.key
end

local function MarksSummary(store)
    local tips, bags = store.Get("bisTooltip"), store.Get("bisBagMarks")
    if tips and bags then return TEXT_MARKS_BOTH end
    if tips then return TEXT_MARKS_TIPS end
    if bags then return TEXT_MARKS_BAGS end
    return TEXT_MARKS_NONE
end

local function AlertSummary(store)
    local which = ALERT_FOR[1][store.Get("bisAlertFor")] or ALERT_FOR[1].all
    return ns.L(which) .. (store.Get("bisToast") and TEXT_ON_SCREEN or "") .. (store.Get("bisAlertChat") and TEXT_IN_CHAT or "")
end

local function ListsSummary()
    local list = L.List()
    return list and (list.name:gsub("||", "|")) or ""
end

local function WindowSummary(store)
    return TEXT_OPACITY:format(math.floor((store.Get("bisWindowAlpha") or 1) * PERCENT + ROUND))
end

local function RefreshPage()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local page = Settings.Page("BiS List/Settings", S)

page:Window({
    text = "Open BiS List",
    open = function() ns.OpenBisWindow() end,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "marks", name = "Marks on Items", order = ORDER_MARKS,
    help = "Your list's marks on items out in the game.",
    summary = MarksSummary,
    rows = {
        { key = "bisTooltip", label = "Show on Tooltips", toggle = true, needs = "bis", why = BIS_OFF,
          help = "Your list's rank on the items in it.",
          search = "alt shift click alt+shift-click add remove item link" },
        { key = "bisBagMarks", label = "Bag Marks", toggle = true, needs = "bis", why = BIS_OFF,
          help = "Your BiS List's slot marks on the items in your bags: item level, your BiS's star, Forever's "
              .. "mark and the green arrow on an upgrade. In the game's bags or EllesmereUI's." },
    },
})

page:Card({
    id = "dropAlert", name = "Drop Alert", order = ORDER_DROP_ALERT, switch = "bisLootAlert",
    help = "When an item on your list is up for a roll or in the loot window, and again when it is yours. "
        .. "Move the on-screen alert in the HUD Editor.",
    summary = AlertSummary,
    studio = B.AlertStudio,
    rows = {
        { key = "bisAlertFor", label = "Alert For", choice = ALERT_FOR, needs = "bis", why = BIS_OFF,
          help = "Which of your picks alert: your BiS only, your top two, or every pick on your list." },
        { key = "bisAlertChat", label = "Chat Line", toggle = true, needs = "bis", why = BIS_OFF,
          help = "A line in chat with the item's link." },
        { key = "bisAlertBadge", label = "Roll Frame Badge", toggle = true, needs = "bis", why = BIS_OFF,
          help = "Your star and rank on the game's roll frame." },
        SoundRow("bisDropSound", "Drop Sound", "When it is up for a roll or drops."),
        SoundRow("bisYoursSound", "It's Yours Sound", "When it is yours."),
        { label = "Play Test", button = function() A.TestAlert() end, buttonText = "Play Test", needs = "bis",
          why = BIS_OFF,
          help = "Plays Drop Alert with your list's first BiS, as you set it: up for a roll, dropped, then yours." },
        Settings.Group("On-Screen Alert"),
        { key = "bisToast", label = "On-Screen Alert", toggle = true, needs = "bis", why = BIS_OFF,
          help = "The item, your star and what happened, on screen for a while." },
        { key = "bisToastScale", label = "Size", slider = SCALE_RANGE, unit = "%", scale = TO_FRACTION,
          needs = NEEDS_LOOKS, help = "How big the on-screen alert is." },
        { key = "bisToastTime", label = "Stays For", slider = TIME_RANGE, unit = "s", needs = NEEDS_LOOKS,
          help = "Seconds before it fades." },
        { key = "bisToastAlpha", label = "Background", slider = ALPHA_RANGE, unit = "%", scale = TO_FRACTION,
          needs = NEEDS_LOOKS, help = "How solid its background is." },
        { key = "bisToastGlow", label = "Glow", toggle = true, needs = NEEDS_LOOKS,
          help = "A soft glow round it in your rank's color." },
        { key = "bisToastStar", label = "Star", choice = STARS, needs = NEEDS_LOOKS,
          help = "Where your star sits: on the icon's corner, before the name, or hidden." },
        { key = "bisToastBorder", label = "Border", choice = BORDERS, needs = NEEDS_LOOKS,
          help = "Its edge: none, black, the item's quality, or your rank's color." },
        Settings.Look("bisToast", { text = true, size = FONT_RANGE, needs = NEEDS_LOOKS }),
        Settings.Group("Line Under the Name"),
        { key = "bisToastEvent", label = "What Happened", toggle = true, needs = NEEDS_LOOKS,
          help = "Up for a roll, dropped, or yours." },
        { key = "bisToastRank", label = "Your Rank", toggle = true, needs = NEEDS_LOOKS,
          help = "Your BiS, your second pick, and so on." },
        { key = "bisToastSlot", label = "The Slot", toggle = true, needs = NEEDS_LOOKS,
          help = "The slot it is for." },
        { key = "bisToastSource", label = "Where It Drops", toggle = true, needs = NEEDS_LOOKS,
          help = "The boss or place it comes from." },
        { key = "bisToastGain", label = "How Much Stronger", toggle = true, needs = NEEDS_LOOKS,
          help = "How much stronger it makes you by your stat weights, as +%." },
    },
})

page:Card({
    id = "lists", name = "Lists", order = ORDER_LISTS,
    help = "Lists are shared by every character of your class; each character keeps using the one picked "
        .. "here. New, Rename, Import, Export and Delete are in the BiS List's window.",
    search = "list button title bar alt shift click alt+shift-click add remove item link",
    summary = ListsSummary,
    rows = {
        { label = "Your List", choice = ns.BisListChoices, get = ListGet, set = ns.SelectBisList,
          help = "The list this character uses." },
        { label = "Rankings For", choice = SpecChoices, get = SpecGet, set = ns.SetBisSpec,
          help = "Whose ranking the picker shows. Each spec keeps its own picks on a list." },
    },
})

page:Card({
    id = "keys", name = "Key Binding", order = ORDER_KEYS,
    help = "The key that opens the BiS List.",
    rows = {
        { label = "Open BiS List", binding = "NAOWHFOREVER_BIS",
          help = "Press this key to open the BiS List, and again to close it." },
    },
})

page:Card({
    id = "window", name = "Window", order = ORDER_WINDOW,
    help = "The BiS List's own window, and its Stat Weights window.",
    summary = WindowSummary,
    rows = {
        { key = "bisWindowAlpha", label = "Window Opacity", slider = OPACITY_RANGE, unit = "%",
          scale = TO_FRACTION, help = "How solid the BiS List's windows are, in percent. Also on their title bars." },
    },
})

B.OnListChange(RefreshPage)
