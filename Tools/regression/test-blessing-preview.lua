-- Run with Lua 5.1 from the repository root: the Blessing Bar card's preview edits the bar. The
-- x hides the aura or Righteous Fury button and the + brings it back, the wheel sets Button Size
-- (Shift: Button Spacing) within the sliders' ranges, dragging the gap sets the Aura / Class Gap,
-- a paladin's right-click on a class and click on the aura open the bar's own menus and write
-- the plan, nothing is editable while Blessings is off, and hovering or the wheel makes no garbage.
-- The preview is plain frames, never the bar's secure buttons. Frames here are stubs: this does
-- not emulate the game's renderer, menus or taint rules.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)

local methods = {}
local frameMeta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:find("^[A-Z]") then return methods.Nothing end
end }
local function New(kind, parent)
    return setmetatable({ kind = kind, parent = parent, scripts = {}, shown = true, w = 0, h = 0,
        level = parent and parent.level + 1 or 0 }, frameMeta)
end
function methods.Nothing() end
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:HookScript(k, v)
    local prior = self.scripts[k]
    self.scripts[k] = prior and function(...) prior(...); v(...) end or v
end
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
function methods:SetAllPoints() self.all = true end
function methods:GetWidth() if self.all then return self.parent:GetWidth() end return self.w end
function methods:GetHeight() if self.all then return self.parent:GetHeight() end return self.h end
function methods:SetPoint(point, relative, _, x, y) self.point, self.anchor, self.x, self.y = point, relative, x, y end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(v) self.level = v end
function methods:GetEffectiveScale() return 1 end
function methods:IsMouseOver() return self.over == true end
function methods:EnableMouseWheel(on) self.wheel = on end
function methods:SetText(t) self.text = t end
-- Roughly how wide text draws: half its font size per letter.
function methods:GetUnboundedStringWidth() return #(self.text or "") * (self.size or 10) / 2 end
function methods:SetTexture(t) self.texture = t end
function methods:SetTexCoord(...) self.coords = { ... } end
function methods:SetVertexColor(r, g, b) self.vertex = { r, g, b } end
function methods:SetTextColor(r, g, b) self.color = { r, g, b } end
function methods:CreateTexture() return New("Texture", self) end
function methods:CreateFontString() return New("FontString", self) end

local settings = {}
local defaults = { blessings = true, blessBarSize = 30, blessSpacing = 6, blessGroupSpacing = 6,
    blessTimerSize = 14, blessShowLabels = true, blessTimers = true, blessShowAura = true, blessShowFury = false,
    blessLabelStyle = "name", blessLayout = "horizontal", blessTank = "none", blessAssist = "none",
    blessColorMissing = { r = 0.97, g = 0.27, b = 0.27 }, blessColorExpiring = { r = 1, g = 0.85, b = 0.3 },
    blessColorOwn = { r = 0.35, g = 0.6, b = 1 } }
local sets = 0
local S = {}
function S.Get(k) local v = settings[k]; if v == nil then return defaults[k] end return v end
function S.Set(k, v) settings[k] = v; sets = sets + 1 end

local THEME = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
    accent = { r = 0, g = 0.57, b = 0.93 }, accentSoft = { r = 0.3, g = 0.71, b = 0.96 }, bg = { r = 0, g = 0, b = 0 } }
