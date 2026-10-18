-- Offline checks for Glimmer: reading the soft target, skill-up colors, the game settings saved and put
-- back, combat, and the nameplate it opens, against stubs of the game's API. Run from the repo root:
-- lua Tools/regression/test-glimmer.lua
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local FILES = dofile("Tools/regression/toc_files.lua")("^NaowhForever_QoL/Glimmer/.*%.lua$")
table.insert(FILES, 1, "Core/Features.lua")
table.insert(FILES, 2, "Shared/UI/MinimapPins.lua")

local SHARED = {}
dofile("Tools/regression/load_files.lua")({ "Shared/Style.lua", "Shared/Data/SameMaps.lua", "Shared/Game/Places.lua" }, { _G = { NaowhForever = {
    L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Shared = SHARED } } })

local COPPER, TIN, CHEST, BOBBER = 1731, 1732, 2843, 35591
local function GUID(id) return "GameObject-0-1-2-3-" .. id .. "-0000ABCDEF" end

local function Widget(log)
    local w = { shown = true, events = {}, points = 0 }
    setmetatable(w, { __index = function(_, k)
        if k:match("^%u") then return function() end end
    end })
    function w:RegisterEvent(e) self.events[e] = true end
    function w:UnregisterEvent(e) self.events[e] = nil end
    function w:UnregisterAllEvents() self.events = {} end
    function w:SetScript(kind, fn) self[kind] = fn end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:IsShown() return self.shown end
    function w:SetParent(p) self.parent = p end
    function w:SetAlpha(a) self.alpha = a end
    function w:GetFrameLevel() return 5 end
    function w:SetText(t) self.text = t end
    function w:SetTextColor(r, g, b) self.textColor = { r, g, b } end
    function w:CreateTexture() return Widget(log) end
    function w:GetTexture() return self.texture end
    function w:SetTexture(t) self.texture = t end
    function w:SetPoint(...) self.point = { ... } end
    function w:SetVertexColor(r, g, b) self.color = { r, g, b } end
    function w:GetWidth() return 140 end
    function w:GetEffectiveScale() return 1 end
    function w:CreateMaskTexture() return Widget(log) end
    function w:AddMaskTexture(m) self.mask = m end
    function w:RemoveMaskTexture(m) if self.mask == m then self.mask = nil end end
    function w:GetHeight() return 140 end
    log.frames[#log.frames + 1] = w
    return w
end

local function Session(settings, opts)
    opts = opts or {}
    local log = { frames = {}, writes = {}, timers = {}, confirms = {}, reloads = {}, printed = {} }
    local cvars = {
        SoftTargetInteract = "1", SoftTargetInteractOnlyInRange = "1", SoftTargetInteractRange = "10",
        SoftTargetInteractArc = "1", SoftTargetNameplateInteract = "0", SoftTargetIconGameObject = "0",
        outlineModeShowLootEffectWhenDisabled = "0", graphicsOutlineMode = "2", OutlineEngineMode = "2",
        raidGraphicsOutlineMode = "2", RAIDOutlineEngineMode = "2",
    }
    log.cvars = cvars
    local game = { combat = false, instance = false, guid = nil, object = true, near = false, related = false,
        tooltip = nil, plate = nil, mining = 70, herbalism = 0, loaded = opts.loaded or {}, px = 0.5, py = 0.5,
        pins = {} }
    log.game = game
    local account = {}
    log.account = account
    local hooks = {}
    local S = {}
    local ns = {
        L = dofile("Tools/regression/locale_stub.lua").L, Shared = SHARED, THEME = { muted = {} },
        UI = { ModuleSettings = function(_, defaults)
            function S.Get(k) local v = settings[k]; if v == nil then return defaults[k] end; return v end
            function S.Set(k, v) settings[k] = v end
            function S.Raw(k) return settings[k] end
            return S
        end },
    }
    SHARED.Parts = { HudText = function(fs) return fs end }
    SHARED.MapPins = {}
    SHARED.Ago = function() return "today" end
    SHARED.ScalePin = function() end
    function ns.PlaceWaypoint(title, map, x, y) log.waypoint = { title, map, x, y } end
    function ns.Apply() end
    function ns.AccountSettings() return account end
    function ns.Font() return Widget(log) end
    function ns.Print(text) log.printed[#log.printed + 1] = text end
    function ns.Confirm(text, onYes) log.confirms[#log.confirms + 1] = { text = text, yes = onYes } end
    function ns.ConfirmReload(text) log.reloads[#log.reloads + 1] = text end

    local env = setmetatable({
        _G = { NaowhForever = ns },
        CreateFrame = function() return Widget(log) end,
        UIParent = Widget(log),
        hooksecurefunc = function(t, name, fn)
            local orig = t[name]
            t[name] = function(...) local a, b, c = orig(...); fn(...); return a, b, c end
            hooks[#hooks + 1] = name
        end,
        C_CVar = {
            GetCVar = function(name) return cvars[name] end,
            GetCVarBool = function(name) return cvars[name] == "1" end,
            SetCVar = function(name, value)
                assert(not game.combat, "a game setting was changed in combat: " .. name)
                cvars[name] = value
                log.writes[#log.writes + 1] = name
            end,
        },
        C_Timer = { After = function(_, fn) log.timers[#log.timers + 1] = fn end },
        C_NamePlate = { GetNamePlateForUnit = function() return game.plate end },
        C_QuestLog = { UnitIsRelatedToActiveQuest = function() return game.related end },
        C_TooltipInfo = { GetUnit = function() return game.tooltip end },
        C_AddOns = {
            IsAddOnLoaded = function(name) return game.loaded[name] and true or false end,
            GetAddOnInfo = function(name) return name, name end,
            DisableAddOn = function(name) game.loaded[name] = nil; log.disabled = name end,
        },
        C_EncodingUtil = {
            DecodeBase64 = function(s) return s end,
            DecompressString = function(s) return s end,
            DeserializeCBOR = function(s)
                log.dataLoaded = s
                return { 1429, { 1731, 500, 520, 1618, 510, 500, 1732, 900, 900 } }
            end,
        },
        Enum = { TooltipDataLineType = { QuestObjective = 8 }, CompressionMethod = { Deflate = 0 } },
        UnitGUID = function() return game.guid end,
        UnitIsGameObject = function() return game.guid ~= nil and game.object end,
        UnitIsInInteractRange = function() return game.near end,
        UnitIsUnit = function(unit) return unit ~= "nameplate9" end,
        GetNumLootItems = function() return 1 end,
        GetLootSourceInfo = function() return game.lootFrom or game.guid end,
        SetUnitCursorTexture = function(texture, _, _, lowPriority)
            local cursor = game.cursor
            if game.cursorLow and not lowPriority then cursor = nil end
            texture.texture = cursor
            return cursor ~= nil
        end,
        GetFileIDFromPath = function() return nil end,
        GetProfessions = function() return 1, game.herbalism > 0 and 2 or nil end,
        GetProfessionInfo = function(i)
            if i == 2 then return "Herbalism", 0, game.herbalism, 300, 0, 0, 182 end
            return "Mining", 0, game.mining, 300, 0, 0, 186
        end,
        InCombatLockdown = function() return game.combat end,
        IsInInstance = function() return game.instance end,
        GetTime = function() return log.now or 0 end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        time = function() return 1000 end,
        CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(v) return v.x, v.y end } end,
        C_Map = {
            GetBestMapForUnit = function() return 1429 end,
            GetPlayerMapPosition = function() return { GetXY = function() return game.px, game.py end } end,
            GetWorldPosFromMapPos = function(_, v)
                return 0, { GetXY = function() return v.x * 1000, v.y * 1000 end }
            end,
            GetMapWorldSize = function() return 1000, 1000 end,
        },
        C_Minimap = {
            GetViewRadius = function() return 100 end,
            GetNumTrackingTypes = function() return 2 end,
            GetTrackingInfo = function(i)
                local spell = i == 1 and 2580 or 2383
                return { spellID = spell, active = game.tracking == spell }
            end,
        },
        C_Spell = { GetSpellTexture = function(id) return "spell" .. id end },
        UnitPosition = function() return game.px * 1000, game.py * 1000, 0, 0 end,
        GetPlayerFacing = function() return 0 end,
        IsPlayerMoving = function() return false end,
        Minimap = Widget(log),
        CreateFromMixins = function(...)
            local t = {}
            for _, m in ipairs({ ... }) do for k, v in pairs(m) do t[k] = v end end
            return t
        end,
        MapCanvasDataProviderMixin = {},
        MapCanvasPinMixin = {},
        WorldMapFrame = {
            AddDataProvider = function(_, p)
                log.provider = p
                p.GetMap = function() return {
                    GetMapID = function() return 1429 end,
                    RemoveAllPinsByTemplate = function() for k in pairs(game.pins) do game.pins[k] = nil end end,
                    AcquirePin = function(_, _, entry) game.pins[#game.pins + 1] = entry end,
                } end
            end,
            IsShown = function() return game.mapShown end,
        },
    }, { __index = _G })
    dofile("Tools/regression/load_files.lua")(FILES, env)
    log.ns, log.env, log.S = ns, env, S
    function log.Fire(event, ...)
        for _, f in ipairs(log.frames) do
            if f.events[event] and rawget(f, "OnEvent") then f.OnEvent(f, event, ...) end
        end
    end
    function log.RunTimers()
        local timers = log.timers
        log.timers = {}
        for _, fn in ipairs(timers) do fn() end
    end
    function log.Login()
        for _, f in ipairs(log.frames) do
            if f.events.PLAYER_LOGIN and rawget(f, "OnEvent") then f.OnEvent(f, "PLAYER_LOGIN") end
        end
    end
    function log.Set(k, v)
        S.Set(k, v)
        log.RunTimers()
    end
    return log
end

local function Registered(log)
    local n = 0
    for _, f in ipairs(log.frames) do
        for event in pairs(f.events) do
            if event ~= "PLAYER_LOGIN" then n = n + 1 end
        end
    end
    return n
end

local function Lit(log)
    for _, f in ipairs(log.frames) do
        if f.glints and f.shown and f.parent == log.game.plate and log.game.plate then return f end
    end
end

local function LineText(log)
    local fx = Lit(log)
    if not fx then return end
    for _, f in ipairs(log.frames) do
        if f.text and f.shown ~= false and f ~= fx then return f.text end
    end
end

-- Off by default: nothing changes, nothing listens.
do
    local log = Session({})
    log.Login()
    check("off by default", log.ns.Glimmer.On() == false)
    check("off: no game setting written", #log.writes == 0)
    check("off: no event but the login check", Registered(log) == 0)
end

-- Quest givers used to be part of Quest Objects: a profile without its own giver settings takes the
-- quest ones, once, and a profile switched to later gets the same.
do
    local settings = { quest = false, questStyle = "ring", questColor = { r = 0.1, g = 0.2, b = 0.3 } }
    local log = Session(settings)
    log.ns.Apply()
    check("quest objects off: quest givers stay off", settings.giver == false)
    check("and keep the quest effect", settings.giverStyle == "ring")
    check("and the quest color, as a copy", settings.giverColor ~= settings.questColor
        and settings.giverColor.r == 0.1 and settings.giverColor.g == 0.2 and settings.giverColor.b == 0.3)
    log.S.Set("giver", true)
    log.S.Set("giverStyle", "beam")
    log.ns.Apply()
    check("only once: givers turned back on stay on", settings.giver == true and settings.giverStyle == "beam")

    for k in pairs(settings) do settings[k] = nil end
    settings.quest, settings.giverStyle = true, "glow"
    log.ns.Apply()
    check("another profile: givers follow quest objects", settings.giver == true)
    check("a giver effect already picked is kept", settings.giverStyle == "glow" and settings.giverColor == nil)
end

-- Every effect draws, in reach and out, through its flash.
do
    local e = Session({})
    local G = e.ns.Glimmer
    local fx = G.Effects.New(Widget(e))
    for _, style in ipairs({ "glow", "sparkles", "ring", "beam", "brackets" }) do
        G.Effects.Set(fx, style, G.Style.TIER_RGB.orange, 1, 1, false, false)
        G.Effects.Start(fx)
        for _ = 1, 30 do fx.OnUpdate(fx, 0.05) end
        G.Effects.Set(fx, style, G.Style.TIER_RGB.orange, 1, 1, true, false)
        check(style .. ": reaching it flashes", fx.burstAge == 0)
        for _ = 1, 30 do fx.OnUpdate(fx, 0.05) end
        check(style .. ": the flash ends and it is bright", fx.burstAge == nil and fx.lock == 1 and fx.appear == 1)
    end
end

-- Skill-up colors.
do
    local Tier = Session({}).ns.Glimmer.Target.Tier
    check("below the node's skill is red", Tier(64, 65) == "red")
    check("at it, orange", Tier(65, 65) == "orange" and Tier(89, 65) == "orange")
    check("25 over, yellow", Tier(90, 65) == "yellow" and Tier(114, 65) == "yellow")
    check("50 over, green", Tier(115, 65) == "green" and Tier(164, 65) == "green")
    check("100 over, grey", Tier(165, 65) == "grey")
end

-- Turned on: the soft target settings are saved, then set.
local log = Session({ enabled = true })
log.Login()
local cv = log.cvars
check("on: the soft target is kept on", cv.SoftTargetInteract == "3" and cv.SoftTargetInteractOnlyInRange == "0")
check("on: range and direction from the settings", cv.SoftTargetInteractRange == "15" and cv.SoftTargetInteractArc == "2")
check("on: the old values are saved", log.account.glimmerSoftCVars.SoftTargetInteract == "1"
    and log.account.glimmerSoftCVars.SoftTargetInteractRange == "10")
check("on: objects get their nameplate", cv.SoftTargetIconGameObject == "1"
    and log.account.glimmerSoftCVars.SoftTargetIconGameObject == "0")
check("on: the quest sparkle is left alone", cv.graphicsOutlineMode == "2" and log.account.glimmerSparkleCVars == nil)
check("on: no target, no nameplate opened", cv.SoftTargetNameplateInteract == "0")

-- A copper vein a little way off.
log.game.guid = GUID(COPPER)
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "x")
check("a vein opens the nameplate", cv.SoftTargetNameplateInteract == "1")
check("nothing lit before the nameplate comes", Lit(log) == nil)
log.game.plate = Widget(log)
log.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
local fx = Lit(log)
check("lit on the nameplate once it comes", fx ~= nil and fx.style == "sparkles")
check("out of reach first", fx.ready == false)
local St = log.ns.Glimmer.Style
check("70 Mining on Copper is green", fx.r == St.TIER_RGB.green.r and fx.g == St.TIER_RGB.green.g)
check("and says so under the name", LineText(log) == "Skill-up unlikely")

-- Walking into reach: it waits for the answer to hold, then brightens.
log.game.near = true
local Watch
for _, f in ipairs(log.frames) do if rawget(f, "OnUpdate") and not f.glints and f.shown then Watch = f end end
log.now = 1
Watch.OnUpdate(Watch, 0.2)
check("in reach: not before the answer holds", fx.ready == false)
log.now = 1.3
Watch.OnUpdate(Watch, 0.2)
check("in reach: then bright, with the flash", fx.ready == true and fx.burstAge == 0)

-- Too low for tin.
log.game.guid, log.game.mining = GUID(TIN), 20
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "x", "y")
fx = Lit(log)
check("too low: grey and locked", fx and fx.locked == true and fx.r == St.LOCKED_RGB.r)
check("too low: the skill it needs", LineText(log) == "Requires Mining 65")
log.Set("hideLocked", true)
check("too low and hidden: dark", Lit(log) == nil)
log.Set("hideLocked", false)

-- No Mining at all: grey, like a node the skill is too low for.
log.game.mining = 0
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "x", "y")
fx = Lit(log)
check("no Mining: grey and locked", fx and fx.locked == true and fx.r == St.LOCKED_RGB.r)
check("no Mining: the skill it needs", LineText(log) == "Requires Mining 65")
log.Set("hideLocked", true)
check("no Mining and hidden: dark", Lit(log) == nil)
log.Set("hideLocked", false)
log.game.mining = 70
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "x", "y")
check("Mining learned: ore lights in its color", Lit(log) and Lit(log).locked == false)

-- A vein missing from the node data, known only by its cursor: grey without Mining too.
log.game.guid, log.game.cursor, log.game.mining = GUID(999999), "Interface\\Cursor\\Mine", 0
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "x", "y")
fx = Lit(log)
check("unlisted vein, no Mining: grey and locked", fx and fx.locked == true and fx.r == St.LOCKED_RGB.r)
log.game.guid, log.game.cursor, log.game.mining = GUID(TIN), nil, 70

-- An NPC: no nameplate opened for it.
log.game.guid, log.game.object = "Creature-0-1-2-3-4-5", false
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "y", "z")
check("an NPC closes the nameplate", cv.SoftTargetNameplateInteract == "0" and Lit(log) == nil)
log.game.cursor, log.game.cursorLow = "Cursor Crosshair_QuestTurnIn_64", true
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "z", "y")
check("a quest giver with a quest to hand in lights up, though the game only gives its cursor as low priority",
    Lit(log) ~= nil)
log.game.cursor = "Interface\\Cursor\\Quest"
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "y", "z")
check("and one with a quest to pick up", Lit(log) ~= nil)
local unitFrame = { HealthBarsContainer = Widget(log), LevelFrame = Widget(log), PlayerLevelDiffFrame = Widget(log) }
log.game.plate.UnitFrame = unitFrame
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "z", "y")
check("a quest giver's plate keeps its bar and level by default",
    unitFrame.HealthBarsContainer.alpha == nil and unitFrame.LevelFrame.alpha == nil
    and unitFrame.PlayerLevelDiffFrame.alpha == nil)
