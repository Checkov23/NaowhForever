-- FavoriteMarks.lua: stars beside favorite unlearned recipes at open trainers and merchants.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local Patterns = P.Patterns
local Widgets = P.Widgets

local MERCHANT_ROWS = 12
local TRAINER_ROWS = 30
local STAR_SIZE, STAR_GAP, STAR_DROP = 12, 4, 1
local EVENTS = { "ADDON_LOADED", "MERCHANT_SHOW", "BAG_UPDATE_DELAYED", "TRAINER_SHOW", "TRAINER_UPDATE",
    "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "TRADE_SKILL_LIST_UPDATE" }
local SETTING_KEYS = { enabled = true, favoriteVendorMarks = true }
local UI_ADDONS = { Blizzard_MerchantUI = true, Blizzard_TrainerUI = true, EllesmereUIBlizzardSkin = true }

local merchantItems, trainerNames, seen = {}, {}, {}
local merchantMarks, trainerMarks = {}, {}
local merchantStale, trainerStale = true, true
local events
local merchantHooked, trainerHooked, favoritesHooked = false, false, false
local trainerScroll

local function On()
    return P.On() and S.Get("favoriteVendorMarks") and not ns.GamepadStandDown()
end

local function HideMarks(marks)
    for _, mark in pairs(marks) do mark:Hide() end
end

local function Mark(marks, row, name, shown)
    local mark = marks[row]
    if not shown then
        if mark then mark:Hide() end
        return
    end
    if not mark then
        mark = row:CreateTexture(nil, "OVERLAY")
        mark:SetSize(STAR_SIZE, STAR_SIZE)
        Widgets.Star(mark, true)
        marks[row] = mark
    end
    mark:ClearAllPoints()
    local room = row:GetRight() - name:GetLeft() - STAR_SIZE
    mark:SetPoint("LEFT", name, "LEFT", math.min(name:GetStringWidth() + STAR_GAP, room), -STAR_DROP)
    mark:Show()
end

local function MerchantItem(index, button)
    local item = GetMerchantItemID(index)
    if item then return item end
    local link = button and button.link or GetMerchantItemLink(index)
    return link and tonumber(link:match("item:(%d+)"))
end

local function MerchantParts(row, fallback)
    if not row then return end
    local rowName = row:GetName()
    local name = row.Name or (rowName and _G[rowName .. "Name"])
    local button = row.ItemButton or (rowName and _G[rowName .. "ItemButton"])
    local index = button and button.GetID and button:GetID()
    return name, button, tonumber(index) or fallback
end

local function ApplyMerchantRow(row, fallback)
    if not row or seen[row] then return end
    seen[row] = true
    local name, button, index = MerchantParts(row, fallback)
    if not (name and index) then return Mark(merchantMarks, row, name, false) end
    local item = MerchantItem(index, button)
    Mark(merchantMarks, row, name, merchantItems[item] == true
        and C_MerchantFrame.GetItemInfo(index).numAvailable ~= 0)
end

local function PaintMerchant()
    if not On() then return end
    HideMarks(merchantMarks)
    local frame = _G.MerchantFrame
    if not frame:IsShown() or frame.selectedTab == 2 then return end
    if merchantStale then
        wipe(merchantItems)
        for _, entry in ipairs(Patterns.List()) do merchantItems[entry.item] = true end
        merchantStale = false
    end
    wipe(seen)
    local scroll = _G.WSkinMerchantScrollFrame or frame.wSkinScrollFrame
    for index, row in ipairs((scroll and scroll.rows) or {}) do ApplyMerchantRow(row, index) end
    local page = tonumber(frame.page) or 1
    for slot = 1, MERCHANT_ROWS do
        ApplyMerchantRow(_G["MerchantItem" .. slot], (page - 1) * MERCHANT_ROWS + slot)
    end
end

local function TrainerName(row)
    if not row then return end
    local rowName = row:GetName()
    return row.name or row.Name or row.Text or (rowName and (_G[rowName .. "Text"] or _G[rowName .. "Name"]))
end

local function ApplyTrainerRow(row)
    local name = TrainerName(row)
    local text = name and name:GetText()
    Mark(trainerMarks, row, name, text and trainerNames[text] == true)
end

local function PaintTrainer()
    if not On() then return end
    HideMarks(trainerMarks)
    local frame = _G.ClassTrainerFrame
    if not (frame and frame:IsShown()) then return end
    if trainerStale then
        wipe(trainerNames)
        for _, offer in ipairs(Patterns.TrainerOffers()) do trainerNames[offer.name] = true end
        trainerStale = false
    end
    local scroll = frame and (frame.ScrollBox or frame.scrollBox)
    if scroll and scroll.ForEachFrame then scroll:ForEachFrame(ApplyTrainerRow) end
    for index = 1, TRAINER_ROWS do ApplyTrainerRow(_G["ClassTrainerSkill" .. index]) end
end

local function Refresh()
    if not On() then return end
    merchantStale, trainerStale = true, true
    PaintMerchant()
    PaintTrainer()
end

local function HookFrames()
    if not merchantHooked and type(_G.MerchantFrame_Update) == "function" then
        hooksecurefunc("MerchantFrame_Update", PaintMerchant)
        merchantHooked = true
    end
    if not trainerHooked and type(_G.ClassTrainerFrame_Update) == "function" then
        hooksecurefunc("ClassTrainerFrame_Update", PaintTrainer)
        trainerHooked = true
    end
    local frame = _G.ClassTrainerFrame
    local scroll = frame and (frame.ScrollBox or frame.scrollBox)
    if scroll and scroll ~= trainerScroll and type(scroll.Update) == "function" then
        hooksecurefunc(scroll, "Update", PaintTrainer)
        trainerScroll = scroll
    end
    if not favoritesHooked then
        hooksecurefunc(P.Favorites, "Toggle", Refresh)
        favoritesHooked = true
    end
end

local function OnEvent(_, event, arg)
    if event == "ADDON_LOADED" and not UI_ADDONS[arg] then return end
    HookFrames()
    Refresh()
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        HideMarks(merchantMarks)
        HideMarks(trainerMarks)
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    HookFrames()
    Refresh()
end

local function OnSettingChanged(key)
    if SETTING_KEYS[key] then Apply() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
Apply()
