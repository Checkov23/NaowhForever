-- BookRow.lua: a library book: its level or tick, its name and where it lies, whether you carry it, a waypoint pin.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local C = Discovery.C
local Parts = ns.Shared.Parts
local Style = Discovery.Style
local Library = Discovery.Library
local V = Discovery.View

local TEXT_HANDED_IN = ns.L("Handed in")
local TEXT_IN_BAGS = ns.L("In bags")
local TEXT_IN_BANK = ns.L("In bank")
local TEXT_MISSING = ns.L("Missing")
local TEXT_SHARE = ns.L("Share where it is")
local TEXT_HAND_IN_TO = ns.L("Hand in to")
local TEXT_STATUS = ns.L("Status")
local TEXT_HINT = ns.L("Pin: waypoint    Right-click: Share")

local function Status(book)
    if Library.Done(book) then return TEXT_HANDED_IN, T.muted end
    local stored = Library.Stored(book)
    if stored == "bags" then return TEXT_IN_BAGS, Style.STORED_RGB end
    if stored == "bank" then return TEXT_IN_BANK, Style.STORED_RGB end
    return TEXT_MISSING, Style.MISSING_RGB
end

local function Share(owner, row)
    local spot = row.spot
    if spot then Parts.SharePlace(owner, TEXT_SHARE, row.book.name, spot[C.SPOT_MAP], spot[C.SPOT_X], spot[C.SPOT_Y], spot[C.SPOT_PLACE]) end
end

local function PinClicked(button, mouse)
    local row = button:GetParent()
    if mouse == "RightButton" then return Share(button, row) end
    Library.WaypointBook(row.book, row.spot)
end

local function BookEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local book, m = row.book, T.muted
    GameTooltip:SetText(book.name, 1, 1, 1)
    if row.spot then
        GameTooltip:AddLine(Library.ZoneName(row.spot[C.SPOT_MAP]) .. ", " .. Library.Where(row.spot), m.r, m.g, m.b, true)
    end
    GameTooltip:AddDoubleLine(TEXT_HAND_IN_TO, Library.TurnIn(book).name, m.r, m.g, m.b, 1, 1, 1)
    local text, color = Status(book)
    GameTooltip:AddDoubleLine(TEXT_STATUS, text, m.r, m.g, m.b, color.r, color.g, color.b)
    if row.spot and not Library.Done(book) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TEXT_HINT, V.Soft())
    end
    GameTooltip:Show()
end

local function BookMouseUp(row, button)
    if button == "RightButton" then Share(row, row) end
end

local function NewBook(parent)
    local row = V.NewRow(parent, PinClicked, BookEnter)
    row:SetScript("OnMouseUp", BookMouseUp)
    return row
end

local function SetBook(row, book, spot, sub, stripe)
    row.book, row.spot = book, spot
    V.Reset(row, stripe)
    local done = Library.Done(book)
    row.pin:SetShown(spot ~= nil and not done)
    row.tick:SetShown(done)
    row.level:SetShown(not done)
    row.level:SetText(book.tier)
    V.Paint(row.level, GetQuestDifficultyColor(book.tier))
    local text, color = Status(book)
    row.status:SetText(text)
    V.Paint(row.status, color)
    row.bag:SetShown(Library.Carried(book))
    row.bag:SetVertexColor(color.r, color.g, color.b)
    local textW = V.TextWidth(row)
    row.title:SetWidth(textW)
    row.title:SetText(book.name)
    V.Paint(row.title, done and T.muted or T.fg)
    row.where:SetWidth(textW)
    row.where:SetText(sub)
    return V.Height(row)
end

V.Kinds.book = { New = NewBook, Set = SetBook }
