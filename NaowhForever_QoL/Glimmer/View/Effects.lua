-- Effects.lua: Glimmer's five effects on a frame, the same over the world and on the settings previews (G.Effects).
local ns = _G.NaowhForever

local sin, cos, sqrt, random, min, max, pi = math.sin, math.cos, math.sqrt, math.random, math.min, math.max, math.pi

local G = ns.Glimmer
local St = G.Style

local TEX = {
    glow = St.MEDIA .. "glow", flare = St.MEDIA .. "flare", ring = St.MEDIA .. "ring",
    beam = St.MEDIA .. "beam", bracket = St.MEDIA .. "bracket",
}
local TWO_PI = pi * 2

local GLOW_SIZE, GLOW_PULSE, GLOW_RATE, GLOW_ALPHA = 2.6, 0.08, 3, 0.7
local GLOW_CORE, GLOW_CORE_ALPHA = 1.1, 0.35

local GLINT_SPREAD_X, GLINT_SPREAD_Y = 0.9, 0.7
local GLINT_LIFE, GLINT_LIFE_MORE = 0.6, 0.8
local GLINT_SCALE, GLINT_SCALE_MORE = 0.5, 0.7
local GLINT_SIZE, GLINT_MIN, GLINT_GROW = 0.75, 0.35, 0.65
local GLINT_SPIN, GLINT_RISE, GLINT_WAIT = 2, 10, 0.6
local GLINT_HAZE, GLINT_HAZE_ALPHA = 2.2, 0.25

local RING_W, RING_H, GROUND_Y = 2.6, 0.95, -0.35
local COMET_RATE, COMET_GAP, COMET_SIZE, COMET_HAZE = 1.6, 0.09, 0.42, 1.8

local BEAM_W, BEAM_H, BEAM_ALPHA = 0.9, 3.6, 0.9
local RISER_RATE, RISER_HEIGHT, RISER_SIZE, RISER_SPREAD = 0.45, 3.2, 0.35, 0.5

local BRACKET_SIZE, BRACKET_FAR, BRACKET_NEAR = 0.8, 1.45, 0.95
local BRACKET_BREATH, BRACKET_RATE, BRACKET_SQUASH = 0.08, 2.5, 0.85
local CORNERS = {
    { -1, 1, 0, 1, 0, 1 }, { 1, 1, 1, 0, 0, 1 }, { 1, -1, 1, 0, 1, 0 }, { -1, -1, 0, 1, 1, 0 },
}

local BURST_FROM, BURST_GROW = 0.8, 3

local Effects = {}
G.Effects = Effects

local function Tex(fx, file, layer, sub)
    local t = fx:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetTexture(TEX[file])
    t:SetBlendMode("ADD")
    t:Hide()
    return t
end

local function Respawn(glint, now)
    local angle, reach = random() * TWO_PI, sqrt(random())
    glint.x, glint.y = cos(angle) * reach * GLINT_SPREAD_X, sin(angle) * reach * GLINT_SPREAD_Y
    glint.life = GLINT_LIFE + GLINT_LIFE_MORE * random()
    glint.scale = GLINT_SCALE + GLINT_SCALE_MORE * random()
    glint.angle = random() * TWO_PI
    glint.spin = (random() - 0.5) * GLINT_SPIN
    glint.age = now and 0 or -GLINT_WAIT * random()
end

local function Approach(v, target, step)
    if v < target then return min(v + step, target) end
    return max(v - step, target)
end

local function Paint(t, fx, alpha)
    t:SetVertexColor(fx.r, fx.g, fx.b, max(0, min(1, alpha)))
end

local function Place(t, fx, x, y, w, h)
    t:ClearAllPoints()
    t:SetPoint("CENTER", fx, "CENTER", x, y)
    t:SetSize(max(w, 0.01), max(h or w, 0.01))
end

local DRAW = {}

