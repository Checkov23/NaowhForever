-- Run with Lua 5.1 from the repository root: the feature switches (Core/Features.lua).
-- Every switch is a boolean in a store some module declares with UI.ModuleSettings, and that
-- store's defaults name it: either as the same literal (true or false) or by reading it back
-- from ns.FEATURES under the same key. An unknown store or switch is an error, not nil, so a
-- typo cannot quietly turn a feature off.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
_G.NaowhForever = ns
assert(loadstring(Read("Core/Features.lua"), "Features"))()

check("the badges build flag is 0 or 1", ns.FEATURE_BADGES == 0 or ns.FEATURE_BADGES == 1)
check("an unknown store is an error", not pcall(function() return ns.FEATURES.noSuchStore end))
check("an unknown switch is an error", not pcall(function() return ns.FEATURES.qol.noSuchSwitch end))

local TocFiles = dofile("Tools/regression/toc_files.lua")
local coreFiles = TocFiles("%.lua$", "NaowhForever.toc")
check("the core TOC loads the features file right after the core",
    coreFiles[1] ~= nil and (function()
        for i, path in ipairs(coreFiles) do
            if path == "Core/Features.lua" then return coreFiles[i - 1] == "Core/Core.lua" end
        end
        return false
    end)())

-- Each store's defaults table, as source text without comments: the table passed to
-- UI.ModuleSettings("<store>", ...), or the local table it names.
local stores = {}
for _, path in ipairs(TocFiles("%.lua$")) do
    local source = Read(path):gsub("%-%-[^\n]*", "")
    for key, rest in source:gmatch("ModuleSettings%(%s*\"([%w_]+)\"%s*,%s*([^\n]*)") do
        local body
        if rest:find("^{") then
            local at = source:find("ModuleSettings%(%s*\"" .. key .. "\"%s*,%s*{")
            body = source:match("%b{}", at)
        else
            local name = rest:match("^([%a_][%w_]*)")
            body = name and source:match("local%s+" .. name .. "%s*=%s*(%b{})")
        end
        if body then stores[key] = { path = path, body = body } end
    end
end

-- The account store has no UI.ModuleSettings: its switches are saved in ns.AccountSettings().
-- Each must be saved there under its own key and read back from ns.FEATURES.account in the
-- same file, directly or through a local alias of that table.
local function AccountReader(key)
    for _, path in ipairs(TocFiles("%.lua$")) do
        local source = Read(path):gsub("%-%-[^\n]*", "")
        if source:find("AccountSettings%(%)%." .. key .. "[^%w_]") then
            if source:find("FEATURES%.account%." .. key .. "[^%w_]") then return path end
            local alias = source:match("local%s+([%a_][%w_]*)%s*=%s*ns%.FEATURES%.account[^%.%w_]")
            if alias and source:find("[^%w_]" .. alias .. "%." .. key .. "[^%w_]") then return path end
        end
    end
end

for key, value in pairs(ns.FEATURES.account) do
    check("account." .. key .. " is a boolean", type(value) == "boolean")
    check("account." .. key .. " is saved in AccountSettings and read from ns.FEATURES.account",
        AccountReader(key) ~= nil)
end

local function CheckStore(store, switches)
    local declared = stores[store]
    check(("a module declares the %q store"):format(store), declared ~= nil)
    for key, value in pairs(switches) do
        local where = ("%s.%s (%s)"):format(store, key, declared.path)
        check(where .. " is a boolean", type(value) == "boolean")
        local given = declared.body:match("[%s,{]" .. key .. "%s*=%s*([^,\n}]+)")
        check(where .. " is in the store's defaults", given ~= nil)
        given = given:gsub("%s+$", "")
        if given == "true" or given == "false" then
            check(where .. " matches the store's default, " .. given, tostring(value) == given)
        else
            check(where .. " is read from ns.FEATURES under its own key, not " .. given,
                given:match("%.([%w_]+)$") == key)
        end
    end
end

for store, switches in pairs(ns.FEATURES) do
    if store ~= "account" then CheckStore(store, switches) end
end

print(("test-features: %d checks passed"):format(checks))
