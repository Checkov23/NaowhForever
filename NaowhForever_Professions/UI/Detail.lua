-- Detail.lua: the window's middle column for one of your recipes: what it needs, its profit, and the craft buttons.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local C = P.C
local W = P.State
local R = P.Recipes
local V = P.Vendors
local Favorites = P.Favorites
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets
local SetColor = Widgets.SetColor
local EnableButton = Widgets.EnableButton

local ICON = 44
local STAR_GAP = 10
local NAME_GAP = Style.ICON_NAME_GAP
local SEARCH_W, SEARCH_H = 84, 22
local SEARCH_DROP = 36
local DESC_GAP = 12
local RIGHT_EDGE = 12
local DESC_SPACING = 2
local REAGENTS_GAP = 14
local TRACK_TEXT_GAP = 6
local PROFIT_BOTTOM = 44
local EDGE = Style.PANEL_EDGE
local CREATE_W, CREATE_ALL_W = 90, 120
local USABLE_DELAY = 0.5
local TEXT_REQUIRES = ns.L("Requires: ")
local TEXT_COOLDOWN = ns.L("Cooldown: ")
local TEXT_BAG_ROOM = ns.L("Bags: room for %d of %d.|r")
local TEXT_CREATE, TEXT_CREATE_ALL = ns.L("Create"), ns.L("Create All")
local TEXT_CREATE_ALL_COUNT = ns.L("Create All (%d)")
local TEXT_SEARCH = ns.L("Search AH")
local TEXT_TRACK = _G.PROFESSIONS_TRACK_RECIPE or ns.L("Track Recipe")
local TIP_FAVORITE = ns.L("Favorite")
local TIP_FAVORITE_HELP = ns.L("Makes this recipe a favourite, or no longer one. Favourites "
    .. "get a star in the list, and the Filter menu's Favorites shows only them. Right-click "
    .. "a recipe in the list does the same.")
local TIP_SEARCH_HELP = ns.L("Searches the auction house for the item this recipe makes.")
local TIP_TRACK_HELP = ns.L("Shows this recipe's reagents in your objective tracker, with how many "
    .. "you have of each.")

local EMPTY = {}
local lines, parts = {}, {}
local drawnRecipe, drawnUnmet, drawnCooldown
local usablePending = false
local usable = CreateFrame("Frame")
local win

local Detail = {}
P.Detail = Detail

local function Cooldown(recipeID)
    local ok, cooldown = pcall(C_TradeSkillUI.GetRecipeCooldown, recipeID)
    return ok and cooldown and cooldown > 0 and cooldown or nil
end

local function Unmet(recipeID)
    local okReq, reqs = pcall(C_TradeSkillUI.GetRecipeRequirements, recipeID)
    if not (okReq and reqs) then return false end
    for i = 1, #reqs do
        if reqs[i].met == false then return true end
    end
    return false
end

local function UsableChanged()
    if W.linked or W.selectedUnlearned then return true end
    local info = R.SelectedInfo()
    if not info or info.recipeID ~= drawnRecipe then return true end
    local cooldown = Cooldown(info.recipeID)
    local cd = cooldown and math.floor(cooldown) or 0
    return Unmet(info.recipeID) ~= drawnUnmet or cd ~= drawnCooldown
end

local function OnUsableSettled()
    usablePending = false
    if win:IsShown() and win.detail:IsShown() and UsableChanged() then Detail.Render() end
end

local function OnUsable()
    if usablePending then return end
    usablePending = true
    C_Timer.After(USABLE_DELAY, OnUsableSettled)
end

