local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================================
-- СПИСКИ РОЛЕЙ
-- ============================================================
local TAGGER_ROLES = {
    "Tagger", "Infected", "PatientZero", "FastInfected", "BabyInfected",
    "JumpingInfected", "BigInfected", "CloakInfected", "InfectedRunner",
    "Slasher", "HiddenSlasher", "Haunter", "FFATagger", "SlapFFATagger",
    "Seeker", "Overseer", "Assassin", "Eliminator", "Juggernaut", "Hunter",
    "Freezer", "Chiller", "Arsonist", "Toxic"
}

local function isTagger(player)
    local roleObj = player:FindFirstChild("PlayerRole")
    if roleObj then
        local role = roleObj.Value
        return table.find(TAGGER_ROLES, role) ~= nil
    end
    return false
end

local function getMyRole()
    local roleObj = LocalPlayer:FindFirstChild("PlayerRole")
    return roleObj and roleObj.Value or "Runner"
end

local function isSurvivor()
    local role = getMyRole()
    return not table.find(TAGGER_ROLES, role)
end

-- ============================================================
-- СОСТОЯНИЕ ФУНКЦИЙ
-- ============================================================
local autoTagEnabled = false
local autoTagRadius = 15
local autoTagSpeed = 0.1

local tagAuraEnabled = false
local tagAuraRadius = 8
local tagAuraSpeed = 0.15

local autoDodgeEnabled = false
local autoDodgeRadius = 20
local autoDodgeSpeed = 100
local autoDodgeJump = true

local lookAtEnabled = false
local lookAtTarget = nil
local lookAtSmooth = 0.1

local hitboxEnabled = false
local hitboxMultiplier = 1.5
local hitboxVisualize = false
local hitboxCache = {}

-- ============================================================
-- АВТО ТАГ (ULTRA RAGE)
-- ============================================================
local function autoTagLoop()
    if not autoTagEnabled then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Находим ближайшего игрока в радиусе
    local closest = nil
    local closestDist = autoTagRadius
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp then
                local dist = (targetHrp.Position - hrp.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = player
                end
            end
        end
    end
    
    if closest and closest.Character then
        local targetHrp = closest.Character:FindFirstChild("HumanoidRootPart")
        if targetHrp then
            -- Телепортируем к цели (очень близко)
            local offset = Vector3.new(0, 0, -3)
            hrp.CFrame = CFrame.new(targetHrp.Position + offset, targetHrp.Position)
            
            -- Поворачиваем камеру на цель
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHrp.Position)
            
            -- Симулируем клик
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(
                Camera.ViewportSize.X / 2,
                Camera.ViewportSize.Y / 2,
                0, true, game, 1
            )
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(
                Camera.ViewportSize.X / 2,
                Camera.ViewportSize.Y / 2,
                0, false, game, 1
            )
        end
    end
end

-- ============================================================
-- TAG AURA (LEGIT)
-- ============================================================
local auraCooldowns = {}

local function tagAuraLoop()
    if not tagAuraEnabled then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp then
                local dist = (targetHrp.Position - hrp.Position).Magnitude
                
                if dist <= tagAuraRadius then
                    local lastTag = auraCooldowns[player.UserId] or 0
                    if tick() - lastTag > 1 then
                        -- Плавно телепортируем к цели
                        local offset = Vector3.new(0, 0, -2)
                        local targetCFrame = CFrame.new(targetHrp.Position + offset, targetHrp.Position)
                        
                        -- Интерполяция для "легитности"
                        local currentCFrame = hrp.CFrame
                        local newPos = currentCFrame.Position:Lerp(targetCFrame.Position, tagAuraSpeed)
                        hrp.CFrame = CFrame.new(newPos, targetHrp.Position)
                        
                        -- Поворачиваем камеру
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHrp.Position)
                        
                        -- Клик
                        task.wait(0.03)
                        VirtualInputManager:SendMouseButtonEvent(
                            Camera.ViewportSize.X / 2,
                            Camera.ViewportSize.Y / 2,
                            0, true, game, 1
                        )
                        task.wait(0.02)
                        VirtualInputManager:SendMouseButtonEvent(
                            Camera.ViewportSize.X / 2,
                            Camera.ViewportSize.Y / 2,
                            0, false, game, 1
                        )
                        
                        auraCooldowns[player.UserId] = tick()
                    end
                end
            end
        end
    end
end

