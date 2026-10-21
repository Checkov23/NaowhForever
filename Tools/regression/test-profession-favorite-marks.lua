-- Run with Lua 5.1 from the repository root: favorite trainer and merchant marks stay opt-in and current.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end
local function Noop() end

local values, listeners, registry = {}, {}, {}
local frames, applyHooks = {}, {}
local merchantHook, trainerHook, favoriteHook, scrollHook
local vendorEntries = { { item = 111 } }
local trainerOffers = { { name = "Fine Leather Gloves" } }
local stock = -1
local listCalls, offerCalls = 0, 0
local ROW_RIGHT, NAME_LEFT = 153, 46

local textureMethods = {}
function textureMethods:SetSize(width, height) self.width, self.height = width, height end
function textureMethods:ClearAllPoints() self.point = nil end
function textureMethods:SetPoint(...) self.point = { ... } end
function textureMethods:Show() self.shown = true end
function textureMethods:Hide() self.shown = false end

local function Texture()
    return setmetatable({ shown = false }, { __index = textureMethods })
end

local function Font(text, width)
    return {
        GetText = function() return text end,
        GetStringWidth = function() return width end,
        GetLeft = function() return NAME_LEFT end,
    }
end

local rowMethods = {}
function rowMethods:GetName() return self.frameName end
function rowMethods:GetRight() return ROW_RIGHT end
function rowMethods:CreateTexture()
    self.mark = Texture()
    return self.mark
end

local function Row(name, text, index, width)
    return setmetatable({
        frameName = name,
        Name = Font(text, width),
        Text = Font(text, width),
        ItemButton = { GetID = function() return index end },
    }, { __index = rowMethods })
end

local frameMethods = {}
function frameMethods:RegisterEvent(event)
    registry[event] = registry[event] or {}
    registry[event][self] = true
end
function frameMethods:UnregisterAllEvents()
    for _, set in pairs(registry) do set[self] = nil end
end
function frameMethods:SetScript(name, fn) self.scripts[name] = fn end

local function Listening()
    local count = 0
    for _, set in pairs(registry) do for _ in pairs(set) do count = count + 1 end end
    return count
end

