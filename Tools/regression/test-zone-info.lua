-- Zone Info: original model and lifecycle coverage, without a game client.
local root = "NaowhForever_QoL/Interface/ZoneInfo/"
local checks = 0
local function Check(ok, text) assert(ok, text); checks = checks + 1 end
local function Read(name)
    local f = assert(io.open(root .. name, "rb"))
    local s = f:read("*a"); f:close(); return s
end
local function Wipe(t) for k in pairs(t) do t[k] = nil end return t end
local function Fixture(runtime)
    local secret = setmetatable({}, { __index = function() error("secret inspected") end })
    local state = { level = 16, herb = 100, fish = 75, frames = {}, loads = 0, queries = 0,
        combat = false, mouse = true, x = 0.5, y = 0.5, target = 1, map = 100, enabled = {} }
    local defaults = { enabled = true, zoneInfo = false, zoneInfoCurrent = false, zoneInfoDungeons = false,
        zoneInfoFishing = false, zoneInfoTravel = false, zoneInfoGathering = false, zoneInfoHideCombat = false,
        zoneInfoOnlyProfessions = false, zoneInfoPinned = 0, zoneInfoScale = 1,
        zoneInfoPos = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -24, y = -220 } }
    local values, listeners = {}, {}
    local S = {}
    function S.Get(k) if values[k] == nil then return defaults[k] end return values[k] end
    function S.Set(k, v) values[k] = v; for _, fn in ipairs(listeners) do fn(k, v) end end
    function S.Default(k) return defaults[k] end
    function S.OnChange(fn) listeners[#listeners + 1] = fn end
    local maps = { [1] = { mapID = 1, name = "Westfall", mapType = 3, parentMapID = 100 },
        [2] = { mapID = 2, name = "Arathi Highlands", mapType = 3, parentMapID = 100 },
        [3] = { mapID = 3, name = "Cave", mapType = 4, parentMapID = 1 },
        [100] = { mapID = 100, name = "Eastern Kingdoms", mapType = 2, parentMapID = 0 } }
    local function Frame(kind, parent)
        local f = { kind = kind, parent = parent, scripts = {}, events = {}, shown = true }
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(k) self.events[k] = true end
        function f:UnregisterAllEvents() Wipe(self.events) end
        function f:SetSize(w, h) self.w, self.h = w, h end
        function f:SetPoint(...) self.point = { ... } end
        function f:GetPoint() return "TOPRIGHT", parent, "TOPRIGHT", -30, -60 end
        function f:ClearAllPoints() self.point = nil end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:IsShown() return self.shown end
        function f:SetShown(v) self.shown = v end
        function f:SetEnabled(v) self.enabled = v end
        function f:SetScale(v) self.scale = v end
        function f:SetMovable(v) self.movable = v end
        function f:SetClampedToScreen() end
        state.frames[#state.frames + 1] = f
        return f
    end
    local canvas = {}
    local map = { shown = false }
    function map:IsShown() return self.shown end
    function map:GetCanvasContainer() return canvas end
    function map:IsCanvasMouseFocus() return state.mouse end
    function map:GetNormalizedCursorPosition() return state.x, state.y end
    function map:GetMapID() return state.map end
    function map:AddDataProvider(p) self.provider = p; p:OnAdded(self) end
    function map:RemoveDataProvider(p) p:RemoveAllData(); p:OnRemoved(self); self.provider = nil end
    local base = {}
    function base:OnAdded(owner) self.owner = owner end
    function base:OnRemoved() self.owner = nil end
    function base:GetMap() return self.owner end
    local T = { muted = {}, fg = {} }
    local ns = { QoLSettings = S, THEME = T, UI = {}, ZoneLevels = { [1] = { 9, 18 }, [2] = { 30, 40 } },
        FishingLevels = { [1] = { 1, 75 } }, Shared = { Style = { HAVE_RGB = {}, TIME_OUT_RGB = {} },
            Places = { SameMap = function(id) return id end } } }
    ns.L = function(text) return text end
    ns.Apply, ns.ShowUnlockMode, ns.HideUnlockMode = function() end, function() end, function() end
    ns.UIScale = function() return 1 end
    ns.Tooltip = function() end
    ns.Button = function(parent) return Frame("Button", parent) end
    ns.UI.AttachMover = function(parent, _, save)
        state.save = save
        return Frame("Mover", parent)
    end
    ns.Glimmer = { C = { SPOT_SCALE = 1000 }, NODES = {
        [1617] = { "herb", 1, "Silverleaf" }, [1731] = { "ore", 1, "Copper Vein" },
        [9999] = { "herb", 1, "Silverleaf" } }, Spots = {} }
    function ns.Glimmer.Spots.Load()
        if state.combat then return false end
        state.loads = state.loads + 1
        ns.GlimmerSpots = { [1] = { 1617, 100, 200, 1731, 300, 400, 9999, 500, 600 } }
        return true
    end
    ns.TownNPCs = { [1] = { { 10, 20, "flight", "Friendly flight", "", nil, "A" },
        { 30, 40, "flight", "Hostile flight", "", nil, "H" } } }
    ns.TownTravel = { [1] = { { 20, 30, "AH", "Boat to Arathi", 2 } } }
    ns.ZoneExits = { [1] = { { 40, 50, 0, 2 } } }
    local dungeon = { name = "The Deadmines", entrance = { map = 1, x = 43.2, y = 72.4 }, wings = {} }
    ns.Journal = { Settings = { Get = function() return state.journal ~= false end },
        Dungeons = function() return { dungeon } end, LevelRange = function() return "17-26" end }
    local env = setmetatable({ NaowhForever = ns, Enum = { UIMapType = { Zone = 3 } },
        issecretvalue = function(v) return v == secret end, wipe = Wipe,
        InCombatLockdown = function() return state.combat end,
        UnitLevel = function() assert(not state.combat, "live level read in combat"); return state.secretLevel and secret or state.level end,
        UnitFactionGroup = function() return "Alliance" end,
        GetSubZoneText = function() return "Sentinel Hill" end,
        C_PvP = { GetZonePVPInfo = function() return "friendly" end },
        GetProfessions = function() return state.secretSkill and secret or 1, nil, nil, state.secretFish and secret or 2 end,
        GetProfessionInfo = function(index)
            assert(index ~= secret, "secret index used")
            return "Profession", "icon", index == 1 and state.herb or state.fish, 300, 0, 0,
                index == 1 and 182 or 356, index == 1 and 10 or 5
        end,
        GetQuestDifficultyColor = function() return T.fg end,
        C_Map = { GetMapInfo = function(id) return maps[id] end,
            GetBestMapForUnit = function() assert(not state.combat); return 1 end,
            GetMapInfoAtPosition = function() state.queries = state.queries + 1; return maps[state.target] end },
        WorldMapFrame = map, UIParent = {}, MapCanvasDataProviderMixin = base,
        CreateFrame = function(kind, _, parent) return Frame(kind, parent) end,
        CreateFromMixins = function(mixin) local out = {}; for k, v in pairs(mixin) do out[k] = v end return out end,
        hooksecurefunc = function(owner, key, callback)
            local old = assert(owner[key], key)
            owner[key] = function(...) old(...); callback(...) end
        end,
    }, { __index = _G })
    env._G = env
    local function Load(name) local fn = assert(loadstring(Read(name), name)); setfenv(fn, env); fn() end
    Load("Model.lua")
    local Z = ns.ZoneInfo
    Z.Character()
    state.out = { rows = {} }
    state.ns, state.S, state.Z, state.map = ns, S, Z, map
    if runtime then
        function Z.MapText(id) state.summary = id end
        function Z.HideMapText() state.summary = nil end
        function Z.Hover(id) state.hover = id end
        function Z.HoverFocused() return state.focused end
        function Z.ShowDetails(detached) state.detailMap, state.detached = S.Get("zoneInfoPinned"), detached end
        function Z.HideMap() state.hover = nil; Z.HideMapText() end
        function Z.HideAll() state.hidden = true; if state.hud then state.hud:Hide(); state.hud.mover:Hide() end end
        function Z.RefreshPanels() state.refreshes = (state.refreshes or 0) + 1 end
        function Z.HUD() state.hud = state.hud or Frame("HUD"); return state.hud end
        function Z.PaintHUD(_, id) state.hudMap = id end
        Load("Runtime.lua")
        function state.Event(event, arg)
            for _, f in ipairs(state.frames) do if f.events[event] then f.scripts.OnEvent(f, event, arg) end end
        end
        function state.Tick(elapsed)
            for _, f in ipairs(state.frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, elapsed) end end
        end
    end
    return state
end

local function Find(out, title)
    for i = 1, out.count do if out.rows[i].title == title then return out.rows[i] end end
end

-- Stable model data comes from existing registries; optional modules are guarded.
do
    local f = Fixture()
    local Z, S, out = f.Z, f.S, f.out
    Check(Z.skills[182] == 110 and Z.fishing == 80, "profession bonus is return eight, including fishing")
    Check(Z.ZoneMap(3) == 1 and Z.ZoneMap(100) == nil and Z.ZoneMap(999) == nil, "zones normalize floors, not continents")
    Z.current = 1
    Z.Fill(out, 1, false)
    Check(out.range == "Level 9-18" and out.rating == "Good for your level", "readable level recommendation")
    Check(out.territory == "Friendly territory", "current territory comes from the client")
    Z.Fill(out, 2, false)
    Check(out.territory == nil and out.rating == "Above your level", "hovered territory is not invented")
    Check(f.loads == 0, "overview does not decode gathering locations")
    S.Set("zoneInfoDungeons", true); S.Set("zoneInfoTravel", true); S.Set("zoneInfoFishing", true)
    Z.Fill(out, 1, false)
    Check(Find(out, "The Deadmines").dungeon ~= nil, "dungeon links retain their registry entry")
    Check(Find(out, "Friendly flight") and not Find(out, "Hostile flight"), "travel filters opposing faction stops")
    Check(Find(out, "Boat to Arathi").x == 20 and Find(out, "Road to Arathi Highlands").y == 50, "travel waypoints use known coordinates")
    Check(Find(out, "Fishing 1 minimum / 75 reliable").detail == "Your Fishing: 80 / Reliable fishing", "fishing distinguishes minimum and reliable skill")
    f.journal = false
    Z.Fill(out, 1, false)
    Check(not Find(out, "The Deadmines") and Find(out, "Friendly flight"), "disabling Journal removes only its content")
    S.Set("zoneInfoDungeons", false); S.Set("zoneInfoTravel", false)
    Z.Fill(out, 2, false)
    Check(Find(out, "Fishing requirements are not recorded for this zone."), "missing fishing data is explicit")
    S.Set("zoneInfoDungeons", true); S.Set("zoneInfoTravel", true)
    f.ns.Journal = nil
    Z.Fill(out, 1, false)
    Check(out.count > 0, "no Journal installed is supported")
    Z.Fill(out, 999, false)
    Check(out.count == 1 and not Find(out, "Friendly flight"), "unknown zone clears old details")
end

-- Gathering loads lazily, deduplicates object variants and remains independent of Glimmer's switches.
do
    local f = Fixture(); local Z, S, out = f.Z, f.S, f.out
    S.Set("zoneInfoOnlyProfessions", true)
    Z.Fill(out, 1, true)
    Check(f.loads == 1 and Find(out, "Silverleaf") and not Find(out, "Copper Vein"), "only learned professions are shown")
    Check(out.count == 3, "same named herb variants appear once")
    local herb = Find(out, "Silverleaf")
    Check(herb.x == 10 and herb.y == 20 and herb.detail == "Your skill 110 / Requires 1", "known spots use normalized map percentages")
    Z.Fill(out, 1, true)
    Check(f.loads == 1, "repeated draws reuse the node index")
    S.Set("zoneInfoOnlyProfessions", false)
    Z.Fill(out, 1, true)
    Check(Find(out, "Copper Vein").detail == "Requires skill 1", "all-professions view shows requirements, not false readiness")
end

do
    local f = Fixture(); f.combat = true
    f.Z.Fill(f.out, 1, true)
    Check(f.loads == 0 and Find(f.out, "Gathering details are available after combat."), "decoding defers in combat")
    f.combat = false
    f.Z.Fill(f.out, 1, true)
    Check(f.loads == 1 and Find(f.out, "Silverleaf"), "post-combat draw retries gathering")
    f.secretLevel, f.secretSkill, f.secretFish = true, true, true
    f.Z.Character()
    Check(f.Z.level == nil and f.Z.fishing == nil and not f.Z.professionsKnown, "secret character values are never consumed")
    f.S.Set("zoneInfoOnlyProfessions", true)
    f.Z.Fill(f.out, 1, true)
    Check(Find(f.out, "Profession information is unavailable."), "unknown skills are not labeled missing or ready")
end

-- Provider and HUD lifecycle use real runtime code, with only drawing stubs.
do
    local f = Fixture(true); local S, Z, map = f.S, f.Z, f.map
    Check(#f.frames == 0 and map.provider == nil, "off by default creates no frames, events or provider")
    f.ns.Apply()
    Check(#f.frames == 0, "profile apply while off remains free")
    S.Set("zoneInfo", true)
    Check(map.provider ~= nil and f.hud == nil, "enabling map feature leaves optional HUD unbuilt")
    f.Tick(1)
    Check(f.queries == 0, "hidden map has no hover work")
    map.shown = true; map.provider:OnShow()
    f.Tick(0.04); Check(f.queries == 0, "moving-map queries are throttled")
    f.Tick(0.05); Check(f.queries == 1 and f.hover == 1, "hover resolves the zone")
    f.Tick(0.2); Check(f.queries == 1, "stationary cursor performs no repeated query")
    f.mouse = false
    f.Tick(0.2)
    Check(f.hover == 1 and f.queries == 1, "summary remains clickable while crossing from map to external dock")
    f.mouse = true
    f.target, f.x = 100, 0.6; f.Tick(0.1)
    Check(f.hover == 1, "crossing empty continent map space keeps the last valid zone available")
    f.x = 1.1; f.Tick(0.1)
    Check(f.hover == 1, "crossing the canvas boundary cannot dismiss the pin action")
    map.provider:RefreshAllData()
    Check(f.hover == 1, "same-map redraw keeps the pin action")
    f.Event("SKILL_LINES_CHANGED")
    Check(f.hover == 1, "character refresh updates rather than dismisses the hover card")
    f.target, f.x = 1, 0.5
    Z.Pin(1, false)
    f.target, f.x = 2, 0.7; f.Tick(0.1)
    Check(S.Get("zoneInfoPinned") == 1 and f.hover == 2, "hovering elsewhere never replaces the pinned zone")
    S.Set("zoneInfoCurrent", true)
    Check(f.hud:IsShown() and f.hudMap == 1, "current-zone HUD follows the player, not the selected map")
    S.Set("zoneInfoHideCombat", true)
    f.combat = true; f.Event("PLAYER_REGEN_DISABLED")
    local before = f.queries
    f.x = 0.8; f.Tick(1)
    Check(f.queries == before and not f.hud:IsShown(), "combat stops queries and hides the configured HUD")
    S.Set("zoneInfoHideCombat", false)
    Check(f.hud:IsShown(), "optional combat display uses cached data without live unit reads")
    f.combat = false; f.Event("PLAYER_REGEN_ENABLED")
    f.Tick(0.1)
    Check(f.queries == before + 1 and f.hud:IsShown(), "combat exit restores map updates and HUD")
    f.Event("PLAYER_LEVEL_UP", 17)
    Check(Z.level == 17, "level-up payload updates the cached level")
    f.ns.ShowUnlockMode()
    Check(f.hud.mover.shown, "HUD participates in the shared editor")
    f.ns.HideUnlockMode()
    Check(not f.hud.mover.shown, "closing editor clears the mover")
    local count = #f.frames
    S.Set("zoneInfo", true)
    Check(#f.frames == count, "repeated enables reuse frames")
    f.save(f.hud)
    Check(S.Get("zoneInfoPos").x == -30, "HUD movement persists through the settings store")
    map.shown = false; map.provider:OnHide()
    before = f.queries; f.Tick(1)
    Check(f.queries == before, "map close stops all hover work")
    S.Set("zoneInfo", false)
    Check(map.provider == nil and not f.hud:IsShown(), "disable removes the provider and hides the HUD")
    for _, frame in ipairs(f.frames) do Check(next(frame.events) == nil and frame.scripts.OnUpdate == nil, "disable leaves no registered events or ticking") end
    S.Set("zoneInfo", true)
    Check(#f.frames == count and map.provider, "reenabling reuses every constructed frame")
end

do
    local f = Fixture(true)
    local S, map = f.S, f.map
    S.Set("zoneInfoOnMap", true)
    Check(f.summary == nil and #f.frames == 0, "on-map option alone cannot activate a disabled feature")
    S.Set("zoneInfo", true)
    map.shown = true; map.provider:OnShow()
    Check(f.summary == 1, "zoomed-out map initially summarizes the current zone")
    local button
    for _, frame in ipairs(f.frames) do if frame.kind == "Button" then button = frame end end
    Check(button and not button.shown and f.hud == nil, "map-text layout hides the map button and leaves optional HUD off")
    f.target, f.x = 2, 0.7; f.Tick(0.1)
    Check(f.summary == 2, "zoomed-out hover updates the on-map summary")
    map.provider:RefreshAllData()
    Check(f.summary == 2, "same-map refresh retains the last valid hovered zone")
    f.map.mapID = 2
    f.map.GetMapID = function() return 2 end
    map.provider:RefreshAllData()
    Check(f.summary == 2, "zooming into another zone summarizes the selected zone")
    S.Set("zoneInfoOnMap", false)
    Check(f.summary == nil and button.shown, "switching back removes map text and restores the panel button")
    S.Set("zoneInfoOnMap", true)
    map.shown = false; map.provider:OnHide()
    Check(f.summary == nil, "closing the map hides its summary")
end

print("test-zone-info: " .. checks .. " checks passed")
