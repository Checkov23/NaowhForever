-- Run with Lua 5.1 from the repository root: Mana Efficiency (QoL > Interface > Tooltips) on stubs.
-- The generated data's shape (one string per spell), the line's math (direct, periodic, hybrid, both
-- on one target, spell power and its sub-20 penalty, cast against instant), mana-only gating, secrets
-- and malformed entries failing to no line, no garbage per hover once a spell is decoded, off meaning
-- no hook, every option's effect on the line, a bad imported color falling back to the default, the
-- card's preview and Preview Tooltip, and the card's rows, defaults and search.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return s
end

local DATA = "NaowhForever_QoL/Interface/SpellEfficiencyData.lua"
local FIELDS, PART = 3, 9

local source = Read(DATA)
check("the data's header names its builder", source:match("^%-%- SpellEfficiencyData%.lua: .-Tools/build/spell_efficiency%.py"))
local seen, count = {}, 0
for id in source:gmatch("\n    %[(%d+)%] = ") do
    check("spell " .. id .. " is listed once", not seen[id])
    seen[id] = true
    count = count + 1
end
check("the data lists a few hundred spells", count > 200)

local secret = setmetatable({}, {
    __tostring = function() error("formatted a secret") end,
    __index = function() error("indexed a secret") end,
})
local secretTable = {}
local settings = {
    enabled = true, spellEfficiency = false, spellEfficiencyPerMana = true, spellEfficiencyPerSecond = true,
    spellEfficiencyPerManaSecond = false, spellEfficiencyStyle = "long", spellEfficiencyDecimals = 2,
    spellEfficiencyColor = { r = 0.3, g = 0.71, b = 0.96 }, spellEfficiencyBonus = true, spellEfficiencyShow = "all",
}
local defaults = {}
for key, value in pairs(settings) do defaults[key] = value end
defaults.enabled = nil

local function noop() end
local function FontString()
    local fs = { text = "" }
    function fs:SetText(text) self.text = text end
    function fs:GetText() return self.text end
    function fs:SetTextColor(r, g, b) self.color = { r, g, b } end
    return setmetatable(fs, { __index = function() return noop end })
end
local function Frame()
    local f = { lines = {}, shown = false }
    function f:CreateFontString() return FontString() end
    function f:CreateTexture() return FontString() end
    function f:IsForbidden() return self.forbidden == true end
    function f:AddLine(text, r, g, b) self.lines[#self.lines + 1] = { text, r, g, b } end
    function f:NumLines() return #self.lines end
    function f:GetName() return self.name end
    function f:Show() self.shown = true end
    return setmetatable(f, { __index = function() return noop end })
end

local posts, macroPosts, damageReads = {}, {}, {}
local actions, macroSpells = {}, {}
local costs, casts, infos = {}, {}, {}
local spellInfo
local power = { heal = 0 }
local level, statsSecret = 60, false
local tooltip, refTip, shopTip = Frame(), Frame(), Frame()
tooltip.name, refTip.name, shopTip.name = "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1"

local function Post(tip, data)
    for i = 1, #posts do posts[i](tip, data) end
end
function tooltip:SetOwner(owner) self.owner = owner; self.lines = {}; self.shown = false end
function tooltip:SetSpellByID(id) self.lines = {}; Post(self, { type = 1, id = id }) end

local S = {
    Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end,
    Default = function(k) return defaults[k] end,
}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S, Apply = noop,
    THEME = { muted = { r = 0.6, g = 0.6, b = 0.6 }, fg = { r = 1, g = 1, b = 1 }, accent = { r = 0, g = 0.5, b = 1 } },
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    Shared = { Style = dofile("Tools/regression/shared_style.lua") },
    Font = function() return FontString() end, Solid = function() return FontString() end, Border = noop,
}
local env = {
    _G = { NaowhForever = ns }, GameTooltip = tooltip, ItemRefTooltip = refTip, ShoppingTooltip1 = shopTip,
    UIParent = Frame(), CreateFrame = Frame,
    Enum = { PowerType = { Mana = 0, Rage = 1 }, TooltipDataType = { Spell = 1, Item = 2, Unit = 3, Macro = 25 } },
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn)
        if kind == 1 then posts[#posts + 1] = fn elseif kind == 25 then macroPosts[#macroPosts + 1] = fn end
    end },
    GetActionInfo = function(slot) local a = actions[slot]; if a then return a[1], a[2], a[3] end end,
    GetMacroSpell = function(id) return macroSpells[id] end,
    C_Spell = {
        GetSpellPowerCost = function(id) return costs[id] end,
        GetSpellInfo = function(id)
            if spellInfo ~= nil then return spellInfo end
            if casts[id] == nil then return nil end
            local info = infos[id] or {}
            infos[id], info.castTime = info, casts[id]
            return info
        end,
    },
    C_Secrets = { ShouldUnitStatsBeSecret = function() return statsSecret end },
    GetSpellBonusHealing = function() return power.heal end,
    GetSpellBonusDamage = function(school) damageReads[#damageReads + 1] = school; return power[school] or 0 end,
    UnitLevel = function() return level end,
    GetMouseFoci = function() return {} end,
    issecretvalue = function(v) return rawequal(v, secret) end,
    canaccessvalue = function(v) return not rawequal(v, secret) end,
    issecrettable = function(v) return rawequal(v, secret) or rawequal(v, secretTable) end,
    hooksecurefunc = function(t, k, fn) local old = t[k]; t[k] = function(...) old(...); return fn(...) end end,
}
setmetatable(env, { __index = function(_, key)
    local name, n = tostring(key):match("^(.-)TextLeft(%d+)$")
    local tip = name and rawget(env, name)
    if tip then local line = tip.lines[tonumber(n)]; return { GetText = function() return line and line[1] end } end
    return _G[key]
end })
setmetatable(env._G, { __index = env })

