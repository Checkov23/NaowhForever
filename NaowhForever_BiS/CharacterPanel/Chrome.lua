-- Chrome.lua: the character panel dressed in the BiS List's look: the game's art faded or tinted under our frame.
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local CP = ns.CharacterPanel
local St = ns.Shared.Style
local Parts = ns.Shared.Parts
local StatsLook = CP.StatsLook

local TOGGLE_EDGE, TOGGLE_W, LINK_GAP = 6, 28, 12
local BADGE_MID_FALLBACK = 32
local COVER_LIFT = 20
local LEVEL_STRIP_Y = 2
local SIDE_TABS, SIDEBAR_TABS = 6, 3
local TEXTURE = CP.C.TEXTURE
local SIDE_TAB, SIDEBAR_TAB = "CharacterFrameModeTab", "PaperDollSidebarTab"
local TEXT_BIS_LIST = ns.L(" BiS List")
local TAB_RGB, HOVER_ALPHA = CP.C.TAB_RGB, CP.C.HOVER_ALPHA
local MODEL_ART = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight",
    "BackgroundOverlay" }

local game = CP.PanelArt
local chrome, installed, levelMoved

local function OpenBis()
    ns.OpenBisWindow()
end

local function Cover(frame, controls)
    local cover = CreateFrame("Frame", nil, PaperDollFrame or frame)
    cover:SetAllPoints(controls)
    cover:SetFrameLevel(CharacterModelScene:GetFrameLevel() + COVER_LIFT)
    cover:EnableMouse(true)
    local bis = Parts.Link(cover, OpenBis, true)
    Parts.SetLink(bis, Parts.Inline(St.STAR, St.BIS_RGB, Parts.CARD_DROP) .. TEXT_BIS_LIST)
    bis:SetPoint("RIGHT", frame.LeftPaneHost, "TOPRIGHT", -(TOGGLE_EDGE + TOGGLE_W + LINK_GAP),
        -(CP.BADGE_MID or BADGE_MID_FALLBACK))
    return cover
end

local function Build()
    local frame = CharacterFrame
    chrome = CP.Chrome(frame)
    CP.ModelPanel(chrome, frame.LeftPaneHost)
    CP.Split(chrome, frame.RightPaneHost)
    local controls = CharacterModelScene and CharacterModelScene.ControlFrame
    if controls then chrome.cover = Cover(frame, controls) end
end

local function FadeAmmo()
    local ammo = _G.CharacterAmmoSlot
    if not ammo then return end
    for _, region in ipairs({ ammo:GetRegions() }) do
        if region ~= ammo.icon and region:GetObjectType() == TEXTURE then game.Fade(region) end
    end
end

local function FadeGame()
    local frame = CharacterFrame
    game.Fade(frame.NineSlice)
    game.Fade(frame.PortraitContainer)
    game.FadeRegions(frame.LeftPaneHost)
    local right = frame.RightPaneHost
    game.FadeRegions(right)
    if right then
        for _, child in ipairs({ right:GetChildren() }) do game.Fade(child) end
    end
    local model = CharacterModelScene
    if model then
        for _, key in ipairs(MODEL_ART) do game.Fade(model[key]) end
    end
    game.Fade(CharacterLevelTextBackground)
    game.FadeTree(PaperDollFrame and PaperDollFrame.TopBackgroundStripHost)
    game.FadeRegions(CharacterStatsPaneScrollBox)
    FadeAmmo()
    game.FadeClose(frame.CloseButton)
end

local function TintSidebarTab(tab)
    for _, region in ipairs({ tab:GetRegions() }) do
        if region ~= tab.Icon and region:GetObjectType() == TEXTURE then game.Tint(region, TAB_RGB) end
    end
    game.Tint(tab:GetCheckedTexture(), T.accent)
    game.Tint(tab:GetHighlightTexture(), T.accent, HOVER_ALPHA)
end

local function TintGame()
    for i = 1, SIDE_TABS do game.TintSideTab(_G[SIDE_TAB .. i]) end
    for i = 1, SIDEBAR_TABS do
        local tab = _G[SIDEBAR_TAB .. i]
        if tab then TintSidebarTab(tab) end
    end
    local toggle = CharacterFrame.RightPaneToggleButton
    if toggle then
        game.Tint(toggle:GetNormalTexture(), T.muted)
        game.Tint(toggle:GetPushedTexture(), T.accent)
    end
    game.TintTree(CharacterStatsPaneScrollBox and CharacterStatsPaneScrollBox.ScrollBar, T.muted)
    game.FadeTree(CharacterModelScene and CharacterModelScene.ControlFrame)
end

local function PlaceLevel(onRow)
    local info, strip = PaperDollLevelInfo, PaperDollFrame and PaperDollFrame.TopBackgroundStripHost
    if not (info and strip) or (not onRow and not levelMoved) then return end
    info:ClearAllPoints()
    if onRow then
        info:SetPoint("CENTER", CharacterFrame.LeftPaneHost, "TOP", 0, -CP.BADGE_MID)
    else
        info:SetPoint("CENTER", strip, "CENTER", 0, -LEVEL_STRIP_Y)
    end
    levelMoved = onRow
end

local function StatsList()
    return CharacterStatsPaneScrollBox and CharacterStatsPaneScrollBox.ScrollBox
end

local function Install()
    installed = true
    Build()
    local list = StatsList()
    if list and ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
        ScrollUtil.AddInitializedFrameCallback(list, StatsLook.Style, chrome, true)
    end
end

local function ShowChrome(on)
    chrome:SetShown(on)
    if chrome.cross then chrome.cross:SetShown(on) end
    if chrome.cover then chrome.cover:SetShown(on) end
end

local function Dress()
    FadeGame()
    TintGame()
    game.Restyle(CharacterFrameTitleText, CP.TITLE_SIZE, T.fg)
    game.Restyle(CharacterLevelText, CP.LEVEL_SIZE, T.fg)
    PlaceLevel(true)
    ShowChrome(true)
    StatsLook.StyleAll(StatsList())
end

local function Apply()
    local on = CP.On()
    if on and not installed and CharacterFrame then Install() end
    if not installed then return end
    if on then return Dress() end
    game.Restore()
    PlaceLevel(false)
    StatsLook.Unstyle()
    ShowChrome(false)
end

local function OnSetting(key)
    if key == "enabled" or key:find("^characterPanel") then Apply() end
end

CP.ApplyChrome = Apply

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
