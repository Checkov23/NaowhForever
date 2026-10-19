-- Loads Disenchant.lua against two copies of one item and checks failures and locks stay per copy.
local saved = {}

_G.NaowhForever = {
    AccountSettings = function() return saved end,
    Professions = {},
}

_G.C_Container = {
    GetContainerNumSlots = function() return 0 end,
    GetContainerItemInfo = function() end,
}
_G.C_Item = {
    GetItemInfoInstant = function() end,
    GetItemQualityByID = function() end,
}
_G.C_SpellBook = { IsSpellKnown = function() return true end }
_G.NUM_BAG_SLOTS = 4
_G.BACKPACK_CONTAINER = 0

dofile("NaowhForever_Professions/Disenchant.lua")

local disenchant = _G.NaowhForever.Professions.Disenchant
local first = { bag = 0, slot = 1, itemID = 100, guid = "first", failureKey = "first", locked = false }
local second = { bag = 0, slot = 2, itemID = 100, guid = "second", failureKey = "second", locked = false }

disenchant.MarkFailed(first)
assert(disenchant.Failed(first), "the refused copy was not remembered")
assert(not disenchant.Failed(second), "another copy of the same item was refused")
assert(disenchant.Ready(second), "the unaffected copy was not ready")

second.locked = true
assert(not disenchant.Ready(second), "a locked item was ready")

local function Noop() end
local methods = {}
local widgetMeta = { __index = function(_, key) return methods[key] or Noop end }
local function Widget()
    return setmetatable({ shown = false, scripts = {}, hooks = {}, attributes = {} }, widgetMeta)
end

function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.HookScript(self, name, fn) self.hooks[name] = fn end
function methods.Show(self)
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
    if self.hooks.OnShow then self.hooks.OnShow(self) end
end
function methods.Hide(self)
    if not self.shown then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
    if self.hooks.OnHide then self.hooks.OnHide(self) end
end
function methods.SetShown(self, shown) if shown then self:Show() else self:Hide() end end
function methods.IsShown(self) return self.shown end
function methods.SetAttribute(self, key, value) self.attributes[key] = value end
function methods.GetAttribute(self, key) return self.attributes[key] end
function methods.SetText(self, text) self.text = text end
function methods.SetPropagateKeyboardInput(self, propagate) self.propagate = propagate end
function methods.GetFrameLevel() return 1 end
function methods.CreateTexture() return Widget() end

local secureButton, eventFrame, keyFrame
local timers, printed = {}, {}
local targeting, refused = false, false
local uiRecord = { bag = 1, slot = 2, itemID = 200, link = "[Test Item]", icon = 1,
    quality = 2, guid = "ui-copy", failureKey = "ui-copy", locked = false }

local originalMarkFailed = disenchant.MarkFailed
disenchant.MarkFailed = function(record) refused = true; originalMarkFailed(record) end
disenchant.Known = function() return true end
disenchant.Kept = function() return false end
disenchant.KeptAll = function() return false end
disenchant.KeptCopy = function() return false end
disenchant.ToggleKeep = Noop
disenchant.Collect = function() return { uiRecord }, 1 end
disenchant.Next = function() return not refused and uiRecord or nil end
disenchant.Counts = function() return refused and 0 or 1, 0 end

