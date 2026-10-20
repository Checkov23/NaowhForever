-- LinkView.lua: another player's profession opened from a trade link in chat, and when that view ends.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings

local SMELTING = 2656
local RETRY_AFTER = 0.5
local SETTLE = 1
local SETTLE_MARGIN = 0.05
local TRADE_LINK_GUID = "^trade:(Player%-%d+%-%x+):"

local viewingLink, linkClicked, linkGUID
local retrying
local casts = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and not ns.GamepadStandDown()
end

local function Queue()
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

local function Settled()
    return viewingLink and GetTime() - linkClicked > SETTLE
end

local function StopLinkView()
    viewingLink = nil
    casts:UnregisterAllEvents()
end

local function EndLinkView()
    if not viewingLink then return end
    if Settled() then return StopLinkView() end
    local clicked = linkClicked
    C_Timer.After(SETTLE - (GetTime() - clicked) + SETTLE_MARGIN, function()
        if viewingLink and linkClicked == clicked and not ProfessionsFrame:IsShown() then StopLinkView() end
    end)
end

local function OwnProfessionSpell(spellID)
    local name = C_Spell.GetSpellName(spellID)
    if not name then return false end
    for _, index in pairs({ GetProfessions() }) do
        if GetProfessionInfo(index) == name then return true end
    end
    return spellID == SMELTING
end

local function OnCast(_, _, _, _, spellID)
    if Settled() and OwnProfessionSpell(spellID) then
        StopLinkView()
        Queue()
    end
end

local function OnItemRef(link, text, button, chatFrame)
    if not On() or IsShiftKeyDown() or IsControlKeyDown() then return end
    local guid = type(link) == "string" and link:match(TRADE_LINK_GUID)
    if not guid or guid == UnitGUID("player") then return end
    viewingLink, linkClicked, linkGUID = true, GetTime(), guid
    casts:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    Queue()
    if retrying then return end
    C_Timer.After(RETRY_AFTER, function()
        if not viewingLink or C_TradeSkillUI.IsTradeSkillLinked() then return end
        retrying = true
        SetItemRef(link, text, button, chatFrame)
        retrying = nil
    end)
end

local Links = {}
P.Links = Links

function Links.Viewing()
    return viewingLink
end

function Links.GUID()
    return linkGUID
end

Links.End = EndLinkView

casts:SetScript("OnEvent", OnCast)
hooksecurefunc("SetItemRef", OnItemRef)
