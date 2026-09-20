-- [[ Services & Modules ]] --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

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

-- [[ Engine Environment Resolver ]] --
local function getGameShared()
    local renv = (getrenv and getrenv()) or {}
    return renv.shared or shared or {}
end

-- [[ Global Settings ]] --
_G.AutoTagEnabled = false
_G.KillAuraRange = 15
_G.KillAuraWallCheck = true
_G.ShowKillAuraRing = false
_G.IgnoreNoTagBack = true

_G.LegitTagEnabled = false
_G.LegitTagRange = 12
_G.LegitTagFOV = 0.6
_G.LegitTagWallCheck = true

_G.HitboxExpanderEnabled = false
_G.HitboxSize = 8
_G.HitboxTransparency = 0.6

_G.AutoParryEnabled = false
_G.AutoParryMode = "Smart"
_G.AutoParryRange = 14
_G.AutoParryProjectiles = true
_G.ForceParrying = false

_G.EspEnabled = false
_G.EspMaxDistance = 600
_G.ShowHighlights = true
_G.HighlightFillTransparency = 0.5
_G.HighlightOutlineTransparency = 0.0
_G.ShowNames = true
_G.ShowRoles = true
_G.ShowDistance = true
_G.ShowShieldStatus = true
_G.ShowBoxes = false
_G.ShowTracers = false
_G.TracerOrigin = "Bottom"
_G.TracerThickness = 1.5

_G.CoinEspEnabled = false
_G.CoinEspMaxDistance = 800
_G.AutoCollectCoins = false
_G.CollectCoinsMode = "Map-Wide"
_G.CollectCoinsRadius = 100
_G.CollectCoinsDelay = 0.15

_G.AntiAFK = true
_G.AutoRejoin = true
_G.ForceUnlockTagging = true

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

-- === ANTI AFK & AUTO REJOIN ===
local xAFKx
local function setupAntiAFK(enabled)
    if xAFKx then
        pcall(function() xAFKx:Disconnect() end)
        xAFKx = nil
    end
    if enabled then
        xAFKx = LocalPlayer.Idled:Connect(function()
            if not _G.AntiAFK then return end
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end)
    end
end
setupAntiAFK(true)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local currentPlace = game.PlaceId
local currentServer = game.JobId

local function reconnect()
    local player = Players.LocalPlayer
    if player then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(currentPlace, currentServer, player)
        end)
        task.wait(10)
        pcall(function()
            TeleportService:Teleport(currentPlace, player)
        end)
    end
end

local function serverHop()
    local success, result = pcall(function()
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", currentPlace)
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if success and result and result.data then
        for _, s in ipairs(result.data) do
            if s.id ~= currentServer and s.playing < s.maxPlayers and s.playing > 0 then
                TeleportService:TeleportToPlaceInstance(currentPlace, s.id, LocalPlayer)
                return true
            end
        end
    end
    TeleportService:Teleport(currentPlace, LocalPlayer)
    return true
end

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function()
        if not _G.AutoRejoin then return end
        local errorMsg = GuiService:GetErrorMessage()
        if errorMsg and errorMsg ~= "" then
            task.wait(5)
            reconnect()
        end
    end)
end)

-- ============================================================
-- [[ POWERFUL BOOSTER ENGINE ]] --
-- ============================================================
local boosters = {
    Speed = { enabled = false, mult = 2.0 },
    Jump = { enabled = false, mult = 2.5 },
    Accel = { enabled = false, mult = 5.0 },
    TagCooldown = { enabled = false, mult = 3.0 },
    TagRange = { enabled = false, mult = 2.0 },
    TagKnockback = { enabled = false, mult = 3.0 },
    SlideSpeed = { enabled = false, mult = 2.0 },
    SlideJump = { enabled = false, mult = 2.0 },
    Wallclimb = { enabled = false, mult = 2.0 },
    VaultMomentum = { enabled = false, mult = 2.0 },
    Gravity = { enabled = false, mult = 1.0 },
    CharacterScale = { enabled = false, mult = 1.0 },
}

local moveFlags = {
    RunInAllDirections = false,
    InfiniteSlides = false,
    EnableWallrunning = false,
    EnableTictacs = false,
    EnableParagliding = false,
    EnableFlying = false,
    DisableFriction = false,
}

local function applyAllBoosts()
    local gShared = getGameShared()
    if not gShared or not gShared.multipliers then return end
    local m = gShared.multipliers

    -- Разблокировать таг
    if _G.ForceUnlockTagging ~= false then
        m.DisableTagging = false
    end

    -- Включение парирования в движке
    if _G.AutoParryEnabled or _G.ForceParrying then
        m.EnableParrying = true
    end

    -- Булевы флаги движения
    for flag, state in pairs(moveFlags) do
        m[flag] = state and true or false
    end

    -- Скорость (Speed Booster): синхронно WalkSpeedMultiplier и RunSpeedMultiplier
    if boosters.Speed.enabled then
        local spd = boosters.Speed.mult
        m.WalkSpeedMultiplier = spd
        m.RunSpeedMultiplier = spd
    else
        m.WalkSpeedMultiplier = 1
        m.RunSpeedMultiplier = 1.01
    end

    -- Сила прыжка (Jump Power Booster)
    if boosters.Jump.enabled then
        local jmp = boosters.Jump.mult
        m.JumpPowerMultiplier = jmp
        if not boosters.SlideJump.enabled then
            m.SlideJumpMultiplier = jmp
        end
    else
        m.JumpPowerMultiplier = 1.25
    end

    -- Ускорение (Acceleration Booster)
    if boosters.Accel.enabled then
        m.AccelerationMultiplier = boosters.Accel.mult
    else
        m.AccelerationMultiplier = 1
    end

    -- Кулдаун тага (Tag Cooldown Booster)
    if boosters.TagCooldown.enabled then
        m.TagCooldown = math.max(0.01, 0.666 / boosters.TagCooldown.mult)
        if gShared.cooldowns then
            gShared.cooldowns["Tag"] = 0
        end
    else
        m.TagCooldown = 0.666
    end

    -- Дальность тага (Tag Range Booster)
    if boosters.TagRange.enabled then
        m.RangeMultiplier = boosters.TagRange.mult
        m.TagRayNumber = 18
        m.TagRaySpread = 2
        m.TagRayRows = 2
    else
        m.RangeMultiplier = 1
        m.TagRayNumber = 9
        m.TagRaySpread = 1
        m.TagRayRows = 1
    end

    -- Сила отбрасывания при таге (Knockback Booster)
    if boosters.TagKnockback.enabled then
        local kb = boosters.TagKnockback.mult
        m.TagPlayerKnockback = kb
        m.TagPartKnockback = kb
        m.TagKnockback = kb
    else
        m.TagPlayerKnockback = 1
        m.TagPartKnockback = 1
        m.TagKnockback = 1
    end

    -- Паркур-множители
    if boosters.SlideSpeed.enabled then
        m.SlideSpeedMultiplier = boosters.SlideSpeed.mult
    else
        m.SlideSpeedMultiplier = 1
    end

    if boosters.SlideJump.enabled then
        m.SlideJumpMultiplier = boosters.SlideJump.mult
    elseif not boosters.Jump.enabled then
        m.SlideJumpMultiplier = 1
    end

    if boosters.Wallclimb.enabled then
        m.WallclimbMultiplier = boosters.Wallclimb.mult
    else
        m.WallclimbMultiplier = 1
    end

    if boosters.VaultMomentum.enabled then
        m.VaultMomentumMultiplier = boosters.VaultMomentum.mult
    else
        m.VaultMomentumMultiplier = 1
    end

    if boosters.Gravity.enabled then
        m.GravityMultiplier = boosters.Gravity.mult
    else
        m.GravityMultiplier = 1
    end

    -- Физический размер локального персонажа (Character Scale)
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local scale = boosters.CharacterScale.enabled and boosters.CharacterScale.mult or 1
        if hrp then hrp.Size = Vector3.new(2 * scale, 2 * scale, 1 * scale) end
        if head then head.Size = Vector3.new(2 * scale, 1 * scale, 1 * scale) end
    end
