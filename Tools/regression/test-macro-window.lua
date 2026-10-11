-- Run with Lua 5.1 from the repository root: Naowh's Forge, the Macros module's window, built
-- on the Shared kit and opened against stubs and a stand-in for the game's macros. Both tabs are
-- drawn and their controls used: the Smart Macros, the Library that starts empty and fills from
-- the pack and from the player's own, and a share string that round-trips.
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
    GetMacroBody = function() return nil end,
    GetInventoryItemID = function() return 19949 end,
    NUM_BAG_SLOTS = 0,
    C_Container = { GetContainerNumSlots = function() return 0 end },
    C_Item = { GetItemCount = function(id) return id == 5509 and 1 or 0 end, GetItemIconByID = function() return 133939 end,
        GetItemNameByID = function(id) return "Item " .. id end, GetItemSpell = NOTHING, GetItemInfo = NOTHING },
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
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_Macros/.*%.lua$")) do
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

local function Window()
    for _, f in ipairs(frames) do
        if rawget(f, "positionKey") == "macroWindow" then return f end
    end
end
local function Shown(test)
    local out = {}
    for _, f in ipairs(frames) do
        if rawget(f, "shown") ~= false and test(f) then out[#out + 1] = f end
    end
    return out
end

-------------------------------------------------------------------------------
--  The window and its two tabs
-------------------------------------------------------------------------------
store.account[1] = { name = "Hearth", icon = 134400, body = "#showtooltip\n/use Hearthstone" }
store.character[1] = { name = "Sheep", icon = 134400, body = "#showtooltip Polymorph\n/cast [@focus,harm][] Polymorph" }

ns.OpenMacroWindow()
local window = Window()
check("Naowh's Forge is built by the kit", window and window.backdrop and window.switch)
check("its title is Naowh's Forge", window.title:GetText() == "Naowh's Forge")
check("the subtitle names the character and meters the slots", window.subtitle:GetText() == "Glyalith, MAGE"
    and window.meters[1].label:GetText() == "Account 1/120" and window.meters[2].label:GetText() == "MAGE 1/18")
local tabs = {}
for _, f in ipairs(frames) do
    if f.parent == window.switch and rawget(f, "key") then tabs[#tabs + 1] = f.key end
end
check("the window has Smart Macros and Library, nothing else", #tabs == 2 and tabs[1] == "smart" and tabs[2] == "lib")
check("it opens on Smart Macros", window.switch.shown == "smart" and window.smartView:IsShown()
    and not window.libView:IsShown())

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

window.switch.onPick("lib")
check("the Library starts empty, with nothing but the class name", not window.lib.lead:IsShown()
    and #LibCards() == 0)
packMacros.MAGE = { { name = "Naowh Sheep", body = "#showtooltip Polymorph\n/cast Polymorph", note = "Naowh's" } }
window.switch.onPick("smart")
window.switch.onPick("lib")
local libCards = LibCards()
check("the pack's macros fill it", #libCards == 1 and window.lib.lead:IsShown())
check("a card has no editor button", rawget(libCards[1], "open") == nil)
Click(libCards[1].add)
check("Add makes a character macro", #store.character == 2 and store.character[1].name == "Naowh Sheep")
check("and says where to find it", printed[#printed]:find("/macro", 1, true)
    and not printed[#printed]:find("My Macros", 1, true))

local importButton, exportAllButton, newButton
for _, f in ipairs(frames) do
    local tip = rawget(f, "tip")
    if tip == "Import" then importButton = f elseif tip == "Export" then exportAllButton = f
    elseif tip == "New Macro" then newButton = f end
end
check("the bar has Import and Export, no New Macro", importButton and exportAllButton and not newButton)

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
window.switch.onPick("smart")
window.switch.onPick("lib")
Click(LibCard("Scripted").add)
check("a pack script needs the player's yes", (account.lastConfirm or ""):find("runs a script from a shared pack", 1, true))
Click(LibCard("A name far too long").add)
check("a name the game cannot hold is turned away", printed[#printed]:find("not a macro the game can hold", 1, true)
    and #store.character == 1)
window.switch.onPick("lib")
Click(LibCard("Plain").add)
window.switch.onPick("lib")
Click(LibCard("Plain").add)
check("adding it twice makes one macro", #store.character == 2 and printed[#printed]:find("already", 1, true))

-- A pack import refreshes the Library.
packMacros.MAGE = {}
window.switch.onPick("lib")
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
window.switch.onPick("lib")
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
window.switch.onPick("smart")
window.switch.onPick("lib")
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
window.switch.onPick("lib")
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
window.switch.onPick("smart")
window.switch.onPick("lib")
Click(Shown(function(f) return rawget(f, "class") == "MAGE" end)[1])
check("the Library has a New Macro button beside Save a Macro, on your own class", window.lib.new:IsShown())
Click(window.lib.new)
local function Named(test) return Shown(function(f) return test(f) end)[1] end
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
