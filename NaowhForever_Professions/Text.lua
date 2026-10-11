-- Text.lua: amounts of money and colour codes, as the Professions module writes them.
local ns = _G.NaowhForever

local P = ns.Professions
local C = P.C

local GOLD, SILVER = C.COPPER_PER_GOLD, C.COPPER_PER_SILVER
local ROUND = C.ROUND
local RGB_MAX = 255
local HEX = "|cff%02x%02x%02x"
local ALIGNED_GOLD, ALIGNED_SILVER, ALIGNED_COPPER = ns.L("%s%dg %02ds %02dc"), ns.L("%s%ds %02dc"), ns.L("%s%dc")

local Text = {}
P.Text = Text

function Text.Hex(c)
    return HEX:format(c.r * RGB_MAX, c.g * RGB_MAX, c.b * RGB_MAX)
end

function Text.Money(copper, plus)
    local left = math.floor(math.abs(copper) + ROUND)
    local g, s, c = math.floor(left / GOLD), math.floor(left % GOLD / SILVER), left % SILVER
    local sign = copper < 0 and "-" or plus and "+" or ""
    if g > 0 then return ALIGNED_GOLD:format(sign, g, s, c) end
    if s > 0 then return ALIGNED_SILVER:format(sign, s, c) end
    return ALIGNED_COPPER:format(sign, c)
end

function Text.Short(copper)
    copper = math.floor((copper or 0) + ROUND)
    local g, s, c = math.floor(copper / GOLD), math.floor(copper % GOLD / SILVER), copper % SILVER
    if g > 0 then
        if s > 0 then
            if c > 0 then return ("%dg %ds %dc"):format(g, s, c) end
            return ("%dg %ds"):format(g, s)
        end
        if c > 0 then return ("%dg %dc"):format(g, c) end
        return ("%dg"):format(g)
    end
    if s > 0 then
        if c > 0 then return ("%ds %dc"):format(s, c) end
        return ("%ds"):format(s)
    end
    return ("%dc"):format(c)
end
