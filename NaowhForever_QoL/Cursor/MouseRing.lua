-- MouseRing.lua: the QoL mouse ring: casts and the GCD swept around the cursor, and its settings card.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI
local T = ns.THEME

local MEDIA = "Interface\\AddOns\\NaowhForever_QoL\\Media\\MouseRing\\"
local RING_TEXEL = 0.5 / 256
local TRAIL_TEXEL = 0.5 / 128
local TRAIL_MAX = 60
local TRAIL_SHAPES = {
    glow = "trail_glow.tga", circle = "nq_circle.tga", ring = "nq_ring_soft1.tga",
    star = "nq_star.tga", sparkle = "sparkle.tga",
}
local MELEE_TICK = 0.05
local IDLE_FADE = 0.5
local PI, TWO_PI = math.pi, math.pi * 2
local floor, max, min = math.floor, math.max, math.min
local RED = { r = 1, g = 0, b = 0 }
local WHITE = "Interface\\Buttons\\WHITE8x8"
local SPARKLES, SPARKLE_LOW, SPARKLE_HIGH = 40, 30, 90
local PERCENT = ns.QoLConstants.PERCENT
local SWEEP_LEVEL = 5
local ROUND = ns.QoLConstants.ROUND
local TRAIL_TICK = 0.025
local TRAIL_MIN_GAP, TRAIL_GAP_SHARE = 2, 0.1
local TRAIL_MIN_TIME = 0.1
local MS = 1000
local STAGE_H = 170
local OPACITY_RANGE, DOT_RANGE = ns.QoLConstants.OPACITY_RANGE, ns.QoLConstants.DOT_RANGE
local SOUND_REPEAT_RANGE = ns.QoLConstants.SOUND_REPEAT_RANGE
local SIZE_RANGE, FADE_DELAY_RANGE = { 16, 128, 1 }, { 0.5, 10, 0.5 }
local IDLE_OPACITY_RANGE, PERCENT_SCALE = ns.Shared.Style.ALPHA_RANGE, ns.Shared.Style.PERCENT_SCALE
local BORDER_RANGE, SWEEP_DELAY_RANGE, TRAIL_SIZE_RANGE = { 1, 10, 1 }, { 0, 0.5, 0.01 }, { 4, 64, 1 }
local TRAIL_LENGTH_RANGE, TRAIL_TIME_RANGE, BRIGHTNESS_RANGE = { 5, 60, 1 }, { 0.1, 5, 0.1 }, { 10, 100, 5 }
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED", "PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM" }
local PLAYER_EVENTS = { "PLAYER_FLAGS_CHANGED", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE" }
local RESET_MELEE = { PLAYER_TARGET_CHANGED = true, SPELLS_CHANGED = true, UPDATE_SHAPESHIFT_FORM = true }

local TEXT_NO_CAST = ns.L("Cast Sweep is off: only your global cooldown sweeps.")
local TEXT_NO_SWEEP = ns.L("GCD Sweep is off: nothing sweeps around the ring.")
local TEXT_FADED = ns.L("Idle Opacity is 0%: the ring fades out completely.")
local TEXT_SUMMARY = ns.L("%s, %d px%s%s")
local TEXT_GCD, TEXT_TRAIL = ns.L(", GCD sweep"), ns.L(", trail")

local sparkleColors = {}
for i = 1, SPARKLES do
    sparkleColors[i] = { r = math.random(SPARKLE_LOW, SPARKLE_HIGH) / PERCENT,
        g = math.random(SPARKLE_LOW, SPARKLE_HIGH) / PERCENT, b = math.random(SPARKLE_LOW, SPARKLE_HIGH) / PERCENT }
end

local container, parts, sweep
local trail, trailPoints = nil, {}

local state = {
    inCombat = false, inInstance = false, afk = false, rightDown = false,
    castStart = 0, castEnd = 0, casting = false, castPending = false,
    gcd = nil, gcdOwned = false, castSwipeAllowed = false, gcdSwipeAllowed = true,
    outOfMelee = false, lastInRange = nil,
    lastMove = 0, idleAlpha = 1,
}
local sweepState = { active = false, mode = nil, start = 0, duration = 1, modRate = 1 }
local castDelay, gcdDelay, alarmTicker
local meleeSpell
local meleeTicker, mouseWatcher = CreateFrame("Frame"), CreateFrame("Frame")
local meleeAcc = 0
local UpdateRender

local function On()
    return S.Get("enabled") and S.Get("mouseRing")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function Color(key, classKey)
    if S.Get(classKey) then return RAID_CLASS_COLORS[select(2, UnitClass("player"))] end
    return S.Get(key)
end

local function SetupTexture(tex, shape)
    tex:SetTexture(MEDIA .. shape, "CLAMP", "CLAMP", "TRILINEAR")
    tex:SetTexCoord(RING_TEXEL, 1 - RING_TEXEL, RING_TEXEL, 1 - RING_TEXEL)
    tex:SetSnapToPixelGrid(false)
    tex:SetTexelSnappingBias(0)
end

local function Visible()
    if not On() then return false end
    if S.Get("mouseHideOnClick") and state.rightDown then return false end
    if state.inCombat then return true end
    if S.Get("mouseHideAfk") and state.afk then return false end
    return S.Get("mouseShowOOC")
end

local function Opacity()
    return (state.inCombat or state.inInstance) and S.Get("mouseOpacityCombat")
        or S.Get("mouseOpacityOOC")
end

local Look = {}

function Look.HideSweep(s)
    s.right:Hide()
    s.left:Hide()
    s.frame:Hide()
end

function Look.Sweep(s, angle, r, g, b, a)
    s.right:SetVertexColor(r, g, b, a)
    s.rightProg:SetRotation(PI - min(angle, PI))
    s.right:Show()
    if angle > PI then
        s.left:SetVertexColor(r, g, b, a)
        s.leftProg:SetRotation(-(angle - PI))
        s.left:Show()
    else
        s.left:Hide()
    end
end

local function UpdateSweep()
    local s = sweepState
    if not s.active then return end
    local frac = min((GetTime() - s.start) / (s.duration / s.modRate), 1)
    if frac >= 1 then
        if s.mode == "gcd" then
            state.gcd = nil
            state.gcdSwipeAllowed = true
        end
        s.active, s.mode = false, nil
        Look.HideSweep(sweep)
        return true
    end
    Look.Sweep(sweep, frac * TWO_PI, s.r, s.g, s.b, s.a)
end

local function SweepHalf(f, clipRotation, progRotation)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    local clip = f:CreateMaskTexture()
    clip:SetTexture(MEDIA .. "half_disk_clip.tga", "CLAMP", "CLAMP", "TRILINEAR")
    clip:SetAllPoints()
    clip:SetRotation(clipRotation)
    tex:AddMaskTexture(clip)
    local prog = f:CreateMaskTexture()
    prog:SetTexture(MEDIA .. "half_disk.tga", "CLAMP", "CLAMP", "TRILINEAR")
    prog:SetAllPoints()
    prog:SetRotation(progRotation)
    tex:AddMaskTexture(prog)
    tex:Hide()
    return tex, prog
end

function Look.New(f)
    local p = {}
    p.border = f:CreateTexture(nil, "BACKGROUND")
    p.border:SetPoint("CENTER")
    p.ring = f:CreateTexture(nil, "BORDER")
    p.ring:SetAllPoints()
    p.ready = f:CreateTexture(nil, "ARTWORK")
    p.ready:SetAllPoints()

    local s = { frame = CreateFrame("Frame", nil, f) }
    s.frame:SetAllPoints()
    s.frame:SetFrameLevel(f:GetFrameLevel() + SWEEP_LEVEL)
    s.frame:Hide()
    s.right, s.rightProg = SweepHalf(s.frame, 0, PI)
    s.left, s.leftProg = SweepHalf(s.frame, PI, 0)
    p.sweep = s

    p.dot = f:CreateTexture(nil, "OVERLAY")
    p.dot:SetTexture(WHITE)
    p.dot:SetPoint("CENTER")
    return p
end

function Look.Shape(f, p)
    local shape = S.Get("mouseShape")
    local size = S.Get("mouseSize")
    size = size + size % 2
    f:SetSize(size, size)
    SetupTexture(p.border, shape)
    SetupTexture(p.ring, shape)
    SetupTexture(p.ready, shape)
    SetupTexture(p.sweep.right, shape)
    SetupTexture(p.sweep.left, shape)
    return size
end

function Look.Paint(p, alpha, melee, ready)
    local gcdOn = S.Get("mouseGCD")
    local size = S.Get("mouseSize")
    local meleeBorder = melee and S.Get("mouseMeleeBorder")
    if S.Get("mouseBorder") or meleeBorder then
        local bw = S.Get("mouseBorderWeight")
        local c = meleeBorder and RED or Color("mouseBorderColor", "mouseBorderClassColor")
        p.border:SetSize(size + bw * 2, size + bw * 2)
        p.border:SetVertexColor(c.r, c.g, c.b, alpha)
        p.border:Show()
    else
        p.border:Hide()
    end

    if gcdOn and S.Get("mouseHideBackground") then
        p.ring:Hide()
    else
        local c = melee and RED or Color("mouseColor", "mouseClassColor")
        p.ring:SetVertexColor(c.r, c.g, c.b, alpha)
        p.ring:Show()
    end

    if gcdOn and ready then
        local c = S.Get("mouseReadyMatch") and Color("mouseGCDColor", "mouseGCDClassColor")
            or S.Get("mouseReadyColor")
        if melee and S.Get("mouseMeleeRing") then c = RED end
        p.ready:SetVertexColor(c.r, c.g, c.b, alpha)
        p.ready:Show()
    else
        p.ready:Hide()
    end

    if S.Get("mouseDot") then
        local ds = S.Get("mouseDotSize")
        local c = Color("mouseDotColor", "mouseDotClassColor")
        p.dot:SetSize(ds, ds)
        p.dot:SetVertexColor(c.r, c.g, c.b, alpha)
        p.dot:Show()
    else
        p.dot:Hide()
    end
end

function Look.NewTrailPoint(f)
    local tex = f:CreateTexture(nil, "BACKGROUND")
    tex:SetBlendMode("ADD")
    tex:Hide()
    return tex
end

function Look.TrailPath()
    return MEDIA .. (TRAIL_SHAPES[S.Get("mouseTrailShape")] or TRAIL_SHAPES.glow)
end

function Look.TrailTexture(tex, path)
    tex:SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")
    tex:SetTexCoord(TRAIL_TEXEL, 1 - TRAIL_TEXEL, TRAIL_TEXEL, 1 - TRAIL_TEXEL)
end

function Look.TrailPoint(tex, i, fade, c, alpha, size, sparkle)
    local pc = sparkle and sparkleColors[(i - 1) % #sparkleColors + 1] or c
    tex:SetVertexColor(pc.r, pc.g, pc.b, fade * alpha)
    tex:SetSize(size * fade, size * fade)
    tex:Show()
end

local function Cursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return floor(x / scale + ROUND), floor(y / scale + ROUND)
end

local function OnSweepUpdate()
    if UpdateSweep() then UpdateRender() end
end

local function FadeIdle(self)
    if S.Get("mouseFadeIdle") then
        local idle = GetTime() - state.lastMove - S.Get("mouseFadeDelay")
        local target = S.Get("mouseFadeOpacity")
        state.idleAlpha = idle > 0 and max(target, 1 - idle / IDLE_FADE * (1 - target)) or 1
        self:SetAlpha(state.idleAlpha)
        if trail then trail:SetAlpha(state.idleAlpha) end
    elseif state.idleAlpha ~= 1 then
        state.idleAlpha = 1
        self:SetAlpha(1)
        if trail then trail:SetAlpha(1) end
    end
end

local function BuildRing()
    container = CreateFrame("Frame", "NaowhForeverMouseRing", UIParent)
    container:SetFrameStrata("TOOLTIP")
    container:EnableMouse(false)

    parts = Look.New(container)
    sweep = parts.sweep
    sweep.frame:SetScript("OnUpdate", OnSweepUpdate)

    local lastX, lastY = 0, 0
    container:SetScript("OnUpdate", function(self)
        local x, y = Cursor()
        if x ~= lastX or y ~= lastY then
            lastX, lastY = x, y
            state.lastMove = GetTime()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end
        FadeIdle(self)
    end)
end

local function BuildTrail()
    trail = CreateFrame("Frame", nil, UIParent)
    trail:SetFrameStrata("TOOLTIP")
    trail:SetFrameLevel(1)
    trail:SetPoint("BOTTOMLEFT")
    trail:SetSize(1, 1)
    trail:Hide()
    for i = 1, TRAIL_MAX do
        trailPoints[i] = { tex = Look.NewTrailPoint(trail), x = 0, y = 0, time = 0, active = false }
    end

    local head, lastX, lastY, acc, activeCount = 0, 0, 0, 0, 0
    local function Step(self, elapsed)
        acc = acc + elapsed
        if acc < TRAIL_TICK then return end
        acc = 0
        local now = GetTime()
        local tracking = S.Get("mouseTrail") and Visible()
        if tracking then
            local x, y = Cursor()
            local spacing = max(TRAIL_MIN_GAP, S.Get("mouseTrailSize") * TRAIL_GAP_SHARE)
            if (x - lastX) ^ 2 + (y - lastY) ^ 2 >= spacing * spacing then
                lastX, lastY = x, y
                head = head % S.Get("mouseTrailLength") + 1
                local pt = trailPoints[head]
                if not pt.active then activeCount = activeCount + 1 end
                pt.x, pt.y, pt.time, pt.active = x, y, now, true
            end
        end
        if activeCount > 0 then
            local duration = max(S.Get("mouseTrailDuration"), TRAIL_MIN_TIME)
            local c = Color("mouseTrailColor", "mouseTrailClassColor")
            local alpha = Opacity() * S.Get("mouseTrailBrightness")
            local size = S.Get("mouseTrailSize")
            local sparkle = S.Get("mouseTrailSparkle")
            for i = 1, TRAIL_MAX do
                local pt = trailPoints[i]
                if pt.active then
                    local fade = 1 - (now - pt.time) / duration
                    if fade <= 0 then
                        pt.active = false
                        pt.tex:Hide()
                        activeCount = activeCount - 1
                    else
                        pt.tex:ClearAllPoints()
                        pt.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pt.x, pt.y)
                        Look.TrailPoint(pt.tex, i, fade, c, alpha, size, sparkle)
                    end
                end
            end
        end
        if not tracking and activeCount == 0 then self:SetScript("OnUpdate", nil) end
    end
    trail:SetScript("OnShow", function(self) self:SetScript("OnUpdate", Step) end)
end

local function StyleTrail()
    local path = Look.TrailPath()
    for _, pt in ipairs(trailPoints) do Look.TrailTexture(pt.tex, path) end
end

local function StartSweep(mode, start, duration, modRate, c, alpha)
    sweepState.active, sweepState.mode = true, mode
    sweepState.start, sweepState.duration, sweepState.modRate = start, duration, modRate
    sweepState.r, sweepState.g, sweepState.b, sweepState.a = c.r, c.g, c.b, alpha
    sweep.frame:Show()
    UpdateSweep()
end

function UpdateRender()
    if not container then return end
    if not Visible() then
        container:Hide()
        if trail then trail:Hide() end
        return
    end
    container:Show()
    local alpha = Opacity()
    local melee = S.Get("mouseMelee") and state.outOfMelee
    local gcdOn = S.Get("mouseGCD")

    local sweepAlpha = alpha * S.Get("mouseGCDAlpha")
    if gcdOn and S.Get("mouseCastSwipe") and state.casting and state.castSwipeAllowed then
        StartSweep("cast", state.castStart, state.castEnd - state.castStart, 1,
            Color("mouseCastColor", "mouseCastClassColor"), sweepAlpha)
    elseif gcdOn and state.gcd and state.gcdSwipeAllowed then
        StartSweep("gcd", state.gcd.startTime, state.gcd.duration, state.gcd.modRate or 1,
            Color("mouseGCDColor", "mouseGCDClassColor"),
            state.gcdOwned and S.Get("mouseCastSwipe") and 0 or sweepAlpha)
    else
        sweepState.active, sweepState.mode = false, nil
        Look.HideSweep(sweep)
    end

    Look.Paint(parts, alpha, melee, not state.gcd and not state.casting)

    if trail then trail:SetShown(S.Get("mouseTrail")) end
end

local function StopAlarm()
    if alarmTicker then
        alarmTicker:Cancel()
        alarmTicker = nil
    end
end

local function PlayAlarm()
    UI._PlayLSMSound(UI.SoundPathFor(S.Get("mouseMeleeSoundKey")))
end

local function StartAlarm()
    StopAlarm()
    PlayAlarm()
    local every = S.Get("mouseMeleeSoundInterval")
    if every > 0 then alarmTicker = C_Timer.NewTicker(every, PlayAlarm) end
end

local function SetOutOfMelee(out)
    if out == state.outOfMelee then return end
    state.outOfMelee = out
    UpdateRender()
end

local function MeleeTick(_, elapsed)
    meleeAcc = meleeAcc + elapsed
    if meleeAcc < MELEE_TICK then return end
    meleeAcc = 0
    local inRange = C_Spell.IsSpellInRange(meleeSpell, "target")
    if inRange == nil or Secret(inRange) then return end
    if not inRange and state.lastInRange == true and S.Get("mouseMeleeSound") then StartAlarm() end
    if inRange then StopAlarm() end
    state.lastInRange = inRange
    SetOutOfMelee(not inRange)
end

local function EvaluateMelee()
    meleeSpell = ns.MeleeRangeSpell()
    if On() and S.Get("mouseMelee") and meleeSpell and UnitExists("target")
        and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
        meleeTicker:SetScript("OnUpdate", MeleeTick)
        if not S.Get("mouseMeleeSound") then StopAlarm() end
    else
        meleeTicker:SetScript("OnUpdate", nil)
        StopAlarm()
        state.lastInRange = nil
        SetOutOfMelee(false)
    end
end

local function AllowCastSwipe()
    state.castSwipeAllowed = true
    UpdateRender()
end

local function AllowGCDSwipe()
    state.gcdSwipeAllowed = true
    UpdateRender()
end

local function DelaySwipe(field, timerVar, allow)
    state[field] = false
    if timerVar then timerVar:Cancel() end
    return C_Timer.NewTimer(S.Get("mouseSwipeDelay"), allow)
end

local function ReadCast()
    state.castPending = false
    local _, _, _, startMs, endMs = UnitCastingInfo("player")
    if not startMs then _, _, _, startMs, endMs = UnitChannelInfo("player") end
    if startMs and not Secret(startMs) and not Secret(endMs) then
        local already = state.casting
        state.casting, state.castStart, state.castEnd = true, startMs / MS, endMs / MS
        if not already then castDelay = DelaySwipe("castSwipeAllowed", castDelay, AllowCastSwipe) end
    else
        state.casting = false
        if castDelay then castDelay:Cancel(); castDelay = nil end
        state.castSwipeAllowed = false
    end
end

local function ReadGCD()
    local info = C_Spell.GetSpellCooldown(ns.GCDSpell())
    if info and info.isOnGCD and not Secret(info.duration) and not Secret(info.startTime)
        and not Secret(info.modRate) then
        local wasReady = state.gcd == nil
        if wasReady or state.gcd.startTime ~= info.startTime then
            state.gcdOwned = state.castPending or state.casting
        end
        state.gcd = info
        if wasReady then gcdDelay = DelaySwipe("gcdSwipeAllowed", gcdDelay, AllowGCDSwipe) end
    else
        state.gcd = nil
        if gcdDelay then gcdDelay:Cancel(); gcdDelay = nil end
        state.gcdSwipeAllowed = true
    end
end

local function RefreshZone()
    state.inCombat = UnitAffectingCombat("player")
    local inInstance, kind = IsInInstance()
    state.inInstance = inInstance and (kind == "party" or kind == "raid" or kind == "pvp")
    state.afk = not state.inInstance and UnitIsAFK("player") or false
end

local function ResetMelee()
    state.lastInRange = nil
    StopAlarm()
    SetOutOfMelee(false)
    EvaluateMelee()
end

local function OnSent(castGUID, spellID)
    state.castPending, state.sentGUID = false, nil
    if not (S.Get("mouseGCD") and S.Get("mouseCastSwipe")) or Secret(spellID) or Secret(castGUID) then return end
    local info = C_Spell.GetSpellInfo(spellID)
    local castTime = info and info.castTime
    if not Secret(castTime) and castTime and castTime > 0 then
        state.castPending, state.sentGUID = true, castGUID
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, _, arg2, arg3, arg4)
    if RESET_MELEE[event] then
        ResetMelee()
        return
    elseif event == "UNIT_SPELLCAST_SENT" then
        OnSent(arg3, arg4)
        return
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if S.Get("mouseGCD") then ReadGCD() end
    elseif event:find("^UNIT_SPELLCAST") then
        if (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
            and state.sentGUID and not Secret(arg2) and arg2 == state.sentGUID then
            state.gcdOwned, state.sentGUID = false, nil
        end
        ReadCast()
    else
        RefreshZone()
    end
    UpdateRender()
end)

