-- CharacterPanel.lua: the Naowh Character Panel (ns.CharacterPanel): its switch and EllesmereUI's rule.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local ASK_DELAY = 2
local STYLE_OFF = "off"
local RELOAD_OFF = ns.L("EllesmereUI's %s is off, so Naowh's can take over. Reload now to switch?")
local RELOAD_ON = ns.L("EllesmereUI's %s is back on. Reload now to switch?")
local ASK = ns.L("EllesmereUI's %s is on. Naowh's is recommended, as it comes with more features. "
    .. "Use Naowh's instead?")
local TAKEN = ns.L("Naowh's %s takes over from EllesmereUI's after your next reload.")
local TEXT_USE_OURS, TEXT_KEEP_THEIRS = ns.L("Use Naowh's"), ns.L("Keep EllesmereUI's")

local rivals = {}
local newcomer

local function AskOnce()
    for _, rival in ipairs(rivals) do rival.Repair() end
    if InCombatLockdown() or ns.GamepadStandDown() then return end
    for _, rival in ipairs(rivals) do
        if not rival.Due() then
            rival.Forget()
        elseif newcomer or rival.Picked() then
            rival.TakeOver()
        else
            return rival.Ask()
        end
    end
end

local function OnEnteringWorld(self)
    self:UnregisterAllEvents()
    newcomer = not ns.AccountSettings().welcomeSeen
    C_Timer.After(ASK_DELAY, AskOnce)
end

local CP = {}
ns.CharacterPanel = CP

function CP.Rival(r)
    local rival = {}
    local tookOver, asked, picked = r.key .. "TookOver", r.key .. "Asked", r.key .. "Picked"

    function rival.Styled()
        local E = _G.EllesmereUI
        return E ~= nil and E.GetBlizzWindowStyle ~= nil and E.GetBlizzWindowStyle(r.winKey) ~= STYLE_OFF
    end

    function rival.On()
        return S.Get("enabled") == true and S.Get(r.key) == true and not rival.Styled()
            and not ns.GamepadStandDown()
    end

    local function Swap(on)
        local db = _G.EllesmereUIDB
        if type(db) ~= "table" or not (_G.EllesmereUI and _G.EllesmereUI.GetBlizzWindowStyle) then return end
        if on and ns.GamepadStandDown() then return end
        if on and db[r.dbKey] ~= false then
            db[r.dbKey] = false
            S.Set(tookOver, true)
            ns.ConfirmReload(RELOAD_OFF:format(r.name))
        elseif not on and S.Get(tookOver) then
            S.Set(tookOver, false)
            if db[r.dbKey] == false then
                db[r.dbKey] = true
                ns.ConfirmReload(RELOAD_ON:format(r.name))
            end
        end
    end

    S.OnChange(function(key, value)
        if key == r.key then Swap(value == true) end
    end)

    local function UseOurs()
        S.Set(asked, true)
        S.Set(r.key, true)
    end

    local function KeepTheirs()
        S.Set(asked, true)
        S.Set(r.key, false)
    end

    function rival.Repair()
        local db = _G.EllesmereUIDB
        if type(db) ~= "table" or not S.Get(tookOver) or db[r.dbKey] == false then return end
        S.Set(tookOver, false)
        S.Set(asked, false)
    end

    function rival.Picked()
        return S.Get(picked) == true
    end

    function rival.Forget()
        if S.Get(picked) ~= nil then S.Set(picked, nil) end
    end

    function rival.Due()
        if S.Get(asked) and not rival.Picked() then return false end
        if not (S.Get("enabled") and S.Get(r.key) and rival.Styled()) then return false end
        return type(_G.EllesmereUIDB) == "table"
    end

    function rival.Ask()
        ns.Confirm(ASK:format(r.name), UseOurs, KeepTheirs, TEXT_USE_OURS, TEXT_KEEP_THEIRS)
    end

    function rival.TakeOver()
        rival.Forget()
        S.Set(asked, true)
        _G.EllesmereUIDB[r.dbKey] = false
        S.Set(tookOver, true)
        ns.Print(TAKEN:format(r.name))
    end

    rivals[#rivals + 1] = rival
    return rival
end

local sheet = CP.Rival({ key = "characterPanel", winKey = "charsheet", dbKey = "themedCharacterSheet",
    name = ns.L("character panel") })

CP.EllesmereSheet = sheet.Styled
CP.On = sheet.On

function CP._AskForTest(isNew)
    newcomer = isNew
    AskOnce()
end

local asker = CreateFrame("Frame")
asker:RegisterEvent("PLAYER_ENTERING_WORLD")
asker:SetScript("OnEvent", OnEnteringWorld)
