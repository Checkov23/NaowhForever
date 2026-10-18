-- Run with Lua 5.1 from the repository root: QoL's Gear Reminders (NaowhForever_QoL/Loot/GearReminders.lua).
-- Off by default and silent while off; Cloak of Hermitic Bliss in Wailing Caverns and a fishing pole each
-- show an icon on their own switch; Ctrl-click hides one until it comes off; Unlock Mode shows samples; and
-- a profile's old AuraBuffs settings move over once, false kept as false.
local checks = 0
local function Check(label, got, want)
    if got ~= want then error(("%s: got %s, want %s"):format(label, tostring(got), tostring(want)), 2) end
    checks = checks + 1
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local NOTHING = function() end
local frames = {}
local function Frame(_, name)
    local f = { scripts = {}, events = {}, shown = true, name = name }
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(on) self.shown = on and true or false end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetPoint(...) self.point = { ... } end
    f.ClearAllPoints, f.SetMovable, f.SetClampedToScreen, f.EnableMouse = NOTHING, NOTHING, NOTHING, NOTHING
    frames[#frames + 1] = f
    return f
end

local state = { worn = {}, instance = "none", instanceID = nil, ctrl = false,
    classes = { [6256] = 2, [2901] = 2 }, subclasses = { [6256] = 20, [2901] = 14 } }
local root = { auraBuffs = {} }
local tooltip = { lines = {} }
function tooltip:SetOwner() self.lines = {} end
function tooltip:SetInventoryItem(_, slot) self.slot = slot end
function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
tooltip.Show, tooltip.Hide = NOTHING, NOTHING

local card, mover
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, accentSoft = { r = 1, g = 1, b = 1 }, muted = { r = 1, g = 1, b = 1 } },
    SettingsRoot = function() return root end,
    Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
    Shared = {
        Parts = { ItemIcon = function()
            local icon = Frame()
            icon.texture = { SetTexture = function(_, t) icon.icon = t end }
            return icon
        end },
        Settings = { Page = function(page) return { Card = function(_, c) card = c; card.page = page end } end },
    },
}
ns.UI = {
    AttachMover = function(_, label, _, page, feature)
        mover = Frame()
        mover.label, mover.page, mover.feature = label, page, feature
        return mover
    end,
    ModuleSettings = function(key, defaults)
        local S = {}
        function S.DB()
            if type(root[key]) ~= "table" then root[key] = {} end
            return root[key]
        end
        function S.Get(k)
            local v = S.DB()[k]
            if v == nil then return defaults[k] end
            return v
        end
        function S.Set(k, v) S.DB()[k] = v end
        return S
    end,
}

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    UIParent = {},
    GameTooltip = tooltip,
    Enum = { ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Fishingpole = 20 } },
    GetInventoryItemID = function(_, slot) return state.worn[slot] end,
    GetInstanceInfo = function() return "x", state.instance, nil, nil, nil, nil, nil, state.instanceID end,
    IsInInstance = function() return state.instance ~= "none", state.instance end,
    IsControlKeyDown = function() return state.ctrl end,
    C_Item = {
        GetItemIconByID = function(id) return "item:" .. id end,
        GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, state.classes[id] or 4, state.subclasses[id] end,
    },
    hooksecurefunc = function(t, name, fn)
        local orig = t[name]
        t[name] = function(...) orig(...); fn(...) end
    end,
}, { __index = _G })
env._G = env

local function Load(path)
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end

_G.NaowhForever = ns
Load("Core/Features.lua")
Load("Core/Settings.lua")
local S = ns.QoLSettings
Load("NaowhForever_QoL/Loot/GearReminders.lua")
local events, boot = frames[1], frames[2]

local function Fire(event, ...)
    events.scripts.OnEvent(events, event, ...)
end

local function Main()
    for _, f in ipairs(frames) do
        if f.name == "NaowhForeverGearReminders" then return f end
    end
end

