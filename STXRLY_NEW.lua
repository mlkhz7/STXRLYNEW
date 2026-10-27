--[[=====================================================================
    ███████ ████████ ██   ██ ██████  ██      ██    ██
    ██         ██    ██   ██ ██   ██ ██      ██    ██
    ███████    ██    ██   ██ ██████  ██      ██    ██
         ██    ██    ██   ██ ██   ██ ██      ██    ██
    ███████    ██    ██   ██ ██   ██ ███████  ██████

      S T X R L Y   N E W   •   Egg Stealer   •   v1.3 MOBILE

    • Delta Mobile: touch, sin teclado, debajo de la topbar
    • Anti-deteccion: humanizacion, rate-limit, caminar (no TP)
    • ENCRYPT() -> STXRLY_NEW.enc para subir a GitHub
=======================================================================]]

local VERSION = "1.3"

--== [0] MINI-CIFRADO DE STRINGS =======================================
local XK = 90
local function X(s)
    local o = {}
    for i = 1, #s do o[i] = string.char(bit32.bxor(string.byte(s, i), XK)) end
    return table.concat(o)
end
local TITULO = X("\9\14\2\8\22\3\122\20\31\13")   -- "STXRLY NEW"

--== [1] CONFIGURACION =================================================
local CFG = {
    Seguridad = {
        AntiDeteccion = true, Humanizar = true, Jitter = 0.15,
        RateLimit = 14, CaminarNoTP = true, AntiAFK = true,
    },
    Huevos = { SoloFavoritos = false, MinPrecio = 0, Radio = 700 },
    Servidor = { UmbralBuenHuevo = 250000, TiempoParaHop = 30 },
    Velocidad = { Valor = 32, Min = 16, Max = 150, RespetarCarga = true },
}

--== [2] SERVICIOS, ANTI-DOBLE-EJECUCION ===============================
local Players = game:GetService("Players")
local RunSrv  = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("ReplicatedStorage")
local TS      = game:GetService("TeleportService")
local Http    = game:GetService("HttpService")
local VU      = game:GetService("VirtualUser")
local LP      = Players.LocalPlayer

local GENV = (getgenv and getgenv()) or _G
if GENV.STXRLY_NEW and GENV.STXRLY_NEW.gui then
    pcall(function() GENV.STXRLY_NEW.gui:Destroy() end)
end
local CTRL = {}
GENV.STXRLY_NEW_CTRL = CTRL
local function vivo() return GENV.STXRLY_NEW_CTRL == CTRL end

local S = {
    EggCollector = false, SpeedBoost = false, ServerHop = false,
    AutoPlace = false, AutoOpenPlace = false, AutoTreadmill = false,
    NoOpenFav = true, AutoMutFav = false, SoloFav = false,
}
local FAV, PUNTO_BASE = {}, nil

--== [3] UTILIDADES ====================================================
local function paso(t) print("[STXRLY NEW] " .. t) end

local function esperar(t)
    if CFG.Seguridad.Humanizar then
        t = t * (1 + (math.random() * 2 - 1) * CFG.Seguridad.Jitter)
    end
    task.wait(math.max(t, 0.02))
end

local function pcall2(f, ...)
    local ok, res = pcall(f, ...)
    if ok then return res end
    return nil
end

local ultima = 0
local function gate()
    if not CFG.Seguridad.AntiDeteccion then return end
    local min = 1 / CFG.Seguridad.RateLimit
    local dt = os.clock() - ultima
    if dt < min then task.wait(min - dt) end
    ultima = os.clock()
end

--== [4] PERSONAJE / MOVIMIENTO ========================================
local function personaje()
    local c = LP.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

