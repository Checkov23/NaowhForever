-- Ask.lua: Ask to Add New Consumables: a new consumable in the bags is offered for the bar, one at a time, out of combat.
local ns = _G.NaowhForever

local CB = ns.ConsumableBar
local S = CB.S
local Shared = ns.Shared
local Parts, St = Shared.Parts, Shared.Style

local ASK_W, ASK_ICON, ASK_FONT, ASK_BUTTON_W, BUTTON_H = 340, 36, 13, 90, 24
local ASK_GAP, ASK_TEXT_GAP = 4, 10
local ASK_ABOVE, ASK_TOP = 14, -180
local TEXT_TITLE = ns.L("Consumable Bar")
local TEXT_QUESTION = ns.L("Add %s to the Consumable Bar?")
local TEXT_ADD, TEXT_NO = ns.L("Add"), ns.L("No")
local TEXT_NEVER, TEXT_NEVER_TIP = ns.L("Never Ask"), ns.L("Never asks about this item again.")

local ask, known
local asking = {}
local inBags, seenInBags = {}, {}

local ShowAsk

local function IconEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(ask.itemID)
    GameTooltip:Show()
end

local function IconLeave()
    GameTooltip:Hide()
end

local function Add()
    ask:Hide()
    CB.AddItems({ ask.itemID })
    ShowAsk()
end

local function Decline()
    local declined = {}
    for id in pairs(S.Get("consumableBarDeclined") or {}) do declined[id] = true end
    declined[ask.itemID] = true
    ask:Hide()
    S.Set("consumableBarDeclined", declined)
    ShowAsk()
end

local function BuildAsk()
    ask = Parts.Panel(TEXT_TITLE)
    ask:SetFrameStrata("DIALOG")
    ask:SetSize(ASK_W, St.PANEL_HEADER + ASK_ICON + St.PANEL_PAD * 2 + BUTTON_H)
    ask.icon = CreateFrame("Button", nil, ask)
    ask.icon:SetSize(ASK_ICON, ASK_ICON)
    ask.icon:SetPoint("TOPLEFT", St.PANEL_PAD, -St.PANEL_HEADER)
    ask.icon.tex = ask.icon:CreateTexture(nil, "ARTWORK")
    ask.icon.tex:SetAllPoints()
    Shared.ItemBar.CropIcon(ask.icon.tex)
    ns.Border(ask.icon, St.BORDER_RGB)
    ask.icon:SetScript("OnEnter", IconEnter)
    ask.icon:SetScript("OnLeave", IconLeave)
    ask.text = ns.Font(ask, ASK_FONT, nil)
    ask.text:SetPoint("TOPLEFT", ask.icon, "TOPRIGHT", ASK_TEXT_GAP, 0)
    ask.text:SetPoint("RIGHT", -St.PANEL_PAD, 0)
    ask.text:SetJustifyH("LEFT")
    ns.Button(ask, TEXT_ADD, ASK_BUTTON_W, BUTTON_H, Add):SetPoint("BOTTOMRIGHT", ask, "BOTTOM", -ASK_GAP, St.PANEL_PAD)
    local no = ns.Button(ask, TEXT_NO, ASK_BUTTON_W, BUTTON_H, Decline)
    no:SetPoint("BOTTOMLEFT", ask, "BOTTOM", ASK_GAP, St.PANEL_PAD)
    ns.Tooltip(no, TEXT_NEVER, TEXT_NEVER_TIP)
    ask:Hide()
end

local function StillNew(id)
    local declined = S.Get("consumableBarDeclined") or {}
    return not CB.Has(CB.Items(), id) and not declined[id] and CB.Wanted(id) and C_Item.GetItemCount(id) > 0
end

function ShowAsk()
    if InCombatLockdown() or not CB.On() or not S.Get("consumableBarAskNew") then return end
    if ask and ask:IsShown() then return end
    local id
    repeat id = table.remove(asking, 1) until not id or StillNew(id)
    if not id then return end
    if not ask then BuildAsk() end
    ask.itemID = id
    ask.icon.tex:SetTexture(C_Item.GetItemIconByID(id) or CB.C.EMPTY_ICON)
    ask.text:SetText(TEXT_QUESTION:format(CB.ItemName(id)))
    ask:ClearAllPoints()
    local bar = CB.BarFrame()
    if bar and bar:IsVisible() then
        ask:SetPoint("BOTTOM", bar, "TOP", 0, ASK_ABOVE)
    else
        ask:SetPoint("TOP", UIParent, "TOP", 0, ASK_TOP)
    end
    ask:Show()
end
CB.ShowAsk = ShowAsk

function CB.CheckNewItems()
    if not S.Get("consumableBarAskNew") then
        known = nil
        return
    end
    local now = CB.BagConsumables(inBags, seenInBags)
    if not known then
        known = {}
        for _, id in ipairs(now) do known[id] = true end
        return
    end
    local items = CB.Items()
    local declined = S.Get("consumableBarDeclined") or {}
    for _, id in ipairs(now) do
        if not known[id] and not CB.Has(items, id) and not declined[id] and CB.Wanted(id) then
            asking[#asking + 1] = id
        end
        known[id] = true
    end
    ShowAsk()
end

function CB.StopAsking()
    known = nil
    wipe(asking)
    if ask then ask:Hide() end
end
