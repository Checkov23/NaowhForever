-- Journeys.lua: the Journeys settings (ns.JourneysSettings), its table (ns.Journeys) and its per-character stores.
local ns = _G.NaowhForever

local F = ns.FEATURES.journeys

local S = ns.UI.ModuleSettings("journeys", {
    enabled = F.enabled,
    card = F.card,
    cardScale = 1,
    cardAlpha = 1,
    hearth = true,
    hearthSaving = 120,
    teleports = true,
    mapRoute = true,
    quests = true,
})
ns.JourneysSettings = S

local Jy = { Settings = S }
ns.Journeys = Jy

function Jy.On()
    return S.Get("enabled") == true
end

function Jy.CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

function Jy.CharStore(key)
    local account = ns.AccountSettings()
    if type(account[key]) ~= "table" then account[key] = {} end
    local mine = Jy.CharKey()
    if type(account[key][mine]) ~= "table" then account[key][mine] = {} end
    return account[key][mine]
end
