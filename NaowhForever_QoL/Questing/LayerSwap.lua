-- LayerSwap.lua: Auto-Accept Layer Swap, confirming the layer swap prompt the game shows when you join a group.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local events = CreateFrame("Frame")
local hooked

local function On()
    return S.Get("enabled") and S.Get("layerSwap") and not ns.GamepadStandDown()
end

local function Accept()
    local prompt = _G.ShardTransferImminentFrame
    if not (On() and IsInGroup() and prompt and prompt:IsShown()) then return end
    local wasUp = StaticPopup1:IsShown()
    prompt:Click("LeftButton", true)
    if not wasUp and StaticPopup1:IsShown() then StaticPopup1Button1:Click() end
end

local function Hook()
    local prompt = _G.ShardTransferImminentFrame
    if hooked or not prompt then return end
    prompt:HookScript("OnShow", Accept)
    hooked = true
end

local function Joined()
    Hook()
    Accept()
end

local function Apply()
    if not On() then
        events:UnregisterAllEvents()
        return
    end
    events:RegisterEvent("GROUP_JOINED")
    Hook()
end

events:SetScript("OnEvent", Joined)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "layerSwap" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/Questing & Group", S):Card({
    id = "layerSwap", name = "Auto-Accept Layer Swap", order = 26, switch = "layerSwap", switchWhy = ns.GamepadWhy,
    help = "Accepts the layer swap prompt when you join a group.",
})
