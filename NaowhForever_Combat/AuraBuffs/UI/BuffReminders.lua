-- BuffReminders.lua: the Buffs & Consumables row of icons on screen, refreshed out of combat.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local D = ns.BuffReminderData
local R, Cell, Menu, Glow = A.Buffs, A.BuffCell, A.BuffMenu, A.Glow
local ItemBar = ns.Shared.ItemBar
local Left, Secret, GROUP_UNIT = R.Left, R.Secret, R.GROUP_UNIT

local QUEUE_DELAY = 0.3
local ELIXIR_ICON = 13454
local WAKE_PAD = 0.1
local WAKE_SAME = 0.01
local RANGE_INTERVAL = 0.5
local HOME_Y = 220
local CARD = A.PAGE .. ":buffs"
local TEXT_MOVER = "Buff Reminders"
local KEYS = {
    consumableEntries = true, enabled = true, consumablesWhere = true, consumablesMinutes = true,
    onlyIfCarried = true, carriedPicks = true, hideResting = true, raidBuffs = true, raidBuffsOwn = true, raidBuffPicks = true, iconSize = true,
    buffIconMode = true, raidBuffRange = true, raidBuffRangeHide = true, hideBlessingsOnPaladin = true,
    personalBuffs = true, personalBuffPicks = true, weaponEnhancements = true,
    buffsFont = true, buffsFontSize = true, buffsOutline = true, buffsBorderColor = true,
    buffGlow = true, buffGlowType = true, buffGlowColor = true, buffGlowLines = true, buffGlowThickness = true,
    buffGlowSpeed = true,
}
local PREVIEW = {
    { spell = D.WELL_FED[1] }, { item = D.FLASKS.items[1] }, { item = ELIXIR_ICON },
    { item = D.SCROLLS[4].items[4], count = 2 }, { raid = true, count = 3 },
}

local frame, unlocked, pending, held
local wakeTimer, wakeDue
local rangeTicker, rangeList
local cells = {}
local events = CreateFrame("Frame")
local Queue

local function OnCellHide(cell)
    if Menu.OwnedBy(cell) then Menu.Hide() end
end

local function OnCellEnter(cell)
    Menu.Open(cell)
end

local function OnCellLeave()
    Menu.Leave()
end

local function OnCellUsed(cell)
    if cell.itemID then Glow.Press(cell, "buffGlow") end
end

local function GetCell(i)
    local cell = cells[i]
    if cell then return cell end
    cell = Cell.New(frame, "SecureActionButtonTemplate")
    cell:EnableMouse(true)
    cell:RegisterForClicks("AnyUp", "AnyDown")
    cell:SetScript("PostClick", OnCellUsed)
    cell:SetScript("OnEnter", OnCellEnter)
    cell:SetScript("OnLeave", OnCellLeave)
    cell:SetScript("OnHide", OnCellHide)
    cell.timer = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
    cell.timer:SetAllPoints()
    cell.timer:SetDrawEdge(false)
    cell.timer:SetReverse(true)
    cells[i] = cell
    return cell
end

local function ShowTimer(cell, aura)
    if aura and Left(aura) and not Secret(aura.duration) then
        cell.timer:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
        cell.timer:Show()
    else
        cell.timer:Hide()
    end
end

local function StopRange()
    if rangeTicker then rangeTicker:Cancel() end
    rangeTicker, rangeList = nil, nil
end

local function Hides(entry, inRange)
    return S.Get("raidBuffRangeHide") and inRange == 0 and entry.rangeSpell ~= nil or false
end

local function PaintRange(cell, entry, inRange)
    local missing = entry.rangeUnits and #entry.rangeUnits
    if missing or cell.rangeTracked then
        Cell.Range(cell, inRange, missing)
        cell.rangeTracked = missing ~= nil and true or nil
    end
    Glow.Set(cell, S.Get("buffGlow") and not unlocked and (not missing or inRange > 0), "buffGlow")
end

local function OnRangeTick()
    if not R.On() or not S.Get("raidBuffRange") or not frame:IsShown() then return StopRange() end
    if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then return end
    for _, entry in ipairs(rangeList) do
        if entry.rangeUnits then
            local inRange = R.InRange(entry)
            if Hides(entry, inRange) ~= not entry.cell then return Queue() end
            if entry.cell then PaintRange(entry.cell, entry, inRange) end
        end
    end
end

local function RangeMoves(entry)
    if not (entry.rangeUnits and entry.rangeSpell) then return false end
    for _, unit in ipairs(entry.rangeUnits) do
        if not UnitIsUnit(unit, "player") then return true end
    end
    return false
end

