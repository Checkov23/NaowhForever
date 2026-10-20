-- Run with Lua 5.1 from the repository root: Auto-Accept Layer Swap.
-- Off it listens to nothing; on, the layer swap prompt is clicked and its popup confirmed when you join a
-- group, or when the prompt shows while you are in one. A popup that was already up is never confirmed.
local NOTHING = function() end
local frames = {}
local grouped = false

local function Frame()
    local f = { scripts = {}, events = {}, shown = false }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:IsShown() return self.shown end
    frames[#frames + 1] = f
    return f
end

local settings = { enabled = true }
local setHooks, applyHooks = {}, {}
local S = { Get = function(k) return settings[k] end }
local card
local gamepad = false
local ns = {
    GamepadStandDown = function() return gamepad end,
    QoLSettings = S,
    Apply = NOTHING,
    Shared = { Settings = { Page = function() return { Card = function(_, c) card = c end } end } },
}

local popup, confirmed, clicked, shownHooks = Frame(), 0, 0, {}
popup.IsShown = function() return popup.shown end
local popupButton = { Click = function() confirmed = confirmed + 1 end }
local prompt = { shown = false }
function prompt:IsShown() return self.shown end
function prompt:HookScript(name, fn) shownHooks[#shownHooks + 1] = fn end
function prompt:Click(button, down)
    clicked = clicked + 1
    assert(button == "LeftButton" and down == true)
    popup.shown = true
end

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    IsInGroup = function() return grouped end,
    StaticPopup1 = popup,
    StaticPopup1Button1 = popupButton,
    hooksecurefunc = function(t, name, fn)
        if t == S then setHooks[#setHooks + 1] = fn elseif name == "Apply" then applyHooks[#applyHooks + 1] = fn end
    end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/LayerSwap.lua"))
setfenv(chunk, env)
chunk()
local events, boot = frames[2], frames[3]

local function Set(k, v)
    settings[k] = v
    for _, fn in ipairs(setHooks) do fn(k) end
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("the card is on Questing & Group, behind its own switch", function()
    assert(card and card.switch == "layerSwap")
end)

Case("off by default: no events, nothing hooked", function()
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    assert(next(events.events) == nil and #shownHooks == 0)
end)

Case("the Gamepad interface style: switching on listens to nothing and hooks nothing", function()
    gamepad = true
    Set("layerSwap", true)
    assert(next(events.events) == nil and #shownHooks == 0)
    Set("layerSwap", false)
    gamepad = false
end)

Case("a game without the prompt: switching on only listens", function()
    Set("layerSwap", true)
    assert(events.events.GROUP_JOINED and #shownHooks == 0)
    events.scripts.OnEvent(events, "GROUP_JOINED")
    assert(clicked == 0)
end)

Case("the prompt exists: hooked once", function()
    env.ShardTransferImminentFrame = prompt
    grouped = true
    events.scripts.OnEvent(events, "GROUP_JOINED")
    events.scripts.OnEvent(events, "GROUP_JOINED")
    assert(#shownHooks == 1 and clicked == 0)
end)

Case("joining a group with the prompt up: clicked and confirmed", function()
    prompt.shown = true
    events.scripts.OnEvent(events, "GROUP_JOINED")
    assert(clicked == 1 and confirmed == 1)
end)

Case("the prompt showing while in a group: clicked and confirmed", function()
    popup.shown = false
    shownHooks[1]()
    assert(clicked == 2 and confirmed == 2)
end)

Case("not in a group: left alone", function()
    popup.shown, grouped = false, false
    shownHooks[1]()
    assert(clicked == 2)
    grouped = true
end)

Case("a popup already up: the prompt is clicked, that popup is not confirmed", function()
    popup.shown = true
    shownHooks[1]()
    assert(clicked == 3 and confirmed == 2)
    popup.shown = false
end)

Case("switched off: events dropped and the hook does nothing", function()
    Set("layerSwap", false)
    assert(next(events.events) == nil)
    shownHooks[1]()
    assert(clicked == 3)
end)

print(count .. " layer-swap checks passed")
