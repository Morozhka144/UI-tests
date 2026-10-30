--[[
    Murder Mystery 2 - MoroElite UI Edition
    ESP / Aimbot / Silent Aim / Auto Shoot / Murderer tools / Movement / Visuals / Skins
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

if _G.__MM2Cleanup then pcall(_G.__MM2Cleanup) end

--=====================================================================--
--                              CORE / HELPERS                         --
--=====================================================================--
local Players = game:GetService("Players")
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
local function dbg(msg) local f = _G.__MM2Dlog if f then f(msg) end end

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
    return (c and c:FindFirstChild(name)) or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild(name))
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
    bhop = false, bhopMode = "Hold Space", bhopMax = 45, bhopStep = 3, hopCur = 16,
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
    Murderer = newProfile({ aimMode = "Anyone", rapid = false, rapidRate = 8, killAura = false, killRange = 14, killDelay = 0.9, killAll = false, throwAura = false, throwRange = 70, throwDelay = 1.2 }),
    Sheriff = newProfile({ aimMode = "Murderer", wallbang = false, wbMode = "Close Range", wbOffset = 4, wbManual = false, rapid = false, rapidRate = 10, autoShoot = false, shootDelay = 1.3, shootRange = 250, shootWall = true, autoGun = false }),
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
    S.autoGun = isS and sh.autoGun
    S.wallbang, S.wbMode, S.wbOffset, S.wbManual = isS and sh.wallbang, sh.wbMode, sh.wbOffset, isS and sh.wbManual
    S.rapidGun, S.rapidGunRate = isS and sh.rapid, sh.rapidRate
    S.rapidKnife, S.rapidKnifeRate = isM and m.rapid, m.rapidRate
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
    if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
        return cam.ViewportSize / 2
    end
    return UIS:GetMouseLocation()
end

local function getTarget(fov, wall, mode)
    local best, bestD, bestPart
    local center = screenCenter()
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
local E, ESP
do
E = {
    on = false, maxDist = 1500, filter = "All players", colorMode = "Role", staticColor = Color3.new(1, 1, 1),
    visCheck = false, fade = true,
    box = "Corners", boxThick = 1.6, boxFill = 88,
    name = true, nameStyle = "Pill", textSize = 13, roleTag = true, dist = true, weapon = true,
    hpBar = true, hpText = false,
    skeleton = false, skelThick = 1.4, headDot = false, look = false,
    tracer = false, tracerFrom = "Bottom", tracerThick = 1.2,
    arrows = false, arrowRadius = 0.38,
    chams = "Off", chamMode = "Role", chamVisible = Color3.fromRGB(255, 70, 90), chamHidden = Color3.fromRGB(110, 60, 255), chamAlpha = 0.45,
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

local espLayer = Instance.new("Frame")
espLayer.Name = "ESPLayer"
espLayer.BackgroundTransparency = 1
espLayer.Size = UDim2.fromScale(1, 1)
espLayer.ZIndex = 1
espLayer.Parent = overlay
onCleanup(function() espLayer:Destroy() end)

local function newFrame(parent, props)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.BackgroundColor3 = Color3.new(1, 1, 1)
    f.Visible = false
    for k, v in pairs(props or {}) do f[k] = v end
    f.Parent = parent
    return f
end
local function newLine(parent) return newFrame(parent, { AnchorPoint = Vector2.new(0.5, 0.5) }) end
local function setLine(f, a, b, thick, col, transp)
    local d = b - a
    f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    f.Size = UDim2.fromOffset(d.Magnitude, thick)
    f.Rotation = math.deg(math.atan2(d.Y, d.X))
    f.BackgroundColor3 = col
    f.BackgroundTransparency = transp or 0
    f.Visible = true
end
local function addStroke(f, thick, col, transp)
    local s = Instance.new("UIStroke")
    s.Thickness = thick
    s.Color = col
    s.Transparency = transp or 0
    s.Parent = f
    return s
end
local function addCorner(f, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r
    c.Parent = f
    return c
end
local function newText(parent, size)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = size or 13
    t.RichText = true
    t.TextColor3 = Color3.new(1, 1, 1)
    t.Visible = false
    t.Parent = parent
    addStroke(t, 1, Color3.new(0, 0, 0), 0.4)
    return t
end
local function hex(c) return string.format("#%02x%02x%02x", c.R * 255, c.G * 255, c.B * 255) end

local BONES_R15 = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local BONES_R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
local CUBE_EDGES = { { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 }, { 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }

local pObjs = {}
local function newPlayerObj()
    local o = {}
    o.root = newFrame(espLayer, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = true })
    o.glow = newFrame(o.root, { BackgroundTransparency = 1 })
    addCorner(o.glow, UDim.new(0, 12))
    o.glowStroke = addStroke(o.glow, 5, Color3.new(1, 1, 1), 0.8)
    o.boxFull = newFrame(o.root, {})
    o.boxCorner = addCorner(o.boxFull, UDim.new(0, 0))
    o.boxStroke = addStroke(o.boxFull, 1.6, Color3.new(1, 1, 1), 0)
    o.fillGrad = Instance.new("UIGradient")
    o.fillGrad.Rotation = 90
    o.fillGrad.Parent = o.boxFull
    o.corners = {}
    for i = 1, 8 do o.corners[i] = newFrame(o.root, {}) end
    o.hpBg = newFrame(o.root, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45 })
    o.hpFill = newFrame(o.hpBg, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Visible = true })
    o.pill = newFrame(o.root, { BackgroundColor3 = Color3.fromRGB(14, 14, 20), BackgroundTransparency = 0.15 })
    addCorner(o.pill, UDim.new(0, 7))
    o.pillStroke = addStroke(o.pill, 1, Color3.new(1, 1, 1), 0.35)
    o.accent = newFrame(o.pill, { Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(0, 3, 1, -8), Visible = true })
    addCorner(o.accent, UDim.new(1, 0))
    o.nameT = newText(o.pill, 13)
    o.nameT.Visible = true
    o.nameT.TextXAlignment = Enum.TextXAlignment.Left
    o.nameT.Position = UDim2.fromOffset(13, 0)
    o.nameT.Size = UDim2.new(1, -16, 1, 0)
    o.plainT = newText(o.root, 13)
    o.plainT.AnchorPoint = Vector2.new(0.5, 1)
    o.plainT.Size = UDim2.fromOffset(240, 18)
    o.infoT = newText(o.root, 12)
    o.infoT.AnchorPoint = Vector2.new(0.5, 0)
    o.infoT.Size = UDim2.fromOffset(240, 16)
    o.bones, o.cube = {}, {}
    o.tracer = newLine(o.root)
    o.lookLine = newLine(o.root)
    o.dot = newFrame(o.root, { AnchorPoint = Vector2.new(0.5, 0.5) })
    addCorner(o.dot, UDim.new(1, 0))
    addStroke(o.dot, 1, Color3.new(0, 0, 0), 0.2)
    o.arrow = newText(espLayer, 20)
    o.arrow.Text = "▲"
    o.arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    o.arrow.Size = UDim2.fromOffset(26, 26)
    return o
end

local function destroyObj(o)
    pcall(function() o.root:Destroy() end)
    pcall(function() o.arrow:Destroy() end)
end

local function hideBoxes(o)
    o.boxFull.Visible, o.glow.Visible = false, false
    for _, f in ipairs(o.corners) do f.Visible = false end
    for _, f in ipairs(o.cube) do f.Visible = false end
end

local function renderPlayer(p, o, t, vs, center)
    o.arrow.Visible = false
    local c = p.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local head = c and c:FindFirstChild("Head")
    local me = hrpOf(lp)
    if not (hum and hrp and head and me and hum.Health > 0) then o.root.Visible = false return end
    local role = getRole(p)
    if not roleVisible(role) then o.root.Visible = false return end
    local dist = (hrp.Position - me.Position).Magnitude
    if dist > E.maxDist then o.root.Visible = false return end

    local col = espColor(p, role, t)
    if E.visCheck then
        if t - (o.visT or 0) > 0.12 then o.vis = visible(head) o.visT = t end
        if not o.vis then col = col:Lerp(Color3.new(0, 0, 0), 0.45) end
    end
    local ta = E.fade and math.clamp(dist / E.maxDist, 0, 1) * 0.55 or 0

    local footOff = (hum.HipHeight > 0 and hum.HipHeight or 2) + hrp.Size.Y / 2
    local topW = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.2, 0)
    local botW = hrp.Position - Vector3.new(0, footOff, 0)
    local tp, bp = cam:WorldToViewportPoint(topW), cam:WorldToViewportPoint(botW)
    local onScreen = tp.Z > 0 and bp.Z > 0 and tp.X > -150 and tp.X < vs.X + 150 and tp.Y > -150 and bp.Y < vs.Y + 150

    if not onScreen then
        o.root.Visible = false
        if E.arrows then
            local sp = cam:WorldToViewportPoint(hrp.Position)
            local dir = Vector2.new(sp.X, sp.Y) - center
            if sp.Z < 0 then dir = -dir end
            if dir.Magnitude < 1 then dir = Vector2.new(0, 1) end
            local u = dir.Unit
            local rad = E.arrowRadius * math.min(vs.X, vs.Y)
            o.arrow.Position = UDim2.fromOffset(center.X + u.X * rad, center.Y + u.Y * rad)
            o.arrow.Rotation = math.deg(math.atan2(u.Y, u.X)) + 90
            o.arrow.TextColor3 = col
            o.arrow.TextSize = 18 + (1 - math.clamp(dist / E.maxDist, 0, 1)) * 10
            o.arrow.Visible = true
        end
        return
    end

    o.root.Visible = true
    local h = math.abs(bp.Y - tp.Y)
    local w = h * 0.5
    local x = (tp.X + bp.X) / 2 - w / 2
    local y = math.min(tp.Y, bp.Y)
    local th = E.boxThick

    hideBoxes(o)
    local style = E.box
    if style == "Full" or style == "Rounded Glow" then
        o.boxFull.Visible = true
        o.boxFull.Position, o.boxFull.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
        o.boxFull.BackgroundColor3 = Color3.new(1, 1, 1)
        o.boxFull.BackgroundTransparency = E.boxFill / 100
        o.fillGrad.Color = ColorSequence.new(col, col:Lerp(Color3.new(0, 0, 0), 0.6))
        o.boxStroke.Thickness, o.boxStroke.Color, o.boxStroke.Transparency = th, col, ta
        o.boxCorner.CornerRadius = UDim.new(0, style == "Rounded Glow" and 10 or 0)
        if style == "Rounded Glow" then
            o.glow.Visible = true
            o.glow.Position, o.glow.Size = UDim2.fromOffset(x - 2, y - 2), UDim2.fromOffset(w + 4, h + 4)
            o.glowStroke.Color, o.glowStroke.Transparency = col, 0.72 + ta * 0.3
        end
    elseif style == "Corners" then
        local L = math.max(math.min(w, h) * 0.3, 6)
        local cs = o.corners
        local tr = ta
        local defs = {
            { x, y, L, th }, { x, y, th, L }, { x + w - L, y, L, th }, { x + w - th, y, th, L },
            { x, y + h - th, L, th }, { x, y + h - L, th, L }, { x + w - L, y + h - th, L, th }, { x + w - th, y + h - L, th, L },
        }
        for i, d in ipairs(defs) do
            local f = cs[i]
            f.Position, f.Size = UDim2.fromOffset(d[1], d[2]), UDim2.fromOffset(d[3], d[4])
            f.BackgroundColor3, f.BackgroundTransparency, f.Visible = col, tr, true
        end
    elseif style == "3D Box" then
        local yaw = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)
        local centerW = (topW + botW) / 2
        local half = Vector3.new(1.5, (topW.Y - botW.Y) / 2, 1.0)
        local cf = CFrame.new(centerW) * CFrame.Angles(0, yaw, 0)
        local pts, ok = {}, true
        local i = 0
        for sx = -1, 1, 2 do
            for sy = -1, 1, 2 do
                for sz = -1, 1, 2 do
                    i += 1
                    local sp = cam:WorldToViewportPoint(cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
                    if sp.Z <= 0 then ok = false end
                    pts[i] = Vector2.new(sp.X, sp.Y)
                end
            end
        end
        if ok then
            for e, ed in ipairs(CUBE_EDGES) do
                local f = o.cube[e]
                if not f then f = newLine(o.root) o.cube[e] = f end
                setLine(f, pts[ed[1]], pts[ed[2]], th, col, ta)
            end
        end
    end

    -- health bar
    if E.hpBar then
        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        o.hpBg.Visible = true
        o.hpBg.Position, o.hpBg.Size = UDim2.fromOffset(x - 6, y), UDim2.fromOffset(3, h)
        o.hpFill.Size = UDim2.fromScale(1, ratio)
        o.hpFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 235, 130), ratio)
    else
        o.hpBg.Visible = false
    end

    -- name
    local label = p.DisplayName
    local tag = (E.roleTag and role ~= "Lobby" and role ~= "Innocent") and string.format('  <font color="%s">%s</font>', hex(col), role) or ""
    o.pill.Visible, o.plainT.Visible = false, false
    if E.name then
        if E.nameStyle == "Pill" then
            o.nameT.TextSize = E.textSize
            o.nameT.Text = label .. tag
            local pw = o.nameT.TextBounds.X + 22
            local ph = E.textSize + 10
            o.pill.Size = UDim2.fromOffset(pw, ph)
            o.pill.Position = UDim2.fromOffset(x + w / 2 - pw / 2, y - ph - 5)
            o.pill.Visible = true
            o.accent.BackgroundColor3 = col
            o.pillStroke.Color = col
        else
            o.plainT.TextSize = E.textSize
            o.plainT.Text = '<font color="' .. hex(col) .. '">' .. label .. "</font>" .. tag
            o.plainT.Position = UDim2.fromOffset(x + w / 2, y - 3)
            o.plainT.Visible = true
        end
    end

    -- info under the box
    local info = {}
    if E.dist then info[#info + 1] = math.floor(dist) .. "m" end
    if E.hpText then info[#info + 1] = math.floor(hum.Health) .. "hp" end
    if E.weapon then
        local tool = c:FindFirstChildOfClass("Tool")
        local wn = tool and tool.Name or (role == "Murderer" and "Knife") or ((role == "Sheriff" or role == "Hero") and "Gun") or ""
        if wn ~= "" then info[#info + 1] = '<font color="' .. hex(col) .. '">' .. wn .. "</font>" end
    end
    if #info > 0 then
        o.infoT.TextSize = math.max(E.textSize - 1, 9)
        o.infoT.Text = table.concat(info, "  ·  ")
        o.infoT.Position = UDim2.fromOffset(x + w / 2, y + h + 3)
        o.infoT.Visible = true
    else
        o.infoT.Visible = false
    end

    -- skeleton
    if E.skeleton then
        local bones = BONES_R15
        if not c:FindFirstChild("UpperTorso") then bones = BONES_R6 end
        for i, b in ipairs(bones) do
            local f = o.bones[i]
            if not f then f = newLine(o.root) o.bones[i] = f end
            local a0, a1 = c:FindFirstChild(b[1]), c:FindFirstChild(b[2])
            if a0 and a1 then
                local s0, s1 = cam:WorldToViewportPoint(a0.Position), cam:WorldToViewportPoint(a1.Position)
                if s0.Z > 0 and s1.Z > 0 then
                    setLine(f, Vector2.new(s0.X, s0.Y), Vector2.new(s1.X, s1.Y), E.skelThick, col, ta)
                else f.Visible = false end
            else f.Visible = false end
        end
    else
        for _, f in ipairs(o.bones) do f.Visible = false end
    end

    -- head dot / look line
    if E.headDot then
        local sp = cam:WorldToViewportPoint(head.Position)
        local d = math.clamp(h * 0.13, 5, 16)
        o.dot.Size = UDim2.fromOffset(d, d)
        o.dot.Position = UDim2.fromOffset(sp.X, sp.Y)
        o.dot.BackgroundColor3 = col
        o.dot.Visible = true
    else o.dot.Visible = false end
    if E.look then
        local a = cam:WorldToViewportPoint(head.Position)
        local b = cam:WorldToViewportPoint(head.Position + head.CFrame.LookVector * 7)
        if a.Z > 0 and b.Z > 0 then setLine(o.lookLine, Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y), 1.6, col, 0.15) else o.lookLine.Visible = false end
    else o.lookLine.Visible = false end

    -- tracer
    if E.tracer then
        local from
        if E.tracerFrom == "Center" then from = center
        elseif E.tracerFrom == "Top" then from = Vector2.new(vs.X / 2, 0)
        elseif E.tracerFrom == "Mouse" then from = UIS:GetMouseLocation()
        else from = Vector2.new(vs.X / 2, vs.Y) end
        setLine(o.tracer, from, Vector2.new(x + w / 2, y + h), E.tracerThick, col, 0.15 + ta * 0.5)
    else o.tracer.Visible = false end
end

-- chams (box adornments: bright where visible, dim through walls) ---------
local CHAM_PARTS = {
    "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
    "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}
local chamObjs = {}
local function clearChams(p)
    local d = chamObjs[p]
    if not d then return end
    for _, l in ipairs(d.layers) do pcall(function() l.a:Destroy() end) end
    if d.hl then pcall(function() d.hl:Destroy() end) end
    chamObjs[p] = nil
end
local function buildChams(p, c, sig)
    local d = { char = c, sig = sig, layers = {} }
    if sig == "hl" then
        local hl = Instance.new("Highlight")
        hl.Adornee = c
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = espFolder
        d.hl = hl
    else
        for _, n in ipairs(CHAM_PARTS) do
            local part = c:FindFirstChild(n)
            if part and part:IsA("BasePart") then
                local kinds = { "hidden", "visible" }
                if sig == "glow" then kinds[3] = "glow" end
                for _, kind in ipairs(kinds) do
                    local a
                    local grow = kind == "glow" and 0.2 or 0.05
                    if n == "Head" then
                        a = Instance.new("SphereHandleAdornment")
                        a.Radius = math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2 + grow / 2
                    else
                        a = Instance.new("BoxHandleAdornment")
                        a.Size = part.Size + Vector3.new(grow, grow, grow)
                    end
                    a.Adornee = part
                    a.AlwaysOnTop = kind ~= "visible"
                    a.ZIndex = kind == "glow" and 1 or (kind == "hidden" and 2 or 3)
                    a.Parent = espFolder
                    d.layers[#d.layers + 1] = { a = a, kind = kind }
                end
            end
        end
    end
    chamObjs[p] = d
end

local function updateChams(t)
    local style = E.chams
    local used = {}
    local me = hrpOf(lp)
    if style ~= "Off" and me then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local c = p.Character
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 and (hrp.Position - me.Position).Magnitude <= E.maxDist then
                    local role = getRole(p)
                    if roleVisible(role) then
                        used[p] = true
                        local sig = style == "Outline Glow" and "hl" or (style == "Glow" and "glow" or "box")
                        local d = chamObjs[p]
                        if d and (d.char ~= c or d.sig ~= sig) then clearChams(p) d = nil end
                        if not d then buildChams(p, c, sig) d = chamObjs[p] end
                        local off = (p.UserId % 100) / 100
                        local visC, hidC
                        if E.chamMode == "Custom" then
                            visC, hidC = E.chamVisible, E.chamHidden
                        else
                            local rc = espColor(p, role, t)
                            visC, hidC = rc, rc:Lerp(Color3.new(0, 0, 0), 0.4)
                        end
                        if style == "Rainbow" then visC, hidC = rainbowAt(t, off), rainbowAt(t, off + 0.5) end
                        local alpha = E.chamAlpha
                        if style == "Pulse" then alpha = math.clamp(E.chamAlpha + math.sin(t * 3 + off * 6) * 0.2, 0, 0.95) end
                        if d.hl then
                            d.hl.FillColor, d.hl.OutlineColor = visC, hidC
                            d.hl.FillTransparency = math.clamp(alpha + 0.3, 0, 1)
                            d.hl.OutlineTransparency = 0
                        else
                            for _, l in ipairs(d.layers) do
                                if l.a.Parent then
                                    if l.kind == "hidden" then
                                        l.a.Color3, l.a.Transparency = hidC, math.clamp(alpha + 0.2, 0, 1)
                                    elseif l.kind == "visible" then
                                        l.a.Color3, l.a.Transparency = visC, alpha
                                    else
                                        l.a.Color3, l.a.Transparency = visC, math.clamp(alpha + 0.42, 0, 1)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for p in pairs(chamObjs) do
        if not used[p] then clearChams(p) end
    end
end
onCleanup(function() for p in pairs(chamObjs) do clearChams(p) end end)

ESP = {}
function ESP.render(t)
    local vs = cam.ViewportSize
    local center = vs / 2
    local want = {}
    if E.on then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local o = pObjs[p]
                if not o then o = newPlayerObj() pObjs[p] = o end
                want[p] = true
                pcall(renderPlayer, p, o, t, vs, center)
            end
        end
    end
    for p, o in pairs(pObjs) do
        if not want[p] then
            o.root.Visible, o.arrow.Visible = false, false
            if not p.Parent then destroyObj(o) pObjs[p] = nil end
        end
    end
    updateChams(t)
end
onCleanup(function() for p, o in pairs(pObjs) do destroyObj(o) end pObjs = {} end)

-- world ESP: outlined items with labels --------------------------------------
local world = {}
local function worldMake(inst, label)
    local d = { inst = inst, label = label }
    local part = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
    -- outline: wireframe cube; fill: translucent box (both work on invisible parts, unlike SelectionBox / Highlight)
    local half = (part and part.Size or Vector3.new(2, 2, 2)) / 2 * 1.2
    d.wf = Instance.new("WireframeHandleAdornment")
    d.wf.Adornee = part or inst
    d.wf.AlwaysOnTop = true
    d.wf.ZIndex = 3
    d.wf.Scale = Vector3.one
    local c = {}
    for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do c[#c + 1] = Vector3.new(half.X * sx, half.Y * sy, half.Z * sz) end end end
    for _, e in ipairs(CUBE_EDGES) do d.wf:AddLine(c[e[1]], c[e[2]]) end
    d.wf.Parent = espFolder
    d.fillAd = Instance.new("BoxHandleAdornment")
    d.fillAd.Adornee = part or inst
    d.fillAd.Size = half * 2
    d.fillAd.AlwaysOnTop = true
    d.fillAd.ZIndex = 1
    d.fillAd.Parent = espFolder
    d.visual = inst:FindFirstChild("CoinVisual") or (inst:IsA("BasePart") and inst.Transparency < 0.95 and inst) or nil
    d.bb = Instance.new("BillboardGui")
    d.bb.AlwaysOnTop = true
    d.bb.Size = UDim2.fromOffset(130, 24)
    d.bb.StudsOffset = Vector3.new(0, 2.4, 0)
    d.bb.Adornee = inst
    d.bb.Parent = espFolder
    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromScale(1, 1)
    pill.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    pill.BackgroundTransparency = 0.15
    pill.BorderSizePixel = 0
    pill.Parent = d.bb
    addCorner(pill, UDim.new(1, 0))
    d.stroke = addStroke(pill, 1.2, Color3.new(1, 1, 1), 0.2)
    d.tl = Instance.new("TextLabel")
    d.tl.BackgroundTransparency = 1
    d.tl.Size = UDim2.fromScale(1, 1)
    d.tl.Font = Enum.Font.GothamBold
    d.tl.TextSize = 12
    d.tl.RichText = true
    d.tl.TextColor3 = Color3.new(1, 1, 1)
    d.tl.Parent = pill
    return d
end
local function worldRemove(inst)
    local d = world[inst]
    if d then
        pcall(function() d.wf:Destroy() d.fillAd:Destroy() d.bb:Destroy() if d.hl then d.hl:Destroy() end end)
        world[inst] = nil
    end
end
local function worldStyle(d, col, dist, maxD, glow)
    local within = dist <= maxD
    d.wf.Color3 = col
    d.wf.Transparency = E.outline and 0 or 1
    d.wf.Visible = within
    d.fillAd.Color3 = col
    d.fillAd.Transparency = E.fill and 0.8 or 1
    d.fillAd.Visible = within
    d.bb.Enabled = within and E.tag
    d.stroke.Color = col
    d.tl.Text = string.format('<font color="%s">%s</font>  %dm', hex(col), d.label, dist)
    -- real glowing outline for the nearest few (Roblox allows ~31 Highlights at a time)
    if glow and within and E.outline and d.visual then
        if not d.hl then
            d.hl = Instance.new("Highlight")
            d.hl.Adornee = d.visual
            d.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            d.hl.FillTransparency = 0.55
            d.hl.Parent = espFolder
        end
        d.hl.FillColor, d.hl.OutlineColor = col, Color3.new(1, 1, 1)
    elseif d.hl then
        d.hl:Destroy()
        d.hl = nil
    end
end
onCleanup(function() for i in pairs(world) do worldRemove(i) end end)

local lastDropSeen = false
task.spawn(function()
    while alive do
        local me = hrpOf(lp)
        local t = os.clock()
        local keep = {}
        local drop = gunDrop()
        if drop and not lastDropSeen and S.roleNotify then notify("Gun dropped", "The sheriff is dead - grab the gun", "warning", 4) end
        lastDropSeen = drop ~= nil

        if E.gun and drop then
            keep[drop] = true
            local d = world[drop] or worldMake(drop, "GUN")
            world[drop] = d
            local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true)
            local dist = (me and part) and (part.Position - me.Position).Magnitude or 0
            worldStyle(d, E.gunCol:Lerp(Color3.new(1, 1, 1), (math.sin(t * 4) + 1) * 0.15), dist, 5000, true)
        end

        if E.coins and me then
            local map = mapModel()
            local cc = map and map:FindFirstChild("CoinContainer")
            if cc then
                local list = {}
                for _, coin in ipairs(cc:GetChildren()) do
                    if coin:IsA("BasePart") then
                        keep[coin] = true
                        list[#list + 1] = { coin = coin, dist = (coin.Position - me.Position).Magnitude }
                    end
                end
                table.sort(list, function(a, b) return a.dist < b.dist end)
                for rank, it in ipairs(list) do
                    local coin = it.coin
                    local id = tostring(coin:GetAttribute("CoinID") or "Coin")
                    local d = world[coin] or worldMake(coin, id)
                    world[coin] = d
                    local col = id == "Candy" and E.coinCol or Color3.fromRGB(255, 205, 70)
                    worldStyle(d, col, it.dist, E.coinMax, rank <= 12)
                end
            end
        end
        for inst in pairs(world) do
            if not keep[inst] or not inst.Parent then worldRemove(inst) end
        end
        task.wait(0.2)
    end
end)

end -- ESP engine

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

    pcall(ESP.render, os.clock())

    -- aimbot
    if S.aimbot then
        local pressed = S.aimKey == "Always" or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
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

-- shots you fire by hand: the game's own Shoot call is rewritten while "Manual Shots" is on
_G.__MM2ShootHook = function(remote, origin, target)
    if not (S.wallbang and S.wbManual) then return nil end
    local p, part = getTarget(math.max(S.silentFov, 300), false, S.aimMode)
    if not (p and part) then return nil end
    local pos = predicted(part)
    dbg("Manual shot rewritten -> " .. p.Name)
    return spoofOrigin(pos), CFrame.new(pos)
end
onCleanup(function() _G.__MM2ShootHook = nil end)
if hookmetamethod and getnamecallmethod and newcclosure and checkcaller and not _G.__MM2NamecallHooked then
    _G.__MM2NamecallHooked = true
    local oldNc
    oldNc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if getnamecallmethod() == "FireServer" and typeof(self) == "Instance" and self.Name == "Shoot" and not checkcaller() then
            local fn = _G.__MM2ShootHook
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

-- rapid fire: hold the left mouse button and the gun keeps firing at the chosen rate
task.spawn(function()
    while alive do
        if S.rapidGun and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not UIS:GetFocusedTextBox() then
            pcall(function()
                local c = lp.Character
                local gun = c and c:FindFirstChild("Gun")
                local r = hrpOf(lp)
                if not (gun and r and gun:FindFirstChild("Shoot") and visAlive(lp)) then return end
                local att = r:FindFirstChild("GunRaycastAttachment")
                local origin = att and att.WorldCFrame or r.CFrame
                local tcf = WeaponService and WeaponService:GetMouseTargetCFrame() or CFrame.new(cam.CFrame.Position + cam.CFrame.LookVector * 100)
                if S.wallbang then
                    local p, part = getTarget(math.max(S.silentFov, 300), false, S.aimMode)
                    if p and part then
                        local pos = predicted(part)
                        origin, tcf = spoofOrigin(pos), CFrame.new(pos)
                    end
                end
                gun.Shoot:FireServer(origin, tcf)
                if _G.__MM2OnShot then pcall(_G.__MM2OnShot, origin.Position, tcf.Position) end
            end)
            task.wait(1 / math.max(S.rapidGunRate or 10, 1))
        else
            task.wait(0.03)
        end
    end
end)

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

-- rapid stab: hold the left mouse button with the knife out
task.spawn(function()
    while alive do
        if S.rapidKnife and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not UIS:GetFocusedTextBox() then
            pcall(function()
                local c = lp.Character
                local knife = c and c:FindFirstChild("Knife")
                local r = hrpOf(lp)
                if not (knife and r and visAlive(lp)) then return end
                local best, bd
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= lp and isAlive(p) then
                        local t = hrpOf(p)
                        local d = t and (t.Position - r.Position).Magnitude
                        if d and d <= math.max(S.killRange, 12) and (not bd or d < bd) then best, bd = p, d end
                    end
                end
                if best then
                    stab(best)
                else
                    local ev = knife:FindFirstChild("Events")
                    if ev then ev.KnifeStabbed:FireServer() end
                end
            end)
            task.wait(1 / math.max(S.rapidKnifeRate or 8, 1))
        else
            task.wait(0.03)
        end
    end
end)

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
                if did then task.wait(S.killDelay) end
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
                local p, part = nearestTarget(S.throwRange, true, "Anyone")
                if knife and p and part then
                    equip(knife)
                    task.wait(0.05)
                    local handle = knife:FindFirstChild("Handle")
                    if handle then
                        knife.Events.KnifeThrown:FireServer(handle.CFrame, CFrame.new(predicted(part)))
                    end
                    task.wait(S.throwDelay)
                end
            end)
        end
        task.wait(0.1)
    end
end)

-- grab dropped gun
task.spawn(function()
    while alive do
        if S.autoGun and getRole(lp) ~= "Murderer" and isAlive(lp) and not findTool(lp, "Gun") then
            pcall(function()
                local drop = gunDrop()
                local r = hrpOf(lp)
                if drop and r then
                    local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        if firetouchinterest then
                            pcall(firetouchinterest, r, part, 0)
                            pcall(firetouchinterest, r, part, 1)
                            task.wait(0.3)
                        end
                        if not findTool(lp, "Gun") and part.Parent then
                            local home = r.CFrame
                            tpTo(part.CFrame)
                            task.wait(0.35)
                            tpTo(home)
                        end
                    end
                end
            end)
        end
        task.wait(0.4)
    end
end)

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
    if S.bhop then
        local moving = h.MoveDirection.Magnitude > 0.1
        local want = S.bhopMode == "Always" or UIS:IsKeyDown(Enum.KeyCode.Space)
        if want and moving then
            if h.FloorMaterial ~= Enum.Material.Air then
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

local xrayParts = {}
local function setXray(on)
    if on then
        local map = mapModel()
        local base = map and map:FindFirstChild("Base")
        if base then
            for _, d in ipairs(base:GetDescendants()) do
                if d:IsA("BasePart") and d.Transparency < 0.5 and not xrayParts[d] then
                    xrayParts[d] = true
                    d.LocalTransparencyModifier = 0.65
                end
            end
        end
    else
        for d in pairs(xrayParts) do
            if d.Parent then d.LocalTransparencyModifier = 0 end
        end
        xrayParts = {}
    end
end
task.spawn(function()
    while alive do
        if S.xray then setXray(true) end
        task.wait(3)
    end
end)
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
local GRIP = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local SKIN_TARGET = { Knife = 3.6, Gun = 2.2 }

local function addSkin(slot, label, skin)
    local base, i = label, 1
    while SK.list[slot][label] do i += 1 label = base .. " #" .. i end
    skin.label = label
    SK.list[slot][label] = skin
    table.insert(SK.names[slot], label)
    return label
end

local function collectDisplaySkins()
    local seen, count = {}, { Knife = 0, Gun = 0 }
    for _, d in ipairs(workspace.WeaponDisplays:GetChildren()) do
        local mesh = d:FindFirstChildOfClass("SpecialMesh")
        local slot = d.Name:find("Knife") and "Knife" or "Gun"
        if mesh and mesh.MeshId ~= "" then
            local key = slot .. mesh.MeshId .. mesh.TextureId
            if not seen[key] then
                seen[key] = true
                count[slot] += 1
                local id = mesh.MeshId:match("%d+") or "?"
                addSkin(slot, slot .. " " .. count[slot] .. " (" .. id:sub(-4) .. ")", {
                    meshId = mesh.MeshId, texId = mesh.TextureId, scale = mesh.Scale, offset = mesh.Offset,
                    color = d.Color, material = d.Material,
                })
            end
        end
    end
end
pcall(collectDisplaySkins)

local function fakeFor(slot)
    local c = lp.Character
    local hand = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
    if not hand then return nil end
    local f = SK.fakes[slot]
    if f and f.part.Parent and f.weld.Part0 == hand then return f end
    if f then pcall(function() f.part:Destroy() end) end
    local part = Instance.new("Part")
    part.Name = "MM2Skin" .. slot
    part.Size = Vector3.new(0.4, 0.4, 0.4)
    part.CanCollide, part.CanQuery, part.CanTouch, part.Massless, part.Anchored = false, false, false, true, false
    part.CastShadow = false
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.Parent = part
    local weld = Instance.new("Weld")
    weld.Part0, weld.Part1 = hand, part
    weld.Parent = part
    part.Parent = workspace.Terrain
    f = { part = part, mesh = mesh, weld = weld }
    SK.fakes[slot] = f
    return f
end

local function styleFake(slot, skin)
    local f = fakeFor(slot)
    if not f then return nil end
    local a = SK.adj[slot]
    f.mesh.MeshId = skin.meshId
    f.mesh.TextureId = skin.texId or ""
    f.mesh.Scale = (skin.scale or Vector3.one) * a.size
    f.mesh.Offset = skin.offset or Vector3.zero
    f.part.Color = skin.color or Color3.new(1, 1, 1)
    f.part.Material = skin.material or Enum.Material.Plastic
    f.weld.C0 = GRIP * CFrame.new(a.off) * CFrame.Angles(math.rad(a.rot.X), math.rad(a.rot.Y), math.rad(a.rot.Z)) * (skin.orient or CFrame.identity)
    return f
end

local hiddenReal = setmetatable({}, { __mode = "k" })
local function updateSkins()
    local c = lp.Character
    for _, slot in ipairs({ "Knife", "Gun" }) do
        local skin = SK.pick[slot] and SK.list[slot][SK.pick[slot]]
        local real = findTool(lp, slot)
        local equipped = real and real.Parent == c
        local show = skin and visAlive(lp) and (equipped or (not real and SK.idle == slot))
        local f = SK.fakes[slot]
        local rh = real and real:FindFirstChild("Handle")
        if show then
            f = styleFake(slot, skin)
            if f then f.part.Transparency = 0 end
            if rh then rh.LocalTransparencyModifier = 1 hiddenReal[rh] = true end
        else
            if f and f.part.Parent then f.part.Transparency = 1 end
            if rh and hiddenReal[rh] then rh.LocalTransparencyModifier = 0 hiddenReal[rh] = nil end
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
    for _, f in pairs(SK.fakes) do pcall(function() f.part:Destroy() end) end
    for h in pairs(hiddenReal) do pcall(function() h.LocalTransparencyModifier = 0 end) end
end)

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

local function extractMesh(objs)
    for _, o in ipairs(objs) do
        local list = o:GetDescendants()
        table.insert(list, 1, o)
        for _, d in ipairs(list) do
            if d:IsA("MeshPart") and d.MeshId ~= "" then
                local tex = d.TextureID
                if tex == "" then
                    local sa = d:FindFirstChildOfClass("SurfaceAppearance")
                    if sa then tex = sa.ColorMap end
                end
                return { meshId = d.MeshId, texId = tex, native = d.MeshSize, color = d.Color, material = d.Material }
            elseif d:IsA("SpecialMesh") and d.MeshId ~= "" then
                local part = d.Parent
                return { meshId = d.MeshId, texId = d.TextureId, scale = d.Scale, offset = d.Offset,
                    color = part:IsA("BasePart") and part.Color or nil, material = part:IsA("BasePart") and part.Material or nil }
            end
        end
    end
end

-- takes the first mesh from a catalog model and uses it as a skin
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
        local info = extractMesh(objs)
        for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        if not info then return notify("Skins", "No mesh found in that asset", "error", 4) end
        local skin = { meshId = info.meshId, texId = info.texId or "", scale = info.scale, offset = info.offset, color = info.color, material = info.material }
        if info.native then
            local m = math.max(info.native.X, info.native.Y, info.native.Z, 0.01)
            skin.scale = Vector3.one * (SKIN_TARGET[slot] / m)
            -- point the mesh's longest axis along the hand (the blade / barrel goes forward)
            local n = info.native
            if n.X >= n.Y and n.X >= n.Z then skin.orient = CFrame.Angles(0, math.rad(90), 0)
            elseif n.Y >= n.X and n.Y >= n.Z then skin.orient = CFrame.Angles(math.rad(90), 0, 0) end
        end
        local label = addSkin(slot, tostring(name):sub(1, 28), skin)
        refreshSkinLists()
        selectSkin(slot, label)
        notify("Skins", "Using " .. label .. " as your " .. slot:lower() .. " (adjust it under Fit)", "success", 4)
    end)
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
local HttpService = game:GetService("HttpService")

local F = {
    -- bullet tracers
    tracers = false, trStyle = "Beam", trColor = Color3.fromRGB(0, 220, 255), trMode = "Custom", trWidth = 0.3,
    trTime = 0.7, trImpact = true, trOthers = true, trMine = true,
    -- kill effects
    killFx = false, kfStyle = "Soul Ascend", kfColor = Color3.fromRGB(255, 80, 120), kfRole = true,
    kfMode = "All kills", kfText = true, kfShake = true, kfFlash = true,
    -- aura
    aura = false, auStyle = "Orbs", auColor = Color3.fromRGB(170, 90, 255), auRainbow = false, auScale = 1, roleAura = false,
    trail = false, trailColor = Color3.fromRGB(120, 200, 255), trailRainbow = true,
}

local dlogT = {}
_G.__MM2Log = dlogT
local function dlog(msg)
    dlogT[#dlogT + 1] = string.format("[%.1f] %s", os.clock() % 10000, tostring(msg))
    if #dlogT > 300 then table.remove(dlogT, 1) end
end
_G.__MM2Dlog = dlog
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

local function boltBetween(a, b, color, width, segs, jitter, fadeT)
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
            local seg = mk({ Color = color, Size = Vector3.new(width, width, d) })
            seg.CFrame = CFrame.lookAt(p0, p1) * CFrame.new(0, 0, -d / 2)
            tw(seg, fadeT, { Transparency = 1, Size = Vector3.new(0.02, 0.02, d) })
            life(seg, fadeT + 0.1)
        end
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
local TRACER_STYLES = { "Beam", "Laser", "Lightning", "Rainbow Beam", "Dotted", "Spiral", "Comet" }

local function impactAt(pos, color)
    sparkBurst(pos, color, 14, 20, 0.5)
    local p = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, Color = color, Position = pos, Transparency = 0.1 })
    tw(p, 0.3, { Size = Vector3.one * 2.4, Transparency = 1 })
    life(p, 0.4)
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

