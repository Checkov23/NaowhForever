-- FocusCastBar.lua: the Focus Cast Bar, coloured by whether your interrupt is ready.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts

local BAR = ns.Shared.Style.WHITE
local THROTTLE = 0.033
local INTERRUPTS = {
    WARRIOR = { 6552, 72 },
    ROGUE = { 1766 },
    MAGE = { 2139 },
    SHAMAN = { 8042 },
    PRIEST = { 15487 },
    DRUID = { 16979 },
}
local INTERRUPTED = ns.L("Interrupted")
local SAMPLE_SPELL, SAMPLE_NAME, SAMPLE_ICON = 116, "Frostbolt", 135846
local SAMPLE_TOTAL, SAMPLE_LEFT, SAMPLE_KICK, SAMPLE_STOPPED = 2.5, 1.4, 2, 0.6
local BLACK = ns.Shared.Style.BORDER_RGB
local ICON_CROP = ns.QoLConstants.ICON_CROP_TIGHT
local TICK_W, TICK_ALPHA = 2, 0.9
local SHIELD_W, SHIELD_H, SHIELD_RISE = 29, 33, 4
local SHIELD_ATLAS = "ui-castingbar-shield"
local TEXT_ABOVE = 5
local FONT_SIZE, TEXT_INSET = 12, 4
local ICON_GAP = 1
local CHAR_WIDTH = 0.6
local DEFAULT_Y = 100
local TIME_FORMAT = "%.1f"
local NOT_INTERRUPTIBLE_CAST, NOT_INTERRUPTIBLE_CHANNEL = 8, 7
local MOVER_LABEL = "Focus Cast Bar"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Combat", "QoL/Combat:focusCastBar"
local NOTE_NO_FADE = ns.L("Interrupted Fade is 0: the bar hides at once.")
local NOTE_HIDE_COOLDOWN = ns.L("Hide While Interrupt Is on Cooldown is on: the bar stays hidden.")
local NOTE_HIDE_NONINT = ns.L("Hide Uninterruptible Casts is on: the bar stays hidden.")
local SUMMARY = ns.L("%d by %d%s")
local SUMMARY_SOUND, SUMMARY_SPEAKS = ns.L(", plays a sound"), ns.L(", speaks")
local STAGE_H = 150
local NOTE_Y, NOTE_SIZE = ns.Shared.Style.STAGE_NOTE_Y, ns.Shared.Style.STAGE_NOTE_SIZE
local STAGE_MARGIN = ns.Shared.Style.STAGE_MARGIN
local VOLUME_RANGE, SPEECH_RATE_RANGE = ns.QoLConstants.VOLUME_RANGE, ns.QoLConstants.SPEECH_RATE_RANGE
local NAME_LENGTH_RANGE, FADE_RANGE, WIDTH_RANGE = { 0, 40, 1 }, { 0, 3, 0.05 }, { 100, 600, 5 }
local HEIGHT_RANGE = { 10, 60, 1 }
local TEXT_RANGE = ns.Shared.Style.HUD_TEXT_RANGE
local UNIT_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE" }

local frame, bar, tickBar, icon, shield, nameText, targetText, timeText
local unlocked, casting, channeling, fadeTimer
local interrupt, tickSnapshot
local acc = 0
local readyFill, cooldownFill, nonIntFill

local function On()
    return S.Get("enabled") and S.Get("focusCastBar")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function ClassColor(key, classKey)
    if S.Get(classKey) then return RAID_CLASS_COLORS[select(2, UnitClass("player"))] end
    return S.Get(key)
end

local function Themed(key, themeKey)
    if S.Get("focusThemeColors") then return T[themeKey] end
    return S.Get(key)
end

local function FindInterrupt()
    interrupt = nil
    for _, id in ipairs(INTERRUPTS[select(2, UnitClass("player"))] or {}) do
        if C_SpellBook.IsSpellKnown(id) then
            interrupt = id
            return
        end
    end
end

local function KickReady()
    if not interrupt then return true end
    local cd = C_Spell.GetSpellCooldownDuration(interrupt)
    if not cd then return true end
    return cd:IsZero()
end

