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

-- [[ Global Settings ]] --
_G.AutoTagEnabled = false
_G.AutoParryEnabled = false
_G.KillAuraRange = 15
_G.AutoParryRange = 12
_G.ShowKillAuraRing = true

_G.LegitTagEnabled = false
_G.LegitTagRange = 12
_G.LegitTagFOV = 0.6

_G.GodTagEnabled = false

-- [[ Helpers ]] --
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getModifiersRole()
    local modifiers = LocalPlayer:FindFirstChild("Modifiers")
    return modifiers and modifiers:FindFirstChild("Role")
end

local function getRole(player)
    local roleObj = player:FindFirstChild("PlayerRole")
    return roleObj and roleObj.Value
end

-- ============================================================
-- [[ ATTRIBUTE BOOSTERS ]] --
-- ============================================================
local baseAttributes = {
    AccelerationMultiplier = 3,
    RunSpeedMultiplier = 1.01,
    JumpPowerMultiplier = 1.25,
    SizeMultiplier = 1.15,
    HeadSizeMultiplier = 1,
    TagCooldown = 0.666,
    TagPlayerKnockback = 0.75,
    RangeMultiplier = 1,
    MomentumMultiplier = 1,
    MomentumDecayMultiplier = 1,
    FrictionDecayMultiplier = 1,
    WindowSmashMultiplier = 1,
    RollBoostMultiplier = 1,
}

local boosters = {}
for attr, defaultBase in pairs(baseAttributes) do
    boosters[attr] = { enabled = false, mult = 1.0, base = defaultBase }
end

local function applyAllBoosts()
    if not shared or not shared.multipliers then return end
    local m = shared.multipliers

    -- разблокировать таг всегда
    m.DisableTagging = false

    -- Парринг
    m.EnableParrying = _G.AutoParryEnabled and true or false

    -- Кулдаун тага (base 0.666; мельче = быстрее)
    if boosters.TagCooldown.enabled then
        m.TagCooldown = 0.666 / boosters.TagCooldown.mult
    else
        m.TagCooldown = 0.666
    end

    -- Дальность
    m.RangeMultiplier = boosters.RangeMultiplier.enabled and boosters.RangeMultiplier.mult or 1
    -- GOD TAG
    if _G.GodTagEnabled then
        m.RangeMultiplier = math.max(m.RangeMultiplier, 12)
        m.TagRayNumber = 40
        m.TagRayRows = 4
        m.TagRaySpread = 8
    end
end

-- Хелпер для тоглов бустеров (убирает дублирование)
local function makeBoostToggle(attr)
    return function(state)
        boosters[attr].enabled = state
        if state then
            local roleObj = getModifiersRole()
            if roleObj then
                boosters[attr].base = roleObj:GetAttribute(attr) or baseAttributes[attr]
            end
        end
        applyAllBoosts()
    end
end

local function makeBoostSlider(attr)
    return function(v) boosters[attr].mult = v; applyAllBoosts() end
end

-- ============================================================
-- [[ AUTO-TAG (KILL AURA) ]] --
-- ============================================================
local IGNORED_ROLES = {
    Bomb = true, PatientZero = true, Infected = true, Tagger = true,
    HotBomb = true, Chiller = true, Dead = true, Ashen = true,
    Spectator = true, OOF = true,
}

-- Роли-одиночки (тагают всех)
local FFA_ROLES = {
    FFATagger = true, SlapFFATagger = true,
}

