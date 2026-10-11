-- SettingsPage.lua: the Naowh Score's card on BiS List > Character.
local ns = _G.NaowhForever

local Score = ns.NaowhScore
local S = ns.QoLSettings

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local C = Score.COMPARE
local COMPARE = { { [C.MAX] = "Best in the Game", [C.LEVEL] = "Best for Their Level", [C.BOTH] = "Both" },
    { C.MAX, C.LEVEL, C.BOTH } }
local ORDER_SCORE = 30
local TEXT_YOURS_NOW = ns.L("Yours now: ")

local function Summary()
    return TEXT_YOURS_NOW .. Score.Colored((Score.Unit("player")), UnitLevel("player"))
end

Settings.Page("BiS List/Character", S):Card({
    id = "naowhScore", name = "Naowh Score", order = ORDER_SCORE, switch = "naowhScore", store = S,
    help = "One number for a character's gear, on the item level scale: 26.4 means gear worth a set of level "
        .. "26 epics. Your own is always on the BiS List's paperdoll.",
    summary = Summary,
    rows = {
        { key = "naowhScoreShare", label = "Share My Score", toggle = true,
          help = "Sends your score to your group and guild as it changes." },
        { key = "naowhScoreTooltip", label = "On Player Tooltips", toggle = true,
          help = "A player's score on their tooltip. One running Naowh Forever shares theirs; anyone else's is "
              .. "read from their gear when you hover them, within inspect range and out of combat." },
        { key = "naowhScoreScan", label = "Scan Your Group", toggle = true,
          help = "Reads your group members' gear in the background, one at a time while they are in range and "
              .. "out of combat, so their scores are ready before you hover them." },
        { key = "naowhScoreNearby", label = "Scan Players Nearby", toggle = true,
          help = "Reads the gear of the players around you in the background: your target, focus, mouseover "
              .. "and everyone whose nameplate shows, one at a time in inspect range and out of combat." },
        { key = "naowhScoreCompare", label = "Grade Against", choice = COMPARE,
          help = "Grades a score by its share of the best: in the game, for their level, or Both." },
    },
})
