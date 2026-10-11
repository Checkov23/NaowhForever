-- BossTips.lua: Naowh's tips: their tooltip lines, sharing one in chat, and the tip row on a boss's page.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Kinds, Parts = J.View.Kinds, J.View.Parts
local St = J.Style
local TIP_RGB, TEXT_SIZE = St.TIP_RGB, St.TEXT_SIZE

local CHAT_MAX = 255
local ELLIPSIS = "..."
local MARK = 14
local TIP_MARK = St.ICON
local TEXT_GAP = 8
local ROW_PAD = 5
local DENSE_PAD = St.CARD_BOTTOM
local SHARE = St.ACTION
local BUBBLE = "Interface\\GossipFrame\\GossipGossipIcon"

local TIP_TEXT = "Naowh's tip for %s: %s"
local TEXT_SHARE_TITLE = ns.L("Share Naowh's tip")
local TEXT_COPY_TITLE = ns.L("Naowh's tip: ")
local TEXT_TIP = ns.L("Naowh's tip")
local TEXT_CLICK_SHARE = ns.L("Click: share in chat")
local TEXT_SHARE_BUTTON = ns.L("Share Naowh's tip in chat")
local TEXT_BLANK = " "

local function TipMessage(boss, tip)
    local text = TIP_TEXT:format(boss.name, tip)
    if #text > CHAT_MAX then text = text:sub(1, CHAT_MAX - #ELLIPSIS) .. ELLIPSIS end
    return text
end

function Parts.ShareTip(owner, boss, tip)
    local name = boss.name
    Parts.ShareMenu(owner, TEXT_SHARE_TITLE, TipMessage(boss, tip), TEXT_COPY_TITLE .. name,
        TIP_TEXT:format(name, tip), nil, nil, true)
end

function Parts.OpenTipMenu(button)
    if button.tip then Parts.ShareTip(button, button.boss, button.tip) end
end

function Parts.AddTip(tip)
    GameTooltip:AddLine(TEXT_TIP, TIP_RGB.r, TIP_RGB.g, TIP_RGB.b)
    GameTooltip:AddLine(tip, 1, 1, 1, true)
    GameTooltip:AddLine(TEXT_BLANK)
    GameTooltip:AddLine(TEXT_CLICK_SHARE, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
end

local function ShareClicked(button)
    Parts.ShareTip(button, button.boss, button.tipText)
end

Kinds.tip = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetTexture(St.LOGO_SMALL, nil, nil, "TRILINEAR")
        row.share = Parts.IconButton(row, ShareClicked, BUBBLE, 0, TEXT_SHARE_BUTTON)
        row.text = ns.Font(row, TEXT_SIZE, nil, T.fg)
        row.text:SetPoint("TOPLEFT", row.mark, "TOPRIGHT", TEXT_GAP, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(true)
        return row
    end,
    Set = function(row, boss, tip)
        local dense = row:GetParent().dense
        local mark, pad = dense and MARK or TIP_MARK, dense and DENSE_PAD or ROW_PAD
        row.mark:SetSize(mark, mark)
        row.mark:SetPoint("TOPLEFT", 0, -pad)
        row.share:SetPoint("RIGHT", 0, dense and -pad / 2 or 0)
        row.share.boss, row.share.tipText = boss, tip
        row.text:SetWidth(row:GetWidth() - mark - TEXT_GAP * 2 - SHARE)
        row.text:SetText(tip)
        local text = row.text:GetStringHeight()
        row.text:SetPoint("TOPLEFT", row.mark, "TOPRIGHT", TEXT_GAP, -math.max(0, (mark - text) / 2))
        return math.ceil(math.max(mark, text)) + (dense and pad or pad * 2)
    end,
}
