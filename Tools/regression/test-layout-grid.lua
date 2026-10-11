-- Run with Lua 5.1 from the repository root: Layout Mode's grid. Lines are counted out from
-- the screen's centre both ways, every fifth one stronger, the centre lines in the accent with a
-- mark where they cross; each line starts on a whole pixel at any UI scale, and lines left over
-- after a resize are hidden.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

-- The grid's own file, from its first named value on: T and Pixel come from the stub env below.
local f = assert(io.open("Core/Unlock/Grid.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local first = assert(source:find("local GRID_STEP", 1, true))
local last = assert(source:find("\nfunction ns.SetAnchorGridShown", first, true))
last = assert(source:find("\nend\n", last, true))
local section = source:sub(first, last + 4)

local W, H, scale = 1920, 1080, 1
local function Texture()
    local t = { shown = true }
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:ClearAllPoints() self.point = nil end
    function t:SetPoint(...) self.point = { ... } end
    function t:SetSize(w, h) self.w, self.h = w, h end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end
local made
local UIParent = {}
function UIParent:GetWidth() return W end
function UIParent:GetHeight() return H end
function UIParent:GetEffectiveScale() return scale end
local FG, ACCENT = { r = 1, g = 1, b = 1 }, { r = 0, g = 0.57, b = 0.93 }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
local env = setmetatable({
    ns = ns, T = { fg = FG, accent = ACCENT }, UIParent = UIParent,
    Pixel = function() return 1 / scale end,
    PixelUtil = { GetNearestPixelSize = function(v, s) return math.floor(v * s + 0.5) / s end },
    CreateFrame = function()
        made = Texture()
        function made:SetFrameStrata() end
        function made:SetAllPoints() end
        function made:CreateTexture() return Texture() end
        return made
    end,
}, { __index = _G })
local chunk = assert(loadstring(section, "grid")); setfenv(chunk, env)
chunk()

local function Shown()
    local up, level = {}, {}
    for _, line in ipairs(made.lines) do
        if line.shown then
            if line.h == H then up[#up + 1] = line else level[#level + 1] = line end
        end
    end
    return up, level
end
local function Whole(v) return math.abs(v * scale - math.floor(v * scale + 0.5)) < 1e-6 end

ns.SetAnchorGridShown(true)
local up, level = Shown()
Check(made.shown and #up == 2 * 24 + 1 and #level == 2 * 13 + 1, "lines both ways from the centre, as many as fit")
local strong, centre = 0, nil
for _, line in ipairs(up) do
    if line.color[4] == 0.18 then strong = strong + 1 end
    if line.color[1] == ACCENT.r and line.color[3] == ACCENT.b then centre = line end
end
Check(strong == 2 * 4, "every fifth line is stronger")
Check(centre and centre.point[4] == 960 and centre.color[4] == 0.6, "the upright centre line in the accent, at the middle")
Check(made.mark.point[4] == 958 and made.mark.point[5] == -538 and made.mark.w == 5, "the mark sits evenly round the crossing")

-- At a fractional UI scale every line still starts on a whole pixel.
scale, W, H = 1.25, 1536, 864
ns.SetAnchorGridShown(true)
up, level = Shown()
local whole = true
for _, line in ipairs(up) do whole = whole and Whole(line.point[4]) and line.w == 1 / scale end
for _, line in ipairs(level) do whole = whole and Whole(line.point[5]) and line.h == 1 / scale end
Check(whole, "at UI scale 1.25 each line starts on a whole pixel and is one pixel thick")
Check(#up == 2 * 19 + 1 and #level == 2 * 10 + 1, "fewer lines on the smaller screen, the rest hidden")

ns.SetAnchorGridShown(false)
Check(not made.shown, "hidden")

print(("test-layout-grid: %d checks passed"):format(checks))
