-- [[ Services & Modules ]] --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- [[ Game Specific Modules & Remotes ]] --
local Utils = require(ReplicatedFirst.Utils)
local SerialisedData = require(ReplicatedStorage.Modules.SerialisedData)

local TagPlayerEvent = Utils.GetEvent("TagPlayer")
local CIParryProjectileEvent = Utils.GetEvent("CIParryProjectile")
local CIParryClientEvent = Utils.GetEvent("CIParryClient")
local PlayerParryEvent = Utils.GetEvent("PlayerParry")

local SoundEvent = Utils.GetEvent("SoundEvent")
local AnimateEvent = Utils.GetEvent("AnimateEvent")
local TagSwing = Utils.GetEvent("TagSwing")

-- [[ Global Settings for UI ]] --
_G.AutoTagEnabled = false
_G.AutoParryEnabled = false
_G.KillAuraRange = 15
_G.AutoParryRange = 12
_G.ShowKillAuraRing = true
_G.AutoDodgeEnabled = false
_G.DodgeRadius = 12
_G.DodgeInputMethod = "Keyboard"

-- [[ Helpers ]] --
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
-- [[ VISUALIZER RING (Кольцо на земле) ]] --
-- ============================================================
-- Создаём кольцо из двух цилиндров (внешний и внутренний)
local killAuraRingOuter = Instance.new("Part")
killAuraRingOuter.Name = "MoroKillAuraRingOuter"
killAuraRingOuter.Shape = Enum.PartType.Cylinder
killAuraRingOuter.Size = Vector3.new(0.2, 30, 30)
killAuraRingOuter.Material = Enum.Material.Neon
killAuraRingOuter.Color = Color3.fromRGB(255, 0, 0)
killAuraRingOuter.Transparency = 0.6
killAuraRingOuter.CanCollide = false
killAuraRingOuter.CanTouch = false
killAuraRingOuter.CanQuery = false
killAuraRingOuter.Massless = true
killAuraRingOuter.Anchored = true
killAuraRingOuter.TopSurface = Enum.SurfaceType.Smooth
killAuraRingOuter.BottomSurface = Enum.SurfaceType.Smooth
killAuraRingOuter.Parent = workspace

local killAuraRingInner = Instance.new("Part")
killAuraRingInner.Name = "MoroKillAuraRingInner"
killAuraRingInner.Shape = Enum.PartType.Cylinder
killAuraRingInner.Size = Vector3.new(0.3, 28, 28)
killAuraRingInner.Material = Enum.Material.Neon
killAuraRingInner.Color = Color3.fromRGB(0, 0, 0)
killAuraRingInner.Transparency = 1
killAuraRingInner.CanCollide = false
killAuraRingInner.CanTouch = false
killAuraRingInner.CanQuery = false
killAuraRingInner.Massless = true
killAuraRingInner.Anchored = true
killAuraRingInner.TopSurface = Enum.SurfaceType.Smooth
killAuraRingInner.BottomSurface = Enum.SurfaceType.Smooth
killAuraRingInner.Parent = workspace

local floorRayParams = RaycastParams.new()
floorRayParams.FilterType = Enum.RaycastFilterType.Exclude
floorRayParams.FilterDescendantsInstances = {LocalPlayer.Character}

local function updateRing()
    local hrp = getHRP()
    if hrp and _G.AutoTagEnabled and _G.ShowKillAuraRing then
        floorRayParams.FilterDescendantsInstances = {LocalPlayer.Character}
        local ray = workspace:Raycast(
            hrp.Position + Vector3.new(0, 2, 0),
            Vector3.new(0, -50, 0),
            floorRayParams
        )
        
        local floorY
        if ray then
            floorY = ray.Position.Y + 0.05
        else
            floorY = hrp.Position.Y - (hrp.Size.Y / 2) - 2
        end

        local pos = Vector3.new(hrp.Position.X, floorY, hrp.Position.Z)
        local radius = _G.KillAuraRange
        
        killAuraRingOuter.CFrame = CFrame.new(pos)
        killAuraRingOuter.Size = Vector3.new(radius * 2, 0.2, radius * 2)
        killAuraRingOuter.Transparency = 0.4
        
        killAuraRingInner.CFrame = CFrame.new(pos)
        killAuraRingInner.Size = Vector3.new((radius - 0.5) * 2, 0.3, (radius - 0.5) * 2)
    else
        killAuraRingOuter.Transparency = 1
        killAuraRingInner.Transparency = 1
    end
end

-- ============================================================
-- [[ ATTRIBUTE BOOSTERS ]] --
-- ============================================================
local baseAttributes = {
    ["AccelerationMultiplier"] = 3, ["RunSpeedMultiplier"] = 1.01,
    ["JumpPowerMultiplier"] = 1.25, ["SizeMultiplier"] = 1.15,
    ["HeadSizeMultiplier"] = 1, ["TagCooldown"] = 0.666,
    ["TagPlayerKnockback"] = 0.75,
}

local boosters = {}
for attr, defaultBase in pairs(baseAttributes) do
    boosters[attr] = { enabled = false, mult = 1.0, base = defaultBase }
end

local function applyAllBoosts()
    local modifiers = LocalPlayer:FindFirstChild("Modifiers")
    local roleObj = modifiers and modifiers:FindFirstChild("Role")
    if not roleObj then return end
    
    for attr, data in pairs(boosters) do
        local targetVal = data.enabled and (data.base * data.mult) or data.base
        if roleObj:GetAttribute(attr) ~= targetVal then
            roleObj:SetAttribute(attr, targetVal)
        end
    end
