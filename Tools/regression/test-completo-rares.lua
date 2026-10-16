-- Run with Lua 5.1 from the repository root: Completo's Rares. A rare friendly to your faction
-- is not yours; a zone counts the ones you killed; a targeted rare dying counts once when it was
-- yours and not when someone else tapped it; a looted corpse counts; Shift-click ticks one off.
-- Rare Alerts: a rare's nameplate brings the alert, once per rare in a while; not for a dead or
-- friendly one, nor one you killed unless Alert for Killed Rares; it fades after Stays For and moves
-- in the HUD Editor; Unlock Mode previews it; the settings preview draws each moment; nothing is
-- registered while it is off. Raid marks are Blizzard-only on Forever: SetRaidTarget and the other
-- marker calls raise an error here, so no rare path (nameplate, mouseover, target, minimap, Test
-- Alert, Unlock Mode, the settings preview) may call them.
-- Rare Alert targeting: hovering the card out of combat lays an invisible secure button over it
-- (all but its pin) running /targetexact on the rare; it hides when combat starts and its macro
-- is never set in combat; right-clicking it still closes the card. Skull on Click (off by default)
-- adds the game's /tm !8 after /cleartarget and /targetexact.
-- Map Pins: hover a star for its tooltip, click it for a waypoint, right-click it to keep its spots
-- and way shown (no panel).

local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local function Strsplit(sep, s)
    local out = {}
    for part in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
    return unpack(out)
end

local function Region()
    local r = { shown = true, text = "" }
    function r:SetText(t) self.text = t or "" end
    function r:GetText() return self.text end
    function r:GetStringWidth() return #self.text * 7 end
    function r:GetStringHeight() return 14 end
    function r:SetShown(on) self.shown = on and true or false end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:CreateTexture() return Region() end
    function r:SetTexture(t) self.texture = t end
    function r:GetFrameLevel() return 5 end
    function r:GetParent() return self.parent end
    function r:SetFrameStrata(s) self.strata = s end
    function r:SetVertexColor(red) self.vertex = red end
    -- Where it is: its middle, in its own units (scale), and the screen's (UIParent's).
    r.scale = 1
    function r:SetScale(s) self.scale = s end
    function r:GetScale() return self.scale end
    function r:GetEffectiveScale() return self.scale end
    function r:GetCenter() return 410.4 / self.scale, 619.6 / self.scale end
    function r:SetPoint(point, _, _, x, y) self.point, self.at = point, { x, y } end
    -- A portrait model: what it was last set to show.
    function r:ClearModel() self.unit, self.creature = nil, nil end
    function r:SetUnit(unit) self.unit = unit end
    function r:SetCreature(npc) self.creature = npc end
    function r:GetModelFileID() return self.creature or self.unit end
    function r:SetScript(k, fn) self[k] = fn end
    -- Every other drawing call (a method: a capital first letter) does nothing.
    return setmetatable(r, { __index = function(_, key)
        if key:find("^%u") then return function() end end
    end })
end

-- The alert's look as Completo's defaults have it, where a test leaves it out.
local LOOK = { rareAlertTime = 20, rareAlertScale = 1, rareAlertFont = "", rareAlertFontSize = 13,
    rareAlertOutline = "", rareAlertBackground = "card", rareAlertGlow = false }

