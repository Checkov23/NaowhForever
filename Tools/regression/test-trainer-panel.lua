-- Run with Lua 5.1 from the repository root: the Train Now panel beside the class trainer. A spell
-- skipped in the Training Planner starts unticked, so Learn All leaves it out; ticking it puts it
-- back for this visit, and the next visit starts it unticked again.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local NOTHING = function() end

local METHODS = {}
local function Stub(kind)
    return setmetatable({ kind = kind, shown = true, scripts = {}, events = {} },
        { __index = function(_, key) return METHODS[key] or key:find("^%u") and NOTHING or nil end })
end
function METHODS.Show(self) self.shown = true end
function METHODS.Hide(self) self.shown = false end
function METHODS.IsShown(self) return self.shown end
function METHODS.SetShown(self, on) self.shown = on and true or false end
function METHODS.SetScript(self, script, fn) self.scripts[script] = fn end
function METHODS.HookScript(self, script, fn) self.scripts[script] = fn end
function METHODS.RegisterEvent(self, event) self.events[event] = true end
function METHODS.UnregisterAllEvents(self) for event in pairs(self.events) do self.events[event] = nil end end
function METHODS.CreateTexture() return Stub() end
function METHODS.SetText(self, text) self.text = text end

local SERVICES = {
    { name = "Fireball", spell = 101 },
    { name = "Frost Armor", spell = 102 },
    { name = "Arcane Intellect", spell = 103 },
}
local COST = 100
local ignored = { [102] = true }
local frames, timers, bought = {}, {}, {}
local values = { enabled = true, trainerPanel = true }
local trainer = Stub()
local COLOR = { r = 1, g = 1, b = 1 }

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    THEME = setmetatable({}, { __index = function() return COLOR end }),
    Training = {
        Settings = { Get = function(key) return values[key] end, OnChange = NOTHING },
        Style = setmetatable({}, { __index = function() return 1 end }),
        Rows = { Crop = function(texture) return texture end },
        On = function() return true end,
        Ignored = function() return ignored end,
        SpellsByService = function() return {} end,
        ServiceSpell = function(_, i) return SERVICES[i].spell end,
        Coins = function(copper) return tostring(copper) end,
    },
    TrainerServiceInfo = function(i) return SERVICES[i].name, "available", "icon" end,
    Font = function() return Stub() end,
    Solid = function() return Stub() end,
    Border = function() return Stub() end,
    Hairline = NOTHING,
    Button = function(_, text, _, _, onClick) local b = Stub(); b.text, b.onClick = text, onClick; return b end,
    AccentBorder = function(button) return button end,
    SetButtonText = function(button, text) button.text = text end,
    Apply = NOTHING,
}

local env = setmetatable({
    NaowhForever = ns,
    ClassTrainerFrame = trainer,
    UIParent = Stub(),
    CreateFrame = function(kind)
        local frame = Stub(kind)
        frames[#frames + 1] = frame
        return frame
    end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    hooksecurefunc = NOTHING,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UnitLevel = function() return 20 end,
    GetMoney = function() return 1000 end,
    GetNumTrainerServices = function() return #SERVICES end,
    GetTrainerServiceInfo = function() return nil, nil, nil, 10 end,
    GetTrainerServiceCost = function() return COST end,
    BuyTrainerService = function(i) bought[#bought + 1] = SERVICES[i].name end,
    IsTradeskillTrainer = function() return false end,
    C_SpellBook = { IsSpellKnown = function() return false end },
    C_Spell = { GetSpellTexture = NOTHING, GetSpellSubtext = NOTHING },
    GameTooltip_Hide = NOTHING,
}, { __index = _G })
env._G = env
Load({ "NaowhForever_Training/UI/TrainerPanel.lua" }, env)

local events, boot = frames[1], frames[2]
boot.scripts.OnEvent(boot, "PLAYER_LOGIN")

local function RunTimers()
    while timers[1] do table.remove(timers, 1)() end
end

local function Visit()
    events.scripts.OnEvent(events, "TRAINER_SHOW")
    RunTimers()
end

local function Rows()
    local rows = {}
    for _, frame in ipairs(frames) do
        if frame.kind == "Button" then rows[#rows + 1] = frame end
    end
    return rows
end

local function LearnButton()
    for _, frame in ipairs(frames) do
        for _, child in pairs(frame) do
            if type(child) == "table" and child.onClick and child.text and child.text:find("Learn") then return child end
        end
    end
end

local function Learn()
    for i = #bought, 1, -1 do bought[i] = nil end
    local learn = assert(LearnButton(), "the Learn All button")
    learn.onClick()
    table.sort(bought)
    return table.concat(bought, ", ")
end

Visit()
local rows = Rows()
check("a row per spell to train", #rows == 3)
check("the spell skipped in the planner starts unticked, the rest ticked",
    rows[1].tick.shown and not rows[2].tick.shown and rows[3].tick.shown)
check("Learn All leaves the skipped spell out", Learn() == "Arcane Intellect, Fireball")

rows[2].scripts.OnClick(rows[2])
check("ticked by hand: ticked", rows[2].tick.shown)
check("and Learn All buys it on this visit", Learn() == "Arcane Intellect, Fireball, Frost Armor")
rows[1].scripts.OnClick(rows[1])
check("a spell not skipped unticks as before", not rows[1].tick.shown and Learn() == "Arcane Intellect, Frost Armor")

Visit()
check("the next visit starts the skipped spell unticked again", rows[1].tick.shown and not rows[2].tick.shown)

print(("test-trainer-panel: %d checks passed"):format(checks))
