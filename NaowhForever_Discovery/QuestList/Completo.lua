-- Completo.lua: the Quest List's settings, its module table (ns.Completo), and its switch following Discovery's.
local ns = _G.NaowhForever

local F = ns.FEATURES.completo
local D = ns.DiscoverySettings
local OLD_ADDON = "NaowhForever_Completo"
local DATA_ADDON = "NaowhForever_DiscoveryData"
local TEXT_OLD_FOLDER = ns.L("Completo is part of Discovery now. Its old folder has been turned off; reload to finish.")

local S = ns.UI.ModuleSettings("completo", {
    enabled = F.enabled, hideDone = false,
    mapPins = F.mapPins, mapGrey = false, mapChainsOnly = false, mapPinSize = 20,
    rareHideKilled = false, rareAlert = F.rareAlert, rareAlertKilled = false, rareAlertSkull = false,
    rareSound = true, rareSoundKey = "file:gruntlinghorn", rareAlertPosition = nil, rareAlertScale = 1,
    rareAlertTime = 20, rareAlertFont = "", rareAlertFontSize = 13, rareAlertOutline = "",
    rareAlertBackground = "card", rareAlertGlow = false,
    rarePins = F.rarePins, rarePinsKilled = false, rarePinSize = 20,
})
ns.CompletoSettings = S

local Completo = { Settings = S }
ns.Completo = Completo

local function LoadData(data, key)
    local quests, rares = ns.CompletoQuestData, ns.CompletoRareData
    setmetatable(quests, nil)
    setmetatable(rares, nil)
    if not C_AddOns.LoadAddOn(DATA_ADDON) then
        quests.Zones, quests.Quests, quests.Requires, quests.Chains = {}, {}, {}, {}
        rares.Zones, rares.Rares = {}, {}
    end
    return rawget(data, key)
end

local UNTIL_LOADED = { __index = LoadData }
ns.CompletoQuestData = setmetatable({}, UNTIL_LOADED)
ns.CompletoRareData = setmetatable({}, UNTIL_LOADED)

local function FollowDiscovery()
    local on = D.Get("enabled")
    if S.Get("enabled") ~= on then S.Set("enabled", on) end
end

local function Sync()
    if S.Get("enabled") and not D.Get("enabled") then
        D.Set("enabled", true)
    else
        FollowDiscovery()
    end
end

local function OnDiscoverySet(key)
    if key == "enabled" then FollowDiscovery() end
end

local function TurnOffOldFolder()
    if not C_AddOns.IsAddOnLoaded(OLD_ADDON) then return end
    C_AddOns.DisableAddOn(OLD_ADDON)
    ns.ConfirmReload(TEXT_OLD_FOLDER)
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Sync()
    TurnOffOldFolder()
end

D.OnChange(OnDiscoverySet)
hooksecurefunc(ns, "Apply", Sync)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)

function Completo.CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end