local cards = {}
local account = {}
local refreshed = 0
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S, THEME = THEME,
    Apply = function() end, ShowUnlockMode = function() end, HideUnlockMode = function() end,
    AccountSettings = function() return account end,
    OpenBlessingsWindow = function() end,
    PixelInset = function() end, Border = function(f) f.bordered = true end, UIFontPath = function() return "font" end,
    Font = function(parent) return New("FontString", parent) end,
    Solid = function(parent) return New("Texture", parent) end,
    Color = function(_, text) return text end,
    Tooltip = function(frame, title, body) frame.tipTitle, frame.tipBody = title, body end,
    UI = { RefreshPage = function() refreshed = refreshed + 1 end },
    Shared = {
        Style = setmetatable({ PLUS = "plus", CROSS = "cross", OPACITY_MIN = 20 },
            { __index = dofile("Tools/regression/shared_style.lua") }),
        Parts = { HudFont = function(fs, font, size, outline) fs.font, fs.size, fs.outline = font, size, outline end,
            Hover = function(button) button.flatHover = true end },
        Anchor = { Rows = function(spec) return { { anchor = spec } } end },
        Settings = {
            Group = function(name) return { group = name } end,
            Look = function(prefix, opts) return { { look = prefix, opts = opts } } end,
            Page = function()
                return { Window = function() end, Card = function(_, card) cards[card.id] = card end }
            end,
        },
    },
}

local class = "WARRIOR"
local menu
local function Root()
    local root = { items = {} }
    local function Add(kind, label, a, b) root.items[#root.items + 1] = { kind = kind, label = label, a = a, b = b } end
    function root:CreateTitle(label) Add("title", label) end
    function root:CreateRadio(label, isSelected, select) Add("radio", label, isSelected, select) end
    function root:CreateButton(label, click) Add("button", label, click) end
    function root:CreateCheckbox(label, isChecked, toggle) Add("checkbox", label, isChecked, toggle) end
    function root:CreateDivider() Add("divider") end
    return root
end
local function Pick(label)
    for _, item in ipairs(menu.items) do
        if item.label == label then
            if item.kind == "radio" then item.b() else item.a() end
            return true
        end
    end
end

local shift, cursorX, cursorY, templated = false, 0, 0, 0
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(kind, _, parent, template)
        if template then templated = templated + 1 end
        return New(kind, parent)
    end,
    hooksecurefunc = function() end,
    C_Timer = { After = function() end },
    C_Spell = { GetSpellName = function(id) return "Spell " .. id end, GetSpellTexture = function(id) return id end },
    C_SpellBook = { IsSpellKnown = function() return true end },
    UnitClass = function() return "Class", class end,
    UnitName = function() return "Glyadin" end,
    UnitFullName = function() return "Glyadin" end,
    UnitGUID = function() return "me" end,
    IsInRaid = function() return false end,
    GetNumSubgroupMembers = function() return 0 end,
    GetNormalizedRealmName = function() return "Forever" end,
    GetRealmName = function() return "Forever" end,
    LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PRIEST = "Priest", ROGUE = "Rogue", MAGE = "Mage" },
    MenuUtil = { CreateContextMenu = function(owner, generate)
        menu = Root()
        menu.owner = owner
        generate(owner, menu)
    end },
    IsShiftKeyDown = function() return shift end,
    GetCursorPosition = function() return cursorX, cursorY end,
}, { __index = _G })
env._G = env

local function Load(path)
    local fn = assert(loadfile(path))
    setfenv(fn, env)
    fn("NaowhForever", ns)
end
Load("Shared/UI/ItemBar.lua")
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_Combat/Blessings/.*%.lua$")) do
    if not path:find("/UI/Window%.lua$") then Load(path) end
end
local B = ns.Blessings
local studio = assert(cards.bar and cards.bar.studio, "the Blessing Bar card has a preview")

local function Stage()
    local stage = New("Frame")
    stage:SetSize(600, 160)
    return stage
end

-- The bar's buttons take the shared flat hover and pressed look (Parts.Press), with none of their own.
local barSource = io.open("NaowhForever_Combat/Blessings/UI/Bar.lua", "rb"):read("*a")
local recipientSource = io.open("NaowhForever_Combat/Blessings/UI/Recipient.lua", "rb"):read("*a")
local lookSource = io.open("NaowhForever_Combat/Blessings/View/Look.lua", "rb"):read("*a")
check("the aura and Righteous Fury buttons use Parts.Press", barSource:find("Parts%.Press%(btn%)") ~= nil)
check("so do the class buttons", recipientSource:find("Parts%.Press%(button%)") ~= nil)
check("Blessings has no hover look of its own", not (barSource .. recipientSource .. lookSource)
    :find("Look%.Hover"))

