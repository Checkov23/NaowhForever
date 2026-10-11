local root = arg[1] or "."
local CORE_FILES = { _Widgets = "Options/Widgets" }
local function Read(name)
    local f = assert(io.open(root .. "/Core/" .. CORE_FILES[name] .. ".lua", "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close(); return s
end
local function Slice(s, first, last)
    local a = assert(s:find(first, 1, true), first)
    return s:sub(a, assert(s:find(last, a, true), last) - 1)
end
local function Eval(code, env)
    setmetatable(env, { __index = _G })
    local f = assert(loadstring(code)); setfenv(f, env); return f()
end
local cases = 0
local function Case(name, fn)
    fn(); cases = cases + 1; print("PASS " .. name)
end
local widgets = Read("_Widgets")
local widgetConstants = assert(widgets:match("\n(local MEDIA = .-\n)\nlocal UI = {}\n"), "Widgets constants")
local sharedMedia = assert(widgets:match("\n(local function SharedMedia%(%).-\nend\n)"), "SharedMedia")

Case("late LSM, negative cache, and later sound registration", function()
    local ui, builds, callback = {}, 0, nil
    local media = { later = "later.ogg" }
    local provider = {
        HashTable = function() builds = builds + 1; return media end,
        RegisterCallback = function(_, event, fn) assert(event == "LibSharedMedia_Registered"); callback = fn end,
        UnregisterCallback = function() end,
    }
    local env = { UI = ui, LibStub = false, ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua") } }
    Eval(widgetConstants .. sharedMedia .. Slice(widgets, "local bundledVoices =", "function ns.SoundChoices()"), env)
    assert(ui.SoundPathFor("sm:later") == nil)
    env.LibStub = function() return provider end
    assert(ui.SoundPathFor("sm:later") == "later.ogg")
    for _ = 1, 100 do assert(ui.SoundPathFor("sm:missing") == nil) end
    assert(builds == 1, "negative lookup rebuilt cache")
    media.added = "added.ogg"; callback("LibSharedMedia_Registered", "sound", "added")
    assert(ui.SoundPathFor("sm:added") == "added.ogg" and builds == 2)
end)

Case("bundled voices resolve without SharedMedia, and each one is a real Ogg file", function()
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, UI = {}, MEDIA = dofile("Tools/regression/core_media.lua") }
    local start = assert(widgets:find("local bundledVoices =", 1, true))
    local chunk = assert(loadstring("local ns = ...; local UI = ns.UI; " .. widgetConstants .. sharedMedia
        .. widgets:sub(start)))
    setfenv(chunk, setmetatable({ LibStub = false }, { __index = _G })); chunk(ns)
    local paths, names, order = ns.UI.BuildAlertSoundTables()
    assert(#order == 6 and order[1] == "none")
    assert(ns.UI.SoundPathFor("none") == nil and ns.UI.SoundPathFor("missing") == nil)
    for index = 2, #order do
        local key = order[index]
        assert(names[key]:find("Voice:", 1, true))
        assert(ns.UI.SoundPathFor(key) == paths[key])
        local relative = assert(paths[key]:match("NaowhForever\\(.+)$")):gsub("\\", "/")
        local sound = assert(io.open(root .. "/" .. relative, "rb"))
        assert(sound:read(4) == "OggS"); sound:close()
    end
end)

print(cases .. " recovery regression cases passed")
