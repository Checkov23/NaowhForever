-- The theme colors written as |cffRRGGBB escapes used to be typed out by hand in 65 places. They
-- now come from ns.Color, and with the default theme every one of them must produce exactly the
-- string it replaced. Each row names the file, the shipped code (which must be in that file),
-- the same expression with sample arguments, and the literal it used to be. Run with Lua 5.1
-- from the repository root.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local frame = setmetatable({}, { __index = function() return function() end end })
function frame:SetScript() end
local coreEnv = { CreateFrame = function() return frame end,
    NaowhForeverDB = { account = {}, profiles = {}, charActive = {} } }
coreEnv._G = coreEnv
setmetatable(coreEnv, { __index = _G })
local core = assert(loadstring(Read("Core/Core.lua"), "Core"))
setfenv(core, coreEnv)
core("NaowhForever")
local ns = coreEnv.NaowhForever

local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end
local function Eval(text)
    local chunk = assert(loadstring("return " .. text))
    setfenv(chunk, setmetatable({ ns = ns }, { __index = _G }))
    return chunk()
end

local ROWS = {
    { [==[Core/Core.lua]==],
      [==[msg = ns.Color("accent", ns.L(TEXT_SECRET))]==],
      [==[ns.Color("accent", ns.L("(withheld: this line contained a secret value)"))]==],
      [==["|cff0091ed(withheld: this line contained a secret value)|r"]==] },
    { [==[Core/Core.lua]==],
      [==[local TEXT_SECRET = "(withheld: this line contained a secret value)"]==],
      [==[ns.Color("accent", "(withheld: this line contained a secret value)")]==],
      [==["|cff0091ed(withheld: this line contained a secret value)|r"]==] },
    { [==[Core/Core.lua]==],
      [==[print(ns.PRINT_LOGO .. " " .. ns.Color("accent", "Naowh") .. " Forever: " .. tostring(msg))]==],
      [==[ns.Color("accent", "Naowh") .. " Forever: " .. tostring("hi")]==],
      [==["|cff0091edNaowh|r Forever: " .. tostring("hi")]==] },
    { [==[Core/Core.lua]==],
      [==[return ns.Color("accent", title) .. "\n" .. ns.L(b)]==],
      [==[ns.Color("accent", ns.L("Title")) .. "\n" .. ns.L("body")]==],
      [==["|cff0091ed" .. "Title" .. "|r\n" .. "body"]==] },
    { [==[NaowhForever_DungeonJournal/View/QuestRows.lua]==],
      [==[text = text .. "  " .. ns.Color("accentSoft", TEXT_DUNGEON_QUEST)]==],
      [==["x" .. "  " .. ns.Color("accentSoft", "(dungeon quest)")]==],
      [==["x" .. "  |cff4db5f5(dungeon quest)|r"]==] },
    { [==[NaowhForever_DungeonJournal/View/QuestRows.lua]==],
      [==[local TEXT_DUNGEON_QUEST = ns.L("(dungeon quest)")]==],
      [==["x" .. "  " .. ns.Color("accentSoft", "(dungeon quest)")]==],
      [==["x" .. "  |cff4db5f5(dungeon quest)|r"]==] },
    { [==[NaowhForever_QoL/Loot/BagSpace.lua]==],
      [==[("  " .. ns.Color("muted", ns.L("(%s each x%d)"))):format(Coins(each), count)]==],
      [==[("  " .. ns.Color("muted", ns.L("(%s each x%d)"))):format("5g", 3)]==],
      [==[("  |cff9a9ea6(%s each x%d)|r"):format("5g", 3)]==] },
    { [==[NaowhForever_QoL/Loot/BagSpace.lua]==],
      [==[GameTooltip:AddLine(ns.Color("accent", ns.L("Click")) .. ns.L("  stack now"), 1, 1, 1)]==],
      [==[ns.Color("accent", ns.L("Click")) .. ns.L("  stack now")]==],
      [==["|cff0091edClick|r  stack now"]==] },
    { [==[NaowhForever_QoL/Loot/BagSpace.lua]==],
      [==[or ns.Color("muted", ns.L("unknown"))]==],
      [==[ns.Color("muted", ns.L("unknown"))]==],
      [==["|cff9a9ea6unknown|r"]==] },
    { [==[NaowhForever_QoL/Loot/BagSpace.lua]==],
      [==[GameTooltip:AddLine(ns.Color("accent", ns.L("Ctrl-click")) .. ns.L("  twice to delete"), 1, 1, 1)]==],
      [==[ns.Color("accent", ns.L("Ctrl-click")) .. ns.L("  twice to delete")]==],
      [==["|cff0091edCtrl-click|r  twice to delete"]==] },
    { [==[NaowhForever_QoL/Loot/BagSpace.lua]==],
      [==[GameTooltip:AddLine(ns.Color("accent", ns.L("Ctrl-click")) .. ns.L("  pick up to delete"), 1, 1, 1)]==],
      [==[ns.Color("accent", ns.L("Ctrl-click")) .. ns.L("  pick up to delete")]==],
      [==["|cff0091edCtrl-click|r  pick up to delete"]==] },
    { [==[NaowhForever_QoL/Loot/BagSpace.lua]==],
      [==[GameTooltip:AddLine(ns.Color("accent", "Ctrl-click") .. ns.L("  delete now"), 1, 1, 1)]==],
      [==[ns.Color("accent", "Ctrl-click") .. ns.L("  delete now")]==],
      [==["|cff0091edCtrl-click|r  delete now"]==] },
    { [==[NaowhForever_QoL/Loot/BagSpace.lua]==],
      [==[GameTooltip:AddLine(ns.Color("accent", ns.L("Click")) .. ns.L("  sell"), 1, 1, 1)]==],
      [==[ns.Color("accent", ns.L("Click")) .. ns.L("  sell")]==],
      [==["|cff0091edClick|r  sell"]==] },
    { [==[NaowhForever_QoL/Loot/BagSpace.lua]==],
      [==[GameTooltip:AddLine(ns.Color("accent", ns.L("Middle-click")) .. ns.L("  ignore this item"), 1, 1, 1)]==],
      [==[ns.Color("accent", ns.L("Middle-click")) .. ns.L("  ignore this item")]==],
      [==["|cff0091edMiddle-click|r  ignore this item"]==] },
    { [==[NaowhForever_QoL/Loot/LootFeed.lua]==],
      [==[name = name .. "  " .. ns.Color("accent", "BiS" .. (pick > 1 and " #" .. pick or ""))]==],
      [==["n" .. "  " .. ns.Color("accent", "BiS" .. (2 > 1 and " #" .. 2 or ""))]==],
      [==["n" .. "  |cff0091edBiS" .. (2 > 1 and " #" .. 2 or "") .. "|r"]==] },
    { [==[NaowhForever_QoL/XP/XPBar.lua]==],
      [==[local LABEL, VALUE = ns.Color("muted"), ns.Color("fg")]==],
      [==[ns.Color("muted") .. "Session:|r " .. ns.Color("fg") .. "1h" .. "|r"]==],
      [==["|cff9a9ea6" .. "Session:|r " .. "|cfff0f1f3" .. "1h" .. "|r"]==] },
}

