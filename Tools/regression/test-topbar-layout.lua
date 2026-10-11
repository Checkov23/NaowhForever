-- Top Bar layout: the saved layout, its migration from the old button keys, the order the bar
-- draws in, and the preview editor's remove, move and add. NaowhForever_TopBar/Layout.lua and its look are
-- loaded on stubs; the preview's key handling is cut out of NaowhForever_TopBar/UI/Preview.lua.

-- The Top Bar's files as TopBar.xml lists them, read as one source.
local parts = {}
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_TopBar/.*%.lua$")) do
    local f = assert(io.open(path, "rb"))
    parts[#parts + 1] = f:read("*a"):gsub("\r\n", "\n")
    f:close()
end
local source = table.concat(parts, "\n")
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Slice(a, b)
    local first = assert(source:find(a, 1, true), a)
    return source:sub(first, assert(source:find(b, first + #a, true), b) - 1)
end

local defaultLayout = assert(loadstring("return " .. assert(source:match("\n    layout = (%b{}),\n"))))()
local FILES = { "NaowhForever_TopBar/Constants.lua", "NaowhForever_TopBar/Layout.lua", "NaowhForever_TopBar/View/Style.lua", "NaowhForever_TopBar/View/Look.lua" }

local function Store(db)
    local S = { sets = 0 }
    function S.DB() return db end
    function S.Get(k)
        if db[k] == nil then return k == "layout" and defaultLayout or nil end
        return db[k]
    end
    function S.Default(k) return k == "layout" and defaultLayout or nil end
    function S.Set(k, v) db[k] = v; S.sets = S.sets + 1 end
    return S
end

local objects = {}
local ldb = {
    GetDataObjectByName = function(_, name) return objects[name] end,
    DataObjectIterator = function() return pairs(objects) end,
}

local function Load(db)
    local S = Store(db)
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, TopBar = { Settings = S, LDB = function() return ldb end },
        Shared = { Style = {}, Parts = {} }, THEME = {}, UI = {} }
    local env = setmetatable({ NaowhForever = ns, wipe = function(t) for k in pairs(t) do t[k] = nil end return t end },
        { __index = _G })
    env._G = env
    for _, path in ipairs(FILES) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local TB = ns.TopBar
    local L = TB.Layout
    return { Look = TB.Look, Style = TB.Style, SavedLayout = L.Saved, RemoveKey = L.Remove, MoveKey = L.Move,
        AddKey = L.Add, ResetLayout = L.Reset, InLayoutOf = L.InLayoutOf }, S
end

local function Join(list) return table.concat(list, ",") end
local function Sides(layout) return Join(layout.left) .. " | " .. Join(layout.right) end

check("the default bar: Journal and Discovery left, BiS and Training right", Sides(defaultLayout)
    == "ldb:NaowhForeverJournal,ldb:NaowhForeverDiscovery | ldb:NaowhForeverBiS,ldb:NaowhForeverTraining")

-- A fresh profile keeps the default and only marks itself migrated.
local db = {}
local api = Load(db)
check("fresh: the default layout", Sides(api.SavedLayout()) == Sides(defaultLayout))
check("fresh: migrated once, nothing saved", db.layoutMigrated == true and db.layout == nil)

-- Old keys become the same bar, in the order the old code drew it.
db = { showHearth = true, showGuild = false, brokers = { "BugSack", "NaowhForeverDQ", "NaowhForeverBiS" },
    brokerSide = { BugSack = "left", NaowhForeverDQ = "left" } }
api = Load(db)
check("migrated: left brokers, then friends; hearth then the rest on the right",
    Sides(api.SavedLayout()) == "ldb:BugSack,ldb:NaowhForeverJournal,friends | hearth,ldb:NaowhForeverBiS")
check("migrated: Dungeon Quests became the Journal on its side", db.brokerSide.NaowhForeverJournal == "left")
db.layout.left[1] = "guild"
check("migrated only once: the flag keeps an edited layout", api.SavedLayout().left[1] == "guild")

db = { showFriends = false, brokers = { "NaowhForeverDQ", "NaowhForeverJournal" } }
api = Load(db)
check("migrated: Dungeon Quests beside the Journal is dropped, not doubled",
    Sides(api.SavedLayout()) == "guild | ldb:NaowhForeverJournal")

db = { layout = { left = {}, right = { "hearth" } }, showHearth = false }
api = Load(db)
check("a saved layout wins over the old keys", Sides(api.SavedLayout()) == " | hearth")

db = { layoutMigrated = true, layout = { left = "broken" } }
api = Load(db)
check("a malformed layout falls back to the default", Sides(api.SavedLayout()) == Sides(defaultLayout))

-- The bar draws each side in its saved order; brokers not loaded are skipped but kept.
objects = { BugSack = { icon = "bug", label = "Bug Sack" }, NaowhForeverBiS = { icon = "bis" },
    NoIcon = {} }
db = { layoutMigrated = true,
    layout = { left = { "ldb:Missing", "guild", "ldb:BugSack" }, right = { "ldb:NoIcon", "hearth", "ldb:NaowhForeverBiS" } } }
api = Load(db)
local drawn = {}
api.Look.Buttons(function(side, key, texture, glyph, coords, name)
    drawn[#drawn + 1] = side .. ":" .. key .. ":" .. tostring(texture) .. ":" .. tostring(glyph) .. ":"
        .. tostring(name) .. ":" .. #coords
end)
local M = api.Style.MEDIA
check("drawn in saved order, missing and iconless brokers skipped", Join(drawn) ==
    "left:guild:" .. M .. "icon-guild.png:true:nil:4,left:ldb:BugSack:bug:false:BugSack:4,"
    .. "right:hearth:" .. M .. "icon-hearth.png:true:nil:4,right:ldb:NaowhForeverBiS:" .. M
    .. "icon-bis.png:true:NaowhForeverBiS:4")
check("skipped brokers stay in the layout", db.layout.left[1] == "ldb:Missing" and db.layout.right[1] == "ldb:NoIcon")

-- Every Naowh Forever launcher in the default layout has its own glyph, and the file is there.
local glyphs = {}
for name, path in pairs(api.Style.GLYPH) do
    glyphs[name] = "NaowhForever_TopBar/Media/" .. path:sub(#api.Style.MEDIA + 1)
end
local missing = {}
for _, side in ipairs({ "left", "right" }) do
    for _, key in ipairs(defaultLayout[side]) do
        local name = key:match("^ldb:(NaowhForever.*)$")
        local path = name and glyphs[name]
        local file = path and io.open(path, "rb")
        if file then file:close() elseif name then missing[#missing + 1] = name end
    end
end
check("the default launchers all have a glyph file: " .. table.concat(missing, ", "), #missing == 0)

-- Editing: every change saves a fresh layout through the store.
local saved = db.layout
local S
api, S = Load(db)
api.RemoveKey("guild")
check("remove: gone from its side", Sides(db.layout) == "ldb:Missing,ldb:BugSack | ldb:NoIcon,hearth,ldb:NaowhForeverBiS")
check("remove: saved through the store, the old table untouched", S.sets == 1 and saved.left[2] == "guild")
api.MoveKey("hearth", "left", "ldb:BugSack")
check("move: before the button it was dropped on, across the clock",
    Sides(db.layout) == "ldb:Missing,hearth,ldb:BugSack | ldb:NoIcon,ldb:NaowhForeverBiS")
api.MoveKey("hearth", "right", nil)
check("move: to the end of a side", Sides(db.layout) == "ldb:Missing,ldb:BugSack | ldb:NoIcon,ldb:NaowhForeverBiS,hearth")
api.MoveKey("ldb:BugSack", "left", "ldb:Missing")
check("move: reorder on the same side", Sides(db.layout) == "ldb:BugSack,ldb:Missing | ldb:NoIcon,ldb:NaowhForeverBiS,hearth")
api.AddKey("left", "friends")
api.AddKey("right", "guild")
check("add: on the outer end of the side, beside its +",
    Sides(db.layout) == "friends,ldb:BugSack,ldb:Missing | ldb:NoIcon,ldb:NaowhForeverBiS,hearth,guild")
api.AddKey("right", "friends")
check("add: a button already on the bar moves, never doubles",
    Sides(db.layout) == "ldb:BugSack,ldb:Missing | ldb:NoIcon,ldb:NaowhForeverBiS,hearth,guild,friends")
check("InLayoutOf finds either side", api.InLayoutOf(db.layout, "friends") and api.InLayoutOf(db.layout, "ldb:BugSack")
    and not api.InLayoutOf(db.layout, "ldb:Other"))
api.ResetLayout()
check("reset: back to the default", db.layout == nil and Sides(api.SavedLayout()) == Sides(defaultLayout)
    and db.layoutMigrated == true)

-- The card: the old per-button rows are gone, the layout has its reset, the preview its tabs.
check("the old button keys are only read by the migration", not source:find('S%.Get%("show[FGH]')
    and not source:find('S%.Get%("broker') and not source:find("\n    showFriends = ", 1, true))
check("no per-broker choice rows", not source:find('left = "Left Side"', 1, true) and not source:find("ADDON_GROUP", 1, true))
check("Reset Layout is a button row on the layout",
    source:find('{ key = "layout", label = "Reset Layout", button = ResetLayout,', 1, true) ~= nil)
check("Faded and In Combat show only while their setting is on",
    source:find('needs = "mouseover" }', 1, true) and source:find('needs = "hideInCombat" }', 1, true))
check("the preview's hint", source:find('"Drag to move, x to remove, + to add."', 1, true) ~= nil)
check("the drag's OnUpdate is removed when it ends", source:find('edit:SetScript("OnUpdate", nil)', 1, true) ~= nil)

-- The edit layer sits over the options window: its keyboard is off until a drag starts, and
-- Escape passes through to close the window unless it cancels a drag.
local layer = Slice("local function NewEditLayer(preview)", "\n    preview.edit = edit")
local keyScript = assert(layer:find('edit:SetScript("OnKeyDown", DragKey)', 1, true))
check("the edit layer's keyboard is turned off once its key script is set",
    (layer:find("\n    edit:EnableKeyboard(false)", keyScript, true) or 0) > keyScript)

local ended
local keyChunk = assert(loadstring(Slice("local function DragKey(edit, key)", "\nlocal function PreviewHidden")
    .. "\nreturn DragKey"))
setfenv(keyChunk, { InCombatLockdown = function() return false end,
    EndDrag = function(preview, commit) ended = { preview, commit } end })
local DragKey = keyChunk()
local edit = { preview = {} }
function edit:SetPropagateKeyboardInput(v) self.propagate = v end
DragKey(edit, "ESCAPE")
check("Escape with no drag passes through to the window", edit.propagate == true and ended == nil)
edit.preview.drag = {}
DragKey(edit, "ESCAPE")
check("Escape during a drag is kept and cancels it",
    edit.propagate == false and ended and ended[1] == edit.preview and ended[2] == false)
DragKey(edit, "A")
check("other keys pass through during a drag", edit.propagate == true)

print("PASS top bar layout: " .. checks .. " checks")
