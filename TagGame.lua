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
-- [[ ПЕРЕМЕННЫЕ КОСМЕТИКИ (динамические) ]] --
-- ============================================================
local fakeCosmeticEnabled = true
local selectedCosmeticCategory = "Trails"
local selectedCosmeticModel = "Box"
local currentFakeCosmetics = currentFakeCosmetics or {} -- category -> model instance
local cosmeticsInstalled = cosmeticsInstalled or {}     -- category -> bool
local lastEquipped = lastEquipped or {}                 -- category -> itemName

-- ============================================================
-- [[ ЗАЩИТА КОСМЕТИКИ ОТ УДАЛЕНИЯ ИГРОЙ ]] --
-- ============================================================
local hookAvailable = (hookmetamethods ~= nil and getnamecallmethod ~= nil)

if hookAvailable then
    local oldNamecall
    oldNamecall = hookmetamethods(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        if method == "Destroy" or method == "Remove" or method == "remove" then
            for cat, instance in pairs(currentFakeCosmetics) do
                if instance and (self == instance or (self.Parent and self:IsDescendantOf(instance))) then
                    return nil
                end
            end
        end
        
        return oldNamecall(self, ...)
    end)
    print("[MoroLumina]: Hook защита косметики активирована")
else
    print("[MoroLumina]: hookmetamethods недоступен, используем мониторинг")
end

-- ============================================================
-- [[ МАППИНГ ИМЕН ПРЕДМЕТОВ К ИМЕНАМ МОДЕЛЕЙ В ИГРЕ ]] --
-- ============================================================
-- Списки предметов (Trails - полный список, Outfits - динамически)
local ITEMS_BY_CATEGORY = {
    Trails = {
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
    },
    Outfits = {}, -- Будет заполнено динамически
}

local CATEGORY_KEYS = {"Trails", "Outfits"}

-- Функция для сканирования доступных аутфитов
local function scanOutfits()
    local outfits = {}
    
    -- Пробуем разные варианты папок
    local possibleFolders = {
        "Outfits", "Outfit", "outfits", "outfit",
        "CharacterOutfits", "PlayerOutfits"
    }
    
    for _, folderName in ipairs(possibleFolders) do
        local folder = ReplicatedStorage:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                table.insert(outfits, child.Name)
            end
            break
        end
    end
    
    -- Если не нашли в ReplicatedStorage, пробуем ReplicatedFirst.content
    if #outfits == 0 then
        local content = ReplicatedFirst:FindFirstChild("content")
        if content then
            for _, folderName in ipairs(possibleFolders) do
                local folder = content:FindFirstChild(folderName)
                if folder then
                    for _, child in ipairs(folder:GetChildren()) do
                        table.insert(outfits, child.Name)
                    end
                    break
                end
            end
        end
    end
    
    return outfits
end

-- Заполняем Outfits при старте
ITEMS_BY_CATEGORY.Outfits = scanOutfits()

-- Возвращает имя модели для предмета в заданной категории
local function getModelName(category, itemName)
    local map = MODEL_NAME_MAP[category]
    if map and map[itemName] then
        return map[itemName]
    end
    -- Если нет в маппинге — пробуем имя как есть
    return itemName
end

-- Ищет папку с моделями для категории в ReplicatedStorage
local function getModelsFolder(category)
    -- Пробуем разные варианты названий папок
    local possibleNames = {
        category,                              -- "Trails"
        category:sub(1, -2),                   -- "Trail" (без s)
        category .. "Folder",                  -- "TrailsFolder"
        category:lower(),                      -- "trails"
    }
    
    for _, name in ipairs(possibleNames) do
        local folder = ReplicatedStorage:FindFirstChild(name)
        if folder then return folder end
    end
    
    -- Если нет в ReplicatedStorage, пробуем ReplicatedFirst.content
    local content = ReplicatedFirst:FindFirstChild("content")
    if content then
        for _, name in ipairs(possibleNames) do
            local folder = content:FindFirstChild(name)
            if folder then return folder end
        end
    end
    
    return nil
end

-- ============================================================
-- [[ ФУНКЦИИ ЭКИПИРОВКИ/СНЯТИЯ КОСМЕТИКИ ]] --
-- ============================================================
local function unequipCosmetic(category)
    local instance = currentFakeCosmetics[category]
    if instance then
        pcall(function() instance:Destroy() end)
        currentFakeCosmetics[category] = nil
        cosmeticsInstalled[category] = false
    end
    
    -- Удаляем атрибут с персонажа
    local char = LocalPlayer.Character
    if char then
        local attrName = "Equipped" .. category
        pcall(function() char:SetAttribute(attrName, nil) end)
    end
    
    print("[MoroLumina]: Снята косметика категории " .. category)
