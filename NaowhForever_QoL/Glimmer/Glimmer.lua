-- Glimmer.lua: Glimmer's settings (ns.GlimmerSettings), its table (ns.Glimmer) and the categories it lights up.
local ns = _G.NaowhForever

local F = ns.FEATURES.glimmer

local CATEGORIES = { "ore", "herb", "quest", "chest", "bobber" }

local S = ns.UI.ModuleSettings("glimmer", {
    enabled = F.enabled,
    questSparkle = F.questSparkle,
    minimapIcons = F.minimapIcons, minimapSize = 14, myProfessions = true,
    gatheredPins = F.gatheredPins, gatheredPinSize = 18,
    cutout = F.cutout, cutoutSize = 1, cutoutHeight = 0,
    style = "sparkles", size = 1, brightness = 1,
    skillColors = true, showLine = true,
    hideInstance = true, hideLocked = false,
    range = 15, arc = 2, onlyHighlighted = true,
    ore = true, herb = true, quest = true, chest = true, bobber = true,
    oreStyle = "same", herbStyle = "same", questStyle = "same", chestStyle = "same", bobberStyle = "same",
    oreColor = { r = 0.88, g = 0.64, b = 0.35 },
    herbColor = { r = 0.49, g = 0.83, b = 0.54 },
    questColor = { r = 1, g = 0.84, b = 0.35 },
    chestColor = { r = 0.30, g = 0.71, b = 0.96 },
    bobberColor = { r = 1, g = 0.48, b = 0.42 },
})
ns.GlimmerSettings = S

local G = { Settings = S, CATEGORIES = CATEGORIES }
ns.Glimmer = G

function G.On()
    return S.Get("enabled") and true or false
end

function G.Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

function G.StyleOf(category)
    local own = S.Get(category .. "Style")
    if own == "same" then return S.Get("style") end
    return own
end
