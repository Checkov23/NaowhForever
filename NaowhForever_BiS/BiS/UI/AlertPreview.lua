-- AlertPreview.lua: Drop Alert's live preview on its settings card (B.AlertStudio).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local S = B.Settings
local Shared = ns.Shared
local Items, Parts = Shared.Items, Shared.Parts
local St = B.Style

local STAGE_H = 130
local TOAST_W = St.TOAST_W
local TOAST_ROOM = 32
local FALLBACK_STAGE_W = 600
local NOTE_BOTTOM = 10
local EMPTY_LINK_GAP = 6
local EMPTY_RAISE = 12
local OFF_ALPHA = 0.35
local FIRST_SLOT = 1
local TEXT_OFF_NOTE = ns.L("On-Screen Alert is off: Drop Alert plays its chat line and sounds only.")
local TEXT_EMPTY_NOTE = ns.L("Pick your BiS to see your alert here.")
local TEXT_OPEN = ns.L("Open BiS List")
local STATES = { { key = "roll", label = "Up for a roll" }, { key = "dropped", label = "Dropped" },
    { key = "yours", label = "Yours!" } }

local function Sample()
    local list = B.Lists.List()
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local id = list.slots[gear[1]]
        if id then return id, ns.IsBisItem(id) or 1 end
    end
    return B.Rankings.Candidates(FIRST_SLOT, B.Lists.CurrentSpec())[1], 1
end

local function OpenList()
    ns.OpenFromOptions(ns.OpenBisWindow)
end

local function Note(preview, text)
    local note = ns.Font(preview, St.TEXT_SIZE, nil, T.muted)
    note:SetText(text)
    return note
end

local function New(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.toast = B.Toast.New(preview)
    preview.note = Note(preview, TEXT_OFF_NOTE)
    preview.note:SetPoint("BOTTOM", 0, NOTE_BOTTOM)
    preview.empty = Note(preview, TEXT_EMPTY_NOTE)
    preview.empty:SetPoint("CENTER", 0, EMPTY_RAISE)
    preview.emptyLink = Parts.Link(preview, OpenList, true)
    preview.emptyLink:SetPoint("TOP", preview.empty, "BOTTOM", 0, -EMPTY_LINK_GAP)
    Parts.SetLink(preview.emptyLink, TEXT_OPEN)
    return preview
end

local function Fit(preview)
    local w = preview:GetWidth()
    if not w or w <= 0 then w = FALLBACK_STAGE_W end
    preview.toast:SetScale(math.min(S.Get("bisToastScale"), (w - TOAST_ROOM) / TOAST_W))
    preview.toast:ClearAllPoints()
    preview.toast:SetPoint("CENTER", preview, "CENTER", 0, 0)
end

local function Paint(preview, state)
    local id, rank = Sample()
    local shown = id ~= nil
    preview.toast:SetShown(shown)
    preview.empty:SetShown(not shown)
    preview.emptyLink:SetShown(not shown)
    local looks = S.Get("bisToast") == true
    preview.note:SetShown(shown and not looks)
    if not shown then return end
    B.Toast.Paint(preview.toast, id, rank, state)
    preview.toast:SetAlpha(looks and 1 or OFF_ALPHA)
    Fit(preview)
end

B.AlertStudio = { height = STAGE_H, states = STATES, new = New, paint = Paint }