check("and the effect sits at the usual height", Lit(log).point[5] == -40)
log.Set("giverHideBar", true)
check("Hide Health Bar and Level: the bar and both level frames go, the name stays",
    unitFrame.HealthBarsContainer.alpha == 0 and unitFrame.LevelFrame.alpha == 0
    and unitFrame.PlayerLevelDiffFrame.alpha == 0)
log.Set("giverOffset", 30)
check("a quest giver's effect moves by its own height", Lit(log).point[5] == -10)
log.game.guid, log.game.object, log.game.cursor = GUID(COPPER), true, nil
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "y", "z")
check("the plate gets its bar back when it stops being a quest giver's",
    unitFrame.HealthBarsContainer.alpha == 1 and unitFrame.LevelFrame.alpha == 1
    and unitFrame.PlayerLevelDiffFrame.alpha == 1)
check("and an object's effect keeps the usual height", Lit(log).point[5] == -40)
log.Set("giverHideBar", false)
log.Set("giverOffset", 0)
log.game.guid, log.game.object, log.game.cursor = "Creature-0-1-2-3-4-5", false, "Interface\\Cursor\\Quest"
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "z", "y")
log.Set("giver", false)
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "z", "y")
check("quest givers switched off: dark, and no nameplate opened", cv.SoftTargetNameplateInteract == "0" and Lit(log) == nil)
log.Set("giver", true)
log.game.cursor, log.game.cursorLow = nil, nil
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "z", "y")
check("an NPC with no quest stays dark", Lit(log) == nil)
log.game.object = true