end

-- ============================================================
-- [[ AUTO-TAG (KILL AURA) ]] --
-- ============================================================
local IGNORED_ROLES = {
    ["Bomb"] = true, ["PatientZero"] = true, ["Infected"] = true,
    ["Tagger"] = true, ["HotBomb"] = true, ["Chiller"] = true, ["OOF"] = true
}

local losRayParams = RaycastParams.new()
losRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(fromPos, toPos, myChar, targetChar)
    losRayParams.FilterDescendantsInstances = {myChar, targetChar}
    
    local direction = toPos - fromPos
    local distance = direction.Magnitude
    
    local ray = workspace:Raycast(fromPos, direction, losRayParams)

    if not ray then return true end
    if ray.Distance >= distance - 0.5 then return true end
    
    return false
end

local function autoTagLoop()
    if not _G.AutoTagEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    
    local myRole = LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value
    local closestTarget, closestDist = nil, _G.KillAuraRange
    
    local myChar = LocalPlayer.Character
    
    for _, char in ipairs(CollectionService:GetTagged("TaggablePlayer")) do
        if char ~= myChar and char:FindFirstChild("HumanoidRootPart") then
            local targetPlayer = Players:GetPlayerFromCharacter(char)
            local targetRole = targetPlayer and targetPlayer:FindFirstChild("PlayerRole") and targetPlayer.PlayerRole.Value
            
            if myRole == "Crown" and (targetRole == "Peasant" or targetRole == "Knight") then continue end
            if myRole == "Chiller" and targetRole == "Frozen" then continue end
            if myRole == "Runner" and targetRole == "Chiller" then continue end
            
            if myRole ~= "Alone" then
                if myRole and targetRole and myRole == targetRole then continue end
            end
            
            if targetRole and IGNORED_ROLES[targetRole] then continue end
            
            local targetHRP = char.HumanoidRootPart
            local dist = (targetHRP.Position - hrp.Position).Magnitude
            
            -- Проверка дистанции
            if dist < closestDist then
                -- НОВАЯ ПРОВЕРКА: видимость сквозь стены
                -- Стреляем луч от глаз (HRP + 1.5 по Y) к HRP цели
                local eyePos = hrp.Position + Vector3.new(0, 1.5, 0)
                local targetPos = targetHRP.Position
                
                if hasLineOfSight(eyePos, targetPos, myChar, char) then
                    closestDist = dist
                    closestTarget = char
                end
            end
        end
    end
    
    if closestTarget then
        local targetHRP = closestTarget.HumanoidRootPart
        local targetPlayer = Players:GetPlayerFromCharacter(closestTarget)
        
        if targetPlayer then
            local success, targetID = pcall(SerialisedData.getPlayer, targetPlayer)
            if success and targetID then
                local lookCFrame = CFrame.new(hrp.Position, targetHRP.Position)
                local a1, a2, a3 = lookCFrame:ToEulerAnglesYXZ()
                
                local compress = function(angle)
                    return math.floor((angle + math.pi) / (math.pi * 2) * 65535 + 0.5)
                end
                
                local buf = buffer.create(7)
                buffer.writeu8(buf, 0, targetID)
                buffer.writeu16(buf, 1, compress(a1))
                buffer.writeu16(buf, 3, compress(a2))
                buffer.writeu16(buf, 5, compress(a3))
                
                local s, res = pcall(function() return TagPlayerEvent:InvokeServer(buf) end)
                
                if s and res then
                    pcall(function() SoundEvent:Fire("Tag", hrp, 0.25, true) end)
                    local tagSpeed = 1 / (boosters.TagCooldown.enabled and (boosters.TagCooldown.base * boosters.TagCooldown.mult) or boosters.TagCooldown.base)
                    pcall(function() AnimateEvent:Fire("Tag", 0.1, tagSpeed) end)
                    pcall(function() TagSwing:Fire() end)
                end
            end
        end
    end
end

-- ============================================================
-- [[ AUTO-PARRY ]] --
-- ============================================================
local function autoParryLoop()
    if not _G.AutoParryEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    
    for _, projectile in ipairs(CollectionService:GetTagged("Parryable")) do
        if projectile:GetAttribute("Sender") ~= LocalPlayer.Name then
            local dist = (projectile.Position - hrp.Position).Magnitude
            if dist < _G.AutoParryRange then
                local lookVector = CFrame.new(hrp.Position, projectile.Position).LookVector
                pcall(function() CIParryProjectileEvent:InvokeServer(projectile, lookVector) end)
                pcall(function() CIParryClientEvent:Fire() end)
                pcall(function() PlayerParryEvent:FireServer() end)
            end
        end
    end
end

-- ============================================================
-- [[ AUTO DODGE (LEGIT) ]] --
-- ============================================================
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local dodgeCooldown = 0.5
local lastDodgeTime = 0

local function isTagger(player)
    local roleObj = player:FindFirstChild("PlayerRole")
    if roleObj then
        return table.find(TAGGER_ROLES, roleObj.Value) ~= nil
    end
    return false
end

local function isLookingAtMe(taggerHrp, myHrp)
    local lookVector = taggerHrp.CFrame.LookVector
    local direction = (myHrp.Position - taggerHrp.Position).Unit
    local dot = lookVector:Dot(direction)
    return dot > 0.7 -- Угол < 45°
