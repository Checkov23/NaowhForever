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
    UpdateMap = function() end, UpdateGotoSteps = function() end }
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
print(("test-guide-waypoint: %d checks passed"):format(checks))