local function WrapClass(text, classToken)
    if Secret(classToken) or not classToken then return text end
    local c = C_ClassColor.GetClassColor(classToken)
    if not c then return text end
    return c:WrapTextInColorCode(text)
end

local Look = {}

local function NewBars(f)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(BAR)
    ns.Border(f, BLACK)
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints()
    f.bar:SetStatusBarTexture(BAR)
    f.bar:SetMinMaxValues(0, 1)
    f.tickBar = CreateFrame("StatusBar", nil, f)
    f.tickBar:SetAllPoints(f.bar)
    f.tickBar:SetStatusBarTexture(BAR)
    f.tickBar:SetStatusBarColor(0, 0, 0, 0)
    f.tickBar:Hide()
    f.tick = f.tickBar:CreateTexture(nil, "OVERLAY")
    f.tick:SetTexture(BAR)
    f.tick:SetWidth(TICK_W)
end

local function NewIconAndShield(f)
    f.icon = CreateFrame("Frame", nil, f)
    f.icon.tex = f.icon:CreateTexture(nil, "ARTWORK")
    f.icon.tex:SetAllPoints()
    f.icon.tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ns.Border(f.icon, BLACK)
    f.shield = f:CreateTexture(nil, "OVERLAY")
    f.shield:SetAtlas(SHIELD_ATLAS)
    f.shield:SetSize(SHIELD_W, SHIELD_H)
    f.shield:SetPoint("TOP", f, "BOTTOM", 0, SHIELD_RISE)
    f.shield:Hide()
end

local function NewTexts(f)
    local text = CreateFrame("Frame", nil, f)
    text:SetAllPoints(f.bar)
    text:SetFrameLevel(f:GetFrameLevel() + TEXT_ABOVE)
    f.nameText = ns.Font(text, FONT_SIZE, "OUTLINE")
    f.nameText:SetPoint("LEFT", TEXT_INSET, 0)
    f.nameText:SetJustifyH("LEFT")
    f.nameText:SetWordWrap(false)
    f.targetText = ns.Font(text, FONT_SIZE, "OUTLINE")
    f.targetText:SetJustifyH("LEFT")
    f.targetText:SetWordWrap(false)
    f.timeText = ns.Font(text, FONT_SIZE, "OUTLINE")
    f.timeText:SetPoint("RIGHT", -TEXT_INSET, 0)
    f.timeText:SetJustifyH("RIGHT")
    f.texts = { f.nameText, f.targetText, f.timeText }
end

function Look.New(f)
    NewBars(f)
    NewIconAndShield(f)
    NewTexts(f)
end

local function PlaceIcon(f, h)
    local spell = f.icon
    spell:ClearAllPoints()
    spell:SetSize(h, h)
    local side = S.Get("focusIconSide")
    if side == "RIGHT" then
        spell:SetPoint("LEFT", f, "RIGHT", ICON_GAP, 0)
    elseif side == "TOP" then
        spell:SetPoint("BOTTOM", f, "TOP", 0, ICON_GAP)
    elseif side == "BOTTOM" then
        spell:SetPoint("TOP", f, "BOTTOM", 0, -ICON_GAP)
    else
        spell:SetPoint("RIGHT", f, "LEFT", -ICON_GAP, 0)
    end
    spell:SetShown(S.Get("focusIcon"))
end

local function StyleTexts(f)
    local font, size, outline = S.Get("focusFont"), S.Get("focusFontSize"), S.Get("focusOutline")
    local tc = ClassColor("focusTextColor", "focusTextClassColor")
    for _, fs in ipairs(f.texts) do
        Parts.HudFont(fs, font, size, outline)
        fs:SetTextColor(tc.r, tc.g, tc.b, 1)
    end
    local chars = S.Get("focusNameLength")
    f.nameText:SetWidth(chars > 0 and chars * size * CHAR_WIDTH or 0)
    f.nameText:SetShown(S.Get("focusSpellName"))
    f.targetText:ClearAllPoints()
    if S.Get("focusSpellName") then
        f.targetText:SetPoint("LEFT", f.nameText, "RIGHT", TEXT_INSET, 0)
    else
        f.targetText:SetPoint("LEFT", f.bar, "LEFT", TEXT_INSET, 0)
    end
    f.timeText:SetShown(S.Get("focusTime"))
