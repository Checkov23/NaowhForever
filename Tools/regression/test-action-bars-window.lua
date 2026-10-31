-- Run with Lua 5.1 from the repository root: the Action Bars page's Bar Sets tab and its three views
-- (home, the set builder and the import preview) built into a stand-in for the options window's page
-- and drawn from the real files against stubs.
-- Checks the home's cards and set rows, the paste and export popups, the scene's strip for each
-- class (Bar 3 | Bar 2 over Bar 1 | Bar 4, form chips, the pet bar's keys), toggling a bar by its
-- label, skipping a slot, the summary, saving, and the preview's strip and Import.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, size, text and shown state; every other method is one
--  shared do-nothing function.
-------------------------------------------------------------------------------
local NOTHING = function() end
local WHITE = { r = 1, g = 1, b = 1 }
local Frame
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.hooks[script] = fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterEvent = function(f, event) f.events[event] = nil end,
    GetParent = function(f) return rawget(f, "parent") end,
    SetParent = function(f, parent) f.parent = parent end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 300 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text) f.text = text end,
    SetPoint = function(f, point, x, y) if point == "TOPLEFT" and type(x) == "number" then f.y = y end end,
    GetText = function(f) return rawget(f, "text") or "" end,
    SetTexture = function(f, texture) f.texture = texture end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    Show = function(f) f.shown = true; if f.scripts.OnShow then f.scripts.OnShow(f) end end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f)
        while f do
            if rawget(f, "shown") == false then return false end
            f = rawget(f, "parent")
        end
        return true
    end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    SetDesaturated = function(f, on) f.desaturated = on end,
    GetFrameLevel = function() return 1 end,
    GetEffectiveScale = function() return 1 end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    return setmetatable({ scripts = {}, hooks = {}, events = {}, parent = parent }, META)
end

-------------------------------------------------------------------------------
--  The game: a priest who knows Smite, with bars, macros and keys
-------------------------------------------------------------------------------
local state = { account = {}, printed = {}, timers = {}, bars = {}, macros = {}, binds = {}, frames = {} }
local SPELLS = { [585] = "Smite", [2054] = "Heal" }
local known = { [585] = true }