end

local function equipCosmeticVisual(category, itemName)
    local char = LocalPlayer.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- Снимаем старую косметику этой категории
    unequipCosmetic(category)
    
    if not fakeCosmeticEnabled then return false end
    
    local folder = getModelsFolder(category)
    if not folder then
        warn("[MoroLumina]: Папка для категории " .. category .. " не найдена")
        return false
    end
    
    local modelName = getModelName(category, itemName)
    local originalModel = folder:FindFirstChild(modelName)
    
    if not originalModel then
        -- Пробуем найти по другим вариантам
        for _, child in ipairs(folder:GetChildren()) do
            if child.Name:lower() == modelName:lower() then
                originalModel = child
                break
            end
        end
    end
    
    if not originalModel then
        warn("[MoroLumina]: Модель '" .. modelName .. "' не найдена в папке " .. category)
        return false
    end
    
    -- Клонируем модель
    local cloned = originalModel:Clone()
    cloned.Parent = char
    currentFakeCosmetics[category] = cloned
    cosmeticsInstalled[category] = true
    
    -- Специальная логика для трейлов: настраиваем Attachment'ы
    if category == "Trails" then
        local trailComponent = cloned:FindFirstChildOfClass("Trail") or cloned
        if trailComponent and trailComponent:IsA("Trail") then
            local att0 = hrp:FindFirstChild("MoroTrailAtt0") or Instance.new("Attachment", hrp)
            att0.Name = "MoroTrailAtt0"
            att0.Position = Vector3.new(0, 1, 0)
            
            local att1 = hrp:FindFirstChild("MoroTrailAtt1") or Instance.new("Attachment", hrp)
            att1.Name = "MoroTrailAtt1"
            att1.Position = Vector3.new(0, -1, 0)
            
            trailComponent.Attachment0 = att0
            trailComponent.Attachment1 = att1
        end
    end
    
    -- Устанавливаем атрибут на персонаже (чтобы другие скрипты знали)
    pcall(function()
        char:SetAttribute("Equipped" .. category, itemName)
    end)
    
    print("[MoroLumina]: Экипирован " .. itemName .. " (" .. category .. ")")
    return true
end

-- ============================================================
-- [[ ПОСТОЯННАЯ ПРОВЕРКА: если игра удалила косметику — возвращаем ]] --
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.1)
        
        if fakeCosmeticEnabled and LocalPlayer.Character then
            -- Проверяем каждую категорию, которая была экипирована
            if lastEquipped and type(lastEquipped) == "table" then
                for category, itemName in pairs(lastEquipped) do
                    local instance = currentFakeCosmetics and currentFakeCosmetics[category]
                    
                    -- Если экипировка пропала — восстанавливаем именно то, что было экипировано
                    if not instance or not instance.Parent then
                        print("[MoroLumina]: Восстанавливаем " .. tostring(category) .. " -> " .. tostring(itemName))
                        if equipCosmeticVisual then
                            pcall(equipCosmeticVisual, category, itemName)
                        end
                    elseif not hookAvailable then
                        -- Дополнительная защита: если hook недоступен, проверяем видимость
                        pcall(function()
                            for _, descendant in ipairs(instance:GetDescendants()) do
                                if descendant:IsA("Trail") or descendant:IsA("ParticleEmitter") then
                                    descendant.Enabled = true
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- [[ ХУКАЕМ СПАВН ПЕРСОНАЖА ]] --
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function(character)
    cosmeticsInstalled = {}
    currentFakeCosmetics = {}
    task.wait(1.5)
    
    -- Восстанавливаем экипированную косметику
    if lastEquipped and type(lastEquipped) == "table" then
        for category, itemName in pairs(lastEquipped) do
            if equipCosmeticVisual then
                pcall(equipCosmeticVisual, category, itemName)
            end
        end
    end
end)

if LocalPlayer.Character then
    task.defer(function()
        task.wait(1.5)
        for category, itemName in pairs(lastEquipped) do
            equipCosmeticVisual(category, itemName)
        end
    end)
end

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
-- [[ AUTO-TAG (KILL AURA) - БЕЗ ПРОВЕРКИ НА СТЕНЫ ]] --
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
            
            if myRole == "Crown" and (targetRole == "Peasant" or targetRole == "Knight") then continue end
            if myRole == "Chiller" and targetRole == "Frozen" then continue end
            if myRole == "Runner" and targetRole == "Chiller" then continue end
            
            if myRole ~= "Alone" then
                if myRole and targetRole and myRole == targetRole then continue end
            end
            
            if targetRole and IGNORED_ROLES[targetRole] then continue end
            
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

