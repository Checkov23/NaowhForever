-- Launchers.lua: the Naowh Forever launcher and one per module, for the minimap, the Top Bar and broker displays.
local ns = _G.NaowhForever
local O = ns.Options

local MODULES, Loaded, OpenModule, MinimapButtonOn = O.MODULES, O.Loaded, O.OpenModule, O.MinimapButtonOn

local LOGO = ns.MEDIA .. "LogoAddon.tga"
local LAUNCHER_NAME = "NaowhForever"
local LAUNCHER_LABEL = "Naowh Forever"
local MINIMAP_POS = 220
local TIP_TITLE = { r = 1, g = 0.82, b = 0 }
local TIP_TEXT = { r = 1, g = 1, b = 1 }
local TEXT_CLICK = ns.L("Click to open settings.")
local TEXT_DRAG = ns.L("Drag to move the minimap button.")
local TEXT_MODULE_CLICK = ns.L("Click to open or close it on its own.")
local TEXT_SETTINGS_CLICK = ns.L("Click to open or close its settings.")

local launcherEvents = CreateFrame("Frame")
local function TipTitle(tooltip, text)
    local c = ns.ThemeTint("accent", TIP_TITLE)
    tooltip:AddLine(text, c.r, c.g, c.b)
end
local function TipLine(tooltip, text)
    local c = ns.ThemeTint("fg", TIP_TEXT)
    tooltip:AddLine(text, c.r, c.g, c.b)
end

local function MainLauncher(account)
    if type(account.minimap) ~= "table" then
        account.minimap = { minimapPos = MINIMAP_POS }
    end
    local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(LAUNCHER_NAME, {
        type = "launcher",
        label = LAUNCHER_LABEL,
        icon = LOGO,
        OnClick = function() ns.ToggleOptionsWindow() end,
        OnTooltipShow = function(tooltip)
            TipTitle(tooltip, LAUNCHER_LABEL)
            TipLine(tooltip, ns.L(TEXT_CLICK))
            TipLine(tooltip, ns.L(TEXT_DRAG))
        end,
    })
    LibStub("LibDBIcon-1.0"):Register(LAUNCHER_NAME, launcher, account.minimap)
end

local function ModuleLauncher(account, mod)
    local db = account.moduleButtons[mod.name] or { minimapPos = MINIMAP_POS }
    account.moduleButtons[mod.name] = db
    db.hide = not MinimapButtonOn(mod)
    local obj = LibStub("LibDataBroker-1.1"):NewDataObject(LAUNCHER_NAME .. mod.short, {
        type = "launcher",
        label = ns.L(mod.name),
        icon = mod.icon,
        OnClick = function() OpenModule(mod) end,
        OnTooltipShow = function(tooltip)
            TipTitle(tooltip, ns.L(mod.name))
            TipLine(tooltip, ns.L(mod.open and TEXT_MODULE_CLICK or TEXT_SETTINGS_CLICK))
        end,
    })
    LibStub("LibDBIcon-1.0"):Register(LAUNCHER_NAME .. mod.short, obj, db)
end

local function OnLogin(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.SaveModuleDefaults()
    local account = ns.AccountSettings()
    MainLauncher(account)
    account.moduleButtons = account.moduleButtons or {}
    for _, mod in ipairs(MODULES) do
        if mod.command and Loaded(mod) then ModuleLauncher(account, mod) end
    end
end

launcherEvents:SetScript("OnEvent", OnLogin)
launcherEvents:RegisterEvent("PLAYER_LOGIN")
