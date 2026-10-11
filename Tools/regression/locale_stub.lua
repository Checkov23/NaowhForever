-- locale_stub.lua: ns.L, ns.Upper and ns.Lower as Core/Core.lua has them (on the English catalog), for tests that
-- build ns by hand.
local catalog = {}
local chunk = assert(loadfile("Core/Locales/enUS.lua"))
setfenv(chunk, { _G = { NaowhForeverLocale = catalog } })
chunk()

return {
    L = function(text, ...)
        local shown = catalog[text]
        if shown == nil or shown == true then shown = text end
        if select("#", ...) > 0 then return shown:format(...) end
        return shown
    end,
    Upper = string.upper,
    Lower = string.lower,
}
