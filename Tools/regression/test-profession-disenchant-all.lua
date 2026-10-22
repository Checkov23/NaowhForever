-- Drives Disenchant All through a fake bag until it is empty: a copy the game keeps failing or refusing must not stall the button.
local saved = {}

_G.NaowhForever = {
    AccountSettings = function() return saved end,
    Professions = {},
}

local ITEM = 300
local SKILL_ERROR = "Your enchanting skill is too low to disenchant this item."
local bag = {}
local outcome = {}
local boundKey

local function Fill(kinds)
    for slot = 1, #kinds do
        bag[slot] = { itemID = ITEM, quality = 2, hyperlink = "[Copy " .. slot .. "]", iconFileID = 1 }
        outcome[slot] = kinds[slot]
    end
end

_G.C_Container = {
    GetContainerNumSlots = function(id) return id == 0 and #outcome or 0 end,
    GetContainerItemInfo = function(id, slot) return id == 0 and bag[slot] or nil end,
}
_G.C_Item = {
    GetItemInfoInstant = function(itemID)
        if itemID == ITEM then return itemID, nil, nil, "INVTYPE_RANGEDRIGHT", nil, 2 end
    end,
    GetItemQualityByID = function() end,
}
_G.C_SpellBook = { IsSpellKnown = function() return true end }
_G.NUM_BAG_SLOTS = 4
_G.BACKPACK_CONTAINER = 0
_G.SPELL_FAILED_CANT_BE_DISENCHANTED_SKILL = SKILL_ERROR

dofile("NaowhForever_Professions/Data/DisenchantValues.lua")
dofile("NaowhForever_Professions/Disenchant.lua")
local disenchant = _G.NaowhForever.Professions.Disenchant

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
function methods.GetFrameLevel() return 1 end
function methods.CreateTexture() return Widget() end

local secureButton, eventFrame
local timers, printed = {}, {}
local targeting = false

local color = { r = 1, g = 1, b = 1 }
_G.NaowhForever.THEME = { accent = color, muted = color, line = color }
_G.NaowhForever.Shared = {
    Parts = {
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
    },
    Style = {
        WINDOW_HEADER = 1, WINDOW_PAD = 1, WINDOW_FOOTER = 1, SCROLLBAR = 1, CONTENT_INSET = 1,
        RED_RGB = color,
    },
    ActionKeys = { Bound = function(command) return boundKey and boundKey[command] end },
}
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
    end
    return frame
