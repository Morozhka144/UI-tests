--[[
    Murder Mystery 2 - MoroElite UI Edition
    ESP / Aimbot / Bullet Homing / Auto Shoot / Murderer tools / Movement / Visuals / Skins
--]]

local function SafeLoad()
    local cache = "MoroElite.lua"
    local function run(src, origin)
        local fn, err = loadstring(src)
        if not fn then warn("[Moro MM2] MoroElite compile error (" .. origin .. "): " .. tostring(err)) return nil end
        local ok, lib = pcall(fn)
        if not ok or not lib then warn("[Moro MM2] MoroElite init error (" .. origin .. "): " .. tostring(lib)) return nil end
        return lib
    end

    local function hasSubTab(src) return src:find("function Tab:SubTab", 1, true) ~= nil end

    local url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/MoroElite.lua"
    local ok, content = pcall(function() return game:HttpGet(url) end)
    local cached = isfile and isfile(cache) and readfile(cache) or nil
    -- prefer whichever copy has sub-tab support; GitHub wins a tie
    if ok and type(content) == "string" and #content > 1000 and not (cached and hasSubTab(cached) and not hasSubTab(content)) then
        local lib = run(content, "GitHub")
        if lib then
            if writefile then pcall(writefile, cache, content) end
            return lib
        end
    elseif not ok then
        warn("[Moro MM2] Could not download MoroElite: " .. tostring(content))
    end

    if cached then
        return run(cached, "local cache")
    end
    return nil
end

local Library = SafeLoad()
if not Library then return end

-- MoroVisuals: общая библиотека ESP / PostFX / X-Ray (GitHub first, cache as a fallback)
local function LoadVisuals()
    local cache = "MoroVisuals.lua"
    local function run(src, origin)
        local fn, err = loadstring(src, "=MoroVisuals")
        if not fn then warn("[Moro MM2] MoroVisuals compile error (" .. origin .. "): " .. tostring(err)) return nil end
        local ok, lib = pcall(fn)
        if not ok or not lib then warn("[Moro MM2] MoroVisuals init error (" .. origin .. "): " .. tostring(lib)) return nil end
        return lib
    end
    local url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/MoroVisuals.lua"
    local ok, content = pcall(function() return game:HttpGet(url) end)
    if ok and type(content) == "string" and #content > 1000 then
        local lib = run(content, "GitHub")
        if lib then
            if writefile then pcall(writefile, cache, content) end
            return lib
        end
    end
    if isfile and isfile(cache) then return run(readfile(cache), "local cache") end
    return nil
end
local V = LoadVisuals()
if not V then warn("[Moro MM2] MoroVisuals could not be loaded") return end

if _G.__MM2Cleanup then pcall(_G.__MM2Cleanup) end