end

-- ============================================================
-- [[ ENEMY HITBOX EXPANDER ]] --
-- ============================================================
local originalHRPProps = {}

local function updateHitboxes()
    if not _G.HitboxExpanderEnabled then
        if next(originalHRPProps) then
            for hrp, props in pairs(originalHRPProps) do
                if hrp and hrp.Parent then
                    pcall(function()
                        hrp.Size = props.Size or Vector3.new(2, 2, 1)
                        hrp.Transparency = props.Transparency or 1
                        hrp.CanCollide = false
                    end)
                end
            end
            table.clear(originalHRPProps)
        end
        return
    end

    local size = _G.HitboxSize or 8
    local trans = _G.HitboxTransparency or 0.6
    local myChar = LocalPlayer.Character

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isEnemy and isEnemy(player) and player.Character and player.Character ~= myChar then
            local eHRP = player.Character:FindFirstChild("HumanoidRootPart")
            if eHRP then
                if not originalHRPProps[eHRP] then
                    originalHRPProps[eHRP] = {
                        Size = eHRP.Size,
                        Transparency = eHRP.Transparency
                    }
                end
                eHRP.Size = Vector3.new(size, size, size)
                eHRP.Transparency = trans
                eHRP.BrickColor = BrickColor.new("Bright red")
                eHRP.Material = Enum.Material.Neon
                eHRP.CanCollide = false
            end
        end
    end
end

-- ============================================================
-- [[ WALL CHECK (LINE OF SIGHT) ]] --
-- ============================================================
local wallRayParams = RaycastParams.new()
wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
wallRayParams.IgnoreWater = true

local function isPointVisible(origin, targetPos, targetChar)
    local direction = targetPos - origin
    local currentOrigin = origin
    local remainingDir = direction
    local ignoreList = {LocalPlayer.Character}
    wallRayParams.FilterDescendantsInstances = ignoreList

    for _ = 1, 4 do
        local ray = workspace:Raycast(currentOrigin, remainingDir, wallRayParams)
        if not ray then
            return true
        end

        local hit = ray.Instance
        if hit:IsDescendantOf(targetChar) then
            return true
        end

        local isOtherPlayer = false
        local parentModel = hit:FindFirstAncestorOfClass("Model")
        if parentModel and Players:GetPlayerFromCharacter(parentModel) then
            isOtherPlayer = true
        end

        if (not hit.CanCollide) or hit.Transparency > 0.8 or isOtherPlayer then
            table.insert(ignoreList, hit)
            wallRayParams.FilterDescendantsInstances = ignoreList

            local hitPos = ray.Position
            remainingDir = targetPos - hitPos
            if remainingDir.Magnitude < 0.15 then
                return true
            end
            currentOrigin = hitPos + remainingDir.Unit * 0.05
        else
            return false
        end
    end
    return false
end

local function isPlayerVisible(targetChar)
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end

    local origin = myHRP.Position + Vector3.new(0, 1.5, 0)
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return false end

    if isPointVisible(origin, targetHRP.Position, targetChar) then
        return true
    end

    local targetHead = targetChar:FindFirstChild("Head")
    if targetHead and isPointVisible(origin, targetHead.Position, targetChar) then
        return true
    end

    return false
end

-- ============================================================
-- [[ AUTO-TAG (KILL AURA) ]] --
-- ============================================================
local IGNORED_ROLES = {
    Bomb = true, PatientZero = true, Infected = true, Tagger = true,
    HotBomb = true, Chiller = true, Dead = true, Ashen = true,
    Spectator = true, OOF = true,
}

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

            if _G.IgnoreNoTagBack ~= false then
                if char:GetAttribute("NoTagBack") or (targetPlayer and targetPlayer:GetAttribute("NoTagBack")) then
                    skip = true
                end
            end

            if not skip then
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
            end

            if not skip then
                local dist = (targetHRP.Position - hrp.Position).Magnitude
                if dist < closestDist then
                    if (not _G.KillAuraWallCheck) or isPlayerVisible(char) then
                        closestDist = dist
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
        local tagSpeed = cd.enabled and cd.mult or 1
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
    local aimDir = Camera.CFrame.LookVector

    local closestTarget, closestDist = nil, _G.LegitTagRange
    local bestDot = _G.LegitTagFOV

    for _, char in ipairs(CollectionService:GetTagged("TaggablePlayer")) do
        local targetHRP = char ~= myChar and char:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            local targetPlayer = Players:GetPlayerFromCharacter(char)
            local targetRole = targetPlayer and getRole(targetPlayer)
            local skip = false

            if _G.IgnoreNoTagBack ~= false then
                if char:GetAttribute("NoTagBack") or (targetPlayer and targetPlayer:GetAttribute("NoTagBack")) then
                    skip = true
                end
            end

            if not skip then
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
            end

            if not skip then
                local delta = targetHRP.Position - hrp.Position
                local dist = delta.Magnitude
                if dist < closestDist and dist > 0 then
                    local dot = aimDir:Dot(delta.Unit)
                    if dot > bestDot then
                        if (not _G.LegitTagWallCheck) or isPlayerVisible(char) then
                            bestDot = dot
                            closestDist = dist
                            closestTarget = char
                        end
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
        local tagSpeed = cd.enabled and cd.mult or 1
        pcall(function() AnimateEvent:Fire("Tag", 0.1, tagSpeed) end)
        pcall(function() TagSwing:Fire() end)
    end
end

-- ============================================================
-- [[ AUTO-PARRY 2.0 (SMART & PROXIMITY) ]] --
-- ============================================================
local isEnemy
local lastParryTick = 0

local function executeParry()
    local gShared = getGameShared()
    if gShared and gShared.multipliers then
        gShared.multipliers.EnableParrying = true
    end

    if Utils.InCooldown and Utils.InCooldown("Parry") then return end
    if tick() - lastParryTick < 0.25 then return end
    lastParryTick = tick()

    pcall(function()
        PlayerParryEvent:FireServer()
        local hrp = getHRP()
        if hrp then SoundEvent:Fire("Parry", hrp, 0.25, true) end
        AnimateEvent:Fire("Parry", 0.1)
    end)
    pcall(function() Utils.ApplyCooldown("Parry") end)
