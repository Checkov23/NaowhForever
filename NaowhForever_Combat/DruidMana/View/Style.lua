-- Style.lua: the Druid Mana bar's own look, on top of Shared/Style.lua.
local ns = _G.NaowhForever

local DM = ns.DruidMana

DM.Style = setmetatable({
    TEXT_INSET = 6,
    TEXT_SIZE = 12,
    OUTLINE = "OUTLINE",
    LINE_H = 3,
    LINE_GAP = 2,
    INFO_GAP = 2,
    INFO_SIZE = 0.8,
    TICK_W = 2,
    SPARK_W = 6,
    SPARK_ALPHA = 0.8,
    SPARK_LOW = 0.2,
    TICK_RGB = { r = 1, g = 1, b = 1 },
    SPARK_RGB = { r = 0.56, g = 0.72, b = 1 },
    EDGE_RGB = { r = 0, g = 0, b = 0 },
    COUNTDOWN_RGB = { r = 0.55, g = 0.81, b = 1 },
    FLAT_TEX = "Interface\\Buttons\\WHITE8X8",
}, { __index = ns.Shared.Style })