end

function Look.Layout(f)
    local w, h = S.Get("focusWidth"), S.Get("focusHeight")
    f:SetSize(w, h)
    local c = Themed("focusBgColor", "bg")
    f.bg:SetVertexColor(c.r, c.g, c.b, S.Get("focusBgAlpha"))
    f.bar:SetStatusBarTexture(UI.TexturePath(S.Get("focusTexture"), BAR))
    PlaceIcon(f, h)
    StyleTexts(f)
    f.tick:SetHeight(h)
    local t = ClassColor("focusTickColor", "focusTickClassColor")
    f.tick:SetVertexColor(t.r, t.g, t.b, TICK_ALPHA)
end

function Look.StateColour(state)
    if state == "ready" then
        if S.Get("focusReadyClassColor") then return ClassColor("focusReadyColor", "focusReadyClassColor") end
        return Themed("focusReadyColor", "accent")
    end
    if state == "cooldown" then return S.Get("focusCooldownColor") end
    if state == "nonint" then return S.Get("focusNonIntColor") end
    return S.Get("focusInterruptedColor")
end

function Look.Paint(f, c)
    f.bar:GetStatusBarTexture():SetVertexColor(c.r, c.g, c.b, 1)
end

function Look.Tick(f, total, at, channel)
    local ticker, mark = f.tickBar, f.tick
    ticker:SetMinMaxValues(0, total)
    ticker:SetReverseFill(channel == true)
    ticker:SetValue(at)
    mark:ClearAllPoints()
    if channel then
        mark:SetPoint("RIGHT", ticker:GetStatusBarTexture(), "LEFT")
    else
        mark:SetPoint("LEFT", ticker:GetStatusBarTexture(), "RIGHT")
    end
    ticker:Show()
end

function Look.Interrupter(name, classToken)
    return INTERRUPTED .. ": " .. WrapClass(name, classToken)
end

function Look.Sample(f, state)
    local _, class = UnitClass("player")
    local you = UnitName("player")
    if f.bar.ClearTimerDuration then f.bar:ClearTimerDuration() end
    f.bar:SetMinMaxValues(0, 1)
    f.icon.tex:SetTexture(C_Spell.GetSpellTexture(SAMPLE_SPELL) or SAMPLE_ICON)
    f.shield:Hide()
    f.tickBar:Hide()
    f:SetAlpha(1)
    if state == "interrupted" then
        f.bar:SetValue(SAMPLE_STOPPED)
        f.nameText:SetText(S.Get("focusInterrupter") and Look.Interrupter(you, class) or INTERRUPTED)
        f.targetText:SetText("")
        f.timeText:SetText("")
        Look.Paint(f, Look.StateColour("interrupted"))
        if S.Get("focusFadeTime") <= 0 then return NOTE_NO_FADE end
        return nil
    end
    f.bar:SetValue((SAMPLE_TOTAL - SAMPLE_LEFT) / SAMPLE_TOTAL)
    f.nameText:SetText(C_Spell.GetSpellName(SAMPLE_SPELL) or SAMPLE_NAME)
    f.targetText:SetText(S.Get("focusTarget") and WrapClass(you, class) or "")
    f.timeText:SetFormattedText(TIME_FORMAT, SAMPLE_LEFT)
    local colour, note = Look.StateColour("ready"), nil
    if state == "cooldown" then
        colour = Look.StateColour("cooldown")
        if S.Get("focusTick") then
            Look.Tick(f, SAMPLE_TOTAL, SAMPLE_KICK, false)
            f.tickBar:SetAlpha(1)
        end
        if S.Get("focusHideOnCooldown") then
            f:SetAlpha(0)
            note = NOTE_HIDE_COOLDOWN
        end
    elseif state == "nonint" then
        if S.Get("focusColorNonInt") then colour = Look.StateColour("nonint") end
        if S.Get("focusShield") then
            f.shield:Show()
            f.shield:SetAlpha(1)
        end
        if S.Get("focusHideNonInt") then
            f:SetAlpha(0)
            note = NOTE_HIDE_NONINT
        end
    end
    Look.Paint(f, colour)
    return note
