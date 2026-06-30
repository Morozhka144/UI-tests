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
    "Freezer", "Chiller", "Arsonist", "Toxic", "RunnerTagger"
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
-- ЦВЕТА ДЛЯ ТРЕЙСЕРОВ
-- ============================================================
local roleColors = {
    ["Crown"] = Color3.fromRGB(255, 215, 0), ["Monarch"] = Color3.fromRGB(255, 215, 0),
    ["Tagger"] = Color3.fromRGB(255, 0, 0), ["RunnerTagger"] = Color3.fromRGB(255, 0, 0),
    ["Infected"] = Color3.fromRGB(50, 205, 50), ["PatientZero"] = Color3.fromRGB(50, 205, 50),
    ["Bomb"] = Color3.fromRGB(255, 140, 0), ["SubspaceBomb"] = Color3.fromRGB(255, 140, 0),
    ["Slasher"] = Color3.fromRGB(75, 0, 130), ["HiddenSlasher"] = Color3.fromRGB(75, 0, 130),
    ["Knight"] = Color3.fromRGB(169, 169, 169), ["Bodyguard"] = Color3.fromRGB(169, 169, 169),
    ["Peasant"] = Color3.fromRGB(139, 69, 19), ["Baron"] = Color3.fromRGB(139, 69, 19),
    ["Freezer"] = Color3.fromRGB(0, 206, 209), ["Chiller"] = Color3.fromRGB(0, 206, 209),
    ["Arsonist"] = Color3.fromRGB(255, 69, 0), ["Burning"] = Color3.fromRGB(255, 69, 0),
    ["Toxic"] = Color3.fromRGB(126, 255, 5),
}
local function getRoleColor(role)
    return roleColors[role] or Color3.fromRGB(255, 255, 255)
end

-- ============================================================
-- БАЗОВЫЕ ЗНАЧЕНИЯ АТРИБУТОВ
-- ============================================================
local baseAttributes = {
    ["AccelerationMultiplier"] = 3,
    ["RunSpeedMultiplier"]     = 1.01,
    ["JumpPowerMultiplier"]    = 1.25,
    ["SizeMultiplier"]         = 1.15,
    ["HeadSizeMultiplier"]     = 1,
    ["TagCooldown"]            = 0.666,
    ["TagPlayerKnockback"]     = 0.75,
}

local boosters = {}
for attr, base in pairs(baseAttributes) do
    boosters[attr] = { enabled = false, mult = 1.0 }
end

-- ============================================================
-- СОСТОЯНИЕ НОВЫХ ФУНКЦИЙ
-- ============================================================
local autoTagEnabled = false
local autoTagRadius = 15
local autoTagCooldown = 0.3
local autoTagLastTime = 0

local tagAuraEnabled = false
local tagAuraRadius = 8
local tagAuraSmoothness = 0.15
local auraCooldowns = {}

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

-- Трейсеры
local tracersEnabled = false
local selectedRoles = {}
local lines = {}

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================
local function getRoleAttrObj()
    return LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
end

local function applyAllBoosts()
    local roleObj = getRoleAttrObj()
    if not roleObj then return end
    for attr, data in pairs(boosters) do
        local base = baseAttributes[attr]
        local targetVal = data.enabled and (base * data.mult) or base
        roleObj:SetAttribute(attr, targetVal)
    end
end

-- ============================================================
-- АВТО ТАГ (ULTRA RAGE)
-- ============================================================
local function autoTagLoop()
    if not autoTagEnabled then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if tick() - autoTagLastTime < autoTagCooldown then return end
    
    -- Находим ближайшего игрока в радиусе
    local closest, closestDist = nil, autoTagRadius
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
            local offset = Vector3.new(0, 0, -3)
            hrp.CFrame = CFrame.new(targetHrp.Position + offset, targetHrp.Position)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHrp.Position)
            
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(
                Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2,
                0, true, game, 1
            )
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(
                Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2,
                0, false, game, 1
            )
            
            autoTagLastTime = tick()
        end
    end
end

