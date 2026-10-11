-- KeyBinding.lua: binds Shift-L to the Quest List once per character, if nothing else has it.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings

local ACTION, DEFAULT_KEY = "NAOWHFOREVER_COMPLETO", "SHIFT-L"
local KEY_SET_STORE = "completoKeySet"
local TEXT_BOUND = ns.L("Shift-L now opens the Quest List. Change it under Discovery > Quest List or Key Bindings.")
local TEXT_TAKEN = ns.L("Shift-L is already %s, so the Quest List has no key. Pick one under Discovery > Quest List.")

local function FirstTime()
    local account = ns.AccountSettings()
    account[KEY_SET_STORE] = account[KEY_SET_STORE] or {}
    local char = Completo.CharKey()
    if account[KEY_SET_STORE][char] then return false end
    account[KEY_SET_STORE][char] = true
    return true
end

local function DefaultKey()
    if not S.Get("enabled") or InCombatLockdown() then return end
    if not FirstTime() or GetBindingKey(ACTION) then return end
    local taken = GetBindingAction(DEFAULT_KEY)
    if taken ~= "" then
        ns.Print(TEXT_TAKEN:format(GetBindingName(taken)))
        return
    end
    SetBinding(DEFAULT_KEY, ACTION)
    SaveBindings(GetCurrentBindingSet())
    ns.Print(TEXT_BOUND)
end

local function OnSet(key)
    if key == "enabled" then DefaultKey() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    DefaultKey()
end

hooksecurefunc(S, "Set", OnSet)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