end

local function checkObstacle(myHrp, direction)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local ray = workspace:Raycast(
        myHrp.Position + direction * 2,
        direction * 5,
        rayParams
    )
    
    return ray ~= nil -- Есть препятствие
end

local function performDodge(taggerHrp, myHrp)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    
    -- Определяем направление для strafe (перпендикулярно к тэггеру)
    local toTagger = (taggerHrp.Position - myHrp.Position).Unit
    local strafeDir = Vector3.new(-toTagger.Z, 0, toTagger.X)
    
    -- Случайный выбор: влево или вправо
    if math.random() > 0.5 then
        strafeDir = -strafeDir
    end
    
    -- Проверяем препятствия в обоих направлениях
    if checkObstacle(myHrp, strafeDir) then
        strafeDir = -strafeDir -- Меняем направление
        if checkObstacle(myHrp, strafeDir) then
            return -- Оба направления заблокированы, не уклоняемся
        end
    end
    
    -- Прыжок (если на земле)
    if hum.FloorMaterial ~= Enum.Material.Air then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    
    -- Симуляция движения в зависимости от метода ввода
    if _G.DodgeInputMethod == "Keyboard" then
        -- Клавиатура: используем VirtualInputManager
        local moveX = strafeDir.X > 0 and 1 or -1
        local moveZ = strafeDir.Z > 0 and 1 or -1
        
        -- Симулируем нажатие клавиш A/D и W/S
        task.spawn(function()
            local duration = 0.3
            local startTime = tick()
            
            while tick() - startTime < duration do
                -- Симулируем движение через клавиши
                if moveX ~= 0 then
                    local key = moveX > 0 and Enum.KeyCode.D or Enum.KeyCode.A
                    VirtualInputManager:SendKeyEvent(true, key, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, key, false, game)
                end
                if moveZ ~= 0 then
                    local key = moveZ > 0 and Enum.KeyCode.W or Enum.KeyCode.S
                    VirtualInputManager:SendKeyEvent(true, key, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, key, false, game)
                end
                task.wait(0.05)
            end
        end)
    else
        -- Джойстик: используем ContextActionService или прямое управление
        task.spawn(function()
            local duration = 0.3
            local startTime = tick()
            local cameraCF = Camera.CFrame
            local relativeDir = cameraCF:VectorToObjectSpace(strafeDir)
            
            -- Нормализуем для контроллера
            local moveX = math.clamp(relativeDir.X, -1, 1)
            local moveZ = math.clamp(-relativeDir.Z, -1, 1)
            
            while tick() - startTime < duration do
                -- Симулируем движение через джойстик
                -- Используем Thumbstick1 для движения
                local thumbstickValue = Vector3.new(moveX, 0, moveZ)
                
                -- Симулируем ввод джойстика
                pcall(function()
                    VirtualInputManager:SendGamepadEvent(
                        Enum.UserInputType.Gamepad1,
                        Enum.KeyCode.Thumbstick1,
                        thumbstickValue,
                        game
                    )
                end)
                
                task.wait(0.05)
            end
            
            -- Возвращаем джойстик в центр
            pcall(function()
                VirtualInputManager:SendGamepadEvent(
                    Enum.UserInputType.Gamepad1,
                    Enum.KeyCode.Thumbstick1,
                    Vector3.new(0, 0, 0),
                    game
                )
            end)
        end)
    end
end

local function autoDodgeLoop()
    if not _G.AutoDodgeEnabled then return end
    
    local char = LocalPlayer.Character
    local myHrp = char and char:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    
    -- Проверяем, что мы выживший (не таггер)
    local myRole = LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value
    if isTagger(LocalPlayer) then return end
    
    -- Кулдаун
    if tick() - lastDodgeTime < dodgeCooldown then return end
    
    -- Ищем ближайшую угрозу
    local closestTagger, closestDist = nil, _G.DodgeRadius
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isTagger(player) then
            -- Не уклоняемся от тиммейтов
            if isMyTeam(player) then continue end
            
            local taggerHrp = player.Character:FindFirstChild("HumanoidRootPart")
            if taggerHrp then
                local dist = (taggerHrp.Position - myHrp.Position).Magnitude
                
                if dist < closestDist and isLookingAtMe(taggerHrp, myHrp) then
                    closestDist = dist
                    closestTagger = taggerHrp
                end
            end
        end
    end
    
    -- Если нашли угрозу, которая смотрит на нас
    if closestTagger then
        performDodge(closestTagger, myHrp)
        lastDodgeTime = tick()
    end
end

-- ============================================================
-- [[ LOOK AT PLAYER (HARD LOCK) ]] --
-- ============================================================
local lookAtEnabled = false
local lookAtTarget = nil

local function lookAtLoop()
    if not lookAtEnabled or not lookAtTarget then return end
    local targetPlayer = Players:FindFirstChild(lookAtTarget)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHrp.Position)
end

-- ============================================================
-- [[ HITBOX EXPANDER ]] --
-- ============================================================
local hitboxEnabled = false
local hitboxMultiplier = 1.5
local hitboxVisualize = false
local hitboxCache = {}

