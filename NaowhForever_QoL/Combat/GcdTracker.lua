-- GcdTracker.lua: GCD Tracker, your recent casts as scrolling icons over a bar of busy time and gaps.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI

local GCD_BLUE = { r = 0.01, g = 0.56, b = 0.91 }
local GLOW_ALPHA = 0.7
local BORDER_ALPHA = 0.8
local FAILED_TINT = { r = 1, g = 0.3, b = 0.3 }
local FAILED_BORDER = { r = 0.8, g = 0.1, b = 0.1, a = 0.9 }
local PLAIN_BORDER = { r = 0, g = 0, b = 0, a = 0.8 }
local FLAT = ns.Shared.Style.WHITE

local GCD_SPELLS = {
    WARRIOR = 6673, PALADIN = 635, HUNTER = 1978, ROGUE = 1752, PRIEST = 585,
    SHAMAN = 403, MAGE = 133, WARLOCK = 686, DRUID = 5176,
}
local STACK_WINDOW = 0.3
local DEDUP_WINDOW = 0.15
local TIMELINE_GAP = 3
local UPDATE_INTERVAL = 0.025
local LOGIN_QUIET = 5
local DOWNTIME_TICK = 0.033
local MIN_DOWNTIME_FIGHT = 15
local GCD_GLOW_AGE = 2
local SEGMENT_LENGTH = 1
local SEGMENT_ALPHA = 0.6
local SPEED_PER_ICON = 1.5
local MIN_FADE = 0.05
local ICON_CROP = ns.QoLConstants.ICON_CROP
local EDGE_OUT = ns.QoLConstants.EDGE_OUT
local FALLBACK_ICON = 136243
local FRAME_W, FRAME_H = 200, 40
local DEFAULT_Y = -100
local PERCENT = ns.QoLConstants.PERCENT
local DURATION_RANGE, FADE_FROM_RANGE, ICON_RANGE = { 2, 15, 1 }, { 0, 95, 5 }, { 16, 64, 1 }
local SPACING_RANGE, TIMELINE_RANGE = { 0, 20, 1 }, { 1, 12, 1 }
local PERCENT_SCALE = ns.Shared.Style.PERCENT_SCALE
local MOVER_LABEL = "GCD Tracker"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Combat", "QoL/Combat:gcdTracker"
local TEXT_DOWNTIME = ns.L("Downtime: %.1fs (%.1f%% of the fight)")
local SUMMARY = ns.L("The last %ds, scrolling %s%s")
local SUMMARY_COMBAT = ns.L(", in combat")

local DIRECTIONS = {
    LEFT = { x = -1, y = 0, px = 0, py = -1 }, RIGHT = { x = 1, y = 0, px = 0, py = -1 },
    UP = { x = 0, y = 1, px = 1, py = 0 }, DOWN = { x = 0, y = -1, px = 1, py = 0 },
}
local ZONE_KEYS = { party = "gcdDungeon", raid = "gcdRaid", pvp = "gcdPvP", arena = "gcdPvP" }
local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }
local UNIT_EVENTS = { "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP" }

local frame, unlocked, inCombat, zoneAllowed = nil, false, false, true
local history, segments = {}, {}
local iconPool, segPool = {}, {}
local byGUID, lastBySpell, lastByName = {}, {}, {}
local channelName, quietUntil = nil, 0
local wasActive = false
local combatStart, downtime, idleSince, downtimeTicker = 0, 0, nil, nil
local blocked = {}
local acc = 0
local awake = false

function ns.GCDSpell()
    return GCD_SPELLS[select(2, UnitClass("player"))]
end

local function On()
    return S.Get("enabled") and S.Get("gcdTracker")
end

local function Blocked(spellID)
    return blocked[spellID]
end

local function GCDActive()
    local info = C_Spell.GetSpellCooldown(ns.GCDSpell())
    return info and info.isOnGCD == true
end

local function Casting()
    return UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil
end

local function Busy()
    return GCDActive() or Casting()
end

local function Fade(fraction)
    local start = S.Get("gcdFadeStart")
    if fraction <= start then return 1 end
    return math.max(MIN_FADE, 1 - (fraction - start) / (1 - start))
end

local function NewIcon()
    local f = CreateFrame("Frame", nil, frame)
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    ns.PixelInset(f.glow, EDGE_OUT)
    local blue = ns.ThemeTint("accent", GCD_BLUE)
    f.glow:SetColorTexture(blue.r, blue.g, blue.b, GLOW_ALPHA)
    f.border = f:CreateTexture(nil, "BORDER")
    ns.PixelInset(f.border, EDGE_OUT)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    return f
