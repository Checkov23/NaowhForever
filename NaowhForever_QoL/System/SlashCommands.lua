-- SlashCommands.lua: the QoL custom slash commands that open a game window or run another command.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI
local T = ns.THEME

local DEFAULTS = {
    { name = "cdm", frame = "CooldownViewerSettings", enabled = true },
    { name = "em", frame = "EditModeManagerFrame", enabled = true },
    { name = "kb", frame = "QuickKeybindFrame", enabled = true },
}

local FRAMES = {
    { "Achievements", "AchievementFrame", "Blizzard_AchievementUI" },
    { ns.L("Addon List"), "AddonList" },
    { "Auction House", "AuctionHouseFrame", "Blizzard_AuctionHouseUI" },
    { "Calendar", "CalendarFrame", "Blizzard_Calendar" },
    { "Channels", "ChannelFrame", "Blizzard_Channels" },
    { ns.L("Chat Config"), "ChatConfigFrame" },
    { ns.L("Click Binding"), "ClickBindingFrame", "Blizzard_ClickBindingUI" },
    { "Collections", "CollectionsJournal", "Blizzard_Collections" },
    { "Communities", "CommunitiesFrame", "Blizzard_Communities" },
    { ns.L("Cooldown Viewer"), "CooldownViewerSettings", "Blizzard_CooldownViewer" },
    { ns.L("Death Recap"), "DeathRecapFrame", "Blizzard_DeathRecap" },
    { ns.L("Dress Up"), "DressUpFrame" },
    { "Dungeon Journal", "EncounterJournal", "Blizzard_EncounterJournal" },
    { ns.L("Edit Mode"), "EditModeManagerFrame", "Blizzard_EditMode" },
    { ns.L("Game Menu"), "GameMenuFrame" },
    { "Group Finder", "PVEFrame" },
    { ns.L("Guild Bank"), "GuildBankFrame", "Blizzard_GuildBankUI" },
    { "Help", "HelpFrame", "Blizzard_HelpFrame" },
    { ns.L("Loot History"), "GroupLootHistoryFrame", "Blizzard_GroupLootHistoryFrame" },
    { "Macros", "MacroFrame", "Blizzard_MacroUI" },
    { ns.L("Pet Stable"), "StableFrame", "Blizzard_StableUI" },
    { ns.L("Quick Keybind"), "QuickKeybindFrame", "Blizzard_QuickKeybind" },
    { ns.L("Raid Manager"), "CompactRaidFrameManager", "Blizzard_CompactRaidFrames" },
    { "Settings", "SettingsPanel" },
    { "Spellbook / Talents", "PlayerSpellsFrame", "Blizzard_PlayerSpells" },
    { "Stopwatch", "StopwatchFrame" },
    { ns.L("Time Manager"), "TimeManagerFrame", "Blizzard_TimeManager" },
    { ns.L("World Map"), "WorldMapFrame", "Blizzard_WorldMap" },
}

local ACTION_VALUES = { frame = "Open a Window", command = "Run a Command" }
local ACTION_ORDER = { "frame", "command" }
local SLASH_PREFIX = "NAOWHFOREVER_"
local HEAD_SIZE, LABEL_SIZE, NAME_SIZE = 14, 12, 13
local HEAD_TOP, LABEL_GAP, FIELD_GAP = 16, 12, 4
local ADD_W, ADD_H, ADD_PAD = 380, 290, 20
local FIELD_W, FIELD_H, NAME_MAX = 340, 26, 24
local SAVE_W, SAVE_H, SAVE_X, SAVE_Y = 110, 26, 60, 16
local EDITOR_W, EDITOR_PAD, EDITOR_TOP, EDITOR_ROW, EDITOR_FOOT = 460, 20, 52, 30, 62
local EDITOR_NAME_W, EDITOR_GAP, EDITOR_REMOVE_W, EDITOR_BUTTON_H = 90, 10, 76, 22
local FOOT_BUTTON_W, FOOT_RESTORE_W, FOOT_BUTTON_H, FOOT_Y = 100, 150, 26, 16

