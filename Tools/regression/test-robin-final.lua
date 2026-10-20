-- Run with Lua 5.1 from the repository root. Hardware actions are recorded, not executed.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local TocFiles = dofile('Tools/regression/toc_files.lua')
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local function fixture(kind)
    local state = { combat = false, secret = false, now = 1000, bags = { 101, 202, 101, 303 },
        settings = { gearSets = true, gearBarVisible = false, trinketBar = true,
            trinketSize = 36, trinketSpacing = 4, gearBarSize = 32, gearBarSpacing = 4, gearBarShow = 'always' },
        frames = {}, named = {}, timers = {}, equips = {} }
    local function frame(name, parent, template)
        local f = { scripts = {}, events = {}, shown = true, parent = parent, attributes = {},
            secure = template == 'SecureActionButtonTemplate' or name == 'NaowhForeverTrinkets' }
        local noop = function() end
        setmetatable(f, { __index = function(_, key) if key ~= 'sitSpot' and key ~= 'hot' then return noop end end })
        function f:SetScript(key, fn) self.scripts[key] = fn end
        function f:HookScript(key, fn)
            local old = self.scripts[key]
            self.scripts[key] = function(...) if old then old(...) end; fn(...) end
        end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:RegisterUnitEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
        function f:SetShown(v) if v then self:Show() else self:Hide() end end
        function f:IsShown() return self.shown end
        function f:SetSize(w, h)
            assert(not (self.secure and state.combat), 'layout changed in combat')
            self.width, self.height = w, h
        end
        function f:SetPoint(...) self.point = { ... } end
        function f:SetTexture(v) self.texture = v end
        function f:SetColorTexture(...) self.color = { ... } end
        function f:SetVertexColor(...) self.color = { ... } end
        function f:SetText(v) self.text = v end
        function f:SetFont(...) self.font = { ... } end
        function f:SetDrawSwipe(v) self.swipe = v end
        function f:SetCooldown(start, duration) self.cooldown = { start, duration } end
        function f:SetAttribute(key, value)
            assert(not state.combat, 'secure attribute changed in combat')
            self.attributes[key] = value
        end
        function f:CreateTexture() return frame(nil, self) end
        function f:CreateMaskTexture() return frame(nil, self) end
        state.frames[#state.frames + 1] = f
        if name then state.named[name] = f end
        return f
    end
    local S = { Get = function(k) return state.settings[k] end,
        Set = function(k, v) state.settings[k] = v end, OnChange = function() end }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), QoLSettings = S, Apply = function() end, Print = function() end,
        ShowUnlockMode = function() end, HideUnlockMode = function() end,
        THEME = { bg = {}, accent = { r = 0, g = 1, b = 1 }, accentSoft = {} },
        UIFontPath = function() return 'font' end,
        Border = function() return frame() end, Solid = function() return frame() end,
        PixelInset = function(region) return region end,
        ThemeTint = function(_, literal) return literal end,
        Shared = { Style = { TIME_OK_RGB = {}, TIME_LOW_RGB = {}, TIME_OUT_RGB = {} }, Items = { SLEEPING_BAG = 211527 },
            Parts = { Smooth = function(t) return t end, HudText = function(t) return t end,
                Pill = function() return frame() end, SetPill = function() return 0 end, ColorPill = function() end,
                Press = function(button) button.pressed = true end,
                HudFont = function(fs, font, size, outline) fs:SetFont(font, size, outline) end } },
        Font = function() return frame() end, Tooltip = function() end,
        Button = function(parent, text, w, h, callback)
            local f = frame(nil, parent); f.scripts.OnClick = callback; return f
        end,
        UI = { STATUS = {}, AttachMover = function() return frame() end,
            ModuleSettings = function(_, defaults)
                for key, value in pairs(defaults) do
                    if state.settings[key] == nil then state.settings[key] = value end
                end
                return S
            end },
    }
    local env = { _G = { NaowhForever = ns }, UIParent = {}, NUM_BAG_SLOTS = 0,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        CreateFrame = function(_, name, parent, template) return frame(name, parent, template) end,
        InCombatLockdown = function() return state.combat end,
        GetTime = function() return state.now end,
        IsInInstance = function() return false end,
        IsMounted = function() return false end, IsResting = function() return false end,
        GetInventoryItemTexture = function(_, slot) return slot + 1000 end,
        GetInventoryItemID = function(_, slot) return slot + 2000 end,
        C_Secrets = { ShouldAurasBeSecret = function() return state.secret end },
        LibStub = function() return { PixelGlow_Start = function() end, PixelGlow_Stop = function() end } end,
        C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
            assert(not state.combat and not state.secret, 'restricted aura read')
            return state.auras and state.auras[id]
        end },
        C_TooltipInfo = { GetUnitBuffByAuraInstanceID = function() return { lines = {
            { leftText = 'Camp Benefits' }, { leftText = 'Tent: Rested XP\nMana Well: 10 MP5' },
            { leftText = 'Spell ID: 1229741' }, { leftText = '20 |4minute:minutes;' },
        } } end },
        C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
        C_EquipmentSet = { GetEquipmentSetIDs = function() return {} end },
        C_Container = {
            GetContainerNumSlots = function() return #state.bags end,
            GetContainerItemID = function(_, slot) return state.bags[slot] end,
        },
        C_Item = {
            GetItemInfoInstant = function(id) return id, nil, nil, id == 303 and 'INVTYPE_HEAD' or 'INVTYPE_TRINKET' end,
            GetItemIconByID = function(id) return id end,
            GetItemCount = function() return 0 end,
            EquipItemByName = function(id, slot)
                assert(not state.combat); state.equips[#state.equips + 1] = { id, slot }
            end,
        },
        hooksecurefunc = function(t, key, callback)
            local orig = t[key]; t[key] = function(...) orig(...); callback(...) end
        end,
    }
    setmetatable(env, { __index = _G })
    function state.load(path)
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
    end
    state.load('Shared/UI/ItemBar.lua')
    function state.loadModule(dir)
        for _, path in ipairs(TocFiles("^" .. dir .. "/.*%.lua$")) do state.load(path) end
    end
    function state.fire(event)
        local copy = {}; for i, f in ipairs(state.frames) do copy[i] = f end
        for _, f in ipairs(copy) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end end
    end
    state.ns, state.S = ns, S
    return state
