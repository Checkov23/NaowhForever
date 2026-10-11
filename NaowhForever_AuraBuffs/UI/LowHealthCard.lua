-- LowHealthCard.lua: the Low Health card on the AuraBuffs/Settings page, with its preview.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local T = ns.THEME
local Look = A.LowHealthLook

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local STAGE_H, NOTE_Y, NOTE_SIZE, STAGE_MARGIN, LABEL_ROOM = 150, A.Style.STAGE_NOTE_Y, A.Style.STAGE_NOTE_SIZE, A.Style.STAGE_MARGIN, 24
local BELOW_RANGE, ICON_RANGE, TEXT_RANGE = { 10, 90, 1 }, { 24, 96, 1 }, { 10, 28, 1 }
local ORDER_LOW_HEALTH = 40
local GLOW_RGB = A.Style.LOW_RGB
local GLOW_OUT = 2
local SAMPLE_POTIONS = 3
local ITEMS = { { auto = "Best in Bags", stone = "Healthstone", potion = "Healing Potion" },
    { "auto", "stone", "potion" } }
local STATES = {
    { key = "low", label = "Low Health", tip = "Your health under the threshold, with a healing item in your bags." },
    { key = "none", label = "None in Bags", tip = "Your health under the threshold, with nothing to drink or eat." },
}

local OFF = ns.L("Turn on AuraBuffs")
local TEXT_NOTE = ns.L("Shown below %d%% health, in combat too.")

local Enabled = A.Enabled
local SoundOn = A.Needs("lowHealthSound")

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.icon = CreateFrame("Frame", nil, shot)
    Look.New(shot.icon)
    shot.glow = CreateFrame("Frame", nil, shot.icon)
    shot.glow:SetPoint("TOPLEFT", -GLOW_OUT, GLOW_OUT)
    shot.glow:SetPoint("BOTTOMRIGHT", GLOW_OUT, -GLOW_OUT)
    ns.Border(shot.glow, GLOW_RGB)
    shot.note = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    shot.note:SetPoint("BOTTOM", 0, NOTE_Y)
    return shot
end

local function SampleItem(state, mode)
    if state ~= "low" then return nil end
    return mode == "potion" and ns.HEALING_POTIONS[1] or ns.HEALTHSTONES[1]
end

local function PaintPreview(shot, state)
    local f = shot.icon
    local size = S.Get("lowHealthIconSize")
    f:SetSize(size, size)
    Look.Style(f)
    local room = shot:GetHeight() - STAGE_MARGIN * 2 - NOTE_Y * 2 - LABEL_ROOM
    local scale = (room > 0 and size > room) and room / size or 1
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", shot, "CENTER", 0, (NOTE_Y + LABEL_ROOM / 2) / scale)
    local mode = S.Get("lowHealthItem")
    Look.Item(f, SampleItem(state, mode), mode == "potion" and SAMPLE_POTIONS or 1)
    shot.glow:SetShown(S.Get("lowHealthGlow"))
    shot.note:SetText(TEXT_NOTE:format(S.Get("lowHealthBelow")))
end

local function Summary(store)
    return (ns.L("Below %d%%, %s")):format(store.Get("lowHealthBelow"), ns.L(ITEMS[1][store.Get("lowHealthItem")] or ""))
end

Settings.Page(A.PAGE, S):Card({
    id = "lowHealth", name = "Low Health", order = ORDER_LOW_HEALTH, switch = "lowHealth",
    help = "Shows a healing item's icon the moment your health drops below the threshold, in combat too: "
        .. "the game shows and hides it itself. Move it in the HUD Editor.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        { key = "lowHealthBelow", label = "Show Below", slider = BELOW_RANGE, unit = "%", needs = Enabled,
          why = OFF },
        { key = "lowHealthItem", label = "Item", choice = ITEMS, needs = Enabled, why = OFF,
          help = "Best in Bags: your best healthstone, else your best healing potion." },
        { key = "lowHealthGlow", label = "Glow", toggle = true, needs = Enabled, why = OFF,
          help = "A red glow around the icon while it shows." },
        { key = "lowHealthSound", label = "Play a Sound", toggle = true, needs = Enabled, why = OFF,
          help = "Plays once each time your health drops below the threshold. If the game hides your "
              .. "health from addons mid-fight, it only plays out of combat." },
        { key = "lowHealthSoundKey", label = "Sound", sound = true, needs = SoundOn, why = "Needs Play a Sound" },
        Settings.Group("Size"),
        { key = "lowHealthIconSize", label = "Icon Size", slider = ICON_RANGE, needs = Enabled, why = OFF },
        Settings.Look("lowHealth", { text = true, size = TEXT_RANGE, needs = Enabled, why = OFF }),
    },
})
