-- Offline behavior checks for the Consumable Bar (NaowhForever_Combat/ConsumableBar, on Shared/UI/ItemBar.lua
-- and Shared/UI/Anchor.lua); these do not emulate client taint, secure clicks, state drivers' secure
-- side or rendering. Run from the repo root: lua Tools/regression/test-consumable-bar.lua
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })

-- The Consumable Bar's defaults, as Core/Settings.lua declares them.
local DEFAULTS = (function()
    local f = assert(io.open('Core/Settings.lua', 'rb'))
    local settings = f:read('*a'):gsub('\r\n', '\n')
    f:close()
    local block = settings:match('\n(    consumableBar = F%.consumableBar.-consumableBarY = 0,)\n')
    local chunk = assert(loadstring('return {\n' .. block .. '\n}'))
    setfenv(chunk, { F = { consumableBar = false } })
    local defaults = chunk()
    defaults.enabled = true
    return defaults
end)()
-- Most checks lay out items they have none of; the ones about Hide When Out switch it on themselves.
local SHIPPED_HIDE_EMPTY = DEFAULTS.consumableBarHideEmpty
DEFAULTS.consumableBarHideEmpty = false
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

-- itemID -> { icon, classID, use spell }
local KNOWN = {
    [13446] = { 134830, 0, 17534, 1 },   -- Major Healing Potion
    [5512] = { 135230, 0, 6262, 8 },     -- Healthstone
    [20007] = { 134735, 0, 17535, 2 },   -- an elixir
    [12404] = { 135249, 0, 16138 },   -- a sharpening stone
    [2589] = { 132889, 7, nil, 0 },   -- Linen Cloth, not a consumable
    [18641] = { 133714, 7, 23063, 2 }, -- Dense Dynamite: Trade Goods, Explosives
    [10587] = { 133001, 7, 12543, 3 }, -- Goblin Bomb Dispenser: Trade Goods, Devices
    [4359] = { 133594, 7, nil, 1 },   -- Handful of Bronze Bolts: Trade Goods, Parts
    [10307] = { 134937, 0, 12178, 4 }, -- Scroll of Stamina IV
    [7146] = { 134939, 0, 8902, 4 },   -- a Scroll that gives no buff
    [8932] = { 133948, 0, 433, 5 },   -- Alterac Swiss
    [14530] = { 133690, 0, 18610, 7 }, -- Heavy Runecloth Bandage
    [2862] = { 135248, 7, 2828, 0 },  -- Rough Sharpening Stone, filed as a trade good here
    [5509] = { 135230, 0, 6263, 8 },  -- Healthstone, Other Consumables
    [21023] = { 134021, 0, 24869, 5 }, -- Dirge's Kickin' Chimaerok Chops: eating, then Well Fed
    [17202] = { 132387, 0, 21343, 8 }, -- Snowball, Other Consumables
}

-- Food and drink by the spell they cast, as Shared/Game/Consumables.lua reads them.
local SPELL_NAMES = { [8932] = 'Food', [21023] = 'Food', [8766] = 'Drink', [1179] = 'Drink' }
KNOWN[8766] = { 132794, 0, 1135, 5 }   -- Morning Glory Dew
KNOWN[1179] = { 132794, 0, 430, 5 }    -- Ice Cold Milk
KNOWN[13444] = { 134854, 0, 17531, 1 } -- Major Mana Potion

