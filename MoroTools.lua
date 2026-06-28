local RAW_URL = "https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"

-- безопасная загрузка
local Library
local ok, err = pcall(function()
    Library = loadstring(game:HttpGet(RAW_URL))()
end)
if not ok or not Library then
    warn("[TEST] Не удалось загрузить библиотеку: " .. tostring(err))
    error(err)
    return
end
print("[TEST] Библиотека загружена ✓")

--==================================================================
-- СЕРВИСЫ
--==================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local PlayerScripts = player:WaitForChild("PlayerScripts")
local ControlModule = require(PlayerScripts:WaitForChild("PlayerModule")):GetControls()

--==================================================================
-- ОКНО И ВКЛАДКИ (новый API)
--==================================================================
local Window = Library:CreateWindow({ Title = "MTools.lua" })

local MainTab   = Window:CreateTab({ Name = "Movement", Icon = "move" })
local CombatTab = Window:CreateTab({ Name = "Combat",   Icon = "sword" })
local VisualTab = Window:CreateTab({ Name = "Visuals",  Icon = "eye" })
local MiscTab   = Window:CreateTab({ Name = "Misc",     Icon = "settings" })

-- Встроенная вкладка настроек (масштаб, акцент, конфиги)
Window:AddSettingsTab()

--==================================================================
-- ПЕРЕМЕННЫЕ / НАСТРОЙКИ
--==================================================================
local flySpeed = 50
local walkSpeedValue = 50
local safePosition = nil
local selectedTarget = nil
local slowTpSpeed = 100
local espType = "Full"

local colorPalette = {
    ["White"] = Color3.fromRGB(255, 255, 255),
    ["Green"] = Color3.fromRGB(50, 255, 50),
    ["Red"] = Color3.fromRGB(255, 50, 50),
    ["Dark Red"] = Color3.fromRGB(128, 0, 0),
    ["Blue"] = Color3.fromRGB(50, 50, 255),
    ["Light Blue"] = Color3.fromRGB(0, 255, 255),
    ["Pink"] = Color3.fromRGB(255, 100, 255),
    ["Purple"] = Color3.fromRGB(150, 50, 255),
    ["Orange"] = Color3.fromRGB(255, 140, 0),
}
local colorNames = {"White", "Green", "Red", "Dark Red", "Blue", "Light Blue", "Pink", "Purple", "Orange"}

local espSelectedColor = colorPalette["White"]
local friendsSelectedColor = colorPalette["Green"]

local friendCache = {}

task.spawn(function()
    while task.wait(5) do
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                pcall(function()
                    friendCache[p.UserId] = player:IsFriendsWith(p.UserId)
                end)
            end
        end
    end
end)

-- Состояния
local animActive, animPower = false, 1
local isFlying, isNoclip, isSpeedHack, isFling = false, false, false, false
local isEspEnabled, isGhost, isInfJump, isAntiFling = false, false, false, false
local isNamesEnabled = false
local isSlowTpActive = false

local flyConn, noclipConn, speedConn, flingConn = nil, nil, nil, nil
local animConn, espConn, ghostConn, jumpConn, antiFlingConn = nil, nil, nil, nil, nil
local slowTpConn = nil
local fakeCamPart = nil

--==================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
--==================================================================
local function getPlayerNames()
    local names = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then table.insert(names, p.Name) end
    end
    return names
end

local espCache = {}

local function clearEsp(char)
    if espCache[char] then
        for _, obj in pairs(espCache[char]) do
            if typeof(obj) == "Instance" then obj:Destroy() end
        end
        if espCache[char].Parts then
            for _, b in pairs(espCache[char].Parts) do b:Destroy() end
        end
        espCache[char] = nil
    end
    if char:FindFirstChild("MoroHighlight") then char.MoroHighlight:Destroy() end
    if char:FindFirstChild("MoroNameGui") then char.MoroNameGui:Destroy() end
end

