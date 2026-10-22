-- Minimap.lua: where herbs and veins grow, on the minimap, each in its own icon and ringed in its skill-up color;
-- while its Find spell tracks, the icon sits on the ring so the game's own dot shows inside when the node is up.
local ns = _G.NaowhForever

local G = ns.Glimmer
local S = G.Settings
local C, St = G.C, G.Style
local Spots = G.Spots

local RING_GROW = 1.6
local ICON_SHARE = 0.7
local BADGE_SHARE = 0.45
local BADGE_AT = 0.57
local OWN_KEYS = { enabled = true, minimapIcons = true, minimapSize = true, myProfessions = true, ore = true,
    herb = true, skillColors = true, oreColor = true, herbColor = true }
local TEXT_LINE = "%s (%d)"

local layer, events, kinds, here, watching
local spots = {}
local tracked = {}

local function On()
    return G.On() and S.Get("minimapIcons")
end

local function OnEnter(pin)
    local node = pin.node
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(TEXT_LINE:format(ns.L(node[3]), node[2]), 1, 1, 1)
    local tier = Spots.Tier(pin.id)
    if tier then
        local c = St.TIER_RGB[tier]
        GameTooltip:AddLine(G.Target.TierText(node[1], node[2], tier), c.r, c.g, c.b)
    end
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

local function NewPin()
    local pin = CreateFrame("Frame", nil, Minimap)
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetTexture(St.MEDIA .. "ring")
    pin.ring:SetPoint("CENTER")
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetPoint("CENTER")
    pin.icon:SetTexCoord(St.ICON_CROP, St.ICON_CROP_HIGH, St.ICON_CROP, St.ICON_CROP_HIGH)
    pin:SetScript("OnEnter", OnEnter)
    pin:SetScript("OnLeave", OnLeave)
    return pin
end

local function Paint(pin, list, i)
    local id = list[i * 3 - 2]
    local node = G.NODES[id]
    local size = S.Get("minimapSize")
    pin.id, pin.node = id, node
    pin:SetSize(size, size)
    pin.ring:SetSize(size * RING_GROW, size * RING_GROW)
    pin.icon:ClearAllPoints()
    if tracked[node[1]] then
        pin.icon:SetPoint("CENTER", size * BADGE_AT, -size * BADGE_AT)
        pin.icon:SetSize(size * BADGE_SHARE, size * BADGE_SHARE)
    else
        pin.icon:SetPoint("CENTER")
        pin.icon:SetSize(size * ICON_SHARE, size * ICON_SHARE)
    end
    pin.icon:SetTexture(C_Spell.GetSpellTexture(C.ICON_SPELL[node[1]]))
    local tier = S.Get("skillColors") and Spots.Tier(id)
    local c = tier and St.TIER_RGB[tier] or S.Get(node[1] .. "Color")
    pin.ring:SetVertexColor(c.r, c.g, c.b)
    local x, y = Spots.XY(list, i)
    local covered = ns.NodeIconAt and ns.NodeIconAt(here, x, y)
    pin:SetAlpha(covered and 0 or 1)
    pin:EnableMouse(not covered)
end

local function Track()
    wipe(tracked)
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and info.active then
            for category, spell in pairs(C.ICON_SPELL) do
                if info.spellID == spell then tracked[category] = true end
            end
        end
    end
end

local function Kinds()
    return (Spots.Wanted("ore") and "o" or "") .. (Spots.Wanted("herb") and "h" or "")
end

local function Refresh()
    kinds = Kinds()
    if not On() or kinds == "" or not Spots.Load() then
        if layer then layer:Set(nil) end
        return
    end
    Track()
    layer = layer or ns.Shared.Parts.MinimapLayer({ max = C.MINIMAP_MAX, new = NewPin, paint = Paint, xy = Spots.XY })
    local mapID = C_Map.GetBestMapForUnit("player")
    here = mapID
    layer:Set(mapID, spots, mapID and Spots.ForMap(mapID, spots) or 0)
end

local function Repaint()
    if layer then layer:Repaint() end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if not ns.GlimmerSpots then Refresh() end
    elseif event == "MINIMAP_UPDATE_TRACKING" then
        Track()
        if layer then layer:Repaint() end
    elseif event == "SKILL_LINES_CHANGED" then
        if Kinds() ~= kinds then Refresh() elseif layer then layer:Repaint() end
    else
        Refresh()
    end
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(C.MAP_EVENTS) do events:RegisterEvent(event) end
        if ns.NodeIconsChanged and not watching then
            watching = true
            hooksecurefunc(ns, "NodeIconsChanged", Repaint)
        end
    elseif events then
        events:UnregisterAllEvents()
    end
    Refresh()
end

local function OnSet(key)
    if OWN_KEYS[key] then C_Timer.After(0, Apply) end
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
