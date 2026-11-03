-- Run with Lua 5.1 from the repository root: the Mana Efficiency window (/nf efficiency) on stubs, loaded with the
-- Shared files, the real data and the tooltip code. Its numbers are the tooltip's (ns.SpellEfficiencyOf), it lists
-- every known rank and the unknown higher ones greyed, stars the best rank, sorts by a clicked column, searches,
-- follows the Tooltips card's settings, and costs nothing until it is opened.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end
local Frame
local made = 0
local frames = {}
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.scripts[script] = f.scripts[script] or fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    GetParent = function(f) return rawget(f, "parent") end,
    GetWidth = function() return 400 end,
    GetHeight = function() return 24 end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    SetTextColor = function(f, r, g, b) f.color = { r, g, b } end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
    GetFrameLevel = function() return 1 end,
    IsForbidden = function() return false end,
    GetEffectiveScale = function() return 1 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
    CreateAnimationGroup = function(f) return Frame(f) end,
    CreateAnimation = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    return setmetatable({ scripts = {}, events = {}, parent = parent }, META)
end

local THEME = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 }, accent = { r = 0, g = 0.5, b = 1 } }
setmetatable(THEME, { __index = function() return { r = 1, g = 1, b = 1 } end })
local timers = {}
local tooltip = Frame()
tooltip.GetOwner = function() return nil end
tooltip.SetSpellByID = function(self, id) self.spell = id end

local settings = {
    enabled = true, spellEfficiency = false, spellEfficiencyPerMana = true, spellEfficiencyPerSecond = true,
    spellEfficiencyPerManaSecond = true, spellEfficiencyStyle = "long", spellEfficiencyDecimals = 2,
    spellEfficiencyColor = { r = 1, g = 1, b = 1 }, spellEfficiencyBonus = true, spellEfficiencyTalents = true,
    spellEfficiencyShow = "all",
}
local S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end,
    Default = function(k) return settings[k] end }
local minimap = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S, QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    Print = NOTHING, Apply = NOTHING, AccountSettings = function() return {} end,
    THEME = THEME,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    ThemeTint = function(_, literal) return literal end,
    Hairline = function(region) return region end,
    PixelInset = function(region) return region end,
    Border = function() return { SetColor = NOTHING } end,
    AccentBorder = function() return { SetColor = NOTHING } end,
    AllowOffscreen = NOTHING,
    Button = function(parent) return Frame(parent) end,
    NewSearchBox = function(parent, _, onChange)
        local box = Frame(parent)
        box.onChange, box.hint, box.border = onChange, Frame(box), { SetColor = NOTHING }
        frames[#frames + 1] = box
        return box
    end,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    UI = { Keep = NOTHING, SlimScroll = function(parent) return Frame(parent) end, CloseOnEscape = NOTHING },
    RegisterMinimapFeature = function(feature) minimap[#minimap + 1] = feature end,
}

local names = { [2050] = "Lesser Heal", [2052] = "Lesser Heal", [2053] = "Lesser Heal", [116] = "Frostbolt",
    [205] = "Frostbolt", [122] = "Frost Nova" }
local subtexts = { [2050] = "Rank 1", [2052] = "Rank 2", [2053] = "Rank 3", [116] = "Rank 1", [122] = "Rank 1" }
local known = { [2050] = true, [2052] = true, [116] = true, [122] = true }
local costs = { [2050] = 30, [2052] = 45, [2053] = 75, [116] = 25, [205] = 35, [122] = 55 }
local casts = { [2050] = 1500, [2052] = 2000, [2053] = 2500, [116] = 1500, [205] = 1800, [122] = 0 }
local loads = {}
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent)
        made = made + 1
        local f = Frame(parent)
        frames[#frames + 1] = f
        return f
    end,
    hooksecurefunc = function(a, b, c)
        if type(a) ~= "table" then return end
        local original = a[b]
        a[b] = function(...) original(...); c(...) end
    end,
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_Item = { GetItemInfo = NOTHING, GetItemIconByID = NOTHING },
    C_Spell = {
        GetSpellName = function(id) return names[id] end,
        GetSpellSubtext = function(id) return subtexts[id] or "" end,
        GetSpellPowerCost = function(id) return costs[id] and { { type = 0, cost = costs[id] } } end,
        GetSpellInfo = function(id) return casts[id] and { castTime = casts[id] } end,
        RequestLoadSpellData = function(id) loads[#loads + 1] = id end,
    },
    C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end },
    C_ClassTalents = { GetActiveConfigID = NOTHING },
    C_Traits = { GetNodeInfo = NOTHING },
    Enum = { PowerType = { Mana = 0 }, TooltipDataType = { Spell = 1, Macro = 25 } },
    TooltipDataProcessor = { AddTooltipPostCall = NOTHING },
    UnitLevel = function() return 60 end,
    GetSpellBonusHealing = function() return 0 end,
    GetSpellBonusDamage = function() return 0 end,
    GetSpellCritChance = function() return 0 end,
    GetActionInfo = NOTHING, GetMacroSpell = NOTHING, GetMouseFoci = function() return {} end,
    Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
    GameTooltip = tooltip,
    GameTooltip_Hide = NOTHING,
    InCombatLockdown = function() return false end,
    CreateColor = function() return Frame() end,
    UIParent = Frame(),
}, { __index = _G })
env._G = env

