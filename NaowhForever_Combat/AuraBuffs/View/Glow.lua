-- Glow.lua: shared reminder glows, with an optional proc outline, from a feature's glow settings.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings

local LIB = "LibCustomGlow-1.0"
local SPEED_TOP = 9
local GOLD_LAYERS_MAX = 6
local GOLD_LAYER_STEP = 0.5
local GOLD_LAYER_KEY = "thickness"

local Glow = {}
A.Glow = Glow

local active = setmetatable({}, { __mode = "k" })

Glow.TYPES = { { pixel = "Pixel Glow", standard = "Standard Glow" }, { "pixel", "standard" } }
Glow.TRACKER_TYPES = { { pixel = "Pixel Glow", standard = "Standard Glow", proc = "Gold Glow" },
    { "proc", "pixel", "standard" } }

local function Stop(frame)
    local glow = active[frame]
    if not glow then return end
    active[frame] = nil
    local LCG = LibStub(LIB, true)
    if glow.kind == "proc" then
        LCG.ProcGlow_Stop(frame)
        for i = 2, glow.layers do LCG.ProcGlow_Stop(frame, GOLD_LAYER_KEY .. i) end
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
    local layers
    if kind == "proc" then
        layers = math.max(1, math.min(GOLD_LAYERS_MAX, math.floor(thickness)))
        LCG.ProcGlow_Start(frame, { color = color, startAnim = false })
        for i = 2, layers do
            local offset = (i - 1) * GOLD_LAYER_STEP
            LCG.ProcGlow_Start(frame, { color = color, startAnim = false, key = GOLD_LAYER_KEY .. i,
                xOffset = offset, yOffset = offset })
        end
    elseif kind == "pixel" then
        LCG.PixelGlow_Start(frame, color, lines, 1 / (SPEED_TOP - speed), nil, thickness)
    else
        LCG.ButtonGlow_Start(frame, color)
    end
    active[frame] = { kind = kind, key = key, layers = layers }
end