-- ============================================================
-- AUTO DODGE
-- ============================================================
local function autoDodgeLoop()
    if not autoDodgeEnabled then return end
    if not isSurvivor() then return end -- Работает только если мы выживший
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not (hrp and hum) then return end
    
    -- Ищем ближайшего тэггера
    local closestTagger = nil
    local closestDist = autoDodgeRadius
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isTagger(player) then
            local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp then
                local dist = (targetHrp.Position - hrp.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestTagger = player
                end
            end
        end
    end
    
    if closestTagger and closestTagger.Character then
        local taggerHrp = closestTagger.Character:FindFirstChild("HumanoidRootPart")
        if taggerHrp then
            -- Двигаемся в противоположном направлении
            local awayDir = (hrp.Position - taggerHrp.Position).Unit
            local targetPos = hrp.Position + awayDir * autoDodgeSpeed * RunService.Heartbeat:Wait()
            
            -- Отключаем коллизии на мгновение
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            
            hrp.CFrame = CFrame.new(targetPos, targetPos + awayDir)
            
            -- Прыжок для уклонения
            if autoDodgeJump and hrp.Velocity.Y < 1 then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end

-- ============================================================
-- LOOK AT PLAYER
-- ============================================================
local function lookAtLoop()
    if not lookAtEnabled or not lookAtTarget then return end
    
    local targetPlayer = Players:FindFirstChild(lookAtTarget)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end
    
    -- Плавный поворот камеры
    local currentCF = Camera.CFrame
    local targetCF = CFrame.new(currentCF.Position, targetHrp.Position)
    
    Camera.CFrame = currentCF:Lerp(targetCF, lookAtSmooth)
end

-- ============================================================
-- HITBOX EXPANDER
-- ============================================================
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
        -- Очищаем все хитбоксы
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
                
                -- Создаём хитбоксы для основных частей
                local partsToExpand = {
                    "Head", "UpperTorso", "LowerTorso",
                    "LeftUpperArm", "RightUpperArm",
                    "LeftLowerArm", "RightLowerArm",
                    "LeftUpperLeg", "RightUpperLeg",
                    "LeftLowerLeg", "RightLowerLeg"
                }
                
                for _, partName in ipairs(partsToExpand) do
                    local part = char:FindFirstChild(partName)
                    if part then
                        local hitbox = createHitboxPart(part, hitboxMultiplier)
                        hitboxCache[char][part] = hitbox
                    end
                end
            else
                -- Обновляем размеры и прозрачность
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
// ГЛАВНЫЕ ЦИКЛЫ
-- ============================================================
RunService.Heartbeat:Connect(function()
    autoTagLoop()
    tagAuraLoop()
    autoDodgeLoop()
    updateHitboxes()
end)

RunService.RenderStepped:Connect(function()
    lookAtLoop()
end)

-- ============================================================
// UI INTEGRATION (добавь это в свой существующий скрипт)
-- ============================================================
-- В Combat Tab добавь:

local autoTagSec = CombatTab:CreateSection({ Name = "Auto Tag", Icon = "crosshair" })

autoTagSec:AddToggle({
    Name = "Auto Tag (Ultra Rage)",
    Icon = "zap",
    Default = false,
    Callback = function(state)
        autoTagEnabled = state
    end,
})

autoTagSec:AddSlider({
    Name = "Tag Radius",
    Icon = "maximize",
    Min = 5, Max = 30, Default = 15, Decimals = 0,
    Callback = function(val)
        autoTagRadius = val
    end,
})

autoTagSec:AddSlider({
    Name = "Tag Speed",
    Icon = "activity",
    Min = 0.05, Max = 0.5, Default = 0.1, Decimals = 2,
    Callback = function(val)
        autoTagSpeed = val
    end,
})

local auraSec = CombatTab:CreateSection({ Name = "Tag Aura", Icon = "target" })

auraSec:AddToggle({
    Name = "Tag Aura (Legit)",
    Icon = "circle",
    Default = false,
    Callback = function(state)
        tagAuraEnabled = state
        auraCooldowns = {}
    end,
})

auraSec:AddSlider({
    Name = "Aura Radius",
    Icon = "maximize",
    Min = 3, Max = 20, Default = 8, Decimals = 0,
    Callback = function(val)
        tagAuraRadius = val
    end,
})

auraSec:AddSlider({
    Name = "Aura Smoothness",
    Icon = "activity",
    Min = 0.05, Max = 0.5, Default = 0.15, Decimals = 2,
    Callback = function(val)
        tagAuraSpeed = val
    end,
})

local dodgeSec = CombatTab:CreateSection({ Name = "Auto Dodge", Icon = "shield" })

dodgeSec:AddToggle({
    Name = "Auto Dodge",
    Icon = "shield",
    Default = false,
    Callback = function(state)
        autoDodgeEnabled = state
    end,
})

dodgeSec:AddSlider({
    Name = "Dodge Radius",
    Icon = "maximize",
    Min = 10, Max = 40, Default = 20, Decimals = 0,
    Callback = function(val)
        autoDodgeRadius = val
    end,
})

dodgeSec:AddSlider({
    Name = "Dodge Speed",
    Icon = "activity",
    Min = 50, Max = 200, Default = 100, Decimals = 0,
    Callback = function(val)
        autoDodgeSpeed = val
    end,
})

dodgeSec:AddToggle({
    Name = "Jump on Dodge",
    Icon = "arrow-up",
    Default = true,
    Callback = function(state)
        autoDodgeJump = state
    end,
})

local lookSec = CombatTab:CreateSection({ Name = "Look At Player", Icon = "eye" })

lookSec:AddToggle({
    Name = "Enable Look At",
    Icon = "eye",
    Default = false,
    Callback = function(state)
        lookAtEnabled = state
    end,
})

local targetDrop = lookSec:AddDropdown({
    Name = "Select Target",
    Icon = "user",
    Options = {},
    Callback = function(val)
        lookAtTarget = val
    end,
})

lookSec:AddButton({
    Name = "Refresh Players",
    Icon = "refresh-cw",
    Callback = function()
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        targetDrop.Refresh(names, true)
    end,
})

lookSec:AddSlider({
    Name = "Look Smoothness",
    Icon = "activity",
    Min = 0.01, Max = 0.5, Default = 0.1, Decimals = 2,
    Callback = function(val)
        lookAtSmooth = val
    end,
})

local hitboxSec = CombatTab:CreateSection({ Name = "Hitbox Expander", Icon = "box" })

hitboxSec:AddToggle({
    Name = "Enable Hitbox Expander",
    Icon = "box",
    Default = false,
    Callback = function(state)
        hitboxEnabled = state
    end,
})

hitboxSec:AddSlider({
    Name = "Hitbox Size",
    Icon = "maximize",
    Min = 1.0, Max = 3.0, Default = 1.5, Decimals = 1,
    Callback = function(val)
        hitboxMultiplier = val
    end,
})

hitboxSec:AddToggle({
    Name = "Visualize Hitboxes",
    Icon = "eye",
    Default = false,
    Callback = function(state)
        hitboxVisualize = state
    end,
})
