-- AutoAssign.lua: Auto-Assign, a plan for every paladin in the group, and the saved preset.
local ns = _G.NaowhForever

local B = ns.Blessings
local CLASSES, BLESSINGS, AURAS = B.CLASSES, B.BLESSINGS, B.AURAS
local others = B.others
local IsPaladin, Learned, MyName, Store, CanAssign = B.IsPaladin, B.Learned, B.MyName, B.Store, B.CanAssign

local WANTED = {
    WARRIOR = { "might", "kings" },
    ROGUE = { "might", "kings" },
    HUNTER = { "might", "kings", "wisdom" },
    PALADIN = { "wisdom", "kings", "might" },
    PRIEST = { "wisdom", "kings" },
    MAGE = { "wisdom", "kings" },
    WARLOCK = { "wisdom", "kings" },
    SHAMAN = { "wisdom", "kings", "might" },
    DRUID = { "wisdom", "kings", "might" },
}
local AURA_ORDER = { "devotion", "retribution", "concentration", "fire", "frost", "shadow", "sanctity" }

local function FewestFirst(a, b)
    if a.count ~= b.count then return a.count < b.count end
    return a.who < b.who
end

local function Paladins()
    local list = {}
    if IsPaladin() then
        local known = {}
        for _, entry in ipairs(BLESSINGS) do if Learned(entry) then known[entry.key] = true end end
        for _, entry in ipairs(AURAS) do if Learned(entry) then known[entry.key] = true end end
        list[1] = { who = MyName(), known = known, you = true }
    end
    for who, plan in pairs(others) do list[#list + 1] = { who = who, known = plan.known } end
    for _, p in ipairs(list) do
        p.count = 0
        for _ in pairs(p.known) do p.count = p.count + 1 end
    end
    table.sort(list, FewestFirst)
    return list
end

local function Pick(paladins, wanted, give)
    local free = {}
    for _, p in ipairs(paladins) do free[#free + 1] = p end
    for _, key in ipairs(wanted) do
        for i, p in ipairs(free) do
            if p.known[key] then
                give(p, key)
                table.remove(free, i)
                break
            end
        end
    end
end

local function AutoPlans()
    local paladins = Paladins()
    local plans = {}
    for _, p in ipairs(paladins) do plans[p.who] = { classes = {} } end
    for _, class in ipairs(CLASSES) do
        Pick(paladins, WANTED[class], function(p, key) plans[p.who].classes[class] = key end)
    end
    Pick(paladins, AURA_ORDER, function(p, key) plans[p.who].aura = key end)
    return plans
end

local function ApplyPlans(plans)
    local store = Store()
    for who, plan in pairs(plans) do
        if who == MyName() then
            store.classes = {}
            for class, key in pairs(plan.classes) do store.classes[class] = key end
            store.aura = plan.aura
            B.BroadcastSoon()
        elseif others[who] then
            B.SendPlan(who, plan.classes, plan.aura)
        end
    end
    B.Changed()
end

local function Presets()
    local account = ns.AccountSettings()
    account.blessingPreset = account.blessingPreset or {}
    return account.blessingPreset
end

local function SavedPlan(p, saved)
    local plan = { classes = {} }
    for class, key in pairs(saved.classes or {}) do
        if p.known[key] then plan.classes[class] = key end
    end
    plan.aura = saved.aura and p.known[saved.aura] and saved.aura or nil
    return plan
end

function B.AutoAssign()
    ApplyPlans(AutoPlans())
end

function B.ClearAll()
    local plans = {}
    for _, p in ipairs(Paladins()) do plans[p.who] = { classes = {} } end
    if IsPaladin() then Store().players = {} end
    ApplyPlans(plans)
end

function B.CanPlanAll()
    return next(others) == nil or CanAssign("player")
end

function B.SavePreset()
    local paladins = Paladins()
    if #paladins == 0 then return false end
    local preset = {}
    for _, p in ipairs(paladins) do
        local plan = p.you and Store() or others[p.who]
        local classes = {}
        for class, key in pairs(plan.classes) do classes[class] = key end
        preset[p.who] = { classes = classes, aura = plan.aura }
    end
    ns.AccountSettings().blessingPreset = preset
    return true
end

function B.LoadPreset()
    local plans = {}
    for _, p in ipairs(Paladins()) do
        local saved = Presets()[p.who]
        if saved then plans[p.who] = SavedPlan(p, saved) end
    end
    ApplyPlans(plans)
    return next(plans) ~= nil
end

function B.HasPreset()
    return next(Presets()) ~= nil
end

function B.HasPaladins()
    return #Paladins() > 0
end

function B.SetFor(who, column, key)
    local plan = others[who]
    if not plan then return end
    if column == "AURA" then plan.aura = key else plan.classes[column] = key end
    B.SendPlan(who, plan.classes, plan.aura)
end
