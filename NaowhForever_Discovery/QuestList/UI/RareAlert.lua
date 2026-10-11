-- RareAlert.lua: Rare Alerts: the card on screen when a rare is near, with its sound (Completo.RareAlert).
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local C = Completo.C
local S = Completo.Settings
local R = Completo.Rares
local Sounds = Completo.Sounds
local Card = Completo.AlertCard

local AGAIN_AFTER = 300
local FADE = 0.3
local DEFAULT_Y = 260
local PERCENT = C.PERCENT
local STRATA = "HIGH"
local HOLDER_NAME, CARD_NAME = "NaowhForeverRareAlertHolder", "NaowhForeverRareAlert"
local MOVER_LABEL, MOVER_PAGE, MOVER_FEATURE = "Rare Alert", "Discovery/Rares", "Discovery/Rares:rareAlert"
local RARE = { rare = true, rareelite = true }
local LOOK_PREFIX = "^rareAlert"
local TEXT_RARE = ns.L("Rare")
local TEXT_CLOSE = ns.L("Right-click to close it.")

local alert, holder
local shownNpc, shownGuid
local alerted = {}
local events = CreateFrame("Frame")

local RareAlert = {}
Completo.RareAlert = RareAlert

local function On()
    return S.Get("enabled") and S.Get("rareAlert")
end

local function HideAlert()
    if not alert then return end
    alert.fade:Stop()
    alert:Hide()
    shownNpc, shownGuid = nil, nil
    events:UnregisterEvent("UNIT_FLAGS")
end

local function Place()
    local scale = S.Get("rareAlertScale")
    holder:SetScale(scale)
    local pos = S.Get("rareAlertPosition")
    holder:ClearAllPoints()
    if pos then
        holder:SetPoint(pos.point, UIParent, pos.relPoint, pos.x / scale, pos.y / scale)
    else
        holder:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y / scale)
    end
end

local function CardClicked(_, button)
    if button == "RightButton" then HideAlert() end
end

local function CardEnter(card)
    local soft = T.accentSoft
    GameTooltip:SetOwner(card, "ANCHOR_TOP")
    GameTooltip:SetText(card.name:GetText() or TEXT_RARE, 1, 1, 1)
    GameTooltip:AddLine(TEXT_CLOSE, soft.r, soft.g, soft.b)
    GameTooltip:Show()
end

local function CardLeave()
    GameTooltip:Hide()
end

local function Moved(pos)
    local scale = holder:GetScale()
    S.Set("rareAlertPosition", { point = pos.point, relPoint = pos.relPoint, x = pos.x * scale, y = pos.y * scale })
end

local function NewFade(group, from, to, order)
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(from)
    fade:SetToAlpha(to)
    fade:SetDuration(FADE)
    fade:SetOrder(order)
    return fade
end

local function BuildHolder()
    holder = CreateFrame("Frame", HOLDER_NAME, UIParent)
    holder:SetSize(Card.W, Card.H)
    holder:SetFrameStrata(STRATA)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder.mover = ns.UI.AttachMover(holder, MOVER_LABEL, Moved, MOVER_PAGE, MOVER_FEATURE)
end

local function BuildAlert()
    BuildHolder()
    alert = Card.New(holder, CARD_NAME)
    alert:SetPoint("CENTER")
    alert:RegisterForClicks("RightButtonUp")
    alert:SetScript("OnClick", CardClicked)
    alert:SetScript("OnEnter", CardEnter)
    alert:SetScript("OnLeave", CardLeave)
    alert.fade = alert:CreateAnimationGroup()
    alert.fadeIn = NewFade(alert.fade, 0, 1, 1)
    alert.fadeOut = NewFade(alert.fade, 1, 0, 2)
    alert.fade:SetScript("OnFinished", HideAlert)
    alert:Hide()
    Place()
end

local function PlayAlertSound()
    if S.Get("rareSound") then Sounds.Play(S.Get("rareSoundKey")) end
