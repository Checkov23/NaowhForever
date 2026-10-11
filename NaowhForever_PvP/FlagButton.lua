-- FlagButton.lua: PvP Flag, a button that turns your PvP flag on and off, movable in the HUD Editor.
local ns = _G.NaowhForever

local UI = ns.UI
local S = ns.PvPSettings

local PAGE, CARD = "PvP/Flag", "PvP/Flag:flagButton"
local MOVER_LABEL = "PvP Flag"
local DEFAULT_Y = -200
local CREST_SCALE = 0.55
local CREST_ALPHA_ON, CREST_ALPHA_OFF = 1, 0.5
local RING, SWORDS, OFF = "talents-warmode-ring", "pvptalents-warmode-swords", "-disabled"
local CRESTS = { Alliance = "MountJournalIcons-Alliance", Horde = "MountJournalIcons-Horde" }
local MACRO = "/pvp"
local KEYS = { enabled = true, flagButton = true, flagButtonSize = true, flagButtonPos = true }
local TEXT_ON, TEXT_OFF = ns.L("PvP Flag: On"), ns.L("PvP Flag: Off")
local TEXT_TURN_ON, TEXT_TURN_OFF = ns.L("Click to flag yourself for PvP."), ns.L("Click to stop flagging yourself.")

local button, moving, pending
local events = CreateFrame("Frame")

local function Update()
    local flagged = UnitIsPVP("player")
    local suffix = flagged and "" or OFF
    button.ring:SetAtlas(RING .. suffix)
    button.swords:SetAtlas(SWORDS .. suffix)
    button.crest:SetAtlas(CRESTS[UnitFactionGroup("player")] or CRESTS.Alliance)
    button.crest:SetDesaturated(not flagged)
    button.crest:SetAlpha(flagged and CREST_ALPHA_ON or CREST_ALPHA_OFF)
    ns.Tooltip(button, flagged and TEXT_ON or TEXT_OFF, GetPVPDesired() and TEXT_TURN_OFF or TEXT_TURN_ON)
end

local function SavePosition(pos)
    S.Set("flagButtonPos", pos)
end

local function Build()
    button = CreateFrame("Button", "NaowhForeverPvPFlag", UIParent, "SecureActionButtonTemplate")
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", MACRO)
    button.crest = button:CreateTexture(nil, "BACKGROUND")
    button.crest:SetPoint("CENTER")
    button.swords = button:CreateTexture(nil, "ARTWORK")
    button.swords:SetPoint("CENTER")
    button.ring = button:CreateTexture(nil, "OVERLAY")
    button.ring:SetAllPoints()
    button.mover = UI.AttachMover(button, MOVER_LABEL, SavePosition, PAGE, CARD)
end

local function Resize(size)
    button:SetSize(size, size)
    button.crest:SetSize(size * CREST_SCALE, size * CREST_SCALE)
    local ring, swords = C_Texture.GetAtlasInfo(RING), C_Texture.GetAtlasInfo(SWORDS)
    local scale = size / ring.width
    button.swords:SetSize(swords.width * scale, swords.height * scale)
end

local function Place()
    button:ClearAllPoints()
    local pos = S.Get("flagButtonPos")
    if pos then
        button:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function Apply()
    local on = S.Get("enabled") and S.Get("flagButton")
    if not (on or button) then return end
    if InCombatLockdown() then
        pending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pending = false
    if not on then
        button:Hide()
        events:UnregisterAllEvents()
        return
    end
    if not button then Build() end
    Resize(S.Get("flagButtonSize"))
    Place()
    Update()
    events:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", "player")
    events:RegisterUnitEvent("UNIT_FACTION", "player")
    button.mover:SetShown(moving == true)
    button:Show()
end

local function OnEvent(self, event)
    if event ~= "PLAYER_REGEN_ENABLED" then
        Update()
        return
    end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pending then Apply() end
end

local function OnSettingChanged(key)
    if KEYS[key] then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function() moving = true; Apply() end)
hooksecurefunc(ns, "HideUnlockMode", function() moving = false; Apply() end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
