-- Samples.lua: the sample group the preview and Unlock Mode show (DM.SAMPLE).
local ns = _G.NaowhForever

local OWN = 2

ns.DamageMeter.SAMPLE = {
    durationSeconds = 205,
    fightName = "Training Dummy",
    maxAmount = 100,
    totalAmount = 660,
    combatSources = {
        { name = "Aldrin", classFilename = "MAGE", totalAmount = 100, amountPerSecond = 41, isLocalPlayer = false },
        { name = "You", classFilename = "ROGUE", totalAmount = 91, amountPerSecond = 37, isLocalPlayer = true },
        { name = "Brenna", classFilename = "WARLOCK", totalAmount = 84, amountPerSecond = 34, isLocalPlayer = false },
        { name = "Corvus", classFilename = "HUNTER", totalAmount = 77, amountPerSecond = 31, isLocalPlayer = false },
        { name = "Dara", classFilename = "WARRIOR", totalAmount = 62, amountPerSecond = 25, isLocalPlayer = false },
        { name = "Edric", classFilename = "PALADIN", totalAmount = 48, amountPerSecond = 20, isLocalPlayer = false },
        { name = "Fenna", classFilename = "PRIEST", totalAmount = 31, amountPerSecond = 13, isLocalPlayer = false },
    },
}

function ns.DamageMeter.Sample()
    local _, class = UnitClass("player")
    if type(class) == "string" and class ~= "" then
        ns.DamageMeter.SAMPLE.combatSources[OWN].classFilename = class
    end
    return ns.DamageMeter.SAMPLE
end
