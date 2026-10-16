-- ns.Hairline, ns.PixelInset and ns.Border (Core/Core.lua): lines, insets and borders in whole screen
-- pixels, refitted when their frame shows again. The renderer's snapping is not emulated;
-- these check the sizes and offsets handed to it.
local f = assert(io.open(arg[1] or "Core/Core.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local first = assert(source:find("local fitters", 1, true))
local last = assert(source:find("function ns.Solid(parent, layer, color, alpha)", first, true))

local factor = 768 / 1440          -- a 1440p screen
local Frame
function Frame(scale, parent)
    local o = { scale = scale, parent = parent, points = {}, children = {}, visible = true }
    function o:GetObjectType() return self.texture and "Texture" or "Frame" end
    function o:GetParent() return self.parent end
    function o:GetEffectiveScale() return self.parent and self.parent:GetEffectiveScale() or self.scale end
    function o:SetScript(_, fn) self.onShow = fn end
    function o:IsVisible() return self.visible end
    function o:SetHeight(h) self.height = h end
    function o:SetWidth(w) self.width = w end
    function o:ClearAllPoints() self.points = {} end
    function o:SetPoint(point, _, _, x, y) self.points[point] = { x, y } end
    function o:SetAllPoints() end
    function o:GetFrameLevel() return self.level or 1 end
    function o:SetFrameLevel(level) self.level = level end
    function o:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function o:CreateTexture()
        local t = Frame(nil, self)
        t.texture = true
        self.textures = self.textures or {}
        self.textures[#self.textures + 1] = t
        return t
    end
    -- Showing a frame shows its children: each child's OnShow runs.
    function o:Show()
        if self.onShow then self.onShow(self) end
        for _, child in ipairs(self.children) do child:Show() end
    end
    return o
end
local function Texture(parent)
    local t = Frame(nil, parent)
    t.texture = true
    return t
end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
local env = setmetatable({ ns = ns, BORDER_EDGES = 4, MAX_FRAME_LEVEL = 9999, PixelUtil = { GetPixelToUIUnitFactor = function() return factor end },
    CreateFrame = function(_, _, parent)
        local child = Frame(1, parent)
        if parent then parent.children[#parent.children + 1] = child end
        child.RegisterEvent = function() end
        return child
    end },
    { __index = _G })
local chunk = assert(loadstring(source:sub(first, last - 1))); setfenv(chunk, env); chunk()

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end
local function Near(a, b) return math.abs(a - b) < 1e-9 end

Case("a line is one screen pixel thick at a fractional scale", function()
    local panel = Frame(0.71)
    local h, v = Texture(panel), Texture(panel)
    ns.Hairline(h, "h"); ns.Hairline(v, "v")
    assert(Near(h.height, factor / 0.71) and Near(v.width, factor / 0.71), "one pixel in the panel's units")
    assert(h.width == nil and v.height == nil, "only the thickness is set")
end)
Case("an inset is that many pixels in on every side, an outset out", function()
    local panel = Frame(0.71)
    local icon, ring = Texture(panel), Texture(panel)
    ns.PixelInset(icon, 1); ns.PixelInset(ring, -1)
    local px = factor / 0.71
    assert(Near(icon.points.TOPLEFT[1], px) and Near(icon.points.TOPLEFT[2], -px), "top left inset")
    assert(Near(icon.points.BOTTOMRIGHT[1], -px) and Near(icon.points.BOTTOMRIGHT[2], px), "bottom right inset")
    assert(Near(ring.points.TOPLEFT[1], -px), "an outset goes the other way")
end)
Case("a frame showing again after a scale change refits its lines once", function()
    local panel = Frame(0.71)
    local line = Texture(panel)
    ns.Hairline(line, "h")
    ns.Hairline(line, "h")
    assert(#panel.children == 1, "one watcher per frame, however often a line registers")
    -- A module setting the frame's own OnShow afterwards does not stop the refit.
    panel:SetScript("OnShow", function() end)
    panel.scale = 1.4
    panel:Show()
    assert(Near(line.height, factor / 1.4), "refitted to the new scale")
end)
Case("RefitPixels redraws what is up, and leaves hidden frames for their next show", function()
    local shown, hidden = Frame(1), Frame(1)
    hidden.visible = false
    local a, b = Texture(shown), Texture(hidden)
    ns.Hairline(a, "h"); ns.Hairline(b, "h")
    shown.scale, hidden.scale = 2, 2
    ns.RefitPixels()
    assert(Near(a.height, factor / 2), "the shown frame refits")
    assert(Near(b.height, factor), "the hidden one waits")
end)
Case("a border is one pixel to start, any whole number after, and refits at a new scale", function()
    local panel = Frame(0.71)
    local border = ns.Border(panel, { r = 0, g = 0, b = 0 })
    local edges = border._frame.textures
    local px = factor / 0.71
    assert(#edges == 4 and border.pixels == 1, "four edges, one pixel")
    assert(Near(edges[1].height, px) and Near(edges[2].height, px), "top and bottom one pixel")
    assert(Near(edges[3].width, px) and Near(edges[4].width, px), "left and right one pixel")
    border:SetPixels(3)
    assert(Near(edges[1].height, 3 * px) and Near(edges[4].width, 3 * px), "three pixels when asked")
    panel.scale = 1.4
    panel:Show()
    assert(Near(edges[2].height, 3 * factor / 1.4) and Near(edges[3].width, 3 * factor / 1.4),
        "and still three pixels after a scale change")
    border:SetColor(1, 0, 0)
    assert(edges[1].color[1] == 1 and edges[4].color[4] == 1, "its color is set on every edge, opaque to start")
end)
print(count .. " pixel regressions passed")
