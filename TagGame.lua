local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================================
-- ЦВЕТА ДЛЯ ТРЕЙСЕРОВ ПО РОЛЯМ
-- ============================================================
local roleColors = {
    -- Золотые (королевские)
    ["Crown"] = Color3.fromRGB(255, 215, 0),
    ["Monarch"] = Color3.fromRGB(255, 215, 0),
    
    -- Красные (таггеры)
    ["Tagger"] = Color3.fromRGB(255, 0, 0),
    ["RunnerTagger"] = Color3.fromRGB(255, 0, 0),
    
    -- Зелёные (заражённые)
    ["Infected"] = Color3.fromRGB(50, 205, 50),
    ["PatientZero"] = Color3.fromRGB(50, 205, 50),
    
    -- Оранжевые (бомбы)
    ["Bomb"] = Color3.fromRGB(255, 140, 0),
    ["SubspaceBomb"] = Color3.fromRGB(255, 140, 0),
    
    -- Индиго (слэшеры)
    ["Slasher"] = Color3.fromRGB(75, 0, 130),
    ["HiddenSlasher"] = Color3.fromRGB(75, 0, 130),
    
    -- Серые (рыцари/телохранители)
    ["Knight"] = Color3.fromRGB(169, 169, 169),
    ["Bodyguard"] = Color3.fromRGB(169, 169, 169),
    
    -- Коричневые (крестьяне)
    ["Peasant"] = Color3.fromRGB(139, 69, 19),
    ["Baron"] = Color3.fromRGB(139, 69, 19),
    
    -- Бирюзовые (замораживатели)
    ["Freezer"] = Color3.fromRGB(0, 206, 209),
    ["Chiller"] = Color3.fromRGB(0, 206, 209),
    
    -- Оранжево-красные (поджигатели)
    ["Arsonist"] = Color3.fromRGB(255, 69, 0),
    ["Burning"] = Color3.fromRGB(255, 69, 0),
    
    -- Лаймовый (токсичный)
    ["Toxic"] = Color3.fromRGB(126, 255, 5),
}

-- Функция получения цвета для роли
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

-- ============================================================
-- СОСТОЯНИЕ БУСТЕРОВ
-- ============================================================
local boosters = {}
for attr, base in pairs(baseAttributes) do
    boosters[attr] = {
        enabled = false,
        mult    = 1.0,
    }
end

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
-- UI
-- ============================================================
local Lumina = loadstring(game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"))()
local Window = Lumina:CreateWindow({ Title = "MoroLumina | Evade" })

-- ===================== MOVEMENT TAB =====================
local moveTab = Window:CreateTab({ Name = "Movement", Icon = "move" })

-- Acceleration
local accelSec = moveTab:CreateSection({ Name = "Acceleration", Icon = "zap" })
accelSec:AddLabel("Base: " .. tostring(baseAttributes.AccelerationMultiplier))
accelSec:AddToggle({
    Name = "Acceleration Booster",
    Icon = "zap",
    Default = false,
    Callback = function(state)
        boosters.AccelerationMultiplier.enabled = state
        applyAllBoosts()
    end,
})
accelSec:AddSlider({
    Name = "Accel Multiplier",
    Icon = "trending-up",
    Min = 0.1, Max = 20.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.AccelerationMultiplier.mult = v
        if boosters.AccelerationMultiplier.enabled then applyAllBoosts() end
    end,
})

-- Run Speed
local runSec = moveTab:CreateSection({ Name = "Run Speed", Icon = "activity" })
runSec:AddLabel("Base: " .. tostring(baseAttributes.RunSpeedMultiplier))
runSec:AddToggle({
    Name = "Run Speed Booster",
    Icon = "activity",
    Default = false,
    Callback = function(state)
        boosters.RunSpeedMultiplier.enabled = state
        applyAllBoosts()
    end,
})
runSec:AddSlider({
    Name = "Run Multiplier",
    Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.RunSpeedMultiplier.mult = v
        if boosters.RunSpeedMultiplier.enabled then applyAllBoosts() end
    end,
})

-- Jump Power
local jumpSec = moveTab:CreateSection({ Name = "Jump Power", Icon = "arrow-up" })
jumpSec:AddLabel("Base: " .. tostring(baseAttributes.JumpPowerMultiplier))
jumpSec:AddToggle({
    Name = "Jump Power Booster",
    Icon = "arrow-up",
    Default = false,
    Callback = function(state)
        boosters.JumpPowerMultiplier.enabled = state
        applyAllBoosts()
    end,
})
jumpSec:AddSlider({
    Name = "Jump Multiplier",
    Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.JumpPowerMultiplier.mult = v
        if boosters.JumpPowerMultiplier.enabled then applyAllBoosts() end
    end,
})

-- ===================== VISUALS TAB =====================
local visualsTab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })

