-- XPBarFX.lua: the XP bar's effects and hover breakdown (ns.XPBarFX), used by XPBar.lua.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local FLAT = ns.Shared.Style.WHITE
local MEDIA = "Interface\\AddOns\\NaowhForever_QoL\\Media\\"
local STRIPES = MEDIA .. "XP\\stripes.tga"
local STAR = MEDIA .. "MouseRing\\nq_star.tga"

local LOOK = { SHEEN = 0.16, SHADE = 0.22, SPARK_W = 8, SPARK = 0.6, TICKS = 10, TICK_ALPHA = 0.35,
    TICK_SHARE = 0.2, TICK_MIN = 3, RESTED_ALPHA = 0.45, RESTED_EDGE = 0.95, LIFT = 1.6, STRIPE_ALPHA = 0.35 }
local PULSE = { FLASH = 0.9, FADE = 0.8, RISE = 18, HOLD = 0.35, TEXT_FADE = 0.9, SIZE = 13, GAP = 2, EDGE = 24,
    WAIT = 0.15 }
local READY = { LOW = 0.1, HIGH = 0.5, BEAT = 0.9, STAR = 16 }
local LEVEL = { FLASH = 0.75, IN = 0.15, DRAIN = 0.7, GONE = 0.01 }
local KILL = { BASE = 45, PER_LEVEL = 5, RESTED = 2 }
local GOLD = { r = 1, g = 0.82, b = 0.25 }
local RAISE = 6
local TIP = { justify = "LEFT" }
local TEXT = {
    GAIN = "+%s",
    PCT = "%.1f%%",
    LINE = "\n",
    LEFT = ns.L("XP to level: %s (%s)"),
    DONE = ns.L("Completed quests: %s"),
    ENOUGH = ns.L("Completed quests: %s, enough to level"),
    OPEN = ns.L("Quests in progress: %s"),
    RESTED = ns.L("Rested: %s"),
    KILLS = ns.L("About %d kills of your level"),
    PACE = ns.L("%s at your pace"),
}

local FX = { SETTLE = 0.2 }
ns.XPBarFX = FX

local lines = {}
local tipShown = false

local function Grouped(n)
    n = math.floor(n)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

local function Lift(c)
    return math.min(c * LOOK.LIFT, 1)
end

local function HideRegion(group)
    group:GetParent():Hide()
end

local function Fade(region, from, duration, delay)
    local group = region:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(from)
    alpha:SetToAlpha(0)
    alpha:SetDuration(duration)
    alpha:SetStartDelay(delay or 0)
    group:SetScript("OnFinished", HideRegion)
    return group
end

local function Beat(region)
    local group = region:CreateAnimationGroup()
    group:SetLooping("BOUNCE")
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(READY.LOW)
    alpha:SetToAlpha(READY.HIGH)
    alpha:SetDuration(READY.BEAT)
    return group
end

local function Rise(region)
    local group = Fade(region, 1, PULSE.TEXT_FADE, PULSE.HOLD)
    local move = group:CreateAnimation("Translation")
    move:SetOffset(0, PULSE.RISE)
    move:SetDuration(PULSE.HOLD + PULSE.TEXT_FADE)
    return group
end

local function Drain(region)
    local group = region:CreateAnimationGroup()
    local light = group:CreateAnimation("Alpha")
    light:SetFromAlpha(0)
    light:SetToAlpha(LEVEL.FLASH)
    light:SetDuration(LEVEL.IN)
    light:SetOrder(1)
    local shrink = group:CreateAnimation("Scale")
    if shrink.SetScaleFrom then
        shrink:SetScaleFrom(1, 1)
        shrink:SetScaleTo(LEVEL.GONE, 1)
    else
        shrink:SetFromScale(1, 1)
        shrink:SetToScale(LEVEL.GONE, 1)
    end
    shrink:SetOrigin("RIGHT", 0, 0)
    shrink:SetDuration(LEVEL.DRAIN)
    shrink:SetOrder(2)
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(LEVEL.FLASH)
    fade:SetToAlpha(0)
    fade:SetDuration(LEVEL.DRAIN)
    fade:SetOrder(2)
    group:SetScript("OnFinished", HideRegion)
    return group
end

local function Flat(parent, layer, sub, blend)
    local tex = parent:CreateTexture(nil, layer, nil, sub)
    tex:SetTexture(FLAT)
    if blend then tex:SetBlendMode(blend) end
    return tex
end

