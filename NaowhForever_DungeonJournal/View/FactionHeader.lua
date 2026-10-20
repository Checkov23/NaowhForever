-- FactionHeader.lua: the top of a faction's page or the PvP rank's: its name, quartermaster pin, where line and stats.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Loot = J.Loot
local Rep = J.Reputation
local Kinds, Parts = J.View.Kinds, J.View.Parts
local Tip = Parts.Tip
local St = J.Style
local BIS_CODE, LOOK_CODE, LOOK_RGB, BIS_RGB = St.BIS_CODE, St.LOOK_CODE, St.LOOK_RGB, St.BIS_RGB
local STAR, HANGER, PLACE_DOT, TERRITORY_CODE = St.STAR, St.HANGER, St.PLACE_DOT, St.TERRITORY_CODE
local TITLE_SIZE, TITLE_H, TITLE_GAP, WHERE_H, HEADER_PAD = St.TITLE_SIZE, St.TITLE_H, St.TITLE_GAP, St.WHERE_H,
    St.HEADER_PAD
local STAT_GAP, STAT_ICON, QUESTION_ICON, TEXT_SIZE = St.STAT_GAP, St.STAT_ICON, St.QUESTION_ICON, St.TEXT_SIZE

local PIN_DROP = 2
local PIN_GAP = 6
local TITLE_ROOM = 30
local CURRENCY_H = 16
local STAT_ICON_GAP = 2
local LOOK_DROP = -1
local FOREVER_SIZE = 12
local RANK_CITY = { Alliance = "Stormwind", Horde = "Orgrimmar" }

local TEXT_CODE_END = "|r"
local TEXT_QUARTERMASTER_IN = ns.L("Quartermaster in ")
local TEXT_FOREVER = "Forever|r"
local TEXT_RANK = ns.L("Rank ")
local TEXT_SEASON = ns.L("Season ")
local TEXT_ENDS_IN = ns.L("Ends in ")
local TEXT_VENDOR_IN = ns.L("Rank vendor in ")
local TEXT_CURRENCY = "|T%d:%d:%d:0:0|t %s %s"
local TEXT_RANK_SELLS = ns.L("PvP rank rewards")
local TEXT_QUARTERMASTER = " quartermaster"
local TEXT_NOTE = " (%s)"
local TEXT_SHARE_VENDOR = ns.L("Share the rank vendor")
local TEXT_SHARE_QUARTERMASTER = ns.L("Share the quartermaster")
local TEXT_SHOW_QUARTERMASTER = ns.L("Show the quartermaster on your map")
local TEXT_SHOW_VENDOR = ns.L("Show where your side's rank rewards are sold on your map")
local TEXT_SHARE_HINT = ns.L("Right-click to share it in chat, or copy it.")

local whereLines = {}