local function OnMouseWatch()
    local down = IsMouseButtonDown("RightButton")
    if down ~= state.rightDown then
        state.rightDown = down
        UpdateRender()
    end
end

mouseWatcher:SetScript("OnUpdate", OnMouseWatch)
mouseWatcher:Hide()

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        if container then container:Hide() end
        if trail then trail:Hide() end
        mouseWatcher:Hide()
        EvaluateMelee()
        return
    end
    if not container then
        BuildRing()
        BuildTrail()
    end
    Look.Shape(container, parts)
    StyleTrail()
    state.rightDown = false
    mouseWatcher:SetShown(S.Get("mouseHideOnClick"))
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    for _, event in ipairs(PLAYER_EVENTS) do events:RegisterUnitEvent(event, "player") end
    RefreshZone()
    ReadCast()
    ReadGCD()
    state.lastMove = GetTime()
    EvaluateMelee()
    UpdateRender()
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "crossMeleeSpell" or key:find("^mouse") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group
local RING_SHAPES = {
    { "ring.tga", "Circle" }, { "thin_ring.tga", "Thin Circle" }, { "thick_ring.tga", "Thick Circle" },
    { "nq_circle.tga", "Filled Circle" }, { "nq_circle_hard.tga", "Hard Circle" },
    { "nq_ring1.tga", "Ring 1" }, { "nq_ring2.tga", "Ring 2" }, { "nq_ring3.tga", "Ring 3" },
    { "nq_ring4.tga", "Ring 4" }, { "nq_ring_soft1.tga", "Soft Ring 1" },
    { "nq_ring_soft2.tga", "Soft Ring 2" }, { "nq_ring_soft3.tga", "Soft Ring 3" },
    { "nq_ring_soft4.tga", "Soft Ring 4" }, { "nq_glow.tga", "Glow" }, { "nq_glow_large.tga", "Large Glow" },
    { "nq_glow_reversed.tga", "Reversed Glow" }, { "nq_cross1.tga", "Cross 1" },
    { "nq_cross2.tga", "Cross 2" }, { "nq_cross3.tga", "Cross 3" }, { "nq_star.tga", "Star" },
    { "nq_swirl.tga", "Swirl" }, { "nq_sphere.tga", "Sphere" },
}
local SHAPE = { {}, {} }
for _, shape in ipairs(RING_SHAPES) do
    SHAPE[1][shape[1]] = shape[2]
    SHAPE[2][#SHAPE[2] + 1] = shape[1]
end
local TRAIL = { { glow = "Glow", circle = "Circle", ring = "Ring", star = "Star", sparkle = "Sparkle" },
    { "glow", "circle", "ring", "star", "sparkle" } }

local PREVIEW_FIT = ns.QoLConstants.CURSOR_PREVIEW_FIT
local PREVIEW_Y = ns.QoLConstants.CURSOR_PREVIEW_Y
local NOTE_Y, NOTE_SIZE = ns.Shared.Style.STAGE_NOTE_Y, ns.Shared.Style.STAGE_NOTE_SIZE
local TRAIL_DOTS = 5
local TRAIL_STEP = 8
local TRAIL_SPREAD = 0.5
local TRAIL_DROP = 0.5
local CAST_SHOWN = 0.6
local STATES = {
    { key = "combat", label = "In Combat", tip = "In a fight with your global cooldown ready, the cursor moving." },
    { key = "casting", label = "Casting", tip = "A cast part way through, swept around the ring." },
    { key = "idle", label = "Idle", tip = "The cursor left still.", needs = "mouseFadeIdle" },
}

local function OwnColour(on, classKey)
    return function() return S.Get(on) and not S.Get(classKey) end
end

local function OwnRingColour() return not S.Get("mouseClassColor") end
local function OwnReadyColour() return S.Get("mouseGCD") and not S.Get("mouseReadyMatch") end
local function OwnCastColour()
    return S.Get("mouseGCD") and S.Get("mouseCastSwipe") and not S.Get("mouseCastClassColor")
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    local scene = CreateFrame("Frame", nil, preview)
    scene:SetPoint("CENTER", 0, PREVIEW_Y)
    scene:SetSize(1, 1)
    preview.scene = scene
    preview.trail = CreateFrame("Frame", nil, scene)
    preview.trail:SetPoint("CENTER")
    preview.trail:SetSize(1, 1)
    preview.shape = CreateFrame("Frame", nil, scene)
    preview.shape:SetPoint("CENTER")
    preview.shape:SetFrameLevel(preview.trail:GetFrameLevel() + 1)
    preview.parts = Look.New(preview.shape)
    preview.dots = {}
    for i = 1, TRAIL_DOTS do preview.dots[i] = Look.NewTrailPoint(preview.trail) end
    preview.note = preview:CreateFontString(nil, "OVERLAY")
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y)
    preview.note:SetFont(ns.UIFontPath(), NOTE_SIZE, "")
    preview.note:SetTextColor(T.muted.r, T.muted.g, T.muted.b, 1)
    return preview