local function updateEsp()
    if not isEspEnabled and not isNamesEnabled then
        for char, _ in pairs(espCache) do clearEsp(char) end
        return
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local char = p.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                if not espCache[char] then espCache[char] = {Parts = {}} end
                local cache = espCache[char]

                local isFriend = friendCache[p.UserId] or false
                local finalColor = isFriend and friendsSelectedColor or espSelectedColor

                -- ИМЕНА
                if isNamesEnabled then
                    if not cache.NameGui then
                        cache.NameGui = Instance.new("BillboardGui", char)
                        cache.NameGui.Name = "MoroNameGui"
                        cache.NameGui.AlwaysOnTop = true
                        cache.NameGui.Size = UDim2.new(0, 100, 0, 50)
                        cache.NameGui.StudsOffset = Vector3.new(0, 4, 0)
                        local label = Instance.new("TextLabel", cache.NameGui)
                        label.BackgroundTransparency = 1
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.Font = Enum.Font.GothamBold
                        label.TextSize = 14
                        label.TextStrokeTransparency = 0
                        cache.NameLabel = label
                    end
                    cache.NameGui.Adornee = hrp
                    cache.NameLabel.Text = p.Name
                    cache.NameLabel.TextColor3 = finalColor
                    cache.NameGui.Enabled = true
                elseif cache.NameGui then
                    cache.NameGui.Enabled = false
                end

                -- ESP
                if isEspEnabled then
                    if espType == "Full" or espType == "Highlight" then
                        for _, b in pairs(cache.Parts) do b.Visible = false end
                        if not cache.Highlight then
                            cache.Highlight = Instance.new("Highlight", char)
                            cache.Highlight.Name = "MoroHighlight"
                        end
                        cache.Highlight.Enabled = true
                        cache.Highlight.OutlineColor = finalColor
                        cache.Highlight.FillColor = finalColor
                        cache.Highlight.OutlineTransparency = 0
                        cache.Highlight.FillTransparency = (espType == "Full" and 0.5 or 1)
                    elseif espType == "Box" then
                        if cache.Highlight then cache.Highlight.Enabled = false end
                        for _, part in pairs(char:GetChildren()) do
                            if part:IsA("BasePart") then
                                if part.Name ~= "HumanoidRootPart" and part.Transparency < 1 and part.Size.X < 5 then
                                    local bPart = cache.Parts[part]
                                    if not bPart then
                                        bPart = Instance.new("BoxHandleAdornment", part)
                                        bPart.Name = "MoroBoxPart"
                                        bPart.AlwaysOnTop = true
                                        bPart.ZIndex = 10
                                        cache.Parts[part] = bPart
                                    end
                                    bPart.Adornee = part
                                    bPart.Color3 = finalColor
                                    bPart.Transparency = 0.4
                                    bPart.Size = (part.Name == "Head" and Vector3.new(1.1, 1.1, 1.1) or part.Size)
                                    bPart.Visible = true
                                elseif cache.Parts[part] then
                                    cache.Parts[part].Visible = false
                                end
                            end
                        end
                    end
                else
                    if cache.Highlight then cache.Highlight.Enabled = false end
                    for _, b in pairs(cache.Parts) do b.Visible = false end
                end
            end
        end
    end
end

--==================================================================
-- MOVEMENT TAB
--==================================================================
MainTab:Column("left")
local MoveSection = MainTab:CreateSection({ Name = "Movement" })

MoveSection:AddToggle({
    Name = "SpeedHack",
    Default = false,
    Flag = "SpeedHack",
    Callback = function(state)
        isSpeedHack = state
        if state then
            speedConn = RunService.Heartbeat:Connect(function()
                local hum = player.Character and player.Character:FindFirstChild("Humanoid")
                if isSpeedHack and hum then hum.WalkSpeed = walkSpeedValue end
            end)
        else
            if speedConn then speedConn:Disconnect() end
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.WalkSpeed = 16
            end
        end
    end,
})

MoveSection:AddSlider({
    Name = "Walk Speed",
    Min = 16, Max = 500, Default = 50,
    Flag = "WalkSpeedValue",
    Callback = function(val) walkSpeedValue = val end,
})

