-- AurasPreview.lua: the PvP Auras card's preview, your target or focus with sample auras.
local ns = _G.NaowhForever

local P = ns.PvP
local S = P.Settings
local T = ns.THEME
local SPELLS = ns.PvPSpells
local St = P.Style
local Icon = P.Icon

local ICON_GAP, ROW_GAP, HEADER_PAD, NAME_GAP = St.ICON_GAP, St.ROW_GAP, St.HEADER_PAD, St.NAME_GAP
local NAME_SIZE, CLASS_ICONS, OUTLINE = St.NAME_SIZE, St.CLASS_ICONS, St.OUTLINE
local ABSORB_TEXT, ABSORB_SIZE, ABSORB_RGB = St.ABSORB_TEXT, St.ABSORB_SIZE, St.ABSORB_RGB
local ICONS = "Interface\\Icons\\"
local STAGE_MARGIN, NOTE_SIZE = St.STAGE_MARGIN, St.STAGE_NOTE_SIZE
local NOTE_ROOM, NOTE_Y = 24, 9
local ROW_COUNT = 3
local SAMPLE_ABSORB = 1240

local TEXT_ROWS_OFF = ns.L("Every row is off: nothing shows.")
local TEXT_NONE_PASS = ns.L("Nothing in these samples passes your settings.")
local TEXT_FOCUS = ns.L("Your focus, set with NF Focus: their timers keep counting while you fight someone else.")
local TEXT_TARGET = ns.L("Your target in a fight: short buffs, crowd control, then your debuffs.")

local SAMPLE_BUFFS = {
    { icon = "Spell_Holy_DivineIntervention", length = 12, magic = true, left = 9 },
    { icon = "Spell_Shadow_ShadowWard", length = 15, left = 11 },
    { icon = "Ability_Rogue_Sprint", length = 15, left = 6 },
    { icon = "Spell_Holy_SealOfProtection", length = 10, magic = true, left = 2 },
    { icon = "Ability_GhoulFrenzy", length = 15, left = 12, count = 3 },
    { icon = "Spell_Holy_PowerWordShield", length = 30, magic = true, left = 24 },
    { icon = "Spell_Nature_Lightning", length = 20, magic = true, left = 17 },
}
local SAMPLE_CC = {
    { key = "cc_sap", left = 38 }, { key = "cc_polymorph", left = 27 }, { key = "cc_kidneyShot", left = 4 },
    { key = "cc_fear", left = 8 }, { key = "cc_frostNova", left = 2 }, { key = "cc_silence", left = 3 },
    { key = "cc_hammerOfJustice", left = 5 }, { key = "cc_mindControl", left = 12 },
}
local SAMPLE_DEBUFFS = {
    { key = "debuff_mortalStrike", left = 7 }, { key = "debuff_woundPoison", left = 11, count = 4 },
    { key = "debuff_cripplingPoison", left = 9 }, { key = "debuff_curseOfTongues", left = 26 },
    { key = "debuff_hamstring", left = 13 }, { key = "debuff_frostShock", left = 6 },
}
local SAMPLE_FOCUS = { name = "Kalerith", class = "MAGE" }
local STATES = {
    { key = "target", label = "Target" },
    { key = "focus", label = "Focus", needs = "focus" },
}

local iconOf = {}
for _, entry in ipairs(SPELLS.crowdControl) do iconOf[P.CC_PREFIX .. entry.key] = entry.icon end
for _, entry in ipairs(SPELLS.debuffs) do iconOf[P.DEBUFF_PREFIX .. entry.key] = entry.icon end

local function HeaderRoom()
    return Icon.TextSize(NAME_SIZE) + HEADER_PAD + ROW_GAP
end

local function StageHeight()
    return STAGE_MARGIN * 2 + NOTE_ROOM + HeaderRoom() + Icon.Size() * ROW_COUNT + ROW_GAP * (ROW_COUNT - 1)
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.rows = { {}, {}, {} }
    shot.absorb = shot:CreateFontString(nil, "OVERLAY")
    shot.class = shot:CreateTexture(nil, "ARTWORK")
    shot.class:SetTexture(CLASS_ICONS)
    shot.name = shot:CreateFontString(nil, "OVERLAY")
    shot.note = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    shot.note:SetPoint("BOTTOM", 0, NOTE_Y)
    return shot
end

local function BuffShown(sample)
    return sample.length <= S.Get("buffLength") and (sample.magic or not S.Get("buffMagicOnly"))
end

local function SwitchedOn(sample)
    return S.Get(sample.key) == true
end

local PREVIEW_ROWS = {
    { key = "buffs", samples = SAMPLE_BUFFS, shown = BuffShown },
    { key = "cc", samples = SAMPLE_CC, shown = SwitchedOn },
    { key = "debuffs", samples = SAMPLE_DEBUFFS, shown = SwitchedOn },
}