-- Chests and the bobber come from their IDs; a switched off category stays dark.
log.game.guid = GUID(CHEST)
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "z", "a")
check("a chest lights up", Lit(log) ~= nil and LineText(log) == nil)
log.Set("chest", false)
check("chests off: dark", Lit(log) == nil and cv.SoftTargetNameplateInteract == "0")
log.game.guid = GUID(BOBBER)
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "a", "b")
check("the bobber lights up", Lit(log) ~= nil)

-- A quest object: its objective line from the tooltip.
log.game.guid, log.game.related = GUID(999999), true
log.game.tooltip = { lines = { { type = 1, leftText = "Supply Crate" }, { type = 8, leftText = "Supplies: 1/4" } } }
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "b", "c")
check("a quest object shows what is still needed", Lit(log) ~= nil and LineText(log) == "Supplies: 1/4")
log.Set("giver", false)
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "z", "y")
check("quest objects stay lit with quest givers off", Lit(log) ~= nil)
log.Set("giver", true)
log.game.related = false

-- The game does not call it quest related, but its tooltip lists the objective: still a quest object,
-- in the effect picked for quest objects.
log.Set("questStyle", "beam")
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "c", "d")
local questFx = Lit(log)
check("the objective line alone makes it a quest object", questFx ~= nil and LineText(log) == "Supplies: 1/4")
check("in the effect picked for quest objects", questFx and questFx.style == "beam")
log.Set("questStyle", "same")
log.game.tooltip = nil