local color = { r = 1, g = 1, b = 1 }
local parts = {
    Window = function()
        local window = Widget()
        window.backdrop = Widget()
        return window
    end,
    ItemIcon = function()
        local icon = Widget()
        icon.texture, icon.edge = Widget(), Widget()
        return icon
    end,
    MarkForever = Noop,
    TitleBar = Noop,
    FooterBrand = Noop,
}
_G.NaowhForever.THEME = { accent = color, muted = color, line = color }
_G.NaowhForever.Shared = { Parts = parts, Style = {
    WINDOW_HEADER = 1, WINDOW_PAD = 1, WINDOW_FOOTER = 1, SCROLLBAR = 1, CONTENT_INSET = 1,
    RED_RGB = color,
} }
_G.NaowhForever.UI = { SlimScroll = function() return Widget() end }
_G.NaowhForever.Professions.Settings = { Get = function() return true end }
_G.NaowhForever.Professions.Recipes = {
    Profession = function() return { id = disenchant.ENCHANTING } end,
    Own = function() return true end,
}
_G.NaowhForever.Professions.Window = { Render = Noop }
_G.NaowhForever.Professions.State = {}
_G.NaowhForever.L = function(text) return text end
_G.NaowhForever.Print = function(text) printed[#printed + 1] = text end
_G.NaowhForever.Font = function() return Widget() end
_G.NaowhForever.Border = function() return Widget() end
_G.NaowhForever.Button = function(_, _, _, _, _, template)
    local button = Widget()
    if template == "SecureActionButtonTemplate" then secureButton = button end
    return button
end
_G.NaowhForever.SetButtonText = function(button, text) button.text = text end
_G.NaowhForever.UIScale = function() return 1 end

_G.CreateFrame = function()
    local frame = Widget()
    local setScript = frame.SetScript
    frame.SetScript = function(self, name, fn)
        setScript(self, name, fn)
        if name == "OnEvent" then eventFrame = self end
        if name == "OnKeyDown" then keyFrame = self end
    end
    return frame
end
_G.C_Spell = { GetSpellName = function() return "Disenchant" end }
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
_G.ITEM_QUALITY_COLORS = { [2] = color }
_G.GameTooltip = { IsOwned = function() return false end }
_G.GameTooltip_Hide = Noop
_G.InCombatLockdown = function() return false end
_G.SpellIsTargeting = function() return targeting end
_G.SpellStopTargeting = function() error("protected SpellStopTargeting was called") end
_G.IsShiftKeyDown = function() return false end
_G.HandleModifiedItemClick = Noop
_G.hooksecurefunc = function() end

dofile("NaowhForever_Professions/UI/Disenchant.lua")
_G.NaowhForever.OpenDisenchant()
assert(secureButton and eventFrame, "the disenchant secure button or event frame was not built")
assert(secureButton:GetAttribute("type") == "macro", "the next item was not armed")
local macro = secureButton:GetAttribute("macrotext")
assert(macro:find("/stopspelltarget", 1, true) and not macro:find("/use", 1, true),
    "the secure macro can use the item when Disenchant did not start")
assert(secureButton:GetAttribute("target-bag") == 1 and secureButton:GetAttribute("target-slot") == 2,
    "the secure target attributes do not point at the selected bag slot")

local function Click(beforePost)
    secureButton.scripts.PreClick(secureButton, "LeftButton", false)
    if beforePost then beforePost() end
    secureButton.scripts.PostClick(secureButton, "LeftButton", false)
end

local timerCount = #timers
targeting = false
Click(function()
    eventFrame.scripts.OnEvent(eventFrame, "UNIT_SPELLCAST_FAILED", "player", nil, disenchant.SPELL)
end)
assert(secureButton:GetAttribute("type") == "macro" and #timers == timerCount,
    "a synchronous failed cast left the button waiting")

for _ = 1, 3 do
    targeting = false
    Click()
    assert(secureButton:GetAttribute("type") == nil and secureButton.text == "Disenchanting...",
        "the button rearmed before the disenchant completed")
    timerCount = #timers
    Click()
    assert(#timers == timerCount, "an extra click started another disenchant wait")
    eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
    assert(secureButton:GetAttribute("type") == "macro", "a bag update did not rearm the next copy")
end

targeting = false
Click()
eventFrame.scripts.OnEvent(eventFrame, "UNIT_SPELLCAST_FAILED", "player", nil, 999)
assert(secureButton:GetAttribute("type") == nil, "an unrelated failed spell released the wait")
eventFrame.scripts.OnEvent(eventFrame, "UNIT_SPELLCAST_FAILED", "player", nil, disenchant.SPELL)
assert(secureButton:GetAttribute("type") == "macro", "a failed disenchant did not release the wait")

targeting = false
Click()
for _, timer in ipairs(timers) do timer() end
assert(secureButton:GetAttribute("type") == "macro", "the missing-event timeout did not rearm the button")

targeting = true
Click()
assert(disenchant.Failed(uiRecord) and secureButton:GetAttribute("type") == nil,
    "a refused copy was not skipped without calling the protected API")
assert(#printed > 0 and printed[#printed]:find("Right%-click") and printed[#printed]:find("Escape"),
    "a refused copy did not explain how to cancel the item cursor")
assert(keyFrame, "the window keyboard frame was not built")
keyFrame.scripts.OnKeyDown(keyFrame, "ESCAPE")
assert(keyFrame.propagate == true, "Escape was not passed through to cancel the item cursor")

print("Profession disenchant regression test: PASS")
