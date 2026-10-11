-- HealerMana.lua: Healer Mana, every healer in your group and their mana, lowest first.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local MANA, MANA_TOKEN = 0, "MANA"
local DRINK_SPELL = 430
local DRINK_ICON = "Interface\\Icons\\INV_Drink_07"
local HEALER_CLASSES = { PRIEST = true, PALADIN = true, DRUID = true, SHAMAN = true }
local UPDATE_DELAY = 0.25
local BASE_SIZE, ROW_PAD, PAD, ICON_GAP, COLUMN_GAP = 12, 4, 6, 4, 8
local ICON_CROP = ns.QoLConstants.ICON_CROP_TIGHT
local ICON_DROP = 1
local LOW, OUT = 0.6, 0.3
local RAID_SIZE, PARTY_SIZE = ns.QoLConstants.RAID_SIZE, ns.QoLConstants.PARTY_SIZE
local PERMILLE, ROUND, TENTHS = ns.QoLConstants.PERMILLE, ns.QoLConstants.ROUND, ns.QoLConstants.TENTHS
local PERCENT = ns.QoLConstants.PERCENT
local PCT_FORMAT = "%.1f%%"
local DEAD, OFFLINE, UNKNOWN = ns.L("Dead"), ns.L("Offline"), "--"
local NO_RANK = math.huge
local PLACE = { point = "LEFT", relPoint = "LEFT", x = 40, y = -120 }
local UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION", "UNIT_AURA" }
local GROUP_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD" }

local MOVER_LABEL = "Healer Mana"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Combat", "QoL/Combat:healerMana"
local TEXT_IN_GROUP = ns.L("Shown while you are in a group.")
local TEXT_IN_INSTANCES = ns.L("Shown in dungeons and raids.")
local SUMMARY = ns.L("%s, %d wide")
local STAGE_H = 150
local NOTE_Y, NOTE_SIZE, STAGE_MARGIN = St.STAGE_NOTE_Y, St.STAGE_NOTE_SIZE, St.STAGE_MARGIN
local WIDTH_RANGE = { 100, 300, 5 }
local TEXT_RANGE = { 8, 20, 1 }

local frame, unlocked, pending, rosterPending, drinkName, shareCurve
local look = 0
local rows, members, list, tracked, rank, units, watchers = {}, {}, {}, {}, {}, {}, {}

local RAID, PARTY = {}, {}
for i = 1, RAID_SIZE do RAID[i] = "raid" .. i end
for i = 1, PARTY_SIZE do PARTY[i] = "party" .. i end
local backdrops = setmetatable({}, { __mode = "k" })

local function On()
    return S.Get("enabled") and S.Get("healerMana")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function Here()
    if not IsInGroup() then return false end
    if S.Get("healerManaWhere") == "group" then return true end
    local _, kind = IsInInstance()
    return kind == "party" or kind == "raid"
end

local function IsHealer(unit, class)
    local role = UnitGroupRolesAssigned(unit)
    if Secret(role) then role = nil end
    if role == "HEALER" then return true end
    if role == "TANK" or role == "DAMAGER" then return false end
    return HEALER_CLASSES[class] == true
end

