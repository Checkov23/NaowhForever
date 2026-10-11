-- Run with Lua 5.1 from the repository root: Buff Thank You Message whispers a player who
-- gives you a class buff, once per cooldown, in the open world and out of combat only; a
-- caster the game cannot name gets the optional built-in /thank; and nothing is registered
-- while it is off.
local settings = {
    enabled = true, buffThanks = false, buffThanksCooldown = 10, buffThanksGroup = false,
    buffThanksEmote = false, buffThanksText = "Thanks for the {buff}, {name}!",
    buffThanksPerBuff = false, buffThanksBlessing = "Light be with you, {name}!", buffThanksIntellect = "",
}
local S = { Get = function(key) return settings[key] end }
function S.Set(key, value) settings[key] = value end
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    Apply = function() end,
    Shared = { Style = dofile("Tools/regression/shared_style.lua"),
        Settings = { Page = function() return { Card = function() end } end,
        Group = function(title) return { group = title } end } },
}

local frames = {}
local function CreateFrame()
    local f = { events = {}, unitEvents = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e, unit) self.unitEvents[e] = unit end
    function f:UnregisterAllEvents() self.events, self.unitEvents = {}, {} end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end

-- Units the game can name: a nameplate stranger, a party member, an NPC, and you.
local units = {
    nameplate38 = { name = "Mumford", guid = "Player-1-38", player = true },
    nameplate2 = { name = "Farfriend-Other Realm", guid = "Player-2-02", player = true },
    party1 = { name = "Buddy", guid = "Player-1-01", player = true, party = true },
    nameplate9 = { name = "Guard", player = false },
    player = { name = "Zyan", guid = "Player-1-00", player = true },
}
-- A crowd for the cap, and a second Mumford: Forever's first names are not unique.
for i = 1, 5 do units["nameplate" .. (100 + i)] = { name = "Crowd" .. i, guid = "Player-1-1" .. i, player = true } end
units.nameplate40 = { name = "Mumford", guid = "Player-1-40", player = true }
local sent, now, combat, instance, secretAuras, lockdown, secret = {}, 1000, false, false, false, false, nil
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = CreateFrame,
    hooksecurefunc = function(t, name, fn)
        local orig = t[name]
        t[name] = function(...) orig(...) fn(...) end
    end,
    issecretvalue = function(v) return secret ~= nil and v == secret end,
    C_Secrets = { ShouldAurasBeSecret = function() return secretAuras end },
    C_ChatInfo = {
        SendChatMessage = function(text, channel, _, to) sent[#sent + 1] = { text = text, channel = channel, to = to } end,
        InChatMessagingLockdown = function() return lockdown end,
        PerformEmote = function(emote) sent[#sent + 1] = { emote = emote } end,
    },
    GetTime = function() return now end,
    UnitAffectingCombat = function() return combat end,
    IsInInstance = function() return instance end,
    UnitIsUnit = function(a, b) return a == b end,
    UnitIsPlayer = function(u) return units[u].player end,
    UnitInParty = function(u) return units[u].party end,
    UnitInRaid = function() return nil end,
    GetUnitName = function(u) return units[u].name end,
    UnitGUID = function(u) return units[u].guid end,
    Ambiguate = function(name) return (name:gsub("%-.*", "")) end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    math = { random = function(n) return n end },
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/BuffThanks.lua"))
setfenv(chunk, env)
chunk()

local events, boot = frames[1], frames[2]
boot.onEvent(boot, "PLAYER_LOGIN")

-- An aura added to you, from unit (nil when the game cannot name the caster).
local function Gain(id, name, unit)
    events.onEvent(events, "UNIT_AURA", "player",
        { addedAuras = { { spellId = id, name = name, sourceUnit = unit, isHelpful = true } } })
end

local count = 0
local function Case(name, fn)
    sent = {}
    fn()
    count = count + 1
    print("PASS " .. name)
end

Case("off by default: no aura event registered", function()
    assert(next(events.unitEvents) == nil and next(events.events) == nil)
end)

S.Set("buffThanks", true)
Case("on: only the player's UNIT_AURA", function()
    assert(events.unitEvents.UNIT_AURA == "player")
    assert(next(events.events) == nil)
end)
Case("a stranger's Blessing of Kings: a whisper naming the buff and the caster", function()
    Gain(20217, "Blessing of Kings", "nameplate38")
    assert(#sent == 1 and sent[1].channel == "WHISPER" and sent[1].to == "Mumford", #sent)
    assert(sent[1].text == "Thanks for the Blessing of Kings, Mumford!", sent[1].text)
end)
Case("the same player again within the cooldown: nothing", function()
    now = now + 9 * 60
    Gain(25898, "Greater Blessing of Kings", "nameplate38")
    assert(#sent == 0)
end)
Case("the same player after the cooldown: thanked again", function()
    now = now + 61
    Gain(20217, "Blessing of Kings", "nameplate38")
    assert(#sent == 1)
end)
Case("a class buff from the extra list (Thorns)", function()
    now = now + 3600
    Gain(467, "Thorns", "nameplate38")
    assert(#sent == 1 and sent[1].text == "Thanks for the Thorns, Mumford!", sent[1] and sent[1].text)
end)
Case("another realm: whispered by full name, called by the short one", function()
    Gain(20217, "Blessing of Kings", "nameplate2")
    assert(sent[1].to == "Farfriend-Other Realm" and sent[1].text == "Thanks for the Blessing of Kings, Farfriend!")
end)
Case("your own buff, a world buff, and an NPC's: nothing", function()
    now = now + 3600
    Gain(20217, "Blessing of Kings", "player")
    Gain(1259688, "Elemental Blessing", "player")
    Gain(1259688, "Elemental Blessing", "nameplate38")
    Gain(20217, "Blessing of Kings", "nameplate9")
    assert(#sent == 0, #sent)
end)
Case("a party member: skipped unless Thank Group Members is on", function()
    Gain(20217, "Blessing of Kings", "party1")
    assert(#sent == 0)
    settings.buffThanksGroup = true
    Gain(20217, "Blessing of Kings", "party1")
    assert(#sent == 1 and sent[1].to == "Buddy")
end)
Case("in combat, in an instance, secret auras, chat lockdown: nothing", function()
    now = now + 3600
    combat = true
    Gain(20217, "Blessing of Kings", "nameplate38")
    combat, instance = false, true
    Gain(20217, "Blessing of Kings", "nameplate38")
    instance, secretAuras = false, true
    Gain(20217, "Blessing of Kings", "nameplate38")
    secretAuras, lockdown = false, true
    Gain(20217, "Blessing of Kings", "nameplate38")
    lockdown = false
    assert(#sent == 0, #sent)
end)
Case("a secret caster or spell ID: nothing", function()
    secret = "nameplate38"
    Gain(20217, "Blessing of Kings", "nameplate38")
    secret = 20217
    Gain(20217, "Blessing of Kings", "nameplate38")
    secret = nil
    assert(#sent == 0, #sent)
end)
Case("an unnamed caster: nothing unless Thank With an Emote is on", function()
    Gain(20217, "Blessing of Kings", nil)
    assert(#sent == 0)
end)
Case("every class: Arcane Intellect, Fortitude, Mark of the Wild, Unending Breath", function()
    now = now + 3600
    for _, id in ipairs({ 1459, 10938, 21849, 5697 }) do
        now = now + 3600
        Gain(id, "Buff", "nameplate38")
    end
    assert(#sent == 4, #sent)
    settings.buffThanksEmote = true
end)
Case("unnamed casters with the emote on: one built-in /thank per cooldown", function()
    Gain(9885, "Mark of the Wild", nil)
    Gain(467, "Thorns", nil)
    assert(#sent == 1 and sent[1].emote == "THANK" and sent[1].channel == nil, #sent)
    now = now + 3600
    Gain(20217, "Blessing of Kings", nil)
    assert(#sent == 2 and sent[2].emote == "THANK", #sent)
end)
Case("several lines: one is picked, trimmed, placeholders filled in", function()
    now = now + 3600
    settings.buffThanksText = "Cheers!\n  Thanks for the {buff} and {buff}, {name} \n "
    Gain(20217, "Blessing of Kings", "nameplate38")
    assert(sent[1].text == "Thanks for the Blessing of Kings and Blessing of Kings, Mumford", sent[1].text)
end)
Case("no lines: nothing sent", function()
    now = now + 3600
    settings.buffThanksText = " \n \n"
    Gain(20217, "Blessing of Kings", "nameplate38")
    assert(#sent == 0)
end)
Case("Lines Per Buff off: a blessing gets the Whisper Lines", function()
    now = now + 3600
    settings.buffThanksText = "Thanks for the {buff}!"
    Gain(20217, "Blessing of Kings", "nameplate38")
    assert(sent[1].text == "Thanks for the Blessing of Kings!", sent[1].text)
end)
Case("Lines Per Buff on: a blessing gets the Blessing Lines", function()
    now = now + 3600
    settings.buffThanksPerBuff = true
    Gain(1038, "Blessing of Salvation", "nameplate38")
    assert(sent[1].text == "Light be with you, Mumford!", sent[1].text)
end)
Case("Lines Per Buff on, its lines left empty: the Whisper Lines", function()
    now = now + 3600
    Gain(1459, "Arcane Intellect", "nameplate38")
    assert(sent[1].text == "Thanks for the Arcane Intellect!", sent[1].text)
end)
Case("Lines Per Buff on, a buff with no lines of its own: the Whisper Lines", function()
    now = now + 3600
    Gain(5697, "Unending Breath", "nameplate38")
    assert(sent[1].text == "Thanks for the Unending Breath!", sent[1].text)
end)
Case("a crowd buffing you: three thanks a minute, then more once it passes", function()
    now = now + 3600
    settings.buffThanksPerBuff = false
    for i = 1, 5 do Gain(20217, "Blessing of Kings", "nameplate" .. (100 + i)) end
    assert(#sent == 3, #sent)
    now = now + 60
    Gain(20217, "Blessing of Kings", "nameplate104")
    assert(#sent == 4 and sent[4].to == "Crowd4", #sent)
end)
Case("two players with the same first name: each thanked", function()
    now = now + 3600
    Gain(20217, "Blessing of Kings", "nameplate38")
    Gain(20217, "Blessing of Kings", "nameplate40")
    assert(#sent == 2, #sent)
end)
Case("a secret GUID: kept apart by name instead", function()
    now = now + 3600
    secret = "Player-1-38"
    Gain(20217, "Blessing of Kings", "nameplate38")
    Gain(20217, "Blessing of Kings", "nameplate38")
    secret = nil
    assert(#sent == 1, #sent)
end)
Case("another options change does not forget who was thanked", function()
    now = now + 3600
    Gain(20217, "Blessing of Kings", "nameplate38")
    ns.Apply()
    Gain(20217, "Blessing of Kings", "nameplate38")
    assert(#sent == 1, #sent)
end)
Case("turned off: the aura event is gone", function()
    S.Set("buffThanks", false)
    assert(next(events.unitEvents) == nil)
end)
print(count .. " buff thank you message regressions passed")