function FX.New(b)
    local track = b.track
    b.restedEdge = track:CreateTexture(nil, "ARTWORK", nil, 2)
    b.restedEdge:SetWidth(1)
    b.stripes = track:CreateTexture(nil, "ARTWORK", nil, 1)
    b.stripes:SetTexture(STRIPES, "REPEAT", "REPEAT")
    b.stripes:SetHorizTile(true)
    b.stripes:SetVertTile(true)
    b.stripes:SetAllPoints(b.rested)
    b.stripes:Hide()

    b.sheen = Flat(track, "OVERLAY", 0)
    b.sheen:SetPoint("TOPLEFT")
    b.sheen:SetPoint("TOPRIGHT")
    b.sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, LOOK.SHEEN))
    b.shade = Flat(track, "OVERLAY", 0)
    b.shade:SetPoint("BOTTOMLEFT")
    b.shade:SetPoint("BOTTOMRIGHT")
    b.shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, LOOK.SHADE), CreateColor(0, 0, 0, 0))
    b.spark = Flat(track, "OVERLAY", 2, "ADD")
    b.spark:SetWidth(LOOK.SPARK_W)
    b.spark:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, LOOK.SPARK))
    b.ticks = {}
    for i = 1, LOOK.TICKS - 1 do
        local t = track:CreateTexture(nil, "OVERLAY", nil, 1)
        t:SetColorTexture(0, 0, 0, LOOK.TICK_ALPHA)
        t:SetWidth(1)
        b.ticks[i] = t
    end

    b.readyGlow = Flat(track, "OVERLAY", 3, "ADD")
    b.readyGlow:SetAllPoints(b.done)
    b.readyGlow:Hide()
    b.readyBeat = Beat(b.readyGlow)
    b.gain = Flat(track, "OVERLAY", 4, "ADD")
    b.gain:Hide()
    b.gainFade = Fade(b.gain, PULSE.FLASH, PULSE.FADE)
    b.levelFlash = Flat(track, "OVERLAY", 5, "ADD")
    b.levelFlash:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 1)
    b.levelFlash:SetPoint("TOPLEFT")
    b.levelFlash:SetPoint("BOTTOMLEFT")
    b.levelFlash:Hide()
    b.levelDrain = Drain(b.levelFlash)

    b.fx = CreateFrame("Frame", nil, b)
    b.fx:SetAllPoints()
    b.fx:SetFrameLevel(b:GetFrameLevel() + RAISE)
    b.star = b.fx:CreateTexture(nil, "OVERLAY")
    b.star:SetTexture(STAR)
    b.star:SetSize(READY.STAR, READY.STAR)
    b.star:SetPoint("CENTER", b, "TOPRIGHT")
    b.star:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 1)
    b.star:Hide()
    b.starBeat = Beat(b.star)
    b.gainText = ns.Font(b.fx, PULSE.SIZE, "OUTLINE")
    b.gainText:Hide()
    b.gainRise = Rise(b.gainText)
end

function FX.Paint(b, quest, rested)
    b.rested:SetVertexColor(rested.r, rested.g, rested.b, LOOK.RESTED_ALPHA)
    b.restedEdge:SetColorTexture(Lift(rested.r), Lift(rested.g), Lift(rested.b), LOOK.RESTED_EDGE)
    b.stripes:SetVertexColor(Lift(rested.r), Lift(rested.g), Lift(rested.b), LOOK.STRIPE_ALPHA)
    b.readyGlow:SetVertexColor(Lift(quest.r), Lift(quest.g), Lift(quest.b), 1)
    b.gainText:SetTextColor(Lift(quest.r), Lift(quest.g), Lift(quest.b), 1)
end

function FX.Size(b, w, h)
    b.sheen:SetHeight(h / 2)
    b.shade:SetHeight(h / 3)
    local notches = S.Get("xpBarNotches")
    local notch = math.max(LOOK.TICK_MIN, math.floor(h * LOOK.TICK_SHARE + 0.5))
    for i, t in ipairs(b.ticks) do
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", math.floor(w * i / LOOK.TICKS + 0.5), 0)
        t:SetHeight(notch)
        t:SetShown(notches)
    end
end

local function Pulse(b, from, to, total, amount)
    if to > from + 1 then
        b.gain:ClearAllPoints()
        b.gain:SetPoint("TOPLEFT", from, 0)
        b.gain:SetPoint("BOTTOMLEFT", from, 0)
        b.gain:SetWidth(to - from)
        b.gain:Show()
        b.gainFade:Stop()
        b.gainFade:Play()
    end
    b.gainText:SetText(TEXT.GAIN:format(Grouped(amount)))
    b.gainText:ClearAllPoints()
    b.gainText:SetPoint("BOTTOM", b, "TOPLEFT", math.min(math.max(to, PULSE.EDGE), total - PULSE.EDGE), PULSE.GAP)
    b.gainText:Show()
    b.gainRise:Stop()
    b.gainRise:Play()
end

