-- Alerts.lua: Drop Alert, once per drop and again when it is yours, as you set it (B.Alerts).
local ns = _G.NaowhForever

local B = ns.BiS
local S = B.Settings
local Items, Parts = ns.Shared.Items, ns.Shared.Parts
local RankMark = Parts.RankMark

local SAME_DROP = 300
local FORGET = 3600
local RAID_WARNING, EPIC_LOOT = "game:raidwarning", "game:epicloot"
local NO_SOUND = "none"
local SOUND_CHANNEL = "Master"
local ROLL_KEY = "roll"
local GAP = "  "
local TEXT_DETAIL = "  %s: %s%s"
local TEXT_PICK = ns.L("your #%d pick")
local TEXT_FOR = ns.L(" for ")
local RANK_WORDS = { ns.L("your BiS"), ns.L("your second pick") }
local WHAT = { roll = ns.L("up for a roll"), dropped = "dropped", yours = ns.L("is yours") }
local ALERT_FOR = { bis = 1, top2 = 2, all = math.huge }
local GAME_SOUNDS = { [RAID_WARNING] = SOUNDKIT.RAID_WARNING,
    [EPIC_LOOT] = SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.RAID_WARNING }
local GAME_SOUND_NAMES = { [RAID_WARNING] = ns.L("Raid Warning (game)"), [EPIC_LOOT] = ns.L("Epic Loot (game)") }
local LOOT_EVENTS = { "LOOT_READY", "START_LOOT_ROLL" }

local seen, said = {}, {}
local events

local function Tag() return ns.Color("accent", "Naowh BiS") end

local function Rank(link)
    if not link or issecretvalue(link) then return nil end
    return ns.IsBisItem(Items.IDFrom(link))
end

local function AlertOn()
    return B.On() and S.Get("bisLootAlert")
end

local function Play(key)
    if not key or key == NO_SOUND then return end
    local kit = GAME_SOUNDS[key]
    if kit then
        PlaySound(kit, SOUND_CHANNEL)
    else
        ns.UI._PlayLSMSound(ns.UI.SoundPathFor(key))
    end
end

local function Alerts(rank)
    return rank ~= nil and rank <= (ALERT_FOR[S.Get("bisAlertFor")] or math.huge)
end

local function ChatLine(link, rank, event)
    local slot = B.Lists.SlotOf(Items.IDFrom(link))
    local detail = TEXT_DETAIL:format(WHAT[event], RANK_WORDS[rank] or TEXT_PICK:format(rank),
        slot and TEXT_FOR .. Items.SlotName(slot) or "")
    return Tag() .. GAP .. RankMark(rank) .. GAP .. link .. ns.Color("muted", detail)
end

local function Say(link, rank, event)
    if S.Get("bisToast") then B.Toast.Show(link, rank, event) end
    if S.Get("bisAlertChat") then ns.Print(ChatLine(link, rank, event)) end
    Play(S.Get(event == "yours" and "bisYoursSound" or "bisDropSound"))
end

local function Forget(now)
    for key, at in pairs(seen) do
        if now - at > FORGET then seen[key] = nil end
    end
    for id, at in pairs(said) do
        if now - at > FORGET then said[id] = nil end
    end
end

local function New(key, id)
    local now = GetTime()
    local old = seen[key] or (said[id] and now - said[id] < SAME_DROP)
    seen[key] = now
    if old then return false end
    Forget(now)
    said[id] = now
    return true
end

local function Dropped(link, event, key)
    local rank = Rank(link)
    if Alerts(rank) and New(key, Items.IDFrom(link)) then Say(link, rank, event) end
end

local function Yours(link, id)
    local rank = id and ns.IsBisItem(id)
    if Alerts(rank) and not C_Item.IsEquippedItem(id) then Say(link, rank, "yours") end
end

local function ReadLootWindow()
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local corpse = GetLootSourceInfo(slot)
        if link and not issecretvalue(link) and corpse and not issecretvalue(corpse) then
            Dropped(link, "dropped", corpse .. link)
        end
    end
end

local function OnEvent(_, event, arg)
    if event == "START_LOOT_ROLL" then return Dropped(GetLootRollItemLink(arg), "roll", ROLL_KEY .. arg) end
    if event == "CHAT_MSG_LOOT" then return Yours(Items.YourLoot(arg, true)) end
    ReadLootWindow()
end

local function Listen()
    if not AlertOn() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:UnregisterAllEvents()
    for _, event in ipairs(LOOT_EVENTS) do events:RegisterEvent(event) end
    if Items.READS_LOOT then events:RegisterEvent("CHAT_MSG_LOOT") end
end

local function OnSetting(key)
    if key == "bis" or key == "bisLootAlert" then Listen() end
end

local A = {}
B.Alerts = A
A.GAME_SOUNDS = GAME_SOUNDS
A.GAME_SOUND_NAMES = GAME_SOUND_NAMES
A.GAME_SOUND_ORDER = { RAID_WARNING, EPIC_LOOT }
A.Play = Play
A.On = AlertOn
A.Rank = Rank
A.Wanted = Alerts
A.Say = Say

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Listen)
