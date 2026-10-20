-- Run with Lua 5.1 from the repository root: the Waypoint Pin against stubs of the game's
-- navigation. Off by default and idle while off; on, it follows the navigation frame with the
-- name ns.PlaceWaypoint gave the spot, moves to the screen's edge or the behind-you cue while
-- the spot is off screen, shows the arrival where the pin stood even once the game has cleared
-- the waypoint, ignores stops on the way, goes within 40 yards of a tracked quest (its area) and
-- comes back past 55, and fades the game's own marker only while it is on.
-- These do not emulate rendering or the 3D projection.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local W, H = 1920, 1080
local EDGE_ROOM = 250
local NOOP = function() end
local made = {}
local GLYPH_W = 6
local Frame = {}
local FrameMeta = { __index = function(_, k)
    if Frame[k] then return Frame[k] end
    if type(k) == "string" and k:match("^%u") then return NOOP end
end }

local function NewFrame(kind, parent)
    local f = setmetatable({ kind = kind, parent = parent, scripts = {}, events = {}, shown = true, alpha = 1 }, FrameMeta)
    made[#made + 1] = f
    return f
end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(v) self.shown = v and true or false end
function Frame:IsShown() return self.shown end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:SetScale(v) self.scale = v end
function Frame:ClearAllPoints() self.point, self.points = nil, {} end
function Frame:SetPoint(...)
    self.point = { ... }
    self.points = self.points or {}
    self.points[#self.points + 1] = self.point
end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:GetStringHeight() return 13 * (select(2, (self.text or ""):gsub("\n", "")) + 1) end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:GetStringWidth() return #(self.text or "") * GLYPH_W end
function Frame:SetJustifyH(j) self.justify = j end
function Frame:SetRotation(r) self.rotation = r end
function Frame:SetTexture(t) self.texture = t end
function Frame:SetHeight(h) self.height = h end
function Frame:CreateTexture() return NewFrame("Texture", self) end
function Frame:CreateFontString() return NewFrame("FontString", self) end

local UIParent = NewFrame("Frame")
function UIParent:GetWidth() return W end
function UIParent:GetHeight() return H end
function UIParent:GetCenter() return W / 2, H / 2 end

local settings = {}
local defaults = { enabled = true, waypoints = false, waypointShape = "hex", waypointScale = 1, waypointCard = true,
    waypointTime = true, waypointBeam = true, waypointFadeNear = 40, waypointArrive = 5, waypointEdge = true, waypointNav = true,
    waypointSound = "none", waypointHideGame = true }
local S = {}
function S.Get(k) if settings[k] ~= nil then return settings[k] end return defaults[k] end
function S.Set(k, v) settings[k] = v end

local nav = { frame = nil, valid = true, clamped = false, distance = 312, x = 1100, y = 700 }
local navFrame = NewFrame("NavFrame")
function navFrame:GetCenter() return nav.x, nav.y end
local userWaypoint, cleared, superCleared = nil, 0, 0
local playerMap = 88
local tracked, mapOpen, mapHide = {}, false, nil
local parents = { [1500] = 88 }   -- a leaf zone inside the waypoint's map
local timers, played, printed = {}, {}, {}
local speed = 0
local now = 0
local questObjectives = {}
local tracking = 1   -- Enum.SuperTrackingType.UserWaypoint

local gameMarker = {}
for _, key in ipairs({ "Icon", "Arrow", "DistanceText", "IconBorder" }) do gameMarker[key] = NewFrame("Texture") end

local function Theme() return { r = 0, g = 0.57, b = 0.93 } end
local routeInfo   -- { title, at, n, next } while a route is followed
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    MEDIA = dofile("Tools/regression/core_media.lua"),
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    QoLSettings = S,
    WAYPOINT_HOLD = 4,
    WaypointRoute = function() if routeInfo then return unpack(routeInfo) end end,
    THEME = { accent = Theme(), accentSoft = Theme(), fg = Theme(), muted = Theme(), bg = Theme() },
    Font = function(parent) return parent:CreateFontString() end,
    Solid = function(parent) return parent:CreateTexture() end,
    Print = function(msg) printed[#printed + 1] = msg end,
    ClearWaypoint = function()
        userWaypoint = nil
        cleared, superCleared = cleared + 1, superCleared + 1
    end,
    Apply = NOOP, ShowUnlockMode = NOOP, HideUnlockMode = NOOP,
    UI = {
        AttachMover = function(frame) return NewFrame("Mover", frame) end,
        _PlayLSMSound = function(path) if path then played[#played + 1] = path end end,
        SoundPathFor = function(key) if key ~= "none" then return "sound:" .. key end end,
    },
    Shared = {
        Places = dofile("Tools/regression/shared_places.lua"),
        Style = setmetatable({ ROUND = "round", PLACE_DOT = " . " },
            { __index = dofile("Tools/regression/shared_style.lua") }),
        Parts = {
            HudBackdrop = NOOP,
            HudText = function(fs) return fs end,
            IconButton = function(parent, onClick)
                local b = NewFrame("Button", parent)
                b.click = onClick
                return b
            end,
        },
    },
}

local env = setmetatable({
    NaowhForever = ns,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UIParent = UIParent,
    CreateFrame = function(kind, _, parent) return NewFrame(kind, parent) end,
    C_Navigation = {
        GetFrame = function() return nav.frame end,
        HasValidScreenPosition = function() return nav.valid end,
        WasClampedToScreen = function() return nav.clamped end,
        GetDistance = function() return nav.distance end,
    },
    C_SuperTrack = {
        IsSuperTrackingUserWaypoint = function() return tracking == 1 end,
        SetSuperTrackedUserWaypoint = function(on) tracked[#tracked + 1] = on end,
        GetHighestPrioritySuperTrackingType = function() return tracking end,
        GetSuperTrackedQuestID = function() return 7 end,
        ClearAllSuperTracked = function() superCleared = superCleared + 1 end,
    },
    WorldMapFrame = { IsVisible = function() return mapOpen end,
        HookScript = function(_, name, fn) if name == "OnHide" then mapHide = fn end end },
    C_Map = {
        HasUserWaypoint = function() return userWaypoint ~= nil end,
        GetBestMapForUnit = function() return playerMap end,
        GetUserWaypoint = function() return userWaypoint end,
        ClearUserWaypoint = function() userWaypoint = nil; cleared = cleared + 1 end,
        GetMapInfo = function(id) return { name = "Thunder Bluff", parentMapID = parents[id] or 0 } end,
    },
    C_QuestLog = { GetTitleForQuestID = function() return "The Barrens Oases" end,
        GetQuestObjectives = function() return questObjectives end },
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end },
    Enum = { SuperTrackingType = { Quest = 0, UserWaypoint = 1, Corpse = 2 } },
    SuperTrackedFrame = gameMarker,
    GetUnitSpeed = function() return speed end,
    issecretvalue = function(v) return v == "secret" end,
    GetTime = function() return now end,
    BreakUpLargeNumbers = function(n)
        local s = tostring(n)
        while true do
            local k
            s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
            if k == 0 then return s end
        end
    end,
    hooksecurefunc = function(tbl, name, fn)
        local orig = tbl[name]
        tbl[name] = function(...)
            orig(...)
            fn(...)
        end
    end,
}, { __index = _G })
env._G = env
local f = assert(io.open("NaowhForever_QoL/Interface/Waypoints.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local chunk = assert(loadstring(source, "NaowhForever_QoL/Interface/Waypoints.lua"))
setfenv(chunk, env)
chunk()

local function Find(pred)
    for _, fr in ipairs(made) do
        if pred(fr) then return fr end
    end
end
local boot = Find(function(fr) return fr.events.PLAYER_LOGIN end)
boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
local events = Find(function(fr) return fr.scripts.OnEvent and fr ~= boot end)

-- Off by default: nothing listens and nothing is built.
Check(next(events.events) == nil, "off by default, no events")
Check(not Find(function(fr) return fr.card end), "and no pin built")
Check(gameMarker.Icon.alpha == 1, "and the game's marker untouched")

-- On with no waypoint: it listens, shows nothing, and fades the game's marker.
S.Set("waypoints", true)
Check(events.events.NAVIGATION_FRAME_CREATED and events.events.NAVIGATION_DESTINATION_REACHED, "on, it listens")
local pin = Find(function(fr) return fr.card end)
local navBar = Find(function(fr) return fr.mover end)
local driver = Find(function(fr) return fr.kind == "Frame" and fr.parent == nil and fr ~= UIParent and fr ~= boot
    and fr ~= events end)
Check(pin and not pin:IsShown() and not navBar:IsShown(), "with no waypoint nothing shows")
Check(gameMarker.Icon.alpha == 0 and gameMarker.DistanceText.alpha == 0, "the game's marker is faded")

-- A spot from ns.PlaceWaypoint: followed on the navigation frame, named as it was placed.
ns.placedWaypoint = { title = "Mage Trainer", map = 88, x = 46.2, y = 49.8 }
userWaypoint = { uiMapID = 88, position = { x = 0.462, y = 0.498 } }
nav.frame = navFrame
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
Check(pin:IsShown() and pin.point[2] == navFrame and pin.point[5] == 36 / 2 + 80,
    "the pin stands its line's length above the navigation point, the ring on the spot")
S.Set("waypointBeam", false)
Check(pin.point[2] == navFrame and pin.point[5] == 0, "with no line it sits on the spot")
S.Set("waypointBeam", nil)
Check(pin.card.name.text == "Mage Trainer" and pin.card.dist.text == "312 yd", "named as placed, with its distance")
Check(pin.card.time.text == "about 0:45", "standing still, the walking time is at running pace")
local function Centred(card)
    local row = #card.dist.text * GLYPH_W + (card.time.text ~= "" and 8 + #card.time.text * GLYPH_W or 0)
    local left = card.icon.shown and 8 + 35 + 8 or 8
    return card.name.justify == "CENTER" and card.note.justify == "CENTER"
        and card.dist.point[4] == math.floor(math.max(180 - left - 8 - row, 0) / 2 + 0.5)
end
Check(Centred(pin.card), "the name, and the distance with its time, sit centred on the card")
speed = 14
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.time.text == "about 0:22", "moving, at your own speed")
speed = "secret"
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.time.text == "about 0:22", "a speed that reads secret keeps the last readable one")
-- On an epic mount with the speed secret, the last readable speed is the run on foot: the
-- time comes from how fast the distance shrinks instead.
speed = 7
driver.scripts.OnUpdate(driver, 0)
speed = "secret"
now = now + 1
nav.distance = 298
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.time.text == "about 0:21", "closing 14 yards a second: the time at that pace")
now = now + 0.5
nav.distance = 291
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.time.text == "about 0:21", "between samples the pace is kept")
now = now + 0.5
nav.distance = 284
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.time.text == "about 0:20", "and the time follows the distance")
now = now + 1
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.time.text == "about 0:41", "stopped: back to the last readable speed")
now = now + 1
nav.distance = 1300
driver.scripts.OnUpdate(driver, 0)
now = now + 1
nav.distance = 312
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.time.text == "about 0:45", "a jump in the distance (a new spot) is not a pace")
speed = 14
nav.distance = 312
Check(navBar:IsShown() and navBar.name.text == "Mage Trainer" and navBar.sub.text == "Thunder Bluff",
    "the navigator names it and its zone")