--=====================================================================--
--                              CORE / HELPERS                         --
--=====================================================================--
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local alive = true
local conns, cleanups = {}, {}
local function track(c) conns[#conns + 1] = c return c end
local function onCleanup(fn) cleanups[#cleanups + 1] = fn end
local function safe(fn, ...) local ok, a, b = pcall(fn, ...) if ok then return a, b end return nil end
local function rainbowAt(t, off) return Color3.fromHSV((t * 0.3 + (off or 0)) % 1, 0.8, 1) end
local function dbg() end

local overlayParent = (gethui and gethui()) or game:GetService("CoreGui")
local overlay = Instance.new("ScreenGui")
overlay.Name = "MM2Overlay"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 50
overlay.Parent = overlayParent
onCleanup(function() overlay:Destroy() end)

local espFolder = Instance.new("Folder")
espFolder.Name = "MM2ESP"
espFolder.Parent = overlayParent
onCleanup(function() espFolder:Destroy() end)

local CR = safe(function() return require(RS:WaitForChild("Modules", 5):WaitForChild("CurrentRoundClient", 5)) end)
local WeaponService = safe(function() return require(RS:WaitForChild("ClientServices", 5):WaitForChild("WeaponService", 5)) end)

local function char(p) return p and p.Character end
local function hrpOf(p) local c = char(p) return c and c:FindFirstChild("HumanoidRootPart") end
local function humOf(p) local c = char(p) return c and c:FindFirstChildOfClass("Humanoid") end

local function pdata(p)
    return CR and CR.PlayerData and CR.PlayerData[p.Name]
end

local function visAlive(p)
    local h = humOf(p)
    return h ~= nil and h.Health > 0
end

local function isAlive(p)
    local h = humOf(p)
    if not h or h.Health <= 0 then return false end
    local d = pdata(p)
    if d and d.Dead then return false end
    return true
end

local function findTool(p, name)
    local c = char(p)
    local bp = p:FindFirstChild("Backpack")
    local toys = bp and bp:FindFirstChild("Toys")
    return (c and c:FindFirstChild(name)) or (bp and bp:FindFirstChild(name)) or (toys and toys:FindFirstChild(name))
end

-- "Murderer" / "Sheriff" / "Hero" / "Innocent" / "Lobby"
local function getRole(p)
    local d = pdata(p)
    local role = d and d.Role
    if role == "Murderer" then return "Murderer" end
    if role == "Sheriff" then return "Sheriff" end
    if findTool(p, "Knife") then return "Murderer" end
    if findTool(p, "Gun") then return role and "Hero" or "Sheriff" end
    if role then return role == "Innocent" and "Innocent" or role end
    return "Lobby"
end

local ROLE_COLORS = {
    Murderer = Color3.fromRGB(255, 60, 60),
    Sheriff = Color3.fromRGB(60, 140, 255),
    Hero = Color3.fromRGB(255, 220, 60),
    Innocent = Color3.fromRGB(80, 230, 120),
    Lobby = Color3.fromRGB(220, 220, 220),
}

local function notify(title, text, kind, dur)
    task.spawn(function()
        pcall(function()
            Library.Window:Notify({ Title = title, Text = text, Type = kind or "info", Duration = dur or 3 })
        end)
    end)
end

local function findByRole(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if getRole(p) == role then return p end
    end
end

local function mapModel()
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("Model") and not Players:GetPlayerFromCharacter(c) and (c:FindFirstChild("CoinContainer") or c:FindFirstChild("Spawns")) and c.Name ~= "Lobby" then
            return c
        end
    end
end

local function gunDrop()
    local d = workspace:FindFirstChild("GunDrop")
    if d then return d end
    local m = mapModel()
    return m and m:FindFirstChild("GunDrop")
end

local function equip(tool)
    local c = lp.Character
    local h = humOf(lp)
    if tool and h and c and tool.Parent ~= c then pcall(function() h:EquipTool(tool) end) end
end

local function tpTo(cf)
    local r = hrpOf(lp)
    if r then
        r.CFrame = cf
        r.AssemblyLinearVelocity = Vector3.zero
    end
end

--=====================================================================--
--                              SETTINGS                               --
--=====================================================================--
local S = {
    -- esp
    esp = false, espNames = true, espDist = true, espHealth = true, espRoleOnly = false, espBox = false,
    espFill = 0.6, espTracers = false, espGun = true, espCoins = false, roleNotify = true,
    -- aim
    aimbot = false, aimMode = "Auto", aimPart = "Head", aimKey = "Hold RMB", aimFov = 150,
    aimSmooth = 20, aimWall = true, predict = 0.08, showFov = true,
    silent = false, silentFov = 400, silentWall = false,
    autoShoot = false, shootDelay = 1.3, shootRange = 250, shootWall = true,
    -- murderer
    killAura = false, killRange = 14, killDelay = 0.9, killAll = false,
    throwAura = false, throwRange = 70, throwDelay = 1.2,
    autoGun = false,
    -- movement
    speed = false, speedVal = 24, jump = false, jumpVal = 60, infJump = false, noclip = false,
    fly = false, flySpeed = 60, antiVoid = true,
    bhop = false, bhopMode = "Hold Space", bhopMax = 45, bhopStep = 3, hopCur = 16, hopT = 0, bhopJump = 50, hip = false, hipVal = 4, grav = false, gravVal = 196,
    -- visuals
    fullbright = false, fovOn = false, fovVal = 90, xray = false, crosshair = false, noFog = false,
}

-- per-role combat profiles: the one that matches your current role is copied into S every frame,
-- so all aim / auto-attack logic keeps reading S and only the menu knows about the two roles
local P, syncProfile
do
local PROFILE_DEFAULTS = {
    aimbot = false, aimKey = "Hold RMB", aimMode = "Anyone", aimPart = "Head", aimFov = 150, aimSmooth = 20, aimWall = true,
    predict = 0.08, showFov = true, silent = false, silentFov = 400, silentWall = false,
}
local function newProfile(extra)
    local p = {}
    for k, v in pairs(PROFILE_DEFAULTS) do p[k] = v end
    for k, v in pairs(extra) do p[k] = v end
    return p
end
P = {
    Murderer = newProfile({ aimMode = "Anyone", wallbang = false, wbMode = "Close Range", wbOffset = 4, wbManual = false, throwWall = true, holster = true, holsterDelay = 0.3, stabHolster = true, stabHolsterDelay = 0.3, killAura = false, killRange = 14, killDelay = 0.9, killAll = false, throwAura = false, throwRange = 70, throwDelay = 1.2, throwSpeed = 100 }),
    Sheriff = newProfile({ aimMode = "Murderer", wallbang = false, wbMode = "Close Range", wbOffset = 4, wbManual = false, autoShoot = false, shootDelay = 1.3, shootRange = 250, shootWall = true, autoGun = false, grabMode = "Remote", holster = true, holsterDelay = 0.3 }),
}
local SHARED_KEYS = { "aimbot", "aimKey", "aimMode", "aimPart", "aimFov", "aimSmooth", "aimWall", "predict", "showFov", "silent", "silentFov", "silentWall" }
syncProfile = function()
    local role = getRole(lp)
    local isM = role == "Murderer"
    local isS = role == "Sheriff" or role == "Hero"
    local src = isM and P.Murderer or P.Sheriff
    for _, k in ipairs(SHARED_KEYS) do S[k] = src[k] end
    if not (isM or isS) then S.aimbot, S.silent = false, false end
    local m, sh = P.Murderer, P.Sheriff
    S.killAura, S.killRange, S.killDelay = isM and m.killAura, m.killRange, m.killDelay
    S.killAll = isM and m.killAll
    S.throwAura, S.throwRange, S.throwDelay = isM and m.throwAura, m.throwRange, m.throwDelay
    S.autoShoot, S.shootDelay, S.shootRange, S.shootWall = isS and sh.autoShoot, sh.shootDelay, sh.shootRange, sh.shootWall
    S.autoGun = (not isM) and sh.autoGun   -- innocents need the gun grab most of all
    S.grabMode = sh.grabMode
    -- wallbang works the same way for both roles: shots for the sheriff, knife throws for the murderer
    local wp = isM and m or sh
    S.wallbang, S.wbMode, S.wbOffset, S.wbManual = (isM or isS) and wp.wallbang, wp.wbMode, wp.wbOffset, (isM or isS) and wp.wbManual
    S.throwWall = m.throwWall
    S.stabHolster, S.stabHolsterDelay = isM and m.stabHolster, m.stabHolsterDelay
    S.holster, S.holsterDelay = (isM or isS) and wp.holster, wp.holsterDelay
end
end

--=====================================================================--
--                               TARGETING                             --
--=====================================================================--
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function visible(part)
    local origin = cam.CFrame.Position
    rayParams.FilterDescendantsInstances = { lp.Character, part.Parent }
    return workspace:Raycast(origin, part.Position - origin, rayParams) == nil
end

local function aimPartOf(p)
    local c = char(p)
    if not c then return nil end
    if S.aimPart == "Head" then return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart") end
    if S.aimPart == "Torso" then return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart") end
    return c:FindFirstChild("HumanoidRootPart")
end

local function predicted(part)
    local v = part.AssemblyLinearVelocity
    if v.Magnitude > 120 then v = Vector3.zero end
    return part.Position + v * S.predict
end

local function candidates(mode)
    local list = {}
    local myRole = getRole(lp)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and isAlive(p) and hrpOf(p) then
            local role = getRole(p)
            local ok
            if mode == "Murderer" then ok = role == "Murderer"
            elseif mode == "Sheriff" then ok = role == "Sheriff" or role == "Hero"
            elseif mode == "Anyone" then ok = true
            else ok = (myRole == "Murderer") or role == "Murderer" end
            if ok then list[#list + 1] = p end
        end
    end
    return list
end

local function screenCenter()
    -- on a touch device there is no mouse pointer: the crosshair is the middle of the screen
    if UIS.PreferredInput == Enum.PreferredInput.Touch or UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
        return cam.ViewportSize / 2
    end
    return UIS:GetMouseLocation()
end

local function getTarget(fov, wall, mode, center)
    local best, bestD, bestPart
    center = center or screenCenter()
    for _, p in ipairs(candidates(mode)) do
        local part = aimPartOf(p)
        if part then
            local sp, on = cam:WorldToViewportPoint(part.Position)
            if on then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d <= fov and (not bestD or d < bestD) and (not wall or visible(part)) then
                    best, bestD, bestPart = p, d, part
                end
            end
        end
    end
    return best, bestPart
end

local function nearestTarget(maxDist, wall, mode)
    local r = hrpOf(lp)
    if not r then return nil end
    local best, bestD, bestPart
    for _, p in ipairs(candidates(mode)) do
        local part = aimPartOf(p)
        if part then
            local d = (part.Position - r.Position).Magnitude
            if d <= maxDist and (not bestD or d < bestD) and (not wall or visible(part)) then
                best, bestD, bestPart = p, d, part
            end
        end
    end
    return best, bestPart
end

--=====================================================================--
--                         SILENT AIM (WeaponService hook)             --
--=====================================================================--
local origGetMouse
local lastAim = { pos = nil, t = 0 }
if WeaponService and WeaponService.GetMouseTargetCFrame then
    origGetMouse = WeaponService.GetMouseTargetCFrame
    local ok = pcall(function()
        WeaponService.GetMouseTargetCFrame = function(self, ...)
            local res
            if S.silent and alive then
                local p, part = getTarget(S.silentFov, S.silentWall, S.aimMode)
                if p and part then res = CFrame.new(predicted(part)) end
            end
            res = res or origGetMouse(self, ...)
            lastAim.pos, lastAim.t = res.Position, os.clock()
            return res
        end
    end)
    if not ok then origGetMouse = nil end
    onCleanup(function()
        if origGetMouse then pcall(function() WeaponService.GetMouseTargetCFrame = origGetMouse end) end
    end)
end
-- phones: a tap in the world goes through GetTargetPosition(x, y); the target is picked around the tap point
local origGetPos
if WeaponService and WeaponService.GetTargetPosition then
    origGetPos = WeaponService.GetTargetPosition
    local ok2 = pcall(function()
        WeaponService.GetTargetPosition = function(self, x, y, ...)
            local res
            if S.silent and alive and typeof(x) == "number" and typeof(y) == "number" then
                local p, part = getTarget(S.silentFov, S.silentWall, S.aimMode, Vector2.new(x, y))
                if p and part then res = CFrame.new(predicted(part)) end
            end
            res = res or origGetPos(self, x, y, ...)
            lastAim.pos, lastAim.t = res.Position, os.clock()
            return res
        end
    end)
    if not ok2 then origGetPos = nil end
    onCleanup(function()
        if origGetPos then pcall(function() WeaponService.GetTargetPosition = origGetPos end) end
    end)
end

--=====================================================================--
--                         FOV CIRCLE / CROSSHAIR                      --
--=====================================================================--
local fovFrame = Instance.new("Frame")
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.BackgroundTransparency = 1
fovFrame.Visible = false
fovFrame.Parent = overlay
do
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = fovFrame
    local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(255, 255, 255) st.Thickness = 1.2 st.Transparency = 0.35 st.Parent = fovFrame
end

local crossFrame = Instance.new("Frame")
crossFrame.AnchorPoint = Vector2.new(0.5, 0.5)
crossFrame.Size = UDim2.fromOffset(4, 4)
crossFrame.Position = UDim2.fromScale(0.5, 0.5)
crossFrame.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
crossFrame.BorderSizePixel = 0
crossFrame.Visible = false
crossFrame.Parent = overlay
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = crossFrame end

--=====================================================================--
--                                  ESP                                --
--=====================================================================--
local E, syncESP   -- меню читает E; остальное мост к MoroVisuals живёт в do-блоке (лимит 200 локалов)
do
E = {
    on = false, maxDist = 1500, filter = "All players", colorMode = "Role", staticColor = Color3.new(1, 1, 1),
    visCheck = false, fade = true,
    box = "Rounded Glow", boxThick = 1.6, boxFill = 88,
    name = true, nameStyle = "Pill", textSize = 13, roleTag = true, dist = true, weapon = true,
    hpBar = true, hpText = true,
    skeleton = true, skelThick = 1.4, headDot = true, look = true,
    tracer = true, tracerFrom = "Bottom", tracerThick = 1.2,
    arrows = true, arrowRadius = 0.38,
    chams = "Flat", chamMode = "Role", chamVisible = Color3.fromRGB(255, 70, 90), chamHidden = Color3.fromRGB(110, 60, 255), chamAlpha = 0.6,
    gun = true, coins = false, outline = true, fill = true, tag = true, coinMax = 250,
    gunCol = Color3.fromRGB(255, 220, 60), coinCol = Color3.fromRGB(255, 160, 40),
}

local function roleVisible(role)
    if E.filter == "Murderer + Sheriff" then return role == "Murderer" or role == "Sheriff" or role == "Hero" end
    if E.filter == "Murderer only" then return role == "Murderer" end
    return true
end

local function espColor(p, role, t)
    if E.colorMode == "Rainbow" then return rainbowAt(t, (p.UserId % 100) / 100) end
    if E.colorMode == "Static" then return E.staticColor end
    return ROLE_COLORS[role] or ROLE_COLORS.Lobby
end

-- Сам рендер (боксы, скелет, хамсы, трейсеры, стрелки) живёт в MoroVisuals; здесь только роли MM2.
local ESP = V.ESP
onCleanup(function() pcall(V.Unload) end)

local roleMemo = setmetatable({}, { __mode = "k" })
local function roleOf(p)
    local m = roleMemo[p]
    local now = os.clock()
    if m and now - m.t < 0.1 then return m.r end
    local r = getRole(p)
    roleMemo[p] = { t = now, r = r }
    return r
end

local trackingOn = false
local function startTracking()
    ESP:TrackPlayers({
        Filter = function(p) return roleVisible(roleOf(p)) end,
        Color = function(p, t) return espColor(p, roleOf(p), t) end,
        Text = function(p) return E.name and p.DisplayName or "" end,
        Tag = function(p)
            if not E.roleTag then return nil end
            local r = roleOf(p)
            if r ~= "Lobby" and r ~= "Innocent" then return r end
        end,
        Info = function(p)
            if not E.weapon then return nil end
            local role = roleOf(p)
            local tool = p.Character and p.Character:FindFirstChildOfClass("Tool")
            local wn = tool and tool.Name or (role == "Murderer" and "Knife") or ((role == "Sheriff" or role == "Hero") and "Gun") or ""
            return wn ~= "" and wn or nil
        end,
    })
end

-- настройки меню (E) -> движок; вызывается каждый кадр, это просто запись в таблицу
function syncESP()
    if E.on ~= trackingOn then
        trackingOn = E.on
        if E.on then startTracking() else ESP:StopTrackingPlayers() end
    end
    local s = ESP.Settings
    ESP.MaxDistance = E.maxDist
    ESP.Tracers = E.tracer
    s.box, s.boxThick, s.boxFill = E.box, E.boxThick, E.boxFill / 100
    s.nameStyle, s.textSize, s.showDist = E.nameStyle, E.textSize, E.dist
    s.hpBar, s.hpText = E.hpBar, E.hpText
    s.skeleton, s.skelThick, s.headDot, s.lookLine = E.skeleton, E.skelThick, E.headDot, E.look
    s.distFade, s.visCheck = E.fade, E.visCheck
    s.tracerFrom, s.tracerThick = E.tracerFrom, E.tracerThick
    s.arrows = E.arrows
    local vs = cam.ViewportSize
    s.arrowRadius = E.arrowRadius * math.min(vs.X, vs.Y)
    if E.on and E.chams ~= "Off" then
        if E.chams == "Outline Glow" then s.chamsMode, s.chams = "Highlight", "Glow"
        else s.chamsMode, s.chams = "Dual", E.chams end
    else
        s.chams = "Off"
    end
    s.chamMode = E.chamMode == "Custom" and "Custom" or "Object"
    s.chamVisible, s.chamHidden, s.chamAlpha = E.chamVisible, E.chamHidden, E.chamAlpha
end

-- world ESP: пистолет и монеты тоже идут через движок ---------------------------
local world = {}
local function worldAdd(inst, labelFn, colorFn, maxD)
    if not world[inst] then
        world[inst] = true
        ESP:AddESP({
            Object = inst, Text = "", TextFn = labelFn, ColorFn = colorFn,
            NoTracer = true, NoArrow = true,
        })
    end
    ESP.ObjectMaxDistance[inst] = maxD
end
local function worldRemove(inst)
    if world[inst] then
        world[inst] = nil
        ESP:RemoveESP(inst)
        ESP.ObjectMaxDistance[inst] = nil
    end
end
onCleanup(function() for i in pairs(world) do worldRemove(i) end end)

local lastDropSeen = false
task.spawn(function()
    while alive do
        local me = hrpOf(lp)
        local keep = {}
        local drop = gunDrop()
        if drop and not lastDropSeen and S.roleNotify then notify("Gun dropped", "The sheriff is dead - grab the gun", "warning", 4) end
        lastDropSeen = drop ~= nil

        if E.gun and drop then
            keep[drop] = true
            worldAdd(drop,
                function() return E.tag and "GUN" or "" end,
                function(t) return E.gunCol:Lerp(Color3.new(1, 1, 1), (math.sin(t * 4) + 1) * 0.15) end,
                5000)
        end

        if E.coins and me then
            local map = mapModel()
            local cc = map and map:FindFirstChild("CoinContainer")
            if cc then
                local list = {}
                for _, coin in ipairs(cc:GetChildren()) do
                    if coin:IsA("BasePart") then
                        list[#list + 1] = { coin = coin, dist = (coin.Position - me.Position).Magnitude }
                    end
                end
                table.sort(list, function(a, b) return a.dist < b.dist end)
                -- каждый объект движка стоит ~35 фреймов, поэтому только ближайшие
                for rank = 1, math.min(#list, 15) do
                    local coin = list[rank].coin
                    local id = tostring(coin:GetAttribute("CoinID") or "Coin")
                    keep[coin] = true
                    worldAdd(coin,
                        function() return E.tag and id or "" end,
                        function() return id == "Candy" and E.coinCol or Color3.fromRGB(255, 205, 70) end,
                        E.coinMax)
                end
            end
        end
        for inst in pairs(world) do
            if not keep[inst] or not inst.Parent then worldRemove(inst) end
        end
        task.wait(0.2)
    end
end)
end -- MoroVisuals bridge

-- ESP + aim / fov rendering
track(RunService.RenderStepped:Connect(function()
    cam = workspace.CurrentCamera
    syncProfile()
    local vs = cam.ViewportSize
    -- FOV circle
    local radius = S.silent and math.max(S.silentFov, S.aimbot and S.aimFov or 0) or S.aimFov
    fovFrame.Visible = S.showFov and (S.aimbot or S.silent)
    fovFrame.Size = UDim2.fromOffset(radius * 2, radius * 2)
    local c = screenCenter()
    fovFrame.Position = UDim2.fromOffset(c.X, c.Y)
    crossFrame.Visible = S.crosshair
    if S.fovOn then cam.FieldOfView = S.fovVal end

    pcall(syncESP)

    -- aimbot
    if S.aimbot then
        -- there is no right mouse button on a phone: the aimbot is simply always on there
        local pressed = S.aimKey == "Always" or UIS.PreferredInput == Enum.PreferredInput.Touch or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if pressed then
            local p, part = getTarget(S.aimFov, S.aimWall, S.aimMode)
            if p and part then
                local goal = CFrame.lookAt(cam.CFrame.Position, predicted(part))
                local alpha = math.clamp(1 - S.aimSmooth / 100, 0.03, 1)
                cam.CFrame = cam.CFrame:Lerp(goal, alpha)
            end
        end
    end
end))
onCleanup(function() fovFrame:Destroy() crossFrame:Destroy() end)

--=====================================================================--
--                           ROLE NOTIFIER                              --
--=====================================================================--
local lastSig = ""
local function checkRoles()
    local m, s = findByRole("Murderer"), findByRole("Sheriff")
    local sig = (m and m.Name or "-") .. "|" .. (s and s.Name or "-")
    if sig ~= lastSig and (m or s) then
        lastSig = sig
        if S.roleNotify then
            notify("Round roles", "Murderer: " .. (m and m.DisplayName or "?") .. "  |  Sheriff: " .. (s and s.DisplayName or "?"), "info", 6)
        end
        if F.sndPlay then F.sndPlay("role") end
    elseif not m and not s then
        lastSig = ""
    end
end
if CR and CR.PlayerDataChanged then
    track(CR.PlayerDataChanged.Event:Connect(function() task.defer(checkRoles) end))
end
task.spawn(function() while alive do pcall(checkRoles) task.wait(2) end end)

--=====================================================================--
--                              COMBAT LOGIC                            --
--=====================================================================--
-- Auto Shoot / Auto Throw: after the shot the weapon goes back into the backpack (a short delay lets the shot reach the server)
local function holsterAfter(toolName, on, delay)
    if not on then return end
    task.delay(delay or 0.3, function()
        local c, h = lp.Character, humOf(lp)
        if c and h and c:FindFirstChild(toolName) then pcall(function() h:UnequipTools() end) end
    end)
end
local function holsterAfterShot(toolName) holsterAfter(toolName, S.holster, S.holsterDelay) end

-- wallbang: the shot origin is moved next to the target so no wall lies between the muzzle and the player
local function spoofOrigin(targetPos)
    local head = lp.Character and lp.Character:FindFirstChild("Head")
    local mine = hrpOf(lp)
    local from = head and head.Position or (mine and mine.Position) or targetPos
    local origin
    if S.wbMode == "Overhead" then
        origin = targetPos + Vector3.new(0, S.wbOffset, 0)
    else
        local dir = targetPos - from
        origin = dir.Magnitude > 0.1 and (targetPos - dir.Unit * math.min(S.wbOffset, dir.Magnitude)) or from
    end
    return CFrame.lookAt(origin, targetPos)
end

-- calls the game makes itself (gun Shoot / knife KnifeThrown): the bullet tracer is drawn from the real arguments, and
-- with Wallbang's "Manual Shots" on they are rewritten before they reach the server
_G.__MM2ShootHook = function(remote, origin, target)
    local na, nb
    if S.wallbang and S.wbManual then
        local p, part = getTarget(math.max(S.silentFov, 300), false, S.aimMode)
        if p and part then
            local pos = predicted(part)
            na, nb = spoofOrigin(pos), CFrame.new(pos)
            dbg("Manual " .. tostring(remote.Name) .. " rewritten -> " .. p.Name)
        end
    end
    local o, t = na or origin, nb or target
    if typeof(o) == "CFrame" and typeof(t) == "CFrame" and _G.__MM2OnShot then
        pcall(_G.__MM2OnShot, o.Position, t.Position)
    end
    return na, nb
end
_G.__MM2ThrowHook = _G.__MM2ShootHook
onCleanup(function() _G.__MM2ShootHook, _G.__MM2ThrowHook = nil, nil end)
if hookmetamethod and getnamecallmethod and newcclosure and checkcaller and not _G.__MM2NamecallHooked then
    _G.__MM2NamecallHooked = true
    local oldNc
    oldNc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if getnamecallmethod() == "FireServer" and typeof(self) == "Instance" and not checkcaller() then
            local n = self.Name
            local fn = (n == "Shoot" and _G.__MM2ShootHook) or (n == "KnifeThrown" and _G.__MM2ThrowHook) or nil
            if fn then
                local a, b = ...
                local ok, na, nb = pcall(fn, self, a, b)
                if ok and na then return oldNc(self, na, nb) end
            end
        end
        return oldNc(self, ...)
    end))
end

-- confirms hits in the debug log (the server tells every client about a kill)
do
    local gp = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Gameplay")
    local ke = gp and gp:FindFirstChild("KillEvent")
    if ke then
        track(ke.OnClientEvent:Connect(function(...)
            local t = {}
            for i, v in ipairs({ ... }) do t[#t + 1] = tostring(v) end
            dbg("KillEvent " .. table.concat(t, " | "))
        end))
    end
end

-- sheriff auto shoot
task.spawn(function()
    while alive do
        if S.autoShoot then
            pcall(function()
                local gun = findTool(lp, "Gun")
                local r = hrpOf(lp)
                if not (gun and r and isAlive(lp)) then return end
                local mode = (S.aimMode == "Anyone") and "Anyone" or "Murderer"
                local p, part = nearestTarget(S.shootRange, S.shootWall and not S.wallbang, mode)
                if p and part then
                    equip(gun)
                    task.wait(0.05)
                    local att = r:FindFirstChild("GunRaycastAttachment")
                    local aimAt = predicted(part)
                    local originCF = att and att.WorldCFrame or r.CFrame
                    if S.wallbang then originCF = spoofOrigin(aimAt) end
                    gun.Shoot:FireServer(originCF, CFrame.new(aimAt))
                    dbg("AutoShoot -> " .. p.Name .. (S.wallbang and " (wallbang)" or ""))
                    if _G.__MM2OnShot then pcall(_G.__MM2OnShot, originCF.Position, aimAt) end
                    holsterAfterShot("Gun")
                    task.wait(S.shootDelay)
                end
            end)
        end
        task.wait(0.05)
    end
end)

local function stab(target)
    local knife = findTool(lp, "Knife")
    if not knife then return false end
    equip(knife)
    local ev = knife:FindFirstChild("Events")
    local tr = target and hrpOf(target)
    if not (ev and tr) then return false end
    ev.KnifeStabbed:FireServer()
    ev.HandleTouched:FireServer(tr)
    local handle = knife:FindFirstChild("Handle")
    if firetouchinterest and handle then
        pcall(firetouchinterest, handle, tr, 0)
        pcall(firetouchinterest, handle, tr, 1)
    end
    return true
end

-- murderer kill aura (range)
task.spawn(function()
    while alive do
        if S.killAura and getRole(lp) == "Murderer" and isAlive(lp) then
            pcall(function()
                local r = hrpOf(lp)
                if not r then return end
                local did = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= lp and isAlive(p) then
                        local t = hrpOf(p)
                        if t and (t.Position - r.Position).Magnitude <= S.killRange then
                            stab(p)
                            did = true
                        end
                    end
                end
                if did then
                    holsterAfter("Knife", S.stabHolster, S.stabHolsterDelay)
                    task.wait(S.killDelay)
                end
            end)
        end
        task.wait(0.1)
    end
end)

-- kill all (teleport to each victim)
local killAllBusy = false
local function runKillAll()
    if killAllBusy or getRole(lp) ~= "Murderer" then return end
    killAllBusy = true
    local r = hrpOf(lp)
    local home = r and r.CFrame
    for _, p in ipairs(Players:GetPlayers()) do
        if not alive then break end
        if p ~= lp and isAlive(p) and hrpOf(p) then
            local t0 = os.clock()
            while alive and isAlive(p) and isAlive(lp) and hrpOf(p) and os.clock() - t0 < 2.2 do
                tpTo(hrpOf(p).CFrame * CFrame.new(0, 0, 2.2))
                stab(p)
                task.wait(0.35)
            end
        end
    end
    if home and isAlive(lp) then tpTo(home) end
    killAllBusy = false
end
task.spawn(function()
    while alive do
        if S.killAll then pcall(runKillAll) end
        task.wait(0.5)
    end
end)

-- knife throw aura
task.spawn(function()
    while alive do
        if S.throwAura and getRole(lp) == "Murderer" and isAlive(lp) then
            pcall(function()
                local knife = findTool(lp, "Knife")
                local p, part = nearestTarget(S.throwRange, S.throwWall and not S.wallbang, "Anyone")
                if knife and p and part then
                    equip(knife)
                    task.wait(0.05)
                    local handle = knife:FindFirstChild("Handle")
                    if handle then
                        local originCF = handle.CFrame
                        -- the knife needs time to fly: lead the target by (distance / knife speed + one-way ping), solved a few times
                        -- because the flight time depends on where the target will be
                        local v = part.AssemblyLinearVelocity
                        if v.Magnitude > 120 then v = Vector3.zero end
                        v = Vector3.new(v.X, v.Y * 0.4, v.Z)
                        local ping = safe(function() return lp:GetNetworkPing() end) or 0.05
                        local speed = math.max(P.Murderer.throwSpeed or 100, 20)
                        local flight = 0
                        for _ = 1, 4 do
                            flight = ((part.Position + v * flight) - originCF.Position).Magnitude / speed + ping
                        end
                        local aimAt = part.Position + v * flight
                        if S.wallbang then originCF = spoofOrigin(aimAt) end
                        knife.Events.KnifeThrown:FireServer(originCF, CFrame.new(aimAt))
                        dbg("AutoThrow -> " .. p.Name .. (S.wallbang and " (wallbang)" or ""))
                        if _G.__MM2OnShot then pcall(_G.__MM2OnShot, originCF.Position, aimAt) end
                        holsterAfterShot("Knife")
                    end
                    task.wait(S.throwDelay)
                end
            end)
        end
        task.wait(0.1)
    end
end)

-- grab the dropped gun. "Remote": interact with the drop without moving (fires every remote / prompt / click detector it
-- carries and simulates the touch). "Teleport": walk into the gun and come back.
do
    local logged
    local function dropPart(drop)
        return drop and (drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true))
    end
    local function byRemote(drop, part, r)
        for _, d in ipairs(drop:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                pcall(function() d:FireServer() end)
            elseif d:IsA("RemoteFunction") then
                task.spawn(function() pcall(function() d:InvokeServer() end) end)
            elseif d:IsA("ProximityPrompt") and fireproximityprompt then
                pcall(fireproximityprompt, d)
            elseif d:IsA("ClickDetector") and fireclickdetector then
                pcall(fireclickdetector, d)
            end
        end
        if firetouchinterest then
            pcall(firetouchinterest, r, part, 0)
            pcall(firetouchinterest, r, part, 1)
        end
    end
    local function byTeleport(part, r)
        local home = r.CFrame
        tpTo(part.CFrame)
        task.wait(0.35)
        tpTo(home)
    end
    S.grabGun = function(mode)
        local drop = gunDrop()
        local r = hrpOf(lp)
        local part = dropPart(drop)
        if not (part and r) then return false, "No dropped gun" end
        if drop ~= logged then
            logged = drop
            local kids = {}
            for _, d in ipairs(drop:GetDescendants()) do kids[#kids + 1] = d.ClassName .. ":" .. d.Name end
            dbg("GunDrop " .. drop.ClassName .. " attrs=" .. tostring(next(drop:GetAttributes()) ~= nil) .. " children=" .. table.concat(kids, ","))
        end
        if mode == "Teleport" then
            byTeleport(part, r)
        else
            byRemote(drop, part, r)
        end
        return true
    end
    task.spawn(function()
        while alive do
            if S.autoGun and getRole(lp) ~= "Murderer" and visAlive(lp) and not findTool(lp, "Gun") and gunDrop() then
                pcall(S.grabGun, S.grabMode)
                task.wait(1)
            end
            task.wait(0.4)
        end
    end)
end

--=====================================================================--
--                               MOVEMENT                               --
--=====================================================================--
local flyBV
local lastSafe
track(RunService.Heartbeat:Connect(function()
    local h, r = humOf(lp), hrpOf(lp)
    if not (h and r) then return end
    if S.speed then h.WalkSpeed = S.speedVal end
    if S.jump then h.UseJumpPower = true h.JumpPower = S.jumpVal end
    if S.hip then h.HipHeight = S.hipVal end
    if S.grav then workspace.Gravity = S.gravVal end
    if S.bhop then
        local moving = h.MoveDirection.Magnitude > 0.1
        local want = S.bhopMode == "Always" or UIS:IsKeyDown(Enum.KeyCode.Space)
        if want and moving then
            -- one jump per landing: only from the ground states, and never twice within 0.25 s
            -- (the floor is still "touched" for a few frames after take-off, which used to stack the jumps)
            h.UseJumpPower = true
            h.JumpPower = S.bhopJump
            local st = h:GetState()
            local grounded = h.FloorMaterial ~= Enum.Material.Air
                and (st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed or st == Enum.HumanoidStateType.RunningNoPhysics)
            if grounded and os.clock() - S.hopT > 0.25 then
                S.hopT = os.clock()
                S.hopCur = math.min(S.hopCur + S.bhopStep, S.bhopMax)
                h:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            h.WalkSpeed = math.max(S.hopCur, 16)
        else
            S.hopCur = math.max(16, S.hopCur - 1.2)
            h.WalkSpeed = S.speed and S.speedVal or S.hopCur
        end
    end

    if S.fly then
        if not flyBV or flyBV.Parent ~= r then
            if flyBV then flyBV:Destroy() end
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            flyBV.Velocity = Vector3.zero
            flyBV.Parent = r
        end
        local dir = Vector3.zero
        local cf = cam.CFrame
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * S.flySpeed or Vector3.zero
    elseif flyBV then
        flyBV:Destroy()
        flyBV = nil
    end

    if S.antiVoid then
        if r.Position.Y > workspace.FallenPartsDestroyHeight + 150 and h.FloorMaterial ~= Enum.Material.Air then
            lastSafe = r.CFrame
        elseif r.Position.Y < workspace.FallenPartsDestroyHeight + 80 and lastSafe then
            r.AssemblyLinearVelocity = Vector3.zero
            r.CFrame = lastSafe
        end
    end
end))
onCleanup(function() if flyBV then flyBV:Destroy() end end)

track(RunService.Stepped:Connect(function()
    if S.noclip and lp.Character then
        for _, d in ipairs(lp.Character:GetDescendants()) do
            if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end
        end
    end
end))

track(UIS.JumpRequest:Connect(function()
    if S.infJump then
        local h = humOf(lp)
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- anti AFK
track(lp.Idled:Connect(function()
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.zero)
    end)
end))

--=====================================================================--
--                               VISUALS                                --
--=====================================================================--
local lightingBackup
local function applyLighting(on)
    if on then
        if not lightingBackup then
            lightingBackup = {
                Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
            }
        end
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    elseif lightingBackup then
        for k, v in pairs(lightingBackup) do pcall(function() Lighting[k] = v end) end
        lightingBackup = nil
    end
end
local fogBackup
task.spawn(function()
    while alive do
        if S.fullbright then applyLighting(true) end
        if S.noFog then
            if not fogBackup then fogBackup = Lighting.FogEnd end
            Lighting.FogEnd = 1e6
        elseif fogBackup then
            Lighting.FogEnd = fogBackup
            fogBackup = nil
        end
        task.wait(1)
    end
end)
onCleanup(function()
    applyLighting(false)
    if fogBackup then Lighting.FogEnd = fogBackup end
    cam.FieldOfView = 70
end)

local function setXray(on)
    if on then
        V.XRay.Start({
            Roots = function()
                local map = mapModel()
                local base = map and map:FindFirstChild("Base")
                return base and { base } or {}
            end,
            Amount = 0.65, Interval = 3,
        })
    else
        V.XRay.Stop()
    end
end
onCleanup(function() setXray(false) end)

--=====================================================================--
--                         WEAPON SKINS / AVATAR                        --
--=====================================================================--
-- A skin is shown as a separate model welded to your hand (client-side only). It replaces the real knife / gun
-- while you hold it, and can also be shown when you are empty-handed, so it works in the lobby too.
local SK = {
    list = { Knife = {}, Gun = {} }, names = { Knife = { "Default (real)" }, Gun = { "Default (real)" } },
    pick = { Knife = nil, Gun = nil }, fakes = {}, idle = "Knife", loading = false, dd = {},
    adj = { Knife = { rot = Vector3.zero, off = Vector3.zero, size = 1 }, Gun = { rot = Vector3.zero, off = Vector3.zero, size = 1 } },
}

local function addSkin(slot, label, skin)
    local base, i = label, 1
    while SK.list[slot][label] do i += 1 label = base .. " #" .. i end
    skin.label = label
    SK.list[slot][label] = skin
    table.insert(SK.names[slot], label)
    return label
end

do
local GRIP = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local SKIN_TARGET = { Knife = 3.6, Gun = 2.6 }
local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
-- a skin is a whole model: scripts and joints are stripped, every part is welded to the biggest one
local function prepSkinModel(objs)
    local m = Instance.new("Model")
    m.Name = "MM2SkinTemplate"
    for _, o in ipairs(objs) do o.Parent = m end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("Tool") then
            for _, ch in ipairs(d:GetChildren()) do
                if ch:IsA("BasePart") or ch:IsA("Model") then ch.Parent = m end
            end
            d:Destroy()
        end
    end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Humanoid") or d:IsA("Animator") or d:IsA("JointInstance") or d:IsA("WeldConstraint")
            or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BodyMover") or d:IsA("ForceField") or d:IsA("Seat") or d:IsA("VehicleSeat")
            or d:IsA("Constraint") then
            pcall(function() d:Destroy() end)
        end
    end
    local parts, root, best = {}, nil, -1
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            parts[#parts + 1] = d
            local vol = d.Size.X * d.Size.Y * d.Size.Z
            if vol > best then root, best = d, vol end
        end
    end
    if not root then m:Destroy() return nil end
    m.PrimaryPart = root
    for _, p in ipairs(parts) do
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, false, true, false
        if p ~= root then
            local w = Instance.new("Weld")
            w.Part0, w.Part1 = root, p
            w.C0 = root.CFrame:ToObjectSpace(p.CFrame)
            w.Parent = p
        end
    end
    return m
end

local function longAxis(s) return (s.X >= s.Y and s.X >= s.Z) and 1 or (s.Y >= s.Z and 2 or 3) end
local function rotateTo(a, b)
    local axis = a:Cross(b)
    if axis.Magnitude < 1e-4 then
        if a:Dot(b) > 0 then return CFrame.identity end
        local perp = math.abs(a.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
        return CFrame.fromAxisAngle(a:Cross(perp).Unit, math.pi)
    end
    return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a:Dot(b), -1, 1)))
end

local function dropFake(slot)
    local f = SK.fakes[slot]
    if f then pcall(function() f.model:Destroy() end) end
    SK.fakes[slot] = nil
end

-- the skin rides on the handle of the weapon you hold (so it sits exactly like the real one); with nothing in hand it goes to the hand
local function fakeFor(slot, skin, handle)
    local c = lp.Character
    local hand = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
    local anchor = handle or hand
    if not anchor then return nil end
    local a = SK.adj[slot]
    local key = skin.label .. "|" .. string.format("%.2f", a.size)
    local f = SK.fakes[slot]
    if f and f.model.Parent and f.key == key and f.anchor == anchor then return f end
    dropFake(slot)
    local m = skin.model:Clone()
    local _, sz0 = m:GetBoundingBox()
    m:ScaleTo(SKIN_TARGET[slot] * a.size / math.max(sz0.X, sz0.Y, sz0.Z, 0.01))
    local bbCF, sz = m:GetBoundingBox()
    local root = m.PrimaryPart
    local center = root.CFrame:ToObjectSpace(bbCF)
    local mi = longAxis(sz)
    local ti = handle and longAxis(handle.Size) or 3
    local weld = Instance.new("Weld")
    weld.Part0, weld.Part1 = anchor, root
    weld.C1 = center
    weld.Parent = root
    m.Parent = workspace.Terrain
    f = { model = m, weld = weld, key = key, anchor = anchor, base = handle and CFrame.identity or GRIP, orient = rotateTo(AXES[mi], AXES[ti]) }
    SK.fakes[slot] = f
    return f
end

local hiddenReal = setmetatable({}, { __mode = "k" })
local function setRealHidden(tool, hide)
    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("BasePart") then
            if hide then d.LocalTransparencyModifier = 1 hiddenReal[d] = true
            elseif hiddenReal[d] then d.LocalTransparencyModifier = 0 hiddenReal[d] = nil end
        end
    end
end
local lastHidden = {}
local function updateSkins()
    local c = lp.Character
    for _, slot in ipairs({ "Knife", "Gun" }) do
        local skin = SK.pick[slot] and SK.list[slot][SK.pick[slot]]
        local real = findTool(lp, slot)
        local equipped = real and real.Parent == c
        local show = skin and visAlive(lp) and equipped
        local f = SK.fakes[slot]
        if show then
            f = fakeFor(slot, skin, equipped and real:FindFirstChild("Handle") or nil)
            if f then
                local a = SK.adj[slot]
                f.weld.C0 = f.base * CFrame.new(a.off) * CFrame.Angles(math.rad(a.rot.X), math.rad(a.rot.Y), math.rad(a.rot.Z)) * f.orient
                if f.model.Parent ~= workspace.Terrain then f.model.Parent = workspace.Terrain end
            end
            if equipped then
                setRealHidden(real, true)
                lastHidden[slot] = real
            end
        else
            if f and f.model.Parent then f.model.Parent = nil end
        end
        if lastHidden[slot] and (not show or lastHidden[slot] ~= real or not equipped) then
            pcall(setRealHidden, lastHidden[slot], false)
            lastHidden[slot] = nil
        end
    end
end
task.spawn(function()
    while alive do
        pcall(updateSkins)
        task.wait(0.12)
    end
end)
onCleanup(function()
    for slot in pairs(SK.fakes) do dropFake(slot) end
    for p in pairs(hiddenReal) do pcall(function() p.LocalTransparencyModifier = 0 end) end
end)
SK.prep = prepSkinModel
end

local function selectSkin(slot, label)
    SK.pick[slot] = label ~= "Default (real)" and label or nil
    local dd = SK.dd[slot]
    if dd then pcall(dd.Set, label, true) end
end
local function refreshSkinLists()
    for _, slot in ipairs({ "Knife", "Gun" }) do
        local dd = SK.dd[slot]
        if dd then pcall(dd.Refresh, SK.names[slot], true) end
    end
end

-- loads a model asset and keeps the whole model as a skin
local function loadSkinAsset(id, name, slot)
    if SK.loading then return notify("Skins", "Already loading, wait a moment", "warning") end
    SK.loading = true
    notify("Skins", "Loading " .. tostring(name) .. "...", "info", 2)
    task.spawn(function()
        local done, objs, err = false, nil, nil
        task.spawn(function()
            local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
            if ok then objs = res else err = res end
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < 25 do task.wait(0.1) end
        SK.loading = false
        if not objs or #objs == 0 then
            return notify("Skins", done and ("Asset not available: " .. tostring(err or "empty")) or "Timed out", "error", 5)
        end
        local ok, m = pcall(SK.prep, objs)
        if not (ok and m) then
            for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
            return notify("Skins", "That asset has no visible parts", "error", 4)
        end
        local label = addSkin(slot, tostring(name):sub(1, 28), { model = m })
        refreshSkinLists()
        selectSkin(slot, label)
        notify("Skins", "Using " .. label .. " as your " .. slot:lower() .. " (adjust it under Fit)", "success", 4)
    end)
end

--=== SKIN LIBRARY =====================================================
-- Every knife and gun that shows up on screen (yours, or in another player's hand) is copied as data - meshes, textures,
-- colours, offsets - into a library saved to a file. Any saved weapon can then be worn as a skin, in the lobby too.
do
    local LIBFILE = "MM2_SkinLibrary.json"
    local lib = { items = {}, bySig = {}, count = { Knife = 0, Gun = 0 }, on = true, dirty = false, dd = {}, seen = setmetatable({}, { __mode = "k" }) }
    SK.lib = lib

    local function v3(v) return { v.X, v.Y, v.Z } end
    local function partRec(p, rootCF)
        local r = {
            cls = p:IsA("MeshPart") and "MeshPart" or "Part", name = p.Name,
            size = v3(p.Size), cf = { rootCF:ToObjectSpace(p.CFrame):GetComponents() },
            color = { p.Color.R, p.Color.G, p.Color.B }, mat = p.Material.Name, tr = p.Transparency, refl = p.Reflectance,
        }
        if p:IsA("MeshPart") then
            r.mesh, r.tex = p.MeshId, p.TextureID
        elseif p:IsA("Part") then
            r.shape = p.Shape.Name
        end
        local sm = p:FindFirstChildOfClass("SpecialMesh")
        if sm then r.sm = { type = sm.MeshType.Name, id = sm.MeshId, tex = sm.TextureId, scale = v3(sm.Scale), off = v3(sm.Offset), vc = v3(sm.VertexColor) } end
        return r
    end
    local function signature(parts)
        local s = {}
        for _, r in ipairs(parts) do
            s[#s + 1] = table.concat({ r.cls, r.mesh or "", r.tex or "", r.sm and (r.sm.id .. r.sm.tex .. r.sm.type) or "", string.format("%.2f,%.2f,%.2f", r.size[1], r.size[2], r.size[3]) }, "|")
        end
        return table.concat(s, ";")
    end

    local function save()
        if not (writefile and lib.dirty) then return end
        lib.dirty = false
        local out = {}
        for _, it in ipairs(lib.items) do out[#out + 1] = { slot = it.slot, label = it.label, sig = it.sig, owner = it.owner, parts = it.parts } end
        pcall(writefile, LIBFILE, HttpService:JSONEncode({ v = 1, items = out }))
    end
    local function labelFor(slot, owner)
        lib.count[slot] += 1
        return slot .. " " .. lib.count[slot] .. (owner and (" - " .. owner) or "")
    end
    local function refresh()
        for _, slot in ipairs({ "Knife", "Gun" }) do
            local names = { "Off" }
            for _, it in ipairs(lib.items) do if it.slot == slot then names[#names + 1] = it.label end end
            lib.names = lib.names or {}
            lib.names[slot] = names
            local dd = lib.dd[slot]
            if dd then pcall(dd.Refresh, names, true) end
        end
    end
    local function add(slot, parts, owner, label)
        local sig = slot .. "#" .. signature(parts)
        if lib.bySig[sig] then return false end
        local it = { slot = slot, label = label or labelFor(slot, owner), sig = sig, owner = owner, parts = parts }
        lib.items[#lib.items + 1] = it
        lib.bySig[sig] = it
        lib.dirty = true
        return it
    end

    -- load what earlier sessions saved
    pcall(function()
        if isfile and isfile(LIBFILE) then
            local d = HttpService:JSONDecode(readfile(LIBFILE))
            for _, it in ipairs(d.items or {}) do
                local n = tonumber(string.match(it.label or "", "^%a+ (%d+)")) or 0
                if n > (lib.count[it.slot] or 0) then lib.count[it.slot] = n end
                local sig = it.slot .. "#" .. signature(it.parts)
                if not lib.bySig[sig] then
                    local rec = { slot = it.slot, label = it.label, sig = sig, owner = it.owner, parts = it.parts }
                    lib.items[#lib.items + 1] = rec
                    lib.bySig[sig] = rec
                end
            end
        end
    end)

    local function capture(tool, owner)
        local h = tool:FindFirstChild("Handle")
        if not (h and h:IsA("BasePart")) then return false end
        local parts = {}
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("BasePart") and (d == h or d.Transparency < 0.98) then
                local rec = partRec(d, h.CFrame)
                if d == h then table.insert(parts, 1, rec) else parts[#parts + 1] = rec end
            end
        end
        local meshy = false
        for _, r in ipairs(parts) do if r.mesh and r.mesh ~= "" or r.sm and r.sm.id ~= "" then meshy = true end end
        if not meshy then return false end   -- not loaded yet
        local slot = tool.Name
        local it = add(slot, parts, owner)
        if it then
            refresh()
            notify("Skin Library", "Saved " .. it.label .. " (" .. lib.count.Knife .. " knives, " .. lib.count.Gun .. " guns)", "success", 3)
        end
        return true
    end

    task.spawn(function()
        while alive do
            if lib.on then
                pcall(function()
                    for _, p in ipairs(Players:GetPlayers()) do
                        local list = {}
                        local c = p.Character
                        if c then for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") then list[#list + 1] = ch end end end
                        if p == lp and p:FindFirstChild("Backpack") then
                            for _, ch in ipairs(p.Backpack:GetChildren()) do if ch:IsA("Tool") then list[#list + 1] = ch end end
                        end
                        for _, tool in ipairs(list) do
                            if (tool.Name == "Knife" or tool.Name == "Gun") and not lib.seen[tool] and tool:FindFirstChild("Handle") then
                                if capture(tool, p ~= lp and p.DisplayName or nil) then lib.seen[tool] = true end
                            end
                        end
                    end
                end)
            end
            if lib.dirty then save() end
            task.wait(1.2)
        end
    end)

    -- turn a saved weapon back into a model
    local function makePart(r)
        local p
        if r.cls == "MeshPart" then
            local ok, mp = pcall(function() local m = Instance.new("MeshPart") m.MeshId = r.mesh return m end)
            if ok and mp and mp.MeshId ~= "" then
                p = mp
            else
                local ok2, m2 = pcall(function() return game:GetService("InsertService"):CreateMeshPartAsync(r.mesh, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic) end)
                if ok2 then p = m2 end
            end
            if p then pcall(function() p.TextureID = r.tex end) end
        else
            p = Instance.new("Part")
            pcall(function() p.Shape = Enum.PartType[r.shape or "Block"] end)
        end
        if not p then return nil end
        p.Anchored = true
        pcall(function() p.Size = Vector3.new(r.size[1], r.size[2], r.size[3]) end)
        p.CFrame = CFrame.new(table.unpack(r.cf))
        p.Color = Color3.new(r.color[1], r.color[2], r.color[3])
        pcall(function() p.Material = Enum.Material[r.mat] end)
        p.Transparency, p.Reflectance = r.tr or 0, r.refl or 0
        if r.sm then
            local sm = Instance.new("SpecialMesh")
            pcall(function() sm.MeshType = Enum.MeshType[r.sm.type] end)
            sm.MeshId, sm.TextureId = r.sm.id, r.sm.tex
            sm.Scale = Vector3.new(r.sm.scale[1], r.sm.scale[2], r.sm.scale[3])
            sm.Offset = Vector3.new(r.sm.off[1], r.sm.off[2], r.sm.off[3])
            sm.VertexColor = Vector3.new(r.sm.vc[1], r.sm.vc[2], r.sm.vc[3])
            sm.Parent = p
        end
        return p
    end
    local function wear(it)
        local slot = it.slot
        if SK.list[slot][it.label] then
            SK.pick[slot] = it.label
            return
        end
        task.spawn(function()
            local objs = {}
            for _, r in ipairs(it.parts) do
                local p = makePart(r)
                if p then objs[#objs + 1] = p end
            end
            local ok, m = pcall(SK.prep, objs)
            if not (ok and m) then return notify("Skin Library", "Could not rebuild " .. it.label, "error", 4) end
            SK.list[slot][it.label] = { model = m, label = it.label }
            table.insert(SK.names[slot], it.label)
            SK.pick[slot] = it.label
            notify("Skin Library", "Wearing " .. it.label, "success", 3)
        end)
    end
    lib.wear = wear
    lib.refresh = refresh
    lib.save = function() lib.dirty = true save() end
    lib.clear = function()
        lib.items, lib.bySig, lib.count = {}, {}, { Knife = 0, Gun = 0 }
        if writefile then pcall(writefile, LIBFILE, HttpService:JSONEncode({ v = 1, items = {} })) end
        refresh()
    end
end

local origDesc
local avatarBusy = false
local function applyDescriptionFor(userId, label)
    if avatarBusy then return notify("Avatar", "Still loading the previous request", "warning") end
    avatarBusy = true
    notify("Avatar", "Loading " .. tostring(label) .. "...", "info", 2)
    task.spawn(function()
        local h = humOf(lp)
        local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
        if not (ok and desc and h) then
            avatarBusy = false
            return notify("Avatar", "Failed to load that appearance", "error")
        end
        if not origDesc then origDesc = safe(function() return h:GetAppliedDescription() end) end
        local ok2, err = pcall(function() h:ApplyDescription(desc) end)
        avatarBusy = false
        notify("Avatar", ok2 and ("Now looking like " .. tostring(label) .. " (only you see it)") or tostring(err), ok2 and "success" or "error")
    end)
end
local function applyAvatar(input)
    task.spawn(function()
        local uid = tonumber(input)
        if not uid then
            local ok, res = pcall(function() return Players:GetUserIdFromNameAsync(input) end)
            if not ok then return notify("Avatar", "User not found", "error") end
            uid = res
        end
        applyDescriptionFor(uid, input)
    end)
end
local function resetAvatar()
    local h = humOf(lp)
    if h and origDesc then
        pcall(function() h:ApplyDescription(origDesc) end)
        notify("Avatar", "Restored", "success")
    else
        applyDescriptionFor(lp.UserId, "yourself")
    end
end

--=====================================================================--
--                                  UI                                  --
--=====================================================================--
--=====================================================================--
--                           VISUAL FX ENGINE                           --
--=====================================================================--
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local F = {
    -- bullet tracers
    tracers = false, trStyle = "Streak", trColor = Color3.fromRGB(0, 220, 255), trMode = "Custom", trWidth = 0.3,
    trTime = 0.7, trImpact = true, trOthers = true, trMine = true,
    -- kill effects
    killFx = false, kfSpeed = 1, kfScale = 1, kfStyle = "Soul Ascend", kfColor = Color3.fromRGB(255, 80, 120), kfRole = true,
    kfMode = "All kills", kfText = true, kfShake = true, kfFlash = true,
    -- aura
    aura = false, auStyle = "Orbs", auColor = Color3.fromRGB(170, 90, 255), auRainbow = false, auScale = 1,
    trail = false, trailStyle = "Ribbon", trailColor = Color3.fromRGB(120, 200, 255), trailRainbow = true,
}

local function dlog() end
local function describe(v, depth)
    depth = depth or 0
    local tv = typeof(v)
    if tv == "table" and depth < 2 then
        local s = {}
        for k, x in pairs(v) do s[#s + 1] = tostring(k) .. "=" .. describe(x, depth + 1) end
        return "{" .. table.concat(s, ",") .. "}"
    elseif tv == "Instance" then return "Inst(" .. v.ClassName .. ":" .. v.Name .. ")"
    elseif tv == "Vector3" or tv == "CFrame" then return tv .. "(" .. tostring(v.Position or v) .. ")"
    end
    return tv .. ":" .. tostring(v)
end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "MM2FX"
fxFolder.Parent = workspace.Terrain
onCleanup(function() fxFolder:Destroy() end)

local function mk(props)
    local p = Instance.new("Part")
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
    p.Material = Enum.Material.Neon
    p.Size = Vector3.new(0.2, 0.2, 0.2)
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    p.Parent = fxFolder
    return p
end
local function tw(inst, t, props, style, dir)
    local tween = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end
local function life(inst, t) Debris:AddItem(inst, t) end
local function fxBudget() return #fxFolder:GetChildren() < 700 end

local function sparkBurst(pos, color, count, speed, size, tex)
    local p = mk({ Transparency = 1, Position = pos })
    local e = Instance.new("ParticleEmitter")
    e.Texture = tex or "rbxasset://textures/particles/sparkles_main.dds"
    e.Color = ColorSequence.new(color)
    e.LightEmission = 1
    e.Rate = 0
    e.Lifetime = NumberRange.new(0.5, 1.1)
    e.Speed = NumberRange.new(speed * 0.4, speed)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
    e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    e.Acceleration = Vector3.new(0, -14, 0)
    e.Parent = p
    e:Emit(count)
    life(p, 1.6)
end

local function ring(pos, color, maxR, t, thick)
    local p = mk({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(thick or 0.2, 1, 1), Color = color, Transparency = 0.3 })
    p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    tw(p, t, { Size = Vector3.new(thick or 0.2, maxR * 2, maxR * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
    life(p, t + 0.1)
end

local function boltBetween(a, b, color, width, segs, jitter, fadeT, alpha0)
    local pts = { a }
    local dir = b - a
    for i = 1, segs - 1 do
        local base = a + dir * (i / segs)
        pts[#pts + 1] = base + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * jitter
    end
    pts[#pts + 1] = b
    for i = 1, #pts - 1 do
        local p0, p1 = pts[i], pts[i + 1]
        local d = (p1 - p0).Magnitude
        if d > 0.01 then
            local seg = mk({ Color = color, Size = Vector3.new(width, width, d), Transparency = alpha0 or 0 })
            seg.CFrame = CFrame.lookAt(p0, p1) * CFrame.new(0, 0, -d / 2)
            tw(seg, fadeT, { Transparency = 1, Size = Vector3.new(0.02, 0.02, d) })
            life(seg, fadeT + 0.1)
        end
    end
end

-- shared building blocks for tracers, kill effects and objects ------------------------------
local FXH = {}
do
    local WHITE = Color3.new(1, 1, 1)
    local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

    -- a short light flash
    function FXH.light(pos, color, brightness, range, dur)
        local p = mk({ Transparency = 1, Position = pos })
        local l = Instance.new("PointLight")
        l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
        l.Parent = p
        tw(l, dur, { Brightness = 0 }, Enum.EasingStyle.Quad)
        life(p, dur + 0.1)
    end

    -- one-shot particle burst; o: tex c0 c1 le count s0 s1 size size1 l0 l1 acc drag spread dir look t0
    -- (look = a direction vector: the burst is emitted along it)
    function FXH.burst(pos, o)
        local p = mk({ Transparency = 1, Position = pos })
        if o.look then p.CFrame = CFrame.lookAt(pos, pos + o.look) end
        local e = Instance.new("ParticleEmitter")
        e.Texture = o.tex or SPARK
        e.Color = ColorSequence.new(o.c0 or WHITE, o.c1 or o.c0 or WHITE)
        e.LightEmission = o.le == nil and 1 or o.le
        e.Rate = 0
        e.Lifetime = NumberRange.new(o.l0 or 0.6, o.l1 or 1.4)
        e.Speed = NumberRange.new(o.s0 or 4, o.s1 or 16)
        e.SpreadAngle = o.spread or Vector2.new(180, 180)
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size or 0.5), NumberSequenceKeypoint.new(1, o.size1 or 0) })
        e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.t0 or 0), NumberSequenceKeypoint.new(1, 1) })
        e.Acceleration = o.acc or Vector3.new(0, -8, 0)
        e.Drag = o.drag or 0
        e.RotSpeed = NumberRange.new(-180, 180)
        e.EmissionDirection = o.look and Enum.NormalId.Front or (o.dir or Enum.NormalId.Top)
        e.Parent = p
        e:Emit(o.count or 20)
        life(p, (o.l1 or 1.4) + 0.4)
    end

    -- a thin glowing ring that expands and fades (tilt rotates its plane)
    function FXH.thinRing(center, color, r0, r1, dur, o)
        o = o or {}
        local n, thick = o.segs or 56, o.thick or 0.07
        local tilt = o.tilt or CFrame.identity
        local parts = {}
        for i = 1, n do parts[i] = mk({ Size = Vector3.new(thick, thick, 0.2), Color = color, Transparency = 0.1 }) end
        local t0 = os.clock()
        task.spawn(function()
            while parts[1].Parent do
                local k = (os.clock() - t0) / dur
                if k >= 1 then break end
                local R = r0 + (r1 - r0) * (1 - (1 - k) ^ 3)
                local segLen = (math.pi * 2 * R / n) * 1.15
                local cfs = {}
                for i, p in ipairs(parts) do
                    local ang = i / n * math.pi * 2
                    local lpos = Vector3.new(math.cos(ang) * R, 0, math.sin(ang) * R)
                    cfs[i] = CFrame.new(center) * tilt * CFrame.lookAt(lpos, lpos + Vector3.new(-math.sin(ang), 0, math.cos(ang)))
                    p.Size = Vector3.new(thick, thick, segLen)
                    p.Transparency = 0.1 + k * 0.9
                end
                workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
                task.wait()
            end
            for _, p in ipairs(parts) do p:Destroy() end
        end)
    end

    -- a soft column of light
    function FXH.beamColumn(base, height, color, width, dur)
        local a = mk({ Transparency = 1, Position = base })
        local b = mk({ Transparency = 1, Position = base + Vector3.new(0, height, 0) })
        local a0 = Instance.new("Attachment") a0.Parent = a
        local a1 = Instance.new("Attachment") a1.Parent = b
        local bm = Instance.new("Beam")
        bm.Attachment0, bm.Attachment1 = a0, a1
        bm.Color = ColorSequence.new(color, WHITE)
        bm.LightEmission = 1
        bm.FaceCamera = true
        bm.Width0, bm.Width1 = width, width * 0.4
        bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
        bm.Parent = a
        tw(bm, dur, { Width0 = 0, Width1 = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        life(a, dur + 0.2)
        life(b, dur + 0.2)
    end

    -- a ribbon behind a moving part (alpha0 = start transparency)
    function FXH.trailOn(part, c0, c1, lifetime, half, alpha0)
        local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, half, 0) a0.Parent = part
        local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -half, 0) a1.Parent = part
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Lifetime = lifetime
        tr.LightEmission = 1
        tr.MinLength = 0.03
        tr.FaceCamera = true
        tr.Color = ColorSequence.new(c0, c1 or c0)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha0 or 0.05), NumberSequenceKeypoint.new(1, 1) })
        tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
        tr.Parent = part
        return tr
    end

    -- camera zoom punch and a brief colour grade
    function FXH.punch(amount, dur)
        local c = workspace.CurrentCamera
        local base = c.FieldOfView
        tw(c, dur * 0.35, { FieldOfView = base + amount }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        task.delay(dur * 0.35, function() tw(c, dur * 0.65, { FieldOfView = base }, Enum.EasingStyle.Sine) end)
    end
    function FXH.grade(props, dur)
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Parent = Lighting
        tw(cc, dur * 0.3, props, Enum.EasingStyle.Quad)
        task.delay(dur * 0.3, function()
            tw(cc, dur * 0.7, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE }, Enum.EasingStyle.Sine)
        end)
        life(cc, dur + 0.2)
    end

    -- the rotation that lays a ring (normally flat on the ground) onto a surface with this normal
    function FXH.surfaceTilt(n)
        return CFrame.lookAt(Vector3.zero, n) * CFrame.Angles(-math.pi / 2, 0, 0)
    end
end

-- screen flash / vignette overlay -----------------------------------
local flashFrame = Instance.new("Frame")
flashFrame.Size = UDim2.fromScale(1, 1)
flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.ZIndex = 0
flashFrame.Parent = overlay
local function screenFlash(color, a)
    flashFrame.BackgroundColor3 = color
    flashFrame.BackgroundTransparency = 1 - a
    tw(flashFrame, 0.45, { BackgroundTransparency = 1 })
end

local vig = { frames = {}, strength = 0, color = Color3.new(0, 0, 0) }
do
    local defs = {
        { Vector2.new(0, 0), UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0, 0), 90 },
        { Vector2.new(0, 1), UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 1, 0), 270 },
        { Vector2.new(0, 0), UDim2.new(0.3, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
        { Vector2.new(1, 0), UDim2.new(0.3, 0, 1, 0), UDim2.new(1, 0, 0, 0), 180 },
    }
    for _, d in ipairs(defs) do
        local f = Instance.new("Frame")
        f.AnchorPoint, f.Size, f.Position = d[1], d[2], d[3]
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.ZIndex = 0
        f.Visible = false
        local g = Instance.new("UIGradient")
        g.Rotation = d[4]
        g.Parent = f
        f.Parent = overlay
        vig.frames[#vig.frames + 1] = { f = f, g = g }
    end
end
local function setVignette(strength, color)
    vig.strength, vig.color = strength, color or vig.color
    for _, v in ipairs(vig.frames) do
        v.f.Visible = strength > 0.01
        v.f.BackgroundColor3 = vig.color
        v.g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - strength), NumberSequenceKeypoint.new(1, 1) })
    end
end

-- camera shake ------------------------------------------------------
local shakeAmp = 0
local function shake(a) shakeAmp = math.max(shakeAmp, a) end
RunService:BindToRenderStep("MM2Shake", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if shakeAmp > 0.01 then
        cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * shakeAmp, (math.random() - 0.5) * shakeAmp, 0)
            * CFrame.Angles(0, 0, (math.random() - 0.5) * shakeAmp * 0.02)
        shakeAmp = shakeAmp * math.exp(-dt * 9)
    end
end)
onCleanup(function() pcall(function() RunService:UnbindFromRenderStep("MM2Shake") end) end)

--=== BULLET TRACERS ===================================================
local TRACER_STYLES = { "Streak", "Laser", "Lightning", "Prism", "Stardust", "Helix", "Comet" }

local hitRay = RaycastParams.new()
hitRay.FilterType = Enum.RaycastFilterType.Exclude
-- end point of the shot and the normal of the surface it hits (nil in the open air)
local function hitPoint(origin, target)
    local dir = target - origin
    if dir.Magnitude < 0.1 then return target, nil end
    hitRay.FilterDescendantsInstances = { lp.Character, fxFolder }
    local r = workspace:Raycast(origin, dir.Unit * math.max(dir.Magnitude + 3, 12), hitRay)
    if r then return r.Position, r.Normal end
    return target, nil
end

local function pickTracerColor(a)
    if F.trMode == "Rainbow" then return rainbowAt(os.clock()) end
    if F.trMode == "By Role" then
        local best, bd
        for _, p in ipairs(Players:GetPlayers()) do
            local r = hrpOf(p)
            if r then
                local d = (r.Position - a).Magnitude
                if d < 12 and (not bd or d < bd) then best, bd = p, d end
            end
        end
        if best then return ROLE_COLORS[getRole(best)] or F.trColor end
    end
    return F.trColor
end

-- Every shot is a small scene: a muzzle flash, a bullet that really flies (with ribbons, sparks or a helix behind it)
-- and an impact that follows the surface it hits: flash, ring, sparks, dust and a fading scorch mark.
local drawTracer
do
    local WHITE = Color3.new(1, 1, 1)
    local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
    local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local function rnd(x, y) return x + (y - x) * math.random() end

    local function beam(a, b, color, w0, w1, alpha0, alpha1, lifeT)
        local pa = mk({ Transparency = 1, Position = a })
        local pb = mk({ Transparency = 1, Position = b })
        local a0 = Instance.new("Attachment") a0.Parent = pa
        local a1 = Instance.new("Attachment") a1.Parent = pb
        local bm = Instance.new("Beam")
        bm.Attachment0, bm.Attachment1 = a0, a1
        bm.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
        bm.LightEmission = 1
        bm.LightInfluence = 0
        bm.FaceCamera = true
        bm.Width0, bm.Width1 = w0, w1
        bm.Transparency = NumberSequence.new(alpha0, alpha1)
        bm.Parent = pa
        life(pa, lifeT + 0.1)
        life(pb, lifeT + 0.1)
        return bm
    end

    local function muzzle(a, b, color)
        local dir = (b - a).Unit
        FXH.light(a, color, 3, 12, 0.12)
        local f = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.9), Color = WHITE })
        f.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -0.35)
        tw(f, 0.1, { Size = Vector3.new(0.9, 0.9, 1.8), Transparency = 1 })
        life(f, 0.15)
        FXH.burst(a, { look = dir, c0 = WHITE, c1 = color, count = 8, s0 = 8, s1 = 22, size = 0.3, l0 = 0.15, l1 = 0.35, spread = Vector2.new(12, 12), acc = Vector3.zero })
    end

    local function impact(pos, color, normal)
        local n = normal or Vector3.yAxis
        local surf = FXH.surfaceTilt(n)
        FXH.light(pos + n * 0.4, color, 2.2, 10, 0.25)
        local f = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = WHITE, Position = pos + n * 0.1 })
        tw(f, 0.2, { Size = Vector3.one * 2.2, Transparency = 1 }, Enum.EasingStyle.Quad)
        life(f, 0.25)
        FXH.thinRing(pos + n * 0.05, color, 0.15, 2.4, 0.4, { thick = 0.05, segs = 36, tilt = surf })
        FXH.burst(pos, { look = n, c0 = WHITE, c1 = color, count = 16, s0 = 6, s1 = 18, size = 0.35, l0 = 0.35, l1 = 0.8, spread = Vector2.new(40, 40), acc = Vector3.new(0, -26, 0) })
        if normal then
            FXH.burst(pos, { look = n, tex = SMOKE, c0 = Color3.fromRGB(150, 145, 140), le = 0, count = 6, s0 = 1.5, s1 = 4, size = 0.9, size1 = 2, l0 = 0.5, l1 = 0.9, spread = Vector2.new(50, 50), acc = Vector3.zero, t0 = 0.6 })
            local d = mk({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.03, 0.5, 0.5), Color = color, Transparency = 0.2 })
            d.CFrame = CFrame.new(pos + n * 0.03) * CFrame.lookAt(Vector3.zero, n) * CFrame.Angles(0, math.rad(90), 0)
            tw(d, 1.2, { Transparency = 1, Size = Vector3.new(0.03, 1.1, 1.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            life(d, 1.3)
        end
    end

    -- a bullet part with ribbons; it flies from a to b in tt seconds
    local function bullet(a, tt, color, w, tl)
        local head = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * w * 1.7, Color = WHITE, Position = a })
        FXH.trailOn(head, color, WHITE:Lerp(color, 0.4), tl, w * 1.1, 0.35)
        FXH.trailOn(head, WHITE, color:Lerp(WHITE, 0.6), tl * 0.75, w * 0.28, 0.02)
        local pl = Instance.new("PointLight")
        pl.Color, pl.Brightness, pl.Range = color, 1.4, 9
        pl.Parent = head
        life(head, tt + tl + 0.4)
        return head
    end
    local function land(head, b)
        if head.Parent then
            head.Position = b
            tw(head, 0.14, { Transparency = 1, Size = Vector3.zero })
        end
    end

    local styles = {}

    styles.Streak = function(a, b, color, dist, w, t)
        local tt = math.clamp(dist / 600, 0.12, 0.35)
        local head = bullet(a, tt, color, w, t)
        tw(head, tt, { Position = b }, Enum.EasingStyle.Linear)
        task.delay(tt, land, head, b)
        return tt
    end

    styles.Laser = function(a, b, color, dist, w, t)
        local outer = beam(a, b, color, w * 4, w * 4, 0.7, 0.7, t)
        local mid = beam(a, b, color:Lerp(WHITE, 0.45), w * 1.8, w * 1.8, 0.25, 0.25, t)
        local core = beam(a, b, WHITE, w * 0.7, w * 0.7, 0, 0, t)
        for _, bm in ipairs({ outer, mid, core }) do
            tw(bm, t, { Width0 = 0, Width1 = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end
        local glint = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * w * 2.2, Color = WHITE, Position = a })
        tw(glint, 0.07, { Position = b }, Enum.EasingStyle.Linear)
        task.delay(0.07, function() if glint.Parent then tw(glint, 0.1, { Transparency = 1, Size = Vector3.zero }) end end)
        life(glint, 0.3)
        return 0
    end

    styles.Lightning = function(a, b, color, dist, w, t)
        local segs = math.clamp(math.floor(dist / 4), 6, 36)
        boltBetween(a, b, color, w * 1.6, segs, 1.3, t, 0.55)
        boltBetween(a, b, color, w * 0.7, segs, 1.1, t)
        boltBetween(a, b, WHITE, w * 0.3, segs, 0.8, t * 0.8)
        for i = 1, 3 do
            local from = a:Lerp(b, rnd(0.15, 0.85))
            local to = from + Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)).Unit * rnd(2.5, 6)
            boltBetween(from, to, color, w * 0.35, 5, 0.7, t * 0.7)
        end
        FXH.light(a:Lerp(b, 0.5), color, 2, 14, 0.15)
        return 0
    end

    styles.Prism = function(a, b, color, dist, w, t)
        local hue = (os.clock() * 0.3) % 1
        local keys = {}
        for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((hue + i / 7) % 1, 0.8, 1)) end
        local outer = beam(a, b, ColorSequence.new(keys), w * 3, w * 1.4, 0.55, 0.8, t)
        local core = beam(a, b, WHITE, w * 0.55, w * 0.3, 0.05, 0.3, t)
        tw(outer, t, { Width0 = 0, Width1 = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tw(core, t * 0.8, { Width0 = 0, Width1 = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        for i = 1, 9 do
            local p = a:Lerp(b, i / 10 + rnd(-0.03, 0.03))
            task.delay(i * 0.012, function()
                FXH.burst(p, { c0 = Color3.fromHSV((hue + i / 9) % 1, 0.6, 1), c1 = WHITE, count = 4, s0 = 1, s1 = 4, size = 0.3, l0 = 0.4, l1 = 0.9, acc = Vector3.zero })
            end)
        end
        return 0
    end

    styles.Stardust = function(a, b, color, dist, w, t)
        local tt = math.clamp(dist / 520, 0.14, 0.4)
        local head = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * w * 1.4, Color = WHITE, Position = a })
        local em = Instance.new("ParticleEmitter")
        em.Texture = SPARK
        em.Color = ColorSequence.new(WHITE, color)
        em.LightEmission = 1
        em.Rate = 220
        em.Lifetime = NumberRange.new(t * 0.6, t * 1.3)
        em.Speed = NumberRange.new(0.2, 2.2)
        em.SpreadAngle = Vector2.new(180, 180)
        em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, w * 1.8 + 0.2), NumberSequenceKeypoint.new(1, 0) })
        em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
        em.RotSpeed = NumberRange.new(-150, 150)
        em.Parent = head
        FXH.trailOn(head, color, color, t * 0.7, w * 0.45, 0.55)
        life(head, tt + t + 0.6)
        tw(head, tt, { Position = b }, Enum.EasingStyle.Linear)
        task.delay(tt, function()
            em.Rate = 0
            land(head, b)
            FXH.burst(b, { c0 = WHITE, c1 = color, count = 24, s0 = 3, s1 = 12, size = 0.5, l0 = 0.6, l1 = 1.3, acc = Vector3.new(0, -4, 0) })
        end)
        return tt
    end

    styles.Helix = function(a, b, color, dist, w, t)
        local tt = math.clamp(dist / 420, 0.22, 0.5)
        local mid = CFrame.lookAt(a, b)
        local right, up = mid.RightVector, mid.UpVector
        local heads = {}
        for i = 1, 3 do
            local h = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * w * 1.2, Color = i == 1 and WHITE or color, Position = a })
            FXH.trailOn(h, i == 1 and WHITE or color, i == 1 and color or WHITE, t, w * 0.5, 0.15)
            heads[i] = h
            life(h, tt + t + 0.4)
        end
        local axis = beam(a, b, color:Lerp(WHITE, 0.5), w * 0.35, w * 0.35, 0.5, 0.5, t)
        tw(axis, t, { Width0 = 0, Width1 = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.spawn(function()
            local t0 = os.clock()
            while heads[1].Parent do
                local k = (os.clock() - t0) / tt
                if k >= 1 then break end
                local base = a:Lerp(b, k)
                local rad = 0.55 * (1 - k * 0.6) * math.min(1, k * 8)
                for i, h in ipairs(heads) do
                    local ang = k * dist * 0.5 + i * 2.094
                    h.Position = base + (right * math.cos(ang) + up * math.sin(ang)) * rad
                end
                task.wait()
            end
            for _, h in ipairs(heads) do land(h, b) end
        end)
        return tt
    end

    styles.Comet = function(a, b, color, dist, w, t)
        local tt = math.clamp(dist / 380, 0.16, 0.5)
        local head = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * w * 3, Color = WHITE, Position = a })
        local glow = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * w * 5, Color = color, Transparency = 0.85, Position = a })
        FXH.trailOn(head, color, color:Lerp(WHITE, 0.3), t * 1.4, w * 1.25, 0.5)
        FXH.trailOn(head, WHITE, color, t, w * 0.45, 0.05)
        local em = Instance.new("ParticleEmitter")
        em.Texture = SPARK
        em.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 110, 40))
        em.LightEmission = 1
        em.Rate = 70
        em.Lifetime = NumberRange.new(0.4, 0.9)
        em.Speed = NumberRange.new(1, 3.5)
        em.SpreadAngle = Vector2.new(180, 180)
        em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
        em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
        em.Acceleration = Vector3.new(0, -5, 0)
        em.Parent = head
        life(head, tt + t * 1.6 + 0.5)
        life(glow, tt + 0.5)
        local up = CFrame.lookAt(a, b).UpVector
        local arc = math.min(2.2, dist * 0.025)
        task.spawn(function()
            local t0 = os.clock()
            while head.Parent do
                local k = (os.clock() - t0) / tt
                if k >= 1 then break end
                local pos = a:Lerp(b, k) + up * math.sin(math.pi * k) * arc
                head.Position, glow.Position = pos, pos
                task.wait()
            end
            em.Rate = 0
            land(head, b)
            if glow.Parent then glow:Destroy() end
        end)
        return tt
    end

    drawTracer = function(a, b, normal)
        if not fxBudget() then return end
        local dist = (b - a).Magnitude
        if dist < 1 then return end
        local color = pickTracerColor(a)
        local fn = styles[F.trStyle] or styles.Streak
        muzzle(a, b, color)
        local ok, delay = pcall(fn, a, b, color, dist, F.trWidth, F.trTime)
        if not ok then
            dlog("tracer " .. tostring(F.trStyle) .. " ERR " .. tostring(delay))
            delay = 0
        end
        if F.trImpact then
            if normal == nil then
                local _, n = hitPoint(a, b)
                normal = n
            end
            task.delay(delay or 0, impact, b, color, normal)
        end
    end
