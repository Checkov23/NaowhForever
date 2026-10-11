-- Popup.lua: Boss Loot at Cursor: the loot of the boss you hover or target, in a small panel at the mouse.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local St = J.Style
local PANEL_W, PANEL_PAD, PANEL_HEADER = St.PANEL_W, St.PANEL_PAD, St.PANEL_HEADER

local CURSOR_OFFSET = 12
local VIEW_TOP = 4
local CARD_INSET = 4

local TEXT_HOVER = ns.L("Hover or target a boss, then press the key again.")
local TEXT_UNREADABLE = ns.L("That is not a boss the Dungeon Journal can read right now.")
local TEXT_UNKNOWN = ns.L("%s is not a boss the Dungeon Journal knows.")
local TEXT_THAT = ns.L("That")

local popup, view

local function Drawn(height)
    popup:SetHeight(height + PANEL_HEADER + VIEW_TOP + PANEL_PAD)
end

local function Build()
    popup = J.View.Parts.Panel("", true)
    popup.backdrop:Card(CARD_INSET, PANEL_HEADER, CARD_INSET, CARD_INSET)
    popup.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    popup:SetFrameStrata("DIALOG")
    view = J.View.New(popup)
    view:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_HEADER - VIEW_TOP)
    view:SetWidth(PANEL_W - PANEL_PAD * 2)
    view.onResize = Drawn
    popup:HookScript("OnHide", J.View.ForgetMapLoot)
end

local function Open(boss, dungeon)
    if not popup then Build() end
    local x, y = GetCursorPosition()
    popup:SetScale(ns.UIScale())
    local scale = popup:GetEffectiveScale()
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + CURSOR_OFFSET, y / scale - CURSOR_OFFSET)
    popup.title:SetText(dungeon.name:upper())
    popup.backdrop:Paint(S.Get("mapAlpha") or 1)
    popup:Show()
    view:DrawBossLoot(boss, dungeon)
end

local function HoveredNpc()
    local unit = UnitExists("mouseover") and "mouseover" or "target"
    if not UnitExists(unit) then return nil, unit, TEXT_HOVER end
    local guid = UnitGUID(unit)
    local npc = guid and not issecretvalue(guid) and J.NpcID(guid)
    if not npc then return nil, unit, TEXT_UNREADABLE end
    return npc, unit
end

local function OnSettingChanged(key, value)
    if key == "enabled" and not value and popup then popup:Hide() end
end

J.View.OpenBossLoot = Open

function J.View.CloseBossLoot()
    if popup then popup:Hide() end
end

function NaowhForever_BossLoot()
    if popup and popup:IsShown() then
        popup:Hide()
        return
    end
    J.TurnOn()
    local npc, unit, why = HoveredNpc()
    if not npc then
        ns.Print(why)
        return
    end
    J.View.ForgetMapLoot()
    local boss, dungeon = J.Boss(npc)
    if not boss then
        ns.Print(TEXT_UNKNOWN:format(UnitName(unit) or TEXT_THAT))
        return
    end
    Open(boss, dungeon)
end

J.Settings.OnChange(OnSettingChanged)
