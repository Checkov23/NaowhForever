-- Run with Lua 5.1 from the repository root: the XP Bar's effects (NaowhForever_QoL/XP/XPBarFX.lua) on stub
-- frames. Each effect shows only while its switch is on: Shine, Notches, Rested Stripes, the quest hand-in pulse and
-- its rising amount, the Ready to Level glow and star, the Level-Up flash and the hover breakdown. The kills
-- estimate counts rested kills double, and every switch has a default, the new effects off.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return s
end

local Region = {}
Region.__index = Region
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetShown(on) self.shown = on and true or false end
function Region:IsShown() return self.shown ~= false end
function Region:SetWidth(w) self.width = w end
function Region:GetWidth() return self.width or 0 end
function Region:SetText(t) self.text = t end
function Region:SetPoint() end
function Region:ClearAllPoints() end
function Region:SetAllPoints() end
function Region:SetHeight() end
function Region:SetSize() end
function Region:SetTexture() end
function Region:SetColorTexture() end
function Region:SetVertexColor() end
function Region:SetTextColor() end
function Region:SetGradient() end
function Region:SetBlendMode() end
function Region:SetHorizTile() end
function Region:SetVertTile() end
function Region:SetFrameLevel() end
function Region:GetFrameLevel() return 1 end

local Group = {}
Group.__index = Group
function Group:Play() self.playing = true; self.plays = (self.plays or 0) + 1 end
function Group:Stop() self.playing = false end
function Group:IsPlaying() return self.playing == true end
function Group:SetScript() end
function Group:SetLooping() end
local Anim = setmetatable({}, { __index = function() return function() end end })
function Group:CreateAnimation() return Anim end
function Region:CreateAnimationGroup() return setmetatable({}, Group) end
function Region:CreateTexture() return setmetatable({}, Region) end

local function New() return setmetatable({}, Region) end

local settings = {}
local S = { Get = function(k) return settings[k] end }
local tip, hides = nil, 0
local ns = {
    QoLSettings = S,
    QoLConstants = { PERCENT = 100 },
    Shared = { Style = { WHITE = "Interface\\Buttons\\WHITE8X8" } },
    L = function(s) return s end,
    Font = function() return New() end,
    UI = { ShowWidgetTooltip = function(_, text) tip = text end, HideWidgetTooltip = function() hides = hides + 1 end },
}
local now = 100
local env = setmetatable({ NaowhForever = ns, CreateFrame = New, CreateColor = function() return {} end,
    GetTime = function() return now end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end }, { __index = _G })
env._G = env
local chunk = assert(loadstring(Read("NaowhForever_QoL/XP/XPBarFX.lua"), "XPBarFX"))
setfenv(chunk, env)
chunk()
local FX = ns.XPBarFX

local b = New()
b.track, b.rested, b.done = New(), New(), New()
b.track.width = 520
FX.New(b)