for _, path in ipairs({ DATA, "NaowhForever_QoL/Interface/SpellEfficiency.lua" }) do
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end

local function Fields(text)
    local entry, n = {}, 0
    for field in (text .. ","):gmatch("([^,]*),") do
        n = n + 1
        entry[n] = field:match("^%-?%d+%.?%d*$") and tonumber(field)
    end
    return entry, n
end

local Data = ns.SpellEfficiencyData
for id, text in pairs(Data) do
    check("spell IDs are whole numbers", type(id) == "number" and id > 0 and id == math.floor(id))
    check(id .. " is one string, not a table built at login", type(text) == "string")
    local entry, n = Fields(text)
    check(id .. " has its fields and whole parts", n > FIELDS and (n - FIELDS) % PART == 0)
    for i = 1, n do check(id .. " holds numbers only", type(entry[i]) == "number") end
    for at = FIELDS + 1, n, PART do
        check(id .. " is a heal or damage", entry[at] == 0 or entry[at] == 1)
        check(id .. " has whole ticks", entry[at + 7] == math.floor(entry[at + 7]))
    end
end
check("the weapon shot (Aimed Shot) is left out", Data[19434] == nil)
check("Multi-Shot is left out", Data[2643] == nil)
check("seals and Judgement are left out", Data[21084] == nil and Data[20271] == nil and Data[20154] == nil)
check("area triggers (Consecration, Blizzard) are left out", Data[26573] == nil and Data[10] == nil)
check("Swiftmend's scripted heal is left out", Data[18562] == nil)
check("Lesser Heal, Frostbolt, Shadow Word: Pain, Exorcism, Arcane Missiles are in",
    Data[2050] and Data[116] and Data[589] and Data[879] and Data[5143])

