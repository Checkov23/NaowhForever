-- Trainer.lua: the QoL trainer popup: what you learned, new abilities lit until used, and rank swaps.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Style = ns.Shared.Style

local PLAYER_BANK = Enum.SpellBookSpellBank.Player
local SPELL_ITEM = Enum.SpellBookItemType.Spell
local KEYBOARD_SLOTS = 180
local MAX_ROWS = 8
local ROW_H = 30
local ROW_GAP = 2
local ROW_W = 300
local PAD = 12
local LIST_TOP = 44
local ICON_INSET = 4
local ICON_CROP_LOW, ICON_CROP_HIGH = ns.QoLConstants.ICON_CROP_TIGHT, ns.QoLConstants.ICON_CROP_TIGHT_HIGH
local NAME_GAP, RANK_GAP = 8, 6
local NAME_SIZE, RANK_SIZE, TITLE_SIZE, RANKS_SIZE, MORE_SIZE = 13, 11, 16, 12, 11
local POPUP_W = 324
local POPUP_ALPHA = 0.95
local LOGO_SIZE, LOGO_TOP, TITLE_GAP = 26, 8, 8
local CLOSE_SIZE, CLOSE_INSET = 22, 10
local BUTTON_H, SWAP_W, LATER_W, BUTTON_GAP = 26, 140, 80, 8
local MORE_TOP, MORE_H = 2, 20
local RANKS_TOP, RANKS_ROOM = 8, 14
local BOTTOM_PAD = 14
local DEFAULT_TOP = -160
local GLOW_KEY = "NaowhNewAbility"
local GLOW_LINES, GLOW_THICKNESS = 8, 2
local SHOW_DELAY = 2
local GLOW_EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "PLAYER_ENTERING_WORLD" }

local SETTINGS_PAGE = "QoL/XP"
local TEXT_GLOW_RANKS, TEXT_GLOW, TEXT_RANKS, TEXT_LISTS =
    ns.L("Glows new abilities, offers rank swaps"), ns.L("Glows new abilities"), ns.L("Offers rank swaps"), ns.L("Lists what you learned")
local TEXT_NEW = ns.L("New Abilities")
local TEXT_LOWER = ns.L("Lower Ranks on Your Bars")
local TEXT_MORE = ns.L("+%d more")
local TEXT_KEPT = ns.L("  (kept)")
local TEXT_HOLD = ns.L("%d bar slot(s) hold a lower rank: %s")
local TEXT_UPDATED = ns.L("updated %d bar slot(s): %s")
local TEXT_COUNT = "%s (x%d)"
local TEXT_DRAG = ns.L("Drag onto your bars to place it.")
local TEXT_UNKEEP = ns.L("Right-click to let Update Bars swap it again.")
local TEXT_KEEP = ns.L("Right-click to leave it as it is on your bars when you update them.")
local TEXT_COMBAT = ns.L("leave combat, then check your bars again.")
local TEXT_ALL_TOP = ns.L("every spell on your bars is at its highest rank.")
local TEXT_UPDATE = ns.L("Update Bars")
local TEXT_LATER = ns.L("Later")
local TEXT_CLOSE = "X"

local learned = {}
local listed = {}
local manual = false
local atTrainer, rankTrainer, showQueued, showPending = false, false, false, 0
local popup
local glowing = {}
local glowQueued = false
local charKey
local events = CreateFrame("Frame")
local WatchGlow, Render

local function On()
    return S.Get("enabled") and S.Get("trainerPopup")
end

local function Account(key)
    local account = ns.AccountSettings()
    account[key] = account[key] or {}
    return account[key]
end

local function NewSpells()
    local all = Account("trainerNew")
    charKey = charKey or UnitName("player") .. "-" .. GetRealmName()
    all[charKey] = all[charKey] or {}
    return all[charKey]
end

local function Kept()
    return Account("rankKeep")
end

local function RankOf(subtext)
    return tonumber(subtext and subtext:match("%d+")) or 0
end

