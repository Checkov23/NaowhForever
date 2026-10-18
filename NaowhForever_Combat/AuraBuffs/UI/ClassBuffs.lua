-- ClassBuffs.lua: clickable self-buff slots for the buffs you are missing; in combat the row holds and Blizzard draws its active icons.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local D = ns.BuffReminderData
local Cell, Glow = A.BuffCell, A.Glow
local ICON_CROP = ns.Shared.Style.ICON_CROP
local Settings = ns.Shared.Settings
if A.OLD_COPY then return end

local HOME_Y = 160
local ACTIVE_LEVEL = 2
local MAX_AURAS = 255
local ABSENT_ALPHA = 0.6
local ICON_INSET = 1
local LABEL_SIZE, LABEL_MIN, LABEL_DROP = 10, 7, 2
local LABELS = {
    intellect = "Intellect", stamina = "Fortitude", spirit = "Spirit", wild = "Mark",
    blessing = "Blessing", demonArmor = "Armor", mageArmor = "Armor", battleShout = "Shout",
    innerFire = "Inner Fire", shadowform = "Shadow", aspect = "Aspect", trueshot = "Trueshot",
    thorns = "Thorns", shield = "Shield",
}
local ORDER = 15
local SIZE_RANGE = { 24, 96, 1 }
local CARD = A.PAGE .. ":classBuffTracker"
local TITLE = "Class Buff Tracker"
local WHY_OFF = ns.L("Turn on the Class Buff Tracker")
local TEXT_SUMMARY = ns.L("Grey when inactive; left-click to buff yourself.")
local TEXT_UNAVAILABLE = ns.L("Class Buff Tracker could not load Blizzard's aura display.")
local KEYS = { enabled = true, classBuffTracker = true, classBuffSize = true,
    personalBuffPicks = true, raidBuffPicks = true, hideBlessingsOnPaladin = true, buffsFont = true, buffsBorderColor = true,
    classBuffGlow = true, classBuffGlowType = true,
    classBuffGlowColor = true, classBuffGlowLines = true, classBuffGlowThickness = true,
    classBuffGlowSpeed = true }

local frame, events, pending, failed, unlocked
local cells = {}
local buffs, ownBuffs, unknownCaster = {}, {}, {}
local Apply

local function On()
    return S.Get("enabled") and S.Get("classBuffTracker")
end

local function Known(family)
    for _, id in ipairs(family.spells) do
        if C_SpellBook.IsSpellKnown(id) then return id end
    end
end

local function PaintGlow(cell)
    Glow.Set(cell, On() and S.Get("classBuffGlow") and cell.missing == true,
        "classBuffGlow")
end

local function ReadBuffs()
    wipe(buffs)
    wipe(ownBuffs)
    wipe(unknownCaster)
    for i = 1, MAX_AURAS do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then return true end
        local id = aura.spellId
        if issecretvalue(id) then return false end
        buffs[id] = true
        local caster = aura.sourceUnit
        if issecretvalue(caster) then unknownCaster[id] = true
        elseif caster == "player" then ownBuffs[id] = true end
    end
    return false
end

local function Missing(cell)
    local present = cell.own and ownBuffs or buffs
    local unknown = false
    for id in pairs(cell.ids) do
        if present[id] then return false end
        if cell.own and unknownCaster[id] then unknown = true end
    end
    if not unknown then return true end
end

local function RefreshGlows(restricted, read)
    restricted = restricted or InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()
    local readable = false
    if not restricted and On() and S.Get("classBuffGlow") then
        if read == nil then readable = ReadBuffs() else readable = read end
    end
    for _, cell in pairs(cells) do
        cell.missing = nil
        if readable and cell.selected then cell.missing = Missing(cell) end
        PaintGlow(cell)
    end
end

local function OnHide(cell)
    if GameTooltip:IsOwned(cell) then GameTooltip:Hide() end
    Glow.Set(cell, false)
end

local function OnEnter(cell)
    GameTooltip:SetOwner(cell, "ANCHOR_TOP")
    GameTooltip:SetSpellByID(cell.spell)
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

local function NewCell(family)
    local cell = Cell.New(frame, "SecureActionButtonTemplate")
    ns.PixelInset(cell.icon, ICON_INSET)
    cell.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    cell:SetScript("OnHide", OnHide)
    cell:SetScript("OnEnter", OnEnter)
    cell:SetScript("OnLeave", OnLeave)
    cell.label = ns.Font(cell, LABEL_SIZE, "OUTLINE")
    cell.label:SetPoint("TOP", cell, "BOTTOM", 0, -LABEL_DROP)
    cell.label:SetWordWrap(false)
    cell.label:SetText(ns.L(LABELS[family.key] or family.name))
    cell:EnableMouse(true)
    cell:RegisterForClicks("AnyUp", "AnyDown")
    cell:SetAttribute("type1", "spell")
    cell:SetAttribute("unit1", "player")
    cell.icon:SetDesaturated(true)
    cell.icon:SetAlpha(ABSENT_ALPHA)
    local watch = CreateFrame("AuraContainer", nil, cell, "CustomAuraContainerTemplate")
    cell.watch = watch
    watch:SetAllPoints(cell)
    watch:SetFrameLevel(cell:GetFrameLevel() + ACTIVE_LEVEL)
    watch:EnableMouse(false)
    watch:SetEnabled(false)
    local ids = {}
    for _, id in ipairs(family.spells) do ids[id] = true end
    cell.ids, cell.own = ids, family.own
    watch:AddAuraSlot("buff", "HELPFUL", {
        candidateFilters = { includeSpellIDs = ids, isFromPlayerOrPlayerPet = family.own or nil },
        initializeFrame = function(button)
            button:SetAllPoints(cell.icon)
            button:EnableMouse(false)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            local crop = ICON_CROP
            icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
            button:SetIcon(icon)
        end,
    })
    watch:SetUnit("player")
    return cell
