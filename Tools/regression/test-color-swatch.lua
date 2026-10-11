-- The shared color swatch: UI.BuildColorSwatchControl cut out of Widgets.lua and run against a
-- color picker that behaves like Blizzard's (swatchFunc fires as it opens, cancelFunc on Escape).
local f = assert(io.open("Core/Options/Widgets.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local constants = assert(source:match("\n(local MEDIA = .-\n)\nlocal UI = {}\n"), "Widgets constants")
local body = constants .. assert(source:match("\n(local function Near%(a, b%).-\nfunction UI%.BuildColorSwatchControl%(.-\nend)\n"),
    "BuildColorSwatchControl")
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local picker = {}
function picker:SetupColorPickerAndShow(info)
    self.info, self.r, self.g, self.b, self.a = info, info.r, info.g, info.b, info.opacity
    info.swatchFunc()
end
function picker:GetColorRGB() return self.r, self.g, self.b end
function picker:GetColorAlpha() return self.a end
function picker:Drag(r, g, b) self.r, self.g, self.b = r, g, b; self.info.swatchFunc() end
function picker:Okay() self.info.swatchFunc() end
function picker:Cancel() self.info.cancelFunc() end

local function Frame()
    local fr = {}
    function fr:SetScript(_, fn) self.onClick = fn end
    return setmetatable(fr, { __index = function() return function() end end })
end

local function Swatch(get, hasAlpha)
    local sets = {}
    local env = setmetatable({ UI = {}, CreateFrame = Frame, ColorPickerFrame = picker,
        ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), Border = function() end, Solid = function() return Frame() end },
        T = { fg = {} } }, { __index = _G })
    local chunk = assert(loadstring(body))
    setfenv(chunk, env)
    chunk()
    local btn = env.UI.BuildColorSwatchControl(Frame(), get, function(...) sets[#sets + 1] = { ... } end, hasAlpha)
    return btn, sets
end

local btn, sets = Swatch(function() return 0.2, 0.4, 0.6 end)
btn.onClick()
check("opening saves nothing", #sets == 0)
picker:Cancel()
check("opened and cancelled: nothing saved", #sets == 0)

btn, sets = Swatch(function() return 0.2, 0.4, 0.6 end)
btn.onClick()
picker.r = 0.2 + 0.5 / 255
picker:Okay()
check("a rounding step off the opened color is not a change", #sets == 0)

btn, sets = Swatch(function() return 0.2, 0.4, 0.6 end)
btn.onClick()
picker:Drag(1, 0, 0)
check("a real change is saved as it is picked", #sets == 1 and sets[1][1] == 1 and sets[1][2] == 0)
picker:Drag(0.2, 0.4, 0.6)
check("dragging back after a change still saves", #sets == 2 and sets[2][1] == 0.2)
picker:Cancel()
check("cancel after a change restores the opened color", #sets == 3 and sets[3][1] == 0.2 and sets[3][3] == 0.6)

btn, sets = Swatch(function() return nil end)
btn.onClick()
picker:Cancel()
check("an unset color opens as white and saves nothing", #sets == 0 and picker.info.r == 1)

btn, sets = Swatch(function() return 0.2, 0.4, 0.6, 0.5 end, true)
btn.onClick()
picker.a = 0.8
picker.info.opacityFunc()
check("an opacity change is a change", #sets == 1 and sets[1][4] == 0.8)

print("PASS color swatch: " .. checks .. " checks")
