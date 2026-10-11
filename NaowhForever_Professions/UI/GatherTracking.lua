-- GatherTracking.lua: the Tracking Reminder: a secure icon that starts Find Herbs, Minerals or Fish while none is tracked.
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI

local P = ns.Professions
local S = P.Settings
local Style = P.Style
local Parts = ns.Shared.Parts

local FIND_HERBS, FIND_MINERALS, FIND_FISH = 2383, 2580, 43308
local TRACKINGS = {
    { spell = FIND_HERBS, label = ns.L("Herbs") },
    { spell = FIND_MINERALS, label = ns.L("Minerals") },
    { spell = FIND_FISH, label = "Fish", key = "gatherFish" },
}
local CLICKS = { { "1", "Left-click" }, { "2", "Right-click" }, { "3", "Middle-click" } }
local CROP_LOW, CROP_HIGH = Style.ICON_CROP, Style.ICON_CROP_HIGH
local LABEL_SIZE, LABEL_GAP = 13, 4
local HIGHLIGHT_ALPHA = 0.15
local HOME_X, HOME_Y = 260, 120
local FRAME_NAME = "NaowhForeverGatherTracking"
local MOVER_LABEL = "Tracking"
local EVENTS = { "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD",
    "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }
local TEXT_TRACK = ns.L("Track ")
local TEXT_NOT_TRACKING = ns.L("Not Tracking")
local TEXT_CLICK = "%s: %s"

local button, unlocked, pending
local events = CreateFrame("Frame")
local Apply

local Look = { FIND_HERBS = FIND_HERBS }
P.GatherLook = Look

function Look.New(frame)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    ns.Border(frame, Style.BORDER_RGB)
    frame.label = ns.Font(frame, LABEL_SIZE, "OUTLINE", T.accentSoft)
    frame.label:SetPoint("TOP", frame, "BOTTOM", 0, -LABEL_GAP)
end

function Look.Fill(frame, size, texture, text)
    frame:SetSize(size, size)
    frame.icon:SetTexture(texture)
    Parts.HudFont(frame.label, S.Get("gatherFont"), S.Get("gatherFontSize"), S.Get("gatherOutline"))
    frame.label:SetText(text)
end

local function On()
    return S.Get("enabled") and S.Get("gatherReminder")
end

local function Tracking(spellID)
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        if type(info) == "table" then
            if info.spellID == spellID then return info.active == true end
        else
            local _, _, active, _, _, id = C_Minimap.GetTrackingInfo(i)
            if id == spellID then return active == true end
        end
    end
    return false
end

local function Known()
    local known, any = {}, false
    for _, t in ipairs(TRACKINGS) do
        if C_SpellBook.IsSpellKnown(t.spell) and (not t.key or S.Get(t.key)) then
            known[#known + 1] = t
            if Tracking(t.spell) then any = true end
        end
    end
    return known, any
end

local function Suppressed()
    if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return true end
    return IsInInstance() and not S.Get("gatherInInstances")
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    local gold = Style.GOLD_RGB
    GameTooltip:AddLine(TEXT_NOT_TRACKING, gold.r, gold.g, gold.b)
    for i, t in ipairs(self.known or {}) do
        local name = C_Spell.GetSpellName(t.spell) or t.label
        GameTooltip:AddLine(TEXT_CLICK:format(CLICKS[i][2], name), 1, 1, 1)
    end
    GameTooltip:Show()
end

local function SavePosition(pos)
    S.Set("gatherPos", pos)
end

local function Build()
    button = CreateFrame("Button", FRAME_NAME, UIParent, "SecureActionButtonTemplate")
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", false)
    Look.New(button)
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(1, 1, 1, HIGHLIGHT_ALPHA)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button.mover = UI.AttachMover(button, MOVER_LABEL, SavePosition, "Professions/Settings", "Professions/Settings:gather")
    button:Hide()
end

local function Place()
    local pos = S.Get("gatherPos")
    button:ClearAllPoints()
    if pos then
        button:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        button:SetPoint("CENTER", UIParent, "CENTER", HOME_X, HOME_Y)
    end
end

local function Arm(known)
    button.known = known
    for i, click in ipairs(CLICKS) do
        local t = known[i]
        button:SetAttribute("type" .. click[1], t and "spell" or nil)
        button:SetAttribute("spell" .. click[1], t and t.spell or nil)
    end
    local shown = known[1] or TRACKINGS[1]
    local labels = {}
    for _, t in ipairs(#known > 0 and known or { TRACKINGS[1], TRACKINGS[2] }) do
        labels[#labels + 1] = t.label
    end
    Look.Fill(button, S.Get("gatherIconSize"), C_Spell.GetSpellTexture(shown.spell),
        TEXT_TRACK .. table.concat(labels, " / "))
end

local function Update(event)
    if not button then return end
    if event == "PLAYER_REGEN_DISABLED" then
        button:Hide()
        return
    end
    if InCombatLockdown() then return end
    local known, any = Known()
    Arm(known)
    if unlocked then
        button:Show()
    else
        button:SetShown(On() and #known > 0 and not any and not Suppressed())
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" and pending then
        pending = nil
        return Apply()
    end
    Update(event)
end

function Apply()
    if InCombatLockdown() then
        pending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterAllEvents()
    if not (On() or unlocked) then
        if button then button:Hide() end
        return
    end
    if not button then Build() end
    local size = S.Get("gatherIconSize")
    button:SetSize(size, size)
    Place()
    button.mover:SetShown(unlocked == true)
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    Update()
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^gather") and key ~= "gatherPos") then Apply() end
end

local function OnUnlock()
    unlocked = On() == true
    Apply()
end

local function OnLock()
    unlocked = false
    Apply()
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
