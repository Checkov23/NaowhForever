-- Every ns field a module addon reads must be defined by the core, by the module itself or by an
-- addon its TOC lists under Dependencies, so turning any other module off cannot break it. The
-- core and every module may read a field from elsewhere only behind a nil guard (ns.X and,
-- if ns.X then, if not ns.X then return, ns.X ~= nil, type(ns.X), ns.X or, or a local copy of
-- ns.X checked before its first use). A module inside a combined addon may also read what the addons
-- its MODULES entry `needs` define: it loads nothing while one is missing (test-group-inspect-data.lua
-- checks Group Inspect without the BiS List). Quality of Life (NaowhForever_QoL) is optional too: with it
-- off, nothing else may read its fields unguarded or at load, so the base and every module that
-- does not list it load and run without it. Run from the repo root:
--   lua5.1 Tools/regression/test-module-boundaries.lua
local TocFiles = dofile("Tools/regression/toc_files.lua")
local CORE = "NaowhForever"

local ALLOWED = {
    { addon = "NaowhForever_DungeonJournal", field = "OpenBisWindow", file = "NaowhForever_DungeonJournal/View/View.lua",
      reason = "DrawBisNote links to it only after filters.bisOn, Loot.BisOn: the BiS List loaded and on" },
    { addon = "NaowhForever_DungeonJournal", field = "BisListIsEmpty", file = "NaowhForever_DungeonJournal/View/View.lua",
      reason = "DrawBisNote reads it only after filters.bisOn, Loot.BisOn: the BiS List loaded and on" },
    { addon = "NaowhForever_DungeonJournal", field = "OpenBisWindow", file = "NaowhForever_DungeonJournal/View/DungeonHeader.lua",
      reason = "the BiS stat's click runs only when canClick, Loot.BisOn: the BiS List loaded and on" },
    { addon = "NaowhForever_DungeonJournal", field = "AddBisItem", file = "NaowhForever_DungeonJournal/View/ItemMenu.lua",
      reason = "the item menu offers it only when Loot.BisOn: the BiS List loaded and on" },
    { addon = "NaowhForever_DungeonJournal", field = "PromoteBisItem", file = "NaowhForever_DungeonJournal/View/ItemMenu.lua",
      reason = "the item menu offers it only when Loot.BisOn: the BiS List loaded and on" },
    { addon = "NaowhForever_DungeonJournal", field = "RemoveBisItem", file = "NaowhForever_DungeonJournal/View/ItemMenu.lua",
      reason = "the item menu offers it only when Loot.BisOn: the BiS List loaded and on" },
    { addon = "NaowhForever", field = "Macros", file = "Core/Profiles/ProfileShare.lua",
      reason = "AddLibrary runs only behind wanted.library and ns.ModuleOn, the Macros module on" },
    { addon = "NaowhForever", field = "TrainingBuilds", file = "Core/Profiles/ProfileShare.lua",
      reason = "AddBuilds runs only behind ns.Training, which the same addon defines" },
    { addon = "NaowhForever", field = "Training", file = "Core/Profiles/ProfileShare.lua",
      reason = "AddBuilds runs only behind wanted.builds and ns.Training" },
    { addon = "NaowhForever", field = "Training", file = "Core/Profiles/ProfileDialogs.lua",
      reason = "the build hand-off's Add button shows only when ns[needs] (Training) is set" },
    { addon = "NaowhForever", field = "ImportMacroString", file = "Core/Profiles/ProfileDialogs.lua",
      reason = "the macro hand-off's Add button shows only when ns[needs] (ImportMacroString) is set" },
    { addon = "NaowhForever", field = "ImportBisList", file = "Core/Profiles/ProfileDialogs.lua",
      reason = "the BiS hand-off's Add button shows only when ns[needs] (ImportBisList) is set" },
    { addon = "NaowhForever", field = "ImportActionBarString", file = "Core/Profiles/ProfileDialogs.lua",
      reason = "the bar set hand-off's Add button shows only when ns[needs] (ImportActionBarString) is set" },
    { addon = "NaowhForever_BiS", field = "Journal", file = "NaowhForever_BiS/BiS/Quests.lua",
      reason = "Rewards, Choice and Zones run only after Quests.Available() checks ns.Journal" },
    { addon = "NaowhForever_BiS", field = "Journal", file = "NaowhForever_BiS/BiS/View/QuestsPage.lua",
      reason = "the Quests page opens from tabs shown only when Quests.Available(), or from a Journal quest source" },
    { addon = "NaowhForever_BiS", field = "Journal", file = "NaowhForever_BiS/BiS/View/PlaceRow.lua",
      reason = "Levels and the quest count run only for row.dungeon, which JournalDungeon sets only with the Journal" },
    { addon = "NaowhForever_BiS", field = "OpenJournalWindow", file = "NaowhForever_BiS/BiS/View/PlaceRow.lua",
      reason = "Go opens the Journal only for row.dungeon, set only when ns.OpenJournalWindow exists" },
    { addon = "NaowhForever_BiS", field = "OpenJournalWindow", file = "NaowhForever_BiS/BiS/Sources.lua",
      reason = "the dungeon and faction kinds come only from the Journal's drops and factions" },
    { addon = "NaowhForever_Combat", field = "[BUILD[shown]]", file = "NaowhForever_Combat/AuraBuffs/UI/Window.lua",
      reason = "both page builders BUILD names are defined in UI/WindowPages.lua, the same addon" },
    { addon = "NaowhForever_Combat", field = "OpenMacroWindow", file = "NaowhForever_Combat/PvP/UI/AurasPage.lua",
      reason = "the Open Forge button is disabled unless ForgeReady sees the Macros module on (ns.ModuleOn)" },
}

