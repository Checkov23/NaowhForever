-- Source scan for the taint rules in CONTRIBUTING over every file the TOCs load: game-frame
-- calls (on the frame's name or a local holding it), protected calls with no combat check
-- before them, writes into the game's tables and unguarded aura reads. Reviewed sites are
-- listed below with why they are safe. Source text
-- only, so it does not replace /console taintLog 1 in the game. From the repo root:
--   lua5.1 Tools/regression/test-taint-scan.lua
local TocFiles = dofile("Tools/regression/toc_files.lua")

local LOOKBACK = 40

local FRAME_METHODS = { "SetScript", "Hide", "SetParent", "ClearAllPoints", "SetPoint",
    "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale", "UnregisterAllEvents",
    "UnregisterEvent", "RegisterEvent", "EnableMouse", "SetAttribute", "SetFrameStrata" }

local FRAME_FREE = { ["GameTooltip:Hide"] = true }

local FRAME_ALLOWED = {
    ["NaowhForever_BiS/CharacterPanel/Chrome.lua"] = {
        why = "the level line, not protected, put on the badge row while the panel is on and back on the game's strip when off",
        calls = { ["PaperDollLevelInfo:ClearAllPoints"] = 1, ["PaperDollLevelInfo:SetPoint"] = 2 } },
    ["NaowhForever_QoL/TopBar/UI/Tooltips.lua"] = { why = "the bar's own tooltip size, put back on hide",
        calls = { ["GameTooltip:SetScale"] = 1 } },
    ["NaowhForever_QoL/TopBar/UI/Widgets.lua"] = {
        why = "the top-centre scores (no secure frames, only GhostFrame hangs from them) moved below the bar, put back when it goes",
        calls = { ["UIWidgetTopCenterContainerFrame:ClearAllPoints"] = 1, ["UIWidgetTopCenterContainerFrame:SetPoint"] = 1 } },
    ["NaowhForever_BiS/CharacterPanel/Badge.lua"] = { why = "places the tooltip it owns",
        calls = { ["GameTooltip:ClearAllPoints"] = 1, ["GameTooltip:SetPoint"] = 1 } },
    ["NaowhForever_QoL/Travel/Flight.lua"] = { why = "faded leave button, out of combat only",
        calls = { ["MainMenuBarVehicleLeaveButton:EnableMouse"] = 1 } },
    ["NaowhForever_QoL/Interface/HideClutter.lua"] = { why = "the same switch as /uierrorsoff; screenshot text",
        calls = { ["UIErrorsFrame:UnregisterEvent"] = 1, ["UIErrorsFrame:RegisterEvent"] = 1,
            ["ActionStatus:UnregisterEvent"] = 2, ["ActionStatus:RegisterEvent"] = 2 } },
    ["NaowhForever_QoL/Interface/MapSize.lua"] = { why = "windowed world map (no secure frames) scaled and moved, put back where the game had it",
        calls = { ["WorldMapFrame:SetScale"] = 1, ["WorldMapFrame:ClearAllPoints"] = 3,
            ["WorldMapFrame:SetPoint"] = 3 } },
    ["NaowhForever_QoL/Loot/LootFeed.lua"] = { why = "loot window shrunk and restored, never hidden",
        calls = { ["LootFrame:SetScale"] = 2 } },
    ["NaowhForever_Professions/UI/Takeover.lua"] = {
        why = "pinned under ours out of combat; its overview tab docked beside ours, its points put back",
        calls = { ["ProfessionsFrame:ClearAllPoints"] = 1, ["ProfessionsFrame:SetPoint"] = 1,
            ["ProfessionsFrame.ProfessionsOverviewTab:ClearAllPoints"] = 2,
            ["ProfessionsFrame.ProfessionsOverviewTab:SetPoint"] = 2 } },
    ["NaowhForever_BiS/InspectPanel/InspectPanel.lua"] = {
        why = "the inspect window (no secure frames) a pane wider, its tabs' frames and inset kept left; put back off",
        calls = { ["InspectFrame:SetWidth"] = 1, ["InspectFrame.Inset:SetPoint"] = 1,
            ["_G[...]:ClearAllPoints"] = 1, ["_G[...]:SetPoint"] = 2, ["_G[...]:SetAllPoints"] = 1 } },
    ["NaowhForever_BiS/CharacterPanel/SpecStats.lua"] = { why = "the stats list moved under your score; put back off",
        calls = { ["CharacterStatsPaneScrollBox:ClearAllPoints"] = 1, ["CharacterStatsPaneScrollBox:SetPoint"] = 2 } },
    ["Shared/Game/Played.lua"] = { why = "the chat frames' /played line muted while ours asks, registered again after",
        calls = { ["_G[...]:UnregisterEvent"] = 1 } },
}

local PROTECTED = { "PickupAction", "PlaceAction", "SetBinding", "CreateMacro", "EditMacro",
    "DeleteMacro", "PickupMacro", "C_PartyInfo.UninviteUnit", "C_PartyInfo.PromoteToLeader",
    "C_PartyInfo.ConvertToRaid", "C_PartyInfo.DoReadyCheck", "DeleteCursorItem",
    "C_Container.UseContainerItem", "C_Container.PickupContainerItem", "C_Item.EquipItemByName",
    "C_EquipmentSet.UseEquipmentSet", "C_Item.DeleteItem", "TargetUnit", "FocusUnit",
    "CastSpellByName", "CastSpellByID", "UseAction", "RunMacroText", "SetOverrideBinding",
    "C_Spell.PickupSpell", "C_Item.ReplaceEnchant", "HideUIPanel", "ShowUIPanel" }

local UNGUARDED_ALLOWED = {
    ["NaowhForever_QoL/Loot/BagSpace.lua"] = { why = "straight from a click on its own row or key",
        calls = { ["C_Container.PickupContainerItem"] = 1, DeleteCursorItem = 1 } },
    ["NaowhForever_QoL/Loot/Mail.lua"] = { why = "attachments from a click at the open mailbox",
        calls = { ["C_Container.PickupContainerItem"] = 1 } },
    ["NaowhForever_QoL/Loot/ScrapMarker.lua"] = { why = "CanSell checks the merchant and combat each item",
        calls = { ["C_Container.UseContainerItem"] = 1 } },
    ["NaowhForever_Utilities/ActionBars/Import.lua"] = {
        why = "Run is reached only through Sets.lua's Ready(), which refuses in combat (imports and putting a backup back), or as a test that changes nothing",
        calls = { CreateMacro = 1, SetBinding = 3, ["C_Spell.PickupSpell"] = 3, PickupMacro = 1,
            PickupAction = 2, PlaceAction = 1 } },
    ["NaowhForever_Utilities/ActionBars/Pending.lua"] = {
        why = "FillPending runs from SpellsReady, which waits for PLAYER_REGEN_ENABLED in combat",
        calls = { PickupAction = 1, PlaceAction = 1 } },
    ["NaowhForever_Utilities/Macros/Smart.lua"] = { why = "Update() and the Pickup entry points refuse in combat",
        calls = { EditMacro = 1, CreateMacro = 1 } },
    ["Core/Options/GameMenu.lua"] = { why = "our game menu button's own click",
        calls = { HideUIPanel = 1 } },
    ["NaowhForever_Professions/UI/Window.lua"] = { why = "the close button's click",
        calls = { HideUIPanel = 1 } },
}

local GAME_TABLES = { "hash_SlashCmdList", "hash_EmoteTokenList", "hash_ChatTypeInfoList",
    "UIPanelWindows", "UISpecialFrames" }

local TABLE_WRITE_ALLOWED = {}

local function ReadGlobals()
    local f = assert(io.open(".luacheckrc", "rb"))
    local text = f:read("*a")
    f:close()
    local block = assert(text:match("read_globals%s*=%s*(%b{})"), "read_globals not found in .luacheckrc")
    local names = {}
    for name in block:gmatch('"([%w_]+)"') do names[name] = true end
    return names
end

local BLIZZARD = ReadGlobals()
assert(BLIZZARD.UIParent and BLIZZARD.GameTooltip, "read_globals has no game frames")

local function Lines(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", function(c) return (c:gsub("[^\n]", "")) end)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        if line:match("^%s*%-%-") then line = "" end
        lines[#lines + 1] = line
    end
    return lines
end

local function Escape(s) return (s:gsub("[%.%[%]%(%)%*%+%-%?%^%$%%]", "%%%1")) end

local problems = {}
local function Problem(fmt, ...) problems[#problems + 1] = fmt:format(...) end

local function Bump(counts, key) counts[key] = (counts[key] or 0) + 1 end

local function CheckCounts(path, counts, allowed, what)
    allowed = allowed and allowed.calls or {}
    for key, n in pairs(counts) do
        if n ~= (allowed[key] or 0) then
            Problem("%s: %d %s %s, %d reviewed", path, n, what, key, allowed[key] or 0)
        end
    end
    for key, n in pairs(allowed) do
        if not counts[key] then Problem("%s: reviewed %s %s (%d) is gone; update the list", path, what, key, n) end
    end
end

local function FrameCalls(line, counts, aliases)
    for receiver, method in line:gmatch("([%w_%.]+):([%w_]+)%(") do
        local root = receiver:match("^_G%.([%w_]+)$") or receiver:match("^([%w_]+)$")
        local name = root and (BLIZZARD[root] and root or aliases[root])
        if name and not FRAME_FREE[name .. ":" .. method] then
            for _, m in ipairs(FRAME_METHODS) do
                if m == method then Bump(counts, name .. ":" .. method) end
            end
        end
    end
end

-- Locals that hold one of the game's frames (local frame = InspectFrame, local inset =
-- InspectFrame.Inset, local sub = _G[name]), until the name is declared again or a function starts.
local function Aliases(line, aliases)
    if line:find("^%s*local%s+function%f[%W]") or line:find("^%s*function%f[%W]") then
        for k in pairs(aliases) do aliases[k] = nil end
    end
    for name, value in line:gmatch("local%s+([%w_]+)[%w_,%s]*=%s*([^\n]+)") do
        local path = value:match("^_G%.([%w_%.]+)") or value:match("^([%w_%.]+)")
        local root = path and path:match("^[%w_]+")
        if value:find("^_G%[") then
            aliases[name] = "_G[...]"
        elseif root and BLIZZARD[root] and not value:find("^[%w_%.]+%s*[%(:]") then
            aliases[name] = path
        else
            aliases[name] = nil
        end
    end
end

local function ProtectedCalls(lines, i, counts)
    local line = lines[i]
    for _, call in ipairs(PROTECTED) do
        if line:find("%f[%w_%.]" .. Escape(call) .. "%s*%(") and not line:find("function%s+[%w_%.:]*" .. Escape(call)) then
            local guarded = false
            for j = math.max(1, i - LOOKBACK), i do
                if lines[j]:find("InCombatLockdown", 1, true) then
                    guarded = true
                    break
                end
            end
            if not guarded then Bump(counts, call) end
        end
    end
end

local function TableWrites(path, i, line, counts)
    for key, field in line:gmatch("StaticPopupDialogs%[([^%]]+)%]%.([%w_]+)%s*=[^=]") do
        if not key:find("^[\"']NAOWHFOREVER_") then
            Problem("%s:%d: writes %s into the game's StaticPopupDialogs[%s]", path, i, field, key)
        end
    end
    for _, name in ipairs(GAME_TABLES) do
        if line:find("%f[%w_]" .. name .. "%s*%[[^%]]+%]%s*=[^=]") or line:find("tinsert%(%s*" .. name)
            or line:find("table%.insert%(%s*" .. name) then
            Bump(counts, name)
        end
    end
    for name in line:gmatch("_G%.([%w_]+)%s*=[^=]") do
        if BLIZZARD[name] then Problem("%s:%d: replaces the game's global %s", path, i, name) end
    end
    for name in line:gmatch("_G%[\"([%w_]+)\"%]%s*=[^=]") do
        if BLIZZARD[name] then Problem("%s:%d: replaces the game's global %s", path, i, name) end
    end
end

local scanned, auraFiles = 0, 0
for _, path in ipairs(TocFiles("%.lua$")) do
    if not path:find("^Libs/") and not path:find("/Libs/") then
        scanned = scanned + 1
        local lines = Lines(path)
        local frameCounts, unguarded, writes, aliases = {}, {}, {}, {}
        local auraRead, secretGuard = false, false
        for i, line in ipairs(lines) do
            Aliases(line, aliases)
            FrameCalls(line, frameCounts, aliases)
            ProtectedCalls(lines, i, unguarded)
            TableWrites(path, i, line, writes)
            if line:find("C_UnitAuras%.Get") or line:find("GetAuraData") or line:find("AuraUtil%.ForEachAura") then
                auraRead = true
            end
            if line:find("ShouldAurasBeSecret", 1, true) or line:find("issecretvalue", 1, true) then
                secretGuard = true
            end
        end
        CheckCounts(path, frameCounts, FRAME_ALLOWED[path], "call(s) on a game frame:")
        CheckCounts(path, unguarded, UNGUARDED_ALLOWED[path], "protected call(s) with no combat check before:")
        CheckCounts(path, writes, TABLE_WRITE_ALLOWED[path], "write(s) into the game's table")
        if auraRead then
            auraFiles = auraFiles + 1
            if not secretGuard then Problem("%s: reads auras with no ShouldAurasBeSecret or issecretvalue guard", path) end
        end
    end
end

for _, list in ipairs({ FRAME_ALLOWED, UNGUARDED_ALLOWED, TABLE_WRITE_ALLOWED }) do
    for path, entry in pairs(list) do
        if type(entry.why) ~= "string" or entry.why == "" then Problem("%s: reviewed entry has no reason", path) end
    end
end

for _, p in ipairs(problems) do print("FAIL " .. p) end
assert(scanned > 100, "too few files scanned: " .. scanned)
assert(auraFiles > 0, "no aura reads found: the scan is not reading the modules")
assert(#problems == 0, #problems .. " taint rule problem(s)")
print(("PASS %d files: no new game-frame calls, unguarded protected calls or game-table writes"):format(scanned))