local function Fire(event, arg)
    local copy = {}
    for frame in pairs(registry[event] or {}) do copy[#copy + 1] = frame end
    for _, frame in ipairs(copy) do frame.scripts.OnEvent(frame, event, arg) end
end

local gamepad = false
local ns = {
    L = function(text) return text end,
    Apply = Noop,
    GamepadStandDown = function() return gamepad end,
    UI = {
        ModuleSettings = function(_, defaults)
            local S = {}
            function S.Get(key)
                if values[key] == nil then return defaults[key] end
                return values[key]
            end
            function S.Set(key, value)
                values[key] = value
                for _, fn in ipairs(listeners) do fn(key, value) end
            end
            function S.OnChange(fn) listeners[#listeners + 1] = fn end
            function S.Raw(key) return values[key] end
            function S.DB() return values end
            return S
        end,
    },
}

local merchantRow = Row("MerchantItem1", "Pattern: Fine Leather Gloves", 1, 100)
local trainerRow = Row("ClassTrainerSkill1", "Fine Leather Gloves", 1, 60)
local otherTrainerRow = Row("ClassTrainerSkill2", "Other Recipe", 2, 60)
local scroll = {
    Update = Noop,
    ForEachFrame = function(_, fn) fn(trainerRow) end,
}

local env = setmetatable({
    NaowhForever = ns,
    MerchantFrame = { selectedTab = 1, page = 1, IsShown = function() return true end },
    MerchantItem1 = merchantRow,
    ClassTrainerSkill1 = trainerRow,
    ClassTrainerSkill2 = otherTrainerRow,
    ClassTrainerFrame = { ScrollBox = scroll, IsShown = function() return true end },
    MerchantFrame_Update = Noop,
    ClassTrainerFrame_Update = Noop,
    GetMerchantItemID = function(index) return index == 1 and 111 or nil end,
    C_MerchantFrame = { GetItemInfo = function() return { numAvailable = stock } end },
    CreateFrame = function()
        local frame = setmetatable({ scripts = {} }, { __index = frameMethods })
        frames[#frames + 1] = frame
        return frame
    end,
    hooksecurefunc = function(target, name, fn)
        if target == ns and name == "Apply" then
            applyHooks[#applyHooks + 1] = fn
        elseif target == "MerchantFrame_Update" then
            merchantHook = name
        elseif target == "ClassTrainerFrame_Update" then
            trainerHook = name
        elseif target == scroll and name == "Update" then
            scrollHook = fn
        elseif target == ns.Professions.Favorites and name == "Toggle" then
            favoriteHook = fn
        end
    end,
    wipe = function(t) for key in pairs(t) do t[key] = nil end return t end,
}, { __index = _G })
env._G = env

Load({ "Core/Features.lua", "NaowhForever_Professions/Professions.lua" }, env)
local P, S = ns.Professions, ns.ProfessionSettings
P.Patterns = {
    List = function()
        listCalls = listCalls + 1
        return vendorEntries
    end,
    TrainerOffers = function()
        offerCalls = offerCalls + 1
        return trainerOffers
    end,
}
P.Widgets = { Star = function(mark) mark.starred = true end }
P.Favorites = { Toggle = Noop }
Load({ "NaowhForever_Professions/UI/FavoriteMarks.lua" }, env)

Check("the feature is off by default", not S.Get("favoriteVendorMarks"))
Check("off creates no frame or game hook", #frames == 0 and Listening() == 0
    and not merchantHook and not trainerHook and not favoriteHook and not scrollHook)

gamepad = true
S.Set("favoriteVendorMarks", true)
Check("the Gamepad interface style keeps it off: no frame or game hook", #frames == 0 and Listening() == 0
    and not merchantHook and not trainerHook and not favoriteHook and not scrollHook)
S.Set("favoriteVendorMarks", false)
gamepad = false

S.Set("favoriteVendorMarks", true)
Check("enabling registers only its eight events", #frames == 1 and Listening() == 8)
Check("enabling installs update hooks", merchantHook and trainerHook and favoriteHook and scrollHook)
Check("an in-stock favorite vendor pattern is starred", merchantRow.mark and merchantRow.mark.shown
    and merchantRow.mark.starred)
Check("a currently trainable favorite recipe is starred", trainerRow.mark and trainerRow.mark.shown
    and trainerRow.mark.starred)
Check("ordinary trainer recipes stay unmarked", not otherTrainerRow.mark)
Check("a short name puts the star after its text", trainerRow.mark.point[2] == trainerRow.Name
    and trainerRow.mark.point[3] == "LEFT" and trainerRow.mark.point[4] == 64)
Check("a name filling its box keeps the star inside the row", merchantRow.mark.point[4] == 95)

vendorEntries, trainerOffers = {}, {}
Fire("SPELLS_CHANGED")
Check("learned or unfavorited entries lose their marks", not merchantRow.mark.shown and not trainerRow.mark.shown)

vendorEntries = { { item = 111 } }
stock = 0
Fire("MERCHANT_SHOW")
Check("sold-out patterns stay unmarked", not merchantRow.mark.shown)
local before = listCalls
stock = -1
merchantHook()
Check("restocked favorite patterns are marked", merchantRow.mark.shown)
Check("a merchant update repaints without walking the patterns", listCalls == before)
Fire("MERCHANT_UPDATE")
Check("merchant updates are left to the game's own redraw", listCalls == before)
Fire("MERCHANT_SHOW")
merchantHook()
Check("opening a merchant walks the patterns once", listCalls == before + 1)

env.MerchantFrame.selectedTab = 2
merchantHook()
Check("the buyback tab hides merchant marks", not merchantRow.mark.shown)
env.MerchantFrame.selectedTab = 1

vendorEntries, trainerOffers = {}, {}
favoriteHook()
Check("changing a favorite refreshes both windows", not merchantRow.mark.shown and not trainerRow.mark.shown)
vendorEntries, trainerOffers = { { item = 111 } }, { { name = "Fine Leather Gloves" } }
Fire("TRAINER_SHOW")
Check("opening a trainer marks its favorite recipes", trainerRow.mark.shown)
before = offerCalls
scrollHook()
scrollHook()
trainerHook()
Check("trainer scrolling repaints without rebuilding the offers", trainerRow.mark.shown and offerCalls == before)
Fire("TRAINER_UPDATE")
Check("a trainer update rebuilds the offers once", offerCalls == before + 1)

S.Set("favoriteVendorMarks", false)
Check("turning it off unregisters its events", Listening() == 0)
Check("turning it off hides every mark", not merchantRow.mark.shown and not trainerRow.mark.shown)
merchantHook()
Check("installed hooks do no work while off", not merchantRow.mark.shown)

values.favoriteVendorMarks = true
for _, fn in ipairs(applyHooks) do fn() end
Check("applying a profile turns the feature back on", Listening() == 8 and merchantRow.mark.shown)

print(("test-profession-favorite-marks: %d checks passed"):format(checks))
