-- Run with Lua 5.1 from the repository root: the Training Planner's window, built on the
-- Shared kit, opened and drawn against stubs. Every tab and view is drawn and every control
-- in it clicked once, so a missing field or a bad call fails here instead of in game.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, size, text and shown state; Show runs OnShow; every
--  other method does nothing.
-------------------------------------------------------------------------------
local NOTHING = function() end
local Frame
local frames = {}
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn)
        local old = f.scripts[script]
        f.scripts[script] = old and function(...) old(...); fn(...) end or fn
    end,
    GetParent = function(f) return rawget(f, "parent") end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 600 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    GetLeft = function() return 100 end,
    GetTop = function() return 900 end,
    GetPoint = function() return "TOPLEFT", nil, "BOTTOMLEFT", 100, 900 end,
    Show = function(f)
        local was = rawget(f, "shown")
        f.shown = true
        if was == false and f.scripts.OnShow then f.scripts.OnShow(f) end
    end,
    Hide = function(f)
        local was = rawget(f, "shown") ~= false
        f.shown = false
        if was and f.scripts.OnHide then f.scripts.OnHide(f) end
    end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
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

local function Click(f, button)
    assert(f.scripts.OnClick, "clickable")(f, button or "LeftButton")
end

local WHITE = { r = 1, g = 1, b = 1 }
local account, printed, waypoint = {}, {}, nil
local settings = {}
local listeners = {}
local UI = {
    CONTENT_PAD = 10,
    STATUS = { untested = "" },
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
    ModuleSettings = function(_, defaults)
        local S = {}
        function S.Get(k) if settings[k] == nil then return defaults[k] end return settings[k] end
        function S.Set(k, v)
            settings[k] = v
            for _, fn in ipairs(listeners) do fn(k) end
        end
        function S.OnChange(fn) listeners[#listeners + 1] = fn end
        function S.Toggle(key, text) return { type = "toggle", key = key, text = text } end
        return S
    end,
    Widgets = {
        SectionHeader = function() return nil, 30 end,
        DualRow = function() return nil, 50 end,
        Note = function() return nil, 20 end,
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
    Button = function(parent, _, _, _, onClick)
        local b = Frame(parent)
        b.label, b._border, b._rest, b._onClick = Frame(b), { SetColor = NOTHING }, WHITE, onClick
        b.scripts.OnClick = function() if b._onClick then b._onClick() end end
        return b
    end,
    SetButtonText = NOTHING,
    Tooltip = NOTHING,
    Hairline = NOTHING,
    PixelInset = NOTHING,
    NewSearchBox = function(parent, _, onChange)
        local box = Frame(parent)
        box.hint, box.border = Frame(box), { SetColor = NOTHING }
        box.SetText = function(self, text)
            self.text = text
            onChange(text)
        end
        return box
    end,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    AccountSettings = function() return account end,
    Print = function(m) printed[#printed + 1] = m end,
    TownNPCs = { [1453] = { { 38.4, 79.4, "class", "Elsharin", "Mage Trainer", "MAGE", "A" } } },
    TownCapitals = { [1453] = true },
    PlaceWaypointRoute = function(_, stops)
        local s = stops[1]
        waypoint = { s[1], s[2], s[3], s[4], s[5], #stops }
    end,
    Confirm = function(_, yes) yes() end,
    PromptText = function(_, _, _, accept) accept("Mine") end,
    ShowCopyBox = NOTHING,
    StashOptionsWindow = NOTHING,
    OpenOptionsWindow = NOTHING,
    Apply = NOTHING,
}
local env = setmetatable({
    NaowhForever = ns,
    UIParent = Frame(),
    GameTooltip = Frame(),
    GameTooltip_Hide = NOTHING,
    GameTooltip_SetTitle = function(tooltip, text) tooltip:AddLine(text) end,
    CreateFrame = function(_, _, parent) return Frame(parent) end,
    CreateColor = function() return { SetRGBA = NOTHING } end,
    hooksecurefunc = NOTHING,
    InCombatLockdown = function() return false end,
    IsMouseButtonDown = function() return false end,
    IsModifiedClick = function() return false end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UnitClass = function() return "Mage", "MAGE", 8 end,
    UnitRace = function() return "Human", "Human", 1 end,
    UnitLevel = function() return 20 end,
    UnitFactionGroup = function() return "Alliance" end,
    GetProfessions = NOTHING,
    CreateVector2D = function() end,
    C_Map = { GetBestMapForUnit = function() end, GetWorldPosFromMapPos = function() end },
    UnitName = function() return "Me" end,
    GetRealmName = function() return "Realm" end,
    GetMoney = function() return 12345 end,
    GetClassInfo = function(id) return "Class " .. id, "MAGE" end,
    RAID_CLASS_COLORS = setmetatable({}, { __index = function()
        return { WrapTextInColorCode = function(_, text) return text end }
    end }),
    C_Spell = {
        GetSpellName = function(id) return "Spell " .. id end,
        GetSpellTexture = function() return 1 end,
        GetSpellSubtext = function() return "Rank 1" end,
        GetSpellDescription = function() return "Deals 10 to 12 Fire damage." end,
        RequestLoadSpellData = NOTHING,
        GetSpellLink = function() return "link" end,
    },
    C_SpellBook = { IsSpellKnown = function() return false end },
    C_Item = {},
    C_ClassTalents = { GetActiveConfigID = function() return 1 end, HasUnspentTalentPoints = function() return true end },
    C_Traits = { GetNodeInfo = function(_, node) return { activeRank = 0, entryIDs = { node + 500000 } } end,
        PurchaseRank = function() return true end,
        CommitConfig = function() return true end },
    C_Timer = { After = function(_, fn) fn() end },
    PixelUtil = { SetPoint = NOTHING, SetSize = NOTHING },
    MenuUtil = { CreateContextMenu = NOTHING },
    LibStub = function()
        local same = function(_, v) return v end
        return { Serialize = function() return "S" end, Deserialize = function(_, v) return true, v end, CompressDeflate = same,
            DecompressDeflate = same, EncodeForPrint = same, DecodeForPrint = same }
    end,
}, { __index = _G })
env._G = env

Load({
    "Shared/Shared.lua", "Shared/Data/Forever.lua", "Shared/Style.lua", "Shared/Game/Items.lua", "Shared/Game/Gear.lua", "Shared/Game/Places.lua",
    "Shared/UI/Parts.lua", "Shared/UI/Marks.lua", "Shared/UI/Text.lua", "Shared/UI/Hud.lua", "Shared/UI/Timer.lua", "Shared/UI/Share.lua", "Shared/UI/Panels.lua", "Shared/UI/Window.lua", "Shared/UI/Tabs.lua", "Shared/UI/SettingsCard.lua", "Shared/View/View.lua", "Shared/View/Kinds.lua",
    "Shared/Settings/Settings.lua",
    "Core/Features.lua",
}, env)
-- The planner's own files, as Training.xml lists them.
local xml = assert(io.open("NaowhForever_Training/Training.xml", "rb")):read("*a"):gsub("<!%-%-.-%-%->", "")
local planner = {}
for file in xml:gmatch("<Script%s+file=\"([^\"]+)\"") do
    planner[#planner + 1] = "NaowhForever_Training/" .. file:gsub("\\", "/")
end
Load(planner, env)

-------------------------------------------------------------------------------
--  Opening it, and every part of it
-------------------------------------------------------------------------------
ns.OpenTrainingWindow()
local window
for _, f in ipairs(frames) do
    if rawget(f, "positionKey") == "trainingWindow" then window = f end
end
check("the window is made by the kit", window and window.backdrop and window.switch)
check("it shows", window:IsShown())
check("its subtitle says who you are", window.subtitle:GetText() == "Mage, level 20")
check("the Spells tab shows the next visit and the road", window.hero:IsShown() and window.road:IsShown())
check("and its own controls", window.search:IsShown() and not window.import:IsShown())
Click(window.hero.trainer)
check("its trainer link puts a waypoint on your class's trainer", waypoint and waypoint[1] == "Elsharin"
    and waypoint[2] == 1453 and waypoint[5] == " (Mage Trainer)" and waypoint[6] == 1)

ns.OpenTrainingWindow(20)
check("a level opens on Spells with All Levels", window.back:IsShown())
Click(window.back)
window.search:SetText("spell")
settings.showLearned = true
for _, fn in ipairs(listeners) do fn("showLearned") end
window.search:SetText("")
local painted
local paint = window.backdrop.Paint
window.backdrop.Paint = function(self, alpha, ...) painted = alpha; return paint(self, alpha, ...) end
settings.windowAlpha = 0.5
window:Hide()
ns.OpenTrainingWindow()
check("it opens solid, even with an old lowered opacity saved", painted == 1)

window.switch.onPick("builds")
check("Builds hides the next visit and the road", not window.hero:IsShown() and not window.road:IsShown())
check("and shows its own controls", window.import:IsShown() and window.new:IsShown() and not window.search:IsShown())
local rows, picked = 0, 0
for _, f in ipairs(frames) do
    if rawget(f, "bar") and rawget(f, "picked") ~= nil and f:IsShown() then
        rows = rows + 1
        if f.picked then picked = picked + 1 end
    end
end
check("with none saved, the list is empty and nothing is picked", rows == 0 and picked == 0)

-- Every button the Builds tab drew, clicked: the class row, the build cards and theirs.
local function Clickables()
    local list = {}
    for _, f in ipairs(frames) do
        if f.scripts.OnClick and rawget(f, "shown") ~= false and f ~= window then list[#list + 1] = f end
    end
    return list
end
Click(window.new)
check("New Build opens the editor with an empty build", account.trainingBuilds and #account.trainingBuilds[8] == 1)
for _, f in ipairs(Clickables()) do
    if rawget(f, "spell") then Click(f) end
end
check("clicking talents takes points", #account.trainingBuilds[8][1].points > 0)

-- A talent's tooltip: the text of its rank in the build, then the next rank's, from its trait entry.
local tip = {}
env.GameTooltip.AddLine = function(_, text) tip[#tip + 1] = text end
env.GameTooltip.AppendInfo = function(_, getter, entry, rank) tip[#tip + 1] = getter .. " " .. entry .. " " .. rank end
env.GameTooltip.SetSpellByID = function(_, spell) tip[#tip + 1] = "spell " .. spell end
local function Hover(f)
    for k in pairs(tip) do tip[k] = nil end
    f.scripts.OnEnter(f)
    return table.concat(tip, " / ")
end
local function Nodes()
    local none, some, full
    for _, f in ipairs(frames) do
        if rawget(f, "node") and rawget(f, "count") and f:IsShown() then
            if f.rank == 0 then none = none or f
            elseif f.rank < f.max then some = some or f
            else full = full or f end
        end
    end
    return none, some, full
end
local none, some = Nodes()
local function Starts(text, prefix) return text:sub(1, #prefix) == prefix end
check("a talent with no points shows rank 1 as its next rank", none and Starts(Hover(none),
    ("Spell %d / Rank 0 of %d /   / Next rank: / GetTraitEntry %d 1 / "):format(none.spell, none.max, none.node + 500000)))
check("one with some points shows its rank, then the next", some and Starts(Hover(some),
    ("Spell %d / Rank %d of %d / GetTraitEntry %d %d /   / Next rank: / GetTraitEntry %d %d / "):format(some.spell,
        some.rank, some.max, some.node + 500000, some.rank, some.node + 500000, some.rank + 1)))
local node = some.node
for _ = some.rank + 1, some.max do
    for _, f in ipairs(frames) do
        if rawget(f, "count") and rawget(f, "node") == node and f:IsShown() then Click(f) break end
    end
end
local _, _, full = Nodes()
check("one at full rank shows only its rank", full and Starts(Hover(full),
    ("Spell %d / Rank %d of %d / GetTraitEntry %d %d / "):format(full.spell, full.max, full.max, full.node + 500000,
        full.max)) and not Hover(full):find("Next rank", 1, true))
local step
for _, f in ipairs(frames) do
    if rawget(f, "last") and f:IsShown() then step = step or f end
end
check("a level-by-level row's tooltip reads the rank that step reaches", step and Hover(step):find(
    ("GetTraitEntry %d %d"):format(step.node + 500000, step.last), 1, true))
local tabs
for _, f in ipairs(frames) do
    if rawget(f, "onPick") and f ~= window.switch and f:IsShown() then tabs = f end
end
check("the editor has a Talents and a Spells tab", tabs ~= nil)
tabs.onPick("spells")
local skips = 0
for _, f in ipairs(Clickables()) do
    if rawget(f, "group") then
        Click(f)
        skips = skips + 1
        break
    end
end
check("the editor's Spells tab lists the class's spells to skip, and a click skips one", skips == 1
    and ns.Training.SkipCount(account.trainingBuilds[8][1]) > 0)

-- Two ranks of one spell: the spell's row, then a row per rank, each skipped on its own.
local first, second
for _, entry in ipairs(ns.TrainingData[8]) do
    if not entry.quest then
        if not first then first = entry[2] elseif not second then second = entry[2] end
    end
end
local spellName = env.C_Spell.GetSpellName
env.C_Spell.GetSpellName = function(id)
    if id == first or id == second then return "Same" end
    return spellName(id)
end
env.C_Spell.GetSpellSubtext = function(id) return id == second and "Rank 2" or "Rank 1" end
ns.Training.SkipAll(8, account.trainingBuilds[8][1], false)
local whole, rankTwo
for _, f in ipairs(frames) do
    if rawget(f, "group") and f.group.name == "Same" and f:IsShown() then
        if f.rank == nil then whole = f elseif f.rank == 2 then rankTwo = f end
    end
end
check("a spell with ranks has its own row and one per rank", whole and rankTwo
    and rankTwo.name:GetText() == "Same (Rank 2)" and whole.name:GetText() == "Same")
Click(rankTwo)
local skip = account.trainingBuilds[8][1].skip
check("a rank's row skips only that rank", skip and skip[second] and not skip[first])
env.C_Spell.GetSpellName = spellName
env.C_Spell.GetSpellSubtext = function() return "Rank 1" end
Click(window.save)
Click(window.import)
for _ = 1, 2 do
    for _, f in ipairs(Clickables()) do Click(f) end
end
check("following a build is kept for the character", account.trainingFollow ~= nil)
window.switch.onPick("spells")
check("back on Spells", window.hero:IsShown())

-- The mini bar, and the settings page with the kit's module card.
settings.enabled = true
settings.miniShown = true
for _, fn in ipairs(listeners) do fn("miniShown") end
local mini
for _, f in ipairs(frames) do
    if rawget(f, "gold") and rawget(f, "fill") and rawget(f, "track") and f.scripts.OnEvent then mini = f end
end
check("the mini bar shows, with your gold", mini and mini:IsShown() and mini.gold:GetText():find("|cffffd100g|r", 1, true))
local plans = 0
local Plan = ns.Training.Plan
ns.Training.Plan = function(...) plans = plans + 1 return Plan(...) end
mini.scripts.OnEvent(mini, "PLAYER_MONEY")
ns.Training.Plan = Plan
check("your gold changing repaints the gold, not the plan", plans == 0)
check("Coins reads as before", ns.Training.Coins(12345) == "1|cffffd100g|r 23|cffc7ccd3s|r 45|cffe0904fc|r"
    and ns.Training.Coins(0) == "0|cffe0904fc|r" and ns.Training.Coins(10005) == "1|cffffd100g|r 5|cffe0904fc|r"
    and ns.Training.Coins(200) == "2|cffc7ccd3s|r")
dofile("Tools/regression/measure.lua")(check)("the mini bar on a change of gold", 0.05, function()
    mini.scripts.OnEvent(mini, "PLAYER_MONEY")
end)
local declared = ns.Shared.Settings.pages["Training Planner/Settings"]
local windowCard, trainer = declared and declared.items[1], declared and declared.cards.trainer
check("the settings page is declared, the planner's window card first", windowCard and windowCard.window
    and windowCard.text == "Open Training Planner")
check("and no trainer popup card of its own: QoL's Trainer declares it, so it goes with QoL", trainer == nil)
local buildsCard = declared.cards.builds
check("a Talent Builds card", buildsCard and buildsCard.name == "Talent Builds")
local openRow, stopRow = buildsCard.rows[1], buildsCard.rows[2]
local followed = ns.Training.Builds(8)[1]
ns.Training.Follow(8, followed)
check("its summary names the build you follow", buildsCard.summary() == "Following: " .. followed.name)
check("with Stop Following shown", not stopRow.hidden())
stopRow.button()
check("Stop Following stops it", ns.Training.Followed() == nil and buildsCard.summary() == "Not following a build"
    and stopRow.hidden())
ns.OpenFromOptions = function(open) open() end
window.switch.onPick("spells")
window:Hide()
openRow.button()
check("Open Builds opens the planner on its Builds tab", window:IsShown() and window.import:IsShown()
    and not window.hero:IsShown())
window.switch.onPick("spells")

local backed = 0
window:Hide()
ns.Shared.Parts.OpenWithBack(function() ns.OpenTrainingWindow() end, Frame(), function() backed = backed + 1 end,
    "Back to Settings")
check("opened from /nf, its title links back", window.backLink and window.backLink:IsShown()
    and window.backLink.text:GetText() == "Back to Settings")
check("and All Levels stays its own button", window.back ~= window.backLink)
window:Hide()
check("closing it goes back to /nf, once", backed == 1 and not window.backLink:IsShown())

print(("test-training-window: %d checks passed"):format(checks))