local function autoTagLoop()
    if not _G.AutoTagEnabled then return end
    local hrp = getHRP()
    if not hrp then return end

    local myRole = getRole(LocalPlayer)
    local closestTarget, closestDist = nil, _G.KillAuraRange
    local myChar = LocalPlayer.Character

    for _, char in ipairs(CollectionService:GetTagged("TaggablePlayer")) do
        local targetHRP = char ~= myChar and char:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            local targetPlayer = Players:GetPlayerFromCharacter(char)
            local targetRole = targetPlayer and getRole(targetPlayer)
            local skip = false

            if FFA_ROLES[myRole] then
                skip = targetRole and IGNORED_ROLES[targetRole]
            else
                if myRole == "Crown" and (targetRole == "Peasant" or targetRole == "Knight") then skip = true
                elseif (myRole == "Chiller" or myRole == "Freezer") and targetRole == "Frozen" then skip = true
                elseif myRole == "Runner" and targetRole == "Chiller" then skip = true
                elseif myRole and targetRole and myRole == targetRole then skip = true
                elseif targetRole and IGNORED_ROLES[targetRole] then skip = true
                end
            end

            if not skip then
                local dist = (targetHRP.Position - hrp.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestTarget = char
                end
            end
        end
    end

    if not closestTarget then return end

    local targetPlayer = Players:GetPlayerFromCharacter(closestTarget)
    if not targetPlayer then return end

    local success, targetID = pcall(SerialisedData.getPlayer, targetPlayer)
    if not (success and targetID) then return end

    local targetHRP = closestTarget.HumanoidRootPart
    local lookCFrame = CFrame.new(hrp.Position, targetHRP.Position)
    local a1, a2, a3 = lookCFrame:ToEulerAnglesYXZ()

    local function compress(angle)
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
        local cd = boosters.TagCooldown
        local tagSpeed = 1 / (cd.enabled and (cd.base * cd.mult) or cd.base)
        pcall(function() AnimateEvent:Fire("Tag", 0.1, tagSpeed) end)
        pcall(function() TagSwing:Fire() end)
    end
end

-- ============================================================
-- [[ AUTO-TAG LEGIT (только цели перед тобой) ]] --
-- ============================================================
local function legitTagLoop()
    if not _G.LegitTagEnabled then return end
    local hrp = getHRP()
    if not hrp then return end

    local myRole = getRole(LocalPlayer)
    local myChar = LocalPlayer.Character

    -- Направление взгляда (камера)
    local aimDir = Camera.CFrame.LookVector

    local closestTarget, closestDist = nil, _G.LegitTagRange
    local bestDot = _G.LegitTagFOV

    for _, char in ipairs(CollectionService:GetTagged("TaggablePlayer")) do
        local targetHRP = char ~= myChar and char:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            local targetPlayer = Players:GetPlayerFromCharacter(char)
            local targetRole = targetPlayer and getRole(targetPlayer)
            local skip = false

            if FFA_ROLES[myRole] then
                skip = targetRole and IGNORED_ROLES[targetRole]
            else
                if myRole == "Crown" and (targetRole == "Peasant" or targetRole == "Knight") then skip = true
                elseif (myRole == "Chiller" or myRole == "Freezer") and targetRole == "Frozen" then skip = true
                elseif myRole == "Runner" and targetRole == "Chiller" then skip = true
                elseif myRole and targetRole and myRole == targetRole then skip = true
                elseif targetRole and IGNORED_ROLES[targetRole] then skip = true
                end
            end

            if not skip then
                local delta = targetHRP.Position - hrp.Position
                local dist = delta.Magnitude
                if dist < closestDist and dist > 0 then
                    -- Проверка: цель в конусе перед нами?
                    local dot = aimDir:Dot(delta.Unit)
                    if dot > bestDot then
                        bestDot = dot
                        closestTarget = char
                    end
                end
            end
        end
    end

    if not closestTarget then return end

    local targetPlayer = Players:GetPlayerFromCharacter(closestTarget)
    if not targetPlayer then return end

    local success, targetID = pcall(SerialisedData.getPlayer, targetPlayer)
    if not (success and targetID) then return end

    local targetHRP = closestTarget.HumanoidRootPart
    local lookCFrame = CFrame.new(hrp.Position, targetHRP.Position)
    local a1, a2, a3 = lookCFrame:ToEulerAnglesYXZ()

    local function compress(angle)
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
        local cd = boosters.TagCooldown
        local tagSpeed = 1 / (cd.enabled and (cd.base * cd.mult) or cd.base)
        pcall(function() AnimateEvent:Fire("Tag", 0.1, tagSpeed) end)
        pcall(function() TagSwing:Fire() end)
    end
end

-- ============================================================
-- [[ AUTO-PARRY ]] --
-- ============================================================
local function autoParryLoop()
    if not _G.AutoParryEnabled then return end
    -- ставим флаг игры (на всякий) + напрямую фаерим
    if shared.multipliers then
        shared.multipliers.EnableParrying = true
    end
    if Utils.InCooldown and Utils.InCooldown("Parry") then return end
    pcall(function()
        PlayerParryEvent:FireServer()
        SoundEvent:Fire("Parry", getHRP(), 0.25, true)
        AnimateEvent:Fire("Parry", 0.1)
    end)
    pcall(function() Utils.ApplyCooldown("Parry") end)
end

-- ============================================================
-- [[ LOOK AT PLAYER (HARD LOCK) ]] --
-- ============================================================
local lookAtEnabled = false
local lookAtTarget = nil

local function lookAtLoop()
    if not lookAtEnabled or not lookAtTarget then return end
    local targetPlayer = Players:FindFirstChild(lookAtTarget)
    local targetHrp = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHrp.Position)