local function Shown()
    local out = {}
    if not (Main() and Main().shown) then return "" end
    for _, f in ipairs(frames) do
        if f.icon and f.shown then out[#out + 1] = f.icon end
    end
    return table.concat(out, " ")
end

local function IconFor(slot)
    for _, f in ipairs(frames) do
        if f.icon and f.shown and f.slot == slot then return f end
    end
end

Check("both switches start off", ns.FEATURES.qol.wornReminders == false and ns.FEATURES.qol.fishingPoleReminder == false, true)
Check("the card is on Loot & Items", card.page, "QoL/Loot & Items")
Check("its id", card.id, "gearReminders")
Check("the XML loads it", Read("NaowhForever_QoL/QoL.xml"):find("Loot\\GearReminders.lua", 1, true) ~= nil, true)
Check("AuraBuffs keeps no gear settings", Read("NaowhForever_Combat/AuraBuffs/AuraBuffs.lua"):find("wornReminders", 1, true), nil)

boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
Check("a new profile: nothing to move, the defaults stand", root.qol.wornReminders, nil)
Check("the cloak is off by default", S.Get("wornReminders"), false)
Check("off: no events", next(events.events), nil)
Check("off: no frame built", mover, nil)

-- An old profile: AuraBuffs had the cloak on and the pole off, shown only in dungeons and raids.
root.auraBuffs = { wornReminders = true, fishingPoleReminder = false, fishingPoleWhere = "instance", iconSize = 40 }
ns.Apply()
Check("the cloak switch moves over", root.qol.wornReminders, true)
Check("a switch that was off stays off, not the default", root.qol.fishingPoleReminder, false)
Check("its Shows In moves over", root.qol.fishingPoleWhere, "instance")
Check("and leaves AuraBuffs", root.auraBuffs.wornReminders == nil and root.auraBuffs.fishingPoleWhere == nil, true)
Check("whose own settings stay", root.auraBuffs.iconSize, 40)
S.Set("fishingPoleWhere", "always")
root.auraBuffs.fishingPoleWhere = "instance"
ns.Apply()
Check("a value set in QoL is never overwritten", root.qol.fishingPoleWhere, "always")
root.qol = {}
ns.Apply()
Check("switched off again: events dropped", next(events.events), nil)

-- Worn Gear Reminder: Cloak of Hermitic Bliss worn in Wailing Caverns.
state.worn[15], state.instance, state.instanceID = 273084, "party", 43
S.Set("fishingPoleReminder", true)
Check("the fishing pole switch alone leaves the cloak out", Shown(), "")
Check("its own switch listens for gear changes", events.events.PLAYER_EQUIPMENT_CHANGED, true)
Check("its mover is in Unlock Mode, on its card", mover.feature, "QoL/Loot & Items:gearReminders")
S.Set("fishingPoleReminder", false)
S.Set("wornReminders", true)
Check("cloak worn in Wailing Caverns", Shown(), "item:273084")
state.worn[15] = nil
Fire("PLAYER_EQUIPMENT_CHANGED", 15, false)
Check("cloak taken off", Shown(), "")
state.worn[15], state.instanceID = 273084, 36
Fire("PLAYER_EQUIPMENT_CHANGED", 15, true)
Check("cloak worn in another dungeon", Shown(), "")
state.instance, state.instanceID = "none", nil
Fire("ZONE_CHANGED_NEW_AREA")
Check("cloak worn outside", Shown(), "")
state.instance, state.instanceID = "party", 43
Fire("PLAYER_ENTERING_WORLD")
Check("back in Wailing Caverns", Shown(), "item:273084")
local cloak = IconFor(15)
cloak.scripts.OnEnter(cloak)
Check("its tooltip is the item's own", tooltip.slot, 15)
Check("with what to do about it", tooltip.lines[2], "Ctrl-click to hide it until you take it off.")
S.Set("wornReminders", false)
Check("switched off", Shown(), "")
Check("switched off: events dropped", next(events.events), nil)

-- Fishing Pole Reminder: any fishing pole in the main hand, anywhere.
state.worn[15], state.worn[16], state.instance, state.instanceID = nil, 6256, "none", nil
S.Set("wornReminders", true)
Check("Worn Gear Reminder alone leaves the pole out", Shown(), "")
S.Set("wornReminders", false)
S.Set("fishingPoleReminder", true)
Check("fishing pole worn outside", Shown(), "item:6256")
state.instance, state.instanceID = "party", 36
Fire("PLAYER_ENTERING_WORLD")
Check("and in a dungeon", Shown(), "item:6256")
state.worn[16] = 2901
Fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
Check("another weapon in its place", Shown(), "")
state.worn[16], state.classes[2901], state.subclasses[2901] = 2901, 15, 20
Fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
Check("something not a weapon with a pole's subclass number", Shown(), "")

-- Shows In: Dungeons & Raids, and Ctrl-click hides it until it comes off.
state.worn[16], state.instance, state.instanceID = 6256, "none", nil
S.Set("fishingPoleWhere", "instance")
Check("pole set to dungeons and raids, out in the world", Shown(), "")
state.instance, state.instanceID = "raid", 409
Fire("PLAYER_ENTERING_WORLD")
Check("and in a raid", Shown(), "item:6256")
S.Set("fishingPoleWhere", "always")
local pole = IconFor(16)
pole.scripts.OnMouseUp(pole)
Check("a plain click keeps it", Shown(), "item:6256")
state.ctrl = true
pole.scripts.OnMouseUp(pole)
state.ctrl = false
Check("Ctrl-click hides it", Shown(), "")
Fire("ZONE_CHANGED_NEW_AREA")
Check("and it stays hidden while worn", Shown(), "")
state.worn[16] = nil
Fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
state.worn[16] = 6256
Fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
Check("taken off and put back on, it shows again", Shown(), "item:6256")

-- Unlock Mode: a sample of each reminder that is on, to place them by.
state.worn[16] = nil
Fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
S.Set("wornReminders", true)
ns.ShowUnlockMode()
Check("unlocked: the mover shows", mover.shown, true)
Check("with a sample of each", Shown(), "item:273084 item:6256")
Check("the frame fits both", Main().w, 2 * 48 + 4)
local sample = IconFor(nil)
sample.scripts.OnEnter(sample)
sample.scripts.OnMouseUp(sample)
ns.HideUnlockMode()
Check("locked again: only what you wear", Shown(), "")
Check("and the mover hides", mover.shown, false)
S.Set("gearReminderSize", 32)
state.worn[15], state.instance, state.instanceID = 273084, "party", 43
Fire("PLAYER_ENTERING_WORLD")
Check("Icon Size sizes the icons", IconFor(15).w, 32)

print(("test-gear-reminders: %d checks passed"):format(checks))
