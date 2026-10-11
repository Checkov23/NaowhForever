-- Search.lua: the search box at the top of the options window's sidebar.
local ns = _G.NaowhForever
local UI = ns.UI

local TEXT_SEARCH_HINT = ns.L("Search settings")
local NONE = {}
local NOT_LETTERS, LETTER = "[^%w\128-\255]+", "[%w\128-\255]"

local carries = {}

local function Words(text)
    return " " .. ns.Lower(text):gsub(NOT_LETTERS, " ") .. " "
end

local function Both(text)
    if not text or text == "" then return "" end
    local shown = ns.L(text)
    return shown == text and text or (text .. " " .. shown)
end

local function Typed(query)
    local typed = {}
    for word in Words(query):gmatch("%S+") do typed[#typed + 1] = word end
    return typed
end

local function Place(page, cardName)
    local parts = {}
    local mod = page.module
    if mod and #mod.tabs > 1 then parts[#parts + 1] = ns.L(page.name) end
    if cardName then parts[#parts + 1] = ns.L(cardName) end
    return mod and ns.Options.DisplayName(mod) or ns.L(page.title or page.name), table.concat(parts, " / ")
end

local function IndexInto(list, page, scope, Settings, settingsKey)
    Settings.Index(settingsKey, function(card, label, help, cardName, group)
        local t, where = Place(page, cardName)
        list[#list + 1] = { page = page.key, card = card, label = label, tag = t, trail = where,
            isCard = cardName == nil, scope = scope,
            words = Words(table.concat({ Both(label), Both(help), Both(group), Both(cardName) }, " ")) }
    end)
end

local function AddTerms(list, page, tag, scope)
    local terms = page.terms and ns[page.terms]
    if not terms then return end
    terms(function(label, help, section, off)
        list[#list + 1] = { page = page.key, label = label, tag = tag, trail = section, scope = scope, off = off,
            words = Words(table.concat({ Both(label), Both(help), Both(section) }, " ")) }
    end)
end

local function Collect()
    local list = {}
    local Settings = ns.Shared and ns.Shared.Settings
    for _, page in ipairs(UI.SearchPages()) do
        local tag, trail = Place(page)
        local pageWords = Words(table.concat({ tag, trail, page.module and page.module.name or "" }, " "))
        list[#list + 1] = { page = page.key, tag = tag, trail = trail, words = pageWords }
        AddTerms(list, page, tag, pageWords)
        if Settings then
            IndexInto(list, page, pageWords, Settings, page.key)
            for _, settingsKey in ipairs(carries[page.key] or NONE) do
                IndexInto(list, page, pageWords, Settings, settingsKey)
            end
        end
    end
    return list
end

local function Matched(target, typed)
    local own = false
    for _, word in ipairs(typed) do
        local start = " " .. word
        if target.words:find(start, 1, true) then
            own = true
        elseif not (target.scope and target.scope:find(start, 1, true)) then
            return false
        end
    end
    return own
end

local function Matches(list, typed)
    local out = {}
    if #typed == 0 then return out end
    for _, target in ipairs(list) do
        if Matched(target, typed) then out[#out + 1] = target end
    end
    return out
end

local function Find(list, query)
    return Matches(list, Typed(query))
end

local function AddMatch(f, t)
    local key = t.page
    if not f.count[key] then
        f.count[key] = 0
        f.order[#f.order + 1] = key
    end
    if not t.card then
        f.all[key] = true
        if t.label then f.count[key] = f.count[key] + 1 end
        if t.off then f.off[#f.off + 1] = t.off end
        return
    end
    f.count[key] = f.count[key] + 1
    f.first[key] = f.first[key] or t.card
    if t.isCard then
        f.cards[t.card] = true
    elseif f.cards[t.card] ~= true then
        local labels = f.cards[t.card] or {}
        labels[t.label] = true
        f.cards[t.card] = labels
    end
end

local function Build(list, query)
    local typed = Typed(query)
    if #typed == 0 then return nil end
    local f = { typed = typed, count = {}, all = {}, cards = {}, order = {}, first = {}, off = {} }
    for _, t in ipairs(Matches(list, typed)) do AddMatch(f, t) end
    return f
end

local function StartsWord(lower, s)
    return s == 1 or not lower:sub(s - 1, s - 1):find(LETTER)
end

local function LitLetters(filter, lower)
    local lit
    for _, word in ipairs(filter.typed) do
        local from = 1
        while true do
            local s, e = lower:find(word, from, true)
            if not s then break end
            if StartsWord(lower, s) then
                lit = lit or {}
                for i = s, e do lit[i] = true end
            end
            from = s + 1
        end
    end
    return lit
end

local function Paint(text, lit)
    local out, i = {}, 1
    while i <= #text do
        local on, j = lit[i] == true, i
        while j < #text and (lit[j + 1] == true) == on do j = j + 1 end
        local piece = text:sub(i, j)
        out[#out + 1] = on and ns.Color("accent", piece) or piece
        i = j + 1
    end
    return table.concat(out)
end

local function Mark(filter, text)
    if not (filter and text) then return text end
    local lit = LitLetters(filter, ns.Lower(text))
    if not lit then return text end
    return Paint(text, lit)
end

local function Narrowing(filter, pageKey)
    if filter and not filter.all[pageKey] and (filter.count[pageKey] or 0) > 0 then return filter end
    return nil
end

local function Narrowed(pageKey)
    return Narrowing(UI.filter, pageKey)
end

local function CarriedChanged(before, after)
    for pageKey in pairs(carries) do
        if Narrowing(before, pageKey) or Narrowing(after, pageKey) then return true end
    end
    return false
end

UI.Search = { Collect = Collect, Find = Find, Build = Build, Mark = Mark, Narrowed = Narrowed }

function UI.SearchCarries(pageKey, settingsKey)
    local keys = carries[pageKey] or {}
    keys[#keys + 1] = settingsKey
    carries[pageKey] = keys
end

local box, list, onFilter

local function OnText(text)
    local before = UI.filter
    if text:find("%S") then
        list = list or Collect()
        UI.filter = Build(list, text)
    else
        list, UI.filter = nil, nil
    end
    onFilter()
    if CarriedChanged(before, UI.filter) then UI:RefreshPage(true) end
end

function UI.FocusSearch()
    box:SetFocus()
    box:HighlightText()
end

function UI.SearchTyped()
    return box:GetText() ~= ""
end

function UI.ClearSearch()
    if box:GetText() ~= "" then box:SetText("") end
    box:ClearFocus()
end

function UI.AttachSearchBox(parent, onChange, columns)
    onFilter = onChange
    box = ns.Shared.Parts.SearchBox(parent, TEXT_SEARCH_HINT, OnText, columns)
    UI:RegisterOnHide(UI.ClearSearch)
    return box
end