end

do
    local s = fixture('gear')
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    check('hidden set bar stays hidden', not s.named.NaowhForeverGearBar.shown)
    local swaps = false
    for _, f in ipairs(s.frames) do if f.events.PLAYER_MOUNT_DISPLAY_CHANGED then swaps = true end end
    check('hidden set bar keeps automatic swaps', swaps)
    local bar = s.named.NaowhForeverTrinkets
    check('two trinket slots', #bar.buttons == 2)
    check('secure use top slot', bar.buttons[1].attributes.item1 == '13')
    check('secure use bottom slot', bar.buttons[2].attributes.item1 == '14')
    bar.buttons[2].scripts.PostClick(bar.buttons[2], 'RightButton', false)
    local picker
    for _, f in ipairs(s.frames) do if type(rawget(f, 'buttons')) == 'table' and rawget(f, 'close') then picker = f end end
    check('deduplicates trinkets and excludes armor', #picker.buttons == 2)
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    check('uses selected destination slot', s.equips[1][1] == 101 and s.equips[1][2] == 14)
    bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    s.bags = {}
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    check('stale bag selection is refused', #s.equips == 1)
    s.bags = { 101 }; bar.buttons[1].scripts.PostClick(bar.buttons[1], 'RightButton', false)
    s.fire('PLAYER_REGEN_DISABLED'); s.combat = true
    check('combat closes picker', not picker.shown)
    picker.buttons[1].scripts.OnClick(picker.buttons[1])
    s.S.Set('trinketSize', 50); s.ns.Apply()
    check('combat blocks equips and layout', #s.equips == 1 and bar.buttons[1].width == 36)
    s.combat = false; s.fire('PLAYER_REGEN_ENABLED')
    check('deferred settings apply', bar.buttons[1].width == 50)
end

do
    local s = fixture('gear')
    s.settings.trinketBar = false
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    local function Listening(e)
        for _, f in ipairs(s.frames) do if f.events[e] then return f end end
    end
    check('trinket bar off: no combat events of its own', not Listening('PLAYER_REGEN_DISABLED'))
    s.S.Set('trinketBar', true)
    local watcher = Listening('PLAYER_REGEN_DISABLED')
    check('trinket bar on: it listens', watcher and watcher.events.PLAYER_EQUIPMENT_CHANGED)
    local bar = s.named.NaowhForeverTrinkets
    bar.buttons[1].width = nil
    watcher.scripts.OnEvent(watcher, 'PLAYER_EQUIPMENT_CHANGED', 5)
    check('another slot changing leaves the trinkets alone', rawget(bar.buttons[1], 'width') == nil)
    watcher.scripts.OnEvent(watcher, 'PLAYER_EQUIPMENT_CHANGED', 13)
    check('a trinket slot changing redraws them', bar.buttons[1].width == 36)
    s.S.Set('trinketBar', false)
    check('switched off again: it stops listening', not watcher.events.PLAYER_REGEN_DISABLED
        and not watcher.events.PLAYER_EQUIPMENT_CHANGED and not watcher.events.PLAYER_REGEN_ENABLED)
end

do
    local s = fixture('gear')
    s.settings.gearBarVisible, s.settings.gearBarShow, s.settings.trinketBar = true, 'nocombat', false
    s.loadModule('NaowhForever_Combat/GearSets'); s.fire('PLAYER_LOGIN')
    local bar = s.named.NaowhForeverGearBar
    check('Show Out of Combat: shown out of combat', bar.shown)
    s.fire('PLAYER_REGEN_DISABLED'); s.combat = true
    check('and hidden as a fight starts', not bar.shown)
    s.combat = false; s.fire('PLAYER_REGEN_ENABLED')
    check('and back after it', bar.shown)
    check('4px between buttons by default', bar.width == 36)
    s.S.Set('gearBarSpacing', 10)
    check('Spacing widens the gaps', bar.width == 42)
    s.S.Set('gearBarShow', 'combat')
    check('Show In Combat: hidden out of combat', not bar.shown)
    s.fire('PLAYER_REGEN_DISABLED')
    check('shown in one', bar.shown)
    s.fire('PLAYER_REGEN_ENABLED')
    s.S.Set('gearBarShow', 'always')
    local listens = false
    for _, f in ipairs(s.frames) do if f.events.PLAYER_REGEN_DISABLED then listens = true end end
    check('Show Always: shown, with no combat event of its own', bar.shown and not listens)
end

do
    local s = fixture('camp')
    s.load('Core/Features.lua'); s.load('NaowhForever_Combat/AuraBuffs/AuraBuffs.lua')
    s.load('NaowhForever_Combat/AuraBuffs/Constants.lua')
    local parse = s.ns.ParseConsumableEntry
    check('explicit item and buff IDs parse', parse('food', '123, 456, 789').auras[2] == 789)
    local alone = parse('food', '123')
    check('item alone parses without buff IDs', alone.itemID == 123 and alone.auras == nil)
    check('invalid category rejected', not parse('other', '123 456'))
    local list = s.ns.ConsumableListString({ { category = 'battle', itemID = 13454, auras = { 17539 } },
        { category = 'food', itemID = 13931 }, { category = 'food', itemID = 2680 } })
    check('list string groups by category, buff IDs kept', list == 'NFCONSUMABLES1:food=13931,2680;battle=13454/17539')
    local back = s.ns.ParseConsumableList(list)
    check('list string reads back', #back == 3 and back[3].auras[1] == 17539 and back[1].auras == nil)
    check('damaged list rejected', not s.ns.ParseConsumableList('NFCONSUMABLES1:food=13931,x')
        and not s.ns.ParseConsumableList('NFCONSUMABLES1:food13931'))
    s.ns.DecodeProfile = function() return { parts = { consumables = { { category = 'flask', itemID = 13510 } } } } end
    check('profile string gives its consumables', s.ns.ParseConsumableList('NFPROFILE1:x')[1].itemID == 13510)
    ---@diagnostic disable-next-line: duplicate-set-field
    s.ns.DecodeProfile = function() return nil end
    check('anything else holds no list', not s.ns.ParseConsumableList('hello'))
    check('invalid IDs rejected', not parse('food', '123, x') and not parse('food', '0, 1'))
    s.S.Set('campShowUnder', false)
    for _, file in ipairs({ 'Data/Campfire.lua', 'CampReader.lua', 'View/Style.lua', 'View/Glow.lua', 'View/CampIcon.lua',
        'View/CampBar.lua', 'View/CampAlert.lua', 'UI/CampBag.lua', 'UI/Campfire.lua', 'UI/CampfireCards.lua' }) do
        s.load('NaowhForever_Combat/AuraBuffs/' .. file)
    end
    s.fire('PLAYER_LOGIN')
    local icon = s.named.NaowhForeverCampfire
    check('no icon swipe', icon.timer.swipe == false)
    check('missing shown by default', icon.shown)
    s.S.Set('campShowMissing', false)
    check('missing can be hidden', not icon.shown)
    s.auras = { [1229739] = { duration = 60, expirationTime = 1060 } }
    s.fire('UNIT_AURA')
    check('sitting label is Resting', icon.label.text == 'Resting' and icon.shown)
    s.auras = { [1229741] = { duration = 3600, expirationTime = 2200, auraInstanceID = 1 } }
    s.fire('UNIT_AURA')
    check('effects instead of objects', icon.buffs.text == '+Rested\n+MP5')
    s.S.Set('campBuffSide', 'right'); s.S.Set('campBuffTextSize', 20)
    check('buff text position and size', icon.buffs.point[1] == 'LEFT' and icon.buffs.font[2] == 20)
    s.S.Set('campShowUnder', true); s.S.Set('campShowUnderMinutes', 1)
    check('one-minute threshold hides healthy camp', not icon.shown)
    s.combat = true; s.fire('UNIT_AURA'); s.combat = false
    s.secret = true; s.fire('UNIT_AURA')
    check('restricted aura access skipped', true)
end
do
    local s = fixture('profile')
    local active = {}
    s.ns.DB = function() return active end
    s.load('Core/Features.lua'); s.load('NaowhForever_Combat/AuraBuffs/AuraBuffs.lua')
    s.load('NaowhForever_Combat/AuraBuffs/Constants.lua')
    local entry = { category = "food", itemID = 123, auras = { 456 } }
    s.S.Set("consumableEntries", { entry })
    check('editor writes profile-backed definitions', active.utilityReminders.consumables[1] == entry)
    active = {}
    check('profile change clears previous definitions', #s.S.Get("consumableEntries") == 0)
    local m = fixture('profile')
    m.ns.DB = function() return active end
    m.load('Core/Features.lua')
    m.load('NaowhForever_Utilities/Macros/Macros.lua')
    m.S.Set("classMacros", { PALADIN = { { name = "Test", body = "/say test" } } })
    check('class macros use profile-backed data', active.utilityReminders.classMacros.PALADIN[1].name == "Test")
    active = {}
    check('class macros follow active profile', next(m.S.Get("classMacros")) == nil)
end
print(checks .. ' final-video regressions passed')