-- A warrior's view: the bar as a sample, still editable for its look.
local preview = studio.new(Stage())
check("the preview's buttons hover like the bar's", preview.aura.flatHover and preview.plus.flatHover)
studio.paint(preview, "group")
check("the preview is plain frames, no secure template", templated == 0)
check("the aura button shows, Righteous Fury is off by default", preview.aura.shown and not preview.fury.shown)
check("a + slot brings Righteous Fury back", preview.plus.shown and preview.plus.tipBody:find("Righteous Fury"))
check("the note says how to edit", preview.hint.text:find("Shift%-wheel") and preview.hint.text:find("x hides"))
check("the aura's tooltip is the bar's own, then what it does here",
    preview.aura.tipTitle == "Aura" and preview.aura.tipBody:find(B.AURA_TIP, 1, true) == 1)
check("a class's tooltip says what left-click does on the bar",
    preview.cells[1].tipTitle == "Warrior" and preview.cells[1].tipBody:find("the next Warrior who needs it", 1, true))

preview.aura.scripts.OnEnter(preview.aura)
check("hovering the aura shows its x", preview.remove.shown and preview.remove.owner == preview.aura)
preview.aura.scripts.OnLeave(preview.aura)
check("leaving it hides the x", not preview.remove.shown)
preview.aura.scripts.OnEnter(preview.aura)
preview.remove.scripts.OnClick(preview.remove)
check("its x turns the Aura Button setting off", S.Get("blessShowAura") == false)
studio.paint(preview, "group")
check("the aura button is gone", not preview.aura.shown)
check("with both hidden the + offers both", preview.plus.shown and preview.plus.tipBody:find("Choose"))
preview.plus.scripts.OnClick(preview.plus)
check("the + opens a menu of both", menu and menu.owner == preview.plus and #menu.items == 3)
check("picking one brings it back", Pick("Aura Button") and S.Get("blessShowAura") == true)
settings.blessShowFury = true
studio.paint(preview, "group")
check("with nothing hidden there is no + slot", not preview.plus.shown)
settings.blessShowFury = false
studio.paint(preview, "group")
preview.plus.scripts.OnClick(preview.plus)
check("with one hidden the + brings it straight back", S.Get("blessShowFury") == true)
settings.blessShowFury = nil

-- The wheel: size, Shift for spacing, never past the sliders' ends.
studio.paint(preview, "group")
local wheel = preview.cells[2].scripts.OnMouseWheel
wheel(preview.cells[2], 1)
check("wheel up grows the buttons", S.Get("blessBarSize") == 31)
wheel(preview.cells[2], -1)
check("wheel down shrinks them", S.Get("blessBarSize") == 30)
settings.blessBarSize = 70
sets = 0
wheel(preview.cells[2], 1)
check("never past the slider's top, and nothing written", S.Get("blessBarSize") == 70 and sets == 0)
shift = true
wheel(preview.bar, 1)
check("Shift-wheel changes the spacing", S.Get("blessSpacing") == 7 and S.Get("blessBarSize") == 70)
settings.blessSpacing = 0
wheel(preview.bar, -1)
check("spacing stops at the slider's bottom", S.Get("blessSpacing") == 0)
shift = false
settings.blessBarSize, settings.blessSpacing = nil, nil

-- Dragging the gap after the aura sets the Aura / Class Gap.
studio.paint(preview, "group")
local grip = preview.grip
check("the gap after the aura can be dragged", grip.shown and grip.anchor == preview.bar)
check("the grip spans the gap after the + slot and the aura", grip.w == 12 and grip.x == 66)
cursorX = 100
grip.scripts.OnMouseDown(grip, "LeftButton")
check("a drag runs only while dragging", grip.scripts.OnUpdate ~= nil)
cursorX = 110
grip.scripts.OnUpdate(grip)
check("dragging right widens the gap", S.Get("blessGroupSpacing") == 16)
cursorX = 1000
grip.scripts.OnUpdate(grip)
check("the gap stops at the slider's top", S.Get("blessGroupSpacing") == 40)
grip.scripts.OnMouseUp(grip, "LeftButton")
check("letting go stops the drag", grip.scripts.OnUpdate == nil and not grip.dragging)
settings.blessGroupSpacing = nil

-- Direction: Vertical stacks the bar top to bottom, the class labels beside the buttons and
-- the gap after the aura dragged up or down; Horizontal puts it all back.
settings.blessLayout = "vertical"
studio.paint(preview, "group")
local first, second = preview.cells[1], preview.cells[2]
check("vertical: the class buttons stack from the top", first.point == "TOP" and second.point == "TOP"
    and first.x == 0 and second.y == first.y - 36)
check("vertical: the bar is a column", preview.bar.w == 30 and preview.bar.h == 216)
check("vertical: the + sits at the top", preview.plus.point == "TOP")
check("vertical: class labels beside their buttons", first.label.point == "LEFT" and first.label.anchor == first)
check("vertical: the gap is a band across the column", grip.point == "TOP" and grip.w == 30 and grip.h == 12
    and grip.y == -66 and grip.tipBody:find("up or down"))
cursorY = 100
grip.scripts.OnMouseDown(grip, "LeftButton")
cursorY = 90
grip.scripts.OnUpdate(grip)
check("vertical: dragging down widens the gap", S.Get("blessGroupSpacing") == 16)
grip.scripts.OnMouseUp(grip, "LeftButton")
cursorY = 0
check("the card's summary says vertical", cards.bar.summary(S):find(", vertical", 1, true))
settings.blessLayout, settings.blessGroupSpacing = nil, nil
studio.paint(preview, "group")
check("horizontal again: a row with labels under the buttons", first.point == "LEFT" and first.label.point == "TOP"
    and preview.bar.h == 30 and grip.point == "LEFT")

-- Hovering and the wheel make no garbage.
studio.paint(preview, "group")
local aura = preview.aura
Measure("hovering the aura", 0.5, function()
    aura.scripts.OnEnter(aura)
    aura.scripts.OnLeave(aura)
end)
Measure("the wheel", 0.5, function()
    wheel(aura, 1)
    wheel(aura, -1)
end)

-- Font, outline and the status colours: today's look until a setting changes it.
settings.blessFont, settings.blessOutline, settings.blessThemeColors = "", "OUTLINE", false
studio.paint(preview, "group")
local warriorCell, priestCell = preview.cells[1], preview.cells[2]
check("the minutes left keep the Addon Font, outlined, at Font Size", warriorCell.timer.font == ""
    and warriorCell.timer.outline == "OUTLINE" and warriorCell.timer.size == 14)
check("the count and class label keep their sizes", warriorCell.mark.size == 14 and warriorCell.label.size == 10)
check("missing is red and running out yellow", warriorCell.icon.vertex[1] == B.Look.RED.r
    and priestCell.icon.vertex[2] == B.Look.YELLOW.g and warriorCell.mark.color[1] == B.Look.RED.r)
settings.blessFont, settings.blessOutline, settings.blessTimerSize = "Naowh", "", 18
studio.paint(preview, "group")
check("Font, Outline and Font Size reach every text", warriorCell.timer.font == "Naowh"
    and warriorCell.timer.outline == "" and warriorCell.timer.size == 18 and warriorCell.mark.font == "Naowh"
    and warriorCell.label.outline == "")
settings.blessThemeColors = true
studio.paint(preview, "group")
check("Apply Theme: missing in the Accent, running out in the lighter Accent",
    warriorCell.icon.vertex[3] == THEME.accent.b and priestCell.icon.vertex[3] == THEME.accentSoft.b
    and warriorCell.mark.color[3] == THEME.accent.b and preview.note.text:find("^Accent"))
local look
for _, row in ipairs(cards.bar.rows) do if row[1] and row[1].look then look = row[1] end end
check("the card has the standard Text rows on the timer size", look and look.look == "bless"
    and look.opts.keys.FontSize == "blessTimerSize")
settings.blessThemeColors = false
settings.blessColorMissing = { r = 0, g = 1, b = 0 }
settings.blessColorExpiring = { r = 1, g = 0, b = 1 }
studio.paint(preview, "group")
check("your own colors replace the missing and running out ones", warriorCell.icon.vertex[2] == 1
    and warriorCell.icon.vertex[1] == 0 and priestCell.icon.vertex[3] == 1 and priestCell.icon.vertex[2] == 0)
settings.blessColorMissing, settings.blessColorExpiring = nil, nil
settings.blessFont, settings.blessOutline, settings.blessTimerSize, settings.blessThemeColors = nil, nil, nil, nil

-- Class names keep to their own slot, the button plus the gap: a long one shrinks down to 7 pt,
-- then shortens to three letters, and a name with room is left as it is.
settings.blessBarSize, settings.blessSpacing = 16, 0
studio.paint(preview, "group")
local mageCell = preview.cells[4]
check("a name that fits smaller shrinks, no lower than 7 pt", mageCell.label.text == "Mage"
    and mageCell.label.size < 10 and mageCell.label.size >= 7)
check("a name too long even at 7 pt shortens to three letters", warriorCell.label.text == "War"
    and warriorCell.label.size == 7)
settings.blessBarSize, settings.blessSpacing = nil, nil
studio.paint(preview, "group")
check("with room again the full name comes back at its size", warriorCell.label.text == "Warrior"
    and warriorCell.label.size == 10 and mageCell.label.text == "Mage" and mageCell.label.size == 10)
check("the Name style builds no class icon", warriorCell.classIcon == nil)

-- Class Label Style: Class Icon shows the class's icon under its button instead of its name,
-- two thirds of the button, between 12 and 24 px.
settings.blessLabelStyle = "icon"
studio.paint(preview, "group")
local classIcon = warriorCell.classIcon
check("Class Icon shows the class's icon in place of the name", classIcon and classIcon.shown
    and not warriorCell.label.shown and classIcon.tex.texture == "Interface\\Icons\\ClassIcon_WARRIOR"
    and mageCell.classIcon.tex.texture == "Interface\\Icons\\ClassIcon_MAGE")
check("the icon is cropped and edged like the buttons", classIcon.tex.coords[1] == 0.08
    and classIcon.tex.coords[2] == 0.92 and classIcon.bordered)
check("the icon is two thirds of the button", classIcon.w == 20 and classIcon.h == 20)
settings.blessBarSize = 70
studio.paint(preview, "group")
check("the icon stops at 24 px on big buttons", classIcon.w == 24)
settings.blessBarSize = 20
studio.paint(preview, "group")
check("and keeps two thirds on small ones", classIcon.w == 13)
-- Growth Direction: Left and Up grow from the opposite edge; the saved Horizontal and Vertical still mean Right and Down.
settings.blessBarSize, settings.blessLabelStyle, settings.blessLayout = nil, nil, "LEFT"
studio.paint(preview, "group")
check("left: the class buttons stack from the right edge", first.point == "RIGHT" and second.point == "RIGHT"
    and second.x == first.x - 36 and second.y == 0)
check("left: the bar is a row with the labels under it", preview.bar.h == 30 and first.label.point == "TOP"
    and preview.plus.point == "RIGHT")
cursorX = 100
grip.scripts.OnMouseDown(grip, "LeftButton")
cursorX = 90
grip.scripts.OnUpdate(grip)
check("left: dragging left widens the gap", S.Get("blessGroupSpacing") == 16)
grip.scripts.OnMouseUp(grip, "LeftButton")
cursorX, settings.blessGroupSpacing = 0, nil
settings.blessLayout = "UP"
studio.paint(preview, "group")
check("up: the class buttons stack from the bottom", first.point == "BOTTOM" and second.point == "BOTTOM"
    and second.y == first.y + 36 and second.x == 0)
check("up: the bar is a column with the labels beside it", preview.bar.w == 30 and first.label.point == "LEFT")
cursorY = 100
grip.scripts.OnMouseDown(grip, "LeftButton")
cursorY = 110
grip.scripts.OnUpdate(grip)
check("up: dragging up widens the gap", S.Get("blessGroupSpacing") == 16)
grip.scripts.OnMouseUp(grip, "LeftButton")
check("the card's summary says vertical for up", cards.bar.summary(S):find(", vertical", 1, true))
cursorY, settings.blessGroupSpacing, settings.blessLayout = 0, nil, nil
studio.paint(preview, "group")

settings.blessShowLabels = false
studio.paint(preview, "group")
check("Class Labels off hides the icon too", not classIcon.shown and not warriorCell.label.shown)
settings.blessBarSize, settings.blessShowLabels, settings.blessLabelStyle = nil, nil, nil
studio.paint(preview, "group")
check("back on Name the name returns and the icon hides", warriorCell.label.shown and not classIcon.shown
    and warriorCell.label.text == "Warrior")
settings.blessLabelStyle, settings.blessLayout = "icon", "vertical"
studio.paint(preview, "group")
check("a column's icons sit beside their buttons, not on the one below", classIcon.shown
    and classIcon.point == "LEFT" and classIcon.anchor == warriorCell)
settings.blessLabelStyle, settings.blessLayout = nil, nil
studio.paint(preview, "group")
check("and back under them in a row", not classIcon.shown and warriorCell.label.point == "TOP")
settings.blessBarSize, settings.blessSpacing, settings.blessLayout = 16, 0, "vertical"
studio.paint(preview, "group")
check("a column's names sit beside it with nothing to run into: never squeezed",
    warriorCell.label.text == "Warrior" and warriorCell.label.size == 10)
settings.blessBarSize, settings.blessSpacing, settings.blessLayout = nil, nil, nil
studio.paint(preview, "group")

-- The Anchor card: Growth Direction first, the shared anchor rows on the bar's own settings, and a way
-- back above Buff Reminders. The Blessing Bar card no longer lists Growth Direction.
local anchorRows = cards.anchor and cards.anchor.rows
check("the Anchor card starts with Growth Direction", anchorRows and anchorRows[1].key == "blessLayout"
    and anchorRows[1].label == "Growth Direction")
local layoutValues, layoutOrder = anchorRows[1].choice[1], anchorRows[1].choice[2]
check("Growth Direction offers Right, Left, Up and Down, keeping the saved Horizontal and Vertical",
    layoutOrder[1] == "horizontal" and layoutOrder[2] == "LEFT" and layoutOrder[3] == "UP"
    and layoutOrder[4] == "vertical" and layoutValues.horizontal == "Right" and layoutValues.vertical == "Down")
check("the Anchor card has the shared rows and Reset Position", anchorRows[2].anchor.prefix == "bless"
    and anchorRows[3].label == "Reset Position" and anchorRows[3].button == B.ResetPosition)
local barLayoutRow = false
for _, row in ipairs(cards.bar.rows) do if row.key == "blessLayout" then barLayoutRow = true end end
check("Growth Direction is on one card only", not barLayoutRow)

-- Off: nothing in the preview edits.
settings.blessings = false
studio.paint(preview, "group")
local wheels = true
for _, f in ipairs(preview.wheels) do if f.wheel then wheels = false end end
check("off: the wheel is free for the page", wheels)
check("off: no + and no gap to drag", not preview.plus.shown and not preview.grip.shown)
check("off: the note says why", preview.hint.text:find("Turn on Blessings"))
preview.aura.scripts.OnEnter(preview.aura)
check("off: no x", not preview.remove.shown)
settings.blessings = nil

-- A paladin: the preview shows their plan and edits it through the bar's own menus.
class = "PALADIN"
local mine = studio.new(Stage())
studio.paint(mine, "group")
check("an unplanned class shows the question mark", mine.cells[1].icon.texture == 134400)
local warrior = mine.cells[1]
menu = nil
warrior.scripts.OnClick(warrior, "LeftButton")
check("left-click opens nothing in the preview", menu == nil)
warrior.scripts.OnClick(warrior, "RightButton")
check("right-click opens the class's blessing menu", menu and menu.items[1].label == "Warrior")
local players = false
for _, item in ipairs(menu.items) do if item.label == "Players" then players = true end end
check("without the bar's player list", not players and Pick("Assignments") ~= nil)
warrior.scripts.OnClick(warrior, "RightButton")
check("choosing a blessing writes the plan", Pick("Spell 20217") and B.Store().classes.WARRIOR == "kings")
check("and refreshes the page", refreshed > 0)
studio.paint(mine, "group")
check("the preview shows the new blessing", warrior.icon.texture == 20217)
mine.aura.scripts.OnClick(mine.aura, "LeftButton")
check("clicking the aura opens the aura menu", menu and menu.items[1].label == "Aura")
check("choosing one sets your aura", Pick("Spell 7294") and B.Store().aura == "retribution")
studio.paint(mine, "group")
check("the preview shows your aura", mine.aura.icon.texture == 7294)

-- A class with someone on their own blessing says so, and can hand them back the class blessing.
local function Has(label)
    for _, item in ipairs(menu.items) do if item.label == label then return true end end
end
B.ClassMenu(mine.cells[1], "PALADIN", true)
check("nobody on their own blessing: no line about it", not Has("Give them the class blessing"))
B.Store().players.me = "might"
B.ClassMenu(mine.cells[1], "PALADIN", true)
check("the class menu counts who has their own blessing", Has("1 player has their own blessing"))
B.ClassMenu(mine.cells[1], "WARRIOR", true)
check("and only for that class's members", not Has("Give them the class blessing"))
B.ClassMenu(mine.cells[1], "PALADIN", true)
refreshed = 0
check("its button gives them the class blessing again", Pick("Give them the class blessing")
    and B.Store().players.me == nil and refreshed > 0)

-- The card lists every class's blessing too, writing the same plan as the menus.
local classRows
for _, row in ipairs(cards.bar.rows) do
    if row[1] and row[1].group == "Blessings by Class" then classRows = row end
end
check("the card has a Blessings by Class group, a row per class and Salvation",
    classRows and #classRows == #B.CLASSES + 2)
local salvRow = classRows[#classRows]
check("the last row is Salvation, off to begin with", salvRow.get() == "none")
salvRow.set("give")
check("giving Salvation writes your plan", B.Store().salv == true and salvRow.get() == "give")
salvRow.set("none")
check("and None turns it off", B.Store().salv == nil)
local warriorRow = classRows[2]
check("each row is named for its class", warriorRow.label == "Warrior")
check("its help names the blessings, so a search for one finds it",
    warriorRow.help:find("Kings", 1, true) and warriorRow.help:find("Might", 1, true)
    and warriorRow.help:find("Wisdom", 1, true))
check("the row shows the plan", warriorRow.get() == "kings")
local values, order = warriorRow.choice()
check("its choices are the blessings, then None", values.kings == "Spell 20217" and order[#order] == "none"
    and #order == #B.BLESSINGS + 1)
refreshed = 0
warriorRow.set("might")
check("choosing one writes the plan and refreshes the page", B.Store().classes.WARRIOR == "might" and refreshed > 0)
warriorRow.set("none")
check("None clears it", B.Store().classes.WARRIOR == nil and warriorRow.get() == "none")
check("shown to paladins", not warriorRow.hidden())
class = "WARRIOR"
check("and hidden from everyone else", warriorRow.hidden())
for i = #cards.bar.rows, 1, -1 do
    local row = cards.bar.rows[i]
    if row[1] and row[1].look then table.remove(cards.bar.rows, i) end
end
local Search = dofile("Tools/regression/settings_search.lua")({ ["Blessings/Settings"] = { cards.bar } })
local kings = Search("kings")
check("the options search finds Kings on the Blessing Bar card, a row per class",
    #kings >= #B.CLASSES and kings[1].label == "Warrior" and kings[1].card == "Blessings/Settings:bar")
check("and finds them by \"greater\"", #Search("greater") >= #B.CLASSES)

-- Saved plans from before Salvation was split off the class blessings: each Salvation becomes "Salvation on",
-- once, and the plan keeps its other blessings.
account.blessings["Glyadin-Forever"] = { classes = { MAGE = "salvation", WARRIOR = "might" },
    players = { me = "salvation", you = "kings" } }
local migrated = B.Store()
check("an old class Salvation is cleared", migrated.classes.MAGE == nil and migrated.classes.WARRIOR == "might")
check("an old player Salvation is cleared, the others kept", migrated.players.me == nil and migrated.players.you == "kings")
check("and Salvation is on", migrated.salv == true)
migrated.salv = nil
check("it does not come back once turned off", B.Store().salv == nil)

-- The preset keeps whether you give Salvation.
class = "PALADIN"
B.Store().salv = true
check("saving the preset", B.SavePreset())
check("the preset keeps Salvation", account.blessingPreset["Glyadin"].salv == true)
B.Store().salv = nil
check("loading the preset gives it back", B.LoadPreset() and B.Store().salv == true)
B.Store().salv = nil
account.blessingPreset = { Glyadin = { classes = { MAGE = "salvation", WARRIOR = "might" } } }
check("loading a preset from before the split", B.LoadPreset())
check("turns its class Salvation into Salvation on",
    B.Store().classes.MAGE == nil and B.Store().classes.WARRIOR == "might" and B.Store().salv == true)
B.Store().salv = nil

-- The seal button: seals are looked up like the other spells, picked from a menu and kept in your plan.
check("the seals are indexed by key and spell", B.BY_KEY.sealCommand.ranks[1] == 20375 and B.FAMILY[20375] == "sealCommand")
check("a seal has a name and an icon", B.SpellName("sealFury") == "Spell 1311649" and B.SpellIcon("sealFury") == 1311649)
B.SealMenu({})
local sealLabels = {}
for _, item in ipairs(menu.items) do sealLabels[#sealLabels + 1] = item.label end
check("the seal menu lists every seal you know, then the default", #sealLabels == #B.SEALS + 2
    and sealLabels[2] == "Spell 20154" and sealLabels[#sealLabels] == "Default")
B.SetSeal("sealCommand")
check("choosing a seal keeps it and refreshes", B.Store().seal == "sealCommand" and refreshed > 0)
B.SetSeal(nil)
check("and Default clears it", B.Store().seal == nil)

-- Clear empties your whole plan.
local plan = B.Store()
plan.classes.WARRIOR, plan.aura, plan.salv, plan.players.me = "might", "retribution", true, "kings"
B.ClearAll()
plan = B.Store()
check("Clear empties your classes, aura, Salvation and own choices",
    next(plan.classes) == nil and plan.aura == nil and plan.salv == nil and next(plan.players) == nil)
class = "WARRIOR"

print(("test-blessing-preview: %d checks passed"):format(checks))