local function Fixture(settings, units)
    for k, v in pairs(LOOK) do
        if settings[k] == nil then settings[k] = v end
    end
    local env = { pairs = pairs, ipairs = ipairs, type = type, math = math, table = table, select = select,
        setmetatable = setmetatable,
        tostring = tostring, tonumber = tonumber, string = string, wipe = function(t)
            for k in pairs(t) do t[k] = nil end
            return t
        end }
    env.strsplit = Strsplit
    env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
    local now = 1000
    env.time = function() return now end
    env.GetTime = function() return now end
    env.Advance = function(s) now = now + s end
    local frames = {}
    env.CreateFrame = function(_, _, parent)
        local f = Region()
        f.parent = parent
        f.events, f.unitEvents = {}, {}
        function f:RegisterForClicks() end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:RegisterUnitEvent(e, unit) self.events[e] = true; self.unitEvents[e] = unit end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(k, fn) self[k] = fn end
        f.CreateAnimationGroup = function()
            local none = function() end
            local g = { playing = false, SetLooping = none }
            g.SetScript = function(group, k, fn) group[k] = fn end
            g.Play = function(group) group.playing = true end
            g.Stop = function(group) group.playing = false end
            g.IsPlaying = function(group) return group.playing end
            g.CreateAnimation = function()
                return { SetFromAlpha = function(a, v) a.from = v end, SetToAlpha = none, SetDuration = none,
                    SetSmoothing = none,
                    SetOrder = none, SetStartDelay = function(a, d) a.delay = d end }
            end
            return g
        end
        frames[#frames + 1] = f
        return f
    end
    -- Every frame listening for the event hears it.
    env.Fire = function(event, ...)
        for _, f in ipairs(frames) do
            if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
        end
    end
    env.Listening = function(event)
        for _, f in ipairs(frames) do
            if f.events[event] then return true end
        end
        return false
    end
    env.hooksecurefunc = function(t, key, fn)
        local orig = t[key]
        t[key] = function(...) orig(...); fn(...) end
    end
    env.UnitName = function(unit) return units[unit] and units[unit].name or "Grim" end
    env.GetRealmName = function() return "Realm" end
    env.UnitFactionGroup = function() return "Horde" end
    env.UnitGUID = function(unit) return units[unit] and units[unit].guid end
    env.UnitExists = function(unit) return units[unit] ~= nil end
    env.UnitIsDead = function(unit) return units[unit] and units[unit].dead or false end
    env.UnitIsTapDenied = function(unit) return units[unit] and units[unit].denied or false end
    env.UnitClassification = function(unit) return units[unit] and units[unit].kind or "normal" end
    env.UnitCanAttack = function(_, unit) return not (units[unit] and units[unit].friend) end
    env.UnitLevel = function(unit) return units[unit] and units[unit].level or 20 end
    env.IsInGroup = function() return units.group ~= nil end
    env.IsInRaid = function() return units.group == "raid" end
    env.UnitIsGroupLeader = function() return false end
    env.UnitIsGroupAssistant = function() return false end
    -- Blizzard-only on Forever (HasRestrictions): any call fails the test, and is counted in case
    -- something catches the error.
    env.restricted = 0
    local function Restricted(name)
        return function()
            env.restricted = env.restricted + 1
            error(name .. " is Blizzard-only on Forever: Completo must never call it", 2)
        end
    end
    env.SetRaidTarget = Restricted("SetRaidTarget")
    env.PlaceRaidMarker = Restricted("PlaceRaidMarker")
    env.ClearRaidMarker = Restricted("ClearRaidMarker")
    env.RemoveRaidTargets = Restricted("RemoveRaidTargets")
    env.loot = {}
    env.GetNumLootItems = function() return #env.loot end
    env.GetLootSourceInfo = function(slot) return env.loot[slot], 1 end
    env.lootLinks = {}
    env.GetLootSlotLink = function(slot) return env.lootLinks[slot] end
    env.sounds = 0
    env.PlaySound = function() env.sounds = env.sounds + 1 end
    env.PlaySoundFile = function(file) env.soundFile = file; env.sounds = env.sounds + 1 end
    env.SOUNDKIT = { RAID_WARNING = 8959 }
    env.C_Timer = { NewTimer = function() return { Cancel = function() end } end }
    env.C_Map = { GetBestMapForUnit = function() return 1440 end, GetMapInfo = function() end }
    env.vignettes = {}
    env.C_VignetteInfo = { GetVignetteInfo = function(id) return env.vignettes[id] end }
    local account = {}
    env.IsInInstance = function() return units.instance == true end
    env.InCombatLockdown = function() return units.combat == true end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, THEME = { accent = {}, muted = { r = 0.66 }, fg = {}, panel = {}, accentSoft = {}, bg = {} },
        Apply = function() end,
        ShowUnlockMode = function() end, HideUnlockMode = function() end }
    ns.AccountSettings = function() return account end
    ns.Font = function() return Region() end
    ns.Solid = function(parent)
        local t = Region()
        function t:SetHeight(h) self.height = h end
        function t:SetWidth(w) self.width = w end
        function t:SetColorTexture(red) self.red = red end
        if parent then
            parent.sides = parent.sides or {}
            parent.sides[#parent.sides + 1] = t
        end
        return t
    end
    ns.Border = function() end
    -- A colour escape, as the colour's tag.
    ns.Color = function(c, text) return ("[%s]%s"):format(c.tag or "?", text) end

    env.waypoints = {}
    ns.PlaceWaypoint = function(name, map, x, y) env.waypoints[#env.waypoints + 1] = { name, map, x, y } end
    env.UIParent = Region()
    env.UIParent.GetCenter = function() return 400, 500 end
    env.UIParent.GetRight = function() return 1000 end
    -- The card, by its frame name.
    local create = env.CreateFrame
    ---@diagnostic disable-next-line: duplicate-set-field
    env.CreateFrame = function(kind, name, parent, template)
        local f = create(kind, name, parent, template)
        if name == "NaowhForeverRareAlert" then ns.alert = f end
        -- The secure target button: its template, attributes, textures, place, and its show and
        -- hide scripts run as the game runs them.
        if name == "NaowhForeverRareAlertTarget" then
            ns.target, f.template, f.attrs, f.textures = f, template, {}, 0
            f.combatSets = 0
            function f:SetAttribute(k, v)
                if env.InCombatLockdown() then self.combatSets = self.combatSets + 1 end
                self.attrs[k] = v
            end
            function f:CreateTexture() self.textures = self.textures + 1; return Region() end
            function f:SetSize(w, h) self.size = { w, h } end
            function f:IsMouseOver() return env.overTarget == true end
            function f:Show()
                assert(not env.InCombatLockdown(), "the secure button is shown in combat")
                self.shown = true
                if self.OnShow then self.OnShow(self) end
            end
            function f:Hide()
                assert(not env.InCombatLockdown(), "the secure button is hidden in combat")
                self.shown = false
                if self.OnHide then self.OnHide(self) end
            end
        end
        return f
    end
    -- The HUD Editor's plates, by label.
    ns.movers = {}
    ns.UI = { SoundPathFor = function() return nil end, _PlayLSMSound = function() end,
        AttachMover = function(frame, label, onMoved, page, feature)
            local mover = Region()
            mover.shown, mover.frame, mover.onMoved, mover.page, mover.feature = false, frame, onMoved, page, feature
            ns.movers[label] = mover
            return mover
        end }
    ns.SoundChoices = function()
        return {}, { ["voice:move-out"] = "Move out", ["lsm:BugSack: Fatality"] = "BugSack: Fatality",
            ["lsm:Bell"] = "Bell" }, { "voice:move-out", "lsm:BugSack: Fatality", "lsm:Bell" }
    end
    ns.CompletoSettings = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end,
        DB = function() return settings end }
    ns.Completo = { Settings = ns.CompletoSettings }
    -- The settings pages' cards, by id, to reach their rows.
    ns.cards = {}
    local page = { Window = function() end, Card = function(_, spec) ns.cards[spec.id] = spec end }
    local Settings = { Page = function() return page end, Group = function(title) return { group = title } end }
    -- Settings.Look's rows, as the keys it would name.
    function Settings.Look(prefix, opts)
        local rows = { { key = prefix .. "Font" }, { key = prefix .. "FontSize" }, { key = prefix .. "Outline" } }
        if opts.background == "card" then rows[#rows + 1] = { key = prefix .. "Background" } end
        return rows
    end
    ns.Shared = { Settings = Settings, MapPins = {}, ScalePin = function() end,
        -- Per character, by the player's GUID.
        CharacterData = function(key)
            account[key] = account[key] or {}
            account[key]["Player-1-0001"] = account[key]["Player-1-0001"] or {}
            return account[key]["Player-1-0001"]
        end,
        Style = { PIN = "pin", TICK = "tick", HAVE_RGB = { tag = "have", r = 0.3 }, WARN_RGB = { tag = "warn" },
            PANEL_W = 380, PANEL_PAD = 10, PANEL_HEADER = 30 },
        Parts = {
            -- Forever's sign, as text.
            ForeverInline = function() return " <inf>" end,
            -- The pin button: its click.
            IconButton = function(parent, onClick)
                local button = Region()
                button.parent, button.OnClick = parent, onClick
                return button
            end,
            HudBackdrop = function()
                return { SetMode = function(b, mode) b.mode = mode or "card"; return b.mode end }
            end,
            HudFont = function(fs, font, size, outline) fs.font, fs.size, fs.outline = font, size, outline end,
            ItemIcon = function()
                local icon = Region()
                icon.texture = Region()
                return icon
            end,
            -- The house panel: its title and close button.
            Panel = function(title)
                local panel = env.CreateFrame("Frame", "Panel")
                panel.title = Region()
                panel.title:SetText(title)
                panel.close = Region()
                ns.mapPanel = panel
                return panel
            end } }
    ns.Button = function(_, text, _, _, onClick)
        local button = Region()
        button.label, button._onClick = text, onClick
        return button
    end
    ns.OpenCompletoWindow = function(which, npc) env.opened = { which, npc } end
    -- Ashenvale: Mist Howler; Darkslayer Mordenthal, friendly to the Horde; Ursol'lok.
    ns.CompletoRareData = {
        Zones = { { map = 1440, name = "Ashenvale", continent = 1, rares = { 10644, 3736, 12037, 10647 } } },
        Rares = {
            [3736] = { "Darkslayer Mordenthal", 23, 23, 0, -1, 1, 1440, { 60.0, 70.0 } },
            [10644] = { "Mist Howler", 22, 22, 0, -1, -1, 1440, { 50.0, 40.0, 52.0, 44.0 } },
            [12037] = { "Ursol'lok", 31, 31, 0, -1, -1, 1440, {} },
            -- Patrols: a star on its way, three dots along it.
            [10647] = { "Prince Raze", 32, 32, 0, -1, -1, 1440, { 70.0, 20.0 }, { 68.0, 20.0, 70.0, 22.0, 72.0, 24.0 } },
        },
        -- Prince Raze: a blue of his own, a recipe, and more; Mist Howler: nothing special.
        Loot = {
            [10647] = { { 4454, 3, 22.2, "Talon of Vultros" }, { 5971, 2, 0.4, "Pattern: Feathered Cape" },
                { 285330, 3, 4.3, "Signet of the Zhevra", 1 }, more = 3 },
        },
    }
    ns.ThemeTint = function() return nil end
    env.CreateFromMixins = function(...)
        local out = {}
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do out[k] = v end
        end
        return out
    end
    env.MapCanvasPinMixin = { UseFrameLevelType = function(pin, _, index) pin.levelIndex = index end }
    env.MapCanvasDataProviderMixin = {}
    -- The world map, open on Ashenvale: pins made from the template's mixin, kept by template.
    local map = { pins = {} }
    function map:GetMapID() return 1440 end
    function map:RemoveAllPinsByTemplate() self.pins = {} end
    function map:RemovePin(pin)
        for i = #self.pins, 1, -1 do
            if self.pins[i] == pin then table.remove(self.pins, i) end
        end
    end
    function map:EnumeratePinsByTemplate()
        local i = 0
        return function()
            i = i + 1
            return self.pins[i]
        end
    end
    function map:AcquirePin(_, data)
        local pin = env.CreateFromMixins(env.NaowhForeverRarePinMixin)
        local icon = { atlas = nil, desaturated = false }
        function icon.SetAtlas(t, atlas) t.atlas = atlas; return true end
        function icon.SetTexture() end
        function icon.SetDesaturated(t, on) t.desaturated = on end
        function icon.SetAlpha(t, a) t.alpha = a end
        pin.Icon = icon
        pin.SetSize = function(p, w) p.size = w end
        pin.EnableMouse = function(p, on) p.mouse = on end
        pin.SetPosition = function(p, x, y) p.at = { x, y } end
        -- On a 1000-wide screen, the map filling it.
        pin.GetRight = function(p) return p.at[1] * 1000 end
        pin.GetEffectiveScale = function() return 1 end
        pin:OnAcquired(data)
        self.pins[#self.pins + 1] = pin
        return pin
    end
    env.WorldMapFrame = { IsShown = function() return true end }
    local none = function() end
    env.IsShiftKeyDown = function() return env.shift == true end
    -- The tooltip's lines, as shown last.
    env.tip = {}
    env.GameTooltip = { SetOwner = function(_, owner) env.tip, env.tipOwner = {}, owner end, SetText = none, Show = function() env.tipHidden = false end,
        Hide = function() env.tipHidden = true end,
        AddLine = function(_, text, r, g, b) env.tip[#env.tip + 1] = { text, nil, r, g, b } end,
        SetItemByID = function(_, id) env.tipItem = id end,
        AddDoubleLine = function(_, left, right, r, g, b) env.tip[#env.tip + 1] = { left, right, r, g, b } end }
    env.ITEM_QUALITY_COLORS = { [2] = { r = 0.1, g = 1, b = 0 }, [3] = { r = 0, g = 0.44, b = 0.87 } }
    env.C_Item = { GetItemIconByID = function(id) return 1000 + id end }
    function env.WorldMapFrame:AddDataProvider(provider)
        provider.GetMap = function() return map end
        env.provider = provider
    end
    env.worldMap = map
    env.NaowhForever = ns
    env._G = env
    Load({ "NaowhForever_Discovery/QuestList/Constants.lua", "NaowhForever_Discovery/QuestList/Data/AlertSounds.lua",
        "NaowhForever_Discovery/QuestList/Rares.lua", "NaowhForever_Discovery/QuestList/Kills.lua", "NaowhForever_Discovery/QuestList/Sounds.lua",
        "NaowhForever_Discovery/QuestList/View/Style.lua", "NaowhForever_Discovery/QuestList/View/AlertCard.lua",
        "NaowhForever_Discovery/QuestList/UI/RareAlert.lua", "NaowhForever_Discovery/QuestList/UI/RarePins.lua",
        "NaowhForever_Discovery/QuestList/UI/RaresSettings.lua" }, env)
    env.Fire("PLAYER_LOGIN")
    return ns, env, account
end

local function Guid(npc, spawn) return ("Creature-0-1-2-3-%d-%s"):format(npc, spawn or "0001") end

-- Kills
do
    local units = {}
    local ns, env, account = Fixture({ enabled = true }, units)
    local R = ns.Completo.Rares
    local zone = R.Zones()[1]
    Check(R.NpcOf(Guid(10644)) == 10644, "the npcID comes from the GUID")
    Check(R.NpcOf("Player-1-0001") == nil, "a player is no creature")
    Check(not R.Mine(3736) and R.Mine(10644), "a rare friendly to the Horde is not a Horde rare")
    local n, total, low, high = R.ZoneProgress(zone)
    Check(n == 0 and total == 3 and low == 22 and high == 32, "the zone counts its three rares for the Horde")

    units.target = { guid = Guid(10644), name = "Mist Howler" }
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(env.Listening("UNIT_HEALTH"), "a targeted rare is watched")
    units.target.dead = true
    env.Fire("UNIT_HEALTH", "target")
    Check(R.Killed(10644) and R.Record(10644).n == 1, "the targeted rare dying counts")
    Check(not env.Listening("UNIT_HEALTH"), "a dead rare is no longer watched")
    env.loot = { Guid(10644) }
    env.Fire("LOOT_READY")
    Check(R.Record(10644).n == 1, "looting the same corpse does not count it again")
    Check(account.completoRareKills["Player-1-0001"][10644] ~= nil, "kills are kept per character, by its GUID")

    units.target = { guid = Guid(10644, "0002"), name = "Mist Howler" }
    env.Fire("PLAYER_TARGET_CHANGED")
    units.target.dead, units.target.denied = true, true
    env.Fire("UNIT_HEALTH", "target")
    Check(R.Record(10644).n == 1, "a rare someone else tapped does not count")

    env.loot = { Guid(12037) }
    env.lootLinks = { "|cff0070dd|Hitem:4454::::::::30:::::|h[Talon of Vultros]|h|r" }
    env.Fire("LOOT_READY")
    Check(R.Killed(12037), "a looted rare counts")
    Check(R.Dropped(12037, 4454) and not R.Dropped(12037, 5971) and not R.Dropped(10644, 4454),
        "the item its loot window had is kept as that rare's drop")
    env.lootLinks = {}
    Check(select(1, R.ZoneProgress(zone)) == 2, "the zone counts both kills")

    local heard = 0
    R.OnChange(function() heard = heard + 1 end)
    R.SetKilled(12037, false)
    Check(not R.Killed(12037) and heard == 1, "Shift-click unticks a rare, and says so")
    R.SetKilled(12037, true)
    Check(R.Killed(12037) and R.Record(12037).n == 0, "ticked off by hand: killed, no kill counted")

    local found, count = R.Search("howl", 10)
    Check(count == 1 and found[1].ids[1] == 10644, "the search finds a rare by name")
    Check(R.CurrentZone() == zone, "the zone you are in")
    local map, x, y = R.Spot(10644)
    Check(map == 1440 and x == 50 and y == 40, "the waypoint goes to its first spot off its map")
end

-- Rare Alerts
do
    local units = {}
    local settings = { enabled = true, rareAlert = false, rareSound = true, rareAlertKilled = false }
    local ns, env = Fixture(settings, units)
    local R = ns.Completo.Rares
    Check(not env.Listening("NAME_PLATE_UNIT_ADDED"), "nothing is registered while Rare Alerts is off")
    ns.CompletoSettings.Set("rareAlert", true)
    Check(env.Listening("NAME_PLATE_UNIT_ADDED"), "on: nameplates are watched")

    units.nameplate1 = { guid = Guid(10644), name = "Mist Howler", kind = "rare", level = 22 }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(ns.alert and ns.alert:IsShown(), "a rare's nameplate brings the alert")
    Check(ns.alert.name.text:find("Mist Howler", 1, true), "the alert names it")
    local DOT = "  \194\183  "
    Check(ns.alert.detail.text == "Level 22" .. DOT .. "Rare" .. DOT .. "Not killed yet",
        "its level, kind, and that it is not killed yet")
    Check(ns.alert.model.unit == "nameplate1", "the portrait is its own model")
    Check(ns.alert.mark == nil, "the card has no raid mark")
    local holder = ns.alert:GetParent()
    Check(holder.strata == "HIGH", "it shows over the rest of the HUD")
    Check(ns.alert.fade.playing and ns.alert.fadeOut.delay == 20, "it fades in, and out after Stays For")
    Check(not ns.alert.glow.shown and ns.alert.backdrop.mode == "card" and ns.alert.name.size == 13
        and ns.alert.detail.size == 11, "no glow by default, on a card, in the Font Size and two under it")
    Check(#ns.alert.glow.sides == 4 and ns.alert.glow.sides[1].height == 3 and ns.alert.glow.sides[3].width == 3,
        "its glow is a 3px ring of four sides, nothing behind the card")
    Check(ns.alert.pin.shown, "its pin shows: it has a spot to go to")
    ns.alert.OnClick(ns.alert, "LeftButton")
    Check(#env.waypoints == 0 and ns.alert:IsShown(), "a click on the card sets no waypoint and leaves it up")
    ns.alert.pin.OnClick(ns.alert.pin)
    local wp = env.waypoints[1]
    Check(wp and wp[1] == "Mist Howler" and wp[2] == 1440 and wp[3] == 50 and wp[4] == 40,
        "its pin sets a waypoint to its spot")
    local mover = ns.movers["Rare Alert"]
    Check(mover and mover.frame == holder and mover.frame ~= ns.alert and mover.page == "Discovery/Rares"
        and mover.feature == "Discovery/Rares:rareAlert",
        "it moves in the HUD Editor by a holder that stays shown, with its settings card")
    Check(holder.at[1] == 0 and holder.at[2] == 260, "above the middle of the screen at first")
    mover.onMoved({ point = "CENTER", relPoint = "CENTER", x = 10, y = 120 })
    Check(settings.rareAlertPosition.x == 10 and settings.rareAlertPosition.y == 120, "the HUD Editor keeps its spot")
    ns.alert.model.unit = "kept"
    ns.CompletoSettings.Set("rareAlertScale", 2)
    Check(holder.scale == 2 and holder.at[1] == 5 and holder.at[2] == 60, "Size scales it about the same spot")
    ns.CompletoSettings.Set("rareAlertGlow", true)
    ns.CompletoSettings.Set("rareAlertBackground", "soft")
    Check(ns.alert.glow.shown and ns.alert.backdrop.mode == "soft",
        "Glow and Background change the card while it is up")
    Check(ns.alert.model.unit == "kept", "a settings change leaves the portrait alone")
    mover.onMoved({ point = "CENTER", relPoint = "CENTER", x = 5, y = 60 })
    Check(settings.rareAlertPosition.x == 10 and settings.rareAlertPosition.y == 120,
        "a spot saved at 200% is the same spot on the screen")
    ns.CompletoSettings.Set("rareAlertScale", 1)
    Check(holder.at[1] == 10 and holder.at[2] == 120, "and back at 100% it is where it was")
    settings.rareAlertPosition = { point = "CENTER", relPoint = "CENTER", x = -30, y = 40 }
    ns.Apply()
    Check(holder.at[1] == -30 and holder.at[2] == 40, "a profile switch puts it at that profile's spot")
    settings.rareAlertPosition = { point = "CENTER", relPoint = "CENTER", x = 10, y = 120 }
    ns.Apply()
    ns.THEME.accent = { r = 0.5 }
    ns.CompletoSettings.Set("rareAlertGlow", true)
    Check(ns.alert.glow.sides[1].red == 0.5 and ns.alert.glow.sides[4].red == 0.5, "the glow takes the accent as it is now")
    ns.THEME.accent = {}
    ns.alert.OnClick(ns.alert, "RightButton")
    Check(not ns.alert:IsShown(), "a right-click puts it away")
    Check(not ns.alert.fade.playing, "and its fade stops")
    ns.alert:Show()
    Check(env.sounds == 1, "a sound plays")

    ns.alert:Hide()
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(not ns.alert:IsShown(), "its nameplate coming back does not alert again")
    env.Advance(301)
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(ns.alert:IsShown(), "a while later it alerts again")
    Check(holder.at[2] == 120, "where the HUD Editor put it")
    Check(env.Listening("UNIT_FLAGS"), "while it is up, its rare's tap state is watched")
    units.nameplate9 = { guid = Guid(10644, "0009"), name = "Mist Howler", kind = "rare", level = 22, denied = true }
    env.Fire("UNIT_FLAGS", "nameplate9")
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
    Check(not ns.alert.detail.text:find("Tapped", 1, true), "another of the same rare, tapped, leaves the card alone")
    units.nameplate1.denied, units.nameplate1.dead = true, true
    env.Fire("UNIT_FLAGS", "nameplate1")
    Check(not ns.alert.detail.text:find("Tapped", 1, true), "and so does its own corpse")
    units.nameplate1.dead = nil
    units.nameplate1.denied = true
    env.Fire("UNIT_FLAGS", "nameplate1")
    Check(ns.alert.detail.text:find("[warn]Tapped by someone else", 1, true),
        "someone tapping it after the card came up shows on the card")
    units.nameplate1.denied = nil
    ns.CompletoSettings.Set("rareAlertTime", 30)
    Check(ns.alert.fade.playing and ns.alert.fadeOut.delay == 30 and ns.alert.fadeIn.from == 1,
        "Stays For changed while it is up counts again from now, without fading in again")
    ns.CompletoSettings.Set("rareAlertTime", 20)
    ns.alert.fade.OnFinished(ns.alert.fade)
    Check(not ns.alert:IsShown(), "faded out, it is gone")
    Check(not env.Listening("UNIT_FLAGS"), "and its tap state is no longer watched")
    env.Advance(301)
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")

    R.SetKilled(10644, true)
    Check(not ns.alert:IsShown(), "the alert goes once its rare is killed")

    units.nameplate2 = { guid = Guid(10644, "0003"), name = "Mist Howler", kind = "rare", level = 22 }
    env.Advance(301)
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Check(not ns.alert:IsShown(), "a rare you killed does not alert")
    settings.rareAlertKilled = true
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Check(ns.alert:IsShown() and ns.alert.detail.text:find("[have]Killed before", 1, true),
        "with Alert for Killed Rares it does, saying so in the have color")

    ns.alert:Hide()
    units.nameplate3 = { guid = Guid(5555), name = "Not A Rare", kind = "normal" }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    units.nameplate4 = { guid = Guid(6666), name = "Dead Rare", kind = "rareelite", dead = true }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    units.nameplate5 = { guid = Guid(7777), name = "Friendly Rare", kind = "rare", friend = true }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
    Check(not ns.alert:IsShown(), "no alert for a normal mob, a dead rare or a friendly one")

    units.group = "raid"
    units.target = { guid = Guid(8888), name = "Raid Rare", kind = "rareelite", level = 40 }
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(ns.alert:IsShown() and ns.alert.detail.text == "Level 40" .. DOT .. "Rare elite",
        "a rare not in the data alerts too, without a kill note")
    Check(not ns.alert.pin.shown, "no pin with no spot to send a waypoint to")
    units.group = nil
    units.nameplate8 = { guid = Guid(9997), name = "Tapped Rare", kind = "rare", denied = true }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
    Check(ns.alert.name.text:find("Tapped Rare", 1, true), "a rare someone else tapped alerts")
    Check(ns.alert.detail.text:find("[warn]Tapped by someone else", 1, true), "and says it is tapped")
    ns.ShowUnlockMode()
    Check(ns.alert:IsShown() and ns.alert.name.text:find("Tapped Rare", 1, true) and mover.shown
        and env.Listening("UNIT_FLAGS"), "Unlock Mode with a real alert up places that one, still followed")
    ns.HideUnlockMode()
    Check(ns.alert:IsShown() and not mover.shown, "and leaving Unlock Mode leaves it up")
    ns.alert.OnClick(ns.alert, "RightButton")
    ns.ShowUnlockMode()
    Check(ns.alert:IsShown() and ns.alert.name.text:find("Mist Howler", 1, true) and ns.alert.mark == nil,
        "Unlock Mode previews the card with a made-up rare, and no raid mark")
    Check(mover.shown and not ns.alert.fade.playing, "with its HUD Editor plate, and it does not fade")
    Check(not env.Listening("UNIT_FLAGS"), "the preview follows no rare")
    units.nameplate10 = { guid = Guid(10644, "0010"), name = "Mist Howler", kind = "rare", level = 22, denied = true }
    env.Fire("UNIT_FLAGS", "nameplate10")
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate10")
    Check(not ns.alert.detail.text:find("Tapped", 1, true), "so a real Mist Howler does not take it over")
    ns.alert.OnClick(ns.alert, "RightButton")
    Check(mover.shown, "the plate stays when the card is put away")
    ns.HideUnlockMode()
    Check(not mover.shown and not ns.alert:IsShown(), "leaving Unlock Mode takes both away")
    ns.ShowUnlockMode()
    Check(ns.alert:IsShown(), "back in Unlock Mode, the preview shows again")

    ns.CompletoSettings.Set("rareAlert", false)
    Check(not env.Listening("NAME_PLATE_UNIT_ADDED") and not ns.alert:IsShown(), "switched off: unregistered, alert gone")
end

-- Rare Alerts: a left-click on the card targets its rare
do
    local units = {}
    local settings = { enabled = true, rareAlert = true }
    local ns, env = Fixture(settings, units)
    units.nameplate1 = { guid = Guid(10644), name = "Mist Howler", kind = "rare", level = 22 }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local alert = ns.alert
    Check(alert:IsShown() and ns.target == nil, "no secure button is made until the card is hovered")
    -- The card on screen: 300 wide and 54 high at (100, 600), its pin 24 in from its right.
    alert.GetLeft = function() return 100 end
    alert.GetRight = function() return 400 end
    alert.GetBottom = function() return 600 end
    alert.GetHeight = function() return 54 end
    alert.pin.GetLeft = function() return 376 end
    alert.OnEnter(alert)
    local target = ns.target
    Check(target and target:IsShown() and target.template == "SecureActionButtonTemplate"
        and target:GetParent() == env.UIParent, "hovering lays a secure button of its own over the card")
    Check(target.attrs.type1 == "macro" and target.attrs.macrotext1 == "/targetexact Mist Howler",
        "a left-click on it targets the rare by its exact name")
    Check(target.point == "BOTTOMLEFT" and target.at[1] == 100 and target.at[2] == 600
        and target.size[1] == 276 and target.size[2] == 54, "it covers the card up to its pin, which keeps its click")
    Check(target.textures == 0, "it draws nothing: the card looks as it did")
    Check(#env.tip == 1 and env.tip[1][1] == "Right-click to close it." and env.tipOwner == alert,
        "the card's tooltip is as it was")
    ns.CompletoSettings.Set("rareAlertSkull", true)
    alert.OnEnter(alert)
    Check(target.attrs.macrotext1 == "/cleartarget\n/targetexact Mist Howler\n/tm !8",
        "with Skull on Click it clears the target first, then targets the rare and skulls it without toggling")
    ns.CompletoSettings.Set("rareAlertSkull", false)
    alert.OnEnter(alert)
    Check(target.attrs.macrotext1 == "/targetexact Mist Howler", "with it off again it only targets")
    env.overTarget = true
    alert.OnLeave(alert)
    Check(target:IsShown() and not env.tipHidden, "the pointer going onto it from the card keeps it and the tooltip")
    target.OnLeave(target)
    env.overTarget = false
    Check(not target:IsShown() and env.tipHidden, "and leaving it takes it away")
    alert.OnEnter(alert)
    alert.OnLeave(alert)
    Check(not target:IsShown(), "so does leaving the card for its pin or off it")

    alert.OnEnter(alert)
    Check(env.Listening("PLAYER_REGEN_DISABLED"), "while it is up, it waits for combat")
    env.Fire("PLAYER_REGEN_DISABLED")
    Check(not target:IsShown() and not env.Listening("PLAYER_REGEN_DISABLED"),
        "combat starting takes it away before the lockdown, and it stops listening")
    units.combat = true
    alert.OnEnter(alert)
    alert.OnLeave(alert)
    units.nameplate2 = { guid = Guid(10647), name = "Prince Raze", kind = "rare", level = 32 }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    alert.OnClick(alert, "RightButton")
    Check(not target:IsShown() and target.combatSets == 0 and target.attrs.macrotext1 == "/targetexact Mist Howler",
        "in combat it is never shown, moved or set")
    units.combat = nil

    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    env.Advance(301)
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    alert.OnEnter(alert)
    target.PostClick(target, "LeftButton", false)
    Check(alert:IsShown() and target:IsShown(), "a left-click leaves the card up")
    target.PostClick(target, "RightButton", true)
    Check(alert:IsShown(), "a right-click's press does not close it")
    target.PostClick(target, "RightButton", false)
    Check(not alert:IsShown() and not target:IsShown(), "a right-click on it closes the card, as on the card")

    env.Advance(301)
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    alert.OnEnter(alert)
    units.nameplate3 = { guid = Guid(99999), name = "Odd\nName", kind = "rare", level = 30 }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    Check(target:IsShown() and target.attrs.macrotext1 == "/targetexact OddName",
        "a new alert under the pointer retargets it, and a name never adds a macro line")
    Check(not alert.pin.shown and target.size[1] == 300, "with no pin it covers the whole card")
    alert.fade.OnFinished(alert.fade)
    Check(not target:IsShown(), "the card fading away takes it with it")

    ns.ShowUnlockMode()
    alert.OnEnter(alert)
    Check(alert:IsShown() and alert.preview and not target:IsShown(), "the Unlock Mode preview targets nothing")
    ns.HideUnlockMode()
end

-- The card's old spot, from before the HUD Editor placed it
do
    local settings = { enabled = true, rareAlert = true, rareAlertPos = { point = "CENTER", relPoint = "CENTER",
        x = 40, y = 300 } }
    local _, env = Fixture(settings, {})
    Check(settings.rareAlertPos == nil and settings.rareAlertPosition.x == 40 and settings.rareAlertPosition.y == 300
        and settings.rareAlertPosition.point == "CENTER", "an old card spot carries over, and the old key goes")
    settings.rareAlertPosition.x = 5
    settings.rareAlertPos = nil
    env.NaowhForever.Apply()
    Check(settings.rareAlertPosition.x == 5, "once")
    settings = { enabled = true, rareAlert = true, rareAlertPos = { x = 1, y = 2 },
        rareAlertPosition = { point = "CENTER", relPoint = "CENTER", x = 7, y = 8 } }
    Fixture(settings, {})
    Check(settings.rareAlertPos == nil and settings.rareAlertPosition.x == 7, "a spot set in the HUD Editor wins")
end

-- Rare Alerts in a group, and from the minimap
do
    local units = {}
    local settings = { enabled = true, rareAlert = true, rareSound = false }
    local ns, env = Fixture(settings, units)
    units.group, units.instance = "party", true
    units.nameplate1 = { guid = Guid(10644), name = "Mist Howler", kind = "rare", level = 22 }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(ns.alert:IsShown() and ns.alert.name.text == "Mist Howler", "in a party's dungeon: the alert")
    units.instance, units.combat = nil, true
    units.nameplate2 = { guid = Guid(10647), name = "Prince Raze", kind = "rare", level = 32 }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Check(ns.alert.name.text == "Prince Raze", "in a party's fight: the alert")
    units.group, units.combat = nil, nil
    units.nameplate4 = { guid = Guid(9998), name = "Other Rare", kind = "rare" }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    Check(ns.alert.name.text == "Other Rare", "solo: the alert")
    units.nameplate5 = { guid = Guid(12037), name = "Ursol'lok", kind = "normal" }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
    Check(ns.alert.name.text ~= "Ursol'lok", "a creature the game does not call rare brings no alert")
    env.vignettes.v1 = { objectGUID = Guid(3736), name = "Darkslayer Mordenthal", atlasName = "VignetteKill" }
    env.Fire("VIGNETTE_MINIMAP_UPDATED", "v1", true)
    Check(ns.alert.name.text ~= "Darkslayer Mordenthal", "no minimap alert for a rare friendly to you")
    env.vignettes.v2 = { objectGUID = Guid(10647, "0002"), name = "Prince Raze", atlasName = "VignetteKill" }
    env.Advance(301)
    env.Fire("VIGNETTE_MINIMAP_UPDATED", "v2", true)
    Check(ns.alert.name.text == "Prince Raze", "a hostile rare on the minimap alerts")
    Check(not ns.alert.detail.text:find("Tapped", 1, true), "with no tap state to show from the minimap")
    units.nameplate11 = { guid = Guid(10647, "0011"), name = "Prince Raze", kind = "rare", level = 32, denied = true,
        friend = true }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate11")
    Check(not ns.alert.detail.text:find("Tapped", 1, true), "a copy of the rare you cannot attack is not taken for it")
    units.nameplate7 = { guid = Guid(10647, "0003"), name = "Prince Raze", kind = "rare", level = 32, denied = true,
        dead = true }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
    Check(not ns.alert.detail.text:find("Tapped", 1, true), "a corpse of the rare does not count as seeing it")
    units.nameplate6 = { guid = Guid(10647, "0002"), name = "Prince Raze", kind = "rare", level = 32, denied = true }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
    Check(ns.alert.detail.text:find("[warn]Tapped by someone else", 1, true) and ns.alert.model.unit == nil,
        "its nameplate coming up tapped shows on the card, without a second alert")
    units.nameplate6.denied = nil
    env.Fire("UNIT_FLAGS", "nameplate6")
    Check(not ns.alert.detail.text:find("Tapped", 1, true), "and back when it is free again")
    units.nameplate8 = { guid = Guid(10647, "0004"), name = "Prince Raze", kind = "rare", level = 32, denied = true }
    env.Fire("UNIT_FLAGS", "nameplate8")
    Check(not ns.alert.detail.text:find("Tapped", 1, true), "from then on it follows that creature only")
end

-- A kill is counted once per creature, a reload in between too
do
    local units = {}
    local ns, env, account = Fixture({ enabled = true }, units)
    local R = ns.Completo.Rares
    account.completoRareKills = { ["Player-1-0001"] = { [10644] = { n = 1, at = 900, guid = Guid(10644, "0007") } } }
    env.loot = { Guid(10644, "0007") }
    env.Fire("LOOT_READY")
    Check(R.Record(10644).n == 1, "a corpse counted before a reload does not count again")
    env.loot = { Guid(10644, "0008") }
    env.Fire("LOOT_READY")
    Check(R.Record(10644).n == 2, "another one of it does")
end

-- Test Alert
do
    local units = {}
    local settings = { enabled = true, rareAlert = false, rareSound = true }
    local ns, env = Fixture(settings, units)
    local test, reset
    local keys = {}
    local function Collect(rows)
        for _, row in ipairs(rows) do
            if row[1] then Collect(row) end
            if row.label == "Test Alert" then test = row.button end
            if row.label == "Reset Position" then reset = row.button end
            if row.key then keys[row.key] = row end
        end
    end
    Collect(ns.cards.rareAlert.rows)
    Check(test ~= nil, "Rare Alerts has a Test button")
    Check(keys.rareAlertTime and keys.rareAlertTime.label == "Stays For" and keys.rareAlertScale.label == "Size",
        "Stays For and Size")
    Check(keys.rareAlertFont and keys.rareAlertFontSize and keys.rareAlertOutline and keys.rareAlertBackground
        and keys.rareAlertGlow, "the house look rows, and Glow")
    Check(not keys.rareAlertPos and not keys.rareAlertPosition, "no position row: the HUD Editor places it")
    Check(reset ~= nil, "a Reset Position button")
    Check(not keys.rareMarker and ns.Completo.Marks == nil, "no Mark Rare row, and no raid mark rules")

    -- The settings preview: the card in each moment.
    local studio = ns.cards.rareAlert.studio
    local labels = {}
    for _, state in ipairs(studio.states) do labels[#labels + 1] = state.label end
    Check(table.concat(labels, ",") == "Not Killed,Killed Before,Tapped", "the preview's three moments")
    local preview = studio.new(env.UIParent)
    local DOT = "  \194\183  "
    studio.paint(preview, "new")
    Check(preview.card.name.text == "Mist Howler" and preview.card.detail.text == "Level 22" .. DOT .. "Rare" .. DOT
        .. "Not killed yet", "Not Killed: a rare you have not killed")
    Check(preview.card.mark == nil and preview.card.model.creature == 10644, "with its portrait, and no raid mark")
    preview.card.model.creature = "kept"
    studio.paint(preview, "killed")
    Check(preview.card.detail.text:find("[have]Killed before", 1, true), "Killed Before")
    Check(preview.card.model.creature == "kept", "the preview's model is not loaded again on a redraw")
    preview.card.model.creature = nil
    studio.paint(preview, "killed")
    Check(preview.card.model.creature == 10644, "a model that went missing is set again")
    preview.card.model.creature = "kept"
    preview.OnShow(preview)
    Check(preview.card.model.creature == 10644, "and the preview shown again sets it again")
    settings.rareAlertScale = 2
    studio.paint(preview, "new")
    Check(preview.card.scale * (54 + 6) <= 110 - 8 + 0.001, "at 200% the card and its glow fit the stage's height")
    settings.rareAlertScale = 1
    studio.paint(preview, "tapped")
    Check(preview.card.detail.text:find("[warn]Tapped by someone else", 1, true), "Tapped")
    Check(ns.alert == nil, "the preview is a card of its own, not the alert")
    local soundRow
    for _, row in ipairs(ns.cards.rareAlert.rows) do
        if row.key == "rareSoundKey" then soundRow = row end
    end
    local values, order = soundRow.choice()
    Check(order[1] == "file:gruntlinghorn" and values["file:gruntlinghorn"] == "Gruntling Horn (game)"
        and order[2] == "game:raidwarning", "the Gruntling Horn first, then the game's other sounds")
    Check(values["game:legendary"] == nil, "a SOUNDKIT name the client lacks is left out")
    Check(values["game:flaghorde"] == "Flag Taken, Horde (game)", "the flag sounds are offered by their kit ID")
    Check(values["file:thunder"] == nil and values["file:scourgehorn"] == nil and values["file:pvphorde"] == nil,
        "no Thunder Crack, Scourge Horn or PvP warnings")
    Check(soundRow.get() == "file:gruntlinghorn", "the Gruntling Horn by default")
    soundRow.set("file:gruntlinghorn")
    Check(env.soundFile == 598196 and env.sounds == 1, "a sound file plays by its ID")
    env.soundFile = nil
    soundRow.set("game:flaghorde")
    Check(env.sounds == 2 and env.soundFile == nil, "a flag sound plays by its kit ID")
    env.soundFile = nil
    soundRow.set("file:pvphorde")
    Check(env.soundFile == 598196, "a sound no longer offered falls back to the Gruntling Horn")
    env.sounds = 0
    settings.rareSoundKey = nil
    Check(values["voice:move-out"] == nil and values["lsm:BugSack: Fatality"] == nil and values["lsm:Bell"] == "Bell"
        and order[#order] == "lsm:Bell", "no spoken lines or BugSack's sound; the addon's other sounds stay")
    soundRow.set("game:raidwarning")
    Check(env.sounds == 1 and settings.rareSoundKey == "game:raidwarning", "picking a sound plays it")
    env.sounds = 0
    test()
    Check(ns.alert:IsShown() and ns.alert.name.text:find("Mist Howler", 1, true), "with nothing targeted, a made-up rare")
    Check(not env.Listening("UNIT_FLAGS"), "with Rare Alerts off, the test card follows no rare")
    local holder = ns.alert:GetParent()
    settings.rareAlertPosition = { point = "CENTER", relPoint = "CENTER", x = 80, y = -40 }
    ns.Apply()
    Check(holder.at[1] == 80, "placed where the HUD Editor put it")
    reset()
    Check(settings.rareAlertPosition == nil and holder.at[1] == 0 and holder.at[2] == 260,
        "Reset Position puts it back above the middle of the screen")
    Check(env.sounds == 1, "with its sound")
    units.target = { guid = Guid(5555), name = "Kobold Miner", level = 7 }
    test()
    Check(ns.alert.name.text:find("Kobold Miner", 1, true) and ns.alert.model.unit == "target",
        "with a hostile target, about it")
    units.target.friend = true
    test()
    Check(ns.alert.name.text:find("Mist Howler", 1, true), "a friendly target is not taken: a made-up rare")
end

-- Raid marks are Blizzard-only on Forever: no rare path sets one
do
    local units = {}
    local settings = { enabled = true, rareAlert = true, rareMarker = "skull", rareSound = true }
    local ns, env = Fixture(settings, units)
    env.UnitIsGroupLeader = function() return true end
    units.group = "raid"
    units.nameplate1 = { guid = Guid(10644), name = "Mist Howler", kind = "rare", level = 22 }
    env.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(ns.alert:IsShown() and ns.alert.name.text == "Mist Howler", "a nameplate alerts, as a raid's leader too")
    units.group = nil
    units.mouseover = { guid = Guid(10647), name = "Prince Raze", kind = "rare", level = 32 }
    env.Fire("UPDATE_MOUSEOVER_UNIT")
    Check(ns.alert.name.text == "Prince Raze" and ns.alert.model.unit == "mouseover", "a mouseover alerts")
    units.target = { guid = Guid(9999), name = "Target Rare", kind = "rareelite", level = 40 }
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(ns.alert.name.text == "Target Rare" and ns.alert.model.unit == "target", "a target alerts")
    env.vignettes.v1 = { objectGUID = Guid(12037), name = "Ursol'lok", atlasName = "VignetteKill" }
    env.Fire("VIGNETTE_MINIMAP_UPDATED", "v1", true)
    Check(ns.alert.name.text == "Ursol'lok", "the minimap alerts")
    local test
    for _, row in ipairs(ns.cards.rareAlert.rows) do
        if row.label == "Test Alert" then test = row.button end
    end
    test()
    Check(ns.alert.name.text == "Target Rare", "Test Alert is about the target")
    units.target = nil
    test()
    Check(ns.alert.name.text == "Mist Howler", "and a made-up rare with nothing targeted")
    ns.alert.OnClick(ns.alert, "RightButton")
    ns.ShowUnlockMode()
    Check(ns.alert:IsShown() and ns.alert.preview, "Unlock Mode previews the card")
    ns.HideUnlockMode()
    local studio = ns.cards.rareAlert.studio
    local preview = studio.new(env.UIParent)
    for _, state in ipairs(studio.states) do studio.paint(preview, state.key) end
    Check(preview.card.mark == nil and ns.alert.mark == nil, "neither card has a raid mark")
    Check(env.restricted == 0, "and nothing called SetRaidTarget or another Blizzard-only marker call")
    Check(settings.rareMarker == "skull", "an old Mark Rare choice stays in the saved settings, unused")
end

-- Map Pins
do
    local units = {}
    local settings = { enabled = true, rarePins = false, rarePinsKilled = false, rarePinSize = 18 }
    local ns, env = Fixture(settings, units)
    local R = ns.Completo.Rares
    Check(env.provider == nil, "no map provider while Map Pins is off")
    Check(not ns.cards.rarePins, "no Map Pins card of its own on the Rares page")
    local section = ns.Shared.MapPins[1]
    Check(section and section.title == "Rares" and section.rows[1].key == "rarePins"
        and section.rows[1].store == ns.CompletoSettings and section.rows[1].always,
        "its switch is a row on QoL's Map Pins, in Completo's store")
    ns.CompletoSettings.Set("rarePins", true)
    local pins = env.worldMap.pins
    Check(#pins == 2, "one star each for Mist Howler and Prince Raze; none for the Horde-friendly rare or one "
        .. "with no spot")
    local function PinsOf(npc, kind)
        local out = {}
        for _, pin in ipairs(env.worldMap.pins) do
            if pin.npc == npc and (kind == nil or pin.kind == (kind or nil)) then out[#out + 1] = pin end
        end
        return out
    end
    local howler = PinsOf(10644)[1]
    Check(howler.Icon.atlas == "VignetteKill" and howler.at[1] == 0.5 and howler.at[2] == 0.4,
        "the game's rare star, at its first spot (where it was seen most)")
    howler:OnMouseEnter()
    local other = PinsOf(10644, "spot")[1]
    Check(#PinsOf(10644, "spot") == 1 and other.at[1] == 0.52 and other.size < howler.size and not other.mouse,
        "hovering it shows its other spot, smaller, taking no mouse")
    howler:OnMouseLeave()
    Check(#PinsOf(10644) == 1, "moving off takes the other spot away")
    local star = PinsOf(10647, false)[1]
    star:OnMouseEnter()
    Check(#env.worldMap.pins == 5 and #PinsOf(10647, "dot") == 3, "hovering a patrolling rare's star shows its way's three dots")
    local dot = PinsOf(10647, "dot")[1]
    Check(dot.size < star.size and dot.levelIndex < star.levelIndex and not dot.mouse,
        "a trail's dots are smaller, under the star and take no mouse")
    Check(star.size > 18 and howler.Icon.alpha < 0.5, "the hovered rare's star is lit, the others faded")
    local function Line(find)
        for _, line in ipairs(env.tip) do
            if tostring(line[1]):find(find, 1, true) then return line end
        end
    end
    local talon = Line("Talon of Vultros")
    Check(Line("Drops") and talon and talon[1] == "|T5454:14:14|t Talon of Vultros" and talon[2] == "22%"
        and talon[5] == 0.87, "its tooltip lists its loot: icon, name in its quality's color, chance")
    Check(Line("Pattern: Feathered Cape")[2] == "0.4%", "a rare chance keeps its decimal")
    Check(Line("And 3 more"), "and says how many more")
    Check(Line("Signet of the Zhevra <inf>") and not Line("Talon of Vultros <inf>"),
        "Forever's sign on a drop new in Forever, none on the others")
    star:OnMouseLeave()
    howler:OnMouseEnter()
    Check(not Line("Drops"), "a rare with nothing special has no Drops section")
    local last = env.tip[#env.tip]
    Check(last[1] == "Click for a waypoint, right-click to keep its spots shown." and Line(" ") ~= nil,
        "its tooltip ends with one hint line")
    Check(Line("Spawns at 1 more spots")[3] == 0.66,
        "its notes in the muted color")
    howler:OnMouseLeave()
    Check(#env.worldMap.pins == 2 and #PinsOf(10647, "dot") == 0, "moving off the star takes its way away")
    Check(star.size == 18 and howler.Icon.alpha == 1, "and puts the others back")
    star:OnClick("LeftButton")
    Check(#env.waypoints == 1 and env.waypoints[1][3] == 70, "clicking a star sets a waypoint there")
    Check(ns.mapPanel == nil and #PinsOf(10647, "dot") == 0, "and focuses nothing")
    star:OnClick("RightButton")
    star:OnMouseLeave()
    Check(#PinsOf(10647, "dot") == 3 and howler.Icon.alpha < 0.5 and #env.waypoints == 1,
        "right-clicking a star focuses its rare: its way stays and the others stay faded after the pointer leaves")
    Check(ns.mapPanel == nil, "and no panel comes up")
    star:OnMouseEnter()
    Check(env.tip[#env.tip][1] == "Click for a waypoint, right-click to let go.", "hovered, the focused star has its tooltip")
    star:OnClick("RightButton")
    Check(#PinsOf(10647, "dot") == 0 and howler.Icon.alpha == 1 and star.size == 18,
        "right-clicked again, every star is back at once, while the pointer is still on it")
    Check(env.tip[#env.tip][1] == "Click for a waypoint, right-click to keep its spots shown.", "its tooltip stays")
    star:OnMouseLeave()
    Check(#PinsOf(10647, "dot") == 0 and howler.Icon.alpha == 1, "and moving off changes nothing")
    star:OnClick("RightButton")
    star:OnMouseLeave()
    howler:OnMouseEnter()
    Check(#PinsOf(10647, "dot") == 0 and #PinsOf(10644, "spot") == 1, "hovering another rare shows that one meanwhile")
    howler:OnMouseLeave()
    Check(#PinsOf(10647, "dot") == 3 and #PinsOf(10644, "spot") == 0, "and leaving it goes back to the focused one")
    env.provider:RefreshAllData()
    Check(#PinsOf(10647, "dot") == 3, "a redraw keeps the focus")
    star = PinsOf(10647, false)[1]
    star:OnClick("RightButton")
    star:OnMouseLeave()
    howler = PinsOf(10644)[1]
    Check(#PinsOf(10647, "dot") == 0 and howler.Icon.alpha == 1, "right-clicking it again lets go")
    R.SetKilled(10644, true)
    Check(#PinsOf(10644) == 0 and #env.worldMap.pins == 1, "a killed rare's star goes")
    ns.CompletoSettings.Set("rarePinsKilled", true)
    Check(#PinsOf(10644) == 1 and PinsOf(10644)[1].Icon.desaturated, "with Show Killed Rares, a grey star")
    ns.CompletoSettings.Set("rarePins", false)
    Check(#env.worldMap.pins == 0, "switched off: the stars go")
end

print(("test-completo-rares: %d checks passed"):format(checks))