local function drawTracer(a, b)
    if not fxBudget() then return end
    local dist = (b - a).Magnitude
    if dist < 1 then return end
    local style, w, t = F.trStyle, F.trWidth, F.trTime
    local color = pickTracerColor(a)
    local mid = CFrame.lookAt(a, b)

    if style == "Beam" or style == "Laser" then
        local core = mk({ Color = style == "Laser" and Color3.new(1, 1, 1) or color, Size = Vector3.new(w, w, dist) })
        core.CFrame = mid * CFrame.new(0, 0, -dist / 2)
        tw(core, t, { Transparency = 1, Size = Vector3.new(0.02, 0.02, dist) })
        life(core, t + 0.1)
        if style == "Laser" then
            local halo = mk({ Color = color, Size = Vector3.new(w * 3.2, w * 3.2, dist), Transparency = 0.55 })
            halo.CFrame = mid * CFrame.new(0, 0, -dist / 2)
            tw(halo, t * 1.2, { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) })
            life(halo, t * 1.2 + 0.1)
        end
    elseif style == "Rainbow Beam" then
        local n = math.clamp(math.floor(dist / 3), 6, 40)
        local len = dist / n
        for i = 1, n do
            local seg = mk({ Color = Color3.fromHSV((i / n + os.clock() * 0.2) % 1, 0.85, 1), Size = Vector3.new(w, w, len + 0.05) })
            seg.CFrame = mid * CFrame.new(0, 0, -(i - 0.5) * len)
            tw(seg, t, { Transparency = 1, Size = Vector3.new(0.02, 0.02, len) })
            life(seg, t + 0.1)
        end
    elseif style == "Lightning" then
        local segs = math.clamp(math.floor(dist / 5), 4, 32)
        boltBetween(a, b, color, w * 0.8, segs, 1.1, t)
        boltBetween(a, b, Color3.new(1, 1, 1), w * 0.35, segs, 0.8, t * 0.8)
    elseif style == "Dotted" then
        local n = math.clamp(math.floor(dist / 2), 3, 70)
        for i = 1, n do
            local d = mk({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * w * 1.5, Position = a + (b - a) * (i / n) })
            task.delay(t * 0.35 * (i / n), function()
                if d.Parent then tw(d, t * 0.65, { Transparency = 1, Size = Vector3.zero }) end
            end)
            life(d, t + 0.3)
        end
    elseif style == "Spiral" then
        local n = math.clamp(math.floor(dist * 0.9), 8, 120)
        for i = 1, n do
            local k = i / n
            local ang = i * 0.7
            local pos = (mid * CFrame.new(math.cos(ang) * 0.7, math.sin(ang) * 0.7, -dist * k)).Position
            local d = mk({ Shape = Enum.PartType.Ball, Color = Color3.fromHSV((k + os.clock() * 0.3) % 1, 0.7, 1), Size = Vector3.one * w * 1.1, Position = pos })
            task.delay(t * 0.3 * k, function()
                if d.Parent then tw(d, t * 0.7, { Transparency = 1, Size = Vector3.zero }) end
            end)
            life(d, t + 0.3)
        end
    elseif style == "Comet" then
        local orb = mk({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * w * 3, Position = a })
        local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, w * 1.4, 0) a0.Parent = orb
        local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -w * 1.4, 0) a1.Parent = orb
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Lifetime = 0.5
        tr.LightEmission = 1
        tr.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
        tr.Parent = orb
        local flight = math.clamp(dist / 500, 0.08, 0.35)
        tw(orb, flight, { Position = b }, Enum.EasingStyle.Linear)
        task.delay(flight, function()
            if orb.Parent then tw(orb, 0.4, { Transparency = 1, Size = Vector3.zero }) end
        end)
        life(orb, flight + 0.9)
    end
    if F.trImpact then
        task.delay(style == "Comet" and 0.1 or 0, impactAt, b, color)
    end
