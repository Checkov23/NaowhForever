-- StepRow.lua: a Sleeping Bag step: its number or tick, what to click and where, where it stands, a waypoint pin.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local Parts = ns.Shared.Parts
local Style = Discovery.Style
local Bag = Discovery.Bag
local V = Discovery.View

local WORDS = { done = ns.L("Done"), now = ns.L("Next"), optional = ns.L("Optional"), later = ns.L("Later") }
local TEXT_SHARE = ns.L("Share where it is")
local TEXT_HINT = ns.L("Pin: waypoint    Right-click it: Share")

local function StepPin(button, mouse)
    local row = button:GetParent()
    local step = row.step
    if mouse == "RightButton" then
        return Parts.SharePlace(button, TEXT_SHARE, step.object, step.map, step.x, step.y, step.place)
    end
    Bag.Waypoint(step)
end

local function StepEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local step, m = row.step, T.muted
    GameTooltip:SetText(Bag.Name(step), 1, 1, 1)
    GameTooltip:AddLine(Bag.Where(step), m.r, m.g, m.b, true)
    if step.tip then GameTooltip:AddLine(step.tip, 1, 1, 1, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TEXT_HINT, V.Soft())
    GameTooltip:Show()
end

local function NewStep(parent)
    return V.NewRow(parent, StepPin, StepEnter)
end

local function Where(step, done)
    local where = Bag.Where(step)
    if step.tip and not done then return where .. "\n" .. step.tip end
    return where
end

local function SetStep(row, step, number, state, stripe)
    row.step = step
    V.Reset(row, stripe)
    local done = state == "done"
    row.pin:SetShown(not done)
    row.tick:SetShown(done)
    row.level:SetShown(not done)
    row.level:SetText(number)
    V.Paint(row.level, T.muted)
    row.status:SetText(WORDS[state] or WORDS.later)
    V.Paint(row.status, state == "now" and Style.HAVE_RGB or T.muted)
    row.bag:Hide()
    local textW = V.TextWidth(row)
    row.title:SetWidth(textW)
    row.title:SetText(Bag.Name(step))
    V.Paint(row.title, done and T.muted or T.fg)
    row.where:SetWidth(textW)
    row.where:SetText(Where(step, done))
    return V.Height(row)
end

V.Kinds.step = { New = NewStep, Set = SetStep }
