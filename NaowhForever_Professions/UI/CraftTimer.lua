-- CraftTimer.lua: Total Craft Timer: one bar for a batch of crafts, on the Flight Timer's spot, in place of the cast bar.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local Style = P.Style
local Widgets = P.Widgets
local Parts = ns.Shared.Parts

local ROUND = 0.5
local WIDTH, TRACK_H, PIN, NAME_SIZE, ICON = 420, 20, 18, 14, 30
local SIDE_GAP = 10
local TIME_LARGER = 4
local LABEL_GAP = 4
local LABEL_SHARE = 0.47
local LABEL_LEVEL = 3
local TIME_SIZE = 18
local HEIGHT = PIN + 2 * (NAME_SIZE + 8)
local GAP = 0.3
local GUESS_CAST = 3
local MIN_BATCH = 2
local STALE = 5
local WATCH_EVERY = 1
local MS = 1000
local SECONDS_PER_MINUTE = 60
local FALLBACK_DROP = -150
local CASTING_SPELL = 9
local CAST_BARS = { "ERB_CastBarFrame", "PlayerCastingBarFrame", "CastingBarFrame" }
local SIDES = { "LEFT", "RIGHT" }
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED" }
local TEXT_CLOCK = "%d:%02d"
local TEXT_DONE = ns.L("%d / %d crafted")

local job
local bar, watch
local hidden = {}
local hooked = false
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("craftTimer")
end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds + ROUND))
    return TEXT_CLOCK:format(math.floor(seconds / SECONDS_PER_MINUTE), seconds % SECONDS_PER_MINUTE)
end

local function HideCastBars()
    for _, name in ipairs(CAST_BARS) do
        local frame = _G[name]
        if frame and frame.SetAlpha then
            if hidden[frame] == nil then hidden[frame] = frame:GetAlpha() end
            if frame:GetAlpha() ~= 0 then frame:SetAlpha(0) end
        end
    end
end

local function RestoreCastBars()
    for frame, alpha in pairs(hidden) do frame:SetAlpha(alpha) end
    wipe(hidden)
end

local Look = {}
P.CraftTimerLook = Look

function Look.New(parent, name)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(WIDTH, HEIGHT)
    local track = CreateFrame("StatusBar", nil, frame)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(TRACK_H)
    track:SetMinMaxValues(0, 1)
    frame.bg = ns.Solid(track, "BACKGROUND", T.bg)
    frame.bg:SetAllPoints()
    ns.Border(track, Style.BORDER_RGB)
    frame.track = track
    local over = CreateFrame("Frame", nil, frame)
    over:SetAllPoints()
    over:SetFrameLevel(track:GetFrameLevel() + LABEL_LEVEL)
    frame.labels = {}
    for i, side in ipairs(SIDES) do
        local label = ns.Font(over, NAME_SIZE, "OUTLINE")
        label:SetWordWrap(false)
        label:SetPoint("BOTTOM" .. side, track, "TOP" .. side, 0, LABEL_GAP)
        label:SetWidth(WIDTH * LABEL_SHARE)
        label:SetJustifyH(side)
        frame.labels[i] = label
    end
    frame.time = ns.Font(frame, TIME_SIZE, "OUTLINE", T.accentSoft)
    frame.time:SetPoint("RIGHT", frame, "LEFT", -SIDE_GAP, 0)
    local icon = CreateFrame("Frame", nil, frame)
    icon:SetSize(ICON, ICON)
    icon:SetPoint("LEFT", frame, "RIGHT", SIDE_GAP, 0)
    ns.Border(icon, Style.BORDER_RGB)
    frame.icon = Widgets.Crop(icon:CreateTexture(nil, "ARTWORK"))
    frame.icon:SetAllPoints()
    return frame
end

function Look.Style(frame)
    local font, size, outline = S.Get("craftTimerFont"), S.Get("craftTimerFontSize"), S.Get("craftTimerOutline")
    for _, label in ipairs(frame.labels) do Parts.HudFont(label, font, size, outline) end
    Parts.HudFont(frame.time, font, size + TIME_LARGER, outline)
    frame.track:SetStatusBarTexture(ns.UI.TexturePath(S.Get("craftTimerTexture"), Style.GRADIENT))
    frame.track:SetStatusBarColor(T.accent.r, T.accent.g, T.accent.b)
    frame.bg:SetColorTexture(T.bg.r, T.bg.g, T.bg.b, S.Get("craftTimerBgAlpha"))