end

local function PaintTrail(preview, alpha, size)
    local dots = preview.dots
    if not S.Get("mouseTrail") then
        for i = 1, #dots do dots[i]:Hide() end
        return
    end
    local path = Look.TrailPath()
    local c = Color("mouseTrailColor", "mouseTrailClassColor")
    local dotSize = S.Get("mouseTrailSize")
    local sparkle = S.Get("mouseTrailSparkle")
    local step = max(TRAIL_STEP, dotSize * TRAIL_SPREAD)
    alpha = alpha * S.Get("mouseTrailBrightness")
    for i = 1, #dots do
        local tex = dots[i]
        Look.TrailTexture(tex, path)
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", preview.trail, "CENTER", -(size / 2 + i * step), -i * step * TRAIL_DROP)
        Look.TrailPoint(tex, i, 1 - i / (TRAIL_DOTS + 1), c, alpha, dotSize, sparkle)
    end
end

local function PaintPreview(preview, moment)
    local p = preview.parts
    local size = Look.Shape(preview.shape, p)
    preview.scene:SetScale(min(1, PREVIEW_FIT / max(1, size + S.Get("mouseBorderWeight") * 2)))
    local casting, idle = moment == "casting", moment == "idle"
    local alpha = S.Get("mouseOpacityCombat")
    local gcdOn = S.Get("mouseGCD")
    local note = ""

    if casting and gcdOn then
        local cast = S.Get("mouseCastSwipe")
        local c = cast and Color("mouseCastColor", "mouseCastClassColor") or Color("mouseGCDColor", "mouseGCDClassColor")
        p.sweep.frame:Show()
        Look.Sweep(p.sweep, CAST_SHOWN * TWO_PI, c.r, c.g, c.b, alpha * S.Get("mouseGCDAlpha"))
        if not cast then note = TEXT_NO_CAST end
    else
        Look.HideSweep(p.sweep)
        if casting then note = TEXT_NO_SWEEP end
    end
    Look.Paint(p, alpha, false, not casting)

    if idle then
        for i = 1, #preview.dots do preview.dots[i]:Hide() end
    else
        PaintTrail(preview, alpha, size)
    end

    local fade = 1
    if idle then
        fade = S.Get("mouseFadeOpacity")
        if fade <= 0 then note = TEXT_FADED end
    end
    preview.scene:SetAlpha(fade)
    preview.note:SetText(note)
