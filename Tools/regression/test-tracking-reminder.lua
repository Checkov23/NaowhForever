-- Run with Lua 5.1 from the repository root: the Tracking Reminder module tests.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local function Short(text)
    return type(text) == "string" and #text < 100 and not text:find("%. ")
end

local function Has(list, spell)
    for i = 1, #list do
        if list[i] == spell then return true end
    end
    return false
end

local BEASTS, HUMANOIDS, UNDEAD, HIDDEN = 1494, 19883, 19884, 19885
local SENSE_UNDEAD, SENSE_DEMONS, FIND_TREASURE = 5502, 5500, 2481
local TRACK_DRUID_HUMANOIDS = 5225

local function Load(opts)
    opts = opts or {}
    local store, listeners, frames = {}, {}, {}
    local card, pageKey
    local tip = { lines = {} }
    function tip:SetOwner() self.lines = {} end
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    function tip:SetSpellByID() end
    function tip:Show() end
    local who = { race = opts.race or "Human", class = opts.class or "HUNTER" }
    local known, active = opts.known or {}, opts.active or {}
    local S = {}
    function S.Get(k) return store[k] end
    function S.Set(k, v)
        store[k] = v
        for i = 1, #listeners do listeners[i](k, v) end
    end
    function S.OnChange(fn) listeners[#listeners + 1] = fn end
    local ns = {
        L = dofile("Tools/regression/locale_stub.lua").L,
        Upper = string.upper, Lower = string.lower,
        THEME = { accentSoft = {}, fg = { r = 1, g = 1, b = 1 } },
        Tooltip = function(frame, title, body)
            frame._tipTitle, frame._tipBody = title, body
        end,
        Border = function() end,
        Font = function()
            local font = {}
            function font:SetPoint() end
            function font:SetText(text) self.text = text end
            return font
        end,
        Apply = function() end, ShowUnlockMode = function() end, HideUnlockMode = function() end,
        UI = {
            ModuleSettings = function(_, defaults)
                for k, v in pairs(defaults) do
                    if store[k] == nil then store[k] = v end
                end
                return S
            end,
            AttachMover = function() return { SetShown = function() end } end,
        },
        Shared = {
            Style = { BORDER_RGB = {}, ICON_CROP = 0.08, HUD_TEXT_RANGE = { 8, 24, 1 },
                FOREVER_GOLD_RGB = { r = 1, g = 0.82, b = 0 } },
            Parts = { HudFont = function() end },
            Settings = {
                Group = function(title) return { group = title } end,
                Look = function() return {} end,
                Page = function(key)
                    pageKey = key
                    local page = {}
                    function page:Card(spec) card = spec; return spec end
                    return page
                end,
            },
        },
    }
    local function Frame()
        local f = { scripts = {}, events = {}, attrs = {} }
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:RegisterUnitEvent(e, ...) self.events[e] = { ... } end
        function f:UnregisterAllEvents() self.events = {} end
        function f:CreateTexture()
            return setmetatable({}, { __index = function(_, key)
                if type(key) == "string" and key:find("^%u") then return function() end end
            end })
        end
        function f:SetAttribute(k, v) self.attrs[k] = v end
        function f:RegisterForClicks(...) self.clicks = { ... } end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:IsShown() return self.shown == true end
        function f:SetPoint(...) self.point = { ... } end
        return setmetatable(f, { __index = function(_, key)
            if type(key) == "string" and key:find("^%u") then return function() end end
        end })
    end
    local env = setmetatable({
        NaowhForever = ns, UIParent = {},
        CreateFrame = function(_, name, _, template)
            local f = Frame()
            f.name, f.template = name, template
            frames[#frames + 1] = f
            return f
        end,
        hooksecurefunc = function(tbl, name, fn)
            local prev = tbl[name]
            tbl[name] = function(...)
                if prev then prev(...) end
                return fn(...)
            end
        end,
        wipe = function(t)
            for k in pairs(t) do t[k] = nil end
            return t
        end,
        InCombatLockdown = function() return false end,
        GetShapeshiftFormID = function() return opts.form end,
        UnitIsDeadOrGhost = function() return false end,
        UnitOnTaxi = function() return false end,
        IsInInstance = function() return false end,
        UnitRace = function() return who.race, who.race end,
        UnitClass = function() return who.class, who.class end,
        GameTooltip = tip,
        GameTooltip_Hide = function() end,
        C_Spell = {
            GetSpellTexture = function(id) return id end,
            GetSpellName = function(id) return "Spell " .. id end,
        },
        C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end },
        C_Secrets = { ShouldAurasBeSecret = function() return opts.secretAuras == true end },
        C_UnitAuras = {
            GetPlayerAuraBySpellID = function(id)
                opts.auraReads = (opts.auraReads or 0) + 1
                return opts.auras and opts.auras[id] or nil
            end,
        },
        C_Minimap = {
            GetNumTrackingTypes = function()
                if opts.types then return #opts.types end
                return #active
            end,
            GetTrackingInfo = function(i)
                if opts.types then
                    local t = opts.types[i]
                    if opts.tuple then return t.name, "tex", t.active, "spell", "spell", t.spell end
                    return { spellID = t.spell, active = t.active, name = t.name }
                end
                local id = active[i]
                if opts.tuple then return "name", "tex", true, "spell", "spell", id end
                return { spellID = id, active = true }
            end,
            SetTracking = opts.track and function(index, on)
                opts.track.index, opts.track.on = index, on
            end or nil,
        },
    }, { __index = _G })
    env._G = env
    for _, file in ipairs({
        "Core/Features.lua",
        "NaowhForever_Utilities/TrackingReminder/TrackingReminder.lua",
        "NaowhForever_Utilities/TrackingReminder/Data/Spells.lua",
        "NaowhForever_Utilities/TrackingReminder/UI/Reminder.lua",
        "NaowhForever_Utilities/TrackingReminder/UI/SettingsPage.lua",
    }) do
        local chunk = assert(loadstring(Read(file), file))
        setfenv(chunk, env)
        chunk()
    end
    if opts.settings then
        for k, v in pairs(opts.settings) do S.Set(k, v) end
    end
    for _, f in ipairs(frames) do
        if f.scripts.OnEvent and f.events.PLAYER_LOGIN then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
    end
    return { ns = ns, S = S, frames = frames, card = card, who = who, pageKey = pageKey, tip = tip }
end

local function Armed(world)
    local spells = {}
    for _, f in ipairs(world.frames) do
        if f.template == "SecureActionButtonTemplate" and f.spell then
            spells[#spells + 1] = f.spell
        end
    end
    return spells
end

local function TrackingOn(world)
    for _, f in ipairs(world.frames) do
        if f.events.MINIMAP_UPDATE_TRACKING then return true end
    end
    return false
end

local function Named(world, name)
    for _, f in ipairs(world.frames) do
        if f.name == name then return f end
    end
end

local function Button(world, spell)
    for _, f in ipairs(world.frames) do
        if f.template == "SecureActionButtonTemplate" and f.spell == spell then return f end
    end
end

local function Fire(world, event)
    for _, f in ipairs(world.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
    end
end

do
    local ns = {
        L = dofile("Tools/regression/locale_stub.lua").L,
        Upper = string.upper, Lower = string.lower,
    }
    _G.NaowhForever = ns
    assert(loadstring(Read("Core/Features.lua"), "Features"))()
    check("trackingReminder feature switches exist", ns.FEATURES.trackingReminder ~= nil)
    check("trackingReminder is off by default", ns.FEATURES.trackingReminder.enabled == false)
    check("trackRacial is on by default", ns.FEATURES.trackingReminder.trackRacial == true)
    check("trackClass is on by default", ns.FEATURES.trackingReminder.trackClass == true)
end

do
    local world = Load()
    local TR = world.ns.TrackingReminder
    check("TrackingReminder module table exists", TR ~= nil)
    check("TrackingReminder.Enabled() is false", TR.Enabled() == false)
    check("TrackingReminder.On() is false", TR.On() == false)
    check("settings page is Racial and Class Tracking/Settings", world.pageKey == "Racial and Class Tracking/Settings")
    check("Find Treasure ID is 2481", TR.Data.FIND_TREASURE == FIND_TREASURE)
    check("RACIAL contains Dwarf Find Treasure", #TR.Data.RACIAL == 1 and TR.Data.RACIAL[1].spell == FIND_TREASURE
        and TR.Data.RACIAL[1].race == "Dwarf")
    local hunterSpells, paladinSpells, warlockSpells, druidSpells = 0, 0, 0, 0
    for _, t in ipairs(TR.Data.CLASS) do
        if t.class == "HUNTER" then hunterSpells = hunterSpells + 1 end
        if t.class == "PALADIN" then paladinSpells = paladinSpells + 1 end
        if t.class == "WARLOCK" then warlockSpells = warlockSpells + 1 end
        if t.class == "DRUID" then
            druidSpells = druidSpells + 1
            check("Druid Track Humanoids is 5225", t.spell == TRACK_DRUID_HUMANOIDS)
        end
    end
    check("Hunter has 8 tracking spells", hunterSpells == 8)
    check("Paladin has Sense Undead", paladinSpells == 1)
    check("Warlock has Sense Demons", warlockSpells == 1)
    check("Druid has Track Humanoids", druidSpells == 1)
    check("off: no tracking events", not TrackingOn(world))
    check("off: no reminder row", Named(world, "NaowhForeverTrackingReminder") == nil)
    check("off: no secure buttons", #Armed(world) == 0)
    check("card help is one short sentence", Short(world.card.help))
    local rows = world.card.rows()
    for i = 1, #rows do
        if rows[i].help then
            check("help is one short sentence: " .. tostring(rows[i].label), Short(rows[i].help))
        end
    end
    local hunterFields = {}
    for i = 1, #rows do
        if rows[i].field then hunterFields[rows[i].field] = true end
    end
    check("a human hunter sees beast tracking", hunterFields.beasts == true)
    for i = 1, #rows do
        if rows[i].field == "beasts" then
            check("a tracking spell starts on", rows[i].get() == true)
            rows[i].set(false)
            check("turning a pick off stores false", world.S.Get("classPicks").beasts == false)
            rows[i].set(true)
            check("turning a pick back on clears the saved value", world.S.Get("classPicks").beasts == nil)
        end
    end
    check("a human hunter does not see Find Treasure", hunterFields.treasure ~= true)
    check("a human hunter does not see Sense Undead", hunterFields.senseUndead ~= true)
    check("the preview has a state", world.card.studio.states[1].key == "untracked")
    local shot = world.card.studio.new({})
    world.card.studio.paint(shot)
    check("the preview label starts with Track", shot.label.text == "Track Beasts")
    world.who.race, world.who.class = "Dwarf", "PALADIN"
    local paladinFields = {}
    rows = world.card.rows()
    for i = 1, #rows do
        if rows[i].field then paladinFields[rows[i].field] = true end
    end
    check("a dwarf paladin sees Find Treasure", paladinFields.treasure == true)
    check("a dwarf paladin sees Sense Undead", paladinFields.senseUndead == true)
    check("a dwarf paladin does not see beast tracking", paladinFields.beasts ~= true)
    world.who.race, world.who.class = "Human", "MAGE"
    rows = world.card.rows()
    local mageTracking = false
    for i = 1, #rows do
        if rows[i].key == "trackRacial" or rows[i].key == "trackClass" or rows[i].field then mageTracking = true end
    end
    check("a mage has no racial or class rows", not mageTracking)
    world.who.race, world.who.class = "NightElf", "DRUID"
    rows = world.card.rows()
    local druidFields = {}
    for i = 1, #rows do
        if rows[i].field then druidFields[rows[i].field] = true end
    end
    check("a druid sees Track Humanoids", druidFields.druidHumanoids == true)
    check("the druid pick has its own key", druidFields.humanoids ~= true)
end

do
    local world = Load({
        known = { [BEASTS] = true, [HUMANOIDS] = true, [UNDEAD] = true, [HIDDEN] = true },
        settings = { enabled = true, trackClass = true, trackRacial = true },
    })
    check("class tracking on with no picks shows the known spells", #Armed(world) == 4)
end

do
    local world = Load({
        known = { [BEASTS] = true, [HUMANOIDS] = true, [UNDEAD] = true, [HIDDEN] = true },
        settings = {
            enabled = true, trackClass = true, trackRacial = true,
            classPicks = { beasts = true, humanoids = true, undead = true, hidden = true },
        },
    })
    local spells = Armed(world)
    local home = Named(world, "NaowhForeverTrackingReminder").point
    check("it homes above the Find Herbs spot", home[1] == "CENTER" and home[3] == "CENTER"
        and home[4] == 260 and home[5] == 170)
    check("four missing hunter tracks get four icons", #spells == 4)
    check("the four icons are those tracks", Has(spells, BEASTS) and Has(spells, HUMANOIDS)
        and Has(spells, UNDEAD) and Has(spells, HIDDEN))
    check("on: tracking events are registered", TrackingOn(world))
    local learned, oldEvent, auraEvent = false, false, false
    for _, f in ipairs(world.frames) do
        if f.events.LEARNED_SPELL_IN_SKILL_LINE then learned = true end
        if f.events.LEARNED_SPELL_IN_TAB then oldEvent = true end
        local units = f.events.UNIT_AURA
        if units then auraEvent = type(units) == "table" and #units == 1 and units[1] == "player" end
    end
    check("learns spells on LEARNED_SPELL_IN_SKILL_LINE", learned and not oldEvent)
    check("only the player's aura changes refresh the row", auraEvent)
    local beasts = Button(world, BEASTS)
    check("left-click still casts that tracking", beasts.attrs.type1 == "spell"
        and beasts.attrs.spell1 == "Spell " .. BEASTS and beasts.attrs.type2 == nil)
    check("the secure button takes presses and releases", beasts.clicks[1] == "AnyUp" and beasts.clicks[2] == "AnyDown")
    check("the secure button waits for the release", beasts.attrs.useOnKeyDown == false)
    check("the icon label is Track plus its name", beasts.label.text == "Track Beasts")
    check("the tooltip title is Not Tracking", beasts._tipTitle == "Not Tracking")
    check("the tooltip is one sentence", beasts._tipBody
        == "Left-click turns it on, and right-click hides it until you change area.")
    local row = Named(world, "NaowhForeverTrackingReminder")
    beasts.scripts.PostClick(beasts, "LeftButton")
    check("left-click leaves the row up", row.shown == true)
    beasts.scripts.PostClick(beasts, "RightButton")
    check("right-click hides the row", row.shown == false)
    world.ns.ShowUnlockMode()
    check("unlock mode shows a snoozed row", row.shown == true)
    beasts.scripts.PostClick(beasts, "RightButton")
    check("right-click while unlocking leaves it up", row.shown == true)
    world.ns.HideUnlockMode()
    check("locking keeps the snooze", row.shown == false)
    Fire(world, "MINIMAP_UPDATE_TRACKING")
    check("a tracking update stays hidden", row.shown == false)
    Fire(world, "ZONE_CHANGED_NEW_AREA")
    check("a new area shows the row again", row.shown == true)
    beasts.scripts.PostClick(beasts, "RightButton")
    Fire(world, "PLAYER_ENTERING_WORLD")
    check("entering the world shows the row again", row.shown == true)
    world.S.Set("classPicks", { beasts = false, humanoids = true, undead = true, hidden = true })
    spells = Armed(world)
    check("turning a pick off drops that icon", #spells == 3 and not Has(spells, BEASTS)
        and Has(spells, HUMANOIDS) and Has(spells, UNDEAD) and Has(spells, HIDDEN))
end

do
    local world = Load({
        tuple = true,
        known = {
            [BEASTS] = true, [HUMANOIDS] = true, [UNDEAD] = true, [HIDDEN] = true,
            [SENSE_UNDEAD] = true, [FIND_TREASURE] = true,
        },
        active = { BEASTS },
        settings = {
            enabled = true, trackClass = true, trackRacial = true,
            classPicks = { humanoids = true, undead = true, hidden = false },
        },
    })
    local spells = Armed(world)
    check("an active track, a turned-off pick, and other classes are omitted", #spells == 2
        and Has(spells, HUMANOIDS) and Has(spells, UNDEAD) and not Has(spells, BEASTS)
        and not Has(spells, HIDDEN) and not Has(spells, SENSE_UNDEAD) and not Has(spells, FIND_TREASURE))
end

do
    local track = {}
    local world = Load({
        race = "Dwarf", class = "WARRIOR",
        known = { [FIND_TREASURE] = true },
        settings = { enabled = true, trackRacial = true, racialPicks = { treasure = true } },
        types = { { spell = FIND_TREASURE, active = false, name = "Spell " .. FIND_TREASURE } },
        track = track,
    })
    local treasure = Button(world, FIND_TREASURE)
    check("an off track is armed on the minimap list", treasure.trackIndex == 1 and treasure.attrs.spell1 == nil)
    treasure.scripts.PostClick(treasure, "LeftButton")
    check("left-click turns Find Treasure on", track.index == 1 and track.on == true)
    check("left-click does not hide the row", Named(world, "NaowhForeverTrackingReminder").shown == true)
end

do
    local shown = Load({
        race = "Human", class = "WARLOCK",
        known = { [SENSE_DEMONS] = true },
        settings = { enabled = true, trackClass = true },
    })
    local demons = Button(shown, SENSE_DEMONS)
    check("a spell with no minimap slot is cast from the button", demons.trackIndex == nil
        and demons.attrs.type1 == "spell" and demons.attrs.spell1 == "Spell " .. SENSE_DEMONS)
end

do
    local opts = {
        race = "Human", class = "WARLOCK",
        known = { [SENSE_DEMONS] = true },
        settings = { enabled = true, trackClass = true },
        auras = { [SENSE_DEMONS] = true },
    }
    check("a slot-less tracking clears once its aura is up", #Armed(Load(opts)) == 0)
    check("the aura was read", (opts.auraReads or 0) > 0)
end

do
    local opts = {
        race = "Human", class = "WARLOCK",
        known = { [SENSE_DEMONS] = true },
        settings = { enabled = true, trackClass = true },
        secretAuras = true,
        auras = { [SENSE_DEMONS] = true },
    }
    check("secret auras leave a slot-less reminder up", #Armed(Load(opts)) == 1)
    check("secret auras are not read", opts.auraReads == nil)
end

do
    local opts = {
        race = "Human", class = "WARLOCK",
        known = { [SENSE_DEMONS] = true },
        settings = { enabled = true, trackClass = true },
        auras = { [SENSE_DEMONS] = true },
    }
    local world = Load(opts)
    opts.secretAuras = true
    opts.auras = nil
    Fire(world, "UNIT_AURA")
    check("secret auras keep the last aura state", #Armed(world) == 0)
end

do
    local CAT_FORM = 1
    local opts = {
        race = "NightElf", class = "DRUID",
        known = { [TRACK_DRUID_HUMANOIDS] = true },
        settings = { enabled = true, trackClass = true },
    }
    local world = Load(opts)
    local row = Named(world, "NaowhForeverTrackingReminder")
    check("out of Cat Form there is no Track Humanoids icon", #Armed(world) == 0 and row.shown == false)
    local shifts = false
    for _, f in ipairs(world.frames) do
        if f.events.UPDATE_SHAPESHIFT_FORM then shifts = true end
    end
    check("a druid who knows Track Humanoids watches shapeshifts", shifts)
    opts.form = CAT_FORM
    Fire(world, "UPDATE_SHAPESHIFT_FORM")
    check("in Cat Form Track Humanoids gets an icon", Button(world, TRACK_DRUID_HUMANOIDS) ~= nil
        and row.shown == true)
end

do
    local world = Load({
        known = { [BEASTS] = true },
        settings = { enabled = true, trackClass = true },
    })
    local shifts = false
    for _, f in ipairs(world.frames) do
        if f.events.UPDATE_SHAPESHIFT_FORM then shifts = true end
    end
    check("a hunter does not watch shapeshifts", not shifts)
end

print(("test-tracking-reminder: %d checks passed"):format(checks))