Check(navBar.dist.text == "312 yd" and pin.scale < 1 and pin.scale > 0.65, "and shrinks the pin with distance")
Check(not pin.card.note.shown and not pin.card.icon.shown and navBar.fill.shown, "no note or icon: neither shows")
local plainH = pin.card.height
-- A note and an icon from the module that placed it: a line under the name, the icon beside it
-- and in the navigator in place of the shape.
ns.placedWaypoint.note, ns.placedWaypoint.icon = " (weapon Master)", 132
events.scripts.OnEvent(events, "USER_WAYPOINT_UPDATED")
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.note.shown and pin.card.note.text == "Weapon Master" and pin.card.height > plainH,
    "the note on its own line, the card taller")
Check(pin.card.icon.shown and pin.card.icon.texture == 132 and pin.card.name.points[1][2] == pin.card.icon, "the icon beside the name")
Check(Centred(pin.card), "with an icon, the text centres in the room beside it")
nav.distance = 23456
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.dist.point[4] == 0, "a row too long to centre starts at the column's edge, never over the icon")
nav.distance = 312
driver.scripts.OnUpdate(driver, 0)
Check(navBar.sub.text == "Weapon Master . Thunder Bluff" and navBar.icon.shown and navBar.icon.texture == 132
    and not navBar.fill.shown, "the navigator: note and zone, the icon in place of the shape")
