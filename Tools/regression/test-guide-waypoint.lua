-- Optional guide waypoint integration against synthetic guide and map ownership transitions.
local checks = 0
local function Check(value, label) assert(value, label); checks = checks + 1 end
local frames, hooks = {}, 0
local settings = { enabled = true, waypoints = true, waypointRestedXP = false }
local current, writes, clears, refreshes, available = nil, 0, 0, 0, true
local tracking = true
local S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end }
local ns = { QoLSettings = S, L = function(s) return s end, Apply = function() end,
    WaypointPinOn = function() return settings.waypoints end,
    GuideWaypointIsCurrent = function() return tracking and current and current.guide == true end,
    ClearGuideWaypoint = function()
        if tracking and current and current.guide then clears = clears + 1; current = nil end
    end,
    RefreshWaypointPin = function() refreshes = refreshes + 1 end,
}
-- A closure in the initializer cannot capture the local being declared.
ns.SetGuideWaypoint = function(title, map, x, y, details)
    if not available then return false end
    tracking = true
    writes = writes + 1
    current = { guide = true, title = title, map = map, x = x, y = y, details = details }
    ns.placedWaypoint = current
    return true
end
local alphaWrites = 0
local function Part(alpha)
    return { alpha = alpha, GetAlpha = function(self) return self.alpha end,
        SetAlpha = function(self, value) alphaWrites = alphaWrites + 1; self.alpha = value end }