end

local lastOwnTracer = 0
_G.__MM2OnShot = function(origin, target)
    if F.sndPlay then F.sndPlay("shot") end
    if not (F.tracers and F.trMine) then return end
    lastOwnTracer = os.clock()
    local ok, err = pcall(function()
        local p, n = hitPoint(origin, target)
        drawTracer(origin, p, n)
    end)
    if not ok then dlog("OwnShot drawTracer ERR " .. tostring(err)) end
end

local function parseBeamArgs(...)
    local pts = {}
    local function visit(v, depth)
        local tv = typeof(v)
        if tv == "Vector3" then pts[#pts + 1] = v
        elseif tv == "CFrame" then pts[#pts + 1] = v.Position
        elseif tv == "Instance" then
            if v:IsA("Attachment") then pts[#pts + 1] = v.WorldPosition
            elseif v:IsA("BasePart") then pts[#pts + 1] = v.Position
            elseif v:IsA("Model") then
                local pp = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                if pp then pts[#pts + 1] = pp.Position end
            end
        elseif tv == "table" and depth < 2 then
            for _, x in pairs(v) do visit(x, depth + 1) end
        end
    end
    for _, v in ipairs({ ... }) do visit(v, 0) end
    return pts
end

local gunBeamRemote = RS:FindFirstChild("WeaponEvents") and RS.WeaponEvents:FindFirstChild("GunBeam")
if gunBeamRemote then
    track(gunBeamRemote.OnClientEvent:Connect(function(...)
        local args = { ... }
        local parts = {}
        for i, v in ipairs(args) do parts[#parts + 1] = i .. ":" .. describe(v) end
        dlog("GunBeam args " .. table.concat(parts, " | "))
        if not (F.tracers and F.trOthers) then return end
        local pts = parseBeamArgs(...)
        dlog("GunBeam points=" .. #pts)
        if #pts >= 2 then
            local a, b = pts[1], pts[#pts]
            local r = hrpOf(lp)
            if r and (a - r.Position).Magnitude < 12 and os.clock() - lastOwnTracer < 0.5 then return end
            local ok, err = pcall(function()
                local bp, n = hitPoint(a, b)
                if (bp - b).Magnitude < 8 then b = bp end
                drawTracer(a, b, n)
            end)
            if not ok then dlog("drawTracer ERR " .. tostring(err)) end
        end
    end))
end

-- own manual shots (gun Activated)
local hookedGuns = setmetatable({}, { __mode = "k" })
task.spawn(function()
    while alive do
        local c = lp.Character
        for _, holder in ipairs({ c, lp:FindFirstChild("Backpack") }) do
            local tool = holder and holder:FindFirstChild("Gun")
            if tool and not hookedGuns[tool] then
                hookedGuns[tool] = true
                tool.Activated:Connect(function()
                    dlog("Gun Activated")
                    task.defer(function()
                        local r = hrpOf(lp)
                        if r and lastAim.pos and os.clock() - lastAim.t < 0.3 and not S.autoShoot and not _G.__MM2NamecallHooked then
                            local att = r:FindFirstChild("GunRaycastAttachment")
                            _G.__MM2OnShot(att and att.WorldPosition or r.Position, lastAim.pos)
                        end
                    end)
                end)
            end
        end
        task.wait(1)
    end
end)

-- thrown knives get a glowing trail
track(workspace.DescendantAdded:Connect(function(d)
    if not (F.tracers and d:IsA("BasePart") and d.Name:find("Knife") and not d:FindFirstAncestorOfClass("Tool")) then return end
    if d:FindFirstAncestorWhichIsA("Humanoid") or (d.Parent and d.Parent:FindFirstChildOfClass("Humanoid")) then return end
    task.defer(function()
        if not d.Parent then return end
        local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 0.4, 0) a0.Parent = d
        local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -0.4, 0) a1.Parent = d
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Lifetime = 0.6
        tr.LightEmission = 1
        tr.Color = ColorSequence.new(F.trMode == "Rainbow" and rainbowAt(os.clock()) or F.trColor, Color3.new(1, 1, 1))
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
        tr.Parent = d
    end)
end))

--=== KILL EFFECTS =====================================================
local KILL_STYLES = { "Soul Ascend", "Black Hole", "Thunder Smite", "Crystal Shatter", "Haunt", "Sakura Bloom", "Random" }

-- Every kill effect is a short scene: a build-up, the main moment and an aftermath, with light, layered particles,
-- thin rings, ribbons and details on the floor. Camera / colour reactions only play for kills you can actually see.
local killEffect
do
    local _mk, _tw, _life, _bolt = mk, tw, life, boltBetween
    local WHITE = Color3.new(1, 1, 1)
    local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
    local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local FIRE = "rbxasset://textures/particles/fire_main.dds"
    local function rnd(a, b) return a + (b - a) * math.random() end

    local function groundY(pos, skip)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local list = { fxFolder }
        if skip then list[#list + 1] = skip end
        if lp.Character then list[#list + 1] = lp.Character end
        rp.FilterDescendantsInstances = list
        local res = workspace:Raycast(pos, Vector3.new(0, -14, 0), rp)
        return res and res.Position.Y + 0.04 or pos.Y - 2.8
    end

    -- every effect is built per kill by kfBuild(speed, scale, origin): the shadowed helpers below stretch time and space,
    -- so the effect code itself is written for speed 1 / scale 1
    local function kfBuild(SP, SC, ORG)
    local task_, os_ = task, os
    local task = setmetatable({
        wait = function(n) if n then return task_.wait(n / SP) end return task_.wait() end,
        delay = function(t, f, ...) return task_.delay(t / SP, f, ...) end,
    }, { __index = task_ })
    local os = setmetatable({ clock = function() return os_.clock() * SP end }, { __index = os_ })
    local GHOST = setmetatable({}, { __mode = "k" })
    local function sv(v) return ORG + (v - ORG) * SC end      -- point: scale about the floor under the victim
    local function usv(v) return ORG + (v - ORG) / SC end
    local function scf(cf) return CFrame.new(sv(cf.Position)) * (cf - cf.Position) end

    local function mk(props)
        local q = table.clone(props)
        q.Size = (props.Size or Vector3.new(0.2, 0.2, 0.2)) * SC
        if props.Position then q.Position = sv(props.Position) end
        if props.CFrame then q.CFrame = scf(props.CFrame) end
        return _mk(q)
    end
    local function tw(inst, t, props, style, dir)
        if typeof(inst) == "Instance" then
            if inst:IsA("BasePart") and not GHOST[inst] then
                props = table.clone(props)
                if props.Size then props.Size = props.Size * SC end
                if props.Position then props.Position = sv(props.Position) end
                if props.CFrame then props.CFrame = scf(props.CFrame) end
            elseif inst:IsA("Beam") then
                props = table.clone(props)
                if props.Width0 then props.Width0 = props.Width0 * SC end
                if props.Width1 then props.Width1 = props.Width1 * SC end
            end
        end
        return _tw(inst, t / SP, props, style, dir)
    end
    local function life(inst, t) _life(inst, t / SP) end
    local function light(pos, c, b, range, dur) FXH.light(sv(pos), c, b, range * SC, dur / SP) end
    local function burst(pos, o)
        local q = table.clone(o)
        q.s0, q.s1 = (o.s0 or 4) * SC * SP, (o.s1 or 16) * SC * SP
        q.size, q.size1 = (o.size or 0.5) * SC, (o.size1 or 0) * SC
        q.l0, q.l1 = (o.l0 or 0.6) / SP, (o.l1 or 1.4) / SP
        q.acc = (o.acc or Vector3.new(0, -8, 0)) * SC * SP * SP
        q.drag = (o.drag or 0) * SP
        FXH.burst(sv(pos), q)
    end
    local function thinRing(center, c, r0, r1, dur, o)
        local q = table.clone(o or {})
        q.thick = (q.thick or 0.07) * SC
        FXH.thinRing(sv(center), c, r0 * SC, r1 * SC, dur / SP, q)
    end
    local function beamColumn(base, h, c, w, dur) FXH.beamColumn(sv(base), h * SC, c, w * SC, dur / SP) end
    local function trailOn(part, c0, c1, lifetime, half, a0) return FXH.trailOn(part, c0, c1, lifetime / SP, half * SC, a0) end
    local function punch(a, dur) FXH.punch(a, dur / SP) end
    local function grade(p, dur) FXH.grade(p, dur / SP) end
    local function boltBetween(a, b, c, w, segs, jit, fadeT, a0) _bolt(sv(a), sv(b), c, w * SC, segs, jit * SC, fadeT / SP, a0) end

    -- a copy of the victim's body made of anchored parts
    local function ghostOf(c, color, material, transp)
        local ok, g = pcall(function() return c:Clone() end)
        if not ok or not g then return nil end
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Sound") or d:IsA("Motor6D") or d:IsA("Tool") or d:IsA("ForceField")
                or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
                d:Destroy()
            end
        end
        local parts = {}
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
                GHOST[d] = true
                d.Material = material or Enum.Material.Neon
                d.Color = color
                d.Transparency = d.Name == "HumanoidRootPart" and 1 or (transp or 0.2)
                if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
                parts[#parts + 1] = d
            end
        end
        g.Parent = fxFolder
        return g, parts
    end

    local function killText(pos, text, color)
        local p = mk({ Transparency = 1, Position = pos + Vector3.new(0, 3.5, 0) })
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.fromOffset(240, 50)
        bb.AlwaysOnTop = true
        bb.Parent = p
        local tl = Instance.new("TextLabel")
        tl.BackgroundTransparency = 1
        tl.Size = UDim2.fromScale(1, 1)
        tl.Text = text
        tl.Font = Enum.Font.GothamBlack
        tl.TextSize = 26
        tl.TextColor3 = color
        tl.TextStrokeTransparency = 0.3
        tl.TextStrokeColor3 = Color3.new(0, 0, 0)
        tl.Parent = bb
        tw(bb, 1.6, { StudsOffset = Vector3.new(0, 5, 0) }, Enum.EasingStyle.Quad)
        tw(tl, 1.6, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        life(p, 1.8)
    end

    --=== SOUL ASCEND ======================================================
    -- the body turns into a hologram and drifts up, a soul orb leaves the chest on a spiral and bursts into stars
    local function fxSoul(c, pos, col, feetY)
        local floor = Vector3.new(pos.X, feetY, pos.Z)
        light(pos, col, 4, 24, 1.6)
        thinRing(floor, col, 0.4, 6.8, 1.2, { thick = 0.06 })
        thinRing(floor, WHITE, 0.3, 4.4, 0.95, { thick = 0.035, segs = 44 })
        beamColumn(floor, 34, col, 2.4, 2.2)
        local g, parts = ghostOf(c, col, Enum.Material.ForceField, 0.05)
        if g then
            for _, p in ipairs(parts) do
                if p.Name ~= "HumanoidRootPart" then
                    local rel = math.clamp((p.Position.Y - feetY) / 5, 0, 1)
                    task.delay(rel * 0.4, function()
                        if p.Parent then
                            tw(p, 2.8, {
                                CFrame = p.CFrame * CFrame.new(rnd(-0.7, 0.7) * SC, rnd(8, 13) * SC, rnd(-0.7, 0.7) * SC) * CFrame.Angles(0, math.rad(math.random(-80, 80)), 0),
                                Transparency = 1,
                            }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
                        end
                    end)
                end
            end
            life(g, 3.4)
        end
        burst(pos, { c0 = col, c1 = WHITE, count = 28, s0 = 1, s1 = 4, size = 0.4, l0 = 1.4, l1 = 2.6, acc = Vector3.new(0, 5, 0), spread = Vector2.new(60, 60) })
        local orb = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = WHITE, Position = pos })
        local pl = Instance.new("PointLight") pl.Color, pl.Brightness, pl.Range = col, 2.5, 14 * SC pl.Parent = orb
        trailOn(orb, col, WHITE, 1.6, 0.35)
        life(orb, 3.7)
        task.spawn(function()
            local t0 = os.clock()
            while orb.Parent do
                local k = (os.clock() - t0) / 3.3
                if k >= 1 then break end
                local ease = k * k * (3 - 2 * k)
                local ang = k * 11
                local rad = 0.5 + math.sin(k * math.pi) * 1.7
                orb.Position = sv(pos + Vector3.new(math.cos(ang) * rad, ease * 26, math.sin(ang) * rad))
                orb.Size = Vector3.one * (0.9 * (1 - k * 0.6) * SC)
                task.wait()
            end
            if orb.Parent then
                local top = usv(orb.Position)
                burst(top, { c0 = WHITE, c1 = col, count = 38, s0 = 3, s1 = 11, size = 0.55, l0 = 0.8, l1 = 1.8, acc = Vector3.new(0, -2, 0) })
                thinRing(top, col, 0.3, 4.5, 0.9, { thick = 0.05 })
                light(top, col, 3, 20, 0.8)
                orb:Destroy()
            end
        end)
    end

    --=== BLACK HOLE =======================================================
    -- an event horizon with a camera-facing photon ring, an accretion disk of glowing arcs that spin faster near the
    -- centre, two jets, an infalling star swarm; the victim is pulled in, then everything contracts into a flash
    local function fxBlackHole(c, pos, col, feetY, near)
        local camPos = workspace.CurrentCamera.CFrame.Position
        -- the disk is seen from a shallow angle, whatever the direction of the camera is
        local cpos = sv(pos)
        local diskCF = CFrame.lookAt(cpos, camPos) * CFrame.Angles(math.rad(74), 0, 0)
        local diskRot = diskCF - diskCF.Position
        local normal = diskCF:VectorToWorldSpace(Vector3.zAxis)
        local R0 = 1.7

        -- event horizon: a black sphere in a faint shimmering shell, with a soft glow behind it
        local core = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3, Color = Color3.fromRGB(2, 0, 5), Material = Enum.Material.SmoothPlastic, Position = pos })
        tw(core, 0.55, { Size = Vector3.one * R0 * 2 }, Enum.EasingStyle.Back)
        local shell = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = col:Lerp(Color3.new(0, 0, 0), 0.7), Material = Enum.Material.ForceField, Transparency = 0.4, Position = pos })
        tw(shell, 0.55, { Size = Vector3.one * (R0 * 2 + 0.55) }, Enum.EasingStyle.Back)
        burst(pos, { c0 = Color3.fromRGB(255, 190, 110), c1 = col, count = 1, s0 = 0, s1 = 0, size = 9, size1 = 9, l0 = 2.8, l1 = 2.8, t0 = 0.78, acc = Vector3.zero })
        light(pos, Color3.fromRGB(255, 190, 120), 1.4, 22, 2.6)

        -- photon rings: always a perfect circle facing the camera
        local rings = {}
        for _, def in ipairs({ { 2.05, 0.09, WHITE, 0.05 }, { 2.3, 0.055, Color3.fromRGB(255, 205, 120), 0.3 }, { 2.75, 0.035, col, 0.55 } }) do
            local segs = {}
            for i = 1, 72 do segs[i] = mk({ Size = Vector3.new(def[2], def[2], 0.2), Color = def[3], Transparency = def[4] }) end
            rings[#rings + 1] = { segs = segs, R = def[1], thick = def[2], base = def[4] }
        end

        -- accretion disk: 230 thin arcs on Keplerian orbits, white-hot inside, orange in the middle, the role colour outside
        local arcs = {}
        local rIn, rOut = 2.7, 8.4
        for i = 1, 230 do
            local r = rIn + (rOut - rIn) * math.random() ^ 1.4
            local k = (r - rIn) / (rOut - rIn)
            local colr
            if k < 0.1 then colr = Color3.fromRGB(255, 246, 230):Lerp(Color3.fromRGB(255, 205, 110), k / 0.1)
            elseif k < 0.4 then colr = Color3.fromRGB(255, 205, 110):Lerp(Color3.fromRGB(255, 110, 40), (k - 0.1) / 0.3)
            else colr = Color3.fromRGB(255, 110, 40):Lerp(col, (k - 0.4) / 0.6) end
            arcs[i] = {
                part = mk({ Size = Vector3.new(rnd(0.025, 0.06), rnd(0.025, 0.05), rnd(0.5, 1.6) * (1 - k * 0.3)), Color = colr, Transparency = rnd(0.12, 0.55) + k * 0.2 }),
                r = r, a = rnd(0, math.pi * 2), w = 9 / r ^ 1.5, off = rnd(-0.07, 0.07), base = rnd(0.12, 0.55) + k * 0.2,
            }
        end

        -- two jets along the disk's axis: a hair-thin beam core and a stream of sparks
        local jets = {}
        for sgn = -1, 1, 2 do
            local a = mk({ Transparency = 1, CFrame = CFrame.lookAt(pos, pos + normal * sgn) })
            local b = mk({ Transparency = 1, Position = pos + normal * 15 * sgn })
            local a0 = Instance.new("Attachment") a0.Parent = a
            local a1 = Instance.new("Attachment") a1.Parent = b
            local bm = Instance.new("Beam")
            bm.Attachment0, bm.Attachment1 = a0, a1
            bm.Color = ColorSequence.new(Color3.fromRGB(215, 235, 255), col)
            bm.LightEmission = 1
            bm.FaceCamera = true
            bm.Width0, bm.Width1 = 0, 0
            bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
            bm.Parent = a
            local em = Instance.new("ParticleEmitter")
            em.Texture = SPARK
            em.Color = ColorSequence.new(Color3.fromRGB(225, 240, 255), col)
            em.LightEmission = 1
            em.Rate = 0
            em.Lifetime = NumberRange.new(0.5 / SP, 0.9 / SP)
            em.Speed = NumberRange.new(16 * SC * SP, 26 * SC * SP)
            em.SpreadAngle = Vector2.new(5, 5)
            em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55 * SC), NumberSequenceKeypoint.new(1, 0) })
            em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
            em.EmissionDirection = Enum.NormalId.Front
            em.Parent = a
            jets[#jets + 1] = { beam = bm, a = a, b = b, em = em }
        end

        -- stars falling in on spirals (a few leave ribbons)
        local stars = {}
        for i = 1, 34 do
            local st = {
                part = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * rnd(0.14, 0.3), Color = i % 3 == 0 and WHITE or col }),
                r0 = rnd(8, 15), a0 = rnd(0, math.pi * 2), z0 = rnd(-5, 5), spin = rnd(3.5, 6), delay = rnd(0, 0.4),
            }
            trailOn(st.part, st.part.Color, WHITE, 0.55, 0.07)
            stars[i] = st
        end

        -- the victim is torn apart and pulled in
        local g, parts = ghostOf(c, col, Enum.Material.ForceField, 0.1)
        if g then
            for _, p in ipairs(parts) do
                local d = (p.Position - pos).Magnitude
                task.delay(0.4 + d * 0.06, function()
                    if p.Parent then
                        tw(p, 1.0, { CFrame = CFrame.new(cpos) * CFrame.Angles(rnd(0, 3), rnd(0, 3), 0), Size = p.Size * Vector3.new(0.1, 0.1, 0.7), Transparency = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                    end
                end)
            end
            life(g, 2)
        end
        if near then
            punch(-6, 2.3)
            grade({ Brightness = -0.1, Contrast = 0.22, Saturation = -0.25 }, 2.5)
        end

        task.spawn(function()
            local t0, T = os.clock(), 2.3
            while core.Parent do
                local el = os.clock() - t0
                if el >= T then break end
                local appear = math.clamp(el / 0.55, 0, 1)
                local contract = math.clamp((el - (T - 0.4)) / 0.4, 0, 1)
                local shrink = 1 - contract * contract
                local spinUp = 1 + contract * 5
                local camNow = workspace.CurrentCamera.CFrame.Position
                local face = CFrame.lookAt(cpos, camNow)

                -- photon rings
                for _, rg in ipairs(rings) do
                    local R = rg.R * SC * shrink * (0.6 + 0.4 * appear) * (1 + math.sin(el * 5 + rg.R) * 0.01)
                    local segLen = (math.pi * 2 * R / #rg.segs) * 1.15
                    local cfs = {}
                    for i, p in ipairs(rg.segs) do
                        local ang = i / #rg.segs * math.pi * 2
                        local lpos = Vector3.new(math.cos(ang) * R, math.sin(ang) * R, 0)
                        cfs[i] = face * CFrame.lookAt(lpos, lpos + Vector3.new(-math.sin(ang), math.cos(ang), 0))
                        p.Size = Vector3.new(rg.thick * SC, rg.thick * SC, segLen)
                        p.Transparency = rg.base + (1 - appear) * (1 - rg.base)
                    end
                    workspace:BulkMoveTo(rg.segs, cfs, Enum.BulkMoveMode.FireCFrameChanged)
                end

                -- disk
                local ps, cfs = {}, {}
                for i, ar in ipairs(arcs) do
                    local ang = ar.a + ar.w * el * spinUp
                    local r = ar.r * SC * shrink
                    local lpos = Vector3.new(math.cos(ang) * r, math.sin(ang) * r, ar.off * SC)
                    ps[i] = ar.part
                    cfs[i] = diskCF * CFrame.lookAt(lpos, lpos + Vector3.new(-math.sin(ang), math.cos(ang), 0))
                    ar.part.Transparency = ar.base + (1 - appear) * (1 - ar.base)
                end
                workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged)

                -- jets
                local jw = appear * (1 - contract)
                for _, j in ipairs(jets) do
                    j.beam.Width0 = 0.22 * SC * jw * (0.85 + math.sin(el * 20) * 0.15)
                    j.beam.Width1 = 0.03 * SC * jw
                    j.em.Rate = 70 * jw
                end

                -- stars
                for _, st in ipairs(stars) do
                    local k = math.clamp((el - st.delay) / (T - 0.5), 0, 1)
                    local rr = st.r0 * (1 - k ^ 1.5) + 0.4
                    local ang = st.a0 + k * st.spin * math.pi
                    local lpos = Vector3.new(math.cos(ang) * rr, math.sin(ang) * rr, st.z0 * (1 - k) ^ 2)
                    st.part.Position = (diskCF * CFrame.new(lpos * SC)).Position
                    st.part.Transparency = k > 0.9 and (k - 0.9) * 10 or 0
                end
                task.wait()
            end

            -- collapse: everything is gone in a flash and a shockwave
            for _, st in ipairs(stars) do st.part:Destroy() end
            for _, rg in ipairs(rings) do for _, p in ipairs(rg.segs) do p:Destroy() end end
            for _, ar in ipairs(arcs) do ar.part:Destroy() end
            for _, j in ipairs(jets) do j.a:Destroy() j.b:Destroy() end
            if core.Parent then tw(core, 0.12, { Size = Vector3.zero }) life(core, 0.2) end
            if shell.Parent then tw(shell, 0.12, { Size = Vector3.zero }) life(shell, 0.2) end
            local pulse = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = WHITE, Position = pos, Transparency = 0.15 })
            tw(pulse, 0.5, { Size = Vector3.one * 22, Transparency = 1 }, Enum.EasingStyle.Quart)
            life(pulse, 0.6)
            thinRing(pos, WHITE, 1, 20, 0.75, { thick = 0.09, tilt = diskRot })
            thinRing(pos, Color3.fromRGB(255, 190, 110), 1, 14, 0.65, { thick = 0.06 })
            thinRing(pos, col, 1, 10, 0.55, { thick = 0.05, tilt = diskRot * CFrame.Angles(math.rad(90), 0, 0) })
            burst(pos, { c0 = WHITE, c1 = col, count = 50, s0 = 10, s1 = 32, size = 0.7, l0 = 0.5, l1 = 1.4, acc = Vector3.zero, drag = 2 })
            light(pos, WHITE, 5, 40, 0.45)
            if near then
                punch(16, 0.6)
                if F.kfFlash then screenFlash(col, 0.35) end
            end
        end)
    end

    --=== THUNDER SMITE ====================================================
    -- a rune circle draws itself, the sky dims, a forked bolt lands; rocks, cracks and a scorch mark remain
    local function fxThunder(c, pos, col, feetY, near)
        local floor = Vector3.new(pos.X, feetY, pos.Z)
        thinRing(floor, col, 0.3, 3.4, 0.45, { thick = 0.05, segs = 48 })
        thinRing(floor, WHITE, 0.2, 2.2, 0.45, { thick = 0.035, segs = 36 })
        beamColumn(floor, 60, WHITE, 0.5, 0.5)
        if near then grade({ Brightness = -0.18, Contrast = 0.1 }, 0.55) end
        task.delay(0.5, function()
            local top = pos + Vector3.new(math.random(-6, 6), 140, math.random(-6, 6))
            boltBetween(top, pos, col, 1.3, 26, 6, 0.55)
            boltBetween(top, pos, WHITE, 0.55, 26, 4, 0.45)
            for i = 1, 5 do
                local from = top:Lerp(pos, rnd(0.2, 0.8))
                local to = from + Vector3.new(rnd(-22, 22), -rnd(14, 34), rnd(-22, 22))
                boltBetween(from, to, col, 0.4, 9, 2.4, 0.4)
                if i <= 2 then
                    local mid = from:Lerp(to, 0.5)
                    boltBetween(mid, mid + Vector3.new(rnd(-9, 9), -rnd(6, 12), rnd(-9, 9)), WHITE, 0.2, 5, 1.2, 0.3)
                end
            end
            light(pos, WHITE, 10, 70, 0.35)
            if near then
                if F.kfFlash then
                    screenFlash(WHITE, 0.6)
                    task.delay(0.12, function() screenFlash(col, 0.35) end)
                end
                punch(9, 0.5)
            end
            thinRing(floor, WHITE, 0.5, 15, 0.65, { thick = 0.09 })
            thinRing(floor, col, 0.5, 10, 0.55, { thick = 0.06 })
            burst(floor + Vector3.new(0, 0.5, 0), { tex = SMOKE, c0 = Color3.fromRGB(120, 112, 105), le = 0, count = 26, s0 = 6, s1 = 14, size = 3, size1 = 6, l0 = 0.9, l1 = 1.8, spread = Vector2.new(85, 85), acc = Vector3.new(0, 1, 0), t0 = 0.5 })
            burst(pos, { c0 = WHITE, c1 = Color3.fromRGB(255, 210, 90), count = 30, s0 = 14, s1 = 34, size = 0.5, l0 = 0.4, l1 = 1, acc = Vector3.new(0, -30, 0) })
            for i = 1, 14 do
                local rock = mk({ Size = Vector3.new(rnd(0.2, 0.5), rnd(0.2, 0.4), rnd(0.2, 0.5)), Color = Color3.fromRGB(72, 64, 58), Material = Enum.Material.Slate, Position = floor + Vector3.new(0, 0.3, 0) })
                local a, d = rnd(0, math.pi * 2), rnd(2.5, 8)
                local landP = floor + Vector3.new(math.cos(a) * d, 0.15, math.sin(a) * d)
                local peak = floor + Vector3.new(math.cos(a) * d * 0.5, rnd(3.5, 7), math.sin(a) * d * 0.5)
                tw(rock, 0.32, { Position = peak, Orientation = Vector3.new(rnd(0, 360), rnd(0, 360), rnd(0, 360)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                task.delay(0.32, function()
                    if rock.Parent then tw(rock, 0.42, { Position = landP, Orientation = Vector3.new(rnd(0, 360), rnd(0, 360), rnd(0, 360)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
                end)
                task.delay(1.4, function() if rock.Parent then tw(rock, 0.8, { Transparency = 1 }) end end)
                life(rock, 2.4)
            end
            for i = 1, 10 do
                local a = i / 10 * math.pi * 2 + rnd(-0.2, 0.2)
                local len = rnd(3, 7)
                local crack = mk({ Size = Vector3.new(0.09, 0.04, len), Color = Color3.fromRGB(255, 140, 30), Transparency = 0.05 })
                crack.CFrame = scf(CFrame.new(floor + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, a, 0)) * CFrame.new(0, 0, -len / 2 * SC)
                tw(crack, 2.6, { Transparency = 1, Color = Color3.fromRGB(120, 30, 10) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                life(crack, 2.7)
            end
            local scorch = mk({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 6.8, 6.8), Color = Color3.fromRGB(14, 12, 12), Material = Enum.Material.Slate, Transparency = 0.2 })
            scorch.CFrame = scf(CFrame.new(floor + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)))
            tw(scorch, 3.6, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            life(scorch, 3.7)
            local g, parts = ghostOf(c, Color3.fromRGB(26, 22, 22), Enum.Material.Slate, 0)
            if g then
                for _, p in ipairs(parts) do
                    if p.Name ~= "HumanoidRootPart" then
                        local rel = math.clamp((p.Position.Y - feetY) / 5, 0, 1)
                        task.delay(0.5 + (1 - rel) * 0.25, function()
                            if p.Parent then
                                tw(p, 1.3, { Transparency = 1, Size = p.Size * Vector3.new(1.15, 0.2, 1.15), CFrame = p.CFrame - Vector3.new(0, p.Size.Y * 0.45, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                            end
                        end)
                    end
                end
                life(g, 2.2)
            end
            burst(pos, { tex = SMOKE, c0 = Color3.fromRGB(70, 66, 62), c1 = Color3.fromRGB(30, 28, 28), le = 0, count = 24, s0 = 1, s1 = 4, size = 2, size1 = 5, l0 = 1.6, l1 = 3, acc = Vector3.new(0, 3, 0), spread = Vector2.new(50, 50), t0 = 0.45 })
            burst(pos - Vector3.new(0, 1.5, 0), { c0 = Color3.fromRGB(255, 170, 60), c1 = Color3.fromRGB(255, 70, 20), count = 36, s0 = 1, s1 = 6, size = 0.35, l0 = 1.6, l1 = 3, acc = Vector3.new(0, 6, 0), spread = Vector2.new(70, 70) })
        end)
    end

    --=== CRYSTAL SHATTER ==================================================
    -- the body freezes into glass, trembles, then bursts into dozens of tumbling shards
    local function fxCrystal(c, pos, col, feetY, near)
        local ice = Color3.fromRGB(150, 220, 255)
        local floor = Vector3.new(pos.X, feetY, pos.Z)
        local g, parts = ghostOf(c, ice, Enum.Material.Glass, 0.25)
        burst(pos, { tex = SMOKE, c0 = ice, c1 = WHITE, le = 0.4, count = 22, s0 = 1, s1 = 5, size = 2.4, size1 = 0.5, l0 = 0.9, l1 = 1.7, acc = Vector3.new(0, -1, 0), t0 = 0.55 })
        thinRing(floor, ice, 0.3, 5.5, 0.5, { thick = 0.06 })
        for i = 1, 9 do
            local a, len = i / 9 * math.pi * 2 + rnd(-0.15, 0.15), rnd(2.5, 5.5)
            local cr = mk({ Size = Vector3.new(0.06, 0.03, len), Color = WHITE, Transparency = 0.1 })
            cr.CFrame = scf(CFrame.new(floor + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, a, 0)) * CFrame.new(0, 0, -len / 2 * SC)
            tw(cr, 1.8, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            life(cr, 1.9)
        end
        light(pos, ice, 3, 20, 1.2)
        task.spawn(function()
            if g then
                local t0 = os.clock()
                local base = {}
                for i, p in ipairs(parts) do base[i] = p.CFrame end
                while g.Parent and os.clock() - t0 < 0.55 do
                    local k = (os.clock() - t0) / 0.55
                    for i, p in ipairs(parts) do
                        p.CFrame = base[i] + Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) * 0.04 * (0.4 + k)
                    end
                    task.wait()
                end
                g:Destroy()
            end
            local shards = {}
            for i = 1, 72 do
                local w = Instance.new("WedgePart")
                w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
                w.Size = Vector3.new(rnd(0.1, 0.25), rnd(0.3, 0.8), rnd(0.2, 0.6)) * SC
                w.Material = (i % 4 == 0) and Enum.Material.Neon or Enum.Material.Glass
                w.Color = ice:Lerp(WHITE, rnd(0, 0.6))
                w.Transparency = rnd(0, 0.25)
                local off = Vector3.new(rnd(-1, 1), rnd(-2.4, 2.4), rnd(-0.7, 0.7))
                w.CFrame = CFrame.new(sv(pos + off)) * CFrame.Angles(rnd(0, 6), rnd(0, 6), rnd(0, 6))
                w.Parent = fxFolder
                local dir = Vector3.new(off.X, off.Y * 0.4 + 0.5, off.Z)
                if dir.Magnitude < 0.1 then dir = Vector3.yAxis end
                shards[i] = { part = w, vel = (dir.Unit * rnd(8, 20) + Vector3.new(0, rnd(2, 8), 0)) * SC, spin = Vector3.new(rnd(-9, 9), rnd(-9, 9), rnd(-9, 9)), life = rnd(1.2, 2.0) }
            end
            thinRing(pos, WHITE, 0.4, 9, 0.5, { thick = 0.08 })
            burst(pos, { c0 = ice, c1 = WHITE, count = 40, s0 = 6, s1 = 20, size = 0.5, l0 = 0.6, l1 = 1.5 })
            burst(pos, { tex = SMOKE, c0 = ice, le = 0.3, count = 16, s0 = 2, s1 = 8, size = 3, size1 = 0.5, l0 = 0.8, l1 = 1.6, t0 = 0.6, acc = Vector3.new(0, -2, 0) })
            light(pos, WHITE, 6, 36, 0.4)
            if near then
                punch(6, 0.45)
                grade({ Saturation = -0.35, TintColor = ice, Contrast = 0.15 }, 0.6)
            end
            local s0, dt = os.clock(), SP / 60
            while os.clock() - s0 < 2.1 do
                local el = os.clock() - s0
                for _, sh in ipairs(shards) do
                    if sh.part.Parent then
                        sh.vel = (sh.vel + Vector3.new(0, -26 * SC * dt, 0)) * (1 - 0.6 * dt)
                        local cf = sh.part.CFrame + sh.vel * dt
                        if cf.Position.Y < feetY + 0.08 then
                            cf = cf + Vector3.new(0, feetY + 0.08 - cf.Position.Y, 0)
                            sh.vel = Vector3.new(sh.vel.X * 0.5, math.abs(sh.vel.Y) * 0.25, sh.vel.Z * 0.5)
                        end
                        sh.part.CFrame = cf * CFrame.Angles(sh.spin.X * dt, sh.spin.Y * dt, sh.spin.Z * dt)
                        if el > sh.life then sh.part.Transparency = math.min(1, sh.part.Transparency + dt * 2.2) end
                    end
                end
                dt = task.wait() * SP
            end
            for _, sh in ipairs(shards) do sh.part:Destroy() end
        end)
    end

    --=== HAUNT (Halloween) ================================================
    local function spirit(origin, delay, seed)
        task.delay(delay, function()
            -- a classic bedsheet ghost: dome, body and a wavy hem
            local dome = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.7, 1.7, 1.7), Color = Color3.fromRGB(196, 186, 236), Material = Enum.Material.SmoothPlastic, Transparency = 0.15, Position = origin })
            local torso = mk({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 1.7, 1.7), Color = Color3.fromRGB(196, 186, 236), Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
            local hem = {}
            for i = 1, 6 do
                hem[i] = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.62, 0.7, 0.62), Color = Color3.fromRGB(196, 186, 236), Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
            end
            local dark = Color3.fromRGB(12, 0, 22)
            local eyeL = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.5, 0.12), Color = dark, Material = Enum.Material.SmoothPlastic })
            local eyeR = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.5, 0.12), Color = dark, Material = Enum.Material.SmoothPlastic })
            local mouth = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.42, 0.62, 0.12), Color = dark, Material = Enum.Material.SmoothPlastic })
            local pl = Instance.new("PointLight") pl.Color, pl.Brightness, pl.Range = Color3.fromRGB(190, 150, 255), 0.6, 9 * SC pl.Parent = dome
            local all = { dome, torso, eyeL, eyeR, mouth }
            for _, h in ipairs(hem) do all[#all + 1] = h end
            local t0 = os.clock()
            while dome.Parent do
                local k = (os.clock() - t0) / 2.8
                if k >= 1 then break end
                local now = os.clock()
                local pos = origin + Vector3.new(math.sin(k * 6 + seed) * 1.3, k * 11 + math.sin(k * 9 + seed) * 0.4, math.cos(k * 5 + seed) * 1.3)
                local sway = Vector3.new(math.sin(now * 3 + seed) * 0.12, 0, math.cos(now * 3 + seed) * 0.12)
                dome.Position = sv(pos + Vector3.new(0, 0.45, 0))
                torso.CFrame = CFrame.new(sv(pos + sway)) * CFrame.Angles(0, 0, math.pi / 2)
                for i, h in ipairs(hem) do
                    local ang = i / #hem * math.pi * 2
                    h.Position = sv(pos + sway * 2 + Vector3.new(math.cos(ang) * 0.74, -0.78 + math.sin(now * 6 + i * 1.3 + seed) * 0.16, math.sin(ang) * 0.74))
                end
                local fade = k > 0.6 and (k - 0.6) / 0.4 or 0
                local tr = math.min(1, 0.15 + fade)
                dome.Transparency, torso.Transparency = tr, tr
                for _, h in ipairs(hem) do h.Transparency = tr end
                local face = CFrame.lookAt(dome.Position, workspace.CurrentCamera.CFrame.Position)
                eyeL.CFrame = face * CFrame.new(Vector3.new(-0.3, 0.12, -0.8) * SC)
                eyeR.CFrame = face * CFrame.new(Vector3.new(0.3, 0.12, -0.8) * SC)
                mouth.CFrame = face * CFrame.new(Vector3.new(0, -0.38, -0.78) * SC)
                eyeL.Transparency, eyeR.Transparency, mouth.Transparency = fade, fade, fade
                pl.Brightness = 0.6 * (1 - fade)
                task.wait()
            end
            for _, p in ipairs(all) do p:Destroy() end
        end)
    end

    local function bat(origin, delay)
        task.delay(delay, function()
            local dark = Color3.fromRGB(28, 14, 42)
            local body = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.5), Color = dark, Material = Enum.Material.SmoothPlastic })
            local wl = mk({ Size = Vector3.new(0.85, 0.035, 0.45), Color = dark, Material = Enum.Material.SmoothPlastic })
            local wr = mk({ Size = Vector3.new(0.85, 0.035, 0.45), Color = dark, Material = Enum.Material.SmoothPlastic })
            local dir = Vector3.new(rnd(-1, 1), 0, rnd(-1, 1))
            if dir.Magnitude < 0.1 then dir = Vector3.xAxis end
            dir = dir.Unit
            local spd, ph, t0 = rnd(5, 9), rnd(0, 6), os.clock()
            while body.Parent do
                local k = (os.clock() - t0) / 2.6
                if k >= 1 then break end
                local pos = origin + dir * spd * k * 2 + Vector3.new(0, k * 7 + math.sin(k * 9 + ph) * 0.7, 0)
                local cf = scf(CFrame.lookAt(pos, pos + dir + Vector3.new(0, 0.25, 0)))
                local flap = math.sin((os.clock() - t0) * 26 + ph) * 0.95
                body.CFrame = cf
                wl.CFrame = cf * CFrame.new(-0.5 * SC, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.35 * SC, 0, 0)
                wr.CFrame = cf * CFrame.new(0.5 * SC, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.35 * SC, 0, 0)
                local ft = k > 0.7 and (k - 0.7) / 0.3 or 0
                body.Transparency, wl.Transparency, wr.Transparency = ft, ft, ft
                task.wait()
            end
            body:Destroy() wl:Destroy() wr:Destroy()
        end)
    end

    local function pumpkin(origin, floorY, delay)
        task.delay(delay, function()
            local orange = Color3.fromRGB(255, 125, 25)
            local dark = Color3.fromRGB(30, 8, 0)
            local sz = rnd(0.9, 1.2)
            local body = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(sz * 1.1, sz, sz * 1.1), Color = orange, Position = origin })
            local eyeL = mk({ Size = Vector3.new(0.18, 0.2, 0.08), Color = dark, Material = Enum.Material.SmoothPlastic })
            local eyeR = mk({ Size = Vector3.new(0.18, 0.2, 0.08), Color = dark, Material = Enum.Material.SmoothPlastic })
            local mouth = mk({ Size = Vector3.new(0.5, 0.16, 0.08), Color = dark, Material = Enum.Material.SmoothPlastic })
            local a, d = rnd(0, math.pi * 2), rnd(3, 8)
            local target = Vector3.new(origin.X + math.cos(a) * d, floorY + sz / 2, origin.Z + math.sin(a) * d)
            local t0, T = os.clock(), 1.5
            while body.Parent do
                local k = (os.clock() - t0) / T
                if k >= 1 then break end
                local flat = origin:Lerp(target, k)
                local y = floorY + sz / 2 + math.abs(math.sin(k * math.pi * 2.5)) * (1 - k) * 4.5
                if k < 0.25 then y = y + (0.25 - k) * 10 end
                local pos = Vector3.new(flat.X, y, flat.Z)
                body.Position = sv(pos)
                local face = CFrame.lookAt(body.Position, workspace.CurrentCamera.CFrame.Position)
                eyeL.CFrame = face * CFrame.new(Vector3.new(-0.2, 0.12, -sz * 0.5) * SC)
                eyeR.CFrame = face * CFrame.new(Vector3.new(0.2, 0.12, -sz * 0.5) * SC)
                mouth.CFrame = face * CFrame.new(Vector3.new(0, -0.14, -sz * 0.5) * SC)
                task.wait()
            end
            burst(usv(body.Position), { c0 = orange, c1 = Color3.fromRGB(255, 220, 90), count = 16, s0 = 4, s1 = 11, size = 0.4, l0 = 0.5, l1 = 1.1, acc = Vector3.new(0, -14, 0) })
            body:Destroy() eyeL:Destroy() eyeR:Destroy() mouth:Destroy()
        end)
    end

    local function fxHaunt(c, pos, col, feetY, near)
        local orange, purple = Color3.fromRGB(255, 125, 25), Color3.fromRGB(165, 85, 255)
        local floor = Vector3.new(pos.X, feetY, pos.Z)
        light(pos, orange, 4, 26, 1.8)
        thinRing(floor, orange, 0.4, 7, 1.0, { thick = 0.07 })
        thinRing(floor, purple, 0.3, 5, 0.8, { thick = 0.05 })
        burst(pos, { tex = FIRE, c0 = purple, c1 = orange, le = 0.7, count = 26, s0 = 2, s1 = 8, size = 2.2, size1 = 0.3, l0 = 0.8, l1 = 1.6, acc = Vector3.new(0, 6, 0), spread = Vector2.new(70, 70), t0 = 0.3 })
        local g, parts = ghostOf(c, purple, Enum.Material.ForceField, 0.1)
        if g then
            for _, p in ipairs(parts) do tw(p, 0.9, { Transparency = 1, Size = p.Size * 1.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
            life(g, 1)
        end
        for i = 1, 3 do spirit(pos + Vector3.new(rnd(-0.6, 0.6), 0.5, rnd(-0.6, 0.6)), (i - 1) * 0.18, i * 2.1) end
        for i = 1, 6 do bat(pos + Vector3.new(0, 1, 0), (i - 1) * 0.08) end
        for i = 1, 4 do pumpkin(pos, feetY, (i - 1) * 0.05) end
        local candy = { Color3.fromRGB(255, 90, 160), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 220, 70), Color3.fromRGB(180, 110, 255) }
        for i = 1, 14 do
            local cd = mk({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.22, 0.22), Color = candy[i % 4 + 1], Position = pos })
            if i <= 5 then trailOn(cd, cd.Color, WHITE, 0.5, 0.08) end
            local a, d = rnd(0, math.pi * 2), rnd(3, 9)
            local peak = pos + Vector3.new(math.cos(a) * d * 0.5, rnd(4, 8), math.sin(a) * d * 0.5)
            local land = Vector3.new(pos.X + math.cos(a) * d, feetY + 0.2, pos.Z + math.sin(a) * d)
            tw(cd, 0.45, { Position = peak, Orientation = Vector3.new(rnd(0, 360), rnd(0, 360), 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.delay(0.45, function()
                if cd.Parent then tw(cd, 0.6, { Position = land }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out) end
            end)
            task.delay(1.9, function() if cd.Parent then tw(cd, 0.6, { Transparency = 1 }) end end)
            life(cd, 2.7)
        end
        killText(pos, "BOO!", orange)
    end

    --=== SAKURA BLOOM =====================================================
    -- the body dissolves into petals that swirl up and rain down, a glowing flower opens on the floor
    local function fxSakura(c, pos, col, feetY)
        local floor = Vector3.new(pos.X, feetY, pos.Z)
        local palette = { Color3.fromRGB(255, 170, 205), Color3.fromRGB(255, 205, 225), Color3.fromRGB(255, 235, 242), Color3.fromRGB(240, 120, 175) }
        light(pos, palette[1], 2.5, 22, 1.8)
        thinRing(floor, palette[1], 0.4, 6, 1.0, { thick = 0.05 })
        local g, parts = ghostOf(c, palette[1], Enum.Material.ForceField, 0.1)
        if g then
            for _, p in ipairs(parts) do tw(p, 0.9, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
            life(g, 1)
        end
        -- petals
        local petals = {}
        for i = 1, 84 do
            local pt = mk({ Size = Vector3.new(0.3, 0.03, 0.2), Color = palette[i % 4 + 1], Material = Enum.Material.Neon, Transparency = 0.1 })
            petals[i] = {
                part = pt, delay = rnd(0, 0.5), a0 = rnd(0, math.pi * 2), r0 = rnd(0.2, 0.9), y0 = rnd(-2.4, 2.4),
                spin = rnd(4, 8), rise = rnd(6, 11), sx = rnd(2, 5), sy = rnd(2, 5), sz = rnd(2, 5),
            }
        end
        -- flower
        local flower = {}
        for layer = 1, 3 do
            for i = 1, 8 do
                local len = 1.1 + layer * 0.45
                flower[#flower + 1] = {
                    part = mk({ Size = Vector3.new(0.5 + layer * 0.08, 0.04, len), Color = palette[layer], Material = Enum.Material.Neon, Transparency = 0.1 }),
                    yaw = i / 8 * math.pi * 2 + layer * 0.4, len = len, layer = layer,
                }
            end
        end
        local core = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, Color = Color3.fromRGB(255, 225, 130), Position = floor + Vector3.new(0, 0.3, 0) })
        life(core, 3.4)
        task.spawn(function()
            local t0 = os.clock()
            local T = 3.4
            while petals[1].part.Parent do
                local el = os.clock() - t0
                if el >= T then break end
                local ps, cfs = {}, {}
                for _, pe in ipairs(petals) do
                    local k = math.clamp((el - pe.delay) / (T - 0.6), 0, 1)
                    local y = pe.y0 + k * pe.rise - (k ^ 2) * pe.rise * 0.9
                    local rad = pe.r0 + k * 3.4
                    local ang = pe.a0 + k * 6
                    ps[#ps + 1] = pe.part
                    cfs[#cfs + 1] = CFrame.new(sv(pos + Vector3.new(math.cos(ang) * rad, y, math.sin(ang) * rad))) * CFrame.Angles(el * pe.sx, el * pe.sy, el * pe.sz)
                    pe.part.Transparency = k > 0.65 and 0.1 + (k - 0.65) / 0.35 * 0.9 or 0.1
                end
                for _, fl in ipairs(flower) do
                    local open = math.clamp(el / 0.9, 0, 1)
                    local tilt = math.rad(80 - 62 * open)
                    ps[#ps + 1] = fl.part
                    cfs[#cfs + 1] = CFrame.new(sv(floor + Vector3.new(0, 0.06 + fl.layer * 0.03, 0))) * CFrame.Angles(0, fl.yaw, 0) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 0, -fl.len / 2 * SC)
                    fl.part.Transparency = el > 2.2 and 0.1 + (el - 2.2) / 1.2 * 0.9 or 0.1
                end
                workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged)
                core.Transparency = el > 2.2 and (el - 2.2) / 1.2 or 0
                task.wait()
            end
            for _, pe in ipairs(petals) do pe.part:Destroy() end
            for _, fl in ipairs(flower) do fl.part:Destroy() end
        end)
        burst(pos, { c0 = palette[1], c1 = WHITE, count = 26, s0 = 1, s1 = 5, size = 0.35, l0 = 1.4, l1 = 2.6, acc = Vector3.new(0, 3, 0), spread = Vector2.new(70, 70) })
    end

    return {
        ["Soul Ascend"] = fxSoul, ["Black Hole"] = fxBlackHole, ["Thunder Smite"] = fxThunder,
        ["Crystal Shatter"] = fxCrystal, ["Haunt"] = fxHaunt, ["Sakura Bloom"] = fxSakura,
        text = killText,
    }
    end

    local pool = { "Soul Ascend", "Black Hole", "Thunder Smite", "Crystal Shatter", "Haunt", "Sakura Bloom" }
    local known = {}
    for _, n in ipairs(pool) do known[n] = true end

    killEffect = function(victim, mine)
        local c, r = char(victim), hrpOf(victim)
        if not (c and r) or not fxBudget() then return end
        local pos = r.Position
        local col = F.kfRole and (ROLE_COLORS[getRole(victim)] or F.kfColor) or F.kfColor
        local style = F.kfStyle
        if style == "Random" or not known[style] then style = pool[math.random(#pool)] end
        local mine3 = hrpOf(lp)
        local dist = mine3 and (mine3.Position - pos).Magnitude or 0
        local near = mine or dist < 45
        local feetY = groundY(pos, c)
        local effects = kfBuild(math.clamp(F.kfSpeed or 1, 0.25, 4), math.clamp(F.kfScale or 1, 0.25, 4), Vector3.new(pos.X, feetY, pos.Z))
        local ok, err = pcall(effects[style], c, pos, col, feetY, near)
        if not ok then dbg("killEffect " .. style .. " ERR " .. tostring(err)) end

        if F.kfText and style ~= "Haunt" then effects.text(pos, "☠ " .. victim.DisplayName, col) end
        if F.kfShake then
            shake(mine and 2.2 or math.clamp(1.4 - dist / 80, 0.2, 1.4))
        end
        if F.kfFlash and mine and style ~= "Thunder Smite" and style ~= "Black Hole" then screenFlash(col, 0.25) end
    end
end

local diedAt = {}
local function hookDeath(p)
    local function onChar(c)
        local h = c:WaitForChild("Humanoid", 10)
        if not h then return end
        h.Died:Connect(function()
            if F.sndPlay and alive then
                local role = getRole(p)
                local killer = (role == "Murderer") and (findByRole("Sheriff") or findByRole("Hero")) or findByRole("Murderer")
                F.sndPlay("kill", killer == lp)
            end
            if not (F.killFx and alive) then return end
            if os.clock() - (diedAt[p] or 0) < 1 then return end
            diedAt[p] = os.clock()
            local role = getRole(p)
            local killer = (role == "Murderer") and (findByRole("Sheriff") or findByRole("Hero")) or findByRole("Murderer")
            local mine = killer == lp
            if F.kfMode == "Only my kills" and not mine then return end
            if F.kfMode == "Exclude me" and p == lp then return end
            task.spawn(function()
                local ok, err = pcall(killEffect, p, mine)
                dlog("killEffect " .. p.Name .. " ok=" .. tostring(ok) .. (ok and "" or (" " .. tostring(err))))
            end)
        end)
    end
    if p.Character then task.spawn(onChar, p.Character) end
    track(p.CharacterAdded:Connect(onChar))
end
for _, p in ipairs(Players:GetPlayers()) do hookDeath(p) end
track(Players.PlayerAdded:Connect(hookDeath))

--=== AURAS / TRAIL ====================================================
local OBJECT_STYLES = { "Orbs", "Gyroscope", "Helix", "Constellation", "Fireflies", "Light Wings" }
local auras = {}

local function clearAura(c)
    local a = auras[c]
    if not a then return end
    for _, o in ipairs(a.objs) do pcall(function() o:Destroy() end) end
    auras[c] = nil
end

local function mkEmitter(parent, cfg)
    local e = Instance.new("ParticleEmitter")
    e.Texture = cfg.tex or "rbxasset://textures/particles/sparkles_main.dds"
    e.Color = ColorSequence.new(cfg.c0, cfg.c1 or cfg.c0)
    e.LightEmission = cfg.le or 1
    e.Rate = cfg.rate or 30
    e.Lifetime = NumberRange.new(cfg.l0 or 0.6, cfg.l1 or 1.3)
    e.Speed = NumberRange.new(cfg.s0 or 1, cfg.s1 or 3)
    e.SpreadAngle = cfg.spread or Vector2.new(25, 25)
    if cfg.keep then
        e.Size = NumberSequence.new(cfg.size or 0.6)
    else
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, cfg.size or 0.6), NumberSequenceKeypoint.new(1, 0) })
    end
    e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, cfg.t0 or 0.1), NumberSequenceKeypoint.new(0.8, cfg.t0 or 0.1), NumberSequenceKeypoint.new(1, 1) })
    e.Acceleration = cfg.acc or Vector3.zero
    e.RotSpeed = NumberRange.new(-120, 120)
    e.EmissionDirection = cfg.dir or Enum.NormalId.Top
    if cfg.shape then e.Shape = cfg.shape end
    e.Parent = parent
    return e
end

-- shared pieces for the object styles: a glowing orb (hot core inside two soft shells) and a light beam between two orbs
function FXH.auOrb(add, size, color, o)
    o = o or {}
    local white = Color3.new(1, 1, 1)
    local b = { size = size, k = 1, col = color }
    b.core = add(mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.4, Color = white }))
    b.s1 = add(mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = color, Transparency = 0.7 }))
    b.s2 = add(mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 1.9, Color = color, Transparency = 0.9 }))
    if o.light then
        local pl = Instance.new("PointLight") pl.Color, pl.Brightness, pl.Range = color, 0.9, 8 pl.Parent = b.core
        b.pl = pl
    end
    if o.trail then
        b.tr1 = FXH.trailOn(b.core, color, color:Lerp(white, 0.5), o.trail, size * 0.22, 0.3)
        b.tr2 = FXH.trailOn(b.core, white, color, o.trail * 0.6, size * 0.07, 0.1)
    end
    if o.spark then
        local em = Instance.new("ParticleEmitter")
        em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        em.Color = ColorSequence.new(white, color)
        em.LightEmission = 1
        em.Rate = 10
        em.Lifetime = NumberRange.new(0.6, 1.1)
        em.Speed = NumberRange.new(0.2, 0.8)
        em.SpreadAngle = Vector2.new(180, 180)
        em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.32), NumberSequenceKeypoint.new(1, 0) })
        em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
        em.Parent = b.core
        b.em = em
    end
    return b
