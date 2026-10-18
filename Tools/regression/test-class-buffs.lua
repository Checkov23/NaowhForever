-- Offline lifecycle tests; these do not simulate Blizzard's managed aura rendering.
local function Fixture(class, known)
    local state = { combat = false, secret = false, auraReads = 0, auras = {}, frames = {}, containers = {}, messages = {} }
    local settings = { enabled = true, classBuffTracker = false, classBuffSize = 40,
        classBuffGlow = false, personalBuffPicks = {}, raidBuffPicks = { blessing = false } }
    local listeners = {}
    local S = {
        Get = function(key) return settings[key] end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
        Set = function(key, value)
            settings[key] = value
            for _, fn in ipairs(listeners) do fn(key) end
        end,
    }
    local function Noop() end
    local function Frame(kind, name, _, template)
        local f = { kind = kind, name = name, events = {}, attributes = {}, template = template }
        function f:RegisterForClicks(...) self.clicks = { ... } end
        function f:SetAttribute(key, value)
            assert(not state.combat, "secure attributes must not change in combat")
            self.attributes[key] = value
        end
        function f:SetText(text) self.text = text end
        function f:SetWordWrap() end
        function f:SetWidth(width) self.width = width end
        function f:GetUnboundedStringWidth() return #(self.text or "") * 6 end
        function f:SetScript(key, fn) self[key] = fn end
        function f:RegisterUnitEvent(event) self.events[event] = true end
        function f:RegisterEvent(event) self.events[event] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:IsShown() return self.shown end
        function f:Hide()
            self.hides = (self.hides or 0) + 1
            local shown = self.shown
            self.shown = false
            if shown and self.OnHide then self.OnHide(self) end
        end
        function f:Show() self.shown = true end
        function f:SetShown(on) self.shown = on end
        function f:SetEnabled(on) assert(not state.combat); self.enabled = on end
        function f:SetUnit(unit) self.unit = unit end
        function f:GetFrameLevel() return 1 end
        function f:AddAuraSlot(key, filter, options)
            assert(not state.combat)
            if state.unavailable then error("unavailable") end
            self.slot, self.filter, self.options = key, filter, options
            options.initializeFrame(Frame("managed"))
        end
        function f:CreateTexture() return Frame("texture") end
        function f:SetDurationText() error("tracker must not bind number text") end
        function f:SetIcon(icon) self.icon = icon end
        f.SetDesaturated, f.SetAlpha, f.SetAllPoints = Noop, Noop, Noop
        f.SetFrameLevel, f.EnableMouse, f.SetTexCoord = Noop, Noop, Noop
        f.SetPoint, f.ClearAllPoints, f.SetMovable, f.SetClampedToScreen = Noop, Noop, Noop, Noop
        state.frames[#state.frames + 1] = f
        if kind == "AuraContainer" then state.containers[#state.containers + 1] = f end
        return f
    end
    local ns = {
        Apply = function() end, ShowUnlockMode = function() end, HideUnlockMode = function() end,
        PixelInset = function(icon, inset) icon.inset = inset end,
        L = function(s) return s end, Font = function() return Frame("text") end,
        Print = function(s) state.messages[#state.messages + 1] = s end,
        AuraBuffs = { Settings = S, PAGE = "AuraBuffs/Settings", Style = { BUFF_CROP = 0.07, BUFF_GAP = 4 },
            Glow = { Set = function(cell, on) cell.glowing = on and true or false end },
            GlowRows = function() return {} end },
        Shared = { Parts = { HudFont = function() end }, Style = { ICON_CROP = 0.08 }, Settings = { Page = function() return { Card = function(_, card) state.card = card end } end } },
        UI = { AttachMover = function() return Frame("mover") end },
    }
    ns.AuraBuffs.BuffCell = {
        New = function(_, template)
            local f = Frame("cell", nil, nil, template); f.icon = Frame("texture"); return f
        end,
        Place = function(cell, _, index, size, icon, count)
            assert(count == nil, "texture API secondary return must not become an icon count")
            assert(not state.combat); cell.index, cell.size, cell.texture = index, size, icon
        end,
        Fit = function(_, count) assert(not state.combat); state.count = count end,
    }
    local env = setmetatable({ NaowhForever = ns, UIParent = {}, CreateFrame = Frame,
        GameTooltip = {
            SetOwner = function(_, cell) state.tooltipOwner = cell end,
            IsOwned = function(_, cell) return state.tooltipOwner == cell and state.tooltipShown end,
            SetSpellByID = function(_, spell) state.tooltipSpell = spell end,
            Show = function() state.tooltipShown = true end,
            Hide = function() state.tooltipShown = false end,
        },
        InCombatLockdown = function() return state.combat end,
        UnitClass = function() assert(not state.combat); return class, class end,
        GetNumGroupMembers = function() return state.groupSize or 0 end,
        C_AddOns = { LoadAddOn = function() assert(not state.combat) end },
        C_SpellBook = { IsSpellKnown = function(id) assert(not state.combat); return known[id] end },
        C_Spell = { GetSpellName = function(id) return "Spell " .. id end, GetSpellTexture = function(id) return id, id + 100000 end },
        C_Secrets = { ShouldAurasBeSecret = function() return state.secret end },
        geterrorhandler = function() return function(err) state.error = err end end,
        wipe = function(t) for key in pairs(t) do t[key] = nil end end,
        issecretvalue = function(v) return v == state.secretValue and v ~= nil end,
        C_UnitAuras = { GetAuraDataByIndex = function(_, i)
            assert(not state.combat and not state.secret, "must not read restricted auras")
            state.auraReads = state.auraReads + 1
            return state.auras[i]
        end },
        hooksecurefunc = function(target, key, hook)
            local old = target[key]
            target[key] = function(...) old(...); hook(...) end
        end,
    }, { __index = _G })
    env._G = env
    -- Existing data needs only the shared consumable lists at load time.
    ns.WELL_FED, ns.FOOD_SPELLS = {}, {}
    local data = assert(loadfile("NaowhForever_Combat/AuraBuffs/Data/BuffReminders.lua"))
    setfenv(data, env); data()
    local code = assert(loadfile("NaowhForever_Combat/AuraBuffs/UI/ClassBuffs.lua"))
    setfenv(code, env); code()
    state.settings, state.ns = S, ns
    function state:Event(event)
        for _, f in ipairs(self.frames) do
            if f.events[event] then f.OnEvent(f, event) end
        end
    end
    return state
end

local paladin = Fixture("PALADIN", { [19740] = true, [1038] = true })
paladin.groupSize = 2
paladin.settings.Set("raidBuffPicks", { blessing = true, salvation = true })
paladin.settings.Set("classBuffTracker", true)
assert(paladin.count == 2, "selected paladin buffs show with the filter off")
paladin.settings.Set("hideBlessingsOnPaladin", true)
assert(paladin.count == 0, "grouped paladin hides blessing slots immediately")
paladin.groupSize = 0
paladin:Event("GROUP_ROSTER_UPDATE")
assert(paladin.count == 2, "leaving a group restores paladin self-buff slots")
paladin.groupSize = 2
paladin:Event("GROUP_ROSTER_UPDATE")
assert(paladin.count == 0, "joining a group hides the self-buff slots again")
paladin.settings.Set("hideBlessingsOnPaladin", false)
assert(paladin.count == 2, "turning the filter off restores paladin self-buff slots")
paladin.combat = true
paladin.settings.Set("hideBlessingsOnPaladin", true)
assert(paladin.count == 2, "changing the filter in combat holds the secure slots")
paladin.combat = false
paladin:Event("PLAYER_REGEN_ENABLED")
assert(paladin.count == 0, "the filter applies after combat ends")
paladin.combat, paladin.groupSize = true, 0
paladin:Event("GROUP_ROSTER_UPDATE")
assert(paladin.count == 0, "leaving the group in combat waits to restore secure slots")
paladin.combat = false
paladin:Event("PLAYER_REGEN_ENABLED")
assert(paladin.count == 2, "the solo slots restore after combat ends")

local s = Fixture("MAGE", { [168] = true, [1459] = true })
assert(#s.frames == 0, "off creates no frames")
s.ns.Apply()
assert(#s.frames == 0, "global apply while off creates no frames")
s.settings.Set("classBuffTracker", true)
assert(#s.messages == 0 and s.count == 2, "known personal and raid buffs get slots")
assert(s.containers[1].options.candidateFilters.includeSpellIDs[168], "all armor ranks configured")
assert(s.containers[2].options.candidateFilters.includeSpellIDs[23028], "group intellect rank configured")
for _, c in ipairs(s.containers) do assert(c.unit == "player" and c.enabled) end
local spells = {}
for _, f in ipairs(s.frames) do
    if f.kind == "cell" then
        assert(f.template == "SecureActionButtonTemplate", "clickable buff uses secure template")
        assert(f.attributes.type1 == "spell" and f.attributes.unit1 == "player", "self-cast action")
        assert(f.clicks[1] == "AnyUp" and f.clicks[2] == "AnyDown", "both click timings registered")
        spells[f.attributes.spell1] = true
    end
end
assert(spells[168] and spells[1459], "known buff spells assigned")
local cell
for _, f in ipairs(s.frames) do if f.kind == "cell" then cell = f; break end end
cell.OnEnter(cell)
assert(s.tooltipOwner == cell and s.tooltipSpell == 168 and s.tooltipShown, "native tooltip shows actual spell")
cell.OnLeave(cell)
assert(not s.tooltipShown, "tooltip closes on leave")
assert(cell.icon.inset == 1, "same pixel inset as Blessings")
s.settings.Set("classBuffGlow", true)
assert(cell.glowing, "missing buff glows without mouseover")
local hidesBefore = cell.hides or 0
s.ns.ShowUnlockMode()
assert(cell.glowing, "opening settings/mover mode keeps missing-buff glow")
s.ns.HideUnlockMode()
assert(cell.glowing, "closing settings keeps missing-buff glow")
assert((cell.hides or 0) == hidesBefore, "opening and closing settings must not hide/rebuild buff cells")
s.auras = { { spellId = 999 } }
s.auraReads = 0
s:Event("UNIT_AURA")
assert(s.auraReads == 2, "an aura change that hides nothing is one scan for every slot")
s.auras = { { spellId = 168, sourceUnit = "player" } }
s:Event("UNIT_AURA")
assert(not cell.shown and s.count == 1, "an active buff's slot goes away and the rest close up")
assert(not cell.glowing, "applying buff stops glow")
s.ns.ShowUnlockMode()
assert(cell.shown and s.count == 2, "Unlock Mode shows every slot to place the row")
s.ns.HideUnlockMode()
assert(not cell.shown and s.count == 1, "and hides the active one again after")
s.auras = {}
for i = 1, 42 do s.auras[i] = { spellId = 900000 + i } end
s.auras[43] = { spellId = 168, sourceUnit = "player" }
s:Event("UNIT_AURA")
assert(not cell.glowing, "buff beyond the old 40-aura limit is detected")
s.secretValue = {}
s.auras = { { spellId = s.secretValue } }
s:Event("UNIT_AURA")
assert(not cell.glowing, "unreadable aura suppresses glow")
s.secretValue = nil
s.auras = {}
s:Event("UNIT_AURA")
assert(cell.shown and s.count == 2, "a buff that drops shows its slot again")
assert(cell.glowing, "removing buff restarts glow")
s.secret = true
s:Event("UNIT_AURA")
assert(not cell.glowing, "restricted auras suppress glow before lockdown")
s.secret = false
s:Event("UNIT_AURA")
assert(cell.glowing)
s:Event("PLAYER_REGEN_DISABLED")
assert(not cell.glowing, "combat event suppresses glow before lockdown flag changes")
s.combat = true
s.auras = { { spellId = 168, sourceUnit = "player" } }
s.auraReads = 0
s:Event("UNIT_AURA")
assert(cell.shown and s.auraReads == 0, "in combat the row holds and no aura is read")
s.combat = false
s:Event("PLAYER_REGEN_ENABLED")
assert(not cell.shown and s.count == 1, "after combat a buff gained during it hides its slot")
s.auras = {}
s:Event("UNIT_AURA")
assert(cell.shown, "and its slot comes back when it drops")
s:Event("PLAYER_REGEN_DISABLED")
s.combat = true
s:Event("SPELLS_CHANGED")
s.settings.Set("classBuffTracker", false)
for _, c in ipairs(s.containers) do assert(c.enabled, "combat disable deferred") end
s.combat = false
s:Event("PLAYER_REGEN_ENABLED")
for _, c in ipairs(s.containers) do assert(not c.enabled, "disabled after combat") end
for _, f in ipairs(s.frames) do assert(next(f.events) == nil, "off unregisters events") end
s.settings.Set("personalBuffPicks", { mageArmor = false })
s.settings.Set("classBuffTracker", true)
assert(s.count == 1 and #s.containers == 2, "picks honored and containers reused")
s.settings.Set("enabled", false)
for _, c in ipairs(s.containers) do assert(not c.enabled) end

local hunter = Fixture("HUNTER", { [13165] = true, [1130] = true })
hunter.combat = true
hunter.settings.Set("classBuffTracker", true)
assert(#hunter.containers == 0, "first combat enable waits")
hunter.combat = false
hunter:Event("PLAYER_REGEN_ENABLED")
assert(hunter.count == 1, "target debuffs excluded")
assert(hunter.containers[1].options.candidateFilters.isFromPlayerOrPlayerPet, "own aspect filter")
hunter.settings.Set("classBuffGlow", true)
hunter.auras = { { spellId = 13165, sourceUnit = "party1" } }
hunter:Event("UNIT_AURA")
local hunterCell
for _, f in ipairs(hunter.frames) do if f.kind == "cell" then hunterCell = f end end
assert(hunterCell.glowing, "another hunter's aspect does not satisfy own-buff check")
hunter.auras[1].sourceUnit = "player"
hunter:Event("UNIT_AURA")
assert(not hunterCell.glowing, "own aspect stops glow")
hunter.secretValue = {}
hunter.auras[1].sourceUnit = hunter.secretValue
hunter:Event("UNIT_AURA")
assert(not hunterCell.glowing, "unknown caster suppresses own-buff warning")
local rogue = Fixture("ROGUE", { [2842] = true })
rogue.settings.Set("classBuffTracker", true)
assert(rogue.count == 0 and #rogue.containers == 0, "weapon enchants excluded")
local bad = Fixture("MAGE", { [168] = true })
bad.unavailable = true
bad.settings.Set("classBuffTracker", true)
assert(#bad.messages == 1 and bad.error, "unsupported display reports once and preserves error detail")
bad.ns.Apply()
assert(#bad.messages == 1, "no retry loop")
local starts, stops, procLayers = {}, {}, {}
local lib = {}
for _, kind in ipairs({ "Proc", "Pixel", "Button" }) do
    lib[kind .. "Glow_Start"] = function(_, options)
        starts[kind] = (starts[kind] or 0) + 1
        if kind == "Proc" then
            assert(options.startAnim == false, "gold glow skips the opening flash")
            procLayers[options.key or ""] = options
        end
    end
    lib[kind .. "Glow_Stop"] = function(_, key)
        stops[kind] = (stops[kind] or 0) + 1
        if kind == "Proc" then procLayers[key or ""] = nil end
    end
end
local glowSettings = { Type = "proc", Color = { r = 1, g = 0.82, b = 0.2 },
    Lines = 8, Thickness = 1, Speed = 5 }
local glowNs = { AuraBuffs = { Settings = { Get = function(key) return glowSettings[key:sub(5)] end } } }
local glowEnv = setmetatable({ NaowhForever = glowNs, LibStub = function() return lib end }, { __index = _G })
glowEnv._G = glowEnv
local glowCode = assert(loadfile("NaowhForever_Combat/AuraBuffs/View/Glow.lua"))
setfenv(glowCode, glowEnv); glowCode()
local glow = glowNs.AuraBuffs.Glow
local target = { GetWidth = function() return 40 end }
glow.Set(target, true, "test")
glow.Set(target, true, "test")
assert(starts.Proc == 1, "unchanged glow is not restarted")
glowSettings.Thickness = 3
glow.Set(target, true, "test")
assert(starts.Proc == 4 and stops.Proc == 1, "thicker glow replaces the old outline")
assert(procLayers.thickness2.xOffset == 0.5 and procLayers.thickness3.yOffset == 1,
    "gold layers widen the outline in half-unit steps")
glow.Set(target, true, "test")
assert(starts.Proc == 4, "unchanged layered glow is not restarted")
glowSettings.Thickness = 1
glow.Set(target, true, "test")
assert(stops.Proc == 4 and not procLayers.thickness2 and not procLayers.thickness3,
    "reducing thickness removes every surplus layer")
glowSettings.Thickness = 100
glow.Set(target, true, "test")
local layerCount = 0
for _ in pairs(procLayers) do layerCount = layerCount + 1 end
assert(layerCount == 6, "imported thickness cannot create unbounded glow layers")
glowSettings.Type = "pixel"
glow.Set(target, true, "test")
assert(stops.Proc == 11 and next(procLayers) == nil and starts.Pixel == 1, "changing style stops every gold layer")
glowSettings.Type = "standard"
glow.Set(target, true, "test")
assert(stops.Pixel == 1 and starts.Button == 1, "existing standard glow dispatch preserved")
glow.Set(target, false)
assert(stops.Button == 1, "turning glow off stops the current style")
glowNs.L = function(text) return text end
glowNs.Shared = { Settings = {} }
local rowsCode = assert(loadfile("NaowhForever_Combat/AuraBuffs/UI/GlowRows.lua"))
setfenv(rowsCode, glowEnv); rowsCode()
glowSettings.Type = "proc"
local rows = glowNs.AuraBuffs.GlowRows("test", function() return true end, glow.TRACKER_TYPES)
assert(not rows[4].hidden() and rows[3].hidden() and rows[5].hidden(),
    "gold exposes thickness while pixel-only controls stay hidden")
glowSettings.Type = "standard"
assert(rows[4].hidden(), "standard glow keeps its original controls")
glowSettings.Type = "pixel"
assert(not rows[4].hidden(), "pixel thickness remains available")
print("Class buff tracker lifecycle and glow dispatch tests passed")