MoveSection:AddToggle({
    Name = "Fly",
    Default = false,
    Flag = "Fly",
    Callback = function(state)
        isFlying = state
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if isFlying and hrp and hum then
            local bv = hrp:FindFirstChild("FlyVel") or Instance.new("BodyVelocity", hrp)
            bv.Name = "FlyVel"
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            hum.PlatformStand = true
            flyConn = RunService.RenderStepped:Connect(function()
                local cam = workspace.CurrentCamera.CFrame
                local mv = ControlModule:GetMoveVector()
                bv.Velocity = mv.Magnitude > 0 and ((cam.LookVector * -mv.Z) + (cam.RightVector * mv.X)).Unit * flySpeed or Vector3.new(0,0,0)
                hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z))
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        else
            if flyConn then flyConn:Disconnect() end
            if hrp and hrp:FindFirstChild("FlyVel") then hrp.FlyVel:Destroy() end
            if hum then hum.PlatformStand = false; hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
    end,
})

MoveSection:AddSlider({
    Name = "Fly Speed",
    Min = 10, Max = 500, Default = 50,
    Flag = "FlySpeed",
    Callback = function(val) flySpeed = val end,
})

MainTab:Column("right")
local TpSection = MainTab:CreateSection({ Name = "Teleport" })

TpSection:AddButton({
    Name = "Запомнить место",
    Callback = function()
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            safePosition = hrp.CFrame
            Window:Notify({ Title = "Позиция", Content = "Место сохранено!", Type = "Success", Duration = 2 })
        end
    end,
})

TpSection:AddButton({
    Name = "Мгновенный телепорт",
    Callback = function()
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp and safePosition then hrp.CFrame = safePosition end
    end,
})

TpSection:AddButton({
    Name = "Медленный телепорт",
    Callback = function()
        if not safePosition or isSlowTpActive then return end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if hrp and hum then
            isSlowTpActive = true
            hum.PlatformStand = true
            if slowTpConn then slowTpConn:Disconnect() end
            slowTpConn = RunService.Heartbeat:Connect(function(dt)
                if not isSlowTpActive or not hrp.Parent then
                    if slowTpConn then slowTpConn:Disconnect() end
                    hum.PlatformStand = false
                    return
                end
                local targetPos = safePosition.Position
                local currentPos = hrp.Position
                local direction = (targetPos - currentPos)
                local distance = direction.Magnitude
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
                if distance > 2 then
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    hrp.RotVelocity = Vector3.new(0, 0, 0)
                    hrp.CFrame = CFrame.new(currentPos + (direction.Unit * slowTpSpeed * dt), targetPos)
                else
                    hrp.CFrame = safePosition
                    isSlowTpActive = false
                    hum.PlatformStand = false
                    slowTpConn:Disconnect()
                end
            end)
        end
    end,
})

TpSection:AddSlider({
    Name = "Скорость медл. ТП",
    Min = 10, Max = 300, Default = 100,
    Flag = "SlowTpSpeed",
    Callback = function(val) slowTpSpeed = val end,
})

--==================================================================
-- COMBAT TAB
--==================================================================
CombatTab:Column("left")
local CombatSection = CombatTab:CreateSection({ Name = "Player Actions" })

CombatSection:AddToggle({
    Name = "Ghost",
    Default = false,
    Flag = "Ghost",
    Callback = function(state)
        isGhost = state
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if isGhost and hrp then
            local ghostPos = hrp.CFrame
            fakeCamPart = Instance.new("Part")
            fakeCamPart.Name = "GhostCamAnchor"
            fakeCamPart.Transparency = 1
            fakeCamPart.CanCollide = false
            fakeCamPart.Anchored = true
            fakeCamPart.Parent = workspace
            Camera.CameraSubject = fakeCamPart
            ghostConn = RunService.Heartbeat:Connect(function()
                if not isGhost or not hrp.Parent then return end
                local realCF = hrp.CFrame
                fakeCamPart.CFrame = realCF
                hrp.CFrame = ghostPos
                RunService.RenderStepped:Wait()
                hrp.CFrame = realCF
            end)
        else
            isGhost = false
            if ghostConn then ghostConn:Disconnect() end
            if hum then Camera.CameraSubject = hum end
            if fakeCamPart then fakeCamPart:Destroy() end
        end
    end,
})