function DRAW.glow(fx, a, B)
    local s = B * GLOW_SIZE * (1 + GLOW_PULSE * sin(fx.time * GLOW_RATE))
    Place(fx.glow, fx, 0, 0, s)
    Paint(fx.glow, fx, a * GLOW_ALPHA)
    Place(fx.core, fx, 0, 0, B * GLOW_CORE)
    fx.core:SetVertexColor(1, 1, 1, a * GLOW_CORE_ALPHA * (0.5 + 0.5 * fx.lock))
end

function DRAW.sparkles(fx, a, B, step)
    Place(fx.glow, fx, 0, 0, B * GLINT_HAZE)
    Paint(fx.glow, fx, a * GLINT_HAZE_ALPHA)
    for _, glint in ipairs(fx.glints) do
        glint.age = glint.age + step
        if glint.age >= glint.life then Respawn(glint) end
        local age = max(glint.age, 0)
        local shine = glint.age > 0 and sin(pi * glint.age / glint.life) or 0
        local t = glint.tex
        Place(t, fx, glint.x * B, glint.y * B + GLINT_RISE * age,
            B * GLINT_SIZE * glint.scale * (GLINT_MIN + GLINT_GROW * shine))
        t:SetRotation(glint.angle + glint.spin * age)
        Paint(t, fx, a * shine)
    end
end

function DRAW.ring(fx, a, B)
    local gy = B * GROUND_Y
    Place(fx.ring, fx, 0, gy, B * RING_W, B * RING_H)
    Paint(fx.ring, fx, a)
    local rx, ry = B * RING_W / 2, B * RING_H / 2
    for c, tail in ipairs(fx.comets) do
        local head = fx.time * COMET_RATE + (c - 1) * TWO_PI / #fx.comets
        for j, t in ipairs(tail) do
            local an, fade = head - (j - 1) * COMET_GAP, 1 - (j - 1) / #tail
            Place(t, fx, cos(an) * rx, gy + sin(an) * ry, B * COMET_SIZE * fade * COMET_HAZE)
            Paint(t, fx, a * fade)
        end
    end
end