local function Passing(samples, shown, max)
    local n = 0
    for _, sample in ipairs(samples) do
        if n < max and shown(sample) then n = n + 1 end
    end
    return n
end

local function SampleIcon(shot, icons, n)
    local f = icons[n]
    if f then return f end
    f = CreateFrame("Frame", nil, shot)
    Icon.New(f)
    icons[n] = f
    return f
end

local function PaintSample(f, sample)
    Icon.Style(f)
    f.icon:SetTexture(sample.icon and ICONS .. sample.icon or iconOf[sample.key])
    f.timeText:SetText(Icon.Formatter():Format(sample.left))
    local c = Icon.TimeColor(sample.left)
    f.timeText:SetTextColor(c[1], c[2], c[3], c[4])
    f.countText:SetText(sample.count and tostring(sample.count) or "")
end

local function PaintRow(shot, row, samples, shown, max, y)
    local size, icons, n = Icon.Size(), shot.rows[row], 0
    local count = Passing(samples, shown, max)
    local first = -(count - 1) * (size + ICON_GAP) / 2
    for _, sample in ipairs(samples) do
        if n < count and shown(sample) then
            n = n + 1
            local f = SampleIcon(shot, icons, n)
            PaintSample(f, sample)
            f:ClearAllPoints()
            f:SetPoint("TOP", shot, "TOP", first + (n - 1) * (size + ICON_GAP), -y)
            f:Show()
        end
    end
    for i = n + 1, #icons do icons[i]:Hide() end
    return n
end

local function PaintHeader(shot, d, y)
    local named = d.nameKey ~= nil and S.Get(d.nameKey) == true
    shot.name:SetShown(named)
    shot.class:SetShown(named)
    if not named then return end
    local nameSize = Icon.TextSize(NAME_SIZE)
    shot.name:SetFont(ns.UIFontPath(), nameSize, OUTLINE)
    shot.name:SetText(SAMPLE_FOCUS.name)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[SAMPLE_FOCUS.class]
    if color then shot.name:SetTextColor(color.r, color.g, color.b) end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[SAMPLE_FOCUS.class]
    shot.class:SetShown(coords ~= nil)
    if coords then Icon.SetClass(shot.class, coords) end
    shot.class:SetSize(nameSize + HEADER_PAD, nameSize + HEADER_PAD)
    shot.class:ClearAllPoints()
    shot.class:SetPoint("BOTTOMRIGHT", shot, "TOP", -ICON_GAP, -y)
    shot.name:ClearAllPoints()
    shot.name:SetPoint("LEFT", shot.class, "RIGHT", NAME_GAP, 0)
end

local function FirstShown(shot)
    for i = 1, #PREVIEW_ROWS do
        local icon = shot.rows[i][1]
        if icon and icon:IsShown() then return icon end
    end
end

local function PaintAbsorb(shot)
    local first = FirstShown(shot)
    shot.absorb:SetFont(ns.UIFontPath(), Icon.TextSize(ABSORB_SIZE), OUTLINE)
    shot.absorb:SetTextColor(ABSORB_RGB.r, ABSORB_RGB.g, ABSORB_RGB.b)
    shot.absorb:SetFormattedText(ABSORB_TEXT, SAMPLE_ABSORB)
    shot.absorb:ClearAllPoints()
    if first then shot.absorb:SetPoint("RIGHT", first, "LEFT", -NAME_GAP, 0) end
    shot.absorb:SetShown(S.Get("absorb") == true and first ~= nil)
end

local function Note(d, anyRow, drawn)
    if not anyRow then return TEXT_ROWS_OFF end
    if drawn == 0 then return TEXT_NONE_PASS end
    if d.nameKey then return TEXT_FOCUS end
    return TEXT_TARGET
end

local function PaintPreview(shot, state)
    local displays = P.Displays
    local d = state == "focus" and displays[2] or displays[1]
    local rows = 0
    for _, row in ipairs(PREVIEW_ROWS) do
        if P.RowOn(d, row.key) then rows = rows + 1 end
    end
    local block = rows * Icon.Size() + math.max(rows - 1, 0) * ROW_GAP
    local y = math.floor((StageHeight() - NOTE_ROOM - block + HeaderRoom()) / 2)
    PaintHeader(shot, d, y - ROW_GAP)
    local drawn, anyRow = 0, false
    for i, row in ipairs(PREVIEW_ROWS) do
        local on = P.RowOn(d, row.key)
        drawn = drawn + PaintRow(shot, i, row.samples, row.shown, on and S.Get(P.MAX_KEY[row.key]) or 0, y)
        if on then
            anyRow = true
            y = y + Icon.Size() + ROW_GAP
        end
    end
    PaintAbsorb(shot)
    shot.note:SetText(Note(d, anyRow, drawn))
end

P.AurasPreview = { height = StageHeight, states = STATES, new = NewPreview, paint = PaintPreview }
