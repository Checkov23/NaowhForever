-- FreeForAll.lua: Always Free for All, the party loot method set to Free for All while you lead.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local EVENTS = { "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PARTY_LOOT_METHOD_CHANGED", "PLAYER_REGEN_ENABLED" }

local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("freeForAll")
end

local function Update()
    if InCombatLockdown() or not IsInGroup() or IsInRaid() or not UnitIsGroupLeader("player") then return end
    if C_PartyInfo.GetLootMethod() ~= Enum.LootMethod.Freeforall then
        C_PartyInfo.SetLootMethod(Enum.LootMethod.Freeforall)
    end
end

local function Apply()
    if not On() then
        events:UnregisterAllEvents()
        return
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Update()
end

events:SetScript("OnEvent", Update)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "freeForAll" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/Questing & Group", S):Card({
    id = "freeForAll", name = "Always Free for All", order = 25, switch = "freeForAll",
    help = "Sets your party's loot to Free for All whenever you lead it.",
})
