-- Waypoint.lua: an optional guide destination feed for the Waypoint Pin.
local ns = _G.NaowhForever

local ADDON = "RXPGuides"
local MAX_LINES = 6
local PERCENT = 100
local TEXT_GUIDE = ns.L("Guide destination")

local hooked, settingsHooked, active
local lastElement, lastMap, lastX, lastY
local details, lastTitle
local hidden, oldTextureAlpha, oldTextAlpha
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

local function RestoreArrow()
    if not hidden then return end
    hidden.texture:SetAlpha(oldTextureAlpha)
    hidden.text:SetAlpha(oldTextAlpha)
    hidden = nil
end

local function FadeArrow(arrow)
    if not arrow.texture or not arrow.text then return end
    if hidden ~= arrow then
        RestoreArrow()
        hidden = arrow
        oldTextureAlpha, oldTextAlpha = arrow.texture:GetAlpha(), arrow.text:GetAlpha()
    end
    arrow.texture:SetAlpha(0)
    arrow.text:SetAlpha(0)
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
    RestoreArrow()
    lastElement, lastMap, lastX, lastY, lastTitle, details = nil, nil, nil, nil, nil, nil
end

local function Sync(force)
    if not On() then return end
    local rxp = _G.RXP
    local arrow = rxp and rxp.arrowFrame
    local profile = rxp and rxp.settings and rxp.settings.profile
    local element = arrow and arrow.element
    if not (rxp and rxp.currentGuide and profile and profile.showEnabled ~= false
        and not rxp.hideArrow and type(element) == "table") then Stop() return end
    local map, x, y = element.zone, element.x, element.y
    if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number"
        or x ~= x or y ~= y or x < 0 or x > PERCENT or y < 0 or y > PERCENT or element.completed or element.skip
        or element.parent and (element.parent.completed or element.parent.skip)
        or element.step and element.step.active == false then
        Stop()
        return
    end
    local changed = element ~= lastElement or map ~= lastMap or x ~= lastX or y ~= lastY
    if not force and not changed and not ns.GuideWaypointIsCurrent() then RestoreArrow() return end
    local title, quest, objectives = ReadDetails(element)
    if force or changed then
        details = { guide = true, quest = quest, objectives = objectives, title = title }
        if not ns.SetGuideWaypoint(title, map, x, y, details) then Stop() return end
        lastElement, lastMap, lastX, lastY, lastTitle = element, map, x, y, title
    elseif details.quest ~= quest or details.objectives ~= objectives or lastTitle ~= title then
        details.quest, details.objectives, details.title = quest, objectives, title
        local placed = ns.placedWaypoint
        if placed and placed.details == details then placed.title = title end
        lastTitle = title
        if ns.RefreshWaypointPin then ns.RefreshWaypointPin() end
    end
    FadeArrow(arrow)
end

local function OnGuideUpdate()
    Sync(false)
end

local function HookGuide()
    local rxp = _G.RXP
    if hooked or not (rxp and type(rxp.UpdateMap) == "function" and type(rxp.UpdateGotoSteps) == "function") then return end
    hooked = true
    hooksecurefunc(rxp, "UpdateMap", OnGuideUpdate)
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
    events:RegisterEvent("USER_WAYPOINT_UPDATED")
    events:RegisterEvent("SUPER_TRACKING_CHANGED")
    Sync(first)
end

function OnSetting(key)
    if key == "enabled" or key == "waypoints" or key == "waypointRestedXP" then Apply() end
end

function OnEvent(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            HookGuide()
            if hooked then events:UnregisterEvent("ADDON_LOADED") end
            Sync(true)
        end
    elseif not ns.GuideWaypointIsCurrent() then
        RestoreArrow()
    end
end

hooksecurefunc(ns, "Apply", Apply)
