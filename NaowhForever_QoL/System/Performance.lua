-- Performance.lua: the QoL Performance page, NaowhQOL's recommended game settings.
local ns = _G.NaowhForever
local UI = ns.UI
local Group = ns.Shared.Settings.Group

local SAME_WITHIN = 0.001
local SPELL_QUEUE = "SpellQueueWindow"
local SPELL_QUEUE_MAX = 400
local SPELL_QUEUE_RANGE = { 0, SPELL_QUEUE_MAX, 1 }

local TEXT_COMBAT = ns.L("Game settings can only be changed out of combat.")
local TEXT_RELOAD = ns.L("Some settings only take effect after a reload. Reload UI now?")
local TEXT_APPLIED_ONE = ns.L("Applied %d recommended setting. Restore All puts yours back.")
local TEXT_APPLIED = ns.L("Applied %d recommended settings. Restore All puts yours back.")
local TEXT_RESTORED_ONE, TEXT_RESTORED = ns.L("Restored %d setting."), ns.L("Restored %d settings.")
local TEXT_NOTHING_BACK = ns.L(" was already at this value before, so there is nothing to put back.")
local TEXT_RESTORE_ALL = ns.L("Put back every setting this page has changed?")
local TEXT_ROW_HELP = ns.L("Recommended: %s.|n|nOn sets it; off puts back the value you had before. Now: %s.")
local TEXT_SUMMARY = ns.L("%d of %d recommended settings in use")

