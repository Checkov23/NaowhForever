-- SettingsPage.lua: Glimmer's tab of the QoL settings, declared as cards, with its live previews.
local ns = _G.NaowhForever

local T = ns.THEME
local G = ns.Glimmer
local S = G.Settings
local C, St = G.C, G.Style
local Effects, CVars = G.Effects, G.CVars

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local OFF = ns.L("Turn on Glimmer")
local TEXT_RESTART = ns.L("Restart the game to take the sparkle off. A reload is not enough.")
local TEXT_INTERACT = ns.L("Enable Interact Key is off in the game's Controls settings, so nothing lights up.")
local TEXT_RESTORE_ASK = ns.L("Put back the game settings Glimmer changed and turn Glimmer off?")
local TEXT_NOTHING = ns.L("Nothing to put back.")
local STAGE_H = 150
local NOTE_Y, NOTE_SIZE = St.STAGE_NOTE_Y, St.STAGE_NOTE_SIZE
local SAMPLE_Y = 8
local SIZE_RANGE, BRIGHT_RANGE = { 60, 160, 5 }, { 30, 150, 5 }
local RANGE_RANGE = { 5, 15, 1 }
local OFFSET_RANGE = { -120, 120, 5 }
local TO_FRACTION = St.PERCENT_SCALE
local ORDER_WINDOW, ORDER_LOOK, ORDER_OBJECTS, ORDER_HIDE = 5, 10, 20, 30
local ORDER_DETECT, ORDER_MINIMAP, ORDER_GATHERED, ORDER_RESTORE = 40, 44, 46, 60
local MINIMAP_SIZE = { 10, 24, 1 }
local PIN_SIZE = St.PIN_SIZE_RANGE
local TEXT_SECTION = ns.L("Glimmer")
local TEXT_PINS_OFF = ns.L("Turn on Gathered Herbs and Ore")
local INTERACT_BINDING = "INTERACTTARGET"

local STYLE_NAMES = {
    glow = "Glow", sparkles = "Sparkles", ring = "Ring", beam = "Beam", brackets = "Brackets",
}
local STYLE_ORDER = { "glow", "sparkles", "ring", "beam", "brackets" }
local STYLES = { STYLE_NAMES, STYLE_ORDER }
local OWN_NAMES = { same = "Same as All" }
for key, name in pairs(STYLE_NAMES) do OWN_NAMES[key] = name end
local OWN_STYLES = { OWN_NAMES, { "same", "glow", "sparkles", "ring", "beam", "brackets" } }
local ARCS = { { [0] = "Straight Ahead", [1] = "In Front", [2] = "All Around" }, { 0, 1, 2 } }

local CATEGORY_NAMES = {
    ore = "Ore", herb = "Herbs", quest = "Quest Objects", giver = "Quest Givers", chest = "Chests",
    bobber = "Fishing Bobber",
}
local CATEGORY_HELP = {
    ore = "Mining veins and deposits.",
    herb = "Plants you can gather.",
    quest = "Objects your quests need.",
    giver = "NPCs with a quest to pick up or hand in. Glimmer shows their nameplate to light them up.",
    chest = "Chests, strongboxes and footlockers out in the world.",
    bobber = "Your fishing bobber.",
}

local SAMPLES = {
    far = { ready = false, line = "Skill-up every gather", tier = "orange" },
    ready = { ready = true, line = "Skill-up every gather", tier = "orange" },
    locked = { ready = true, locked = true, line = "Requires Mining 65", tier = "red" },
}

local function Enabled() return G.On() end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.fx = Effects.New(preview)
    preview.fx:SetPoint("CENTER", preview, "CENTER", 0, SAMPLE_Y)
    preview.line = ns.Font(preview, St.LINE_SIZE)
    preview.line:SetPoint("TOP", preview.fx, "CENTER", 0, -St.BASE)
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y)
    return preview
end

