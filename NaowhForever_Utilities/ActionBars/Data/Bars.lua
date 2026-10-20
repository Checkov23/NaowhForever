-- Bars.lua: the action bars as the game numbers them: each one's page of slots and the binding its buttons answer to, the pet bar's keys, and the pages a class's forms swap in (ns.ActionBars.BARS).
local ns = _G.NaowhForever

ns.ActionBars.BARS = {
    { page = 1, name = "Action Bar 1", button = "ACTIONBUTTON" },
    { page = 6, name = "Action Bar 2", button = "MULTIACTIONBAR1BUTTON" },
    { page = 5, name = "Action Bar 3", button = "MULTIACTIONBAR2BUTTON" },
    { page = 3, name = "Action Bar 4", button = "MULTIACTIONBAR3BUTTON" },
    { page = 4, name = "Action Bar 5", button = "MULTIACTIONBAR4BUTTON" },
    { page = 13, name = "Action Bar 6", button = "MULTIACTIONBAR5BUTTON" },
    { page = 14, name = "Action Bar 7", button = "MULTIACTIONBAR6BUTTON" },
    { page = 15, name = "Action Bar 8", button = "MULTIACTIONBAR7BUTTON" },
    { page = 2, name = "Action Bar 1, Page 2", button = "ACTIONBUTTON" },
    { page = 7, name = "Stance Bar 1", button = "ACTIONBUTTON" },
    { page = 8, name = "Stance Bar 2", button = "ACTIONBUTTON" },
    { page = 9, name = "Stance Bar 3", button = "ACTIONBUTTON" },
    { page = 10, name = "Stance Bar 4", button = "ACTIONBUTTON" },
    { page = 11, name = "Extra Bar 1", button = "ACTIONBUTTON" },
    { page = 12, name = "Extra Bar 2", button = "ACTIONBUTTON" },
}

ns.ActionBars.PET_BAR = { name = "Pet Bar", button = "BONUSACTIONBUTTON", buttons = 10 }

ns.ActionBars.PET_CLASSES = { HUNTER = true, WARLOCK = true }

ns.ActionBars.FORMS = {
    ROGUE = { { page = 7, name = "Stealth" } },
    DRUID = { { page = 7, name = "Cat" }, { page = 8, name = "Prowl" }, { page = 9, name = "Bear" },
        { page = 10, name = "Moonkin" } },
    WARRIOR = { { page = 7, name = "Battle Stance" }, { page = 8, name = "Defensive Stance" },
        { page = 9, name = "Berserker Stance" } },
}
