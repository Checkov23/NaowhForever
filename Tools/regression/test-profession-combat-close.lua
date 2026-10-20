-- Run with Lua 5.1 from the repository root: closing the Professions window in combat. With the
-- overview docked our window holds Blizzard's secure profession buttons, which makes it
-- protected, so it is not hidden or re-laid out until combat ends (that would be a blocked
-- action); it goes transparent instead.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local source = Read("NaowhForever_Professions/UI/Takeover.lua")
local first = assert(source:find("local function Deactivate()", 1, true))
local last = assert(source:find("\nend\n", first, true))
local chunk = "local win, hooked\n" .. source:sub(first, last + 4)
    .. "return function(w, h) win, hooked = w, h ~= false end, Deactivate"

local combat = false
local calls = {}
local function Frame(protected)
    local f = { shown = true, alpha = 1 }
    function f:IsProtected() return protected end
    function f:Hide() self.shown = false end
    function f:SetAlpha(a) self.alpha = a end
    return f
end
local pf = Frame()
local env = {
    waiting = {},
    ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, ProfBagChanges = 0 },
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    InCombatLockdown = function() return combat end,
    ProfessionsFrame = pf,
    DockTabs = function(on) calls[#calls + 1] = "tabs:" .. tostring(on) end,
    DockBook = function(on) calls[#calls + 1] = "book:" .. tostring(on) end,
}
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local Set, Deactivate = fn()

local win = Frame(true)
Set(win)
Deactivate()
check("out of combat the window hides", not win.shown)

win = Frame(true)
combat = true
Set(win)
Deactivate()
check("protected in combat the window is not hidden", win.shown)
check("protected in combat the window goes transparent", win.alpha == 0)
check("the book is still asked to undock (it waits for combat itself)", calls[#calls] == "book:false")

win = Frame(false)
Set(win)
Deactivate()
check("not protected, the window hides in combat too", not win.shown)

combat, calls, pf.alpha = false, {}, 0.5
Set(nil, false)
Deactivate()
check("never hooked, as under the Gamepad style: Blizzard's window is left alone", #calls == 0 and pf.alpha == 0.5)
pf.alpha = 1

local activate = assert(source:find("local function Activate(mode)", 1, true))
local activateEnd = assert(source:find("\nend\n", activate, true))
local body = source:sub(activate, activateEnd)
check("opening again brings the window back from transparent", body:find("win:SetAlpha(1)", 1, true))
check("the docked book is not shown or hidden in combat",
    body:find("if not (bookDocked and InCombatLockdown()) then win.book:SetShown(book) end", 1, true))

print(checks .. " profession combat close checks passed")
