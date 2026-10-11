-- Run with Lua 5.1 from the repository root: the Alerts group. Members stack upward from the
-- group's bottom in their order, whichever are shown; a scaled member is measured and offset in
-- the group's units; the one mover covers the stack and shows in Unlock Mode only while a member
-- is up; the group starts at the first old alert spot a player had (Camp Nearby's only while
-- AuraBuffs is loaded), saves it, and keeps its own spot from then on.

local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local function Frame(name)
    local f = { name = name, shown = true, w = 0, h = 0, scale = 1, hooks = {} }
    function f:SetSize(w, h)
        local changed = w ~= self.w or h ~= self.h
        self.w, self.h = w, h
        if changed then self:Fire("OnSizeChanged") end
    end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:SetScale(s) self.scale = s end
    function f:GetEffectiveScale() return self.scale end
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(point, rel, relPoint, x, y) self.point = { point, rel, relPoint, x or 0, y or 0 } end
    function f:IsShown() return self.shown end
    function f:SetShown(on) if on then self:Show() else self:Hide() end end
    function f:Show() if not self.shown then self.shown = true; self:Fire("OnShow") end end
    function f:Hide() if self.shown then self.shown = false; self:Fire("OnHide") end end
    function f:HookScript(event, fn)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], fn)
    end
    function f:Fire(event) for _, fn in ipairs(self.hooks[event] or {}) do fn(self) end end
    f.SetMovable, f.SetClampedToScreen = function() end, function() end
    return f
end

local function Settings(values)
    return { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end }
end

local function Fixture(qol, aura)
    local env = { pairs = pairs, ipairs = ipairs, type = type, math = math, table = table }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Apply = function() end, ShowUnlockMode = function() end,
        HideUnlockMode = function() end }
    ns.QoLSettings = Settings(qol)
    ns.AuraBuffSettings = aura and Settings(aura)
    ns.UI = { AttachMover = function(frame, label, onMoved, page)
        local mover = Frame()
        mover.shown = false
        mover.label, mover.onMoved, mover.page, mover.parent = label, onMoved, page, frame
        return mover
    end, SetMoverChoices = function(mover, choices) mover.choices = choices end }
    env.NaowhForever = ns
    env._G = env
    env.UIParent = Frame("UIParent")
    env.named = {}
    env.CreateFrame = function(_, name)
        local f = Frame(name)
        env.named[name] = f
        return f
    end
    env.hooksecurefunc = function(t, key, fn)
        local orig = t[key]
        t[key] = function(...) orig(...); fn(...) end
    end
    Load({ "Core/AlertStack.lua" }, env)
    return ns, env
end

local function Member(w, h)
    local f = Frame()
    f.shown = false
    f.w, f.h = w, h
    return f
end

do
    local qol = {}
    local ns = Fixture(qol, nil)
    local camp, talent, pet = Member(200, 26), Member(300, 32), Member(220, 36)
    ns.AlertStack(pet, 5, "Pet Tracker", "QoL/Combat", "QoL/Combat:petTracker")
    ns.AlertStack(camp, 1, "Camp Nearby", "AuraBuffs/Settings", "AuraBuffs/Settings:campNearby")
    ns.AlertStack(talent, 2, "Talent Points", "QoL/XP", "QoL/XP:talentPoints")
    Check(qol.alertsPos.point == "CENTER" and qol.alertsPos.y == 150,
        "no old spot and no AuraBuffs: the group starts at its default and saves it")
    talent:Show()
    pet:Show()
    Check(talent.point[4] == 0 and talent.point[5] == 0, "the lowest shown member sits on the group's bottom")
    Check(pet.point[5] == 32 + 6, "the next one stacks above it with the gap")
    camp:SetScale(1.5)
    camp:Show()
    Check(camp.point[5] == 0 and math.abs(talent.point[5] - 26 * 1.5 - 6) < 1e-9,
        "a scaled member goes to the bottom, measured in the group's units")
    local group = pet.point[2]
    local mover = rawget(group, "mover")
    Check(mover.label == "Alerts" and mover.page ~= nil, "one mover, named Alerts, with an options page")
    Check(#mover.choices == 3 and mover.choices[1].name == "Camp Nearby" and mover.choices[2].name == "Talent Points"
        and mover.choices[3].feature == "QoL/Combat:petTracker", "its Settings lists every alert in stack order, each with its card")
    Check(mover.shown == false, "the mover stays hidden outside Unlock Mode")
    ns.ShowUnlockMode()
    Check(mover.shown == true, "Unlock Mode shows the mover while a member is up")
    Check(mover.h == 26 * 1.5 + 6 + 32 + 6 + 36 and mover.w == 300, "the mover covers the whole stack")
    camp:Hide(); talent:Hide(); pet:Hide()
    Check(mover.shown == false, "no member up: no mover")
    ns.HideUnlockMode()
    mover.onMoved({ point = "CENTER", relPoint = "CENTER", x = 10, y = 20 })
    Check(qol.alertsPos.x == 10 and qol.alertsPos.y == 20, "moving the group saves its spot")
end

do
    local qol = { durabilityPos = { point = "CENTER", relPoint = "CENTER", x = 1, y = 2 } }
    local campPos = { point = "CENTER", relPoint = "BOTTOMLEFT", x = 500, y = 300 }
    local ns, env = Fixture(qol, { campAlertPos = campPos })
    ns.AlertStack(Member(300, 32), 3)
    Check(qol.alertsPos == campPos, "Camp Nearby's old spot comes first while AuraBuffs is loaded")
    local group = env.named.NaowhForeverAlerts
    Check(group.point[1] == "CENTER" and group.point[3] == "BOTTOMLEFT" and group.point[4] == 500,
        "the group is placed there")
end

do
    local qol = { durabilityPos = { point = "CENTER", relPoint = "CENTER", x = 1, y = 2 },
        restockPos = { point = "CENTER", relPoint = "CENTER", x = 3, y = 4 } }
    local ns = Fixture(qol, nil)
    ns.AlertStack(Member(300, 32), 3)
    Check(qol.alertsPos == qol.durabilityPos, "without AuraBuffs: the first old spot of the core alerts")
    qol.alertsPos = { point = "CENTER", relPoint = "CENTER", x = 7, y = 8 }
    ns.Apply()
    Check(qol.alertsPos.x == 7, "a saved group spot wins over the old ones")
end

print(("test-alert-stack: %d checks passed"):format(checks))
