-- Website imports save only after confirmation, preserve unrelated slots and reject unsafe data.
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end
local payload, confirmation, opened, printed
local enabled, combat = true, false
local sets = {}
local ns = {
    L = function(s) return s end,
    Shared = { Decode = { String = function() return payload end } },
    Print = function(s) printed = s end,
    Confirm = function(_, fn) confirmation = fn end,
    OpenActionBarsImport = function(key) opened = key end,
    ActionBars = {
        C = { KEYBOARD_SLOTS = 180, SLOTS_PER_BAR = 12, QUESTION = 134400 },
        Capture = { Slots = function() return { 1, 2, 12, 181 } end,
            MacroKey = function(name, body) return name .. "\n" .. body end },
        Class = function() return "WARRIOR" end,
        On = function() return enabled end,
        Sets = function() return sets end,
        Find = function(key) return sets[key] and key end,
        Refresh = function() end,
    },
}
local env = setmetatable({ _G = { NaowhForever = ns },
    InCombatLockdown = function() return combat end, time = function() return 123 end }, { __index = _G })
for _, file in ipairs({ "NaowhForever_Utilities/ActionBars/Data/Bars.lua", "NaowhForever_Utilities/ActionBars/Sharing.lua" }) do
    local chunk = assert(loadfile(file)); setfenv(chunk, env); chunk()
end
local sharing = ns.ActionBars.Sharing
local function Valid()
    return { v = 1, class = 1, name = "My bars", slots = {
        [1] = { kind = "spell", id = 100, name = "Charge" },
        [12] = { kind = "item", id = 6948 },
    }, bindings = { ["SHIFT-Q"] = "ACTIONBUTTON1" } }
end
payload = Valid()
local name, set = sharing.Decode("!NFA1!test")
Check("valid name", name == "My bars")
Check("unfilled keyboard and gamepad slots preserved", set.choices.skip[2] and set.choices.skip[181])
Check("filled slot imported", not set.choices.skip[1] and set.slots[1].id == 100)
Check("keybind imported", set.bindings["SHIFT-Q"] == "ACTIONBUTTON1" and set.choices.keys)
payload = Valid()
payload.slots[2] = { kind = "macro", name = "Pull", body = "/say pull", icon = 134400, perCharacter = true }
payload.macros = {
    { name = "Pull", body = "/say pull", icon = 134400, perCharacter = true },
    { name = "Shout", body = "/yell hi", icon = 132333, perCharacter = false },
    { name = "Plain", body = "/dance" },
}
set = select(2, sharing.Decode("!NFA1!test"))
Check("unplaced macros kept, a placed one listed once", #set.macros == 3 and set.macros[2].name == "Shout")
Check("account macro honoured", set.macros[2].perCharacter == false and set.slots[2].perCharacter == true)
Check("character macro by default", set.macros[3].perCharacter == true)
Check("icon honoured", set.macros[2].icon == 132333 and set.macros[3].icon == 134400)
payload.macros[3].icon = -5
set = select(2, sharing.Decode("!NFA1!test"))
Check("bad icon falls back to the question mark", set.macros[3].icon == 134400)
payload = Valid()
payload.slots = {}
payload.macros = { { name = "Shout", body = "/yell hi" } }
set = select(2, sharing.Decode("!NFA1!test"))
Check("a layout of macros alone is accepted", set and #set.macros == 1 and set.choices.skip[1])
sharing.Import("!NFA1!test")
Check("nothing saved or opened before confirmation", next(sets) == nil and opened == nil and confirmation ~= nil)
confirmation()
Check("confirmed set opens preview", opened == "My bars" and sets[opened].saved == 123)
local original = sets[opened]
sharing.Import("!NFA1!test"); confirmation()
Check("existing set never overwritten", opened == "My bars (1)" and sets["My bars"] == original)
sharing.Import("!NFA1!test"); combat = true; confirmation()
Check("combat entered during confirmation cancels save", sets["My bars (2)"] == nil)
combat = false; enabled = false; confirmation = nil
sharing.Import("!NFA1!test")
Check("disabled module does nothing", confirmation == nil and printed ~= nil)
enabled = true
for _, mutate in ipairs({
    function(p) p.class = 2 end,
    function(p) p.slots[181] = p.slots[1] end,
    function(p) p.slots[1].kind = "function" end,
    function(p) p.slots[1].id = 0 / 0 end,
    function(p) p.slots[1].id = -1 end,
    function(p) p.name = "|Hunsafe" end,
    function(p) p.slots = {} end,
    function(p) p.bindings.Q = "RUNSCRIPT" end,
    function(p) p.bindings["ESCAPE"] = "ACTIONBUTTON1" end,
    function(p) p.slots[1] = { kind = "macro", name = "bad", body = string.rep("a", 256) } end,
    function(p) p.macros = "Pull" end,
    function(p) p.macros = { { name = "Pull" } } end,
    function(p) p.macros = { x = { name = "Pull", body = "/say pull" } } end,
    function(p)
        p.macros = {}
        for i = 1, 31 do p.macros[i] = { name = "M" .. i, body = "/say " .. i } end
    end,
}) do
    payload = Valid(); mutate(payload)
    Check("malformed layout rejected", sharing.Decode("!NFA1!test") == nil)
end
payload = Valid()
Check("wrong prefix rejected", sharing.Decode("!NFM1!test") == nil)
Check("input size bounded", sharing.Decode(string.rep("a", 100001)) == nil)
print("action bar sharing: " .. checks .. " checks passed")