local function createHitboxPart(part, multiplier)
    local hitbox = Instance.new("Part")
    hitbox.Name = "MoroHitbox"
    hitbox.Transparency = hitboxVisualize and 0.7 or 1
    hitbox.Color = Color3.fromRGB(255, 0, 0)
    hitbox.CanCollide = false
    hitbox.Anchored = false
    hitbox.Size = part.Size * multiplier
    hitbox.CFrame = part.CFrame
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = part
    weld.Part1 = hitbox
    weld.Parent = hitbox
    hitbox.Parent = part
    return hitbox
end

local function updateHitboxes()
    if not hitboxEnabled then
        for char, parts in pairs(hitboxCache) do
            for _, hitbox in pairs(parts) do
                if hitbox.Parent then hitbox:Destroy() end
            end
        end
        hitboxCache = {}
        return
    end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            if not hitboxCache[char] then
                hitboxCache[char] = {}
                local partsToExpand = {
                    "Head", "UpperTorso", "LowerTorso",
                    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
                    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"
                }
                for _, partName in ipairs(partsToExpand) do
                    local part = char:FindFirstChild(partName)
                    if part then hitboxCache[char][part] = createHitboxPart(part, hitboxMultiplier) end
                end
            else
                for part, hitbox in pairs(hitboxCache[char]) do
                    if hitbox.Parent then
                        hitbox.Size = part.Size * hitboxMultiplier
                        hitbox.Transparency = hitboxVisualize and 0.7 or 1
                    end
                end
            end
        end
    end
end

-- ============================================================
-- [[ TRACERS ]] — с категориями и цветными ролями
-- ============================================================
local tracersEnabled = false
local selectedCategories = {}
local lines = {}

local function clearTracerCache(playerName)
    if lines[playerName] then
        pcall(function()
            lines[playerName].Visible = false
            lines[playerName]:Remove()
        end)
        lines[playerName] = nil
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            clearTracerCache(player.Name)
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        clearTracerCache(player.Name)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    clearTracerCache(player.Name)
end)

local function isEnemy(player)
    -- OOF и Frozen — это отдельные категории, не враги
    if isOOF(player) or isFrozen(player) then return false end
    
    local myRole = LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value
    local theirRole = player:FindFirstChild("PlayerRole") and player.PlayerRole.Value
    if not myRole or not theirRole then return false end
    
    -- Враг = роль другая ИЛИ я в FFA-режиме (Alone)
    return myRole ~= theirRole or myRole == "Alone"
end

local function isMyTeam(player)
    -- OOF и Frozen — это отдельные категории
    if isOOF(player) or isFrozen(player) then return false end
    
    local myRole = LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value
    local theirRole = player:FindFirstChild("PlayerRole") and player.PlayerRole.Value
    if not myRole or not theirRole then return false end
    
    -- Моя команда = та же роль, но НЕ Alone и НЕ OOF
    return myRole == theirRole and myRole ~= "Alone" and myRole ~= "OOF"
end

local function isMyTeam(player)
    -- OOF и Frozen игроки НЕ считаются тиммейтами
    if isOOF(player) or isFrozen(player) then return false end
    
    local myRole = LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value
    local theirRole = player:FindFirstChild("PlayerRole") and player.PlayerRole.Value
    if not myRole or not theirRole then return false end
    
    return myRole == theirRole
end

local function isOOF(player)
    local char = player.Character
    if not char then return false end
    return char:GetAttribute("OOF") == true or
           char:GetAttribute("Eliminated") == true or
           char:GetAttribute("Dead") == true or
           (char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0)
end

local function isFrozen(player)
    local char = player.Character
    if not char then return false end
    return char:GetAttribute("Frozen") == true or
           char:GetAttribute("Chilled") == true or
           char:GetAttribute("Ice") == true
end

