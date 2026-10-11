-- locale_stub.lua: ns.L, ns.Upper and ns.Lower as Core/Core.lua has them, for tests that build ns by hand.
return {
    L = function(text, ...)
        if select("#", ...) > 0 then return text:format(...) end
        return text
    end,
    Upper = string.upper,
    Lower = string.lower,
}
