-- Reminder.lua: the Tracking Reminder row, one secure icon per missing racial or class tracking.
local ns = _G.NaowhForever

local GetNumTrackingTypes = C_Minimap.GetNumTrackingTypes
local GetTrackingInfo = C_Minimap.GetTrackingInfo
local IsSpellKnown = C_SpellBook.IsSpellKnown
local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellName = C_Spell.GetSpellName
local SetTracking = C_Minimap.SetTracking
local ShouldAurasBeSecret = C_Secrets.ShouldAurasBeSecret
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local TR = ns.TrackingReminder
local S = TR.Settings
local D = TR.Data

local CROP = St.ICON_CROP
local LABEL_SIZE = 13
local LABEL_GAP = 4
local ICON_GAP = 4
local HIGHLIGHT_ALPHA = 0.15
local HOME_X, HOME_Y = 260, 170
local FRAME_NAME = "NaowhForeverTrackingReminder"
local MOVER_LABEL = "Racial and Class Tracking"
local CARD = TR.PAGE .. ":tracking"
local EVENTS = { "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }
local RESUME = { PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true }
local REFRESH = {
    enabled = true, trackRacial = true, trackClass = true, racialPicks = true, classPicks = true,
    inInstances = true, iconSize = true, trackingFont = true, trackingFontSize = true, trackingOutline = true,
}
local TEXT_TRACK = ns.L("Track %s")
local TEXT_NOT_TRACKING = ns.L("Not Tracking")
local TEXT_TIP = ns.L("Left-click turns it on, and right-click hides it until you change area.")

local row, unlocked, pending, snoozed
local buttons = {}
local shown = {}
local slots = {}
local auras = {}
local events = CreateFrame("Frame")

local Look = {}
TR.Look = Look

local function AuraOn(spellID)
    if not ShouldAurasBeSecret() then auras[spellID] = GetPlayerAuraBySpellID(spellID) ~= nil end
    return auras[spellID] == true
end

local function Slot(spellID)
    for i = 1, GetNumTrackingTypes() do
        local info, _, active, _, _, id = GetTrackingInfo(i)
        local spell, on
        if type(info) == "table" then
            spell, on = info.spellID, info.active == true
        else
            spell, on = id, active == true
        end
        if spell == spellID then return i, on end
    end
    return nil, AuraOn(spellID)
end

local function AddKnown(list, picks, token, field, includeActive)
    for i = 1, #list do
        local t = list[i]
        if t[field] == token and picks[t.key] ~= false and IsSpellKnown(t.spell) then
            if t.form then events:RegisterEvent("UPDATE_SHAPESHIFT_FORM") end
            local index, on = Slot(t.spell)
            if includeActive or (not on and (not t.form or GetShapeshiftFormID() == t.form)) then
                local n = #shown + 1
                shown[n] = t
                slots[n] = index
            end
        end
    end
end

local function Collect(includeActive)
    wipe(shown)
    wipe(slots)
    local _, race = UnitRace("player")
    local _, class = UnitClass("player")
    if S.Get("trackRacial") then AddKnown(D.RACIAL, S.Get("racialPicks"), race, "race", includeActive) end
    if S.Get("trackClass") then AddKnown(D.CLASS, S.Get("classPicks"), class, "class", includeActive) end
    return shown
end

local function Suppressed()
    if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return true end
    return IsInInstance() and not S.Get("inInstances")
end

local function OnPostClick(self, mouseButton)
    if unlocked or InCombatLockdown() then return end
    if mouseButton == "RightButton" then
        snoozed = true
        row:Hide()
        return
    end
    if mouseButton == "LeftButton" and self.trackIndex then SetTracking(self.trackIndex, true) end
end

function Look.New(frame)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    ns.Border(frame, St.BORDER_RGB)
    frame.label = ns.Font(frame, LABEL_SIZE, "OUTLINE", T.accentSoft)
    frame.label:SetPoint("TOP", frame, "BOTTOM", 0, -LABEL_GAP)
end

function Look.Fill(frame, size, texture, text)
    frame:SetSize(size, size)
    frame.icon:SetTexture(texture)
    Parts.HudFont(frame.label, S.Get("trackingFont"), S.Get("trackingFontSize"), S.Get("trackingOutline"))
    frame.label:SetText(TEXT_TRACK:format(text))
end

local function GetButton(i)
    local button = buttons[i]
    if button then return button end
    button = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", false)
    Look.New(button)
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(T.fg.r, T.fg.g, T.fg.b, HIGHLIGHT_ALPHA)
    ns.Tooltip(button, TEXT_NOT_TRACKING, TEXT_TIP)
    button:SetScript("PostClick", OnPostClick)
    buttons[i] = button
    return button
end

local function SavePosition(pos)
    S.Set("trackingPos", pos)
end

local function Build()
    row = CreateFrame("Frame", FRAME_NAME, UIParent)
    row:SetMovable(true)
    row:SetClampedToScreen(true)
    row.mover = UI.AttachMover(row, MOVER_LABEL, SavePosition, TR.PAGE, CARD)
    row:Hide()
end

local function Place()
    if not row or InCombatLockdown() then return end
    local pos = S.Get("trackingPos")
    row:ClearAllPoints()
    if pos then
        row:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        row:SetPoint("CENTER", UIParent, "CENTER", HOME_X, HOME_Y)
    end
end

local function ShowRow(list)
    local size = S.Get("iconSize")
    local n = #list
    for i = 1, n do
        local t = list[i]
        local button = GetButton(i)
        local index = slots[i]
        button.spell = t.spell
        button.trackIndex = index
        if index then
            button:SetAttribute("type1", nil)
            button:SetAttribute("spell1", nil)
        else
            button:SetAttribute("type1", "spell")
            button:SetAttribute("spell1", GetSpellName(t.spell) or t.spell)
        end
        Look.Fill(button, size, GetSpellTexture(t.spell), t.label)
        button:ClearAllPoints()
        button:SetPoint("LEFT", row, "LEFT", (i - 1) * (size + ICON_GAP), 0)
        button:Show()
    end
    for i = n + 1, #buttons do
        local button = buttons[i]
        button.spell = nil
        button.trackIndex = nil
        button:SetAttribute("type1", nil)
        button:SetAttribute("spell1", nil)
        button:Hide()
    end
    row:SetSize(n > 0 and n * size + (n - 1) * ICON_GAP or size, size)
    row:Show()
end

local function Update(event)
    if not row then return end
    if RESUME[event] then snoozed = false end
    if event == "PLAYER_REGEN_DISABLED" then
        row:Hide()
        return
    end
    if InCombatLockdown() then return end
    local list = Collect(unlocked)
    if unlocked or (TR.On() and #list > 0 and not Suppressed() and not snoozed) then
        ShowRow(list)
    else
        row:Hide()
    end
end

local function Apply()
    if InCombatLockdown() then
        pending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterAllEvents()
    if not (TR.On() or unlocked) then
        if row then row:Hide() end
        return
    end
    if not row then Build() end
    Place()
    row.mover:SetShown(unlocked == true)
    for i = 1, #EVENTS do events:RegisterEvent(EVENTS[i]) end
    events:RegisterUnitEvent("UNIT_AURA", "player")
    Update()
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" and pending then
        pending = nil
        return Apply()
    end
    Update(event)
end

local function OnSettingChanged(key)
    if REFRESH[key] then Apply() end
end

local function OnUnlock()
    unlocked = TR.On() == true
    Apply()
end

local function OnLock()
    unlocked = false
    Apply()
end

events:SetScript("OnEvent", OnEvent)
S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