local function fixture(settings, noMacros, class)
    local s = { level = 60, levels = {}, missing = {}, frames = {}, combat = false, counts = {}, cooldowns = {}, auras = {},
        settings = settings or {}, built = 0, blocked = 0, now = 100, timers = {},
        secretAuras = false, auraReads = 0, bags = {}, focus = {}, mouseDown = false,
        enchant = {}, actions = {}, actionButtons = {}, bindings = {}, macros = {}, labButtons = nil,
        refreshes = 0, registers = 0, cards = {}, actionText = {}, macroBodies = {}, macroSettings = {},
        macroUpdates = 0, macroListeners = {}, writes = {}, panels = {}, stores = {}, windows = {}, renders = {}, sides = {}, hud = { anchoredTo = {} } }
    local G = {}
    local function Evaluate(f)
        local rule = rawget(f, 'driver')
        if rule == '[combat] hide; show' then f.shown = not s.combat
        elseif rule == '[combat] show; hide' then f.shown = s.combat end
    end
    local function frame(kind, name, parent, template)
        local f = { kind = kind, scripts = {}, events = {}, shown = true, parent = parent,
            template = template, attrs = {}, level = 1, alpha = 1, mouse = true, scale = 1 }
        -- Methods the bar does not care about are no-ops; a missing field is nil, as on a frame.
        setmetatable(f, { __index = function(_, k) if k:match('^%u') then return function() end end end })
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:HookScript(k, fn)
            local old = self.scripts[k]
            self.scripts[k] = function(...)
                if old then old(...) end
                fn(...)
            end
        end
        function f:RegisterEvent(k) self.events[k] = true end
        function f:RegisterUnitEvent(k) self.events[k] = true end
        function f:UnregisterAllEvents()
            self.events = {}
            s.applies = (s.applies or 0) + 1
        end
        function f:Show() self.shown = true end
        function f:Hide()
            local was = self.shown
            self.shown = false
            if was and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function f:SetShown(v) self.shown = v and true or false end
        function f:IsShown() return self.shown end
        function f:IsVisible() return self.shown end
        function f:SetSize(w, h) assert(type(w) == 'number' and type(h) == 'number'); self.w, self.h = w, h end
        function f:SetHeight(h) self.h = h end
        function f:GetWidth() return self.w or 0 end
        function f:GetFrameLevel() return self.level end
        function f:SetFrameLevel(v) self.level = v end
        function f:SetTexCoord(...) self.texCoord = { ... } end
        function f:GetParent() return self.parent end
        function f:GetName() return name end
        function f:IsMouseOver() return self.over == true end
        function f:HasFocus() return self.focused == true end
        function f:ClearFocus()
            local was = self.focused
            self.focused = false
            if was and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
        end
        function f:SetFocus()
            self.focused = true
            if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
        end
        function f:ClearAllPoints() self.point = nil; self.points = {} end
        function f:SetPoint(...)
            local relative = select(2, ...)
            if type(relative) == 'table' and relative.dependsOn == self then error('dependent anchor') end
            self.point = { ... }
            self.points = rawget(self, 'points') or {}
            self.points[(...)] = { ... }
        end
        function f:SetAllPoints(target) self.point = { 'ALL', target } end
        local setSize = f.SetSize
        function f:SetSize(w, h)
            if self.template == 'SecureActionButtonTemplate' and s.combat then s.blocked = s.blocked + 1 end
            setSize(self, w, h)
        end
        function f:SetAttribute(k, v)
            if self.template == 'SecureActionButtonTemplate' and s.combat then s.blocked = s.blocked + 1 end
            self.attrs[k] = v
        end
        function f:EnableMouse(v) self.mouse = v end
        function f:GetAttribute(k) return self.attrs[k] end
        function f:SetAlpha(v) self.alpha = v end
        function f:SetScale(v) self.scale = v end
        function f:GetEffectiveScale() return self.scale end
        function f:GetTexture() return self.texture end
        function f:GetHeight() return self.h or 0 end
        function f:EnableMouseWheel(v) self.wheel = v end
        function f:SetHorizontalScroll(v) self.hscroll = v end
        function f:GetHorizontalScroll() return self.hscroll or 0 end
        function f:GetHorizontalScrollRange() return self.hrange or 0 end
        function f:SetText(t) self.text = t end
        function f:GetText() return self.text end
        function f:SetTextColor(r, g, b) self.color = { r, g, b } end
        function f:SetFont(path, size) assert(type(path) == 'string' and type(size) == 'number'); self.fontSize = size; self.font = path end
        function f:GetStringWidth() return #tostring(self.text or '') * (self.fontSize or 10) * 0.6 end
        function f:SetJustifyH(v) self.justify = v end
        function f:SetTexture(t) self.texture = t end
        function f:SetColorTexture() self.texture = 'color' end
        function f:SetDesaturated(v) self.desaturated = v end
        function f:SetCooldown(start, dur) self.cooldown = { start, dur } end
        function f:CreateTexture() return frame('Texture', nil, self) end
        s.frames[#s.frames + 1] = f
        if name then G[name] = f end
        if kind == 'Frame' and name == 'NaowhForeverConsumableBar' then s.built = s.built + 1 end
        return f
    end
    s.frame = frame
    -- An action bar button: its slot, the key text it shows, and whether it is on screen.
    function s.actionButton(slot, hotkey, shown)
        local b = frame('Button')
        b.action, b.shown = slot, shown ~= false
        b.HotKey = frame('FontString', nil, b)
        b.HotKey:SetText(hotkey)
        s.actionButtons[#s.actionButtons + 1] = b
        return b
    end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, THEME = { bg = {}, line = {}, fg = { r = 0.94, g = 0.95, b = 0.95 }, panel = { r = 0, g = 0, b = 0 }, muted = { r = 0.5, g = 0.5, b = 0.5 },
            accent = { r = 0, g = 0.6, b = 1 } },
        Print = function(msg) s.printed = msg end,
        Apply = function() end,
        ShowUnlockMode = function() s.hudOpen = true end,
        HideUnlockMode = function() s.hudOpen = false end,
        IsUnlockModeActive = function() return s.hudOpen == true end,
        UnlockModeSettings = { DB = function() return s.hud end },
        Font = function(parent, _, _, c)
            local fs = frame('FontString', nil, parent)
            if c then fs.color = { c.r, c.g, c.b } end
            return fs
        end,
        Border = function() return frame('Border') end,
        Tooltip = function() end,
        Button = function(parent, text, _, _, fn) local b = frame('Button', nil, parent); b.label = text; b.onClick = fn; return b end,
        PromptText = function(_, _, _, accept) s.prompt = accept end,
        Confirm = function(text, yes) s.confirm, s.confirmText = yes, text end,
        PixelInset = function() end,
        NewEditBox = function(parent) return frame('EditBox', nil, parent) end,
        Solid = function(parent, layer, color)
            local t = frame('Texture', nil, parent); t.layer, t.solidColor = layer, color; return t
        end,
        -- The options window steps aside for the anchor picker and editor, and comes back.
        StashOptionsWindow = function()
            local was = s.windowOpen
            s.windowOpen = false
            return was == true
        end,
        OpenOptionsWindow = function() s.windowOpen = true; s.windowOpens = (s.windowOpens or 0) + 1 end,
        -- The Shared kit: a window's parts, and the settings pages a file declares.
        Shared = {
            Parts = {
                Press = function(button) button.pressed = true end,
                -- The kit's panel: its title and its x, as Parts.Panel makes them.
                Panel = function(title)
                    local f = frame('Panel')
                    f.title = frame('FontString', nil, f)
                    f.title:SetText(title)
                    f.close = frame('Button', nil, f)
                    s.panels[#s.panels + 1] = f
                    return f
                end,
                -- The bar's own window: its backdrop's opacity, its footer note.
                Window = function()
                    local w = frame('Window')
                    w.backdrop = { Paint = function(_, alpha) w.painted = alpha end, Card = function() end }
                    w:Hide()
                    s.window = w
                    return w
                end,
                TitleBar = function(window, title) window.title = title; return frame('Button', nil, window) end,
                FooterBrand = function() end,
                FooterNote = function(window)
                    local note = frame('Frame', nil, window)
                    note.text = frame('FontString', nil, note)
                    return note
                end,
                -- A panel beside a window: its buttons along the bottom, the view it scrolls. One
                -- shows at a time, and it closes with what it is beside.
                SidePanel = function(actions, view, opacity)
                    local p = frame('Side')
                    p.actions, p.opacity = actions, opacity
                    p.title = frame('FontString', nil, p)
                    p.view = view(frame('ScrollFrame', nil, p))
                    p:Hide()
                    s.sides[#s.sides + 1] = p
                    if actions[1][1] == 'Cancel' then s.anchorEditor = p else s.side = p end
                    return p
                end,
                RepaintSidePanels = function() s.repaints = (s.repaints or 0) + 1 end,
                ShowBeside = function(panel, owner)
                    for _, other in ipairs(s.sides) do if other ~= panel then other:Hide() end end
                    if panel.beside ~= owner then owner:HookScript('OnHide', function() panel:Hide() end) end
                    panel.beside = owner
                    panel:Show()
                end,
            },
            Style = dofile('Tools/regression/shared_style.lua'),
            -- A page's cards, windows and store, by the page's name; Render counts its draws.
            Settings = {
                Group = function(title) return { group = title } end,
                Page = function(key, store)
                    s.stores[key] = store
                    return {
                        Card = function(_, spec) s.cards[key .. ':' .. spec.id] = spec; return spec end,
                        Window = function(_, spec) s.windows[key] = spec end,
                    }
                end,
                Render = function(_, key, onHeight)
                    s.renders[key] = (s.renders[key] or 0) + 1
                    onHeight(80)
                    return 80
                end,
            },
        },
        -- The Macros module, loaded first: its consumable macros, its settings, its rewrite.
        ConsumableMacros = {
            health = { label = 'Health', name = 'NF Health', icon = 134829 },
            mana = { label = 'Mana Potion', name = 'NF Mana', icon = 134855 },
            food = { label = 'Food', name = 'NF Food', icon = 133971 },
            healthstone = { label = 'Healthstone', name = 'NF Healthstone', icon = 135230 },
            healthPotion = { label = 'Health Potion', name = 'NF Health Potion', icon = 134830 },
            drink = { label = 'Drink', name = 'NF Drink', icon = 132794 },
        },
        MacroSettings = {
            Get = function(k) return s.macroSettings[k] end,
            Set = function(k, v)
                s.macroSettings[k] = v
                for _, fn in ipairs(s.macroListeners) do fn(k, v) end
            end,
            OnChange = function(fn) s.macroListeners[#s.macroListeners + 1] = fn end,
        },
        -- The Macros module on: the core's ns.ModuleOn, read from its switch here.
        ModuleOn = function(addon)
            return addon == 'NaowhForever_Macros' and not noMacros and s.macroSettings.enabled ~= false
        end,
        UpdateManagedMacros = function() s.macroUpdates = s.macroUpdates + 1 end,
        HealthOrderChoices = { values = { stone = 'Healthstone First', potion = 'Potion First' },
            order = { 'stone', 'potion' } },
        UI = { CONTENT_PAD = 20,
            -- The HUD Editor's anchoring: an element follows another (anchoredTo, by label).
            PickAnchorFor = function(handle) s.hudPicking = handle end,
            DropAnchor = function(handle)
                if handle and handle.label then s.hud.anchoredTo[handle.label] = nil end
            end, FontPath = function(key) return key ~= '' and key or 'font.ttf' end,
            -- The HUD Editor's mover: where it opens the options, and what a drag does.
            AttachMover = function(_, label, onMoved, page, card)
                local m = frame('Mover')
                m.label, m.onMoved, m.page, m.card = label, onMoved, page, card
                m:Hide()
                return m
            end,
            FontChoices = function() return { [''] = 'Addon Font', Naowh = 'Naowh' }, { '', 'Naowh' } end },
    }
    if noMacros then ns.ConsumableMacros, ns.MacroSettings, ns.HealthOrderChoices = nil, nil, nil end
    local listeners = {}
    ns.QoLSettings = {
        Get = function(k) if s.settings[k] ~= nil then return s.settings[k] end return DEFAULTS[k] end,
        Set = function(k, v)
            s.writes[k] = (s.writes[k] or 0) + 1
            s.settings[k] = v
            for _, fn in ipairs(listeners) do fn(k) end
        end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
    }
    G.NaowhForever = ns
    local env = { _G = G, CreateFrame = frame, GameTooltip = frame('Tooltip'),
        NUM_BAG_SLOTS = 4, WorldFrame = frame('WorldFrame'),
        InCombatLockdown = function() return s.combat end,
        GetTime = function() return s.now end,
        issecretvalue = function(v) return type(v) == 'table' and v.secret == true end,
        strtrim = function(t) return (t:gsub('^%s+', ''):gsub('%s+$', '')) end,
        RegisterStateDriver = function(f, _, rule)
            if s.combat then s.blocked = s.blocked + 1 end
            s.registers = s.registers + 1
            f.driver = rule; Evaluate(f)
        end,
        UnregisterStateDriver = function(f) f.driver = nil end,
        GetMouseFoci = function() return s.focus end,
        GetCursorPosition = function() return 300, 200 end,
        RANGE_INDICATOR = 'RANGE',
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_Spell = { GetSpellName = function(id) return id == 430 and 'Drink' or id == 433 and 'Food' or 'Spell' end },
        UnitClass = function() return 'Class', class or 'MAGE' end,
        UnitLevel = function() return s.level end,
        GetBindingKey = function(command) return s.bindings[command] end,
        GetBindingText = function(key, short) return short and ('*' .. key) or key end,
        GetMacroInfo = function(index) return s.macros[index] end,
        GetActionText = function(slot) return s.actionText[slot] end,
        GetMacroBody = function(name) return s.macroBodies[name] end,
        GetCursorInfo = function() if s.cursor then return s.cursor[1], s.cursor[2] end end,
        ClearCursor = function() s.cursor = nil end,
        LibStub = function(name)
            if name == 'LibActionButton-1.0' and s.labButtons then
                return { GetAllButtons = function() return s.labButtons end }
            end
        end,
        ActionBarButtonEventsFrame = { frames = s.actionButtons },
        GetActionInfo = function(slot) local a = s.actions[slot]; if a then return a[1], a[2] end end,
        IsMouseButtonDown = function() return s.mouseDown end,
        GetWeaponEnchantInfo = function()
            local e = s.enchant
            return e.main ~= nil, e.main, 0, 1, e.off ~= nil, e.off, 0, 2
        end,
        C_Secrets = { ShouldAurasBeSecret = function() return s.secretAuras end },
        C_UnitAuras = { GetPlayerAuraBySpellID = function(id) s.auraReads = s.auraReads + 1; return s.auras[id] end },
        C_Timer = { After = function(delay, fn) s.timers[#s.timers + 1] = { at = s.now + delay, fn = fn } end },
        C_Item = { GetItemInfoInstant = function(id) local k = KNOWN[id]; if k then return id, nil, nil, nil, k[1], k[2], k[4] end end,
            GetItemIconByID = function(id) return KNOWN[id] and KNOWN[id][1] end,
            GetItemNameByID = function(id) return 'Item' .. id end,
            GetItemSpell = function(id)
                local k = KNOWN[id]
                if k and k[3] then return SPELL_NAMES[id] or 'Spell', k[3] end
            end,
            GetItemInfo = function(id)
                if s.missing[id] then return end
                return 'Item', nil, nil, nil, s.levels[id] or 0
            end,
            RequestLoadItemDataByID = function() end,
            GetItemCount = function(id) return s.counts[id] or 0 end },
        C_Container = {
            GetItemCooldown = function(id)
                local c = s.cooldowns[id]
                if c then return c[1], c[2], c[3] end
                return 0, 0, 1
            end,
            GetContainerNumSlots = function(bag) return s.bags[bag] and #s.bags[bag] or 0 end,
            GetContainerItemID = function(bag, slot) return s.bags[bag] and s.bags[bag][slot] end,
            GetContainerItemInfo = function(bag, slot)
                local id = s.bags[bag] and s.bags[bag][slot]
                if id then return { itemID = id } end
            end },
        hooksecurefunc = function(t, k, fn) local old = t[k]; t[k] = function(...) old(...); fn(...) end end,
    }
    env.UIParent = frame('Parent', 'UIParent')
    setmetatable(G, { __index = env })
    setmetatable(env, { __index = _G })
    -- The feature switches, the shared parts the bar is built on, then the addon's files in its
    -- XML's order.
    local paths = { 'Core/Features.lua', 'Shared/Game/Consumables.lua', 'Shared/Game/ActionKeys.lua',
        'Shared/UI/ItemBar.lua', 'Shared/UI/Anchor.lua' }
    local xml = assert(io.open('NaowhForever_Combat/ConsumableBar/ConsumableBar.xml', 'rb'))
    for file in xml:read('*a'):gmatch('<Script file="([^"]+)"') do
        paths[#paths + 1] = 'NaowhForever_Combat/ConsumableBar/' .. file:gsub('\\', '/')
    end
    xml:close()
    for _, path in ipairs(paths) do
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
    end
    s.ns, s.G, s.CB = ns, G, ns.ConsumableBar
    function s.fire(event, ...)
        local all = {}; for i, f in ipairs(s.frames) do all[i] = f end
        for _, f in ipairs(all) do if f.events[event] then f.scripts.OnEvent(f, event, ...) end end
    end
    -- An item used: its spell cast, then its cooldown.
    function s.use(itemID, duration)
        s.fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast', KNOWN[itemID][3])
        s.cooldowns[itemID] = { s.now, duration, 1 }
        s.fire('BAG_UPDATE_COOLDOWN')
    end
    -- Combat starts and ends the way the client runs it: drivers first, then the events.
    function s.fight(on)
        s.combat = on
        for _, f in ipairs(s.frames) do Evaluate(f) end
        s.fire(on and 'PLAYER_REGEN_DISABLED' or 'PLAYER_REGEN_ENABLED')
    end
    function s.advance(dt)
        s.now = s.now + dt
        local again = true
        while again do
            again = false
            for i, t in ipairs(s.timers) do
                if t.at <= s.now then table.remove(s.timers, i); t.fn(); again = true; break end
            end
        end
    end
    function s.set(k, v) ns.QoLSettings.Set(k, v) end
    -- Opens Edit Items, as the page's window card does; returns the bar's preview in it.
    function s.editor()
        s.CB.OpenEditor()
        for _, f in ipairs(s.frames) do
            if rawget(f, 'cells') and rawget(f, 'view') then return f end
        end
    end
    -- A row of an item's settings, by its label.
    function s.itemRow(label)
        for _, row in ipairs(s.cards['Consumable Bar/Item:item'].rows) do
            if row.label == label then return row end
        end
    end
    -- A row of a card on the settings page, by the card's id and the row's label.
    function s.pageRow(id, label)
        for _, row in ipairs(s.cards['Consumable Bar/Settings:' .. id].rows) do
            if row.label == label then return row end
        end
    end
    function s.listens(event)
        for _, f in ipairs(s.frames) do if f.events[event] then return true end end
        return false
    end
    function s.buttons()
        local out = {}
        for _, f in ipairs(s.frames) do
            if f.template == 'SecureActionButtonTemplate' and f.slot ~= nil then out[#out + 1] = f end
        end
        table.sort(out, function(x, y) return x.slot < y.slot end)
        return out
    end
    s.fire('PLAYER_LOGIN')
    s.bar = G.NaowhForeverConsumableBar
    return s
end

local function driver(f) return rawget(f, 'driver') end

do
    local s = fixture()
    check('disabled builds no bar', s.built == 0)
    check('disabled registers no bag events', not s.listens('BAG_UPDATE_DELAYED'))
    local handlers = 0
    for _, f in ipairs(s.frames) do if f.scripts.OnEvent then handlers = handlers + 1 end end
    check('off at load, no event frame is even made', handlers == 0)
    s.set('consumableBarSize', 40)
    check('a setting change while disabled still builds nothing', s.built == 0)
end

-- The bar is its own switch, as Gear & Trinkets and Blessings are: QoL's switch is QoL's
do
    local s = fixture({ enabled = false, consumableBar = true, consumableBarItems = { 13446 } })
    check('with QoL switched off, the bar still runs', s.built == 1 and s.bar.shown)
    local applies = s.applies
    s.set('enabled', true)
    s.set('enabled', false)
    check('and QoL\'s switch applies nothing to it', s.applies == applies)
end

do
    local s = fixture({ consumableBar = true })
    check('an empty bar stays hidden', not s.bar.shown)
    s.ns.ShowUnlockMode()
    check('an empty bar shows in Unlock Mode', s.bar.shown and s.bar.mover.shown and s.bar.w == 36)
    s.ns.HideUnlockMode()
    check('leaving Unlock Mode hides the empty bar again', not s.bar.shown)
end

do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512 } })
    s.counts[13446] = 7
    s.fire('BAG_UPDATE_DELAYED')
    local b = s.buttons()
    check('one button per item', #b == 2)
    check('item buttons use the item on left click', b[1].attrs.type1 == 'item' and b[1].attrs.item1 == 'item:13446')
    check('a carried item shows its count', b[1].count.shown and b[1].count.text == 7 and not b[1].none.shown)
    check('an item the bags are out of shows NONE', b[2].none.shown and not b[2].count.shown)
    check('NONE is the house red, centered', b[2].none.color[1] == s.ns.Shared.Style.RED_RGB.r
        and b[2].none.point[1] == 'CENTER')
    check('an item the bags are out of is grey', b[2].icon.desaturated == true)
    local crop = s.ns.Shared.Style.ICON_CROP
    check("icons are cropped like the addon's other item icons", b[1].icon.texCoord
        and b[1].icon.texCoord[1] == crop and b[1].icon.texCoord[4] == 1 - crop)

    for _, size in ipairs({ 20, 36, 64 }) do
        s.set('consumableBarSize', size)
        local width = b[2].none:GetStringWidth()
        check('NONE fits inside a ' .. size .. 'px icon', width <= size - 4)
        check('NONE reaches toward the edges of a ' .. size .. 'px icon', width >= size - 7)
    end
    local noneSize = b[2].none.fontSize
    s.set('consumableBarFontSize', 30)
    check('NONE follows the icon, not the font size', b[2].none.fontSize == noneSize)

    check('on by default, Hide When Out', SHIPPED_HIDE_EMPTY == true)
    check('both items take their place', s.bar.w == 132)
    s.set('consumableBarHideEmpty', true)
    check('Hide When Out takes an empty item off the bar', #s.buttons() == 1 and s.buttons()[1] == b[1]
        and not b[2].shown)
    check('and the bar closes up behind it', s.bar.w == 64)
    check('Hide When Out leaves a carried item alone', b[1].alpha == 1)
    s.fight(true)
    local before = s.blocked
    s.counts[13446] = 0
    s.fire('BAG_UPDATE_DELAYED')
    check('the last one used in combat fades at once', b[1].alpha == 0 and b[1].shown)
    s.counts[13446] = 3
    s.fire('BAG_UPDATE_DELAYED')
    check('one looted in combat comes back at once', b[1].alpha == 1 and b[1].count.text == 3)
    s.counts[5512] = 1
    s.fire('BAG_UPDATE_DELAYED')
    check('one gained in combat waits for the fight to end', #s.buttons() == 1 and s.blocked == before)
    s.fight(false)
    check('then takes its old place on the bar', #s.buttons() == 2 and s.buttons()[2] == b[2] and b[2].shown
        and s.bar.w == 132)
    s.counts[13446] = 0
    s.fire('BAG_UPDATE_DELAYED')
    check('one used up out of combat leaves at once', #s.buttons() == 1 and s.buttons()[1] == b[2]
        and b[2].point[4] == 0)
    s.ns.ShowUnlockMode()
    check('Unlock Mode shows every item', #s.buttons() == 2)
    s.ns.HideUnlockMode()
    s.counts[13446] = 3
    s.set('consumableBarHideEmpty', false)

    s.fight(true)
    local blocked = s.blocked
    s.set('consumableBarItems', { 13446, 5512, 20007 })
    check('a change in combat touches no secure button', s.blocked == blocked and #s.buttons() == 2)
    s.fight(false)
    check('the change applies when combat ends', #s.buttons() == 3)

    s.set('consumableBar', false)
    check('disabling hides the bar', not s.bar.shown)
    check('disabling unregisters bag events', not s.listens('BAG_UPDATE_DELAYED'))
end

do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    local count = s.buttons()[1].count
    check('default count sits inside the bottom right corner',
        count.point[1] == 'BOTTOMRIGHT' and count.point[4] == -2 and count.point[5] == 2)
    s.set('consumableBarTextOutside', true)
    check('outside the bottom right corner hangs below it', count.point[1] == 'TOPRIGHT' and count.point[3] == 'BOTTOMRIGHT')
end

-- Hide in Combat
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512 },
        consumableBarItemFlags = { [13446] = { combat = true } } })
    local b = s.buttons()
    check('hide in combat puts a state driver on that icon', driver(b[1]) == '[combat] hide; show' and not driver(b[2]))
    s.fight(true)
    check('it hides in a fight, the other stays', not b[1].shown and b[2].shown and s.bar.shown)
    s.fight(false)
    s.set('consumableBarItemFlags', { [13446] = { combat = true }, [5512] = { combat = true } })
    check('every icon hidden in combat hides the bar too', driver(s.bar) == '[combat] hide; show')
    s.ns.ShowUnlockMode()
    check('Unlock Mode shows every icon', not driver(b[1]) and not driver(s.bar) and b[1].shown)
end

-- Hide After Use: out of combat only; a fight brings the icon back.
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 20007, 12404 },
        consumableBarItemFlags = { [13446] = { used = true }, [20007] = { used = true },
            [12404] = { used = true, track = 'mainhand' } } })
    local potion, elixir, stone = s.buttons()[1], s.buttons()[2], s.buttons()[3]
    check('hide after use listens for buffs and weapon enchants',
        s.listens('UNIT_AURA') and s.listens('UNIT_INVENTORY_CHANGED') and s.listens('BAG_UPDATE_COOLDOWN'))
    check('a ready item shows', potion.shown and elixir.shown and stone.shown)

    s.use(13446, 120)
    check('a potion on cooldown hides out of combat', not potion.shown and driver(potion) == '[combat] show; hide')
    s.fight(true)
    check('a fight brings it back, with its cooldown', potion.shown and potion.timer.shown)
    s.fight(false)
    check('after the fight it hides again', not potion.shown)
    s.advance(121)
    check('it comes back when its cooldown ends', potion.shown)
    s.cooldowns[13446] = { s.now, 1, 1 }
    s.fire('BAG_UPDATE_COOLDOWN')
    check('the global cooldown does not count as used', potion.shown)

    s.set('consumableBarItems', { 13446, 13444 })
    s.set('consumableBarItemFlags', { [13444] = { used = true } })
    local mana = s.buttons()[2]
    s.advance(200)
    s.use(13446, 120)
    s.cooldowns[13444] = { s.now, 120, 1 }
    s.fire('BAG_UPDATE_COOLDOWN')
    check("a healing potion's shared cooldown does not hide a mana potion", mana.shown)
    s.fight(true)
    s.use(13444, 120)
    s.fight(false)
    check('its own use does, noted even in a fight', not mana.shown)
    s.set('consumableBarItems', { 13446, 20007, 12404 })
    s.set('consumableBarItemFlags', { [13446] = { used = true }, [20007] = { used = true },
        [12404] = { used = true, track = 'mainhand' } })

    s.auras[17535] = { expirationTime = s.now + 1800 }
    s.fire('UNIT_AURA', 'player')
    check('an elixir hides while its buff is on you', not elixir.shown)
    s.fight(true)
    local reads, blocked = s.auraReads, s.blocked
    s.fire('UNIT_AURA', 'player')
    s.fire('BAG_UPDATE_COOLDOWN')
    check('no aura is read in combat', s.auraReads == reads)
    check('nothing protected changes in combat', s.blocked == blocked)
    check('the elixir shows in the fight', elixir.shown)
    s.fight(false)
    check('and hides after it while the buff lasts', not elixir.shown)
    s.advance(1801)
    check('it comes back when the buff runs out', elixir.shown)

    s.enchant.main = 1800 * 1000
    s.fire('UNIT_INVENTORY_CHANGED', 'player')
    check('a sharpening stone hides while the weapon is enchanted', not stone.shown)
    s.enchant.main = nil
    s.fire('UNIT_INVENTORY_CHANGED', 'player')
    check('it shows once the enchant is gone', stone.shown)
    s.set('consumableBarItemFlags', { [13446] = { used = true }, [20007] = { used = true },
        [12404] = { used = true, track = 'offhand' } })
    s.enchant.main = 1800 * 1000
    s.fire('UNIT_INVENTORY_CHANGED', 'player')
    check('set to the off hand, the main hand enchant does not hide it', stone.shown)
    s.enchant.off = 1800 * 1000
    s.fire('UNIT_INVENTORY_CHANGED', 'player')
    check('the off hand enchant does', not stone.shown)
end

-- Hide After Use re-registers a driver only when its rule changes
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 20007 },
        consumableBarItemFlags = { [13446] = { used = true } } })
    local potion = s.buttons()[1]
    s.use(13446, 120)
    local before = s.registers
    for _ = 1, 5 do s.fire('BAG_UPDATE_COOLDOWN') end
    check('a global cooldown with nothing changed registers nothing', s.registers == before)
    local later = 0
    for _, timer in ipairs(s.timers) do if timer.at > s.now then later = later + 1 end end
    check('one look is scheduled, not one per global cooldown', later == 1)
    s.advance(121)
    check('a rule that changes is registered', potion.shown and driver(potion) == nil)
    s.use(13446, 120)
    s.set('consumableBar', false)
    s.advance(121)
    check('a look due after the bar is switched off leaves it hidden', not s.bar.shown)
end

-- Food: hidden while eating and while Well Fed, not only while eating; from Shared's lists, so with
-- Aura Buffs off too (it is not loaded here)
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 21023 },
        consumableBarItemFlags = { [21023] = { used = true } } })
    s.counts[21023] = 3
    local chops = s.buttons()[1]
    s.auras[24869] = { expirationTime = s.now + 30 }
    s.fire('UNIT_AURA', 'player')
    check('hidden while eating', not chops.shown)
    s.auras[24869] = nil
    s.auras[24870] = { expirationTime = s.now + 900 }
    s.fire('UNIT_AURA', 'player')
    check('still hidden once you stand up Well Fed', not chops.shown)
    s.advance(901)
    check('back when Well Fed runs out', chops.shown)
    s.auras[24870] = { expirationTime = s.now + 900 }
    s.set('consumableBarItemFlags', { [20007] = { used = true } })
    s.set('consumableBarItems', { 20007 })
    check('Well Fed does not hide an item that is not food', s.buttons()[1].shown)
