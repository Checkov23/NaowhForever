-- HDR.lua: the HDR card, the game's HDR and peak brightness, which its own options do not show.
local ns = _G.NaowhForever

local UI = ns.UI
local S = ns.QoLSettings

local HDR, HDR_PEAK, HDR_PEAK_ON = "HDRFactor", "HDRPeakBrightness", "useHDRPeakBrightness"
local HDR_PEAK_DEFAULT = 1000
local HDR_PEAK_RANGE = { 100, 2000, 10 }

local TEXT_COMBAT = ns.L("Game settings can only be changed out of combat.")
local TEXT_HDR_OFF = ns.L("Turn on HDR")
local TEXT_HDR_SETTINGS_OFF = ns.L("Needs %s", ns.L("HDR Settings"))

local function CanChange()
    if InCombatLockdown() then
        ns.Print(TEXT_COMBAT)
        return false
    end
    return true
end

local function HDROn()
    return (tonumber(C_CVar.GetCVar(HDR)) or 0) > 0
end

local function HDRSet(on)
    if CanChange() then C_CVar.SetCVar(HDR, on and "1" or "0") end
    UI:RefreshPage(true)
end

local function PeakOn()
    return S.Get("hdr") and HDROn()
end

local function PeakWhy()
    return S.Get("hdr") and TEXT_HDR_OFF or TEXT_HDR_SETTINGS_OFF
end

local function PeakGet()
    return tonumber(C_CVar.GetCVar(HDR_PEAK)) or HDR_PEAK_DEFAULT
end

local function PeakSet(v)
    if not CanChange() then return UI:RefreshPage(true) end
    C_CVar.SetCVar(HDR_PEAK_ON, "1")
    C_CVar.SetCVar(HDR_PEAK, v)
end

if C_CVar.GetCVar(HDR) == nil then return end

ns.Shared.Settings.Page("QoL/Interface", S):Card({
    id = "hdr", name = "HDR", order = 70,
    help = "The game's HDR and peak brightness, which its own options do not show.",
    rows = {
        { key = "hdr", label = "HDR Settings", toggle = true,
          help = "Lets this page change the game's HDR and peak brightness." },
        { label = "HDR", toggle = true, get = HDROn, set = HDRSet, needs = "hdr",
          help = "High dynamic range, for an HDR monitor with HDR on in Windows." },
        { label = "Peak Brightness", slider = HDR_PEAK_RANGE, unit = " nits", get = PeakGet, set = PeakSet,
          needs = PeakOn, why = PeakWhy,
          help = "Your monitor's peak brightness in nits, so the brightest parts are not clipped or dimmed." },
    },
})
