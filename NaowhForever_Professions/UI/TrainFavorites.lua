-- TrainFavorites.lua: Train Favorites: beside a profession trainer, the favourites it can teach you now, to learn.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local Patterns = P.Patterns
local Popup = P.Popup
local Text = P.Text
local Style = P.Style

local MAX_ROWS = Style.SIDE_PANEL_ROWS
local LEARN_ALL_W, LEARN_ALL_H = 140, 22
local LEARN_ALL_RIGHT, LEARN_ALL_BOTTOM = 10, 8
local PANEL_GAP = Style.SIDE_PANEL_GAP
local PANEL_LIFT = 120
local QUEUE_DELAY = P.C.QUEUE_DELAY
local OPEN_TRIES = { 0.2, 0.6, 1.5 }
local TRAINER_ADDON = "Blizzard_TrainerUI"
local EVENTS = { "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "PLAYER_MONEY", "ADDON_LOADED" }
local TEXT_TITLE = ns.L("Train Favorites")
local TEXT_LEARN = "Learn"
local TEXT_LEARN_ALL = ns.L("Learn All")
local TEXT_LEARN_ALL_COST = ns.L("Learn All (%s)")
local TEXT_MORE = ns.L("+%d more")

local trainer
local trainerOpen
local pending = false
local hookedTrainer
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("trainFavorites") and not ns.GamepadStandDown()
end

local function LearnClick(row)
    Patterns.Learn({ row.offer })
end

local function Build()
    trainer = Popup.New(TEXT_TITLE)
    trainer.all = ns.AccentBorder(ns.Button(trainer, TEXT_LEARN_ALL, LEARN_ALL_W, LEARN_ALL_H, function()
        Patterns.Learn(trainer.offers)
    end))
    trainer.all:SetPoint("BOTTOMRIGHT", -LEARN_ALL_RIGHT, LEARN_ALL_BOTTOM)
end

local function NoteColor(row, cost)
    local short = GetMoney() < cost
    local c = Style.RED_RGB
    row.note:SetTextColor(short and 1 or T.muted.r, short and c.g or T.muted.g, short and c.b or T.muted.b)
end

local function FillRow(i, o)
    local row = Popup.Row(trainer, i, TEXT_LEARN, LearnClick)
    row.offer, row.item, row.spell = o, nil, o.spell
    row.icon:SetTexture(o.icon)
    row.name:SetText(o.name)
    row.note:SetText(Text.Short(o.cost))
    NoteColor(row, o.cost)
    row:Show()
end

local function Place(frame)
    trainer:ClearAllPoints()
    if frame and frame:IsShown() then
        trainer:SetPoint("TOPLEFT", frame, "TOPRIGHT", PANEL_GAP, 0)
    else
        trainer:SetPoint("CENTER", UIParent, "CENTER", 0, PANEL_LIFT)
    end
end

local function Render()
    local frame = _G.ClassTrainerFrame
    if not (On() and (trainerOpen or frame and frame:IsShown())) then return trainer and trainer:Hide() end
    local offers = Patterns.TrainerOffers()
    if #offers == 0 then return trainer and trainer:Hide() end
    if not trainer then Build() end
    if trainer.dismissed then return end
    trainer.offers = offers
    local total = 0
    for i, o in ipairs(offers) do
        total = total + o.cost
        if i <= MAX_ROWS then FillRow(i, o) end
    end
    Popup.Fit(trainer, math.min(#offers, MAX_ROWS), true)
    ns.SetButtonText(trainer.all, TEXT_LEARN_ALL_COST:format(Text.Short(total)))
    trainer.all:SetEnabled(GetMoney() >= total)
    trainer.all:SetAlpha(GetMoney() >= total and 1 or Style.DIMMED)
    trainer.note:SetText(#offers > MAX_ROWS and TEXT_MORE:format(#offers - MAX_ROWS) or "")
    Place(frame)
    trainer:Show()
end

local function Flush()
    pending = false
    Render()
end

local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(QUEUE_DELAY, Flush)
end

local function TryAgain()
    if not (trainer and trainer:IsShown()) then Render() end
end

local function Opened()
    trainerOpen = true
    if trainer then trainer.dismissed = nil end
    for _, delay in ipairs(OPEN_TRIES) do C_Timer.After(delay, TryAgain) end
end

local function OnFrameShow()
    if On() then Opened() end
end

local function OnFrameHide()
    if trainer then trainer:Hide() end
end

local function HookTrainerFrame()
    local frame = _G.ClassTrainerFrame
    if hookedTrainer or not frame then return end
    hookedTrainer = true
    frame:HookScript("OnShow", OnFrameShow)
    frame:HookScript("OnHide", OnFrameHide)
end

local function OnEvent(_, event, name)
    if event == "ADDON_LOADED" then
        if name == TRAINER_ADDON then HookTrainerFrame() end
    elseif event == "TRAINER_SHOW" then
        HookTrainerFrame()
        Opened()
    elseif event == "TRAINER_CLOSED" then
        trainerOpen = false
        if trainer then trainer:Hide() end
    else
        Queue()
    end
end

local function Apply()
    events:UnregisterAllEvents()
    if trainer and not On() then trainer:Hide() end
    if not On() then return end
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    HookTrainerFrame()
end

local function OnSettingChanged(key)
    if key ~= "enabled" and key ~= "trainFavorites" then return end
    Apply()
    Queue()
end

local function OnStarred()
    if On() then Queue() end
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
if ns.ProfFavorites then hooksecurefunc(ns.ProfFavorites, "Toggle", OnStarred) end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
