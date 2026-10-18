-- Style.lua: the AuraBuffs reminders' own look, on top of Shared/Style.lua.
local ns = _G.NaowhForever

local Shared = ns.Shared or {}
local St = Shared.Style or {}

ns.AuraBuffs.Style = setmetatable({
    BLACK = { r = 0, g = 0, b = 0 },
    BUFF_GAP = 4,
    BUFF_CROP = 0.07,
    BUFF_COUNT_SIZE = 14,
    BUFF_COUNT_INSET = 2,
    BUFF_RANGE_DIM = 0.35,
    MENU_COLS = 8,
    MENU_PAD = 4,
    MENU_GAP = 2,
    LOW_CROP = 0.07,
    LOW_COUNT_SIZE = 14,
    LOW_COUNT_INSET = 2,
    LOW_LABEL_SIZE = 16,
    LOW_LABEL_GAP = 4,
    LOW_RGB = { r = 1, g = 0.25, b = 0.25 },
    LOW_FALLBACK_ICON = 134830,
    CAMP_TEXT_SIZE = 16,
    CAMP_LABEL_GAP = 4,
    CAMP_BUFF_GAP = 12,
    CAMP_TRACK_OUT = 6,
    CAMP_DRAIN_OUT = 5,
    CAMP_RING_OUT = 1,
    CAMP_SIT_HOT = 0.45,
    CAMP_MASK = ns.MEDIA .. "circle_mask.tga",
    CAMP_RING = ns.MEDIA .. "circle_ring.tga",
    CAMP_ART = "Interface\\AddOns\\NaowhForever_Combat\\AuraBuffs\\Media\\CampfireHD.tga",
    CAMP_ART_CROP = { 40 / 1024, 993 / 1024, 36 / 1024, 988 / 1024 },
    CAMP_TIME_STEPS = { { 1800, St.TIME_OK_RGB }, { 300, St.TIME_LOW_RGB }, { 0, St.TIME_OUT_RGB } },
    CAMP_FADE = { IN = 0.3, OUT = 0.4, BREATHE = 0.8, LOW = 0.6 },
    CAMP_BAR = { PAD = St.PANEL_PAD, TEXT = 12, TEXT_MIN = 11, LINE_H = 2, FONT_LIFT = 1, EDGE = 1, ICON_PAD = 2,
        CAMP_GAP = 8, BONUS_GAP = 10, TIME_GAP = 12, BONUS_ICON_GROW = 1, BONUS_ICON_GAP = 3,
        BONUS_ICON_DROP = 1 },
    CAMP_MIN_LABELS = { "+8% Stats", "+308 Armor", "+2% Crit", "+29 MP5" },
    CAMP_SIT_PREFIX = "in ",
    CAMP_TIME_SAMPLE = "44m",
}, { __index = St })
