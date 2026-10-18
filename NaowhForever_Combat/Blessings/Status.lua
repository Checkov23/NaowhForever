-- Status.lua: your Symbols of Kings and your Lay on Hands and Divine Intervention cooldowns, shared with the group's paladins.
local ns = _G.NaowhForever

local B = ns.Blessings
local Secret, HighestKnown = B.Secret, B.HighestKnown

local LAY_ON_HANDS = { 633, 2800, 10310 }
local DIVINE_INTERVENTION = { 19752 }
local UNKNOWN = -1
local GLOBAL_COOLDOWN = 1.5

local tracked = {}
for _, ranks in ipairs({ LAY_ON_HANDS, DIVINE_INTERVENTION }) do
    for _, id in ipairs(ranks) do tracked[id] = true end
end

function B.IsStatusSpell(id)
    return tracked[id] == true
end

local function Left(ranks)
    local spell = HighestKnown(ranks)
    if not spell then return UNKNOWN end
    local info = C_Spell.GetSpellCooldown(spell)
    local start, duration = info and info.startTime, info and info.duration
    if not start or Secret(start) or Secret(duration) or duration <= GLOBAL_COOLDOWN then return 0 end
    return math.max(0, math.floor(start + duration - GetTime()))
end

function B.OwnStatus()
    return C_Item.GetItemCount(B.SYMBOL_OF_KINGS), Left(LAY_ON_HANDS), Left(DIVINE_INTERVENTION)
end

function B.StatusMessage()
    local symbols, loh, di = B.OwnStatus()
    return ("I|%d|%d|%d"):format(symbols, loh, di)
end