-- Функции категорий
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

local function isEnemy(player)
    if isOOF(player) or isFrozen(player) then return false end
    local myRole = LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value
    local theirRole = player:FindFirstChild("PlayerRole") and player.PlayerRole.Value
    if not myRole or not theirRole then return false end
    return myRole ~= theirRole or myRole == "Alone"
end

local function isMyTeam(player)
    if isOOF(player) or isFrozen(player) then return false end
    local myRole = LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value
    local theirRole = player:FindFirstChild("PlayerRole") and player.PlayerRole.Value
    if not myRole or not theirRole then return false end
    return myRole == theirRole and myRole ~= "Alone" and myRole ~= "OOF"
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

-- ===================== COSMETICS TAB =====================
local cosmeticsTab = Window:CreateTab({ Name = "Cosmetics", Icon = "shirt" })

-- Только Trails и Outfits
local ITEMS_BY_CATEGORY = {
    Trails = {
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
    },
    Outfits = {"Classic", "Warrior", "Mage", "Assassin", "Knight"},
}

local CATEGORY_KEYS = {"Trails", "Outfits"}

-- Переменные для отслеживания выбора
local selectedCategoryKey = "Trails"
local selectedItemName = "Box"

cosmeticsTab:Column("left")
local equipSec = cosmeticsTab:CreateSection({ Name = "Equip Cosmetic", Icon = "shirt" })

-- Dropdown категории
local cosmeticCategoryDrop = equipSec:AddDropdown({
    Name = "Category",
    Icon = "layers",
    Options = CATEGORY_KEYS,
    Default = "Trails",
    Callback = function(val)
        selectedCategoryKey = val
        -- Обновляем опции в dropdown предметов
        local newItems = ITEMS_BY_CATEGORY[val] or {}
        if itemDrop then
            itemDrop.Refresh(newItems, false) -- false = не сохранять выбор
            -- Устанавливаем первый предмет как выбранный
            if newItems[1] then
                selectedItemName = newItems[1]
            end
        end
    end,
})

-- Dropdown предметов (динамически обновляется)
local itemDrop = equipSec:AddDropdown({
    Name = "Item",
    Icon = "box",
    Options = ITEMS_BY_CATEGORY["Trails"],
    Default = "Box",
    Callback = function(val)
        selectedItemName = val  -- ВАЖНО: обновляем при выборе
    end,
})

-- Кнопка Equip
equipSec:AddButton({
    Name = "Equip Selected",
    Primary = true,
    Icon = "check",
    Callback = function()
        if not selectedItemName or not selectedCategoryKey then
            Window:Notify({ Title = "Cosmetics", Content = "Select category and item", Type = "Warning" })
            return
        end
        
        -- ВАЖНО: передаем именно selectedItemName, а не hardcoded значение
        local success = equipCosmeticVisual(selectedCategoryKey, selectedItemName)
        if success then
            lastEquipped[selectedCategoryKey] = selectedItemName
            Window:Notify({
                Title = "Cosmetics",
                Content = "Equipped " .. selectedItemName .. " (" .. selectedCategoryKey .. ")",
                Type = "Success",
                Duration = 3
            })
        else
            Window:Notify({
                Title = "Cosmetics",
                Content = "Failed to equip. Model not found in game files.",
                Type = "Error",
                Duration = 4
            })
        end
    end,
})

-- Кнопка UNEQUIP
equipSec:AddButton({
    Name = "Unequip Selected Category",
    Icon = "x",
    Callback = function()
        if not selectedCategoryKey then return end
        unequipCosmetic(selectedCategoryKey)
        lastEquipped[selectedCategoryKey] = nil
        Window:Notify({
            Title = "Cosmetics",
            Content = "Unequipped " .. selectedCategoryKey,
            Type = "Info",
            Duration = 2
        })
    end,
})

-- Кнопка UNEQUIP ALL
equipSec:AddButton({
    Name = "Unequip ALL Cosmetics",
    Icon = "trash",
    Callback = function()
        for category, _ in pairs(currentFakeCosmetics) do
            unequipCosmetic(category)
        end
        lastEquipped = {}
        Window:Notify({
            Title = "Cosmetics",
            Content = "All cosmetics unequipped",
            Type = "Info",
            Duration = 2
        })
    end,
})

-- Инфо
equipSec:AddLabel("Currently equipped:")
for _, cat in ipairs(CATEGORY_KEYS) do
    equipSec:AddLabel("  • " .. cat .. ": " .. tostring(lastEquipped[cat] or "None"))