end

local function FillKnown(seen)
    local npc = seen.npc
    if not (npc and R.Known(npc)) then return end
    if seen.elite == nil then seen.elite = R.Elite(npc) end
    seen.record = R.Record(npc) or false
end

local function Play()
    alert.fadeIn:SetFromAlpha(0)
    alert.fadeOut:SetStartDelay(S.Get("rareAlertTime"))
    alert.fade:Play()
    PlayAlertSound()
    if FlashClientIcon then FlashClientIcon() end
end

local function ShowAlert(seen, quiet)
    if not alert then BuildAlert() end
    local track = not quiet and On()
    shownNpc, shownGuid = track and seen.npc or nil, track and seen.guid or nil
    alert.preview = quiet == true
    FillKnown(seen)
    alert.seen = seen
    Card.SetPortrait(alert, seen.unit, seen.npc)
    Card.Paint(alert, seen)
    Place()
    alert.fade:Stop()
    alert:Show()
    if track then events:RegisterEvent("UNIT_FLAGS") else events:UnregisterEvent("UNIT_FLAGS") end
    if not quiet then Play() end
end

local function OnRareChanged(npc)
    if shownNpc and npc == shownNpc and R.Killed(npc) then HideAlert() end
end

local function Due(key, npc)
    if alerted[key] and GetTime() - alerted[key] < AGAIN_AFTER then return false end
    return not (npc and R.Known(npc) and R.Killed(npc) and not S.Get("rareAlertKilled"))
end

local function Alert(key, seen)
    if not Due(key, seen.npc) then return end
    alerted[key] = GetTime()
    ShowAlert(seen)
end

local function Retap(unit)
    local denied = UnitIsTapDenied(unit)
    if R.IsSecret(denied) then return end
    local seen = alert.seen
    if (seen.tapped == true) == (denied == true) then return end
    seen.tapped = denied or nil
    Card.Paint(alert, seen)
end

local function RareGuid(unit)
    if not UnitExists(unit) then return nil end
    local kind = UnitClassification(unit)
    if R.IsSecret(kind) or not RARE[kind] then return nil end
    local guid = UnitGUID(unit)
    if R.IsSecret(guid) or not guid then return nil end
    return guid, kind
end

local function Hostile(unit)
    local dead, hostile = UnitIsDead(unit), UnitCanAttack("player", unit)
    if R.IsSecret(dead) or R.IsSecret(hostile) then return false end
    return not dead and hostile
end

local function Follow(unit, npc, guid)
    if npc ~= shownNpc then return end
    shownGuid = shownGuid or guid
    if guid == shownGuid then Retap(unit) end
end

local function Check(unit)
    local guid, kind = RareGuid(unit)
    if not guid then return end
    local npc = R.NpcOf(guid)
    if not npc or not Hostile(unit) then return end
    Follow(unit, npc, guid)
    local name, level = UnitName(unit), UnitLevel(unit)
    if R.IsSecret(name) then return end
    if R.IsSecret(level) then level = nil end
    if not Due(npc, npc) then return end
    local denied = UnitIsTapDenied(unit)
    Alert(npc, { name = name, level = level, npc = npc, guid = guid, unit = unit, elite = kind == "rareelite",
        tapped = not R.IsSecret(denied) and denied or nil })
end

local function VignetteNpc(info)
    local npc = R.NpcOf(info.objectGUID)
    local atlas = type(info.atlasName) == "string" and not R.IsSecret(info.atlasName) and info.atlasName or ""
    if not npc or not (R.Known(npc) or atlas:find("Kill")) then return nil end
    if R.Known(npc) and not R.Mine(npc) then return nil end
    return npc
end

local function VignetteSpot(id)
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_VignetteInfo.GetVignettePosition and C_VignetteInfo.GetVignettePosition(id, map)
    if not pos or R.IsSecret(pos) then return nil end
    local x, y = pos:GetXY()
    if not x then return nil end
    return map, x * PERCENT, y and y * PERCENT