-- ============================================================
-- TAG AURA (LEGIT)
-- ============================================================
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
                        local offset = Vector3.new(0, 0, -2)
                        local targetCFrame = CFrame.new(targetHrp.Position + offset, targetHrp.Position)
                        
                        local currentCFrame = hrp.CFrame
                        local newPos = currentCFrame.Position:Lerp(targetCFrame.Position, tagAuraSmoothness)
                        hrp.CFrame = CFrame.new(newPos, targetHrp.Position)
                        
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHrp.Position)
                        
                        task.wait(0.03)
                        VirtualInputManager:SendMouseButtonEvent(
                            Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2,
                            0, true, game, 1
                        )
                        task.wait(0.02)
                        VirtualInputManager:SendMouseButtonEvent(
                            Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2,
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
    if not isSurvivor() then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not (hrp and hum) then return end
    
    local closestTagger, closestDist = nil, autoDodgeRadius
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
            local awayDir = (hrp.Position - taggerHrp.Position).Unit
            local targetPos = hrp.Position + awayDir * autoDodgeSpeed * RunService.Heartbeat:Wait()
            
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            
            hrp.CFrame = CFrame.new(targetPos, targetPos + awayDir)
            
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
-- UI
-- ============================================================
local Lumina = loadstring(game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"))()
local Window = Lumina:CreateWindow({ Title = "MoroLumina | Evade" })

-- ===================== MOVEMENT TAB =====================
local moveTab = Window:CreateTab({ Name = "Movement", Icon = "move" })

-- Левая колонка
moveTab:Column("left")

local accelSec = moveTab:CreateSection({ Name = "Acceleration", Icon = "zap" })
accelSec:AddLabel("Base: " .. tostring(baseAttributes.AccelerationMultiplier))
accelSec:AddToggle({
    Name = "Acceleration Booster", Icon = "zap", Default = false,
    Callback = function(state) boosters.AccelerationMultiplier.enabled = state; applyAllBoosts() end,
})
accelSec:AddSlider({
    Name = "Accel Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 20.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.AccelerationMultiplier.mult = v
        if boosters.AccelerationMultiplier.enabled then applyAllBoosts() end
    end,
})

local runSec = moveTab:CreateSection({ Name = "Run Speed", Icon = "activity" })
runSec:AddLabel("Base: " .. tostring(baseAttributes.RunSpeedMultiplier))
runSec:AddToggle({
    Name = "Run Speed Booster", Icon = "activity", Default = false,
    Callback = function(state) boosters.RunSpeedMultiplier.enabled = state; applyAllBoosts() end,
})
runSec:AddSlider({
    Name = "Run Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.RunSpeedMultiplier.mult = v
        if boosters.RunSpeedMultiplier.enabled then applyAllBoosts() end
    end,
})

-- Правая колонка
moveTab:Column("right")

local jumpSec = moveTab:CreateSection({ Name = "Jump Power", Icon = "arrow-up" })
jumpSec:AddLabel("Base: " .. tostring(baseAttributes.JumpPowerMultiplier))
jumpSec:AddToggle({
    Name = "Jump Power Booster", Icon = "arrow-up", Default = false,
    Callback = function(state) boosters.JumpPowerMultiplier.enabled = state; applyAllBoosts() end,
})
jumpSec:AddSlider({
    Name = "Jump Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.JumpPowerMultiplier.mult = v
        if boosters.JumpPowerMultiplier.enabled then applyAllBoosts() end
    end,
})

-- ===================== VISUALS TAB =====================
local visualsTab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })

-- Левая колонка
visualsTab:Column("left")

local sizeSec = visualsTab:CreateSection({ Name = "Body Size", Icon = "maximize" })
sizeSec:AddLabel("Base: " .. tostring(baseAttributes.SizeMultiplier))
sizeSec:AddToggle({
    Name = "Size Booster", Icon = "maximize", Default = false,
    Callback = function(state) boosters.SizeMultiplier.enabled = state; applyAllBoosts() end,
})
sizeSec:AddSlider({
    Name = "Size Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.SizeMultiplier.mult = v
        if boosters.SizeMultiplier.enabled then applyAllBoosts() end
    end,
})

