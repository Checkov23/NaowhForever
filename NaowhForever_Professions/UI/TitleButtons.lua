-- TitleButtons.lua: the feature buttons on the profession window's title bar, each shown one in the next place left of the close button (P.TitleButtons).
local ns = _G.NaowhForever

local P = ns.Professions

local GAP = 6

local TitleButtons = {}
P.TitleButtons = TitleButtons

local buttons = {}

local function Before(a, b)
    return a.titleOrder < b.titleOrder
end

function TitleButtons.Layout()
    local first = buttons[1]
    local anchor = first and first:GetParent().close
    if not anchor then return end
    for _, button in ipairs(buttons) do
        if button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("RIGHT", anchor, "LEFT", -GAP, 0)
            anchor = button
        end
    end
end

function TitleButtons.Add(button, order)
    button.titleOrder = order
    buttons[#buttons + 1] = button
    table.sort(buttons, Before)
    button:HookScript("OnShow", TitleButtons.Layout)
    button:HookScript("OnHide", TitleButtons.Layout)
    TitleButtons.Layout()
end