end

local function FitLabel(cell)
    local label = cell.label
    local width = S.Get("classBuffSize") + A.Style.BUFF_GAP
    ns.Shared.Parts.HudFont(label, S.Get("buffsFont"), LABEL_SIZE, "OUTLINE")
    label:SetWidth(0)
    local full = label:GetUnboundedStringWidth()
    if full > width then
        ns.Shared.Parts.HudFont(label, S.Get("buffsFont"),
            math.max(LABEL_MIN, math.floor(LABEL_SIZE * width / full)), "OUTLINE")
    end
    label:SetWidth(width)
end

local function Active(cell, readable)
    return readable and not unlocked and Missing(cell) == false
end

local function AddFamilies(families, picks, count, class, readable, hideBlessings)
    for _, family in ipairs(families) do
        if family.class == class and not family.weapons and not family.target
            and picks[family.key] ~= false and not (hideBlessings and family.class == "PALADIN") then
            local spell = Known(family)
            if spell then
                local cell = cells[family.key]
                if not cell then cell = NewCell(family); cells[family.key] = cell end
                cell.picked = true
                cell.active = Active(cell, readable)
                if not cell.active then
                    count = count + 1
                    local icon = C_Spell.GetSpellTexture(spell)
                    Cell.Place(cell, frame, count, S.Get("classBuffSize"), icon)
                    FitLabel(cell)
                    cell:SetAttribute("spell1", spell)
                    cell.spell = spell
                    cell.selected = true
                    cell:Show()
                    cell.watch:SetEnabled(true)
                end
            end
        end
    end
    return count
end

local function SavePosition(pos)
    S.Set("classBuffPos", pos)
end

local function Paint()
    if not frame then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        frame = CreateFrame("Frame", "NaowhForeverClassBuffs", UIParent)
        frame:Hide()
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame.mover = ns.UI.AttachMover(frame, TITLE, SavePosition, A.PAGE, CARD)
    end
    for _, cell in pairs(cells) do
        cell.selected, cell.picked, cell.active = false, false, false
    end
    local readable = not C_Secrets.ShouldAurasBeSecret() and ReadBuffs()
    local _, class = UnitClass("player")
    local count = AddFamilies(D.PERSONAL, S.Get("personalBuffPicks"), 0, class, readable)
    local hideBlessings = S.Get("hideBlessingsOnPaladin") and class == "PALADIN" and GetNumGroupMembers() > 0
    count = AddFamilies(D.RAID, S.Get("raidBuffPicks"), count, class, readable, hideBlessings)
    for _, cell in pairs(cells) do
        if not cell.selected then
            cell.watch:SetEnabled(false)
            cell:Hide()
        end
    end
    Cell.Fit(frame, count, S.Get("classBuffSize"))
    frame:ClearAllPoints()
    local pos = S.Get("classBuffPos")
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, HOME_Y)
    end
    frame.mover:SetShown(unlocked == true and On())
    frame:SetShown(count > 0)
    RefreshGlows(nil, readable)
end

local function Readable()
    return not InCombatLockdown() and not C_Secrets.ShouldAurasBeSecret() and ReadBuffs()
end

local function ActiveChanged()
    for _, cell in pairs(cells) do
        if cell.picked and Active(cell, true) ~= cell.active then return true end
    end
    return false
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then return RefreshGlows(true) end
    if event == "UNIT_AURA" then
        local read = Readable()
        if read and ActiveChanged() then return Apply() end
        return RefreshGlows(nil, read)
    end
    Apply()
end

local function Listen()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Apply()
    if not On() and not frame and not pending then return end
    if InCombatLockdown() then
        RefreshGlows(true)
        pending = true
        Listen()
        return
    end
    pending = nil
    if events then events:UnregisterAllEvents() end
    if not On() or failed then
        for _, cell in pairs(cells) do cell.watch:SetEnabled(false); Glow.Set(cell, false) end
        if frame then frame:Hide() end
        return
    end
    local ok, err = pcall(Paint)
    if not ok then
        failed = true
        for _, cell in pairs(cells) do cell.watch:SetEnabled(false); Glow.Set(cell, false) end
        if frame then frame:Hide() end
        ns.Print(TEXT_UNAVAILABLE)
        geterrorhandler()(err)
        return
    end
    Listen()
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    if S.Get("hideBlessingsOnPaladin") then events:RegisterEvent("GROUP_ROSTER_UPDATE") end
end

local function OnSet(key)
    if KEYS[key] then Apply() end
end

local function UpdateMover()
    if not frame or InCombatLockdown() or (Readable() and ActiveChanged()) then return Apply() end
    frame.mover:SetShown(unlocked == true and On())
    RefreshGlows()
end

local function OnUnlock()
    unlocked = true
    if On() then UpdateMover() end
end

local function OnLock()
    unlocked = false
    if frame then UpdateMover() end
end

S.OnChange(OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local function Summary()
    return TEXT_SUMMARY
end

if not A.OLD_COPY then
    Settings.Page(A.PAGE, S):Card({
        id = "classBuffTracker", name = TITLE, order = ORDER, switch = "classBuffTracker",
        help = "Click to buff yourself, with active buff icons updated during combat.",
        summary = Summary,
        rows = {
            { key = "classBuffSize", label = "Icon Size", slider = SIZE_RANGE, needs = On, why = WHY_OFF },
            { key = "classBuffGlow", label = "Glow", toggle = true, needs = On, why = WHY_OFF,
                help = "Glows for missing buffs outside combat." },
            A.GlowRows("classBuffGlow", On, Glow.TRACKER_TYPES),
        },
    })
end

Apply()