ns.placedWaypoint.note, ns.placedWaypoint.icon = nil, nil
events.scripts.OnEvent(events, "USER_WAYPOINT_UPDATED")
driver.scripts.OnUpdate(driver, 0)
Check(not pin.card.note.shown and pin.card.height == plainH, "and back without them")
nav.distance = 20
driver.scripts.OnUpdate(driver, 0)
Check(pin.alpha < 1 and pin.alpha >= 0.25, "it fades up close")
nav.distance = 1240
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.dist.text == "1,240 yd", "long distances read with a comma")

-- Off screen to the right: at the edge, the arrow pointing right, the card toward the middle.
nav.clamped, nav.x, nav.y = true, 2400, 540
driver.scripts.OnUpdate(driver, 0)
Check(pin.point[2] == UIParent and math.abs(pin.point[4] - W * 0.3) < 0.01 and pin.point[5] == 0,
    "clamped right, it sits on the ring around the middle, not at the screen's edge")
Check(pin.arrow.shown and pin.arrow.rotation == 0 and not pin.beam.shown, "with the arrow out and no line down")
Check(pin.card.point[1] == "RIGHT" and pin.card.point[3] == "LEFT", "the card on the screen's side of it")
S.Set("waypointScale", 1.5)
driver.scripts.OnUpdate(driver, 0)
Check(math.abs(pin.point[4] * pin.scale - W * 0.3) < 0.01, "a bigger pin still sits on the ring")
-- Up and to the right, toward the minimap's corner: still on the ring, well inside the screen.
nav.x, nav.y = 960 + 3000, 540 + 3000
driver.scripts.OnUpdate(driver, 0)
local px, py = pin.point[4] * pin.scale, pin.point[5] * pin.scale
Check(math.abs((px / (W * 0.3)) ^ 2 + (py / (H * 0.3)) ^ 2 - 1) < 0.001, "toward a corner it sits on the ring")
Check(W / 2 - px > EDGE_ROOM and H / 2 - py > EDGE_ROOM,
    "and stays " .. EDGE_ROOM .. " px clear of both edges, off the minimap")