end

-- ===================== ПРАВАЯ КОЛОНКА: Inventory =====================
cosmeticsTab:Column("right")
local invSec = cosmeticsTab:CreateSection({ Name = "Inventory Management", Icon = "box" })

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

local function addCosmetic(category, itemName)
    local data = getInventory()
    if not data or not data.Owned then return false end
    if not data.Owned[category] then data.Owned[category] = {} end
    
    for _, item in ipairs(data.Owned[category]) do
        if item == itemName then return true end
    end
    
    table.insert(data.Owned[category], itemName)
    return setInventory(data)
end

invSec:AddButton({
    Name = "Add ALL Trails to Inventory",
    Primary = true,
    Icon = "zap",
    Callback = function()
        local count = 0
        for _, trail in ipairs(ITEMS_BY_CATEGORY.Trails) do
            if addCosmetic("Trails", trail) then count = count + 1 end
        end
        Window:Notify({
            Title = "Inventory",
            Content = "Added " .. count .. " trails",
            Type = "Success",
            Duration = 4
        })
    end,
})

invSec:AddButton({
    Name = "Clear Inventory",
    Icon = "trash",
    Callback = function()
        local data = getInventory()
        if data and data.Owned then
            for cat, _ in pairs(data.Owned) do
                data.Owned[cat] = {}
            end
            setInventory(data)
            Window:Notify({ Title = "Inventory", Content = "Inventory cleared", Type = "Info" })
        end
    end,
})

-- Быстрая экипировка по имени
local quickNameBox = invSec:AddTextbox({
    Name = "Quick Equip Name",
    Placeholder = "Enter exact model name",
})

invSec:AddButton({
    Name = "Quick Equip (by name)",
    Icon = "zap",
    Callback = function()
        local name = quickNameBox.Get()
        if not name or name == "" then
            Window:Notify({ Title = "Cosmetics", Content = "Enter a name", Type = "Warning" })
            return
        end
        
        local success = equipCosmeticVisual(selectedCategoryKey, name)
        if success then
            lastEquipped[selectedCategoryKey] = name
            Window:Notify({
                Title = "Cosmetics",
                Content = "Equipped " .. name,
                Type = "Success"
            })
        else
            Window:Notify({
                Title = "Cosmetics",
                Content = "Model '" .. name .. "' not found",
                Type = "Error"
            })
        end
    end,
})

invSec:AddButton({
    Name = "Detect Available Models",
    Icon = "search",
    Callback = function()
        local found = {}
        for _, cat in ipairs(CATEGORY_KEYS) do
            local folder = getModelsFolder(cat)
            if folder then
                local models = {}
                for _, child in ipairs(folder:GetChildren()) do
                    table.insert(models, child.Name)
                end
                table.insert(found, cat .. ": " .. #models .. " models")
                print("[MoroDetect] " .. cat .. " folder: " .. folder:GetFullName())
                for _, m in ipairs(models) do
                    print("  - " .. m)
                end
            else
                table.insert(found, cat .. ": NOT FOUND")
            end
        end
        
        local msg = table.concat(found, "\n")
        print("[MoroDetect] Summary:\n" .. msg)
        Window:Notify({
            Title = "Detect",
            Content = "Check console (F9) for detailed info",
            Type = "Info",
            Duration = 5
        })
    end,
})

invSec:AddButton({
    Name = "Rescan Outfits",
    Icon = "refresh-cw",
    Callback = function()
        local newOutfits = scanOutfits()
        ITEMS_BY_CATEGORY.Outfits = newOutfits
        
        -- Обновляем dropdown предметов, если выбрана категория Outfits
        if selectedCategoryKey == "Outfits" and itemDrop then
            itemDrop.Refresh(newOutfits, false)
            if newOutfits[1] then
                selectedItemName = newOutfits[1]
            end
        end
        
        Window:Notify({
            Title = "Outfits",
            Content = "Found " .. #newOutfits .. " outfits",
            Type = "Success",
            Duration = 3
        })
        
        -- Выводим в консоль для отладки
        print("[MoroLumina] Available outfits:")
        for _, outfit in ipairs(newOutfits) do
            print("  - " .. outfit)
        end
    end,
})

-- ============================================================
-- [[ SETTINGS TAB ]] --
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
                for _, category in ipairs(selectedCategories) do
                    if category == "Enemies" and isEnemy(player) then show = true break end
                    if category == "My Team" and isMyTeam(player) then show = true break end
                    if category == "OOF" and isOOF(player) then show = true break end
                    if category == "Frozen" and isFrozen(player) then show = true break end
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