local function AddRequirements(recipeID)
    local okReq, reqs = pcall(C_TradeSkillUI.GetRecipeRequirements, recipeID)
    if W.linked then okReq = false end
    local unmet = false
    if not (okReq and reqs and #reqs > 0) then return unmet end
    wipe(parts)
    for _, req in ipairs(reqs) do
        if req.met == false then unmet = true end
        local c = req.met and T.fg or Style.RED_RGB
        parts[#parts + 1] = Text.Hex(c) .. req.name .. "|r"
    end
    lines[#lines + 1] = TEXT_REQUIRES .. table.concat(parts, ", ")
    return unmet
end

local function Describe(info, output, made)
    local d = win.detail
    local ok, desc = pcall(C_TradeSkillUI.GetRecipeDescription, info.recipeID, EMPTY)
    wipe(lines)
    lines[1] = ok and desc or ""
    local unmet = AddRequirements(info.recipeID)
    local cooldown = Cooldown(info.recipeID)
    if not W.linked and cooldown then
        lines[#lines + 1] = Style.ALERT_CODE .. TEXT_COOLDOWN .. SecondsToTime(cooldown) .. "|r"
    end
    drawnRecipe, drawnUnmet = info.recipeID, unmet
    drawnCooldown = cooldown and math.floor(cooldown) or 0
    local can = R.Craftable(info)
    local room = not W.linked and ns.CraftBagRoom and ns.CraftBagRoom(output, made, R.Reagents(info.recipeID), can)
    if room and can > room then
        lines[#lines + 1] = Style.ALERT_CODE .. TEXT_BAG_ROOM:format(room, can)
    end
    win.createAll.count = room and math.min(can, room) or can
    d.desc:SetText(table.concat(lines, "\n"))
    return unmet
end

local function ShowCraftOrOrder(info, output, made)
    local d = win.detail
    for _, control in ipairs(win.craftControls) do control:SetShown(not W.linked) end
    if W.linked then
        d.profit.value = nil
        d.profit:Hide()
        return
    end
    d.orderRow:Hide()
    d.bringHead:Hide()
    d.orderValue.value = nil
    d.orderValue:Hide()
    P.Lines.RenderProfit(d.profit, info.recipeID, output, made)
end

local function FillHeader(info, output)
    local d = win.detail
    d.icon:SetTexture(info.icon)
    d.name:SetText(info.name)
    d.fav:SetShown(not W.linked)
    Widgets.Star(d.fav.tex, Favorites.Is(info))
    SetColor(d.name, Style.DIFFICULTY_RGB[info.relativeDifficulty] or T.fg)
    Widgets.ShowSearch(d.search, not W.linked and output and (R.ItemName(output) or info.name) or nil, d.name, d)
    if S.Get("skillThresholds") or d.skillThresholdAnchor then
        local range = P.SkillThresholds.Render(d, info)
        if range ~= d.skillThresholdAnchor then
            d.desc:ClearAllPoints()
            d.desc:SetPoint("TOPLEFT", range or d.icon, "BOTTOMLEFT", 0, -DESC_GAP)
            d.skillThresholdAnchor = range
        end
    end
end

local function FillReagents(info)
    local d = win.detail
    local reagents = R.Reagents(info.recipeID)
    local target = S.Get("vendorMaterials") and V.CraftableWithVendor(info)
    if target and target <= R.Craftable(info) then target = nil end
    P.Reagents.Fill(d.reagents, reagents, target, Style.MAX_REAGENTS)
    return d.reagents[math.min(#reagents, Style.MAX_REAGENTS)]
end

local function FillTrack(info)
    local d = win.detail
    local okTrack, tracked = pcall(C_TradeSkillUI.IsRecipeTracked, info.recipeID, false)
    d.track:SetShown(okTrack and C_TradeSkillUI.SetRecipeTracked ~= nil)
    d.track:SetChecked(okTrack and tracked == true)
end

local function ShowLearn()
    win.detail:Hide()
    win.empty:Hide()
    win.learn:Show()
    return P.Learn.Render(W.selectedUnlearned)
end

function Detail.Render()
    local d = win.detail
    if ns.ShoppingListRender then ns.ShoppingListRender(nil) end
    if W.selectedUnlearned then return ShowLearn() end
    win.learn:Hide()
    local info = R.SelectedInfo()
    d:SetShown(info ~= nil)
    win.empty:SetShown(info == nil)
    if not info then return end
    local output, made = R.OutputItem(info.recipeID)
    FillHeader(info, output)
    ShowCraftOrOrder(info, output, made)
    local unmet = Describe(info, output, made)
    d.reagentsLabel:ClearAllPoints()
    d.reagentsLabel:SetPoint("TOPLEFT", d.desc, "BOTTOMLEFT", 0, -REAGENTS_GAP)
    if W.linked then return P.OrderPanel.RenderDetail(info) end
    local last = FillReagents(info)
    P.BuyRow.Render(info, last)
    if ns.ShoppingListRender then ns.ShoppingListRender(info, last) end
    FillTrack(info)
    ns.SetButtonText(win.createAll, TEXT_CREATE_ALL_COUNT:format(win.createAll.count))
    EnableButton(win.create, not unmet)
    EnableButton(win.createAll, not unmet)
end

function Detail.Listen(on)
    if on then
        usable:RegisterEvent("SPELL_UPDATE_USABLE")
    else
        usable:UnregisterAllEvents()
    end
end

local function OnIconEnter(self)
    local info = R.SelectedInfo()
    if not info then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if not pcall(GameTooltip.SetRecipeResultItem, GameTooltip, info.recipeID) then
        GameTooltip:SetSpellByID(info.recipeID)
    end
    GameTooltip:Show()
end

local function OnFavorite()
    local info = R.SelectedInfo()
    if not info then return end
    Favorites.Toggle(info)
    P.List.RedrawAll()
end

local function OnTrack(self)
    local info = R.SelectedInfo()
    local on = self:GetChecked()
    if not (info and pcall(C_TradeSkillUI.SetRecipeTracked, info.recipeID, on, false)) then
        self:SetChecked(not on)
    end
end

local function OnTrackEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.text:GetText(), 1, 1, 1)
    GameTooltip:AddLine(TIP_TRACK_HELP, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function QtyValue()
    return tonumber(win.qty:GetText()) or 1
end

local function OnCreate()
    R.Craft(QtyValue())
end

local function OnCreateAll()
    local info = R.SelectedInfo()
    if info then R.Craft(win.createAll.count or R.Craftable(info)) end
end

local function BuildHeader(d)
    local iconBtn = CreateFrame("Button", nil, d)
    iconBtn:SetSize(ICON, ICON)
    iconBtn:SetPoint("TOPLEFT", Style.PANE_EDGE, -Style.PANE_EDGE)
    d.icon = Widgets.Crop(iconBtn:CreateTexture(nil, "ARTWORK"))
    d.icon:SetAllPoints()
    iconBtn:SetScript("OnEnter", OnIconEnter)
    iconBtn:SetScript("OnLeave", GameTooltip_Hide)
    d.fav = Widgets.StarButton(d)
    d.fav:SetPoint("LEFT", iconBtn, "RIGHT", STAR_GAP, 0)
    d.fav:SetScript("OnClick", OnFavorite)
    ns.Tooltip(d.fav, TIP_FAVORITE, TIP_FAVORITE_HELP)
    d.name = ns.Font(d, Style.FONT_NAME, nil)
    d.name:SetPoint("LEFT", d.fav, "RIGHT", NAME_GAP, 0)
    d.name:SetPoint("RIGHT", -RIGHT_EDGE, 0)
    d.name:SetJustifyH("LEFT")
    d.search = ns.Button(d, TEXT_SEARCH, SEARCH_W, SEARCH_H, function() P.AH.Search(d.search.itemName) end)
    d.search:SetPoint("RIGHT", d, "TOPRIGHT", -RIGHT_EDGE, -SEARCH_DROP)
    ns.Tooltip(d.search, TEXT_SEARCH, TIP_SEARCH_HELP)
    d.search:Hide()
    d.desc = ns.Font(d, Style.FONT, nil)
    d.desc:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", 0, -DESC_GAP)
    d.desc:SetWidth(Style.PANE_INNER_W)
    d.desc:SetJustifyH("LEFT")
    d.desc:SetSpacing(DESC_SPACING)
end

local function BuildTrack(d)
    d.track = Widgets.CheckBox(d)
    d.track:SetPoint("RIGHT", d.reagentsLabel, "LEFT", Style.PANE_INNER_W, 0)
    d.track.text = ns.Font(d.track, Style.FONT, nil)
    d.track.text:SetPoint("RIGHT", d.track, "LEFT", -TRACK_TEXT_GAP, 0)
    d.track.text:SetText(TEXT_TRACK)
    d.track:SetScript("OnClick", OnTrack)
    d.track:HookScript("OnEnter", OnTrackEnter)
    d.track:HookScript("OnLeave", GameTooltip_Hide)
end

local function QtyMore()
    win.qty:SetText(tostring(math.min(C.MAX_CRAFTS, QtyValue() + 1)))
end

local function QtyFewer()
    win.qty:SetText(tostring(math.max(1, QtyValue() - 1)))
end

local function BuildCraftControls(d)
    local create = ns.Button(d, TEXT_CREATE, CREATE_W, Style.BUTTON_H, OnCreate)
    create:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    win.create = create
    local qty = Widgets.QtyBox(d)
    win.qty = qty
    local plus = ns.Button(d, "+", Style.STEP_W, Style.BUTTON_H, QtyMore)
    plus:SetPoint("RIGHT", create, "LEFT", -Style.QTY_GAP, 0)
    qty:SetPoint("RIGHT", plus, "LEFT", -Style.STEP_GAP, 0)
    local minus = ns.Button(d, "-", Style.STEP_W, Style.BUTTON_H, QtyFewer)
    minus:SetPoint("RIGHT", qty, "LEFT", -Style.STEP_GAP, 0)
    win.createAll = ns.Button(d, TEXT_CREATE_ALL, CREATE_ALL_W, Style.BUTTON_H, OnCreateAll)
    win.createAll:SetPoint("BOTTOMLEFT", EDGE, EDGE)
    win.craftControls = { create, qty, plus, minus, win.createAll }
end

function Detail.Build(frame, mid)
    win = frame
    local d = CreateFrame("Frame", nil, mid)
    d:SetAllPoints()
    win.detail = d
    BuildHeader(d)
    d.reagentsLabel, d.reagents = P.Reagents.Build(d)
    BuildTrack(d)
    d.profit = P.Lines.BuildProfit(d)
    d.profit:SetPoint("BOTTOMLEFT", Style.PANE_EDGE, PROFIT_BOTTOM)
    P.BuyRow.Build(win, d)
    BuildCraftControls(d)
    P.OrderPanel.BuildControls(d)
end

usable:SetScript("OnEvent", OnUsable)
