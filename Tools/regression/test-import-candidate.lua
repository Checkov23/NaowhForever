-- A character's first login and the main it is asked about: Core's SettingsRoot noting a new
-- character (saved in charAsk, so a reload or relog asks again), MarkSeen, MarkAsked and
-- ImportCandidate (the other character played most recently, on any profile), on a stub saved table.
-- From the repo root: lua5.1 Tools/regression/test-import-candidate.lua
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local f = assert(io.open(arg[1] or "Core/Core.lua", "rb"))
local src = f:read("*a"):gsub("\r\n", "\n"); f:close()

local function Slice(a, b)
    local first = assert(src:find(a, 1, true))
    return src:sub(first, assert(src:find(b, first + #a, true)) - 1)
end

local code = assert(src:match("\n(local MODULE_KEY = .-\n)\nlocal ns = {}\n"), "Core constants")
    .. Slice("local function CharKey()", "function ns.DB()")
    .. Slice("function ns.MarkSeen()", "function ns.ListProfiles()")

local function Login(sv, name, clock, guid)
    local env = { ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, STARTER = { profile = {}, account = {} } }, UNKNOWNOBJECT = "Unknown",
        UnitName = function() return name end, GetRealmName = function() return "Forever" end,
        UnitGUID = function() return guid end, time = function() return clock or 0 end }
    function env.CopyTable(t)
        local out = {}
        for k, v in pairs(t) do out[k] = v end
        return out
    end
    env._G = env
    env.NaowhForeverDB = sv
    setmetatable(env, { __index = _G })
    local chunk = assert(loadstring(code))
    setfenv(chunk, env)
    chunk()
    env.ns.SettingsRoot()
    return env.ns
end

do
    local sv = { profiles = { Default = {} }, charActive = {} }
    local ns = Login(sv, "Die Man")
    check("the account's first character is not offered anything", ns.ImportCandidate() == nil)
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, defaultProfile = "Default",
        charActive = { ["Die Man-Forever"] = "Raid", ["Die Pri-Forever"] = "Default" } }
    local ns = Login(sv, "Die Dudu", 300)
    local char, profile = ns.ImportCandidate()
    check("a new character lands on the account's profile", sv.charActive["Die Dudu-Forever"] == "Default")
    check("and is offered the character on another profile", char == "Die Man-Forever" and profile == "Raid")
    ns.MarkSeen()
    check("its login is noted", sv.charSeen["Die Dudu-Forever"] == 300)
    check("and it waits for an answer, saved by character", sv.charAsk["Die Dudu-Forever"] == true
        and sv.charAsk["Die Man-Forever"] == nil)
    ns = Login(sv, "Die Dudu", 400)
    char, profile = ns.ImportCandidate()
    check("a reload or relog with no answer: offered again", char == "Die Man-Forever" and profile == "Raid")
    Login(sv, "Die Man", 450).MarkAsked()
    check("another character's close leaves this one waiting", sv.charAsk["Die Dudu-Forever"] == true)
    ns.MarkAsked()
    check("answered: the wait is cleared", sv.charAsk == nil)
    check("and nothing is offered after, this session", ns.ImportCandidate() == nil)
    ns = Login(sv, "Die Dudu", 500)
    check("logging in again is not new: nothing offered", ns.ImportCandidate() == nil)
    ns.MarkAsked()
    check("a close with nothing waiting changes nothing", sv.charAsk == nil)
end

do
    local sv = { profiles = { Default = {} }, charActive = { ["Die Man-Forever"] = "Default" } }
    local ns = Login(sv, "Die Dudu")
    local char, profile = ns.ImportCandidate()
    check("the main on the same profile is still the main: asked, with its profile", char == "Die Man-Forever"
        and profile == "Default" and sv.charActive["Die Dudu-Forever"] == "Default")
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, defaultProfile = "Default",
        charActive = { ["Ann-Forever"] = "Default", ["Bob-Forever"] = "Raid" },
        charSeen = { ["Ann-Forever"] = 500, ["Bob-Forever"] = 100 } }
    local ns = Login(sv, "Die Dudu")
    local char, profile = ns.ImportCandidate()
    check("the character played most recently, even on this character's profile", char == "Ann-Forever"
        and profile == "Default")
    sv.charSeen["Bob-Forever"] = 900
    check("and it follows who was played last", (ns.ImportCandidate()) == "Bob-Forever")
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, defaultProfile = "Default",
        charActive = { ["Ann-Forever"] = "Raid", ["Bob-Forever"] = "Default" } }
    local ns = Login(sv, "Die Dudu")
    local char, profile = ns.ImportCandidate()
    check("this character landing on a profile does not count for it: a tie, by name", char == "Ann-Forever"
        and profile == "Raid")
    sv.charActive["Cid-Forever"] = "Default"
    check("two others on one profile: their profile wins", (ns.ImportCandidate()) == "Bob-Forever")
end

do
    local sv = { profiles = { Default = {}, Raid = {}, Alts = {} }, defaultProfile = "Default",
        charActive = { ["Ann-Forever"] = "Alts", ["Bob-Forever"] = "Raid", ["Cid-Forever"] = "Raid" },
        charSeen = { ["Ann-Forever"] = 500, ["Bob-Forever"] = 100 } }
    local ns = Login(sv, "Die Dudu")
    check("the character played most recently is offered", (ns.ImportCandidate()) == "Ann-Forever")
    sv.charSeen = nil
    sv.charActive["Die Dudu-Forever"] = nil
    ns = Login(sv, "Die Dudu")
    local char, profile = ns.ImportCandidate()
    check("none noted: the profile most characters use", profile == "Raid" and char == "Bob-Forever")
end