local function irA(pos, dist)
    dist = dist or 8
    local _, hum, hrp = personaje()
    if not (hum and hrp) then return false end
    if (hrp.Position - pos).Magnitude <= dist then return true end
    if CFG.Seguridad.CaminarNoTP then
        hum:MoveTo(pos)
        local t = 0
        while t < 14 do
            esperar(0.1); t = t + 0.1
            local _, h2, r2 = personaje()
            if not (h2 and r2) then return false end
            if (r2.Position - pos).Magnitude <= dist then return true end
        end
        return false
    else
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        esperar(0.15)
        return true
    end
end

--== [5] REMOTOS =======================================================
local cacheRem = {}
local function remoto(kw)
    if cacheRem[kw] == nil then
        cacheRem[kw] = false
        for _, d in ipairs(RS:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                if d.Name:lower():find(kw:lower(), 1, true) then cacheRem[kw] = d; break end
            end
        end
    end
    return cacheRem[kw] or nil
end

local function fire(kw, ...)
    local r = remoto(kw)
    if not r then return false end
    gate()
    return pcall2(function() r:FireServer(...) end) ~= nil
end

local function promptCerca()
    local _, _, hrp = personaje()
    if not hrp then return nil end
    local mejor, mejorD = nil, 9
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled and d.Parent and d.Parent:IsA("BasePart") then
            local dd = (d.Parent.Position - hrp.Position).Magnitude
            if dd < mejorD then mejor, mejorD = d, dd end
        end
    end
    return mejor
end

local function usarPrompt(pr)
    if not pr then return end
    if fireproximityprompt then
        pcall2(fireproximityprompt, pr)
    else
        pcall2(function() pr:InputHoldBegin(); task.wait(0.25); pr:InputHoldEnd() end)
    end
end

--== [6] HUEVOS ========================================================
local function esHuevo(o)
    local n = o.Name:lower()
    return n:find("egg", 1, true) or n:find("huevo", 1, true)
end

local function parteDe(o)
    if o:IsA("BasePart") then return o end
    return o:FindFirstChildWhichIsA("BasePart", true)
end

local function precioDe(o)
    local v = o:GetAttribute("Price") or o:GetAttribute("Cost")
           or o:GetAttribute("Value") or o:GetAttribute("Worth")
    if not v then
        local d = o.Name:match("(%d+)")
        v = d and tonumber(d) or 0
    end
    return tonumber(v) or 0
end

local function esFavorito(nome)
    local n = tostring(nome):lower()
    for _, f in ipairs(FAV) do
        if n:find(f:lower(), 1, true) then return true end
    end
    return false
end

local _cache, _cacheT = nil, 0
local function huevos()
    if _cache and os.clock() - _cacheT < 0.5 then return _cache end
    local lista = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("Model") or d:IsA("BasePart")) and esHuevo(d) then
            local p = parteDe(d)
            if p then
                lista[#lista + 1] = { obj = d, parte = p, precio = precioDe(d), nombre = d.Name }
            end
        end
    end
    table.sort(lista, function(a, b) return a.precio > b.precio end)
    _cache, _cacheT = lista, os.clock()
    return lista
end

local function mejorHuevo()
    local _, _, hrp = personaje()
    if not hrp then return nil end
    for _, h in ipairs(huevos()) do
        if (h.parte.Position - hrp.Position).Magnitude <= CFG.Huevos.Radio
            and h.precio >= CFG.Huevos.MinPrecio
            and ((not S.SoloFav) or esFavorito(h.nombre)) then
            return h
        end
    end
    return nil
end

local function cargando()
    local c = LP.Character
    if not c then return false end
    for _, d in ipairs(c:GetChildren()) do
        local n = d.Name:lower()
        if esHuevo(d) or n:find("carry", 1, true) or n:find("holding", 1, true) then return true end
    end
    return false
end

--== [7] ACCIONES ======================================================
local function guardarBase()
    local _, _, hrp = personaje()
    if hrp then PUNTO_BASE = hrp.Position end
end

local function colocarHuevo()
    if PUNTO_BASE then irA(PUNTO_BASE, 12) end
    fire("place"); esperar(0.35)
    fire("drop");  esperar(0.2)
    usarPrompt(promptCerca())
end

local function abrirHuevos()
    local n = 0
    for _, h in ipairs(huevos()) do
        if n >= 3 then break end
        if not (S.NoOpenFav and esFavorito(h.nombre)) then
            fire("open", h.obj); esperar(0.3)
            fire("hatch", h.obj)
            n = n + 1
        end
    end
    if n == 0 then fire("open") end
end

local function equiparMejor()
    fire("equipbest"); esperar(0.25)
    fire("equip");     esperar(0.2)
    fire("best")
end

local function subirTreadmill()
    for _, d in ipairs(workspace:GetDescendants()) do
        local nm = d.Name:lower()
        if nm:find("treadmill", 1, true) or nm:find("cinta", 1, true) then
            local p = parteDe(d)
            if p then irA(p.Position, 9) end
            usarPrompt(d:FindFirstChildWhichIsA("ProximityPrompt", true))
            break
        end
    end
    fire("treadmill"); esperar(0.2)
    fire("upgrade")
end

local function aplicarMutacionFav()
    local obj = nil
    for _, h in ipairs(huevos()) do
        if esFavorito(h.nombre) then obj = h; break end
    end
    if obj then irA(obj.parte.Position, 9) end
    fire("mutation"); esperar(0.3)
    fire("applymutation")
end

local function aplicarVelocidad()
    local _, hum = personaje()
    if not hum then return end
    if CFG.Velocidad.RespetarCarga and cargando() then return end
    if hum.WalkSpeed ~= CFG.Velocidad.Valor then hum.WalkSpeed = CFG.Velocidad.Valor end
end

local function hop()
    local ok = pcall2(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100&excludeFullGames=true"):format(game.PlaceId)
        local data = Http:JSONDecode(game:HttpGet(url))
        local ids = {}
        for _, srv in ipairs(data.data or {}) do
            if srv.id ~= game.JobId and (srv.playing or 0) < (srv.maxPlayers or 30) then
                ids[#ids + 1] = srv.id
            end
        end
        if #ids > 0 then
            TS:TeleportToPlaceInstance(game.PlaceId, ids[math.random(1, #ids)], LP)
        else
            TS:Teleport(game.PlaceId, LP)
        end
    end)
    if not ok then pcall2(function() TS:Teleport(game.PlaceId, LP) end) end
end

--== [8] INTERFAZ ======================================================
paso("construyendo UI")
local MOVIL = UIS.TouchEnabled and not UIS.KeyboardEnabled
local ANCHO = MOVIL and 244 or 272
local ALTO  = MOVIL and 372 or 384

local function nuevo(cls, props, pai)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = pai
    return o
end
local function curva(o, r) nuevo("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o) end
local function contorno(o, col, esp, tr)
    return nuevo("UIStroke", {
        Color = col, Thickness = esp or 1.5,
        Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end

local gui = nuevo("ScreenGui", {
    Name = TITULO, ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- contenedor: CoreGui (el juego no la ve) con caida a PlayerGui
local function moverGUI(modo)
    local destinos = {}
    if modo == "coregui" then
        destinos = { game:GetService("CoreGui"), LP:FindFirstChild("PlayerGui") }
    elseif modo == "gethui" then
        local ok, r = pcall(function() return gethui() end)
        destinos = { (ok and r) or nil, game:GetService("CoreGui"), LP:FindFirstChild("PlayerGui") }
    else
        destinos = { LP:FindFirstChild("PlayerGui") }
    end
    for _, d in ipairs(destinos) do
        if d then
            local ok = pcall(function() gui.Parent = d end)
            if ok and gui.Parent == d then
                paso("GUI -> " .. d:GetFullName())
                return true
            end
        end
    end
    return false
end

local panel = nuevo("Frame", {
    Size = UDim2.fromOffset(ANCHO, ALTO),
    Position = UDim2.new(0, 12, 0, MOVIL and 56 or 30),
    BackgroundColor3 = Color3.fromRGB(13, 13, 15),
    BorderSizePixel = 0, Active = true,
}, gui)
curva(panel, 14)
contorno(panel, Color3.fromRGB(138, 60, 255), 1.5, 0.08)

local barra = nuevo("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, panel)

local titulo = nuevo("TextLabel", {
    Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 40, 0, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 17,
    Text = TITULO, TextColor3 = Color3.fromRGB(255, 40, 40),
    TextXAlignment = Enum.TextXAlignment.Center,
}, barra)
contorno(titulo, Color3.fromRGB(255, 40, 40), 1.2, 0.55)

local btnMin = nuevo("TextButton", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 6, 0.5, -15),
    BackgroundTransparency = 1, Text = "–", Font = Enum.Font.GothamBold,
    TextSize = 16, TextColor3 = Color3.fromRGB(140, 140, 155), AutoButtonColor = false,
}, barra)

local btnCerrar = nuevo("TextButton", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -36, 0.5, -15),
    BackgroundTransparency = 1, Text = "×", Font = Enum.Font.GothamBold,
    TextSize = 16, TextColor3 = Color3.fromRGB(140, 140, 155), AutoButtonColor = false,
}, barra)

local arrastrando, ini, iniPos = false, nil, nil
barra.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        arrastrando, ini, iniPos = true, i.Position, panel.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then arrastrando = false end
        end)
    end
end)
barra.InputChanged:Connect(function(i)
    if arrastrando and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - ini
        panel.Position = UDim2.new(iniPos.X.Scale, iniPos.X.Offset + d.X, iniPos.Y.Scale, iniPos.Y.Offset + d.Y)
    end
end)

local pags, botones, tabActual = {}, {}, 1
local nombres = { "MAIN", "FAV EGGS", "AJUSTES" }
local ANCHO_TAB = MOVIL and 70 or 72

local function seleccionar(i)
    tabActual = i
    for j = 1, #pags do
        pags[j].Visible = (j == i)
        local b = botones[j]
        b.btn.TextColor3 = (j == i) and Color3.fromRGB(201, 169, 255) or Color3.fromRGB(107, 107, 120)
        b.btn.BackgroundColor3 = (j == i) and Color3.fromRGB(31, 22, 48) or Color3.fromRGB(20, 20, 25)
        b.stroke.Color = (j == i) and Color3.fromRGB(138, 60, 255) or Color3.fromRGB(44, 44, 54)
    end
end

for i = 1, 3 do
    local b = nuevo("TextButton", {
        Size = UDim2.fromOffset(ANCHO_TAB, 24), Position = UDim2.new(0, 10 + (i - 1) * (ANCHO_TAB + 4), 0, 46),
        BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0,
        Text = nombres[i], Font = Enum.Font.GothamBold, TextSize = 9,
        TextColor3 = Color3.fromRGB(107, 107, 120), AutoButtonColor = false,
    }, panel)
    curva(b, 6)
    botones[i] = { btn = b, stroke = contorno(b, Color3.fromRGB(44, 44, 54), 1, 0) }
    b.MouseButton1Click:Connect(function() seleccionar(i) end)

    local p = nuevo("Frame", {
        Size = UDim2.new(1, -20, 1, -84), Position = UDim2.new(0, 10, 0, 76),
        BackgroundTransparency = 1, Visible = false,
    }, panel)
    nuevo("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, p)
    pags[i] = p
end

local function filaToggle(texto, pagina, clave, defecto, alCambiar)
    if defecto ~= nil then S[clave] = defecto end
    local fila = nuevo("Frame", { Size = UDim2.new(1, 0, 0, MOVIL and 30 or 26), BackgroundTransparency = 1 }, pagina)
    nuevo("TextLabel", {
        Size = UDim2.new(1, -56, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 11, Text = texto,
        TextColor3 = Color3.fromRGB(214, 214, 222), TextXAlignment = Enum.TextXAlignment.Left,
    }, fila)
    local pill = nuevo("TextButton", {
        Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -38, 0.5, -10),
        BackgroundColor3 = Color3.fromRGB(28, 28, 34), BorderSizePixel = 0,
        Text = "", AutoButtonColor = false,
    }, fila)
    curva(pill, 10)
    local pst = contorno(pill, Color3.fromRGB(44, 44, 54), 1, 0)
    local knob = nuevo("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(74, 74, 86), BorderSizePixel = 0,
    }, pill)
    curva(knob, 7)

    local function pintar(on)
        if on then
            pill.BackgroundColor3 = Color3.fromRGB(56, 26, 96)
            pst.Color = Color3.fromRGB(138, 60, 255)
            knob.BackgroundColor3 = Color3.fromRGB(168, 107, 255)
            knob.Position = UDim2.new(1, -17, 0.5, -7)
        else
            pill.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
            pst.Color = Color3.fromRGB(44, 44, 54)
            knob.BackgroundColor3 = Color3.fromRGB(74, 74, 86)
            knob.Position = UDim2.new(0, 3, 0.5, -7)
        end
    end
    pintar(S[clave])
    pill.MouseButton1Click:Connect(function()
        S[clave] = not S[clave]
        pintar(S[clave])
        if alCambiar then task.spawn(alCambiar, S[clave]) end
    end)
    return pintar
end

local function filaSlider(texto, pagina, min, max, valor, alCambiar)
    local caja = nuevo("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1 }, pagina)
    nuevo("TextLabel", {
        Size = UDim2.new(1, -46, 0, 15), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 11, Text = texto,
        TextColor3 = Color3.fromRGB(214, 214, 222), TextXAlignment = Enum.TextXAlignment.Left,
    }, caja)
    local val = nuevo("TextLabel", {
        Size = UDim2.fromOffset(46, 15), Position = UDim2.new(1, -46, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11,
        Text = tostring(valor), TextColor3 = Color3.fromRGB(168, 107, 255),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, caja)
    local zona = nuevo("Frame", {
        Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 16), BackgroundTransparency = 1,
    }, caja)
    local track = nuevo("Frame", {
        Size = UDim2.new(1, -12, 0, 5), Position = UDim2.new(0, 6, 0.5, -2.5),
        BackgroundColor3 = Color3.fromRGB(34, 34, 42), BorderSizePixel = 0,
    }, zona)
    curva(track, 3)
    local fill = nuevo("Frame", {
        Size = UDim2.new((valor - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(138, 60, 255), BorderSizePixel = 0,
    }, track)
    curva(fill, 3)
    local knob = nuevo("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new((valor - min) / (max - min), -7, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(201, 169, 255), BorderSizePixel = 0,
    }, track)
    curva(knob, 7)

    local moviendo = false
    local function set(x)
        local p = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(min + (max - min) * p + 0.5)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, -7, 0.5, -7)
        val.Text = tostring(v)
        if alCambiar then alCambiar(v) end
    end
    zona.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            moviendo = true; set(i.Position.X)
        end
    end)
    zona.InputChanged:Connect(function(i)
        if moviendo and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            set(i.Position.X)
        end
    end)
    zona.InputEnded:Connect(function() moviendo = false end)
    return val
end

local function separador(pagina)
    nuevo("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(30, 30, 38), BorderSizePixel = 0 }, pagina)
end

--== [9] CONTENIDO =====================================================
filaToggle("Egg Collector", pags[1], "EggCollector", false)
filaToggle("Speed Boost", pags[1], "SpeedBoost", false)
filaSlider("Velocidad", pags[1], CFG.Velocidad.Min, CFG.Velocidad.Max, CFG.Velocidad.Valor, function(v)
    CFG.Velocidad.Valor = v
end)
separador(pags[1])
filaToggle("Server hop", pags[1], "ServerHop", false)
filaToggle("Auto Place After Steal", pags[1], "AutoPlace", true)
filaToggle("Auto Open Eggs And Place Best Pets", pags[1], "AutoOpenPlace", false)
filaToggle("Auto Upgrade Treadmill", pags[1], "AutoTreadmill", false)

filaToggle("Dont Open Favorite Eggs", pags[2], "NoOpenFav", true)
filaToggle("Auto Apply Mutation Favorite", pags[2], "AutoMutFav", false)
filaToggle("Solo huevos favoritos", pags[2], "SoloFav", false)
separador(pags[2])
nuevo("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold, TextSize = 9, Text = "FAVORITOS",
    TextColor3 = Color3.fromRGB(107, 107, 120), TextXAlignment = Enum.TextXAlignment.Left,
}, pags[2])

local lista = nuevo("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(138, 60, 255),
    CanvasSize = UDim2.new(0, 0, 0, 0),
}, pags[2])

local function renderFavs()
    for _, c in ipairs(lista:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for i, f in ipairs(FAV) do
        local fila = nuevo("Frame", {
            Size = UDim2.new(1, -6, 0, 26), Position = UDim2.new(0, 0, 0, (i - 1) * 28),
            BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0,
        }, lista)
        curva(fila, 6)
        contorno(fila, Color3.fromRGB(32, 32, 40), 1, 0)
        nuevo("TextLabel", {
            Size = UDim2.new(1, -34, 1, 0), Position = UDim2.new(0, 9, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11,
            Text = "★ " .. f, TextColor3 = Color3.fromRGB(214, 214, 222),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, fila)
        local x = nuevo("TextButton", {
            Size = UDim2.fromOffset(28, 26), Position = UDim2.new(1, -30, 0, 0),
            BackgroundTransparency = 1, Text = "×", Font = Enum.Font.GothamBold,
            TextSize = 14, TextColor3 = Color3.fromRGB(92, 92, 104), AutoButtonColor = false,
        }, fila)
        x.MouseButton1Click:Connect(function()
            table.remove(FAV, i); renderFavs()
        end)
    end
    lista.CanvasSize = UDim2.new(0, 0, 0, #FAV * 28)
end

local cajaAdd = nuevo("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, pags[2])
local entrada = nuevo("TextBox", {
    Size = UDim2.new(1, -60, 1, 0), BackgroundColor3 = Color3.fromRGB(20, 20, 25),
    BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 11,
    PlaceholderText = "nombre del huevo...", PlaceholderColor3 = Color3.fromRGB(92, 92, 104),
    Text = "", TextColor3 = Color3.fromRGB(214, 214, 222), ClearTextOnFocus = false,
}, cajaAdd)
curva(entrada, 6)
contorno(entrada, Color3.fromRGB(32, 32, 40), 1, 0)

local botonAdd = nuevo("TextButton", {
    Size = UDim2.fromOffset(54, 28), Position = UDim2.new(1, -54, 0, 0),
    BackgroundColor3 = Color3.fromRGB(56, 26, 96), BorderSizePixel = 0,
    Text = "AÑADIR", Font = Enum.Font.GothamBold, TextSize = 8,
    TextColor3 = Color3.fromRGB(201, 169, 255), AutoButtonColor = false,
}, cajaAdd)
curva(botonAdd, 6)
contorno(botonAdd, Color3.fromRGB(138, 60, 255), 1, 0.2)

local function agregarFav()
    local t = entrada.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then
        FAV[#FAV + 1] = t
        entrada.Text = ""
        renderFavs()
    end
end
botonAdd.MouseButton1Click:Connect(agregarFav)
entrada.FocusLost:Connect(agregarFav)
renderFavs()

filaToggle("Anti-Deteccion", pags[3], "AntiD", true, function(v) CFG.Seguridad.AntiDeteccion = v end)
filaToggle("Humanizar (delays random)", pags[3], "Hum", true, function(v) CFG.Seguridad.Humanizar = v end)
filaSlider("Rate Limit", pags[3], 4, 30, CFG.Seguridad.RateLimit, function(v) CFG.Seguridad.RateLimit = v end)
filaToggle("Caminar (no teleport)", pags[3], "NoTP", true, function(v) CFG.Seguridad.CaminarNoTP = v end)
filaToggle("Anti-AFK", pags[3], "AFK", true, function(v) CFG.Seguridad.AntiAFK = v end)
filaToggle("Respetar carga (speed)", pags[3], "Rsp", true, function(v) CFG.Velocidad.RespetarCarga = v end)
filaToggle("GUI en CoreGui (invisible)", pags[3], "Core", true, function(v)
    moverGUI(v and "coregui" or "playergui")
end)

local btnOcultar = nuevo("TextButton", {
    Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(31, 22, 48),
    BorderSizePixel = 0, Text = "OCULTAR PANEL", Font = Enum.Font.GothamBold,
    TextSize = 9, TextColor3 = Color3.fromRGB(201, 169, 255), AutoButtonColor = false,
}, pags[3])
curva(btnOcultar, 6)
contorno(btnOcultar, Color3.fromRGB(138, 60, 255), 1, 0.25)

seleccionar(1)

local estado = nuevo("TextLabel", {
    Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 1, -22),
    BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 9,
    Text = "STXRLY NEW v" .. VERSION, TextColor3 = Color3.fromRGB(107, 107, 120),
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local reabrir = nuevo("TextButton", {
    Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 12, 0, MOVIL and 56 or 30),
    BackgroundColor3 = Color3.fromRGB(13, 13, 15), BorderSizePixel = 0,
    Text = "S", Font = Enum.Font.GothamBlack, TextSize = 15,
    TextColor3 = Color3.fromRGB(255, 40, 40), AutoButtonColor = false, Visible = false,
}, gui)
curva(reabrir, 19)
contorno(reabrir, Color3.fromRGB(138, 60, 255), 1.5, 0.1)

reabrir.MouseButton1Click:Connect(function()
    reabrir.Visible = false
    panel.Visible = true
end)
btnCerrar.MouseButton1Click:Connect(function()
    panel.Visible = false
    reabrir.Visible = true
end)
btnOcultar.MouseButton1Click:Connect(function()
    panel.Visible = false
    reabrir.Visible = true
end)

local colapsado = false
btnMin.MouseButton1Click:Connect(function()
    colapsado = not colapsado
    for _, c in ipairs(panel:GetChildren()) do
        if c:IsA("GuiObject") and c ~= barra then c.Visible = not colapsado end
    end
    if not colapsado then seleccionar(tabActual) end
    panel.Size = UDim2.fromOffset(ANCHO, colapsado and 40 or ALTO)
end)

local function notificar(txt)
    local n = nuevo("TextLabel", {
        Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, 76),
        BackgroundColor3 = Color3.fromRGB(31, 22, 48), BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 9, Text = txt,
        TextColor3 = Color3.fromRGB(201, 169, 255),
        TextTransparency = 1, BackgroundTransparency = 1, ZIndex = 5,
    }, panel)
    curva(n, 6)
    task.spawn(function()
        for i = 0, 1, 0.1 do
            n.TextTransparency = 1 - i; n.BackgroundTransparency = 1 - i
            task.wait(0.02)
        end
        task.wait(2)
        for i = 1, 0, -0.1 do
            n.TextTransparency = 1 - i; n.BackgroundTransparency = 1 - i
            task.wait(0.02)
        end
        n:Destroy()
    end)
end

moverGUI("coregui")
GENV.STXRLY_NEW = { gui = gui, version = VERSION }
paso("UI lista")

--== [10] ANTI-AFK =====================================================
LP.Idled:Connect(function()
    if not CFG.Seguridad.AntiAFK then return end
    pcall2(function()
        VU:CaptureController()
        VU:ClickButton2(Vector2.new(0, 0))
    end)
end)

--== [11] BUCLES =======================================================
guardarBase()
task.spawn(function() while task.wait(2) do if not vivo() then return end; guardarBase() end end)

task.spawn(function()
    while true do
        esperar(0.2)
        if not vivo() then return end
        if S.EggCollector then
            if cargando() then
                if S.AutoPlace then colocarHuevo() end
            else
                local h = mejorHuevo()
                if h then
                    irA(h.parte.Position, 8)
                    esperar(0.15)
                    fire("steal"); esperar(0.2)
                    fire("grab")
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        esperar(2)
        if not vivo() then return end
        if S.AutoOpenPlace then
            abrirHuevos()
            esperar(0.5)
            equiparMejor()
        end
    end
end)

task.spawn(function()
    while true do
        esperar(1.5)
        if not vivo() then return end
        if S.AutoTreadmill and not cargando() then subirTreadmill() end
    end
end)

task.spawn(function()
    while true do
        esperar(3)
        if not vivo() then return end
        if S.AutoMutFav then aplicarMutacionFav() end
    end
end)

task.spawn(function()
    local t = 0
    while true do
        esperar(1)
        if not vivo() then return end
        if not S.ServerHop then
            t = 0
        else
            local h = mejorHuevo()
            local p = h and h.precio or 0
            if p >= CFG.Servidor.UmbralBuenHuevo then
                t = 0
            else
                t = t + 1
                if t >= CFG.Servidor.TiempoParaHop then
                    notificar("Server hop: buscando mejores huevos")
                    esperar(0.4)
                    hop()
                    return
                end
            end
        end
    end
end)

RunSrv.Heartbeat:Connect(function()
    if vivo() and S.SpeedBoost then aplicarVelocidad() end
end)

task.spawn(function()
    while true do
        esperar(1)
        if not vivo() then return end
        local h = mejorHuevo()
        estado.Text = h
            and ("mejor huevo: " .. h.nombre .. "  ·  " .. tostring(h.precio))
            or ("STXRLY NEW v" .. VERSION)
    end
end)

notificar("STXRLY NEW v" .. VERSION .. " cargado")
paso("bucles activos")

--== [12] ENCRIPTADOR ==================================================
local B64C = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function xorStr(d, k)
    local o = {}
    for i = 1, #d do
        o[i] = string.char(bit32.bxor(string.byte(d, i), string.byte(k, (i - 1) % #k + 1)))
    end
    return table.concat(o)
end

local function b64enc(d)
    local o, b = {}, { string.byte(d, 1, #d) }
    for i = 1, #b, 3 do
        local x, y, z = b[i], b[i + 1], b[i + 2]
        local n1 = math.floor(x / 4)
        local n2 = (x % 4) * 16 + math.floor((y or 0) / 16)
        local n3 = ((y or 0) % 16) * 4 + math.floor((z or 0) / 64)
        local n4 = (z or 0) % 64
        o[#o + 1] = B64C:sub(n1 + 1, n1 + 1) .. B64C:sub(n2 + 1, n2 + 1)
            .. (y and B64C:sub(n3 + 1, n3 + 1) or "=")
            .. (z and B64C:sub(n4 + 1, n4 + 1) or "=")
    end
    return table.concat(o)
end

function ENCRYPT(entrada, salida)
    entrada = entrada or "STXRLY_NEW.lua"
    salida  = salida  or "STXRLY_NEW.enc"
    if not (readfile and writefile) then return warn("[STXRLY NEW] Falta readfile/writefile") end
    local ok, src = pcall(readfile, entrada)
    if not ok then return warn("[STXRLY NEW] No encontre " .. entrada) end
    local data = b64enc(xorStr(src, "STXRLY_NEW_KEY_2026"))
    local lineas = {}
    for i = 1, #data, 120 do lineas[#lineas + 1] = data:sub(i, i + 119) end
    writefile(salida, table.concat(lineas, "\n"))
    print(("[STXRLY NEW] Cifrado -> %s (%d KB)"):format(salida, math.floor(#data / 1024)))
    return salida
end

print("[STXRLY NEW] v" .. VERSION .. " cargado. ENCRYPT() genera el .enc")