end
_G.C_Spell = { GetSpellName = function() return "Disenchant" end }
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
_G.ITEM_QUALITY_COLORS = { [2] = color }
local tipLines = {}
_G.GameTooltip = {
    IsOwned = function() return false end,
    SetOwner = function() for i = #tipLines, 1, -1 do tipLines[i] = nil end end,
    AddLine = function(_, text) tipLines[#tipLines + 1] = text end,
    Show = Noop,
}
_G.GameTooltip_Hide = Noop
_G.InCombatLockdown = function() return false end
_G.SpellIsTargeting = function() return targeting end
_G.SpellStopTargeting = function() error("protected SpellStopTargeting was called") end
_G.IsShiftKeyDown = function() return false end
_G.HandleModifiedItemClick = Noop
_G.hooksecurefunc = Noop

dofile("NaowhForever_Professions/UI/Disenchant.lua")

local function Fire(event, ...)
    eventFrame.scripts.OnEvent(eventFrame, event, ...)
end

local function FailCast()
    Fire("UNIT_SPELLCAST_FAILED", "player", "cast", disenchant.SPELL)
end

local pending
local tried = {}

local function SecureClick()
    local slot = secureButton:GetAttribute("target-slot")
    if secureButton:GetAttribute("type") ~= "macro" or not slot then return end
    tried[#tried + 1] = slot
    local kind = outcome[slot]
    if kind == "skill" then
        Fire("UI_ERROR_MESSAGE", 1, SKILL_ERROR)
        FailCast()
    elseif kind == "cursor" then
        targeting = true
    else
        bag[slot].isLocked = true
        Fire("ITEM_LOCK_CHANGED", 0, slot)
        pending = slot
    end
end

local function Resolve()
    local slot = pending
    pending = nil
    if not slot then return end
    bag[slot].isLocked = nil
    if outcome[slot] == "server" then
        Fire("ITEM_LOCK_CHANGED", 0, slot)
        FailCast()
    else
        bag[slot] = nil
        Fire("BAG_UPDATE_DELAYED")
    end
end

local function Click()
    targeting = false
    secureButton.scripts.PreClick(secureButton, "LeftButton", false)
    SecureClick()
    secureButton.scripts.PostClick(secureButton, "LeftButton", false)
    Resolve()
end

local function Left()
    local n = 0
    for slot = 1, #outcome do
        if bag[slot] and outcome[slot] == "ok" then n = n + 1 end
    end
    return n
end

Fill({ "server", "ok", "skill", "ok", "ok", "cursor", "ok" })
_G.NaowhForever.OpenDisenchant()
assert(secureButton and eventFrame, "the disenchant secure button or event frame was not built")
assert(secureButton:GetAttribute("target-slot") == 1, "Disenchant All did not arm the first copy")

for _ = 1, 20 do
    if Left() == 0 then break end
    Click()
end
assert(Left() == 0, "Disenchant All stalled on a copy the game would not disenchant; tried slots: "
    .. table.concat(tried, " "))

local refused = {}
for i = 1, #printed do refused[#refused + 1] = printed[i] end
assert(#refused == 2 and refused[1]:find("[Copy 3]", 1, true) and refused[2]:find("[Copy 6]", 1, true),
    "the refused copies were not reported once each")
local records, n = disenchant.Collect()
for i = 1, n do
    local r = records[i]
    if r.slot == 3 or r.slot == 6 then
        assert(disenchant.Failed(r), "a refused copy was not skipped")
    else
        assert(not disenchant.Failed(r), "a copy that only failed its cast was skipped until reload")
    end
end
assert(secureButton:GetAttribute("target-slot") == 1 and secureButton:GetAttribute("type") == "macro",
    "the button went dead instead of offering the failing copy again")

Click()
assert(secureButton:GetAttribute("type") == "macro", "a failed cast left the button waiting")
Click()
assert(secureButton:GetAttribute("type") == "macro", "a repeated failed cast left the button waiting")

outcome[1] = "silent"
targeting = false
secureButton.scripts.PreClick(secureButton, "LeftButton", false)
SecureClick()
secureButton.scripts.PostClick(secureButton, "LeftButton", false)
pending = nil
bag[1].isLocked = nil
assert(secureButton:GetAttribute("type") == nil, "the button rearmed before the disenchant resolved")
for _, timer in ipairs(timers) do timer() end
assert(secureButton:GetAttribute("type") == "macro", "a cast with no result event left the button dead")

local function TipSays(text)
    secureButton.hooks.OnEnter(secureButton)
    for _, line in ipairs(tipLines) do
        if line:find(text, 1, true) then return true end
    end
    return false
end
assert(TipSays("Key Bindings"), "the tooltip did not say a key can be set")
boundKey = { ["CLICK NaowhForeverDisenchantAll:LeftButton"] = "F" }
assert(TipSays("Or press F"), "the tooltip did not name the bound key")
assert(not TipSays("Key Bindings"), "the tooltip still asked for a key that is set")

assert(secureButton:GetAttribute("type") == "macro", "the button was not armed before the window closed")
_G.NaowhForever.ToggleDisenchant()
assert(secureButton:GetAttribute("type") == nil and secureButton:GetAttribute("target-slot") == nil,
    "the key binding could still disenchant a stale bag slot with the window closed")

print("Profession disenchant all regression test: PASS")
