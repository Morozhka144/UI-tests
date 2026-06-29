local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- 1. Таблица базовых множителей ускорения
local roleBaseAccelerations = {
    ["Runner"] = 1.0, ["Tagger"] = 2.5, ["Infected"] = 0.4, ["PatientZero"] = 3.0,
    ["FastInfected"] = 0.2, ["BabyInfected"] = 0.6, ["JumpingInfected"] = 0.75,
    ["BigInfected"] = 0.75, ["CloakInfected"] = 0.5, ["Medic"] = 2.5,
    ["InfectedRunner"] = 0.75, ["pingus"] = 3.5, ["HiddenBeing"] = 2.5,
    ["Spectator"] = 2.0, ["Hider"] = 0.9, ["Seeker"] = 3.0, ["Overseer"] = 3.0,
    ["Bodyguard"] = 1.5, ["Assassin"] = 1.33, ["Target"] = 2.1, ["Bomb"] = 3.5,
    ["AshyBomb"] = 3.5, ["Nuke"] = 1.0, ["HotBomb"] = 2.0, ["Slasher"] = 1.5,
    ["HiddenSlasher"] = 0.85, ["Haunter"] = 0.9, ["FFATagger"] = 1.75,
    ["SlapFFATagger"] = 1.75, ["Crown"] = 3.0, ["Monarch"] = 3.0,
    ["Peasant"] = 1.75, ["Baron"] = 1.75, ["Knight"] = 1.5, ["Eliminator"] = 2.5,
    ["Juggernaut"] = 0.85, ["Hunter"] = 3.0, ["Freezer"] = 2.0, ["Chiller"] = 1.2,
    ["Arsonist"] = 1.25, ["Burning"] = 10.0, ["FunnyBomb"] = 20.0,
    ["SubspaceBomb"] = 3.5, ["RunnerTagger"] = 1.5, ["Toxic"] = 3.5
}

-- Переменные состояния
local isBoosterEnabled = false
local boostMultiplier = 1.0
local tracersEnabled = false
local selectedRoles = {}
local lines = {}

-- Вспомогательные функции пути
local function getRoleName()
    return LocalPlayer:FindFirstChild("PlayerRole") and LocalPlayer.PlayerRole.Value or "Runner"
end

local function getRoleAttrObj()
    return LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
end

-- Логика ускорения
local function applyBoost()
    local roleObj = getRoleAttrObj()
    if not roleObj then return end
    
    local base = roleBaseAccelerations[getRoleName()] or 1.0
    local targetVal = isBoosterEnabled and (base * boostMultiplier) or base
    
    roleObj:SetAttribute("AccelerationMultiplier", targetVal)
end

-- Инициализация UI
local Lumina = loadstring(game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"))()
local Window = Lumina:CreateWindow({ Title = "MoroLumina | Evade" })

-- Вкладка Movement
local moveTab = Window:CreateTab({ Name = "Movement" })
local accelSection = moveTab:CreateSection({ Name = "Acceleration" })

local defaultAccelLabel = accelSection:AddLabel("Default: " .. tostring(roleBaseAccelerations[getRoleName()] or 1.0))

accelSection:AddToggle({
    Name = "Acceleration Booster",
    Default = false,
    Callback = function(state)
        isBoosterEnabled = state
        applyBoost()
    end
})

accelSection:AddSlider({
    Name = "Boost Multiplier",
    Min = 0.5, Max = 10.0, Default = 1.0, Decimals = 1,
    Callback = function(value)
        boostMultiplier = value
        if isBoosterEnabled then applyBoost() end
    end
})

-- Вкладка Visuals
local visualsTab = Window:CreateTab({ Name = "Visuals" })
local visSection = visualsTab:CreateSection({ Name = "Tracers" })

visSection:AddToggle({
    Name = "Enable Tracers",
    Default = false,
    Callback = function(state)
        tracersEnabled = state
        if not state then for _, l in pairs(lines) do l.Visible = false end end
    end
})

visSection:AddMultiDropdown({
    Name = "Select Roles",
    Options = {unpack(table.clone(table.keys(roleBaseAccelerations)))}, -- Взятие всех ключей
    Default = {},
    Callback = function(values) selectedRoles = values end
})

-- Обновление UI и логики
LocalPlayer:FindFirstChild("PlayerRole"):GetPropertyChangedSignal("Value"):Connect(function()
    defaultAccelLabel:Set("Default: " .. tostring(roleBaseAccelerations[getRoleName()] or 1.0))
    applyBoost()
end)

-- Рендер трейсеров
RunService.RenderStepped:Connect(function()
    if not tracersEnabled then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Character then continue end
        
        if not lines[player.Name] then
            local l = Drawing.new("Line")
            l.Thickness = 1.5; l.Color = Color3.new(1,1,1); lines[player.Name] = l
        end
        
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        local pRole = player:FindFirstChild("PlayerRole") and player.PlayerRole.Value
        
        local show = hrp and table.find(selectedRoles, pRole)
        if show then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                lines[player.Name].From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                lines[player.Name].To = Vector2.new(pos.X, pos.Y)
                lines[player.Name].Visible = true
            else lines[player.Name].Visible = false end
        else lines[player.Name].Visible = false end
    end
end)