end

-- Hide When Out leaves no button to catch clicks
do
    local s = fixture({ consumableBar = true, consumableBarHideEmpty = true, consumableBarItems = { 13446, 20007 } })
    s.counts[13446], s.counts[20007] = 0, 2
    s.fire('BAG_UPDATE_DELAYED')
    check('an item you have none of has no button on the bar', #s.buttons() == 1
        and s.buttons()[1].attrs.item1 == 'item:20007')
    s.counts[13446] = 1
    s.fire('BAG_UPDATE_DELAYED')
    local out = s.buttons()[1]
    check('it gets one, first in line, once you have one', #s.buttons() == 2 and out.attrs.item1 == 'item:13446'
        and out.mouse == true)
    s.fight(true)
    s.counts[13446] = 0
    s.fire('BAG_UPDATE_DELAYED')
    check('in combat it can only fade', out.alpha == 0 and out.mouse == true and out.shown)
    s.fight(false)
    check('after the fight it leaves the bar', not out.shown and out.slot == nil and #s.buttons() == 1)
    s.set('consumableBarHideEmpty', false)
    check('with Hide When Out off, NONE stays clickable', out.shown and out.mouse == true and out.none.shown)
end

-- Show Before It Ends
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 20007 },
        consumableBarItemFlags = { [20007] = { used = true, early = true, earlySeconds = 120 } } })
    local elixir = s.buttons()[1]
    s.auras[17535] = { expirationTime = s.now + 600 }
    s.fire('UNIT_AURA', 'player')
    check('the buff with ten minutes left keeps it hidden', not elixir.shown)
    s.advance(479)
    check('still hidden just over two minutes out', not elixir.shown)
    s.advance(2)
    check('it shows two minutes before the buff ends', elixir.shown)
    s.auras[17535] = { expirationTime = 0 }
    s.fire('UNIT_AURA', 'player')
    check('a buff that never runs out keeps it hidden', not elixir.shown)
end

-- Icons Per Row
do
    local items = {}
    for i = 1, 7 do items[i] = 13446 + i - 1 end
    local s = fixture({ consumableBar = true, consumableBarItems = items, consumableBarPerRow = 3,
        consumableBarSize = 30, consumableBarSpacing = 2 })
    local b = s.buttons()
    check('a full row starts a new one below', s.bar.w == 3 * 32 - 2 and s.bar.h == 3 * 32 - 2)
    check('the fourth icon starts the second row', b[4].point[1] == 'TOPLEFT' and b[4].point[4] == 0 and b[4].point[5] == -32)
    check('the third icon ends the first row', b[3].point[4] == 64 and b[3].point[5] == 0)
    s.set('consumableBarGrow', 'LEFT')
    check('growing left fills rows from the right', b[2].point[1] == 'TOPRIGHT' and b[2].point[4] == -32)
    s.set('consumableBarGrow', 'DOWN')
    check('growing down fills columns, new ones to the right', b[4].point[1] == 'TOPLEFT' and b[4].point[4] == 32
        and b[4].point[5] == 0 and b[2].point[5] == -32)
    check('a column bar is as wide as its columns', s.bar.w == 3 * 32 - 2 and s.bar.h == 3 * 32 - 2)
    s.set('consumableBarGrow', 'UP')
    check('growing up fills columns from the bottom', b[2].point[1] == 'BOTTOMLEFT' and b[2].point[5] == 32)
    s.set('consumableBarGrow', 'LEFT')
    check('Flip Row Direction is off by default', DEFAULTS.consumableBarFlipRows == false)
    s.set('consumableBarFlipRows', true)
    check('flipped, the first row sits at the bottom', b[1].point[1] == 'BOTTOMRIGHT' and b[1].point[5] == 0)
    check('and the next row goes above it', b[4].point[1] == 'BOTTOMRIGHT' and b[4].point[4] == 0
        and b[4].point[5] == 32)
    check('flipping keeps the bar\'s size', s.bar.w == 3 * 32 - 2 and s.bar.h == 3 * 32 - 2)
    check('the background reaches up toward the row above', b[1].bg.points.TOPLEFT[5] == 1
        and b[1].bg.points.BOTTOMRIGHT[5] == -s.CB.C.BG_PAD)
    s.set('consumableBarGrow', 'DOWN')
    check('flipped columns go to the left', b[4].point[1] == 'TOPRIGHT' and b[4].point[4] == -32)
    s.set('consumableBarGrow', 'RIGHT')
    check('flipped right, the next row goes above from the left', b[4].point[1] == 'BOTTOMLEFT'
        and b[4].point[4] == 0 and b[4].point[5] == 32 and b[2].point[4] == 32 and b[2].point[5] == 0)
    s.set('consumableBarGrow', 'UP')
    check('flipped up, the next column goes to the left from the bottom', b[4].point[1] == 'BOTTOMRIGHT'
        and b[4].point[4] == -32 and b[4].point[5] == 0 and b[2].point[5] == 32)
    s.set('consumableBarFlipRows', false)
    s.set('consumableBarPerRow', 12)
    s.set('consumableBarGrow', 'RIGHT')
    check('one row when they all fit', s.bar.h == 30 and s.bar.w == 7 * 32 - 2)
    check('Rectangular Icons is off by default', DEFAULTS.consumableBarRect == false)
    s.set('consumableBarHeight', 20)
    check('Icon Height does nothing while it is off', b[1].w == 30 and b[1].h == 30)
    s.set('consumableBarRect', true)
    local crop = s.ns.Shared.Style.ICON_CROP
    check('rectangular icons take their own height', b[1].w == 30 and b[1].h == 20 and s.bar.h == 20)
    local tc = b[1].icon.texCoord
    check('a wide icon crops its art top and bottom, not stretched',
        math.abs((tc[2] - tc[1]) / (tc[4] - tc[3]) - 28 / 18) < 1e-9)
    s.set('consumableBarHeight', 40)
    tc = b[1].icon.texCoord
    check('a tall icon crops its art at the sides', b[1].h == 40
        and math.abs((tc[2] - tc[1]) / (tc[4] - tc[3]) - 28 / 38) < 1e-9 and math.abs(tc[3] - crop) < 1e-9)
    s.set('consumableBarHeight', 20)
    s.set('consumableBarGrow', 'DOWN')
    check('a column steps by the icon height', b[2].point[5] == -22 and s.bar.h == 7 * 22 - 2 and s.bar.w == 30)
    s.set('consumableBarRect', false)
    s.set('consumableBarGrow', 'RIGHT')
    check('square again, the usual crop', b[1].h == 30 and b[1].icon.texCoord[1] == crop
        and b[1].icon.texCoord[3] == crop)
end

-- Show Keybinds
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512, 20007 } })
    s.actions[1] = { 'item', 13446 }
    s.actions[25] = { 'item', 5512 }
    s.actions[61] = { 'item', 5512 }
    s.actions[2] = { 'spell', 20007 }
    s.actionButton(1, 'S1')
    s.actionButton(25, 'RANGE')
    s.actionButton(61, 'F3', false)
    s.actionButton(2, '2')
    local b = s.buttons()
    s.advance(0)
    check('keybinds are off by default', not b[1].key.shown)
    check('off, nothing listens for binding changes', not s.listens('UPDATE_BINDINGS'))
    s.set('consumableBarKeybinds', true)
    s.advance(0)
    check('an item on a bound button shows its key', b[1].key.shown and b[1].key.text == 'S1')
    check('the key sits in the top right corner', b[1].key.point[1] == 'TOPRIGHT')
    check('an unbound button is skipped, a bar off screen still counts', b[2].key.text == 'F3')
    check('a spell with the same ID is not the item', not b[3].key.shown)
    s.actionButton(26, 'C5')
    s.actions[26] = { 'item', 5512 }
    s.fire('ACTIONBAR_SLOT_CHANGED')
    check('it waits a frame for the game to redraw its own keys', b[2].key.text == 'F3')
    s.advance(0)
    check('a button on screen wins over one off it', b[2].key.text == 'C5')
    s.fight(true)
    s.actions[1] = nil
    s.fire('ACTIONBAR_SLOT_CHANGED')
    s.advance(0)
    check('keys follow the bars in combat too', not b[1].key.shown)
    s.fight(false)
    s.set('consumableBarKeybinds', false)
    s.advance(0)
    check('switching it off clears the keys and stops listening', not b[2].key.shown and not s.listens('ACTIONBAR_SLOT_CHANGED'))
end

-- Hide Bar in Combat
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512 },
        consumableBarItemFlags = { [13446] = { used = true } } })
    s.set('consumableBarHideCombat', true)
    check('the bar hides in combat as a whole', driver(s.bar) == '[combat] hide; show')
    s.fight(true)
    check('a fight hides it, whatever the icons say', not s.bar.shown)
    s.fight(false)
    check('it is back after the fight', s.bar.shown)
    s.ns.ShowUnlockMode()
    check('Unlock Mode still shows it', not driver(s.bar) and s.bar.shown)
end

-- Custom text set before the switch existed
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 },
        consumableBarItemFlags = { [13446] = { text = 'OLD' } } })
    check('an item that already had text keeps showing it', s.buttons()[1].custom.shown and s.buttons()[1].custom.text == 'OLD')
    local cells = s.editor().cells
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    check('and its settings show the switch on', s.stores['Consumable Bar/Item'].Get('textOn') == true)
end

