-- Solo.lua: Group Inspect's note while you are not in a group, with a link to the preview on its settings page (GI.UI.SoloNote).
local ns = _G.NaowhForever

local T = ns.THEME
local GI = ns.GroupInspect
local UI = GI.UI
local St = UI.Style
local Parts = ns.Shared.Parts

local INSET = St.CONTENT_INSET
local SOLO_GAP, SOLO_LIFT = 8, 30
local SOLO_TITLE_GROW = 1
local SOLO_TITLE = ns.L("You are not in a group")
local SOLO_LINE = ns.L("Join a party or raid to see everyone's Naowh Score, gear, talents and stats.")
local SOLO_LINK = ns.L("See a preview on its settings page")

local function OpenPage()
    ns.OpenOptionsWindow(UI.PAGE)
end

function UI.SoloNote(parent)
    local solo = CreateFrame("Frame", nil, parent)
    solo:SetPoint("TOPLEFT", INSET, -UI.CONTENT_TOP)
    solo:SetSize(UI.CONTENT_W, UI.CONTENT_H)
    local title = ns.Font(solo, St.CARD_NAME_SIZE + SOLO_TITLE_GROW, nil, T.fg)
    title:SetPoint("CENTER", 0, SOLO_LIFT)
    title:SetText(SOLO_TITLE)
    local line = ns.Font(solo, St.LINE_SIZE, nil, T.muted)
    line:SetPoint("TOP", title, "BOTTOM", 0, -SOLO_GAP)
    line:SetText(SOLO_LINE)
    local link = Parts.Link(solo, OpenPage, true)
    Parts.SetLink(link, SOLO_LINK)
    link:SetPoint("TOP", line, "BOTTOM", 0, -SOLO_GAP)
    return solo
end