end

local function isEnemyAttacking(enemyPlayer, enemyChar, myHRP)
    local eHRP = enemyChar:FindFirstChild("HumanoidRootPart")
    if not eHRP then return false end

    local toUs = (myHRP.Position - eHRP.Position)
    local dist = toUs.Magnitude
    if dist <= 0.01 then return true end

    local enemyLook = eHRP.CFrame.LookVector
    local dot = enemyLook:Dot(toUs.Unit)

    if dot < -0.2 then
        return false
    end

    if _G.AutoParryMode == "Proximity" then
        return true
    end

    local hum = enemyChar:FindFirstChildOfClass("Humanoid")
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local animName = track.Animation and track.Animation.Name or ""
                if animName == "Tag1" or animName == "Tag2"
                   or animName == "Tag1Acted" or animName == "Tag2Acted"
                   or animName == "SwordLunge" or animName:find("Tag") then
                    return true
                end
            end
        end
    end

    if dist <= 6.5 and dot > 0.6 then
        return true
    end

    return false
end

local function autoParryLoop()
    if not _G.AutoParryEnabled then return end
    local hrp = getHRP()
    if not hrp then return end

    local range = _G.AutoParryRange or 14
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isEnemy and isEnemy(player) and player.Character then
            local eHRP = player.Character:FindFirstChild("HumanoidRootPart")
            if eHRP and (eHRP.Position - hrp.Position).Magnitude <= range then
                if isEnemyAttacking(player, player.Character, hrp) then
                    executeParry()
                    break
                end
            end
        end
    end
end

pcall(function()
    CIParryClientEvent.Event:Connect(function(...)
        if _G.AutoParryEnabled and _G.AutoParryProjectiles ~= false then
            executeParry()
        end
    end)
end)

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
local DEAD_ROLES = {
    Dead = true, OOF = true, Ashen = true, Spectator = true, pingus = true,
}

local function isDeadRole(player)
    local role = getRole(player)
    return role and DEAD_ROLES[role] or false
end

local function isFrozen(player)
    local role = getRole(player)
    return role == "Frozen" or role == "FrozenInfected"
end

local function isFFA(role)
    return role and FFA_ROLES[role] or false
end

local function isRoyalty(role)
    return role == "Crown" or role == "Monarch" or role == "Knight" or role == "Bodyguard" or role == "Peasant" or role == "Baron"
end

isEnemy = function(player)
    if not player or player == LocalPlayer then return false end
    local theirRole = getRole(player)
    if not theirRole or isDeadRole(player) then return false end

    local myRole = getRole(LocalPlayer)

    if isFFA(myRole) or isFFA(theirRole) then
        return true
    end

    if isFrozen(player) then
        return false
    end

    if not myRole then
        return true
    end

    if isRoyalty(myRole) and isRoyalty(theirRole) then
        return false
    end

    if myRole == theirRole then
        return false
    end

    return true
end

local function isMyTeam(player)
    if not player or player == LocalPlayer then return false end
    local theirRole = getRole(player)
    if not theirRole or isDeadRole(player) then return false end

    local myRole = getRole(LocalPlayer)
    if not myRole then return false end

    if isFFA(myRole) or isFFA(theirRole) then
        return false
    end

    if isRoyalty(myRole) and isRoyalty(theirRole) then
        return true
    end

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
-- [[ ESP SYSTEM ]] --
-- ============================================================
local selectedCategories = {"Enemies"}
local espCache = {}

local function shouldShowPlayer(player)
    if not player or player == LocalPlayer then return false end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if #selectedCategories == 0 then return false end

    for _, cat in ipairs(selectedCategories) do
        if cat == "All" then return true end
        if cat == "Enemies" and isEnemy(player) then return true end
        if cat == "My Team" and isMyTeam(player) then return true end
        if cat == "Frozen" and isFrozen(player) then return true end
        if cat == "OOF" and isDeadRole(player) then return true end
    end
    return false
end

local function getOrCreateEspCache(player)
    if not espCache[player] then
        espCache[player] = {}
    end
    return espCache[player]
end

local function hidePlayerEsp(player)
    local cache = espCache[player]
    if not cache then return end
    if cache.Highlight then cache.Highlight.Enabled = false end
    if cache.Billboard then cache.Billboard.Enabled = false end
    if cache.Box then cache.Box.Visible = false end
    if cache.BoxOutline then cache.BoxOutline.Visible = false end
    if cache.Tracer then cache.Tracer.Visible = false end
end

local function clearPlayerEsp(player)
    local cache = espCache[player]
    if not cache then return end
    if cache.Highlight then pcall(function() cache.Highlight:Destroy() end) end
    if cache.Billboard then pcall(function() cache.Billboard:Destroy() end) end
    if cache.Box then pcall(function() cache.Box:Remove() end) end
    if cache.BoxOutline then pcall(function() cache.BoxOutline:Remove() end) end
    if cache.Tracer then pcall(function() cache.Tracer:Remove() end) end
    espCache[player] = nil
end

local function clearAllEsp()
    for player, _ in pairs(espCache) do
        clearPlayerEsp(player)
    end
end

