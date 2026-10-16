-- Glow.lua: shared reminder glows, with an optional proc outline, from a feature's glow settings.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings

local LIB = "LibCustomGlow-1.0"
local SPEED_TOP = 9
local PRESS_KEY = "press"
local PRESS_TIME = 0.4
local PRESS_FREQUENCY = 1

local Glow = {}
A.Glow = Glow

local active = setmetatable({}, { __mode = "k" })
local pressed = setmetatable({}, { __mode = "k" })

Glow.TYPES = { { pixel = "Pixel Glow", standard = "Standard Glow" }, { "pixel", "standard" } }
Glow.TRACKER_TYPES = { { pixel = "Pixel Glow", standard = "Standard Glow", proc = "Gold Glow" },
    { "proc", "pixel", "standard" } }
Glow.PRESS_TIME = PRESS_TIME

local function Stop(frame)
    local glow = active[frame]
    if not glow then return end
    active[frame] = nil
    local LCG = LibStub(LIB, true)
    if glow.kind == "proc" then LCG.ProcGlow_Stop(frame)
    elseif glow.kind == "pixel" then LCG.PixelGlow_Stop(frame)
    else LCG.ButtonGlow_Stop(frame) end
end

function Glow.Set(frame, on, prefix)
    if not on then return Stop(frame) end
    local kind, c = S.Get(prefix .. "Type"), S.Get(prefix .. "Color")
    local lines, thickness, speed = S.Get(prefix .. "Lines"), S.Get(prefix .. "Thickness"), S.Get(prefix .. "Speed")
    local key = table.concat({ kind, c.r, c.g, c.b, lines, thickness, speed, frame:GetWidth() }, ":")
    if active[frame] and active[frame].key == key then return end
    Stop(frame)
    local LCG = LibStub(LIB, true)
    if not LCG then return end
    local color = { c.r, c.g, c.b, 1 }
    if kind == "proc" then
        LCG.ProcGlow_Start(frame, { color = color, startAnim = false })
    elseif kind == "pixel" then
        LCG.PixelGlow_Start(frame, color, lines, 1 / (SPEED_TOP - speed), nil, thickness)
    else
        LCG.ButtonGlow_Start(frame, color)
    end
    active[frame] = { kind = kind, key = key }
end

function Glow.Press(frame, prefix)
    local LCG = LibStub(LIB, true)
    if not LCG then return end
    if pressed[frame] then pressed[frame]:Cancel() end
    local c = S.Get(prefix .. "Color")
    LCG.PixelGlow_Start(frame, { c.r, c.g, c.b, 1 }, S.Get(prefix .. "Lines"), PRESS_FREQUENCY, nil,
        S.Get(prefix .. "Thickness"), nil, nil, nil, PRESS_KEY)
    pressed[frame] = C_Timer.NewTimer(PRESS_TIME, function()
        pressed[frame] = nil
        LCG.PixelGlow_Stop(frame, PRESS_KEY)
    end)
end
