-- Loads the Professions module's window, recipe finder, favourites and shopping list against
-- stubbed game APIs, opens the window beside the auction house, and drives what runs while it
-- is open: item data loading (the auction house's own lists load hundreds), an item that never
-- loads, bag updates, scrolling and redraws. It checks that unrelated item loads and failed
-- loads do not redraw anything, what each path costs in time and garbage, and that repeating
-- them does not grow retained memory. Run from the repo root (a folder argument loads the
-- module from there instead, to measure an older copy):
--   lua Tools/regression/test-professions-memory.lua
local DIR = arg and arg[1] or "NaowhForever_Professions"
local Load = dofile("Tools/regression/load_files.lua")

local checks, failures = 0, {}
local function check(label, value)
    checks = checks + 1
    if not value then failures[#failures + 1] = label end
end

local function Noop() end
local EMPTY = {}
local UNMET = { { name = "Anvil", met = false } }
local requirements = EMPTY

-- A runaway loop fails the test instead of hanging it.
local DEADLINE = os.clock() + 60
debug.sethook(function()
    if os.clock() > DEADLINE then error("test-professions-memory: still running after 60 s") end
end, "", 1000000)

-------------------------------------------------------------------------------
--  Time, timers and events
-------------------------------------------------------------------------------
local FRAME = 1 / 60
local now = 1000
-- Timers in parallel arrays, so scheduling one makes no garbage once the arrays have grown.
local timerFn, timerAt, timerCount = {}, {}, 0
-- Item loads answered on the next frame: itemID and whether it loaded.
local loadID, loadOK, loadCount = {}, {}, 0
local registry = {}     -- event -> { frame -> true }
local calls = setmetatable({}, { __index = function() return 0 end })
local function Count(name) calls[name] = calls[name] + 1 end

local function Fire(event, ...)
    local set = registry[event]
    if not set then return end
    for frame in pairs(set) do
        local fn = frame.scripts and frame.scripts.OnEvent
        if fn then fn(frame, event, ...) end
    end
end

local function RunTimers()
    local n, kept = timerCount, 0
    for i = 1, n do
        if timerAt[i] <= now then
            timerFn[i]()
        else
            kept = kept + 1
            timerFn[kept], timerAt[kept] = timerFn[i], timerAt[i]
        end
    end
    -- Timers scheduled while these ran sit after n; move them down behind the kept ones.
    for i = n + 1, timerCount do
        kept = kept + 1
        timerFn[kept], timerAt[kept] = timerFn[i], timerAt[i]
    end
    for i = kept + 1, timerCount do timerFn[i], timerAt[i] = nil, nil end
    timerCount = kept
end

-- One frame: the item loads asked for last frame answer, then the timers due run. Loads asked
-- for while those answer wait for the next frame.
local answerID, answerOK = {}, {}
local function Step()
    now = now + FRAME
    local n = loadCount
    for i = 1, n do answerID[i], answerOK[i] = loadID[i], loadOK[i] end
    loadCount = 0
    for i = 1, n do Fire("ITEM_DATA_LOAD_RESULT", answerID[i], answerOK[i]) end
    RunTimers()
end

local function Advance(seconds)
    local stop = now + seconds
    while now < stop do Step() end
end

-------------------------------------------------------------------------------
--  Frames
-------------------------------------------------------------------------------
local Widget
local methods = {}
-- A setter or other action a stub lacks does nothing; any other field never set is nil, as on
-- a real frame (BookPage, SearchBar).
local NOOP_PREFIXES = { "Set", "Clear", "Enable", "Register", "Start", "Stop", "Add", "Disable" }
local widgetMeta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) ~= "string" then return end
    for _, p in ipairs(NOOP_PREFIXES) do
        if k:sub(1, #p) == p then
            methods[k] = Noop
            return Noop
        end
    end
end }

local function RunHooks(self, name)
    local hooks = self.hooks and self.hooks[name]
    if hooks then for i = 1, #hooks do hooks[i](self) end end
end

function methods.Show(self)
    if self.shown then return end
    self.shown = true
    local fn = self.scripts and self.scripts.OnShow
    if fn then fn(self) end
    RunHooks(self, "OnShow")
end
function methods.Hide(self)
    if not self.shown then return end
    self.shown = false
    local fn = self.scripts and self.scripts.OnHide
    if fn then fn(self) end
    RunHooks(self, "OnHide")
end
function methods.SetShown(self, on) if on then self:Show() else self:Hide() end end
function methods.IsShown(self) return self.shown end
function methods.IsVisible(self) return self.shown end
function methods.SetText(self, v) self.text = v end
function methods.GetText(self) return self.text end
function methods.GetStringWidth() return 20 end
function methods.GetStringHeight() return 12 end
function methods.GetWidth(self) return self.w or 400 end
function methods.GetHeight(self) return self.h or 500 end
function methods.SetSize(self, w, h) self.w, self.h = w, h end
function methods.SetWidth(self, w) self.w = w end
function methods.SetHeight(self, h) self.h = h end
function methods.GetFrameLevel() return 1 end
function methods.GetFrameStrata() return "MEDIUM" end
function methods.GetNumPoints() return 0 end
function methods.GetAlpha() return 1 end
function methods.HasFocus() return false end
function methods.GetChecked(self) return self.checked end
function methods.SetChecked(self, v) self.checked = v end
function methods.GetParent(self) return self.parent end
function methods.GetPoint() return nil end
function methods.SetScript(self, name, fn)
    self.scripts = self.scripts or {}
    self.scripts[name] = fn
end
function methods.GetScript(self, name) return self.scripts and self.scripts[name] end
function methods.HookScript(self, name, fn)
    self.hooks = self.hooks or {}
    self.hooks[name] = self.hooks[name] or {}
    local hooks = self.hooks[name]
    hooks[#hooks + 1] = fn
end
function methods.CreateTexture(self) return Widget(self) end
function methods.CreateFontString(self) return Widget(self) end
function methods.GetStatusBarTexture(self) return Widget(self) end
function methods.RegisterEvent(self, event)
    registry[event] = registry[event] or {}
    registry[event][self] = true
end
methods.RegisterUnitEvent = methods.RegisterEvent
-- Only a key that is there is cleared: in Lua 5.1 setting an absent key to nil adds it, which
-- could rehash a set that Fire is walking.
function methods.UnregisterEvent(self, event)
    local set = registry[event]
    if set and set[self] then set[self] = nil end
end
function methods.UnregisterAllEvents(self)
    for _, set in pairs(registry) do
        if set[self] then set[self] = nil end
    end
end

local made = 0
function Widget(parent)
    made = made + 1
    local w = setmetatable({ shown = true, parent = parent }, widgetMeta)
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = w
    end
    return w
end

local env
local function CreateFrame(_, name, parent)
    local w = Widget(parent)
    if name then env[name] = w end
    return w
end

local function hooksecurefunc(a, b, c)
    local tbl, name, fn = a, b, c
    if type(a) == "string" then tbl, name, fn = env, a, b end
    local orig = tbl[name]
    tbl[name] = function(...)
        local r1, r2, r3 = orig(...)
        fn(...)
        return r1, r2, r3
    end
end

-------------------------------------------------------------------------------
--  Game data: Tailoring, the first recipes learned, the rest of RecipeData not yet
-------------------------------------------------------------------------------
local PROF = 197
local LEARNED_N = 60
local REAGENTS = {}            -- reagent itemIDs
for i = 1, 30 do REAGENTS[i] = 50000 + i end
local BROKEN = 49999           -- an item that never loads once `broken` is set (gone from the client)
local broken = false
local UNRELATED = 777777       -- an item the auction house loads for its own lists

local names, loaded = {}, {}
local function ItemNameOf(id)
    local n = names[id]
    if not n then n = "Item " .. id; names[id] = n end
    return n
end

local recipeIDs, recipeInfo, schematic, categoryInfo = {}, {}, {}, {}
local spellNames = {}

local api = {}
-- Called once the real data file has loaded.
function api.Build(data)
    local recipes = data[PROF].recipes
    for i = 1, LEARNED_N do
        local r = recipes[i]
        recipeIDs[i] = r.spell
        local cat = 100 + (i % 6)
        categoryInfo[cat] = categoryInfo[cat] or { name = "Category " .. cat, uiOrder = cat }
        recipeInfo[r.spell] = { recipeID = r.spell, name = "Recipe " .. i, icon = 1000 + i,
            categoryID = cat, learned = true, relativeDifficulty = i % 4, numAvailable = 0 }
        local slots = {}
        for k = 1, 3 do
            local item = REAGENTS[((i + k * 7) % #REAGENTS) + 1]
            slots[k] = { reagents = { { itemID = item } }, quantityRequired = k, required = true }
        end
        schematic[r.spell] = { reagentSlotSchematics = slots, outputItemID = r.item or (60000 + i),
            quantityMin = 1 }
    end
    -- The recipe chosen when the window opens (the first of the first category) takes the
    -- item that never loads.
    schematic[recipes[6].spell].reagentSlotSchematics[2].reagents[1].itemID = BROKEN
    for _, r in ipairs(recipes) do
        loaded[r.spell] = true
        if r.item then loaded[r.item] = true end
        if r.recipe then loaded[r.recipe] = true end
    end
    for _, id in ipairs(REAGENTS) do loaded[id] = true end
    for i = 1, LEARNED_N do loaded[schematic[recipes[i].spell].outputItemID] = true end
    return recipes
end

-- One answer per item per frame however often it is asked for, as the client keeps one load.
local function RequestLoad(id)
    Count("RequestLoadItemDataByID")
    if loaded[id] then return end
    for i = 1, loadCount do if loadID[i] == id then return end end
    loadCount = loadCount + 1
    local ok = not (broken and id == BROKEN)
    loadID[loadCount], loadOK[loadCount] = id, ok
    if ok then loaded[id] = true end
end

local bagItems = {}            -- slot key -> info, made once
local function BagInfo(bag, slot)
    Count("GetContainerItemInfo")
    if bag > 0 then return nil end
    local key = bag * 100 + slot
    local info = bagItems[key]
    if not info then
        info = { itemID = REAGENTS[slot], stackCount = slot }
        bagItems[key] = info
    end
    return info
end

local ah = Widget()
ah.SearchBar = { SetSearchText = Noop, StartSearch = Noop }
local professionsFrame = Widget()
local childInfo = { professionID = PROF, professionName = "Tailoring", skillLevel = 150, maxSkillLevel = 225 }
local itemKeys = {}
local patternItems = {}

local settings = { enabled = true, recipeFinder = true, vendorMaterials = true, craftProfit = true,
    craftProfitList = true, ahSearch = true, bagReagents = true, bankReagents = true,
    buyMaterials = true, shoppingList = true, searchFavoritesAH = true, manualPatternScan = true }
local defaults = {}
local db = {}
local account = {}
local ns, logoPage, launcher
ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"),
    RegisterMinimapFeature = function(feature) launcher = feature end,
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = { Logo = function(parent, page) logoPage = page; return Widget(parent) end }, Settings = {
        Group = function() return {} end, Look = function() return {} end,
        Page = function() return { Window = Noop, Card = Noop } end } },
    THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
        fg = { r = 0.94, g = 0.95, b = 0.95 }, bg = { r = 0.05, g = 0.06, b = 0.07 },
        panel = { r = 0.1, g = 0.1, b = 0.1 }, line = { r = 0.18, g = 0.19, b = 0.21 },
        accentSoft = { r = 0.3, g = 0.71, b = 0.96 } },
    UI = {
        ModuleSettings = function(_, defs)
            for k, v in pairs(defs) do defaults[k] = v end
            local S = {}
            function S.DB() return db end
            function S.Get(k)
                local v = settings[k]
                if v == nil then v = db[k] end
                if v == nil then return defaults[k] end
                return v
            end
            local listeners = {}
            function S.Set(k, v)
                settings[k] = v
                for i = 1, #listeners do listeners[i](k, v) end
            end
            function S.OnChange(fn) listeners[#listeners + 1] = fn end
            return S
        end,
    },
    ThemeTint = function() return nil end,
    Solid = function(parent) return Widget(parent) end,
    Border = function(parent) return Widget(parent) end,
    Font = function(parent) return Widget(parent) end,
    Button = function(parent, text, _, _, onClick)
        local b = Widget(parent)
        b.label = Widget(b)
        b.label.text = text
        b:SetScript("OnClick", onClick)
        return b
    end,
    NewEditBox = function(parent) return Widget(parent) end,
    Tooltip = Noop,
    SetButtonText = function(b, text) b.label.text = text end,
    AccentBorder = function(f) return f end,
    AccountSettings = function() return account end,
    Print = Noop,
    Apply = Noop,
    AllowOffscreen = Noop,
    Color = function(_, text) return text end,
    AuctionPrice = function(id) return 1000 + (id % 97) * 37 end,
    AuctionScanTime = function() return 5000 end,
    AuctionAge = function() return "1h" end,
    AuctionScanSummary = function() return "Last scan" end,
}

env = {
    NaowhForever = ns,
    CreateFrame = CreateFrame,
    CreateColor = function() return EMPTY end,
    hooksecurefunc = hooksecurefunc,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    GetTime = function() return now end,
    time = function() return now end,
    C_Timer = {
        After = function(d, fn)
            timerCount = timerCount + 1
            timerFn[timerCount], timerAt[timerCount] = fn, now + d
        end,
        NewTicker = function() return { Cancel = Noop } end,
    },
    UIParent = Widget(),
    ProfessionsFrame = professionsFrame,
    AuctionHouseFrame = ah,
    GameTooltip = setmetatable({}, widgetMeta),
    GameTooltip_Hide = Noop,
    HideUIPanel = Noop,
    InCombatLockdown = function() return false end,
    IsShiftKeyDown = function() return false end,
    IsControlKeyDown = function() return false end,
    IsModifiedClick = function() return false end,
    IsInGroup = function() return false end,
    GetMoney = function() return 10000000 end,
    UnitGUID = function() return "Player-1-SELF" end,
    UnitName = function() return "Tester" end,
    UnitLevel = function() return 40 end,
    GetRealmName = function() return "Realm" end,
    UnitFactionGroup = function() return "Alliance" end,
    GetProfessions = function() return 1 end,
    GetProfessionInfo = function() return "Tailoring", 1, 150, 225, 0, 0, PROF, 0 end,
    SecondsToTime = function() return "1 min" end,
    GetMerchantNumItems = function() return 0 end,
    bit = { band = function() return 0 end },
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4,
    SetItemRef = Noop,
    Enum = { BagIndex = { ReagentBag = 5 }, ItemClass = { Tradegoods = 7 },
        AuctionHouseSortOrder = { Price = 0 } },
    C_AddOns = { IsAddOnLoaded = function() return true end },
    C_SpellBook = { IsSpellKnown = function() return false end },
    C_Spell = {
        GetSpellName = function(id)
            local n = spellNames[id]
            if not n then n = "Spell " .. id; spellNames[id] = n end
            return n
        end,
        GetSpellTexture = function(id) return id end,
        GetSpellInfo = function() return nil end,
    },
    C_Map = { GetBestMapForUnit = function() return nil end, GetMapInfo = function() return nil end,
        GetAreaInfo = function() return "Area" end },
    C_QuestLog = { GetTitleForQuestID = function() return nil end },
    C_Item = {
        GetItemNameByID = function(id) if loaded[id] then return ItemNameOf(id) end end,
        RequestLoadItemDataByID = RequestLoad,
        GetItemCount = function(id, bank)
            if patternItems[id] then return 0 end
            return (id % 5) + (bank and 3 or 0)
        end,
        GetItemIconByID = function(id) return id end,
        GetItemInfo = function(id)
            if not loaded[id] then return nil end
            return ItemNameOf(id), nil, 1, 1, 0, "", "", 20, "", id, 1, 7, 0, 2, 0, 0, false
        end,
        GetItemInfoInstant = function(id) return id end,
        GetItemMaxStackSizeByID = function() return 20 end,
        GetItemFamily = function() return 0 end,
    },
    C_Container = {
        GetContainerNumSlots = function() return 16 end,
        GetContainerNumFreeSlots = function() return 2, 0 end,
        GetContainerItemInfo = BagInfo,
    },
    C_AuctionHouse = {
        MakeItemKey = function(id)
            local k = itemKeys[id]
            if not k then k = { itemID = id }; itemKeys[id] = k end
            return k
        end,
        SendSearchQuery = function() Count("SendSearchQuery") end,
        IsThrottledMessageSystemReady = function() return true end,
    },
    C_TradeSkillUI = {
        GetChildProfessionInfo = function() return childInfo end,
        GetBaseProfessionInfo = function() return childInfo end,
        GetAllRecipeIDs = function() Count("GetAllRecipeIDs"); return recipeIDs end,
        GetRecipeInfo = function(id) Count("GetRecipeInfo"); return recipeInfo[id] end,
        GetCategoryInfo = function(id) return categoryInfo[id] end,
        GetRecipeSchematic = function(id) Count("GetRecipeSchematic"); return schematic[id] or EMPTY end,
        GetRecipeOutputItemData = function() return nil end,
        IsTradeSkillLinked = function() return false end,
        IsTradeSkillGuild = function() return false end,
        IsNPCCrafting = function() return false end,
        GetRecipeDescription = function() Count("detail"); return "A recipe." end,
        GetRecipeRequirements = function() return requirements end,
        GetRecipeCooldown = function() return 0 end,
        IsRecipeTracked = function() return false end,
        SetRecipeTracked = Noop,
        GetRecipeLink = function() return "[link]" end,
        CraftRecipe = Noop,
    },
}
env._G = env
-- A global no stub covers reads as nil, as an absent API would in game.
setmetatable(env, { __index = _G })

-------------------------------------------------------------------------------
--  Load the module and open its window beside the auction house
-------------------------------------------------------------------------------
-- Every file Professions.xml lists, in its order, after the feature switches they read.
local xml = assert(io.open(DIR .. "/Professions.xml", "rb")):read("*a"):gsub("<!%-%-.-%-%->", "")
local paths = { "Core/Features.lua" }
for file in xml:gmatch("<Script%s+file=\"([^\"]+)\"") do paths[#paths + 1] = DIR .. "/" .. file:gsub("\\", "/") end
Load(paths, env)
local recipes = api.Build(ns.RecipeData)

-- Count the auction house panels' draws: the shopping list places itself on every draw.
local place = ns.ShoppingListPlace
ns.ShoppingListPlace = function() Count("shopping") return place() end
-- The window's draws: the recipe pane starts each by drawing the shopping list column. Its
-- re-reads of every recipe: each asks the recipe finder for the unlearned ones.
local column = ns.ShoppingListRender
ns.ShoppingListRender = function(info, last)
    if not info then Count("render") end
    return column(info, last)
end
local unlearned = ns.RecipeFinder.Unlearned
ns.RecipeFinder.Unlearned = function(learned)
    Count("reread")
    return unlearned(learned)
end

-- Ten favourite patterns to look up at the auction house, one of them an item that never
-- loads, exercise two pages; the shopping list has that item on it too.
local FAVORITE_PATTERNS = 10
local favorites, favCount = {}, 0
for i = LEARNED_N + 1, #recipes do
    local r = recipes[i]
    if r.recipe and favCount < FAVORITE_PATTERNS then
        favorites[r.spell] = true
        favCount = favCount + 1
        if favCount == 2 then loaded[r.recipe] = nil; r.recipe = BROKEN end
        patternItems[r.recipe] = true
    end
end
db.craftFavorites = favorites
account.profShopping = { ["Tester-Realm"] = {
    [recipes[1].spell] = { name = "Recipe 1", icon = 1, count = 2,
        need = { [BROKEN] = 1, [REAGENTS[3]] = 2, [REAGENTS[4]] = 3, [REAGENTS[9]] = 1 } },
} }

-- With Recipe Availability Marks on, a Shopping List change before the recipe window is ever
-- built, as from /nf shopping after a reload, has no list to draw.
settings.recipeAvailability = true
local listRenders = 0
local listRender = ns.Professions.List.Render
ns.Professions.List.Render = function() listRenders = listRenders + 1 return listRender() end
check("a shopping change before the window is built does not error",
    pcall(ns.Professions.Shopping.Step, recipes[1].spell, 0))
check("and draws no recipe list", listRenders == 0)
settings.recipeAvailability = false

Fire("PLAYER_LOGIN")
Fire("AUCTION_HOUSE_SHOW")
Advance(0.5)
local win = env.NaowhForeverProfessions
assert(win and win:IsShown(), "the window opens")
check("the window lists recipes", calls.render > 0)
check("manual favourite scanning sends nothing before Scan", calls.SendSearchQuery == 0)
local patternWindow = ns.FavoritePatternsFrames()
check("manual favourite scanning builds its Scan button", patternWindow and patternWindow.scan)
check("manual favourite scanning pages every pattern", patternWindow.pageCount == 2)
patternWindow.hooks.OnMouseWheel[1](patternWindow, -1)
check("the mouse wheel reaches the next pattern page", patternWindow.pager.label.text == "2 / 2")
patternWindow.hooks.OnMouseWheel[1](patternWindow, 1)
patternWindow.scan.scripts.OnClick(patternWindow.scan)
check("Scan starts with one auction search", calls.SendSearchQuery == 1)
patternWindow.scan.scripts.OnClick(patternWindow.scan)
Advance(3.5)
check("Pause stops before the next auction search", calls.SendSearchQuery == 1)
patternWindow.scan.scripts.OnClick(patternWindow.scan)
check("Resume continues the queued auction searches", calls.SendSearchQuery == 2)
patternWindow.scan.scripts.OnClick(patternWindow.scan)

-- Searches that time out are tried again: the scan stops at Resume, not done with them unsearched.
patternWindow.scan.scripts.OnClick(patternWindow.scan)
Advance(60)
check("a scan whose searches timed out waits to resume", patternWindow.scan.label.text == "Resume Scan")
local sent = calls.SendSearchQuery
patternWindow.scan.scripts.OnClick(patternWindow.scan)
check("Resume searches the timed-out patterns again", calls.SendSearchQuery == sent + 1)

-- A new scan's search is not cut short by the timeout of one from before a reset.
ns.Professions.Settings.Set("manualPatternScan", true)
Advance(0.5)
patternWindow.scan.scripts.OnClick(patternWindow.scan)
Advance(1)
ns.Professions.Settings.Set("manualPatternScan", true)
Advance(0.5)
patternWindow.scan.scripts.OnClick(patternWindow.scan)
sent = calls.SendSearchQuery
Advance(2)
check("an earlier search's timeout leaves the new search running", calls.SendSearchQuery == sent)
patternWindow.scan.scripts.OnClick(patternWindow.scan)

settings.recipeAvailability = true
local bagReads = calls.GetContainerItemInfo
check("availability marks render", pcall(ns.Professions.List.Render))
check("availability marks scan bags once", calls.GetContainerItemInfo - bagReads <= 80)
local shopping = account.profShopping["Tester-Realm"]
local savedCraft = shopping[recipes[1].spell]
shopping[recipes[1].spell] = false
check("a legacy false shopping entry is ignored", pcall(ns.Professions.List.Render))
shopping[recipes[1].spell] = savedCraft
settings.recipeAvailability = false

-- A pass of every hot path, also the warm-up before measuring.
local list = win.list
local function Scroll()
    list.scripts.OnMouseWheel(list, -1)
    list.scripts.OnMouseWheel(list, 1)
end
local function Redraw() ns.ProfWindowRefresh(); Step() end
local function BagUpdate() Fire("BAG_UPDATE_DELAYED"); Advance(0.12) end
local function UnrelatedLoad() Fire("ITEM_DATA_LOAD_RESULT", UNRELATED, true); Step() end
for _ = 1, 5 do Redraw(); Scroll(); BagUpdate(); UnrelatedLoad() end
Advance(1)

-------------------------------------------------------------------------------
--  1. Item loads that are not the window's own redraw nothing
-------------------------------------------------------------------------------
local function Snapshot() return calls.render, calls.shopping, calls.RequestLoadItemDataByID end

local r0, s0 = Snapshot()
for _ = 1, 100 do UnrelatedLoad() end
local r1, s1 = Snapshot()
print(("  100 unrelated item loads at the AH: %d window redraws, %d shopping list redraws"):format(
    r1 - r0, s1 - s0))
check("an item loaded for the auction house's own lists does not redraw the window", r1 - r0 == 0)
check("nor the shopping list", s1 - s0 == 0)

-------------------------------------------------------------------------------
--  2. An item that never loads does not keep the window redrawing
-------------------------------------------------------------------------------
local function Break(on)
    broken = on
    loaded[BROKEN] = nil
    Redraw()
    Advance(0.3)
end
Break(true)
local r2, s2, q2 = Snapshot()
Advance(2)
local r3, s3, q3 = Snapshot()
print(("  2 s idle with an item that never loads: %d window redraws, %d shopping list redraws, "
    .. "%d load requests"):format(r3 - r2, s3 - s2, q3 - q2))
check("an item that fails to load does not redraw the window over and over", r3 - r2 <= 1)
check("nor the shopping list", s3 - s2 <= 1)

Break(false)

-------------------------------------------------------------------------------
--  2b. A name the window or the list is waiting for still shows once it loads
-------------------------------------------------------------------------------
local REAGENT = REAGENTS[14]    -- the chosen recipe's first reagent
loaded[REAGENT] = nil
Redraw()
local r5 = calls.render
Advance(0.3)
check("a reagent's name loading redraws the window once", calls.render == r5 + 1)

local LISTED = REAGENTS[3]      -- on the shopping list
loaded[LISTED] = nil
ns.Professions.Shopping.Materials()
local s5 = calls.shopping
Advance(0.3)
check("a listed material's name loading redraws the shopping list once", calls.shopping == s5 + 1)

-------------------------------------------------------------------------------
--  3. What each path costs
-------------------------------------------------------------------------------
local RUNS = 200
local function Cost(fn)
    for _ = 1, 3 do fn() end
    collectgarbage("collect")
    collectgarbage("stop")
    local before, start = collectgarbage("count"), os.clock()
    for _ = 1, RUNS do fn() end
    local ms = (os.clock() - start) * 1000 / RUNS
    local kb = (collectgarbage("count") - before) / RUNS
    collectgarbage("restart")
    return ms, kb
end

local function Report(label, fn, maxMs, maxKb)
    local info0, schem0, bag0 = calls.GetRecipeInfo, calls.GetRecipeSchematic, calls.GetContainerItemInfo
    local ms, kb = Cost(fn)
    local runs = RUNS + 3
    print(("  %s: %.3f ms, %.2f KB a call; %.0f GetRecipeInfo, %.0f GetRecipeSchematic, %.0f "
        .. "GetContainerItemInfo a call"):format(label, ms, kb, (calls.GetRecipeInfo - info0) / runs,
        (calls.GetRecipeSchematic - schem0) / runs, (calls.GetContainerItemInfo - bag0) / runs))
    check(label .. " takes under " .. maxMs .. " ms", ms < maxMs)
    check(label .. " makes under " .. maxKb .. " KB of garbage", kb < maxKb)
end

Report("full redraw", Redraw, 4, 0.05)
Report("bag update", BagUpdate, 4, 0.05)
Report("scroll a step down and up", Scroll, 1, 0.05)
Report("unrelated item load at the AH", UnrelatedLoad, 0.1, 0.01)
-- The auction house opening: the window redraws, the shopping list and Favorite Patterns show.
Report("auction house shown", function()
    Fire("AUCTION_HOUSE_SHOW")
    now = now + 0.31
    RunTimers()
end, 5, 0.5)
-- As the recipe pane draws it: the column first, then the chosen recipe's Add to List row.
Report("shopping list column with the recipe pane", function()
    ns.ShoppingListRender(nil)
    ns.ShoppingListRender(ns.ProfWindowAPI.SelectedInfo(), win.detail.reagents[1])
end, 0.5, 0.05)

Report("recipe list re-read", function() Fire("NEW_RECIPE_LEARNED"); Step() end, 4, 0.05)

-------------------------------------------------------------------------------
--  3b. Each trigger reads only what it can have changed. In game every recipe info, schematic
--  and container slot read is a new table: the client's share of the garbage.
-------------------------------------------------------------------------------
local KEYS = { "GetRecipeInfo", "GetRecipeSchematic", "GetContainerItemInfo", "GetAllRecipeIDs",
    "reread", "render" }
local function Calls(label, fn)
    local before = {}
    for i, k in ipairs(KEYS) do before[i] = calls[k] end
    fn()
    local d = {}
    for i, k in ipairs(KEYS) do d[k] = calls[k] - before[i] end
    print(("  %s: %d GetRecipeInfo, %d GetRecipeSchematic, %d GetContainerItemInfo, %d GetAllRecipeIDs; "
        .. "%d re-reads, %d draws"):format(label, d.GetRecipeInfo, d.GetRecipeSchematic,
        d.GetContainerItemInfo, d.GetAllRecipeIDs, d.reread, d.render))
    return d
end

local d = Calls("new recipe learned", function() Fire("NEW_RECIPE_LEARNED"); Step() end)
check("learning a recipe reads the recipes again, once", d.reread == 1 and d.render == 1)

d = Calls("bag update", function() Fire("BAG_UPDATE_DELAYED"); Advance(0.2) end)
check("a bag update reads no recipe list", d.reread == 0 and d.GetAllRecipeIDs == 0)
check("a bag update reads only the chosen recipe's info", d.GetRecipeInfo <= 3)
check("a bag update scans the bags once", d.GetContainerItemInfo <= 80 and d.render == 1)

d = Calls("price update burst", function()
    for _ = 1, 5 do ns.ProfWindowRefresh() end
    Step()
end)
check("new prices draw once and read no recipe list", d.render == 1 and d.reread == 0)
check("new prices read only the chosen recipe's info", d.GetRecipeInfo <= 3)
check("new prices do not scan the bags again", d.GetContainerItemInfo == 0)

d = Calls("10 list updates, nothing changed", function()
    for _ = 1, 10 do Fire("TRADE_SKILL_LIST_UPDATE") end
    Advance(0.2)
end)
check("a burst of list updates with nothing changed draws once", d.render == 1)
check("and only counts the recipes", d.reread == 0 and d.GetAllRecipeIDs <= 1)

local extra = recipes[LEARNED_N + 1].spell
recipeIDs[#recipeIDs + 1] = extra
recipeInfo[extra] = { recipeID = extra, name = "Recipe new", icon = 1, categoryID = 100, learned = true,
    relativeDifficulty = 0, numAvailable = 0 }
d = Calls("list update with a new recipe", function() Fire("TRADE_SKILL_LIST_UPDATE"); Advance(0.2) end)
check("a list update that adds a recipe reads the recipes again", d.reread == 1)
recipeIDs[#recipeIDs] = nil
recipeInfo[extra] = nil
Fire("TRADE_SKILL_LIST_UPDATE")
Advance(0.2)

childInfo.skillLevel = 151
d = Calls("list update after a skill-up", function() Fire("TRADE_SKILL_LIST_UPDATE"); Advance(0.2) end)
check("a skill-up reads the recipes again, for their colors", d.reread == 1)
childInfo.skillLevel = 150
Fire("SKILL_LINES_CHANGED")
Advance(0.2)

-- The Shopping List records the open profession's recipes once, when its list first settles.
Fire("TRADE_SKILL_LIST_UPDATE")
Advance(0.6)

-- Ten seconds of browsing: the auction house loads items for its lists, the client sends list
-- updates, and a price scan finishing redraws in a burst every two seconds.
d = Calls("10 s browsing the AH", function()
    for t = 1, 20 do
        for _ = 1, 20 do Fire("ITEM_DATA_LOAD_RESULT", UNRELATED, true) end
        Fire("TRADE_SKILL_LIST_UPDATE")
        Fire("TRADE_SKILL_LIST_UPDATE")
        if t % 4 == 0 then for _ = 1, 3 do ns.ProfWindowRefresh() end end
        Advance(0.5)
    end
end)
check("browsing the auction house reads no recipe list", d.reread == 0)
check("browsing draws at most once per burst", d.render <= 20)
check("each of those draws reads at most the chosen recipe's info", d.GetRecipeInfo <= 3 * d.render)

-------------------------------------------------------------------------------
--  4. Repeating it all grows no retained memory
-------------------------------------------------------------------------------
local function Round()
    for _ = 1, 50 do Redraw(); Scroll(); BagUpdate(); UnrelatedLoad() end
    Advance(1)
end
Break(true)
Round()
collectgarbage("collect"); collectgarbage("collect")
local base = collectgarbage("count")
for _ = 1, 6 do Round() end
collectgarbage("collect"); collectgarbage("collect")
local grown = collectgarbage("count") - base
print(("  retained after 300 more redraws, scrolls, bag updates and item loads: %+.2f KB"):format(grown))
check("repeated redraws and item loads grow no retained memory", grown < 2)

-------------------------------------------------------------------------------
--  5. Closed, it stays quiet
-------------------------------------------------------------------------------
-- The recipe pane listens to SPELL_UPDATE_USABLE while open, which fires often: it redraws only
-- when what that event can change (a requirement met or not, the recipe's cooldown) changed.
check("a recipe is shown in the pane", win.detail:IsShown())
local d0 = calls.detail
for _ = 1, 20 do Fire("SPELL_UPDATE_USABLE"); Advance(0.6) end
check("usable events with nothing changed redraw no recipe pane", calls.detail == d0)
requirements = UNMET
Fire("SPELL_UPDATE_USABLE"); Advance(0.6)
check("a requirement turning unmet redraws the pane once", calls.detail == d0 + 1)
requirements = EMPTY
Fire("SPELL_UPDATE_USABLE"); Advance(0.6)
check("and met again, once more", calls.detail == d0 + 2)

professionsFrame:Hide()
win:Hide()
Step()
local r4 = calls.render
for _ = 1, 50 do UnrelatedLoad(); BagUpdate() end
check("with the window closed, item loads and bag updates draw nothing", calls.render == r4)
settings.recipeAvailability = true
local lr = listRenders
ns.Professions.Shopping.Step(recipes[1].spell, 0)
check("with the window closed, a shopping change draws no recipe list", listRenders == lr)
settings.recipeAvailability = false

check("the recipe window's logo opens the Professions settings", logoPage == "Professions/Settings")
check("the Shopping List has a launcher that toggles it, with a real icon path", launcher
    and launcher.open == ns.ToggleShoppingList and launcher.icon == "Interface\\Icons\\INV_Misc_Note_01")

if #failures > 0 then
    for _, label in ipairs(failures) do print("  FAIL " .. label) end
    error(("test-professions-memory: %d of %d checks failed"):format(#failures, checks))
end
print(("test-professions-memory: %d checks passed"):format(checks))