local function updatePlayerEsp(player, myPos, tracerOrigin)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not char or not hrp or not shouldShowPlayer(player) then
        hidePlayerEsp(player)
        return
    end

    local dist = (hrp.Position - myPos).Magnitude
    if dist > _G.EspMaxDistance then
        hidePlayerEsp(player)
        return
    end

    local role = getRole(player) or "Unknown"
    local color = getRoleColor(role)
    local cache = getOrCreateEspCache(player)
    local hasShield = char:GetAttribute("NoTagBack") or (player and player:GetAttribute("NoTagBack"))

    -- 1. HIGHLIGHT (CHAMS)
    if _G.EspEnabled and _G.ShowHighlights then
        if not cache.Highlight or cache.Highlight.Parent ~= char then
            if cache.Highlight then pcall(function() cache.Highlight:Destroy() end) end
            local hl = Instance.new("Highlight")
            hl.Name = "MoroEspHighlight"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
            cache.Highlight = hl
        end
        cache.Highlight.Enabled = true
        cache.Highlight.FillColor = color
        cache.Highlight.OutlineColor = (hasShield and _G.ShowShieldStatus) and Color3.fromRGB(255, 215, 0) or color
        cache.Highlight.FillTransparency = _G.HighlightFillTransparency or 0.5
        cache.Highlight.OutlineTransparency = _G.HighlightOutlineTransparency or 0.0
    elseif cache.Highlight then
        cache.Highlight.Enabled = false
    end

    -- 2. BILLBOARD GUI
    local showAnyText = _G.EspEnabled and (_G.ShowNames or _G.ShowRoles or _G.ShowDistance)
    if showAnyText then
        if not cache.Billboard or cache.Billboard.Parent ~= char then
            if cache.Billboard then pcall(function() cache.Billboard:Destroy() end) end

            local bb = Instance.new("BillboardGui")
            bb.Name = "MoroEspBillboard"
            bb.AlwaysOnTop = true
            bb.Size = UDim2.new(0, 170, 0, 48)
            bb.StudsOffset = Vector3.new(0, 3.2, 0)
            bb.MaxDistance = _G.EspMaxDistance
            bb.Parent = char

            local layout = Instance.new("UIListLayout")
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.VerticalAlignment = Enum.VerticalAlignment.Center
            layout.Padding = UDim.new(0, 1)
            layout.Parent = bb

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Name = "NameLabel"
            nameLbl.LayoutOrder = 1
            nameLbl.BackgroundTransparency = 1
            nameLbl.Size = UDim2.new(1, 0, 0, 14)
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 13
            nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLbl.TextStrokeTransparency = 0.2
            nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            nameLbl.Parent = bb

            local roleLbl = Instance.new("TextLabel")
            roleLbl.Name = "RoleLabel"
            roleLbl.LayoutOrder = 2
            roleLbl.BackgroundTransparency = 1
            roleLbl.Size = UDim2.new(1, 0, 0, 13)
            roleLbl.Font = Enum.Font.GothamSemibold
            roleLbl.TextSize = 12
            roleLbl.TextStrokeTransparency = 0.2
            roleLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            roleLbl.Parent = bb

            local distLbl = Instance.new("TextLabel")
            distLbl.Name = "DistLabel"
            distLbl.LayoutOrder = 3
            distLbl.BackgroundTransparency = 1
            distLbl.Size = UDim2.new(1, 0, 0, 12)
            distLbl.Font = Enum.Font.Gotham
            distLbl.TextSize = 11
            distLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            distLbl.TextStrokeTransparency = 0.3
            distLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            distLbl.Parent = bb

            cache.Billboard = bb
            cache.NameLabel = nameLbl
            cache.RoleLabel = roleLbl
            cache.DistLabel = distLbl
        end

        cache.Billboard.Adornee = hrp
        cache.Billboard.Enabled = true
        cache.Billboard.MaxDistance = _G.EspMaxDistance

        if _G.ShowNames then
            cache.NameLabel.Text = player.DisplayName ~= player.Name and (player.DisplayName .. " (@" .. player.Name .. ")") or player.Name
            cache.NameLabel.Visible = true
        else
            cache.NameLabel.Visible = false
        end

        if _G.ShowRoles then
            local roleStr = "[" .. tostring(role) .. "]"
            if _G.ShowShieldStatus and hasShield then
                roleStr = roleStr .. " [SHIELD]"
                cache.RoleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
            else
                cache.RoleLabel.TextColor3 = color
            end
            cache.RoleLabel.Text = roleStr
            cache.RoleLabel.Visible = true
        else
            cache.RoleLabel.Visible = false
        end

        if _G.ShowDistance then
            cache.DistLabel.Text = string.format("%d studs", math.floor(dist))
            cache.DistLabel.Visible = true
        else
            cache.DistLabel.Visible = false
        end
    elseif cache.Billboard then
        cache.Billboard.Enabled = false
    end

    -- 3. 2D BOX & TRACERS
    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    local hrpCFrame = hrp.CFrame
    local topPos, topOnScreen = Camera:WorldToViewportPoint((hrpCFrame * CFrame.new(0, 3, 0)).Position)
    local bottomPos, bottomOnScreen = Camera:WorldToViewportPoint((hrpCFrame * CFrame.new(0, -3.5, 0)).Position)

    local isVisibleOnScreen = (onScreen or topOnScreen or bottomOnScreen) and screenPos.Z > 0

    if _G.EspEnabled and _G.ShowBoxes and isVisibleOnScreen and Drawing and Drawing.new then
        local boxHeight = math.abs(bottomPos.Y - topPos.Y)
        local boxWidth = boxHeight * 0.65
        local boxPos = Vector2.new(topPos.X - (boxWidth / 2), math.min(topPos.Y, bottomPos.Y))

        if not cache.Box then
            local success, b = pcall(function()
                local out = Drawing.new("Square")
                out.Thickness = 2.5
                out.Filled = false
                out.Color = Color3.new(0, 0, 0)
                out.Transparency = 0.8
                out.Visible = false

                local box = Drawing.new("Square")
                box.Thickness = 1.2
                box.Filled = false
                box.Visible = false
                return {Box = box, Outline = out}
            end)
            if success and b then
                cache.Box = b.Box
                cache.BoxOutline = b.Outline
            end
        end

        if cache.Box and cache.BoxOutline then
            cache.BoxOutline.Size = Vector2.new(boxWidth, boxHeight)
            cache.BoxOutline.Position = boxPos
            cache.BoxOutline.Visible = true

            cache.Box.Size = Vector2.new(boxWidth, boxHeight)
            cache.Box.Position = boxPos
            cache.Box.Color = color
            cache.Box.Visible = true
        end
    else
        if cache.Box then cache.Box.Visible = false end
        if cache.BoxOutline then cache.BoxOutline.Visible = false end
    end

    -- Tracers
    if _G.ShowTracers and onScreen and screenPos.Z > 0 and Drawing and Drawing.new then
        if not cache.Tracer then
            local success, line = pcall(function()
                local l = Drawing.new("Line")
                l.Thickness = _G.TracerThickness or 1.5
                l.Color = color
                l.Visible = false
                return l
            end)
            if success and line then
                cache.Tracer = line
            end
        end

        if cache.Tracer then
            cache.Tracer.From = tracerOrigin
            cache.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            cache.Tracer.Color = color
            cache.Tracer.Thickness = _G.TracerThickness or 1.5
            cache.Tracer.Visible = true
        end
    else
        if cache.Tracer then cache.Tracer.Visible = false end
    end
end

local function updateEspLoop()
    if not _G.EspEnabled and not _G.ShowTracers then
        if next(espCache) then
            for p, _ in pairs(espCache) do
                hidePlayerEsp(p)
            end
        end
        return
    end

    local myHRP = getHRP()
    local myPos = myHRP and myHRP.Position or Camera.CFrame.Position
    local mousePos = UserInputService:GetMouseLocation()
    local viewportSize = Camera.ViewportSize
    local originPos
    if _G.TracerOrigin == "Center" then
        originPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    elseif _G.TracerOrigin == "Mouse" then
        originPos = mousePos
    else
        originPos = Vector2.new(viewportSize.X / 2, viewportSize.Y)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        updatePlayerEsp(player, myPos, originPos)
    end
end