local function Ready(b, on)
    if on then
        b.readyGlow:Show()
        b.star:Show()
        if not b.readyBeat:IsPlaying() then
            b.readyBeat:Play()
            b.starBeat:Play()
        end
    elseif b.readyGlow:IsShown() then
        b.readyBeat:Stop()
        b.starBeat:Stop()
        b.readyGlow:Hide()
        b.star:Hide()
    end
end

function FX.Segments(b, total, x, restedEnd, ready, perXP)
    local shine = S.Get("xpBarShine")
    b.sheen:SetShown(shine)
    b.shade:SetShown(shine)
    b.spark:ClearAllPoints()
    b.spark:SetPoint("TOPRIGHT", b.track, "TOPLEFT", x, 0)
    b.spark:SetPoint("BOTTOMRIGHT", b.track, "BOTTOMLEFT", x, 0)
    b.spark:SetShown(shine and x >= LOOK.SPARK_W and x < total)
    if restedEnd and restedEnd < total then
        b.restedEdge:ClearAllPoints()
        b.restedEdge:SetPoint("TOPLEFT", restedEnd - 1, 0)
        b.restedEdge:SetPoint("BOTTOMLEFT", restedEnd - 1, 0)
        b.restedEdge:Show()
    else
        b.restedEdge:Hide()
    end
    b.stripes:SetShown(restedEnd ~= nil and S.Get("xpBarRestedStripes"))
    Ready(b, ready and S.Get("xpBarReadyGlow"))
    local gained = b.fxGain
    if gained and (x ~= b.fxFillX or GetTime() - b.fxGainAt >= PULSE.WAIT) then
        b.fxGain = nil
        Pulse(b, math.max(0, x - gained * (perXP or 0)), x, total, gained)
    end
    b.fxFillX = x
end

function FX.Gain(b, amount, at)
    if not S.Get("xpBarGainPulse") then return end
    b.fxGain = (b.fxGain or 0) + amount
    b.fxGainAt = at or GetTime()
end

function FX.LevelUp(b)
    if not S.Get("xpBarLevelFlash") then return end
    b.levelFlash:SetWidth(math.max(b.track:GetWidth(), 1))
    b.levelFlash:Show()
    b.levelDrain:Stop()
    b.levelDrain:Play()
end

function FX.Kills(level, left, rested)
    local kill = KILL.BASE + KILL.PER_LEVEL * level
    local boosted = math.min(math.ceil(left / (KILL.RESTED * kill)), math.floor(rested / kill))
    local rest = left - boosted * KILL.RESTED * kill
    return boosted + math.max(0, math.ceil(rest / kill))
end

function FX.ShowBreakdown(b, d)
    wipe(lines)
    lines[1] = TEXT.LEFT:format(Grouped(d.left), TEXT.PCT:format(d.leftPct))
    if d.done > 0 then lines[#lines + 1] = (d.ready and TEXT.ENOUGH or TEXT.DONE):format(Grouped(d.done)) end
    if d.open > 0 then lines[#lines + 1] = TEXT.OPEN:format(Grouped(d.open)) end
    if d.rested > 0 then lines[#lines + 1] = TEXT.RESTED:format(Grouped(d.rested)) end
    lines[#lines + 1] = TEXT.KILLS:format(FX.Kills(d.level, d.left, d.rested))
    if d.pace then lines[#lines + 1] = TEXT.PACE:format(d.pace) end
    ns.UI.ShowWidgetTooltip(b, table.concat(lines, TEXT.LINE), TIP)
    tipShown = true
end

function FX.HideBreakdown()
    if not tipShown then return end
    tipShown = false
    ns.UI.HideWidgetTooltip()
end

function FX.Rows(Group)
    return {
        Group("Effects"),
        { key = "xpBarShine", label = "Shine", toggle = true,
          help = "A soft shine along the top of the bar and a glow where your XP ends." },
        { key = "xpBarNotches", label = "Notches", toggle = true,
          help = "Slim marks along the bottom of the bar at every 10%." },
        { key = "xpBarRestedStripes", label = "Rested Stripes", toggle = true,
          help = "Fine diagonal stripes on the rested band." },
        { key = "xpBarGainPulse", label = "Quest XP Pulse", toggle = true,
          help = "The XP from a quest you hand in flashes on the bar and its amount rises off it." },
        { key = "xpBarReadyGlow", label = "Ready to Level", toggle = true,
          help = "Your completed quests glow, with a star on the bar, when handing them in would level you." },
        { key = "xpBarLevelFlash", label = "Level-Up Flash", toggle = true,
          help = "The bar flashes gold and drains back to empty when you level up." },
        { key = "xpBarBreakdown", label = "Hover Breakdown", toggle = true,
          help = "Hovering the bar shows your XP to level, quest and rested XP, and about how many kills are left." },
    }
end
