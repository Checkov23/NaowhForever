-- FactionSwitch.lua: the faction switch beside the window's search: each crest lists or hides its side's dungeons (J.FactionSwitch).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local St = J.Style
local BORDER_RGB, SEARCH_H, FACTION_ATLAS, TERRITORY_CODE = St.BORDER_RGB, St.SEARCH_H, St.FACTION_ATLAS,
    St.TERRITORY_CODE
local FACTION_W, FACTION_ICON, FACTION_OFF = St.FACTION_W, St.FACTION_ICON, St.FACTION_OFF

local SIDE_FILL = 0.15
local FILL_SUBLEVEL = 1
local HEX_BASE, BYTE = J.C.HEX_BASE, J.C.BYTE
local RED_AT, GREEN_AT, BLUE_AT = 5, 7, 9
local SIDES = { { faction = "Alliance", key = "showAlliance" }, { faction = "Horde", key = "showHorde" } }

local TEXT_CODE_END = "|r"
local TEXT_LISTED = ns.L("Listed: the dungeons on %s ground, and its battleground factions. Click to hide them.")
local TEXT_HIDDEN = ns.L("Hidden. Click to list them again.")
local TEXT_CONTESTED = ns.L("Contested dungeons are always listed.")

local function Channel(code, at)
    return tonumber(code:sub(at, at + 1), HEX_BASE) / BYTE
end

local function CodeRGB(code)
    return Channel(code, RED_AT), Channel(code, GREEN_AT), Channel(code, BLUE_AT)
end

local function PaintSide(half)
    local on = S.Get(half.side.key)
    half.icon:SetDesaturated(not on)
    half.icon:SetAlpha(on and 1 or FACTION_OFF)
    half.fill:SetShown(on)
end

local function SideEnter(half)
    local side = half.side
    local on = S.Get(side.key)
    GameTooltip:SetOwner(half, "ANCHOR_BOTTOM")
    GameTooltip:SetText(TERRITORY_CODE[side.faction] .. side.faction .. TEXT_CODE_END, 1, 1, 1)
    GameTooltip:AddLine(on and TEXT_LISTED:format(side.faction) or TEXT_HIDDEN, 1, 1, 1, true)
    GameTooltip:AddLine(TEXT_CONTESTED, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function SideClicked(half)
    local key = half.side.key
    local turningOff = S.Get(key)
    if turningOff then
        for _, side in ipairs(SIDES) do
            if side.key ~= key and not S.Get(side.key) then S.Set(side.key, true) end
        end
    end
    S.Set(key, not turningOff)
    SideEnter(half)
end

local function Half(switch, i, side)
    local half = CreateFrame("Button", nil, switch)
    half:SetSize(FACTION_W, SEARCH_H)
    half:SetPoint("LEFT", (i - 1) * FACTION_W, 0)
    half.side = side
    half.fill = half:CreateTexture(nil, "BACKGROUND", nil, FILL_SUBLEVEL)
    half.fill:SetAllPoints()
    local r, g, b = CodeRGB(TERRITORY_CODE[side.faction])
    half.fill:SetColorTexture(r, g, b, SIDE_FILL)
    half.icon = half:CreateTexture(nil, "ARTWORK")
    half.icon:SetAtlas(FACTION_ATLAS[side.faction])
    half.icon:SetSize(FACTION_ICON, FACTION_ICON)
    half.icon:SetPoint("CENTER")
    half:SetScript("OnClick", SideClicked)
    half:SetScript("OnEnter", SideEnter)
    half:SetScript("OnLeave", GameTooltip_Hide)
    return half
end

local FactionSwitch = {}
J.FactionSwitch = FactionSwitch

function FactionSwitch.New(parent)
    local switch = CreateFrame("Frame", nil, parent)
    switch:SetSize(FACTION_W * #SIDES, SEARCH_H)
    ns.Solid(switch, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(switch, BORDER_RGB)
    local halves = {}
    for i, side in ipairs(SIDES) do halves[i] = Half(switch, i, side) end
    local split = ns.Solid(switch, "BORDER", BORDER_RGB, 1)
    split:SetPoint("TOP", 0, 0)
    split:SetPoint("BOTTOM", 0, 0)
    ns.Hairline(split, "v")
    return switch, halves
end

function FactionSwitch.Paint(halves)
    for _, half in ipairs(halves) do PaintSide(half) end
end
