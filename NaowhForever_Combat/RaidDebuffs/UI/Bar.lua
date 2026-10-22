-- Bar.lua: the Raid Debuffs bar on Blizzard's AuraContainer, one aura slot over each picked debuff's missing icon, with its events and Unlock Mode.
local ns = _G.NaowhForever

local RD = ns.RaidDebuffs
local S = RD.Settings
local St = RD.Style
local UI = ns.UI
local SPELLS = ns.RaidDebuffSpells

local BORDER, ICON_CROP, ICON_GAP, BLACK = St.BORDER, St.ICON_CROP, St.ICON_GAP, St.BLACK
local SLOT_LIFT, MISSING_ALPHA, PRESENT_DIM, MISSING_RGB = St.SLOT_LIFT, St.MISSING_ALPHA, St.PRESENT_DIM, St.RED_RGB
local FILTER = "HARMFUL"
local UNIT = "target"
local FRAME_NAME = "NaowhForeverRaidDebuffs"
local MOVER_LABEL = "Raid Debuffs"
local CARD = RD.PAGE .. ":bar"
local FADES = { GROUP_ROSTER_UPDATE = true, UNIT_FACTION = true, UNIT_FLAGS = true }

local Icon = ns.Shared.AuraIcon(S, St)
RD.Icon = Icon

local holder, container, unlocked
local cells, slots = {}, {}
local events = CreateFrame("Frame")

local function InitButton(button)
    button.aura = true
    Icon.New(button)
    button:SetIcon(button.icon)
    button:SetDurationCooldown(button.swipe)
    button:SetApplicationCount(button.countText)
    button:EnableMouse(false)
end

local function NewCell(entry)
    local cell = CreateFrame("Frame", nil, holder)
    local ground = cell:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(BLACK.r, BLACK.g, BLACK.b, 1)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", BORDER, -BORDER)
    cell.icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
    cell.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    cell.icon:SetTexture(entry.icon)
    cell.edge = ns.Border(cell, BLACK)
    return cell
end

local function SavePosition(pos)
    S.Set("pos", pos)
end

local function Build()
    holder = CreateFrame("Frame", FRAME_NAME, UIParent)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    container:SetPoint("TOPLEFT")
    container:SetFrameLevel(holder:GetFrameLevel() + SLOT_LIFT)
    container:SetUnit(UNIT)
    for _, entry in ipairs(SPELLS) do
        local cell = NewCell(entry)
        local slot = container:AddAuraSlot(entry.key, FILTER, {
            candidateFilters = { includeSpellIDs = entry.ids }, initializeFrame = InitButton,
        })
        slot:SetAllPoints(cell)
        cells[entry.key], slots[entry.key] = cell, slot
    end
    holder.mover = UI.AttachMover(holder, MOVER_LABEL, SavePosition, RD.PAGE, CARD)
end

local function PaintCell(cell, slot, size, x)
    local lit = S.Get("highlightMissing") == true
    local edge = lit and MISSING_RGB or BLACK
    cell:SetSize(size, size)
    cell:ClearAllPoints()
    cell:SetPoint("LEFT", holder, "LEFT", x, 0)
    cell.icon:SetDesaturated(not lit)
    cell.icon:SetAlpha(lit and 1 or MISSING_ALPHA)
    cell.edge:SetColor(edge.r, edge.g, edge.b, 1)
    Icon.Style(slot)
    slot.icon:SetDesaturated(lit)
    slot.icon:SetAlpha(lit and PRESENT_DIM or 1)
end

local function Layout()
    local size, n = Icon.Size(), 0
    for _, entry in ipairs(SPELLS) do
        local on = RD.Picked(entry)
        container:SetAuraSlotEnabled(entry.key, on)
        cells[entry.key]:SetShown(on)
        if on then
            PaintCell(cells[entry.key], slots[entry.key], size, n * (size + ICON_GAP))
            n = n + 1
        end
    end
    n = math.max(n, 1)
    holder:SetSize(n * size + (n - 1) * ICON_GAP, size)
end

local function Place()
    local pos = S.Get("pos")
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function Wanted()
    if unlocked then return true end
    local show = S.Get("show")
    if show == "raid" and not IsInRaid() or show == "group" and not IsInGroup() then return false end
    if not UnitExists(UNIT) then return false end
    local hostile = UnitCanAttack("player", UNIT)
    if issecretvalue and issecretvalue(hostile) then return true end
    return hostile == true
end

local function Fade()
    holder:SetAlpha(Wanted() and 1 or 0)
end

local function Hide()
    if not holder then return end
    container:SetEnabled(false)
    holder:Hide()
    holder.mover:Hide()
end

local function Apply()
    if not RD.On() and not holder then
        events:UnregisterAllEvents()
        return
    end
    if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
        return
    end
    events:UnregisterAllEvents()
    if not RD.On() then return Hide() end
    if not holder then Build() end
    Layout()
    Place()
    container:SetEnabled(true)
    holder:Show()
    holder.mover:SetShown(unlocked == true)
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterUnitEvent("UNIT_FACTION", UNIT)
    events:RegisterUnitEvent("UNIT_FLAGS", UNIT)
    Fade()
end

local function OnEvent(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        container:UpdateAllAuras()
        return Fade()
    end
    if FADES[event] then return Fade() end
    Apply()
end

local function OnSettingChanged(key)
    if key ~= "pos" then Apply() end
end

local function OnUnlock()
    unlocked = RD.On()
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