local CATEGORIES = {
    { name = "Render & Display", cvars = {
        { "renderScale", "1", ns.L("Render Scale"), ns.L("100%, native resolution") },
        { "VSync", "0", "VSync", ns.L("Off, for the highest frame rate") },
        { "MSAAQuality", "0", "Multisampling", ns.L("None") },
        { "LowLatencyMode", "3", ns.L("Low Latency Mode"), "Reflex + Boost" },
        { "ffxAntiAliasingMode", "4", "Anti-Aliasing", ns.L("Advanced (CMAA2)") },
    } },
    { name = "Graphics Quality", cvars = {
        { "graphicsShadowQuality", "1", ns.L("Shadow Quality"), ns.L("Fair") },
        { "graphicsLiquidDetail", "2", ns.L("Liquid Detail"), ns.L("Good") },
        { "graphicsParticleDensity", "3", ns.L("Particle Density"), ns.L("Good") },
        { "graphicsSSAO", "0", "SSAO", ns.L("Off") },
        { "graphicsDepthEffects", "0", ns.L("Depth Effects"), ns.L("Off") },
        { "graphicsComputeEffects", "0", ns.L("Compute Effects"), ns.L("Off") },
        { "graphicsOutlineMode", "2", ns.L("Outline Mode"), ns.L("High") },
        { "graphicsTextureResolution", "2", ns.L("Texture Resolution"), ns.L("High") },
        { "graphicsSpellDensity", "0", ns.L("Spell Density"), ns.L("Essential") },
        { "graphicsProjectedTextures", "1", ns.L("Projected Textures"), ns.L("On") },
    } },
    { name = "View Distance & Detail", cvars = {
        { "graphicsViewDistance", "3", ns.L("View Distance"), ns.L("Level 4") },
        { "graphicsEnvironmentDetail", "3", ns.L("Environment Detail"), ns.L("Level 4") },
        { "graphicsGroundClutter", "0", ns.L("Ground Clutter"), ns.L("Level 1") },
    } },
    { name = "Raid Graphics", cvars = {
        { "RAIDsettingsEnabled", "1", ns.L("Separate Raid Settings"), ns.L("On") },
        { "raidGraphicsShadowQuality", "0", ns.L("Raid Shadow Quality"), ns.L("Low") },
        { "raidGraphicsLiquidDetail", "0", ns.L("Raid Liquid Detail"), ns.L("Low") },
        { "raidGraphicsParticleDensity", "3", ns.L("Raid Particle Density"), ns.L("Good") },
        { "raidGraphicsSSAO", "0", ns.L("Raid SSAO"), ns.L("Off") },
        { "raidGraphicsDepthEffects", "0", ns.L("Raid Depth Effects"), ns.L("Off") },
        { "raidGraphicsComputeEffects", "0", ns.L("Raid Compute Effects"), ns.L("Off") },
        { "raidGraphicsOutlineMode", "2", ns.L("Raid Outline Mode"), ns.L("High") },
        { "raidGraphicsTextureResolution", "2", ns.L("Raid Texture Resolution"), ns.L("High") },
        { "raidGraphicsSpellDensity", "0", ns.L("Raid Spell Density"), ns.L("Essential") },
        { "raidGraphicsProjectedTextures", "1", ns.L("Raid Projected Textures"), ns.L("On") },
        { "raidGraphicsViewDistance", "0", ns.L("Raid View Distance"), ns.L("Level 1") },
        { "raidGraphicsEnvironmentDetail", "0", ns.L("Raid Environment Detail"), ns.L("Level 1") },
        { "raidGraphicsGroundClutter", "0", ns.L("Raid Ground Clutter"), ns.L("Level 1") },
    } },
    { name = "Advanced", cvars = {
        { "GxMaxFrameLatency", "2", ns.L("Triple Buffering"), ns.L("Off") },
        { "TextureFilteringMode", "5", ns.L("Texture Filtering"), ns.L("16x Anisotropic") },
        { "shadowRt", "0", ns.L("Ray Traced Shadows"), ns.L("Off") },
        { "ResampleQuality", "3", ns.L("Resample Quality"), "FidelityFX SR 1.0" },
        { "GxApi", "D3D12", ns.L("Graphics API"), ns.L("DirectX 12, after a game restart") },
        { "physicsLevel", "1", ns.L("Physics Integration"), ns.L("Player Only") },
    } },
    { name = "Frame Rate Limits", cvars = {
        { "useMaxFPS", "1", ns.L("Frame Rate Cap"), ns.L("On") },
        { "maxFPS", "200", ns.L("Max Frame Rate"), "200" },
        { "useTargetFPS", "0", ns.L("Target Frame Rate"), ns.L("Off") },
        { "useMaxFPSBk", "1", ns.L("Background Frame Rate Cap"), ns.L("On") },
        { "maxFPSBk", "30", ns.L("Background Frame Rate"), ns.L("30, while the game is not in focus") },
        { "maxFPSLoading", "30", ns.L("Loading Screen Frame Rate"), "30" },
    } },
    { name = "Post Processing & Effects", cvars = {
        { "ResampleSharpness", "0", ns.L("Resample Sharpness"), "0, neutral" },
        { "ResampleAlwaysSharpen", "1", ns.L("Always Sharpen"), ns.L("On") },
        { "cameraShake", "0", ns.L("Camera Shake"), ns.L("Off") },
        { "ffxDeath", "0", ns.L("Death Effect"), ns.L("Off") },
        { "ffxGlow", "0", ns.L("Glow Effect"), ns.L("Off") },
        { "overrideScreenFlash", "1", ns.L("Override Screen Flash"), ns.L("On") },
        { "ShakeStrengthCamera", "0", ns.L("Camera Shake Strength"), ns.L("Off") },
        { "ShakeStrengthUI", "0", ns.L("UI Shake Strength"), ns.L("Off") },
    } },
    { name = "Network, Logging & Interface", cvars = {
        { "advancedCombatLogging", "1", ns.L("Advanced Combat Logging"), ns.L("On") },
        { "disableServerNagle", "1", ns.L("Disable Server Nagle"), ns.L("On, for lower latency") },
        { "AutoPushSpellToActionBar", "0", ns.L("Auto Push Spells to Bars"), ns.L("Off") },
        { "cameraDistanceMaxZoomFactor", "2.6", ns.L("Max Camera Zoom"), "2.6x" },
        { "nameplateShowFriendlyClassColor", "1", ns.L("Friendly Class Colors"), ns.L("On") },
        { "UnitNameFriendlyPlayerName", "1", ns.L("Friendly Player Names"), ns.L("On") },
    } },
}

local cvarRows, rows = {}, {}

local function Backups()
    local account = ns.AccountSettings()
    account.cvarBackups = account.cvarBackups or {}
    return account.cvarBackups
end

local function Exists(cvar)
    return C_CVar.GetCVar(cvar) ~= nil
end

local function AtValue(cvar, value)
    local current = C_CVar.GetCVar(cvar)
    local a, b = tonumber(current), tonumber(value)
    if a and b then return math.abs(a - b) < SAME_WITHIN end
    return current == value
end

local function CanChange()
    if InCombatLockdown() then
        ns.Print(TEXT_COMBAT)
        return false
    end
    return true
end

local function SetRecommended(cvar, value)
    if AtValue(cvar, value) then return false end
    local backups = Backups()
    if backups[cvar] == nil then backups[cvar] = C_CVar.GetCVar(cvar) end
    return C_CVar.SetCVar(cvar, value)
end

