-- [[ Services & Modules ]] --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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

-- [[ Global Settings for UI ]] --
_G.AutoTagEnabled = false
_G.AutoParryEnabled = false
_G.KillAuraRange = 15
_G.AutoParryRange = 12

-- [[ Helpers ]] --
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
-- [[ ATTRIBUTE BOOSTERS (Anti-Reset Logic) ]] --
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
        if data.enabled then
            local targetVal = data.base * data.mult
            -- Принудительно выставляем каждый кадр, чтобы игра не сбросила при смене роли
            if roleObj:GetAttribute(attr) ~= targetVal then
                roleObj:SetAttribute(attr, targetVal)
            end
        end
    end
end

-- ============================================================
-- [[ AUTO-TAG (KILL AURA) ]] --
-- ============================================================
local function autoTagLoop()
    if not _G.AutoTagEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    
    local closestTarget, closestDist = nil, _G.KillAuraRange
    
    for _, char in ipairs(CollectionService:GetTagged("TaggablePlayer")) do
        if char ~= LocalPlayer.Character and char:FindFirstChild("HumanoidRootPart") then
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
                
                pcall(function() TagPlayerEvent:InvokeServer(buf) end)
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
    
    -- Жесткий лок камеры на цель каждый кадр
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
-- [[ TRACERS ]] --
-- ============================================================
local tracersEnabled = false
local selectedRoles = {}
local lines = {}

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
local function getRoleColor(role) return roleColors[role] or Color3.fromRGB(255, 255, 255) end

-- ============================================================
-- [[ UI INITIALIZATION ]] --
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
    Name = "Accel Multiplier", Icon = "trending-up", Min = 0.1, Max = 20.0, Default = 1.0, Decimals = 2,
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
    Name = "Run Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
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
    Name = "Head Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2,
    Callback = function(v) boosters.HeadSizeMultiplier.mult = v; applyAllBoosts() end,
})

visualsTab:Column("right")
local tracerSec = visualsTab:CreateSection({ Name = "Tracers", Icon = "crosshair" })
tracerSec:AddToggle({
    Name = "Enable Tracers", Icon = "crosshair", Default = false,
    Callback = function(state)
        tracersEnabled = state
        if not state then for _, l in pairs(lines) do if l and l.Visible ~= nil then l.Visible = false end end end
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
    Name = "Select Roles", Icon = "users", Options = roleList, Default = {},
    Callback = function(values) selectedRoles = values end,
})

tracerSec:AddButton({ Name = "Select All", Icon = "check-square", Callback = function() roleDropdown.SelectAll() end })
tracerSec:AddButton({ Name = "Clear All", Icon = "x-square", Callback = function() roleDropdown.ClearAll() end })

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
    Name = "Cooldown Multiplier", Icon = "trending-up", Min = 0.01, Max = 5.0, Default = 1.0, Decimals = 2,
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
-- Auto Tag
local autoTagSec = combatTab:CreateSection({ Name = "Auto Tag", Icon = "zap" })
autoTagSec:AddToggle({
    Name = "Auto Tag (Kill Aura)", Icon = "zap", Default = false,
    Callback = function(state) _G.AutoTagEnabled = state end,
})
autoTagSec:AddSlider({
    Name = "Tag Radius", Icon = "maximize", Min = 5, Max = 30, Default = 15, Decimals = 0,
    Callback = function(val) _G.KillAuraRange = val end,
})

-- Auto Parry
local autoParrySec = combatTab:CreateSection({ Name = "Auto Parry", Icon = "shield" })
autoParrySec:AddToggle({
    Name = "Auto Parry", Icon = "shield", Default = false,
    Callback = function(state) _G.AutoParryEnabled = state end,
})
autoParrySec:AddSlider({
    Name = "Parry Radius", Icon = "maximize", Min = 5, Max = 25, Default = 12, Decimals = 0,
    Callback = function(val) _G.AutoParryRange = val end,
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

-- Hitbox Expander
local hitboxSec = combatTab:CreateSection({ Name = "Hitbox Expander", Icon = "box" })
hitboxSec:AddToggle({
    Name = "Enable Hitbox", Icon = "box", Default = false,
    Callback = function(state) hitboxEnabled = state end,
})
hitboxSec:AddSlider({
    Name = "Hitbox Size", Icon = "maximize", Min = 1.0, Max = 3.0, Default = 1.5, Decimals = 1,
    Callback = function(val) hitboxMultiplier = val end,
})
hitboxSec:AddToggle({
    Name = "Visualize Hitboxes", Icon = "eye", Default = false,
    Callback = function(state) hitboxVisualize = state end,
})

-- ============================================================
-- [[ MAIN LOOPS ]] --
-- ============================================================
RunService.Heartbeat:Connect(function()
    autoTagLoop()
    autoParryLoop()
    applyAllBoosts() -- Гарантируем, что множители не сбросятся
    updateHitboxes()
end)

RunService.RenderStepped:Connect(function()
    lookAtLoop()
    
    -- Tracers Render
    if tracersEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer or not player.Character then continue end

            if not lines[player.Name] then
                local success, line = pcall(function()
                    local l = Drawing.new("Line")
                    l.Thickness = 1.5
                    l.Color = Color3.new(1, 1, 1)
                    return l
                end)
                if success and line then lines[player.Name] = line else continue end
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
    end
end)
