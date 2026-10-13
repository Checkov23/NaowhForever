-- DamageMeterLayout.lua: the game's damage meter settings in the active Edit Mode layout, set without opening Edit Mode.
local ns = _G.NaowhForever

local DEBOUNCE, VERIFY = 0.5, 0.5
local BACKUP_KEY = "damageMeterLayoutBackup"
local DIFF, STEP, FLAG = "diff", "step", "flag"
local TEXT_COMBAT = ns.L("Not in combat.")
local TEXT_NO_EDIT_MODE = ns.L("The game's layouts are not available.")
local TEXT_EDIT_MODE_OPEN = ns.L("Close Edit Mode first.")
local TEXT_PRESET = ns.L("Your active layout is one of the game's own: make a copy in Edit Mode first.")
local TEXT_NO_SYSTEM = ns.L("This layout has no damage meter.")
local TEXT_FAILED = ns.L("The game would not save the layout (%s).")
local TEXT_RELOAD = ns.L("Needs a /reload")
local TEXT_NOTHING = ns.L("Nothing to restore yet: it remembers your settings from before your first change.")

local SPECS = {
    { name = "Style", label = "Bar Style", enum = "DamageMeterStyle", members = { "Default", "Bordered", "Thin" },
      names = { "Default", "Bordered", "Thin" }, help = "Default, Bordered or Thin bars." },
    { name = "Numbers", label = "Numbers", enum = "DamageMeterNumbers", members = { "Minimal", "Compact", "Complete" },
      names = { "Minimal", "Compact", "Complete" }, default = "Compact", help = "How much of each number is written." },
    { name = "FrameWidth", label = "Window Width", convert = DIFF, min = 200, max = 600, step = 1, default = 300,
      unit = "px", frame = true, help = "The window's width, which Move and Resize sets by dragging." },
    { name = "FrameHeight", label = "Window Height", convert = DIFF, min = 120, max = 400, step = 1, default = 200,
      unit = "px", frame = true, help = "The window's height, which Move and Resize sets by dragging." },
    { name = "BarHeight", label = "Bar Height", convert = DIFF, min = 15, max = 40, step = 1, default = 24,
      unit = "px", help = "How tall each bar is." },
    { name = "Padding", label = "Bar Spacing", convert = STEP, min = 2, max = 10, step = 1, default = 4,
      unit = "px", help = "The gap between the bars." },
    { name = "Transparency", label = "Window Opacity", convert = STEP, min = 50, max = 100, step = 1, default = 100,
      unit = "%", help = "How solid the whole window is, from half to full." },
    { name = "BackgroundTransparency", label = "Background Opacity", convert = STEP, min = 0, max = 100, step = 1,
      default = 0, unit = "%", help = "How solid the window's own background is, from none to full." },
    { name = "TextSize", label = "Text Size", convert = STEP, min = 50, max = 150, step = 10, default = 100,
      unit = "%", help = "The size of all the text, against normal." },
    { name = "Visibility", label = "Visibility", enum = "DamageMeterVisibility",
      members = { "Always", "InCombat", "Hidden", "InGroup" },
      names = { "Always Visible", "In Combat", "Hidden", "In Group" },
      help = "When the meter shows: always, in combat, in a group or never." },
    { name = "ShowSpecIcon", label = "Show Spec Icon", convert = FLAG, default = true,
      help = "A spec icon at the start of each bar." },
    { name = "ShowClassColor", label = "Show Class Color", convert = FLAG, default = true,
      help = "Colors each bar by class, unless the reskin picks another color." },
}

local byName = {}
for _, spec in ipairs(SPECS) do byName[spec.name] = spec end

local pending, shown, status = {}, {}, {}
local backedUp = false

local function Has(object, method)
    return type(object) == "table" and type(object[method]) == "function"
end

local function Refresh()
    if ns.UI and ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function Say(owner, text)
    if status[owner] == text then return end
    status[owner] = text
    Refresh()
end

local function Manager()
    local frame = _G.EditModeManagerFrame
    if type(frame) == "table" and type(frame.layoutInfo) == "table" then return frame end
