-- Window.lua: the Blessings window (/nfbless): every paladin's blessing for each class, Auto-Assign and the preset.
local ns = _G.NaowhForever

local B = ns.Blessings
local Shared = ns.Shared
local Parts, St = Shared.Parts, Shared.Style

local WIDTH, HEIGHT = 720, 560
local HEADER, FOOTER, PAD = St.WINDOW_HEADER, St.WINDOW_FOOTER, St.WINDOW_PAD
local INSET, SCROLLBAR = St.CONTENT_INSET, St.SCROLLBAR
local CARD = 6
local SCROLL_GAP = 4
local TOP_Y = -6
local WINDOW_KEY = "blessingsWindow"
local GRIP_SIZE, GRIP_INSET = 16, 4
local GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.6, 1.5, 0.05
local TEXT_GRIP = ns.L("Drag to resize the window. Right-click to reset its size.")
local TEXT_TITLE = ns.L("Blessings")
local TEXT_TITLE_TIP = ns.L("Paladin blessings by class and player, shared with the group's paladins.")

local window, scroll, content
local queued

local function Paint()
    window.backdrop:Paint(1)
    window.note.text:SetText(B.Headline())
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
end

local function Redraw()
    queued = false
    if not (window and window:IsShown()) then return end
    ns.UI.BeginReusableRows(content)
    local y = ns.BuildBlessingAssignmentsPage(content, TOP_Y)
    content:SetHeight(math.abs(y) + PAD)
    Paint()
end

local function RedrawSoon()
    if queued or not (window and window:IsShown()) then return end
    queued = true
    C_Timer.After(0, Redraw)
end

local function Scale()
    return ns.UIScale() * B.Settings.Get("blessWindowScale")
end

local function Rescale(grip)
    local factor = 1 + (GetCursorPosition() - grip.startX) / (WIDTH * grip.startEffective)
    local scale = math.min(SCALE_MAX, math.max(SCALE_MIN, grip.startScale * factor))
    grip.scale = math.floor(scale / SCALE_STEP + 0.5) * SCALE_STEP
    window:SetScale(ns.UIScale() * grip.scale)
end

local function StartResize(grip, button)
    if button == "RightButton" then
        grip.scale = nil
        B.Settings.Set("blessWindowScale", 1)
        return
    end
    grip.startX, grip.startScale, grip.startEffective = GetCursorPosition(), B.Settings.Get("blessWindowScale"),
        window:GetEffectiveScale()
    grip.scale = grip.startScale
    grip:SetScript("OnUpdate", Rescale)
end

local function StopResize(grip)
    grip:SetScript("OnUpdate", nil)
    if grip.scale and grip.scale ~= B.Settings.Get("blessWindowScale") then B.Settings.Set("blessWindowScale", grip.scale) end
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, WINDOW_KEY)
    window.backdrop:Card(CARD, HEADER + CARD, CARD, FOOTER + CARD)
    Parts.TitleBar(window, TEXT_TITLE, TEXT_TITLE_TIP, B.PAGE)
    Parts.FooterBrand(window, B.PAGE)
    window.note = Parts.FooterNote(window, "")
    local left, top = CARD + INSET, HEADER + CARD + PAD
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", left, -top)
    scroll:SetPoint("BOTTOMRIGHT", -(CARD + SCROLLBAR + SCROLL_GAP), FOOTER + CARD + PAD)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - left - CARD - SCROLLBAR - INSET, 1)
    scroll:SetScrollChild(content)
    local grip = CreateFrame("Button", nil, window)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
    grip:SetNormalTexture(GRIP_TEXTURE)
    grip:RegisterForClicks("AnyDown", "AnyUp")
    grip:SetScript("OnMouseDown", StartResize)
    grip:SetScript("OnMouseUp", StopResize)
    ns.Tooltip(grip, TEXT_TITLE, TEXT_GRIP)
end

function ns.OpenBlessingsWindow()
    if not window then Build() end
    window:SetScale(Scale())
    window:Show()
    Redraw()
end

function ns.ToggleBlessingsWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenBlessingsWindow() end
end

hooksecurefunc(ns.UI, "RefreshPage", RedrawSoon)
hooksecurefunc(ns, "Apply", RedrawSoon)
hooksecurefunc(B.Settings, "Set", function(key)
    if key == "blessWindowScale" and window then window:SetScale(Scale()) end
end)
