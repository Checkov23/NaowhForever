-- GameTrackerFade.lua: Hide the Game's Quest Tracker: the game's tracker faded while ours is up in a dungeon.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Tracker = J.QuestTracker

local FADED, SHOWN = 0, 1

local gameFaded, gameHooked = false, false

local function KeepFaded(frame)
    if gameFaded and frame:GetAlpha() ~= FADED then frame:SetAlpha(FADED) end
end

local function ShouldFade()
    return S.Get("enabled") and S.Get("hideGameTracker") and not ns.GamepadStandDown() and Tracker.IsShown()
        and J.Current() ~= nil
end

function Tracker.SyncGameTracker()
    local frame = _G.ObjectiveTrackerFrame
    if not frame then return end
    if ShouldFade() then
        if not gameHooked then
            gameHooked = true
            hooksecurefunc(frame, "Show", KeepFaded)
            hooksecurefunc(frame, "SetAlpha", KeepFaded)
        end
        gameFaded = true
        frame:SetAlpha(FADED)
    elseif gameFaded then
        gameFaded = false
        frame:SetAlpha(SHOWN)
    end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "hideGameTracker" then Tracker.SyncGameTracker() end
end

S.OnChange(OnSettingChanged)