end

local function ActiveLayout(info)
    local layouts = info.layouts
    local layout = type(layouts) == "table" and layouts[info.activeLayout] or nil
    if type(layout) == "table" then return layout end
end

local function SystemOf(layout)
    if type(layout.systems) ~= "table" then return nil end
    for _, system in ipairs(layout.systems) do
        if system.system == Enum.EditModeSystem.DamageMeter then return system end
    end
end

local function SettingId(spec)
    local list = Enum and Enum.EditModeDamageMeterSetting
    return list and list[spec.name]
end

local function EntryOf(system, id)
    if type(system.settings) ~= "table" then return nil end
    for index, entry in ipairs(system.settings) do
        if entry.setting == id then return entry, index end
    end
end

local function Clamp(spec, value)
    if value < spec.min then return spec.min end
    if value > spec.max then return spec.max end
    return value
end

local function EnumValue(spec, member)
    local list = Enum and Enum[spec.enum]
    return type(list) == "table" and list[member] or nil
end

local function ToStored(spec, display)
    if spec.enum then return display end
    if spec.convert == FLAG then return display and 1 or 0 end
    if spec.convert == DIFF then return display - spec.min end
    return (display - spec.min) / spec.step
end

local function ToDisplay(spec, stored)
    if spec.enum then return stored end
    if spec.convert == FLAG then return stored == 1 end
    if spec.convert == DIFF then return Clamp(spec, stored + spec.min) end
    return Clamp(spec, stored * spec.step + spec.min)
end

local function DefaultDisplay(spec)
    if spec.enum then return EnumValue(spec, spec.default or spec.members[1]) end
    return spec.default
end

local function StoredOf(system, spec)
    local id = SettingId(spec)
    local entry = id and EntryOf(system, id)
    if entry and type(entry.value) == "number" then return entry.value end
end

local function LayoutValue(spec)
    local frame = Manager()
    local layout = frame and ActiveLayout(frame.layoutInfo)
    local system = layout and SystemOf(layout)
    local stored = system and StoredOf(system, spec)
    if stored then return ToDisplay(spec, stored) end
    return DefaultDisplay(spec)
end

local function Shown(spec)
    local value = shown[spec.name]
    if value ~= nil then return value end
    return LayoutValue(spec)
end

local function Backup(layout, system)
    if backedUp then return end
    backedUp = true
    local values = {}
    for _, spec in ipairs(SPECS) do values[spec.name] = StoredOf(system, spec) or false end
    local saved = { name = layout.layoutName, values = values }
    if C_EditMode and C_EditMode.ConvertLayoutInfoToString then
        local ok, text = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
        if ok and type(text) == "string" then saved.text = text end
    end
    ns.AccountSettings()[BACKUP_KEY] = saved
end

local function Target(owner)
    if InCombatLockdown() then Say(owner, TEXT_COMBAT) return nil end
    local frame = Manager()
    if not (frame and C_EditMode and C_EditMode.SaveLayouts) then Say(owner, TEXT_NO_EDIT_MODE) return nil end
    if Has(frame, "IsShown") and frame:IsShown() then Say(owner, TEXT_EDIT_MODE_OPEN) return nil end
    local info = CopyTable(frame.layoutInfo)
    local layout = ActiveLayout(info)
    if not layout then Say(owner, TEXT_NO_EDIT_MODE) return nil end
    if layout.layoutType == Enum.EditModeLayoutType.Preset then Say(owner, TEXT_PRESET) return nil end
    local system = SystemOf(layout)
    if not system then Say(owner, TEXT_NO_SYSTEM) return nil end
    return info, layout, system
end

local function Differs(system, updates)
    for name, value in pairs(updates) do
        local id = SettingId(byName[name])
        local entry = id and EntryOf(system, id)
        if value == false then
            if entry then return true end
        elseif not entry or entry.value ~= value then
            return true
        end
    end
    return false
end

