-- Run with Lua 5.1 from the repository root: text from other players and shared strings is shown
-- as plain text. ns.PlainText (Core) on crafted names, and a crafted old Reminder Pack string
-- (Core/Profiles/ProfileShare.lua, through the real LibSerialize and LibDeflate).
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")

local PlainText = dofile("Tools/regression/plain_text.lua")()

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local BADGE = "|TInterface\\AddOns\\NaowhForever\\Core\\Badges\\Media\\BadgeNaowhChat.tga:0:0:0:-1|t"

local function Live(text)
    return (text:gsub("||", "")):find("|", 1, true) ~= nil or text:find("%c") ~= nil
end

Case("escapes in a name are shown, never drawn", function()
    for _, raw in ipairs({ BADGE .. " Naowh", "|cffe6cc80Naowh Forever:|r hi", "|Hitem:19019|h[Thunderfury]|h",
        "|Kq1|k", "|A:raidicon:16:16|a", "a|nb", "line\nbreak", "tab\there", "end|", "|", "x\0y" }) do
        local out = PlainText(raw)
        assert(not Live(out), out)
    end
    assert(PlainText(BADGE):find("||T", 1, true) == 1, "the texture code reads as text")
end)

Case("plain names, format codes and escaped pipes are left as they are", function()
    for _, raw in ipairs({ "Die Man", "Naowh's Pack (2026)", "%s%d%n%%", "a||b", "" }) do
        assert(PlainText(raw) == raw, raw)
    end
    assert(PlainText(PlainText(BADGE)) == PlainText(BADGE), "cleaning twice changes nothing more")
    assert(("Imported %s."):format(PlainText("%s%d")) == "Imported %s%d.", "a name with %s is an argument")
end)

Case("anything but a string is nil, and a cap cuts", function()
    assert(PlainText(nil) == nil and PlainText(42) == nil and PlainText({}) == nil)
    assert(#PlainText(("x"):rep(500), 100) == 100)
end)

Case("4000 letters of color codes clean quickly", function()
    local long = ("|cffff0000x|r"):rep(400)
    assert(#long >= 4000)
    local started = os.clock()
    local out
    for _ = 1, 200 do out = PlainText(long) end
    assert(not Live(out) and os.clock() - started < 1, "slow: " .. (os.clock() - started))
end)

local function Profiles()
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, PlainText = PlainText }
    local env = setmetatable({ _G = { NaowhForever = ns }, LibStub = LibStub }, { __index = _G })
    ns.Shared = { Decode = dofile("Tools/regression/load_decode.lua")(env) }
    local chunk = assert(loadfile("Core/Profiles/ProfileShare.lua")); setfenv(chunk, env); chunk()
    return ns
end

local function PackString(payload)
    local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")
    return "NSRPACK2:" .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(payload)))
end

Case("a crafted old pack's name, author and profile names are never shown", function()
    local ns = Profiles()
    local fake = "|cffff0000Naowh|r " .. BADGE
    for _, payload in ipairs({
        { format = 1, name = BADGE .. " |cffe6cc80Official Naowh Pack|r",
          author = "Naowh " .. BADGE .. "\nVerified by the Naowh Forever team", made = "%s%d%n",
          data = { callouts = { a = "Taunt" } } },
        { format = 1, name = "Pack", author = "Me", profiles = { [fake] = { callouts = { a = "Taunt" } } } },
    }) do
        local decoded, why = ns.DecodeProfile(PackString(payload))
        assert(decoded == nil and why == "Reminder Packs are no longer supported.", tostring(why))
        assert(not Live(why), why)
    end
end)

