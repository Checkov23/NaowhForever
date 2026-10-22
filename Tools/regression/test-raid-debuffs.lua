-- Run with Lua 5.1 from the repository root: Raid Debuffs. Off, it builds no frame and listens to
-- nothing. On, it hands Blizzard's AuraContainer one HARMFUL slot per debuff, matched by every rank's
-- spell ID, over a missing icon of its own; picked debuffs get a slot in order and the rest are
-- disabled; Highlight Missing swaps which of the two looks is lit; the bar fades without an enemy
-- target or outside a raid; and nothing is built or laid out while auras are secret or in combat.

local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local none = function() end

local function Frame(kind)
    local f = { kind = kind, shown = true, events = {}, slots = {}, slotOrder = {} }
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(on) self.shown = on and true or false end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetPoint(_, _, _, x) self.x = x end
    function f:SetAllPoints(other) self.over = other end
    function f:SetScript(k, fn) self[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e, unit) self.events[e] = unit end
    function f:EnableMouse(on) self.mouse = on end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetDesaturated(on) self.desaturated = on end
    function f:SetColor(r, g, b) self.color = { r, g, b } end
    function f:SetTexture(t) self.texture = t end
    function f:SetEnabled(on) self.enabled = on end
    function f:SetUnit(unit) self.unit = unit end
    function f:UpdateAllAuras() self.rebuilt = (self.rebuilt or 0) + 1 end
    function f:GetFrameLevel() return 1 end
    function f:SetFrameLevel(level) self.level = level end
    function f:CreateTexture() return Frame("Texture") end
    function f:CreateFontString() return Frame("FontString") end
    function f:SetDurationText(_, options) self.timerOptions = options end
    function f:AddAuraSlot(key, filter, opts)
        local button = Frame("AuraButton")
        opts.initializeFrame(button)
        self.slots[key] = { filter = filter, ids = opts.candidateFilters.includeSpellIDs, enabled = true, frame = button }
        self.slotOrder[#self.slotOrder + 1] = key
        return button
    end
    function f:SetAuraSlotEnabled(key, on) self.slots[key].enabled = on end
    return setmetatable(f, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return none end
    end })
end