end

-- ============================================================
-- [[ ROLE CLASSIFICATION ]] --
-- ============================================================
-- Мёртвые/нейтральные роли (не враги и не союзники)
local NEUTRAL_ROLES = {
    Dead = true, OOF = true, Ashen = true, Spectator = true,
    FFATagger = true, SlapFFATagger = true,
}

local function isNeutral(role)
    return role and NEUTRAL_ROLES[role]
end

local function isDeadRole(player)
    local role = getRole(player)
    return role == "Dead" or role == "OOF" or role == "Ashen"
end

local function isFrozen(player)
    return getRole(player) == "Frozen"
end

local function isEnemy(player)
    local myRole = getRole(LocalPlayer)
    local theirRole = getRole(player)
    if not myRole or not theirRole then return false end
    if theirRole == "Frozen" or isNeutral(theirRole) then return false end
    return theirRole ~= myRole
end

local function isMyTeam(player)
    local myRole = getRole(LocalPlayer)
    local theirRole = getRole(player)
    if not myRole or not theirRole then return false end
    if theirRole == "Frozen" or isNeutral(theirRole) then return false end
    return theirRole == myRole
end

local roleColors = {
    Crown = Color3.fromRGB(255, 215, 0), Monarch = Color3.fromRGB(255, 215, 0),
    Tagger = Color3.fromRGB(255, 0, 0), RunnerTagger = Color3.fromRGB(255, 0, 0),
    FFATagger = Color3.fromRGB(255, 0, 0), SlapFFATagger = Color3.fromRGB(255, 0, 0),
    Infected = Color3.fromRGB(50, 205, 50), PatientZero = Color3.fromRGB(50, 205, 50),
    FastInfected = Color3.fromRGB(50, 205, 50), BabyInfected = Color3.fromRGB(50, 205, 50),
    JumpingInfected = Color3.fromRGB(50, 205, 50), BigInfected = Color3.fromRGB(50, 205, 50),
    CloakInfected = Color3.fromRGB(50, 205, 50), InfectedRunner = Color3.fromRGB(50, 205, 50),
    Bomb = Color3.fromRGB(255, 140, 0), SubspaceBomb = Color3.fromRGB(255, 140, 0),
    AshyBomb = Color3.fromRGB(255, 140, 0), HotBomb = Color3.fromRGB(255, 140, 0),
    FunnyBomb = Color3.fromRGB(255, 140, 0), Nuke = Color3.fromRGB(255, 140, 0),
    Slasher = Color3.fromRGB(75, 0, 130), HiddenSlasher = Color3.fromRGB(75, 0, 130),
    Haunter = Color3.fromRGB(75, 0, 130), TheStalker = Color3.fromRGB(75, 0, 130),
    Knight = Color3.fromRGB(169, 169, 169), Bodyguard = Color3.fromRGB(169, 169, 169),
    Peasant = Color3.fromRGB(139, 69, 19), Baron = Color3.fromRGB(139, 69, 19),
    Freezer = Color3.fromRGB(0, 206, 209), Chiller = Color3.fromRGB(0, 206, 209),
    Frozen = Color3.fromRGB(0, 206, 209), FrozenInfected = Color3.fromRGB(0, 206, 209),
    Arsonist = Color3.fromRGB(255, 69, 0), Burning = Color3.fromRGB(255, 69, 0),
    Toxic = Color3.fromRGB(126, 255, 5),
    Seeker = Color3.fromRGB(50, 50, 255), Overseer = Color3.fromRGB(50, 50, 255),
    Hunter = Color3.fromRGB(50, 50, 255), Eliminator = Color3.fromRGB(50, 50, 255),
    Assassin = Color3.fromRGB(50, 50, 255), Juggernaut = Color3.fromRGB(50, 50, 255),
    Target = Color3.fromRGB(255, 100, 255), HiddenBeing = Color3.fromRGB(255, 100, 255),
    Runner = Color3.fromRGB(100, 200, 255), Hider = Color3.fromRGB(100, 200, 255),
    Medic = Color3.fromRGB(100, 200, 255), Survivor = Color3.fromRGB(255, 255, 0),
    Spectator = Color3.fromRGB(128, 128, 128), pingus = Color3.fromRGB(128, 128, 128),
    Ashen = Color3.fromRGB(80, 80, 80), Dead = Color3.fromRGB(200, 200, 200),
}

