-- Style.lua: the Raid Debuffs bar's own look, on top of Shared/Style.lua.
local ns = _G.NaowhForever

local RD = ns.RaidDebuffs

RD.Style = setmetatable({
    BORDER = 1,
    ICON_GAP = 3,
    TIME_SIZE = 0.34,
    COUNT_SIZE = 0.3,
    TEXT_INSET = 2,
    MIN_TEXT = 8,
    SLOT_LIFT = 3,
    MISSING_ALPHA = 0.35,
    PRESENT_DIM = 0.3,
    OUTLINE = "OUTLINE",
    BLACK = { r = 0, g = 0, b = 0 },
    BLINK = 0.5,
    WHITE_RGBA = { 1, 1, 1, 1 },
    YELLOW_RGBA = { 1, 0.82, 0, 1 },
    RED_RGBA = { 1, 0.2, 0.2, 1 },
    FAINT_RGBA = { 1, 0.2, 0.2, 0.3 },
}, { __index = ns.Shared.Style })
