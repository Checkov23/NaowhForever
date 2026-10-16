-- GlowRows.lua: the settings rows for a reminder's glow: its type, color and, for Pixel Glow, its look.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local LINES_RANGE, THICKNESS_RANGE, SPEED_RANGE = { 1, 16, 1 }, { 1, 6, 1 }, { 1, 8, 1 }
local NEEDS_GLOW = ns.L("Needs the glow on")

function A.GlowRows(prefix, base, types)
    base = base or A.Enabled
    local function On() return base() and S.Get(prefix) and true or false end
    local function NotPixel() return S.Get(prefix .. "Type") ~= "pixel" end
    return {
        { key = prefix .. "Type", label = "Glow Type", choice = types or A.Glow.TYPES, needs = On, why = NEEDS_GLOW,
          help = "Pixel Glow runs lines around the icon; Standard Glow is the game's own button glow." },
        { key = prefix .. "Color", label = "Glow Color", colour = true, needs = On, why = NEEDS_GLOW },
        { key = prefix .. "Lines", label = "Lines", slider = LINES_RANGE, needs = On, why = NEEDS_GLOW,
          hidden = NotPixel },
        { key = prefix .. "Thickness", label = "Thickness", slider = THICKNESS_RANGE, needs = On, why = NEEDS_GLOW,
          hidden = NotPixel },
        { key = prefix .. "Speed", label = "Speed", slider = SPEED_RANGE, needs = On, why = NEEDS_GLOW,
          hidden = NotPixel },
    }
end