local function getRoleColor(role) return roleColors[role] or Color3.fromRGB(255, 255, 255) end

-- ============================================================
-- [[ TRACERS ]] --
-- ============================================================
local tracersEnabled = false
local selectedCategories = {"Enemies"}
local lines = {}

local function clearTracerCache(playerName)
    local l = lines[playerName]
    if l then
        pcall(function() l.Visible = false; l:Remove() end)
        lines[playerName] = nil
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function() clearTracerCache(player.Name) end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function() clearTracerCache(player.Name) end)
end)

Players.PlayerRemoving:Connect(function(player) clearTracerCache(player.Name) end)

-- ============================================================
-- [[ VISUALIZER RING ]] --
-- ============================================================
local function makeRingPart(name, size, color, transparency)
    local p = Instance.new("Part")
    p.Name = name
    p.Shape = Enum.PartType.Cylinder
    p.Size = size
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Transparency = transparency
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Massless = true
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = workspace
    return p
end

local killAuraRingOuter = makeRingPart("MoroKillAuraRingOuter", Vector3.new(0.2, 30, 30), Color3.fromRGB(255, 0, 0), 0.6)
local killAuraRingInner = makeRingPart("MoroKillAuraRingInner", Vector3.new(0.3, 28, 28), Color3.fromRGB(0, 0, 0), 1)

local floorRayParams = RaycastParams.new()
floorRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateRing()
    local hrp = getHRP()
    if hrp and _G.AutoTagEnabled and _G.ShowKillAuraRing then
        floorRayParams.FilterDescendantsInstances = {LocalPlayer.Character}
        local ray = workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, -50, 0), floorRayParams)
        local floorY = ray and (ray.Position.Y + 0.05) or (hrp.Position.Y - (hrp.Size.Y / 2) - 2)

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
-- [[ COSMETICS ]] --
-- ============================================================
local currentTrail, currentOutfit = nil, nil
local lastEquippedTrail, lastEquippedOutfit = nil, nil