local KNOWN = {}

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return s
end

local function Blank(s)
    return (s:gsub("[^\n]", " "))
end

local function Strip(src)
    local out, n, i, len = {}, 0, 1, #src
    while i <= len do
        local s = src:find("[%-\"'%[]", i)
        if not s then
            n = n + 1; out[n] = src:sub(i)
            break
        end
        n = n + 1; out[n] = src:sub(i, s - 1)
        local c = src:sub(s, s)
        local e
        if c == "-" and src:sub(s + 1, s + 1) == "-" then
            local eqs = src:match("^%[(=*)%[", s + 2)
            if eqs then
                local _, close = src:find("]" .. eqs .. "]", s + 2, true)
                e = close or len
            else
                e = (src:find("\n", s, true) or len + 1) - 1
            end
            n = n + 1; out[n] = Blank(src:sub(s, e))
        elseif c == "[" and src:match("^%[=*%[", s) then
            local eqs = src:match("^%[(=*)%[", s)
            local _, close = src:find("]" .. eqs .. "]", s, true)
            e = close or len
            n = n + 1; out[n] = Blank(src:sub(s, e))
        elseif c == "\"" or c == "'" then
            local j = s + 1
            while true do
                local k = src:find("[\\\n" .. c .. "]", j)
                if not k or src:sub(k, k) ~= "\\" then
                    j = k or len + 1
                    break
                end
                j = k + 2
            end
            local body = src:sub(s + 1, j - 1)
            if not body:find("^[%a_][%w_]*$") then body = Blank(body) end
            n = n + 1; out[n] = c .. body .. c
            e = j
        else
            n = n + 1; out[n] = c
            e = s
        end
        i = e + 1
    end
    local code = table.concat(out)
    code = code:gsub("_G%.NaowhForever%f[^%w_]", "ns")
    code = ("\n" .. code):gsub("([^%w_%.:\"'])NaowhForever%f[^%w_]", "%1ns"):sub(2)
    return code
end