do
    local sv = { profiles = { Default = {} }, charActive = { ["Die Man-Forever"] = "Gone" } }
    local ns = Login(sv, "Die Dudu")
    check("a profile since deleted is not offered", ns.ImportCandidate() == nil)
end

do
    local sv = { profiles = { Default = {}, Raid = {} }, charActive = { ["Die Man-Forever"] = "Raid" } }
    local ns = Login(sv, "Unknown")
    check("before the game knows the name, nothing is noted or offered", ns.ImportCandidate() == nil
        and sv.charActive["Unknown-Forever"] == nil)
    ns.MarkSeen()
    check("and no login is noted under it", sv.charSeen == nil)
    ns.MarkAsked()
    check("nor any answer", sv.charAsk == nil)
end

do
    local sv = { profiles = { Default = {} }, charActive = { ["Die Man-Forever"] = "Default" } }
    Login(sv, "Die Dudu")
    Login(sv, "Die Pri")
    Login(sv, "Die Pri").MarkAsked()
    check("two new characters wait on their own: one answered leaves the other", sv.charAsk["Die Dudu-Forever"] == true
        and sv.charAsk["Die Pri-Forever"] == nil and (Login(sv, "Die Dudu").ImportCandidate()) ~= nil)
end

local MAIN_GUID, PRI_GUID, DUDU_GUID = "Player-4613-006EB819", "Player-4613-006EC000", "Player-4613-006ED000"

do
    local sv = { profiles = { Default = {} }, charActive = {} }
    Login(sv, "Die Man", 100, MAIN_GUID).MarkSeen()
    check("each login saves the character's GUID", sv.charGuid["Die Man-Forever"] == MAIN_GUID)
    Login(sv, "Die Pri", 200).MarkSeen()
    check("a GUID the game does not give yet is not saved", sv.charGuid["Die Pri-Forever"] == nil
        and sv.charSeen["Die Pri-Forever"] == 200)
    Login(sv, "Unknown", 300, PRI_GUID).MarkSeen()
    check("nor one before the game knows the name", sv.charGuid["Unknown-Forever"] == nil)
end

local function Account()
    return { profiles = { Default = {}, Raid = {}, Alts = {} }, defaultProfile = "Default",
        charActive = { ["Die Man-Forever"] = "Raid", ["Die Pri-Forever"] = "Alts" },
        charSeen = { ["Die Man-Forever"] = 100, ["Die Pri-Forever"] = 900 },
        charGuid = { ["Die Man-Forever"] = MAIN_GUID, ["Die Pri-Forever"] = PRI_GUID } }
end

do
    local sv = Account()
    local char, profile = Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()
    check("the first character made wins over the one played most recently", char == "Die Man-Forever"
        and profile == "Raid")
end

do
    local sv = Account()
    sv.charGuid["Die Man-Forever"], sv.charGuid["Die Pri-Forever"] = "Player-4613-100", "Player-4613-FF"
    check("the counter is read as a number, not as text", (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate())
        == "Die Pri-Forever")
end

do
    local sv = Account()
    sv.charActive["Far Away-Forever"], sv.charGuid["Far Away-Forever"] = "Default", "Player-4614-00000001"
    sv.charSeen["Far Away-Forever"] = 2000
    check("another server's characters are left out of the first-made rule",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Man-Forever")
    sv = Account()
    sv.charGuid = { ["Far Away-Forever"] = "Player-4614-00000001" }
    sv.charActive["Far Away-Forever"], sv.charSeen["Far Away-Forever"] = "Default", 50
    check("none known on this server: the one played most recently, as before",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Pri-Forever")
end

do
    local sv = Account()
    sv.charGuid = nil
    check("no GUIDs known: the one played most recently",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Pri-Forever")
    sv = Account()
    check("this character's own GUID not known yet: the one played most recently",
        (Login(sv, "Die Dudu", 1000).ImportCandidate()) == "Die Pri-Forever")
end

do
    local sv = Account()
    sv.charGuid["Die Man-Forever"] = "Player-4613-zz"
    sv.charGuid["Die Pri-Forever"] = 42
    sv.charActive["Odd-Forever"], sv.charGuid["Odd-Forever"] = "Default", "Creature-0-4613-0-1-1-0000000001"
    sv.charActive["Odder-Forever"], sv.charGuid["Odder-Forever"] = "Default", "Player-4613-"
    check("malformed GUIDs are left out: the one played most recently",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Pri-Forever")
    sv.charGuid["Die Man-Forever"] = MAIN_GUID
    check("while a sound one still wins", (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate())
        == "Die Man-Forever")
end

do
    local sv = Account()
    sv.charActive["Unknown-Forever"], sv.charGuid["Unknown-Forever"] = "Default", "Player-4613-00000001"
    sv.charSeen["Unknown-Forever"] = 5000
    check("a provisional Unknown- key is never picked by GUID",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Man-Forever")
    sv.charGuid = nil
    check("nor by when it was played", (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Pri-Forever")
    sv = { profiles = { Default = {} }, charActive = { ["Unknown-Forever"] = "Default" },
        charGuid = { ["Unknown-Forever"] = "Player-4613-00000001" } }
    check("an Unknown- key alone: nothing offered", Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate() == nil)
end

do
    local sv = Account()
    sv.charGuid["Die Dudu-Forever"] = "Player-4613-00000001"
    check("never this character itself, even with the lowest counter",
        (Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate()) == "Die Man-Forever")
    sv.charAsk = nil
    check("and only while it waits for an answer", Login(sv, "Die Dudu", 1000, DUDU_GUID).ImportCandidate() == nil)
end

print(("test-import-candidate: %d checks passed"):format(checks))