local TRAILS_DATA = {
    {display = "+", model = "+"}, {display = "6 color", model = "Pride"},
    {display = "abro", model = "Pride"}, {display = "ace", model = "Pride"},
    {display = "ac unit", model = "ACUnit"}, {display = "ablaze", model = "Ablaze"},
    {display = "arithmetic", model = "Arithmetic"}, {display = "arrow", model = "Arrow"},
    {display = "awesome human trail", model = "AwesomeHumanTrail"}, {display = "basic", model = "Basic"},
    {display = "bi", model = "Pride"}, {display = "bitwave", model = "BitWaves"},
    {display = "bonsai", model = "Bonsai"}, {display = "box", model = "Box"},
    {display = "cape", model = "Cape"}, {display = "celestial head", model = "CelestialHead"},
    {display = "cherry blossom", model = "CherryBlossom"}, {display = "chocolate box", model = "HeartTrail"},
    {display = "circle", model = "Circle"}, {display = "cloudy", model = "Cloudy"},
    {display = "comet", model = "Comet"}, {display = "condiments", model = "Condiments"},
    {display = "dark gradient", model = "DarkGradient"}, {display = "decorated tree", model = "Decorated Tree"},
    {display = "dracula walker", model = "draculawalker"}, {display = "driftin", model = "Driftin"},
    {display = "encrypted", model = "Encrypted"}, {display = "error", model = "Error"},
    {display = "flaming skull", model = "ghostrider"}, {display = "fluid", model = "Pride"},
    {display = "freedom", model = "Freedom"}, {display = "frostbite", model = "frostbite"},
    {display = "gilbert", model = "Pride"}, {display = "gradient", model = "Gradient"},
    {display = "homing missile", model = "homingmissle"}, {display = "ice skating", model = "IceSkates"},
    {display = "idea", model = "IdeaTrail"}, {display = "illusions", model = "Illusions"},
    {display = "jet", model = "JetTrail"}, {display = "kinetic", model = "Kinetic"},
    {display = "knight", model = "Knight"}, {display = "light gradient", model = "LightGradient"},
    {display = "love power", model = "LovePower"}, {display = "lovestruck", model = "Lovestruck"},
    {display = "m.l.m.", model = "Pride"}, {display = "meteor fists", model = "MeteorFists"},
    {display = "n.b.", model = "Pride"}, {display = "overfilled briefcase", model = "OverfilledBriefcase"},
    {display = "pan", model = "Pride"}, {display = "pentagon", model = "PentagonTrail"},
    {display = "personal sun", model = "PersonalSun"}, {display = "philly", model = "Pride"},
    {display = "polaris", model = "NorthStarTrail"}, {display = "pride", model = "Pride"},
    {display = "radio head", model = "RadioHead"}, {display = "rainbow comet", model = "RainbowComet"},
    {display = "real PNG", model = "RealPNG"}, {display = "salt n' pepper", model = "SaltNPepper"},
    {display = "secret santa", model = "SecretSanta"}, {display = "segmented", model = "Segmented"},
    {display = "snarp", model = "snarp"}, {display = "snowflake power", model = "Snowflake Power"},
    {display = "snowflakes", model = "Snowflakes"}, {display = "solid", model = "Solid"},
    {display = "sparkletime", model = "Sparkletime"}, {display = "sparkling hands", model = "Sparklinghands"},
    {display = "speedcoil", model = "SpeedCoilTrail"}, {display = "spellbook", model = "Spellbook"},
    {display = "star", model = "StarTrail"}, {display = "star beam", model = "StarTrail2"},
    {display = "star power", model = "StarRoot"}, {display = "stinky", model = "Stinky"},
    {display = "string lights", model = "StringLights"}, {display = "subspace", model = "Subspace"},
    {display = "T", model = "T"}, {display = "tachophobia", model = "Tachophobia"},
    {display = "tank knight", model = "TankKnight"}, {display = "the trail", model = "GuppyTrail"},
    {display = "trail test", model = "GuppyTrail"}, {display = "trans", model = "Pride"},
    {display = "triangle", model = "Triangle"}, {display = "tron", model = "Tron"},
    {display = "tron 2", model = "Tron2"}, {display = "V", model = "V"},
    {display = "vantablack", model = "Vantablack"}, {display = "visualizer", model = "Visualizer"},
    {display = "w.l.w.", model = "Pride"}, {display = "whirlpool", model = "WhirlPool"},
    {display = "X", model = "X"}, {display = "yinyang", model = "YinYang"},
    {display = "zfight", model = "ZFight"},
}

table.sort(TRAILS_DATA, function(a, b) return a.display:lower() < b.display:lower() end)

local TRAIL_DISPLAY_NAMES = {}
local TRAIL_MODEL_MAP = {}
for _, trail in ipairs(TRAILS_DATA) do
    table.insert(TRAIL_DISPLAY_NAMES, trail.display)
    TRAIL_MODEL_MAP[trail.display] = trail.model
end

local function getTrailModel(displayName)
    return TRAIL_MODEL_MAP[displayName] or displayName
end

-- Защита косметики от удаления игрой
if hookmetamethods and getnamecallmethod then
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

-- Универсальная настройка аттачментов трейла
local function setupTrailAttachments(trailModel, hrp)
    local trailObj = trailModel:FindFirstChildOfClass("Trail")
    if not trailObj then return end

    local att0 = hrp:FindFirstChild("TrailAttachment0")
    if not att0 then att0 = Instance.new("Attachment"); att0.Parent = hrp end
    att0.Name = "TrailAttachment0"
    att0.Position = Vector3.new(0, 1, 0)

    local att1 = hrp:FindFirstChild("TrailAttachment1")
    if not att1 then att1 = Instance.new("Attachment"); att1.Parent = hrp end
    att1.Name = "TrailAttachment1"
    att1.Position = Vector3.new(0, -1, 0)

    trailObj.Attachment0 = att0
    trailObj.Attachment1 = att1
end

-- Установка трейла по имени МОДЕЛИ
local function equipTrailByModel(modelName, saveKey)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if currentTrail and currentTrail.Parent then
        pcall(function() currentTrail:Destroy() end)
    end

    local trailsFolder = ReplicatedStorage:FindFirstChild("Trails")
    if not trailsFolder then return false end

    local model = trailsFolder:FindFirstChild(modelName)
    if not model then return false end

    currentTrail = model:Clone()
    currentTrail.Parent = char
    setupTrailAttachments(currentTrail, hrp)

    lastEquippedTrail = saveKey or modelName
    return true
end

-- Установка по display-имени (из дропдауна)
local function equipTrail(displayName)
    return equipTrailByModel(getTrailModel(displayName), displayName)
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