end

function Look.Fill(frame, icon, name, done, count)
    frame.icon:SetTexture(icon)
    frame.labels[1]:SetText(name or "")
    frame.labels[2]:SetText(TEXT_DONE:format(done, count))
end

function Look.Progress(frame, share, left)
    frame.track:SetValue(math.min(share, 1))
    local seconds = math.max(0, math.floor(left + ROUND))
    if seconds ~= frame.seconds then
        frame.seconds = seconds
        frame.time:SetText(Clock(left))
    end
end

local function OnUpdate(self)
    if not job then return self:Hide() end
    HideCastBars()
    local elapsed = GetTime() - job.start
    Look.Progress(self, elapsed / job.known, job.known - elapsed)
end

local function Build()
    bar = Look.New(UIParent, "NaowhForeverCraftTimer")
    Look.Style(bar)
    bar:SetFrameStrata("MEDIUM")
    bar:SetScript("OnUpdate", OnUpdate)
    bar:Hide()
end

local function Place()
    local flight = _G.NaowhForeverFlightTimer
    bar:ClearAllPoints()
    if flight then
        bar:SetScale(flight:GetScale())
        bar:SetPoint("CENTER", flight, "CENTER")
    else
        bar:SetPoint("TOP", UIParent, "TOP", 0, FALLBACK_DROP)
    end
end

local function Show()
    if not bar then Build() end
    Place()
    Look.Fill(bar, job.icon, job.name, job.done, job.count)
    HideCastBars()
    bar:Show()
end

local function Stop()
    job = nil
    events:UnregisterAllEvents()
    if watch then
        watch:Cancel()
        watch = nil
    end
    if bar then bar:Hide() end
    RestoreCastBars()
end

local function Resync(castLeft)
    local after = job.count - job.done - 1
    job.known = (GetTime() - job.start) + math.max(0, castLeft) + math.max(0, after) * (job.cast + job.gap)
end

local function OnStart()
    if job.lastEnd then job.gap = GetTime() - job.lastEnd end
    local _, _, _, startMS, endMS = UnitCastingInfo("player")
    if not (startMS and endMS) then return end
    job.cast = (endMS - startMS) / MS
    Resync(endMS / MS - GetTime())
end

local function OnSucceeded()
    job.done = job.done + 1
    if job.done >= job.count then return Stop() end
    job.lastEnd = GetTime()
    Resync(job.gap + job.cast)
    Show()
end

local function OnEvent(_, event, _, _, spellID)
    if not job or spellID ~= job.recipeID then return end
    if event == "UNIT_SPELLCAST_START" then return OnStart() end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then return OnSucceeded() end
    if event == "UNIT_SPELLCAST_FAILED" and select(CASTING_SPELL, UnitCastingInfo("player")) == job.recipeID then
        return
    end
    Stop()
end

local function Watch()
    if job and GetTime() > job.start + job.known + STALE then Stop() end
end

local function OnCraft(recipeID, count)
    count = tonumber(count) or 1
    local spell = C_Spell.GetSpellInfo(recipeID)
    local cast = spell and (spell.castTime or 0) / MS or 0
    if not On() or count < MIN_BATCH then return end
    local recipe = C_TradeSkillUI.GetRecipeInfo(recipeID)
    Stop()
    job = { recipeID = recipeID, name = recipe and recipe.name or (spell and spell.name),
        icon = recipe and recipe.icon or (spell and spell.iconID), count = count, done = 0,
        cast = cast > 0 and cast or GUESS_CAST, gap = GAP, start = GetTime() }
    Resync(job.cast)
    for _, event in ipairs(CAST_EVENTS) do events:RegisterUnitEvent(event, "player") end
    watch = C_Timer.NewTicker(WATCH_EVERY, Watch)
    Show()
end

local function Apply()
    if not On() then return Stop() end
    if hooked then return end
    hooked = true
    hooksecurefunc(C_TradeSkillUI, "CraftRecipe", OnCraft)
    if C_TradeSkillUI.StopRecipeRepeat then hooksecurefunc(C_TradeSkillUI, "StopRecipeRepeat", Stop) end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "craftTimer" then
        Apply()
    elseif bar and key:find("^craftTimer") then
        Look.Style(bar)
    end
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
