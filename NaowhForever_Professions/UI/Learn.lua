-- Learn.lua: the window's middle column for a recipe not learned yet: what it needs and where to learn it.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local C = P.C
local W = P.State
local R = P.Recipes
local Favorites = P.Favorites
local Style = P.Style
local Widgets = P.Widgets
local SetColor = Widgets.SetColor

local ICON = 44
local STAR_GAP = 10
local NAME_GAP, NAME_DROP = Style.ICON_NAME_GAP, 2
local NAME_TOP = 16
local RIGHT_EDGE = 12
local REQ_GAP, REQ_DROP = 10, 24
local SEARCH_W, SEARCH_H = 96, 20
local SEARCH_TOP = 14
local SEARCH_STACK = 4
local BESIDE_GAP = 8
local REQ_ROOM = 80
local MAX_PARAS, MAX_LINES = 3, 7
local PARA_SPACING = 2
local LINE_SHRINK = 36
local LINE_H = 16
local TEXT_TOP = -72
local PARA_GAP = 8
local PARA_AFTER = 6
local LINE_X = 20
local LINE_STEP = 18
local REAGENTS_GAP = 14
local FOOT_ROOM = 36
local HINT_BOTTOM = 10
local PROFIT_GAP = 8
local TEXT_RECIPE = ns.L("Recipe ")
local TEXT_SEARCH, TEXT_SEARCH_RECIPE = ns.L("Search AH"), ns.L("Search Recipe")
local TEXT_HINT = ns.L("Click a trainer or vendor to set a waypoint.")
local TEXT_WAYPOINT = ns.L("Click to set a waypoint.")
local TIP_FAVORITE = ns.L("Favorite")
local TIP_FAVORITE_HELP = ns.L("Makes this recipe a favourite, or no longer one. With Train "
    .. "Favorites on, a trainer who teaches it offers it when you visit; with Search Favorites "
    .. "AH on, its pattern, plans or manual is listed at the auction house to search for.")
local TIP_SEARCH_HELP = ns.L("Searches the auction house for the item this recipe makes.")
local TIP_SEARCH_RECIPE_HELP = ns.L("Searches the auction house for the recipe itself, to learn it.")

local win

local Learn = {}
P.Learn = Learn

local function OnIconEnter(self)
    if not (self.item or self.spell) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.item then
        GameTooltip:SetItemByID(self.item)
    else
        GameTooltip:SetSpellByID(self.spell)
    end
    GameTooltip:Show()
end

local function OnIconClick(self)
    if not IsModifiedClick("CHATLINK") then return end
    local link = self.item and select(2, C_Item.GetItemInfo(self.item))
        or self.spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(self.spell)
    if link then ChatFrameUtil.InsertLink(link) end
end

local function OnFavorite()
    if not W.selectedUnlearned then return end
    Favorites.Toggle(W.selectedUnlearned)
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

local function OnLineClick(self)
    local npc = self.npc
    if npc and ns.PlaceWaypoint then ns.PlaceWaypoint(npc[C.NPC_NAME], npc[C.NPC_MAP], npc[C.NPC_X], npc[C.NPC_Y]) end
end

local function OnLineEnter(self)
    if not self.npc then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.npc[C.NPC_NAME], 1, 1, 1)
    GameTooltip:AddLine(TEXT_WAYPOINT, T.accent.r, T.accent.g, T.accent.b)
    GameTooltip:Show()
end