local headSec = visualsTab:CreateSection({ Name = "Head Size", Icon = "circle" })
headSec:AddLabel("Base: " .. tostring(baseAttributes.HeadSizeMultiplier))
headSec:AddToggle({
    Name = "Head Size Booster", Icon = "circle", Default = false,
    Callback = function(state) boosters.HeadSizeMultiplier.enabled = state; applyAllBoosts() end,
})
headSec:AddSlider({
    Name = "Head Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.HeadSizeMultiplier.mult = v
        if boosters.HeadSizeMultiplier.enabled then applyAllBoosts() end
    end,
})

-- Правая колонка — трейсеры
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

local roleList = {
    "Runner", "Tagger", "Infected", "PatientZero", "FastInfected", "BabyInfected",
    "JumpingInfected", "BigInfected", "CloakInfected", "Medic", "InfectedRunner",
    "pingus", "HiddenBeing", "Spectator", "Hider", "Seeker", "Overseer", "Bodyguard",
    "Assassin", "Target", "Bomb", "AshyBomb", "Nuke", "HotBomb", "Slasher",
    "HiddenSlasher", "Haunter", "FFATagger", "SlapFFATagger", "Crown", "Monarch",
    "Peasant", "Baron", "Knight", "Eliminator", "Juggernaut", "Hunter", "Freezer",
    "Chiller", "Arsonist", "Burning", "FunnyBomb", "SubspaceBomb", "RunnerTagger", "Toxic"
}

local roleDropdown = tracerSec:AddMultiDropdown({
    Name = "Select Roles", Icon = "users",
    Options = roleList, Default = {},
    Callback = function(values) selectedRoles = values end,
})

-- Кнопки "Выбрать все" / "Отменить все"
tracerSec:AddButton({
    Name = "Select All", Icon = "check-square",
    Callback = function() roleDropdown.SelectAll() end,
})
tracerSec:AddButton({
    Name = "Clear All", Icon = "x-square",
    Callback = function() roleDropdown.ClearAll() end,
})

-- ===================== COMBAT TAB =====================
local combatTab = Window:CreateTab({ Name = "Combat", Icon = "crosshair" })

-- Левая колонка — атрибуты
combatTab:Column("left")

local tagCdSec = combatTab:CreateSection({ Name = "Tag Cooldown", Icon = "clock" })
tagCdSec:AddLabel("Base: " .. tostring(baseAttributes.TagCooldown))
tagCdSec:AddToggle({
    Name = "Tag Cooldown Booster", Icon = "clock", Default = false,
    Callback = function(state) boosters.TagCooldown.enabled = state; applyAllBoosts() end,
})
tagCdSec:AddSlider({
    Name = "Cooldown Multiplier", Icon = "trending-up",
    Min = 0.01, Max = 5.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.TagCooldown.mult = v
        if boosters.TagCooldown.enabled then applyAllBoosts() end
    end,
})

local tagKbSec = combatTab:CreateSection({ Name = "Tag Knockback", Icon = "wind" })
tagKbSec:AddLabel("Base: " .. tostring(baseAttributes.TagPlayerKnockback))
tagKbSec:AddToggle({
    Name = "Tag Knockback Booster", Icon = "wind", Default = false,
    Callback = function(state) boosters.TagPlayerKnockback.enabled = state; applyAllBoosts() end,
})
tagKbSec:AddSlider({
    Name = "Knockback Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.TagPlayerKnockback.mult = v
        if boosters.TagPlayerKnockback.enabled then applyAllBoosts() end
    end,
})

-- Правая колонка — новые функции
combatTab:Column("right")

-- Auto Tag
local autoTagSec = combatTab:CreateSection({ Name = "Auto Tag", Icon = "zap" })
autoTagSec:AddToggle({
    Name = "Auto Tag (Ultra Rage)", Icon = "zap", Default = false,
    Callback = function(state) autoTagEnabled = state end,
})
autoTagSec:AddSlider({
    Name = "Tag Radius", Icon = "maximize",
    Min = 5, Max = 30, Default = 15, Decimals = 0,
    Callback = function(val) autoTagRadius = val end,
})
autoTagSec:AddSlider({
    Name = "Tag Cooldown", Icon = "clock",
    Min = 0.1, Max = 2.0, Default = 0.3, Decimals = 2,
    Callback = function(val) autoTagCooldown = val end,
})

