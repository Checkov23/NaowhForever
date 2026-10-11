-- Run with Lua 5.1 from the repository root: coin loot on the live Loot Feed. A second coin
-- loot adds to the coin line still on screen instead of stacking a line, and once that line
-- has faded its row is reused for the next loot, starting from nothing. The running total is
-- kept apart from the row's coin widgets. Frames here are stubs: this does not emulate the
-- game's renderer or its animations.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local methods = {}
local frameMeta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:find("^[A-Z]") then return methods.Nothing end
end }
local frames = {}
local function New(kind, parent, name)
    local f = setmetatable({ kind = kind, parent = parent, name = name, scripts = {}, events = {}, shown = true },
        frameMeta)
    frames[#frames + 1] = f
    return f
end
function methods.Nothing() end
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:UnregisterEvent(e) self.events[e] = nil end
function methods:UnregisterAllEvents() for e in pairs(self.events) do self.events[e] = nil end end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(on) self.shown = on and true or false end
function methods:IsShown() return self.shown end
function methods:GetParent() return self.parent end
function methods:SetText(t) self.text = t end
function methods:CreateTexture() return New("Texture", self) end
function methods:CreateFontString() return New("FontString", self) end
function methods:CreateAnimationGroup() return New("AnimationGroup", self) end
function methods:CreateAnimation() return New("Animation", self) end

local defaults = { enabled = true, lootFeed = true, lootFeedMoney = true, lootFeedXP = false, lootFeedQuality = 1,
    lootFeedQuest = true, lootFeedRep = false, lootFeedCount = 6, lootFeedFade = 5, lootFeedStyle = "dark",
    lootFeedGlow = false, lootFeedValue = true, lootFeedBank = true, lootFeedPrice = "vendor", lootFeedGPH = false,
    hideLootWindow = false, fastLoot = false, lootFeedWidth = 340, lootFeedHeight = 36, lootFeedSpacing = -1,
    lootFeedGrowth = "up", lootFeedFont = "", lootFeedFontSize = 13 }
local S = { Get = function(k) return defaults[k] end, Set = function(k, v) defaults[k] = v end }

local THEME = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
    accent = { r = 0, g = 0.57, b = 0.93 }, bg = { r = 0, g = 0, b = 0 } }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    QoLSettings = S, THEME = THEME,
    Apply = function() end, ShowUnlockMode = function() end, HideUnlockMode = function() end,
    Border = function(parent)
        local border = New("Border", parent)
        border._frame = New("Frame", parent)
        return border
    end,
    Font = function(parent) return New("FontString", parent) end,
    Solid = function(parent) return New("Texture", parent) end,
    ThemeTint = function(_, literal) return literal end,
    OnePixel = function() return 1 end,
    UI = { FontPath = function() return "font" end, AttachMover = function(f) return New("Mover", f) end },
    Shared = {
        Style = dofile("Tools/regression/shared_style.lua"),
        Parts = { HUD_OUTLINES = { {}, {} }, HudFont = function(fs) return fs end },
        Settings = {
            Group = function(name) return { group = name } end,
            Look = function() return {} end,
            Page = function() return { Card = function() end } end,
        },
    },
}

local env = setmetatable({
    NaowhForever = ns, UIParent = New("Frame"), GameTooltip = New("GameTooltip"),
    CreateFrame = function(kind, name, parent) return New(kind, parent, name) end,
    CreateColor = function() return {} end,
    hooksecurefunc = function(t, k, fn)
        local old = t[k]
        t[k] = function(...) old(...); fn(...) end
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    BreakUpLargeNumbers = function(n) return tostring(n) end,
    GetTime = function() return 0 end,
    LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.", LOOT_ITEM_SELF = "You receive loot: %s.",
    LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d.", LOOT_ITEM_PUSHED_SELF = "You receive item: %s.",
    GOLD_AMOUNT = "%d Gold", SILVER_AMOUNT = "%d Silver", COPPER_AMOUNT = "%d Copper",
    FACTION_STANDING_INCREASED = "Reputation with %s increased by %d.",
    COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience.",
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Loot/LootFeed.lua"))
setfenv(chunk, env)
chunk()

for i = 1, #frames do
    local f = frames[i]
    if f.events.PLAYER_LOGIN then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
end
local events
for _, f in ipairs(frames) do if f.events.CHAT_MSG_MONEY then events = f end end
check("the feed listens for coin loot once it is on", events ~= nil)
local function Money(text) events.scripts.OnEvent(events, "CHAT_MSG_MONEY", text) end

-- The feed's lines: the frames that hold coin widgets.
local function Lines()
    local out = {}
    for _, f in ipairs(frames) do if type(f.coins) == "table" and f.anim then out[#out + 1] = f end end
    return out
end
-- A coin the line has none of is hidden rather than shown as 0.
local function Amount(pair) return pair.amount.shown and tonumber(pair.amount.text) or 0 end
local function Shows(row, gold, silver, copper)
    local c = row.coins
    return type(c) == "table" and Amount(c[1]) == gold and Amount(c[2]) == silver and Amount(c[3]) == copper
end

Money("You loot 1 Gold, 20 Silver, 5 Copper")
local lines = Lines()
local row = lines[1]
check("coin loot adds one line", #lines == 1 and row.shown)
check("the line shows the coins looted", Shows(row, 1, 20, 5))

Money("You loot 99 Copper")
check("more coins add to the line still on screen", #Lines() == 1 and Shows(row, 1, 21, 4))
Money("Your share of the loot is 2 Gold")
check("and a group share adds to it too", #Lines() == 1 and Shows(row, 3, 21, 4))

-- The line fades out and its row goes back to the pool.
row.anim.scripts.OnFinished()
check("the faded line is hidden", not row.shown)

Money("You loot 2 Silver, 50 Copper")
check("the next coin loot reuses the faded row", #Lines() == 1 and row.shown)
check("and starts from nothing", Shows(row, 0, 2, 50))
Money("You loot 50 Copper")
check("coins add up on a reused row as well", Shows(row, 0, 3, 0))

print(("test-loot-feed-coins: %d checks passed"):format(checks))
