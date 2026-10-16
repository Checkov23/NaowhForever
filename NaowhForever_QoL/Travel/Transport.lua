-- Transport.lua: boat and zeppelin estimates from a recorded sighting, their HUD and Travel settings.
local ns = _G.NaowhForever

local GetServerTime = GetServerTime
local UnitPosition = UnitPosition
local S, UI = ns.QoLSettings, ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts
local Times = ns.TransportTimes

local WIDTH, HEIGHT, PAD = 300, 96, 10
local TITLE_SIZE, TEXT_SIZE = 13, 12
local TITLE_Y, ROUTE_Y, STATUS_Y, BUTTON_Y = -10, -28, -46, -64
local BUTTON_W, BUTTON_H, BUTTON_GAP = 88, 22, 6
local UPDATE_EVERY, MOVE_EVERY = 1, 0.5
local SECONDS_PER_MINUTE = ns.QoLConstants.SECONDS_PER_MINUTE
local NEAR_YARDS = 200
local PERCENT = ns.QoLConstants.PERCENT
local FIRST_LABEL, LABEL_STEP = 4, 2
local PAGE, CARD = "QoL/Travel", "QoL/Travel:transportTimers"
local NEARBY, PLAYER = "nearby", "player"
local TITLE = ns.L("Boat and Zeppelin Timers")
local TEXT_NEARBY = ns.L("Nearby dock")
local TEXT_ESTIMATE = ns.L("Estimate: %s in %d:%02d")
local TEXT_ARRIVES, TEXT_LEAVES = ns.L("arrives"), ns.L("leaves")
local TEXT_SIGHTING = ns.L("Record an arrival or departure to start the estimate.")
local TEXT_STALE = ns.L("Server clock changed; record a new sighting.")
local TEXT_EXPIRED = ns.L("Estimate is out of date; record a new sighting.")
local TEXT_SELECT = ns.L("%s: %s")
local TEXT_RESET = ns.L("Reset")
local TEXT_ARRIVED, TEXT_DEPARTED = ns.L("Arrived"), ns.L("Departed")
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }

local frame, events, docks, labels, order, selected
local elapsed, moveElapsed = 0, 0
local inWorld = true

local function On()
    return S.Get("enabled") == true and S.Get("transportTimers") == true
end

