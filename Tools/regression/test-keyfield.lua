-- The key binding field: UI.KeyField cut out of Widgets.lua and run against a binding table that
-- behaves like the game's. A field takes a binding command, or a function for one pointed at
-- another binding each time its panel opens.
local f = assert(io.open("Core/Options/Widgets.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local body = assert(source:match("\n(local function KeyCombo%(.-\nfunction UI%.KeyField%(.-\nend)\n"), "KeyField")
local modifiers = assert(source:match("\n(local MEDIA = .-)\nlocal UI = {}\n"), "the file's constants")
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Frame()
    local fr = { scripts = {} }
    function fr:SetScript(event, fn) self.scripts[event] = fn end
    function fr:SetText(text) self.text = text end
    return setmetatable(fr, { __index = function() return function() end end })
end

-- The game's bindings: a key to its command, and the commands to their keys.
local bound, printed, tooltips = {}, {}, {}
local env = setmetatable({
    UI = {},
    CreateFrame = Frame,
    ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        MEDIA = dofile("Tools/regression/core_media.lua"),
        Button = function() local b = Frame(); b.label = Frame(); return b end,
        Tooltip = function(_, title, text) tooltips[#tooltips + 1] = { title, text } end,
        Print = function(msg) printed[#printed + 1] = msg end,
    },
    InCombatLockdown = function() return false end,
    IsAltKeyDown = function() return false end,
    IsControlKeyDown = function() return false end,
    IsShiftKeyDown = function() return false end,
    GetBindingKey = function(command)
        for key, cmd in pairs(bound) do if cmd == command then return key end end
    end,
    GetBindingAction = function(key) return bound[key] or "" end,
    SetBinding = function(key, command) bound[key] = command end,
    SaveBindings = function() end,
    GetCurrentBindingSet = function() return 1 end,
    GetBindingText = function(key) return key end,
    GetBindingName = function(command) return command end,
}, { __index = _G })
local chunk = assert(loadstring(modifiers .. "\n" .. body))
setfenv(chunk, env)
chunk()
local KeyField = env.UI.KeyField

-- A plain command, as every older caller passes.
local region = {}
local field = KeyField(region, "CLICK FooButton:LeftButton", "Use Foo")
check("it returns its button", field ~= nil and region._keyField == field)
check("a second call on the same region returns the same field", KeyField(region, "X", "Y") == field)
field.scripts.OnClick(field, "LeftButton")
field.scripts.OnKeyDown(field, "F")
check("a pressed key binds the command", bound.F == "CLICK FooButton:LeftButton")
check("the field shows its key", field.label.text == "F")
check("the default tooltip stays for a plain field", tooltips[1][1] == "Use Foo"
    and tooltips[1][2]:find("Key Bindings", 1, true) ~= nil)

-- One field pointed at a different binding each time its panel opens.
local current = "CLICK Item1:LeftButton"
local region2 = {}
local field2 = KeyField(region2, function() return current end, function() return current .. " label" end,
    "Its own tooltip.")
check("a field may take its own tooltip", tooltips[2][1] == "Key Binding" and tooltips[2][2] == "Its own tooltip.")
field2.scripts.OnClick(field2, "LeftButton")
field2.scripts.OnKeyDown(field2, "G")
check("it binds the command it points at now", bound.G == "CLICK Item1:LeftButton")
check("and shows the key of the command it points at", field2.label.text == "G")
current = "CLICK Item2:LeftButton"
field2._refreshValue()
check("re-pointed, it shows that binding's key: none yet", field2.label.text:find("Not bound", 1, true) ~= nil)
field2.scripts.OnClick(field2, "LeftButton")
field2.scripts.OnKeyDown(field2, "F")
check("a key bound elsewhere moves to the new command", bound.F == "CLICK Item2:LeftButton")
check("and says what it took the key from, by the field's label now",
    printed[#printed]:find("CLICK Item2:LeftButton label", 1, true) ~= nil
    and printed[#printed]:find("CLICK FooButton:LeftButton", 1, true) ~= nil)
field2.scripts.OnClick(field2, "RightButton")
check("a right-click clears the binding it points at", bound.F == nil and bound.G == "CLICK Item1:LeftButton")

print(("test-keyfield: %d checks passed"):format(checks))
