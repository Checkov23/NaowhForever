-- LayerRequests.lua: Layer Tracker's swaps: asking the layer channel for an invite, other players' requests with an Invite button, and leaving a swap that did not move you.
local ns = _G.NaowhForever

local issecretvalue = issecretvalue

local S = ns.QoLSettings
local T = ns.THEME
local Parts = ns.Shared.Parts
local Layers = ns.Layers

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHAT_MSG_CHANNEL", "PARTY_INVITE_REQUEST",
    "GROUP_JOINED", "GROUP_LEFT",
    "SHARD_TRANSFER_IMMINENT", "SHARD_TRANSFER_CANCELLED", "SHARD_TRANSFER",
}
local CHANNEL = "layer"
local CHANNEL_STORE = "layerRequestsChannel"
local REQUEST = "inv layer <LS %d not %s>"
local REQUEST_PATTERN = "^inv layer <LS (%d+) not (%d+%-(%d+))>"
local JOIN_DELAY = 10
local ASK_TIME, ASK_GAP = 60, 30
local CHECK_AFTER = 15
local PROMPT_TIME, PROMPT_AGAIN = 30, 60
local ASKERS_MAX = 50
local PARTY_FULL = MAX_PARTY_MEMBERS + 1
local TOAST_NAME, TOAST_POS = "NaowhForeverLayerRequest", "layerRequestsPos"
local TOAST_W, BUTTON_W = 440, 90
local NO_ICONS = {}
local TEXT_TITLE = ns.L("Layer Swap")
local TEXT_ASKS = ns.L("%s wants to join your layer.")
local TEXT_ASKS_GUILD = ns.L("%s from your guild wants to join your layer.")
local TEXT_ASKS_FRIEND = ns.L("Your friend %s wants to join your layer.")
local TEXT_INVITE, TEXT_NOT_NOW = ns.L("Invite"), ns.L("Not Now")
local TEXT_ASKED = ns.L("Asked the layer channel for an invite to another layer.")
local TEXT_STOPPED = ns.L("Stopped asking for another layer.")
local TEXT_NO_ONE = ns.L("No one invited you to another layer. Click the layer line to ask again.")
local TEXT_NO_LAYER = ns.L("Your layer is not read yet: target or mouse over an NPC first.")
local TEXT_IN_GROUP = ns.L("Leave your group first: a swap is an invite to someone else's group.")
local TEXT_JOINING = ns.L("Joining the layer channel. Click again in a moment.")
local TEXT_WAIT = ns.L("You asked a moment ago. Wait a little before asking again.")
local TEXT_LOCKED = ns.L("Chat is locked right now, so nothing was asked.")
local TEXT_LEFT = ns.L("Joining that group did not move you, so you left it.")
local TEXT_NOT_MOVED = ns.L("Joining that group did not move you to another layer.")
local TEXT_STAY = ns.L("You keep this layer while you stay in the group.")
local TEXT_CLICK_ASK = ns.L("Click: ask for another layer")
local TEXT_CLICK_STOP = ns.L("Asking for another layer. Click: stop asking")

local events, toast, askTimer, checkTimer, joinTimer
local asking, swapping, prompt, trusted, lastAsk
local askers = {}
local askerCount = 0

local function On()
    return S.Get("enabled") and S.Get("layerTracker") and S.Get("layerRequests")
end

local function Hosting()
    return On() and S.Get("layerRequestsHost")
end

local function Channel()
    local id = GetChannelName(CHANNEL)
    if id > 0 then return id end
end

local function Own()
    return ns.Shared.CharacterData(CHANNEL_STORE, true)
end

local function JoinChannel()
    if joinTimer then
        joinTimer:Cancel()
        joinTimer = nil
    end
    if not On() or Channel() then return end
    JoinTemporaryChannel(CHANNEL)
    local own = Own()
    if own then own.joined = true end
end

local function JoinSoon()
    if joinTimer or Channel() then return end
    joinTimer = C_Timer.NewTimer(JOIN_DELAY, JoinChannel)
end

local function LeaveChannel()
    if joinTimer then
        joinTimer:Cancel()
        joinTimer = nil
    end
    local own = Own()
    if not own then return end
    if own.joined and Channel() then LeaveChannelByName(CHANNEL) end
    own.joined = nil
end

local function StopTimers()
    if askTimer then askTimer:Cancel() end
    if checkTimer then checkTimer:Cancel() end
    askTimer, checkTimer = nil, nil
end

local function StopAsking()
    StopTimers()
    asking, swapping, trusted = nil, nil, nil
    Layers.Refresh()
end

local function NoOneCame()
    askTimer = nil
    StopAsking()
    ns.Print(TEXT_NO_ONE)
end

local function Failed()
    checkTimer = nil
    local grouped, keep = IsInGroup(), trusted
    StopAsking()
    if not grouped then return end
    if S.Get("layerRequestsLeave") and not keep then
        C_PartyInfo.LeaveParty()
        ns.Print(TEXT_LEFT)
    else
        ns.Print(TEXT_NOT_MOVED)
    end
end

local function Ask()
    local key, where = Layers.Current(), Layers.Map()
    if not (key and where) then
        ns.Print(TEXT_NO_LAYER)
        return
    end
    if IsInGroup() then
        ns.Print(TEXT_IN_GROUP)
        return
    end
    if C_ChatInfo.InChatMessagingLockdown() then
        ns.Print(TEXT_LOCKED)
        return
    end
    local id = Channel()
    if not id then
        if not joinTimer then JoinChannel() end
        ns.Print(TEXT_JOINING)
        return
    end
    if lastAsk and GetTime() - lastAsk < ASK_GAP then
        ns.Print(TEXT_WAIT)
        return
    end
    C_ChatInfo.SendChatMessage(REQUEST:format(where, key), "CHANNEL", nil, id)
    lastAsk = GetTime()
    asking = true
    askTimer = C_Timer.NewTimer(ASK_TIME, NoOneCame)
    ns.Print(TEXT_ASKED)
    Layers.Refresh()
