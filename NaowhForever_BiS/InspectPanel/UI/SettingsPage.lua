-- SettingsPage.lua: the Inspect Panel's card on BiS List > Character.
local ns = _G.NaowhForever

local IP = ns.InspectPanel
local S = ns.QoLSettings

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local BADGES_LIVE = ns.BADGES_LIVE
local ORDER_INSPECT = 15
local TEXT_THEIRS_IN_USE = ns.L("EllesmereUI's inspect window is in use: switch this off and on for this one")
local TEXT_TAKES_OVER = ns.L("Takes over from EllesmereUI's inspect window, after a reload")
local TEXT_BADGE_AND_SCORE = ns.L("With their badge and Naowh Score")
local TEXT_BADGE = ns.L("With their badge")
local TEXT_SCORE = ns.L("With their Naowh Score")
local TEXT_PLAIN = ns.L("Their gear, talents and history")

local function Summary(store)
    if IP.EllesmereSheet() then
        return store.Get("inspectPanel") and TEXT_THEIRS_IN_USE or TEXT_TAKES_OVER
    end
    local badge = ns.FEATURE_BADGES == BADGES_LIVE and store.Get("inspectPanelBadge")
    local score = store.Get("inspectPanelScore")
    if badge and score then return TEXT_BADGE_AND_SCORE end
    if badge then return TEXT_BADGE end
    if score then return TEXT_SCORE end
    return TEXT_PLAIN
end

local rows = {
    { key = "inspectPanelScore", label = "Naowh Score", toggle = true,
      help = "Their Naowh Score at the top of the panel, with yours under it." },
    { key = "inspectPanelShareBis", label = "Share Your BiS", toggle = true, always = true,
      help = "Shows your BiS stars to players who inspect you with Naowh Forever." },
}
if ns.FEATURE_BADGES == BADGES_LIVE then
    table.insert(rows, 1, { key = "inspectPanelBadge", label = "Supporter Badge", toggle = true,
        help = "Their supporter badge in the window's corner, if they have one." })
end

Settings.Page("BiS List/Character", S):Card({
    id = "inspectPanel", name = "Inspect Panel", order = ORDER_INSPECT, switch = "inspectPanel", store = S,
    help = "The inspect window in the BiS List's look, with their score, gear check, talents and history.",
    search = "note notes tag tags player tab",
    summary = Summary,
    rows = rows,
})
