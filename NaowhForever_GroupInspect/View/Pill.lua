-- Pill.lua: Group Inspect's NF pill on members who run Naowh Forever, tinted when their version is older than yours.
local ns = _G.NaowhForever

local T = ns.THEME
local GI = ns.GroupInspect
local UI = GI.UI
local St = UI.Style
local Parts = ns.Shared.Parts

local TITLE_RGB, WARN_RGB = St.TIP_TITLE_RGB, St.WARN_RGB
local VERSION_MAX = 24
local RUNS_NF, VERSION = ns.L("Runs Naowh Forever"), ns.L("Version %s")
local OLDER = ns.L("Older than yours (%s): ask them to update.")
local NF = "NF"

local parts = {}

local function Older(theirs, mine)
    if type(theirs) ~= "string" or type(mine) ~= "string" then return false end
    wipe(parts)
    for n in mine:gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
    local i = 0
    for n in theirs:gmatch("%d+") do
        i = i + 1
        local a, b = tonumber(n), parts[i]
        if b == nil then return false end
        if a ~= b then return a < b end
    end
    return i < #parts
end

UI.Older = Older

function UI.PaintNFPill(pill, rec)
    local old = rec and rec.hasNF == true and Older(rec.nfVersion, ns.CODE_BUILD)
    Parts.ColorPill(pill, old and WARN_RGB or T.accent)
end

local function PillEnter(pill)
    if GameTooltip:IsForbidden() or not Parts.Tip(pill, "ANCHOR_TOP") then return end
    local guid = pill.holder.guid
    local rec = guid and GI.Member(guid)
    GameTooltip:SetText(RUNS_NF, TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    local version = rec and ns.PlainText(rec.nfVersion, VERSION_MAX)
    if version and version ~= "" then
        GameTooltip:AddLine(VERSION:format(version), T.muted.r, T.muted.g, T.muted.b)
        if Older(rec.nfVersion, ns.CODE_BUILD) then
            GameTooltip:AddLine(OLDER:format(ns.PlainText(ns.CODE_BUILD, VERSION_MAX)), WARN_RGB.r, WARN_RGB.g,
                WARN_RGB.b, true)
        end
    end
    GameTooltip:Show()
end

function UI.NFPill(parent, holder)
    local pill = Parts.Pill(parent, St.PILL_SIZE, T.accent)
    pill.color = T.accent
    Parts.SetPill(pill, NF)
    pill.holder = holder
    pill:EnableMouse(true)
    pill:SetScript("OnEnter", PillEnter)
    pill:SetScript("OnLeave", GameTooltip_Hide)
    pill:Hide()
    return pill
end
