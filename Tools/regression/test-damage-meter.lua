-- Offline behavior checks for the Damage Meter (NaowhForever_DamageMeter) against stubs of the game's frames and
-- C_DamageMeter; they do not emulate the client. Amounts are tables here, so any arithmetic or comparison on a
-- value that is secret in combat fails the test, as it would in game. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Noop() end
local METHODS = { __index = function(_, k) if type(k) == "string" and k:find("^[A-Z]") then return Noop end end }

local function Region(kind, parent)
    local r = setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, events = {}, children = {},
        w = 0, h = 0, alpha = 1, level = 1, text = "", points = {} }, METHODS)
    function r:SetScript(k, fn) self.scripts[k] = fn end
    function r:HookScript(k, fn) self.scripts[k] = fn end
    function r:RegisterEvent(e) self.events[e] = true end
    function r:UnregisterEvent(e) self.events[e] = nil end
    function r:UnregisterAllEvents() self.events = {} end
    function r:RegisterForClicks() end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetWidth(w) self.w = w end
    function r:SetHeight(h) self.h = h end
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:ClearAllPoints() self.points = {} end
    function r:GetCenter() return self.centerX end
    function r:SetAlpha(a) self.alpha = a end
    function r:SetText(t) self.text = t end
    function r:SetTextColor(rr, g, b) self.textColor = { r = rr, g = g, b = b } end
    function r:GetText() return self.text end
    function r:SetFormattedText(fmt, ...) self.text = fmt:format(...) end
    -- the width the text takes, held to the width the region was given
    function r:GetStringHeight() return 14 end
    function r:SetFrameStrata(v) self.strata = v end
    function r:SetScale(v) self.scale = v end
    function r:SetReverseFill(v) self.reverse = v end
    function r:SetWordWrap(v) self.wrap = v end
    function r:IsMouseOver() return self.mouseOver == true end
    function r:GetAlpha() return self.alpha end
    function r:GetScale() return self.scale or 1 end
    function r:EnableMouse(v) self.mouse = v end
    function r:SetToplevel(v) self.toplevel = v end
    function r:GetStringWidth()
        local natural = self.stringWidth or 40
        if self.w > 0 then return math.min(natural, self.w) end
        return natural
    end
    function r:SetJustifyH(j) self.justify = j end
    function r:SetFrameLevel(l) self.level = l end
    function r:GetFrameLevel() return self.level end
    function r:SetMinMaxValues(lo, hi) self.barMin, self.barMax = lo, hi end
    function r:SetValue(v) self.barValue = v end
    function r:SetStatusBarColor(rr, g, b, a) self.color = { rr, g, b, a } end
    function r:SetStatusBarTexture(t) self.barTexture = t end
    function r:SetColorTexture(rr, g, b, a) self.solid = { rr, g, b, a } end
    function r:SetTexture(t, h, v) self.texture = t; self.wrap = { h, v } end
    function r:SetTexCoord(a, b, c, d) self.texCoord = { a, b, c, d } end
    function r:CreateTexture() return Region("Texture", self) end
    function r:GetLeft() return 100 end
    function r:GetTop() return 300 end
    function r:GetEffectiveScale() return self.scale or 1 end
    function r:StartMoving() self.dragging = true end
    function r:StartSizing(point) self.sizingFrom = point end
    function r:StopMovingOrSizing() self.dragging, self.sizingFrom = false, nil end
    return r
end

local THEME = {
    bg = { r = 0.1, g = 0.1, b = 0.1 }, panel = { r = 0.2, g = 0.2, b = 0.2 }, line = { r = 0.3, g = 0.3, b = 0.3 },
    fg = { r = 0.9, g = 0.9, b = 0.9 }, muted = { r = 0.6, g = 0.6, b = 0.6 }, accent = { r = 0, g = 0.5, b = 1 },
}
local CLASS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, ROGUE = { r = 1, g = 0.96, b = 0.41 } }
-- what the stub client calls secret: a flagged table, this number and this string
local SECRET_NUMBER, SECRET_TEXT = 424242, "secret-name"

-- A row of the settings page by its key (not the per-class ones), and a card by its id.
local function RowOf(page, key)
    for _, card in ipairs(page.cards) do
        for _, row in ipairs(card.rows) do
            if row.key == key and row.field == nil then return row, card end
        end
    end
end

local function CardOf(page, id)
    for _, card in ipairs(page.cards) do
        if card.id == id then return card end
    end
end

local function Amount(name) return setmetatable({ name = name }, { __tostring = function() return name end }) end

local function Source(name, class, total, rate, own, guid)
    return { name = name, classFilename = class, specIconID = 0, totalAmount = Amount(total), amountPerSecond = Amount(rate),
        isLocalPlayer = own == true, sourceGUID = guid }
end

local function Spell(id, total) return { spellID = id, totalAmount = total, amountPerSecond = total / 10 } end

