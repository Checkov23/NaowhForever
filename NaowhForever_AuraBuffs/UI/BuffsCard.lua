-- BuffsCard.lua: the Buffs & Consumables card on the AuraBuffs/Settings page, with its preview.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local D = ns.BuffReminderData
local T = ns.THEME
local R, Cell = A.Buffs, A.BuffCell

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local STAGE_H, NOTE_Y, NOTE_SIZE, STAGE_MARGIN = 120, A.Style.STAGE_NOTE_Y, A.Style.STAGE_NOTE_SIZE, A.Style.STAGE_MARGIN
local MINUTES_RANGE, ICON_RANGE, TEXT_RANGE = { 0, 10, 1 }, { 20, 64, 1 }, ns.Shared.Style.HUD_TEXT_RANGE
local ORDER_BUFFS = 10
local PREVIEW = A.BuffPreview
local RAID_SAMPLE = #PREVIEW
local WHERE = { { always = "Everywhere", instance = "Dungeons & Raids", raid = "Raids Only" },
    { "always", "instance", "raid" } }
local STATES = {
    { key = "raid", label = "In a Raid", tip = "In a raid, where every Show In choice reminds you." },
    { key = "world", label = "Open World", tip = "Out in the world, where only Everywhere reminds you." },
    { key = "resting", label = "Resting", tip = "In a city or an inn, where Hide While Resting hides them.",
      needs = "hideResting" },
}

local OFF = ns.L("Turn on AuraBuffs")
local NEEDS_RAID = ns.L("Needs Raid Buff Reminders")
local NEEDS_PERSONAL = ns.L("Needs Personal Buff Reminders")
local TEXT_NOTHING = ns.L("Nothing to remind you of here.")
local TEXT_SAMPLE = ns.L("Sample icons: add the consumables to watch in the AuraBuffs window.")
local TEXT_BLESSINGS = ns.L("Off by default: the Blessings module covers them.")

