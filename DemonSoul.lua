local function SafeLoad()
    local path = "MoroLumina.lua"
    if not isfile(path) then 
        print("Библиотека не найдена!")
        return nil 
    end
    return loadstring(readfile(path))()
end

local Library = SafeLoad()

if Library then
    local rs = game:GetService("ReplicatedStorage")
    local player = game:GetService("Players").LocalPlayer
    local runService = game:GetService("RunService")
    local lighting = game:GetService("Lighting")
    local remoteFolder = rs:WaitForChild("RemoteEvents")
    
    local attackRemote = remoteFolder:WaitForChild("GeneralAttack")
    local skillRemote = remoteFolder:WaitForChild("SkillAttack")

    -- Settings
    local states = {attack = false, skill1 = false, skill2 = false, skill3 = false}
    local speeds = {attack = 20} 
    local killAuraActive = false
    local priorityHighHP = false 
    local animCancel = false
    local monsterNearby = false
    local isSpeedHack = false
    local minHealthLimit = 1000000 
    local flySpeedToTarget = 300 
    local tpHeight = 2
    local walkSpeedValue = 50
    local speedConn = nil
    local currentTarget = nil

    local Win = Library:CreateWindow("Moro Soul", "67 GOD")
    local MainTab = Win:CreateTab("Attacks")
    local TrainTab = Win:CreateTab("Train")
    local ExploitsTab = Win:CreateTab("Exploits")
    local FishTab = Win:CreateTab("Fishing&Food" )
    local UpgradeTab = Win:CreateTab("Upgrade")
    local DispatchTab = Win:CreateTab("Dispatch")
    local SettingsTab = Win:CreateTab("Settings")

    -- === 1. A SINGLE OPTIMIZED TARGET SEARCH ===
    task.spawn(function()
        while task.wait(0.3) do
            if killAuraActive or states.skill1 or states.skill2 or states.skill3 then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local target = nil
                    local bestValue = priorityHighHP and 0 or math.huge

                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                            local eHum = obj.Humanoid
                            if obj.Name ~= player.Name and eHum.Health > 0 and eHum.Health >= minHealthLimit then
                                local dist = (obj.HumanoidRootPart.Position - hrp.Position).Magnitude
                                if priorityHighHP then
                                    if eHum.Health > bestValue then bestValue = eHum.Health target = obj end
                                else
                                    if dist < bestValue then bestValue = dist target = obj end
                                end
                            end
                        end
                    end
                    currentTarget = target
                end
            else
                currentTarget = nil
            end
        end
    end)

    -- === 2. ANIMATION CANCEL ===
    task.spawn(function()
        while true do
            if animCancel then
                local char = player.Character
                local hum = char and char:FindFirstChild("Humanoid")
                if hum then
                    for _, track in pairs(hum:GetPlayingAnimationTracks()) do
                        track:Stop()
                    end
                end
            end
            task.wait(0.1)
        end
    end)

    -- === 3. FAST ATTACK ===
    task.spawn(function()
        while true do
            if states.attack then
                if monsterNearby then
                    attackRemote:FireServer(4)
                    
                    if animCancel then
                        local hum = player.Character and player.Character:FindFirstChild("Humanoid")
                        if hum then
                            for _, track in pairs(hum:GetPlayingAnimationTracks()) do
                                track:Stop()
                            end
                        end
                    end
                    
                    task.wait(1/speeds.attack)
                else
                    task.wait(0.1)
                end
            else
                task.wait(0.5)
            end
        end
    end)

    -- === 4. FAT SKILLS ===
    local function startSkillLoop(stateKey, skillNum)
        task.spawn(function()
            while states[stateKey] do
                if monsterNearby then
                    -- 1. СБРОС СОСТОЯНИЯ ИГРЫ (Освобождаем персонажа для нового действия)
                    _G.Skilling = false
                    _G.AttackAnim = nil
                
                    -- 2. СБРОС АНИМАЦИИ (Прерываем текущий каст на клиенте)
                    local char = player.Character
                    local hum = char and char:FindFirstChild("Humanoid")
                    if hum then
                        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                            -- На всякий случай проверяем, что это не анимация бега/стойки, а именно атака/скилл
                            if track.Name:find("Attack") or track.Name:find("Skill") or track.Name:find("SkillAttack") then
                                track:Stop()
                            end
                        end
                    end
                
                -- 3. ОТПРАВКА СКИЛЛА
                    skillRemote:FireServer(skillNum)
                
                    -- Пауза между кастами (регулируется через ползунок CPS в настройках)
                    -- Если speeds.attack = 20, то задержка будет 0.05 сек
                    task.wait(1 / speeds.attack) 
                else
                    task.wait(0.3)
                end
            end
        end)
    end



    -- === 5. SAFE SKILLS ===
    task.spawn(function()
        while true do
            if states.attack or states.skill1 or states.skill2 or states.skill3 then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local found = false
                
                if hrp then
                    local folder = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies") or workspace
                    for _, v in pairs(folder:GetChildren()) do
                        if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") then
                            if v.Humanoid.Health > 0 and (v.HumanoidRootPart.Position - hrp.Position).Magnitude < 19 then
                                found = true
                                break 
                            end
                        end
                    end
                end
                monsterNearby = found
                task.wait(0.09)
            else
                monsterNearby = false
                task.wait(1) 
            end
        end
    end)

    -- === 6. PAUSE FIX ===
    local CoreGui = game:GetService("CoreGui")
    local AntiGameplayPaused
    
    local function destroyNetworkPause()
        pcall(function()
            local robloxGui = CoreGui:FindFirstChild("RobloxGui")
            if robloxGui then
                local netPause = robloxGui:FindFirstChild("CoreScripts/NetworkPause")
                if netPause then
                    netPause:Destroy()
                end
            end
        end)
    end
    
    task.spawn(function()
        destroyNetworkPause()
        if AntiGameplayPaused then
            AntiGameplayPaused:Disconnect()
            AntiGameplayPaused = nil
        end
        AntiGameplayPaused = CoreGui.ChildAdded:Connect(function(child)
            if child.Name == "RobloxGui" then
                task.wait(0.1)
                destroyNetworkPause()
            end
        end)
    end)

    -- === 7. ANTI AFK ===
    local xAFKx
    
    if xAFKx then
        xAFKx:Disconnect()
        xAFKx = nil
    end
    
    xAFKx = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        local vu = game:GetService("VirtualUser")
        vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)


    -- === 8. AUTO REJOIN ===
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    local currentPlace = game.PlaceId
    local currentServer = game.JobId
    local TeleportService = game:GetService("TeleportService")
    local GuiService = game:GetService("GuiService")
    local Players = game:GetService("Players")
    
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
    
    pcall(function()
        GuiService.ErrorMessageChanged:Connect(function()
            local errorCode = GuiService:GetErrorCode()
            local errorMsg = GuiService:GetErrorMessage()
            
            if errorMsg ~= "" then
                task.wait(5)
                reconnect()
            end
        end)
    end)


    -- === ATTACKS ===
    MainTab:AddToggle("SpeedHack", function(state)
        isSpeedHack = state
        if state then
            speedConn = runService.Heartbeat:Connect(function()
                local char = player.Character
                local hum = char and char:FindFirstChild("Humanoid")
                if isSpeedHack and hum then 
                    hum.WalkSpeed = walkSpeedValue 
                end
            end)
        else
            if speedConn then 
                speedConn:Disconnect() 
                speedConn = nil
            end
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum then 
                hum.WalkSpeed = 16 
            end
        end
    end)


    MainTab:AddToggle("Fast General Attack", function(state) states.attack = state end)

    MainTab:AddToggle("Fast Skill 1", function(state) 
        states.skill1 = state 
        if state then startSkillLoop("skill1", 1) end 
    end)
    
    MainTab:AddToggle("Fast Skill 2", function(state) 
        states.skill2 = state 
        if state then startSkillLoop("skill2", 2) end 
    end)
    
    MainTab:AddToggle("Fast Skill 3", function(state) 
        states.skill3 = state 
        if state then startSkillLoop("skill3", 3) end 
    end)

    -- KILL AURA(Broken)
    MainTab:AddToggle("Kill Aura V67", function(state)
        killAuraActive = state
        states.attack = state
        
        if killAuraActive then
            task.spawn(function()
                local target = nil
                
                while killAuraActive do
                    local char = player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    
                    if hrp then
                        local isAlive = target and target.Parent and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0
                        
                        if not isAlive then
                            target = currentTarget
                            
                            if target and target:FindFirstChild("HumanoidRootPart") then
                                hrp.CFrame = target.HumanoidRootPart.CFrame
                                hrp.Velocity = Vector3.new(0, 0, 0)
                            end
                        end
                    end
                    task.wait(0.09)
                end
            end)
        end
    end)

    -- CHRISTMAS V2
    MainTab:AddToggle("Christmas Aura V2", function(state)
        _G.ChristmasAuraV2 = state
        if not state then
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
            end
        Library:Notify("System", state and "Christmas Farm V2 Active!" or "Disabled", 2)
        end
    end)

    _G.ChristmasAuraV2 = false

    task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        local camera = workspace.CurrentCamera
        local rs = game:GetService("ReplicatedStorage")
        local genAttack = rs:WaitForChild("RemoteEvents"):WaitForChild("GeneralAttack")
        
        -- Boss Finder
        local function GetBoss()
            local folder = workspace:FindFirstChild("Enemies") or workspace
            for _, e in pairs(folder:GetDescendants()) do
                if e:IsA("Model") and e:FindFirstChild("Humanoid") and e:FindFirstChild("HumanoidRootPart") then
                    if e.Humanoid.Health > 0 and e.Humanoid.MaxHealth >= 5000000 then
                        return e
                    end
                end
            end
            return nil
        end

        local camCfg = {
            z1 = {p = Vector3.new(195, 142, -336), l = Vector3.new(195, 0, -336)},
            z2 = {p = Vector3.new(28, 147, -36), l = Vector3.new(28, 0, -36)}
        }

        while true do
            if _G.ChristmasAuraV2 then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                
                if hrp then
                    local function UpdateCam(pos)
                        local d1 = (pos - camCfg.z1.l).Magnitude
                        local d2 = (pos - camCfg.z2.l).Magnitude
                        local current = d1 < d2 and camCfg.z1 or camCfg.z2
                        
                        camera.CameraType = Enum.CameraType.Scriptable
                        camera.CFrame = CFrame.new(current.p, current.l) * CFrame.Angles(0, 0, math.rad(90))
                    end

                    local targetBoss = GetBoss()
                    
                    if targetBoss then
                        local tHrp = targetBoss:FindFirstChild("HumanoidRootPart")
                        local tHum = targetBoss:FindFirstChild("Humanoid")
                        if tHrp and tHum then
                            UpdateCam(tHrp.Position)
                            while _G.ChristmasAuraV2 and tHum.Health > 0 and targetBoss.Parent do
                                hrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3)
                                genAttack:FireServer(4)
                                task.wait(speeds and 1/speeds.attack)
                            end
                        end
                    else
                        -- Фарм Мелочи
                        local zones = {"\232\141\146\233\135\142", "\230\151\160\231\186\191\229\136\151\232\189\166"}
                        for _, name in pairs(zones) do
                            local f = workspace.GhostPos:FindFirstChild(name)
                            if f then
                                for _, obj in pairs(f:GetDescendants()) do
                                    if not _G.ChristmasAuraV2 or GetBoss() then break end
                                    if obj:IsA("BasePart") and obj.Name ~= "对象038" then
                                        UpdateCam(obj.Position) 
                                        
                                        hrp.CFrame = obj.CFrame
                                        for k = 1, 6 do
                                            genAttack:FireServer(4)
                                            task.wait(speeds and 1/speeds.attack)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)

    -- === SPRING AURA ===
    local TweenService = game:GetService("TweenService")
    local flySpeed = 250
    local isFlying = false

    local function patrolFly(targetCFrame)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        isFlying = true
        local distance = (hrp.Position - targetCFrame.Position).Magnitude
        local duration = distance / flySpeed
        
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        tween.Completed:Connect(function()
            task.wait(0.1) 
            isFlying = false 
        end)
        
        tween:Play()
        return tween
    end

    MainTab:AddToggle("Spring farm", function(state)
        _G.SpringFarm = state
        states.attack = state 
        if state then
            Library:Notify("Moro Lumina", "Priority Patrol Started", 2)
        else
            isFlying = false
            if currentTween then currentTween:Cancel() end
        end
    end)

    -- 1. Координаты
    local farmPoints = {
        Vector3.new(208, 30, -319),
        Vector3.new(6, 30, -52),
        Vector3.new(209, 30, 219),
        Vector3.new(437, 30, 478),
        Vector3.new(386, 30, 740),
        Vector3.new(438, 30, 1014)
    }
    local currentPointIdx = 1

    -- 2. Основная логика
    task.spawn(function()
        local lastFoundTime = tick()
        local currentTween = nil

        while task.wait(0.17) do
            if _G.SpringFarm then
                local monsters = workspace:FindFirstChild("Monsters")
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                
                if monsters and hrp then
                    local target = nil
                    
                    if isFlying then
                        lastFoundTime = tick()
                        continue 
                    end

                    -- ПОИСК
                    for _, monster in ipairs(monsters:GetChildren()) do
                        local tHum = monster:FindFirstChildOfClass("Humanoid")
                        if tHum and tHum.Health > 0 then
                            local hasHat = monster:FindFirstChild("SpringHat")
                            local isBoss = tHum.MaxHealth >= 5000000
                            
                            if hasHat or isBoss then
                                local targetPart = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChild("Head")
                                if hasHat and monster.SpringHat:FindFirstChild("Handle") then
                                    targetPart = monster.SpringHat.Handle
                                end
                                
                                if targetPart then
                                    target = {monster = monster, part = targetPart, hum = tHum, type = isBoss and "BOSS" or "EVENT"}
                                    break 
                                end
                            end
                        end
                    end

                    if target then
                        lastFoundTime = tick()
                        local targetCF = target.part.CFrame * CFrame.new(0, tpHeight or 2, 0)
    
                        if isGhost then
                            targetCF = targetCF * CFrame.new(0, -11, 0)
                        end
    
                        hrp.CFrame = targetCF
                        
                        while _G.SpringFarm and target.hum.Health > 0 and target.monster.Parent do
                            hrp.Velocity = Vector3.new(0, 0, 0)
        
                            local currentTargetCF = target.part.CFrame
                            if isGhost then
                                currentTargetCF = currentTargetCF * CFrame.new(0, -11, 0)
                            end

                            if (hrp.Position - currentTargetCF.Position).Magnitude > 12 then
                                hrp.CFrame = currentTargetCF
                            end
                            task.wait(0.1)
                        end
                    else
                        if (tick() - lastFoundTime) > 3 then
                            currentPointIdx = currentPointIdx + 1
                            
                            if currentPointIdx > #farmPoints then 
                                currentPointIdx = 1 
                                hrp.CFrame = CFrame.new(farmPoints[currentPointIdx])
                                Library:Notify("Moro Lumina", "Teleported to Start", 1)
                                lastFoundTime = tick()
                            else
                                currentTween = patrolFly(CFrame.new(farmPoints[currentPointIdx]))
                            end
                        end
                    end
                end
            end
        end
    end)


    -- === TRAIN ===

    local vim = game:GetService("VirtualInputManager")
    local autoTrain = false

    task.spawn(function()
        while true do
            task.wait(0.2)
            if autoTrain then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                local trainPoint = workspace.InfinityTrain.Train
                local nextDoor = workspace.InfinityTrain.Portal.Next

                -- 1. Tp to demon
                hrp.CFrame = trainPoint.CFrame * CFrame.new(0, 2, 0)
                hrp.Velocity = Vector3.new(0,0,0)

                local monster = nil
                while autoTrain and not monster do
                    for _, v in pairs(workspace.Monsters:GetChildren()) do
                        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            if (v.PrimaryPart.Position - trainPoint.Position).Magnitude < 50 then
                                monster = v
                                break
                            end
                        end
                    end
                    task.wait(0.1)
                end

                -- 2. Killing demon
                if monster and autoTrain then
                    local mHrp = monster.PrimaryPart
                    local mHum = monster.Humanoid
                    
                    while autoTrain and mHum.Health > 0 and monster.Parent do
                        hrp.CFrame = CFrame.new(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position)
                        hrp.Velocity = Vector3.new(0,0,0)
                        
                        attackRemote:FireServer(4) 
                        task.wait(1 / speeds.attack)
                    end
                    task.wait(0.07)
                end

                -- 3. Tp ro button
                if autoTrain then
                    -- Мгновенно переносимся к двери
                    hrp.CFrame = nextDoor.CFrame
                    hrp.Velocity = Vector3.new(0,0,0)
                    task.wait(0.07) -- Даем серверу "увидеть" нас у двери
                    
                    -- Virtual E
                    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.1)
                    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    
                    task.wait(0.07)
                end
            end
        end
    end)

    TrainTab:AddToggle("Infinity Train (TP Mode)", function(state)
        autoTrain = state
        Library:Notify("Moro Lumina", state and "Auto Train Active" or "Disabled", 2)
    end)

    local vim = game:GetService("VirtualInputManager")
    local autoTrainV2 = false

    task.spawn(function()
        while true do
            task.wait(0.2)
            if autoTrainV2 then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                local trainPoint = workspace.InfinityTrain.Train
                local nextDoor = workspace.InfinityTrain.Portal.Next

                hrp.CFrame = trainPoint.CFrame * CFrame.new(0, 2, 0)
                hrp.Velocity = Vector3.new(0,0,0)

                local monster = nil
                while autoTrainV2 and not monster do
                    for _, v in pairs(workspace.Monsters:GetChildren()) do
                        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            if (v.PrimaryPart.Position - trainPoint.Position).Magnitude < 50 then
                                monster = v
                                break
                            end
                        end
                    end
                    task.wait(0.1)
                end

                if monster and autoTrainV2 then
                    local mHrp = monster.PrimaryPart
                    local mHum = monster.Humanoid
                    
                    while autoTrainV2 and mHum.Health > 0 and monster.Parent do
                        hrp.CFrame = CFrame.new(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position)
                        hrp.Velocity = Vector3.new(0,0,0)
                        
                        attackRemote:FireServer(4) 
                        skillRemote:FireServer(_G.TrainSkillNumber)
                        
                        task.wait(1 / speeds.attack)
                    end
                    task.wait(0.05) 
                end

                if autoTrainV2 then
                    hrp.CFrame = nextDoor.CFrame
                    hrp.Velocity = Vector3.new(0,0,0)
                    task.wait(0.1) 
                    
                    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.1)
                    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    
                    task.wait(0.1)
                end
            end
        end
    end)

    TrainTab:AddToggle("Infinity Train V2", function(state)
        autoTrainV2 = state
        if state then
            autoTrain = false 
        end
        Library:Notify("Moro Lumina", state and "Train V2 Active" or "Train V2 Disabled", 2)
    end)


    -- Skill Changer
    _G.TrainSkillNumber = 2

    TrainTab:AddDropdown("Train V2 Skill", {"Skill 1", "Skill 2", "Skill 3"}, function(selected)
        if selected == "Skill 1" then
            _G.TrainSkillNumber = 1
        elseif selected == "Skill 2" then
            _G.TrainSkillNumber = 2
        elseif selected == "Skill 3" then
            _G.TrainSkillNumber = 3
        end
        Library:Notify("Moro Lumina", "Train V2 will now use: " .. selected, 2)
    end)


    TrainTab:AddButton("Teleport to Train Entrance", function()
        local char = game:GetService("Players").LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local entrance = workspace:FindFirstChild("PromptTriggers") and workspace.PromptTriggers:FindFirstChild("Train_Entrance_1")
        
        if hrp and entrance then
            hrp.CFrame = entrance.CFrame + Vector3.new(0, 3, 0)
            Library:Notify("Moro Lumina", "Teleported to Train Entrance", 2)
        else
            Library:Notify("Error", "Entrance point not found!", 3)
        end
    end)


    -- === SETTINGS ===
    SettingsTab:AddButton("FPS Booster (Ultra)", function()
        local lighting = game:GetService("Lighting")
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
        end
        
        lighting.GlobalShadows = false
        lighting.FogEnd = 9e9
        lighting.Brightness = 1
        
        for _, obj in pairs(lighting:GetChildren()) do
            if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
                obj.Enabled = false
            end
        end
    
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Part") then
                obj.Material = Enum.Material.Plastic
                obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                obj.Enabled = false
            elseif obj:IsA("Explosion") then
                obj.Visible = false
            end
        end
        
        Library:Notify("Moro Lumina", "FPS Has Been Boosted!" , 2)
    end)

    SettingsTab:AddToggle("Animation Cancel", function(state) animCancel = state end)
    SettingsTab:AddToggle("Priority: Max HP First", function(state) priorityHighHP = state end)
    SettingsTab:AddTextBox("Walk Speed", "50", function(val) 
        walkSpeedValue = tonumber(val) or 50 
    end)
    SettingsTab:AddTextBox("CPS Speed", "20", function(val) speeds.attack = tonumber(val) or 20 end)
    SettingsTab:AddTextBox("Min HP", "1000000", function(val) minHealthLimit = tonumber(val) or 1000000 end)

    -- === FISHING AND FOOD ===
    local autoFishing = false
    local fishingArea = "Area_1"
    
    task.spawn(function()
        local startRemote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("StartFishing")
        local pullRemote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("PullFish")
        
        while true do
            if autoFishing then
                local fishingRoot = workspace:FindFirstChild("Fishing")
                local targetPoint = fishingRoot and fishingRoot:FindFirstChild(fishingArea) and fishingRoot[fishingArea]:FindFirstChild("FishingPoint")
                
                if targetPoint and targetPoint:FindFirstChild("ProximityPrompt") then
                    startRemote:FireServer(targetPoint.ProximityPrompt)
                    
                    task.wait(0.1)
                    
                    for i = 1, 40 do
                        if not autoFishing then break end
                        pullRemote:FireServer()
                        task.wait(0.05)
                    end
                end
            end
            task.wait(1)
        end
    end)
    
    -- Элементы управления
    FishTab:AddToggle("Auto Fishing", function(state)
        autoFishing = state
        Library:Notify("Moro Lumina", state and "Auto Fish Active" or "Disabled", 2)
    end)
    
    FishTab:AddTextBox("Fishing Area", "Area_1", function(val)
        fishingArea = val
    end)
    
    FishTab:AddButton("Teleport to Fishing Point", function()
        local char = game:GetService("Players").LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local fRoot = workspace:FindFirstChild("Fishing")
        local fPoint = fRoot and fRoot:FindFirstChild(fishingArea) and fRoot[fishingArea]:FindFirstChild("FishingPoint")
        
        if hrp and fPoint then
            hrp.CFrame = fPoint.CFrame + Vector3.new(0, 3, 0)
            Library:Notify("Moro Lumina", "Train TP Active", 2)
        else
            Library:Notify("Moro Lumina", "Area not found", 2)
        end
    end)

    FishTab:AddButton("Collect All Food", function()
        task.spawn(function()
            local vim = game:GetService("VirtualInputManager")
            local container = workspace:FindFirstChild("FoodMaterialContainer")
            local player = game:GetService("Players").LocalPlayer
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

            if hrp and container then
                local allItems = container:GetDescendants()
                Library:Notify("Moro Lumina", "Items found: " .. #allItems, 2)

                for _, item in pairs(allItems) do
                    if item:IsA("BasePart") then
                        hrp.CFrame = item.CFrame
                        hrp.Velocity = Vector3.new(0, 0, 0)
                        
                        task.wait(0.13)
                        
                        -- Virtual E
                        vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait(0.07)
                        vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        
                        task.wait(0.11)
                    end
                end
                Library:Notify("Moro Lumina", "Done collecting!", 2)
            else
                Library:Notify("Error", "Food folder not found", 3)
            end
        end)
    end)

    -- === UPGRADE TAB ===

    -- 1. CHARACTER TABLE (English Name for Menu = Byte-string for Remote)
    local heroData = {
        ["Yushiro & Tamayo"] = "\230\132\136\229\143\178\233\131\142\239\188\134\231\143\160\228\184\150",
        ["Shinobu Kocho"] = "\232\157\180\232\157\18蝶\229\191\141",
        ["Tanjiro (Hinokami)"] = "\231\130\173\230\178\187\233\131\142_\231\127\171\228\185\139\231\165\158\231\165\158\229\144\144",
        ["Rui"] = "\231\180\175",
        ["Zenitsu Agatsuma"] = "\230\136\145\229\166\187\229\150\132\233\128\184",
        ["Giyu Tomioka"] = "\229\175\140\229\175\136\228\185\137\229\139\135",
        ["Kyojuro Rengoku"] = "\231\130\188\231\133\177\230\15杏\229\175\183\233\131\142",
        ["Nezuko Kamado"] = "\229\188\165\230\178\187\229\173\144",
        ["Inosuke Hashibira"] = "\228\188\138\228\185\139\229\138\169",
        ["Akaza"] = "\230\188\154\229\173\150\229\186\167",
        ["Sakonji Urokodaki"] = "\229\183\166\232\191\145\226\172\161",
        ["Yahaba"] = "\231\159\162\233\150\181\231\190\189",
        ["Douma"] = "\231\171\165\233\173\148",
        ["Yushiro"] = "\230\132\136\229\143\178\233\131\142",
        ["Susamaru"] = "\230\156\177\231\187\161\228\184\184",
        ["Murata"] = "\230\157\145\231\148\176",
        ["Kanao Tsuyuri"] = "\230\160\151\232\138\177\229\144\189\233\166\153\229\165\136\228\185\142",
        ["Mitsuri Kanroji"] = "\231\148\152\230\156\178\229\175\186\232\156\156\231\147\153",
        ["Kaigaku"] = "\231\168\187\231\142\137\228\183\130\229\178\179",
        ["Daki"] = "\229\160\181\22姬\22姬",
        ["Gyutaro"] = "\229\166\179\229\164\171\229\164\170\233\131\142",
        ["Tengen Uzui"] = "\229\17宇\232\154\147\229\164\169\229\133\131",
        ["Iguro Obanai"] = "\228\188\138\233\187\145\229\176\143\232\138\173\229\134\133",
        ["Muichiro Tokito"] = "\230\151\182\233\128\143\230\151\160\228\184\128\233\131\142",
        ["Sanemi Shinazugawa"] = "\228\184\141\230\173\187\229\183\157\229\174\158\229\188\165",
        ["Gyomei Himejima"] = "\230\130\178\230\184\163\229\173\172\232\161\140\229\13冥",
        ["Tanjiro (Water)"] = "\231\130\173\230\178\187\233\131\142_\230\176\180",
        ["Zenitsu (Entertainment District)"] = "\230\136\145\229\166\187\229\150\132\233\128\184_\230\184\184\230\131\173\231\175\135",
        ["Tanjiro (Entertainment District)"] = "\231\130\173\230\178\187\233\131\142_\230\184\184\230\131\173\231\175\135",
        ["Inosuke (Entertainment District)"] = "\228\188\138\228\185\139\229\138\16助_\230\184\184\230\131\173\231\175\135",
        ["Nezuko (Berserk)"] = "\229\188\165\230\178\187\229\173\144_\231\170\156\229\140\150",
        ["Enmu"] = "\233\173\135\230\162\166",
        ["Genya Shinazugawa"] = "\228\184\141\230\173\187\229\183\157\231\142\132\229\188\165",
        ["Hinatsuru"] = "\233\155\142\233\185\164",
        ["Zohakuten"] = "\229\133\156\231\143\128\229\164\169",
        ["Tanjiro (Swordsmith Village)"] = "\231\130\173\230\178\187\233\131\142_\233\148\187\229\136\128\230\157\145\231\175\135"
    }

    local heroNames = {}
    for name, _ in pairs(heroData) do table.insert(heroNames, name) end
    table.sort(heroNames)

    _G.BuyCrystalsAmount = 10
    _G.UseCrystalsAmount = 10
    _G.SelectedHeroPath = heroData["Iguro Obanai"]

    UpgradeTab:AddToggle("Auto Buy Crystals", function(state)
        _G.AutoBuyCrystals = state
        if state then
            task.spawn(function()
                while _G.AutoBuyCrystals do
                    local args = {"\232\180\173\228\185\176\231\187\143\233\170\140\230\176\180\230\153\182", "\231\187\143\233\170\140\230\176\180\230\153\1823", _G.BuyCrystalsAmount}
                    game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("EventBus"):WaitForChild("EventProvider"):WaitForChild("default_RemoteEvent"):FireServer(unpack(args))
                    task.wait(0.5)
                end
            end)
        end
    end)

    UpgradeTab:AddButton("Buy crystals (one-time)", function()
        local args = {
            "\232\180\173\228\185\176\231\187\143\233\170\140\230\176\180\230\153\182", 
            "\231\187\143\233\170\140\230\176\180\230\153\1823", 
            _G.BuyCrystalsAmount
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("EventBus"):WaitForChild("EventProvider"):WaitForChild("default_RemoteEvent"):FireServer(unpack(args))
    end)

    -- BUY SECTION
    UpgradeTab:AddTextBox("Buy Amount", "Enter count...", function(val)
        local num = tonumber(val)
        if num then _G.BuyCrystalsAmount = num end
    end)

    UpgradeTab:AddToggle("Auto Upgrade Hero", function(state)
        _G.AutoUpgradeHero = state
        if state then
            task.spawn(function()
                while _G.AutoUpgradeHero do
                    local args = {
                        "/\229\141\161\231\137\140\231\179\187\231\187\159/\229\141\161\231\137\140\229\141\135\231\186\167/\229\162\158\229\138\160\231\187\143\233\170\140?\229\164\154\230\172\161\232\180\173\228\185\176",
                        _G.UseCrystalsAmount,
                        "/\229\141\161\231\137\140\231\179\187\231\187\159/\229\141\161\231\137\140\232\131\140\229\140\133/" .. _G.SelectedHeroPath,
                        "/\233\129\147\229\133\183/\231\187\143\233\170\140\230\176\180\230\153\1823"
                    }
                    pcall(function()
                        game:GetService("ReplicatedStorage"):WaitForChild("WuKong"):WaitForChild("RemoteActionFunction"):InvokeServer(unpack(args))
                    end)
                    task.wait(1)
                end
            end)
        end
    end)

    UpgradeTab:AddButton("Upgrade (One-time)", function()
        local args = {
            "/\229\141\161\231\137\140\231\179\187\231\187\159/\229\141\161\231\137\140\229\141\135\231\186\167/\229\162\158\229\138\160\231\187\143\233\170\140?\229\164\154\230\172\161\232\180\173\228\185\176",
            _G.UseCrystalsAmount,
            "/\229\141\161\231\137\140\231\179\187\231\187\159/\229\141\161\231\137\140\232\131\140\229\140\133/" .. _G.SelectedHeroPath,
            "/\233\129\147\229\133\183/\231\187\143\233\170\140\230\176\180\230\153\1823"
        }
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("WuKong"):WaitForChild("RemoteActionFunction"):InvokeServer(unpack(args))
        end)
    end)

    -- UPGRADE SECTION
    UpgradeTab:AddTextBox("Upgrade Amount", "Enter count...", function(val)
        local num = tonumber(val)
        if num then _G.UseCrystalsAmount = num end
    end)

    UpgradeTab:AddDropdown("Select Character", heroNames, function(val)
        _G.SelectedHeroPath = heroData[val]
        Library:Notify("Moro Lumina", "Selected: " .. val, 2)
    end)


    -- === EXPLOITS TAB ===
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")

    local player = Players.LocalPlayer
    local Camera = workspace.CurrentCamera

    local isGhost = false
    local ghostConn = nil
    local fakeCamPart = nil
    local ghostPlatform = nil
    local ghostBall = nil


    ExploitsTab:AddToggle("Ghost", function(state)
        isGhost = state
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        if isGhost and hrp then
            -- 1. Platform
            ghostPlatform = Instance.new("Part")
            ghostPlatform.Name = "GhostSafePlatform"
            ghostPlatform.Size = Vector3.new(10, 1, 10)
            ghostPlatform.Anchored = true
            ghostPlatform.CanCollide = true
            ghostPlatform.Transparency = 1 
            ghostPlatform.Parent = workspace

            fakeCamPart = Instance.new("Part")
            fakeCamPart.Name = "GhostCamAnchor"
            fakeCamPart.Transparency = 1
            fakeCamPart.CanCollide = false
            fakeCamPart.Anchored = true
            fakeCamPart.Parent = workspace
            
            Camera.CameraSubject = fakeCamPart
            -- 2. Ball
            ghostBall = Instance.new("Part")
            ghostBall.Name = "GhostVisualBall"
            ghostBall.Shape = Enum.PartType.Ball
            ghostBall.Size = Vector3.new(1.2, 1.2, 1.2)
            ghostBall.Color = Color3.fromRGB(0, 255, 255)
            ghostBall.Material = Enum.Material.Neon
            ghostBall.Transparency = 0.3
            ghostBall.CanCollide = false
            ghostBall.Anchored = true
            ghostBall.Parent = workspace

            local light = Instance.new("PointLight")
            light.Color = ghostBall.Color
            light.Range = 10
            light.Brightness = 2
            light.Parent = ghostBall

            
            ghostConn = RunService.Heartbeat:Connect(function()
                if not isGhost or not hrp.Parent then return end
                
                local realCF = hrp.CFrame
                
                fakeCamPart.CFrame = realCF
                if ghostBall then
                    ghostBall.CFrame = realCF * CFrame.new(0, 3.5, 0)
                end

                -- Move true body and platform
                local followPos = realCF * CFrame.new(0, -10, 0)
                hrp.CFrame = followPos
                
                ghostPlatform.CFrame = followPos * CFrame.new(0, -3, 0)
                
                RunService.RenderStepped:Wait()
                
                hrp.CFrame = realCF
            end)
        else
            isGhost = false
            if ghostConn then ghostConn:Disconnect() end
            if hum then Camera.CameraSubject = hum end
            if fakeCamPart then fakeCamPart:Destroy() end
            if ghostBall then ghostBall:Destroy() ghostBall = nil end

            
            if ghostPlatform then 
                ghostPlatform:Destroy() 
                ghostPlatform = nil
            end
            
            if hrp then
                hrp.Velocity = Vector3.new(0,0,0)
            end
        end
    end)

    local autoCrowdTpConn = false
    local lastWaypoint = Vector3.new(438, 35, 1014)

    ExploitsTab:AddToggle("Auto TP to Crowd", function(state)
        autoCrowdTpConn = state
        
        if state then
            task.spawn(function()
                while autoCrowdTpConn do
                    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local playersList = Players:GetPlayers()
                        local bestTargetPos = nil
                        local maxNearby = -1
                        local minDistanceToWaypoint = math.huge

                        -- Crowd finding
                        for _, p in pairs(playersList) do
                            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                local currentPos = p.Character.HumanoidRootPart.Position
                                local nearbyCount = 0

                                for _, otherP in pairs(playersList) do
                                    if otherP.Character and otherP.Character:FindFirstChild("HumanoidRootPart") then
                                        local dist = (currentPos - otherP.Character.HumanoidRootPart.Position).Magnitude
                                        if dist < 20 then
                                            nearbyCount = nearbyCount + 1
                                        end
                                    end
                                end

                                local distToLastPoint = (currentPos - lastWaypoint).Magnitude

                                if nearbyCount > maxNearby or (nearbyCount == maxNearby and distToLastPoint < minDistanceToWaypoint) then
                                    maxNearby = nearbyCount
                                    minDistanceToWaypoint = distToLastPoint
                                    bestTargetPos = p.Character.HumanoidRootPart.CFrame
                                end
                            end
                        end

                        -- Tp
                        if bestTargetPos then
                            local tpDestination = bestTargetPos
                            
                            if isGhost and fakeCamPart then
                                hrp.CFrame = tpDestination
                                fakeCamPart.CFrame = tpDestination
                                
                                if ghostPlatform then
                                    ghostPlatform.CFrame = tpDestination * CFrame.new(0, -13, 0)
                                end
                            else
                                hrp.CFrame = tpDestination
                            end
                        end
                    end
                    task.wait(10)
                end
            end)
        end
    end)


    ExploitsTab:AddButton("TP to Crowd (Once)", function()
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local playersList = Players:GetPlayers()
        local bestTargetPos = nil
        local maxNearby = -1
        local minDistanceToWaypoint = math.huge
        local lastWaypoint = Vector3.new(438, 35, 1014)

        for _, p in pairs(playersList) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local currentPos = p.Character.HumanoidRootPart.Position
                local nearbyCount = 0

                for _, otherP in pairs(playersList) do
                    if otherP.Character and otherP.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (currentPos - otherP.Character.HumanoidRootPart.Position).Magnitude
                        if dist < 20 then
                            nearbyCount = nearbyCount + 1
                        end
                    end
                end

                local distToLastPoint = (currentPos - lastWaypoint).Magnitude

                if nearbyCount > maxNearby or (nearbyCount == maxNearby and distToLastPoint < minDistanceToWaypoint) then
                    maxNearby = nearbyCount
                    minDistanceToWaypoint = distToLastPoint
                    bestTargetPos = p.Character.HumanoidRootPart.CFrame
                end
            end
        end

        if bestTargetPos then
            local tpDestination = bestTargetPos
            
            if isGhost and fakeCamPart then
                hrp.CFrame = tpDestination
                fakeCamPart.CFrame = tpDestination
                
                if ghostPlatform then
                    ghostPlatform.CFrame = tpDestination * CFrame.new(0, -13, 0)
                end
                Library:Notify("Moro Tools", "Ghost TP to Crowd (" .. maxNearby .. " players)", 2)
            else
                hrp.CFrame = tpDestination
                Library:Notify("Moro Lumina", "TP to Crowd (" .. maxNearby .. " players)", 2)
            end
        else
            Library:Notify("Moro Lumina", "No crowd found", 2)
        end
    end)


    -- 1. IDs

    local selectedRole1 = nil
    local selectedRole2 = nil
    local selectedRole3 = nil

    local dispatchRoles = {
        ["Nezuko"] = 1,
        ["Inosuke"] = 2,
        ["Tanjirou[Water]"] = 3,
        ["Rui"] = 4,
        ["Zenitsu"] = 5,
        ["Tanjirou[HinokamiKagura]"] = 6,
        ["Shinobu"] = 7,
        ["Giyu"] = 8,
        ["Rengoku"] = 9,
        ["Akaza"] = 10,
        ["Susamaru"] = 11,
        ["Yahaba"] = 12,
        ["Yushirou"] = 13,
        ["Enmu"] = 14,
        ["Urokodaki"] = 15,
        ["Tsuyuri Kanawo"] = 16,
        ["Kanroji Mitsuri"] = 17,
        ["Kaigaku"] = 18,
        ["Daki"] = 19,
        ["Gyuutarou"] = 20,
        ["Uzui Tengen"] = 21,
        ["Iguro Obanai"] = 22,
        ["Tokitou Muichirou"] = 23,
        ["Shinazugawa Sanemi"] = 24,
        ["Himejima Kyoumei"] = 25,
        ["Douma"] = 26,
        ["Tanjiro[Yoshiwara]"] = 27,
        ["Zenitsu[Yoshiwara]"] = 28,
        ["Inosuke[Yoshiwara]"] = 29,
        ["Nezuko[Demonic]"] = 30,
        ["Murata"] = 31,
        ["Shinazugawa Genya"] = 32,
        ["Hinatsuru"] = 33,
        ["Zohakuten"] = 34,
        ["Tanjirou[Swordsmith]"] = 35
    }

    local roleNames = {}
    for name, _ in pairs(dispatchRoles) do table.insert(roleNames, name) end
    table.sort(roleNames)

    -- === DROPDOWNS ===
    DispatchTab:AddDropdown("Select Role 1", roleNames, function(val)
        selectedRole1 = dispatchRoles[val]
    end)

    DispatchTab:AddDropdown("Select Role 2", roleNames, function(val)
        selectedRole2 = dispatchRoles[val]
    end)

    DispatchTab:AddDropdown("Select Role 3", roleNames, function(val)
        selectedRole3 = dispatchRoles[val]
    end)

    -- === SENDING  ===
    DispatchTab:AddButton("Send Selected to Dispatch", function()
        local toSend = {}
        if selectedRole1 then table.insert(toSend, selectedRole1) end
        if selectedRole2 then table.insert(toSend, selectedRole2) end
        if selectedRole3 then table.insert(toSend, selectedRole3) end

        if #toSend == 0 then
            Library:Notify("Moro Lumina", "Select at least one role!", 3)
            return
        end

        task.spawn(function()
            for _, roleId in ipairs(toSend) do
                local args = { roleId }
                game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("Dispatch"):FireServer(unpack(args))
                
                task.wait(0.1) 
            end
            Library:Notify("Moro Lumina", "Sent " .. #toSend .. " roles to dispatch!", 2)
        end)
    end)

    -- === CLAIM REWARDS ===
    DispatchTab:AddButton("Claim Rewards", function()
        local idsToClaim = {}
        if selectedRole1 then table.insert(idsToClaim, selectedRole1) end
        if selectedRole2 then table.insert(idsToClaim, selectedRole2) end
        if selectedRole3 then table.insert(idsToClaim, selectedRole3) end

        if #idsToClaim > 0 then
            local args = {
                "ClaimDispatchReward",
                idsToClaim 
            }
            game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("EventBus"):WaitForChild("EventProvider"):WaitForChild("default_RemoteEvent"):FireServer(unpack(args))
            Library:Notify("Moro Lumina", "Claimed rewards for " .. #idsToClaim .. " roles!", 2)
        else
            Library:Notify("Moro Lumina", "Select roles to claim!", 3)
        end
    end)

    -- === CANCEL DISPATCH ===
    DispatchTab:AddButton("Cancel Dispatch", function()
        local toCancel = {}
        if selectedRole1 then table.insert(toCancel, selectedRole1) end
        if selectedRole2 then table.insert(toCancel, selectedRole2) end
        if selectedRole3 then table.insert(toCancel, selectedRole3) end

        if #toCancel == 0 then
            Library:Notify("Moro Lumina", "No roles selected to cancel!", 3)
            return
        end

        task.spawn(function()
            for _, roleId in ipairs(toCancel) do
                local args = { roleId }
                game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("CancelDispatch"):FireServer(unpack(args))
                task.wait(0.1)
            end
            Library:Notify("Moro Lumina", "Cancelled dispatch for selected roles!", 2)
        end)
    end)

    local autoDispatchConn = false

    DispatchTab:AddToggle("Auto Dispatch", function(state)
        autoDispatchConn = state
        
        if state then
            task.spawn(function()
                while autoDispatchConn do
                    local roles = {}
                    if selectedRole1 then table.insert(roles, selectedRole1) end
                    if selectedRole2 then table.insert(roles, selectedRole2) end
                    if selectedRole3 then table.insert(roles, selectedRole3) end
                    
                    if #roles == 0 then
                        Library:Notify("Moro Lumina", "AutoDispatch: No roles selected!", 3)
                        autoDispatchConn = false
                        break
                    end

                    -- 1. Sending
                    for _, roleId in ipairs(roles) do
                        if not autoDispatchConn then break end
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("Dispatch"):FireServer(roleId)
                        task.wait(0.3)
                    end
                    
                    Library:Notify("Moro Lumina", "AutoDispatch: Roles sent. Waiting 30 min...", 2)

                    -- 2. Waiting
                    local waitTime = 1802
                    for i = 1, waitTime do
                        if not autoDispatchConn then break end
                        task.wait(1)
                    end

                    if not autoDispatchConn then break end

                    -- 3. Claiming
                    local claimArgs = {
                        "ClaimDispatchReward",
                        roles
                    }
                    game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("EventBus"):WaitForChild("EventProvider"):WaitForChild("default_RemoteEvent"):FireServer(unpack(claimArgs))
                    
                    Library:Notify("Moro Lumina", "AutoDispatch: Rewards claimed!", 2)

                    -- 4. Pause
                    task.wait(2)
                    
                    if not autoDispatchConn then break end
                    Library:Notify("Moro Lumina", "AutoDispatch: Restarting cycle...", 2)
                end
            end)
        else
            Library:Notify("Moro Lumina", "Auto Dispatch Disabled", 2)
        end
    end)


    Library:Notify("Moro Lumina", "The script is executed!", 2)

end