local function Values(defaults)
    local db, heard = {}, {}
    return {
        Get = function(k) if db[k] == nil then return defaults[k] end return db[k] end,
        Set = function(k, v)
            db[k] = v
            for i = 1, #heard do heard[i](k, v) end
        end,
        OnChange = function(fn) heard[#heard + 1] = fn end,
        Toggle = NOTHING,
    }
end

local rowParents = setmetatable({}, { __mode = "k" })
local ns
ns = {
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    UI = {
        ModuleSettings = function(_, defaults) return Values(defaults) end,
        SlimScroll = function(parent) return Frame(parent) end,
        CloseOnEscape = NOTHING, RefreshPage = NOTHING, CONTENT_PAD = 20,
        -- Kept frames per parent and key, hidden at the start of each draw, as the real kit.
        BeginReusableRows = function(parent)
            local kept = rowParents[parent] or {}
            rowParents[parent] = kept
            kept.uses = {}
            for key, list in pairs(kept) do
                if key ~= "uses" then for _, el in ipairs(list) do el:Hide() end end
            end
        end,
        Keep = function(parent, key, create)
            local kept = rowParents[parent]
            if not kept then return create(parent) end
            local i = (kept.uses[key] or 0) + 1
            kept.uses[key] = i
            kept[key] = kept[key] or {}
            local el = kept[key][i] or create(parent)
            kept[key][i] = el
            el:Show()
            return el
        end,
        KeepFont = function(parent, key)
            local fs = Frame(parent)
            state.keptFonts[key] = fs
            return fs
        end,
        KeepButton = function(parent, key, text, _, _, onClick)
            local button = Frame(parent)
            button.label, button.onClick, button.key = text, onClick, key
            state.rowButtons[text] = button
            return button
        end,
        BuildDropdownControl = function(parent, _, _, values, order, get, set)
            local picker = Frame(parent)
            picker.values, picker.order, picker.get, picker.set = values, order, get, set
            picker._refreshValue = NOTHING
            state.pickers[#state.pickers + 1] = picker
            return picker
        end,
        BuildToggleControl = function(parent, _, get, set)
            local toggle = Frame(parent)
            state.toggles[#state.toggles + 1] = toggle
            -- The real switch reads its value when it is made.
            toggle._get, toggle._set, toggle._refreshValue = get, set, function() get() end
            toggle._refreshValue()
            toggle.scripts.OnClick = function() set(not get()) end
            return toggle
        end,
        BuildSliderCore = function(parent, _, _, _, _, _, _, _, _, _, _, get, set)
            local slider = Frame(parent)
            slider.rail, slider.fill, slider.thumb = Frame(slider), Frame(slider), Frame(slider)
            slider.valueBox, slider.valueFill = Frame(parent), Frame(parent)
            slider.valueBorder = { _frame = Frame(parent) }
            slider._get, slider._set, slider._refreshValue = get, set, NOTHING
            return slider, slider.valueBox
        end,
        Widgets = {
            SectionHeader = function() return nil, 20 end,
            Note = function() return nil, 20 end,
        },
    },
    AccountSettings = function() return state.account end,
    Print = function(text) state.printed[#state.printed + 1] = text end,
    Color = function(_, text) return text end,
    L = function(text) return text end,
    Font = function(parent)
        local fs = Frame(parent)
        state.fonts[#state.fonts + 1] = fs
        return fs
    end,
    Solid = function(parent) return Frame(parent) end,
    Hairline = function(region) return region end,
    AllowOffscreen = function() end,
    Border = function(parent)
        local edge = Frame(parent)
        edge.SetColor = function(self, r) self.red = r end
        edge._frame = edge
        return edge
    end,
    Button = function(parent, text, _, _, onClick)
        local button = Frame(parent)
        button.label, button._onClick = text, onClick
        button.onClick = function() if button._onClick then button._onClick() end end
        state.buttons[text] = button
        return button
    end,
    AccentBorder = function(frame) return frame end,
    SetButtonText = function(button, text) button.label = text end,
    NewEditBox = function(parent)
        state.editBox = Frame(parent)
        return state.editBox
    end,
    UIScale = function() return 1 end,
    UIFontPath = function() return "font" end,
    Apply = NOTHING,
    Confirm = function(text, yes) state.confirmed = text; yes() end,
    PromptText = NOTHING,
    Upper = string.upper,
    PrimaryButton = function(button) button.primary = true; return button end,
    MakeModal = function()
        local dimmer, panel = Frame(), Frame()
        ns.UI.BeginReusableRows(panel)
        state.modal = { dimmer = dimmer, panel = panel }
        return dimmer, panel
    end,
}
state.buttons, state.rowButtons, state.toggles, state.fonts = {}, {}, {}, {}
state.keptFonts, state.pickers = {}, {}
state.class, state.className = "PRIEST", "Priest"

local function ActionInfo(slot)
    local a = state.bars[slot]
    if a then return a.kind, a.id, a.subType end
end

local env = setmetatable({
    _G = { NaowhForever = ns },
    Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } },
    Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } },
    C_GamepadUI = {
        GetFirstGamepadActionStorageSlotIndex = function() return 181 end,
        IsValidGamepadActionStorageSlotIndex = function() return false end,
    },
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
        GetSpellBookItemInfo = function() return { name = "Smite", subName = "Rank 1", actionID = 585,
            itemType = 1, isPassive = false } end,
    },
    C_Spell = {
        GetSpellName = function(id) return SPELLS[id] end,
        GetSpellTexture = function() return 135924 end,
        GetSpellLevelLearned = function() return 30 end,
        GetSpellSubtext = function() return "Rank 1" end,
        PickupSpell = function(id) if known[id] then state.cursor = { kind = "spell", id = id } end end,
    },
    C_Item = { GetItemIconByID = function() return 134400 end, GetItemNameByID = function() return "Item" end,
        PickupItem = function(id) state.cursor = { kind = "item", id = id } end },
    C_ActionBar = { GetActionText = function(slot) return state.bars[slot] and state.bars[slot].name end },
    C_EquipmentSet = { GetEquipmentSetID = NOTHING, PickupEquipmentSet = NOTHING },
    C_KeyBindings = { GetBindingContextForAction = function() return 1 end },
    C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
    Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
    MenuUtil = { CreateContextMenu = function(_, build)
        state.menu = {}
        build(nil, { CreateButton = function(_, text, fn) state.menu[text] = fn end,
            CreateTitle = NOTHING, CreateDivider = NOTHING })
    end },
    GameTooltip = Frame(), GameTooltip_Hide = NOTHING,
    GetActionInfo = ActionInfo,
    GetActionTexture = function(slot) return state.bars[slot] and 135924 end,
    GetCursorInfo = function() return state.cursor and state.cursor.kind end,
    ClearCursor = function() state.cursor = nil end,
    PlaceAction = function(slot) state.bars[slot], state.cursor = state.cursor, state.bars[slot] end,
    PickupAction = function(slot) state.cursor, state.bars[slot] = state.bars[slot], nil end,
    GetNumMacros = function() return #state.macros, 0 end,
    GetMacroInfo = function(i) local m = state.macros[i]; if m then return m.name, m.icon, m.body end end,
    GetMacroIndexByName = function(name)
        for i, m in ipairs(state.macros) do if m.name == name then return i end end
        return 0
    end,
    CreateMacro = function(name, icon, body)
        state.macros[#state.macros + 1] = { name = name, icon = icon, body = body }
        return #state.macros
    end,
    PickupMacro = function(i) state.cursor = { kind = "macro", id = 0, name = state.macros[i].name } end,
    GetNumBindings = function() return #state.binds end,
    GetBinding = function(i) local b = state.binds[i]; return b[1], "", b[2] end,
    GetBindingKey = function(command)
        for _, b in ipairs(state.binds) do if b[1] == command then return b[2] end end
    end,
    GetBindingText = function(key) return key end,
    GetBindingAction = function(key)
        for _, b in ipairs(state.binds) do if b[2] == key then return b[1] end end
        return ""
    end,
    SetBinding = function() return true end,
    SaveBindings = NOTHING, GetCurrentBindingSet = function() return 1 end,
    InCombatLockdown = function() return false end,
    UnitClass = function() return state.className, state.class end,
    GetPetActionInfo = function(i)
        local pet = state.pet and state.pet[i]
        if pet then return pet[1], pet[2], pet[3] end
    end,
    UnitName = function() return "Alt" end,
    UnitGUID = function() return "Player-1" end,
    GetNumShapeshiftForms = function() return #(state.stances or {}) end,
    GetShapeshiftFormInfo = function(i) return 136000 + i, false, true, state.stances[i] end,
    RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 } },
    UnitLevel = function() return 20 end,
    GetRealmName = function() return "Realm" end,
    CreateFrame = function(_, _, parent)
        local frame = Frame(parent)
        state.frames[#state.frames + 1] = frame
        return frame
    end,
    CreateColor = function() return Frame() end,
    UIParent = Frame(),
    hooksecurefunc = function(t, key, fn)
        local original = t[key]
        t[key] = function(...) original(...); fn(...) end
    end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    time = os.time, date = os.date,
    print = function(text) state.printed[#state.printed + 1] = text end,
}, { __index = _G })
env._G.NaowhForever = ns

Load({ "Shared/Shared.lua", "Shared/Style.lua", "Shared/Decode.lua", "Shared/Encode.lua", "Shared/Game/ActionKeys.lua", "Shared/UI/Parts.lua", "Shared/UI/Marks.lua", "Shared/UI/Text.lua", "Shared/UI/Hud.lua", "Shared/UI/Timer.lua", "Shared/UI/Share.lua", "Shared/UI/CodeModal.lua", "Shared/UI/Panels.lua", "Shared/UI/Window.lua", "Shared/UI/Tabs.lua", "Shared/UI/SettingsCard.lua",
    }, env)
local MODULE = { "Core/Features.lua" }
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_Utilities/ActionBars/.*%.lua$")) do
    if not path:find("SettingsPage%.lua$") then MODULE[#MODULE + 1] = path end
end
Load(MODULE, env)

local function RunTimers()
    local timers = state.timers
    state.timers = {}
    for _, fn in ipairs(timers) do fn() end
end

local function Visible(frame)
    while frame do
        if not frame:IsShown() then return false end
        frame = frame:GetParent()
    end
    return true
end

-------------------------------------------------------------------------------
--  Finding things on screen
-------------------------------------------------------------------------------
local DOT = ns.Shared.Style.PLACE_DOT

local function Scene()
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "grid") and rawget(frame, "labels") and Visible(frame) then return frame end
    end
end
local function Tile(region, i) return Scene().tiles[region][i] end
local function Label(region)
    local label = Scene().labels[region]
    return Visible(label) and label.text.text or nil
end
local function Click(frame)
    local fn = frame.scripts.OnClick
    if fn then fn(frame) elseif rawget(frame, "onClick") then frame.onClick() end
end
local function Chips()
    local texts = {}
    for _, chip in ipairs(Scene().chips) do
        if Visible(chip) then texts[#texts + 1] = chip.text.text .. " " .. chip.count end
    end
    return table.concat(texts, ", ")
end
local function Chip(text)
    for _, chip in ipairs(Scene().chips) do
        if Visible(chip) and chip.text.text:find(text, 1, true) == 1 then return chip end
    end
end
local function Summary()
    local out = {}
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "number") and rawget(frame, "unit") and Visible(frame) then
            out[#out + 1] = frame.number.text .. " " .. frame.unit.text
        end
    end
    return table.concat(out, DOT)
end
local function Steps()
    local on = {}
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "step") and Visible(frame) then on[frame.step] = frame.line.shown ~= false end
    end
    return on
end
local function BackLink()
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "underline") and Visible(frame) then return frame end
    end
