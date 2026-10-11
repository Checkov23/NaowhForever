-- CombatAlert.lua: Combat Alert, fading text and an optional sound or spoken line as you enter and leave combat.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI
local Parts, St = ns.Shared.Parts, ns.Shared.Style

local WIDTH = 300
local FONT_SIZE, ROOM = 32, 16
local FADE_TIME, HOLD_TIME = 0.4, 1.7
local DEFAULT_Y = 200
local VOLUME_RANGE, SPEECH_RATE_RANGE = ns.QoLConstants.VOLUME_RANGE, ns.QoLConstants.SPEECH_RATE_RANGE
local TEXT_RANGE = { 10, 72, 1 }
local ENTER, LEAVE = "combatEnter", "combatLeave"
local MOVER_LABEL = "Combat Alert"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Combat", "QoL/Combat:combatAlert"
local SUMMARY = ns.L("%s and %s")

local frame, fade, unlocked

local function On()
    return S.Get("enabled") and S.Get("combatAlert")
end

local function SavePosition(pos)
    S.Set("combatAlertPos", pos)
end

local function OnFadeFinished()
    frame:Hide()
end

local function BuildFade()
    fade = frame:CreateAnimationGroup()
    local fadeIn = fade:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(FADE_TIME)
    fadeIn:SetOrder(1)
    local fadeOut = fade:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(FADE_TIME)
    fadeOut:SetStartDelay(HOLD_TIME)
    fadeOut:SetOrder(2)
    fade:SetScript("OnFinished", OnFadeFinished)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverCombatAlert", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.text = ns.Font(frame, FONT_SIZE, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.backdrop = Parts.HudBackdrop(frame, { mode = "none" })
    frame.mover = UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
    frame:Hide()
    BuildFade()
end

