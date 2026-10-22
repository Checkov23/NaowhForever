-- Constants.lua: the names, settings, timings and limits Glimmer's files share.
local ns = _G.NaowhForever

ns.Glimmer.C = {
    PAGE = "QoL/Glimmer",
    UNIT = "softinteract",
    BOBBER = 35591,
    GUID_OBJECT = "^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-",
    PROFESSION_OF = { ore = 186, herb = 182 },
    SKILL_ORANGE = 25, SKILL_YELLOW = 50, SKILL_GREEN = 100,
    INTERACT_CVAR = "SoftTargetInteract",
    INTERACT_ON = "3",
    SOFT_CVARS = {
        SoftTargetInteractOnlyInRange = "0",
        SoftTargetIconGameObject = "1",
    },
    RANGE_CVAR = "SoftTargetInteractRange",
    ARC_CVAR = "SoftTargetInteractArc",
    PLATE_CVAR = "SoftTargetNameplateInteract",
    SPARKLE_CVARS = {
        outlineModeShowLootEffectWhenDisabled = "1",
    },
    SPARKLE_RESETS = { graphicsquality = true, raidgraphicsquality = true },
    SPARKLE_AGAIN = 1,
    CURSOR_WORDS = { herb = "herb", mine = "ore", quest = "quest" },
    CURSOR_UNABLE = "unable",
    STATE_CHECK = 0.15,
    STATE_HOLD = 0.15,
    OTHER_ADDONS = { "Lueur", "ForeverLootSparkles" },
    ICON_SPELL = { herb = 2383, ore = 2580 },
    SPOT_SCALE = 1000,
    SNAP = 15,
    MAX_GATHERED = 400,
    MINIMAP_MAX = 40,
    MAP_EVENTS = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD",
        "SKILL_LINES_CHANGED", "PLAYER_REGEN_ENABLED", "MINIMAP_UPDATE_TRACKING" },
}
