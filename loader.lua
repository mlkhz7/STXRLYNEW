--[[ STXRLY NEW • Loader público • Delta Mobile / PC ]]

local RAW = "https://raw.githubusercontent.com/USUARIO/REPO/main/STXRLY_NEW.enc"   -- <<< CAMBIA ESTO
local KEY = "STXRLY_NEW_KEY_2026"

local function paso(t) print("[STXRLY NEW] " .. t) end

if RAW:find("USUARIO/REPO") then
    warn("[STXRLY NEW] No cambiaste USUARIO/REPO en la linea 3 del loader")
end

paso("descargando...")
local ok, raw = pcall(function()
    return game:HttpGet(RAW .. "?v=" .. tostring(math.floor(os.time() / 300)))
end)
if not ok then return warn("[STXRLY NEW] No se pudo descargar: " .. tostring(raw)) end
if #raw < 200 then return warn("[STXRLY NEW] Archivo vacio/corto (" .. #raw .. " bytes). ¿Subiste el .enc?") end

local B64C = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64D = {}
for i = 1, #B64C do B64D[B64C:sub(i, i)] = i - 1 end

local function b64d(s)
    s = s:gsub("%s", "")
    local o, buf, bits = {}, 0, 0
    for i = 1, #s do
        local v = B64D[s:sub(i, i)]
        if v then
            buf = buf * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                o[#o + 1] = string.char(math.floor(buf / 2 ^ bits) % 256)
                buf = buf % 2 ^ bits
            end
        end
    end
    return table.concat(o)
end

local function xr(d, k)
    local o = {}
    for i = 1, #d do
        o[i] = string.char(bit32.bxor(string.byte(d, i), string.byte(k, (i - 1) % #k + 1)))
    end
    return table.concat(o)
end

local f, e = loadstring(xr(b64d(raw), KEY))
if not f then return warn("[STXRLY NEW] Fallo el descifrado: " .. tostring(e)) end
paso("ok, ejecutando")
f()