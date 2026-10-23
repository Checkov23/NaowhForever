-- DruidMana.lua: the Druid Mana settings (ns.DruidManaSettings) and the module table (ns.DruidMana).
local ns = _G.NaowhForever

local F = ns.FEATURES.druidMana

local S = ns.UI.ModuleSettings("druidMana", {
    enabled = F.enabled,
    showCat = true, showBear = true, showTravel = false, showAquatic = false, showMoonkin = false,
    showCaster = false,
    combatOnly = true,
    width = 220, height = 16, text = "both",
    font = "", textSize = 12, outline = "OUTLINE", texture = "Naowh Gradient", bgAlpha = 0.6,
    fiveSecond = F.fiveSecond, fiveLine = true, fiveCountdown = true, regenSpark = true,
    powershift = F.powershift, shiftMark = true, shiftsLeft = true, warnLow = true,
    manaColor = { r = 0.18, g = 0.44, b = 0.88 },
    warnColor = { r = 0.94, g = 0.54, b = 0.14 },
    missingColor = { r = 0.9, g = 0.15, b = 0.15 },
    druidManaPos = nil,
    druidManaAnchor = "PlayerFrame", druidManaAnchorPoint = "TOP", druidManaAnchorRelPoint = "BOTTOM",
    druidManaX = 0, druidManaY = -2,
})
ns.DruidManaSettings = S

local _, class = UnitClass("player")

local DM = {
    Settings = S,
    PAGE = "Druid Mana/Settings",
    DRUID = class == "DRUID",
}
ns.DruidMana = DM
DM.PREFIX = "druidMana"

function DM.On()
    return DM.DRUID and S.Get("enabled") == true
end

function DM.Readable(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end
