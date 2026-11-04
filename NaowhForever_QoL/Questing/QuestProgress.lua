-- QuestProgress.lua: Announce Quest Progress, your quest objective updates said in party chat.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Parts = ns.Shared.Parts

local PROGRESS = {
    ERR_QUEST_ADD_KILL_SII = true,
    ERR_QUEST_ADD_ITEM_SII = true,
    ERR_QUEST_ADD_FOUND_SII = true,
    ERR_QUEST_ADD_PLAYER_KILL_SII = true,
    ERR_QUEST_OBJECTIVE_COMPLETE_S = true,
}

local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("questProgress")
end

local function OnInfoMessage(_, _, messageType, message)
    if issecretvalue(messageType) or issecretvalue(message) then return end
    if not PROGRESS[GetGameMessageInfo(messageType)] then return end
    if not IsInGroup() or IsInRaid() or C_ChatInfo.InChatMessagingLockdown() then return end
    C_ChatInfo.SendChatMessage(message, Parts.PartyChat())
end

local function Apply()
    if not On() then
        events:UnregisterAllEvents()
        return
    end
    events:RegisterEvent("UI_INFO_MESSAGE")
end

events:SetScript("OnEvent", OnInfoMessage)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "questProgress" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/Questing & Group", S):Card({
    id = "questProgress", name = "Announce Quest Progress", order = 13, switch = "questProgress",
    help = "Says your quest objective progress in party chat.",
})
