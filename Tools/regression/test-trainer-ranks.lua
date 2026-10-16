local f = assert(io.open(arg[1] or "NaowhForever_QoL/Questing/Trainer.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

-- Spells by id: name and rank. The spellbook's best rank of each is `known`.
local SPELLS = {
    [2050] = { "Lesser Heal", 1 }, [2052] = { "Lesser Heal", 2 }, [2053] = { "Lesser Heal", 3 },
    [2054] = { "Heal", 1 }, [2055] = { "Heal", 2 }, [6063] = { "Heal", 3 }, [6064] = { "Heal", 4 },
    [585] = { "Smite", 1 }, [591] = { "Smite", 2 }, [598] = { "Smite", 3 },
}
local function Fixture(bars, known, kept)
    local env = {
        KEYBOARD_SLOTS = 180,
        GetActionInfo = function(slot) if bars[slot] then return "spell", bars[slot] end end,
        C_Spell = {
            GetSpellName = function(id) return SPELLS[id][1] end,
            GetSpellSubtext = function(id) return "Rank " .. SPELLS[id][2] end,
        },
        C_GamepadUI = {
            GetFirstGamepadActionStorageSlotIndex = function() return 181 end,
            IsValidGamepadActionStorageSlotIndex = function(slot) return slot <= 190 end,
        },
        HighestRanks = function()
            local best = {}
            for _, id in ipairs(known) do best[SPELLS[id][1]] = { rank = SPELLS[id][2], spellID = id } end
            return best
        end,
        Kept = function() return kept or {} end,
    }
    setmetatable(env, { __index = _G })
    local code = "local " .. Slice("function RankOf(", "\nlocal function AddBest(") .. "local "
        .. Slice("function CheckSlot(", "\nlocal function Summary(")
        .. "\nreturn Upgrades"
    local chunk = assert(loadstring(code)); setfenv(chunk, env)
    return chunk()
end
local function Slots(ups)
    local out = {}
    for _, up in ipairs(ups) do out[#out + 1] = up.slot .. ">" .. up.spellID end
    table.sort(out)
    return table.concat(out, " ")
end
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("a lone lower rank is swapped for the highest known", function()
    assert(Slots(Fixture({ [1] = 2055 }, { 6064 })()) == "1>6064")
end)
Case("a downrank beside the main copy stays; only the main copy is swapped", function()
    assert(Slots(Fixture({ [1] = 2054, [2] = 2055 }, { 6064 })()) == "2>6064")
end)
Case("nothing swaps when the top rank is already on the bars", function()
    assert(Slots(Fixture({ [1] = 2054, [2] = 6064 }, { 6064 })()) == "")
end)
Case("the same highest rank on several slots, keyboard and controller, all swap", function()
    assert(Slots(Fixture({ [1] = 2055, [185] = 2055, [3] = 2054 }, { 6064 })()) == "185>6064 1>6064")
end)
Case("each spell is judged on its own", function()
    local ups = Fixture({ [1] = 2050, [2] = 2052, [3] = 585, [4] = 2055 }, { 2053, 598, 6064 })()
    assert(Slots(ups) == "2>2053 3>598 4>6064")
end)
Case("kept spells are still listed, flagged", function()
    local ups = Fixture({ [1] = 2054, [2] = 2055 }, { 6064 }, { Heal = true })()
    assert(#ups == 1 and ups[1].slot == 2 and ups[1].kept == true)
end)
Case("spells not in the spellbook and empty slots are ignored", function()
    assert(Slots(Fixture({ [1] = 2055 }, { 598 })()) == "")
end)
Case("QoL declares the Trainer Popup card on its XP page, so it shows without the Training Planner", function()
    assert(source:find('local SETTINGS_PAGE = "QoL/XP"', 1, true))
    local card = Slice("Settings.Page(SETTINGS_PAGE, S):Card({", "\n})")
    assert(card:find('id = "trainer"', 1, true) and card:find('switch = "trainerPopup"', 1, true))
    assert(card:find('label = "Popup Position", buttonText = "Reset", button = ResetPosition', 1, true)
        and source:find('S.Set("trainerPos", nil)', 1, true))
    assert(card:find("button = ns.TrainerRankCheck,", 1, true) and card:find("button = ns.TrainerForgetKept,", 1, true))
end)
Case("a profession trainer's offers and known recipes are not new spells; class spells are", function()
    local trainer, recipes = true, {}
    local env = { atTrainer = true, IsTradeskillTrainer = function() return trainer end,
        C_TradeSkillUI = { GetRecipeInfo = function(id) return recipes[id] end } }
    local chunk = assert(loadstring(Slice("local function IsRecipe(", "\nlocal function Learned(")
        .. "\nreturn IsRecipe"))
    setfenv(chunk, env)
    local IsRecipe = chunk()
    assert(IsRecipe(1), "any offer at a profession trainer")
    trainer, recipes[2] = false, {}
    assert(IsRecipe(2), "a recipe the game knows")
    assert(not IsRecipe(3), "a class spell")
    env.atTrainer, trainer = false, true
    assert(not IsRecipe(3), "the trainer flag counts only at a trainer")
end)
-- Real event, Show, Rows, Render and Apply paths with drawing replaced by small stand-ins.
local function Lifecycle(kept)
    local bars, known = { [1] = 2055 }, { 2055 }
    local upgrades = Fixture(bars, known, kept)
    local settings = { enabled = true, trainerPopup = true, trainerRanks = true, trainerGlow = false }
    local combat, profession = false, false
    local timers, listeners = {}, {}
    local env = { learned = {}, listed = {}, manual = false, atTrainer = false, rankTrainer = false,
        showQueued = false, showPending = 0, SHOW_DELAY = 2, BOTTOM_PAD = 0,
        TEXT_NEW = "New Abilities", TEXT_LOWER = "Lower Ranks on Your Bars",
        S = { Get = function(k) return settings[k] end },
        On = function() return settings.enabled and settings.trainerPopup end,
        Upgrades = upgrades, Kept = function() return kept or {} end,
        InCombatLockdown = function() return combat end,
        IsTradeskillTrainer = function() return profession end,
        C_TradeSkillUI = { GetRecipeInfo = function() end },
        C_Spell = { IsSpellPassive = function() return false end,
            GetSpellName = function(id) return SPELLS[id][1] end },
        C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
        WatchGlow = function() end, QueueGlow = function() end,
        glowing = {}, RefreshGlow = function() end,
        FillRows = function() return 0 end,
        LayoutMore = function(_, y) return y end,
        LayoutSwap = function(_, y) return y end,
        Place = function() end,
        events = { RegisterEvent = function(_, e) listeners[e] = true end,
            UnregisterAllEvents = function() for e in pairs(listeners) do listeners[e] = nil end end },
    }
    env.Build = function()
        local popup = { shown = false, title = {} }
        function popup.title:SetText(text) popup.titleText = text end
        function popup:SetHeight() end
        function popup:Show() self.shown = true end
        function popup:Hide() self.shown = false end
        function popup:IsShown() return self.shown end
        env.popup = popup
    end
    setmetatable(env, { __index = _G })
    local code = Slice("local function Rows(", "\nlocal function FillRows(")
        .. Slice("Render = function()", "\nlocal function Show()")
        .. Slice("local function Show()", "\nfunction WatchGlow()")
        .. Slice("local function Apply()", '\nevents:SetScript("OnEvent", OnEvent)')
        .. "\nreturn OnEvent, Apply"
    local chunk = assert(loadstring(code)); setfenv(chunk, env)
    local event, apply = chunk()
    local t = { env = env, settings = settings, bars = bars, known = known }
    function t.Event(name, ...) event(nil, name, ...) end
    function t.Known(id) known[1] = id end
    function t.Profession(value) profession = value end
    function t.Combat(value) combat = value end
    function t.Shown() return env.popup and env.popup.shown or false end
    function t.Hide() if env.popup then env.popup:Hide() end end
    function t.Tick() for _, fn in ipairs(timers) do fn() end; timers = {} end
    t.Apply = apply
    return t
end

Case("closing a class trainer detects a new rank without a learned-ability notification", function()
    local t = Lifecycle()
    t.Event("TRAINER_SHOW")
    t.Known(6064)
    t.Event("TRAINER_CLOSED")
    assert(t.Shown() and t.env.popup.titleText == "Lower Ranks on Your Bars")
    assert(t.bars[1] == 2055, "offers the swap without changing any action slot")
    t.Hide()
    t.Event("TRAINER_CLOSED")
    assert(not t.Shown(), "a duplicate close is not a second trainer visit")
end)
Case("closing a class trainer with no lower ranks shows nothing", function()
    local t = Lifecycle()
    t.Event("TRAINER_SHOW")
    t.Event("TRAINER_CLOSED")
    assert(not t.Shown())
end)
Case("the rank option still gates the automatic check", function()
    local t = Lifecycle()
    t.settings.trainerRanks = false
    t.Event("TRAINER_SHOW")
    t.Known(6064)
    t.Event("TRAINER_CLOSED")
    assert(not t.Shown())
end)
Case("profession visits do not trigger class rank checks after their API flag clears", function()
    local t = Lifecycle()
    t.Profession(true)
    t.Event("TRAINER_SHOW")
    t.Known(6064)
    t.Profession(false)
    t.Event("TRAINER_CLOSED")
    assert(not t.Shown())
end)
Case("the automatic rank offer waits until combat ends", function()
    local t = Lifecycle()
    t.Event("TRAINER_SHOW")
    t.Known(6064)
    t.Combat(true)
    t.Event("TRAINER_CLOSED")
    assert(not t.Shown() and t.env.showQueued)
    t.Combat(false)
    t.Event("PLAYER_REGEN_ENABLED")
    assert(t.Shown() and not t.env.showQueued)
end)
Case("kept-only ranks do not cause automatic prompts but remain available manually", function()
    local t = Lifecycle({ Heal = true })
    t.Event("TRAINER_SHOW")
    t.Known(6064)
    t.Event("TRAINER_CLOSED")
    assert(not t.Shown())
    t.env.manual = true
    assert(t.env.Render() and t.Shown())
end)
Case("a previous learned list is not replayed on the next trainer visit", function()
    local t = Lifecycle()
    t.Event("LEARNED_SPELL_IN_SKILL_LINE", 591)
    t.Tick()
    assert(t.Shown() and t.env.popup.titleText == "New Abilities")
    t.Hide()
    t.Event("TRAINER_SHOW")
    t.Event("TRAINER_CLOSED")
    assert(not t.Shown() and #t.env.listed == 0 and not t.env.manual)
end)
Case("normal new-ability notifications still appear after closing the trainer", function()
    local t = Lifecycle()
    t.Event("TRAINER_SHOW")
    t.Event("LEARNED_SPELL_IN_SKILL_LINE", 591)
    assert(not t.Shown())
    t.Event("TRAINER_CLOSED")
    assert(t.Shown() and t.env.popup.titleText == "New Abilities" and t.env.listed[1] == 591)
end)
Case("disabling the feature cancels a combat-deferred rank check", function()
    local t = Lifecycle()
    t.Event("TRAINER_SHOW")
    t.Known(6064)
    t.Combat(true)
    t.Event("TRAINER_CLOSED")
    t.settings.trainerPopup = false
    t.Apply()
    t.Combat(false)
    t.Event("PLAYER_REGEN_ENABLED")
    assert(not t.Shown() and not t.env.showQueued and not t.env.rankTrainer)
end)

print(count .. " trainer rank regressions passed")
