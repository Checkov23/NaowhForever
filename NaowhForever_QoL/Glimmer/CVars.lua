-- CVars.lua: the game settings Glimmer changes, saved before it changes them and put back when it stops (G.CVars).
local ns = _G.NaowhForever

local G = ns.Glimmer
local S = G.Settings
local C = G.C

local GetCVar, SetCVar = C_CVar.GetCVar, C_CVar.SetCVar

local SOFT_SAVED = "glimmerSoftCVars"
local SPARKLE_SAVED = "glimmerSparkleCVars"
local ON, OFF = "1", "0"

local CVars = {}
G.CVars = CVars

local watched = {}
for name in pairs(C.SPARKLE_RESETS) do watched[name] = true end
for name in pairs(C.SPARKLE_CVARS) do watched[name:lower()] = true end

local pending = {}
local plateOpen
local writing = false
local sparkleRun = 0
local events

local function Write(name, value)
    local current = GetCVar(name)
    if current == nil or current == value then return end
    writing = true
    SetCVar(name, value)
    writing = false
end

local function Save(slot, names)
    local account = ns.AccountSettings()
    local saved = account[slot] or {}
    for name in pairs(names) do
        if saved[name] == nil then saved[name] = GetCVar(name) end
    end
    account[slot] = saved
end

local function PutBack(slot)
    local account = ns.AccountSettings()
    local saved = account[slot]
    if not saved then return end
    for name, value in pairs(saved) do Write(name, value) end
    account[slot] = nil
end

local function SoftNames()
    local names = { [C.INTERACT_CVAR] = true, [C.RANGE_CVAR] = true, [C.ARC_CVAR] = true, [C.PLATE_CVAR] = true }
    for name in pairs(C.SOFT_CVARS) do names[name] = true end
    return names
end

local function Later(job)
    pending[job] = true
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function ApplySoft()
    if InCombatLockdown() then return Later(ApplySoft) end
    if G.On() then
        local first = ns.AccountSettings()[SOFT_SAVED] == nil
        Save(SOFT_SAVED, SoftNames())
        if first then Write(C.INTERACT_CVAR, C.INTERACT_ON) end
        for name, value in pairs(C.SOFT_CVARS) do Write(name, value) end
        Write(C.RANGE_CVAR, tostring(S.Get("range")))
        Write(C.ARC_CVAR, tostring(S.Get("arc")))
        plateOpen = nil
    else
        PutBack(SOFT_SAVED)
        plateOpen = nil
    end
end

local function ApplySparkle()
    if InCombatLockdown() then return Later(ApplySparkle) end
    if G.On() and S.Get("questSparkle") then
        Save(SPARKLE_SAVED, C.SPARKLE_CVARS)
        for name, value in pairs(C.SPARKLE_CVARS) do Write(name, value) end
        CVars.sparkleShown = true
    else
        PutBack(SPARKLE_SAVED)
    end
end

local function SparkleAgain()
    sparkleRun = sparkleRun + 1
    local run = sparkleRun
    C_Timer.After(C.SPARKLE_AGAIN, function()
        if run == sparkleRun then ApplySparkle() end
    end)
end

local function OnEvent(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" then
        events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local jobs = pending
        pending = {}
        for job in pairs(jobs) do job() end
    elseif event == "CVAR_UPDATE" then
        if writing or type(name) ~= "string" then return end
        if watched[name:lower()] then SparkleAgain() end
    end
end

local function Events()
    if events then return end
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

function CVars.Apply()
    if not G.On() and not CVars.Saved() then return end
    Events()
    ApplySoft()
    ApplySparkle()
    if G.On() and S.Get("questSparkle") then
        events:RegisterEvent("CVAR_UPDATE")
    else
        events:UnregisterEvent("CVAR_UPDATE")
    end
end

function CVars.SetPlate(open)
    if open == plateOpen or InCombatLockdown() then return end
    plateOpen = open
    Write(C.PLATE_CVAR, open and ON or OFF)
end

function CVars.InteractOn()
    return GetCVar(C.INTERACT_CVAR) == C.INTERACT_ON
end

function CVars.Saved()
    local account = ns.AccountSettings()
    return account[SOFT_SAVED] ~= nil or account[SPARKLE_SAVED] ~= nil
end

function CVars.RestoreAll()
    S.Set("questSparkle", false)
    S.Set("enabled", false)
    Events()
    if InCombatLockdown() then
        Later(function() PutBack(SOFT_SAVED); PutBack(SPARKLE_SAVED) end)
        return
    end
    PutBack(SOFT_SAVED)
    PutBack(SPARKLE_SAVED)
    plateOpen = nil
end
