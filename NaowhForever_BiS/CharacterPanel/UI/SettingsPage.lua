-- SettingsPage.lua: the Character Panel's and Slot Marks' cards on BiS List > Character.
local ns = _G.NaowhForever

local CP = ns.CharacterPanel
local S = ns.QoLSettings

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local BADGES_LIVE = ns.BADGES_LIVE
local MARK_KEYS = { "characterPanelLevels", "characterPanelMarks", "characterPanelEnchants" }
local MARKS_OFF = ns.L("Turn on Slot Marks or the Naowh Character Panel")
local TEXT_THEIRS_IN_USE = ns.L("EllesmereUI's panel is in use: switch this off and on for this one")
local TEXT_TAKES_OVER = ns.L("Takes over from EllesmereUI's panel, after a reload")
local TEXT_BADGE_AND_SCORE = ns.L("With your badge and Naowh Score")
local TEXT_BADGE = ns.L("With your badge")
local TEXT_SCORE = ns.L("With your Naowh Score")
local TEXT_PLAIN = ns.L("The slots and stats only")
local TEXT_ON_PANEL = ns.L("On the Naowh Character Panel")
local TEXT_MARKS = ns.L("%d of %d marks")
local STATS_SHOWN = { { spec = "Your Spec", all = "All Stats" }, { "spec", "all" } }

local function MarksOn()
    return S.Get("characterPanel") or S.Get("characterPanelSlotMarks")
end

local function PanelSummary(store)
    if CP.EllesmereSheet() then
        return store.Get("characterPanel") and TEXT_THEIRS_IN_USE or TEXT_TAKES_OVER
    end
    local badge = ns.FEATURE_BADGES == BADGES_LIVE and store.Get("characterPanelBadge")
    local score = store.Get("characterPanelScore")
    if badge and score then return TEXT_BADGE_AND_SCORE end
    if badge then return TEXT_BADGE end
    if score then return TEXT_SCORE end
    return TEXT_PLAIN
end

local function MarksSummary(store)
    if store.Get("characterPanel") and not store.Get("characterPanelSlotMarks") then return TEXT_ON_PANEL end
    local shown = 0
    for _, key in ipairs(MARK_KEYS) do
        if store.Get(key) then shown = shown + 1 end
    end
    return TEXT_MARKS:format(shown, #MARK_KEYS)
end

local panelRows = {
    { key = "characterPanelScore", label = "Naowh Score", toggle = true,
      help = "Your Naowh Score, big under your level: hover it for your score with your BiS and the best "
          .. "in the game, click it for the BiS List." },
    { key = "characterPanelStats", label = "Stats Shown", choice = STATS_SHOWN,
      help = "Your spec's stats with what each is worth, or all of the game's stats." },
}
if ns.FEATURE_BADGES == BADGES_LIVE then
    table.insert(panelRows, 1, { key = "characterPanelBadge", label = "Supporter Badge", toggle = true,
        help = "Your supporter badge, big in the panel's top corner, if you have one." })
end

local page = Settings.Page("BiS List/Character", S)

page:Card({
    id = "characterPanel", name = "Character Panel", order = 10, switch = "characterPanel", store = S,
    switchWhy = ns.GamepadWhy,
    help = "Your character panel (C) in the BiS List's look: each slot with its marks, your stats for your "
        .. "spec, and your Naowh Score under your level. The game keeps the panel and everything it does. With "
        .. "EllesmereUI, turning this on turns its character panel off, and off turns it back on, after a reload.",
    summary = PanelSummary,
    rows = panelRows,
})

page:Card({
    id = "slotMarks", name = "Slot Marks", order = 20, switch = "characterPanelSlotMarks", store = S,
    switchWhy = ns.GamepadWhy,
    help = "The marks on the game's own character panel, as it looks (or EllesmereUI's), without the Naowh "
        .. "Character Panel. With it on, its slots have them already.",
    summary = MarksSummary,
    rows = {
        { key = "characterPanelLevels", label = "Item Level", toggle = true, always = true, needs = MarksOn,
          why = MARKS_OFF, help = "Each slot's item level, in its icon's corner." },
        { key = "characterPanelMarks", label = "BiS Marks", toggle = true, always = true, needs = MarksOn,
          why = MARKS_OFF, help = "Your BiS's star on a slot, and Forever's mark on what is new in Forever." },
        { key = "characterPanelEnchants", label = "Enchant Dots", toggle = true, always = true, needs = MarksOn,
          why = MARKS_OFF,
          help = "A dot on a slot where a better enchant for your level waits: hover it for the advice, click "
              .. "it to ask in Trade." },
    },
})