local function setupPlayerListeners(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function()
        clearPlayerEsp(player)
    end)
    player.CharacterRemoving:Connect(function()
        clearPlayerEsp(player)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayerListeners(player)
end

Players.PlayerAdded:Connect(setupPlayerListeners)
Players.PlayerRemoving:Connect(function(player)
    clearPlayerEsp(player)
end)

-- ============================================================
-- [[ COIN & CURRENCY AUTOMATION ]] --
-- ============================================================
local coinEspCache = {}

local function clearCoinEsp(item)
    local cache = coinEspCache[item]
    if cache then
        if cache.Billboard then pcall(function() cache.Billboard:Destroy() end) end
        coinEspCache[item] = nil
    end
end

local function clearAllCoinEsp()
    for item, _ in pairs(coinEspCache) do
        clearCoinEsp(item)
    end
end

local function updateCoinEsp()
    if not _G.CoinEspEnabled then
        if next(coinEspCache) then clearAllCoinEsp() end
        return
    end

    local hrp = getHRP()
    local myPos = hrp and hrp.Position or Camera.CFrame.Position
    local maxDist = _G.CoinEspMaxDistance or 800
    local currencyFolders = {"coins", "specialcurrency", "doublecoins", "doublecoinsLegacy"}
    local seen = {}

    for _, fName in ipairs(currencyFolders) do
        local folder = workspace:FindFirstChild(fName)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                if part and part.Parent then
                    seen[item] = true
                    local dist = (part.Position - myPos).Magnitude
                    local cache = coinEspCache[item]

                    if dist <= maxDist then
                        if not cache then
                            cache = {}
                            coinEspCache[item] = cache

                            local bb = Instance.new("BillboardGui")
                            bb.Name = "MoroCoinBillboard"
                            bb.AlwaysOnTop = true
                            bb.Size = UDim2.new(0, 100, 0, 30)
                            bb.StudsOffset = Vector3.new(0, 1.5, 0)
                            bb.MaxDistance = maxDist
                            bb.Adornee = part
                            bb.Parent = part

                            local lbl = Instance.new("TextLabel")
                            lbl.Name = "Label"
                            lbl.BackgroundTransparency = 1
                            lbl.Size = UDim2.new(1, 0, 1, 0)
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextSize = 11
                            lbl.TextColor3 = fName == "specialcurrency" and Color3.fromRGB(0, 255, 255)
                                or (fName:find("double") and Color3.fromRGB(255, 100, 255) or Color3.fromRGB(255, 215, 0))
                            lbl.TextStrokeTransparency = 0.2
                            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            lbl.Parent = bb

                            cache.Billboard = bb
                            cache.Label = lbl

                            item.AncestryChanged:Connect(function(_, parent)
                                if not parent then clearCoinEsp(item) end
                            end)
                        end

                        if cache.Billboard then
                            cache.Billboard.Enabled = true
                            local tagText = fName == "specialcurrency" and "SPECIAL"
                                or (fName:find("double") and "2X COIN" or "COIN")
                            cache.Label.Text = string.format("%s\n[%d studs]", tagText, math.floor(dist))
                        end
                    elseif cache and cache.Billboard then
                        cache.Billboard.Enabled = false
                    end
                end
            end
        end
    end

    for item, _ in pairs(coinEspCache) do
        if not seen[item] then
            clearCoinEsp(item)
        end
    end
end

local function collectCoins(mapWide, maxRadius)
    local hrp = getHRP()
    if not hrp then return 0 end
    local myPos = hrp.Position
    local count = 0
    local currencyFolders = {"coins", "specialcurrency", "doublecoins", "doublecoinsLegacy"}

    for _, fName in ipairs(currencyFolders) do
        local folder = workspace:FindFirstChild(fName)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                if part and part.Parent then
                    local dist = (part.Position - myPos).Magnitude
                    if mapWide or dist <= (maxRadius or 100) then
                        pcall(function()
                            firetouchinterest(hrp, part, 0)
                            task.wait(0.01)
                            firetouchinterest(hrp, part, 1)
                            count = count + 1
                        end)
                        if not mapWide then
                            task.wait(0.02)
                        end
                    end
                end
            end
        end
    end
    return count
end

task.spawn(function()
    while true do
        task.wait(_G.CollectCoinsDelay or 0.15)
        if _G.AutoCollectCoins then
            local isMapWide = (_G.CollectCoinsMode == "Map-Wide")
            collectCoins(isMapWide, _G.CollectCoinsRadius or 100)
        end
    end
end)

-- ============================================================
-- [[ VISUALIZER RANGE RING ]] --
-- ============================================================
local rangeAnchor = Instance.new("Part")
rangeAnchor.Name = "MoroAuraAnchor"
rangeAnchor.Size = Vector3.new(1, 1, 1)
rangeAnchor.Transparency = 1
rangeAnchor.CanCollide = false
rangeAnchor.CanTouch = false
rangeAnchor.CanQuery = false
rangeAnchor.Massless = true
rangeAnchor.Anchored = true
rangeAnchor.Parent = workspace

local rangeRing = Instance.new("CylinderHandleAdornment")
rangeRing.Name = "MoroAuraRing"
rangeRing.Adornee = rangeAnchor
rangeRing.AlwaysOnTop = false
rangeRing.ZIndex = 2
rangeRing.Color3 = Color3.fromRGB(255, 45, 45)
rangeRing.Transparency = 0.15
rangeRing.Height = 0.08
rangeRing.Radius = _G.KillAuraRange or 15
rangeRing.InnerRadius = math.max(0.1, (_G.KillAuraRange or 15) - 0.35)
rangeRing.CFrame = CFrame.Angles(math.rad(90), 0, 0)
rangeRing.Visible = false
rangeRing.Parent = rangeAnchor

local rangeFill = Instance.new("CylinderHandleAdornment")
rangeFill.Name = "MoroAuraFill"
rangeFill.Adornee = rangeAnchor
rangeFill.AlwaysOnTop = false
rangeFill.ZIndex = 1
rangeFill.Color3 = Color3.fromRGB(255, 60, 60)
rangeFill.Transparency = 0.88
rangeFill.Height = 0.04
rangeFill.Radius = _G.KillAuraRange or 15
rangeFill.InnerRadius = 0
rangeFill.CFrame = CFrame.Angles(math.rad(90), 0, 0)
rangeFill.Visible = false
rangeFill.Parent = rangeAnchor

local floorRayParams = RaycastParams.new()
floorRayParams.FilterType = Enum.RaycastFilterType.Exclude
floorRayParams.IgnoreWater = true

local function updateRing()
    local hrp = getHRP()
    if hrp and _G.ShowKillAuraRing then
        local myChar = LocalPlayer.Character
        floorRayParams.FilterDescendantsInstances = {myChar, rangeAnchor}
        local ray = workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), floorRayParams)
        local floorY = ray and (ray.Position.Y + 0.06) or (hrp.Position.Y - 2.8)

        local radius = _G.KillAuraRange or 15
        rangeAnchor.CFrame = CFrame.new(hrp.Position.X, floorY, hrp.Position.Z)

        rangeRing.Radius = radius
        rangeRing.InnerRadius = math.max(0.1, radius - 0.35)
        rangeRing.Visible = true

        rangeFill.Radius = radius
        rangeFill.Visible = true

        if _G.AutoTagEnabled then
            rangeRing.Color3 = Color3.fromRGB(255, 45, 45)
            rangeFill.Color3 = Color3.fromRGB(255, 45, 45)
            rangeFill.Transparency = 0.85
        else
            rangeRing.Color3 = Color3.fromRGB(255, 140, 40)
            rangeFill.Color3 = Color3.fromRGB(255, 140, 40)
            rangeFill.Transparency = 0.92
        end
    else
        rangeRing.Visible = false
        rangeFill.Visible = false
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
end

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
-- [[ UI (LUMINA) ]] --
-- ============================================================
local Lumina = loadstring(game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"))()
local Window = Lumina:CreateWindow({ Title = "MoroLumina | Tag Game" })

-- ===================== COMBAT TAB =====================
local combatTab = Window:CreateTab({ Name = "Combat", Icon = "crosshair" })

combatTab:Column("left")
local auraSec = combatTab:CreateSection({ Name = "Kill Aura (Rage)", Icon = "zap" })
local auraToggle = auraSec:AddToggle({
    Name = "Auto Tag (Kill Aura)", Icon = "zap", Default = false,
    Callback = function(state) _G.AutoTagEnabled = state end,
})
auraToggle:AddKeybind({ Default = nil, Mode = "Toggle" })

auraSec:AddSlider({
    Name = "Aura Radius", Icon = "maximize",
    Min = 5, Max = 30, Default = 15, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.KillAuraRange = val end,
})
auraSec:AddToggle({
    Name = "Wall Check", Icon = "shield", Default = true,
    Callback = function(state) _G.KillAuraWallCheck = state end,
})
auraSec:AddToggle({
    Name = "Ignore Shield (NoTagBack)", Icon = "shield-check", Default = true,
    Callback = function(state) _G.IgnoreNoTagBack = state end,
})
auraSec:AddToggle({
    Name = "Show Range Ring", Icon = "circle", Default = false,
    Callback = function(state) _G.ShowKillAuraRing = state end,
})

local legitSec = combatTab:CreateSection({ Name = "Auto Tag (Legit)", Icon = "target" })
local legitToggle = legitSec:AddToggle({
    Name = "Auto Tag (Legit)", Icon = "target", Default = false,
    Callback = function(state) _G.LegitTagEnabled = state end,
})
legitToggle:AddKeybind({ Default = nil, Mode = "Toggle" })

legitSec:AddSlider({
    Name = "Legit Range", Icon = "maximize",
    Min = 5, Max = 20, Default = 12, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.LegitTagRange = val end,
})
legitSec:AddSlider({
    Name = "Cone FOV", Icon = "triangle",
    Min = 0.1, Max = 0.95, Default = 0.6, Decimals = 2,
    Callback = function(val) _G.LegitTagFOV = val end,
})
legitSec:AddToggle({
    Name = "Wall Check", Icon = "shield", Default = true,
    Callback = function(state) _G.LegitTagWallCheck = state end,
})
legitSec:AddToggle({
    Name = "Ignore Shield (NoTagBack)", Icon = "shield-check", Default = true,
    Callback = function(state) _G.IgnoreNoTagBack = state end,
})

local hitboxSec = combatTab:CreateSection({ Name = "Enemy Hitbox Expander", Icon = "box" })
hitboxSec:AddToggle({
    Name = "Expand Enemy Hitboxes", Icon = "maximize", Default = false,
    Callback = function(state) _G.HitboxExpanderEnabled = state end,
})
hitboxSec:AddSlider({
    Name = "Hitbox Size", Icon = "maximize",
    Min = 3, Max = 25, Default = 8, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.HitboxSize = val end,
})
hitboxSec:AddSlider({
    Name = "Hitbox Transparency", Icon = "sun",
    Min = 0.1, Max = 0.9, Default = 0.6, Decimals = 2,
    Callback = function(val) _G.HitboxTransparency = val end,
})

combatTab:Column("right")
local parrySec = combatTab:CreateSection({ Name = "Auto Parry", Icon = "shield" })
local parryToggle = parrySec:AddToggle({
    Name = "Auto Parry", Icon = "shield", Default = false,
    Callback = function(state)
        _G.AutoParryEnabled = state
        applyAllBoosts()
    end,
})
parryToggle:AddKeybind({ Default = nil, Mode = "Toggle" })

parrySec:AddDropdown({
    Name = "Parry Mode", Icon = "sliders",
    Options = {"Smart", "Proximity"}, Default = "Smart",
    Callback = function(val) _G.AutoParryMode = val end,
})

parrySec:AddSlider({
    Name = "Parry Radius", Icon = "maximize",
    Min = 5, Max = 25, Default = 14, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.AutoParryRange = val end,
})

parrySec:AddToggle({
    Name = "Parry Projectiles", Icon = "crosshair", Default = true,
    Callback = function(state) _G.AutoParryProjectiles = state end,
})

local combatModSec = combatTab:CreateSection({ Name = "Combat Boosters", Icon = "trending-up" })
combatModSec:AddToggle({
    Name = "Force Enable Parry (All Roles)", Icon = "shield", Default = false,
    Callback = function(state)
        _G.ForceParrying = state
        applyAllBoosts()
    end,
})
combatModSec:AddToggle({
    Name = "Tag Cooldown Booster", Icon = "clock", Default = false,
    Callback = function(state) boosters.TagCooldown.enabled = state; applyAllBoosts() end,
})
combatModSec:AddSlider({
    Name = "Cooldown Multiplier", Icon = "trending-up",
    Min = 1.0, Max = 10.0, Default = 3.0, Decimals = 1, Suffix = "x",
    Callback = function(v) boosters.TagCooldown.mult = v; applyAllBoosts() end,
})
combatModSec:AddToggle({
    Name = "Tag Range Booster", Icon = "maximize", Default = false,
    Callback = function(state) boosters.TagRange.enabled = state; applyAllBoosts() end,
})
combatModSec:AddSlider({
    Name = "Range Multiplier", Icon = "trending-up",
    Min = 1.0, Max = 5.0, Default = 2.0, Decimals = 1, Suffix = "x",
    Callback = function(v) boosters.TagRange.mult = v; applyAllBoosts() end,
})
combatModSec:AddToggle({
    Name = "Tag Knockback Booster", Icon = "wind", Default = false,
    Callback = function(state) boosters.TagKnockback.enabled = state; applyAllBoosts() end,
})
combatModSec:AddSlider({
    Name = "Knockback Multiplier", Icon = "trending-up",
    Min = 1.0, Max = 10.0, Default = 3.0, Decimals = 1, Suffix = "x",
    Callback = function(v) boosters.TagKnockback.mult = v; applyAllBoosts() end,
})

local lookSec = combatTab:CreateSection({ Name = "Target Aim / Look At", Icon = "eye" })
lookSec:AddToggle({
    Name = "Enable Look At", Icon = "eye", Default = false,
    Callback = function(state) lookAtEnabled = state end,
})

local function getPlayerNamesList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    table.sort(names)
    return names
end

local targetDrop = lookSec:AddDropdown({
    Name = "Select Target", Icon = "user",
    Options = getPlayerNamesList(),
    Default = getPlayerNamesList()[1],
    Callback = function(val) lookAtTarget = val end,
})
lookSec:AddButton({
    Name = "Refresh Players", Icon = "refresh-cw",
    Callback = function()
        local list = getPlayerNamesList()
        targetDrop.Refresh(list, true)
    end,
})

-- ===================== MOVEMENT TAB =====================
local moveTab = Window:CreateTab({ Name = "Movement", Icon = "move" })

moveTab:Column("left")
local speedSec = moveTab:CreateSection({ Name = "Locomotion", Icon = "zap" })
speedSec:AddToggle({
    Name = "Run In All Directions", Icon = "compass", Default = false,
    Callback = function(state) moveFlags.RunInAllDirections = state; applyAllBoosts() end,
})
speedSec:AddToggle({
    Name = "Speed Booster (Walk & Run)", Icon = "activity", Default = false,
    Callback = function(state) boosters.Speed.enabled = state; applyAllBoosts() end,
})
speedSec:AddSlider({
    Name = "Speed Multiplier", Icon = "trending-up",
    Min = 1.0, Max = 10.0, Default = 2.0, Decimals = 1, Suffix = "x",
    Callback = function(v) boosters.Speed.mult = v; applyAllBoosts() end,
})
speedSec:AddToggle({
    Name = "Jump Power Booster", Icon = "arrow-up", Default = false,
    Callback = function(state) boosters.Jump.enabled = state; applyAllBoosts() end,
})
speedSec:AddSlider({
    Name = "Jump Multiplier", Icon = "trending-up",
    Min = 1.0, Max = 10.0, Default = 2.5, Decimals = 1, Suffix = "x",
    Callback = function(v) boosters.Jump.mult = v; applyAllBoosts() end,
})
speedSec:AddToggle({
    Name = "Acceleration Booster", Icon = "zap", Default = false,
    Callback = function(state) boosters.Accel.enabled = state; applyAllBoosts() end,
})
speedSec:AddSlider({
    Name = "Accel Multiplier", Icon = "trending-up",
    Min = 1.0, Max = 10.0, Default = 5.0, Decimals = 1, Suffix = "x",
    Callback = function(v) boosters.Accel.mult = v; applyAllBoosts() end,
})
speedSec:AddToggle({
    Name = "Gravity Multiplier", Icon = "arrow-down", Default = false,
    Callback = function(state) boosters.Gravity.enabled = state; applyAllBoosts() end,
})
speedSec:AddSlider({
    Name = "Gravity Scale", Icon = "trending-down",
    Min = 0.1, Max = 3.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = function(v) boosters.Gravity.mult = v; applyAllBoosts() end,
})

local charScaleSec = moveTab:CreateSection({ Name = "Character Scale (Self)", Icon = "user" })
charScaleSec:AddToggle({
    Name = "Character Scale Booster", Icon = "maximize", Default = false,
    Callback = function(state) boosters.CharacterScale.enabled = state; applyAllBoosts() end,
})
charScaleSec:AddSlider({
    Name = "Scale Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 3.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = function(v) boosters.CharacterScale.mult = v; applyAllBoosts() end,
})

moveTab:Column("right")
local parkourSec = moveTab:CreateSection({ Name = "Parkour & Abilities", Icon = "sparkles" })
parkourSec:AddToggle({
    Name = "Infinite Slides", Icon = "fast-forward", Default = false,
    Callback = function(state) moveFlags.InfiniteSlides = state; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Enable Wallrunning", Icon = "chevrons-right", Default = false,
    Callback = function(state) moveFlags.EnableWallrunning = state; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Enable Tictacs", Icon = "corner-up-right", Default = false,
    Callback = function(state) moveFlags.EnableTictacs = state; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Enable Paragliding", Icon = "wind", Default = false,
    Callback = function(state) moveFlags.EnableParagliding = state; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Enable Fly Mode", Icon = "feather", Default = false,
    Callback = function(state) moveFlags.EnableFlying = state; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Slide Speed Booster", Icon = "activity", Default = false,
    Callback = function(state) boosters.SlideSpeed.enabled = state; applyAllBoosts() end,
})
parkourSec:AddSlider({
    Name = "Slide Speed Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 5.0, Default = 2.0, Decimals = 2, Suffix = "x",
    Callback = function(v) boosters.SlideSpeed.mult = v; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Slide Jump Booster", Icon = "arrow-up-right", Default = false,
    Callback = function(state) boosters.SlideJump.enabled = state; applyAllBoosts() end,
})
parkourSec:AddSlider({
    Name = "Slide Jump Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 5.0, Default = 2.0, Decimals = 2, Suffix = "x",
    Callback = function(v) boosters.SlideJump.mult = v; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Wallclimb Booster", Icon = "chevrons-up", Default = false,
    Callback = function(state) boosters.Wallclimb.enabled = state; applyAllBoosts() end,
})
parkourSec:AddSlider({
    Name = "Wallclimb Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 5.0, Default = 2.0, Decimals = 2, Suffix = "x",
    Callback = function(v) boosters.Wallclimb.mult = v; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Vault Momentum Booster", Icon = "external-link", Default = false,
    Callback = function(state) boosters.VaultMomentum.enabled = state; applyAllBoosts() end,
})
parkourSec:AddSlider({
    Name = "Vault Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 5.0, Default = 2.0, Decimals = 2, Suffix = "x",
    Callback = function(v) boosters.VaultMomentum.mult = v; applyAllBoosts() end,
})
parkourSec:AddToggle({
    Name = "Zero Friction (Ice Mode)", Icon = "snowflake", Default = false,
    Callback = function(state) moveFlags.DisableFriction = state; applyAllBoosts() end,
})

-- ===================== VISUALS TAB =====================
local visualsTab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })

visualsTab:Column("left")
local espSec = visualsTab:CreateSection({ Name = "ESP Master", Icon = "eye" })
local espToggle = espSec:AddToggle({
    Name = "Enable ESP", Icon = "eye", Default = false,
    Callback = function(state)
        _G.EspEnabled = state
        if not state and not _G.ShowTracers then
            clearAllEsp()
        end
    end,
})
espToggle:AddKeybind({ Default = nil, Mode = "Toggle" })

espSec:AddMultiDropdown({
    Name = "Filter Categories", Icon = "users",
    Options = {"Enemies", "My Team", "Frozen", "OOF", "All"},
    Default = {"Enemies"},
    Callback = function(values) selectedCategories = values or {} end,
})
espSec:AddSlider({
    Name = "Max Distance", Icon = "maximize",
    Min = 50, Max = 1500, Default = 600, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.EspMaxDistance = val end,
})

local chamsSec = visualsTab:CreateSection({ Name = "Highlights / Chams", Icon = "layers" })
chamsSec:AddToggle({
    Name = "Enable Chams", Icon = "layers", Default = true,
    Callback = function(state)
        _G.ShowHighlights = state
        if not state then
            for _, cache in pairs(espCache) do
                if cache.Highlight then cache.Highlight.Enabled = false end
            end
        end
    end,
})
chamsSec:AddSlider({
    Name = "Fill Transparency", Icon = "sun",
    Min = 0, Max = 1, Default = 0.5, Decimals = 2,
    Callback = function(val) _G.HighlightFillTransparency = val end,
})
chamsSec:AddSlider({
    Name = "Outline Transparency", Icon = "circle",
    Min = 0, Max = 1, Default = 0.0, Decimals = 2,
    Callback = function(val) _G.HighlightOutlineTransparency = val end,
})

