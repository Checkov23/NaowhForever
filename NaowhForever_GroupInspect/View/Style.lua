-- Style.lua: Group Inspect's look, its window's sizes and the words its views share (GI.UI).
local ns = _G.NaowhForever

local GI = ns.GroupInspect

local UI = {}
GI.UI = UI
local St = setmetatable({
    WINDOW_W = 1100,
    WINDOW_H = 612,
    TOOLBAR_GAP = 12,
    PARTY_W = 203,
    PARTY_WIDE_W = 256,
    PARTY_GAP = 10,
    PARTY_MAX = 5,
    PARTY_PAD = 10,
    PARTY_NAME_GAP = 8,
    PARTY_ICON_GAP = 6,
    PARTY_STAT_ROWS = 5,
    PARTY_VALUE_ROOM = 40,
    BAND_H = 3,
    CLASS_ICON = 32,
    ROW_CLASS_ICON = 20,
    NAME_SIZE = 15,
    NAME_MIN = 11,
    ROW_NAME_SIZE = 13,
    ROW_NAME_MIN = 10,
    SUB_SIZE = 11,
    KICKER_SIZE = 10,
    LINE_SIZE = 12,
    LINE_H = 16,
    SECTION_GAP = 12,
    KICKER_GAP = 6,
    PILL_SIZE = 9,
    BADGE = 14,
    BADGE_GAP = 4,
    ROLE_ICON = 16,
    ROW_ROLE_ICON = 14,
    SLOT = 27,
    SLOT_GAP = 4,
    WIDE_SLOT = 33,
    WIDE_SLOT_GAP = 5,
    STRIP_WEAPON_GAP = 8,
    STRIP_SLOT = 20,
    STRIP_GAP = 3,
    EMPTY_ALPHA = 0.45,
    AWAY_ALPHA = 0.55,
    ROW_H = 32,
    RAID_NAME_X = 40,
    RAID_SCORE_RIGHT = 290,
    RAID_ILVL_RIGHT = 340,
    RAID_VIEW_X = 364,
    RAID_TREE_W = 140,
    RAID_STATE_RIGHT = 32,
    COLUMNS_H = 20,
    SCROLL_GAP = 4,
    ROLE_ATLAS = { TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder", HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
        DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder" },
}, { __index = ns.Shared.Style })
UI.Style = St

local HEADER, PAD, FOOTER, INSET = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.CONTENT_INSET
local SCROLLBAR, TAB_H = St.SCROLLBAR, St.TAB_H
local SCROLL_GAP, TOOLBAR_DROP = St.SCROLL_GAP, 4

UI.PAGE = "Group Inspect/Settings"
UI.WAITING = "..."
UI.NOT_READ = ns.L("Not inspected yet")
UI.REFRESH_TIP = ns.L("Inspect them again")
UI.MODE_WORDS = { party = ns.L("Party of %d"), raid = ns.L("Raid of %d") }
UI.CONTENT_W = St.WINDOW_W - 2 * INSET
UI.LIST_W = UI.CONTENT_W - SCROLLBAR - SCROLL_GAP
UI.TOOLBAR_TOP = HEADER + PAD + TOOLBAR_DROP
UI.CONTENT_TOP = UI.TOOLBAR_TOP + TAB_H + St.TOOLBAR_GAP
UI.CONTENT_H = St.WINDOW_H - UI.CONTENT_TOP - FOOTER - PAD

UI.CLASS_NAMES = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue",
    PRIEST = "Priest", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
UI.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
UI.ARMOR = { MAGE = "Cloth", PRIEST = "Cloth", WARLOCK = "Cloth", ROGUE = "Leather", DRUID = "Leather",
    HUNTER = "Mail", SHAMAN = "Mail", WARRIOR = "Plate", PALADIN = "Plate" }
UI.ROLE_WORDS = { TANK = ns.L("Tank"), HEALER = ns.L("Healer"), DAMAGER = ns.L("Damage") }
UI.STATS = {
    { key = "STR", name = ns.L("Strength"), short = "STR" }, { key = "AGI", name = ns.L("Agility"), short = "AGI" },
    { key = "STA", name = ns.L("Stamina"), short = "STA" }, { key = "INT", name = ns.L("Intellect"), short = "INT" },
    { key = "SPI", name = ns.L("Spirit"), short = "SPI" }, { key = "AP", name = ns.L("Attack Power"), card = ns.L("Atk Power"), short = "AP" },
    { key = "SP", name = ns.L("Spell Power"), short = "SP" }, { key = "CRIT", name = ns.L("Crit"), short = ns.L("Crit"), percent = true },
    { key = "HIT", name = ns.L("Hit"), short = ns.L("Hit"), percent = true }, { key = "ARMOR", name = ns.L("Armor"), short = ns.L("Armor") },
}
