-- Cells.lua: the parts the BiS List's rows share: the gain, where an item drops, and their hover zones (B.View.Cells).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local R = B.Rankings
local Shared = ns.Shared
local Items, Parts = Shared.Items, Shared.Parts
local Tip = Parts.Tip
local St = B.Style

local PLACE_DOT, RED_CODE = St.PLACE_DOT, St.RED_CODE
local NAME_GAP, TIP_X = St.NAME_GAP, St.CURSOR_TIP_X
local GAIN_W, GAIN_H, GAIN_BAR_H, GAIN_BAR_MIN = 44, 18, 2, 2
local GAIN_BIG, GAIN_SMALL = 10, 2
local GAIN_BIG_RGB, GAIN_RGB, GAIN_SMALL_RGB = St.GAIN_BIG_RGB, St.GAIN_RGB, St.GAIN_SMALL_RGB
local SOURCE_H = 16
local NO_LEVEL = 1
local ROUND = B.C.ROUND
local TEXT_UNKNOWN = ns.L("World drop")
local TEXT_QUEST = "Quest"
local TEXT_LEVEL = ns.L("Level ")
local TEXT_ITEM = ns.L("Item ")
local OWN_QUEST = { Alliance = ns.L("Quest (Alliance)"), Horde = ns.L("Quest (Horde)") }
local FOREVER_KIND = B.C.FOREVER_KIND

local gainWords = {}
local metas = { [true] = {}, [false] = {} }
local metaAbove = { [true] = {}, [false] = {} }
local keptTails = { [""] = "" }
local ownQuest

local function GainWords(percent)
    local words = gainWords[percent]
    if not words then
        words = "+" .. percent .. "%"
        gainWords[percent] = words
    end
    return words
end

local function GainColor(gain)
    if gain >= GAIN_BIG then return GAIN_BIG_RGB end
    if gain < GAIN_SMALL then return GAIN_SMALL_RGB end
    return GAIN_RGB
end

local function Place(itemID)
    local place, detail = R.Place(ns.BiSSource(itemID) or TEXT_UNKNOWN)
    ownQuest = ownQuest or OWN_QUEST[UnitFactionGroup("player")] or false
    if place == ownQuest then place = TEXT_QUEST end
    return place, detail
end

local function LevelText(required, above, withLevel)
    if not (required and required > NO_LEVEL and (above or withLevel)) then return "" end
    return PLACE_DOT .. (above and RED_CODE or "") .. TEXT_LEVEL .. required .. (above and "|r" or "")
end

local function TipLeave(zone)
    GameTooltip:Hide()
    local row = zone:GetParent()
    if not row:IsMouseOver() then row:GetScript("OnLeave")(row) end
end

local function SourceEnter(zone)
    local row = zone:GetParent()
    local meta = row.meta
    local soft, muted = T.accentSoft, T.muted
    meta:SetTextColor(soft.r, soft.g, soft.b)
    if not Tip(zone, "ANCHOR_TOP") then return end
    if meta:IsTruncated() then
        GameTooltip:SetText(meta:GetText(), muted.r, muted.g, muted.b)
        GameTooltip:AddLine(B.Sources.Hint(zone.itemID), soft.r, soft.g, soft.b)
    else
        GameTooltip:SetText(B.Sources.Hint(zone.itemID), soft.r, soft.g, soft.b)
    end
    GameTooltip:Show()
end

local function SourceLeave(zone)
    local row = zone:GetParent()
    row.meta:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Hide()
    if not row:IsMouseOver() then row:GetScript("OnLeave")(row) end
end

local function SourceClicked(zone)
    GameTooltip:Hide()
    B.Sources.Go(zone.itemID)
end

local Cells = {}
B.View.Cells = Cells

function Cells.OpenPicker(slot, from)
    B.OpenPicker(slot, from)
end

