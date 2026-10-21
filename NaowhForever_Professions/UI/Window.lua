-- Window.lua: Naowh's profession window: its frame, title, skill bar, rank banner, search and Filter, and drawing it all.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local W = P.State
local R = P.Recipes
local Prices = P.Prices
local Filters = P.Filters
local Entries = P.Entries
local Orders = P.Orders
local Style = P.Style
local Widgets = P.Widgets
local SetColor = Widgets.SetColor

local FRAME_NAME = "NaowhForeverProfessions"
local LOGO = 26
local LOGO_X, LOGO_DROP = 10, 5
local SETTINGS_PAGE = "Professions/Settings"
local TITLE_GAP = 8
local CLOSE, CLOSE_RIGHT, CLOSE_DROP = Style.WINDOW_CLOSE, 8, 7
local RANK_DROP, RANK_H = 40, 18
local RANK_INSET = 2
local BANNER_Y, BANNER_H, BANNER_SHIFT = -64, 40, 46
local BANNER_ICON, BANNER_ICON_X = 16, 8
local WAYPOINT_W, WAYPOINT_H, WAYPOINT_RIGHT = 86, 22, 4
local BANNER_TEXT_GAP = 8
local BANNER_SPACING, BANNER_LINES = 2, 2
local SEARCH_H = 22
local HINT_X = 6
local CLEAR, CLEAR_RIGHT = 18, 2
local SEARCH_INSET_LEFT, SEARCH_INSET_RIGHT = 6, 22
local TEXT_TITLE_LINKED = ns.L("%s's %s")
local TEXT_RANK = "%s %d/%d"
local TEXT_FILTER, TEXT_FILTER_COUNT = ns.L("Filter"), ns.L("Filter (%d)")
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_SET_WAYPOINT = ns.L("Click to set a waypoint.")
local TEXT_WHERE = "%s %.1f, %.1f"
local TEXT_BANNER = "%s %s\n%s%s|r"
local TEXT_SCAN_FIRST = ns.L("Scan the auction house (Scan Prices) first.")
local TEXT_AUCTIONS_FIRST = ns.L("Turn on Your Auctions in Professions settings first.")
local TEXT_VISIT_AH = ns.L("Visit the Auction House once to read your listings.")
local TEXT_UNLEARNED = ns.L("Unlearned Recipes")
local TEXT_RESET = ns.L("Reset Filters")
local TEXT_SHOW_ROI = ns.L("Show ROI")
local TEXT_ROI_SETTINGS = ns.L("ROI Color Thresholds...")
local TEXT_SEARCH = SEARCH or ns.L("Search")
local TEXT_NO_MATCH = ns.L("No recipes match.")

local EMPTY = {}
local sig = {}
local win

local Window = {}
P.Window = Window

local function CloseAll()
    HideUIPanel(ProfessionsFrame)
end

local function UpdateFilterLabel()
    if not (win and win.filter) then return end
    local n = Filters.Active()
    ns.SetButtonText(win.filter, n > 0 and TEXT_FILTER_COUNT:format(n) or TEXT_FILTER)
end

local function RenderRankBanner(prof)
    local banner = win.rankBanner
    local a
    if ns.ProfessionRank and ns.RecipeFinder and R.Own() then
        local line, skill, max = ns.RecipeFinder.Current()
        a = line and ns.ProfessionRank.For(line, skill, max, prof.name)
    end
    local npc = a and a.npc
    if a then
        banner.npc = npc
        local rank, how, where = P.Book.RankLines(a)
        banner.text:SetText(TEXT_BANNER:format(rank, how, ns.RecipeFinder.Hex(T.muted), where))
        banner.waypoint:SetShown(npc ~= nil)
    end
    banner:SetShown(a ~= nil)
    local top = a and (Style.TOP_Y - BANNER_SHIFT) or Style.TOP_Y
    win.search:SetPoint("TOPLEFT", Style.PAD, top)
    win.mid:SetPoint("TOPLEFT", Style.MID_X, top)
end

local function Reread(prof, who)
    if W.listChanged and not W.stale
        and #(C_TradeSkillUI.GetAllRecipeIDs() or EMPTY) ~= Entries.Count() then
        W.stale = true
    end
    W.listChanged = false
    if not (W.stale or sig.id ~= prof.id or sig.skill ~= prof.skill or sig.max ~= prof.max
        or sig.linked ~= W.linked or sig.who ~= who) then
        return
    end
    W.stale = false
    sig.id, sig.skill, sig.max, sig.linked, sig.who = prof.id, prof.skill, prof.max, W.linked, who
    Entries.Collect()
end

