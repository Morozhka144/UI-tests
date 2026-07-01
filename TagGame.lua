-- [[ Services & Modules ]] --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

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
-- [[ ATTRIBUTE BOOSTERS (с новыми множителями) ]] --
-- ============================================================
local baseAttributes = {
    ["AccelerationMultiplier"] = 3,
    ["RunSpeedMultiplier"] = 1.01,
    ["JumpPowerMultiplier"] = 1.25,
    ["SizeMultiplier"] = 1.15,
    ["HeadSizeMultiplier"] = 1,
    ["TagCooldown"] = 0.666,
    ["TagPlayerKnockback"] = 0.75,
    -- Новые множители
    ["RangeMultiplier"] = 1,
    ["MomentumMultiplier"] = 1,
    ["MomentumDecayMultiplier"] = 1,
    ["FrictionDecayMultiplier"] = 1,
    ["WindowSmashMultiplier"] = 1,
    ["RollBoostMultiplier"] = 1,
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
            
            -- Если я Alone — тагаю ВСЕХ (кроме себя и IGNORED_ROLES)
            if myRole == "Alone" or myRole == "FFATagger" then
                if targetRole and IGNORED_ROLES[targetRole] then continue end
            else
                -- Обычная логика для остальных ролей
                if myRole == "Crown" and (targetRole == "Peasant" or targetRole == "Knight") then continue end
                if (myRole == "Chiller" or myRole == "Freezer") and targetRole == "Frozen" then continue end
                if myRole == "Runner" and targetRole == "Chiller" then continue end
                
                -- Не тагаю своих
                if myRole and targetRole and myRole == targetRole then continue end
                
                if targetRole and IGNORED_ROLES[targetRole] then continue end
            end
            
            local targetHRP = char.HumanoidRootPart
            local dist = (targetHRP.Position - hrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestTarget = char
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
local dodgeCooldown = 0.5
local lastDodgeTime = 0

local TAGGER_ROLES = {
    "Tagger", "Infected", "PatientZero", "FastInfected", "BabyInfected",
    "JumpingInfected", "BigInfected", "CloakInfected", "InfectedRunner",
    "Slasher", "HiddenSlasher", "Haunter", "FFATagger", "SlapFFATagger",
    "Seeker", "Overseer", "Assassin", "Eliminator", "Juggernaut", "Hunter",
    "Freezer", "Chiller", "Arsonist", "Toxic", "RunnerTagger"
}

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
    return dot > 0.7
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
    
    return ray ~= nil
end

local function performDodge(taggerHrp, myHrp)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    
    local toTagger = (taggerHrp.Position - myHrp.Position).Unit
    local strafeDir = Vector3.new(-toTagger.Z, 0, toTagger.X)
    
    if math.random() > 0.5 then
        strafeDir = -strafeDir
    end
    
    if checkObstacle(myHrp, strafeDir) then
        strafeDir = -strafeDir
        if checkObstacle(myHrp, strafeDir) then
            return
        end
    end
    
    if hum.FloorMaterial ~= Enum.Material.Air then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    
    if _G.DodgeInputMethod == "Keyboard" then
        local moveX = strafeDir.X > 0 and 1 or -1
        local moveZ = strafeDir.Z > 0 and 1 or -1
        
        task.spawn(function()
            local duration = 0.3
            local startTime = tick()
            
            while tick() - startTime < duration do
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
        task.spawn(function()
            local duration = 0.3
            local startTime = tick()
            local cameraCF = Camera.CFrame
            local relativeDir = cameraCF:VectorToObjectSpace(strafeDir)
            
            local moveX = math.clamp(relativeDir.X, -1, 1)
            local moveZ = math.clamp(-relativeDir.Z, -1, 1)
            
            while tick() - startTime < duration do
                local thumbstickValue = Vector3.new(moveX, 0, moveZ)
                
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
    
    local myRole = LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value
    if isTagger(LocalPlayer) then return end
    
    if tick() - lastDodgeTime < dodgeCooldown then return end
    
    local closestTagger, closestDist = nil, _G.DodgeRadius
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isTagger(player) then
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
-- [[ TRACERS ]] — с категориями и цветными ролями
-- ============================================================
local tracersEnabled = false
local selectedCategories = {"Enemies"}
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

-- Функции категорий
local function getRole(player)
    local roleObj = player:FindFirstChild("PlayerRole")
    return roleObj and roleObj.Value
end

local function isOOF(player)
    local role = getRole(player)
    return role == "OOF"
end

local function isAshen(player)
    local role = getRole(player)
    return role == "Ashen"
end

local function isDead(player)
    local role = getRole(player)
    return role == "Dead"
end

local function isFrozen(player)
    local role = getRole(player)
    return role == "Frozen"
end

local function isEnemy(player)
    local myRole = getRole(LocalPlayer)
    local theirRole = getRole(player)
    if not myRole or not theirRole then return false end

    if theirRole == "Frozen" or theirRole == "OOF" or theirRole == "Alone" or theirRole == "Ashen" then
        return false
    end
    
    return theirRole ~= myRole
end

local function isMyTeam(player)
    local myRole = getRole(LocalPlayer)
    local theirRole = getRole(player)
    if not myRole or not theirRole then return false end
    

    if theirRole == "Frozen" or theirRole == "OOF" or theirRole == "Alone" then
        return false
    end
    
    -- Команда = такая же роль, как у меня
    return theirRole == myRole
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
    ["Ashen"] = Color3.fromRGB(80, 80, 80),
    ["Alone"] = Color3.fromRGB(200, 200, 200),
}

local function getRoleColor(role) return roleColors[role] or Color3.fromRGB(255, 255, 255) end

-- ============================================================
-- [[ VISUALIZER RING (Кольцо на земле) ]] --
-- ============================================================
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
-- [[ COSMETICS (из cosmetic.txt) ]] --
-- ============================================================
local currentTrail = nil
local currentOutfit = nil
local lastEquippedTrail = nil
local lastEquippedOutfit = nil

-- Данные из cosmetic.txt: display name -> model name
local TRAILS_DATA = {
    {display = "+", model = "+"},
    {display = "6 color", model = "Pride"},
    {display = "abro", model = "Pride"},
    {display = "ace", model = "Pride"},
    {display = "ac unit", model = "ACUnit"},
    {display = "ablaze", model = "Ablaze"},
    {display = "arithmetic", model = "Arithmetic"},
    {display = "arrow", model = "Arrow"},
    {display = "awesome human trail", model = "AwesomeHumanTrail"},
    {display = "basic", model = "Basic"},
    {display = "bi", model = "Pride"},
    {display = "bitwave", model = "BitWaves"},
    {display = "bonsai", model = "Bonsai"},
    {display = "box", model = "Box"},
    {display = "cape", model = "Cape"},
    {display = "celestial head", model = "CelestialHead"},
    {display = "cherry blossom", model = "CherryBlossom"},
    {display = "chocolate box", model = "HeartTrail"},
    {display = "circle", model = "Circle"},
    {display = "cloudy", model = "Cloudy"},
    {display = "comet", model = "Comet"},
    {display = "condiments", model = "Condiments"},
    {display = "dark gradient", model = "DarkGradient"},
    {display = "decorated tree", model = "Decorated Tree"},
    {display = "dracula walker", model = "draculawalker"},
    {display = "driftin", model = "Driftin"},
    {display = "encrypted", model = "Encrypted"},
    {display = "error", model = "Error"},
    {display = "flaming skull", model = "ghostrider"},
    {display = "fluid", model = "Pride"},
    {display = "freedom", model = "Freedom"},
    {display = "frostbite", model = "frostbite"},
    {display = "gilbert", model = "Pride"},
    {display = "gradient", model = "Gradient"},
    {display = "homing missile", model = "homingmissle"},
    {display = "ice skating", model = "IceSkates"},
    {display = "idea", model = "IdeaTrail"},
    {display = "illusions", model = "Illusions"},
    {display = "jet", model = "JetTrail"},
    {display = "kinetic", model = "Kinetic"},
    {display = "knight", model = "Knight"},
    {display = "light gradient", model = "LightGradient"},
    {display = "love power", model = "LovePower"},
    {display = "lovestruck", model = "Lovestruck"},
    {display = "m.l.m.", model = "Pride"},
    {display = "meteor fists", model = "MeteorFists"},
    {display = "n.b.", model = "Pride"},
    {display = "overfilled briefcase", model = "OverfilledBriefcase"},
    {display = "pan", model = "Pride"},
    {display = "pentagon", model = "PentagonTrail"},
    {display = "personal sun", model = "PersonalSun"},
    {display = "philly", model = "Pride"},
    {display = "polaris", model = "NorthStarTrail"},
    {display = "pride", model = "Pride"},
    {display = "radio head", model = "RadioHead"},
    {display = "rainbow comet", model = "RainbowComet"},
    {display = "real PNG", model = "RealPNG"},
    {display = "salt n' pepper", model = "SaltNPepper"},
    {display = "secret santa", model = "SecretSanta"},
    {display = "segmented", model = "Segmented"},
    {display = "snarp", model = "snarp"},
    {display = "snowflake power", model = "Snowflake Power"},
    {display = "snowflakes", model = "Snowflakes"},
    {display = "solid", model = "Solid"},
    {display = "sparkletime", model = "Sparkletime"},
    {display = "sparkling hands", model = "Sparklinghands"},
    {display = "speedcoil", model = "SpeedCoilTrail"},
    {display = "spellbook", model = "Spellbook"},
    {display = "star", model = "StarTrail"},
    {display = "star beam", model = "StarTrail2"},
    {display = "star power", model = "StarRoot"},
    {display = "stinky", model = "Stinky"},
    {display = "string lights", model = "StringLights"},
    {display = "subspace", model = "Subspace"},
    {display = "T", model = "T"},
    {display = "tachophobia", model = "Tachophobia"},
    {display = "tank knight", model = "TankKnight"},
    {display = "the trail", model = "GuppyTrail"},
    {display = "trail test", model = "GuppyTrail"},
    {display = "trans", model = "Pride"},
    {display = "triangle", model = "Triangle"},
    {display = "tron", model = "Tron"},
    {display = "tron 2", model = "Tron2"},
    {display = "V", model = "V"},
    {display = "vantablack", model = "Vantablack"},
    {display = "visualizer", model = "Visualizer"},
    {display = "w.l.w.", model = "Pride"},
    {display = "whirlpool", model = "WhirlPool"},
    {display = "X", model = "X"},
    {display = "yinyang", model = "YinYang"},
    {display = "zfight", model = "ZFight"},
}

-- Сортируем по алфавиту
table.sort(TRAILS_DATA, function(a, b) return a.display:lower() < b.display:lower() end)

local TRAIL_DISPLAY_NAMES = {}
for _, trail in ipairs(TRAILS_DATA) do
    table.insert(TRAIL_DISPLAY_NAMES, trail.display)
end

local function getTrailModel(displayName)
    for _, trail in ipairs(TRAILS_DATA) do
        if trail.display == displayName then
            return trail.model
        end
    end
    return displayName
end

-- Защита косметики от удаления игрой
local hookAvailable = (hookmetamethods ~= nil and getnamecallmethod ~= nil)

if hookAvailable then
    local oldNamecall
    oldNamecall = hookmetamethods(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Destroy" or method == "Remove" or method == "remove" then
            if currentTrail and (self == currentTrail or (typeof(self) == "Instance" and self:IsDescendantOf(currentTrail))) then
                return nil
            end
            if currentOutfit and (self == currentOutfit or (typeof(self) == "Instance" and self:IsDescendantOf(currentOutfit))) then
                return nil
            end
        end
        return oldNamecall(self, ...)
    end))
    print("[MoroLumina]: Hook защита косметики активна")
end

local function equipTrail(displayName)
    local char = LocalPlayer.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- Удаляем старый трейл
    if currentTrail and currentTrail.Parent then
        pcall(function() currentTrail:Destroy() end)
    end
    
    local trailsFolder = ReplicatedStorage:FindFirstChild("Trails")
    if not trailsFolder then return false end
    
    local modelName = getTrailModel(displayName)
    local model = trailsFolder:FindFirstChild(modelName)
    if not model then return false end
    
    currentTrail = model:Clone()
    currentTrail.Parent = char
    
    -- Настраиваем аттачменты
    local trailObj = currentTrail:FindFirstChildOfClass("Trail")
    if trailObj then
        local att0 = hrp:FindFirstChild("TrailAttachment0") or Instance.new("Attachment", hrp)
        att0.Name = "TrailAttachment0"
        att0.Position = Vector3.new(0, 1, 0)
        
        local att1 = hrp:FindFirstChild("TrailAttachment1") or Instance.new("Attachment", hrp)
        att1.Name = "TrailAttachment1"
        att1.Position = Vector3.new(0, -1, 0)
        
        trailObj.Attachment0 = att0
        trailObj.Attachment1 = att1
    end
    
    lastEquippedTrail = displayName
    return true
end

local function unequipTrail()
    if currentTrail and currentTrail.Parent then
        pcall(function() currentTrail:Destroy() end)
    end
    currentTrail = nil
    lastEquippedTrail = nil
end

local function equipOutfit(outfitName)
    local char = LocalPlayer.Character
    if not char then return false end
    
    if currentOutfit and currentOutfit.Parent then
        pcall(function() currentOutfit:Destroy() end)
    end
    
    local outfitsFolder = ReplicatedStorage:FindFirstChild("Outfits")
    if not outfitsFolder then return false end
    
    local model = outfitsFolder:FindFirstChild(outfitName)
    if not model then return false end
    
    currentOutfit = model:Clone()
    currentOutfit.Parent = char
    
    lastEquippedOutfit = outfitName
    return true
end

local function unequipOutfit()
    if currentOutfit and currentOutfit.Parent then
        pcall(function() currentOutfit:Destroy() end)
    end
    currentOutfit = nil
    lastEquippedOutfit = nil
end

-- Мониторинг: восстанавливаем косметику, если игра её удалила
task.spawn(function()
    while true do
        task.wait(0.3)
        
        if LocalPlayer.Character then
            -- Проверяем трейл
            if lastEquippedTrail and (not currentTrail or not currentTrail.Parent) then
                equipTrail(lastEquippedTrail)
            end
            
            -- Проверяем аутфит
            if lastEquippedOutfit and (not currentOutfit or not currentOutfit.Parent) then
                equipOutfit(lastEquippedOutfit)
            end
        end
    end
end)

-- Восстановление при спавне
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if lastEquippedTrail then
        equipTrail(lastEquippedTrail)
    end
    if lastEquippedOutfit then
        equipOutfit(lastEquippedOutfit)
    end
end)

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
    Callback = function(values)
        selectedCategories = values or {}
    end,
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

-- НОВЫЕ МНОЖИТЕЛИ
local rangeSec = combatTab:CreateSection({ Name = "Tag Range", Icon = "maximize" })
rangeSec:AddToggle({
    Name = "Range Booster", Icon = "maximize", Default = false,
    Callback = function(state)
        boosters.RangeMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.RangeMultiplier.base = roleObj:GetAttribute("RangeMultiplier") or 1 end
        end
        applyAllBoosts()
    end,
})
rangeSec:AddSlider({
    Name = "Range Multiplier", Icon = "trending-up", Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.RangeMultiplier.mult = v; applyAllBoosts() end,
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

-- ===================== ADVANCED TAB (НОВЫЕ МНОЖИТЕЛИ) =====================
local advancedTab = Window:CreateTab({ Name = "Advanced", Icon = "settings" })

advancedTab:Column("left")
local momentumSec = advancedTab:CreateSection({ Name = "Momentum", Icon = "activity" })
momentumSec:AddToggle({
    Name = "Momentum Booster", Icon = "activity", Default = false,
    Callback = function(state)
        boosters.MomentumMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.MomentumMultiplier.base = roleObj:GetAttribute("MomentumMultiplier") or 1 end
        end
        applyAllBoosts()
    end,
})
momentumSec:AddSlider({
    Name = "Momentum Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.MomentumMultiplier.mult = v; applyAllBoosts() end,
})

momentumSec:AddToggle({
    Name = "Momentum Decay Booster", Icon = "trending-down", Default = false,
    Callback = function(state)
        boosters.MomentumDecayMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.MomentumDecayMultiplier.base = roleObj:GetAttribute("MomentumDecayMultiplier") or 1 end
        end
        applyAllBoosts()
    end,
})
momentumSec:AddSlider({
    Name = "Decay Multiplier", Icon = "trending-down", Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.MomentumDecayMultiplier.mult = v; applyAllBoosts() end,
})

local frictionSec = advancedTab:CreateSection({ Name = "Friction", Icon = "wind" })
frictionSec:AddToggle({
    Name = "Friction Decay Booster", Icon = "wind", Default = false,
    Callback = function(state)
        boosters.FrictionDecayMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.FrictionDecayMultiplier.base = roleObj:GetAttribute("FrictionDecayMultiplier") or 1 end
        end
        applyAllBoosts()
    end,
})
frictionSec:AddSlider({
    Name = "Friction Multiplier", Icon = "wind", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.FrictionDecayMultiplier.mult = v; applyAllBoosts() end,
})

advancedTab:Column("right")
local specialSec = advancedTab:CreateSection({ Name = "Special", Icon = "zap" })
specialSec:AddToggle({
    Name = "Window Smash Booster", Icon = "box", Default = false,
    Callback = function(state)
        boosters.WindowSmashMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.WindowSmashMultiplier.base = roleObj:GetAttribute("WindowSmashMultiplier") or 1 end
        end
        applyAllBoosts()
    end,
})
specialSec:AddSlider({
    Name = "Window Multiplier", Icon = "box", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.WindowSmashMultiplier.mult = v; applyAllBoosts() end,
})

specialSec:AddToggle({
    Name = "Roll Boost Booster", Icon = "rotate-cw", Default = false,
    Callback = function(state)
        boosters.RollBoostMultiplier.enabled = state
        if state then
            local roleObj = LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
            if roleObj then boosters.RollBoostMultiplier.base = roleObj:GetAttribute("RollBoostMultiplier") or 1 end
        end
        applyAllBoosts()
    end,
})
specialSec:AddSlider({
    Name = "Roll Multiplier", Icon = "rotate-cw", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.RollBoostMultiplier.mult = v; applyAllBoosts() end,
})

-- ===================== COSMETICS TAB =====================
local cosmeticsTab = Window:CreateTab({ Name = "Cosmetics", Icon = "shirt" })

cosmeticsTab:Column("left")
local trailsSec = cosmeticsTab:CreateSection({ Name = "Trails", Icon = "zap" })

local trailDrop = trailsSec:AddDropdown({
    Name = "Select Trail",
    Icon = "layers",
    Options = TRAIL_DISPLAY_NAMES,
    Default = TRAIL_DISPLAY_NAMES[1],
})

trailsSec:AddButton({
    Name = "Equip Trail",
    Primary = true,
    Icon = "check",
    Callback = function()
        local selected = trailDrop.Get()
        if equipTrail(selected) then
            Window:Notify({
                Title = "Trail",
                Content = "Equipped: " .. selected,
                Type = "Success",
                Duration = 2
            })
        else
            Window:Notify({
                Title = "Trail",
                Content = "Failed to equip",
                Type = "Error",
                Duration = 2
            })
        end
    end,
})

trailsSec:AddButton({
    Name = "Unequip Trail",
    Icon = "x",
    Callback = function()
        unequipTrail()
        Window:Notify({
            Title = "Trail",
            Content = "Trail removed",
            Type = "Info",
            Duration = 2
        })
    end,
})

local trailNameBox = trailsSec:AddTextbox({
    Name = "Trail Name (exact)",
    Placeholder = "Enter model name",
})

trailsSec:AddButton({
    Name = "Equip by Name",
    Icon = "edit",
    Callback = function()
        local name = trailNameBox.Get()
        if name == "" then
            Window:Notify({
                Title = "Trail",
                Content = "Enter a name",
                Type = "Warning",
                Duration = 2
            })
            return
        end
        
        -- Ищем модель напрямую
        local char = LocalPlayer.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        if currentTrail and currentTrail.Parent then
            pcall(function() currentTrail:Destroy() end)
        end
        
        local trailsFolder = ReplicatedStorage:FindFirstChild("Trails")
        if not trailsFolder then return end
        
        local model = trailsFolder:FindFirstChild(name)
        if not model then
            Window:Notify({
                Title = "Trail",
                Content = "Model not found: " .. name,
                Type = "Error",
                Duration = 2
            })
            return
        end
        
        currentTrail = model:Clone()
        currentTrail.Parent = char
        
        local trailObj = currentTrail:FindFirstChildOfClass("Trail")
        if trailObj then
            local att0 = hrp:FindFirstChild("TrailAttachment0") or Instance.new("Attachment", hrp)
            att0.Name = "TrailAttachment0"
            att0.Position = Vector3.new(0, 1, 0)
            
            local att1 = hrp:FindFirstChild("TrailAttachment1") or Instance.new("Attachment", hrp)
            att1.Name = "TrailAttachment1"
            att1.Position = Vector3.new(0, -1, 0)
            
            trailObj.Attachment0 = att0
            trailObj.Attachment1 = att1
        end
        
        lastEquippedTrail = name
        Window:Notify({
            Title = "Trail",
            Content = "Equipped: " .. name,
            Type = "Success",
            Duration = 2
        })
    end,
})

cosmeticsTab:Column("right")
local outfitsSec = cosmeticsTab:CreateSection({ Name = "Outfits", Icon = "shirt" })

-- Сканируем аутфиты
local OUTFIT_NAMES = {}
local outfitsFolder = ReplicatedStorage:FindFirstChild("Outfits")
if outfitsFolder then
    for _, outfit in ipairs(outfitsFolder:GetChildren()) do
        table.insert(OUTFIT_NAMES, outfit.Name)
    end
    table.sort(OUTFIT_NAMES)
end

if #OUTFIT_NAMES == 0 then
    outfitsSec:AddLabel("No outfits found")
else
    local outfitDrop = outfitsSec:AddDropdown({
        Name = "Select Outfit",
        Icon = "layers",
        Options = OUTFIT_NAMES,
        Default = OUTFIT_NAMES[1],
    })
    
    outfitsSec:AddButton({
        Name = "Equip Outfit",
        Primary = true,
        Icon = "check",
        Callback = function()
            local selected = outfitDrop.Get()
            if equipOutfit(selected) then
                Window:Notify({
                    Title = "Outfit",
                    Content = "Equipped: " .. selected,
                    Type = "Success",
                    Duration = 2
                })
            else
                Window:Notify({
                    Title = "Outfit",
                    Content = "Failed to equip",
                    Type = "Error",
                    Duration = 2
                })
            end
        end,
    })
    
    outfitsSec:AddButton({
        Name = "Unequip Outfit",
        Icon = "x",
        Callback = function()
            unequipOutfit()
            Window:Notify({
                Title = "Outfit",
                Content = "Outfit removed",
                Type = "Info",
                Duration = 2
            })
        end,
    })
    
    local outfitNameBox = outfitsSec:AddTextbox({
        Name = "Outfit Name (exact)",
        Placeholder = "Enter outfit name",
    })
    
    outfitsSec:AddButton({
        Name = "Equip by Name",
        Icon = "edit",
        Callback = function()
            local name = outfitNameBox.Get()
            if name == "" then
                Window:Notify({
                    Title = "Outfit",
                    Content = "Enter a name",
                    Type = "Warning",
                    Duration = 2
                })
                return
            end
            
            if equipOutfit(name) then
                Window:Notify({
                    Title = "Outfit",
                    Content = "Equipped: " .. name,
                    Type = "Success",
                    Duration = 2
                })
            else
                Window:Notify({
                    Title = "Outfit",
                    Content = "Outfit not found: " .. name,
                    Type = "Error",
                    Duration = 2
                })
            end
        end,
    })
end

-- ===================== SETTINGS TAB =====================
Window:AddSettingsTab()

-- ============================================================
-- [[ MAIN LOOPS ]] --
-- ============================================================
RunService.Heartbeat:Connect(function()
    autoTagLoop()
    autoParryLoop()
    autoDodgeLoop()
    applyAllBoosts()
end)

RunService.RenderStepped:Connect(function()
    lookAtLoop()
    updateRing()
    
    if tracersEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            local show = false
            if hrp then
                if #selectedCategories == 0 then
                    show = false
                else
                    for _, category in ipairs(selectedCategories) do
                        if category == "Enemies" and isEnemy(player) then show = true break end
                        if category == "My Team" and isMyTeam(player) then show = true break end
                        if category == "OOF" and (isOOF(player) or isAshen(player) or isDead(player)) then show = true break end
                        if category == "Frozen" and isFrozen(player) then show = true break end
                    end
                end
            end
            
            if not show then
                if lines[player.Name] then
                    pcall(function() lines[player.Name].Visible = false end)
                end
                continue
            end
            
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