-- A quest finished and ready to hand in at an object: no objective left, but the game's turn-in cursor.
log.game.cursor = "Interface\\Cursor\\QuestTurnIn"
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "d", "e")
check("a quest turn-in object lights up from its cursor", Lit(log) ~= nil and LineText(log) == nil)
log.game.cursor = nil
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "e", "f")
check("without the cursor, objective or quest link it stays dark", Lit(log) == nil)

-- Combat: the nameplate is closed before the lockdown, and settings wait for the fight to end.
log.game.guid = GUID(COPPER)
log.Fire("PLAYER_SOFT_INTERACT_CHANGED", "c", "d")
check("lit before the fight", Lit(log) ~= nil)
log.Fire("PLAYER_REGEN_DISABLED")
check("the fight closes the nameplate and rests", cv.SoftTargetNameplateInteract == "0" and Lit(log) == nil)
log.game.combat = true
log.Set("range", 10)
check("a setting in combat waits", cv.SoftTargetInteractRange == "15")
log.game.combat = false
log.Fire("PLAYER_REGEN_ENABLED")
check("and lands after it", cv.SoftTargetInteractRange == "10" and Lit(log) ~= nil)

-- Dungeons.
log.game.instance = true
log.Fire("PLAYER_ENTERING_WORLD")
check("rests in a dungeon", Lit(log) == nil)
log.game.instance = false
log.Fire("PLAYER_ENTERING_WORLD")