end

local function OnJoined()
    if not asking then return end
    StopTimers()
    swapping = true
    checkTimer = C_Timer.NewTimer(CHECK_AFTER, Failed)
end

local function Known(name, guid)
    if C_FriendList.IsFriend(guid) or C_BattleNet.GetGameAccountInfoByGUID(guid) then return "friend" end
    if IsInGuild() and C_GuildInfo.MemberExistsByName(name) then return "guild" end
end

local function Line(name, guid)
    local known = Known(name, guid)
    if known == "friend" then return TEXT_ASKS_FRIEND:format(name) end
    if known == "guild" then return TEXT_ASKS_GUILD:format(name) end
    return TEXT_ASKS:format(name)
end

local function Invite()
    if prompt then C_PartyInfo.InviteUnit(prompt) end
    toast:Hide()
end

local function NotNow()
    toast:Hide()
end

local function OnPromptHide()
    prompt = nil
end

local function OnPromptShow(self)
    if not prompt then self:Hide() end
end

local function ShowPrompt(name, guid)
    if not toast then
        toast = Parts.Toast({ name = TOAST_NAME, width = TOAST_W, icons = 0, store = S, posKey = TOAST_POS, on = Hosting,
            buttons = {
                { text = TEXT_INVITE, width = BUTTON_W, click = Invite, accent = true },
                { text = TEXT_NOT_NOW, width = BUTTON_W, click = NotNow },
            } })
        toast:HookScript("OnHide", OnPromptHide)
        toast:HookScript("OnShow", OnPromptShow)
    end
    prompt = name
    Parts.FillToast(toast, TEXT_TITLE, Line(name, guid), NO_ICONS)
    Parts.ShowToast(toast, PROMPT_TIME)
end

local function CanHost(theirs)
    local mine = Layers.Current()
    if not mine or mine == theirs or asking or prompt then return false end
    if InCombatLockdown() or IsInInstance() or IsInRaid() then return false end
    if IsInGroup() and (not UnitIsGroupLeader("player") or GetNumGroupMembers() >= PARTY_FULL) then return false end
    return true
end

local function AskedLately(name)
    local now = GetTime()
    local at = askers[name]
    if at and now - at < PROMPT_AGAIN then return true end
    if not at then
        if askerCount >= ASKERS_MAX then
            wipe(askers)
            askerCount = 0
        end
        askerCount = askerCount + 1
    end
    askers[name] = now
    return false
end

local function OnChannel(text, name, baseName, guid)
    if issecretvalue(baseName) or type(baseName) ~= "string" or baseName:lower() ~= CHANNEL then return end
    if issecretvalue(text) or issecretvalue(name) or issecretvalue(guid) or type(text) ~= "string" then return end
    local where, theirs, zone = text:match(REQUEST_PATTERN)
    if not where then return end
    where = tonumber(where)
    Layers.Note(where, theirs, tonumber(zone))
    if not Hosting() or guid == UnitGUID("player") or where ~= Layers.Map() then return end
    if not CanHost(theirs) or AskedLately(name) then return end
    ShowPrompt(name, guid)
end

local function OnEvent(_, event, ...)
    if event == "CHAT_MSG_CHANNEL" then
        local text, name, _, _, _, _, _, _, baseName, _, _, guid = ...
        OnChannel(text, name, baseName, guid)
    elseif event == "PARTY_INVITE_REQUEST" then
        local name, _, _, _, _, _, guid = ...
        if asking and not (issecretvalue(name) or issecretvalue(guid)) and Known(name, guid) then trusted = true end
    elseif event == "GROUP_JOINED" then
        OnJoined()
    elseif event == "SHARD_TRANSFER_IMMINENT" then
        if swapping and checkTimer then
            checkTimer:Cancel()
            checkTimer = nil
        end
    elseif event == "SHARD_TRANSFER_CANCELLED" then
        if swapping then Failed() end
    elseif event == "SHARD_TRANSFER" then
        if swapping then ns.Print(TEXT_STAY) end
        if asking then StopAsking() end
    elseif event == "GROUP_LEFT" then
        if asking then StopAsking() end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if asking and not swapping then
            StopAsking()
            ns.Print(TEXT_STOPPED)
        end
        if event == "PLAYER_ENTERING_WORLD" then JoinSoon() end
    end
end

local function Apply()
    if not On() then
        if asking then StopAsking() end
        LeaveChannel()
        prompt = nil
        if events then events:UnregisterAllEvents() end
        if toast then toast:Hide() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if not Hosting() then
        prompt = nil
        if toast then toast:Hide() end
    end
    JoinSoon()
end

function Layers.Asking()
    return asking == true
end

function Layers.Click()
    if not On() then return end
    if asking then
        StopAsking()
        ns.Print(TEXT_STOPPED)
    else
        Ask()
    end
end

function Layers.AddTip(tooltip)
    if not On() then return end
    local a = T.accentSoft
    tooltip:AddLine(" ")
    tooltip:AddLine(asking and TEXT_CLICK_STOP or TEXT_CLICK_ASK, a.r, a.g, a.b)
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "layerTracker" or (key:find("^layerRequests") and key ~= TOAST_POS) then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