S.Set("waypointScale", nil)
-- Off the bottom edge, but not behind: the card goes above the pin, on screen.
nav.x, nav.y = 960 + 1000 * math.cos(math.rad(-50)), 540 + 1000 * math.sin(math.rad(-50))
driver.scripts.OnUpdate(driver, 0)
Check(pin:IsShown() and pin.card.point[1] == "BOTTOM" and pin.card.point[3] == "TOP", "on the bottom edge the card is above it")
nav.x, nav.y = 1200, 1600
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.point[1] == "TOP" and pin.card.point[3] == "BOTTOM", "on the top edge, below it")
-- Behind the camera (straight down): the behind-you cue instead.
nav.x, nav.y = 960, -900
driver.scripts.OnUpdate(driver, 0)
local cue = Find(function(fr) return fr.text and fr.arrow and not fr.card and not fr.mover end)
Check(not pin:IsShown() and cue:IsShown() and cue.text.text == "Behind you", "behind you, the cue shows instead")
S.Set("waypointEdge", false)
driver.scripts.OnUpdate(driver, 0)
Check(not cue:IsShown(), "and not with Edge Arrow off")
S.Set("waypointEdge", nil)
nav.clamped, nav.x, nav.y = false, 1100, 700
driver.scripts.OnUpdate(driver, 0)
Check(pin:IsShown() and pin.point[2] == navFrame, "back on screen, back on the navigation frame")
-- On screen but out past the ring, up by the minimap: on the ring with the arrow, never on the corner.
nav.x, nav.y = W - 60, H - 60
driver.scripts.OnUpdate(driver, 0)
Check(pin:IsShown() and pin.point[2] == UIParent and pin.arrow.shown
    and W / 2 - pin.point[4] * pin.scale > EDGE_ROOM and H / 2 - pin.point[5] * pin.scale > EDGE_ROOM,
    "a spot on screen in the corner gets the arrow on the ring, not a pin on the minimap")
