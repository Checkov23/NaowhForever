-- Style.lua: the Group Finder's look, its window's sizes and the words its views share (ns.GroupFinder.UI).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end

local UI = {}
GF.UI = UI
local St = setmetatable({
    WINDOW_W = 640,
    WINDOW_H = 640,
    TAB_GAP = 10,
    TAB_PAD = 24,
    ROW_H = 68,
    ROW_PAD = 12,
    BAND_W = 3,
    LINE_1 = 10,
    LINE_2 = 28,
    LINE_3 = 49,
    TITLE_SIZE = 13,
    LINE_SIZE = 12,
    SUB_SIZE = 11,
    SCORE_SIZE = 16,
    KICKER_SIZE = 10,
    CLASS_ICON = 14,
    ROLE_ICON = 15,
    ROLE_GAP = 3,
    SLOTS_SHOWN = 5,
    TEXT_GAP = 6,
    DETAIL_GAP = 14,
    HEAD_SIZE = 16,
    GROUP_HEAD_H = 76,
    GROUP_PARTY_Y = 44,
    GROUP_PARTY_W = 119,
    CHIP_H = 20,
    CHIP_GAP = 4,
    CHIP_PAD = 8,
    FILTER_GAP = 8,
    TILE_COLS = 4,
    TILE_H = 44,
    TILE_GAP = 6,
    SECTION_GAP = 14,
    KICKER_GAP = 6,
    STEP_W = 20,
    ROLE_GROUP_W = 180,
    TRACK_W = 200,
    BOX_W = 44,
    NOTE_H = 24,
    LIST_BUTTON_W = 120,
    DISABLED_ALPHA = 0.45,
    APPLICANT_H = 48,
    APPLICANT_NAME_W = 150,
    APPLICANT_SCORE_RIGHT = 230,
    APPLICANT_KILLS_X = 245,
    APPLICANT_BIS_X = 330,
    APPLICANT_QUESTS_X = 385,
    APPLICANT_BUTTON_W = 56,
    APPLY_W = 76,
    BUTTON_H = 20,
    DELISTED_ALPHA = 0.45,
    SCROLL_GAP = 4,
    ROLE_ATLAS = { TANK = "groupfinder-icon-role-large-tank", HEALER = "groupfinder-icon-role-large-heal",
        DAMAGER = "groupfinder-icon-role-large-dps" },
    EMPTY_SLOT = "groupfinder-icon-emptyslot",
}, { __index = ns.Shared.Style })
UI.Style = St

local HEADER, PAD, FOOTER, INSET = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.CONTENT_INSET

UI.WAITING = "..."
UI.TABS_TOP = HEADER + PAD
UI.CONTENT_TOP = UI.TABS_TOP + St.TAB_H + St.TAB_GAP
UI.CONTENT_W = St.WINDOW_W - 2 * INSET
UI.LIST_W = UI.CONTENT_W - St.SCROLLBAR - St.SCROLL_GAP
UI.FOOTER_ROOM = FOOTER + PAD
UI.STYLES = { GROUP_FINDER_GENERAL_PLAYSTYLE1, GROUP_FINDER_GENERAL_PLAYSTYLE2, GROUP_FINDER_GENERAL_PLAYSTYLE3,
    GROUP_FINDER_GENERAL_PLAYSTYLE4 }

function UI.Kicker(parent, text)
    local kicker = ns.Font(parent, St.KICKER_SIZE, nil, ns.THEME.accentSoft)
    kicker:SetText(ns.L(text))
    return kicker
end

function UI.Pick(button, on, color)
    local T = ns.THEME
    button._rest = on and T.accent or button.idle
    button._border:SetColor(button._rest.r, button._rest.g, button._rest.b, 1)
    color = on and T.accent or color or T.fg
    button.label:SetTextColor(color.r, color.g, color.b)
end

function UI.PaintClass(icon, class)
    local coords = class and CLASS_ICON_TCOORDS[class]
    icon.texture:SetShown(coords ~= nil)
    if coords then ns.Shared.Parts.ClassCrop(icon.texture, coords) end
end
