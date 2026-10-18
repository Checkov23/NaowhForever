-- Keys.lua: the Next Blessing and Next Greater Blessing key bindings, secure buttons that step through who needs one.
local ns = _G.NaowhForever

local B = ns.Blessings
local CLASSES, BY_KEY = B.CLASSES, B.BY_KEY
local SYMBOL_OF_KINGS = B.SYMBOL_OF_KINGS
local Store, Assigned, HighestKnown, Due, ByUrgency = B.Store, B.Assigned, B.HighestKnown, B.Due, B.ByUrgency

local NEXT, NEXT_GREATER = "NaowhForeverBlessNext", "NaowhForeverBlessNextGreater"

local STEP = [[
    local i, n = self:GetAttribute("step") or 1, self:GetAttribute("count") or 0
    if i > n then return false end
    self:SetAttribute("unit", self:GetAttribute("unit" .. i))
    self:SetAttribute("spell", self:GetAttribute("spell" .. i))
    self:SetAttribute("step", i + 1)
]]

local keyNext, keyGreater, keyAuto

local function NewKeyButton(name, handler)
    local btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyDown")
    btn:SetAttribute("useOnKeyDown", true)
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("count", 0)
    SecureHandlerWrapScript(btn, "OnClick", handler, STEP)
    btn:SetScript("PostClick", function(self) B.NoteCast(self:GetAttribute("unit"), self:GetAttribute("spell")) end)
    return btn
end

local function SetQueue(btn, list, kind)
    kind = kind or ""
    table.sort(list, ByUrgency)
    for i, entry in ipairs(list) do
        btn:SetAttribute("unit" .. kind .. i, entry.unit)
        btn:SetAttribute("spell" .. kind .. i, entry.spell)
    end
    btn:SetAttribute("count" .. kind, #list)
    btn:SetAttribute("step" .. kind, 1)
end

local function Singles(members, single, shared)
    for _, member in ipairs(members) do
        local key = Assigned(member)
        if key ~= shared then shared = nil end
        local spell = key and HighestKnown(BY_KEY[key].ranks)
        local rank, left = Due(member, key, spell)
        if rank then single[#single + 1] = { unit = member.unit, spell = spell, rank = rank, left = left } end
    end
    return shared
end

local function Greater(members, shared, symbols)
    local spell = shared and symbols and HighestKnown(BY_KEY[shared].greater)
    if spell and not B.WaitedFor(members, spell) then spell = nil end
    local best
    for _, member in ipairs(spell and members or {}) do
        local rank, left = Due(member, shared, spell)
        if rank and (not best or ByUrgency({ rank = rank, left = left }, best)) then
            best = { unit = member.unit, spell = spell, rank = rank, left = left }
        end
    end
    return best
end

local function Salvation(members, tankClass, single, greater, symbols)
    local entry = B.SALVATION
    local spell = HighestKnown(entry.ranks)
    local byClass = {}
    for _, member in ipairs(members) do
        local rank, left = Due(member, entry.key, spell)
        if rank then single[#single + 1] = { unit = member.unit, spell = spell, rank = rank, left = left } end
        if not tankClass[member.class] then
            byClass[member.class] = byClass[member.class] or {}
            table.insert(byClass[member.class], member)
        end
    end
    for _, list in pairs(byClass) do greater[#greater + 1] = Greater(list, entry.key, symbols) end
end

local Keys = {}
B.Keys = Keys

function Keys.Build(handler)
    keyNext = NewKeyButton(NEXT, handler)
    keyGreater = NewKeyButton(NEXT_GREATER, handler)
end

function Keys.SetAuto(btn)
    keyAuto = btn
end

function Keys.Peek()
    if not keyNext then return end
    return keyNext:GetAttribute("spell1") or keyGreater:GetAttribute("spell1"), keyNext:GetAttribute("count") or 0
end

function Keys.Clear()
    if keyNext then keyNext:SetAttribute("count", 0) end
    if keyGreater then keyGreater:SetAttribute("count", 0) end
    if keyAuto then
        keyAuto:SetAttribute("countN", 0)
        keyAuto:SetAttribute("countG", 0)
    end
end

function Keys.Fill(byClass, salvMembers, tankClass)
    local single, greater = {}, {}
    local symbols = C_Item.GetItemCount(SYMBOL_OF_KINGS) > 0
    for _, class in ipairs(CLASSES) do
        local members = byClass[class]
        if members then
            local shared = Singles(members, single, Store().classes[class])
            greater[#greater + 1] = Greater(members, shared, symbols)
        end
    end
    if salvMembers then Salvation(salvMembers, tankClass, single, greater, symbols) end
    SetQueue(keyNext, single)
    SetQueue(keyGreater, greater)
    if keyAuto then
        SetQueue(keyAuto, single, "N")
        SetQueue(keyAuto, greater, "G")
    end
end
