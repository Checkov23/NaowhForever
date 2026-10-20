-- Style.lua: what only Completo draws (Completo.Style), on top of the house look in Shared/Style.lua.
local ns = _G.NaowhForever

local Completo = ns.Completo

local Style = setmetatable({
    GOLD_RGB = { r = 1, g = 0.82, b = 0 },
    LOG_RGB = { r = 1, g = 0.82, b = 0 },
    REPEAT_RGB = { r = 0.35, g = 0.7, b = 1 },
    DUNGEON_RGB = { r = 0.3, g = 1, b = 0.3 },
    GREY_RGB = { r = 0.62, g = 0.62, b = 0.62 },
    HINT_RGB = { r = 0.3, g = 0.71, b = 0.96 },
    BLACK_RGB = { r = 0, g = 0, b = 0 },
    STAR_ATLAS = "VignetteKill",
    ROW_ICON_DROP = 1,
    TITLE_SIZE = 13,
    KICKER_SIZE = 10,
    COUNT_SIZE = 22,
    LINE_GAP = 3,
    LEVEL_W = 24,
    TICK_SIZE = 14,
    PIN_RIGHT = 10,
    STATUS_W = 120,
    STATUS_GAP = 10,
    BAR_H = 4,
    ARROW_SIZE = 10,
    ARROW_GAP = 6,
    RARE_GAP = 16,
    ICON_GAP = 6,
    DROP_ICON = 16,
    HERO_PAD = 16,
    HERO_TOP = 14,
    SECTION_GAP = 8,
}, { __index = ns.Shared.Style })
Completo.Style = Style

function Style.Hint()
    local c = ns.ThemeTint("accentSoft", nil) or Style.HINT_RGB
    return c.r, c.g, c.b
end
