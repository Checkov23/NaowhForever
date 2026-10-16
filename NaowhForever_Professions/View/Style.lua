-- Style.lua: the Professions module's own look, on top of the house look in Shared/Style.lua.
local ns = _G.NaowhForever

local P = ns.Professions

local PAD, LEFT_W, MID_W = 8, 340, 400
local MID_X = PAD + LEFT_W + PAD
local PANE_EDGE = 14
local STEP_W, STEP_GAP, QTY_W, QTY_GAP, ACTION_W = 22, 2, 40, 12, 90
local PROFIT_LINE = 16

P.Style = setmetatable({
    GOLD_RGB = { r = 1, g = 0.82, b = 0 },
    RED_RGB = { r = 1, g = 0.3, b = 0.3 },
    VENDOR_RGB = { r = 1, g = 0.6, b = 0.2 },
    PROFIT_RGB = { r = 0.3, g = 0.82, b = 0.48 },
    READY_RGB = { r = 0.35, g = 1, b = 0.35 },
    RANK_RGB = { r = 1, g = 0.6, b = 0.2 },
    DIFFICULTY_RGB = {
        [0] = { r = 1, g = 0.5, b = 0.25 },
        [1] = { r = 1, g = 1, b = 0 },
        [2] = { r = 0.25, g = 0.75, b = 0.25 },
        [3] = { r = 0.55, g = 0.55, b = 0.55 },
    },
    ALERT_CODE = "|cffff4d4d",
    VENDOR_ICON = "|TInterface\\GossipFrame\\VendorGossipIcon:14:14|t",
    TRAINER_ICON = "Interface\\GossipFrame\\TrainerGossipIcon",
    LOGO = ns.MEDIA .. "LogoSmall.tga",
    GRADIENT = ns.MEDIA .. "NaowhGradient.tga",

    CROP_LOW = 0.07,
    CROP_HIGH = 0.93,
    DIMMED = 0.45,
    PANEL_ALPHA = 0.6,
    SELECTED_ALPHA = 0.25,
    HIGHLIGHT_ALPHA = 0.06,
    BANNER_ALPHA = 0.12,
    WINDOW_ALPHA = 0.97,

    FONT_SMALL = 11,
    FONT = 12,
    FONT_LARGE = 13,
    FONT_HEAD = 14,
    FONT_TITLE = 15,
    FONT_NAME = 16,
    SKILL_BAR_GAP = 8,

    PAD = PAD,
    LEFT_W = LEFT_W,
    MID_W = MID_W,
    MID_X = MID_X,
    WINDOW_W = MID_X + MID_W + PAD,
    ORDER_W = 260,
    MIN_H = 620,
    TOP_Y = -68,
    PANE_EDGE = PANE_EDGE,
    PANE_INNER_W = MID_W - 2 * PANE_EDGE,
    ROW_H = 20,
    ICON_NAME_GAP = 6,
    ROW_ICON_SHRINK = 4,
    NOTE_GAP = 8,
    PANEL_EDGE = 10,
    SIDE_PANEL_ROWS = 8,
    SIDE_PANEL_GAP = 8,
    REAGENT_H = 36,
    MAX_REAGENTS = 8,
    REAGENT_COL_W = 52,
    PROFIT_LINE = PROFIT_LINE,
    PROFIT_H = 3 * PROFIT_LINE,
    BUTTON_H = 24,
    STEP_W = STEP_W,
    STEP_GAP = STEP_GAP,
    QTY_W = QTY_W,
    QTY_GAP = QTY_GAP,
    QTY_LETTERS = 3,
    ACTION_W = ACTION_W,
    BUY_ROW_W = STEP_W + STEP_GAP + QTY_W + STEP_GAP + STEP_W + QTY_GAP + ACTION_W,
    POPUP_W = 420,
    FILTER_W = 76,
    FILTER_GAP = 6,
    CHECK_SIZE = 14,
}, { __index = ns.Shared.Style })