end
local function SetRow(name)
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "extras") and frame.key == name and Visible(frame) then return frame end
    end
end
local function Picker()
    for _, picker in ipairs(state.pickers) do
        if Visible(picker) then return picker end
    end
end
local function Panel(title)
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "title") and rawget(frame, "line") and frame.title.text == title and Visible(frame) then
            return frame
        end
    end
end

-------------------------------------------------------------------------------
--  Home, the builder and the preview for a priest
-------------------------------------------------------------------------------
state.bars = { [1] = { kind = "spell", id = 585 }, [2] = { kind = "spell", id = 2054 },
    [3] = { kind = "macro", id = 0, name = "Pull" } }
state.macros = { { name = "Pull", icon = 1, body = "/say pull" }, { name = "Dance", icon = 2, body = "/dance" } }
state.binds = { { "ACTIONBUTTON1", "1" }, { "ACTIONBUTTON2", "2" } }
known[2054] = true

local opened = {}
ns.OpenOptionsWindow = function(key) opened[#opened + 1] = key end
ns.OpenActionBarsWindow()
check("/nfbars and its callers open the options window on the Bar Sets tab", opened[1] == "Action Bars/Bar Sets")

-- The options window: a scroll frame, its scroll child, and the tab's page.
local scrollFrame = Frame()
local page = Frame(Frame(scrollFrame))
ns.BuildActionBarsTab(page, -6)
local function Under(frame, parent)
    while frame do
        if frame == parent then return true end
        frame = frame:GetParent()
    end
    return false
end
local save = state.buttons["+ Save Current Bars"]
check("the tab is built into the options window's page, no window of its own", Under(save, page) and Visible(save))
local previewImport = state.buttons.Import
local editBox = state.editBox
check("home has Save Current Bars as the primary button over it", save.primary)
check("and Paste Code and Get Code beside it", state.buttons["Paste Code"] and state.buttons["Get Code"]
    and not rawget(state.buttons["Paste Code"], "primary"))
local function Pill()
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "edge") and rawget(frame, "text") and type(frame.text.text) == "string"
            and frame.text.text:find(" SET", 1, true) and Visible(frame) then return frame.text.text end
    end