local visualAidSec = visualsTab:CreateSection({ Name = "Visual Aids", Icon = "circle" })
visualAidSec:AddToggle({
    Name = "Show Kill Aura Ring", Icon = "circle", Default = false,
    Callback = function(state) _G.ShowKillAuraRing = state end,
})

visualsTab:Column("right")
local infoSec = visualsTab:CreateSection({ Name = "ESP Elements", Icon = "layout" })
infoSec:AddToggle({ Name = "Show Names", Icon = "user", Default = true, Callback = function(s) _G.ShowNames = s end })
infoSec:AddToggle({ Name = "Show Roles", Icon = "tag", Default = true, Callback = function(s) _G.ShowRoles = s end })
infoSec:AddToggle({ Name = "Show Distance", Icon = "map-pin", Default = true, Callback = function(s) _G.ShowDistance = s end })
infoSec:AddToggle({ Name = "Show Shield Status [SHIELD]", Icon = "shield", Default = true, Callback = function(s) _G.ShowShieldStatus = s end })
infoSec:AddToggle({
    Name = "Show 2D Boxes", Icon = "box", Default = false,
    Callback = function(state)
        _G.ShowBoxes = state
        if not state then
            for _, cache in pairs(espCache) do
                if cache.Box then cache.Box.Visible = false end
                if cache.BoxOutline then cache.BoxOutline.Visible = false end
            end
        end
    end,
})