local roleColors = {
    ["Crown"] = Color3.fromRGB(255, 215, 0),
    ["Monarch"] = Color3.fromRGB(255, 215, 0),
    ["Tagger"] = Color3.fromRGB(255, 0, 0),
    ["RunnerTagger"] = Color3.fromRGB(255, 0, 0),
    ["FFATagger"] = Color3.fromRGB(255, 0, 0),
    ["SlapFFATagger"] = Color3.fromRGB(255, 0, 0),
    ["Infected"] = Color3.fromRGB(50, 205, 50),
    ["PatientZero"] = Color3.fromRGB(50, 205, 50),
    ["FastInfected"] = Color3.fromRGB(50, 205, 50),
    ["BabyInfected"] = Color3.fromRGB(50, 205, 50),
    ["JumpingInfected"] = Color3.fromRGB(50, 205, 50),
    ["BigInfected"] = Color3.fromRGB(50, 205, 50),
    ["CloakInfected"] = Color3.fromRGB(50, 205, 50),
    ["InfectedRunner"] = Color3.fromRGB(50, 205, 50),
    ["Bomb"] = Color3.fromRGB(255, 140, 0),
    ["SubspaceBomb"] = Color3.fromRGB(255, 140, 0),
    ["AshyBomb"] = Color3.fromRGB(255, 140, 0),
    ["HotBomb"] = Color3.fromRGB(255, 140, 0),
    ["FunnyBomb"] = Color3.fromRGB(255, 140, 0),
    ["Nuke"] = Color3.fromRGB(255, 140, 0),
    ["Slasher"] = Color3.fromRGB(75, 0, 130),
    ["HiddenSlasher"] = Color3.fromRGB(75, 0, 130),
    ["Haunter"] = Color3.fromRGB(75, 0, 130),
    ["Knight"] = Color3.fromRGB(169, 169, 169),
    ["Bodyguard"] = Color3.fromRGB(169, 169, 169),
    ["Peasant"] = Color3.fromRGB(139, 69, 19),
    ["Baron"] = Color3.fromRGB(139, 69, 19),
    ["Freezer"] = Color3.fromRGB(0, 206, 209),
    ["Chiller"] = Color3.fromRGB(0, 206, 209),
    ["Frozen"] = Color3.fromRGB(0, 206, 209),
    ["Arsonist"] = Color3.fromRGB(255, 69, 0),
    ["Burning"] = Color3.fromRGB(255, 69, 0),
    ["Toxic"] = Color3.fromRGB(126, 255, 5),
    ["Seeker"] = Color3.fromRGB(50, 50, 255),
    ["Overseer"] = Color3.fromRGB(50, 50, 255),
    ["Hunter"] = Color3.fromRGB(50, 50, 255),
    ["Eliminator"] = Color3.fromRGB(50, 50, 255),
    ["Assassin"] = Color3.fromRGB(50, 50, 255),
    ["Juggernaut"] = Color3.fromRGB(50, 50, 255),
    ["Target"] = Color3.fromRGB(255, 100, 255),
    ["HiddenBeing"] = Color3.fromRGB(255, 100, 255),
    ["Runner"] = Color3.fromRGB(100, 200, 255),
    ["Hider"] = Color3.fromRGB(100, 200, 255),
    ["Medic"] = Color3.fromRGB(100, 200, 255),
    ["Spectator"] = Color3.fromRGB(128, 128, 128),
    ["pingus"] = Color3.fromRGB(128, 128, 128),
}
local function getRoleColor(role) return roleColors[role] or Color3.fromRGB(255, 255, 255) end

-- ============================================================
-- [[ UI ]] --
-- ============================================================
local Lumina = loadstring(game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"))()
local Window = Lumina:CreateWindow({ Title = "MoroLumina | Evade" })

-- ===================== MOVEMENT TAB =====================
local moveTab = Window:CreateTab({ Name = "Movement", Icon = "move" })

moveTab:Column("left")
local accelSec = moveTab:CreateSection({ Name = "Acceleration", Icon = "zap" })
accelSec:AddToggle({
    Name = "Acceleration Booster", Icon = "zap", Default = false,
    Callback = function(state)
        boosters.AccelerationMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.AccelerationMultiplier.base = roleObj:GetAttribute("AccelerationMultiplier") or 3 end
        end
        applyAllBoosts()
    end,
})
accelSec:AddSlider({
    Name = "Accel Multiplier", Icon = "trending-up", Min = 0.1, Max = 20.0, Default = 20.0, Decimals = 2,
    Callback = function(v) boosters.AccelerationMultiplier.mult = v; applyAllBoosts() end,
})

local runSec = moveTab:CreateSection({ Name = "Run Speed", Icon = "activity" })
runSec:AddToggle({
    Name = "Run Speed Booster", Icon = "activity", Default = false,
    Callback = function(state)
        boosters.RunSpeedMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.RunSpeedMultiplier.base = roleObj:GetAttribute("RunSpeedMultiplier") or 1.01 end
        end
        applyAllBoosts()
    end,
})
runSec:AddSlider({
    Name = "Run Multiplier", Icon = "trending-up", Min = 0.1, Max = 2.0, Default = 1.1, Decimals = 2,
    Callback = function(v) boosters.RunSpeedMultiplier.mult = v; applyAllBoosts() end,
})

moveTab:Column("right")
local jumpSec = moveTab:CreateSection({ Name = "Jump Power", Icon = "arrow-up" })
jumpSec:AddToggle({
    Name = "Jump Power Booster", Icon = "arrow-up", Default = false,
    Callback = function(state)
        boosters.JumpPowerMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.JumpPowerMultiplier.base = roleObj:GetAttribute("JumpPowerMultiplier") or 1.25 end
        end
        applyAllBoosts()
    end,
})
jumpSec:AddSlider({
    Name = "Jump Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.JumpPowerMultiplier.mult = v; applyAllBoosts() end,
})

-- ===================== VISUALS TAB =====================
local visualsTab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })

visualsTab:Column("left")
local sizeSec = visualsTab:CreateSection({ Name = "Body Size", Icon = "maximize" })
sizeSec:AddToggle({
    Name = "Size Booster", Icon = "maximize", Default = false,
    Callback = function(state)
        boosters.SizeMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.SizeMultiplier.base = roleObj:GetAttribute("SizeMultiplier") or 1.15 end
        end
        applyAllBoosts()
    end,
})
sizeSec:AddSlider({
    Name = "Size Multiplier", Icon = "trending-up", Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.SizeMultiplier.mult = v; applyAllBoosts() end,
})

local headSec = visualsTab:CreateSection({ Name = "Head Size", Icon = "circle" })
headSec:AddToggle({
    Name = "Head Size Booster", Icon = "circle", Default = false,
    Callback = function(state)
        boosters.HeadSizeMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.HeadSizeMultiplier.base = roleObj:GetAttribute("HeadSizeMultiplier") or 1 end
        end
        applyAllBoosts()
    end,
})
headSec:AddSlider({
    Name = "Head Multiplier", Icon = "trending-up", Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.HeadSizeMultiplier.mult = v; applyAllBoosts() end,
})

