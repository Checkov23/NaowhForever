-- FirstLogin.lua: opens the onboarding on an account's first login, and a new character's page until it is answered, unless NaowhUI is loaded.
local ns = _G.NaowhForever

local SHOW_DELAY = 5
local INSTALLER_ADDON = "NaowhUI"

local timer, armed
local login = CreateFrame("Frame")

local function Stop()
    login:UnregisterAllEvents()
    if timer then timer:Cancel() end
    timer = nil
end

local function Wanted()
    if C_AddOns.IsAddOnLoaded(INSTALLER_ADDON) then return false end
    return not ns.AccountSettings().onboardingSeen or ns.ImportCandidate() ~= nil
end

local function AskMain()
    local char, profile = ns.ImportCandidate()
    if not char then return end
    ns.ShowNewCharacter(UnitName("player"), char:match("^[^-]+"), profile)
end

local function Due()
    timer = nil
    if not Wanted() then return Stop() end
    if InCombatLockdown() then
        login:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    Stop()
    if ns.AccountSettings().onboardingSeen then return AskMain() end
    ns.ShowSetup()
end

local function OnEnteringWorld(self, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then ns.MarkSeen() end
    if not (armed or isInitialLogin or isReloadingUi) or not Wanted() then
        return Stop()
    end
    armed = true
    if timer then timer:Cancel() end
    timer = C_Timer.NewTimer(SHOW_DELAY, Due)
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
end

local function OnLeavingWorld(self)
    if timer then timer:Cancel() end
    timer = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

local function OnLoginEvent(self, event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_ENTERING_WORLD" then
        OnEnteringWorld(self, isInitialLogin, isReloadingUi)
    elseif event == "PLAYER_LEAVING_WORLD" then
        OnLeavingWorld(self)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Due()
    end
end

login:SetScript("OnEvent", OnLoginEvent)
login:RegisterEvent("PLAYER_ENTERING_WORLD")
