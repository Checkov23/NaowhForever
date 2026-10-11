-- AlertTest.lua: Play Test: Drop Alert with your first BiS, up for a roll, dropped, then yours (B.Alerts.Test).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local S = B.Settings
local A = B.Alerts
local Items, Parts = ns.Shared.Items, ns.Shared.Parts
local St = B.Style

local TEST_STEP = 2.5
local TEST_W, TEST_H, TEST_ICON = 260, 44, 32
local TEST_TOP = 180
local ICON_X, TEXT_X, TEXT_Y = 6, 8, 2
local TEXT_TEST_ROLL = ns.L("Test roll")
local PLAIN_LINK = "|cffffffff|Hitem:%d::|h[%s]|h|r"

local preview, testLink, testRank

local function Preview()
    if preview then return preview end
    preview = CreateFrame("Frame", nil, UIParent)
    preview:SetSize(TEST_W, TEST_H)
    preview:SetPoint("TOP", 0, -TEST_TOP)
    preview:SetFrameStrata("DIALOG")
    ns.Solid(preview, "BACKGROUND", T.bg, St.CARD_ALPHA):SetAllPoints()
    ns.Border(preview, St.BORDER_RGB)
    local icon = Parts.ItemIcon(preview, TEST_ICON)
    icon:SetPoint("LEFT", ICON_X, 0)
    preview.icon = icon.texture
    preview.name = ns.Font(preview, St.TEXT_SIZE)
    preview.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", TEXT_X, -TEXT_Y)
    preview.name:SetPoint("RIGHT", -TEXT_X, 0)
    preview.name:SetJustifyH("LEFT")
    preview.name:SetWordWrap(false)
    local note = ns.Font(preview, St.SMALL_SIZE, nil, T.muted)
    note:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", TEXT_X, TEXT_Y)
    note:SetText(TEXT_TEST_ROLL)
    return preview
end

local function TestDropped() A.Say(testLink, testRank, "dropped") end

local function TestYours()
    A.Say(testLink, testRank, "yours")
    B.RollBadge.Show(preview, nil)
    preview:Hide()
end

local function FirstBis()
    local list = B.Lists.List()
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local id = list.slots[gear[1]]
        if id then return id end
    end
end

function A.Test()
    local id = FirstBis()
    if not id then return false end
    testRank = ns.IsBisItem(id) or 1
    testLink = select(2, C_Item.GetItemInfo(id)) or PLAIN_LINK:format(id, Items.Name(id))
    local frame = Preview()
    frame.icon:SetTexture(C_Item.GetItemIconByID(id))
    frame.name:SetText(testLink)
    frame:Show()
    B.RollBadge.Show(frame, S.Get("bisAlertBadge") and testRank or nil)
    A.Say(testLink, testRank, "roll")
    C_Timer.After(TEST_STEP, TestDropped)
    C_Timer.After(TEST_STEP * 2, TestYours)
    return true
end