-- Just inside the ring after being past it: it stays on the ring, so it never flickers on the line.
nav.x, nav.y = 960 + 0.95 * W * 0.3, 540
driver.scripts.OnUpdate(driver, 0)
Check(pin.point[2] == UIParent and pin.arrow.shown, "a little inside the ring it holds on the ring")
nav.x = 960 + 0.85 * W * 0.3
driver.scripts.OnUpdate(driver, 0)
Check(pin.point[2] == navFrame, "well inside, back on its spot")
-- Low on screen past the ring is in front of you, not behind: on the ring, no cue.
nav.x, nav.y = 960, 60
driver.scripts.OnUpdate(driver, 0)
Check(pin:IsShown() and pin.point[2] == UIParent and not cue:IsShown(), "a spot low on screen is not behind you")
nav.clamped = true
driver.scripts.OnUpdate(driver, 0)
Check(not pin:IsShown() and cue:IsShown(), "clamped straight down is behind you")
nav.clamped = false
-- Close by, the spot keeps its pin wherever it is on screen, so you can walk onto it.
nav.distance = 20
driver.scripts.OnUpdate(driver, 0)
Check(pin:IsShown() and pin.point[2] == navFrame and pin.alpha < 1, "within 40 yards it stays on its spot, fading up close")
nav.distance = 1240
-- With Edge Arrow off, a spot on screen keeps its pin on the spot, wherever it is.
S.Set("waypointEdge", false)
nav.x, nav.y = W - 60, H - 60
driver.scripts.OnUpdate(driver, 0)
Check(pin:IsShown() and pin.point[2] == navFrame, "Edge Arrow off: the pin stays on the spot")
S.Set("waypointEdge", nil)
nav.x, nav.y = 1100, 700
driver.scripts.OnUpdate(driver, 0)

