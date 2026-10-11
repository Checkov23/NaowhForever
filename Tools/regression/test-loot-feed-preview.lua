-- Run with Lua 5.1 from the repository root: the Loot Feed card's preview edits the feed. Its
-- right edge sets Width and a line's bottom edge Line Height, live while dragging and saved on
-- release (snapped and clamped to the sliders, cursor moves converted by the fit scale, nothing
-- saved by a click, a hide or a repaint); the wheel sets Font Size (Shift: Spacing, Ctrl: Lines
-- Shown); clicking the value or bag count flips Show Item Value or Count Bank Items; the line menu
-- holds what lines show, Glow, Style, Outline and Growth Direction; nothing edits while QoL or the
-- feed is off; and dragging and hovering make no garbage. Then the look: today's outlined Addon Font
-- by default, Font, Font Size and Outline on every text, Style None without the fill and edge, and
-- the card's standard groups. The preview is plain frames, never the live
-- feed. Frames here are stubs: this does not emulate the game's renderer, menus or taint rules.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)

local methods = {}
local frameMeta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:find("^[A-Z]") then return methods.Nothing end
end }
local frames = {}
local function New(kind, parent, name)
    local f = setmetatable({ kind = kind, parent = parent, name = name, scripts = {}, events = {},
        shown = true, w = 0, h = 0, scale = 1, level = parent and parent.level + 1 or 0 }, frameMeta)
    frames[#frames + 1] = f
    return f
end
function methods.Nothing() end
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:UnregisterEvent(e) self.events[e] = nil end
function methods:UnregisterAllEvents() for e in pairs(self.events) do self.events[e] = nil end end
function methods:Show() self.shown = true end
function methods:Hide()
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetSize(w, h) self.w, self.h = w, h end
function methods:SetWidth(w) self.w = w end
function methods:SetHeight(h) self.h = h end
function methods:GetWidth() return self.w end
function methods:GetHeight() return self.h end
function methods:SetScale(s) self.scale = s end
function methods:GetEffectiveScale() return self.scale end
function methods:ClearAllPoints() self.point, self.rel, self.x, self.y = nil, nil, nil, nil end
function methods:SetPoint(point, rel, _, x, y) self.point, self.rel, self.x, self.y = point, rel, x, y end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(v) self.level = v end
function methods:IsMouseOver() return self.over == true end
function methods:EnableMouse(on) self.mouse = on end
function methods:EnableMouseWheel(on) self.wheel = on end
function methods:SetAlpha(a) self.alpha = a end
function methods:SetText(t) self.text = t end
function methods:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
function methods:GetStringWidth() return self.text and #tostring(self.text) * 6 or 0 end
function methods:CreateTexture() return New("Texture", self) end
function methods:CreateFontString() return New("FontString", self) end

local settings = {}
local defaults = { enabled = true, lootFeed = true, lootFeedMoney = true, lootFeedXP = false, lootFeedQuality = 1,
    lootFeedQuest = true, lootFeedRep = false, lootFeedCount = 6, lootFeedFade = 5, lootFeedStyle = "dark",
    lootFeedGlow = false, lootFeedValue = true, lootFeedBank = true, lootFeedPrice = "vendor", lootFeedGPH = false,
    hideLootWindow = false, fastLoot = false, lootFeedWidth = 340, lootFeedHeight = 36, lootFeedSpacing = -1,
    lootFeedGrowth = "up", lootFeedFont = "", lootFeedFontSize = 13, lootFeedOutline = "OUTLINE" }
local sets = 0
local S = {}
function S.Get(k) local v = settings[k]; if v == nil then return defaults[k] end return v end
function S.Set(k, v) settings[k] = v; sets = sets + 1 end

local THEME = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
    accent = { r = 0, g = 0.57, b = 0.93 }, bg = { r = 0, g = 0, b = 0 } }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    QoLSettings = S, THEME = THEME,
    Apply = function() end, ShowUnlockMode = function() end, HideUnlockMode = function() end,
    Border = function(parent)
        local border = New("Border", parent)
        border._frame = New("Frame", parent)
        return border
    end,
    Font = function(parent) return New("FontString", parent) end,
    Solid = function(parent, _, color) local t = New("Texture", parent); t.color = color; return t end,
    ThemeTint = function(_, literal) return literal end,
    OnePixel = function() return 1 end,
    UI = { FontPath = function() return "font" end, AttachMover = function(f) return New("Mover", f) end },
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = {
        HUD_OUTLINES = { { [""] = "Shadow", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
            { "", "OUTLINE", "THICKOUTLINE" } },
        HUD_BACKGROUNDS = { { card = "Card", soft = "Soft", none = "None" }, { "card", "soft", "none" } },
        HudFont = function(fs, font, size, outline, background)
            fs:SetFont(font, size, outline)
            fs.shadow = outline == "" and (background or "card") or false
            return fs
        end,
    } },
}