local function Write(system, updates)
    system.settings = system.settings or {}
    for name, value in pairs(updates) do
        local id = SettingId(byName[name])
        if id then
            local entry, index = EntryOf(system, id)
            if value == false then
                if index then table.remove(system.settings, index) end
            elseif entry then
                entry.value = value
            else
                system.settings[#system.settings + 1] = { setting = id, value = value }
            end
        end
    end
end

local function Change(updates, owner)
    local info, layout, system = Target(owner)
    if not info or not Differs(system, updates) then return false end
    Backup(layout, system)
    Write(system, updates)
    local ok, err = pcall(C_EditMode.SaveLayouts, info)
    if not ok then
        Say(owner, TEXT_FAILED:format(tostring(err)))
        return false
    end
    Say(owner, nil)
    return true
end

local function Flush(updates, expect, owner)
    if not Change(updates, owner) then
        for name in pairs(expect) do shown[name] = nil end
        return
    end
    C_Timer.After(VERIFY, function()
        local taken = true
        for name, display in pairs(expect) do
            if LayoutValue(byName[name]) ~= display then taken = false end
        end
        if taken then
            for name in pairs(expect) do shown[name] = nil end
        else
            Say(owner, TEXT_RELOAD)
        end
    end)
end

local function Request(spec, display)
    if not (spec.enum or spec.convert == FLAG) then display = Clamp(spec, display) end
    shown[spec.name] = display
    status[spec.name] = nil
    pending[spec.name] = (pending[spec.name] or 0) + 1
    local token = pending[spec.name]
    C_Timer.After(DEBOUNCE, function()
        if token ~= pending[spec.name] then return end
        Flush({ [spec.name] = ToStored(spec, display) }, { [spec.name] = display }, spec.name)
    end)
end

local function Restore()
    local saved = ns.AccountSettings()[BACKUP_KEY]
    local values = type(saved) == "table" and saved.values or nil
    if type(values) ~= "table" then
        status.Restore = TEXT_NOTHING
        Refresh()
        return
    end
    status.Restore = nil
    local updates, expect = {}, {}
    for _, spec in ipairs(SPECS) do
        local stored = values[spec.name]
        if stored ~= nil then
            updates[spec.name] = stored
            expect[spec.name] = stored == false and DefaultDisplay(spec) or ToDisplay(spec, stored)
            shown[spec.name] = expect[spec.name]
        end
    end
    Flush(updates, expect, "Restore")
    Refresh()
end

local function Note(owner)
    return function() return status[owner] end
end

local function ChoiceRow(spec)
    local labels, order = {}, {}
    for index, member in ipairs(spec.members) do
        local value = EnumValue(spec, member)
        if value ~= nil then
            labels[tostring(value)] = spec.names[index]
            order[#order + 1] = tostring(value)
        end
    end
    if #order == 0 then return nil end
    return { label = spec.label, choice = { labels, order }, help = spec.help, note = Note(spec.name),
        get = function() return tostring(Shown(spec)) end,
        set = function(key) Request(spec, tonumber(key)) end }
end

local function Row(spec)
    if spec.enum then return ChoiceRow(spec) end
    if spec.convert == FLAG then
        return { label = spec.label, toggle = true, help = spec.help, note = Note(spec.name),
            get = function() return Shown(spec) == true end,
            set = function(on) Request(spec, on and true or false) end }
    end
    return { label = spec.label, slider = { spec.min, spec.max, spec.step }, unit = spec.unit, help = spec.help,
        frame = spec.frame, note = Note(spec.name),
        get = function() return Shown(spec) end,
        set = function(value) Request(spec, value) end }
end

local rows, rowOf = {}, {}
for _, spec in ipairs(SPECS) do
    local row = Row(spec)
    if row then
        rows[#rows + 1] = row
        rowOf[spec.name] = row
    end
end
local restore = { label = "Restore Game Settings", buttonText = "Restore", button = Restore, note = Note("Restore"),
    help = "Puts the game's own settings back to how they were before your first change since login." }
rows[#rows + 1] = restore

ns.DamageMeterLayout = { rows = rows, byName = rowOf, restore = restore }
