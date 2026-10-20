-- Run with Lua 5.1 from the repository root: Scout (NaowhForever_QoL/Interface/Scout.lua) against a stub tooltip. Off,
-- it hooks and builds nothing. On, a creature's tooltip gets its abilities with range and cast time, its armor and the
-- cut of your physical damage at your level, and a hint naming the details key. Holding that key shows Scout's own
-- details box under the tooltip or the full spell tooltips beside it, and letting go hides them: the creature's
-- tooltip is never redrawn. Hunters see a beast's family and whether they can tame it yet. A hidden creature ID adds
-- nothing, a spell the client does not know is left out, instances can be left out, and the data waits for combat.
-- A creature's own armor is used, the level's expected armor (with a ~) when it has none; what it is immune to and
-- resists is listed.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local HOGGER, TOOTH, RAGNAROS, BOAR, MYSTERY = 448, 2850, 11502, 113, 9999
local SPELLS = {
    [6016] = { name = "Pierce Armor", icon = 1, castTime = 0, minRange = 0, maxRange = 0, desc = "Reduces armor." },
    [6268] = { name = "Rushing Charge", icon = 2, castTime = 0, minRange = 5, maxRange = 25, desc = "Charges." },
    [6730] = { name = "Head Butt", icon = 3, castTime = 0, minRange = 0, maxRange = 0, desc = "Stuns for 2 sec." },
    [20565] = { name = "Magma Blast", icon = 4, castTime = 1000, minRange = 0, maxRange = 50000, desc = "Fire." },
    [7000] = { name = "Quiet", icon = 5, castTime = 0, minRange = 0, maxRange = 0, desc = "" },
}
local ARMOR = {}
for level = 1, 63 do ARMOR[level] = level * 10 end
ARMOR[11], ARMOR[37], ARMOR[63] = 545, 1607, 3731

