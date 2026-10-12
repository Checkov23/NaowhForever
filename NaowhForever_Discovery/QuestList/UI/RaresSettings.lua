-- RaresSettings.lua: the Rares settings page (Discovery/Rares), declared as cards, with the alert's preview, and its rare pins' rows on QoL > Map & Pins.
local ns = _G.NaowhForever

local Completo = ns.Completo
local C = Completo.C
local S = Completo.Settings
local R = Completo.Rares
local Sounds = Completo.Sounds
local Card = Completo.AlertCard
local RareAlert = Completo.RareAlert
local Settings = ns.Shared.Settings

local PAGE = "Discovery/Rares"
local STAGE_H = 110
local CARD_ROOM = 32
local CARD_ROOM_V = 8
local FALLBACK_STAGE_W = 600
local SAMPLE_MAP, SAMPLE_X, SAMPLE_Y = 1440, 50, 40
local SAMPLE_RECORD = { n = 1 }
local STATES = {
    { key = "new", label = "Not Killed", tip = "A rare you have not killed yet." },
    { key = "killed", label = "Killed Before", tip = "A rare you have killed before." },
    { key = "tapped", label = "Tapped", tip = "A rare someone else is fighting." },
}
local ALERT_TIME = { 5, 60, 1 }
local ALERT_SCALE = { 50, 200, 5 }
local FONT_SIZE = { 10, 20, 1 }
local PIN_SIZE = ns.Shared.Style.PIN_SIZE_RANGE
local PERCENT_SCALE = ns.Shared.Style.PERCENT_SCALE
local ORDER_RARES, ORDER_ALERT = 10, 20
local TEXT_OFF = ns.L("Turn on Discovery")
local TEXT_SOUND_OFF = ns.L("Needs Play a Sound")
local TEXT_PINS_OFF = ns.L("Turn on Rares")
local TEXT_PROGRESS = ns.L("%d of %d rares killed")
local TEXT_ZONE = ns.L("%s: %d of %d.")
local TEXT_EVERY_RARE = ns.L("Every rare of every zone, and which of them you have killed.")
local TEXT_WARNING = ns.L("A warning when a rare is near")
local TEXT_WITH_SOUND = ns.L(", a sound")

local page = Settings.Page(PAGE, S)

local function Enabled() return S.Get("enabled") == true end
local function SoundOn() return Enabled() and S.Get("rareSound") == true end
local function PinsOn() return Enabled() and S.Get("rarePins") == true end

local function Headline()
    return TEXT_PROGRESS:format(R.Progress())
end

local function Detail()
    local zone = R.CurrentZone()
    if not zone then return TEXT_EVERY_RARE end
    local n, total = R.ZoneProgress(zone)
    return TEXT_ZONE:format(zone.name, n, total)
end

local function OpenRares()
    ns.OpenCompletoWindow("rares")
end

local function AlertSummary(store)
    if store.Get("rareSound") then return TEXT_WARNING .. TEXT_WITH_SOUND end
    return TEXT_WARNING
end

local function GetSound()
    return Sounds.Picked(S.Get("rareSoundKey"))
end

local function SetSound(key)
    S.Set("rareSoundKey", key)
    Sounds.Play(key)
end

local function PreviewShown(preview)
    Card.SetPortrait(preview.card, nil, C.SAMPLE_RARE_NPC)
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.card = Card.New(preview)
    preview.card:EnableMouse(false)
    preview.card.pin:EnableMouse(false)
    preview.seen = {}
    preview:SetScript("OnShow", PreviewShown)
    PreviewShown(preview)
    return preview
end

local function FillSample(seen, state)
    local npc = C.SAMPLE_RARE_NPC
    seen.name, seen.level, seen.npc = C.SAMPLE_RARE_NAME, C.SAMPLE_RARE_LEVEL, npc
    seen.elite = R.Known(npc) and R.Elite(npc)
    seen.record = state == "killed" and SAMPLE_RECORD or false
    seen.tapped = state == "tapped" or nil
    seen.map, seen.x, seen.y = SAMPLE_MAP, SAMPLE_X, SAMPLE_Y
end

