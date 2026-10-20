-- Run with Lua 5.1 from the repository root: Type DELETE For You fills in DELETE,
-- leaves the box showing it, names the item, and leaves Yes clickable, as a tester found it did
-- not on Forever: the box filled in by code never told the dialog, so Yes stayed greyed. The box
-- here does the same: SetText runs no change handler.
local settings = { enabled = true }
local hook
local function Frame()
    local f = { shown = true }
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetText(text) self.text = text end
    function f:GetText() return self.text end
    function f:GetHeight() return self.height or 100 end
    function f:SetHeight(h) self.height = h end
    return f
end

local dialog, yes = Frame(), Frame()
yes.enabled = false
function yes:SetEnabled(on) self.enabled = on end
function dialog:GetName() return "StaticPopup1" end
function dialog:GetButton1() return yes end
function dialog:Resize() self.resized = true end
dialog.hooks = {}
function dialog:HookScript(script, fn)
    assert(not self.hooks[script], "hooked once")
    self.hooks[script] = fn
end
local box, text = Frame(), Frame()
function box:GetParent() return dialog end

local cursor
local gamepad = false
local env = setmetatable({
    NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = { Get = function(key) return settings[key] end },
        GamepadStandDown = function() return gamepad end,
        Shared = { Settings = { Page = function() return { Card = function() end } end } } },
    hooksecurefunc = function(name, fn)
        assert(name == "StaticPopup_Show")
        hook = fn
    end,
    StaticPopup_FindVisible = function() return dialog end,
    StaticPopup1EditBox = box,
    StaticPopup1Text = text,
    GetCursorInfo = function() return cursor and "item", 6948, cursor end,
    DELETE_GOOD_ITEM = "Do you want to destroy %s?\n\nType \"DELETE\" into the field to confirm.",
    DELETE_ITEM_CONFIRM_STRING = "DELETE",
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    GameTooltip_Hide = function() end,
    GameTooltip = { SetOwner = function(self) self.owned = true end,
        SetHyperlink = function(self, link) self.link = link end,
        Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end },
}, { __index = _G })
env._G = env
-- The game's dialogs: the typed ones enable Yes once the box reads DELETE.
local function Check(editBox) editBox:GetParent():GetButton1():SetEnabled(editBox:GetText() == "DELETE") end
env.StaticPopupDialogs = { DELETE_GOOD_ITEM = { EditBoxOnTextChanged = Check }, DELETE_ITEM = {},
    DELETE_QUEST_ITEM = {}, DELETE_GOOD_QUEST_ITEM = { EditBoxOnTextChanged = Check } }
local chunk = assert(loadfile("NaowhForever_QoL/Loot/DeleteConfirm.lua"))
setfenv(chunk, env)
chunk()

local count = 0
local function Case(name, fn)
    box.shown, box.text, yes.enabled, dialog.resized = true, nil, false, false
    cursor = "|Hitem:6948|h[Hearthstone]|h"
    text.text = "Do you want to destroy Hearthstone?\n\nType \"DELETE\" into the field to confirm."
    fn()
    count = count + 1
    print("PASS " .. name)
end

Case("off by default: the box is left to type in", function()
    hook("DELETE_GOOD_ITEM")
    assert(box.shown and box.text == nil and not yes.enabled)
end)
settings.deleteConfirm = true
Case("the Gamepad interface style: the popup is left as the game shows it", function()
    gamepad = true
    hook("DELETE_GOOD_ITEM")
    gamepad = false
    assert(box.text == nil and not yes.enabled and not dialog.resized and next(dialog.hooks) == nil)
end)
Case("on: DELETE filled in, the box left showing, and Yes clickable", function()
    hook("DELETE_GOOD_ITEM")
    assert(box.text == "DELETE" and box.shown, "filled in and showing")
    assert(yes.enabled, "Yes clickable")
end)
Case("the item named as a link in place of the instruction", function()
    hook("DELETE_GOOD_ITEM")
    assert(text.text == "Do you want to destroy Hearthstone?\n\n|Hitem:6948|h[Hearthstone]|h", text.text)
    assert(dialog.resized, "dialog laid out again around the link")
end)
Case("a dialog with no box: nothing typed, Yes left as the game set it", function()
    box.shown = false
    hook("DELETE_ITEM")
    assert(box.text == nil and not yes.enabled)
end)
Case("other popups are not touched", function()
    hook("CONFIRM_LOOT_ROLL")
    assert(box.shown and box.text == nil and not yes.enabled)
end)
Case("the link tooltip hooks the dialog frame, not the game's dialog tables", function()
    for name, info in pairs(env.StaticPopupDialogs) do
        assert(info.OnHyperlinkEnter == nil and info.OnHyperlinkLeave == nil, name .. " written into")
    end
    local tip = env.GameTooltip
    dialog.which = "DELETE_GOOD_ITEM"
    dialog.hooks.OnHyperlinkEnter(dialog, "item:6948")
    assert(tip.shown and tip.link == "item:6948", "tooltip shown on a delete dialog")
    dialog.hooks.OnHyperlinkLeave(dialog)
    assert(not tip.shown, "tooltip hidden on leave")
    tip.link = nil
    dialog.which = "CONFIRM_LOOT_ROLL"
    dialog.hooks.OnHyperlinkEnter(dialog, "item:1")
    assert(tip.link == nil, "the pooled dialog reused by another popup shows nothing")
end)
print(count .. " delete confirmation regressions passed")