local function TocDeps(addon)
    local toc = addon == CORE and "NaowhForever.toc" or (addon .. "/" .. addon .. ".toc")
    local hard, optional = {}, {}
    for line in io.lines(toc) do
        local key, value = line:gsub("\r$", ""):match("^##%s*([%w%-]+)%s*:%s*(.-)%s*$")
        key = key and key:lower()
        local into = key and ((key == "optionaldeps" and optional)
            or ((key:find("^dep") or key == "requireddeps") and hard))
        if into then
            for name in value:gmatch("[^,%s]+") do into[#into + 1] = name end
        end
    end
    return hard, optional
end

local addons, byName = {}, {}
for _, path in ipairs(TocFiles("%.lua$")) do
    local name = path:match("^(NaowhForever_[%w_]+)/") or CORE
    local a = byName[name]
    if not a then
        a = { name = name, files = {}, defines = {}, reads = {} }
        a.hard, a.optional = TocDeps(name)
        byName[name] = a
        addons[#addons + 1] = a
    end
    a.files[#a.files + 1] = path
end
assert(byName[CORE] and #addons > 1, "no module addons found through .pkgmeta")

local OPENERS = { ["function"] = true, ["if"] = true, ["do"] = true, ["repeat"] = true }
local CLOSERS = { ["end"] = true, ["until"] = true }
local STATEMENT_START = { ["then"] = true, ["do"] = true, ["else"] = true }

local function IsDefinition(before, after, prevWord)
    if after:find("^%s*=[^=]") then return true end
    if prevWord == "function" and before:find("function%s*$") then
        return after:find("^%s*[%(:]") ~= nil
    end
    if not after:find("^%s*,[%w_%.%[%]\"'%s,]-=[^=]") then return false end
    local head = before:gsub("[%w_%.%[%]\"']+%s*,%s*", "")
    if head:find("^%s*$") or head:find(";%s*$") then return true end
    local last = head:match("([%a_]+)%s*$")
    return last ~= nil and STATEMENT_START[last] == true
end

local function IsNilTest(before, after)
    return after:find("^%s*and%f[^%w_]") or after:find("^%s*or%f[^%w_]")
        or after:find("^%s*[~=]=%s*nil%f[^%w_]") or before:find("type%s*%(%s*$")
end

local function AliasChecked(code, before, after, stop)
    if not (after:find("^[ \t]*[\n;]") or after:find("^%s*$") or after:find("^%s*end%f[^%w_]")) then return false end
    local name = before:match("([%a_][%w_]*)%s*=%s*$")
    if not name or before:find("[%.:]%s*" .. name .. "%s*=%s*$") then return false end
    local from = stop
    while true do
        local s, e = code:find("%f[%w_]" .. name .. "%f[^%w_]", from)
        if not s then return false end
        local prev = code:sub(s - 1, s - 1)
        if not prev:find("[%.:\"']") then
            local pre = code:sub(math.max(1, s - 40), s - 1)
            local post = code:sub(e + 1, e + 40)
            if post:find("^%s*[%.:%[%(]") then return false end
            return (IsNilTest(pre, post) or post:find("^%s*then%f[^%w_]")
                or pre:find("%f[%w_]not%s*%(?%s*$")) and true or false
        end
        from = e + 1
    end
end

local function Scan(a, path)
    local code = Strip(Read(path))
    local line, lineStart, cursor = 1, 1, 1
    local depth, guards, lineGuards, returns = 0, {}, {}, {}
    local kinds, inFunction = {}, 0
    local cond, prevWord
    local function Advance(pos)
        while true do
            local nl = code:find("\n", cursor, true)
            if not nl or nl >= pos then break end
            line, lineStart, cursor = line + 1, nl + 1, nl + 1
            lineGuards = {}
        end
        cursor = pos
    end
    local function Nested(pos)
        local text = code:sub(cond.start, pos - 1)
        return select(2, text:gsub("%(", "")) > select(2, text:gsub("%)", ""))
    end
    local function Guarded(field)
        if lineGuards[field] then return true end
        for _, g in ipairs(guards) do
            if g.field == field then return true end
        end
        return false
    end
    local function DropGuards(atLeast, blockOnly)
        for i = #guards, 1, -1 do
            if guards[i].depth >= atLeast and (guards[i].block or not blockOnly) then table.remove(guards, i) end
        end
    end
    local function Record(field, before, after, stop, isRead)
        if not isRead then
            a.defines[field] = a.defines[field] or (path .. ":" .. line)
            return
        end
        local negated = before:find("%f[%w_]not%s*$") ~= nil
        local truthy = cond and after:find("^[%s%)]*then%f[^%w_]") or after:find("^[%s%)]*and%f[^%w_]")
            or after:find("^[%s%)]*or%f[^%w_]")
        local guard = IsNilTest(before, after)
            or (cond and truthy and not before:find("[#%+%-%*/%^%%%.]%s*$"))
            or AliasChecked(code, before, after, stop)
        if cond and not Nested(stop) then
            if negated and (after:find("^%s*then%f[^%w_]") or after:find("^%s*or%f[^%w_]")) then
                cond.negs[#cond.negs + 1] = field
            elseif not negated and (after:find("^%s*then%f[^%w_]") or after:find("^%s*and%f[^%w_]")) then
                cond.fields[#cond.fields + 1] = field
            end
        end
        local safe = guard or Guarded(field)
            or (field:find("^%[") and not after:find("^%s*[%.:%(%[]"))
        if guard then lineGuards[field] = true end
        a.reads[#a.reads + 1] = { field = field, file = path, where = path .. ":" .. line, guarded = safe and true or false,
            atLoad = inFunction == 0 }
    end
    for pos, word in code:gmatch("()([%a_][%w_]*)") do
        local prevChar = pos > 1 and code:sub(pos - 1, pos - 1) or ""
        if not prevChar:find("[%w_%.:\"']") then
            Advance(pos)
            if word == "ns" then
                local rest = code:sub(pos + 2, pos + 200)
                local field, stop = rest:match("^%s*[%.:]%s*([%a_][%w_]*)()")
                if not field then field, stop = rest:match("^%s*%[%s*[\"']([%a_][%w_]*)[\"']%s*%]()") end
                local open = not field and rest:match("^%s*%[()")
                if open then
                    local level, i = 1, open
                    while level > 0 and i <= #rest do
                        local ch = rest:sub(i, i)
                        if ch == "[" then level = level + 1 elseif ch == "]" then level = level - 1 end
                        i = i + 1
                    end
                    if level == 0 then
                        field, stop = "[" .. rest:sub(open, i - 2):gsub("%s+", " ") .. "]", i
                    end
                end
                if field then
                    local before = code:sub(lineStart, pos - 1)
                    local after = rest:sub(stop)
                    Record(field, before, after, pos + 1 + stop, not IsDefinition(before, after, prevWord))
                end
            elseif word == "hooksecurefunc" then
                local field = code:sub(pos, pos + 200):match("^hooksecurefunc%s*%(%s*ns%s*,%s*[\"']([%a_][%w_]*)[\"']")
                if field then Record(field, "", "", pos, true) end
            elseif word == "if" or word == "elseif" then
                if word == "if" then
                    depth = depth + 1
                    kinds[depth] = false
                else
                    DropGuards(depth, true)
                    returns[depth] = nil
                end
                cond = { start = pos, depth = depth, fields = {}, negs = {}, hasOr = false, hasAnd = false, isIf = word == "if" }
            elseif word == "else" then
                DropGuards(depth, true)
                returns[depth] = nil
            elseif word == "or" and cond then
                if not Nested(pos) then cond.hasOr = true end
            elseif word == "and" and cond then
                if not Nested(pos) then cond.hasAnd = true end
            elseif word == "then" and cond then
                if not cond.hasOr then
                    for _, f in ipairs(cond.fields) do
                        guards[#guards + 1] = { field = f, depth = cond.depth, block = true }
                    end
                end
                if cond.isIf and not cond.hasAnd and #cond.negs > 0 then
                    returns[cond.depth] = { fields = cond.negs }
                end
                cond = nil
            elseif word == "return" then
                if returns[depth] then returns[depth].returns = true end
            elseif OPENERS[word] then
                depth = depth + 1
                kinds[depth] = word == "function"
                if kinds[depth] then inFunction = inFunction + 1 end
            elseif CLOSERS[word] then
                local closing = returns[depth]
                returns[depth] = nil
                DropGuards(depth)
                if kinds[depth] then inFunction = inFunction - 1 end
                kinds[depth] = nil
                depth = depth - 1
                if closing and closing.returns then
                    for _, f in ipairs(closing.fields) do
                        guards[#guards + 1] = { field = f, depth = depth }
                    end
                end
            end
            prevWord = word
        end
    end
end

for _, a in ipairs(addons) do
    for _, path in ipairs(a.files) do
        if not path:find("^Libs/") then Scan(a, path) end
    end
end

local function Closure(a)
    local set, queue = { [a.name] = true, [CORE] = true }, { a.name }
    while #queue > 0 do
        local current = byName[table.remove(queue)]
        for _, dep in ipairs(current and current.hard or {}) do
            if not set[dep] then
                set[dep] = true
                queue[#queue + 1] = dep
            end
        end
    end
    return set
end

local MODULES = assert(loadstring("return " .. assert(Read("Core/Options/Modules.lua"):match("\nlocal MODULES = (%b{})\n"),
    "MODULES")))()
local NEEDS = {}
for _, mod in ipairs(MODULES) do
    if mod.host and mod.needs then NEEDS[mod.host .. "/" .. (mod.addon:gsub("^NaowhForever_", "")) .. "/"] = mod.needs end
end

local function NeedsOf(path)
    for folder, needs in pairs(NEEDS) do
        if path:sub(1, #folder) == folder then return needs end
    end
end

local function Lookup(list, addon, field, file)
    for _, entry in ipairs(list) do
        if entry.addon == addon and entry.field == field and entry.file == file then return entry end
    end
end

local function DefinedBy(field)
    local names = {}
    for _, other in ipairs(addons) do
        if other.defines[field] then names[#names + 1] = other.name end
    end
    return #names > 0 and table.concat(names, ", ") or "nobody"
end

for _, list in ipairs({ ALLOWED, KNOWN }) do
    for _, entry in ipairs(list) do
        assert(type(entry.reason) == "string" and entry.reason ~= "",
            "entry for " .. tostring(entry.addon) .. " ns." .. tostring(entry.field) .. " needs a reason")
    end
end

local checked, failures, warnings, used = 0, {}, {}, {}
for _, a in ipairs(addons) do
    local loaded = Closure(a)
    for _, r in ipairs(a.reads) do
        checked = checked + 1
        local ok = r.guarded
        if not ok then
            for name in pairs(loaded) do
                if byName[name] and byName[name].defines[r.field] then ok = true break end
            end
        end
        for _, need in ipairs(not ok and NeedsOf(r.file) or {}) do
            for name in pairs(byName[need] and Closure(byName[need]) or {}) do
                if byName[name].defines[r.field] then ok = true end
            end
        end
        if not ok then
            local line = ("%s reads ns.%s at %s (defined by %s)"):format(a.name, r.field, r.where, DefinedBy(r.field))
            local allowed = Lookup(ALLOWED, a.name, r.field, r.file)
            local known = Lookup(KNOWN, a.name, r.field, r.file)
            if allowed then
                used[allowed] = true
            elseif known then
                used[known] = true
                warnings[#warnings + 1] = line .. ": " .. known.reason
            else
                failures[#failures + 1] = line
            end
        end
    end
end

for _, list in ipairs({ ALLOWED, KNOWN }) do
    for _, entry in ipairs(list) do
        if not used[entry] then
            failures[#failures + 1] = ("stale entry: %s ns.%s in %s needs no exception any more"):format(
                entry.addon, entry.field, entry.file)
        end
    end
end

local QOL = "NaowhForever_QoL"
local qol = byName[QOL]
local qolReads, dependents = 0, {}
if not qol then
    failures[#failures + 1] = QOL .. " is not a module addon in .pkgmeta"
else
    local onlyQoL = {}
    for field in pairs(qol.defines) do
        local elsewhere = false
        for _, other in ipairs(addons) do
            if other ~= qol and other.defines[field] then elsewhere = true end
        end
        if not elsewhere then onlyQoL[field] = true end
    end
    for _, a in ipairs(addons) do
        if a ~= qol and Closure(a)[QOL] then
            dependents[#dependents + 1] = a.name
        elseif a ~= qol then
            for _, r in ipairs(a.reads) do
                if onlyQoL[r.field] then
                    qolReads = qolReads + 1
                    if not r.guarded then
                        failures[#failures + 1] = ("without %s: %s reads ns.%s unguarded at %s"):format(QOL, a.name,
                            r.field, r.where)
                    elseif r.atLoad then
                        failures[#failures + 1] = ("without %s: %s reads ns.%s at load, before QoL loads, at %s"):format(
                            QOL, a.name, r.field, r.where)
                    end
                end
            end
        end
    end
    local hard = table.concat(qol.hard, ",")
    if hard ~= CORE then
        failures[#failures + 1] = QOL .. " must depend on the core alone, not: " .. hard
    end
end

for _, w in ipairs(warnings) do print("WARNING " .. w) end
for _, f in ipairs(failures) do print("FAIL " .. f) end
assert(#failures == 0, #failures .. " ns read(s) cross a module boundary unguarded")
print(("test-module-boundaries: %d addons, %d reads checked, %d known issue(s)"):format(#addons, checked, #warnings))
print(("  without %s: %d guarded read(s) of its fields elsewhere, none at load; needed by %s"):format(QOL,
    qolReads, table.concat(dependents, ", ")))