-- Scan Filters
do
    local cat = function(s, id) return s.CB.Category(id) end
    local s = fixture({ consumableBar = true })
    check('potions, elixirs and scrolls by subclass', cat(s, 13446) == 'potion' and cat(s, 20007) == 'elixir'
        and cat(s, 10307) == 'scroll')
    check('food and bandages by subclass', cat(s, 8932) == 'food' and cat(s, 14530) == 'bandage')
    check('a stone is a weapon enhancement, whatever class the game gives it', cat(s, 2862) == 'weapon')
    check('a healthstone has its own kind', cat(s, 5509) == 'healthstone')
    check('a scroll that gives no buff is not one either', cat(s, 7146) == nil)
    check('cloth is no consumable', cat(s, 2589) == nil)
    check('explosives and devices count, filed as Trade Goods', cat(s, 18641) == 'explosive'
        and cat(s, 10587) == 'device')
    check('other Trade Goods do not', cat(s, 4359) == nil)
    s.bags[0] = { 13446, 2862, 8932, 5509, 2589 }
    s.set('consumableBarSkip', { food = true, weapon = true })
    s.CB.ScanBags()
    local items = s.settings.consumableBarItems
    check('scan skips the kinds switched off', #items == 2 and items[1] == 13446 and items[2] == 5509)
    s.set('consumableBarSkip', {})
    s.CB.ScanBags()
    check('switched back on, the next scan adds them', #s.settings.consumableBarItems == 4)
end

do
    local s = fixture({ consumableBar = true, consumableBarAskNew = true, consumableBarSkip = { food = true } })
    s.bags[1] = { 20007 }
    s.counts[20007] = 1
    s.fire('BAG_UPDATE_DELAYED')
    check('the bags filled after login are learnt, not asked about', s.panels[1] == nil)
    -- A potion and a food land together; only the potion is a kind still switched on.
    s.bags[0] = { 13446, 8932 }
    s.counts[13446] = (s.counts[13446] or 0) + 1
    s.counts[8932] = (s.counts[8932] or 0) + 1
    s.fire('BAG_UPDATE_DELAYED')
    local ask
    for _, f in ipairs(s.frames) do
        local icon = rawget(f, 'icon')
        if type(icon) == 'table' and rawget(icon, 'tex') then ask = f end
    end
    check('the potion asks', ask and ask.shown and ask.itemID == 13446)
    for _, f in ipairs(s.frames) do
        if f.parent == ask and f.label == 'Add' then f.onClick() end
    end
    check('a kind switched off is never asked about', not ask.shown and #s.settings.consumableBarItems == 1)
end

-- Every icon's button is named after its item, so a bound key follows it
do
    local s = fixture({ consumableBar = true, consumableBarKeybinds = true, consumableBarItems = { 13446, 20007 } })
    local potion = s.G.NaowhForeverConsumableBarItem13446
    check('an item\'s button is named by its ID', potion ~= nil and s.buttons()[1] == potion)
    check('the bind action names that button',
        s.CB.BindAction(13446) == 'CLICK NaowhForeverConsumableBarItem13446:LeftButton')
    s.bindings['CLICK NaowhForeverConsumableBarItem13446:LeftButton'] = 'CTRL-1'
    s.fire('UPDATE_BINDINGS')
    s.advance(0)
    check('a key bound to it shows on it', potion.key.text == '*CTRL-1')
    s.set('consumableBarItems', { 20007, 13446 })
    s.advance(0)
    check('moved, the same button and key go with it', s.buttons()[2] == potion and potion.slot == 2
        and potion.key.text == '*CTRL-1')
    s.set('consumableBarItems', { 20007 })
    check('taken off the bar, its button is cleared and hidden', potion.itemID == nil and potion.entry == nil
        and potion.attrs.type1 == nil and not potion.shown)
    s.set('consumableBarItems', { 20007, 13446 })
    check('back on the bar, it gets the same button', s.buttons()[2] == potion and potion.shown)

    local cells = s.editor().cells
    local key = s.itemRow('Key')
    cells[2].scripts.OnClick(cells[2], 'RightButton')
    check('an icon\'s settings have a Key row for its button',
        key.binding() == 'CLICK NaowhForeverConsumableBarItem13446:LeftButton')
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    check('opened for another icon, it binds that one',
        key.binding() == 'CLICK NaowhForeverConsumableBarItem20007:LeftButton')
end

-- Keybinds from every kind of bar
do
    local s = fixture({ consumableBar = true, consumableBarKeybinds = true,
        consumableBarItems = { 13446, 5512, 20007, 10307 } })
    s.bindings['CLICK NaowhForeverConsumableBarItem10307:LeftButton'] = 'ALT-M'
    s.actions[3] = { 'item', 13446 }
    local blizz = s.actionButton(3, '')
    blizz.commandName = 'ACTIONBUTTON3'
    s.bindings.ACTIONBUTTON3 = 'SHIFT-3'
    s.actions[40] = { 'item', 5512 }
    local own = s.actionButton(40, 'RANGE')
    own.GetName = function() return 'EUI_Bar2Button4' end
    s.bindings['CLICK EUI_Bar2Button4:Keybind'] = 'F'
    s.actions[90] = { 'item', 20007 }
    local lab = s.frame('Button')
    lab.HotKey = s.frame('FontString', nil, lab)
    lab.HotKey:SetText('Q')
    lab.GetAction = function() return 'action', 90 end
    s.labButtons = { [lab] = true }
    s.fire('ACTIONBAR_SLOT_CHANGED')
    s.advance(0)
    local b = s.buttons()
    check('a bar that draws its own text: the key bound to the button', b[1].key.text == '*SHIFT-3')
    check('a bar bound by click: that binding', b[2].key.text == '*F')
    check('a LibActionButton bar is read too', b[3].key.text == 'Q')
    check('or the key bound to its own button', b[4].key.text == '*ALT-M')
end

-- EllesmereUI's own buttons, off ActionBarButtonEventsFrame
do
    local s = fixture({ consumableBar = true, consumableBarKeybinds = true, consumableBarItems = { 13446, 5512 } })
    s.actions[37] = { 'item', 13446 }
    local shown = s.frame('CheckButton', 'EABButton37')
    shown.attrs.action = 37
    shown.HotKey = s.frame('FontString', nil, shown)
    shown.HotKey:SetText('S-4')
    -- Keybind text switched off in EllesmereUI: the binding command it set is read instead.
    s.actions[61] = { 'item', 5512 }
    local bare = s.frame('CheckButton', 'EABButton61')
    bare.attrs.action, bare.attrs.binding = 61, 'MULTIACTIONBAR4BUTTON1'
    bare.HotKey = s.frame('FontString', nil, bare)
    bare.HotKey:SetText('')
    s.bindings.MULTIACTIONBAR4BUTTON1 = 'CTRL-1'
    s.fire('ACTIONBAR_SLOT_CHANGED')
    s.advance(0)
    local b = s.buttons()
    check('an EllesmereUI button is found by name', b[1].key.text == 'S-4')
    check('one with its text off shows the key bound to it', b[2].key.text == '*CTRL-1')
end

-- Keybind text settings
do
    local s = fixture({ consumableBar = true, consumableBarKeybinds = true, consumableBarItems = { 13446 },
        consumableBarFont = 'Naowh' })
    local b = s.buttons()[1]
    check('the key sits top right at size 10 by default', b.key.point[1] == 'TOPRIGHT' and b.key.fontSize == 10)
    check('its font starts on the addon font, whatever the count uses', b.key.font == 'font.ttf')
    check('and it is light grey', b.key.color[1] == 0.85)
    s.set('consumableBarKeyFont', 'Other')
    s.set('consumableBarKeySize', 16)
    s.set('consumableBarKeyColor', { r = 1, g = 0, b = 0 })
    s.set('consumableBarKeyPoint', 'BOTTOMLEFT')
    s.set('consumableBarKeyOutside', true)
    s.set('consumableBarKeyX', 3)
    check('its own font and size', b.key.font == 'Other' and b.key.fontSize == 16)
    check('its own colour', b.key.color[1] == 1 and b.key.color[2] == 0)
    check('outside the icon at its own point, with the offset', b.key.point[1] == 'TOPLEFT'
        and b.key.point[3] == 'BOTTOMLEFT' and b.key.point[4] == 3)
end

-- Its settings page: Edit Items, the bar's card with its cogs, adding items, the window
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512 },
        consumableBarItemFlags = { [5512] = { combat = true } } })
    local edit = s.windows['Consumable Bar/Settings']
    check('the page opens Edit Items', edit and edit.text == 'Edit Items' and edit.headline() == '2 items on the bar')
    edit.open()
    check('which opens the bar\'s own window', s.window and s.window.shown)
    local bar = s.cards['Consumable Bar/Settings:bar']
    check('the bar\'s card says how many items', bar.summary(s.ns.QoLSettings) == '2 items on the bar')
    s.set('consumableBar', false)
    check('or that it is off', bar.summary(s.ns.QoLSettings) == 'Off')
    s.set('consumableBar', true)
    local rows = {}
    for _, id in ipairs({ 'bar', 'adding', 'anchor' }) do
        local seen = {}
        for _, row in ipairs(s.cards['Consumable Bar/Settings:' .. id].rows) do
            if row.label then
                check('every label is its own on its card: ' .. row.label, seen[row.label] == nil)
                seen[row.label] = true
                if id == 'adding' or not rows[row.label] then rows[row.label] = row end
                check('its help is one short sentence: ' .. row.label, row.help == nil or #row.help < 100)
            end
        end
    end
    check('Show Count has its cog, its text rows under it', rows['Show Count'].cog.title == 'Count Text'
        and rows['Count Size'].under == 'Show Count' and rows['Count Y Offset'].under == 'Show Count')
    check('Show Keybinds has its cog, its text rows under it', rows['Show Keybinds'].cog.title == 'Keybind Text'
        and rows['Keybind Font'].under == 'Show Keybinds' and rows['Keybind Y Offset'].under == 'Show Keybinds')
    check("the key font is a font choice like the count's", rows['Keybind Font'].font == true
        and rows['Keybind Font'].choice == nil)
    check('Ask to Add has the Scan Filters cog', rows['Ask to Add New Consumables'].cog.title == 'Scan Filters')
    local filters = 0
    for _, row in pairs(rows) do
        if row.under == 'Ask to Add New Consumables' then filters = filters + 1 end
    end
    check('a filter for every kind, under that cog', filters == #s.CB.Data.ORDER)
    local food = rows['Food & Drink']
    check('a filter is an entry of the skip list', food.key == 'consumableBarSkip' and food.field == 'food')
    food.set(false)
    check('switched off, it skips its kind', s.settings.consumableBarSkip.food == true and food.get() == false)
    food.set(true)
    check('switched on again, the entry goes', s.settings.consumableBarSkip.food == nil and food.get() == true)
    s.settings.consumableBarDeclined = { [20007] = true }
    rows['Ask Again for Declined Items'].button()
    check('Ask Again forgets the declined items', next(s.settings.consumableBarDeclined) == nil)
    check('the background opacity waits for its switch', rows['Background Opacity'].needs == 'consumableBarBackground')
    check('no Window card: the window is always solid', s.cards['Consumable Bar/Settings:window'] == nil
        and rows['Window Opacity'] == nil)
end

-- The card's preview: the bar as it is set, out of combat and in it
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512, 20007 },
        consumableBarItemFlags = { [5512] = { combat = true } } })
    local studio = s.cards['Consumable Bar/Settings:bar'].studio
    local holder = studio.new(s.frame('Frame'))
    studio.paint(holder, 'rest')
    check('two moments: out of combat and in it', #studio.states == 2)
    check('every item shows out of combat, on plain frames', holder.cells[1].shown and holder.cells[2].shown
        and holder.cells[3].shown and holder.cells[1].template == nil)
    check('at the bar\'s real size', holder.cells[1].w == 36 and holder.w == 3 * 40 - 4)
    check('with items, no note', not holder.note.shown)
    studio.paint(holder, 'combat')
    check('in combat an icon hidden in combat is gone', holder.cells[1].shown and not holder.cells[2].shown)
    s.set('consumableBarHideCombat', true)
    studio.paint(holder, 'combat')
    check('and Hide Bar in Combat hides them all', not holder.cells[1].shown and not holder.cells[3].shown)
    check('the stage fits one row', studio.height() == 90)
    s.set('consumableBarGrow', 'DOWN')
    check('a column makes it taller', studio.height() == 3 * 40 - 4 + 2 * s.CB.C.BG_PAD + 24)
    s.set('consumableBarHideCombat', false)
    s.set('consumableBarGrow', 'RIGHT')
    s.counts[5512] = 1
    s.set('consumableBarHideEmpty', true)
    studio.paint(holder, 'rest')
    check('Hide When Out leaves the preview what you carry', holder.cells[1].itemID == 5512
        and not holder.cells[2].shown and holder.w == 36)
    s.set('consumableBarItems', {})
    studio.paint(holder, 'rest')
    check('an empty bar says how to add items', holder.note.shown and not holder.cells[1].shown)
end

-- Dragging onto Edit Items
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512 },
        consumableBarItemFlags = { [5512] = { combat = true } } })
    local box = s.editor()
    local cells = box.cells
    local items = function() return table.concat(s.settings.consumableBarItems, ',') end
    check('the box takes a drop', box.mouse == true and box.scripts.OnReceiveDrag ~= nil)
    s.cursor = { 'item', 20007 }
    box.scripts.OnReceiveDrag(box)
    check('an item dropped on the box goes to the end', items() == '13446,5512,20007' and s.cursor == nil)
    s.cursor = { 'item', 8932 }
    cells[2].scripts.OnReceiveDrag(cells[2])
    check('one dropped on an icon goes before it', items() == '13446,8932,5512,20007')
    s.cursor = { 'item', 5512 }
    cells[1].scripts.OnReceiveDrag(cells[1])
    check('one already on the bar moves there', items() == '5512,13446,8932,20007')
    check('and keeps its settings', s.settings.consumableBarItemFlags[5512].combat == true)
    s.cursor = { 'item', 13446 }
    cells[4].scripts.OnReceiveDrag(cells[4])
    check('moving one later lands before the icon dropped on', items() == '5512,8932,13446,20007')
    s.cursor = { 'item', 2589 }
    box.scripts.OnReceiveDrag(box)
    check('cloth is refused and stays on the cursor', items() == '5512,8932,13446,20007' and s.cursor ~= nil
        and s.printed:find('not a consumable') ~= nil)
    cells[5].scripts.OnClick(cells[5], 'LeftButton')
    check('clicking + with cloth on the cursor neither adds it nor asks', items() == '5512,8932,13446,20007'
        and s.prompt == nil)
    s.cursor = { 'item', 10307 }
    cells[5].scripts.OnClick(cells[5], 'LeftButton')
    check('clicking + with an item on the cursor adds it, no prompt', items() == '5512,8932,13446,20007,10307'
        and s.prompt == nil)
    s.macros[22] = 'Mount'
    s.cursor = { 'macro', 22 }
    box.scripts.OnReceiveDrag(box)
    check('a macro is left on the cursor', #s.settings.consumableBarItems == 5 and s.cursor ~= nil)
    s.cursor = { 'spell', 133 }
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    check('a spell is no item: the right-click opens the settings as always', s.cursor ~= nil
        and #s.settings.consumableBarItems == 5 and s.side.shown)
end

-- Dragging an icon in Edit Items moves it on the bar
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512, 20007 },
        consumableBarItemFlags = { [13446] = { combat = true } } })
    local cells = s.editor().cells
    local items = function() return table.concat(s.settings.consumableBarItems, ',') end
    local function Drag(from, onto)
        local cell = cells[from]
        cell.scripts.OnDragStart(cell)
        s.focus = { onto }
        cell.scripts.OnDragStop(cell)
    end
    check('an icon can be dragged', cells[1].scripts.OnDragStart ~= nil and cells[1].scripts.OnDragStop ~= nil)
    cells[1].scripts.OnDragStart(cells[1])
    local ghost
    for _, f in ipairs(s.frames) do if f.scripts.OnUpdate and rawget(f, 'icon') and f.shown then ghost = f end end
    check('a copy of its icon follows the cursor, the icon fades', ghost and ghost.icon.texture == 134830
        and cells[1].alpha < 1)
    s.focus = { s.frame('Frame') }
    cells[1].scripts.OnDragStop(cells[1])
    check('let go off the bar, nothing moves', items() == '13446,5512,20007' and not ghost.shown
        and cells[1].alpha == 1)
    local list = s.settings.consumableBarItems
    Drag(2, cells[2])
    check('dropped on itself, nothing is saved', s.settings.consumableBarItems == list)
    Drag(1, cells[3])
    check('dropped on a later icon, it takes its place', items() == '5512,20007,13446')
    check('and keeps its settings', s.settings.consumableBarItemFlags[13446].combat == true)
    Drag(3, cells[1])
    check('dropped on an earlier one, it takes that place', items() == '13446,5512,20007')
    Drag(1, cells[4].plus)
    check('dropped on the + tile, it goes to the end', items() == '5512,20007,13446')
    cells[4].scripts.OnDragStart(cells[4])
    check('the + tile does not move', not ghost.shown)
    s.cursor = { 'item', 8932 }
    cells[1].scripts.OnDragStart(cells[1])
    check('nor does an icon while an item is on the cursor', not ghost.shown)
    s.cursor = nil
    s.set('consumableBarRect', true)
    s.set('consumableBarHeight', 20)
    cells[1].scripts.OnDragStart(cells[1])
    local tc = ghost.icon.texCoord
    check('the copy of a rectangular icon is cropped to its shape', ghost.h == 20
        and math.abs((tc[2] - tc[1]) / (tc[4] - tc[3]) - cells[1].w / 20) < 1e-9)
end