local function Show(list)
    local size = S.Get("iconSize")
    local moving, shown = false, 0
    for _, entry in ipairs(list) do
        local inRange = entry.rangeUnits and R.InRange(entry)
        if not Hides(entry, inRange) then
            shown = shown + 1
            local cell = GetCell(shown)
            Cell.Place(cell, frame, shown, size, entry.icon, entry.count)
            cell.rangeIn, cell.rangeMissing = nil, nil
            cell.items = entry.items
            ItemBar.SetItem(cell, entry.item)
            ShowTimer(cell, entry.aura)
            cell:Show()
            PaintRange(cell, entry, inRange)
            entry.cell = cell
        end
        if RangeMoves(entry) then moving = true end
    end
    for i = shown + 1, #cells do
        Glow.Set(cells[i], false)
        cells[i]:Hide()
    end
    Cell.Fit(frame, shown, size)
    if moving then
        rangeList = list
        rangeTicker = C_Timer.NewTicker(RANGE_INTERVAL, OnRangeTick)
    end
    local owner = Menu.Owner()
    if not owner then return end
    if owner:IsShown() and owner.items then Menu.Open(owner) else Menu.Hide() end
end

local function PreviewList()
    local list = {}
    for _, p in ipairs(PREVIEW) do
        local spell = p.raid and R.RaidSample() or p.spell
        if p.item or spell then
            list[#list + 1] = { icon = p.item and C_Item.GetItemIconByID(p.item) or C_Spell.GetSpellTexture(spell),
                count = p.raid and S.Get("raidBuffRange") and ("1/" .. p.count) or p.count }
        end
    end
    return list
end

local Refresh, Apply

local function StopWake()
    if wakeTimer then wakeTimer:Cancel() end
    wakeTimer, wakeDue = nil, nil
end

local function OnWake()
    wakeTimer, wakeDue = nil, nil
    Refresh()
end

local function ArmWake(seconds)
    local due = GetTime() + seconds
    if wakeTimer and math.abs(due - wakeDue) < WAKE_SAME then return end
    StopWake()
    wakeDue = due
    wakeTimer = C_Timer.NewTimer(seconds + WAKE_PAD, OnWake)
end

function Refresh()
    pending = nil
    if not frame or InCombatLockdown() then return end
    StopRange()
    if unlocked then return Show(PreviewList()) end
    if not R.On() then return Show({}) end
    local list = R.Collect()
    if not list then return end
    Show(list)
    local wakeAt = R.WakeAt()
    if wakeAt then ArmWake(wakeAt) else StopWake() end
end

function Queue()
    if pending then return end
    pending = true
    C_Timer.After(QUEUE_DELAY, Refresh)
end

local function OnEvent(_, event, unit, arg2, spellID)
    if event == "UNIT_AURA" and (InCombatLockdown() or Secret(unit)
        or not (GROUP_UNIT[unit] or unit == "target" and R.WatchesTarget())) then return end
    if event == "PLAYER_REGEN_DISABLED" then
        StopRange()
        Menu.Hide()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and held then return Apply() end
    if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD" then R.ForgetBags() end
    if event == "ITEM_DATA_LOAD_RESULT" and not R.Requested(unit) then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" and (Secret(spellID)
        or not (R.NoteImbueCast(spellID) or R.NoteFoodCast(spellID) or R.NoteUseCast(spellID))) then return end
    Queue()
end

local function SavePosition(pos)
    S.Set("buffsPos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverBuffReminders", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.mover = ns.UI.AttachMover(frame, TEXT_MOVER, SavePosition, A.PAGE, CARD)
end

local function Place()
    local pos = S.Get("buffsPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, HOME_Y)
    end
end

local function Listen()
    if S.Get("raidBuffs") then
        events:RegisterEvent("UNIT_AURA")
        events:RegisterEvent("GROUP_ROSTER_UPDATE")
    elseif R.WatchesTarget() then
        events:RegisterUnitEvent("UNIT_AURA", "player", "target")
    else
        events:RegisterUnitEvent("UNIT_AURA", "player")
    end
    if R.WatchesTarget() then events:RegisterEvent("PLAYER_TARGET_CHANGED") end
    if S.Get("personalBuffs") or S.Get("weaponEnhancements") then
        events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    end
    if R.WatchesImbue() or not R.Carried("food") or S.Get("buffIconMode") == "last" then
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_UPDATE_RESTING")
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
end

function Apply()
    if InCombatLockdown() then
        if R.On() or unlocked or frame and frame:IsShown() then
            held = true
            events:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end
    held = nil
    Menu.Hide()
    events:UnregisterAllEvents()
    StopWake()
    StopRange()
    if not (R.On() or unlocked) then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Place()
    frame.mover:SetShown(unlocked == true)
    frame:Show()
    if R.On() then Listen() end
    Refresh()
end

local function OnSet(key)
    if KEYS[key] then Apply() end
end

local function OnUnlock()
    unlocked = R.On() == true
    Menu.unlocked = unlocked
    Apply()
end

local function OnLock()
    unlocked = false
    Menu.unlocked = false
    if frame then Apply() end
end

A.BuffPreview = PREVIEW

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
