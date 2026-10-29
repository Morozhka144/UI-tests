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
-- В Real Executor таблица shared в песочнице скрипта изолирована от игры.
-- Настоящие множители и кулдауны лежат в getrenv().shared.
local function getGameShared()
    local renv = (getrenv and getrenv()) or {}
    return renv.shared or shared or {}
end

-- [[ Global Settings ]] --
_G.AutoTagEnabled = false
_G.KillAuraRange = 15
_G.KillAuraWallCheck = true
_G.KillAuraStrictWall = true -- не салить, если ни одной части тела цели не видно (строже обычного Wall Check)
_G.ShowKillAuraRing = false
_G.IgnoreNoTagBack = true

_G.LegitTagEnabled = false
_G.LegitTagRange = 12
_G.LegitTagFOV = 0.6
_G.LegitTagWallCheck = true
_G.AuraMode = "Rage" -- "Rage" (ближайший в радиусе) или "Legit" (только в конусе перед тобой)
_G.AuraAimSource = "Character" -- для Legit: конус от направления "Character" или "Camera"
_G.AuraFaceTarget = false
_G.AuraFaceSmooth = 0.6 -- 0 = мгновенный поворот, ближе к 1 = плавнее
_G.AuraTagDelay = 0.35
_G.Whitelist = {} -- [Player.Name] = true: этих игроков аура не трогает

_G.AutoParryEnabled = false
_G.AutoParryMode = "Smart" -- "Smart" (по анимации атаки) или "Proximity" (всегда рядом)
_G.AutoParryRange = 14
_G.AutoParryProjectiles = true
_G.ForceParrying = false

_G.EspEnabled = false
_G.EspMaxDistance = 600
_G.ShowHighlights = true
_G.HighlightFillTransparency = 0.75
_G.HighlightOutlineTransparency = 0.0
_G.EspBoxStyle = "Corners" -- "Corners" или "Full"
_G.EspBoxFill = true
_G.EspFillOpacity = 0.12
_G.EspArrows = true
_G.EspHealthBar = false
_G.EspSkeleton = false
_G.EspTextSize = 13
_G.ShowNames = true
_G.ShowRoles = true
_G.ShowDistance = true
_G.ShowShieldStatus = true
_G.ShowBoxes = true
_G.ShowTracers = false
_G.TracerOrigin = "Bottom"
_G.TracerThickness = 1.5

_G.CoinEspEnabled = false
_G.CoinEspMaxDistance = 800
_G.AutoCollectCoins = false
_G.CollectCoinsMode = "Map-Wide" -- "Map-Wide" или "Radius"
_G.CollectCoinsRadius = 100
_G.CollectCoinsDelay = 0.5

_G.AntiAFK = true
_G.AutoRejoin = true
_G.ForceUnlockTagging = true

-- [[ Helpers ]] --
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function isWhitelisted(player)
    return player ~= nil and _G.Whitelist[player.Name] == true
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
-- [[ ATTRIBUTE BOOSTERS & MOVEMENT ENGINE ]] --
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
    SlideSpeedMultiplier = 1,
    SlideJumpMultiplier = 1,
    WallclimbMultiplier = 1,
    VaultMomentumMultiplier = 1,
    GravityMultiplier = 1,
    FrictionMultiplier = 1,
}

local boosters = {}
for attr, defaultBase in pairs(baseAttributes) do
    boosters[attr] = { enabled = false, mult = 1.0, base = defaultBase }
end

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

    -- Кулдаун тага (чем меньше, тем быстрее)
    if boosters.TagCooldown.enabled then
        local cdVal = 0.666 / math.max(0.01, boosters.TagCooldown.mult)
        m.TagCooldown = cdVal
        if gShared.cooldowns and boosters.TagCooldown.mult > 1 then
            gShared.cooldowns["Tag"] = 0
        end
    else
        m.TagCooldown = 0.666
    end

    -- Дальность тага
    m.RangeMultiplier = boosters.RangeMultiplier.enabled and boosters.RangeMultiplier.mult or 1

    -- Сила отбрасывания при таге
    if boosters.TagPlayerKnockback.enabled then
        m.TagPlayerKnockback = (boosters.TagPlayerKnockback.base or 0.75) * boosters.TagPlayerKnockback.mult
    end

    -- Прямые множители движка
    local directAttrs = {
        "SlideSpeedMultiplier", "SlideJumpMultiplier", "WallclimbMultiplier",
        "VaultMomentumMultiplier", "GravityMultiplier", "FrictionMultiplier"
    }
    for _, attr in ipairs(directAttrs) do
        if boosters[attr] and boosters[attr].enabled then
            m[attr] = (boosters[attr].base or 1) * boosters[attr].mult
        end
    end

    -- Атрибуты персонажа / роли
    local roleObj = getModifiersRole()
    if roleObj then
        for attr, data in pairs(boosters) do
            if attr ~= "TagCooldown" and attr ~= "RangeMultiplier" and attr ~= "GravityMultiplier" then
                if data.enabled then
                    local baseVal = data.base or baseAttributes[attr] or 1
                    local finalVal = baseVal * data.mult
                    pcall(function() roleObj:SetAttribute(attr, finalVal) end)
                    if m[attr] ~= nil then m[attr] = finalVal end
                end
            end
        end
    end
end

local function makeBoostToggle(attr)
    return function(state)
        boosters[attr].enabled = state
        local roleObj = getModifiersRole()
        if state then
            if roleObj then
                boosters[attr].base = roleObj:GetAttribute(attr) or baseAttributes[attr]
            end
        else
            if roleObj and attr ~= "TagCooldown" and attr ~= "RangeMultiplier" then
                pcall(function() roleObj:SetAttribute(attr, boosters[attr].base or baseAttributes[attr]) end)
            end
        end
        applyAllBoosts()
    end
end

local function makeBoostSlider(attr)
    return function(v) boosters[attr].mult = v; applyAllBoosts() end
end

local function makeFlagToggle(flag)
    return function(state)
        moveFlags[flag] = state
        applyAllBoosts()
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