-- Мониторинг восстановления косметики
task.spawn(function()
    while true do
        task.wait(0.3)
        if LocalPlayer.Character then
            if lastEquippedTrail and (not currentTrail or not currentTrail.Parent) then
                equipTrail(lastEquippedTrail)
            end
            if lastEquippedOutfit and (not currentOutfit or not currentOutfit.Parent) then
                equipOutfit(lastEquippedOutfit)
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if lastEquippedTrail then equipTrail(lastEquippedTrail) end
    if lastEquippedOutfit then equipOutfit(lastEquippedOutfit) end
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
accelSec:AddToggle({ Name = "Acceleration Booster", Icon = "zap", Default = false, Callback = makeBoostToggle("AccelerationMultiplier") })
accelSec:AddSlider({ Name = "Accel Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 10.0, Decimals = 2, Callback = makeBoostSlider("AccelerationMultiplier") })

local runSec = moveTab:CreateSection({ Name = "Run Speed", Icon = "activity" })
runSec:AddToggle({ Name = "Run Speed Booster", Icon = "activity", Default = false, Callback = makeBoostToggle("RunSpeedMultiplier") })
runSec:AddSlider({ Name = "Run Multiplier", Icon = "trending-up", Min = 0.1, Max = 2.0, Default = 1.1, Decimals = 2, Callback = makeBoostSlider("RunSpeedMultiplier") })

moveTab:Column("right")
local jumpSec = moveTab:CreateSection({ Name = "Jump Power", Icon = "arrow-up" })
jumpSec:AddToggle({ Name = "Jump Power Booster", Icon = "arrow-up", Default = false, Callback = makeBoostToggle("JumpPowerMultiplier") })
jumpSec:AddSlider({ Name = "Jump Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("JumpPowerMultiplier") })

-- ===================== VISUALS TAB =====================
local visualsTab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })

visualsTab:Column("left")
local sizeSec = visualsTab:CreateSection({ Name = "Body Size", Icon = "maximize" })
sizeSec:AddToggle({ Name = "Size Booster", Icon = "maximize", Default = false, Callback = makeBoostToggle("SizeMultiplier") })
sizeSec:AddSlider({ Name = "Size Multiplier", Icon = "trending-up", Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("SizeMultiplier") })

local headSec = visualsTab:CreateSection({ Name = "Head Size", Icon = "circle" })
headSec:AddToggle({ Name = "Head Size Booster", Icon = "circle", Default = false, Callback = makeBoostToggle("HeadSizeMultiplier") })
headSec:AddSlider({ Name = "Head Multiplier", Icon = "trending-up", Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("HeadSizeMultiplier") })

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
tracerSec:AddMultiDropdown({
    Name = "Select Categories", Icon = "users",
    Options = {"Enemies", "My Team", "OOF", "Frozen"},
    Default = {"Enemies"},
    Callback = function(values) selectedCategories = values or {} end,
})

-- ===================== COMBAT TAB =====================
local combatTab = Window:CreateTab({ Name = "Combat", Icon = "crosshair" })

combatTab:Column("left")
local tagCdSec = combatTab:CreateSection({ Name = "Tag Cooldown", Icon = "clock" })
tagCdSec:AddToggle({ Name = "Tag Cooldown Booster", Icon = "clock", Default = false, Callback = makeBoostToggle("TagCooldown") })
tagCdSec:AddSlider({ Name = "Cooldown Multiplier", Icon = "trending-up", Min = 0.01, Max = 2.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("TagCooldown") })

local tagKbSec = combatTab:CreateSection({ Name = "Tag Knockback", Icon = "wind" })
tagKbSec:AddToggle({ Name = "Tag Knockback Booster", Icon = "wind", Default = false, Callback = makeBoostToggle("TagPlayerKnockback") })
tagKbSec:AddSlider({ Name = "Knockback Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("TagPlayerKnockback") })

local rangeSec = combatTab:CreateSection({ Name = "Tag Range", Icon = "maximize" })
rangeSec:AddToggle({ Name = "Range Booster", Icon = "maximize", Default = false, Callback = makeBoostToggle("RangeMultiplier") })
rangeSec:AddSlider({ Name = "Range Multiplier", Icon = "trending-up", Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("RangeMultiplier") })

local lookSec = combatTab:CreateSection({ Name = "Look At Player", Icon = "eye" })
lookSec:AddToggle({ Name = "Enable Look At", Icon = "eye", Default = false, Callback = function(state) lookAtEnabled = state end })
local targetDrop = lookSec:AddDropdown({ Name = "Select Target", Icon = "user", Options = {}, Callback = function(val) lookAtTarget = val end })
lookSec:AddButton({
    Name = "Refresh Players", Icon = "refresh-cw",
    Callback = function()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        targetDrop.Refresh(names, true)
    end,
})

combatTab:Column("right")
local autoTagSec = combatTab:CreateSection({ Name = "Auto Tag", Icon = "zap" })
autoTagSec:AddToggle({ Name = "Auto Tag (Kill Aura)", Icon = "zap", Default = false, Callback = function(state) _G.AutoTagEnabled = state end })
autoTagSec:AddSlider({ Name = "Tag Radius", Icon = "maximize", Min = 5, Max = 20, Default = 10, Decimals = 0, Callback = function(val) _G.KillAuraRange = val end })
autoTagSec:AddToggle({ Name = "Show Ring", Icon = "circle", Default = false, Callback = function(state) _G.ShowKillAuraRing = state end })

local legitTagSec = combatTab:CreateSection({ Name = "Auto Tag (Legit)", Icon = "target" })
legitTagSec:AddToggle({ Name = "Auto Tag (Legit)", Icon = "target", Default = false, Callback = function(state) _G.LegitTagEnabled = state end })
legitTagSec:AddSlider({ Name = "Legit Range", Icon = "maximize", Min = 5, Max = 20, Default = 12, Decimals = 0, Callback = function(val) _G.LegitTagRange = val end })
legitTagSec:AddSlider({ Name = "Cone FOV", Icon = "triangle", Min = 0.1, Max = 0.95, Default = 0.6, Decimals = 2, Callback = function(val) _G.LegitTagFOV = val end })

local godTagSec = combatTab:CreateSection({ Name = "God Tag", Icon = "swords" })
godTagSec:AddToggle({ Name = "God Tag (нативная аура)", Icon = "swords", Default = false, Callback = function(s) _G.GodTagEnabled = s end })

local autoParrySec = combatTab:CreateSection({ Name = "Auto Parry", Icon = "shield" })
autoParrySec:AddToggle({
    Name = "Auto Parry", Icon = "shield", Default = false,
    Callback = function(state)
        _G.AutoParryEnabled = state
        applyAllBoosts() -- сразу выставит атрибут EnableParry
    end,
})
autoParrySec:AddSlider({ Name = "Parry Radius", Icon = "maximize", Min = 5, Max = 20, Default = 12, Decimals = 0, Callback = function(val) _G.AutoParryRange = val end })

-- ===================== ADVANCED TAB =====================
local advancedTab = Window:CreateTab({ Name = "Advanced", Icon = "settings" })

advancedTab:Column("left")
local momentumSec = advancedTab:CreateSection({ Name = "Momentum", Icon = "activity" })
momentumSec:AddToggle({ Name = "Momentum Booster", Icon = "activity", Default = false, Callback = makeBoostToggle("MomentumMultiplier") })
momentumSec:AddSlider({ Name = "Momentum Multiplier", Icon = "trending-up", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("MomentumMultiplier") })
momentumSec:AddToggle({ Name = "Momentum Decay Booster", Icon = "trending-down", Default = false, Callback = makeBoostToggle("MomentumDecayMultiplier") })
momentumSec:AddSlider({ Name = "Decay Multiplier", Icon = "trending-down", Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("MomentumDecayMultiplier") })

local frictionSec = advancedTab:CreateSection({ Name = "Friction", Icon = "wind" })
frictionSec:AddToggle({ Name = "Friction Decay Booster", Icon = "wind", Default = false, Callback = makeBoostToggle("FrictionDecayMultiplier") })
frictionSec:AddSlider({ Name = "Friction Multiplier", Icon = "wind", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("FrictionDecayMultiplier") })

advancedTab:Column("right")
local specialSec = advancedTab:CreateSection({ Name = "Special", Icon = "zap" })
specialSec:AddToggle({ Name = "Window Smash Booster", Icon = "box", Default = false, Callback = makeBoostToggle("WindowSmashMultiplier") })
specialSec:AddSlider({ Name = "Window Multiplier", Icon = "box", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("WindowSmashMultiplier") })
specialSec:AddToggle({ Name = "Roll Boost Booster", Icon = "rotate-cw", Default = false, Callback = makeBoostToggle("RollBoostMultiplier") })
specialSec:AddSlider({ Name = "Roll Multiplier", Icon = "rotate-cw", Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Callback = makeBoostSlider("RollBoostMultiplier") })

-- ===================== COSMETICS TAB =====================
local cosmeticsTab = Window:CreateTab({ Name = "Cosmetics", Icon = "shirt" })

cosmeticsTab:Column("left")
local trailsSec = cosmeticsTab:CreateSection({ Name = "Trails", Icon = "zap" })

local trailDrop = trailsSec:AddDropdown({
    Name = "Select Trail", Icon = "layers",
    Options = TRAIL_DISPLAY_NAMES, Default = TRAIL_DISPLAY_NAMES[1],
})

trailsSec:AddButton({
    Name = "Equip Trail", Primary = true, Icon = "check",
    Callback = function()
        local selected = trailDrop.Get()
        if equipTrail(selected) then
            Window:Notify({ Title = "Trail", Content = "Equipped: " .. selected, Type = "Success", Duration = 2 })
        else
            Window:Notify({ Title = "Trail", Content = "Failed to equip", Type = "Error", Duration = 2 })
        end
    end,
})

trailsSec:AddButton({
    Name = "Unequip Trail", Icon = "x",
    Callback = function()
        unequipTrail()
        Window:Notify({ Title = "Trail", Content = "Trail removed", Type = "Info", Duration = 2 })
    end,
})

local trailNameBox = trailsSec:AddTextbox({ Name = "Trail Name (exact)", Placeholder = "Enter model name" })

trailsSec:AddButton({
    Name = "Equip by Name", Icon = "edit",
    Callback = function()
        local name = trailNameBox.Get()
        if name == "" then
            Window:Notify({ Title = "Trail", Content = "Enter a name", Type = "Warning", Duration = 2 })
            return
        end
        if equipTrailByModel(name, name) then
            Window:Notify({ Title = "Trail", Content = "Equipped: " .. name, Type = "Success", Duration = 2 })
        else
            Window:Notify({ Title = "Trail", Content = "Model not found: " .. name, Type = "Error", Duration = 2 })
        end
    end,
})

cosmeticsTab:Column("right")
local outfitsSec = cosmeticsTab:CreateSection({ Name = "Outfits", Icon = "shirt" })

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
        Name = "Select Outfit", Icon = "layers",
        Options = OUTFIT_NAMES, Default = OUTFIT_NAMES[1],
    })

    outfitsSec:AddButton({
        Name = "Equip Outfit", Primary = true, Icon = "check",
        Callback = function()
            local selected = outfitDrop.Get()
            if equipOutfit(selected) then
                Window:Notify({ Title = "Outfit", Content = "Equipped: " .. selected, Type = "Success", Duration = 2 })
            else
                Window:Notify({ Title = "Outfit", Content = "Failed to equip", Type = "Error", Duration = 2 })
            end
        end,
    })

    outfitsSec:AddButton({
        Name = "Unequip Outfit", Icon = "x",
        Callback = function()
            unequipOutfit()
            Window:Notify({ Title = "Outfit", Content = "Outfit removed", Type = "Info", Duration = 2 })
        end,
    })

    local outfitNameBox = outfitsSec:AddTextbox({ Name = "Outfit Name (exact)", Placeholder = "Enter outfit name" })

    outfitsSec:AddButton({
        Name = "Equip by Name", Icon = "edit",
        Callback = function()
            local name = outfitNameBox.Get()
            if name == "" then
                Window:Notify({ Title = "Outfit", Content = "Enter a name", Type = "Warning", Duration = 2 })
                return
            end
            if equipOutfit(name) then
                Window:Notify({ Title = "Outfit", Content = "Equipped: " .. name, Type = "Success", Duration = 2 })
            else
                Window:Notify({ Title = "Outfit", Content = "Outfit not found: " .. name, Type = "Error", Duration = 2 })
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
    legitTagLoop()
    autoParryLoop()
    applyAllBoosts()
end)

RunService.RenderStepped:Connect(function()
    lookAtLoop()
    updateRing()

    if not tracersEnabled then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        local show = false
        if hrp and #selectedCategories > 0 then
            for _, category in ipairs(selectedCategories) do
                if category == "Enemies" and isEnemy(player) then show = true break end
                if category == "My Team" and isMyTeam(player) then show = true break end
                if category == "OOF" and isDeadRole(player) then show = true break end
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
            local pRole = getRole(player)
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
end)