end

function FXH.auPut(b, pos, col, k)
    k = k or 1
    b.core.Position, b.s1.Position, b.s2.Position = pos, pos, pos
    if math.abs(b.k - k) > 0.01 then
        b.k = k
        local sz = b.size * k
        b.core.Size, b.s1.Size, b.s2.Size = Vector3.one * sz * 0.4, Vector3.one * sz, Vector3.one * sz * 1.9
    end
    if b.col ~= col then
        b.col = col
        local white = Color3.new(1, 1, 1)
        b.s1.Color, b.s2.Color = col, col
        if b.pl then b.pl.Color = col end
        if b.tr1 then
            b.tr1.Color = ColorSequence.new(col, col:Lerp(white, 0.45))
            b.tr2.Color = ColorSequence.new(white, col)
        end
        if b.em then b.em.Color = ColorSequence.new(white, col) end
    end
end

function FXH.auBeam(c0, c1, width, color)
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = c0, c1
    local b = Instance.new("Beam")
    b.Attachment0, b.Attachment1 = a0, a1
    b.Width0, b.Width1 = width, width
    b.LightEmission = 1
    b.FaceCamera = true
    b.Segments = 1
    b.Color = ColorSequence.new(color)
    b.Transparency = NumberSequence.new(0.5)
    b.Parent = c0
    return b
end

