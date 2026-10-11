-- SettingsPage.lua: Group Inspect's settings page, declared as cards, with its live preview.
local ns = _G.NaowhForever
local S = ns.QoLSettings
local GI = ns.GroupInspect
local UI = GI.UI

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local St = UI.Style
local PREVIEW_H, MARGIN = 320, 12
local MIN_SCALE = 0.1
local PERCENT, ROUND = GI.C.PERCENT, GI.C.ROUND
local OPACITY_RANGE, PERCENT_SCALE = St.OPACITY_RANGE, St.PERCENT_SCALE
local STATES = {
    { key = "party", label = "Party", tip = "A party of five, a card each." },
    { key = "raid", label = "Raid", tip = "A raid, a row each." },
}
local NOT_GROUPED = ns.L("Not in a group")
local PARTY, RAID = UI.MODE_WORDS.party, UI.MODE_WORDS.raid
local RUNS_ONE, RUNS = ns.L("1 runs Naowh Forever"), ns.L("%d run Naowh Forever")
local GROUPED_DETAIL = ns.L("Everyone's Naowh Score, gear, talents and stats, side by side.")
local SOLO_DETAIL = ns.L("Join a party or raid to use it; the preview below shows how it looks.")

local function Hidden(preview)
    preview.state = nil
    GI.Preview(false)
    UI.PaintWindow()
end

local function Scale(preview, height)
    local w, h = preview:GetWidth(), preview:GetHeight()
    local scale = 1
    if w > 0 then scale = math.min(scale, (w - 2 * MARGIN) / UI.BOARD_W) end
    if h > 0 and height then scale = math.min(scale, (h - 2 * MARGIN) / height) end
    return math.max(scale, MIN_SCALE)
end

local function Layout(preview)
    local party = preview.state == "party"
    preview.board:SetShown(party)
    preview.box:SetShown(not party)
    if party then
        local scale = Scale(preview, UI.PARTY_H)
        preview.board:SetScale(scale)
        preview.board:ClearAllPoints()
        preview.board:SetPoint("TOP", preview, "TOP", 0, -MARGIN / scale)
        preview.board:Paint()
    else
        local scale = Scale(preview)
        preview.box:SetScale(scale)
        preview.box:ClearAllPoints()
        preview.box:SetPoint("TOP", preview, "TOP", 0, -MARGIN / scale)
        preview.list:Draw()
    end
end

local function Repaint(preview, guid)
    if not preview.state then return end
    if guid and preview.state == "party" and preview.board:PaintGuid(guid) then return end
    if guid and preview.state == "raid" then
        preview.list:PaintGuid(guid)
        return
    end
    Layout(preview)
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.board = UI.PartyBoard(preview)
    local box = CreateFrame("Frame", nil, preview)
    box:SetSize(UI.LIST_W, St.COLUMNS_H)
    preview.box = box
    preview.list = UI.RaidList(box)
    preview.list.header:SetPoint("TOPLEFT")
    preview.list.view:SetPoint("TOPLEFT", 0, -St.COLUMNS_H)
    preview.list.view.unfiltered = true
    preview.Repaint = Repaint
    preview:SetScript("OnHide", Hidden)
    UI.preview = preview
    UI.Listen()
    return preview
end

local function PaintPreview(preview, state)
    preview.state = state
    GI.PreviewMode(state)
    GI.Preview(true)
    Layout(preview)
end

local function Grouped()
    return IsInGroup() and GetNumGroupMembers() > 1
end

local function Headline()
    if not Grouped() then return NOT_GROUPED end
    local text = (IsInRaid() and RAID or PARTY):format(GetNumGroupMembers())
    if UI.preview and UI.preview.state then return text end
    local nf = 0
    for _, rec in ipairs(GI.Members()) do
        if rec.hasNF and rec.state ~= "self" then nf = nf + 1 end
    end
    if nf == 0 then return text end
    return text .. St.PLACE_DOT .. (nf == 1 and RUNS_ONE or RUNS:format(nf))
end

local function Detail()
    return Grouped() and GROUPED_DETAIL or SOLO_DETAIL
end

local function Open()
    ns.OpenGroupInspect()
end

local function ShareSummary(store)
    return store.Get("groupInspectShare") and ns.L("Sharing with your group") or ns.L("Not sharing")
end

local function WindowSummary(store)
    return (ns.L("%d%% opacity")):format(math.floor((store.Get("groupInspectAlpha") or 1) * PERCENT + ROUND))
end

local page = Settings.Page(UI.PAGE, S)

page:Window({
    text = "Open Group Inspect",
    open = Open,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "share", name = "Share Your Stats", order = 10, switch = "groupInspectShare",
    help = "Sends your exact stats and talents to group members who use Group Inspect.",
    summary = ShareSummary,
})

page:Card({
    id = "preview", name = "Preview", order = 20,
    help = "How Group Inspect shows a party and a raid, with sample players.",
    studio = { height = PREVIEW_H, states = STATES, new = NewPreview, paint = PaintPreview },
})

page:Card({
    id = "binding", name = "Key Binding", order = 30,
    help = "A key that opens Group Inspect.",
    rows = {
        { label = "Open Group Inspect", binding = "NAOWHFOREVER_GROUPINSPECT",
          help = "Press this key to open Group Inspect, and again to close it." },
    },
})

page:Card({
    id = "window", name = "Window", order = 40,
    help = "Group Inspect's own window.",
    search = "right-click right click party raid menu",
    summary = WindowSummary,
    rows = {
        { key = "groupInspectAlpha", label = "Window Opacity", slider = OPACITY_RANGE, unit = "%",
          scale = PERCENT_SCALE, help = "How solid the window is, in percent. Also on its title bar." },
    },
})