function DRAW.beam(fx, a, B)
    local base = B * GROUND_Y
    fx.beam:ClearAllPoints()
    fx.beam:SetPoint("BOTTOM", fx, "CENTER", 0, base)
    fx.beam:SetSize(B * BEAM_W, B * BEAM_H)
    Paint(fx.beam, fx, a * BEAM_ALPHA)
    for i, t in ipairs(fx.risers) do
        local phase = (fx.time * RISER_RATE + i / #fx.risers) % 1
        Place(t, fx, (t.lane - 0.5) * B * RISER_SPREAD, base + phase * B * RISER_HEIGHT,
            B * RISER_SIZE * sin(pi * phase))
        t:SetVertexColor(1, 1, 1, a * sin(pi * phase))
    end
end

function DRAW.brackets(fx, a, B)
    local far = 1 - fx.lock
    local h = B * (BRACKET_NEAR + (BRACKET_FAR - BRACKET_NEAR) * far
        + far * BRACKET_BREATH * sin(fx.time * BRACKET_RATE))
    for i, t in ipairs(fx.brackets) do
        local c = CORNERS[i]
        Place(t, fx, c[1] * h, c[2] * h * BRACKET_SQUASH, B * BRACKET_SIZE)
        t:SetTexCoord(c[3], c[4], c[5], c[6])
        Paint(t, fx, a)
    end
end

local PARTS = {
    glow = { "glow", "core" }, sparkles = { "glow", "glints" }, ring = { "ring", "comets" },
    beam = { "beam", "risers" }, brackets = { "brackets" },
}

local function ShowParts(fx, style)
    for _, list in pairs(fx.parts) do
        for _, t in ipairs(list) do t:Hide() end
    end
    for _, key in ipairs(PARTS[style]) do
        for _, t in ipairs(fx.parts[key]) do t:Show() end
    end
end

local function Step(fx, elapsed)
    elapsed = min(elapsed, St.MAX_STEP)
    local slow = fx.locked and St.LOCKED_SPEED or 1
    fx.time = fx.time + elapsed * slow
    fx.appear = Approach(fx.appear, 1, elapsed / St.FADE)
    fx.lock = Approach(fx.lock, fx.ready and 1 or 0, elapsed / St.BLEND)
    local a = fx.appear * fx.alpha * (St.FAR_ALPHA + (1 - St.FAR_ALPHA) * fx.lock)
    if fx.locked then a = a * St.LOCKED_ALPHA end
    local B = St.BASE * fx.size
    DRAW[fx.style](fx, a, B, elapsed * slow)
    if fx.burstAge then
        fx.burstAge = fx.burstAge + elapsed
        local k = fx.burstAge / St.BURST_TIME
        if k >= 1 then
            fx.burstAge = nil
            fx.burst:Hide()
        else
            Place(fx.burst, fx, 0, 0, B * (BURST_FROM + k * BURST_GROW))
            fx.burst:SetVertexColor(1, 1, 1, (1 - k) * fx.alpha)
            fx.burst:Show()
        end
    end
end

function Effects.New(parent)
    local fx = CreateFrame("Frame", nil, parent)
    fx:SetSize(1, 1)
    fx.time, fx.appear, fx.lock, fx.alpha, fx.size = 0, 0, 0, 1, 1
    fx.r, fx.g, fx.b = 1, 1, 1
    fx.style = "sparkles"
    fx.glow = Tex(fx, "glow", "BACKGROUND")
    fx.core = Tex(fx, "glow", "ARTWORK")
    fx.ring = Tex(fx, "ring", "BORDER")
    fx.beam = Tex(fx, "beam", "BORDER")
    fx.burst = Tex(fx, "ring", "OVERLAY")
    fx.glints, fx.comets, fx.risers, fx.brackets = {}, {}, {}, {}
    local glintTex, cometTex = {}, {}
    for i = 1, St.GLINTS do
        local g = { tex = Tex(fx, "flare", "OVERLAY") }
        Respawn(g)
        fx.glints[i], glintTex[i] = g, g.tex
    end
    for c = 1, St.COMETS do
        fx.comets[c] = {}
        for j = 1, St.TAIL do
            local t = Tex(fx, "glow", "ARTWORK")
            fx.comets[c][j] = t
            cometTex[#cometTex + 1] = t
        end
    end
    for i = 1, St.RISERS do
        local t = Tex(fx, "flare", "OVERLAY")
        t.lane = i / (St.RISERS + 1)
        fx.risers[i] = t
    end
    for i = 1, #CORNERS do fx.brackets[i] = Tex(fx, "bracket", "ARTWORK") end
    fx.parts = {
        glow = { fx.glow }, core = { fx.core }, ring = { fx.ring }, beam = { fx.beam },
        glints = glintTex, comets = cometTex, risers = fx.risers, brackets = fx.brackets,
    }
    fx:SetScript("OnUpdate", Step)
    return fx
end

function Effects.Set(fx, style, color, alpha, size, ready, locked)
    if fx.style ~= style then
        fx.style = style
        fx.styled = false
    end
    if not fx.styled then
        ShowParts(fx, style)
        fx.styled = true
    end
    if locked then color = St.LOCKED_RGB end
    fx.r, fx.g, fx.b = color.r, color.g, color.b
    fx.alpha, fx.size = alpha, size
    if ready and fx.ready == false and not locked then Effects.Burst(fx) end
    fx.ready, fx.locked = ready and true or false, locked and true or false
end

function Effects.Start(fx)
    fx.appear, fx.burstAge = 0, nil
    fx.lock = fx.ready and 1 or 0
    fx.burst:Hide()
    for _, glint in ipairs(fx.glints) do Respawn(glint) end
end

function Effects.Mask(fx, mask)
    if fx.mask == mask then return end
    for _, list in pairs(fx.parts) do
        for _, t in ipairs(list) do
            if fx.mask then t:RemoveMaskTexture(fx.mask) end
            if mask then t:AddMaskTexture(mask) end
        end
    end
    if fx.mask then fx.burst:RemoveMaskTexture(fx.mask) end
    if mask then fx.burst:AddMaskTexture(mask) end
    fx.mask = mask
end

function Effects.Burst(fx)
    fx.burstAge = 0
    for _, glint in ipairs(fx.glints) do Respawn(glint, true) end
end