local TEXT_SECURE = ns.L(" can't be run from a custom command. Put it in a macro instead.")
local TEXT_UNKNOWN = ns.L(" isn't a command this can run.")
local TEXT_NO_RELOAD = ns.L("A custom command can't reload. Type /reload.")
local TEXT_COMBAT = ns.L("Windows cannot be opened or closed by a command in combat.")
local TEXT_GAMEPAD = ns.L("Windows cannot be opened or closed by a command with a gamepad.")
local TEXT_TAKEN = ns.L(" already belongs to another addon, so it was skipped.")
local TEXT_RUNS, TEXT_OPENS, TEXT_MISSING = ns.L("runs "), ns.L("opens "), ns.L(" (not in this game)")
local TEXT_ADD_TITLE = ns.L("Add Slash Command")
local TEXT_NAME_LABEL = ns.L("Command name, such as r for /r")
local TEXT_ACTION_LABEL = ns.L("It should")
local TEXT_WINDOW = ns.L("Window")
local TEXT_COMMAND_LABEL = ns.L("Command to run, such as /dance. What you type after your command is added to it.")
local TEXT_BAD_NAME = ns.L("A command name can only use letters, numbers and underscores.")
local TEXT_PICK_WINDOW = ns.L("Pick a window to open.")
local TEXT_TYPE_COMMAND = ns.L("Type a command to run.")
local TEXT_ALREADY = ns.L(" is already one of your commands.")
local TEXT_SAVE, TEXT_CANCEL = ns.L("Save"), ns.L("Cancel")
local TEXT_EDITOR_TITLE = ns.L("Custom Slash Commands")
local TEXT_NONE = ns.L("No commands yet. Add one, or restore the defaults.")
local TEXT_REMOVE, TEXT_ADD, TEXT_RESTORE, TEXT_CLOSE = ns.L("Remove"), ns.L("Add"), ns.L("Restore Defaults"), ns.L("Close")
local TEXT_RESTORE_ASK = ns.L("Replace your commands with the defaults?")
local TEXT_SUMMARY = ns.L("%d %s, %d on")
local TEXT_ONE, TEXT_MANY = ns.L("command"), ns.L("commands")

local ADDON_FOR, FRAME_NAME = {}, {}
for _, f in ipairs(FRAMES) do
    ADDON_FOR[f[2]] = f[3]
    FRAME_NAME[f[2]] = f[1]
end

local registered = {}

local function On()
    return S.Get("enabled") and S.Get("slashCommands")
end

local function Available(frame)
    if _G[frame] then return true end
    local addon = ADDON_FOR[frame]
    return addon ~= nil and C_AddOns.DoesAddOnExist(addon)
end

function ns.SlashCommandList()
    local db = S.DB()
    if type(db.slashList) ~= "table" then
        db.slashList = {}
        for i, cmd in ipairs(DEFAULTS) do db.slashList[i] = CopyTable(cmd) end
    end
    return db.slashList
end

local function SlashID(name)
    return SLASH_PREFIX .. strupper(name)
end

local function FindInList(list, command)
    if type(list) ~= "table" then return end
    for key, handler in pairs(list) do
        local i = 1
        local alias = _G["SLASH_" .. key .. i]
        while alias do
            if strupper(alias) == command then return handler end
            i = i + 1
            alias = _G["SLASH_" .. key .. i]
        end
    end
end

local function FindHandler(command)
    local handler = hash_SlashCmdList[command] or FindInList(SlashCmdList, command)
    if handler then return handler end
    local meta = getmetatable(SlashCmdList)
    return meta and FindInList(meta.__index, command)
end

local function RunEmote(name, key, msg)
    local emote = hash_EmoteTokenList[key]
    if emote then
        C_ChatInfo.PerformEmote(emote, msg)
    else
        ns.Print(name .. TEXT_UNKNOWN)
    end