Case("ns.Print starts every line with the Naowh logo, which chat from players cannot carry", function()
    local f = assert(io.open("Core/Core.lua", "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
    local said = {}
    local frame = setmetatable({}, { __index = function() return function() end end })
    local env = { CreateFrame = function() return frame end, print = function(text) said[#said + 1] = text end,
        NaowhForeverDB = { account = {}, profiles = {}, charActive = {} } }
    env._G = env
    setmetatable(env, { __index = _G })
    local chunk = assert(loadstring(source, "Core")); setfenv(chunk, env); chunk("NaowhForever")
    env.NaowhForever.Print("%s hi")
    local line = said[#said]
    assert(line:find("|TInterface\\AddOns\\NaowhForever\\Core\\Media\\LogoAddon.tga:0:0:0:", 1, true) == 1, line)
    assert(line:find("|t |cff0091edNaowh|r Forever: %s hi", 1, true), line)
end)

Case("no chat line with a Naowh prefix is printed outside ns.Print", function()
    local TocFiles = dofile("Tools/regression/toc_files.lua")
    local found = {}
    for _, path in ipairs(TocFiles("%.lua$")) do
        local f = io.open(path, "rb")
        if f then
            local n = 0
            for line in f:read("*a"):gsub("\r\n", "\n"):gmatch("([^\n]*)\n") do
                n = n + 1
                local code = line:gsub("%-%-.*$", "")
                local bare = code:find("[^%w_%.:]print%s*%(") or code:find("^print%s*%(")
                    or code:find("AddMessage%s*%(")
                if bare and code:find("Naowh", 1, true) and not code:find("ns.PRINT_LOGO", 1, true) then
                    found[#found + 1] = path .. ":" .. n
                end
            end
            f:close()
        end
    end
    assert(#found == 0, "prints a Naowh line by hand: " .. table.concat(found, ", "))
end)

local function Senders(world)
    local function Member(unit)
        if unit == "player" then return world.me end
        return world.party[tonumber(unit:match("^party(%d+)$") or unit:match("^raid(%d+)$") or 0)]
    end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
    local env = setmetatable({ _G = { NaowhForever = ns },
        IsInRaid = function() return world.raid end,
        GetNumGroupMembers = function() return #world.party end,
        GetNumSubgroupMembers = function() return #world.party end,
        UnitGUID = function(unit) local m = Member(unit) return m and m.guid end,
        UnitFullName = function(unit) local m = Member(unit) if m then return m.first, m.second end end,
        GetNormalizedRealmName = function() return "Forever" end,
        GetNumGuildMembers = function() return #world.guild end,
        GetGuildRosterInfo = function(i)
            local m = world.guild[i]
            if m then return m[1], nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, m[2] end
        end,
        C_FriendList = { GetFriendInfo = function(name) return world.friends[name] end },
        CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        issecretvalue = function(v) return v ~= nil and v == world.secret end,
    }, { __index = _G })
    local chunk = assert(loadfile("Core/Senders.lua")); setfenv(chunk, env); chunk()
    return ns
end

Case("a GUID is taken only from the group member it belongs to, in every name format", function()
    local world = { me = { guid = "Player-1-0001", first = "Die", second = "Man" }, guild = {}, friends = {},
        party = { { guid = "Player-1-00A1", first = "Emmy", second = "Stone" },
            { guid = "Player-1-00A2", first = "Bob" }, { guid = "Player-1-00A3", first = "Bob", second = "Forever" } } }
    local ns = Senders(world)
    for _, name in ipairs({ "Emmy Stone", "Emmy-Stone", "Emmy Stone-Forever", "Emmy-Stone-Forever" }) do
        assert(ns.SenderIs(name, "PARTY", "Player-1-00A1"), name)
    end
    assert(ns.SenderIs("Bob", "PARTY", "Player-1-00A2") and ns.SenderIs("Bob-Forever", "RAID", "Player-1-00A2"))
    assert(ns.SenderIs("Bob", "INSTANCE_CHAT", "Player-1-00A3"), "a realm in the surname's place")
    for _, name in ipairs({ "Bob", "Emmy", "Emmy Stones", "Emmy Stone-Elsewhere", "Emmy%Stone", "Stone Emmy" }) do
        assert(not ns.SenderIs(name, "PARTY", "Player-1-00A1"), name)
    end
    assert(not ns.SenderIs("Emmy Stone", "PARTY", "Player-1-00FF"), "a GUID outside the group")
    assert(not ns.SenderIs("Emmy Stone", "SAY", "Player-1-00A1"), "a channel addon messages do not use")
    world.raid = true
    assert(ns.SenderIs("Emmy Stone", "RAID", "Player-1-00A1"), "the raid's units in a raid")
    world.secret = "Player-1-00A1"
    assert(not ns.SenderIs("Emmy Stone", "RAID", "Player-1-00A1"), "a secret GUID matches nothing")
end)

Case("a guildmate is matched through the guild roster, a friend through the friends list", function()
    local world = { me = { guid = "Player-1-0001", first = "Die", second = "Man" }, party = {},
        guild = { { "Die-Dudu", "Player-1-00B1" }, { "Die-Pri", "Player-1-00B2" } },
        friends = { ["Pen-Pal"] = { guid = "Player-1-00C1" } } }
    local ns = Senders(world)
    assert(ns.SenderIs("Die-Dudu", "GUILD", "Player-1-00B1") and ns.SenderIs("Die-Dudu-Forever", "GUILD", "Player-1-00B1"))
    assert(not ns.SenderIs("Die-Dudu", "GUILD", "Player-1-00B2"), "another guildmate's GUID")
    assert(ns.SenderIs("Die Dudu", "GUILD", "Player-1-00B1"), "a space where the roster has a dash")
    world.guild[4] = { "Mugha Bee", "Player-1-00B4" }
    ns._SendersTest.GuildChanged()
    assert(ns.SenderIs("Mugha-Bee", "GUILD", "Player-1-00B4"), "a dash where the roster has a space")
    assert(not ns.SenderIs("Out-Sider", "GUILD", "Player-1-00B9"), "a sender outside the guild")
    assert(ns.SenderIs("Pen-Pal", "WHISPER", "Player-1-00C1"), "a friend's whisper")
    assert(not ns.SenderIs("Pen-Pal", "WHISPER", "Player-1-00B1"), "a friend claiming someone else")
    assert(not ns.SenderIs("Stranger", "WHISPER", "Player-1-00D1"), "a whisper nobody can place")
    world.guild[3] = { "New-Member", "Player-1-00B3" }
    assert(not ns.SenderIs("New-Member", "GUILD", "Player-1-00B3"), "the roster is read once until it changes")
    ns._SendersTest.GuildChanged()
    assert(ns.SenderIs("New-Member", "GUILD", "Player-1-00B3"), "and again after GUILD_ROSTER_UPDATE")
end)

Case("matching a sender makes no garbage", function()
    local world = { me = { guid = "Player-1-0001", first = "Die", second = "Man" }, friends = {},
        party = { { guid = "Player-1-00A1", first = "Emmy", second = "Stone" } },
        guild = { { "Die-Dudu", "Player-1-00B1" } } }
    local ns = Senders(world)
    ns.SenderIs("Die-Dudu", "GUILD", "Player-1-00B1")
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 1000 do
        ns.SenderIs("Emmy-Stone", "PARTY", "Player-1-00A1")
        ns.SenderIs("Die-Dudu", "GUILD", "Player-1-00B1")
    end
    local grown = collectgarbage("count") - before
    collectgarbage("restart")
    assert(grown < 1, ("%.2f KB for 2000 matches"):format(grown))
end)

print(count .. " untrusted text regressions passed")
