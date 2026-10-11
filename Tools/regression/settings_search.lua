-- Declares card specs a test captured from a module's stubbed Settings.Page through the real
-- Shared/Settings/Settings.lua and Core/Options/Search.lua, and returns a search over them: the
-- hits for a query, as the options window's sidebar search finds them. Not a test itself
-- (run-all.sh runs only test*.lua). Run from the repo root.
--
--   local Search = dofile("Tools/regression/settings_search.lua")({ ["QoL/Interface"] = { card } })
--   local hits = Search("flight master")   -- { { label = "Flight Masters", card = "QoL/Interface:townMap" }, ... }
return function(pages)
    local ns = { THEME = {}, L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper,
        Lower = string.lower, Color = function(_, text) return text end,
        Shared = { Style = dofile("Tools/regression/shared_style.lua") }, UI = {} }
    local env = setmetatable({ _G = { NaowhForever = ns } }, { __index = _G })
    for _, path in ipairs({ "Shared/Settings/Settings.lua", "Core/Options/Search.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local Settings, list = ns.Shared.Settings, {}
    local store = { Get = function() end, Set = function() end }
    for key, cards in pairs(pages) do
        local page = Settings.Page(key, store)
        for _, card in ipairs(cards) do page:Card(card) end
        list[#list + 1] = { key = key, name = key, title = key }
    end
    ns.UI.SearchPages = function() return list end
    local found = ns.UI.Search.Collect()
    return function(query)
        return ns.UI.Search.Find(found, query)
    end
end
