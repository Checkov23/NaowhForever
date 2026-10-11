-- Sounds.lua: plays Rare Alerts' sound, and lists the sounds it offers (Completo.Sounds).
local ns = _G.NaowhForever

local Completo = ns.Completo
local GAME_SOUNDS = Completo.AlertSounds

local KEY, HOW, WHAT, LABEL = 1, 2, 3, 4
local CHANNEL = "Master"
local DEFAULT_SOUND = "file:gruntlinghorn"
local GAME_SUFFIX = ns.L(" (game)")
local NONE = {}

local Sounds = { DEFAULT = DEFAULT_SOUND }
Completo.Sounds = Sounds

local function Find(key)
    for _, sound in ipairs(GAME_SOUNDS) do
        if sound[KEY] == key then return sound end
    end
end

local function Has(sound)
    return sound[HOW] ~= "name" or (SOUNDKIT ~= nil and SOUNDKIT[sound[WHAT]] ~= nil)
end

local function PlayGame(sound)
    if not sound or not Has(sound) then return false end
    if sound[HOW] == "file" then
        PlaySoundFile(sound[WHAT], CHANNEL)
    else
        PlaySound(sound[HOW] == "kit" and sound[WHAT] or SOUNDKIT[sound[WHAT]], CHANNEL)
    end
    return true
end

local function Unfit(key, name)
    return key:find("^voice:") ~= nil or tostring(name or ""):find("BugSack", 1, true) ~= nil
        or key:find("BugSack", 1, true) ~= nil
end

function Sounds.Play(key)
    if PlayGame(Find(key)) then return end
    if ns.UI.SoundPathFor(key) then return ns.UI.PlaySoundKey(key) end
    PlayGame(Find(DEFAULT_SOUND))
end

function Sounds.Picked(key)
    if key == nil or key == "none" then return DEFAULT_SOUND end
    return key
end

function Sounds.Choices()
    local values, order = {}, {}
    for _, sound in ipairs(GAME_SOUNDS) do
        if Has(sound) then
            values[sound[KEY]] = sound[LABEL] .. GAME_SUFFIX
            order[#order + 1] = sound[KEY]
        end
    end
    local _, names, keys = nil, nil, nil
    if ns.SoundChoices then _, names, keys = ns.SoundChoices() end
    for _, key in ipairs(keys or NONE) do
        if not Unfit(key, names[key]) then
            values[key] = names[key]
            order[#order + 1] = key
        end
    end
    return values, order
end
