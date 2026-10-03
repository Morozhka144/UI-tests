--[[
    Demon Soul Simulator - Lumina UI Edition
    Fully ported to Lumina UI Framework (Clean Version)
]]

local function SafeLoad()
    -- Убираем загрузку из локальных файлов, чтобы избежать подгрузки битых библиотек из кэша эксплойтера.
    -- Грузим оригинальную Lumina напрямую по ссылке.
    local url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"
    local ok, content = pcall(function() return game:HttpGet(url) end)
    if ok and content and #content > 0 then
        local func, err = loadstring(content)
        if func then
            local success, lib = pcall(func)
            if success and lib then return lib end
        end
    end
    
    warn("[Moro Soul] Не удалось загрузить библиотеку Lumina!")
    return nil
end

local Library = SafeLoad()

if Library then
    local rs = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local player = players.LocalPlayer
    local runService = game:GetService("RunService")
    local lighting = game:GetService("Lighting")
    local tweenService = game:GetService("TweenService")
    local vim = game:GetService("VirtualInputManager")
    local teleportService = game:GetService("TeleportService")
    local guiService = game:GetService("GuiService")
    local uis = game:GetService("UserInputService")
    
    local remoteFolder = rs:WaitForChild("RemoteEvents", 10) or rs:FindFirstChild("RemoteEvents")
    local attackRemote = remoteFolder:WaitForChild("GeneralAttack")
    local skillRemote = remoteFolder:WaitForChild("SkillAttack")
    
    local EventBus = nil
    pcall(function()
        EventBus = require(rs:WaitForChild("Packages"):WaitForChild("EventBus"))
    end)
    
    local AttackHelper = nil
    pcall(function()
        AttackHelper = require(rs:WaitForChild("AttackHelpers"):WaitForChild("AttackHelper"))
    end)

    -- Settings & State
    local states = {attack = false, skill1 = false, skill2 = false, skill3 = false}
    local speeds = {attack = 20} 
    local killAuraActive = false
    local priorityHighHP = false 
    local animCancel = false
    local noSkillCd = false
    local autoCastSkills = false
    local autoRoulette = false
    local autoMissions = false
    local monsterNearby = false
    local isSpeedHack = false
    local minHealthLimit = 0
    local tpHeight = 2
    local walkSpeedValue = 50
    local speedConn = nil
    local currentTarget = nil
    
    -- Dynamic Hero Data from RoleConfig
    local heroData = {}
    local heroNames = {}
    local dispatchRoles = {}
    local roleNames = {}
    
    pcall(function()
        local rc = require(rs:WaitForChild("Configs"):WaitForChild("RoleConfig"))
        for id, r in pairs(rc) do
            if r.RoleName and r.RoleIndex then
                heroData[r.RoleName] = r.RoleIndex
                table.insert(heroNames, r.RoleName)
            end
            if r.RoleName and r.RoleId then
                dispatchRoles[r.RoleName] = r.RoleId
                table.insert(roleNames, r.RoleName)
            end
        end
        table.sort(heroNames)
        table.sort(roleNames)
    end)
    
    -- Fallback hero table if RoleConfig is not accessible
    if #heroNames == 0 then
        heroData = {
            ["Akaza"] = "漪窝座", ["Daki"] = "堕姬", ["Douma"] = "童魔", ["Enmu"] = "魇梦",
            ["Genya Shinazugawa"] = "不死川玄弥", ["Giyu Tomioka"] = "富冈义勇", ["Gyomei Himejima"] = "悲鸣屿行冥",
            ["Gyutaro"] = "妓夫太郎", ["Himejima Kyoumei"] = "悲鸣屿行冥", ["Hinatsuru"] = "雏鹤",
            ["Iguro Obanai"] = "伊黑小芭内", ["Inosuke Hashibira"] = "伊之助", ["Inosuke (Entertainment District)"] = "伊之助_游郭篇",
            ["Kaigaku"] = "稻玉狯岳", ["Kanao Tsuyuri"] = "栗花落香奈乎", ["Kyojuro Rengoku"] = "炼狱杏寿郎",
            ["Mitsuri Kanroji"] = "甘露寺蜜璃", ["Muichiro Tokito"] = "时透无一郎", ["Murata"] = "村田",
            ["Nezuko Kamado"] = "弥豆子", ["Nezuko (Berserk)"] = "弥豆子_鬼化", ["Rui"] = "累",
            ["Sakonji Urokodaki"] = "左近次", ["Sanemi Shinazugawa"] = "不死川实弥", ["Shinobu Kocho"] = "蝴蝶忍",
            ["Susamaru"] = "朱纱丸", ["Tanjiro (Entertainment District)"] = "炭治郎_游郭篇", ["Tanjiro (Hinokami)"] = "炭治郎_火之神神乐",
            ["Tanjiro (Swordsmith Village)"] = "炭治郎_锻刀村篇", ["Tanjiro (Water)"] = "炭治郎_水", ["Tengen Uzui"] = "宇髓天元",
            ["Yahaba"] = "矢琵羽", ["Yushiro"] = "愈史郎", ["Yushiro & Tamayo"] = "愈史郎",
            ["Zenitsu Agatsuma"] = "我妻善逸", ["Zenitsu (Entertainment District)"] = "我妻善逸_游郭篇", ["Zohakuten"] = "憎珀天"
        }
        for name, _ in pairs(heroData) do table.insert(heroNames, name) end
        table.sort(heroNames)
    end
    
    if #roleNames == 0 then
        local defaultDispatch = {
            ["Nezuko"] = 1, ["Inosuke"] = 2, ["Tanjirou[Water]"] = 3, ["Rui"] = 4, ["Zenitsu"] = 5,
            ["Tanjirou[HinokamiKagura]"] = 6, ["Shinobu"] = 7, ["Giyu"] = 8, ["Rengoku"] = 9, ["Akaza"] = 10,
            ["Susamaru"] = 11, ["Yahaba"] = 12, ["Yushirou"] = 13, ["Enmu"] = 14, ["Urokodaki"] = 15,
            ["Tsuyuri Kanawo"] = 16, ["Kanroji Mitsuri"] = 17, ["Kaigaku"] = 18, ["Daki"] = 19, ["Gyuutarou"] = 20,
            ["Uzui Tengen"] = 21, ["Iguro Obanai"] = 22, ["Tokitou Muichirou"] = 23, ["Shinazugawa Sanemi"] = 24,
            ["Himejima Kyoumei"] = 25, ["Douma"] = 26, ["Tanjiro[Yoshiwara]"] = 27, ["Zenitsu[Yoshiwara]"] = 28,
            ["Inosuke[Yoshiwara]"] = 29, ["Nezuko[Demonic]"] = 30, ["Murata"] = 31, ["Shinazugawa Genya"] = 32,
            ["Hinatsuru"] = 33, ["Zohakuten"] = 34, ["Tanjirou[Swordsmith]"] = 35
        }
        for name, id in pairs(defaultDispatch) do
            dispatchRoles[name] = id
            table.insert(roleNames, name)
        end
        table.sort(roleNames)
    end

    -- Window Creation (Lumina API)
    local Win = Library:CreateWindow({
        Title = "Moro Soul",
        ToggleKey = Enum.KeyCode.RightShift,
        LoaderSound = true,
        NotifySound = true
    })

    -- Universal Notification Helper
    local function Notify(title, content, dur, nType)
        if Win and Win.Notify then
            Win:Notify({
                Title = title or "Moro Soul",
                Content = content or "",
                Duration = dur or 2.5,
                Type = nType or "Info"
            })
        end
    end
    Library.Notify = function(self, title, content, dur, nType)
        Notify(title, content, dur, nType)
    end

    -- Tabs Creation (Lumina API)
    local MainTab     = Win:CreateTab({ Name = "Attacks", Icon = "swords" })
    local TrainTab    = Win:CreateTab({ Name = "Train", Icon = "train" })
    local FishTab     = Win:CreateTab({ Name = "Fishing & Food", Icon = "fish" })
    local UpgradeTab  = Win:CreateTab({ Name = "Upgrade", Icon = "sparkles" })
    local DispatchTab = Win:CreateTab({ Name = "Dispatch", Icon = "send" })
    local RewardsTab  = Win:CreateTab({ Name = "Rewards", Icon = "gift" })
    local ExploitsTab = Win:CreateTab({ Name = "Exploits", Icon = "shield" })
    
    local SettingsTab
    if Win.AddSettingsTab then
        SettingsTab = Win:AddSettingsTab()
    else
        SettingsTab = Win:CreateTab({ Name = "Settings", Icon = "settings" })
    end

    -- Compatibility aliases for Section methods
    local function wrapSection(sec)
        if sec then
            if not sec.AddTextBox and sec.AddTextbox then
                sec.AddTextBox = sec.AddTextbox
            elseif not sec.AddTextbox and sec.AddTextBox then
                sec.AddTextbox = sec.AddTextBox
            end
        end
        return sec
    end

    -- === 1. ULTRA OPTIMIZED TARGET SEARCH ===
    task.spawn(function()
        while task.wait(0.15) do
            if killAuraActive or states.attack or states.skill1 or states.skill2 or states.skill3 then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local target = nil
                    local bestValue = priorityHighHP and 0 or math.huge
                    local monstersFolder = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies")

                    if monstersFolder then
                        for _, obj in ipairs(monstersFolder:GetChildren()) do
                            if obj:IsA("Model") then
                                local eHum = obj:FindFirstChildOfClass("Humanoid")
                                local eHrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                                if eHum and eHrp and eHum.Health > 0 and eHum.Health >= minHealthLimit then
                                    local dist = (eHrp.Position - hrp.Position).Magnitude
                                    if priorityHighHP then
                                        if eHum.Health > bestValue then bestValue = eHum.Health; target = obj end
                                    else
                                        if dist < bestValue then bestValue = dist; target = obj end
                                    end
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

    -- Hook DebugOptions to enable "无限火力" (Infinite Firepower mode) on client
    pcall(function()
        local DebugOptions = require(rs:WaitForChild("Packages"):WaitForChild("DebugOptions"))
        local oldIsEnable = DebugOptions.IsEnable
        DebugOptions.IsEnable = function(opt)
            if noSkillCd and opt == "无限火力" then return true end
            return oldIsEnable(opt)
        end
    end)

    -- === 2. ANIMATION CANCEL & NO SKILL LOCK ===
    task.spawn(function()
        while true do
            if noSkillCd or animCancel then
                local char = player.Character
                local hum = char and char:FindFirstChild("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if noSkillCd then
                    _G.Skilling = false
                    if hrp then
                        local p = hrp:FindFirstChild("SkillAlignPosition")
                        local o = hrp:FindFirstChild("SkillAlignOrientation")
                        if p and p.Enabled then p.Enabled = false end
                        if o and o.Enabled then o.Enabled = false end
                    end
                end
                if hum then
                    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                        local name = track.Name:lower()
                        if noSkillCd and name:find("skill") then track:Stop(0)
                        elseif animCancel and name:find("attack") then track:Stop(0) end
                    end
                end
            end
            task.wait(0.05)
        end
    end)

    -- === AUTO CAST SKILLS IN AURA ===
    task.spawn(function()
        while true do
            if autoCastSkills and (monsterNearby or killAuraActive) then
                local energy = player.LeaderEnergy and player.LeaderEnergy.Value or 0
                _G.Skilling = false; _G.Attacking = false
                if energy >= 40 then skillRemote:FireServer(3); task.wait(0.1); _G.Skilling = false
                elseif energy >= 25 then skillRemote:FireServer(2); task.wait(0.1); _G.Skilling = false
                elseif energy >= 15 then skillRemote:FireServer(1); task.wait(0.1); _G.Skilling = false end
                task.wait(0.15)
            else task.wait(0.4) end
        end
    end)

    -- === 3. FAST ATTACK ===
    task.spawn(function()
        while true do
            if states.attack then
                if monsterNearby or killAuraActive then
                    _G.Attacking = false; _G.AttackAnim = nil
                    attackRemote:FireServer(4)
                    if animCancel then
                        local hum = player.Character and player.Character:FindFirstChild("Humanoid")
                        if hum then
                            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                                if track.Name:find("Attack") then track:Stop(0) end
                            end
                        end
                    end
                    task.wait(1 / (speeds.attack or 20))
                else task.wait(0.1) end
            else task.wait(0.3) end
        end
    end)

    -- === 4. FAST SKILLS ===
    local function startSkillLoop(stateKey, skillNum)
        task.spawn(function()
            while states[stateKey] do
                if monsterNearby or killAuraActive then
                    _G.Skilling = false; _G.Attacking = false; _G.AttackAnim = nil
                    local char = player.Character
                    local hum = char and char:FindFirstChild("Humanoid")
                    if hum then
                        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                            if track.Name:find("Attack") or track.Name:find("Skill") then track:Stop(0) end
                        end
                    end
                    skillRemote:FireServer(skillNum)
                    task.wait(1 / (speeds.attack or 20))
                else task.wait(0.2) end
            end
        end)
    end

    -- === 5. MONSTER NEARBY CHECK ===
    task.spawn(function()
        while true do
            if states.attack or states.skill1 or states.skill2 or states.skill3 or killAuraActive then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local found = false
                if hrp then
                    if currentTarget and currentTarget.Parent and currentTarget:FindFirstChildOfClass("Humanoid") and currentTarget:FindFirstChildOfClass("Humanoid").Health > 0 then
                        local tPart = currentTarget:FindFirstChild("HumanoidRootPart") or currentTarget.PrimaryPart
                        if tPart and (tPart.Position - hrp.Position).Magnitude < 30 then found = true end
                    end
                    if not found then
                        local folder = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies")
                        if folder then
                            for _, v in ipairs(folder:GetChildren()) do
                                if v:IsA("Model") then
                                    local vHum = v:FindFirstChildOfClass("Humanoid")
                                    local vHrp = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                                    if vHum and vHrp and vHum.Health > 0 and (vHrp.Position - hrp.Position).Magnitude < 25 then found = true; break end
                                end
                            end
                        end
                    end
                end
                monsterNearby = found; task.wait(0.08)
            else monsterNearby = false; task.wait(0.5) end
        end
    end)

    -- === 6. NETWORK PAUSE FIX ===
    local CoreGui = game:GetService("CoreGui")
    local AntiGameplayPaused = nil
    local function destroyNetworkPause()
        pcall(function()
            local robloxGui = CoreGui:FindFirstChild("RobloxGui")
            if robloxGui then
                local netPause = robloxGui:FindFirstChild("CoreScripts/NetworkPause")
                if netPause then netPause:Destroy() end
            end
        end)
    end
    task.spawn(function()
        destroyNetworkPause()
        if AntiGameplayPaused then AntiGameplayPaused:Disconnect(); AntiGameplayPaused = nil end
        AntiGameplayPaused = CoreGui.ChildAdded:Connect(function(child)
            if child.Name == "RobloxGui" then task.wait(0.1); destroyNetworkPause() end
        end)
    end)

    -- === 7. ANTI AFK ===
    local xAFKx = nil
    pcall(function()
        xAFKx = player.Idled:Connect(function()
            local vu = game:GetService("VirtualUser")
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end)

    -- === 8. AUTO REJOIN ===
    local currentPlace = game.PlaceId
    local currentServer = game.JobId
    local autoReconnectEnabled = true
    local function reconnect()
        if player and autoReconnectEnabled then
            pcall(function() teleportService:TeleportToPlaceInstance(currentPlace, currentServer, player) end)
            task.wait(10)
            pcall(function() teleportService:Teleport(currentPlace, player) end)
        end
    end
    pcall(function()
        guiService.ErrorMessageChanged:Connect(function()
            local errorMsg = guiService:GetErrorMessage()
            if errorMsg and errorMsg ~= "" and autoReconnectEnabled then task.wait(5); reconnect() end
        end)
    end)

    -- =====================================================================
    --                            ATTACKS TAB
    -- =====================================================================
    MainTab:Column("left")
    local MoveSec = wrapSection(MainTab:CreateSection({ Name = "Movement & Speeds", Collapsible = true }))
    MoveSec:AddToggle({
        Name = "SpeedHack", Default = false,
        Callback = function(state)
            isSpeedHack = state
            if state then
                if speedConn then speedConn:Disconnect() end
                speedConn = runService.Heartbeat:Connect(function()
                    local char = player.Character; local hum = char and char:FindFirstChild("Humanoid")
                    if isSpeedHack and hum then hum.WalkSpeed = walkSpeedValue end
                end)
            else
                if speedConn then speedConn:Disconnect(); speedConn = nil end
                local char = player.Character; local hum = char and char:FindFirstChild("Humanoid")
                if hum then hum.WalkSpeed = 16 end
            end
        end
    })
    MoveSec:AddSlider({
        Name = "Walk Speed", Min = 16, Max = 250, Default = walkSpeedValue, Suffix = " ws", Decimals = 0,
        Callback = function(val)
            walkSpeedValue = tonumber(val) or 50
            if isSpeedHack then
                local char = player.Character; local hum = char and char:FindFirstChild("Humanoid")
                if hum then hum.WalkSpeed = walkSpeedValue end
            end
        end
    })
    MoveSec:AddSlider({
        Name = "CPS Speed", Min = 1, Max = 50, Default = speeds.attack or 20, Suffix = " cps", Decimals = 0,
        Callback = function(val) speeds.attack = tonumber(val) or 20 end
    })
    MoveSec:AddToggle({ Name = "Fast General Attack", Default = false, Callback = function(state) states.attack = state end })

    local SkillsSec = wrapSection(MainTab:CreateSection({ Name = "Skills & Infinite Firepower", Collapsible = true }))
    SkillsSec:AddToggle({ Name = "No Skill CD / No Lock (Ultra)", Default = false, Callback = function(state)
        noSkillCd = state
        if state then _G.Skilling = false; Notify("Moro Soul", "No Skill CD & Lock Active!", 2, "Success") end
    end })
    SkillsSec:AddToggle({ Name = "Auto Cast Skills (In Aura)", Default = false, Callback = function(state) autoCastSkills = state end })
    SkillsSec:AddToggle({ Name = "Fast Skill 1", Default = false, Callback = function(state) states.skill1 = state; if state then startSkillLoop("skill1", 1) end end })
    SkillsSec:AddToggle({ Name = "Fast Skill 2", Default = false, Callback = function(state) states.skill2 = state; if state then startSkillLoop("skill2", 2) end end })
    SkillsSec:AddToggle({ Name = "Fast Skill 3", Default = false, Callback = function(state) states.skill3 = state; if state then startSkillLoop("skill3", 3) end end })

    MainTab:Column("right")
    local AuraSec = wrapSection(MainTab:CreateSection({ Name = "Kill Aura V67 (Ultra)", Collapsible = true }))
    AuraSec:AddToggle({
        Name = "Kill Aura V67 (Ultra)", Default = false,
        Callback = function(state)
            killAuraActive = state; states.attack = state
            if killAuraActive then
                task.spawn(function()
                    local target = nil; local lastTarget = nil
                    while killAuraActive do
                        local char = player.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local isAlive = target and target.Parent and target:FindFirstChildOfClass("Humanoid") and target:FindFirstChildOfClass("Humanoid").Health > 0
                            if not isAlive then
                                target = currentTarget
                                if not target or not target.Parent then
                                    local monsters = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies")
                                    if monsters then
                                        local closestDist = math.huge
                                        for _, m in ipairs(monsters:GetChildren()) do
                                            local mHum = m:FindFirstChildOfClass("Humanoid"); local mHrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                                            if mHum and mHrp and mHum.Health > 0 and mHum.Health >= minHealthLimit then
                                                local d = (mHrp.Position - hrp.Position).Magnitude
                                                if d < closestDist then closestDist = d; target = m end
                                            end
                                        end
                                    end
                                end
                            end
                            if target and target.Parent then
                                local tHrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
                                local tHum = target:FindFirstChildOfClass("Humanoid")
                                if tHrp and tHum and tHum.Health > 0 then
                                    local currentDist = (hrp.Position - tHrp.Position).Magnitude
                                    if target ~= lastTarget or currentDist > 12 then
                                        lastTarget = target
                                        local targetCF = tHrp.CFrame * CFrame.new(0, tpHeight or 2, 2)
                                        hrp.CFrame = CFrame.lookAt(targetCF.Position, tHrp.Position)
                                        hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
                                    end
                                    if char:FindFirstChild("LockedEnermy") and char.LockedEnermy.Value ~= target then char.LockedEnermy.Value = target end
                                    _G.Attacking = false; _G.Skilling = false
                                else target = nil; lastTarget = nil end
                            else target = nil; lastTarget = nil end
                        end
                        task.wait(0.08)
                    end
                    if player.Character and player.Character:FindFirstChild("LockedEnermy") then player.Character.LockedEnermy.Value = nil end
                end)
                Notify("Moro Soul", "Kill Aura Activated!", 2, "Success")
            else Notify("Moro Soul", "Kill Aura Disabled", 2, "Info") end
        end
    })
    AuraSec:AddToggle({ Name = "Priority: Max HP First", Default = false, Callback = function(state) priorityHighHP = state end })
    AuraSec:AddSlider({ Name = "Kill Aura TP Height", Min = -5, Max = 15, Default = tpHeight or 2, Suffix = " studs", Decimals = 0, Callback = function(val) tpHeight = tonumber(val) or 2 end })
    AuraSec:AddTextbox({ Name = "Min HP Filter", Default = tostring(minHealthLimit), Placeholder = "0", Numeric = true, Callback = function(val) minHealthLimit = tonumber(val) or 0 end })

    local EventSec = wrapSection(MainTab:CreateSection({ Name = "Event Farms", Collapsible = true }))
    EventSec:AddToggle({
        Name = "Christmas Aura V2", Default = false,
        Callback = function(state)
            _G.ChristmasAuraV2 = state
            if not state then
                workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                if player.Character and player.Character:FindFirstChild("Humanoid") then workspace.CurrentCamera.CameraSubject = player.Character.Humanoid end
            end
            Notify("System", state and "Christmas Farm V2 Active!" or "Disabled", 2, state and "Success" or "Info")
        end
    })

    _G.ChristmasAuraV2 = false
    task.spawn(function()
        local camera = workspace.CurrentCamera; local genAttack = remoteFolder:WaitForChild("GeneralAttack")
        local function GetBoss()
            local folder = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies")
            if folder then
                for _, e in ipairs(folder:GetChildren()) do
                    if e:IsA("Model") then
                        local hum = e:FindFirstChildOfClass("Humanoid"); local hrp = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                        if hum and hrp and hum.Health > 0 and hum.MaxHealth >= 5000000 then return e end
                    end
                end
            end
            return nil
        end
        local camCfg = { z1 = {p = Vector3.new(195, 142, -336), l = Vector3.new(195, 0, -336)}, z2 = {p = Vector3.new(28, 147, -36), l = Vector3.new(28, 0, -36)} }
        while true do
            if _G.ChristmasAuraV2 then
                local char = player.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local function UpdateCam(pos)
                        local d1 = (pos - camCfg.z1.l).Magnitude; local d2 = (pos - camCfg.z2.l).Magnitude
                        local current = d1 < d2 and camCfg.z1 or camCfg.z2
                        camera.CameraType = Enum.CameraType.Scriptable; camera.CFrame = CFrame.new(current.p, current.l) * CFrame.Angles(0, 0, math.rad(90))
                    end
                    local targetBoss = GetBoss()
                    if targetBoss then
                        local tHrp = targetBoss:FindFirstChild("HumanoidRootPart") or targetBoss.PrimaryPart; local tHum = targetBoss:FindFirstChildOfClass("Humanoid")
                        if tHrp and tHum then
                            UpdateCam(tHrp.Position); hrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3); hrp.AssemblyLinearVelocity = Vector3.zero
                            while _G.ChristmasAuraV2 and tHum.Health > 0 and targetBoss.Parent do
                                if (hrp.Position - tHrp.Position).Magnitude > 12 then hrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3); hrp.AssemblyLinearVelocity = Vector3.zero end
                                genAttack:FireServer(4); task.wait(speeds and 1 / (speeds.attack or 20))
                            end
                        end
                    else
                        local ghostPos = workspace:FindFirstChild("GhostPos")
                        if ghostPos then
                            local zones = {"荒野", "无线列车", "主公宅邸", "紫藤山"}
                            for _, name in ipairs(zones) do
                                local f = ghostPos:FindFirstChild(name)
                                if f then
                                    for _, obj in ipairs(f:GetDescendants()) do
                                        if not _G.ChristmasAuraV2 or GetBoss() then break end
                                        if obj:IsA("BasePart") and obj.Name ~= "对象038" then
                                            UpdateCam(obj.Position); hrp.CFrame = obj.CFrame; hrp.AssemblyLinearVelocity = Vector3.zero
                                            for k = 1, 6 do genAttack:FireServer(4); task.wait(speeds and 1 / (speeds.attack or 20)) end
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

    -- SPRING FARM
    local flySpeed = 250; local isFlying = false; local currentTween = nil
    local function patrolFly(targetCFrame)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        isFlying = true; local distance = (hrp.Position - targetCFrame.Position).Magnitude; local duration = distance / flySpeed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = tweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        tween.Completed:Connect(function() task.wait(0.1); isFlying = false end)
        tween:Play(); return tween
    end

    EventSec:AddToggle({
        Name = "Spring farm", Default = false,
        Callback = function(state)
            _G.SpringFarm = state; states.attack = state 
            if state then Notify("Moro Soul", "Priority Patrol Started", 2, "Info")
            else isFlying = false; if currentTween then currentTween:Cancel() end end
        end
    })
    local farmPoints = { Vector3.new(208, 30, -319), Vector3.new(6, 30, -52), Vector3.new(209, 30, 219), Vector3.new(437, 30, 478), Vector3.new(386, 30, 740), Vector3.new(438, 30, 1014) }
    local currentPointIdx = 1
    task.spawn(function()
        local lastFoundTime = tick()
        while task.wait(0.15) do
            if _G.SpringFarm then
                local monsters = workspace:FindFirstChild("Monsters"); local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if monsters and hrp then
                    local target = nil
                    if isFlying then lastFoundTime = tick(); continue end
                    for _, monster in ipairs(monsters:GetChildren()) do
                        local tHum = monster:FindFirstChildOfClass("Humanoid")
                        if tHum and tHum.Health > 0 then
                            local hasHat = monster:FindFirstChild("SpringHat"); local isBoss = tHum.MaxHealth >= 5000000
                            if hasHat or isBoss then
                                local targetPart = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChild("Head") or monster.PrimaryPart
                                if hasHat and monster.SpringHat:FindFirstChild("Handle") then targetPart = monster.SpringHat.Handle end
                                if targetPart then target = {monster = monster, part = targetPart, hum = tHum, type = isBoss and "BOSS" or "EVENT"}; break end
                            end
                        end
                    end
                    if target then
                        lastFoundTime = tick(); local targetCF = target.part.CFrame * CFrame.new(0, tpHeight or 2, 0); hrp.CFrame = targetCF
                        while _G.SpringFarm and target.hum.Health > 0 and target.monster.Parent do
                            hrp.AssemblyLinearVelocity = Vector3.zero; local currentTargetCF = target.part.CFrame
                            if (hrp.Position - currentTargetCF.Position).Magnitude > 12 then hrp.CFrame = currentTargetCF * CFrame.new(0, tpHeight or 2, 0) end
                            task.wait(0.1)
                        end
                    else
                        if (tick() - lastFoundTime) > 3 then
                            currentPointIdx = currentPointIdx + 1
                            if currentPointIdx > #farmPoints then currentPointIdx = 1; hrp.CFrame = CFrame.new(farmPoints[currentPointIdx]); Notify("Moro Soul", "Teleported to Start", 1, "Info"); lastFoundTime = tick()
                            else currentTween = patrolFly(CFrame.new(farmPoints[currentPointIdx])) end
                        end
                    end
                end
            end
        end
    end)

    -- =====================================================================
    --                             TRAIN TAB
    -- =====================================================================
    local autoTrain = false; local autoTrainV2 = false; _G.TrainSkillNumber = 2
    local function AdvanceTrainLevel()
        local it = workspace:FindFirstChild("InfinityTrain")
        if not it or not it.PrimaryPart then return end
        local trigger = it.PrimaryPart:FindFirstChild("ContinueTrigger"); local prompt = trigger and trigger:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt and fireproximityprompt then fireproximityprompt(prompt); return end
        if AttackHelper and AttackHelper.GoToNextTrain then pcall(function() AttackHelper.GoToNextTrain(it.PrimaryPart.PlayerSpawnPos.WorldCFrame, it.PrimaryPart.GhostSpawnPos.WorldCFrame) end); return end
        local nextDoor = it:FindFirstChild("Portal") and it.Portal:FindFirstChild("Next"); local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp and nextDoor then hrp.CFrame = nextDoor.CFrame; task.wait(0.08); vim:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.1); vim:SendKeyEvent(false, Enum.KeyCode.E, false, game) end
    end

    -- Train Mode V1 (General Attack)
    task.spawn(function()
        while true do
            task.wait(0.15)
            if autoTrain then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); local it = workspace:FindFirstChild("InfinityTrain")
                if not hrp or not it then continue end
                local trainPoint = it:FindFirstChild("Train")
                if trainPoint and (hrp.Position - trainPoint.Position).Magnitude > 10 then hrp.CFrame = trainPoint.CFrame * CFrame.new(0, 2, 0); hrp.AssemblyLinearVelocity = Vector3.zero end
                local monster = nil; local scanStart = tick()
                while autoTrain and not monster and (tick() - scanStart < 4) do
                    local monsters = workspace:FindFirstChild("Monsters")
                    if monsters and trainPoint then
                        for _, v in ipairs(monsters:GetChildren()) do
                            local hum = v:FindFirstChildOfClass("Humanoid"); local part = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                            if hum and part and hum.Health > 0 then if (part.Position - trainPoint.Position).Magnitude < 60 then monster = v; break end end
                        end
                    end
                    task.wait(0.1)
                end
                if monster and autoTrain then
                    local mHrp = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart; local mHum = monster:FindFirstChildOfClass("Humanoid")
                    if mHrp and hrp then hrp.CFrame = CFrame.lookAt(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position); hrp.AssemblyLinearVelocity = Vector3.zero end
                    while autoTrain and mHum and mHum.Health > 0 and monster.Parent do
                        if mHrp and hrp and (hrp.Position - mHrp.Position).Magnitude > 12 then hrp.CFrame = CFrame.lookAt(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position); hrp.AssemblyLinearVelocity = Vector3.zero end
                        _G.Attacking = false; attackRemote:FireServer(4); task.wait(1 / (speeds.attack or 20))
                    end
                    task.wait(0.1)
                end
                if autoTrain then AdvanceTrainLevel(); task.wait(0.3) end
            end
        end
    end)

    -- Train Mode V2 (Attack + Selected Skill) - FIXED CLEAN LOGIC
    task.spawn(function()
        while true do
            task.wait(0.15)
            if autoTrainV2 then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local it = workspace:FindFirstChild("InfinityTrain")
                if not hrp or not it then continue end

                local trainPoint = it:FindFirstChild("Train")
                if trainPoint and (hrp.Position - trainPoint.Position).Magnitude > 10 then
                    hrp.CFrame = trainPoint.CFrame * CFrame.new(0, 2, 0)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end

                local monster = nil
                local scanStart = tick()
                while autoTrainV2 and not monster and (tick() - scanStart < 4) do
                    local monsters = workspace:FindFirstChild("Monsters")
                    if monsters and trainPoint then
                        for _, v in ipairs(monsters:GetChildren()) do
                            local hum = v:FindFirstChildOfClass("Humanoid")
                            local part = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                            if hum and part and hum.Health > 0 then
                                if (part.Position - trainPoint.Position).Magnitude < 60 then monster = v; break end
                            end
                        end
                    end
                    task.wait(0.1)
                end

                if monster and autoTrainV2 then
                    local mHrp = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
                    local mHum = monster:FindFirstChildOfClass("Humanoid")
                    if mHrp and hrp then
                        hrp.CFrame = CFrame.lookAt(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                    while autoTrainV2 and mHum and mHum.Health > 0 and monster.Parent do
                        if mHrp and hrp and (hrp.Position - mHrp.Position).Magnitude > 12 then
                            hrp.CFrame = CFrame.lookAt(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                        _G.Attacking = false; _G.Skilling = false
                        attackRemote:FireServer(4) 
                        skillRemote:FireServer(_G.TrainSkillNumber)
                        task.wait(1 / (speeds.attack or 20))
                    end
                    task.wait(0.1)
                end

                if autoTrainV2 then AdvanceTrainLevel(); task.wait(0.3) end
            end
        end
    end)

    TrainTab:Column("left")
    local TrainSec = wrapSection(TrainTab:CreateSection({ Name = "Infinity Train Farming", Collapsible = true }))
    TrainSec:AddToggle({
        Name = "Infinity Train (TP Mode)", Default = false,
        Callback = function(state) autoTrain = state; if state then autoTrainV2 = false end; Notify("Moro Soul", state and "Auto Train Active" or "Disabled", 2, state and "Success" or "Info") end
    })
    TrainSec:AddToggle({
        Name = "Infinity Train V2 (Skills)", Default = false,
        Callback = function(state) autoTrainV2 = state; if state then autoTrain = false end; Notify("Moro Soul", state and "Train V2 Active" or "Train V2 Disabled", 2, state and "Success" or "Info") end
    })
    TrainSec:AddDropdown({
        Name = "Train V2 Skill", Options = {"Skill 1", "Skill 2", "Skill 3"}, Default = "Skill 2",
        Callback = function(selected)
            if selected == "Skill 1" then _G.TrainSkillNumber = 1
            elseif selected == "Skill 2" then _G.TrainSkillNumber = 2
            elseif selected == "Skill 3" then _G.TrainSkillNumber = 3 end
            Notify("Moro Soul", "Train V2 using: " .. tostring(selected), 2, "Info")
        end
    })
    TrainTab:Column("right")
    local TrainTpSec = wrapSection(TrainTab:CreateSection({ Name = "Train Teleports", Collapsible = true }))
    TrainTpSec:AddButton({
        Name = "Teleport to Train Entrance 1", Primary = false,
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); local entrance = workspace:FindFirstChild("PromptTriggers") and workspace.PromptTriggers:FindFirstChild("Train_Entrance_1")
            if hrp and entrance then hrp.CFrame = entrance.CFrame + Vector3.new(0, 3, 0); Notify("Moro Soul", "Teleported to Train Entrance 1", 2, "Success") else Notify("Error", "Entrance point not found!", 2, "Error") end
        end
    })
    TrainTpSec:AddButton({
        Name = "Teleport to Train Entrance 2", Primary = false,
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); local entrance = workspace:FindFirstChild("PromptTriggers") and workspace.PromptTriggers:FindFirstChild("Train_Entrance_2")
            if hrp and entrance then hrp.CFrame = entrance.CFrame + Vector3.new(0, 3, 0); Notify("Moro Soul", "Teleported to Train Entrance 2", 2, "Success") else Notify("Error", "Entrance 2 not found!", 2, "Error") end
        end
    })

    local autoCrowdTpConn = false; local lastWaypoint = Vector3.new(438, 35, 1014)
    local function GetBestCrowdPos()
        local playersList = players:GetPlayers(); local bestTargetPos = nil; local maxNearby = -1; local minDistanceToWaypoint = math.huge
        for _, p in ipairs(playersList) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local currentPos = p.Character.HumanoidRootPart.Position; local nearbyCount = 0
                for _, otherP in ipairs(playersList) do
                    if otherP.Character and otherP.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (currentPos - otherP.Character.HumanoidRootPart.Position).Magnitude
                        if dist < 20 then nearbyCount = nearbyCount + 1 end
                    end
                end
                local distToLastPoint = (currentPos - lastWaypoint).Magnitude
                if nearbyCount > maxNearby or (nearbyCount == maxNearby and distToLastPoint < minDistanceToWaypoint) then maxNearby = nearbyCount; minDistanceToWaypoint = distToLastPoint; bestTargetPos = p.Character.HumanoidRootPart.CFrame end
            end
        end
        return bestTargetPos, maxNearby
    end

    ExploitsTab:Column("right")
    local CrowdSec = wrapSection(ExploitsTab:CreateSection({ Name = "Crowd Teleport", Collapsible = true }))
    CrowdSec:AddToggle({
        Name = "Auto TP to Crowd", Default = false,
        Callback = function(state)
            autoCrowdTpConn = state
            if state then
                task.spawn(function()
                    while autoCrowdTpConn do
                        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local bestTargetPos, _ = GetBestCrowdPos()
                            if bestTargetPos then hrp.CFrame = bestTargetPos end
                        end
                        task.wait(10)
                    end
                end)
            end
        end
    })
    CrowdSec:AddButton({
        Name = "TP to Crowd (Once)", Primary = false,
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local bestTargetPos, maxNearby = GetBestCrowdPos()
            if bestTargetPos then hrp.CFrame = bestTargetPos; Notify("Moro Soul", "TP to Crowd (" .. maxNearby .. " players)", 2, "Success") else Notify("Moro Soul", "No crowd found", 2, "Warning") end
        end
    })

    -- =====================================================================
    --                           DISPATCH TAB
    -- =====================================================================
    local selectedRole1 = nil; local selectedRole2 = nil; local selectedRole3 = nil
    DispatchTab:Column("left")
    local RoleSec = wrapSection(DispatchTab:CreateSection({ Name = "Select Roles", Collapsible = true }))
    RoleSec:AddDropdown({ Name = "Select Role 1", Options = roleNames, Default = roleNames[1] or "", Callback = function(val) selectedRole1 = dispatchRoles[val] end })
    RoleSec:AddDropdown({ Name = "Select Role 2", Options = roleNames, Default = roleNames[2] or "", Callback = function(val) selectedRole2 = dispatchRoles[val] end })
    RoleSec:AddDropdown({ Name = "Select Role 3", Options = roleNames, Default = roleNames[3] or "", Callback = function(val) selectedRole3 = dispatchRoles[val] end })

    local ManualDispatchSec = wrapSection(DispatchTab:CreateSection({ Name = "Manual Dispatch Actions", Collapsible = true }))
    ManualDispatchSec:AddButton({
        Name = "Send Selected to Dispatch", Primary = true,
        Callback = function()
            local toSend = {}
            if selectedRole1 then table.insert(toSend, selectedRole1) end
            if selectedRole2 then table.insert(toSend, selectedRole2) end
            if selectedRole3 then table.insert(toSend, selectedRole3) end
            if #toSend == 0 then Notify("Moro Soul", "Select at least one role!", 2, "Warning"); return end
            task.spawn(function()
                for _, roleId in ipairs(toSend) do remoteFolder.Dispatch:FireServer(roleId); task.wait(0.15) end
                Notify("Moro Soul", "Sent " .. #toSend .. " roles to dispatch!", 2, "Success")
            end)
        end
    })
    ManualDispatchSec:AddButton({
        Name = "Claim Rewards", Primary = false,
        Callback = function()
            local idsToClaim = {}
            if selectedRole1 then table.insert(idsToClaim, selectedRole1) end
            if selectedRole2 then table.insert(idsToClaim, selectedRole2) end
            if selectedRole3 then table.insert(idsToClaim, selectedRole3) end
            if #idsToClaim > 0 then
                if EventBus and EventBus.FireServer then EventBus.FireServer("ClaimDispatchReward", idsToClaim) else rs.Packages.EventBus.EventProvider.default_RemoteEvent:FireServer("ClaimDispatchReward", idsToClaim) end
                Notify("Moro Soul", "Claimed rewards for " .. #idsToClaim .. " roles!", 2, "Success")
            else Notify("Moro Soul", "Select roles to claim!", 2, "Warning") end
        end
    })
    ManualDispatchSec:AddButton({
        Name = "Cancel Dispatch", Primary = false,
        Callback = function()
            local toCancel = {}
            if selectedRole1 then table.insert(toCancel, selectedRole1) end
            if selectedRole2 then table.insert(toCancel, selectedRole2) end
            if selectedRole3 then table.insert(toCancel, selectedRole3) end
            if #toCancel == 0 then Notify("Moro Soul", "No roles selected to cancel!", 2, "Warning"); return end
            task.spawn(function()
                for _, roleId in ipairs(toCancel) do remoteFolder.CancelDispatch:FireServer(roleId); task.wait(0.1) end
                Notify("Moro Soul", "Cancelled dispatch for selected roles!", 2, "Info")
            end)
        end
    })

    DispatchTab:Column("right")
    local AutoDispatchSec = wrapSection(DispatchTab:CreateSection({ Name = "Automated Dispatch", Collapsible = true }))
    local autoDispatchConn = false
    AutoDispatchSec:AddToggle({
        Name = "Auto Dispatch", Default = false,
        Callback = function(state)
            autoDispatchConn = state
            if state then
                task.spawn(function()
                    while autoDispatchConn do
                        local roles = {}
                        if selectedRole1 then table.insert(roles, selectedRole1) end
                        if selectedRole2 then table.insert(roles, selectedRole2) end
                        if selectedRole3 then table.insert(roles, selectedRole3) end
                        if #roles == 0 then Notify("Moro Soul", "AutoDispatch: No roles selected!", 2, "Warning"); autoDispatchConn = false; break end
                        for _, roleId in ipairs(roles) do
                            if not autoDispatchConn then break end
                            remoteFolder.Dispatch:FireServer(roleId); task.wait(0.2)
                        end
                        Notify("Moro Soul", "AutoDispatch: Sent roles. Monitoring timers...", 2, "Info")
                        local dispatchDuration = 1802
                        pcall(function() dispatchDuration = rs.Configs.GlobalConfigs.DispatchTime.Value + 2 end)
                        for i = 1, dispatchDuration do if not autoDispatchConn then break end; task.wait(1) end
                        if not autoDispatchConn then break end
                        if EventBus and EventBus.FireServer then EventBus.FireServer("ClaimDispatchReward", roles) else rs.Packages.EventBus.EventProvider.default_RemoteEvent:FireServer("ClaimDispatchReward", roles) end
                        Notify("Moro Soul", "AutoDispatch: Rewards claimed! Restarting...", 2, "Success"); task.wait(3)
                    end
                end)
            else Notify("Moro Soul", "Auto Dispatch Disabled", 2, "Info") end
        end
    })
    AutoDispatchSec:AddButton({
        Name = "Claim All Ready Dispatches", Primary = false,
        Callback = function()
            local pd = rs:FindFirstChild("PlayerData") and rs.PlayerData:FindFirstChild(player.Name); local dInfo = pd and pd:FindFirstChild("DispatchInfo"); local readyList = {}
            local dispatchTime = 1800
            pcall(function() dispatchTime = rs.Configs.GlobalConfigs.DispatchTime.Value end)
            if dInfo then
                for _, child in ipairs(dInfo:GetChildren()) do if child.Value >= dispatchTime then table.insert(readyList, tonumber(child.Name)) end end
            end
            if #readyList > 0 then
                if EventBus and EventBus.FireServer then EventBus.FireServer("ClaimDispatchReward", readyList) else rs.Packages.EventBus.EventProvider.default_RemoteEvent:FireServer("ClaimDispatchReward", readyList) end
                Notify("Moro Soul", "Claimed " .. #readyList .. " ready dispatches!", 2, "Success")
            else Notify("Moro Soul", "No dispatches ready to claim yet", 2, "Info") end
        end
    })

    -- =====================================================================
    --                           REWARDS & QUESTS TAB
    -- =====================================================================
    local promoCodes = { "demon", "demonsoul", "demonsoul300k", "thanks3000likes", "Welcome", "1000likes", "demon150k", "demon100k", "demon50k", "demon20k", "demon10k", "10klikes", "5000likes", "2000likes", "3000likes", "100kmembers", "200kmembers", "300kmembers", "400kmembers", "500kmembers", "600kmembers", "700kmembers", "800kmembers", "1Mmembers", "ADouma", "dakigo", "gyutarogo", "tengen", "shinobu", "kamado", "zenitsu", "inosuke", "kyojuro", "akaza", "rui", "demon500k", "demon600k", "demon700k", "demon800k", "demon1m" }
    RewardsTab:Column("left")
    local PromoSec = wrapSection(RewardsTab:CreateSection({ Name = "Promo Codes", Collapsible = true }))
    PromoSec:AddButton({
        Name = "Redeem All Promo Codes", Primary = true,
        Callback = function()
            task.spawn(function()
                Notify("Moro Soul", "Redeeming all codes...", 2, "Info"); local redeemed = 0
                for _, code in ipairs(promoCodes) do pcall(function() remoteFolder.Code:FireServer(code) end); redeemed = redeemed + 1; task.wait(0.35) end
                Notify("Moro Soul", "Finished! Sent " .. redeemed .. " codes.", 3, "Success")
            end)
        end
    })
    local customCodeText = ""
    PromoSec:AddTextbox({ Name = "Custom Code", Default = "", Placeholder = "Enter promo code...", Callback = function(val) customCodeText = val end })
    PromoSec:AddButton({
        Name = "Redeem Custom Code", Primary = false,
        Callback = function()
            if customCodeText and #customCodeText > 0 then pcall(function() remoteFolder.Code:FireServer(customCodeText) end); Notify("Moro Soul", "Redeemed code: " .. customCodeText, 2, "Success") else Notify("Moro Soul", "Enter a code first!", 2, "Warning") end
        end
    })
    local RouletteSec = wrapSection(RewardsTab:CreateSection({ Name = "Daily Roulette", Collapsible = true }))
    local function spinRoulette()
        local pd = rs:FindFirstChild("PlayerData") and rs.PlayerData:FindFirstChild(player.Name); local lastTime = pd and pd:FindFirstChild("LastRouletteTime") and pd.LastRouletteTime.Value or 0; local elapsed = os.time() - lastTime
        if elapsed >= 86400 then pcall(function() remoteFolder.Roulette:FireServer() end); Notify("Moro Soul", "Daily Roulette Spun!", 3, "Success"); return true else local remaining = 86400 - elapsed; local h = math.floor(remaining / 3600); local m = math.floor((remaining % 3600) / 60); Notify("Moro Soul", string.format("Roulette CD: %02d h %02d min", h, m), 3, "Info"); return false end
    end
    RouletteSec:AddButton({ Name = "Spin Daily Roulette", Primary = false, Callback = function() spinRoulette() end })
    RouletteSec:AddToggle({ Name = "Auto Daily Roulette", Default = false, Callback = function(state) autoRoulette = state; if state then task.spawn(function() while autoRoulette do spinRoulette(); task.wait(60) end end) end end })

    RewardsTab:Column("right")
    local ChestsSec = wrapSection(RewardsTab:CreateSection({ Name = "World Chests & Drops", Collapsible = true }))
    local function safeFirePrompt(obj)
        if not obj then return false end
        local pp = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if pp then
            if fireproximityprompt then fireproximityprompt(pp, 0); return true else local char = player.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart"); if hrp and obj:IsA("PVInstance") then hrp.CFrame = obj:GetPivot(); task.wait(0.1); vim:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.2); vim:SendKeyEvent(false, Enum.KeyCode.E, false, game); return true end end
        end
        return false
    end
    ChestsSec:AddButton({
        Name = "Collect ALL Rewards & Chests", Primary = true,
        Callback = function()
            task.spawn(function()
                local char = player.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart"); local savedCF = hrp and hrp.CFrame; local pt = workspace:FindFirstChild("PromptTriggers")
                if not pt then return end
                local items = {"TrainChest_1", "TrainChest_2", "MysteryBoxTouch", "GroupRewardTouch"}; local collected = 0
                for _, name in ipairs(items) do
                    local target = pt:FindFirstChild(name)
                    if target and target:IsA("PVInstance") and hrp then hrp.CFrame = target:GetPivot() + Vector3.new(0, 1, 0); task.wait(0.15); if safeFirePrompt(target) then collected = collected + 1 end; task.wait(0.2) end
                end
                if savedCF and hrp then hrp.CFrame = savedCF end
                Notify("Moro Soul", "Collected " .. collected .. " rewards & returned!", 3, "Success")
            end)
        end
    })
    ChestsSec:AddButton({ Name = "Collect Train Chests (1 & 2)", Primary = false, Callback = function() local pt = workspace:FindFirstChild("PromptTriggers"); if pt then local c1 = pt:FindFirstChild("TrainChest_1"); local c2 = pt:FindFirstChild("TrainChest_2"); local count = 0; if safeFirePrompt(c1) then count = count + 1 end; task.wait(0.2); if safeFirePrompt(c2) then count = count + 1 end; Notify("Moro Soul", "Collected " .. count .. " Train Chests", 2, "Success") end end })
    ChestsSec:AddButton({ Name = "Collect Mystery Box", Primary = false, Callback = function() local pt = workspace:FindFirstChild("PromptTriggers"); local mb = pt and pt:FindFirstChild("MysteryBoxTouch"); if safeFirePrompt(mb) then Notify("Moro Soul", "Collected Mystery Box!", 2, "Success") else Notify("Moro Soul", "Mystery Box not found!", 2, "Warning") end end })
    ChestsSec:AddButton({ Name = "Claim Group Reward", Primary = false, Callback = function() local pt = workspace:FindFirstChild("PromptTriggers"); local gr = pt and pt:FindFirstChild("GroupRewardTouch"); if safeFirePrompt(gr) then Notify("Moro Soul", "Claimed Group Reward!", 2, "Success") else Notify("Moro Soul", "Group Reward not found!", 2, "Warning") end end })
    local MissionSec = wrapSection(RewardsTab:CreateSection({ Name = "Missions & Attendance", Collapsible = true }))
    local function claimDailyAttendance() local WuKong = nil; pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end); if WuKong then local success = pcall(function() WuKong:ExecuteAction("/活动/每日登录奖励/领取每日登录奖励?购买", "__null__", "__null__") end); if success then Notify("Moro Soul", "Daily Attendance Claimed!", 3, "Success"); return true end end; return false end
    local function claimReadyMissions() local WuKong = nil; pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end); if not WuKong then return 0 end; local claimed = 0; pcall(function() local subitems = WuKong:ExecuteQuery("/任务/日常任务分组?已激活子项"); if subitems then for _, group in pairs(subitems) do local children = WuKong:ExecuteQuery(("/任务/日常任务分组/%*?已激活子项"):format(group)); if children then for _, id in pairs(children) do local path = ("/任务/日常任务分组/%*/%*"):format(group, id); local config = WuKong:ExecuteQuery(path .. "?获取元素配置"); local progress = WuKong:ExecuteQuery(path .. "?获取监听事件计数"); if config and config.Tags and progress then local maxProgress = config.Tags[3] - 0; if progress >= maxProgress then local validate = WuKong:ExecuteValidate(path .. "?购买验证", "__null__", "__null__"); if validate and not validate:getHasError() then pcall(function() WuKong:ExecuteAction(path .. "?购买"); claimed = claimed + 1 end); task.wait(0.2) end end end end end end end end end); return claimed end
    MissionSec:AddButton({ Name = "Claim Daily Attendance (7-Day)", Primary = false, Callback = function() if not claimDailyAttendance() then Notify("Moro Soul", "Attendance already claimed or not ready", 2, "Info") end end })
    MissionSec:AddButton({ Name = "Claim Ready Daily Missions", Primary = false, Callback = function() task.spawn(function() local c = claimReadyMissions(); if c > 0 then Notify("Moro Soul", "Claimed " .. c .. " daily missions!", 3, "Success") else Notify("Moro Soul", "No missions ready to claim", 2, "Info") end end) end })
    MissionSec:AddToggle({ Name = "Auto Claim Missions", Default = false, Callback = function(state) autoMissions = state; if state then task.spawn(function() while autoMissions do claimDailyAttendance(); claimReadyMissions(); task.wait(30) end end) end end })

    -- =====================================================================
    --                           EXPLOITS TAB
    -- =====================================================================
    ExploitsTab:Column("left")
    local WallSec = wrapSection(ExploitsTab:CreateSection({ Name = "World & Wall Exploits", Collapsible = true }))
    local bypassWallsActive = false; local wallConn = nil
    local function applyWallBypass() local walls = workspace:FindFirstChild("LockedAreaWalls"); if walls then for _, model in ipairs(walls:GetChildren()) do for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false; part.Transparency = 0.7 end end end end end end
    WallSec:AddToggle({
        Name = "Bypass Locked Walls", Default = false,
        Callback = function(state)
            bypassWallsActive = state
            if state then applyWallBypass(); if wallConn then wallConn:Disconnect() end; wallConn = runService.Heartbeat:Connect(function() if bypassWallsActive then applyWallBypass() end end); Notify("Moro Soul", "Locked Walls Bypassed! All Areas Accessible", 2, "Success")
            else if wallConn then wallConn:Disconnect(); wallConn = nil end; local walls = workspace:FindFirstChild("LockedAreaWalls"); if walls then for _, model in ipairs(walls:GetChildren()) do for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true; part.Transparency = 0 end end end end end; Notify("Moro Soul", "Locked Walls Restored", 2, "Info") end
        end
    })
    local noClipActive = false; local noClipConn = nil
    WallSec:AddToggle({
        Name = "No-Clip (Ghost Mode)", Default = false,
        Callback = function(state)
            noClipActive = state
            if state then if noClipConn then noClipConn:Disconnect() end; noClipConn = runService.Stepped:Connect(function() local char = player.Character; if char and noClipActive then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end end end end); Notify("Moro Soul", "No-Clip Activated!", 2, "Success")
            else if noClipConn then noClipConn:Disconnect(); noClipConn = nil end; Notify("Moro Soul", "No-Clip Disabled", 2, "Info") end
        end
    })
    local infJumpActive = false; local infJumpConn = nil
    WallSec:AddToggle({
        Name = "Infinite Jump", Default = false,
        Callback = function(state)
            infJumpActive = state
            if state then if infJumpConn then infJumpConn:Disconnect() end; infJumpConn = uis.JumpRequest:Connect(function() local char = player.Character; local hum = char and char:FindFirstChildOfClass("Humanoid"); if hum and infJumpActive then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end); Notify("Moro Soul", "Infinite Jump Enabled", 2, "Success")
            else if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end; Notify("Moro Soul", "Infinite Jump Disabled", 2, "Info") end
        end
    })
    local customJumpPower = 50
    WallSec:AddSlider({ Name = "Jump Power", Min = 50, Max = 250, Default = 50, Suffix = " jp", Decimals = 0, Callback = function(val) customJumpPower = tonumber(val) or 50; local char = player.Character; local hum = char and char:FindFirstChildOfClass("Humanoid"); if hum then hum.UseJumpPower = true; hum.JumpPower = customJumpPower end end })
    local TeleportSec = wrapSection(ExploitsTab:CreateSection({ Name = "World Teleporter (Remote)", Collapsible = true }))
    local areaOptions = { "Wilderness", "Ubuyashiki Residence", "Farmland", "Train Station", "Wisteria Peak", "Wisteria Village" }; local selectedWorldArea = areaOptions[1]
    TeleportSec:AddDropdown({ Name = "Select World Area", Options = areaOptions, Default = areaOptions[1], Callback = function(val) selectedWorldArea = val end })
    TeleportSec:AddButton({ Name = "Teleport to World (Instant)", Primary = true, Callback = function() pcall(function() if remoteFolder:FindFirstChild("UnlockTeleport") then remoteFolder.UnlockTeleport:FireServer() end; if remoteFolder:FindFirstChild("AreaTeleport") then remoteFolder.AreaTeleport:FireServer(selectedWorldArea); Notify("Moro Soul", "Teleporting to " .. tostring(selectedWorldArea) .. "...", 2, "Success") else Notify("Moro Soul", "AreaTeleport remote not found!", 2, "Error") end end) end })
    TeleportSec:AddButton({ Name = "Unlock All World Teleports", Primary = false, Callback = function() local unRemote = remoteFolder:FindFirstChild("UnlockTeleport"); if unRemote then unRemote:FireServer(); Notify("Moro Soul", "UnlockTeleport request sent to server!", 2, "Success") else Notify("Moro Soul", "UnlockTeleport not found", 2, "Warning") end end })
    TeleportSec:AddButton({ Name = "Teleport to Boss Area", Primary = false, Callback = function() if remoteFolder:FindFirstChild("ToBossArea") then remoteFolder.ToBossArea:FireServer(); Notify("Moro Soul", "Teleporting to Boss Area...", 2, "Success") end end })
    TeleportSec:AddButton({ Name = "Teleport to Mugen Train", Primary = false, Callback = function() if remoteFolder:FindFirstChild("ToMugenTrain") then remoteFolder.ToMugenTrain:FireServer(); Notify("Moro Soul", "Teleporting to Mugen Train...", 2, "Success") end end })
    TeleportSec:AddButton({ Name = "Teleport to Blood Moon", Primary = false, Callback = function() if remoteFolder:FindFirstChild("ToBloodMoon") then remoteFolder.ToBloodMoon:FireServer(); Notify("Moro Soul", "Teleporting to Blood Moon...", 2, "Success") end end })

    ExploitsTab:Column("right")
    local PassSec = wrapSection(ExploitsTab:CreateSection({ Name = "GamePass & VIP Perks", Collapsible = true }))
    local autoSpoofPasses = false; local passSpoofConn = nil
    local function applyGamePassSpoof() local pd = rs:FindFirstChild("PlayerData") and rs.PlayerData:FindFirstChild(player.Name); if not pd then return end; local passes = { "GamePass_Speed", "GamePass_FastDrawRole1", "GamePass_FastDrawRole2", "GamePass_DoubleSoul", "GamePass_DoubleExp", "GamePass_Magnet", "GamePass_Luck1", "GamePass_Luck2", "GamePass_Luck3", "GamePass_AutoAttack", "GamePass_Dispatch1", "GamePass_Dispatch2", "GamePass_Dispatch3", "GamePass_UnlockHelper1", "GamePass_UnlockHelper2", "GamePass_Vip" }; for _, passName in ipairs(passes) do local val = pd:FindFirstChild(passName); if val and val:IsA("BoolValue") then val.Value = true end end; pcall(function() local toolMod = require(rs.Modules.Tool); if toolMod and toolMod.SetMoveSpeed then toolMod.SetMoveSpeed(player) end end) end
    PassSec:AddButton({ Name = "Unlock All GamePass Perks (Client)", Primary = true, Callback = function() applyGamePassSpoof(); Notify("Moro Soul", "All Client GamePasses & VIP Unlocked!", 3, "Success") end })
    PassSec:AddToggle({
        Name = "Keep GamePasses Active (Persistent)", Default = false,
        Callback = function(state)
            autoSpoofPasses = state
            if state then applyGamePassSpoof(); if passSpoofConn then passSpoofConn:Disconnect() end; passSpoofConn = runService.Heartbeat:Connect(function() if autoSpoofPasses then applyGamePassSpoof() end end); Notify("Moro Soul", "GamePass Lock Activated", 2, "Success")
            else if passSpoofConn then passSpoofConn:Disconnect(); passSpoofConn = nil end; Notify("Moro Soul", "GamePass Lock Disabled", 2, "Info") end
        end
    })
    local GachaSec = wrapSection(ExploitsTab:CreateSection({ Name = "Remote Gacha & Rewards", Collapsible = true }))
    GachaSec:AddButton({ Name = "Summon Character (1x)", Primary = false, Callback = function() local drawRemote = remoteFolder:FindFirstChild("DrawRole"); if drawRemote then drawRemote:FireServer(false); Notify("Moro Soul", "Remote Draw Executed!", 2, "Success") else Notify("Moro Soul", "DrawRole remote not found", 2, "Error") end end })
    local autoGacha = false
    GachaSec:AddToggle({
        Name = "Auto Remote Summon", Default = false,
        Callback = function(state)
            autoGacha = state
            if state then task.spawn(function() local drawRemote = remoteFolder:FindFirstChild("DrawRole"); if not drawRemote then return end; while autoGacha do drawRemote:FireServer(true); task.wait(1.5) end end); Notify("Moro Soul", "Auto Remote Summon Active!", 2, "Success")
            else Notify("Moro Soul", "Auto Remote Summon Disabled", 2, "Info") end
        end
    })
    GachaSec:AddButton({ Name = "Claim Season Reward", Primary = false, Callback = function() local sr = remoteFolder:FindFirstChild("ReceiveSeasonReward"); if sr then sr:FireServer(); Notify("Moro Soul", "Claimed Season Reward!", 2, "Success") end end })
    GachaSec:AddButton({ Name = "Claim Season Top 3 Reward", Primary = false, Callback = function() local s3 = remoteFolder:FindFirstChild("ReceiveSeasonTop3Reward"); if s3 then s3:FireServer(); Notify("Moro Soul", "Claimed Season Top 3 Reward!", 2, "Success") end end })
    local VisualSec = wrapSection(ExploitsTab:CreateSection({ Name = "Visual Exploits", Collapsible = true }))
    VisualSec:AddButton({ Name = "Full Bright / Night Vision", Primary = false, Callback = function() lighting.Ambient = Color3.fromRGB(255, 255, 255); lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255); lighting.Brightness = 2; lighting.ClockTime = 14; lighting.FogEnd = 1e5; lighting.GlobalShadows = false; Notify("Moro Soul", "Full Bright Activated!", 2, "Success") end })

    -- =====================================================================
    --                           SETTINGS TAB (Custom Extras)
    -- =====================================================================
    SettingsTab:Column("right")
    local GameOptSec = wrapSection(SettingsTab:CreateSection({ Name = "Game Optimizations", Collapsible = true }))
    GameOptSec:AddButton({
        Name = "FPS Booster (Ultra)", Primary = true,
        Callback = function()
            local terrain = workspace:FindFirstChildOfClass("Terrain"); if terrain then terrain.WaterWaveSize = 0; terrain.WaterWaveSpeed = 0; terrain.WaterReflectance = 0; terrain.WaterTransparency = 0 end
            lighting.GlobalShadows = false; lighting.FogEnd = 9e9; lighting.Brightness = 1
            for _, obj in ipairs(lighting:GetChildren()) do if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then obj.Enabled = false end end
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then obj.Material = Enum.Material.Plastic; obj.Reflectance = 0
                elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then obj.Enabled = false
                elseif obj:IsA("Explosion") then obj.Visible = false end
            end
            Notify("Moro Soul", "FPS Has Been Boosted!", 2, "Success")
        end
    })
    GameOptSec:AddToggle({ Name = "Animation Cancel", Default = false, Callback = function(state) animCancel = state end })
    GameOptSec:AddToggle({ Name = "Auto Reconnect", Default = true, Callback = function(state) autoReconnectEnabled = state end })

    Notify("Moro Soul", "Script Loaded Successfully (Lumina UI)!", 3, "Success")
end