local function Fixture(settings)
    local s = { lines = {}, frames = {}, keys = {}, combat = false, instance = false, playerLevel = 12, class = "WARRIOR",
        units = {}, unit = "mouseover", hooks = 0, timers = {}, loads = 0, settings = settings or {} }
    local defaults = { enabled = true, scout = true, scoutAbilities = true, scoutArmor = true, scoutImmunities = true,
        scoutKey = "ctrl",
        scoutDetails = "inline", scoutFamily = true, scoutInstances = true, scoutHint = true }
    local S = { Get = function(k) local v = s.settings[k]; if v == nil then return defaults[k] end; return v end,
        Set = function(k, v) s.settings[k] = v end }
    local function Frame(kind, name)
        local f = { kind = kind, name = name, events = {}, scripts = {}, shown = false, lines = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:SetOwner() self.lines = {} end
        function f:SetClampedToScreen() end
        function f:ClearAllPoints() end
        function f:SetPoint(...) self.point = { ... } end
        function f:SetSpellByID(id) self.spell = id end
        function f:AddLine(text, r, g, b, wrap) self.lines[#self.lines + 1] = { text = text, wrap = wrap } end
        s.frames[#s.frames + 1] = f
        return f
    end
    local tooltip = Frame("GameTooltip", "GameTooltip")
    tooltip.shown = true
    function tooltip:IsForbidden() return false end
    function tooltip:IsShown() return self.shown end
    function tooltip:GetUnit() return "Name", s.unit end
    function tooltip:GetCenter() return s.tooltipX or 1500 end
    function tooltip:HookScript(k, fn) self.scripts[k] = fn end
    function tooltip:AddLine(text, r, g, b, wrap) s.lines[#s.lines + 1] = { text = text, r = r, wrap = wrap } end
    function tooltip:AddDoubleLine(l, r, lr, lg, lb, rr)
        s.lines[#s.lines + 1] = { text = l, right = r, rr = rr }
    end
    function tooltip:SetUnit() s.redrawn = true end
    s.tooltip = tooltip
    local packed = {
        abilities = { HOGGER, { 6016, 6268, 6730, MYSTERY }, RAGNAROS, { 20565 }, TOOTH, { 6016 }, BOAR, {},
            1001, { 7000 } },
        tameable = { 0, { TOOTH } },
        stats = { HOGGER, { 538, 0, 0, 0, 0, 0, 0, 0, 0 }, RAGNAROS, { 4691, 4, 116097015, 0, 0, 0, 0, 0, 0 },
            TOOTH, { 1593, 0, 0, 0, 0, 0, 0, 0, 0 }, 1001, { 100, 0, 0, 0, 60, 0, 20, 0, 0 },
            1002, { 500, 1, 0, 0, 0, 0, 0, 0, 0 } },
    }
    local ns = {
        L = function(t) return t end, QoLSettings = S, ScoutArmor = ARMOR,
        ScoutAbilitiesPacked = "abilities", ScoutTameablePacked = "tameable", ScoutStatsPacked = "stats",
        THEME = { accentSoft = { r = 0.3, g = 0.7, b = 0.96 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
            fg = { r = 0.9, g = 0.9, b = 0.9 } },
        QoLConstants = { WHITE_RGB = { r = 1, g = 1, b = 1 }, PERCENT = 100 },
        Shared = { Style = { HAVE_RGB = { r = 0.3, g = 0.82, b = 0.48 }, RED_RGB = { r = 0.97, g = 0.44, b = 0.44 },
            FOREVER_GOLD_RGB = { r = 1, g = 0.82, b = 0 }, PLACE_DOT = " . " },
            Settings = { Page = function(page) s.page = page; return { Card = function(_, card) s.card = card end } end } },
        Apply = function() end,
    }
    local function Unit(unit) return s.units[unit] or {} end
    local env = setmetatable({
        _G = { NaowhForever = ns },
        GameTooltip = tooltip, UIParent = { GetWidth = function() return 1920 end },
        CreateFrame = function(kind, name) return Frame(kind, name) end,
        hooksecurefunc = function(t, k, fn) local old = t[k]; t[k] = function(...) old(...); fn(...) end end,
        TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) s.hooks = s.hooks + 1; s.onUnit = fn end },
        Enum = { TooltipDataType = { Unit = 2 }, CompressionMethod = { Deflate = 0 } },
        C_EncodingUtil = { DecodeBase64 = function(x) return x end, DecompressString = function(x) return x end,
            DeserializeCBOR = function(x) s.unpacked = (s.unpacked or 0) + 1; return packed[x] end },
        C_Spell = {
            GetSpellInfo = function(id) return SPELLS[id] end,
            GetSpellName = function(id) return SPELLS[id] and SPELLS[id].name end,
            GetSpellTexture = function(id) return SPELLS[id] and SPELLS[id].icon end,
            GetSpellDescription = function(id) return SPELLS[id] and SPELLS[id].desc or "" end,
        },
        C_Timer = { After = function(_, fn) s.timers[#s.timers + 1] = fn end },
        Spell = { CreateFromSpellID = function()
            s.loads = s.loads + 1
            assert(s.loads < 50, "a spell with no description keeps asking to load")
            return { ContinueOnSpellLoad = function(_, fn) fn() end }
        end },
        IsControlKeyDown = function() return s.keys.ctrl == true end,
        IsAltKeyDown = function() return s.keys.alt == true end,
        IsShiftKeyDown = function() return s.keys.shift == true end,
        InCombatLockdown = function() return s.combat end,
        IsInInstance = function() return s.instance end,
        UnitLevel = function(unit) if unit == "player" then return s.playerLevel end return Unit(unit).level end,
        UnitClassification = function(unit) return Unit(unit).classification or "normal" end,
        UnitCanAttack = function(_, unit) return Unit(unit).hostile ~= false end,
        UnitClass = function() return s.class, s.class end,
        UnitCreatureFamily = function(unit) return Unit(unit).family end,
        issecretvalue = function(v) return v == s.secret and v ~= nil end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        bit = {
            band = function(a, b)
                local r, p = 0, 1
                while a > 0 and b > 0 do
                    if a % 2 == 1 and b % 2 == 1 then r = r + p end
                    a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
                end
                return r
            end,
            lshift = function(a, n) return a * 2 ^ n end,
        },
        strsplit = function(sep, text)
            local out = {}
            for part in (text .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
            return unpack(out)
        end,
    }, { __index = _G })
    local chunk = assert(loadfile("NaowhForever_QoL/Interface/Scout.lua"))
    setfenv(chunk, env)
    chunk()
    s.ns, s.S = ns, S
    function s.Fire(event, ...)
        for _, f in ipairs(s.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end
    function s.Login() s.Fire("PLAYER_LOGIN") end
    function s.Listening(event)
        for _, f in ipairs(s.frames) do if f.events[event] then return true end end
        return false
    end
    function s.RunTimers()
        local due = s.timers
        s.timers = {}
        for _, fn in ipairs(due) do fn() end
    end
    function s.Hover(npc, unit)
        s.lines = {}
        s.units.mouseover = unit
        s.onUnit(tooltip, { guid = npc and ("Creature-0-1-2-3-" .. npc .. "-0000ABCDEF") })
        s.RunTimers()
        return s.lines
    end
    function s.Find(text)
        for _, line in ipairs(s.lines) do
            if line.text == text then return line end
        end
        for _, line in ipairs(s.lines) do
            if type(line.text) == "string" and line.text:find(text, 1, true) then return line end
        end
    end
    function s.Named(name)
        for _, f in ipairs(s.frames) do if f.name == name then return f end end
    end
    function s.Details()
        local d = s.Named("NaowhForeverScoutDetails")
        return d and d.shown and d or nil
    end
    function s.Tips()
        local out = {}
        for _, f in ipairs(s.frames) do
            if f.name and f.name:find("^NaowhForeverScoutSpell") and f.shown then out[#out + 1] = f.spell end
        end
        return out
    end
    return s
end

local function Has(frame, text)
    for _, line in ipairs(frame.lines) do
        if type(line.text) == "string" and line.text:find(text, 1, true) then return line end
    end
end

do
    local s = Fixture({ scout = false })
    s.Login()
    check("off: nothing hooked, no frame but the login one", s.hooks == 0 and #s.frames == 2 and s.unpacked == nil)
    check("the card is on the Interface tab after Tooltips, with its switch", s.page == "QoL/Interface"
        and s.card.order == 52 and s.card.switch == "scout")
end

do
    local s = Fixture()
    s.Login()
    check("on: one unit hook, abilities and tameable beasts unpacked once, stats not until used",
        s.hooks == 1 and s.unpacked == 2)
    check("listening for the details key", s.Listening("MODIFIER_STATE_CHANGED"))
    s.Hover(HOGGER, { level = 11 })
    check("the first creature's armor unpacks the stats, once", s.unpacked == 3)
    check("a creature's abilities, under their header", s.Find("Abilities") and s.Find("Pierce Armor"))
    check("each with its range and cast time", s.Find("Rushing Charge").right == "5-25 yd . Instant"
        and s.Find("Head Butt").right == "Melee . Instant")
    check("with its icon", s.Find("Pierce Armor").text == "|T1:0|t Pierce Armor")
    check("a spell the client does not know is left out", #s.lines == 7)
    check("its own armor, with no ~", s.Find("Armor").right == "538")
    check("and your physical damage it takes at level 12: 538 / (538 + 400 + 85 x 12)",
        s.Find("Your physical damage").right == "-27.5%")
    check("nothing to say about immunities when it has none", not s.Find("Immune:") and not s.Find("Resists:"))
    check("the hint names the key", s.Find("Hold Ctrl for ability details") ~= nil)
    check("no details until the key is held", s.Details() == nil)

    s.Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
    local details = s.Details()
    check("Ctrl pressed: Scout's details box under the tooltip", details and details.point[1] == "TOPLEFT"
        and details.point[3] == "BOTTOMLEFT")
    check("each ability with its description, wrapped", Has(details, "Head Butt")
        and Has(details, "Stuns for 2 sec.").wrap)
    check("the creature's tooltip is never redrawn", not s.redrawn)
    s.Fire("MODIFIER_STATE_CHANGED", "LCTRL", 0)
    check("let go: it hides", s.Details() == nil)
    s.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    check("another modifier does nothing", s.Details() == nil)

    s.keys.ctrl = true
    s.Hover(HOGGER, { level = 11 })
    check("Ctrl already held over a creature: the details show once it is drawn", s.Details() ~= nil)
    s.keys.ctrl = false

    s.S.Set("scoutDetails", "beside")
    s.Hover(HOGGER, { level = 11 })
    s.Fire("MODIFIER_STATE_CHANGED", "RCTRL", 1)
    local tips = s.Tips()
    check("Beside It: one spell tooltip per known ability, none for the unknown one", #tips == 3
        and tips[1] == 6016 and tips[3] == 6730 and s.Details() == nil)
    check("on the left of a tooltip on the right of the screen",
        s.Named("NaowhForeverScoutSpell1").point[1] == "TOPRIGHT")
    s.tooltip.scripts.OnHide(s.tooltip)
    check("and they go with the creature's tooltip", #s.Tips() == 0)
    s.Fire("MODIFIER_STATE_CHANGED", "RCTRL", 1)
    check("a key pressed with no creature shown does nothing", #s.Tips() == 0)

    s.S.Set("scoutKey", "alt")
    s.Hover(HOGGER, { level = 11 })
    s.Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
    check("another key chosen: Ctrl does nothing, the hint names Alt", #s.Tips() == 0
        and s.Find("Hold Alt for ability details"))
    s.Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
    check("and Alt shows them", #s.Tips() == 3)
    s.Fire("MODIFIER_STATE_CHANGED", "LALT", 0)
    s.S.Set("scoutHint", false)
    s.Hover(HOGGER, { level = 11 })
    check("Key Hint off: no hint", not s.Find("ability details"))

    s.S.Set("scoutDetails", "inline")
    s.Hover(1001, { level = 5 })
    s.Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
    check("a spell with no description asks the client once, and stops", s.loads == 1 and s.Details()
        and Has(s.Details(), "Quiet"))
    s.Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
    check("and does not ask again", s.loads == 1)
    s.Fire("MODIFIER_STATE_CHANGED", "LALT", 0)

    s.playerLevel = 60
    s.Hover(RAGNAROS, { level = -1, classification = "worldboss" })
    check("Ragnaros's own armor is 4691, not a level 63's 3731", s.Find("Armor").right == "4691")
    check("which takes 46.0% of a level 60's physical damage", s.Find("Your physical damage").right == "-46.0%")
    local immune = s.Find("Immune:")
    check("Ragnaros is immune to fire, stuns, fears and roots", immune and immune.text:find("Fire", 1, true)
        and immune.text:find("Stun", 1, true) and immune.text:find("Fear", 1, true) and immune.text:find("Root", 1, true))
    check("and not to what the mask leaves out: Holy, Frost, Distract", not immune.text:find("Holy", 1, true)
        and not immune.text:find("Frost", 1, true))
    check("the list wraps", immune.wrap)
    s.Hover(1001, { level = 5 })
    check("a creature's resistances, in the order of the schools", s.Find("Resists:").text == "Resists: Fire 60, Frost 20")
    s.S.Set("scoutImmunities", false)
    s.Hover(RAGNAROS, { level = -1, classification = "worldboss" })
    check("Immunities and Resistances off: neither line", not s.Find("Immune:") and not s.Find("Resists:"))
    s.S.Set("scoutImmunities", true)
    s.Hover(1002, { level = 5 })
    check("a creature immune to physical damage says so, and shows no armor or damage cut",
        s.Find("Immune:").text == "Immune: Physical" and not s.Find("Your physical damage") and not s.Find("Armor"))
    s.Hover(BOAR, { level = 11 })
    check("a creature with no stats of its own: the level's expected armor, with a ~", s.Find("Armor").right == "~545")
    check("and its cut of a level 60's physical damage: 545 / (545 + 400 + 85 x 60)",
        s.Find("Your physical damage").right == "-9.0%")
    s.Hover(RAGNAROS, { level = -1, classification = "worldboss" })
    check("a spell with a cast time and no minimum range", s.Find("Magma Blast").right == "50000 yd . 1s cast")
    s.Hover(HOGGER, { level = 11, hostile = false })
    check("no armor on a creature you cannot attack", not s.Find("Your physical damage"))

    s.playerLevel = 30
    s.Hover(TOOTH, { level = 37, family = "Cat" })
    check("not a hunter: no pet family", not s.Find("Pet family"))
    s.class = "HUNTER"
    s.Hover(TOOTH, { level = 37, family = "Cat" })
    local family = s.Find("Pet family")
    check("a hunter below its level: red, untameable until level 37",
        family.right == "Cat . Untameable until level 37" and family.rr == 0.97)
    s.Hover(TOOTH, { level = -1, family = "Cat" })
    check("a tameable beast shown as ??: untameable at your level, not never",
        s.Find("Pet family").right == "Cat . Untameable at your level")
    s.playerLevel = 40
    s.Hover(TOOTH, { level = 37, family = "Cat" })
    family = s.Find("Pet family")
    check("at or above it: green, tameable", family.right == "Cat . Tameable" and family.rr == 0.3)
    s.Hover(BOAR, { level = 5, family = "Boar" })
    check("a beast no hunter can tame says so", s.Find("Pet family").right == "Boar . Untameable")
    s.S.Set("scoutFamily", false)
    s.Hover(TOOTH, { level = 37, family = "Cat" })
    check("Pet Family off: no line", not s.Find("Pet family"))

    s.secret = "Creature-0-1-2-3-448-0000ABCDEF"
    s.Hover(HOGGER, { level = 11 })
    check("a hidden creature ID adds nothing", #s.lines == 0)
    s.secret = nil
    s.instance = true
    s.S.Set("scoutInstances", false)
    s.Hover(HOGGER, { level = 11 })
    check("Also in Instances off: nothing inside one", #s.lines == 0)
    s.instance = false
    s.Hover(BOAR, { level = 5 })
    check("a creature with no known abilities still gets its armor", not s.Find("Abilities") and s.Find("Armor"))
    s.S.Set("scoutAbilities", false)
    check("Creature Abilities off: the details key is not listened for", not s.Listening("MODIFIER_STATE_CHANGED"))
    s.S.Set("scout", false)
    check("Scout off: nothing listened for", not s.Listening("MODIFIER_STATE_CHANGED"))
end

do
    local s = Fixture()
    s.combat = true
    s.Login()
    check("turned on in combat: the data waits", s.unpacked == nil)
    s.Hover(HOGGER, { level = 11 })
    check("and a tooltip in combat adds nothing yet", #s.lines == 0)
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    check("after combat it unpacks", s.unpacked == 2)
    check("and stops waiting for combat to end", not s.Listening("PLAYER_REGEN_ENABLED"))
    s.Hover(HOGGER, { level = 11 })
    check("and tooltips fill in", s.Find("Pierce Armor") ~= nil)
end

do
    local s = Fixture({ scoutArmor = false, scoutImmunities = false })
    s.Login()
    s.Hover(HOGGER, { level = 11 })
    check("Armor and Immunities both off: the stats are never unpacked", s.unpacked == 2 and s.Find("Pierce Armor"))
end

print(("test-scout: %d checks passed"):format(checks))
