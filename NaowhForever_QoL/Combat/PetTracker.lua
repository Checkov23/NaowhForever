-- PetTracker.lua: the QoL pet tracker, a warning while a pet is missing, passive or low on health.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Parts, St = ns.Shared.Parts, ns.Shared.Style

local CALL_PET, SUMMON_IMP = 883, 688
local LONE_WOLF, LONE_WOLF_TAUGHT = 415370, 409979
local ICON = 132161
local WIDTH, ICON_GAP = 220, 8
local DISMOUNT_DELAY = 5
local SACRIFICE_BUFFS = { 18789, 18790, 18791, 18792 }
local ICON_CROP_LOW, ICON_CROP_HIGH = ns.QoLConstants.ICON_CROP_TIGHT, ns.QoLConstants.ICON_CROP_TIGHT_HIGH
local FONT_SIZE = 20
local STACK_ORDER = 5
local PAGE = "QoL/Combat"
local TEXT_ALERT = "Pet Tracker"
local ICON_GROW, HEIGHT_ROOM = 12, 16
local PERCENT = ns.QoLConstants.PERCENT
local STEP_EDGE = 0.001
local LOW_HEALTH_RANGE = { 5, 90, 1 }
local TEXT_RANGE = { 12, 48, 1 }
local EVENTS = { "UNIT_PET", "PET_BAR_UPDATE", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE",
    "PLAYER_UNGHOST", "SPELLS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }

local TEXT_MISSING = ns.L("Missing")
local TEXT_PASSIVE = ns.L(", passive")
local TEXT_BELOW = ns.L(", below %d%%")

local frame, curve, unlocked, class
local mounted, dismountTimer, sacrificed
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("petTracker")
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverPetTracker", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetTexture(ICON)
    frame.icon:SetTexCoord(ICON_CROP_LOW, ICON_CROP_HIGH, ICON_CROP_LOW, ICON_CROP_HIGH)
    frame.text = ns.Font(frame, FONT_SIZE, "OUTLINE")
    frame.backdrop = Parts.HudBackdrop(frame, { mode = "none" })
    frame:Hide()
    ns.AlertStack(frame, STACK_ORDER, TEXT_ALERT, PAGE, PAGE .. ":petTracker")
end

local function Restyle()
    local size = S.Get("petFontSize")
    frame.mode = frame.backdrop:SetMode(S.Get("petBackground"))
    Parts.HudFont(frame.text, S.Get("petFont"), size, S.Get("petOutline"), frame.mode)
    local c = S.Get("petClassColor") and RAID_CLASS_COLORS[class] or S.Get("petColor")
    frame.text:SetTextColor(c.r, c.g, c.b, 1)
    frame.text:ClearAllPoints()
    if S.Get("petShowIcon") then
        frame.icon:SetSize(size + ICON_GROW, size + ICON_GROW)
        frame.icon:SetPoint("LEFT", frame, "LEFT", frame.mode == "none" and 0 or St.CARD_PAD, 0)
        frame.icon:Show()
        frame.text:SetPoint("LEFT", frame.icon, "RIGHT", ICON_GAP, 0)
    else
        frame.icon:Hide()
        frame.text:SetPoint("CENTER")
    end
    frame:SetSize(WIDTH, size + HEIGHT_ROOM)
end

local function Fit()
    if frame.mode == "none" then return end
    local w = frame.text:GetStringWidth() + 2 * St.CARD_PAD
    if frame.icon:IsShown() then w = w + frame.icon:GetWidth() + ICON_GAP end
    frame:SetWidth(w)
end

local function BuildCurve()
    local below = S.Get("petLowHealthBelow") / PERCENT
    curve = curve or C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:ClearPoints()
    curve:AddPoint(0, 1)
    curve:AddPoint(below - STEP_EDGE, 1)
    curve:AddPoint(below, 0)
    curve:AddPoint(1, 0)
end

local function ShouldHavePet()
    if class == "HUNTER" then return C_SpellBook.IsSpellKnown(CALL_PET) end
    if class == "WARLOCK" then return C_SpellBook.IsSpellKnown(SUMMON_IMP) and not sacrificed end
    return false
end

local function CheckSacrifice()
    if class ~= "WARLOCK" or C_Secrets.ShouldAurasBeSecret() then return end
    sacrificed = false
    for _, id in ipairs(SACRIFICE_BUFFS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(id) then
            sacrificed = true
            return
        end
    end
end

local function IsPassive()
    if not PetHasActionBar() then return false end
    for i = 1, NUM_PET_ACTION_SLOTS do
        local name, _, _, isActive = GetPetActionInfo(i)
        if name == "PET_MODE_PASSIVE" then return isActive == true end
    end
    return false
end

local function Warning()
    if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return end
    if S.Get("petHideMounted") and (mounted or dismountTimer) then return end
    if S.Get("petCombatOnly") and not UnitAffectingCombat("player") then return end
    if S.Get("petInstanceOnly") and not IsInInstance() then return end
    if not ShouldHavePet() then return end
    if not UnitExists("pet") then
        if class == "HUNTER" and (C_SpellBook.IsSpellKnown(LONE_WOLF) or C_SpellBook.IsSpellKnown(LONE_WOLF_TAUGHT)) then
            return
        end
        return "petMissingText"
    end
    if S.Get("petPassive") and IsPassive() then return "petPassiveText" end
    if S.Get("petLowHealth") and not UnitIsDeadOrGhost("pet") then return "petLowHealthText", true end
end

local function Update()
    if unlocked then
        frame.text:SetText(S.Get("petMissingText"))
        Fit()
        frame:SetAlpha(1)
        frame:Show()
        return
    end
    local key, lowHealth = Warning()
    if not key then
        frame:Hide()
        return
    end
    frame.text:SetText(S.Get(key))
    Fit()
    if lowHealth then
        frame:SetAlpha(UnitHealthPercent("pet", true, curve))
    else
        frame:SetAlpha(1)
    end
    frame:Show()
end

local function CancelDismount()
    if dismountTimer then dismountTimer:Cancel(); dismountTimer = nil end
end

local function OnDismounted()
    dismountTimer = nil
    Update()
end

local function OnMountChanged()
    local was = mounted
    mounted = IsMounted()
    CancelDismount()
    if was and not mounted then
        dismountTimer = C_Timer.NewTimer(DISMOUNT_DELAY, OnDismounted)
    end
end

local function OnEvent(_, event, unit)
    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        OnMountChanged()
    elseif event == "UNIT_AURA" or event == "PLAYER_REGEN_ENABLED" then
        CheckSacrifice()
    elseif event == "UNIT_HEALTH" and unit ~= "pet" then
        return
    end
    Update()
end

local function Apply()
    events:UnregisterAllEvents()
    if not (On() or unlocked) then
        CancelDismount()
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    class = select(2, UnitClass("player"))
    Restyle()
    BuildCurve()
    if On() then
        mounted = IsMounted()
        CheckSacrifice()
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
        events:RegisterUnitEvent("UNIT_HEALTH", "pet")
        events:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
        if class == "WARLOCK" then events:RegisterUnitEvent("UNIT_AURA", "player") end
    end
    Update()
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key:find("^pet") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = S.Get("enabled") == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if frame then Apply() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group

local function OwnColour() return not S.Get("petClassColor") end

local function Summary(store)
    local parts = TEXT_MISSING
    if store.Get("petPassive") then parts = parts .. TEXT_PASSIVE end
    if store.Get("petLowHealth") then parts = parts .. TEXT_BELOW:format(store.Get("petLowHealthBelow")) end
    return parts
end

ns.Shared.Settings.Page(PAGE, S):Card({
    id = "petTracker", name = "Pet Tracker", order = 100, switch = "petTracker",
    help = "A warning while a hunter or warlock has no pet out. A warlock who sacrificed their "
        .. "demon is left alone. Move it in the HUD Editor.",
    summary = Summary,
    rows = {
        Group("Warnings"),
        { key = "petPassive", label = "Warn While Passive", toggle = true,
          help = "Also warns while your pet is set to passive." },
        { key = "petLowHealth", label = "Warn on Low Pet Health", toggle = true,
          help = "Also warns while your pet's health is under the threshold, in combat too." },
        { key = "petLowHealthBelow", label = "Low Health Below", slider = LOW_HEALTH_RANGE, unit = "%",
          needs = "petLowHealth" },
        Group("When"),
        { key = "petCombatOnly", label = "Only In Combat", toggle = true },
        { key = "petInstanceOnly", label = "Only In Dungeons & Raids", toggle = true },
        { key = "petHideMounted", label = "Hide While Mounted", toggle = true,
          help = "Also hidden for a few seconds after you dismount, while the pet comes back." },
        Group("Messages"),
        { key = "petMissingText", label = "Missing Text", text = true, help = "Text while your pet is missing." },
        { key = "petPassiveText", label = "Passive Text", text = true, needs = "petPassive",
          help = "Text while your pet is passive." },
        { key = "petLowHealthText", label = "Low Health Text", text = true, needs = "petLowHealth",
          help = "Text while your pet is low on health." },
        { key = "petShowIcon", label = "Show Icon", toggle = true },
        ns.Shared.Settings.Look("pet", { text = true, size = TEXT_RANGE, background = "card" }),
        Group("Colors"),
        { key = "petClassColor", label = "Class Color", toggle = true },
        { key = "petColor", label = "Color", colour = true, needs = OwnColour, why = "Class color is on" },
    },
})
