-- Run with Lua 5.1 from the repository root: a BiS pick's rank mark and tooltip line (Shared/UI/Marks.lua).
-- Picks one to three get a star in their own color (orange, silver, copper) and the rest their number;
-- the line under an item's tooltip says the rank once, never "#4 #4".
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local HEX = { muted = "999999" }
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    THEME = { muted = { r = 0.6, g = 0.6, b = 0.6 }, accent = {}, fg = {}, bg = {}, line = {}, accentSoft = {} },
    Color = function(token, text) return "|cff" .. HEX[token] .. text .. "|r" end,
}
dofile("Tools/regression/load_files.lua")({ "Shared/Shared.lua", "Shared/Style.lua", "Shared/UI/Parts.lua",
    "Shared/UI/Marks.lua" }, { _G = { NaowhForever = ns } })
local Parts, St = ns.Shared.Parts, ns.Shared.Style

local function Hex(c) return ("%02x%02x%02x"):format(c.r * 255 + 0.5, c.g * 255 + 0.5, c.b * 255 + 0.5) end

check("the third pick has a copper star color", Hex(Parts.RankColor(3)) == "a0522d"
    and Parts.RankColor(3) == St.THIRD_RGB)
check("picks one to three are stars", Parts.RankMark(1):find("|T", 1, true) and Parts.RankMark(2):find("|T", 1, true)
    and Parts.RankMark(3):find("|T", 1, true))
check("the fourth pick is its number", Parts.RankMark(4):find("#4", 1, true) and not Parts.RankMark(4):find("|T", 1, true))
local third, fourth = Parts.RankLine(3), Parts.RankLine(4)
check("the third pick's line is its star and its rank once", third:find("|T", 1, true)
    and select(2, third:gsub("#3", "")) == 1)
check("the fourth pick's line says its rank once", select(2, fourth:gsub("#4", "")) == 1
    and not fourth:find("|T", 1, true))
check("the first pick's line is its star and Your BiS", Parts.RankLine(1):find("|T", 1, true)
    and Parts.RankLine(1):find("Your BiS", 1, true))

print(("test-rank-marks: %d checks passed"):format(checks))