local function Prepare()
    if docks then return end
    docks, labels, order = {}, { [NEARBY] = TEXT_NEARBY }, {}
    for map, pins in pairs(ns.TownTravel) do
        local info = C_Map.GetMapInfo(map)
        for index, pin in ipairs(pins) do
            for label = FIRST_LABEL, #pin, LABEL_STEP do
                local key = map .. ":" .. index .. ":" .. label
                docks[key] = { map = map, x = pin[1] / PERCENT, y = pin[2] / PERCENT }
                labels[key] = TEXT_SELECT:format(info and info.name or tostring(map), ns.L(pin[label]))
                order[#order + 1] = key
            end
        end
    end
    table.sort(order)
    table.insert(order, 1, NEARBY)
end

local function Choices()
    Prepare()
    return labels, order
end

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function Nearest(choice)
    local x, y, _, continent = UnitPosition(PLAYER)
    if not x or Secret(x) or Secret(y) then return nil end
    local best, distance = nil, NEAR_YARDS * NEAR_YARDS
    for _, key in ipairs(order) do
        local dock = docks[key]
        if dock and (choice == NEARBY or choice == key) then
            if not dock.world then
                dock.continent, dock.world = C_Map.GetWorldPosFromMapPos(dock.map, CreateVector2D(dock.x, dock.y))
            end
            local point = dock.world
            if dock.continent == continent and point and not Secret(point.x) and not Secret(point.y) then
                local dx, dy = point.x - x, point.y - y
                local yards = dx * dx + dy * dy
                if yards < distance then best, distance = key, yards end
            end
        end
    end
    return best
end

local function Paint()
    local seconds, kind = Times.Next(selected, GetServerTime())
    frame.arrived:SetEnabled(selected ~= nil)
    frame.departed:SetEnabled(selected ~= nil)
    frame.reset:SetEnabled(selected ~= nil)
    if seconds then
        local rounded = math.ceil(seconds)
        frame.status:SetText(TEXT_ESTIMATE:format(kind == "arrival" and TEXT_ARRIVES or TEXT_LEAVES,
            math.floor(rounded / SECONDS_PER_MINUTE), rounded % SECONDS_PER_MINUTE))
    elseif kind == "stale" then frame.status:SetText(TEXT_STALE)
    elseif kind == "expired" then frame.status:SetText(TEXT_EXPIRED)
    else frame.status:SetText(TEXT_SIGHTING) end
    return seconds ~= nil
end

local Refresh

local function OnUpdate(_, delta)
    elapsed = elapsed + delta
    if elapsed < UPDATE_EVERY then return end
    elapsed = 0
    Refresh()
end

local function OnMove(_, delta)
    moveElapsed = moveElapsed + delta
    if moveElapsed < MOVE_EVERY then return end
    moveElapsed = 0
    Refresh()
end

Refresh = function()
    if not On() then return end
    Prepare()
    selected = inWorld and Nearest(S.Get("transportDock")) or nil
    if not selected then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        return
    end
    frame.route:SetText(labels[selected])
    frame:SetScript("OnUpdate", Paint() and OnUpdate or nil)
    frame:Show()
end

local function Arrived()
    if not On() then return end
    Refresh()
    if not selected then return end
    Times.Record(selected, "arrival", GetServerTime())
    Refresh()
end

local function Departed()
    if not On() then return end
    Refresh()
    if not selected then return end
    Times.Record(selected, "departure", GetServerTime())
    Refresh()
end

local function Reset()
    if not On() then return end
    Refresh()
    if not selected then return end
    Times.Clear(selected)
    Refresh()
end

local function SavePosition(pos)
    S.Set("transportTimersPos", { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y })
end

local function Text(size, y, color)
    local text = ns.Font(frame, size, nil, color)
    text:SetPoint("TOPLEFT", PAD, y)
    text:SetWidth(WIDTH - PAD - PAD)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function Build()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    Parts.HudBackdrop(frame)
    Text(TITLE_SIZE, TITLE_Y):SetText(TITLE)
    frame.route = Text(TEXT_SIZE, ROUTE_Y, T.muted)
    frame.status = Text(TEXT_SIZE, STATUS_Y, T.accent)
    frame.arrived = ns.Button(frame, TEXT_ARRIVED, BUTTON_W, BUTTON_H, Arrived)
    frame.arrived:SetPoint("TOPLEFT", PAD, BUTTON_Y)
    frame.departed = ns.Button(frame, TEXT_DEPARTED, BUTTON_W, BUTTON_H, Departed)
    frame.departed:SetPoint("LEFT", frame.arrived, "RIGHT", BUTTON_GAP, 0)
    frame.reset = ns.Button(frame, TEXT_RESET, BUTTON_W, BUTTON_H, Reset)
    frame.reset:SetPoint("LEFT", frame.departed, "RIGHT", BUTTON_GAP, 0)
    UI.AttachMover(frame, "Boat and Zeppelin Timers", SavePosition, PAGE, CARD)
end

local function Watch()
    local map = C_Map.GetBestMapForUnit(PLAYER)
    moveElapsed = 0
    events:SetScript("OnUpdate", inWorld and map and ns.TownTravel[map] and IsPlayerMoving() and OnMove or nil)
end

local function OnEvent(_, event)
    if event == "PLAYER_LEAVING_WORLD" then
        inWorld = false
        events:SetScript("OnUpdate", nil)
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        selected = nil
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        inWorld = true
        Times.Prune(GetServerTime())
    end
    Watch()
    Refresh()
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents(); events:SetScript("OnUpdate", nil) end
        if frame then frame:SetScript("OnUpdate", nil); frame:Hide() end
        selected = nil
        return
    end
    if not frame then Build() end
    local pos = S.Get("transportTimersPos")
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if IsLoggedIn() then Times.Prune(GetServerTime()) end
    Watch()
    Refresh()
end

local function OnSetting(key)
    if key == "enabled" or key == "transportTimers" or key == "transportDock" then Apply() end
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
Apply()

ns.Shared.Settings.Page(PAGE, S):Card({
    id = "transportTimers", name = "Boat and Zeppelin Timers", order = 13, switch = "transportTimers",
    help = "Estimate the next arrival or departure from stops you record at a dock.",
    rows = {
        { key = "transportDock", label = "Dock and Route", choice = Choices,
          help = "Track a nearby dock or choose a specific route to watch." },
    },
})
