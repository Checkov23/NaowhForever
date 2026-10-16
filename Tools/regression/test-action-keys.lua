-- Run with Lua 5.1 from the repository root: the short key text on action buttons (Shared/Game/ActionKeys.lua).
-- A mouse button is its modifiers' letters and M with its number, as action bar addons show it; any other key
-- is the game's own short text.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local ns = { Shared = {} }
local bound = { ["CLICK Food:LeftButton"] = "SHIFT-BUTTON5" }
local env = setmetatable({
    _G = { NaowhForever = ns },
    GetBindingText = function(key) return "game:" .. key end,
    GetBindingKey = function(command) return bound[command] end,
}, { __index = _G })
local chunk = assert(loadfile("Shared/Game/ActionKeys.lua"))
setfenv(chunk, env)
chunk()
local Text = ns.Shared.ActionKeys.Text

check("mouse button 4 is M4", Text("BUTTON4") == "M4")
check("shift and mouse button 5 is SM5", Text("SHIFT-BUTTON5") == "SM5")
check("every modifier, in the game's order", Text("ALT-CTRL-SHIFT-BUTTON3") == "ACSM3")
check("a keyboard key keeps the game's text", Text("SHIFT-F") == "game:SHIFT-F")
check("a bound command reads the same way", ns.Shared.ActionKeys.Bound("CLICK Food:LeftButton") == "SM5")

print(("test-action-keys: %d checks passed"):format(checks))
