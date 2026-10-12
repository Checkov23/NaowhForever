-- Discovery.lua: Discovery's settings and its module table (ns.Discovery).
local ns = _G.NaowhForever

local F = ns.FEATURES.discovery

local TRACKER_ALPHAS = { "trackerAlpha", "bagTrackerAlpha" }

local S = ns.UI.ModuleSettings("discovery", {
    enabled = F.enabled,
    tracker = F.tracker, trackerAlways = false, trackerScale = 1, mapPins = F.mapPins, mapPinSize = 20,
    mapTurnIn = true,
    nearbySound = F.nearbySound, nearbyRange = 40, nearbyPing = true, nearbyChat = true, openMap = true,
    windowAlpha = 1,
    trackerAlpha = 1,
    bagTracker = F.bagTracker, bagTrackerScale = 1, bagTrackerAlpha = 1, bagMapPins = F.bagMapPins,
    bagMapPinSize = 20,
})
ns.DiscoverySettings = S

ns.Discovery = { Settings = S }

local function SplitOpacity()
    local was = S.Raw("windowAlpha")
    if was == nil then return end
    for _, key in ipairs(TRACKER_ALPHAS) do
        if S.Raw(key) == nil then S.Set(key, was) end
    end
end

hooksecurefunc(ns, "Apply", SplitOpacity)