local tip = { left = {}, right = {}, accent = {}, n = 0 }
function tip:SetOwner(owner) self.owner, self.n = owner, 0 end
function tip:GetOwner() return self.owner end
function tip:AddLine() end
function tip:AddDoubleLine(left, right, r)
    local n = self.n + 1
    self.n, self.left[n], self.right[n], self.accent[n] = n, left, right, r == THEME.accent.r
end
function tip:Show() self.shown = true end
function tip:Hide() self.shown = false end

local menu
local cx, cy, shift, ctrl = 0, 0, false, false
local function hooksecurefunc(t, k, fn)
    local old = t[k]
    t[k] = function(...) old(...); fn(...) end
end
local env = setmetatable({
    NaowhForever = ns, UIParent = New("Frame"), GameTooltip = tip,
    CreateFrame = function(kind, name, parent) return New(kind, parent, name) end,
    CreateColor = function() return {} end,
    hooksecurefunc = hooksecurefunc,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    BreakUpLargeNumbers = function(n) return tostring(n) end,
    GetCursorPosition = function() return cx, cy end,
    IsShiftKeyDown = function() return shift end,
    IsControlKeyDown = function() return ctrl end,
    MenuUtil = { CreateContextMenu = function(owner, gen) menu = { owner = owner, gen = gen } end },
    LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.", LOOT_ITEM_SELF = "You receive loot: %s.",
    LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d.", LOOT_ITEM_PUSHED_SELF = "You receive item: %s.",
    GOLD_AMOUNT = "%d Gold", SILVER_AMOUNT = "%d Silver", COPPER_AMOUNT = "%d Copper",
    FACTION_STANDING_INCREASED = "Reputation with %s increased by %d.",
    COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience.",
}, { __index = _G })
env._G = env
local settingsFile = assert(loadfile("Shared/Settings/Settings.lua"))
setfenv(settingsFile, env)
settingsFile()
local chunk = assert(loadfile("NaowhForever_QoL/Loot/LootFeed.lua"))
setfenv(chunk, env)
chunk()
local cards = ns.Shared.Settings.pages["QoL/Loot & Items"].cards

local loaded = #frames
for i = 1, loaded do
    local f = frames[i]
    if f.events.PLAYER_LOGIN then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
end
local live
for _, f in ipairs(frames) do if f.name == "NaowhForeverLootFeed" then live = f end end
check("the live feed is built on login", live and live.w == 340 and live.h == 36)

local card = cards.lootFeed
local function Row(key)
    for _, row in ipairs(card.rows) do if row.key == key then return row end end
end
local studio = card.studio
local stage = New("Frame")
local before = #frames
local preview = studio.new(stage)
local made = #frames - before
preview.area.w, preview.area.h = 600, 160
studio.paint(preview, "looting")
local box, samples = preview.feed, preview.rows
local pants, cloth, coins = samples[1], samples[2], samples[3]

local registered, updating = false, false
for i = before + 1, before + made do
    if next(frames[i].events) then registered = true end
    if frames[i].scripts.OnUpdate then updating = true end
end
check("the preview listens to no events", not registered)
check("the preview runs no OnUpdate at rest", not updating)
check("the preview is editable while on", preview.edit.shown and box.mouse and box.wheel
    and preview.hint.text:find("Drag the right edge", 1, true) == 1)
