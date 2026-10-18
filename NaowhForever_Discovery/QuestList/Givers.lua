-- Givers.lua: learns from the quest givers you speak to which quests they really offer you.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests

local QUEST_ID_ANSWER = 5
local EVENTS = { "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_TURNED_IN" }
local NONE = {}

local offered = {}
local titles = {}
local listed
local events

local function ReadableGUID(unit)
    local guid = UnitGUID(unit)
    if not issecretvalue(guid) then return guid end
end

local function Learn(unit)
    if not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local zone = Q.CurrentZone()
    if not zone then return end
    Q.Refresh()
    local trivial = not C_Minimap.IsFilteredOut(Enum.MinimapTrackingFilter.TrivialQuests)
    for _, id in ipairs(Q.GiverQuests(UnitName(unit), zone.map)) do
        if offered[id] and Q.Expected(id) == "later" then Q.SetOpened(id) end
        if Q.Expected(id) == "open" and (trivial or not Q.Trivial(id)) then
            Q.SetOffered(id, offered[id] == true)
        end
    end
end

local function FromGossip()
    wipe(offered)
    for _, quest in ipairs(C_GossipInfo.GetAvailableQuests() or NONE) do
        if quest.questID then offered[quest.questID] = true end
    end
    listed = ReadableGUID("npc")
    Learn("npc")
end

local function OfferByTitle()
    if not next(titles) then return end
    local zone = Q.CurrentZone()
    if not zone then return end
    for _, id in ipairs(Q.GiverQuests(UnitName("npc"), zone.map)) do
        if titles[Q.Name(id)] then offered[id] = true end
    end
end

local function FromGreeting()
    wipe(offered)
    wipe(titles)
    for i = 1, GetNumAvailableQuests() do
        local id = GetAvailableQuestInfo and select(QUEST_ID_ANSWER, GetAvailableQuestInfo(i))
        if id then offered[id] = true else titles[GetAvailableTitle(i) or ""] = true end
    end
    OfferByTitle()
    listed = ReadableGUID("npc")
    Learn("npc")
end

local function FromDetail()
    local guid = ReadableGUID("questnpc")
    if not guid or guid == listed then return end
    wipe(offered)
    offered[GetQuestID()] = true
    Learn("questnpc")
end

local function OnEvent(_, event, questID)
    if event == "GOSSIP_SHOW" then
        FromGossip()
    elseif event == "QUEST_GREETING" then
        FromGreeting()
    elseif event == "QUEST_DETAIL" then
        FromDetail()
    elseif event == "QUEST_TURNED_IN" then
        Q.CountTurnIn(questID)
    end
end

local function Apply()
    if events then events:UnregisterAllEvents() end
    if not S.Get("enabled") then return end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

local function OnSet(key)
    if key == "enabled" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