end

local function Summary(store)
    return TEXT_SUMMARY:format(ns.L(SHAPE[1][store.Get("mouseShape")] or SHAPE[1]["ring.tga"]),
        store.Get("mouseSize"), store.Get("mouseGCD") and TEXT_GCD or "", store.Get("mouseTrail") and TEXT_TRAIL or "")
end

ns.Shared.Settings.Page("QoL/Cursor & Crosshair", S):Card({
    id = "mouseRing", name = "Mouse Ring", order = 20, switch = "mouseRing",
    help = "A ring around your cursor so you never lose it in a busy fight, with your global "
        .. "cooldown and casts swept around it.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Ring"),
        { key = "mouseShape", label = "Shape", choice = SHAPE },
        { key = "mouseSize", label = "Size", slider = SIZE_RANGE },
        { key = "mouseClassColor", label = "Class Color Ring", toggle = true },
        { key = "mouseColor", label = "Ring Color", colour = true, needs = OwnRingColour,
          why = "Class color is on" },
        { key = "mouseOpacityCombat", label = "Opacity In Combat", slider = OPACITY_RANGE, unit = "%",
          scale = PERCENT_SCALE, help = "Also used inside dungeons and raids." },
        { key = "mouseOpacityOOC", label = "Opacity Out of Combat", slider = OPACITY_RANGE, unit = "%",
          scale = PERCENT_SCALE },
        Group("When"),
        { key = "mouseShowOOC", label = "Show Out of Combat", toggle = true },
        { key = "mouseHideOnClick", label = "Hide While Right-Click Held", toggle = true,
          help = "Hidden while you turn the camera with the right mouse button." },
        { key = "mouseHideAfk", label = "Hide While Away", toggle = true,
          help = "Hidden while you are away, outside instances." },
        { key = "mouseFadeIdle", label = "Fade When Idle", toggle = true,
          help = "Fades out while the cursor stays still." },
        { key = "mouseFadeDelay", label = "Fade After (s)", slider = FADE_DELAY_RANGE, needs = "mouseFadeIdle" },
        { key = "mouseFadeOpacity", label = "Idle Opacity", slider = IDLE_OPACITY_RANGE, unit = "%", scale = PERCENT_SCALE,
          needs = "mouseFadeIdle" },
        Group("Border"),
        { key = "mouseBorder", label = "Border", toggle = true },
        { key = "mouseBorderWeight", label = "Border Width", slider = BORDER_RANGE, needs = "mouseBorder" },
        { key = "mouseBorderClassColor", label = "Class Color Border", toggle = true, needs = "mouseBorder" },
        { key = "mouseBorderColor", label = "Border Color", colour = true,
          needs = OwnColour("mouseBorder", "mouseBorderClassColor"), why = "Needs Border, class color off" },
        Group("Centre Dot"),
        { key = "mouseDot", label = "Centre Dot", toggle = true },
        { key = "mouseDotSize", label = "Dot Size", slider = DOT_RANGE, needs = "mouseDot" },
        { key = "mouseDotClassColor", label = "Class Color Dot", toggle = true, needs = "mouseDot" },
        { key = "mouseDotColor", label = "Dot Color", colour = true,
          needs = OwnColour("mouseDot", "mouseDotClassColor"), why = "Needs Centre Dot, class color off" },
        Group("GCD & Casts"),
        { key = "mouseGCD", label = "GCD Sweep", toggle = true,
          help = "Your global cooldown swept around the ring, and a ready ring once it is over." },
        { key = "mouseHideBackground", label = "Hide Ring Under the Sweep", toggle = true, needs = "mouseGCD",
          help = "Only the sweep and the ready ring show." },
        { key = "mouseGCDAlpha", label = "Sweep Opacity", slider = OPACITY_RANGE, unit = "%", scale = PERCENT_SCALE,
          needs = "mouseGCD" },
        { key = "mouseSwipeDelay", label = "Sweep Delay (s)", slider = SWEEP_DELAY_RANGE, needs = "mouseGCD",
          help = "Waits this long before a sweep starts, so one that is over at once does not flicker." },
        { key = "mouseGCDClassColor", label = "Class Color Sweep", toggle = true, needs = "mouseGCD" },
        { key = "mouseGCDColor", label = "Sweep Color", colour = true,
          needs = OwnColour("mouseGCD", "mouseGCDClassColor"), why = "Needs GCD Sweep, class color off" },
        { key = "mouseReadyMatch", label = "Ready Matches Sweep", toggle = true, needs = "mouseGCD" },
        { key = "mouseReadyColor", label = "Ready Color", colour = true, needs = OwnReadyColour,
          why = "Needs GCD Sweep, Ready Matches Sweep off" },
        { key = "mouseCastSwipe", label = "Cast Sweep", toggle = true, needs = "mouseGCD",
          help = "Your casts and channels swept around the ring too." },
        { key = "mouseCastClassColor", label = "Class Color Cast Sweep", toggle = true, needs = { "mouseGCD", "mouseCastSwipe" } },
        { key = "mouseCastColor", label = "Cast Sweep Color", colour = true, needs = OwnCastColour,
          why = "Needs Cast Sweep, class color off" },
        Group("Trail"),
        { key = "mouseTrail", label = "Trail", toggle = true, help = "A fading trail behind the cursor." },
        { key = "mouseTrailShape", label = "Trail Shape", choice = TRAIL, needs = "mouseTrail" },
        { key = "mouseTrailClassColor", label = "Class Color Trail", toggle = true, needs = "mouseTrail" },
        { key = "mouseTrailColor", label = "Trail Color", colour = true,
          needs = OwnColour("mouseTrail", "mouseTrailClassColor"), why = "Needs Trail, class color off" },
        { key = "mouseTrailSparkle", label = "Sparkle", toggle = true, needs = "mouseTrail",
          help = "Each point of the trail in a color of its own." },
        { key = "mouseTrailSize", label = "Trail Size", slider = TRAIL_SIZE_RANGE, needs = "mouseTrail" },
        { key = "mouseTrailLength", label = "Trail Length", slider = TRAIL_LENGTH_RANGE, needs = "mouseTrail" },
        { key = "mouseTrailDuration", label = "Trail Duration (s)", slider = TRAIL_TIME_RANGE, needs = "mouseTrail" },
        { key = "mouseTrailBrightness", label = "Trail Brightness", slider = BRIGHTNESS_RANGE, unit = "%",
          scale = PERCENT_SCALE, needs = "mouseTrail" },
        Group("Out of Melee Range"),
        { key = "mouseMelee", label = "Recolour Out of Melee Range", toggle = true,
          help = "Turns the ring red while your target is out of melee range. Uses the same ability "
              .. "as the crosshair's melee check, Melee Spell ID included." },
        { key = "mouseMeleeBorder", label = "Recolour Border", toggle = true, needs = "mouseMelee" },
        { key = "mouseMeleeRing", label = "Recolour Ready Ring", toggle = true, needs = { "mouseMelee", "mouseGCD" },
          help = "The ready ring shows with GCD Sweep on." },
        { key = "mouseMeleeSound", label = "Play a Sound", toggle = true, needs = "mouseMelee",
          help = "Plays as your target leaves melee range." },
        { key = "mouseMeleeSoundKey", label = "Sound", sound = true, needs = { "mouseMelee", "mouseMeleeSound" } },
        { key = "mouseMeleeSoundInterval", label = "Repeat Every (s)", slider = SOUND_REPEAT_RANGE,
          needs = { "mouseMelee", "mouseMeleeSound" },
          help = "Plays the sound again this often while out of range. 0 plays it once." },
    },
})
