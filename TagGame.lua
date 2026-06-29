local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 1. Таблица базовых множителей из твоего roles.txt
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

-- Переменные
local isBoosterEnabled = false
local boostMultiplier = 1.0

-- Путь к роли
local function getRoleObj()
    return LocalPlayer:FindFirstChild("Modifiers") and LocalPlayer.Modifiers:FindFirstChild("Role")
end

local function getBaseAcceleration()
    local roleObj = getRoleObj()
    local roleName = roleObj and roleObj.Value or "Runner"
    return roleBaseAccelerations[roleName] or 1.0
end

local function applyBoost()
    local roleObj = getRoleObj()
    if not roleObj then return end
    
    local base = getBaseAcceleration()
    if roleObj:GetAttribute("AccelerationMultiplier") == nil then
        roleObj:SetAttribute("AccelerationMultiplier", base)
    end
    
    if isBoosterEnabled then
        roleObj:SetAttribute("AccelerationMultiplier", base * boostMultiplier)
    else
        roleObj:SetAttribute("AccelerationMultiplier", base)
    end
end


-- Инициализация UI
local Lumina = loadstring(game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"))()

local Window = Lumina:CreateWindow({ Title = "MoroLumina | Movement" })
local moveTab = Window:CreateTab({ Name = "Movement" })
local accelSection = moveTab:CreateSection({ Name = "Acceleration" })

-- Лейбл
local defaultAccelLabel = accelSection:AddLabel("Default: " .. tostring(getBaseAcceleration()))

-- Тоггл
accelSection:AddToggle({
    Name = "Acceleration Booster",
    Default = false,
    Callback = function(state)
        isBoosterEnabled = state
        applyBoost()
    end
})

-- Слайдер
accelSection:AddSlider({
    Name = "Boost Multiplier",
    Min = 0.5,
    Max = 10.0,
    Default = 1.0,
    Decimals = 1,
    Callback = function(value)
        boostMultiplier = value
        if isBoosterEnabled then applyBoost() end
    end
})

-- Обновление при смене роли
local function refresh()
    defaultAccelLabel.Set("Default: " .. tostring(getBaseAcceleration()))
    applyBoost()
end

local roleObj = getRoleObj()
if roleObj then
    roleObj:GetPropertyChangedSignal("Value"):Connect(refresh)
    roleObj:GetAttributeChangedSignal("AccelerationMultiplier"):Connect(function()
        -- Если игра меняет атрибут, принудительно переприменяем наш буст
        if isBoosterEnabled then task.defer(applyBoost) end
    end)
end

print("[MoroLumina]: Скрипт активен, путь исправлен на Modifiers.Role")
