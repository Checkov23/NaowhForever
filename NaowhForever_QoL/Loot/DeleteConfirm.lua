-- DeleteConfirm.lua: Type DELETE For You, the delete confirmation filled in and the item named as a link.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local DIALOGS = { DELETE_ITEM = true, DELETE_QUEST_ITEM = true, DELETE_GOOD_ITEM = true,
    DELETE_GOOD_QUEST_ITEM = true }
local LINK_GAP = "\n\n"

local hooked = {}

local function StripInstruction(text)
    local cut = DELETE_GOOD_ITEM:find("\n")
    if not cut then return text end
    local instruction = strtrim((DELETE_GOOD_ITEM:sub(cut):gsub("%%s", "")))
    if instruction == "" then return text end
    local at = text:find(instruction, 1, true)
    return at and strtrim(text:sub(1, at - 1)) or text
end

local function LinkEnter(self, link)
    if not DIALOGS[self.which] then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

local function LinkLeave(self)
    if DIALOGS[self.which] then GameTooltip:Hide() end
end

local function HookLinks(dialog)
    if hooked[dialog] then return end
    hooked[dialog] = true
    dialog:HookScript("OnHyperlinkEnter", LinkEnter)
    dialog:HookScript("OnHyperlinkLeave", LinkLeave)
end

local function FillBox(dialog, which)
    local editBox = _G[dialog:GetName() .. "EditBox"]
    if not editBox:IsShown() then return end
    editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
    local check = StaticPopupDialogs[which].EditBoxOnTextChanged
    if check then check(editBox, dialog.data) end
end

local function NameItem(dialog)
    local kind, _, link = GetCursorInfo()
    if kind ~= "item" or not link then return end
    local text = _G[dialog:GetName() .. "Text"]
    text:SetText(StripInstruction(text:GetText() or "") .. LINK_GAP .. link)
    dialog:Resize()
end

local function OnPopupShow(which)
    if not (DIALOGS[which] and S.Get("enabled") and S.Get("deleteConfirm")) then return end
    local dialog = StaticPopup_FindVisible(which)
    if not dialog then return end
    HookLinks(dialog)
    FillBox(dialog, which)
    NameItem(dialog)
end

hooksecurefunc("StaticPopup_Show", OnPopupShow)

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "looting", name = "Looting", order = 10,
    help = "Fewer clicks around loot and items: the delete confirmation filled in, and auto loot that "
        .. "keeps the loot window.",
    rows = {
        { key = "deleteConfirm", label = "Type DELETE For You", toggle = true,
          help = "Types DELETE into the confirmation box for you, and names the item in the dialog as a "
              .. "link you can hover for its tooltip." },
        { key = "fastLoot", label = "Faster Auto Loot", toggle = true,
          help = "Loots automatically without hiding the loot window. Hold Shift to loot manually." },
    },
})