-- Строгая проверка: цель считается видимой, только если до ЛЮБОЙ её части тела есть прямой луч.
-- В отличие от isPlayerVisible, непрозрачные части без коллизии (декор, меши) тоже блокируют обзор,
-- а игнорируются только почти прозрачные (Transparency >= 0.85) и другие игроки.
local STRICT_PARTS = {
    "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso",
    "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}
local strictParams = RaycastParams.new()
strictParams.FilterType = Enum.RaycastFilterType.Exclude
strictParams.IgnoreWater = true
local strictCache = setmetatable({}, { __mode = "k" })

local function isFullyVisibleStrict(targetChar)
    local now = os.clock()
    local cached = strictCache[targetChar]
    if cached and now - cached.t < 0.08 then return cached.v end

    local result = false
    local myChar = LocalPlayer.Character
    local myHead = myChar and (myChar:FindFirstChild("Head") or myChar:FindFirstChild("HumanoidRootPart"))
    if myHead then
        local origin = myHead.Position
        local baseFilter = { myChar }
        for _, other in ipairs(CollectionService:GetTagged("TaggablePlayer")) do
            if other ~= targetChar and other ~= myChar then table.insert(baseFilter, other) end
        end

        for _, name in ipairs(STRICT_PARTS) do
            local part = targetChar:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                local filter = table.clone(baseFilter)
                strictParams.FilterDescendantsInstances = filter
                local from = origin
                local goal = part.Position
                for _ = 1, 4 do
                    local hit = workspace:Raycast(from, goal - from, strictParams)
                    if not hit or hit.Instance:IsDescendantOf(targetChar) then
                        result = true
                        break
                    end
                    if hit.Instance.Transparency >= 0.85 then
                        table.insert(filter, hit.Instance)
                        strictParams.FilterDescendantsInstances = filter
                        from = hit.Position
                    else
                        break
                    end
                end
                if result then break end
            end
        end
    end

    strictCache[targetChar] = { t = now, v = result }
    return result
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

local function shouldSkipTarget(char, targetPlayer, myRole)
    if isWhitelisted(targetPlayer) then return true end

    local targetRole = targetPlayer and getRole(targetPlayer)

    -- Проверка неуязвимости / щита спавна
    if _G.IgnoreNoTagBack ~= false then
        if char:GetAttribute("NoTagBack") or (targetPlayer and targetPlayer:GetAttribute("NoTagBack")) then
            return true
        end
    end

    if FFA_ROLES[myRole] then
        return targetRole and IGNORED_ROLES[targetRole] or false
    end
    if myRole == "Crown" and (targetRole == "Peasant" or targetRole == "Knight") then return true end
    if (myRole == "Chiller" or myRole == "Freezer") and targetRole == "Frozen" then return true end
    if myRole == "Runner" and targetRole == "Chiller" then return true end
    if myRole and targetRole and myRole == targetRole then return true end
    if targetRole and IGNORED_ROLES[targetRole] then return true end
    return false
end

-- Rage: ближайший в радиусе. Legit: в конусе (по горизонтали, без учёта наклона камеры) перед персонажем
-- или камерой (_G.AuraAimSource), приоритет тому кто ближе к центру конуса.
local function findAuraTarget(hrp, legit)
    local myRole = getRole(LocalPlayer)
    local myChar = LocalPlayer.Character
    local range = legit and _G.LegitTagRange or _G.KillAuraRange

    local aimFlat
    if legit then
        local look = (_G.AuraAimSource == "Camera") and Camera.CFrame.LookVector or hrp.CFrame.LookVector
        aimFlat = Vector3.new(look.X, 0, look.Z)
        if aimFlat.Magnitude < 0.01 then return nil end
        aimFlat = aimFlat.Unit
    end
    local bestDot = _G.LegitTagFOV

    local best, bestDist = nil, range

    for _, char in ipairs(CollectionService:GetTagged("TaggablePlayer")) do
        local targetHRP = char ~= myChar and char:FindFirstChild("HumanoidRootPart")
        if targetHRP and not shouldSkipTarget(char, Players:GetPlayerFromCharacter(char), myRole) then
            local delta = targetHRP.Position - hrp.Position
            local dist = delta.Magnitude
            if dist < bestDist and dist > 0 then
                local dot = 1
                local ok = true
                if legit then
                    local flat = Vector3.new(delta.X, 0, delta.Z)
                    -- почти вплотную (сверху/снизу) направление не определено: считаем что цель прямо перед нами
                    dot = flat.Magnitude < 0.5 and 1 or aimFlat:Dot(flat.Unit)
                    ok = dot > bestDot
                end
                if ok and ((not _G.KillAuraWallCheck) or isPlayerVisible(char))
                    and ((not _G.KillAuraStrictWall) or isFullyVisibleStrict(char)) then
                    bestDist = dist
                    best = char
                    if legit then bestDot = dot end
                end
            end
        end
    end
    return best
end

-- Поворот персонажа к цели. Делается в конце RenderStepped (после игрового контроллера и камеры), а
-- Humanoid.AutoRotate на это время выключается: на телефоне стик и AutoRotate иначе перебивают поворот.
local auraFaceChar = nil
local autoRotateSaved = nil

local function restoreAutoRotate()
    if autoRotateSaved == nil then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate = autoRotateSaved end
    autoRotateSaved = nil
end

local function auraFaceStep(dt)
    local target = auraFaceChar
    local hrp = getHRP()
    local targetHRP = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
    if not (_G.AutoTagEnabled and _G.AuraFaceTarget and hrp and targetHRP) then
        restoreAutoRotate()
        return
    end

    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and autoRotateSaved == nil then
        autoRotateSaved = hum.AutoRotate
        hum.AutoRotate = false
    end

    local flat = Vector3.new(targetHRP.Position.X - hrp.Position.X, 0, targetHRP.Position.Z - hrp.Position.Z)
    if flat.Magnitude < 0.05 then return end
    local goal = CFrame.lookAt(hrp.Position, hrp.Position + flat)

    local smooth = math.clamp(_G.AuraFaceSmooth or 0, 0, 0.98)
    if smooth <= 0 then
        hrp.CFrame = goal
    else
        -- не зависит от FPS: доля пути за кадр = 1 - smooth^(dt*60)
        hrp.CFrame = hrp.CFrame:Lerp(goal, 1 - smooth ^ (math.clamp(dt, 0, 0.1) * 60))
    end
    hrp.AssemblyAngularVelocity = Vector3.zero
end

pcall(function() RunService:UnbindFromRenderStep("MoroAuraFace") end)
RunService:BindToRenderStep("MoroAuraFace", Enum.RenderPriority.Last.Value, auraFaceStep)

local function compressAngle(angle)
    return math.floor((angle + math.pi) / (math.pi * 2) * 65535 + 0.5)
end

local lastAuraTag = 0

local function autoTagLoop()
    auraFaceChar = nil
    if not _G.AutoTagEnabled then return end
    local hrp = getHRP()
    if not hrp then return end

    local target = findAuraTarget(hrp, _G.AuraMode == "Legit")
    if not target then return end
    local targetHRP = target.HumanoidRootPart

    auraFaceChar = target

    -- Собственный кулдаун ауры (отдельно от TagCooldown бустера)
    if tick() - lastAuraTag < (_G.AuraTagDelay or 0) then return end

    local targetPlayer = Players:GetPlayerFromCharacter(target)
    if not targetPlayer then return end

    local success, targetID = pcall(SerialisedData.getPlayer, targetPlayer)
    if not (success and targetID) then return end

    local a1, a2, a3 = CFrame.new(hrp.Position, targetHRP.Position):ToEulerAnglesYXZ()

    local buf = buffer.create(7)
    buffer.writeu8(buf, 0, targetID)
    buffer.writeu16(buf, 1, compressAngle(a1))
    buffer.writeu16(buf, 3, compressAngle(a2))
    buffer.writeu16(buf, 5, compressAngle(a3))

    lastAuraTag = tick()
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

    -- Если враг смотрит в противоположную сторону, он не атакует нас
    if dot < -0.2 then
        return false
    end

    if _G.AutoParryMode == "Proximity" then
        return true
    end

    -- Smart Mode: Проверяем анимацию атаки/замаха у врага
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

    -- Если дистанция критически мала и враг смотрит прямо на нас
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

-- Автопарирование входящих снарядов
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
-- Drawing-based ESP. Slow data (role, shield, names, rig, chams) is refreshed ~7x/sec;
-- only projection + drawing writes run per frame, and a write is skipped when the value did not change.
local selectedCategories = {"Enemies", "Friends"}
local espCache = {}
local drawShadow = setmetatable({}, { __mode = "k" }) -- last value written to each Drawing property

local HAS_DRAWING = Drawing ~= nil and Drawing.new ~= nil
local ESP_BLACK = Color3.new(0, 0, 0)
local ESP_WHITE = Color3.new(1, 1, 1)
local ESP_DIM = Color3.fromRGB(190, 190, 200)
local FRIEND_COLOR = Color3.fromRGB(90, 255, 170)
local SHIELD_COLOR = Color3.fromRGB(255, 215, 0)
local HP_LOW = Color3.fromRGB(255, 60, 60)
local HP_HIGH = Color3.fromRGB(70, 255, 110)
local ESP_FONT = (HAS_DRAWING and Drawing.Fonts and Drawing.Fonts.Plex) or 2
local GROUP_KEYS = { "box", "corners", "fill", "text", "hp", "skel", "tracer", "arrow" }

local R15_BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6_BONES = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function shouldShowPlayer(player)
    if not player or player == LocalPlayer then return false end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if #selectedCategories == 0 then return false end

    for _, cat in ipairs(selectedCategories) do
        if cat == "All" then return true end
        if cat == "Friends" and isWhitelisted(player) then return true end
        if cat == "Enemies" and isEnemy(player) then return true end
        if cat == "My Team" and isMyTeam(player) then return true end
        if cat == "Frozen" and isFrozen(player) then return true end
        if cat == "OOF" and isDeadRole(player) then return true end
    end
    return false
end

-- [[ drawing helpers ]] --
local function newDraw(kind, props)
    local d = Drawing.new(kind)
    local shadow = {}
    drawShadow[d] = shadow
    for k, v in pairs(props) do
        d[k] = v
        shadow[k] = v
    end
    return d
end

local function put(d, k, v)
    local shadow = drawShadow[d]
    if shadow[k] ~= v then
        shadow[k] = v
        d[k] = v
    end
end

local function newGroup(list)
    return { list = list, shown = false }
end

local function showGroup(g, on)
    if not g or g.shown == on then return end
    g.shown = on
    for _, d in ipairs(g.list) do put(d, "Visible", on) end
end

local function removeGroup(g)
    if not g then return end
    for _, d in ipairs(g.list) do
        drawShadow[d] = nil
        pcall(function() d:Remove() end)
    end
end

local function ensureBox(c)
    if c.box then return c.box end
    if not HAS_DRAWING then return nil end
    c.boxOut = newDraw("Square", { Thickness = 3, Filled = false, Color = ESP_BLACK, Transparency = 0.6, Visible = false })
    c.boxMain = newDraw("Square", { Thickness = 1.5, Filled = false, Visible = false })
    c.box = newGroup({ c.boxOut, c.boxMain })
    return c.box
end

local function ensureFill(c)
    if c.fill then return c.fill end
    if not HAS_DRAWING then return nil end
    c.fillSq = newDraw("Square", { Thickness = 0, Filled = true, Visible = false })
    c.fill = newGroup({ c.fillSq })
    return c.fill
end

local function ensureCorners(c)
    if c.corners then return c.corners end
    if not HAS_DRAWING then return nil end
    local list, outs, mains = {}, {}, {}
    for i = 1, 8 do
        outs[i] = newDraw("Line", { Thickness = 3, Color = ESP_BLACK, Transparency = 0.6, Visible = false })
        list[#list + 1] = outs[i]
    end
    for i = 1, 8 do
        mains[i] = newDraw("Line", { Thickness = 1.5, Visible = false })
        list[#list + 1] = mains[i]
    end
    c.cornerOuts, c.cornerMains = outs, mains
    c.corners = newGroup(list)
    return c.corners
end

local function ensureText(c)
    if c.text then return c.text end
    if not HAS_DRAWING then return nil end
    local function mk()
        return newDraw("Text", { Center = true, Outline = true, OutlineColor = ESP_BLACK, Font = ESP_FONT, Size = 13, Visible = false })
    end
    c.nameT, c.roleT, c.distT, c.shieldT = mk(), mk(), mk(), mk()
    c.text = newGroup({ c.nameT, c.roleT, c.distT, c.shieldT })
    return c.text
end

local function ensureHp(c)
    if c.hp then return c.hp end
    if not HAS_DRAWING then return nil end
    c.hpBg = newDraw("Square", { Thickness = 0, Filled = true, Color = ESP_BLACK, Transparency = 0.7, Visible = false })
    c.hpFill = newDraw("Square", { Thickness = 0, Filled = true, Visible = false })
    c.hp = newGroup({ c.hpBg, c.hpFill })
    return c.hp
end

local function ensureSkel(c, n)
    if c.skel and #c.skel.list >= n then return c.skel end
    removeGroup(c.skel)
    if not HAS_DRAWING then return nil end
    local list = {}
    for i = 1, n do
        list[i] = newDraw("Line", { Thickness = 1.2, Visible = false })
    end
    c.skel = newGroup(list)
    return c.skel
end

local function ensureTracer(c)
    if c.tracer then return c.tracer end
    if not HAS_DRAWING then return nil end
    c.tracerLine = newDraw("Line", { Thickness = 1.5, Visible = false })
    c.tracer = newGroup({ c.tracerLine })
    return c.tracer
end

local function ensureArrow(c)
    if c.arrow then return c.arrow end
    if not HAS_DRAWING then return nil end
    c.arrowFill = newDraw("Triangle", { Filled = true, Thickness = 1, Visible = false })
    c.arrowEdge = newDraw("Triangle", { Filled = false, Thickness = 1, Color = ESP_BLACK, Transparency = 0.8, Visible = false })
    c.arrow = newGroup({ c.arrowFill, c.arrowEdge })
    return c.arrow
end

local function hideEspDrawings(c)
    for _, key in ipairs(GROUP_KEYS) do showGroup(c[key], false) end
    if c.highlight then c.highlight.Enabled = false end
end

local function hideAllEsp()
    for _, c in pairs(espCache) do hideEspDrawings(c) end
end

local function destroyEsp(c)
    for _, key in ipairs(GROUP_KEYS) do removeGroup(c[key]) end
    if c.highlight then pcall(function() c.highlight:Destroy() end) end
end

local function clearPlayerEsp(player)
    local c = espCache[player]
    if not c then return end
    destroyEsp(c)
    espCache[player] = nil
end

local function clearAllEsp()
    for player in pairs(espCache) do clearPlayerEsp(player) end
end

-- [[ slow refresh (role / shield / names / chams / rig) ]] --
local function refreshPlayerInfo(player)
    local c = espCache[player]
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not hrp or not shouldShowPlayer(player) then
        if c then
            c.show = false
            if c.highlight then c.highlight.Enabled = false end
        end
        return
    end

    if not c then
        c = {}
        espCache[player] = c
    end

    c.show = true
    c.char, c.hrp = char, hrp
    c.hum = char:FindFirstChildOfClass("Humanoid")
    c.scale = (char.GetScale and char:GetScale()) or 1

    local role = getRole(player) or "Unknown"
    local friend = isWhitelisted(player)
    local shield = (char:GetAttribute("NoTagBack") or player:GetAttribute("NoTagBack")) and true or false
    local base = friend and FRIEND_COLOR or getRoleColor(role)

    c.shield = shield
    c.friend = friend
    c.roleColor = base
    c.color = (shield and _G.ShowShieldStatus) and SHIELD_COLOR or base
    c.nameText = player.DisplayName
    c.roleText = (friend and "[FRIEND] " or "") .. string.upper(tostring(role))

    -- skeleton joints (resolved once per character, retried until the rig is complete)
    if _G.EspSkeleton and c.boneChar ~= char then
        local defs = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
        local bones = {}
        for _, def in ipairs(defs) do
            local a, b = char:FindFirstChild(def[1]), char:FindFirstChild(def[2])
            if a and b then bones[#bones + 1] = { a, b } end
        end
        c.bones = bones
        if #bones == #defs then c.boneChar = char end
    end

    -- chams
    if _G.EspEnabled and _G.ShowHighlights then
        local hl = c.highlight
        if not hl or hl.Parent ~= char then
            if hl then pcall(function() hl:Destroy() end) end
            hl = Instance.new("Highlight")
            hl.Name = "MoroEspHighlight"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
            c.highlight = hl
        end
        hl.Enabled = true
        hl.FillColor = base
        hl.OutlineColor = c.color
        hl.FillTransparency = _G.HighlightFillTransparency or 0.75
        hl.OutlineTransparency = _G.HighlightOutlineTransparency or 0
    elseif c.highlight then
        c.highlight.Enabled = false
    end
end

-- [[ per-frame drawing ]] --
local function drawBoxes(c, bx, by, bw, bh, alpha)
    local color = c.color
    local wantBox = _G.ShowBoxes
    local corners = _G.EspBoxStyle == "Corners"

    if wantBox and not corners then
        local g = ensureBox(c)
        if g then
            local size, pos = Vector2.new(bw, bh), Vector2.new(bx, by)
            put(c.boxOut, "Size", size)
            put(c.boxOut, "Position", pos)
            put(c.boxOut, "Transparency", alpha * 0.6)
            put(c.boxMain, "Size", size)
            put(c.boxMain, "Position", pos)
            put(c.boxMain, "Color", color)
            put(c.boxMain, "Transparency", alpha)
            showGroup(g, true)
        end
    else
        showGroup(c.box, false)
    end

    if wantBox and corners then
        local g = ensureCorners(c)
        if g then
            local l = math.max(4, math.floor(bw * 0.38))
            local x2, y2 = bx + bw, by + bh
            local function seg(i, x1, y1, xe, ye)
                local a, b = Vector2.new(x1, y1), Vector2.new(xe, ye)
                local o, m = c.cornerOuts[i], c.cornerMains[i]
                put(o, "From", a) put(o, "To", b) put(o, "Transparency", alpha * 0.6)
                put(m, "From", a) put(m, "To", b) put(m, "Color", color) put(m, "Transparency", alpha)
            end
            seg(1, bx, by, bx + l, by)     seg(2, bx, by, bx, by + l)
            seg(3, x2, by, x2 - l, by)     seg(4, x2, by, x2, by + l)
            seg(5, bx, y2, bx + l, y2)     seg(6, bx, y2, bx, y2 - l)
            seg(7, x2, y2, x2 - l, y2)     seg(8, x2, y2, x2, y2 - l)
            showGroup(g, true)
        end
    else
        showGroup(c.corners, false)
    end

    if wantBox and _G.EspBoxFill then
        local g = ensureFill(c)
        if g then
            put(c.fillSq, "Position", Vector2.new(bx, by))
            put(c.fillSq, "Size", Vector2.new(bw, bh))
            put(c.fillSq, "Color", color)
            put(c.fillSq, "Transparency", (_G.EspFillOpacity or 0.12) * alpha)
            showGroup(g, true)
        end
    else
        showGroup(c.fill, false)
    end
end

local function drawText(c, cx, by, bh, dist, alpha)
    local g = ensureText(c)
    if not g then return end
    g.shown = true

    local size = _G.EspTextSize or 13

    if _G.ShowNames then
        put(c.nameT, "Text", c.nameText)
        put(c.nameT, "Size", size)
        put(c.nameT, "Position", Vector2.new(cx, by - size - 4))
        put(c.nameT, "Color", ESP_WHITE)
        put(c.nameT, "Transparency", alpha)
        put(c.nameT, "Visible", true)
    else
        put(c.nameT, "Visible", false)
    end

    local y = by + bh + 2

    if _G.ShowRoles then
        put(c.roleT, "Text", c.roleText)
        put(c.roleT, "Size", size - 1)
        put(c.roleT, "Position", Vector2.new(cx, y))
        put(c.roleT, "Color", c.roleColor)
        put(c.roleT, "Transparency", alpha)
        put(c.roleT, "Visible", true)
        y = y + size
    else
        put(c.roleT, "Visible", false)
    end

    if _G.ShowDistance then
        local di = math.floor(dist)
        if c.distInt ~= di then
            c.distInt = di
            c.distStr = di .. "m"
        end
        put(c.distT, "Text", c.distStr)
        put(c.distT, "Size", size - 2)
        put(c.distT, "Position", Vector2.new(cx, y))
        put(c.distT, "Color", ESP_DIM)
        put(c.distT, "Transparency", alpha)
        put(c.distT, "Visible", true)
        y = y + size - 1
    else
        put(c.distT, "Visible", false)
    end

    if _G.ShowShieldStatus and c.shield then
        put(c.shieldT, "Text", "SHIELD")
        put(c.shieldT, "Size", size - 2)
        put(c.shieldT, "Position", Vector2.new(cx, y))
        put(c.shieldT, "Color", SHIELD_COLOR)
        put(c.shieldT, "Transparency", alpha)
        put(c.shieldT, "Visible", true)
    else
        put(c.shieldT, "Visible", false)
    end
end

local function drawHealth(c, bx, by, bh)
    local hum = c.hum
    if not (_G.EspHealthBar and hum and hum.Parent and hum.MaxHealth > 0) then
        showGroup(c.hp, false)
        return
    end
    local g = ensureHp(c)
    if not g then return end
    local f = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
    local fillH = math.max(1, math.floor(bh * f + 0.5))
    put(c.hpBg, "Position", Vector2.new(bx - 6, by - 1))
    put(c.hpBg, "Size", Vector2.new(4, bh + 2))
    put(c.hpFill, "Position", Vector2.new(bx - 5, by + bh - fillH))
    put(c.hpFill, "Size", Vector2.new(2, fillH))
    put(c.hpFill, "Color", HP_LOW:Lerp(HP_HIGH, f))
    showGroup(g, true)
end

local function drawSkeleton(c, alpha, dist)
    local bones = c.bones
    if not (_G.EspSkeleton and bones and #bones > 0 and dist < 250) then
        showGroup(c.skel, false)
        return
    end
    local g = ensureSkel(c, #bones)
    if not g then return end
    g.shown = true
    local color = c.color
    for i = 1, #bones do
        local a, b = bones[i][1], bones[i][2]
        local line = g.list[i]
        local visible = false
        if a.Parent and b.Parent then
            local pa = Camera:WorldToViewportPoint(a.Position)
            local pb = Camera:WorldToViewportPoint(b.Position)
            if pa.Z > 0 and pb.Z > 0 then
                put(line, "From", Vector2.new(pa.X, pa.Y))
                put(line, "To", Vector2.new(pb.X, pb.Y))
                put(line, "Color", color)
                put(line, "Transparency", alpha)
                visible = true
            end
        end
        put(line, "Visible", visible)
    end
end

local function drawTracer(c, origin, cx, footY, alpha)
    local g = ensureTracer(c)
    if not g then return end
    put(c.tracerLine, "From", origin)
    put(c.tracerLine, "To", Vector2.new(cx, footY))
    put(c.tracerLine, "Color", c.color)
    put(c.tracerLine, "Thickness", _G.TracerThickness or 1.5)
    put(c.tracerLine, "Transparency", alpha)
    showGroup(g, true)
end

local function drawArrow(c, pos, vp, alpha)
    local g = ensureArrow(c)
    if not g then return end
    local rel = Camera.CFrame:PointToObjectSpace(pos)
    local dir = Vector2.new(rel.X, rel.Z)
    if dir.Magnitude < 0.001 then
        showGroup(g, false)
        return
    end
    dir = dir.Unit
    local radius = math.min(vp.X, vp.Y) * 0.34
    local p = Vector2.new(vp.X / 2, vp.Y / 2) + dir * radius
    local perp = Vector2.new(-dir.Y, dir.X)
    local a = p + dir * 11
    local b = p - dir * 7 + perp * 8
    local d = p - dir * 7 - perp * 8
    for _, tri in ipairs({ c.arrowFill, c.arrowEdge }) do
        put(tri, "PointA", a)
        put(tri, "PointB", b)
        put(tri, "PointC", d)
    end
    put(c.arrowFill, "Color", c.color)
    put(c.arrowFill, "Transparency", alpha)
    showGroup(g, true)
end

local function drawPlayerEsp(c, myPos, tracerOrigin, vp)
    local hrp = c.hrp
    if not hrp or not hrp.Parent then
        hideEspDrawings(c)
        return
    end

    local pos = hrp.Position
    local dist = (pos - myPos).Magnitude
    local maxDist = _G.EspMaxDistance or 600
    if dist > maxDist then
        hideEspDrawings(c)
        return
    end

    local s = c.scale or 1
    local top, topOn = Camera:WorldToViewportPoint(pos + Vector3.new(0, 2.9 * s, 0))
    local bot, botOn = Camera:WorldToViewportPoint(pos - Vector3.new(0, 3.1 * s, 0))
    local inFront = top.Z > 0 and bot.Z > 0
    local onScreen = inFront and (topOn or botOn)
    local alpha = math.floor((1 - (dist / maxDist) ^ 2 * 0.55) * 10 + 0.5) / 10

    local master = _G.EspEnabled

    if master and onScreen then
        local bh = math.max(8, math.floor(bot.Y - top.Y + 0.5))
        local bw = math.floor(bh * 0.55 + 0.5)
        local cx = math.floor((top.X + bot.X) / 2 + 0.5)
        local bx = cx - math.floor(bw / 2)
        local by = math.floor(top.Y + 0.5)

        drawBoxes(c, bx, by, bw, bh, alpha)
        drawText(c, cx, by, bh, dist, alpha)
        drawHealth(c, bx, by, bh)
        drawSkeleton(c, alpha, dist)
    else
        showGroup(c.box, false)
        showGroup(c.corners, false)
        showGroup(c.fill, false)
        showGroup(c.text, false)
        showGroup(c.hp, false)
        showGroup(c.skel, false)
    end

    if master and _G.EspArrows and not onScreen then
        drawArrow(c, pos, vp, alpha)
    else
        showGroup(c.arrow, false)
    end

    if _G.ShowTracers and inFront then
        drawTracer(c, tracerOrigin, math.floor((top.X + bot.X) / 2 + 0.5), bot.Y, alpha)
    else
        showGroup(c.tracer, false)
    end
end

local lastEspRefresh = 0
local espWasActive = false

local function updateEspLoop()
    if not _G.EspEnabled and not _G.ShowTracers then
        if espWasActive then
            espWasActive = false
            hideAllEsp()
        end
        return
    end
    espWasActive = true

    local now = os.clock()
    if now - lastEspRefresh >= 0.15 then
        lastEspRefresh = now
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then refreshPlayerInfo(player) end
        end
    end

    local myHRP = getHRP()
    local myPos = myHRP and myHRP.Position or Camera.CFrame.Position
    local vp = Camera.ViewportSize
    local origin
    if _G.TracerOrigin == "Center" then
        origin = Vector2.new(vp.X / 2, vp.Y / 2)
    elseif _G.TracerOrigin == "Mouse" then
        origin = UserInputService:GetMouseLocation()
    else
        origin = Vector2.new(vp.X / 2, vp.Y)
    end

    for _, c in pairs(espCache) do
        if c.show then
            drawPlayerEsp(c, myPos, origin, vp)
        else
            hideEspDrawings(c)
        end
    end
end

local function setupPlayerListeners(player)
    if player == LocalPlayer then return end
    local function resetChar()
        local c = espCache[player]
        if not c then return end
        hideEspDrawings(c)
        c.show = false
        c.boneChar, c.bones = nil, nil
        if c.highlight then
            pcall(function() c.highlight:Destroy() end)
            c.highlight = nil
        end
    end
    player.CharacterAdded:Connect(resetChar)
    player.CharacterRemoving:Connect(resetChar)
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

-- Сбор монет (безопасный — CFrame-телепорт + рандомизация)
-- Настройки анти-кика
_G.CollectCoinsPerCycle = _G.CollectCoinsPerCycle or 5       -- макс монет за один цикл
_G.CollectCoinsTouchHold = _G.CollectCoinsTouchHold or 0.12  -- удержание touch (сек)
_G.CollectCoinsJitter = _G.CollectCoinsJitter or true        -- случайный разброс задержки

local coinCollectBusy = false

local function randDelay(base)
    if _G.CollectCoinsJitter then
        return base + (math.random() * base * 0.6)  -- +0..60% разброс
    end
    return base
end

-- Сортируем монеты по расстоянию — ближайшие первыми (выглядит естественнее)
local function getSortedCoins(myPos, mapWide, maxRadius)
    local results = {}
    local currencyFolders = {"coins", "specialcurrency", "doublecoins", "doublecoinsLegacy"}

    for _, fName in ipairs(currencyFolders) do
        local folder = workspace:FindFirstChild(fName)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                if part and part.Parent then
                    local dist = (part.Position - myPos).Magnitude
                    if mapWide or dist <= (maxRadius or 100) then
                        table.insert(results, {part = part, dist = dist})
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b) return a.dist < b.dist end)
    return results
end

local function collectCoins(mapWide, maxRadius)
    if coinCollectBusy then return 0 end
    coinCollectBusy = true

    local hrp = getHRP()
    if not hrp then coinCollectBusy = false; return 0 end

    local originalCFrame = hrp.CFrame
    local myPos = hrp.Position
    local count = 0
    local limit = _G.CollectCoinsPerCycle or 3
    local holdTime = _G.CollectCoinsTouchHold or 0.12

    local sorted = getSortedCoins(myPos, mapWide, maxRadius)

    for i, entry in ipairs(sorted) do
        if count >= limit then break end

        local part = entry.part
        if not part or not part.Parent then continue end

        local ok = pcall(function()
            -- Телепорт вплотную к монете (со сдвигом ~1 stud чтобы не застрять)
            local coinPos = part.Position
            local offset = Vector3.new(
                (math.random() - 0.5) * 1.5,
                0,
                (math.random() - 0.5) * 1.5
            )
            hrp.CFrame = CFrame.new(coinPos + offset)

            -- Подождать чтобы сервер "увидел" позицию
            task.wait(randDelay(0.04))

            -- Touch
            firetouchinterest(hrp, part, 0)
            task.wait(randDelay(holdTime))
            firetouchinterest(hrp, part, 1)

            count = count + 1
        end)

        -- Задержка между монетами
        if ok and count < limit then
            task.wait(randDelay(0.08))
        end
    end

    -- Вернуть персонажа на исходную позицию
    pcall(function()
        if hrp and hrp.Parent then
            hrp.CFrame = originalCFrame
        end
    end)

    coinCollectBusy = false
    return count
end

-- Фоновый поток автосбора монет (с безопасным интервалом)
task.spawn(function()
    while true do
        local interval = math.max(0.3, _G.CollectCoinsDelay or 0.5)
        task.wait(interval)
        if _G.AutoCollectCoins then
            local isMapWide = (_G.CollectCoinsMode == "Map-Wide")
            pcall(function()
                collectCoins(isMapWide, _G.CollectCoinsRadius or 100)
            end)
        end
    end
end)

-- ============================================================
-- [[ FLY-COLLECT ALL (Noclip + скоростной пролёт) ]] --
-- ============================================================
_G.FlyCollectSpeed = _G.FlyCollectSpeed or 999
local flyCollectRunning = false

local function setNoclip(char, state)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not state
        end
    end
end

-- Ближайший сосед: каждый раз летим к самой близкой оставшейся монете
local function nearestNeighborSort(coins, startPos)
    local ordered = {}
    local remaining = {}
    for i, c in ipairs(coins) do
        remaining[i] = c
    end

    local currentPos = startPos
    while #remaining > 0 do
        local bestIdx, bestDist = 1, math.huge
        for i, c in ipairs(remaining) do
            local d = (c.part.Position - currentPos).Magnitude
            if d < bestDist then
                bestDist = d
                bestIdx = i
            end
        end
        local chosen = table.remove(remaining, bestIdx)
        currentPos = chosen.part.Position
        table.insert(ordered, chosen)
    end
    return ordered
end

local function flyCollectAll()
    if flyCollectRunning then return 0 end
    if coinCollectBusy then return 0 end
    flyCollectRunning = true
    coinCollectBusy = true

    local hrp = getHRP()
    local char = LocalPlayer.Character
    if not hrp or not char then
        flyCollectRunning = false
        coinCollectBusy = false
        return 0
    end

    local originalCFrame = hrp.CFrame
    local count = 0
    local speed = _G.FlyCollectSpeed or 600

    -- Собираем все монеты на карте
    local allCoins = getSortedCoins(hrp.Position, true, 99999)
    if #allCoins == 0 then
        flyCollectRunning = false
        coinCollectBusy = false
        return 0
    end

    -- Оптимальный маршрут (nearest neighbor)
    local route = nearestNeighborSort(allCoins, hrp.Position)

    -- Сохраняем оригинальное состояние коллизии
    local originalCollisions = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollisions[part] = part.CanCollide
        end
    end

    -- Включаем ноуклип
    setNoclip(char, true)

    -- Подключаем Stepped чтобы ноуклип не сбрасывался физикой
    local noclipConn
    noclipConn = RunService.Stepped:Connect(function()
        if flyCollectRunning and char and char.Parent then
            setNoclip(char, true)
        end
    end)

    -- Отключаем гравитацию на время пролёта
    local hum = char:FindFirstChildOfClass("Humanoid")
    local bodyVel, bodyGyro
    pcall(function()
        -- BodyVelocity чтобы не падать
        bodyVel = Instance.new("BodyVelocity")
        bodyVel.Velocity = Vector3.zero
        bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVel.P = 1e5
        bodyVel.Parent = hrp

        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bodyGyro.P = 1e5
        bodyGyro.Parent = hrp
    end)

    -- Летим по маршруту
    for _, entry in ipairs(route) do
        local part = entry.part
        if not part or not part.Parent then continue end
        if not hrp or not hrp.Parent then break end

        local targetPos = part.Position
        local startPos = hrp.Position
        local direction = targetPos - startPos
        local distance = direction.Magnitude

        if distance < 2 then
            -- Уже рядом, просто собираем
            pcall(function()
                hrp.CFrame = CFrame.new(targetPos)
                if bodyVel then bodyVel.Velocity = Vector3.zero end
                if bodyGyro then bodyGyro.CFrame = hrp.CFrame end
            end)
        else
            -- Плавный пролёт с CFrame на каждый фрейм
            local flyTime = distance / speed
            local elapsed = 0

            while elapsed < flyTime do
                if not hrp or not hrp.Parent then break end
                if not part or not part.Parent then break end

                local dt = RunService.Heartbeat:Wait()
                elapsed = elapsed + dt

                local alpha = math.min(elapsed / flyTime, 1)
                -- Обновляем targetPos на случай если монета двигалась
                local curTarget = (part and part.Parent) and part.Position or targetPos
                local newPos = startPos:Lerp(curTarget, alpha)
                local lookDir = (curTarget - newPos)
                if lookDir.Magnitude > 0.1 then
                    hrp.CFrame = CFrame.new(newPos, newPos + lookDir)
                else
                    hrp.CFrame = CFrame.new(newPos)
                end

                if bodyVel then bodyVel.Velocity = Vector3.zero end
                if bodyGyro then bodyGyro.CFrame = hrp.CFrame end
            end
        end

        -- Финальная позиция точно на монете и сбор
        if part and part.Parent and hrp and hrp.Parent then
            pcall(function()
                hrp.CFrame = CFrame.new(part.Position)
                if bodyVel then bodyVel.Velocity = Vector3.zero end
            end)

            task.wait(0.03)

            pcall(function()
                firetouchinterest(hrp, part, 0)
                task.wait(0.06)
                firetouchinterest(hrp, part, 1)
            end)

            count = count + 1
            task.wait(0.02)
        end
    end

    -- Возвращаемся на исходную позицию
    if hrp and hrp.Parent then
        local returnDist = (hrp.Position - originalCFrame.Position).Magnitude
        local returnTime = math.max(0.15, returnDist / speed)
        local startPos = hrp.Position
        local elapsed = 0

        while elapsed < returnTime do
            if not hrp or not hrp.Parent then break end
            local dt = RunService.Heartbeat:Wait()
            elapsed = elapsed + dt
            local alpha = math.min(elapsed / returnTime, 1)
            local newPos = startPos:Lerp(originalCFrame.Position, alpha)
            hrp.CFrame = CFrame.new(newPos) * (originalCFrame - originalCFrame.Position)
            if bodyVel then bodyVel.Velocity = Vector3.zero end
            if bodyGyro then bodyGyro.CFrame = hrp.CFrame end
        end

        pcall(function() hrp.CFrame = originalCFrame end)
    end

    -- Убираем body movers
    pcall(function() if bodyVel then bodyVel:Destroy() end end)
    pcall(function() if bodyGyro then bodyGyro:Destroy() end end)

    -- Отключаем ноуклип-апдейт
    if noclipConn then
        pcall(function() noclipConn:Disconnect() end)
    end

    -- Восстанавливаем коллизии
    for part, wasCollide in pairs(originalCollisions) do
        pcall(function()
            if part and part.Parent then
                part.CanCollide = wasCollide
            end
        end)
    end

    flyCollectRunning = false
    coinCollectBusy = false
    return count
end

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
-- MoroElite from GitHub (cached to MoroElite.lua); the cache is only used when GitHub is unreachable
local Lumina
do
    local okGet, src = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/main/MoroElite.lua") end)
    local fn = okGet and type(src) == "string" and #src > 1000 and loadstring(src)
    if fn then
        Lumina = fn()
        if Lumina and writefile then pcall(writefile, "MoroElite.lua", src) end
    elseif isfile and isfile("MoroElite.lua") then
        Lumina = loadstring(readfile("MoroElite.lua"))()
    end
    assert(Lumina, "[Moro] Failed to load MoroElite UI library")
end
local Window = Lumina:CreateWindow({ Title = "MoroLumina | Tag Game" })

-- ===================== COMBAT TAB =====================
local combatTab = Window:CreateTab({ Name = "Combat", Icon = "crosshair" })

combatTab:Column("left")
local auraSec = combatTab:CreateSection({ Name = "Tag Aura", Icon = "zap" })
local auraToggle = auraSec:AddToggle({
    Name = "Auto Tag (Aura)", Icon = "zap", Default = false,
    Callback = function(state) _G.AutoTagEnabled = state end,
})
auraToggle:AddKeybind({ Default = nil, Mode = "Toggle" })

auraSec:AddDropdown({
    Name = "Aura Mode", Icon = "target",
    Options = {"Rage", "Legit"}, Default = "Rage",
    Callback = function(val) _G.AuraMode = val end,
})
auraSec:AddDropdown({
    Name = "Legit Aim Source", Icon = "crosshair",
    Options = {"Character", "Camera"}, Default = "Character",
    Callback = function(val) _G.AuraAimSource = val end,
})
auraSec:AddToggle({
    Name = "Face Target", Icon = "rotate-cw", Default = false,
    Callback = function(state) _G.AuraFaceTarget = state end,
})
auraSec:AddSlider({
    Name = "Rotation Smoothness", Icon = "sliders",
    Min = 0, Max = 0.95, Default = 0.6, Decimals = 2,
    Callback = function(val) _G.AuraFaceSmooth = val end,
})
auraSec:AddSlider({
    Name = "Tag Delay (aura cooldown)", Icon = "clock",
    Min = 0, Max = 2, Default = 0.35, Decimals = 2, Suffix = " s",
    Callback = function(val) _G.AuraTagDelay = val end,
})
auraSec:AddSlider({
    Name = "Aura Radius (Rage)", Icon = "maximize",
    Min = 5, Max = 25, Default = 15, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.KillAuraRange = val end,
})
auraSec:AddSlider({
    Name = "Legit Range", Icon = "maximize",
    Min = 5, Max = 20, Default = 12, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.LegitTagRange = val end,
})
auraSec:AddSlider({
    Name = "Legit Cone FOV", Icon = "triangle",
    Min = 0.1, Max = 0.95, Default = 0.6, Decimals = 2,
    Callback = function(val) _G.LegitTagFOV = val end,
})
auraSec:AddToggle({
    Name = "Wall Check", Icon = "shield", Default = true,
    Callback = function(state) _G.KillAuraWallCheck = state end,
})
auraSec:AddToggle({
    Name = "Strict Wall Check (no tag through walls)", Icon = "shield-alert", Default = true,
    Callback = function(state) _G.KillAuraStrictWall = state end,
})
auraSec:AddToggle({
    Name = "Ignore Shield (NoTagBack)", Icon = "shield-check", Default = true,
    Callback = function(state) _G.IgnoreNoTagBack = state end,
})
auraSec:AddToggle({
    Name = "Show Range Ring", Icon = "circle", Default = false,
    Callback = function(state) _G.ShowKillAuraRing = state end,
})

local wlSec = combatTab:CreateSection({ Name = "Whitelist", Icon = "users" })

local function playerNameList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    table.sort(names)
    return names
end

local wlDrop = wlSec:AddMultiDropdown({
    Name = "Never Tag / Show as Friend", Icon = "users",
    Options = playerNameList(), Default = {}, Placeholder = "None",
    Callback = function(values)
        local w = {}
        for _, n in ipairs(values or {}) do w[n] = true end
        _G.Whitelist = w
    end,
})
wlSec:AddButton({
    Name = "Add Roblox Friends In Server", Icon = "users",
    Callback = function()
        local names = wlDrop.Get() or {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, isFriend = pcall(LocalPlayer.IsFriendsWith, LocalPlayer, p.UserId)
                if ok and isFriend then table.insert(names, p.Name) end
            end
        end
        wlDrop.Set(names)
    end,
})
wlSec:AddButton({
    Name = "Clear Whitelist", Icon = "x",
    Callback = function() wlDrop.ClearAll() end,
})

local function refreshWhitelistList()
    wlDrop.Refresh(playerNameList(), true)
end
Players.PlayerAdded:Connect(function() task.defer(refreshWhitelistList) end)
Players.PlayerRemoving:Connect(function() task.defer(refreshWhitelistList) end)

combatTab:Column("right")
local parrySec =combatTab:CreateSection({ Name = "Auto Parry", Icon = "shield" })
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
    Callback = makeBoostToggle("TagCooldown"),
})
combatModSec:AddSlider({
    Name = "Cooldown Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("TagCooldown"),
})
combatModSec:AddToggle({
    Name = "Tag Range Booster", Icon = "maximize", Default = false,
    Callback = makeBoostToggle("RangeMultiplier"),
})
combatModSec:AddSlider({
    Name = "Range Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("RangeMultiplier"),
})
combatModSec:AddToggle({
    Name = "Tag Knockback Booster", Icon = "wind", Default = false,
    Callback = makeBoostToggle("TagPlayerKnockback"),
})
combatModSec:AddSlider({
    Name = "Knockback Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("TagPlayerKnockback"),
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
    Callback = makeFlagToggle("RunInAllDirections"),
})
speedSec:AddToggle({
    Name = "Acceleration Booster", Icon = "zap", Default = false,
    Callback = makeBoostToggle("AccelerationMultiplier"),
})
speedSec:AddSlider({
    Name = "Accel Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 10.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("AccelerationMultiplier"),
})
speedSec:AddToggle({
    Name = "Run Speed Booster", Icon = "activity", Default = false,
    Callback = makeBoostToggle("RunSpeedMultiplier"),
})
speedSec:AddSlider({
    Name = "Run Speed Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 3.0, Default = 1.1, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("RunSpeedMultiplier"),
})
speedSec:AddToggle({
    Name = "Jump Power Booster", Icon = "arrow-up", Default = false,
    Callback = makeBoostToggle("JumpPowerMultiplier"),
})
speedSec:AddSlider({
    Name = "Jump Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("JumpPowerMultiplier"),
})
speedSec:AddToggle({
    Name = "Gravity Multiplier", Icon = "arrow-down", Default = false,
    Callback = makeBoostToggle("GravityMultiplier"),
})
speedSec:AddSlider({
    Name = "Gravity Scale", Icon = "trending-down",
    Min = 0.1, Max = 3.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("GravityMultiplier"),
})

local hitboxSec = moveTab:CreateSection({ Name = "Character Scale", Icon = "user" })
hitboxSec:AddToggle({
    Name = "Body Size Booster", Icon = "maximize", Default = false,
    Callback = makeBoostToggle("SizeMultiplier"),
})
hitboxSec:AddSlider({
    Name = "Body Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("SizeMultiplier"),
})
hitboxSec:AddToggle({
    Name = "Head Size Booster", Icon = "circle", Default = false,
    Callback = makeBoostToggle("HeadSizeMultiplier"),
})
hitboxSec:AddSlider({
    Name = "Head Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("HeadSizeMultiplier"),
})

moveTab:Column("right")
local parkourSec = moveTab:CreateSection({ Name = "Parkour & Abilities", Icon = "sparkles" })
parkourSec:AddToggle({
    Name = "Infinite Slides", Icon = "fast-forward", Default = false,
    Callback = makeFlagToggle("InfiniteSlides"),
})
parkourSec:AddToggle({
    Name = "Enable Wallrunning", Icon = "chevrons-right", Default = false,
    Callback = makeFlagToggle("EnableWallrunning"),
})
parkourSec:AddToggle({
    Name = "Enable Tictacs", Icon = "corner-up-right", Default = false,
    Callback = makeFlagToggle("EnableTictacs"),
})
parkourSec:AddToggle({
    Name = "Enable Paragliding", Icon = "wind", Default = false,
    Callback = makeFlagToggle("EnableParagliding"),
})
parkourSec:AddToggle({
    Name = "Enable Fly Mode", Icon = "feather", Default = false,
    Callback = makeFlagToggle("EnableFlying"),
})
parkourSec:AddToggle({
    Name = "Slide Speed Booster", Icon = "activity", Default = false,
    Callback = makeBoostToggle("SlideSpeedMultiplier"),
})
parkourSec:AddSlider({
    Name = "Slide Speed Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("SlideSpeedMultiplier"),
})
parkourSec:AddToggle({
    Name = "Slide Jump Booster", Icon = "arrow-up-right", Default = false,
    Callback = makeBoostToggle("SlideJumpMultiplier"),
})
parkourSec:AddSlider({
    Name = "Slide Jump Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("SlideJumpMultiplier"),
})
parkourSec:AddToggle({
    Name = "Wallclimb Booster", Icon = "chevrons-up", Default = false,
    Callback = makeBoostToggle("WallclimbMultiplier"),
})
parkourSec:AddSlider({
    Name = "Wallclimb Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("WallclimbMultiplier"),
})
parkourSec:AddToggle({
    Name = "Vault Momentum Booster", Icon = "external-link", Default = false,
    Callback = makeBoostToggle("VaultMomentumMultiplier"),
})
parkourSec:AddSlider({
    Name = "Vault Multiplier", Icon = "trending-up",
    Min = 0.5, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("VaultMomentumMultiplier"),
})

local momentumSec = moveTab:CreateSection({ Name = "Momentum & Friction", Icon = "activity" })
momentumSec:AddToggle({
    Name = "Momentum Booster", Icon = "activity", Default = false,
    Callback = makeBoostToggle("MomentumMultiplier"),
})
momentumSec:AddSlider({
    Name = "Momentum Multiplier", Icon = "trending-up",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("MomentumMultiplier"),
})
momentumSec:AddToggle({
    Name = "Momentum Decay Booster", Icon = "trending-down", Default = false,
    Callback = makeBoostToggle("MomentumDecayMultiplier"),
})
momentumSec:AddSlider({
    Name = "Decay Multiplier", Icon = "trending-down",
    Min = 0.1, Max = 5.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("MomentumDecayMultiplier"),
})
momentumSec:AddToggle({
    Name = "Friction Decay Booster", Icon = "wind", Default = false,
    Callback = makeBoostToggle("FrictionDecayMultiplier"),
})
momentumSec:AddSlider({
    Name = "Friction Multiplier", Icon = "wind",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("FrictionDecayMultiplier"),
})
momentumSec:AddToggle({
    Name = "Zero Friction (Ice Mode)", Icon = "snowflake", Default = false,
    Callback = makeFlagToggle("DisableFriction"),
})

local perksSec = moveTab:CreateSection({ Name = "Movement Perks", Icon = "sparkles" })
perksSec:AddToggle({
    Name = "Window Smash Booster", Icon = "box", Default = false,
    Callback = makeBoostToggle("WindowSmashMultiplier"),
})
perksSec:AddSlider({
    Name = "Window Multiplier", Icon = "box",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("WindowSmashMultiplier"),
})
perksSec:AddToggle({
    Name = "Roll Boost Booster", Icon = "rotate-cw", Default = false,
    Callback = makeBoostToggle("RollBoostMultiplier"),
})
perksSec:AddSlider({
    Name = "Roll Multiplier", Icon = "rotate-cw",
    Min = 0.1, Max = 10.0, Default = 1.0, Decimals = 2, Suffix = "x",
    Callback = makeBoostSlider("RollBoostMultiplier"),
})

-- ===================== VISUALS TAB =====================
local visualsTab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })

visualsTab:Column("left")
local espSec = visualsTab:CreateSection({ Name = "ESP Master", Icon = "eye" })
local espToggle = espSec:AddToggle({
    Name = "Enable ESP", Icon = "eye", Default = false,
    Callback = function(state)
        _G.EspEnabled = state
        if not state then hideAllEsp() end
    end,
})
espToggle:AddKeybind({ Default = nil, Mode = "Toggle" })

espSec:AddMultiDropdown({
    Name = "Filter Categories", Icon = "users",
    Options = {"Enemies", "Friends", "My Team", "Frozen", "OOF", "All"},
    Default = {"Enemies", "Friends"},
    Callback = function(values) selectedCategories = values or {} end,
})
espSec:AddSlider({
    Name = "Max Distance", Icon = "maximize",
    Min = 50, Max = 1500, Default = 600, Decimals = 0, Suffix = " studs",
    Callback = function(val) _G.EspMaxDistance = val end,
})

local boxSec = visualsTab:CreateSection({ Name = "Boxes", Icon = "box" })
boxSec:AddToggle({
    Name = "Show Boxes", Icon = "box", Default = true,
    Callback = function(state) _G.ShowBoxes = state end,
})
boxSec:AddDropdown({
    Name = "Box Style", Icon = "layout",
    Options = {"Corners", "Full"}, Default = "Corners",
    Callback = function(val) _G.EspBoxStyle = val end,
})
boxSec:AddToggle({
    Name = "Box Fill", Icon = "layers", Default = true,
    Callback = function(state) _G.EspBoxFill = state end,
})
boxSec:AddSlider({
    Name = "Fill Opacity", Icon = "sun",
    Min = 0.02, Max = 0.5, Default = 0.12, Decimals = 2,
    Callback = function(val) _G.EspFillOpacity = val end,
})

local chamsSec = visualsTab:CreateSection({ Name = "Highlights / Chams", Icon = "layers" })
chamsSec:AddToggle({
    Name = "Enable Chams", Icon = "layers", Default = true,
    Callback = function(state) _G.ShowHighlights = state end,
})
chamsSec:AddSlider({
    Name = "Fill Transparency", Icon = "sun",
    Min = 0, Max = 1, Default = 0.75, Decimals = 2,
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
visualAidSec:AddToggle({
    Name = "Off-screen Arrows", Icon = "navigation", Default = true,
    Callback = function(state) _G.EspArrows = state end,
})

visualsTab:Column("right")
local infoSec = visualsTab:CreateSection({ Name = "ESP Elements", Icon = "layout" })
infoSec:AddToggle({ Name = "Show Names", Icon = "user", Default = true, Callback = function(s) _G.ShowNames = s end })
infoSec:AddToggle({ Name = "Show Roles", Icon = "tag", Default = true, Callback = function(s) _G.ShowRoles = s end })
infoSec:AddToggle({ Name = "Show Distance", Icon = "map-pin", Default = true, Callback = function(s) _G.ShowDistance = s end })
infoSec:AddToggle({ Name = "Show Shield Status [SHIELD]", Icon = "shield", Default = true, Callback = function(s) _G.ShowShieldStatus = s end })
infoSec:AddToggle({ Name = "Health Bar", Icon = "heart", Default = false, Callback = function(s) _G.EspHealthBar = s end })
infoSec:AddToggle({ Name = "Skeleton", Icon = "user", Default = false, Callback = function(s) _G.EspSkeleton = s end })
infoSec:AddSlider({
    Name = "Text Size", Icon = "type",
    Min = 10, Max = 20, Default = 13, Decimals = 0,
    Callback = function(val) _G.EspTextSize = val end,
})

local tracerSec = visualsTab:CreateSection({ Name = "Tracers", Icon = "crosshair" })
local tracerToggle = tracerSec:AddToggle({
    Name = "Enable Tracers", Icon = "crosshair", Default = false,
    Callback = function(state) _G.ShowTracers = state end,
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
    Min = 0.3, Max = 2.0, Default = 0.5, Decimals = 2, Suffix = "s",
    Callback = function(val) _G.CollectCoinsDelay = val end,
})
magnetSec:AddSlider({
    Name = "Coins Per Cycle", Icon = "layers",
    Min = 1, Max = 10, Default = 3, Decimals = 0,
    Callback = function(val) _G.CollectCoinsPerCycle = val end,
})
magnetSec:AddSlider({
    Name = "Fly Speed", Icon = "rocket",
    Min = 100, Max = 2000, Default = 600, Decimals = 0, Suffix = " studs/s",
    Callback = function(val) _G.FlyCollectSpeed = val end,
})
magnetSec:AddButton({
    Name = "Fly & Collect All (Noclip)", Primary = true, Icon = "rocket",
    Callback = function()
        if flyCollectRunning then
            Window:Notify({ Title = "Coin Magnet", Content = "Already flying!", Type = "Warning", Duration = 1.5 })
            return
        end
        Window:Notify({ Title = "Coin Magnet", Content = "Noclip fly-collect started...", Type = "Info", Duration = 1.5 })
        task.spawn(function()
            local count = flyCollectAll()
            Window:Notify({ Title = "Coin Magnet", Content = "Fly-collected " .. tostring(count) .. " coins!", Type = "Success", Duration = 3 })
        end)
    end,
})
magnetSec:AddButton({
    Name = "Instant Collect (Teleport)", Icon = "check",
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
    autoParryLoop()
    applyAllBoosts()
end)

RunService.RenderStepped:Connect(function()
    lookAtLoop()
    updateRing()
    updateEspLoop()
    updateCoinEsp()
end)