function Window.Render()
    local prof = R.Profession()
    if not prof then return end
    Prices.ClearCache()
    local who = W.linked and Orders.Crafter()
    local name = who and TEXT_TITLE_LINKED:format(Ambiguate(who, "short"), prof.name) or prof.name
    win.title:SetText(name)
    win.rank:SetMinMaxValues(0, math.max(prof.max, 1))
    win.rank:SetValue(prof.skill)
    win.rankText:SetText(TEXT_RANK:format(name, prof.skill, prof.max))
    RenderRankBanner(prof)
    Reread(prof, who)
    Entries.Build()
    P.List.Render()
    P.Detail.Render()
    P.OrderPanel.Render()
    UpdateFilterLabel()
end

local function Refilter()
    W.offset = 0
    Window.Render()
end

local function ToggleSetting(key)
    S.Set(key, not S.Get(key))
    Refilter()
end

local function ResetFilters()
    for _, f in ipairs(Filters.LIST) do S.Set(f.key, false) end
    Refilter()
end

local function AddFilter(root, f)
    if f.divider then root:CreateDivider() end
    local box = root:CreateCheckbox(f.text, function() return S.Get(f.key) == true end,
        function() ToggleSetting(f.key) end)
    if Filters.Available(f) then return end
    box:SetEnabled(false)
    box:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, f.text)
        local reason = f.auctions and (P.Auctions.On() and TEXT_VISIT_AH or TEXT_AUCTIONS_FIRST) or TEXT_SCAN_FIRST
        GameTooltip_AddNormalLine(tooltip, reason)
    end)
end

local function OpenROISettings()
    ns.OpenOptionsWindow(SETTINGS_PAGE)
    ns.UI.GoToSetting(SETTINGS_PAGE, nil, SETTINGS_PAGE .. ":buying")
end

local function FilterMenu(_, root)
    root:CreateTitle(TEXT_FILTER)
    for _, f in ipairs(Filters.LIST) do AddFilter(root, f) end
    root:CreateDivider()
    if S.Get("craftProfit") then
        root:CreateCheckbox(TEXT_SHOW_ROI, function() return S.Get("craftROI") == true end,
            function() ToggleSetting("craftROI") end)
        root:CreateButton(TEXT_ROI_SETTINGS, OpenROISettings)
        root:CreateDivider()
    end
    root:CreateCheckbox(TEXT_UNLEARNED, function() return S.Get("recipeFinder") == true end,
        function() ToggleSetting("recipeFinder") end)
    root:CreateButton(TEXT_RESET, ResetFilters)
end

local function OpenFilterMenu()
    MenuUtil.CreateContextMenu(win.filter, FilterMenu)
end