-- The quest sparkle: saved, set, and put back after a graphics preset.
log.Set("questSparkle", true)
check("sparkle on: outline off, loot effect on", cv.graphicsOutlineMode == "0"
    and cv.outlineModeShowLootEffectWhenDisabled == "1")
check("sparkle on: the old values are saved", log.account.glimmerSparkleCVars.graphicsOutlineMode == "2")
cv.graphicsOutlineMode = "2"
log.Fire("CVAR_UPDATE", "graphicsQuality", "5")
check("a preset is undone only after it has finished", cv.graphicsOutlineMode == "2")
log.RunTimers()
check("then the sparkle is back", cv.graphicsOutlineMode == "0")
log.Set("questSparkle", false)
check("sparkle off: the old values come back", cv.graphicsOutlineMode == "2" and log.account.glimmerSparkleCVars == nil)

-- Off again: everything put back, nothing listening.
log.Set("enabled", false)
check("off: the soft target settings come back", cv.SoftTargetInteract == "1" and cv.SoftTargetInteractRange == "10"
    and cv.SoftTargetInteractOnlyInRange == "1" and cv.SoftTargetIconGameObject == "0"
    and log.account.glimmerSoftCVars == nil)
check("off: dark", Lit(log) == nil)
check("off: no event left", Registered(log) == 0)

