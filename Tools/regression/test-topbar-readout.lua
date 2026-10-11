-- Top Bar FPS / MS readout: its colours and text, and what the ticker's second costs. Its look
-- (NaowhForever_TopBar/View/Look.lua) is loaded and UpdateSystem cut out of NaowhForever_TopBar/UI/Bar.lua, run on stubs that
-- make no garbage. Run from the repo root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)

-- The Top Bar's files as TopBar.xml lists them, read as one source.
local parts = {}
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_TopBar/.*%.lua$")) do
    local f = assert(io.open(path, "rb"))
    parts[#parts + 1] = f:read("*a"):gsub("\r\n", "\n")
    f:close()
end
local source = table.concat(parts, "\n")

local function Slice(a, b)
    local first = assert(source:find(a, 1, true), a)
    return source:sub(first, assert(source:find(b, first + #a, true), b) - 1)
end

local code = table.concat({
    "local bar, S, On, Look, C = ...",
    assert(source:match("\n(local SYS_DROP, [^\n]*)"), "the readout's sizes"),
    assert(source:match("\n(local ROUND = [^\n]*)"), "ROUND"),
    assert(source:match("\n(local HOME_LATENCY = [^\n]*)"), "HOME_LATENCY"),
    Slice("local function UpdateSystem()", "\nlocal function UpdateResting()"),
    "return { UpdateSystem = UpdateSystem }",
}, "\n")

-- The real look, on a stub namespace.
local function LoadLook(S)
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, TopBar = { Settings = S }, Shared = { Style = {}, Parts = {} }, THEME = {}, UI = {} }
    local env = setmetatable({ NaowhForever = ns }, { __index = _G })
    env._G = env
    for _, path in ipairs({ "NaowhForever_TopBar/Constants.lua", "NaowhForever_TopBar/View/Style.lua", "NaowhForever_TopBar/View/Look.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    return ns.TopBar.Look, ns.TopBar.C
end

local fps, ms, writes = 144, 38, 0
local text = {
    SetText = function(self, v) self.value = v; writes = writes + 1 end,
    GetStringWidth = function() return 120 end,
}
local sys = {
    text = text,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    SetWidth = function(self, w) self.w = w end,
}
local settings = { showSystem = true }
local S = { Get = function(k) return settings[k] end }
local chunk = assert(loadstring(code))
setfenv(chunk, setmetatable({
    GetFramerate = function() return fps end,
    GetNetStats = function() return 0, 0, ms, 90 end,
}, { __index = _G }))
local Look, C = LoadLook(S)
local api = chunk({ sys = sys }, S, function() return true end, Look, C)
api.FpsRGB, api.MsRGB = Look.FpsRGB, Look.MsRGB

api.UpdateSystem()
check("the readout's text", text.value == "FPS: |cff40ff40144|r  MS: |cff40ff4038|r")
check("sized to its text and shown", sys.w == 130 and sys.shown)
fps, ms = 45, 160
api.UpdateSystem()
check("bands change color", text.value == "FPS: |cffffff4045|r  MS: |cffff5940160|r")
local r, g, b = api.FpsRGB(20)
check("the tooltip's colors are the readout's", r == 1 and g == 0.35 and b == 0.25)
r, g, b = api.MsRGB(100)
check("the tooltip's latency color", r == 1 and g == 1 and b == 0.25)

writes = 0
api.UpdateSystem()
check("the same numbers are not written again", writes == 0)
fps = 46
api.UpdateSystem()
check("a new number is", writes == 1 and text.value:find("FPS: |cffffff4046|r", 1, true) == 1)
settings.showSystem = false
api.UpdateSystem()
check("switched off, it hides", not sys.shown)
settings.showSystem = true
writes = 0
api.UpdateSystem()
check("shown again, it is written again", writes == 1 and sys.shown)

Measure("a second of the ticker, numbers unchanged", 0.01, api.UpdateSystem)

check("the badge and resting events are registered only while the bar is up",
    source:find("for i = 1, #BAR_EVENTS do events:RegisterEvent(BAR_EVENTS[i]) end", 1, true) ~= nil
    and not source:find('events:RegisterEvent("FRIENDLIST_UPDATE")', 1, true))
check("GameTooltip is hooked with the bar's first tooltip, not at load",
    not source:find("\nGameTooltip:HookScript", 1, true))

print("PASS top bar readout: " .. checks .. " checks")
