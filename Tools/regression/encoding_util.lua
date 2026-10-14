-- encoding_util.lua: a stand-in for the client's C_EncodingUtil (Base64, raw deflate, CBOR) on the embedded
-- LibDeflate, for tests that decode the addon's packed data the way the client does. Not a test itself
-- (run-all.sh runs only test*.lua). Run from the repo root.
--
--   env.C_EncodingUtil = dofile("Tools/regression/encoding_util.lua")()
return function()
    local libs = setmetatable({ strmatch = string.match }, { __index = _G })
    libs._G = libs
    for _, path in ipairs({ "Libs/LibStub/LibStub.lua", "Libs/LibDeflate/LibDeflate.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, libs)
        chunk()
    end
    local LibDeflate = libs.LibStub("LibDeflate")

    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local B64_VALUE = {}
    for i = 1, #B64 do B64_VALUE[B64:sub(i, i)] = i - 1 end

    local function DecodeBase64(s)
        local out, bits, count = {}, 0, 0
        for i = 1, #s do
            local v = B64_VALUE[s:sub(i, i)]
            if v then
                bits, count = bits * 64 + v, count + 6
                if count >= 8 then
                    count = count - 8
                    local byte = math.floor(bits / 2 ^ count)
                    out[#out + 1] = string.char(byte)
                    bits = bits - byte * 2 ^ count
                end
            end
        end
        return table.concat(out)
    end

    local function Cbor(s)
        local at = 1
        local function Arg(info)
            if info < 24 then return info end
            local n = ({ [24] = 1, [25] = 2, [26] = 4 })[info]
            local v = 0
            for _ = 1, n do v = v * 256 + s:byte(at); at = at + 1 end
            return v
        end
        local function Item()
            local head = s:byte(at); at = at + 1
            local major, n = math.floor(head / 32), Arg(head % 32)
            if major == 0 then return n end
            if major == 1 then return -1 - n end
            if major == 3 then local text = s:sub(at, at + n - 1); at = at + n; return text end
            if major == 4 then local t = {}; for i = 1, n do t[i] = Item() end; return t end
            local t = {}
            for _ = 1, n do local k = Item(); t[k] = Item() end
            return t
        end
        return Item()
    end

    return {
        DecodeBase64 = DecodeBase64,
        DecompressString = function(s) return LibDeflate:DecompressDeflate(s) end,
        DeserializeCBOR = Cbor,
    }
end