end
check("the title is Bar Sets, with the class and how many sets beside it", Pill() == "PRIEST" .. DOT .. "0 SETS")
local newCard
for _, frame in ipairs(state.frames) do if rawget(frame, "plus") and Visible(frame) then newCard = frame end end
check("a card offers to save the bars as a new set", newCard and newCard.text.text == "Save your bars as a new set")

Click(state.buttons["Paste Code"])
check("Import Website Code opens the paste popup", state.keptFonts.title.text == "Paste a code from naowh.gg"
    and state.rowButtons.Import.primary and state.rowButtons.Cancel)

Click(save)
check("the builder draws the strip: Bar 3 | Bar 2 over Bar 1 | Bar 4", Label("left") == "ACTION BAR 3"
    and Label("top") == "ACTION BAR 2" and Label("right") == "ACTION BAR 4"
    and Label("bottom") == "ACTION BAR 1" .. DOT .. "MAIN")
check("a priest has no form chips and no pet bar", Chips() == "" and not Visible(Scene().pet))
check("a slot with an action shows its icon and key", Tile("bottom", 1).icon.texture == 135924
    and Tile("bottom", 1).key.text == "1")
check("an empty button is shown empty", Visible(Tile("left", 1)) and Tile("left", 1).icon.shown == false)
check("the summary counts actions, keybinds and macros", Summary() == "3 actions" .. DOT .. "2 keybinds" .. DOT .. "2 macros")
check("What Goes In sits in a scroll sized to its rows, so a short tab scrolls it instead of cutting it", Panel("Keybinds"):GetParent().h == 4 * 52)
check("keybinds and macros head the macro list", Panel("Keybinds") and Panel("Macros")
    and Panel("Keybinds").line.text == "All 2 come along: 2 on your bars, 0 for other commands.")
check("there is no step strip", not Steps()[1] and not Steps()[2] and not Steps()[3])
Click(Tile("bottom", 2))
check("a click on a button skips just that slot: dimmed, with its mark", Tile("bottom", 2).icon.desaturated == true
    and Tile("bottom", 2).mark.shown and Tile("bottom", 1).icon.desaturated == false and Summary():find("^2 actions"))

check("the builder has a name box", editBox and editBox.scripts.OnEnterPressed)
editBox:SetText("Raid")
check("Save Set is the primary button", state.buttons["Save Set"].primary)
local function FontShown(text)
    for _, fs in ipairs(state.fonts) do
        if rawget(fs, "text") == text and Visible(fs) then return fs end
    end
end
check("the summary bar says what is left out", FontShown("1 slot left out") ~= nil)
local function ListTab(key)
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "buttons") and Visible(frame) then
            for _, button in ipairs(frame.buttons) do if button.key == key then return button end end
        end
    end