local function buildAura(c, style, color, scale)
    local a = { style = style, scale = scale, objs = {}, color = color }
    local function add(o) a.objs[#a.objs + 1] = o return o end
    a.core = add(mk({ Transparency = 1 }))
    if style == "Orbs" then
        -- glowing orbs on slow 3D orbits: a hot core inside two soft shells, two ribbons behind and drifting dust
        a.orbs = {}
        for i = 1, 5 do
            local core = add(mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3 * scale, Color = Color3.new(1, 1, 1) }))
            local s1 = add(mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.75 * scale, Color = color, Transparency = 0.7 }))
            local s2 = add(mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4 * scale, Color = color, Transparency = 0.9 }))
            local pl = Instance.new("PointLight") pl.Color, pl.Brightness, pl.Range = color, 0.9, 8 pl.Parent = core
            local tr1 = FXH.trailOn(core, color, color:Lerp(Color3.new(1, 1, 1), 0.5), 0.38, 0.14 * scale, 0.3)
            local tr2 = FXH.trailOn(core, Color3.new(1, 1, 1), color, 0.22, 0.045 * scale, 0.1)
            local em = Instance.new("ParticleEmitter")
            em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            em.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
            em.LightEmission = 1
            em.Rate = 14
            em.Lifetime = NumberRange.new(0.6, 1.1)
            em.Speed = NumberRange.new(0.2, 0.8)
            em.SpreadAngle = Vector2.new(180, 180)
            em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22 * scale), NumberSequenceKeypoint.new(1, 0) })
            em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
            em.Parent = core
            a.orbs[i] = { core = core, s1 = s1, s2 = s2, pl = pl, tr1 = tr1, tr2 = tr2, em = em, ph = i / 5 * math.pi * 2 }
        end
    elseif style == "Gyroscope" then
        -- three tilted orbits with two glowing orbs on each; every orb draws a short arc behind it, so the rings weave themselves
        a.gy = {}
        for ri = 1, 3 do
            for k = 0, 1 do
                a.gy[#a.gy + 1] = { o = FXH.auOrb(add, 0.55 * scale, color, { trail = 0.75, spark = true, light = (k == 0) }), ri = ri, ph = k * math.pi, R = (2.5 + 0.45 * ri) * scale }
            end
        end
    elseif style == "Helix" then
        -- two strands of orbs spiral up the body and fade out at the top; light rungs join each pair
        a.hx = { A = {}, B = {}, rung = {}, last = {} }
        for i = 1, 5 do
            local oa = FXH.auOrb(add, 0.5 * scale, color, { trail = 0.55 })
            local ob = FXH.auOrb(add, 0.5 * scale, color, { trail = 0.55 })
            a.hx.A[i], a.hx.B[i] = oa, ob
            a.hx.rung[i] = FXH.auBeam(oa.core, ob.core, 0.035, color)
            a.hx.last[i] = 0
        end
    elseif style == "Constellation" then
        -- eight slow stars; any two that drift close are joined by a thread of light
        a.cs = { stars = {}, beams = {} }
        for i = 1, 8 do
            a.cs.stars[i] = FXH.auOrb(add, (0.28 + (i % 3) * 0.07) * scale, color, { spark = true, light = (i % 3 == 0) })
        end
        for i = 1, 7 do
            for j = i + 1, 8 do
                a.cs.beams[#a.cs.beams + 1] = { i = i, j = j, b = FXH.auBeam(a.cs.stars[i].core, a.cs.stars[j].core, 0.03, color) }
            end
        end
    elseif style == "Fireflies" then
        -- a handful of glowing flies wandering on smooth noise, with a little drifting dust
        a.ff = {}
        for i = 1, 9 do
            a.ff[i] = { o = FXH.auOrb(add, 0.5 * scale, color, { light = (i % 3 == 1), spark = true }), seed = i * 17.3 }
        end
        a.core.Size = Vector3.one * 7 * scale
        a.dust = mkEmitter(a.core, { c0 = color, rate = 5, s0 = 0.1, s1 = 0.4, size = 0.16, l0 = 2, l1 = 3.5, spread = Vector2.new(180, 180), shape = Enum.ParticleEmitterShape.Sphere })
    elseif style == "Light Wings" then
        -- wings drawn with light: an arm sweeps up and out, and three layers of tapering feather-blades hang from it,
        -- beating in a wave and shedding glints
        local rows = {
            { n = 9, lenK = 1.0, w = 0.26, tr = 0.18, zoff = 0, glow = true },
            { n = 8, lenK = 0.62, w = 0.2, tr = 0.3, zoff = 0.06 },
            { n = 7, lenK = 0.34, w = 0.15, tr = 0.42, zoff = 0.12 },
        }
        a.wg = { feathers = {}, bones = {} }
        a.core.Size = Vector3.new(0.3, 0.3, 0.3)
        for sd = -1, 1, 2 do
            -- the bone: shoulder, elbow, wrist and fingertip joined by light, with a glowing orb at each joint
            local bone = { side = sd, atts = {}, orbs = {} }
            for i = 1, 4 do
                bone.atts[i] = Instance.new("Attachment") bone.atts[i].Parent = a.core
                bone.orbs[i] = FXH.auOrb(add, (i == 1 and 0.55 or 0.45) * scale, color, { light = (i == 3), spark = (i == 4) })
            end
            bone.beams = {}
            for i = 1, 3 do
                for layer = 1, 2 do
                    local b = Instance.new("Beam")
                    b.Attachment0, b.Attachment1 = bone.atts[i], bone.atts[i + 1]
                    b.Width0, b.Width1 = (layer == 1 and 0.26 or 0.7) * scale * (1.2 - i * 0.2), (layer == 1 and 0.2 or 0.55) * scale * (1.2 - i * 0.2)
                    b.LightEmission = 1
                    b.FaceCamera = true
                    b.Segments = 1
                    b.Color = ColorSequence.new(color)
                    b.Transparency = NumberSequence.new(layer == 1 and 0 or 0.7)
                    b.Parent = a.core
                    bone.beams[#bone.beams + 1] = b
                end
            end
            a.wg.bones[#a.wg.bones + 1] = bone
            for ri, row in ipairs(rows) do
                for k = 1, row.n do
                    local u = (k - 1) / (row.n - 1)
                    local root = Instance.new("Attachment") root.Parent = a.core
                    local tip = Instance.new("Attachment") tip.Parent = a.core
                    local function beam(w, tr0)
                        local b = Instance.new("Beam")
                        b.Attachment0, b.Attachment1 = root, tip
                        b.Width0, b.Width1 = w * scale, 0.04
                        b.LightEmission = 1
                        b.FaceCamera = true
                        b.Segments = 1
                        b.Color = ColorSequence.new(color)
                        b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, tr0), NumberSequenceKeypoint.new(0.6, math.min(1, tr0 + 0.12)), NumberSequenceKeypoint.new(1, 1) })
                        b.Parent = a.core
                        return b
                    end
                    local fe = { root = root, tip = tip, side = sd, u = u, row = ri, zoff = row.zoff, len = (2.6 + 1.2 * math.sin(u * math.pi * 0.9 + 0.15)) * row.lenK * scale, beams = { beam(row.w, row.tr) } }
                    if row.glow then fe.beams[2] = beam(row.w * 2.4, 0.84) end
                    if ri == 1 and (k == 3 or k == 7) then
                        local em = Instance.new("ParticleEmitter")
                        em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                        em.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
                        em.LightEmission = 1
                        em.Rate = 5
                        em.Lifetime = NumberRange.new(1.2, 2.0)
                        em.Speed = NumberRange.new(0.1, 0.5)
                        em.SpreadAngle = Vector2.new(180, 180)
                        em.Acceleration = Vector3.new(0, -1.6, 0)
                        em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2 * scale), NumberSequenceKeypoint.new(1, 0) })
                        em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
                        em.Parent = tip
                        fe.em = em
                    end
                    a.wg.feathers[#a.wg.feathers + 1] = fe
                end
            end
        end
    end
    auras[c] = a
end

local function updateAura(c, a, t)
    local r = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not r then return end
    local s = a.scale
    local col = a.rainbow and rainbowAt(t) or a.color
    local feet = r.Position - Vector3.new(0, (hum and hum.HipHeight or 2) + r.Size.Y / 2 - 0.15, 0)
    local style = a.style
    if style == "Orbs" then
        local white = Color3.new(1, 1, 1)
        for i, o in ipairs(a.orbs) do
            local ph = o.ph
            local ang = t * (1.3 + 0.12 * (i % 3)) + ph
            local R = (2.8 + math.sin(t * 0.7 + ph * 2) * 0.55) * s
            local y = math.sin(t * 1.15 + ph * 1.7) * 1.35 + math.sin(t * 2.2 + ph) * 0.2
            local pos = r.Position + Vector3.new(math.cos(ang) * R, y, math.sin(ang) * R)
            o.core.Position, o.s1.Position, o.s2.Position = pos, pos, pos
            o.s1.Size = Vector3.one * 0.75 * s * (1 + math.sin(t * 5 + ph) * 0.12)
            o.s1.Color, o.s2.Color, o.pl.Color = col, col, col
            o.tr1.Color = ColorSequence.new(col, col:Lerp(white, 0.4))
            o.tr2.Color = ColorSequence.new(white, col)
            o.em.Color = ColorSequence.new(white, col)
        end
    elseif style == "Gyroscope" then
        local center = CFrame.new(r.Position)
        local bases = {
            CFrame.Angles(t * 0.6, 0, 0),
            CFrame.Angles(0, 0, t * 0.5 + 1.0),
            CFrame.Angles(math.rad(55), t * 0.4, 0),
        }
        for _, g in ipairs(a.gy) do
            local ang = t * (1.5 + 0.3 * g.ri) + g.ph
            local cf = center * bases[g.ri] * CFrame.new(math.cos(ang) * g.R, 0, math.sin(ang) * g.R)
            FXH.auPut(g.o, cf.Position, col)
        end
    elseif style == "Helix" then
        local hx = a.hx
        local n = #hx.A
        for i = 1, n do
            local k = (t * 0.2 + i / n) % 1
            local fade = math.sin(k * math.pi) ^ 0.6
            if k < hx.last[i] then
                pcall(function() hx.A[i].tr1:Clear() hx.A[i].tr2:Clear() hx.B[i].tr1:Clear() hx.B[i].tr2:Clear() end)
            end
            hx.last[i] = k
            local ang = t * 1.9 + k * 5
            local R = 1.7 * s
            local off = Vector3.new(math.cos(ang) * R, 0, math.sin(ang) * R)
            local mid = r.Position + Vector3.new(0, (-2.2 + k * 4.6) * s, 0)
            FXH.auPut(hx.A[i], mid + off, col, fade)
            FXH.auPut(hx.B[i], mid - off, col, fade)
            hx.rung[i].Color = ColorSequence.new(col)
            hx.rung[i].Transparency = NumberSequence.new(1 - fade * 0.55)
        end
    elseif style == "Constellation" then
        local cs = a.cs
        local center = r.Position + Vector3.new(0, 0.6, 0)
        local pos3 = {}
        for i, st in ipairs(cs.stars) do
            local ang = t * (0.35 + (i % 3) * 0.12) + i * 2.4
            local inc = t * (0.5 + (i % 4) * 0.1) + i * 1.7
            local R = (3.0 + math.sin(t * 0.8 + i) * 0.4) * s
            pos3[i] = center + Vector3.new(math.cos(ang) * math.cos(inc), math.sin(inc) * 0.9, math.sin(ang) * math.cos(inc)) * R
            FXH.auPut(st, pos3[i], col, 1 + math.sin(t * 2 + i * 1.3) * 0.12)
        end
        local reach = 4.8 * s
        for _, l in ipairs(cs.beams) do
            local d = (pos3[l.i] - pos3[l.j]).Magnitude
            if d < reach then
                l.b.Enabled = true
                l.b.Color = ColorSequence.new(col)
                l.b.Transparency = NumberSequence.new(0.35 + (d / reach) * 0.6)
            else
                l.b.Enabled = false
            end
        end
    elseif style == "Fireflies" then
        a.core.Position = r.Position
        a.dust.Color = ColorSequence.new(col)
        for _, f in ipairs(a.ff) do
            local sd = f.seed
            local nx = math.noise(t * 0.22, sd, 0) * 2
            local ny = math.noise(t * 0.22, sd, 7.7) * 2
            local nz = math.noise(t * 0.22, sd, 15.3) * 2
            local pos = r.Position + Vector3.new(nx * 3.4, ny * 1.9 + 0.4, nz * 3.4) * s
            local glow = 0.7 + 0.3 * math.sin(t * 3.2 + sd)
            FXH.auPut(f.o, pos, col, glow)
        end
    elseif style == "Light Wings" then
        local white = Color3.new(1, 1, 1)
        a.core.CFrame = r.CFrame * CFrame.new(0, 0.7, 0.45)
        local recolor = a.wcol ~= col
        a.wcol = col
        local grad = ColorSequence.new(col:Lerp(white, 0.25), col)
        local sc = a.scale
        for _, bn in ipairs(a.wg.bones) do
            local sd = bn.side
            for i = 1, 4 do
                local u = (i - 1) / 3
                local psi = math.sin(t * 2.0 - u * 0.8 - 0.25) * 0.26 * (0.35 + u * 0.65)
                local c, s2 = math.cos(sd * psi), math.sin(sd * psi)
                local v = Vector3.new(sd * (0.3 + 3.0 * u), 0.15 + 1.9 * u ^ 0.85, 0) * sc
                local p = Vector3.new(v.X * c - v.Y * s2, v.X * s2 + v.Y * c, v.Z)
                bn.atts[i].Position = p
                FXH.auPut(bn.orbs[i], (a.core.CFrame * CFrame.new(p)).Position, col)
            end
            if recolor then for _, b in ipairs(bn.beams) do b.Color = ColorSequence.new(col:Lerp(white, 0.65), col:Lerp(white, 0.2)) end end
        end
        for _, fe in ipairs(a.wg.feathers) do
            local sd, u = fe.side, fe.u
            local psi = math.sin(t * 2.0 - u * 0.8 - fe.row * 0.25) * 0.26 * (0.35 + u * 0.65)
            local function rz(v)
                local c, s2 = math.cos(sd * psi), math.sin(sd * psi)
                return Vector3.new(v.X * c - v.Y * s2, v.X * s2 + v.Y * c, v.Z)
            end
            -- the arm: out and up from the shoulder; the feather hangs from a point on it, swept outward and back
            local arm = Vector3.new(sd * (0.3 + 3.0 * u), 0.15 + 1.9 * u ^ 0.85, fe.zoff) * sc
            local dir = Vector3.new(sd * (0.55 + 0.35 * u), -1, 0.3).Unit
            local rootP = rz(arm)
            fe.root.Position = rootP
            fe.tip.Position = rootP + rz(dir) * fe.len
            if recolor then
                for _, b in ipairs(fe.beams) do b.Color = grad end
                if fe.em then fe.em.Color = ColorSequence.new(white, col) end
            end
        end
    end
end

-- player trail: four looks (Ribbon, Comet, Stardust, Ripples)
local trailObjs, trailRefs, trailKey = {}, {}, nil
local function clearTrail()
    for _, o in ipairs(trailObjs) do pcall(function() o:Destroy() end) end
    trailObjs, trailRefs, trailKey = {}, {}, nil
end
local function updateTrail()
    local r = hrpOf(lp)
    if not (F.trail and r) then
        if trailKey then clearTrail() end
        return
    end
    local style = F.trailStyle
    local key = style .. tostring(r)
    local white = Color3.new(1, 1, 1)
    if key ~= trailKey then
        clearTrail()
        trailKey = key
        local function att(y)
            local x = Instance.new("Attachment")
            x.Position = Vector3.new(0, y, 0)
            x.Parent = r
            trailObjs[#trailObjs + 1] = x
            return x
        end
        local function ribbon(y0, y1, lifetime, alpha0, kind)
            local tr = Instance.new("Trail")
            tr.Attachment0, tr.Attachment1 = att(y0), att(y1)
            tr.Lifetime = lifetime
            tr.LightEmission = 1
            tr.MinLength = 0.05
            tr.FaceCamera = true
            tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha0), NumberSequenceKeypoint.new(1, 1) })
            tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.05) })
            tr.Parent = r
            trailObjs[#trailObjs + 1] = tr
            trailRefs[#trailRefs + 1] = { trail = tr, kind = kind }
        end
        local function sparkle(y, rate, size, lifeLo, lifeHi, accY)
            local holder = att(y)
            local em = Instance.new("ParticleEmitter")
            em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            em.LightEmission = 1
            em.Rate = rate
            em.Lifetime = NumberRange.new(lifeLo, lifeHi)
            em.Speed = NumberRange.new(0.3, 1.2)
            em.SpreadAngle = Vector2.new(180, 180)
            em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
            em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
            em.Acceleration = Vector3.new(0, accY, 0)
            em.RotSpeed = NumberRange.new(-120, 120)
            em.Parent = holder
            trailRefs[#trailRefs + 1] = { emitter = em }
        end
        if style == "Ribbon" then
            ribbon(1.6, -2.0, 1.3, 0.55, "soft")
            ribbon(0.25, -0.05, 0.95, 0.05, "core")
            ribbon(1.2, 1.0, 1.7, 0.2, "line")
            ribbon(-0.2, -0.4, 1.7, 0.2, "line")
            ribbon(-1.5, -1.7, 1.7, 0.2, "line")
        elseif style == "Comet" then
            ribbon(1.2, -1.6, 2.1, 0.45, "soft")
            ribbon(0.4, 0.0, 1.5, 0.05, "core")
            sparkle(0, 34, 0.4, 0.7, 1.3, 1.5)
        elseif style == "Stardust" then
            ribbon(0.3, 0.0, 0.9, 0.55, "soft")
            sparkle(-1.4, 55, 0.38, 1.0, 1.7, 0.4)
            sparkle(0.6, 25, 0.28, 0.8, 1.3, 0.8)
        end
    end
    local keys = {}
    if F.trailRainbow then
        local t = os.clock()
        for i = 0, 5 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 5, Color3.fromHSV((t * 0.3 + i / 6) % 1, 0.85, 1)) end
    end
    for _, ref in ipairs(trailRefs) do
        if ref.trail then
            if ref.kind == "core" then
                ref.trail.Color = ColorSequence.new(white, F.trailRainbow and Color3.fromHSV((os.clock() * 0.3) % 1, 0.5, 1) or F.trailColor:Lerp(white, 0.5))
            elseif F.trailRainbow then
                ref.trail.Color = ColorSequence.new(keys)
            else
                ref.trail.Color = ColorSequence.new(F.trailColor, F.trailColor:Lerp(white, 0.45))
            end
        elseif ref.emitter then
            ref.emitter.Color = ColorSequence.new(white, F.trailRainbow and Color3.fromHSV((os.clock() * 0.3) % 1, 0.8, 1) or F.trailColor)
        end
    end
end
-- Ripples: thin rings spread over the floor from your feet while you move
task.spawn(function()
    while alive do
        if F.trail and F.trailStyle == "Ripples" then
            pcall(function()
                local r, h = hrpOf(lp), humOf(lp)
                if not (r and h) then return end
                local v = r.AssemblyLinearVelocity
                if Vector3.new(v.X, 0, v.Z).Magnitude > 2 and fxBudget() then
                    local feetPos = r.Position - Vector3.new(0, h.HipHeight + r.Size.Y / 2 - 0.1, 0)
                    local col = F.trailRainbow and rainbowAt(os.clock()) or F.trailColor
                    FXH.thinRing(feetPos, col, 0.2, 2.3, 0.85, { thick = 0.045, segs = 36 })
                    FXH.thinRing(feetPos, Color3.new(1, 1, 1), 0.1, 1.2, 0.55, { thick = 0.03, segs = 28 })
                end
            end)
        end
        task.wait(0.2)
    end
end)
onCleanup(function() F.trail = false pcall(clearTrail) end)

task.spawn(function()
    while alive do
        pcall(function()
            local want = {}
            if F.aura and lp.Character and visAlive(lp) then
                want[lp.Character] = { F.auStyle, F.auColor, F.auRainbow, F.auScale }
            end
            for c in pairs(auras) do if not want[c] or not c.Parent then clearAura(c) end end
            for c, w in pairs(want) do
                local a = auras[c]
                if a and (a.style ~= w[1] or a.scale ~= w[4]) then clearAura(c) a = nil end
                if not a then buildAura(c, w[1], w[2], w[4]) a = auras[c] end
                if a then a.color, a.rainbow = w[2], w[3] end
            end
            updateTrail()
        end)
        task.wait(0.25)
    end
end)
onCleanup(function() for c in pairs(auras) do clearAura(c) end end)

--=== JUMP EFFECTS =====================================================
-- thin rings and a few motes where you take off and land; the harder the fall, the wider the wave
do
    local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
    local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local WHITE = Color3.new(1, 1, 1)
    F.jfxStyle = F.jfxStyle or "Ripple"
    F.jfxMode = F.jfxMode or "Custom"
    F.jfxColor = F.jfxColor or Color3.fromRGB(150, 205, 255)
    F.jfxSize = F.jfxSize or 1
    if F.jfxTakeoff == nil then F.jfxTakeoff = true end

    local function colorFor(p)
        if F.jfxMode == "Rainbow" then return rainbowAt(os.clock() * 1.5) end
        if F.jfxMode == "By Role" then return ROLE_COLORS[getRole(p)] or F.jfxColor end
        return F.jfxColor
    end
    local function feetOf(r, h)
        return Vector3.new(r.Position.X, r.Position.Y - ((h and h.HipHeight or 2) + r.Size.Y / 2) + 0.08, r.Position.Z)
    end

    local function landing(p, r, h, power)
        if not fxBudget() then return end
        local col = colorFor(p)
        local k = math.clamp(power / 55, 0.35, 1.3) * (F.jfxSize or 1)
        local floor = feetOf(r, h)
        local up = Vector3.new(0, 0.15, 0)
        local style = F.jfxStyle
        if style == "Shockwave" then
            FXH.thinRing(floor, col, 0.4, 3.4 + 5.2 * k, 0.75, { thick = 0.07, segs = 52 })
            FXH.thinRing(floor, WHITE, 0.3, 2.2 + 3.4 * k, 0.55, { thick = 0.04, segs = 44 })
            FXH.burst(floor + up, { tex = SMOKE, c0 = Color3.fromRGB(196, 186, 176), le = 0, count = 8 + math.floor(10 * k), s0 = 3, s1 = 8 * k + 2, size = 0.9 * k, size1 = 2.4 * k, l0 = 0.5, l1 = 1.1, t0 = 0.62, acc = Vector3.new(0, 0.6, 0), spread = Vector2.new(86, 86) })
        elseif style == "Stardust" then
            FXH.thinRing(floor, col, 0.2, 1.8 + 2.6 * k, 0.8, { thick = 0.035, segs = 40 })
            FXH.burst(floor + up, { c0 = WHITE, c1 = col, count = 14 + math.floor(18 * k), s0 = 3, s1 = 9 * k + 2, size = 0.26, l0 = 0.7, l1 = 1.5, acc = Vector3.new(0, -4, 0), spread = Vector2.new(75, 75) })
            FXH.burst(floor + up, { c0 = col, c1 = WHITE, count = 5, s0 = 0.5, s1 = 1.6, size = 0.5, l0 = 1, l1 = 1.8, acc = Vector3.new(0, 1.5, 0), spread = Vector2.new(40, 40) })
        elseif style == "Petals" then
            FXH.thinRing(floor, col:Lerp(WHITE, 0.4), 0.3, 2 + 2.8 * k, 0.85, { thick = 0.03, segs = 36 })
            FXH.burst(floor + up, { tex = SMOKE, c0 = col:Lerp(WHITE, 0.55), c1 = col, le = 0.15, count = 10 + math.floor(10 * k), s0 = 2, s1 = 6 * k + 1.5, size = 0.38, l0 = 1.3, l1 = 2.4, t0 = 0.08, acc = Vector3.new(0, -2.2, 0), drag = 1.2, spread = Vector2.new(62, 62) })
        elseif style == "Spirit" then
            FXH.thinRing(floor, col, 0.3, 2.6 + 3 * k, 1.3, { thick = 0.03, segs = 44 })
            FXH.burst(floor + up, { tex = SMOKE, c0 = WHITE, c1 = col, le = 0.9, count = 7 + math.floor(6 * k), s0 = 0.4, s1 = 1.8, size = 0.7, size1 = 1.6, l0 = 1.2, l1 = 2.2, t0 = 0.55, acc = Vector3.new(0, 2.6, 0), spread = Vector2.new(35, 35) })
        else -- Ripple
            FXH.thinRing(floor, col, 0.3, 2.4 + 3.4 * k, 0.9, { thick = 0.05, segs = 44 })
            FXH.thinRing(floor, WHITE, 0.2, 1.4 + 2.2 * k, 0.65, { thick = 0.03, segs = 36 })
            FXH.thinRing(floor, col, 0.1, 0.8 + 1.4 * k, 0.45, { thick = 0.025, segs = 28 })
            FXH.burst(floor + up, { c0 = WHITE, c1 = col, count = 6 + math.floor(8 * k), s0 = 1.5, s1 = 4, size = 0.22, l0 = 0.5, l1 = 1, acc = Vector3.new(0, 3, 0), spread = Vector2.new(70, 70) })
        end
    end

    local function takeoff(p, r, h, inAir)
        if not fxBudget() then return end
        local col = colorFor(p)
        local s = F.jfxSize or 1
        local pos = inAir and (feetOf(r, h) + Vector3.new(0, 0.3, 0)) or feetOf(r, h)
        FXH.thinRing(pos, col, 0.15, 1.3 * s + 0.6, 0.5, { thick = 0.03, segs = 32 })
        if F.jfxStyle == "Stardust" or F.jfxStyle == "Spirit" then
            FXH.burst(pos, { c0 = WHITE, c1 = col, count = 7, s0 = 1, s1 = 3, size = 0.2, l0 = 0.5, l1 = 0.9, acc = Vector3.new(0, 1, 0), spread = Vector2.new(50, 50), dir = Enum.NormalId.Bottom })
        elseif F.jfxStyle == "Petals" then
            FXH.burst(pos, { tex = SMOKE, c0 = col:Lerp(WHITE, 0.55), le = 0.15, count = 5, s0 = 1, s1 = 2.6, size = 0.3, l0 = 0.8, l1 = 1.4, t0 = 0.1, acc = Vector3.new(0, -1.4, 0), spread = Vector2.new(60, 60), dir = Enum.NormalId.Bottom })
        end
    end

    local recs = setmetatable({}, { __mode = "k" })
    track(RunService.Heartbeat:Connect(function()
        if not F.jfx then return end
        local now = os.clock()
        local camPos = cam.CFrame.Position
        for _, p in ipairs(Players:GetPlayers()) do
            if p == lp or F.jfxOthers then
                local c = p.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if h and r and h.Health > 0 and (p == lp or (r.Position - camPos).Magnitude < 90) then
                    local rec = recs[c]
                    if not rec then rec = { air = false, minVy = 0, vy = 0, since = 0, cool = 0 } recs[c] = rec end
                    local air = h.FloorMaterial == Enum.Material.Air
                    local vy = r.AssemblyLinearVelocity.Y
                    if air and not rec.air then
                        rec.air, rec.since, rec.minVy = true, now, 0
                        if F.jfxTakeoff and vy > 8 and now > rec.cool then rec.cool = now + 0.15 takeoff(p, r, h, false) end
                    elseif air then
                        if vy < rec.minVy then rec.minVy = vy end
                        if F.jfxTakeoff and vy - rec.vy > 24 and now - rec.since > 0.15 and now > rec.cool then
                            rec.cool = now + 0.15
                            takeoff(p, r, h, true)   -- a jump in mid-air
                        end
                    elseif not air and rec.air then
                        rec.air = false
                        if now - rec.since > 0.14 and -rec.minVy > 14 and now > rec.cool then
                            rec.cool = now + 0.15
                            landing(p, r, h, -rec.minVy)
                        end
                    end
                    rec.vy = vy
                end
            end
        end
    end))
    F.jfxPreview = function()
        local r, h = hrpOf(lp), humOf(lp)
        if r and h then landing(lp, r, h, 55) end
    end
    onCleanup(function() F.jfx = false F.jfxPreview = nil end)
end

--=== POST PROCESSING (движок в MoroVisuals.PostFX) ====================
local PFX = V.PostFX
local PF = { on = false, ui = {} }
PF.v = PFX.Values            -- те же значения, что читает движок
local PF_DEFAULT = PFX.Defaults
local PF_NAMES = PFX.Names

local function pfApply(smooth) PFX.Apply(smooth) end
local function pfEnable(on)
    PFX.Enable(on)
    PF.on = PFX.On
end
onCleanup(function() pfEnable(false) setVignette(0) end)

local function pfPreset(name)
    if not PFX.Preset(name) then return end
    PF.on = PFX.On
    if PF.toggle then pcall(PF.toggle.Set, true) end
    for key, sl in pairs(PF.ui) do
        local val = PF.v[key]
        if typeof(val) == "number" then pcall(sl.Set, val, true) end
    end
end

--=== WEATHER ==========================================================
local WEATHER_KINDS = { "Off", "Snowfall", "Blizzard", "Rain", "Thunderstorm", "Misty Morning", "Fireflies", "Ashfall", "Cherry Blossoms", "Autumn Leaves", "Haunted Mist", "Golden Dust", "Confetti" }
local weather = { kind = "Off", intensity = 1, mood = true, parts = {}, wind = {}, token = nil }
local setWeather
do
    local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
    local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

    -- one particle layer: a flat emitter slab above the camera (or at its feet) that follows it
    local function layer(o)
        local part = mk({ Transparency = 1, Size = Vector3.new(o.w or 80, 1, o.w or 80) })
        local e = Instance.new("ParticleEmitter")
        e.Texture = o.tex or SMOKE
        e.LightEmission = o.le or 0
        e.Color = o.color or ColorSequence.new(o.c0 or Color3.new(1, 1, 1), o.c1 or o.c0 or Color3.new(1, 1, 1))
        e.Rate = (o.rate or 20) * weather.intensity
        e.Lifetime = NumberRange.new(o.l0 or 3, o.l1 or o.l0 or 4)
        e.Speed = NumberRange.new(o.s0 or 1, o.s1 or o.s0 or 2)
        e.SpreadAngle = o.spread or Vector2.new(12, 12)
        e.EmissionDirection = o.dir or Enum.NormalId.Bottom
        local acc = o.acc or Vector3.zero
        e.Acceleration = acc
        e.Drag = o.drag or 0
        e.Rotation = NumberRange.new(0, o.spin and 360 or 0)
        e.RotSpeed = NumberRange.new(-(o.spin or 0), o.spin or 0)
        e.Shape = Enum.ParticleEmitterShape.Box
        e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        local sz = o.size or 0.4
        e.Size = o.grow and NumberSequence.new({ NumberSequenceKeypoint.new(0, sz * 0.4), NumberSequenceKeypoint.new(0.5, sz), NumberSequenceKeypoint.new(1, sz * 1.3) })
            or NumberSequence.new(sz)
        local t0 = o.t0 or 0.1
        e.Transparency = o.alpha or NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, t0), NumberSequenceKeypoint.new(0.8, t0), NumberSequenceKeypoint.new(1, 1) })
        if o.streak then
            e.Orientation = Enum.ParticleOrientation.VelocityParallel
            e.Squash = NumberSequence.new(o.streak)
        end
        e.Parent = part
        weather.parts[#weather.parts + 1] = { part = part, height = o.h or 20 }
        if o.wind then weather.wind[#weather.wind + 1] = { e = e, base = acc, k = o.wind, ph = math.random() * 6.28, fast = o.gust or 0.45 } end
        return e
    end

    -- the mood: atmosphere haze and a colour grade, faded in and out
    local atmBackup, atmOwned, cc
    local function moodClear()
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm and atmBackup then
            tw(atm, 1.5, atmBackup, Enum.EasingStyle.Sine)
            if atmOwned then task.delay(1.6, function() if weather.kind == "Off" and atmOwned and atm.Parent then atm:Destroy() atmOwned = nil end end) end
        end
        atmBackup = nil
        if cc then
            local old = cc
            cc = nil
            tw(old, 1.2, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }, Enum.EasingStyle.Sine)
            task.delay(1.3, function() old:Destroy() end)
        end
    end
    local function moodApply(m)
        if not (m and weather.mood) then return moodClear() end
        local k = math.clamp(weather.intensity, 0.4, 1.6)
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if not atm then
            atm = Instance.new("Atmosphere")
            atm.Density, atm.Offset, atm.Glare, atm.Haze = 0, 0, 0, 0
            atm.Parent = Lighting
            atmOwned = true
        end
        if not atmBackup then
            atmBackup = { Density = atm.Density, Offset = atm.Offset, Color = atm.Color, Decay = atm.Decay, Glare = atm.Glare, Haze = atm.Haze }
        end
        tw(atm, 2, { Density = math.clamp(m.density * k, 0, 1), Offset = m.offset or 0, Color = m.color, Decay = m.decay or m.color, Glare = m.glare or 0, Haze = (m.haze or 1) * k }, Enum.EasingStyle.Sine)
        if not cc then
            cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "MM2WeatherCC"
            cc.Parent = Lighting
        end
        tw(cc, 2, { Brightness = m.bright or 0, Contrast = m.contrast or 0, Saturation = m.sat or 0, TintColor = m.tint or Color3.new(1, 1, 1) }, Enum.EasingStyle.Sine)
        weather.baseBright = m.bright or 0
    end

    -- thunderstorm: forked bolts at a distance and a flash of the whole sky
    local function lightning(token)
        task.spawn(function()
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            while alive and weather.token == token do
                task.wait(3.5 + math.random() * 6)
                if weather.token ~= token then break end
                pcall(function()
                    local c = cam.CFrame.Position
                    local ang = math.random() * math.pi * 2
                    local d = 70 + math.random() * 120
                    local top = c + Vector3.new(math.cos(ang) * d, 150, math.sin(ang) * d)
                    rp.FilterDescendantsInstances = { fxFolder, lp.Character }
                    local hit = workspace:Raycast(top, Vector3.new(0, -400, 0), rp)
                    local ground = hit and hit.Position or (top - Vector3.new(0, 150, 0))
                    boltBetween(top, ground, rgb(205, 220, 255), 1.5, 22, 7, 0.5)
                    boltBetween(top, ground, Color3.new(1, 1, 1), 0.55, 22, 5, 0.4)
                    for i = 1, 3 do
                        local from = top:Lerp(ground, 0.25 + math.random() * 0.5)
                        boltBetween(from, from + Vector3.new(math.random(-30, 30), -math.random(20, 50), math.random(-30, 30)), rgb(190, 205, 255), 0.4, 9, 3, 0.35)
                    end
                    if cc then
                        local base = weather.baseBright or 0
                        cc.Brightness = base + 0.42
                        tw(cc, 0.5, { Brightness = base }, Enum.EasingStyle.Quad)
                        task.delay(0.16, function()
                            if cc and weather.token == token then
                                cc.Brightness = base + 0.28
                                tw(cc, 0.55, { Brightness = base }, Enum.EasingStyle.Quad)
                            end
                        end)
                    end
                    screenFlash(rgb(210, 220, 255), 0.18)
                end)
            end
        end)
    end

    local PRESETS = {
        ["Snowfall"] = {
            mood = { density = 0.34, color = rgb(214, 224, 240), decay = rgb(170, 186, 208), haze = 1.4, bright = -0.01, sat = -0.12, tint = rgb(226, 236, 255) },
            function()
                layer({ h = 22, rate = 240, tex = SMOKE, le = 0.2, c0 = Color3.new(1, 1, 1), t0 = 0.12, size = 0.26, l0 = 5, l1 = 7, s0 = 3, s1 = 6, spread = Vector2.new(28, 28), acc = Vector3.new(2, 0, 1), wind = 3, drag = 0.4 })
                layer({ h = 20, rate = 26, tex = SPARK, le = 0.35, c0 = Color3.new(1, 1, 1), t0 = 0.08, size = 0.7, spin = 40, l0 = 6, l1 = 8, s0 = 1.5, s1 = 3, spread = Vector2.new(35, 35), acc = Vector3.new(1, 0, 0), wind = 2, drag = 0.6 })
            end,
        },
        ["Blizzard"] = {
            mood = { density = 0.62, color = rgb(222, 230, 242), decay = rgb(185, 198, 218), haze = 2.6, bright = -0.05, contrast = -0.1, sat = -0.25, tint = rgb(214, 228, 255) },
            function()
                layer({ h = 20, rate = 650, tex = SMOKE, le = 0.2, c0 = Color3.new(1, 1, 1), t0 = 0.1, size = 0.3, l0 = 2.5, l1 = 3.5, s0 = 8, s1 = 14, spread = Vector2.new(30, 30), acc = Vector3.new(26, 0, 6), wind = 10, gust = 0.9 })
                layer({ h = 4, rate = 14, tex = SMOKE, le = 0, c0 = rgb(235, 240, 248), t0 = 0.8, size = 12, grow = true, l0 = 4, l1 = 6, s0 = 6, s1 = 12, spread = Vector2.new(20, 20), dir = Enum.NormalId.Front, acc = Vector3.new(14, 0, 3), wind = 5, w = 120 })
            end,
        },
        ["Rain"] = {
            mood = { density = 0.42, color = rgb(128, 140, 156), decay = rgb(96, 108, 124), haze = 1.8, bright = -0.07, contrast = 0.04, sat = -0.18, tint = rgb(190, 202, 226) },
            function()
                layer({ h = 26, rate = 850, tex = SMOKE, le = 0.3, c0 = rgb(208, 222, 244), t0 = 0.42, size = 1.1, streak = -9, l0 = 0.5, l1 = 0.6, s0 = 90, s1 = 115, spread = Vector2.new(2, 2), acc = Vector3.new(6, 0, 2), wind = 3 })
                layer({ h = 2, rate = 12, tex = SMOKE, le = 0, c0 = rgb(160, 170, 184), t0 = 0.84, size = 9, grow = true, l0 = 5, l1 = 7, s0 = 1, s1 = 3, spread = Vector2.new(40, 40), dir = Enum.NormalId.Front, wind = 1.5, w = 110 })
            end,
        },
        ["Thunderstorm"] = {
            lightning = true,
            mood = { density = 0.55, color = rgb(86, 96, 112), decay = rgb(58, 66, 82), haze = 2.4, bright = -0.12, contrast = 0.08, sat = -0.25, tint = rgb(170, 184, 215) },
            function()
                layer({ h = 26, rate = 1250, tex = SMOKE, le = 0.3, c0 = rgb(200, 216, 240), t0 = 0.38, size = 1.2, streak = -10, l0 = 0.4, l1 = 0.5, s0 = 105, s1 = 135, spread = Vector2.new(3, 3), acc = Vector3.new(18, 0, 5), wind = 6, gust = 0.8 })
                layer({ h = 2, rate = 16, tex = SMOKE, le = 0, c0 = rgb(120, 128, 144), t0 = 0.82, size = 11, grow = true, l0 = 5, l1 = 7, s0 = 2, s1 = 5, spread = Vector2.new(40, 40), dir = Enum.NormalId.Front, wind = 3, w = 120 })
            end,
        },
        ["Misty Morning"] = {
            mood = { density = 0.58, color = rgb(224, 226, 232), decay = rgb(190, 194, 206), haze = 2.8, glare = 0.25, bright = 0.01, sat = -0.06, tint = rgb(255, 246, 236) },
            function()
                layer({ h = 3, rate = 8, tex = SMOKE, le = 0.1, c0 = rgb(228, 232, 240), t0 = 0.86, size = 15, grow = true, l0 = 8, l1 = 11, s0 = 0.6, s1 = 1.6, spread = Vector2.new(180, 180), dir = Enum.NormalId.Front, wind = 1.2, w = 120 })
                layer({ h = 8, rate = 9, tex = SPARK, le = 0.9, c0 = rgb(255, 236, 190), t0 = 0.25, size = 0.22, l0 = 5, l1 = 8, s0 = 0.2, s1 = 0.7, spread = Vector2.new(180, 180), dir = Enum.NormalId.Front, wind = 1, w = 50 })
            end,
        },
        ["Fireflies"] = {
            mood = { density = 0.3, color = rgb(70, 92, 120), decay = rgb(40, 56, 80), haze = 1.2, bright = -0.07, sat = 0.06, tint = rgb(176, 206, 240) },
            function()
                local blink = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.05), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(0.6, 0.05), NumberSequenceKeypoint.new(0.8, 0.7), NumberSequenceKeypoint.new(1, 1) })
                layer({ h = 4, w = 55, rate = 11, tex = SMOKE, le = 1, c0 = rgb(214, 255, 140), c1 = rgb(150, 255, 170), alpha = blink, size = 0.3, l0 = 5, l1 = 8, s0 = 0.4, s1 = 1.4, spread = Vector2.new(180, 180), dir = Enum.NormalId.Front, wind = 1.4, drag = 1 })
                layer({ h = 4, w = 55, rate = 11, tex = SMOKE, le = 1, c0 = rgb(180, 255, 130), alpha = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.86), NumberSequenceKeypoint.new(0.4, 0.96), NumberSequenceKeypoint.new(0.6, 0.86), NumberSequenceKeypoint.new(0.8, 0.95), NumberSequenceKeypoint.new(1, 1) }), size = 1.3, l0 = 5, l1 = 8, s0 = 0.4, s1 = 1.4, spread = Vector2.new(180, 180), dir = Enum.NormalId.Front, wind = 1.4, drag = 1 })
            end,
        },
        ["Ashfall"] = {
            mood = { density = 0.46, color = rgb(94, 56, 46), decay = rgb(70, 38, 30), haze = 2.2, bright = -0.05, contrast = 0.05, sat = -0.05, tint = rgb(255, 214, 188) },
            function()
                layer({ h = 20, rate = 150, tex = SMOKE, le = 0, c0 = rgb(78, 74, 74), c1 = rgb(120, 112, 108), t0 = 0.3, size = 0.34, spin = 90, l0 = 6, l1 = 9, s0 = 1.2, s1 = 2.6, spread = Vector2.new(40, 40), acc = Vector3.new(2, 0, 1), wind = 2.5, drag = 0.5 })
                layer({ h = -3, w = 60, rate = 34, tex = SPARK, le = 1, c0 = rgb(255, 196, 90), c1 = rgb(255, 80, 30), t0 = 0.05, size = 0.24, l0 = 3, l1 = 5, s0 = 2, s1 = 5, spread = Vector2.new(30, 30), dir = Enum.NormalId.Top, acc = Vector3.new(0, 1.5, 0), wind = 3 })
            end,
        },
        ["Cherry Blossoms"] = {
            mood = { density = 0.22, color = rgb(255, 232, 238), decay = rgb(240, 200, 214), haze = 1.2, glare = 0.2, bright = 0.01, sat = 0.1, tint = rgb(255, 238, 244) },
            function()
                layer({ h = 18, rate = 60, tex = SMOKE, le = 0.15, color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 226, 238)), ColorSequenceKeypoint.new(1, rgb(255, 170, 205)) }), t0 = 0.05, size = 0.6, spin = 200, l0 = 6, l1 = 9, s0 = 1.2, s1 = 2.6, spread = Vector2.new(55, 55), acc = Vector3.new(1.5, 0, 0.5), wind = 4.5, gust = 0.35, drag = 0.9 })
                layer({ h = 14, rate = 10, tex = SPARK, le = 0.8, c0 = rgb(255, 244, 248), t0 = 0.2, size = 0.28, l0 = 5, l1 = 8, s0 = 0.3, s1 = 0.9, spread = Vector2.new(180, 180), dir = Enum.NormalId.Front, wind = 1.5 })
            end,
        },
        ["Autumn Leaves"] = {
            mood = { density = 0.2, color = rgb(250, 222, 186), decay = rgb(220, 170, 120), haze = 1.1, glare = 0.15, bright = 0, sat = 0.12, tint = rgb(255, 236, 214) },
            function()
                layer({ h = 18, rate = 34, tex = SMOKE, le = 0, color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(232, 150, 52)), ColorSequenceKeypoint.new(0.5, rgb(190, 76, 36)), ColorSequenceKeypoint.new(1, rgb(120, 70, 36)) }), t0 = 0, size = 0.75, spin = 140, l0 = 6, l1 = 9, s0 = 1.8, s1 = 3.4, spread = Vector2.new(45, 45), acc = Vector3.new(2.5, 0, 1), wind = 6, gust = 0.3, drag = 0.8 })
            end,
        },
        ["Haunted Mist"] = {
            mood = { density = 0.5, color = rgb(74, 46, 102), decay = rgb(46, 26, 70), haze = 2.2, bright = -0.1, sat = 0.04, tint = rgb(214, 196, 255) },
            function()
                layer({ h = 3, rate = 9, tex = SMOKE, le = 0.35, c0 = rgb(128, 78, 180), c1 = rgb(70, 170, 120), t0 = 0.8, size = 13, grow = true, l0 = 7, l1 = 10, s0 = 0.8, s1 = 2, spread = Vector2.new(180, 180), dir = Enum.NormalId.Front, wind = 1.6, w = 110 })
                layer({ h = 4, w = 50, rate = 12, tex = SPARK, le = 1, c0 = rgb(255, 150, 40), c1 = rgb(170, 90, 255), t0 = 0.05, size = 0.55, l0 = 4, l1 = 6, s0 = 0.8, s1 = 2, spread = Vector2.new(60, 60), dir = Enum.NormalId.Top, acc = Vector3.new(0, 1.1, 0), wind = 2 })
            end,
        },
        ["Golden Dust"] = {
            mood = { density = 0.3, color = rgb(255, 236, 196), decay = rgb(240, 200, 140), haze = 1.6, glare = 0.5, bright = 0.02, contrast = 0.06, sat = 0.1, tint = rgb(255, 240, 214) },
            function()
                layer({ h = 6, w = 70, rate = 38, tex = SPARK, le = 0.95, c0 = rgb(255, 232, 170), t0 = 0.2, size = 0.22, l0 = 6, l1 = 10, s0 = 0.15, s1 = 0.6, spread = Vector2.new(180, 180), dir = Enum.NormalId.Front, wind = 1.3, drag = 1 })
                layer({ h = 9, w = 70, rate = 5, tex = SMOKE, le = 0.7, c0 = rgb(255, 226, 160), t0 = 0.93, size = 6, grow = true, l0 = 8, l1 = 12, s0 = 0.2, s1 = 0.8, spread = Vector2.new(180, 180), dir = Enum.NormalId.Front, wind = 1 })
            end,
        },
        ["Confetti"] = {
            mood = nil,
            function()
                layer({ h = 18, rate = 180, tex = SPARK, le = 0.2, color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 70, 110)), ColorSequenceKeypoint.new(0.33, rgb(255, 220, 60)), ColorSequenceKeypoint.new(0.66, rgb(70, 220, 255)), ColorSequenceKeypoint.new(1, rgb(190, 90, 255)) }), t0 = 0, size = 0.7, spin = 260, l0 = 3, l1 = 4, s0 = 5, s1 = 9, spread = Vector2.new(25, 25), wind = 3 })
            end,
        },
    }

    setWeather = function(kind)
        for _, w in ipairs(weather.parts) do pcall(function() w.part:Destroy() end) end
        weather.parts, weather.wind = {}, {}
        weather.kind = kind
        weather.token = nil
        local preset = PRESETS[kind]
        if not preset then
            moodApply(nil)
            return
        end
        local token = {}
        weather.token = token
        preset[1]()
        moodApply(preset.mood)
        if preset.lightning then lightning(token) end
    end

    -- every frame: the slabs follow the camera and the wind keeps changing direction a little
    weather.step = function(now)
        if #weather.parts == 0 then return end
        local c = cam.CFrame.Position
        for _, w in ipairs(weather.parts) do
            w.part.CFrame = CFrame.new(c + Vector3.new(0, w.height, 0))
        end
        for _, w in ipairs(weather.wind) do
            w.e.Acceleration = w.base + Vector3.new(math.sin(now * w.fast + w.ph) * w.k, math.sin(now * 0.3 + w.ph * 2) * w.k * 0.15, math.cos(now * w.fast * 0.8 + w.ph) * w.k * 0.7)
        end
    end
end
onCleanup(function() setWeather("Off") end)

