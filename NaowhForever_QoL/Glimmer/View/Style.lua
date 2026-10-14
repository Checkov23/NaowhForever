-- Style.lua: Glimmer's own look, on top of the house style: the skill colours, sizes and timings of its effects.
local ns = _G.NaowhForever

local St = ns.Shared.Style

ns.Glimmer.Style = setmetatable({
    TIER_RGB = {
        orange = { r = 1, g = 0.5, b = 0.25 },
        yellow = { r = 1, g = 1, b = 0 },
        green = { r = 0.25, g = 0.75, b = 0.25 },
        grey = { r = 0.5, g = 0.5, b = 0.5 },
        red = St.RED_RGB,
    },
    LOCKED_RGB = { r = 0.62, g = 0.62, b = 0.62 },
    QUEST_LINE_RGB = St.CARRIED_RGB,
    MEDIA = "Interface\\AddOns\\NaowhForever_QoL\\Media\\Glimmer\\",
    BASE = 48,
    PLATE_Y = -40,
    LINE_SIZE = 12,
    LINE_Y = -6,
    FAR_ALPHA = 0.5,
    LOCKED_ALPHA = 0.55,
    LOCKED_SPEED = 0.5,
    FADE = 0.3,
    BLEND = 0.25,
    BURST_TIME = 0.5,
    MAX_STEP = 0.1,
    GLINTS = 7,
    COMETS = 2,
    TAIL = 6,
    RISERS = 5,
    CUTOUT_SHARE = 0.34,
    CUTOUT_Y = -0.06,
    CUTOUT_EDGE_RGB = St.RED_RGB,
    CUTOUT_EDGE_TIME = 10,
}, { __index = St })