local targetDrop = CombatSection:AddDropdown({
    Name = "Выбрать игрока",
    Options = getPlayerNames(),
    Flag = "SelectedTarget",
    Callback = function(val) selectedTarget = val end,
})

CombatSection:AddButton({
    Name = "Обновить список",
    Callback = function() targetDrop.Refresh(getPlayerNames()) end,
})

CombatSection:AddButton({
    Name = "Instant TP",
    Callback = function()
        if not selectedTarget then return end
        local t = Players:FindFirstChild(selectedTarget)
        if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
            and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame
        end
    end,
})

CombatSection:AddButton({
    Name = "Медленный ТП к игроку",
    Callback = function()
        if not selectedTarget then return end
        local targetPlayer = Players:FindFirstChild(selectedTarget)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if targetPlayer and targetPlayer.Character and hrp and hum then
            local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not targetHrp then return end
            isSlowTpActive = true
            hum.PlatformStand = true
            if slowTpConn then slowTpConn:Disconnect() end
            slowTpConn = RunService.Heartbeat:Connect(function(dt)
                if not isSlowTpActive or not hrp.Parent or not targetHrp.Parent then
                    if slowTpConn then slowTpConn:Disconnect() end
                    hum.PlatformStand = false
                    return
                end
                local targetPos = targetHrp.Position + Vector3.new(0, 2, 0)
                local currentPos = hrp.Position
                local direction = (targetPos - currentPos)
                local distance = direction.Magnitude
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
                if distance > 3 then
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    hrp.RotVelocity = Vector3.new(0, 0, 0)
                    hrp.CFrame = CFrame.new(currentPos + (direction.Unit * (slowTpSpeed or 60) * dt), targetPos)
                else
                    isSlowTpActive = false
                    hum.PlatformStand = false
                    slowTpConn:Disconnect()
                end
            end)
            Window:Notify({ Title = "ТП", Content = "Медленная телепортация!", Type = "Info", Duration = 2 })
        end
    end,
})

--==================================================================
-- VISUALS TAB
--==================================================================
VisualTab:Column("left")
local EspSection = VisualTab:CreateSection({ Name = "ESP" })

EspSection:AddToggle({
    Name = "Enable ESP",
    Default = false,
    Flag = "EspEnabled",
    Callback = function(state)
        isEspEnabled = state
        if state then
            espConn = RunService.Heartbeat:Connect(updateEsp)
        else
            if espConn then espConn:Disconnect() end
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character then clearEsp(p.Character) end
            end
        end
    end,
})

EspSection:AddToggle({
    Name = "Enable Names",
    Default = false,
    Flag = "NamesEnabled",
    Callback = function(state)
        isNamesEnabled = state
        updateEsp()
    end,
})

EspSection:AddDropdown({
    Name = "Режим ESP",
    Options = {"Full", "Highlight", "Box"},
    Default = "Full",
    Flag = "EspType",
    Callback = function(val)
        espType = val
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then clearEsp(p.Character) end
        end
    end,
})

EspSection:AddDropdown({
    Name = "ESP Color",
    Options = colorNames,
    Default = "White",
    Flag = "EspColor",
    Callback = function(val) espSelectedColor = colorPalette[val] end,
})

EspSection:AddDropdown({
    Name = "Friends Color",
    Options = colorNames,
    Default = "Green",
    Flag = "FriendsColor",
    Callback = function(val) friendsSelectedColor = colorPalette[val] end,
})

VisualTab:Column("right")
local SkinSection = VisualTab:CreateSection({ Name = "Skin Changer" })