end

local function CheckVignette(id)
    local info = C_VignetteInfo.GetVignetteInfo(id)
    if not info or R.IsSecret(info.objectGUID) or R.IsSecret(info.name) then return end
    local npc = VignetteNpc(info)
    if not npc then return end
    local known = R.Known(npc)
    local level = known and R.Levels(npc) or nil
    local map, x, y = VignetteSpot(id)
    Alert(npc, { name = info.name or (known and R.Name(npc)) or TEXT_RARE, level = level, npc = npc,
        map = map, x = x, y = y })
end

local function Sample()
    return { name = C.SAMPLE_RARE_NAME, level = C.SAMPLE_RARE_LEVEL, npc = C.SAMPLE_RARE_NPC }
end

local function TargetSeen()
    local guid = UnitGUID("target")
    local hostile = UnitExists("target") and UnitCanAttack("player", "target")
    if not guid or R.IsSecret(guid) or R.IsSecret(hostile) or not hostile then return nil end
    local name, level = UnitName("target"), UnitLevel("target")
    if R.IsSecret(name) then return nil end
    return { name = name, level = not R.IsSecret(level) and level or nil, npc = R.NpcOf(guid), guid = guid,
        unit = "target" }
end

local function OnFlags(unit)
    if not shownGuid then return end
    local guid = UnitGUID(unit)
    if R.IsSecret(guid) or guid ~= shownGuid then return end
    local dead = UnitIsDead(unit)
    if not R.IsSecret(dead) and not dead then Retap(unit) end
end

local function OnEvent(_, event, unit, onMinimap)
    if event == "UNIT_FLAGS" then
        OnFlags(unit)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        Check(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        Check("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Check("mouseover")
    elseif event == "VIGNETTE_MINIMAP_UPDATED" then
        if onMinimap and not R.IsSecret(unit) then CheckVignette(unit) end
    end
end

local function Migrate()
    local db = S.DB()
    local old = db.rareAlertPos
    if old == nil then return end
    if type(old) == "table" and db.rareAlertPosition == nil then
        db.rareAlertPosition = { point = "CENTER", relPoint = "CENTER", x = old.x, y = old.y }
    end
    db.rareAlertPos = nil
end

local function Apply()
    Migrate()
    if holder then Place() end
    events:UnregisterAllEvents()
    if not On() then
        HideAlert()
        return
    end
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    if C_VignetteInfo and C_VignetteInfo.GetVignetteInfo then
        events:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
    end
    if shownNpc then events:RegisterEvent("UNIT_FLAGS") end
end

local function RestartFade()
    alert.fade:Stop()
    alert.fadeIn:SetFromAlpha(1)
    alert.fadeOut:SetStartDelay(S.Get("rareAlertTime"))
    alert.fade:Play()
end

local function OnSet(key)
    if key == "enabled" or key == "rareAlert" then Apply() end
    if key == "rareAlertScale" and holder then Place() end
    if key == "rareAlertTime" and alert and alert.fade:IsPlaying() then RestartFade() end
    if alert and alert:IsShown() and key:find(LOOK_PREFIX) and key ~= "rareAlertPosition" then
        Card.Paint(alert, alert.seen)
    end
end

local function ShowMover()
    if not On() then return end
    if not (alert and alert:IsShown()) then ShowAlert(Sample(), true) end
    holder.mover:Show()
end

local function HideMover()
    if not alert then return end
    holder.mover:Hide()
    if alert.preview then HideAlert() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

function RareAlert.Test()
    ShowAlert(TargetSeen() or Sample())
end

function RareAlert.ResetPosition()
    S.Set("rareAlertPosition", nil)
    if holder then Place() end
end

events:SetScript("OnEvent", OnEvent)
R.OnChange(OnRareChanged)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", ShowMover)
hooksecurefunc(ns, "HideUnlockMode", HideMover)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