FX.Size(b, 520, 26)
check("Notches off: no marks", not b.ticks[1].shown)
settings.xpBarNotches = true
FX.Size(b, 520, 26)
check("Notches on: nine marks, every 10%", #b.ticks == 9 and b.ticks[1].shown and b.ticks[9].shown)

FX.Segments(b, 520, 200, 300, false, 0.1)
check("Shine off: no shine and no spark", not b.sheen.shown and not b.spark.shown)
check("the rested band ends in a bright line", b.restedEdge.shown)
check("Rested Stripes off: none", not b.stripes.shown)
settings.xpBarShine, settings.xpBarRestedStripes = true, true
FX.Segments(b, 520, 200, 300, false, 0.1)
check("Shine on: the shine and the spark at the fill's end", b.sheen.shown and b.shade.shown and b.spark.shown)
check("Rested Stripes on: on the rested band", b.stripes.shown)
FX.Segments(b, 520, 200, nil, false)
check("no rested band: no stripes and no line", not b.stripes.shown and not b.restedEdge.shown)
FX.Segments(b, 520, 520, nil, false)
check("a full bar has no spark past its end", not b.spark.shown)

local PER_XP = 0.1
FX.Segments(b, 520, 230, nil, false, PER_XP)
FX.Gain(b, 300)
FX.Segments(b, 520, 260, nil, false, PER_XP)
check("Quest XP Pulse off: a hand-in flashes nothing", not b.gain.shown and not b.gainText.shown)
settings.xpBarGainPulse = true

FX.Gain(b, 300)
FX.Segments(b, 520, 260, nil, false, PER_XP)
check("the hand-in comes before its XP: nothing flashes until the fill moves", not b.gain.shown)
FX.Segments(b, 520, 290, nil, false, PER_XP)
check("then the quest's XP flashes, its width back from the fill's end", b.gain.shown and b.gain.width == 30
    and b.gainFade.playing)
check("and its amount rises off the bar", b.gainText.shown and b.gainText.text == "+300" and b.gainRise.playing)

FX.Gain(b, 400)
FX.Segments(b, 520, 290, nil, false, PER_XP)
check("its XP came first: it waits a moment for the fill", b.gainRise.plays == 1)
now = now + 0.2
FX.Segments(b, 520, 290, nil, false, PER_XP)
check("then flashes where the fill already is", b.gainRise.plays == 2 and b.gain.width == 40 and b.gainText.text == "+400")

FX.Gain(b, 100)
FX.Gain(b, 50)
FX.Segments(b, 520, 10, nil, false, PER_XP)
check("two hand-ins between draws add up, cut at the bar's start when they level you",
    b.gainText.text == "+150" and b.gain.width == 10)
FX.Segments(b, 520, 40, nil, false, PER_XP)
check("a hand-in flashes once", b.gainRise.plays == 3)
FX.Segments(b, 520, 60, nil, false, PER_XP)
check("kills move the fill but never pulse", b.gainRise.plays == 3)
local source = Read("NaowhForever_QoL/XP/XPBar.lua")
check("the pulse comes from QUEST_TURNED_IN's XP reward, never from PLAYER_XP_UPDATE",
    source:find('if event == "QUEST_TURNED_IN" then', 1, true) and source:find("FX.Gain(bar, questXP)", 1, true)
    and select(2, source:gsub("FX%.Gain%(bar", "")) == 1)

FX.Segments(b, 520, 200, nil, true)
check("Ready to Level off: no glow", not b.readyGlow.shown and not b.star.shown)
settings.xpBarReadyGlow = true
FX.Segments(b, 520, 200, nil, true)
check("Ready to Level on: the quests glow and the star shows", b.readyGlow.shown and b.star.shown
    and b.readyBeat.playing and b.starBeat.playing)
FX.Segments(b, 520, 210, nil, true)
check("the glow keeps beating, never restarted each second", b.readyBeat.plays == 1)
FX.Segments(b, 520, 210, nil, false)
check("handed in: the glow and the star go", not b.readyGlow.shown and not b.star.shown and not b.readyBeat.playing)

FX.LevelUp(b)
check("Level-Up Flash off: nothing", not b.levelFlash.shown)
settings.xpBarLevelFlash = true
FX.LevelUp(b)
check("Level-Up Flash on: the whole bar flashes and drains", b.levelFlash.shown and b.levelFlash.width == 520
    and b.levelDrain.playing)

check("kills of your level: 5 x level + 45 each", FX.Kills(20, 11259, 0) == 78)
check("rested kills count double while the rested XP lasts", FX.Kills(20, 11259, 3596) == 54)
check("rested past the level: half the kills", FX.Kills(20, 2900, 100000) == 10)

FX.HideBreakdown()
check("nothing to hide: the shared tooltip is left alone", hides == 0)
FX.ShowBreakdown(b, { level = 20, left = 11259, leftPct = 48.53, done = 11300, open = 0, rested = 3596,
    ready = true, pace = "2h 48m" })
check("the breakdown lists XP to level, the quests, rested, kills and the pace", tip
    and tip:find("XP to level: 11259 (48.5%)", 1, true) and tip:find("enough to level", 1, true)
    and not tip:find("in progress", 1, true) and tip:find("Rested: 3596", 1, true)
    and tip:find("About 54 kills", 1, true) and tip:find("2h 48m at your pace", 1, true))
FX.HideBreakdown()
check("and hides once", hides == 1)

local rows = FX.Rows(function(name) return { group = name } end)
local defaults = Read("Core/Settings.lua")
local OFF = { xpBarRestedStripes = true, xpBarGainPulse = true, xpBarReadyGlow = true, xpBarLevelFlash = true,
    xpBarBreakdown = true }
for i = 2, #rows do
    local key = rows[i].key
    local default = defaults:match(key .. " = (%a+)")
    check(key .. " has a default", default ~= nil)
    if OFF[key] then check(key .. " starts off", default == "false") end
end

print(("test-xp-bar-fx: %d checks passed"):format(checks))