-- Edit Items draws the bar at its real size
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 5512, 20007 } })
    local box = s.editor()
    check('the preview bar is never scaled', box.bar.scale == 1 and box.cells[1].w == 36)
    check('the window says how many items', s.window.note.text.text == '3 items on the bar')
    box.view.w = 200
    s.set('consumableBarSize', 64)
    check('a bar wider than the window scrolls sideways', box.view.wheel == true and box.bar.scale == 1)
    check('it says so in the hint', box.hint.text:find('Scroll') ~= nil)
    s.set('consumableBarSize', 20)
    check('one that fits does not take the wheel', box.view.wheel == false and box.view.hscroll == 0)
    s.set('consumableBarGrow', 'DOWN')
    local tall = box.h
    s.set('consumableBarGrow', 'RIGHT')
    check('growing down makes it taller, not the icons smaller', tall > box.h and box.cells[1].w == 20)
end

-- The window is always solid, even for a player who had lowered the old opacity setting
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 }, consumableBarWindowAlpha = 0.6 })
    s.editor()
    check('the window opens solid, the old setting ignored', s.window.painted == 1)
    check('one item, said so', s.window.note.text.text == '1 item on the bar')
    check('the options can open it too', s.ns.OpenConsumableBarEditor == s.CB.OpenEditor)
end

-- Show Count
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    s.counts[13446] = 3
    s.fire('BAG_UPDATE_DELAYED')
    local b = s.buttons()[1]
    check('the count shows by default', b.count.shown and b.count.text == 3)
    s.set('consumableBarShowCount', false)
    check('Show Count off hides it', not b.count.shown)
    s.counts[13446] = 0
    s.fire('BAG_UPDATE_DELAYED')
    check('NONE still shows when out', b.none.shown)
end

-- Cooldowns
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    local timer = s.buttons()[1].timer
    s.cooldowns[13446] = { 100, 120, 1 }
    s.fire('BAG_UPDATE_COOLDOWN')
    check('an item cooldown shows', timer.shown and timer.cooldown[2] == 120)
    s.cooldowns[13446] = { { secret = true }, { secret = true }, 1 }
    s.fire('BAG_UPDATE_COOLDOWN')
    check('a secret cooldown leaves the last one drawn', timer.shown and timer.cooldown[1] == 100)
    s.set('consumableBarCooldown', false)
    check('cooldowns off stops listening for them', not s.listens('BAG_UPDATE_COOLDOWN'))
end

-- Edit Items: its + tile, and an item's settings beside it
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446, 20007, 2589 } })
    local box = s.editor()
    local cells = box.cells
    local store = s.stores['Consumable Bar/Item']
    local card = s.cards['Consumable Bar/Item:item']
    local function flags(id) return s.settings.consumableBarItemFlags[id] or {} end
    local function visible(label)
        local row = s.itemRow(label)
        return not (row.hidden and row.hidden())
    end
    check('the preview shows in the window', box.shown and s.window.shown)
    check('one cell per item plus the + tile', cells[4].isPlus and cells[4].shown and cells[3].itemID == 2589)
    s.set('consumableBarHideEmpty', true)
    check('an empty item stays in the preview as a ghost', cells[1].alpha > 0 and cells[1].alpha < 1)
    s.set('consumableBarHideEmpty', false)
    cells[4].scripts.OnClick(cells[4], 'LeftButton')
    s.prompt('5512')
    check('the + tile adds items by ID', s.settings.consumableBarItems[4] == 5512 and cells[5].isPlus)

    cells[1].scripts.OnClick(cells[1], 'LeftButton')
    check('a left-click on an icon opens nothing', s.side == nil)
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    check('right-click opens its settings beside it', s.side.shown and s.side.beside == cells[1])
    check('drawn as a settings page of its own, named for the item', card.name == 'Item13446'
        and s.renders['Consumable Bar/Item'] == 1)
    check('a potion offers Hide After Use', visible('Hide After Use'))
    check('what it tracks waits for Hide After Use', not visible('Tracks') and not visible('Show Before It Ends'))
    check('custom text waits for its switch', visible('Custom Text') and not visible('Text')
        and not visible('Font Size'))
    check('an unchanged setting reads its default', store.Get('combat') == false and store.Raw('combat') == nil
        and store.Default('earlySeconds') == 120)

    store.Set('combat', true)
    check('Hide in Combat saves per item', flags(13446).combat == true and store.Raw('combat') == true)
    check('a change leaves the redraw to the page, which waits out a slider drag',
        s.renders['Consumable Bar/Item'] == 1)
    store.Set('used', true)
    check('Hide After Use shows Tracks and Show Before It Ends', visible('Tracks')
        and visible('Show Before It Ends') and not visible('Show With'))
    store.Set('early', true)
    check('Show With waits for Show Before It Ends, two minutes to start', visible('Show With')
        and store.Get('earlySeconds') == 120)
    store.Set('earlySeconds', 150)
    check('it saves per item', flags(13446).earlySeconds == 150)
    store.Set('combat', false)
    check('switched back off, the setting goes', flags(13446).combat == nil)

    store.Set('textOn', true)
    check('the switch shows every text setting', visible('Text') and visible('Font') and visible('Font Size')
        and visible('Color') and visible('Position') and visible('Outside the Icon') and visible('X Offset')
        and visible('Y Offset'))
    store.Set('text', 'HP')
    check('custom text saves to the item', flags(13446).text == 'HP')
    check('the icon shows it, at the top by default', cells[1].custom.shown and cells[1].custom.text == 'HP'
        and cells[1].custom.point[1] == 'TOP')
    store.Set('textSize', 20)
    store.Set('textPoint', 'BOTTOM')
    store.Set('textOutside', true)
    check('the custom text follows its own settings', cells[1].custom.fontSize == 20
        and cells[1].custom.point[1] == 'TOP' and cells[1].custom.point[3] == 'BOTTOM')
    check('its font follows the count unless set', s.itemRow('Font').choice()[''] == 'Same as Count')
    store.Set('textOn', false)
    check('switching it off hides the text and its settings', not cells[1].custom.shown and not visible('Text'))
    check('and keeps the text for later', flags(13446).text == 'HP' and flags(13446).textOn == false)
    store.Set('textOn', true)
    check('switching it back on shows it again', cells[1].custom.shown and cells[1].custom.text == 'HP')

    cells[2].scripts.OnClick(cells[2], 'RightButton')
    check('another icon: the same panel, with its settings', s.side.beside == cells[2] and card.name == 'Item20007'
        and store.Get('text') == '' and not store.Get('textOn'))
    store.Set('combat', true)
    check('and what is set there is that item\'s', flags(20007).combat == true and flags(13446).combat == nil)
    cells[3].scripts.OnClick(cells[3], 'RightButton')
    check('an item with no use effect has no Hide After Use', not visible('Hide After Use'))
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    check('the panel has Remove From Bar', s.side.actions[1][1] == 'Remove From Bar')
    s.side.actions[1][2]()
    check('Remove From Bar takes the item off and closes the panel', s.settings.consumableBarItems[1] == 20007
        and not s.side.shown)
    check('and drops its settings', s.settings.consumableBarItemFlags[13446] == nil)
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    s.CB.RemoveItem(20007)
    check('an item taken off the bar elsewhere closes its settings', not s.side.shown)
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    check('the panel follows the window\'s opacity', s.side.opacity() == 1)
end

-- Ask to Add asks at the bar, even one with nothing on it yet, so the question shows where the item will go
do
    local s = fixture({ consumableBar = true, consumableBarAskNew = true })
    s.fire('BAG_UPDATE_DELAYED')
    check('an empty bar shows nothing', not s.bar.shown)
    s.bags[0] = { 5512 }
    s.counts[5512] = 1
    s.fire('BAG_UPDATE_DELAYED')
    local ask = s.panels[1]
    check('a new consumable is asked about at the empty bar', ask and ask.shown and ask.point
        and ask.point[1] == 'BOTTOM' and ask.point[2] == s.bar and ask.point[3] == 'TOP')
end

-- New consumables ask to be added
do
    local s = fixture({ consumableBar = true, consumableBarAskNew = true, consumableBarItems = { 13446 } })
    s.bags[0] = { 13446, 2589 }
    s.counts[13446] = (s.counts[13446] or 0) + 1
    s.counts[2589] = (s.counts[2589] or 0) + 1
    s.fire('BAG_UPDATE_DELAYED')
    local function popup()
        for _, f in ipairs(s.frames) do
            local icon = rawget(f, 'icon')
            if type(icon) == 'table' and rawget(icon, 'tex') then return f end
        end
    end
    check('what the bags held at first is not asked about', popup() == nil)
    s.bags[1] = { 5512, 2589 }
    s.counts[5512] = (s.counts[5512] or 0) + 1
    s.counts[2589] = (s.counts[2589] or 0) + 1
    s.fire('BAG_UPDATE_DELAYED')
    local ask = popup()
    check('a new consumable asks to be added', ask and ask.shown and ask.text.text:find('Item5512'))
    check('in the Shared kit\'s panel', s.panels[1] == ask)
    local add, no
    for _, f in ipairs(s.frames) do
        if f.parent == ask and f.label == 'Add' then add = f end
        if f.parent == ask and f.label == 'No' then no = f end
    end
    add.onClick()
    check('Add puts it on the bar', s.settings.consumableBarItems[2] == 5512 and not ask.shown)

    s.fight(true)
    s.bags[2] = { 20007 }
    s.counts[20007] = (s.counts[20007] or 0) + 1
    s.fire('BAG_UPDATE_DELAYED')
    check('nothing asks in combat', not ask.shown)
    s.fight(false)
    check('it asks when the fight ends', ask.shown and ask.itemID == 20007)
    no.onClick()
    check('No remembers the item', s.settings.consumableBarDeclined[20007] == true and not ask.shown)
    s.bags[2] = {}
    s.fire('BAG_UPDATE_DELAYED')
    s.bags[2] = { 20007 }
    s.counts[20007] = (s.counts[20007] or 0) + 1
    s.fire('BAG_UPDATE_DELAYED')
    check('a declined item never asks again', not ask.shown)
    check('cloth never asks', ask.itemID ~= 2589)
    s.CB.ForgetDeclined()
    check('Ask Again forgets the declined items', next(s.settings.consumableBarDeclined) == nil)
    s.set('consumableBarAskNew', false)
    s.bags[3] = { 12404 }
    s.counts[12404] = (s.counts[12404] or 0) + 1
    s.fire('BAG_UPDATE_DELAYED')
    check('with the option off nothing asks', not ask.shown)
end

-- An item that left the bags and is looted again is new again
do
    local s = fixture({ consumableBar = true, consumableBarAskNew = true, consumableBarItems = {} })
    s.fire('BAG_UPDATE_DELAYED')
    local function popup()
        for _, f in ipairs(s.frames) do
            local icon = rawget(f, 'icon')
            if type(icon) == 'table' and rawget(icon, 'tex') then return f end
        end
    end
    s.bags[0] = { 5512, 20007 }
    s.counts[5512], s.counts[20007] = 1, 1
    s.fire('BAG_UPDATE_DELAYED')
    local ask = popup()
    check('the first of two new items asks, the other waits', ask and ask.shown and ask.itemID == 5512)
    s.bags[0] = { 5512 }
    s.counts[20007] = 0
    s.fire('BAG_UPDATE_DELAYED')
    for _, f in ipairs(s.frames) do
        if f.parent == ask and f.label == 'Add' then f.onClick() end
    end
    check('the one used up meanwhile is not asked about', not ask.shown)
    s.bags[0] = { 5512, 20007 }
    s.counts[20007] = 1
    s.fire('BAG_UPDATE_DELAYED')
    check('looted again, it asks', ask.shown and ask.itemID == 20007)
end

do
    local s = fixture({ consumableBar = true, consumableBarAskNew = true, consumableBarDeclined = { [20007] = true } })
    s.fire('BAG_UPDATE_DELAYED')
    s.bags[0] = { 20007, 5512 }
    s.counts[20007] = (s.counts[20007] or 0) + 1
    s.counts[5512] = (s.counts[5512] or 0) + 1
    s.fire('BAG_UPDATE_DELAYED')
    local ask = s.panels[1]
    check('an item declined before is not asked about, a new one is', ask and ask.shown and ask.itemID == 5512)
end