-- Restore puts back both sets and turns both switches off.
do
    local r = Session({ enabled = true, questSparkle = true })
    r.Login()
    check("restore: both sets were changed", r.cvars.SoftTargetInteract == "3" and r.cvars.graphicsOutlineMode == "0")
    r.ns.Glimmer.CVars.RestoreAll()
    r.RunTimers()
    check("restore: both sets put back", r.cvars.SoftTargetInteract == "1" and r.cvars.graphicsOutlineMode == "2")
    check("restore: Glimmer and the sparkle off", r.S.Get("enabled") == false and r.S.Get("questSparkle") == false)
end

-- Saved before SoftTargetIconGameObject was one of the settings: it is saved too, and put back.
do
    local o = Session({ enabled = true })
    o.account.glimmerSoftCVars = { SoftTargetInteract = "1", SoftTargetInteractRange = "10" }
    o.Login()
    check("old save: the new setting is saved on top", o.account.glimmerSoftCVars.SoftTargetIconGameObject == "0"
        and o.account.glimmerSoftCVars.SoftTargetInteract == "1" and o.cvars.SoftTargetIconGameObject == "1")
    o.Set("enabled", false)
    check("old save: and put back", o.cvars.SoftTargetIconGameObject == "0" and o.account.glimmerSoftCVars == nil)
end