-- A stop on the way there (a zone's exit) is not the arrival.
S.Set("waypointSound", "naowh")
local timersBefore = #timers
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", true)
driver.scripts.OnUpdate(driver, 0)
Check(pin.card.dist.text ~= "Arrived" and #timers == timersBefore and #played == 0, "a stop on the way is not an arrival")

-- Reaching a waypoint you set: the game clears its tracking and the frame goes before the
-- event reaches us. It is over at once: the sound, and nothing left on screen, no card held.
tracking = nil
events.scripts.OnEvent(events, "SUPER_TRACKING_CHANGED")
nav.frame = nil
events.scripts.OnEvent(events, "NAVIGATION_FRAME_DESTROYED")
local timersAtArrival, playedAtArrival = #timers, #played
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
Check(not pin:IsShown() and not navBar:IsShown() and driver.scripts.OnUpdate == nil, "the pin and the bar go at once")
Check(played[#played] == "sound:naowh" and #played == playedAtArrival + 1 and #timers == timersAtArrival,
    "with the sound, and no timer holding an arrival")
-- The other order: the arrival first, then the game clears it.
tracking = 1
nav.frame = navFrame
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
Check(not pin:IsShown() and not navBar:IsShown() and #played == playedAtArrival + 2, "arrival first: gone at once too")
tracking = nil
events.scripts.OnEvent(events, "SUPER_TRACKING_CHANGED")
nav.frame = nil
events.scripts.OnEvent(events, "NAVIGATION_FRAME_DESTROYED")
Check(not pin:IsShown() and not navBar:IsShown(), "and still gone once the game has cleared it")

-- A map waypoint the game does not clear: no arrival event comes, so within 5 yards the pin
-- arrives and clears it itself, once.
tracking = 1
nav.frame = navFrame
local was = nav.distance
nav.distance = 3
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
local clearedBefore, playedBefore = cleared, #played
driver.scripts.OnUpdate()
Check(pin.card.dist.text ~= "Arrived" and cleared == clearedBefore and #played == playedBefore,
    "a waypoint that starts within reach is not arrived at before you have been away from it")
nav.distance = 30
driver.scripts.OnUpdate()
Check(pin:IsShown() and cleared == clearedBefore, "30 yards out it is still up and nothing is cleared")
-- Something else changing what is tracked on the way does not make it forget you were away.
events.scripts.OnEvent(events, "SUPER_TRACKING_CHANGED")
-- Next to a stop on the way (a zone's exit), which lies on another map than the waypoint, it is not the spot.
playerMap = 1411
nav.distance = 4
driver.scripts.OnUpdate()
Check(pin.card.dist.text ~= "Arrived" and cleared == clearedBefore and #played == playedBefore,
    "next to a stop on another map the waypoint is left alone")
-- Placed on a parent map (a continent), standing in a zone inside it: that is the spot's map too.
playerMap = 1500
nav.distance = 15
driver.scripts.OnUpdate()
Check(pin.card.dist.text ~= "Arrived" and cleared == clearedBefore, "15 yards out is not there at the default 5")
-- Arrival Distance moves where it counts as there.
settings.waypointArrive = 20
driver.scripts.OnUpdate()
settings.waypointArrive = nil
Check(not pin:IsShown() and #played == playedBefore + 1, "within Arrival Distance it is over at once, with its sound, on a map inside the waypoint's")
Check(cleared == clearedBefore + 1 and superCleared >= 1, "and the waypoint is cleared")
-- The clear waits while the world map is open: standing there, nothing repeats.
Check(driver.scripts.OnUpdate == nil and cleared == clearedBefore + 1, "the pin stops following, and does not arrive or clear again")
-- A route's stop is left to the game's arrival, which is what moves the route on.
events.scripts.OnEvent(events, "NAVIGATION_FRAME_DESTROYED")
nav.distance = 30
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
routeInfo = { "Training run", 1, 3, "Weapon Master" }
ns.placedWaypoint = { title = "Mage Trainer", map = 88, x = 46.2, y = 49.8 }
userWaypoint = { uiMapID = 88, position = { x = 0.462, y = 0.498 } }
events.scripts.OnEvent(events, "SUPER_TRACKING_CHANGED")
clearedBefore = cleared
nav.distance = 4
driver.scripts.OnUpdate()
Check(cleared == clearedBefore, "on a route's stop the pin clears nothing itself")
routeInfo = nil
nav.distance = was
tracking = 1
cleared, superCleared = 0, 0

-- Placed inside a long Arrival Distance: not there at once, it arrives at the usual 5 yards.
settings.waypointArrive = 100
userWaypoint = { uiMapID = playerMap, position = { x = 0.5, y = 0.5 } }
events.scripts.OnEvent(events, "NAVIGATION_FRAME_DESTROYED")
nav.frame, nav.distance = navFrame, 60
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
driver.scripts.OnUpdate()
Check(pin:IsShown() and cleared == 0, "placed 60 yards away with Arrival Distance at 100: still up")
nav.distance = 4
driver.scripts.OnUpdate()
Check(cleared == 1, "it clears within 5 yards")
settings.waypointArrive = nil
nav.distance = was
cleared, superCleared = 0, 0

-- A stop on a route: the navigator says which, and the arrival names the next stop, or says the
-- route is done on its last.
tracking = 1
ns.placedWaypoint = { title = "Mage Trainer", map = 88, x = 46.2, y = 49.8 }
userWaypoint = { uiMapID = 88, position = { x = 0.462, y = 0.498 } }
routeInfo = { "Training run", 2, 4, "Weapon Master" }
nav.frame = navFrame
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
Check(navBar.sub.text == "Training run . 2 of 4", "the navigator shows the route and the stop")
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
Check(pin.card.note.text == "Next: Weapon Master" and navBar.sub.text == "Next: Weapon Master", "the arrival names the next stop")
timers[#timers].fn()
routeInfo = { "Training run", 4, 4, nil }
events.scripts.OnEvent(events, "USER_WAYPOINT_UPDATED")
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
Check(pin.card.note.text == "Training run done", "the last stop says the route is done")
timers[#timers].fn()
routeInfo = nil
-- A spot the route did not place (a quest) is not shown as a stop.
tracking = 0
routeInfo = { "Training run", 2, 4, "Weapon Master" }
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
Check(navBar.sub.text == "", "a quest is not a stop on it")
routeInfo = nil

-- A quest the game keeps tracking: the arrival shows, then the pin follows it again. An older
-- arrival's timer does nothing.
nav.frame = navFrame
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
Check(pin.card.name.text == "The Barrens Oases", "a quest is named from the quest log")
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
local first = timers[#timers]
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
first.fn()
Check(pin.card.dist.text == "Arrived" and driver.scripts.OnUpdate == nil, "an older arrival's timer does nothing")
timers[#timers].fn()
Check(pin:IsShown() and pin.point[2] == navFrame and driver.scripts.OnUpdate ~= nil, "then it follows the quest again")
-- A quest's navigation point is over the target (a quest giver's head), not on the ground.
Check(pin.point[5] == 0 and not pin.beam.shown and not pin.ground.shown, "a quest's pin sits on its point, no line down")
-- The game keeps tracking a quest at the quest giver, so the pin goes up close, the navigator stays.
local far = nav.distance
nav.distance = 4
driver.scripts.OnUpdate()
Check(not pin:IsShown() and navBar:IsShown(), "next to the quest giver the pin goes")
nav.distance = 6
driver.scripts.OnUpdate()
Check(not pin:IsShown(), "a step back does not bring it back, so it does not flicker")
nav.clamped, nav.x, nav.y = true, 960, -900
driver.scripts.OnUpdate()
Check(not cue:IsShown(), "with your back to the quest giver, no behind-you cue either")
nav.clamped, nav.x, nav.y = false, 1100, 700
nav.distance = far
driver.scripts.OnUpdate()
Check(pin:IsShown(), "walking away brings it back")
-- A quest's area: Forever reports a quest reached only right on its point, so the pin goes within
-- 40 yards of it and comes back past 55, wherever you walk about the area.
nav.distance = 50
driver.scripts.OnUpdate()
Check(pin:IsShown(), "coming toward a quest, 50 yards out it still points there")
nav.distance = 39
driver.scripts.OnUpdate()
Check(not pin:IsShown() and not cue:IsShown(), "within 40 yards, in the quest's area, it goes")
nav.distance = 54
driver.scripts.OnUpdate()
Check(not pin:IsShown(), "walking about the area does not bring it back")
nav.distance = 56
driver.scripts.OnUpdate()
Check(pin:IsShown(), "past 55 yards it comes back")
nav.distance = far

-- A corpse is on the ground: lifted with its line, and it does not go up close.
tracking = 2
events.scripts.OnEvent(events, "SUPER_TRACKING_CHANGED")
driver.scripts.OnUpdate()
Check(pin.point[5] == 36 / 2 + 80 and pin.beam.shown, "a corpse's pin stands over its spot")
nav.distance = 4
driver.scripts.OnUpdate()
Check(pin:IsShown(), "and stays up close")
nav.distance = far
tracking = 0
events.scripts.OnEvent(events, "SUPER_TRACKING_CHANGED")

-- A new waypoint during an arrival ends it.
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
first = timers[#timers]
events.scripts.OnEvent(events, "NAVIGATION_FRAME_CREATED")
Check(driver.scripts.OnUpdate ~= nil and pin.card.dist.text ~= "Arrived", "a new waypoint ends the arrival")
first.fn()
Check(driver.scripts.OnUpdate ~= nil, "and its timer does nothing")

-- The navigator's clear button clears the waypoint and the game's tracking.
navBar.clear.click()
Check(cleared == 1 and superCleared == 1, "the navigator clears the waypoint")
-- The game can keep its navigation frame after a clear and send no NAVIGATION_FRAME_DESTROYED.
tracking = nil
events.scripts.OnEvent(events, "SUPER_TRACKING_CHANGED")
Check(not navBar:IsShown() and not pin:IsShown() and driver.scripts.OnUpdate == nil,
    "with nothing tracked the navigator goes, though the frame stayed")
tracking = 1
events.scripts.OnEvent(events, "SUPER_TRACKING_CHANGED")
Check(navBar:IsShown() and driver.scripts.OnUpdate ~= nil, "tracking again on that frame brings it back")

-- A waypoint placed on the map is not tracked by the game, so the pin tracks it: at once when the
-- map is closed, as the map closes when it is open (placing one from an addon while it is open
-- taints it), and not when it already is, or when there is none.
userWaypoint = { uiMapID = 88, position = { x = 0.5, y = 0.5 } }
tracking = nil
local trackTimers = #timers
tracked = {}
events.scripts.OnEvent(events, "USER_WAYPOINT_UPDATED")
Check(#timers == trackTimers + 1 and #tracked == 0, "placed with the map closed: tracked after the game has finished with it")
timers[#timers].fn()
Check(tracked[1] == true and #tracked == 1, "and then it is")
mapOpen, tracked = true, {}
events.scripts.OnEvent(events, "USER_WAYPOINT_UPDATED")
Check(#tracked == 0 and mapHide ~= nil, "placed with the map open: nothing yet")
mapOpen = false
mapHide()
Check(tracked[1] == true and #tracked == 1, "tracked as the map closes")
mapHide()
Check(#tracked == 1, "once")
tracking, tracked = 1, {}
events.scripts.OnEvent(events, "USER_WAYPOINT_UPDATED")
timers[#timers].fn()
Check(#tracked == 0, "already tracked: left alone")
userWaypoint, tracking = nil, nil
trackTimers = #timers
events.scripts.OnEvent(events, "USER_WAYPOINT_UPDATED")
Check(#timers == trackTimers and #tracked == 0, "cleared: nothing to track")
tracking = 1

-- Off again: idle, and the game's marker back.
S.Set("waypoints", false)
Check(next(events.events) == nil and not pin:IsShown() and driver.scripts.OnUpdate == nil, "off, it stops listening")
Check(gameMarker.Icon.alpha == 1 and gameMarker.IconBorder.alpha == 1, "and the game's marker is back")
Check(#printed == 0, "nothing printed")

-- Optional objectives and downward arrows use the existing pin and update on quest progress.
tracking, nav.frame, nav.distance = 0, navFrame, 20
questObjectives = { { text = "0/10 Highlands Bandit slain", finished = false },
    { text = "0/1 Bennic slain", finished = false }, { text = "Done", finished = true } }
S.Set("waypoints", true)
Check(pin.objectives == nil and pin.down == nil, "new presentation switches default off without extra frames/textures")
S.Set("waypointObjectives", true)
S.Set("waypointDownArrows", true)
driver.scripts.OnUpdate()
Check(pin:IsShown() and pin.objectives.shown, "objectives keep the quest pin visible inside its area")
Check(pin.objectives.text.text == "0/10 Highlands Bandit slain\n0/1 Bennic slain", "only unfinished objectives shown")
Check(pin.down[1].shown and pin.down[3].shown and pin.down[1].rotation == -math.pi / 2, "three downward chevrons")
Check(pin.card.point[5] > 8, "title card makes room above the arrows")
questObjectives[1].text = "1/10 Highlands Bandit slain"
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
driver.scripts.OnUpdate()
Check(pin.objectives.text.text:find("1/10", 1, true), "quest progress updates in place")
questObjectives[1].text = "secret"
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
driver.scripts.OnUpdate()
Check(pin.objectives.text.text == "0/1 Bennic slain", "restricted objective text is skipped")
questObjectives[1].text = "1/10 Highlands Bandit slain"
questObjectives[1].finished, questObjectives[2].finished = true, true
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
driver.scripts.OnUpdate()
Check(not pin.objectives.shown, "completed objectives do not leave a stale panel")
questObjectives[1].finished, questObjectives[2].finished = false, false
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
driver.scripts.OnUpdate()
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
Check(driver.scripts.OnUpdate ~= nil and pin:IsShown(), "arrival does not hide unfinished quest objectives")
nav.distance, nav.clamped, nav.x, nav.y = 300, true, 1900, 700
driver.scripts.OnUpdate()
Check(not pin.objectives.shown and not pin.down[1].shown, "off-screen direction does not show downward arrows or objective panel")
nav.clamped, nav.x, nav.y = false, 1100, 700
S.Set("waypointCard", false)
driver.scripts.OnUpdate()
Check(pin.objectives.shown and not pin.card.shown and pin.objectives.point[5] > 8,
    "objectives work without the name card and leave room for chevrons")
S.Set("waypointObjectives", false)
driver.scripts.OnUpdate()
Check(not pin.objectives.shown and not events.events.QUEST_LOG_UPDATE, "objectives off releases its event")
S.Set("waypoints", false)
Check(next(events.events) == nil and driver.scripts.OnUpdate == nil, "all waypoint features stop while off")

questObjectives = {}
tracking, nav.distance = 1, 3
userWaypoint = { uiMapID = 88, position = { x = 0.45, y = 0.60 } }
ns.placedWaypoint = { title = "Guide step", map = 88, x = 45, y = 60,
    details = { guide = true, quest = 7, title = "The Criminal Element", objectives = "0/10 Bandits" } }
S.Set("waypoints", true)
S.Set("waypointObjectives", true)
S.Set("waypointCard", true)
driver.scripts.OnUpdate()
Check(pin.card.name.text == "The Criminal Element" and pin.objectives.text.text == "0/10 Bandits",
    "guide title and objective context reach the world pin")
routeInfo = { "The Criminal Element", 1, 3, "Fly to Sentinel Hill" }
ns.placedWaypoint.title = "Deeprun Tram to Stormwind"
ns.RefreshWaypointPin()
driver.scripts.OnUpdate()
Check(pin.card.name.text == "Deeprun Tram to Stormwind" and pin.objectives.text.text == "0/10 Bandits",
    "on a guide journey the pin names the step to take, with the guide's objectives")
routeInfo = nil
ns.placedWaypoint.title = "Guide step"
ns.RefreshWaypointPin()
local guideClears = cleared
nav.distance = 100
driver.scripts.OnUpdate()
nav.distance = 3
driver.scripts.OnUpdate()
Check(cleared == guideClears and pin:IsShown(), "guide pin skips manual distance auto-clear")
events.scripts.OnEvent(events, "NAVIGATION_DESTINATION_REACHED", false)
Check(driver.scripts.OnUpdate ~= nil, "guide arrival leaves guide advancement in charge")
S.Set("waypoints", false)

print(("test-waypoints: %d checks passed"):format(checks))