end

local function NewSeg()
    local f = CreateFrame("Frame", nil, frame)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    return f
end

local function Release(pool, f)
    f:Hide()
    f:ClearAllPoints()
    pool[#pool + 1] = f
end

local function Paint(f, entry, onGCD)
    if entry.casting or onGCD then
        f.glow:Show()
        f.tex:SetDesaturated(false)
        f.tex:SetVertexColor(1, 1, 1)
        local blue = ns.ThemeTint("accent", GCD_BLUE)
        f.border:SetColorTexture(blue.r, blue.g, blue.b, BORDER_ALPHA)
    elseif entry.failed then
        f.glow:Hide()
        f.tex:SetDesaturated(true)
        f.tex:SetVertexColor(FAILED_TINT.r, FAILED_TINT.g, FAILED_TINT.b)
        f.border:SetColorTexture(FAILED_BORDER.r, FAILED_BORDER.g, FAILED_BORDER.b, FAILED_BORDER.a)
    else
        f.glow:Hide()
        f.tex:SetDesaturated(false)
        f.tex:SetVertexColor(1, 1, 1)
        f.border:SetColorTexture(PLAIN_BORDER.r, PLAIN_BORDER.g, PLAIN_BORDER.b, PLAIN_BORDER.a)
    end
end

local function ExpireHistory(now, duration)
    while history[1] and now - history[1].time > duration do
        local entry = table.remove(history, 1)
        if entry.frame then Release(iconPool, entry.frame) end
        if entry.guid then byGUID[entry.guid] = nil end
    end
end

local function DrawIcon(entry, now, duration, size, spacing, speed, dir, gcdActive)
    local f = entry.frame
    if not f then
        f = table.remove(iconPool) or NewIcon()
        f.tex:SetTexture(entry.icon)
        entry.frame = f
    end
    local age = now - entry.time
    local offset, lane = age * speed, entry.lane * (size + spacing)
    f:SetSize(size, size)
    f:ClearAllPoints()
    f:SetPoint("CENTER", frame, "CENTER", dir.x * offset + dir.px * lane, dir.y * offset + dir.py * lane)
    Paint(f, entry, not entry.casting and not entry.failed and gcdActive and age < GCD_GLOW_AGE)
    f:SetAlpha(Fade(age / duration))
    f:Show()
end

local function TrackActivity(now, gcdActive)
    local active = gcdActive or Casting()
    local last = segments[#segments]
    if active then
        if not last or last.stop or now - last.start >= SEGMENT_LENGTH then
            if last and not last.stop then last.stop = now end
            segments[#segments + 1] = { start = now }
        end
    elseif wasActive and last and not last.stop then
        last.stop = now
    end
    wasActive = active
end

local function ExpireSegments(now, duration)
    while segments[1] and now - segments[1].start > duration do
        local seg = table.remove(segments, 1)
        if seg.frame then Release(segPool, seg.frame) end
    end
end

local function SegmentFrame(seg, texture)
    local f = seg.frame
    if not f then
        f = table.remove(segPool) or NewSeg()
        seg.frame = f
    end
    if f.texture ~= texture then
        f.texture = texture
        f.tex:SetTexture(texture)
    end
    return f
end

local function DrawSegments(now, duration, size, speed, dir)
    local height = S.Get("gcdTimelineHeight")
    local c = S.Get("gcdTimelineColor")
    local texture = UI.TexturePath(S.Get("gcdTexture"), FLAT)
    local perp = size / 2 + TIMELINE_GAP + height / 2
    for _, seg in ipairs(segments) do
        local startAge = math.min(now - seg.start, duration)
        local startOff, stopOff = startAge * speed, (seg.stop and now - seg.stop or 0) * speed
        local length, mid = math.max(1, startOff - stopOff), (startOff + stopOff) / 2
        local f = SegmentFrame(seg, texture)
        f.tex:SetVertexColor(c.r, c.g, c.b, SEGMENT_ALPHA)
        f:ClearAllPoints()
        if dir.x ~= 0 then
            f:SetSize(length, height)
            f:SetPoint("CENTER", frame, "CENTER", dir.x * mid, -perp)
        else
            f:SetSize(height, length)
            f:SetPoint("CENTER", frame, "CENTER", perp, dir.y * mid)
        end
        f:SetAlpha(Fade(startAge / duration))
        f:Show()
    end
end

local function Layout()
    local now = GetTime()
    local duration = S.Get("gcdDuration")
    local size, spacing = S.Get("gcdIconSize"), S.Get("gcdSpacing")
    local dir = DIRECTIONS[S.Get("gcdDirection")] or DIRECTIONS.RIGHT
    local speed = (size + spacing) * SPEED_PER_ICON
    local gcdActive = GCDActive()
    ExpireHistory(now, duration)
    for _, entry in ipairs(history) do
        DrawIcon(entry, now, duration, size, spacing, speed, dir, gcdActive)
    end
    TrackActivity(now, gcdActive)
    ExpireSegments(now, duration)
    DrawSegments(now, duration, size, speed, dir)
end

local function Tick(_, elapsed)
    acc = acc + elapsed
    if acc < UPDATE_INTERVAL then return end
    acc = 0
    Layout()
    if not (history[1] or segments[1] or wasActive) then
        awake = false
        frame:SetScript("OnUpdate", nil)
    end
end

local function Wake()
    if awake or not frame then return end
    awake = true
    frame:SetScript("OnUpdate", Tick)
end

local function Visible()
    if unlocked then return true end
    if not On() then return false end
    if S.Get("gcdCombatOnly") and not inCombat then return false end
    return zoneAllowed
end

local function Add(spellID, casting, guid)
    local now = GetTime()
    local prev = history[#history]
    local lane = (S.Get("gcdStack") and prev and now - prev.time <= STACK_WINDOW) and prev.lane + 1 or 0
    local entry = { spellID = spellID, icon = C_Spell.GetSpellTexture(spellID) or FALLBACK_ICON,
        time = now, lane = lane, casting = casting, guid = guid }
    history[#history + 1] = entry
    if guid then byGUID[guid] = entry end
end

local function Duplicate(spellID, name, now)
    return (lastBySpell[spellID] and now - lastBySpell[spellID] < DEDUP_WINDOW)
        or (name and lastByName[name] and now - lastByName[name] < DEDUP_WINDOW)
end

local function OnSucceeded(guid, spellID)
    local tracked = guid and byGUID[guid]
    if tracked then
        tracked.casting = false
        return
    end
    if Blocked(spellID) then return end
    local now = GetTime()
    local name = C_Spell.GetSpellName(spellID)
    if channelName and name == channelName then return end
    if Duplicate(spellID, name, now) then return end
    lastBySpell[spellID] = now
    if name then lastByName[name] = now end
    Add(spellID, false, guid)
end

local function OnFailed(guid)
    local tracked = guid and byGUID[guid]
    if not tracked then return end
    tracked.casting, tracked.failed = false, true
    byGUID[guid] = nil
end

local function TrackDowntime()
    local busy = Busy()
    if not busy and not idleSince then
        idleSince = GetTime()
    elseif busy and idleSince then
        downtime = downtime + GetTime() - idleSince
        idleSince = nil
    end
end

local function CombatStart()
    inCombat = true
    if not S.Get("gcdDowntime") then return end
    combatStart, downtime = GetTime(), 0
    idleSince = not Busy() and combatStart or nil
    if downtimeTicker then downtimeTicker:Cancel() end
    downtimeTicker = C_Timer.NewTicker(DOWNTIME_TICK, TrackDowntime)
end

local function ReportDowntime()
    downtimeTicker:Cancel()
    downtimeTicker = nil
    if idleSince then downtime = downtime + GetTime() - idleSince end
    idleSince = nil
    local length = GetTime() - combatStart
    if length > MIN_DOWNTIME_FIGHT then
        ns.Print(TEXT_DOWNTIME:format(downtime, downtime / length * PERCENT))
    end
end

local function CombatEnd()
    inCombat = false
    if downtimeTicker then ReportDowntime() end
    wipe(lastBySpell)
    wipe(lastByName)
    local last = segments[#segments]
    if last and not last.stop then last.stop = GetTime() end
    wasActive = false
end

local function RefreshZone()
    local _, kind = IsInInstance()
    zoneAllowed = S.Get(ZONE_KEYS[kind] or "gcdWorld")
end

local function Place()
    local pos = S.Get("gcdTrackerPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function OnCast(event, guid, spellID)
    if event == "UNIT_SPELLCAST_START" then
        if not Blocked(spellID) then Add(spellID, true, guid) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSucceeded(guid, spellID)
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        OnFailed(guid)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        channelName = C_Spell.GetSpellName(spellID)
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        channelName = nil
    end
end

local function OnEvent(_, event, unit, guid, spellID)
    if unit == "player" then Wake() end
    if event == "PLAYER_REGEN_DISABLED" then
        CombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        CombatEnd()
    elseif event == "PLAYER_ENTERING_WORLD" then
        quietUntil = GetTime() + LOGIN_QUIET
        RefreshZone()
    elseif GetTime() >= quietUntil and Visible() then
        OnCast(event, guid, spellID)
    end
    frame:SetShown(Visible())
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)

local function SavePosition(pos)
    S.Set("gcdTrackerPos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverGcdTracker", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetSize(FRAME_W, FRAME_H)
    frame.mover = UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
end

local function ReadBlocklist()
    wipe(blocked)
    for id in S.Get("gcdBlocklist"):gmatch("%d+") do blocked[tonumber(id)] = true end
end

local function Register()
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    for _, event in ipairs(UNIT_EVENTS) do events:RegisterUnitEvent(event, "player") end
end

local function Apply()
    events:UnregisterAllEvents()
    if not (On() or unlocked) then
        if frame then frame:Hide() end
        if downtimeTicker then downtimeTicker:Cancel(); downtimeTicker = nil end
        return
    end
    if not frame then Build() end
    Wake()
    Place()
    frame.mover:SetShown(unlocked == true)
    ReadBlocklist()
    inCombat = UnitAffectingCombat("player")
    RefreshZone()
    if On() then Register() end
    frame:SetShown(Visible())
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^gcd") and key ~= "gcdTrackerPos") then Apply() end
end

local function OnLogin()
    quietUntil = GetTime() + LOGIN_QUIET
    Apply()
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
boot:SetScript("OnEvent", OnLogin)

local Group = ns.Shared.Settings.Group
local DIRECTION = { { RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" }, { "RIGHT", "LEFT", "UP", "DOWN" } }

local function Summary(store)
    local way = DIRECTION[1][store.Get("gcdDirection")] or DIRECTION[1].RIGHT
    return SUMMARY:format(store.Get("gcdDuration"), way:lower(),
        store.Get("gcdCombatOnly") and SUMMARY_COMBAT or "")
end

ns.Shared.Settings.Page("QoL/Combat", S):Card({
    id = "gcdTracker", name = "GCD Tracker", order = 60, switch = "gcdTracker",
    help = "Your recent casts as icons scrolling away from a point, with a bar underneath while "
        .. "you were casting or on the global cooldown. Gaps in the bar are time spent doing "
        .. "nothing. Move it in the HUD Editor.",
    summary = Summary,
    rows = {
        Group("When"),
        { key = "gcdCombatOnly", label = "Only In Combat", toggle = true },
        { key = "gcdWorld", label = "Show in the World", toggle = true },
        { key = "gcdDungeon", label = "Show in Dungeons", toggle = true },
        { key = "gcdRaid", label = "Show in Raids", toggle = true },
        { key = "gcdPvP", label = "Show in Battlegrounds", toggle = true },
        Group("Icons"),
        { key = "gcdDirection", label = "Direction", choice = DIRECTION },
        { key = "gcdDuration", label = "Time Shown", slider = DURATION_RANGE, unit = "s" },
        { key = "gcdFadeStart", label = "Fade From", slider = FADE_FROM_RANGE, unit = "%", scale = PERCENT_SCALE,
          help = "How far along an icon starts to fade, from 0% (at once) to 95% (at the very end)." },
        { key = "gcdStack", label = "Stack Overlapping Casts", toggle = true,
          help = "Casts within 0.3s of each other sit side by side instead of on top of each other." },
        { key = "gcdBlocklist", label = "Hidden Spells", text = true, wide = true,
          help = "Spell IDs never shown, separated by commas. 6603 is Auto Attack, 75 is Auto Shot." },
        Group("Activity Bar"),
        { key = "gcdDowntime", label = "Downtime Summary", toggle = true,
          help = "After each fight longer than 15 seconds, how long you spent neither casting nor on "
              .. "the global cooldown, in chat." },
        Group("Size"),
        { key = "gcdIconSize", label = "Icon Size", slider = ICON_RANGE },
        { key = "gcdSpacing", label = "Spacing", slider = SPACING_RANGE },
        { key = "gcdTimelineHeight", label = "Activity Bar Height", slider = TIMELINE_RANGE },
        ns.Shared.Settings.Look("gcd", { bar = "Flat" }),
        Group("Colors"),
        { key = "gcdTimelineColor", label = "Activity Bar Color", colour = true },
    },
})
