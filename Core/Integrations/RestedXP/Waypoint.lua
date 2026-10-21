-- Waypoint.lua: an optional guide destination feed for the Waypoint Pin.
local ns = _G.NaowhForever

local ADDON = "RXPGuides"
local MAX_LINES = 6
local PERCENT = 100
local TEXT_GUIDE = ns.L("Guide destination")

local hooked, settingsHooked, active
local lastMap, lastX, lastY
local lastGuide, lastStep
local details, lastTitle
local lines = {}
local events
local OnSetting, OnEvent

local function On()
    local S = ns.QoLSettings
    return S and S.Get("enabled") and S.Get("waypoints") and S.Get("waypointRestedXP")
        and ns.WaypointPinOn and ns.WaypointPinOn()
end

local function Plain(text)
    if issecretvalue and issecretvalue(text) then return end
    if type(text) ~= "string" then return end
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:match("^%s*(.-)%s*$")
    if text ~= "" then return text end
end

local function ElementText(element)
    local frame = element.frame
    local text = frame and frame.text
    return Plain(text and text.GetText and text:GetText()) or Plain(element.text)
        or Plain(element.tooltipText) or Plain(element.rawtext)
end

local function ReadDetails(element)
    wipe(lines)
    local quest = element.questId or element.parent and element.parent.questId
    local step = element.step
    local list = step and step.elements
    if type(list) == "table" then
        for _, other in ipairs(list) do
            if other.tag == "complete" and not (other.completed or other.skip) then
                quest = quest or other.questId
                local text = ElementText(other)
                if text then lines[#lines + 1] = text end
                if #lines == MAX_LINES then break end
            end
        end
    end
    if type(quest) ~= "number" or quest <= 0 then quest = nil end
    local title = quest and C_QuestLog.GetTitleForQuestID(quest)
    title = title or Plain(element.title) or step and Plain(step.title) or TEXT_GUIDE
    return title, quest, #lines > 0 and table.concat(lines, "\n") or ElementText(element.parent or element)
end

local function Stop()
    ns.ClearGuideWaypoint()
    lastMap, lastX, lastY, lastTitle, details = nil, nil, nil, nil, nil
    lastGuide, lastStep = nil, nil
end

local function Sync(force)
    if not On() then return end
    local rxp = _G.RXP
    local arrow = rxp and rxp.arrowFrame
    local profile = rxp and rxp.settings and rxp.settings.profile
    local element = arrow and arrow.element
    local waypoints = rxp and rxp.activeWaypoints
    if not (rxp and rxp.currentGuide and profile and profile.showEnabled ~= false
        and (not rxp.hideArrow or profile.disableArrow == true) and type(element) == "table")
        or type(waypoints) == "table" and #waypoints == 0 then Stop() return end
    local map, x, y = element.zone, element.x, element.y
    if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number"
        or x ~= x or y ~= y or x < 0 or x > PERCENT or y < 0 or y > PERCENT or element.completed
        or element.parent and (element.parent.completed or element.parent.skip)
        or element.step and element.step.active == false then
        Stop()
        return
    end
    if element.skip then
        local step = element.step
        if profile.disableArrow and rxp.currentGuide == lastGuide and step == lastStep
            and step and step.active and step.loop then return end
        Stop()
        return
    end
    local changed = map ~= lastMap or x ~= lastX or y ~= lastY
    local routing = details ~= nil and ns.JourneyDetails and ns.JourneyDetails() == details
    if not force and not changed and not routing and not ns.GuideWaypointIsCurrent() then return end
    local title, quest, objectives = ReadDetails(element)
    if force or changed then
        details = { guide = true, quest = quest, objectives = objectives, title = title }
        if not ns.SetGuideWaypoint(title, map, x, y, details) then Stop() return end
        lastMap, lastX, lastY, lastTitle = map, x, y, title
    elseif details.quest ~= quest or details.objectives ~= objectives or lastTitle ~= title then
        details.quest, details.objectives, details.title = quest, objectives, title
        local placed = ns.placedWaypoint
        if placed and placed.details == details and placed.title == lastTitle then placed.title = title end
        lastTitle = title
        if ns.RefreshWaypointPin then ns.RefreshWaypointPin() end
    end
    lastGuide, lastStep = rxp.currentGuide, element.step
end

local function OnGuideUpdate()
    Sync(false)
end

local function OnMapUpdate()
    if not On() then return end
    local rxp = _G.RXP
    local profile = rxp and rxp.settings and rxp.settings.profile
    if profile and profile.disableArrow then return end
    Sync(false)
end

local function HookGuide()
    local rxp = _G.RXP
    if hooked or not (rxp and type(rxp.UpdateMap) == "function" and type(rxp.UpdateGotoSteps) == "function") then return end
    hooked = true
    hooksecurefunc(rxp, "UpdateMap", OnMapUpdate)
    hooksecurefunc(rxp, "UpdateGotoSteps", OnGuideUpdate)
end

local function Apply()
    local S = ns.QoLSettings
    if S and not settingsHooked then
        settingsHooked = true
        hooksecurefunc(S, "Set", OnSetting)
    end
    local on = On() and true or false
    if not on then
        if events then events:UnregisterAllEvents() end
        if active then Stop() end
        active = false
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    local first = not active
    active = true
    HookGuide()
    if not hooked then events:RegisterEvent("ADDON_LOADED") end
    Sync(first)
end

function ns.RestedXPPin()
    local rxp = _G.RXP
    local steps = rxp and rxp.RXPFrame and rxp.RXPFrame.activeSteps
    if type(steps) ~= "table" then return false end
    for _, step in ipairs(steps) do
        local list = type(step) == "table" and step.elements
        if type(list) == "table" then
            for _, element in ipairs(list) do
                if element.waypointSet == true and type(element.zone) == "number" then
                    local pos = C_Map.GetUserWaypointPositionForMap(element.zone)
                    if pos and pos.x == element.zx and pos.y == element.zy then return true end
                end
            end
        end
    end
    return false
end

function OnSetting(key)
    if key == "enabled" or key == "waypoints" or key == "waypointRestedXP" then Apply() end
end

function OnEvent(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        HookGuide()
        if hooked then events:UnregisterEvent("ADDON_LOADED") end
        Sync(true)
    end
end

hooksecurefunc(ns, "Apply", Apply)