-- Scan Bags and Clear
do
    local s = fixture({ consumableBarItems = { 13446 } })
    s.bags[0] = { 13446, 2589, 5512 }
    s.bags[2] = { 20007, 5512 }
    s.CB.ScanBags()
    local items = s.settings.consumableBarItems
    check('scan adds the consumables in bag order, once each', #items == 3 and items[2] == 5512 and items[3] == 20007)
    s.CB.ScanBags()
    check('a second scan with nothing new says so', s.printed:find('No consumables') ~= nil)
    s.CB.Clear()
    check('clear waits for the confirmation', #s.settings.consumableBarItems == 3)
    s.confirm()
    check('clear removes every item', #s.settings.consumableBarItems == 0)
end

-- Other Consumables are left to the player; Remove Empty
do
    local s = fixture({ consumableBar = true })
    s.bags[0] = { 13446, 17202, 5512 }
    s.counts[13446], s.counts[17202], s.counts[5512] = 2, 5, 1
    s.CB.ScanBags()
    local items = s.settings.consumableBarItems
    check('by default a scan leaves Other Consumables out', #items == 2 and not s.CB.Has(items, 17202))
    s.set('consumableBarSkip', {})
    s.CB.ScanBags()
    check('switched on, the next scan adds them', s.CB.Has(s.settings.consumableBarItems, 17202))
    s.CB.SetMacro('health', true)
    s.counts[13446], s.counts[17202] = 0, 0
    s.confirm = nil
    s.CB.RemoveEmpty()
    check('Remove Empty asks first, saying how many', s.confirm ~= nil
        and s.confirmText:find('Remove 2 items', 1, true) ~= nil and #s.settings.consumableBarItems == 4)
    s.confirm()
    items = s.settings.consumableBarItems
    check('then takes off the items you have none of and keeps Smart Macros', #items == 2 and items[1] == 5512
        and items[2] == 'macro:health')
    s.confirm = nil
    s.CB.RemoveEmpty()
    check('with nothing to take off it only says so', s.confirm == nil
        and s.printed:find('at least one of every item', 1, true) ~= nil)
end

do
    local s = fixture()
    local parse = s.CB.ParseItems
    local ids = parse('13446, 5512 13446')
    check('parses IDs once each, in order', #ids == 2 and ids[1] == 13446 and ids[2] == 5512)
    check('drops items the game does not know', parse('99999999') == nil)
    -- Bag items are named Item<id> by the mock.
    s.bags[0] = { 13446, 5512, 20007 }
    ids = parse('item5512')
    check('a name in the bags, case aside', ids and #ids == 1 and ids[1] == 5512)
    ids = parse('Item200')
    check('part of a name', ids and ids[1] == 20007)
    ids = parse('Item2000')
    check('a whole name wins over part of another', ids and ids[1] == 20007)
    local missing
    ids, missing = parse('13446, Item5512, |cffffffff|Hitem:20007::::::::60:::::|h[An, Elixir]|h|r, Thunderfury')
    check('IDs, names and links mixed, in order', ids and #ids == 3 and ids[1] == 13446 and ids[2] == 5512
        and ids[3] == 20007)
    check('a link with a comma in its name is still one item', #missing == 1)
    check('a name that matches nothing is reported', missing[1] == 'Thunderfury')
    s.CB.PromptAdd()
    s.prompt('Thunderfury')
    check('and the prompt says so', s.printed:find('No item called Thunderfury') ~= nil)
    s.prompt('2589, 13446, 18641')
    check('the + box adds consumables only', s.settings.consumableBarItems[1] == 13446
        and s.settings.consumableBarItems[2] == 18641 and #s.settings.consumableBarItems == 2)
    check('and names what it left out', s.printed:find('Item2589 is not a consumable') ~= nil)
    s.settings.consumableBarItems = nil
    s.prompt('Item13446, nothing')
    check('what was found is still added', s.settings.consumableBarItems[1] == 13446)
end

-- The background: each icon's own piece, so hidden icons leave no empty panel behind
do
    local s = fixture({ consumableBar = true, consumableBarBackground = true, consumableBarBgAlpha = 0.5,
        consumableBarPerRow = 2, consumableBarItems = { 13446, 5512, 20007 } })
    s.counts[13446], s.counts[5512] = 1, 1
    local b = s.buttons()
    local function reach(cell)
        local tl, br = cell.bg.points.TOPLEFT, cell.bg.points.BOTTOMRIGHT
        return -tl[4], br[4], tl[5], -br[5]
    end
    local l, r, t, bo = reach(b[1])
    check('to the edge of the bar: 3px; into the spacing: half of it', l == 3 and r == 2 and t == 3 and bo == 2)
    l, r, t, bo = reach(b[2])
    check('the end of a row reaches past it', l == 2 and r == 3 and t == 3 and bo == 3)
    l, r, t, bo = reach(b[3])
    check('a short last row has its own edges', l == 3 and r == 3 and t == 2 and bo == 3)
    check('shown at the chosen opacity', b[1].bg.shown and b[1].bg.alpha == 0.5)
    s.set('consumableBarHideEmpty', true)
    s.fire('BAG_UPDATE_DELAYED')
    check('an icon hidden when out takes its piece with it', not b[3].shown and b[1].shown)
    check('and the icon above its old place reaches past the bottom now', select(4, reach(b[1])) == 3)
    s.set('consumableBarHideEmpty', false)
    s.set('consumableBarGrow', 'DOWN')
    l, r, t, bo = reach(b[1])
    check('growing down: neighbours below and to the right', l == 3 and r == 2 and t == 3 and bo == 2)
    l, r, t, bo = reach(b[2])
    check('the bottom of a column reaches past it', l == 3 and r == 3 and t == 2 and bo == 3)
    s.set('consumableBarBackground', false)
    check('switched off, no piece shows', not b[1].bg.shown and not b[2].bg.shown)
    s.set('consumableBarBackground', true)
    local cells = s.editor().cells
    check('the preview draws it the same way, the + tile without', cells[1].bg.shown and not cells[4].bg.shown)
end

-- Its place: the HUD Editor's mover opens its card, and a drag is kept
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    check('the mover opens the bar\'s card', s.bar.mover.page == 'Consumable Bar/Settings'
        and s.bar.mover.card == 'Consumable Bar/Settings:bar')
    check('it starts under the middle of the screen', s.bar.point[1] == 'CENTER' and s.bar.point[5] == -260)
    s.bar.mover.onMoved({ point = 'TOPLEFT', relPoint = 'TOPLEFT', x = 10, y = -20 })
    check('a drag is saved', s.settings.consumableBarPos.x == 10)
    s.set('consumableBarSize', 40)
    check('and kept when the bar is laid out again', s.bar.point[1] == 'TOPLEFT' and s.bar.point[4] == 10)
end

-- Every setting the addon reads has its default in QoL's settings
do
    local function Read(path)
        local f = assert(io.open(path, 'rb'))
        local text = f:read('*a')
        f:close()
        return text
    end
    local qol = Read('Core/Settings.lua')
    local seen = {}
    local xml = Read('NaowhForever_Combat/ConsumableBar/ConsumableBar.xml')
    for file in xml:gmatch('<Script file="([^"]+)"') do
        local path = 'NaowhForever_Combat/ConsumableBar/' .. file:gsub('\\', '/')
        for key in Read(path):gmatch('"(consumableBar%w+)"') do
            -- Where it was dragged has none (it starts at its spot); the window's place is account-wide.
            if not seen[key] and key ~= 'consumableBarPos' and key ~= 'consumableBarWindow' then
                seen[key] = true
                check('a default for ' .. key, qol:find('%f[%w]' .. key .. ' = ') ~= nil)
            end
        end
    end
    check('the switch is a feature switch, off', qol:find('consumableBar = F.consumableBar', 1, true) ~= nil
        and Read('Core/Features.lua'):find('consumableBar = false', 1, true) ~= nil)
end

-- The Anchor card
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    local choose = s.pageRow('anchor', 'Anchor to a Unit Frame')
    local back, edit = choose.icons[1], choose.icons[2]
    check('its points wait for a frame', s.pageRow('anchor', 'Bar Point').needs() == false)
    check('Choose has the back icon and the edit cog, greyed out while not anchored',
        back.texture == s.ns.Shared.Style.RESET and edit.texture == nil and back.enabled() == false and edit.enabled() == false)
    local player = s.frame('Button', 'PlayerFrame', s.G.UIParent)
    function player:IsProtected() return true end
    player.attrs.unit = 'player'
    s.set('consumableBarAnchor', 'PlayerFrame')
    check('anchored, they work', s.pageRow('anchor', 'Bar Point').needs() == true and back.enabled() and edit.enabled())
    check('and the bar sits on the frame', s.bar.point[2] == player and s.bar.point[1] == 'CENTER')
    back.open()
    check('the back icon puts the bar on the screen', s.settings.consumableBarAnchor == 'UIParent'
        and s.bar.point[2] == s.G.UIParent and s.bar.point[5] == -260)
    s.set('consumableBarAnchor', 'PlayerFrame')
    s.bar.mover.onMoved({ point = 'TOPLEFT', relPoint = 'TOPLEFT', x = 10, y = -20 })
    check('dragging it in the HUD Editor puts it on the screen there', s.settings.consumableBarAnchor == 'UIParent'
        and s.bar.point[1] == 'TOPLEFT' and s.bar.point[4] == 10)
    s.frame('Frame', 'SomeAddonCastBar', s.G.UIParent)
    s.set('consumableBarAnchor', 'SomeAddonCastBar')
    check('a frame it may not hold to, typed in, leaves it on the screen', s.bar.point[2] == s.G.UIParent)
    s.set('consumableBarAnchor', 'LaterFrame')
    check('a frame not there yet: on the screen for now', s.bar.point[2] == s.G.UIParent)
    local later = s.frame('Button', 'LaterFrame', s.G.UIParent)
    function later:IsProtected() return true end
    later.attrs.unit = 'party1'
    s.fire('PLAYER_ENTERING_WORLD')
    check('it is looked up again on a loading screen', s.bar.point[2] == later)
    s.set('consumableBarAnchor', 'UIParent')
    local writes, applies = s.writes.consumableBarAnchor, s.applies
    s.bar.mover.onMoved({ point = 'TOP', relPoint = 'TOP', x = 5, y = 6 })
    check('a drag of a bar already on the screen writes no anchor and applies nothing',
        s.writes.consumableBarAnchor == writes and s.applies == applies and s.settings.consumableBarPos.x == 5)
    local food = s.frame('Frame', 'NaowhForeverFoodBar', s.G.UIParent)
    s.set('consumableBarAnchor', 'NaowhForeverFoodBar')
    check('a Naowh Forever element is not held here: that is the HUD Editor\'s', s.bar.point[2] ~= food)
end

-- Anchor to an Element: the HUD Editor's own anchoring, started for this bar
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    local follow = s.pageRow('anchor', 'Anchor to an Element')
    check('a row hands it to the HUD Editor', follow.buttonText == 'HUD Editor')
    local unit = s.frame('Button', 'PlayerFrame', s.G.UIParent)
    function unit:IsProtected() return true end
    unit.attrs.unit = 'player'
    s.set('consumableBarAnchor', 'PlayerFrame')
    follow.button()
    check('it lets go of a unit frame first, so one system places the bar',
        s.settings.consumableBarAnchor == 'UIParent' and s.bar.point[2] ~= unit)
    check('it opens the HUD Editor with this bar picking what to follow', s.hudOpen == true
        and s.hudPicking == s.bar.mover)
    s.ns.HideUnlockMode()
    s.set('consumableBar', false)
    s.hudPicking = nil
    follow.button()
    check('with the bar off it says so instead', s.hudPicking == nil
        and s.printed:find('Switch the Consumable Bar on') ~= nil)
end

-- The anchor picker: unit frames only; and the editor beside the bar
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    s.windowOpen = true
    local choose = s.pageRow('anchor', 'Anchor to a Unit Frame')
    local player = s.frame('Button', 'PlayerFrame', s.G.UIParent)
    function player:IsProtected() return true end
    player.attrs.unit = 'player'
    local portrait = s.frame('Texture', nil, player)
    s.hud.anchoredTo[s.bar.mover.label] = { target = 'Food & Drink', side = 'TOP' }
    choose.button()
    check('picking steps the options window aside', s.windowOpen == false)
    check('without the HUD Editor: unit frames show as they are', not s.hudOpen)
    local picker
    for _, f in ipairs(s.frames) do if f.scripts.OnUpdate and rawget(f, 'box') then picker = f end end
    check('the picker is the Shared kit\'s panel, named for the bar', s.panels[#s.panels] == picker
        and picker.title.text == 'Anchor the Consumable Bar')
    s.focus = { portrait }
    picker.scripts.OnUpdate(picker)
    check('the unit frame under the cursor is lit with its name',
        picker.highlight.shown and picker.highlight.text.text == 'PlayerFrame')
    s.focus = { s.bar }
    picker.scripts.OnUpdate(picker)
    check('the bar cannot pick itself', not picker.highlight.shown)
    s.focus = { s.buttons()[1] }
    picker.scripts.OnUpdate(picker)
    check('nor one of its own icons', not picker.highlight.shown)
    local foodBar = s.frame('Frame', 'NaowhForeverFoodBar', s.G.UIParent)
    s.focus = { s.frame('Button', 'NaowhForeverFoodBarFood', foodBar) }
    picker.scripts.OnUpdate(picker)
    check('nor a Naowh Forever element: those are the HUD Editor\'s', not picker.highlight.shown)
    s.focus = { s.frame('Frame', 'OtherCastBar', s.G.UIParent) }
    picker.scripts.OnUpdate(picker)
    check('nor another addon\'s frame', not picker.highlight.shown)
    s.focus = { portrait }
    picker.scripts.OnUpdate(picker)
    local opens = s.windowOpens or 0
    s.mouseDown = true
    picker.scripts.OnUpdate(picker)
    check('a click anchors the bar to that frame', s.settings.consumableBarAnchor == 'PlayerFrame' and s.bar.point[2] == player)
    check('and drops its HUD Editor anchor, so one system places it', s.hud.anchoredTo[s.bar.mover.label] == nil)
    check('picking stops, and the options stay aside', picker.scripts.OnUpdate == nil and not s.windowOpen
        and (s.windowOpens or 0) == opens)
    local editor = s.anchorEditor
    check('the points and offsets are set next, beside the bar, titled plainly', editor and editor.shown
        and editor.beside == s.bar and editor.title.text == 'Anchor Settings' and s.renders['Consumable Bar/Anchor'] >= 1)
    local card = s.cards['Consumable Bar/Anchor:anchor']
    check('its card is just Anchor', card.name == 'Anchor')
    check('its rows are the anchor\'s four settings', #card.rows == 4 and card.rows[1].key == 'consumableBarAnchorPoint'
        and card.rows[4].key == 'consumableBarY' and s.stores['Consumable Bar/Anchor'] == s.ns.QoLSettings)
    check('the bar is outlined while you edit it', s.bar.outline.shown)
    local renders = s.renders['Consumable Bar/Anchor']
    s.set('consumableBarX', 40)
    check('the bar moves as you edit', s.bar.point[4] == 40)
    check('and the editor leaves its redraw to the page, so a slider can be dragged',
        s.renders['Consumable Bar/Anchor'] == renders)
    editor.actions[1][2]()
    check('Cancel puts the offset back and brings the options back', s.settings.consumableBarX == 0
        and s.bar.point[4] == 0 and not editor.shown and s.windowOpen)
    check('and the outline goes', not s.bar.outline.shown)
    choose.icons[2].open()
    check('the edit icon opens it again, putting the options aside', editor.shown and not s.windowOpen)
    s.set('consumableBarY', -12)
    editor.actions[2][2]()
    check('Done keeps it', s.settings.consumableBarY == -12 and not editor.shown and s.windowOpen)
    choose.icons[2].open()
    s.set('consumableBarX', 5)
    editor:Hide()
    check('its x keeps it too', s.settings.consumableBarX == 5 and s.windowOpen and not s.bar.outline.shown)
    s.mouseDown = false
    choose.button()
    picker.box:SetText('NoSuchFrame')
    picker.box.scripts.OnEnterPressed(picker.box)
    check('a typed name that is no frame is refused', s.settings.consumableBarAnchor == 'PlayerFrame'
        and picker.scripts.OnUpdate ~= nil)
    for _, typed in ipairs({ 'OtherCastBar', 'NaowhForeverFoodBar', 'NaowhForeverConsumableBar',
        'NaowhForeverConsumableBarItem13446' }) do
        s.printed = nil
        picker.box:SetText(typed)
        picker.box.scripts.OnEnterPressed(picker.box)
        check('typed, it is refused too: ' .. typed, s.settings.consumableBarAnchor == 'PlayerFrame'
            and s.printed:find('cannot hold the bar') ~= nil)
    end
    picker.box.scripts.OnEscapePressed(picker.box)
    check('Esc cancels and brings the window back', picker.scripts.OnUpdate == nil and s.windowOpen)
    s.set('consumableBar', false)
    choose.icons[2].open()
    check('with the bar off there is nothing to edit', not editor.shown and s.printed:find('Switch the Consumable Bar on') ~= nil)
end

-- What a setting changes decides what runs: nothing for what the bar does not show, a restyle for
-- the look, the whole bar only for what it is built from
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 },
        consumableBarItemFlags = { [13446] = { textOn = true, text = 'HP' } } })
    local b = s.buttons()[1]
    local applies = s.applies
    for _, key in ipairs({ 'consumableBarSkip', 'consumableBarDeclined', 'consumableBarTooltip' }) do
        s.set(key, s.ns.QoLSettings.Get(key))
    end
    check('scan filters, declined items and tooltips apply nothing', s.applies == applies)
    s.set('consumableBarFontSize', 22)
    s.set('consumableBarKeyX', 4)
    check('the count and key text restyle without applying the bar', s.applies == applies
        and b.count.fontSize == 22 and b.key.point[4] == 4 - s.ns.Shared.ItemBar.TEXT_INSET)
    s.CB.SetFlag(13446, 'textX', 7)
    check('an item\'s own text moves without applying the bar', s.applies == applies
        and b.custom.point[4] == 7)
    s.fight(true)
    s.set('consumableBarFontSize', 18)
    check('in a fight a restyle waits for the end, as a layout does', b.count.fontSize == 22)
    s.fight(false)
    check('and is done then', b.count.fontSize == 18)
    applies = s.applies
    s.CB.SetFlag(13446, 'combat', true)
    check('Hide in Combat applies the bar, it sets a driver', s.applies > applies
        and driver(b) == '[combat] hide; show')
end

-- What waits to be asked about is checked again when it is shown
do
    local s = fixture({ consumableBar = true, consumableBarAskNew = true })
    s.fire('BAG_UPDATE_DELAYED')
    s.fight(true)
    s.bags[0] = { 13446, 20007, 5512 }
    s.counts[13446], s.counts[20007], s.counts[5512] = 1, 1, 1
    s.fire('BAG_UPDATE_DELAYED')
    s.set('consumableBarDeclined', { [13446] = true })
    s.counts[20007] = 0
    s.fight(false)
    local ask = s.panels[1]
    check('declined or gone in the fight, it is not asked about after it', ask and ask.shown and ask.itemID == 5512)
    for _, f in ipairs(s.frames) do
        if f.parent == ask and f.label == 'No' then f.onClick() end
    end
    s.fight(true)
    s.bags[1] = { 12404, 10307 }
    s.counts[12404], s.counts[10307] = 1, 1
    s.fire('BAG_UPDATE_DELAYED')
    s.fight(false)
    check('two wait, one is asked about', ask.shown and ask.itemID == 12404)
    s.set('consumableBarAskNew', false)
    s.set('consumableBarAskNew', true)
    s.fight(true)
    s.fight(false)
    check('switched off and on, what waited is forgotten', not ask.shown)
end

-- Consumable macros on the bar: the button runs the Macros module's macro by name
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    s.counts[5509] = 1
    s.pageRow('adding', 'NF Health').set(true)
    check('its switch adds it to the end of the bar', s.settings.consumableBarItems[2] == 'macro:health'
        and s.CB.HasMacro('health') and s.ns.ConsumableBarUsesMacro('health')
        and s.pageRow('adding', 'NF Health').get() == true)
    check('and asks Macros to write it, leaving its switch alone', s.macroSettings.health == nil
        and s.macroUpdates > 0)
    local b = s.buttons()[2]
    check('the button runs the macro by name', b.attrs.type1 == 'macro' and b.attrs.macro1 == 'NF Health'
        and b.attrs.item1 == nil)
    check('its button has a name to bind a key to', s.G.NaowhForeverConsumableBarHealth == b)
    check('not written yet: NONE and the macro icon', b.none.shown and b.icon.texture == 134829 and b.itemID == nil)
    check('its tooltip names the macro until then', b.emptyTip == 'Health (NF Health)' and not b.tipOff(b))

    s.macroBodies['NF Health'] = '#showtooltip\n/use item:5509'
    s.fire('UPDATE_MACROS')
    check('once the Macros module writes it, it shows the item', b.itemID == 5509 and b.icon.texture == 135230
        and b.count.text == 1 and not b.none.shown)
    s.fight(true)
    local blocked = s.blocked
    s.counts[13446] = 4
    s.macroBodies['NF Health'] = '#showtooltip\n/use item:13446'
    s.fire('UPDATE_MACROS')
    check('a rewrite needs nothing protected, so it shows even in combat', b.itemID == 13446
        and b.count.text == 4 and s.blocked == blocked and b.attrs.macro1 == 'NF Health')
    s.fight(false)
    s.counts[13446] = 0
    s.fire('BAG_UPDATE_DELAYED')
    check('out of the item the macro still names: NONE', b.none.shown and b.icon.texture == 134830)
    s.set('consumableBarHideEmpty', true)
    check('with Hide When Out it leaves the bar', not b.shown and b.slot == nil)
    s.counts[5509] = 1
    s.macroBodies['NF Health'] = '#showtooltip\n/use item:5509'
    s.fire('UPDATE_MACROS')
    check('and comes back when the macro is rewritten to an item you carry', b.shown and b.slot ~= nil
        and b.itemID == 5509)
    s.set('consumableBarHideEmpty', false)

    s.pageRow('adding', 'NF Health').set(false)
    check('switching it off takes it off the bar', not s.CB.HasMacro('health') and #s.buttons() == 1)
    check('its button is cleared and hidden', b.entry == nil and b.attrs.type1 == nil and b.attrs.macro1 == nil
        and not b.shown)
    check('the bar no longer counts as using it', not s.ns.ConsumableBarUsesMacro('health'))
    check('and its Macros switch was never touched', s.macroSettings.health == nil)
    s.macroSettings.mana = true
    s.CB.SetMacro('mana', true)
    s.CB.SetMacro('mana', false)
    check('one you had on already stays on', s.macroSettings.mana == true)
    s.CB.SetMacro('health', true)
    local updates = s.macroUpdates
    s.set('consumableBarSize', 40)
    s.fire('BAG_UPDATE_DELAYED')
    check('Macros is only asked again when the macros on the bar change', s.macroUpdates == updates)
    s.set('consumableBar', false)
    check('switching the bar off tells Macros once', s.macroUpdates == updates + 1
        and not s.ns.ConsumableBarUsesMacro('health'))
    s.set('consumableBarSize', 36)
    s.set('consumableBarItems', { 'macro:health', 13446 })
    check('while off, the bar costs Macros nothing', s.macroUpdates == updates + 1)
    s.set('consumableBar', true)
    check('and back on, it asks again', s.macroUpdates == updates + 2 and s.ns.ConsumableBarUsesMacro('health'))
end

-- Off at load, the bar never asks Macros for anything
do
    local s = fixture({ consumableBar = false, consumableBarItems = { 'macro:health' } })
    s.set('consumableBarItems', { 'macro:mana' })
    check('a bar that is off never asks Macros to update', s.macroUpdates == 0)
end

do
    local s = fixture({ consumableBar = true, consumableBarItems = { 'macro:mana', 13446, 'macro:health' } })
    local b = s.buttons()
    check('items and macros keep their order on the bar', b[1].entry == 'macro:mana' and b[2].entry == 13446
        and b[3].entry == 'macro:health')
    check('the bar uses every macro it carries', s.ns.ConsumableBarUsesMacro('mana')
        and s.ns.ConsumableBarUsesMacro('health') and s.macroUpdates == 1)
    check('the bar listens for macro rewrites', s.listens('UPDATE_MACROS'))
    s.set('consumableBarItems', { 13446 })
    check('with no macro on it, it stops listening', not s.listens('UPDATE_MACROS'))
    s.set('consumableBarItems', { 'macro:mana' })
    s.set('consumableBar', false)
    check('a bar switched off uses no macro', not s.ns.ConsumableBarUsesMacro('mana'))
end

-- Macros ships in NaowhForever_Utilities, so its files stay loaded while its switch is off: the bar
-- then carries no Smart Macro, as when the Macros addon was not loaded, and takes them back when it
-- is switched on again.
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 'macro:mana', 13446, 'macro:health' } })
    local function MacroRows()
        local n = 0
        for _, row in ipairs(s.cards['Consumable Bar/Settings:adding'].rows) do
            if row.label == 'NF Mana' and not (row.hidden and row.hidden()) then n = n + 1 end
        end
        return n
    end
    check('Macros on: its macros on the bar and offered', #s.buttons() == 3 and MacroRows() == 1)
    s.ns.MacroSettings.Set('enabled', false)
    check('Macros switched off: only the item stays, nothing of Macros is used or offered', #s.buttons() == 1
        and s.buttons()[1].entry == 13446 and not s.ns.ConsumableBarUsesMacro('mana') and MacroRows() == 0
        and not s.listens('UPDATE_MACROS'))
    s.ns.MacroSettings.Set('enabled', true)
    check('switched back on: the macros come back in their places', #s.buttons() == 3
        and s.buttons()[1].entry == 'macro:mana' and s.ns.ConsumableBarUsesMacro('health') and MacroRows() == 1)
end

-- A macro's key: on an action bar, known by the macro's name on the slot, or its own button's
do
    local s = fixture({ consumableBar = true, consumableBarKeybinds = true,
        consumableBarItems = { 'macro:health', 'macro:mana' } })
    s.bindings['CLICK NaowhForeverConsumableBarMana:LeftButton'] = 'ALT-M'
    -- Forever's GetActionInfo gives the spell or item a macro shows, not the macro's index.
    s.actions[7] = { 'macro', 5509 }
    s.actionText[7] = 'NF Health'
    s.actionButton(7, 'E')
    s.fire('ACTIONBAR_SLOT_CHANGED')
    s.advance(0)
    local b = s.buttons()
    check('a macro shows the key of the macro on an action bar', b[1].key.text == 'E')
    check('or the key bound to its own button', b[2].key.text == '*ALT-M')
end

-- A macro already written shows its item from the start, and Hide After Use reads its settings
do
    local s = fixture({ consumableBar = true, consumableBarItemFlags = { ['macro:health'] = { used = true, track = 'mainhand' } } })
    s.macroBodies['NF Health'] = '#showtooltip\n/use item:13446'
    s.counts[13446] = 2
    s.set('consumableBarItems', { 'macro:health' })
    local b = s.buttons()[1]
    check('a written macro shows its item once it is on the bar', b.itemID == 13446 and b.count.text == 2)
    s.enchant.main = 1800 * 1000
    s.fire('UNIT_INVENTORY_CHANGED', 'player')
    check('Hide After Use reads the macro\'s own settings: here, the weapon enchant', not b.shown
        and driver(b) == '[combat] show; hide')
end

-- A macro's settings in Edit Items are its own
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 'macro:health' } })
    s.macroBodies['NF Health'] = '#showtooltip\n/use item:13446'
    s.fire('UPDATE_MACROS')
    local cells = s.editor().cells
    check('its cell shows the item the macro uses', cells[1].entry == 'macro:health' and cells[1].itemID == 13446)
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    check('right-click opens them, named for the macro', s.side.shown
        and s.cards['Consumable Bar/Item:item'].name == 'Health (NF Health)')
    check('Hide After Use follows the item it uses', not s.itemRow('Hide After Use').hidden())
    s.stores['Consumable Bar/Item'].Set('combat', true)
    check('they are saved under the macro', s.settings.consumableBarItemFlags['macro:health'].combat == true)
    check('and the bar follows them', driver(s.buttons()[1]) == '[combat] hide; show')
    check('its Key row binds the macro\'s button',
        s.itemRow('Key').binding() == 'CLICK NaowhForeverConsumableBarHealth:LeftButton')
end

-- The Smart Macros group: the macros there while the Macros module is
do
    local s = fixture({ consumableBar = true })
    local card = s.cards['Consumable Bar/Settings:adding']
    check('a switch for each macro', s.pageRow('adding', 'NF Health') and s.pageRow('adding', 'NF Mana'))
    check('the Health priority behind its cog', s.pageRow('adding', 'NF Health').cog.title == 'Health Priority'
        and s.pageRow('adding', 'Use First').under == 'NF Health')
    s.pageRow('adding', 'Use First').set('potion')
    check('it sets the Macros module\'s priority', s.macroSettings.healthOrder == 'potion'
        and s.pageRow('adding', 'Use First').get() == 'potion')
    check("Food Only behind NF Food's cog", s.pageRow('adding', 'NF Food').cog.title == 'Food Only'
        and s.pageRow('adding', 'Food Only').under == 'NF Food' and s.pageRow('adding', 'Food Only').get() == false)
    s.pageRow('adding', 'Food Only').set(true)
    check("it is the Macros module's own Food Only", s.macroSettings.foodOnly == true
        and s.pageRow('adding', 'Food Only').get() == true)
    check('the card is drawn again when it changes there', card.watch[1] == s.ns.MacroSettings)
    local without = fixture({ consumableBar = true }, true)
    check('without the Macros module there are no macro rows', without.pageRow('adding', 'NF Health') == nil)
    without.cursor = { 'macro', 21 }
    without.macros[21] = 'NF Health'
    local box = without.editor()
    box.scripts.OnReceiveDrag(box)
    check('and a macro dropped is left on the cursor', without.cursor ~= nil and #(without.settings.consumableBarItems or {}) == 0)
end


-- No mana: no NF Mana, and no drinks or mana potions offered
do
    local s = fixture({ consumableBar = true }, false, 'WARRIOR')
    s.bags[0] = { 8766, 13444, 13446 }
    s.CB.ScanBags()
    check('Scan Bags skips drinks and mana potions', table.concat(s.settings.consumableBarItems, ',') == '13446')
    local box = s.editor()
    s.cursor = { 'item', 8766 }
    box.scripts.OnReceiveDrag(box)
    check('a drink dragged in asks first, saying why', s.confirm ~= nil and s.confirmText:find("You don't use mana", 1, true)
        and s.confirmText:find('Item8766', 1, true) and not s.CB.Has(s.settings.consumableBarItems, 8766))
    s.confirm()
    check('and goes on the bar when you say yes', s.CB.Has(s.settings.consumableBarItems, 8766))
    s.confirm = nil
    s.set('consumableBarItems', { 'macro:health' })
    s.CB.PromptAdd()
    s.prompt('13444, 13446, 20007')
    check('typed in with covered ones too, one question for both', s.confirmText:find('or they need mana', 1, true)
        and s.CB.Has(s.settings.consumableBarItems, 20007) and not s.CB.Has(s.settings.consumableBarItems, 13444))
    s.confirm()
    check('yes adds both', s.CB.Has(s.settings.consumableBarItems, 13444) and s.CB.Has(s.settings.consumableBarItems, 13446))
    local caster = fixture({ consumableBar = true })
    local casterBox = caster.editor()
    caster.cursor = { 'item', 8766 }
    casterBox.scripts.OnReceiveDrag(casterBox)
    check('a class with mana is not asked', caster.confirm == nil and caster.CB.Has(caster.settings.consumableBarItems, 8766))
    local rogue = fixture({ consumableBar = true, consumableBarItems = { 'macro:mana', 13446 } }, false, 'ROGUE')
    check("NF Mana from another character's profile is not shown", #rogue.buttons() == 1
        and rogue.buttons()[1].entry == 13446)
    check("but still used from Macros, as it is the caster's too",rogue.ns.ConsumableBarUsesMacro('mana')
        and rogue.macroUpdates == 1)
    local manaRow = rogue.pageRow('adding', 'NF Mana')
    check('its switch waits, saying why', manaRow.needs() == false and manaRow.why == "You don't use mana")
    rogue.set('consumableBarItems', { 13446 })
    manaRow.set(true)
    check('and it cannot be added', not rogue.CB.HasMacro('mana') and rogue.printed:find("don't use mana", 1, true))
    rogue.macros[23] = 'NF Mana'
    rogue.cursor = { 'macro', 23 }
    local rogueBox = rogue.editor()
    rogueBox.scripts.OnReceiveDrag(rogueBox)
    check('nor dragged in', not rogue.CB.HasMacro('mana') and rogue.cursor ~= nil)
    check('a class with mana has it as usual', caster.pageRow('adding', 'NF Mana').needs() == true)
end

-- The split macros cover their half: NF Healthstone and NF Health Potion, NF Drink only drinks, and
-- NF Food leaves drinks to NF Drink with Food Only on
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 'macro:healthstone', 'macro:drink' } })
    s.bags[0] = { 13446, 5512, 8932, 8766, 14530 }
    s.CB.ScanBags()
    check('NF Healthstone and NF Drink cover healthstones and drinks, not potions or food',
        table.concat(s.settings.consumableBarItems, ',') == 'macro:healthstone,macro:drink,13446,8932,14530')
    s.set('consumableBarItems', { 'macro:healthPotion', 'macro:food' })
    s.CB.ScanBags()
    check('NF Health Potion covers potions, NF Food food and drink',
        table.concat(s.settings.consumableBarItems, ',') == 'macro:healthPotion,macro:food,5512,14530')
    s.set('consumableBarItems', { 'macro:healthPotion', 'macro:food' })
    s.macroSettings.foodOnly = true
    s.CB.ScanBags()
    check('with Food Only, NF Food leaves drinks out',
        table.concat(s.settings.consumableBarItems, ',') == 'macro:healthPotion,macro:food,5512,8766,14530')
    check('each has its switch', s.pageRow('adding', 'NF Healthstone') and s.pageRow('adding', 'NF Health Potion')
        and s.pageRow('adding', 'NF Drink'))
    local warrior = fixture({ consumableBar = true, consumableBarItems = { 'macro:drink', 13446 } }, false, 'WARRIOR')
    check('a warrior gets no NF Drink, as no NF Mana', #warrior.buttons() == 1
        and warrior.pageRow('adding', 'NF Drink').needs() == false)
end

-- What a Smart Macro covers: Scan Bags and Ask to Add skip it, adding it by hand asks first
do
    local s = fixture({ consumableBar = true, consumableBarAskNew = true, consumableBarItems = { 'macro:health' } })
    s.bags[0] = { 13446, 5512, 20007 }
    s.CB.ScanBags()
    check('Scan Bags skips what NF Health covers', table.concat(s.settings.consumableBarItems, ',')
        == 'macro:health,20007')
    s.bags[1] = { 929 }
    KNOWN[929] = { 134830, 0, 441, 1 }
    s.fire('BAG_UPDATE_DELAYED')
    check('Ask to Add does not ask about it', s.panels[1] == nil or not s.panels[1].shown)
    local box = s.editor()
    s.cursor = { 'item', 13446 }
    box.scripts.OnReceiveDrag(box)
    check('dropped in by hand, it asks first', s.confirm ~= nil and not s.CB.Has(s.settings.consumableBarItems, 13446)
        and s.cursor == nil)
    check('saying which Smart Macro covers it', s.confirmText ==
        'NF Health already uses your best healthstone or healing potion. Add Item13446 too?')
    s.confirm()
    check('and goes on the bar when you say yes', s.CB.Has(s.settings.consumableBarItems, 13446))
    s.confirm = nil
    local cells = box.cells
    s.cursor = { 'item', 13446 }
    cells[1].scripts.OnReceiveDrag(cells[1])
    check('one already on the bar just moves, without asking', s.confirm == nil
        and s.settings.consumableBarItems[1] == 13446)
    s.macros[22] = 'NF Mana'
    s.cursor = { 'macro', 22 }
    box.scripts.OnReceiveDrag(box)
    check('an NF macro dragged from the macro window goes on the bar', s.CB.HasMacro('mana') and s.cursor == nil)
    s.confirm = nil
    s.CB.PromptAdd()
    s.prompt('5512, 10307')
    check('typed in, what is not covered goes on at once, the rest asks',
        s.CB.Has(s.settings.consumableBarItems, 10307) and not s.CB.Has(s.settings.consumableBarItems, 5512)
        and s.confirm ~= nil)
end

-- A character's edits keep what it does not show: a warrior adds, places, moves and removes, and the
-- NF Mana saved by a mage's profile stays saved, where it was
do
    local s = fixture({ consumableBar = true,
        consumableBarItems = { 'macro:mana', 13446, 20007 } }, false, 'WARRIOR')
    local function saved() return table.concat(s.settings.consumableBarItems, ',') end
    s.CB.AddItems({ 5512 })
    check('adding keeps them', saved() == 'macro:mana,13446,20007,5512')
    local box = s.editor()
    local cells = box.cells
    check('the bar shows the rest', cells[1].entry == 13446 and cells[2].entry == 20007 and cells[3].entry == 5512)
    cells[3].scripts.OnDragStart(cells[3])
    s.focus = { cells[1] }
    cells[3].scripts.OnDragStop(cells[3])
    check('moving keeps them, the moved one takes its place', saved() == 'macro:mana,5512,13446,20007')
    s.cursor = { 'item', 10307 }
    cells[3].scripts.OnReceiveDrag(cells[3])
    check('a drop goes before the icon it lands on, by entry', saved() == 'macro:mana,5512,13446,10307,20007')
    s.CB.RemoveItem(13446)
    check('removing keeps them', saved() == 'macro:mana,5512,10307,20007')
end

-- A Smart Macro saved while the Macros module is not loaded has no button, and stays saved
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 'macro:health', 13446 } }, true)
    check('no button for it', #s.buttons() == 1 and s.buttons()[1].entry == 13446)
    s.CB.AddItems({ 5512 })
    check('and it stays saved for when Macros is back', s.settings.consumableBarItems[1] == 'macro:health')
end

-- The Food & Drink buttons: the smart food and drink of the Food & Drink Bar, on the main bar
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 13446 } })
    s.bags[0] = { 8932, 8766 }
    s.counts[8932], s.counts[8766] = 3, 5
    local row = s.pageRow('adding', 'Food & Drink Buttons')
    row.set(true)
    check('its switch puts the food and the drink buttons at the end', table.concat(s.settings.consumableBarItems, ',')
        == '13446,smart:food,smart:drink' and row.get() == true)
    local food, drink = s.buttons()[2], s.buttons()[3]
    check('without QoL, named as the Food & Drink Bar\'s, so its keys click them', s.G.NaowhForeverFoodBarFood == food
        and s.G.NaowhForeverFoodBarDrink == drink)
    check('each uses your best one', food.attrs.item1 == 'item:8932' and drink.attrs.item1 == 'item:8766'
        and food.count.text == 3)
    s.counts[13446] = 2
    s.set('consumableBarHideEmpty', SHIPPED_HIDE_EMPTY)
    s.bags[0] = { 8766 }
    s.counts[8932] = 0
    s.fire('BAG_UPDATE_DELAYED')
    check('out of food with Hide When Out on, the default: it leaves the bar and the gap closes',
        not food.shown and #s.buttons() == 2 and s.buttons()[2] == drink and drink.slot == 2)
    s.set('consumableBarHideEmpty', false)
    check('with it off: nothing to use, NONE on its own empty icon and tooltip', food.shown
        and food.attrs.item1 == nil and food.none.shown and food.icon.texture == 133971
        and food.emptyTip == 'No food in your bags')
    s.fight(true)
    s.bags[0] = { 8932, 8766 }
    s.counts[8932] = 2
    local blocked = s.blocked
    s.fire('BAG_UPDATE_DELAYED')
    check('a bag change in a fight touches no secure button', s.blocked == blocked and food.attrs.item1 == nil)
    s.fight(false)
    check('it is pointed at the food when the fight ends', food.attrs.item1 == 'item:8932')
    check('the Food & Drink Bar steps aside', s.ns.ConsumableBarUsesFood() == true)
    s.set('consumableBar', false)
    check('unless the Consumable Bar is off', s.ns.ConsumableBarUsesFood() == false)
    s.set('consumableBar', true)
    row.set(false)
    check('switched off, both go', table.concat(s.settings.consumableBarItems, ',') == '13446'
        and not food.shown and not drink.shown and s.ns.ConsumableBarUsesFood() == false)
end

-- The Food & Drink buttons share the Food & Drink Bar's keys: one key, shown in both places
do
    local s = fixture({ consumableBar = true, consumableBarKeybinds = true, consumableBarItems = { 'smart:food' } })
    check('without QoL, the key bound to Use Best Food clicks the button itself', s.CB.BindAction('smart:food')
        == 'CLICK NaowhForeverFoodBarFood:LeftButton' and s.G.NaowhForeverFoodBarFood == s.buttons()[1])
    s.ns.FoodBarBindings = { food = 'CLICK NaowhForeverFoodBarFood:LeftButton',
        drink = 'CLICK NaowhForeverFoodBarDrink:LeftButton' }
    check('with QoL, the button has a name of its own, as that bar\'s hidden button has this one',
        s.CB.ButtonName('smart:food') == 'NaowhForeverConsumableBarSmartFood')
    check('with it, the food button binds the Food & Drink Bar\'s Use Best Food',
        s.CB.BindAction('smart:food') == 'CLICK NaowhForeverFoodBarFood:LeftButton'
        and s.CB.BindAction('smart:drink') == 'CLICK NaowhForeverFoodBarDrink:LeftButton')
    s.bindings['CLICK NaowhForeverFoodBarFood:LeftButton'] = 'F'
    s.fire('UPDATE_BINDINGS')
    s.advance(0)
    check('a key bound on the Food & Drink Bar shows on the button', s.buttons()[1].key.text == '*F')
    local cells = s.editor().cells
    cells[1].scripts.OnClick(cells[1], 'RightButton')
    check('and its Key row in Edit Items is that same binding',
        s.itemRow('Key').binding() == 'CLICK NaowhForeverFoodBarFood:LeftButton')
    check('an item keeps its own', s.CB.BindAction(13446) == 'CLICK NaowhForeverConsumableBarItem13446:LeftButton')
end

-- The Food & Drink buttons or NF Food and NF Drink: one or the other, saying which is in the way
do
    local s = fixture({ consumableBar = true })
    local food, drink = s.pageRow('adding', 'NF Food'), s.pageRow('adding', 'NF Drink')
    local buttons = s.pageRow('adding', 'Food & Drink Buttons')
    check('all are offered', food.needs() and drink.needs() and buttons.needs())
    buttons.set(true)
    check('with the buttons on, NF Food and NF Drink wait, saying why', food.needs() == false
        and drink.needs() == false and food.why == 'The Food & Drink buttons are on the bar'
        and drink.why() == 'The Food & Drink buttons are on the bar')
    food.set(true)
    check('and cannot be added', not s.CB.HasMacro('food') and s.printed:find('Take them off to use NF Food', 1, true))
    s.macros[21] = 'NF Drink'
    s.cursor = { 'macro', 21 }
    local box = s.editor()
    box.scripts.OnReceiveDrag(box)
    check('nor dragged in', not s.CB.HasMacro('drink') and s.cursor ~= nil)
    s.cursor = nil
    buttons.set(false)
    drink.set(true)
    check('the other way round, naming the macro', buttons.needs() == false
        and buttons.why() == 'NF Drink is on the bar')
    buttons.set(true)
    check('the buttons wait while NF Drink is on', not s.CB.HasFoodButtons()
        and s.printed:find('NF Drink is on the bar. Take it off', 1, true))
    drink.set(false)
    food.set(true)
    check('and while NF Food is on', buttons.why() == 'NF Food is on the bar')
end

-- No mana: the food button alone, a drink button saved by a caster's profile stays saved, and the
-- buttons cover drinks only for a class with mana
do
    local s = fixture({ consumableBar = true }, false, 'WARRIOR')
    s.pageRow('adding', 'Food & Drink Buttons').set(true)
    check('a warrior gets the food button alone', table.concat(s.settings.consumableBarItems, ',') == 'smart:food')
    s.bags[0] = { 8932, 8766, 13446 }
    s.CB.ScanBags()
    check('Scan Bags skips food, and drinks as ever', table.concat(s.settings.consumableBarItems, ',')
        == 'smart:food,13446')
    local box = s.editor()
    s.cursor = { 'item', 8766 }
    box.scripts.OnReceiveDrag(box)
    check("a drink dragged in asks as one you can't use, not as one the buttons cover",
        s.confirmText and s.confirmText:find("You don't use mana", 1, true) ~= nil)
    local rogue = fixture({ consumableBar = true, consumableBarItems = { 'smart:food', 'smart:drink' } }, false, 'ROGUE')
    check("a drink button from another character's profile is not shown", #rogue.buttons() == 1
        and rogue.buttons()[1].entry == 'smart:food')
    rogue.CB.AddItems({ 13446 })
    check('and stays saved', table.concat(rogue.settings.consumableBarItems, ',') == 'smart:food,smart:drink,13446')
    local mage = fixture({ consumableBar = true, consumableBarItems = { 'smart:food', 'smart:drink' } })
    mage.bags[0] = { 8932, 8766, 14530 }
    mage.CB.ScanBags()
    check('the buttons cover food and drink', table.concat(mage.settings.consumableBarItems, ',')
        == 'smart:food,smart:drink,14530')
end

-- Smart food/drink follows player levels and cache completion, including combat deferral.
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 'smart:drink' } })
    s.level, s.levels[8766], s.levels[1179] = 12, 45, 5
    s.bags[0], s.counts[8766], s.counts[1179] = { 8766, 1179 }, 1, 1
    s.fire('BAG_UPDATE_DELAYED')
    check('smart drink chooses an eligible lower rank', s.CB.Resolve('smart:drink') == 1179)
    s.level = 45
    s.fire('UNIT_LEVEL', 'target')
    check('another unit leveling leaves smart drink alone', s.CB.Resolve('smart:drink') == 1179)
    s.fight(true)
    s.fire('UNIT_LEVEL', 'player')
    check('smart drink level refresh waits in combat', s.CB.Resolve('smart:drink') == 1179)
    s.fight(false)
    check('smart drink upgrades after combat', s.CB.Resolve('smart:drink') == 8766)
    s.missing[8766] = true
    s.fire('BAG_UPDATE_DELAYED')
    check('smart drink skips unknown requirements', s.CB.Resolve('smart:drink') == 1179)
    s.missing[8766] = nil
    s.fire('GET_ITEM_INFO_RECEIVED', 8766, true)
    check('smart drink upgrades when item data arrives', s.CB.Resolve('smart:drink') == 8766)
