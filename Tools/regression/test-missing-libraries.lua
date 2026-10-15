-- Run with Lua 5.1 from the repository root: Libs/ is added by the packager, so an install from
-- the source zip has none. At login the addon says which bundled libraries are missing, and says
-- nothing when they are all there (another addon's LibStub alone does not count as ours).
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local f = assert(io.open("Core/Core.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()
local constants = assert(source:match("\n(local MODULE_KEY = .-\n)\nlocal ns = {}\n"), "Core constants")
local a = assert(source:find("local function OnLibraryCheck()", 1, true))
local wired = 'libCheck:SetScript("OnEvent", OnLibraryCheck)\n'
local b = assert(source:find(wired, a, true))
local chunk = constants .. source:sub(a, b + #wired - 1)

local printed, handler
local env = {
    CreateFrame = function()
        return { RegisterEvent = function() end, SetScript = function(_, _, fn) handler = fn end }
    end,
    ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Print = function(msg) printed = msg end, Color = function(_, text) return text end },
}
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
fn()

local function Login(libs)
    printed = nil
    env.LibStub = libs and function(name) return libs[name] end
    handler()
    return printed
end

check("no LibStub at all: warns", Login(nil):find("LibCustomGlow%-1%.0") ~= nil)
check("someone else's LibStub without our libraries: warns", Login({}):find("LibDeflate") ~= nil)
local all = {}
for _, name in ipairs({ "CallbackHandler-1.0", "LibDataBroker-1.1", "LibDBIcon-1.0", "LibSharedMedia-3.0",
    "LibCustomGlow-1.0", "LibDeflate", "LibSerialize" }) do all[name] = true end
check("every library present: says nothing", Login(all) == nil)
all["LibSerialize"] = nil
local msg = Login(all)
check("one missing: names only that one", msg and msg:find("LibSerialize") and not msg:find("LibDeflate"))

print(("test-missing-libraries: %d checks passed"):format(checks))