local function PlaceSearches(l)
    l.searchRecipe:ClearAllPoints()
    if l.search:IsShown() then
        l.searchRecipe:SetPoint("TOPRIGHT", l.search, "BOTTOMRIGHT", 0, -SEARCH_STACK)
    else
        l.searchRecipe:SetPoint("TOPRIGHT", l, "TOPRIGHT", -RIGHT_EDGE, -SEARCH_TOP)
    end
    local beside = (l.search:IsShown() and l.search) or (l.searchRecipe:IsShown() and l.searchRecipe)
    if beside then
        l.name:SetPoint("TOPRIGHT", beside, "TOPLEFT", -BESIDE_GAP, 0)
    else
        l.name:SetPoint("TOPRIGHT", l, "TOPRIGHT", -RIGHT_EDGE, -NAME_TOP)
    end
    local stacked = l.search:IsShown() and l.searchRecipe:IsShown()
    l.req:SetWidth(Style.MID_W - REQ_ROOM - (stacked and l.searchRecipe:GetWidth() + BESIDE_GAP or 0))
end

local function ShowPara(l, nPara, text, y)
    local fs = l.paras[nPara]
    if not fs then return end
    if nPara > 1 then y = y - PARA_GAP end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", Style.PANE_EDGE, y)
    fs:SetText(text)
    fs:Show()
    return y - fs:GetStringHeight() - PARA_AFTER
end

local function ShowLine(l, nLine, entry, y)
    local line = l.lines[nLine]
    if not line then return end
    line.npc = entry.npc
    line.text:SetText(entry.text)
    SetColor(line.text, entry.npc and T.accent or T.fg)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", LINE_X, y)
    line:Show()
    return y - LINE_STEP
end

local function Describe(l, r)
    for _, fs in ipairs(l.paras) do fs:Hide() end
    for _, line in ipairs(l.lines) do line:Hide() end
    local y, nPara, nLine = TEXT_TOP, 0, 0
    for _, entry in ipairs(ns.RecipeFinder.Describe(r)) do
        local nextY
        if entry.para then
            nPara = nPara + 1
            nextY = ShowPara(l, nPara, entry.text, y)
        else
            nLine = nLine + 1
            nextY = ShowLine(l, nLine, entry, y)
        end
        if not nextY then break end
        y = nextY
    end
    return y
end