local function FactionWhere(faction)
    local line = whereLines[faction]
    if line then return line end
    local parts = {}
    if faction.side then parts[#parts + 1] = TERRITORY_CODE[faction.side] .. faction.side .. TEXT_CODE_END end
    if faction.battleground then parts[#parts + 1] = ns.Color("fg", faction.battleground) end
    if faction.zone then
        parts[#parts + 1] = (#faction.tiers > 0 and TEXT_QUARTERMASTER_IN or "") .. ns.Color("fg", faction.zone)
    end
    if faction.new then
        parts[#parts + 1] = Parts.ForeverInline(FOREVER_SIZE, 0):sub(2) .. " " .. St.FOREVER_CODE .. TEXT_FOREVER
    end
    line = table.concat(parts, PLACE_DOT)
    whereLines[faction] = line
    return line
end

local function RankWhere(info)
    if not info then return "" end
    local season, left = Rep.Season()
    local line = TEXT_RANK .. ns.Color("fg", info.renownLevel)
    if season > 0 then line = line .. PLACE_DOT .. TEXT_SEASON .. ns.Color("fg", season) end
    if left > 0 then line = line .. PLACE_DOT .. TEXT_ENDS_IN .. ns.Color("fg", Rep.Duration(left)) end
    local city = RANK_CITY[UnitFactionGroup("player")]
    if city then line = line .. PLACE_DOT .. TEXT_VENDOR_IN .. ns.Color("fg", city) end
    return line
end

local function CurrencyText(id)
    local quantity, name, icon = Rep.Currency(id)
    if not name then return "" end
    return TEXT_CURRENCY:format(icon or QUESTION_ICON, STAT_ICON, STAT_ICON, BreakUpLargeNumbers(quantity),
        ns.Color("muted", name))
end

local function CurrencyEnter(frame)
    if not Tip(frame, "ANCHOR_BOTTOM") then return end
    GameTooltip:SetCurrencyByID(frame.currency)
    GameTooltip:Show()
end

local function Currency(row)
    local frame = CreateFrame("Frame", nil, row)
    frame:SetHeight(CURRENCY_H)
    frame:EnableMouse(true)
    frame.text = ns.Font(frame, TEXT_SIZE, nil, T.fg)
    frame.text:SetPoint("LEFT")
    frame:SetScript("OnEnter", CurrencyEnter)
    frame:SetScript("OnLeave", GameTooltip_Hide)
    return frame
end

local function SetCurrency(frame, id)
    frame.currency = id
    frame.text:SetText(CurrencyText(id))
    frame:SetWidth(math.ceil(frame.text:GetStringWidth()))
    frame:SetShown(frame.text:GetText() ~= "")
end

local function PinSpot(page)
    if page.rank then
        local spot = Rep.RankVendor()
        if spot then return spot, spot.name or TEXT_RANK_SELLS, TEXT_RANK_SELLS end
        return nil
    end
    local spot = Rep.Quartermaster(page)
    if spot then return spot, spot.name or (page.name .. TEXT_QUARTERMASTER), page.name end
    return nil
end

local function PinClicked(pin, mouse)
    local spot, name, what = PinSpot(pin.page)
    if not spot then return end
    local note = TEXT_NOTE:format(what)
    if mouse == "RightButton" then
        Parts.SharePlace(pin, pin.page.rank and TEXT_SHARE_VENDOR or TEXT_SHARE_QUARTERMASTER, name,
            spot.map, spot.x, spot.y, note)
        return
    end
    ns.PlaceWaypoint(name, spot.map, spot.x, spot.y, note)
    ns.Shared.Places.ShowMap(spot.map)
end

local function PlaceStats(row, stats)
    local middle = -(TITLE_H + TITLE_GAP + WHERE_H / 2)
    local right, used = nil, 0
    for _, stat in ipairs(stats) do
        if stat:IsShown() then
            if right then
                stat:SetPoint("RIGHT", right, "LEFT", -STAT_GAP, 0)
            else
                stat:SetPoint("RIGHT", row, "TOPRIGHT", 0, middle)
            end
            right, used = stat, used + stat:GetWidth() + STAT_GAP
        end
    end
    return used
end

local function SetRank(row, info)
    row.title:SetText(Rep.RankTitle(info and info.renownLevel or 0))
    row.where:SetText(RankWhere(info))
    row.bis:Hide()
    row.looks:Hide()
    SetCurrency(row.points, Rep.RANK_POINTS)
    SetCurrency(row.honor, Rep.HONOR)
    return PlaceStats(row, row.rankStats)
end

local function SetFaction(row, page, filters)
    row.title:SetText(page.name)
    row.where:SetText(FactionWhere(page))
    row.honor:Hide()
    row.points:Hide()
    local bis, haveBis = Rep.Bis(page)
    Parts.SetStat(row.bis, haveBis, bis, BIS_CODE, Loot.BisOn())
    local new, looks = 0, 0
    if filters.showAppearance then new, looks = Rep.NewLooks(page, filters) end
    Parts.SetStat(row.looks, looks - new, looks, LOOK_CODE, filters.showAppearance)
    return PlaceStats(row, row.factionStats)
end

local function NewPin(row)
    local pin = Parts.IconButton(row, PinClicked, St.PIN)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetPoint("LEFT", row.title, "RIGHT", PIN_GAP, -PIN_DROP)
    pin.tip = TEXT_SHOW_QUARTERMASTER
    pin.hint = TEXT_SHARE_HINT
    return pin
end

local function NewStats(row)
    row.bis = Parts.Stat(row, "BiS", ns.L("You have %d of the %d BiS from your list among its rewards"),
        ns.L("You have every BiS among its rewards"), STAR, BIS_RGB, STAT_ICON_GAP)
    row.bis.noneTip = ns.L("None of your BiS is among its rewards")
    Parts.OpensBisList(row.bis)
    row.looks = Parts.Stat(row, "Transmog", ns.L("You have %d of the %d looks among its rewards"),
        ns.L("You have every look among its rewards"), HANGER, LOOK_RGB, STAT_ICON_GAP, LOOK_DROP)
    row.looks.noneTip = ns.L("None of its rewards listed has a look to collect")
    row.honor, row.points = Currency(row), Currency(row)
    row.rankStats, row.factionStats = { row.points, row.honor }, { row.looks, row.bis }
end

Kinds.page = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.title = ns.Font(row, TITLE_SIZE, nil, T.fg)
        row.title:SetPoint("TOPLEFT")
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(false)
        row.pin = NewPin(row)
        row.where = ns.Font(row, TEXT_SIZE, nil, T.muted)
        row.where:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -TITLE_GAP)
        row.where:SetJustifyH("LEFT")
        row.where:SetWordWrap(false)
        NewStats(row)
        return row
    end,
    Set = function(row, page, info)
        local view = row:GetParent()
        row.bis:ClearAllPoints()
        row.looks:ClearAllPoints()
        row.honor:ClearAllPoints()
        row.points:ClearAllPoints()
        row.title:SetWidth(0)
        row.pin.page = page
        row.pin.tip = page.rank and TEXT_SHOW_VENDOR or TEXT_SHOW_QUARTERMASTER
        row.pin:SetShown(PinSpot(page) ~= nil)
        local used = page.rank and SetRank(row, info) or SetFaction(row, page, view.filters)
        row.title:SetWidth(math.min(math.ceil(row.title:GetStringWidth()) + 1, row:GetWidth() - TITLE_ROOM))
        row.where:SetWidth(math.max(1, row:GetWidth() - used))
        return TITLE_H + TITLE_GAP + WHERE_H + HEADER_PAD
    end,
}
