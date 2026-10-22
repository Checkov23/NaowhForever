-- RaidDebuffs.lua: the Raid Debuffs settings (ns.RaidDebuffSettings) and the module table (ns.RaidDebuffs).
local ns = _G.NaowhForever

local F = ns.FEATURES.raidDebuffs
local SPELLS = ns.RaidDebuffSpells

local PREFIX = "debuff_"
local PICKED = { sunderArmor = true, faerieFire = true, curseOfRecklessness = true, curseOfElements = true,
    curseOfShadow = true, demoralizingShout = true, thunderClap = true }

local DEFAULTS = {
    enabled = F.enabled,
    show = "raid", highlightMissing = false,
    size = 32, timer = true, count = true, warn = false, warnAt = 3, warnBlink = false,
    pos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 220 },
}
for _, entry in ipairs(SPELLS) do DEFAULTS[PREFIX .. entry.key] = PICKED[entry.key] == true end

local S = ns.UI.ModuleSettings("raidDebuffs", DEFAULTS)
ns.RaidDebuffSettings = S

local RD = {
    Settings = S,
    PREFIX = PREFIX,
    PAGE = "Raid Debuffs/Settings",
}
ns.RaidDebuffs = RD

function RD.On()
    return S.Get("enabled") == true
end

function RD.Picked(entry)
    return S.Get(PREFIX .. entry.key) == true
end
