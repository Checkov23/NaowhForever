-- NodeToast.lua: New Herbs and Ores: a toast naming the herbs or veins your Herbalism or Mining has just grown into.
local ns = _G.NaowhForever

local GetItemIconByID = C_Item.GetItemIconByID

local P = ns.Professions
local S = P.Settings
local Scan = P.NodeScan
local C = P.C
local Parts = ns.Shared.Parts

local FRAME_NAME = "NaowhForeverNodeToast"
local TOAST_W, TOAST_ICONS = 440, 10
local DISMISS_W = 90
local TOAST_SECONDS = 20
local KINDS = { "herb", "ore" }
local TEXT_TITLE = "%s %d"
local TEXT_PROFESSION = { herb = ns.L("Herbalism"), ore = ns.L("Mining") }
local TEXT_CAN = { herb = ns.L("You can now gather %s."), ore = ns.L("You can now mine %s.") }
local TEXT_AND = ns.L(" and ")
local TEXT_LIST, TEXT_TITLES, TEXT_LINES = ", ", ", ", " "
local TEXT_DISMISS = ns.L("Dismiss")

local toast, events
local best = {}
local found, textures, shownItems, titles, lines = {}, {}, {}, {}, {}

local function On()
    return S.Get("enabled") and S.Get("nodeToast") and true or false
end

local function Join(names)
    if #names == 1 then return names[1] end
    return table.concat(names, TEXT_LIST, 1, #names - 1) .. TEXT_AND .. names[#names]
end

local function Dismiss()
    toast:Hide()
end

local function Build()
    toast = Parts.Toast({ name = FRAME_NAME, width = TOAST_W, icons = TOAST_ICONS, store = S, posKey = "nodeToastPos", on = On,
        buttons = { { text = TEXT_DISMISS, width = DISMISS_W, click = Dismiss } } })
end

local function AddIcons(kind)
    for _, name in ipairs(found) do
        local item = Scan.Item(Scan.Node(name))
        local key = item or kind
        if not shownItems[key] and #textures < TOAST_ICONS then
            shownItems[key] = true
            textures[#textures + 1] = item and GetItemIconByID(item) or C_Spell.GetSpellTexture(C.FIND_SPELL[kind])
        end
    end
end

local function Collect(kind, skill)
    if skill <= 0 then
        best[kind] = nil
        return
    end
    local from = best[kind]
    if not from or skill > from then best[kind] = skill end
    if not from or from <= 0 or skill <= from then return end
    Scan.Unlocked(kind, from, skill, found)
    if #found == 0 then return end
    titles[#titles + 1] = TEXT_TITLE:format(TEXT_PROFESSION[kind], skill)
    lines[#lines + 1] = TEXT_CAN[kind]:format(Join(found))
    AddIcons(kind)
end

local function OnSkillsChanged()
    Scan.ReadSkills()
    wipe(textures)
    wipe(shownItems)
    wipe(titles)
    wipe(lines)
    for _, kind in ipairs(KINDS) do Collect(kind, Scan.Skill(kind)) end
    if #lines == 0 then return end
    if not toast then Build() end
    Parts.FillToast(toast, table.concat(titles, TEXT_TITLES), table.concat(lines, TEXT_LINES), textures)
    Parts.ShowToast(toast, TOAST_SECONDS)
end

local function Remember()
    Scan.ReadSkills()
    for _, kind in ipairs(KINDS) do
        local skill = Scan.Skill(kind)
        if skill > (best[kind] or 0) then best[kind] = skill end
    end
end

local function Apply()
    if not On() or not Scan.Usable() then
        if events then events:UnregisterAllEvents() end
        if toast then toast:Hide() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnSkillsChanged)
    end
    Remember()
    events:RegisterEvent("SKILL_LINES_CHANGED")
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "nodeToast" then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