end

local hitRay = RaycastParams.new()
hitRay.FilterType = Enum.RaycastFilterType.Exclude
local function hitPoint(origin, target)
    local dir = target - origin
    if dir.Magnitude < 0.1 then return target end
    hitRay.FilterDescendantsInstances = { lp.Character, fxFolder }
    local r = workspace:Raycast(origin, dir.Unit * math.max(dir.Magnitude + 3, 12), hitRay)
    return r and r.Position or target
end

local lastOwnTracer = 0
_G.__MM2OnShot = function(origin, target)
    dlog("OwnShot tracers=" .. tostring(F.tracers) .. " mine=" .. tostring(F.trMine))
    if not (F.tracers and F.trMine) then return end
    lastOwnTracer = os.clock()
    local ok, err = pcall(function() drawTracer(origin, hitPoint(origin, target)) end)
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
            local ok, err = pcall(drawTracer, a, b)
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
                        if r and lastAim.pos and os.clock() - lastAim.t < 0.3 and not S.autoShoot then
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
local KILL_STYLES = { "Soul Ascend", "Black Hole", "Lightning Strike", "Disintegrate", "Pumpkin Burst", "Random" }

local function ghostOf(c, color)
    local ok, g = pcall(function() return c:Clone() end)
    if not ok or not g then return nil end
    local parts = {}
    for _, d in ipairs(g:GetDescendants()) do
        if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Sound") or d:IsA("Motor6D") or d:IsA("Tool") or d:IsA("ForceField")
            or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
            d:Destroy()
        end
    end
    for _, d in ipairs(g:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
            d.Material = Enum.Material.Neon
            d.Color = color
            d.Transparency = d.Name == "HumanoidRootPart" and 1 or 0.2
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
    bb.StudsOffset = Vector3.new(0, 0, 0)
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

local function risingSparks(pos, color, count)
    local p = mk({ Transparency = 1, Position = pos })
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    e.Color = ColorSequence.new(color)
    e.LightEmission = 1
    e.Rate = 0
    e.Lifetime = NumberRange.new(1.2, 2.2)
    e.Speed = NumberRange.new(2, 6)
    e.SpreadAngle = Vector2.new(60, 60)
    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
    e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    e.Acceleration = Vector3.new(0, 8, 0)
    e.Parent = p
    e:Emit(count)
    life(p, 2.4)
end

local function killEffect(victim, mine)
    local c, r = char(victim), hrpOf(victim)
    if not (c and r) or not fxBudget() then return end
    local pos = r.Position
    local col = F.kfRole and (ROLE_COLORS[getRole(victim)] or F.kfColor) or F.kfColor
    local style = F.kfStyle
    if style == "Random" then
        local pool = { "Soul Ascend", "Black Hole", "Lightning Strike", "Disintegrate", "Pumpkin Burst" }
        style = pool[math.random(#pool)]
    end

    if style == "Soul Ascend" then
        -- gentle and ethereal: the body drifts up as a glowing silhouette, wisps spiral around it, no rings
        local g, parts = ghostOf(c, col)
        if g then
            for _, p in ipairs(parts) do
                if p.Name ~= "HumanoidRootPart" then
                    tw(p, 3.0, {
                        CFrame = p.CFrame * CFrame.new(math.random() - 0.5, 12 + math.random() * 4, math.random() - 0.5)
                            * CFrame.Angles(0, math.rad(math.random(-160, 160)), 0),
                        Transparency = 1,
                    }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
                end
            end
            life(g, 3.2)
        end
        local orb = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, Color = Color3.new(1, 1, 1), Position = pos })
        local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 0.6, 0) a0.Parent = orb
        local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -0.6, 0) a1.Parent = orb
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Lifetime = 1
        tr.LightEmission = 1
        tr.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
        tr.Parent = orb
        tw(orb, 3.0, { Position = pos + Vector3.new(0, 28, 0), Size = Vector3.zero }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
        life(orb, 3.2)
        for i = 1, 6 do
            local wisp = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, Color = col:Lerp(Color3.new(1, 1, 1), 0.5), Position = pos })
            life(wisp, 3.1)
            task.spawn(function()
                local t0, phase = os.clock(), i * math.pi / 3
                while wisp.Parent and os.clock() - t0 < 3 do
                    local k = (os.clock() - t0) / 3
                    local ang = phase + k * 9
                    local rad = 1.2 + k * 1.4
                    wisp.Position = pos + Vector3.new(math.cos(ang) * rad, 1 + k * 22, math.sin(ang) * rad)
                    wisp.Transparency = k * 0.9
                    task.wait()
                end
            end)
        end
        risingSparks(pos, col, 26)
    elseif style == "Black Hole" then
        -- implosion: a dark core with an accretion disk sucks the body and debris in, then collapses in a pulse
        local core = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, Color = Color3.fromRGB(8, 0, 14), Material = Enum.Material.SmoothPlastic, Position = pos })
        local disk = mk({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1, 1), Color = col, Transparency = 0.15 })
        disk.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.Angles(0, 0, math.rad(90))
        tw(core, 0.5, { Size = Vector3.one * 3.2 }, Enum.EasingStyle.Back)
        tw(disk, 0.5, { Size = Vector3.new(0.12, 8, 8) })
        for i = 1, 40 do
            local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
            if dir.Magnitude < 0.05 then dir = Vector3.yAxis end
            local s = 0.2 + math.random() * 0.35
            local cube = mk({ Size = Vector3.one * s, Color = i % 2 == 0 and col or Color3.fromRGB(40, 0, 60), Position = pos + dir.Unit * (7 + math.random() * 5) })
            local d = 0.5 + math.random() * 0.5
            task.delay(math.random() * 0.25, function()
                if cube.Parent then tw(cube, d, { Position = pos, Size = Vector3.zero }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
            end)
            life(cube, 1.2)
        end
        local g, parts = ghostOf(c, col)
        if g then
            for _, p in ipairs(parts) do
                tw(p, 0.8, { CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), Size = p.Size * 0.15, Transparency = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            life(g, 0.9)
        end
        task.delay(0.95, function()
            if core.Parent then tw(core, 0.15, { Size = Vector3.zero }) end
            if disk.Parent then tw(disk, 0.15, { Transparency = 1 }) end
            local pulse = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = Color3.new(1, 1, 1), Position = pos, Transparency = 0.2 })
            tw(pulse, 0.4, { Size = Vector3.one * 16, Transparency = 1 }, Enum.EasingStyle.Quart)
            life(pulse, 0.5)
            sparkBurst(pos, col, 30, 30, 0.7)
            if F.kfFlash then screenFlash(col, 0.3) end
        end)
        life(core, 1.4)
        life(disk, 1.4)
    elseif style == "Lightning Strike" then
        -- forked bolt from the sky, scorched floor, the body is burnt to charcoal and crumbles
        local top = pos + Vector3.new(math.random(-8, 8), 130, math.random(-8, 8))
        boltBetween(top, pos, col, 1.0, 22, 5, 0.5)
        boltBetween(top, pos, Color3.new(1, 1, 1), 0.4, 22, 3.5, 0.4)
        for i = 1, 3 do
            local from = top:Lerp(pos, 0.25 + math.random() * 0.55)
            boltBetween(from, from + Vector3.new(math.random(-18, 18), -math.random(12, 30), math.random(-18, 18)), col, 0.35, 8, 2.2, 0.35)
        end
        if F.kfFlash then screenFlash(Color3.new(1, 1, 1), 0.6) end
        local scorch = mk({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 6.5, 6.5), Color = Color3.fromRGB(12, 10, 10), Material = Enum.Material.Slate, Transparency = 0.15 })
        scorch.CFrame = CFrame.new(pos - Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
        tw(scorch, 3, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        life(scorch, 3.2)
        sparkBurst(pos, Color3.new(1, 1, 1), 24, 30, 0.6)
        risingSparks(pos - Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 150, 40), 22)
        local g, parts = ghostOf(c, Color3.fromRGB(25, 22, 22))
        if g then
            for _, p in ipairs(parts) do
                p.Material = Enum.Material.Slate
                p.Transparency = 0
                tw(p, 1.5, { Transparency = 1, Size = p.Size * Vector3.new(1, 0.2, 1), CFrame = p.CFrame - Vector3.new(0, p.Size.Y * 0.4, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            life(g, 1.6)
        end
    elseif style == "Disintegrate" then
        for i = 1, 48 do
            local off = Vector3.new((math.random() - 0.5) * 2.4, (math.random() - 0.5) * 5, (math.random() - 0.5) * 1.6)
            local s = 0.25 + math.random() * 0.45
            local cube = mk({ Size = Vector3.one * s, Color = col:Lerp(Color3.new(1, 1, 1), math.random() * 0.4), Position = pos + off, Transparency = 0.05 })
            cube.CFrame = cube.CFrame * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
            local d = 1.1 + math.random() * 0.9
            task.delay((1 - (off.Y + 2.5) / 5) * 0.45, function()
                if cube.Parent then
                    tw(cube, d, {
                        CFrame = cube.CFrame * CFrame.new((math.random() - 0.5) * 5, 3 + math.random() * 8, (math.random() - 0.5) * 5) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
                        Transparency = 1, Size = Vector3.one * s * 0.15,
                    })
                end
            end)
            life(cube, d + 0.7)
        end
        sparkBurst(pos, col, 20, 10, 0.5)
    elseif style == "Pumpkin Burst" then
        local orange = Color3.fromRGB(255, 120, 20)
        for i = 1, 10 do
            local pk = mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * (0.7 + math.random() * 0.6), Color = i % 3 == 0 and Color3.fromRGB(150, 60, 255) or orange, Position = pos })
            local dir = Vector3.new(math.random() - 0.5 + 0.01, 0, math.random() - 0.5).Unit * (6 + math.random() * 9)
            local peak = pos + dir * 0.5 + Vector3.new(0, 7 + math.random() * 5, 0)
            local land = pos + dir + Vector3.new(0, -2.6, 0)
            tw(pk, 0.45, { Position = peak }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
            task.delay(0.45, function()
                if pk.Parent then tw(pk, 0.55, { Position = land, Transparency = 1, Size = Vector3.zero }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
            end)
            life(pk, 1.3)
        end
        sparkBurst(pos, orange, 30, 18, 0.7)
        sparkBurst(pos, Color3.fromRGB(150, 60, 255), 18, 12, 0.6)
        ring(pos - Vector3.new(0, 2.8, 0), orange, 10, 0.8, 0.15)
        if F.kfText then killText(pos, "BOO!", orange) end
    end

    if F.kfText and style ~= "Pumpkin Burst" then killText(pos, "☠ " .. victim.DisplayName, col) end
    if F.kfShake then
        local d = r and hrpOf(lp) and (r.Position - hrpOf(lp).Position).Magnitude or 0
        shake(mine and 2.2 or math.clamp(1.4 - d / 80, 0.2, 1.4))
    end
    if F.kfFlash and style ~= "Lightning Strike" and mine then screenFlash(col, 0.25) end
end

local diedAt = {}
local function hookDeath(p)
    local function onChar(c)
        local h = c:WaitForChild("Humanoid", 10)
        if not h then return end
        h.Died:Connect(function()
            dlog("Died " .. p.Name .. " killFx=" .. tostring(F.killFx))
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
local AURA_STYLES = { "Orbs", "Rings", "Magic Circle", "Wings & Halo", "Flames", "Sparkles", "Shadow Smoke" }
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

local function buildAura(c, style, color, scale)
    local a = { style = style, scale = scale, objs = {}, color = color }
    local function add(o) a.objs[#a.objs + 1] = o return o end
    a.core = add(mk({ Transparency = 1 }))
    if style == "Orbs" then
        a.orbs = {}
        for i = 1, 6 do
            local o = add(mk({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55 * scale, Color = color, Transparency = 0.05 }))
            local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 0.2 * scale, 0) a0.Parent = o
            local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -0.2 * scale, 0) a1.Parent = o
            local tr = Instance.new("Trail")
            tr.Attachment0, tr.Attachment1 = a0, a1
            tr.Lifetime = 0.5
            tr.LightEmission = 1
            tr.Color = ColorSequence.new(color)
            tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
            tr.Parent = o
            a.orbs[i] = { part = o, trail = tr }
        end
    elseif style == "Rings" then
        a.rings = {}
        for ri = 1, 3 do
            local blocks = {}
            for i = 1, 22 do
                blocks[i] = add(mk({ Size = Vector3.one * 0.26 * scale, Color = color, Transparency = 0.1 }))
            end
            a.rings[ri] = blocks
        end
    elseif style == "Magic Circle" then
        a.outer, a.inner, a.lines = {}, {}, {}
        for i = 1, 30 do a.outer[i] = add(mk({ Size = Vector3.new(0.22, 0.08, 0.22) * scale, Color = color })) end
        for i = 1, 16 do a.inner[i] = add(mk({ Size = Vector3.new(0.2, 0.08, 0.2) * scale, Color = color })) end
        local R = 3.6 * scale
        for tri = 0, 1 do
            for k = 0, 2 do
                local a0 = math.rad(tri * 60 + k * 120)
                local a1 = math.rad(tri * 60 + (k + 1) * 120)
                local p0 = Vector3.new(math.cos(a0) * R, 0, math.sin(a0) * R)
                local p1 = Vector3.new(math.cos(a1) * R, 0, math.sin(a1) * R)
                local len = (p1 - p0).Magnitude
                a.lines[#a.lines + 1] = { part = add(mk({ Size = Vector3.new(0.08, 0.06, len), Color = color, Transparency = 0.2 })), p0 = p0, p1 = p1 }
            end
        end
        a.core.Size = Vector3.new(6 * scale, 0.2, 6 * scale)
        mkEmitter(a.core, { c0 = color, rate = 28, s0 = 2, s1 = 5, size = 0.45, l0 = 0.8, l1 = 1.6, spread = Vector2.new(10, 10), shape = Enum.ParticleEmitterShape.Disc })
    elseif style == "Wings & Halo" then
        a.feathers, a.halo = {}, {}
        for side = -1, 1, 2 do
            for k = 1, 8 do
                local len = (1.0 + k * 0.32) * scale
                a.feathers[#a.feathers + 1] = {
                    part = add(mk({ Size = Vector3.new(len, 0.06, 0.42 * scale), Color = color, Transparency = 0.1 })),
                    side = side, k = k, len = len,
                }
            end
        end
        for i = 1, 18 do a.halo[i] = add(mk({ Size = Vector3.one * 0.18 * scale, Color = color })) end
    elseif style == "Flames" then
        a.core.Size = Vector3.new(3 * scale, 0.5, 3 * scale)
        mkEmitter(a.core, { tex = "rbxasset://textures/particles/fire_main.dds", c0 = Color3.fromRGB(255, 190, 60), c1 = Color3.fromRGB(220, 40, 20), rate = 90, s0 = 3, s1 = 7, size = 2.2 * scale, l0 = 0.5, l1 = 1.1, le = 0.8, shape = Enum.ParticleEmitterShape.Disc })
    elseif style == "Sparkles" then
        a.core.Size = Vector3.new(4 * scale, 6 * scale, 4 * scale)
        a.emit = mkEmitter(a.core, { c0 = color, rate = 60, s0 = 0.5, s1 = 2, size = 0.55 * scale, l0 = 0.8, l1 = 1.8, spread = Vector2.new(180, 180), acc = Vector3.new(0, 1.5, 0), shape = Enum.ParticleEmitterShape.Cylinder })
    elseif style == "Shadow Smoke" then
        a.core.Size = Vector3.new(3 * scale, 0.5, 3 * scale)
        mkEmitter(a.core, { tex = "rbxasset://textures/particles/smoke_main.dds", c0 = Color3.fromRGB(45, 0, 70), c1 = Color3.fromRGB(10, 0, 20), le = 0, t0 = 0.35, rate = 28, s0 = 1.5, s1 = 3.5, size = 3.2 * scale, l0 = 1.2, l1 = 2.2, shape = Enum.ParticleEmitterShape.Disc })
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
        for i, o in ipairs(a.orbs) do
            local ang = t * 2.2 + i * (math.pi * 2 / 6)
            o.part.Position = r.Position + Vector3.new(math.cos(ang) * 3.2 * s, math.sin(t * 1.7 + i) * 1.2, math.sin(ang) * 3.2 * s)
            o.part.Color = col
            o.trail.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
        end
    elseif style == "Rings" then
        local parts, cfs = {}, {}
        for ri, blocks in ipairs(a.rings) do
            local base = CFrame.new(r.Position) * CFrame.Angles(t * (0.6 + ri * 0.35) + ri, t * 0.9 * ri, math.rad(35 * ri))
            local R = (2.6 + ri * 0.55) * s
            for i, b in ipairs(blocks) do
                local ang = i / #blocks * math.pi * 2
                parts[#parts + 1] = b
                cfs[#cfs + 1] = base * CFrame.new(math.cos(ang) * R, 0, math.sin(ang) * R)
                b.Color = col
            end
        end
        workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
    elseif style == "Magic Circle" then
        a.core.CFrame = CFrame.new(feet)
        local parts, cfs = {}, {}
        local base = CFrame.new(feet)
        for i, b in ipairs(a.outer) do
            local ang = i / #a.outer * math.pi * 2 + t * 0.7
            parts[#parts + 1] = b
            cfs[#cfs + 1] = base * CFrame.new(math.cos(ang) * 4.2 * s, 0, math.sin(ang) * 4.2 * s)
            b.Color = col
        end
        for i, b in ipairs(a.inner) do
            local ang = i / #a.inner * math.pi * 2 - t * 1.1
            parts[#parts + 1] = b
            cfs[#cfs + 1] = base * CFrame.new(math.cos(ang) * 2.5 * s, 0, math.sin(ang) * 2.5 * s)
            b.Color = col
        end
        local spin = CFrame.Angles(0, t * 0.5, 0)
        for _, l in ipairs(a.lines) do
            parts[#parts + 1] = l.part
            local p0, p1 = l.p0, l.p1
            cfs[#cfs + 1] = base * spin * CFrame.lookAt((p0 + p1) / 2, p1)
            l.part.Color = col
        end
        workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
    elseif style == "Wings & Halo" then
        local rootCF = r.CFrame * CFrame.new(0, 0.9, 0.5)
        local flap = math.sin(t * 3.2) * 0.28
        local parts, cfs = {}, {}
        for _, f in ipairs(a.feathers) do
            local sd = f.side
            local rcf = rootCF * CFrame.new(sd * 0.4, 0, 0) * CFrame.Angles(0, -sd * (0.35 + flap), 0)
            local ang = 0.9 - (f.k - 1) * 0.17
            parts[#parts + 1] = f.part
            cfs[#cfs + 1] = rcf * CFrame.Angles(0, 0, sd * ang) * CFrame.new(sd * f.len / 2, 0, 0)
            f.part.Color = col
        end
        local head = r.Position + Vector3.new(0, 3.1 + math.sin(t * 2) * 0.08, 0)
        for i, h in ipairs(a.halo) do
            local ang = i / #a.halo * math.pi * 2 + t
            parts[#parts + 1] = h
            cfs[#cfs + 1] = CFrame.new(head + Vector3.new(math.cos(ang) * 0.95 * s, 0, math.sin(ang) * 0.95 * s))
            h.Color = col
        end
        workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
    elseif style == "Sparkles" then
        a.core.CFrame = CFrame.new(r.Position)
        if a.emit then a.emit.Color = ColorSequence.new(col) end
    else -- Flames / Shadow Smoke
        a.core.CFrame = CFrame.new(feet)
    end
end

local trailObj
local function updateTrail()
    local r = hrpOf(lp)
    if F.trail and r then
        if not (trailObj and trailObj.Parent) then
            local a0 = Instance.new("Attachment") a0.Name = "MM2T0" a0.Position = Vector3.new(0, 1.4, 0) a0.Parent = r
            local a1 = Instance.new("Attachment") a1.Name = "MM2T1" a1.Position = Vector3.new(0, -1.9, 0) a1.Parent = r
            trailObj = Instance.new("Trail")
            trailObj.Name = "MM2Trail"
            trailObj.Attachment0, trailObj.Attachment1 = a0, a1
            trailObj.Lifetime = 1.1
            trailObj.LightEmission = 1
            trailObj.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
            trailObj.Parent = r
        end
        if F.trailRainbow then
            local t = os.clock()
            local keys = {}
            for i = 0, 5 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 5, Color3.fromHSV((t * 0.3 + i / 6) % 1, 0.85, 1)) end
            trailObj.Color = ColorSequence.new(keys)
        else
            trailObj.Color = ColorSequence.new(F.trailColor)
        end
    elseif trailObj then
        local r2 = trailObj.Parent
        pcall(function()
            if r2 then
                if r2:FindFirstChild("MM2T0") then r2.MM2T0:Destroy() end
                if r2:FindFirstChild("MM2T1") then r2.MM2T1:Destroy() end
            end
            trailObj:Destroy()
        end)
        trailObj = nil
    end
end
onCleanup(function() F.trail = false pcall(updateTrail) end)

task.spawn(function()
    while alive do
        pcall(function()
            local want = {}
            if F.aura and lp.Character and visAlive(lp) then
                want[lp.Character] = { F.auStyle, F.auColor, F.auRainbow, F.auScale }
            end
            if F.roleAura then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= lp and p.Character and visAlive(p) then
                        local role = getRole(p)
                        if role == "Murderer" or role == "Sheriff" or role == "Hero" then
                            want[p.Character] = { "Sparkles", ROLE_COLORS[role], false, 1 }
                        end
                    end
                end
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

--=== POST PROCESSING ==================================================
local PF = { on = false, fx = {}, backup = nil, ui = {} }
local PF_DEFAULT = {
    b = 0, c = 0, s = 0, tint = Color3.new(1, 1, 1),
    bi = 0, bs = 24, bt = 2, ri = 0, rs = 0.5,
    dof = false, df = 50, dr = 30, dfar = 0, dnear = 0, blur = 0,
    ad = 0.3, ao = 0, ac = Color3.fromRGB(199, 199, 199), adc = Color3.fromRGB(106, 112, 125), ag = 0, ah = 0,
    clock = nil, amb = nil, expo = 0,
}
PF.v = {}
for k, v in pairs(PF_DEFAULT) do PF.v[k] = v end

local PF_PRESETS = {
    ["Cinematic"] = { b = 0.02, c = 0.22, s = 0.08, tint = Color3.fromRGB(255, 243, 228), bi = 0.7, bs = 32, bt = 0.95, ri = 0.12, rs = 0.7, dof = true, df = 38, dr = 14, dfar = 0.12,
        ad = 0.3, ac = Color3.fromRGB(200, 205, 215), adc = Color3.fromRGB(120, 100, 90), ah = 1, clock = 17.2 },
    ["Neon Night"] = { c = 0.35, s = 0.55, tint = Color3.fromRGB(200, 170, 255), bi = 1.6, bs = 42, bt = 0.75, ad = 0.35, ac = Color3.fromRGB(60, 40, 110), adc = Color3.fromRGB(180, 60, 255), ah = 2,
        clock = 0, amb = Color3.fromRGB(70, 50, 120), expo = 0.1 },
    ["Halloween"] = { c = 0.25, s = 0.35, tint = Color3.fromRGB(255, 170, 90), bi = 0.9, bs = 36, bt = 0.85, ad = 0.5, ac = Color3.fromRGB(255, 120, 40), adc = Color3.fromRGB(120, 30, 150), ah = 2.4,
        clock = 0, amb = Color3.fromRGB(90, 40, 20), expo = 0.15 },
    ["Blood Moon"] = { c = 0.3, s = 0.2, tint = Color3.fromRGB(255, 120, 120), bi = 1.0, bs = 40, bt = 0.8, ad = 0.45, ac = Color3.fromRGB(170, 20, 20), adc = Color3.fromRGB(60, 0, 0), ah = 2,
        clock = 0, amb = Color3.fromRGB(80, 15, 15) },
    ["Vaporwave"] = { c = 0.25, s = 0.6, tint = Color3.fromRGB(255, 190, 245), bi = 1.2, bs = 38, bt = 0.8, ad = 0.3, ac = Color3.fromRGB(255, 130, 220), adc = Color3.fromRGB(90, 200, 255), ah = 1.2,
        clock = 18.2, amb = Color3.fromRGB(120, 80, 150) },
    ["Noir"] = { b = -0.03, c = 0.45, s = -1, tint = Color3.fromRGB(235, 235, 235), bi = 0.3, ad = 0.25, ac = Color3.fromRGB(120, 120, 120), adc = Color3.fromRGB(60, 60, 60), ah = 1.5 },
    ["Frozen"] = { b = 0.04, c = 0.15, s = -0.1, tint = Color3.fromRGB(190, 225, 255), bi = 0.8, bs = 34, bt = 0.9, ri = 0.1, ad = 0.38, ac = Color3.fromRGB(215, 235, 255), adc = Color3.fromRGB(170, 205, 235), ah = 1.4,
        clock = 12 },
    ["Matrix"] = { c = 0.3, s = -0.2, tint = Color3.fromRGB(150, 255, 170), bi = 0.9, bs = 30, bt = 0.85, ad = 0.34, ac = Color3.fromRGB(20, 90, 40), adc = Color3.fromRGB(0, 70, 20), ah = 1.8,
        clock = 0, amb = Color3.fromRGB(10, 70, 25) },
    ["Golden Hour"] = { b = 0.02, c = 0.2, s = 0.2, tint = Color3.fromRGB(255, 220, 170), bi = 0.8, bs = 36, bt = 0.9, ri = 0.3, rs = 0.9, ad = 0.32, ac = Color3.fromRGB(255, 200, 150), adc = Color3.fromRGB(255, 140, 80), ah = 1.2,
        clock = 17.6 },
    ["Dreamy"] = { b = 0.05, c = -0.05, s = 0.25, tint = Color3.fromRGB(255, 235, 250), bi = 1.4, bs = 52, bt = 0.7, dof = true, df = 30, dr = 10, dfar = 0.35, dnear = 0.1, ad = 0.3,
        ac = Color3.fromRGB(240, 220, 255), adc = Color3.fromRGB(255, 200, 230), ah = 1 },
    ["Toxic"] = { c = 0.3, s = 0.5, tint = Color3.fromRGB(190, 255, 120), bi = 1.1, bs = 36, bt = 0.8, ad = 0.45, ac = Color3.fromRGB(110, 190, 20), adc = Color3.fromRGB(40, 90, 0), ah = 2.2,
        clock = 0, amb = Color3.fromRGB(40, 90, 15) },
}
local PF_NAMES = { "Cinematic", "Neon Night", "Halloween", "Blood Moon", "Vaporwave", "Noir", "Frozen", "Matrix", "Golden Hour", "Dreamy", "Toxic" }

local function pfEnsure()
    if PF.fx.cc then return end
    local function mkfx(class, name)
        local e = Instance.new(class)
        e.Name = "MM2_" .. name
        e.Parent = Lighting
        return e
    end
    PF.fx.cc = mkfx("ColorCorrectionEffect", "CC")
    PF.fx.bloom = mkfx("BloomEffect", "Bloom")
    PF.fx.rays = mkfx("SunRaysEffect", "Rays")
    PF.fx.dof = mkfx("DepthOfFieldEffect", "DOF")
    PF.fx.blur = mkfx("BlurEffect", "Blur")
    local existing = Lighting:FindFirstChildOfClass("Atmosphere")
    if existing then
        PF.fx.atmo = existing
        PF.atmoBackup = { Density = existing.Density, Offset = existing.Offset, Color = existing.Color, Decay = existing.Decay, Glare = existing.Glare, Haze = existing.Haze }
    else
        PF.fx.atmo = mkfx("Atmosphere", "Atmo")
        PF.atmoOwn = true
    end
    PF.backup = { ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, ExposureCompensation = Lighting.ExposureCompensation }
end

local function pfApply(smooth)
    if not PF.on then return end
    pfEnsure()
    local v, fx = PF.v, PF.fx
    local t = smooth and 1.2 or 0.05
    local function to(inst, props) tw(inst, t, props, Enum.EasingStyle.Sine) end
    to(fx.cc, { Brightness = v.b, Contrast = v.c, Saturation = v.s, TintColor = v.tint })
    to(fx.bloom, { Intensity = v.bi, Size = v.bs, Threshold = v.bt })
    to(fx.rays, { Intensity = v.ri, Spread = v.rs })
    fx.dof.Enabled = v.dof
    to(fx.dof, { FocusDistance = v.df, InFocusRadius = v.dr, FarIntensity = v.dfar, NearIntensity = v.dnear })
    to(fx.blur, { Size = v.blur })
    to(fx.atmo, { Density = v.ad, Offset = v.ao, Color = v.ac, Decay = v.adc, Glare = v.ag, Haze = v.ah })
    if v.clock then Lighting.ClockTime = v.clock end
    if v.amb then
        Lighting.Ambient = v.amb
        Lighting.OutdoorAmbient = v.amb
    end
    Lighting.ExposureCompensation = v.expo
end

local function pfEnable(on)
    PF.on = on
    if on then
        pfEnsure()
        pfApply(true)
    else
        for k, e in pairs(PF.fx) do
            if k == "atmo" and not PF.atmoOwn then
                for prop, val in pairs(PF.atmoBackup or {}) do pcall(function() e[prop] = val end) end
            else
                pcall(function() e:Destroy() end)
            end
        end
        if PF.backup then
            for k, val in pairs(PF.backup) do pcall(function() Lighting[k] = val end) end
        end
        PF.fx, PF.backup, PF.atmoBackup, PF.atmoOwn = {}, nil, nil, nil
    end
end
onCleanup(function() pfEnable(false) setVignette(0) end)

local function pfPreset(name)
    local p = PF_PRESETS[name]
    if not p then return end
    for k, v in pairs(PF_DEFAULT) do PF.v[k] = v end
    for k, v in pairs(p) do PF.v[k] = v end
    PF.v.clock = p.clock
    PF.v.amb = p.amb
    if not PF.on and PF.toggle then PF.toggle.Set(true) else pfApply(true) end
    for key, sl in pairs(PF.ui) do
        local val = PF.v[key]
        if typeof(val) == "number" then pcall(sl.Set, val, true) end
    end
end

--=== WEATHER ==========================================================
local WEATHER_KINDS = { "Off", "Snow", "Rain", "Embers", "Fireflies", "Spooky Wisps", "Autumn Leaves", "Confetti" }
local weather = { part = nil, kind = "Off" }
local function setWeather(kind)
    if weather.part then weather.part:Destroy() weather.part = nil end
    weather.kind = kind
    if kind == "Off" then return end
    local p = mk({ Transparency = 1, Size = Vector3.new(70, 1, 70) })
    local sp = "rbxasset://textures/particles/sparkles_main.dds"
    local sm = "rbxasset://textures/particles/smoke_main.dds"
    if kind == "Snow" then
        mkEmitter(p, { tex = sp, c0 = Color3.new(1, 1, 1), le = 0.3, t0 = 0.05, rate = 380, s0 = 6, s1 = 10, size = 0.55, keep = true, l0 = 3, l1 = 4, spread = Vector2.new(20, 20), dir = Enum.NormalId.Bottom, shape = Enum.ParticleEmitterShape.Box })
        weather.height = 16
    elseif kind == "Rain" then
        local e = mkEmitter(p, { tex = sp, c0 = Color3.fromRGB(170, 200, 255), le = 0.3, t0 = 0.35, rate = 700, s0 = 70, s1 = 90, size = 0.9, keep = true, l0 = 0.5, l1 = 0.6, spread = Vector2.new(2, 2), dir = Enum.NormalId.Bottom, shape = Enum.ParticleEmitterShape.Box })
        e.Orientation = Enum.ParticleOrientation.VelocityParallel
        e.Squash = NumberSequence.new(-3)
        weather.height = 25
    elseif kind == "Embers" then
        mkEmitter(p, { c0 = Color3.fromRGB(255, 190, 70), c1 = Color3.fromRGB(255, 60, 20), rate = 70, s0 = 3, s1 = 8, size = 0.28, l0 = 3, l1 = 5, spread = Vector2.new(35, 35), acc = Vector3.new(0, 2, 0), shape = Enum.ParticleEmitterShape.Box })
        weather.height = -6
    elseif kind == "Fireflies" then
        p.Size = Vector3.new(50, 12, 50)
        local e = mkEmitter(p, { c0 = Color3.fromRGB(220, 255, 120), rate = 28, s0 = 0.4, s1 = 1.4, size = 0.32, l0 = 4, l1 = 6, spread = Vector2.new(180, 180), shape = Enum.ParticleEmitterShape.Box })
        e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.1), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(0.75, 0.1), NumberSequenceKeypoint.new(1, 1) })
        e.Size = NumberSequence.new(0.32)
        weather.height = 3
    elseif kind == "Spooky Wisps" then
        p.Size = Vector3.new(50, 8, 50)
        mkEmitter(p, { c0 = Color3.fromRGB(170, 90, 255), c1 = Color3.fromRGB(255, 130, 30), rate = 40, s0 = 1, s1 = 3, size = 0.8, l0 = 4, l1 = 6, spread = Vector2.new(60, 60), acc = Vector3.new(0, 1.6, 0), shape = Enum.ParticleEmitterShape.Box })
        weather.height = 1
    elseif kind == "Autumn Leaves" then
        mkEmitter(p, { c0 = Color3.fromRGB(255, 150, 40), c1 = Color3.fromRGB(150, 60, 20), le = 0, t0 = 0, rate = 70, s0 = 3, s1 = 5, size = 1.2, keep = true, l0 = 4, l1 = 5, spread = Vector2.new(30, 30), dir = Enum.NormalId.Bottom, shape = Enum.ParticleEmitterShape.Box })
        weather.height = 16
    elseif kind == "Confetti" then
        local e = mkEmitter(p, { c0 = Color3.fromRGB(255, 80, 120), rate = 200, s0 = 5, s1 = 9, size = 0.9, keep = true, l0 = 3, l1 = 4, spread = Vector2.new(25, 25), dir = Enum.NormalId.Bottom, shape = Enum.ParticleEmitterShape.Box })
        e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 110)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)) })
        e.LightEmission = 0.2
        weather.height = 16
    end
    weather.part = p
end
onCleanup(function() setWeather("Off") end)

--=== MODEL REPLACEMENT ================================================
local MR = {
    on = false, scope = "Everyone", template = nil, templateId = nil, height = 5.6, yaw = 0, yoff = 0, gen = 0,
    recs = {}, hidden = {}, loading = false,
}
local MODEL_PRESETS = {
    { "Tung Tung Tung Sahur (ArrogantArgon)", 138151705692565 },
    { "Tung Tung Sahur + Bat (Low-Poly)", 116724607376773 },
    { "Tung Tung Tung Sahur Buffed (Rigged)", 128230179587698 },
    { "tung_tung_tung_sahur (flamainfernal)", 112342985897325 },
    { "Tung Tung Sahur (Leonbatzi)", 91672128957338 },
    { "Tung Tung Sahur (IsuperDuperPro)", 94398976707691 },
    { "BIG Tung Tung Sahur (Meme Army)", 134311787718382 },
}
local MODEL_NAMES = {}
local modelIdByName = {}
for _, m in ipairs(MODEL_PRESETS) do
    MODEL_NAMES[#MODEL_NAMES + 1] = m[1]
    modelIdByName[m[1]] = m[2]
end

local function mrDropAll()
    for c, rec in pairs(MR.recs) do pcall(function() rec.model:Destroy() end) MR.recs[c] = nil end
    for c, list in pairs(MR.hidden) do
        for _, p in ipairs(list) do if p.Parent then p.LocalTransparencyModifier = 0 end end
        MR.hidden[c] = nil
    end
end
onCleanup(function() MR.on = false mrDropAll() end)

local function sanitizeTemplate(objs)
    local m = Instance.new("Model")
    m.Name = "MM2Template"
    for _, o in ipairs(objs) do o.Parent = m end
    local n = 0
    for _, d in ipairs(m:GetDescendants()) do
        n += 1
        if n % 200 == 0 then task.wait() end
        if d:IsA("Tool") then
            for _, ch in ipairs(d:GetChildren()) do
                if ch:IsA("BasePart") or ch:IsA("Model") then ch.Parent = m end
            end
            d:Destroy()
        elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Humanoid") or d:IsA("Animator") or d:IsA("JointInstance") or d:IsA("WeldConstraint")
            or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BodyMover") or d:IsA("ForceField") or d:IsA("Seat") or d:IsA("VehicleSeat") then
            pcall(function() d:Destroy() end)
        end
    end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = true, false, false, false, true
        end
    end
    return m
end

MR.status = "Not loaded"
local function loadModelAsset(id, auto)
    if MR.loading then return notify("Model", "Already loading, wait a moment", "warning") end
    MR.loading = true
    MR.status = "Loading " .. tostring(id) .. "..."
    if not auto then notify("Model", "Loading asset " .. tostring(id) .. "...", "info") end
    task.spawn(function()
        local done, objs, err = false, nil, nil
        task.spawn(function()
            local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
            if ok then objs = res else err = res end
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < 25 do task.wait(0.1) end
        if not objs or #objs == 0 then
            MR.loading = false
            MR.status = "Error: " .. (done and tostring(err or "empty asset") or "timed out")
            return notify("Model", MR.status, "error", 5)
        end
        local ok, tpl = pcall(sanitizeTemplate, objs)
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
        MR.status = "Ready (id " .. tostring(id) .. ", " .. #tpl:GetDescendants() .. " objects)"
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
    return { model = inst, off = off, size = size, phase = math.random() * 6, gen = MR.gen, height = MR.height, hidden = false }
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
        local bob = math.abs(math.sin(t * 9 + rec.phase)) * 0.45 * sp
        local D = CFrame.new(r.Position.X, feetY + rec.size.Y / 2 + bob + MR.yoff, r.Position.Z)
            * CFrame.Angles(0, yaw + math.rad(MR.yaw), 0)
            * CFrame.Angles(math.rad(-10) * sp, 0, math.sin(t * 9 + rec.phase) * math.rad(7) * sp)
        rec.model:PivotTo(D * rec.off:Inverse())
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
    if weather.part then
        weather.part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, weather.height or 30, 0))
    end
end))

_G.__MM2Dbg = { Library = Library, F = F, S = S, P = P, SK = SK, applyAvatar = applyAvatar, loadSkinAsset = loadSkinAsset, addSkin = addSkin, resetAvatar = resetAvatar, PF = PF, MR = MR, killEffect = killEffect, drawTracer = drawTracer, pfPreset = pfPreset, pfEnable = pfEnable,
    setWeather = setWeather, loadModelAsset = loadModelAsset, searchModels = searchModels, setVignette = setVignette }
onCleanup(function() _G.__MM2Dbg = nil end)

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
local MiscTab = Win:CreateTab({ Name = "Misc", Icon = "wrench" })
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
        aim:AddToggle({ Name = "Aimbot (" .. who .. ")", Icon = "crosshair", Description = "Works while you are the " .. who:lower(), Callback = function(v) prof.aimbot = v end })
        aim:AddDropdown({ Name = "Key", Options = { "Hold RMB", "Always" }, Default = "Hold RMB", Callback = function(v) prof.aimKey = v or "Hold RMB" end })
        aim:AddDropdown({ Name = "Target", Options = targets, Default = defaultTarget, Callback = function(v) prof.aimMode = v or defaultTarget end })
        aim:AddDropdown({ Name = "Part", Options = { "Head", "Torso", "Root" }, Default = "Head", Callback = function(v) prof.aimPart = v or "Head" end })
        aim:AddSlider({ Name = "FOV", Min = 30, Max = 600, Default = prof.aimFov, Suffix = " px", Callback = function(v) prof.aimFov = v end })
        aim:AddSlider({ Name = "Smoothness", Min = 0, Max = 95, Default = prof.aimSmooth, Callback = function(v) prof.aimSmooth = v end })
        aim:AddSlider({ Name = "Prediction", Min = 0, Max = 300, Default = prof.predict * 1000, Suffix = " ms", Callback = function(v) prof.predict = v / 1000 end })
        aim:AddToggle({ Name = "Wall Check", Default = true, Callback = function(v) prof.aimWall = v end })
        aim:AddToggle({ Name = "Show FOV Circle", Default = true, Callback = function(v) prof.showFov = v end })

        local sil = R:CreateSection({ Name = "Silent Aim", Icon = "target", Collapsible = true })
        sil:AddToggle({ Name = "Silent Aim (" .. who .. ")", Icon = "target", Description = "Gun shots and knife throws go to the target", Callback = function(v)
            prof.silent = v
            if v and not origGetMouse then notify("Silent Aim", "WeaponService hook failed - it will not work", "error") end
        end })
        sil:AddSlider({ Name = "FOV", Min = 50, Max = 1000, Default = prof.silentFov, Suffix = " px", Callback = function(v) prof.silentFov = v end })
        sil:AddToggle({ Name = "Wall Check", Callback = function(v) prof.silentWall = v end })
        return L, R
    end

    -- MURDERER
    local Mu = combatSub("Murderer", "swords")
    local ML, MR = aimSections(Mu, P.Murderer, "Murderer", { "Anyone", "Sheriff" }, "Anyone")
    local ka = ML:CreateSection({ Name = "Kill Aura", Icon = "swords", Collapsible = true })
    ka:AddToggle({ Name = "Kill Aura", Icon = "swords", Description = "Stabs everyone in range", Callback = function(v) P.Murderer.killAura = v end })
    ka:AddSlider({ Name = "Range", Min = 5, Max = 60, Default = P.Murderer.killRange, Suffix = " st", Callback = function(v) P.Murderer.killRange = v end })
    ka:AddSlider({ Name = "Stab Delay", Min = 0.05, Max = 2, Default = P.Murderer.killDelay, Decimals = 2, Suffix = " s", Callback = function(v) P.Murderer.killDelay = v end })

    local ak = MR:CreateSection({ Name = "Kill All", Icon = "skull", Collapsible = true })
    ak:AddButton({ Name = "Kill All (once)", Primary = true, Callback = function() task.spawn(runKillAll) end })
    ak:AddToggle({ Name = "Kill All Loop", Description = "Repeats while you are the murderer", Callback = function(v) P.Murderer.killAll = v end })

    local th = MR:CreateSection({ Name = "Knife Throw", Icon = "send", Collapsible = true })
    th:AddToggle({ Name = "Throw Aura", Description = "Throws the knife at the nearest visible player", Callback = function(v) P.Murderer.throwAura = v end })
    th:AddSlider({ Name = "Range", Min = 20, Max = 200, Default = P.Murderer.throwRange, Suffix = " st", Callback = function(v) P.Murderer.throwRange = v end })
    th:AddSlider({ Name = "Delay", Min = 0.05, Max = 4, Default = P.Murderer.throwDelay, Decimals = 2, Suffix = " s", Callback = function(v) P.Murderer.throwDelay = v end })

    local rs = MR:CreateSection({ Name = "Rapid Stab", Icon = "zap", Collapsible = true })
    rs:AddToggle({ Name = "Rapid Stab", Icon = "zap", Description = "Hold left mouse button to keep stabbing", Callback = function(v) P.Murderer.rapid = v end })
    rs:AddSlider({ Name = "Rate", Min = 1, Max = 30, Default = P.Murderer.rapidRate, Suffix = " /s", Callback = function(v) P.Murderer.rapidRate = v end })

    -- SHERIFF
    local Sh = combatSub("Sheriff", "shield")
    local SL, SR = aimSections(Sh, P.Sheriff, "Sheriff", { "Murderer", "Anyone" }, "Murderer")
    local au = SL:CreateSection({ Name = "Auto Shoot", Icon = "zap", Collapsible = true })
    au:AddToggle({ Name = "Auto Shoot", Icon = "zap", Description = "Equips the gun and shoots when the target is visible", Callback = function(v) P.Sheriff.autoShoot = v end })
    au:AddSlider({ Name = "Delay", Min = 0.05, Max = 4, Default = P.Sheriff.shootDelay, Decimals = 2, Suffix = " s", Callback = function(v) P.Sheriff.shootDelay = v end })
    au:AddSlider({ Name = "Max Distance", Min = 30, Max = 500, Default = P.Sheriff.shootRange, Suffix = " st", Callback = function(v) P.Sheriff.shootRange = v end })
    au:AddToggle({ Name = "Wall Check", Default = true, Callback = function(v) P.Sheriff.shootWall = v end })

    local wb = SR:CreateSection({ Name = "Wallbang", Icon = "brick-wall", Collapsible = true })
    wb:AddToggle({ Name = "Wallbang", Icon = "brick-wall", Description = "Shots ignore walls: the shot origin is moved next to the target", Callback = function(v) P.Sheriff.wallbang = v end })
    wb:AddDropdown({ Name = "Mode", Options = { "Close Range", "Overhead" }, Default = "Close Range", Callback = function(v) P.Sheriff.wbMode = v or "Close Range" end })
    wb:AddSlider({ Name = "Offset", Min = 1, Max = 15, Default = P.Sheriff.wbOffset, Suffix = " st", Callback = function(v) P.Sheriff.wbOffset = v end })
    wb:AddToggle({ Name = "Manual Shots", Description = "Also rewrites shots you fire yourself (needs a target in FOV)", Callback = function(v) P.Sheriff.wbManual = v end })

    local rf = SR:CreateSection({ Name = "Rapid Fire", Icon = "zap", Collapsible = true })
    rf:AddToggle({ Name = "Rapid Fire", Icon = "zap", Description = "Hold left mouse button to keep shooting", Callback = function(v) P.Sheriff.rapid = v end })
    rf:AddSlider({ Name = "Rate", Min = 1, Max = 30, Default = P.Sheriff.rapidRate, Suffix = " /s", Callback = function(v) P.Sheriff.rapidRate = v end })

    local gn = SR:CreateSection({ Name = "Gun", Icon = "hand", Collapsible = true })
    gn:AddToggle({ Name = "Auto Grab Dropped Gun", Icon = "hand", Callback = function(v) P.Sheriff.autoGun = v end })
    gn:AddButton({ Name = "Grab Gun Now", Callback = function()
        local drop = gunDrop()
        local r = hrpOf(lp)
        local part = drop and (drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true))
        if not (part and r) then return notify("Gun", "No dropped gun", "warning") end
        local home = r.CFrame
        tpTo(part.CFrame)
        task.wait(0.35)
        tpTo(home)
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
        ["Chams Only"] = { ["ESP Master"] = false, ["Chams Style"] = "Glow", ["Chams Opacity"] = 50 },
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
    mt:AddDropdown({ Name = "Preset", Description = "Applies a ready set of ESP settings", Options = presetNames, Callback = function(v) if v then applyEspPreset(v) end end })
    ctl["ESP Filter"] = mt:AddDropdown({ Name = "Filter", Options = { "All players", "Murderer + Sheriff", "Murderer only" }, Default = "All players", Callback = function(v) E.filter = v or "All players" end })
    mt:AddSlider({ Name = "Max Distance", Min = 100, Max = 3000, Default = E.maxDist, Suffix = " st", Callback = function(v) E.maxDist = v end })
    ctl["ESP Color Mode"] = mt:AddDropdown({ Name = "Color Mode", Options = { "Role", "Rainbow", "Static" }, Default = "Role", Callback = function(v) E.colorMode = v or "Role" end })
    mt:AddColorPicker({ Name = "Static Color", Default = E.staticColor, Callback = function(c) E.staticColor = c end })
    ctl["ESP Visible Check"] = mt:AddToggle({ Name = "Visible Check", Description = "Dims players that are behind walls", Callback = function(v) E.visCheck = v end })
    ctl["ESP Distance Fade"] = mt:AddToggle({ Name = "Distance Fade", Default = true, Callback = function(v) E.fade = v end })

    -- boxes / skeleton ---------------------------------------------------
    local bx = L:CreateSection({ Name = "Boxes & Skeleton", Icon = "box-select", Collapsible = true })
    ctl["Box Style"] = bx:AddDropdown({ Name = "Style", Options = { "Off", "Corners", "Full", "Rounded Glow", "3D Box" }, Default = "Corners", Callback = function(v) E.box = v or "Corners" end })
    ctl["Box Thickness"] = bx:AddSlider({ Name = "Thickness", Min = 0.5, Max = 4, Default = E.boxThick, Decimals = 1, Callback = function(v) E.boxThick = v end })
    ctl["Box Fill Transparency"] = bx:AddSlider({ Name = "Fill Transparency", Min = 50, Max = 100, Default = E.boxFill, Suffix = " %", Callback = function(v) E.boxFill = v end })
    ctl["Skeleton"] = bx:AddToggle({ Name = "Skeleton", Icon = "bone", Callback = function(v) E.skeleton = v end })
    bx:AddSlider({ Name = "Bone Thickness", Min = 0.5, Max = 4, Default = E.skelThick, Decimals = 1, Callback = function(v) E.skelThick = v end })
    ctl["Head Dot"] = bx:AddToggle({ Name = "Head Dot", Callback = function(v) E.headDot = v end })
    ctl["Look Line"] = bx:AddToggle({ Name = "Look Line", Description = "Shows where a player is looking", Callback = function(v) E.look = v end })

    -- labels -------------------------------------------------------------
    local lb = L:CreateSection({ Name = "Labels", Icon = "tag", Collapsible = true })
    ctl["Name Tag"] = lb:AddToggle({ Name = "Name", Default = true, Callback = function(v) E.name = v end })
    ctl["Name Style"] = lb:AddDropdown({ Name = "Name Style", Options = { "Pill", "Plain" }, Default = "Pill", Callback = function(v) E.nameStyle = v or "Pill" end })
    ctl["Role Tag"] = lb:AddToggle({ Name = "Role", Default = true, Callback = function(v) E.roleTag = v end })
    ctl["Show Distance"] = lb:AddToggle({ Name = "Distance", Default = true, Callback = function(v) E.dist = v end })
    ctl["Show Weapon"] = lb:AddToggle({ Name = "Weapon", Default = true, Callback = function(v) E.weapon = v end })
    ctl["Health Bar"] = lb:AddToggle({ Name = "Health Bar", Default = true, Callback = function(v) E.hpBar = v end })
    ctl["Health Text"] = lb:AddToggle({ Name = "Health Text", Callback = function(v) E.hpText = v end })
    ctl["Text Size"] = lb:AddSlider({ Name = "Text Size", Min = 9, Max = 22, Default = E.textSize, Callback = function(v) E.textSize = v end })

    -- chams --------------------------------------------------------------
    local ch = R:CreateSection({ Name = "Chams", Icon = "scan", Collapsible = true })
    ctl["Chams Style"] = ch:AddDropdown({ Name = "Style", Options = { "Off", "Flat", "Glow", "Pulse", "Rainbow", "Outline Glow" }, Default = "Off", Callback = function(v) E.chams = v or "Off" end })
    ctl["Chams Colors"] = ch:AddDropdown({ Name = "Colors", Options = { "Role", "Custom" }, Default = "Role", Callback = function(v) E.chamMode = v or "Role" end })
    ch:AddColorPicker({ Name = "Visible Color", Default = E.chamVisible, Callback = function(c) E.chamVisible = c end })
    ch:AddColorPicker({ Name = "Hidden Color", Default = E.chamHidden, Callback = function(c) E.chamHidden = c end })
    ctl["Chams Opacity"] = ch:AddSlider({ Name = "Opacity", Min = 5, Max = 95, Default = 55, Suffix = " %", Callback = function(v) E.chamAlpha = 1 - v / 100 end })
    ch:AddLabel("Bright color = visible, dim color = through walls.")

    -- tracers / arrows ---------------------------------------------------
    local tr = R:CreateSection({ Name = "Tracers & Arrows", Icon = "locate", Collapsible = true })
    ctl["ESP Tracers"] = tr:AddToggle({ Name = "Tracers", Callback = function(v) E.tracer = v end })
    tr:AddDropdown({ Name = "Origin", Options = { "Bottom", "Center", "Top", "Mouse" }, Default = "Bottom", Callback = function(v) E.tracerFrom = v or "Bottom" end })
    tr:AddSlider({ Name = "Thickness", Min = 0.5, Max = 4, Default = E.tracerThick, Decimals = 1, Callback = function(v) E.tracerThick = v end })
    ctl["Off-screen Arrows"] = tr:AddToggle({ Name = "Arrows", Description = "Arrows pointing at players outside your view", Callback = function(v) E.arrows = v end })
    tr:AddSlider({ Name = "Radius", Min = 15, Max = 48, Default = E.arrowRadius * 100, Suffix = " %", Callback = function(v) E.arrowRadius = v / 100 end })

    -- world --------------------------------------------------------------
    local we = R:CreateSection({ Name = "World ESP", Icon = "map-pin", Collapsible = true })
    local gunT = we:AddToggle({ Name = "Gun", Default = true, Callback = function(v) E.gun = v end })
    gunT:AddColorPicker({ Default = E.gunCol, Callback = function(c) E.gunCol = c end })
    local coinT = we:AddToggle({ Name = "Coins / Candies", Callback = function(v) E.coins = v end })
    coinT:AddColorPicker({ Default = E.coinCol, Callback = function(c) E.coinCol = c end })
    we:AddToggle({ Name = "Outline", Default = true, Callback = function(v) E.outline = v end })
    we:AddToggle({ Name = "Fill", Default = true, Callback = function(v) E.fill = v end })
    we:AddToggle({ Name = "Labels", Default = true, Callback = function(v) E.tag = v end })
    we:AddSlider({ Name = "Coin Range", Min = 30, Max = 800, Default = E.coinMax, Suffix = " st", Callback = function(v) E.coinMax = v end })

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
    local L, R = MoveTab:Column("left"), MoveTab:Column("right")
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

    local bh = L:CreateSection({ Name = "Bunny Hop", Icon = "rabbit", Collapsible = true })
    local bhT = bh:AddToggle({ Name = "Bunny Hop", Icon = "rabbit", Description = "Auto-jumps and gains speed with every hop", Callback = function(v)
        S.bhop = v
        if not v then
            S.hopCur = 16
            local h = humOf(lp)
            if h and not S.speed then h.WalkSpeed = 16 end
        end
    end })
    bhT:AddKeybind({ Default = Enum.KeyCode.B, Mode = "Toggle" })
    bh:AddDropdown({ Name = "Mode", Options = { "Hold Space", "Always" }, Default = "Hold Space", Callback = function(v) S.bhopMode = v or "Hold Space" end })
    bh:AddSlider({ Name = "Max Speed", Min = 20, Max = 120, Default = S.bhopMax, Callback = function(v) S.bhopMax = v end })
    bh:AddSlider({ Name = "Speed Gain", Min = 1, Max = 10, Default = S.bhopStep, Decimals = 1, Callback = function(v) S.bhopStep = v end })

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
    w:AddToggle({ Name = "X-Ray", Description = "Makes map walls see-through", Callback = function(v) S.xray = v if not v then setXray(false) end end })

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

    local ws = L:CreateSection({ Name = "Weapon Skins", Icon = "palette", Collapsible = true })
    ws:AddLabel("Shown only on your screen. Pick a skin and it appears in your hand.")
    SK.dd.Knife = ws:AddDropdown({ Name = "Knife", Options = SK.names.Knife, Default = "Default (real)", Callback = function(v)
        SK.pick.Knife = (v and v ~= "Default (real)") and v or nil
    end })
    SK.dd.Gun = ws:AddDropdown({ Name = "Gun", Options = SK.names.Gun, Default = "Default (real)", Callback = function(v)
        SK.pick.Gun = (v and v ~= "Default (real)") and v or nil
    end })
    ws:AddDropdown({ Name = "Show When Empty-Handed", Options = { "Knife", "Gun", "Off" }, Default = "Knife", Description = "What you hold in the lobby / as an innocent", Callback = function(v) SK.idle = v or "Knife" end })
    ws:AddButton({ Name = "Refresh Skins", Callback = function()
        SK.list, SK.names = { Knife = {}, Gun = {} }, { Knife = { "Default (real)" }, Gun = { "Default (real)" } }
        collectDisplaySkins()
        refreshSkinLists()
        notify("Skins", (#SK.names.Knife - 1) .. " knives, " .. (#SK.names.Gun - 1) .. " guns", "info")
    end })

    local fit = L:CreateSection({ Name = "Fit", Icon = "move-3d", Collapsible = true })
    fit:AddLabel("Rotate / resize the skin if it sits wrong in your hand.")
    local slotSel = "Knife"
    local fitSliders = {}
    fit:AddDropdown({ Name = "Adjust", Options = { "Knife", "Gun" }, Default = "Knife", Callback = function(v)
        slotSel = v or "Knife"
        local a = SK.adj[slotSel]
        local vals = { size = a.size, rx = a.rot.X, ry = a.rot.Y, rz = a.rot.Z, ox = a.off.X, oy = a.off.Y, oz = a.off.Z }
        for k, s in pairs(fitSliders) do pcall(s.Set, vals[k], true) end
    end })
    local function fitSlider(key, name, mn, mx, dec, suffix, apply)
        fitSliders[key] = fit:AddSlider({ Name = name, Min = mn, Max = mx, Default = key == "size" and 1 or 0, Decimals = dec, Suffix = suffix, Callback = function(v)
            apply(SK.adj[slotSel], v)
        end })
    end
    fitSlider("size", "Size", 0.2, 3, 2, "x", function(a, v) a.size = v end)
    fitSlider("rx", "Rotate X", -180, 180, 0, "°", function(a, v) a.rot = Vector3.new(v, a.rot.Y, a.rot.Z) end)
    fitSlider("ry", "Rotate Y", -180, 180, 0, "°", function(a, v) a.rot = Vector3.new(a.rot.X, v, a.rot.Z) end)
    fitSlider("rz", "Rotate Z", -180, 180, 0, "°", function(a, v) a.rot = Vector3.new(a.rot.X, a.rot.Y, v) end)
    fitSlider("ox", "Move X", -2, 2, 2, "", function(a, v) a.off = Vector3.new(v, a.off.Y, a.off.Z) end)
    fitSlider("oy", "Move Y", -2, 2, 2, "", function(a, v) a.off = Vector3.new(a.off.X, v, a.off.Z) end)
    fitSlider("oz", "Move Z", -2, 2, 2, "", function(a, v) a.off = Vector3.new(a.off.X, a.off.Y, v) end)

    -- catalog ------------------------------------------------------------
    local cs = R:CreateSection({ Name = "Catalog Skins", Icon = "search", Collapsible = true })
    cs:AddLabel("Searches Roblox for models and uses the first mesh as a skin.")
    local kw, results, chosen = "karambit knife", {}, nil
    cs:AddTextbox({ Name = "Keyword", Default = kw, Placeholder = "knife, sword, pistol...", Callback = function(t) kw = t end })
    local resDd = cs:AddDropdown({ Name = "Results", Options = {}, Callback = function(v) chosen = v end })
    cs:AddButton({ Name = "Search", Primary = true, Callback = function()
        notify("Skins", "Searching...", "info", 2)
        searchModels(kw, function(list, err)
            if not list then return notify("Skins", "Search failed: " .. tostring(err), "error", 5) end
            results = {}
            local names = {}
            for _, x in ipairs(list) do
                local label = string.format("%s - %s", x.name:sub(1, 36), x.by)
                local i = 1
                while results[label] do i += 1 label = string.format("%s - %s #%d", x.name:sub(1, 32), x.by, i) end
                results[label] = { id = x.id, name = x.name }
                names[#names + 1] = label
            end
            resDd.Refresh(names)
            notify("Skins", #names .. " results", "success")
        end)
    end })
    cs:AddButton({ Name = "Use as Knife", Callback = function()
        local r = chosen and results[chosen]
        if r then loadSkinAsset(r.id, r.name, "Knife") else notify("Skins", "Pick a result first", "warning") end
    end })
    cs:AddButton({ Name = "Use as Gun", Callback = function()
        local r = chosen and results[chosen]
        if r then loadSkinAsset(r.id, r.name, "Gun") else notify("Skins", "Pick a result first", "warning") end
    end })

    local cu = R:CreateSection({ Name = "Custom Mesh", Icon = "box", Collapsible = true })
    local meshBox, texBox, scaleBox = "", "", "1"
    cu:AddTextbox({ Name = "MeshId", Placeholder = "rbxassetid://...", Callback = function(t) meshBox = t end })
    cu:AddTextbox({ Name = "TextureId", Placeholder = "rbxassetid://... (optional)", Callback = function(t) texBox = t end })
    cu:AddTextbox({ Name = "Scale", Default = "1", Numeric = true, Callback = function(t) scaleBox = t end })
    local function custom(slot)
        if meshBox == "" then return notify("Skins", "Enter a MeshId", "warning") end
        local id = meshBox:match("^%d+$") and ("rbxassetid://" .. meshBox) or meshBox
        local label = addSkin(slot, "Custom " .. slot, { meshId = id, texId = texBox, scale = Vector3.one * (tonumber(scaleBox) or 1) })
        refreshSkinLists()
        selectSkin(slot, label)
        notify("Skins", "Custom " .. slot:lower() .. " ready", "success")
    end
    cu:AddButton({ Name = "Use as Knife", Callback = function() custom("Knife") end })
    cu:AddButton({ Name = "Use as Gun", Callback = function() custom("Gun") end })

    -- avatar -------------------------------------------------------------
    local av = R:CreateSection({ Name = "Avatar Changer", Icon = "user", Collapsible = true })
    av:AddLabel("Copies another user's look. Only you see it.")
    local who = ""
    av:AddTextbox({ Name = "Username / UserId", Placeholder = "Roblox username or id", Callback = function(t) who = t end })
    av:AddButton({ Name = "Apply", Primary = true, Callback = function()
        if who == "" then return notify("Avatar", "Enter a username or id", "warning") end
        applyAvatar(who)
    end })
    local function playerNames()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= lp then t[#t + 1] = p.Name end end
        table.sort(t)
        return t
    end
    local copyWho
    local copyDd = av:AddDropdown({ Name = "Copy Player", Options = playerNames(), Callback = function(v) copyWho = v end })
    av:AddButton({ Name = "Refresh Players", Callback = function() copyDd.Refresh(playerNames(), true) end })
    av:AddButton({ Name = "Copy Selected", Callback = function()
        local p = copyWho and Players:FindFirstChild(copyWho)
        if p then applyDescriptionFor(p.UserId, p.DisplayName) else notify("Avatar", "Select a player", "warning") end
    end })
    av:AddButton({ Name = "Reset", Callback = resetAvatar })
end

-- EFFECTS -----------------------------------------------------------
do
    local L, R = FxTab:Column("left"), FxTab:Column("right")

    local tr = L:CreateSection({ Name = "Bullet Tracers", Icon = "zap", Collapsible = true })
    local trT = tr:AddToggle({ Name = "Bullet Tracers", Icon = "zap", Description = "Beams for gun shots and knife throws", Callback = function(v) F.tracers = v end })
    trT:AddColorPicker({ Default = F.trColor, Callback = function(c) F.trColor = c end })
    tr:AddDropdown({ Name = "Style", Options = TRACER_STYLES, Default = F.trStyle, Callback = function(v) F.trStyle = v or "Beam" end })
    tr:AddDropdown({ Name = "Color Mode", Options = { "Custom", "Rainbow", "By Role" }, Default = "Custom", Callback = function(v) F.trMode = v or "Custom" end })
    tr:AddSlider({ Name = "Width", Min = 0.05, Max = 1.2, Default = F.trWidth, Decimals = 2, Callback = function(v) F.trWidth = v end })
    tr:AddSlider({ Name = "Duration", Min = 0.2, Max = 2.5, Default = F.trTime, Decimals = 1, Suffix = " s", Callback = function(v) F.trTime = v end })
    tr:AddToggle({ Name = "Impact Sparks", Default = true, Callback = function(v) F.trImpact = v end })
    tr:AddToggle({ Name = "My Shots", Default = true, Callback = function(v) F.trMine = v end })
    tr:AddToggle({ Name = "Others' Shots", Default = true, Callback = function(v) F.trOthers = v end })
    tr:AddButton({ Name = "Test Tracer", Primary = true, Callback = function()
        local cf = cam.CFrame
        drawTracer(cf.Position + cf.LookVector * 3 + cf.RightVector * 0.6 - Vector3.new(0, 0.6, 0), cf.Position + cf.LookVector * 70)
    end })

    local kf = L:CreateSection({ Name = "Kill Effects", Icon = "skull", Collapsible = true })
    kf:AddToggle({ Name = "Kill Effects", Icon = "skull", Callback = function(v) F.killFx = v end })
    kf:AddDropdown({ Name = "Style", Options = KILL_STYLES, Default = F.kfStyle, Callback = function(v) F.kfStyle = v or "Soul Ascend" end })
    kf:AddDropdown({ Name = "Filter", Options = { "All kills", "Only my kills", "Exclude me" }, Default = "All kills", Callback = function(v) F.kfMode = v or "All kills" end })
    kf:AddToggle({ Name = "Use Role Color", Default = true, Callback = function(v) F.kfRole = v end })
    kf:AddColorPicker({ Name = "Color", Default = F.kfColor, Callback = function(c) F.kfColor = c end })
    kf:AddToggle({ Name = "Floating Text", Default = true, Callback = function(v) F.kfText = v end })
    kf:AddToggle({ Name = "Camera Shake", Default = true, Callback = function(v) F.kfShake = v end })
    kf:AddToggle({ Name = "Screen Flash", Default = true, Callback = function(v) F.kfFlash = v end })
    kf:AddButton({ Name = "Preview on Me", Primary = true, Callback = function() task.spawn(killEffect, lp, true) end })

    local au = R:CreateSection({ Name = "Aura", Icon = "sparkles", Collapsible = true })
    local auT = au:AddToggle({ Name = "My Aura", Icon = "sparkles", Callback = function(v) F.aura = v end })
    auT:AddColorPicker({ Default = F.auColor, Callback = function(c) F.auColor = c end })
    au:AddDropdown({ Name = "Style", Options = AURA_STYLES, Default = F.auStyle, Callback = function(v) F.auStyle = v or "Orbs" end })
    au:AddToggle({ Name = "Rainbow", Callback = function(v) F.auRainbow = v end })
    au:AddSlider({ Name = "Size", Min = 0.6, Max = 2.2, Default = F.auScale, Decimals = 1, Callback = function(v) F.auScale = v end })
    au:AddToggle({ Name = "Role Auras", Description = "Glow around the murderer and the sheriff", Callback = function(v) F.roleAura = v end })

    local tl = R:CreateSection({ Name = "Player Trail", Icon = "wind", Collapsible = true })
    local tlT = tl:AddToggle({ Name = "Trail", Icon = "wind", Callback = function(v) F.trail = v end })
    tlT:AddColorPicker({ Default = F.trailColor, Callback = function(c) F.trailColor = c end })
    tl:AddToggle({ Name = "Rainbow", Default = true, Callback = function(v) F.trailRainbow = v end })
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
        if v and modelIdByName[v] ~= MR.templateId then loadModelAsset(modelIdByName[v], true) end
    end })
    rp:AddButton({ Name = "Load Preset", Primary = true, Callback = function() loadModelAsset(modelIdByName[chosen]) end })
    local customId = ""
    rp:AddTextbox({ Name = "Asset ID", Placeholder = "e.g. 138151705692565", Numeric = true, Callback = function(t) customId = t end })
    rp:AddButton({ Name = "Load ID", Callback = function()
        local id = tonumber(customId)
        if id then loadModelAsset(id) else notify("Model", "Enter a numeric asset id", "warning") end
    end })
    rp:AddSlider({ Name = "Height", Min = 2, Max = 16, Default = MR.height, Decimals = 1, Suffix = " st", Callback = function(v) MR.height = v end })
    rp:AddSlider({ Name = "Rotation Offset", Min = 0, Max = 360, Default = 0, Suffix = "°", Callback = function(v) MR.yaw = v end })
    rp:AddSlider({ Name = "Vertical Offset", Min = -3, Max = 3, Default = 0, Decimals = 1, Callback = function(v) MR.yoff = v end })
    rp:AddButton({ Name = "Remove", Callback = function()
        if MR.toggle then MR.toggle.Set(false) end
        mrDropAll()
        if MR.template then MR.template:Destroy() MR.template = nil end
    end })

    local sr = R:CreateSection({ Name = "Search Models", Icon = "search", Collapsible = true })
    sr:AddLabel("Searches the Roblox toolbox. Scripts and sounds are stripped.")
    local kw, results = "tung tung sahur", {}
    sr:AddTextbox({ Name = "Keyword", Default = kw, Placeholder = "keyword", Callback = function(t) kw = t end })
    local resDd
    local resChosen
    resDd = sr:AddDropdown({ Name = "Results", Options = {}, Callback = function(v) resChosen = v end })
    sr:AddButton({ Name = "Search", Primary = true, Callback = function()
        notify("Model", "Searching...", "info", 2)
        searchModels(kw, function(list, err)
            if not list then return notify("Model", "Search failed: " .. tostring(err), "error", 5) end
            results = {}
            local names = {}
            for _, x in ipairs(list) do
                local label = string.format("%s - %s", x.name:sub(1, 38), x.by)
                local i = 1
                while results[label] do i += 1 label = string.format("%s - %s #%d", x.name:sub(1, 34), x.by, i) end
                results[label] = x.id
                names[#names + 1] = label
            end
            resDd.Refresh(names)
            notify("Model", #names .. " results", "success")
        end)
    end })
    sr:AddButton({ Name = "Load Result", Callback = function()
        local id = resChosen and results[resChosen]
        if id then loadModelAsset(id) else notify("Model", "Pick a result first", "warning") end
    end })
end

-- MISC --------------------------------------------------------------
do
    local L = MiscTab:Column("left")
    local m = L:CreateSection({ Name = "Utility", Icon = "wrench", Collapsible = true })
    m:AddButton({ Name = "Rejoin", Callback = function() if Library.Rejoin then Library:Rejoin() else TeleportService:Teleport(game.PlaceId, lp) end end })
    m:AddButton({ Name = "Server Hop", Callback = function() if Library.ServerHop then Library:ServerHop() end end })
    m:AddButton({ Name = "Reset Character", Callback = function() local h = humOf(lp) if h then h.Health = 0 end end })
    m:AddLabel("Anti-AFK is always on.")
end

-- preload the default model in the background so "Replace Models" works the moment it is switched on
task.delay(1.5, function()
    if alive and not MR.template then loadModelAsset(MODEL_PRESETS[1][2], true) end
end)

notify("Moro MM2", "Loaded. RightShift opens the menu.", "success", 4)