local function Place()
    local pos = S.Get("combatAlertPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function Flash(prefix)
    fade:Stop()
    local c = S.Get(prefix .. "ClassColor") and RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        or S.Get(prefix .. "Color")
    frame.text:SetText(S.Get(prefix .. "Text"))
    frame.text:SetTextColor(c.r, c.g, c.b, 1)
    frame:SetWidth(frame.mode == "none" and WIDTH or frame.text:GetStringWidth() + 2 * St.CARD_PAD)
    frame:Show()
    if not unlocked then fade:Play() end
end

local function Speak(prefix)
    local text = S.Get(prefix .. "Speech")
    if not (C_VoiceChat and C_VoiceChat.SpeakText) or text == "" then return end
    local voice = S.Get(prefix .. "Voice")
    if voice == "" then voice = ns.TTSVoiceID() end
    pcall(C_VoiceChat.SpeakText, voice, text, S.Get(prefix .. "Rate"), S.Get(prefix .. "Volume"), true)
end

local function Announce(prefix)
    local mode = S.Get(prefix .. "Audio")
    if mode == "sound" then
        UI._PlayLSMSound(UI.SoundPathFor(S.Get(prefix .. "Sound")))
    elseif mode == "tts" then
        Speak(prefix)
    end
end

local function AnnounceEnter() Announce(ENTER) end
local function AnnounceLeave() Announce(LEAVE) end

local function OnEvent(_, event)
    if unlocked then return end
    local entering = event == "PLAYER_REGEN_DISABLED"
    Flash(entering and ENTER or LEAVE)
    C_Timer.After(0, entering and AnnounceEnter or AnnounceLeave)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        if frame then
            fade:Stop()
            frame:Hide()
        end
        return
    end
    if not frame then Build() end
    local size = S.Get("combatAlertFontSize")
    frame.mode = frame.backdrop:SetMode(S.Get("combatAlertBackground"))
    Parts.HudFont(frame.text, S.Get("combatAlertFont"), size, S.Get("combatAlertOutline"), frame.mode)
    frame:SetSize(WIDTH, size + ROOM)
    Place()
    frame.mover:SetShown(unlocked == true)
    if unlocked then
        Flash(ENTER)
    else
        fade:Stop()
        frame:Hide()
    end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "combatAlert"
        or ((key:find("^combatEnter") or key:find("^combatLeave") or key:find("^combatAlert"))
            and key ~= "combatAlertPos") then
        Apply()
    end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = S.Get("enabled") == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group
local AUDIO = { { none = "None", sound = "Sound", tts = "Text to Speech" }, { "none", "sound", "tts" } }
local AUDIO_HELP = ns.L("A sound, or the Speech text read aloud. Text to Speech can stutter on some PCs, "
    .. "as the game waits while Windows speaks it; a Sound costs nothing.")
local VOICE_HELP = ns.L("Game Default speaks in the voice the rest of the addon uses.")
local SPEAKS_WHY = ns.L("Needs Text to Speech")

local function Voices()
    return ns.TTSVoiceChoices()
end

local rows = {}

local function Side(prefix, t)
    local function OwnColour() return not S.Get(prefix .. "ClassColor") end
    local function PlaysSound() return S.Get(prefix .. "Audio") == "sound" end
    local function Speaks() return S.Get(prefix .. "Audio") == "tts" end
    local list = {
        Group(t.combat),
        { key = prefix .. "Text", label = t.text, text = true, help = t.textHelp },
        { key = prefix .. "ClassColor", label = t.classColor, toggle = true },
        { key = prefix .. "Color", label = t.color, colour = true, needs = OwnColour,
          why = "Class color is on" },
        { key = prefix .. "Audio", label = t.audio, choice = AUDIO, help = AUDIO_HELP },
        { key = prefix .. "Sound", label = t.sound, sound = true, needs = PlaysSound,
          why = t.notSound },
        { key = prefix .. "Voice", label = t.voice, choice = Voices, help = VOICE_HELP, needs = Speaks,
          why = SPEAKS_WHY },
        { key = prefix .. "Volume", label = t.volume, slider = VOLUME_RANGE, needs = Speaks,
          why = SPEAKS_WHY },
        { key = prefix .. "Rate", label = t.rate, slider = SPEECH_RATE_RANGE, needs = Speaks,
          why = SPEAKS_WHY },
        { key = prefix .. "Speech", label = t.speech, text = true, needs = Speaks, why = SPEAKS_WHY,
          help = t.speechHelp },
    }
    for _, row in ipairs(list) do rows[#rows + 1] = row end
end

Side(ENTER, {
    combat = "Entering Combat", text = "Entering Text", textHelp = "What it shows as you enter combat.",
    classColor = "Entering Class Color", color = "Entering Color", audio = "Entering Audio",
    sound = "Entering Sound", notSound = "Entering Audio is not Sound", voice = "Entering Voice",
    volume = "Entering Volume", rate = "Entering Speech Rate", speech = "Entering Speech",
    speechHelp = "Read aloud as you enter combat.",
})
Side(LEAVE, {
    combat = "Leaving Combat", text = "Leaving Text", textHelp = "What it shows as you leave combat.",
    classColor = "Leaving Class Color", color = "Leaving Color", audio = "Leaving Audio",
    sound = "Leaving Sound", notSound = "Leaving Audio is not Sound", voice = "Leaving Voice",
    volume = "Leaving Volume", rate = "Leaving Speech Rate", speech = "Leaving Speech",
    speechHelp = "Read aloud as you leave combat.",
})
rows[#rows + 1] = ns.Shared.Settings.Look("combatAlert", { text = true, size = TEXT_RANGE, background = "card" })

local function Summary(store)
    return SUMMARY:format(store.Get("combatEnterText"), store.Get("combatLeaveText"))
end

local page = ns.Shared.Settings.Page("QoL/Combat", S)

page:Card({
    id = "combatAlert", name = "Combat Alert", order = 70, switch = "combatAlert", note = ns.Shared.Settings.EllesmereNote,
    help = "A short flash of text entering and leaving combat. Move it in the HUD Editor.",
    summary = Summary,
    rows = rows,
})