end

local function SavePosition(pos)
    S.Set("focusCastBarPos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverFocusCastBar", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    Look.New(frame)
    bar, tickBar, icon, shield = frame.bar, frame.tickBar, frame.icon, frame.shield
    nameText, targetText, timeText = frame.nameText, frame.targetText, frame.timeText
    frame.mover = UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
    frame:Hide()
end

local function Place()
    local pos = S.Get("focusCastBarPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function NotInterruptible()
    if casting then return select(NOT_INTERRUPTIBLE_CAST, UnitCastingInfo("focus")) end
    if channeling then return select(NOT_INTERRUPTIBLE_CHANNEL, UnitChannelInfo("focus")) end
end

local function Fill(color, c)
    if not color then return CreateColor(c.r, c.g, c.b, 1) end
    color:SetRGBA(c.r, c.g, c.b, 1)
    return color
end

local function Colors(interrupted)
    if interrupted then
        Look.Paint(frame, Look.StateColour("interrupted"))
        frame:SetAlpha(1)
        return
    end
    local tex = bar:GetStatusBarTexture()
    local ready = KickReady()
    readyFill = Fill(readyFill, Look.StateColour("ready"))
    cooldownFill = Fill(cooldownFill, Look.StateColour("cooldown"))
    local color = C_CurveUtil.EvaluateColorFromBoolean(ready, readyFill, cooldownFill)
    local notInt = NotInterruptible()
    local hasNotInt = Secret(notInt) or notInt ~= nil
    if hasNotInt and S.Get("focusColorNonInt") then
        nonIntFill = Fill(nonIntFill, Look.StateColour("nonint"))
        color = C_CurveUtil.EvaluateColorFromBoolean(notInt, nonIntFill, color)
    end
    tex:SetVertexColor(color:GetRGBA())

    if S.Get("focusHideOnCooldown") then
        frame:SetAlphaFromBoolean(ready, 1, 0)
    else
        frame:SetAlpha(1)
    end
    if hasNotInt and S.Get("focusHideNonInt") then
        frame:SetAlphaFromBoolean(notInt, 0, frame:GetAlpha())
    end
    if hasNotInt and S.Get("focusShield") then
        shield:Show()
        shield:SetAlphaFromBoolean(notInt, 1, 0)
    else
        shield:Hide()
    end
end

local function UpdateTick()
    local duration = casting and UnitCastingDuration("focus") or channeling and UnitChannelDuration("focus")
    local cd = interrupt and C_Spell.GetSpellCooldownDuration(interrupt)
    if not (S.Get("focusTick") and duration and cd) then
        tickBar:Hide()
        return
    end
    if tickSnapshot == nil then
        local remaining, elapsed = cd:GetRemainingDuration(), duration:GetElapsedDuration()
        if Secret(remaining) or Secret(elapsed) then
            tickSnapshot = remaining
        else
            tickSnapshot = elapsed + remaining
        end
    end
    local total = duration:GetTotalDuration()
    if not Secret(tickSnapshot) and not Secret(total) and (tickSnapshot > total or tickSnapshot < 0) then
        tickBar:Hide()
        return
    end
    Look.Tick(frame, total, tickSnapshot, channeling)
    tickBar:SetAlphaFromBoolean(cd:IsZero(), 0, 1)
end

local function Speak()
    local voice = S.Get("focusVoice")
    if voice == "" then voice = ns.TTSVoiceID() end
    C_VoiceChat.SpeakText(voice, S.Get("focusSpeech"), S.Get("focusRate"), S.Get("focusVolume"), true)
end

local function Announce()
    local mode = S.Get("focusAudio")
    if mode == "sound" then
        UI._PlayLSMSound(UI.SoundPathFor(S.Get("focusSound")))
    elseif mode == "tts" and C_VoiceChat and C_VoiceChat.SpeakText and S.Get("focusSpeech") ~= "" then
        Speak()
    end
end

local function CancelFade()
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
end

local function Stop()
    CancelFade()
    casting, channeling, tickSnapshot = false, false, nil
    tickBar:Hide()
    shield:Hide()
    targetText:SetText("")
    if not unlocked then frame:Hide() end
end

local function FriendlyFocus()
    local friend = UnitIsFriend("player", "focus")
    return not Secret(friend) and friend
end

local function ShowTarget(isChannel)
    targetText:SetText("")
    if not S.Get("focusTarget") or isChannel then return end
    local target = UnitSpellTargetName("focus")
    if Secret(target) or target then
        targetText:SetText(WrapClass(target, UnitSpellTargetClass("focus")))
    end
end

local function Start(isChannel, announce)
    if S.Get("focusHideFriendly") and FriendlyFocus() then return end
    local _, text, texture
    if isChannel then
        _, text, texture = UnitChannelInfo("focus")
    else
        _, text, texture = UnitCastingInfo("focus")
    end
    CancelFade()
    casting, channeling, tickSnapshot = not isChannel, isChannel, nil
    icon.tex:SetTexture(texture)
    nameText:SetText(text)
    ShowTarget(isChannel)
    local duration = isChannel and UnitChannelDuration("focus") or UnitCastingDuration("focus")
    if duration then
        bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
            isChannel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
    end
    Colors()
    UpdateTick()
    frame:Show()
    if announce then Announce() end
end

local function HoldBar()
    local timer, value = bar:GetTimerDuration(), nil
    if timer then
        if channeling then
            value = timer:GetRemainingPercent()
        else
            value = timer:GetElapsedPercent()
        end
    end
    if not Secret(value) and value == nil then value = 1 end
    if bar.ClearTimerDuration then bar:ClearTimerDuration() end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(value)
end

local function InterruptedLabel(by)
    if not (S.Get("focusInterrupter") and (Secret(by) or (by and by ~= ""))) then return INTERRUPTED end
    local name = UnitNameFromGUID(by)
    if Secret(name) or name then
        return Look.Interrupter(name, select(2, GetPlayerInfoByGUID(by)))
    end
    return INTERRUPTED
end

local function FadeDone()
    fadeTimer = nil
    Stop()
end

local function Interrupted(by)
    local fade = S.Get("focusFadeTime")
    if fade <= 0 then
        Stop()
        return
    end
    HoldBar()
    casting, channeling = false, false
    nameText:SetText(InterruptedLabel(by))
    targetText:SetText("")
    timeText:SetText("")
    shield:Hide()
    tickBar:Hide()
    Colors(true)
    frame:Show()
    if fadeTimer then fadeTimer:Cancel() end
    fadeTimer = C_Timer.NewTimer(fade, FadeDone)
end

local function Check()
    if not UnitExists("focus") then
        Stop()
    elseif UnitCastingDuration("focus") then
        Start(false)
    elseif UnitChannelDuration("focus") then
        Start(true)
    else
        Stop()
    end
end

local function Preview()
    Look.Sample(frame, "ready")
    frame:Show()
end

local function OnUpdate(_, elapsed)
    acc = acc + elapsed
    if acc < THROTTLE then return end
    acc = 0
    if not (casting or channeling) then return end
    Colors()
    if S.Get("focusTime") then
        local duration = casting and UnitCastingDuration("focus") or UnitChannelDuration("focus")
        if duration then timeText:SetFormattedText(TIME_FORMAT, duration:GetRemainingDuration()) end
    end
end

local function OnChannelStop(interruptedBy)
    if Secret(interruptedBy) or (interruptedBy and interruptedBy ~= "") then
        Interrupted(interruptedBy)
    elseif not fadeTimer then
        Stop()
    end
end

local function OnEvent(_, event, _, _, _, interruptedBy)
    if event == "SPELLS_CHANGED" then
        FindInterrupt()
        return
    end
    if unlocked then return end
    if event == "PLAYER_FOCUS_CHANGED" then
        Check()
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
        Start(false, event == "UNIT_SPELLCAST_START")
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        Start(true, event == "UNIT_SPELLCAST_CHANNEL_START")
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        Interrupted(interruptedBy)
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        OnChannelStop(interruptedBy)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" then
        if not fadeTimer then Stop() end
    elseif (casting or channeling) then
        Colors()
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)

local function Apply()
    events:UnregisterAllEvents()
    if not (On() or unlocked) then
        if frame then
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
        end
        return
    end
    if not frame then Build() end
    Place()
    Look.Layout(frame)
    FindInterrupt()
    frame.mover:SetShown(unlocked == true)
    frame:SetScript("OnUpdate", OnUpdate)
    if unlocked then
        Preview()
        return
    end
    events:RegisterEvent("PLAYER_FOCUS_CHANGED")
    events:RegisterEvent("SPELLS_CHANGED")
    for _, event in ipairs(UNIT_EVENTS) do events:RegisterUnitEvent(event, "focus") end
    Check()
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^focus") and key ~= "focusCastBarPos") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = S.Get("enabled") == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if frame then Apply() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group
local SIDE = { { LEFT = "Left", RIGHT = "Right", TOP = "Top", BOTTOM = "Bottom" }, { "LEFT", "RIGHT", "TOP", "BOTTOM" } }
local AUDIO = { { none = "None", sound = "Sound", tts = "Text to Speech" }, { "none", "sound", "tts" } }
local AUDIO_HELP = ns.L("A sound, or the Speech text read aloud, as each cast starts.")
local VOICE_HELP = ns.L("Game Default speaks in the voice the rest of the addon uses.")
local STATES = {
    { key = "ready", label = "Interrupt Ready", tip = "A cast while your interrupt is ready." },
    { key = "cooldown", label = "On Cooldown", tip = "A cast while your interrupt is on cooldown, with the tick where it comes back." },
    { key = "nonint", label = "Uninterruptible", tip = "A cast you cannot interrupt, with its shield." },
    { key = "interrupted", label = "Interrupted", tip = "A cast someone interrupted, held for the fade time." },
}

local function Voices()
    return ns.TTSVoiceChoices()
end

local function OwnReadyColour() return not (S.Get("focusReadyClassColor") or S.Get("focusThemeColors")) end
local function OwnBgColour() return not S.Get("focusThemeColors") end
local function OwnTextColour() return not S.Get("focusTextClassColor") end
local function OwnTickColour() return S.Get("focusTick") and not S.Get("focusTickClassColor") end
local function PlaysSound() return S.Get("focusAudio") == "sound" end
local function Speaks() return S.Get("focusAudio") == "tts" end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.bar = CreateFrame("Frame", nil, preview)
    Look.New(preview.bar)
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y)
    return preview