end

-- One button left alone: either one is the Food & Drink buttons being on the bar, and each covers
-- only its own half; a lone drink button counts only for a class with mana, as only it shows it
do
    local s = fixture({ consumableBar = true, consumableBarItems = { 'smart:drink' } })
    check('the drink button alone keeps the Food & Drink Bar aside', s.ns.ConsumableBarUsesFood() == true
        and s.pageRow('adding', 'Food & Drink Buttons').get() == true)
    local pointed
    s.ns.FoodBarPoint = function(food, drink) pointed = { food, drink } end
    s.bags[0] = { 8932, 8766 }
    s.fire('BAG_UPDATE_DELAYED')
    check('a bag change hands what it found to the hidden Food & Drink Bar', pointed
        and pointed[1] == 8932 and pointed[2] == 8766)
    s.bags[0] = {}
    check('and holds NF Food back', s.pageRow('adding', 'NF Food').needs() == false)
    s.bags[0] = { 8932, 8766 }
    s.CB.ScanBags()
    check('it covers drinks, not food', table.concat(s.settings.consumableBarItems, ',') == 'smart:drink,8932')
    s.set('consumableBarItems', { 'smart:food' })
    s.CB.ScanBags()
    check('the food button alone covers food, not drinks', table.concat(s.settings.consumableBarItems, ',')
        == 'smart:food,8766')
    local box = s.editor()
    s.cursor = { 'item', 8932 }
    box.scripts.OnReceiveDrag(box)
    check('and says so when food is added by hand', s.confirmText
        == 'The food button already uses your best food. Add Item8932 too?')
    s.pageRow('adding', 'Food & Drink Buttons').set(false)
    check('its switch takes off whichever is there', #s.settings.consumableBarItems == 1
        and s.settings.consumableBarItems[1] == 8766)
    local warrior = fixture({ consumableBar = true, consumableBarItems = { 'smart:drink' } }, false, 'WARRIOR')
    check("a warrior's hidden drink button does not keep their Food & Drink Bar aside",
        warrior.ns.ConsumableBarUsesFood() == false and warrior.pageRow('adding', 'Food & Drink Buttons').get() == false)
end

print(checks .. ' consumable-bar checks passed')