SkinSection:AddButton({
    Name = "Надеть аксессуары",
    Callback = function()
        getgenv().Time = 2
        getgenv().Head = {105912717530980, 117464922920275}
        getgenv().Torso = {111132415112616}
        getgenv().Waist = {107430654581685}
        getgenv().LeftShoulder = {128170623253453}
        getgenv().RightShoulder = {122026029637452}
        getgenv().Neck = {78308643519674}

        task.wait(getgenv().Time)

        local function findMyCharacter()
            local camera = workspace.CurrentCamera
            if camera and camera.CameraSubject then
                local subject = camera.CameraSubject
                if subject and subject:IsA("Humanoid") then
                    return subject.Parent
                end
            end
            for _, obj in pairs(workspace:GetChildren()) do
                if obj:FindFirstChild("Humanoid") and obj:FindFirstChild("Head") then
                    if not string.find(obj.Name:lower(), "badpreload") and not string.find(obj.Name:lower(), "preload") then
                        return obj
                    end
                end
            end
            return nil
        end

        local character = findMyCharacter()

        if character then
            print("✅ Found YOUR character: " .. character.Name)

            local function addAccessory(accessoryId, parentPart)
                local success, accessory = pcall(function()
                    return game:GetObjects("rbxassetid://" .. tostring(accessoryId))[1]
                end)

                if success and accessory then
                    local handle = accessory:FindFirstChild("Handle")
                    if handle then
                        local accessoryAttachment = handle:FindFirstChildOfClass("Attachment")
                        if accessoryAttachment then
                            local parentAttachment = parentPart:FindFirstChild(accessoryAttachment.Name)
                            if parentAttachment then
                                local weld = Instance.new("Weld")
                                weld.Part0 = parentPart
                                weld.Part1 = handle
                                weld.C0 = parentAttachment.CFrame
                                weld.C1 = accessoryAttachment.CFrame
                                weld.Parent = handle
                            else
                                local weld = Instance.new("Weld")
                                weld.Part0 = parentPart
                                weld.Part1 = handle
                                weld.C0 = CFrame.new()
                                weld.C1 = CFrame.new()
                                weld.Parent = handle
                            end
                        else
                            local weld = Instance.new("Weld")
                            weld.Part0 = parentPart
                            weld.Part1 = handle
                            weld.C0 = CFrame.new()
                            weld.C1 = CFrame.new()
                            weld.Parent = handle
                        end

                        handle.CanCollide = false
                        accessory.Parent = character
                        print("✅ Added to YOU: " .. tostring(accessoryId))
                    end
                end
            end

            -- Голова
            if character:FindFirstChild("Head") then
                for _, id in ipairs(getgenv().Head) do
                    addAccessory(id, character.Head)
                    task.wait(0.3)
                end
            end

            -- Торс
            local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
            if torso then
                for _, id in ipairs(getgenv().Torso) do
                    addAccessory(id, torso)
                    task.wait(0.3)
                end
            end

            -- Талия
            local waist = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
            if waist and getgenv().Waist then
                for _, id in ipairs(getgenv().Waist) do
                    addAccessory(id, waist)
                    task.wait(0.3)
                end
            end

            -- Левое плечо
            local leftShoulder = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
            if leftShoulder and getgenv().LeftShoulder then
                for _, id in ipairs(getgenv().LeftShoulder) do
                    addAccessory(id, leftShoulder)
                    task.wait(0.3)
                end
            end

            -- Правое плечо
            local rightShoulder = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
            if rightShoulder and getgenv().RightShoulder then
                for _, id in ipairs(getgenv().RightShoulder) do
                    addAccessory(id, rightShoulder)
                    task.wait(0.3)
                end
            end

            -- Шея
            if getgenv().Neck then
                local neckPart = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Head")
                if neckPart then
                    for _, id in ipairs(getgenv().Neck) do
                        addAccessory(id, neckPart)
                        task.wait(0.3)
                    end
                end
            end

            Window:Notify({ Title = "Skin Changer", Content = "Аксессуары надеты!", Type = "Success", Duration = 3 })
        else
            Window:Notify({ Title = "Skin Changer", Content = "Персонаж не найден!", Type = "Error", Duration = 3 })
        end
    end,
})

