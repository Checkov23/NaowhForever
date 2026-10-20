-- Run with Lua 5.1 from the repository root: the saved quest rewards list reads, removes and clears the picks,
-- keeps them per class and hands old classless picks to the first class to log in, unconfirmed until that class picks
-- them again, tolerates damaged entries, and falls back to the title kept at save time; the window's X removes that
-- quest's pick, loaded with the Shared files and the window against stubs.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local NOTHING = function() end
local Frame
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.scripts[script] = f.scripts[script] or fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    GetParent = function(f) return rawget(f, "parent") end,
    GetWidth = function() return 400 end,
    GetHeight = function() return 24 end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
    GetFrameLevel = function() return 1 end,
    IsForbidden = function() return false end,
    GetEffectiveScale = function() return 1 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
    CreateAnimationGroup = function(f) return Frame(f) end,
    CreateAnimation = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    return setmetatable({ scripts = {}, events = {}, parent = parent }, META)
end

local WHITE = { r = 1, g = 1, b = 1 }
local timers = {}
local tooltip = Frame()
tooltip.GetOwner = function() return nil end

local db, account = { questRewards = { [10] = 111, [20] = 222, [30] = 333, bad = 5, [40] = "x",
    PALADIN = { [10] = 999, [50] = 555 } } }, {}
local class = "DRUID"
local settings = {}
local S = { Get = function(key) return settings[key] end, Set = function() end, DB = function() return db end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S, Print = NOTHING, Apply = NOTHING, AccountSettings = function() return account end,
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    ThemeTint = function(_, literal) return literal end,
    Hairline = function(region) return region end,
    PixelInset = function(region) return region end,
    Border = function() return { SetColor = NOTHING } end,
    AccentBorder = function() return { SetColor = NOTHING } end,
    AllowOffscreen = NOTHING,
    Button = function(parent) return Frame(parent) end,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    UI = { Keep = NOTHING, SlimScroll = function(parent) return Frame(parent) end, CloseOnEscape = NOTHING },
}

local titles = { [10] = "Ten" }
local hooks, frames, rewarded = {}, {}, {}
local choices = { 111, 222 }
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent)
        local frame = Frame(parent)
        frames[#frames + 1] = frame
        return frame
    end,
    UnitClass = function() return "Class", class end,
    hooksecurefunc = function(a, b, c)
        if type(a) ~= "table" then
            hooks[a] = b
            return
        end
        local original = a[b]
        a[b] = function(...) original(...); c(...) end
    end,
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_QuestLog = { GetTitleForQuestID = function(id) return titles[id] end, RequestLoadQuestByID = NOTHING },
    C_Item = {
        GetItemInfoInstant = function(id) return id end,
        GetItemInfo = function(id) return "item " .. id end,
        GetItemNameByID = function(id) return "item " .. id end,
        GetItemQualityByID = function() return 1 end,
        GetItemIconByID = function(id) return id end,
        GetItemCount = function() return 0 end,
        IsItemDataCachedByID = function() return true end,
    },
    ITEM_QUALITY_COLORS = { [1] = { hex = "|cffffffff", r = 1, g = 1, b = 1 } },
    GameTooltip = tooltip,
    GameTooltip_Hide = NOTHING,
    InCombatLockdown = function() return false end,
    IsAltKeyDown = function() return true end,
    IsShiftKeyDown = function() return false end,
    IsControlKeyDown = function() return false end,
    QuestInfoFrame = { questLog = true },
    GetQuestID = function() return 1 end,
    GetNumQuestChoices = function() return #choices end,
    GetQuestItemInfo = function(_, i) return nil, nil, nil, nil, nil, choices[i] end,
    GetQuestLogChoiceInfo = function(i) return nil, nil, nil, nil, nil, choices[i] end,
    GetQuestLogItemLink = NOTHING,
    GetTitleText = NOTHING,
    GetQuestReward = function(i) rewarded[#rewarded + 1] = i end,
    CreateColor = function() return Frame() end,
    UIParent = Frame(),
}, { __index = _G })
env._G = env

local files = TocFiles("^Shared/.*%.lua$")
for i = #files, 1, -1 do
    if files[i] == "Shared/UI/CopyCard.lua" then table.remove(files, i) end