check("off: no tooltip hook at all", #posts == 0 and #macroPosts == 0)

local function Show(id, tip)
    tip = tip or tooltip
    tip.lines = {}
    Post(tip, { type = 1, id = id })
    return tip.lines
end

costs[2050], casts[2050] = { { type = 0, cost = 30 } }, 1500
costs[2052], casts[2052] = { { type = 0, cost = 45 } }, 2000
costs[2053], casts[2053] = { { type = 0, cost = 75 } }, 2500
costs[589], casts[589] = { { type = 0, cost = 25 } }, 0
costs[116], casts[116] = { { type = 0, cost = 25 } }, 1500
costs[8936], casts[8936] = { { type = 0, cost = 70 } }, 2000

S.Set("spellEfficiency", true)
check("on: the spell post-call is installed once", #posts == 1)
check("on: the macro post-call is installed once", #macroPosts == 1)

local function ShowMacro(slot, id, tip)
    tip = tip or tooltip
    tip.lines, tip.owner = {}, slot and { action = slot } or false
    for i = 1, #macroPosts do macroPosts[i](tip, { type = 25, id = id }) end
    return tip.lines
end
function tooltip:GetOwner() return self.owner end
actions[1], actions[2], actions[3], actions[4] = { "macro", 2050, "spell" }, { "macro", 7 }, { "macro", 8 }, { "spell", 2050 }
macroSpells[7] = 2052
check("a macro showing a spell gets the line", ShowMacro(1, 7)[1][1] == "1.76 healing per mana  ||  35 per second")
check("a macro is decorated once", #ShowMacro(1, 7) == 1)
check("a macro with no spell shown resolves through GetMacroSpell",
    ShowMacro(2, 7)[1][1] == "1.86 healing per mana  ||  42 per second")
check("a macro with no spell gets no line", #ShowMacro(3, 8) == 0)
check("a non-macro action gets no line from the macro hook", #ShowMacro(4, 7) == 0)
check("with no action slot the tooltip's own id is not trusted: no line", #ShowMacro(nil, 7) == 0)
tooltip.lines, tooltip.owner = {}, { GetAttribute = function(_, name) return name == "action" and 2 or nil end }
for i = 1, #macroPosts do macroPosts[i](tooltip, { type = 25, id = 99 }) end
check("a bar button with only an action attribute resolves through it",
    tooltip.lines[1] ~= nil and tooltip.lines[1][1]:find("42", 1, true) ~= nil)
check("with no action slot and no spell there is no line", #ShowMacro(nil, 8) == 0)
tooltip.lines = {}
Post(tooltip, { type = 1, id = 2050 })
tooltip.owner = { action = 1 }
for i = 1, #macroPosts do macroPosts[i](tooltip, { type = 25, id = 7 }) end
check("a spell tooltip and macro post-call on the same build add the line once", #tooltip.lines == 1)
tooltip.forbidden = true
check("a forbidden tooltip gets no macro line", #ShowMacro(1, 7) == 0)
tooltip.forbidden = nil
tooltip.owner = false

local lines = Show(2050)
check("Lesser Heal 1, no spell power: per mana and per second",
    #lines == 1 and lines[1][1] == "1.76 healing per mana  ||  35 per second")
check("in the line's color", lines[1][2] == 0.3 and lines[1][3] == 0.71 and lines[1][4] == 0.96)
check("Lesser Heal 2", Show(2052)[1][1] == "1.86 healing per mana  ||  42 per second")
check("Lesser Heal 3", Show(2053)[1][1] == "1.99 healing per mana  ||  60 per second")

power.heal = 100
check("Lesser Heal 1 with 100 healing: the level 1 penalty cuts its 0.429 to 0.123",
    Show(2050)[1][1] == "2.17 healing per mana  ||  43 per second")
check("Lesser Heal 2 with 100 healing", Show(2052)[1][1] == "2.36 healing per mana  ||  53 per second")
check("Lesser Heal 3 with 100 healing", Show(2053)[1][1] == "2.58 healing per mana  ||  77 per second")
check("Regrowth 1, hybrid, cast time counts", Show(8936)[1][1] == "3.45 healing per mana  ||  121 per second")
power.heal = 0
check("Regrowth 1 base", Show(8936)[1][1] == "2.67 healing per mana  ||  94 per second")

level = 2
check("the per-level growth stops at the player's level", Show(2050)[1][1] == "1.73 healing per mana  ||  35 per second")
level = 60

check("Shadow Word: Pain 1, instant DoT: per second over its 18 seconds",
    Show(589)[1][1] == "1.20 damage per mana  ||  2 per second")
power[6] = 100
check("with 100 shadow damage", Show(589)[1][1] == "3.12 damage per mana  ||  4 per second")
check("spell damage is read for the spell's school (shadow)", damageReads[#damageReads] == 6)
check("Frostbolt 1 with no frost damage", Show(116)[1][1] == "0.84 damage per mana  ||  14 per second")
power[5] = 100
check("Frostbolt 1 with 100 frost damage", Show(116)[1][1] == "1.49 damage per mana  ||  25 per second")

Data[900001] = "3,60,0,0,100,0,0,0,0,0,0,0"
costs[900001], casts[900001] = { { type = 0, cost = 50 } }, 0
check("an instant spell with no periodic part has no per second", Show(900001)[1][1] == "2.00 damage per mana")
Data[900002] = "2,60,0,0,40,0,0,0,0,0,0,0,1,20,0,0,0,0,0,0,0"
costs[900002], casts[900002] = { { type = 0, cost = 10 } }, 1000
lines = Show(900002)
check("both on one target: a damage line and a heal line", #lines == 2
    and lines[1][1] == "4.00 damage per mana  ||  40 per second" and lines[2][1] == "2.00 healing per mana  ||  20 per second")

costs[2050] = { { type = 1, cost = 10 } }
check("a spell that costs rage gets nothing", #Show(2050) == 0)
costs[2050] = nil
check("no cost, nothing", #Show(2050) == 0)
costs[2050] = { { type = 0, cost = secret } }
check("a secret cost, nothing", #Show(2050) == 0)
costs[2050] = { { type = 0, cost = 30 } }
casts[2050] = secret
check("a secret cast time, nothing", #Show(2050) == 0)
casts[2050] = 1500
spellInfo = secret
check("secret spell info, nothing (never indexed)", #Show(2050) == 0)
spellInfo = secretTable
check("a secret spell info table, nothing", #Show(2050) == 0)
spellInfo = 7
check("spell info that is not a table, nothing", #Show(2050) == 0)
spellInfo = nil
check("readable spell info again: the line", Show(2050)[1][1] == "1.76 healing per mana  ||  35 per second")
check("a spell with no data gets nothing", #Show(12345) == 0)

local MALFORMED = {
    [900010] = "3,60,0,0,100,0,0,0,0,0,0",
    [900011] = "3,60,0",
    [900012] = "3,60,0,0,abc,0,0,0,0,0,0,0",
    [900013] = "3,60,0,0,100,0,0,0,0,0,0,0,",
    [900014] = "3,60,0,0,,0,0,0,0,0,0,0",
    [900015] = "3,60,0,2,100,0,0,0,0,0,0,0",
    [900016] = "3,60,0,0,inf,0,0,0,0,0,0,0",
    [900017] = "3,60,0,0,0x10,0,0,0,0,0,0,0",
    [900018] = "",
    [900019] = { 3, 60, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0 },
}
for id, text in pairs(MALFORMED) do
    Data[id] = text
    costs[id], casts[id] = { { type = 0, cost = 50 } }, 0
    check("malformed entry " .. id .. ": no line, no error", #Show(id) == 0)
    check("malformed entry " .. id .. " again: still nothing", #Show(id) == 0)
end

statsSecret = true
check("stats secret: nothing rather than a guess", #Show(2050) == 0)
settings.spellEfficiencyBonus = false
check("Include My Spell Power off reads no stats and shows the base", Show(2050)[1][1] == "1.76 healing per mana  ||  35 per second")
settings.spellEfficiencyBonus = true
statsSecret = false
power.heal = secret
check("a secret healing bonus, nothing", #Show(2050) == 0)
power.heal = 0

local HOVERS = 200
local AddLine, NumLines = tooltip.AddLine, tooltip.NumLines
local added = 0
tooltip.AddLine = function() added = added + 1 end
tooltip.NumLines = function() return added end
local function Garbage(data, runs, warm)
    collectgarbage("collect")
    collectgarbage("stop")
    if warm then
        added = 0
        Post(tooltip, data)
    end
    local before = collectgarbage("count")
    for _ = 1, runs do
        added = 0
        Post(tooltip, data)
    end
    local grown = collectgarbage("count") - before
    collectgarbage("restart")
    return grown
end
Data[900020] = "2,60,0,1,80,0,0,0,0,0,0,0"
costs[900020], casts[900020] = { { type = 0, cost = 20 } }, 2000
local fresh = { type = 1, id = 900020 }
check("a spell's first hover decodes its entry (allocates)", Garbage(fresh, 1) > 0 and added == 1)
check("later hovers of a decoded spell: no garbage", Garbage(fresh, HOVERS, true) == 0 and added == 1)
check("hovering Lesser Heal again and again: no garbage", Garbage({ type = 1, id = 2050 }, HOVERS, true) == 0 and added == 1)
check("hovering a malformed entry again: no garbage", Garbage({ type = 1, id = 900012 }, HOVERS, true) == 0 and added == 0)
check("hovering a spell with no data: no garbage", Garbage({ type = 1, id = 12345 }, HOVERS, true) == 0 and added == 0)
tooltip.AddLine, tooltip.NumLines = AddLine, NumLines

Show(2050)
Post(tooltip, { type = 1, id = 2050 })
check("run twice on one build: one line", #tooltip.lines == 1)
tooltip.lines = { { "Lesser Heal" } }
Post(tooltip, { type = 1, id = 2050 })
check("rebuilt in place: the line comes back", #tooltip.lines == 2)
tooltip.forbidden = true
check("a forbidden tooltip is left alone", #Show(2050) == 0)
tooltip.forbidden = false
check("comparison tooltips are left alone", #Show(2050, shopTip) == 0)
check("the chat link tooltip gets it", #Show(2050, refTip) == 1)
tooltip.lines = {}
Post(tooltip, { type = 1, id = secret })
check("a secret spell ID, nothing", #tooltip.lines == 0)
Post(tooltip, secret)
check("secret data, nothing", #tooltip.lines == 0)

settings.spellEfficiencyStyle = "short"
check("Short", Show(2050)[1][1] == "HPM 1.76  ||  HPS 35")
check("Short damage", Show(589)[1][1] == "DPM 3.12  ||  DPS 4")
settings.spellEfficiencyPerManaSecond = true
check("Short with per mana per second", Show(2050)[1][1] == "HPM 1.76  ||  HPS 35  ||  HPM/s 1.17")
settings.spellEfficiencyStyle = "long"
check("Long with per mana per second",
    Show(2050)[1][1] == "1.76 healing per mana  ||  35 per second  ||  1.17 per mana per second")
settings.spellEfficiencyDecimals = 0
check("no decimals", Show(2050)[1][1] == "2 healing per mana  ||  35 per second  ||  1 per mana per second")
settings.spellEfficiencyDecimals = 1
check("one decimal", Show(2050)[1][1] == "1.8 healing per mana  ||  35 per second  ||  1.2 per mana per second")
settings.spellEfficiencyDecimals = 2
settings.spellEfficiencyPerMana = false
check("without per mana the first part names the kind",
    Show(2050)[1][1] == "35 healing per second  ||  1.17 per mana per second")
settings.spellEfficiencyPerSecond = false
check("per mana per second alone", Show(2050)[1][1] == "1.17 healing per mana per second")
settings.spellEfficiencyPerManaSecond = false
check("every number off, no line", #Show(2050) == 0)
settings.spellEfficiencyPerMana, settings.spellEfficiencyPerSecond = true, true
settings.spellEfficiencyColor = { r = 1, g = 0.5, b = 0 }
lines = Show(2050)
check("the color setting colors the line", lines[1][2] == 1 and lines[1][3] == 0.5 and lines[1][4] == 0)
local BROKEN_COLORS = { {}, { r = 1, g = 0.5 }, { r = "1", g = 0.5, b = 0 }, { r = 1, g = true, b = 0 }, { r = 1, g = 0.5, b = {} } }
local fallback = defaults.spellEfficiencyColor
for i, broken in ipairs(BROKEN_COLORS) do
    settings.spellEfficiencyColor = broken
    lines = Show(2050)
    check("an imported color with a missing or bad channel (" .. i .. ") falls back to the default",
        #lines == 1 and lines[1][2] == fallback.r and lines[1][3] == fallback.g and lines[1][4] == fallback.b)
end
settings.spellEfficiencyColor = defaults.spellEfficiencyColor
settings.spellEfficiencyShow = "heal"
check("Heals Only: a heal", #Show(2050) == 1)
check("Heals Only: no damage spell", #Show(589) == 0)
lines = Show(900002)
check("Heals Only: only the heal line of both", #lines == 1 and lines[1][1]:find("healing", 1, true))
settings.spellEfficiencyShow = "damage"
check("Damage Only: no heal", #Show(2050) == 0)
check("Damage Only: a damage spell", #Show(589) == 1)
settings.spellEfficiencyShow = "all"

S.Set("spellEfficiency", false)
check("switched off: the hook stays but adds nothing", #posts == 1 and #Show(2050) == 0 and #ShowMacro(1, 7) == 0)

costs[2053], casts[2053] = { { type = 0, cost = 75 } }, 2500
ns.PreviewSpellEfficiency()
check("Preview Tooltip shows a sample spell with the line, even switched off",
    tooltip.shown and #tooltip.lines == 1 and tooltip.lines[1][1] == "1.99 healing per mana  ||  60 per second")
S.Set("spellEfficiency", true)
check("switched on again: still one hook", #posts == 1)
ns.PreviewSpellEfficiency()
check("Preview Tooltip with the hook on: the line once", #tooltip.lines == 1)

local studio = ns.SpellEfficiencyStudio
check("the card's preview is a studio", studio and studio.new and studio.paint and studio.states[1].key)
local shot = studio.new(Frame())
studio.paint(shot, studio.states[1].key)
local heal, bolt = shot.mocks[1].line, shot.mocks[2].line
check("preview: the sample heal", heal.text == "1.79 healing per mana  ||  214 per second")
check("preview: the sample bolt", bolt.text == "2.43 damage per mana  ||  162 per second")
check("preview: in the line's color", heal.color[1] == 0.3 and heal.color[3] == 0.96)
settings.spellEfficiencyStyle = "short"
studio.paint(shot, studio.states[1].key)
check("preview redraws with Short", heal.text == "HPM 1.79  ||  HPS 214" and bolt.text == "DPM 2.43  ||  DPS 162")
settings.spellEfficiencyStyle = "long"
settings.spellEfficiencyBonus = false
studio.paint(shot, studio.states[1].key)
check("preview without spell power", heal.text == "1.50 healing per mana  ||  180 per second"
    and shot.note.text == "Sample spells, base numbers only.")
settings.spellEfficiencyBonus = true
settings.spellEfficiencyShow = "heal"
studio.paint(shot, studio.states[1].key)
check("preview: Heals Only leaves the bolt without a line", bolt.text == "" and heal.text ~= "")
settings.spellEfficiencyShow = "all"
settings.spellEfficiencyColor = { r = 1, g = 0, b = 0 }
studio.paint(shot, studio.states[1].key)
check("preview: the color follows", heal.color[1] == 1 and heal.color[2] == 0)
for i, broken in ipairs(BROKEN_COLORS) do
    settings.spellEfficiencyColor = broken
    studio.paint(shot, studio.states[1].key)
    check("preview: a bad imported color (" .. i .. ") paints the default", heal.color[1] == fallback.r
        and heal.color[2] == fallback.g and heal.color[3] == fallback.b and bolt.color[1] == fallback.r)
end
settings.spellEfficiencyColor = defaults.spellEfficiencyColor
S.Set("spellEfficiency", false)
studio.paint(shot, studio.states[1].key)
check("preview says how to turn it on", shot.note.text:find("Turn on Mana Efficiency", 1, true))

local card
local cardEnv = setmetatable({
    _G = nil, SlashCmdList = {}, CreateFrame = Frame,
    TooltipDataProcessor = { AddTooltipPostCall = noop },
    hooksecurefunc = noop,
}, { __index = env })
local cardNs = setmetatable({
    Shared = { Settings = {
        Group = function(title) return { group = title } end,
        Page = function() return { Card = function(_, spec) card = spec end } end,
    } },
}, { __index = ns })
cardEnv._G = setmetatable({ NaowhForever = cardNs }, { __index = cardEnv })
local chunk = assert(loadfile("NaowhForever_QoL/Interface/GlobalCopy.lua"))
setfenv(chunk, cardEnv)
chunk()
check("the Tooltips card", card and card.id == "tooltips")
check("its preview is Mana Efficiency's", card.studio == ns.SpellEfficiencyStudio)
local rows, group = {}, nil
for _, row in ipairs(card.rows) do
    if row.group then group = row.group elseif row.key or row.button then rows[row.key or row.label] = { row = row, group = group } end
end
local settingsSource, features = Read("Core/Settings.lua"), Read("Core/Features.lua")
check("the switch defaults off in Core/Features.lua", features:find("\n        spellEfficiency = false,\n", 1, true))
check("the store reads it from there", settingsSource:find("spellEfficiency = F.spellEfficiency", 1, true))
for key in pairs(defaults) do
    local entry = rows[key]
    check(key .. " is a row in the Spell Efficiency group", entry and entry.group == "Spell Efficiency")
    check(key .. " has a default in the QoL store", settingsSource:find("[%s,]" .. key .. " = "))
    local help = entry.row.help
    check(key .. " has one short sentence of help", help and #help < 100 and not help:sub(1, -2):find("%. "))
end
check("the switch row", rows.spellEfficiency.row.label == "Mana Efficiency" and rows.spellEfficiency.row.always)
check("its options need it", rows.spellEfficiencyStyle.row.needs == "spellEfficiency")
check("Preview Tooltip opens the sample", rows["Preview Tooltip"].row.button == ns.PreviewSpellEfficiency)

local Search = dofile("Tools/regression/settings_search.lua")({ ["QoL/Interface"] = { card } })
local function Finds(query, label)
    for _, hit in ipairs(Search(query)) do
        if hit.label == label then return true end
    end
    return false
end
check("search finds Mana Efficiency", Finds("mana efficiency", "Mana Efficiency"))
check("search finds it by HPM", Finds("hpm", "Mana Efficiency"))
check("search finds Per Mana per Second", Finds("per mana per second", "Per Mana per Second"))
check("search finds Include My Spell Power", Finds("spell power", "Include My Spell Power"))
check("search finds Show On", Finds("show on", "Show On"))
check("search finds the Preview Tooltip", Finds("preview tooltip", "Preview Tooltip"))

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do copy[k] = DeepCopy(v) end
    return copy
end
local root = { qol = {} }
local presetNs = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    SettingsRoot = function() return root end,
    PROFILE_OWN = { qol = {} },
    Shared = { Settings = { pages = {} } },
}
presetNs.QoLSettings = {
    Get = function(k) local v = root.qol[k]; if v == nil then return defaults[k] end; return v end,
    Set = function(k, v) root.qol[k] = v end,
}
local presetEnv = setmetatable({ NaowhForever = presetNs, CopyTable = DeepCopy }, { __index = _G })
presetEnv._G = presetEnv
for _, path in ipairs({ "Core/Profiles/Presets.lua", "Core/Profiles/Setups.lua" }) do
    local load = assert(loadfile(path))
    setfenv(load, presetEnv)
    load()
end
check("both of Naowh's setups are there", #presetNs.PRESETS.order == 2)
for _, key in ipairs(presetNs.PRESETS.order) do
    check(key .. " sets Mana Efficiency off", presetNs.PRESETS[key].profile.qol.spellEfficiency == false)
    root = { qol = {} }
    presetNs.QoLSettings.Set("spellEfficiency", true)
    check("a player who turned it on keeps it on", presetNs.QoLSettings.Get("spellEfficiency") == true)
    presetNs.ApplyPreset(key)
    check("applying " .. key .. " turns it off", presetNs.QoLSettings.Get("spellEfficiency") == false
        and root.qol.preset == key)
end

print(("test-spell-efficiency: %d checks passed"):format(checks))
