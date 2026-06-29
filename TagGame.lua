local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 1. Полная таблица базового ускорения ролей (из твоего roles.txt)
local roleBaseAccelerations = {
    ["Runner"] = 1.0, -- Дефолт
    ["Tagger"] = 2.5,
    ["Infected"] = 0.4,
    ["PatientZero"] = 3.0,
    ["FastInfected"] = 0.2,
    ["BabyInfected"] = 0.6,
    ["JumpingInfected"] = 0.75,
    ["BigInfected"] = 0.75,
    ["CloakInfected"] = 0.5,
    ["Medic"] = 2.5,
    ["InfectedRunner"] = 0.75,
    ["pingus"] = 3.5,
    ["HiddenBeing"] = 2.5,
    ["Spectator"] = 2.0,
    ["Hider"] = 0.9,
    ["Seeker"] = 3.0,
    ["Overseer"] = 3.0,
    ["Bodyguard"] = 1.5,
    ["Assassin"] = 1.33,
    ["Target"] = 2.1,
    ["Bomb"] = 3.5,
    ["AshyBomb"] = 3.5,
    ["Nuke"] = 1.0,
    ["HotBomb"] = 2.0,
    ["Slasher"] = 1.5,
    ["HiddenSlasher"] = 0.85,
    ["Haunter"] = 0.9,
    ["FFATagger"] = 1.75,
    ["SlapFFATagger"] = 1.75,
    ["Crown"] = 3.0,
    ["Monarch"] = 3.0,
    ["Peasant"] = 1.75,
    ["Baron"] = 1.75,
    ["Knight"] = 1.5,
    ["Eliminator"] = 2.5,
    ["Juggernaut"] = 0.85,
    ["Hunter"] = 3.0,
    ["CompDyingTagger"] = 3.5,
    ["Freezer"] = 2.0,
    ["Chiller"] = 1.2,
    ["Arsonist"] = 1.25,
    ["Burning"] = 10.0,
    ["FunnyBomb"] = 20.0,
    ["SubspaceBomb"] = 3.5,
    ["RunnerTagger"] = 1.5,
    ["Toxic"] = 3.5
}

-- 2. Переменные состояния чита
local isUpdating = false
local isBoosterEnabled = false
local boostMultiplier = 1.0 -- Значение слайдера

local function getMyRole()
    local roleVal = LocalPlayer:FindFirstChild("PlayerRole")
    return roleVal and roleVal.Value or "Runner"
end

local function getBaseAcceleration()
    local role = getMyRole()
    return roleBaseAccelerations[role] or 1.0
end

-- 3. Функция применения буста (безопасная перезапись атрибута)
local function applyBuff()
    if isUpdating then return end
    
    local activeModifiers = LocalPlayer:FindFirstChild("ActiveModifiers")
    if not activeModifiers then return end

    local baseAccel = getBaseAcceleration()
    
    isUpdating = true
    if isBoosterEnabled then
        -- Умножаем базовое значение роли на наш буст
        activeModifiers:SetAttribute("AccelerationMultiplier", baseAccel * boostMultiplier)
    else
        -- Возвращаем к оригинальному значению
        activeModifiers:SetAttribute("AccelerationMultiplier", baseAccel)
    end
    isUpdating = false
end

-- 4. Загрузка интерфейса MoroLumina
local Lumina = loadstring(game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"))()

local Window = Lumina:CreateWindow({
    Title = "MoroLumina | Evade Menu", 
    ToggleKey = Enum.KeyCode.RightControl
})

-- Создаем вкладку и секцию
local moveTab = Window:CreateTab({ Name = "Movement", Icon = "zap" })
local accelSection = moveTab:CreateSection({ Name = "Acceleration" })

-- Лейбл, который мы будем менять
local defaultAccelLabel = accelSection:AddLabel("Default: " .. tostring(getBaseAcceleration()))

-- Функция для обновления текста лейбла
local function updateLabel()
    local base = getBaseAcceleration()
    defaultAccelLabel.Set("Default: " .. tostring(base))
end

-- Тоггл включения буста
accelSection:AddToggle({
    Name = "Acceleration Booster",
    Default = false,
    Callback = function(state)
        isBoosterEnabled = state
        applyBuff()
    end
})

-- Ползунок множителя (от 0.5 до 10)
accelSection:AddSlider({
    Name = "Boost Multiplier",
    Min = 0.5,
    Max = 10.0,
    Default = 1.0,
    Decimals = 1,
    Callback = function(value)
        boostMultiplier = value
        if isBoosterEnabled then
            applyBuff()
        end
    end
})

-- Добавляем стандартную вкладку настроек UI (встроенная в твою либу)
Window:AddSettingsTab()

-- 5. Обработчики событий (Следим за игрой)

-- Если роль меняется -> обновляем лейбл и пересчитываем буст
local function onRoleChanged()
    updateLabel()
    applyBuff()
end

-- Хукаем изменение роли
local currentRole = LocalPlayer:FindFirstChild("PlayerRole")
if currentRole then
    currentRole:GetPropertyChangedSignal("Value"):Connect(onRoleChanged)
end

-- Хукаем сброс атрибутов игрой
local activeMods = LocalPlayer:FindFirstChild("ActiveModifiers")
if activeMods then
    activeMods:GetAttributeChangedSignal("Acceleration"):Connect(function()
        -- Если атрибут поменялся (например, игра сбросила его), то восстанавливаем буст
        task.defer(applyBuff)
    end)
end

-- Если персонаж или роли пересоздаются
LocalPlayer.ChildAdded:Connect(function(child)
    if child.Name == "PlayerRole" then
        child:GetPropertyChangedSignal("Value"):Connect(onRoleChanged)
    elseif child.Name == "ActiveModifiers" then
        child:GetAttributeChangedSignal("Acceleration"):Connect(function()
            task.defer(applyBuff)
        end)
    end
end)

print("[MoroLumina]: Скрипт на ускорение успешно загружен.")

