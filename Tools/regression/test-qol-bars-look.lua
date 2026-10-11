-- The look options on the Co-Tank frame and the Total Craft Timer: the defaults draw today's
-- flat, outlined health bar and gradient, outlined craft bar, and Font, Font Size, Outline, Bar
-- Texture and Background Opacity each apply when changed. Run with Lua 5.1 from the repo root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Noop() end
local Widget
local methods = {
    SetScript = function(self, k, fn) self.scripts[k] = fn end,
    RegisterEvent = function(self, e) self.events[e] = true end,
    RegisterUnitEvent = function(self, e) self.events[e] = true end,
    UnregisterAllEvents = function(self) for k in pairs(self.events) do self.events[k] = nil end end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    SetShown = function(self, v) self.shown = v and true or false end,
    SetAlpha = function(self, a) self.alpha = a end,
    SetStatusBarTexture = function(self, path) self.texture = path end,
    SetColorTexture = function(self, r, g, b, a) self.color = { r, g, b, a } end,
    GetFrameLevel = function() return 1 end,
    CreateTexture = function(self) return Widget("Texture", self) end,
}
local meta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:find("^%u") then return Noop end
end }
function Widget(kind, parent)
    return setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, events = {} }, meta)
end

local function Store(defaults)
    local values = {}
    for k, v in pairs(defaults) do values[k] = v end
    return { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end }
end

local function Load(path, ns, globals)
    local frames, cards = {}, {}
    ns.UI = { AttachMover = function() return Widget("Mover") end,
        TexturePath = function(name, own) if name == "" then return own end return "lsm:" .. name end }
    ns.Shared = {
        Style = dofile("Tools/regression/shared_style.lua"),
        Parts = { HudFont = function(fs, font, size, outline) fs.font = font .. " " .. size .. " " .. outline end },
        Settings = { Group = function() return {} end, Look = function() return {} end,
            Page = function() return { Card = function(_, card) cards[#cards + 1] = card end, Window = Noop } end },
    }
    ns.THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, bg = { r = 0.05, g = 0.06, b = 0.07 }, accentSoft = {} }
    ns.Font = function(parent) return Widget("FontString", parent) end
    ns.Solid = function(parent) return Widget("Texture", parent) end
    ns.Border, ns.PixelInset = Noop, Noop
    ns.L, ns.Upper, ns.Lower = ns.L or dofile("Tools/regression/locale_stub.lua").L, string.upper, string.lower
    ns.Apply, ns.ShowUnlockMode, ns.HideUnlockMode = Noop, Noop, Noop
    ns.QoLConstants = dofile("Tools/regression/qol_constants.lua")
    ns.MEDIA = dofile("Tools/regression/core_media.lua")
    local env = { _G = { NaowhForever = ns }, UIParent = Widget("Frame"),
        CreateFrame = function(kind, _, parent)
            local w = Widget(kind, parent)
            frames[#frames + 1] = w
            return w
        end,
        hooksecurefunc = function(t, name, post)
            local orig = t[name]
            t[name] = function(...) orig(...); post(...) end
        end }
    for k, v in pairs(globals) do env[k] = v end
    setmetatable(env, { __index = _G })
    for _, file in ipairs(type(path) == "table" and path or { path }) do
        local chunk = assert(loadfile(file))
        setfenv(chunk, env)
        chunk()
    end
    return frames, cards
end

do -- Co-Tank
    local S = Store({ enabled = true, coTank = true, coTankWidth = 180, coTankHeight = 30, coTankBgAlpha = 0.6,
        coTankFont = "", coTankFontSize = 12, coTankOutline = "OUTLINE", coTankTexture = "", coTankDebuffs = false,
        coTankAnchor = "UIParent" })
    local frames = Load("NaowhForever_QoL/Combat/CoTank.lua", { QoLSettings = S }, {
        UnitClass = function() return "Warrior", "WARRIOR" end,
        InCombatLockdown = function() return false end,
        UnitGroupRolesAssigned = Noop, GetShapeshiftFormID = Noop, IsInRaid = Noop,
        GetNumSubgroupMembers = function() return 0 end,
    })
    for _, w in ipairs(frames) do
        if w.events.PLAYER_LOGIN then w.scripts.OnEvent(w, "PLAYER_LOGIN") end
    end
    local frame
    for _, w in ipairs(frames) do
        if w.kind == "Button" then frame = w end
    end
    check("co-tank default: the flat bar", frame.bar.texture == "Interface\\Buttons\\WHITE8X8")
    check("co-tank default: the outlined Addon Font at 12", frame.name.font == " 12 OUTLINE")
    check("co-tank default: the background at 60%", frame.bg.alpha == 0.6)
    S.Set("coTankTexture", "Smooth")
    S.Set("coTankFont", "Arial")
    S.Set("coTankFontSize", 16)
    S.Set("coTankOutline", "")
    S.Set("coTankBgAlpha", 0.3)
    check("co-tank: Bar Texture applies", frame.bar.texture == "lsm:Smooth")
    check("co-tank: Font, Font Size and Outline apply", frame.name.font == "Arial 16 ")
    check("co-tank: Background Opacity applies", frame.bg.alpha == 0.3)
end

do -- Total Craft Timer, drawn on its card's preview
    local S = Store({ enabled = true, craftTimer = true, craftTimerFont = "", craftTimerFontSize = 14,
        craftTimerOutline = "OUTLINE", craftTimerTexture = "", craftTimerBgAlpha = 0.9 })
    local _, cards = Load({ "NaowhForever_Professions/View/Style.lua", "NaowhForever_Professions/View/Widgets.lua",
        "NaowhForever_Professions/UI/CraftTimer.lua", "NaowhForever_Professions/UI/SettingsPage.lua" },
        { Professions = { Settings = S } }, { CreateColor = function() return {} end })
    local card
    for _, c in ipairs(cards) do
        if c.id == "craftTimer" then card = c end
    end
    local preview = card.studio.new(Widget("Frame"))
    card.studio.paint(preview, "crafting")
    check("craft timer default: the Naowh Gradient", preview.track.texture
        == "Interface\\AddOns\\NaowhForever\\Core\\Media\\NaowhGradient.tga")
    check("craft timer default: outlined labels at 14, the time at 18", preview.labels[1].font == " 14 OUTLINE"
        and preview.time.font == " 18 OUTLINE")
    check("craft timer default: the background at 90%", preview.bg.color[4] == 0.9)
    S.Set("craftTimerTexture", "Smooth")
    S.Set("craftTimerFont", "Arial")
    S.Set("craftTimerFontSize", 12)
    S.Set("craftTimerOutline", "THICKOUTLINE")
    S.Set("craftTimerBgAlpha", 0.5)
    card.studio.paint(preview, "crafting")
    check("craft timer: Bar Texture applies", preview.track.texture == "lsm:Smooth")
    check("craft timer: Font, Font Size and Outline apply", preview.labels[2].font == "Arial 12 THICKOUTLINE"
        and preview.time.font == "Arial 16 THICKOUTLINE")
    check("craft timer: Background Opacity applies", preview.bg.color[4] == 0.5)
end

print(("PASS qol bars look: %d checks"):format(checks))