-- Size
local sizeSec = visualsTab:CreateSection({ Name = "Body Size", Icon = "maximize" })
sizeSec:AddLabel("Base: " .. tostring(baseAttributes.SizeMultiplier))
sizeSec:AddToggle({
    Name = "Size Booster",
    Icon = "maximize",
    Default = false,
    Callback = function(state)
        boosters.SizeMultiplier.enabled = state
        applyAllBoosts()
    end,
})
sizeSec:AddSlider({
    Name = "Size Multiplier",
    Icon = "trending-up",
    Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.SizeMultiplier.mult = v
        if boosters.SizeMultiplier.enabled then applyAllBoosts() end
    end,
})

-- Head Size
local headSec = visualsTab:CreateSection({ Name = "Head Size", Icon = "circle" })
headSec:AddLabel("Base: " .. tostring(baseAttributes.HeadSizeMultiplier))
headSec:AddToggle({
    Name = "Head Size Booster",
    Icon = "circle",
    Default = false,
    Callback = function(state)
        boosters.HeadSizeMultiplier.enabled = state
        applyAllBoosts()
    end,
})
headSec:AddSlider({
    Name = "Head Multiplier",
    Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.HeadSizeMultiplier.mult = v
        if boosters.HeadSizeMultiplier.enabled then applyAllBoosts() end
    end,
})

-- Трейсеры
local tracerSec = visualsTab:CreateSection({ Name = "Tracers", Icon = "crosshair" })
tracerSec:AddToggle({
    Name = "Enable Tracers",
    Icon = "crosshair",
    Default = false,
    Callback = function(state)
        tracersEnabled = state
        if not state then
            for _, l in pairs(lines) do 
                if l and l.Visible ~= nil then l.Visible = false end
            end
        end
    end,
})

-- Список ролей для трейсеров
local roleList = {
    "Runner", "Tagger", "Infected", "PatientZero", "FastInfected", "BabyInfected",
    "JumpingInfected", "BigInfected", "CloakInfected", "Medic", "InfectedRunner",
    "pingus", "HiddenBeing", "Spectator", "Hider", "Seeker", "Overseer", "Bodyguard",
    "Assassin", "Target", "Bomb", "AshyBomb", "Nuke", "HotBomb", "Slasher",
    "HiddenSlasher", "Haunter", "FFATagger", "SlapFFATagger", "Crown", "Monarch",
    "Peasant", "Baron", "Knight", "Eliminator", "Juggernaut", "Hunter", "Freezer",
    "Chiller", "Arsonist", "Burning", "FunnyBomb", "SubspaceBomb", "RunnerTagger", "Toxic"
}

tracerSec:AddMultiDropdown({
    Name = "Select Roles",
    Icon = "users",
    Options = roleList,
    Default = {},
    Callback = function(values) selectedRoles = values end,
})

-- ===================== COMBAT TAB =====================
local combatTab = Window:CreateTab({ Name = "Combat", Icon = "crosshair" })

-- Tag Cooldown
local tagCdSec = combatTab:CreateSection({ Name = "Tag Cooldown", Icon = "clock" })
tagCdSec:AddLabel("Base: " .. tostring(baseAttributes.TagCooldown))
tagCdSec:AddToggle({
    Name = "Tag Cooldown Booster",
    Icon = "clock",
    Default = false,
    Callback = function(state)
        boosters.TagCooldown.enabled = state
        applyAllBoosts()
    end,
})
tagCdSec:AddSlider({
    Name = "Cooldown Multiplier",
    Icon = "trending-up",
    Min = 0.01, Max = 5.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.TagCooldown.mult = v
        if boosters.TagCooldown.enabled then applyAllBoosts() end
    end,
})

-- Tag Knockback
local tagKbSec = combatTab:CreateSection({ Name = "Tag Knockback", Icon = "wind" })
tagKbSec:AddLabel("Base: " .. tostring(baseAttributes.TagPlayerKnockback))
tagKbSec:AddToggle({
    Name = "Tag Knockback Booster",
    Icon = "wind",
    Default = false,
    Callback = function(state)
        boosters.TagPlayerKnockback.enabled = state
        applyAllBoosts()
    end,
})
tagKbSec:AddSlider({
    Name = "Knockback Multiplier",
    Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v)
        boosters.TagPlayerKnockback.mult = v
        if boosters.TagPlayerKnockback.enabled then applyAllBoosts() end
    end,
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
-- РЕНДЕР ТРЕЙСЕРОВ С ЦВЕТАМИ
-- ============================================================
RunService.RenderStepped:Connect(function()
    if not tracersEnabled then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Character then continue end

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

        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        local pRoleObj = player:FindFirstChild("PlayerRole")
        local pRole = pRoleObj and pRoleObj.Value

        local show = hrp and table.find(selectedRoles, pRole)
        if show then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                lines[player.Name].From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                lines[player.Name].To = Vector2.new(pos.X, pos.Y)
                lines[player.Name].Color = getRoleColor(pRole) -- Устанавливаем цвет по роли
                lines[player.Name].Visible = true
            else
                lines[player.Name].Visible = false
            end
        else
            lines[player.Name].Visible = false
        end
    end
end)
