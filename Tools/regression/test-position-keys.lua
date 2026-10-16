-- Run with Lua 5.1 from the repository root: Keep My Positions (Core/Profiles/Positions.lua). Every
-- position key a shipped file saves is on its list, every listed key is still used, and keeping copies
-- your values, clears what you never moved and makes no empty stores.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local function Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
    return out
end

local ns = {}
local chunk = assert(loadfile("Core/Profiles/Positions.lua"))
setfenv(chunk, setmetatable({ _G = { NaowhForever = ns }, CopyTable = Copy }, { __index = _G }))
chunk()
local LIST = ns.POSITION_KEYS

-- Keys that look like positions but are not one of yours to keep: a choice of side, an old key a
-- migration reads, or a position saved for the account, which an import never touches.
local NOT_KEPT = { statusPos = true, coTankDebuffPosition = true, campAlertPos = true, talentPointsPos = true,
    durabilityPos = true, restockPos = true, petTrackerPos = true, rareAlertPos = true, rxpWindowPos = true,
    minimapPos = true }

local listed, source, sourceFiles = {}, {}, {}
for _, keys in pairs(LIST) do
    for _, key in ipairs(keys) do listed[key] = true end
end
local files = assert(io.popen("git ls-files *.lua"))
for path in files:lines() do
    if not (path:find("^Tools/") or path:find("^Libs/") or path:find("Locales/", 1, true)) then
        local f = assert(io.open(path, "rb"))
        source[#source + 1] = f:read("*a")
        sourceFiles[#sourceFiles + 1] = source[#source]
        f:close()
    end
end
files:close()
Check(#source > 100, "the shipped files were read")
source = table.concat(source, "\n")

local missing = {}
for word in source:gmatch('"(%a+Pos%d?)"') do
    if not listed[word] and not NOT_KEPT[word] then missing[#missing + 1] = word end
end
for word in source:gmatch('"(%a+Position)"') do
    if not listed[word] and not NOT_KEPT[word] then missing[#missing + 1] = word end
end
Check(#missing == 0, "every saved position is on the list: add " .. table.concat(missing, ", "))

local bars = 0
for _, file in ipairs(sourceFiles) do
    if file:find("Anchor.Rows(", 1, true) and not file:find("function Anchor.Rows(", 1, true) then
        local prefix = file:match('prefix = "(%a+)"')
        local name = not prefix and file:match("prefix = ([%w_%.]+)")
        if name then
            local spelled = "%f[%w_%.]" .. name:gsub("%.", "%%.") .. ' = "(%a+)"'
            prefix = file:match(spelled) or source:match(spelled)
        end
        Check(prefix, "a bar pinned to a unit frame names its prefix")
        bars = bars + 1
        for _, suffix in ipairs({ "Anchor", "AnchorPoint", "AnchorRelPoint", "X", "Y" }) do
            Check(listed[prefix .. suffix], "the pinned bar's " .. prefix .. suffix .. " is on the list")
        end
    end
end
Check(bars >= 3, "the Consumable Bar, the Food & Drink Bar and Blessings pin to a unit frame")

for db, keys in pairs(LIST) do
    Check(source:find('ModuleSettings("' .. db .. '"', 1, true), db .. " is a settings store")
    for _, key in ipairs(keys) do
        Check(source:find('"' .. key .. '"', 1, true) or source:find("%f[%w]" .. key .. " =")
            or source:find("%f[%w]" .. key .. "=", 1), db .. "." .. key .. " is still used")
    end
end

local mine = { qol = { lootFeedPos = { point = "TOP", x = 1, y = 2 }, fastLoot = false },
    unlockMode = { layouts = { Mine = {} }, guides = false } }
local kept = ns.KeepPositions(mine)
local theirs = { qol = { lootFeedPos = { point = "BOTTOM" }, alertsPos = { point = "LEFT" }, fastLoot = true },
    unlockMode = { guides = true } }
ns.PutPositionsBack(theirs, kept)
Check(theirs.qol.lootFeedPos.point == "TOP" and theirs.qol.lootFeedPos ~= mine.qol.lootFeedPos,
    "your position comes back, as a copy")
Check(theirs.qol.alertsPos == nil, "a frame you never moved goes back to its default")
Check(theirs.qol.fastLoot == true and theirs.unlockMode.guides == true, "everything else stays theirs")
Check(theirs.unlockMode.layouts.Mine ~= nil, "your HUD Editor layouts")
Check(theirs.pvp == nil and theirs.damageMeter == nil, "no store is made for positions you never had")
ns.PutPositionsBack(theirs, ns.KeepPositions({}))
Check(theirs.qol.lootFeedPos == nil and theirs.qol.fastLoot == true, "keeping from an empty profile clears only positions")

print(("test-position-keys: %d checks passed"):format(checks))