--==================================================================
-- MISC TAB
--==================================================================
MiscTab:Column("left")
local MiscSection = MiscTab:CreateSection({ Name = "Movement Extras" })

MiscSection:AddToggle({
    Name = "Infinite Jump",
    Default = false,
    Flag = "InfJump",
    Callback = function(state)
        isInfJump = state
        if state then
            jumpConn = UserInputService.JumpRequest:Connect(function()
                if isInfJump and player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        else
            if jumpConn then jumpConn:Disconnect() end
        end
    end,
})

MiscSection:AddToggle({
    Name = "NoClip",
    Default = false,
    Flag = "NoClip",
    Callback = function(state)
        isNoclip = state
        if state then
            noclipConn = RunService.Stepped:Connect(function()
                if isNoclip and player.Character then
                    for _, v in pairs(player.Character:GetDescendants()) do
                        if v:IsA("BasePart") then v.CanCollide = false end
                    end
                end
            end)
        else
            if noclipConn then noclipConn:Disconnect() end
        end
    end,
})

MiscSection:AddToggle({
    Name = "Anti-Fling",
    Default = false,
    Flag = "AntiFling",
    Callback = function(state)
        isAntiFling = state
        if state then
            antiFlingConn = RunService.Stepped:Connect(function()
                if not isAntiFling then return end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= player and p.Character then
                        for _, part in pairs(p.Character:GetChildren()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                                part.Velocity = Vector3.new(0, 0, 0)
                                part.RotVelocity = Vector3.new(0, 0, 0)
                            end
                        end
                    end
                end
            end)
        else
            if antiFlingConn then antiFlingConn:Disconnect() end
        end
    end,
})

MiscTab:Column("right")
local FunSection = MiscTab:CreateSection({ Name = "Fun" })

FunSection:AddToggle({
    Name = "Insane Animation",
    Default = false,
    Flag = "InsaneAnim",
    Callback = function(state)
        animActive = state
        if state then
            animConn = RunService.Stepped:Connect(function()
                local char = player.Character
                local rj = char and char:FindFirstChild("LowerTorso") and char.LowerTorso:FindFirstChild("Root")
                    or (char and char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Root Joint"))
                if rj and animActive then
                    rj.C0 = rj.C0 * CFrame.Angles(
                        math.rad(math.random(-10, 10) * animPower),
                        math.rad(math.random(-10, 10) * animPower),
                        math.rad(math.random(-10, 10) * animPower)
                    )
                end
            end)
        else
            if animConn then animConn:Disconnect() end
        end
    end,
})

FunSection:AddSlider({
    Name = "Anim Intensity",
    Min = 1, Max = 20, Default = 1,
    Flag = "AnimPower",
    Callback = function(val) animPower = val end,
})

FunSection:AddToggle({
    Name = "Touch Fling",
    Default = false,
    Flag = "TouchFling",
    Callback = function(state)
        isFling = state
        if isFling then
            flingConn = RunService.Heartbeat:Connect(function()
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if isFling and hrp and hrp.Parent then
                    local moveVel = hrp.Velocity
                    hrp.Velocity = Vector3.new(10000, 10000, 10000)
                    hrp.RotVelocity = Vector3.new(0, 10000, 0)
                    RunService.RenderStepped:Wait()
                    if hrp.Parent then
                        hrp.Velocity = moveVel
                        hrp.RotVelocity = Vector3.new(0, 0, 0)
                    end
                end
            end)
        else
            if flingConn then flingConn:Disconnect() end
        end
    end,
})

--==================================================================
-- ГОТОВО
--==================================================================
Window:Notify({
    Title = "MTools загружен!",
    Content = "Приятного использования 🎉",
    Type = "Success",
    Duration = 5,
})