visualsTab:Column("right")
local tracerSec = visualsTab:CreateSection({ Name = "Tracers", Icon = "crosshair" })
tracerSec:AddToggle({
    Name = "Enable Tracers", Icon = "crosshair", Default = false,
    Callback = function(state)
        tracersEnabled = state
        if not state then
            for _, l in pairs(lines) do
                if l and l.Visible ~= nil then l.Visible = false end
            end
        end
    end,
})

local categoryDropdown = tracerSec:AddMultiDropdown({
    Name = "Select Categories",
    Icon = "users",
    Options = {"Enemies", "My Team", "OOF", "Frozen"},
    Default = {"Enemies"},
    Callback = function(values) selectedCategories = values end,
})

-- ===================== COMBAT TAB =====================
local combatTab = Window:CreateTab({ Name = "Combat", Icon = "crosshair" })

combatTab:Column("left")
local tagCdSec = combatTab:CreateSection({ Name = "Tag Cooldown", Icon = "clock" })
tagCdSec:AddToggle({
    Name = "Tag Cooldown Booster", Icon = "clock", Default = false,
    Callback = function(state)
        boosters.TagCooldown.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.TagCooldown.base = roleObj:GetAttribute("TagCooldown") or 0.666 end
        end
        applyAllBoosts()
    end,
})
tagCdSec:AddSlider({
    Name = "Cooldown Multiplier", Icon = "trending-up", Min = 0.01, Max = 2.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.TagCooldown.mult = v; applyAllBoosts() end,
})

local tagKbSec = combatTab:CreateSection({ Name = "Tag Knockback", Icon = "wind" })
tagKbSec:AddToggle({
    Name = "Tag Knockback Booster", Icon = "wind", Default = false,
    Callback = function(state)
        boosters.TagPlayerKnockback.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.TagPlayerKnockback.base = roleObj:GetAttribute("TagPlayerKnockback") or 0.75 end
        end
        applyAllBoosts()
    end,
})
tagKbSec:AddSlider({
    Name = "Knockback Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.TagPlayerKnockback.mult = v; applyAllBoosts() end,
})

combatTab:Column("right")
local autoTagSec = combatTab:CreateSection({ Name = "Auto Tag", Icon = "zap" })
autoTagSec:AddToggle({
    Name = "Auto Tag (Kill Aura)", Icon = "zap", Default = false,
    Callback = function(state) _G.AutoTagEnabled = state end,
})
autoTagSec:AddSlider({
    Name = "Tag Radius", Icon = "maximize", Min = 5, Max = 20, Default = 10, Decimals = 0,
    Callback = function(val) _G.KillAuraRange = val end,
})
autoTagSec:AddToggle({
    Name = "Show Ring", Icon = "circle", Default = false,
    Callback = function(state) _G.ShowKillAuraRing = state end,
})

local autoParrySec = combatTab:CreateSection({ Name = "Auto Parry", Icon = "shield" })
autoParrySec:AddToggle({
    Name = "Auto Parry", Icon = "shield", Default = false,
    Callback = function(state) _G.AutoParryEnabled = state end,
})
autoParrySec:AddSlider({
    Name = "Parry Radius", Icon = "maximize", Min = 5, Max = 20, Default = 12, Decimals = 0,
    Callback = function(val) _G.AutoParryRange = val end,
})

local autoDodgeSec = combatTab:CreateSection({ Name = "Auto Dodge", Icon = "shield" })
autoDodgeSec:AddToggle({
    Name = "Auto Dodge (Legit)", Icon = "shield", Default = false,
    Callback = function(state) _G.AutoDodgeEnabled = state end,
})
autoDodgeSec:AddSlider({
    Name = "Dodge Radius", Icon = "maximize", Min = 5, Max = 25, Default = 12, Decimals = 0,
    Callback = function(val) _G.DodgeRadius = val end,
})
autoDodgeSec:AddDropdown({
    Name = "Input Method", Icon = "keyboard",
    Options = {"Keyboard", "Joystick"},
    Default = "Keyboard",
    Callback = function(val) _G.DodgeInputMethod = val end,
})

local lookSec = combatTab:CreateSection({ Name = "Look At Player", Icon = "eye" })
lookSec:AddToggle({
    Name = "Enable Look At", Icon = "eye", Default = false,
    Callback = function(state) lookAtEnabled = state end,
})
local targetDrop = lookSec:AddDropdown({
    Name = "Select Target", Icon = "user", Options = {},
    Callback = function(val) lookAtTarget = val end,
})
lookSec:AddButton({
    Name = "Refresh Players", Icon = "refresh-cw",
    Callback = function()
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        targetDrop.Refresh(names, true)
    end,
})

local hitboxSec = combatTab:CreateSection({ Name = "Hitbox Expander", Icon = "box" })
hitboxSec:AddToggle({
    Name = "Enable Hitbox", Icon = "box", Default = false,
    Callback = function(state) hitboxEnabled = state end,
})
hitboxSec:AddSlider({
    Name = "Hitbox Size", Icon = "maximize", Min = 1.0, Max = 10.0, Default = 1.5, Decimals = 1,
    Callback = function(val) hitboxMultiplier = val end,
})
hitboxSec:AddToggle({
    Name = "Visualize Hitboxes", Icon = "eye", Default = false,
    Callback = function(state) hitboxVisualize = state end,
})