local function AddBest(best, slot)
    local item = C_SpellBook.GetSpellBookItemInfo(slot, PLAYER_BANK)
    if not (item and item.itemType == SPELL_ITEM and not item.isPassive) then return end
    local rank = RankOf(item.subName)
    local top = best[item.name]
    if not top or rank > top.rank then
        best[item.name] = { rank = rank, spellID = item.actionID }
    end
end

local function HighestRanks()
    local best = {}
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and not info.isGuild then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                AddBest(best, slot)
            end
        end
    end
    return best
end

local function CheckSlot(slot, best, found)
    local kind, id = GetActionInfo(slot)
    if kind ~= "spell" or not id then return end
    local name = C_Spell.GetSpellName(id)
    local subtext = C_Spell.GetSpellSubtext(id)
    if not (name and best[name] and subtext and subtext ~= "") then return end
    found[#found + 1] = { slot = slot, name = name, id = id, rank = RankOf(subtext) }
end

local function Upgrades()
    local best, kept, found, onBars, out = HighestRanks(), Kept(), {}, {}, {}
    for slot = 1, KEYBOARD_SLOTS do CheckSlot(slot, best, found) end
    local slot = math.max(C_GamepadUI.GetFirstGamepadActionStorageSlotIndex(), KEYBOARD_SLOTS + 1)
    while C_GamepadUI.IsValidGamepadActionStorageSlotIndex(slot) do
        CheckSlot(slot, best, found)
        slot = slot + 1
    end
    for _, f in ipairs(found) do onBars[f.name] = math.max(onBars[f.name] or 0, f.rank) end
    for _, f in ipairs(found) do
        local top = best[f.name]
        if top.spellID ~= f.id and top.rank > f.rank and f.rank == onBars[f.name] then
            out[#out + 1] = { slot = f.slot, name = f.name, spellID = top.spellID, kept = kept[f.name] }
        end
    end
    return out
end

local function Summary(ups)
    local counts, order = {}, {}
    for _, up in ipairs(ups) do
        if not counts[up.name] then order[#order + 1] = up.name end
        counts[up.name] = (counts[up.name] or 0) + 1
    end
    for i, name in ipairs(order) do
        if counts[name] > 1 then order[i] = TEXT_COUNT:format(name, counts[name]) end
    end
    return table.concat(order, ", ")
end

local function WantsGlow(btn, show, new)
    if not (show and btn.action) then return false end
    local kind, id = GetActionInfo(btn.action)
    return kind == "spell" and not (issecretvalue and issecretvalue(id)) and new[id] == true
end

local function RefreshGlow()
    local new = NewSpells()
    local show = On() and S.Get("trainerGlow") and not ns.GamepadStandDown()
    local LCG = LibStub("LibCustomGlow-1.0")
    local color = { T.accent.r, T.accent.g, T.accent.b, 1 }
    for _, btn in pairs(ActionBarButtonEventsFrame.frames) do
        local want = WantsGlow(btn, show, new)
        if want and not glowing[btn] then
            LCG.PixelGlow_Start(btn, color, GLOW_LINES, nil, nil, GLOW_THICKNESS, 0, 0, nil, GLOW_KEY)
            glowing[btn] = true
        elseif not want and glowing[btn] then
            LCG.PixelGlow_Stop(btn, GLOW_KEY)
            glowing[btn] = nil
        end
    end
    WatchGlow()
end

local function RunQueuedGlow()
    glowQueued = false
    RefreshGlow()
end

local function QueueGlow()
    if glowQueued then return end
    glowQueued = true
    C_Timer.After(0, RunQueuedGlow)
end

local function Place()
    local pos = S.Get("trainerPos")
    popup:ClearAllPoints()
    if pos then
        popup:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        popup:SetPoint("TOP", UIParent, "TOP", 0, DEFAULT_TOP)
    end
end

local function ToggleKeep(name)
    local kept = Kept()
    kept[name] = not kept[name] or nil
    Render()
end

local function Swappable()
    local ups = {}
    for _, up in ipairs(Upgrades()) do
        if not up.kept then ups[#ups + 1] = up end
    end
    return ups
end

local function HidePopup()
    popup:Hide()
end

local function SwapRanks()
    if InCombatLockdown() then return end
    local ups = Swappable()
    ClearCursor()
    for _, up in ipairs(ups) do
        C_Spell.PickupSpell(up.spellID)
        PlaceAction(up.slot)
        ClearCursor()
    end
    if #ups > 0 then
        ns.Print(TEXT_UPDATED:format(#ups, Summary(ups)))
    end
    if #Swappable() == 0 then
        popup:Hide()
    else
        Render()
    end
end

local function OnRowDragStart(self)
    if not InCombatLockdown() then C_Spell.PickupSpell(self.spellID) end
end

local function OnRowClick(self)
    ToggleKeep(self.spellName)
end

local function OnRowEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(self.spellID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TEXT_DRAG, 1, 1, 1)
    GameTooltip:AddLine(Kept()[self.spellName] and TEXT_UNKEEP or TEXT_KEEP, 1, 1, 1)
    GameTooltip:Show()
end

local function BuildRow(i)
    local row = CreateFrame("Button", nil, popup)
    row:SetSize(ROW_W, ROW_H - ROW_GAP)
    row:SetPoint("TOPLEFT", PAD, -LIST_TOP - (i - 1) * ROW_H)
    row:RegisterForClicks("RightButtonUp")
    row:RegisterForDrag("LeftButton")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - ICON_INSET, ROW_H - ICON_INSET)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(ICON_CROP_LOW, ICON_CROP_HIGH, ICON_CROP_LOW, ICON_CROP_HIGH)

    row.name = ns.Font(row, NAME_SIZE, nil)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
    row.rank = ns.Font(row, RANK_SIZE, nil, T.muted)
    row.rank:SetPoint("LEFT", row.name, "RIGHT", RANK_GAP, 0)

    row:SetScript("OnDragStart", OnRowDragStart)
    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function OnPopupDragStop(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    S.Set("trainerPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Build()
    popup = CreateFrame("Frame", "NaowhForeverTrainer", UIParent)
    popup:SetWidth(POPUP_W)
    popup:SetFrameStrata("MEDIUM")
    popup:SetMovable(true)
    popup:SetClampedToScreen(true)
    ns.AllowOffscreen(popup)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", OnPopupDragStop)
    ns.Solid(popup, "BACKGROUND", T.bg, POPUP_ALPHA):SetAllPoints()
    ns.Border(popup)

    local logo = popup:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO_SMALL, nil, nil, "TRILINEAR")
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetPoint("TOPLEFT", PAD, -LOGO_TOP)

    popup.title = ns.Font(popup, TITLE_SIZE, "OUTLINE", T.accent)
    popup.title:SetPoint("LEFT", logo, "RIGHT", TITLE_GAP, 0)

    local close = ns.Button(popup, TEXT_CLOSE, CLOSE_SIZE, CLOSE_SIZE, HidePopup)
    close:SetPoint("TOPRIGHT", -CLOSE_INSET, -CLOSE_INSET)

    popup.rows = {}
    for i = 1, MAX_ROWS do popup.rows[i] = BuildRow(i) end

    popup.more = ns.Font(popup, MORE_SIZE, nil, T.muted)
    popup.ranks = ns.Font(popup, RANKS_SIZE, nil)
    popup.ranks:SetWidth(ROW_W)
    popup.ranks:SetJustifyH("LEFT")
    popup.ranks:SetWordWrap(true)

    popup.swap = ns.Button(popup, TEXT_UPDATE, SWAP_W, BUTTON_H, SwapRanks)
    popup.later = ns.Button(popup, TEXT_LATER, LATER_W, BUTTON_H, HidePopup)
    popup:Hide()
end

local function Rows(ups)
    local rows, seen, swappable = {}, {}, {}
    for _, id in ipairs(listed) do
        rows[#rows + 1] = id
        seen[C_Spell.GetSpellName(id) or id] = true
    end
    for _, up in ipairs(ups) do
        if not seen[up.name] then
            rows[#rows + 1] = up.spellID
            seen[up.name] = true
        end
        if not up.kept then swappable[#swappable + 1] = up end
    end
    return rows, swappable
end

local function FillRows(rows)
    local kept = Kept()
    local shown = math.min(#rows, MAX_ROWS)
    for i, row in ipairs(popup.rows) do
        local id = rows[i]
        if i <= shown then
            row.spellID, row.spellName = id, C_Spell.GetSpellName(id)
            row.icon:SetTexture(C_Spell.GetSpellTexture(id))
            row.name:SetText(row.spellName)
            local rank = C_Spell.GetSpellSubtext(id) or ""
            row.rank:SetText(kept[row.spellName] and (rank .. TEXT_KEPT) or rank)
            row:Show()
        else
            row:Hide()
        end
    end
    return -LIST_TOP - shown * ROW_H
end

local function LayoutMore(rows, y)
    popup.more:ClearAllPoints()
    if #rows <= MAX_ROWS then
        popup.more:Hide()
        return y
    end
    popup.more:SetPoint("TOPLEFT", PAD, y - MORE_TOP)
    popup.more:SetText(TEXT_MORE:format(#rows - MAX_ROWS))
    popup.more:Show()
    return y - MORE_H
end

local function LayoutSwap(swappable, y)
    popup.ranks:ClearAllPoints()
    popup.swap:ClearAllPoints()
    popup.later:ClearAllPoints()
    if #swappable == 0 then
        popup.ranks:Hide()
        popup.swap:Hide()
        popup.later:Hide()
        return y
    end
    popup.ranks:SetPoint("TOPLEFT", PAD, y - RANKS_TOP)
    popup.ranks:SetText(TEXT_HOLD:format(#swappable, Summary(swappable)))
    popup.ranks:Show()
    y = y - RANKS_ROOM - popup.ranks:GetStringHeight()
    popup.swap:SetPoint("TOPLEFT", PAD, y)
    popup.swap:Show()
    popup.later:SetPoint("LEFT", popup.swap, "RIGHT", BUTTON_GAP, 0)
    popup.later:Show()
    return y - BUTTON_H
end

Render = function()
    local ups = (manual or S.Get("trainerRanks")) and Upgrades() or {}
    local rows, swappable = Rows(ups)
    if #rows == 0 or (#listed == 0 and not manual and #swappable == 0) then
        if popup then popup:Hide() end
        return false
    end
    if not popup then Build() end
    popup.title:SetText(#listed > 0 and TEXT_NEW or TEXT_LOWER)
    local y = FillRows(rows)
    y = LayoutMore(rows, y)
    y = LayoutSwap(swappable, y)
    popup:SetHeight(-y + BOTTOM_PAD)
    Place()
    popup:Show()
    return true
end

local function Show()
    if not On() then return end
    if InCombatLockdown() then
        showQueued = true
        return
    end
    showQueued = false
    if #learned > 0 then listed, learned, manual = learned, {}, false end
    Render()
end

local function OnShowTimer()
    showPending = showPending - 1
    if showPending == 0 and not atTrainer then Show() end
end

local function IsRecipe(spellID)
    return (atTrainer and IsTradeskillTrainer()) or C_TradeSkillUI.GetRecipeInfo(spellID) ~= nil
end

local function Learned(spellID)
    if C_Spell.IsSpellPassive(spellID) or IsRecipe(spellID) then return end
    learned[#learned + 1] = spellID
    if S.Get("trainerGlow") and not ns.GamepadStandDown() then
        NewSpells()[spellID] = true
        WatchGlow()
        QueueGlow()
    end
    if atTrainer then return end
    showPending = showPending + 1
    C_Timer.After(SHOW_DELAY, OnShowTimer)
end

local function Used(spellID)
    if issecretvalue and issecretvalue(spellID) then return end
    local new = NewSpells()
    if new[spellID] then
        new[spellID] = nil
        QueueGlow()
    end
end

local function OnEvent(_, event, arg1, _, arg3)
    if event == "LEARNED_SPELL_IN_SKILL_LINE" then
        Learned(arg1)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        Used(arg3)
    elseif event == "TRAINER_SHOW" then
        atTrainer = true
        rankTrainer = not IsTradeskillTrainer()
    elseif event == "TRAINER_CLOSED" then
        local ranks = atTrainer and rankTrainer and S.Get("trainerRanks")
        atTrainer, rankTrainer = false, false
        if #learned > 0 or ranks then
            listed, manual = {}, false
            Show()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if popup and popup:IsShown() then
            popup:Hide()
            showQueued = true
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if showQueued then Show() end
    else
        QueueGlow()
    end
end

function WatchGlow()
    local watch = On() and S.Get("trainerGlow") and not ns.GamepadStandDown()
        and (next(NewSpells()) ~= nil or next(glowing) ~= nil)
    if watch then
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        for _, event in ipairs(GLOW_EVENTS) do events:RegisterEvent(event) end
    else
        events:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        for _, event in ipairs(GLOW_EVENTS) do events:UnregisterEvent(event) end
    end
end

function ns.TrainerRankCheck()
    if InCombatLockdown() then
        ns.Print(TEXT_COMBAT)
        return
    end
    listed, manual = {}, true
    if not Render() then
        ns.Print(TEXT_ALL_TOP)
    end
end

function ns.TrainerForgetKept()
    ns.AccountSettings().rankKeep = {}
    if popup and popup:IsShown() then Render() end
end

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        learned, listed = {}, {}
        showQueued, atTrainer, rankTrainer = false, false, false
        if popup then popup:Hide() end
        if next(glowing) then RefreshGlow() end
        return
    end
    events:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
    events:RegisterEvent("TRAINER_SHOW")
    events:RegisterEvent("TRAINER_CLOSED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    WatchGlow()
    QueueGlow()
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or (key:find("^trainer") and key ~= "trainerPos") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local function ResetPosition()
    S.Set("trainerPos", nil)
    if popup then Place() end
end

local function TrainerSummary(store)
    local glow, ranks = store.Get("trainerGlow"), store.Get("trainerRanks")
    if glow and ranks then return TEXT_GLOW_RANKS end
    if glow then return TEXT_GLOW end
    if ranks then return TEXT_RANKS end
    return TEXT_LISTS
end

Settings.Page(SETTINGS_PAGE, S):Card({
    id = "trainer", name = "Trainer Popup", order = 50, switch = "trainerPopup",
    help = "After visiting a trainer, a small window lists the abilities you just learned. Abilities from a "
        .. "tome or a quest show a moment after you learn them. Drag one from the window onto your bars.",
    summary = TrainerSummary,
    rows = {
        { key = "trainerGlow", label = "Glow New Abilities", toggle = true,
          needs = ns.GamepadFree, why = ns.GamepadWhy,
          help = "Lights up the new abilities on your action bars until you use them." },
        { key = "trainerRanks", label = "Offer to Replace Lower Ranks", toggle = true,
          help = "Adds a button to the popup that swaps every lower rank on your bars for the highest rank "
              .. "you know. Keyboard and controller bars land in the same slot. Right-click a spell in the "
              .. "popup to keep its lower ranks, for downranking. Rank swaps only happen out of combat." },
        { label = "Check My Bars Now", buttonText = "Check Bars", always = true,
          button = ns.TrainerRankCheck,
          help = "Looks for lower ranks on your bars now, as after a trainer visit (also /naowh ranks). Out of "
              .. "combat only." },
        { label = "Forget Kept Spells", buttonText = "Forget Kept", always = true,
          button = ns.TrainerForgetKept,
          help = "Forgets the spells you chose to keep at lower ranks, so the popup offers to swap them again." },
        { label = "Popup Position", buttonText = "Reset", button = ResetPosition, always = true,
          help = "Puts the popup back where it first showed." },
    },
})