end
files[#files + 1] = "NaowhForever_QoL/Questing/QuestAutomation.lua"
files[#files + 1] = "NaowhForever_QoL/Questing/RewardList.lua"
Load(files, env)

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local R = ns.QuestRewards
local list = R.List({})
table.sort(list)
check("only well-formed picks are listed", #list == 3 and list[1] == 10 and list[3] == 30)
local itemID, unconfirmed = R.ItemID(20)
check("an old numeric pick reads back its item, not confirmed", itemID == 222 and unconfirmed == true)
check("old classless picks move under the class that logs in", db.questRewards.DRUID[20] == -222
    and db.questRewards[20] == nil and db.questRewards[40] == nil and db.questRewards.bad == 5)
check("another class keeps its own picks", db.questRewards.PALADIN[10] == 999 and db.questRewards.PALADIN[50] == 555
    and R.ItemID(50) == nil and R.ItemID(10) == 111)

check("a cached title wins", R.Title(10) == "Ten")
check("no title is nil", R.Title(20) == nil)
account.questTitles = { [20] = "Kept" }
check("the title kept at save time is the fallback", R.Title(20) == "Kept")

local changed = 0
R.OnChange(function() changed = changed + 1 end)
R.Remove(20)
local mine = db.questRewards.DRUID
check("remove drops that quest only", mine[20] == nil and mine[10] == -111 and changed == 1)
R.Clear()
check("clear drops this class's picks only", next(mine) == nil and db.questRewards.PALADIN[10] == 999
    and changed == 2)
check("an empty list is empty", #R.List({}) == 0)
db.questRewards = { [10] = 111, DRUID = { [10] = 222 } }
itemID, unconfirmed = R.ItemID(10)
check("a class's own pick wins over an old classless one", itemID == 222 and not unconfirmed
    and db.questRewards[10] == nil)
db.questRewards = { [10] = 111 }
ns.Apply()
check("a profile switch tells the window", changed == 3)

local views = {}
local NewView = ns.Shared.View.New
ns.Shared.View.New = function(...)
    local view = NewView(...)
    views[#views + 1] = view
    return view
end
db.questRewards = { DRUID = { [10] = 111, [20] = 222, [30] = -333 }, PALADIN = { [60] = 666 } }
ns.OpenQuestRewards()
local rewardView = views[1]
local function Find(questID)
    for i = 1, rewardView.pools.item.used do
        local row = rewardView.pools.item[i]
        if row:IsShown() and row.key == questID then return row end
    end
end
local row = Find(20)
check("the window lists a row for each saved reward", rewardView.pools.item.used == 3 and row and row.itemID == 222
    and row.remove.shown == true and row.value.text == "")
row = Find(30)
check("an unconfirmed pick shows its item, marked", row.itemID == 333 and row.value.text == "Not confirmed")
row = Find(20)
row.remove.scripts.OnClick(row.remove)
mine = db.questRewards.DRUID
check("its X removes that quest's reward only", mine[20] == nil and mine[10] == 111 and mine[30] == -333)
while #timers > 0 do table.remove(timers, 1)() end
check("and the row goes", Find(20) == nil and Find(10) ~= nil)

settings.enabled, settings.questTurnIn, settings.questRewardPicks = true, true, true
ns.Apply()
local events
for _, frame in ipairs(frames) do
    if frame.events.QUEST_COMPLETE then events = frame end
end
local function HandIn()
    rewarded[1] = nil
    events.scripts.OnEvent(events, "QUEST_COMPLETE")
    return rewarded[1]
end
db.questRewards = { [1] = 222 }
check("an old pick is not handed in for you", HandIn() == nil and db.questRewards.DRUID[1] == -222)
local button = Frame()
button.type, button.objectType, button.questID = "choice", "item", 1
button.GetID = function() return 2 end
hooks.QuestInfo_GetRewardButton({ RewardButtons = { button } }, 1)
button.scripts.OnClick(button)
check("picking it again confirms it", db.questRewards.DRUID[1] == 222 and select(2, R.ItemID(1)) == nil)
check("a confirmed pick is handed in for you", HandIn() == 2)
button.scripts.OnClick(button)
check("Alt-clicking a confirmed pick still clears it", db.questRewards.DRUID[1] == nil and HandIn() == nil)

print(checks .. " saved quest reward checks passed")