--=== MODEL REPLACEMENT ================================================
local MR = {
    on = false, scope = "Everyone", template = nil, templateId = nil, height = 5.6, yaw = 0, yoff = 0, gen = 0,
    recs = {}, hidden = {}, loading = false,
}
local MODEL_PRESETS = {
    { "Chubby Dog", 22202531681153, "market" },
    { "Alya", { 239, 57285014083965, 131346580241689, 126528728730337, 96994061769130 }, "market" },
    { "Shark", 1105996, "market" },
    { "TUNG Sahur", 164815366314625, "market" },
    { "Withered Golden Freddy", 103872628924571, "market" },
    { "Herobrine", 103153167628525, "market" },
    { "Shrek", 34356843621214, "market" },
    { "Cristiano Ronaldo", { 946, 115658016588579, 104775751657638, 15917804613 }, "market" },
    { "Stylized Skeleton", 160527682802304, "market" },
    { "Rabbid Classic", 141407388683693, "market" },
    { "Verity", 235686917499405, "market" },
}
local MODEL_NAMES = {}
local modelIdByName = {}
for _, m in ipairs(MODEL_PRESETS) do
    MODEL_NAMES[#MODEL_NAMES + 1] = m[1]
    modelIdByName[m[1]] = m
end

local function mrDropAll()
    for c, rec in pairs(MR.recs) do pcall(function() rec.model:Destroy() end) MR.recs[c] = nil end
    for c, list in pairs(MR.hidden) do
        for _, p in ipairs(list) do if p.Parent then p.LocalTransparencyModifier = 0 end end
        MR.hidden[c] = nil
    end
end
onCleanup(function() MR.on = false mrDropAll() end)

local function sanitizeTemplate(objs, rig)
    local m = Instance.new("Model")
    m.Name = "MM2Template"
    for _, o in ipairs(objs) do
        if rig and o:IsA("Model") then
            for _, ch in ipairs(o:GetChildren()) do ch.Parent = m end
            o:Destroy()
        else
            o.Parent = m
        end
    end
    if rig then
        m.PrimaryPart = m:FindFirstChild("HumanoidRootPart")
        m:SetAttribute("Rig", true)
    end
    local n = 0
    for _, d in ipairs(m:GetDescendants()) do
        n += 1
        if n % 200 == 0 then task.wait() end
        if d:IsA("Tool") then
            for _, ch in ipairs(d:GetChildren()) do
                if ch:IsA("BasePart") or ch:IsA("Model") then ch.Parent = m end
            end
            d:Destroy()
        elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") or (d:IsA("Humanoid") and not rig) or d:IsA("Animator") or (d:IsA("JointInstance") and not rig) or d:IsA("WeldConstraint")
            or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BodyMover") or d:IsA("ForceField") or d:IsA("Seat") or d:IsA("VehicleSeat") then
            pcall(function() d:Destroy() end)
        end
    end
    -- a rig keeps its Humanoid only so that Shirt / Pants textures are drawn; it is switched off completely
    local hum = rig and m:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        hum.AutoRotate = false
        pcall(function() hum.EvaluateStateMachine = false end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
    end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = true, false, false, false, true
        end
    end
    return m
end

-- marketplace items: a bundle or a single catalog item is dressed onto an R15 rig through a HumanoidDescription
local ITEM_FIELDS = {
    [17] = "Head", [18] = "Face", [27] = "Torso", [28] = "RightArm", [29] = "LeftArm", [30] = "LeftLeg", [31] = "RightLeg",
    [2] = "GraphicTShirt", [11] = "Shirt", [12] = "Pants", [79] = "Head",
}
local ITEM_ACCESSORY = {
    [8] = Enum.AccessoryType.Hat, [41] = Enum.AccessoryType.Hair, [42] = Enum.AccessoryType.Face, [43] = Enum.AccessoryType.Neck,
    [44] = Enum.AccessoryType.Shoulder, [45] = Enum.AccessoryType.Front, [46] = Enum.AccessoryType.Back, [47] = Enum.AccessoryType.Waist,
    [64] = Enum.AccessoryType.TShirt, [65] = Enum.AccessoryType.Shirt, [66] = Enum.AccessoryType.Pants, [67] = Enum.AccessoryType.Jacket,
    [68] = Enum.AccessoryType.Sweater, [69] = Enum.AccessoryType.Shorts, [70] = Enum.AccessoryType.LeftShoe, [71] = Enum.AccessoryType.RightShoe,
    [72] = Enum.AccessoryType.DressSkirt,
}
local function parseItemId(text)
    text = tostring(text or "")
    if text:find("share%?code") or text:find("share%-links") then return nil, "share links need a login: open it in your browser and paste the /bundles/... or /catalog/... address instead" end
    if text:find("/looks/") then return nil, "a look is a set of items: open it and paste its item links one by one (or use a look preset)" end
    local id = text:match("/bundles/(%d+)") or text:match("/catalog/(%d+)") or text:match("/library/(%d+)") or text:match("(%d%d%d+)")
    return tonumber(id), true
end
local function marketModel(id)
    local function get(url) return HttpService:JSONDecode(game:HttpGet(url)) end
    local ids = type(id) == "table" and id or { id }
    local desc
    local acc = {}
    -- an item named on its own replaces whatever the body bundles brought along for that slot (e.g. their default hair)
    local function put(assetId, at, explicit)
        if ITEM_FIELDS[at] then desc[ITEM_FIELDS[at]] = assetId
        elseif ITEM_ACCESSORY[at] then
            if explicit then
                for i = #acc, 1, -1 do if acc[i].AccessoryType == ITEM_ACCESSORY[at] then table.remove(acc, i) end end
            end
            acc[#acc + 1] = { AssetId = assetId, AccessoryType = ITEM_ACCESSORY[at], Order = #acc + 1 }
        end
    end
    -- a single bundle that ships with an outfit is used as the outfit (keeps its body scale); anything else is composed item by item
    if #ids == 1 then
        local okb, b = pcall(get, "https://catalog.roblox.com/v1/bundles/" .. ids[1] .. "/details")
        if okb and type(b) == "table" and b.id then
            for _, it in ipairs(b.items or {}) do
                if it.type == "UserOutfit" then desc = Players:GetHumanoidDescriptionFromOutfitId(it.id) break end
            end
        end
    end
    if not desc then
        desc = Instance.new("HumanoidDescription")
        local skin = Color3.fromRGB(255, 224, 204)
        desc.HeadColor, desc.TorsoColor, desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin, skin, skin, skin
        for _, one in ipairs(ids) do
            local okb, b = pcall(get, "https://catalog.roblox.com/v1/bundles/" .. one .. "/details")
            if okb and type(b) == "table" and b.id then
                for _, it in ipairs(b.items or {}) do
                    if it.type == "Asset" then put(it.id, it.assetType) end
                end
            else
                local okd, det = pcall(get, "https://economy.roblox.com/v2/assets/" .. one .. "/details")
                if not (okd and type(det) == "table" and det.AssetTypeId) then return nil, "item " .. one .. " not found in the catalog" end
                if not (ITEM_FIELDS[det.AssetTypeId] or ITEM_ACCESSORY[det.AssetTypeId]) then
                    return nil, "asset type " .. tostring(det.AssetTypeId) .. " is not an avatar item, use Asset ID"
                end
                put(one, det.AssetTypeId, true)
            end
        end
        if #acc > 0 then desc:SetAccessories(acc, true) end
    end
    local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    -- a rig only assembles itself once it is in the world, so park it there for a moment
    local root = rig:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = true end
    rig.Parent = workspace.Terrain
    task.wait(0.4)
    return { rig }
end

MR.status = "Not loaded"
local function loadModelAsset(id, auto, market)
    if MR.loading then return notify("Model", "Already loading, wait a moment", "warning") end
    MR.loading = true
    MR.status = "Loading " .. (type(id) == "table" and "look" or tostring(id)) .. "..."
    if not auto then notify("Model", "Loading " .. (type(id) == "table" and "look" or tostring(id)) .. "...", "info") end
    task.spawn(function()
        local done, objs, err = false, nil, nil
        task.spawn(function()
            local ok, res, why
            if market then
                ok, res, why = pcall(marketModel, id)
                if ok and not res then ok, res = false, why end
            else
                ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
            end
            if ok then objs = res else err = res end
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < 40 do task.wait(0.1) end
        if not objs or #objs == 0 then
            MR.loading = false
            MR.status = "Error: " .. (done and tostring(err or "empty asset") or "timed out")
            return notify("Model", MR.status, "error", 5)
        end
        local ok, tpl = pcall(sanitizeTemplate, objs, market)
        MR.loading = false
        if not ok then
            MR.status = "Error: " .. tostring(tpl)
            return notify("Model", MR.status, "error", 5)
        end
        local _, size = tpl:GetBoundingBox()
        if size.Magnitude < 0.1 then
            MR.status = "Error: asset has no visible parts"
            return notify("Model", MR.status, "error")
        end
        if MR.template then MR.template:Destroy() end
        MR.template, MR.templateId = tpl, id
        MR.gen += 1
        mrDropAll()
        MR.status = "Ready (id " .. (type(id) == "table" and "look" or tostring(id)) .. ", " .. #tpl:GetDescendants() .. " objects)"
        notify("Model", MR.status, "success")
        if not auto and MR.toggle and not MR.on then MR.toggle.Set(true) end
    end)
end

local function searchModels(keyword, cb)
    task.spawn(function()
        local ok, res = pcall(function()
            local j = HttpService:JSONDecode(game:HttpGet("https://apis.roblox.com/toolbox-service/v1/marketplace/10?keyword=" .. HttpService:UrlEncode(keyword) .. "&num=20&sortType=1"))
            local ids = {}
            for _, d in ipairs(j.data or {}) do ids[#ids + 1] = d.id end
            if #ids == 0 then return {} end
            local det = HttpService:JSONDecode(game:HttpGet("https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=" .. table.concat(ids, ",")))
            local list = {}
            for _, x in ipairs(det.data or {}) do
                if x.asset then list[#list + 1] = { id = x.asset.id, name = x.asset.name or "?", by = x.creator and x.creator.name or "?" } end
            end
            return list
        end)
        cb(ok and res or nil, res)
    end)
end

local function wantsModel(p)
    if not MR.on or not MR.template then return false end
    local sc = MR.scope
    if sc == "Me only" then return p == lp end
    if sc == "Others only" then return p ~= lp end
    if sc == "Murderer only" then return getRole(p) == "Murderer" end
    if sc == "Sheriff only" then local r = getRole(p) return r == "Sheriff" or r == "Hero" end
    return true
end

local function makeRec(c)
    local inst = MR.template:Clone()
    local _, bbSize = inst:GetBoundingBox()
    inst:ScaleTo(MR.height / math.max(bbSize.Y, 0.1))
    local bbCF, size = inst:GetBoundingBox()
    local off = inst:GetPivot():ToObjectSpace(bbCF)
    inst.Parent = fxFolder
    local rec = { model = inst, off = off, size = size, phase = math.random() * 6, gen = MR.gen, height = MR.height, hidden = false }
    if inst:GetAttribute("Rig") and inst.PrimaryPart then
        -- forward kinematics on the model's OWN skeleton: every joint takes the Transform of the same joint of the real character,
        -- so a different body keeps its proportions while running, jumping or emoting. All parts stay anchored (no physics).
        rec.rig = true
        local root = inst.PrimaryPart
        rec.root = root
        rec.drop = root.Position.Y - (bbCF.Position.Y - size.Y / 2)
        local rr = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        rec.k = rec.drop / math.max((hum and hum.HipHeight or 2) + (rr and rr.Size.Y / 2 or 1), 0.1)
        local function driven(d)
            if d:IsA("Motor6D") then return d.Part1 end
            if d:IsA("AnimationConstraint") then return d.Attachment1 and d.Attachment1.Parent end
        end
        local real = {}
        for _, d in ipairs(c:GetDescendants()) do
            local p = driven(d)
            if p then real[d.Name .. ":" .. p.Name] = d end
        end
        local entries, byChild = {}, {}
        local function addEntry(parent, child, cf0, cf1, src)
            if parent and child and not byChild[child] then
                local e = { parent = parent, child = child, cf0 = cf0, cf1 = cf1:Inverse(), src = src }
                byChild[child] = e
                entries[#entries + 1] = e
            end
        end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("Motor6D") then
                addEntry(d.Part0, d.Part1, d.C0, d.C1, real[d.Name .. ":" .. (d.Part1 and d.Part1.Name or "")])
            elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
                addEntry(d.Attachment0.Parent, d.Attachment1.Parent, d.Attachment0.CFrame, d.Attachment1.CFrame, real[d.Name .. ":" .. d.Attachment1.Parent.Name])
            end
        end
        -- accessory handles and other attached parts (no Transform)
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("Weld") and d.Part0 and d.Part1 then
                addEntry(d.Part0, d.Part1, d.C0, d.C1)
            elseif d:IsA("RigidConstraint") and d.Attachment0 and d.Attachment1 then
                local pa, pb = d.Attachment0.Parent, d.Attachment1.Parent
                if pa and pb then
                    if pb:FindFirstChildWhichIsA("Attachment") and (pb.Name == "Handle" or pb:FindFirstAncestorOfClass("Accessory")) then
                        addEntry(pa, pb, d.Attachment0.CFrame, d.Attachment1.CFrame)
                    else
                        addEntry(pb, pa, d.Attachment1.CFrame, d.Attachment0.CFrame)
                    end
                end
            end
        end
        -- parents before children
        local order, placed = {}, { [root] = true }
        local left = #entries
        while left > 0 do
            local progressed = false
            for _, e in ipairs(entries) do
                if not e.done and placed[e.parent] then
                    e.done, placed[e.child] = true, true
                    order[#order + 1] = e
                    left -= 1
                    progressed = true
                end
            end
            if not progressed then break end
        end
        rec.order = order
        rec.parts = {}
        for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then rec.parts[#rec.parts + 1] = d end end
    end
    return rec
end

local function refreshHidden(c)
    local list = {}
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Tool") then list[#list + 1] = d end
    end
    MR.hidden[c] = list
end

task.spawn(function()
    while alive do
        pcall(function()
            local keep = {}
            for _, p in ipairs(Players:GetPlayers()) do
                local c = p.Character
                if c and wantsModel(p) and c:FindFirstChild("HumanoidRootPart") and visAlive(p) then
                    keep[c] = p
                    local rec = MR.recs[c]
                    if rec and (rec.gen ~= MR.gen or math.abs(rec.height - MR.height) > 0.01) then
                        rec.model:Destroy() MR.recs[c] = nil rec = nil
                    end
                    if not rec then
                        rec = makeRec(c)
                        rec.isSelf = p == lp
                        MR.recs[c] = rec
                    end
                    refreshHidden(c)
                end
            end
            for c, rec in pairs(MR.recs) do
                if not keep[c] then
                    pcall(function() rec.model:Destroy() end)
                    MR.recs[c] = nil
                    for _, p in ipairs(MR.hidden[c] or {}) do if p.Parent then p.LocalTransparencyModifier = 0 end end
                    MR.hidden[c] = nil
                end
            end
        end)
        task.wait(0.4)
    end
end)

local function mrStep(t)
    for c, rec in pairs(MR.recs) do
        local r = c.Parent and c:FindFirstChild("HumanoidRootPart")
        if not r then continue end
        local h = c:FindFirstChildOfClass("Humanoid")
        local vel = r.AssemblyLinearVelocity
        local sp = math.clamp(Vector3.new(vel.X, 0, vel.Z).Magnitude / 16, 0, 1.5)
        local look = r.CFrame.LookVector
        local yaw = math.atan2(-look.X, -look.Z)
        local feetY = r.Position.Y - ((h and h.HipHeight or 2) + r.Size.Y / 2)
        if rec.rig then
            local rootCF = CFrame.new(r.Position.X, feetY + rec.drop + MR.yoff, r.Position.Z) * (r.CFrame - r.CFrame.Position) * CFrame.Angles(0, math.rad(MR.yaw), 0)
            local cf = { [rec.root] = rootCF }
            local ps, cfs = { rec.root }, { rootCF }
            for _, e in ipairs(rec.order) do
                local pcf = cf[e.parent]
                if pcf then
                    local T = CFrame.identity
                    if e.src then
                        local s = e.src.Transform
                        T = CFrame.new(s.Position * rec.k) * (s - s.Position)
                    end
                    local ccf = pcf * e.cf0 * T * e.cf1
                    cf[e.child] = ccf
                    ps[#ps + 1], cfs[#cfs + 1] = e.child, ccf
                end
            end
            for _, p in ipairs(rec.parts) do p.CanCollide, p.CanTouch, p.CanQuery = false, false, false end   -- a Humanoid keeps switching collisions back on
            workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged)
        else
        local bob = math.abs(math.sin(t * 9 + rec.phase)) * 0.45 * sp
        local D = CFrame.new(r.Position.X, feetY + rec.size.Y / 2 + bob + MR.yoff, r.Position.Z)
            * CFrame.Angles(0, yaw + math.rad(MR.yaw), 0)
            * CFrame.Angles(math.rad(-10) * sp, 0, math.sin(t * 9 + rec.phase) * math.rad(7) * sp)
        rec.model:PivotTo(D * rec.off:Inverse())
        end
        for _, p in ipairs(MR.hidden[c] or {}) do
            if p.Parent then p.LocalTransparencyModifier = 1 end
        end
        if rec.isSelf then
            local near = (cam.CFrame.Position - r.Position).Magnitude < 2
            if near ~= rec.hidden then
                rec.hidden = near
                for _, d in ipairs(rec.model:GetDescendants()) do
                    if d:IsA("BasePart") then d.LocalTransparencyModifier = near and 1 or 0 end
                end
            end
        end
    end
end

-- single FX render step: auras, models, weather
track(RunService.RenderStepped:Connect(function()
    local t = os.clock()
    for c, a in pairs(auras) do
        if c.Parent then pcall(updateAura, c, a, t) end
    end
    if MR.on then pcall(mrStep, t) end
    if weather.step then weather.step(t) end
end))


local Win = Library:CreateWindow({
    Title = "Moro MM2",
    Subtitle = "Murder Mystery 2",
    Icon = "skull",
    ToggleKey = Enum.KeyCode.RightShift,
    TeleportFile = "MM2.lua",
    LoaderSound = true,
    NotifySound = true,
})
Library.Window = Win
Library:OnUnload(function()
    alive = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(cleanups) do pcall(fn) end
end)
_G.__MM2Cleanup = function() Library:Unload() end
-- if the library lacks Unload, fall back to a manual cleanup
if not Library.Unload then
    _G.__MM2Cleanup = function()
        alive = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(cleanups) do pcall(fn) end
    end
end

local CombatTab = Win:CreateTab({ Name = "Combat", Icon = "crosshair" })
local MoveTab = Win:CreateTab({ Name = "Movement", Icon = "footprints" })
local VisTab = Win:CreateTab({ Name = "Visuals", Icon = "eye" })
-- sub-tabs need a MoroElite build that has Tab:SubTab; with an older build every sub-tab becomes a normal tab
local function subTab(cfg)
    if VisTab.SubTab then return VisTab:SubTab(cfg) end
    return Win:CreateTab({ Name = "Vis: " .. cfg.Name, Icon = cfg.Icon })
end
local EspTab = subTab({ Name = "ESP", Icon = "eye" })
local FxTab = subTab({ Name = "Effects", Icon = "sparkles" })
local PostTab = subTab({ Name = "Post FX", Icon = "clapperboard" })
local ModelTab = subTab({ Name = "Models", Icon = "box" })
local WorldTab = subTab({ Name = "World", Icon = "globe" })
local SkinTab = Win:CreateTab({ Name = "Skins", Icon = "palette" })
local HalloweenTab = Win:CreateTab({ Name = "Halloween", Icon = "ghost" })
local MiscTab = Win:CreateTab({ Name = "Misc", Icon = "wrench" })
local MiscSub = (function()
    local function mk(name, icon)
        if MiscTab.SubTab then return MiscTab:SubTab({ Name = name, Icon = icon }) end
        return Win:CreateTab({ Name = "Misc: " .. name, Icon = icon })
    end
    local general, sounds = mk("General", "wrench"), mk("Sounds", "volume-2")
    return { general = general, sounds = sounds, left = general:Column("left"), right = general:Column("right"),
        soundL = sounds:Column("left"), soundR = sounds:Column("right") }
end)()
Win:AddSettingsTab()

-- COMBAT ------------------------------------------------------------
do
    local function combatSub(name, icon)
        if CombatTab.SubTab then return CombatTab:SubTab({ Name = name, Icon = icon }) end
        return Win:CreateTab({ Name = "Combat: " .. name, Icon = icon })
    end

    -- both roles get the same aim settings; each role keeps its own values
    local function aimSections(sub, prof, who, targets, defaultTarget)
        local L, R = sub:Column("left"), sub:Column("right")
        local aim = L:CreateSection({ Name = "Aimbot", Icon = "crosshair", Collapsible = true })
        aim:AddToggle({ Name = "Aimbot", Icon = "crosshair", Description = "Works while you are the " .. who:lower(), Callback = function(v) prof.aimbot = v end })
        aim:AddDropdown({ Name = "Key", Description = "On phones it is always on", Options = { "Hold RMB", "Always" }, Default = "Hold RMB", Callback = function(v) prof.aimKey = v or "Hold RMB" end })
        aim:AddDropdown({ Name = "Target", Options = targets, Default = defaultTarget, Callback = function(v) prof.aimMode = v or defaultTarget end })
        aim:AddDropdown({ Name = "Part", Options = { "Head", "Torso", "Root" }, Default = "Head", Callback = function(v) prof.aimPart = v or "Head" end })
        aim:AddSlider({ Name = "FOV", Min = 30, Max = 600, Default = prof.aimFov, Suffix = " px", Callback = function(v) prof.aimFov = v end })
        aim:AddSlider({ Name = "Smoothness", Min = 0, Max = 95, Default = prof.aimSmooth, Callback = function(v) prof.aimSmooth = v end })
        aim:AddSlider({ Name = "Prediction", Min = 0, Max = 300, Default = prof.predict * 1000, Suffix = " ms", Callback = function(v) prof.predict = v / 1000 end })
        aim:AddToggle({ Name = "Wall Check", Default = true, Callback = function(v) prof.aimWall = v end })
        aim:AddToggle({ Name = "Show FOV Circle", Default = true, Callback = function(v) prof.showFov = v end })

        local sil = R:CreateSection({ Name = "Bullet Homing", Icon = "target", Collapsible = true })
        sil:AddToggle({ Name = "Bullet Homing", Icon = "target", Description = "Gun shots and knife throws go to the target", Callback = function(v)
            prof.silent = v
            if v and not origGetMouse then notify("Bullet Homing", "WeaponService hook failed - it will not work", "error") end
        end })
        sil:AddSlider({ Name = "FOV", Min = 50, Max = 1000, Default = prof.silentFov, Suffix = " px", Callback = function(v) prof.silentFov = v end })
        sil:AddToggle({ Name = "Wall Check", Callback = function(v) prof.silentWall = v end })
        return L, R
    end

    local function wallbangSection(col, prof, what)
        local wb = col:CreateSection({ Name = "Wallbang", Icon = "brick-wall", Collapsible = true })
        wb:AddToggle({ Name = "Wallbang", Icon = "brick-wall", Description = what .. " ignore walls: the origin is moved next to the target", Callback = function(v) prof.wallbang = v end })
        wb:AddDropdown({ Name = "Mode", Options = { "Close Range", "Overhead" }, Default = "Close Range", Callback = function(v) prof.wbMode = v or "Close Range" end })
        wb:AddSlider({ Name = "Offset", Min = 1, Max = 15, Default = prof.wbOffset, Suffix = " st", Callback = function(v) prof.wbOffset = v end })
        wb:AddToggle({ Name = "Manual Shots", Description = "Also rewrites the " .. what:lower() .. " you make yourself (needs a target in FOV)", Callback = function(v) prof.wbManual = v end })
    end

    local function holsterRows(sec, prof, what)
        sec:AddToggle({ Name = "Hide After Shot", Icon = "package", Default = true, Description = "The " .. what .. " goes back into the backpack after every automatic shot", Callback = function(v) prof.holster = v end })
        sec:AddSlider({ Name = "Hide Delay", Min = 0.05, Max = 1.5, Default = prof.holsterDelay, Decimals = 2, Suffix = " s", Callback = function(v) prof.holsterDelay = v end })
    end

    -- MURDERER
    local Mu = combatSub("Murderer", "swords")
    local ML, MR = aimSections(Mu, P.Murderer, "Murderer", { "Anyone", "Sheriff" }, "Anyone")
    local th = ML:CreateSection({ Name = "Auto Throw", Icon = "send", Collapsible = true })
    th:AddToggle({ Name = "Auto Throw", Icon = "send", Description = "Throws the knife at the nearest player", Callback = function(v) P.Murderer.throwAura = v end })
    th:AddSlider({ Name = "Range", Min = 20, Max = 200, Default = P.Murderer.throwRange, Suffix = " st", Callback = function(v) P.Murderer.throwRange = v end })
    th:AddSlider({ Name = "Knife Speed", Min = 30, Max = 300, Default = P.Murderer.throwSpeed, Suffix = " st/s", Description = "Used to lead moving targets: lower = leads more", Callback = function(v) P.Murderer.throwSpeed = v end })
    th:AddSlider({ Name = "Delay", Min = 0.5, Max = 4, Default = P.Murderer.throwDelay, Decimals = 1, Suffix = " s", Callback = function(v) P.Murderer.throwDelay = v end })
    th:AddToggle({ Name = "Wall Check", Default = true, Callback = function(v) P.Murderer.throwWall = v end })
    holsterRows(th, P.Murderer, "knife")
    wallbangSection(MR, P.Murderer, "Knife throws")
    local ka = MR:CreateSection({ Name = "Kill Aura", Icon = "swords", Collapsible = true })
    ka:AddToggle({ Name = "Kill Aura", Icon = "swords", Description = "Stabs everyone in range", Callback = function(v) P.Murderer.killAura = v end })
    ka:AddSlider({ Name = "Range", Min = 5, Max = 40, Default = P.Murderer.killRange, Suffix = " st", Callback = function(v) P.Murderer.killRange = v end })
    ka:AddSlider({ Name = "Stab Delay", Min = 0.2, Max = 2, Default = P.Murderer.killDelay, Decimals = 1, Suffix = " s", Callback = function(v) P.Murderer.killDelay = v end })
    ka:AddToggle({ Name = "Hide After Stab", Icon = "package", Default = true, Description = "The knife goes back into the backpack after every Kill Aura stab", Callback = function(v) P.Murderer.stabHolster = v end })
    ka:AddSlider({ Name = "Hide Delay", Min = 0.05, Max = 1.5, Default = P.Murderer.stabHolsterDelay, Decimals = 2, Suffix = " s", Callback = function(v) P.Murderer.stabHolsterDelay = v end })
    ka:AddButton({ Name = "Kill All (once)", Primary = true, Callback = function() task.spawn(runKillAll) end })
    ka:AddToggle({ Name = "Kill All Loop", Description = "Repeats while you are the murderer", Callback = function(v) P.Murderer.killAll = v end })

    -- SHERIFF
    local Sh = combatSub("Sheriff", "shield")
    local SL, SR = aimSections(Sh, P.Sheriff, "Sheriff", { "Murderer", "Anyone" }, "Murderer")
    local au = SL:CreateSection({ Name = "Auto Shoot", Icon = "zap", Collapsible = true })
    au:AddToggle({ Name = "Auto Shoot", Icon = "zap", Description = "Equips the gun and shoots the nearest target", Callback = function(v) P.Sheriff.autoShoot = v end })
    au:AddSlider({ Name = "Max Distance", Min = 30, Max = 500, Default = P.Sheriff.shootRange, Suffix = " st", Callback = function(v) P.Sheriff.shootRange = v end })
    au:AddSlider({ Name = "Delay", Min = 0.3, Max = 4, Default = P.Sheriff.shootDelay, Decimals = 1, Suffix = " s", Callback = function(v) P.Sheriff.shootDelay = v end })
    au:AddToggle({ Name = "Wall Check", Default = true, Callback = function(v) P.Sheriff.shootWall = v end })
    holsterRows(au, P.Sheriff, "gun")
    wallbangSection(SR, P.Sheriff, "Shots")

    local gn = SR:CreateSection({ Name = "Gun", Icon = "hand", Collapsible = true })
    gn:AddLabel("Works for any player who is not the murderer and has no gun, innocents too.")
    gn:AddToggle({ Name = "Auto Grab Dropped Gun", Icon = "hand", Callback = function(v) P.Sheriff.autoGun = v end })
    gn:AddDropdown({ Name = "Method", Options = { "Remote", "Teleport" }, Default = "Remote", Description = "Remote: no movement. Teleport: walks into the gun and comes back", Callback = function(v) P.Sheriff.grabMode = v or "Remote" end })
    gn:AddButton({ Name = "Grab Gun Now", Callback = function()
        task.spawn(function()
            local ok, why = S.grabGun(P.Sheriff.grabMode)
            if not ok then notify("Gun", why, "warning") end
        end)
    end })
end

-- ESP ---------------------------------------------------------------
do
    local L, R = EspTab:Column("left"), EspTab:Column("right")

    local ctl = {}
    local ESP_BASE = {
        ["ESP Master"] = true, ["ESP Filter"] = "All players", ["ESP Color Mode"] = "Role", ["ESP Visible Check"] = false, ["ESP Distance Fade"] = true,
        ["Box Style"] = "Corners", ["Box Thickness"] = 1.6, ["Box Fill Transparency"] = 88, ["Skeleton"] = false, ["Head Dot"] = false, ["Look Line"] = false,
        ["Name Tag"] = true, ["Name Style"] = "Pill", ["Role Tag"] = true, ["Show Distance"] = true, ["Show Weapon"] = true,
        ["Health Bar"] = true, ["Health Text"] = false, ["Text Size"] = 13,
        ["Chams Style"] = "Off", ["Chams Colors"] = "Role", ["Chams Opacity"] = 55,
        ["ESP Tracers"] = false, ["Off-screen Arrows"] = false,
    }
    local ESP_PRESETS = {
        ["Elegant"] = { ["Box Style"] = "Corners", ["Chams Style"] = "Glow", ["Chams Opacity"] = 45 },
        ["Minimal"] = { ["Box Style"] = "Corners", ["Show Distance"] = false, ["Show Weapon"] = false, ["Health Bar"] = false },
        ["Clean Outline"] = { ["Box Style"] = "Off", ["Name Style"] = "Plain", ["Health Bar"] = false, ["Show Weapon"] = false, ["Chams Style"] = "Outline Glow" },
        ["Full Info"] = { ["Box Style"] = "Rounded Glow", ["Skeleton"] = true, ["Head Dot"] = true, ["Look Line"] = true, ["Health Text"] = true,
            ["ESP Tracers"] = true, ["Off-screen Arrows"] = true, ["Chams Style"] = "Flat", ["Chams Opacity"] = 40 },
        ["Competitive"] = { ["Box Style"] = "Off", ["Name Style"] = "Plain", ["Skeleton"] = true, ["Health Bar"] = true, ["Show Weapon"] = false,
            ["Chams Style"] = "Pulse", ["ESP Visible Check"] = true },
        ["Chams Only"] = { ["Box Style"] = "Off", ["Name Tag"] = false, ["Role Tag"] = false, ["Show Distance"] = false, ["Show Weapon"] = false,
            ["Health Bar"] = false, ["Chams Style"] = "Glow", ["Chams Opacity"] = 50 },
        ["Neon 3D"] = { ["Box Style"] = "3D Box", ["Name Style"] = "Pill", ["ESP Color Mode"] = "Rainbow", ["Chams Style"] = "Rainbow", ["Chams Opacity"] = 40 },
    }
    local presetNames = {}
    for _, n in ipairs({ "Elegant", "Minimal", "Clean Outline", "Full Info", "Competitive", "Chams Only", "Neon 3D" }) do
        presetNames[#presetNames + 1] = n
    end
    local function applyEspPreset(name)
        local p = ESP_PRESETS[name]
        if not p then return end
        local merged = {}
        for k, v in pairs(ESP_BASE) do merged[k] = v end
        for k, v in pairs(p) do merged[k] = v end
        for key, val in pairs(merged) do
            local c = ctl[key]
            if c and c.Set then pcall(c.Set, val) end
        end
        notify("ESP", "Preset: " .. name, "success", 2)
    end

    -- master -------------------------------------------------------------
    local mt = L:CreateSection({ Name = "Player ESP", Icon = "eye", Collapsible = true })
    ctl["ESP Master"] = mt:AddToggle({ Name = "Player ESP", Icon = "eye", Callback = function(v) E.on = v end })
    mt:AddDropdown({ Name = "Preset", Description = "Applies a ready set of ESP settings", Options = presetNames, Default = "Full Info", Callback = function(v) if v then applyEspPreset(v) end end })
    ctl["ESP Filter"] = mt:AddDropdown({ Name = "Filter", Options = { "All players", "Murderer + Sheriff", "Murderer only" }, Default = "All players", Callback = function(v) E.filter = v or "All players" end })
    mt:AddSlider({ Name = "Max Distance", Min = 100, Max = 3000, Default = E.maxDist, Suffix = " st", Callback = function(v) E.maxDist = v end })
    ctl["ESP Color Mode"] = mt:AddDropdown({ Name = "Color Mode", Options = { "Role", "Rainbow", "Static" }, Default = "Role", Callback = function(v) E.colorMode = v or "Role" end })
    mt:AddColorPicker({ Name = "Static Color", Default = E.staticColor, Callback = function(c) E.staticColor = c end })
    ctl["ESP Visible Check"] = mt:AddToggle({ Name = "Visible Check", Description = "Dims players that are behind walls", Callback = function(v) E.visCheck = v end })
    ctl["ESP Distance Fade"] = mt:AddToggle({ Name = "Distance Fade", Default = true, Callback = function(v) E.fade = v end })

    -- boxes / skeleton ---------------------------------------------------
    local bx = L:CreateSection({ Name = "Boxes & Skeleton", Icon = "box-select", Collapsible = true })
    ctl["Box Style"] = bx:AddDropdown({ Name = "Style", Options = { "Off", "Corners", "Full", "Rounded Glow", "3D Box" }, Default = "Rounded Glow", Callback = function(v) E.box = v or "Corners" end })
    ctl["Box Thickness"] = bx:AddSlider({ Name = "Thickness", Min = 0.5, Max = 4, Default = E.boxThick, Decimals = 1, Callback = function(v) E.boxThick = v end })
    ctl["Box Fill Transparency"] = bx:AddSlider({ Name = "Fill Transparency", Min = 50, Max = 100, Default = E.boxFill, Suffix = " %", Callback = function(v) E.boxFill = v end })
    ctl["Skeleton"] = bx:AddToggle({ Name = "Skeleton", Default = true, Icon = "bone", Callback = function(v) E.skeleton = v end })
    bx:AddSlider({ Name = "Bone Thickness", Min = 0.5, Max = 4, Default = E.skelThick, Decimals = 1, Callback = function(v) E.skelThick = v end })
    ctl["Head Dot"] = bx:AddToggle({ Name = "Head Dot", Default = true, Callback = function(v) E.headDot = v end })
    ctl["Look Line"] = bx:AddToggle({ Name = "Look Line", Default = true, Description = "Shows where a player is looking", Callback = function(v) E.look = v end })

    -- labels -------------------------------------------------------------
    local lb = L:CreateSection({ Name = "Labels", Icon = "tag", Collapsible = true })
    ctl["Name Tag"] = lb:AddToggle({ Name = "Name", Default = true, Callback = function(v) E.name = v end })
    ctl["Name Style"] = lb:AddDropdown({ Name = "Name Style", Options = { "Pill", "Plain" }, Default = "Pill", Callback = function(v) E.nameStyle = v or "Pill" end })
    ctl["Role Tag"] = lb:AddToggle({ Name = "Role", Default = true, Callback = function(v) E.roleTag = v end })
    ctl["Show Distance"] = lb:AddToggle({ Name = "Distance", Default = true, Callback = function(v) E.dist = v end })
    ctl["Show Weapon"] = lb:AddToggle({ Name = "Weapon", Default = true, Callback = function(v) E.weapon = v end })
    ctl["Health Bar"] = lb:AddToggle({ Name = "Health Bar", Default = true, Callback = function(v) E.hpBar = v end })
    ctl["Health Text"] = lb:AddToggle({ Name = "Health Text", Default = true, Callback = function(v) E.hpText = v end })
    ctl["Text Size"] = lb:AddSlider({ Name = "Text Size", Min = 9, Max = 22, Default = E.textSize, Callback = function(v) E.textSize = v end })

    -- chams --------------------------------------------------------------
    local ch = R:CreateSection({ Name = "Chams", Icon = "scan", Collapsible = true })
    ctl["Chams Style"] = ch:AddDropdown({ Name = "Style", Options = { "Off", "Flat", "Glow", "Pulse", "Rainbow", "Outline Glow" }, Default = "Flat", Callback = function(v) E.chams = v or "Off" end })
    ctl["Chams Colors"] = ch:AddDropdown({ Name = "Colors", Options = { "Role", "Custom" }, Default = "Role", Callback = function(v) E.chamMode = v or "Role" end })
    ch:AddColorPicker({ Name = "Visible Color", Default = E.chamVisible, Callback = function(c) E.chamVisible = c end })
    ch:AddColorPicker({ Name = "Hidden Color", Default = E.chamHidden, Callback = function(c) E.chamHidden = c end })
    ctl["Chams Opacity"] = ch:AddSlider({ Name = "Opacity", Min = 5, Max = 95, Default = 40, Suffix = " %", Callback = function(v) E.chamAlpha = 1 - v / 100 end })
    ch:AddLabel("Bright color = visible, dim color = through walls.")

    -- tracers / arrows ---------------------------------------------------
    local tr = R:CreateSection({ Name = "Tracers & Arrows", Icon = "locate", Collapsible = true })
    ctl["ESP Tracers"] = tr:AddToggle({ Name = "Tracers", Default = true, Callback = function(v) E.tracer = v end })
    tr:AddDropdown({ Name = "Origin", Options = { "Bottom", "Center", "Top", "Mouse" }, Default = "Bottom", Callback = function(v) E.tracerFrom = v or "Bottom" end })
    tr:AddSlider({ Name = "Thickness", Min = 0.5, Max = 4, Default = E.tracerThick, Decimals = 1, Callback = function(v) E.tracerThick = v end })
    ctl["Off-screen Arrows"] = tr:AddToggle({ Name = "Arrows", Default = true, Description = "Arrows pointing at players outside your view", Callback = function(v) E.arrows = v end })
    tr:AddSlider({ Name = "Radius", Min = 15, Max = 48, Default = E.arrowRadius * 100, Suffix = " %", Callback = function(v) E.arrowRadius = v / 100 end })

    -- world --------------------------------------------------------------
    local we = R:CreateSection({ Name = "World ESP", Icon = "map-pin", Collapsible = true })
    local gunT = we:AddToggle({ Name = "Gun", Default = true, Callback = function(v) E.gun = v end })
    gunT:AddColorPicker({ Default = E.gunCol, Callback = function(c) E.gunCol = c end })
    we:AddToggle({ Name = "Outline", Default = true, Callback = function(v) E.outline = v end })
    we:AddToggle({ Name = "Fill", Default = true, Callback = function(v) E.fill = v end })
    we:AddToggle({ Name = "Labels", Default = true, Callback = function(v) E.tag = v end })

    -- colors / notifications / info --------------------------------------
    local rc = R:CreateSection({ Name = "Role Colors", Icon = "palette", Collapsible = true })
    for _, role in ipairs({ "Murderer", "Sheriff", "Hero", "Innocent" }) do
        rc:AddColorPicker({ Name = role .. " Color", Default = ROLE_COLORS[role], Callback = function(c) ROLE_COLORS[role] = c end })
    end
    rc:AddToggle({ Name = "Role Notifications", Default = true, Callback = function(v) S.roleNotify = v end })

    local info = R:CreateSection({ Name = "Round Info", Icon = "info", Collapsible = true })
    info:AddStat({ Name = "You", Interval = 1, Get = function() return getRole(lp) end })
    info:AddStat({ Name = "Murderer", Interval = 1, Get = function() local p = findByRole("Murderer") return p and ('<font color="#ff3c3c">' .. p.DisplayName .. "</font>") or "-" end })
    info:AddStat({ Name = "Sheriff", Interval = 1, Get = function() local p = findByRole("Sheriff") or findByRole("Hero") return p and ('<font color="#3c8cff">' .. p.DisplayName .. "</font>") or "-" end })
    info:AddStat({ Name = "Alive", Interval = 1, Get = function()
        local n = 0
        for _, p in ipairs(Players:GetPlayers()) do if isAlive(p) then n += 1 end end
        return n .. "/" .. #Players:GetPlayers()
    end })
end

-- MOVEMENT ----------------------------------------------------------
do
    local function moveSub(name, icon)
        if MoveTab.SubTab then return MoveTab:SubTab({ Name = name, Icon = icon }) end
        return Win:CreateTab({ Name = "Move: " .. name, Icon = icon })
    end
    local WalkTab, TpTab = moveSub("Walk", "footprints"), moveSub("Teleport", "map-pin")
    local L = WalkTab:Column("left")
    local WR = WalkTab:Column("right")
    local R = TpTab:Column("left")
    local mv = L:CreateSection({ Name = "Movement", Icon = "footprints", Collapsible = true })
    local sp = mv:AddToggle({ Name = "Speed", Callback = function(v)
        S.speed = v
        if not v then local h = humOf(lp) if h then h.WalkSpeed = 16 end end
    end })
    sp:AddKeybind({ Default = Enum.KeyCode.X, Mode = "Toggle" })
    mv:AddSlider({ Name = "Walk Speed", Min = 16, Max = 120, Default = S.speedVal, Callback = function(v) S.speedVal = v end })
    mv:AddToggle({ Name = "Jump Power", Callback = function(v)
        S.jump = v
        if not v then local h = humOf(lp) if h then h.JumpPower = 50 end end
    end })
    mv:AddSlider({ Name = "Jump Value", Min = 50, Max = 200, Default = S.jumpVal, Callback = function(v) S.jumpVal = v end })
    mv:AddToggle({ Name = "Infinite Jump", Callback = function(v) S.infJump = v end })
    mv:AddToggle({ Name = "Noclip", Callback = function(v) S.noclip = v end })
    local fl = mv:AddToggle({ Name = "Fly", Description = "WASD + Space / Ctrl", Callback = function(v) S.fly = v end })
    fl:AddKeybind({ Default = Enum.KeyCode.F, Mode = "Toggle" })
    mv:AddSlider({ Name = "Fly Speed", Min = 20, Max = 200, Default = S.flySpeed, Callback = function(v) S.flySpeed = v end })
    mv:AddToggle({ Name = "Anti Void", Default = true, Callback = function(v) S.antiVoid = v end })

    local bh = WR:CreateSection({ Name = "Bunny Hop", Icon = "rabbit", Collapsible = true })
    local bhT = bh:AddToggle({ Name = "Bunny Hop", Icon = "rabbit", Description = "Auto-jumps and gains speed with every hop", Callback = function(v)
        S.bhop = v
        if not v then
            S.hopCur = 16
            local h = humOf(lp)
            if h and not S.speed then h.WalkSpeed = 16 end
            if h and not S.jump then h.JumpPower = 50 end
        end
    end })
    bhT:AddKeybind({ Default = Enum.KeyCode.B, Mode = "Toggle" })
    bh:AddDropdown({ Name = "Mode", Options = { "Hold Space", "Always" }, Default = "Hold Space", Callback = function(v) S.bhopMode = v or "Hold Space" end })
    bh:AddSlider({ Name = "Max Speed", Min = 20, Max = 120, Default = S.bhopMax, Callback = function(v) S.bhopMax = v end })
    bh:AddSlider({ Name = "Speed Gain", Min = 1, Max = 10, Default = S.bhopStep, Decimals = 1, Callback = function(v) S.bhopStep = v end })
    bh:AddSlider({ Name = "Jump Height", Min = 20, Max = 200, Default = S.bhopJump, Description = "How high each hop goes", Callback = function(v) S.bhopJump = v end })

    local bd = WR:CreateSection({ Name = "Body", Icon = "ruler", Collapsible = true })
    local hipOrig
    bd:AddToggle({ Name = "Hip Height", Description = "Lifts or lowers your body above the floor", Callback = function(v)
        S.hip = v
        local h = humOf(lp)
        if v and h then hipOrig = h.HipHeight end
        if not v and h and hipOrig then h.HipHeight = hipOrig end
    end })
    bd:AddSlider({ Name = "Hip Height Value", Min = 0, Max = 30, Default = S.hipVal, Decimals = 1, Callback = function(v) S.hipVal = v end })
    bd:AddToggle({ Name = "Gravity", Callback = function(v)
        S.grav = v
        if not v then workspace.Gravity = 196.2 end
    end })
    bd:AddSlider({ Name = "Gravity Value", Min = 5, Max = 400, Default = S.gravVal, Callback = function(v) S.gravVal = v end })
    onCleanup(function() S.grav = false workspace.Gravity = 196.2 end)

    local tp = R:CreateSection({ Name = "Teleports", Icon = "map-pin", Collapsible = true })
    local function playerNames()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= lp then t[#t + 1] = p.Name end end
        table.sort(t)
        return t
    end
    local selected
    local dd = tp:AddDropdown({ Name = "Player", Options = playerNames(), Callback = function(v) selected = v end })
    tp:AddButton({ Name = "Refresh Players", Callback = function() dd.Refresh(playerNames(), true) end })
    tp:AddButton({ Name = "Teleport to Player", Primary = true, Callback = function()
        local p = selected and Players:FindFirstChild(selected)
        local r = p and hrpOf(p)
        if r then tpTo(r.CFrame * CFrame.new(0, 0, 3)) else notify("Teleport", "Select a player", "warning") end
    end })
    tp:AddToggle({ Name = "Spectate Player", Description = "Camera follows the selected player", Callback = function(on)
        S.spectating = on and true or nil
        if not on then
            local h = humOf(lp)
            if h then cam.CameraSubject = h end
            return
        end
        task.spawn(function()
            while alive and S.spectating do
                local p = selected and Players:FindFirstChild(selected)
                local th = p and humOf(p)
                if th then cam.CameraSubject = th end
                task.wait(0.3)
            end
        end)
    end })
    tp:AddButton({ Name = "To Murderer", Callback = function()
        local p = findByRole("Murderer")
        local r = p and hrpOf(p)
        if r then tpTo(r.CFrame * CFrame.new(0, 0, 3)) else notify("Teleport", "No murderer", "warning") end
    end })
    tp:AddButton({ Name = "To Sheriff", Callback = function()
        local p = findByRole("Sheriff") or findByRole("Hero")
        local r = p and hrpOf(p)
        if r then tpTo(r.CFrame * CFrame.new(0, 0, 3)) else notify("Teleport", "No sheriff", "warning") end
    end })
    tp:AddButton({ Name = "To Dropped Gun", Callback = function()
        local d = gunDrop()
        local part = d and (d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true))
        if part then tpTo(part.CFrame) else notify("Teleport", "No dropped gun", "warning") end
    end })
    tp:AddButton({ Name = "To Map Spawn", Callback = function()
        local m = mapModel()
        local sp2 = m and m:FindFirstChild("Spawns")
        local s = sp2 and sp2:GetChildren()[1]
        if s then tpTo(s.CFrame + Vector3.new(0, 4, 0)) else notify("Teleport", "No map loaded", "warning") end
    end })
    tp:AddButton({ Name = "To Lobby", Callback = function()
        local sps = workspace.Lobby and workspace.Lobby:FindFirstChild("Spawns")
        local s = sps and sps:GetChildren()[1]
        if s then tpTo(s.CFrame + Vector3.new(0, 4, 0)) else notify("Teleport", "Lobby not found", "warning") end
    end })
end

-- VISUALS -----------------------------------------------------------
do
    local L, R = WorldTab:Column("left"), WorldTab:Column("right")
    local w = L:CreateSection({ Name = "World", Icon = "sun", Collapsible = true })
    w:AddToggle({ Name = "Fullbright", Callback = function(v) S.fullbright = v if not v then applyLighting(false) end end })
    w:AddToggle({ Name = "No Fog", Callback = function(v) S.noFog = v end })
    w:AddToggle({ Name = "X-Ray", Description = "Makes map walls see-through", Callback = function(v) S.xray = v setXray(v) end })

    local c = R:CreateSection({ Name = "Camera", Icon = "camera", Collapsible = true })
    c:AddToggle({ Name = "Custom FOV", Callback = function(v) S.fovOn = v if not v then cam.FieldOfView = 70 end end })
    c:AddSlider({ Name = "FOV", Min = 40, Max = 120, Default = S.fovVal, Callback = function(v) S.fovVal = v end })
    c:AddToggle({ Name = "Crosshair", Callback = function(v) S.crosshair = v end })
    local specTarget
    local specNames = function()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= lp then t[#t + 1] = p.Name end end
        table.sort(t)
        return t
    end
    local sdd = c:AddDropdown({ Name = "Player", Options = specNames(), Callback = function(v) specTarget = v end })
    c:AddButton({ Name = "Refresh Players", Callback = function() sdd.Refresh(specNames(), true) end })
    c:AddToggle({ Name = "Spectate", Callback = function(v)
        if v then
            local p = specTarget and Players:FindFirstChild(specTarget)
            local h = p and humOf(p)
            if h then cam.CameraSubject = h else notify("Spectate", "Select a player", "warning") end
        else
            local h = humOf(lp)
            if h then cam.CameraSubject = h end
        end
    end })
end

-- SKINS -------------------------------------------------------------
do
    local L, R = SkinTab:Column("left"), SkinTab:Column("right")

    -- two lists, one per weapon; "Off" (the default) shows the real weapon, anything else is applied right away
    local GUN_PRESETS = {
        { "AWP Sniper", 9736025924 }, { "AK-47", 9914863724 }, { "AK-47 (mesh)", 4776045776 },
        { "Minigun", 91486152 }, { "Shotgun", 3840063 }, { "Rocket Launcher", 175731201 },
    }
    local KNIFE_PRESETS = {
        { "Banana", 13165469156 }, { "Lightsaber", 14558617502 }, { "Green Lightsaber", 12857941046 },
        { "Katana", 11401699633 }, { "Black Katana", 140237683099823 }, { "Chainsaw", 3155896845 },
    }
    local sk = L:CreateSection({ Name = "Skins", Icon = "palette", Collapsible = true })
    local function skinList(slot, title, list)
        local names, byName = { "Off" }, {}
        for _, p in ipairs(list) do names[#names + 1] = p[1] byName[p[1]] = p end
        sk:AddDropdown({ Name = title, Options = names, Default = "Off", Callback = function(v)
            v = v or "Off"
            if v == "Off" then
                SK.pick[slot] = nil
            elseif SK.list[slot][v] then
                SK.pick[slot] = v
            else
                loadSkinAsset(byName[v][2], v, slot)
            end
        end })
    end
    skinList("Gun", "Gun", GUN_PRESETS)
    skinList("Knife", "Knife", KNIFE_PRESETS)


    local lb = R:CreateSection({ Name = "Skin Library", Icon = "library", Collapsible = true })
    lb:AddLabel("Every knife and gun you see in a round is copied here, from other players' hands too. Saved to a file, so it keeps growing.")
    lb:AddToggle({ Name = "Collect Weapons", Default = true, Callback = function(v) SK.lib.on = v end })
    lb:AddStat({ Name = "Saved", Interval = 1, Get = function() return SK.lib.count.Knife .. " knives, " .. SK.lib.count.Gun .. " guns" end })
    local function libList(slot, title)
        SK.lib.names = SK.lib.names or {}
        SK.lib.dd[slot] = lb:AddDropdown({ Name = title, Options = { "Off" }, Default = "Off", Callback = function(v)
            v = v or "Off"
            if v == "Off" then SK.pick[slot] = nil return end
            for _, it in ipairs(SK.lib.items) do
                if it.slot == slot and it.label == v then return SK.lib.wear(it) end
            end
        end })
    end
    libList("Gun", "Saved Guns")
    libList("Knife", "Saved Knives")
    SK.lib.refresh()

    local av = L:CreateSection({ Name = "Avatar", Icon = "user", Collapsible = true })
    av:AddToggle({ Name = "Headless", Description = "Your head and face vanish (only on your screen)", Callback = function(v) F.headless = v end })
end

-- EFFECTS -----------------------------------------------------------
do
    local L, R = FxTab:Column("left"), FxTab:Column("right")

    local tr = L:CreateSection({ Name = "Bullet Tracers", Icon = "zap", Collapsible = true })
    local trT = tr:AddToggle({ Name = "Bullet Tracers", Icon = "zap", Description = "Beams for gun shots and knife throws", Callback = function(v) F.tracers = v end })
    trT:AddColorPicker({ Default = F.trColor, Callback = function(c) F.trColor = c end })
    tr:AddDropdown({ Name = "Style", Options = TRACER_STYLES, Default = F.trStyle, Callback = function(v) F.trStyle = v or "Streak" end })
    tr:AddDropdown({ Name = "Color Mode", Options = { "Custom", "Rainbow", "By Role" }, Default = "Custom", Callback = function(v) F.trMode = v or "Custom" end })
    tr:AddSlider({ Name = "Width", Min = 0.05, Max = 1.2, Default = F.trWidth, Decimals = 2, Callback = function(v) F.trWidth = v end })
    tr:AddSlider({ Name = "Duration", Min = 0.2, Max = 2.5, Default = F.trTime, Decimals = 1, Suffix = " s", Callback = function(v) F.trTime = v end })
    tr:AddToggle({ Name = "Impact Sparks", Default = true, Callback = function(v) F.trImpact = v end })
    tr:AddToggle({ Name = "My Shots", Default = true, Callback = function(v) F.trMine = v end })
    tr:AddToggle({ Name = "Others' Shots", Default = true, Callback = function(v) F.trOthers = v end })
    tr:AddButton({ Name = "Test Tracer", Primary = true, Callback = function()
        local r = hrpOf(lp)
        local head = char(lp) and char(lp):FindFirstChild("Head")
        local look = (head or r) and (head or r).CFrame.LookVector or cam.CFrame.LookVector
        local from = ((head or r) and (head or r).Position or cam.CFrame.Position) + look * 1.5 - Vector3.new(0, 0.5, 0)
        drawTracer(from, from + look * 70)
    end })

    local kf = L:CreateSection({ Name = "Kill Effects", Icon = "skull", Collapsible = true })
    kf:AddToggle({ Name = "Kill Effects", Icon = "skull", Callback = function(v) F.killFx = v end })
    kf:AddDropdown({ Name = "Style", Options = KILL_STYLES, Default = F.kfStyle, Callback = function(v) F.kfStyle = v or "Soul Ascend" end })
    kf:AddDropdown({ Name = "Filter", Options = { "All kills", "Only my kills", "Exclude me" }, Default = "All kills", Callback = function(v) F.kfMode = v or "All kills" end })
    kf:AddSlider({ Name = "Speed", Min = 0.5, Max = 2.5, Default = 1, Decimals = 2, Suffix = "x", Callback = function(v) F.kfSpeed = v end })
    kf:AddSlider({ Name = "Scale", Min = 0.5, Max = 2.5, Default = 1, Decimals = 2, Suffix = "x", Callback = function(v) F.kfScale = v end })
    kf:AddToggle({ Name = "Use Role Color", Default = true, Callback = function(v) F.kfRole = v end })
    kf:AddColorPicker({ Name = "Color", Default = F.kfColor, Callback = function(c) F.kfColor = c end })
    kf:AddToggle({ Name = "Floating Text", Default = true, Callback = function(v) F.kfText = v end })
    kf:AddToggle({ Name = "Camera Shake", Default = true, Callback = function(v) F.kfShake = v end })
    kf:AddToggle({ Name = "Screen Flash", Default = true, Callback = function(v) F.kfFlash = v end })
    kf:AddButton({ Name = "Preview on Me", Primary = true, Callback = function() task.spawn(killEffect, lp, true) end })

    local ob = R:CreateSection({ Name = "Objects", Icon = "orbit", Collapsible = true })
    local obT = ob:AddToggle({ Name = "My Objects", Icon = "orbit", Description = "Shapes that float around you", Callback = function(v) F.aura = v end })
    obT:AddColorPicker({ Default = F.auColor, Callback = function(c) F.auColor = c end })
    ob:AddDropdown({ Name = "Style", Options = OBJECT_STYLES, Default = F.auStyle, Callback = function(v) F.auStyle = v or "Orbs" end })
    ob:AddToggle({ Name = "Rainbow", Callback = function(v) F.auRainbow = v end })
    ob:AddSlider({ Name = "Size", Min = 0.6, Max = 2.2, Default = F.auScale, Decimals = 1, Callback = function(v) F.auScale = v end })

    local tl = R:CreateSection({ Name = "Player Trail", Icon = "wind", Collapsible = true })
    local tlT = tl:AddToggle({ Name = "Trail", Icon = "wind", Callback = function(v) F.trail = v end })
    tlT:AddColorPicker({ Default = F.trailColor, Callback = function(c) F.trailColor = c end })
    tl:AddDropdown({ Name = "Style", Options = { "Ribbon", "Comet", "Stardust", "Ripples" }, Default = F.trailStyle, Callback = function(v) F.trailStyle = v or "Ribbon" end })
    tl:AddToggle({ Name = "Rainbow", Default = true, Callback = function(v) F.trailRainbow = v end })

    local jf = R:CreateSection({ Name = "Jump Effects", Icon = "arrow-up", Collapsible = true })
    local jfT = jf:AddToggle({ Name = "Jump Effects", Icon = "arrow-up", Description = "Waves where you land, a soft ring when you jump", Callback = function(v) F.jfx = v end })
    jfT:AddColorPicker({ Default = F.jfxColor, Callback = function(c) F.jfxColor = c end })
    jf:AddDropdown({ Name = "Jump Style", Options = { "Ripple", "Shockwave", "Stardust", "Petals", "Spirit" }, Default = F.jfxStyle, Callback = function(v) F.jfxStyle = v or "Ripple" end })
    jf:AddDropdown({ Name = "Jump Colors", Options = { "Custom", "Rainbow", "By Role" }, Default = F.jfxMode, Callback = function(v) F.jfxMode = v or "Custom" end })
    jf:AddSlider({ Name = "Jump Size", Min = 0.5, Max = 2, Default = F.jfxSize, Decimals = 1, Suffix = "x", Callback = function(v) F.jfxSize = v end })
    jf:AddToggle({ Name = "Takeoff Ring", Default = true, Callback = function(v) F.jfxTakeoff = v end })
    jf:AddToggle({ Name = "Show Others", Description = "Other players' jumps too", Callback = function(v) F.jfxOthers = v end })
    jf:AddButton({ Name = "Preview Landing", Primary = true, Callback = function() if F.jfxPreview then F.jfxPreview() end end })
end

-- POST FX -----------------------------------------------------------
do
    local L, R = PostTab:Column("left"), PostTab:Column("right")
    local pr = L:CreateSection({ Name = "Presets", Icon = "clapperboard", Collapsible = true })
    PF.toggle = pr:AddToggle({ Name = "Post Processing", Icon = "clapperboard", Callback = function(v) pfEnable(v) end })
    pr:AddDropdown({ Name = "Preset", Options = PF_NAMES, Callback = function(v) if v then pfPreset(v) end end })
    pr:AddButton({ Name = "Reset Values", Callback = function()
        for k, v in pairs(PF_DEFAULT) do PF.v[k] = v end
        pfApply(true)
        for key, sl in pairs(PF.ui) do
            if typeof(PF.v[key]) == "number" then pcall(sl.Set, PF.v[key], true) end
        end
    end })

    local function sl(sec, key, name, mn, mx, dec, suffix)
        local obj = sec:AddSlider({
            Name = name, Min = mn, Max = mx, Default = PF.v[key] or mn, Decimals = dec, Suffix = suffix,
            Callback = function(v) PF.v[key] = v pfApply(false) end,
        })
        PF.ui[key] = obj
        return obj
    end

    local cg = L:CreateSection({ Name = "Color Grading", Icon = "palette", Collapsible = true })
    sl(cg, "b", "Brightness", -0.5, 0.5, 2)
    sl(cg, "c", "Contrast", -1, 1, 2)
    sl(cg, "s", "Saturation", -1, 1.5, 2)
    cg:AddColorPicker({ Name = "Tint", Default = Color3.new(1, 1, 1), Callback = function(c) PF.v.tint = c pfApply(false) end })
    sl(cg, "expo", "Exposure", -1.5, 1.5, 2)
    sl(cg, "clock", "Time of Day", 0, 24, 1, " h")

    local bl = R:CreateSection({ Name = "Bloom / Rays / Blur", Icon = "sun", Collapsible = true })
    sl(bl, "bi", "Bloom Intensity", 0, 3, 2)
    sl(bl, "bs", "Bloom Size", 0, 56, 0)
    sl(bl, "bt", "Bloom Threshold", 0, 2, 2)
    sl(bl, "ri", "Sun Rays", 0, 1, 2)
    sl(bl, "blur", "Blur", 0, 24, 0)

    local dof = R:CreateSection({ Name = "Depth of Field / Fog", Icon = "aperture", Collapsible = true })
    dof:AddToggle({ Name = "Depth of Field", Callback = function(v) PF.v.dof = v pfApply(false) end })
    sl(dof, "df", "Focus Distance", 5, 200, 0, " st")
    sl(dof, "dr", "Focus Radius", 2, 100, 0)
    sl(dof, "dfar", "Far Blur", 0, 1, 2)
    sl(dof, "ad", "Fog Density", 0, 0.8, 2)
    sl(dof, "ah", "Haze", 0, 6, 1)

    local we = L:CreateSection({ Name = "Weather", Icon = "cloud-snow", Collapsible = true })
    we:AddDropdown({ Name = "Type", Options = WEATHER_KINDS, Default = "Off", Callback = function(v) setWeather(v or "Off") end })
    we:AddSlider({ Name = "Intensity", Min = 0.4, Max = 2, Default = 1, Decimals = 1, Suffix = "x", Callback = function(v)
        weather.intensity = v
        if weather.kind ~= "Off" then setWeather(weather.kind) end
    end })
    we:AddToggle({ Name = "Atmosphere Mood", Default = true, Description = "Haze and colour grade that go with the weather", Callback = function(v)
        weather.mood = v
        if weather.kind ~= "Off" then setWeather(weather.kind) end
    end })

    local vg = L:CreateSection({ Name = "Vignette", Icon = "circle", Collapsible = true })
    vg:AddSlider({ Name = "Strength", Min = 0, Max = 100, Default = 0, Suffix = " %", Callback = function(v) setVignette(v / 100) end })
    vg:AddColorPicker({ Name = "Color", Default = Color3.new(0, 0, 0), Callback = function(c) setVignette(vig.strength, c) end })
end

-- MODELS ------------------------------------------------------------
do
    local L, R = ModelTab:Column("left"), ModelTab:Column("right")
    local rp = L:CreateSection({ Name = "Model Replacement", Icon = "box", Collapsible = true })
    rp:AddLabel("Replaces how characters look on YOUR screen only.")
    rp:AddStat({ Name = "Status", Interval = 0.5, Get = function()
        local s = MR.status
        if s:find("^Ready") then return '<font color="#3CDC82">' .. s .. "</font>" end
        if s:find("^Error") then return '<font color="#ff5a5a">' .. s .. "</font>" end
        return s
    end })
    MR.toggle = rp:AddToggle({ Name = "Replace Models", Icon = "box", Callback = function(v)
        MR.on = v
        if not v then mrDropAll()
        elseif not MR.template then notify("Model", "Model is not ready yet: " .. MR.status, "warning", 4) end
    end })
    rp:AddDropdown({ Name = "Target", Options = { "Everyone", "Me only", "Others only", "Murderer only", "Sheriff only" }, Default = "Everyone", Callback = function(v) MR.scope = v or "Everyone" end })
    local chosen = MODEL_NAMES[1]
    rp:AddDropdown({ Name = "Preset", Options = MODEL_NAMES, Default = MODEL_NAMES[1], Callback = function(v)
        chosen = v or chosen
        local m = v and modelIdByName[v]
        if m and m[2] ~= MR.templateId then loadModelAsset(m[2], true, m[3]) end
    end })
    rp:AddButton({ Name = "Load Preset", Primary = true, Callback = function()
        local m = modelIdByName[chosen]
        loadModelAsset(m[2], false, m[3])
    end })

    -- Pets: a real little character (own rig, own Humanoid) that walks, runs and jumps after you. Only you see it.
    do
        local PETS = {
            { "Tung Tung Sahur", 164815366314625 }, { "Chubby Dog", 22202531681153 }, { "Capybara", 159803432748970 },
            { "Squirrel", 178960554982276 }, { "Rabbit", 38324265921292 }, { "Cat", 3623 },
            { "Frog", 187021437835849 }, { "BIG Verity", 33498031238003 },
        }
        local ANIM = {
            idle = "rbxassetid://507766666", walk = "rbxassetid://507777826", run = "rbxassetid://507767714",
            jump = "rbxassetid://507765000", fall = "rbxassetid://507767968",
            -- things it does when you are away from the keyboard
            sit = "rbxassetid://2506281703", wave = "rbxassetid://507770239", point = "rbxassetid://507770453",
            dance = "rbxassetid://507771019", dance2 = "rbxassetid://507776043", dance3 = "rbxassetid://507777268",
            laugh = "rbxassetid://507770818", cheer = "rbxassetid://507770677",
            -- the game's own emotes
            dab = "rbxassetid://2445521505", floss = "rbxassetid://2452938820", headless = "rbxassetid://2513664073",
            zombie = "rbxassetid://2513692312", ninja = "rbxassetid://2431864798", zen = "rbxassetid://2431812646",
        }
        local LOOPING = { idle = true, walk = true, run = true, sit = true, dance = true, dance2 = true, dance3 = true,
            floss = true, zombie = true, ninja = true, zen = true }
        -- label -> animation, or a procedural move (flip, spin ...) done by code
        local EMOTE_DEFS = {
            ["Backflip"] = { proc = "flip" }, ["Front Flip"] = { proc = "frontflip" }, ["Spin Jump"] = { proc = "spin" }, ["Hop"] = { proc = "hop" },
            ["Wave"] = { anim = "wave" }, ["Point"] = { anim = "point" }, ["Cheer"] = { anim = "cheer" }, ["Laugh"] = { anim = "laugh" },
            ["Dance 1"] = { anim = "dance", loop = true }, ["Dance 2"] = { anim = "dance2", loop = true }, ["Dance 3"] = { anim = "dance3", loop = true },
            ["Dab"] = { anim = "dab" }, ["Floss"] = { anim = "floss", loop = true }, ["Headless"] = { anim = "headless" },
            ["Zombie"] = { anim = "zombie", loop = true }, ["Ninja"] = { anim = "ninja", loop = true }, ["Zen"] = { anim = "zen", loop = true },
            ["Sit"] = { anim = "sit", loop = true },
        }
        local EMOTE_ORDER = { "Backflip", "Front Flip", "Spin Jump", "Hop", "Wave", "Point", "Cheer", "Laugh", "Dance 1", "Dance 2", "Dance 3",
            "Dab", "Floss", "Headless", "Zombie", "Ninja", "Zen", "Sit" }
        local RANDOM_POOL = {}
        for _, n in ipairs(EMOTE_ORDER) do if n ~= "Sit" then RANDOM_POOL[#RANDOM_POOL + 1] = n end end
        local PT = { on = false, id = PETS[1][2], size = 0.6, baseH = 5, far = 6, close = 3, following = false, idleSince = 0, wander = nil,
            loading = false, rig = nil, hum = nil, root = nil, tracks = {}, cur = nil, status = "Off", stuck = 0, ownerChar = nil, ncs = {},
            pick = "Random", emoteLabel = "", preview = false, proc = nil, sideDir = Vector3.xAxis, lastInput = os.clock(), lastOp = nil, ownerVel = Vector3.zero, movingFor = 0, stillFor = 0, emote = nil, emoteUntil = 0, nextEmote = 0, afkEmotes = true, tick = 0, lastOwner = nil }

        local function dropPet()
            for _, c in ipairs(PT.ncs) do pcall(function() c:Destroy() end) end
            PT.ncs = {}
            if PT.rig then pcall(function() PT.rig:Destroy() end) end
            PT.rig, PT.hum, PT.root, PT.cur, PT.tracks, PT.ownerChar, PT.emote = nil, nil, nil, nil, {}, nil, nil
        end
        -- the pet must never shove you: no collisions between its body and yours
        local function ignoreOwner()
            for _, c in ipairs(PT.ncs) do pcall(function() c:Destroy() end) end
            PT.ncs = {}
            local oc = lp.Character
            PT.ownerChar = oc
            if not (oc and PT.rig) then return end
            for _, pp in ipairs(PT.rig:GetDescendants()) do
                if pp:IsA("BasePart") then
                    for _, op in ipairs(oc:GetDescendants()) do
                        if op:IsA("BasePart") then
                            local nc = Instance.new("NoCollisionConstraint")
                            nc.Part0, nc.Part1, nc.Parent = pp, op, pp
                            PT.ncs[#PT.ncs + 1] = nc
                        end
                    end
                end
            end
        end
        local function play(name, speed)
            local tr = PT.tracks[name]
            if not tr then return end
            if PT.cur ~= name then
                for n, other in pairs(PT.tracks) do if n ~= name and other.IsPlaying then other:Stop(0.2) end end
                tr:Play(0.2)
                PT.cur = name
            end
            if speed then tr:AdjustSpeed(speed) end
        end
        local function buildPet()
            if PT.loading then return end
            PT.loading, PT.status = true, "Loading..."
            task.spawn(function()
                local ok, objs = pcall(marketModel, PT.id)
                PT.loading = false
                local rig = ok and objs and objs[1]
                if not rig then PT.status = "Error: could not build" return notify("Pets", "Could not build the pet", "error", 4) end
                if not PT.on then rig:Destroy() PT.status = "Off" return end
                dropPet()
                for _, d in ipairs(rig:GetDescendants()) do
                    if d:IsA("LuaSourceContainer") then d:Destroy() end
                end
                rig.Name = "MM2Pet"
                local hum = rig:FindFirstChildOfClass("Humanoid")
                local root = rig:FindFirstChild("HumanoidRootPart")
                if not (hum and root) then rig:Destroy() PT.status = "Error: no humanoid" return end
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                hum.WalkSpeed, hum.JumpPower, hum.UseJumpPower = 16, 50, true
                -- no tumbling or ragdolling: it only ever runs, jumps and falls on its feet
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
                hum.PlatformStand = false
                -- every pet is brought to the same height first, so a tiny frog and a tall log use the same size slider
                local _, bb = rig:GetBoundingBox()
                PT.baseH = math.max(bb.Y, 0.5)
                pcall(function() rig:ScaleTo(5.2 * PT.size / PT.baseH) end)
                root.Anchored = false
                local r = hrpOf(lp)
                local spot = r and (r.CFrame * CFrame.new(3, 0, 5)).Position or Vector3.new(0, 50, 0)
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = { lp.Character, fxFolder }
                local hit = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), rp)
                local floorY = hit and hit.Position.Y or spot.Y
                rig:PivotTo(CFrame.new(spot.X, floorY + hum.HipHeight + root.Size.Y / 2 + 0.15, spot.Z))
                rig.Parent = fxFolder
                root.AssemblyLinearVelocity = Vector3.zero
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                PT.rig, PT.hum, PT.root = rig, hum, root
                local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
                for name, id in pairs(ANIM) do
                    local a = Instance.new("Animation")
                    a.AnimationId = id
                    local okTrack, tr = pcall(function() return animator:LoadAnimation(a) end)
                    if okTrack and tr then
                        tr.Looped = LOOPING[name] == true
                        PT.tracks[name] = tr
                    end
                end
                ignoreOwner()
                PT.status = "Following"
                notify("Pets", "Pet ready", "success", 3)
            end)
        end

        local pt = R:CreateSection({ Name = "Pets", Icon = "paw-print", Collapsible = true })
        pt:AddLabel("A little character that follows you on foot. Only you see it.")
        pt:AddToggle({ Name = "Pet", Icon = "paw-print", Callback = function(v)
            PT.on = v
            if v then buildPet() else dropPet() PT.status = "Off" end
        end })
        local names = {}
        for _, p in ipairs(PETS) do names[#names + 1] = p[1] end
        pt:AddDropdown({ Name = "Pet Model", Options = names, Default = names[1], Callback = function(v)
            for _, p in ipairs(PETS) do
                if p[1] == v and p[2] ~= PT.id then
                    PT.id = p[2]
                    if PT.on then dropPet() buildPet() end
                end
            end
        end })
        pt:AddSlider({ Name = "Pet Size", Min = 0.3, Max = 1.5, Default = PT.size, Decimals = 2, Suffix = "x", Callback = function(v)
            PT.size = v
            if PT.on and PT.rig then pcall(function() PT.rig:ScaleTo(5.2 * v / PT.baseH) end) end
        end })
        pt:AddSlider({ Name = "Follow Distance", Min = 3, Max = 25, Default = PT.far, Decimals = 1, Suffix = " st", Description = "While you stand it may stray this far", Callback = function(v) PT.far = v end })
        pt:AddSlider({ Name = "Stay Close", Min = 2, Max = 8, Default = PT.close, Decimals = 1, Suffix = " st", Description = "How near it stops when it catches up", Callback = function(v) PT.close = v end })
        pt:AddToggle({ Name = "AFK Emotes", Default = true, Description = "Waves, dances and sits when you stand still for a while", Callback = function(v) PT.afkEmotes = v end })
        pt:AddStat({ Name = "Status", Interval = 1, Get = function() return PT.status end })

        track(UIS.InputBegan:Connect(function() PT.lastInput = os.clock() end))
        track(UIS.InputChanged:Connect(function(i) if i.UserInputType ~= Enum.UserInputType.MouseMovement or i.Delta.Magnitude > 2 then PT.lastInput = os.clock() end end))

        local function stopEmote()
            if PT.emote then
                local tr = PT.tracks[PT.emote]
                if tr and tr.IsPlaying then tr:Stop(0.25) end
                PT.emote, PT.cur, PT.proc, PT.preview = nil, nil, nil, false
            end
        end
        local function startEmote(name, seconds)
            local tr = PT.tracks[name]
            if not tr then return end
            for n, other in pairs(PT.tracks) do if n ~= name and other.IsPlaying then other:Stop(0.2) end end
            tr:Play(0.25)
            PT.emote, PT.cur, PT.emoteUntil = name, name, os.clock() + seconds
        end

        -- moves done by code: a jump with a full turn in the air, or hops
        local function procEmote(kind)
            local rig, hum, root = PT.rig, PT.hum, PT.root
            if not (rig and hum and root) then return 0 end
            local look = root.CFrame.LookVector
            local yaw = math.atan2(-look.X, -look.Z)
            local token = {}
            PT.proc = token
            if kind == "hop" then
                task.spawn(function()
                    for _ = 1, 3 do
                        if PT.proc ~= token or not hum.Parent then return end
                        hum.Jump = true
                        task.wait(0.6)
                    end
                end)
                return 2.1
            end
            local v = 46 * math.sqrt(math.max(PT.size, 0.4) / 0.6)
            local dur = 2 * v / workspace.Gravity * 0.9
            task.spawn(function()
                hum.PlatformStand = true
                root.AssemblyLinearVelocity = Vector3.new(0, v, 0)
                local t0 = os.clock()
                while PT.proc == token and os.clock() - t0 < dur and root.Parent do
                    local dt = RunService.Heartbeat:Wait()
                    local k = dt / dur
                    if kind == "spin" then root.CFrame = root.CFrame * CFrame.Angles(0, math.pi * 4 * k, 0)
                    elseif kind == "flip" then root.CFrame = root.CFrame * CFrame.Angles(-math.pi * 2 * k, 0, 0)
                    else root.CFrame = root.CFrame * CFrame.Angles(math.pi * 2 * k, 0, 0) end
                end
                if root.Parent then root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0) end
                if hum.Parent then hum.PlatformStand = false end
            end)
            return dur + 0.7
        end
        local function startLabel(label)
            local def = EMOTE_DEFS[label]
            if not def then return false end
            PT.emoteLabel = label
            if def.proc then
                local secs = procEmote(def.proc)
                PT.emote, PT.cur, PT.emoteUntil = "proc", "proc", os.clock() + secs
                return true
            end
            local tr = PT.tracks[def.anim]
            if not tr then return false end
            local secs = def.loop and (4 + math.random() * 3) or math.max((tr.Length > 0 and tr.Length or 3) + 0.3, 1)
            startEmote(def.anim, secs)
            return true
        end
        local pickNames = { "Random" }
        for _, n in ipairs(EMOTE_ORDER) do pickNames[#pickNames + 1] = n end
        pt:AddDropdown({ Name = "AFK Emote", Options = pickNames, Default = "Random", Description = "One emote, or a random one each time", Callback = function(v) PT.pick = v or "Random" end })
        pt:AddButton({ Name = "Play Emote Now", Callback = function()
            if not (PT.on and PT.rig) then return notify("Pets", "Turn the pet on first", "warning") end
            stopEmote()
            local label = PT.pick == "Random" and RANDOM_POOL[math.random(#RANDOM_POOL)] or PT.pick
            PT.preview = true
            PT.following = false
            startLabel(label)
        end })

        -- one brain step: where to walk and what to do
        local function think(dt)
            local rig, hum, root = PT.rig, PT.hum, PT.root
            local r = hrpOf(lp)
            if not (PT.on and rig and rig.Parent and hum and root and r) then return end
            if PT.ownerChar ~= lp.Character then ignoreOwner() end
            local op, rp = r.Position, root.Position
            -- your speed is measured from where you actually are (smoothed), not from the physics velocity, which can flicker
            if PT.lastOp and dt > 0 then
                local inst = Vector3.new(op.X - PT.lastOp.X, 0, op.Z - PT.lastOp.Z) / dt
                if inst.Magnitude < 120 then PT.ownerVel = PT.ownerVel:Lerp(inst, 0.35) end
            end
            PT.lastOp = op
            local ov = PT.ownerVel
            local ownerSpeed = ov.Magnitude
            if ownerSpeed > 2.5 then PT.movingFor, PT.stillFor = PT.movingFor + dt, 0 else PT.stillFor, PT.movingFor = PT.stillFor + dt, 0 end
            local toOwner = Vector3.new(op.X - rp.X, 0, op.Z - rp.Z)
            local d = toOwner.Magnitude
            if d > 3 then PT.sideDir = -toOwner / d end   -- the side of you it is on; kept while it stands next to you
            if d > 70 or rp.Y < op.Y - 80 then
                local a = math.random() * math.pi * 2
                local spot = op + Vector3.new(math.cos(a) * PT.close, 0, math.sin(a) * PT.close)
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = { lp.Character, fxFolder }
                local hit = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), rp)
                local floorY = hit and hit.Position.Y or spot.Y
                rig:PivotTo(CFrame.new(spot.X, floorY + hum.HipHeight + root.Size.Y / 2 + 0.15, spot.Z))
                root.AssemblyLinearVelocity = Vector3.zero
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                PT.following, PT.wander, PT.stuck = false, nil, 0
                stopEmote()
                return
            end
            local ownerMoving = PT.movingFor > 0 or PT.stillFor < 0.35 and PT.following
            -- following starts the moment you walk off, and keeps going for as long as you move (no stop-and-go)
            if ownerMoving and d > PT.close * 0.8 then
                PT.following = true
            elseif PT.following and not ownerMoving and d <= PT.close + 1 then
                PT.following, PT.idleSince = false, os.clock()
            elseif not PT.following and d > PT.far then
                PT.following = true
            end

            if PT.following then
                PT.status = "Following"
                stopEmote()
                PT.wander = nil
                local rel = Vector3.new(rp.X - op.X, 0, rp.Z - op.Z)
                local dirOwner = ownerSpeed > 1.5 and ov.Unit or nil
                local want, speed
                if dirOwner and rel:Dot(dirOwner) > 0 and d < PT.close * 2.2 then
                    -- it is in front of you as you walk: step out of your way and drop behind, never ahead
                    local perp = Vector3.new(-dirOwner.Z, 0, dirOwner.X)
                    local sgn = rel:Dot(perp) >= 0 and 1 or -1
                    want = op - dirOwner * PT.close * 1.3 + perp * sgn * PT.close * 0.8
                    speed = ownerSpeed + 12
                else
                    -- it keeps the side it is on; it only hurries when it is really behind, and never faster than you once close
                    want = op + PT.sideDir * PT.close
                    speed = d > PT.close * 2.2 and (ownerSpeed + (d - PT.close) * 4 + 2) or math.max(8, ownerSpeed + (d - PT.close) * 1.5)
                end
                hum.WalkSpeed = math.clamp(speed, 8, 46)
                hum:MoveTo(want)
                local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
                if moving < 1 and d > PT.close + 1.5 then
                    PT.stuck += dt
                    if PT.stuck > 0.45 then hum.Jump = true PT.stuck = 0 end
                else
                    PT.stuck = 0
                end
                return
            end

            -- resting beside you
            local afk = PT.stillFor > 8 or (os.clock() - PT.lastInput > 10 and ownerSpeed < 0.5)
            if PT.emote then
                if (not PT.preview and (not afk or not PT.afkEmotes)) or os.clock() > PT.emoteUntil then stopEmote() PT.nextEmote = os.clock() + 1.5 + math.random() * 2.5 end
            elseif afk and PT.afkEmotes and os.clock() > PT.nextEmote and not PT.wander then
                if PT.pick == "Random" then
                    if os.clock() - PT.lastInput > 45 and PT.tracks.sit then
                        PT.emoteLabel = "Sit"
                        startEmote("sit", 1e9)
                    else
                        startLabel(RANDOM_POOL[math.random(#RANDOM_POOL)])
                    end
                else
                    startLabel(PT.pick)
                end
            end
            if PT.emote then
                PT.status = PT.emote == "sit" and "Sitting (you are AFK)" or ("Emote: " .. PT.emoteLabel)
                hum:Move(Vector3.zero)
                hum:MoveTo(rp)
                if toOwner.Magnitude > 0.1 and PT.emote ~= "sit" and PT.emote ~= "proc" then
                    root.CFrame = root.CFrame:Lerp(CFrame.lookAt(rp, rp + toOwner), 0.12)
                end
                return
            end
            if PT.wander then
                local left = Vector3.new(PT.wander.X - rp.X, 0, PT.wander.Z - rp.Z).Magnitude
                if left < 1.2 or os.clock() - PT.idleSince > 4 then PT.wander, PT.idleSince = nil, os.clock() end
            end
            if PT.wander then
                PT.status = "Strolling"
                hum.WalkSpeed = 7
                hum:MoveTo(PT.wander)
            else
                PT.status = afk and "Waiting" or "Resting"
                hum:Move(Vector3.zero)
                hum:MoveTo(rp)
                if toOwner.Magnitude > 0.1 then root.CFrame = root.CFrame:Lerp(CFrame.lookAt(rp, rp + toOwner), 0.2) end
                if not afk and os.clock() - PT.idleSince > 3 + math.random() * 3 then
                    local a, rad = math.random() * math.pi * 2, 2 + math.random() * 2
                    local spot = rp + Vector3.new(math.cos(a) * rad, 0, math.sin(a) * rad)
                    local sd = Vector3.new(spot.X - op.X, 0, spot.Z - op.Z).Magnitude
                    if sd < PT.far - 0.5 and sd > 2 then PT.wander = spot end
                    PT.idleSince = os.clock()
                end
            end
        end
        track(RunService.Heartbeat:Connect(function(dt)
            PT.tick += dt
            if PT.tick >= 0.05 then
                local step = PT.tick
                PT.tick = 0
                pcall(think, step)
            end
            -- animation follows the real movement, unless an emote is playing
            if not (PT.on and PT.root and PT.hum and PT.hum.Parent) or PT.emote then return end
            local v = PT.root.AssemblyLinearVelocity
            local speed = Vector3.new(v.X, 0, v.Z).Magnitude
            local air = PT.hum.FloorMaterial == Enum.Material.Air
            if air and v.Y > 4 then play("jump")
            elseif air and v.Y < -4 then play("fall")
            elseif speed < 0.6 then play("idle")
            elseif speed < 11 then play("walk", math.clamp(speed / 14, 0.4, 1.4))
            else play("run", math.clamp(speed / 20, 0.6, 1.6)) end
        end))
        onCleanup(function() PT.on = false dropPet() end)
    end
end

-- HALLOWEEN ---------------------------------------------------------
do
    local HW = { collect = false, range = 400, speed = 60, avoid = true, got = 0, bad = {}, what = "Candies", resetFull = false, bag = 40,
        boxId = "Halloween2026Box", cur = "Candies2026", delay = 1.5, opened = 0, crateOn = false, crateBusy = false, lastDrop = "-" }
    local L, R = HalloweenTab:Column("left"), HalloweenTab:Column("right")

    local function candies()
        local map = mapModel()
        local cc = map and map:FindFirstChild("CoinContainer")
        local out = {}
        if cc then
            for _, c in ipairs(cc:GetChildren()) do
                if c:IsA("BasePart") and tostring(c:GetAttribute("CoinID")) == "Candy" then out[#out + 1] = c end
            end
        end
        return out
    end
    -- what the farm goes for: candies, ordinary coins or both; coins already taken carry a Collected attribute
    local function targets()
        local map = mapModel()
        local cc = map and map:FindFirstChild("CoinContainer")
        local out = {}
        if cc then
            for _, c in ipairs(cc:GetChildren()) do
                if c:IsA("BasePart") and not c:GetAttribute("Collected") then
                    local isCandy = tostring(c:GetAttribute("CoinID")) == "Candy"
                    if HW.what == "Both" or (HW.what == "Candies" and isCandy) or (HW.what == "Coins" and not isCandy) then out[#out + 1] = c end
                end
            end
        end
        return out
    end
    local function bagFull()
        local n = tonumber(lp:GetAttribute("Coins"))
        if not n then
            local d = pdata(lp)
            n = d and tonumber(d.Coins)
        end
        return n ~= nil and n >= HW.bag
    end
    local function murdererPos()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and getRole(p) == "Murderer" then
                local r = hrpOf(p)
                if r and visAlive(p) then return r.Position end
            end
        end
    end

    -- Candy ESP ---------------------------------------------------------
    local ce = L:CreateSection({ Name = "Candy ESP", Icon = "eye", Collapsible = true })
    local ceT = ce:AddToggle({ Name = "Candy ESP", Icon = "eye", Description = "Outline and label on every candy (and coin)", Callback = function(v) E.coins = v end })
    ceT:AddColorPicker({ Default = E.coinCol, Callback = function(c) E.coinCol = c end })
    ce:AddSlider({ Name = "Range", Min = 30, Max = 800, Default = E.coinMax, Suffix = " st", Callback = function(v) E.coinMax = v end })
    ce:AddStat({ Name = "Candies on map", Interval = 1, Get = function() return tostring(#candies()) end })
    ce:AddStat({ Name = "Collected", Interval = 1, Get = function() return tostring(HW.got) end })

    -- Candy collector ---------------------------------------------------
    local co = R:CreateSection({ Name = "Auto Farm", Icon = "candy", Collapsible = true })
    co:AddToggle({ Name = "Auto Collect", Icon = "candy", Description = "Flies to the nearest candy by itself", Callback = function(v)
        HW.collect = v
        HW.bad = {}
        if not v then HW.flying = false end
    end })
    co:AddDropdown({ Name = "Collect", Options = { "Candies", "Coins", "Both" }, Default = HW.what, Callback = function(v) HW.what = v or "Candies" end })
    co:AddSlider({ Name = "Fly Speed", Min = 10, Max = 150, Default = HW.speed, Suffix = " st/s", Callback = function(v) HW.speed = v end })
    co:AddToggle({ Name = "Reset On Full Bag", Description = "Resets your character when the bag is full, otherwise waits", Callback = function(v) HW.resetFull = v end })
    co:AddSlider({ Name = "Bag Size", Min = 10, Max = 100, Default = HW.bag, Description = "Counts as full from this many", Callback = function(v) HW.bag = v end })
    co:AddSlider({ Name = "Range", Min = 50, Max = 800, Default = HW.range, Suffix = " st", Callback = function(v) HW.range = v end })
    co:AddToggle({ Name = "Avoid Murderer", Default = true, Description = "Skips candies close to the murderer", Callback = function(v) HW.avoid = v end })
    co:AddLabel("Flies to each candy in a straight line, through walls (noclip).")

    -- Fly keeps the body from colliding with anything
    track(RunService.Stepped:Connect(function()
        if not HW.flying then return end
        local c = lp.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end))
    task.spawn(function()
        while alive do
            if HW.collect then
                pcall(function()
                    local r, h = hrpOf(lp), humOf(lp)
                    if not (r and h and h.Health > 0 and visAlive(lp)) then return end
                    if bagFull() then
                        if HW.resetFull then h.Health = 0 task.wait(4) end
                        return
                    end
                    local murd = (HW.avoid and getRole(lp) ~= "Murderer") and murdererPos() or nil
                    local best, bd = nil, HW.range
                    for _, c in ipairs(targets()) do
                        local d = (c.Position - r.Position).Magnitude
                        if d < bd and not (HW.bad[c] and os.clock() < HW.bad[c]) and not (murd and (c.Position - murd).Magnitude < 22) then
                            best, bd = c, d
                        end
                    end
                    if not best then return end
                    HW.flying = true
                    local t0 = os.clock()
                    while HW.collect and alive and best.Parent and os.clock() - t0 < 12 do
                        r, h = hrpOf(lp), humOf(lp)
                        if not (r and h and h.Health > 0) then break end
                        local to = best.Position - r.Position
                        if to.Magnitude < 2.5 then break end
                        local dt = RunService.Heartbeat:Wait()
                        local step = math.min(HW.speed * dt, to.Magnitude)
                        r.CFrame = CFrame.new(r.Position + to.Unit * step) * (r.CFrame - r.CFrame.Position)
                        r.AssemblyLinearVelocity = Vector3.zero
                    end
                    HW.flying = false
                    if not best.Parent then HW.got += 1 else HW.bad[best] = os.clock() + 6 end
                end)
            end
            task.wait(0.12)
        end
    end)
    onCleanup(function() HW.collect, HW.flying, HW.crateOn = false, false, false end)

    -- Mystery boxes: pays for a box with the chosen currency and opens it, once or on a loop
    local cr = L:CreateSection({ Name = "Mystery Boxes", Icon = "gift", Collapsible = true })
    cr:AddTextbox({ Name = "Box ID", Default = HW.boxId, Placeholder = "e.g. Halloween2026Box", Callback = function(t) if t ~= "" then HW.boxId = t end end })
    cr:AddDropdown({ Name = "Pay With", Options = { "Candies2026", "HalloweenKey2026", "Coins", "Key", "Gems" }, Default = HW.cur, Callback = function(v) HW.cur = v or HW.cur end })
    cr:AddSlider({ Name = "Open Delay", Min = 0.5, Max = 5, Default = HW.delay, Decimals = 1, Suffix = " s", Callback = function(v) HW.delay = v end })
    local function openBox()
        if HW.crateBusy then return false end
        local shop = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Shop")
        local rem = shop and shop:FindFirstChild("OpenCrate")
        if not (rem and rem:IsA("RemoteFunction")) then notify("Boxes", "Box system not found", "warning") return false end
        HW.crateBusy = true
        local ok, reward = pcall(function() return rem:InvokeServer(HW.boxId, "MysteryBox", HW.cur) end)
        HW.crateBusy = false
        if ok and reward then
            HW.opened += 1
            HW.lastDrop = tostring(reward)
            return true
        end
        return false
    end
    cr:AddButton({ Name = "Open Once", Primary = true, Callback = function()
        task.spawn(function()
            if openBox() then notify("Boxes", "Got: " .. HW.lastDrop, "success", 4) else notify("Boxes", "Could not open (not enough " .. HW.cur .. "?)", "warning") end
        end)
    end })
    cr:AddToggle({ Name = "Auto Open", Description = "Keeps opening until you run out", Callback = function(v) HW.crateOn = v end })
    cr:AddStat({ Name = "Opened", Interval = 1, Get = function() return tostring(HW.opened) end })
    cr:AddStat({ Name = "Last Drop", Interval = 1, Get = function() return HW.lastDrop end })
    task.spawn(function()
        while alive do
            if HW.crateOn then
                local ok = openBox()
                if not ok then HW.crateOn = false notify("Boxes", "Auto Open stopped: nothing left to pay with", "warning") end
                task.wait(HW.delay)
            else
                task.wait(0.3)
            end
        end
    end)
end

-- EXTRAS: defense, sounds, music, emotes, HUD, trade guard -------------------------------------
do
    local R = MiscSub.right
    local SoundService = game:GetService("SoundService")
    local Stats = game:GetService("Stats")

    do
    -- Defense ---------------------------------------------------------
    local df = R:CreateSection({ Name = "Defense", Icon = "shield", Collapsible = true })
    local AA = { on = false, strength = 20 }
    df:AddToggle({ Name = "Anti Aim", Icon = "shield", Description = "Experimental: gives aimbots that predict your movement a jittering velocity", Callback = function(v) AA.on = v end })
    df:AddSlider({ Name = "Anti Aim Strength", Min = 5, Max = 80, Default = AA.strength, Suffix = " st/s", Callback = function(v) AA.strength = v end })
    task.spawn(function()
        while alive do
            local r = AA.on and hrpOf(lp)
            if r and visAlive(lp) then
                local real = r.AssemblyLinearVelocity
                local j = AA.strength
                r.AssemblyLinearVelocity = real + Vector3.new(math.random(-j, j), 0, math.random(-j, j))
                RunService.RenderStepped:Wait()
                if r.Parent then r.AssemblyLinearVelocity = real end
            end
            RunService.Heartbeat:Wait()
        end
    end)

    -- a thrown knife flying at you: sidestep and hop instead of standing still
    local DK = { on = false, last = {}, cool = 0 }
    df:AddToggle({ Name = "Dodge Thrown Knife", Description = "Sidesteps a knife that is flying straight at you", Callback = function(v) DK.on = v end })
    track(RunService.Heartbeat:Connect(function(dt)
        if not DK.on or getRole(lp) == "Murderer" then return end
        local r = hrpOf(lp)
        if not (r and visAlive(lp)) then return end
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name == "ThrowingKnife" then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local prev = DK.last[obj]
                    DK.last[obj] = part.Position
                    if prev and dt > 0 then
                        local vel = (part.Position - prev) / dt
                        local toMe = r.Position - part.Position
                        if vel.Magnitude > 12 and toMe.Magnitude < 24 and vel.Unit:Dot(toMe.Unit) > 0.85 and os.clock() > DK.cool then
                            DK.cool = os.clock() + 0.5
                            local side = vel.Unit:Cross(Vector3.yAxis)
                            if side.Magnitude > 0.01 then
                                r.AssemblyLinearVelocity = side.Unit * (math.random() < 0.5 and 55 or -55) + Vector3.new(0, 28, 0)
                            end
                        end
                    end
                end
            end
        end
        for obj in pairs(DK.last) do if not obj.Parent then DK.last[obj] = nil end end
    end))

    -- trades: warn when a trade changes (a script can add items behind your back) and optionally refuse
    local TG = { on = false, decline = false }
    local tradeFolder = RS:FindFirstChild("Trade")
    local updateTrade = tradeFolder and tradeFolder:FindFirstChild("UpdateTrade")
    local declineTrade = tradeFolder and tradeFolder:FindFirstChild("DeclineTrade")
    df:AddToggle({ Name = "Trade Guard", Description = "Warns whenever your trade offer changes", Callback = function(v) TG.on = v end })
    df:AddToggle({ Name = "Trade Guard: Decline", Description = "Also declines the trade right away", Callback = function(v) TG.decline = v end })
    if updateTrade and updateTrade:IsA("RemoteEvent") then
        track(updateTrade.OnClientEvent:Connect(function()
            if not TG.on then return end
            notify("Trade Guard", "Your trade just changed - check what is in it", "warning", 6)
            if TG.decline and declineTrade then pcall(function() declineTrade:FireServer() end) end
        end))
    end

    -- Ghost: when the murderer gets close, your real body drops underground (where nothing can reach it) and a see-through
    -- copy of you stays on the surface, mirroring every step and animation. It comes back when the murderer is gone.
    local GH = { on = false, range = 30, alpha = 0.55, active = false, depth = 45, since = 0 }
    function GH.ground(x, z, from)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local ex = {}
        if GH.clone then ex[#ex + 1] = GH.clone end
        if GH.plat then ex[#ex + 1] = GH.plat end
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then ex[#ex + 1] = p.Character end end
        rp.FilterDescendantsInstances = ex
        local hit = workspace:Raycast(Vector3.new(x, from + 8, z), Vector3.new(0, -160, 0), rp)
        return hit and hit.Position.Y or from
    end
    function GH.applyAlpha()
        GH.shownAlpha = GH.alpha
        for _, pr in ipairs(GH.pairs or {}) do
            if pr.vis and pr.clone.Parent then pr.clone.Transparency = GH.alpha end
        end
        if GH.clone then
            for _, d in ipairs(GH.clone:GetDescendants()) do
                if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = math.max(d.Transparency, GH.alpha) end
            end
        end
    end
    function GH.start()
        local c, r, h = lp.Character, hrpOf(lp), humOf(lp)
        if GH.active or not (c and r and h) then return end
        local arch = c.Archivable
        c.Archivable = true
        local ok, clone = pcall(function() return c:Clone() end)
        c.Archivable = arch
        if not (ok and clone) then return end
        clone.Name = "MM2Ghost"
        -- pair every real part with its copy (a clone keeps the same order), then drop tools and scripts from the copy
        GH.pairs = {}
        local function walk(ra, rb)
            local used = {}
            for _, ca in ipairs(ra:GetChildren()) do
                -- match the same name, counting duplicates among siblings (several "Handle"s, accessories ...)
                local n = (used[ca.Name] or 0) + 1
                used[ca.Name] = n
                local seen, cb = 0, nil
                for _, x in ipairs(rb:GetChildren()) do
                    if x.Name == ca.Name then
                        seen += 1
                        if seen == n then cb = x break end
                    end
                end
                if cb and not ca:IsA("Tool") then
                    if ca:IsA("BasePart") and cb:IsA("BasePart") then
                        GH.pairs[#GH.pairs + 1] = { real = ca, clone = cb, vis = ca.Transparency < 0.99 and ca ~= r }
                    end
                    walk(ca, cb)
                end
            end
        end
        walk(c, clone)
        local kill = {}
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Tool") or d:IsA("LuaSourceContainer") or d:IsA("Animator") or d:IsA("Sound") then kill[#kill + 1] = d end
        end
        for _, d in ipairs(kill) do pcall(function() d:Destroy() end) end
        local live = {}
        for _, pr in ipairs(GH.pairs) do
            if pr.clone:IsDescendantOf(clone) then
                pr.clone.Anchored, pr.clone.CanCollide, pr.clone.CanQuery, pr.clone.CanTouch, pr.clone.CastShadow = true, false, false, false, false
                if not pr.vis then pr.clone.Transparency = 1 end
                live[#live + 1] = pr
            end
        end
        GH.pairs = live
        local ch = clone:FindFirstChildOfClass("Humanoid")
        if ch then
            ch.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            ch.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            ch.WalkSpeed = 0
        end
        GH.chum = ch
        GH.clone = clone
        local floorY = GH.ground(r.Position.X, r.Position.Z, r.Position.Y)
        GH.floor = floorY
        GH.plat0 = floorY - GH.depth
        local plat = Instance.new("Part")
        plat.Name = "MM2GhostFloor"
        plat.Anchored, plat.CanCollide, plat.CanQuery, plat.CanTouch, plat.CastShadow = true, true, false, false, false
        plat.Transparency = 1
        plat.Size = Vector3.new(220, 2, 220)
        plat.Position = Vector3.new(r.Position.X, GH.plat0 - 1, r.Position.Z)
        plat.Parent = workspace.Terrain
        GH.plat = plat
        GH.applyAlpha()
        clone.Parent = workspace.Terrain
        c:PivotTo(c:GetPivot() - Vector3.new(0, GH.depth, 0))
        r.AssemblyLinearVelocity = Vector3.zero
        GH.active, GH.since = true, os.clock()
        if ch then cam.CameraSubject = ch end
        notify("Ghost", "Murderer nearby - your body is underground", "info", 3)
    end
    function GH.stop()
        if not GH.active then return end
        GH.active = false
        local c, r = lp.Character, hrpOf(lp)
        local cr = GH.clone and GH.clone:FindFirstChild("HumanoidRootPart")
        if c and r and cr and visAlive(lp) then
            c:PivotTo(cr.CFrame)
            r.AssemblyLinearVelocity = Vector3.zero
        end
        if GH.clone then pcall(function() GH.clone:Destroy() end) end
        if GH.plat then pcall(function() GH.plat:Destroy() end) end
        GH.clone, GH.plat, GH.pairs, GH.chum = nil, nil, nil, nil
        local h = humOf(lp)
        if h then cam.CameraSubject = h end
    end
    track(RunService.RenderStepped:Connect(function()
        if not GH.active then return end
        local r = hrpOf(lp)
        if not (r and GH.clone and GH.clone.Parent and visAlive(lp)) then return GH.stop() end
        GH.floor = GH.floor + (GH.ground(r.Position.X, r.Position.Z, GH.floor) - GH.floor) * 0.35
        local off = Vector3.new(0, GH.floor - GH.plat0, 0)
        local parts, cfs = {}, {}
        for _, pr in ipairs(GH.pairs) do
            if pr.real.Parent and pr.clone.Parent then
                parts[#parts + 1] = pr.clone
                cfs[#cfs + 1] = pr.real.CFrame + off
            end
        end
        workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
        GH.plat.Position = Vector3.new(r.Position.X, GH.plat0 - 1, r.Position.Z)
        if GH.shownAlpha ~= GH.alpha then GH.applyAlpha() end
        if GH.chum and cam.CameraSubject ~= GH.chum then cam.CameraSubject = GH.chum end
    end))
    task.spawn(function()
        while alive do
            pcall(function()
                local role = getRole(lp)
                if not GH.on or not visAlive(lp) or role == "Murderer" or role == "Lobby" then return GH.stop() end
                local m = findByRole("Murderer")
                local mr = m and m ~= lp and visAlive(m) and hrpOf(m)
                local me = GH.active and GH.clone and GH.clone:FindFirstChild("HumanoidRootPart") or hrpOf(lp)
                if not me then return end
                local d = mr and (mr.Position - me.Position).Magnitude or math.huge
                if not GH.active and d < GH.range then
                    GH.start()
                elseif GH.active and d > GH.range + 10 and os.clock() - GH.since > 1.5 then
                    GH.stop()
                    notify("Ghost", "Clear - you are back on the surface", "success", 2)
                end
            end)
            task.wait(0.1)
        end
    end)
    onCleanup(function() GH.on = false pcall(GH.stop) end)
    df:AddToggle({ Name = "Ghost Mode", Icon = "ghost", Description = "When the murderer comes close your real body drops underground and a see-through copy of you stays on the map", Callback = function(v) GH.on = v if not v then GH.stop() end end })
    df:AddSlider({ Name = "Ghost Range", Min = 10, Max = 80, Default = GH.range, Suffix = " st", Callback = function(v) GH.range = v end })
    df:AddSlider({ Name = "Ghost Transparency", Min = 0.2, Max = 0.9, Default = GH.alpha, Decimals = 2, Callback = function(v) GH.alpha = v end })
    df:AddStat({ Name = "Ghost", Interval = 0.5, Get = function() return GH.active and "underground" or (GH.on and "watching" or "off") end })
    end

    do
    -- Sounds ----------------------------------------------------------
    local SOUNDS = {
        Ping = "rbxasset://sounds/electronicpingshort.wav", Oof = "rbxasset://sounds/uuhhh.mp3", Slash = "rbxasset://sounds/swordslash.wav",
        Snap = "rbxasset://sounds/snap.mp3", Bass = "rbxasset://sounds/bass.wav", Click = "rbxasset://sounds/clickfast.wav", Glass = "rbxasset://sounds/glassbreak.wav",
    }
    local SOUND_NAMES = { "Ping", "Oof", "Slash", "Snap", "Bass", "Click", "Glass" }
    local SND = {
        kill = { on = false, name = "Oof", vol = 60, mineOnly = true, custom = "" },
        shot = { on = false, name = "Click", vol = 50, custom = "" },
        role = { on = false, name = "Ping", vol = 60, custom = "" },
    }
    F.sndPlay = function(kind, mine)
        local c = SND[kind]
        if not (c and c.on) then return end
        if kind == "kill" and c.mineOnly and not mine then return end
        local id = (c.custom ~= "" and (tonumber(c.custom) and ("rbxassetid://" .. c.custom) or c.custom)) or SOUNDS[c.name]
        local s = Instance.new("Sound")
        s.SoundId, s.Volume = id, c.vol / 100 * 2
        s.Parent = SoundService
        s:Play()
        Debris:AddItem(s, 6)
    end
    local sd = MiscSub.soundL:CreateSection({ Name = "Sounds", Icon = "volume-2", Collapsible = true })
    local function soundGroup(kind, title, extra)
        local c = SND[kind]
        sd:AddToggle({ Name = title, Callback = function(v) c.on = v end })
        sd:AddDropdown({ Name = title .. " Sound", Options = SOUND_NAMES, Default = c.name, Callback = function(v) c.name = v or c.name end })
        sd:AddTextbox({ Name = title .. " Custom ID", Placeholder = "audio asset id (optional)", Callback = function(t) c.custom = t end })
        sd:AddSlider({ Name = title .. " Volume", Min = 0, Max = 100, Default = c.vol, Suffix = " %", Callback = function(v) c.vol = v end })
        if extra then extra() end
    end
    soundGroup("kill", "Kill", function()
        sd:AddToggle({ Name = "Only My Kills", Default = true, Callback = function(v) SND.kill.mineOnly = v end })
    end)
    soundGroup("shot", "Shot")
    soundGroup("role", "Role Reveal")
    sd:AddButton({ Name = "Test Kill Sound", Callback = function()
        local was = SND.kill.on SND.kill.on = true
        F.sndPlay("kill", true)
        SND.kill.on = was
    end })
    end

    do
    -- Round music -----------------------------------------------------
    local MU = { auto = false, id = "", vol = 40, loop = true, snd = nil }
    local function stopMusic() if MU.snd then pcall(function() MU.snd:Destroy() end) MU.snd = nil end end
    local function playMusic()
        if MU.id == "" then return notify("Music", "Enter an audio asset id first", "warning") end
        stopMusic()
        local s = Instance.new("Sound")
        s.SoundId = tonumber(MU.id) and ("rbxassetid://" .. MU.id) or MU.id
        s.Volume, s.Looped = MU.vol / 100 * 2, MU.loop
        s.Parent = SoundService
        s:Play()
        MU.snd = s
    end
    local mu = MiscSub.soundR:CreateSection({ Name = "Round Music", Icon = "music", Collapsible = true })
    mu:AddTextbox({ Name = "Music ID", Placeholder = "audio asset id", Callback = function(t) MU.id = t end })
    mu:AddSlider({ Name = "Music Volume", Min = 0, Max = 100, Default = MU.vol, Suffix = " %", Callback = function(v) MU.vol = v if MU.snd then MU.snd.Volume = v / 100 * 2 end end })
    mu:AddToggle({ Name = "Loop", Default = true, Callback = function(v) MU.loop = v if MU.snd then MU.snd.Looped = v end end })
    mu:AddToggle({ Name = "Play On Round Start", Description = "Starts when a round begins, stops when it ends", Callback = function(v) MU.auto = v end })
    mu:AddButton({ Name = "Play", Primary = true, Callback = playMusic })
    mu:AddButton({ Name = "Stop", Callback = stopMusic })
    local gpr = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Gameplay")
    local rs = gpr and gpr:FindFirstChild("RoundStart")
    local go = gpr and gpr:FindFirstChild("GameOver")
    if rs and rs:IsA("RemoteEvent") then track(rs.OnClientEvent:Connect(function() if MU.auto then playMusic() end end)) end
    if go and go:IsA("RemoteEvent") then track(go.OnClientEvent:Connect(function() if MU.auto then stopMusic() end end)) end
    onCleanup(stopMusic)
    end

    do
    -- Emotes ----------------------------------------------------------
    local EM = { name = "ninja", auto = false }
    local em = R:CreateSection({ Name = "Emotes", Icon = "smile", Collapsible = true })
    em:AddDropdown({ Name = "Emote", Options = { "ninja", "dab", "floss", "headless", "zen", "zombie", "sit" }, Default = EM.name, Callback = function(v) EM.name = v or EM.name end })
    local function fireEmote()
        local misc = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Misc")
        local ev = misc and misc:FindFirstChild("PlayEmote")
        if ev and ev:IsA("BindableEvent") then ev:Fire(EM.name) else notify("Emotes", "Emote system not found", "warning") end
    end
    em:AddButton({ Name = "Play Emote", Primary = true, Callback = fireEmote })
    em:AddToggle({ Name = "Auto Emote", Description = "Keeps the emote going", Callback = function(v) EM.auto = v end })
    task.spawn(function()
        while alive do
            if EM.auto and visAlive(lp) then pcall(function()
                local misc = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Misc")
                local ev = misc and misc:FindFirstChild("PlayEmote")
                if ev and ev:IsA("BindableEvent") then ev:Fire(EM.name) end
            end) end
            task.wait(1.5)
        end
    end)
    end

    do
    -- HUD / performance ----------------------------------------------
    local hu = R:CreateSection({ Name = "HUD", Icon = "gauge", Collapsible = true })
    local label = Instance.new("TextLabel")
    label.Name = "MM2Hud"
    label.AnchorPoint = Vector2.new(0, 0)
    label.Position = UDim2.fromOffset(12, 12)
    label.AutomaticSize = Enum.AutomaticSize.XY
    label.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    label.BackgroundTransparency = 0.25
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.Visible = false
    label.ZIndex = 5
    local pad = Instance.new("UIPadding") pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 4) pad.Parent = label
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 6) corner.Parent = label
    label.Parent = overlay
    local frames, fps = 0, 60
    track(RunService.RenderStepped:Connect(function() frames += 1 end))
    task.spawn(function()
        while alive do
            local t0 = os.clock()
            local f0 = frames
            task.wait(0.5)
            fps = (frames - f0) / math.max(os.clock() - t0, 0.01)
            if label.Visible then
                local ping = safe(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end) or 0
                label.Text = string.format("Moro MM2   %d fps   %d ms   %s", math.floor(fps + 0.5), math.floor(ping + 0.5), os.date("%H:%M"))
            end
        end
    end)
    hu:AddToggle({ Name = "Watermark", Description = "FPS, ping and time in the corner", Callback = function(v) label.Visible = v end })
    hu:AddToggle({ Name = "FPS Unlocker", Description = "Removes the 60 fps cap", Callback = function(v)
        if setfpscap then pcall(setfpscap, v and 9999 or 60) else notify("HUD", "Your executor has no setfpscap", "warning") end
    end })
    hu:AddToggle({ Name = "Disable 3D Rendering", Description = "Black screen, almost no GPU use", Callback = function(v)
        pcall(function() RunService:Set3dRenderingEnabled(not v) end)
    end })
    onCleanup(function()
        label:Destroy()
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
    end)
    end

    do
    -- Map vote duplication --------------------------------------------
    -- Standing on a vote pad counts a vote; dying and standing on it again counts another one
    local VT = { busy = false, stop = false, done = 0, want = 0, status = "Idle", pad = 1, count = 10 }
    local function votePads()
        local lobby = workspace:FindFirstChild("RegularLobby")
        local folder = lobby and lobby:FindFirstChild("VotePads")
        if folder and lobby:FindFirstChild("VotePad1") then return lobby, folder end
        for _, m in ipairs(workspace:GetChildren()) do
            if m:IsA("Model") then
                local f = m:FindFirstChild("VotePads")
                if f then
                    if m:FindFirstChild("VotePad1") then return m, f end
                    if f:FindFirstChild("VotePad1") then return f, f end
                end
            end
        end
    end
    local function readPad(i)
        local parent, det = votePads()
        if not parent then return nil end
        local pad = parent:FindFirstChild("VotePad" .. i)
        local d = (det and det:FindFirstChild("Detector" .. i)) or (pad and pad:FindFirstChild("Pad"))
        if not (pad and d) then return nil end
        local res = { detector = d, name = "", votes = 0, active = false }
        pcall(function()
            local c = pad.VoteInfoGui.Container
            res.name = c.MapName.Text
            res.votes = tonumber(c.Votes.Text:match("%d+")) or 0
        end)
        pcall(function() res.active = pad.MapInfoGui.MapIcon.Image ~= "" end)
        return res
    end
    local function waitNewCharacter(old, timeout)
        local t0 = os.clock()
        while os.clock() - t0 < timeout and not VT.stop do
            local c = lp.Character
            if c and c ~= old and humOf(lp) and hrpOf(lp) and humOf(lp).Health > 0 then return c end
            RunService.Heartbeat:Wait()
        end
    end
    local function runVotes(index, count)
        VT.busy, VT.stop, VT.done, VT.want, VT.status = true, false, 0, count, "Voting"
        local ok, err = pcall(function()
            local failures = 0
            while VT.done < count and not VT.stop do
                local pad = readPad(index)
                if not (pad and pad.active) then VT.status = "Voting ended" return end
                local before, t0, counted = pad.votes, os.clock(), false
                while os.clock() - t0 < 1.2 and not VT.stop do
                    local cur = readPad(index)
                    if not (cur and cur.active) then break end
                    if cur.votes > before and os.clock() - t0 >= 0.18 then counted = true break end
                    local r = hrpOf(lp)
                    if r then
                        local d = r.Position - cur.detector.Position
                        if Vector3.new(d.X, 0, d.Z).Magnitude > 1.5 or math.abs(d.Y) > 3.5 then
                            r.CFrame = CFrame.new(cur.detector.Position - Vector3.new(0, 1.2, 0)) * (r.CFrame - r.CFrame.Position)
                            r.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
                if counted then VT.done += 1 failures = 0 else failures += 1 if failures >= 2 then VT.status = "Vote not counted" return end end
                if VT.done >= count or VT.stop then break end
                VT.status = "Respawning"
                local old = lp.Character
                local h = humOf(lp)
                if h then h.Health = 0 end
                if not waitNewCharacter(old, 15) then VT.status = VT.stop and "Stopped" or "No character" return end
            end
            VT.status = VT.stop and "Stopped" or "Done"
        end)
        if not ok then VT.status = "Error" end
        VT.busy = false
    end
    local vt = R:CreateSection({ Name = "Map Votes", Icon = "vote", Collapsible = true })
    local padDd
    padDd = vt:AddDropdown({ Name = "Pad", Options = { "1", "2", "3" }, Default = "1", Callback = function(v) VT.pad = tonumber((tostring(v or "1"):match("^%d"))) or 1 end })
    vt:AddButton({ Name = "Show Map Names", Callback = function()
        local names = {}
        for i = 1, 3 do
            local p = readPad(i)
            names[#names + 1] = i .. (p and p.name ~= "" and (" - " .. p.name) or "")
        end
        pcall(padDd.Refresh, names, true)
    end })
    vt:AddSlider({ Name = "Votes To Add", Min = 1, Max = 100, Default = VT.count, Callback = function(v) VT.count = math.floor(v) end })
    vt:AddButton({ Name = "Dupe Votes", Primary = true, Callback = function()
        if VT.busy then return end
        local p = readPad(VT.pad)
        if not (p and p.active) then VT.status = "Waiting for vote" return notify("Map Votes", "Voting is not open right now", "warning") end
        task.spawn(runVotes, VT.pad, VT.count)
    end })
    vt:AddButton({ Name = "Stop", Callback = function() VT.stop = true end })
    vt:AddStat({ Name = "Status", Interval = 0.3, Get = function()
        return VT.busy and (VT.status .. "  " .. VT.done .. "/" .. VT.want) or VT.status
    end })
    onCleanup(function() VT.stop = true end)
    end

    do
    -- Auto Prestige ----------------------------------------------------
    local PR = { on = false, last = 0, level = "-", pres = "-" }
    local acct = R:CreateSection({ Name = "Account", Icon = "crown", Collapsible = true })
    acct:AddToggle({ Name = "Auto Prestige", Description = "Prestiges as soon as level 100 is reached", Callback = function(v) PR.on = v end })
    acct:AddStat({ Name = "Level / Prestige", Interval = 2, Get = function() return tostring(PR.level) .. " / " .. tostring(PR.pres) end })
    task.spawn(function()
        while alive do
            task.wait(2)
            pcall(function()
                local mods = RS:FindFirstChild("Modules")
                local lmObj, pdObj = mods and mods:FindFirstChild("LevelModule"), mods and mods:FindFirstChild("ProfileData")
                if not (lmObj and pdObj) then return end
                local lm, pd = require(lmObj), require(pdObj)
                local level = tonumber(lm.GetLevel(pd.NewXP))
                local pres = tonumber(pd.Prestige) or 0
                PR.level, PR.pres = level or "-", pres
                if PR.on and level and level >= 100 and pres < 10 and os.clock() - PR.last > 15 then
                    local inv = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Inventory")
                    local rem = inv and inv:FindFirstChild("Prestige")
                    if rem and rem:IsA("RemoteEvent") then
                        PR.last = os.clock()
                        rem:FireServer()
                        notify("Prestige", "Prestige requested", "success", 4)
                    end
                end
            end)
        end
    end)
    end

    do
    -- hide accessories / headless (client only) ------------------------
    local hidden = setmetatable({}, { __mode = "k" })
    task.spawn(function()
        while alive do
            local c = lp.Character
            if c then
                for _, d in ipairs(c:GetDescendants()) do
                    local hide
                    if d:IsA("Accessory") and F.hideHats then
                        local h = d:FindFirstChild("Handle")
                        if h then h.LocalTransparencyModifier = 1 hidden[h] = true end
                    elseif d.Name == "Head" and d:IsA("BasePart") and F.headless then
                        d.LocalTransparencyModifier = 1 hidden[d] = true
                        for _, f in ipairs(d:GetChildren()) do if f:IsA("Decal") then f.Transparency = 1 end end
                    end
                end
                if not F.hideHats or not F.headless then
                    for p in pairs(hidden) do
                        if p.Parent and ((p.Name == "Handle" and not F.hideHats) or (p.Name == "Head" and not F.headless)) then
                            p.LocalTransparencyModifier = 0
                            if p.Name == "Head" then for _, f in ipairs(p:GetChildren()) do if f:IsA("Decal") then f.Transparency = 0 end end end
                            hidden[p] = nil
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
    onCleanup(function() F.sndPlay = nil F.hideHats, F.headless = false, false end)
    end
end
-- MISC --------------------------------------------------------------
do
    local L = MiscSub.left
    local m = L:CreateSection({ Name = "Utility", Icon = "wrench", Collapsible = true })
    m:AddButton({ Name = "Rejoin", Callback = function() if Library.Rejoin then Library:Rejoin() else TeleportService:Teleport(game.PlaceId, lp) end end })
    m:AddButton({ Name = "Server Hop", Callback = function() if Library.ServerHop then Library:ServerHop() end end })
    m:AddButton({ Name = "Reset Character", Callback = function() local h = humOf(lp) if h then h.Health = 0 end end })
    m:AddLabel("Anti-AFK is always on.")

    -- spin: turns your character around its vertical axis
    local SPIN = { on = false, speed = 720 }
    local sp = MiscSub.right:CreateSection({ Name = "Spin", Icon = "refresh-cw", Collapsible = true })
    local function spinRestore()
        local h = humOf(lp)
        if h then h.AutoRotate = true end
    end
    sp:AddToggle({ Name = "Spin", Icon = "refresh-cw", Description = "Rotates your character", Callback = function(v)
        SPIN.on = v
        if not v then spinRestore() end
    end })
    sp:AddSlider({ Name = "Speed", Min = 30, Max = 3600, Default = SPIN.speed, Suffix = " °/s", Callback = function(v) SPIN.speed = v end })
    track(RunService.Heartbeat:Connect(function(dt)
        if not SPIN.on then return end
        local r, h = hrpOf(lp), humOf(lp)
        if not (r and h) or h.Health <= 0 then return end
        h.AutoRotate = false
        r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(SPIN.speed) * dt, 0)
    end))
    onCleanup(function() SPIN.on = false spinRestore() end)

    -- fling: Touch Fling spikes your own velocity so that whoever you touch is thrown; Anti-Fling makes other players' bodies harmless
    local FL = { touch = false, anti = false }
    local fl = L:CreateSection({ Name = "Fling", Icon = "wind", Collapsible = true })
    fl:AddToggle({ Name = "Touch Fling", Icon = "zap", Description = "Throws players you touch", Callback = function(v) FL.touch = v end })
    fl:AddToggle({ Name = "Anti-Fling", Icon = "shield", Description = "Other players can't push or throw you", Callback = function(v) FL.anti = v end })
    task.spawn(function()
        while alive do
            if FL.touch then
                local r = hrpOf(lp)
                if r and r.Parent then
                    local keepVel = r.AssemblyLinearVelocity
                    r.AssemblyLinearVelocity = Vector3.new(10000, 10000, 10000)
                    r.AssemblyAngularVelocity = Vector3.new(0, 10000, 0)
                    RunService.RenderStepped:Wait()
                    if r.Parent then
                        r.AssemblyLinearVelocity = keepVel
                        r.AssemblyAngularVelocity = Vector3.zero
                    end
                end
                RunService.Heartbeat:Wait()
            else
                task.wait(0.2)
            end
        end
    end)
    track(RunService.Stepped:Connect(function()
        if not FL.anti then return end
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p ~= lp and p.Character
            if c then
                for _, part in ipairs(c:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
        end
    end))
    onCleanup(function() FL.touch, FL.anti = false, false end)

    -- Fling Stick: a hand on a stick. The swing that touches a player throws them (your body does the throwing, as in Touch Fling)
    local FS = { on = false, power = 100000, tool = nil, swinging = 0, busy = false, flinging = false }
    local function flingPlayer(p)
        if FS.flinging then return end
        local r, vr = hrpOf(lp), hrpOf(p)
        if not (r and vr) then return end
        FS.flinging = true
        task.spawn(function()
            local home = r.CFrame
            local dir = (vr.Position - home.Position)
            dir = dir.Magnitude > 0.1 and dir.Unit or home.LookVector
            local t0 = os.clock()
            while os.clock() - t0 < 0.4 and vr.Parent and r.Parent do
                r.CFrame = vr.CFrame
                r.AssemblyLinearVelocity = dir * FS.power + Vector3.new(0, FS.power * 0.35, 0)
                r.AssemblyAngularVelocity = Vector3.new(0, FS.power, 0)
                RunService.Heartbeat:Wait()
            end
            if r.Parent then
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
                r.CFrame = home
            end
            FS.flinging = false
        end)
    end
    local function makeStick()
        local tool = Instance.new("Tool")
        tool.Name = "Fling Stick"
        tool.ToolTip = "Swing at a player to throw them"
        tool.CanBeDropped = false
        tool.RequiresHandle = true
        tool.GripPos = Vector3.new(0, 0, 1.7)
        local function part(name, size, color, mat, parent)
            local p = Instance.new("Part")
            p.Name, p.Size, p.Color, p.Material = name, size, color, mat
            p.CanCollide, p.Massless, p.TopSurface, p.BottomSurface = false, true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
            p.Parent = parent
            return p
        end
        local handle = part("Handle", Vector3.new(0.35, 0.35, 5), Color3.fromRGB(125, 85, 50), Enum.Material.Wood, tool)
        local skin = Color3.fromRGB(255, 205, 160)
        local function weldAt(p, cf)
            p.CFrame = handle.CFrame * cf
            local w = Instance.new("Weld")
            w.Part0, w.Part1 = handle, p
            w.C0 = cf
            w.Parent = p
        end
        local palm = part("Palm", Vector3.new(1.1, 0.5, 0.9), skin, Enum.Material.SmoothPlastic, tool)
        weldAt(palm, CFrame.new(0, 0, -2.9))
        for i, x in ipairs({ -0.4, -0.13, 0.13, 0.4 }) do
            local f = part("Finger" .. i, Vector3.new(0.22, 0.4, 0.6), skin, Enum.Material.SmoothPlastic, tool)
            weldAt(f, CFrame.new(x, 0, -3.65))
        end
        local thumb = part("Thumb", Vector3.new(0.25, 0.4, 0.55), skin, Enum.Material.SmoothPlastic, tool)
        weldAt(thumb, CFrame.new(0.72, 0, -3.1) * CFrame.Angles(0, math.rad(-35), 0))

        local function onHit(hit)
            if FS.swinging < os.clock() or FS.flinging then return end
            local model = hit:FindFirstAncestorOfClass("Model")
            local p = model and Players:GetPlayerFromCharacter(model)
            if p and p ~= lp then flingPlayer(p) end
        end
        handle.Touched:Connect(onHit)
        palm.Touched:Connect(onHit)
        local baseGrip = tool.Grip
        tool.Activated:Connect(function()
            if FS.busy then return end
            FS.busy = true
            FS.swinging = os.clock() + 0.45
            task.spawn(function()
                local t0 = os.clock()
                local fell = false
                while os.clock() - t0 < 0.4 do
                    local k = (os.clock() - t0) / 0.4
                    tool.Grip = baseGrip * CFrame.Angles(math.rad(-25 * math.sin(k * math.pi)), math.rad(-55 + 110 * k), 0)
                    -- touch events can miss a fast swing: also look for a player right at the tip
                    if not fell and k > 0.25 and not FS.flinging and palm.Parent then
                        for _, p in ipairs(Players:GetPlayers()) do
                            local vr = p ~= lp and hrpOf(p)
                            if vr and (vr.Position - palm.Position).Magnitude < 5 then fell = true flingPlayer(p) break end
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
                tool.Grip = baseGrip
                task.wait(0.25)
                FS.busy = false
            end)
        end)
        return tool
    end
    fl:AddToggle({ Name = "Fling Stick", Icon = "wand", Description = "A hand on a stick appears in your hotbar; swing it at someone", Callback = function(v)
        FS.on = v
        if not v and FS.tool then FS.tool:Destroy() FS.tool = nil end
    end })
    fl:AddSlider({ Name = "Fling Power", Min = 10000, Max = 500000, Default = FS.power, Callback = function(v) FS.power = v end })
    -- role targets, click-to-fling and the two automatic modes all go through the same throw as the stick
    fl:AddButton({ Name = "Fling Sheriff", Callback = function()
        local p = findByRole("Sheriff") or findByRole("Hero")
        if p and p ~= lp then flingPlayer(p) else notify("Fling", "No sheriff to fling", "warning") end
    end })
    fl:AddButton({ Name = "Fling Murderer", Callback = function()
        local p = findByRole("Murderer")
        if p and p ~= lp then flingPlayer(p) else notify("Fling", "No murderer to fling", "warning") end
    end })
    fl:AddToggle({ Name = "Auto Fling Sheriff", Description = "Throws each new sheriff once", Callback = function(v) FS.autoSheriff = v FS.lastSheriff = nil end })
    fl:AddToggle({ Name = "Auto End Round", Description = "While you are dead, keeps throwing the murderer", Callback = function(v) FS.autoEnd = v end })
    fl:AddToggle({ Name = "Click Fling", Description = "Click or tap a player to throw them", Callback = function(v) FS.click = v end })
    task.spawn(function()
        while alive do
            if FS.autoSheriff then
                local p = findByRole("Sheriff") or findByRole("Hero")
                if p and p ~= lp and p ~= FS.lastSheriff and visAlive(lp) then
                    FS.lastSheriff = p
                    flingPlayer(p)
                    task.wait(3)
                end
            end
            if FS.autoEnd and not isAlive(lp) then
                local p = findByRole("Murderer")
                if p and p ~= lp and hrpOf(p) then
                    flingPlayer(p)
                    task.wait(3)
                end
            end
            task.wait(0.4)
        end
    end)
    track(UIS.InputBegan:Connect(function(input, processed)
        if not FS.click or processed then return end
        local ut = input.UserInputType
        if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
        local pos = ut == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or UIS:GetMouseLocation()
        local ray = cam:ViewportPointToRay(pos.X, pos.Y)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = { lp.Character, fxFolder }
        local res = workspace:Raycast(ray.Origin, ray.Direction * 500, rp)
        local model = res and res.Instance:FindFirstAncestorOfClass("Model")
        local p = model and Players:GetPlayerFromCharacter(model)
        if p and p ~= lp then flingPlayer(p) end
    end))
    task.spawn(function()
        while alive do
            if FS.on then
                local bp = lp:FindFirstChild("Backpack")
                local c = lp.Character
                if bp and c and not (FS.tool and FS.tool.Parent and (FS.tool.Parent == bp or FS.tool.Parent == c)) then
                    if FS.tool then pcall(function() FS.tool:Destroy() end) end
                    FS.tool = makeStick()
                    FS.tool.Parent = bp
                end
            end
            task.wait(0.8)
        end
    end)
    onCleanup(function() FS.on = false if FS.tool then pcall(function() FS.tool:Destroy() end) end end)
end

-- preload the default model in the background so "Replace Models" works the moment it is switched on
task.delay(1.5, function()
    if alive and not MR.template then loadModelAsset(MODEL_PRESETS[1][2], true, MODEL_PRESETS[1][3]) end
end)

notify("Moro MM2", "Loaded. RightShift opens the menu.", "success", 4)
