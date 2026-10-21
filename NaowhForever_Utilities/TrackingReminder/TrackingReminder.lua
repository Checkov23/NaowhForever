-- TrackingReminder.lua: the Tracking Reminder's settings (ns.TrackingReminderSettings) and module table (ns.TrackingReminder).
local ns = _G.NaowhForever

local F = ns.FEATURES.trackingReminder

local S = ns.UI.ModuleSettings("trackingReminder", {
    enabled = F.enabled,
    trackRacial = F.trackRacial,
    trackClass = F.trackClass,
    racialPicks = {},
    classPicks = {},
    inInstances = false,
    iconSize = 40,
    trackingFont = "",
    trackingFontSize = 13,
    trackingOutline = "OUTLINE",
    trackingPos = nil,
})
ns.TrackingReminderSettings = S

local TR = {
    Settings = S,
    PAGE = "Racial and Class Tracking/Settings",
}
ns.TrackingReminder = TR

function TR.Enabled()
    return S.Get("enabled") and true or false
end

function TR.On()
    return TR.Enabled() and (S.Get("trackRacial") or S.Get("trackClass")) and true or false
end