local tracerSec = visualsTab:CreateSection({ Name = "Tracers", Icon = "crosshair" })
local tracerToggle = tracerSec:AddToggle({
    Name = "Enable Tracers", Icon = "crosshair", Default = false,
    Callback = function(state)
        _G.ShowTracers = state
        if not state then
            for _, cache in pairs(espCache) do
                if cache.Tracer then cache.Tracer.Visible = false end
            end
        end
    end,
})
tracerToggle:AddKeybind({ Default = nil, Mode = "Toggle" })

tracerSec:AddDropdown({
    Name = "Tracer Origin", Icon = "corner-down-right",
    Options = {"Bottom", "Center", "Mouse"}, Default = "Bottom",
    Callback = function(val) _G.TracerOrigin = val end,
})
tracerSec:AddSlider({
    Name = "Tracer Thickness", Icon = "trending-up",
    Min = 1.0, Max = 4.0, Default = 1.5, Decimals = 1,
    Callback = function(val) _G.TracerThickness = val end,
})

-- ===================== CURRENCY TAB =====================
local currencyTab = Window:CreateTab({ Name = "Currency", Icon = "circle-dollar-sign" })

currencyTab:Column("left")
local magnetSec = currencyTab:CreateSection({ Name = "Coin Magnet (Auto-Collect)", Icon = "zap" })
magnetSec:AddToggle({
    Name = "Auto-Collect Coins", Icon = "zap", Default = false,
    Callback = function(state) _G.AutoCollectCoins = state end,
})
magnetSec:AddDropdown({
    Name = "Collection Mode", Icon = "map",
    Options = {"Map-Wide", "Radius"}, Default = "Map-Wide",
    Callback = function(val) _G.CollectCoinsMode = val end,
})
magnetSec:AddSlider({
    Name = "Radius", Icon = "maximize",
    Min = 10, Max = 500, Default = 100, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.CollectCoinsRadius = val end,
})
magnetSec:AddSlider({
    Name = "Collect Interval", Icon = "clock",
    Min = 0.05, Max = 1.0, Default = 0.15, Decimals = 2, Suffix = "s",
    Callback = function(val) _G.CollectCoinsDelay = val end,
})
magnetSec:AddButton({
    Name = "Collect All Now (Map Wipe)", Primary = true, Icon = "check",
    Callback = function()
        local count = collectCoins(true, 5000)
        Window:Notify({ Title = "Coin Magnet", Content = "Collected " .. tostring(count) .. " coins!", Type = "Success", Duration = 2 })
    end,
})

currencyTab:Column("right")
local coinEspSec = currencyTab:CreateSection({ Name = "Currency ESP", Icon = "eye" })
coinEspSec:AddToggle({
    Name = "Enable Coin ESP", Icon = "eye", Default = false,
    Callback = function(state)
        _G.CoinEspEnabled = state
        if not state then clearAllCoinEsp() end
    end,
})
coinEspSec:AddSlider({
    Name = "Max Distance", Icon = "maximize",
    Min = 50, Max = 1500, Default = 800, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.CoinEspMaxDistance = val end,
})

-- ===================== COSMETICS TAB =====================
local cosmeticsTab = Window:CreateTab({ Name = "Cosmetics", Icon = "shirt" })

cosmeticsTab:Column("left")
local trailsSec = cosmeticsTab:CreateSection({ Name = "Trails", Icon = "sparkles" })

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

local trailNameBox = trailsSec:AddTextbox({ Name = "Trail Name (Custom)", Placeholder = "Enter model name..." })

trailsSec:AddButton({
    Name = "Equip by Custom Name", Icon = "edit",
    Callback = function()
        local name = trailNameBox.Get()
        if not name or name == "" then
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
    outfitsSec:AddLabel("No outfits found in ReplicatedStorage")
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

    local outfitNameBox = outfitsSec:AddTextbox({ Name = "Outfit Name (Custom)", Placeholder = "Enter outfit name..." })

    outfitsSec:AddButton({
        Name = "Equip by Custom Name", Icon = "edit",
        Callback = function()
            local name = outfitNameBox.Get()
            if not name or name == "" then
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

-- ===================== MISC TAB =====================
local miscTab = Window:CreateTab({ Name = "Misc", Icon = "sliders" })

miscTab:Column("left")
local autoSec = miscTab:CreateSection({ Name = "Automation", Icon = "cpu" })
autoSec:AddToggle({
    Name = "Anti-AFK", Icon = "shield-check", Default = true,
    Callback = function(state)
        _G.AntiAFK = state
        setupAntiAFK(state)
    end,
})
autoSec:AddToggle({
    Name = "Auto Rejoin on Error", Icon = "refresh-cw", Default = true,
    Callback = function(state) _G.AutoRejoin = state end,
})
autoSec:AddToggle({
    Name = "Force Unlock Tagging", Icon = "unlock", Default = true,
    Callback = function(state)
        _G.ForceUnlockTagging = state
        applyAllBoosts()
    end,
})

miscTab:Column("right")
local serverSec = miscTab:CreateSection({ Name = "Server Tools", Icon = "server" })
serverSec:AddButton({
    Name = "Rejoin Current Server", Icon = "rotate-cw",
    Callback = function()
        Window:Notify({ Title = "Server", Content = "Reconnecting...", Type = "Info", Duration = 2 })
        reconnect()
    end,
})
serverSec:AddButton({
    Name = "Server Hop (New Server)", Icon = "shuffle",
    Callback = function()
        Window:Notify({ Title = "Server", Content = "Finding a new server...", Type = "Info", Duration = 2 })
        serverHop()
    end,
})
serverSec:AddButton({
    Name = "Copy Job ID", Icon = "clipboard",
    Callback = function()
        if setclipboard then
            setclipboard(tostring(game.JobId))
            Window:Notify({ Title = "Clipboard", Content = "Copied JobId!", Type = "Success", Duration = 2 })
        else
            Window:Notify({ Title = "Clipboard", Content = "Clipboard not supported", Type = "Warning", Duration = 2 })
        end
    end,
})

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
    updateHitboxes()
end)

RunService.RenderStepped:Connect(function()
    lookAtLoop()
    updateRing()
    updateEspLoop()
    updateCoinEsp()
end)