-- ===================== COSMETICS TAB =====================
local cosmeticsTab = Window:CreateTab({ Name = "Cosmetics", Icon = "shirt" })

-- Функция для работы с инвентарём
local function getInventory()
    local inv = LocalPlayer:FindFirstChild("Inventory")
    if not inv then return nil end
    local success, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(inv.Value)
    end)
    return success and data or nil
end

local function setInventory(data)
    local inv = LocalPlayer:FindFirstChild("Inventory")
    if not inv then return false end
    local success = pcall(function()
        inv.Value = game:GetService("HttpService"):JSONEncode(data)
    end)
    return success
end

-- Добавляет косметику в Owned
local function addCosmetic(category, itemName)
    local data = getInventory()
    if not data or not data.Owned then return false end
    if not data.Owned[category] then data.Owned[category] = {} end
    
    -- Проверяем, есть ли уже
    for _, item in ipairs(data.Owned[category]) do
        if item == itemName then return true end
    end
    
    table.insert(data.Owned[category], itemName)
    return setInventory(data)
end

-- Экипирует косметику (если игра поддерживает Equipped)
local function equipCosmetic(category, itemName)
    local data = getInventory()
    if not data then return false end
    
    -- Пробуем разные варианты хранения экипировки
    if not data.Equipped then data.Equipped = {} end
    if not data.Equipped[category] then data.Equipped[category] = {} end
    
    -- Очищаем текущую экипировку этой категории
    data.Equipped[category] = {}
    table.insert(data.Equipped[category], itemName)
    
    return setInventory(data)
end

-- Список всех трейлов из cosmetic.txt
local TRAILS_LIST = {
    "Basic", "Plus", "V", "T", "X", "RealPNG", "Box", "Comet", "RainbowComet",
    "Whirlpool", "Gradient", "LightGradient", "DarkGradient", "Error", "Tron",
    "Tron2", "Vantablack", "ZFight", "Snarp", "AwesomeHumanTrail", "Visualizer",
    "Freedom", "Solid", "Sparkletime", "BitWave", "Kinetic", "Cloudy", "Arithmetic",
    "Arrow", "Subspace", "cape", "Encrypted", "Stinky", "DraculaWalker", "StarTrail",
    "ghostrider", "HomingMissile", "SpeedCoilTrail", "StringLights", "Bonsai",
    "Snowflakes", "Lovestruck", "Driftin", "CherryBlossom", "JetTrail", "StarRoot",
    "IceSkates", "Tachophobia", "Ablaze", "Decorated Tree", "Snowflake Power",
    "Knight", "TankKnight", "Boombox", "MeteorFists", "PersonalSun", "PentagonTrail",
    "Spellbook", "NorthStarTrail", "CelestialHead", "YinYang", "Condiments",
    "OverfilledBriefcase", "ACUnit", "HeartTrail", "RadioHead", "SaltNPepper",
    "LovePower", "SecretSanta", "Circle", "Triangle", "StarBeam", "IdeaTrail",
    "frostbite", "Sparklinghands", "Segmented", "Illusions", "GuppyTrail", "TESTING"
}

-- Категории косметики
local CATEGORIES = {
    { Name = "Trails", Key = "Trails", Items = TRAILS_LIST },
    { Name = "Emotes", Key = "Emotes", Items = {} },
    { Name = "Tag Effects", Key = "TagEffects", Items = {} },
    { Name = "Banners", Key = "Banners", Items = {} },
    { Name = "Outfits", Key = "Outfits", Items = {} },
    { Name = "Stickers", Key = "Stickers", Items = {} },
}

local selectedCategory = CATEGORIES[1]
local selectedItem = nil

-- Секция: Добавить косметику
cosmeticsTab:Column("left")
local addSec = cosmeticsTab:CreateSection({ Name = "Add to Inventory", Icon = "plus" })

local categoryDrop = addSec:AddDropdown({
    Name = "Category",
    Icon = "layers",
    Options = (function()
        local names = {}
        for _, cat in ipairs(CATEGORIES) do table.insert(names, cat.Name) end
        return names
    end)(),
    Default = "Trails",
    Callback = function(val)
        for _, cat in ipairs(CATEGORIES) do
            if cat.Name == val then selectedCategory = cat break end
        end
    end,
})

local itemDrop = addSec:AddDropdown({
    Name = "Item",
    Icon = "box",
    Options = TRAILS_LIST,
    Default = TRAILS_LIST[1],
    Callback = function(val) selectedItem = val end,
})

addSec:AddButton({
    Name = "Add to Inventory",
    Primary = true,
    Icon = "plus",
    Callback = function()
        if not selectedItem then
            Window:Notify({ Title = "Cosmetics", Content = "Select an item first", Type = "Warning" })
            return
        end
        
        if addCosmetic(selectedCategory.Key, selectedItem) then
            Window:Notify({ 
                Title = "Cosmetics", 
                Content = "Added " .. selectedItem .. " to " .. selectedCategory.Name,
                Type = "Success",
                Duration = 3
            })
        else
            Window:Notify({ Title = "Cosmetics", Content = "Failed to add item", Type = "Error" })
        end
    end,
})