check("the preview is drawn at the saved size", box.w == 340 and pants.w == 340 and pants.h == 36)

-- The wheel.
local wheel = box.scripts.OnMouseWheel
wheel(box, 1)
check("the wheel raises Font Size a step", settings.lootFeedFontSize == 14)
shift = true; wheel(box, 1); shift = false
check("Shift + wheel sets Spacing", settings.lootFeedSpacing == 0 and settings.lootFeedFontSize == 14)
ctrl = true; wheel(box, -1); ctrl = false
check("Ctrl + wheel sets Lines Shown", settings.lootFeedCount == 5)
local size = Row("lootFeedFontSize").slider
settings.lootFeedFontSize = size[2]; wheel(box, 1)
check("the wheel stays inside the Font Size slider", settings.lootFeedFontSize == size[2])
settings.lootFeedFontSize = 13.4; wheel(box, -1)
check("the wheel snaps to the slider step", settings.lootFeedFontSize == 12)
local spacing = Row("lootFeedSpacing").slider
check("Spacing goes down to -1", spacing[1] == -1)
settings.lootFeedSpacing = spacing[1]; shift = true; wheel(box, -1); shift = false
check("Shift + wheel stays inside the Spacing slider", settings.lootFeedSpacing == -1)
local count = Row("lootFeedCount").slider
settings.lootFeedCount = count[1]; ctrl = true; wheel(box, -1); ctrl = false
check("Ctrl + wheel stays inside the Lines Shown slider", settings.lootFeedCount == count[1])
local wheelSets = sets
pants.valueHit.scripts.OnMouseWheel(pants.valueHit, 1)
check("the wheel works over the value too", sets == wheelSets + 1 and settings.lootFeedFontSize == 13)
settings.lootFeedFontSize, settings.lootFeedCount, settings.lootFeedSpacing = nil, nil, nil
studio.paint(preview, "looting")

-- Clicks.
local value = pants.valueHit
value.scripts.OnMouseUp(value, "LeftButton")
check("a click that slid off the value changes nothing", settings.lootFeedValue == nil)
value.over = true
value.scripts.OnMouseUp(value, "LeftButton")
check("clicking the value turns Show Item Value off", settings.lootFeedValue == false)
studio.paint(preview, "looting")
check("the item lines lose their value", not pants.coins[3].amount.shown and not cloth.coins[3].amount.shown)
check("the coin line keeps its money", coins.coins[3].amount.shown)
check("the value stays clickable to turn it back on", value.w > 0)
value.scripts.OnMouseUp(value, "LeftButton")
check("clicking it again turns it back on", settings.lootFeedValue == true)
value.over = false
local bags = cloth.bagsHit
bags.over = true
bags.scripts.OnMouseUp(bags, "LeftButton")
check("clicking the bag count turns Count Bank Items off", settings.lootFeedBank == false)
studio.paint(preview, "looting")
check("the count drops to the bags alone", cloth.bags.text == 7)
bags.scripts.OnMouseUp(bags, "LeftButton")
studio.paint(preview, "looting")
check("the count takes in the bank again", settings.lootFeedBank == true and cloth.bags.text == 27)
bags.over = false