end

local function RunCommand(command, args)
    if not command:match("^/") then command = "/" .. command end
    if args and args ~= "" then command = command .. " " .. args end
    local name = command:match("^/%S+")
    if not name then return end
    local key = strupper(name)
    if IsSecureCmd(key) then
        ns.Print(name .. TEXT_SECURE)
        return
    end
    local msg = strtrim(command:sub(#name + 1))
    local handler = FindHandler(key)
    if not handler then return RunEmote(name, key, msg) end
    if handler == SlashCmdList.RELOAD then
        ns.Print(TEXT_NO_RELOAD)
        return
    end
    handler(msg, nil)
end

local function ToggleFrame(name)
    if InCombatLockdown() then
        ns.Print(TEXT_COMBAT)
        return
    end
    if ns.GamepadOwnsPanels() then
        ns.Print(TEXT_GAMEPAD)
        return
    end
    local addon = ADDON_FOR[name]
    if addon and not C_AddOns.IsAddOnLoaded(addon) then C_AddOns.LoadAddOn(addon) end
    local frame = _G[name]
    if type(frame) == "table" and frame.IsShown then frame:SetShown(not frame:IsShown()) end
end

local function Register(cmd)
    local name = strlower(cmd.name)
    local id = SlashID(name)
    local existing = _G["SLASH_" .. strupper(name) .. "1"]
    if existing and existing ~= _G["SLASH_" .. id .. "1"] then
        ns.Print("/" .. name .. TEXT_TAKEN)
        return
    end
    _G["SLASH_" .. id .. "1"] = "/" .. name
    SlashCmdList[id] = function(msg)
        if cmd.command then RunCommand(cmd.command, msg) else ToggleFrame(cmd.frame) end
    end
    registered[name] = id
end

function ns.RefreshSlashCommands()
    for name, id in pairs(registered) do
        _G["SLASH_" .. id .. "1"] = nil
        SlashCmdList[id] = nil
        hash_SlashCmdList["/" .. strupper(name)] = nil
        registered[name] = nil
    end
    if not On() then return end
    for _, cmd in ipairs(ns.SlashCommandList()) do
        if cmd.enabled and (cmd.command or Available(cmd.frame)) then Register(cmd) end
    end
end

function ns.SlashCommandSummary(cmd)
    if cmd.command then return TEXT_RUNS .. cmd.command end
    local label = FRAME_NAME[cmd.frame] or cmd.frame
    if not Available(cmd.frame) then return TEXT_OPENS .. label .. TEXT_MISSING end
    return TEXT_OPENS .. label
end

function ns.RemoveSlashCommand(name)
    name = strlower((strtrim(name):gsub("^/", "")))
    local list = ns.SlashCommandList()
    for i = #list, 1, -1 do
        if strlower(list[i].name) == name then
            table.remove(list, i)
            ns.RefreshSlashCommands()
            return true
        end
    end
    return false
end

function ns.RestoreSlashCommands()
    S.DB().slashList = nil
    ns.RefreshSlashCommands()
end

local function Label(panel, key, text, anchor)
    local fs = UI.KeepFont(panel, key, LABEL_SIZE, nil, T.muted)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -LABEL_GAP)
    fs:SetWidth(FIELD_W)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

function ns.ShowAddSlashCommand(onAdded)
    local dimmer, panel = ns.MakeModal(ADD_W, ADD_H, "addSlashCommand")
    local head = UI.KeepFont(panel, "head", HEAD_SIZE, "OUTLINE")
    head:SetPoint("TOPLEFT", ADD_PAD, -HEAD_TOP)
    head:SetText(TEXT_ADD_TITLE)

    local nameLabel = Label(panel, "nameLabel", TEXT_NAME_LABEL, head)
    local nameBox = UI.Keep(panel, "nameBox", ns.NewEditBox)
    nameBox:SetSize(FIELD_W, FIELD_H)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -FIELD_GAP)
    nameBox:SetMaxLetters(NAME_MAX)
    nameBox:SetText("")

    local action, frame = "frame", nil
    local frames, frameOrder = {}, {}
    for _, f in ipairs(FRAMES) do
        if Available(f[2]) then
            frames[f[2]] = f[1]
            frameOrder[#frameOrder + 1] = f[2]
        end
    end

    local ShowAction
    local actionLabel = Label(panel, "actionLabel", TEXT_ACTION_LABEL, nameBox)
    local actionDD = UI.KeepDropdown(panel, "actionDD", FIELD_W, ACTION_VALUES, ACTION_ORDER,
        function() return action end, function(v)
            action = v
            ShowAction()
        end)
    actionDD:SetPoint("TOPLEFT", actionLabel, "BOTTOMLEFT", 0, -FIELD_GAP)

    local targetLabel = Label(panel, "targetLabel", "", actionDD)
    local frameDD = UI.KeepDropdown(panel, "frameDD", FIELD_W, frames, frameOrder,
        function() return frame end, function(v) frame = v end)
    frameDD:SetPoint("TOPLEFT", targetLabel, "BOTTOMLEFT", 0, -FIELD_GAP)
    local commandBox = UI.Keep(panel, "commandBox", ns.NewEditBox)
    commandBox:SetSize(FIELD_W, FIELD_H)
    commandBox:SetPoint("TOPLEFT", targetLabel, "BOTTOMLEFT", 0, -FIELD_GAP)
    commandBox:SetText("")

    function ShowAction()
        local isFrame = action == "frame"
        targetLabel:SetText(isFrame and TEXT_WINDOW or TEXT_COMMAND_LABEL)
        frameDD:SetShown(isFrame)
        commandBox:SetShown(not isFrame)
    end
    ShowAction()

    local function Save()
        local name = (strtrim(nameBox:GetText()):gsub("^/", ""))
        if name == "" or not name:match("^[%w_]+$") then
            ns.Print(TEXT_BAD_NAME)
            return
        end
        local command = strtrim(commandBox:GetText())
        if action == "frame" and not frame then return ns.Print(TEXT_PICK_WINDOW) end
        if action == "command" and command == "" then return ns.Print(TEXT_TYPE_COMMAND) end
        local list = ns.SlashCommandList()
        for _, cmd in ipairs(list) do
            if strlower(cmd.name) == strlower(name) then
                return ns.Print("/" .. name .. TEXT_ALREADY)
            end
        end
        list[#list + 1] = { name = strlower(name), enabled = true,
            frame = action == "frame" and frame or nil,
            command = action == "command" and command or nil }
        dimmer:Hide()
        ns.RefreshSlashCommands()
        if onAdded then onAdded() end
    end
    UI.KeepButton(panel, "save", TEXT_SAVE, SAVE_W, SAVE_H, Save):SetPoint("BOTTOM", panel, "BOTTOM", -SAVE_X, SAVE_Y)
    UI.KeepButton(panel, "cancel", TEXT_CANCEL, SAVE_W, SAVE_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOM", panel, "BOTTOM", SAVE_X, SAVE_Y)
    dimmer:Show()
    nameBox:SetFocus()
end

local function Edited()
    ns.RefreshSlashCommands()
    UI:RefreshPage(true)
end

function ns.ShowSlashCommandEditor()
    local list = ns.SlashCommandList()
    local dimmer, panel = ns.MakeModal(EDITOR_W, EDITOR_TOP + math.max(1, #list) * EDITOR_ROW + EDITOR_FOOT,
        "slashCommandEditor")
    local head = UI.KeepFont(panel, "head", HEAD_SIZE, "OUTLINE")
    head:SetPoint("TOPLEFT", EDITOR_PAD, -HEAD_TOP)
    head:SetText(TEXT_EDITOR_TITLE)

    if #list == 0 then
        local none = UI.KeepFont(panel, "none", LABEL_SIZE, nil, T.muted)
        none:SetPoint("TOPLEFT", EDITOR_PAD, -EDITOR_TOP)
        none:SetText(TEXT_NONE)
    end
    for i, cmd in ipairs(list) do
        local y = -(EDITOR_TOP + (i - 1) * EDITOR_ROW)
        local toggle = UI.KeepToggle(panel, "toggle", function() return cmd.enabled end, function(v)
            cmd.enabled = v
            Edited()
        end)
        toggle:SetPoint("TOPLEFT", EDITOR_PAD, y)
        local name = UI.KeepFont(panel, "name", NAME_SIZE)
        name:SetPoint("LEFT", toggle, "RIGHT", EDITOR_GAP, 0)
        name:SetText("/" .. cmd.name)
        local remove = UI.KeepButton(panel, "remove", TEXT_REMOVE, EDITOR_REMOVE_W, EDITOR_BUTTON_H, function()
            if ns.RemoveSlashCommand(cmd.name) then UI:RefreshPage(true) end
            ns.ShowSlashCommandEditor()
        end)
        remove:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -EDITOR_PAD, y + (EDITOR_BUTTON_H - toggle:GetHeight()) / 2)
        local what = UI.KeepFont(panel, "what", LABEL_SIZE, nil, T.muted)
        what:SetPoint("LEFT", toggle, "RIGHT", EDITOR_GAP + EDITOR_NAME_W, 0)
        what:SetPoint("RIGHT", remove, "LEFT", -EDITOR_GAP, 0)
        what:SetJustifyH("LEFT")
        what:SetWordWrap(false)
        what:SetText(ns.SlashCommandSummary(cmd))
    end

    UI.KeepButton(panel, "add", TEXT_ADD, FOOT_BUTTON_W, FOOT_BUTTON_H, function()
        ns.ShowAddSlashCommand(function()
            UI:RefreshPage(true)
            ns.ShowSlashCommandEditor()
        end)
    end):SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", EDITOR_PAD, FOOT_Y)
    UI.KeepButton(panel, "restore", TEXT_RESTORE, FOOT_RESTORE_W, FOOT_BUTTON_H, function()
        ns.Confirm(TEXT_RESTORE_ASK, function()
            ns.RestoreSlashCommands()
            UI:RefreshPage(true)
            ns.ShowSlashCommandEditor()
        end)
    end):SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", EDITOR_PAD + FOOT_BUTTON_W + EDITOR_GAP, FOOT_Y)
    UI.KeepButton(panel, "close", TEXT_CLOSE, FOOT_BUTTON_W, FOOT_BUTTON_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -EDITOR_PAD, FOOT_Y)
    dimmer:Show()
end

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local function Summary()
    local list, on = ns.SlashCommandList(), 0
    for _, cmd in ipairs(list) do
        if cmd.enabled then on = on + 1 end
    end
    return TEXT_SUMMARY:format(#list, #list == 1 and TEXT_ONE or TEXT_MANY, on)
end

Settings.Page("QoL/System", S):Card({
    id = "slashCommands", name = "Custom Slash Commands", order = 20, switch = "slashCommands",
    help = "Short commands of your own that open a game window or run another command. A name another "
        .. "addon already uses is skipped.",
    search = "/cdm cdm cooldown viewer /em em edit mode /kb kb quick keybind",
    summary = Summary,
    rows = {
        { label = "Edit Commands", buttonText = "Edit...", button = ns.ShowSlashCommandEditor,
          help = "Add or remove your commands, turn each one on or off, or restore the defaults." },
    },
})

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "slashCommands" then ns.RefreshSlashCommands() end
end)
local function Refresh()
    ns.RefreshSlashCommands()
end

hooksecurefunc(ns, "Apply", Refresh)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Refresh)