addSec:AddButton({
    Name = "Equip Item",
    Icon = "check",
    Callback = function()
        if not selectedItem then
            Window:Notify({ Title = "Cosmetics", Content = "Select an item first", Type = "Warning" })
            return
        end
        
        if equipCosmetic(selectedCategory.Key, selectedItem) then
            Window:Notify({ 
                Title = "Cosmetics", 
                Content = "Equipped " .. selectedItem,
                Type = "Success",
                Duration = 3
            })
        else
            Window:Notify({ Title = "Cosmetics", Content = "Failed to equip", Type = "Error" })
        end
    end,
})

-- Секция: Кастомный ввод
cosmeticsTab:Column("right")
local customSec = cosmeticsTab:CreateSection({ Name = "Custom Item", Icon = "edit" })

local customCategoryDrop = customSec:AddDropdown({
    Name = "Category",
    Icon = "layers",
    Options = (function()
        local names = {}
        for _, cat in ipairs(CATEGORIES) do table.insert(names, cat.Name) end
        return names
    end)(),
    Default = "Trails",
    Callback = function(val)
        for _, cat in ipairs(CATEGORIES) do
            if cat.Name == val then selectedCategory = cat break end
        end
    end,
})

local customNameBox = customSec:AddTextbox({
    Name = "Item Name",
    Placeholder = "Enter custom name",
})

customSec:AddButton({
    Name = "Add Custom Item",
    Primary = true,
    Icon = "plus",
    Callback = function()
        local name = customNameBox.Get()
        if not name or name == "" then
            Window:Notify({ Title = "Cosmetics", Content = "Enter item name", Type = "Warning" })
            return
        end
        
        if addCosmetic(selectedCategory.Key, name) then
            Window:Notify({ 
                Title = "Cosmetics", 
                Content = "Added " .. name .. " to " .. selectedCategory.Name,
                Type = "Success",
                Duration = 3
            })
        else
            Window:Notify({ Title = "Cosmetics", Content = "Failed to add", Type = "Error" })
        end
    end,
})

customSec:AddButton({
    Name = "Equip Custom",
    Icon = "check",
    Callback = function()
        local name = customNameBox.Get()
        if not name or name == "" then
            Window:Notify({ Title = "Cosmetics", Content = "Enter item name", Type = "Warning" })
            return
        end
        
        if equipCosmetic(selectedCategory.Key, name) then
            Window:Notify({ 
                Title = "Cosmetics", 
                Content = "Equipped " .. name,
                Type = "Success",
                Duration = 3
            })
        else
            Window:Notify({ Title = "Cosmetics", Content = "Failed to equip", Type = "Error" })
        end
    end,
})

-- Секция: Быстрые действия
local quickSec = cosmeticsTab:CreateSection({ Name = "Quick Actions", Icon = "zap" })

quickSec:AddButton({
    Name = "Add ALL Trails",
    Primary = true,
    Icon = "zap",
    Callback = function()
        local count = 0
        for _, trail in ipairs(TRAILS_LIST) do
            if addCosmetic("Trails", trail) then count = count + 1 end
        end
        Window:Notify({ 
            Title = "Cosmetics", 
            Content = "Added " .. count .. " trails",
            Type = "Success",
            Duration = 4
        })
    end,
})

quickSec:AddButton({
    Name = "Clear Inventory",
    Icon = "trash",
    Callback = function()
        local data = getInventory()
        if data and data.Owned then
            for cat, _ in pairs(data.Owned) do
                data.Owned[cat] = {}
            end
            setInventory(data)
            Window:Notify({ Title = "Cosmetics", Content = "Inventory cleared", Type = "Info" })
        end
    end,
})

-- ============================================================
-- [[ SETTINGS TAB (в самом низу сайдбара) ]] --
-- ============================================================
Window:AddSettingsTab()

-- ============================================================
-- [[ MAIN LOOPS ]] --
-- ============================================================
RunService.Heartbeat:Connect(function()
    autoTagLoop()
    autoParryLoop()
    autoDodgeLoop()
    applyAllBoosts()
    updateHitboxes()
end)

RunService.RenderStepped:Connect(function()
    lookAtLoop()
    updateRing()
    
    -- Трейсеры рендер
    if tracersEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            -- Определяем, нужно ли показывать
            local show = false
            if hrp then
                for _, category in ipairs(selectedCategories) do
                    if category == "Enemies" and isEnemy(player) then show = true break end
                    if category == "My Team" and isMyTeam(player) then show = true break end
                    if category == "OOF" and isOOF(player) then show = true break end
                    if category == "Frozen" and isFrozen(player) then show = true break end
                end
            end
            
            -- Если не показываем — скрываем линию (если она есть)
            if not show then
                if lines[player.Name] then
                    pcall(function() lines[player.Name].Visible = false end)
                end
                continue
            end
            
            -- Создаём линию, если её нет
            if not lines[player.Name] then
                local success, line = pcall(function()
                    local l = Drawing.new("Line")
                    l.Thickness = 1.5
                    l.Color = Color3.new(1, 1, 1)
                    return l
                end)
                if success and line then
                    lines[player.Name] = line
                else
                    continue
                end
            end
            
            -- Обновляем позицию и цвет
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local pRoleObj = player:FindFirstChild("PlayerRole")
                local pRole = pRoleObj and pRoleObj.Value
                
                pcall(function()
                    lines[player.Name].From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    lines[player.Name].To = Vector2.new(pos.X, pos.Y)
                    lines[player.Name].Color = getRoleColor(pRole)
                    lines[player.Name].Visible = true
                end)
            else
                pcall(function() lines[player.Name].Visible = false end)
            end
        end
    end
end)