local function PaintPreview(preview, state)
    local sample = SAMPLES[state]
    local color = S.Get("skillColors") and St.TIER_RGB[sample.tier] or S.Get("oreColor")
    local fx = preview.fx
    Effects.Set(fx, S.Get("style"), color, S.Get("brightness"), S.Get("size"), sample.ready, sample.locked)
    if preview.state ~= state then
        preview.state = state
        Effects.Start(fx)
    end
    preview.line:SetText(S.Get("showLine") and ns.L(sample.line) or "")
    local tint = St.TIER_RGB[sample.tier]
    preview.line:SetTextColor(tint.r, tint.g, tint.b)
    preview.note:SetText(G.On() and "" or OFF)
end

local LOOK_STATES = {
    { key = "far", label = "Out of Reach", tip = "Dim while the object is too far to use." },
    { key = "ready", label = "In Reach", tip = "Bright once you can gather, loot or use it." },
    { key = "locked", label = "Too Low", tip = "Grey when your skill is too low for it.", needs = function()
        return not S.Get("hideLocked") end },
}

local function Shown()
    local names = {}
    for _, key in ipairs(G.CATEGORIES) do
        if S.Get(key) then names[#names + 1] = ns.L(CATEGORY_NAMES[key]) end
    end
    return names
end

local function Headline()
    if not G.On() then return ns.L("Glimmer is off") end
    local names = Shown()
    if #names == 0 then return ns.L("Nothing picked to light up") end
    return ns.L("Lights up %s"):format(table.concat(names, ", "))
end

local function Detail()
    local style = ns.L(STYLE_NAMES[S.Get("style")])
    local text = ns.L("%s, within %d yards."):format(style, S.Get("range"))
    if not S.Get("questSparkle") then return text end
    return text .. " " .. ns.L("Quest items keep their sparkle.")
end

local function Note()
    if G.On() and not CVars.InteractOn() then return TEXT_INTERACT end
    if CVars.sparkleShown and not (G.On() and S.Get("questSparkle")) then return TEXT_RESTART end
end

local function Restore()
    if not CVars.Saved() then
        ns.Print(TEXT_NOTHING)
        return
    end
    ns.Confirm(TEXT_RESTORE_ASK, CVars.RestoreAll)
end

local function ObjectRows()
    local rows = {}
    for _, key in ipairs(G.CATEGORIES) do
        rows[#rows + 1] = Group(CATEGORY_NAMES[key])
        rows[#rows + 1] = { key = key, label = "Light Up " .. CATEGORY_NAMES[key], toggle = true,
            needs = Enabled, why = OFF, help = CATEGORY_HELP[key] }
        rows[#rows + 1] = { key = key .. "Style", label = "Effect", choice = OWN_STYLES,
            needs = Enabled, why = OFF }
        rows[#rows + 1] = { key = key .. "Color", label = "Color", colour = true, needs = Enabled, why = OFF }
        if key == "giver" then
            rows[#rows + 1] = { key = "giverHideBar", label = "Hide Health Bar and Level", toggle = true,
                needs = Enabled, why = OFF, help = "Only the name on a quest giver's nameplate." }
            rows[#rows + 1] = { key = "giverOffset", label = "Effect Height", slider = OFFSET_RANGE, unit = " px",
                needs = Enabled, why = OFF, help = "Moves a quest giver's effect up or down." }
        end
    end
    return rows
end

local page = Settings.Page(C.PAGE, S)

page:Window({
    order = ORDER_WINDOW,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "look", name = "Glimmer", order = ORDER_LOOK, switch = "enabled", open = true,
    help = "Herbs, ore, chests and quest objects light up as you walk up to them.",
    studio = { height = STAGE_H, states = LOOK_STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        { key = "style", label = "Effect", choice = STYLES, needs = Enabled, why = OFF },
        { key = "size", label = "Size", slider = SIZE_RANGE, unit = "%", scale = TO_FRACTION,
          needs = Enabled, why = OFF },
        { key = "brightness", label = "Brightness", slider = BRIGHT_RANGE, unit = "%", scale = TO_FRACTION,
          needs = Enabled, why = OFF },
        { key = "skillColors", label = "Skill-Up Colors", toggle = true, needs = Enabled, why = OFF,
          help = "Color herbs and ore by your chance of a skill-up, red when your skill is too low." },
        { key = "showLine", label = "Show Skill and Quest Line", toggle = true, needs = Enabled, why = OFF,
          help = "A line under the name: the skill-up chance, or what the quest still needs." },
        { key = "questSparkle", label = "Quest Item Sparkle", toggle = true, needs = Enabled, why = OFF,
          help = "The game's own sparkle on every quest item, kept on through graphics presets." },
    },
    note = Note,
})

page:Card({
    id = "objects", name = "Objects", order = ORDER_OBJECTS,
    help = "What lights up, each with its own effect and color if you like.",
    rows = ObjectRows(),
})

page:Card({
    id = "hide", name = "When to Hide", order = ORDER_HIDE,
    help = "Glimmer always rests in combat, since the game locks these settings there.",
    rows = {
        { key = "hideInstance", label = "In Dungeons and Raids", toggle = true, needs = Enabled, why = OFF },
        { key = "hideLocked", label = "On Nodes Your Skill Is Too Low For", toggle = true, needs = Enabled,
          why = OFF, help = "Leave them dark instead of grey." },
    },
})

page:Card({
    id = "detect", name = "Detection", order = ORDER_DETECT,
    help = "The one object the game would interact with is the one that lights up.",
    rows = {
        { key = "range", label = "Range", slider = RANGE_RANGE, unit = " yd", needs = Enabled, why = OFF,
          help = "How far away the game may pick an object to light up." },
        { key = "arc", label = "Look For Objects", choice = ARCS, needs = Enabled, why = OFF },
        { key = "onlyHighlighted", label = "Only Name What Glimmer Lights", toggle = true, needs = Enabled,
          why = OFF, help = "No soft target name on NPCs, mailboxes and doors." },
        { label = "Interact Key", binding = INTERACT_BINDING,
          help = "Gathers, loots or uses the lit object once it is in reach." },
    },
})

local function PinsOn() return G.On() and S.Get("gatheredPins") end

page:Card({
    id = "minimap", name = "Minimap Icons", order = ORDER_MINIMAP, switch = "minimapIcons",
    help = "Every spot herbs and ore grow near you, on the minimap, ringed in its skill-up color. With Find Herbs or Find Minerals on, the ring is left open and the game's own dot shows in it while the node is up.",
    rows = {
        { key = "minimapSize", label = "Icon Size", slider = MINIMAP_SIZE, needs = Enabled, why = OFF },
        { key = "myProfessions", label = "Only My Professions", toggle = true, needs = Enabled, why = OFF,
          help = "Only herbs if you are an herbalist, only ore if you are a miner." },
    },
})

local GATHERED_ROWS = {
    { key = "gatheredPins", label = "Gathered Herbs and Ore", toggle = true, store = S, needs = Enabled, why = OFF,
      help = "Every herb and vein you gather, on the world map; click one for a waypoint." },
    { key = "gatheredPinSize", label = "Gathered Pin Size", slider = PIN_SIZE, store = S, always = true,
      needs = PinsOn, why = TEXT_PINS_OFF, help = "How big the pins are on the map." },
}

page:Card({
    id = "gathered", name = "Gathered on the Map", order = ORDER_GATHERED,
    help = "Glimmer notes every herb and vein you gather, so you can find them again.",
    rows = GATHERED_ROWS,
})

table.insert(ns.Shared.MapPins, { title = TEXT_SECTION, store = S, switch = "gatheredPins", rows = GATHERED_ROWS })

page:Card({
    id = "restore", name = "Game Settings", order = ORDER_RESTORE,
    help = "Glimmer saves the game settings it changes and puts them back when it is turned off.",
    rows = {
        { label = "Put My Game Settings Back", button = Restore, buttonText = "Restore",
          help = "Writes the saved settings back and turns Glimmer off." },
    },
})