local function FillReagents(l, r, y)
    local ok, reagents = pcall(R.Reagents, r.spell)
    if not ok then reagents = {} end
    local height = l:GetHeight() > 0 and l:GetHeight() or (Style.MIN_H + Style.TOP_Y - Style.PAD)
    local fit = math.floor((height + y - REAGENTS_GAP - (Style.PROFIT_H + FOOT_ROOM)) / Style.REAGENT_H)
    l.reagentsLabel:SetShown(#reagents > 0 and fit > 0)
    l.reagentsLabel:ClearAllPoints()
    l.reagentsLabel:SetPoint("TOPLEFT", Style.PANE_EDGE, y - REAGENTS_GAP)
    P.Reagents.Fill(l.reagents, reagents, nil, math.max(0, fit))
end

function Learn.Render(r)
    local l = win.learn
    l.icon:SetTexture((r.item and C_Item.GetItemIconByID(r.item)) or C_Spell.GetSpellTexture(r.spell))
    l.name:SetText(C_Spell.GetSpellName(r.spell) or (TEXT_RECIPE .. r.spell))
    SetColor(l.name, ns.RecipeFinder.Color(r))
    Widgets.Star(l.fav.tex, Favorites.Is(r))
    l.req:SetText(ns.RecipeFinder.Requirement(r))
    local read, made = R.OutputItem(r.spell)
    local output = r.item or read
    l.iconButton.item, l.iconButton.spell = output, r.spell
    Widgets.ShowSearch(l.search, output and (R.ItemName(output) or C_Spell.GetSpellName(r.spell)))
    P.Lines.RenderProfit(l.profit, r.spell, output, made)
    Widgets.ShowSearch(l.searchRecipe, R.ItemName(r.recipe))
    PlaceSearches(l)
    FillReagents(l, r, Describe(l, r))
end

local function BuildIcon(l)
    local learnIcon = CreateFrame("Button", nil, l)
    learnIcon:SetSize(ICON, ICON)
    learnIcon:SetPoint("TOPLEFT", Style.PANE_EDGE, -Style.PANE_EDGE)
    l.iconButton = learnIcon
    l.icon = Widgets.Crop(learnIcon:CreateTexture(nil, "ARTWORK"))
    l.icon:SetAllPoints()
    learnIcon:SetScript("OnEnter", OnIconEnter)
    learnIcon:SetScript("OnLeave", GameTooltip_Hide)
    learnIcon:SetScript("OnClick", OnIconClick)
    l.fav = Widgets.StarButton(l)
    l.fav:SetPoint("TOPLEFT", l.icon, "TOPRIGHT", STAR_GAP, 0)
    l.fav:SetScript("OnClick", OnFavorite)
    ns.Tooltip(l.fav, TIP_FAVORITE, TIP_FAVORITE_HELP)
end

local function BuildText(l)
    l.name = ns.Font(l, Style.FONT_NAME, nil)
    l.name:SetPoint("TOPLEFT", l.fav, "TOPRIGHT", NAME_GAP, -NAME_DROP)
    l.name:SetPoint("TOPRIGHT", -RIGHT_EDGE, -NAME_TOP)
    l.name:SetJustifyH("LEFT")
    l.req = ns.Font(l, Style.FONT, nil)
    l.req:SetPoint("TOPLEFT", l.icon, "TOPRIGHT", REQ_GAP, -REQ_DROP)
    l.req:SetJustifyH("LEFT")
    l.req:SetWordWrap(true)
    l.search = ns.Button(l, TEXT_SEARCH, SEARCH_W, SEARCH_H, function() P.AH.Search(l.search.itemName) end)
    l.search:SetPoint("TOPRIGHT", -RIGHT_EDGE, -SEARCH_TOP)
    ns.Tooltip(l.search, TEXT_SEARCH, TIP_SEARCH_HELP)
    l.search:Hide()
    l.searchRecipe = ns.Button(l, TEXT_SEARCH_RECIPE, SEARCH_W, SEARCH_H, function()
        P.AH.Search(l.searchRecipe.itemName)
    end)
    ns.Tooltip(l.searchRecipe, TEXT_SEARCH_RECIPE, TIP_SEARCH_RECIPE_HELP)
    l.searchRecipe:Hide()
end

local function BuildLines(l)
    l.paras = {}
    for i = 1, MAX_PARAS do
        local fs = ns.Font(l, Style.FONT, nil)
        fs:SetWidth(Style.PANE_INNER_W)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetSpacing(PARA_SPACING)
        l.paras[i] = fs
    end
    l.lines = {}
    for i = 1, MAX_LINES do
        local line = CreateFrame("Button", nil, l)
        line:SetSize(Style.MID_W - LINE_SHRINK, LINE_H)
        line.text = ns.Font(line, Style.FONT, nil)
        line.text:SetPoint("LEFT")
        line.text:SetPoint("RIGHT")
        line.text:SetJustifyH("LEFT")
        line.text:SetWordWrap(false)
        line:SetScript("OnClick", OnLineClick)
        line:SetScript("OnEnter", OnLineEnter)
        line:SetScript("OnLeave", GameTooltip_Hide)
        l.lines[i] = line
    end
end

function Learn.Build(frame, mid)
    win = frame
    local l = CreateFrame("Frame", nil, mid)
    l:SetAllPoints()
    l:Hide()
    win.learn = l
    BuildIcon(l)
    BuildText(l)
    BuildLines(l)
    l.reagentsLabel, l.reagents = P.Reagents.Build(l)
    local hint = ns.Font(l, Style.FONT_SMALL, nil, T.muted)
    hint:SetPoint("BOTTOMLEFT", Style.PANE_EDGE, HINT_BOTTOM)
    hint:SetText(TEXT_HINT)
    l.profit = P.Lines.BuildProfit(l)
    l.profit:SetPoint("BOTTOMLEFT", hint, "TOPLEFT", 0, PROFIT_GAP)
end
