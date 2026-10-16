-- Run with Lua 5.1 from the repository root: Naowh's Forge, the My Macros, Smart Macros and Library
-- tabs of the Macros page, built into stand-ins for the options window's pages against stubs and the
-- game's macros. Every tab is drawn and its controls used: My Macros with Simple's form and Advanced's
-- Build and Simulate, the Smart Macros, the Library that starts empty and fills from the pack and from
-- the player's own, and a share string that round-trips.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, size, text and shown state; Show runs OnShow.
-------------------------------------------------------------------------------
local NOTHING = function() end
local Frame
local frames = {}
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.scripts[script] = fn end,
    GetParent = function(f) return rawget(f, "parent") end,
    SetParent = function(f, parent) f.parent = parent end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 600 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text)
        f.text = text
        if f.scripts.OnTextChanged then f.scripts.OnTextChanged(f, false) end
    end,
    GetText = function(f) return rawget(f, "text") or "" end,
    Insert = function(f, text) f:SetText(f:GetText() .. text) end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 16 end,
    GetFrameLevel = function() return 1 end,
    Show = function(f)
        local was = rawget(f, "shown")
        f.shown = true
        if was == false and f.scripts.OnShow then f.scripts.OnShow(f) end
    end,
    Hide = function(f)
        local was = rawget(f, "shown")
        f.shown = false
        if was ~= false and f.scripts.OnHide then f.scripts.OnHide(f) end
    end,
    SetShown = function(f, shown) if shown then f:Show() else f:Hide() end end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    SetEnabled = function(f, on) f.enabled = on end,
    SetMaxBytes = function(f, n) f.maxBytes = n end,
    SetClipsChildren = function(f, on) f.clips = on end,
    SetCursorPosition = function(f, at) f.cursor = at end,
    GetCursorPosition = function(f) return rawget(f, "cursor") or #(rawget(f, "text") or "") end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    local f = setmetatable({ scripts = {}, parent = parent }, META)
    frames[#frames + 1] = f
    return f
end
local function Click(f, ...) assert(f.scripts.OnClick, "clickable")(f, ...) end

-------------------------------------------------------------------------------
--  The game's macros: account 1-120, character 121-138, sorted by name as the game does.
-------------------------------------------------------------------------------
local MAX_ACCOUNT, MAX_CHARACTER = 120, 18
local store = { account = {}, character = {} }
local menu
local function Sort(list) table.sort(list, function(a, b) return a.name < b.name end) end
local function At(index)
    if index <= MAX_ACCOUNT then return store.account[index], store.account, index end
    return store.character[index - MAX_ACCOUNT], store.character, index - MAX_ACCOUNT
end
local macroAPI = {
    GetNumMacros = function() return #store.account, #store.character end,
    -- As the game does, a question mark macro reports the icon #showtooltip shows.
    GetMacroInfo = function(index)
        local m = At(index)
        if m then return m.name, (m.icon == 134400 and m.body:find("^#showtooltip")) and 135846 or m.icon, m.body end
    end,
    GetMacroSpell = function() return nil end,
    CreateMacro = function(name, icon, body, perCharacter)
        local list = perCharacter and store.character or store.account
        list[#list + 1] = { name = name, icon = icon, body = body }
        Sort(list)
    end,
    EditMacro = function(index, name, icon, body)
        local m, list = At(index)
        m.name, m.icon, m.body = name or m.name, icon or m.icon, body or m.body
        Sort(list)
    end,
    DeleteMacro = function(index)
        local _, list, i = At(index)
        table.remove(list, i)
    end,
    PickupMacro = function() end,
    GetMacroIndexByName = function(name)
        for i, m in ipairs(store.account) do if m.name == name then return i end end
        for i, m in ipairs(store.character) do if m.name == name then return MAX_ACCOUNT + i end end
        return 0
    end,
}

-------------------------------------------------------------------------------
--  The addon around it
-------------------------------------------------------------------------------
local WHITE = { r = 1, g = 1, b = 1 }
local modalPanel
local account, printed, settings, packMacros = {}, {}, {}, {}
local setHooks, applyHooks = {}, {}
local UI = {
    STATUS = { untested = "" },
    CONTENT_PAD = 10,
    Keep = function(parent, key, make)
        local kept = rawget(parent, key)
        if not kept then kept = make(parent); parent[key] = kept end
        return kept
    end,
    RefreshPage = NOTHING,
    CloseOnEscape = NOTHING,
    SlimScroll = function(parent) return Frame(parent) end,
    BuildSliderCore = function(parent)
        local slider = Frame(parent)
        for _, k in ipairs({ "rail", "fill", "thumb", "valueBox", "valueFill" }) do slider[k] = Frame(slider) end
        slider.valueBorder = { _frame = Frame(slider) }
        slider._refreshValue = NOTHING
        return slider
    end,
    BuildToggleControl = function(parent, _, get, set)
        local t = Frame(parent)
        t._get, t._set = get, set
        t._refreshValue = NOTHING
        t.scripts.OnClick = function() set(not get()) end
        return t
    end,
    BuildDropdownControl = function(parent, _, _, _, _, get, set)
        local d = Frame(parent)
        d._get, d._set = get, set
        return d
    end,
    ModuleSettings = function(_, defaults)
        local S = {}
        function S.Get(k) if settings[k] == nil then return defaults[k] end return settings[k] end
        function S.Set(k, v)
            settings[k] = v
            for _, fn in ipairs(setHooks) do fn(k, v) end
        end
        return S
    end,
    Widgets = {
        Note = function() return nil, 20 end, DualRow = function() return nil, 50 end,
        SectionHeader = function() return nil, 30 end, Feature = function() return nil, 30 end,
        Button = function() return nil, 30 end,
    },
}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"),
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    UI = UI,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Border = function(parent) return { SetColor = NOTHING, _frame = Frame(parent) } end,
    AllowOffscreen = NOTHING,
    AccentBorder = function(b) return b end,
    Button = function(parent, text, _, _, onClick)
        local b = Frame(parent)
        b.caption = text
        b.label, b._border, b._rest, b._onClick = Frame(b), { SetColor = NOTHING }, WHITE, onClick
        b.scripts.OnClick = function() if b._onClick then b._onClick() end end
        return b
    end,
    NewEditBox = function(parent)
        local box = Frame(parent)
        box.isName = true
        return box
    end,
    MakeModal = function()
        local dimmer, panel = Frame(), Frame()
        dimmer.shown = false
        modalPanel = panel
        return dimmer, panel
    end,
    NewSearchBox = function(parent)
        local box = Frame(parent)
        box.hint, box.border = Frame(box), { SetColor = NOTHING }
        return box
    end,
    SetButtonText = NOTHING, Tooltip = NOTHING, Hairline = NOTHING, PixelInset = NOTHING,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    AccountSettings = function() return account end,
    Print = function(m) printed[#printed + 1] = m end,
    Confirm = function(text, yes) account.lastConfirm = text; yes() end,
    ShowCopyBox = function(_, text) account.lastCopy = text end,
    StashOptionsWindow = NOTHING, OpenOptionsWindow = NOTHING, Apply = NOTHING,
    DB = function() return { utilityReminders = { classMacros = packMacros } } end,
    HEALTHSTONES = { 5509 }, HEALING_POTIONS = { 13446 }, BestFoodAndDrink = NOTHING,
}
local lastPrompt
local vault = {}
ns.PromptText = function(_, _, _, accept) lastPrompt = accept end
local env = setmetatable({
    NaowhForever = ns,
    UIParent = {},
    GameTooltip = Frame(),
    GameTooltip_Hide = NOTHING,
    CreateFrame = function(kind, _, parent)
        local f = Frame(parent)
        if kind == "EditBox" then f.isBody = true end
        return f
    end,
    CreateColor = function() return { SetRGBA = NOTHING } end,
    hooksecurefunc = function(t, name, fn)
        if type(t) == "table" and name == "Set" then setHooks[#setHooks + 1] = fn end
        if t == ns and name == "Apply" then applyHooks[#applyHooks + 1] = fn end
    end,
    InCombatLockdown = function() return false end,
    MenuUtil = { CreateContextMenu = function(owner, fill)
        menu = { owner = owner, items = {} }
        local root = {}
        function root:CreateTitle(text) menu.items[#menu.items + 1] = { title = text } end
        function root:CreateButton(text, pick) menu.items[#menu.items + 1] = { text = text, pick = pick } end
        function root:SetScrollMode(height) menu.scroll = height end
        fill(owner, root)
    end },
    IsMouseButtonDown = function() return false end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    UnitClass = function() return "Mage", "MAGE", 8 end,
    UnitName = function() return "Glyalith" end,
    IsInRaid = function() return false end,
    IsInGroup = function() return false end,
    LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(_, k) return k end }),
    RAID_CLASS_COLORS = setmetatable({}, { __index = function()
        return { WrapTextInColorCode = function(_, text) return text end }
    end }),
    Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = MAX_ACCOUNT, MAX_CHARACTER_MACROS = MAX_CHARACTER } },
    GetLooseMacroIcons = function(t) t[#t + 1] = 136243 end,
    GetLooseMacroItemIcons = NOTHING,
    GetMacroIcons = function(t) t[#t + 1] = 134400; t[#t + 1] = 135846 end,
    GetMacroItemIcons = NOTHING,
    Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, Flyout = 2 } },
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 2 end,
        GetSpellBookSkillLineInfo = function(line)
            if line == 1 then return { itemIndexOffset = 0, numSpellBookItems = 3 } end
            return { itemIndexOffset = 3, numSpellBookItems = 6 }
        end,
        GetSpellBookItemInfo = function(i)
            local book = {
                { name = "Fireball", iconID = 135812, itemType = 1 },
                { name = "Fireball", iconID = 135812, itemType = 1 },
                { name = "Frost Armor", iconID = 135843, itemType = 1, isPassive = true },
                { name = "Blink", iconID = 135736, itemType = 1 },
                { name = "Fire Blast", iconID = 135807, itemType = 1 },
                { name = "Flamestrike", iconID = 135826, itemType = 1 },
                { name = "Frost Nova", iconID = 135848, itemType = 1 },
                { name = "Polymorph", iconID = 136071, itemType = 1 },
                { name = "Portals", iconID = 1, itemType = 2 },
            }
            return book[i]
        end,
    },
    GetMacroBody = function() return nil end,
    GetInventoryItemID = function() return 19949 end,
    UnitLevel = function() return 60 end,
    NUM_BAG_SLOTS = 0,
    C_Container = { GetContainerNumSlots = function() return 0 end },
    C_Item = { GetItemCount = function(id) return id == 5509 and 1 or 0 end, GetItemIconByID = function() return 133939 end,
        GetItemNameByID = function(id) return "Item " .. id end, GetItemSpell = NOTHING, GetItemInfo = function() return "Item", nil, nil, nil, 0 end },
    C_Spell = { GetSpellName = function(id) return "Spell " .. id end, GetSpellTexture = function() return 135846 end },
    LibStub = function()
        return {
            Serialize = function(_, v) vault[1] = v; return "S" end,
            Deserialize = function() return true, vault[1] end,
            CompressDeflate = function(_, v) return v end, DecompressDeflate = function(_, v) return v end,
            EncodeForPrint = function(_, v) return v end, DecodeForPrint = function(_, v) return v end,
        }
    end,
}, { __index = _G })
for k, v in pairs(macroAPI) do env[k] = v end
env._G = env
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
env.SLASH_NAOWHFOREVER4, env.SLASH_DBM1, env.SLASH_CAST1 = "/nf", "/dbm", "/cast"
env.issecurevariable = function(key) return key ~= "SLASH_DBM1" end

-- The module's files as Macros.xml lists them, all but its settings page (no Shared Settings here).
local MACRO_FILES = {}
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_Utilities/Macros/.*%.lua$")) do
    if not path:find("SettingsPage%.lua$") then MACRO_FILES[#MACRO_FILES + 1] = path end
end
-- Shared as Shared.xml lists it, all but its settings pages and the item data the window never reads.
local SHARED_FILES = { "Core/Features.lua" }
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^Shared/.*%.lua$")) do
    if not (path:find("^Shared/Settings/") or path:find("^Shared/Data/ItemFacts") or path:find("^Shared/Data/FactionItems")) then
        SHARED_FILES[#SHARED_FILES + 1] = path
    end
end
Load(SHARED_FILES, env)
Load(MACRO_FILES, env)
ns.Shared.Decode = dofile("Tools/regression/load_decode.lua")(env, true)

local opened = {}
ns.OpenOptionsWindow = function(key) opened[#opened + 1] = key end

-- The options window: a scroll frame, its scroll child, and one page per tab, shown one at a time.
local scrollFrame = Frame()
local scrollChild = Frame(scrollFrame)
local pages = {}
local function Tab(key)
    for k, page in pairs(pages) do
        if k ~= key then page:Hide() end
    end
    if pages[key] then return pages[key]:Show() end
    pages[key] = Frame(scrollChild)
    ns.BuildForgePage(pages[key], -6, key)
end
local function Shown(test)
    local out = {}
    for _, f in ipairs(frames) do
        if rawget(f, "shown") ~= false and test(f) then out[#out + 1] = f end
    end
    return out
end

-------------------------------------------------------------------------------
--  The Macros page's tabs
-------------------------------------------------------------------------------
store.account[1] = { name = "Hearth", icon = 134400, body = "#showtooltip\n/use Hearthstone" }
store.character[1] = { name = "Sheep", icon = 134400, body = "#showtooltip Polymorph\n/cast [@focus,harm][] Polymorph" }

ns.OpenMacroWindow("smart")
check("/nfmacros and its callers open the options window on a Macros tab", opened[1] == "Macros/Smart Macros")
Tab("mine")
local window = ns.Macros.Forge.window
check("My Macros is built into the options window's page, no window of its own",
    window and window.parent == pages.mine and rawget(window, "positionKey") == nil)
check("the subtitle names the character and meters the slots", window.subtitle:GetText() == "Glyalith, MAGE"
    and window.meters[1].label:GetText() == "Account 1/120" and window.meters[2].label:GetText() == "MAGE 1/18")
check("it shows My Macros", window.mine:IsShown() and not window.smartView:IsShown() and not window.libView:IsShown())
Tab("smart")
check("the Smart Macros tab moves it to its own page", window.parent == pages.smart and window.smartView:IsShown()
    and not window.mine:IsShown())
Tab("mine")
check("back on My Macros, the built page takes it back", window.parent == pages.mine and window.mine:IsShown())

-------------------------------------------------------------------------------
--  My Macros: Simple
-------------------------------------------------------------------------------
local editor = window.editor
local simple = editor.simple
local function Rows()
    return Shown(function(f) return rawget(f, "macro") ~= nil and rawget(f, "dot") ~= nil end)
end
local function Row(name)
    for _, r in ipairs(Rows()) do
        if r.macro.name == name then return r end
    end
end
local function Body() return ns.Macros.Forge.draft.body end
local function Cards(view)
    local out = {}
    for i = 1, view.cards.used do out[i] = view.cards.list[i] end
    return out
end
local function PickItem(text)
    for _, item in ipairs(menu.items) do
        if item.text == text then return item.pick() end
    end
    error("no menu item " .. text)
end
local function Says() return simple.press.text.text end

check("Simple is the default: the form shows, the code box and the side panel do not",
    simple:IsShown() and not editor.codeBox:IsShown() and not window.inspectorArea:IsShown()
    and ns.Macros.Settings.Get("forgeMode") == "simple")
check("the list shows the account's and this character's macros", Row("Hearth") and Row("Sheep"))
check("a new macro waits in the editor", editor.saveLabel.text == "Create" and Body():find("^#showtooltip"))
check("a new macro is a form: cast a spell at your target", simple.spell:IsShown() and simple.aim.bar.shown == "target"
    and simple.fall.bar.shown == "none" and Says() == "Type the spell or item it casts.")
check("aiming at your target with nothing else asks no friend or enemy question", not simple.kind:IsShown())

local box = simple.spell.box
box:SetText("Flash Heal")
box.scripts.OnEditFocusLost(box)
check("the spell box writes a plain cast", Body() == "#showtooltip\n/cast Flash Heal"
    and Says() == "Casts Flash Heal on your target.")
simple.aim.bar.onPick("mouseover")
check("Mouseover aims it, your target if there is none",
    Body() == "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead] Flash Heal"
    and simple.kind:IsShown() and simple.fall.bar.shown == "target"
    and Says() == "Casts Flash Heal on your mouseover. No living friend there: on your target instead.")
check("the fallback question names the mouseover", simple.fall.label.text == "If there is no mouseover")
simple.fall.bar.onPick("player")
simple.self.bar.onPick("alt")
check("yourself as the fallback, and Alt for yourself",
    Body() == "#showtooltip\n/cast [mod:alt,@player][@mouseover,help,nodead][@player] Flash Heal"
    and Says():find("Hold Alt: on yourself.", 1, true))
simple.kind.bar.onPick("enemy")
check("Enemies swaps the checks",
    Body() == "#showtooltip\n/cast [mod:alt,@player][@mouseover,harm,nodead][@player] Flash Heal")
Click(simple.toggles[1].toggle)
Click(simple.toggles[2].toggle)
Click(simple.toggles[3].toggle)
check("the switches add /stopcasting and /startattack and take #showtooltip off",
    Body() == "/stopcasting\n/startattack\n/cast [mod:alt,@player][@mouseover,harm,nodead][@player] Flash Heal"
    and Says():find("^Stops your cast first%.") and Says():find("Starts attacking too%.$"))
simple.aim.bar.onPick("player")
check("Myself needs no fallback or key", Body() == "/stopcasting\n/startattack\n/cast [@player] Flash Heal"
    and not simple.fall:IsShown() and not simple.self:IsShown() and Says():find("on yourself.", 1, true))
check("the text it writes is under the form", simple.code.text.text == ns.Macros.Text.Colorize(Body()))
Click(editor.undo)
check("Undo takes back a pick",
    Body() == "/stopcasting\n/startattack\n/cast [mod:alt,@player][@mouseover,harm,nodead][@player] Flash Heal")

ns.Macros.Forge.SetBody("#showtooltip\n/use [@focus,harm,nodead][harm,nodead] Linen Bandage", true)
check("a macro in the same shape reads back into the form", simple.aim.bar.shown == "focus"
    and simple.kind.bar.shown == "enemy" and simple.fall.bar.shown == "target"
    and simple.spell.box:GetText() == "Linen Bandage" and Says():find("^Uses Linen Bandage on your focus%."))

Click(Row("Sheep"))
check("a macro Simple cannot show says so, with the way to Advanced", window.name:GetText() == "Sheep"
    and simple.tooBig:IsShown() and simple.advanced:IsShown() and not simple.spell:IsShown())
Click(simple.advanced)
check("Edit in Advanced switches to Advanced", settings.forgeMode == "advanced" and editor.codeBox:IsShown()
    and not simple:IsShown() and window.inspectorArea:IsShown())

-------------------------------------------------------------------------------
--  My Macros: Advanced, its Build and Simulate panels
-------------------------------------------------------------------------------
local builder = Shown(function(f) return rawget(f, "recipeButtons") ~= nil end)[1]
local forgeCards = Cards(builder)
check("Build opens it: one card per line", #forgeCards == 2)
check("the #showtooltip line is the Button shows card",
    forgeCards[1].shows:IsShown() and forgeCards[1].shows:GetText() == "Polymorph")
local cast = forgeCards[2]
local first, second = cast.clauses.list[1], cast.clauses.list[2]
check("the /cast line reads as two choices, each with its unit and spell", cast.clauses.used == 2
    and first.lead.text == "If" and second.lead.text == "Otherwise" and first.arg:GetText() == "Polymorph"
    and second.arg:GetText() == "Polymorph")
check("its condition is a chip", first.chips.used == 1 and first.chips.list[1].label.text == "hostile")

Click(first.when)
PickItem("Alt")
check("+ when adds a condition to the line", Body() == "#showtooltip Polymorph\n/cast [@focus,harm,mod:alt][] Polymorph")
check("and undo has it", editor.undo.enabled)
cast = Cards(builder)[2]
first = cast.clauses.list[1]
Click(first.chips.list[2])
check("the chip's x takes it out again", Body() == "#showtooltip Polymorph\n/cast [@focus,harm][] Polymorph")

cast = Cards(builder)[2]
Click(cast.clauses.list[2].unit)
PickItem("yourself")
check("the unit menu aims a choice", Body() == "#showtooltip Polymorph\n/cast [@focus,harm][@player] Polymorph")

cast = Cards(builder)[2]
box = cast.clauses.list[1].arg
box:SetText("Frost Nova")
box.scripts.OnEditFocusLost(box)
check("the spell box writes the spell when you leave it",
    Body() == "#showtooltip Polymorph\n/cast [@focus,harm] Frost Nova; [@player] Polymorph")
Click(editor.undo)
cast = Cards(builder)[2]
box = cast.clauses.list[1].arg
box.scripts.OnEditFocusGained(box)
box:SetText("bli")
box.scripts.OnTextChanged(box, true)
Click(ns.Macros.Forge.spellPopup.rows[1])
check("a /cast line's spell box offers spells and writes the pick into the line",
    Body() == "#showtooltip Polymorph\n/cast [@focus,harm] Blink; [@player] Polymorph")
Click(editor.undo)
check("Undo puts the line back", Body() == "#showtooltip Polymorph\n/cast [@focus,harm][@player] Polymorph")

local inspector = window.inspector
inspector.tabs.onPick("sim")
local tester = Shown(function(f) return rawget(f, "answerText") ~= nil and rawget(f, "questions") ~= nil end)[1]
local asked = {}
for i = 1, tester.questions.used do asked[#asked + 1] = tester.questions.list[i].label.text end
check("Simulate asks only what the macro depends on", #asked == 1 and asked[1] == "Who is your focus?")
check("with no focus it falls through to you", tester.answerText.text:find("1. Cast Polymorph on yourself", 1, true))
tester.questions.list[1].bar.onPick("enemy")
check("an enemy focus takes the first choice", tester.answerText.text:find("1. Cast Polymorph on your focus", 1, true))
inspector.tabs.onPick("build")

Click(editor.saveButton)
check("Save writes the game macro", store.character[1].body == "#showtooltip Polymorph\n/cast [@focus,harm][@player] Polymorph"
    and printed[#printed]:find("Saved Sheep", 1, true))

Click(window.list.new)
check("New Macro starts a fresh draft", window.name:GetText() == "New Macro" and editor.saveLabel.text == "Create")
local spellBox = builder.spell
spellBox.scripts.OnEditFocusGained(spellBox)
local popup = ns.Macros.Forge.spellPopup
local function Offered()
    local out = {}
    for _, row in ipairs(popup.rows) do
        if row:IsShown() then out[#out + 1] = row.text.text end
    end
    return table.concat(out, ", ")
end
check("the recipe's spell box offers the spells you know, once each, no passives or flyouts",
    popup:IsShown() and Offered() == "Blink, Fire Blast, Fireball, Flamestrike, Frost Nova, Polymorph")
spellBox:SetText("f")
spellBox.scripts.OnTextChanged(spellBox, true)
check("typing narrows them, starting with what you typed",
    Offered() == "Fire Blast, Fireball, Flamestrike, Frost Nova")
spellBox:SetText("bla")
spellBox.scripts.OnTextChanged(spellBox, true)
check("a word inside a name still finds it", Offered() == "Fire Blast")
spellBox:SetText("fr")
spellBox.scripts.OnTextChanged(spellBox, true)
spellBox.scripts.OnArrowPressed(spellBox, "DOWN")
spellBox.scripts.OnEnterPressed(spellBox)
check("Enter takes the lit one", spellBox:GetText() == "Frost Nova" and not popup:IsShown())
spellBox.scripts.OnEditFocusGained(spellBox)
spellBox:SetText("pol")
spellBox.scripts.OnTextChanged(spellBox, true)
Click(popup.rows[1])
check("a click takes it too", spellBox:GetText() == "Polymorph" and not popup:IsShown())
builder.spell:SetText("Flash Heal")
Click(builder.recipeButtons[1])
check("a recipe writes the macro around the spell",
    Body() == "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] Flash Heal")
check("its recipe says mouseover", builder.recipeButtons[1].title.text == "Heal my mouseover")
window.name:SetText("MO Heal")
window.name.scripts.OnTextChanged(window.name, true)
Click(editor.saveButton)
check("Create makes it a character macro", #store.character == 2 and store.character[1].name == "MO Heal")

ns.Macros.Forge.SetBody("/cats Fireball", true)
local issue = builder.issues.list[1]
check("a typo shows as a problem with a fix", builder.issues.used >= 1 and issue.text.text:find("/cats", 1, true)
    and issue.fix:IsShown())
Click(issue.fix)
check("Fix it corrects the line", Body() == "/cast Fireball")
Click(builder.lineButtons[3])
check("Add a line appends it", Body() == "/cast Fireball\n/stopcasting")
Click(builder.lineButtons[5])
check("Show on button goes on top", Body() == "#showtooltip\n/cast Fireball\n/stopcasting")

check("the code box holds the text, colored", window.code:GetText():find("|c", 1, true) ~= nil
    and ns.Macros.Text.Strip(window.code:GetText()) == Body())
inspector.tabs.onPick("reads")
local said = {}
for _, f in ipairs(Shown(function(f) return rawget(f, "number") ~= nil and rawget(f, "box") ~= nil end)) do
    said[#said + 1] = f.text.text
end
check("Reads as says each line in words", #said == 3 and said[2] == "Cast Fireball.")
inspector.tabs.onPick("build")
window.mode.onPick("simple")
check("back to Simple", simple:IsShown() and not window.inspectorArea:IsShown())

Click(Row("Sheep"))
Click(editor.iconButton)
local picker = ns.Macros.Forge.picker
local icons = {}
for _, b in ipairs(picker.buttons) do if b:IsShown() then icons[#icons + 1] = b end end
check("the icon opens a picker of the game's macro icons", picker:IsShown() and #icons == 3)
Click(icons[3], "LeftButton")
check("picking one sets it on the saved macro", store.character[2].icon == icons[3].fileID and not picker:IsShown())

Click(editor.deleteButton)
check("Delete asks, then removes the macro", account.lastConfirm:find("Delete Sheep", 1, true)
    and #store.character == 1 and store.character[1].name == "MO Heal")
store.account = { { name = "Hearth", icon = 134400, body = "#showtooltip\n/use Hearthstone" } }
store.character = { { name = "Sheep", icon = 134400, body = "#showtooltip Polymorph\n/cast [@focus,harm][] Polymorph" } }
Tab("smart")

-------------------------------------------------------------------------------
--  Smart Macros and Library
-------------------------------------------------------------------------------
local cards = Shown(function(f) return rawget(f, "key") ~= nil and rawget(f, "uses") ~= nil end)
check("one card per Smart Macro", #cards == 11)
local health
for _, c in ipairs(cards) do if c.key == "health" then health = c end end
check("the health card says what it will use", health.uses[1].text.text == "Item 5509")
Click(health.toggle)
check("its switch turns the macro off, on by default", settings.health == false)

local function LibCards() return Shown(function(f) return rawget(f, "add") ~= nil end) end
local function LibCard(name)
    for _, c in ipairs(LibCards()) do
        if c.title.text == name then return c end
    end
end

Tab("lib")
check("the Library starts empty, with nothing but the class name", not window.lib.lead:IsShown()
    and #LibCards() == 0)
packMacros.MAGE = { { name = "Naowh Sheep", body = "#showtooltip Polymorph\n/cast Polymorph", note = "Naowh's" } }
Tab("smart")
Tab("lib")
local libCards = LibCards()
check("the pack's macros fill it", #libCards == 1 and window.lib.lead:IsShown())
check("a card has no editor button", rawget(libCards[1], "open") == nil)
Click(libCards[1].add)
check("Add makes a character macro", #store.character == 2 and store.character[1].name == "Naowh Sheep")
check("and says where to find it", printed[#printed]:find("/macro", 1, true)
    and not printed[#printed]:find("My Macros", 1, true))

local importButton, exportAllButton, newButton
for _, f in ipairs(frames) do
    local caption = rawget(f, "caption")
    if f.parent == window then
        if caption == "Import" then importButton = f elseif caption == "Export" then exportAllButton = f
        elseif caption == "New Macro" then newButton = f end
    end
end
check("the top bar has Import and Export, no New Macro", importButton and exportAllButton and not newButton)

-------------------------------------------------------------------------------
--  Import and Export
-------------------------------------------------------------------------------
Click(exportAllButton)
Click(importButton)
lastPrompt(account.lastCopy)
check("a macro whose name you already have is not imported again", #store.character == 2
    and printed[#printed]:find("Added 0 of 3: 3 use a name you already have", 1, true))
store.character[1].name = "Bsheep"
Click(importButton)
lastPrompt(account.lastCopy)
check("a share string imports as character macros", #store.character == 3)
lastPrompt("not a string")
check("anything else is turned away", printed[#printed]:find("not a Naowh Forever macro string", 1, true))

-- Any number, as many as fit; a script in any case is called out.
store.account = {}
local twenty = {}
for i = 1, 20 do twenty[i] = { name = "M" .. i, body = "/cast Spell " .. i } end
vault[1] = { v = 1, macros = twenty }
Click(importButton)
lastPrompt("!NFM1!S")
check("all 20 are read, as many added as fit", #store.character == 18
    and printed[#printed]:find("Added 15 of 20", 1, true))
store.character = {}
for _, body in ipairs({ "/RUN print(1)", "/dump GetTime()" }) do
    vault[1] = { v = 1, macros = { { name = "X", body = body } } }
    Click(importButton)
    lastPrompt("!NFM1!S")
    check("a script is called out: " .. body, account.lastConfirm:find("runs a script", 1, true))
end
vault[1] = { v = 1, macros = { { name = "A", body = "/nf bars delete Raid\n/DBM pull 10" },
    { name = "B", body = "#showtooltip\n/foo bar\n/nf" }, { name = "C", body = "/cast Polymorph" } } }
Click(importButton)
lastPrompt("!NFM1!S")
check("addon and unknown commands are called out, by name", account.lastConfirm:find(" Some use Naowh Forever's own"
    .. " commands (/nf), use other addons' commands (/dbm) and use commands the game does not know (/foo): read them"
    .. " in /macro before you use them.", 1, true))
vault[1] = { v = 1, macros = { { name = "A", body = "/run x()\n/nf scrap" } } }
Click(importButton)
lastPrompt("!NFM1!S")
check("a script and our own command in one macro", account.lastConfirm:find(" One runs a script and uses Naowh"
    .. " Forever's own commands (/nf): read it in /macro before you use it.", 1, true))
vault[1] = { v = 1, macros = { { name = "A", body = "/cast Polymorph\n/1 hello" } } }
Click(importButton)
lastPrompt("!NFM1!S")
check("the game's own commands need no warning", account.lastConfirm:find("macros?", 1, true)
    and not account.lastConfirm:find("read", 1, true))

-- A name that is only stripped characters is turned away.
store.character = {}
vault[1] = { v = 1, macros = { { name = "|", body = "/cast X" } } }
Click(importButton)
lastPrompt("!NFM1!S")
check("an import name stripped to nothing is turned away", #store.character == 0
    and printed[#printed]:find("not a Naowh Forever macro string", 1, true))

-- Nothing to export.
store.account, store.character = {}, {}
account.lastCopy = nil
Click(exportAllButton)
check("with no macros, Export says so", account.lastCopy == nil and printed[#printed]:find("no macros to export", 1, true))

-- Export everything: an empty macro still imports, the Smart Macros stay home.
store.account = { { name = "NF Health", icon = 134400, body = "/use item:5509" },
    { name = "Blank", icon = 134400, body = "" } }
store.character = { { name = "Mine", icon = 134400, body = "/cast Blink" } }
Click(exportAllButton)
local exported = vault[1].macros
check("Export leaves the Smart Macros out", #exported == 2 and exported[1].name == "Blank"
    and exported[2].name == "Mine")
store.account, store.character = {}, {}
Click(importButton)
lastPrompt(account.lastCopy)
check("an export with an empty macro imports whole", #store.character == 2
    and printed[#printed]:find("Added 2.", 1, true))

-------------------------------------------------------------------------------
--  Library Add: the pack's checks
-------------------------------------------------------------------------------
store.character = {}
packMacros.MAGE = {
    { name = "Scripted", body = "/run print(1)\n/cast Polymorph" },
    { name = "A name far too long", body = "/cast Frostbolt" },
    { name = "Plain", body = "/cast Frost Nova" },
}
account.lastConfirm = nil
Tab("smart")
Tab("lib")
Click(LibCard("Scripted").add)
check("a pack script needs the player's yes", (account.lastConfirm or ""):find("runs a script from a shared pack", 1, true))
Click(LibCard("A name far too long").add)
check("a name the game cannot hold is turned away", printed[#printed]:find("not a macro the game can hold", 1, true)
    and #store.character == 1)
Tab("lib")
Click(LibCard("Plain").add)
Tab("lib")
Click(LibCard("Plain").add)
check("adding it twice makes one macro", #store.character == 2 and printed[#printed]:find("already", 1, true))

-- A pack import refreshes the Library.
packMacros.MAGE = {}
Tab("lib")
packMacros.MAGE = { { name = "Iconic", body = "/cast Blink", icon = 135736 } }
for _, fn in ipairs(applyHooks) do fn() end
check("a pack import fills the open Library", LibCard("Iconic") ~= nil and window.lib.lead:IsShown())

-- Pack macros keep the pack's icon.
store.character = {}
Click(LibCard("Iconic").add)
check("Add makes it with the pack's icon", store.character[1] and store.character[1].icon == 135736)

-- A name already in use is not taken twice.
store.character = { { name = "Iconic", icon = 134400, body = "/cast Something Else" } }
packMacros.MAGE = { { name = "Iconic", body = "/cast Blink", icon = 135736 } }
Tab("lib")
Click(LibCard("Iconic").add)
check("Library Add will not take a name in use", #store.character == 1
    and printed[#printed]:find("different macro called Iconic", 1, true))

-------------------------------------------------------------------------------
--  Your own Library
-------------------------------------------------------------------------------
store.account, store.character = {}, {}
packMacros.MAGE = { { name = "Pack One", body = "/cast Arcane Missiles" } }
account.libraryMacros = { MAGE = { { name = "My Blink", body = "/cast Blink" },
    { name = "My Script", body = "/run print(1)" }, { name = "Pack Run", body = "/run print(2)", pack = true } } }
Tab("smart")
Tab("lib")
local mine, packed = LibCard("My Blink"), LibCard("Pack One")
check("yours shows in the Library beside the pack's", mine and mine.tag.text == "YOURS" and mine.remove:IsShown()
    and packed and packed.tag.text:find("NAOWH", 1, true) and not packed.remove:IsShown())

account.lastConfirm = nil
Click(LibCard("My Script").add)
check("your own script is added without a warning", account.lastConfirm == nil
    and store.character[1] and store.character[1].name == "My Script")
Click(LibCard("Pack Run").add)
check("a script copied from the pack still asks first",
    (account.lastConfirm or ""):find("runs a script from a shared pack", 1, true))

Click(LibCard("My Blink").remove)
check("Remove takes it out of the Library", #account.libraryMacros.MAGE == 2 and LibCard("My Blink") == nil
    and LibCard("My Script") ~= nil)

-------------------------------------------------------------------------------
--  Save a Macro: the picker
-------------------------------------------------------------------------------
store.account = { { name = "Ice Lance", icon = 135846, body = "/cast Ice Lance" } }
store.character = { { name = "Blink Now", icon = 134400, body = "/cast Blink" },
    { name = "Too Long", icon = 134400, body = ("x"):rep(256) } }
account.libraryMacros = { MAGE = {} }
Tab("lib")
check("the Library has a Save a Macro button on your own class", window.lib.save:IsShown())
Click(window.lib.save)
local texts = {}
for _, item in ipairs(menu.items) do texts[#texts + 1] = item.title or item.text end
check("the picker lists the account's macros, then this character's, scrolling",
    menu.owner == window.lib.save and menu.scroll
    and table.concat(texts, "|") == "Account macros|Ice Lance|This character's macros|Blink Now|Too Long")
local function Pick(name)
    for _, item in ipairs(menu.items) do if item.text == name then item.pick() end end
end
Pick("Ice Lance")
check("picking one saves it under your class, with its icon",
    #account.libraryMacros.MAGE == 1 and account.libraryMacros.MAGE[1].name == "Ice Lance"
    and account.libraryMacros.MAGE[1].body == "/cast Ice Lance" and account.libraryMacros.MAGE[1].icon == 135846)
check("and it shows in the Library as yours", LibCard("Ice Lance") and LibCard("Ice Lance").tag.text == "YOURS")
Pick("Blink Now")
check("a question mark icon is not kept, so it keeps following its spell",
    account.libraryMacros.MAGE[2].name == "Blink Now" and account.libraryMacros.MAGE[2].icon == nil)
account.lastConfirm = nil
Click(window.lib.save)
Pick("Ice Lance")
check("saving the same name with the same text updates it without asking", account.lastConfirm == nil
    and #account.libraryMacros.MAGE == 2)
store.account[1].body = "/cast Ice Lance Rank 2"
Click(window.lib.save)
Pick("Ice Lance")
check("with other text it asks before replacing, then updates it", #account.libraryMacros.MAGE == 2
    and (account.lastConfirm or ""):find("already in your Library with other text", 1, true)
    and account.libraryMacros.MAGE[1].body == "/cast Ice Lance Rank 2")
Click(window.lib.save)
Pick("Too Long")
check("a macro the game cannot hold is refused", #account.libraryMacros.MAGE == 2)
store.account, store.character = {}, {}
Click(window.lib.save)
check("with no game macros the picker says so", #menu.items == 1 and menu.items[1].title == "You have no game macros to save.")
local priest = Shown(function(f) return rawget(f, "class") == "PRIEST" end)[1]
Click(priest)
check("the button is only for your own class: not on another's page", priest and not window.lib.save:IsShown())

-------------------------------------------------------------------------------
--  New Macro: write one
-------------------------------------------------------------------------------
store.account, store.character = {}, {}
account.libraryMacros = { MAGE = {} }
Tab("smart")
Tab("lib")
Click(Shown(function(f) return rawget(f, "class") == "MAGE" end)[1])
check("the Library has a New Macro button beside Save a Macro, on your own class", window.lib.new:IsShown())
Click(window.lib.new)
local function Under(f, root)
    while f do
        if f == root then return true end
        f = rawget(f, "parent")
    end
end
local function Named(test) return Shown(function(f) return Under(f, modalPanel) and test(f) end)[1] end
local nameBox = Named(function(f) return rawget(f, "isName") end)
local bodyBox = Named(function(f) return rawget(f, "isBody") end)
local saveButton = Named(function(f) return rawget(f, "caption") == "Save to Library" end)
local addButton = Named(function(f) return rawget(f, "caption") == "Save and Add" end)
local cancelButton = Named(function(f) return rawget(f, "caption") == "Cancel" end)
check("it opens a dialog with its name and text empty and the three buttons",
    nameBox and bodyBox and saveButton and addButton and cancelButton and nameBox:GetText() == ""
    and bodyBox:GetText() == "")
check("the dialog holds a name of 16 bytes and a macro of 255", nameBox.maxBytes == 17 and bodyBox.maxBytes == 256)
bodyBox:SetText("#showtooltip\n/cast Frostbolt")
local meter = Named(function(f) return type(rawget(f, "text")) == "string" and f.text:find("bytes", 1, true) end)
check("the byte meter counts the text against 255", meter.text == "28 / 255 bytes")

nameBox:SetText("")
Click(saveButton)
check("a macro with no name is refused and the dialog stays", #account.libraryMacros.MAGE == 0)
nameBox:SetText("A name that is far too long")
Click(saveButton)
check("so is a name over 16 bytes", #account.libraryMacros.MAGE == 0)
nameBox:SetText("  Frost Combo  ")
Click(saveButton)
check("Save to Library keeps it under your class, trimmed, and adds no character macro",
    #account.libraryMacros.MAGE == 1 and account.libraryMacros.MAGE[1].name == "Frost Combo"
    and account.libraryMacros.MAGE[1].body == "#showtooltip\n/cast Frostbolt" and #store.character == 0)
check("and it shows in the Library as yours", LibCard("Frost Combo") and LibCard("Frost Combo").tag.text == "YOURS")

Click(window.lib.new)
check("opened again it starts empty", nameBox:GetText() == "" and bodyBox:GetText() == "")
nameBox:SetText("Blink Pair")
bodyBox:SetText("/cast Blink")
Click(addButton)
check("Save and Add also makes it this character's macro",
    #account.libraryMacros.MAGE == 2 and #store.character == 1 and store.character[1].name == "Blink Pair"
    and store.character[1].body == "/cast Blink")

Click(window.lib.new)
nameBox:SetText("Unsaved")
bodyBox:SetText("/cast Fireball")
Click(cancelButton)
check("Cancel keeps nothing", #account.libraryMacros.MAGE == 2)
local scroller = bodyBox.parent
local at = 0
scroller.GetVerticalScroll = function() return at end
scroller.SetVerticalScroll = function(_, v) at = v end
scroller.GetHeight = function() return 160 end
bodyBox.scripts.OnCursorChanged(bodyBox, 0, -200, 2, 14)
check("the text box scrolls down to keep the cursor in view", at == 54)
bodyBox.scripts.OnCursorChanged(bodyBox, 0, -10, 2, 14)
check("and back up", at == 10)
local priestRow = Shown(function(f) return rawget(f, "class") == "PRIEST" end)[1]
Click(priestRow)
check("New Macro is only on your own class's page", not window.lib.new:IsShown())

print(("test-macro-window: %d checks passed"):format(checks))
