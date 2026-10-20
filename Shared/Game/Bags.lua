-- Bags.lua: the item buttons in your bags, the game's, EllesmereUI's and Baganator's, for the marks modules paint on them (ns.Shared.Bags).
local ns = _G.NaowhForever

local ELLESMERE_ADDON = "EllesmereUIBags"
local ELLESMERE_WINDOWS = { "EUI_Bags", "EUI_BagsReagent" }
local BAGANATOR_ADDON = "Baganator"
local UPDATE_METHOD = "UpdateItems"

local frames = {}
local painters = {}

local function Painted(frame)
    for i = 1, #painters do painters[i](frame) end
end

local function HookGameBags()
    local list = ContainerFrameContainer and ContainerFrameContainer.ContainerFrames
    for i = 1, list and #list or 0 do frames[#frames + 1] = list[i] end
    frames[#frames + 1] = ContainerFrameCombinedBags
    for _, frame in ipairs(frames) do
        if frame[UPDATE_METHOD] then hooksecurefunc(frame, UPDATE_METHOD, Painted) end
    end
end

local Bags = {}
ns.Shared.Bags = Bags

function Bags.OnGameUpdate(painter)
    if ns.GamepadStandDown() then return end
    if #painters == 0 then HookGameBags() end
    painters[#painters + 1] = painter
end

function Bags.RepaintGame(painter)
    for _, frame in ipairs(frames) do
        if frame:IsShown() then painter(frame) end
    end
end

function Bags.Ellesmere()
    local bags = _G.EUI_Bags
    return C_AddOns.IsAddOnLoaded(ELLESMERE_ADDON) and bags and bags.RegisterItemOverlayIcon and bags or nil
end

function Bags.Baganator()
    local api = _G.Baganator and _G.Baganator.API
    return C_AddOns.IsAddOnLoaded(BAGANATOR_ADDON) and api and api.RegisterCornerWidget and api or nil
end

function Bags.RefreshEllesmere()
    for _, name in ipairs(ELLESMERE_WINDOWS) do
        local frame = _G[name]
        if frame and frame.RefreshInventory and frame:IsVisible() then frame:RefreshInventory() end
    end
end
