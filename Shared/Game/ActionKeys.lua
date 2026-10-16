-- ActionKeys.lua: the keys on action buttons, the game's, LibActionButton bars' and EllesmereUI's, and a bar's map of them (ns.Shared.ActionKeys).
local ns = _G.NaowhForever

local LAB_NAMES = { "LibActionButton-1.0", "LibActionButton-1.0-ElvUI" }
local EUI_PREFIX = "EABButton"
local EUI_SLOTS = 180
local CLICK = "CLICK %s:%s"
local CLICK_LEFT, CLICK_KEYBIND = "LeftButton", "Keybind"
local KEY_EVENTS = { "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR" }
local MOUSE_KEY = "^(.-)BUTTON(%d+)$"
local MOUSE_TEXT = "M%s"
local MODIFIER_LETTERS = { { "ALT%-", "A" }, { "CTRL%-", "C" }, { "SHIFT%-", "S" } }

local ActionKeys = {}
ns.Shared.ActionKeys = ActionKeys

function ActionKeys.Text(key)
    local modifiers, number = key:match(MOUSE_KEY)
    if not number then return GetBindingText(key, true) end
    local letters = ""
    for _, pair in ipairs(MODIFIER_LETTERS) do
        if modifiers:find(pair[1]) then letters = letters .. pair[2] end
    end
    return letters .. MOUSE_TEXT:format(number)
end

function ActionKeys.Bound(command)
    local key = GetBindingKey(command)
    return key and ActionKeys.Text(key)
end

local function Try(command)
    if type(command) ~= "string" then return nil end
    return ActionKeys.Bound(command)
end

function ActionKeys.OfButton(btn)
    local hotkey = btn.HotKey and btn.HotKey:GetText()
    if hotkey and hotkey ~= "" and hotkey ~= RANGE_INDICATOR then return hotkey end
    local name = btn.GetName and btn:GetName()
    return Try(btn.bindingAction) or Try(btn.commandName) or Try(btn.GetAttribute and btn:GetAttribute("binding"))
        or (name and (Try(CLICK:format(name, CLICK_LEFT)) or Try(CLICK:format(name, CLICK_KEYBIND))))
end

function ActionKeys.Each(visit)
    local frames = ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames
    for _, btn in pairs(frames or {}) do visit(btn, btn.action) end
    for slot = 1, EUI_SLOTS do
        local btn = _G[EUI_PREFIX .. slot]
        if btn and btn.GetAttribute then visit(btn, btn:GetAttribute("action")) end
    end
    for _, libName in ipairs(LAB_NAMES) do
        local lab = LibStub and LibStub(libName, true)
        local all = lab and lab.GetAllButtons and lab:GetAllButtons()
        for k, v in pairs(all or {}) do
            local btn = type(k) == "table" and k or v
            local kind, action = btn:GetAction()
            if kind == "action" then
                visit(btn, action)
            elseif kind == "item" then
                visit(btn, nil, tonumber(tostring(action):match("(%d+)")))
            end
        end
    end
end

function ActionKeys.Listen(frame, on)
    for _, event in ipairs(KEY_EVENTS) do
        if on then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
    end
end

function ActionKeys.NewQueue(refresh)
    local pending
    local function Run()
        pending = nil
        refresh()
    end
    return function()
        if pending then return end
        pending = true
        C_Timer.After(0, Run)
    end
end

function ActionKeys.NewMap(entryOf)
    local map = { keys = {}, hidden = {} }
    local keys, hidden = map.keys, map.hidden
    local function Note(btn, slot, item)
        local entry = entryOf(slot, item)
        if entry == nil then return end
        local hotkey = ActionKeys.OfButton(btn)
        if not hotkey then return end
        if btn:IsVisible() then keys[entry] = keys[entry] or hotkey
        else hidden[entry] = hidden[entry] or hotkey end
    end
    function map.Read(first)
        wipe(keys)
        wipe(hidden)
        if first then first(keys) end
        ActionKeys.Each(Note)
        for entry, hotkey in pairs(hidden) do keys[entry] = keys[entry] or hotkey end
        return keys
    end
    function map.Clear()
        wipe(keys)
        return keys
    end
    return map
end