local function Store(values)
    local listeners = {}
    local S = { Get = function(k) return values[k] end }
    function S.Set(k, v)
        values[k] = v
        for i = 1, #listeners do listeners[i](k, v) end
    end
    function S.OnChange(fn) listeners[#listeners + 1] = fn end
    return S
end

local function Fixture(saved)
    local env = { pairs = pairs, ipairs = ipairs, type = type, math = math, table = table, next = next,
        setmetatable = setmetatable, select = select, tostring = tostring, string = string }
    local frames = {}
    env.CreateFrame = function(kind, name, parent)
        local f = Frame(kind)
        f.frameName, f.parent = name, parent
        frames[#frames + 1] = f
        return f
    end
    env.Frames = function() return #frames end
    env.Find = function(kind)
        for _, f in ipairs(frames) do
            if f.kind == kind then return f end
        end
    end
    env.Fire = function(event, ...)
        for _, f in ipairs(frames) do
            if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
        end
    end
    env.Listening = function()
        for _, f in ipairs(frames) do
            if next(f.events) and not f.events.PLAYER_LOGIN then return true end
        end
        return false
    end
    env.hooksecurefunc = function(t, key, fn)
        local orig = t[key]
        t[key] = function(...) orig(...); fn(...) end
    end
    env.combat, env.secret = false, false
    env.InCombatLockdown = function() return env.combat end
    env.C_Secrets = { ShouldAurasBeSecret = function() return env.secret end }
    env.inRaid, env.inGroup, env.hasTarget, env.hostile = true, true, true, true
    env.IsInRaid = function() return env.inRaid end
    env.IsInGroup = function() return env.inGroup end
    env.UnitExists = function() return env.hasTarget end
    env.UnitCanAttack = function() return env.hostile end
    env.issecretvalue = function(v) return v == "secret" end
    env.UIParent = Frame("Frame")
    env.Enum = { SecondsFormatterAbbreviation = {}, SecondsFormatterIntervalWhitespace = {},
        SecondsFormatterInterval = {}, SecondsFormatterRounding = {}, LuaCurveType = {},
        DurationTextBindingProperty = {} }
    env.C_StringUtil = { CreateSecondsFormatter = function()
        return setmetatable({}, { __index = function() return none end })
    end }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Apply = none,
        ShowUnlockMode = none, HideUnlockMode = none }
    ns.UIFontPath = function() return "font" end
    ns.Border = function() return Frame("Border") end
    env.pages = {}
    ns.UI = { AttachMover = function() return Frame("Mover") end,
        ModuleSettings = function(key, defaults)
            assert(key == "raidDebuffs", "Raid Debuffs' settings are its own")
            for k, v in pairs(defaults) do
                if saved[k] == nil then saved[k] = v end
            end
            return Store(saved)
        end }
    ns.Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = { ClassCrop = none },
        Settings = { Group = function(title) return { group = title } end,
            Page = function(key)
                local page = { key = key, cards = {} }
                function page.Card(p, spec) p.cards[#p.cards + 1] = spec end
                env.pages[key] = page
                return page
            end } }
    env.NaowhForever = ns
    env._G = env
    Load({ "Core/Features.lua", "Shared/UI/AuraIcon.lua" }, env)
    Load(TocFiles("^NaowhForever_Combat/RaidDebuffs/.*%.lua$"), env)
    env.Fire("PLAYER_LOGIN")
    return env, ns
end

local function ByKey(spells)
    local out = {}
    for _, entry in ipairs(spells) do out[entry.key] = entry end
    return out
end

-- The spell list
do
    local _, ns = Fixture({})
    local spells = ByKey(ns.RaidDebuffSpells)
    Check(#ns.RaidDebuffSpells >= 15, "the raid debuffs are listed")
    Check(spells.sunderArmor.ids[11597] and spells.sunderArmor.ids[7386], "Sunder Armor has its first and last rank")
    Check(spells.faerieFire.ids[770] and spells.faerieFire.ids[9907], "Faerie Fire has its ranks")
    for _, entry in ipairs(ns.RaidDebuffSpells) do
        Check(next(entry.ids) and type(entry.icon) == "number", entry.label .. " has spell IDs and an icon")
    end
end

-- Off: nothing is made or listened to.
do
    local env, ns = Fixture({})
    Check(ns.FEATURES.raidDebuffs.enabled == false, "off by default")
    Check(env.Find("AuraContainer") == nil, "off, no container is built")
    Check(not env.Listening(), "off, it listens to nothing")
    Check(env.pages["Raid Debuffs/Settings"] ~= nil, "its settings page is declared")
end

-- On: one slot per debuff, the picked ones in order over their missing icons.
do
    local env, ns = Fixture({ enabled = true })
    local container = env.Find("AuraContainer")
    Check(container and container.unit == "target", "on, a container follows the target")
    Check(#container.slotOrder == #ns.RaidDebuffSpells, "every debuff has a slot")
    local sunder = container.slots.sunderArmor
    Check(sunder.filter == "HARMFUL" and sunder.ids[11597], "a slot matches the debuff's spell IDs")
    Check(sunder.frame.aura and sunder.frame.icon and sunder.frame.over, "its button is styled and laid over its cell")
    Check(sunder.frame.mouse == false, "its button lets the mouse through, faded or not")
    Check(sunder.enabled and not container.slots.huntersMark.enabled, "picked debuffs are on, the rest off")
    local cell = sunder.frame.over
    Check(cell.shown and cell.x == 0, "the first picked debuff sits at the start")
    Check(container.slots.faerieFire.frame.over.x > 0, "the next one sits after it")
    Check(cell.icon.desaturated == true and cell.icon.alpha < 1, "missing looks dimmed")
    Check(sunder.frame.icon.alpha == 1, "a debuff that is up looks bright")
    Check(not container.slots.huntersMark.frame.over.shown, "an unpicked debuff's cell is hidden")
    Check(env.Find("AuraContainer").enabled == true, "the container is on")
    Check(env.Listening(), "on, it listens")

    ns.RaidDebuffSettings.Set("highlightMissing", true)
    Check(cell.icon.desaturated == false and cell.icon.alpha == 1, "Highlight Missing lights the missing icon")
    Check(sunder.frame.icon.alpha < 1 and sunder.frame.icon.desaturated, "and fades a debuff that is up")

    ns.RaidDebuffSettings.Set("debuff_huntersMark", true)
    Check(container.slots.huntersMark.enabled and container.slots.huntersMark.frame.over.shown,
        "picking a debuff turns its slot on")
end

-- The fade: an enemy target, in a raid.
do
    local env, ns = Fixture({ enabled = true })
    local holder = env.Find("AuraContainer").parent
    Check(holder.alpha == 1, "an enemy target in a raid shows the bar")
    env.hostile = false
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(holder.alpha == 0, "a friendly target fades it")
    Check(env.Find("AuraContainer").rebuilt == 1, "a new target rebuilds the container")
    env.hostile = "secret"
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(holder.alpha == 1, "a target the game will not say about keeps it")
    env.hostile = false
    env.Fire("UNIT_FACTION", "target")
    Check(holder.alpha == 0, "a target turning friendly fades it without a new target")
    env.hostile = true
    env.Fire("UNIT_FLAGS", "target")
    Check(holder.alpha == 1, "and turning hostile brings it back")
    env.hostile, env.inRaid = true, false
    env.Fire("GROUP_ROSTER_UPDATE")
    Check(holder.alpha == 0, "outside a raid it fades")
    ns.RaidDebuffSettings.Set("show", "always")
    Check(holder.alpha == 1, "Show Always keeps it outside a raid")
end

-- Secret auras and combat: nothing is built or laid out until they end.
do
    local env, ns = Fixture({})
    env.secret = true
    ns.RaidDebuffSettings.Set("enabled", true)
    Check(env.Find("AuraContainer") == nil, "while auras are secret the bar is not built")
    env.Fire("PLAYER_REGEN_ENABLED")
    Check(env.Find("AuraContainer") == nil, "a fight ending with auras still secret builds nothing")
    env.secret = false
    env.Fire("ADDON_RESTRICTION_STATE_CHANGED")
    Check(env.Find("AuraContainer") ~= nil, "it is built once the restriction lifts")

    env.combat = true
    ns.RaidDebuffSettings.Set("debuff_huntersMark", true)
    Check(not env.Find("AuraContainer").slots.huntersMark.enabled, "a pick made in combat waits")
    env.combat = false
    env.Fire("PLAYER_REGEN_ENABLED")
    Check(env.Find("AuraContainer").slots.huntersMark.enabled, "and lands when combat ends")

    ns.RaidDebuffSettings.Set("enabled", false)
    local holder = env.Find("AuraContainer").parent
    Check(not holder.shown and env.Find("AuraContainer").enabled == false, "turned off, the bar goes")
    Check(not env.Listening(), "and stops listening")
end

-- The settings page
do
    local env, ns = Fixture({})
    local page = env.pages["Raid Debuffs/Settings"]
    Check(#page.cards == 2 and page.cards[1].id == "bar" and page.cards[2].id == "debuffs", "two cards")
    local rows = page.cards[2].rows
    local toggles = 0
    for _, row in ipairs(rows) do
        if row.toggle then toggles = toggles + 1 end
    end
    Check(toggles == #ns.RaidDebuffSpells, "a switch per debuff")
    Check(page.cards[1].summary(ns.RaidDebuffSettings):find("^7 debuffs"), "the summary counts the picked debuffs")
end

print(("test-raid-debuffs: %d checks passed"):format(checks))
