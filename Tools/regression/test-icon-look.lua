-- Run with Lua 5.1 from the repository root: the Low Health reminder and the Tracking reminder
-- keep today's text until Font, Font Size or Outline change it, on the real frame and the
-- card's preview alike. Frames are stubs that record what is set on them.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end
local function New()
    local f = { scripts = {}, events = {}, attrs = {} }
    return setmetatable(f, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return NOTHING end
    end })
end
local function Frame()
    local f = New()
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:CreateTexture() return New() end
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:SetAlpha(a) self.alpha = a end
    return f
end

local function Load(path, settings, extra)
    local hooks = {}
    local S = { Get = function(k) return settings[k] end }
    function S.Set(k, v)
        settings[k] = v
        for _, fn in ipairs(hooks) do fn(k) end
    end
    local fonts = {}
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"),
        AuraBuffSettings = S, ProfessionSettings = S, THEME = { accentSoft = {}, muted = {} },
        HEALTHSTONES = { 5509 }, HEALING_POTIONS = { 13446 },
        Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
        Border = NOTHING,
        Font = function()
            local fs = New()
            function fs:SetText(t) self.text = t end
            fonts[#fonts + 1] = fs
            return fs
        end,
        UI = { AttachMover = function() return Frame() end, ModuleSettings = function() return S end },
        Shared = { Parts = { HudFont = function(fs, font, size, outline)
            fs.font, fs.size, fs.outline = font, size, outline
        end } },
    }
    local frames = {}
    local env = setmetatable({
        NaowhForever = ns, UIParent = {},
        CreateFrame = function() local f = Frame(); frames[#frames + 1] = f; return f end,
        hooksecurefunc = function(t, _, fn) if t == S then hooks[#hooks + 1] = fn end end,
        InCombatLockdown = function() return false end,
        UnitIsDeadOrGhost = function() return false end, UnitOnTaxi = function() return false end,
        IsInInstance = function() return false end,
        UnitHealthPercent = function() return 1 end, issecretvalue = function() return false end,
        LibStub = function() return nil end,
        C_CurveUtil = { CreateCurve = function() return New() end },
        Enum = { LuaCurveType = { Step = 1 } },
        C_Item = { GetItemCount = function() return 0 end, GetItemIconByID = function(id) return id end },
        C_Spell = { GetSpellTexture = function(id) return id end, GetSpellName = function() return "Find" end },
        C_SpellBook = { IsSpellKnown = function() return true end },
        C_Minimap = { GetNumTrackingTypes = function() return 0 end },
        GameTooltip_Hide = NOTHING,
    }, { __index = _G })
    env._G = env
    for k, v in pairs(extra or {}) do env[k] = v end
    for _, file in ipairs(type(path) == "table" and path or { path }) do
        local chunk = assert(loadfile(file))
        setfenv(chunk, env)
        chunk()
    end
    for _, f in ipairs(frames) do
        if f.scripts.OnEvent and f.events.PLAYER_LOGIN then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
    end
    return S, fonts, frames
end

local function Find(fonts, text)
    for _, fs in ipairs(fonts) do
        if fs.text and tostring(fs.text):find(text, 1, true) then return fs end
    end
end

-- Low Health: LOW HEALTH at 16 and the count at 14, both outlined.
do
    local settings = { enabled = true, lowHealth = true, lowHealthBelow = 35, lowHealthItem = "auto",
        lowHealthIconSize = 48, lowHealthGlow = false, lowHealthSound = false,
        lowHealthFont = "", lowHealthFontSize = 16, lowHealthOutline = "OUTLINE" }
    local S, fonts = Load({ "Core/Features.lua", "NaowhForever_Combat/AuraBuffs/AuraBuffs.lua",
        "NaowhForever_Combat/AuraBuffs/Constants.lua", "NaowhForever_Combat/AuraBuffs/LowHealth.lua", "NaowhForever_Combat/AuraBuffs/View/Style.lua",
        "NaowhForever_Combat/AuraBuffs/View/Glow.lua", "NaowhForever_Combat/AuraBuffs/View/LowHealthLook.lua",
        "NaowhForever_Combat/AuraBuffs/UI/GlowRows.lua", "NaowhForever_Combat/AuraBuffs/UI/LowHealth.lua",
        "NaowhForever_Combat/AuraBuffs/UI/LowHealthCard.lua" }, settings)
    local label, count = Find(fonts, "LOW HEALTH"), fonts[1]
    check("Low Health: the warning as today", label.font == "" and label.size == 16 and label.outline == "OUTLINE")
    check("Low Health: the count as today", count ~= label and count.size == 14 and count.outline == "OUTLINE")
    S.Set("lowHealthFont", "Naowh")
    S.Set("lowHealthFontSize", 20)
    S.Set("lowHealthOutline", "")
    check("Low Health: Font Size is the warning's", label.font == "Naowh" and label.size == 20 and label.outline == "")
    check("Low Health: the count follows the font and outline, not the size", count.font == "Naowh"
        and count.size == 14 and count.outline == "")
end

-- Low Health: the glow starts once while health stays low, and again only when its look changes.
do
    local reads = 0
    local settings = setmetatable({ enabled = true, lowHealth = true, lowHealthBelow = 35, lowHealthItem = "auto",
        lowHealthIconSize = 48, lowHealthGlow = true, lowHealthSound = false,
        lowHealthGlowColor = { r = 1, g = 0.25, b = 0.25 }, lowHealthGlowLines = 8, lowHealthGlowThickness = 2,
        lowHealthGlowSpeed = 5, lowHealthFont = "", lowHealthFontSize = 16, lowHealthOutline = "OUTLINE" },
        { __index = function(_, k) if k == "lowHealthGlowType" then reads = reads + 1; return "pixel" end end })
    local starts, stops = 0, 0
    local LCG = { PixelGlow_Start = function() starts = starts + 1 end, PixelGlow_Stop = function() stops = stops + 1 end }
    local S, _, frames = Load({ "Core/Features.lua", "NaowhForever_Combat/AuraBuffs/AuraBuffs.lua",
        "NaowhForever_Combat/AuraBuffs/Constants.lua", "NaowhForever_Combat/AuraBuffs/LowHealth.lua", "NaowhForever_Combat/AuraBuffs/View/Style.lua",
        "NaowhForever_Combat/AuraBuffs/View/Glow.lua", "NaowhForever_Combat/AuraBuffs/View/LowHealthLook.lua",
        "NaowhForever_Combat/AuraBuffs/UI/GlowRows.lua", "NaowhForever_Combat/AuraBuffs/UI/LowHealth.lua" }, settings,
        { LibStub = function() return LCG end, UnitHealthPercent = function() return 0.2 end,
          C_Item = { GetItemCount = function() return 1 end, GetItemIconByID = function(id) return id end } })
    local events
    for _, f in ipairs(frames) do
        if f.events.UNIT_HEALTH then events = f end
    end
    check("Low Health: low at login, the glow starts", starts == 1)
    local before = reads
    for _ = 1, 5 do events.scripts.OnEvent(events, "UNIT_HEALTH") end
    check("Low Health: health events while low leave the glow alone", starts == 1 and stops == 0 and reads == before)
    S.Set("lowHealthGlowLines", 6)
    check("Low Health: a new glow look restarts it", starts == 2 and stops == 1)
end

-- Low Health with no healing item: hidden, without its glow, unless Show When Out is on.
do
    local settings = { enabled = true, lowHealth = true, lowHealthBelow = 35, lowHealthItem = "auto",
        lowHealthShowEmpty = false, lowHealthIconSize = 48, lowHealthGlow = true, lowHealthSound = false,
        lowHealthGlowType = "pixel", lowHealthGlowColor = { r = 1, g = 0.25, b = 0.25 }, lowHealthGlowLines = 8,
        lowHealthGlowThickness = 2, lowHealthGlowSpeed = 5, lowHealthFont = "", lowHealthFontSize = 16,
        lowHealthOutline = "OUTLINE" }
    local carried, starts, stops = 0, 0, 0
    local LCG = { PixelGlow_Start = function() starts = starts + 1 end, PixelGlow_Stop = function() stops = stops + 1 end }
    local S, _, frames = Load({ "Core/Features.lua", "NaowhForever_Combat/AuraBuffs/AuraBuffs.lua",
        "NaowhForever_Combat/AuraBuffs/Constants.lua", "NaowhForever_Combat/AuraBuffs/LowHealth.lua", "NaowhForever_Combat/AuraBuffs/View/Style.lua",
        "NaowhForever_Combat/AuraBuffs/View/Glow.lua", "NaowhForever_Combat/AuraBuffs/View/LowHealthLook.lua",
        "NaowhForever_Combat/AuraBuffs/UI/GlowRows.lua", "NaowhForever_Combat/AuraBuffs/UI/LowHealth.lua" }, settings,
        { LibStub = function() return LCG end, UnitHealthPercent = function() return 0.2 end,
          C_Item = { GetItemCount = function() return carried end, GetItemIconByID = function(id) return id end } })
    local events, icon
    for _, f in ipairs(frames) do
        if f.events.UNIT_HEALTH then events = f elseif f.alpha then icon = f end
    end
    check("Low Health: low with empty bags, hidden by default", icon.alpha == 0 and starts == 0)
    events.scripts.OnEvent(events, "UNIT_HEALTH")
    check("Low Health: health events keep it hidden", icon.alpha == 0 and starts == 0)
    carried = 1
    events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
    check("Low Health: a healing item looted while low shows it", icon.alpha == 0.2 and starts == 1)
    carried = 0
    events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
    check("Low Health: the last one used hides it again", icon.alpha == 0 and stops == 1)
    S.Set("lowHealthShowEmpty", true)
    check("Low Health: Show When Out shows it with nothing in bags", icon.alpha == 0.2 and starts == 2)
end

-- Tracking: its Track line at 13, outlined.
do
    local settings = { enabled = true, gatherReminder = true, gatherInInstances = false, gatherIconSize = 40,
        gatherFish = false, gatherFont = "", gatherFontSize = 13, gatherOutline = "OUTLINE" }
    local S, fonts = Load({ "Core/Features.lua", "NaowhForever_Professions/Professions.lua",
        "NaowhForever_Professions/Constants.lua", "NaowhForever_Professions/View/Style.lua",
        "NaowhForever_Professions/UI/GatherTracking.lua" }, settings)
    local label = Find(fonts, "Track ")
    check("Tracking: the line as today", label and label.font == "" and label.size == 13
        and label.outline == "OUTLINE")
    S.Set("gatherFont", "Naowh")
    S.Set("gatherFontSize", 16)
    S.Set("gatherOutline", "THICKOUTLINE")
    check("Tracking: Font, Font Size and Outline apply", label.font == "Naowh" and label.size == 16
        and label.outline == "THICKOUTLINE")
end

print(("test-icon-look: %d checks passed"):format(checks))
