-- Run with Lua 5.1 from the repository root: the game's replace enchant popup is left to the
-- player. Its Yes calls C_Item.ReplaceEnchant, which only the game's own code may call; Auto-Replace
-- Enchants called it from a popup hook, so the game blocked the addon and closed the popup, and an
-- armor kit or enchant over an old one could not be applied until the addon was turned off.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local CONFIRMS = { "ReplaceEnchant", "ReplaceTradeEnchant", "ReplaceTradeskillEnchant", "BindEnchant" }
local POPUPS = { "REPLACE_ENCHANT", "TRADE_REPLACE_ENCHANT", "REPLACE_TRADESKILL_ENCHANT", "BIND_ENCHANT" }

local count = 0
local function Case(name, fn)
    fn()
    count = count + 1
    print("PASS " .. name)
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local function AddonFiles()
    local out = {}
    for _, path in ipairs(TocFiles("%.lua$")) do
        if not path:find("^Libs/") and not path:find("/Libs/") then out[#out + 1] = path end
    end
    return out
end

Case("no addon file answers an enchant confirmation", function()
    local found, scanned = {}, 0
    for _, path in ipairs(AddonFiles()) do
        scanned = scanned + 1
        local n = 0
        for line in (Read(path) .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            if not line:match("^%s*%-%-") then
                for _, call in ipairs(CONFIRMS) do
                    if line:find("%f[%w_]" .. call .. "%s*%(") then
                        found[#found + 1] = ("%s:%d calls %s"):format(path, n, call)
                    end
                end
                for _, popup in ipairs(POPUPS) do
                    if line:find("[\"']" .. popup .. "[\"']") then
                        found[#found + 1] = ("%s:%d handles the %s popup"):format(path, n, popup)
                    end
                end
            end
        end
    end
    assert(scanned > 100, "too few files scanned: " .. scanned)
    assert(#found == 0, table.concat(found, "\n"))
end)

Case("the retired setting is read nowhere", function()
    for _, path in ipairs(AddonFiles()) do
        assert(not Read(path):find("[\"']enchantReplace[\"']"), path .. " still reads enchantReplace")
    end
end)

Case("the Looting card no longer offers it", function()
    local card
    local env = setmetatable({
        NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = { Get = function() return true end },
            Shared = { Settings = { Page = function()
                return { Card = function(_, spec) card = spec end }
            end } } },
        hooksecurefunc = function() end,
    }, { __index = _G })
    env._G = env
    local chunk = assert(loadfile("NaowhForever_QoL/Loot/DeleteConfirm.lua"))
    setfenv(chunk, env)
    chunk()
    assert(card and card.id == "looting", "Looting card not built")
    for _, row in ipairs(card.rows) do
        assert(row.key ~= "enchantReplace", "Auto-Replace Enchants is still offered")
    end
    assert(not card.help:lower():find("enchant", 1, true), "card help still promises enchants")
end)

print(("test-enchant-replace: %d cases passed"):format(count))