end
local env = setmetatable({ NaowhForever = ns,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_QuestLog = { GetTitleForQuestID = function(id) return id == 7 and "The Criminal Element" end },
    CreateFrame = function()
        local f = { events = {} }
        function f:SetScript(_, fn) self.handler = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        frames[#frames + 1] = f
        return f
    end,
    hooksecurefunc = function(t, key, fn)
        if key == "UpdateMap" or key == "UpdateGotoSteps" then hooks = hooks + 1 end
        local old = t[key]
        t[key] = function(...) old(...); fn(...) end
    end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("Core/Integrations/RestedXP/Waypoint.lua")); setfenv(chunk, env); chunk()
local function Fire(event, ...)
    for _, f in ipairs(frames) do if f.events[event] then f.handler(f, event, ...) end end
end
ns.Apply()
Check(hooks == 0 and #frames == 0 and writes == 0, "off: no guide hooks or events")
S.Set("waypointRestedXP", true)
Check(frames[1].events.ADDON_LOADED and writes == 0, "optional guide absent: waits without errors")
local objective = { tag = "complete", questId = 7, frame = { text = { GetText = function() return "0/10 Bandits" end } } }
local element = { zone = 88, x = 45, y = 60, step = { active = true, elements = { objective } } }
local arrow = { element = element, texture = Part(0.8), text = Part(0.6) }
local rxp = { currentGuide = {}, arrowFrame = arrow, settings = { profile = { showEnabled = true } },
    UpdateMap = function() end, UpdateGotoSteps = function(refresh) if refresh then refresh() end end }
env.RXP = rxp
Fire("ADDON_LOADED", "RXPGuides")
Check(hooks == 2 and writes == 1 and current.map == 88 and current.x == 45 and current.y == 60,
    "late guide load follows the active destination")
Check(current.title == "The Criminal Element" and current.details.quest == 7
    and current.details.objectives == "0/10 Bandits", "guide quest context reaches the pin")
Check(alphaWrites == 0, "guide arrow stays visible while the pin follows it")
Check(next(frames[1].events) == nil, "following the guide registers no waypoint or tracking events")
rxp.UpdateGotoSteps()
Check(writes == 1, "unchanged guide destination does not rewrite the game waypoint")
objective.frame.text.GetText = function() return "1/10 Bandits" end
rxp.UpdateGotoSteps()
Check(writes == 1 and refreshes == 1 and current.details.objectives == "1/10 Bandits",
    "guide objective progress refreshes metadata without a map write")
current.title = "Deeprun Tram to Stormwind"
objective.frame.text.GetText = function() return "2/10 Bandits" end
rxp.UpdateGotoSteps()
Check(refreshes == 2 and current.title == "Deeprun Tram to Stormwind",
    "objective progress leaves a journey step's own title alone")
current.title = "The Criminal Element"
local held = current
tracking = false
ns.JourneyDetails = function() return held.details end
objective.frame.text.GetText = function() return "3/10 Bandits" end
rxp.UpdateGotoSteps()
Check(writes == 1 and refreshes == 3 and held.details.objectives == "3/10 Bandits",
    "objective progress between journey steps still reaches the pin")
ns.JourneyDetails, tracking = nil, true
current = { guide = false, title = "Manual pin" }
rxp.UpdateGotoSteps()
Check(writes == 1 and current.title == "Manual pin", "same guide step does not steal a manual waypoint")
arrow.element = { zone = 88, x = 55, y = 60, title = "Next stop", step = { active = true } }
rxp.UpdateMap()
Check(writes == 2 and current.title == "Next stop", "next guide destination resumes following")
S.Set("waypointRestedXP", false)
Check(current == nil and clears == 1 and next(frames[1].events) == nil,
    "disable clears only the owned pin")
S.Set("waypointRestedXP", true)
Check(hooks == 2 and writes == 3, "re-enable reuses hooks and follows current step")
current = { guide = false, title = "Manual again" }
S.Set("waypointRestedXP", false)
Check(current.title == "Manual again" and clears == 1, "disable preserves a manual pin")
S.Set("waypointRestedXP", true)
rxp.currentGuide = nil
rxp.UpdateGotoSteps()
Check(current == nil, "unloading the guide releases its destination")
rxp.currentGuide = {}
arrow.element.x = 101
rxp.UpdateMap()
Check(current == nil, "invalid coordinates do not create a pin")
arrow.element.x, available = 40, false
rxp.UpdateMap()
Check(current == nil, "unsupported map does not create a pin")
available = true
rxp.UpdateMap()
Check(current and current.x == 40, "valid guide destination recovers")
local beforeUntrack = writes
tracking = false
rxp.UpdateGotoSteps()
Check(writes == beforeUntrack, "ending native navigation does not repeatedly recreate the same destination")
S.Set("enabled", false)
Check(current and not tracking and next(frames[1].events) == nil, "module off releases events without clearing an untracked pin")
rxp.UpdateGotoSteps()
Check(current and not tracking, "installed hooks remain inert while off")
Check(alphaWrites == 0, "guide arrow is never touched")
local pinAt
env.C_Map = { GetUserWaypointPositionForMap = function(map) return pinAt and pinAt.map == map and pinAt or nil end }
Check(ns.RestedXPPin() == false, "no guide window steps: no RestedXP pin")
local pinned = { zone = 1429, zx = 0.4, zy = 0.6, waypointSet = true }
rxp.RXPFrame = { activeSteps = { {}, { elements = { { tag = "goto" }, pinned } } } }
pinAt = { map = 1429, x = 0.4, y = 0.6 }
Check(ns.RestedXPPin() == true, "the pin a guide step placed is RestedXP's")
pinAt = { map = 1429, x = 0.5, y = 0.6 }
Check(ns.RestedXPPin() == false, "a pin elsewhere on the same map is not")
pinAt, pinned.waypointSet = { map = 1429, x = 0.4, y = 0.6 }, false
Check(ns.RestedXPPin() == false, "a step that let its pin go no longer owns it")
-- A hidden arrow is presentation state, not a missing guide destination.
local target = { zone = 88, x = 45, y = 60, title = "Quest area", step = { active = true } }
arrow.element = target
rxp.activeWaypoints = { target }
rxp.settings.profile.disableArrow, rxp.hideArrow = true, false
tracking, current = true, nil
S.Set("enabled", true)
local hiddenWrites, hiddenClears = writes, clears
rxp.hideArrow = true
rxp.UpdateGotoSteps()
Check(current and current.x == 45 and writes == hiddenWrites and clears == hiddenClears,
    "hiding the guide arrow does not clear a valid active destination")
local replacement = { zone = 88, x = 45, y = 60, title = "Quest area", step = { active = true } }
arrow.element, rxp.activeWaypoints = replacement, { replacement }
rxp.UpdateGotoSteps()
Check(writes == hiddenWrites, "a replacement guide element at the same location does not place another pin")
local transient = { zone = 88, x = 55, y = 60, title = "Intermediate area", step = { active = true } }
rxp.UpdateGotoSteps(function()
    arrow.element = transient
    rxp.UpdateMap()
    arrow.element = replacement
end)
Check(writes == hiddenWrites and current.x == 45,
    "hidden-arrow map refreshes do not replace the final destination with an intermediate target")
rxp.UpdateGotoSteps(function()
    arrow.element = transient
    rxp.UpdateMap()
end)
Check(writes == hiddenWrites + 1 and current.x == 55, "a genuine final destination change still places one pin")
local manualWrites = writes
current = { guide = false, title = "Manual during guide" }
arrow.element = { zone = 88, x = 55, y = 60, title = "Updated title", step = { active = true } }
rxp.activeWaypoints = { arrow.element }
rxp.UpdateGotoSteps()
Check(writes == manualWrites and current.title == "Manual during guide", "same-coordinate replacements cannot steal a manual pin")
arrow.element = target
rxp.activeWaypoints = { target }
rxp.UpdateGotoSteps()
Check(current and current.guide and current.x == 45, "following resumes when the actual destination changes")
rxp.activeWaypoints = {}
rxp.UpdateGotoSteps()
Check(current == nil, "an empty active waypoint list releases even a stale valid arrow target")
rxp.activeWaypoints = { target }
rxp.UpdateGotoSteps()
Check(current and current.x == 45, "a later active destination can recover after the guide has none")
rxp.settings.profile.disableArrow = false
rxp.UpdateGotoSteps()
Check(current == nil, "normal guide arrow suppression still releases its pin")
rxp.settings.profile.disableArrow, rxp.hideArrow = true, false
rxp.UpdateGotoSteps()
arrow.element.skip = true
rxp.UpdateGotoSteps()
Check(current == nil, "completed or skipped guide targets are not kept by hiding the arrow")
local loop = { active = true, loop = "", index = 6 }
local reached = { zone = 1420, x = 31.71990734137275, y = 63.980076016279511,
    radius = 40, step = loop }
local nextPoint = { zone = 1420, x = 30.689976497665977, y = 63.880158995733836,
    radius = 40, step = loop }
arrow.element, rxp.activeWaypoints = nextPoint, { nextPoint }
rxp.UpdateGotoSteps()
local loopWrites, loopClears, loopPin = writes, clears, current
for _ = 1, 7 do
    reached.skip = false
    arrow.element, rxp.activeWaypoints = reached, { reached, nextPoint }
    rxp.UpdateMap()
    reached.skip = true
    rxp.UpdateGotoSteps(function() rxp.UpdateMap() end)
    arrow.element, rxp.activeWaypoints = nextPoint, { nextPoint }
    rxp.UpdateMap()
    rxp.UpdateGotoSteps()
end
Check(current == loopPin and writes == loopWrites and clears == loopClears,
    "an arrived loop point cannot repeatedly clear and recreate the next destination")
current = { guide = false, title = "Manual beside loop" }
arrow.element, reached.skip = reached, true
rxp.UpdateGotoSteps()
arrow.element = nextPoint
rxp.UpdateGotoSteps()
Check(current.title == "Manual beside loop" and writes == loopWrites and clears == loopClears,
    "loop arrival retries leave a manual pin alone")
arrow.element, reached.skip = reached, false
rxp.UpdateGotoSteps()
Check(current.guide and current.x == reached.x and writes == loopWrites + 1,
    "backing away to a genuinely selected loop destination still follows it")
reached.skip, reached.completed = true, true
rxp.UpdateGotoSteps()
Check(current == nil, "a completed loop target still releases the pin")
reached.completed, reached.skip = nil, false
rxp.UpdateGotoSteps()
reached.skip, loop.active = true, false
rxp.UpdateGotoSteps()
Check(current == nil, "a stopped loop step releases its pin even while skipped")
loop.active, reached.skip = true, false
rxp.UpdateGotoSteps()
reached.skip, reached.parent = true, { completed = true }
rxp.UpdateGotoSteps()
Check(current == nil, "a completed loop parent releases its pin")
reached.skip, reached.parent = false, nil
rxp.UpdateGotoSteps()
arrow.element = { zone = 1420, x = reached.x, y = reached.y, skip = true,
    step = { active = true, loop = true, index = 7 } }
rxp.UpdateGotoSteps()
Check(current == nil, "a skipped point in another step cannot retain the previous step's pin")
arrow.element = reached
rxp.UpdateGotoSteps()
reached.skip, rxp.activeWaypoints = true, {}
rxp.UpdateGotoSteps()
Check(current == nil, "an empty loop waypoint list still releases the pin")
rxp.activeWaypoints, reached.skip = { reached }, false
rxp.UpdateGotoSteps()
reached.skip, rxp.settings.profile.disableArrow = true, false
rxp.UpdateGotoSteps()
Check(current == nil, "visible-arrow skip handling remains unchanged for loop steps")
rxp.settings.profile.disableArrow = true
reached.skip, arrow.element = false, reached
rxp.UpdateGotoSteps()
reached.skip, rxp.currentGuide = true, {}
rxp.UpdateGotoSteps()
Check(current == nil, "a different guide cannot retain the previous guide's loop pin")
reached.skip = false
rxp.UpdateGotoSteps()
reached.skip = true
rxp.UpdateGotoSteps()
S.Set("waypointRestedXP", false)
Check(current == nil, "disabling the feed clears a pin held through a loop arrival retry")
S.Set("waypointRestedXP", true)
Check(current == nil, "enabling on an already skipped loop point does not create a pin")
Check(rxp.settings.profile.disableArrow == true and alphaWrites == 0,
    "the integration never changes the arrow preference or visibility")
S.Set("waypointRestedXP", false)
Check(hooks == 2 and next(frames[1].events) == nil, "the fix adds no hooks, polling, or persistent registrations")
print(("test-guide-waypoint: %d checks passed"):format(checks))