end
Click(ListTab("keys"))
local bound = {}
for _, frame in ipairs(state.frames) do
    if rawget(frame, "keyText") and Visible(frame) then bound[#bound + 1] = frame.keyText.text .. " " .. frame.what.text end
end
table.sort(bound)
check("the Keybinds tab lists each key with what it presses", bound[1] == "1 Smite" and bound[2] == "2 Heal")
Click(ListTab("macros"))
Click(FontShown("Select None"):GetParent())
check("Select None leaves out every macro but the ones on the bars", Summary():find("1 macro$") ~= nil)
Click(FontShown("Select All"):GetParent())
check("and Select All puts them back", Summary():find("2 macros$") ~= nil)
state.buttons["Save Set"].onClick()
local set = state.account.barSets.PRIEST.Raid
check("Save Set saves under the typed name", set)
check("with the slot left out", set.slots[1] and not set.slots[2] and set.choices.skip[2])
check("and every macro, keys too", #set.macros == 2 and set.bindings and set.bindings["1"] == "ACTIONBUTTON1")

local row = SetRow("Raid")
check("home lists the set as a row", row and row.name.text == "Raid" and row.has.text == "2 actions, 2 macros, 2 keybinds")
check("with a small strip of the saved set", row.strip.cells.bottom[1].texture == 135924
    and row.strip.cells.bottom[3].texture == 1 and row.strip.cells.bottom[2].empty and row.strip.cells.left[1].empty)
check("and nothing more to tag for a priest", row.extras.text == "")
check("Import is primary, More is not", row.import.primary and not rawget(row.more, "primary"))
Click(row.more)
check("More has Export to Website", state.menu["Export to Website"] and state.menu["Edit and Save Again"])
state.menu["Export to Website"]()
check("which shows the set's code to copy", state.keptFonts.title.text == "Export to Website"
    and state.editBox.text:find("^!NFA1!") and state.editBox.scripts.OnTextChanged)
check("and what went in and was left out", state.keptFonts.summary.text:find("In the code: 1 action", 1, true)
    and state.keptFonts.summary.text:find("Training Planner", 1, true))
state.editBox.scripts.OnTextChanged(state.editBox, true)
check("the code box cannot be typed over", state.editBox.text:find("^!NFA1!"))
ns.TrainingData = { [5] = { { 1, 585, 10 }, { 16, 2054, 100 } } }
Click(state.buttons["Get Code"])
local exported = select(2, ns.ActionBars.Sharing.Decode(state.editBox.text))
check("Export to Website exports the bars as they are", exported and exported.slots[1].id == 585
    and exported.slots[2].id == 2054 and exported.slots[3].name == "Pull")

-- The same set on an alt that knows only Smite, has no macros and other things on its bars.
known[2054] = nil
state.macros = {}
state.bars = { [2] = { kind = "item", id = 6948 }, [7] = { kind = "spell", id = 585 } }
state.binds = { { "ACTIONBUTTON2", "1" } }
Click(row.import)
check("the row's Import opens the preview on the same strip", Label("bottom") == "ACTION BAR 1" .. DOT .. "MAIN")
check("a macro the import makes is marked NEW", Tile("bottom", 3).badge.text.text == "NEW")
check("a slot left out shows the alt's own action", Tile("bottom", 2).icon.texture == 135924
    and Tile("bottom", 2).icon.desaturated)
local function With(field, other)
    local out = {}
    for _, frame in ipairs(state.frames) do
        if rawget(frame, field) and (not other or rawget(frame, other)) and Visible(frame) then out[#out + 1] = frame end
    end
    return out
end
local function Tiles()
    local out = {}
    for _, tile in ipairs(With("number", "label")) do out[#out + 1] = tile.number.text .. " " .. tile.label.text end
    return table.concat(out, "|")
end
local function Bring(name)
    for _, choice in ipairs(With("box", "count")) do
        if choice.name.text == name then return choice end
    end
end
local function Note(text)
    for _, frame in ipairs(With("note", "rows")) do
        if frame.note.shown ~= false and frame.note.text == text then return frame end
    end
end
check("tiles count what the import changes", Tiles()
    == "3 slots change|2 added to empty buttons|1 cleared|0 fill in as you learn|2 macros made, 0 already here")
check("Bring Across lists actions, macros and keybinds with what the set holds", Bring("Actions").count.text == 2
    and Bring("Macros").count.text == 2 and Bring("Keybinds").count.text == 2)
check("Import is primary", previewImport.primary)
check("the strip's caption says nothing changes yet", Scene().caption.text == "Nothing changes until you press Import.")
check("a slot that fills an empty button is edged green, one taken off is crossed in red",
    Tile("bottom", 1).edge.red == ns.ActionBars.Style.GREEN_RGB.r and Tile("bottom", 7).mark.shown
    and Tile("bottom", 7).edge.red == ns.ActionBars.Style.RED_RGB.r)
check("Import names how many changes it makes", previewImport.label == "Import 3 changes")
local keyLines = {}
for _, line in ipairs(With("key", "text")) do
    if type(line.key) == "table" then keyLines[#keyLines + 1] = line.key.text .. " " .. line.text.text end
end
table.sort(keyLines)
check("the keys that change are listed with what they did and will do",
    keyLines[1] == "1 Item  ->  Smite" and keyLines[2] == "2 nothing  ->  Item")
Click(Bring("Keybinds"))
check("leaving keybinds out of this import says the keys stay", Note("Off: your keys stay as they are.")
    and not Bring("Keybinds").box.tick.shown)
Click(Bring("Keybinds"))
local modes = With("buttons", "onPick")[1]
for _, button in ipairs(modes.buttons) do if button.key == "now" then Click(button) end end
check("Your bars now shows the bars as they are, the slot the import clears edged red",
    Tile("bottom", 7).icon.texture == 135924 and Tile("bottom", 7).edge.red == ns.ActionBars.Style.RED_RGB.r
    and not Tile("bottom", 7).mark.shown)
for _, button in ipairs(modes.buttons) do if button.key == "after" then Click(button) end end
check("nothing changed yet", state.bars[2].kind == "item" and #state.macros == 0)
previewImport.onClick()
check("Import imports", state.bars[1].id == 585 and state.bars[3].kind == "macro" and #state.macros == 2)
check("and leaves the left-out slot alone", state.bars[2].kind == "item")
check("and clears a slot the set keeps empty", state.bars[7] == nil)
RunTimers()
check("and goes back home, the set listed", SetRow("Raid"))

local function Shown(field)
    for _, frame in ipairs(state.frames) do
        if rawget(frame, field) and Visible(frame) then return frame end
    end
end
local function AllShown(field)
    local out = {}
    for _, frame in ipairs(state.frames) do
        if rawget(frame, field) and Visible(frame) then out[#out + 1] = frame end
    end
    return out
end

local banner = Shown("undo")
check("home offers Undo for the import just made", banner
    and banner.text.text == "Raid is on your bars. Your bars from before it are kept as a backup.")
check("and marks the set as on your bars", SetRow("Raid").on.shown ~= false
    and SetRow("Raid").on.text.text == "ON YOUR BARS")
check("the backup taken first is listed", #AllShown("restore") == 1 and Shown("restore").why.text == "Before importing Raid")
Click(banner.undo)
RunTimers()
check("Undo puts the alt's own bars back", state.bars[2].kind == "item" and state.bars[7].id == 585 and state.bars[1] == nil)
check("and the banner goes", not Shown("undo"))
check("putting a backup back is itself backed up", #AllShown("restore") == 2)

state.bars = { [1] = { kind = "macro", id = 585, subType = "spell", name = "Gone" } }
RunTimers()
ns.UI.RefreshPage()
RunTimers()
check("the spell a macro shows is on the bars, though no macro is found by its name", not Shown("icons"))
state.macros = { { name = "Holy", icon = 1, body = "#showtooltip\n/cast smite" } }
state.bars = { [1] = { kind = "macro", id = 0, name = "Holy" } }
RunTimers()
ns.UI.RefreshPage()
RunTimers()
check("a spell named in a macro on the bars counts in any letter case", not Shown("icons"))

state.bars = {}
RunTimers()
ns.UI.RefreshPage()
RunTimers()
local spells = Shown("icons")
check("a spell this priest knows and has on no bar is offered to drag", spells
    and spells.title.text == "1 spell you know is on no bar" and spells.icons[1].spell == 585)
Click(spells.first)
RunTimers()
check("Hide These stops listing it", not Shown("icons"))

ns.PromptText = function(_, _, _, accept) accept("Dungeon") end
ns.OpenActionBarsBuilder("Raid")
Click(state.buttons["+ Tag"])
local tagChip
for _, frame in ipairs(AllShown("index")) do if not rawget(frame, "scene") then tagChip = frame end end
check("+ Tag adds a tag to the set being built", tagChip and tagChip.text.text == "DUNGEON  x")
state.bars = { [1] = { kind = "spell", id = 585 } }
local iconButton
for _, frame in ipairs(AllShown("texture")) do
    if not rawget(frame, "spell") and frame.scripts.OnClick then iconButton = frame end
end
Click(iconButton)
local picked
for _, frame in ipairs(AllShown("texture")) do if frame.texture == 135924 and frame ~= iconButton then picked = frame end end
Click(picked)
state.binds = { { "ACTIONBUTTON1", "1" } }
state.buttons["Save Set"].onClick()
RunTimers()
check("an icon picked from the bars is saved with the set", state.account.barSets.PRIEST.Raid.icon == 135924)
check("the tag is saved with the set and shown on its card", state.account.barSets.PRIEST.Raid.tags[1] == "Dungeon"
    and SetRow("Raid").tags[1].text.text == "DUNGEON")
local filters = AllShown("edge")
local dungeonFilter
for _, chip in ipairs(filters) do
    if rawget(chip, "text") and chip.text.text == "Dungeon" and rawget(chip, "onClick") then dungeonFilter = chip end
end
check("a tag gets a filter over the saved sets", dungeonFilter ~= nil)
Click(dungeonFilter)
RunTimers()
check("which shows only the sets with that tag", SetRow("Raid") ~= nil)

state.binds = { { "ACTIONBUTTON2", "1" } }
ns.OpenActionBarsKeys("Raid")
local caps = {}
for _, frame in ipairs(AllShown("full")) do caps[frame.full] = frame end
check("the keybind map shows each key with the action it presses", caps["1"] and caps["1"].what == "Smite"
    and caps["1"].icon.texture == 135924)
check("a key that does something else here now is ringed", caps["1"].changed == true and caps["2"].changed == false)
check("free keys near WASD are listed", Shown("head") ~= nil)

ns.ActionBarsMenu(Frame())
check("the launcher's quick menu loads a set, and names the one on your bars", state.menu["Raid (on your bars)"]
    and state.menu["Open Bar Sets"] and state.menu["Save Bars into Raid"])

-- More > Edit and Save Again opens the builder on the set, its picks in place.
ns.OpenActionBarsBuilder("Raid")
check("editing a set keeps its name", editBox.text == "Raid")
check("and its left-out slot", Tile("bottom", 2).icon.desaturated == true)

-------------------------------------------------------------------------------
--  Each class's strip
-------------------------------------------------------------------------------
local KEYS = state.toggles[1]

state.class, state.className = "ROGUE", "Rogue"
state.bars = { [1] = { kind = "spell", id = 585 }, [2] = { kind = "spell", id = 2054 },
    [73] = { kind = "spell", id = 585 }, [61] = { kind = "spell", id = 2054 }, [40] = { kind = "spell", id = 585 } }
state.macros = { { name = "Pull", icon = 1, body = "/say pull" }, { name = "Dance", icon = 2, body = "/dance" } }
state.binds = { { "ACTIONBUTTON1", "1" }, { "ACTIONBUTTON2", "2" } }
state.stances = { 1784 }
ns.OpenActionBarsBuilder()
check("a rogue has Main and Stealth chips with their counts", Chips() == "MAIN 2, STEALTH 1")
check("over the strip, under STANCE BAR, as on the website", Visible(Scene().forms)
    and Scene().forms.head.text.text == "STANCE BAR")
check("Main is a word, Stealth is its spell's icon", Chip("MAIN").text.shown ~= false and Chip("MAIN").icon.shown == false
    and Chip("STEALTH").icon.shown ~= false and Chip("STEALTH").icon.texture == 135924 and Chip("STEALTH").text.shown == false)
check("Bar 1's row shows the main page", Tile("bottom", 1).slot == 1 and Label("bottom") == "ACTION BAR 1" .. DOT .. "MAIN")
check("Bar 2 is the top row of the middle", Tile("top", 1).slot == 61 and Tile("top", 1).icon.texture == 135924)
check("the summary counts every page", Summary() == "5 actions" .. DOT .. "2 keybinds" .. DOT .. "2 macros")
Click(Chip("STEALTH"))
check("the Stealth chip swaps Bar 1's row to the Stealth page", Tile("bottom", 1).slot == 73
    and Label("bottom") == "ACTION BAR 1" .. DOT .. "STEALTH")
check("with Bar 1's keys", Tile("bottom", 1).key.text == "1")
Click(Tile("bottom", 1))
check("a click there skips the Stealth slot only", Tile("bottom", 1).icon.desaturated == true
    and Chips() == "MAIN 2, STEALTH 0" and Summary():find("^4 actions"))
Click(Scene().labels.top)
check("a click on Bar 2's label leaves the whole bar out, and dims it", Label("top") == "ACTION BAR 2" .. DOT .. "LEFT OUT"
    and Tile("top", 1).alpha < 1 and Summary():find("^3 actions"))
Click(Scene().labels.top)
check("and a second click puts it back", Label("top") == "ACTION BAR 2" and Summary():find("^4 actions"))
Click(Scene().labels.top)
local picker = Picker()
check("other bars are picked from the list, with their counts", picker.values[0] == "Main bars"
    and picker.values[4] == "Action Bar 5 (1)" and not picker.values[7])
local mainHeight = Scene().h
picker.set(4)
check("picking one shows that bar on its own", Label("top") == "ACTION BAR 5" and Tile("top", 4).slot == 40
    and not Visible(Tile("left", 1)) and Chips() == "")
check("and the scene keeps the stance bar's height, so nothing under it moves", Scene().h == mainHeight
    and not Visible(Scene().forms))
picker.set(0)
editBox:SetText("Rogue")
state.buttons["Save Set"].onClick()
set = state.account.barSets.ROGUE.Rogue
check("the saved set leaves those slots out", set.slots[1] and set.slots[73] == nil and set.choices.skip[73]
    and set.slots[61] == nil and set.choices.skip[72] and set.slots[40])
row = SetRow("Rogue")
check("its home row draws the strip from the saved set, and tags the bar off the strip", row
    and row.strip.cells.bottom[1].texture == 135924 and row.strip.cells.top[1].empty and row.extras.text == "+ 1 more bar")
ns.OpenActionBarsBuilder()
editBox:SetText("Stealthy")
state.buttons["Save Set"].onClick()
check("a set with a Stealth page is tagged with it", SetRow("Stealthy").extras.text == "+ Stealth" .. DOT .. "+ 1 more bar")

state.class, state.className = "DRUID", "Druid"
state.bars = { [1] = { kind = "spell", id = 585 }, [73] = { kind = "spell", id = 585 },
    [85] = { kind = "spell", id = 585 }, [97] = { kind = "spell", id = 585 }, [109] = { kind = "spell", id = 585 } }
state.stances = { 5487, 1066, 768, 783, 24858 }
state.binds = { { "ACTIONBUTTON1", "1" }, { "SHAPESHIFTBUTTON3", "F3" } }
ns.OpenActionBarsBuilder()
check("a druid has a chip for each form, in stance bar order", Chips() == "MAIN 1, BEAR 1, CAT 1, PROWL 1, MOONKIN 1")
check("under FORMS", Scene().forms.head.text.text == "FORMS")
check("each form chip shows its stance bar key, Prowl is a word", Chip("CAT").key.text == "F3"
    and Chip("BEAR").key.text == "" and Chip("PROWL").icon.shown == false)
Click(Chip("BEAR"))
check("the Bear chip shows the Bear page with the main bar's keys", Tile("bottom", 1).slot == 97
    and Tile("bottom", 1).key.text == "1" and Label("bottom") == "ACTION BAR 1" .. DOT .. "BEAR")
editBox:SetText("Druid")
state.buttons["Save Set"].onClick()
check("a druid's row counts its forms", SetRow("Druid").extras.text == "+ 4 forms")
state.binds = { { "ACTIONBUTTON1", "1" }, { "SHAPESHIFTBUTTON3", "F5" } }
ns.OpenActionBarsImport("Druid")
check("the preview's form chips show the keys the set binds, not the ones bound now", Chip("CAT").key.text == "F3")

state.class, state.className = "WARRIOR", "Warrior"
state.stances = { 2457, 71 }
state.bars = { [73] = { kind = "spell", id = 585 }, [85] = { kind = "spell", id = 585 } }
ns.OpenActionBarsBuilder()
check("a warrior is always in a stance: no Main, Battle Stance first", Chips()
    == "BATTLE STANCE 1, DEFENSIVE STANCE 1, BERSERKER STANCE 0"
    and Label("bottom") == "ACTION BAR 1" .. DOT .. "BATTLE STANCE" and Tile("bottom", 1).slot == 73)
state.bars[1] = { kind = "spell", id = 585 }
ns.OpenActionBarsBuilder()
check("but Main comes back when its page has actions", Chips():find("^MAIN 1, ") ~= nil)
state.class, state.className = "DRUID", "Druid"
state.binds = { { "ACTIONBUTTON1", "1" }, { "SHAPESHIFTBUTTON1", "F1" } }
ns.OpenActionBarsBuilder()
check("a druid's form keys count as keys on the bars",
    Panel("Keybinds").line.text == "All 2 come along: 2 on your bars, 0 for other commands.")

state.class, state.className = "HUNTER", "Hunter"
state.bars = { [1] = { kind = "spell", id = 585 } }
state.binds = { { "ACTIONBUTTON1", "1" }, { "BONUSACTIONBUTTON1", "CTRL-1" }, { "BONUSACTIONBUTTON2", "CTRL-2" } }
state.pet = { { "Attack", "PET_ATTACK_TEXTURE", true } }
ns.OpenActionBarsBuilder()
local pet = Scene().pet
check("a hunter's What Goes In has room for the pet bar's row", Panel("Keybinds"):GetParent().h == 5 * 52)
check("a hunter sees the pet bar's row above the strip", Visible(pet) and pet.label.text.text == "PET BAR" and Chips() == "")
check("its ten buttons show keys only", #pet.tiles == 10 and pet.tiles[1].key.text == "CTRL-1"
    and pet.tiles[10].key.text == "" and pet.tiles[1].icon.shown == false)
check("its keys count in the summary", Summary() == "1 action" .. DOT .. "3 keybinds" .. DOT .. "2 macros")
check("as keys for other commands", Panel("Keybinds").line.text == "All 3 come along: 3 on your bars, 0 for other commands.")
editBox:SetText("Pets")
state.buttons["Save Set"].onClick()
check("a hunter's row tags the pet bar's keys", SetRow("Pets").extras.text == "+ pet keys")
ns.OpenActionBarsBuilder()
pet = Scene().pet
Click(pet.tiles[1])
check("a pet button is not a slot to skip", not pet.tiles[1].mark.shown)
Click(pet.label)
check("its label leaves the pet bar's keys out", pet.label.text.text == "PET BAR" .. DOT .. "LEFT OUT"
    and Summary():find(DOT .. "1 keybind" .. DOT, 1, true))
editBox:SetText("Hunter")
state.buttons["Save Set"].onClick()
set = state.account.barSets.HUNTER.Hunter
check("so the set keeps the bar keys only", set.bindings["1"] == "ACTIONBUTTON1" and set.bindings["CTRL-1"] == nil
    and set.choices.petOff == true)
ns.OpenActionBarsBuilder("Hunter")
Click(Scene().pet.label)
Click(KEYS)
check("keybinds off leaves the pet bar out and drops keys from the summary",
    Scene().pet.label.text.text:find("LEFT OUT") and Summary() == "1 action" .. DOT .. "2 macros")
Click(Scene().pet.label)
check("and its label cannot put it back then", Scene().pet.label.text.text:find("LEFT OUT"))
Click(KEYS)
ns.OpenActionBarsImport("Hunter")
check("the preview shows the pet bar's row too, left out as saved", Visible(Scene().pet)
    and Scene().pet.label.text.text == "PET BAR" .. DOT .. "LEFT OUT" and Scene().pet.tiles[1].key.text == "CTRL-1")
check("bars that already match change nothing", Tiles():find("^0 slots change") ~= nil and previewImport.label == "Import")
local tile = With("number", "label")[1]
local view = tile:GetParent()
view.scripts.OnSizeChanged(view, 1100)
check("its five tiles and three panels share the tab's width", tile.w == 212 and With("note", "rows")[1].w == 360)

state.class, state.className = "MAGE", "Mage"
state.bars = {}
state.binds = {}
ns.OpenActionBarsBuilder()
check("a mage has no chips and no pet bar, and empty bars show empty buttons", Chips() == ""
    and not Visible(Scene().pet) and Visible(Tile("bottom", 12)) and Tile("bottom", 12).icon.shown == false)
local back = BackLink()
check("the builder links back to the saved sets", back and back.text.text == "Saved Sets")
Click(back)
check("which it opens", Visible(save) and not BackLink())

print(checks .. " action bar window checks passed")