end

local function Fit(preview)
    local f = preview.bar
    local h = S.Get("focusHeight")
    local side = S.Get("focusIconSide")
    local across = S.Get("focusIcon") and (side == "LEFT" or side == "RIGHT") and h + ICON_GAP or 0
    local down = S.Get("focusIcon") and (side == "TOP" or side == "BOTTOM") and h + ICON_GAP or 0
    local x = side == "LEFT" and across / 2 or -across / 2
    local y = side == "BOTTOM" and down / 2 or -down / 2
    local width = S.Get("focusWidth") + across
    local room = preview:GetWidth() - STAGE_MARGIN * 2
    local scale = 1
    if room > 0 and width > room then scale = room / width end
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", preview, "CENTER", x, y + NOTE_Y)
end

local function PaintPreview(preview, state)
    Look.Layout(preview.bar)
    Fit(preview)
    preview.note:SetText(Look.Sample(preview.bar, state) or "")
end

local function Summary(store)
    local audio = store.Get("focusAudio")
    return SUMMARY:format(store.Get("focusWidth"), store.Get("focusHeight"),
        audio == "sound" and SUMMARY_SOUND or audio == "tts" and SUMMARY_SPEAKS or "")
end

ns.Shared.Settings.Page("QoL/Combat", S):Card({
    id = "focusCastBar", name = "Focus Cast Bar", order = 50, switch = "focusCastBar",
    help = "Your focus target's casts on a bar of their own, colored by whether your interrupt "
        .. "is ready, with a tick where it comes off cooldown and a shield on casts you cannot "
        .. "interrupt. Your interrupt is the first you know of Pummel, Shield Bash, Kick, "
        .. "Counterspell, Earth Shock, Silence and Feral Charge. Move it in the HUD Editor.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Shown"),
        { key = "focusIcon", label = "Show Icon", toggle = true },
        { key = "focusIconSide", label = "Icon Side", choice = SIDE, needs = "focusIcon" },
        { key = "focusSpellName", label = "Show Spell Name", toggle = true },
        { key = "focusNameLength", label = "Name Length", slider = NAME_LENGTH_RANGE, needs = "focusSpellName",
          help = "Cuts the name to about this many letters. 0 shows it whole." },
        { key = "focusTarget", label = "Show Cast Target", toggle = true,
          help = "Who the cast is aimed at, in their class color." },
        { key = "focusTime", label = "Show Time Left", toggle = true },
        { key = "focusShield", label = "Uninterruptible Shield", toggle = true },
        { key = "focusInterrupter", label = "Show Who Interrupted", toggle = true },
        { key = "focusTick", label = "Interrupt Ready Tick", toggle = true,
          help = "A tick on the bar where your interrupt comes off cooldown. Hidden while it is ready." },
        { key = "focusTickClassColor", label = "Class Color Tick", toggle = true, needs = "focusTick" },
        { key = "focusTickColor", label = "Tick Color", colour = true, needs = OwnTickColour,
          why = "Needs Interrupt Ready Tick, class color off" },
        Group("Hide"),
        { key = "focusHideFriendly", label = "Hide Friendly Casts", toggle = true },
        { key = "focusHideNonInt", label = "Hide Uninterruptible Casts", toggle = true },
        { key = "focusHideOnCooldown", label = "Hide While Interrupt Is on Cooldown", toggle = true },
        { key = "focusFadeTime", label = "Interrupted Fade", slider = FADE_RANGE, unit = "s",
          help = "How long an interrupted cast stays up. 0 hides it at once." },
        Group("Sound"),
        { key = "focusAudio", label = "Cast Start Audio", choice = AUDIO, help = AUDIO_HELP },
        { key = "focusSound", label = "Sound", sound = true, needs = PlaysSound, why = "Cast Start Audio is not Sound" },
        { key = "focusVoice", label = "Voice", choice = Voices, help = VOICE_HELP, needs = Speaks,
          why = "Needs Text to Speech" },
        { key = "focusVolume", label = "Volume", slider = VOLUME_RANGE, needs = Speaks, why = "Needs Text to Speech" },
        { key = "focusRate", label = "Speech Rate", slider = SPEECH_RATE_RANGE, needs = Speaks,
          why = "Needs Text to Speech" },
        { key = "focusSpeech", label = "Speech Text", text = true, needs = Speaks, why = "Needs Text to Speech",
          help = "Spoken as a cast starts." },
        Group("Size"),
        { key = "focusWidth", label = "Width", slider = WIDTH_RANGE },
        { key = "focusHeight", label = "Height", slider = HEIGHT_RANGE },
        ns.Shared.Settings.Look("focus", { text = true, size = TEXT_RANGE, bar = "Flat", background = "alpha" }),
        { key = "focusBgColor", label = "Background Color", colour = true, needs = OwnBgColour,
          why = "Apply Theme to Bar Colors is on" },
        Group("Colors"),
        { key = "focusThemeColors", label = "Apply Theme to Bar Colors", toggle = true,
          help = "Color the ready bar with your theme's Accent and its background with the theme's Background." },
        { key = "focusReadyClassColor", label = "Class Color Ready", toggle = true },
        { key = "focusReadyColor", label = "Interrupt Ready Color", colour = true, needs = OwnReadyColour,
          why = "Class color or Apply Theme is on" },
        { key = "focusCooldownColor", label = "Interrupt on Cooldown Color", colour = true },
        { key = "focusInterruptedColor", label = "Interrupted Color", colour = true },
        { key = "focusColorNonInt", label = "Color Uninterruptible Casts", toggle = true },
        { key = "focusNonIntColor", label = "Uninterruptible Color", colour = true, needs = "focusColorNonInt" },
        { key = "focusTextClassColor", label = "Class Color Text", toggle = true },
        { key = "focusTextColor", label = "Text Color", colour = true, needs = OwnTextColour,
          why = "Class color is on" },
    },
})