-- a menu, as the game's builder hands it to the generator
local function Menu()
    local m = { items = {} }
    local function add(self, item) self.items[#self.items + 1] = item; return item end
    function m:CreateTitle(text) return add(self, { kind = "title", text = text }) end
    function m:CreateDivider() return add(self, { kind = "divider" }) end
    function m:CreateButton(text, onClick)
        local item = Menu(); item.kind, item.text, item.onClick = "button", text, onClick
        return add(self, item)
    end
    function m:CreateRadio(text, isSelected, set)
        return add(self, { kind = "radio", text = text, selected = isSelected, set = set })
    end
    function m:CreateCheckbox(text, isSelected, set)
        return add(self, { kind = "check", text = text, selected = isSelected, set = set })
    end
    function m:Find(text)
        for _, item in ipairs(self.items) do
            if item.text == text then return item end
        end
    end
    return m
end

local function Boot(opts)
    opts = opts or {}
    local s = { settings = opts.settings or {}, calls = {}, idCalls = {}, spellCalls = {}, spellIdCalls = {},
        durationCalls = {}, duration = 125, enemyCalls = {}, enemyIdCalls = {},
        cvars = { damageMeterEnabled = opts.gameMeter or "1" }, timers = {}, printed = {}, frames = {}, buttons = {},
        confirms = {}, prompts = {}, modals = {}, shells = {}, hooks = {}, account = {}, sent = {}, movers = {}, names = { [101] = "Fireball", [102] = "Pyroblast" } }
    local defaults
    local store = {}
    function store.Get(k)
        local v = s.settings[k]
        if v == nil then v = defaults[k] end
        return v
    end
    local listeners = {}
    function store.OnChange(fn) listeners[#listeners + 1] = fn end
    function store.Set(k, v)
        s.settings[k] = v
        for _, fn in ipairs(listeners) do fn(k, v) end
    end
    function store.DB() return s.settings end
    function store.Raw(k) return s.settings[k] end
    function store.Default(k) return defaults[k] end
    local session = { combatSources = { Source("Aldrin", "MAGE", "A", "a", false, "Player-2"),
        Source("You", "ROGUE", "B", "b", true, "Player-1"), Source("Cara", "MAGE", "C", "c", false, "Player-3") },
        maxAmount = Amount("max"), totalAmount = Amount("total") }
    s.session = session
    s.spells = { combatSpells = { Spell(101, 600), Spell(102, 300), Spell(103, 100) }, maxAmount = 600, totalAmount = 1000 }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, THEME = THEME, MEDIA = "Media\\",
        FEATURES = { damageMeter = { enabled = false } },
        UI = {
            ModuleSettings = function(_, d) defaults = d; return store end,
            TexturePath = function(name, fallback) return name ~= "" and name or fallback end,
            RefreshPage = function() s.refreshed = (s.refreshed or 0) + 1 end,
            KeepFont = function(panel, key, size, outline, color)
                panel.kept = panel.kept or {}
                local fs = panel.kept[key] or Region("FontString", panel)
                panel.kept[key] = fs
                return fs
            end,
            KeepButton = function(panel, key, text, w, h, onClick)
                panel.kept = panel.kept or {}
                local b = panel.kept[key] or Region("Button", panel)
                b.label, b.onClick = text, onClick
                panel.kept[key] = b
                return b
            end,
            AttachMover = function(frame, label, onSave, page, card)
                local m = Region("Mover", frame)
                s.mover = m
                s.movers[label] = { mover = m, save = onSave, page = page, card = card }
                return m
            end,
        },
        Shared = {
            Style = { ICON_CROP = 0.08, ALPHA_RANGE = { 0, 100, 5 }, OPACITY_STEP = 5, PERCENT_SCALE = 0.01 },
            Parts = { HudFont = function(fs, font, size, outline) fs.fontSize = size; fs.font = font; fs.outline = outline end,
                HUD_OUTLINES = { { NONE = "None", [""] = "Shadow", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
                    { "NONE", "", "OUTLINE", "THICKOUTLINE" } } },
            Settings = { Group = function(name) return { group = name } end, Look = function(_, o) return { look = o } end,
                Page = function(_, st)
                    local page = { store = st, cards = {} }
                    function page:Window(def) self.window = def; return self end
                    function page:Card(def)
                        if type(def.rows) == "function" then def.rowsFn, def.rows = def.rows, {} end
                        self.cards[#self.cards + 1] = def; s.page = self; return self
                    end
                    return page
                end },
        },
        Solid = function(parent) return Region("Solid", parent) end,
        Border = function(frame)
            return { _frame = Region("Border", frame),
                SetColor = function(self, r, g, b, a) self.color = { r = r, g = g, b = b, a = a } end }
        end,
        Font = function(parent) return Region("FontString", parent) end,
        Button = function(parent, text, w, h, onClick)
            local b = Region("Button", parent); b.label = text; b.onClick = onClick
            s.buttons[#s.buttons + 1] = b
            return b
        end,
        SetButtonText = function(b, text) b.label = text end,
        Tooltip = Noop, AllowOffscreen = Noop,
        Confirm = function(text, yes) s.confirms[#s.confirms + 1] = { text = text, yes = yes } end,
        PromptText = function(title, text, max, accept) s.prompts[#s.prompts + 1] = { title = title, max = max, accept = accept } end,
        ShowCopyBox = function(title, text) s.copied = { title = title, text = text } end,
        MakeModal = function(w, h, key)
            local shell = s.shells[key]
            if not shell then
                local dimmer = Region("Frame")
                dimmer.shown = false
                shell = { key = key, dimmer = dimmer, panel = Region("Frame", dimmer) }
                s.shells[key] = shell
                s.modals[#s.modals + 1] = shell
            end
            shell.panel.w, shell.panel.h = w, h
            return shell.dimmer, shell.panel
        end,
        Print = function(t) s.printed[#s.printed + 1] = t end,
        OpenOptionsWindow = function(name) s.opened = name end,
        AccountSettings = function() return s.account end,
        Apply = Noop, ShowUnlockMode = Noop, HideUnlockMode = Noop,
    }
    local env = { ipairs = ipairs, pairs = pairs, type = type, select = select, tostring = tostring, tonumber = tonumber,
        math = math, table = table, string = string, setmetatable = setmetatable, pcall = pcall, unpack = unpack,
        UIParent = Region("Frame"), NaowhForever = ns, RAID_CLASS_COLORS = CLASS,
        InCombatLockdown = function() return s.combat == true end,
        IsInGroup = function(category) if category == 2 then return s.instanceGroup == true end return s.group == true end,
        IsInRaid = function() return s.raid == true end,
        IsInGuild = function() return s.guild == true end,
        IsInInstance = function() return s.instance == true, s.instanceType end,
        LE_PARTY_CATEGORY_INSTANCE = 2,
        UnitGUID = function(unit) if unit == "player" then return s.playerGUID or "Player-1" end end,
        UnitName = function(unit)
            if unit == "player" then return s.ownName or "You", s.ownSurname end
            local u = s.units and s.units[unit]
            if u then return u.name, u.surname end
        end,
        UnitClass = function(unit)
            if unit == "player" then return "Rogue", s.ownClass or "ROGUE" end
            local u = s.units and s.units[unit]
            if u then return u.class, u.class end
        end,
        UnitExists = function(unit) return unit == "player" or (s.units ~= nil and s.units[unit] ~= nil) end,
        UnitIsPlayer = function(unit) return not (s.units and s.units[unit] and s.units[unit].npc) end,
        UnitIsUnit = function(a, b)
            if a == b then return true end
            local u = s.units and s.units[a]
            return u ~= nil and u.self == true and b == "player"
        end,
        GetNumGroupMembers = function() return s.members or 1 end,
        Ambiguate = function(name) return (name:gsub("%-.+$", "")) end,
        Constants = opts.separator and { CharacterNameSeparatorConsts = {
            CHARACTERNAME_SURNAME_SEPARATOR = opts.separator } } or nil,
        C_PlayerInfo = opts.forever and { ShouldDisplaySurname = function() return s.showSurname ~= false end } or nil,
        SendChatMessage = function(text, channel) s.sent[#s.sent + 1] = { text = text, channel = channel } end,
        issecretvalue = function(v)
            return (type(v) == "table" and v.secret == true) or v == SECRET_NUMBER or v == SECRET_TEXT
        end,
        AbbreviateLargeNumbers = function(n) return "<" .. tostring(n) .. ">" end,
        CreateAbbreviateConfig = function(rows) s.configs = (s.configs or 0) + 1; return { rows = rows } end,
        AbbreviateNumbers = function(n, options)
            s.abbreviated = { n = n, rows = options.config.rows }
            return "{" .. tostring(n) .. ":" .. #options.config.rows .. "}"
        end,
        GetLocale = function() return s.locale or "enUS" end,
        LibStub = function() return s.lsm end,
        GetTime = function() return s.now or 0 end,
        time = function() return s.clock or 1700000000 end,
        date = os.date,
        GetInstanceInfo = function() return s.instanceName, nil, nil, nil, nil, nil, nil, s.instanceID end,
        GetZoneText = function() return s.zone or "Plains" end,
        Screenshot = function() s.shots = (s.shots or 0) + 1 end,
        CLASS_SORT_ORDER = opts.classes,
        LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", ROGUE = "Rogue" },
        Enum = { DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, DamageTaken = 7,
                AvoidableDamageTaken = 8, Absorbs = 4, Interrupts = 5, Dispels = 6, Deaths = 9, EnemyDamageTaken = 10 },
            DamageMeterSessionType = { Overall = 0, Current = 1 } },
        C_DamageMeter = {
            GetCombatSessionFromType = function(kind, type)
                s.calls[#s.calls + 1] = { kind, type }
                if s.apiError then error("secret") end
                if s.apiResult ~= nil then return s.apiResult end
                return s.byType and s.byType[type] or session
            end,
            GetCombatSessionFromID = function(id, type)
                s.idCalls[#s.idCalls + 1] = { id, type }
                if s.apiError then error("secret") end
                return s.idResult == nil and session or s.idResult
            end,
            GetSessionDurationSeconds = function(kind)
                s.durationCalls[#s.durationCalls + 1] = kind
                if s.durationError then error("secret") end
                return s.duration
            end,
            GetAvailableCombatSessions = function()
                if s.fightsError then error("secret") end
                return s.fights or {}
            end,
            IsDamageMeterAvailable = function()
                if s.unavailable then return false, s.unavailable end
                return true, ""
            end,
            GetCombatSessionSourceFromType = function(kind, type, guid, creature)
                if type == 10 then
                    s.enemyCalls[#s.enemyCalls + 1] = { kind = kind, guid = guid, creature = creature }
                    return s.enemyData and s.enemyData[guid]
                end
                s.spellCalls[#s.spellCalls + 1] = { kind = kind, type = type, guid = guid, creature = creature }
                if s.spellError then error("secret") end
                if s.spellsResult ~= nil then return s.spellsResult end
                return s.spells
            end,
            GetCombatSessionSourceFromID = function(id, type, guid, creature)
                if type == 10 then
                    s.enemyIdCalls[#s.enemyIdCalls + 1] = { id = id, guid = guid, creature = creature }
                    return s.enemyData and s.enemyData[guid]
                end
                s.spellIdCalls[#s.spellIdCalls + 1] = { id = id, type = type, guid = guid, creature = creature }
                return s.spells
            end,
            ResetAllCombatSessions = function() s.resets = (s.resets or 0) + 1 end,
        },
        GameTooltip = {
            SetOwner = function(_, owner, anchor) s.tip = { owner = owner, anchor = anchor, shown = false } end,
            SetSpellByID = function(_, id) s.tip.spell = id end,
            Show = function() s.tip.shown = true end,
            Hide = function() if s.tip then s.tip.shown = false end end,
            GetOwner = function() return s.tip and s.tip.shown and s.tip.owner or nil end,
        },
        C_Spell = {
            GetSpellName = function(id) return s.names[id] end,
            GetSpellTexture = function(id)
                if s.noTexture then error("bad argument") end
                return 1000 + id
            end,
        },
        MenuUtil = {
            CreateContextMenu = function(owner, generator)
                local root = Menu()
                root.owner = owner
                generator(owner, root)
                s.menu = root
            end,
        },
        C_CVar = { GetCVar = function(k) return s.cvars[k] end, SetCVar = function(k, v) s.cvars[k] = v end },
        C_Timer = { After = function(sec, fn) s.timers[#s.timers + 1] = { sec = sec, fn = fn } end },
        hooksecurefunc = function(tbl, name, fn)
            local original = tbl[name]
            tbl[name] = function(...) local r = original(...); fn(...); return r end
        end,
        CreateFrame = function(kind, name, parent)
            local f = Region(kind, parent)
            f.name = name
            s.frames[#s.frames + 1] = f
            return f
        end,
    }
    env._G = env
    env.UIParent.w = 1000
    local files = { "DamageMeter.lua", "Constants.lua", "Data/Samples.lua", "Source.lua", "Numbers.lua", "Spells.lua", "Looks.lua", "Names.lua", "Report.lua",
        "History.lua", "View/Meter.lua", "View/Breakdown.lua", "UI/History.lua", "UI/Menus.lua", "UI/Meter.lua",
        "UI/ImageHelp.lua", "UI/SettingsPage.lua" }
    for _, file in ipairs(files) do
        local chunk = assert(loadfile("NaowhForever_DamageMeter/" .. file))
        setfenv(chunk, env)
        chunk("NaowhForever")
    end
    s.ns, s.store, s.env = ns, store, env
    if opts.media then
        local all = { Marble = true, Dots = true, Solid = true, ["Blizzard Tooltip"] = true,
            ["Blizzard Out of Control"] = true, ["Blizzard Low Health"] = true, None = true }
        s.lsm = { List = function(_, kind)
                return kind == "background" and { "Marble", "Dots", "Solid", "Blizzard Tooltip",
                    "Blizzard Out of Control", "Blizzard Low Health", "None" } or {}
            end,
            Fetch = function(_, kind, name)
                if kind == "background" and all[name] then return "Media\\" .. name end
            end }
    end
    s.DM = ns.DamageMeter
    for _, f in ipairs(s.frames) do
        if f.events and f.events.PLAYER_LOGIN then s.boot = f end
    end
    function s.Login() s.boot.scripts.OnEvent(s.boot, "PLAYER_LOGIN") end
    local function Named(name)
        for _, f in ipairs(s.frames) do
            if f.name == name then return f end
        end
    end
    function s.Window(i) return Named(i and i > 1 and "NaowhForeverDamageMeter" .. i or "NaowhForeverDamageMeter") end
    function s.Panel() return Named("NaowhForeverDamageMeterBreakdown") end
    function s.Fire(event, ...)
        for _, f in ipairs(s.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end
    function s.Flush()
        local due = s.timers
        s.timers = {}
        for _, t in ipairs(due) do t.fn() end
    end
    function s.Listening()
        for _, f in ipairs(s.frames) do
            for e in pairs(f.events) do
                if e:find("^DAMAGE_METER") then return true end
            end
        end
        return false
    end
    function s.Hover(w, i)
        local row = w.rows[i]
        row.scripts.OnEnter(row)
        return row
    end
    return s
end

-- the data: defaults, modes, and the API read
do
    local s = Boot()
    check("off by default", s.ns.FEATURES.damageMeter.enabled == false and s.store.Get("enabled") == false)
    check("class colors by default", s.store.Get("barColor") == "class")
    local DM = s.DM
    local C = DM.C
    check("ten lists, in order", #C.MODES == 10 and C.MODE_ORDER[1] == "damage" and C.MODE_ORDER[2] == "dps"
        and C.MODE_ORDER[4] == "hps" and C.MODE_ORDER[6] == "avoidable" and C.MODE_ORDER[10] == "deaths")
    check("DPS and HPS are the game's own lists and lead with the per-second figure",
        DM.Mode("dps").type == "Dps" and DM.Mode("hps").type == "Hps" and DM.Mode("dps").rateFirst == true
        and DM.Mode("damage").rateFirst == nil)
    check("each has its game type", DM.Mode("healing").type == "HealingDone" and DM.Mode("deaths").type == "Deaths"
        and DM.Mode("avoidable").type == "AvoidableDamageTaken" and DM.Mode("interrupts").rate == false
        and DM.Mode("damage").rate == true)
    check("an unknown list reads as Damage Done", DM.Mode("bogus").key == "damage" and DM.Mode(nil).key == "damage")
    check("the API is there", DM.Available() == true)
    s.unavailable = "Not here."
    local ok, why = DM.Available()
    check("the game says no: not available, with its reason", ok == false and why == "Not here."
        and #DM.Session("damage", "current").combatSources == 0 and #s.calls == 0)
    s.unavailable = nil
    local got = DM.Session("taken", "overall")
    check("the session is the API's, by session type and list type",
        got == s.session and s.calls[1][1] == 0 and s.calls[1][2] == 7)
    DM.Session("damage", "current")
    check("current is the current session", s.calls[2][1] == 1 and s.calls[2][2] == 0)
    s.apiError = true
    check("an error from the API reads as nothing", #DM.Session("damage", "current").combatSources == 0)
    s.apiError = nil
    s.apiResult = "no"
    check("a result that is not a session reads as nothing", #DM.Session("damage", "current").combatSources == 0)
    s.apiResult = {}
    check("one without its sources too", #DM.Session("damage", "current").combatSources == 0)
    s.env.C_DamageMeter = nil
    check("no API: not available, and nothing", DM.Available() == false and #DM.Session("damage", "current").combatSources == 0)
    DM.Reset()
    check("and a reset does nothing", s.resets == nil)
    check("and there are no fights", #DM.Fights() == 0)
end

-- past fights: the list, their labels and reading one by its id
do
    local s = Boot()
    local DM = s.DM
    local got = DM.Session("healing", "overall", 7)
    check("a fight is read by its id and the list's type", got == s.session and s.idCalls[1][1] == 7
        and s.idCalls[1][2] == 2 and #s.calls == 0)
    s.apiError = true
    check("a fight the game errors on reads as nothing", #DM.Session("damage", "current", 7).combatSources == 0)
    s.apiError = nil
    s.fights = { { sessionID = 3, name = "Boss", durationSeconds = 125 }, { sessionID = 5, name = "", durationSeconds = 61 },
        { sessionID = 4 } }
    local fights = DM.Fights()
    check("past fights, newest first", #fights == 3 and fights[1].id == 5 and fights[2].id == 4 and fights[3].id == 3)
    check("with the name the game gives", fights[3].name == "Boss" and fights[1].name == nil)
    check("labeled by name and length", DM.FightLabel(fights[3]) == "Boss (2:05)" and DM.FightLabel(fights[1]) == "Fight 5 (1:01)"
        and DM.FightLabel(fights[2]) == "Fight 4")
    check("a session's name", DM.SessionName("overall") == "Overall" and DM.SessionName("bogus") == "Current"
        and DM.SessionName("current", 3) == "Boss (2:05)" and DM.SessionName("current", 99) == "Fight 99")
    s.fights = {}
    for i = 1, 15 do s.fights[i] = { sessionID = i } end
    local many = DM.Fights()
    check("at most ten, the newest", #many == 10 and many[1].id == 15 and many[10].id == 6)
    s.fights = { { sessionID = SECRET_NUMBER }, { sessionID = 2, name = SECRET_TEXT, durationSeconds = SECRET_NUMBER },
        "junk" }
    local plain = DM.Fights()
    check("a secret id is skipped, a secret name or length left off", #plain == 1 and plain[1].id == 2
        and plain[1].name == nil and plain[1].seconds == nil)
    s.fightsError = true
    check("an error from the API: no fights", #DM.Fights() == 0)
end

-- how long the shown session has run
do
    local s = Boot()
    local DM = s.DM
    check("the current session's length, from the game", DM.Duration("current") == 125 and s.durationCalls[1] == 1)
    check("and the overall one's", DM.Duration("overall") == 125 and s.durationCalls[2] == 0)
    s.duration = SECRET_NUMBER
    check("a secret length reads as nothing", DM.Duration("current") == nil)
    s.duration = "soon"
    check("so does one that is no number", DM.Duration("current") == nil)
    s.duration = 125
    s.durationError = true
    check("and an error from the API", DM.Duration("current") == nil)
    s.durationError = nil
    s.fights = { { sessionID = 3, durationSeconds = 61 }, { sessionID = 4 } }
    check("a past fight's length is the game's list's", DM.Duration("current", 3) == 61 and DM.Duration("current", 4) == nil
        and DM.Duration("current", 9) == nil)
    check("a clock reads m:ss, and h:mm:ss from an hour", DM.Clock(0) == "0:00" and DM.Clock(65) == "1:05"
        and DM.Clock(59.9) == "0:59" and DM.Clock(600) == "10:00" and DM.Clock(3599) == "59:59"
        and DM.Clock(3600) == "1:00:00" and DM.Clock(3725) == "1:02:05")
    s.env.C_DamageMeter.GetSessionDurationSeconds = nil
    check("an API without it reads as nothing", DM.Duration("current") == nil)
    s.env.C_DamageMeter = nil
    check("and no API", DM.Duration("current") == nil)
end

-- the spells behind a row
do
    local s = Boot()
    local DM = s.DM
    local you = Source("You", "ROGUE", 5, 1, true, "Player-9")
    local other = Source("Aldrin", "MAGE", 5, 1, false, "Player-2")
    local data = DM.SourceSpells("damage", "current", nil, you)
    local call = s.spellCalls[1]
    check("your row asks with your own guid, the list's type and no creature", data == s.spells and call.guid == "Player-1"
        and call.type == 0 and call.kind == 1 and call.creature == nil)
    DM.SourceSpells("damage", "overall", nil, other)
    check("another row asks with its guid, for the overall session", s.spellCalls[2].guid == "Player-2" and s.spellCalls[2].kind == 0)
    DM.SourceSpells("healing", "current", 9, other)
    check("a past fight by its id", s.spellIdCalls[1].id == 9 and s.spellIdCalls[1].type == 2
        and s.spellIdCalls[1].guid == "Player-2" and s.spellIdCalls[1].creature == nil)
    local before = #s.spellCalls
    check("a secret guid: nothing, and the game is not asked",
        DM.SourceSpells("damage", "current", nil, Source("X", "MAGE", 5, 1, false, SECRET_TEXT)) == nil
        and DM.SourceSpells("damage", "current", nil, Source("Y", "MAGE", 5, 1, false, nil)) == nil
        and #s.spellCalls == before)
    check("deaths have no spells", DM.SourceSpells("deaths", "current", nil, you) == nil and #s.spellCalls == before)
    s.spellsResult = { combatSpells = {} }
    check("a source without spells reads as nothing", DM.SourceSpells("damage", "current", nil, you) == nil)
    s.spellsResult = "no"
    check("an answer that is no table too", DM.SourceSpells("damage", "current", nil, you) == nil)
    s.spellsResult = nil
    s.spellError = true
    check("an error from the API reads as nothing", DM.SourceSpells("damage", "current", nil, you) == nil)
    s.env.C_DamageMeter = nil
    check("no API: nothing", DM.SourceSpells("damage", "current", nil, you) == nil)

    check("a share of a total", DM.Percent(250, 1000) == 25)
    check("none when either is secret, missing or zero", DM.Percent(SECRET_NUMBER, 1000) == nil
        and DM.Percent(5, SECRET_NUMBER) == nil and DM.Percent(5, 0) == nil and DM.Percent(Amount("x"), 10) == nil
        and DM.Percent(5, nil) == nil)
end

-- off: nothing is built, listened to or changed
do
    local s = Boot()
    s.Login()
    check("off: no window", s.Window() == nil and s.Window(2) == nil)
    check("off: no damage meter events, and no frame built but the one that waits for the login", #s.frames == 1 and not s.Listening())
    check("off: the game's meter is untouched", s.cvars.damageMeterEnabled == "1" and s.account.damageMeterGameWas == nil)
    s.env.NaowhForever_ResetDamageMeter()
    check("off: the reset key says so and resets nothing", s.resets == nil and #s.printed == 1)
end

-- on: the window, its rows and its texts
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("on: the window is built and shown", w and w.shown)
    check("on: three rows", #w.rows == 3 and w.rows[3].shown)
    local first, own = w.rows[1], w.rows[2]
    check("the name goes straight to the text", first.name.text == "Aldrin")
    check("two columns: the total, then the per-second figure, secret-safe", first.colA.text == "<A>"
        and first.colB.text == "<a>" and first.colA.shown == true and first.colB.shown == true)
    check("the bar is the amount out of the maximum", first.barMax == s.session.maxAmount
        and first.barValue == s.session.combatSources[1].totalAmount)
    check("class colors", first.color[1] == CLASS.MAGE.r and own.color[1] == CLASS.ROGUE.r)
    check("rank numbers", first.rank.text == "1" and w.rows[3].rank.text == "3")
    check("your row's edge is the Accent, the others' their class color",
        own.edge.solid[1] == THEME.accent.r and first.edge.solid[1] == CLASS.MAGE.r)
    check("the title is the list", w.title.text == "Damage Done")
    check("the session button names the session", w.session.label == "Current")
    check("the preview text is hidden with rows shown", w.empty.shown == false)
    check("only the first window", s.Window(2) == nil and s.Window(3) == nil)

    s.store.Set("barColor", "accent")
    s.Flush()
    check("Theme Accent: every bar in the Accent", first.color[1] == THEME.accent.r and own.color[1] == THEME.accent.r
        and w.rows[3].color[3] == THEME.accent.b)
    s.store.Set("barColor", "class")
    s.store.Set("columns", "name,total")
    s.Flush()
    check("no Per Second column: the total alone, in the right column", first.colB.text == "<A>"
        and first.colA.shown == false)
    s.store.Set("columns", "name,rate")
    s.Flush()
    check("no Total column: the rate alone", first.colB.text == "<a>" and first.colA.shown == false)
    s.store.Set("columns", "auto")
    s.store.Set("mode", "interrupts")
    s.Flush()
    check("a list without a rate shows the total", first.colB.text == "<A>" and first.colA.shown == false)
    check("and is titled so", w.title.text == "Interrupts")
    check("and the API was asked for it", s.calls[#s.calls][2] == 5)
end

-- the sample shows you, in your own class, on your own bar and edge
do
    local s = Boot({ settings = { enabled = true } })
    s.ownClass = "MAGE"
    s.Login()
    s.ns.ShowUnlockMode()
    local w = s.Window()
    check("the row that is you takes your class", w.rows[2].icon.texture == "Interface\\Icons\\ClassIcon_MAGE"
        and w.rows[2].color[1] == CLASS.MAGE.r and w.rows[2].name.text == "You")
    s.store.Set("ownBarStyle", "custom"); s.store.Set("ownBarColor", { r = 0.1, g = 0.8, b = 0.2 }); s.Flush()
    check("with your own bar color on it", w.rows[2].color[2] == 0.8 and w.rows[1].color[1] == CLASS.MAGE.r)
    s.store.Set("edgeStyle", "class"); s.Flush()
    check("and your edge", w.rows[2].edge.solid[1] == CLASS.MAGE.r)
    s.ns.HideUnlockMode()
    s.ns.PreviewDamageMeter()
    check("the preview too", w.rows[2].icon.texture == "Interface\\Icons\\ClassIcon_MAGE" and w.rows[2].color[2] == 0.8)
end

-- each text has a font, an outline and a size of its own, when it is given them
do
    local s = Boot({ settings = { enabled = true, showSummary = true } })
    s.Login()
    local w = s.Window()
    local row = w.rows[1]
    check("every text follows the window's by default: its font and outline, and its usual size",
        row.name.font == "" and row.colA.font == "" and row.rank.font == "" and w.title.font == "" and w.time.font == ""
        and w.summary.font == "" and w.panes[1].headName.font == "" and row.name.outline == "OUTLINE"
        and row.name.fontSize == 11 and row.colA.fontSize == 11 and row.rank.fontSize == 10 and w.title.fontSize == 12
        and w.time.fontSize == 11 and w.summary.fontSize == 11 and w.panes[1].headName.fontSize == 10)

    s.store.Set("font", "Fonts\\base.ttf"); s.store.Set("outline", "THICKOUTLINE"); s.Flush()
    check("the window's font and outline reach all of them at once, without a reload", row.name.font == "Fonts\\base.ttf"
        and row.colA.font == "Fonts\\base.ttf" and row.rank.font == "Fonts\\base.ttf"
        and w.title.font == "Fonts\\base.ttf" and w.time.font == "Fonts\\base.ttf"
        and w.summary.font == "Fonts\\base.ttf" and w.panes[1].headA.font == "Fonts\\base.ttf"
        and w.title.outline == "THICKOUTLINE" and row.name.outline == "THICKOUTLINE")

    s.store.Set("nameFont", "Fonts\\name.ttf"); s.store.Set("nameOutline", "NONE"); s.Flush()
    check("a font set for a text does nothing until it is switched on", row.name.font == "Fonts\\base.ttf")
    s.store.Set("nameOwnFont", true); s.Flush()
    check("then the name has it, with its outline, and nothing else does", row.name.font == "Fonts\\name.ttf"
        and row.name.outline == "NONE" and row.colA.font == "Fonts\\base.ttf" and row.rank.font == "Fonts\\base.ttf")
    for _, e in ipairs({ "value", "rank", "title", "time", "summary", "head" }) do
        s.store.Set(e .. "Font", "Fonts\\" .. e .. ".ttf"); s.store.Set(e .. "Outline", e .. "O")
        s.store.Set(e .. "OwnFont", true)
    end
    s.Flush()
    check("each of the others the same", row.colA.font == "Fonts\\value.ttf" and row.colB.font == "Fonts\\value.ttf"
        and row.colP.font == "Fonts\\value.ttf" and row.rank.font == "Fonts\\rank.ttf"
        and w.title.font == "Fonts\\title.ttf" and w.lowerTitle.font == "Fonts\\title.ttf"
        and w.time.font == "Fonts\\time.ttf" and w.summary.font == "Fonts\\summary.ttf"
        and w.panes[1].headName.font == "Fonts\\head.ttf" and w.panes[1].headB.font == "Fonts\\head.ttf")
    check("and its own outline", row.colA.outline == "valueO" and row.colB.outline == "valueO"
        and row.colP.outline == "valueO" and row.rank.outline == "rankO" and w.title.outline == "titleO"
        and w.lowerTitle.outline == "titleO" and w.time.outline == "timeO" and w.summary.outline == "summaryO"
        and w.panes[1].headA.outline == "headO" and w.panes[1].headP.outline == "headO")
    s.store.Set("nameOwnFont", false); s.Flush()
    check("and switched off, back to the window's", row.name.font == "Fonts\\base.ttf" and row.name.outline == "THICKOUTLINE")

    -- sizes
    s.store.Set("valueFontSize", 15); s.store.Set("headSize", 14); s.Flush()
    check("a size set is not used until it is switched on", row.colA.fontSize == 11 and w.panes[1].headName.fontSize == 10)
    s.store.Set("valueOwnSize", true); s.store.Set("headOwnSize", true); s.Flush()
    check("then it is", row.colA.fontSize == 15 and w.panes[1].headName.fontSize == 14)
    check("the figures' columns are as wide as their size needs", row.colA.w == math.floor(7 * 0.62 * 15))
    s.store.Set("fontSize", 13); s.store.Set("valueOwnSize", false); s.Flush()
    check("the figures follow the names' size when they have none of their own", row.name.fontSize == 13
        and row.colA.fontSize == 13)
    s.store.Set("fontSize", 11)
    s.store.Set("valueOwnSize", true); s.store.Set("valueFontSize", 0); s.Flush()
    check("a size of zero is none: the names' size", row.colA.fontSize == 11)
    s.store.Set("valueOwnSize", false); s.store.Set("valueFontSize", 11)
    s.store.Set("timeOwnSize", true); s.store.Set("timeSize", 15); s.Flush()
    check("the time's room follows its own size", w.time.fontSize == 15 and w.time.w == math.ceil(7 * 0.62 * 15))
    s.store.Set("timeOwnSize", false); s.Flush()
    check("and the usual one without", w.time.fontSize == 11 and w.time.w == math.ceil(7 * 0.62 * 11))

    -- a change is applied at once, even when the layout would think nothing moved
    row.laidKey = "stale"
    w.laidKey = w.laidKey
    s.store.Set("nameClassColor", true)
    w.panes[1].laidKey = "stale"
    s.store.Set("nameClassColor", false)
    check("any change throws the layout away", row.laidKey == nil and w.laidKey == nil
        and w.panes[1].laidKey == nil)
    s.Flush()
    check("and the next paint lays it again", row.laidKey ~= nil and w.laidKey ~= nil)
end

-- each text: its size on the card beside its row, and its size switch, font and color behind the row's cog
do
    local s = Boot({ settings = { enabled = true } })
    local texts = {
        { "rank", "Rank", "Rank Numbers", "row", "rankSize", "rankColor", 10 },
        { "value", "Figure", "Figure Settings", "figures", "valueFontSize", "valueColor", 11 },
        { "head", "Column Title", "Column Titles", "header", "headSize", "columnColor", 10 },
        { "title", "Title", "Title Settings", "header", "titleSize", "titleColor", 12 },
        { "time", "Time", "Show Fight Time", "header", "timeSize", "timeColor", 11 },
        { "summary", "Summary", "Summary Line", "header", "summarySize", "summaryColor", 11 },
    }
    for _, t in ipairs(texts) do
        local element, noun, owner, cardId, sizeKey, colorKey, usual = t[1], t[2], t[3], t[4], t[5], t[6], t[7]
        local own, card = RowOf(s.page, element .. "OwnSize")
        local size, color = RowOf(s.page, sizeKey), RowOf(s.page, colorKey)
        local ownFont, font, outline = RowOf(s.page, element .. "OwnFont"), RowOf(s.page, element .. "Font"),
            RowOf(s.page, element .. "Outline")
        local ownerRow
        for _, row in ipairs(card.rows) do
            if row.label == owner then ownerRow = row end
        end
        check(noun .. ": the row that owns its settings has a cog, on the " .. cardId .. " card", card.id == cardId
            and ownerRow ~= nil and ownerRow.cog ~= nil)
        check(noun .. ": its size switch, font, outline and color are behind that cog", own.under == owner
            and ownFont.under == owner and font.under == owner and outline.under == owner
            and (color.under == owner or color == ownerRow))
        check(noun .. ": its size is behind the cog of its text, with its other settings", size.under == owner
            and size.label == noun .. " Size" and size.slider ~= nil and select(2, RowOf(s.page, sizeKey)) == card
            and size.needs() == true)
        check(noun .. ": the rows are named for it", own.label == "Own " .. noun .. " Size" and own.toggle == true
            and ownFont.label == "Own " .. noun .. " Font" and ownFont.toggle == true
            and font.label == noun .. " Font" and font.font == true and outline.label == noun .. " Outline"
            and outline.choice ~= nil)
        check(noun .. ": it shows the usual size", size.get() == usual and s.store.Get(element .. "OwnSize") == false)
        size.set(15)
        check(noun .. ": setting it gives the text a size of its own", s.store.Get(sizeKey) == 15
            and s.store.Get(element .. "OwnSize") == true and size.get() == 15)
        s.store.Set(element .. "OwnSize", false)
        check(noun .. ": and the switch in the cog takes it back to the usual size", size.get() == usual)
        s.store.Set(element .. "OwnSize", true)
        check(noun .. ": the font and outline wait for their switch, and say so", font.needs() == false
            and outline.needs() == false and font.why == "Turn on its Own Font"
            and outline.why == "Turn on its Own Font")
        s.store.Set(element .. "OwnFont", true)
        check(noun .. ": and are on with it", font.needs() == true and outline.needs() == true)
    end
    s.store.Set("fontSize", 13); s.store.Set("valueOwnSize", false)
    check("the figures' usual size is the names'", RowOf(s.page, "valueFontSize").get() == 13)
    local name, card = RowOf(s.page, "fontSize")
    check("the names: a size with no switch, which the figures follow, behind Name Settings with the font",
        card.id == "row" and name.label == "Name Size" and name.under == "Name Settings" and name.needs() == true
        and RowOf(s.page, "nameColor").label == "Name Settings" and RowOf(s.page, "nameColor").cog ~= nil
        and RowOf(s.page, "nameOwnFont").under == "Name Settings" and RowOf(s.page, "nameOwnSize") == nil
        and RowOf(s.page, "nameFormat").under == "Name Settings" and RowOf(s.page, "youLabel").under == "Name Settings"
        and RowOf(s.page, "nameMaxLetters").under == "Name Settings"
        and RowOf(s.page, "nameFont").needs() == false)
    local base = RowOf(s.page, "font")
    check("the window's own font and outline are on the Window card", base.font == true
        and select(2, RowOf(s.page, "font")).id == "window" and select(2, RowOf(s.page, "outline")).id == "window"
        and base.under == nil)
end

-- the fight time in the title bar
do
    local s = Boot({ settings = { enabled = true } })
    s.fights = { { sessionID = 3, durationSeconds = 61 } }
    s.Login()
    local w = s.Window()
    check("the title bar shows how long the session ran", w.time.text == "2:05" and w.time.shown == true)
    s.duration = 3725
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("and follows it", w.time.text == "1:02:05")
    s.store.Set("showTime", false); s.Flush()
    check("Show Fight Time off: nothing", w.time.shown == false and w.time.text == "")
    s.store.Set("showTime", true)
    s.store.Set("width", 170); s.Flush()
    check("no room beside the title: hidden", w.time.shown == false)
    s.store.Set("width", 300)
    s.duration = SECRET_NUMBER; s.Flush()
    check("a length the game keeps back: hidden", w.time.shown == false)
    s.duration = 125
    w.session.onClick()
    s.menu:Find("Fight 3 (1:01)").set()
    s.Flush()
    check("a past fight: its own length", w.time.text == "1:01" and w.time.shown == true)
    s.ns.PreviewDamageMeter()
    check("the sample has a length too", w.time.text == "3:25")
end

-- the title bar: what the title says, and how far the title and the time are moved
do
    local s = Boot({ settings = { enabled = true } })
    s.fights = { { sessionID = 3, name = "Fyrakk", durationSeconds = 61 } }
    s.Login()
    local w = s.Window()
    local function At(fs) return fs.points[1][4] end
    check("by default the list's name, at the left, with the time by the buttons", w.title.text == "Damage Done"
        and w.title.points[1][1] == "LEFT" and At(w.title) == 8 and w.title.w == 40
        and w.time.points[1][2] == w.session and w.time.points[1][4] == -4 and w.time.justify == "RIGHT")
    check("the title is only text, so it drags the window: no button over it", w.modeButton == nil
        and w.lowerButton == nil)

    s.store.Set("titleText", "fight"); s.Flush()
    check("Title Shows the fight: its name", w.title.text == "Fyrakk")
    s.store.Set("titleText", "both"); s.Flush()
    check("both: the list and the fight", w.title.text == "Damage Done - Fyrakk")
    s.fights = { { sessionID = 3, durationSeconds = 61 } }
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a fight with no name: the list's", w.title.text == "Damage Done")
    s.fights = { { sessionID = 3, name = "Fyrakk", durationSeconds = 61 } }
    s.combat = true
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("in combat the newest fight is not the one running: the list's", w.title.text == "Damage Done")
    s.combat = false
    s.store.Set("titleText", "fight")
    s.store.Set("session", "overall"); s.Flush()
    check("Overall is its own name", w.title.text == "Overall")
    s.store.Set("session", "current"); s.Flush()
    s.store.Set("lower", "healing"); s.Flush()
    check("the second list keeps its own name", w.lowerTitle.text == "Healing Done")
    s.store.Set("lower", "")
    s.fights = { { sessionID = 4, name = "Wolves", durationSeconds = 30 },
        { sessionID = 3, name = "Fyrakk", durationSeconds = 61 } }
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("Current: the newest fight's name", w.title.text == "Wolves")
    w.session.onClick()
    s.menu:Find("Fyrakk (1:01)").set()
    s.Flush()
    check("a past fight: its own name, not the newest's", w.title.text == "Fyrakk")
    s.store.Set("session", "current")
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    s.ns.PreviewDamageMeter()
    check("the preview names a fight too", w.title.text == "Training Dummy")
    s.ns.HideUnlockMode()
    s.store.Set("titleText", "list"); s.Flush()

    -- the bar is 300 wide: the buttons take 98, so the title has 8 to 202, and the time is beside the buttons
    s.store.Set("titleX", 50); s.Flush()
    check("X Offset moves the title right", At(w.title) == 58 and w.title.points[1][5] == 0)
    s.store.Set("titleX", -6); s.Flush()
    check("or left", At(w.title) == 2)
    s.store.Set("titleX", 0); s.store.Set("titleY", 5); s.Flush()
    check("Y Offset moves it up", w.title.points[1][5] == 5 and At(w.title) == 8)
    s.store.Set("titleY", -5); s.Flush()
    check("or down", w.title.points[1][5] == -5)
    s.store.Set("titleY", 0)
    s.store.Set("timeX", -30); s.store.Set("timeY", 3); s.Flush()
    check("the time moves from the buttons, in both directions", w.time.points[1][2] == w.session
        and w.time.points[1][4] == -4 - 30 and w.time.points[1][5] == 3 and w.time.justify == "RIGHT")
    check("and the title stays", At(w.title) == 8 and w.title.points[1][5] == 0 and w.time.shown == true)
    s.store.Set("timeX", 0); s.store.Set("timeY", 0)
    s.store.Set("showTime", false); s.Flush()
    check("with no time the title keeps its place", w.time.shown == false and At(w.title) == 8)
    s.store.Set("showTime", true)
    s.store.Set("width", 198); s.Flush()
    check("the time fits with nothing to spare", w.time.shown == true)
    s.store.Set("width", 197); s.Flush()
    check("and not a pixel less", w.time.shown == false)
    w.title.stringWidth = 100
    s.store.Set("width", 300); s.Flush()
    check("a title that grew is measured whole, not by the width it had", w.title.w == 100)
    w.title.stringWidth = nil
    s.store.Set("width", 170); s.Flush()
    check("no room for both: the time goes, the title stays", w.time.shown == false and At(w.title) == 8
        and w.title.w == 40)
    w.title.stringWidth = 500
    s.store.Set("width", 300); s.Flush()
    check("a long title is cut to the room, and the time gives way", w.title.w == 194 and w.time.shown == false)
    w.title.stringWidth = nil
    s.store.Set("lower", "healing"); s.store.Set("titleX", 30); s.store.Set("titleY", 4); s.Flush()
    check("the second title moves with the first, across its strip", w.lowerTitle.points[1][1] == "LEFT"
        and w.lowerTitle.points[1][2] == 38 and w.lowerTitle.points[1][3] == 4
        and w.lowerTitle.points[2][1] == "RIGHT" and w.lowerTitle.points[2][2] == -8
        and w.lowerTitle.points[2][3] == 4)
    s.store.Set("titleX", 0); s.store.Set("titleY", 0); s.Flush()
    check("and back", w.lowerTitle.points[1][2] == 8 and w.lowerTitle.points[1][3] == 0)

    local page = s.page
    local card = CardOf(page, "header")
    local says = RowOf(page, "titleText")
    local tx, ty, mx, my = RowOf(page, "titleX"), RowOf(page, "titleY"), RowOf(page, "timeX"), RowOf(page, "timeY")
    local values, order = says.choice[1], says.choice[2]
    check("Title Shows: list, fight, both", values.list == "List Name" and values.fight == "Fight Name"
        and values.both == "List and Fight" and #order == 3 and order[1] == "list")
    check("four offsets, from below zero to above", tx and ty and mx and my and tx.label == "Title X Offset"
        and ty.label == "Title Y Offset" and mx.label == "Time X Offset" and my.label == "Time Y Offset"
        and tx.slider[1] == -300 and tx.slider[2] == 300 and mx.slider[1] == -300
        and ty.slider[1] == -20 and ty.slider[2] == 20 and my.slider[2] == 20)
    check("they start at zero", s.store.Get("titleX") == 0 and s.store.Get("titleY") == 0
        and s.store.Get("timeX") == 0 and s.store.Get("timeY") == 0)
    check("and they are in the title bar card, with no position choices left", card and #card.rows >= 9
        and RowOf(page, "titleAlign") == nil and RowOf(page, "timePlace") == nil)
    local time = RowOf(page, "showTime")
    check("the time's offsets are behind the cog of Show Fight Time, on the Title Bar card", time.toggle == true
        and time.cog ~= nil and mx.under == "Show Fight Time" and my.under == "Show Fight Time"
        and select(2, RowOf(page, "timeX")) == card and mx.needs() == true and my.needs() == true)
    s.store.Set("showTime", false)
    check("and wait for the time, and say so", mx.needs() == false and my.needs() == false
        and mx.why == "Turn on Show Fight Time")
    s.store.Set("showTime", true)
end

-- names: full, first, last, initials, and found by class in combat
do
    local s = Boot({ settings = { enabled = true } })
    local DM = s.DM
    local function Show(name, format, class)
        s.store.Set("nameFormat", format)
        return DM.DisplayName({ name = name, classFilename = class or "MAGE" })
    end
    check("full: both words, the realm dropped", Show("Aldrin Stormwind-Draenor", "full") == "Aldrin Stormwind")
    check("first: the first word", Show("Aldrin Stormwind-Draenor", "first") == "Aldrin")
    check("last: the last word", Show("Aldrin Stormwind-Draenor", "last") == "Stormwind")
    check("initials: the first letter of each word", Show("Aldrin Stormwind", "initials") == "A.S.")
    check("first name and the last name's initial", Show("Aldrin Stormwind", "firstInitial") == "Aldrin S.")
    check("a one-word name stays one word", Show("Cara", "first") == "Cara" and Show("Cara", "last") == "Cara"
        and Show("Cara", "initials") == "C." and Show("Cara", "firstInitial") == "Cara")
    check("a realm alone is dropped", Show("Cara-Draenor", "full") == "Cara")
    check("letters beyond ASCII are whole characters", Show("\195\137dith \195\150rn", "initials")
        == "\195\137.\195\150.")
    check("a name that is not a player's is left as it is", DM.DisplayName({ name = "Boar Dog", classFilename = "",
        sourceCreatureID = 5 }) == "Boar Dog")
    for i = 1, 300 do Show("Name" .. i .. " Last", "first") end
    check("the cache wipes itself and still answers", Show("Name1 Last", "first") == "Name1"
        and Show("Zed Last", "first") == "Zed")

    s.store.Set("nameFormat", "first")
    check("your own row comes from your unit", DM.DisplayName({ name = s.session.combatSources[1].name,
        classFilename = "ROGUE", isLocalPlayer = true }) == "You")
    s.ownName = "Rowan"
    check("not from the name the row carries, which is secret in combat", DM.DisplayName({ name = SECRET_TEXT,
        classFilename = "ROGUE", isLocalPlayer = true }) == "Rowan")

    s.units = { party1 = { name = "Brenna Ashdown", surname = nil, class = "WARLOCK" },
        party2 = { name = "Corvus Reed", class = "HUNTER" }, party3 = { name = "Dara Vale", class = "HUNTER" } }
    s.group = true
    s.members = 4
    DM.ScanRoster()
    local function Secret(class) return { name = SECRET_TEXT, classFilename = class } end
    check("in combat a secret name is found by its class, then written", DM.DisplayName(Secret("WARLOCK")) == "Brenna")
    s.store.Set("nameFormat", "initials")
    check("in the format chosen", DM.DisplayName(Secret("WARLOCK")) == "B.A.")
    check("a class two players share stays as it is, whole", DM.DisplayName(Secret("HUNTER")) == SECRET_TEXT)
    check("so does one that is not in the group", DM.DisplayName(Secret("PRIEST")) == SECRET_TEXT)
    s.units.party2 = nil
    DM.ScanRoster()
    check("a new scan: the hunter is alone now", DM.DisplayName(Secret("HUNTER")) == "D.V.")
    s.group = false
    DM.ScanRoster()
    check("alone, nobody to find", DM.DisplayName(Secret("HUNTER")) == SECRET_TEXT)
    s.raid = true
    s.group = true
    s.members = 2
    s.units = { raid1 = { name = "You", class = "ROGUE", self = true }, raid2 = { name = "Eira Moss", class = "DRUID" } }
    DM.ScanRoster()
    check("in a raid: raid units, and you not twice", DM.DisplayName(Secret("DRUID")) == "E.M."
        and DM.DisplayName({ name = SECRET_TEXT, classFilename = "ROGUE" }) == "R.")
    s.units.raid2.name = SECRET_TEXT
    DM.ScanRoster()
    check("a secret name in the group is not used", DM.DisplayName(Secret("DRUID")) == SECRET_TEXT)
end

-- a surname separator other than a space
do
    local s = Boot({ settings = { enabled = true }, separator = "_" })
    local DM = s.DM
    local function Show(name, format)
        s.store.Set("nameFormat", format)
        return DM.DisplayName({ name = name, classFilename = "MAGE" })
    end
    check("words are cut at the separator too", Show("Aldrin_Stormwind", "first") == "Aldrin"
        and Show("Aldrin_Stormwind", "last") == "Stormwind" and Show("Aldrin_Stormwind", "initials") == "A.S."
        and Show("Aldrin_Stormwind", "full") == "Aldrin Stormwind")
end

-- surnames on a client that has them
do
    local s = Boot({ settings = { enabled = true, nameFormat = "full" }, forever = true })
    local DM = s.DM
    s.ownName, s.ownSurname = "Rowan", "Thorne"
    local own = { name = SECRET_TEXT, classFilename = "ROGUE", isLocalPlayer = true }
    check("your name with its surname", DM.DisplayName(own) == "Rowan Thorne")
    s.store.Set("nameFormat", "last")
    check("and its last name", DM.DisplayName(own) == "Thorne")
    s.showSurname = false
    s.store.Set("nameFormat", "full")
    check("Blizzard's show-surname setting leaves yours off", DM.DisplayName(own) == "Rowan")
    s.showSurname = true
    s.ownSurname = ""
    check("an empty surname adds nothing", DM.DisplayName(own) == "Rowan")
    s.ownSurname = "Thorne"
    s.units = { party1 = { name = "Brenna", surname = "Ashdown", class = "WARLOCK" } }
    s.group = true
    DM.ScanRoster()
    check("a group member's too", DM.DisplayName({ name = SECRET_TEXT, classFilename = "WARLOCK" }) == "Brenna Ashdown")
    s.units.party1 = { name = "Brenna Ashdown", surname = "Ashdown", class = "WARLOCK" }
    DM.ScanRoster()
    check("a name that already carries it is not doubled",
        DM.DisplayName({ name = SECRET_TEXT, classFilename = "WARLOCK" }) == "Brenna Ashdown")
end

-- the window and the roster follow the group
do
    local s = Boot({ settings = { enabled = true, nameFormat = "first" } })
    s.units = { party1 = { name = "Aldrin Hale", class = "MAGE" } }
    s.group = true
    s.members = 2
    s.session.combatSources[1].name = SECRET_TEXT
    s.Login()
    local w = s.Window()
    check("the rows write the names the way chosen", w.rows[1].name.text == "Aldrin" and w.rows[2].name.text == "You"
        and w.rows[3].name.text == "Cara")
    s.units.party1 = nil
    s.Fire("GROUP_ROSTER_UPDATE"); s.Flush()
    check("a roster change is scanned again", w.rows[1].name.text == SECRET_TEXT)
    s.units.party1 = { name = "Aldrin Hale", class = "MAGE" }
    s.Fire("PLAYER_REGEN_ENABLED"); s.Flush()
    check("and after combat", w.rows[1].name.text == "Aldrin")
    s.Hover(w, 1)
    check("the spell panel is titled the same way", s.Panel().title.text == "Aldrin")
    s.units.party1 = { name = "Aldrin Hale", class = "WARLOCK" }
    s.Fire("PLAYER_ENTERING_WORLD"); s.Flush()
    check("and on entering the world", w.rows[1].name.text == SECRET_TEXT)
    s.apiResult = { combatSources = { { name = "Aldrin Hale", classFilename = "MAGE", totalAmount = 100,
        amountPerSecond = 10 } }, maxAmount = 100, totalAmount = 100 }
    s.printed = {}
    s.DM.Report("SELF", "damage", "current", nil)
    check("and a report", s.printed[2] == "1. Aldrin  <100> (<10>)")
end

-- the summary line, the title and time sizes
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("the summary line is off by default", w.summary.shown == false)
    s.store.Set("showSummary", true); s.Flush()
    check("on: the session, its total and your rank, the total as the game's secret", w.summary.shown == true
        and w.summary.text == "Current   Damage <total>   Rank 2/3")
    check("the rows move down for it, and the column titles", w.rows[1].points[1][5] == -(26 + 16 + 16) - 6
        and w.headB.points[1][5] == -(26 + 16) - 3)
    s.apiResult = { combatSources = { { name = "You", classFilename = "ROGUE", isLocalPlayer = true,
        totalAmount = 5000, amountPerSecond = 40 } }, maxAmount = 5000, totalAmount = 5000 }
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("with plain numbers: the raid's per-second figure too", w.summary.text
        == "Current   Damage <5000>   Raid DPS <40>   Rank 1/1")
    s.apiResult.totalAmount = SECRET_NUMBER
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("a total the game keeps back has none", w.summary.text == "Current   Damage <424242>   Rank 1/1")
    s.apiResult.totalAmount = 5000
    s.duration = SECRET_NUMBER
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("nor a length it keeps back", w.summary.text == "Current   Damage <5000>   Rank 1/1")
    s.duration = 0
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("nor no time at all", w.summary.text == "Current   Damage <5000>   Rank 1/1")
    s.duration = 125
    s.apiResult.combatSources[1].isLocalPlayer = false
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("without you in it, no rank", w.summary.text == "Current   Damage <5000>   Raid DPS <40>")
    s.apiResult.combatSources[1].isLocalPlayer = true
    s.store.Set("mode", "interrupts"); s.Flush()
    check("a list without a rate has no raid figure, and names its own total", w.summary.text
        == "Current   Interrupts <5000>   Rank 1/1")
    s.store.Set("mode", "damage")
    s.store.Set("session", "overall"); s.Flush()
    check("it names the session", w.summary.text:find("^Overall   ") ~= nil)
    s.store.Set("session", "current")
    w.summary.text = "untouched"
    s.store.Set("showSummary", false); s.Flush()
    check("off again: gone, not painted, and the rows back", w.summary.shown == false and w.summary.text == "untouched"
        and w.rows[1].points[1][5] == -(26 + 16) - 6)
    s.apiResult = nil

    check("the title and the time have their own sizes", w.title.fontSize == 12 and w.time.fontSize == 11
        and w.time.w == 48)
    s.store.Set("titleOwnSize", true); s.store.Set("timeOwnSize", true)
    s.store.Set("titleSize", 16); s.store.Set("timeSize", 14); s.Flush()
    check("which follow the settings, the time's room with it", w.title.fontSize == 16 and w.time.fontSize == 14
        and w.time.w == math.ceil(7 * 0.62 * 14))
    check("the time still shows", w.time.shown == true and w.time.text == "2:05")
    s.store.Set("width", 205); s.Flush()
    check("a bigger time needs more room: it fits at 11 and not at 14", w.time.shown == false)
    s.store.Set("width", 300); s.Flush()
    check("and the time is back with it", w.time.shown == true)
    check("they are drawn in the window's font", w.title.font == "" and w.summary.font == "")
    s.store.Set("font", "Fonts\\x.ttf"); s.Flush()
    check("and a font picked reaches them", w.title.font == "Fonts\\x.ttf" and w.time.font == "Fonts\\x.ttf"
        and w.summary.font == "Fonts\\x.ttf")
end

-- the columns and their titles
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("column titles over the columns, from the list", w.headName.shown == true and w.headName.text == "Name"
        and w.headA.text == "Damage" and w.headB.text == "DPS" and w.headA.shown == true and w.headB.shown == true)
    check("each column as wide as seven characters of the text size", w.rows[1].colA.w == 47 and w.rows[1].colB.w == 47)
    check("the name stops short of both columns", w.rows[1].name.points[2][2] == -(6 + 2 * 47 + 6 + 6))
    s.store.Set("columns", "name,total"); s.Flush()
    check("one column takes less room", w.rows[1].name.points[2][2] == -(6 + 47 + 6))
    s.store.Set("columns", "name"); s.Flush()
    check("none: both hidden and the name takes the row", w.rows[1].colA.shown == false and w.rows[1].colB.shown == false
        and w.rows[1].name.points[2][2] == -12 and w.headB.shown == false)
    s.store.Set("columns", "auto"); s.Flush()
    s.store.Set("mode", "healing"); s.Flush()
    check("a list names its own columns", w.headA.text == "Healing" and w.headB.text == "HPS")
    s.store.Set("mode", "dps"); s.Flush()
    check("DPS leads with the per-second figure", w.headA.text == "DPS" and w.headB.text == "Damage"
        and w.rows[1].colA.text == "<a>" and w.rows[1].colB.text == "<A>")
    s.store.Set("mode", "interrupts"); s.Flush()
    check("a list with one column has one title", w.headB.text == "Interrupts" and w.headA.shown == false)
    s.store.Set("mode", "damage"); s.store.Set("showColumnHeaders", false); s.Flush()
    check("Column Titles off: none, and the rows move up", w.headName.shown == false and w.headB.shown == false)
    local up = w.rows[1].points[1][5]
    s.store.Set("showColumnHeaders", true); s.Flush()
    check("on they are back, and the rows sit below them", w.headB.shown == true
        and w.rows[1].points[1][5] == up - 16)
    s.store.Set("showRanks", false); s.Flush()
    check("the Name title follows the rank column", w.headName.points[1][4] == 12)
    s.store.Set("showRanks", true); s.Flush()
    check("and goes back past it", w.headName.points[1][4] == 12 + 18)
    s.store.Set("fontSize", 16); s.Flush()
    check("the columns grow with the text", w.rows[1].colA.w == math.floor(7 * 0.62 * 16))
    s.store.Set("fontSize", 11)
    s.store.Set("numberUnits", "full"); s.Flush()
    check("Full Numbers need more room", w.rows[1].colA.w == math.floor(10 * 0.62 * 11))
end

-- number formats
do
    local s = Boot({ settings = { enabled = true } })
    local DM = s.DM
    check("Game Default: the game's own abbreviation", DM.Format(1234) == "<1234>" and s.configs == nil)
    s.store.Set("numberUnits", "latin")
    check("K, M, B: the client's AbbreviateNumbers with a config", DM.Format(1234) == "{1234:4}")
    local rows = s.abbreviated.rows
    check("with B, M, K and a plain tier, largest first", rows[1].abbreviation == "B" and rows[1].breakpoint == 1e9
        and rows[2].abbreviation == "M" and rows[3].abbreviation == "K" and rows[4].breakpoint == 1
        and rows[4].abbreviation == "")
    check("one decimal: the M tier is in tenths", rows[2].fractionDivisor == 10 and rows[2].significandDivisor == 1e5
        and rows[3].significandDivisor == 100)
    DM.Format(1)
    check("the config is built once", s.configs == 1)
    s.store.Set("numberDecimals", 0)
    DM.Format(1)
    rows = s.abbreviated.rows
    check("no decimals: whole units", s.configs == 2 and rows[2].fractionDivisor == 1 and rows[2].significandDivisor == 1e6)
    s.store.Set("numberDecimals", 2)
    DM.Format(1)
    rows = s.abbreviated.rows
    check("two: hundredths", rows[2].fractionDivisor == 100 and rows[2].significandDivisor == 1e4)
    s.store.Set("numberUnits", "asian")
    DM.Format(1)
    rows = s.abbreviated.rows
    check("ten-thousands: hundred-millions, ten-thousands and thousands", rows[1].breakpoint == 1e8
        and rows[2].breakpoint == 1e4 and rows[3].breakpoint == 1e3 and #rows == 4)
    check("the simplified Chinese glyphs by default", rows[2].abbreviation == "\228\184\135")
    s.locale = "koKR"
    DM.Format(1)
    check("the Korean ones on a Korean client", s.abbreviated.rows[2].abbreviation == "\235\167\140")
    s.locale = "zhTW"
    DM.Format(1)
    check("the traditional ones on a Taiwanese client", s.abbreviated.rows[2].abbreviation == "\232\144\172")
    s.store.Set("numberUnits", "full")
    DM.Format(1)
    check("Full Numbers: one plain tier", #s.abbreviated.rows == 1 and s.abbreviated.rows[1].breakpoint == 1)
    s.env.AbbreviateNumbers = nil
    check("a client without it falls back to the game's", DM.Format(5) == "<5>")
    local secret = Amount("s")
    s.env.AbbreviateNumbers = function(n) return n end
    s.store.Set("numberUnits", "latin")
    check("a secret number goes straight through", DM.Format(secret) == secret)
end

-- the colors: each part from its own setting, the theme's until one is picked
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    local row, own = w.rows[1], w.rows[2]
    local PICK = { r = 0.9, g = 0.1, b = 0.4 }
    local function Is(c, t) return c ~= nil and c.r == t.r and c.g == t.g and c.b == t.b end
    local function Solid(r) return { r = r.solid[1], g = r.solid[2], b = r.solid[3] } end
    local function Pick(key) s.store.Set(key, PICK); s.Flush() end
    local function Unpick(key) s.store.Set(key, false); s.Flush() end

    check("names, amounts and the title follow the theme", Is(row.name.textColor, THEME.fg)
        and Is(row.colA.textColor, THEME.fg) and Is(row.colB.textColor, THEME.fg) and Is(w.title.textColor, THEME.fg))
    check("ranks, the time and the empty line its muted color", Is(row.rank.textColor, THEME.muted)
        and Is(w.time.textColor, THEME.muted) and Is(w.empty.textColor, THEME.muted))
    check("the window, the title bar and the border their own tokens", Is(Solid(w.background), THEME.bg)
        and Is(Solid(w.headerBackground), THEME.panel) and Is(w.border.color, THEME.line))
    check("your row's edge is the Accent", Is(Solid(own.edge), THEME.accent))
    check("a row has no background of its own: the window's shows behind the bars", row.bg == nil and own.bg == nil
        and w.rows[3].bg == nil)
    check("the window and its border take the background opacity", w.background.alpha == 0.9
        and w.border._frame.alpha == 0.9)

    s.store.Set("ownBarStyle", "custom"); s.store.Set("edgeStyle", "custom"); s.Flush()
    local parts = {
        ownBarColor = function() return { r = own.color[1], g = own.color[2], b = own.color[3] } end,
        nameColor = function() return row.name.textColor end,
        valueColor = function() return row.colB.textColor end,
        columnColor = function() return w.headB.textColor end,
        rankColor = function() return row.rank.textColor end,
        titleColor = function() return w.title.textColor end,
        timeColor = function() return w.time.textColor end,
        summaryColor = function() return w.summary.textColor end,
        edgeColor = function() return Solid(own.edge) end,
        windowColor = function() return Solid(w.background) end,
        headerColor = function() return Solid(w.headerBackground) end,
        borderColor = function() return w.border.color end,
    }
    local count = 0
    for key, read in pairs(parts) do
        count = count + 1
        Pick(key)
        check(key .. ": its part takes it", Is(read(), PICK))
        for other, readOther in pairs(parts) do
            if other ~= key then check(key .. " leaves " .. other .. " alone", not Is(readOther(), PICK)) end
        end
        Unpick(key)
        check(key .. ": back to the theme", not Is(read(), PICK))
    end
    check("every color of the window is covered", count == 12)
    s.store.Set("ownBarStyle", "bar"); s.store.Set("edgeStyle", "accent"); s.Flush()
    Pick("valueColor")
    check("a picked amount color reaches both columns", Is(row.colA.textColor, PICK) and Is(row.colB.textColor, PICK))
    Unpick("valueColor")
    Pick("nameColor")
    check("a picked name color reaches every row", Is(w.rows[3].name.textColor, PICK))
    Unpick("nameColor")
    Pick("rankColor")
    check("the rank color is the empty line's too", Is(w.empty.textColor, PICK))
    Unpick("rankColor")

    s.store.Set("barColor", "custom"); s.Flush()
    check("Custom Color before one is picked: the theme's Accent", row.color[1] == THEME.accent.r
        and row.color[3] == THEME.accent.b)
    Pick("barCustomColor")
    check("Custom Color: every bar the one picked", row.color[1] == PICK.r and own.color[2] == PICK.g
        and w.rows[3].color[3] == PICK.b)
    s.store.Set("barColor", "class"); s.Flush()
    check("Class Colors ignore it", row.color[1] == CLASS.MAGE.r and own.color[1] == CLASS.ROGUE.r)
    Unpick("barCustomColor")

    s.store.Set("highlightPlayer", false)
    Pick("edgeColor")
    check("no highlight: your edge is your class color, whatever is picked", Is(Solid(own.edge), CLASS.ROGUE))
    s.store.Set("highlightPlayer", true); Unpick("edgeColor")
    check("the column title color is its own", Is(w.headA.textColor, THEME.muted))

    s.store.Set("showBorder", false); s.Flush()
    check("Border off hides it", w.border._frame.shown == false)
    s.store.Set("showBorder", true); s.Flush()
    check("and on shows it", w.border._frame.shown == true)

    s.session.combatSources[1].specIconID = 62
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a spec icon when the game gives one", row.icon.texture == 62)
    s.store.Set("iconStyle", "class"); s.Flush()
    check("Class Icon: the class's, always", row.icon.texture == "Interface\\Icons\\ClassIcon_MAGE")
    s.store.Set("iconStyle", "spec"); s.Flush()
    check("and back", row.icon.texture == 62)

    Pick("nameColor"); Pick("valueColor"); Pick("titleColor"); Pick("windowColor"); Pick("borderColor")
    Pick("rankColor")
    s.Hover(w, 2)
    local panel = s.Panel()
    check("the spell panel's names, amounts and title", Is(panel.rows[1].name.textColor, PICK)
        and Is(panel.rows[1].value.textColor, PICK) and Is(panel.title.textColor, PICK))
    check("its window and border", Is(Solid(panel.background), PICK) and Is(panel.border.color, PICK)
        and panel.rows[1].bg == nil)
    s.store.Set("showBorder", false)
    s.Hover(w, 2)
    check("and its border follows Border", panel.border._frame.shown == false)
    for _, key in ipairs({ "nameColor", "valueColor", "titleColor", "windowColor", "borderColor",
        "rankColor" }) do s.store.Set(key, false) end
    s.store.Set("showBorder", true)
    s.spellsResult = { combatSpells = {} }
    s.Hover(w, 2)
    check("without picks the panel follows the theme", Is(panel.title.textColor, THEME.fg)
        and Is(panel.note.textColor, THEME.muted) and Is(Solid(panel.background), THEME.bg))
end

-- fight history: a summary kept when a fight ends, once its numbers are plain
do
    local function Fight(total, secret)
        return { combatSources = {
            { name = "Aldrin", classFilename = "MAGE", totalAmount = 3000, amountPerSecond = 24 },
            { name = "You", classFilename = "ROGUE", isLocalPlayer = true, totalAmount = 5000, amountPerSecond = 40 },
        }, maxAmount = 5000, totalAmount = secret and SECRET_NUMBER or total or 9000 }
    end
    local function End(s)
        s.combat = true
        s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
        s.combat = false
        s.Fire("PLAYER_REGEN_ENABLED")
    end
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    s.duration = 125
    s.apiResult = Fight()
    s.now, s.clock = 1000, 1700000500
    s.zone = "Plains"
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    s.Fire("ENCOUNTER_END", 77, "The Hollow King")
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    local scheduled = false
    for _, t in ipairs(s.timers) do
        if t.sec == 1.5 then scheduled = true end
    end
    check("a read is scheduled for just after combat ends", scheduled)
    s.Flush(); s.Flush()
    local list = s.DM.History.List()
    local e = list[1]
    check("the fight is kept: when, where, which, how long", #list == 1 and e.at == 1700000500 and e.place == "Plains"
        and e.boss == "The Hollow King" and e.seconds == 125)
    check("with your figures and the raid's, damage then healing", e.damage.own == 5000 and e.damage.perSecond == 40
        and e.damage.total == 9000 and e.damage.totalPerSecond == 72 and e.damage.rank == 2 and e.damage.count == 2
        and e.healing.own == 5000)

    -- not plain yet: read again until it is
    s.now = 2000
    End(s)
    s.apiResult = Fight(nil, true)
    s.Flush()
    check("a secret total is not kept, and is read again", #s.DM.History.List() == 1 and #s.timers >= 1)
    s.apiResult = Fight(4000)
    s.Flush(); s.Flush()
    local again = s.DM.History.List()
    check("kept once it is plain, newest first, no boss from the last fight", #again == 2 and again[1].damage.total == 4000
        and again[1].boss == nil and again[2].boss == "The Hollow King")

    -- a length or your own figures still secret
    local before = #s.DM.History.List()
    s.duration = SECRET_NUMBER
    s.apiResult = Fight(5000)
    End(s)
    s.Flush()
    check("a length the game keeps back is waited for", #s.DM.History.List() == before and #s.timers >= 1)
    s.duration = 125
    local mine = Fight(5000)
    mine.combatSources[2].totalAmount = SECRET_NUMBER
    s.apiResult = mine
    s.Flush()
    check("as are your own figures", #s.DM.History.List() == before and #s.timers >= 1)
    mine.combatSources[2].totalAmount = 5000
    s.Flush(); s.Flush()
    check("both kept once they are plain", #s.DM.History.List() == before + 1)

    -- combat begins while it waits for plain numbers
    s.apiResult = Fight(nil, true)
    End(s)
    s.apiResult = Fight(5100)
    s.Fire("PLAYER_REGEN_DISABLED")
    s.Flush(); s.Flush()
    check("a fight that begins drops the read of the last", #s.DM.History.List() == before + 1)
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    s.Flush(); s.Flush()
    check("and the one that ends is read as its own", #s.DM.History.List() == before + 2)

    -- an end of combat that was never a start
    s.Fire("PLAYER_REGEN_ENABLED")
    s.Flush(); s.Flush()
    check("an end with no start is not read", #s.DM.History.List() == before + 2)

    -- a name the game keeps back is not used
    s.now = 5000
    s.Fire("ENCOUNTER_END", 1, SECRET_TEXT)
    End(s)
    s.Flush(); s.Flush()
    check("an encounter name that is secret is not kept as the boss", s.DM.History.List()[1].boss == nil)

    -- a fight that is too short
    s.duration = 3
    End(s)
    s.Flush(); s.Flush()
    check("a fight under five seconds is not kept", #s.DM.History.List() == 5)
    s.duration = 125

    -- the game never gives plain numbers: give up
    s.apiResult = Fight(nil, true)
    End(s)
    for _ = 1, 12 do s.Flush() end
    check("it gives up after a few tries, and keeps nothing", #s.DM.History.List() == 5 and #s.timers == 0)

    -- the next fight starts while it waits
    End(s)
    s.combat = true
    s.Flush()
    s.apiResult = Fight(7000)
    s.Flush(); s.Flush()
    check("combat again: the earlier read is dropped", #s.DM.History.List() == 5)
    s.combat = false
    s.apiResult = Fight(7000)

    -- the list is capped
    s.store.Set("keepFights", 3)
    for i = 1, 4 do
        s.apiResult = Fight(8000 + i)
        End(s)
        s.Flush(); s.Flush()
    end
    local capped = s.DM.History.List()
    check("only as many as Fights Kept, the newest", #capped == 3 and capped[1].damage.total == 8004
        and capped[3].damage.total == 8002)

    -- the window
    local win
    for _, f in ipairs(s.frames) do
        if f.name == "NaowhForeverDamageMeterHistory" then win = f end
    end
    check("not built before it is opened", win == nil)
    s.DM.HistoryWindow.Toggle()
    for _, f in ipairs(s.frames) do
        if f.name == "NaowhForeverDamageMeterHistory" then win = f end
    end
    check("opened", win and win.shown == true and win.title.text == "Fight History")
    check("with a line per fight: when, which, how long, the figures", win.rows[1].cells[1].text
        == os.date("%m/%d %H:%M", capped[1].at) and win.rows[1].cells[2].text == "Plains"
        and win.rows[1].cells[3].text == "2:05" and win.rows[1].cells[4].text == "<40>"
        and win.rows[1].cells[5].text == "<" .. tostring(capped[1].damage.totalPerSecond) .. ">"
        and win.rows[3].cells[1].shown == true and win.rows[4].cells[1].shown == false)
    check("and the empty line is hidden", win.empty.shown == false)
    s.apiResult = Fight(9999)
    End(s)
    s.Flush(); s.Flush()
    check("a new fight refreshes it while it is open", win.rows[1].cells[5].text
        == "<" .. tostring(s.DM.History.List()[1].damage.totalPerSecond) .. ">")
    win.scripts.OnMouseWheel(win, -5)
    check("scrolling past the end stays on the list", win.rows[1].cells[1].shown == true)
    win.scripts.OnMouseWheel(win, 5)
    check("and so does scrolling above the start", win.rows[1].cells[1].shown == true)
    win.clear.onClick()
    check("Clear asks first", #s.confirms == 1 and #s.DM.History.List() == 3)
    s.confirms[1].yes()
    check("then empties it, and says so", #s.DM.History.List() == 0 and win.empty.shown == true
        and win.rows[1].cells[1].shown == false)

    win.close.onClick()
    check("Close hides it", win.shown == false)
    s.DM.HistoryWindow.Toggle()
    check("and it opens again", win.shown == true)

    -- in front of the settings window, and beside it when there is room
    check("above the settings window, not under it", win.strata == "FULLSCREEN" and win.toplevel == true)
    check("with nothing to avoid: in the middle", win.points[1][1] == "CENTER" and #win.points == 1)
    win.close.onClick()
    local optionsFrame = Region("Frame")
    optionsFrame.GetLeft = function() return 100 end
    optionsFrame.GetRight = function() return 300 end
    s.env.NaowhForeverOptions = optionsFrame
    s.DM.HistoryWindow.Toggle()
    check("the settings window open with room at its right: beside it", win.points[1][1] == "TOPLEFT"
        and win.points[1][2] == optionsFrame and win.points[1][3] == "TOPRIGHT" and win.points[1][4] == 8)
    win.close.onClick()
    optionsFrame.GetLeft = function() return 700 end
    optionsFrame.GetRight = function() return 900 end
    s.DM.HistoryWindow.Toggle()
    check("no room at the right, room at the left: there", win.points[1][1] == "TOPRIGHT"
        and win.points[1][2] == optionsFrame and win.points[1][3] == "TOPLEFT" and win.points[1][4] == -8)
    win.close.onClick()
    optionsFrame.GetLeft = function() return 100 end
    optionsFrame.GetRight = function() return 900 end
    s.DM.HistoryWindow.Toggle()
    check("room nowhere: in the middle, and in front", win.points[1][1] == "CENTER" and win.strata == "FULLSCREEN")
    win.close.onClick()
    optionsFrame.GetLeft = function() return 100 end
    optionsFrame.GetRight = function() return 400 end
    s.DM.HistoryWindow.Toggle()
    check("a gap of its own is wanted too: with none, not beside it", win.points[1][1] == "CENTER")
    win.close.onClick()
    optionsFrame:Hide()
    optionsFrame.GetLeft = function() return 100 end
    optionsFrame.GetRight = function() return 300 end
    s.DM.HistoryWindow.Toggle()
    check("the settings window shut: in the middle again", win.points[1][1] == "CENTER")
    win.header.scripts.OnDragStop(win.header)
    win.close.onClick()
    optionsFrame:Show()
    s.DM.HistoryWindow.Toggle()
    check("where the player put it stays", win.points[1][1] == "CENTER" and win.moved == true)
    s.env.NaowhForeverOptions = nil

    -- from the menu
    s.Window().more.onClick()
    s.menu:Find("Fight History").onClick()
    check("the window menu toggles it", win.shown == false)
    s.menu:Find("Take Screenshot").onClick()
    check("a screenshot is taken a moment later, with the menu gone", s.shots == nil)
    s.Flush()
    check("then", s.shots == 1)
end

-- the boss name is only used while it is recent, and the place is the instance's inside one
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    s.duration = 90
    s.apiResult = { combatSources = {}, maxAmount = 0, totalAmount = 100 }
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    s.now = 100
    s.Fire("ENCOUNTER_END", 1, "Old Boss")
    s.now = 400
    s.combat = false
    s.instance, s.instanceName = true, "The Deep Hall"
    s.Fire("PLAYER_REGEN_ENABLED")
    s.Flush(); s.Flush()
    local e = s.DM.History.List()[1]
    check("a boss from minutes ago is not this fight's; the instance's name is the place", e and e.boss == nil
        and e.place == "The Deep Hall" and e.damage.own == 0 and e.damage.rank == nil)
end

-- a second list under the first, in the same window
do
    local s = Boot({ settings = { enabled = true, lower = "healing", height = 300 } })
    local healing = { combatSources = { Source("Mira", "PRIEST", "H1", "h1"), Source("You", "ROGUE", "H2", "h2", true) },
        maxAmount = Amount("hmax"), totalAmount = Amount("htotal") }
    s.byType = { [2] = healing }
    s.Login()
    local w = s.Window()
    check("the second list is drawn under the first, its own sources and titles", w.lowerBar.shown == true
        and w.lowerTitle.text == "Healing Done" and w.rows2[1].name.text == "Mira" and w.rows2[2].name.text == "You"
        and w.rows2[1].colA.text == "<H1>" and w.rows2[1].colB.text == "<h1>"
        and w.rows[1].name.text == "Aldrin" and w.rows[1].colA.text == "<A>")
    check("it has column titles of its own", w.panes[2].headA.text == "Healing" and w.panes[2].headB.text == "HPS"
        and w.headA.text == "Damage")
    check("the rows are shared: five above, four below", w.rows[3].shown == true and w.panes[1].rows[6] == nil
        and w.rows2[2].shown == true and w.rows2[3] == nil)
    check("the strip sits under the first list's last row", w.lowerBar.points[1][5] == -(42 + 6 + 5 * 20 + 4 * 2 + 4))
    check("its titles and rows below the strip", w.panes[2].headB.points[1][5] == -(160 + 20) - 3
        and w.rows2[1].points[1][5] == -(160 + 20 + 16) - 6)
    check("every row knows its list", w.rows[1].modeKey == "damage" and w.rows2[1].modeKey == "healing"
        and w.rows[1].pane == 1 and w.rows2[1].pane == 2)
    check("the title strip names the list", w.lowerTitle.text == "Healing Done" and w.lowerBar.shown == true)
    check("the strip is the title bar's color", w.lowerBackground.solid[1] == THEME.panel.r)
    check("an empty list says so under its own titles", w.empty.points[1][5] == -(42 + 6)
        and w.panes[2].empty.points[1][5] == -(196 + 6))
    s.store.Set("headerColor", { r = 0.3, g = 0.6, b = 0.9 }); s.Flush()
    check("and takes the title bar's color picked", w.lowerBackground.solid[2] == 0.6)
    s.store.Set("headerColor", false)

    s.Hover(w, 1)
    check("a row of the first list asks for its own list's spells", s.spellCalls[#s.spellCalls].type == 0)
    w.rows2[2].scripts.OnEnter(w.rows2[2])
    check("a row of the second asks for its own", s.spellCalls[#s.spellCalls].type == 2)
    w.rows2[2].scripts.OnLeave(w.rows2[2])

    s.store.Set("lower", "interrupts"); s.Flush()
    check("another list: its own columns", w.lowerTitle.text == "Interrupts" and w.rows2[1].colA.shown == false
        and w.rows2[1].colB.shown == true and w.panes[2].headB.text == "Interrupts" and w.rows[1].colA.shown == true)

    s.store.Set("raidMode", true); s.Flush()
    check("Raid Mode keeps your row in each list", w.rows[1].name.text == "You" and w.rows[2].shown == false
        and w.rows2[1].name.text == "You" and w.rows2[2].shown == false)
    s.store.Set("raidMode", false)

    s.store.Set("lower", ""); s.Flush()
    check("none: the strip, its titles and its rows go", w.lowerBar.shown == false and w.rows2[1].shown == false
        and w.panes[2].headB.shown == false)
    check("and the first list has the room again", w.rows[1].shown == true and w.panes[1].rows[6] == nil)
    s.store.Set("height", 400); s.Flush()
    check("room for more rows in a taller window", w.rows[3].shown == true)
end

-- the second list keeps a row in even a very small window, and shows in the sample
do
    local s = Boot({ settings = { enabled = true, lower = "healing", height = 70 } })
    s.Login()
    local w = s.Window()
    check("a window at its smallest still has a row for each list", w.rows[1].shown == true and w.rows2[1].shown == true)
    s.ns.ShowUnlockMode()
    check("Unlock Mode shows the sample in both", w.rows[1].name.text == "Aldrin" and w.rows2[1].shown == true
        and w.rows2[1].name.text == "Aldrin")
end

-- the second list in a small window: scrolled on its own, and its menus
do
    local s = Boot({ settings = { enabled = true, lower = "healing", height = 150 } })
    local healing = { combatSources = { Source("Mira", "PRIEST", "H1", "h1"), Source("You", "ROGUE", "H2", "h2", true) },
        maxAmount = Amount("hmax"), totalAmount = Amount("htotal") }
    s.byType = { [2] = healing }
    s.Login()
    local w = s.Window()
    check("a small window: one row each", w.rows[1].shown == true and w.rows[2] == nil and w.rows2[1].shown == true
        and w.rows2[2] == nil and w.rows2[1].name.text == "Mira")
    w.rows2[1].scripts.OnMouseWheel(w.rows2[1], -1)
    check("the wheel on a second-list row scrolls that list alone", w.rows2[1].name.text == "You"
        and w.rows[1].name.text == "Aldrin")
    w.rows[1].scripts.OnMouseWheel(w.rows[1], -1)
    check("and on the first's scrolls the first alone", w.rows[1].name.text == "You" and w.rows2[1].name.text == "You")
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("a reset puts both back at the top", w.rows[1].name.text == "Aldrin" and w.rows2[1].name.text == "Mira")

    w.rows[1].scripts.OnMouseWheel(w.rows[1], -1)
    w.more.onClick()
    s.menu:Find("List"):Find("Healing Done").set()
    s.Flush()
    check("choosing another first list starts it at the top", w.rows[1].name.text == "Mira")
    w.rows2[1].scripts.OnMouseWheel(w.rows2[1], -1)
    w.more.onClick()
    s.menu:Find("Second List"):Find("Absorbs").set()
    s.Flush()
    check("and so does another second list", w.rows2[1].name.text == "Aldrin")
    s.store.Set("mode", "damage"); s.store.Set("lower", "healing"); s.Flush()
    w.more.onClick()
    local sub = s.menu:Find("Second List")
    check("the ... menu has the second list's: None, then the lists", sub.items[1].text == "None"
        and sub:Find("None").selected() == false and sub:Find("Healing Done").selected() == true and #sub.items == 11)
    sub:Find("Deaths").set()
    check("choosing one sets it", s.store.Get("lower") == "deaths")
    sub:Find("None").set()
    s.Flush()
    check("None turns it off", s.store.Get("lower") == "" and w.lowerBar.shown == false)
    check("and None is the one chosen", sub.items[1].selected() == true)
    sub.items[3].set()
    check("the third choice is the second list", s.store.Get("lower") == "dps")

    local page = s.page
    local row = RowOf(page, "lower")
    check("the settings page has Second List, None among its choices", row and row.choice[1][""] == "None"
        and row.choice[2][1] == "" and row.choice[2][2] == "damage" and row.choice[1].healing == "Healing Done")
end

-- the second list in the second window uses its own setting
do
    local s = Boot({ settings = { enabled = true, window2 = true, lower2 = "taken" } })
    s.Login()
    local one, two = s.Window(), s.Window(2)
    check("a window's second list is its own", two.lowerBar.shown == true and one.lowerBar.shown == false
        and two.lowerTitle.text == "Damage Taken")
    two.more.onClick()
    s.menu:Find("Second List"):Find("Absorbs").set()
    check("its menu sets its own key", s.store.Get("lower2") == "absorbs" and s.settings.lower == nil)
end

-- the fight history is kept on the account under the character, and its window has its column titles
do
    local function Entry(at, place)
        return { at = at, place = place, seconds = 30,
            damage = { own = 600, perSecond = 20, total = 900, totalPerSecond = 30, rank = 1, count = 3 },
            healing = { own = 0, perSecond = 0, total = 0, totalPerSecond = 0, count = 0 } }
    end
    local function Window(s)
        s.DM.HistoryWindow.Toggle()
        for _, f in ipairs(s.frames) do
            if f.name == "NaowhForeverDamageMeterHistory" then return f end
        end
    end

    local s = Boot({ settings = { enabled = true } })
    s.account.damageMeterFights = { ["Player-1"] = { Entry(2000, "Elwynn Forest"), Entry(1000, "Westfall") } }
    s.Login()
    local win = Window(s)
    check("the fights kept on the account are listed after a reload", win.rows[1].cells[2].text == "Elwynn Forest"
        and win.rows[2].cells[2].text == "Westfall" and win.rows[3].cells[1].shown == false)

    -- the column titles are placed, in their widths, and shown
    local want = { "Time", "Fight", "Length", "DPS", "Raid DPS", "HPS", "Raid HPS" }
    local widths = { 84, 150, 50, 66, 70, 66, 70 }
    local placed = #win.titles == 7
    local x = 8
    for n, text in ipairs(want) do
        local fs = win.titles[n]
        local p = fs and fs.points[1]
        placed = placed and fs.text == text and fs.shown == true and p and p[1] == "TOPLEFT" and p[2] == win
            and p[3] == "TOPLEFT" and p[4] == x and p[5] == -(26 + 4) and fs.w == widths[n]
        x = x + widths[n] + 4
    end
    check("the column titles sit under the title bar, over their columns", placed)
    check("the first two to the left, the figures to the right", win.titles[1].justify == "LEFT"
        and win.titles[2].justify == "LEFT" and win.titles[3].justify == "RIGHT" and win.titles[7].justify == "RIGHT")
    check("and the window itself is not moved by them", #win.points == 1 and win.points[1][1] == "CENTER")

    -- a fight that ends is kept there, and not in the profile
    s.apiResult = nil
    s.DM.History.Clear()
    check("clearing empties this character's list", #s.DM.History.List() == 0
        and #s.account.damageMeterFights["Player-1"] == 0)
    check("and none of it is in the profile", s.settings.history == nil)

    -- another character has its own, and the first one's are still there
    local other = Boot({ settings = { enabled = true } })
    other.account.damageMeterFights = { ["Player-1"] = { Entry(2000, "Elwynn Forest") } }
    other.playerGUID = "Player-9"
    other.Login()
    check("another character: its own list, empty", #other.DM.History.List() == 0)
    check("the first one's kept", #other.account.damageMeterFights["Player-1"] == 1)

    -- a profile that is changed or reset does not take them
    local kept = Boot({ settings = { enabled = true, keepFights = 7, mode = "healing" } })
    kept.account.damageMeterFights = { ["Player-1"] = { Entry(2000, "Elwynn Forest") } }
    kept.Login()
    for key in pairs(kept.settings) do kept.settings[key] = nil end
    check("the profile cleared: the fights are there", #kept.DM.History.List() == 1
        and kept.DM.History.List()[1].place == "Elwynn Forest")

    -- the page counts this character's
    local page = Boot({ settings = { enabled = true } })
    page.account.damageMeterFights = { ["Player-1"] = { Entry(1, "a"), Entry(2, "b"), Entry(3, "c") } }
    page.Login()
    check("Fights and Data says how many", CardOf(page.page, "data").summary(page.store) == "3 of 30 fights kept")
end

-- Raid Mode: your row alone
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    s.store.Set("raidMode", true); s.Flush()
    check("your row alone, still ranked as you are", w.rows[1].name.text == "You" and w.rows[1].rank.text == "2"
        and w.rows[2].shown == false)
    check("the bar still against the group's largest", w.rows[1].barMax == s.session.maxAmount
        and w.rows[1].barValue == s.session.combatSources[2].totalAmount)
    s.store.Set("showSummary", true); s.Flush()
    check("the summary still reads the whole group", w.summary.text == "Current   Damage <total>   Rank 2/3")
    s.session.combatSources[2].isLocalPlayer = false
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("not in the session: nothing to show", w.rows[1].shown == false and w.empty.shown == true)
    s.session.combatSources[2].isLocalPlayer = true
    s.store.Set("raidMode", false); s.Flush()
    check("off again: the whole group", w.rows[3].shown == true and w.rows[1].rank.text == "1")
    w.more.onClick()
    local bars = s.menu:Find("Bar Color")
    check("the window menu changes the bar color: three choices, the current one marked", bars and #bars.items == 3
        and bars.items[1].text == "Class Colors" and bars.items[1].selected() == true
        and bars.items[2].selected() == false)
    bars.items[2].set()
    check("and sets it", s.store.Get("barColor") == "accent")
    bars.items[3].set()
    check("custom too", s.store.Get("barColor") == "custom" and bars.items[3].selected() == true)
    s.store.Set("barColor", "class")
    local item = s.menu:Find("Raid Mode")
    check("the window menu has it", item and item.kind == "check" and item.selected() == false)
    item.set()
    check("and sets it", s.store.Get("raidMode") == true)
end

-- In Combat: shown while you fight and a while after, and a key to show or hide it
do
    local s = Boot({ settings = { enabled = true, visibility = "combat", hideDelay = 8 } })
    s.Login()
    local w = s.Window()
    check("hidden until combat", w.shown == false)
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    check("shown in combat", w.shown == true)
    s.combat = false
    s.now = 100
    s.Fire("PLAYER_REGEN_ENABLED")
    local scheduled = false
    for _, t in ipairs(s.timers) do
        if t.sec == 8.25 then scheduled = true end
    end
    check("a check is scheduled for when the delay is out", scheduled)
    s.Flush()
    check("shown for a while after", w.shown == true)
    s.now = 107
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("still shown before the delay is out", w.shown == true)
    s.now = 109
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("hidden when it is", w.shown == false)

    s.env.NaowhForever_ToggleDamageMeter()
    check("the key shows it", w.shown == true)
    s.env.NaowhForever_ToggleDamageMeter()
    check("and hides it", w.shown == false)
    s.env.NaowhForever_ToggleDamageMeter()
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    s.env.NaowhForever_ToggleDamageMeter()
    check("in combat the key hides it", w.shown == false)
    s.combat = false
    s.Fire("PLAYER_REGEN_DISABLED"); s.combat = true; s.Flush()
    check("and the next fight clears that", w.shown == true)

    local always = Boot({ settings = { enabled = true } })
    always.Login()
    always.env.NaowhForever_ToggleDamageMeter()
    check("with Where on Always the key hides it", always.Window().shown == false)
    always.env.NaowhForever_ToggleDamageMeter()
    check("and shows it again", always.Window().shown == true)

    local off = Boot()
    off.Login()
    off.env.NaowhForever_ToggleDamageMeter()
    check("off: the key says so", #off.printed == 1)
end

-- bar colors by class, alternating rows, a background image
do
    local s = Boot({ settings = { enabled = true }, media = true, classes = { "ROGUE", "MAGE" } })
    s.Login()
    local w = s.Window()
    local row, own, third = w.rows[1], w.rows[2], w.rows[3]
    local function Is(c, t) return c.r == t.r and c.g == t.g and c.b == t.b end
    local function Bar(r) return { r = r.color[1], g = r.color[2], b = r.color[3] } end

    s.store.Set("classColors", { MAGE = { r = 0.1, g = 0.9, b = 0.5 } }); s.Flush()
    check("a class picked in the settings colors its bars", Is(Bar(row), { r = 0.1, g = 0.9, b = 0.5 })
        and Is(Bar(third), { r = 0.1, g = 0.9, b = 0.5 }))
    check("and the others keep the game's", Is(Bar(own), CLASS.ROGUE))
    s.store.Set("barColor", "accent"); s.Flush()
    check("Theme Accent ignores the picks", Is(Bar(row), THEME.accent))
    s.store.Set("barColor", "class"); s.store.Set("classColors", {}); s.Flush()
    check("none picked: the game's colors", Is(Bar(row), CLASS.MAGE))

    local MINE = { r = 0.9, g = 0.2, b = 0.7 }
    s.store.Set("ownBarColor", MINE); s.Flush()
    check("a color picked does nothing until Your Bar is Custom Color", Is(Bar(own), CLASS.ROGUE))
    s.store.Set("ownBarStyle", "custom"); s.Flush()
    check("Your Bar: Custom Color, your bar alone", Is(Bar(own), MINE) and Is(Bar(row), CLASS.MAGE)
        and Is(Bar(third), CLASS.MAGE))
    s.store.Set("barColor", "accent"); s.Flush()
    check("whichever Bar Color is chosen", Is(Bar(own), MINE) and Is(Bar(row), THEME.accent))
    s.store.Set("ownBarStyle", "class"); s.Flush()
    check("Class Color: your class's, with the others on the Accent", Is(Bar(own), CLASS.ROGUE)
        and Is(Bar(row), THEME.accent))
    s.store.Set("classColors", { ROGUE = { r = 0.4, g = 0.4, b = 0.4 } }); s.Flush()
    check("and the class color picked for it", Is(Bar(own), { r = 0.4, g = 0.4, b = 0.4 }))
    s.store.Set("classColors", {})
    s.store.Set("ownBarStyle", "bar"); s.store.Set("barColor", "custom"); s.Flush()
    check("Same as Bar Color: custom too", Is(Bar(own), THEME.accent))
    s.store.Set("barColor", "class"); s.store.Set("ownBarColor", false); s.Flush()
    check("and the class's with Class Colors", Is(Bar(own), CLASS.ROGUE))

    check("the edge is the Accent by default", own.edge.solid[1] == THEME.accent.r)
    s.store.Set("edgeStyle", "class"); s.Flush()
    check("Class Color: your class's", own.edge.solid[1] == CLASS.ROGUE.r and row.edge.solid[1] == CLASS.MAGE.r)
    s.store.Set("edgeStyle", "custom"); s.store.Set("edgeColor", { r = 0.2, g = 0.7, b = 0.3 }); s.Flush()
    check("Custom Color: the one picked, on your row alone", own.edge.solid[2] == 0.7 and row.edge.solid[1] == CLASS.MAGE.r)
    s.store.Set("edgeStyle", "accent"); s.store.Set("edgeColor", false); s.Flush()

    check("no image by default", w.image.shown == false)
    s.store.Set("backgroundImage", "Marble"); s.Flush()
    check("a background from the shared media, stretched", w.image.shown == true and w.image.texture == "Media\\Marble"
        and w.image.alpha == 1 and w.image.wrap[1] == nil)
    s.store.Set("imageAlpha", 0.4); s.Flush()
    check("at its own opacity", w.image.alpha == 0.4)
    s.store.Set("backgroundImage", "Gone"); s.Flush()
    check("a name the media no longer has: no image", w.image.shown == false)
    s.store.Set("backgroundImage", "Dots"); s.store.Set("imageTile", true); s.Flush()
    check("another, tiled", w.image.shown == true and w.image.texture == "Media\\Dots"
        and w.image.wrap[1] == "REPEAT" and w.image.wrap[2] == "REPEAT")
    check("repeated at the tile size across the window, whatever the picture's own size",
        w.image.texCoord[2] == 300 / 128 and w.image.texCoord[4] == 206 / 128 and w.image.texCoord[1] == 0)
    s.store.Set("imageTileSize", 64); s.Flush()
    check("a smaller tile repeats more", w.image.texCoord[2] == 300 / 64 and w.image.texCoord[4] == 206 / 64)
    s.store.Set("width", 400); s.Flush()
    check("a wider window repeats it further", w.image.texCoord[2] == 400 / 64)
    s.store.Set("imageTileSize", 0); s.Flush()
    check("a tile size of nothing is kept to the smallest", w.image.texCoord[2] == 400 / 16)
    s.store.Set("width", 300); s.store.Set("imageTileSize", 128)
    s.store.Set("imageTile", false); s.Flush()
    check("not tiled: the whole picture, stretched", w.image.texCoord[2] == 1 and w.image.texCoord[4] == 1
        and w.image.wrap[1] == nil)
    s.store.Set("imageTile", true); s.Flush()
    s.store.Set("backgroundImage", ""); s.Flush()
    check("none again", w.image.shown == false)

    for _, plain in ipairs({ "Solid", "Blizzard Tooltip", "Blizzard Out of Control", "Blizzard Low Health" }) do
        s.store.Set("backgroundImage", plain); s.Flush()
        check(plain .. ": left out, so no picture", w.image.shown == false)
    end
    s.store.Set("backgroundImage", "")

    local mine = "Interface\\AddOns\\MyBackgrounds\\panel"
    s.store.Set("backgroundPath", mine); s.Flush()
    check("a path typed does nothing until Image is Your Own Picture", w.image.shown == false)
    s.store.Set("backgroundImage", "@own"); s.Flush()
    check("picked: that picture", w.image.shown == true and w.image.texture == mine)
    s.store.Set("backgroundPath", ""); s.Flush()
    check("an empty path: no picture", w.image.shown == false)
    s.store.Set("backgroundImage", "Marble"); s.Flush()
    check("another choice: the one picked by name, and the path is not used", w.image.texture == "Media\\Marble")
    s.store.Set("backgroundPath", mine); s.Flush()
    check("with a path typed all the same", w.image.texture == "Media\\Marble")
    s.store.Set("backgroundPath", "")
    s.store.Set("backgroundImage", "")
    s.Flush()

    local page = s.page
    local rows = CardOf(page, "bars").rows
    local classRows = {}
    for _, r in ipairs(rows) do
        if r.key == "classColors" then classRows[#classRows + 1] = r end
    end
    check("a color row per class, in the game's order", #classRows == 2 and classRows[1].field == "ROGUE"
        and classRows[2].field == "MAGE" and classRows[2].label == "Mage")
    check("behind the cog of Bar Color", classRows[1].under == "Bar Color" and classRows[2].under == "Bar Color"
        and RowOf(page, "barColor").cog ~= nil)
    local r, g, b = classRows[2].get()
    check("it shows the game's color until one is picked", r == CLASS.MAGE.r and g == CLASS.MAGE.g and b == CLASS.MAGE.b)
    classRows[2].set(0.2, 0.3, 0.4)
    local picked = s.store.Get("classColors")
    check("picking adds that class alone", picked.MAGE.r == 0.2 and picked.MAGE.g == 0.3 and picked.ROGUE == nil)
    classRows[1].set(0.9, 0.8, 0.7)
    picked = s.store.Get("classColors")
    check("and the next keeps the first", picked.MAGE.r == 0.2 and picked.ROGUE.r == 0.9)
    r = classRows[2].get()
    check("the picker shows it", r == 0.2)
    check("they need Class Colors", classRows[1].needs() == true)
    s.store.Set("barColor", "accent")
    check("and are off without it", classRows[1].needs() == false)
    s.store.Set("barColor", "class")

    local ownColor = RowOf(page, "ownBarColor")
    check("a Your Bar Color row, a color picker", ownColor and ownColor.colour == true and ownColor.label == "Your Bar Color")
    s.store.Set("classColors", {})
    local mr, mg, mb = ownColor.get()
    check("it shows the Accent until one is picked", mr == THEME.accent.r and mg == THEME.accent.g
        and mb == THEME.accent.b)
    check("and is only for Custom Color", ownColor.needs() == false)
    local style = RowOf(page, "ownBarStyle")
    check("Your Bar: same, class or custom", style and style.choice[2][1] == "bar" and style.choice[2][2] == "class"
        and style.choice[2][3] == "custom" and style.choice[1].class == "Class Color")
    s.store.Set("ownBarStyle", "custom")
    check("which turns the picker on", ownColor.needs() == true)
    s.store.Set("ownBarStyle", "bar")
    ownColor.set(0.1, 0.2, 0.3)
    local stored = s.store.Get("ownBarColor")
    check("picking stores it", type(stored) == "table" and stored.r == 0.1 and stored.g == 0.2 and stored.b == 0.3)
    mr, mg = ownColor.get()
    check("and it shows it", mr == 0.1 and mg == 0.2)
    s.store.Set("ownBarColor", false)

    local choices = RowOf(page, "backgroundImage").choice
    local values, order = choices()
    check("the image choices: None, your own, then the media's, without the plain ones", values[""] == "None"
        and values["@own"] == "Your Own Picture" and order[1] == "" and order[2] == "@own" and order[3] == "Marble"
        and order[4] == "Dots" and #order == 4 and values.Solid == nil
        and values["Blizzard Tooltip"] == nil and values["Blizzard Out of Control"] == nil
        and values["Blizzard Low Health"] == nil)
    check("the media's own None is not listed again", values.None == nil and #order == 4)
    s.store.Set("backgroundImage", "None")
    values, order = choices()
    check("one saved as the media's None reads as None, listed once", values.None == "None" and #order == 4)
    s.store.Set("backgroundImage", "Solid")
    values, order = choices()
    check("one picked before they were left out reads as None, and is not offered", values.Solid == "None"
        and #order == 4 and RowOf(page, "imageAlpha").needs() == false)
    s.store.Set("backgroundImage", "")
    local custom = RowOf(page, "backgroundPath")
    check("a text row for a path, wide", custom and custom.text == true and custom.wide == true
        and custom.label == "Custom Image")
    local listed = RowOf(page, "backgroundImage")
    check("Image is always on, and Custom Image waits for Your Own Picture", listed.needs() == true
        and custom.needs() == false and custom.why == "Pick Your Own Picture in Image")
    s.store.Set("backgroundImage", "@own")
    check("picked: Custom Image is on", custom.needs() == true)
    check("and the image rows wait for a path", RowOf(page, "imageAlpha").needs() == false)
    s.store.Set("backgroundPath", "Interface" .. string.char(92) .. "x")
    check("an image once a path is typed", RowOf(page, "imageAlpha").needs() == true
        and RowOf(page, "imageTile").needs() == true)
    s.store.Set("backgroundImage", "Marble")
    check("another choice: Custom Image greyed, and the picture is the one named", custom.needs() == false
        and RowOf(page, "imageAlpha").needs() == true)
    s.store.Set("backgroundPath", ""); s.store.Set("backgroundImage", "")
    local howTo, hostCard
    for _, card in ipairs(page.cards) do
        for _, item in ipairs(card.rows) do
            if item.label == "Adding a Picture" then howTo, hostCard = item, card end
        end
    end
    check("a button for how to add a picture, inside the Window card", howTo and hostCard.id == "window"
        and howTo.buttonText == "Show How")
    check("no card of its own for it", page.infos == nil)
    howTo.button()
    local modal = s.modals[1]
    check("the button opens a dialog", modal and modal.key == "damageMeterImages" and modal.dimmer.shown == true)
    local kept = modal.panel.kept
    check("headed, five parts, and a button to close it", kept.head.text == "Add Your Own Image"
        and kept.title1 and kept.text5 and kept.title5 and kept.title6 == nil and kept.close.label == "Close")
    local text = {}
    for i = 1, 5 do text[#text + 1] = kept["title" .. i].text .. " " .. kept["text" .. i].text end
    local all = table.concat(text, " ")
    check("it names the file kinds, the folder, the restart and the box", all:find(".png", 1, true) ~= nil
        and all:find(".tga", 1, true) ~= nil and all:find(".blp", 1, true) ~= nil
        and all:find("AddOns", 1, true) ~= nil and all:find("Restart the game", 1, true) ~= nil
        and all:find("Custom Image", 1, true) ~= nil and all:find("powers of two", 1, true) ~= nil)
    check("its paths have their backslashes", all:find("Interface" .. string.char(92) .. "AddOns" .. string.char(92)
        .. "MyBackgrounds" .. string.char(92) .. "panel.png", 1, true) ~= nil
        and all:find("Interface" .. string.char(92) .. "AddOns folder", 1, true) ~= nil)
    check("it says a .jpg is not read, and what a green square means", all:find(".jpg", 1, true) ~= nil
        and all:find("green square", 1, true) ~= nil)
    check("and to pick Your Own Picture in Image", all:find("pick Your Own Picture", 1, true) ~= nil)
    check("and the extension is part of the path", all:find("panel.png", 1, true) ~= nil)
    local function Below(fs, above, gap)
        local p = fs.points[1]
        return p[1] == "TOPLEFT" and p[2] == above and p[3] == "BOTTOMLEFT" and p[4] == 0 and p[5] == -gap
    end
    check("each part is below the one before, with a gap, in its own width", Below(kept.title1, kept.head, 12)
        and Below(kept.text1, kept.title1, 2) and Below(kept.title2, kept.text1, 10) and kept.text1.w == 448)
    check("tall enough for all of it", modal.panel.h > 5 * 14 * 2)
    kept.close.onClick()
    check("Close hides it", modal.dimmer.shown == false)
    howTo.button()
    check("and it opens again, as the one dialog", #s.modals == 1 and modal.dimmer.shown == true)
    s.store.Set("backgroundImage", "Lost")
    values, order = choices()
    check("a name that is not there stays chosen, marked", values.Lost == "Lost (unavailable)" and order[5] == "Lost")
    s.store.Set("backgroundImage", "")
end

-- moving and resizing work in combat too, and a resize keeps the size the client gives
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local one = s.Window()
    local grip
    for _, f in ipairs(s.frames) do
        if f.parent == one and f.kind == "Button" and f.scripts.OnMouseDown then grip = f end
    end
    s.combat = true
    grip.scripts.OnMouseDown(grip, "LeftButton")
    check("in combat: the corner starts sizing", one.sizingFrom == "BOTTOMRIGHT")
    one.w, one.h = 420, 260
    one.scripts.OnSizeChanged(one, 420, 260)
    check("the window keeps the size the client gives, not the saved one", one.w == 420 and one.h == 260)
    grip.scripts.OnMouseUp(grip)
    check("on release the size is saved", s.store.Get("width") == 420 and s.store.Get("height") == 260
        and one.sizingFrom == nil)
    s.Flush()
    check("and the window stays that size", one.w == 420 and one.h == 260)

    one.header.scripts.OnDragStart(one.header)
    check("in combat: the title bar starts moving", one.dragging == true)
    one.header.scripts.OnDragStop(one.header)
    check("and the place is saved", s.store.Get("meterPos").point == "TOPLEFT" and one.dragging == false)

    s.store.Set("locked", true)
    one.header.scripts.OnDragStart(one.header)
    check("Lock Window: it does not move", not one.dragging)
    grip.scripts.OnMouseDown(grip, "LeftButton")
    check("nor resize", one.sizingFrom == nil)
    s.store.Set("locked", false)

    s.combat = false
    one.header.scripts.OnDragStart(one.header)
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED")
    check("combat starting does not cancel a drag", one.dragging == true)
    one.header.scripts.OnDragStop(one.header)
    one.scripts.OnHide(one)
    check("hiding the window ends a drag", one.dragging == false)
end

-- the menus: the list, the session, and the rest
do
    local s = Boot({ settings = { enabled = true } })
    s.fights = { { sessionID = 3, name = "Boss", durationSeconds = 125 }, { sessionID = 4 } }
    s.Login()
    local w = s.Window()
    w.more.onClick()
    local list = s.menu:Find("List")
    check("the ... menu has the list menu: the ten lists, the current one chosen", list and #list.items == 10
        and list:Find("Damage Done").selected() == true and list:Find("Healing Done").selected() == false)
    local inside = s.menu:Find("Session")
    check("and the session menu, with the past fights in it", inside and inside:Find("Current").selected() == true
        and inside:Find("Past Fights") ~= nil and inside:Find("Boss (2:05)") ~= nil)
    inside:Find("Boss (2:05)").set()
    s.Flush()
    check("a fight chosen there is the window's", w.session.label == "Fight")
    inside:Find("Current").set()
    s.Flush()
    check("and Current takes it back", w.session.label == "Current")
    list:Find("Healing Done").set()
    check("choosing one sets it", s.store.Get("mode") == "healing")
    s.Flush()
    check("and the window follows", w.title.text == "Healing Done" and s.calls[#s.calls][2] == 2)
    list:Find("Deaths").set()
    check("the last one too", s.store.Get("mode") == "deaths" and list:Find("Deaths").selected() == true)
    s.store.Set("mode", "damage")

    w.session.onClick()
    local menu = s.menu
    check("the session button opens the session menu", menu.owner == w.session and menu:Find("Current").selected() == true
        and menu:Find("Overall").selected() == false)
    check("past fights, newest first, each by its label", menu:Find("Past Fights") ~= nil and menu.items[6].text == "Fight 4"
        and menu.items[7].text == "Boss (2:05)")
    menu:Find("Overall").set()
    check("Overall is a setting", s.store.Get("session") == "overall")
    s.Flush()
    check("and the button says so", w.session.label == "Overall")
    menu:Find("Boss (2:05)").set()
    s.Flush()
    check("a past fight is read by its id", s.idCalls[#s.idCalls][1] == 3 and w.session.label == "Fight")
    s.Hover(w, 2)
    check("its spells are asked for by the fight's id", s.spellIdCalls[#s.spellIdCalls].id == 3)
    w.rows[2].scripts.OnLeave(w.rows[2])
    local asked = #s.idCalls
    w.more.onClick()
    s.menu:Find("Report To"):Find("Yourself").onClick()
    check("and so is its report", #s.idCalls == asked + 1 and s.idCalls[#s.idCalls][1] == 3)
    w.session.onClick()
    menu = s.menu
    check("and chosen in the menu, the sessions not", menu:Find("Boss (2:05)").selected() == true
        and menu:Find("Overall").selected() == false and s.store.Get("session") == "overall")
    menu:Find("Current").set()
    s.Flush()
    check("Current goes back to the live session", s.store.Get("session") == "current" and w.session.label == "Current"
        and menu:Find("Boss (2:05)").selected() == false)

    s.fights = {}
    w.session.onClick()
    check("no past fights: it says so", s.menu:Find("No Past Fights Yet") ~= nil)

    s.fights = { { sessionID = 3 } }
    s.store.Set("session", "current")
    w.session.onClick()
    s.menu:Find("Fight 3").set()
    s.Flush()
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("a reset forgets the past fight", w.session.label == "Current")
end

-- the window menu
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    w.more.onClick()
    local menu = s.menu
    check("the ... button opens the window menu", menu.owner == w.more and menu.items[1].text == "Damage Meter")
    check("with a report, a reset, add, lock and settings", menu:Find("Report To") ~= nil and menu:Find("Reset Data") ~= nil
        and menu:Find("Add Window") ~= nil and menu:Find("Lock Window").kind == "check" and menu:Find("Settings") ~= nil)
    check("no Close Window on the first window", menu:Find("Close Window") == nil)
    menu:Find("Reset Data").onClick()
    check("reset asks first", #s.confirms == 1 and s.resets == nil)
    s.confirms[1].yes()
    check("then clears the game's data", s.resets == 1)
    menu:Find("Lock Window").set()
    check("Lock Window is the setting", s.store.Get("locked") == true and menu:Find("Lock Window").selected() == true)
    menu:Find("Settings").onClick()
    check("Settings opens the page", s.opened == "Damage Meter")
    local channels = menu:Find("Report To").items
    check("reports go to yourself and Say alone, alone", #channels == 2 and channels[1].text == "Yourself" and channels[2].text == "Say")
    s.group, s.raid, s.guild, s.instanceGroup = true, true, true, true
    w.more.onClick()
    local all = s.menu:Find("Report To").items
    check("and to the party, raid, instance and guild when there", #all == 6 and all[3].text == "Party" and all[4].text == "Raid"
        and all[5].text == "Instance" and all[6].text == "Guild")
    s.menu:Find("Add Window").onClick()
    check("Add Window opens the next one", s.store.Get("window2") == true and s.Window(2) ~= nil and s.Window(2).shown == true)
    w.more.onClick()
    s.menu:Find("Add Window").onClick()
    check("and the one after", s.store.Get("window3") == true and s.Window(3).shown == true)
    w.more.onClick()
    check("with all three open there is nothing to add", s.menu:Find("Add Window") == nil)
    local second = s.Window(2)
    second.more.onClick()
    check("the other windows can close", s.menu.items[1].text == "Damage Meter 2" and s.menu:Find("Close Window") ~= nil)
    s.menu:Find("Close Window").onClick()
    check("closing hides it and keeps the rest", s.store.Get("window2") == false and second.shown == false
        and s.Window(3).shown == true and s.Window().shown == true)
    w.more.onClick()
    check("and it can be added again", s.menu:Find("Add Window") ~= nil)
end

-- fading out of combat, full with the mouse over, and the mouse passing through a locked window
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    local function Fader()
        for _, f in ipairs(s.frames) do
            if f.scripts.OnUpdate then return f end
        end
    end
    local function Tick(n)
        local f = Fader()
        for _ = 1, n or 1 do
            if f and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.2) end
        end
    end
    check("not faded by default", w.alpha == 1 and s.store.Get("idleAlpha") == 1)
    Tick(3)
    check("and nothing is watching once it is full", Fader() == nil)

    s.store.Set("idleAlpha", 0.3); s.Flush()
    Tick(1)
    check("Out of Combat Opacity: it fades toward that, a step at a time", w.alpha < 1 and w.alpha > 0.3)
    Tick(30)
    check("and gets there", math.abs(w.alpha - 0.3) < 1e-9)
    check("Full While Hovered still has the mouse to watch", Fader() ~= nil)
    w.mouseOver = true
    Tick(30)
    check("full with the mouse over it", w.alpha == 1)
    w.mouseOver = false
    Tick(30)
    check("and back when it leaves", math.abs(w.alpha - 0.3) < 1e-9)
    s.store.Set("hoverFull", false); s.Flush()
    w.mouseOver = true
    Tick(30)
    check("with Full While Hovered off: the mouse is not looked at", math.abs(w.alpha - 0.3) < 1e-9)
    check("and nothing is watching once it is there", Fader() == nil)
    w.mouseOver = false
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    Tick(30)
    check("in combat: full", w.alpha == 1)
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED"); s.Flush()
    Tick(30)
    check("and faded again after", math.abs(w.alpha - 0.3) < 1e-9)
    s.ns.ShowUnlockMode(); s.Flush()
    Tick(30)
    check("while it is being placed: full", w.alpha == 1)
    s.ns.HideUnlockMode(); s.Flush()
    Tick(30)
    check("and then faded", math.abs(w.alpha - 0.3) < 1e-9)
    s.ns.PreviewDamageMeter()
    Tick(30)
    check("while the preview is up: full", w.alpha == 1)
    s.Flush()
    Tick(30)
    check("and faded after it", math.abs(w.alpha - 0.3) < 1e-9)
    check("each of those starts the fade again and stops it once there", Fader() == nil)
    s.store.Set("hoverFull", true); s.Flush()
    local before = w.alpha
    local f = Fader()
    s.store.Set("idleAlpha", 0.8)
    f.scripts.OnUpdate(f, 0.01)
    check("a tick shorter than the interval does nothing", w.alpha == before)
    s.store.Set("idleAlpha", 0.3)
    s.store.Set("idleAlpha", 1); s.Flush()
    Tick(30)
    check("Out of Combat Opacity at 100%: back to full", w.alpha == 1)

    local row = RowOf(s.page, "hoverFull")
    local idle = RowOf(s.page, "idleAlpha")
    check("Full While Hovered waits for a fade, and says so", row.needs() == false
        and row.why == "Set Out of Combat Opacity below 100%" and idle.needs() == true)
    s.store.Set("idleAlpha", 0.5)
    check("and is on with one", row.needs() == true)
    s.store.Set("idleAlpha", 1)

    -- the mouse
    local through = RowOf(s.page, "clickThrough")
    check("the mouse is taken by default", w.rows[1].mouse == true and w.header.mouse == true
        and w.grip.shown == true and w.passes == false)
    check("Mouse Passes Through waits for Lock Window", through.needs() == false and through.why == "Turn on Lock Window")
    s.store.Set("clickThrough", true); s.Flush()
    check("on its own, while it is not locked, nothing changes", w.rows[1].mouse == true and w.passes == false)
    s.store.Set("locked", true); s.Flush()
    check("locked: the rows, the bar and the corner let the mouse through", w.rows[1].mouse == false
        and w.rows[2].mouse == false and w.header.mouse == false and w.grip.shown == false and w.passes == true
        and through.needs() == true)
    table.insert(s.session.combatSources, Source("Cara", "HUNTER", "C", "c", false, "Player-3"))
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a row made later lets it through too", w.rows[3] ~= nil and w.rows[3].mouse == false)
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("an open breakdown does not take it either", w.title.text:find(" - ", 1, true) ~= nil and w.mouse == false)
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    s.ns.ShowUnlockMode(); s.Flush()
    check("while it is being placed it takes the mouse again", w.rows[1].mouse == true and w.header.mouse == true)
    s.ns.HideUnlockMode(); s.Flush()
    s.store.Set("locked", false); s.Flush()
    check("unlocked: it takes the mouse", w.rows[1].mouse == true and w.header.mouse == true and w.grip.shown == true)
    local fade, hover = RowOf(s.page, "idleAlpha"), RowOf(s.page, "hoverFull")
    check("the fade and the mouse are behind cogs, on the Window card", fade.cog ~= nil and hover.under == fade.label
        and through.under == "Lock Window" and RowOf(s.page, "locked").cog ~= nil
        and select(2, RowOf(s.page, "idleAlpha")).id == "window")
    check("they wait for a fade and for a lock, and say so", hover.needs() == false and through.needs() == false
        and hover.why == "Set Out of Combat Opacity below 100%" and through.why == "Turn on Lock Window")
    s.store.Set("idleAlpha", 0.4); s.store.Set("locked", true)
    check("and are on with them", hover.needs() == true and through.needs() == true)
end

-- the icon's size, side and crop, the room around the texts, the edge and a track behind the bars
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    local row = w.rows[1]
    check("as it was by default: the icon fits the row, and the texts start after it", row.icon.w == 16
        and row.icon.points[1][1] == "LEFT" and row.icon.points[1][2] == 6 + 18 and row.name.points[1][2] == 6 + 18 + 16 + 5
        and row.edge.w == 2 and row.icon.texCoord[1] == 0.08 and row.track.shown == false)
    s.store.Set("iconSize", 12); s.Flush()
    check("Icon Size: that size, and the name after it", row.icon.w == 12 and row.icon.h == 12
        and row.name.points[1][2] == 6 + 18 + 12 + 5)
    s.store.Set("iconSize", 30); s.Flush()
    check("a size of its own is used, and the bars are at least as tall as it", row.icon.w == 30 and row.icon.h == 30
        and row.h == 30 and w.rows[2].h == 30 and row.name.points[1][2] == 6 + 18 + 30 + 5)
    check("the rows are stacked by that height", w.rows[2].points[1][5] == row.points[1][5] - (30 + 2))
    s.store.Set("barHeight", 36); s.Flush()
    check("a taller Row Height is kept", row.h == 36 and row.icon.w == 30)
    s.store.Set("barHeight", 20); s.store.Set("showIcons", false); s.Flush()
    check("with no icons the bars are the Row Height", row.h == 20)
    s.store.Set("showIcons", true)
    s.store.Set("iconSize", 100); s.Flush()
    check("up to the most the slider has", row.icon.w == s.DM.C.MAX_ICON and row.icon.w == 40 and row.h == 40)
    s.store.Set("iconSize", 0)
    s.store.Set("iconGap", 10); s.Flush()
    check("Icon Gap", row.name.points[1][2] == 6 + 18 + 16 + 10)
    s.store.Set("iconGap", 5)
    s.store.Set("iconZoom", 0); s.Flush()
    check("Icon Crop none: the whole icon", row.icon.texCoord[1] == 0 and row.icon.texCoord[2] == 1)
    s.store.Set("iconZoom", 20); s.Flush()
    check("and more", row.icon.texCoord[1] == 0.2 and row.icon.texCoord[2] == 0.8)
    s.store.Set("iconZoom", 8)

    s.store.Set("iconSide", "right"); s.Flush()
    check("Icon Side right: at the end of the row, the name from the start", row.icon.points[1][1] == "RIGHT"
        and row.icon.points[1][2] == -6 and row.name.points[1][2] == 6 + 18)
    check("and the figures before it", row.colB.points[1][2] == -(6 + 16 + 5)
        and row.name.points[2][2] == -(6 + 16 + 5 + 2 * 47 + 6 + 6))
    check("and the titles over them", w.panes[1].headB.points[1][4] == -(6 + 6 + 16 + 5))
    s.store.Set("columns", "name,total,rate,percent"); s.Flush()
    check("and the share, with the figures before it", row.colP.points[1][2] == -(6 + 16 + 5)
        and row.colB.points[1][2] == row.colP)
    s.store.Set("columns", "auto"); s.Flush()
    s.store.Set("showIcons", false); s.Flush()
    check("with no icons, nothing is left for one", row.colB.points[1][2] == -6)
    s.store.Set("showIcons", true); s.store.Set("iconSide", "before"); s.Flush()
    check("Icon Side before the bar: the row starts after the icon, which touches it, as tall as the bar",
        row.icon.w == 20 and row.points[1][4] == 6 + 20 and row.w == 300 - 12 - 20
        and row.icon.points[1][1] == "RIGHT" and row.icon.points[1][2] == row and row.icon.points[1][3] == "LEFT"
        and row.icon.points[1][4] == 0)
    check("the name starts at the row's start, after the rank, and the figures end it as before",
        row.name.points[1][2] == 6 + 18 and row.colB.points[1][2] == -6)
    check("and the title over the name starts there too", w.panes[1].headName.points[1][4] == 6 + 20 + 6 + 18)
    s.store.Set("iconSize", 12); s.Flush()
    check("a size of its own is the room taken, whatever Icon Gap is", row.icon.w == 12 and row.points[1][4] == 6 + 12)
    s.store.Set("iconSize", 0); s.store.Set("showIcons", false); s.Flush()
    check("with no icons, nothing is left for one", row.points[1][4] == 6 and row.w == 300 - 12
        and w.panes[1].headName.points[1][4] == 6 + 6 + 18)
    s.store.Set("showIcons", true); s.store.Set("iconSide", "left"); s.Flush()
    check("and inside the bar a little less than the bar", row.icon.w == 16 and row.points[1][4] == 6)

    s.store.Set("textPad", 12); s.Flush()
    check("Text Padding: at both ends", row.rank.points[1][2] == 12 and row.colB.points[1][2] == -12
        and row.name.points[1][2] == 12 + 18 + 16 + 5)
    s.store.Set("textPad", 6)
    s.store.Set("colGap", 14); s.Flush()
    check("Column Gap", row.colA.points[1][2] == row.colB and row.colA.points[1][4] == -14
        and row.name.points[2][2] == -(6 + 2 * 47 + 14 + 6))
    s.store.Set("colGap", 6)
    s.store.Set("edgeWidth", 5); s.Flush()
    check("Edge Width", row.edge.w == 5)
    s.store.Set("edgeWidth", 2)

    s.store.Set("barTrack", true); s.Flush()
    check("Bar Track: a color behind the bar, in the theme's panel color", row.track.shown == true
        and row.track.solid[1] == THEME.panel.r and row.track.solid[4] == 0.6)
    s.store.Set("trackColor", { r = 0.5, g = 0.25, b = 0.75 }); s.Flush()
    check("or the one picked", row.track.solid[1] == 0.5 and row.track.solid[3] == 0.75)
    s.store.Set("trackColor", false)
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("a spell of a breakdown has it too", w.rows[1].track.shown == true)
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    s.store.Set("barTrack", false); s.Flush()
    check("off", row.track.shown == false)

    -- a heading takes the row of a bar that had a track
    local t = Boot({ settings = { enabled = true, barTrack = true } })
    t.duration = 120
    t.session.combatSources = { Source("A", "MAGE", "a", "a", false, "P-1"), Source("You", "ROGUE", "y", "y", true, "Player-1"),
        Source("C", "MAGE", "c", "c", false, "P-3"), Source("D", "MAGE", "d", "d", false, "P-4"),
        Source("E", "MAGE", "e", "e", false, "P-5") }
    t.byType = { [10] = { combatSources = { { name = "Mob", sourceGUID = "E-1", sourceCreatureID = 1 } } } }
    t.enemyData = { ["E-1"] = { combatSpells = { { totalAmount = 50, combatSpellDetails = { unitName = "You" } } } } }
    t.Login()
    local tw = t.Window()
    check("the list's rows have the track", tw.rows[4].track.shown == true)
    tw.rows[2].scripts.OnMouseUp(tw.rows[2], "LeftButton")
    check("the heading that takes the row of one has none, the enemy under it has", tw.rows[4].name.text == "Targets"
        and tw.rows[4].track.shown == false and tw.rows[5].name.text == "Mob" and tw.rows[5].track.shown == true)

    local colorRow = RowOf(s.page, "trackColor")
    check("the track's color is left off the page until there is a track", colorRow.hidden() == true
        and RowOf(s.page, "barTrack").needs() == true)
    s.store.Set("barTrack", true)
    check("and is there with it", colorRow.hidden() == false)
    s.store.Set("barTrack", false)
    local icons, card = RowOf(s.page, "showIcons")
    check("Icons is a toggle with a cog on the Row card, with its size and the rest behind it", icons.toggle == true
        and icons.cog ~= nil and card.id == "row" and select(2, RowOf(s.page, "iconSize")) == card
        and RowOf(s.page, "iconSize").under == "Icons" and RowOf(s.page, "iconSide").under == "Icons"
        and RowOf(s.page, "iconGap").under == "Icons" and RowOf(s.page, "iconSide").choice[2][2] == "right")
    check("the room around the texts is on the Row card, the edge's width behind Highlight Your Row",
        select(2, RowOf(s.page, "textPad")) == card and select(2, RowOf(s.page, "colGap")) == card
        and RowOf(s.page, "edgeWidth").under == "Highlight Your Row")
    check("its summary", CardOf(s.page, "row").summary(s.store) == "Icons left, ranks on")
    s.store.Set("iconSide", "right")
    check("and with the side set", CardOf(s.page, "row").summary(s.store) == "Icons right, ranks on")
    s.store.Set("iconSide", "before")
    check("before the bar", CardOf(s.page, "row").summary(s.store) == "Icons before the bar, ranks on"
        and RowOf(s.page, "iconSide").choice[2][3] == "before"
        and RowOf(s.page, "iconSide").choice[1].before == "Before the Bar")
    s.store.Set("showIcons", false); s.store.Set("showRanks", false)
    check("and with both off", CardOf(s.page, "row").summary(s.store) == "Icons off, ranks off")
    s.store.Set("showIcons", true); s.store.Set("showRanks", true); s.store.Set("iconSide", "left")
end

-- class colored names and figures, sizes of their own, and how names and numbers are written
do
    local s = Boot({ settings = { enabled = true } })
    s.ownName = "Lyssa"
    s.session.totalAmount = 400
    s.session.combatSources[1].totalAmount = 100
    s.Login()
    local w = s.Window()
    local function Is(c, t) return c and c.r == t.r and c.g == t.g and c.b == t.b end
    check("names and figures in the theme's colors by default", Is(w.rows[1].name.textColor, THEME.fg)
        and Is(w.rows[1].colA.textColor, THEME.fg))
    s.store.Set("nameClassColor", true); s.Flush()
    check("Class Colored Names: each in its class's color", Is(w.rows[1].name.textColor, CLASS.MAGE)
        and Is(w.rows[2].name.textColor, CLASS.ROGUE) and Is(w.rows[1].colA.textColor, THEME.fg))
    s.store.Set("valueClassColor", true); s.Flush()
    check("and the figures, share too", Is(w.rows[1].colA.textColor, CLASS.MAGE) and Is(w.rows[1].colB.textColor, CLASS.MAGE)
        and Is(w.rows[2].colB.textColor, CLASS.ROGUE))
    s.store.Set("columns", "name,total,rate,percent"); s.Flush()
    check("with the share", Is(w.rows[1].colP.textColor, CLASS.MAGE))
    s.store.Set("columns", "auto")
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("a spell is not in the class's color, nor is a heading", Is(w.rows[1].name.textColor, THEME.fg)
        and Is(w.rows[1].colA.textColor, THEME.fg))
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    s.store.Set("nameClassColor", false); s.store.Set("valueClassColor", false); s.Flush()
    check("off: the theme's again", Is(w.rows[1].name.textColor, THEME.fg) and Is(w.rows[1].colA.textColor, THEME.fg))

    -- your name, cut names
    check("your name as it is", w.rows[2].name.text == "Lyssa")
    s.store.Set("youLabel", true); s.Flush()
    check("Call Me You: yours says You, the others as they are", w.rows[2].name.text == "You"
        and w.rows[1].name.text == "Aldrin")
    s.store.Set("youLabel", false)
    s.store.Set("nameMaxLetters", 3); s.Flush()
    check("Name Length: cut, with dots", w.rows[1].name.text == "Ald..." and w.rows[2].name.text == "Lys...")
    s.store.Set("nameMaxLetters", 6); s.Flush()
    check("a name that fits is left", w.rows[1].name.text == "Aldrin")
    s.session.combatSources[1].name = "\195\137mile"
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    s.store.Set("nameMaxLetters", 2); s.Flush()
    check("counted in letters, not bytes", w.rows[1].name.text == "\195\137m...")
    s.session.combatSources[1].name = SECRET_TEXT
    s.session.combatSources[1].classFilename = "MAGE"
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a name the game keeps back goes as it is", w.rows[1].name.text == SECRET_TEXT)
    s.store.Set("nameMaxLetters", 0)
    s.session.combatSources[1].name = "Aldrin"
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()

    -- sizes
    check("by default: ranks 10, figures as the names", w.rows[1].rank.fontSize == 10 and w.rows[1].colA.fontSize == 11
        and w.rows[1].name.fontSize == 11 and w.rows[1].colA.w == 47)
    s.store.Set("valueOwnSize", true); s.store.Set("valueFontSize", 14); s.Flush()
    check("Figures Size: the amounts only, and their columns with it", w.rows[1].colA.fontSize == 14
        and w.rows[1].colB.fontSize == 14 and w.rows[1].name.fontSize == 11 and w.rows[1].colA.w == math.floor(7 * 0.62 * 14))
    s.store.Set("valueOwnSize", false); s.Flush()
    s.store.Set("rankOwnSize", true); s.store.Set("rankSize", 15); s.Flush()
    check("Rank Size: the rank's text, and room for it", w.rows[1].rank.fontSize == 15 and w.rows[1].rank.w == 27
        and w.rows[1].icon.points[1][2] == 6 + 27)
    s.store.Set("rankSize", 10)

    -- numbers
    s.store.Set("columns", "name,total,rate,percent"); s.Flush()
    check("a share with a decimal", w.rows[1].colP.text == "25.0%")
    s.store.Set("percentDecimals", 0); s.Flush()
    check("Percent Decimals zero: whole", w.rows[1].colP.text == "25%")
    s.store.Set("percentDecimals", 2); s.Flush()
    check("two", w.rows[1].colP.text == "25.00%")
    s.store.Set("percentDecimals", 1); s.store.Set("columns", "auto")
    s.store.Set("rateSuffix", true); s.Flush()
    check("Per-Second Suffix: /s after the per-second figure only", w.rows[1].colB.text == "<a>/s"
        and w.rows[1].colA.text == "<100>")
    s.store.Set("showDivider", true); s.Flush()
    check("in one text too", w.rows[1].colB.text == "<100> | <a>/s")
    s.store.Set("mode", "dps"); s.Flush()
    check("and where it leads", w.rows[1].colB.text == "<a>/s | <100>")
    s.store.Set("mode", "damage"); s.store.Set("showDivider", false); s.Flush()
    s.Hover(w, 2)
    local panel = s.Panel()
    check("the spell panel writes it too, and the share with the decimals", panel.rows[1].value.text
        == "<600>  <4.8>/s  60.0%")
    s.store.Set("percentDecimals", 0)
    s.Hover(w, 2)
    check("as the settings say", panel.rows[1].value.text == "<600>  <4.8>/s  60%")
    s.store.Set("percentDecimals", 1)
    w.rows[2].scripts.OnLeave(w.rows[2])
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("in a breakdown the figures too", w.rows[1].colB.text == "<4.8>/s")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")

    local names = {}
    for _, key in ipairs({ "nameClassColor", "valueClassColor", "valueFontSize", "rankSize", "youLabel",
        "nameMaxLetters", "percentDecimals", "rateSuffix" }) do
        names[key] = RowOf(s.page, key) ~= nil
    end
    local all = true
    for _, v in pairs(names) do all = all and v end
    check("each has a row on the page", all)
    local _, figures = RowOf(s.page, "valueFontSize")
    local _, ranks = RowOf(s.page, "rankSize")
    local _, numbers = RowOf(s.page, "rateSuffix")
    local _, colors = RowOf(s.page, "nameClassColor")
    check("each on the card of its text", figures.id == "figures" and ranks.id == "row" and numbers.id == "figures"
        and colors.id == "row")
end

-- Always Show My Row: yours is the last row when it is not among the rows shown
do
    local s = Boot({ settings = { enabled = true, height = 100 } })
    s.session.combatSources = {
        Source("Ann", "MAGE", "a1", "r1", false, "P-1"), Source("Bob", "MAGE", "a2", "r2", false, "P-2"),
        Source("Cy", "MAGE", "a3", "r3", false, "P-3"), Source("Di", "MAGE", "a4", "r4", false, "P-4"),
        Source("You", "ROGUE", "a5", "r5", true, "Player-1"), Source("Fay", "MAGE", "a6", "r6", false, "P-6"),
    }
    s.Login()
    local w = s.Window()
    check("two rows fit", w.rows[2].shown == true and w.rows[3] == nil)
    check("off: the first two", w.rows[1].name.text == "Ann" and w.rows[2].name.text == "Bob"
        and w.rows[2].rank.text == "2")
    s.store.Set("pinSelf", true); s.Flush()
    check("on: the last row is yours, with your rank", w.rows[1].name.text == "Ann" and w.rows[1].rank.text == "1"
        and w.rows[2].name.text == "You" and w.rows[2].rank.text == "5" and w.rows[2].source.isLocalPlayer == true)
    s.Hover(w, 2)
    check("and it is the real row: its spells are yours", s.spellCalls[#s.spellCalls].guid == "Player-1")
    w.rows[2].scripts.OnLeave(w.rows[2])
    w.rows[1].scripts.OnMouseWheel(w.rows[1], -1)
    check("scrolled, still yours", w.rows[1].name.text == "Bob" and w.rows[2].name.text == "You")
    w.rows[1].scripts.OnMouseWheel(w.rows[1], -2)
    check("scrolled to it: it is in its own place, and not twice", w.rows[1].name.text == "Di"
        and w.rows[2].name.text == "You" and w.rows[2].rank.text == "5")
    w.rows[1].scripts.OnMouseWheel(w.rows[1], -3)
    check("to the end: yours is the first of the last two, as it stands", w.rows[1].name.text == "You"
        and w.rows[1].rank.text == "5" and w.rows[2].name.text == "Fay" and w.rows[2].rank.text == "6")

    -- yours above the rows shown
    s.session.combatSources = {
        Source("You", "ROGUE", "a1", "r1", true, "Player-1"), Source("Bob", "MAGE", "a2", "r2", false, "P-2"),
        Source("Cy", "MAGE", "a3", "r3", false, "P-3"), Source("Di", "MAGE", "a4", "r4", false, "P-4"),
    }
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("on top: it is the first row", w.rows[1].name.text == "You" and w.rows[1].rank.text == "1")
    w.rows[1].scripts.OnMouseWheel(w.rows[1], -2)
    check("scrolled past it: the last row is yours, ranked first", w.rows[2].name.text == "You"
        and w.rows[2].rank.text == "1" and w.rows[1].name.text == "Cy")

    -- one row only
    s.store.Set("height", 70); s.Flush()
    check("a window with room for one row: that row is yours", w.rows[1].name.text == "You" and w.rows[2] ~= nil
        and w.rows[2].shown == false)

    -- not in Raid Mode, not in a breakdown
    s.store.Set("height", 100); s.store.Set("raidMode", true); s.Flush()
    check("Raid Mode: yours alone, ranked as it is", w.rows[1].name.text == "You" and w.rows[2].shown == false)
    s.store.Set("raidMode", false); s.Flush()
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    check("a breakdown: its spells, none of yours twice", w.rows[1].name.text == "Fireball"
        and w.rows[2].name.text == "Pyroblast")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    local row = RowOf(s.page, "pinSelf")
    check("a toggle on the Bars card", row and row.toggle == true and row.label == "Always Show My Row")

    -- you are not in the list
    s.session.combatSources = {
        Source("Ann", "MAGE", "a1", "r1", false, "P-1"), Source("Bob", "MAGE", "a2", "r2", false, "P-2"),
        Source("Cy", "MAGE", "a3", "r3", false, "P-3"),
    }
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("not listed: the rows as they are", w.rows[1].name.text == "Ann" and w.rows[2].name.text == "Bob")
end

-- bars: grown upward, filled from the right, and compared to the list's total
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("by default the first row on top, filling from the left, against the top player",
        w.rows[1].points[1][5] == -(42 + 6) and w.rows[2].points[1][5] == -(42 + 6 + 22)
        and w.rows[1].reverse == false and w.rows[1].barMax == s.session.maxAmount)
    s.store.Set("growUp", true); s.Flush()
    check("Grow Upward: the first row at the bottom of the room, the rest above it",
        w.rows[1].points[1][5] == -(42 + 6 + 6 * 22) and w.rows[2].points[1][5] == -(42 + 6 + 5 * 22))
    s.store.Set("height", 150); s.Flush()
    check("in a window with other room: from the bottom of that", w.rows[1].points[1][5] == -(42 + 6 + 3 * 22)
        and w.rows[2].points[1][5] == -(42 + 6 + 2 * 22))
    s.store.Set("lower", "healing"); s.Flush()
    local first = w.panes[1].capacity
    check("with a second list each from the bottom of its own room", w.rows[1].points[1][5]
        == -(42 + 6 + (first - 1) * 22) and w.rows2[1].points[1][5] == -(w.panes[2].top + 6 + (w.panes[2].capacity - 1) * 22))
    s.store.Set("lower", ""); s.store.Set("height", 206); s.store.Set("growUp", false); s.Flush()
    check("off: back at the top", w.rows[1].points[1][5] == -(42 + 6))
    s.store.Set("reverseFill", true); s.Flush()
    check("Fill From the Right: the bars fill that way", w.rows[1].reverse == true and w.rows[2].reverse == true)
    s.store.Set("reverseFill", false); s.Flush()
    check("and not", w.rows[1].reverse == false)
    s.store.Set("barScale", "total"); s.Flush()
    check("Bars Compare To the list total: the whole is full", w.rows[1].barMax == s.session.totalAmount)
    s.store.Set("barScale", "top"); s.Flush()
    check("and the top player again", w.rows[1].barMax == s.session.maxAmount)
    local grow, fill, scale = RowOf(s.page, "growUp"), RowOf(s.page, "reverseFill"), RowOf(s.page, "barScale")
    check("the three are on the Bars card", grow and fill and scale and grow.toggle and fill.toggle
        and scale.choice[1].top == "Top Player" and scale.choice[1].total == "List Total")
end

-- Reset All Settings: every setting back to its default, but the switch and where the windows are
do
    local place = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 5, y = -5 }
    local s = Boot({ settings = { enabled = true, window2 = true, barHeight = 30, fontSize = 14, showRanks = false,
        ownLook2 = true, barHeight2 = 40, nameOwnFont = true, nameFont = "Fonts\\x.ttf", meterPos = place,
        meterPos2 = place, classColors = { MAGE = { r = 1, g = 0, b = 0 } } } })
    s.account.damageMeterLooks = { { name = "Kept" } }
    s.Login()
    local w = s.Window()
    check("set: tall bars", w.rows[1].h == 30 and s.store.Get("window2") == true)
    local reset
    for _, row in ipairs(CardOf(s.page, "data").rows) do
        if row.label == "Reset All Settings" then reset = row end
    end
    check("a button on the Data and Reset card, there when the module is off too", reset and reset.buttonText == "Reset"
        and reset.needs == nil)
    reset.button()
    check("it asks first, and changes nothing yet", #s.confirms == 1 and s.store.Get("barHeight") == 30)
    local before = s.refreshed or 0
    s.confirms[1].yes(); s.Flush()
    check("then every setting is its default", s.store.Get("barHeight") == 20 and s.store.Get("fontSize") == 11
        and s.store.Get("showRanks") == true and s.store.Get("window2") == false and s.store.Get("ownLook2") == false
        and s.settings.barHeight2 == nil and s.settings.nameFont == nil and s.settings.classColors == nil)
    check("the module stays on and the windows where they were", s.store.Get("enabled") == true
        and s.settings.meterPos == place and s.settings.meterPos2 == place)
    check("the looks kept stay", s.account.damageMeterLooks[1].name == "Kept")
    check("the window shows it, and the page is drawn again", w.rows[1].h == 20 and (s.refreshed or 0) > before)
end

-- an icon and a font are not changed on screen until a reload: the options say so once one is changed
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local page = s.page
    local function Card(id) return CardOf(page, id) end
    local size, owner = RowOf(page, "iconSize"), RowOf(page, "showIcons")
    check("nothing is said before a change", size.note(size) == nil and owner.note() == nil
        and Card("row").note() == nil and Card("window").note() == nil)
    s.store.Set("iconSize", 30)
    check("an icon setting changed: its row, the row of its cog and its card say a reload is needed",
        size.note(size) == "Needs a /reload" and owner.note() == "Needs a /reload"
        and Card("row").note() == "Needs a /reload")
    check("another row and another card do not", RowOf(page, "iconGap").note(RowOf(page, "iconGap")) == nil
        and RowOf(page, "barHeight").note == nil and Card("window").note() == nil and Card("figures").note() == nil
        and Card("header").note() == nil)
    s.store.Set("font", "Fonts\\x.ttf"); s.store.Set("outline", "THICKOUTLINE")
    check("the window's font and outline", RowOf(page, "font").note(RowOf(page, "font")) == "Needs a /reload"
        and RowOf(page, "outline").note(RowOf(page, "outline")) == "Needs a /reload"
        and Card("window").note() == "Needs a /reload")
    s.store.Set("nameFont", "Fonts\\x.ttf")
    check("a text's own font: its row, the row of its cog (Name Settings) and its card",
        RowOf(page, "nameFont").note(RowOf(page, "nameFont")) == "Needs a /reload"
        and RowOf(page, "nameColor").note() == "Needs a /reload")
    check("and the figures', and the title bar's, have their own", Card("figures").note() == nil
        and Card("header").note() == nil)
    s.store.Set("valueOwnFont", true)
    check("the Figures card says it for the figures' font", Card("figures").note() == "Needs a /reload"
        and Card("header").note() == nil)
    s.store.Set("summaryFont", "x")
    check("and the Title Bar card for the summary line's", Card("header").note() == "Needs a /reload")
    check("the row of the summary line's cog too", RowOf(page, "showSummary").note() == "Needs a /reload"
        and RowOf(page, "showColumnHeaders").note() == nil and RowOf(page, "titleColor").note() == nil)
    s.store.Set("rankSize", 14)
    check("a size is applied at once, and says nothing", RowOf(page, "rankSize").note == nil
        and RowOf(page, "showRanks").note() == nil)
end

-- a name is always shown: there is no setting to take it out of a row
do
    local s = Boot({ settings = { enabled = true, showName = false, showName2 = false } })
    s.Login()
    local w = s.Window()
    check("an old setting to hide the names does nothing", w.rows[1].name.shown == true and w.rows[2].name.shown == true
        and w.panes[1].headName.shown == true)
    check("there is no row for it, and no card of names", RowOf(s.page, "showName") == nil
        and CardOf(s.page, "names") == nil)
    local inLook = false
    for _, list in ipairs({ s.DM.C.LOOK_KEYS, s.DM.C.OWN_LOOK_ORDER }) do
        for _, key in ipairs(list) do
            if key == "showName" then inLook = true end
        end
    end
    check("and a look does not keep one", not inLook and s.DM.C.OWN_LOOK_COLUMNS.showName == nil)
end

-- looks: kept by name on the account, applied, copied to the other windows, and written as text
do
    local s = Boot({ settings = { enabled = true, window2 = true } })
    s.Login()
    local DM = s.DM
    local C = DM.C
    local w = s.Window()

    local seen, dup, missing = {}, false, {}
    for _, key in ipairs(C.LOOK_KEYS) do
        if seen[key] then dup = true end
        seen[key] = true
        if s.store.Get(key) == nil then missing[#missing + 1] = key end
    end
    check("every key of a look has a default, once", not dup and #missing == 0 and #C.LOOK_KEYS > 60)
    check("and none is a place, a list or a rule", not seen.meterPos and not seen.mode and not seen.width
        and not seen.visibility and not seen.enabled and not seen.history and not seen.scale and not seen.locked)
    check("the colors are in it", seen.nameColor and seen.borderColor and seen.trackColor and seen.classColors)

    -- keeping and applying
    s.store.Set("barHeight", 30); s.store.Set("nameColor", { r = 0.1, g = 0.2, b = 0.3 })
    s.store.Set("classColors", { MAGE = { r = 1, g = 0, b = 0 } }); s.store.Set("backgroundPath", "Interface\\x")
    s.Flush()
    local ok, name = DM.SaveLook("  Neat  ")
    check("a name is trimmed, and the look kept on the account", ok == true and name == "Neat"
        and s.account.damageMeterLooks.Neat.barHeight == 30 and s.account.damageMeterLooks.Neat.nameColor.g == 0.2)
    check("it is a copy, not the settings' own table", s.account.damageMeterLooks.Neat.classColors ~= s.store.Get("classColors"))
    check("the names, in order", (function()
        DM.SaveLook("alpha"); DM.SaveLook("Zed")
        local n = DM.LookNames()
        return table.concat(n, ",") == "alpha,Neat,Zed"
    end)())
    s.store.Set("barHeight", 14); s.store.Set("nameColor", false); s.store.Set("classColors", {}); s.Flush()
    check("changed", w.rows[1].h == 14)
    check("a look applied: its settings come back", DM.ApplyLook(DM.SavedLook("Neat")) > 50
        and s.store.Get("barHeight") == 30 and s.store.Get("nameColor").b == 0.3
        and s.store.Get("classColors").MAGE.r == 1)
    s.Flush()
    check("and the window follows", w.rows[1].h == 30)
    s.store.Get("classColors").MAGE.r = 0.5
    check("the settings took a copy: changing theirs does not change the kept look",
        DM.SavedLook("Neat").classColors.MAGE.r == 1)
    s.store.Get("classColors").MAGE.r = 1
    check("what a look does not hold is not touched", s.store.Get("width") == 300 and s.store.Get("mode") == "damage")
    check("a name with nothing in it, or with room for none", DM.SaveLook("   ") == false and DM.SaveLook(nil) == false)
    check("a name is cut", select(2, DM.SaveLook(string.rep("x", 40))) == string.rep("x", 24))
    DM.DeleteLook(string.rep("x", 24))
    DM.DeleteLook("alpha"); DM.DeleteLook("Zed")
    check("deleted", #DM.LookNames() == 1)
    for i = 1, 11 do DM.SaveLook("look" .. i) end
    local full, why = DM.SaveLook("one too many")
    check("twelve at most", #DM.LookNames() == 12 and full == false and why == "full")
    check("but one of them may be kept over again", DM.SaveLook("look3") == true and #DM.LookNames() == 12)
    for i = 1, 11 do DM.DeleteLook("look" .. i) end

    -- as text
    local text = DM.EncodeLook(DM.CaptureLook())
    check("one line, headed", text:sub(1, 6) == "NFDM1|" and not text:find("\n", 1, true))
    local look = DM.DecodeLook(text)
    check("read back: numbers, booleans, strings, colors and the class colors", look.barHeight == 30
        and look.showRanks == true and look.nameColor.r == 0.1 and look.classColors.MAGE.r == 1
        and look.backgroundPath == "Interface\\x" and look.windowColor == false and look.barColor == "class")
    s.store.Set("backgroundPath", "Interface\\AddOns\\My|Folder=x;y%z:\195\169.png")
    local back = DM.DecodeLook(DM.EncodeLook(DM.CaptureLook()))
    check("a string with the characters that mean something comes back whole",
        back.backgroundPath == "Interface\\AddOns\\My|Folder=x;y%z:\195\169.png")
    check("not a look: nil", DM.DecodeLook("hello") == nil and DM.DecodeLook("") == nil and DM.DecodeLook(nil) == nil
        and DM.DecodeLook("NFDM2|barHeight=n20") == nil and DM.DecodeLook("NFDM1|") == nil)
    local part = DM.DecodeLook("NFDM1|barHeight=n24|nonsense=n1|width=n999|showRanks=sno|fontSize=nbad|"
        .. "nameColor=c2,0,0|windowColor=c0.1,0.2,0.3|barAlpha=n0.5|classColors=mMAGE:0.1,0.2,0.3;ROGUE:9,9,9|"
        .. "showBorder=bf")
    check("a key or value that does not fit is left out, the rest is taken", part.barHeight == 24 and part.barAlpha == 0.5
        and part.windowColor.g == 0.2 and part.showBorder == false and part.nonsense == nil and part.width == nil
        and part.showRanks == nil and part.fontSize == nil and part.nameColor == nil and part.classColors == nil)
    check("a number out of any sense is left out", DM.DecodeLook("NFDM1|barHeight=n1e300|barAlpha=n0.5").barHeight == nil
        and DM.DecodeLook("NFDM1|barHeight=n1e300|barAlpha=n0.5").barAlpha == 0.5)
    check("class colors that do not read are left out whole",
        DM.DecodeLook("NFDM1|classColors=mMAGE:bad|barHeight=n24").classColors == nil
        and DM.DecodeLook("NFDM1|classColors=mMAGE:0.1,0.2,0.3|barHeight=n24").classColors.MAGE.g == 0.2)
    check("a text read by trimming its ends", DM.DecodeLook("  NFDM1|barHeight=n22  \n").barHeight == 22)
    local before = s.store.Get("barHeight")
    check("applying what does not fit sets nothing", DM.ApplyLook({ barHeight = "x", showRanks = 5, nameColor = 7 }) == 0
        and s.store.Get("barHeight") == before)
    check("applying it sets what fits", DM.ApplyLook(part) == 4 and s.store.Get("barHeight") == 24)

    -- the page
    local card = CardOf(s.page, "looks")
    check("a card of its own, between Data and Reset and the colors", card ~= nil and card.rowsFn ~= nil)
    local function Rows()
        local out = {}
        for _, row in ipairs(card.rowsFn()) do out[#out + 1] = row end
        return out
    end
    local function Row(label)
        for _, row in ipairs(Rows()) do
            if row.label == label then return row end
        end
    end
    check("its summary", card.summary(s.store) == "1 kept")
    check("the buttons, and a row to apply and one to delete for each look kept", Row("Save This Look") and Row("Export This Look")
        and Row("Import a Look") and Row("Copy to Other Windows") and Row("Neat") and Row("Delete Neat"))
    Row("Save This Look").button()
    check("Save asks for a name, up to 24 letters", s.prompts[1].title == "Name this look" and s.prompts[1].max == 24)
    s.prompts[1].accept("Second")
    check("and keeps it, and draws the page again so that it shows", s.DM.SavedLook("Second") ~= nil
        and Row("Second") ~= nil and s.refreshed == 1)
    s.prompts[1].accept("   ")
    check("a name with nothing in it says so", s.printed[#s.printed] == "A look needs a name.")
    for i = 1, 12 do DM.SaveLook("fill" .. i) end
    s.prompts[1].accept("a thirteenth")
    check("a thirteenth look says there is no room",
        s.printed[#s.printed] == "There is room for twelve looks. Delete one first."
        and DM.SavedLook("a thirteenth") == nil)
    for i = 1, 12 do DM.DeleteLook("fill" .. i) end
    Row("Export This Look").button()
    check("Export shows the text", s.copied.title == "Look" and s.copied.text:sub(1, 6) == "NFDM1|")
    s.store.Set("barHeight", 16)
    Row("Neat").button()
    check("Apply sets that look, and draws the page again", s.store.Get("barHeight") == 30 and s.refreshed == 2)
    Row("Delete Neat").button()
    check("Delete asks first", #s.confirms >= 1 and s.DM.SavedLook("Neat") ~= nil
        and s.confirms[#s.confirms].text == "Delete the look Neat?")
    s.confirms[#s.confirms].yes()
    check("and then deletes", s.DM.SavedLook("Neat") == nil and Row("Neat") == nil)
    Row("Import a Look").button()
    s.prompts[#s.prompts].accept("NFDM1|barHeight=n26|barAlpha=n0.7")
    check("Import applies a text", s.store.Get("barHeight") == 26 and s.store.Get("barAlpha") == 0.7
        and s.prompts[#s.prompts].max == 20000)
    s.prompts[#s.prompts].accept("garbage")
    check("and says when it is not a look", s.printed[#s.printed] == "That is not a look.")

    -- to the other windows
    s.store.Set("barHeight", 22); s.store.Set("fontSize", 13)
    Row("Copy to Other Windows").button()
    check("the others have it as their own", s.store.Get("ownLook2") == true and s.store.Get("ownLook3") == true
        and s.store.Get("barHeight2") == 22 and s.store.Get("fontSize3") == 13)
    s.Flush()
    check("and the second window shows it", s.Window(2).rows[1].h == 22)
end

-- a window may have a look of its own: row height, text, opacities and more
do
    local s = Boot({ settings = { enabled = true, window2 = true, window3 = true } })
    s.Login()
    local one, two, three = s.Window(), s.Window(2), s.Window(3)
    local function Is(c, t) return c and c.r == t.r and c.g == t.g and c.b == t.b end
    check("the same look by default", one.rows[1].h == 20 and two.rows[1].h == 20 and three.rows[1].h == 20
        and s.store.Get("ownLook2") == false)
    s.store.Set("barHeight2", 33); s.Flush()
    check("a value kept for the second is not used until it takes its own look", two.rows[1].h == 20)
    s.store.Set("ownLook2", true); s.Flush()
    check("a window that takes its own look starts from the shared one", s.store.Get("barHeight2") == 20
        and s.store.Get("fontSize2") == 11 and s.store.Get("backgroundAlpha2") == 0.9
        and s.store.Get("showBorder2") == true and s.store.Get("barColor2") == "class")
    s.store.Set("barHeight2", 30); s.store.Set("fontSize2", 15); s.Flush()
    check("then rows 30 tall and text 15 there, and the first untouched", two.rows[1].h == 30
        and two.rows[1].name.fontSize == 15 and one.rows[1].h == 20 and one.rows[1].name.fontSize == 11
        and three.rows[1].h == 20)
    s.store.Set("barHeight", 24); s.Flush()
    check("the shared look moves the others, not the one with its own", one.rows[1].h == 24 and three.rows[1].h == 24
        and two.rows[1].h == 30)
    s.store.Set("barHeight", 20)
    s.store.Set("backgroundAlpha2", 0.2); s.store.Set("headerAlpha2", 0.5); s.store.Set("showBorder2", false); s.Flush()
    check("its opacities and border", two.background.alpha == 0.2 and two.headerBackground.alpha == 0.5
        and two.border._frame.shown == false and one.background.alpha == 0.9 and one.headerBackground.alpha == 1
        and one.border._frame.shown == true)
    s.store.Set("barAlpha2", 0.4); s.store.Set("barColor2", "accent"); s.Flush()
    check("its bars: opacity and color", two.rows[1].color[4] == 0.4 and Is({ r = two.rows[1].color[1],
        g = two.rows[1].color[2], b = two.rows[1].color[3] }, THEME.accent) and one.rows[1].color[4] == 0.85
        and one.rows[1].color[1] == CLASS.MAGE.r)
    s.store.Set("showColumnHeaders2", false); s.store.Set("columns2", "name,total,rate,percent"); s.Flush()
    check("its column titles and share", two.panes[1].headName.shown == false and one.panes[1].headName.shown == true
        and two.rows[1].colP.shown == true and one.rows[1].colP.shown == false)
    s.store.Set("showRanks2", false); s.store.Set("showIcons2", false); s.Flush()
    check("its ranks and icons", two.rows[1].rank.shown == false and two.rows[1].icon.shown == false
        and one.rows[1].rank.shown == true and one.rows[1].icon.shown == true)
    s.store.Set("growUp2", true); s.Flush()
    check("which way it grows", two.rows[1].points[1][5] ~= two.rows[2].points[1][5]
        and two.rows[1].points[1][5] < two.rows[2].points[1][5] and one.rows[1].points[1][5] > one.rows[2].points[1][5])
    s.Hover(two, 2)
    check("the spell panel is in that window's bar color and opacity too", s.Panel().rows[1].color[1] == THEME.accent.r
        and s.Panel().rows[1].color[4] == 0.4)
    two.rows[2].scripts.OnLeave(two.rows[2])
    s.Hover(one, 2)
    check("and the first's in its own", s.Panel().rows[1].color[4] == 0.85)
    one.rows[2].scripts.OnLeave(one.rows[2])
    s.store.Set("barSpacing2", 6); s.Flush()
    check("the spacing between its rows", math.abs(two.rows[1].points[1][5] - two.rows[2].points[1][5]) == 30 + 6
        and math.abs(one.rows[1].points[1][5] - one.rows[2].points[1][5]) == 20 + 2)
    check("a setting that is not a look has no key of its own", s.DM.LookKey(2, "titleSize") == "titleSize"
        and s.DM.LookKey(2, "barHeight") == "barHeight2" and s.DM.LookKey(1, "barHeight") == "barHeight")

    -- its menu writes its own
    two.more.onClick()
    s.menu:Find("Bar Color"):Find("Custom Color").set()
    check("the menu's Bar Color is its own", s.store.Get("barColor2") == "custom" and s.store.Get("barColor") == "class")
    s.Flush()
    check("and the other window's menu the shared one", (function()
        one.more.onClick()
        s.menu:Find("Bar Color"):Find("Theme Accent").set()
        return s.store.Get("barColor") == "accent" and s.store.Get("barColor2") == "custom"
    end)())
    s.store.Set("barColor", "class")

    s.store.Set("ownLook2", false); s.Flush()
    check("off: it looks as the first again", two.rows[1].h == 20 and two.background.alpha == 0.9
        and two.panes[1].headName.shown == true and two.rows[1].rank.shown == true)
    check("and its keys are kept, for when it is on again", s.store.Get("barHeight2") == 30)
    s.store.Set("ownLook2", true); s.Flush()
    check("on again, from the shared look once more", s.store.Get("barHeight2") == 20)

    -- the page: the look and the columns are behind cogs on the window's card
    local card, other = CardOf(s.page, "window2"), CardOf(s.page, "window3")
    local own = RowOf(s.page, "ownLook2")
    check("Own Look is a toggle with a cog, on each window's card", own.toggle == true and own.cog ~= nil
        and select(2, RowOf(s.page, "ownLook2")) == card and select(2, RowOf(s.page, "ownLook3")) == other
        and card.switch == "window2" and other.switch == "window3")
    local got = {}
    for _, row in ipairs(card.rows) do
        if row.under == "Own Look" then got[#got + 1] = row.key end
    end
    check("with the settings a window may have behind it", table.concat(got, ",") == "barHeight2,barSpacing2,"
        .. "barAlpha2,growUp2,fontSize2,showIcons2,showRanks2,backgroundAlpha2,headerAlpha2,showBorder2,barColor2")
    got = {}
    for _, row in ipairs(card.rows) do
        if row.under == "Column 1" then got[#got + 1] = row.label end
    end
    check("and its columns behind the first column, whose key is the setting's", RowOf(s.page, "columns2").cog ~= nil
        and RowOf(s.page, "columns2").label == "Column 1" and table.concat(got, ",")
        == "Column 2,Column 3,Column 4,Column 5,Column 6,Column Divider,Column Titles"
        and RowOf(s.page, "showDivider2").under == "Column 1" and RowOf(s.page, "showColumnHeaders2").under == "Column 1")
    check("they wait for the look, and say so", RowOf(s.page, "barHeight2").needs() == true
        and RowOf(s.page, "barHeight3").needs() == false and RowOf(s.page, "barHeight3").why == "Turn on Own Look"
        and RowOf(s.page, "columns3").needs() == false)
    s.store.Set("ownLook3", true)
    check("a third one's own", s.store.Get("barHeight3") == 20 and RowOf(s.page, "barHeight3").needs() == true)
end

-- each window has its own scale, and a change keeps its corner where it was
do
    local s = Boot({ settings = { enabled = true, window2 = true,
        meterPos = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 210 } } })
    s.env.UIParent.h = 1000
    s.Login()
    local one, two = s.Window(), s.Window(2)
    check("a window is full size by default", one.scale == 1 and two.scale == 1 and s.store.Get("scale") == 1)
    s.store.Set("scale", 1.5); s.Flush()
    check("Scale makes it that large, the other not", one.scale == 1.5 and two.scale == 1)
    local pos = s.store.Get("meterPos")
    check("its place is in its own units, converted so the corner stays", pos.point == "BOTTOMRIGHT"
        and math.abs(pos.x - (-16)) < 1e-9 and math.abs(pos.y - 140) < 1e-9)
    check("and put back that way", one.points[1][1] == "BOTTOMRIGHT" and math.abs(one.points[1][4] - (-16)) < 1e-9)
    s.store.Set("scale2", 0.5); s.Flush()
    check("the second has its own", two.scale == 0.5 and one.scale == 1.5)
    one.header.scripts.OnDragStart(one.header)
    one.header.scripts.OnDragStop(one.header)
    local saved = s.store.Get("meterPos")
    check("a drag is saved in the window's units: its left, and its top from the screen's top, over the scale",
        saved.point == "TOPLEFT" and saved.x == 100 and math.abs(saved.y - (300 - 1000 / 1.5)) < 1e-9)
    s.store.Set("scale", 1); s.Flush()
    saved = s.store.Get("meterPos")
    check("back to full size: converted back", one.scale == 1 and math.abs(saved.x - 150) < 1e-9
        and math.abs(saved.y - 1.5 * (300 - 1000 / 1.5)) < 1e-9)
    local row = RowOf(s.page, "scale")
    check("Scale on the Window card, from half to double, in steps of five percent", row and row.slider[1] == 50
        and row.slider[2] == 200 and row.slider[3] == 5 and row.unit == "%" and row.scale == 0.01)
    check("and on the other windows' cards", RowOf(s.page, "scale2") ~= nil and RowOf(s.page, "scale3") ~= nil)
    local width = RowOf(s.page, "width")
    local height = RowOf(s.page, "height")
    check("windows may be as wide and tall as a thousand", width.slider[2] == 1000 and height.slider[2] == 1000)
end

-- more windows: each with its own list, session, size and place
do
    local s = Boot({ settings = { enabled = true, window2 = true, mode2 = "taken", session2 = "overall", width2 = 240,
        height2 = 120 } })
    s.Login()
    local one, two = s.Window(), s.Window(2)
    check("a second window, shown", two and two.shown and s.Window(3) == nil)
    check("its own list and session", two.title.text == "Damage Taken" and two.session.label == "Overall"
        and one.title.text == "Damage Done" and one.session.label == "Current")
    check("each asked the game for its own", s.calls[#s.calls][2] == 7 and s.calls[#s.calls][1] == 0)
    check("its own size", two.w == 240 and two.h == 120 and one.w == 300 and one.h == 206)
    s.store.Set("mode2", "healing")
    s.Flush()
    check("a change to one leaves the other", two.title.text == "Healing Done" and one.title.text == "Damage Done")
    two.more.onClick()
    s.menu:Find("List"):Find("Absorbs").set()
    check("a window's list menu sets its own list", s.store.Get("mode2") == "absorbs" and s.settings.mode == nil)
    two.header.scripts.OnDragStart(two.header)
    two.header.scripts.OnDragStop(two.header)
    check("dragging a window saves its own place", s.store.Get("meterPos2").point == "TOPLEFT"
        and s.settings.meterPos == nil)
    check("their own name, page and card for Unlock Mode", s.movers["Damage Meter"].card == "Damage Meter/Settings:window"
        and s.movers["Damage Meter 2"].card == "Damage Meter/Settings:window2"
        and s.movers["Damage Meter 2"].page == "Damage Meter/Settings")
    s.movers["Damage Meter 2"].save({ point = "CENTER", relPoint = "CENTER", x = 5, y = 6 })
    check("a moved window saves its own place", s.store.Get("meterPos2").x == 5 and s.store.Get("meterPos").x == -24)
    check("the others start stacked above the first", s.settings.meterPos == nil and s.store.Get("meterPos").y == 210
        and s.store.Get("meterPos3").y == 630)
    check("keys carry the window's number", s.DM.Key("mode", 1) == "mode" and s.DM.Key("mode", 2) == "mode2"
        and s.DM.Key("width", 3) == "width3")
    s.store.Set("window2", false)
    check("switching one off hides just it", two.shown == false and one.shown == true)
    s.store.Set("enabled", false)
    check("the module off hides all", one.shown == false and not s.Listening())
end

-- all three windows: each mover points at its own card
do
    local s = Boot({ settings = { enabled = true, window2 = true, window3 = true } })
    s.Login()
    check("three windows, each with its own card in Unlock Mode", s.Window(3) ~= nil
        and s.movers["Damage Meter"].card == "Damage Meter/Settings:window"
        and s.movers["Damage Meter 2"].card == "Damage Meter/Settings:window2"
        and s.movers["Damage Meter 3"].card == "Damage Meter/Settings:window3")
end

-- the wheel scrolls the window under it, from its rows or from its frame
do
    local s = Boot({ settings = { enabled = true, window2 = true, height2 = 70 } })
    s.Login()
    local one, two = s.Window(), s.Window(2)
    check("a short window shows one row", two.rows[1].shown == true and two.rows[2] == nil
        and two.rows[1].name.text == "Aldrin")
    two.rows[1].scripts.OnMouseWheel(two.rows[1], -1)
    check("a row passes the wheel to its window: one row down", two.rows[1].name.text == "You"
        and two.rows[1].rank.text == "2" and one.rows[1].name.text == "Aldrin")
    two.scripts.OnMouseWheel(two, -1)
    check("and the frame scrolls it too", two.rows[1].name.text == "Cara")
    two.scripts.OnMouseWheel(two, -1)
    check("not past the last row", two.rows[1].name.text == "Cara")
    two.scripts.OnMouseWheel(two, 2)
    check("and back to the top", two.rows[1].name.text == "Aldrin")
end

-- the second window's grip saves its own size
do
    local s = Boot({ settings = { enabled = true, window2 = true } })
    s.Login()
    local two = s.Window(2)
    local grip
    for _, f in ipairs(s.frames) do
        if f.parent == two and f.kind == "Button" and f.scripts.OnMouseDown then grip = f end
    end
    grip.scripts.OnMouseDown(grip, "LeftButton")
    check("the grip sizes the window", two.sizingFrom == "BOTTOMRIGHT")
    two.w, two.h = 260.4, 150.6
    grip.scripts.OnMouseUp(grip)
    check("and saves its size under its number", s.store.Get("width2") == 260 and s.store.Get("height2") == 151
        and s.settings.width == nil)
end

-- where it shows
do
    local s = Boot({ settings = { enabled = true, visibility = "group", window2 = true } })
    s.Login()
    check("In a Group: hidden alone", s.Window().shown == false and s.Window(2).shown == false)
    s.group = true
    s.Fire("GROUP_ROSTER_UPDATE"); s.Flush()
    check("and shown in a group", s.Window().shown == true and s.Window(2).shown == true)
    s.store.Set("visibility", "instance"); s.Flush()
    check("In Instances: hidden outside one", s.Window().shown == false)
    s.instance = true
    s.Fire("PLAYER_ENTERING_WORLD"); s.Flush()
    check("and shown inside", s.Window().shown == true)
end

-- the game's own meter
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    check("the game's meter is turned off, and what it was is kept", s.cvars.damageMeterEnabled == "0" and s.account.damageMeterGameWas == "1")
    s.store.Set("enabled", false)
    check("off again: it is put back as it was", s.cvars.damageMeterEnabled == "1" and s.account.damageMeterGameWas == nil)
    s.store.Set("enabled", true)
    s.store.Set("hideGameMeter", false)
    check("Replace the Game's Meter off: put back too", s.cvars.damageMeterEnabled == "1")

    local off = Boot({ settings = { enabled = true }, gameMeter = "0" })
    off.Login()
    check("a game meter that was off: nothing kept, nothing restored later", off.account.damageMeterGameWas == nil)
    off.store.Set("enabled", false)
    check("and left off", off.cvars.damageMeterEnabled == "0")

    local fight = Boot({ settings = { enabled = true } })
    fight.combat = true
    fight.Login()
    check("in combat: the game's meter is left for later", fight.cvars.damageMeterEnabled == "1")
    fight.combat = false
    fight.Fire("PLAYER_REGEN_ENABLED"); fight.Flush()
    check("and turned off when combat ends", fight.cvars.damageMeterEnabled == "0")
end

-- Unlock Mode shows the sample, and switching the meter off while it is unlocked stops the listening
do
    local s = Boot({ settings = { enabled = true, window2 = true } })
    s.Login()
    s.ns.ShowUnlockMode()
    local w = s.Window()
    check("Unlock Mode: the sample and the mover, on every open window", #w.rows == 7 and s.Window(2).rows[7] ~= nil
        and s.movers["Damage Meter 2"].mover.shown == true and s.movers["Damage Meter"].mover.shown == true)
    s.store.Set("enabled", false)
    check("switched off while unlocked: no damage meter events", not s.Listening())
    s.ns.HideUnlockMode()
    check("locked again: the windows go", w.shown == false and s.Window(2).shown == false)
end

-- updates are coalesced, and the sample shows without data
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local before = #s.calls
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    s.Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    check("an update is requested once for a burst", #s.timers == 1)
    s.Flush()
    check("and reads the session once", #s.calls == before + 1)
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("a reset redraws", #s.calls == before + 2)

    s.apiResult = { combatSources = {}, maxAmount = Amount("0"), totalAmount = Amount("0") }
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    local w = s.Window()
    check("no sources: the empty line, no rows shown", w.empty.shown == true and w.empty.text == "No data yet"
        and w.rows[1].shown == false)
    s.apiResult = nil

    s.ns.PreviewDamageMeter()
    check("the preview shows the sample's seven rows", #w.rows == 7 and w.rows[7].shown == true and w.rows[7].name.text == "Fenna")
    s.Flush()
    check("and ends after its seconds, back to the three real ones", w.rows[4].shown == false and w.rows[3].shown == true)

    s.combat = true
    s.printed = {}
    s.ns.PreviewDamageMeter()
    check("in combat: no preview, and it says why", #s.printed == 1)
end

-- the unavailable game meter
do
    local s = Boot({ settings = { enabled = true } })
    s.env.C_DamageMeter = nil
    s.Login()
    local w = s.Window()
    check("no API: the window says so", w.empty.text == "The damage meter is not available" and w.empty.shown == true)

    local s2 = Boot({ settings = { enabled = true } })
    s2.unavailable = "Not available in this zone."
    s2.Login()
    local w2 = s2.Window()
    check("the game says it is not available: the window gives its reason",
        w2.empty.text == "Not available in this zone." and w2.empty.shown == true)
    s2.unavailable = ""
    s2.Fire("GROUP_ROSTER_UPDATE"); s2.Flush()
    check("and with no reason, that it is not available", w2.empty.text == "The damage meter is not available")
    s2.unavailable = nil
    s2.Fire("GROUP_ROSTER_UPDATE"); s2.Flush()
    check("and once it is: the window is back", w2.empty.text ~= "The damage meter is not available")
end

-- with the addon disabled or removed, the core puts the game's meter back at login
do
    local f = assert(io.open("Core/Core.lua", "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    local first = assert(source:find("local function RestoreGameMeter()", 1, true))
    local last = assert(source:find("\nlocal meterCheck", first, true))
    local names = assert(source:match("\n(local DAMAGE_METER_ADDON, .-\n)local "))
    local account, cvars, loaded, combat = {}, { damageMeterEnabled = "0" }, false, false
    local chunk = assert(loadstring(names .. source:sub(first, last) .. "return RestoreGameMeter"))
    setfenv(chunk, setmetatable({
        ns = { AccountSettings = function() return account end },
        C_AddOns = { IsAddOnLoaded = function(name) return loaded and name == "NaowhForever_DamageMeter" end },
        InCombatLockdown = function() return combat end,
        C_CVar = { SetCVar = function(k, v) cvars[k] = v end },
    }, { __index = _G }))
    local Restore = chunk()
    Restore()
    check("core: nothing kept, nothing changed", cvars.damageMeterEnabled == "0")
    account.damageMeterGameWas = "1"
    loaded = true
    Restore()
    check("core: the addon loaded is left to put it back itself",
        cvars.damageMeterEnabled == "0" and account.damageMeterGameWas == "1")
    loaded, combat = false, true
    Restore()
    check("core: not in combat", cvars.damageMeterEnabled == "0" and account.damageMeterGameWas == "1")
    combat = false
    Restore()
    check("core: the addon not loaded: put back as it was, and forgotten",
        cvars.damageMeterEnabled == "1" and account.damageMeterGameWas == nil)
end

-- the reset key
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    s.env.NaowhForever_ResetDamageMeter()
    check("the reset key clears the data and says so", s.resets == 1 and #s.printed == 1 and #s.confirms == 0)
end

-- the report
do
    local s = Boot({ settings = { enabled = true, reportLines = 2 } })
    s.Login()
    local DM = s.DM
    local plain = { combatSources = {
        { name = "Aldrin", totalAmount = 1500, amountPerSecond = 150 }, { name = SECRET_TEXT, totalAmount = 1200, amountPerSecond = 120 },
        { name = "You", totalAmount = 900, amountPerSecond = 90 }, { name = "Cara", totalAmount = SECRET_NUMBER, amountPerSecond = 30 },
        { name = Amount("table"), totalAmount = 200, amountPerSecond = 20 }, { name = "Dan", totalAmount = 100, amountPerSecond = 10 },
    }, maxAmount = 1500, totalAmount = 4000 }
    local lines = DM.ReportLines(plain, DM.Mode("damage"), "Current", 2, true)
    check("a header, then the top rows with total and rate", #lines == 3 and lines[1] == "Damage Done, Current"
        and lines[2] == "1. Aldrin  <1500> (<150>)")
    check("a secret name is left out and the ranks go on", lines[3] == "2. You  <900> (<90>)")
    lines = DM.ReportLines(plain, DM.Mode("damage"), "Current", 10, false)
    check("without the rate, the total alone; secret names and amounts left out",
        #lines == 4 and lines[2] == "1. Aldrin  <1500>" and lines[4] == "3. Dan  <100>")
    lines = DM.ReportLines(plain, DM.Mode("interrupts"), "Overall", 1, true)
    check("a list without a rate has none", lines[1] == "Interrupts, Overall" and lines[2] == "1. Aldrin  <1500>")
    check("a secret rate is left off the line", DM.ReportLines({ combatSources = { { name = "A", totalAmount = 5,
        amountPerSecond = SECRET_NUMBER } } }, DM.Mode("damage"), "x", 5, true)[2] == "1. A  <5>")

    s.apiResult = plain
    DM.Report("PARTY", "damage", "current", nil)
    check("sent to the channel, header first, as many as Report Lines says", #s.sent == 3 and s.sent[1].channel == "PARTY"
        and s.sent[1].text == "Damage Done, Current" and s.sent[3].text == "2. You  <900> (<90>)")
    s.sent = {}
    s.store.Set("columns", "name,total")
    DM.Report("RAID", "damage", "overall", nil)
    check("no Per Second column: totals only", s.sent[2].text == "1. Aldrin  <1500>" and s.sent[1].text == "Damage Done, Overall")
    s.sent = {}
    s.printed = {}
    DM.Report("SELF", "damage", "current", nil)
    check("Yourself: printed, not sent", #s.sent == 0 and #s.printed == 3)
    s.printed = {}
    s.combat = true
    DM.Report("SAY", "damage", "current", nil)
    check("in combat: nothing is sent, and it says why", #s.sent == 0 and #s.printed == 1)
    s.combat = false
    s.printed = {}
    s.apiResult = { combatSources = {}, maxAmount = 0, totalAmount = 0 }
    DM.Report("SAY", "damage", "current", nil)
    check("nothing to report: it says so", #s.sent == 0 and #s.printed == 1)
    s.apiResult = nil
    s.sent = {}
    s.fights = { { sessionID = 3, name = "Boss", durationSeconds = 60 } }
    s.idResult = plain
    DM.Report("GUILD", "damage", "current", 3)
    check("a past fight is reported by its name", s.sent[1].text == "Damage Done, Boss (1:00)" and s.idCalls[#s.idCalls][1] == 3)

    s.apiResult = plain
    s.sent = {}
    s.Window().more.onClick()
    s.menu:Find("Report To"):Find("Say").onClick()
    check("the menu's channel sends what its window shows", #s.sent == 3 and s.sent[1].channel == "SAY"
        and s.sent[1].text == "Damage Done, Current")
end

-- the spell panel's size, side and opacity, how many enemies, and how many past fights are offered
do
    local function Enemy(name, guid) return { name = name, sourceGUID = guid, sourceCreatureID = 100 } end
    local function Hit(who, total) return { totalAmount = total, combatSpellDetails = { unitName = who } } end
    local s = Boot({ settings = { enabled = true } })
    s.duration = 120
    local many, hits, mobs = {}, {}, {}
    for i = 1, 14 do many[i] = Spell(300 + i, 200 - i) end
    s.spells = { combatSpells = many, maxAmount = 200, totalAmount = 2000 }
    for i = 1, 8 do
        mobs[i] = Enemy("Mob " .. i, "E-" .. i)
        hits["E-" .. i] = { combatSpells = { Hit("You", 100 - i) } }
    end
    s.byType = { [10] = { combatSources = mobs } }
    s.enemyData = hits
    s.session.combatSources[2].name = "You"
    s.Login()
    local w = s.Window()
    local C = s.DM.C
    s.Hover(w, 2)
    local panel = s.Panel()
    local function Shown(rows)
        local n = 0
        for _, row in ipairs(rows) do
            if row.shown then n = n + 1 end
        end
        return n
    end
    check("by default: eight spells, five enemies, 300 wide, full size and opacity", Shown(panel.rows) == 8
        and Shown(panel.targetRows) == 5 and panel.w == 300 and panel.scale == 1 and panel.background.alpha == 1)
    s.store.Set("panelLines", 3); s.store.Set("targetLines", 2); s.Flush()
    s.Hover(w, 2)
    check("Spells Shown and Enemies Shown", Shown(panel.rows) == 3 and Shown(panel.targetRows) == 2
        and panel.h == 24 + 3 * 20 - 2 + 6 + 16 + 2 * 20 - 2 + 6)
    s.store.Set("panelLines", 15); s.store.Set("targetLines", 10); s.Flush()
    s.Hover(w, 2)
    check("up to fifteen and ten, as many as there are", Shown(panel.rows) == 14 and Shown(panel.targetRows) == 8)
    s.store.Set("panelWidth", 420); s.Flush()
    s.Hover(w, 2)
    check("Panel Width: the panel and its rows", panel.w == 420 and panel.rows[1].w == 408 and panel.targetRows[1].w == 408)
    s.store.Set("panelScale", 1.25); s.store.Set("panelAlpha", 0.5); s.Flush()
    s.Hover(w, 2)
    check("Panel Scale and Opacity", panel.scale == 1.25 and panel.background.alpha == 0.5
        and panel.border._frame.alpha == 0.5)
    w.centerX = 100
    s.Hover(w, 2)
    check("auto: on the side the window leaves room", panel.points[1][1] == "TOPLEFT")
    s.store.Set("panelSide", "left"); s.Flush()
    s.Hover(w, 2)
    check("Panel Side left, whatever the window's place", panel.points[1][1] == "TOPRIGHT")
    w.centerX = 900
    s.store.Set("panelSide", "right"); s.Flush()
    s.Hover(w, 2)
    check("or right", panel.points[1][1] == "TOPLEFT")
    s.store.Set("panelSide", "auto"); s.Flush()
    s.Hover(w, 2)
    check("or as the screen has room", panel.points[1][1] == "TOPRIGHT")
    w.rows[2].scripts.OnLeave(w.rows[2])

    -- the enemies of a player's breakdown follow it
    s.store.Set("targetLines", 3); s.store.Set("height", 500); s.Flush()
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    local names = {}
    for _, row in ipairs(w.rows) do
        if row.shown and row.name.text:find("^Mob") then names[#names + 1] = row.name.text end
    end
    check("Enemies Shown in a breakdown too", #names == 3)
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")

    -- past fights offered
    s.fights = {}
    for i = 1, 12 do s.fights[i] = { sessionID = i, durationSeconds = 10 } end
    w.session.onClick()
    local offered = 0
    for _, item in ipairs(s.menu.items) do
        if item.kind == "radio" and item.text:find("^Fight ") then offered = offered + 1 end
    end
    check("the ten newest past fights by default", offered == 10)
    s.store.Set("fightsShown", 3)
    w.session.onClick()
    offered = 0
    for _, item in ipairs(s.menu.items) do
        if item.kind == "radio" and item.text:find("^Fight ") then offered = offered + 1 end
    end
    check("Past Fights Offered", offered == 3 and s.menu:Find("Fight 12 (0:10)") ~= nil)

    local rows = { "panelLines", "targetLines", "panelWidth", "panelScale", "panelAlpha", "panelSide", "fightsShown" }
    local all = true
    for _, key in ipairs(rows) do all = all and RowOf(s.page, key) ~= nil end
    check("each has a row", all)
    check("the ranges", RowOf(s.page, "panelLines").slider[2] == 15 and RowOf(s.page, "targetLines").slider[2] == 10
        and RowOf(s.page, "panelWidth").slider[1] == 240 and RowOf(s.page, "panelWidth").slider[2] == 480
        and RowOf(s.page, "fightsShown").slider[2] == 30 and C.PANEL_SIDES_ORDER[1] == "auto")
end

-- the spell breakdown on hover
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    local row = s.Hover(w, 2)
    local panel = s.Panel()
    check("hover: the panel shows, titled by the row", panel and panel.shown and panel.title.text == "You")
    check("with the spells of your row, by your own guid", s.spellCalls[#s.spellCalls].guid == "Player-1")
    check("the spells, in the game's order, with their names", panel.rows[1].name.text == "Fireball"
        and panel.rows[2].name.text == "Pyroblast" and panel.rows[3].name.text == "Unknown")
    check("each a bar out of the largest", panel.rows[2].barMax == 600 and panel.rows[2].barValue == 300)
    check("amount, per second and share when they are plain", panel.rows[1].value.text == "<600>  <4.8>  60.0%"
        and panel.rows[3].value.text == "<100>  <0.8>  10.0%")
    check("and the spell's icon", panel.rows[1].icon.texture == 1101 and panel.rows[1].icon.shown == true)
    check("only as many rows as spells, and no note", panel.rows[4].shown == false and panel.note.shown == false
        and panel.h == 24 + 3 * 20 - 2 + 6)
    check("the bars in the row's class color", panel.rows[1].color[1] == CLASS.ROGUE.r)
    local spells = s.spells
    local many = {}
    for i = 1, 12 do many[i] = Spell(200 + i, 100 - i) end
    s.spells = { combatSpells = many, maxAmount = 100, totalAmount = 1000 }
    s.Hover(w, 2)
    check("at most eight spells", panel.rows[8].shown == true and panel.h == 24 + 8 * 20 - 2 + 6)
    s.spells = spells
    s.Hover(w, 2)
    check("on the left of a window on the right half, the right of one on the left",
        panel.points[1][1] == "TOPRIGHT" and panel.points[1][2] == row)
    w.centerX = 100
    s.Hover(w, 2)
    check("a window on the left half: beside its right edge", s.Panel().points[1][1] == "TOPLEFT")
    w.rows[2].scripts.OnLeave(w.rows[2])
    check("leaving hides it", panel.shown == false)

    s.spells.totalAmount = SECRET_NUMBER
    s.Hover(w, 2)
    check("a secret total: amount and per second, no share", panel.rows[1].value.text == "<600>  <4.8>")
    s.spells.totalAmount = 1000
    s.noTexture = true
    s.Hover(w, 2)
    check("an icon the game refuses: no icon, no error", panel.rows[1].icon.shown == false)
    s.noTexture = nil
    s.names = { [101] = SECRET_TEXT }
    s.Hover(w, 2)
    check("a secret name goes to the text as it is", panel.rows[1].name.text == SECRET_TEXT)
    s.names = { [101] = "Fireball", [102] = "Pyroblast" }
    s.Hover(w, 2)
    check("the panel names the list and the session's length", panel.subtitle.text == "Damage Done (2:05)")
    s.store.Set("mode", "interrupts"); s.Flush()
    s.Hover(w, 2)
    check("a list with no per-second figure: the amount and the share", panel.rows[1].value.text == "<600>  60.0%"
        and panel.subtitle.text == "Interrupts (2:05)")
    s.store.Set("mode", "damage"); s.Flush()

    s.combat = true
    s.Hover(w, 1)
    check("in combat, a row with a readable guid still shows", panel.rows[1].shown == true)
    s.session.combatSources[1].sourceGUID = SECRET_TEXT
    s.spellCalls = {}
    s.Hover(w, 1)
    check("in combat, a row with a secret guid says spells show after combat", #s.spellCalls == 0 and panel.rows[1].shown == false
        and panel.note.text == "Spells show after combat." and panel.note.shown == true)
    s.combat = false
    s.Hover(w, 1)
    check("out of combat with no data: a plain note", panel.note.text == "No spell data.")
    s.session.combatSources[1].sourceGUID = "Player-2"
    s.spellsResult = { combatSpells = {} }
    s.Hover(w, 1)
    check("a source with no spells says so", panel.note.text == "No spell data." and panel.note.shown == true)
    s.spellsResult = nil

    s.store.Set("mode", "deaths"); s.Flush()
    s.spellCalls = {}
    w.rows[1].scripts.OnLeave(w.rows[1])
    s.Hover(w, 1)
    check("Deaths: no panel, no question", panel.shown == false and #s.spellCalls == 0)
    s.store.Set("mode", "damage"); s.Flush()

    s.store.Set("breakdown", false)
    s.spellCalls = {}
    s.Hover(w, 2)
    check("Spell Breakdown off: nothing", panel.shown == false and #s.spellCalls == 0)
    s.store.Set("breakdown", true)
end

-- the targets: the enemies a player hurt, from the enemies' own damage taken, after combat
do
    local function Enemy(name, guid) return { name = name, sourceGUID = guid, sourceCreatureID = 100 } end
    local function Hit(who, total) return { totalAmount = total, combatSpellDetails = { unitName = who } } end
    local function Setup(extra)
        local s = Boot({ settings = { enabled = true } })
        s.duration = 120
        s.byType = { [10] = { combatSources = { Enemy("Defias Cutpurse", "E-1"), Enemy("Defias Thug", "E-2"),
            Enemy("Gnoll Brute", "E-3"), Enemy("Unhurt", "E-4"), Enemy("Hidden", SECRET_TEXT) } } }
        s.enemyData = {
            ["E-1"] = { combatSpells = { Hit("You", 100), Hit("You", 20), Hit("Aldrin", 500) } },
            ["E-2"] = { combatSpells = { Hit("You", 60), Hit(SECRET_TEXT, 999), { totalAmount = 5 } } },
            ["E-3"] = { combatSpells = { Hit("You", 12), Hit("You", SECRET_NUMBER) } },
            ["E-4"] = { combatSpells = { Hit("Aldrin", 40) } },
        }
        if extra then extra(s) end
        s.Login()
        return s
    end

    local s = Setup()
    local w = s.Window()
    s.session.combatSources[2].name = "You"
    s.Hover(w, 2)
    local panel = s.Panel()
    check("after combat the panel has a Targets section under the spells", panel.targetsTitle.shown == true
        and panel.targetsTitle.text == "Targets")
    check("the enemies the player hurt, biggest first, with what each took and the per-second figure",
        panel.targetRows[1].name.text == "Defias Cutpurse" and panel.targetRows[1].value.text == "<120> | <1>"
        and panel.targetRows[2].name.text == "Defias Thug" and panel.targetRows[2].value.text == "<60> | <0.5>"
        and panel.targetRows[3].name.text == "Gnoll Brute" and panel.targetRows[3].value.text == "<12> | <0.1>")
    check("only the player's spells are added; others' are not, nor secret ones", panel.targetRows[4].shown == false)
    check("the bars against the largest, in the enemy's red", panel.targetRows[1].barMax == 120
        and panel.targetRows[2].barValue == 60 and panel.targetRows[1].color[1] == 0.78)
    check("under the spells: the section, then its rows", panel.targetsTitle.points[1][5] == -(24 + 3 * 20 - 2 + 6)
        and panel.targetRows[1].points[1][5] == -(24 + 3 * 20 - 2 + 6 + 16))
    check("and the panel is as tall as both", panel.h == 24 + 3 * 20 - 2 + 6 + 16 + 3 * 20 - 2 + 6)
    local asked = #s.enemyCalls
    check("each enemy was asked, with its guid and creature", asked == 4 and s.enemyCalls[1].guid == "E-1"
        and s.enemyCalls[1].creature == 100 and s.enemyCalls[1].kind == 1)
    w.rows[2].scripts.OnLeave(w.rows[2])
    s.Hover(w, 2)
    check("hovering again reads from what was read", #s.enemyCalls == asked)
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    s.Hover(w, 2)
    check("a change in the data reads again", #s.enemyCalls > asked)

    s.combat = true
    local before = #s.enemyCalls
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    s.Hover(w, 2)
    check("in combat there are none, and the game is not asked", panel.targetsTitle.shown == false
        and panel.targetRows[1].shown == false and #s.enemyCalls == before)
    s.combat = false

    s.store.Set("mode", "healing"); s.Flush()
    local calls = #s.enemyCalls
    s.Hover(w, 2)
    check("only for damage: Healing Done has no targets", panel.targetsTitle.shown == false and #s.enemyCalls == calls)
    s.store.Set("mode", "dps"); s.Flush()
    s.Hover(w, 2)
    check("DPS has them", panel.targetsTitle.shown == true)
    s.store.Set("mode", "damage"); s.Flush()

    s.fights = { { sessionID = 4, name = "Pull" } }
    w.session.onClick()
    s.menu:Find("Pull").set()
    s.Flush()
    s.Hover(w, 2)
    check("a past fight is read by its id", #s.enemyIdCalls > 0 and s.enemyIdCalls[1].id == 4)

    -- nothing to show
    local none = Setup(function(t) t.enemyData = {} end)
    none.Hover(none.Window(), 2)
    check("no enemy hurt by the player: no section", none.Panel().targetsTitle.shown == false
        and none.DM.Targets("current", nil, "You") == nil)
    local secretName = Setup()
    secretName.session.combatSources[2].name = SECRET_TEXT
    secretName.Hover(secretName.Window(), 2)
    check("a name the game keeps back: no section, and no question", secretName.Panel().targetsTitle.shown == false
        and #secretName.enemyCalls == 0)
    local DM = secretName.DM
    check("a missing API: none", (function()
        secretName.env.C_DamageMeter = nil
        return DM.Targets("current", nil, "You") == nil
    end)())

    local many = Setup(function(t)
        local sources, data = {}, {}
        for i = 1, 8 do
            sources[i] = Enemy("Mob " .. i, "M-" .. i)
            data["M-" .. i] = { combatSpells = { Hit("You", i * 10) } }
        end
        t.byType = { [10] = { combatSources = sources } }
        t.enemyData = data
    end)
    many.Hover(many.Window(), 2)
    local mp = many.Panel()
    check("at most five, the biggest", mp.targetRows[1].name.text == "Mob 8" and mp.targetRows[5].name.text == "Mob 4"
        and mp.targetRows[5].shown == true)
    check("each bar against the largest, and the panel as tall as the five",
        mp.targetRows[5].barMax == 80 and mp.targetRows[5].barValue == 40
        and mp.h == 24 + 3 * 20 - 2 + 6 + 16 + 5 * 20 - 2 + 6)
end

-- the panel follows updates, and goes with its window
do
    local s = Boot({ settings = { enabled = true, visibility = "group" } })
    s.group = true
    s.Login()
    local w = s.Window()
    s.Hover(w, 2)
    local panel = s.Panel()
    s.spells.combatSpells = { Spell(101, 50) }
    s.spells.maxAmount, s.spells.totalAmount = 50, 100
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("an update redraws the hovered row's spells", panel.rows[1].value.text == "<50>  <0.4>  50.0%"
        and panel.rows[2].shown == false)
    s.group = false
    s.Fire("GROUP_ROSTER_UPDATE"); s.Flush()
    check("the window hiding takes the panel with it", w.shown == false and panel.shown == false)

    local sample = Boot({ settings = { enabled = true } })
    sample.Login()
    sample.ns.ShowUnlockMode()
    sample.Hover(sample.Window(), 1)
    check("the sample has no spells to show", sample.Panel() == nil or sample.Panel().shown == false)
end

-- more rules for when it shows, and when the data is cleared
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    s.store.Set("visibility", "raid"); s.Flush()
    check("In a Raid: not in a party", w.shown == false)
    s.raid = true
    s.Fire("GROUP_ROSTER_UPDATE"); s.Flush()
    check("and shown in a raid", w.shown == true)
    s.raid = false
    s.store.Set("visibility", "always"); s.Flush()
    check("always again", w.shown == true)

    s.instance, s.instanceType = true, "pvp"
    s.store.Set("hideInPvP", true); s.Flush()
    check("Hide in Battlegrounds: hidden in one", w.shown == false)
    s.instanceType = "arena"
    s.Fire("PLAYER_ENTERING_WORLD", false, false); s.Flush()
    check("and in an arena", w.shown == false)
    s.instanceType = "party"
    s.Fire("PLAYER_ENTERING_WORLD", false, false); s.Flush()
    check("not in a dungeon", w.shown == true)
    s.instanceType = "pvp"
    s.store.Set("hideInPvP", false); s.Flush()
    check("and not when it is off", w.shown == true)
    s.instance, s.instanceType = false, nil

    -- clearing the data on entering an instance
    local r = Boot({ settings = { enabled = true } })
    r.Login()
    r.instance, r.instanceType, r.instanceID = true, "party", 100
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    check("never, by default", (r.resets or 0) == 0 and #r.confirms == 0)
    r.store.Set("resetOn", "instance")
    r.instance, r.instanceID = false, nil
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    r.instance, r.instanceID = true, 200
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    check("entering an instance clears it, and says so", r.resets == 1 and r.printed[#r.printed] == "Damage meter data reset.")
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    check("a zone change inside the same one does not", r.resets == 1)
    r.instance, r.instanceID = false, nil
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    check("nor leaving it", r.resets == 1)
    r.instance, r.instanceID = true, 200
    r.Fire("PLAYER_ENTERING_WORLD", true, false)
    check("a login is not entering", r.resets == 1)
    r.instance, r.instanceID = false, nil
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    r.instance, r.instanceID = true, 300
    r.Fire("PLAYER_ENTERING_WORLD", false, true)
    check("nor is a reload", r.resets == 1)
    r.instance, r.instanceID = false, nil
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    r.combat = true
    r.instance, r.instanceID = true, 400
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    check("nothing is cleared in combat", r.resets == 1)
    r.combat = false
    r.instance, r.instanceID = false, nil
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    r.store.Set("resetOn", "ask")
    r.combat = true
    r.instance, r.instanceID = true, 450
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    check("and nothing is asked in combat", #r.confirms == 0)
    r.combat = false
    r.instance, r.instanceID = false, nil
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    r.instance, r.instanceID = true, 500
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    check("Ask: a question first, and nothing yet", #r.confirms == 1 and r.resets == 1
        and r.confirms[1].text:find("Reset the damage meter data", 1, true) ~= nil)
    r.confirms[1].yes()
    check("a yes clears it", r.resets == 2)
    r.instance, r.instanceID = false, nil
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    r.store.Set("resetOn", "never")
    r.instance, r.instanceID = true, 600
    r.Fire("PLAYER_ENTERING_WORLD", false, false)
    check("never again", r.resets == 2 and #r.confirms == 1)

    -- leaving a group
    local g = Boot({ settings = { enabled = true, resetOnLeave = true } })
    g.group = true
    g.Login()
    g.Fire("GROUP_ROSTER_UPDATE")
    check("the first sight of a group clears nothing", (g.resets or 0) == 0)
    g.group = false
    g.Fire("GROUP_ROSTER_UPDATE")
    check("leaving it does", g.resets == 1)
    g.Fire("GROUP_ROSTER_UPDATE")
    check("and once", g.resets == 1)
    g.store.Set("resetOnLeave", false)
    g.group = true
    g.Fire("GROUP_ROSTER_UPDATE")
    g.group = false
    g.Fire("GROUP_ROSTER_UPDATE")
    check("off: leaving clears nothing", g.resets == 1)
    g.store.Set("resetOnLeave", true)
    g.group = true
    g.Fire("GROUP_ROSTER_UPDATE")
    g.combat = true
    g.group = false
    g.Fire("GROUP_ROSTER_UPDATE")
    check("nor in combat", g.resets == 1)

    -- the whole of the data out of combat
    local o = Boot({ settings = { enabled = true, window2 = true, session2 = "overall" } })
    o.fights = { { sessionID = 3, durationSeconds = 61 } }
    o.Login()
    o.Window().session.onClick()
    o.menu:Find("Fight 3 (1:01)").set(); o.Flush()
    check("a past fight picked", o.Window().session.label == "Fight")
    o.store.Set("overallOutOfCombat", true); o.Flush()
    check("a window that is off keeps its own", o.store.Get("session3") == "current")
    check("on: it shows Overall at once, out of combat, and the past fight is let go", o.store.Get("session") == "overall"
        and o.Window().session.label == "Overall")
    o.combat = true
    o.Fire("PLAYER_REGEN_DISABLED"); o.Flush()
    check("and the current fight in combat, in every window", o.store.Get("session") == "current"
        and o.store.Get("session2") == "current" and o.Window().session.label == "Current")
    o.combat = false
    o.Fire("PLAYER_REGEN_ENABLED"); o.Flush()
    check("and Overall again after", o.store.Get("session") == "overall" and o.store.Get("session2") == "overall")
    o.store.Set("overallOutOfCombat", false)
    o.combat = true
    o.Fire("PLAYER_REGEN_DISABLED"); o.Flush()
    check("off: nothing changes", o.store.Get("session") == "overall")

    local page = Boot()
    check("the card: when to reset and the rest", CardOf(page.page, "data") ~= nil
        and RowOf(page.page, "resetOn").choice[2][1] == "never" and RowOf(page.page, "resetOnLeave").toggle == true
        and RowOf(page.page, "overallOutOfCombat").toggle == true and RowOf(page.page, "hideInPvP").toggle == true
        and RowOf(page.page, "visibility").choice[2][4] == "raid")
    check("its summary", CardOf(page.page, "data").summary(page.store) == "0 of 30 fights kept")
    page.store.Set("resetOn", "ask")
    check("and with a rule set", CardOf(page.page, "data").summary(page.store)
        == "0 of 30 fights kept, reset ask when entering an instance")
end

-- the summary line's pieces and size, and the short names of the lists
do
    local s = Boot({ settings = { enabled = true, showSummary = true } })
    s.duration = 100
    s.session.totalAmount = 500
    s.Login()
    local w = s.Window()
    check("the whole line by default: the session, the total, the raid's per second, the rank",
        w.summary.text == "Current   Damage <500>   Raid DPS <5>   Rank 2/3" and w.summary.fontSize == 11)
    s.store.Set("summaryName", false); s.Flush()
    check("without the session's name", w.summary.text == "Damage <500>   Raid DPS <5>   Rank 2/3")
    s.store.Set("summaryTotal", false); s.Flush()
    check("without the total", w.summary.text == "Raid DPS <5>   Rank 2/3")
    s.store.Set("summaryRate", false); s.Flush()
    check("without the raid's figure", w.summary.text == "Rank 2/3")
    s.store.Set("summaryRank", false); s.Flush()
    check("with none: nothing written", w.summary.text == "")
    for _, key in ipairs({ "summaryName", "summaryTotal", "summaryRate", "summaryRank" }) do s.store.Set(key, true) end
    s.store.Set("summaryRate", false); s.store.Set("summaryRank", false); s.Flush()
    check("a name and a total", w.summary.text == "Current   Damage <500>")
    s.store.Set("summaryRate", true); s.store.Set("summaryRank", true)
    s.store.Set("summaryOwnSize", true); s.store.Set("summarySize", 15); s.Flush()
    check("Summary Size", w.summary.fontSize == 15)
    s.store.Set("summarySize", 11)

    local line, card = RowOf(s.page, "showSummary")
    check("Summary Line is a toggle with a cog on the Title Bar card, holding its pieces", line.toggle == true
        and line.cog ~= nil and card.id == "header" and RowOf(s.page, "summaryName").under == "Summary Line"
        and RowOf(s.page, "summaryRank").under == "Summary Line" and RowOf(s.page, "summaryRank").needs() == true)
    s.store.Set("showSummary", false)
    check("the pieces wait for the line, and say so", RowOf(s.page, "summaryRank").needs() == false
        and RowOf(s.page, "summaryRank").why == "Turn on Summary Line")
    s.store.Set("showSummary", true); s.store.Set("summaryRate", false)

    -- short names
    check("the full name by default", w.title.text == "Damage Done")
    s.store.Set("shortNames", true); s.Flush()
    check("Short List Names: in the title", w.title.text == "Damage")
    s.store.Set("lower", "healing"); s.Flush()
    check("and the second list's", w.lowerTitle.text == "Healing")
    s.store.Set("lower", ""); s.store.Set("titleText", "both")
    s.fights = { { sessionID = 3, name = "Fyrakk", durationSeconds = 61 } }
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("with a fight's name", w.title.text == "Damage - Fyrakk")
    s.store.Set("titleText", "list")
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("in a breakdown", w.title.text == "You - Damage")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    s.Hover(w, 2)
    check("in the spell panel", s.Panel().subtitle.text == "Damage (1:40)")
    w.rows[2].scripts.OnLeave(w.rows[2])
    w.more.onClick()
    check("the menus keep the full names", s.menu:Find("List"):Find("Damage Done") ~= nil)
    s.store.Set("mode", "dps"); s.Flush()
    check("DPS is DPS", w.title.text == "DPS")
    local C = s.DM.C
    local all = true
    for _, key in ipairs(C.MODE_ORDER) do all = all and C.MODE_BY_KEY[key].short ~= nil end
    check("every list has a short name", all)
    local short = RowOf(s.page, "shortNames")
    check("a toggle on the Lists card", short and short.toggle == true)
end

-- a click on a name opens its spells in the window, with the enemies it hurt, and a click closes them
do
    local function Enemy(name, guid) return { name = name, sourceGUID = guid, sourceCreatureID = 100 } end
    local function Hit(who, total) return { totalAmount = total, combatSpellDetails = { unitName = who } } end
    local s = Boot({ settings = { enabled = true } })
    s.duration = 120
    s.byType = { [10] = { combatSources = { Enemy("Defias Cutpurse", "E-1"), Enemy("Defias Thug", "E-2") } } }
    s.enemyData = {
        ["E-1"] = { combatSpells = { Hit("You", 100), Hit("You", 20), Hit("Aldrin", 500) } },
        ["E-2"] = { combatSpells = { Hit("You", 60) } },
    }
    s.Login()
    local w = s.Window()
    w.centerX = 100
    s.session.combatSources[2].name = "You"
    local spells = s.spells
    local row = w.rows[2]
    check("the list first: names, and no spells", w.rows[1].name.text == "Aldrin" and w.rows[2].name.text == "You")
    row.scripts.OnMouseUp(row, "RightButton")
    check("a right click on a row does nothing", w.rows[1].name.text == "Aldrin")
    row.scripts.OnMouseUp(row, "LeftButton")
    check("a left click opens its spells in the window: the title names the player and the list",
        w.title.text == "You - Damage Done")
    check("the rows are the spells, by their names, in the game's order", w.rows[1].name.text == "Fireball"
        and w.rows[2].name.text == "Pyroblast" and w.rows[3].name.text == "Unknown" and w.rows[1].shown == true)
    check("each a bar against the largest, in the player's own color", w.rows[2].barMax == 600
        and w.rows[2].barValue == 300 and w.rows[1].color[1] == CLASS.ROGUE.r)
    check("with the spell's icon", w.rows[1].icon.texture == 1101 and w.rows[1].icon.shown == true)
    check("the amount and the per-second figure in the two columns", w.rows[1].colA.text == "<600>"
        and w.rows[1].colB.text == "<5>" and w.rows[2].colB.text == "<2.5>")
    check("no rank numbers on spells", w.rows[1].rank.shown == false)
    check("then a Targets line, and the enemies the player hurt, biggest first", w.rows[4].name.text == "Targets"
        and w.rows[5].name.text == "Defias Cutpurse" and w.rows[6].name.text == "Defias Thug"
        and (w.rows[7] == nil or w.rows[7].shown == false))
    check("the line has no bar, figures or icon", w.rows[4].barValue == 0 and w.rows[4].colA.text == ""
        and w.rows[4].colB.text == "" and w.rows[4].icon.shown == false)
    check("the enemies: what each took and per second, in the enemy's red, against the largest",
        w.rows[5].colA.text == "<120>" and w.rows[5].colB.text == "<1>" and w.rows[6].colA.text == "<60>"
        and w.rows[5].color[1] == 0.78 and w.rows[5].barMax == 120 and w.rows[6].barValue == 60
        and w.rows[5].icon.shown == false)
    local tint = w.rows[4].name.textColor
    check("and the heading in the muted color", tint.r == THEME.muted.r and tint.g == THEME.muted.g
        and tint.b == THEME.muted.b)
    check("the second list is not drawn while it is open", w.lowerBar.shown == false)
    check("the heading has no edge", w.rows[4].edge.solid[4] == 0)
    s.store.Set("columns", "name,total,rate,percent"); s.Flush()
    check("with the share on: each spell's, and none for the enemies", w.rows[1].colP.text == "60.0%"
        and w.rows[2].colP.text == "30.0%" and w.rows[5].colP.text == "" and w.rows[4].colP.text == "")
    s.store.Set("columns", "auto"); s.Flush()
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    w.rows[4].colA.text, w.rows[4].colB.text, w.rows[4].colP.text = "stale", "stale", "stale"
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("a row that had figures is cleared when it becomes a heading", w.rows[4].name.text == "Targets"
        and w.rows[4].colA.text == "" and w.rows[4].colB.text == "" and w.rows[4].colP.text == "")

    w.rows[1].scripts.OnEnter(w.rows[1])
    check("a spell: the game's tooltip for it, at the side away from the window", s.tip.shown == true
        and s.tip.spell == 101 and s.tip.owner == w.rows[1] and s.tip.anchor == "ANCHOR_RIGHT"
        and (s.Panel() == nil or s.Panel().shown == false))
    w.rows[1].scripts.OnLeave(w.rows[1])
    check("taken down when the mouse leaves", s.tip.shown == false)
    w.rows[4].scripts.OnEnter(w.rows[4])
    w.rows[5].scripts.OnEnter(w.rows[5])
    check("the heading and an enemy have no tooltip", s.tip.shown == false)
    w.rows[5].scripts.OnLeave(w.rows[5])
    w.centerX = 900
    w.rows[1].scripts.OnEnter(w.rows[1])
    check("on the other side for a window on the right", s.tip.anchor == "ANCHOR_LEFT")
    w.rows[1].scripts.OnLeave(w.rows[1])
    spells.combatSpells[1].spellID = SECRET_NUMBER
    s.names[SECRET_NUMBER] = "Hidden"
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    w.rows[1].scripts.OnEnter(w.rows[1])
    check("a spell id the game keeps back is not asked for", s.tip.shown == false)
    w.rows[1].scripts.OnLeave(w.rows[1])
    s.names[SECRET_NUMBER] = nil
    spells.combatSpells[1].spellID = 101
    s.names[101] = nil
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    w.rows[1].scripts.OnEnter(w.rows[1])
    check("nor one the game has no spell for", s.tip.shown == false)
    w.rows[1].scripts.OnLeave(w.rows[1])
    s.names[101] = "Fireball"
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    w.rows[1].scripts.OnEnter(w.rows[1])
    check("shown again, on the row", s.tip.shown == true and s.tip.owner == w.rows[1])
    s.tip.owner = Region("Frame")
    w.rows[1].scripts.OnLeave(w.rows[1])
    check("a tooltip that has become another thing's is left alone", s.tip.shown == true)
    s.tip = nil

    -- it follows the player, and updates
    local sources = s.session.combatSources
    sources[1], sources[2] = sources[2], sources[1]
    spells.combatSpells = { Spell(101, 50) }
    spells.maxAmount, spells.totalAmount = 50, 100
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("an update redraws it, still the same player", w.title.text == "You - Damage Done"
        and w.rows[1].colA.text == "<50>" and w.rows[2].name.text == "Targets")
    sources[1] = Source("You", "MAGE", "y", "y", true, "Player-1")
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("it is the live row it follows: the bars have its class", w.rows[1].color[1] == CLASS.MAGE.r)
    spells.combatSpells = { Spell(101, SECRET_NUMBER) }
    spells.maxAmount, spells.totalAmount = SECRET_NUMBER, SECRET_NUMBER
    s.store.Set("columns", "name,total,rate,percent")
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("an amount the game keeps back: no per-second figure and no share, and nothing made of it",
        w.rows[1].colA.text == "<" .. SECRET_NUMBER .. ">" and w.rows[1].colB.text == "" and w.rows[1].colP.text == "")
    s.store.Set("columns", "auto")
    spells.combatSpells = { Spell(101, 50) }
    spells.maxAmount, spells.totalAmount = 50, 100
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    check("a click on any row of it closes it: the list again, the player where they stand",
        w.title.text == "Damage Done" and w.rows[1].name.text == "You" and w.rows[2].name.text == "Aldrin")
    check("and the second list is back with the setting", w.lowerBar.shown == false)
    sources[1], sources[2] = sources[2], sources[1]
    sources[1] = Source("Aldrin", "MAGE", "a", "a", false, "Player-2")
    sources[2] = Source("You", "ROGUE", "y", "y", true, "Player-1")
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    sources[1] = Source("Aldrin", "ROGUE", "a", "a", false, "Player-2")
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("another player is followed by their guid", w.title.text == "Aldrin - Damage Done"
        and w.rows[1].color[1] == CLASS.ROGUE.r)
    local secret = Source(SECRET_TEXT, "MAGE", "a", "a", false, "Player-2")
    sources[1] = secret
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a name the game keeps back: the title is the list's", w.title.text == "Damage Done")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    sources[1] = Source("Aldrin", "MAGE", "a", "a", false, "Player-2")
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()

    -- the opened list, a click, and the data going
    s.store.Set("lower", "healing"); s.Flush()
    check("the second list shows", w.lowerBar.shown == true)
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("opening one hides it", w.lowerBar.shown == false and w.title.text == "You - Damage Done")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    check("closing brings it back", w.lowerBar.shown == true and w.title.text == "Damage Done")
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    s.ns.PreviewDamageMeter()
    check("the preview shows the sample, not the breakdown", w.title.text == "Damage Done"
        and w.rows[1].name.text == "Aldrin")
    s.Flush()
    check("and the breakdown is there when it is over", w.title.text == "You - Damage Done")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    local healing = { combatSources = { Source("Mira", "PRIEST", "H1", "h1", false, "Player-3") },
        maxAmount = Amount("hmax"), totalAmount = Amount("htotal") }
    s.byType[2] = healing
    s.store.Set("showSummary", true); s.Flush()
    w.rows2[1].scripts.OnMouseUp(w.rows2[1], "LeftButton")
    check("a row of the second list opens its own list's spells: its name and list, asked for as that list",
        w.title.text == "Mira - Healing Done" and s.spellCalls[#s.spellCalls].type == 2
        and w.summary.text:find("htotal", 1, true) ~= nil)
    healing.combatSources[1] = Source("Mira", "MAGE", "H1", "h1", false, "Player-3")
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("and it follows the live row of that list", w.rows[1].color[1] == CLASS.MAGE.r)
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    s.store.Set("showSummary", false)
    s.store.Set("lower", ""); s.Flush()

    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("a reset closes it", w.title.text == "Damage Done")
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    s.store.Set("breakdown", false); s.Flush()
    check("Spell Breakdown off: the list", w.title.text == "Damage Done")
    s.store.Set("breakdown", true); s.Flush()
    check("and the click opens it again", w.rows[1].name.text ~= "Aldrin")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    s.store.Set("breakdown", false)
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("with Spell Breakdown off a click opens nothing", w.title.text == "Damage Done")
    s.store.Set("breakdown", true)

    -- in combat the enemies are not asked for, and a row whose guid is kept back has no spells to open
    s.combat = true
    local asked = #s.enemyCalls
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("in combat: the spells, and the enemies are not asked for", w.rows[1].name.text == "Fireball"
        and w.rows[4].shown == false and #s.enemyCalls == asked)
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    s.session.combatSources[1].sourceGUID = SECRET_TEXT
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    check("a row whose guid the game keeps back: no spells, and it says why", w.rows[1].shown == false
        and w.panes[1].empty.shown == true and w.panes[1].empty.text == "Spells show after combat."
        and w.title.text == "Aldrin - Damage Done")
    check("the window takes the mouse while it is open, so that a click anywhere closes it", w.mouse == true)
    w.scripts.OnMouseUp(w, "LeftButton")
    check("and it does", w.title.text == "Damage Done" and w.rows[1].shown == true and w.mouse == false)
    s.combat = false

    -- not for lists without spells, or the sample
    s.store.Set("mode", "deaths"); s.Flush()
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    check("Deaths has no spells to open", w.title.text == "Deaths")
    s.store.Set("mode", "damage"); s.Flush()
    s.ns.PreviewDamageMeter()
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("the sample has none either", w.title.text == "Damage Done")
end

-- a breakdown closed puts the list back at the top
do
    local s = Boot({ settings = { enabled = true, height = 70 } })
    s.Login()
    local w = s.Window()
    w.rows[1].scripts.OnMouseWheel(w.rows[1], -1)
    check("scrolled: the second player on top", w.rows[1].name.text == "You")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    w.rows[1].scripts.OnMouseWheel(w.rows[1], -1)
    check("the spells scroll on their own", w.rows[1].name.text == "Pyroblast")
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    check("closed: the list from its top", w.rows[1].name.text == "Aldrin")
end

-- the share of the total is a column of its own
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    s.session.totalAmount = 400
    s.session.combatSources[1].totalAmount = 100
    check("off by default", s.store.Get("columns") == "auto" and w.rows[1].colP.shown == false
        and w.panes[1].headP.shown == false)
    check("the name's room as it was", w.rows[1].name.points[2][2] == -(6 + 2 * 47 + 6 + 6))
    s.store.Set("columns", "name,total,rate,percent"); s.Flush()
    check("on: each one's share of what the list totals, at the right end", w.rows[1].colP.shown == true
        and w.rows[1].colP.text == "25.0%" and w.rows[1].colP.points[1][1] == "RIGHT"
        and w.rows[1].colP.points[1][2] == -6 and w.rows[1].colP.w == 42)
    check("with a title over it", w.panes[1].headP.shown == true and w.panes[1].headP.text == "%")
    check("a figure that is not plain has no share", w.rows[2].colP.text == "")
    check("the other columns move left of it, and the name makes room", w.rows[1].colB.points[1][2] == w.rows[1].colP
        and w.rows[1].colB.points[1][4] == -6 and w.rows[1].name.points[2][2] == -(6 + 2 * 47 + 6 + 6 + 42 + 6))
    check("the titles too: each at the right end of its column", w.panes[1].headP.points[1][4] == -12
        and w.panes[1].headB.points[1][4] == -(12 + 42 + 6) and w.panes[1].headA.points[1][4] == -(12 + 42 + 6 + 47 + 6))
    s.store.Set("columns", "name,percent"); s.Flush()
    check("alone: the name's room is the share's", w.rows[1].colP.shown == true and w.rows[1].colA.shown == false
        and w.rows[1].colB.shown == false and w.rows[1].name.points[2][2] == -(6 + 42 + 6))
    s.store.Set("columns", "name,total,rate,percent")
    s.store.Set("mode", "deaths"); s.Flush()
    check("Deaths has no share", w.rows[1].colP.shown == false and w.panes[1].headP.shown == false)
    s.store.Set("mode", "damage"); s.Flush()
    s.session.combatSources[1].totalAmount = 100
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    check("an open breakdown has the share of each spell, and none for an enemy",
        w.rows[1].colP.text == "60.0%" and w.rows[2].colP.text == "30.0%")
end

-- the columns of figures are as wide as their texts when all of them are known, so the name has the rest
do
    local s = Boot({ settings = { enabled = true } })
    for i, source in ipairs(s.session.combatSources) do
        source.totalAmount = 1000 * i
        source.amountPerSecond = 10 * i
    end
    s.Login()
    local w = s.Window()
    local pane, row = w.panes[1], w.rows[1]
    check("known figures: each column as wide as its text, and two more", row.colA.w == 42 and row.colB.w == 42)
    check("the name's room is what they leave", row.name.points[2][2] == -(6 + 42 + 6 + 42 + 6))
    check("and the titles are at the ends of the columns", pane.headB.points[1][4] == -12
        and pane.headA.points[1][4] == -(12 + 42 + 6))
    pane.ruler.GetStringWidth = function(self) return #self.text * 7 end
    pane.headRuler.stringWidth = 10
    s.store.Set("fontSize", 12); s.Flush()
    local widthA, widthB = 0, 0
    for i = 1, 2 do
        widthA = math.max(widthA, #w.rows[i].colA.text * 7)
        widthB = math.max(widthB, #w.rows[i].colB.text * 7)
    end
    check("measured in the figures' font", pane.ruler.font == row.colA.font and pane.ruler.fontSize == 12
        and pane.ruler.outline == row.colA.outline)
    check("the widest text of a column is its width, for every row", widthA ~= widthB and row.colA.w == widthA + 2
        and w.rows[2].colA.w == widthA + 2 and row.colB.w == widthB + 2 and w.rows[2].colB.w == widthB + 2)
    s.session.combatSources[2].totalAmount = SECRET_NUMBER
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    local reserve = math.floor(7 * 0.62 * 12)
    check("a figure that is kept back: the columns are as wide as the longest figure could be", row.colA.w == reserve
        and row.colB.w == reserve and row.name.points[2][2] == -(6 + reserve + 6 + reserve + 6))
    s.session.combatSources[2].totalAmount = 2000
    s.session.combatSources[2].amountPerSecond = SECRET_NUMBER
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("the same when only the per-second figure is", row.colA.w == reserve and row.colB.w == reserve)
    s.session.combatSources[2].amountPerSecond = 20
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("and they are fitted again when it is known", row.colA.w == widthA + 2 and row.colB.w == widthB + 2)
    s.store.Set("columns", "name,total,rate,percent")
    s.session.totalAmount = SECRET_NUMBER
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a share that is not known yet keeps its room", row.colP.text == "" and row.colP.w == math.floor(6 * 0.62 * 12))
    s.session.totalAmount = 30000
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    local widthP = 0
    for _, shown in ipairs(w.rows) do
        if shown.shown then widthP = math.max(widthP, #shown.colP.text * 7) end
    end
    check("and is fitted once it is", row.colP.text ~= "" and widthP > 0 and widthP + 2 < math.floor(6 * 0.62 * 12)
        and row.colP.w == widthP + 2)
    s.store.Set("columns", "auto")
    s.store.Set("showDivider", true); s.Flush()
    check("one text with a bar between: the whole text is the width", row.colB.w == #row.colB.text * 7 + 2
        and row.colB.shown == true and row.colA.shown == false)
    s.store.Set("showDivider", false); s.Flush()
    -- a title wider than its figures
    pane.headRuler.stringWidth = 70
    s.store.Set("fontSize", 11); s.Flush()
    check("a column is never narrower than its title", row.colA.w == 70 and row.colB.w == 70
        and pane.headB.points[1][4] == -12 and pane.headA.points[1][4] == -(12 + 70 + 6))
    check("and the name makes room for it", row.name.points[2][2] == -(6 + 70 + 6 + 70 + 6))
    s.store.Set("showColumnHeaders", false); s.Flush()
    check("with no titles shown, the columns are their figures' width", row.colA.w == widthA + 2
        and row.colB.w == widthB + 2)
    s.store.Set("showColumnHeaders", true); s.Flush()
    s.store.Set("columns", "total,rate,name"); s.Flush()
    check("a title at the left end stays in the window: its left end is at the row's", pane.headA.points[1][4] - 70 == 12
        and pane.headB.points[1][4] - 70 == 12 + 70 + 6)
    s.store.Set("columns", "auto"); s.Flush()
    pane.headRuler.stringWidth = 10
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a short title leaves the column its figures' width", row.colA.w == widthA + 2 and row.colB.w == widthB + 2)
end

-- the title has the room to the bar's end when there are no buttons, and leaves them theirs when there are
do
    local s = Boot({ settings = { enabled = true, width = 200 } })
    s.Login()
    local w = s.Window()
    w.title.stringWidth = 190
    s.store.Set("width", 201); s.store.Set("width", 200); s.Flush()
    check("with the buttons: cut to the room before them", w.title.w == 200 - 8 - 98)
    s.store.Set("showButtons", false); s.Flush()
    check("without them: the room to the bar's end, less its margin", w.title.w == 200 - 8 - 8)
    s.store.Set("width", 170); s.Flush()
    check("less of it in a narrow window, with the margin kept", w.title.w == 170 - 8 - 8)
    s.store.Set("titleX", 20); s.Flush()
    check("a title moved right has that much less", w.title.w == 170 - 28 - 8)
    s.store.Set("titleX", -20); s.store.Set("width", 200); s.Flush()
    check("and that much more when moved left, to the text's own width", w.title.w == 190)
    s.store.Set("titleX", 300); s.store.Set("width", 170); s.Flush()
    check("moved past the bar's end it has no room, not a negative one", w.title.w == 0)
end

-- the title bar: the buttons, and the menu on a right click
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("the buttons are there by default", w.session.shown == true and w.more.shown == true
        and w.time.points[1][2] == w.session)
    s.menu = nil
    w.header.scripts.OnMouseUp(w.header, "LeftButton")
    check("a left click on the bar opens nothing", s.menu == nil)
    w.header.scripts.OnMouseUp(w.header, "RightButton")
    check("a right click opens the window menu on it", s.menu and s.menu.owner == w.header
        and s.menu:Find("List") ~= nil and s.menu:Find("Session") ~= nil and s.menu:Find("Report To") ~= nil)
    s.store.Set("timeX", -10); s.store.Set("titleX", 20); s.Flush()
    local titleX, timeX, timeShown = w.title.points[1][4], w.time.points[1][4], w.time.shown
    s.store.Set("showButtons", false); s.Flush()
    check("Show Buttons off: the session button and ... go", w.session.shown == false and w.more.shown == false)
    check("and nothing else moves: the title and the time, offsets and all, are where they were",
        w.title.points[1][4] == titleX and w.time.points[1][4] == timeX and w.time.shown == timeShown
        and w.time.points[1][2] == w.session and timeX == -14 and titleX == 28)
    s.store.Set("width", 218); s.Flush()
    check("and the room for the time is the same, from where the title starts", w.time.shown == true)
    s.store.Set("width", 217); s.Flush()
    check("to the pixel", w.time.shown == false)
    s.store.Set("width", 300); s.Flush()
    s.menu = nil
    w.header.scripts.OnMouseUp(w.header, "RightButton")
    check("the menu is still on a right click", s.menu and s.menu:Find("Session") ~= nil)
    s.store.Set("timeX", 80); s.Flush()
    check("the time's offset takes it to where the buttons were", w.time.points[1][4] == 76)
    s.store.Set("showButtons", true); s.store.Set("timeX", 0); s.store.Set("titleX", 0); s.Flush()
    check("on again: they are back", w.session.shown == true and w.more.shown == true and w.time.shown == true
        and w.time.points[1][4] == -4 and w.title.points[1][4] == 8)
    local row = RowOf(s.page, "showButtons")
    check("a toggle on the Title Bar card", row and row.toggle == true and row.label == "Show Buttons"
        and CardOf(s.page, "header") ~= nil and s.store.Get("showButtons") == true)
end

-- the title bar can be see-through, the time can be in brackets after the title, and the clean look is
-- all of it at once
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("the title bar is drawn by default", w.headerBackground.alpha == 1 and w.headerRule.alpha == 1
        and w.lowerBackground.alpha == 1)
    s.store.Set("headerAlpha", 0); s.Flush()
    check("Title Bar Opacity at zero: the bar, its line and the second list's strip are not drawn",
        w.headerBackground.alpha == 0 and w.headerRule.alpha == 0 and w.lowerBackground.alpha == 0
        and w.title.shown == true)
    s.store.Set("headerAlpha", 0.5); s.Flush()
    check("and half", w.headerBackground.alpha == 0.5 and w.headerRule.alpha == 0.5
        and w.lowerBackground.alpha == 0.5)
    s.store.Set("headerAlpha", 1)

    s.store.Set("timeBrackets", true); s.Flush()
    check("Time in Brackets: (2:05), with room for the brackets", w.time.text == "(2:05)"
        and w.time.w == math.ceil(9 * 0.62 * 11))
    s.store.Set("width", 205); s.Flush()
    check("which needs more room", w.time.shown == false)
    s.store.Set("width", 300); s.Flush()
    s.store.Set("timeByTitle", true); s.Flush()
    check("Time Next to Title: right after it, reading from the left", w.time.points[1][2] == w.title
        and w.time.points[1][1] == "LEFT" and w.time.points[1][3] == "RIGHT" and w.time.points[1][4] == 4
        and w.time.justify == "LEFT" and w.time.shown == true)
    s.store.Set("titleX", 30); s.store.Set("timeX", 10); s.Flush()
    check("it moves with the title, and by its own offset", w.title.points[1][4] == 38 and w.time.points[1][2] == w.title
        and w.time.points[1][4] == 14)
    s.store.Set("titleX", 0); s.store.Set("timeX", 0)
    s.store.Set("timeByTitle", false); s.store.Set("timeBrackets", false); s.Flush()
    check("off again: by the buttons, from the right", w.time.points[1][2] == w.session and w.time.justify == "RIGHT"
        and w.time.text == "2:05")

    local heads = RowOf(s.page, "showColumnHeaders")
    check("Column Titles is a toggle with a cog, holding the titles' text", heads.toggle == true and heads.cog ~= nil
        and RowOf(s.page, "headOwnSize").under == "Column Titles" and RowOf(s.page, "headSize").under == "Column Titles")
    local brackets, byTitle = RowOf(s.page, "timeBrackets"), RowOf(s.page, "timeByTitle")
    check("and the time's choices are behind the cog of Show Fight Time", brackets.under == "Show Fight Time"
        and byTitle.under == "Show Fight Time" and brackets.needs() == true and byTitle.needs() == true
        and RowOf(s.page, "headerAlpha").needs() == true)
    s.store.Set("showTime", false)
    check("which wait for Show Fight Time, and say so", brackets.needs() == false and byTitle.needs() == false
        and brackets.why == "Turn on Show Fight Time" and byTitle.why == "Turn on Show Fight Time")
    s.store.Set("showTime", true)

    local look
    for _, c in ipairs(s.page.cards) do
        for _, r in ipairs(c.rowsFn and c.rowsFn() or c.rows) do
            if r.label == "Clean Look" then look = r end
        end
    end
    check("a Clean Look button on the Looks card", look and look.buttonText == "Apply")
    look.button()
    check("it asks first, and changes nothing yet", #s.confirms >= 1 and w.session.shown == true
        and s.store.Get("showColumnHeaders") == true)
    s.confirms[#s.confirms].yes(); s.Flush()
    check("then the column titles, buttons, ranks, backgrounds and border go", s.store.Get("showColumnHeaders") == false
        and s.store.Get("showButtons") == false and s.store.Get("showRanks") == false
        and s.store.Get("showBorder") == false and s.store.Get("headerAlpha") == 0
        and s.store.Get("backgroundAlpha") == 0 and w.panes[1].headName.shown == false and w.session.shown == false
        and w.more.shown == false and w.rows[1].rank.shown == false and w.headerBackground.alpha == 0
        and w.background.alpha == 0)
    check("and the time is in brackets after the title", w.time.text == "(2:05)" and w.time.points[1][2] == w.title)
    check("and the figures are one text with a bar between", s.store.Get("showDivider") == true
        and w.rows[1].colB.text == "<A> | <a>" and w.rows[1].colA.shown == false)
    check("the rows start under the title bar, with nothing between", w.rows[1].points[1][5] == -26 - 6)
end

-- the column titles on one line as wide as their words, and the order of the columns, per window
do
    local s = Boot({ settings = { enabled = true, columns = "name,total,rate,percent" } })
    s.session.totalAmount = 400
    s.session.combatSources[1].totalAmount = 100
    s.Login()
    local w = s.Window()
    local pane = w.panes[1]
    local row = w.rows[1]
    check("the titles take no width of their own, nor wrap, so that a long one is neither cut nor lowered",
        pane.headA.w == 0 and pane.headB.w == 0 and pane.headP.w == 0 and pane.headA.wrap == false
        and pane.headB.wrap == false and pane.headP.wrap == false and pane.headName.wrap == false)
    check("nor do the figures wrap", row.colA.wrap == false and row.colB.wrap == false and row.colP.wrap == false)
    check("the titles on one line, at the right end of their columns", pane.headA.points[1][5] == pane.headB.points[1][5]
        and pane.headB.points[1][5] == pane.headP.points[1][5] and pane.headB.points[1][5] == pane.headName.points[1][5]
        and pane.headP.points[1][4] == -12 and pane.headB.points[1][4] == -(12 + 42 + 6)
        and pane.headA.points[1][4] == -(12 + 42 + 6 + 47 + 6))

    check("the name, the total, the per-second figure, the share", row.colA.text == "<100>" and row.colB.text == "<a>"
        and row.colB.points[1][2] == row.colP and row.colA.points[1][2] == row.colB)

    -- the share first
    s.store.Set("columns", "name,percent,total,rate"); s.Flush()
    check("the share first: the figures at the right end, the share left of them", row.colB.points[1][2] == -6
        and row.colA.points[1][2] == row.colB and row.colP.points[1][2] == row.colA
        and row.name.points[2][2] == -(6 + 47 + 6 + 47 + 6 + 42 + 6))
    check("and its title", pane.headB.points[1][4] == -12 and pane.headA.points[1][4] == -(12 + 47 + 6)
        and pane.headP.points[1][4] == -(12 + 47 + 6 + 47 + 6))
    -- the share between
    s.store.Set("columns", "name,total,percent,rate"); s.Flush()
    check("the share between: the second figure at the end, the share, the first", row.colB.points[1][2] == -6
        and row.colP.points[1][2] == row.colB and row.colA.points[1][2] == row.colP)
    check("and its titles", pane.headB.points[1][4] == -12 and pane.headP.points[1][4] == -(12 + 47 + 6)
        and pane.headA.points[1][4] == -(12 + 47 + 6 + 42 + 6))
    -- the figures the other way round
    s.store.Set("columns", "name,rate,total,percent"); s.Flush()
    check("the per-second figure first", row.colA.text == "<a>" and row.colB.text == "<100>"
        and pane.headA.text == "DPS" and pane.headB.text == "Damage")
    s.store.Set("columns", "name,total,rate,percent"); s.Flush()
    check("and the total first", row.colA.text == "<100>" and row.colB.text == "<a>")
    -- the lists that lead with the per-second figure, unless the columns say
    s.store.Set("columns", "auto"); s.store.Set("mode", "dps"); s.Flush()
    check("the DPS list leads with its own, as the game's meter does", row.colA.text == "<a>" and row.colB.text == "<100>")
    s.store.Set("columns", "name,total,rate"); s.Flush()
    check("unless the columns say the total", row.colA.text == "<100>" and row.colB.text == "<a>")
    s.store.Set("columns", "auto"); s.store.Set("mode", "damage")

    -- with one figure, and with the divider
    s.store.Set("columns", "name,percent,total"); s.Flush()
    check("one figure and the share first: the share, then the figure at the end", row.colB.points[1][2] == -6
        and row.colP.points[1][2] == row.colB and row.colA.shown == false)
    s.store.Set("columns", "name,total,percent"); s.Flush()
    check("the share after one figure", row.colB.points[1][2] == row.colP and row.colP.points[1][2] == -6)
    s.store.Set("columns", "name,percent,total,rate"); s.store.Set("showDivider", true)
    s.Flush()
    check("the divider with the share first: the two figures as one, the share left of it", row.colB.text == "<100> | <a>"
        and row.colB.points[1][2] == -6 and row.colP.points[1][2] == row.colB and row.colA.shown == false)
    s.store.Set("showDivider", false); s.store.Set("columns", "auto")

    -- the name stands where the columns put it
    s.store.Set("columns", "total,rate,name"); s.Flush()
    check("the name last: the figures from the left end, each to the right of the one before", row.colA.shown == true
        and row.colA.points[1][1] == "LEFT" and row.colA.points[1][2] == 6 and row.colB.points[1][1] == "LEFT"
        and row.colB.points[1][2] == row.colA and row.colB.points[1][3] == "RIGHT" and row.colB.points[1][4] == 6)
    check("and the rank, icon and name after them, to the end of the row", row.rank.points[1][2] == 6 + 47 + 6 + 47 + 6
        and row.name.points[1][2] == 6 + 47 + 6 + 47 + 6 + 18 + 16 + 5 and row.name.points[2][2] == -12)
    check("their titles over them, at their right ends", pane.headA.points[1][1] == "TOPRIGHT"
        and pane.headA.points[1][2] == w and pane.headA.points[1][3] == "TOPLEFT"
        and pane.headA.points[1][4] == 6 + 6 + 47 and pane.headB.points[1][4] == 6 + 6 + 47 + 6 + 47
        and pane.headName.points[1][4] == 6 + 6 + 47 + 6 + 47 + 6 + 18)
    s.store.Set("columns", "total,name,rate"); s.Flush()
    check("the name between them", row.colA.points[1][2] == 6 and row.colB.points[1][1] == "RIGHT"
        and row.colB.points[1][2] == -6 and row.name.points[1][2] == 6 + 47 + 6 + 18 + 16 + 5
        and row.name.points[2][2] == -(6 + 47 + 6))
    local first = RowOf(s.page, "columns")
    check("the page's first column row shows what the first slot has", first.label == "Column 1"
        and first.get() == "total" and first.choice[2][1] == "name")
    s.store.Set("columns", "auto"); s.Flush()
    check("auto: the name, then the figures at the right end", row.colA.points[1][1] == "RIGHT"
        and row.name.points[1][2] == 6 + 18 + 16 + 5)

    -- the totals of other lists, for the same player
    s.byType = { [5] = { combatSources = { { name = "Aldrin", sourceGUID = "Player-2", totalAmount = 7 },
        { name = "You", sourceGUID = "Player-1", isLocalPlayer = true, totalAmount = 3 } } },
        [9] = { combatSources = { { name = "Cara", sourceGUID = "Player-3", totalAmount = 2 } } } }
    s.store.Set("columns", "name,total,rate,interrupts,deaths"); s.Flush()
    local you = w.rows[2]
    check("another list's total as a column: found by guid, and yours as yours", row.colX1.text == "<7>"
        and you.colX1.text == "<3>" and row.colX2.text == "" and w.rows[3].colX2.text == "<2>")
    check("a total that is known is as wide as its text, when the figures are not", row.colX1.w == 42
        and row.colA.w == 47 and row.colB.w == 47)
    check("titled with the list's name, at the right end", pane.headX1.text == "Interrupts"
        and pane.headX2.text == "Deaths" and pane.headX1.shown == true and pane.headX2.points[1][4] == -12)
    check("in the order given, to the left of the name's right side", row.colX2.points[1][2] == -6
        and row.colX1.points[1][2] == row.colX2 and row.colB.points[1][2] == row.colX1
        and row.colA.points[1][2] == row.colB)
    s.store.Set("columns", "interrupts,name,total"); s.Flush()
    check("before the name too", row.colX1.points[1][1] == "LEFT" and row.colX1.points[1][2] == 6
        and row.colX1.text == "<7>" and row.colB.points[1][1] == "RIGHT")
    s.byType[5].combatSources[1].sourceGUID = SECRET_TEXT
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a guid the game keeps back finds nothing: the cell is empty, and yours still is found",
        row.colX1.text == "" and you.colX1.text == "<3>")
    s.session.combatSources[2].sourceGUID = SECRET_TEXT
    s.byType[5].combatSources[2].sourceGUID = SECRET_TEXT
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("yours is found as yours, whatever its guid says", you.colX1.text == "<3>")
    s.byType[5].combatSources = { s.byType[5].combatSources[1] }
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a list that no longer has you leaves your cell empty", you.colX1.text == "")
    s.store.Set("columns", "auto"); s.byType = nil
    local asked = #s.calls
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    local again = false
    for i = asked + 1, #s.calls do
        if s.calls[i][2] == 5 or s.calls[i][2] == 9 then again = true end
    end
    check("a list no column takes from is not asked for any more", not again)
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    s.store.Set("columns", "name,total,rate,interrupts"); s.Flush()
    check("in a player's breakdown the other lists' columns are not drawn", w.rows[1].colX1.shown == false
        and w.panes[1].headX1.shown == false)
    w.rows[1].scripts.OnMouseUp(w.rows[1], "LeftButton")
    s.store.Set("columns", "auto"); s.Flush()

    -- what the slots make of a setting
    local DM = s.DM
    local function Slots(value, mode) return table.concat(DM.ColumnSlots(value, mode), ",") end
    check("auto is the name, the total and the rate, and the rate first where the list leads with it",
        Slots("auto") == "name,total,rate,none,none,none"
        and Slots("auto", DM.Mode("dps")) == "name,rate,total,none,none,none")
    check("the name is put in when it is missing, a kind is only once, and a word that is no kind is left out",
        Slots("total,rate") == "name,total,rate,none,none,none"
        and Slots("name,total,total,bogus,rate") == "name,total,rate,none,none,none"
        and Slots("total,name,none,rate,percent,interrupts,deaths") == "total,name,none,rate,percent,interrupts"
        and Slots("total,rate,percent,interrupts,deaths,dispels") == "name,total,rate,percent,interrupts,deaths")
    s.store.Set("columns", "name,total,rate")
    DM.SetColumnSlot(1, 3, "percent")
    check("a kind in a slot", s.store.Get("columns") == "name,total,percent,none,none,none")
    DM.SetColumnSlot(1, 1, "total")
    check("a kind that is in another slot trades places", s.store.Get("columns") == "total,name,percent,none,none,none")
    DM.SetColumnSlot(1, 2, "none")
    check("the name cannot be taken out", s.store.Get("columns") == "total,name,percent,none,none,none")
    DM.SetColumnSlot(1, 2, "deaths")
    check("another kind in the name's slot moves the name to a free one", s.store.Get("columns")
        == "total,deaths,percent,name,none,none")
    DM.SetColumnSlot(1, 3, "none")
    check("a slot can be made free", s.store.Get("columns") == "total,deaths,none,name,none,none")
    check("what the columns have", DM.HasColumn(1, "deaths") == true and DM.HasColumn(1, "rate") == false)
    s.store.Set("columns", "auto")

    -- a window's own
    local t = Boot({ settings = { enabled = true, window2 = true } })
    t.session.combatSources[1].totalAmount = 100
    t.Login()
    local one, two = t.Window(), t.Window(2)
    t.store.Set("ownLook2", true); t.Flush()
    t.store.Set("columns2", "name,rate,total,percent")
    t.store.Set("showColumnHeaders2", false); t.Flush()
    check("the second window has its columns its own way", two.rows[1].colA.text == "<a>" and two.rows[1].colB.text == "<100>"
        and two.rows[1].colP.shown == true and two.panes[1].headName.shown == false)
    check("and the first as it was", one.rows[1].colA.text == "<100>" and one.rows[1].colB.text == "<a>"
        and one.rows[1].colP.shown == false and one.rows[1].name.shown == true and one.panes[1].headName.shown == true)
    t.store.Set("columns2", "name,rate"); t.Flush()
    check("one figure there", two.rows[1].colA.shown == false and two.rows[1].colB.text == "<a>"
        and one.rows[1].colA.shown == true)
    t.store.Set("columns2", "name,total"); t.Flush()
    check("the per-second figure off there only", two.rows[1].colB.text == "<100>" and two.rows[1].colA.shown == false
        and one.rows[1].colA.shown == true and one.rows[1].colB.text == "<a>")
    t.store.Set("columns2", "total,rate,name"); t.store.Set("showDivider2", true); t.Flush()
    check("a divider there only, and the name last there only", two.rows[1].colB.text:find(" | ", 1, true) ~= nil
        and one.rows[1].colB.text == "<a>" and two.rows[1].colB.points[1][1] == "LEFT"
        and one.rows[1].colB.points[1][1] == "RIGHT")
end

-- a bar between the figures: one text for the total and the per-second figure
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("off by default: two columns", w.rows[1].colA.text == "<A>" and w.rows[1].colB.text == "<a>"
        and w.rows[1].colA.shown == true and s.store.Get("showDivider") == false)
    s.store.Set("showDivider", true); s.Flush()
    check("on: one text, the total and the per-second figure, as the picture has it", w.rows[1].colB.text == "<A> | <a>"
        and w.rows[1].colA.shown == false and w.rows[1].colB.shown == true)
    check("wide enough for both and the bar, and the name leaves room for it", w.rows[1].colB.w == 2 * 47 + 20
        and w.rows[1].name.points[2][2] == -(6 + 2 * 47 + 20 + 6))
    check("one title over it, at the right end", w.panes[1].headB.text == "Damage | DPS"
        and w.panes[1].headA.shown == false and w.panes[1].headB.points[1][4] == -12)
    s.store.Set("columns", "name,total,rate,percent"); s.Flush()
    check("with the share, left of it", w.rows[1].colB.points[1][2] == w.rows[1].colP)
    s.store.Set("columns", "auto")
    s.store.Set("mode", "dps"); s.Flush()
    check("the DPS list leads with its per-second figure", w.rows[1].colB.text == "<a> | <A>"
        and w.panes[1].headB.text == "DPS | Damage")
    s.store.Set("mode", "damage")
    s.store.Set("columns", "name,total"); s.Flush()
    check("one figure only: nothing to divide, and the column its own width again", w.rows[1].colB.text == "<A>"
        and w.panes[1].headB.text == "Damage" and w.rows[1].colB.w == 47 and w.panes[1].headB.points[1][4] == -12
        and w.rows[1].name.points[2][2] == -(6 + 47 + 6))
    local row = RowOf(s.page, "showDivider")
    check("the setting waits for both figures, and says so", row.needs() == false
        and row.why == "Put Total and Per Second in two columns")
    s.store.Set("columns", "auto"); s.Flush()
    check("and is on with them", row.needs() == true)
    s.store.Set("mode", "interrupts"); s.Flush()
    check("a list with no per-second figure has nothing to divide either", w.rows[1].colB.text == "<A>")
    s.store.Set("mode", "damage"); s.Flush()
    w.rows[2].scripts.OnMouseUp(w.rows[2], "LeftButton")
    check("the breakdown's spells too", w.rows[1].colB.text == "<600> | <4.8>")
    s.spells.combatSpells = { Spell(101, SECRET_NUMBER) }
    s.spells.maxAmount, s.spells.totalAmount = SECRET_NUMBER, SECRET_NUMBER
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a spell with no per-second figure yet: the amount alone, no bar", w.rows[1].colB.text == "<424242>")
end

-- the page
do
    local s = Boot()
    local page = s.page
    local C = s.DM.C
    local ids = {}
    for _, card in ipairs(page.cards) do ids[#ids + 1] = card.id end
    check("eleven cards, in their order", table.concat(ids, ",") == "lists,window,bars,row,figures,header,hover,"
        .. "data,looks,window2,window3" and page.window ~= nil)
    local orders = {}
    for i, card in ipairs(page.cards) do orders[i] = card.order end
    local sorted = true
    for i = 2, #orders do
        if orders[i] <= orders[i - 1] then sorted = false end
    end
    check("each one after the last", sorted)
    check("the heading reads the state", page.window.headline() == "Damage Meter is off")
    s.store.Set("enabled", true)
    check("on: it names the list", page.window.headline() == "Damage Done")

    local keys = {}
    for _, card in ipairs(page.cards) do
        check(card.id .. ": a name and a short help", card.name ~= nil and #card.help < 120)
        -- a tooltip is a card of fixed width: a word with no spaces that is wider than it is cut short
        local function Wraps(text)
            for word in (text or ""):gmatch("%S+") do
                if #word > 24 then return false end
            end
            return true
        end
        check(card.id .. ": its help wraps", Wraps(card.help))
        for _, row in ipairs(card.rows) do
            check((row.label or row.key or "?") .. ": its help wraps", Wraps(row.help))
        end
        -- a cog is found by the label of its row: each label is the only one of its name on the card, and a
        -- row behind a cog has the row that owns it
        local labels, cogs = {}, {}
        for _, row in ipairs(card.rows) do
            if row.label then
                check(card.id .. ": " .. row.label .. " is the only row of that name", labels[row.label] == nil)
                labels[row.label] = true
                if row.cog then
                    cogs[row.label] = true
                    check(card.id .. ": " .. row.label .. " has a title and a tip for its cog",
                        type(row.cog.title) == "string" and row.cog.title ~= "" and #row.cog.title < 30
                        and type(row.cog.tip) == "string" and row.cog.tip ~= "" and Wraps(row.cog.tip))
                end
            end
        end
        for _, row in ipairs(card.rows) do
            if row.under then
                check(card.id .. ": " .. tostring(row.label) .. " is behind a cog that is there", cogs[row.under] == true)
            end
        end
        -- what is on the page: the rows that are not behind a cog (a row left off for a choice counts)
        local visible = 0
        for _, row in ipairs(card.rows) do
            if row.under == nil then visible = visible + 1 end
        end
        check(card.id .. ": no more than sixteen entries on the page", visible <= 16)
        for _, row in ipairs(card.rows) do
            if row.key then
                keys[#keys + 1] = row.key
                check("the setting " .. row.key .. " has a default", s.store.Get(row.key) ~= nil)
                if row.choice then
                    local values, order
                    if type(row.choice) == "function" then
                        values, order = row.choice()
                    else
                        values, order = row.choice[1], row.choice[2]
                    end
                    for _, value in ipairs(order) do
                        check(row.key .. " choice " .. value .. " has a label", values[value] ~= nil)
                    end
                end
            end
        end
    end
    check("every setting of the page is on it once", #keys >= 60)

    -- each card says what it holds when it is closed
    check("Lists", CardOf(page, "lists").summary(s.store) == "Damage Done, current")
    s.store.Set("lower", "healing"); s.store.Set("session", "overall")
    check("Lists with a second list and another session", CardOf(page, "lists").summary(s.store)
        == "Damage Done over Healing Done, overall")
    s.store.Set("lower", ""); s.store.Set("session", "current")
    check("Window", CardOf(page, "window").summary(s.store) == "300 by 206")
    s.store.Set("locked", true)
    check("Window, locked", CardOf(page, "window").summary(s.store) == "300 by 206, locked")
    s.store.Set("locked", false)
    check("Bars", CardOf(page, "bars").summary(s.store) == "20 px rows, 2 px apart")
    check("Row", CardOf(page, "row").summary(s.store) == "Icons left, ranks on")
    check("Figures", CardOf(page, "figures").summary(s.store) == "Name, Total, Per Second")
    s.store.Set("columns", "total,name,interrupts")
    check("Figures, as the columns are", CardOf(page, "figures").summary(s.store) == "Total, Name, Interrupts")
    s.store.Set("columns", "auto")
    check("Title Bar", CardOf(page, "header").summary(s.store) == "List Name, buttons on")
    s.store.Set("showButtons", false)
    check("Title Bar, no buttons", CardOf(page, "header").summary(s.store) == "List Name, buttons off")
    s.store.Set("showButtons", true)
    check("Spells and Reports", CardOf(page, "hover").summary(s.store) == "Spells on, reports of 5 lines")
    check("Fights and Data", CardOf(page, "data").summary(s.store) == "0 of 30 fights kept")
    s.account.damageMeterFights = { ["Player-1"] = { {}, {} } }
    check("Fights and Data counts them", CardOf(page, "data").summary(s.store) == "2 of 30 fights kept")
    s.account.damageMeterFights = nil
    -- every color is a picker that shows the theme's until one is picked
    for _, entry in ipairs(C.COLORS) do
        local row = RowOf(page, entry.key)
        -- the pickers of the texts with a cog are called what the cog holds, and found by the color's name
        local called = ({ nameColor = "Name Settings", valueColor = "Figure Settings",
            titleColor = "Title Settings" })[entry.key]
        check(entry.key .. ": a color row, labeled", row and row.colour == true and row.label == (called or entry.label)
            and (called == nil or row.search == entry.label:lower()))
        local token = THEME[entry.token]
        local r, g, b = row.get()
        check(entry.key .. ": shows the theme's " .. entry.token .. " until one is picked",
            r == token.r and g == token.g and b == token.b)
        row.set(0.1, 0.2, 0.3)
        local c = s.store.Get(entry.key)
        check(entry.key .. ": picking stores it", type(c) == "table" and c.r == 0.1 and c.g == 0.2 and c.b == 0.3)
        r, g, b = row.get()
        check(entry.key .. ": and shows it", r == 0.1 and g == 0.2 and b == 0.3)
        s.store.Set(entry.key, false)
    end
    local where = {}
    for _, entry in ipairs(C.COLORS) do
        local _, card = RowOf(page, entry.key)
        where[entry.key] = card.id
    end
    check("each text's color sits on the card of its text", where.nameColor == "row" and where.valueColor == "figures"
        and where.rankColor == "row" and where.columnColor == "header" and where.titleColor == "header"
        and where.timeColor == "header" and where.summaryColor == "header")
    check("the bars' on the Bars card, the window's on the Window card", where.windowColor == "window"
        and where.borderColor == "window" and where.headerColor == "header" and where.trackColor == "bars"
        and where.barCustomColor == "bars" and where.ownBarColor == "bars" and where.edgeColor == "bars")

    check("the custom bar color is left off the page until Custom Color", RowOf(page, "barCustomColor").hidden() == true)
    s.store.Set("barColor", "custom")
    check("which puts it there", RowOf(page, "barCustomColor").hidden() == false)
    s.store.Set("barColor", "class")
    check("the edge color needs Custom Color for the edge", RowOf(page, "edgeColor").needs() == false)
    s.store.Set("edgeStyle", "custom")
    check("which turns it on", RowOf(page, "edgeColor").needs() == true)
    s.store.Set("highlightPlayer", false)
    check("and Highlight Your Row", RowOf(page, "edgeColor").needs() == false)
    local edge = RowOf(page, "edgeStyle")
    check("Your Row Edge: the Accent, your class or custom", edge.choice[2][1] == "accent"
        and edge.choice[2][2] == "class" and edge.choice[2][3] == "custom" and edge.needs() == false)
    s.store.Set("highlightPlayer", true)
    check("and only with Highlight Your Row", edge.needs() == true)
    s.store.Set("edgeStyle", "accent")

    -- the second and third windows: a switch each, and their own rows
    for _, n in ipairs({ 2, 3 }) do
        local card = CardOf(page, "window" .. n)
        check("window" .. n .. ": a switch on its own setting", card.switch == "window" .. n)
        local got = {}
        for _, row in ipairs(card.rows) do
            if row.under == nil then got[#got + 1] = row.key end
        end
        check("window" .. n .. ": its own list, second list, session, size, and the look and columns", table.concat(got, ",")
            == ("mode%d,lower%d,session%d,width%d,height%d,scale%d,ownLook%d,columns%d"):format(n, n, n, n, n, n, n, n))
    end
    s.store.Set("mode2", "healing")
    check("a second window reads its own list and size", CardOf(page, "window2").summary(s.store)
        == "Healing Done, 300 by 206")
    check("and the third its own", CardOf(page, "window3").summary(s.store) == "Damage Taken, 300 by 206")

    -- the time of the fight, and Hide After
    local delay = RowOf(page, "hideDelay")
    check("Hide After is left off the page unless Where is In Combat", delay.hidden() == true)
    s.store.Set("visibility", "combat")
    check("which puts it there", delay.hidden() == false)
    s.store.Set("visibility", "always")
    local decimals = RowOf(page, "numberDecimals")
    check("Decimals are left off for a format that does not abbreviate", decimals.hidden() == true)
    s.store.Set("numberUnits", "latin")
    check("which K, M, B do", decimals.hidden() == false)
    s.store.Set("numberUnits", "asian")
    check("and Ten-thousands", decimals.hidden() == false)
    s.store.Set("numberUnits", "full")
    check("but not Full Numbers", decimals.hidden() == true)
    s.store.Set("numberUnits", "game")
    local tileSize = RowOf(page, "imageTileSize")
    s.store.Set("backgroundImage", "Marble")
    check("Tile Size needs a picture that is tiled", tileSize.needs() == false)
    s.store.Set("imageTile", true)
    check("which it is", tileSize.needs() == true)
    s.store.Set("imageTile", false); s.store.Set("backgroundImage", "")
    local image = RowOf(page, "imageAlpha")
    check("the image rows need an image", image.needs() == false and RowOf(page, "imageTile").needs() == false)
    s.store.Set("backgroundImage", "Marble")
    check("and have one", image.needs() == true and RowOf(page, "imageTile").needs() == true)
    s.store.Set("backgroundImage", "")
end

print("PASS damage meter: " .. checks .. " checks")
