-- HideClutter.lua: UI Clutter, the game's alerts, toasts, zone and error text and tutorials hidden.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local TOAST_CLOSE_DELAY = 0.05
local TUTORIAL_CVARS = { showTutorials = "0", hideHelptips = "1" }
local CINEMATIC_KEY, ZONE_JOIN = "cinematic:", "/"
local MOVIE_KEY = "movie:"
local CLUTTER = { "hideErrors", "hideTutorials", "hideScreenshot", "skipCinematics", "hideAlerts",
    "hideEventToasts", "hideZoneText", "hideBagBar" }
local APPLY_KEYS = { enabled = true, hideErrors = true, hideTutorials = true, hideScreenshot = true,
    skipCinematics = true, hideBagBar = true }
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
    "CharacterBag3Slot", "KeyRingButton", "BagBarExpandToggle" }
local SUMMARY = ns.L("%d of %d on")

local errorsHidden, screenshotHidden, movieHooked = false, false, false
local bagBarHidden = false

local function On(key)
    return S.Get("enabled") and S.Get(key) and true or false
end

local function OnAlertAdded(_, frame)
    if On("hideAlerts") then frame:Hide() end
end

local function OnZoneTextShow(self)
    if On("hideZoneText") then self:Hide() end
end

local function CloseToasts(self)
    if self:IsShown() and not (self.HideButton and self.HideButton:IsShown()) then
        self:CloseActiveToasts()
    end
end

local function OnToast(self)
    if not On("hideEventToasts") then return end
    C_Timer.After(TOAST_CLOSE_DELAY, function() CloseToasts(self) end)
end

local function SeenBefore(key)
    local account = ns.AccountSettings()
    account.seenCinematics = account.seenCinematics or {}
    local seen = account.seenCinematics[key]
    account.seenCinematics[key] = true
    return seen
end

local function CancelCinematic()
    if InCinematic() then CinematicFrame_CancelCinematic() end
end

local function OnCinematicStart(_, _, canBeCancelled)
    if not canBeCancelled then return end
    if SeenBefore(CINEMATIC_KEY .. GetZoneText() .. ZONE_JOIN .. GetSubZoneText()) then
        C_Timer.After(0, CancelCinematic)
    end
end

local function OnMovie(self, movieID)
    if On("skipCinematics") and self.movieID == movieID and SeenBefore(MOVIE_KEY .. movieID)
        and not InCombatLockdown() then
        self:FinishMovie()
    end
end

local cinematics = CreateFrame("Frame")
cinematics:SetScript("OnEvent", OnCinematicStart)

local function ApplyTutorials()
    local account = ns.AccountSettings()
    if On("hideTutorials") then
        if not account.tutorialCVars then
            local saved = {}
            for name in pairs(TUTORIAL_CVARS) do saved[name] = C_CVar.GetCVar(name) end
            account.tutorialCVars = saved
        end
        for name, value in pairs(TUTORIAL_CVARS) do C_CVar.SetCVar(name, value) end
    elseif account.tutorialCVars then
        for name, value in pairs(account.tutorialCVars) do C_CVar.SetCVar(name, value) end
        account.tutorialCVars = nil
    end
end

local function ApplyErrors()
    local hide = On("hideErrors")
    if hide == errorsHidden then return end
    if hide then
        UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    else
        UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    end
    errorsHidden = hide
end

local function ApplyScreenshot()
    local hide = On("hideScreenshot")
    if hide == screenshotHidden then return end
    if hide then
        ActionStatus:UnregisterEvent("SCREENSHOT_SUCCEEDED")
        ActionStatus:UnregisterEvent("SCREENSHOT_FAILED")
    else
        ActionStatus:RegisterEvent("SCREENSHOT_SUCCEEDED")
        ActionStatus:RegisterEvent("SCREENSHOT_FAILED")
    end
    screenshotHidden = hide
end

local function ApplyCinematics()
    if not On("skipCinematics") then
        cinematics:UnregisterEvent("CINEMATIC_START")
        return
    end
    cinematics:RegisterEvent("CINEMATIC_START")
    if not movieHooked then
        hooksecurefunc(MovieFrame, "PlayMovie", OnMovie)
        movieHooked = true
    end
end

local function ApplyBagBar()
    local hide = On("hideBagBar")
    if hide == bagBarHidden then return end
    BagsBar:SetAlpha(hide and 0 or 1)
    for _, name in ipairs(BAG_BUTTONS) do _G[name]:EnableMouse(not hide) end
    bagBarHidden = hide
end

local function Apply()
    ApplyErrors()
    ApplyScreenshot()
    ApplyTutorials()
    ApplyCinematics()
    ApplyBagBar()
end

local function OnSettingChanged(key)
    if APPLY_KEYS[key] then Apply() end
end

hooksecurefunc(AlertFrame, "AddAlertFrame", OnAlertAdded)
for _, frame in ipairs({ ZoneTextFrame, SubZoneTextFrame }) do
    frame:HookScript("OnShow", OnZoneTextShow)
end
if EventToastManagerFrame then
    hooksecurefunc(EventToastManagerFrame, "DisplayToast", OnToast)
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local function ClutterSummary(store)
    local on = 0
    for i = 1, #CLUTTER do
        if store.Get(CLUTTER[i]) then on = on + 1 end
    end
    return SUMMARY:format(on, #CLUTTER)
end

Settings.Page("QoL/Interface", S):Card({
    id = "uiClutter", name = "UI Clutter", order = 20,
    help = "Hides the game's messages, pop-ups and banners you can do without, each on its own switch.",
    summary = ClutterSummary,
    rows = {
        { key = "hideErrors", label = "Hide Red Error Text", toggle = true,
          help = "Hides the red error text, like \"not ready yet\" and \"out of range\", and the "
              .. "voice line that comes with it." },
        { key = "hideTutorials", label = "Turn Off Tutorials", toggle = true,
          help = "Turns off the game's tutorials and help tips. Turning this back off restores "
              .. "what you had before." },
        { key = "hideScreenshot", label = "Hide Screen Captured Text", toggle = true,
          help = "Hides the \"Screen captured\" text when you take a screenshot." },
        { key = "skipCinematics", label = "Skip Cinematics", toggle = true,
          help = "Skips cinematics you have already seen on this account. Each one plays the "
              .. "first time." },
        { key = "hideAlerts", label = "Hide Alert Pop-ups", toggle = true,
          help = "Hides the pop-ups for achievements, loot won and the like." },
        { key = "hideEventToasts", label = "Hide Event Toasts", toggle = true,
          help = "Closes the banners for level ups, new zones and events." },
        { key = "hideZoneText", label = "Hide Zone Text", toggle = true,
          help = "Hides the zone and subzone names that appear as you travel." },
        { key = "hideBagBar", label = "Hide Bag Bar", toggle = true,
          help = "Hides the bag buttons beside the menu; your bag key still opens them." },
    },
})
