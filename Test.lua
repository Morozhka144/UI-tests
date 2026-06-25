local function SafeLoad()
    local url = "https://raw.githubusercontent.com/Morozhka144/GreenyUI/refs/heads/main/main.lua"

    local ok, content = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        print("ОШИБКА: Не удалось загрузить библиотеку с GitHub! " .. tostring(content))
        return nil
    end
    if not content or content == "" then
        print("ОШИБКА: Библиотека загружена, но она пустая (проверь ссылку)!")
        return nil
    end

    local func, err = loadstring(content)
    if not func then
        print("ОШИБКА СИНТАКСИСА в библиотеке: " .. tostring(err))
        return nil
    end

    local success, result = pcall(func)
    if not success then
        print("ОШИБКА ВЫПОЛНЕНИЯ библиотеки: " .. tostring(result))
        return nil
    end

    if result == nil then
        warn("ОШИБКА: Библиотека выполнена, но забыт 'return Library' в конце файла!")
    end

    return result
end

local Library = SafeLoad()

if Library then
    local player = game:GetService("Players").LocalPlayer
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local Camera = workspace.CurrentCamera

    local PlayerScripts = player:WaitForChild("PlayerScripts")
    local ControlModule = require(PlayerScripts:WaitForChild("PlayerModule")):GetControls()

    local Win = Library:CreateWindow({
        Title = "MTools",
        SubTitle = "MoroLumina • emerald build",
        ToggleKey = Enum.KeyCode.RightControl,
    })

    local MainTab   = Win:CreateTab("Movement")
    local CombatTab = Win:CreateTab("Combat")
    local VisualTab = Win:CreateTab("Visuals")
    local MiscTab   = Win:CreateTab("Misc")

    -- Настройки
    local flySpeed = 50
    local walkSpeedValue = 50
    local safePosition = nil
    local selectedTarget = nil
    local slowTpSpeed = 100
    local espType = "Full"

    local colorPalette = {
        ["White"]      = Color3.fromRGB(255, 255, 255),
        ["Green"]      = Color3.fromRGB(50, 255, 50),
        ["Red"]        = Color3.fromRGB(255, 50, 50),
        ["Dark Red"]   = Color3.fromRGB(128, 0, 0),
        ["Blue"]       = Color3.fromRGB(50, 50, 255),
        ["Light Blue"] = Color3.fromRGB(0, 255, 255),
        ["Pink"]       = Color3.fromRGB(255, 100, 255),
        ["Purple"]     = Color3.fromRGB(150, 50, 255),
        ["Orange"]     = Color3.fromRGB(255, 140, 0)
    }
    local colorNames = {"White", "Green", "Red", "Dark Red", "Blue", "Light Blue", "Pink", "Purple", "Orange"}

    local espSelectedColor = colorPalette["White"]
    local friendsSelectedColor = colorPalette["Green"]

    local friendCache = {}

    task.spawn(function()
        while task.wait(5) do
            for _, p in pairs(game.Players:GetPlayers()) do
                if p ~= player then
                    friendCache[p.UserId] = player:IsFriendsWith(p.UserId)
                end
            end
        end
    end)

    -- Состояния
    local animActive, animPower = false, 1
    local isFlying, isNoclip, isSpeedHack, isFling, isEspEnabled, isGhost, isInfJump, isAntiFling = false, false, true, false, false, false, false, false
    local flyConn, noclipConn, speedConn, flingConn, animConn, espConn, ghostConn, jumpConn, antiFlingConn = nil, nil, nil, nil, nil, nil, nil, nil, nil

    local fakeCamPart = nil

    local function getPlayerNames()
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then table.insert(names, p.Name) end
        end
        return names
    end

    local isNamesEnabled = false
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

        for _, p in pairs(game:GetService("Players"):GetPlayers()) do
            if p ~= game:GetService("Players").LocalPlayer and p.Character then
                local char = p.Character
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                if not espCache[char] then espCache[char] = {Parts = {}} end
                local cache = espCache[char]

                local isFriend = friendCache[p.UserId] or false
                local finalColor = isFriend and friendsSelectedColor or espSelectedColor

                -- 1. ИМЕНА
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

                -- 2. ESP ЛОГИКА
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


    -- ============================================================
    -- === MOVEMENT TAB ===
    -- ============================================================
    local isSlowTpActive = false
    local connection -- общий хэндл для медленного ТП

    MainTab:CreateSection("Speed & Fly")

    MainTab:CreateToggle({
        Name = "SpeedHack",
        Default = false,
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

    MainTab:CreateTextbox({
        Name = "Walk Speed",
        Default = "50",
        Placeholder = "50",
        Callback = function(val) walkSpeedValue = tonumber(val) or 50 end,
    })

    MainTab:CreateToggle({
        Name = "Fly",
        Default = false,
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

    MainTab:CreateTextbox({
        Name = "Fly Speed",
        Default = "50",
        Placeholder = "50",
        Callback = function(val) flySpeed = tonumber(val) or 50 end,
    })

    MainTab:CreateSection("Teleport")

    MainTab:CreateButton({
        Name = "Запомнить место",
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                safePosition = hrp.CFrame
                Win:Notify({Title = "Точка", Content = "Позиция сохранена!", Type = "Success", Duration = 2})
            end
        end,
    })

    MainTab:CreateButton({
        Name = "Мгновенный телепорт",
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp and safePosition then hrp.CFrame = safePosition end
        end,
    })

    MainTab:CreateButton({
        Name = "Медленный телепорт",
        Callback = function()
            if not safePosition or isSlowTpActive then return end

            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")

            if hrp and hum then
                isSlowTpActive = true
                hum.PlatformStand = true

                local conn
                conn = RunService.Heartbeat:Connect(function(dt)
                    if not isSlowTpActive or not hrp.Parent then
                        if conn then conn:Disconnect() end
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
                        conn:Disconnect()
                    end
                end)
            end
        end,
    })

    MainTab:CreateTextbox({
        Name = "Скорость медл. ТП",
        Default = "100",
        Placeholder = "100",
        Callback = function(val) slowTpSpeed = tonumber(val) or 100 end,
    })


    -- ============================================================
    -- === COMBAT TAB ===
    -- ============================================================
    CombatTab:CreateSection("Ghost & Targeting")

    CombatTab:CreateToggle({
        Name = "Ghost",
        Default = false,
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

    local targetDrop = CombatTab:CreateDropdown({
        Name = "Выбрать игрока",
        Options = getPlayerNames(),
        Callback = function(val) selectedTarget = val end,
    })

    CombatTab:CreateButton({
        Name = "Обновить список",
        Callback = function() targetDrop:Refresh(getPlayerNames()) end,
    })

    CombatTab:CreateButton({
        Name = "Instant TP",
        Callback = function()
            local t = Players:FindFirstChild(selectedTarget)
            if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame
            end
        end,
    })

    CombatTab:CreateButton({
        Name = "Медленный ТП к игроку",
        Callback = function()
            if selectedTarget then
                local targetPlayer = game.Players:FindFirstChild(selectedTarget)
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")

                if targetPlayer and targetPlayer.Character and hrp and hum then
                    local targetChar = targetPlayer.Character
                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    if not targetHrp then return end

                    isSlowTpActive = true
                    hum.PlatformStand = true

                    if connection then connection:Disconnect() end

                    connection = RunService.Heartbeat:Connect(function(dt)
                        if not isSlowTpActive or not hrp.Parent or not targetHrp.Parent then
                            if connection then connection:Disconnect() end
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
                            local speed = slowTpSpeed or 60
                            hrp.CFrame = CFrame.new(currentPos + (direction.Unit * speed * dt), targetPos)
                        else
                            isSlowTpActive = false
                            hum.PlatformStand = false
                            connection:Disconnect()
                        end
                    end)
                end
                Win:Notify({Title = "ТП", Content = "Медленная телепортация!", Type = "Info", Duration = 2})
            end
        end,
    })


    -- ============================================================
    -- === VISUALS TAB ===
    -- ============================================================
    VisualTab:CreateSection("ESP")

    VisualTab:CreateToggle({
        Name = "Enable ESP",
        Default = false,
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

    VisualTab:CreateToggle({
        Name = "Enable Names",
        Default = false,
        Callback = function(state)
            isNamesEnabled = state
            updateEsp()
        end,
    })

    VisualTab:CreateDropdown({
        Name = "Режим ESP",
        Options = {"Full", "Highlight", "Box"},
        Default = "Full",
        Callback = function(val)
            espType = val
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character then clearEsp(p.Character) end
            end
        end,
    })

    VisualTab:CreateDropdown({
        Name = "ESP Color",
        Options = colorNames,
        Default = "White",
        Callback = function(val) espSelectedColor = colorPalette[val] end,
    })

    VisualTab:CreateDropdown({
        Name = "Friends Color",
        Options = colorNames,
        Default = "Green",
        Callback = function(val) friendsSelectedColor = colorPalette[val] end,
    })

    VisualTab:CreateSection("Skin Changer")

    VisualTab:CreateButton({
        Name = "Надеть аксессуары",
        Callback = function()
            getgenv().Time = 2
            getgenv().Head = {105912717530980, 117464922920275}
            getgenv().Torso = {111132415112616}
            getgenv().Waist = {107430654581685}
            getgenv().LeftShoulder = {128170623253453}
            getgenv().RightShoulder = {122026029637452}
            getgenv().Neck = {78308643519674}

            wait(getgenv().Time)

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
                        wait(0.3)
                    end
                end

                -- Торс
                local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
                if torso then
                    for _, id in ipairs(getgenv().Torso) do
                        addAccessory(id, torso)
                        wait(0.3)
                    end
                end

                -- Талия
                local waist = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
                if waist and getgenv().Waist then
                    for _, id in ipairs(getgenv().Waist) do
                        addAccessory(id, waist)
                        wait(0.3)
                    end
                end

                -- Левое плечо
                local leftShoulder = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
                if leftShoulder and getgenv().LeftShoulder then
                    for _, id in ipairs(getgenv().LeftShoulder) do
                        addAccessory(id, leftShoulder)
                        wait(0.3)
                    end
                end

                -- Правое плечо
                local rightShoulder = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
                if rightShoulder and getgenv().RightShoulder then
                    for _, id in ipairs(getgenv().RightShoulder) do
                        addAccessory(id, rightShoulder)
                        wait(0.3)
                    end
                end

                -- Шея
                if getgenv().Neck then
                    local neckPart = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Head")
                    if neckPart then
                        for _, id in ipairs(getgenv().Neck) do
                            addAccessory(id, neckPart)
                            wait(0.3)
                        end
                    end
                end

                Win:Notify({Title = "Skin Changer", Content = "Аксессуары надеты!", Type = "Success", Duration = 3})
            else
                Win:Notify({Title = "Skin Changer", Content = "Персонаж не найден!", Type = "Error", Duration = 3})
            end
        end,
    })


    -- ============================================================
    -- === MISC TAB ===
    -- ============================================================
    MiscTab:CreateSection("Jump & Anti")

    MiscTab:CreateToggle({
        Name = "Infinite Jump",
        Default = false,
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

    MiscTab:CreateToggle({
        Name = "Anti-Fling",
        Default = false,
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

    MiscTab:CreateToggle({
        Name = "NoClip",
        Default = false,
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

    MiscTab:CreateSection("Fun")

    MiscTab:CreateToggle({
        Name = "Insane Animation",
        Default = false,
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

    MiscTab:CreateTextbox({
        Name = "Anim Intensity",
        Default = "1",
        Placeholder = "1",
        Callback = function(val) animPower = tonumber(val) or 1 end,
    })

    MiscTab:CreateToggle({
        Name = "Touch Fling",
        Default = false,
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

    -- Приветственное уведомление
    Win:Notify({
        Title = "MTools загружен",
        Content = "RightCtrl — скрыть/показать меню",
        Type = "Success",
        Duration = 4,
    })

else
    print("Не удалось загрузить библиотеку.")
end