local function OnWaypointEnter(self)
    local npc = self:GetParent().npc
    if not npc then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(npc[P.C.NPC_NAME], 1, 1, 1)
    GameTooltip:AddLine(TEXT_WHERE:format(ns.RecipeFinder.ZoneName(npc[P.C.NPC_MAP]), npc[P.C.NPC_X], npc[P.C.NPC_Y]),
        T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:AddLine(TEXT_SET_WAYPOINT, T.accent.r, T.accent.g, T.accent.b)
    GameTooltip:Show()
end

local function OnSearchChanged(self)
    local text = self:GetText() or ""
    self.hint:SetShown(text == "")
    self.clear:SetShown(text ~= "")
    W.query = text:lower()
    W.offset = 0
    Entries.Build()
    P.List.Render()
    P.Detail.Render()
end

local function ClearSearch(self)
    local search = self:GetParent()
    search:SetText("")
    search:ClearFocus()
end

local function BuildHeader()
    local logo = ns.Shared.Parts.Logo(win, SETTINGS_PAGE, 0, Style.LOGO, LOGO)
    logo:ClearAllPoints()
    logo:SetPoint("TOPLEFT", LOGO_X, -LOGO_DROP)
    win.title = ns.Font(win, Style.FONT_TITLE, "OUTLINE", T.accent)
    win.title:SetPoint("LEFT", logo, "RIGHT", TITLE_GAP, 0)
    local close = ns.Button(win, "X", CLOSE, CLOSE, CloseAll)
    close:SetPoint("TOPRIGHT", -CLOSE_RIGHT, -CLOSE_DROP)
    win.close = close
    local rank = CreateFrame("StatusBar", nil, win)
    rank:SetPoint("TOPLEFT", Style.PAD + RANK_INSET, -RANK_DROP)
    rank:SetSize(Style.WINDOW_W - Style.PAD * 2 - RANK_INSET * 2, RANK_H)
    ns.Solid(rank, "BACKGROUND", T.panel, 1):SetAllPoints()
    Widgets.StyleBar(rank)
    win.rank = rank
    win.rankText = ns.Font(rank, Style.FONT, "OUTLINE")
    win.rankText:SetPoint("CENTER")
end

local function BuildBanner()
    local banner = CreateFrame("Frame", nil, win)
    banner:SetPoint("TOPLEFT", Style.PAD, BANNER_Y)
    banner:SetSize(Style.WINDOW_W - Style.PAD * 2, BANNER_H)
    ns.Solid(banner, "BACKGROUND", Style.GOLD_RGB, Style.BANNER_ALPHA):SetAllPoints()
    ns.Border(banner, Style.BORDER_RGB)
    banner.icon = banner:CreateTexture(nil, "ARTWORK")
    banner.icon:SetTexture(Style.TRAINER_ICON)
    banner.icon:SetSize(BANNER_ICON, BANNER_ICON)
    banner.icon:SetPoint("LEFT", BANNER_ICON_X, 0)
    banner.waypoint = ns.Button(banner, TEXT_WAYPOINT, WAYPOINT_W, WAYPOINT_H, function()
        ns.ProfessionRank.Waypoint(banner.npc)
    end)
    banner.waypoint:SetPoint("RIGHT", -WAYPOINT_RIGHT, 0)
    banner.waypoint:HookScript("OnEnter", OnWaypointEnter)
    banner.waypoint:HookScript("OnLeave", GameTooltip_Hide)
    banner.text = ns.Font(banner, Style.FONT, nil)
    banner.text:SetPoint("LEFT", banner.icon, "RIGHT", BANNER_TEXT_GAP, 0)
    banner.text:SetPoint("RIGHT", banner.waypoint, "LEFT", -BANNER_TEXT_GAP, 0)
    banner.text:SetJustifyH("LEFT")
    banner.text:SetWordWrap(true)
    banner.text:SetSpacing(BANNER_SPACING)
    if banner.text.SetMaxLines then banner.text:SetMaxLines(BANNER_LINES) end
    banner:Hide()
    win.rankBanner = banner
end

local function BuildSearch()
    local search = ns.NewEditBox(win)
    win.search = search
    search:SetPoint("TOPLEFT", Style.PAD, Style.TOP_Y)
    search:SetSize(Style.LEFT_W - Style.FILTER_W - Style.FILTER_GAP, SEARCH_H)
    win.filter = ns.Button(win, TEXT_FILTER, Style.FILTER_W, SEARCH_H, OpenFilterMenu)
    win.filter:SetPoint("LEFT", search, "RIGHT", Style.FILTER_GAP, 0)
    search.hint = ns.Font(search, Style.FONT, nil, T.muted)
    search.hint:SetPoint("LEFT", HINT_X, 0)
    search.hint:SetText(TEXT_SEARCH)
    search:SetTextInsets(SEARCH_INSET_LEFT, SEARCH_INSET_RIGHT, 0, 0)
    local clear = CreateFrame("Button", nil, search)
    clear:SetSize(CLEAR, CLEAR)
    clear:SetPoint("RIGHT", -CLEAR_RIGHT, 0)
    clear.text = ns.Font(clear, Style.FONT_LARGE, nil, T.muted)
    clear.text:SetPoint("CENTER")
    clear.text:SetText("X")
    clear:SetScript("OnClick", ClearSearch)
    clear:SetScript("OnEnter", function() SetColor(clear.text, T.accent) end)
    clear:SetScript("OnLeave", function() SetColor(clear.text, T.muted) end)
    clear:Hide()
    search.clear = clear
    search:SetScript("OnTextChanged", OnSearchChanged)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    return search
end

local function BuildMiddle()
    local mid = CreateFrame("Frame", nil, win)
    win.mid = mid
    mid:SetPoint("TOPLEFT", Style.MID_X, Style.TOP_Y)
    mid:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", Style.MID_X, Style.PAD)
    mid:SetWidth(Style.MID_W)
    ns.Solid(mid, "BACKGROUND", T.panel, Style.PANEL_ALPHA):SetAllPoints()
    win.empty = ns.Font(mid, Style.FONT_LARGE, nil, T.muted)
    win.empty:SetPoint("CENTER")
    win.empty:SetText(TEXT_NO_MATCH)
    return mid
end

local function OnShow()
    P.Detail.Listen(true)
end

local function OnHide()
    P.Detail.Listen(false)
    P.Buyer.CloseIfShown()
end

function Window.Build()
    win = CreateFrame("Frame", FRAME_NAME, UIParent)
    W.frame = win
    win:SetWidth(Style.WINDOW_W)
    win:HookScript("OnShow", OnShow)
    win:HookScript("OnHide", OnHide)
    win:EnableMouse(true)
    win:Hide()
    ns.Solid(win, "BACKGROUND", T.bg, Style.WINDOW_ALPHA):SetAllPoints()
    ns.Border(win, Style.BORDER_RGB)
    BuildHeader()
    BuildBanner()
    local search = BuildSearch()
    P.List.Build(win, search)
    local mid = BuildMiddle()
    P.Detail.Build(win, mid)
    P.Learn.Build(win, mid)
    P.OrderPanel.Build(win)
    P.Book.Build(win)
    return win
end
