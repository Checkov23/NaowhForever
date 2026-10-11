-- ProfitLines.lua: lines of amounts under a recipe, lined up, and the crafting profit drawn with them.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local Prices = P.Prices
local Text = P.Text
local Style = P.Style

local LABEL_W, VALUE_W, GAP = 58, 96, 8
local NOTE_GAP = Style.NOTE_GAP
local TEXT_NONE = "-|r"
local TEXT_BUY, TEXT_SELL, TEXT_PROFIT = ns.L("Buy for:"), ns.L("Sell for:"), ns.L("Profit:")
local TEXT_UNPRICED = ns.L("+ %d unpriced")
local TEXT_NOT_LISTED = ns.L("not listed at the last scan")
local TEXT_FOR = ns.L("for %d")
local TEXT_NO_PRICES = ns.L("some reagents have no price")
local TEXT_AFTER_CUT = ns.L("after the 5% cut")
local TIP_TITLE = ns.L("Crafting Profit")
local TIP_PART = "%s x%d"
local TIP_HAVE = ns.L("you have it")
local TIP_VENDOR, TIP_AH = ns.L("  (vendor)"), "  (AH)"
local TIP_NO_PRICE = ns.L("no price")
local TIP_TO_BUY, TIP_MATERIALS = ns.L("Materials to buy"), ns.L("Materials")
local TIP_SELLS = ns.L("Sells for, less 5% cut")
local TIP_HELP = ns.L("Vendor prices are the ones last seen at a merchant; the rest are the "
    .. "lowest buyouts at your last auction house scan. Uncheck a reagent you already have "
    .. "to leave it out of the cost.")
local TEXT_ITEM = ns.L("Item ")

local Lines = {}
P.Lines = Lines

function Lines.Build(parent, keys)
    local block = CreateFrame("Frame", nil, parent)
    block:SetSize(Style.PANE_INNER_W, #keys * Style.PROFIT_LINE)
    block:EnableMouse(true)
    block.lines = {}
    for i, key in ipairs(keys) do
        local line = CreateFrame("Frame", nil, block)
        line:SetPoint("TOPLEFT", 0, -(i - 1) * Style.PROFIT_LINE)
        line:SetPoint("RIGHT")
        line:SetHeight(Style.PROFIT_LINE)
        line.label = ns.Font(line, Style.FONT, nil, Style.GOLD_RGB)
        line.label:SetPoint("LEFT")
        line.value = ns.Font(line, Style.FONT, nil)
        line.value:SetPoint("LEFT", LABEL_W, 0)
        line.value:SetWidth(VALUE_W)
        line.value:SetJustifyH("RIGHT")
        line.value:SetWordWrap(false)
        line.note = ns.Font(line, Style.FONT, nil, T.muted)
        line.note:SetPoint("LEFT", line.value, "RIGHT", NOTE_GAP, 0)
        line.note:SetPoint("RIGHT")
        line.note:SetJustifyH("LEFT")
        line.note:SetWordWrap(false)
        block[key] = line
        block.lines[i] = line
    end
    block:SetScript("OnLeave", GameTooltip_Hide)
    block:Hide()
    return block
end

function Lines.Set(line, label, value, note)
    line.label:SetText(label or "")
    line.value:SetText(value or "")
    line.note:SetText(note or "")
    line:SetShown(value ~= nil)
end

function Lines.Fit(lines)
    local labelW, valueW = 0, 0
    for _, line in ipairs(lines) do
        if line:IsShown() then
            labelW = math.max(labelW, line.label:GetStringWidth())
            valueW = math.max(valueW, line.value:GetStringWidth())
        end
    end
    for _, line in ipairs(lines) do
        line.value:ClearAllPoints()
        line.value:SetPoint("LEFT", math.ceil(labelW) + GAP, 0)
        line.value:SetWidth(math.ceil(valueW) + 1)
    end
end

function Lines.None()
    return Text.Hex(T.muted) .. TEXT_NONE
end

local function PartPrice(p)
    if p.owned then return ns.Color("muted", TIP_HAVE) end
    if p.each then
        return Text.Money(p.each * p.need) .. (p.from == Prices.FROM_VENDOR and TIP_VENDOR or TIP_AH)
    end
    return TIP_NO_PRICE
end

local function OnProfitEnter(self)
    local v = self.value
    if not v then return end
    local gold = Style.GOLD_RGB
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(TIP_TITLE, gold.r, gold.g, gold.b)
    for _, p in ipairs(v.parts) do
        local name = C_Item.GetItemNameByID(p.itemID) or (TEXT_ITEM .. p.itemID)
        GameTooltip:AddDoubleLine(TIP_PART:format(name, p.need), PartPrice(p), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(v.owned > 0 and TIP_TO_BUY or TIP_MATERIALS, Text.Money(v.cost),
        gold.r, gold.g, gold.b, 1, 1, 1)
    if v.sale then
        GameTooltip:AddDoubleLine(TIP_SELLS, Text.Money(v.sale), gold.r, gold.g, gold.b, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TIP_HELP, T.muted.r, T.muted.g, T.muted.b, true)
    if ns.AuctionScanSummary then
        GameTooltip:AddLine(ns.AuctionScanSummary(), T.muted.r, T.muted.g, T.muted.b, true)
    end
    GameTooltip:Show()
end

function Lines.BuildProfit(parent)
    local block = Lines.Build(parent, { "buy", "sell", "profit" })
    block.calc = { parts = {} }
    block:SetScript("OnEnter", OnProfitEnter)
    return block
end

local function SellLines(v, output)
    if not output then return end
    local sell = v.each and Text.Money(v.each * v.made) or Lines.None()
    local sellNote = not v.each and TEXT_NOT_LISTED or v.made > 1 and TEXT_FOR:format(v.made) or nil
    if not v.sale then return sell, sellNote, Lines.None() end
    if v.missing > 0 then return sell, sellNote, Lines.None(), TEXT_NO_PRICES end
    local p = v.sale - v.cost
    local profit = Text.Hex(p >= 0 and Style.PROFIT_RGB or Style.RED_RGB) .. Text.Money(p, true) .. "|r"
    return sell, sellNote, profit, TEXT_AFTER_CUT
end

function Lines.RenderProfit(block, recipeID, output, made)
    if not (S.Get("craftProfit") and ns.AuctionScanTime and ns.AuctionScanTime()) then
        block.value = nil
        return block:Hide()
    end
    local v = Prices.CraftValue(recipeID, output, made, block.calc)
    block.value = v
    if #v.parts == 0 then
        block.value = nil
        return block:Hide()
    end
    Lines.Set(block.buy, TEXT_BUY, Text.Money(v.cost), v.missing > 0 and TEXT_UNPRICED:format(v.missing) or nil)
    local sell, sellNote, profit, profitNote = SellLines(v, output)
    Lines.Set(block.sell, TEXT_SELL, sell, sellNote)
    Lines.Set(block.profit, TEXT_PROFIT, profit, profitNote)
    Lines.Fit(block.lines)
    block:Show()
end
