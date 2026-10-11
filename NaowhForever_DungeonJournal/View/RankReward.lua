-- RankReward.lua: a rank reward that is not an item: a title, a mount, an appearance, or what it unlocks at its vendor.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Kinds, Parts = J.View.Kinds, J.View.Parts
local Tip = Parts.Tip
local KEPT_CODE = ns.Shared.Items.KEPT_CODE
local St = J.Style
local BORDER_RGB, ICON, ITEM_H, PLACE_DOT, QUESTION_ICON = St.BORDER_RGB, St.ICON, St.ITEM_H, St.PLACE_DOT,
    St.QUESTION_ICON
local TEXT_SIZE, SMALL_SIZE, TIP_X = St.TEXT_SIZE, St.SMALL_SIZE, St.CURSOR_TIP_X
local CROP_LOW, CROP_HIGH = St.ICON_CROP, St.ICON_CROP_HIGH

local TEXT_GAP = 8
local TEXT_NUDGE = 1
local MOUNT_SPELL = 2
local FIRST_LINE = "^[^\n]+"

local TEXT_REWARD = ns.L("Reward")
local TEXT_COLLECTED = ns.L("   %sCollected|r")
local KIND_WORDS = {
    { "mountID", ns.L("Mount") }, { "titleMaskID", ns.L("Title") }, { "transmogSetID", ns.L("Appearance set") },
    { "transmogID", ns.L("Appearance") }, { "transmogIllusionSourceID", ns.L("Illusion") }, { "spellID", ns.L("Spell") },
}

local described = {}

local function RewardKind(reward)
    for i = 1, #KIND_WORDS do
        local kind = KIND_WORDS[i]
        if reward[kind[1]] then return kind[2] end
    end
    return nil
end

local function Described(reward)
    local text = reward.description
    if not text or text == "" then return nil end
    local line = described[text]
    if not line then
        line = Parts.Plain((text:match(FIRST_LINE) or text))
        described[text] = line
    end
    return line
end

local function RewardEnter(row)
    local reward = row.reward
    if not Tip(row, "ANCHOR_CURSOR_RIGHT", TIP_X, 0) then return end
    local itemID = reward.itemID or reward.transmogID and C_Transmog.GetItemIDForSource(reward.transmogID)
    local mountSpell = reward.mountID and select(MOUNT_SPELL, C_MountJournal.GetMountInfoByID(reward.mountID))
    if itemID then
        GameTooltip:SetItemByID(itemID)
    elseif mountSpell or reward.spellID then
        GameTooltip:SetSpellByID(mountSpell or reward.spellID)
    else
        GameTooltip:SetText(reward.name or RewardKind(reward) or TEXT_REWARD, 1, 1, 1)
        if reward.description then GameTooltip:AddLine(reward.description, nil, nil, nil, true) end
    end
    GameTooltip:Show()
end

local function MetaText(kind, text)
    if kind and text then return kind .. PLACE_DOT .. text end
    return text or kind or TEXT_REWARD
end

Kinds.reward = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        local frame = CreateFrame("Frame", nil, row)
        frame:SetSize(ICON, ICON)
        frame:SetPoint("LEFT", 0, 0)
        ns.Border(frame, BORDER_RGB)
        row.icon = frame:CreateTexture(nil, "ARTWORK")
        ns.PixelInset(row.icon, 1)
        row.icon:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
        row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
        row.name:SetPoint("TOPLEFT", frame, "TOPRIGHT", TEXT_GAP, -TEXT_NUDGE)
        row.name:SetPoint("RIGHT")
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.meta = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.meta:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", TEXT_GAP, TEXT_NUDGE)
        row.meta:SetPoint("RIGHT")
        row.meta:SetJustifyH("LEFT")
        row.meta:SetWordWrap(false)
        row:EnableMouse(true)
        row:SetScript("OnEnter", RewardEnter)
        row:SetScript("OnLeave", GameTooltip_Hide)
        return row
    end,
    Set = function(row, reward)
        row.reward = reward
        row.icon:SetTexture(reward.icon or QUESTION_ICON)
        local kind, text = RewardKind(reward), Described(reward)
        row.name:SetText(reward.name or text or kind or TEXT_REWARD)
        row.meta:SetText(MetaText(kind, text) .. (reward.isCollected and TEXT_COLLECTED:format(KEPT_CODE) or ""))
        return ITEM_H
    end,
}