-- Other addons on the same settings: asked once, then the reload prompt.
do
    local loaded = {}
    for _, addon in ipairs(Session({}).ns.Glimmer.C.OTHER_ADDONS) do loaded[addon] = true end
    local c = Session({ enabled = true }, { loaded = loaded })
    c.Login()
    check("every other one named in one question", #c.confirms == 1
        and select(2, c.confirms[1].text:gsub(" and ", "")) >= 1)
    c.Set("size", 1.2)
    check("asked once a session", #c.confirms == 1)
    c.confirms[1].yes()
    check("yes: disabled, then the house reload prompt", next(c.game.loaded) == nil and #c.reloads == 1)
end

-- Minimap icons: off until switched on, then the data loads and the spots near you show.
do
    local m = Session({ enabled = true })
    m.Login()
    check("map features off: the spot data is not loaded", m.dataLoaded == nil)
    m.Set("minimapIcons", true)
    check("minimap icons on: the packed spots are unpacked, once, and let go", type(m.dataLoaded) == "string"
        and #m.dataLoaded > 0 and m.ns.GlimmerSpotsPacked == nil and m.ns.GlimmerSpots[1429] ~= nil)
    local shown = {}
    for _, f in ipairs(m.frames) do
        if f.ring and f.shown and f.id then shown[#shown + 1] = f end
    end
    check("a miner sees the near vein, not the herb or the far vein", #shown == 1 and shown[1].id == 1731)
    check("ringed in its skill-up color", shown[1].ring.color[1] == m.ns.Glimmer.Style.TIER_RGB.green.r)
    check("placed toward its spot", shown[1].point[4] == 0 and shown[1].point[5] < 0)
    m.game.herbalism = 50
    m.Fire("SKILL_LINES_CHANGED")
    local n = 0
    for _, f in ipairs(m.frames) do if f.ring and f.shown and f.id then n = n + 1 end end
    check("an herbalist and miner sees both", n == 2)
end

-- Only My Professions: a character with neither gathering profession sees no spots; switched off, all of them.
do
    local m = Session({ enabled = true, minimapIcons = true })
    m.game.mining = 0
    m.Login()
    local function Shown()
        local n = 0
        for _, f in ipairs(m.frames) do if f.ring and f.shown and f.id then n = n + 1 end end
        return n
    end
    check("no herbalism or mining: no spots, and the spot data stays packed", Shown() == 0 and m.dataLoaded == nil)
    m.Set("myProfessions", false)
    check("Only My Professions off: every near spot", Shown() == 2)
end

-- Find Minerals on: the vein's icon moves onto the ring, leaving the game's own dot to show inside it.
do
    local m = Session({ enabled = true, minimapIcons = true })
    m.Login()
    local pin
    for _, f in ipairs(m.frames) do if f.ring and f.shown and f.id then pin = f end end
    check("not tracking: the icon sits in the middle", pin.icon.point[1] == "CENTER" and pin.icon.point[2] == nil)
    m.game.tracking = 2580
    m.Fire("MINIMAP_UPDATE_TRACKING")
    check("Find Minerals on: the icon moves to the ring's edge", pin.icon.point[2] > 0 and pin.icon.point[3] < 0)
    m.game.tracking = 2383
    m.Fire("MINIMAP_UPDATE_TRACKING")
    check("Find Herbs alone leaves a vein's icon in the middle", pin.icon.point[2] == nil)
end

-- Gathered: noted on loot, at the spot it grows, and shown on the world map.
do
    local g = Session({ enabled = true, gatheredPins = true })
    g.Login()
    check("gathered pins alone do not load the spot data", g.dataLoaded == nil)
    g.game.guid, g.game.near, g.game.px, g.game.py = GUID(COPPER), true, 0.501, 0.519
    g.game.lootFrom = "Creature-0-1-2-3-99-0000000001"
    g.Fire("LOOT_OPENED")
    check("a corpse looted beside a vein is not a gather", g.account.glimmerGathered == nil)
    g.game.lootFrom = nil
    g.Fire("LOOT_OPENED")
    local map = g.account.glimmerGathered and g.account.glimmerGathered[1429]
    local entry = map and map["1731:501:519"]
    check("a gathered vein is noted where you stand", entry ~= nil and entry.count == 1)
    g.Fire("LOOT_OPENED")
    check("the same loot window opened again counts once", entry.count == 1)
    g.game.guid, g.game.px, g.game.py = "GameObject-0-1-2-3-1731-0000ABCDF0", 0.503, 0.517
    g.Fire("LOOT_OPENED")
    check("the node grown back counts on the same pin", entry.count == 2)
    g.game.near = false
    g.Fire("LOOT_OPENED")
    check("not while out of reach", entry.count == 2)
    g.game.mapShown = true
    g.provider:RefreshAllData()
    check("on the world map", #g.game.pins == 1 and g.game.pins[1] == entry)
    g.game.mining = 0
    g.provider:RefreshAllData()
    check("an alt with no gathering still sees the account's gathers", #g.game.pins == 1)
    g.Set("ore", false)
    g.provider:RefreshAllData()
    check("ore off: not on the map", #g.game.pins == 0)
end

-- A look setting repaints the lit effect without starting it over; a nameplate that is not the soft target
-- is passed over.
do
    local r = Session({ enabled = true })
    r.Login()
    r.game.guid, r.game.plate = GUID(COPPER), Widget(r)
    r.Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "x")
    local lit = Lit(r)
    for _ = 1, 20 do lit.OnUpdate(lit, 0.05) end
    check("faded in", lit.appear == 1)
    r.Set("size", 1.3)
    check("a size change repaints in place", Lit(r) == lit and lit.size == 1.3 and lit.appear == 1)
    r.Set("brightness", 0.5)
    check("and so does brightness", lit.alpha == 0.5 and lit.appear == 1)
    local writes = #r.writes
    r.Set("range", 12)
    check("range writes the game setting, and leaves the effect", r.cvars.SoftTargetInteractRange == "12"
        and #r.writes == writes + 1 and lit.appear == 1)
    r.game.guid = nil
    r.Fire("PLAYER_SOFT_INTERACT_CHANGED", "x", "")
    r.game.guid = GUID(COPPER)
    local reads = 0
    local Read = r.ns.Glimmer.Target.Read
    r.ns.Glimmer.Target.Read = function(...) reads = reads + 1; return Read(...) end
    r.Fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
    check("another unit's nameplate is passed over", reads == 0)
    r.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    check("the soft target's is read", reads == 1)
end

-- The quest sparkle comes back whatever case the game names the setting in.
do
    local q = Session({ enabled = true, questSparkle = true })
    q.Login()
    q.cvars.graphicsOutlineMode = "2"
    q.Fire("CVAR_UPDATE", "graphicsoutlinemode", "2")
    q.RunTimers()
    check("a lower-case name still puts the sparkle back", q.cvars.graphicsOutlineMode == "0")
end

-- With the addon turned off, the core puts Glimmer's saved game settings back at login.
do
    local f = assert(io.open("Core/Core.lua", "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    local first = assert(source:find("local function RestoreGlimmerSettings()", 1, true))
    local last = assert(source:find("\nlocal meterCheck", first, true))
    local names = assert(source:match("\n(local GLIMMER_ADDON, .-\n)"))
    local account = { glimmerSoftCVars = { SoftTargetInteract = "1" }, glimmerSparkleCVars = { graphicsOutlineMode = "2" } }
    local cvars, loaded, combat = { SoftTargetInteract = "3", graphicsOutlineMode = "0" }, true, false
    local chunk = assert(loadstring(names .. source:sub(first, last) .. "return RestoreGlimmerSettings"))
    setfenv(chunk, setmetatable({
        ns = { AccountSettings = function() return account end },
        C_AddOns = { IsAddOnLoaded = function(name) return loaded and name == "NaowhForever_QoL" end },
        InCombatLockdown = function() return combat end,
        C_CVar = { SetCVar = function(k, v) cvars[k] = v end },
    }, { __index = _G }))
    local Restore = chunk()
    Restore()
    check("core: Glimmer loaded puts them back itself", cvars.SoftTargetInteract == "3" and account.glimmerSoftCVars)
    loaded, combat = false, true
    Restore()
    check("core: not in combat", cvars.SoftTargetInteract == "3")
    combat = false
    Restore()
    check("core: Glimmer off: both sets put back and forgotten", cvars.SoftTargetInteract == "1"
        and cvars.graphicsOutlineMode == "2" and account.glimmerSoftCVars == nil and account.glimmerSparkleCVars == nil)
end

-- With the spot data loaded, a first gather is pinned at the data's own spot.
do
    local d = Session({ enabled = true, gatheredPins = true, minimapIcons = true })
    d.Login()
    d.game.guid, d.game.near, d.game.px, d.game.py = GUID(COPPER), true, 0.501, 0.519
    d.Fire("LOOT_OPENED")
    local map = d.account.glimmerGathered and d.account.glimmerGathered[1429]
    check("snapped to the spot it grows", map and map["1731:500:520"] ~= nil)
end

-- A category color, with Skill-Up Colors off, repaints the minimap rings.
do
    local c = Session({ enabled = true, minimapIcons = true, skillColors = false })
    c.Login()
    c.Set("oreColor", { r = 0.1, g = 0.2, b = 0.3 })
    local ring
    for _, f in ipairs(c.frames) do if f.ring and f.shown and f.id then ring = f.ring end end
    check("the ring takes the new color", ring and ring.color[1] == 0.1 and ring.color[3] == 0.3)
end

print(("test-glimmer: %d checks passed"):format(checks))