local sources = {}
for _, r in ipairs(ROWS) do
    local file, has, new, old = r[1], r[2], r[3], r[4]
    sources[file] = sources[file] or Read(file)
    Check(sources[file]:find(has, 1, true), file .. ": ships `" .. has:sub(1, 60) .. "`")
    local got, want = Eval(new), Eval(old)
    Check(got == want, file .. ": " .. new:sub(1, 60) .. " is the old string")
end

-- Nothing in the addon spells a theme color out any more (comments may mention one).
-- Every Lua file the TOC loads, following the XML files it includes.
local toc = {}
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("%.lua$")) do
    if not path:find("^Locales") and not path:find("^Libs") then toc[#toc + 1] = path end
end
Check(#toc > 50, "the TOC lists the addon's files")
local left = {}
for _, path in ipairs(toc) do
    local n = 0
    for line in Read(path):gmatch("[^\n]+") do
        if not line:match("^%s*%-%-") then
            for hex in line:gmatch("|c[fF][fF](%x%x%x%x%x%x)") do
                hex = hex:lower()
                if hex == "0091ed" or hex == "9a9ea6" or hex == "f0f1f3" or hex == "4db5f5" then
                    n = n + 1
                    left[#left + 1] = path .. ": " .. line:sub(1, 80)
                end
            end
        end
    end
end
Check(#left == 0, "hand-written theme colors left: " .. table.concat(left, " | "))

-- The constants that used to be built at file load are looked up when they are used.
local function Slice(path, first, last)
    local source = Read(path)
    local a = assert(source:find(first, 1, true), path .. ": " .. first)
    local b = assert(source:find(last, a, true), path .. ": " .. last)
    return source:sub(a, b + #last - 1)
end
local function Run(code, env)
    local chunk = assert(loadstring(code))
    setfenv(chunk, setmetatable(env, { __index = _G }))
    return chunk()
end

local TAGS = { { "NaowhForever_BiS/BiS/Alerts.lua", "|cff0091edNaowh BiS|r" }, { "NaowhForever_QoL/Loot/Alts.lua", "|cff0091edNaowh|r" },
    { "NaowhForever_QoL/Loot/AuctionPrices.lua", "|cff0091edNaowh AH|r" }, { "NaowhForever_QoL/Loot/Mail.lua", "|cff0091edNaowh Mail|r" } }
for _, t in ipairs(TAGS) do
    local code = Slice(t[1], "local function Tag()", " end") .. "\nreturn Tag()"
    Check(Run(code, { ns = ns }) == t[2], t[1] .. ": Tag() is the old TAG")
end

print("PASS theme literals: " .. cases .. " checks (" .. #ROWS .. " rows, the tag accessors, and a scan for leftovers)")