-- Tag Aura
local auraSec = combatTab:CreateSection({ Name = "Tag Aura", Icon = "target" })
auraSec:AddToggle({
    Name = "Tag Aura (Legit)", Icon = "circle", Default = false,
    Callback = function(state)
        tagAuraEnabled = state
        auraCooldowns = {}
    end,
})
auraSec:AddSlider({
    Name = "Aura Radius", Icon = "maximize",
    Min = 3, Max = 20, Default = 8, Decimals = 0,
    Callback = function(val) tagAuraRadius = val end,
})
auraSec:AddSlider({
    Name = "Aura Smoothness", Icon = "activity",
    Min = 0.05, Max = 0.5, Default = 0.15, Decimals = 2,
    Callback = function(val) tagAuraSmoothness = val end,
})

-- Auto Dodge
local dodgeSec = combatTab:CreateSection({ Name = "Auto Dodge", Icon = "shield" })
dodgeSec:AddToggle({
    Name = "Auto Dodge", Icon = "shield", Default = false,
    Callback = function(state) autoDodgeEnabled = state end,
})
dodgeSec:AddSlider({
    Name = "Dodge Radius", Icon = "maximize",
    Min = 10, Max = 40, Default = 20, Decimals = 0,
    Callback = function(val) autoDodgeRadius = val end,
})
dodgeSec:AddSlider({
    Name = "Dodge Speed", Icon = "activity",
    Min = 50, Max = 200, Default = 100, Decimals = 0,
    Callback = function(val) autoDodgeSpeed = val end,
})
dodgeSec:AddToggle({
    Name = "Jump on Dodge", Icon = "arrow-up", Default = true,
    Callback = function(state) autoDodgeJump = state end,
})

-- Look At Player
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

lookSec:AddSlider({
    Name = "Look Smoothness", Icon = "activity",
    Min = 0.01, Max = 0.5, Default = 0.1, Decimals = 2,
    Callback = function(val) lookAtSmooth = val end,
})

-- Hitbox Expander
local hitboxSec = combatTab:CreateSection({ Name = "Hitbox Expander", Icon = "box" })
hitboxSec:AddToggle({
    Name = "Enable Hitbox", Icon = "box", Default = false,
    Callback = function(state) hitboxEnabled = state end,
})
hitboxSec:AddSlider({
    Name = "Hitbox Size", Icon = "maximize",
    Min = 1.0, Max = 3.0, Default = 1.5, Decimals = 1,
    Callback = function(val) hitboxMultiplier = val end,
})
hitboxSec:AddToggle({
    Name = "Visualize Hitboxes", Icon = "eye", Default = false,
    Callback = function(state) hitboxVisualize = state end,
})

-- ============================================================
-- ОБНОВЛЕНИЕ ПРИ СМЕНЕ РОЛИ
-- ============================================================
local roleObj = LocalPlayer:FindFirstChild("PlayerRole")
if roleObj then
    roleObj:GetPropertyChangedSignal("Value"):Connect(function()
        applyAllBoosts()
    end)
end

-- ============================================================
-- ГЛАВНЫЕ ЦИКЛЫ
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
-- РЕНДЕР ТРЕЙСЕРОВ С ЦВЕТАМИ
-- ============================================================
RunService.RenderStepped:Connect(function()
    if not tracersEnabled then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Character then continue end

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

        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        local pRoleObj = player:FindFirstChild("PlayerRole")
        local pRole = pRoleObj and pRoleObj.Value

        local show = hrp and table.find(selectedRoles, pRole)
        if show then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                lines[player.Name].From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                lines[player.Name].To = Vector2.new(pos.X, pos.Y)
                lines[player.Name].Color = getRoleColor(pRole)
                lines[player.Name].Visible = true
            else
                lines[player.Name].Visible = false
            end
        else
            lines[player.Name].Visible = false
        end
    end
end)
