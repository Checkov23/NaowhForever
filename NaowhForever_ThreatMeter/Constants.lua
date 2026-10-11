-- Constants.lua: the sizes and names the Threat Meter's files share.
local ns = _G.NaowhForever

ns.ThreatMeter.C = {
    PAGE = "Threat Meter/Settings",
    MIN_WIDTH = 160, MIN_HEIGHT = 50, MAX_WIDTH = 520, MAX_HEIGHT = 700,
    MIN_BAR = 12, MAX_BAR = 72, MAX_SPACING = 16, MIN_FONT = 8, MAX_FONT = 24,
    INSET = 8, FOOTER = 24, HEADER = 48,
    LINE_NAME = ns.L("Aggro Line"),
    PERCENT = 100,
    ROUND = 0.5,
    GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
    GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
}
