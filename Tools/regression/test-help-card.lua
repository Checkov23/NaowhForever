-- Run with Lua 5.1 from the repository root: the house help card (UI.ShowWidgetTooltip). It
-- shows nothing for no text and only calls a text function when it shows, narrows to a short
-- line and wraps a long one at its width, sits by the cursor or over its frame, and falls back
-- to its full width and one line when the client keeps a string's size secret.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local f = assert(io.open("Core/Options/Widgets.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
-- The file's named values, then the card: from its state to the toggle's first helper.
local constants = assert(source:match("\n(local MEDIA = .-\n)\nlocal UI = {}\n"), "Widgets constants")
local first = assert(source:find("\nlocal card\n", 1, true))
local last = assert(source:find("\nlocal function Smooth(tex)", first, true))
local section = constants .. source:sub(first, last)

local CHAR_W, LINE_H = 6, 13
local secret = {}
local function Frame()
    local fr = { shown = false, w = 0, h = 0 }
    function fr:SetFrameStrata() end
    function fr:SetClampedToScreen() end
    function fr:Show() self.shown = true end
    function fr:Hide() self.shown = false end
    function fr:ClearAllPoints() self.point = nil end
    function fr:SetPoint(...) self.point = { ... } end
    function fr:SetSize(w, h) self.w, self.h = w, h end
    return fr
end
local function FontString()
    local fs = { width = 0 }
    function fs:SetPoint() end
    function fs:SetSpacing() end
    function fs:SetJustifyH(j) self.justify = j end
    function fs:SetWidth(w) self.width = w end
    function fs:GetWidth() return self.width end
    function fs:SetText(t) self.text = t end
    -- Wrapped at the width it is given: as wide as its widest line, as tall as its lines.
    function fs:GetStringWidth()
        if secret.width then return "secret" end
        return math.min(#self.text * CHAR_W, self.width)
    end
    function fs:GetStringHeight()
        if secret.height then return "secret" end
        return math.ceil(#self.text * CHAR_W / self.width) * LINE_H
    end
    return fs
end

local UI = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"),
    Solid = function() return { SetAllPoints = function() end } end, Border = function() end,
    Font = function() return FontString() end }
local cursor = { 500, 300 }
local env = setmetatable({
    ns = ns, UI = UI, T = { panel = {} }, BLACK = {},
    UIParent = { GetEffectiveScale = function() return 1 end },
    CreateFrame = function() return Frame() end,
    GetCursorPosition = function() return cursor[1], cursor[2] end,
    issecretvalue = function(v) return v == "secret" end,
}, { __index = _G })
local chunk = assert(loadstring(section, "help card")); setfenv(chunk, env)
chunk()

-- The card is local to the file; its builder is an upvalue of ShowWidgetTooltip.
local card
local i = 1
while true do
    local name, value = debug.getupvalue(UI.ShowWidgetTooltip, i)
    if not name then break end
    if name == "Card" then card = value() end
    i = i + 1
end

local owner = {}
local calls = 0
UI.ShowWidgetTooltip(owner, function() calls = calls + 1 return "" end)
UI.ShowWidgetTooltip(owner, nil)
UI.ShowWidgetTooltip(owner, "")
Check(calls == 1 and not card.shown, "no text: a text function is called once, and nothing shows")

UI.ShowWidgetTooltip(owner, "Short")
Check(card and card.shown, "it shows")
Check(card.text.text == "Short" and card.w == math.ceil(5 * CHAR_W) + 16 and card.h == LINE_H + 16,
    "a short line narrows the card to fit it")
Check(card.point[1] == "BOTTOM" and card.point[2] == owner and card.point[3] == "TOP" and card.point[5] == 4,
    "centred over its frame by default")
Check(card.text.justify == "CENTER", "centred text by default")

local long = string.rep("word ", 60)
UI.ShowWidgetTooltip(owner, long, { anchor = "cursor", justify = "LEFT" })
Check(card.w == 240 and card.h == math.ceil(#long * CHAR_W / 224) * LINE_H + 16, "a long text wraps at the full width")
Check(card.point[1] == "TOPLEFT" and card.point[4] == 516 and card.point[5] == 288 and card.text.justify == "LEFT",
    "by the cursor, down and right of it, left aligned")
UI.ShowWidgetTooltip(owner, "Short")
Check(card.w == math.ceil(5 * CHAR_W) + 16, "a short line after a long one narrows again")

secret.width, secret.height = true, true
UI.ShowWidgetTooltip(owner, "Short")
Check(card.w == 240 and card.h == 10 + 16, "secret sizes: its full width and one line")
secret.width, secret.height = nil, nil

UI.HideWidgetTooltip()
Check(not card.shown, "hidden")

print(("test-help-card: %d checks passed"):format(checks))