local PERSONAL = {}
local _, playerClass = UnitClass("player")
for _, family in ipairs(D.PERSONAL) do
    if family.class == playerClass then PERSONAL[#PERSONAL + 1] = family end
end

local Enabled = A.Enabled
local RaidBuffsOn = A.Needs("raidBuffs")
local PersonalBuffsOn = A.Needs("personalBuffs")

local function OpenList()
    ns.OpenAuraBuffsWindow("consumables")
end

local function EditList()
    if ns.OpenFromOptions then ns.OpenFromOptions(OpenList) else OpenList() end
end

local function ConsumablesShown(state)
    if state == "resting" then return false end
    return state == "raid" or S.Get("consumablesWhere") == "always"
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.row = CreateFrame("Frame", nil, shot)
    shot.cells = {}
    for i = 1, #PREVIEW do shot.cells[i] = Cell.New(shot.row) end
    shot.personal = Cell.New(shot.row)
    shot.note = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    shot.note:SetPoint("BOTTOM", 0, NOTE_Y)
    return shot
end

local function Fit(shot)
    local row = shot.row
    local w, h = row:GetWidth(), row:GetHeight()
    local roomW = shot:GetWidth() - STAGE_MARGIN * 2
    local roomH = shot:GetHeight() - STAGE_MARGIN * 2 - NOTE_Y * 2
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h > 0 and h * scale > roomH then scale = roomH / h end
    row:SetScale(scale)
    row:ClearAllPoints()
    row:SetPoint("CENTER", shot, "CENTER", 0, NOTE_Y / scale)
end

local function RaidSample()
    if not S.Get("raidBuffs") then return nil end
    for _, family in ipairs(D.RAID) do
        if R.Picked(family) then return family.spells[1] end
    end
end

local function PersonalSample()
    if not S.Get("personalBuffs") then return nil end
    for _, family in ipairs(PERSONAL) do
        if R.PersonalPicked(family) then return family.spells[1] end
    end
end

local function PaintPreview(shot, state)
    local size = S.Get("iconSize")
    local consumables, raid = ConsumablesShown(state), RaidSample()
    local personal = state ~= "resting" and PersonalSample()
    local n = 0
    local function Put(cell, icon, count)
        n = n + 1
        Cell.Place(cell, shot.row, n, size, icon, count)
    end
    for i = 1, RAID_SAMPLE - 1 do
        local p = PREVIEW[i]
        if consumables then Put(shot.cells[i], p.item and C_Item.GetItemIconByID(p.item) or C_Spell.GetSpellTexture(p.spell), p.count) end
        shot.cells[i]:SetShown(consumables)
    end
    if personal then Put(shot.personal, C_Spell.GetSpellTexture(personal)) end
    shot.personal:SetShown(personal and true or false)
    local raidCell = shot.cells[RAID_SAMPLE]
    if raid then Put(raidCell, C_Spell.GetSpellTexture(raid), PREVIEW[RAID_SAMPLE].count) end
    raidCell:SetShown(raid and true or false)
    Cell.Fit(shot.row, n, size)
    Fit(shot)
    local note = ""
    if n == 0 then
        note = TEXT_NOTHING
    elseif consumables and #(S.Get("consumableEntries") or {}) == 0 then
        note = TEXT_SAMPLE
    end
    shot.note:SetText(note)
end

local function Summary(store)
    local n = #(store.Get("consumableEntries") or {})
    local parts = { n == 1 and ns.L("1 consumable") or ns.L("%d consumables"):format(n) }
    if store.Get("raidBuffs") then parts[#parts + 1] = ns.L("raid buffs") end
    if store.Get("personalBuffs") and #PERSONAL > 0 then parts[#parts + 1] = ns.L("personal buffs") end
    return table.concat(parts, ", ")
end

local function PickRow(family)
    return { key = "raidBuffPicks", field = family.key, label = family.name, toggle = true,
        needs = RaidBuffsOn, why = NEEDS_RAID,
        help = family.class == "PALADIN" and TEXT_BLESSINGS or nil,
        get = function() return R.Picked(family) end,
        set = function(on)
            local picks = {}
            for k, v in pairs(S.Get("raidBuffPicks")) do picks[k] = v end
            picks[family.key] = on
            S.Set("raidBuffPicks", picks)
        end }
end

local function PersonalRow(family)
    return { key = "personalBuffPicks", field = family.key, label = family.name, toggle = true,
        needs = PersonalBuffsOn, why = NEEDS_PERSONAL, help = family.help,
        get = function() return R.PersonalPicked(family) end,
        set = function(on)
            local picks = {}
            for k, v in pairs(S.Get("personalBuffPicks")) do picks[k] = v end
            picks[family.key] = on
            S.Set("personalBuffPicks", picks)
        end }
end

local rows = {
    Group("Consumables"),
    { key = "consumablesWhere", label = "Show In", choice = WHERE, needs = Enabled, why = OFF },
    { key = "consumablesMinutes", label = "Warn With Minutes Left", slider = MINUTES_RANGE, unit = " min",
      needs = Enabled, why = OFF,
      help = "A consumable or personal buff with less time than this left counts as missing." },
    { key = "onlyIfCarried", label = "Only If I Carry One", toggle = true, needs = Enabled, why = OFF,
      help = "Off: a reminder for each kind you watch, even with none in your bags." },
    { key = "hideResting", label = "Hide While Resting", toggle = true, needs = Enabled, why = OFF,
      help = "No consumable or personal buff reminders in cities and inns." },
    { label = "Consumables to Watch", buttonText = "Edit List", needs = Enabled, why = OFF,
      button = EditList,
      help = "Opens the AuraBuffs window, where you add each item by its item ID and buff spell ID.",
      search = "import export" },
    Group("Raid Buffs"),
    { key = "raidBuffs", label = "Raid Buff Reminders", toggle = true, needs = Enabled, why = OFF,
      help = "Missing class buffs in your group, out of combat, with how many are missing them. A camp "
          .. "buff standing in for one, the Incense Candle for Arcane Intellect for example, is not seen, "
          .. "so it still counts as missing." },
    { key = "raidBuffsOwn", label = "Only Buffs I Can Cast", toggle = true, needs = RaidBuffsOn,
      why = NEEDS_RAID, help = "Off: every buff a class in your group can cast." },
}
for _, family in ipairs(D.RAID) do rows[#rows + 1] = PickRow(family) end
if #PERSONAL > 0 then
    rows[#rows + 1] = Group("Personal Buffs")
    rows[#rows + 1] = { key = "personalBuffs", label = "Personal Buff Reminders", toggle = true, needs = Enabled,
        why = OFF, help = "Your own class buff when it is missing or under Warn With Minutes Left: an armor, "
            .. "Inner Fire, Battle Shout, poisons or a weapon imbue. Talent buffs only once you have the "
            .. "talent. Hide While Resting hides them too." }
    for _, family in ipairs(PERSONAL) do rows[#rows + 1] = PersonalRow(family) end
end
rows[#rows + 1] = Group("Size")
rows[#rows + 1] = { key = "iconSize", label = "Icon Size", slider = ICON_RANGE, needs = Enabled, why = OFF }
rows[#rows + 1] = Settings.Look("buffs", { text = true, size = TEXT_RANGE, needs = Enabled, why = OFF })

Settings.Page(A.PAGE, S):Card({
    id = "buffs", name = "Buffs & Consumables", order = ORDER_BUFFS,
    help = "A row of icons for missing food, flask, elixir and scroll buffs, your own class buff, and class "
        .. "buffs missing in your group. Out of combat only: the game keeps your buffs from addons in combat, so the "
        .. "icons keep what they showed. Hover one to pick a carried item to use. Move them in the HUD Editor.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = rows,
})
