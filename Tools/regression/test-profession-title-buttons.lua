-- Run with Lua 5.1 from the repository root: the profession window's title-bar buttons line up left of
-- the close button in their set order, whichever are shown, with no overlap and no gap for a hidden one,
-- however late each is added. The Shopping List, Crafting Queue and Disenchant buttons all use it.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Frame(parent, name)
    local frame = { name = name, parent = parent, shown = true, hooks = {} }
    function frame:GetParent() return self.parent end
    function frame:IsShown() return self.shown end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:HookScript(event, fn)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], fn)
    end
    local function Fire(self, event)
        for _, fn in ipairs(self.hooks[event] or {}) do fn(self) end
    end
    function frame:Show() if not self.shown then self.shown = true; Fire(self, "OnShow") end end
    function frame:Hide() if self.shown then self.shown = false; Fire(self, "OnHide") end end
    function frame:SetShown(on) if on then self:Show() else self:Hide() end end
    return frame
end

local function Load()
    _G.NaowhForever = { Professions = {} }
    dofile("NaowhForever_Professions/UI/TitleButtons.lua")
    local win = Frame(nil, "window")
    win.close = Frame(win, "close")
    return _G.NaowhForever.Professions.TitleButtons, win
end

local function Row(win, ...)
    local want = { ... }
    local anchor = win.close
    for _, button in ipairs(want) do
        local p = button.point
        if not (button.shown and p and p[1] == "RIGHT" and p[2] == anchor and p[3] == "LEFT"
            and p[4] < 0 and p[5] == 0) then
            return false
        end
        anchor = button
    end
    return true
end

local TitleButtons, win = Load()
local shopping, queue = Frame(win, "shopping"), Frame(win, "queue")
shopping:Hide(); queue:Hide()
TitleButtons.Add(shopping, 2)
TitleButtons.Add(queue, 3)
shopping:Show()
check("Shopping List alone sits next to the close button", Row(win, shopping))
queue:Show()
check("the Crafting Queue follows it", Row(win, shopping, queue))

local disenchant = Frame(win, "disenchant")
disenchant:Hide()
TitleButtons.Add(disenchant, 1)
check("a button added hidden moves nothing", Row(win, shopping, queue))
disenchant:Show()
check("Disenchant, added last, still takes the first place and pushes the rest left",
    Row(win, disenchant, shopping, queue))
shopping:Hide()
check("a hidden button in the middle leaves no gap", Row(win, disenchant, queue))
queue:Hide()
check("Disenchant alone sits next to the close button", Row(win, disenchant))
disenchant:Hide(); shopping:Show()
check("switching to another profession puts the Shopping List back next to the close button", Row(win, shopping))

TitleButtons, win = Load()
local only = Frame(win, "disenchant")
TitleButtons.Add(only, 1)
check("with the Shopping List off, Disenchant alone still lines up", Row(win, only))

local function Read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a"):gsub("\r\n", "\n"); file:close()
    return text
end
local add = Read("NaowhForever_Professions/UI/ShoppingAdd.lua")
check("the Shopping List and Crafting Queue buttons are laid out by it",
    add:find("TitleButtons.Add(opener, OPEN_ORDER)", 1, true)
    and add:find("TitleButtons.Add(queueOpener, QUEUE_ORDER)", 1, true))
check("the Disenchant button is laid out by it",
    Read("NaowhForever_Professions/UI/Disenchant.lua"):find("TitleButtons.Add(opener, OPEN_ORDER)", 1, true))
for _, path in ipairs({ "NaowhForever_Professions/UI/ShoppingAdd.lua", "NaowhForever_Professions/UI/Disenchant.lua" }) do
    check(path .. " places no title-bar button itself", not Read(path):find("\"TOPRIGHT\", -OPEN_RIGHT", 1, true))
end
local xml = Read("NaowhForever_Professions/Professions.xml")
local helper = assert(xml:find("UI\\TitleButtons.lua", 1, true))
check("it loads after the window and before the buttons",
    helper > assert(xml:find("UI\\Window.lua", 1, true))
    and helper < assert(xml:find("UI\\ShoppingAdd.lua", 1, true))
    and helper < assert(xml:find("UI\\Disenchant.lua", 1, true)))

print(("Profession title buttons regression test: PASS (%d checks)"):format(checks))