local function Units()
    wipe(units)
    if S.Get("healerManaShowSelf") then units[1] = "player" end
    if IsInRaid() then
        for i = 1, math.min(GetNumGroupMembers(), #RAID) do
            local unit = RAID[i]
            local me = UnitIsUnit(unit, "player")
            if not Secret(me) and not me then units[#units + 1] = unit end
        end
    else
        for i = 1, math.min(GetNumSubgroupMembers(), #PARTY) do units[#units + 1] = PARTY[i] end
    end
    return units
end

local function Track(unit, name, guid, class)
    local n = #list + 1
    local m = members[n] or {}
    members[n] = m
    if m.guid ~= guid then m.pct, m.drinking = nil, false end
    m.unit, m.name, m.class, m.guid = unit, name, class, guid
    list[n] = m
    tracked[unit] = m
end

local function Roster()
    wipe(list)
    wipe(tracked)
    for _, unit in ipairs(Units()) do
        local name, guid = UnitName(unit), UnitGUID(unit)
        local _, class = UnitClass(unit)
        if name and guid and not (Secret(name) or Secret(guid) or Secret(class)) and IsHealer(unit, class) then
            Track(unit, name, guid, class)
        end
    end
end

local function CanReadDrink()
    if not S.Get("healerManaDrinking") or C_Secrets.ShouldAurasBeSecret() then return false end
    drinkName = drinkName or C_Spell.GetSpellName(DRINK_SPELL)
    return drinkName ~= nil
end

local function Drinking(m)
    if not (CanReadDrink() and C_UnitAuras.GetAuraDataBySpellName) then return end
    local aura = C_UnitAuras.GetAuraDataBySpellName(m.unit, drinkName, "HELPFUL")
    m.drinking = aura ~= nil
    m.drinkID = aura and aura.auraInstanceID or nil
end

local function DrinkAdded(m, added)
    for i = 1, #added do
        local name = added[i].name
        if not Secret(name) and name == drinkName then
            m.drinking, m.drinkID = true, added[i].auraInstanceID
        end
    end
end

local function DrinkRemoved(m, removed, id)
    for i = 1, #removed do
        if removed[i] == id then m.drinking, m.drinkID = false, nil end
    end
end

local function DrinkChanged(m, info)
    if not CanReadDrink() then return false end
    local was = m.drinking
    if not info or info.isFullUpdate then
        Drinking(m)
        return m.drinking ~= was
    end
    if info.addedAuras then DrinkAdded(m, info.addedAuras) end
    local removed, id = info.removedAuraInstanceIDs, m.drinkID
    if removed and id then DrinkRemoved(m, removed, id) end
    return m.drinking ~= was
end

local function Read(m)
    local unit = m.unit
    local online, dead = UnitIsConnected(unit), UnitIsDeadOrGhost(unit)
    if Secret(online) then online = true end
    if Secret(dead) then dead = false end
    m.state = (not online and OFFLINE) or (dead and DEAD) or nil
    local cur, max = UnitPower(unit, MANA), UnitPowerMax(unit, MANA)
    m.secret = (Secret(cur) or Secret(max)) == true
    if not m.secret and max > 0 then m.pct = cur / max end
end

local function Less(a, b)
    if (a.state ~= nil) ~= (b.state ~= nil) then return b.state ~= nil end
    local pa, pb = a.pct or NO_RANK, b.pct or NO_RANK
    if pa ~= pb then return pa < pb end
    if a.name ~= b.name then return a.name < b.name end
    return a.guid < b.guid
end

local function Held(a, b)
    local ra, rb = rank[a.guid] or NO_RANK, rank[b.guid] or NO_RANK
    if ra ~= rb then return ra < rb end
    if a.name ~= b.name then return a.name < b.name end
    return a.guid < b.guid
end

local function Sort()
    for i = 1, #list do
        if list[i].secret then
            table.sort(list, Held)
            return
        end
    end
    table.sort(list, Less)
    wipe(rank)
    for i = 1, #list do rank[list[i].guid] = i end
end

local function ManaColour(pct)
    if pct < OUT then return St.TIME_OUT_RGB end
    if pct < LOW then return St.TIME_LOW_RGB end
    return St.TIME_OK_RGB
end

local function SecretShare(fs, unit)
    if not (UnitPowerPercent and C_CurveUtil) then return false end
    if not shareCurve then
        shareCurve = C_CurveUtil.CreateCurve()
        shareCurve:SetType(Enum.LuaCurveType.Linear)
        shareCurve:AddPoint(0, 0)
        shareCurve:AddPoint(1, PERCENT)
    end
    fs:SetFormattedText(PCT_FORMAT, UnitPowerPercent(unit, MANA, false, shareCurve))
    return true
end

local function Colour(fs, c)
    fs:SetTextColor(c.r, c.g, c.b)
end

local Look = {}

function Look.NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexture(DRINK_ICON)
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.icon:SetPoint("LEFT", 0, -ICON_DROP)
    row.pct = ns.Font(row, BASE_SIZE, "OUTLINE")
    row.pct:SetPoint("RIGHT")
    row.pct:SetJustifyH("RIGHT")
    row.name = ns.Font(row, BASE_SIZE, "OUTLINE")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

function Look.Style(row, size, iconRoom)
    local font, outline, background = S.Get("healerManaFont"), S.Get("healerManaOutline"), S.Get("healerManaBackground")
    row:SetHeight(size + ROW_PAD)
    Parts.HudFont(row.name, font, size, outline, background)
    Parts.HudFont(row.pct, font, size, outline, background)
    row.icon:SetSize(size, size)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", iconRoom, 0)
    row.name:SetPoint("RIGHT", row.pct, "LEFT", -COLUMN_GAP, 0)
    row.look = look
end

function Look.Paint(row, m, drinks)
    row.name:SetText(m.name)
    Colour(row.name, RAID_CLASS_COLORS[m.class] or T.fg)
    row.icon:SetShown(drinks and m.drinking == true)
    if m.state then
        row.shownPct = nil
        row.pct:SetText(m.state)
        Colour(row.pct, m.state == DEAD and St.RED_RGB or T.muted)
    elseif m.secret then
        Colour(row.pct, T.fg)
        row.shownPct = nil
        if not SecretShare(row.pct, m.unit) then row.pct:SetText(UNKNOWN) end
    elseif m.pct then
        local shown = math.floor(m.pct * PERMILLE + ROUND)
        if row.shownPct ~= shown then
            row.shownPct = shown
            row.pct:SetText(PCT_FORMAT:format(shown / TENTHS))
        end
        Colour(row.pct, ManaColour(m.pct))
    else
        row.shownPct = nil
        row.pct:SetText(UNKNOWN)
        Colour(row.pct, T.muted)
    end
    row:Show()
end

local function FitCard(owner, count, step)
    local backdrop = backdrops[owner] or Parts.HudBackdrop(owner)
    backdrops[owner] = backdrop
    if owner.look == look and owner.count == count then return end
    owner.look, owner.count = look, count
    backdrop:SetMode(S.Get("healerManaBackground"))
    owner:SetSize(S.Get("healerManaWidth"), count * step + 2 * PAD)
end

local function PoolRow(owner, pool, i)
    local row = pool[i]
    if not row then
        row = Look.NewRow(owner)
        pool[i] = row
    end
    return row
end

function Look.Rows(owner, pool, entries)
    local size, drinks = S.Get("healerManaFontSize"), S.Get("healerManaDrinking")
    local iconRoom = drinks and size + ICON_GAP or 0
    local step = size + ROW_PAD
    FitCard(owner, #entries, step)
    for i, m in ipairs(entries) do
        local row = PoolRow(owner, pool, i)
        if row.look ~= look then
            row.shownPct = nil
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD, -PAD - (i - 1) * step)
            row:SetPoint("TOPRIGHT", -PAD, -PAD - (i - 1) * step)
            Look.Style(row, size, iconRoom)
        end
        Look.Paint(row, m, drinks)
    end
    for i = #entries + 1, #pool do pool[i]:Hide() end
end

local SAMPLE = {
    { name = "Priest", class = "PRIEST", guid = "1", pct = 0.18 },
    { name = "Druid", class = "DRUID", guid = "2", pct = 0.47, drinking = true },
    { name = "Shaman", class = "SHAMAN", guid = "3", pct = 0.83 },
    { name = "Paladin", class = "PALADIN", guid = "4", state = DEAD },
}

local function Redraw()
    if not frame then return end
    if unlocked then
        Look.Rows(frame, rows, SAMPLE)
        frame:Show()
        return
    end
    if not (On() and Here()) or #list == 0 then
        frame:Hide()
        return
    end
    for i = 1, #list do Read(list[i]) end
    Sort()
    Look.Rows(frame, rows, list)
    frame:Show()
end

local function Flush()
    pending = false
    Redraw()
end

local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(UPDATE_DELAY, Flush)
end

local function Place()
    local pos = S.Get("healerManaPos") or PLACE
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local events = CreateFrame("Frame")
local Apply, OnUnitEvent

local function Watch()
    for i, m in ipairs(list) do
        local w = watchers[i]
        if not w then
            w = CreateFrame("Frame")
            w:SetScript("OnEvent", OnUnitEvent)
            watchers[i] = w
        end
        if w.unit ~= m.unit then
            w.unit = m.unit
            for _, event in ipairs(UNIT_EVENTS) do w:RegisterUnitEvent(event, m.unit) end
        end
    end
    for i = #list + 1, #watchers do
        watchers[i]:UnregisterAllEvents()
        watchers[i].unit = nil
    end
end

local function RosterDue()
    rosterPending = false
    Apply()
end

local function RosterSoon()
    if rosterPending then return end
    rosterPending = true
    C_Timer.After(UPDATE_DELAY, RosterDue)
end

local function SavePosition(pos)
    S.Set("healerManaPos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverHealerMana", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.mover = ns.UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
end

function Apply()
    if not On() then
        events:UnregisterAllEvents()
        wipe(list)
        wipe(tracked)
        Watch()
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    for _, event in ipairs(GROUP_EVENTS) do events:RegisterEvent(event) end
    wipe(list)
    wipe(tracked)
    if Here() then
        Roster()
        for i = 1, #list do Drinking(list[i]) end
    end
    Watch()
    Place()
    frame.mover:SetShown(unlocked == true)
    Redraw()
end

local function OnGroupEvent(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Apply()
    else
        RosterSoon()
    end
end

events:SetScript("OnEvent", OnGroupEvent)

function OnUnitEvent(watcher, event, unit, arg)
    if event == "UNIT_POWER_UPDATE" and (Secret(arg) or arg ~= MANA_TOKEN) then return end
    local m = tracked[watcher.unit]
    if not m then return end
    if event == "UNIT_AURA" and not DrinkChanged(m, arg) then return end
    Soon()
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^healerMana") and key ~= "healerManaPos") then
        look = look + 1
        Apply()
    end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", function() Apply() end)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if frame then
        frame.mover:Hide()
        Apply()
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() Apply() end)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local STATES = {
    { key = "group", label = "In a Group", tip = "Your healers' mana, with sample healers." },
}
local WHERE = { { instance = "Dungeons & Raids", group = "Any Group" }, { "instance", "group" } }

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.group = CreateFrame("Frame", nil, preview)
    preview.rows = {}
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y)
    return preview
end

local function PaintPreview(preview)
    local group = preview.group
    preview.note:SetText(S.Get("healerManaWhere") == "group" and TEXT_IN_GROUP or TEXT_IN_INSTANCES)
    Look.Rows(group, preview.rows, SAMPLE)
    local w, h = group:GetWidth(), group:GetHeight()
    local roomW = preview:GetWidth() - STAGE_MARGIN * 2
    local roomH = preview:GetHeight() - STAGE_MARGIN * 2 - NOTE_Y * 2
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h > 0 and h * scale > roomH then scale = roomH / h end
    group:SetScale(scale)
    group:ClearAllPoints()
    group:SetPoint("CENTER", preview, "CENTER", 0, NOTE_Y / scale)
end

local function Summary(store)
    return SUMMARY:format(WHERE[1][store.Get("healerManaWhere")] or WHERE[1].instance,
        store.Get("healerManaWidth"))
end

Settings.Page("QoL/Combat", S):Card({
    id = "healerMana", name = "Healer Mana", order = 45, switch = "healerMana",
    help = "Your group's healers and their mana, lowest first.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        { key = "healerManaWhere", label = "Show In", choice = WHERE },
        { key = "healerManaShowSelf", label = "Show Yourself", toggle = true,
          help = "Your own mana among the healers'." },
        { key = "healerManaDrinking", label = "Mark Drinking", toggle = true,
          help = "A cup beside a healer who is drinking." },
        Settings.Group("Size"),
        { key = "healerManaWidth", label = "Width", slider = WIDTH_RANGE },
        Settings.Look("healerMana", { text = true, size = TEXT_RANGE, background = "card" }),
    },
})