-- The line menu.
box.scripts.OnMouseUp(box, "LeftButton")
check("a left click on a line opens no menu", menu == nil)
box.scripts.OnMouseUp(box, "RightButton")
check("a right click opens the line menu", menu and menu.owner == box)
local items = {}
local root = {}
function root:CreateTitle(label) items[#items + 1] = { kind = "title", label = label } end
function root:CreateDivider() end
function root:CreateCheckbox(label, isOn, set, data) items[#items + 1] = { kind = "box", label = label, isOn = isOn, set = set, data = data } end
function root:CreateRadio(label, isOn, set, data) items[#items + 1] = { kind = "radio", label = label, isOn = isOn, set = set, data = data } end
menu.gen(nil, root)
local function Item(label) for _, item in ipairs(items) do if item.label == label then return item end end end
local labels = {}
for _, item in ipairs(items) do if item.kind ~= "title" then labels[#labels + 1] = item.label end end
check("the menu lists what lines show, Glow, Style, Outline and Growth Direction", table.concat(labels, ",")
    == "Show Money,Show Quest Rewards,Show Reputation,Show Kill Experience,Glow,Dark,Light,None,"
    .. "Shadow,Outline,Thick Outline,Up,Down")
check("the menu passes each setting's key, so it makes no closures",
    Item("Show Reputation").data == "lootFeedRep" and Item("Glow").data == "lootFeedGlow"
    and Item("Show Money").set == Item("Glow").set and Item("Dark").set == Item("Down").set)
check("the menu reads the settings", Item("Show Money").isOn(Item("Show Money").data) and not Item("Glow").isOn("lootFeedGlow")
    and Item("Dark").isOn(Item("Dark").data) and not Item("Light").isOn(Item("Light").data))
Item("Show Reputation").set(Item("Show Reputation").data)
check("a menu checkbox flips its setting", settings.lootFeedRep == true)
Item("Light").set(Item("Light").data)
Item("Down").set(Item("Down").data)
check("the menu picks Style and Growth Direction", settings.lootFeedStyle == "light" and settings.lootFeedGrowth == "down")
Item("Shadow").set(Item("Shadow").data)
check("the menu picks the Outline", settings.lootFeedOutline == "" and Item("Shadow").isOn(Item("Shadow").data))
settings.lootFeedOutline = nil
local gen = menu.gen
pants.valueHit.scripts.OnMouseUp(pants.valueHit, "RightButton")
check("every part opens the same menu", menu.owner == pants.valueHit and menu.gen == gen)
settings.lootFeedRep, settings.lootFeedStyle, settings.lootFeedGrowth = nil, nil, nil
studio.paint(preview, "looting")

-- Hover.
box.over = true
box.scripts.OnEnter(box)
check("hovering shows the right edge grip", preview.widthHit.line.shown)
check("hovering lists the edits", tip.shown and tip.owner == box and tip.n == 8)
check("the wheel's edits are the ones lit on a line", tip.accent[3] and tip.accent[4] and tip.accent[5]
    and tip.accent[8] and not tip.accent[1] and not tip.accent[6])
check("the tooltip shows the current values", tip.right[5] == "Lines Shown (6)" and tip.right[1] == "Width (340)")
box.scripts.OnLeave(box); value.scripts.OnEnter(value)
check("the value lights its own line", tip.accent[6] and not tip.accent[3] and value.wash.shown)
value.scripts.OnLeave(value); box.scripts.OnEnter(box)
check("leaving the value clears its wash", not value.wash.shown)
box.over = false
box.scripts.OnLeave(box)
check("leaving hides the grip and the tooltip", not preview.widthHit.line.shown and not tip.shown)

-- Dragging the right edge.
local grip = preview.widthHit
cx, cy = 500, 500
grip.scripts.OnMouseDown(grip, "LeftButton")
check("the edge drag runs only while dragging", grip.scripts.OnUpdate ~= nil)
check("dragging hides the tooltip", not tip.shown)
cx = 560; grip.scripts.OnUpdate(grip)
check("the preview follows the drag", box.w == 400 and pants.w == 400 and cloth.w == 400)
check("nothing is saved mid-drag", settings.lootFeedWidth == nil)
check("the live feed is not touched mid-drag", live.w == 340)
cx = 5000; grip.scripts.OnUpdate(grip)
check("the drag stays inside the Width slider", box.w == Row("lootFeedWidth").slider[2])
cx = 562.4; grip.scripts.OnUpdate(grip)
grip.scripts.OnMouseUp(grip, "LeftButton")
check("release saves the snapped width", settings.lootFeedWidth == 400)
check("release stops the drag update", grip.scripts.OnUpdate == nil and preview.drag == nil)
check("the live feed takes the new width", live.w == 400)
studio.paint(preview, "looting")

-- Dragging a line's bottom edge.
local top = pants.edgeHit
check("growing up, the newest line is at the bottom", coins.edgeHit.above == 2 and top.above == 0)
cx, cy = 500, 500
top.scripts.OnMouseDown(top, "LeftButton")
cy = 490; top.scripts.OnUpdate(top)
check("the top line's edge follows the cursor", pants.h == 46 and box.h == 3 * 46 - 2)
top.scripts.OnMouseUp(top, "LeftButton")
check("release saves the line height", settings.lootFeedHeight == 46 and live.h == 46)
studio.paint(preview, "looting")
local low = coins.edgeHit
low.scripts.OnMouseDown(low, "LeftButton")
cy = 460; low.scripts.OnUpdate(low)
check("a lower line's edge moves by its share", coins.h == 56)
cy = -5000; low.scripts.OnUpdate(low)
check("the drag stays inside the Line Height slider", coins.h == Row("lootFeedHeight").slider[2])
low.scripts.OnMouseUp(low, "LeftButton")
settings.lootFeedHeight, settings.lootFeedGrowth = nil, "down"
studio.paint(preview, "looting")
check("growing down, the newest line is on top", coins.edgeHit.above == 0 and pants.edgeHit.above == 2)
settings.lootFeedGrowth, settings.lootFeedMoney = nil, false
studio.paint(preview, "looting")
check("without money the coin line and its edge are gone", not coins.shown and not coins.edgeHit.shown
    and pants.edgeHit.above == 0 and box.h == 2 * 36 - 1)
settings.lootFeedMoney = nil
studio.paint(preview, "looting")
check("with money they come back", coins.shown and coins.edgeHit.shown)

-- The fit scale.
preview.area.w = 200
studio.paint(preview, "looting")
check("a feed wider than the stage is scaled to fit", box.scale == 0.5)
check("the edges keep their size on screen", grip.w == 12)
cx, cy = 100, 100
grip.scripts.OnMouseDown(grip, "LeftButton")
cx = 130; grip.scripts.OnUpdate(grip)
grip.scripts.OnMouseUp(grip, "LeftButton")
check("cursor moves are converted by the fit scale", settings.lootFeedWidth == 460)
preview.area.w = 600
studio.paint(preview, "looting")
local quiet = sets
grip.scripts.OnMouseDown(grip, "LeftButton")
grip.scripts.OnMouseUp(grip, "LeftButton")
check("a click on the edge saves nothing", sets == quiet)
grip.scripts.OnMouseDown(grip, "LeftButton")
cx = 190; grip.scripts.OnUpdate(grip)
preview:Hide()
check("hiding the preview ends the drag unsaved", grip.scripts.OnUpdate == nil and sets == quiet)
check("and puts the preview back at the saved size", box.w == 460)
preview:Show()
grip.scripts.OnMouseDown(grip, "LeftButton")
cx = 300; grip.scripts.OnUpdate(grip)
studio.paint(preview, "fading")
check("a repaint mid-drag ends it unsaved", grip.scripts.OnUpdate == nil and sets == quiet and box.w == 460)
check("the fading moment says when lines go", preview.note.text == "Each line fades out after 5s.")
studio.paint(preview, "looting")

-- Nothing makes garbage.
cx, cy = 100, 100
grip.scripts.OnMouseDown(grip, "LeftButton")
local step = 0
Measure("a drag update", 0.5, function()
    step = step + 1
    cx = 100 + step % 40
    grip.scripts.OnUpdate(grip)
end)
grip.scripts.OnMouseUp(grip, "LeftButton")
studio.paint(preview, "looting")
box.over = true
Measure("hovering a line", 0.5, function()
    box.scripts.OnEnter(box)
    box.scripts.OnLeave(box)
end)
box.over = false
box.scripts.OnLeave(box)

-- Off.
settings.lootFeed = false
studio.paint(preview, "looting")
check("nothing edits while the feed is off", not preview.edit.shown and not box.mouse and not box.wheel)
check("the note says how to turn it on", preview.hint.text == "Turn on the Loot Feed to edit it here.")
local offSets = sets
wheel(box, 1)
box.scripts.OnMouseUp(box, "RightButton")
grip.scripts.OnMouseDown(grip, "LeftButton")
check("the wheel, menu and edges do nothing while off", sets == offSets and menu.owner ~= box
    and grip.scripts.OnUpdate == nil)
settings.lootFeed, settings.enabled = true, false
studio.paint(preview, "looting")
check("with QoL off the note names QoL", preview.hint.text == "Turn on QoL to edit the Loot Feed here.")
settings.enabled = nil
studio.paint(preview, "looting")
check("turned back on it edits again", preview.edit.shown and box.mouse)

-- The look.
local function Texts(row)
    local list = { row.name, row.value, row.bags }
    for _, pair in ipairs(row.coins) do list[#list + 1] = pair.amount end
    return list
end
local function AllTexts(test)
    for _, row in ipairs({ pants, cloth, coins }) do
        for _, fs in ipairs(Texts(row)) do
            if not test(fs) then return false end
        end
    end
    return true
end
studio.paint(preview, "looting")
check("today's look: the Addon Font, outlined, no shadow", AllTexts(function(fs)
    return fs.font == "" and fs.flags == "OUTLINE" and fs.shadow == false end))
check("today's look: 13 for the name, 12 for values, 11 for the bag count", pants.name.size == 13
    and pants.value.size == 12 and coins.coins[1].amount.size == 12 and pants.bags.size == 11)
check("today's look: the dark fill and its edge", pants.bg.shown and pants.border._frame.shown)
S.Set("lootFeedFont", "Expressway")
S.Set("lootFeedFontSize", 16)
studio.paint(preview, "looting")
check("Font and Font Size reach every text", AllTexts(function(fs) return fs.font == "Expressway" end)
    and pants.name.size == 16 and pants.value.size == 15 and pants.bags.size == 14)
S.Set("lootFeedOutline", "")
studio.paint(preview, "looting")
check("Shadow: no outline, the card's shadow", AllTexts(function(fs) return fs.flags == "" and fs.shadow == "card" end))
S.Set("lootFeedStyle", "none")
studio.paint(preview, "looting")
check("Style None: no fill and no edge", not pants.bg.shown and not pants.border._frame.shown
    and not coins.bg.shown)
check("Style None: the stronger shadow", AllTexts(function(fs) return fs.shadow == "none" end))
S.Set("lootFeedGPH", true)
studio.paint(preview, "looting")
check("gold per hour follows Font and Outline", preview.gph.font == "Expressway" and preview.gph.flags == ""
    and preview.gph.shadow == "none")
S.Set("lootFeedStyle", "dark")
studio.paint(preview, "looting")
check("Dark again: the fill and edge are back", pants.bg.shown and pants.border._frame.shown)
check("the summary names the style", card.summary(S):find("dark", 1, true) ~= nil)
settings.lootFeedStyle = "none"
check("the summary names no background", card.summary(S):find("no background", 1, true) ~= nil)
settings.lootFeedFont, settings.lootFeedFontSize, settings.lootFeedOutline = nil, nil, nil
settings.lootFeedStyle, settings.lootFeedGPH = nil, nil
studio.paint(preview, "looting")
local group, groups, groupOf = nil, {}, {}
for _, row in ipairs(card.rows) do
    if row.group then
        group = row.group
        groups[#groups + 1] = group
    elseif row.key then
        groupOf[row.key] = group
    end
end
check("the standard groups after its own", table.concat(groups, ", ")
    == "Lines, Value, Loot Window, Size, Text, Background")
check("Font, Font Size and Outline under Text", groupOf.lootFeedFont == "Text" and groupOf.lootFeedFontSize == "Text"
    and groupOf.lootFeedOutline == "Text" and Row("lootFeedOutline").choice == ns.Shared.Parts.HUD_OUTLINES)
check("Style and Glow under Background", groupOf.lootFeedStyle == "Background" and groupOf.lootFeedGlow == "Background")
check("Width under Size", groupOf.lootFeedWidth == "Size" and groupOf.lootFeedSpacing == "Size")

print(("test-loot-feed-preview: %d checks passed"):format(checks))