function Cells.Gain(row, anchor, gap)
    local cell = CreateFrame("Frame", nil, row)
    cell:SetSize(GAIN_W, GAIN_H)
    cell:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
    cell.bar = ns.Solid(cell, "ARTWORK", GAIN_BIG_RGB, 1)
    cell.bar:SetPoint("BOTTOMRIGHT")
    cell.bar:SetHeight(GAIN_BAR_H)
    cell.text = ns.Font(cell, St.TEXT_SIZE)
    cell.text:SetPoint("TOPRIGHT", 0, 0)
    cell.text:SetJustifyH("RIGHT")
    row.gain = cell
end

function Cells.PaintGain(cell, gain, most)
    if not gain then
        cell:Hide()
        return
    end
    cell.text:SetText(GainWords(math.max(1, math.floor(gain + ROUND))))
    local color = GainColor(gain)
    cell.text:SetTextColor(color.r, color.g, color.b)
    local share = most and most > 0 and math.sqrt(math.min(1, gain / most)) or 1
    cell.bar:SetWidth(math.max(GAIN_BAR_MIN, math.floor(GAIN_W * share + ROUND)))
    cell.bar:SetColorTexture(color.r, color.g, color.b, 1)
    cell:Show()
end

function Cells.Meta(itemID, playerLevel, withLevel)
    local required = R.ReqLevel(itemID)
    local above = required ~= nil and required > playerLevel
    withLevel = withLevel == true
    local meta = metas[withLevel][itemID]
    if meta and metaAbove[withLevel][itemID] == above then return meta end
    local place, detail = Place(itemID)
    local weapon = Items.WeaponOf(itemID)
    meta = (weapon and weapon .. PLACE_DOT or "") .. (detail and detail .. PLACE_DOT or "") .. place
        .. LevelText(required, above, withLevel)
    metas[withLevel][itemID], metaAbove[withLevel][itemID] = meta, above
    return meta
end

function Cells.KeptTail(kept)
    local tail = keptTails[kept]
    if not tail then
        tail = PLACE_DOT .. kept
        keptTails[kept] = tail
    end
    return tail
end

function Cells.Named(itemID, name)
    return Items.QualityHex(itemID) .. (name or (TEXT_ITEM .. itemID)) .. "|r"
end

function Cells.ForeverTip(itemID)
    if Parts.IsForever(FOREVER_KIND, itemID) then GameTooltip:AddLine(Parts.ForeverLine()) end
end

function Cells.ItemTip(owner, itemID, hint)
    if not Tip(owner, "ANCHOR_CURSOR_RIGHT", TIP_X, 0) then return end
    GameTooltip:SetItemByID(itemID)
    Cells.ForeverTip(itemID)
    if hint then GameTooltip:AddLine(hint, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:Show()
end

function Cells.TipZone(row, icon, height, onEnter)
    local zone = CreateFrame("Frame", nil, row)
    zone:SetPoint("LEFT", icon, "LEFT")
    zone:SetHeight(height)
    zone:SetScript("OnEnter", onEnter)
    zone:SetScript("OnLeave", TipLeave)
    zone:SetMouseMotionEnabled(true)
    zone:SetMouseClickEnabled(false)
    row.tipZone = zone
end

function Cells.FitTip(row)
    local name = row.name
    local text, room = name:GetStringWidth(), name:GetWidth()
    row.tipZone:SetWidth(row.iconFrame:GetWidth() + NAME_GAP + (room > 0 and math.min(text, room) or text))
end

function Cells.SourceZone(row)
    local zone = CreateFrame("Button", nil, row)
    zone:SetPoint("LEFT", row.meta, "LEFT")
    zone:SetHeight(SOURCE_H)
    zone:SetScript("OnEnter", SourceEnter)
    zone:SetScript("OnLeave", SourceLeave)
    zone:SetScript("OnClick", SourceClicked)
    row.source = zone
end

function Cells.FitSource(row, itemID)
    local zone, meta = row.source, row.meta
    zone.itemID = itemID
    zone:SetShown(itemID ~= nil)
    local text, room = meta:GetStringWidth(), meta:GetWidth()
    zone:SetWidth(math.max(1, room > 0 and math.min(text, room) or text))
end