local function Restore(cvar)
    local backups = Backups()
    if backups[cvar] == nil then return false end
    C_CVar.SetCVar(cvar, backups[cvar])
    backups[cvar] = nil
    return true
end

local function OfferReload()
    ns.ConfirmReload(TEXT_RELOAD)
end

local function ApplyAll()
    if not CanChange() then return end
    local count = 0
    for _, cat in ipairs(CATEGORIES) do
        for _, c in ipairs(cat.cvars) do
            if Exists(c[1]) and SetRecommended(c[1], c[2]) then count = count + 1 end
        end
    end
    ns.Print((count == 1 and TEXT_APPLIED_ONE or TEXT_APPLIED):format(count))
    UI:RefreshPage(true)
    if count > 0 then OfferReload() end
end

local function RestoreAll()
    if not CanChange() then return end
    local count = 0
    for cvar in pairs(Backups()) do
        if Restore(cvar) then count = count + 1 end
    end
    ns.Print((count == 1 and TEXT_RESTORED_ONE or TEXT_RESTORED):format(count))
    UI:RefreshPage(true)
    if count > 0 then OfferReload() end
end

local function SetOne(cvar, value, name, on)
    if not CanChange() then
        UI:RefreshPage(true)
        return
    end
    if on then
        SetRecommended(cvar, value)
    elseif not Restore(cvar) then
        ns.Print(name .. TEXT_NOTHING_BACK)
    end
    UI:RefreshPage(true)
end

local function SpellQueueGet()
    return tonumber(C_CVar.GetCVar(SPELL_QUEUE)) or SPELL_QUEUE_MAX
end

local function SpellQueueSet(v)
    C_CVar.SetCVar(SPELL_QUEUE, v)
end

local function ConfirmRestoreAll()
    ns.Confirm(TEXT_RESTORE_ALL, RestoreAll)
end

local HEAD = {
    Group("Recommended"),
    { label = "Apply All Recommended", buttonText = "Apply All", button = ApplyAll,
      help = "Sets every recommended setting below. Your own value is saved first, so Restore All can put "
          .. "it back." },
    { label = "Restore All", buttonText = "Restore All", button = ConfirmRestoreAll,
      help = "Puts back every setting this page has changed, to the value you had before." },
    Group("Spell Queue"),
    { label = "Spell Queue Window", slider = SPELL_QUEUE_RANGE, unit = "ms", get = SpellQueueGet, set = SpellQueueSet,
      help = "How early you can press your next spell before the current one finishes, in milliseconds. "
          .. "100 to 400 suits most: lower is more responsive, higher is more forgiving of latency. Melee "
          .. "around your ping + 100, ranged around your ping + 150." },
    { label = "Reload UI", buttonText = "Reload UI", button = OfferReload,
      help = "Some settings only take effect after a reload." },
}
for _, cat in ipairs(CATEGORIES) do cat.group = Group(cat.name) end

local function CVarRow(c)
    local row = cvarRows[c]
    if not row then
        local cvar, value, name = c[1], c[2], c[3]
        row = { label = name, toggle = true,
            get = function() return AtValue(cvar, value) end,
            set = function(on) SetOne(cvar, value, name, on) end }
        cvarRows[c] = row
    end
    row.help = TEXT_ROW_HELP:format(c[4], tostring(C_CVar.GetCVar(c[1])))
    return row
end

local function Rows()
    wipe(rows)
    for i = 1, #HEAD do rows[i] = HEAD[i] end
    for _, cat in ipairs(CATEGORIES) do
        local grouped = false
        for _, c in ipairs(cat.cvars) do
            if Exists(c[1]) then
                if not grouped then
                    rows[#rows + 1] = cat.group
                    grouped = true
                end
                rows[#rows + 1] = CVarRow(c)
            end
        end
    end
    return rows
end

local function Summary()
    local on, total = 0, 0
    for _, cat in ipairs(CATEGORIES) do
        for _, c in ipairs(cat.cvars) do
            if Exists(c[1]) then
                total = total + 1
                if AtValue(c[1], c[2]) then on = on + 1 end
            end
        end
    end
    return TEXT_SUMMARY:format(on, total)
end

ns.Shared.Settings.Page("QoL/System", ns.QoLSettings):Card({
    id = "performance", name = "Performance", order = 10,
    help = "NaowhQOL's recommended graphics, frame rate and network settings for a high, steady frame rate. "
        .. "Your own value is saved the first time each one changes, on this computer, and Restore All or "
        .. "turning a setting back off puts it back.",
    summary = Summary,
    rows = Rows,
})
