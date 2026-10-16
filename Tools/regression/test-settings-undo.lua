-- test-settings-undo.lua: reset undo restores exact values without overwriting edits or other profiles.
local checks = 0
local function check(ok, message) assert(ok, message); checks = checks + 1 end
local root = {}
local defaults = { enabled = true, size = 20, values = { a = 1, b = 2 } }
local values = { enabled = false, size = 30, values = { a = 3, b = 4 } }
local writes = 0
local store = {
    Raw = function(k) return values[k] end,
    Default = function(k) return defaults[k] end,
    Get = function(k) if values[k] ~= nil then return values[k] end return defaults[k] end,
    Set = function(k, v) writes = writes + 1; values[k] = v end,
}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L,
    SettingsRoot = function() return root end,
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = {} } }
local env = setmetatable({ _G = { NaowhForever = ns } }, { __index = _G })
local chunk = assert(loadfile("Shared/Settings/Settings.lua"))
setfenv(chunk, env); chunk()
local S = ns.Shared.Settings
local card = { rows = {} }
for _, spec in ipairs({ { key = "enabled" }, { key = "size" },
    { key = "values", field = "a" }, { key = "values", field = "b" } }) do
    spec.store, spec.card = store, card
    card.rows[#card.rows + 1] = spec
end
S.Reset(card)
check(values.enabled == true and values.size == 20 and values.values.a == 1 and values.values.b == 2, "reset uses defaults")
check(S.CanUndoReset(card), "reset is undoable")
check(not S.CanUndoReset({}), "other cards cannot undo this reset")
local before = writes
check(S.UndoReset(card), "undo succeeds")
check(writes == before + 3, "shared keys restore once through the store")
check(values.enabled == false and values.size == 30 and values.values.a == 3 and values.values.b == 4, "false and table fields restored")
check(defaults.values.a == 1 and defaults.values.b == 2, "defaults remain untouched")
check(not S.UndoReset(card), "undo is consumed")
S.ResetRow(card.rows[3])
check(values.values.a == 1 and values.values.b == 4, "single field reset preserves sibling")
check(S.UndoReset(card) and values.values.a == 3, "single field can be undone")
S.Reset(card)
values.size = 22
check(not S.CanUndoReset(card) and not S.UndoReset(card), "later edits invalidate undo")
check(values.size == 22, "later edits are preserved")
values.values.a = 5
S.Reset(card)
values.values.a = 1.001
check(not S.CanUndoReset(card), "even a small table edit invalidates undo")
values.size = 30
S.Reset(card)
root = {}
check(not S.CanUndoReset(card), "switching profile invalidates undo")
values.size = 31
card.rows[2].lent = true
S.Reset(card)
check(values.size == 31, "lent values are not reset")
card.rows[2].lent = nil
values.size = nil
S.ResetRow(card.rows[2])
check(values.size == nil, "unset default stays unset")
values.extra = "custom"
local extra = { key = "extra", store = store, card = card }
S.ResetRow(extra)
check(values.extra == nil and S.UndoReset(card) and values.extra == "custom", "nil default can be undone")
local page = S.Page("Demo", store)
local dep = page:Card({ id = "demo", name = "Demo", rows = {
    { key = "enabled", label = "Enable", toggle = true },
    { key = "size", label = "Size", slider = { 1, 50, 1 }, needs = "enabled" },
} })
values.enabled = false
local pageKey, label, uid = S.Dependency(dep.rows[2])
check(pageKey == "Demo" and label == "Enable" and uid == dep.uid, "dependency points at the controlling setting")
values.enabled = true
check(S.Dependency(dep.rows[2]) == nil, "enabled setting has no dependency jump")
dep.rows[2].needs = function() return false end
check(S.Dependency(dep.rows[2]) == nil, "computed dependency does not guess a destination")
print(checks .. " reset undo and dependency checks passed")