local files = TocFiles("^Shared/.*%.lua$")
for i = #files, 1, -1 do
    if files[i] == "Shared/UI/CopyCard.lua" then table.remove(files, i) end
end
Load(files, env)
local views = {}
local NewView = ns.Shared.View.New
ns.Shared.View.New = function(...)
    local view = NewView(...)
    views[#views + 1] = view
    return view
end
made = 0
Load({ "NaowhForever_QoL/Interface/SpellEfficiencyData.lua", "NaowhForever_QoL/Interface/SpellEfficiency.lua",
    "NaowhForever_QoL/Interface/SpellEfficiencyReport.lua" }, env)

check("closed, the window costs nothing: no frame made at load", made == 0 and #views == 0)
check("a minimap button can open it", #minimap == 1 and minimap[1].id == "SpellEfficiency"
    and minimap[1].open == ns.ToggleSpellEfficiencyReport)

local Of, Number = ns.SpellEfficiencyOf, ns.SpellEfficiencyNumber
local lesser = Of(2050)
check("the shared numbers: Lesser Heal 1's mana, cast time and kind", lesser.mana == 30 and lesser.castMs == 1500
    and lesser.count == 1 and lesser[1].kind == 1 and not lesser.area)
check("the shared numbers are the tooltip's", Number(lesser[1].perMana) == "1.72"
    and Number(lesser[1].perSecond, true) == "34" and Number(lesser[1].perManaSecond) == "1.15")
local nova = Of(122)
check("an instant area spell: flagged, no per second", nova.area and nova[1].perSecond == nil and nova[1].perMana > 0)
check("a spell with no data has no numbers", Of(12345) == nil)
local kept = {}
check("a table passed in is filled and returned", Of(2050, kept) == kept and kept[1].perMana == lesser[1].perMana)

ns.OpenSpellEfficiencyReport()
local view = views[1]
check("opening builds it once", view ~= nil and made > 0)

local function Rows()
    local out = {}
    for i = 1, view.pools.rank.used do
        local row = view.pools.rank[i]
        if row:IsShown() then out[#out + 1] = row end
    end
    return out
end
local function Sections()
    local out = {}
    for i = 1, view.pools.section.used do out[#out + 1] = view.pools.section[i].text.text end
    return out
end
local function RowOf(id)
    for _, row in ipairs(Rows()) do
        if row.spellID == id then return row end
    end
end
local function Cells(row)
    local out = {}
    for _, cell in ipairs(row.cells) do
        if cell.shown ~= false then out[#out + 1] = cell.text end
    end
    return table.concat(out, " ")
end
local function Order(name)
    local out = {}
    for _, row in ipairs(Rows()) do
        if names[row.spellID] == name then out[#out + 1] = row.spellID end
    end
    return table.concat(out, ",")
end
local function Header(key)
    for _, f in ipairs(frames) do
        if f.key == key then return f end
    end
end
local function Flush()
    while #timers > 0 do table.remove(timers, 1)() end
end

local sections = table.concat(Sections(), "|")
check("one group per spell, in name order", sections:find("^FROST NOVA") and sections:find("|FROSTBOLT|", 1, true)
    and sections:find("|LESSER HEAL$"))
check("an area spell's group says per target", sections:find("FROST NOVA   / target", 1, true))
check("every known rank is listed", RowOf(2050) and RowOf(2052) and RowOf(116) and RowOf(122))
check("its rank text is the spell's", RowOf(2052).rank.text == "Rank 2")
check("a rank's cells are mana, amount and the three rates, as the tooltip has them",
    Cells(RowOf(2050)) == "30 52 1.72 34 1.15")
check("an unknown higher rank is listed greyed", RowOf(2053) and RowOf(2053).rank.color[1] == THEME.muted.r
    and RowOf(2052).rank.color[1] == THEME.fg.r)
check("an unknown rank whose text has not loaded is asked for and left out", RowOf(205) == nil and loads[#loads] == 205)
check("the star marks the most per mana among known ranks", RowOf(2052).star.shown == true
    and RowOf(2050).star.shown == false and RowOf(2053).star.shown == false)
check("an instant spell with nothing periodic shows no per second", Cells(RowOf(122)):find(" %- %-$") ~= nil)
check("ranks start in rank order", Order("Lesser Heal") == "2050,2052,2053")
check("it refreshes on spell, level and talent changes while shown", view.events.SPELLS_CHANGED
    and view.events.PLAYER_LEVEL_UP and view.events.TRAIT_CONFIG_UPDATED and view.events.SPELL_DATA_LOAD_RESULT)

subtexts[205] = "Rank 2"
view:OnEvent("SPELL_DATA_LOAD_RESULT", 205, true)
Flush()
check("once its text loads, the rank shows", RowOf(205) ~= nil and RowOf(205).rank.color[1] == THEME.muted.r)

local perMana = Header("perMana")
check("the column headers name the columns", perMana.text.text == "Per Mana"
    and Header("perManaSecond").text.text == "Per Mana/s")
perMana.scripts.OnClick(perMana)
check("clicking a number column sorts highest first", Order("Lesser Heal") == "2053,2052,2050")
check("and lights that column", perMana.text.color[3] == THEME.accent.b and Header("rank").text.color[3] == THEME.muted.b)
perMana.scripts.OnClick(perMana)
check("clicking it again reverses it", Order("Lesser Heal") == "2050,2052,2053")
local mana = Header("mana")
mana.scripts.OnClick(mana)
check("sorting by mana", Order("Lesser Heal") == "2053,2052,2050")
check("the star stays on the best rank whatever the order", RowOf(2052).star.shown == true)
local rank = Header("rank")
rank.scripts.OnClick(rank)
check("Rank sorts lowest first", Order("Lesser Heal") == "2050,2052,2053")

S.Set("spellEfficiencyPerManaSecond", false)
Flush()
check("a rate turned off on the card leaves the window", Cells(RowOf(2050)) == "30 52 1.72 34"
    and Header("perManaSecond").shown == false)
S.Set("spellEfficiencyDecimals", 0)
Flush()
check("Decimals follow the card", Cells(RowOf(2050)) == "30 52 2 34")
S.Set("spellEfficiencyDecimals", 2)
S.Set("spellEfficiencyStyle", "short")
Flush()
check("Short names the columns in short, both kinds listed", perMana.text.text == "H/DPM"
    and Header("perSecond").text.text == "H/DPS")
S.Set("spellEfficiencyShow", "heal")
Flush()
check("Show On heals leaves the damage spells out", RowOf(116) == nil and RowOf(122) == nil and RowOf(2050) ~= nil)
check("and the short headers are the heal ones", perMana.text.text == "HPM" and Header("perSecond").text.text == "HPS")
S.Set("spellEfficiencyShow", "all")
S.Set("spellEfficiencyStyle", "long")
S.Set("spellEfficiencyPerManaSecond", true)
Flush()

local search
for _, f in pairs(frames) do
    if rawget(f, "onChange") then search = f end
end
check("it has a search box", search ~= nil)
search.onChange("Frost")
check("the search box narrows the list by name", RowOf(2050) == nil and RowOf(116) ~= nil and RowOf(122) ~= nil)
search.onChange("nothing like it")
check("no match says so", view.pools.note.used == 1 and #Rows() == 0)
search.onChange("")

known[2053] = true
view:OnEvent("SPELLS_CHANGED")
Flush()
check("a rank learned while shown moves into the list and takes the star", RowOf(2053).rank.color[1] == THEME.fg.r
    and RowOf(2053).star.shown == true and RowOf(2052).star.shown == false)

ns.ToggleSpellEfficiencyReport()
check("the toggle closes it", view:GetParent():GetParent().shown == false)

print(("test-spell-efficiency-report: %d checks passed"):format(checks))
