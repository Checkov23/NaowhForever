-- Run with Lua 5.1 from the repository root: New Herbs and Ores (UI/NodeToast.lua) and the shared toast
-- (Shared/UI/Toast.lua) under it. A Mining skill-up that reaches new veins names them, with one icon per ore, and
-- the toast goes by itself after 20 seconds unless dragged; logging in, learning a profession, the same skill
-- again or a bonus coming and going shows nothing. It is drawn like the game's level-up banner in the accent: no
-- window frame, a fill and two lines fading to both sides, the line small over a large title. A toast waits while
-- the game's own banner or another toast shows, then takes its place, and one turned off while it waits is
-- skipped for the next. On a client whose node names are not English it stays off.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end
local timers = {}
local frames = {}
local boot, skillEvents
local locale = "enUS"

local regionMethods = {
    SetText = function(r, text) r.text = text end,
    GetStringHeight = function() return 14 end,
    SetTexture = function(r, texture) r.texture = texture end,
    SetShown = function(r, on) r.shown = on and true or false end,
    Show = function(r) r.shown = true end,
    Hide = function(r)
        local was = r.shown
        r.shown = false
        if was then for _, fn in ipairs(r.onHide or {}) do fn(r) end end
    end,
    IsShown = function(r) return r.shown == true end,
    HookScript = function(r, name, fn)
        if name == "OnHide" then r.onHide = r.onHide or {}; r.onHide[#r.onHide + 1] = fn end
    end,
    SetHeight = function(r, h) r.height = h end,
    SetWidth = function(r, w) r.width = w end,
    SetPoint = function(r, point, rel, relPoint, x, y)
        r.point = { point, rel, relPoint, x, y }
        r.points = r.points or {}
        r.points[#r.points + 1] = r.point
    end,
    ClearAllPoints = function(r) r.points = {} end,
    SetGradient = function(r, dir, from, to) r.gradient = { dir = dir, from = from, to = to } end,
    SetScript = function(r, name, fn) r[name] = fn end,
    RegisterEvent = function(r, event)
        r.events = r.events or {}
        r.events[event] = true
        if event == "PLAYER_LOGIN" then boot = boot or {}; boot[#boot + 1] = r end
        if event == "SKILL_LINES_CHANGED" then skillEvents = r end
    end,
    UnregisterAllEvents = function(r) r.events = {} end,
}
local regionMeta = { __index = function(_, k)
    if regionMethods[k] then return regionMethods[k] end
    if k:find("^%u") then return Noop end
end }
local function Region() return setmetatable({}, regionMeta) end
regionMethods.CreateTexture = function() return Region() end

local function CreateFrame(_, name)
    local f = Region()
    if name then frames[name] = f end
    return f
end

local function Store(values)
    local S = { values = values }
    function S.Get(k) return S.values[k] end
    function S.Set(k, v) S.values[k] = v end
    function S.OnChange(fn) S.changed = fn end
    return S
end

local skills = { ore = 50, herb = 0 }
local S = Store({ enabled = true, nodeToast = true })
local setHook
local buttons = {}
local framed = 0
local ACCENT, BG = { r = 0, g = 0.57, b = 0.93 }, { r = 0.05, g = 0.05, b = 0.08 }
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    THEME = { bg = BG, accent = ACCENT },
    MEDIA = "Interface\\AddOns\\NaowhForever\\Core\\Media\\",
    Apply = Noop,
    UI = { CenterPosition = function() return { point = "CENTER", relPoint = "CENTER", x = 1, y = 2 } end },
    Solid = function() framed = framed + 1 return Region() end,
    Border = function() framed = framed + 1 end,
    Font = function(_, size, _, color, heading)
        local r = Region()
        r.size, r.color, r.heading = size, color, heading
        return r
    end,
    Button = function(_, text, _, _, click)
        local b = Region()
        b.label, b.click = text, click
        buttons[#buttons + 1] = b
        return b
    end,
    AccentBorder = function(b) return b end,
    Shared = { Parts = {}, Style = { BACKDROP_ALPHA = 0.97, ICON_CROP = 0.08, ICON_CROP_HIGH = 0.92 } },
    Professions = { Settings = S },
}

local env = setmetatable({
    NaowhForever = ns,
    UIParent = Region(),
    CreateFrame = CreateFrame,
    CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    GetLocale = function() return locale end,
    C_TooltipInfo = {},
    C_Timer = { After = function(seconds, fn) timers[#timers + 1] = { seconds = seconds, fn = fn } end },
    C_Item = { GetItemIconByID = function(id) return "item:" .. id end },
    C_Spell = { GetSpellTexture = function(id) return "spell:" .. id end },
    GetProfessions = function() return skills.ore > 0 and 1 or nil, skills.herb > 0 and 2 or nil end,
    GetProfessionInfo = function(index)
        if index == 1 then return "Mining", nil, skills.ore, 300, nil, nil, 186, skills.oreBonus or 0 end
        return "Herbalism", nil, skills.herb, 300, nil, nil, 182, 0
    end,
    hooksecurefunc = function(target, name, fn)
        if target == S and name == "Set" then setHook = fn end
    end,
}, { __index = _G })
env._G = env

Load({
    "Shared/UI/Toast.lua",
    "NaowhForever_Professions/Constants.lua",
    "NaowhForever_Professions/Data/GatherNodes.lua",
    "NaowhForever_Professions/NodeScan.lua",
    "NaowhForever_Professions/UI/NodeToast.lua",
}, env)

for _, f in ipairs(boot) do f.OnEvent(f, "PLAYER_LOGIN") end
check("logging in shows no toast", frames.NaowhForeverNodeToast == nil)
check("it listens for skill changes", skillEvents and skillEvents.events.SKILL_LINES_CHANGED)

local function SkillUp()
    skillEvents.OnEvent(skillEvents, "SKILL_LINES_CHANGED")
    return frames.NaowhForeverNodeToast
end

skills.ore = 75
local toast = SkillUp()
check("Mining 50 to 75 shows the toast", toast and toast.shown)
check("titled with the new skill", toast.title.text == "Mining 75")
check("naming the veins it reached, lowest first", toast.line.text
    == "You can now mine Incendicite Mineral Vein, Tin Vein, Lesser Bloodstone Deposit, Ooze Covered Silver Vein and Silver Vein.")
local shownIcons = {}
for _, icon in ipairs(toast.icons) do if icon.shown then shownIcons[#shownIcons + 1] = icon.texture end end
check("one icon per ore, not per vein", #shownIcons == 4)
check("Tin Ore's among them", (function()
    for _, t in ipairs(shownIcons) do if t == "item:2771" then return true end end
end)())
check("with a Dismiss button", buttons[1].label == "Dismiss")

local function Faded(halves, color, alpha)
    local left, right = halves[1].gradient, halves[2].gradient
    return left.dir == "HORIZONTAL" and right.dir == "HORIZONTAL" and left.from.a == 0 and left.to.a == alpha
        and right.from.a == alpha and right.to.a == 0 and left.to.r == color.r and left.to.b == color.b
end

local function Halved(halves)
    local left, right = halves[1].points, halves[2].points
    return #left == 2 and left[2][3] == "TOP" and #right == 2 and right[1][3] == "TOP"
end

check("no window frame: no backdrop, no border", framed == 0)
check("a fill fading from the background to both sides", Faded(toast.fill, BG, 0.6) and Halved(toast.fill))
check("an accent line above and below, fading at the ends", Faded(toast.top, ACCENT, 1)
    and Faded(toast.bottom, ACCENT, 1) and Halved(toast.top) and Halved(toast.bottom))
check("the fill reaches the bottom line", toast.fill[1].points[2][5] == toast.bottom[1].points[2][5])
check("the title large in the accent, under the small line", toast.title.color == ACCENT and toast.title.heading
    and toast.title.size > toast.line.size and toast.title.point[2] == toast.line and toast.title.point[3] == "BOTTOM")
check("its icons centred under the band", shownIcons[1] and toast.icons[1].point[3] == "TOP"
    and toast.icons[1].point[4] == -(4 * 26 + 3 * 6) / 2 and toast.icons[1].point[5] < toast.bottom[1].points[2][5])
check("its button centred under the icons", toast.buttons[1].point[3] == "TOP" and toast.buttons[1].point[4] == -45
    and toast.buttons[1].point[5] < toast.icons[1].point[5])
check("it sits where the game's level-up banner shows until moved", toast.point[1] == "TOP" and toast.point[5] == -140)
check("it goes by itself after 20 seconds", timers[#timers].seconds == 20)
timers[#timers].fn()
check("and is gone then", toast.shown == false)

toast.shown = false
SkillUp()
check("the same skill again shows nothing", toast.shown == false)
skills.ore = 76
SkillUp()
check("a skill-up that reaches no new vein shows nothing", toast.shown == false)

skills.oreBonus = 50
SkillUp()
check("a Mining bonus reaching Iron Deposit counts", toast.shown and toast.line.text:find("Iron Deposit", 1, true))
toast.shown = false
skills.oreBonus = 0
SkillUp()
skills.oreBonus = 50
SkillUp()
check("but taking it off and on again shows it only once", toast.shown == false)

skills.herb = 1
SkillUp()
check("learning Herbalism shows nothing", toast.shown == false)
skills.herb = 50
SkillUp()
check("Herbalism 1 to 50 names its herbs", toast.shown and toast.title.text == "Herbalism 50"
    and toast.line.text == "You can now gather Earthroot and Mageroyal.")

toast.dragging = true
timers[#timers].fn()
check("a toast being dragged stays until it is let go", toast.shown == true)
toast.OnDragStop(toast)
check("then it goes", toast.shown == false)
check("and its place is kept", S.values.nodeToastPos and S.values.nodeToastPos.x == 1)

skills.herb = 0
SkillUp()
skills.herb = 1
SkillUp()
check("unlearning Herbalism and learning it again shows nothing", toast.shown ~= true)
skills.herb = 15
SkillUp()
check("but climbing back to 15 names Earthroot again", toast.shown == true and toast.title.text == "Herbalism 15"
    and toast.line.text == "You can now gather Earthroot.")
toast:Hide()

local out = {}
ns.Professions.NodeScan.Unlocked("ore", 0, 1, out)
check("Mining 1 unlocks the copper and amber veins", #out == 4 and out[1] == "Chunk of Amber")

S.values.nodeToast = false
setHook("nodeToast")
check("turning it off stops listening", next(skillEvents.events) == nil)

local function RunNext()
    for i = #timers, 1, -1 do
        if timers[i].seconds == 0 then table.remove(timers, i).fn() end
    end
end

S.values.nodeToast = true
setHook("nodeToast")
local banner = Region()
banner.shown = true
env.EventToastManagerFrame = banner
skills.herb = 75
SkillUp()
check("while the game's level-up banner shows, a new herb waits", toast.shown ~= true)
banner:Hide()
RunNext()
check("and takes its place once the banner closes", toast.shown == true and toast.title.text == "Herbalism 75")
check("its 20 seconds start then", timers[#timers].seconds == 20)
toast:Hide()
RunNext()

local other = ns.Shared.Parts.Toast({ name = "OtherToast", width = 300, icons = 0, store = Store({}), posKey = "pos",
    buttons = {} })
ns.Shared.Parts.FillToast(other, "Other", "Another toast.", {})
banner:Show()
skills.herb = 100
SkillUp()
ns.Shared.Parts.ShowToast(other, 20)
check("two toasts wait for the banner", toast.shown ~= true and other.shown ~= true)
S.values.nodeToast = false
banner:Hide()
RunNext()
check("the first, turned off while it waits, is skipped", toast.shown ~= true)
check("and the next one shows", other.shown == true)
other:Hide()
RunNext()

locale = "deDE"
S.values.nodeToast = true
setHook("nodeToast")
check("a client whose node names are not English does not listen", next(skillEvents.events) == nil)

print(("test-node-toast: %d checks passed"):format(checks))