local function FitCard(preview, card)
    local w, h = preview:GetWidth(), preview:GetHeight()
    if not w or w <= 0 then w = FALLBACK_STAGE_W end
    if not h or h <= 0 then h = STAGE_H end
    local fit = math.min(S.Get("rareAlertScale"), (w - CARD_ROOM) / Card.W, (h - CARD_ROOM_V) / (Card.H + Card.GLOW * 2))
    card:SetScale(fit)
    card:ClearAllPoints()
    card:SetPoint("CENTER", preview, "CENTER", 0, 0)
end

local function PaintPreview(preview, state)
    FillSample(preview.seen, state)
    local card = preview.card
    if not card.model:GetModelFileID() then PreviewShown(preview) end
    Card.Paint(card, preview.seen)
    FitCard(preview, card)
end

page:Window({
    text = "Open Rares",
    open = OpenRares,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "rares", name = "Rares", order = ORDER_RARES,
    help = "What a zone's page in the Quest List window lists. Kills count from when Discovery is on: "
        .. "Shift-click a rare there to tick off one you killed before.",
    rows = {
        { key = "rareHideKilled", label = "Hide Killed Rares", toggle = true,
          help = "Leaves the rares you have killed out of a zone's list in the Quest List window." },
    },
})

page:Card({
    id = "rareAlert", name = "Rare Alerts", order = ORDER_ALERT, switch = "rareAlert",
    help = "A warning when a rare is near you: when its nameplate comes up, you mouse over it or target "
        .. "it. A card with its portrait: right-click it to close it, and its pin sets a waypoint to the "
        .. "rare. Move it in the HUD Editor.",
    summary = AlertSummary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Settings.Group("Alert"),
        { key = "rareAlertKilled", label = "Alert for Killed Rares", toggle = true, needs = Enabled, why = TEXT_OFF,
          help = "Also warns about rares you have killed before." },
        { key = "rareSound", label = "Play a Sound", toggle = true, needs = Enabled, why = TEXT_OFF,
          help = "Plays when the warning comes up, and flashes the game's icon on your taskbar." },
        { key = "rareSoundKey", label = "Sound", choice = Sounds.Choices, needs = SoundOn, why = TEXT_SOUND_OFF,
          help = "The game's own alert sounds first, then the addon's. Each plays as you pick it.",
          get = GetSound, set = SetSound },
        { key = "rareAlertTime", label = "Stays For", slider = ALERT_TIME, unit = "s", needs = Enabled, why = TEXT_OFF,
          help = "Seconds before it fades." },
        { key = "rareAlertScale", label = "Size", slider = ALERT_SCALE, unit = "%", scale = PERCENT_SCALE,
          needs = Enabled, why = TEXT_OFF, help = "How big the card is." },
        { label = "Reset Position", buttonText = "Reset", needs = Enabled, why = TEXT_OFF,
          button = RareAlert.ResetPosition,
          help = "Puts the card back above the middle of the screen, where it starts." },
        { label = "Test Alert", buttonText = "Test", button = RareAlert.Test, needs = Enabled, why = TEXT_OFF,
          help = "Shows the warning with its sound, about your target if you can attack it." },
        Settings.Look("rareAlert", { text = true, size = FONT_SIZE, background = "card", needs = Enabled,
            why = TEXT_OFF }),
        { key = "rareAlertGlow", label = "Glow", toggle = true, needs = Enabled, why = TEXT_OFF,
          help = "A soft glow round it in your accent color." },
    },
})

table.insert(ns.Shared.MapPins, {
    title = "Rares", store = S, switch = "rarePins",
    rows = {
        { key = "rarePins", label = "Rares", toggle = true, store = S, always = true, needs = Enabled, why = TEXT_OFF,
          help = "A star on the world map for every rare you have not killed, where it is most likely to be. "
              .. "Hover one for the rare and its drops, its other spawn spots and, if it patrols, its way; "
              .. "click it for a waypoint, right-click it to keep its spots and way shown." },
        { key = "rarePinsKilled", label = "Show Killed Rares", toggle = true, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF, help = "Also a grey star on the map for the rares you have killed." },
        { key = "rarePinSize", label = "Rare Pin Size", slider = PIN_SIZE, store = S, always = true, needs = PinsOn,
          why = TEXT_PINS_OFF, help = "How big the stars are on the map." },
    },
})
